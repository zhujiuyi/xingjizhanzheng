extends Node
## Source-only presentation audit. Every database is fresh and test-owned.
## Credit, unlocks and local inventory are declared UI fixtures, not progression.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
const AuditTheme = preload("res://runtime/ui_theme.gd")
const PAGES: Array[String] = ["title", "station", "ships", "warehouse", "fitting", "market", "industry", "missions", "research", "civilizations", "map", "pause", "settings", "hire", "frontier", "trials", "blockades", "projects", "expeditions", "reports", "consignments", "fitting_analysis", "ship_roles", "operations", "drones", "exploration", "sources"]
var host: Node
var directory: String
var label: String
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var findings: Array[Dictionary] = []
var captures: int = 0
var finishing: bool = false
var role_samples: Dictionary = {}
var owned_ship_id: String = ""
var auxiliary_items: Dictionary = {}
var paid_fixture: Array[String] = []
var interaction_checks: int = 0
var caption_samples: Dictionary = {"drone_recall": 0, "research": 0, "growth_action": 0}
var root: Window:
	get:return get_tree().root
var process_frame: Signal:
	get:return get_tree().process_frame

func create_timer(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(seconds)

func quit(exit_code: int=0) -> void:
	get_tree().quit(exit_code)

func _ready() -> void:
	_initialize()
var boundary_observations: Array[Dictionary] = []

func label_fits(readout: Label) -> bool:
	var font: Font = readout.get_theme_font("font")
	var size: int = readout.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(readout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	return readout.is_visible_in_tree() and Rect2(Vector2.ZERO, host.ui.root.size).grow(1.0).encloses(readout.get_global_rect()) and text_size.x <= readout.size.x + 1.0 and font.get_height(size) <= readout.size.y + 1.0

func caption_fits(button: Button) -> bool:
	var style: StyleBox = button.get_theme_stylebox("normal")
	var width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	var icon_width: float = button.icon.get_width() + button.get_theme_constant("h_separation") if button.icon != null and not button.text.is_empty() else 0.0
	return button.autowrap_mode == TextServer.AUTOWRAP_OFF and not button.text.contains("\n") and width + icon_width + style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT) <= button.size.x + 1.0

func flat_geometry(style: StyleBox) -> bool:
	if not style is StyleBoxFlat: return false
	return style.corner_radius_top_left == 0 and style.corner_radius_top_right == 0 and style.corner_radius_bottom_left == 0 and style.corner_radius_bottom_right == 0 and style.shadow_size == 0

func colors_for(button: Button) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_disabled_color"]:
		result[key] = button.get_theme_color(key).to_html(true)
	return result

func structural_assertions(ui: Node, name: String) -> void:
	var buttons: int = 0
	var button_geometry: bool = true
	var button_states: bool = true
	var scrollbar_geometry: bool = true
	var checks_geometry: bool = true
	var captions: Dictionary = {}
	for node: Node in descendants(ui.root):
		if not node is Control or not node.is_visible_in_tree(): continue
		var control: Control = node
		if node is Button:
			buttons += 1
			for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]: button_geometry = button_geometry and flat_geometry(node.get_theme_stylebox(state))
			var normal: Dictionary = style_data(node.get_theme_stylebox("normal"))
			var hover: Dictionary = style_data(node.get_theme_stylebox("hover"))
			var pressed: Dictionary = style_data(node.get_theme_stylebox("pressed"))
			var disabled: Dictionary = style_data(node.get_theme_stylebox("disabled"))
			button_states = button_states and normal != hover and hover != pressed and normal != disabled
			var role: String = str(node.get_meta("ui_role", "default"))
			if role in ["primary", "secondary", "danger"] and not role_samples.has(role): role_samples[role] = {"style": normal, "font": node.get_theme_color("font_color").to_html(true), "page": name}
			var category: String = "drone_recall" if str(node.name) == "DroneOrder_recall" else "growth_action" if str(node.name).begins_with("Growth_growth_") else "research" if node.text.contains("研究") else ""
			if not category.is_empty():
				caption_samples[category] = int(caption_samples[category]) + 1
				captions[category] = bool(captions.get(category, true)) and caption_fits(node)
		if node is CheckBox or node is CheckButton:
			for icon: String in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
				var image: Texture2D = control.get_theme_icon(icon)
				checks_geometry = checks_geometry and image != null and image.get_size() == Vector2(16, 16)
			checks_geometry = checks_geometry and control.get_theme_icon("checked") != control.get_theme_icon("unchecked") and control.get_theme_icon("checked_disabled") != control.get_theme_icon("checked")
		if node is HScrollBar or node is VScrollBar:
			for state: String in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]: scrollbar_geometry = scrollbar_geometry and flat_geometry(control.get_theme_stylebox(state))
	if buttons > 0:
		check(button_geometry, "all rendered button state surfaces are flat square and shadow-free " + name)
		check(button_states, "rendered controls distinguish normal hover press and disabled states " + name)
	check(scrollbar_geometry and checks_geometry, "rendered scrollbars and checkbox glyphs use shared geometry " + name)
	for category: String in captions: check(bool(captions[category]), "actual " + category + " captions fit natural single-line text including style insets " + name)
	if ui.page == "fitting_analysis":
		var distance_label: Label = ui.body.find_child("FittingDistanceLabel", true, false)
		var distance_input: Control = ui.body.find_child("FittingDistance", true, false)
		if distance_label != null and distance_label.is_visible_in_tree() and distance_input != null:
			var gap: float = distance_input.get_global_rect().position.x - distance_label.get_global_rect().end.x
			check(gap >= -1.0 and gap <= 16.0 and absf(distance_input.get_global_rect().get_center().y - distance_label.get_global_rect().get_center().y) <= 1.0, "real fitting distance label and input stay together within 16px " + name)
		var grid: GridContainer = ui.body.find_child("FittingKeyValues", true, false)
		var aligned: bool = grid != null and grid.get_child_count() >= 4
		if grid != null:
			var columns: Array[Rect2] = []
			for column: int in range(grid.columns): columns.append((grid.get_child(column) as Control).get_global_rect())
			for index: int in range(grid.get_child_count()):
				var cell: Label = grid.get_child(index) as Label
				var column: int = index % grid.columns
				var rect: Rect2 = cell.get_global_rect()
				aligned = aligned and absf(rect.position.x - columns[column].position.x) <= 1.0 and absf(rect.size.x - columns[column].size.x) <= 1.0
				aligned = aligned and cell.horizontal_alignment == (HORIZONTAL_ALIGNMENT_LEFT if column == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		check(aligned, "actual fitting key-value columns align names left and numbers right " + name)
	if ui.page == "research":
		var quantity_label: Label = ui.body.find_child("SpecializationQuantityLabel", true, false) as Label
		var quantity: SpinBox = ui.body.find_child("SpecializationQuantity", true, false) as SpinBox
		if quantity_label != null and quantity_label.is_visible_in_tree() and quantity != null:
			var font: Font = quantity_label.get_theme_font("font")
			var font_size: int = quantity_label.get_theme_font_size("font_size")
			var text_width: float = font.get_string_size(quantity_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			check(quantity_label.autowrap_mode == TextServer.AUTOWRAP_OFF and quantity_label.get_line_count() == 1 and quantity_label.size.x + 1.0 >= text_width and quantity_label.size.y <= font.get_height(font_size) + 2.0, "actual specialization quantity caption stays a complete single line " + name)
			var label_rect: Rect2 = quantity_label.get_global_rect()
			var editor_rect: Rect2 = quantity.get_global_rect()
			var gap: float = editor_rect.position.x - label_rect.end.x
			check(gap >= 0.0 and gap <= 16.0 and absf(label_rect.get_center().y - editor_rect.get_center().y) <= 1.0, "actual specialization caption and editor remain a compact horizontal pair " + name)
			check(quantity.size.y >= 30.0 and quantity.size.y <= maxf(48.0, quantity.get_combined_minimum_size().y + 1.0) and quantity.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "actual specialization editor does not stretch with flow line height " + name)
	for node: Node in descendants(ui.body):
		if node is HFlowContainer and node.name == "InfoFacts" and node.is_visible_in_tree():
			for child: Node in node.get_children():
				if not child is Label or not child.is_visible_in_tree(): continue
				var fact: Label = child as Label
				var font: Font = fact.get_theme_font("font")
				var text_width: float = font.get_string_size(fact.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fact.get_theme_font_size("font_size")).x
				check(fact.size.x + 1.0 >= fact.custom_minimum_size.x, "visible information fact retains its intended readable minimum width " + name + " " + fact.text)
				if not fact.text.contains("\n") and text_width + 2.0 <= fact.custom_minimum_size.x + 0.5:
					check(fact.get_line_count() == 1, "short information fact stays on one actual rendered line " + name + " " + fact.text)
		if node.has_meta("info_list"):
			var current_rows: Array = node.get("rows")
			# A stage list sends the selected item's detail to its own column, so
			# nothing opens inline there; a workbench list still opens exactly one.
			var external: bool = bool(node.get("details_external"))
			var open_count: int = 0
			var selected_matches: bool = true
			for row: Dictionary in current_rows:
				var current: bool = str(row.id) == str(node.get("selected_id"))
				if row.details.visible: open_count += 1
				selected_matches = selected_matches and row.details.visible == (current and not external) and row.selector.button_pressed == current and bool(row.row.get_meta("details_open", false)) == current and row.actions is HFlowContainer
			check(open_count == (0 if current_rows.is_empty() or external else 1) and selected_matches, "non-trading list exposes exactly the real selected detail and horizontal actions " + name)
			if external:
				check(is_instance_valid(ui.stage_detail) and ui.stage_detail.is_visible_in_tree() and ui.stage_detail.get_child_count() > 0, "stage list shows the selected item in its detail column " + name)
		if not node.has_meta("business_list"): continue
		var header: HBoxContainer = node.get("header")
		var aligned: bool = header != null
		var rows: Array = node.get("rows")
		for row: Dictionary in rows:
			var columns: HBoxContainer = row.row.find_child("BusinessColumns", true, false)
			if columns == null or columns.get_child_count() != header.get_child_count(): aligned = false; continue
			for index: int in range(header.get_child_count()):
				var header_cell: Control = header.get_child(index)
				var row_cell: Control = columns.get_child(index)
				aligned = aligned and header_cell.visible == row_cell.visible
				if not header_cell.visible: continue
				var expected: Rect2 = (header.get_child(index) as Control).get_global_rect()
				var actual: Rect2 = (columns.get_child(index) as Control).get_global_rect()
				aligned = aligned and absf(expected.position.x - actual.position.x) <= 1.0 and absf(expected.size.x - actual.size.x) <= 1.0
		check(aligned, "actual business header and all rendered row columns align " + name)
	if ui.page.is_empty():
		check(host.presentation_stage == "flight" and not host.hangar.is_visible_in_tree() and host.world.is_visible_in_tree() and root.get_camera_3d() == host.camera.camera and host.world.flight.record.ship_instance_id == host.state.ship().ship_instance_id, "actual flight presentation uses space world paid hull and production flight camera " + name)
		var overview: Node = ui.overview
		var aligned: bool = true
		var measured: int = 0
		for button: Button in overview.target_buttons.values():
			if not button.is_visible_in_tree(): continue
			var row: Node = button.get_child(0)
			for pair: Array in [["distance", "DistanceCell"], ["name", "Name"], ["type", "Type"]]:
				var heading: Rect2 = (overview.sort_buttons[pair[0]] as Control).get_global_rect()
				var cell: Rect2 = (row.get_node(pair[1]) as Control).get_global_rect()
				aligned = aligned and absf(heading.position.x - cell.position.x) <= 1.0 and absf(heading.size.x - cell.size.x) <= 1.0
			measured += 1
		check(aligned and measured > 0, "actual overview headers align all three contact columns " + name)

func settle_writer(message: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "real fixture transaction closes " + message)
	await frames(4)

## The flight dock must survive a full battleship loadout. The largest hull fits 17
## modules; at the old fixed 80 px tile that was 1424 px of tiles inside a 656 px
## dock, which put a horizontal scroll bar into the flight HUD. Checking only the
## test fixture would never reach that case, so compare the live tile width against
## the worst slot count in the catalog.
func _check_equipment_row_fit(name: String) -> void:
	var bar: Control = host.ui.equipment_bar
	if not is_instance_valid(bar): return
	var row: HFlowContainer = bar.find_child("EquipmentRow", true, false) as HFlowContainer
	if row == null or row.get_child_count() == 0:
		check(false, "flight dock exposes the equipment row " + name)
		return
	var unit: float = 0.0
	var tile_height: float = 0.0
	var visible_tiles: int = 0
	for child: Node in row.get_children():
		var tile: Control = child as Control
		if tile == null or not tile.is_visible_in_tree(): continue
		visible_tiles += 1
		tile_height = maxf(tile_height, tile.get_combined_minimum_size().y)
		if str(tile.name).begins_with("Module_"): unit = maxf(unit, tile.get_combined_minimum_size().x)
	var has_installed_tile: bool = unit > 0.0
	if unit <= 0.0:
		# No module fitted: fall back to the widest tile the row currently shows.
		for child: Node in row.get_children():
			var tile: Control = child as Control
			if tile != null and tile.is_visible_in_tree(): unit = maxf(unit, tile.get_combined_minimum_size().x)
	if unit <= 0.0 or tile_height <= 0.0: return
	var gap: float = float(row.get_theme_constant("h_separation"))
	var totals: Dictionary = {}
	for definition: Dictionary in host.store.catalog.rows("ship_slot_defs"):
		var ship_id: String = str(definition.get("ship_id", ""))
		totals[ship_id] = int(totals.get(ship_id, 0)) + 1
	var worst_slots: int = 0
	for ship_id: String in totals: worst_slots = maxi(worst_slots, int(totals[ship_id]))
	check(worst_slots >= visible_tiles, "catalog reports at least as many slots as the fixture shows " + name)
	# The row is a flow, so wrapping keeps its width demand at one tile. What must
	# still fit is the wrapped height, for the fixture and for the largest hull.
	check(row.get_combined_minimum_size().x <= row.size.x + 1.0, "equipment row columns fit the dock width (%.0f px in %.0f px) " % [row.get_combined_minimum_size().x, row.size.x] + name)
	var per_line: float = floor((row.size.x + gap) / (unit + gap))
	if per_line < 1.0:
		check(false, "equipment dock is narrower than a single tile (%.0f px tile in %.0f px) " % [unit, row.size.x] + name)
		return
	var loadouts: Array[Dictionary] = [{"label": "current", "slots": visible_tiles}]
	if has_installed_tile: loadouts.append({"label": "largest hull", "slots": worst_slots})
	# A summary saying "empty slots x13" is one wide aggregate, not the width of
	# thirteen installed modules. v64 renders the full largest loadout at all four
	# sizes; this current-footprint check must not manufacture seventeen summaries.
	for case: Dictionary in loadouts:
		var slots: int = int(case.slots)
		var lines: float = ceil(float(slots) / per_line)
		var needed: float = lines * tile_height + maxf(0.0, lines - 1.0) * gap
		check(needed <= row.size.y + 1.0, "equipment row wraps %s loadout %d slots into %.0f line(s) needing %.0f px in %.0f px " % [str(case.label), slots, lines, needed, row.size.y] + name)

func _count_buttons(node: Node) -> int:
	var total: int = 0
	if node is Button: total += 1
	for child: Node in node.get_children(): total += _count_buttons(child)
	return total

func actual_click(button: Button, message: String) -> bool:
	if not check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "actual GUI target available " + message):
		# Say which of the three conditions failed, and where the UI was, instead
		# of leaving a bare FAIL that cannot be diagnosed after the run.
		print("ACTUAL_CLICK_UNAVAILABLE " + JSON.stringify({
			"message": message,
			"page": host.ui.page,
			"exists": is_instance_valid(button),
			"visible_in_tree": button.is_visible_in_tree() if is_instance_valid(button) else null,
			"disabled": button.disabled if is_instance_valid(button) else null,
			"rect": str(button.get_global_rect()) if is_instance_valid(button) else null,
			"button_count": _count_buttons(host.ui.body),
		}))
		return false
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	var deadline: int = Time.get_ticks_msec() + 2000
	var stable: int = 0
	var center := Vector2.ZERO
	while Time.get_ticks_msec() < deadline:
		if DisplayServer.get_name() != "headless" and not root.has_focus(): root.grab_focus()
		center = button.get_global_transform_with_canvas() * (button.size * 0.5)
		host.get_viewport().warp_mouse(center)
		var motion := InputEventMouseMotion.new()
		motion.position = center; motion.global_position = center
		root.push_input(motion, true)
		await frames(1)
		var hover: Control = root.gui_get_hovered_control()
		var clip: Array = clip_info(button, Rect2(Vector2.ZERO, host.ui.root.size)).visible_rect
		var visible_area := Rect2(Vector2(clip[0], clip[1]), Vector2(clip[2], clip[3]))
		var complete: bool = visible_area.grow(1.0).encloses(button.get_global_rect())
		var native_pointer: bool = DisplayServer.get_name() == "headless" or root.has_focus() and button.get_global_rect().has_point(button.get_global_mouse_position())
		stable = stable + 1 if complete and native_pointer and hover != null and (hover == button or button.is_ancestor_of(hover)) else 0
		if stable >= 2: break
	if not check(stable >= 2, "stable actual pointer reaches complete control " + message): return false
	center = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var observed: Dictionary = {"pressed": 0}
	button.pressed.connect(func(): observed.pressed += 1, CONNECT_ONE_SHOT)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center; event.global_position = center; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event, true)
	await frames(4)
	interaction_checks += 1
	return check(int(observed.pressed) == 1, "real viewport GUI dispatch emits one press " + message)

