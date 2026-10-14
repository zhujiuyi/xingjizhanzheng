class_name XJOverviewPanel
extends PanelContainer
## Presentation adapter: targets and command eligibility are supplied by the host.
signal selected(id: String)
signal command(action: String, id: String)
signal support_requested(item_id: String,target_id: String,stop: bool)
const UISkin = preload("res://runtime/ui_theme.gd")
const ResourceStatus = preload("res://runtime/resource_status.gd")
const DISTANCE_COLUMN_WIDTH: int = 56
const TYPE_COLUMN_WIDTH: int = 44
const ROW_INSET: int = 4
const COLUMN_GAP: int = 4
var filter_mode: String = "all"
var sort_key: String = "distance"
var sort_ascending: bool = true
var entry_rows: Array[Dictionary] = []
var filtered_ids: Array[String] = []
var selected_id: String = ""
var filter_buttons: Dictionary = {}
var sort_buttons: Dictionary = {}
var sort_header_inset: MarginContainer
var target_buttons: Dictionary = {}
var action_buttons: Dictionary = {}
var support_box: VBoxContainer
var support_buttons: Dictionary = {}
var support_records: Dictionary = {}
var support_status: Label
var action_grid: GridContainer
var more_actions: Button
var actions_expanded: bool = false
var eligible_actions: Dictionary = {}
var selected_kind: String = ""
var selected_friendly: bool = false
var target_list: VBoxContainer
var target_scroll: ScrollContainer
var body_scroll: ScrollContainer
var content: VBoxContainer
var overview_content: VBoxContainer
var selection_card: PanelContainer
var selected_title: Label
var selected_distance: Label
var status_label: Label
var resource_detail: VBoxContainer
var resource_label: Label
var resource_fraction: Label
var resource_bar: ProgressBar
var count_label: Label
var interaction_button: Button
var interaction_label: Label
var npc_detail: VBoxContainer
var npc_title: Label
var npc_bars: Array[Dictionary] = []
var _compact: bool = false
var _last_selection_id: String = ""
var _available_height: float = -1.0
var _layout_queued: bool = false

