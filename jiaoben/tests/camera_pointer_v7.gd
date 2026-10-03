extends SceneTree
## New pointer/keyboard contract. Fresh SQLite and real physics/render boundaries;
## no private progress, no historical mouse-steering probe masquerading as this model.
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
const Main = preload("res://runtime/main.gd")
const Factory = preload("res://runtime/visuals/visual_factory.gd")
const MotionDriver = preload("camera_motion_v7.gd")
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var host: Main
var database_path: String
var original_max_fps: int
var original_physics_hz: int
var original_interpolation: bool
var pointer_position: Vector2 = Vector2(720, 450)

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): print("CAMERA_POINTER_V7_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 2) -> void:
	for frame: int in range(count): await process_frame

func prepare_native_world_input() -> bool:
	if DisplayServer.get_name() == "headless": return true
	# Synthetic event.position only belongs to that event; Main's hover guard
	# still reads the real OS pointer, and its keyboard guard reads window focus.
	# Keep both production guards intact and prepare their actual native inputs.
	root.grab_focus()
	host.get_viewport().warp_mouse(Vector2(root.size) * 0.5)
	await frames(4)
	await RenderingServer.frame_post_draw
	if not root.has_focus():
		print("CAMERA_POINTER_V7_NATIVE_FOCUS_REQUIRED raise the game window within 30 seconds")
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline:
			await process_frame
	# Raising a macOS CLI application may leave the pointer in the other app;
	# warp again after the observed focus boundary, then render the real hover.
	host.get_viewport().warp_mouse(Vector2(root.size) * 0.5)
	await frames(4)
	await RenderingServer.frame_post_draw
	return check(root.has_focus() and host._keyboard_control_allowed() and not host.ui.ui_input_blocked(), "native window has actual focus and OS pointer is in unobstructed flight space")

func release_actions() -> void:
	for action: StringName in InputMap.get_actions(): Input.action_release(action)

func start_host() -> void:
	host = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	host.set_process(false)
	host.set_physics_process(false)
	await frames()
	check(host.services_ready, "actual Main prepares current assets and fresh scoped SQLite")

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "actual writer completes at a stable boundary")

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames()
	await create_timer(0.25).timeout

func motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	pointer_position += relative
	event.position = pointer_position
	event.relative = relative
	event.screen_relative = relative
	host._input(event)

func right_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	if pressed: host._unhandled_input(event)
	else: host._input(event)

func left_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pointer_position
	event.pressed = pressed
	if pressed: host._unhandled_input(event)
	else: host._input(event)