func native_key(code: Key, target: Window = null, reverse: bool = false) -> void:
	for pressed: bool in [true, false]:
		if not is_instance_valid(target): target = root
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = pressed; event.shift_pressed = reverse
		if target is PopupMenu:
			event.window_id = target.get_window_id()
			Input.parse_input_event(event)
		else: target.push_input(event, true)
		await frames(1)
	await frames(3)

func actual_related(destination: String, message: String) -> bool:
	var menu: MenuButton = host.ui.panel.find_child("RelatedNavigation", true, false) as MenuButton
	if not check(menu != null, "contextual related navigation exists " + message): return false
	var popup: PopupMenu = menu.get_popup()
	var wanted: int = -1
	for index: int in range(popup.item_count):
		if str(popup.get_item_metadata(index)) == destination: wanted = index
	if not check(wanted >= 0, "related destination is eligible " + destination): return false
	if not await actual_click(menu, "open related navigation " + message): return false
	if not check(popup.visible, "real native related menu opens " + message): return false
	for step: int in range(popup.item_count + 1):
		if popup.get_focused_item() == wanted: break
		await native_key(KEY_DOWN, popup)
	if not check(popup.get_focused_item() == wanted, "native keyboard reaches exact related destination " + destination): return false
	await native_key(KEY_ENTER, popup)
	return check(host.ui.page == destination, "real menu navigates once to " + destination)

