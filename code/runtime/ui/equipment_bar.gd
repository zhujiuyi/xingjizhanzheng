class_name XJEquipmentBar
extends PanelContainer
## Read-only module snapshots. Only the host can enable modules or pay cycles.
signal toggle_requested(item_id: String, enabled: bool)
signal engine_requested()
signal combat_option_requested(option: String, enabled: bool)
const UISkin = preload("res://runtime/ui_theme.gd")
const Portraits = preload("res://runtime/ui/item_portraits.gd")
var module_records: Array[Dictionary] = []
var module_buttons: Dictionary = {}
var module_labels: Dictionary = {}
var module_progress: Dictionary = {}
var engine_button: Button
var summary_label: Label
var header: HBoxContainer
var row: HFlowContainer
var slot_records: Array[Dictionary] = []
var slot_buttons: Dictionary = {}
var empty_slot_buttons: Dictionary = {}
var combat_option_buttons: Dictionary = {}
var combat_options_row: HBoxContainer
var combat_status_label: Label
var _compact: bool = false
var _combat_options: Dictionary = {"fire": false, "orbit": false, "seek": false}
var _combat_message: String = "手动战斗"
var _combat_blocked: bool = false

## Cooldown traced around a slot's own frame. A battleship fits 17 modules; at the
## old 80 px tile that is 1424 px of tiles inside a 656 px dock, which put a
## horizontal scroll bar in the flight HUD whenever a full loadout cycled. The
## tiles are now flexible and the countdown is the frame itself, so nothing has to
## scroll and the "循环就绪" caption has somewhere better to live.
class SlotRing extends Control:
	var value: float = 0.0
	var max_value: float = 1.0
	var tint: Color = XJUITheme.ICE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func ratio() -> float:
		return clampf(value / maxf(max_value, 0.001), 0.0, 1.0)

	func _draw() -> void:
		var amount: float = ratio()
		if amount <= 0.0: return
		var inset: float = 1.5
		var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		if rect.size.x <= 4.0 or rect.size.y <= 4.0: return
		var points: PackedVector2Array = _perimeter(rect)
		var traced: int = clampi(int(ceil(amount * float(points.size() - 1))) + 1, 2, points.size())
		draw_polyline(points.slice(0, traced), tint, 2.0, true)

	func _perimeter(rect: Rect2) -> PackedVector2Array:
		var corners: Array[Vector2] = [
			Vector2(rect.position.x, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, rect.end.y),
			Vector2(rect.position.x, rect.end.y),
		]
		var per_side: int = 8
		var points := PackedVector2Array()
		for index: int in 4:
			var from: Vector2 = corners[index]
			var to: Vector2 = corners[(index + 1) % 4]
			for step: int in per_side:
				points.append(from.lerp(to, float(step) / float(per_side)))
		points.append(corners[0])
		return points

