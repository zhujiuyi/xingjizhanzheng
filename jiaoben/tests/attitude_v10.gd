extends SceneTree
## Real Main keyboard input and physics, scoped fresh SQLite, current ship/model.
## Explicit pose fixtures exercise old tilted saves and the vertical singularity;
## they do not add game balance values or overwrite the user's progress.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var database_path: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var original_max_fps: int
var original_physics_hz: int
var original_interpolation: bool
var original_mouse: Vector2
var station_id: String
var origin: Vector3
var maximum_roll_error: float = 0.0
var maximum_turn_step: float = 0.0

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): print("ATTITUDE_V10_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 2) -> void:
	for frame: int in range(count): await process_frame

func release_actions() -> void:
	for action: StringName in InputMap.get_actions(): Input.action_release(action)

func start_host() -> void:
	host = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	host.set_process(false)
	host.set_physics_process(false)
	await frames()
	check(host.services_ready, "actual Main opens the formal read-only catalog and fresh scoped SQLite")

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "actual SQLite writer completes at its stable boundary")

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames()
	await create_timer(0.25).timeout

func prepare_native_input() -> bool:
	if DisplayServer.get_name() == "headless": return true
	root.grab_focus()
	var deadline: int = Time.get_ticks_msec() + 30000
	while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
	host.get_viewport().warp_mouse(Vector2(root.size) * 0.5)
	await frames(4)
	await RenderingServer.frame_post_draw
	return check(root.has_focus() and host._keyboard_control_allowed() and not host.ui.ui_input_blocked(), "native window owns actual keyboard focus and unobstructed OS pointer without bypassing protection")

func fixed_step() -> void:
	await physics_frame
	host._physics_process(1.0 / float(Engine.physics_ticks_per_second))
	await process_frame
	host._process(1.0 / float(Engine.max_fps))

func reset_pose(basis: Basis, velocity: Vector3 = Vector3.ZERO) -> void:
	release_actions()
	host.world.flight.global_transform = Transform3D(basis.orthonormalized(), origin)
	host.world.flight.velocity = velocity
	host.world.flight.clear_intent()
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.state.player().camera_mode = T.CameraMode.FOLLOW
	host.camera.step(0.0)
	host.ui.tick(1.0)

func finite_attitude(basis: Basis) -> bool:
	return basis.x.is_finite() and basis.y.is_finite() and basis.z.is_finite() and absf(basis.determinant() - 1.0) < 0.0001 and absf(basis.x.dot(basis.y)) < 0.0001 and absf(basis.y.dot(basis.z)) < 0.0001

func roll_error(basis: Basis, reference_up: Vector3 = Vector3.UP) -> float:
	var forward: Vector3 = -basis.z.normalized()
	var desired_up: Vector3 = reference_up.slide(forward)
	if desired_up.length_squared() < 0.000001: return 0.0
	desired_up = desired_up.normalized()
	var actual_up: Vector3 = basis.y.slide(forward).normalized()
	return absf(atan2(forward.dot(desired_up.cross(actual_up)), desired_up.dot(actual_up)))

func turn_steps(angle: float) -> int:
	return maxi(1, int(ceil(angle / float(host.world.flight.metrics.turn_radps) * float(Engine.physics_ticks_per_second))))

func camera_action() -> void:
	var event := InputEventAction.new()
	event.action = "camera"
	event.pressed = true
	host._unhandled_input(event)