func probe_states(button: Button, message: String) -> void:
	if not check(button != null and not button.disabled, "state probe uses actionable semantic button " + message): return
	var original_page: String = host.ui.page
	var original_state: RefCounted = host.state
	var requests: Dictionary = {"count": 0}
	var request_observer: Callable = func(_action: String, _target: String, _quantity: int, _extra: String): requests.count += 1
	host.ui.requested.connect(request_observer)
	Input.flush_buffered_events()
	button.grab_focus()
	root.grab_focus()
	var center: Vector2 = button.get_global_rect().get_center()
	host.get_viewport().warp_mouse(center)
	var motion := InputEventMouseMotion.new()
	motion.position = center; motion.global_position = center
	root.push_input(motion, true)
	await frames(5)
	var hovered: Control = root.gui_get_hovered_control()
	check(hovered != null and (hovered == button or button.is_ancestor_of(hovered)) and button.has_focus(), "native semantic hover and focus reach actual control " + message)
	var normal: StyleBox = button.get_theme_stylebox("normal")
	var emitted: Dictionary = {"pressed": 0}
	var pressed_observer: Callable = func(): emitted.pressed += 1
	button.pressed.connect(pressed_observer)
	pointer_trace("probe-before-down " + message)
	var down := InputEventMouseButton.new()
	down.position = center; down.global_position = center; down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.window_id = root.get_window_id()
	root.push_input(down, true)
	Input.flush_buffered_events()
	await frames(2)
	check(button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED], "actual held pointer enters pressed draw state " + message)
	# Disable while held, then release. Dangerous/new-world actions never fire.
	button.disabled = true
	# Never mutate the down event already handed to input dispatch. Drain native
	# events with the source still disabled and the pointer outside every button.
	var release := InputEventMouseButton.new()
	release.position = center; release.global_position = center; release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false
	release.button_mask = 0; release.window_id = root.get_window_id()
	root.push_input(release, true)
	Input.flush_buffered_events()
	var safe_point: Vector2 = Vector2(4, 4)
	host.get_viewport().warp_mouse(safe_point)
	var away := InputEventMouseMotion.new()
	away.position = safe_point; away.global_position = safe_point; away.button_mask = 0; away.window_id = root.get_window_id()
	root.push_input(away, true)
	var started: int = Time.get_ticks_msec()
	var stable: int = 0
	while Time.get_ticks_msec() - started < 1500:
		Input.flush_buffered_events()
		await frames(1)
		var hover: Control = root.gui_get_hovered_control()
		var outside: bool = hover == null or (hover != button and not button.is_ancestor_of(hover))
		var released: bool = not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not button.is_pressed() and button.get_draw_mode() == BaseButton.DRAW_DISABLED
		stable = stable + 1 if outside and released else 0
		if stable >= 3 and Time.get_ticks_msec() - started >= 120: break
	check(stable >= 3 and Time.get_ticks_msec() - started >= 120, "disabled probe drains release and leaves its pointer safely within finite deadline " + message)
	pointer_trace("probe-disabled-after-release " + message)
	check(button.get_draw_mode() == BaseButton.DRAW_DISABLED and style_data(normal) != style_data(button.get_theme_stylebox("disabled")) and button.get_theme_color("font_disabled_color") != button.get_theme_color("font_color"), "actual disabled draw state changes plate and foreground " + message)
	button.disabled = false
	root.gui_release_focus()
	Input.flush_buffered_events(); await frames(3)
	check(int(emitted.pressed) == 0 and int(requests.count) == 0 and host.ui.page == original_page and host.state == original_state and not button.is_pressed(), "state probe suppresses every press and business action through release and restoration " + message)
	pointer_trace("probe-restored " + message)
	if button.pressed.is_connected(pressed_observer): button.pressed.disconnect(pressed_observer)
	if host.ui.requested.is_connected(request_observer): host.ui.requested.disconnect(request_observer)
	interaction_checks += 1