func _ready() -> void:
	name = "EquipmentCycles"
	add_theme_stylebox_override("panel", UISkin.hud_panel(4))
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	add_child(layout)
	header = HBoxContainer.new()
	_header_label(header, "设备循环", UISkin.SIZE_NOTE, UISkin.TEXT)
	summary_label = _header_label(header, "", 10, UISkin.MUTED)
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layout.add_child(header)
	_build_combat_options(layout)
	# A plain flow, not a scroll container: the row must always fit the dock, so the
	# tiles share the width instead of overflowing it. 17 modules at the worst case
	# is what sets the minimum below.
	row = HFlowContainer.new()
	row.name = "EquipmentRow"
	row.add_theme_constant_override("h_separation", 3)
	row.add_theme_constant_override("v_separation", 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(row)
	engine_button = Button.new()
	engine_button.name = "EngineCycle"
	engine_button.text = "增推"
	engine_button.focus_mode = Control.FOCUS_NONE
	engine_button.custom_minimum_size = Vector2(54, 28)
	engine_button.add_theme_font_size_override("font_size", 11)
	UISkin.apply_button(engine_button, "filter", true, true)
	engine_button.pressed.connect(func(): engine_requested.emit())
	row.add_child(engine_button)
	engine_button.hide()

func refresh(records: Array[Dictionary], resources: Dictionary, busy: bool = false) -> void:
	module_records = records
	_refresh_combat_controls()
	slot_records.clear()
	slot_buttons.clear()
	if row == null: return
	summary_label.text = "%d件设备" % records.size()
	var ids: Array[String] = []
	var has_engine: bool = false
	for record: Dictionary in records:
		var id: String = str(record.id)
		ids.append(id)
		has_engine = has_engine or str(record.get("module_id", "")).begins_with("module_engine_")
		var button: Button
		if module_buttons.has(id): button = module_buttons[id]
		else:
			button = Button.new()
			button.name = "Module_" + id.validate_node_name()
			button.toggle_mode = true
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func():
				for current: Dictionary in module_records:
					if str(current.id) == id: toggle_requested.emit(id, not bool(current.enabled)); return)
			row.add_child(button)
			var labels: VBoxContainer = VBoxContainer.new()
			labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			labels.offset_left = 5; labels.offset_right = -5
			labels.offset_top = 2; labels.offset_bottom = -4
			labels.add_theme_constant_override("separation", 0)
			labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(labels)
			var icon: TextureRect = TextureRect.new()
			icon.texture = Portraits.texture("item", str(record.module_id))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(16,16)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			labels.add_child(icon)
			var title: Label = _header_label(labels, "", 9, UISkin.TEXT)
			var cost: Label = _header_label(labels, "", 9, UISkin.MUTED)
			# Share the icon area without enlarging the compact tile or slot-ID row.
			var status: Label = _header_label(button, "", 9, UISkin.MUTED)
			status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			status.offset_left = 4; status.offset_right = -4
			status.offset_top = 2; status.offset_bottom = 16
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status.clip_text = true
			status.max_lines_visible = 1
			module_labels[id] = {"title": title, "status": status, "cost": cost, "icon": icon}
			var ring: SlotRing = SlotRing.new()
			ring.name = "ActualCycle"
			button.add_child(ring)
			module_progress[id] = ring
			module_buttons[id] = button
		button.disabled = busy
		var slot_snapshot: Dictionary = record.duplicate()
		slot_snapshot["slot_id"] = str(record.get("slot_id", id))
		slot_snapshot["slot_type"] = int(record.get("slot_type", 0))
		slot_snapshot["slot_index"] = int(record.get("slot_index", 0))
		slot_records.append(slot_snapshot)
		slot_buttons[str(record.get("slot_id", id))] = button
		button.set_pressed_no_signal(bool(record.get("enabled", false)))
		UISkin.apply_button(button, "filter", true, bool(record.get("enabled", false)))
		_tighten_slot_surface(button)
		button.tooltip_text = "%s\n%s槽 %d · %s\n循环 %.1f s · 电容 %.0f · 热量 %.0f\n耐久 %.0f · 点击%s设备" % [str(record.title), str(record.get("slot_title", "")), int(record.get("slot_index", 0)) + 1, str(record.get("state_label", "")), float(record.get("cycle_s", 0.0)), float(record.get("energy_eu", 0.0)), float(record.get("heat_hu", 0.0)), float(record.get("durability", 0.0)), "关闭" if bool(record.get("enabled", false)) else "启用"]
		var labels: Dictionary = module_labels[id]
		labels.title.text = "%s%d" % [str(record.get("slot_short", "")), int(record.get("slot_index", 0)) + 1]
		# Only the states a frame cannot express get words. Ready is the absence of
		# a ring; a running cycle, a lock or a shortage still needs to be readable.
		labels.status.text = _short_status(record)
		labels.status.visible = not labels.status.text.is_empty()
		# A compact state replaces the icon area; it never overprints the slot ID.
		labels.icon.modulate.a = 0.0 if labels.status.visible else 1.0
		labels.cost.text = "电容 %.0f · 热量 %.0f" % [float(record.get("energy_eu", 0.0)), float(record.get("heat_hu", 0.0))]
		labels.cost.hide()
		# Enabled but not ready: cycling, i.e. momentarily blocked, not selected.
		labels.status.add_theme_color_override("font_color", UISkin.WARN if not bool(record.get("ready", false)) and bool(record.get("enabled", false)) else UISkin.TEXT if bool(record.get("enabled", false)) else UISkin.MUTED)
		button.custom_minimum_size = Vector2(30, 34 if _compact else 44)
		button.size_flags_horizontal = Control.SIZE_FILL
		var ring: SlotRing = module_progress[id]
		# Same two values the old bar carried: database cycle length and the real
		# remaining seconds, so the frame traces an authoritative countdown.
		ring.max_value = maxf(float(record.get("cycle_s", 0.0)), 0.001)
		ring.value = float(record.get("cooldown_remaining_s", 0.0))
		ring.visible = float(record.get("cooldown_remaining_s", 0.0)) > 0.0
		ring.tint = UISkin.WARN if ring.visible else UISkin.ICE
		ring.queue_redraw()
		row.move_child(button, ids.size())
	for id: String in module_buttons.keys():
		if id not in ids:
			var button: Button = module_buttons[id]
			row.remove_child(button); button.queue_free()
			module_buttons.erase(id); module_labels.erase(id); module_progress.erase(id)
	var empty_ids: Array[String] = []
	var empty_titles: Array[String] = []
	var empty_records: Array[Dictionary] = resources.get("empty_slots", [])
	# One tile stands for every empty slot. Twelve 80 px placeholders produced
	# 1088 px of tiles inside a 656 px viewport, which forced a horizontal scroll
	# bar into the flight HUD. The count is the useful signal; twelve identical
	# "空槽" labels are not. Every placeholder is still created, so the slot
	# bookkeeping and ordering below are unchanged - the extras are just hidden.
	var summary_id: String = str(empty_records[0].slot_id) if not empty_records.is_empty() else ""
	for record: Dictionary in empty_records:
		var slot_id: String = str(record.slot_id)
		empty_ids.append(slot_id)
		empty_titles.append("%s槽 %d" % [str(record.slot_title), int(record.slot_index) + 1])
		slot_records.append(record)
		var placeholder: Button
		if empty_slot_buttons.has(slot_id): placeholder = empty_slot_buttons[slot_id]
		else:
			placeholder = Button.new()
			placeholder.name = "EmptySlot_" + slot_id.validate_node_name()
			placeholder.focus_mode = Control.FOCUS_NONE
			placeholder.disabled = true
			UISkin.apply_button(placeholder, "secondary", true)
			row.add_child(placeholder)
			empty_slot_buttons[slot_id] = placeholder
		placeholder.visible = slot_id == summary_id
		placeholder.add_theme_font_size_override("font_size", UISkin.SIZE_NOTE)
		if slot_id == summary_id:
			placeholder.text = "空槽 ×%d" % empty_records.size()
			placeholder.custom_minimum_size = Vector2(0, 34 if _compact else 44)
			placeholder.size_flags_horizontal = Control.SIZE_FILL
			placeholder.tooltip_text = "%d 个空槽 · %s\n停靠空间站后前往配装页面安装兼容设备。" % [empty_records.size(), " / ".join(empty_titles)]
		else:
			placeholder.text = ""
			placeholder.tooltip_text = ""
			placeholder.custom_minimum_size = Vector2.ZERO
		slot_buttons[slot_id] = placeholder
	for slot_id: String in empty_slot_buttons.keys():
		if slot_id in empty_ids: continue
		var placeholder: Button = empty_slot_buttons[slot_id]
		row.remove_child(placeholder); placeholder.queue_free()
		empty_slot_buttons.erase(slot_id)
	slot_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.slot_type) == int(b.slot_type): return int(a.slot_index) < int(b.slot_index)
		return int(a.slot_type) < int(b.slot_type))
	for index: int in range(slot_records.size()): row.move_child(slot_buttons[str(slot_records[index].slot_id)], index + 1)
	engine_button.visible = has_engine
	engine_button.disabled = busy or not bool(resources.get("engine_ready", false))
	engine_button.tooltip_text = str(resources.get("engine_reason", "需要已启用且可支付循环消耗的增推设备。"))