func wheel(up: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	host._unhandled_input(event)

func fixed_step() -> void:
	await physics_frame
	host._physics_process(1.0 / float(Engine.physics_ticks_per_second))

func reset_pose(value: Transform3D, velocity: Vector3 = Vector3.ZERO) -> void:
	host.world.flight.global_transform = value
	host.world.flight.velocity = velocity
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.camera.step(0.0)
	host.ui.tick(1.0)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/logs/camera-pointer-v7-" + label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "native camera/pointer capture " + label)
	captures += 1

func _run() -> void:
	original_max_fps = Engine.max_fps
	original_physics_hz = Engine.physics_ticks_per_second
	original_interpolation = physics_interpolation
	physics_interpolation = true
	Engine.max_fps = 144
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	var catalog := XJCatalog.new()
	if not check(catalog.open(), "open the formal read-only camera and flight catalog"):
		await finish(); return
	Engine.physics_ticks_per_second = int(catalog.rule("simulation_hz"))
	await component_checks(catalog)
	catalog.close()
	if OS.get_environment("XJ_CAMERA_V7_SCOPE") == "components": await finish(); return
	database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/camera-pointer-v7-%d.db" % Time.get_ticks_usec())
	await start_host()
	if not host.services_ready: await finish(); return
	await host._command("new_world", "常驻指针与键盘操舰独立验收", 1, "")
	if not check(host.state != null, "create actual single-player world through Main and SQLite"):
		await finish(); return
	await host._command("undock", "", 1, "")
	await wait_writer()
	host.ui.show_page("")
	host._sync_presentation_stage()
	host._sync_mouse_mode()
	# Main's first authoritative tick computes the actual equipped metrics before
	# calling its input reader; do not bypass that lifecycle in this fixture.
	await fixed_step()
	if not await prepare_native_world_input(): await finish(); return
	await input_checks()
	await persistence_checks()
	await finish()

func component_checks(catalog: XJCatalog) -> void:
	var actions: Array[String] = ["forward", "back", "left", "right", "up", "down", "pitch_up", "pitch_down", "yaw_left", "yaw_right", "roll_left", "roll_right", "brake", "boost", "observe", "fire", "target", "camera"]
	for action: String in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var look := XJFlightLook.new()
	check(look.keyboard_turn().is_zero_approx() and not look.manual_override_requested(), "idle keyboard has no ship turn or navigation takeover")
	for action: String in actions:
		Input.action_press(action)
		check(look.manual_override_requested() == (action not in ["boost", "observe", "fire", "target", "camera"]), "only explicit movement takes over navigation: " + action)
		Input.action_release(action)
	for row: Array in [["pitch_up", Vector3.RIGHT], ["pitch_down", Vector3.LEFT], ["yaw_left", Vector3.UP], ["yaw_right", Vector3.DOWN], ["roll_right", Vector3.BACK], ["roll_left", Vector3.FORWARD]]:
		Input.action_press(row[0])
		check(look.keyboard_turn().is_equal_approx(row[1]), "local attitude direction " + row[0])
		Input.action_release(row[0])
	Input.action_press("pitch_up"); Input.action_press("yaw_left"); Input.action_press("roll_right")
	check(is_equal_approx(look.keyboard_turn().length(), 1.0), "combined keyboard attitude shares one authoritative turn budget")
	release_actions()
	var stage := Node3D.new()
	root.add_child(stage)
	var rig := XJCameraRig.new()
	stage.add_child(rig)
	check(rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF and rig.camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF and rig.camera.top_level, "render camera is independent and never automatically interpolated twice")
	for definition: Dictionary in catalog.rows("ship_defs"):
		var wrapper: CharacterBody3D = Factory.scene(str(definition.ship_id))
		var flight := XJFlight.new()
		for child: Node in wrapper.get_children():
			wrapper.remove_child(child); child.owner = null; flight.add_child(child)
		wrapper.free()
		stage.add_child(flight)
		var record := D.ShipStateDto.new()
		record.ship_instance_id = "camera_v7_" + str(definition.ship_id)
		record.ship_def_id = definition.ship_id
		record.status = T.ShipStatus.FLYING
		record.quat_w = 1.0
		flight.bind(record, catalog)
		flight.visual = flight.get_node("VisualRoot")
		flight.metrics = {"turn_radps": float(definition.turn_rad_s), "speed_mps": float(definition.max_speed_mps), "acceleration_mps2": float(definition.acceleration_mps2), "strafe_multiplier": float(catalog.rule("strafe_acceleration_multiplier")), "reverse_multiplier": float(catalog.rule("reverse_acceleration_multiplier")), "brake_multiplier": float(catalog.rule("brake_acceleration_multiplier"))}
		for camera_mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.TACTICAL, T.CameraMode.FRONT]:
			flight.global_transform = Transform3D(Basis.from_euler(Vector3(0.2, -0.4, 0.3)), Vector3(10000, 2000, -4000))
			flight.velocity = Vector3(11, -3, -17)
			flight.write_back(); flight.get_global_transform_interpolated(); flight.reset_physics_interpolation()
			rig.bind(flight, catalog, camera_mode); rig.step(0.0)
			var pose: Transform3D = flight.global_transform
			var velocity: Vector3 = flight.velocity
			rig.begin_observation(); rig.observe(Vector2(230, -100), 0.002); rig.step(1.0)
			var held: Vector2 = rig.orbit
			var basis: Basis = rig.observation_basis
			rig.end_observation()
			var persisted: bool = true
			for frame: int in range(24):
				rig.step(1.0 / 144.0)
				persisted = persisted and rig.orbit.is_equal_approx(held) and rig.observation_basis.is_equal_approx(basis) and not rig.observing
			check(persisted and not held.is_zero_approx() and pose.is_equal_approx(flight.global_transform) and velocity.is_equal_approx(flight.velocity), "%s mode%d drag release keeps the free angle across repeated frames and never moves ship" % [definition.ship_id, camera_mode])
			if camera_mode == T.CameraMode.FRONT:
				var front: Node3D = flight.get_node("FrontCamera")
				var expected: Transform3D = rig.render_ship_transform() * front.transform
				check(rig.camera.global_position.is_equal_approx(expected.origin) and not flight.visual.visible, "%s FRONT uses interpolated ship-local anchor and explains hidden exterior" % definition.ship_id)
			else:
				rig.snapped = false; rig.step(0.0)
				var view_basis: Basis = rig.camera.global_basis
				flight.rotate_object_local(Vector3.RIGHT, 0.9); flight.rotate_object_local(Vector3.UP, -0.6); flight.rotate_object_local(Vector3.BACK, 0.4)
				flight.reset_physics_interpolation(); rig.step(1.0)
				check(rig.camera.global_basis.is_equal_approx(view_basis) and rig.camera.unproject_position(rig.render_position()).distance_to(Vector2(root.size) * 0.5) < 0.02, "%s mode%d ship attitude does not rotate the retained observation reference" % [definition.ship_id, camera_mode])
				var zoom_before: float = rig.zoom
				rig.scroll_zoom(-2); rig.step(1.0)
				check(rig.zoom < zoom_before and flight.global_position.is_equal_approx(pose.origin) and velocity.is_equal_approx(flight.velocity), "%s mode%d wheel changes only camera distance" % [definition.ship_id, camera_mode])
				rig.observe(Vector2(50000, -50000), 0.002); rig.step(1.0)
				var elevation: float = asin(clampf((rig.camera.global_position - rig.render_position()).normalized().dot(rig.observation_basis.y), -1.0, 1.0))
				check(absf(elevation) <= float(catalog.one("presentation_defs", "presentation_id", "camera_orbit_pitch_limit_rad").value_real) + 0.0001 and rig.camera.global_basis.is_finite() and absf(rig.camera.global_basis.determinant() - 1.0) < 0.0001, "%s mode%d large drag stays within SQLite pitch bounds without flipping" % [definition.ship_id, camera_mode])
			rig.reset_observation(); rig.step(1.0)
			check(rig.orbit.is_zero_approx() and not rig.observing, "%s mode%d only explicit reset recenters observation" % [definition.ship_id, camera_mode])
			var forward_before: Vector3 = rig.control_forward()
			var yaw_step: float = float(definition.turn_rad_s) / float(Engine.physics_ticks_per_second)
			var yaw_axis: Vector3 = rig.render_ship_transform().basis.y if camera_mode == T.CameraMode.FRONT else rig.observation_basis.y
			rig.steer_yaw(yaw_step)
			check(rig.control_forward().is_equal_approx(Basis(yaw_axis, yaw_step) * forward_before) and flight.global_position.is_equal_approx(pose.origin) and velocity.is_equal_approx(flight.velocity), "%s mode%d manual camera yaw exposes the newly visible thrust heading without moving ship" % [definition.ship_id, camera_mode])
		if definition.ship_id == "shuttle_swift": await interpolation_checks(stage, flight, rig, catalog)
		stage.remove_child(flight); flight.free()
	stage.free()

