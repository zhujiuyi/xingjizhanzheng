extends RefCounted
## F6 is a deliberate HUD mode; Tab retains target cycling during normal flight.
const Types = preload("res://contracts/contract_types.gd")
var active: bool = false
var saved_modes: Dictionary = {}
var last_index: int = 0

func handle(ui: Node, event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		reset(ui)
		return false
	if ui.loading_suspended or not ui.page.is_empty() or ui.state == null or ui.state.ship().status != Types.ShipStatus.FLYING:
		reset(ui)
		return false
	if not event is InputEventKey or not event.pressed: return false
	if event.is_echo(): return active
	if DisplayServer.get_name() != "headless" and not ui.get_window().has_focus(): return false
	var key: int = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	if not active and key == KEY_TAB and not ui.keyboard_blocked():
		# The GUI's default Tab traversal must not steal the established target key.
		ui.select_next()
		return true
	if key == KEY_F6:
		if active: reset(ui)
		else:
			active = true
			move(ui, 0)
			ui.notify("HUD键盘操作 · Tab/方向键移动 · Enter操作 · Esc返回操舰")
		return true
	if not active: return false
	if key == KEY_ESCAPE:
		reset(ui)
		return true
	if key in [KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		move(ui, -1 if event.shift_pressed or key in [KEY_UP, KEY_LEFT] else 1)
		return true
	# Only GUI activation reaches the focused control; flight/page/save hotkeys
	# remain suppressed until the player explicitly leaves HUD focus mode.
	return key not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]

func controls(ui: Node) -> Array[Control]:
	var result: Array[Control] = []
	for key: String in ["navigation", "mission_navigation_row", "work_box", "operation_bar", "target_panel", "flight_dock"]:
		var surface: Control = ui.get(key) as Control
		if is_instance_valid(surface) and surface.is_visible_in_tree(): _collect(surface, result)
	return result

func _collect(node: Node, result: Array[Control]) -> void:
	if node is BaseButton and node.is_visible_in_tree() and not node.is_queued_for_deletion() and not node.disabled and not result.has(node):
		var id: int = node.get_instance_id()
		if not saved_modes.has(id): saved_modes[id] = {"reference": weakref(node), "mode": node.focus_mode, "next": node.focus_next, "previous": node.focus_previous}
		node.focus_mode = Control.FOCUS_ALL
		result.append(node)
	for child: Node in node.get_children(): _collect(child, result)

func move(ui: Node, direction: int) -> void:
	var entries: Array[Control] = controls(ui)
	if entries.is_empty(): reset(ui); return
	var current: Control = ui.root.get_viewport().gui_get_focus_owner()
	var index: int = entries.find(current)
	last_index = posmod(index + direction, entries.size()) if index >= 0 else clampi(last_index, 0, entries.size() - 1)
	entries[last_index].grab_focus()
	ui.call("_reveal_page_control", entries[last_index])
	for item: Control in entries:
		var next: int = (entries.find(item) + 1) % entries.size()
		item.focus_next = entries[next].get_path()
		item.focus_previous = entries[posmod(next - 2, entries.size())].get_path()

func maintain(ui: Node) -> void:
	if not active: return
	if ui.loading_suspended or not ui.page.is_empty() or not ui.root.visible:
		reset(ui)
		return
	var focus: Control = ui.root.get_viewport().gui_get_focus_owner()
	if not is_instance_valid(focus) or not focus.is_visible_in_tree() or focus.is_queued_for_deletion() or (focus is BaseButton and focus.disabled): move(ui, 0)

func reset(ui: Node) -> void:
	if not active and saved_modes.is_empty(): return
	var current: Control = ui.root.get_viewport().gui_get_focus_owner() if is_instance_valid(ui.root) else null
	if is_instance_valid(current) and saved_modes.has(current.get_instance_id()): ui.root.get_viewport().gui_release_focus()
	for entry: Dictionary in saved_modes.values():
		var control: Control = entry.reference.get_ref() as Control
		if is_instance_valid(control):
			control.focus_mode = int(entry.mode)
			control.focus_next = entry.next
			control.focus_previous = entry.previous
	saved_modes.clear()
	active = false
	last_index = 0
