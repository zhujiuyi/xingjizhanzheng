extends RefCounted
## Fixed opt-in release health endpoint, confined by Main to a fresh tmp database.
## No arbitrary script, source path, command or production save can be supplied.
const Types = preload("res://contracts/contract_types.gd")

static func run(host: Node, output_dir: String) -> bool:
	var evidence := {"checks": 0, "failures": 0}
	var original_pointer: Vector2 = host.get_viewport().get_mouse_position()
	if DisplayServer.get_name() != "headless":
		host.get_window().grab_focus()
		# A background CLI launch on macOS cannot activate its application.
		# Allow the external native-window runner to raise this test window;
		# never bypass the production focus guard to satisfy injected events.
		var focus_deadline: int = Time.get_ticks_msec() + 60000
		print("PRESENTATION_NATIVE_FOCUS awaiting active test window")
		while not host.get_window().has_focus() and Time.get_ticks_msec() < focus_deadline:
			await host.get_tree().process_frame
		if not host.get_window().has_focus():
			_check(evidence, false, "native test window has real input focus")
			return _finish(evidence)
		host.get_viewport().warp_mouse(Vector2(700, 400))
		await host.get_tree().process_frame
	await host._command("new_world", "发布包表现检查", 1, "")
	var industrial_world: bool = host.state != null and host.world != null and is_instance_valid(host.world.flight) and str(host.world.flight.visual.get_meta("visual_asset_version", "")) == "ship-v3-industrial"
	if industrial_world:
		var packed_station: Node3D = host.world.targets.get("station_anchor_port", {}).get("node")
		industrial_world = is_instance_valid(packed_station) and str(packed_station.get_node("VisualRoot").get_meta("station_visual_version", "")) == "station-v3"
	_check(evidence, industrial_world, "actual packed client creates isolated world with industrial ship and station")
	if host.state == null: return _finish(evidence)
	_check(evidence, host.ui.root.theme.default_font == XJUITheme.font(), "packed UI uses bundled Chinese font")
	_check(evidence, not XJUITheme.font().allow_system_fallback and XJUITheme.font().has_char("舰".unicode_at(0)), "packed font covers Chinese without system fallback")
	host.ui.show_title(host.store.list_slots())
	await host.get_tree().process_frame
	var continue_button: Button = null
	for button: Node in host.ui.panel.find_children("*", "Button", true, false):
		if str(button.text) == "继续航行": continue_button = button
	_check(evidence, continue_button != null, "existing-slot title retains compact continue action")
	if continue_button != null:
		var padding: Vector2 = continue_button.get_theme_stylebox("normal").get_minimum_size()
		var text_width: float = continue_button.get_theme_font("font").get_string_size(continue_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, continue_button.get_theme_font_size("font_size")).x
		_check(evidence, text_width <= continue_button.size.x - padding.x + 1.0, "existing-slot continue label fits one line")
		continue_button.mouse_entered.emit()
		continue_button.mouse_exited.emit()
		_check(evidence, continue_button.has_meta("hover_tween"), "first hover creates feedback without missing metadata")
	await _capture(host, output_dir, "title")
	# Resume through the production endpoint. A direct page switch from title
	# leaves menu_open true and would freeze the hangar camera in this fixture.
	await host._command("continue", "", 1, "")
	_check(evidence, host.state != null and not host.ui.menu_open, "actual continue restores active world from title")
	if host.state == null: return _finish(evidence)
	for page: String in ["station", "missions", "market", "industry", "research", "map", "pause", "settings", "station"]:
		host.ui.show_page(page)
		await host.get_tree().process_frame
		_check(evidence, host.ui.page == page and host.ui.body.get_child_count() > 0, "packed service page " + page)
		if page == "map":
			var chart: Node = host.ui.body.find_child("StarChart", true, false)
			_check(evidence, chart != null and chart.sectors.size() == host.store.catalog.rows("sector_defs").size() and not chart.links.is_empty() and chart.selected_sector == host.state.current_sector() and chart.information.text.contains("势力：") and chart.information.text.contains("资源："), "packed graphical star chart reads actual sectors, links and intelligence")
			await _star_chart_checks(host, evidence)
			await _capture(host, output_dir, "map")
		if page == "pause":
			var manual_count: int = 0
			for control: Node in host.ui.body.find_children("*", "Button", true, false):
				if str(control.text).begins_with("保存至手动槽 "): manual_count += 1
			_check(evidence, manual_count == 5, "packed archive exposes five manual save cards")
			await _capture(host, output_dir, "archive")
		for button: Node in host.ui.body.find_children("*", "Button", true, false):
			if not button.disabled:
				button.mouse_entered.emit()
				button.mouse_exited.emit()
				break
	await _business_list_checks(host, evidence, output_dir)
	await _capture(host, output_dir, "station")
	var crew: Node3D = host.hangar.get_service_anchor("operations")
	_check(evidence, is_instance_valid(crew) and crew.is_visible_in_tree(), "packed 3D NPC service model is visible")
	var portrait: Button = host.ui.station_services.find_child("NpcPortrait0", true, false)
	_check(evidence, portrait != null, "packed NPC portrait exposes a view control")
	if portrait != null: portrait.pressed.emit()
	var focus_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < focus_deadline and host.hangar.get_camera().position.distance_to(host.hangar._camera_destination) > 1.0:
		await host.get_tree().process_frame
	_check(evidence, host.hangar._focused == "operations" and host.hangar.get_camera().position.distance_to(host.hangar._camera_destination) <= 1.0, "NPC view action reaches the actual close camera")
	await _capture(host, output_dir, "npc")
	var overview: Button = host.ui.station_services.find_child("HangarOverview", true, false)
	if overview != null: overview.pressed.emit()
	_check(evidence, overview != null and host.hangar._focused.is_empty(), "overview action restores ship framing")
	host.ui.show_page("station")
	var presentation: XJPresentation = host.presentation
	var dead_voice := AudioStreamPlayer.new()
	presentation.add_child(dead_voice)
	presentation.voices.append(dead_voice)
	dead_voice.free()
	presentation.set_paused(false)
	_check(evidence, presentation.voices.all(func(value: Variant): return is_instance_valid(value)), "pause safely removes freed voice slots")
	var dead_effect := Node3D.new()
	presentation.add_child(dead_effect)
	presentation.effects.append(dead_effect)
	dead_effect.free()
	presentation.hit(host.state.ship().ship_instance_id, true, host.world.flight.global_position)
	_check(evidence, presentation.effects.all(func(value: Variant): return is_instance_valid(value)), "hit safely removes freed effect slots")
	host.ui.show_page("pause")
	await host.get_tree().process_frame
	presentation.ui_result(true)
	var short_voice: Variant = presentation.voices[-1]
	var deadline := Time.get_ticks_msec() + 3000
	while is_instance_valid(short_voice) and Time.get_ticks_msec() < deadline:
		await host.get_tree().process_frame
	_check(evidence, not is_instance_valid(short_voice), "real CoreAudio UI sound finishes during paused menu")
	host.ui.show_page("station")
	presentation.consume(0.0)
	_check(evidence, presentation.voices.all(func(value: Variant): return is_instance_valid(value)), "next frame prunes finished voices without typed-callback errors")
	host._business_action("undock", "", 1, "")
	while host.busy: await host.get_tree().process_frame
	_check(evidence, host.state.ship().status == Types.ShipStatus.FLYING, "packed authoritative departure")
	host.set_process(false)
	host.set_physics_process(false)
	host.camera.bind(host.world.flight, host.store.catalog, Types.CameraMode.FRONT)
	host.state.player().camera_mode = Types.CameraMode.FRONT
	host.camera.step(0.0)
	host.ui.update_camera_status()
	_check(evidence, not host.world.flight.visual.visible and host.ui.instrument_title.text.contains("舰体隐藏") and host.ui.show_ship_button.is_visible_in_tree(), "packed cockpit identifies hidden hull and exposes recovery control")
	var flight_pose: Transform3D = host.world.flight.global_transform
	var flight_velocity: Vector3 = host.world.flight.velocity
	host.ui.show_ship_button.pressed.emit()
	_check(evidence, host.camera.mode == Types.CameraMode.FOLLOW and host.state.player().camera_mode == Types.CameraMode.FOLLOW and host.world.flight.visual.is_visible_in_tree() and host.world.flight.global_transform.is_equal_approx(flight_pose) and host.world.flight.velocity.is_equal_approx(flight_velocity) and host.ui.instrument_title.text.contains("跟随视角"), "packed recovery shows centered ship without changing flight motion")
	host.set_process(true)
	host.set_physics_process(true)
	var nav: XJNavigationHUD = host.ui.navigation_hud
	host.ui.tick(1.0)
	_check(evidence, nav.visible and nav.scales.size() == 3, "packed local radar reads three SQLite ranges")
	_check(evidence, nav.sensor_limit == float(host.store.catalog.rule("target_marker_detection_range_m")), "packed radar respects frozen sensor limit")
	_check(evidence, nav.contacts.filter(func(row: Dictionary): return row.kind == "planet" and row.bearing).size() == 1, "packed sector includes known celestial bearing")
	_check(evidence, host.ui.overview.entry_rows.any(func(row: Dictionary): return row.kind == "station") and host.ui.overview.filter_buttons.size() == 3 and host.ui.overview.sort_buttons.size() == 3, "packed overview provides known station selection, classification and sorting")
	_check(evidence, not host.ui.equipment_bar.module_records.is_empty() and host.ui.equipment_bar.module_records.size() == host.gameplay.call("equipped", host.state.ship()).size(), "packed equipment bar reads actual installed module instances")
	_check(evidence, host.get_tree().physics_interpolation and not host.camera.is_physics_interpolated() and not host.camera.camera.is_physics_interpolated(), "packed world interpolates motion once while camera renders from the same pose")
	host._sync_mouse_mode()
	var view_before_right: Vector2 = host.camera.orbit
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	host.get_viewport().push_input(right, true)
	await host.get_tree().process_frame
	_check(evidence, Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not InputMap.has_action("pointer") and not InputMap.has_action("observe") and not host.observing and host.camera.orbit == view_before_right, "packed cursor is always visible and right button does not operate the ship or camera")
	await _hud_layout_checks(host, evidence)
	await _capture(host, output_dir, "flight")
	await _attitude_checks(host, evidence, output_dir)
	await _manual_turn_camera_checks(host, evidence, output_dir)
	var station_id: String = "station_anchor_port"
	var station: Node3D = host.world.targets[station_id].node
	host.set_process(false)
	host.set_physics_process(false)
	host.world.flight.global_position = station.global_position + host.world.flight.global_basis.z * (float(host.store.catalog.rule("dock_radius_m")) * 0.8)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	await host.get_tree().physics_frame
	await host.get_tree().process_frame
	host.ui.target_id = station_id
	host.camera.snapped = false
	host.camera.step(1.0)
	host.ui.tick(1.0)
	var geometry: Dictionary = nav.target_geometry()
	_check(evidence, not geometry.is_empty() and geometry.end.distance_to(host.camera.camera.unproject_position(station.global_position)) < 0.01, "packed selected line reaches actual station projection")
	_check(evidence, nav.target_caption.is_visible_in_tree() and nav.target_caption.text.contains(str(host.world.targets[station_id].title)) and nav.target_caption.get_theme_constant("outline_size") == 0 and nav.target_caption.get_theme_color("font_shadow_color").a == 0.0 and nav.target_caption.position == nav.target_caption.position.round(), "packed selected caption is a single crisp pixel-aligned label without shadow")
	_check(evidence, not nav.marker_geometry().any(func(marker: Dictionary): return marker.id == station_id) and station.get_node("VisualRoot").find_children("Model", "Node3D", false, false).size() == 1, "packed selected target excludes secondary markers and keeps one model")
	_check(evidence, host.ui.interaction_button.visible and not host.ui.interaction_button.disabled and host.ui.interaction_button.text.contains("[F]"), "packed station approach presents usable F control")
	await _capture(host, output_dir, "approach")
	host.world.flight.velocity = Vector3.RIGHT * (float(host.store.catalog.rule("dock_max_speed_mps")) + 1)
	host.ui.tick(1.0)
	_check(evidence, host.ui.interaction_button.disabled and host.ui.interaction_label.text.contains("制动"), "packed over-speed approach gives braking reason")
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	_check(evidence, host.local_navigation.rules.loaded and host.local_navigation.rules.VERSION == "local-navigation-v1", "packed local-navigation rules load the versioned SQLite extension")
	# Retain every child collider in the real World3D while explicitly driving
	# Main at physical boundaries; disabling its inherited process mode removes
	# bodies from the physics space and would invalidate the safety evidence.
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, station.global_position + Vector3(0, 600, 4000))
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	var origin: Vector3 = host.world.flight.global_position
	var snapshots_before: int = host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n
	var begun: bool = host._navigation_command("warp", station_id)
	var snapshots_after: int = host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n
	_check(evidence, begun and host.local_navigation.phase == "warmup" and origin.is_equal_approx(host.world.flight.global_position) and snapshots_after == snapshots_before + 1, "packed warp durably saves its origin before charge or movement")
	var ordinary := InputEventMouseMotion.new()
	ordinary.position = Vector2(700, 400)
	ordinary.relative = Vector2(40, 20)
	var heading_before: Basis = host.world.flight.global_basis
	host.get_viewport().push_input(ordinary, true)
	await host.get_tree().process_frame
	_check(evidence, host.local_navigation.phase == "warmup" and host.local_navigation.target_id == station_id and host.world.flight.global_basis.is_equal_approx(heading_before), "packed ordinary pointer motion preserves accepted warp and physical heading")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	left.position = Vector2(700, 400)
	if DisplayServer.get_name() != "headless":
		host.get_window().grab_focus()
		var gesture_focus_deadline: int = Time.get_ticks_msec() + 60000
		while not host.get_window().has_focus() and Time.get_ticks_msec() < gesture_focus_deadline:
			await host.get_tree().process_frame
		host.get_viewport().warp_mouse(left.position)
		for frame: int in range(3): await host.get_tree().process_frame
	host.get_viewport().push_input(left, true)
	await host.get_tree().process_frame
	print("PRESENTATION_NATIVE_INPUT focus=", host.get_window().has_focus(), " hover_blocked=", host.ui.ui_input_blocked(), " armed=", host.pointer_drag_pressed)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(730, 420)
	drag.relative = Vector2(30, 20)
	host.get_viewport().push_input(drag, true)
	await host.get_tree().process_frame
	var dragged_orbit: Vector2 = host.camera.orbit
	_check(evidence, host.observing and host.pointer_dragged and not dragged_orbit.is_zero_approx() and host.local_navigation.phase == "warmup" and host.world.flight.global_basis.is_equal_approx(heading_before), "packed held left drag changes only observation without interrupting warp")
	left.pressed = false
	left.position = drag.position
	host.get_viewport().push_input(left, true)
	await host.get_tree().process_frame
	_check(evidence, not host.observing and not host.pointer_pick_pending and host.camera.orbit == dragged_orbit and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and host.local_navigation.phase == "warmup", "packed left release retains observation and cannot become a click or navigation cancel")
	host.camera.reset_observation()
	var steps: int = 0
	while host.local_navigation.phase == "warmup" and steps < 1800:
		await host.get_tree().physics_frame
		host._physics_process(1.0 / float(Engine.physics_ticks_per_second))
		steps += 1
	# Sample motion after the first actual travel tick, rather than the zero
	# velocity boundary where charging has just changed its phase to travel.
	await host.get_tree().physics_frame
	host._physics_process(1.0 / float(Engine.physics_ticks_per_second))
	steps += 1
	host.camera.snapped = false
	host.camera.step(1.0)
	host.ui.tick(1.0)
	host.warp_visual.update_navigation(host.local_navigation.phase, 0.6, float(host.preferences.get("vfx_intensity", 1.0)), false)
	_check(evidence, host.local_navigation.phase == "travel" and host.warp_visual.is_visible_in_tree(), "packed warp shows an actual running effect behind the HUD")
	var recorded_speed: float = Vector3(host.state.ship().vel_x, host.state.ship().vel_y, host.state.ship().vel_z).length()
	_check(evidence, recorded_speed > 0.0 and is_equal_approx(host.ui.dial.speed, recorded_speed) and is_equal_approx(recorded_speed, host.world.flight.velocity.length()), "packed warp instrument displays actual moving ship velocity")
	await _capture(host, output_dir, "warp")
	_check(evidence, not host.ui.navigation_hud.selection_frame.is_visible_in_tree() and not host.ui.operation_bar.is_visible_in_tree(), "packed local navigation keeps one selected card and no redundant global banner across render frames")
	while host.local_navigation.active() and steps < 2400:
		await host.get_tree().physics_frame
		host._physics_process(1.0 / float(Engine.physics_ticks_per_second))
		steps += 1
	for frame: int in range(3): await host.get_tree().process_frame
	while host.busy: await host.get_tree().process_frame
	host.warp_visual.update_navigation("idle", 0.0, 1.0, false)
	host.camera.snapped = false
	host.camera.step(1.0)
	host.ui.tick(1.0)
	_check(evidence, steps < 2400 and host.local_navigation.phase == "arrived" and host.state.ship().status == Types.ShipStatus.FLYING and absf(host.world.flight.global_position.distance_to(station.global_position) - 500.0) <= 0.01 and host.world.flight.velocity.is_zero_approx(), "packed local warp reaches the safe station exterior and stops without docking")
	await host.get_tree().physics_frame
	var station_screen: Vector2 = host.camera.camera.unproject_position(station.global_position)
	_check(evidence, not host.camera.camera.is_position_behind(station.global_position) and host._world_target_at(station_screen) == station_id, "packed station model can be selected by its real physical ray hit")
	await _capture(host, output_dir, "arrival")
	var docking: bool = host._navigation_command("dock", station_id)
	var dock_steps: int = 0
	while host.local_navigation.active() and dock_steps < 1800:
		await host.get_tree().physics_frame
		host._physics_process(1.0 / float(Engine.physics_ticks_per_second))
		dock_steps += 1
	for frame: int in range(3): await host.get_tree().process_frame
	while host.busy: await host.get_tree().process_frame
	host._sync_presentation_stage()
	_check(evidence, docking and dock_steps < 1800 and host.state.ship().status == Types.ShipStatus.DOCKED and host.hangar.is_visible_in_tree() and host.ui.page == "station", "packed dock command completes the actual validated station entry")
	host.set_process(true)
	host.set_physics_process(true)
	await _mineral_checks(host, evidence, output_dir)
	presentation = host.presentation
	host.ui.show_page("pause")
	_check(evidence, host.store.save(host.state, "manual", 0), "packed presentation world saves to isolated SQLite")
	# Leave a freed reference immediately before quit to exercise cleanup too.
	var exit_voice := AudioStreamPlayer.new()
	presentation.add_child(exit_voice)
	presentation.voices.append(exit_voice)
	exit_voice.free()
	if DisplayServer.get_name() != "headless": host.get_viewport().warp_mouse(original_pointer)
	return _finish(evidence)

