extends SceneTree
## Actual Main/fresh SQLite HUD regression. Explicit owned-hull/unlock/position
## fixtures supply legal runtime DTOs; they do not claim purchases or campaign
## traversal. Long messages below are presentation inputs, not business events.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var step_s: float
var old_hz: int
var old_fps: int
var miner_id: String
var mine_id: String = "node_echo_conductive"
var fleet: Array[D.ShipStateDto] = []

func _initialize() -> void:
	create_timer(240.0).timeout.connect(func(): print("HUD_LAYOUT_V9_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 4) -> void:
	for frame: int in range(count): await process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "actual HUD fixture SQLite operation finishes")

func step() -> void:
	await physics_frame
	host._physics_process(step_s)
	host.camera.step(step_s)
	host.ui.tick(step_s)

func viewport_rect() -> Rect2:
	return Rect2(Vector2.ZERO, host.ui.root.size)

func glyphs_fit(label: Label, container: Control, wrapped: bool = true) -> bool:
	if not is_instance_valid(label) or not label.is_visible_in_tree() or label.text.is_empty(): return false
	var face: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	var lines: int = maxi(1, label.get_line_count())
	if label.max_lines_visible > 0: lines = mini(lines, label.max_lines_visible)
	var glyph_rect := Rect2(label.get_global_rect().position, Vector2(label.size.x, face.get_height(size) * lines))
	var readable: bool = label.size.y + 0.5 >= glyph_rect.size.y
	if not wrapped: readable = readable and face.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= label.size.x + 0.5
	return readable and container.get_global_rect().encloses(glyph_rect) and viewport_rect().encloses(glyph_rect)

func button_glyphs_fit(button: Button) -> bool:
	var face: Font = button.get_theme_font("font")
	var size: int = button.get_theme_font_size("font_size")
	var text_size: Vector2 = face.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	return button.is_visible_in_tree() and viewport_rect().encloses(button.get_global_rect()) and not button.text.is_empty() and text_size.x <= button.size.x + 0.5 and face.get_height(size) <= button.size.y + 0.5

func descendant_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button: result.append(child)
		result.append_array(descendant_buttons(child))
	return result

func toolbar_button(prefix: String) -> Button:
	var key: String = {"显示舰船": "show_ship", "任务": "missions", "星图": "map", "系统": "pause"}.get(prefix, "")
	var public_buttons: Dictionary = host.ui.get("toolbar_buttons")
	if public_buttons.has(key): return public_buttons[key] as Button
	for button: Button in descendant_buttons(host.ui.navigation):
		if button.text.begins_with(prefix): return button
	return null

func pointer_to(point: Vector2) -> void:
	host.get_viewport().warp_mouse(point)
	await frames(3)

func gui_input_snapshot(button: Button) -> Dictionary:
	var focus_owner: Control = host.get_viewport().gui_get_focus_owner()
	var hover_owner: Control = host.get_viewport().gui_get_hovered_control()
	var mouse: Vector2 = button.get_global_mouse_position()
	return {
		"page": host.ui.page, "keyboard_blocked": host.ui.keyboard_blocked(),
		"keyboard_allowed": host._keyboard_control_allowed(), "ui_input_blocked": host.ui.ui_input_blocked(),
		"drag_pressed": host.pointer_drag_pressed, "dragged": host.pointer_dragged,
		"pick_pending": host.pointer_pick_pending, "pick_position": str(host.pointer_pick_position),
		"drag_origin": str(host.pointer_drag_origin), "fire_held": host.fire_held,
		"window_focus": root.has_focus(), "focus_owner": str(focus_owner.get_path()) if focus_owner != null else "",
		"hover_owner": str(hover_owner.get_path()) if hover_owner != null else "",
		"mouse": str(mouse), "viewport_mouse": str(host.get_viewport().get_mouse_position()),
		"mouse_inside_button": button.get_global_rect().has_point(mouse),
		"button_rect": str(button.get_global_rect()), "button_disabled": button.disabled,
		"button_visible": button.is_visible_in_tree(), "target_id": host.ui.target_id
	}

func wait_click_target(button: Button) -> Dictionary:
	# A native warp may arrive after a canvas/window resize. Wait for the actual
	# Control pointer and consecutive stable layout frames, never Main flags.
	var started: int = Time.get_ticks_msec()
	var deadline: int = started + 1000
	var previous_rect: Rect2 = button.get_global_rect()
	var stable_frames: int = 0
	var ready: bool = false
	var pointer_sent_to: Vector2 = Vector2.INF
	var native: bool = DisplayServer.get_name() != "headless"
	var last_focus_attempt: int = started - 100
	var last_pointer_attempt: int = started - 50
	while Time.get_ticks_msec() < deadline:
		var now: int = Time.get_ticks_msec()
		if native and not root.has_focus() and now - last_focus_attempt >= 100:
			root.grab_focus()
			last_focus_attempt = now
		var rect: Rect2 = button.get_global_rect()
		var center: Vector2 = rect.get_center()
		var actual_mouse: Vector2 = button.get_global_mouse_position()
		var native_pointer_missed: bool = native and (not rect.has_point(actual_mouse) or actual_mouse.distance_to(center) > 1.5)
		if not center.is_equal_approx(pointer_sent_to) or (native_pointer_missed and now - last_pointer_attempt >= 50):
			host.get_viewport().warp_mouse(center)
			# Real GUI motion supplies the headless viewport's hover source. Native
			# readiness additionally checks the actual Control/OS mouse getter.
			var motion := InputEventMouseMotion.new()
			motion.position = center; motion.global_position = center
			host.get_viewport().push_input(motion, true)
			pointer_sent_to = center
			last_pointer_attempt = now
			stable_frames = 0
		await process_frame
		rect = button.get_global_rect()
		var mouse: Vector2 = button.get_global_mouse_position()
		var hover_owner: Control = host.get_viewport().gui_get_hovered_control()
		var layout_stable: bool = rect.position.is_equal_approx(previous_rect.position) and rect.size.is_equal_approx(previous_rect.size)
		var actual_hover: bool = hover_owner != null and (hover_owner == button or button.is_ancestor_of(hover_owner)) and pointer_sent_to.is_equal_approx(rect.get_center())
		if DisplayServer.get_name() != "headless":
			actual_hover = actual_hover and rect.has_point(mouse) and mouse.distance_to(rect.get_center()) <= 1.5 and host.ui.ui_input_blocked()
		var native_focus_ok: bool = DisplayServer.get_name() == "headless" or root.has_focus()
		if layout_stable and actual_hover and native_focus_ok and button.is_visible_in_tree() and not button.disabled and viewport_rect().encloses(rect):
			stable_frames += 1
		else:
			stable_frames = 0
		previous_rect = rect
		if stable_frames >= 2:
			ready = true
			break
	return {"ready": ready, "elapsed_ms": Time.get_ticks_msec() - started, "stable_frames": stable_frames, "state": gui_input_snapshot(button)}

func actual_click(button: Button) -> Dictionary:
	# Control rectangles already use local viewport coordinates. Explicit true
	# prevents push_input from applying the 200% window transform a second time.
	# Real GUI dispatch and native OS hover/focus guards remain enabled.
	# Capture each routing boundary without modifying Main input state. Main's
	# callbacks are manually stepped in this fixture, so a pre-existing queued
	# world pick must be distinguishable from one introduced by this GUI click.
	var trace: Dictionary = {"button": str(button.get_path()), "text": button.text, "before_warp": gui_input_snapshot(button)}
	var pressed: Dictionary = {"count": 0}
	var observe_pressed: Callable = func(): pressed["count"] = int(pressed["count"]) + 1
	button.pressed.connect(observe_pressed)
	trace["target_wait"] = await wait_click_target(button)
	if not check(bool(trace.target_wait.ready), "actual GUI pointer, focus and button layout settle before click " + button.text):
		trace["settled"] = gui_input_snapshot(button)
		trace["pressed_count"] = pressed["count"]
		button.pressed.disconnect(observe_pressed)
		print("HUD_LAYOUT_V9_GUI_TARGET_TIMEOUT " + JSON.stringify(trace))
		return trace
	trace["before_down"] = gui_input_snapshot(button)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true
	down.position = button.get_global_rect().get_center(); down.global_position = down.position
	trace["event_position"] = str(down.position)
	host.get_viewport().push_input(down, true)
	trace["after_down"] = gui_input_snapshot(button)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false
	up.position = down.position; up.global_position = down.position
	host.get_viewport().push_input(up, true)
	trace["after_up"] = gui_input_snapshot(button)
	await frames(3)
	trace["settled"] = gui_input_snapshot(button)
	trace["pressed_count"] = pressed["count"]
	if button.pressed.is_connected(observe_pressed): button.pressed.disconnect(observe_pressed)
	return trace

func native_focus() -> bool:
	if DisplayServer.get_name() == "headless": return true
	root.grab_focus()
	await pointer_to(host.ui.root.size * 0.5)
	if not root.has_focus():
		print("HUD_LAYOUT_V9_NATIVE_FOCUS_REQUIRED raise the game window within 30 seconds")
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
	return check(root.has_focus(), "native HUD input uses actual focused game window")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4); await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/hud-layout-v9/native")
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "native HUD capture " + label)
	captures += 1

