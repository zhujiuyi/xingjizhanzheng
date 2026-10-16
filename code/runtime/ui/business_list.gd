class_name XJBusinessList
extends VBoxContainer
## Shared presentation only. The caller owns all quotes, eligibility and actions.
const UISkin = preload("res://runtime/ui_theme.gd")
const COLUMN_DEFS: Array[Dictionary] = [
	{"key": "image", "wide": 64.0, "trade": 44.0, "compact": 0.0, "align": HORIZONTAL_ALIGNMENT_LEFT},
	{"key": "name", "wide": 240.0, "trade": 240.0, "compact": 140.0, "align": HORIZONTAL_ALIGNMENT_LEFT},
	{"key": "unit", "wide": 46.0, "trade": 44.0, "compact": 0.0, "align": HORIZONTAL_ALIGNMENT_CENTER},
	{"key": "quantity", "wide": 60.0, "trade": 94.0, "compact": 94.0, "align": HORIZONTAL_ALIGNMENT_RIGHT},
	{"key": "unit_price", "wide": 94.0, "trade": 90.0, "compact": 0.0, "align": HORIZONTAL_ALIGNMENT_RIGHT},
	{"key": "total", "wide": 110.0, "trade": 100.0, "compact": 148.0, "align": HORIZONTAL_ALIGNMENT_RIGHT},
	{"key": "status", "wide": 126.0, "trade": 180.0, "compact": 0.0, "align": HORIZONTAL_ALIGNMENT_LEFT},
	{"key": "actions", "wide": 148.0, "trade": 120.0, "compact": 120.0, "align": HORIZONTAL_ALIGNMENT_LEFT},
]
var rows: Array[Dictionary] = []
var horizontal_scroll: ScrollContainer
var content: VBoxContainer
var header: HBoxContainer
var heading: Label
var scroll_tools: HBoxContainer
var top_scrollbar: HScrollBar
var _syncing: bool = false
var _sync_queued: bool = false
var inline_quantities: bool = false
var compact: bool = false
var mode: String = ""
var selected_id: String = ""
var _profile_queued: bool = false
var _price_heading: String = ""
var _headers: Array[Label] = []
var _compact_price_heading: Label
var _by_id: Dictionary = {}
var _profile_signature: String = ""

func configure(title: String = "", price_heading: String = "单价 / 信用点", quantity_heading: String = "数量", use_row_quantities: bool = false, list_mode: String = "") -> void:
	inline_quantities = use_row_quantities
	mode = list_mode
	_price_heading = price_heading
	_ensure_layout()
	heading.text = title
	heading.visible = not title.is_empty()
	var titles: Array[String] = ["图片", "名称 / 描述", "单位", quantity_heading, price_heading, "总价 / 信用点", "状态 / 库存", "操作"]
	for index: int in range(titles.size()):
		_headers[index].text = titles[index]
	_compact_price_heading.text = price_heading
	_request_profile()
	_request_scroll_sync()