## A full battleship loadout wraps the row to two lines at the smallest supported
## size, so the vertical padding is trimmed to buy that second line real room
## instead of relying on a one-pixel margin.
func _tighten_slot_surface(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var surface: StyleBoxFlat = button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if surface == null: continue
		surface.content_margin_top = 2
		surface.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, surface)

## The tile has room for about three characters, so the long state phrases become
## short tags. Nothing is dropped: the full phrase stays in the tooltip, and the
## states that matter are the ones that get the ink.
func _short_status(record: Dictionary) -> String:
	var state: String = str(record.get("state_label", ""))
	if state.begins_with("冷却 "): return "冷却"
	if state.begins_with("运行 "): return "运行"
	match str(record.get("state_label", "")):
		"设备损坏": return "损坏"
		"过热锁定": return "锁定"
		"电容不足": return "缺电"
		"热量受限": return "受限"
		"已启用", "循环就绪", "持续启用", "已关闭": return ""
		_: return str(record.get("state_label", ""))

func responsive(compact: bool) -> void:
	_compact = compact
	if header == null: return
	add_theme_stylebox_override("panel", UISkin.hud_panel(2 if compact else 4))
	header.visible = not compact
	combat_status_label.visible = not compact
	for option: String in combat_option_buttons:
		var check: CheckBox = combat_option_buttons[option]
		check.add_theme_font_size_override("font_size", 10 if compact else 11)
		check.custom_minimum_size.y = 24
	engine_button.custom_minimum_size = Vector2(54, 36 if compact else 28)
	for labels: Dictionary in module_labels.values():
		labels.title.add_theme_font_size_override("font_size", 10)
		labels.status.add_theme_font_size_override("font_size", 9)
		labels.cost.hide()
	# Flexible, not fixed: 17 tiles share the dock width instead of overflowing it.
	for button: Variant in slot_buttons.values():
		button.custom_minimum_size = Vector2(30, 34 if compact else 44)
		button.size_flags_horizontal = Control.SIZE_FILL