func install_module(ship: D.ShipStateDto, fit: Dictionary) -> void:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var slot := inventory.call("slot", ship, str(fit.slot_type), int(fit.slot_index)) as D.ContainerStateDto
	var ids: Array = inventory.call("grant", slot.container_id, str(fit.module_id), 1)
	var equipment := D.EquipmentStateDto.new()
	equipment.slot_container_id = slot.container_id; equipment.item_instance_id = str(ids[0])
	equipment.module_def_id = str(fit.module_id); equipment.enabled = true
	host.state.add("equipment_state", equipment)

func place(point: Vector3) -> void:
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, point)
	host.world.flight.velocity = Vector3.ZERO; host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated(); host.world.flight.reset_physics_interpolation()
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.camera.step(0.0)

func activate_ship(ship: D.ShipStateDto) -> bool:
	# Explicit ship/placement precondition. Empty formal slots are valid without
	# installing an over-budget fictional full fit on the smaller hulls.
	host.state.player().controlled_ship_id = ship.ship_instance_id
	host.state.player().has_docked_station_id = false; host.state.player().docked_station_id = ""
	ship.status = T.ShipStatus.FLYING; ship.has_station_id = false; ship.station_id = ""
	if not check(host._stage_candidate(host.state, host.store.catalog), "actual Main stages formal HUD hull " + ship.ship_def_id): return false
	host._activate(host.state)
	host.ui.show_page(""); host._sync_presentation_stage(); host._sync_mouse_mode()
	var target: Node3D = host.world.targets[mine_id].node
	var mining_range: float = float(host.store.catalog.one("module_defs", "module_id", "module_industry_sift_i").range_m)
	place(target.global_position + Vector3.UP * mining_range * 0.75)
	host.ui._select_target(mine_id); host.ui.tick(1.0)
	await frames(4)
	return true

