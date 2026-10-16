class_name XJWarehousePanel
extends BoxContainer
## Warehouse presentation only. Eligibility and capacities come from Inventory.
signal transfer_requested(kind: String, id: String, quantity: int, destination: String)
signal open_salvage_requested(package_id: String)
const UISkin = preload("res://runtime/ui_theme.gd")
const Interaction = preload("res://runtime/ui/ui_interaction.gd")
var refs: Dictionary = {"ship_rows": [], "station_rows": [], "rows_by_id": {}}
var _quote: Callable
var _quantity_limit: int = 1
var _compact: bool = false
var _has_salvage_actions: bool = false
var _stacked: bool = false
var _shallow: bool = false
var _available_width: float = 0.0

func configure(ship_rows: Array[Dictionary], station_rows: Array[Dictionary], ship_title: String, station_title: String, quantity_limit: int, quote: Callable) -> void:
	name = "WarehousePanel"
	set_meta("warehouse_panel", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UISkin.GAP)
	_quote = quote
	_quantity_limit = quantity_limit
	_has_salvage_actions = (ship_rows + station_rows).any(func(row: Dictionary): return row.kind == "salvage" and not bool(row.remote))
	var ship: Dictionary = _column("ShipWarehouse", "当前舰船货舱", ship_title, "物资 / 持有数量", "所在舱室")
	var station: Dictionary = _column("StationWarehouse", "空间站仓库", station_title, "物资 / 持有数量", "所属空间站")
	refs["ship_scroll"] = ship.scroll
	refs["station_scroll"] = station.scroll
	refs["ship_column"] = ship.column
	refs["station_column"] = station.column
	refs["columns"] = [ship, station]
	for data: Dictionary in ship_rows: refs.ship_rows.append(_append_row(ship.content, data))
	for data: Dictionary in station_rows: refs.station_rows.append(_append_row(station.content, data))
	if ship_rows.is_empty(): _label(ship.content, "当前舰船的货舱和矿舱均为空。", 13, UISkin.MUTED)
	if station_rows.is_empty(): _label(station.content, "各空间站仓库中均没有货物。", 13, UISkin.MUTED)
	elif not bool(station_rows[0].current_station):
		var empty: Label = _label(station.content, "当前空间站仓库为空。", 13, UISkin.MUTED)
		station.content.move_child(empty, 0)
	_set_compact(false)

func fit_height(available: float) -> void:
	fit_view(_available_width if _available_width > 0.0 else size.x, available)

func fit_view(available_width: float, available_height: float) -> void:
	_available_width = available_width
	var normal: Dictionary = _cell_sizes(false)
	var normal_dual: float = 2.0 * (_table_width(normal) + 2.0 * UISkin.GAP + 16.0) + UISkin.GAP
	var compact: bool = available_height < 240.0 or available_width < normal_dual
	var cell: Dictionary = _cell_sizes(compact)
	var pane_min: float = _table_width(cell) + (8.0 if compact else 2.0 * UISkin.GAP) + 16.0
	var stacked: bool = available_width > 0.0 and available_width < 2.0 * pane_min + UISkin.GAP
	if stacked != _stacked:
		_stacked = stacked
		# Native orientation changes retain every node, path, editor and callback.
		vertical = stacked
	set_meta("stacked_panes", stacked)
	# The page owns the vertical budget. Fixed 200/96px minima pushed the top
	# pane outside a 640x360 page even though each individual row fit its table.
	custom_minimum_size.y = maxf(0.0, available_height - 2.0)
	_shallow = false
	_set_compact(compact)
	if stacked and get_combined_minimum_size().y > available_height:
		# Keep both inventory captions and one complete actual row. Only repeated
		# table headings fold in the shallow profile; columns and inputs survive.
		_shallow = true
		for column: Dictionary in refs.get("columns", []): column.header_frame.hide()
		_update_pane_minimums()
	set_meta("shallow_stacked", _shallow)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and is_ancestor_of(focus): _reveal_local_control(focus)

func _table_width(cell: Dictionary) -> float:
	return float(cell.image + cell.name + cell.location + cell.amount + cell.actions + 4 * cell.gap + 2 * cell.margin)

