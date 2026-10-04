extends SceneTree
## Real Main input/physics/render checks in a fresh tmp SQLite world.
## Nine owned hulls, one real fitted weapon and capacity-checked cargo are explicit
## inventory/pose fixtures, not natural purchases, mission completion or player saves.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var fleet_ids: Array[String] = []
var matrix_cases: int = 0
var baseline_cases: int = 0
var old_fps: int
var old_hz: int
var old_interpolation: bool
var old_mouse: Vector2
var origin: Vector3
var dt: float
var baseline_only: bool = false
var maximum_budget_ratio: float = 0.0
var last_step_input: Vector3 = Vector3.ZERO
var last_step_view_thrust: Vector3 = Vector3.ZERO

func _initialize() -> void:
	create_timer(240.0).timeout.connect(func(): print("MANUAL_TURN_V14_RESULT FAIL watchdog"); quit(1))
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
	if is_instance_valid(host): host._release_controls()

func native_focus() -> bool:
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
		host.get_viewport().warp_mouse(Vector2(root.size) * 0.5)
		await frames(4)
		await RenderingServer.frame_post_draw
	return check(host._keyboard_control_allowed() and not host.ui.ui_input_blocked(), "production focus/UI/transaction predicates permit the staged input without bypasses")

func fixed_step() -> void:
	await physics_frame
	host._physics_process(dt)
	# Measure the input actually consumed by physics before a later render/page
	# transition legitimately clears transient controls in Main._process.
	last_step_input = Vector3(host.world.flight.intent.pitch_request, host.world.flight.intent.yaw_request, -host.world.flight.intent.roll_request)
	last_step_view_thrust = host.world.flight.intent.view_thrust_direction
	await process_frame
	host._process(1.0 / float(Engine.max_fps))

func reset_pose(mode: T.CameraMode, basis: Basis = Basis.IDENTITY) -> void:
	release_actions()
	host.world.flight.global_transform = Transform3D(basis.orthonormalized(), origin)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.clear_intent()
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.state.player().camera_mode = mode
	host.camera.bind(host.world.flight, host.store.catalog, mode)
	host.camera.step(0.0)
	host.ui.tick(1.0)
	# Honor the production menu-close boundary before staging a measured key.
	# Main starts with previous_page="title"; the first render clears controls.
	host._process(0.0)

func drag_view(motion: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT; down.position = Vector2(root.size) * 0.5; down.pressed = true
	host._unhandled_input(down)
	var drag := InputEventMouseMotion.new()
	drag.position = down.position + motion; drag.relative = motion; drag.screen_relative = motion
	host._input(drag)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT; up.position = drag.position; up.pressed = false
	host._input(up)
	# Settle this explicit camera starting pose before the measured first key tick.
	host.camera.snapped = false
	host.camera.step(0.0)

func settle_view() -> void:
	# A fixture teleport and an immediate interpolation query can still share
	# the preceding physics pump buffer. Advance actual engine boundaries with
	# Main simulation disabled and no held keys, then sample the stationary pose.
	await physics_frame
	await process_frame
	host.camera.snapped = false
	host.camera.step(0.0)
	host.ui.tick(0.0)
	var rendered: Transform3D = host.camera.render_ship_transform()
	var physical: Transform3D = host.world.flight.global_transform
	check(pose_error(rendered.basis, physical.basis) < 0.00002 and rendered.origin.distance_to(physical.origin) < 0.001, "measured camera starting sample matches the stationary physical fixture after real engine boundaries")
	if host.camera.mode == T.CameraMode.FRONT:
		var expected: Basis = rendered.basis * Basis(Vector3.UP, host.camera.orbit.x) * Basis(Vector3.RIGHT, host.camera.orbit.y)
		check(pose_error(host.camera.camera.global_basis, expected) < 0.00002, "measured front starting camera includes the actual rendered ship pose and retained free observation")

func quaternion_angle(value: Quaternion) -> float:
	var q: Quaternion = value.normalized()
	return 2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w))

func pose_error(actual: Basis, expected: Basis) -> float:
	return quaternion_angle(expected.get_rotation_quaternion().inverse() * actual.get_rotation_quaternion())

func bounded(before: Quaternion, budget: float) -> bool:
	var angle: float = quaternion_angle(before.inverse() * host.world.flight.quaternion)
	if budget > 0.0: maximum_budget_ratio = maxf(maximum_budget_ratio, angle / budget)
	return angle <= budget + 0.00004

func yaw_axis(mode: T.CameraMode, pose: Basis) -> Vector3:
	return pose.y.normalized() if mode == T.CameraMode.FRONT else Vector3.UP

