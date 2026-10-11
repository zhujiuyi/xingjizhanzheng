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
var row: HBoxContainer
var scroll: ScrollContainer
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

func _ready() -> void:
	name = "EquipmentCycles"
	add_theme_stylebox_override("panel", UISkin.hud_panel(4))
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 3)
	add_child(layout)
	header = HBoxContainer.new()
	_header_label(header, "设备循环", 11, UISkin.AMBER)
	summary_label = _header_label(header, "", 10, UISkin.MUTED)
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layout.add_child(header)
	_build_combat_options(layout)
	scroll = ScrollContainer.new()
	scroll.name = "EquipmentScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	scroll.add_child(row)
	engine_button = Button.new()
	engine_button.name = "EngineCycle"
	engine_button.text = "增推"
	engine_button.focus_mode = Control.FOCUS_NONE
	engine_button.custom_minimum_size = Vector2(54, 28)
	engine_button.add_theme_font_size_override("font_size", 11)
	engine_button.add_theme_stylebox_override("normal", UISkin.hud_button(true))
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
			icon.custom_minimum_size = Vector2(20,20)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			labels.add_child(icon)
			var title: Label = _header_label(labels, "", 10, UISkin.TEXT)
			var status: Label = _header_label(labels, "", 10, UISkin.MUTED)
			var cost: Label = _header_label(labels, "", 9, UISkin.MUTED)
			module_labels[id] = {"title": title, "status": status, "cost": cost}
			var progress: ProgressBar = ProgressBar.new()
			progress.name = "ActualCycle"
			progress.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			progress.offset_left = 3; progress.offset_right = -3
			progress.offset_top = -3; progress.offset_bottom = -1
			progress.show_percentage = false
			progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
			progress.add_theme_stylebox_override("fill", UISkin.flat(UISkin.AMBER, UISkin.AMBER, 0))
			button.add_child(progress)
			module_progress[id] = progress
			module_buttons[id] = button
		button.disabled = busy
		var slot_snapshot: Dictionary = record.duplicate()
		slot_snapshot["slot_id"] = str(record.get("slot_id", id))
		slot_snapshot["slot_type"] = int(record.get("slot_type", 0))
		slot_snapshot["slot_index"] = int(record.get("slot_index", 0))
		slot_records.append(slot_snapshot)
		slot_buttons[str(record.get("slot_id", id))] = button
		button.set_pressed_no_signal(bool(record.get("enabled", false)))
		button.add_theme_stylebox_override("normal", UISkin.hud_button(bool(record.get("enabled", false))))
		button.add_theme_stylebox_override("pressed", UISkin.hud_button(bool(record.get("enabled", false))))
		button.add_theme_stylebox_override("hover", UISkin.hud_button(true))
		button.tooltip_text = "%s\n%s槽 %d · %s\n循环 %.1f s · 电容 %.0f · 热量 %.0f\n耐久 %.0f · 点击%s设备" % [str(record.title), str(record.get("slot_title", "")), int(record.get("slot_index", 0)) + 1, str(record.get("state_label", "")), float(record.get("cycle_s", 0.0)), float(record.get("energy_eu", 0.0)), float(record.get("heat_hu", 0.0)), float(record.get("durability", 0.0)), "关闭" if bool(record.get("enabled", false)) else "启用"]
		var labels: Dictionary = module_labels[id]
		labels.title.text = "%s%d · %s" % [str(record.get("slot_short", "")), int(record.get("slot_index", 0)) + 1, str(record.title)]
		labels.status.text = str(record.get("state_label", ""))
		labels.cost.text = "电容 %.0f · 热量 %.0f" % [float(record.get("energy_eu", 0.0)), float(record.get("heat_hu", 0.0))]
		labels.cost.hide()
		labels.status.add_theme_color_override("font_color", UISkin.AMBER if not bool(record.get("ready", false)) and bool(record.get("enabled", false)) else UISkin.TEXT if bool(record.get("enabled", false)) else UISkin.MUTED)
		button.custom_minimum_size = Vector2(68,58) if _compact else Vector2(80,62)
		var progress: ProgressBar = module_progress[id]
		progress.max_value = maxf(float(record.get("cycle_s", 0.0)), 0.001)
		progress.value = float(record.get("cooldown_remaining_s", 0.0))
		progress.visible = float(record.get("cooldown_remaining_s", 0.0)) > 0.0
		row.move_child(button, ids.size())
	for id: String in module_buttons.keys():
		if id not in ids:
			var button: Button = module_buttons[id]
			row.remove_child(button); button.queue_free()
			module_buttons.erase(id); module_labels.erase(id); module_progress.erase(id)
	var empty_ids: Array[String] = []
	for record: Dictionary in resources.get("empty_slots", []):
		var slot_id: String = str(record.slot_id)
		empty_ids.append(slot_id)
		slot_records.append(record)
		var placeholder: Button
		if empty_slot_buttons.has(slot_id): placeholder = empty_slot_buttons[slot_id]
		else:
			placeholder = Button.new()
			placeholder.name = "EmptySlot_" + slot_id.validate_node_name()
			placeholder.focus_mode = Control.FOCUS_NONE
			placeholder.disabled = true
			placeholder.add_theme_stylebox_override("disabled", UISkin.hud_button(false))
			row.add_child(placeholder)
			empty_slot_buttons[slot_id] = placeholder
		placeholder.text = "%s%d · 空槽" % [str(record.slot_short), int(record.slot_index) + 1]
		placeholder.add_theme_font_size_override("font_size", 10)
		placeholder.custom_minimum_size = Vector2(68,58) if _compact else Vector2(80,62)
		placeholder.tooltip_text = "%s槽 %d · 当前未安装设备\n停靠空间站后前往配装页面安装兼容设备。" % [str(record.slot_title), int(record.slot_index) + 1]
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
		labels.status.add_theme_font_size_override("font_size", 9 if compact else 10)
		labels.cost.hide()
	for button: Variant in slot_buttons.values(): button.custom_minimum_size = Vector2(68,58) if compact else Vector2(80,62)

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
		check.add_theme_constant_override("h_separation", 3)
		check.add_theme_stylebox_override("hover", UISkin.hud_button(true))
		check.add_theme_stylebox_override("disabled", UISkin.hud_button(false))
		check.add_theme_stylebox_override("focus", UISkin.focus_style())
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
			check.add_theme_stylebox_override("normal", UISkin.hud_button(enabled))
			check.add_theme_stylebox_override("pressed", UISkin.hud_button(enabled))
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