func _run() -> void:
	old_hz = Engine.physics_ticks_per_second; old_fps = Engine.max_fps
	Engine.max_fps = 144
	root.size = Vector2i(1440, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_size = root.size
	host = Main.new()
	host.progress_database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/hud-layout-v9-%d.db" % Time.get_ticks_usec())
	root.add_child(host); host.set_process(false); host.set_physics_process(false)
	await frames()
	if not check(host.services_ready, "actual Main starts isolated HUD SQLite services"): await finish(); return
	await host._command("new_world", "航行 HUD 布局独立验收", 1, "")
	if not check(host.state != null, "HUD regression creates a real fresh world"): await finish(); return
	Engine.physics_ticks_per_second = int(host.store.catalog.rule("simulation_hz")); step_s = 1.0 / float(Engine.physics_ticks_per_second)
	host.gameplay.call("grant_unlock", str(host.store.catalog.one("resource_node_locations", "node_id", mine_id).required_unlock_id))
	var inventory: RefCounted = host.gameplay.get("inventory")
	for definition: Dictionary in host.store.catalog.rows("ship_defs"):
		var ship := inventory.call("create_ship", str(definition.ship_id), "station_echo_depot") as D.ShipStateDto
		fleet.append(ship)
		if ship.ship_def_id == "miner_anvil":
			miner_id = ship.ship_instance_id
			for fit: Dictionary in host.store.catalog.rows("ship_loadout_items"):
				if str(fit.loadout_id) == "loadout_miner_anvil": install_module(ship, fit)
	var miner := host.state.find("ship_state", "ship_instance_id", miner_id) as D.ShipStateDto
	if not await activate_ship(miner): await finish(); return
	if not await native_focus(): await finish(); return
	await step()
	await actual_waiting_checks()
	await toolbar_input_checks()
	await equipment_slot_checks()
	await information_channels_checks()
	await finish()

func layout_cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]: result.append({"size": size, "scale": scale})
	if OS.get_environment("XJ_HUD_V9_WIDE") == "1": result.append({"size": Vector2i(1920, 1080), "scale": 1.0})
	return result