static func _star_chart_durable_state(host: Node) -> Dictionary:
	# Read complete rows only from the fresh release-test database. Journal file
	# changes cannot substitute for comparing actual snapshots and their slots.
	return {
		"snapshots": host.store._records("SELECT * FROM save_snapshot ORDER BY snapshot_id"),
		"slots": host.store._records("SELECT * FROM save_slot ORDER BY slot_id"),
		"sessions": host.store._records("SELECT * FROM runtime_session ORDER BY world_id"),
		"players": host.store._records("SELECT * FROM player_state ORDER BY snapshot_id,player_id"),
		"ships": host.store._records("SELECT * FROM ship_state ORDER BY snapshot_id,ship_instance_id")}

static func _star_chart_checks(host: Node, evidence: Dictionary) -> void:
	# Freeze Main's simulation callbacks, retaining real GUI/render callbacks and
	# the physics space. Record state after freezing so normal ticks are excluded.
	var process_enabled: bool = host.is_processing()
	var physics_enabled: bool = host.is_physics_processing()
	host.set_process(false)
	host.set_physics_process(false)
	var chart: Control = host.ui.resource_chart
	var controls_valid: bool = is_instance_valid(chart)
	if controls_valid:
		controls_valid = is_instance_valid(chart.get("search_box")) and is_instance_valid(chart.get("risk_filter")) and is_instance_valid(chart.get("navigator")) and is_instance_valid(chart.get("diagram"))
	for identity: String in ["ChartFitAll", "ChartFocusCurrent", "ChartFocusSelected", "ChartZoomOut", "ChartZoomIn"]:
		controls_valid = controls_valid and is_instance_valid(chart) and chart.find_child(identity, true, false) is Button
	if controls_valid:
		var drawing: Control = chart.get("diagram")
		controls_valid = drawing.clip_contents and drawing.mouse_filter == Control.MOUSE_FILTER_STOP and not drawing.mouse_force_pass_scroll_events
	_check(evidence, controls_valid, "packed star chart has search, risk selection, node navigation, view tools and a clipped canvas that consumes scroll input")
	if not controls_valid:
		host.set_process(process_enabled)
		host.set_physics_process(physics_enabled)
		return
	var canvas: Control = chart.get("diagram")
	var original_view: Dictionary = chart.call("export_view")
	var initial_player: Dictionary = host.store._codec.encode_row("player_state", host.state.player())
	var initial_ship: Dictionary = host.store._codec.encode_row("ship_state", host.state.ship())
	var initial_meta: Dictionary = host.store._codec.encode_row("save_snapshot", host.state.snapshot.meta)
	var initial_pose: Transform3D = host.world.flight.global_transform
	var origin: String = host.state.current_sector()
	var initial_target: String = host.ui.target_id
	var initial_durable: Dictionary = _star_chart_durable_state(host)
	var world_points: Dictionary = canvas.get("world_points")
	var ids: Array[String] = []
	var risk_bounds: Dictionary = {}
	var spatial_valid: bool = world_points.size() == host.store.catalog.rows("sector_defs").size()
	for definition: Dictionary in host.store.catalog.rows("sector_defs"):
		var id: String = str(definition.sector_id)
		ids.append(id)
		if not world_points.has(id):
			spatial_valid = false
			continue
		var point: Vector2 = world_points[id]
		spatial_valid = spatial_valid and is_finite(point.x) and is_finite(point.y)
		var risk: String = str(definition.risk_zone_id)
		if not risk_bounds.has(risk): risk_bounds[risk] = {"minimum_x": point.x, "maximum_x": point.x, "count": 0}
		risk_bounds[risk].minimum_x = minf(float(risk_bounds[risk].minimum_x), point.x)
		risk_bounds[risk].maximum_x = maxf(float(risk_bounds[risk].maximum_x), point.x)
		risk_bounds[risk].count += 1
	for risk: String in risk_bounds:
		if int(risk_bounds[risk].count) > 1:
			spatial_valid = spatial_valid and float(risk_bounds[risk].maximum_x) - float(risk_bounds[risk].minimum_x) > 24.0
	_check(evidence, spatial_valid and not ids.is_empty(), "packed star chart positions every actual frozen sector in space instead of one column per risk level")
	var endpoint_groups: Dictionary = {}
	for endpoint: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
		var connection_id: String = str(endpoint.connection_id)
		if not endpoint_groups.has(connection_id): endpoint_groups[connection_id] = []
		endpoint_groups[connection_id].append(endpoint)
	var links_valid: bool = chart.get("links").size() == endpoint_groups.size()
	var seen_connections: Dictionary = {}
	for link: Dictionary in chart.get("links"):
		var identity: String = str(link.connection_id)
		links_valid = links_valid and not seen_connections.has(identity) and endpoint_groups.has(identity)
		seen_connections[identity] = true
		var expected: Array = endpoint_groups.get(identity, [])
		var actual: Array = link.get("endpoints", [])
		var expected_ids: Array[String] = []
		var actual_ids: Array[String] = []
		var forward: bool = false
		var reverse: bool = false
		for endpoint: Dictionary in expected:
			expected_ids.append(str(endpoint.endpoint_id))
			forward = forward or (str(endpoint.origin_sector_id) == str(link.origin) and str(endpoint.target_sector_id) == str(link.destination))
			reverse = reverse or (str(endpoint.origin_sector_id) == str(link.destination) and str(endpoint.target_sector_id) == str(link.origin))
		for endpoint: Dictionary in actual:
			actual_ids.append(str(endpoint.endpoint_id))
			links_valid = links_valid and expected.has(endpoint)
		expected_ids.sort()
		actual_ids.sort()
		links_valid = links_valid and forward and expected_ids == actual_ids and bool(link.get("bidirectional", false)) == reverse
	_check(evidence, links_valid, "packed star chart preserves every actual connection and the direction of its frozen door endpoints")
	host.ui.page_scroll.ensure_control_visible(canvas)
	for frame: int in range(3): await host.get_tree().process_frame
	_check(evidence, canvas.is_visible_in_tree() and host.ui.page_scroll.get_global_rect().grow(0.5).encloses(canvas.get_global_rect()) and Rect2(Vector2.ZERO, host.ui.root.size).encloses(canvas.get_global_rect()), "packed star chart canvas fits completely inside the page scroll viewport")
	ids.sort()
	var foreign: String = ""
	for id: String in ids:
		if id != origin:
			foreign = id
			break
	chart.call("select_sector", foreign)
	for frame: int in range(3): await host.get_tree().process_frame
	var details: Control = host.ui.map_details
	var selection_valid: bool = not foreign.is_empty() and str(chart.get("selected_sector")) == foreign and is_instance_valid(details)
	if selection_valid:
		selection_valid = str(details.get_meta("selected_sector", "")) == foreign and details.get_child_count() == 1 and host.ui.body.find_children("SelectedSectorDetails", "VBoxContainer", true, false).size() == 1
	_check(evidence, selection_valid, "packed star chart selection rebuilds exactly one detail panel for the selected external sector")
	var expected_resources: Array[String] = []
	var shown_resources: Array[String] = []
	for definition: Dictionary in host.store.catalog.rows("resource_node_defs"):
		if str(definition.sector_id) == foreign: expected_resources.append(str(definition.node_id))
	var readouts_valid: bool = selection_valid
	for readout: Dictionary in host.ui.map_resource_readouts:
		shown_resources.append(str(readout.node_id))
		readouts_valid = readouts_valid and str(readout.sector_id) == foreign and is_instance_valid(readout.label) and details.is_ancestor_of(readout.label)
	expected_resources.sort()
	shown_resources.sort()
	_check(evidence, readouts_valid and shown_resources == expected_resources, "packed selected-sector resource readouts contain exactly that sector's real mineral nodes")
	var search: LineEdit = chart.get("search_box")
	var risk_filter: OptionButton = chart.get("risk_filter")
	var navigator: OptionButton = chart.get("navigator")
	search.text = foreign
	search.text_changed.emit(foreign)
	for frame: int in range(3): await host.get_tree().process_frame
	_check(evidence, navigator.item_count == 1 and str(navigator.get_item_metadata(0)) == foreign and str(chart.get("selected_sector")) == foreign, "packed search control finds the exact sector ID without changing its selected intelligence")
	search.text = ""
	search.text_changed.emit("")
	risk_filter.select(3)
	risk_filter.item_selected.emit(3)
	for frame: int in range(3): await host.get_tree().process_frame
	var low_risk_count: int = 0
	for definition: Dictionary in host.store.catalog.rows("sector_defs"):
		if str(definition.risk_zone_id) == "risk_low": low_risk_count += 1
	_check(evidence, low_risk_count > 0 and navigator.item_count == low_risk_count and str(chart.get("selected_sector")) == foreign and str(details.get_meta("selected_sector", "")) == foreign, "packed risk filter limits navigator matches while keeping the selected sector and its single detail panel")
	risk_filter.select(0)
	risk_filter.item_selected.emit(0)
	var anchor: Vector2 = canvas.size * Vector2(0.37, 0.42)
	var before_anchor: Vector2 = canvas.call("screen_to_world", anchor)
	var before_zoom: float = float(canvas.get("zoom"))
	canvas.call("zoom_at", 1.2, anchor)
	_check(evidence, float(canvas.get("zoom")) > before_zoom and Vector2(canvas.call("screen_to_world", anchor)).distance_to(before_anchor) < 0.001, "packed star chart zoom keeps the world point beneath its chosen screen anchor")
	canvas.call("center_on", foreign)
	var centered: bool = (Vector2(world_points.get(foreign, Vector2(1e20, 1e20))) * float(canvas.get("zoom")) + Vector2(canvas.get("pan"))).distance_to(canvas.size * 0.5) < 0.01
	canvas.call("fit_all")
	var fitted: bool = not world_points.is_empty()
	for id: String in world_points:
		fitted = fitted and Rect2(Vector2.ZERO, canvas.size).has_point(Vector2(world_points[id]) * float(canvas.get("zoom")) + Vector2(canvas.get("pan")))
	_check(evidence, centered and fitted, "packed selected-sector centering and full-map restore keep every actual node inside the canvas")
	chart.call("restore_view", original_view)
	chart.call("focus_current")
	chart.call("fit_all")
	host.ui.page_scroll.ensure_control_visible(canvas)
	for frame: int in range(3): await host.get_tree().process_frame
	_check(evidence, host.state.current_sector() == origin and host.ui.target_id == initial_target and host.store._codec.encode_row("player_state", host.state.player()) == initial_player and host.store._codec.encode_row("ship_state", host.state.ship()) == initial_ship and host.store._codec.encode_row("save_snapshot", host.state.snapshot.meta) == initial_meta and host.world.flight.global_transform.is_equal_approx(initial_pose), "packed star chart view operations preserve the player's actual sector, target, ship, funds, pose and simulation snapshot")
	_check(evidence, _star_chart_durable_state(host) == initial_durable, "packed star chart view operations leave all SQLite snapshots, slots, sessions and persisted player and ship rows unchanged")
	host.set_process(process_enabled)
	host.set_physics_process(physics_enabled)

