class_name XJBusinessList
extends VBoxContainer
## Shared presentation only. The caller owns all quotes, eligibility and actions.
const UISkin = preload("res://runtime/ui_theme.gd")
const COLUMN_WIDTHS: Array[float] = [64.0, 240.0, 46.0, 60.0, 94.0, 110.0, 126.0, 148.0]
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

func configure(title: String = "", price_heading: String = "单价 / 信用点", quantity_heading: String = "数量", use_row_quantities: bool = false) -> void:
	inline_quantities = use_row_quantities
	_ensure_layout()
	heading.text = title
	heading.visible = not title.is_empty()
	var titles: Array[String] = ["图片", "名称 / 描述", "单位", quantity_heading, price_heading, "总价 / 信用点", "状态 / 库存", "操作"]
	for index: int in range(titles.size()):
		var cell: Node = header.get_child(index)
		var label: Label = cell.get_child(0)
		label.text = titles[index]
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
	frame.add_theme_stylebox_override("panel", UISkin.table_header())
	content.add_child(frame)
	header = _columns(frame, "BusinessHeader")
	for index: int in range(COLUMN_WIDTHS.size()):
		var cell: VBoxContainer = _column(header, index)
		var label: Label = _label(cell, "", 12)
		label.add_theme_color_override("font_color", UISkin.MUTED)
		_align(label, index)
	var internal: HScrollBar = horizontal_scroll.get_h_scroll_bar()
	internal.changed.connect(_request_scroll_sync)
	internal.value_changed.connect(func(_value: float): _request_scroll_sync())
	top_scrollbar.value_changed.connect(func(value: float):
		if not _syncing and is_instance_valid(horizontal_scroll): horizontal_scroll.scroll_horizontal = roundi(value))
	horizontal_scroll.resized.connect(_request_scroll_sync)
	resized.connect(_request_scroll_sync)

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
	frame.add_theme_stylebox_override("panel", UISkin.table_row(rows.size() % 2 != 0))
	content.add_child(frame)
	var columns: HBoxContainer = _columns(frame, "BusinessColumns")
	var cells: Array[VBoxContainer] = []
	for index: int in range(COLUMN_WIDTHS.size()): cells.append(_column(columns, index))
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
	var name_label: Label = _label(cells[1], title, 14)
	name_label.name = "BusinessName"
	name_label.add_theme_color_override("font_color", UISkin.TEXT)
	var description_label: Label = _label(cells[1], description, 12)
	description_label.name = "BusinessDescription"
	description_label.add_theme_color_override("font_color", UISkin.MUTED)
	if inline_quantities:
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.tooltip_text = title + "\n" + description
		description_label.hide()
		frame.tooltip_text = title + "\n" + description
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
		for label: Label in value_labels:
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.tooltip_text = label.text
	var actions: VBoxContainer = cells[7]
	actions.name = "BusinessActions"
	actions.child_entered_tree.connect(_prepare_action)
	var row: Dictionary = {"id": id, "row": frame, "image": image, "name": name_label, "description": description_label, "unit": value_labels[0], "quantity": value_labels[1], "unit_price": value_labels[2], "total": value_labels[3], "status": value_labels[4], "actions": actions, "amount": null}
	rows.append(row)
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
	amount.add_theme_font_size_override("font_size", 12)
	amount.tooltip_text = "本行操作数量；与其他货品独立。"
	amount.set_meta("business_amount", true)
	amount.set_meta("row_id", entry.id)
	var edit: LineEdit = amount.get_line_edit()
	edit.add_theme_font_size_override("font_size", 12)
	edit.add_theme_stylebox_override("normal", UISkin.input_style(false, 4))
	edit.add_theme_stylebox_override("read_only", UISkin.input_style(true, 4))
	entry.quantity.get_parent().add_child(amount)
	entry.quantity.hide()
	entry["amount"] = amount
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
	result.custom_minimum_size.x = COLUMN_WIDTHS[index]
	if inline_quantities:
		result.custom_minimum_size.x = [44.0, 240.0, 44.0, 94.0, 90.0, 100.0, 180.0, 96.0][index]
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL if index == 1 else Control.SIZE_FILL
	result.alignment = BoxContainer.ALIGNMENT_CENTER
	result.add_theme_constant_override("separation", 3)
	parent.add_child(result)
	return result

func _label(parent: Node, value: String, font_size: int) -> Label:
	var result: Label = Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.y = font_size + 8
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

func _align(label: Label, index: int) -> void:
	if index in [3, 4, 5]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif index == 2: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