func resize_case(layout: Dictionary) -> void:
	var window_size: Vector2i = layout["size"]
	root.size = window_size; root.content_scale_size = Vector2i(Vector2(window_size) / float(layout.scale))
	await frames(4)
	host.ui.tick(1.0); await frames(4)
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await frames(2)

func case_name(layout: Dictionary) -> String:
	var window_size: Vector2i = layout["size"]
	return "%dx%d-%d" % [window_size.x, window_size.y, int(float(layout.scale) * 100)]

func active_mining_heads() -> int:
	var count: int = 0
	for equipment: D.EquipmentStateDto in host.gameplay.call("equipped", host.state.ship()):
		if equipment.cycle_paid and equipment.active_remaining_s > 0.0 and not host.store.catalog.one("mining_defs", "module_id", equipment.module_def_id).is_empty(): count += 1
	return count

func waiting_geometry(label: String) -> void:
	var ui: XJUI = host.ui
	var bar: PanelContainer = ui.operation_bar
	var toolbar: Control = ui.get("top_toolbar_frame") as Control
	var dock: Control = ui.get("flight_dock") as Control
	var left: Control = ui.hud_left.get_parent()
	var separate: bool = true
	for other: Control in [ui.navigation_frame, left, ui.overview, ui.instrument, ui.equipment_bar, ui.navigation]:
		separate = separate and not bar.get_global_rect().intersects(other.get_global_rect())
	if toolbar != null: separate = separate and not bar.get_global_rect().intersects(toolbar.get_global_rect())
	var ship_center := Rect2(ui.root.size * 0.5 - Vector2(36, 28), Vector2(72, 56))
	check(bar.is_visible_in_tree() and viewport_rect().encloses(bar.get_global_rect()) and separate and not bar.get_global_rect().intersects(ship_center), "actual saving notice owns a visible region clear of side HUD, toolbar and central hull " + label)
	check(bar.size.x < ui.root.size.x * 0.75 and glyphs_fit(ui.operation_label, bar) and ui.operation_label.tooltip_text == ui.operation_message, "bounded saving notice retains actual wrapped text and full message without filling the screen " + label)
	check(ui.operation_cancel.is_visible_in_tree() and not ui.operation_cancel.disabled and button_glyphs_fit(ui.operation_cancel) and bar.get_global_rect().encloses(ui.operation_cancel.get_global_rect()), "actual save-wait cancel remains readable and reachable " + label)
	check(not ui.toast.is_visible_in_tree() or ui.toast.text.is_empty() or not ui.toast.text.contains(ui.operation_message), "saving wait has no visible duplicate yellow toast " + label)
	check(dock != null and viewport_rect().encloses(dock.get_global_rect()) and ui.instrument.get_parent() == ui.equipment_bar.get_parent() and not ui.instrument.get_global_rect().intersects(ui.equipment_bar.get_global_rect()) and absf(ui.instrument.get_global_rect().position.y - ui.equipment_bar.get_global_rect().position.y) < minf(ui.instrument.size.y, ui.equipment_bar.size.y) * 0.5, "status and equipment share one horizontal bottom row inside the viewport " + label)
	check(viewport_rect().encloses(ui.instrument.get_global_rect()) and viewport_rect().encloses(ui.equipment_bar.get_global_rect()) and not dock.get_global_rect().intersects(ship_center), "bottom dock stays within the screen and preserves the central hull " + label)
	for entry: Dictionary in ui.condition_bars:
		check(glyphs_fit(entry.label, ui.instrument, entry.label.autowrap_mode != TextServer.AUTOWRAP_OFF), "real ship condition text fits the status panel " + str(entry.label.text) + " " + label)
	check(glyphs_fit(ui.energy_label, ui.instrument, ui.energy_label.autowrap_mode != TextServer.AUTOWRAP_OFF) and glyphs_fit(ui.heat_label, ui.instrument, ui.heat_label.autowrap_mode != TextServer.AUTOWRAP_OFF), "actual energy and heat readouts have visible non-overflowing text " + label)
	var overview: XJOverviewPanel = ui.overview
	var mine_button: Button = overview.target_buttons[mine_id]
	var compact: bool = ui.root.size.x < 950.0
	if not compact:
		overview.body_scroll.scroll_vertical = 0; await frames()
		check(viewport_rect().encloses(overview.target_scroll.get_global_rect()) and viewport_rect().encloses(overview.selection_card.get_global_rect()), "normal-width list and selected card share the actual visible side panel " + label)
	# Small logical screens intentionally expose the two sidebar regions through
	# body scrolling. Each control must be physically reachable inside the real
	# scroll viewport; merely being visible_in_tree is insufficient.
	overview.body_scroll.ensure_control_visible(overview.resource_label); await frames()
	check(overview.resource_detail.is_visible_in_tree() and glyphs_fit(overview.resource_label, overview.selection_card) and overview.body_scroll.get_global_rect().encloses(overview.resource_label.get_global_rect()), "actual body scrolling exposes the selected mineral's real text bounds " + label)
	await capture("selected-resource-" + label)
	overview.body_scroll.ensure_control_visible(overview.interaction_label); await frames()
	check(glyphs_fit(overview.interaction_label, overview.selection_card) and overview.body_scroll.get_global_rect().encloses(overview.interaction_label.get_global_rect()), "actual body scrolling exposes the selected interaction reason's real text bounds " + label)
	var actions_readable: bool = true
	for action: Button in overview.action_buttons.values():
		if not action.is_visible_in_tree(): continue
		overview.body_scroll.ensure_control_visible(action); await frames(2)
		actions_readable = actions_readable and button_glyphs_fit(action) and overview.selection_card.get_global_rect().encloses(action.get_global_rect()) and overview.body_scroll.get_global_rect().encloses(action.get_global_rect())
	check(actions_readable, "actual body scrolling reaches every readable selected-target action button " + label)
	overview.target_scroll.ensure_control_visible(mine_button); await frames()
	overview.body_scroll.ensure_control_visible(mine_button); await frames()
	check(overview.target_scroll.is_visible_in_tree() and overview.target_scroll.size.y >= mine_button.size.y and viewport_rect().encloses(mine_button.get_global_rect()) and overview.target_scroll.get_global_rect().encloses(mine_button.get_global_rect()) and overview.body_scroll.get_global_rect().encloses(mine_button.get_global_rect()), "actual nested scrolling exposes an entire selected target row " + label)
	var resource_readout: Label = mine_button.get_node("ResourceState")
	var name_readout: Label = mine_button.get_child(0).get_node("Name")
	check(glyphs_fit(resource_readout, mine_button, false) and glyphs_fit(name_readout, mine_button) and not resource_readout.get_global_rect().intersects(name_readout.get_global_rect()) and mine_button.tooltip_text.contains(host.ui.overview.resource_label.text), "actual mineral target row separates its name and resource text while retaining full resource tooltip " + label)
	var last_id: String = str(overview.filtered_ids[-1])
	var last_button: Button = overview.target_buttons[last_id]
	overview.target_scroll.ensure_control_visible(last_button); await frames()
	overview.body_scroll.ensure_control_visible(last_button); await frames()
	check(viewport_rect().encloses(last_button.get_global_rect()) and overview.target_scroll.get_global_rect().encloses(last_button.get_global_rect()) and overview.body_scroll.get_global_rect().encloses(last_button.get_global_rect()), "actual nested target scrolling reaches the final overview row " + label)
	var buttons_readable: bool = true
	for button: Button in descendant_buttons(ui.navigation): buttons_readable = buttons_readable and button_glyphs_fit(button)
	check(toolbar != null and toolbar.is_visible_in_tree() and viewport_rect().encloses(toolbar.get_global_rect()) and ui.navigation.get_global_rect().position.y < ui.root.size.y * 0.25 and buttons_readable, "top menu owns readable reachable controls inside its dedicated region " + label)