func _ensure_layout() -> void:
	if horizontal_scroll != null: return
	name = "BusinessList"
	set_meta("business_list", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UISkin.GAP)
	heading = _label(self, "", UISkin.SIZE_SECTION)
	UISkin.apply_text_style(heading, "section")
	heading.add_theme_color_override("font_color", UISkin.TEXT)
	scroll_tools = HBoxContainer.new()
	scroll_tools.name = "BusinessScrollTools"
	scroll_tools.add_theme_constant_override("separation", UISkin.GAP)
	add_child(scroll_tools)
	var hint: Label = _label(scroll_tools, "左右滚动查看完整列表", 11)
	hint.add_theme_color_override("font_color", UISkin.MUTED)
	top_scrollbar = HScrollBar.new()
	top_scrollbar.name = "BusinessTopScrollbar"
	top_scrollbar.custom_minimum_size = Vector2(80, 18)
	top_scrollbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_scrollbar.focus_mode = Control.FOCUS_ALL
	top_scrollbar.tooltip_text = "拖动查看图片、报价和操作列；Shift + 滚轮也可左右滚动。Tab可定位下一操作。"
	scroll_tools.add_child(top_scrollbar)
	horizontal_scroll = ScrollContainer.new()
	horizontal_scroll.name = "BusinessHorizontalScroll"
	horizontal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	horizontal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	horizontal_scroll.follow_focus = true
	add_child(horizontal_scroll)
	content = VBoxContainer.new()
	content.name = "BusinessRows"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 2)
	horizontal_scroll.add_child(content)
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "BusinessHeaderFrame"
	frame.add_theme_stylebox_override("panel", UISkin.table_header(4))
	content.add_child(frame)
	header = _columns(frame, "BusinessHeader")
	for index: int in range(COLUMN_DEFS.size()):
		var cell: VBoxContainer = _column(header, index)
		var label: Label = _label(cell, "", UISkin.text_size("note"))
		label.add_theme_color_override("font_color", UISkin.MUTED)
		_align(label, index)
		_headers.append(label)
	_compact_price_heading = _label(header.get_child(5), "", UISkin.SIZE_NOTE)
	_compact_price_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_compact_price_heading.hide()
	header.get_child(5).move_child(_compact_price_heading, 0)
	var internal: HScrollBar = horizontal_scroll.get_h_scroll_bar()
	internal.changed.connect(_request_scroll_sync)
	internal.value_changed.connect(func(_value: float): _request_scroll_sync())
	top_scrollbar.value_changed.connect(func(value: float):
		if not _syncing and is_instance_valid(horizontal_scroll): horizontal_scroll.scroll_horizontal = roundi(value))
	horizontal_scroll.resized.connect(_request_scroll_sync)
	resized.connect(_request_scroll_sync)
	horizontal_scroll.resized.connect(_request_profile)

func add_section(title: String) -> void:
	_ensure_layout()
	var label: Label = _label(content, title, UISkin.SIZE_BODY)
	label.name = "BusinessSection"
	UISkin.apply_text_style(label, "subhead")
	label.add_theme_color_override("font_color", UISkin.TEXT)
	label.custom_minimum_size.y = 28
	label.set_meta("business_section", title)

