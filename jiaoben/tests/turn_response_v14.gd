extends SceneTree
## Production Flight, actual nine catalog ships, explicit attitude stimuli.
## No player progress, alternate balance values, or visual-camera claims.
const Flight = preload("res://runtime/flight.gd")
const Catalog = preload("res://runtime/data/catalog.gd")
const Look = preload("res://runtime/flight_look.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []
var minimum_progress_ratio: float = INF
var maximum_budget_ratio: float = 0.0

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): print("TURN_RESPONSE_V14_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func rotation_angle(before: Quaternion, after: Quaternion) -> float:
	var difference: Quaternion = (before.inverse() * after).normalized()
	if difference.w < 0.0: difference = -difference
	return 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), difference.w)

func finite_pose(pose: Basis) -> bool:
	return pose.is_finite() and absf(pose.determinant() - 1.0) < 0.00001 and absf(pose.x.dot(pose.y)) < 0.00001

func roll_error(pose: Basis) -> float:
	var forward: Vector3 = -pose.z.normalized()
	var up: Vector3 = Vector3.UP.slide(forward)
	if up.length_squared() < 0.000001: return 0.0
	return absf(atan2(forward.dot(up.normalized().cross(pose.y)), up.normalized().dot(pose.y)))

func reset_flight(flight: Flight, pose: Basis) -> void:
	flight.transform = Transform3D(pose, Vector3(50000, 20000, -50000))
	flight.velocity = Vector3.ZERO
	flight.clear_intent()
	flight.write_back()