func _ready() -> void:
	name = "TargetModule"
	add_theme_stylebox_override("panel", UISkin.hud_panel(UISkin.GAP))
	body_scroll = ScrollContainer.new()
	body_scroll.name = "OverviewBodyScroll"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", UISkin.GAP)
	body_scroll.add_child(content)
	overview_content = VBoxContainer.new()
	overview_content.add_theme_constant_override("separation", 4)
	content.add_child(overview_content)
	var heading: HBoxContainer = HBoxContainer.new()
	overview_content.add_child(heading)
	var overview_heading: Label = _label(heading, "目标总览", UISkin.SIZE_NOTE, UISkin.TEXT)
	overview_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.apply_text_style(overview_heading, "subhead")
	count_label = _label(heading, "", 10, UISkin.MUTED)
	var filters: HBoxContainer = HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	overview_content.add_child(filters)
	for key: String in ["all", "combat", "navigation"]:
		var button: Button = _button(filters, {"all": "全部", "combat": "战斗", "navigation": "导航"}[key])
		button.name = "OverviewFilter_" + key
		button.pressed.connect(func(): filter_mode = key; _refresh_rows())
		filter_buttons[key] = button
	sort_header_inset = MarginContainer.new()
	sort_header_inset.name = "OverviewColumnHeaders"
	sort_header_inset.add_theme_constant_override("margin_left", ROW_INSET)
	sort_header_inset.add_theme_constant_override("margin_right", ROW_INSET)
	overview_content.add_child(sort_header_inset)
	var headers: HBoxContainer = HBoxContainer.new()
	headers.add_theme_constant_override("separation", COLUMN_GAP)
	sort_header_inset.add_child(headers)
	for key: String in ["distance", "name", "type"]:
		var button: Button = _button(headers, {"distance": "距离", "name": "名称", "type": "类型"}[key])
		button.name = "OverviewSort_" + key
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT if key == "distance" else HORIZONTAL_ALIGNMENT_LEFT
		if key != "name":
			button.size_flags_horizontal = Control.SIZE_FILL
			button.custom_minimum_size.x = DISTANCE_COLUMN_WIDTH if key == "distance" else TYPE_COLUMN_WIDTH
		button.pressed.connect(func():
			if sort_key == key: sort_ascending = not sort_ascending
			else: sort_key = key; sort_ascending = true
			_refresh_rows())
		sort_buttons[key] = button
	target_scroll = ScrollContainer.new()
	target_scroll.name = "TargetScroll"
	target_scroll.custom_minimum_size.y = 154
	target_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overview_content.add_child(target_scroll)
	target_list = VBoxContainer.new()
	target_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_list.add_theme_constant_override("separation", 4)
	target_scroll.add_child(target_list)
	target_list.resized.connect(_sync_column_headers)
	selection_card = PanelContainer.new()
	selection_card.name = "SelectedTargetCard"
	selection_card.add_theme_stylebox_override("panel", UISkin.hud_panel(UISkin.GAP))
	content.add_child(selection_card)
	var details: VBoxContainer = VBoxContainer.new()
	details.name = "SelectedTargetDetails"
	details.add_theme_constant_override("separation", 4)
	selection_card.add_child(details)
	var selected_heading: Label = _label(details, "选中目标", UISkin.SIZE_NOTE, UISkin.TEXT)
	UISkin.apply_text_style(selected_heading, "subhead")
	selected_title = _label(details, "尚未选择目标", 14, UISkin.TEXT)
	selected_distance = _label(details, "左键选目标 · Tab切换", 11, UISkin.MUTED)
	resource_detail = VBoxContainer.new()
	resource_detail.name = "SelectedResourceDetails"
	resource_detail.add_theme_constant_override("separation", 4)
	details.add_child(resource_detail)
	resource_label = _label(resource_detail, "", 11, UISkin.TEXT)
	resource_label.name = "ResourceReserveSummary"
	resource_label.mouse_filter = Control.MOUSE_FILTER_PASS
	resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wrapped labels must contribute their font/line height to the VBox. With
	# clip_text enabled their minimum height is 1px, hiding the actual readout.
	resource_label.clip_text = false
	resource_label.max_lines_visible = 3
	resource_fraction = _label(resource_detail, "", 10, UISkin.MUTED)
	resource_fraction.name = "ResourceReservePercentage"
	resource_bar = ProgressBar.new()
	resource_bar.name = "ResourceReserveBar"
	resource_bar.show_percentage = false
	resource_bar.custom_minimum_size.y = 4
	resource_bar.add_theme_stylebox_override("fill", UISkin.flat(UISkin.ICE, UISkin.ICE, 0))
	resource_detail.add_child(resource_bar)
	resource_detail.hide()
	status_label = _label(details, "", UISkin.SIZE_NOTE, UISkin.ICE)
	for readout: Label in [selected_title, selected_distance, status_label]: readout.mouse_filter = Control.MOUSE_FILTER_PASS
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.clip_text = false
	status_label.max_lines_visible = 2
	action_grid = GridContainer.new()
	action_grid.columns = 3
	action_grid.add_theme_constant_override("h_separation", 4)
	action_grid.add_theme_constant_override("v_separation", 4)
	details.add_child(action_grid)
	for key: String in ["nav_warp", "nav_approach", "nav_orbit", "nav_stop", "nav_dock", "combat_engage", "combat_toggle"]:
		var button: Button = _button(action_grid, {"nav_warp": "跃迁", "nav_approach": "接近", "nav_orbit": "环绕", "nav_stop": "停止", "nav_dock": "停靠", "combat_engage": "交战", "combat_toggle": "自动开火"}[key])
		button.name = "SelectedAction_" + key
		button.pressed.connect(func(): command.emit(key, selected_id))
		button.hide()
		action_buttons[key] = button
	more_actions = _button(details, "更多操作")
	more_actions.name = "SelectedMoreActions"
	more_actions.pressed.connect(func():
		actions_expanded = not actions_expanded
		_layout_actions())
	support_box = VBoxContainer.new()
	support_box.name = "FriendlySupportControls"
	details.add_child(support_box)
	var support_actions: HBoxContainer = HBoxContainer.new()
	support_actions.name = "SupportActions"
	support_box.add_child(support_actions)
	support_status = _label(support_box,"",10,UISkin.MUTED)
	support_box.hide()
	npc_detail = VBoxContainer.new()
	npc_detail.add_theme_constant_override("separation", 4)
	details.add_child(npc_detail)
	npc_title = _label(npc_detail, "", 11, UISkin.MUTED)
	npc_title.hide() # The selected-card title already identifies this same vessel.
	var npc_layers: Array[String] = ["护盾", "装甲", "结构"]
	for layer_index: int in npc_layers.size():
		var layer_name: String = npc_layers[layer_index]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		npc_detail.add_child(row)
		var label: Label = _label(row, layer_name, 10, UISkin.MUTED)
		label.custom_minimum_size.x = 70
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 4
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Same grey-blue ramp as the player instrument, so shield/armour/structure
		# read as one family wherever they appear.
		var layer_color: Color = UISkin.LAYER_SERIES[layer_index]
		bar.add_theme_stylebox_override("fill", UISkin.flat(layer_color, layer_color, 0))
		row.add_child(bar)
		npc_bars.append({"label": label, "bar": bar, "name": layer_name})
	npc_detail.hide()
	interaction_button = _button(details, "")
	interaction_button.name = "ContextInteraction"
	interaction_button.pressed.connect(func(): command.emit("context_interact", selected_id))
	interaction_label = _label(details, "", 10, UISkin.MUTED)
	interaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_label.clip_text = false
	interaction_label.mouse_filter = Control.MOUSE_FILTER_PASS
	interaction_label.max_lines_visible = 2
	interaction_button.hide()
	interaction_label.hide()
	selection_card.minimum_size_changed.connect(_queue_list_layout)
	_refresh_rows()

