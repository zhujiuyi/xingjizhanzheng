extends SceneTree
## Integrated HUD geometry and radar checks, using isolated SQLite progress.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
const Navigation = preload("res://runtime/navigation_catalog.gd")
const Factory = preload("res://runtime/visuals/industrial_visual_factory.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): print("NAVIGATION_V3 FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func capture(label: String) -> void:
	for frame: int in range(4): await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/logs/navigation-v3-" + label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)
	captures += 1

func settle_fixture_poses(nodes: Array[Node3D]) -> void:
	# Direct fixture relocations are discontinuities, unlike gameplay movement.
	# Prime/reset at a physical boundary, then let actual render callbacks see
	# the new history before using the camera's shared presentation pose.
	await physics_frame
	for node: Node3D in nodes:
		node.get_global_transform_interpolated()
		node.reset_physics_interpolation()
	for frame: int in range(3): await process_frame
	host.camera.step(0.0)
	host.ui.tick(0.0)

func _run() -> void:
	host = Main.new()
	host.progress_database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/navigation-v3-%d.db" % Time.get_ticks_usec())
	root.add_child(host)
	await process_frame
	check(host.services_ready, "actual Main starts with all asset identities valid")
	if not host.services_ready: await finish(); return
	await host._command("new_world", "雷达与航向验收", 1, "")
	check(host.state != null, "actual world created in isolated SQLite")
	if host.state == null: await finish(); return
	host.process_mode = Node.PROCESS_MODE_DISABLED
	host._command("undock", "", 1, "")
	while host.busy: await process_frame
	host.ui.show_page("")
	host._sync_presentation_stage()
	check(host.presentation_stage == "flight" and host.world.visible and not host.hangar.visible, "real departure switches exhibition to flight stage")
	check(root.get_camera_3d() == host.camera.camera, "captures use the actual flight camera")
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	await process_frame
	var nav: XJNavigationHUD = host.ui.navigation_hud
	# Main stays frozen while the production HUD continues render callbacks.
	nav.process_mode = Node.PROCESS_MODE_ALWAYS
	check(Navigation.rows("celestial_visual_defs").size() == 10 and Navigation.rows("radar_range_defs").size() == 3, "ten sectors and three radar ranges read from independent SQLite")
	check(Navigation.last_error.is_empty(), "navigation SQLite load has no failure")
	check(nav.scales == [500.0, 2000.0, 6000.0], "range selector uses SQLite definitions")
	check(nav.sensor_limit == float(host.store.catalog.rule("target_marker_detection_range_m")), "sensor cap uses frozen core rule")
	var body: Node3D = host.world.flight
	body.global_position = Vector3(5000, 3000, 5000)
	body.global_basis = Basis.IDENTITY
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	var near: Node3D = Factory.enemy_scene("scout")
	XJSurfaceStyle.apply_ship(near)
	var far := Node3D.new()
	host.world.add_child(near); host.world.add_child(far)
	near.global_position = body.global_position + Vector3(30, 100, -450)
	far.global_position = body.global_position + Vector3(0, 0, -6001)
	host.world.targets["nav_near"] = {"id": "nav_near", "title": "测试敌舰", "kind": "npc", "node": near, "anchor_id": ""}
	host.world.targets["nav_far"] = {"id": "nav_far", "title": "探测外敌舰", "kind": "npc", "node": far, "anchor_id": ""}
	await settle_fixture_poses([body, near, far])
	nav.scale_index = 2
	nav.selected_id = "nav_near"
	host.ui.target_id = "nav_near"
	nav.refresh()
	check(nav.contacts.any(func(row: Dictionary): return row.id == "nav_near"), "nearby hostile appears in local echoes")
	check(not nav.contacts.any(func(row: Dictionary): return row.id == "nav_far"), "hostile outside core sensor cap stays absent")
	host.ui.target_id = "nav_far"
	host.ui.tick(1.0)
	check(host.ui.target_id.is_empty() and nav.target_geometry().is_empty(), "selected hostile lost beyond sensor cap clears its live line")
	host.ui.target_id = "nav_near"; nav.selected_id = "nav_near"
	far.global_position = body.global_position + Vector3(0, 0, -6000)
	await settle_fixture_poses([far])
	nav.refresh()
	check(nav.contacts.any(func(row: Dictionary): return row.id == "nav_far"), "inclusive 6000m echo boundary")
	nav.scale_index = 0; nav.refresh()
	check(not nav.contacts.any(func(row: Dictionary): return row.id == "nav_far"), "range selector hides distant echo at 500m")
	var planetary: Array[Dictionary] = []
	for row: Dictionary in nav.contacts:
		if row.kind == "planet": planetary.append(row)
	check(planetary.size() == 1 and planetary[0].bearing, "known scenic planet is a distinct navigation bearing")
	if not planetary.is_empty():
		var canvas_size := Vector2(200, 186)
		var point: Vector2 = nav.radar_point(planetary[0], canvas_size)
		check(is_equal_approx(point.distance_to(canvas_size * Vector2(0.5, 0.47)), minf(canvas_size.x * 0.42, canvas_size.y * 0.39)), "planet stays on bearing perimeter rather than false echo range")
	check(nav.contact_color("npc") != nav.contact_color("planet") and nav.contact_color("npc") != nav.contact_color("station"), "enemy, facility and celestial use distinct colors and shapes")
	for altitude: float in [-10000.0, 10000.0]:
		var vertical: Dictionary = {"relative": Vector3(0, altitude, 0), "bearing": true}
		var point: Vector2 = nav.radar_point(vertical, Vector2(200, 186))
		check(point.distance_to(Vector2(200, 186) * Vector2(0.5, 0.47)) > 70 and (point.y < 87.42 if altitude > 0 else point.y > 87.42), "vertical celestial stays at correct bearing rim " + str(altitude))
	var clicked: Array[String] = []
	nav.selected.connect(func(value: String): clicked.append(value))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	for row: Dictionary in nav.contacts:
		if row.id == "nav_near": event.position = nav.radar_point(row, nav.radar.size)
	nav.radar._gui_input(event)
	check(clicked == ["nav_near"] and host.ui.target_id == "nav_near", "clicking radar selects actual contact through UI signal")
	for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.FRONT, T.CameraMode.TACTICAL]:
		host.camera.bind(host.world.flight, host.store.catalog, mode)
		await physics_frame
		host.camera.step(1.0)
		near.global_position = host.camera.camera.global_position - host.camera.camera.global_basis.z * 500
		await settle_fixture_poses([near])
		nav.selected_id = "nav_near"
		var geometry: Dictionary = nav.target_geometry()
		check(not geometry.is_empty() and geometry.on_screen, "selected target is projected in camera " + str(mode))
		check(geometry.end.distance_to(host.camera.camera.unproject_position(near.get_global_transform_interpolated().origin)) < 0.01, "line ends at actual rendered target projection " + str(mode))
		var render_ship: Vector3 = host.camera.render_ship_transform().origin
		var ship_point: Vector2 = nav.size * 0.5 if host.camera.camera.is_position_behind(render_ship) else host.camera.camera.unproject_position(render_ship)
		check(geometry.start.distance_to(ship_point) < 0.01, "line starts at ship or cockpit center " + str(mode))
	near.global_position = host.camera.camera.global_position + host.camera.camera.global_basis.z * 100
	await settle_fixture_poses([near])
	var behind: Dictionary = nav.target_geometry()
	check(behind.behind and not behind.on_screen, "behind-camera target becomes an edge arrow")
	check(Rect2(Vector2(39, 39), nav.size - Vector2(78, 78)).has_point(behind.end), "behind-camera arrow remains inside viewport")
	for local_point: Vector3 in [Vector3.ZERO, Vector3(100, 0, 0), Vector3(0, 100, 0)]:
		near.global_position = host.camera.camera.global_transform * local_point
		await settle_fixture_poses([near])
		var plane: Dictionary = nav.target_geometry()
		check(not plane.is_empty() and plane.behind and plane.end.is_finite(), "exact camera plane safely maps to edge " + str(local_point))
		host.ui.marker_layer.queue_redraw()
		for frame: int in range(2): await process_frame
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	await physics_frame
	host.camera.step(1.0)
	near.global_position = body.global_position + Vector3(30, 20, -450)
	await settle_fixture_poses([near])
	nav.scale_index = 1
	var standalone := XJNavigationHUD.new()
	root.add_child(standalone)
	standalone.configure(host.world, host.camera, host.store.catalog)
	standalone.selected_id = "nav_near"
	standalone.responsive(Vector2(1440, 900))
	for frame: int in range(12): await process_frame
	check(standalone.selection_readout_enabled and standalone.selection_frame.visible, "standalone HUD retains enabled legacy readout compatibility across render frames")
	standalone.selection_readout_enabled = false
	var standalone_hidden: bool = true
	for frame: int in range(12):
		await process_frame
		standalone_hidden = standalone_hidden and not standalone.selection_frame.visible
	check(standalone_hidden, "explicit HUD readout disable survives repeated production annotation callbacks")
	standalone.queue_free()
	await process_frame
	for window_size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = window_size
			root.content_scale_size = Vector2i(Vector2(window_size) / scale)
			for frame: int in range(3): await process_frame
			host.ui.tick(1.0)
			for frame: int in range(3): await process_frame
			var viewport := Rect2(Vector2.ZERO, host.ui.root.size)
			var legacy_hidden: bool = true
			for frame: int in range(24):
				await process_frame
				legacy_hidden = legacy_hidden and not nav.selection_frame.visible
			check(not nav.selection_readout_enabled and legacy_hidden and host.ui.overview.is_visible_in_tree() and not nav.target_geometry().is_empty(), "main target card stays unique through 24 render frames %s scale %.0f" % [window_size, scale])
			check(viewport.encloses(nav.radar_frame.get_global_rect()), "radar fits window %s scale %.0f" % [window_size, scale])
			check(not nav.radar_frame.get_global_rect().intersects(host.ui.instrument.get_global_rect()), "radar clears flight instrument %s scale %.0f" % [window_size, scale])
			check(not nav.radar_frame.get_global_rect().intersects(host.ui.hud_left.get_parent().get_global_rect()), "radar clears mission readout %s scale %.0f" % [window_size, scale])
			check(not nav.radar_frame.get_global_rect().intersects(host.ui.navigation.get_global_rect()), "radar clears flight navigation %s scale %.0f" % [window_size, scale])
			check(not nav.radar_frame.get_global_rect().has_point(host.ui.root.size * 0.5), "radar clears steering center %s scale %.0f" % [window_size, scale])
			var caption: Rect2 = nav.caption_rect("测试敌舰 · 451 m", nav.target_geometry().end)
			check((not caption.has_area() if scale == 2 else caption.has_area()) and not nav.caption_obstacles.any(func(obstacle: Rect2): return caption.has_area() and caption.grow(4).intersects(obstacle)), "selected caption avoids HUD and compact duplication %s scale %.0f" % [window_size, scale])
			await capture("flight-%dx%d-%dpercent" % [window_size.x, window_size.y, int(scale * 100)])
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	await process_frame
	var station_id := "station_anchor_port"
	var station: Node3D = host.world.targets[station_id].node
	body.global_position = station.global_position + Vector3.RIGHT * (float(host.store.catalog.rule("dock_radius_m")) - 1)
	host.world.flight.write_back()
	await settle_fixture_poses([body])
	host.ui.target_id = ""; host.ui.tick(1.0)
	check(host.ui.interaction_button.visible and not host.ui.interaction_button.disabled and host.ui.interaction_button.text.contains("[F]"), "approaching station exposes a ready F button without preselection")
	host.world.flight.velocity = Vector3.RIGHT * (float(host.store.catalog.rule("dock_max_speed_mps")) + 1)
	host.ui.tick(1.0)
	check(host.ui.interaction_button.disabled and host.ui.interaction_label.text.contains("制动"), "over-speed F button shows same braking reason")
	await capture("station-approach")
	for key: String in host.world.targets:
		if host.world.targets[key].kind == "planet":
			host.ui.target_id = key; nav.selected_id = key; break
	host.ui._update_navigation()
	var selected_card: XJOverviewPanel = host.ui.overview
	check(selected_card.is_visible_in_tree() and selected_card.selected_id == host.ui.target_id and selected_card.selected_distance.text.contains("航向参考") and selected_card.selected_distance.text.contains(XJSpaceUnits.distance(host.world.target_distance(host.ui.target_id))), "visible selected card preserves celestial bearing eligibility and displays its authoritative distance")
	check(not nav.selection_frame.visible and not selected_card.action_buttons["nav_warp"].visible and not selected_card.action_buttons["nav_approach"].visible and not selected_card.action_buttons["nav_orbit"].visible, "bearing selection owns one readout and offers no unsupported movement commands")
	var dead := Node3D.new()
	host.world.add_child(dead)
	host.world.targets["nav_dead"] = {"id": "nav_dead", "title": "已释放目标", "kind": "npc", "node": dead}
	dead.free(); nav.selected_id = "nav_dead"; nav.refresh()
	check(nav.target_geometry().is_empty() and not nav.contacts.any(func(row: Dictionary): return row.id == "nav_dead"), "freed contacts safely disappear from radar and line")
	host.ui.show_page("pause")
	check(not nav.visible, "pause hides all flight radar and target overlays")
	await finish()

func finish() -> void:
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	print("NAVIGATION_V3_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