func pointer_trace(stage: String) -> void:
	var focus: Control = root.gui_get_focus_owner()
	var hover: Control = root.gui_get_hovered_control()
	print("UI_QUALITY_INPUT_BOUNDARY " + JSON.stringify({"stage": stage, "page": host.ui.page, "busy": host.busy, "left": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "middle": Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE), "right": Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), "focus": str(focus.get_path()) if is_instance_valid(focus) else "", "hover": str(hover.get_path()) if is_instance_valid(hover) else "", "mouse": [root.get_mouse_position().x, root.get_mouse_position().y], "native_focus": root.has_focus()}))

func horizontal_scroll_interaction(suffix: String) -> void:
	var list: Node = host.ui.body.find_child("BusinessList", true, false)
	if not check(list != null, "responsive market has the real business list"): return
	var scroll: ScrollContainer = list.get("horizontal_scroll")
	var bar: HScrollBar = scroll.get_h_scroll_bar()
	check(bar.max_value <= bar.page + 1.0 and scroll.scroll_horizontal == 0, "responsive market keeps its complete operation path without horizontal scrolling")
	var rows: Array = list.get("rows")
	check(not rows.is_empty(), "responsive market has genuine quoted rows")
	for row: Dictionary in rows:
		for key: String in ["unit_price", "total"]:
			var label: Label = row[key]
			var natural: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
			check(label.is_visible_in_tree() and label.size.x + 1.0 >= natural and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "responsive financial field renders every digit " + str(row.id) + " " + key)
	interaction_checks += 1
	await inspect("market-responsive-columns-" + suffix, "market")

func research_top(suffix: String) -> void:
	# Keep the original focus-driven screenshot and add the intentional top view.
	await frames(12)
	root.gui_release_focus()
	host.ui.page_scroll.scroll_vertical = 0
	await frames(5)
	check(root.gui_get_focus_owner() == null and host.ui.page_scroll.scroll_vertical == 0, "research top view waits for focus then releases automatic scrolling " + suffix)
	await inspect("research-top-" + suffix, "research")

func instrument_boundaries() -> void:
	var ship: RefCounted = host.state.ship()
	var original: Dictionary = {}
	for field: String in ["shield", "armor", "hull", "energy", "heat", "overheated"]: original[field] = ship.get(field)
	var metrics: Dictionary = host.gameplay.metrics(ship)
	var warning: float = float(host.store.catalog.rule("overheat_warning_ratio"))
	check(warning > 0.0 and warning < 1.0 and float(metrics.heat_max) > 0.0, "thermal display warning boundary comes from authoritative database")
	for size: Vector2i in [Vector2i(1440, 900), Vector2i(1024, 648), Vector2i(1920, 1080)]:
		root.size = size; root.content_scale_size = size
		host.ui.menu_open = false; host.ui.show_page("")
		host._process(0.0)
		await frames(8)
		var suffix: String = "%dx%d" % [size.x, size.y]
		ship.shield = float(metrics.shield_max) * 0.25
		ship.armor = 0.0
		ship.hull = float(metrics.hull_max) * 0.75
		ship.overheated = false
		ship.heat = 0.0
		host.ui._update_instrument(ship, metrics)
		await frames(3)
		var hull: Label = host.ui.condition_bars[2].label
		var armor: Label = host.ui.condition_bars[1].label
		check(hull.get_theme_color("font_color") == AuditTheme.TEXT and armor.get_theme_color("font_color") == AuditTheme.DANGER and label_fits(hull) and label_fits(armor), "recharged shield protects structure despite exhausted armor with readable layer text " + suffix)
		boundary_observations.append({"case": "shield_recharged_armor_empty", "size": [size.x, size.y], "shield": ship.shield, "armor": ship.armor, "hull_text": hull.text, "hull_color": hull.get_theme_color("font_color").to_html(true)})
		ship.shield = 0.0
		host.ui._update_instrument(ship, metrics)
		check(hull.get_theme_color("font_color") == AuditTheme.DANGER, "exhausted shield and armor expose structure " + suffix)
		ship.shield = float(metrics.shield_max) * 0.25
		var threshold: float = float(metrics.heat_max) * warning
		var epsilon: float = maxf(0.001, float(metrics.heat_max) * 0.000001)
		# Heat now has three distinct states, so the meter must show three distinct
		# visuals rather than one accent colour for both warning and idle.
		for thermal: Dictionary in [{"id": "below_warning", "heat": maxf(0.0, threshold - epsilon), "locked": false, "caption": "热量 ", "color": AuditTheme.TEXT, "fill": AuditTheme.ICE}, {"id": "above_warning", "heat": threshold + epsilon, "locked": false, "caption": "预警 ", "color": AuditTheme.WARN, "fill": AuditTheme.WARN}, {"id": "overheat_locked", "heat": float(metrics.heat_max), "locked": true, "caption": "锁定 ", "color": AuditTheme.DANGER, "fill": AuditTheme.DANGER}]:
			ship.heat = thermal.heat; ship.overheated = thermal.locked
			host.ui._update_instrument(ship, metrics)
			await frames(3)
			var heat: Label = host.ui.heat_label
			check(heat.text.begins_with(thermal.caption) and heat.get_theme_color("font_color") == thermal.color and label_fits(heat), "database thermal boundary has distinct readable caption and semantic color " + str(thermal.id) + " " + suffix)
			var fill: StyleBoxFlat = host.ui.heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
			check(fill != null and fill.bg_color == thermal.fill, "thermal meter reflects warning or lock semantics " + str(thermal.id) + " " + suffix)
			boundary_observations.append({"case": thermal.id, "size": [size.x, size.y], "database_warning_ratio": warning, "heat": ship.heat, "overheated": ship.overheated, "text": heat.text, "color": heat.get_theme_color("font_color").to_html(true), "rect": rectangle(heat.get_global_rect())})
		for field: String in original: ship.set(field, original[field])
		host.ui._update_instrument(ship, metrics)
		var restored: bool = true
		for field: String in original: restored = restored and ship.get(field) == original[field]
		check(restored, "temporary layer and heat display fixture restores all authoritative DTO fields before screenshot " + suffix)
		await inspect("flight-restored-boundaries-" + suffix, "")
	paid_fixture.append("temporary shield/armor/heat/overheated DTO display boundaries restored before screenshots")