func set_entries(rows: Array[Dictionary], id: String) -> void:
	entry_rows = rows
	selected_id = id
	_refresh_rows()

func set_selection(details: Dictionary, navigation: Dictionary, busy: bool = false) -> void:
	selected_id = str(details.get("id", ""))
	if selected_id != _last_selection_id: actions_expanded = false
	if _compact and selected_id != _last_selection_id: body_scroll.set_deferred("scroll_vertical", 0)
	_last_selection_id = selected_id
	var kind: String = str(details.get("kind", ""))
	selected_kind = kind
	selected_friendly = bool(details.get("friendly",false))
	selected_title.text = str(details.get("title", "尚未选择目标"))
	selected_title.tooltip_text = selected_title.text
	selected_distance.text = ("%s · %s" % [str(details.get("type_title", "目标")), format_distance(float(details.get("distance_m", 0.0)))]) + (" · 航向参考" if bool(details.get("navigation_only", false)) else " · 远程地点" if bool(details.get("remote_site", false)) else "") if not selected_id.is_empty() else "左键选目标 · Tab切换"
	selected_distance.tooltip_text = selected_distance.text if not selected_id.is_empty() else "左键短击模型、总览行或雷达回波选择目标；Tab 切换目标。总览双击会下令转向并接近；单次选择不攻击或改变当前开火目标。"
	resource_detail.visible = kind == "resource" and not selected_id.is_empty()
	if resource_detail.visible:
		var info: Dictionary = details.get("resource_info", {})
		resource_label.text = ResourceStatus.summary(info)
		resource_label.tooltip_text = resource_label.text + "\n本星系矿点可远距离读取；采矿仍需满足距离、设备和权限。再生按世界时间推进，暂停与退出不推进。"
		var forecast: Dictionary = details.get("resource_forecast", {})
		if float(forecast.get("rate_per_min", 0.0)) > 0:
			resource_label.text += "\n理论 %.1f 单位/分 · 下一舱可采 %d · 约 %.0f 秒" % [forecast.rate_per_min, int(forecast.room_units), ceil(float(forecast.fill_seconds))]
			resource_label.tooltip_text += "\n理论效率共用实际矿头公式；电容、热量、距离、视线和有限矿量可能降低实际效率。"
		elif not str(forecast.get("reason", "")).is_empty(): resource_label.text += "\n" + str(forecast.reason)
		resource_bar.visible = bool(info.get("available", false)) and int(info.get("capacity_units", 0)) > 0
		resource_fraction.visible = resource_bar.visible
		if resource_bar.visible:
			resource_bar.value = clampf(float(info.remaining_units) / float(info.capacity_units) * 100.0, 0, 100)
			resource_fraction.text = "矿量 %.0f%%" % resource_bar.value
			resource_bar.tooltip_text = resource_label.tooltip_text
	action_grid.columns = 2 if kind in ["npc","drone"] else 3
	var running: bool = bool(navigation.get("active", false))
	status_label.text = UISkin.navigation_phase(str(navigation.get("phase", ""))) if running else str(navigation.get("reason", "")) if not selected_id.is_empty() else ""
	if running and str(navigation.get("title", "")) != selected_title.text and not str(navigation.get("title", "")).is_empty(): status_label.text += " · " + str(navigation.title)
	if running and float(navigation.get("remaining_s", 0.0)) > 0.0: status_label.text += " · %.1f s" % float(navigation.remaining_s)
	var combat_active: bool = bool(navigation.get("combat_active", false))
	var combat_status: String = str(navigation.get("combat_status", ""))
	var combat_title: String = str(navigation.get("combat_target_title", ""))
	var active_combat_status: String = str(navigation.get("combat_target_status", ""))
	var combat_readout: String = "战斗目标：" + combat_title if not combat_title.is_empty() else ""
	if not combat_readout.is_empty() and not active_combat_status.is_empty(): combat_readout += " · " + active_combat_status
	if combat_readout.is_empty() and combat_active: combat_readout = combat_status
	if not combat_readout.is_empty(): status_label.text = (status_label.text + "\n" + combat_readout) if running else combat_readout
	status_label.max_lines_visible = 2 if not _compact or not combat_readout.is_empty() else 1
	status_label.tooltip_text = status_label.text
	status_label.visible = not status_label.text.is_empty()
	for action: String in action_buttons:
		var button: Button = action_buttons[action]
		match action:
			"nav_warp": button.visible = kind in ["station", "gate", "resource", "signal", "marker", "exploration", "exploration_exit"]; button.disabled = busy or not bool(navigation.get("warp_ready", false))
			"nav_approach": button.visible = not selected_id.is_empty() and not bool(details.get("navigation_only", false)); button.disabled = busy or not bool(navigation.get("approach_ready", false))
			"nav_orbit": button.visible = not selected_id.is_empty() and not bool(details.get("navigation_only", false)); button.disabled = busy or not bool(navigation.get("orbit_ready", false))
			"nav_stop": button.visible = running; button.disabled = busy
			"nav_dock": button.visible = kind == "station"; button.disabled = busy or not bool(navigation.get("dock_ready", navigation.get("approach_ready", false)))
			"combat_engage": button.visible = kind in ["npc","drone"] and not selected_friendly; button.disabled = busy or not bool(navigation.get("combat_engage_ready", false))
			"combat_toggle":
				button.visible = kind in ["npc","drone"] and not selected_friendly
				button.text = "停止开火" if bool(navigation.get("combat_active", false)) else "对此开火"
				button.disabled = busy or (not bool(navigation.get("combat_active", false)) and not bool(navigation.get("combat_ready", false)))
		button.tooltip_text = str(navigation.get(action.trim_prefix("nav_") + "_reason", navigation.get("reason", "由航行控制器检查资格。")))
		if action == "combat_engage": button.tooltip_text = "交战：自动接近所选敌舰，并明确切换对此目标自动开火。\n" + str(navigation.get("combat_engage_reason", "由战斗控制器检查目标与航行资格。"))
		if action == "combat_toggle": button.tooltip_text = "按钮明确切换对所选敌舰开火；保留接近或环绕。Z 有开火指令时停止当前开火，无指令时启动所选敌舰。武器仍检查射程、射界、视线、冷却、电容与热量。\n" + str(navigation.get("combat_reason", "由战斗控制器检查资格。"))
		if action == "nav_dock": button.tooltip_text = "接近所选空间站，满足停靠条件后入站。F 仅进行当前范围内的即时交互。"
	eligible_actions.clear()
	for action: String in action_buttons: eligible_actions[action] = action_buttons[action].visible
	_layout_actions()