func baseline_checks() -> void:
	# Old Main overwrote explicit A/D with the contrary retained W observation:
	# e.g. -0.28rad view +0.025rad key step => yaw=-1 despite held A (+1).
	for action: String in ["yaw_left", "yaw_right"]:
		reset_pose(T.CameraMode.FOLLOW)
		var sign_value: float = 1.0 if action == "yaw_left" else -1.0
		drag_view(Vector2(140.0 * sign_value, 0.0))
		await settle_view()
		var before: Basis = host.world.flight.global_basis
		var view: Vector3 = host.camera.control_forward()
		var budget: float = float(host.gameplay.call("metrics", host.state.ship()).turn_radps) * dt
		Input.action_press("forward"); Input.action_press(action)
		await fixed_step()
		var actual: Basis = host.world.flight.global_basis
		var expected: Basis = Basis(Vector3.UP, sign_value * budget) * before
		var world_request: Vector3 = before * last_step_input
		check(world_request.dot(Vector3.UP) * sign_value > 0.99, "baseline explicit A/D owns first W+A/D request despite contrary retained view " + action)
		check(pose_error(actual, expected) < 0.0002, "baseline first physical tick turns in the requested direction at the actual catalog budget " + action)
		var sample := {"scope": "opposing_view_baseline", "action": action, "view_before": [view.x, view.y, view.z], "budget_rad": budget, "world_yaw_request": world_request.dot(Vector3.UP), "first_pose_error_rad": pose_error(actual, expected)}
		samples.append(sample); print("MANUAL_TURN_V14_SAMPLE " + JSON.stringify(sample))
		baseline_cases += 1
		release_actions()

func fit_weapon(ship: D.ShipStateDto) -> bool:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var slot := inventory.call("slot", ship, "weapon", 0) as D.ContainerStateDto
	if not check(slot != null, "formal hull exposes its real first weapon slot " + ship.ship_def_id): return false
	var ids: Array = inventory.call("grant", slot.container_id, "module_kinetic_needle_i", 1)
	if not check(ids.size() == 1, "explicit fixture grants one formal weapon instance " + ship.ship_def_id): return false
	var equipment := D.EquipmentStateDto.new()
	equipment.slot_container_id = slot.container_id; equipment.item_instance_id = str(ids[0]); equipment.module_def_id = "module_kinetic_needle_i"; equipment.enabled = true
	return check(host.state.add("equipment_state", equipment), "fixture fitted weapon uses the real equipment DTO " + ship.ship_def_id)

func activate_ship(ship: D.ShipStateDto) -> bool:
	release_actions()
	# A declared fixture stages an already-owned formal hull; no production
	# permission predicate is patched and every measured tick uses Main.
	host.state.player().controlled_ship_id = ship.ship_instance_id
	host.state.player().has_docked_station_id = false; host.state.player().docked_station_id = ""
	ship.status = T.ShipStatus.FLYING; ship.has_station_id = false; ship.station_id = ""
	ship.pos_x = origin.x; ship.pos_y = origin.y; ship.pos_z = origin.z
	if not check(host._stage_candidate(host.state, host.store.catalog), "production staging builds the formal test hull " + ship.ship_def_id): return false
	host._activate(host.state)
	host.ui.show_page(""); host._sync_presentation_stage(); host._sync_mouse_mode()
	await frames(2)
	host.world.flight.metrics = host.gameplay.call("metrics", ship)
	reset_pose(T.CameraMode.FOLLOW)
	return await native_focus()

func add_legal_cargo(ship: D.ShipStateDto) -> bool:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var hold_id: String = str(inventory.call("hold", ship, T.ContainerKind.CARGO))
	var room: int = int(inventory.call("room", hold_id, "ore_pressure_steel", 1000000))
	var quantity: int = maxi(1, int(floor(float(room) * 0.5)))
	if not check(room >= quantity, "formal inventory capacity permits declared loaded fixture " + ship.ship_def_id): return false
	var ids: Array = inventory.call("grant", hold_id, "ore_pressure_steel", quantity)
	var totals: Dictionary = inventory.call("totals", hold_id)
	var metrics: Dictionary = host.gameplay.call("metrics", ship)
	return check(ids.size() == 1 and float(totals.mass) > 0.0 and float(metrics.payload_mass_kg) <= float(metrics.max_payload_mass_kg) and int(metrics.cargo_used_l) <= int(metrics.cargo_capacity_l), "loaded fixture retains real ore mass and both legal payload/volume bounds " + ship.ship_def_id)