func interpolation_checks(stage: Node3D, flight: XJFlight, rig: XJCameraRig, catalog: XJCatalog) -> void:
	flight.global_transform = Transform3D(Basis.IDENTITY, Vector3(10000, 2000, -4000))
	flight.velocity = Vector3(80, 30, -120)
	flight.get_global_transform_interpolated(); flight.reset_physics_interpolation()
	rig.bind(flight, catalog, T.CameraMode.FOLLOW)
	rig.begin_observation(); rig.observe(Vector2(180, -90), 0.002); rig.end_observation()
	flight.intent.pitch_request = 0.2
	flight.intent.yaw_request = -0.3
	var driver := MotionDriver.new()
	driver.flight = flight; driver.rig = rig; stage.add_child(driver)
	driver.moving = true
	await create_timer(1.3).timeout
	driver.moving = false
	var coherent: bool = true
	var centered: bool = true
	var between_ticks: int = 0
	for sample: Dictionary in driver.render_samples:
		coherent = coherent and sample.displayed.is_equal_approx(sample.expected)
		centered = centered and sample.center_error < 0.02
		if sample.displayed.origin.distance_to(sample.physical.origin) > 0.001 and sample.fraction > 0.01 and sample.fraction < 0.99: between_ticks += 1
	check(driver.physics_steps > 30 and driver.render_samples.size() > driver.physics_steps and between_ticks > 10, "actual 144 render / catalog physics cadence samples genuine poses between moving fixed ticks")
	check(coherent and centered, "actual interpolated moving/turning mesh pose remains at camera center in every render frame")
	flight.intent = D.FlightInputDto.new(); flight.velocity = Vector3.ZERO
	flight.global_transform = Transform3D(Basis.IDENTITY, Vector3(-9000, 5000, 12000))
	flight.get_global_transform_interpolated(); flight.reset_physics_interpolation()
	await physics_frame
	await process_frame
	rig.snapped = false; rig.step(0.0)
	check(rig.render_position().is_equal_approx(flight.global_position), "teleport reset eliminates interpolation from prior ship position")
	var endpoints: Array[Vector3] = []
	# Settle comparisons near the origin so large world-coordinate float32
	# rounding does not masquerade as a difference in exponential timing.
	flight.global_position = Vector3.ZERO; flight.reset_physics_interpolation()
	await physics_frame; await process_frame
	for hz: int in [30, 60, 144]:
		rig.bind(flight, catalog, T.CameraMode.FOLLOW); rig.step(0.0)
		rig.camera.global_position += Vector3(100, -80, 40)
		for frame: int in range(hz): rig.step(1.0 / float(hz))
		endpoints.append(rig.camera.global_position)
	check(endpoints[0].distance_to(endpoints[1]) < 0.002 and endpoints[1].distance_to(endpoints[2]) < 0.002, "camera settling is frame-rate independent at 30/60/144 Hz")
	driver.queue_free(); await frames()