func _layout_actions() -> void:
	var primary: Array[String] = ["nav_warp","nav_approach","nav_orbit"]
	if selected_kind == "station" and not action_buttons.nav_warp.disabled: primary = ["nav_warp","nav_dock","nav_approach"]
	elif selected_kind == "station": primary = ["nav_approach","nav_orbit"]
	elif selected_kind in ["npc","drone"]: primary = ["combat_engage","combat_toggle","nav_orbit"]
	if selected_friendly:primary=["nav_approach","nav_orbit"]
	var extra: bool = false
	for action: String in action_buttons:
		var eligible: bool = bool(eligible_actions.get(action,false))
		extra = extra or (eligible and action not in primary)
		action_buttons[action].visible = eligible and (actions_expanded or action in primary)
	more_actions.visible = extra
	more_actions.text = "收起操作" if actions_expanded else "更多操作"
	_queue_list_layout()

func set_support_options(records: Array[Dictionary],busy: bool) -> void:
	var retained: Array[String] = []
	var statuses: PackedStringArray = []
	for record: Dictionary in records:
		var id: String = str(record.item_id)
		retained.append(id); support_records[id] = record
		var button: Button
		if support_buttons.has(id): button = support_buttons[id]
		else:
			button = _button(support_box.get_node("SupportActions"),"")
			button.name = "RemoteSupport_"+id.validate_node_name()
			button.set_meta("support_item_id",id)
			button.pressed.connect(func(): support_requested.emit(id,selected_id,bool(support_records[id].active)))
			support_buttons[id] = button
		var layer_title: String = "护盾" if record.layer_id == "shield" else "装甲"
		button.text = ("停止" if record.active else "维修")+layer_title
		button.disabled = busy or (not record.active and not str(record.reason).is_empty())
		button.tooltip_text = "远程维修 · %s · %s\n%s" % [layer_title,format_distance(record.range_m),"停止后不退还已支付周期" if record.active else str(record.reason) if not str(record.reason).is_empty() else "完成付费周期后修复所选友舰；不能维修敌舰"]
		if record.active: statuses.append(layer_title+" · "+str(record.get("status","%.1f秒" % record.remaining_s)))
	for id: String in support_buttons.keys():
		if id in retained: continue
		var button: Button = support_buttons[id]
		button.get_parent().remove_child(button);button.queue_free();support_buttons.erase(id);support_records.erase(id)
	support_box.visible = not records.is_empty()
	support_status.text = " / ".join(statuses)
	support_status.visible = not statuses.is_empty()
	_queue_list_layout()