func _initialize() -> void:
	get_tree().set_meta("xj_ui_quality_v61_diagnostic",true)
	create_timer(540.0).timeout.connect(func(): check(false, "bounded UI audit watchdog"); finish())
	_run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
	return ok

func frames(count: int = 8) -> void:
	for index: int in range(count): await process_frame

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func rectangle(value: Rect2) -> Array[float]:
	return [snappedf(value.position.x, 0.01), snappedf(value.position.y, 0.01), snappedf(value.size.x, 0.01), snappedf(value.size.y, 0.01)]

func style_data(style: StyleBox) -> Dictionary:
	var data: Dictionary = {"class": style.get_class(), "margins": [style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP), style.get_content_margin(SIDE_RIGHT), style.get_content_margin(SIDE_BOTTOM)]}
	if style is StyleBoxFlat:
		data.merge({"fill": style.bg_color.to_html(true), "border": style.border_color.to_html(true), "border_width": [style.border_width_left, style.border_width_top, style.border_width_right, style.border_width_bottom], "radius": [style.corner_radius_top_left, style.corner_radius_top_right, style.corner_radius_bottom_right, style.corner_radius_bottom_left], "shadow_size": style.shadow_size})
	return data

func clip_info(control: Control, viewport: Rect2) -> Dictionary:
	var clipped: Rect2 = control.get_global_rect().intersection(viewport)
	var ancestor: Node = control.get_parent()
	var scrolled: bool = false
	var scroll_parent: String = ""
	while ancestor != null:
		if ancestor is ScrollContainer:
			scrolled = true
			if scroll_parent.is_empty(): scroll_parent = str(ancestor.get_path())
		if ancestor is Control and ancestor.clip_contents: clipped = clipped.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return {"visible_rect": rectangle(clipped), "in_scroll": scrolled, "scroll_parent": scroll_parent, "has_visible_pixels": clipped.size.x > 0.5 and clipped.size.y > 0.5}

func inspect(name: String, expected: String) -> void:
	await frames(12)
	host.ui.tick(1.0)
	await frames(5)
	var ui: Node = host.ui
	var bounds := Rect2(Vector2.ZERO, ui.root.size)
	var controls: Array[Dictionary] = []
	var scrolls: Array[Dictionary] = []
	var local_findings: Array[Dictionary] = []
	check(ui.page == expected, "actual page reached " + name)
	if label == "after" and ui.page == "map":
		var bound_legend: Label = ui.body.find_child("ChartLegend", true, false)
		check(bound_legend != null and bound_legend.text.contains("外圈安全色") and bound_legend.text.contains("菱形争夺") and not bound_legend.text.contains("同盟绿"), "bound star chart retains the rendered limited-palette legend " + name)
	check(ui.root.size.is_equal_approx(Vector2(root.content_scale_size)), "actual logical canvas matches declared client size " + name)
	for node: Node in descendants(ui.root):
		if not node is Control or not node.is_visible_in_tree(): continue
		var control: Control = node
		var rect: Rect2 = control.get_global_rect()
		var clipping: Dictionary = clip_info(control, bounds)
		var item: Dictionary = {"path": str(control.get_path()), "class": control.get_class(), "rect": rectangle(rect), "minimum": [control.get_combined_minimum_size().x, control.get_combined_minimum_size().y], "clip": clipping, "theme_type_variation": str(control.theme_type_variation), "focus_mode": control.focus_mode}
		if control is Container:
			item["separation"] = control.get_theme_constant("separation")
		if control is Label:
			item.merge({"text": control.text, "font_size": control.get_theme_font_size("font_size"), "font_color": control.get_theme_color("font_color").to_html(true), "alignment": control.horizontal_alignment, "clip_text": control.clip_text, "autowrap": control.autowrap_mode})
		if control is Button:
			var button: Button = control
			var styles: Dictionary = {}
			for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]: styles[state] = style_data(button.get_theme_stylebox(state))
			var font: Font = button.get_theme_font("font")
			var font_size: int = button.get_theme_font_size("font_size")
			var natural: Vector2 = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			item.merge({"text": button.text, "disabled": button.disabled, "toggle_mode": button.toggle_mode, "pressed": button.button_pressed, "ui_role": str(button.get_meta("ui_role", "default")), "font_size": font_size, "font_color": button.get_theme_color("font_color").to_html(true), "colors": colors_for(button), "modulate": button.modulate.to_html(true), "draw_mode": button.get_draw_mode(), "styles": styles, "text_natural_width": natural.x, "icon": button.icon.resource_path if button.icon != null else "", "clip_text": button.clip_text, "autowrap": button.autowrap_mode})
			if bool(clipping.has_visible_pixels) and not bool(clipping.in_scroll) and not bounds.grow(1.0).encloses(rect):
				local_findings.append({"kind": "unscrolled_button_outside_viewport", "path": item.path, "text": button.text, "rect": item.rect})
			if bool(clipping.has_visible_pixels) and not button.clip_text and button.autowrap_mode == TextServer.AUTOWRAP_OFF and natural.x > rect.size.x + 1.0:
				local_findings.append({"kind": "button_text_wider_than_control", "path": item.path, "text": button.text, "text_width": natural.x, "rect": item.rect})
		if control is LineEdit:
			item.merge({"text": control.text, "font_size": control.get_theme_font_size("font_size"), "style": style_data(control.get_theme_stylebox("normal"))})
		if control is HScrollBar or control is VScrollBar:
			var styles: Dictionary = {}
			for state: String in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]: styles[state] = style_data(control.get_theme_stylebox(state))
			item["styles"] = styles
		if control is ScrollContainer:
			var horizontal: HScrollBar = control.get_h_scroll_bar()
			var vertical: VScrollBar = control.get_v_scroll_bar()
			scrolls.append({"path": str(control.get_path()), "rect": rectangle(rect), "horizontal_mode": control.horizontal_scroll_mode, "horizontal_overflow": horizontal.max_value > horizontal.page + 1.0, "horizontal_visible": horizontal.is_visible_in_tree(), "horizontal_max": horizontal.max_value, "horizontal_page": horizontal.page, "vertical_max": vertical.max_value, "vertical_page": vertical.page})
		controls.append(item)
	var important: Array[Control] = []
	if expected == "station": important = [ui.station_services, ui.station_details, ui.station_departure]
	elif expected.is_empty(): important = [ui.flight_header, ui.navigation, ui.target_panel, ui.flight_dock]
	else:
		var close: Control = ui.panel.find_child("PanelClose", true, false)
		if close != null: important.append(close)
		if ui.page_scroll.is_visible_in_tree(): important.append(ui.page_scroll)
	for control: Control in important:
		if control.is_visible_in_tree() and not bounds.grow(1.0).encloses(control.get_global_rect()): local_findings.append({"kind": "critical_frame_outside_viewport", "path": str(control.get_path()), "rect": rectangle(control.get_global_rect())})
	if expected.is_empty(): _check_equipment_row_fit(name)
	for finding: Dictionary in local_findings:
		finding["case"] = name
		findings.append(finding)
	if label == "after": structural_assertions(ui, name)
	var screenshot: String = ""
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		screenshot = directory.path_join(name + ".png")
		check(image.get_size() == root.size and image.save_png(screenshot) == OK, "whole native client screenshot saved " + name)
		captures += 1
	observations.append({"case": name, "page": ui.page, "native_size": [root.size.x, root.size.y], "logical_size": [ui.root.size.x, ui.root.size.y], "screenshot": screenshot, "controls": controls, "scrolls": scrolls, "findings": local_findings})
	print("UI_QUALITY_AUDIT_PAGE ", name, " controls=", controls.size(), " findings=", local_findings.size())

