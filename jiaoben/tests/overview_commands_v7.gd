extends SceneTree
## Actual Main, controls and viewport GUI events; isolated SQLite only.
## Temporary NPC DTOs use the frozen catalog and are removed before teardown.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var station_id: String
var planet_id: String
var requests: Array[Dictionary] = []
var npcs: Array[D.NpcStateDto] = []
var finishing: bool = false

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): print("OVERVIEW_COMMANDS_V7_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for frame: int in range(count): await process_frame

func request_count(action: String) -> int:
	return requests.filter(func(record: Dictionary): return record.action == action).size()

func first_kind(kind: String) -> String:
	for id: String in host.world.targets:
		if str(host.world.targets[id].kind) == kind: return id
	return ""

func select(id: String) -> void:
	host.ui._select_target(id)
	host.ui.tick(1.0)
	await frames()

func mouse_event(button: Button, pressed: bool, double_click: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.double_click = double_click
	root.push_input(event, true)

func hover(control: Control) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	root.push_input(event, true)
	await frames(2)

func click(button: Button, double_click: bool = false) -> void:
	# A real viewport hit requires the row to be in its scrolling viewport.
	# Testing an offscreen child's coordinates hits a different visible control.
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await frames()
		ancestor = ancestor.get_parent()
	await hover(button)
	mouse_event(button, true, double_click)
	mouse_event(button, false)
	await frames()

func spawn_fixture(id: String, offset: Vector3) -> D.NpcStateDto:
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	var definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", str(spawn.npc_id))
	var npc: D.NpcStateDto = D.NpcStateDto.new()
	npc.npc_instance_id = id
	npc.spawn_id = str(spawn.spawn_id)
	npc.sector_id = host.state.current_sector()
	npc.alive = true
	npc.shield = float(definition.shield_max)
	npc.armor = float(definition.armor_max)
	npc.hull = float(definition.hull_max)
	npc.behavior_phase = T.NpcPhase.PATROL
	var point: Vector3 = host.world.flight.global_position + offset
	npc.pos_x = point.x; npc.pos_y = point.y; npc.pos_z = point.z
	if not host.state.add("npc_state", npc) or not host.world.sync_entities(): return null
	npcs.append(npc)
	return npc

func _run() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	host = Main.new()
	host.progress_database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/overview-commands-v7-%d.db" % Time.get_ticks_usec())
	root.add_child(host)
	host.set_process(false)
	host.set_physics_process(false)
	await frames()
	if not check(host.services_ready, "real Main opens fresh isolated SQLite and validates resources"): await finish(); return
	await host._command("new_world", "目标总览与交战指令独立验收", 1, "")
	if not check(host.state != null, "fresh world uses real SQLite rather than fabricated gameplay state"): await finish(); return
	await host._command("undock", "", 1, "")
	while host.busy: await process_frame
	host.ui.show_page("")
	host._sync_presentation_stage()
	station_id = first_kind("station")
	planet_id = first_kind("planet")
	if not check(not station_id.is_empty() and not planet_id.is_empty(), "real sector supplies a station and bearing-only celestial"): await finish(); return
	var station: Node3D = host.world.targets[station_id].node
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, station.global_position + Vector3(8000, 3500, 14000))
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.camera.step(1.0)
	host.ui.tick(1.0)
	await frames()
	host.ui.requested.connect(func(action: String, id: String, quantity: int, extra: String): requests.append({"action": action, "id": id, "quantity": quantity, "extra": extra}))
	check(host.world.visible and not host.hangar.visible and root.get_camera_3d() == host.camera.camera, "actual flight scene and camera remain active while simulation is frozen")
	await row_commands()
	await invalid_replacement()
	var first: D.NpcStateDto = spawn_fixture("overview-v7-live-first", Vector3(220, 180, -1200))
	var second: D.NpcStateDto = spawn_fixture("overview-v7-live-second", Vector3(-420, 230, -1500))
	if not check(first != null and second != null, "temporary enemies project frozen SQLite archetypes through production sync_entities"): await finish(); return
	await combat_commands(first, second)
	await layouts(first)
	await finish()

func row_commands() -> void:
	var overview: XJOverviewPanel = host.ui.overview
	await select("")
	var row: Button = overview.target_buttons[station_id]
	var row_instance: int = row.get_instance_id()
	var before: Transform3D = host.world.flight.global_transform
	requests.clear()
	await click(row)
	check(host.ui.target_id == station_id and request_count("nav_approach") == 0 and not host.local_navigation.active(), "real GUI single click selects the row without sending navigation")
	check(not host.pointer_drag_pressed and not host.pointer_pick_pending and not host.fire_held and not host.observing, "HUD row click does not leak into scene drag, ray-pick or fixed weapon firing")
	var generation: int = host.navigation_generation
	await click(row, true)
	check(request_count("nav_approach") == 1 and requests[0].id == station_id and requests[0].quantity == 1, "same real GUI row double-click sends exactly one approach request for its own identity")
	check(overview.target_buttons[station_id].get_instance_id() == row_instance and host.navigation_generation == generation + 1, "same persistent row causes exactly one accepted Main navigation generation")
	check(host.local_navigation.active() and host.local_navigation.mode == "approach" and host.local_navigation.target_id == station_id and host.world.flight.global_transform.is_equal_approx(before), "double-click reaches actual approach controller without teleporting the ship")
	mouse_event(row, false, true)
	await frames()
	check(request_count("nav_approach") == 1 and host.navigation_generation == generation + 1, "extra double-click release does not replay the approach command")
	await host._command("nav_stop", "", 1, "")
	host.ui.tick(1.0)
	await frames()
	requests.clear()
	var planet_row: Button = overview.target_buttons[planet_id]
	await click(planet_row, true)
	check(host.ui.target_id == planet_id and request_count("nav_approach") == 0 and not host.local_navigation.active(), "actual bearing-only celestial double-click selects but cannot issue approach")
	check(not host.pointer_drag_pressed and not host.observing, "bearing row also consumes its GUI click without starting observation")

func invalid_replacement() -> void:
	await host._command("nav_approach", station_id, 1, "")
	var generation: int = host.navigation_generation
	var pose: Transform3D = host.world.flight.global_transform
	var foreign: String = ""
	for record: Dictionary in host.store.catalog.rows("station_defs"):
		if str(record.sector_id) != host.state.current_sector(): foreign = str(record.station_id); break
	check(not foreign.is_empty(), "frozen catalog supplies an actual foreign-sector station for refusal")
	await host._command("nav_approach", foreign, 1, "")
	check(host.local_navigation.active() and host.local_navigation.target_id == station_id and host.navigation_generation == generation and host.world.flight.global_transform.is_equal_approx(pose), "real Main rejects foreign replacement without discarding accepted station approach or pose")
	await host._command("nav_approach", "no-such-overview-target", 1, "")
	check(host.local_navigation.target_id == station_id and host.navigation_generation == generation and not host.navigation_context("no-such-overview-target").approach_ready, "missing target cannot retarget or stop actual active navigation")
	await host._command("nav_stop", "", 1, "")

func combat_commands(first: D.NpcStateDto, second: D.NpcStateDto) -> void:
	var overview: XJOverviewPanel = host.ui.overview
	await select(first.npc_instance_id)
	var engage: Button = overview.action_buttons.combat_engage
	var context: Dictionary = host.navigation_context(first.npc_instance_id)
	if not check(context.combat_engage_ready and engage.is_visible_in_tree() and not engage.disabled, "actual live detected enemy and fitted weapon enable visible engage action"): return
	first.alive = false
	host.ui._update_navigation()
	check(engage.disabled and not host.navigation_context(first.npc_instance_id).combat_engage_ready and not engage.tooltip_text.is_empty(), "real NPC death disables engage with a controller-supplied reason")
	first.alive = true
	host.busy = true
	host.ui._update_navigation()
	check(engage.disabled and not host.navigation_context(first.npc_instance_id).combat_engage_ready, "actual Main busy boundary disables engage without UI-invented eligibility")
	host.busy = false
	host.ui._update_navigation()
	await frames()
	requests.clear()
	await click(engage)
	check(request_count("combat_engage") == 1 and requests[0].id == first.npc_instance_id, "real engage Button GUI sends one command with exact selected hostile identity")
	check(host.auto_fire_target == first.npc_instance_id and host.local_navigation.target_id == first.npc_instance_id and host.local_navigation.mode == "approach", "actual Main engage composes qualified approach and independent targeted auto-fire")
	await select(second.npc_instance_id)
	context = host.navigation_context(second.npc_instance_id)
	check(host.auto_fire_target == first.npc_instance_id and host.local_navigation.target_id == first.npc_instance_id and not context.combat_active, "viewing another real hostile does not switch accepted navigation or firing target")
	check(overview.status_label.text.contains(str(context.combat_target_title)) and overview.status_label.text.contains(str(context.combat_target_status)) and not str(context.combat_target_title).is_empty(), "selected card displays global actual firing identity and truthful weapon waiting status when viewing another target")
	await select(station_id)
	context = host.navigation_context(station_id)
	check(overview.status_label.text.contains(str(context.combat_target_title)) and host.auto_fire_target == first.npc_instance_id and not overview.action_buttons.combat_engage.visible, "station selection preserves global firing readout while hiding hostile-only engage action")
	await host._command("nav_stop", "", 1, "")
	check(not host.local_navigation.active() and host.auto_fire_target == first.npc_instance_id, "real stop-ship action stops navigation while retaining independent auto-fire")
	await host._command("combat_toggle", first.npc_instance_id, 1, "")
	check(host.auto_fire_target.is_empty(), "explicit firing toggle alone disarms actual auto-fire identity")
	await select(first.npc_instance_id)

func text_fits(control: Control, text: String) -> bool:
	var font_size: int = control.get_theme_font_size("font_size")
	var face: Font = control.get_theme_font("font")
	var width: float = control.size.x
	var height: float = control.size.y
	if control is Button:
		var style: StyleBox = control.get_theme_stylebox("normal")
		width -= style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
		height -= style.get_content_margin(SIDE_TOP) + style.get_content_margin(SIDE_BOTTOM)
	return font_size >= 10 and face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width + 0.5 and face.get_height(font_size) <= height + 0.5

func find_tooltip(node: Node, text: String) -> Label:
	if node is Label and node.is_visible_in_tree() and node.text == text: return node
	for child: Node in node.get_children(true):
		var found: Label = find_tooltip(child, text)
		if found != null: return found
	return null

func native_popup_check(control: Control, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await hover(control)
	await create_timer(0.75).timeout
	await frames()
	var tooltip: Label = find_tooltip(root, control.tooltip_text)
	if check(tooltip != null, "native real hover creates the configured tooltip " + label):
		var popup: Window = tooltip.get_window()
		check(popup.size.x <= root.size.x and popup.size.y <= root.size.y and Rect2(Vector2.ZERO, Vector2(popup.size)).encloses(tooltip.get_global_rect()), "native tooltip text fits popup and popup fits game-window dimensions " + label)
	await capture(label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(3)
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/logs/overview-commands-v7-" + label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "native capture " + label)
	captures += 1

func layouts(first: D.NpcStateDto) -> void:
	var overview: XJOverviewPanel = host.ui.overview
	for window_size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = window_size
			root.content_scale_size = Vector2i(Vector2(window_size) / scale)
			await frames(4)
			await select(first.npc_instance_id)
			var label: String = "%dx%d-%d" % [window_size.x, window_size.y, int(scale * 100)]
			var viewport: Rect2 = Rect2(Vector2.ZERO, host.ui.root.size)
			check(viewport.encloses(overview.get_global_rect()) and viewport.encloses(host.ui.equipment_bar.get_global_rect()) and viewport.encloses(host.ui.instrument.get_global_rect()), "actual overview/equipment/instrument outer dimensions fit " + label)
			check(not overview.get_global_rect().intersects(host.ui.instrument.get_global_rect()) and not overview.get_global_rect().intersects(host.ui.equipment_bar.get_global_rect()), "hostile operation card does not overlap central flight HUD " + label)
			var actions: Array[Button] = [overview.action_buttons.nav_approach, overview.action_buttons.nav_orbit, overview.action_buttons.combat_engage, overview.action_buttons.combat_toggle]
			var actions_fit: bool = true
			for button: Button in actions: actions_fit = actions_fit and button.is_visible_in_tree() and overview.selection_card.get_global_rect().encloses(button.get_global_rect()) and text_fits(button, button.text)
			check(actions_fit and overview.action_grid.columns == 2, "real engage/auto-fire Z and navigation labels fit their two-column card " + label)
			check(overview.selected_title.mouse_filter == Control.MOUSE_FILTER_PASS and overview.selected_distance.mouse_filter == Control.MOUSE_FILTER_PASS and overview.status_label.mouse_filter == Control.MOUSE_FILTER_PASS, "selected text consumes no scene mouse event and exposes tooltips " + label)
			check(overview.action_buttons.combat_engage.tooltip_text.contains("接近") and overview.action_buttons.combat_toggle.tooltip_text.contains("Z") and host.ui.show_ship_button.tooltip_text.contains("左键"), "live operation tooltips teach distinct engage/fire/observation behavior " + label)
			await capture("layout-" + label)
			await select("")
			check(text_fits(overview.selected_distance, overview.selected_distance.text) and overview.selected_distance.tooltip_text.contains("单次选择"), "empty-selection short hint fits with full selection/command explanation " + label)
			if host.ui.controls.is_visible_in_tree(): check(text_fits(host.ui.controls, host.ui.controls.text) and viewport.encloses(host.ui.controls.get_global_rect()), "visible permanent pointer hint fits its own and viewport dimensions " + label)
			await native_popup_check(overview.selected_distance, "tooltip-" + label)
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	await frames()
	if DisplayServer.get_name() == "headless": print("SKIP native tooltip rendering and four-layout screenshots; headless geometry/events are still checked")

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host):
		host.auto_fire_target = ""
		host.world.projectiles.clear() if host.world != null else null
		for npc: D.NpcStateDto in npcs: host.state.remove("npc_state", npc)
		host.queue_free()
	host = null
	await frames(3)
	await create_timer(0.25).timeout
	print("OVERVIEW_COMMANDS_V7_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