func yaw_case(ship: D.ShipStateDto, mode: T.CameraMode, loaded: bool, action: String, with_forward: bool) -> void:
	var start_basis: Basis = Basis(Vector3.RIGHT, 0.60) * Basis(Vector3.FORWARD, 0.35)
	reset_pose(mode, start_basis)
	var sign_value: float = 1.0 if action == "yaw_left" else -1.0
	if with_forward: drag_view(Vector2(140.0 * sign_value, -90.0))
	await settle_view()
	var start: Basis = host.world.flight.global_basis
	var axis: Vector3 = yaw_axis(mode, start)
	var view_start: Vector3 = host.camera.control_forward()
	var orbit_start: Vector2 = host.camera.orbit
	var rendered_start: Basis = host.camera.render_ship_transform().basis
	var metrics: Dictionary = host.gameplay.call("metrics", ship)
	var budget: float = float(metrics.turn_radps) * dt
	var expected: Basis = start
	var max_error: float = 0.0
	var limited: bool = true
	var thrust_coherent: bool = true
	Input.action_press(action)
	if with_forward: Input.action_press("forward")
	for tick: int in range(12):
		var before: Quaternion = host.world.flight.quaternion
		var prior_velocity: Vector3 = host.world.flight.velocity
		expected = (Basis(axis, sign_value * budget) * expected).orthonormalized()
		await fixed_step()
		limited = bounded(before, budget) and limited
		var error: float = pose_error(host.world.flight.global_basis, expected)
		max_error = maxf(max_error, error)
		if tick == 0:
			check(error < 0.0003, "first real Main tick honors manual yaw with old bank/view " + ship.ship_def_id + " mode=" + str(mode) + " loaded=" + str(loaded) + " " + action + " W=" + str(with_forward))
		if with_forward:
			var acceleration: Vector3 = host.world.flight.velocity - prior_velocity
			thrust_coherent = acceleration.length() > 0.0 and acceleration.normalized().dot(last_step_view_thrust) > 0.999 and thrust_coherent
	var label: String = ship.ship_def_id + " mode=" + str(mode) + " loaded=" + str(loaded) + " " + action + " W=" + str(with_forward)
	check(max_error < 0.0006 and limited, "12 actual ticks keep requested yaw progress and one catalog budget " + label)
	check(thrust_coherent if with_forward else host.world.flight.velocity.is_zero_approx(), "manual yaw preserves visible W thrust or idle linear motion " + label)
	var view_after: Vector3 = host.camera.control_forward()
	var visible_progress: float = axis.dot(view_start.cross(view_after)) * sign_value
	check(visible_progress > 0.0 and view_after.is_finite(), "rendered camera turns coherently with the physical manual yaw " + label)
	var rendered_after: Basis = host.camera.render_ship_transform().basis
	var rendered_progress: float = axis.dot((-rendered_start.z).cross(-rendered_after.z)) * sign_value
	check(host.camera.orbit.is_equal_approx(orbit_start), "held manual yaw retains the explicitly dragged free-look offset " + label)
	if mode == T.CameraMode.FRONT:
		var expected_view: Basis = rendered_after * Basis(Vector3.UP, orbit_start.x) * Basis(Vector3.RIGHT, orbit_start.y)
		check(pose_error(host.camera.camera.global_basis, expected_view) < 0.00003, "front render follows the actual interpolated hull and retained observation throughout manual yaw " + label)
	samples.append({"scope": "matrix", "ship_id": ship.ship_def_id, "mode": int(mode), "loaded": loaded, "action": action, "forward": with_forward, "turn_radps": float(metrics.turn_radps), "mass_kg": float(metrics.total_mass_kg), "expected_12tick_rad": budget * 12.0, "maximum_pose_error_rad": max_error, "visible_signed_progress": visible_progress, "rendered_ship_signed_progress": rendered_progress, "rendered_physical_lag_rad": pose_error(rendered_after, host.world.flight.global_basis), "orbit_unchanged": host.camera.orbit.is_equal_approx(orbit_start)})
	matrix_cases += 1
	release_actions()