static func _business_rows(host: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in host.ui.body.find_children("*", "VBoxContainer", true, false):
		if not bool(node.get_meta("business_list", false)): continue
		var values: Variant = node.get("rows")
		if values is Array:
			for entry: Dictionary in values: result.append(entry)
	return result

static func _business_show(host: Node, page: String, filter: String = "") -> void:
	if not filter.is_empty(): host.ui.market_filter = filter
	host.ui.show_page(page)
	for frame: int in range(4): await host.get_tree().process_frame
	host.ui.tick(1.0)
	for frame: int in range(3): await host.get_tree().process_frame

static func _business_list_checks(host: Node, evidence: Dictionary, output_dir: String) -> void:
	# Read-only business presentation in the already fresh diagnostic world.
	# Only the UI quantity changes; funds, stock, unlocks and assets are untouched.
	var process_enabled: bool = host.is_processing()
	var physics_enabled: bool = host.is_physics_processing()
	host.set_process(false); host.set_physics_process(false)
	var initial_credit: int = host.state.player().credit
	var initial_ship: String = host.state.ship().ship_instance_id
	var initial_pose: Transform3D = host.world.flight.global_transform
	var initial_quantity: int = host.ui.quantity_value
	var initial_filter: String = host.ui.market_filter
	var economy: RefCounted = host.gameplay.get("economy")
	await _business_show(host, "market", "buy")
	var goods: Array[Dictionary] = _business_rows(host)
	var goods_valid: bool = not goods.is_empty()
	var columns_ordered: bool = not goods.is_empty()
	var quotes_valid: bool = not goods.is_empty()
	for entry: Dictionary in goods:
		goods_valid = goods_valid and bool(entry.row.get_meta("business_row", false)) and entry.image.texture != null and entry.image.texture.get_width() > 0 and not entry.name.text.is_empty() and not entry.description.text.is_empty() and not entry.unit.text.is_empty()
		var previous_x: float = -INF
		for key: String in ["image", "name", "unit", "quantity", "unit_price", "total", "status", "actions"]:
			var control: Control = entry[key]
			columns_ordered = columns_ordered and control.global_position.x >= previous_x - 0.5
			previous_x = control.global_position.x
		for button: Node in entry.row.find_children("*", "Button", true, false): columns_ordered = columns_ordered and entry.actions.is_ancestor_of(button)
		var id: String = str(entry.row.get_meta("row_id", ""))
		var stock: RefCounted = economy.call("_stock", id)
		quotes_valid = quotes_valid and stock != null and int(entry.unit_price.get_meta("quote_amount", -1)) == int(economy.call("quote", id, 1, false)) and int(entry.total.get_meta("quote_amount", -1)) == int(economy.call("quote", id, initial_quantity, false)) and (stock == null or entry.status.text.contains(str(stock.quantity)))
	_check(evidence, goods_valid, "packed market goods use real item identities, nonempty images, descriptions and units")
	_check(evidence, columns_ordered, "packed business columns place images, descriptions, units, quantities, quotes and status before the final operation column")
	_check(evidence, quotes_valid, "packed goods preserve actual frozen stock and reputation/tax unit and total quotes")
	await _capture(host, output_dir, "business-goods")
	var first_row: Node = goods[0].row if not goods.is_empty() else null
	var list_node: Node = first_row.get_parent() if first_row != null else null
	var changed_valid: bool = first_row != null and is_instance_valid(host.ui.quantity_input)
	if changed_valid:
		host.ui.quantity_input.value = 2
		for frame: int in range(3): await host.get_tree().process_frame
		var changed_rows: Array[Dictionary] = _business_rows(host)
		changed_valid = changed_rows.size() == goods.size() and changed_rows[0].row == first_row and first_row.get_parent() == list_node
		for entry: Dictionary in changed_rows:
			var id: String = str(entry.row.get_meta("row_id", ""))
			changed_valid = changed_valid and entry.quantity.text == "2" and int(entry.total.get_meta("quote_amount", -1)) == int(economy.call("quote", id, 2, false)) and int(entry.unit_price.get_meta("quote_amount", -1)) == int(economy.call("quote", id, 1, false))
		host.ui.quantity_input.value = initial_quantity
		for frame: int in range(3): await host.get_tree().process_frame
	_check(evidence, changed_valid, "packed SpinBox refreshes real rounded quotes on the same list rows and restores its original quantity")
	await _business_show(host, "market", "ships")
	var hulls: Array[Dictionary] = _business_rows(host)
	var hulls_valid: bool = not hulls.is_empty()
	var shortage_quote: bool = false
	var hull_quotes: bool = not hulls.is_empty()
	for entry: Dictionary in hulls:
		var id: String = str(entry.row.get_meta("row_id", ""))
		var price: int = int(economy.call("quote_ship", id, false))
		hulls_valid = hulls_valid and entry.image.texture != null and entry.image.texture.get_width() > 0 and entry.unit.text == "艘" and entry.quantity.text == "1" and not entry.description.text.is_empty()
		hull_quotes = hull_quotes and int(entry.unit_price.get_meta("quote_amount", -1)) == price and int(entry.total.get_meta("quote_amount", -1)) == price
		if price > initial_credit:
			var disabled: bool = false
			for button: Node in entry.actions.find_children("*", "Button", true, false): disabled = disabled or button.disabled
			shortage_quote = shortage_quote or disabled and entry.status.text.contains("信用点不足") and entry.total.text == str(price)
	_check(evidence, hulls_valid, "packed hull list keeps vessel portraits, descriptions, unit and one-vessel transaction quantity")
	_check(evidence, hull_quotes and shortage_quote, "packed hull prices use real taxed quotes and remain readable when funds disable purchasing")
	await _capture(host, output_dir, "business-hulls")
	var all_lists: bool = true
	for variant: Dictionary in [{"page": "ships", "filter": ""}, {"page": "warehouse", "filter": ""}, {"page": "fitting", "filter": ""}, {"page": "industry", "filter": ""}, {"page": "research", "filter": ""}, {"page": "missions", "filter": ""}, {"page": "market", "filter": "buy"}, {"page": "market", "filter": "ships"}, {"page": "market", "filter": "sell"}]:
		await _business_show(host, str(variant.page), str(variant.filter))
		if variant.page == "warehouse":
			var warehouse: Control = host.ui.warehouse_panel
			all_lists = all_lists and is_instance_valid(warehouse) and not warehouse.refs.rows_by_id.is_empty()
			await _warehouse_fixed_checks(host, evidence, output_dir)
		else: all_lists = all_lists and not _business_rows(host).is_empty()
	_check(evidence, all_lists, "packed warehouse uses its two inventory panes while fleet, loans, fitting, industry, research, missions and all market modes retain populated business lists")
	host.ui.quantity_value = initial_quantity
	host.ui.market_filter = initial_filter
	await _business_show(host, "station")
	_check(evidence, host.ui.page == "station" and host.ui.station_layer.is_visible_in_tree() and host.ui.quantity_value == initial_quantity and host.state.player().credit == initial_credit and host.state.ship().ship_instance_id == initial_ship and host.world.flight.global_transform.is_equal_approx(initial_pose), "packed business presentation restores the station and original quantity without changing funds, assets or the existing starting pose")
	host.set_process(process_enabled); host.set_physics_process(physics_enabled)

static func _warehouse_fixed_checks(host: Node, evidence: Dictionary, output_dir: String) -> void:
	# This fixed endpoint only reads the fresh world's real starting inventory.
	# Remote stations and actual transfers are covered by the separate v16 endpoint.
	var pane: Control = host.ui.warehouse_panel
	var valid: bool = is_instance_valid(pane)
	var refs: Dictionary = pane.refs if valid else {}
	var rows: Array[Dictionary] = []
	if valid:
		rows.append_array(refs.ship_rows)
		rows.append_array(refs.station_rows)
		var left: Control = refs.ship_column
		var right: Control = refs.station_column
		var scroll_left: ScrollContainer = refs.ship_scroll
		var scroll_right: ScrollContainer = refs.station_scroll
		valid = scroll_left != scroll_right and left.global_position.x + left.size.x <= right.global_position.x + 1.0 and absf(left.global_position.y - right.global_position.y) <= 1.0 and host.ui.page_scroll.get_global_rect().encloses(left.get_global_rect()) and host.ui.page_scroll.get_global_rect().encloses(right.get_global_rect())
	_check(evidence, valid and host.ui.quantity_input == null and host.ui.body.find_child("OperationQuantity", true, false) == null, "packed warehouse has left cargo and right station panes, independent scrolling and no global operation quantity")
	var authority_before: String = _warehouse_authority_signature(host)
	var source_valid: bool = not rows.is_empty()
	var expected: Dictionary = {}
	for table: String in ["inventory_stack_state", "item_instance_state"]:
		for source: RefCounted in host.state.rows(table):
			var container: RefCounted = host.state.find("container_state", "container_id", source.container_id)
			if container == null or container.owner_player_id != host.state.player().player_id: continue
			if container.kind != Types.ContainerKind.STATION and not (container.kind in [Types.ContainerKind.CARGO, Types.ContainerKind.MINERAL] and container.ship_instance_id == host.state.ship().ship_instance_id): continue
			var id: String = str(source.stack_id) if table == "inventory_stack_state" else str(source.item_instance_id)
			expected[id] = int(source.quantity) if table == "inventory_stack_state" else 1
	for row: Dictionary in rows:
		source_valid = source_valid and expected.has(row.id) and int(str(row.quantity.text).get_slice(" ", 0)) == int(expected.get(row.id, -1)) and not str(row.name.text).is_empty() and not str(row.location.text).is_empty() and row.image.texture != null and row.image.texture.get_width() > 0
	source_valid = source_valid and rows.size() == expected.size()
	_check(evidence, source_valid, "packed warehouse rows retain real owned asset identities, held quantities, portraits and explicit compartment or station locations")
	var eligibility: bool = not rows.is_empty()
	var protected_rows: int = 0
	var editable: Array[Dictionary] = []
	var inventory: RefCounted = host.gameplay.get("inventory")
	for row: Dictionary in rows:
		if bool(row.remote): continue
		var quote: Dictionary = inventory.call("quote_transfer", str(row.kind), str(row.id), int(row.amount.value), str(row.destination))
		eligibility = eligibility and row.button.disabled == (not bool(quote.ok)) and str(row.button.get_meta("target", "")) == str(row.id) and str(row.button.get_meta("extra", "")) == str(row.destination) and row.amount.min_value == 1 and row.amount.value == 1
		if row.policy_id != "normal_owned":
			protected_rows += 1
			eligibility = eligibility and row.button.disabled and not row.amount.editable and not str(quote.reason).is_empty() and str(row.status.text).contains(str(quote.reason))
		elif row.kind == "stack" and row.amount.max_value >= 2: editable.append(row)
	_check(evidence, eligibility and protected_rows > 0, "packed warehouse uses real transfer eligibility and keeps protected starting supplies visible with disabled controls and explicit reasons")
	var independent: bool = editable.size() >= 2
	var original_global: int = host.ui.quantity_value
	if independent:
		var first: Dictionary = editable[0]
		var second: Dictionary = editable[1]
		var held: String = str(first.quantity.text)
		first.amount.value = 2
		for frame: int in range(3): await host.get_tree().process_frame
		independent = first.amount.value == 2 and second.amount.value == 1 and str(first.quantity.text) == held and host.ui.quantity_value == original_global
		first.amount.value = 1
		for frame: int in range(3): await host.get_tree().process_frame
	_check(evidence, independent and _warehouse_authority_signature(host) == authority_before, "packed per-row quantities stay independent of held stock and market quantity without modifying the frozen starting economy or assets")
	await _capture(host, output_dir, "warehouse-dual")

static func _warehouse_authority_signature(host: Node) -> String:
	var codec: XJStateCodec = XJStateCodec.new()
	var result: Dictionary = {}
	for table: String in XJRuntimeState.TABLES:
		var encoded: Array[Dictionary] = []
		for row: RefCounted in host.state.rows(table): encoded.append(codec.encode_row(table, row))
		result[table] = encoded
	return JSON.stringify(result)

static func _mineral_checks(host: Node, evidence: Dictionary, output_dir: String) -> void:
	# A separate fresh world and a legal inventory-created miner are explicit diagnostic
	# prerequisites; this endpoint does not claim to naturally complete the tutorial.
	await host._command("new_world", "发布包矿点检查", 1, "")
	host.set_process(false)
	host.set_physics_process(false)
	var node_id := "node_echo_conductive"
	var definition: Dictionary = host.store.catalog.one("resource_node_defs", "node_id", node_id)
	var location: Dictionary = host.store.catalog.one("resource_node_locations", "node_id", node_id)
	var anchor: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", location.anchor_id)
	var miner: RefCounted = host.gameplay.get("inventory").call("create_ship", "miner_anvil", "station_anchor_port", "normal_owned", "loadout_miner_anvil")
	host.state.player().controlled_ship_id = miner.ship_instance_id
	host.state.player().has_docked_station_id = false
	host.state.player().docked_station_id = ""
	miner.status = Types.ShipStatus.FLYING
	host.state.player().camera_mode = Types.CameraMode.FOLLOW
	miner.has_station_id = false
	miner.station_id = ""
	miner.sector_id = definition.sector_id
	host.gameplay.call("grant_unlock", location.required_unlock_id)
	host.state.find("sector_state", "sector_id", definition.sector_id).visited = true
	var range_m := 0.0
	var cycle_s := 0.0
	for equipment: RefCounted in host.gameplay.call("equipped", miner):
		var mining: Dictionary = host.store.catalog.one("mining_defs", "module_id", equipment.module_def_id)
		if mining.is_empty(): continue
		var module: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment.module_def_id)
		range_m = maxf(range_m, float(module.range_m))
		cycle_s = maxf(cycle_s, float(module.cycle_s))
	var position := Vector3(float(anchor.x_m), float(anchor.y_m), float(anchor.z_m)) + Vector3.UP * range_m * 0.7
	miner.pos_x = position.x; miner.pos_y = position.y; miner.pos_z = position.z
	var facing := Basis.looking_at(Vector3.DOWN, Vector3.FORWARD).get_rotation_quaternion()
	miner.quat_x = facing.x; miner.quat_y = facing.y; miner.quat_z = facing.z; miner.quat_w = facing.w
	for container: RefCounted in host.state.rows("container_state"):
		if container.ship_instance_id == miner.ship_instance_id: container.sector_id = miner.sector_id
	var staged: bool = host._stage_candidate(host.state, host.store.catalog)
	_check(evidence, staged, "packed mineral fixture stages a legal miner and real resource sector")
	if not staged: return
	host._activate(host.state)
	await host.get_tree().physics_frame
	await host.get_tree().process_frame
	host.ui.target_id = node_id
	host.ui.tick(1.0)
	var info := XJResourceStatus.inspect(host.state, host.store.catalog, node_id)
	var context := XJInteractionContext.inspect(host.world, host.state, host.store.catalog, host.gameplay, node_id)
	_check(evidence, info.available and info.remaining_units == int(definition.capacity_units) and context.ready and not host.ui.interaction_button.disabled, "packed resource_state supplies actual full mineral pool and usable interaction")
	host.world.flight.global_position += Vector3.UP * maxf(range_m * 4.0, float(host.store.catalog.rule("target_marker_detection_range_m")) * 2.0)
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.ui.tick(1.0)
	for frame: int in range(2): await host.get_tree().process_frame
	var resource_label: Label = host.ui.overview.resource_label
	var font_height: float = resource_label.get_theme_font("font").get_height(resource_label.get_theme_font_size("font_size"))
	_check(evidence, host.ui.overview.resource_detail.visible and resource_label.text.contains(str(definition.capacity_units)) and resource_label.size.y >= font_height and not resource_label.clip_text and is_equal_approx(host.ui.overview.resource_bar.value, 100.0) and not host.ui.interaction_candidate.in_range, "packed known mineral intelligence has visible text geometry beyond interaction and sensor distance")
	host.ui.show_page("map")
	await host.get_tree().process_frame
	var chart: Node = host.ui.body.find_child("StarChart", true, false)
	_check(evidence, chart != null and chart.resource_information.text.contains(str(definition.capacity_units)) and host.ui.map_resource_readouts.any(func(row: Dictionary): return row.node_id == node_id and row.label.text.contains(str(definition.capacity_units))), "packed star chart and sector cards show real mineral reserve")
	host.ui._back()
	host.world.flight.global_position = position
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	await host.get_tree().physics_frame
	await host.get_tree().process_frame
	var resource: RefCounted = host.state.find("resource_state", "node_id", node_id)
	# Bound the fixture to a final unit, then consume it through the real mining cycle.
	resource.remaining_units = 1
	var mineral_hold: String = host.gameplay.get("inventory").call("hold", host.state.ship(), Types.ContainerKind.MINERAL)
	var before_units: int = host.gameplay.get("inventory").call("count", mineral_hold, definition.item_id)
	var started: bool = host.gameplay.get("work").call("start_mining", node_id)
	# Pay a genuine production cycle before queuing a manual save. Cancellation
	# releases only the pending save request, leaving the mining cycle intact.
	host.gameplay.call("tick", 1.0 / float(host.store.catalog.rule("simulation_hz")))
	host.ui.tick(1.0)
	host._request_save("manual", 4)
	for frame: int in range(3): await host.get_tree().process_frame
	_check(evidence, started and not host.deferred_save.is_empty() and host.ui.operation_bar.is_visible_in_tree() and host.ui.operation_cancel.is_visible_in_tree() and not host.ui.toast.text.begins_with("保存等待："), "packed paid mineral cycle queues one visible save status without a duplicate yellow message")
	var notice: Rect2 = host.ui.operation_bar.get_global_rect()
	var label: Label = host.ui.operation_label
	var notice_font_height: float = label.get_theme_font("font").get_height(label.get_theme_font_size("font_size"))
	_check(evidence, Rect2(Vector2.ZERO, host.ui.root.size).encloses(notice) and notice.size.x < host.ui.root.size.x * 0.7 and not notice.intersects(host.ui.navigation_frame.get_global_rect()) and not notice.intersects(host.ui.target_panel.get_global_rect()) and not notice.intersects(host.ui.navigation.get_global_rect()) and label.size.y >= notice_font_height and notice.encloses(host.ui.operation_cancel.get_global_rect()), "packed compact save notice keeps readable cancellation clear of sidebars and top tools")
	await _capture(host, output_dir, "save-wait")
	host.ui.operation_cancel.pressed.emit()
	for frame: int in range(3): await host.get_tree().process_frame
	_check(evidence, host.deferred_save.is_empty() and not host.ui.operation_bar.is_visible_in_tree() and host.gameplay.get("work").mining_target == node_id and resource.remaining_units == 1, "packed cancel-save control clears the queued save without cancelling its real mining cycle")
	host.gameplay.call("tick", cycle_s + 1.0 / float(host.store.catalog.rule("simulation_hz")))
	host.ui.tick(1.0)
	var after_units: int = host.gameplay.get("inventory").call("count", mineral_hold, definition.item_id)
	_check(evidence, started and after_units == before_units + 1 and resource.remaining_units == 0 and resource.respawn_remaining_s > 0.0 and host.gameplay.get("work").mining_target.is_empty() and host.ui.overview.resource_label.text.contains("再生"), "packed real mining cycle grants exactly its last finite unit and displays a respawn countdown")
	host.camera.snapped = false
	host.camera.step(1.0)
	host.ui.tick(1.0)
	await _capture(host, output_dir, "resources")
	var left: float = resource.respawn_remaining_s
	host.ui.show_page("pause")
	host._physics_process(1.0)
	_check(evidence, is_equal_approx(resource.respawn_remaining_s, left) and not host.gameplay.get("work").call("start_mining", node_id), "packed paused world preserves mineral clock and depleted pool rejects mining")
	host.set_process(true)
	host.set_physics_process(true)