func show_and_inspect(page: String, suffix: String) -> void:
	host.ui.menu_open = false
	if page == "title": host.ui.show_title(host.store.list_slots())
	else: host.ui.show_page(page)
	if host.ui.page_scroll != null: host.ui.page_scroll.scroll_vertical = 0; host.ui.page_scroll.scroll_horizontal = 0
	await inspect(("flight" if page.is_empty() else page) + "-" + suffix, page)

func fixture() -> void:
	# Only display eligibility and inventory coverage. No natural play claims.
	host.state.player().credit = 1000000
	for definition: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.grant_unlock(str(definition.unlock_id))
	var warehouse: String = host.gameplay.inventory.warehouse(host.state.player().docked_station_id)
	for item: String in ["material_structural_stock", "module_spec_range", "module_spec_burst", "module_drone_swarm_i"]:
		host.gameplay.inventory.grant(warehouse, item, 3)
	if label != "after": return
	for definition: Dictionary in host.store.catalog.rows("auxiliary_drone_defs"):
		var granted: Array = host.gameplay.inventory.grant(warehouse, str(definition.module_id), 1)
		if check(not granted.is_empty(), "declared catalog auxiliary item granted " + str(definition.module_id)): auxiliary_items[str(definition.module_id)] = str(granted[0])
	host.gameplay.auxiliary_drones.sync()
	var before: Array[String] = []
	for ship: RefCounted in host.state.rows("ship_state"): before.append(ship.ship_instance_id)
	await host._command("buy_ship", "cruiser_horizon", 1, "")
	await settle_writer("paid spare cruiser")
	for ship: RefCounted in host.state.rows("ship_state"):
		if not before.has(ship.ship_instance_id) and ship.policy_id == "normal_owned": owned_ship_id = ship.ship_instance_id
	check(not owned_ship_id.is_empty(), "actual paid buy_ship creates a normal-owned idle hull")
	paid_fixture.append("actual paid buy_ship cruiser_horizon")
	var profile: String = "crew_pilot_1"
	await host._command("crew_action", profile, 1, "hire|" + host.gameplay.crew.token(profile))
	await settle_writer("paid pilot recruitment")
	check(host.gameplay.crew.member(profile).phase == "hired", "actual paid crew action recruits a pilot")
	if not owned_ship_id.is_empty():
		await host._command("crew_action", profile, 1, "assign|" + host.gameplay.crew.token(profile) + "|" + owned_ship_id)
		await settle_writer("pilot assignment")
		var assignment: RefCounted = host.gameplay.crew.assignment(profile)
		check(assignment != null and assignment.ship_instance_id == owned_ship_id, "actual crew assignment exposes populated management controls")
	paid_fixture.append("actual paid pilot hire and assignment")
	if label == "after" and not owned_ship_id.is_empty():
		await host._command("switch_ship", owned_ship_id, 1, "")
		await settle_writer("controlled drone-capable hull for station page inventory")
		check(host.state.ship().ship_instance_id == owned_ship_id, "station UI inventory is exercised on an actual supported controlled hull")

func variants(suffix: String) -> void:
	for section: String in ["owned", "crew"]:
		host.ui.fleet_section = section
		host.ui.show_page("ships")
		await inspect("ships-" + section + "-" + suffix, "ships")
	host.ui.fleet_section = "hulls"
	for filter: String in ["ships", "sell"]:
		host.ui.market_filter = filter
		host.ui.show_page("market")
		await inspect("market-" + filter + "-" + suffix, "market")
	host.ui.market_filter = "buy"
	for definition: Dictionary in host.store.catalog.rows("civilization_defs"):
		host.ui.civilization_selected_faction = str(definition.faction_id)
		host.ui.show_page("civilizations")
		await inspect("civilizations-" + str(definition.faction_id) + "-" + suffix, "civilizations")
	host.ui.show_page("fitting_analysis")
	await frames(8)
	for name: String in ["FittingConditionsToggle", "FittingDetailsToggle"]:
		var button: Button = host.ui.body.find_child(name, true, false)
		if check(button != null, "analysis embedded disclosure exists " + name):
			await actual_click(button, "analysis disclosure " + name)
			check(button.button_pressed and bool(button.get_meta("expanded", false)), "real analysis disclosure exposes its expanded state " + name)
	var details: Control = host.ui.body.find_child("FittingDetailedValues", true, false)
	check(details != null and details.visible, "real analysis detail disclosure becomes visible")
	host.ui.page_scroll.scroll_vertical = 0
	await inspect("fitting_analysis-expanded-" + suffix, "fitting_analysis")
	host.ui.title_show_slots = true
	host.ui.show_title(host.store.list_slots())
	await inspect("title-slots-" + suffix, "title")
	host.ui.title_show_slots = false
	host.ui.menu_open = false
	host.ui.show_page("pause")
	host.ui.set_operation_status("save", "等待当前周期结束后保存；可继续航行或取消。", true)
	await inspect("pause-save-wait-" + suffix, "pause")
	host.ui.set_operation_status("idle", "")
	# Native vertical scrolling exposes content below the first client viewport.
	for page: String in ["pause", "missions", "research", "industry", "civilizations", "projects", "sources"]:
		host.ui.show_page(page)
		await frames(6)
		host.ui.page_scroll.scroll_vertical = int(host.ui.page_scroll.get_v_scroll_bar().max_value)
		await inspect(page + "-bottom-" + suffix, page)
	if label == "after": await after_variants(suffix)
	if label == "after": await information_variants(suffix)