func responsive(compact: bool, available_height: float = -1.0) -> void:
	_compact = compact
	_available_height = available_height
	if content == null: return
	content.move_child(selection_card, 0 if compact else content.get_child_count() - 1)
	selection_card.add_theme_stylebox_override("panel", UISkin.hud_panel(4 if compact else UISkin.GAP))
	selection_card.get_node("SelectedTargetDetails").add_theme_constant_override("separation", 4)
	selected_title.add_theme_font_size_override("font_size", 12 if compact else 14)
	selected_distance.add_theme_font_size_override("font_size", 10 if compact else 11)
	resource_label.add_theme_font_size_override("font_size", 10 if compact else 11)
	status_label.max_lines_visible = 1 if compact else 2
	for button: Variant in action_buttons.values():
		button.add_theme_font_size_override("font_size", 10 if compact else 11)
		button.custom_minimum_size.y = 22 if compact else 24
	for entry: Dictionary in npc_bars: entry.label.custom_minimum_size.x = 58 if compact else 70
	_refresh_rows()
	_queue_list_layout()

func _queue_list_layout() -> void:
	if _layout_queued: return
	_layout_queued = true
	_reflow_list.call_deferred()

func _reflow_list() -> void:
	_layout_queued = false
	if not is_instance_valid(target_scroll): return
	if _available_height < 0:
		target_scroll.custom_minimum_size.y = 66 if _compact else 154
		return
	# Reserve the current card's actual font/controls height, then devote the
	# remaining pane to contacts. In a small viewport the body remains scrollable.
	var chrome: float = get_theme_stylebox("panel").get_minimum_size().y + float(content.get_theme_constant("separation"))
	chrome += overview_content.get_combined_minimum_size().y - target_scroll.get_combined_minimum_size().y
	var desired: float = maxf(54.0 if _compact else 96.0, _available_height - selection_card.get_combined_minimum_size().y - chrome)
	if absf(target_scroll.custom_minimum_size.y - desired) > 0.5: target_scroll.custom_minimum_size.y = desired
	_sync_column_headers()