func _set_compact(compact: bool) -> void:
	_compact = compact
	var cell: Dictionary = _cell_sizes(compact)
	for column: Dictionary in refs.get("columns", []):
		var frame: PanelContainer = column.column
		frame.custom_minimum_size.x = 180 if compact else 220
		frame.custom_minimum_size.y = 0
		frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		(frame.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(4 if compact else UISkin.GAP)
		column.content_layout.add_theme_constant_override("separation", 4 if compact else UISkin.GAP)
		column.heading.add_theme_font_size_override("font_size", 14 if compact else 17)
		column.heading.text = str(column.title) + " · " + str(column.subtitle) if _stacked else str(column.title)
		column.heading.tooltip_text = str(column.title) + "\n" + str(column.subtitle)
		column.heading.autowrap_mode = TextServer.AUTOWRAP_OFF if _stacked else TextServer.AUTOWRAP_WORD_SMART
		column.heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if _stacked else TextServer.OVERRUN_NO_TRIMMING
		column.subheading.visible = not _stacked
		column.subheading.add_theme_font_size_override("font_size", 10 if compact else 11)
		column.subheading.max_lines_visible = 1 if compact else 2
		column.subheading.autowrap_mode = TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
		column.subheading.clip_text = compact
		column.subheading.tooltip_text = column.subheading.text
		(column.header_frame.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(int(cell.margin))
		column.header_frame.visible = not _shallow
		column.header.add_theme_constant_override("separation", int(cell.gap))
		for label: Label in [column.inventory_heading, column.location_heading, column.amount_heading, column.action_heading]: label.add_theme_font_size_override("font_size", 10 if compact else 11)
		_size_cell(column.image_heading, float(cell.image))
		_size_cell(column.inventory_heading, float(cell.name), true)
		_size_cell(column.location_heading, float(cell.location))
		_size_cell(column.amount_heading, float(cell.amount))
		_size_cell(column.action_heading, float(cell.actions))
		column.content.add_theme_constant_override("separation", 3 if compact else 5)
	for row: Dictionary in refs.rows_by_id.values():
		(row.row.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(int(cell.margin))
		row.top.add_theme_constant_override("separation", int(cell.gap))
		row.info.add_theme_constant_override("separation", int(cell.gap))
		row.actions.add_theme_constant_override("separation", int(cell.gap))
		row.image.custom_minimum_size = Vector2(float(cell.image), float(cell.image))
		_size_cell(row.names, float(cell.name), true)
		_size_cell(row.location, float(cell.location))
		row.name.add_theme_font_size_override("font_size", 12 if compact else 13)
		row.policy_badge.add_theme_font_size_override("font_size", 10 if compact else 11)
		row.quantity.add_theme_font_size_override("font_size", 10 if compact else 11)
		for label: Label in [row.location, row.description, row.status]: label.add_theme_font_size_override("font_size", 10 if compact else 11)
		if is_instance_valid(row.amount):
			_size_cell(row.amount, float(cell.amount))
			row.action_group.add_theme_constant_override("separation", int(cell.gap))
			_size_cell(row.action_group, float(cell.actions))
			_size_cell(row.button, float(cell.button))
			row.amount.custom_minimum_size.y = 30 if compact else 34
			row.button.custom_minimum_size.y = 30 if compact else 34
			row.amount.add_theme_font_size_override("font_size", 11 if compact else 12)
			row.amount.get_line_edit().add_theme_font_size_override("font_size", 11 if compact else 12)
			row.button.add_theme_font_size_override("font_size", 11 if compact else 12)
			row.amount_heading.add_theme_font_size_override("font_size", 10 if compact else 11)
			if is_instance_valid(row.claim):
				_size_cell(row.claim, float(cell.button))
				row.claim.custom_minimum_size.y = 30 if compact else 34
				row.claim.add_theme_font_size_override("font_size", 10 if compact else 12)
		else:
			_size_cell(row.amount_placeholder, float(cell.amount))
			_size_cell(row.action_placeholder, float(cell.actions))
			for label: Label in [row.amount_placeholder, row.action_placeholder]: label.add_theme_font_size_override("font_size", 10 if compact else 11)
	_update_pane_minimums()

func _update_pane_minimums() -> void:
	for column: Dictionary in refs.get("columns", []):
		var minimum: float = 0.0
		if _stacked:
			var records: Array = refs.ship_rows if column.scroll == refs.ship_scroll else refs.station_rows
			minimum = (records[0].row as Control).get_combined_minimum_size().y if not records.is_empty() else column.content.get_combined_minimum_size().y
			if not _shallow: minimum += column.header_frame.get_combined_minimum_size().y + column.table.get_theme_constant("separation")
		column.scroll.custom_minimum_size.y = minimum

func _cell_sizes(compact: bool) -> Dictionary:
	# Presentation dimensions only. Their measured total chooses the pane
	# orientation; cargo, location and controls retain the same per-row grid.
	var sizes: Dictionary = {"image": 24, "name": 156, "location": 72, "amount": 70, "button": 68, "gap": 4, "margin": 3} if compact else {"image": 32, "name": 184, "location": 86, "amount": 82, "button": 76, "gap": 6, "margin": 5}
	# All rows keep the same operation column when a local package adds a claim.
	sizes["actions"] = int(sizes.button) * (2 if _has_salvage_actions else 1) + (int(sizes.gap) if _has_salvage_actions else 0)
	return sizes

func _size_cell(control: Control, width: float, expand: bool = false) -> void:
	control.custom_minimum_size.x = width
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _column(node_name: String, title: String, subtitle: String, inventory_heading: String, location_heading: String) -> Dictionary:
	var frame: PanelContainer = PanelContainer.new()
	frame.name = node_name
	frame.custom_minimum_size.x = 220
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.0
	frame.add_theme_stylebox_override("panel", UISkin.panel_style(UISkin.GAP))
	add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", UISkin.GAP)
	frame.add_child(column)
	var heading: Label = _label(column, title, 17, UISkin.AMBER)
	var subheading: Label = _label(column, subtitle, 11, UISkin.MUTED)
	subheading.max_lines_visible = 2
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = node_name + "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	column.add_child(scroll)
	var table: VBoxContainer = VBoxContainer.new()
	table.name = node_name + "Table"
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 4)
	scroll.add_child(table)
	var header_frame: PanelContainer = PanelContainer.new()
	header_frame.name = node_name + "Header"
	header_frame.add_theme_stylebox_override("panel", UISkin.table_header(5))
	table.add_child(header_frame)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header_frame.add_child(header)
	var image_heading: Control = Control.new()
	header.add_child(image_heading)
	var inventory_title: Label = _label(header, inventory_heading, 11, UISkin.MUTED)
	var location: Label = _label(header, location_heading, 11, UISkin.MUTED)
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var amount_heading: Label = _label(header, "操作数量", 11, UISkin.MUTED)
	amount_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var action_heading: Label = _label(header, "操作", 11, UISkin.MUTED)
	action_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for label: Label in [inventory_title, location, amount_heading, action_heading]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = label.text
	var content: VBoxContainer = VBoxContainer.new()
	content.name = node_name + "Rows"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	table.add_child(content)
	return {"column": frame, "scroll": scroll, "table": table, "content": content, "content_layout": column, "title": title, "subtitle": subtitle, "heading": heading, "subheading": subheading, "header": header, "header_frame": header_frame, "image_heading": image_heading, "inventory_heading": inventory_title, "location_heading": location, "amount_heading": amount_heading, "action_heading": action_heading}

func _append_row(parent: VBoxContainer, data: Dictionary) -> Dictionary:
	var remote: bool = bool(data.remote)
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "WarehouseRow_" + str(data.id).validate_node_name()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UISkin.table_row(false, 5))
	frame.set_meta("warehouse_row", true)
	for key: String in ["id", "kind", "container_id", "station_id", "current_station", "remote", "destination", "asset_id"]:
		frame.set_meta("row_id" if key == "id" else "row_kind" if key == "kind" else key, data[key])
	frame.set_meta("asset_kind", "generic" if data.kind == "salvage" else "item")
	frame.set_meta("salvage_package", data.kind == "salvage")
	if remote: frame.modulate = UISkin.MUTED
	parent.add_child(frame)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	frame.add_child(content)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	content.add_child(top)
	var info: HBoxContainer = HBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	top.add_child(info)
	var image: TextureRect = TextureRect.new()
	image.texture = data.thumbnail
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(32, 32)
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(image)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 2)
	info.add_child(names)
	var name_line: HBoxContainer = HBoxContainer.new()
	name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_line.add_theme_constant_override("separation", 4)
	names.add_child(name_line)
	var title: Label = _label(name_line, str(data.title), 13, UISkin.TEXT)
	title.name = "WarehouseName"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var policy_badge: Label = _label(name_line, str({"tutorial_protected": "保障", "mission_bound": "绑定", "loan_protected": "借用", "loan_bound": "借用"}.get(str(data.policy_id), "受限")), 11, UISkin.AMBER)
	policy_badge.name = "WarehousePolicyBadge"
	policy_badge.visible = str(data.policy_id) != "normal_owned"
	policy_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	policy_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	policy_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var quantity: Label = _label(name_line, "%d %s" % [int(data.quantity), str(data.unit)], 11, UISkin.ICE)
	quantity.name = "WarehouseQuantity"
	quantity.autowrap_mode = TextServer.AUTOWRAP_OFF
	quantity.size_flags_horizontal = Control.SIZE_SHRINK_END
	quantity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var location: Label = _label(top, "当前站" if bool(data.current_station) else str(data.location).replace("\n", " · "), 11, UISkin.MUTED if remote else UISkin.AMBER)
	location.name = "WarehouseLocation"
	location.custom_minimum_size.x = 70
	location.size_flags_horizontal = Control.SIZE_FILL
	location.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	location.autowrap_mode = TextServer.AUTOWRAP_OFF
	location.clip_text = true
	location.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var details: Label = _label(content, str(data.detail), 11, UISkin.MUTED)
	details.name = "WarehouseDescription"
	# Details and policy remain available to references and tooltips; the table
	# itself has exactly one visible line per asset.
	details.visible = false
	var status: Label = _label(content, str(data.policy), 11, UISkin.MUTED)
	status.name = "WarehouseStatus"
	status.visible = false
	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = "WarehouseActions"
	actions.add_theme_constant_override("separation", 6)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(actions)
	var row: Dictionary = data.duplicate()
	row.merge({"row": frame, "content": content, "top": top, "info": info, "names": names, "name_line": name_line, "image": image, "name": title, "policy_badge": policy_badge, "description": details, "description_full": str(data.description), "quantity": quantity, "held_quantity": int(data.quantity), "location": location, "location_full": str(data.location).replace("\n", " · "), "status": status, "actions": actions, "action_group": null, "amount": null, "button": null, "claim": null}, true)
	refs.rows_by_id[data.id] = row
	if remote:
		status.text = "异地仓库 · 只读，需前往该站搬运"
		var readonly: Label = _label(actions, "只读", 11, UISkin.MUTED)
		readonly.autowrap_mode = TextServer.AUTOWRAP_OFF
		readonly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var visit: Label = _label(actions, "需前往", 11, UISkin.MUTED)
		visit.autowrap_mode = TextServer.AUTOWRAP_OFF
		visit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.amount_placeholder = readonly
		row.action_placeholder = visit
		_refresh_tooltip(row)
		return row
	var amount_heading: Label = _label(actions, "数量", 11, UISkin.MUTED)
	amount_heading.visible = false
	amount_heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	amount_heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	amount_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	var amount: SpinBox = SpinBox.new()
	amount.name = "WarehouseAmount"
	amount.min_value = 1
	amount.max_value = mini(_quantity_limit, int(data.quantity)) if data.kind == "stack" else 1
	amount.step = 1
	amount.value = 1
	amount.editable = data.kind == "stack" and data.policy_id == "normal_owned"
	amount.custom_minimum_size = Vector2(82, 34)
	amount.add_theme_font_size_override("font_size", UISkin.text_size("body"))
	amount.tooltip_text = "本行搬运数量，最多 %d %s" % [int(amount.max_value), str(data.unit)]
	amount.set_meta("warehouse_amount", true)
	amount.set_meta("row_id", data.id)
	var edit: LineEdit = amount.get_line_edit()
	edit.add_theme_font_size_override("font_size", UISkin.text_size("body"))
	edit.add_theme_stylebox_override("normal", UISkin.input_style(false, 4))
	edit.add_theme_stylebox_override("read_only", UISkin.input_style(true, 4))
	actions.add_child(amount)
	for focus_control: Control in [amount, edit]:
		focus_control.focus_entered.connect(_reveal_local_control.bind(focus_control))
		focus_control.set_meta("business_focus_bound", true)
	var button: Button = Button.new()
	button.name = "WarehouseTransfer"
	button.text = "装入货舱" if bool(data.current_station) else "存入本站"
	button.size_flags_horizontal = Control.SIZE_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(76, 34)
	button.add_theme_font_size_override("font_size", UISkin.text_size("body"))
	UISkin.apply_button(button, "default", true)
	button.set_meta("action", {"stack": "move_stack", "item": "move_item", "salvage": "move_salvage"}[str(data.kind)])
	button.set_meta("target", data.id)
	button.set_meta("extra", data.destination)
	button.set_meta("uses_quantity", data.kind == "stack")
	button.set_meta("row_id", data.id)
	var action_group: HBoxContainer = HBoxContainer.new()
	action_group.name = "WarehouseRowOperations"
	action_group.add_theme_constant_override("separation", 6)
	actions.add_child(action_group)
	action_group.add_child(button)
	button.focus_entered.connect(_reveal_local_control.bind(button))
	button.set_meta("business_focus_bound", true)
	row.amount = amount
	row.button = button
	row.amount_heading = amount_heading
	row.action_group = action_group
	if data.kind == "salvage":
		var claim: Button = Button.new()
		claim.name = "WarehouseOpenSalvage"
		claim.text = "领取战利品"
		claim.custom_minimum_size = Vector2(76, 34)
		claim.add_theme_font_size_override("font_size", UISkin.text_size("body"))
		UISkin.apply_button(claim, "primary", true)
		claim.set_meta("action", "open_salvage")
		claim.set_meta("target", data.id)
		claim.set_meta("extra", "")
		claim.set_meta("uses_quantity", false)
		claim.set_meta("row_id", data.id)
		claim.disabled = not bool(get_meta("can_open_salvage", false))
		claim.tooltip_text = str(get_meta("salvage_reason", "需在有仓储服务的当前空间站领取")) if claim.disabled else "物资进入本站仓库，信用点进入钱包。"
		action_group.add_child(claim)
		claim.pressed.connect(_request_salvage.bind(str(data.id), weakref(frame)))
		claim.focus_entered.connect(_reveal_local_control.bind(claim))
		claim.set_meta("business_focus_bound", true)
		row.claim = claim
	Interaction.watch_integer(amount, _update_quote.bind(row))
	button.pressed.connect(func():
		# Commit a typed value even if the player has not pressed Enter first.
		var quantity_value: int = Interaction.integer_input(amount)
		if quantity_value <= 0: _update_quote(row); return
		amount.apply()
		_update_quote(row)
		if not button.disabled: transfer_requested.emit(str(data.kind), str(data.id), quantity_value, str(data.destination)))
	_update_quote(row)
	return row