func input_checks() -> void:
	var station_id: String = ""
	for id: String in host.world.targets:
		if str(host.world.targets[id].kind) == "station": station_id = id; break
	var station: Node3D = host.world.targets[station_id].node
	reset_pose(Transform3D(Basis.IDENTITY, station.global_position + Vector3(0, 600, 6000)))
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "flight begins with an immediately visible default pointer")
	var keys := {"pitch_up": KEY_UP, "pitch_down": KEY_DOWN, "yaw_left": KEY_A, "yaw_right": KEY_D}
	for action: String in keys:
		var bound: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == keys[action]: bound = true
		check(bound, "new keyboard attitude action has the documented physical key " + action)
	var left_is_fire: bool = false
	var control_is_fire: bool = false
	for event: InputEvent in InputMap.action_get_events("fire"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: left_is_fire = true
		if event is InputEventKey and event.physical_keycode == KEY_CTRL: control_is_fire = true
	check(control_is_fire and not left_is_fire, "Ctrl controls fixed weapon fire; pointer selection has no fire binding")
	check(not InputMap.has_action("pointer") and not InputMap.has_action("observe"), "Alt pointer toggle and right-observation bindings are removed")
	var initial: Transform3D = host.world.flight.global_transform
	motion(Vector2(400, -180)); host._read_flight_input(1.0 / 60.0)
	check(host.flight_look.keyboard_turn().is_zero_approx() and host.flight_look.pending_angles.is_zero_approx() and host.world.flight.intent.yaw_request == 0.0 and host.world.flight.intent.pitch_request == 0.0 and host.world.flight.global_transform.is_equal_approx(initial), "ordinary pointer movement never queues or requests ship steering")
	# reset_pose updates the body immediately, but a native render interpolation
	# pump can still expose its prior sample until a genuine fixed/render boundary.
	# Re-evaluate the camera after that boundary before projecting a pick point.
	await physics_frame
	await frames(4)
	host.camera.snapped = false
	host._process(0.0)
	check(host.camera.render_position().is_equal_approx(host.world.flight.global_position) and host.camera.camera.unproject_position(host.camera.render_position()).distance_to(Vector2(root.size) * 0.5) < 0.02, "settled scene-pick fixture uses the current stationary ship pose and centered camera")
	pointer_position = host.camera.camera.unproject_position(station.global_position)
	if DisplayServer.get_name() != "headless":
		host.get_viewport().warp_mouse(pointer_position)
		await frames(4)
		await RenderingServer.frame_post_draw
		check(root.has_focus() and not host.ui.ui_input_blocked() and host.ui.root.get_global_mouse_position().distance_to(pointer_position) < 2.0, "native scene-pick OS pointer occupies the projected station in unobstructed world space")
	var ray_target: String = host._world_target_at(pointer_position)
	check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(pointer_position) and not host.camera.camera.is_position_behind(station.global_position) and ray_target == station_id, "actual settled camera ray hits the physical station at its visible projected position")
	print("CAMERA_POINTER_V7_SCENE_PICK before point=%s os=%s ray=%s station=%s camera=%s ship=%s blocked=%s" % [pointer_position, host.ui.root.get_global_mouse_position(), ray_target, station_id, host.camera.camera.global_position, host.world.flight.global_position, host.ui.ui_input_blocked()])
	host.ui.target_id = ""
	left_button(true); left_button(false)
	check(host.pointer_pick_pending and not host.fire_held and not host.local_navigation.active(), "scene single click queues only selection at the physical boundary")
	await fixed_step()
	print("CAMERA_POINTER_V7_SCENE_PICK after selected=%s pending=%s fire=%s projectiles=%d navigation=%s blocked=%s ray=%s" % [host.ui.target_id, host.pointer_pick_pending, host.fire_held, host.world.projectiles.active.size(), host.local_navigation.active(), host.ui.ui_input_blocked(), host._world_target_at(pointer_position)])
	# Direct Main handlers test the production queued-pick boundary, rather than
	# claiming native viewport/GUI event consumption (covered by the UI suite).
	check(host.ui.target_id == station_id and not host.pointer_pick_pending and not host.fire_held and host.world.projectiles.active.is_empty() and not host.local_navigation.active(), "actual Main click handlers select the station at the physical boundary without firing or approaching")
	if DisplayServer.get_name() != "headless":
		host.get_viewport().warp_mouse(Vector2(root.size) * 0.5)
		await frames(4)
	check(host._navigation_command("warp", station_id), "actual warp starts from durable stationary origin")
	motion(Vector2(480, 200))
	var starting: Transform3D = host.world.flight.global_transform
	var velocity: Vector3 = host.world.flight.velocity
	var orbit_before: Vector2 = host.camera.orbit
	right_button(true); motion(Vector2(220, -120)); right_button(false)
	check(not host.observing and host.camera.orbit.is_equal_approx(orbit_before) and host.local_navigation.warp_active(), "right button is entirely inactive and leaves view and warp untouched")
	pointer_position = Vector2(720, 450)
	left_button(true); motion(Vector2(220, -120)); left_button(false)
	var free_angle: Vector2 = host.camera.orbit
	var zoom_before: float = host.camera.zoom
	wheel(true)
	for frame: int in range(24):
		await process_frame
		host._process(1.0 / 144.0)
	check(host.local_navigation.warp_active() and host.local_navigation.phase == "warmup" and not host.observing and not host.camera.observing and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not free_angle.is_zero_approx() and host.camera.orbit.is_equal_approx(free_angle) and host.camera.zoom < zoom_before and not host.pointer_pick_pending and starting.is_equal_approx(host.world.flight.global_transform) and velocity.is_equal_approx(host.world.flight.velocity), "pointer movement, left-drag release and wheel preserve warp, ship motion and held angle; dragging cannot become a click")
	var charge_steps: int = 0
	while host.local_navigation.phase == "warmup" and charge_steps < 1400:
		await fixed_step(); charge_steps += 1
	check(charge_steps < 1400 and host.local_navigation.phase == "travel", "actual charged warp enters physical travel before observing moving flight")
	pointer_position = Vector2(720, 450)
	left_button(true); motion(Vector2(-70, 40))
	var before_travel: Vector3 = host.world.flight.global_position
	for tick: int in range(3): await fixed_step()
	check(host.observing and host.local_navigation.warp_active() and host.local_navigation.phase == "travel" and host.world.flight.global_position.distance_to(before_travel) > 1.0 and host.world.flight.velocity.length() > 0.0, "left drag during actual moving warp leaves its physical controller advancing")
	var before_release: Vector3 = host.world.flight.velocity
	left_button(false)
	check(host.world.flight.velocity.is_equal_approx(before_release) and host.local_navigation.warp_active(), "release of moving warp observation preserves instantaneous velocity and accepted order")
	host._command("nav_stop", "", 1, ""); await wait_writer()
	check(host._navigation_command("orbit", station_id), "actual 3D orbit accepts the selected station")
	pointer_position = Vector2(720, 450)
	left_button(true); motion(Vector2(-130, 60)); left_button(false); wheel(false)
	for frame: int in range(12): await process_frame; host._process(1.0 / 144.0)
	check(host.local_navigation.active() and host.local_navigation.mode == "orbit", "left observation, ordinary pointer and zoom never cancel automatic orbit")
	pointer_position = Vector2(720, 450)
	left_button(true); motion(Vector2(60, 25))
	for tick: int in range(3): await fixed_step()
	var inertial_velocity: Vector3 = host.world.flight.velocity
	left_button(false)
	check(host.local_navigation.active() and host.local_navigation.mode == "orbit" and inertial_velocity.length() > 0.0 and host.world.flight.velocity.is_equal_approx(inertial_velocity), "observing active orbit keeps actual bounded flight and release never stops its inertia")
	var accepted_target: String = host.local_navigation.target_id
	check(not host._navigation_command("warp", "unavailable-v7-fixture") and host.local_navigation.active() and host.local_navigation.mode == "orbit" and host.local_navigation.target_id == accepted_target, "invalid replacement command leaves the already accepted orbit intact")
	Input.action_press("pitch_up")
	await fixed_step(); await fixed_step()
	check(not host.local_navigation.active() and host.world.flight.intent.pitch_request > 0.0 and host.world.flight.global_basis.z.distance_to(starting.basis.z) > 0.00001, "explicit keyboard pitch takes navigation over and rotates the actual 3D vessel")
	check(host.world.flight.velocity.is_equal_approx(inertial_velocity), "manual attitude takeover preserves the existing normal-flight velocity")
	Input.action_release("pitch_up")
	await fixed_step()
	check(host.world.flight.intent.pitch_request == 0.0 and host.world.flight.intent.yaw_request == 0.0, "released attitude keys leave no residual turn request")
	var keyboard_axes := {"yaw_left": Vector2(1, 0), "yaw_right": Vector2(-1, 0), "pitch_up": Vector2(0, 1), "pitch_down": Vector2(0, -1)}
	for action: String in keyboard_axes:
		Input.action_press(action); host._read_flight_input(1.0 / 60.0)
		var expected: Vector2 = keyboard_axes[action]
		check(Vector2(host.world.flight.intent.yaw_request, host.world.flight.intent.pitch_request).is_equal_approx(expected), "actual Main reads manual attitude independently of visible pointer " + action)
		Input.action_release(action)
	host.world.flight.clear_intent()
	await view_thrust_checks(station.global_position + Vector3(0, 1800, 7000))
	var switch_event := InputEventAction.new(); switch_event.action = "camera"; switch_event.pressed = true
	host._unhandled_input(switch_event)
	check(host.camera.orbit.is_zero_approx() and host.state.player().camera_mode == host.camera.mode, "explicit V recenters observation and retains the existing saved camera enum")
	await capture("default-pointer")
	host._command("show_ship", "", 1, "")
	check(host.camera.mode == T.CameraMode.FOLLOW and host.camera.orbit.is_zero_approx() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "show-ship recovers centered exterior without hiding the pointer")
	host.ui.show_page("pause"); host._sync_mouse_mode()
	var paused: Transform3D = host.world.flight.global_transform
	pointer_position = Vector2(720, 450)
	motion(Vector2(150, 60)); left_button(true)
	Input.action_press("yaw_left"); host._read_flight_input(1.0 / 60.0)
	check(not host.observing and host.world.flight.intent.yaw_request == 0.0 and host.world.flight.global_transform.is_equal_approx(paused), "pause blocks both observation and keyboard flight")
	release_actions(); left_button(false); host.ui.show_page("")
	host._sync_mouse_mode()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "resuming flight keeps the default pointer visible")
	if not await prepare_native_world_input(): return
	await overview_and_combat_checks()