func append_row(id: String, thumbnail: Texture2D, title: String, description: String, unit: String, quantity: String, unit_price: String, total: String, status: String) -> Dictionary:
	_ensure_layout()
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "BusinessRow_" + id.validate_node_name()
	frame.set_meta("business_row", true)
	frame.set_meta("row_id", id)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UISkin.table_row(rows.size() % 2 != 0, 4))
	content.add_child(frame)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", UISkin.GAP)
	frame.add_child(layout)
	var columns: HBoxContainer = _columns(layout, "BusinessColumns")
	var cells: Array[VBoxContainer] = []
	for index: int in range(COLUMN_DEFS.size()): cells.append(_column(columns, index))
	var image: TextureRect = TextureRect.new()
	image.name = "BusinessImage"
	image.texture = thumbnail
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(64, 64)
	if inline_quantities: image.custom_minimum_size = Vector2(40, 40)
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cells[0].add_child(image)
	# The literal here used to say 14 and the style call below immediately replaced it
	# with the subhead role's 13, so the two disagreed about a size neither was using.
	var name_label: Label = _label(cells[1], title, UISkin.text_size("subhead"))
	name_label.name = "BusinessName"
	UISkin.apply_text_style(name_label, "subhead")
	name_label.custom_minimum_size.y = ceilf(name_label.get_theme_font("font").get_height(UISkin.SIZE_BODY))
	name_label.add_theme_color_override("font_color", UISkin.TEXT)
	var description_label: Label = _label(cells[1], description, UISkin.text_size("note"))
	description_label.name = "BusinessDescription"
	description_label.add_theme_color_override("font_color", UISkin.MUTED)
	if inline_quantities:
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.tooltip_text = title + "\n" + description
		description_label.hide()
		frame.tooltip_text = title + "\n" + description
	var name_facts: HBoxContainer = HBoxContainer.new()
	name_facts.name = "BusinessNameFacts"
	name_facts.add_theme_constant_override("separation", UISkin.GAP)
	cells[1].add_child(name_facts)
	name_facts.hide()
	var values: Array[String] = [unit, quantity, unit_price, total, status]
	var value_labels: Array[Label] = []
	for index: int in range(values.size()):
		var label: Label = _label(cells[index + 2], values[index], 13)
		_align(label, index + 2)
		value_labels.append(label)
	value_labels[0].name = "BusinessUnit"
	value_labels[1].name = "BusinessQuantity"
	value_labels[2].name = "BusinessUnitPrice"
	value_labels[3].name = "BusinessTotal"
	# The total is a number in a right-aligned column; the header already names it.
	value_labels[3].add_theme_color_override("font_color", UISkin.TEXT)
	value_labels[4].name = "BusinessStatus"
	value_labels[4].add_theme_color_override("font_color", UISkin.MUTED)
	if inline_quantities:
		for index: int in range(value_labels.size()):
			var label: Label = value_labels[index]
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			# Monetary values are never abbreviated or ellipsised.
			label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if index in [2, 3] else TextServer.OVERRUN_TRIM_ELLIPSIS
			label.tooltip_text = label.text
	var actions: HFlowContainer = HFlowContainer.new()
	actions.name = "BusinessActions"
	actions.add_theme_constant_override("h_separation", UISkin.GAP)
	actions.add_theme_constant_override("v_separation", 4)
	cells[7].add_child(actions)
	actions.child_entered_tree.connect(_prepare_action)
	var details: VBoxContainer = VBoxContainer.new()
	details.name = "BusinessDetails"
	details.add_theme_constant_override("separation", 4)
	layout.add_child(details)
	details.hide()
	var detail_title: Label = _label(details, title, UISkin.SIZE_BODY)
	detail_title.name = "BusinessDetailTitle"
	detail_title.add_theme_color_override("font_color", UISkin.TEXT)
	if inline_quantities:
		description_label.reparent(details)
		description_label.show()
	var full_status: Label = _label(details, status, UISkin.SIZE_NOTE)
	full_status.add_theme_color_override("font_color", UISkin.MUTED)
	var row: Dictionary = {"id": id, "row": frame, "columns": columns, "cells": cells, "image": image, "name": name_label, "description": description_label, "unit": value_labels[0], "quantity": value_labels[1], "unit_price": value_labels[2], "total": value_labels[3], "status": value_labels[4], "actions": actions, "amount": null, "name_facts": name_facts, "details": details, "full_status": full_status}
	rows.append(row)
	_by_id[id] = row
	frame.focus_mode = Control.FOCUS_ALL
	frame.focus_entered.connect(_reveal_action.bind(frame))
	frame.focus_entered.connect(_paint_row.bind(row))
	frame.focus_exited.connect(_paint_row.bind(row))
	frame.set_meta("business_focus_bound", true)
	frame.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_toggle_details(id); frame.accept_event()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
			_toggle_details(id); frame.accept_event())
	_request_profile()
	_request_scroll_sync()
	return row

func enable_row_quantity(entry: Dictionary, maximum: int, value: int = 1, editable: bool = true) -> SpinBox:
	var amount: SpinBox = SpinBox.new()
	amount.name = "BusinessAmount"
	amount.min_value = 1
	amount.max_value = maxi(1, maximum)
	amount.step = 1
	amount.value = clampi(value, 1, int(amount.max_value))
	amount.editable = editable
	amount.custom_minimum_size = Vector2(94, 32)
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	amount.add_theme_font_size_override("font_size", UISkin.text_size("body"))
	amount.tooltip_text = "本行操作数量；与其他货品独立。"
	amount.set_meta("business_amount", true)
	amount.set_meta("row_id", entry.id)
	var edit: LineEdit = amount.get_line_edit()
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edit.add_theme_font_size_override("font_size", UISkin.text_size("body"))
	edit.add_theme_stylebox_override("normal", UISkin.input_style(false, 4))
	edit.add_theme_stylebox_override("read_only", UISkin.input_style(true, 4))
	entry.quantity.get_parent().add_child(amount)
	entry.quantity.hide()
	entry["amount"] = amount
	_request_profile()
	for control: Control in [amount, edit]:
		control.focus_entered.connect(_reveal_action.bind(control))
		control.set_meta("business_focus_bound", true)
	return amount

func _columns(parent: Node, node_name: String) -> HBoxContainer:
	var result: HBoxContainer = HBoxContainer.new()
	result.name = node_name
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("separation", UISkin.GAP)
	parent.add_child(result)
	return result