func information_variants(suffix: String) -> void:
	pointer_trace("alias-before-dispatch " + suffix)
	host.ui.show_page("salvage")
	pointer_trace("alias-immediate " + suffix)
	for index: int in range(6):
		await frames(1)
		pointer_trace("alias-settle-%d " % index + suffix)
	check(host.ui.page == "warehouse" and host.ui.warehouse_panel != null, "legacy salvage route resolves to the real warehouse service")
	await inspect("warehouse-salvage-alias-" + suffix, "warehouse")
	pointer_trace("alias-inspected " + suffix)
	host.ui.show_page("research"); await frames(6)
	for kind: String in ["faction", "specialization", "exploration", "facility"]:
		var tab: Button = host.ui.body.find_child("ResearchTab_" + kind, true, false)
		if tab == null: continue
		await actual_click(tab, "research category " + kind)
		await frames(5)
		var show_done: Button = host.ui.body.find_child("ResearchShowCompleted", true, false)
		if show_done != null and show_done.is_visible_in_tree() and not show_done.button_pressed: await actual_click(show_done, "show researched history " + kind)
		var selectors: Array[Node] = host.ui.body.find_children("ResearchSelect_*", "Button", true, false)
		if not selectors.is_empty(): await actual_click(selectors[-1] as Button, "select actual research detail " + str(selectors[-1].name))
		check(host.ui.body.find_children("ResearchDetail", "VBoxContainer", true, false).size() == 1, "technology category constructs a single selected detail " + kind)
		await inspect("research-category-" + kind + "-" + suffix, "research")
	for kind: String in ["manufacture", "jobs", "demands", "recycle"]:
		host.ui.show_page("industry"); await frames(5)
		var tab: Button = host.ui.body.find_child("IndustryTab_" + kind, true, false)
		if tab == null: continue
		await actual_click(tab, "industry category " + kind)
		await frames(5)
		check(host.ui.industry_tab == kind, "industry category is actually selected " + kind)
		await inspect("industry-category-" + kind + "-" + suffix, "industry")
	for kind: String in ["progress", "contribution", "command", "campaign"]:
		host.ui.show_page("civilizations"); await frames(5)
		var tab: Button = host.ui.body.find_child("CivilizationSection_" + kind, true, false)
		if not check(tab != null, "civilization category exists " + kind): continue
		await actual_click(tab, "civilization category " + kind)
		await frames(5)
		check(str(host.ui.get_meta("civilization_section", "progress")) == kind, "civilization selected category follows actual input " + kind)
		await inspect("civilizations-category-" + kind + "-" + suffix, "civilizations")
	for page: String in ["fitting", "missions", "ships", "ship_roles"]:
		host.ui.show_page(page); await frames(6)
		for node: Node in descendants(host.ui.body):
			if not node.has_meta("info_list"): continue
			var current_rows: Array = node.get("rows")
			if current_rows.size() < 2: continue
			var chosen: String = str(current_rows[-1].id)
			var external: bool = bool(node.get("details_external"))
			await actual_click(current_rows[-1].selector, "non-trading row " + page + " " + chosen)
			check(str(node.get("selected_id")) == chosen and (current_rows[-1].details.visible or external) and not current_rows[0].details.visible, "new selection closes old detail " + page)
			if external:
				check(host.ui.stage_detail.get_child_count() > 0, "stage selection fills the detail column " + page)
			await actual_click(current_rows[-1].selector, "reactivate current detail " + page)
			check((current_rows[-1].details.visible or external) and current_rows[-1].selector.button_pressed, "current item stays explicitly selected on repeated activation " + page)
		await inspect(page + "-selected-detail-" + suffix, page)

func after_variants(suffix: String) -> void:
	for group: Dictionary in [{"page": "projects", "table": "construction_project_defs", "key": "project_id", "prefix": "ProjectSelect_", "selection": "project_selected_id"}, {"page": "exploration", "table": "exploration_event_defs", "key": "event_id", "prefix": "ExploreSelect_", "selection": "exploration_selected"}, {"page": "trials", "table": "trial_defs", "key": "trial_id", "prefix": "ScenarioSelect_", "selection": "trial_selected_id"}, {"page": "blockades", "table": "blockade_defs", "key": "blockade_id", "prefix": "ScenarioSelect_", "selection": "blockade_selected_id"}]:
		host.ui.show_page(group.page)
		await frames(8)
		var definitions: Array = host.store.catalog.rows(group.table)
		for definition: Dictionary in definitions:
			var id: String = str(definition[group.key])
			var button: Button = host.ui.body.find_child(str(group.prefix) + id, true, false)
			await actual_click(button, str(group.page) + " selector " + id)
			await frames(5)
			check(str(host.ui.get(group.selection)) == id, "real selector updates the displayed choice " + id)
			var selected: Button = host.ui.body.find_child(str(group.prefix) + id, true, false)
			if group.page == "projects":
				check(selected != null and selected.toggle_mode and selected.button_pressed, "current project has a real selected button state " + id)
				if selected != null:
					var plate: StyleBoxFlat = selected.get_theme_stylebox("normal") as StyleBoxFlat
					var unselected: StyleBoxFlat = AuditTheme.button_surface("filter", "normal", true, false)
					check(plate != null and plate.bg_color != unselected.bg_color and plate.border_color != unselected.border_color and selected.get_meta("ui_role", "") == "filter", "selected project has a distinct semantic plate " + id)
			await inspect(str(group.page) + "-choice-" + id + "-" + suffix, group.page)
	# A disabled business service is never invoked; only native presentation states.
	host.ui.show_page("pause")
	await frames(8)
	var danger: Button = host.ui.body.find_child("QuitWithoutSave", true, false)
	if danger != null:
		host.ui.page_scroll.ensure_control_visible(danger)
		await frames(5)
		await probe_states(danger, "danger quit-discard with release suppressed")
	host.ui.show_title(host.store.list_slots())
	await frames(8)
	var primary: Button
	var secondary: Button
	for node: Node in descendants(host.ui.body):
		if not node is Button: continue
		if str(node.get_meta("ui_role", "")) == "primary" and primary == null: primary = node
		if str(node.get_meta("ui_role", "")) == "secondary" and secondary == null: secondary = node
	await probe_states(primary, "primary continue with release suppressed")
	await probe_states(secondary, "secondary new-world/settings with release suppressed")
	host.ui.menu_open = false

func fresh_external_directory(filename: String,prefix: String) -> bool:
	# The executable's res:// is its PCK. Scope derives from this fixed external
	# test Node, exactly as the production diagnostic dispatcher validates it.
	var source: Script=get_script() as Script
	var script_path: String=source.resource_path.replace("\\","/")
	var expected_root: String=script_path.get_base_dir().get_base_dir().path_join("tmp/"+prefix)
	var uuid: RegEx=RegEx.new()
	uuid.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	return script_path.is_absolute_path() and not script_path.contains("..") and script_path.ends_with("/jiaoben/tests/"+filename) and FileAccess.file_exists(script_path) and directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir()==expected_root and uuid.search(directory.get_file())!=null and not FileAccess.file_exists(directory.path_join("progress.db"))

