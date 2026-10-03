extends SceneTree
## Real Main physics and render callbacks, fresh SQLite and the actual scenic
## planet. The only fixture pose change places the test ship in front of that
## planet; its radius/material/location remain the versioned visual DB values.
## Headless verifies geometry/state only. Native adds six moving frame captures.
const Main = preload("res://runtime/main.gd")
const Navigation = preload("res://runtime/navigation_catalog.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var display_view: Viewport
var probe: AfterPresentation
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var interpolated_frames: int = 0
var maximum_pose_difference_m: float = 0.0
var maximum_center_error_px: float = 0.0
var evidence: Array[Dictionary] = []
var original_fps: int
var original_hz: int
var original_mouse: Vector2
var planet_id: String
var planet: MeshInstance3D

class AfterPresentation extends Node:
	signal sampled
	func _process(_delta: float) -> void: sampled.emit()

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): print("FLIGHT_MOTION_VISUAL_V7 FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value: failures.append(label); print("FAIL ", label)
	return value

func _run() -> void:
	original_fps = Engine.max_fps
	original_hz = Engine.physics_ticks_per_second
	Engine.max_fps = 144
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	display_view = root
	if DisplayServer.get_name() == "headless":
		# A headless Window has no drawable size. The real Main runs under an
		# explicitly sized viewport for projection math, with normal callbacks.
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1440, 900)
		viewport.own_world_3d = true
		root.add_child(viewport)
		display_view = viewport
	else:
		original_mouse = root.get_mouse_position()
		root.grab_focus()
		var deadline: int = Time.get_ticks_msec() + 3000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
		if not check(root.has_focus(), "native window owns real input focus without bypassing Main protection"):
			await finish(); return
	host = Main.new()
	host.progress_database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/flight-motion-visual-v7-%d.db" % Time.get_ticks_usec())
	display_view.add_child(host)
	if not check(host.services_ready, "actual Main opens a fresh tmp SQLite and current resources"):
		await finish(); return
	await host._command("new_world", "真实运动画面独立验收", 1, "")
	if not check(host.state != null, "actual production endpoint creates a new world"):
		await finish(); return
	host._command("undock", "", 1, "")
	while host.busy: await process_frame
	if not check(host.state.ship().status == T.ShipStatus.FLYING, "actual business endpoint departs before motion"):
		await finish(); return
	check(physics_interpolation and Engine.physics_ticks_per_second == int(host.store.catalog.rule("simulation_hz")), "world interpolation and fixed physics cadence use actual project/catalog settings")
	var planets: Array[Dictionary] = []
	for entry: Dictionary in host.world.targets.values():
		if str(entry.kind) == "planet": planets.append(entry)
	if not check(planets.size() == 1, "current sector has exactly one actual planet target"):
		await finish(); return
	planet_id = str(planets[0].id)
	planet = planets[0].node as MeshInstance3D
	var definition: Dictionary = {}
	for row: Dictionary in Navigation.rows("celestial_visual_defs"):
		if str(row.celestial_id) == planet_id: definition = row; break
	if not check(planet != null and not definition.is_empty() and planet.mesh is SphereMesh, "actual versioned visual SQLite defines the single sphere"):
		await finish(); return
	check(is_equal_approx((planet.mesh as SphereMesh).radius, float(definition.render_radius_m)) and planet.global_position.is_equal_approx(Vector3(definition.x_m, definition.y_m, definition.z_m)), "planet radius/location/material are not replaced by a fixture or second model")
	# Test-only staging, not a teleport mechanic or saved balance definition.
	# The radius is read from formal SQLite and the original planet is untouched.
	await physics_frame
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, planet.global_position + Vector3.BACK * float(definition.render_radius_m) * 3.0)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.ui.show_page("")
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.state.player().camera_mode = T.CameraMode.FOLLOW
	host.ui._select_target(planet_id)
	host.camera.step(0.0)
	host.ui.tick(0.0)
	probe = AfterPresentation.new()
	probe.process_priority = 1000
	display_view.add_child(probe)
	# Input is intentionally held for real Main ticks. No direct simulate(),
	# tick(), artificial velocity or hand-authored renderer pose is used.
	for frame: int in range(4): await probe.sampled
	var origin: Vector3 = host.world.flight.global_position
	var start_physics_frame: int = Engine.get_physics_frames()
	Input.action_press("forward")
	for frame: int in range(1, 121):
		await probe.sampled
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		_sample(frame)
		if frame in [10, 30, 50, 70, 90, 120] and DisplayServer.get_name() != "headless":
			var image: Image = display_view.get_texture().get_image()
			var path: String = ProjectSettings.globalize_path("res://../jiaoben/logs/flight-motion-v7-frame-%03d.png" % frame)
			if check(image != null and not image.is_empty() and image.save_png(path) == OK, "actual native moving frame capture " + str(frame)): captures += 1
	Input.action_release("forward")
	check(Engine.get_physics_frames() > start_physics_frame and host.world.flight.global_position.distance_to(origin) > 0.01 and host.world.flight.velocity.length() > 0.0, "standard Main physics genuinely advances the ship while W is held")
	check(interpolated_frames >= 3 and maximum_pose_difference_m > 0.00001, "multiple real render samples differ from current physical ship pose")
	check(DisplayServer.get_name() == "headless" or captures == 6, "native evidence consists of six actual moving frames")
	await finish()