static func _hud_layout_checks(host: Node, evidence: Dictionary) -> void:
	for frame: int in range(3): await host.get_tree().process_frame
	var ui: Node = host.ui
	var bounds: Rect2 = Rect2(Vector2.ZERO, ui.root.size)
	var tools: Rect2 = ui.navigation.get_global_rect()
	var conditions: Rect2 = ui.instrument.get_global_rect()
	var equipment: Rect2 = ui.equipment_bar.get_global_rect()
	_check(evidence, bounds.encloses(tools) and tools.position.y < ui.root.size.y * 0.2 and not tools.intersects(ui.target_panel.get_global_rect()) and not tools.intersects(ui.navigation_frame.get_global_rect()), "packed flight toolbar sits above the sidebars with separate usable bounds")
	_check(evidence, bounds.encloses(conditions) and bounds.encloses(equipment) and conditions.end.x <= equipment.position.x and absf(conditions.get_center().y - equipment.get_center().y) < 2.0 and not conditions.has_point(ui.root.size * 0.5) and not equipment.has_point(ui.root.size * 0.5), "packed ship conditions and installed equipment share one separated bottom row")
	var scroll: ScrollContainer = ui.overview.target_scroll
	_check(evidence, scroll.size.y > 154.0 and ui.target_panel.get_global_rect().encloses(scroll.get_global_rect()) and not ui.target_panel.get_global_rect().intersects(equipment), "packed tall overview uses available height above the bottom equipment row")
	var readable: bool = true
	for button: Node in ui.navigation.find_children("*", "Button", true, false):
		var padding: Vector2 = button.get_theme_stylebox("normal").get_minimum_size()
		var text_size: Vector2 = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
		readable = readable and tools.encloses(button.get_global_rect()) and text_size.x <= button.size.x - padding.x + 1.0
	_check(evidence, readable and ui.show_ship_button.is_visible_in_tree(), "packed top tools keep real menu labels and ship-recovery control readable")