func _column(parent: Node, index: int) -> VBoxContainer:
	var result: VBoxContainer = VBoxContainer.new()
	result.name = "Column%d" % index
	result.custom_minimum_size.x = float(COLUMN_DEFS[index].trade if inline_quantities else COLUMN_DEFS[index].wide)
	result.set_meta("column_key", COLUMN_DEFS[index].key)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL if index == 1 else Control.SIZE_FILL
	result.alignment = BoxContainer.ALIGNMENT_CENTER
	result.add_theme_constant_override("separation", 3)
	parent.add_child(result)
	return result

func _label(parent: Node, value: String, font_size: int) -> Label:
	var result: Label = Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	result.custom_minimum_size.y = ceilf(result.get_theme_font("font").get_height(font_size))
	return result

func _align(label: Label, index: int) -> void:
	label.horizontal_alignment = int(COLUMN_DEFS[index].align)

func present_status(row_id: String, short_status: String, full_status: String) -> void:
	if not _by_id.has(row_id): return
	var entry: Dictionary = _by_id[row_id]
	entry.status.text = short_status
	entry.status.tooltip_text = full_status
	entry.full_status.text = full_status
	entry.row.set_meta("status_short", short_status)
	entry.row.set_meta("status_full", full_status)
	var primary: Button = null
	for child: Node in entry.actions.get_children():
		if child is Button: primary = child as Button; break
	entry.status.add_theme_color_override("font_color", UISkin.WARN if primary != null and primary.disabled else UISkin.MUTED)
	var complete: String = str(entry.name.text) + "\n" + str(entry.description.text)
	if not full_status.is_empty(): complete += "\n" + full_status
	entry.row.tooltip_text = complete
	entry.name.tooltip_text = complete
	_request_profile()

func _toggle_details(id: String) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree() or not _by_id.has(id): return
	selected_id = "" if selected_id == id else id
	for entry: Dictionary in rows:
		var open: bool = str(entry.id) == selected_id
		entry.details.visible = open
		entry.row.set_meta("details_open", open)
		_paint_row(entry)
	_request_scroll_sync()

func _paint_row(entry: Dictionary) -> void:
	var surface: StyleBoxFlat = UISkin.table_row(rows.find(entry) % 2 != 0, 4)
	if str(entry.id) == selected_id or entry.row.has_focus():
		surface.border_width_left = 2
		surface.border_color = UISkin.AMBER if str(entry.id) == selected_id else UISkin.ICE
	entry.row.add_theme_stylebox_override("panel", surface)

func _request_profile() -> void:
	if _profile_queued or not is_inside_tree() or is_queued_for_deletion(): return
	_profile_queued = true
	_apply_profile.call_deferred()