func _sync_column_headers() -> void:
	if not is_instance_valid(sort_header_inset) or not is_instance_valid(target_list) or target_list.size.x <= 0.0: return
	# The list gives its scrollbar a gutter. Match it in the fixed column header.
	var gutter: int = maxi(0, roundi(target_scroll.size.x - target_list.size.x))
	if sort_header_inset.get_theme_constant("margin_right") != ROW_INSET + gutter:
		sort_header_inset.add_theme_constant_override("margin_right", ROW_INSET + gutter)

func _style_sort_header(button: Button, active: bool) -> void:
	UISkin.apply_button(button, "default", true, active)
	# Column captions align with the readout glyphs, without button text padding.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var surface: StyleBox = button.get_theme_stylebox(state).duplicate() as StyleBox
		surface.content_margin_left = 0
		surface.content_margin_right = 0
		button.add_theme_stylebox_override(state, surface)

func _refresh_rows() -> void:
	if target_list == null: return
	var visible_rows: Array[Dictionary] = []
	for entry: Dictionary in entry_rows:
		var combat: bool = str(entry.get("kind", "")) in ["npc", "drone", "wreck", "encounter"]
		if filter_mode == "combat" and not combat: continue
		if filter_mode == "navigation" and combat: continue
		visible_rows.append(entry)
	visible_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av: Variant = float(a.get("distance_m", INF)) if sort_key == "distance" else str(a.get("title", "")) if sort_key == "name" else str(a.get("type_title", ""))
		var bv: Variant = float(b.get("distance_m", INF)) if sort_key == "distance" else str(b.get("title", "")) if sort_key == "name" else str(b.get("type_title", ""))
		if av == bv: return str(a.id) < str(b.id)
		return av < bv if sort_ascending else av > bv)
	filtered_ids.clear()
	for record: Dictionary in visible_rows:
		var id: String = str(record.id)
		filtered_ids.append(id)
		var button: Button
		if target_buttons.has(id): button = target_buttons[id]
		else:
			button = _button(target_list, "")
			button.name = "OverviewTarget_" + id.validate_node_name()
			button.pressed.connect(func(): selected.emit(id))
			button.gui_input.connect(_target_gui_input.bind(id, button))
			var row: HBoxContainer = HBoxContainer.new()
			row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			row.offset_left = ROW_INSET; row.offset_right = -ROW_INSET
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", COLUMN_GAP)
			button.add_child(row)
			var distance: Label = _label(row, "", 10, UISkin.MUTED)
			distance.name = "Distance"; distance.custom_minimum_size.x = DISTANCE_COLUMN_WIDTH
			distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var title: Label = _label(row, "", 11, UISkin.TEXT)
			title.name = "Name"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var type: Label = _label(row, "", 9, UISkin.MUTED)
			type.name = "Type"; type.custom_minimum_size.x = TYPE_COLUMN_WIDTH
			var resource_readout: Label = _label(button, "", 10, UISkin.MUTED)
			resource_readout.name = "ResourceState"
			resource_readout.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			resource_readout.offset_left = 4; resource_readout.offset_right = -4
			resource_readout.offset_top = -20; resource_readout.offset_bottom = -2
			resource_readout.clip_text = true
			resource_readout.max_lines_visible = 1
			resource_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
			resource_readout.hide()
			target_buttons[id] = button
		var qualification: String = " · 天体航向参考\n单击选择" if bool(record.get("navigation_only", false)) else (" · 远程已知地点" if bool(record.get("remote_site", false)) else " · 本星系已知位置" if bool(record.get("known", false)) else " · 传感器接触") + "\n单击选择 · 双击转向并前往"
		button.tooltip_text = "%s · %s\n%s%s" % [str(record.title), str(record.get("type_title", "")), format_distance(float(record.distance_m)), qualification]
		var resource: bool = str(record.get("kind", "")) == "resource"
		var reserve: Label = button.get_node("ResourceState")
		reserve.visible = resource
		button.get_child(0).offset_bottom = -20 if resource else 0
		if resource:
			var full_summary: String = str(record.get("resource_summary", "资源状态不可用"))
			reserve.text = compact_resource_summary(record.get("resource_info", {})) if _compact else full_summary
			reserve.add_theme_font_size_override("font_size", 9 if _compact else 10)
			reserve.add_theme_color_override("font_color", UISkin.WARN if bool(record.get("resource_info", {}).get("depleted", false)) else UISkin.MUTED)
			button.tooltip_text += "\n" + full_summary + "\n再生按世界时间推进；暂停与退出不推进。"
		button.get_child(0).get_node("Distance").text = format_distance(float(record.distance_m))
		button.get_child(0).get_node("Name").text = str(record.title)
		var name_label: Label = button.get_child(0).get_node("Name")
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _compact else TextServer.AUTOWRAP_OFF
		name_label.max_lines_visible = 2 if _compact else 1
		name_label.clip_text = not _compact
		button.custom_minimum_size.y = (54 if _compact else 44) if resource else (34 if _compact else 24)
		button.get_child(0).get_node("Name").add_theme_color_override("font_color", UISkin.AMBER if id == selected_id else UISkin.ICE if bool(record.get("friendly", false)) else UISkin.DANGER if str(record.get("kind", "")) in ["npc", "drone"] else UISkin.TEXT)
		button.get_child(0).get_node("Type").text = str(record.get("type_title", ""))
		UISkin.apply_button(button, "default", true, id == selected_id)
		target_list.move_child(button, filtered_ids.size() - 1)
	for id: String in target_buttons.keys():
		if id not in filtered_ids:
			var button: Button = target_buttons[id]
			target_list.remove_child(button)
			button.queue_free()
			target_buttons.erase(id)
	count_label.text = "%d 目标" % visible_rows.size()
	for key: String in filter_buttons: UISkin.apply_button(filter_buttons[key], "default", true, key == filter_mode)
	for key: String in sort_buttons:
		sort_buttons[key].text = {"distance": "距离", "name": "名称", "type": "类型"}[key] + (" +" if sort_ascending else " −") if sort_key == key else {"distance": "距离", "name": "名称", "type": "类型"}[key]
		_style_sort_header(sort_buttons[key], key == sort_key)