func actual_waiting_checks() -> void:
	host._command("start_mining", mine_id, 1, "")
	await step()
	if not check(active_mining_heads() > 0 and not host.gameplay.call("save_eligible"), "real Main has paid mining cycles before requesting a deferred save"): return
	var cycles: Dictionary = host.gameplay.get("work").mining_cycles.duplicate(true)
	var stock: int = (host.state.find("resource_state", "node_id", mine_id) as D.ResourceStateDto).remaining_units
	var normal_height: float = 0.0
	for layout: Dictionary in layout_cases():
		await resize_case(layout)
		host._request_save("manual", 0)
		await frames(4); host.ui.tick(0.3)
		check(not host.deferred_save.is_empty() and not host.busy and host.ui.operation_kind == "save" and host.ui.operation_waiting and host.gameplay.get("work").mining_cycles == cycles, "actual requested save waits without altering the live paid mining cycles " + case_name(layout))
		await waiting_geometry(case_name(layout))
		# Deliberate presentation duplicate: producers may repeat the same copy,
		# but the overlay must still expose one operation message to the player.
		host.ui.notify(host.ui.operation_message); await frames()
		check(not host.ui.toast.is_visible_in_tree(), "exact operation duplicate is suppressed as a second yellow notification " + case_name(layout))
		host.ui.notify("资源情报已更新。"); await frames()
		var toast_face: Font = host.ui.toast.get_theme_font("font")
		var toast_font: int = host.ui.toast.get_theme_font_size("font_size")
		var toast_lines: int = mini(maxi(1, host.ui.toast.get_line_count()), host.ui.toast.max_lines_visible)
		var toast_glyphs := Rect2(host.ui.toast.get_global_rect().position, Vector2(host.ui.toast.size.x, toast_face.get_height(toast_font) * toast_lines))
		var center := Rect2(host.ui.root.size * 0.5 - Vector2(36, 28), Vector2(72, 56))
		check(host.ui.toast.is_visible_in_tree() and glyphs_fit(host.ui.toast, host.ui.root) and not toast_glyphs.intersects(host.ui.operation_bar.get_global_rect()) and not toast_glyphs.intersects(host.ui.overview.get_global_rect()) and not toast_glyphs.intersects(host.ui.navigation_frame.get_global_rect()) and not toast_glyphs.intersects(center), "different global feedback retains independent readable space while save waiting remains active " + case_name(layout))
		if float(layout.scale) == 1.0 and layout["size"].y == 900: normal_height = host.ui.overview.target_scroll.size.y
		if float(layout.scale) == 1.0 and layout["size"].y == 720: check(normal_height > host.ui.overview.target_scroll.size.y and normal_height > 154.0, "overview target list uses additional available screen height instead of a fixed legacy 154px list")
		await capture("waiting-" + case_name(layout))
		# Long presentation-only copy exercises wrapping and full tooltip. The
		# real pending save stays intact, so its actual cancel button remains live.
		var long_message: String = "等待设备周期结束后保存；原存档保留。".repeat(14)
		host.ui.set_operation_status("save", long_message, true); await frames(4)
		check(host.ui.operation_label.text == long_message and host.ui.operation_label.tooltip_text == long_message and glyphs_fit(host.ui.operation_label, host.ui.operation_bar) and host.ui.operation_bar.size.x < host.ui.root.size.x * 0.75, "long save-wait copy wraps in its bounded notice while retaining full tooltip " + case_name(layout))
		await capture("long-waiting-" + case_name(layout))
		var cancel_trace: Dictionary = await actual_click(host.ui.operation_cancel)
		print("HUD_LAYOUT_V9_CANCEL_INPUT " + JSON.stringify({"layout": case_name(layout), "trace": cancel_trace}))
		check(host.deferred_save.is_empty() and host.ui.operation_kind == "idle" and not host.ui.operation_bar.is_visible_in_tree() and host.gameplay.get("work").mining_target == mine_id and host.gameplay.get("work").mining_cycles == cycles and (host.state.find("resource_state", "node_id", mine_id) as D.ResourceStateDto).remaining_units == stock, "actual GUI cancel abandons only the waiting save and preserves the ongoing mining operation " + case_name(layout))
	host._command("stop_mining", "", 1, "")
	check(host.gameplay.get("work").mining_target.is_empty() and host.gameplay.call("save_eligible"), "actual work stop reaches the stable boundary after HUD cancellation checks")