func ws_only_checks(ship: D.ShipStateDto, mode: T.CameraMode, loaded: bool) -> void:
	for action: String in ["forward", "back"]:
		reset_pose(mode)
		drag_view(Vector2(-130.0, -95.0))
		await settle_view()
		var view: Vector3 = host.camera.control_forward()
		var forward: Vector3 = -host.world.flight.global_basis.z
		var before: Quaternion = host.world.flight.quaternion
		var budget: float = float(host.gameplay.call("metrics", ship).turn_radps) * dt
		Input.action_press(action)
		await fixed_step()
		var after_forward: Vector3 = -host.world.flight.global_basis.z
		var sign_value: float = 1.0 if action == "forward" else -1.0
		var velocity: Vector3 = host.world.flight.velocity
		check(after_forward.dot(view) > forward.dot(view) and bounded(before, budget), "WS alone still aligns the real hull toward visible 3D observation " + ship.ship_def_id + " mode=" + str(mode) + " loaded=" + str(loaded) + " " + action)
		check(velocity.length() > 0.0 and velocity.normalized().dot(view * sign_value) > 0.999, "WS-only acceleration uses the actual visible heading " + ship.ship_def_id + " mode=" + str(mode) + " " + action)
		release_actions()

func mixed_checks(ship: D.ShipStateDto, mode: T.CameraMode) -> void:
	reset_pose(mode, Basis(Vector3.RIGHT, 0.55) * Basis(Vector3.FORWARD, 0.35))
	await settle_view()
	var before: Basis = host.world.flight.global_basis
	var yaw_world: Vector3 = yaw_axis(mode, before)
	# Independent geometric reference: pitch about actual right, yaw about the
	# mode's up axis, explicit positive roll about actual forward. Shared budget.
	var combined: Vector3 = ((before.x + yaw_world - before.z) / sqrt(3.0)).limit_length(1.0)
	var budget: float = float(host.gameplay.call("metrics", ship).turn_radps) * dt
	var expected: Basis = Basis(combined.normalized(), budget * combined.length()) * before
	Input.action_press("pitch_up"); Input.action_press("yaw_left"); Input.action_press("roll_right"); Input.action_press("forward")
	await fixed_step()
	check(pose_error(host.world.flight.global_basis, expected) < 0.0003 and bounded(before.get_rotation_quaternion(), budget), "W plus mixed pitch/yaw/roll keeps the geometric command and total budget " + ship.ship_def_id + " mode=" + str(mode))
	release_actions()

func guard_checks() -> void:
	reset_pose(T.CameraMode.FOLLOW)
	await settle_view()
	var before: Transform3D = host.world.flight.global_transform
	var view_before: Basis = host.camera.camera.global_basis
	host.ui.show_page("pause")
	Input.action_press("yaw_left"); Input.action_press("forward")
	host._read_flight_input(dt)
	host._physics_process(dt)
	check(not host._keyboard_control_allowed() and host.world.flight.intent.yaw_request == 0.0 and host.world.flight.intent.thrust_z == 0.0 and host.world.flight.global_transform.is_equal_approx(before) and host.camera.camera.global_basis.is_equal_approx(view_before), "production pause guards block manual yaw, thrust and camera steering")
	host._process(0.0)
	release_actions(); host.ui.show_page(""); host._sync_mouse_mode()
	Input.action_press("yaw_left")
	host._read_flight_input(dt)
	var pending: bool = not is_zero_approx(host.world.flight.intent.yaw_request)
	host._process(0.0)
	check(pending and host.world.flight.intent.yaw_request == 0.0 and host.world.flight.intent.thrust_z == 0.0 and host.world.flight.global_transform.is_equal_approx(before), "actual menu-close render clears transient steering without altering the ship pose")
	release_actions()
	# show_page deferred focus cleanup must finish before a new real text field
	# acquires focus; otherwise the fixture itself immediately releases it.
	await frames(2)
	var editor := TextEdit.new()
	editor.position = Vector2(480, 220); editor.size = Vector2(320, 160)
	host.ui.root.add_child(editor); editor.grab_focus()
	await frames(2)
	var focused: Control = host.get_viewport().gui_get_focus_owner()
	print("MANUAL_TURN_V14_FOCUS_JSON " + JSON.stringify({"focus_class": focused.get_class() if focused != null else "none", "editor_is_focus_owner": focused == editor, "editor_visible": editor.is_visible_in_tree(), "keyboard_blocked": host.ui.keyboard_blocked(), "keyboard_allowed": host._keyboard_control_allowed(), "page": host.ui.page, "busy": host.busy}))
	Input.action_press("yaw_right"); Input.action_press("forward")
	host._read_flight_input(dt)
	check(focused == editor and editor.is_visible_in_tree() and host.ui.keyboard_blocked() and not host._keyboard_control_allowed() and host.world.flight.intent.yaw_request == 0.0 and host.world.flight.intent.thrust_z == 0.0, "real TextEdit focus blocks steering through production UI checks")
	release_actions(); editor.release_focus(); editor.queue_free(); await frames(2)

