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
## Short state per fitted module, kept so the badge can be re-laid-out when the layout
## changes size without a refresh having to rebuild the records.
var _slot_status: Dictionary = {}
var _combat_options: Dictionary = {"fire": false, "orbit": false, "seek": false}
var _combat_message: String = "手动战斗"
var _combat_blocked: bool = false

## Slot geometry. The circle is the slot and the strip under it carries the slot ID,
## which is why the tile is taller than it is wide.
##
## The strip is what the label actually needs, and the number is measured rather than
## reasoned about: a Label is never smaller than its font's line height, and the note
## role's 11 px font measures 17 px. Two earlier guesses (13, then 15) were both short
## for exactly that reason and hung the slot ID past the tile.
##
## Tuned against the worst case rather than a fixture: a battleship fits 17 modules plus
## the engine control, rendered at all four sizes. A full loadout holds one line down to
## 1024 wide at 30 px. At 640x360 the row is 342 px and wraps to two lines, and that is
## what sets the compact circle: two lines of (circle + 17) plus a gap have to fit the
## 76 px the row is given, so the circle is 19.
##
## Two larger circles were tried first and both passed the wrap arithmetic while still
## overflowing the panel, because the row and the panel around it are not the same
## height, and the row's own height moves with the dock's text. Sizing to the arithmetic
## rather than to the measured fit is what made this take three attempts.
const SLOT_CIRCLE: float = 30.0
const SLOT_LABEL: float = 17.0
const SLOT_CIRCLE_COMPACT: float = 19.0
const SLOT_LABEL_COMPACT: float = 17.0

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
			# The slot is a circle and the portrait is clipped to it by the theme's
			# draw_portrait, so there is no TextureRect and no mask texture: the shape
			# lives in one widget and this tile is only the frame around it.
			var slot: UISkin.CircularSlot = UISkin.CircularSlot.new()
			slot.name = "SlotSurface"
			slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			slot.offset_bottom = SLOT_CIRCLE
			button.add_child(slot)
			var surface_ref: WeakRef = weakref(slot)
			button.mouse_entered.connect(func(): _hover_slot(surface_ref, true))
			button.mouse_exited.connect(func(): _hover_slot(surface_ref, false))
			# The slot ID sits under the circle, the state badge over it. They cannot
			# collide, which is what the tile's extra height buys.
			var title: Label = _header_label(button, "", 10, UISkin.TEXT)
			title.name = "SlotTitle"
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			title.offset_top = -SLOT_LABEL
			title.offset_bottom = 0
			var status: Label = _header_label(button, "", 9, UISkin.MUTED)
			status.name = "SlotStatus"
			status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			status.offset_top = 1; status.offset_bottom = 12
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status.clip_text = true
			status.max_lines_visible = 1
			module_labels[id] = {"title": title, "status": status, "icon": slot}
			var ring: UISkin.RingArc = UISkin.RingArc.new()
			ring.name = "ActualCycle"
			ring.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			ring.offset_bottom = SLOT_CIRCLE
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
		# The button is a hit target with no surface: the circle is the slot. An
		# enabled module is a bright rim, a switched-off one a dim rim, and the cycle
		# arc overlays either while it counts down.
		UISkin.apply_slot_hit(button)
		_tighten_slot_surface(button)
		button.tooltip_text = "%s\n%s槽 %d · %s\n循环 %.1f s · 电容 %.0f · 热量 %.0f\n耐久 %.0f · 点击%s设备" % [str(record.title), str(record.get("slot_title", "")), int(record.get("slot_index", 0)) + 1, str(record.get("state_label", "")), float(record.get("cycle_s", 0.0)), float(record.get("energy_eu", 0.0)), float(record.get("heat_hu", 0.0)), float(record.get("durability", 0.0)), "关闭" if bool(record.get("enabled", false)) else "启用"]
		var labels: Dictionary = module_labels[id]
		labels.title.text = "%s%d" % [str(record.get("slot_short", "")), int(record.get("slot_index", 0)) + 1]
		# Only the states a frame cannot express get words. Ready is the absence of
		# a ring; a running cycle, a lock or a shortage still needs to be readable.
		_slot_status[id] = _short_status(record)
		_apply_slot_status(id, labels)
		# A compact state replaces the portrait but never the disc or the rim, and it
		# never overprints the slot ID, which is in its own strip below the circle.
		var slot_surface: UISkin.CircularSlot = labels.icon
		slot_surface.portrait = Portraits.texture("item", str(record.module_id))
		slot_surface.show_portrait = not labels.status.visible
		slot_surface.rim = Color(UISkin.ICE, 0.75) if bool(record.get("enabled", false)) else Color(UISkin.BORDER, UISkin.RING_BACKING)
		slot_surface.queue_redraw()
		# Enabled but not ready: cycling, i.e. momentarily blocked, not selected.
		labels.status.add_theme_color_override("font_color", UISkin.WARN if not bool(record.get("ready", false)) and bool(record.get("enabled", false)) else UISkin.TEXT if bool(record.get("enabled", false)) else UISkin.MUTED)
		var ring: UISkin.RingArc = module_progress[id]
		_apply_slot_geometry(button, labels, ring, _compact)
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
			UISkin.apply_chip(placeholder)
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