func toolbar_input_checks() -> void:
	for layout: Dictionary in layout_cases():
		await resize_case(layout); host.ui.show_page(""); host.ui.tick(1.0); await frames()
		for entry: Dictionary in [{"prefix": "任务", "page": "missions"}, {"prefix": "星图", "page": "map"}, {"prefix": "系统", "page": "pause"}]:
			var button: Button = toolbar_button(str(entry.prefix))
			if not check(button != null, "actual toolbar exposes " + str(entry.prefix)): continue
			var click_trace: Dictionary = await actual_click(button)
			var verdict: Dictionary = {"page_ok": host.ui.page == str(entry.page), "keyboard_blocked": host.ui.keyboard_blocked(), "drag_clear": not host.pointer_drag_pressed, "pick_clear": not host.pointer_pick_pending}
			if not check(bool(verdict.page_ok) and bool(verdict.keyboard_blocked) and bool(verdict.drag_clear) and bool(verdict.pick_clear), "real toolbar GUI click opens the intended screen and consumes ship pointer control " + str(entry.page) + " " + case_name(layout)):
				print("HUD_LAYOUT_V9_TOOLBAR_INPUT_FAILURE " + JSON.stringify({"layout": case_name(layout), "expected_page": str(entry.page), "verdict": verdict, "trace": click_trace, "main_process_enabled": host.is_processing(), "main_physics_enabled": host.is_physics_processing()}))
			var point: Vector3 = host.world.flight.global_position
			Input.action_press("forward"); Input.action_press("fire")
			var fire := InputEventAction.new(); fire.action = "fire"; fire.pressed = true; host._unhandled_input(fire)
			await step(); Input.action_release("forward"); Input.action_release("fire")
			check(host.world.flight.global_position.is_equal_approx(point) and not host.fire_held and host.world.projectiles.active.is_empty(), "menu keyboard guard prevents thrust and firing from held keys " + str(entry.page) + " " + case_name(layout))
			host.ui.show_page(""); await frames(); host.ui.tick(1.0)
		var show_ship: Button = toolbar_button("显示舰船")
		if show_ship != null:
			var speed: Vector3 = host.world.flight.velocity
			await actual_click(show_ship)
			check(host.camera.mode == T.CameraMode.FOLLOW and host.ui.page.is_empty() and host.world.flight.velocity == speed and not host.pointer_drag_pressed and not host.pointer_pick_pending, "real top-menu show-ship action preserves flight velocity and does not start a world drag " + case_name(layout))
			var pose: Transform3D = host.world.flight.global_transform
			var heading: Vector3 = host.camera.control_forward()
			var motion := InputEventMouseMotion.new()
			motion.position = show_ship.get_global_rect().get_center(); motion.relative = Vector2(90, 40)
			host.get_viewport().push_input(motion, true); await frames()
			check(host.world.flight.global_transform.is_equal_approx(pose) and host.camera.control_forward().is_equal_approx(heading) and not host.pointer_drag_pressed and not host.fire_held, "actual pointer movement over a toolbar control leaves ship and camera heading unchanged " + case_name(layout))