func view_thrust_checks(origin: Vector3) -> void:
	for action: String in ["forward", "back"]:
		reset_pose(Transform3D(Basis.IDENTITY, origin))
		if not await prepare_native_world_input(): return
		pointer_position = Vector2(720, 450)
		left_button(true); motion(Vector2(180, -230)); left_button(false)
		host.camera.snapped = false; host.camera.step(0.0)
		var heading: Vector3 = host.camera.control_forward()
		var before: Quaternion = host.world.flight.quaternion
		Input.action_press(action); await fixed_step(); Input.action_release(action)
		var sign_value: float = 1.0 if action == "forward" else -1.0
		var actual_velocity: Vector3 = host.world.flight.velocity
		var turned: float = before.angle_to(host.world.flight.quaternion)
		check(actual_velocity.length() > 0.0 and actual_velocity.normalized().dot(heading * sign_value) > 0.999 and absf(actual_velocity.y) > 0.001, "actual " + action + " acceleration follows the current observed 3D direction")
		check(turned > 0.0 and turned <= float(host.world.flight.metrics.turn_radps) / float(Engine.physics_ticks_per_second) + 0.0001, "ship aligns toward view using the authoritative finite turn budget: " + action)
		var released: Basis = host.world.flight.global_basis
		await fixed_step()
		check(host.world.flight.global_basis.is_equal_approx(released), "view-following attitude has no residual request after WS is released: " + action)
	reset_pose(Transform3D(Basis.IDENTITY, origin))
	if not await prepare_native_world_input(): return
	var initial_heading: Vector3 = host.camera.control_forward()
	Input.action_press("forward"); Input.action_press("yaw_left")
	var coherent: bool = true
	for tick: int in range(12):
		var before_velocity: Vector3 = host.world.flight.velocity
		await fixed_step()
		var acceleration: Vector3 = host.world.flight.velocity - before_velocity
		coherent = coherent and acceleration.length() > 0.0 and acceleration.normalized().dot(host.camera.control_forward()) > 0.998
	Input.action_release("forward"); Input.action_release("yaw_left")
	check(coherent and initial_heading.angle_to(host.camera.control_forward()) > 0.05 and absf(host.world.flight.global_basis.z.x) > 0.001, "W plus A bends both the visible heading and actual acceleration without steering back to the prior view")
	host._command("nav_stop", "", 1, ""); await wait_writer()