func _run() -> void:
	old_fps = Engine.max_fps; old_hz = Engine.physics_ticks_per_second; old_interpolation = physics_interpolation
	if DisplayServer.get_name() != "headless": old_mouse = root.get_mouse_position()
	Engine.max_fps = 144; physics_interpolation = true
	root.size = Vector2i(1440, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_size = root.size
	baseline_only = OS.get_environment("XJ_MANUAL_TURN_V14_SCOPE") == "baseline"
	host = Main.new()
	host.progress_database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/manual-turn-v14-%d.db" % Time.get_ticks_usec())
	root.add_child(host); host.set_process(false); host.set_physics_process(false)
	await frames()
	if not check(host.services_ready, "actual Main opens fresh tmp SQLite and immutable formal catalog"): await finish(); return
	await host._command("new_world", "操舰响应独立验收", 1, "")
	if not check(host.state != null, "actual production new-world endpoint completes"): await finish(); return
	Engine.physics_ticks_per_second = int(host.store.catalog.rule("simulation_hz")); dt = 1.0 / float(Engine.physics_ticks_per_second)
	await host._command("undock", "", 1, "")
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	if not check(not host.busy and host.state.ship().status == T.ShipStatus.FLYING, "production undock and its writer complete before input tests"): await finish(); return
	var station: Node3D
	for id: String in host.world.targets:
		if str(host.world.targets[id].kind) == "station": station = host.world.targets[id].node; break
	if not check(station != null, "actual current sector exposes the formal station anchor"): await finish(); return
	origin = station.global_position + Vector3(0, 2400, 8000)
	host.ui.show_page(""); host._sync_mouse_mode(); host.world.flight.metrics = host.gameplay.call("metrics", host.state.ship())
	reset_pose(T.CameraMode.FOLLOW)
	if not await native_focus(): await finish(); return
	await baseline_checks()
	if baseline_only: await finish(); return
	for definition: Dictionary in host.store.catalog.rows("ship_defs"):
		var inventory: RefCounted = host.gameplay.get("inventory")
		var ship := inventory.call("create_ship", str(definition.ship_id), "station_anchor_port") as D.ShipStateDto
		if not check(ship != null and fit_weapon(ship), "declared owned hull and fitted-weapon fixture " + str(definition.ship_id)): continue
		if not await activate_ship(ship): break
		fleet_ids.append(ship.ship_def_id)
		var empty_metrics: Dictionary = host.gameplay.call("metrics", ship)
		check(float(empty_metrics.installed_mass_kg) > 0.0 and float(empty_metrics.payload_mass_kg) == 0.0 and float(empty_metrics.turn_radps) < float(definition.turn_rad_s), "actual empty fitted metrics include equipment mass " + ship.ship_def_id)
		for loaded: bool in [false, true]:
			if loaded:
				if not add_legal_cargo(ship): break
				var loaded_metrics: Dictionary = host.gameplay.call("metrics", ship)
				check(float(loaded_metrics.turn_radps) < float(empty_metrics.turn_radps), "real capacity-checked load slows measured turning " + ship.ship_def_id)
			for mode_value: int in [T.CameraMode.FOLLOW, T.CameraMode.FRONT, T.CameraMode.TACTICAL]:
				var mode: T.CameraMode = mode_value as T.CameraMode
				for action: String in ["yaw_left", "yaw_right"]:
					for with_forward: bool in [false, true]: await yaw_case(ship, mode, loaded, action, with_forward)
				await ws_only_checks(ship, mode, loaded)
				await mixed_checks(ship, mode)
	await guard_checks()
	check(fleet_ids.size() == 9 and matrix_cases == 216, "full matrix covers nine real hulls, three cameras, empty/loaded and A/D with/without W")
	await finish()

func finish() -> void:
	release_actions()
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(2); await create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless": root.warp_mouse(old_mouse)
	Engine.max_fps = old_fps; Engine.physics_ticks_per_second = old_hz; physics_interpolation = old_interpolation
	var report := {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "baseline_only": baseline_only, "baseline_cases": baseline_cases, "matrix_cases": matrix_cases, "fleet_ship_ids": fleet_ids, "maximum_turn_budget_ratio": maximum_budget_ratio, "backend": DisplayServer.get_name(), "fixture": "fresh tmp SQLite; actual Main callbacks; nine explicitly granted owned formal hulls and fitted weapons; real capacity-checked cargo; staging poses; no permission predicate override; no natural campaign claim", "samples": samples}
	print("MANUAL_TURN_V14_FINAL_JSON " + JSON.stringify(report))
	print("MANUAL_TURN_V14_RESULT %s checks=%d failures=%d" % [report.result, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