static func _attitude_checks(host: Node, evidence: Dictionary, output_dir: String) -> void:
	# A legacy tilted pose in this fresh diagnostic world exercises the actual
	# packed Flight/Camera paths. It never opens or repairs the player's save.
	host.set_process(false)
	host.set_physics_process(false)
	var body: XJFlight = host.world.flight
	var original_pose: Transform3D = body.global_transform
	var original_velocity: Vector3 = body.velocity
	var original_mode: Types.CameraMode = host.camera.mode
	var legacy_pose: Transform3D = original_pose
	legacy_pose.basis = (legacy_pose.basis * Basis(Vector3.FORWARD, 0.6)).orthonormalized()
	body.global_transform = legacy_pose
	body.velocity = Vector3.ZERO
	body.clear_intent()
	body.write_back()
	var forward: Vector3 = -body.global_basis.z.normalized()
	var step_s: float = 1.0 / float(host.store.catalog.rule("simulation_hz"))
	var budget: float = float(body.metrics.turn_radps) * step_s
	var bounded: bool = true
	for tick: int in range(int(ceil(PI / budget)) + 2):
		var before: Quaternion = body.quaternion
		body.simulate(step_s)
		var difference: Quaternion = (before.inverse() * body.quaternion).normalized()
		var actual_angle: float = 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))
		bounded = bounded and actual_angle <= budget + 0.00002 and body.global_basis.is_finite()
	var reference_up: Vector3 = Vector3.UP.slide(forward).normalized()
	_check(evidence, bounded and body.global_basis.y.dot(reference_up) > 0.99999 and (-body.global_basis.z).dot(forward) > 0.99999 and body.velocity == Vector3.ZERO and body.global_position.is_equal_approx(original_pose.origin), "packed old tilted pose levels smoothly inside one turn budget without changing its heading or velocity")
	var leveled: Quaternion = body.quaternion
	body.intent.roll_request = 1.0
	body.simulate(step_s)
	var explicit_rotation: Quaternion = (leveled.inverse() * body.quaternion).normalized()
	var explicit_angle: float = 2.0 * atan2(Vector3(explicit_rotation.x, explicit_rotation.y, explicit_rotation.z).length(), absf(explicit_rotation.w))
	_check(evidence, explicit_angle > 0.0 and explicit_angle <= budget + 0.00002 and body.global_basis.y.dot(reference_up) < 0.99999, "packed explicit roll request remains available while held")
	body.global_transform = legacy_pose
	body.clear_intent()
	body.write_back()
	body.reset_physics_interpolation()
	host.camera.bind(body, host.store.catalog, Types.CameraMode.FRONT)
	host.state.player().camera_mode = Types.CameraMode.FRONT
	host.ui.show_ship_button.pressed.emit()
	host.camera.step(0.0)
	_check(evidence, host.camera.mode == Types.CameraMode.FOLLOW and absf(host.camera.camera.global_basis.x.y) < 0.00001 and body.global_transform.is_equal_approx(legacy_pose) and body.velocity == Vector3.ZERO, "packed ship-recovery view removes inherited roll without instantly changing the physical vessel")
	var pole_safe: bool = true
	for pitch: float in [-PI * 0.5, PI * 0.5]:
		var source: Basis = Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, 0.6)
		var aligned: Basis = XJFlight.leveled_basis(source)
		pole_safe = pole_safe and aligned.is_finite() and aligned.is_orthonormal() and aligned.z.dot(source.z) > 0.99999
	_check(evidence, pole_safe, "packed exact vertical headings preserve a finite orthonormal orientation and their heading")
	for tick: int in range(int(ceil(PI / budget)) + 2): body.simulate(step_s)
	body.reset_physics_interpolation()
	host.camera.reset_observation()
	host.camera.step(0.0)
	host.ui.tick(1.0)
	await _capture(host, output_dir, "attitude-level")
	body.global_transform = original_pose
	body.velocity = original_velocity
	body.clear_intent()
	body.write_back()
	body.reset_physics_interpolation()
	host.camera.bind(body, host.store.catalog, original_mode)
	host.state.player().camera_mode = original_mode
	host.camera.step(0.0)
	host.set_process(true)
	host.set_physics_process(true)