func overview_and_combat_checks() -> void:
	var station_id: String = ""
	var scenic_id: String = ""
	for id: String in host.world.targets:
		if str(host.world.targets[id].kind) == "station": station_id = id
		if bool(host.world.targets[id].get("navigation_only", false)): scenic_id = id
	var station: Node3D = host.world.targets[station_id].node
	reset_pose(Transform3D(Basis.IDENTITY, station.global_position + Vector3(0, 1800, 7000)))
	if not await prepare_native_world_input(): return
	var panel: XJOverviewPanel = host.ui.overview
	var commands: Array[Dictionary] = []
	var recorder: Callable = func(action: String, id: String): commands.append({"action": action, "id": id})
	panel.command.connect(recorder)
	panel.filter_mode = "all"; host.ui.tick(1.0)
	var button: Button = panel.target_buttons[station_id]
	host.ui._select_target("")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	# Button's native click dispatch is validated by the UI/native suite. Here
	# exercise its actual pressed -> selected -> Main path from an empty choice;
	# gui_input.emit alone does not synthesize Button's native pressed behavior.
	button.pressed.emit()
	check(host.ui.target_id == station_id and not host.local_navigation.active() and commands.is_empty(), "actual overview pressed selection action chooses from an empty target without any motion or weapon command")
	var held_angle: Vector2 = host.camera.orbit
	click.double_click = true; button.gui_input.emit(click)
	check(commands.size() == 1 and commands[0].action == "nav_approach" and commands[0].id == station_id and host.local_navigation.active() and host.local_navigation.mode == "approach" and host.local_navigation.target_id == station_id and host.camera.orbit.is_equal_approx(held_angle), "actual overview double-click handler issues exactly one accepted approach without resetting the observation angle")
	click.pressed = false; button.gui_input.emit(click)
	check(commands.size() == 1, "double-click release never repeats its motion command")
	var original_distance: float = host.world.flight.global_position.distance_to(station.global_position)
	for tick: int in range(12): await fixed_step()
	check(host.world.flight.global_position.distance_to(station.global_position) < original_distance and host.world.flight.velocity.length() <= float(host.world.flight.metrics.speed_mps) + 0.01, "overview approach produces actual bounded physical flight toward the selected object")
	if not scenic_id.is_empty():
		host.ui.tick(1.0)
		var before_count: int = commands.size()
		click.pressed = true; panel.target_buttons[scenic_id].gui_input.emit(click)
		check(commands.size() == before_count and host.local_navigation.target_id == station_id and host.ui.target_id == scenic_id, "double-click scenic body selects its bearing without replacing real navigation")
	panel.command.disconnect(recorder)
	host._command("nav_stop", "", 1, ""); await wait_writer()
	var weapon_range: float = 0.0
	for equipment: D.EquipmentStateDto in host.gameplay.call("equipped", host.state.ship()):
		var definition: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment.module_def_id)
		if str(definition.get("slot_type", "")) == "weapon" and equipment.enabled: weapon_range = maxf(weapon_range, float(definition.range_m))
	if not check(weapon_range > 0.0, "fresh ship exposes an actual catalog weapon for explicit combat checks"): return
	# Project an existing SQLite NPC prototype into runtime only; beyond weapon
	# range but inside sensors. This does not claim campaign unlock or natural play.
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	var definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", str(spawn.npc_id))
	var npc := D.NpcStateDto.new()
	npc.npc_instance_id = "camera-pointer-v7-npc-fixture"
	npc.spawn_id = str(spawn.spawn_id); npc.sector_id = host.state.current_sector(); npc.alive = true
	npc.shield = float(definition.shield_max); npc.armor = float(definition.armor_max); npc.hull = float(definition.hull_max)
	npc.behavior_phase = T.NpcPhase.PATROL
	var point: Vector3 = host.world.flight.global_position + Vector3(250, 180, -(weapon_range + 600.0))
	npc.pos_x = point.x; npc.pos_y = point.y; npc.pos_z = point.z
	if not check(host.state.add("npc_state", npc) and host.world.sync_entities(), "actual NPC sync creates a valid catalog-derived hostile fixture"): return
	var snapshots_before: int = int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	host.ui.target_id = npc.npc_instance_id
	var z := InputEventAction.new(); z.action = "combat_toggle"; z.pressed = true
	host._unhandled_input(z)
	check(host.auto_fire_target == npc.npc_instance_id and not host.local_navigation.active(), "explicit Z opens auto-fire without implicitly navigating")
	host._command("combat_engage", npc.npc_instance_id, 1, "")
	check(host.auto_fire_target == npc.npc_instance_id and host.local_navigation.mode == "approach" and host.local_navigation.target_id == npc.npc_instance_id, "actual engage command accepts approach before arming the same combat identity")
	await fixed_step()
	host.ui._select_target(station_id); host.ui.tick(1.0)
	var context: Dictionary = host.navigation_context(station_id)
	check(host.auto_fire_target == npc.npc_instance_id and not str(context.combat_target_title).is_empty() and panel.status_label.text.contains(str(context.combat_target_title)), "looking at a station retains the actual engaged enemy and names it in the visible status")
	host._command("nav_stop", "", 1, "")
	check(not host.local_navigation.active() and host.world.flight.velocity.is_zero_approx() and host.auto_fire_target == npc.npc_instance_id, "stop ship cancels motion without silently switching explicit automatic fire off")
	var control := InputEventAction.new(); control.action = "fire"; control.pressed = true
	host._unhandled_input(control)
	check(host.fire_held and host.auto_fire_target == npc.npc_instance_id, "Ctrl separately requests fixed weapon fire without replacing the automatic target")
	control.pressed = false; host._input(control)
	check(not host.fire_held and host.auto_fire_target == npc.npc_instance_id, "Ctrl release leaves explicit auto-fire armed")
	host.ui._select_target(station_id)
	host._unhandled_input(z)
	check(host.auto_fire_target.is_empty() and host.ui.target_id == station_id, "global Z stops the actual firing enemy even while a station is selected")
	host.ui._select_target(npc.npc_instance_id); host._unhandled_input(z)
	check(host.auto_fire_target == npc.npc_instance_id, "global Z with no fire order starts the newly selected actual enemy")
	host.ui.target_id = npc.npc_instance_id; host._unhandled_input(z)
	check(host.auto_fire_target.is_empty(), "explicit second Z ends auto-fire")
	await exit_save_checks(npc.npc_instance_id, snapshots_before)
	await exit_pending_input_checks(npc.npc_instance_id, snapshots_before)
	await text_focus_checks(npc.npc_instance_id)
	host.world.projectiles.clear(); host.pending_damage.clear(); host.auto_fire_target = ""
	host.state.remove("npc_state", npc)
	if host.world.npcs.has(npc.npc_instance_id): host.world.npcs[npc.npc_instance_id].queue_free(); host.world.npcs.erase(npc.npc_instance_id)
	host.world.targets.erase(npc.npc_instance_id); host.ui.target_id = station_id
	host.gameplay.combat_remaining_s = 0.0
	await frames()
	check(int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == snapshots_before and host.state.find("npc_state", "npc_instance_id", npc.npc_instance_id) == null and host.world.projectiles.active.is_empty() and host.pending_damage.is_empty(), "temporary combat fixture never enters a SQLite snapshot and is removed before persistence checks")