func equipment_slot_checks() -> void:
	for ship: D.ShipStateDto in fleet:
		if not await activate_ship(ship): continue
		var slots: Array[String] = []
		for container: D.ContainerStateDto in host.state.rows("container_state"):
			if container.ship_instance_id == ship.ship_instance_id and container.kind == T.ContainerKind.SLOT: slots.append(container.container_id)
		for layout: Dictionary in layout_cases():
			await resize_case(layout)
			var bar: XJEquipmentBar = host.ui.equipment_bar
			var slot_buttons: Dictionary = bar.get("slot_buttons")
			var slot_records: Array = bar.get("slot_records")
			if not check(slot_records.size() == slots.size() and slot_buttons.size() == slots.size(), "actual equipment strip represents every catalog-backed slot " + ship.ship_def_id + " " + case_name(layout)): continue
			var reachable: bool = true
			var empty_safe: bool = true
			for id: String in slots:
				if not slot_buttons.has(id): reachable = false; continue
				var button: Button = slot_buttons[id]
				bar.scroll.ensure_control_visible(button); await frames(2)
				reachable = reachable and button.is_visible_in_tree() and bar.scroll.get_global_rect().encloses(button.get_global_rect()) and viewport_rect().encloses(button.get_global_rect())
				if host.state.find("equipment_state", "slot_container_id", id) == null: empty_safe = empty_safe and button.disabled
			check(reachable and empty_safe, "all real installed and empty slots are scroll-reachable; empty slots cannot issue a toggle " + ship.ship_def_id + " " + case_name(layout))
			if ship.ship_def_id == "battleship_bastion": await capture("maximum-slots-" + case_name(layout))