static func _manual_turn_camera_checks(host: Node, evidence: Dictionary, output_dir: String) -> void:
	# These stimuli stay in the fresh opt-in diagnostic world. Drive the real
	# Main input and Flight/Camera components without advancing business time.
	var body: XJFlight = host.world.flight
	var original_pose: Transform3D = body.global_transform
	var original_velocity: Vector3 = body.velocity
	var original_spin := Vector3(body.record.angular_x, body.record.angular_y, body.record.angular_z)
	var original_intent = body.intent
	var original_cruising: bool = body.cruising
	var original_mode: Types.CameraMode = host.camera.mode
	var original_player_mode: Types.CameraMode = host.state.player().camera_mode
	var original_orbit: Vector2 = host.camera.orbit
	var original_zoom: float = host.camera.zoom
	var original_observation: Basis = host.camera.observation_basis
	var original_target: String = host.ui.target_id
	var original_process: bool = host.is_processing()
	var original_physics: bool = host.is_physics_processing()
	var original_pointer: Vector2 = host.get_viewport().get_mouse_position()
	var old_actions: Dictionary = {}
	for action: String in ["forward", "back", "up", "down", "pitch_up", "pitch_down", "yaw_left", "yaw_right", "roll_left", "roll_right", "brake", "boost"]:
		old_actions[action] = Input.get_action_strength(action)
		Input.action_release(action)
	host.set_process(false)
	host.set_physics_process(false)
	var station: StaticBody3D = host.world.targets.get("station_anchor_port", {}).get("node")
	var gate: StaticBody3D = null
	for entry: Dictionary in host.world.targets.values():
		if str(entry.kind) == "gate": gate = entry.node; break
	var step_s: float = 1.0 / float(host.store.catalog.rule("simulation_hz"))
	var budget: float = float(body.metrics.turn_radps) * step_s
	var old_bank := Transform3D(Basis.from_euler(Vector3(0.65, -0.4, 0.9)), original_pose.origin + Vector3(0, 2200, 8000))
	await _control_focus_boundary(host, "manual-turn")
	var first_response: bool = true
	var combined_response: bool = true
	for action: String in ["yaw_left", "yaw_right"]:
		var direction: float = 1.0 if action == "yaw_left" else -1.0
		for with_forward: bool in [false, true]:
			body.global_transform = old_bank
			body.velocity = Vector3.ZERO
			body.clear_intent(); body.write_back(); body.reset_physics_interpolation()
			host.camera.bind(body, host.store.catalog, Types.CameraMode.FOLLOW)
			host.state.player().camera_mode = Types.CameraMode.FOLLOW
			if with_forward: host.camera.observe(Vector2(95, -175), float(host.preferences.get("mouse_sensitivity", 0.0)))
			host.camera.step(0.0)
			var before: Quaternion = body.quaternion
			var view_before: Vector3 = host.camera.control_forward()
			var expected: Quaternion = (Basis(Vector3.UP, direction * budget) * body.global_basis).get_rotation_quaternion()
			Input.action_press(action)
			if with_forward: Input.action_press("forward")
			host._read_flight_input(step_s)
			var view_after: Vector3 = host.camera.control_forward()
			var thrust_direction: Vector3 = body.intent.view_thrust_direction
			body.simulate(step_s)
			var difference: Quaternion = (before.inverse() * body.quaternion).normalized()
			var actual_angle: float = 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))
			var expected_error: Quaternion = (expected.inverse() * body.quaternion).normalized()
			var error_angle: float = 2.0 * atan2(Vector3(expected_error.x, expected_error.y, expected_error.z).length(), absf(expected_error.w))
			var correct_turn: bool = actual_angle >= budget * 0.995 and actual_angle <= budget + 0.00002 and error_angle < 0.00002 and view_after.distance_to(Basis(Vector3.UP, direction * budget) * view_before) < 0.00002
			if with_forward:
				combined_response = combined_response and correct_turn and body.velocity.length() > 0.0 and body.velocity.normalized().dot(thrust_direction) > 0.999 and thrust_direction.distance_to(view_after) < 0.00001
			else: first_response = first_response and correct_turn
			Input.action_release(action); Input.action_release("forward")
	_check(evidence, first_response, "packed real Main A/D gives full first-step physical yaw on the camera world axis despite an old pitched bank")
	_check(evidence, combined_response, "packed W plus A/D retains manual steering and accelerates along the actual visible three-dimensional view")
	var station_collision: CollisionShape3D = station.get_node_or_null("CollisionShape3D") if station != null else null
	var gate_collision: CollisionShape3D = gate.get_node_or_null("FrameCollision_0") if gate != null else null
	_check(evidence, station_collision != null and gate_collision != null and (station.collision_layer & 64) != 0 and (gate.collision_layer & 64) != 0, "packed station and wormhole expose their actual solid camera-obstacle geometry")
	for item: Dictionary in [{"name": "station", "collider": station_collision, "target": "station_anchor_port"}, {"name": "wormhole", "collider": gate_collision, "target": ""}]:
		await _near_camera_case(host, evidence, output_dir, item)
	for action: String in old_actions:
		Input.action_release(action)
		if float(old_actions[action]) > 0.0: Input.action_press(action, float(old_actions[action]))
	body.global_transform = original_pose
	body.velocity = original_velocity
	body.intent = original_intent
	body.cruising = original_cruising
	body.write_back(original_spin)
	body.reset_physics_interpolation()
	host.camera.bind(body, host.store.catalog, original_mode)
	host.camera.orbit = original_orbit
	host.camera.zoom = original_zoom
	host.camera.observation_basis = original_observation
	host.state.player().camera_mode = original_player_mode
	host.ui.target_id = original_target
	host.camera.step(0.0)
	host.ui.tick(1.0)
	if DisplayServer.get_name() != "headless": host.get_viewport().warp_mouse(original_pointer)
	host.set_process(original_process)
	host.set_physics_process(original_physics)
	_check(evidence, body.global_transform.is_equal_approx(original_pose) and body.velocity.is_equal_approx(original_velocity) and body.intent == original_intent and host.camera.mode == original_mode and host.state.player().camera_mode == original_player_mode and host.camera.orbit.is_equal_approx(original_orbit) and is_equal_approx(host.camera.zoom, original_zoom) and not host.observing and not host.pointer_drag_pressed, "packed control diagnostic restores the original physical state and view without residual input")