func exit_save_checks(npc_id: String, snapshots_before: int) -> void:
	for after: String in ["return_title", "quit"]:
		for navigating: bool in [false, true]:
			host.gameplay.combat_remaining_s = 0.0
			host.deferred_save = {}
			host.ui.set_operation_status("idle", "")
			host._command("combat_engage" if navigating else "combat_toggle", npc_id, 1, "")
			check(host.auto_fire_target == npc_id and host.local_navigation.active() == navigating, "exit-save fixture has explicit persistent fire and navigation=%s before %s" % [navigating, after])
			# Use the real hostile-attempt transition and its SQLite combat delay.
			# It defers the actual quit/title operation and keeps the temporary NPC
			# out of every snapshot; no mocked save method or production guard.
			host.gameplay.call("mark_hostile_attempt")
			host._request_save("quick", 0, after)
			check(host.auto_fire_target.is_empty() and not host.local_navigation.active() and str(host.deferred_save.get("after", "")) == after and host.state != null and not host.busy and int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == snapshots_before, "actual %s save request stops persistent automatic fire before waiting, navigation=%s" % [after, navigating])
			# The host's automatic physics callback remains frozen throughout this
			# scoped exit fixture; clear the test request before any next fixed tick.
			host.deferred_save = {}
			host.gameplay.combat_remaining_s = 0.0
			host.ui.set_operation_status("idle", "")

func exit_pending_input_checks(npc_id: String, snapshots_before: int) -> void:
	host.ui._select_target(npc_id)
	host._command("combat_toggle", npc_id, 1, "")
	pointer_position = Vector2(720, 450)
	left_button(true); left_button(false)
	left_button(true); motion(Vector2(80, -40))
	var control := InputEventAction.new(); control.action = "fire"; control.pressed = true
	Input.action_press("fire"); host._unhandled_input(control)
	var engine: D.EquipmentStateDto
	var weapon: D.EquipmentStateDto
	for equipment: D.EquipmentStateDto in host.gameplay.call("equipped", host.state.ship()):
		if equipment.module_def_id.begins_with("module_engine_") and equipment.enabled: engine = equipment
		if str(host.store.catalog.one("module_defs", "module_id", equipment.module_def_id).slot_type) == "weapon" and equipment.enabled: weapon = equipment
	var engine_ready: bool = false
	if engine != null:
		var definition: Dictionary = host.store.catalog.one("module_defs", "module_id", engine.module_def_id)
		var item := host.state.find("item_instance_state", "item_instance_id", engine.item_instance_id) as D.ItemInstanceStateDto
		engine_ready = item != null and item.durability > 0.0 and engine.cooldown_remaining_s <= 0.0 and not host.state.ship().overheated and host.state.ship().energy >= float(definition.energy_eu) and host.state.ship().heat + float(definition.heat_hu) <= float(host.world.flight.metrics.heat_max)
	check(host.fire_held and Input.is_action_pressed("fire") and host.pointer_pick_pending and host.pointer_drag_pressed and host.pointer_dragged and host.observing and host.auto_fire_target == npc_id and engine_ready and weapon != null, "actual exit-pending fixture holds Ctrl, queued pick, drag and automatic fire with a currently payable real engine")
	if not engine_ready or weapon == null:
		release_actions(); host._release_controls(); return
	host.gameplay.call("mark_hostile_attempt")
	host._request_save("quick", 0, "return_title")
	check(host._exit_save_pending() and not host._keyboard_control_allowed() and not host.fire_held and not host.pointer_pick_pending and not host.pointer_drag_pressed and not host.pointer_dragged and not host.observing and not host.camera.observing and host.auto_fire_target.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "actual exit request clears held fire and every pending pointer gesture before its stable-save wait")
	host._unhandled_input(control)
	check(not host.fire_held and host._exit_save_pending(), "new Ctrl press cannot rearm manual fire during an exit-save wait")
	var z := InputEventAction.new(); z.action = "combat_toggle"; z.pressed = true
	host._unhandled_input(z)
	check(host.auto_fire_target.is_empty() and host._exit_save_pending(), "new Z press cannot rearm automatic fire during an exit-save wait")
	host._command("combat_engage", npc_id, 1, "")
	check(host.auto_fire_target.is_empty() and not host.local_navigation.active() and host._exit_save_pending(), "engage command cannot start fire or approach during an exit-save wait")
	var energy: float = host.state.ship().energy
	var heat: float = host.state.ship().heat
	var cooldown: float = engine.cooldown_remaining_s
	var active: float = engine.active_remaining_s
	Input.action_press("boost"); host._read_flight_input(1.0 / float(Engine.physics_ticks_per_second))
	host._command("request_engine_cycle", "", 1, "")
	check(not host.world.flight.intent.engine_cycle_requested and is_equal_approx(host.state.ship().energy, energy) and is_equal_approx(host.state.ship().heat, heat) and is_equal_approx(engine.cooldown_remaining_s, cooldown) and is_equal_approx(engine.active_remaining_s, active) and host._exit_save_pending(), "keyboard boost and equipment command cannot consume or activate the real engine during an exit-save wait")
	host._command("nav_approach", npc_id, 1, "")
	check(not host.local_navigation.active() and host._exit_save_pending(), "new legal target navigation cannot restart motion during an exit-save wait")
	var enabled: bool = weapon.enabled
	host._command("set_module_enabled", weapon.item_instance_id, 1, "off")
	check(weapon.enabled == enabled and str(host.deferred_save.get("after", "")) == "return_title", "real equipment business command cannot mutate state or replace the pending exit request")
	var tick: int = host.state.snapshot.meta.simulation_tick
	var remaining: float = host.gameplay.combat_remaining_s
	await fixed_step()
	check(host.state.snapshot.meta.simulation_tick == tick + 1 and host.gameplay.combat_remaining_s < remaining and host._exit_save_pending() and not host.fire_held and host.world.projectiles.active.is_empty() and int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == snapshots_before, "exit-save wait continues real fixed cycles toward stability without firing or prematurely committing the NPC fixture")
	release_actions()
	host._command("cancel_save", "", 1, "")
	check(not host._exit_save_pending() and host.deferred_save.is_empty() and host._keyboard_control_allowed(), "actual cancel-save command restores legal keyboard control")
	Input.action_press("fire"); host._unhandled_input(control)
	check(host.fire_held, "a fresh Ctrl press is accepted again after canceling the exit-save wait")
	Input.action_release("fire"); control.pressed = false; host._input(control)
	host._command("nav_approach", npc_id, 1, "")
	check(host.local_navigation.active() and host.local_navigation.mode == "approach" and host.local_navigation.target_id == npc_id, "a fresh legal approach is accepted again after canceling the exit-save wait")
	host._command("nav_stop", "", 1, "")
	host.gameplay.combat_remaining_s = 0.0