func drag_view(motion: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = Vector2(root.size) * 0.5
	down.pressed = true
	host._unhandled_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = down.position + motion
	drag.relative = motion
	drag.screen_relative = motion
	host._input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = drag.position
	up.pressed = false
	host._input(up)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var folder: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/attitude-v10/native")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "native attitude capture " + label)
	captures += 1

func _run() -> void:
	original_max_fps = Engine.max_fps
	original_physics_hz = Engine.physics_ticks_per_second
	original_interpolation = physics_interpolation
	if DisplayServer.get_name() != "headless": original_mouse = root.get_mouse_position()
	Engine.max_fps = 144
	physics_interpolation = true
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/attitude-v10-%d.db" % Time.get_ticks_usec())
	await start_host()
	if not host.services_ready: await finish(); return
	Engine.physics_ticks_per_second = int(host.store.catalog.rule("simulation_hz"))
	await host._command("new_world", "姿态回正独立验收", 1, "")
	if not check(host.state != null, "actual production endpoint creates a complete independent world"):
		await finish(); return
	await host._command("undock", "", 1, "")
	await wait_writer()
	host.ui.show_page("")
	host._sync_presentation_stage()
	host._sync_mouse_mode()
	await fixed_step()
	if not await prepare_native_input(): await finish(); return
	for id: String in host.world.targets:
		if str(host.world.targets[id].kind) == "station": station_id = id; break
	if not check(not station_id.is_empty(), "actual current sector exposes a legal station target"):
		await finish(); return
	var station: Node3D = host.world.targets[station_id].node
	origin = station.global_position + Vector3(0, 2200, 8000)
	check(float(host.world.flight.metrics.turn_radps) > 0.0, "turn limits are read from the actual equipped ship metrics")
	await manual_yaw_checks()
	await explicit_roll_checks()
	await pole_checks()
	await navigation_checks()
	await persistence_checks()
	await finish()

func manual_yaw_checks() -> void:
	for pitch: float in [0.0, 0.65, -0.65]:
		for action: String in ["yaw_left", "yaw_right"]:
			reset_pose(Basis(Vector3.RIGHT, pitch), Vector3(4, 3, -12))
			var initial_forward: Vector3 = -host.world.flight.global_basis.z
			var bounded: bool = true
			var finite: bool = true
			Input.action_press(action)
			for tick: int in range(turn_steps(0.40)):
				var previous: Quaternion = host.world.flight.quaternion
				await fixed_step()
				bounded = within_turn_budget(previous) and bounded
				finite = finite_attitude(host.world.flight.global_basis) and finite
			Input.action_release(action)
			var label: String = "%s pitch=%.2f" % [action, pitch]
			check(initial_forward.angle_to(-host.world.flight.global_basis.z) > 0.03 and finite, "actual Main A/D rotates a finite physical ship " + label)
			check(bounded, "combined steering and roll recovery share the real single turn budget " + label)
			if pitch == 0.65:
				check(absf(host.camera.camera.global_basis.x.y) < 0.00001, "pitched A/D keeps the actual rendered screen-right horizontal " + label)
			await recover_and_check(label)
			if pitch == 0.65:
				check(absf(host.camera.camera.global_basis.x.y) < 0.00001, "released pitched A/D leaves the actual follow view level " + label)
			if pitch == 0.65 and action == "yaw_left": await capture("pitched-yaw-recovered")
	# W still accelerates along the observed heading while A/D changes that
	# heading. The player's vertical view is not forcibly flattened by recovery.
	for action: String in ["yaw_left", "yaw_right"]:
		reset_pose(Basis.IDENTITY)
		drag_view(Vector2(95, -175))
		host.camera.snapped = false
		host.camera.step(0.0)
		var observed: Vector3 = host.camera.control_forward()
		Input.action_press("forward"); Input.action_press(action)
		var directed: bool = true
		var bounded: bool = true
		for tick: int in range(12):
			var previous_velocity: Vector3 = host.world.flight.velocity
			var previous: Quaternion = host.world.flight.quaternion
			await fixed_step()
			var acceleration: Vector3 = host.world.flight.velocity - previous_velocity
			directed = acceleration.length() > 0.0 and acceleration.normalized().dot(host.world.flight.intent.view_thrust_direction) > 0.998 and directed
			bounded = within_turn_budget(previous) and bounded
		Input.action_release("forward"); Input.action_release(action)
		check(absf(observed.y) > 0.05 and absf(host.world.flight.velocity.y) > 0.001 and directed, "observed three-dimensional W acceleration remains intact during " + action)
		check(bounded and finite_attitude(host.world.flight.global_basis), "W plus yaw keeps one bounded physical orientation update " + action)
		await recover_and_check("W plus " + action)
	reset_pose(Basis(Vector3.RIGHT, 0.7))
	var reciprocal_bounded: bool = true
	for turn_index: int in range(6):
		var action: String = "yaw_left" if turn_index % 2 == 0 else "yaw_right"
		Input.action_press(action)
		for tick: int in range(10):
			var previous: Quaternion = host.world.flight.quaternion
			await fixed_step()
			reciprocal_bounded = within_turn_budget(previous) and reciprocal_bounded
		Input.action_release(action)
	check(reciprocal_bounded and finite_attitude(host.world.flight.global_basis), "repeated real left/right changes stay finite and rate limited")
	await recover_and_check("repeated left/right changes")
	await capture("left-right-recovered")

func within_turn_budget(previous: Quaternion) -> bool:
	# acos(dot) loses useful precision for a single small fixed step. Relative
	# quaternion atan2 independently measures the actual shortest rotation.
	var applied: Quaternion = (previous.inverse() * host.world.flight.quaternion).normalized()
	var angle: float = 2.0 * atan2(Vector3(applied.x, applied.y, applied.z).length(), absf(applied.w))
	maximum_turn_step = maxf(maximum_turn_step, angle)
	return angle <= float(host.world.flight.metrics.turn_radps) / float(Engine.physics_ticks_per_second) + 0.0002

func recover_and_check(label: String) -> void:
	var released: Basis = host.world.flight.global_basis
	var velocity: Vector3 = host.world.flight.velocity
	var initial_roll: float = roll_error(released)
	maximum_roll_error = maxf(maximum_roll_error, initial_roll)
	var bounded: bool = true
	var monotonic: bool = true
	var previous_roll: float = initial_roll
	for tick: int in range(turn_steps(initial_roll + 0.08) + 8):
		var previous: Quaternion = host.world.flight.quaternion
		await fixed_step()
		bounded = within_turn_budget(previous) and bounded
		var error: float = roll_error(host.world.flight.global_basis)
		monotonic = error <= previous_roll + 0.00005 and monotonic
		previous_roll = error
	var recovered: Basis = host.world.flight.global_basis
	check(roll_error(recovered) < 0.0005 and monotonic, "released controls converge smoothly to level without residual bank " + label)
	check((-recovered.z).dot(-released.z) > 0.999999 and host.world.flight.velocity.is_equal_approx(velocity), "idle roll recovery preserves the chosen 3D heading and inertial velocity " + label)
	check(bounded and finite_attitude(recovered) and host.world.flight.intent.yaw_request == 0.0 and host.world.flight.intent.pitch_request == 0.0 and host.world.flight.intent.roll_request == 0.0, "idle recovery is finite, shares the real turn limit and has no held input " + label)

func explicit_roll_checks() -> void:
	var keys := {"roll_left": KEY_Q, "roll_right": KEY_E}
	for action: String in keys:
		var bound: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == keys[action]: bound = true
		check(bound, "explicit roll keeps its existing physical key " + action)
		reset_pose(Basis.IDENTITY, Vector3(-3, 4, -9))
		var initial_forward: Vector3 = -host.world.flight.global_basis.z
		var bounded: bool = true
		Input.action_press(action)
		for tick: int in range(turn_steps(0.45)):
			var previous: Quaternion = host.world.flight.quaternion
			await fixed_step()
			bounded = within_turn_budget(previous) and bounded
		Input.action_release(action)
		check(roll_error(host.world.flight.global_basis) > 0.20 and absf(host.world.flight.intent.roll_request) > 0.0 and (-host.world.flight.global_basis.z).dot(initial_forward) > 0.999999, "held Q/E explicitly banks the vessel without changing forward " + action)
		check(bounded, "explicit roll consumes the same authoritative turn budget " + action)
		if action == "roll_right": await capture("explicit-roll-held")
		await recover_and_check("released " + action)

func pole_checks() -> void:
	for pitch: float in [PI * 0.5, PI * 0.5 - 0.00001, -PI * 0.5, -PI * 0.5 + 0.00001]:
		reset_pose(Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, 0.45))
		var before: Basis = host.world.flight.global_basis
		await fixed_step()
		check(finite_attitude(host.world.flight.global_basis) and before.is_equal_approx(host.world.flight.global_basis), "exact/near vertical idle pose keeps its valid right/up frame instead of flipping %.7f" % pitch)
		Input.action_press("yaw_left")
		var finite: bool = true
		var bounded: bool = true
		var continuous_view: bool = true
		for tick: int in range(16):
			var previous: Quaternion = host.world.flight.quaternion
			var previous_right: Vector3 = host.camera.camera.global_basis.x.normalized()
			await fixed_step()
			finite = finite_attitude(host.world.flight.global_basis) and finite_attitude(host.camera.camera.global_basis) and host.world.flight.velocity.is_finite() and finite
			bounded = within_turn_budget(previous) and bounded
			continuous_view = previous_right.dot(host.camera.camera.global_basis.x.normalized()) > 0.0 and continuous_view
		Input.action_release("yaw_left")
		check(finite and bounded and continuous_view, "yaw leaving a vertical pose keeps physical turning bounded and the real camera finite without flipping screen-right %.7f" % pitch)
		await recover_and_check("vertical exit %.7f" % pitch)
	# Free observation keeps its old heading; explicitly recover the view before
	# assessing the user's requirement that a recentered vessel appears upright.
	host._command("show_ship", "", 1, "")
	host.camera.step(0.0)
	var right_alignment: float = host.camera.camera.global_basis.x.normalized().dot(host.world.flight.global_basis.x.normalized())
	if right_alignment < 0.99999: print("ATTITUDE_V10_POLE_VIEW alignment=%.9f camera_right=%s ship_right=%s forward=%s" % [right_alignment, host.camera.camera.global_basis.x, host.world.flight.global_basis.x, -host.world.flight.global_basis.z])
	check(host.camera.mode == T.CameraMode.FOLLOW and host.camera.orbit.is_zero_approx() and right_alignment > 0.99999, "show-ship after vertical exit aligns screen-right with the actual recovered vessel right")
	await capture("vertical-exit-recovered")