func _sample(frame: int) -> void:
	var render_pose: Transform3D = host.camera.render_ship_transform()
	var physical_pose: Transform3D = host.world.flight.global_transform
	var difference: float = render_pose.origin.distance_to(physical_pose.origin)
	maximum_pose_difference_m = maxf(maximum_pose_difference_m, difference)
	if difference > 0.00001: interpolated_frames += 1
	var nav: XJNavigationHUD = host.ui.navigation_hud
	var geometry: Dictionary = nav.target_geometry()
	var rendered_planet: Vector3 = planet.get_global_transform_interpolated().origin
	var expected_end: Vector2 = host.camera.camera.unproject_position(rendered_planet)
	var expected_start: Vector2 = host.camera.camera.unproject_position(render_pose.origin)
	var center_error: float = expected_start.distance_to(display_view.get_visible_rect().size * 0.5)
	maximum_center_error_px = maxf(maximum_center_error_px, center_error)
	check(not geometry.is_empty() and geometry.on_screen and geometry.end.distance_to(expected_end) < 0.01 and geometry.start.distance_to(expected_start) < 0.01, "same-frame rendered endpoints frame " + str(frame))
	check(center_error < 0.1 and host.world.flight.visual.is_visible_in_tree(), "actual exterior ship remains visible and centered frame " + str(frame))
	check(nav.find_children("WorldTargetCaption", "Label", true, false).size() == 1 and nav.target_caption.is_visible_in_tree() and nav.target_caption.text.contains(str(host.world.targets[planet_id].title)) and not nav.marker_geometry().any(func(marker: Dictionary): return str(marker.id) == planet_id), "single selected planet name and marker channel frame " + str(frame))
	check(host.world.find_children("Celestial_*", "MeshInstance3D", true, false).size() == 1 and not host.local_navigation.active(), "one original sphere during actual manual flight frame " + str(frame))
	evidence.append({"frame": frame, "physics_frame": Engine.get_physics_frames(), "speed_mps": host.world.flight.velocity.length(), "physical_position": xyz(physical_pose.origin), "rendered_position": xyz(render_pose.origin), "pose_difference_m": difference, "ship_center_error_px": center_error, "target_screen": [expected_end.x, expected_end.y]})

func xyz(value: Vector3) -> Array[float]: return [value.x, value.y, value.z]

func finish() -> void:
	Input.action_release("forward")
	if is_instance_valid(host): host._release_controls(); host.queue_free()
	if is_instance_valid(probe): probe.queue_free()
	for frame: int in range(3): await process_frame
	await create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless": root.warp_mouse(original_mouse)
	Engine.max_fps = original_fps
	Engine.physics_ticks_per_second = original_hz
	var report := {"backend": DisplayServer.get_name(), "image_evidence": DisplayServer.get_name() != "headless", "checks": checks, "failures": failures, "captures": captures, "interpolated_frames": interpolated_frames, "maximum_pose_difference_m": maximum_pose_difference_m, "maximum_center_error_px": maximum_center_error_px, "fixture": "fresh SQLite; existing DB planet unchanged; temporary ship staging only; normal Main callbacks", "samples": evidence}
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/logs/flight-motion-v7-" + DisplayServer.get_name() + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("FLIGHT_MOTION_VISUAL_V7 %s checks=%d failures=%d captures=%d interpolated_frames=%d max_pose_difference_m=%.6f max_center_error_px=%.6f image_evidence=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures, interpolated_frames, maximum_pose_difference_m, maximum_center_error_px, DisplayServer.get_name() != "headless"])
	quit(0 if failures.is_empty() else 1)