func text_focus_checks(npc_id: String) -> void:
	host.ui._select_target(npc_id)
	host._command("combat_toggle", npc_id, 1, "")
	var editor := TextEdit.new()
	editor.position = Vector2(480, 220); editor.size = Vector2(320, 160)
	host.ui.root.add_child(editor)
	editor.grab_focus()
	await frames()
	check(host.get_viewport().gui_get_focus_owner() == editor and host.ui.keyboard_blocked() and not host._keyboard_control_allowed(), "actual TextEdit focus blocks flight keyboard input")
	var pose: Transform3D = host.world.flight.global_transform
	Input.action_press("forward"); Input.action_press("fire")
	var control := InputEventAction.new(); control.action = "fire"; control.pressed = true
	var z := InputEventAction.new(); z.action = "combat_toggle"; z.pressed = true
	host._unhandled_input(control); host._unhandled_input(z)
	host._read_flight_input(1.0 / float(Engine.physics_ticks_per_second))
	check(host.world.flight.intent.thrust_z == 0.0 and not host.fire_held and host.auto_fire_target == npc_id and host.world.flight.global_transform.is_equal_approx(pose), "focused TextEdit prevents W thrust, Ctrl fire and Z toggle from changing the ship or actual fire order")
	release_actions()
	editor.release_focus(); editor.queue_free()
	await frames()
	host._unhandled_input(z)
	check(host._keyboard_control_allowed() and not host.ui.keyboard_blocked() and host.auto_fire_target.is_empty(), "releasing TextEdit focus restores global Z control of the actual fire order")

func persistence_checks() -> void:
	host.world.flight.velocity = Vector3(7, -2, -15); host.world.flight.write_back()
	var saved: Transform3D = host.world.flight.global_transform
	var velocity: Vector3 = host.world.flight.velocity
	for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.FRONT, T.CameraMode.TACTICAL]:
		host.camera.bind(host.world.flight, host.store.catalog, mode)
		host.state.player().camera_mode = mode
		host._request_save("manual", 0)
		await wait_writer()
		var rows: Array[Dictionary] = host.store._records("SELECT p.camera_mode,s.slot_id,s.generation,s.current_snapshot_id FROM save_slot s JOIN player_state p ON p.snapshot_id=s.current_snapshot_id WHERE s.world_id=? AND s.slot_kind='manual' AND s.slot_index=0", [host.state.world_id])
		check(rows.size() == 1 and rows[0].camera_mode == ["follow", "front", "tactical"][int(mode)], "real sealed SQLite retains legacy camera mode " + str(mode))
		if mode == T.CameraMode.FOLLOW and not rows.is_empty():
			if not await prepare_native_world_input(): return
			pointer_position = Vector2(720, 450)
			left_button(true); left_button(false)
			left_button(true); motion(Vector2(90, -50))
			var control := InputEventAction.new(); control.action = "fire"; control.pressed = true
			host._unhandled_input(control)
			check(host.pointer_pick_pending and host.pointer_drag_pressed and host.pointer_dragged and host.observing and host.camera.observing and host.fire_held, "actual input events leave a queued pick, held drag and manual fire before load activation")
			var previous_world: int = host.world.get_instance_id()
			await host._command("load", str(rows[0].slot_id), int(rows[0].generation), str(rows[0].current_snapshot_id))
			await wait_writer()
			check(host.world.get_instance_id() != previous_world and not host.pointer_pick_pending and not host.pointer_drag_pressed and not host.pointer_dragged and not host.observing and not host.camera.observing and not host.fire_held and host.flight_look.pending_angles.is_zero_approx() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "actual load activation replaces the world and clears previous drag, queued selection and held fire")
			if not await prepare_native_world_input(): return
		await release_host(); await start_host()
		await host._command("continue", "", 1, ""); await wait_writer()
		host._sync_mouse_mode(); host.camera.step(0.0)
		check(host.camera.mode == mode and host.world.flight.global_transform.is_equal_approx(saved) and host.world.flight.velocity.is_equal_approx(velocity) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "actual restart accepts existing camera enum without changing ship pose, velocity or pointer mode " + str(mode))
		if not await prepare_native_world_input(): return
	await capture("restored-tactical")

func finish() -> void:
	release_actions()
	await release_host()
	Engine.max_fps = original_max_fps
	Engine.physics_ticks_per_second = original_physics_hz
	physics_interpolation = original_interpolation
	print("CAMERA_POINTER_V7_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