func _request_salvage(package_id: String, reference: WeakRef) -> void:
	var frame: Control = reference.get_ref() as Control
	if not is_visible_in_tree() or is_queued_for_deletion() or not is_instance_valid(frame) or frame.is_queued_for_deletion() or not frame.is_inside_tree() or not is_ancestor_of(frame) or not refs.rows_by_id.has(package_id): return
	var row: Dictionary = refs.rows_by_id[package_id]
	if row.row != frame or not is_instance_valid(row.claim) or row.claim.is_queued_for_deletion() or row.claim.disabled: return
	open_salvage_requested.emit(package_id)

func _update_quote(row: Dictionary) -> void:
	if not is_instance_valid(row.button) or not _quote.is_valid(): return
	var quantity_value: int = Interaction.integer_input(row.amount)
	var result: Dictionary = _quote.call(str(row.kind), str(row.id), quantity_value, str(row.destination)) if quantity_value > 0 else {"ok": false, "reason": "请输入范围内的整数数量"}
	var reason: String = str(result.get("reason", ""))
	row.status.text = str(row.policy) + (" · " + reason if not reason.is_empty() else "")
	Interaction.action_state(row.button, reason, "将本行的 %d %s转入%s。" % [quantity_value, str(row.unit), "当前舰船货舱" if bool(row.current_station) else "当前空间站仓库"] if quantity_value > 0 else "")
	_refresh_tooltip(row)