func _run() -> void:
	directory = OS.get_environment("XJ_UI_QUALITY_AUDIT_DIRECTORY").replace("\\", "/")
	label = OS.get_environment("XJ_UI_QUALITY_AUDIT_LABEL")
	if not check(fresh_external_directory("ui_quality_audit.gd","ui-quality-audit"), "fresh scoped test-owned database required"):
		await finish(); return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_factor = 1.0
	root.content_scale_size = root.size
	host = Main.new()
	host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host)
	await frames(8)
	if not check(host.services_ready and host.state == null, "real Main starts isolated title without opening a personal save"):
		await finish(); return
	await show_and_inspect("title", "empty-1440x900")
	await host._command("new_world", "UI 品质专项 · " + label, 1, "")
	await frames(8)
	if not check(host.state != null and host.state.player().has_docked_station_id, "real new-world command provides a docked display world"):
		await finish(); return
	await fixture()
	# The manually saved UI fixture creates truthful archive cards in its own DB.
	await host._command("save", "0", 1, "manual")
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy and not host.store.list_slots().is_empty(), "fixture save closes before page traversal")
	host.set_process(false)
	host.set_physics_process(false)
	for size: Vector2i in [Vector2i(1440, 900), Vector2i(1024, 648), Vector2i(1920, 1080)]:
		root.size = size
		root.content_scale_size = size
		await frames(6)
		var suffix: String = "%dx%d" % [size.x, size.y]
		for page: String in PAGES:
			await show_and_inspect(page, suffix)
			if label == "after" and page == "market" and size == Vector2i(1024, 648): await horizontal_scroll_interaction(suffix)
			if label == "after" and page == "research": await research_top(suffix)
		if size == Vector2i(1440, 900): await variants(suffix)
	# Keep native pixels and logical canvas distinct at the supported 200% edge.
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	await frames(8)
	for page: String in PAGES: await show_and_inspect(page, "1280x720-200pct")
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	await frames(6)
	# Actual undock transaction supplies the flight HUD without invented state.
	host.ui.menu_open = false
	host.ui.show_page("station")
	if label == "after" and not owned_ship_id.is_empty():
		await host._command("switch_ship", owned_ship_id, 1, "")
		await settle_writer("switch to paid auxiliary-capable hull")
		check(host.state.ship().ship_instance_id == owned_ship_id, "real switch_ship selects the paid cruiser")
		for item: RefCounted in host.state.rows("item_instance_state"):
			if item.item_def_id == "module_drone_swarm_i" and item.container_id == host.gameplay.inventory.warehouse(host.gameplay.station()):
				auxiliary_items["module_drone_swarm_i"] = item.item_instance_id
				break
		for pair: Array in [["module_aux_repair_i", "work:0"], ["module_aux_recon_i", "work:1"], ["module_drone_swarm_i", "weapon:0"]]:
			if not check(auxiliary_items.has(pair[0]), "declared auxiliary module exists " + str(pair[0])): continue
			await host._command("fit_module", str(auxiliary_items[pair[0]]), 1, pair[1])
			await settle_writer("legal auxiliary fit " + str(pair[0]))
			check(host.state.find("equipment_state", "item_instance_id", str(auxiliary_items[pair[0]])) != null, "real fit_module equips catalog auxiliary " + str(pair[0]))
		paid_fixture.append("actual switch_ship and legal repair/recon/attack fitting")
	await host._command("undock", "", 1, "")
	deadline = Time.get_ticks_msec() + 10000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	if check(host.state.ship().status == T.ShipStatus.FLYING, "real undock provides flight HUD"):
		# Production process owns hangar/world visibility and the active camera.
		host._process(0.0)
		await frames(5)
		check(not host.hangar.is_visible_in_tree() and host.world.is_visible_in_tree() and root.get_camera_3d() == host.camera.camera and host.world.flight.record.ship_instance_id == host.state.ship().ship_instance_id, "production presentation process activates real space and the controlled hull camera")
		for size: Vector2i in [Vector2i(1440, 900), Vector2i(1024, 648), Vector2i(1920, 1080)]:
			root.size = size
			root.content_scale_size = size
			await show_and_inspect("", "%dx%d" % [size.x, size.y])
		root.size = Vector2i(1280, 720); root.content_scale_size = Vector2i(640, 360)
		await show_and_inspect("", "1280x720-200pct")
		if label == "after":
			root.size = Vector2i(1440, 900)
			root.content_scale_size = root.size
			var report: RefCounted = host.gameplay.telemetry.latest()
			check(report != null and report.phase == "active" and not report.partial_baseline and host.state.rows("flight_record_state").size() >= 1, "normal undock produces a real nonpartial active flight report")
			paid_fixture.append("actual undock creates active nonpartial flight report; no completed return claimed")
			for page: String in ["reports", "drones", "operations"]: await show_and_inspect(page, "flight-populated-1440x900")
			var panel: Node = host.ui.body
			host.ui.show_page("drones")
			await frames(5)
			panel = host.ui.body
			check(panel.find_child("AuxiliaryIntelPanel", true, false) != null and not panel.find_children("AuxiliaryLaunch_*", "Button", true, false).is_empty(), "real flight drone view includes mounted repair/recon and intelligence controls")
			host.ui.page_scroll.scroll_vertical = int(host.ui.page_scroll.get_v_scroll_bar().max_value)
			await inspect("drones-auxiliary-flight-bottom-1440x900", "drones")
			await instrument_boundaries()
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	if label == "after":
		for category: String in caption_samples: check(int(caption_samples[category]) > 0, "real single-line caption family exercised " + category)
		check(role_samples.has("primary") and role_samples.has("secondary") and role_samples.has("danger"), "actual rendered primary secondary and danger roles are represented")
		if role_samples.has("primary") and role_samples.has("secondary") and role_samples.has("danger"):
			var primary: Dictionary = role_samples.primary
			var secondary: Dictionary = role_samples.secondary
			var danger: Dictionary = role_samples.danger
			check(primary.style != secondary.style and primary.style != danger.style and secondary.style != danger.style, "primary secondary danger surfaces have distinct semantic color treatments")
			check(primary.font == AuditTheme.AMBER.to_html(true) and secondary.font == AuditTheme.MUTED.to_html(true) and danger.font == AuditTheme.DANGER.to_html(true), "semantic role text colors match shared amber muted and danger tokens")
		var current: Theme = AuditTheme.create()
		var tabs: bool = true
		for type: String in ["TabBar", "TabContainer"]:
			for state: String in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]: tabs = tabs and flat_geometry(current.get_stylebox(state, type))
		check(tabs and style_data(current.get_stylebox("tab_selected", "TabBar")) != style_data(current.get_stylebox("tab_unselected", "TabBar")), "shared tab selected disabled hover and focus surfaces retain square geometry")
	if OS.get_environment("XJ_UI_QUALITY_AUDIT_STRICT_LAYOUT") == "1":
		for finding: Dictionary in findings:
			if finding.kind == "critical_frame_outside_viewport": check(false, str(finding.case) + " " + str(finding.path) + " critical bounds")
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(6)
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory, "label": label, "native": DisplayServer.get_name() != "headless", "pages": PAGES + [""], "observations": observations, "findings": findings, "fixtures": ["fresh UUID test-owned SQLite", "credit=1000000", "all catalog unlocks", "four named local inventory items x3", "actual manual save", "actual undock"] + paid_fixture, "interaction_checks": interaction_checks, "role_samples": role_samples, "caption_samples": caption_samples, "boundary_observations": boundary_observations, "scope": "UI rendering and selected real GUI interactions; no active combat acceptance, all mission/operation runtime phases, all tooltip/pop-up states, natural progression, or complete business correctness"}
	var file: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(summary, "\t") + "\n"); file.close()
	print("UI_QUALITY_AUDIT_FINAL_JSON ", JSON.stringify({"result": summary.result, "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory, "pages": summary.pages, "observations_count": observations.size(), "findings_count": findings.size(), "native": summary.native, "label": label}))
	print("UI_QUALITY_AUDIT_RESULT ", summary.result, " checks=", checks, " failures=", failures.size(), " captures=", captures)
	quit(0 if failures.is_empty() else 1)