func information_channels_checks() -> void:
	var miner := host.state.find("ship_state", "ship_instance_id", miner_id) as D.ShipStateDto
	if not await activate_ship(miner): return
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size; await frames()
	host.ui.notify("资源权限状态已更新。"); host.ui.set_operation_status("local_navigation", "本地接近展示夹具")
	check(not host.ui.operation_bar.is_visible_in_tree() and host.ui.toast.text == "资源权限状态已更新。", "local navigation display input does not replace a global completion notice with an operation overlay")
	host.ui.set_operation_status("travel", "虫洞传送准备中", true); await frames()
	check(host.ui.operation_bar.is_visible_in_tree() and host.ui.operation_label.text == "虫洞传送准备中" and not host.ui.operation_cancel.is_visible_in_tree(), "synthetic travel status owns its distinct operation display and never offers save-wait cancellation")
	host.ui.set_operation_status("save", "正在保存航行进度", false); await frames()
	check(host.ui.operation_bar.is_visible_in_tree() and not host.ui.operation_cancel.is_visible_in_tree() and glyphs_fit(host.ui.operation_label, host.ui.operation_bar), "synthetic committing-save status keeps a readable display without a cancellable wait")
	host.ui.set_operation_status("idle", ""); host.ui.notify("资源权限状态已更新。"); await frames()
	check(not host.ui.operation_bar.is_visible_in_tree() and host.ui.toast.text == "资源权限状态已更新。" and host.ui.toast.is_visible_in_tree(), "global completion notice survives independently after operation overlay is cleared")

func finish() -> void:
	for action: StringName in InputMap.get_actions(): Input.action_release(action)
	if is_instance_valid(host): host.queue_free()
	host = null; await frames(2); await create_timer(0.25).timeout
	Engine.physics_ticks_per_second = old_hz; Engine.max_fps = old_fps
	print("HUD_LAYOUT_V9_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