func _build_combat_options(parent: VBoxContainer) -> void:
	combat_options_row = HBoxContainer.new()
	combat_options_row.name = "CombatAutomationOptions"
	combat_options_row.add_theme_constant_override("separation", 4)
	parent.add_child(combat_options_row)
	var titles: Dictionary = {"fire": "自动战斗", "orbit": "自动环绕", "seek": "自动索敌"}
	var names: Dictionary = {"fire": "AutoCombatFire", "orbit": "AutoCombatOrbit", "seek": "AutoCombatSeek"}
	var hints: Dictionary = {
		"fire": "持续使用所有已启用且完好的武器。\n每件武器冷却完成，并满足射程、射界、\n电容和热量条件时自动发射。\n关闭此项停止自动发射，手动开火仍可使用。",
		"orbit": "围绕当前战斗目标航行；超出武器范围时先接近。\n是否自动发射由自动战斗决定。\n手动推进、转向或 X 停船取消自动环绕，\n自动战斗保留。",
		"seek": "自动锁定可探测的最近敌对舰船。\n目标消灭后重新寻找；超出武器范围时自动接近。\n进入范围后按自动战斗、自动环绕设定继续。\n手动推进、转向或 X 停船取消自动索敌，\n自动战斗保留。"
	}
	var options: Array[String] = ["fire", "orbit", "seek"]
	for option: String in options:
		var check: CheckBox = CheckBox.new()
		check.name = str(names[option])
		check.text = str(titles[option])
		check.focus_mode = Control.FOCUS_ALL
		check.mouse_filter = Control.MOUSE_FILTER_STOP
		check.custom_minimum_size.y = 24
		check.add_theme_font_size_override("font_size", 11)
		check.add_theme_constant_override("h_separation", 4)
		UISkin.apply_button(check, "filter", true)
		check.set_meta("action", "set_combat_option")
		check.set_meta("option", option)
		check.set_meta("combat_hint", str(hints[option]))
		check.toggled.connect(_request_combat_option.bind(option))
		combat_options_row.add_child(check)
		combat_option_buttons[option] = check
	for index: int in range(options.size()):
		var check: CheckBox = combat_option_buttons[options[index]]
		var previous: CheckBox = combat_option_buttons[options[(index - 1 + options.size()) % options.size()]]
		var next: CheckBox = combat_option_buttons[options[(index + 1) % options.size()]]
		check.focus_previous = previous.get_path()
		check.focus_next = next.get_path()
		check.focus_neighbor_left = check.focus_previous
		check.focus_neighbor_right = check.focus_next
		check.focus_neighbor_top = check.focus_previous
		check.focus_neighbor_bottom = check.focus_next
	combat_status_label = _header_label(combat_options_row, "手动战斗", 10, UISkin.MUTED)
	combat_status_label.name = "CombatAutomationStatus"
	combat_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_status_label.custom_minimum_size.x = 0
	combat_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combat_status_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_refresh_combat_controls()

func _request_combat_option(enabled: bool, option: String) -> void:
	if _combat_blocked:
		_refresh_combat_controls()
		return
	combat_option_requested.emit(option, enabled)

func set_combat_automation_status(options: Dictionary, message: String = "", blocked: bool = false) -> void:
	# This snapshot belongs to the controller; setting it never sends a command.
	for option: String in _combat_options:
		_combat_options[option] = bool(options.get(option, false))
	_combat_message = message if not message.is_empty() else "手动战斗"
	_combat_blocked = blocked
	_refresh_combat_controls()

func has_combat_option_focus() -> bool:
	if not is_inside_tree() or not is_visible_in_tree(): return false
	return get_viewport().gui_get_focus_owner() in combat_option_buttons.values()

func _refresh_combat_controls() -> void:
	if not is_instance_valid(combat_status_label): return
	if combat_status_label.text != _combat_message: combat_status_label.text = _combat_message
	if combat_status_label.tooltip_text != _combat_message: combat_status_label.tooltip_text = _combat_message
	if combat_options_row.tooltip_text != _combat_message: combat_options_row.tooltip_text = _combat_message
	for option: String in combat_option_buttons:
		var check: CheckBox = combat_option_buttons[option]
		var enabled: bool = bool(_combat_options.get(option, false))
		if check.button_pressed != enabled: check.set_pressed_no_signal(enabled)
		# The controller separates cancellable save waits from locked transitions.
		if check.disabled != _combat_blocked: check.disabled = _combat_blocked
		# Unchanged snapshots must not allocate styles or invalidate the theme.
		if not check.has_meta("combat_visual_enabled") or bool(check.get_meta("combat_visual_enabled")) != enabled:
			UISkin.apply_button(check, "filter", true, enabled)
			check.add_theme_color_override("font_color", UISkin.AMBER if enabled else UISkin.TEXT)
			check.set_meta("combat_visual_enabled", enabled)
		var hint: String = str(check.get_meta("combat_hint")) + "\n当前：" + _combat_message
		if check.tooltip_text != hint: check.tooltip_text = hint

func _header_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
