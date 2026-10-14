extends VBoxContainer
## Non-trading lists show a compact summary and one selected item's details.
const UISkin = preload("res://runtime/ui_theme.gd")
signal selection_changed(id: String)
var rows: Array[Dictionary] = []
var selected_id: String = ""
var preferred_id: String = ""
var context_valid: Callable

func configure(title: String = "", _price_heading: String = "", _quantity_heading: String = "", _quantities: bool = false) -> void:
	name = "InfoList"
	set_meta("info_list", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UISkin.GAP)
	preferred_id = selected_id
	if not title.is_empty():
		var heading: Label = _label(self, title, 16)
		heading.add_theme_color_override("font_color", UISkin.AMBER)

func add_section(title: String) -> void:
	var heading: Label = _label(self, title, 13)
	heading.add_theme_color_override("font_color", UISkin.MUTED)

func append_row(id: String, thumbnail: Texture2D, title: String, description: String, unit: String, quantity: String, unit_price: String, total: String, status: String) -> Dictionary:
	var frame := PanelContainer.new()
	frame.name = "InfoRow_" + id.validate_node_name()
	frame.set_meta("row_id", id)
	frame.set_meta("business_row", true)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UISkin.table_row(rows.size() % 2 != 0))
	add_child(frame)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", UISkin.GAP)
	frame.add_child(layout)
	var summary := HBoxContainer.new()
	summary.name = "InfoSummary"
	summary.add_theme_constant_override("separation", UISkin.GAP)
	layout.add_child(summary)
	var image := TextureRect.new()
	image.texture = thumbnail
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(40, 40)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(image)
	var name_label: Label = _label(summary, title, 14)
	name_label.name = "InfoName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.max_lines_visible = 2
	name_label.tooltip_text = title
	var status_label: Label = _label(summary, status, 12)
	status_label.name = "InfoStatus"
	status_label.custom_minimum_size.x = 120
	status_label.size_flags_horizontal = Control.SIZE_FILL
	status_label.max_lines_visible = 2
	status_label.tooltip_text = status
	status_label.add_theme_color_override("font_color", UISkin.MUTED)
	var toggle := Button.new()
	toggle.name = "InfoSelect_" + id.validate_node_name()
	toggle.text = "详情"
	toggle.custom_minimum_size = Vector2(64, 30)
	toggle.toggle_mode = true
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UISkin.apply_button(toggle, "secondary", true)
	summary.add_child(toggle)
	var selector_ref: WeakRef = weakref(toggle)
	toggle.pressed.connect(func():
		var selector: Button = selector_ref.get_ref() as Button
		if not is_instance_valid(selector) or selector.is_queued_for_deletion() or not selector.is_visible_in_tree(): return
		if context_valid.is_valid() and not context_valid.call(): return
		select_row(id))
	var details := VBoxContainer.new()
	details.name = "InfoDetails"
	details.add_theme_constant_override("separation", UISkin.GAP)
	layout.add_child(details)
	var description_label: Label = _label(details, description, 13)
	description_label.name = "InfoDescription"
	description_label.visible = not description.is_empty()
	description_label.add_theme_color_override("font_color", UISkin.MUTED)
	var facts := HFlowContainer.new()
	facts.name = "InfoFacts"
	facts.add_theme_constant_override("h_separation", UISkin.SECTION_GAP)
	details.add_child(facts)
	var values: Array[Label] = []
	for value: String in [unit, quantity, unit_price, total]:
		var item: Label = _label(facts, value, 13)
		item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Flow children with wrapped labels otherwise have a one-glyph minimum.
		var text_width: float = item.get_theme_font("font").get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		item.custom_minimum_size.x = clampf(ceilf(text_width) + 2.0, 80.0, 320.0)
		item.visible = value not in ["", "—", "1", "份", "艘", "槽", "件", "包"]
		values.append(item)
	var actions := HFlowContainer.new()
	actions.name = "InfoActions"
	actions.add_theme_constant_override("h_separation", UISkin.GAP)
	actions.add_theme_constant_override("v_separation", UISkin.GAP)
	details.add_child(actions)
	var row: Dictionary = {"id": id, "row": frame, "image": image, "name": name_label, "description": description_label, "unit": values[0], "quantity": values[1], "unit_price": values[2], "total": values[3], "status": status_label, "actions": actions, "amount": null, "details": details, "selector": toggle}
	rows.append(row)
	details.hide()
	if rows.size() == 1 or id == preferred_id: select_row(id)
	return row

func select_row(id: String) -> void:
	var found: bool = false
	for row: Dictionary in rows:
		if str(row.id) == id: found = true; break
	if not found: return
	selected_id = id
	for row: Dictionary in rows:
		var selected: bool = str(row.id) == id
		row.details.visible = selected
		row.row.set_meta("details_open", selected)
		row.selector.set_pressed_no_signal(selected)
		row.selector.text = "当前" if selected else "详情"
		row.name.add_theme_color_override("font_color", UISkin.AMBER if selected else UISkin.TEXT)
	selection_changed.emit(id)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