func _refresh_tooltip(row: Dictionary) -> void:
	var tooltip: String = "%s · 持有 %d %s\n所在地：%s" % [str(row.title), int(row.held_quantity), str(row.unit), str(row.location_full)]
	for text: String in [str(row.description_full), str(row.status.text)]:
		if not text.is_empty(): tooltip += "\n" + text
	row.row.tooltip_text = tooltip
	row.name.tooltip_text = tooltip
	row.quantity.tooltip_text = tooltip
	row.location.tooltip_text = tooltip

func _reveal_local_control(control: Control) -> void:
	# Reveal the owning inventory and its outer page; the opposite pane is never
	# an ancestor and retains both scroll offsets in stacked mode as well.
	# The SpinBox owns its arrows outside the embedded LineEdit's rectangle.
	# Focus on the editor must reveal the whole quantity control on both axes.
	var target: Control = control.get_parent() as SpinBox if control is LineEdit and control.get_parent() is SpinBox else control
	_reveal_local_control_after_layout.call_deferred(weakref(target))

func _reveal_local_control_after_layout(reference: WeakRef) -> void:
	var control: Control=reference.get_ref() as Control
	if not is_instance_valid(control) or not is_inside_tree() or is_queued_for_deletion() or not is_ancestor_of(control): return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()