func _text_width(label: Label, font_size: int) -> float:
	return ceilf(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 4.0

func _font_role(label: Label, role: String) -> void:
	UISkin.apply_text_style(label, role)
	label.custom_minimum_size.y = ceilf(label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")))

func _apply_profile() -> void:
	_profile_queued = false
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(horizontal_scroll): return
	var widths: Array[float] = []
	for definition: Dictionary in COLUMN_DEFS: widths.append(float(definition.trade if inline_quantities else definition.wide))
	_headers[5].text = "实收总额 / 信用点" if mode == "sell" else "服务费合计 / 信用点" if mode in ["manufacture", "recycle"] else "总价 / 信用点"
	for index: int in range(_headers.size()): widths[index] = maxf(widths[index], _text_width(_headers[index], UISkin.SIZE_BODY if index == 5 else 12))
	var compact_money: float = 148.0
	for entry: Dictionary in rows:
		widths[4] = maxf(widths[4], _text_width(entry.unit_price, UISkin.SIZE_DATA))
		widths[5] = maxf(widths[5], _text_width(entry.total, UISkin.SIZE_DATA))
		compact_money = maxf(compact_money, maxf(_text_width(entry.unit_price, UISkin.SIZE_NOTE), _text_width(entry.total, UISkin.SIZE_DATA)))
		if is_instance_valid(entry.amount): widths[3] = maxf(widths[3], entry.amount.get_combined_minimum_size().x)
	var needed: float = 8.0 + UISkin.GAP * (COLUMN_DEFS.size() - 1)
	for width: float in widths: needed += width
	var available: float = horizontal_scroll.size.x
	compact = inline_quantities and available > 0.0 and available + 1.0 < needed
	heading.visible = not heading.text.is_empty() and not compact
	set_meta("compact_columns", compact)
	set_meta("column_profile", "compact" if compact else "full")
	if compact:
		for index: int in range(COLUMN_DEFS.size()): widths[index] = float(COLUMN_DEFS[index].compact)
		widths[5] = compact_money
		for entry: Dictionary in rows:
			if is_instance_valid(entry.amount): widths[3] = maxf(widths[3], entry.amount.get_combined_minimum_size().x)
	var signature: String = str(compact) + ":" + str(widths) + ":" + str(rows.size()) + ":" + mode
	if signature == _profile_signature:
		_request_scroll_sync()
		return
	_profile_signature = signature
	_compact_price_heading.visible = compact
	_font_role(_compact_price_heading, "note")
	_compact_price_heading.text = _price_heading
	_font_role(_headers[5], "note" if compact else "body")
	header.get_child(5).add_theme_constant_override("separation", 0 if compact else 3)
	for index: int in range(COLUMN_DEFS.size()):
		var cell: Control = header.get_child(index) as Control
		cell.visible = not compact or float(COLUMN_DEFS[index].compact) > 0.0
		cell.custom_minimum_size.x = widths[index]
	for entry: Dictionary in rows:
		for index: int in range(COLUMN_DEFS.size()):
			entry.cells[index].visible = not compact or float(COLUMN_DEFS[index].compact) > 0.0
			entry.cells[index].custom_minimum_size.x = widths[index]
		entry.name_facts.visible = compact
		var money_parent: Node = entry.cells[5] if compact else entry.cells[4]
		if entry.unit_price.get_parent() != money_parent: entry.unit_price.reparent(money_parent)
		if compact: money_parent.move_child(entry.unit_price, 0)
		entry.cells[5].add_theme_constant_override("separation", 0 if compact else 3)
		_font_role(entry.unit_price, "note" if compact else "data")
		_font_role(entry.total, "data")
		entry.unit_price.add_theme_color_override("font_color", UISkin.MUTED if compact else UISkin.TEXT)
		for field: String in ["unit", "status"]:
			var destination: Node = entry.name_facts if compact else entry.cells[2 if field == "unit" else 6]
			if entry[field].get_parent() != destination: entry[field].reparent(destination)
			_font_role(entry[field], "note" if compact else "body")
		entry.unit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
		entry.unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
		entry.status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_request_scroll_sync()

func _prepare_action(node: Node) -> void:
	if not node is Button: return
	var button: Button = node
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Shrink-to-content actions must measure the complete caption, not a
	# zero-width wrapped label that turns the whole mission row into a column.
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size.x = 0
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 34)
	if inline_quantities:
		button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 13)
	UISkin.apply_button(button, "default", true)
	button.focus_entered.connect(_reveal_action.bind(button))
	button.set_meta("business_focus_bound", true)

func _reveal_action(candidate: Variant) -> void:
	if not is_instance_valid(candidate) or not candidate is Control: return
	var control: Control = candidate
	if control is LineEdit and control.get_parent() is SpinBox: control = control.get_parent()
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()

func _request_scroll_sync() -> void:
	if _sync_queued or not is_inside_tree() or is_queued_for_deletion(): return
	_sync_queued = true
	_sync_scrollbar.call_deferred()

func _sync_scrollbar() -> void:
	_sync_queued = false
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(horizontal_scroll): return
	var internal: HScrollBar = horizontal_scroll.get_h_scroll_bar()
	_syncing = true
	top_scrollbar.min_value = internal.min_value
	top_scrollbar.max_value = internal.max_value
	top_scrollbar.page = internal.page
	top_scrollbar.step = internal.step
	top_scrollbar.set_value_no_signal(internal.value)
	scroll_tools.visible = internal.max_value - internal.min_value > internal.page + 1.0
	_syncing = false
