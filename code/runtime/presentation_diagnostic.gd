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
	await _capture(host, output_dir, "flight")
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