func _run() -> void:
	var catalog := Catalog.new()
	check(catalog.open(), "actual read-only catalog opens " + catalog.last_error)
	if not failures.is_empty(): catalog.close(); quit(1); return
	var ships: Array[Dictionary] = catalog.rows("ship_defs")
	check(ships.size() == 9, "all current nine catalog ship types are covered")
	var poses: Array[Basis] = [Basis.IDENTITY, Basis.from_euler(Vector3(0.65, -0.4, 1.0)), Basis.from_euler(Vector3(-0.65, 0.4, -1.0)), Basis(Vector3.RIGHT, PI * 0.5), Basis(Vector3.RIGHT, -PI * 0.5 + 0.00001)]
	for pose_index: int in range(poses.size()):
		for world_rotation: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD, Vector3(0.25, -0.4, 0.35), poses[pose_index].y]:
			var request: Vector3 = Look.world_rotation_to_input(poses[pose_index], world_rotation)
			var reconstructed: Vector3 = poses[pose_index] * Vector3(request.x, request.y, -request.z)
			check(reconstructed.distance_to(world_rotation) < 0.000001 and absf(request.length() - world_rotation.length()) < 0.000001, "camera world axis converts to truthful ship-local DTO spin without amplification pose%d vector%s" % [pose_index, world_rotation])
	check(Look.world_rotation_to_input(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.UP).is_zero_approx() and Look.world_rotation_to_input(Basis.IDENTITY, Vector3(NAN, 0, 0)).is_zero_approx(), "invalid axis or singular pose cannot poison input conversion")
	for definition: Dictionary in ships:
		var flight := Flight.new()
		root.add_child(flight)
		var record := D.ShipStateDto.new()
		record.ship_instance_id = "turn_v14_" + str(definition.ship_id)
		record.ship_def_id = definition.ship_id
		record.status = T.ShipStatus.FLYING
		record.quat_w = 1.0
		flight.bind(record, catalog)
		flight.metrics = {"turn_radps": float(definition.turn_rad_s), "speed_mps": float(definition.max_speed_mps), "acceleration_mps2": float(definition.acceleration_mps2), "strafe_multiplier": float(catalog.rule("strafe_acceleration_multiplier")), "reverse_multiplier": float(catalog.rule("reverse_acceleration_multiplier")), "brake_multiplier": float(catalog.rule("brake_acceleration_multiplier"))}
		for pose_index: int in range(poses.size()):
			for delta: float in [1.0 / 240.0, 1.0 / 60.0, 0.25]:
				for direction: float in [-1.0, 1.0]:
					await physics_frame
					reset_flight(flight, poses[pose_index])
					flight.intent.yaw_request = direction
					var turn_step: float = float(flight.metrics.turn_radps) * delta
					var bounded: bool = true
					var advancing: bool = true
					var exact: bool = true
					var angular_exact: bool = true
					var finite: bool = true
					var first_ratio: float = 0.0
					for tick: int in range(12):
						var before: Quaternion = flight.quaternion
						var forward: Vector3 = -flight.basis.z
						var expected_forward: Vector3 = -(Basis(before) * Basis(Vector3.UP, direction * turn_step)).z
						flight.simulate(delta)
						var applied_angle: float = rotation_angle(before, flight.quaternion)
						var progress: float = forward.angle_to(-flight.basis.z)
						var ratio: float = progress / turn_step
						if tick == 0: first_ratio = ratio
						minimum_progress_ratio = minf(minimum_progress_ratio, ratio)
						maximum_budget_ratio = maxf(maximum_budget_ratio, applied_angle / turn_step)
						advancing = advancing and ratio >= 0.995
						bounded = bounded and applied_angle <= turn_step + 0.000003
						exact = exact and (-flight.basis.z).distance_to(expected_forward) < 0.000003
						angular_exact = angular_exact and absf(Vector3(record.angular_x, record.angular_y, record.angular_z).length() * delta - applied_angle) < 0.000003
						finite = finite and finite_pose(flight.basis)
					var label: String = "%s pose%d dt%.6f yaw%.0f" % [definition.ship_id, pose_index, delta, direction]
					check(first_ratio >= 0.995 and advancing and exact, "first step and twelve held steps deliver actual yaw without roll starvation " + label)
					check(bounded and angular_exact and finite, "single catalog budget, truthful angular state and finite pose " + label)
		for pose_index: int in range(poses.size()):
			for direction: float in [-1.0, 1.0]:
				reset_flight(flight, poses[pose_index])
				var request: Vector3 = Look.world_rotation_to_input(flight.basis, Vector3.UP * direction)
				flight.intent.pitch_request = request.x
				flight.intent.yaw_request = request.y
				flight.intent.roll_request = request.z
				var before: Quaternion = flight.quaternion
				var step: float = float(flight.metrics.turn_radps) / 60.0
				var expected: Quaternion = (Basis(Vector3.UP, direction * step) * flight.basis).get_rotation_quaternion()
				flight.simulate(1.0 / 60.0)
				check(rotation_angle(expected, flight.quaternion) < 0.000003 and absf(rotation_angle(before, flight.quaternion) - step) < 0.000003 and finite_pose(flight.basis), "mapped non-FRONT camera world-up yaw applies the identical physical rotation %s pose%d yaw%.0f" % [definition.ship_id, pose_index, direction])
		await recovery_checks(flight, str(definition.ship_id))
		root.remove_child(flight); flight.free()
	catalog.close()
	print("TURN_RESPONSE_V14_METRICS ", JSON.stringify({"minimum_heading_progress_ratio": minimum_progress_ratio, "maximum_turn_budget_ratio": maximum_budget_ratio, "checks": checks}))
	print("TURN_RESPONSE_V14_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func recovery_checks(flight: Flight, ship_id: String) -> void:
	var delta: float = 1.0 / 60.0
	var budget: float = float(flight.metrics.turn_radps) * delta
	reset_flight(flight, Basis.from_euler(Vector3(0.45, 0.2, 0.8)))
	flight.intent.yaw_request = 0.35
	var before: Quaternion = flight.quaternion
	var requested_forward: Vector3 = -(Basis(before) * Basis(Vector3.UP, budget * 0.35)).z
	var before_roll: float = roll_error(flight.basis)
	flight.simulate(delta)
	check((-flight.basis.z).distance_to(requested_forward) < 0.000003 and rotation_angle(before, flight.quaternion) <= budget + 0.000003 and roll_error(flight.basis) < before_roll, "partial heading receives its request and unused catalog budget recovers roll " + ship_id)
	reset_flight(flight, Basis.from_euler(Vector3(0.4, -0.2, 0.75)))
	flight.intent.roll_request = 1.0
	var forward: Vector3 = -flight.basis.z
	before = flight.quaternion
	flight.simulate(delta)
	check((-flight.basis.z).distance_to(forward) < 0.000003 and absf(rotation_angle(before, flight.quaternion) - budget) < 0.000003, "explicit Q/E still owns its full actual turn budget " + ship_id)
	flight.clear_intent()
	forward = -flight.basis.z
	var bounded: bool = true
	var stable_heading: bool = true
	for tick: int in range(int(ceil(1.5 / budget))):
		before = flight.quaternion
		flight.simulate(delta)
		bounded = bounded and rotation_angle(before, flight.quaternion) <= budget + 0.000003
		stable_heading = stable_heading and (-flight.basis.z).distance_to(forward) < 0.000003
	check(roll_error(flight.basis) < 0.00001 and bounded and stable_heading and finite_pose(flight.basis), "release recovers roll without heading drift, input residue or an extra turn budget " + ship_id)
	before = flight.quaternion
	flight.simulate(0.0); flight.simulate(-0.1); flight.simulate(NAN)
	check(flight.quaternion.is_equal_approx(before), "invalid time never rotates the physical ship " + ship_id)