func _target_gui_input(event: InputEvent, id: String, button: Button) -> void:
	if not event is InputEventMouseButton: return
	var mouse: InputEventMouseButton = event
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed or not mouse.double_click: return
	button.accept_event()
	selected.emit(id)
	for record: Dictionary in entry_rows:
		if str(record.get("id", "")) != id: continue
		if not bool(record.get("navigation_only", false)): command.emit("nav_approach", id)
		return

static func format_distance(distance_m: float) -> String:
	return XJSpaceUnits.distance(distance_m)

static func compact_resource_summary(info: Dictionary) -> String:
	# Presentation only: preserve all stock/reservation digits in narrow HUDs.
	# The selected card and tooltip retain ResourceStatus.summary verbatim.
	if not bool(info.get("available", false)): return "资源状态不可用"
	if bool(info.get("depleted", false)):
		return "耗尽 · 再生 %s" % ResourceStatus.countdown(float(info.get("respawn_remaining_s", 0.0)))
	var text: String = "%d/%d" % [int(info.get("remaining_units", 0)), int(info.get("capacity_units", 0))]
	if int(info.get("reserved_units", 0)) > 0: text += " · 教学预留%d" % int(info.reserved_units)
	else: text = "剩余 " + text
	return text

func _button(parent: Node, title: String) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 24)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	UISkin.apply_button(button, "default", true)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.clip_text = true
	label.custom_minimum_size.x = 0
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