func snapshot_view() -> Dictionary:
	var view: Dictionary = {"ship_scroll": refs.ship_scroll.scroll_vertical, "station_scroll": refs.station_scroll.scroll_vertical, "ship_scroll_horizontal": refs.ship_scroll.scroll_horizontal, "station_scroll_horizontal": refs.station_scroll.scroll_horizontal, "amounts": {}, "focus_id": "", "focus_amount": false, "focus_action": ""}
	var focus: Control = get_viewport().gui_get_focus_owner()
	for id: String in refs.rows_by_id:
		var row: Dictionary = refs.rows_by_id[id]
		if not is_instance_valid(row.amount): continue
		view.amounts[id] = int(row.amount.value)
		if focus == row.button or focus == row.amount or focus == row.amount.get_line_edit() or (is_instance_valid(row.claim) and focus == row.claim):
			view.focus_id = id
			view.focus_amount = focus != row.button
			view.focus_action = "open_salvage" if is_instance_valid(row.claim) and focus == row.claim else ""
	return view

func restore_view(view: Dictionary) -> void:
	for id: String in view.get("amounts", {}):
		if not refs.rows_by_id.has(id): continue
		var row: Dictionary = refs.rows_by_id[id]
		if is_instance_valid(row.amount): row.amount.value = clampi(int(view.amounts[id]), 1, int(row.amount.max_value))
	_restore_position.call_deferred(view)

func _restore_position(view: Dictionary) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion(): return
	var id: String = str(view.get("focus_id", ""))
	if refs.rows_by_id.has(id):
		var row: Dictionary = refs.rows_by_id[id]
		if view.get("focus_action", "") == "open_salvage" and is_instance_valid(row.claim) and not row.claim.disabled: row.claim.grab_focus()
		elif bool(view.get("focus_amount", false)) and is_instance_valid(row.amount) and row.amount.editable: row.amount.get_line_edit().grab_focus()
		elif is_instance_valid(row.button) and not row.button.disabled: row.button.grab_focus()
	refs.ship_scroll.set_deferred("scroll_vertical", int(view.get("ship_scroll", 0)))
	refs.station_scroll.set_deferred("scroll_vertical", int(view.get("station_scroll", 0)))
	refs.ship_scroll.set_deferred("scroll_horizontal", int(view.get("ship_scroll_horizontal", 0)))
	refs.station_scroll.set_deferred("scroll_horizontal", int(view.get("station_scroll_horizontal", 0)))

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result