## Hover feedback lives on the rim because the slot has no surface to light up.
func _hover_slot(surface_ref: WeakRef, entered: bool) -> void:
	var slot: UISkin.CircularSlot = surface_ref.get_ref() as UISkin.CircularSlot
	if not is_instance_valid(slot): return
	slot.hover = entered
	slot.queue_redraw()

## The state badge is words drawn over the portrait, and at 640x360 the compact circle is
## 19 px wide while two characters at the note size need 22. The ring already says the
## module is cycling, so the words move to the tooltip at that size - which carries the
## full state, in its original wording, at every size.
func _apply_slot_status(id: String, labels: Dictionary) -> void:
	var status: Label = labels.status
	status.text = "" if _compact else str(_slot_status.get(id, ""))
	status.visible = not status.text.is_empty()

## One place decides how big a slot is. refresh() and responsive() both need it and
## used to set the size on their own, which is how a tile can end up sized for one
## layout while it is being drawn for the other.
func _apply_slot_geometry(button: Button, labels: Dictionary, ring: UISkin.RingArc, compact: bool) -> void:
	var circle: float = SLOT_CIRCLE_COMPACT if compact else SLOT_CIRCLE
	var strip: float = SLOT_LABEL_COMPACT if compact else SLOT_LABEL
	button.custom_minimum_size = Vector2(circle, circle + strip)
	button.size_flags_horizontal = Control.SIZE_FILL
	var slot: UISkin.CircularSlot = labels.icon
	slot.compact = compact
	slot.offset_bottom = circle
	slot.queue_redraw()
	var title: Label = labels.title
	title.offset_top = -strip
	title.add_theme_font_size_override("font_size", UISkin.SIZE_NOTE)
	ring.compact = compact
	ring.offset_bottom = circle
	ring.queue_redraw()

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
		check.add_theme_font_size_override("font_size", UISkin.SIZE_NOTE)
		check.custom_minimum_size.y = 24
	engine_button.custom_minimum_size = Vector2(54, 36 if compact else 28)
	for id: String in module_buttons.keys():
		_apply_slot_geometry(module_buttons[id], module_labels[id], module_progress[id], compact)
	for id: String in module_labels.keys():
		var slot_labels: Dictionary = module_labels[id]
		slot_labels.status.add_theme_font_size_override("font_size", UISkin.text_size("note"))
		_apply_slot_status(id, slot_labels)
	# The "empty slots x N" summary is sized by its own text, not by the circle: it is
	# one aggregate standing for many sockets, not a socket.
	for button: Variant in empty_slot_buttons.values():
		button.custom_minimum_size = Vector2(0, SLOT_CIRCLE_COMPACT + SLOT_LABEL_COMPACT if compact else SLOT_CIRCLE + SLOT_LABEL)
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