static func _near_camera_case(host: Node, evidence: Dictionary, output_dir: String, item: Dictionary) -> void:
	var collider: CollisionShape3D = item.collider
	if collider == null or not collider.shape is BoxShape3D:
		_check(evidence, false, "packed near-" + str(item.name) + " sphere endpoints remain safe")
		_check(evidence, false, "packed near-" + str(item.name) + " camera movement sweeps remain safe")
		_check(evidence, false, "packed near-" + str(item.name) + " left observation visibly responds and releases cleanly")
		return
	var body: XJFlight = host.world.flight
	var hull: CollisionShape3D = body.get_node("CollisionShape3D")
	var hull_half: Vector3 = (hull.shape as BoxShape3D).size * 0.5
	var obstacle_half: Vector3 = (collider.shape as BoxShape3D).size * 0.5
	body.global_transform = collider.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, obstacle_half.z + hull_half.z + 0.1))
	body.velocity = Vector3.ZERO
	body.clear_intent(); body.write_back(); body.reset_physics_interpolation()
	host.camera.bind(body, host.store.catalog, Types.CameraMode.FOLLOW)
	host.state.player().camera_mode = Types.CameraMode.FOLLOW
	host.ui.target_id = str(item.target)
	await host.get_tree().physics_frame
	await host.get_tree().process_frame
	host.camera.step(0.0)
	host.ui.tick(1.0)
	if DisplayServer.get_name() != "headless": host.get_viewport().warp_mouse(host.ui.root.size * 0.5)
	await host.get_tree().process_frame
	var pose: Transform3D = body.global_transform
	await _control_focus_boundary(host, "near-" + str(item.name))
	var initial_orbit: Vector2 = host.camera.orbit
	var previous_position: Vector3 = host.camera.camera.global_position
	var previous_forward: Vector3 = host.camera.control_forward()
	var endpoints_safe: bool = true
	var paths_safe: bool = true
	var turns: float = 0.0
	var maximum_turn: float = 0.0
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = host.ui.root.size * 0.5
	down.pressed = true
	host._unhandled_input(down)
	for tick: int in range(24):
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(4, -1.5)
		motion.screen_relative = motion.relative
		motion.position = down.position + motion.relative * (tick + 1)
		host._input(motion)
		host.camera.step(1.0 / 60.0)
		var at: Vector3 = host.camera.camera.global_position
		var forward: Vector3 = host.camera.control_forward()
		var query: PhysicsShapeQueryParameters3D = _near_camera_query(host, at)
		var space: PhysicsDirectSpaceState3D = host.camera.get_world_3d().direct_space_state
		endpoints_safe = endpoints_safe and space.intersect_shape(query, 1).is_empty() and at.is_finite() and host.camera.camera.global_basis.is_finite() and absf(host.camera.camera.global_basis.determinant() - 1.0) < 0.0001 and at.distance_to(host.camera.render_position()) >= host.camera.camera.near * 2.0
		query.transform.origin = previous_position
		query.motion = at - previous_position
		if not query.motion.is_zero_approx():
			var fractions: PackedFloat32Array = space.cast_motion(query)
			paths_safe = paths_safe and fractions.size() >= 2 and fractions[0] >= 0.999
		var angle: float = previous_forward.angle_to(forward)
		turns += angle
		maximum_turn = maxf(maximum_turn, angle)
		previous_forward = forward
		previous_position = at
		await host.get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = down.position + Vector2(96, -36)
	up.pressed = false
	host._input(up)
	var held: Vector2 = host.camera.orbit
	for tick: int in range(8): host.camera.step(1.0 / 60.0)
	_check(evidence, endpoints_safe, "packed near-" + str(item.name) + " complete camera sphere stays finite, clear and separated from the ship")
	_check(evidence, paths_safe, "packed near-" + str(item.name) + " every rendered camera move has a clear swept-sphere path")
	_check(evidence, not held.is_equal_approx(initial_orbit) and host.camera.orbit.is_equal_approx(held) and turns > 0.002 and maximum_turn < 0.8 and not host.observing and not host.camera.observing and not host.pointer_drag_pressed and not host.pointer_pick_pending and body.global_transform.is_equal_approx(pose) and body.velocity == Vector3.ZERO and not host.local_navigation.active(), "packed near-" + str(item.name) + " actual left drag visibly rotates without reversal, ship movement or a release click")
	if str(item.name) == "station": await _capture(host, output_dir, "camera-near-station")