func navigation_checks() -> void:
	for mode: String in ["approach", "orbit", "warp"]:
		var station: Node3D = host.world.targets[station_id].node
		var toward_station: Basis = Basis.looking_at(origin.direction_to(station.global_position), Vector3.UP)
		reset_pose(toward_station * Basis(Vector3.FORWARD, 0.55))
		check(host._navigation_command(mode, station_id), "actual Main accepts legal navigation before camera recovery " + mode)
		var accepted_phase: String = host.local_navigation.phase
		var before: Transform3D = host.world.flight.global_transform
		var velocity: Vector3 = host.world.flight.velocity
		drag_view(Vector2(100, -60))
		var observed: Vector2 = host.camera.orbit
		camera_action()
		check(not observed.is_zero_approx() and host.camera.orbit.is_zero_approx() and host.local_navigation.active() and host.local_navigation.mode == mode and host.local_navigation.target_id == station_id and host.local_navigation.phase == accepted_phase, "V resets only observation and keeps the accepted navigation " + mode)
		check(host.world.flight.global_transform.is_equal_approx(before) and host.world.flight.velocity.is_equal_approx(velocity), "V has no instantaneous physical attitude or velocity mutation " + mode)
		host._command("show_ship", "", 1, "")
		check(host.camera.mode == T.CameraMode.FOLLOW and host.camera.orbit.is_zero_approx() and roll_error(host.camera.observation_basis) < 0.0005 and host.local_navigation.active() and host.local_navigation.mode == mode and host.local_navigation.target_id == station_id, "show-ship uses a level follow reference and keeps the accepted navigation " + mode)
		check(absf(host.camera.camera.global_basis.x.y) < 0.00001, "show-ship renders a horizontal screen-right during accepted navigation " + mode)
		check(host.world.flight.global_transform.is_equal_approx(before) and host.world.flight.velocity.is_equal_approx(velocity), "show-ship does not teleport, instantly turn or stop the actual ship " + mode)
		if mode == "warp":
			var bounded: bool = true
			var initial_roll: float = roll_error(host.world.flight.global_basis)
			for tick: int in range(turn_steps(0.20)):
				var previous: Quaternion = host.world.flight.quaternion
				await fixed_step()
				bounded = within_turn_budget(previous) and bounded
			check(host.local_navigation.warp_active() and host.local_navigation.phase == "warmup" and roll_error(host.world.flight.global_basis) < initial_roll - 0.03 and bounded, "real warp alignment removes old bank smoothly within its existing turn budget")
		host._command("nav_stop", "", 1, "")
		await wait_writer()
		check(not host.local_navigation.active(), "actual explicit stop releases navigation " + mode)
	reset_pose(Basis(Vector3.RIGHT, 0.6) * Basis(Vector3.FORWARD, 0.7), Vector3(2, -4, -10))
	var before: Transform3D = host.world.flight.global_transform
	var velocity: Vector3 = host.world.flight.velocity
	host._command("show_ship", "", 1, "")
	check(roll_error(host.camera.observation_basis) < 0.0005 and (-host.camera.observation_basis.z).dot(-before.basis.z) > 0.999999, "recentered follow view retains heading and removes the inherited camera bank")
	check(absf(host.camera.camera.global_basis.x.y) < 0.00001, "show-ship renders the real follow view level for an old tilted physical pose")
	check(host.world.flight.global_transform.is_equal_approx(before) and host.world.flight.velocity.is_equal_approx(velocity), "recentered follow camera leaves physical ship and velocity untouched before simulation")
	await recover_and_check("show-ship legacy bank")
	check(absf(host.camera.camera.global_basis.x.y) < 0.00001, "the actual recentered follow view stays level throughout subsequent roll recovery")
	await capture("show-ship-recovered")

func persistence_checks() -> void:
	# A legally sealed old-bank pose is an explicit persistence fixture, not a
	# naturally earned gameplay event. No physics occurs between seal and reopen.
	for bank: float in [0.0, 0.6]:
		reset_pose(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, 0.35) * Basis(Vector3.FORWARD, bank), Vector3(7, -2, -15))
		var saved: Transform3D = host.world.flight.global_transform
		var velocity: Vector3 = host.world.flight.velocity
		var q: Quaternion = host.world.flight.quaternion
		host._request_save("manual", 0)
		await wait_writer()
		var rows: Array[Dictionary] = host.store._records("SELECT q.quat_x,q.quat_y,q.quat_z,q.quat_w,q.vel_x,q.vel_y,q.vel_z,s.status FROM save_slot l JOIN save_snapshot s ON s.snapshot_id=l.current_snapshot_id JOIN ship_state q ON q.snapshot_id=s.snapshot_id WHERE l.world_id=? AND l.slot_kind='manual' AND l.slot_index=0 AND q.ship_instance_id=?", [host.state.world_id, host.state.ship().ship_instance_id])
		var persisted: Quaternion = Quaternion.IDENTITY
		if not rows.is_empty(): persisted = Quaternion(float(rows[0].quat_x), float(rows[0].quat_y), float(rows[0].quat_z), float(rows[0].quat_w))
		check(rows.size() == 1 and rows[0].status == "sealed" and persisted.is_equal_approx(q), "sealed SQLite stores the exact physical quaternion, including intentional old bank %.1f" % bank)
		await release_host(); await start_host()
		await host._command("continue", "", 1, "")
		await wait_writer()
		host.ui.show_page("")
		host._sync_mouse_mode()
		host._sync_presentation_stage()
		check(host.world.flight.global_transform.is_equal_approx(saved) and host.world.flight.velocity.is_equal_approx(velocity), "actual SQLite reopen preserves stored ship position, quaternion and velocity before simulation %.1f" % bank)
		check(host.camera.mode == T.CameraMode.FOLLOW and roll_error(host.camera.observation_basis) < 0.0005 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "reopened follow view is level and pointer remains visible without rewriting the snapshot %.1f" % bank)
		if not await prepare_native_input(): return
		# Recompute metrics through Main, exactly as a real first resumed step.
		var before_resume: Quaternion = host.world.flight.quaternion
		await fixed_step()
		check(within_turn_budget(before_resume) and (-host.world.flight.global_basis.z).dot(-saved.basis.z) > 0.999999 and host.world.flight.velocity.is_equal_approx(velocity), "first resumed real physics step recovers only roll within the ship budget %.1f" % bank)
		await recover_and_check("SQLite reopened bank %.1f" % bank)

func finish() -> void:
	release_actions()
	await release_host()
	if DisplayServer.get_name() != "headless": root.warp_mouse(original_mouse)
	Engine.max_fps = original_max_fps
	Engine.physics_ticks_per_second = original_physics_hz
	physics_interpolation = original_interpolation
	print("ATTITUDE_V10_METRICS maximum_roll_error_rad=%.9f maximum_turn_step_rad=%.9f" % [maximum_roll_error, maximum_turn_step])
	print("ATTITUDE_V10_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