static func _control_focus_boundary(host: Node, label: String) -> void:
	if DisplayServer.get_name() != "headless":
		host.get_window().grab_focus()
		var deadline: int = Time.get_ticks_msec() + 10000
		while not host.get_window().has_focus() and Time.get_ticks_msec() < deadline:
			await host.get_tree().process_frame
		host.get_viewport().warp_mouse(host.ui.root.size * 0.5)
		await host.get_tree().process_frame
		await host.get_tree().process_frame
	var focus: Control = host.get_viewport().gui_get_focus_owner()
	print("PRESENTATION_INPUT_BOUNDARY ", JSON.stringify({"case": label, "window_focus": host.get_window().has_focus(), "allowed": host._keyboard_control_allowed(), "page": host.ui.page, "menu": host.ui.menu_open, "panel": host.ui.panel.visible, "ui_pointer_blocked": host.ui.ui_input_blocked(), "focus_owner": str(focus.get_path()) if is_instance_valid(focus) else "", "busy": host.busy, "ship_status": int(host.state.ship().status), "pointer_drag": host.pointer_drag_pressed, "mouse_buttons": Input.get_mouse_button_mask()}))

static func _near_camera_query(host: Node, at: Vector3) -> PhysicsShapeQueryParameters3D:
	# Independently rebuild the required clearance from the shipped profile and
	# near-plane frustum; endpoint and movement tests query the actual World3D.
	var profile: Dictionary = host.camera._profile()
	var size: Vector2 = host.camera.camera.get_viewport().get_visible_rect().size
	var aspect: float = maxf(size.x, size.y) / maxf(1.0, minf(size.x, size.y))
	var near_half: float = host.camera.camera.near * tan(deg_to_rad(host.camera.camera.fov) * 0.5)
	var ball := SphereShape3D.new()
	ball.radius = maxf(0.01, maxf(float(profile.collision_margin_m), near_half * sqrt(1.0 + aspect * aspect)) - 0.002)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.margin = 0.0
	query.collision_mask = 64
	query.exclude = [host.world.flight.get_rid()]
	return query

static func _capture(host: Node, directory: String, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(8): await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := directory.path_join("release-" + name + ".png")
	var result := host.get_viewport().get_texture().get_image().save_png(path)
	if result != OK: push_error("Release presentation capture failed: " + path)
	else: print("PRESENTATION_CAPTURE ", path)

static func _check(evidence: Dictionary, value: bool, label: String) -> void:
	evidence.checks += 1
	if not value: evidence.failures += 1
	print(("PASS " if value else "FAIL ") + label)

static func _finish(evidence: Dictionary) -> bool:
	print("PRESENTATION_CLIENT_RESULT ", "PASS" if int(evidence.failures) == 0 else "FAIL", " checks=", evidence.checks, " failures=", evidence.failures)
	return int(evidence.failures) == 0
