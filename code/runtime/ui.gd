class_name XJUI
extends CanvasLayer
signal requested(action: String, target: String, quantity: int, extra: String)
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
var state: XJRuntimeState
var catalog: XJCatalog
var gameplay: RefCounted
var sector: XJSector
var camera: XJCameraRig
var root: Control
var top: Label
var health: Label
var objective: Label
var toast: Label
var controls: Label
var marker_layer: Control
var panel: PanelContainer
var body: VBoxContainer
var page: String = ""
var target_id: String = ""
var quantity_input: SpinBox
var new_name: LineEdit
var menu_open: bool = true
var target_list: VBoxContainer
var hud_refresh: float = 0.0
var slots: Array[Dictionary] = []
var message_age: float = 0.0
var theme: Theme
var hud_left: VBoxContainer
var target_panel: PanelContainer
var target_buttons: Dictionary = {}
var npc_detail: VBoxContainer
var npc_title: Label
var npc_bars: Array[Dictionary] = []
var work_box: VBoxContainer
var work_label: Label
var work_progress: ProgressBar
var work_stop: Button
var work_mode: String = ""
var operation_bar: PanelContainer
var operation_label: Label
var operation_cancel: Button
var page_scroll: ScrollContainer
var mission_filter: String = "local"
var mission_page: int = 0
var market_filter: String = "buy"
var quantity_value: int = 1
var quotes: Array[Dictionary] = []
var live_missions: Array[Dictionary] = []
var definition_cache: Dictionary = {}
var friendly_names: Dictionary = {}
const PAGE_TITLES: Dictionary = {"station": "空间站服务", "ships": "舰队与借船", "warehouse": "仓库与货舱", "fitting": "舰船配装", "market": "站点市场", "industry": "工业与回收", "missions": "任务与合同", "research": "科技与设施", "map": "星域航路", "pause": "暂停与存读档"}
const ACTION_NAMES: Dictionary = {"undock": "已出港", "dock": "已停靠", "switch_ship": "已切换驾驶舰", "buy_item": "购买完成", "sell_item": "出售完成", "buy_ship": "船体购买完成", "sell_ship": "船体出售完成", "move_stack": "货物转移完成", "move_item": "设备转移完成", "fit_module": "配装完成", "unfit_module": "设备已卸下", "repair": "维修完成", "manufacture": "生产完成", "recycle": "拆解完成", "accept_mission": "任务已接取", "abandon_mission": "任务已放弃", "deliver_mission": "任务已交付", "claim_loan": "任务舰已交接", "handoff_loan": "借船已归还", "request_rescue": "救援完成", "start_scan": "扫描已开始", "stop_scan": "扫描已停止", "start_mining": "采矿已开始", "stop_mining": "采矿已停止", "set_module_enabled": "设备开关已更新", "request_engine_cycle": "增推已启用", "research": "研究完成", "build_base": "设施已建成", "recover_resource": "组件已回收", "pickup_wreck": "残骸已回收"}
var preferences: Dictionary = {}
var title_background: TextureRect
var title_shade: ColorRect
var instrument: PanelContainer
var dial: Control
var condition_bars: Array[Dictionary] = []
var energy_label: Label
var energy_bar: ProgressBar
var heat_label: Label
var heat_bar: ProgressBar
var cargo_label: Label
var instrument_title: Label
var navigation: PanelContainer
var station_layer: Control
var station_services: PanelContainer
var station_details: PanelContainer
var station_departure: PanelContainer
var station_ship_name: Label
var station_ship_status: Label
var station_status: Label
var station_portraits: Array[TextureRect] = []
var sidebar: VBoxContainer
var card_grid: GridContainer
var title_show_slots: bool = false
var return_page: String = ""
var ui_motion: Tween
var telemetry_signature: String = ""
var last_page_focus: Dictionary = {}
var operation_kind: String = ""
var operation_message: String = ""
var operation_waiting: bool = false

func set_operation_status(kind: String, message: String, waiting: bool = false) -> void:
	operation_kind = kind
	operation_message = _friendly(message)
	operation_waiting = waiting
	if is_instance_valid(operation_bar):
		operation_bar.visible = kind != "idle" and not message.is_empty()
		operation_label.text = operation_message
		operation_label.tooltip_text = operation_message
		operation_cancel.visible = waiting and "save" in kind
		_responsive()

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	theme = UISkin.create()
	root.theme = theme
	title_background = TextureRect.new()
	title_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_background.texture = UISkin.texture("res://assets/interface_v2/title_background.png")
	root.add_child(title_background)
	title_shade = ColorRect.new()
	title_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_shade.color = Color(0.008, 0.015, 0.024, 0.43)
	title_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_shade)
	marker_layer = Control.new()
	marker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_layer.draw.connect(_draw_markers)
	root.add_child(marker_layer)
	var objective_frame: PanelContainer = _frame(root, "FlightObjective")
	objective_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	objective_frame.offset_left = 22
	objective_frame.offset_top = 22
	objective_frame.offset_right = 342
	objective_frame.offset_bottom = 130
	hud_left = VBoxContainer.new()
	hud_left.add_theme_constant_override("separation", 9)
	hud_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_frame.add_child(hud_left)
	top = _text_to(hud_left, "航行", 17)
	top.add_theme_color_override("font_color", UISkin.ICE)
	objective = _text_to(hud_left, "", 14)
	objective.max_lines_visible = 4
	work_box = VBoxContainer.new()
	work_box.add_theme_constant_override("separation", 5)
	hud_left.add_child(work_box)
	work_label = _text_to(work_box, "", 13)
	work_progress = _bar(work_box, UISkin.AMBER, 6)
	work_progress.show_percentage = true
	work_stop = _button(work_box, "停止作业", func(): requested.emit("stop_scan" if work_mode == "scan" else "stop_mining", "", 1, ""))
	work_box.hide()
	_build_instrument()
	_build_navigation()
	controls = _label(root, "Alt 操作界面 · 右键观察", 11)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 22
	controls.offset_top = -37
	controls.offset_right = 302
	controls.add_theme_color_override("font_color", UISkin.MUTED)
	toast = _label(root, "", 14)
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast.offset_left = 370
	toast.offset_right = -320
	toast.offset_top = 22
	toast.offset_bottom = 68
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.max_lines_visible = 2
	_build_target_module()
	operation_bar = _frame(root, "OperationStatus")
	operation_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	operation_bar.offset_left = 22
	operation_bar.offset_right = -22
	operation_bar.offset_top = 12
	operation_bar.offset_bottom = 70
	var operation_row: HBoxContainer = HBoxContainer.new()
	operation_row.add_theme_constant_override("separation", 16)
	operation_bar.add_child(operation_row)
	operation_label = _text_to(operation_row, "", 14)
	operation_label.custom_minimum_size.x = 0
	operation_label.max_lines_visible = 3
	operation_cancel = _button(operation_row, "取消等待", func(): requested.emit("cancel_save", "", 1, ""))
	operation_cancel.custom_minimum_size.x = 122
	operation_cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	operation_bar.hide()
	panel = PanelContainer.new()
	panel.name = "ScreenPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_top = 34
	panel.offset_right = -30
	panel.offset_bottom = -34
	root.add_child(panel)
	station_layer = Control.new()
	station_layer.name = "StationOverlay"
	station_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	station_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(station_layer)
	station_layer.hide()
	root.resized.connect(_responsive)
	operation_bar.resized.connect(_responsive)
	show_title([])
	_responsive()

func bind(runtime: XJRuntimeState, db: XJCatalog, business: RefCounted, world: XJSector, rig: XJCameraRig) -> void:
	state = runtime
	catalog = db
	gameplay = business
	sector = world
	camera = rig
	definition_cache.clear()
	telemetry_signature = ""
	_build_names()
	menu_open = false
	target_id = ""
	mission_page = 0
	show_page("station" if state.player().has_docked_station_id else "")
	_refresh_targets()

func show_title(save_slots: Array[Dictionary]) -> void:
	slots = save_slots
	menu_open = true
	page = "title"
	_build_panel("星际战舰", "断航星域  /  单人远征")
	_text("从失联边疆，重建你的航路。", 17)
	if not slots.is_empty():
		var resume: Button = _button(body, "继续航行", func(): requested.emit("continue", "", 1, ""))
		_primary(resume)
	new_name = LineEdit.new()
	new_name.name = "ExpeditionName"
	new_name.placeholder_text = "远征名称"
	new_name.text = "断航远征"
	new_name.max_length = 48
	new_name.custom_minimum_size.y = 38
	body.add_child(new_name)
	var start: Button = _button(body, "建立新远征", func(): requested.emit("new_world", new_name.text.strip_edges(), 1, ""))
	_primary(start) if slots.is_empty() else _secondary(start)
	if not slots.is_empty():
		_button(body, "航行档案" + (" · 收起" if title_show_slots else ""), func(): title_show_slots = not title_show_slots; show_title(slots))
		if title_show_slots: _show_slots()
	var utilities: HBoxContainer = HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 12)
	body.add_child(utilities)
	_secondary(_button(utilities, "设置", func(): show_page("settings")))
	_secondary(_button(utilities, "退出游戏", func(): requested.emit("quit", "", 1, "")))
	var footer: Label = _text_to(body, "本机保存 · 原创星域 · 离线航行", 12)
	footer.add_theme_color_override("font_color", UISkin.MUTED)
	_focus_page.call_deferred()

func show_page(next_page: String) -> void:
	if page == "settings" and next_page != "settings": return_page = ""
	elif next_page == "settings" and page != "settings": return_page = page
	page = next_page
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = not next_page.is_empty() and next_page != "station"
	station_layer.visible = next_page == "station"
	_update_hud_visibility()
	if next_page.is_empty():
		root.get_viewport().gui_release_focus()
		return
	if next_page == "title": show_title(slots); return
	if next_page == "settings":
		_build_panel("设置", "偏好立即保留在本机")
		_settings()
		_focus_page.call_deferred()
		return
	if state == null: show_title(slots); return
	if next_page == "station":
		_station()
		_responsive()
		return
	_build_panel(str(PAGE_TITLES.get(next_page, "航行服务")), "%s  /  %s  /  %d 信用点" % [_station_name(state.player().docked_station_id) if state.player().has_docked_station_id else _sector_name(state.current_sector()), _ship_name(state.ship().ship_def_id), state.player().credit])
	if next_page in ["ships", "warehouse", "fitting", "market", "industry", "research"] and not state.player().has_docked_station_id:
		_text("此服务需要停靠空间站。使用星图找到站点，进入停靠范围并减速后按 F。")
		_focus_page.call_deferred()
		return
	match next_page:
		"ships": _ships()
		"warehouse": _warehouse()
		"fitting": _fitting()
		"market": _market()
		"industry": _industry()
		"missions": _missions()
		"research": _research()
		"map": _map()
		"pause": _pause()
	_animate_panel()
	_focus_page.call_deferred()

func notify(message: String, is_error: bool = false) -> void:
	toast.text = _friendly(message)
	toast.tooltip_text = toast.text
	toast.modulate = Color("ff8578") if is_error else UISkin.AMBER
	_responsive()
	message_age = 0.0

func tick(delta: float) -> void:
	message_age += delta
	if message_age > 12.0:
		toast.text = ""
	marker_layer.queue_redraw()
	if state == null or state.ship() == null or gameplay == null:
		return
	hud_refresh += delta
	# 此节流仅限制界面重绘，不改变模拟频率或玩法数值。
	if hud_refresh < 0.25:
		return
	hud_refresh = 0.0
	var ship: Dtos.ShipStateDto = state.ship()
	var metrics: Dictionary = gameplay.call("metrics", ship)
	var definition: Dictionary = _one("sector_defs", "sector_id", ship.sector_id)
	top.text = "%s\n%s · %s · %d 信用点" % [_ship_name(ship.ship_def_id), _sector_name(ship.sector_id), _risk_name(str(definition.get("risk_zone_id", ""))), state.player().credit]
	health.text = "护盾 %.0f/%.0f  装甲 %.0f/%.0f  结构 %.0f/%.0f\n电容 %.0f/%.0f  热量 %.0f/%.0f %s\n速度 %.0f m/s\n货舱 %.0f/%.0f L  矿舱 %.0f/%.0f L" % [ship.shield, metrics.shield_max, ship.armor, metrics.armor_max, ship.hull, metrics.hull_max, ship.energy, metrics.energy_max, ship.heat, metrics.heat_max, "过热" if ship.overheated else "", Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length(), metrics.cargo_used_l, metrics.cargo_capacity_l, metrics.mineral_used_l, metrics.mineral_capacity_l]
	if root.size.x < 900:
		top.tooltip_text = top.text
		top.text = "%s\n%s · %s" % [_ship_name(ship.ship_def_id), _sector_name(ship.sector_id), _risk_name(str(definition.get("risk_zone_id", "")))]
		health.text = "护盾 %.0f%% · 装甲 %.0f%% · 结构 %.0f%%\n电容 %.0f%% · 热量 %.0f%% %s\n速度 %.0f m/s · 货 %.0f/%.0f L" % [ship.shield / maxf(metrics.shield_max, 1.0) * 100, ship.armor / maxf(metrics.armor_max, 1.0) * 100, ship.hull / maxf(metrics.hull_max, 1.0) * 100, ship.energy / maxf(metrics.energy_max, 1.0) * 100, ship.heat / maxf(metrics.heat_max, 1.0) * 100, "过热" if ship.overheated else "", Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length(), metrics.cargo_used_l + metrics.mineral_used_l, metrics.cargo_capacity_l + metrics.mineral_capacity_l]
	objective.text = _objective_text()
	_update_instrument(ship, metrics)
	if page == "station": _update_station_info()
	_update_work()
	_update_live_missions()
	_refresh_targets()
	_update_npc_target()

func input_blocked() -> bool:
	return menu_open or panel.visible or station_layer.visible or (root.get_viewport().gui_get_focus_owner() is LineEdit) or _pointer_over(target_panel) or _pointer_over(work_box) or _pointer_over(operation_bar) or _pointer_over(navigation) or _pointer_over(instrument)

func refresh_page() -> void:
	if not page.is_empty() and page != "settings" and page != "title":
		var previous_scroll: int = page_scroll.scroll_vertical if is_instance_valid(page_scroll) else 0
		show_page(page)
		if is_instance_valid(page_scroll): page_scroll.set_deferred("scroll_vertical", previous_scroll)

func select_next() -> void:
	if sector == null:
		return
	var keys: Array = sector.targets.keys()
	if keys.is_empty():
		target_id = ""
		return
	target_id = str(keys[(keys.find(target_id) + 1) % keys.size()])

func _build_panel(title: String, description: String) -> void:
	for child: Node in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	quotes.clear()
	live_missions.clear()
	quantity_input = null
	card_grid = null
	panel.visible = true
	panel.modulate = Color.WHITE
	panel.add_theme_stylebox_override("panel", UISkin.plate() if page != "title" else StyleBoxEmpty.new())
	var shell: HBoxContainer = HBoxContainer.new()
	shell.add_theme_constant_override("separation", 24)
	panel.add_child(shell)
	sidebar = VBoxContainer.new()
	sidebar.name = "ServiceSidebar"
	sidebar.custom_minimum_size.x = 178
	sidebar.add_theme_constant_override("separation", 8)
	shell.add_child(sidebar)
	if state != null and page not in ["title", "settings"]:
		_module_heading(sidebar, "舰载终端", "服务 / 航路")
		var available: Array[String] = ["missions", "map", "pause"]
		if state.player().has_docked_station_id: available = ["station", "ships", "warehouse", "fitting", "market", "industry", "missions", "research", "map", "pause"]
		for key: String in available:
			var item: Button = _button(sidebar, str(PAGE_TITLES[key]), show_page.bind(key))
			item.custom_minimum_size.x = 178
			item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if key == page: _primary(item)
		var divider: HSeparator = HSeparator.new()
		sidebar.add_child(divider)
		var location: Label = _text_to(sidebar, _station_name(state.player().docked_station_id) if state.player().has_docked_station_id else _sector_name(state.current_sector()), 12)
		location.add_theme_color_override("font_color", UISkin.MUTED)
	else: sidebar.hide()
	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	shell.add_child(layout)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var heading: Label = _text_to(header, title, 48 if page == "title" else 25)
	heading.custom_minimum_size.x = 90
	heading.max_lines_visible = 2
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if state != null and page not in ["title", "settings"]:
		var selector: OptionButton = OptionButton.new()
		selector.name = "PageSelector"
		selector.custom_minimum_size = Vector2(132, 36)
		for key: String in PAGE_TITLES: selector.add_item(str(PAGE_TITLES[key])); selector.set_item_metadata(selector.item_count - 1, key)
		for index: int in range(selector.item_count):
			if selector.get_item_metadata(index) == page: selector.select(index)
		selector.item_selected.connect(func(index: int): show_page(str(selector.get_item_metadata(index))))
		selector.visible = root.size.x < 950
		header.add_child(selector)
	if page != "title":
		var close: Button = _button(header, "返回" if page == "settings" else "返回机库" if state != null and state.player().has_docked_station_id else "返回航行", _back)
		close.name = "PanelClose"
		close.custom_minimum_size.x = 96
		close.size_flags_horizontal = Control.SIZE_SHRINK_END
		_secondary(close)
	var subheading: Label = _text_to(layout, description, 13)
	subheading.add_theme_color_override("font_color", UISkin.MUTED)
	subheading.max_lines_visible = 2
	var line: HSeparator = HSeparator.new()
	layout.add_child(line)
	page_scroll = ScrollContainer.new()
	page_scroll.name = "PageScroll"
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(page_scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	page_scroll.add_child(body)
	_update_hud_visibility()
	_responsive()

func _station() -> void:
	for child: Node in station_layer.get_children():
		station_layer.remove_child(child)
		child.queue_free()
	panel.hide()
	quotes.clear()
	live_missions.clear()
	card_grid = null
	station_services = _frame(station_layer, "StationServices")
	station_services.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	station_services.offset_left = 22
	station_services.offset_right = 282
	station_services.offset_top = 96
	station_services.offset_bottom = -120
	var services: VBoxContainer = VBoxContainer.new()
	services.add_theme_constant_override("separation", 12)
	station_services.add_child(services)
	_module_heading(services, "驻站联络", "选择服务人员")
	var service_scroll: ScrollContainer = ScrollContainer.new()
	page_scroll = service_scroll
	service_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	service_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	services.add_child(service_scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	service_scroll.add_child(body)
	station_portraits.clear()
	_npc_service(body, 0, "航路与委托", "站务官 · 任务 / 航路", "missions")
	_npc_service(body, 1, "舰队与补给", "补给官 · 市场 / 舰队", "market")
	_npc_service(body, 2, "工业与整备", "工程师 · 制造 / 仓储", "industry")
	_npc_service(body, 3, "科技与研究", "研究官 · 科技 / 设施", "research")
	var shortcuts: HFlowContainer = HFlowContainer.new()
	body.add_child(shortcuts)
	_secondary(_button(shortcuts, "舰队", show_page.bind("ships")))
	_secondary(_button(shortcuts, "配装", show_page.bind("fitting")))
	_secondary(_button(shortcuts, "仓储", show_page.bind("warehouse")))
	var overview: Button = _command(shortcuts, "观察舰船", "hangar_focus")
	overview.name = "HangarOverview"
	_secondary(overview)
	station_details = _frame(station_layer, "StationShipDetails")
	station_details.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	station_details.offset_left = -282
	station_details.offset_right = -22
	station_details.offset_top = 96
	station_details.offset_bottom = -170
	var details: VBoxContainer = VBoxContainer.new()
	details.add_theme_constant_override("separation", 12)
	station_details.add_child(details)
	_module_heading(details, "舰泊档案", "当前驾驶舰")
	station_ship_name = _text_to(details, _ship_name(state.ship().ship_def_id), 22)
	station_ship_name.add_theme_color_override("font_color", UISkin.ICE)
	station_ship_status = _text_to(details, "", 14)
	var funds: Label = _text_to(details, "%d 信用点" % state.player().credit, 19)
	funds.add_theme_color_override("font_color", UISkin.AMBER)
	var needs: Dictionary = gameplay.get("economy").call("repair_requirements")
	var price: int = int(gameplay.get("economy").call("quote_repair"))
	var repair: Button = _command(details, "维修补给 · %d 信用点" % price, "repair", state.ship().ship_instance_id)
	repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	repair.disabled = state.player().credit < price
	_text_to(details, "需结构部件 × %d" % int(needs.get("structural_units", 0)), 12).add_theme_color_override("font_color", UISkin.MUTED)
	_secondary(_button(details, "调整配装", show_page.bind("fitting")))
	station_departure = _frame(station_layer, "StationDeparture")
	station_departure.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	station_departure.offset_left = 22
	station_departure.offset_right = -22
	station_departure.offset_top = -96
	station_departure.offset_bottom = -22
	var departure: HBoxContainer = HBoxContainer.new()
	departure.add_theme_constant_override("separation", 18)
	station_departure.add_child(departure)
	station_status = _text_to(departure, _station_name(state.player().docked_station_id) + "\n停靠完成 · 整备后即可出航", 15)
	station_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var undock: Button = _command(departure, "确认出港  ›", "undock")
	undock.name = "UndockButton"
	undock.custom_minimum_size = Vector2(210, 44)
	_primary(undock)
	_secondary(_button(departure, "系统", show_page.bind("pause")))
	_update_station_info()
	_focus_page.call_deferred()

func _ships() -> void:
	for row: Dtos.ShipStateDto in state.rows("ship_state"):
		if row.status in [Types.ShipStatus.RETURNED, Types.ShipStatus.DESTROYED]: continue
		var card: VBoxContainer = _card("%s · %s" % [_ship_name(row.ship_def_id), _policy_name(row.policy_id)])
		_text_to(card, "结构 %.0f / 装甲 %.0f · %s%s" % [row.hull, row.armor, _station_name(row.station_id) if row.status == Types.ShipStatus.DOCKED else _sector_name(row.sector_id), " · 当前驾驶" if row.ship_instance_id == state.ship().ship_instance_id else ""])
		var local: bool = row.status == Types.ShipStatus.DOCKED and row.station_id == state.player().docked_station_id
		var switch: Button = _command(card, "切换驾驶", "switch_ship", row.ship_instance_id)
		switch.disabled = not local or row.ship_instance_id == state.ship().ship_instance_id
		var may_sell: bool = bool(_one("asset_policy_defs", "policy_id", row.policy_id).get("may_sell", false))
		if may_sell:
			var price: int = int(gameplay.get("economy").call("quote_ship", row.ship_instance_id, true))
			var sell: Button = _command(card, "出售船体 · 实收 %d 信用点" % price, "sell_ship", row.ship_instance_id)
			sell.disabled = not local
			_text_to(card, "出售前会安全换舰、卸下普通设备与货物；需有可替代舰。", 14)
	for definition: Dictionary in _defs("loan_service_defs"):
		if definition.station_id != state.player().docked_station_id: continue
		var loadout: Dictionary = _one("ship_loadout_defs", "loadout_id", str(definition.loadout_id))
		var card: VBoxContainer = _card("任务借船 · " + _ship_name(str(loadout.get("ship_id", ""))))
		var mission: Dtos.MissionStateDto = _latest_mission(str(definition.required_mission_id))
		var reason: String = ""
		if not _unlocked(str(definition.required_unlock_id)): reason = "需解锁 " + _unlock_name(str(definition.required_unlock_id))
		elif mission == null or mission.status not in ["active", "ready"]: reason = "需先接取 " + _mission_name(str(definition.required_mission_id))
		var loan: Dtos.LoanStateDto = state.find("loan_state", "loan_service_id", str(definition.loan_service_id))
		if loan != null and loan.status == Types.LoanStatus.ACTIVE: reason = "已有借船在使用"
		elif loan != null and loan.replacement_remaining_s > 0: reason = "补领等待 %.0f 秒" % loan.replacement_remaining_s
		_text_to(card, "费用 %d 信用点 · 归还 %s。借船及绑定设备不能出售，换发保留任务与采额。" % [int(definition.fee_credit), _station_name(str(definition.return_station_id))], 14)
		if not reason.is_empty(): _text_to(card, reason, 14)
		var claim: Button = _command(card, "领取 / 换领任务舰", "claim_loan", str(definition.loan_service_id))
		claim.disabled = not reason.is_empty()
	for loan: Dtos.LoanStateDto in state.rows("loan_state"):
		if loan.status not in [Types.LoanStatus.ACTIVE, Types.LoanStatus.LOST]: continue
		var definition: Dictionary = _one("loan_service_defs", "loan_service_id", loan.loan_service_id)
		var loadout: Dictionary = _one("ship_loadout_defs", "loadout_id", str(definition.get("loadout_id", "")))
		var card: VBoxContainer = _card("借船管理 · " + _ship_name(str(loadout.get("ship_id", ""))))
		if loan.has_quota_remaining_units: _text_to(card, "剩余可采额度 %d · 补领不会恢复额度" % loan.quota_remaining_units)
		_text_to(card, "返航 %s 后归还；普通战利品转入当地仓库。" % _station_name(str(definition.get("return_station_id", ""))), 14)
		var handoff: Button = _command(card, "归还借船并切换替代舰", "handoff_loan", loan.loan_id)
		handoff.disabled = definition.get("return_station_id") != state.player().docked_station_id

func _warehouse() -> void:
	_quantity()
	_text("仅显示当前站点仓库和当前驾驶舰的货舱。保护或任务绑定物资保留用途限制。", 14)
	var warehouse: String = _warehouse_id()
	var cargo: String = _ship_container(Types.ContainerKind.CARGO)
	var mineral: String = _ship_container(Types.ContainerKind.MINERAL)
	var count: int = 0
	for stack: Dtos.InventoryStackStateDto in state.rows("inventory_stack_state"):
		if not _local_container(stack.container_id): continue
		var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", stack.container_id)
		var card: VBoxContainer = _card("%s × %d" % [_item_name(stack.item_def_id), stack.quantity])
		count += 1
		_text_to(card, "%s · %s" % [_container_name(container), _policy_name(stack.policy_id)], 14)
		if stack.policy_id != "normal_owned":
			_text_to(card, "此批物资仅供指定教学或合同使用。", 14)
			continue
		for destination: Dictionary in [{"id": warehouse, "title": "转入站点仓库"}, {"id": cargo, "title": "装入当前舰货舱"}, {"id": mineral, "title": "装入当前舰矿舱"}]:
			if not str(destination.id).is_empty() and stack.container_id != destination.id:
				_command(card, str(destination.title), "move_stack", stack.stack_id, str(destination.id))
	for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
		if not _local_container(item.container_id): continue
		var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", item.container_id)
		var card: VBoxContainer = _card(_item_name(item.item_def_id))
		count += 1
		_text_to(card, "%s · 耐久 %.0f · 品质 %.2f · %s" % [_container_name(container), item.durability, item.quality_multiplier, _policy_name(item.policy_id)], 14)
		if item.policy_id != "normal_owned": continue
		if item.container_id != warehouse and not warehouse.is_empty(): _command(card, "移至站点仓库", "move_item", item.item_instance_id, warehouse)
		if item.container_id != cargo and not cargo.is_empty(): _command(card, "装入当前舰货舱", "move_item", item.item_instance_id, cargo)
	if count == 0: _text("本地没有可整理的货物。")

func _fitting() -> void:
	var metrics: Dictionary = gameplay.call("metrics", state.ship())
	_text("供能 %.0f/%.0f · 算力 %.0f/%.0f · 总质量 %.0f kg" % [metrics.power_used, metrics.power_capacity, metrics.cpu_used, metrics.cpu_capacity, metrics.total_mass_kg])
	for container: Dtos.ContainerStateDto in state.rows("container_state"):
		if container.ship_instance_id != state.ship().ship_instance_id or container.kind != Types.ContainerKind.SLOT: continue
		var slot_type: String = ["weapon", "work", "utility", "structure"][int(container.slot_type)]
		var card: VBoxContainer = _card("%s槽 %d" % [["武器", "作业", "通用", "结构"][int(container.slot_type)], container.slot_index + 1])
		var equipped: Dtos.EquipmentStateDto = state.find("equipment_state", "slot_container_id", container.container_id)
		if equipped != null:
			var item: Dtos.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", equipped.item_instance_id)
			_text_to(card, _item_name(equipped.module_def_id) + " · " + ("已启用" if equipped.enabled else "已关闭"))
			if item != null: _text_to(card, "%s · 耐久 %.0f · 品质 %.2f" % [_policy_name(item.policy_id), item.durability, item.quality_multiplier], 14)
			var unfit: Button = _command(card, "卸下模块至仓库", "unfit_module", equipped.item_instance_id)
			unfit.disabled = item == null or item.policy_id != "normal_owned"
			_command(card, "关闭设备" if equipped.enabled else "启用设备", "set_module_enabled", equipped.item_instance_id, "off" if equipped.enabled else "on")
		else:
			var available: int = 0
			for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
				if not _local_container(item.container_id) or item.policy_id != "normal_owned": continue
				var module: Dictionary = _one("module_defs", "module_id", item.item_def_id)
				if not module.is_empty() and module.slot_type == slot_type:
					available += 1
					_command(card, "安装 " + _item_name(item.item_def_id), "fit_module", item.item_instance_id, "%s:%d" % [slot_type, container.slot_index])
			if available == 0: _text_to(card, "本地没有适配此槽的设备；可在市场购买或工业制造。", 14)

func _market() -> void:
	_quantity()
	var filters: HFlowContainer = HFlowContainer.new()
	body.add_child(filters)
	for filter: String in ["buy", "ships", "sell"]:
		_button(filters, str({"buy": "购买物资", "ships": "购买船体", "sell": "出售本地资产"}[filter]) + (" · 当前" if filter == market_filter else ""), func(): market_filter = filter; show_page("market"))
	_text("以下为选定数量的含税成交报价，包含当前声望优惠。成交时重新校验库存、额度和资金。", 14)
	var count: int = 0
	if market_filter == "buy":
		for stock: Dtos.ShopStockStateDto in state.rows("shop_stock_state"):
			if stock.station_id != state.player().docked_station_id: continue
			var definition: Dictionary = _stock_definition(stock.item_def_id)
			if not bool(definition.get("allow_buy", false)): continue
			count += 1
			var card: VBoxContainer = _card(_item_name(stock.item_def_id))
			_text_to(card, "站点库存 %d" % stock.quantity, 14)
			var label: Label = _text_to(card, "")
			var button: Button = _command(card, "购买选定数量", "buy_item", stock.item_def_id)
			quotes.append({"kind": "item", "id": stock.item_def_id, "selling": false, "label": label, "button": button, "maximum": stock.quantity, "unlock": str(definition.get("required_unlock_id", ""))})
	elif market_filter == "ships":
		for stock: Dtos.ShopShipStockStateDto in state.rows("shop_ship_stock_state"):
			if stock.station_id != state.player().docked_station_id: continue
			count += 1
			var card: VBoxContainer = _card(_ship_name(stock.ship_def_id) + " · 裸舰")
			_text_to(card, "库存 %d · 船体数量固定为 1；设备与弹药另购。" % stock.quantity, 14)
			var label: Label = _text_to(card, "")
			var button: Button = _command(card, "购买船体", "buy_ship", stock.ship_def_id)
			var role: Dictionary = _one("ship_role_defs", "ship_id", stock.ship_def_id)
			quotes.append({"kind": "ship", "id": stock.ship_def_id, "selling": false, "label": label, "button": button, "maximum": stock.quantity, "unlock": str(role.get("required_unlock_id", ""))})
	else:
		var budget: Dtos.StationEconomyStateDto = state.find("station_economy_state", "station_id", state.player().docked_station_id)
		if budget != null: _text("本站本轮回购预算 %d 信用点" % budget.buyback_remaining_credit, 14)
		for stack: Dtos.InventoryStackStateDto in state.rows("inventory_stack_state"):
			if not _local_container(stack.container_id): continue
			var definition: Dictionary = _stock_definition(stack.item_def_id)
			if not bool(definition.get("allow_sell", false)): continue
			count += 1
			var card: VBoxContainer = _card("%s × %d · %s" % [_item_name(stack.item_def_id), stack.quantity, _policy_name(stack.policy_id)])
			var label: Label = _text_to(card, "")
			var button: Button = _command(card, "出售选定数量", "sell_item", stack.stack_id)
			_text_to(card, "保护物资不可交易；普通物資受本站回购额度限制。", 14)
			quotes.append({"kind": "item", "id": stack.item_def_id, "selling": true, "label": label, "button": button, "maximum": stack.quantity, "policy": stack.policy_id})
		for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
			if not _local_container(item.container_id): continue
			var definition: Dictionary = _stock_definition(item.item_def_id)
			if not bool(definition.get("allow_sell", false)): continue
			count += 1
			var card: VBoxContainer = _card(_item_name(item.item_def_id) + " · " + _policy_name(item.policy_id))
			var label: Label = _text_to(card, "")
			var button: Button = _button(card, "出售此设备", func(): requested.emit("sell_item", item.item_instance_id, 1, ""))
			quotes.append({"kind": "item", "id": item.item_def_id, "selling": true, "label": label, "button": button, "maximum": 1, "fixed": 1, "policy": item.policy_id})
	if count == 0: _text("此页没有当前站点可交易的资产。")
	_update_quotes()

func _industry() -> void:
	_quantity()
	_text("数量表示生产批数；材料仅取当前站点仓库的普通自有物资。费用包含设施优惠。", 14)
	for access: Dictionary in _defs("recipe_access_defs"):
		if access.station_id != state.player().docked_station_id: continue
		var recipe: Dictionary = _one("recipe_defs", "recipe_id", str(access.recipe_id))
		var card: VBoxContainer = _card("制造 / 提炼 · " + _item_name(str(recipe.get("output_item_id", ""))))
		_text_to(card, _inputs_text("recipe_inputs", "recipe_id", str(access.recipe_id)) + "
每批产出 %d" % int(recipe.get("output_quantity", 1)), 14)
		var label: Label = _text_to(card, "")
		var button: Button = _command(card, "生产选定批数", "manufacture", str(access.recipe_id))
		quotes.append({"kind": "recipe", "id": str(access.recipe_id), "label": label, "button": button, "unlock": str(access.required_unlock_id)})
	for recipe: Dictionary in _defs("hull_recipe_defs"):
		var local_yard: bool = false
		for stock: Dtos.ShopShipStockStateDto in state.rows("shop_ship_stock_state"):
			if stock.station_id == state.player().docked_station_id and stock.ship_def_id == recipe.ship_id: local_yard = true
		if not local_yard: continue
		var card: VBoxContainer = _card("船坞 · " + _ship_name(str(recipe.ship_id)))
		_text_to(card, _inputs_text("hull_recipe_inputs", "hull_recipe_id", str(recipe.hull_recipe_id)), 14)
		var label: Label = _text_to(card, "")
		var button: Button = _command(card, "制造选定批数裸舰", "manufacture", str(recipe.hull_recipe_id))
		quotes.append({"kind": "recipe", "id": str(recipe.hull_recipe_id), "label": label, "button": button, "unlock": str(recipe.required_unlock_id)})
	_text("设备拆解 · 普通本地资产", 20)
	for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
		if item.container_id == _warehouse_id() and item.policy_id == "normal_owned": _command(body, "拆解 " + _item_name(item.item_def_id), "recycle", item.item_instance_id)
	_update_quotes()

func _missions() -> void:
	_text("本页不暂停飞行。目标按顺序完成；舰船损失保留当前任务，交付需要指定实物。", 14)
	var filter_row: HFlowContainer = HFlowContainer.new()
	body.add_child(filter_row)
	for filter: String in ["local", "available", "active", "all"]:
		_button(filter_row, str({"local": "当前站点 / 星系", "available": "可接取", "active": "进行中", "all": "全部任务"}[filter]) + (" · 当前" if filter == mission_filter else ""), func(): mission_filter = filter; mission_page = 0; show_page("missions"))
	var filtered: Array[Dictionary] = []
	for definition: Dictionary in _defs("mission_summary_defs"):
		var current: Dtos.MissionStateDto = _latest_mission(str(definition.mission_id))
		var active: bool = current != null and current.status in ["active", "ready"]
		var local: bool = definition.accept_station_id == state.player().docked_station_id if state.player().has_docked_station_id else _one("station_defs", "station_id", str(definition.accept_station_id)).get("sector_id") == state.current_sector()
		if mission_filter == "local" and not local and not active: continue
		if mission_filter == "available" and not _mission_reason(definition, current).is_empty(): continue
		if mission_filter == "active" and not active: continue
		filtered.append(definition)
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = _mission_rank(a)
		var rank_b: int = _mission_rank(b)
		return str(a.mission_id) < str(b.mission_id) if rank_a == rank_b else rank_a < rank_b)
	var pages: int = maxi(1, ceili(float(filtered.size()) / 6.0))
	mission_page = clampi(mission_page, 0, pages - 1)
	var navigation: HBoxContainer = HBoxContainer.new()
	body.add_child(navigation)
	var previous: Button = _button(navigation, "上一页", func(): mission_page -= 1; show_page("missions"))
	previous.disabled = mission_page <= 0
	_text_to(navigation, "%d 项 · %d / %d 页" % [filtered.size(), mission_page + 1, pages], 14)
	var next: Button = _button(navigation, "下一页", func(): mission_page += 1; show_page("missions"))
	next.disabled = mission_page >= pages - 1
	if filtered.is_empty(): _text("此筛选没有任务。可切换“全部任务”查看前置条件。")
	for definition: Dictionary in filtered.slice(mission_page * 6, mini((mission_page + 1) * 6, filtered.size())):
		var current: Dtos.MissionStateDto = _latest_mission(str(definition.mission_id))
		var card: VBoxContainer = _card(_mission_name(str(definition.mission_id)))
		card.name = "MissionCard"
		_text_to(card, "奖励 %d 信用点 · 接取 %s · 交付 %s" % [int(definition.get("reward_credit", 0)), _station_name(str(definition.accept_station_id)), _station_name(str(definition.turnin_station_id))], 14)
		var active: bool = current != null and current.status in ["active", "ready"]
		if active:
			var status: Label = _text_to(card, _mission_status(current.status), 16)
			var progress_rows: Array[Dictionary] = []
			for objective_def: Dictionary in _defs("mission_objective_defs"):
				if objective_def.mission_id != current.mission_def_id: continue
				var progress: Dtos.MissionObjectiveStateDto = _mission_progress(current.mission_instance_id, int(objective_def.objective_index))
				if progress == null: continue
				var label: Label = _text_to(card, _objective_description(objective_def) + " · %d/%d" % [progress.progress_units, int(objective_def.required_count)], 14)
				progress_rows.append({"label": label, "state": progress, "definition": objective_def})
			live_missions.append({"label": status, "mission": current, "progress": progress_rows})
			var target: String = _current_mission_target(current)
			if not target.is_empty() and sector != null and sector.targets.has(target): _button(card, "定位当前目标并继续航行", func(): target_id = target; _back())
			var deliver: Button = _command(card, "交付任务与实物", "deliver_mission", current.mission_instance_id)
			deliver.disabled = current.status != "ready" or state.player().docked_station_id != definition.turnin_station_id
			if current.status == "ready": _text_to(card, "返回 %s；将所需实物带入当前舰或该站仓库。" % _station_name(str(definition.turnin_station_id)), 14)
			_command(card, "放弃此次任务", "abandon_mission", current.mission_instance_id)
		else:
			var reason: String = _mission_reason(definition, current)
			_text_to(card, reason if not reason.is_empty() else "可接取", 15)
			var accept: Button = _command(card, "接取任务" if current == null else "重新接取", "accept_mission", str(definition.mission_id))
			accept.disabled = not reason.is_empty()
	_update_live_missions()

func _research() -> void:
	var station_faction: String = str(_one("station_defs", "station_id", state.player().docked_station_id).get("faction_id", ""))
	for definition: Dictionary in _defs("research_defs"):
		if definition.station_faction_id != station_faction: continue
		var card: VBoxContainer = _card(str(definition.display_name))
		var done: bool = _unlocked(str(definition.reward_unlock_id))
		var reason: String = "已完成研究" if done else ""
		for prerequisite: Dictionary in _defs("research_prerequisites"):
			if prerequisite.research_id == definition.research_id and not _unlocked(str(prerequisite.unlock_id)): reason = "需先解锁 " + _unlock_name(str(prerequisite.unlock_id))
		var reputation: int = int(gameplay.get("economy").call("reputation", station_faction))
		if not done and reputation < int(definition.required_reputation): reason = "声望 %d/%d" % [reputation, int(definition.required_reputation)]
		if not done and definition.get("verification_mission_id") != null and not _mission_completed(str(definition.verification_mission_id)): reason = "需先完成 " + _mission_name(str(definition.verification_mission_id))
		_text_to(card, "费用 %d 信用点 · 需声望 %d
%s" % [int(definition.required_credit), int(definition.required_reputation), _inputs_text("research_inputs", "research_id", str(definition.research_id))], 14)
		if not reason.is_empty(): _text_to(card, reason, 14)
		var button: Button = _command(card, "完成研究", "research", str(definition.research_id))
		button.disabled = not reason.is_empty() or state.player().credit < int(definition.required_credit)
	for definition: Dictionary in _defs("base_module_defs"):
		var card: VBoxContainer = _card(str(definition.display_name))
		var built: bool = false
		for facility: RefCounted in state.rows("base_module_state"):
			if facility.station_id == state.player().docked_station_id and facility.base_module_id == definition.base_module_id: built = true
		_text_to(card, "费用 %d 信用点
%s" % [int(definition.service_fee_credit), _inputs_text("base_module_inputs", "base_module_id", str(definition.base_module_id))], 14)
		var button: Button = _command(card, "设施已建成" if built else "建造个人设施", "build_base", str(definition.base_module_id))
		button.disabled = built or not _unlocked(str(definition.required_unlock_id))
		if not _unlocked(str(definition.required_unlock_id)): _text_to(card, "需解锁 " + _unlock_name(str(definition.required_unlock_id)), 14)
	_text("已解锁科技与资格", 20)
	for row: Dtos.UnlockStateDto in state.rows("unlock_state"): _text(_unlock_name(row.unlock_id), 14)
	for reputation: Dtos.ReputationStateDto in state.rows("reputation_state"):
		_text("%s · 声望 %d" % [str(_one("faction_defs", "faction_id", reputation.faction_id).get("display_name", "未知势力")), reputation.reputation], 14)

func _map() -> void:
	_text("虫洞门连接星系。定位仅选择目标；需实际飞近门口、减速并按 F 跃迁。准入与冷却在交互时校验。", 14)
	for system: Dictionary in _defs("system_defs"):
		var card: VBoxContainer = _card(str(system.display_name))
		_text_to(card, str(system.get("description", "")), 14)
		for sector_def: Dictionary in _defs("sector_defs"):
			if sector_def.system_id != system.system_id: continue
			_text_to(card, _risk_name(str(sector_def.risk_zone_id)) + (" · 所在星系" if sector_def.sector_id == state.current_sector() else ""), 14)
			for station: Dictionary in _defs("station_defs"):
				if station.sector_id == sector_def.sector_id:
					_text_to(card, "站点 · " + _station_name(str(station.station_id)), 14)
					if station.sector_id == state.current_sector(): _button(card, "定位 " + _station_name(str(station.station_id)), func(): target_id = str(station.station_id); _back())
			for resource: Dictionary in _defs("resource_node_defs"):
				if resource.sector_id == sector_def.sector_id: _text_to(card, "产出 · " + _item_name(str(resource.item_id)), 14)
			for endpoint: Dictionary in _defs("gate_endpoint_defs"):
				if endpoint.origin_sector_id != sector_def.sector_id: continue
				_text_to(card, "航路 → " + _sector_name(str(endpoint.target_sector_id)), 14)
				if endpoint.origin_sector_id == state.current_sector(): _button(card, "定位通往 " + _sector_name(str(endpoint.target_sector_id)) + " 的虫洞门", func(): target_id = str(endpoint.endpoint_id); _back())

func _pause() -> void:
	_text("世界时间已暂停。保存成功后才会更新存档；等待中的保存可取消。", 14)
	_button(body, "继续航行", _back)
	var rescue: Button = _command(body, "舰船损失后返回保障站", "request_rescue")
	rescue.name = "RescueButton"
	rescue.disabled = state.ship().status != Types.ShipStatus.DESTROYED
	if operation_waiting and operation_kind == "save": _command(body, "取消等待中的保存", "cancel_save")
	for index: int in range(5): _button(body, "保存至手动槽 %d" % (index + 1), func(): requested.emit("save", str(index), 1, "manual"))
	_button(body, "快速保存", func(): requested.emit("save", "0", 1, "quick"))
	_show_slots()
	_button(body, "设置", show_page.bind("settings"))
	_button(body, "保存并返回主菜单", func(): requested.emit("return_title", "", 1, ""))
	_button(body, "保存并退出", func(): requested.emit("quit", "", 1, ""))
	_text("放弃未保存进度后，下次从最后成功存档恢复。", 14)
	var discard: Button = _button(body, "放弃未保存进度并退出", func(): requested.emit("quit_without_save", "", 1, ""))
	discard.name = "QuitWithoutSave"

func _settings() -> void:
	if preferences.is_empty():
		_text("偏好尚未加载，请稍后重新打开设置。")
		return
	for field: String in ["master_volume", "mouse_sensitivity", "vfx_intensity"]:
		var title: String = {"master_volume": "主音量", "mouse_sensitivity": "鼠标灵敏度", "vfx_intensity": "特效强度"}[field]
		var current: float = float(preferences.get(field, 0.0))
		var value_label: Label = _text_to(body, _setting_text(title, current, field))
		var slider: HSlider = HSlider.new()
		slider.name = "Preference_" + field
		slider.min_value = minf(0.0002, current) if field == "mouse_sensitivity" else 0.0
		slider.max_value = maxf(0.008, current) if field == "mouse_sensitivity" else 1.0
		slider.step = 0.0001 if field == "mouse_sensitivity" else 0.01
		slider.custom_minimum_size.y = 36
		slider.value = current # 先赋实际值，再绑定事件；打开页面不写回数据库。
		body.add_child(slider)
		slider.value_changed.connect(func(value: float):
			value_label.text = _setting_text(title, value, field)
			requested.emit("preference", field, 1, str(value)))
	_text("鼠标灵敏度从低到高调整；主音量为 0 时静音。")
	var quality_row: HFlowContainer = HFlowContainer.new()
	body.add_child(quality_row)
	for quality: String in ["high", "medium", "low"]:
		var label: String = {"high": "高", "medium": "中", "low": "低"}[quality]
		_button(quality_row, "画质 · " + label + ("（当前）" if preferences.get("quality_mode") == quality else ""), func(): requested.emit("preference", "quality_mode", 1, quality))

func _show_slots() -> void:
	if slots.is_empty():
		_text("暂无已保存的航行。")
	for slot: Dictionary in slots:
		var kind: String = {"manual": "手动", "quick": "快速", "auto": "自动"}.get(str(slot.get("slot_kind", "")), "存档")
		var updated: String = str(slot.get("updated_utc", "")).replace("T", " ").replace("Z", "")
		var title: String = "%s槽 %d · %s" % [kind, int(slot.get("slot_index", 0)) + 1, updated]
		_button(body, "读取 " + title, func(): requested.emit("load", str(slot.slot_id), int(slot.get("generation", 0)), str(slot.get("current_snapshot_id", ""))))

func _refresh_targets() -> void:
	if sector == null or not is_instance_valid(sector.flight):
		return
	# Target nodes may disappear between business settlement and visual refresh.
	# Check the raw reference before sorting or casting it to Node3D.
	var sorted: Array[Dictionary] = []
	for entry: Variant in sector.targets.values():
		if entry is Dictionary and is_instance_valid(entry.get("node")) and entry.node is Node3D:
			sorted.append(entry)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary): return sector.flight.position.distance_squared_to(a.node.position) < sector.flight.position.distance_squared_to(b.node.position))
	var visible_ids: Array[String] = []
	for target: Dictionary in sorted:
		var node: Node3D = target.node
		if not is_instance_valid(node): continue
		var distance: float = sector.flight.position.distance_to(node.position)
		if distance > float(catalog.rule("target_marker_detection_range_m")): continue
		var id: String = str(target.id)
		visible_ids.append(id)
		var button: Button
		if target_buttons.has(id):
			button = target_buttons[id]
		else:
			button = _button(target_list, "", func(): target_id = id)
			button.focus_mode = Control.FOCUS_NONE
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			target_buttons[id] = button
		button.text = "%s%s\n%.0f m" % ["▸ " if id == target_id else "", _target_title(target), distance]
		target_list.move_child(button, visible_ids.size() - 1)
	for id: String in target_buttons.keys():
		if id not in visible_ids:
			var button: Button = target_buttons[id]
			target_list.remove_child(button)
			button.queue_free()
			target_buttons.erase(id)

func _draw_markers() -> void:
	if camera == null or camera.camera == null or sector == null or panel.visible or station_layer.visible or state == null or state.ship().status != Types.ShipStatus.FLYING:
		return
	var center := root.size * 0.5
	for segment: Vector4 in [Vector4(-11, 0, -4, 0), Vector4(4, 0, 11, 0), Vector4(0, -11, 0, -4), Vector4(0, 4, 0, 11)]:
		var start: Vector2 = center + Vector2(segment.x, segment.y)
		var finish: Vector2 = center + Vector2(segment.z, segment.w)
		marker_layer.draw_line(start, finish, Color(0.005, 0.01, 0.015, 0.9), 3.5, true)
		marker_layer.draw_line(start, finish, UISkin.ICE, 1.5, true)
	marker_layer.draw_circle(center, 1.5, UISkin.ICE)
	for target: Dictionary in sector.targets.values():
		var candidate: Variant = target.get("node")
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var node: Node3D = candidate
		if camera.camera.is_position_behind(node.global_position):
			continue
		var point := camera.camera.unproject_position(node.global_position)
		var selected: bool = target.id == target_id
		var color := Color("ff9477") if target.kind == "npc" else Color("69dbe9")
		var radius := 15.0 if selected else 8.0
		marker_layer.draw_arc(point, radius, 0, TAU, 16, color, 2.0)
		if selected:
			marker_layer.draw_string(theme.default_font, point + Vector2(20, -10), _target_title(target), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func _objective_text() -> String:
	for mission: Dtos.MissionStateDto in state.rows("mission_state"):
		if mission.status not in ["active", "ready"]: continue
		var definition: Dictionary = _one("mission_defs", "mission_id", mission.mission_def_id)
		var heading: String = "当前任务 · " + _mission_name(mission.mission_def_id)
		if mission.status == "ready": return heading + "\n返回 " + _station_name(str(definition.get("turnin_station_id", ""))) + " 交付"
		for objective_def: Dictionary in _defs("mission_objective_defs"):
			if objective_def.mission_id != mission.mission_def_id: continue
			var progress: Dtos.MissionObjectiveStateDto = _mission_progress(mission.mission_instance_id, int(objective_def.objective_index))
			if progress != null and progress.progress_units < int(objective_def.required_count) and objective_def.objective_kind != "deliver":
				return heading + "\n" + _objective_description(objective_def) + " · %d/%d" % [progress.progress_units, int(objective_def.required_count)]
		return heading + "\n检查实物并返航交付。"
	return "J 任务 · M 星图\n在空间站接取教学、地区合同和主线。"

func _objective_description(definition: Dictionary) -> String:
	var kind: String = str(definition.get("objective_kind", ""))
	match kind:
		"undock": return "从 %s 出港" % _station_name(str(definition.get("target_station_id", "")))
		"reach_anchor": return "抵达 " + _anchor_name(str(definition.get("target_anchor_id", "")))
		"brake_at_anchor": return "在 %s 附近减至 %.0f m/s 以下并保持 %.0f 秒" % [_anchor_name(str(definition.get("target_anchor_id", ""))), float(definition.get("max_speed_mps", 0)), float(definition.get("hold_s", 0))]
		"dock": return "停靠 " + _station_name(str(definition.get("target_station_id", "")))
		"scan_signal": return "解析 " + str(_one("signal_defs", "signal_id", str(definition.get("target_signal_id", ""))).get("display_name", "指定信号"))
		"collect": return "采集 " + _item_name(str(definition.get("target_item_id", "")))
		"deliver": return "携带 " + _item_name(str(definition.get("target_item_id", ""))) + " 返回交付"
		"destroy_spawn":
			var spawn: Dictionary = _one("npc_spawn_defs", "spawn_id", str(definition.get("target_spawn_id", "")))
			return "击毁 " + str(_one("npc_full_defs", "npc_id", str(spawn.get("npc_id", ""))).get("display_name", "指定敌舰"))
		"transit_connection":
			for endpoint: Dictionary in _defs("gate_endpoint_defs"):
				if endpoint.connection_id == definition.get("target_connection_id") and endpoint.origin_sector_id == state.current_sector(): return "通过虫洞门前往 " + _sector_name(str(endpoint.target_sector_id))
			return "通过指定星际虫洞门"
		"loan_checkout":
			var service: Dictionary = _one("loan_service_defs", "loan_service_id", str(definition.get("target_loan_service_id", "")))
			var loadout: Dictionary = _one("ship_loadout_defs", "loadout_id", str(service.get("loadout_id", "")))
			return "在舰队页领取 " + _ship_name(str(loadout.get("ship_id", "")))
		"fit_validate": return "检查并完成任务所需配装"
	return "完成指定目标"

func _objective_target(definition: Dictionary) -> String:
	for field: String in ["target_anchor_id", "target_signal_id", "target_node_id", "target_spawn_id", "target_connection_id", "target_station_id"]:
		if definition.get(field) == null: continue
		var id: String = str(definition[field])
		if field == "target_spawn_id":
			for npc: Dtos.NpcStateDto in state.rows("npc_state"):
				if npc.spawn_id == id and npc.alive and npc.sector_id == state.current_sector(): return npc.npc_instance_id
			return ""
		if field == "target_connection_id":
			for endpoint: Dictionary in _defs("gate_endpoint_defs"):
				if endpoint.connection_id == id and endpoint.origin_sector_id == state.current_sector(): return str(endpoint.endpoint_id)
			return ""
		return id
	return ""

func _quantity() -> void:
	_text("操作数量 · 堆叠单位 / 制造批数", 14)
	quantity_input = SpinBox.new()
	quantity_input.name = "OperationQuantity"
	quantity_input.min_value = 1
	quantity_input.max_value = float(catalog.rule("business_quantity_limit"))
	quantity_input.step = 1
	quantity_input.value = clampi(quantity_value, 1, int(quantity_input.max_value))
	quantity_input.custom_minimum_size.y = 36
	body.add_child(quantity_input)
	quantity_input.value_changed.connect(func(value: float): quantity_value = int(value); _update_quotes())

func _command(parent: Node, title: String, action: String, target: String = "", extra: String = "") -> Button:
	var uses_quantity: bool = action in ["buy_item", "sell_item", "move_stack", "manufacture", "recover_resource"]
	return _button(parent, title, func(): requested.emit(action, target, quantity_value if uses_quantity else 1, extra))

func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(118, 38)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(callback)
	button.mouse_entered.connect(func(): _button_feedback(button, true))
	button.mouse_exited.connect(func(): _button_feedback(button, false))
	parent.add_child(button)
	return button

func _text(text: String, size: int = 15) -> void:
	card_grid = null
	_text_to(body, text, size)

func _text_to(parent: Node, text: String, size: int = 16) -> Label:
	var label := _label(parent, text, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 0
	return label

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _card(title: String) -> VBoxContainer:
	if card_grid == null:
		card_grid = GridContainer.new()
		card_grid.name = "ModuleCards"
		card_grid.columns = 2 if root.size.x >= 1200 else 1
		card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_grid.add_theme_constant_override("h_separation", 14)
		card_grid.add_theme_constant_override("v_separation", 14)
		body.add_child(card_grid)
	var frame: PanelContainer = _frame(card_grid, "ModuleCard")
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card: VBoxContainer = VBoxContainer.new()
	card.add_theme_constant_override("separation", 10)
	frame.add_child(card)
	var heading: Label = _text_to(card, title, 18)
	heading.add_theme_color_override("font_color", UISkin.ICE)
	return card

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _ship_name(id: String) -> String:
	return str(_one("ship_defs", "ship_id", id).get("display_name", "未知舰船"))

func _item_name(id: String) -> String:
	return str(_one("item_defs", "item_id", id).get("display_name", "指定物资"))

func _station_name(id: String) -> String:
	return str(_one("station_defs", "station_id", id).get("display_name", "空间站"))

func _warehouse_id() -> String:
	for container: Dtos.ContainerStateDto in state.rows("container_state"):
		if container.kind == Types.ContainerKind.STATION and container.station_id == state.player().docked_station_id:
			return container.container_id
	return ""

func _ship_container(kind: Types.ContainerKind) -> String:
	for container: Dtos.ContainerStateDto in state.rows("container_state"):
		if container.kind == kind and container.ship_instance_id == state.ship().ship_instance_id:
			return container.container_id
	return ""

func _container_name(container: Dtos.ContainerStateDto) -> String:
	return ["站点仓库", "舰船货舱", "矿物舱", "配装槽", "残骸"][int(container.kind)]

func _local_container(id: String) -> bool:
	var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", id)
	if container == null or container.owner_player_id != state.player().player_id: return false
	if container.kind == Types.ContainerKind.STATION: return state.player().has_docked_station_id and container.station_id == state.player().docked_station_id
	return container.kind in [Types.ContainerKind.CARGO, Types.ContainerKind.MINERAL] and container.ship_instance_id == state.ship().ship_instance_id and state.ship().status not in [Types.ShipStatus.DESTROYED, Types.ShipStatus.RETURNED]

func _defs(table: String) -> Array[Dictionary]:
	if not definition_cache.has(table):
		definition_cache[table] = catalog.rows(table) if catalog != null else []
	return definition_cache[table]

func _one(table: String, key: String, value: String) -> Dictionary:
	for row: Dictionary in _defs(table):
		if str(row.get(key, "")) == value:
			return row
	return {}

func _presentation(id: String) -> float:
	var row: Dictionary = _one("presentation_defs", "presentation_id", id)
	return float(row.get("value_integer") if row.get("value_integer") != null else row.get("value_real", 0.0))

func _build_names() -> void:
	friendly_names.clear()
	var keys: Dictionary = {"ship_defs": "ship_id", "item_defs": "item_id", "station_defs": "station_id", "mission_defs": "mission_id", "unlock_defs": "unlock_id", "faction_defs": "faction_id", "signal_defs": "signal_id", "npc_full_defs": "npc_id", "research_defs": "research_id", "base_module_defs": "base_module_id", "system_defs": "system_id"}
	for table: String in keys:
		for row: Dictionary in _defs(table):
			if row.get("display_name") != null: friendly_names[str(row.get(keys[table], ""))] = str(row.display_name)
	friendly_names.erase("")
	friendly_names["anchor_anchor_flight_forward"] = "前进航路标"
	friendly_names["anchor_anchor_flight_turn"] = "转向航路标"
	friendly_names["anchor_anchor_beacon"] = "航门校准航标"
	for row: Dictionary in _defs("sector_defs"): friendly_names[str(row.sector_id)] = _sector_name(str(row.sector_id))

func _friendly(message: String) -> String:
	if message.begins_with("操作完成："):
		return str(ACTION_NAMES.get(message.trim_prefix("操作完成："), "操作完成"))
	var result: String = message.replace("COMMIT", "进度写入").replace("正在向 SQLite 提交世界快照", "正在保存完整航行进度").replace("manual", "手动").replace("quick", "快速").replace("auto", "自动")
	var identifiers: Array = friendly_names.keys()
	identifiers.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for id: String in identifiers:
		result = result.replace(id, str(friendly_names[id]))
	return result

func _sector_name(id: String) -> String:
	var sector_def: Dictionary = _one("sector_defs", "sector_id", id)
	return str(_one("system_defs", "system_id", str(sector_def.get("system_id", ""))).get("display_name", "未知星系"))

func _risk_name(id: String) -> String:
	return str({"risk_high": "高安", "risk_medium": "中安", "risk_low": "低安", "high": "高安", "medium": "中安", "low": "低安"}.get(id, "星域"))

func _target_title(target: Dictionary) -> String:
	var id: String = str(target.get("id", ""))
	if friendly_names.has(id):
		return str(friendly_names[id])
	return _friendly(str(target.get("title", "未知目标"))).replace("Lv.", "等级 ")

func _pointer_over(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(control.get_global_mouse_position())

func _update_hud_visibility() -> void:
	var show_hud: bool = state != null and state.ship() != null and state.ship().status == Types.ShipStatus.FLYING and not panel.visible and not station_layer.visible and not menu_open
	if is_instance_valid(hud_left): hud_left.get_parent().visible = show_hud
	if is_instance_valid(instrument): instrument.visible = show_hud
	if is_instance_valid(navigation): navigation.visible = show_hud
	if is_instance_valid(target_panel): target_panel.visible = show_hud
	if is_instance_valid(controls): controls.visible = show_hud and root.size.x >= 1100
	if is_instance_valid(title_background): title_background.visible = page == "title"
	if is_instance_valid(title_shade): title_shade.visible = page == "title"
	if is_instance_valid(station_layer): station_layer.visible = page == "station" and state != null
	_responsive_title()

func _responsive() -> void:
	if not is_instance_valid(root): return
	var compact: bool = root.size.x < 950
	var safe: float = 14.0 if compact else 22.0
	if is_instance_valid(hud_left):
		var frame: PanelContainer = hud_left.get_parent()
		frame.offset_left = safe
		frame.offset_top = safe
		frame.offset_right = safe + (220 if compact else 316)
		top.add_theme_font_size_override("font_size", 14 if compact else 17)
		objective.add_theme_font_size_override("font_size", 12 if compact else 14)
		objective.max_lines_visible = 3 if compact else 4
	if is_instance_valid(instrument):
		var width: float = minf(650, root.size.x - safe * 2)
		instrument.offset_left = -width * 0.5
		instrument.offset_right = width * 0.5
		instrument.offset_top = -164 if compact else -244
		instrument.offset_bottom = -68
		var inset: StyleBox = UISkin.plate()
		inset.content_margin_top = 6 if compact else 12
		inset.content_margin_bottom = 6 if compact else 12
		instrument.add_theme_stylebox_override("panel", inset)
		instrument_title.add_theme_font_size_override("font_size", 11 if compact else 14)
		dial.custom_minimum_size = Vector2(90, 56) if compact else Vector2(154, 125)
		for entry: Dictionary in condition_bars:
			entry.label.add_theme_font_size_override("font_size", 10 if compact else 13)
			entry.bar.visible = not compact
		energy_bar.visible = not compact
		heat_bar.visible = not compact
		energy_label.add_theme_font_size_override("font_size", 10 if compact else 13)
		heat_label.add_theme_font_size_override("font_size", 10 if compact else 13)
		cargo_label.add_theme_font_size_override("font_size", 10 if compact else 12)
	if is_instance_valid(target_panel):
		target_panel.offset_left = -(196 if compact else 270)
		target_panel.offset_right = -safe
		target_panel.offset_top = safe
		target_panel.offset_bottom = 184 if compact else 390
	if is_instance_valid(npc_title): npc_title.add_theme_font_size_override("font_size", 12 if compact else 15)
	if is_instance_valid(npc_detail): npc_detail.add_theme_constant_override("separation", 2 if compact else 4)
	for entry: Dictionary in npc_bars:
		entry.label.add_theme_font_size_override("font_size", 10 if compact else 12)
		entry.bar.custom_minimum_size.y = 5 if compact else 7
	if is_instance_valid(panel):
		panel.offset_left = safe
		panel.offset_right = -safe
		panel.offset_top = maxf(safe, operation_bar.position.y + operation_bar.size.y + 8) if is_instance_valid(operation_bar) and operation_bar.visible else safe
		panel.offset_bottom = -52
		if page == "title": _responsive_title()
	if is_instance_valid(sidebar): sidebar.visible = state != null and page not in ["title", "settings"] and not compact
	if is_instance_valid(panel):
		var selector: OptionButton = panel.find_child("PageSelector", true, false)
		if selector != null: selector.visible = compact
	if is_instance_valid(panel):
		for grid: Node in panel.find_children("ModuleCards*", "GridContainer", true, false):
			grid.columns = 2 if root.size.x >= 1200 else 1
	if is_instance_valid(station_services):
		station_services.offset_left = safe
		station_services.offset_right = safe + (200 if compact else 260)
		station_services.offset_top = 44 if compact else 96
		station_services.offset_bottom = -94 if compact else -120
		for heading: Label in station_services.find_children("NpcServiceTitle", "Label", true, false):
			heading.add_theme_font_size_override("font_size", 13 if compact else 15)
	if is_instance_valid(station_details):
		station_details.visible = not compact
	if is_instance_valid(station_departure):
		station_departure.offset_left = safe
		station_departure.offset_right = -safe
		station_departure.offset_top = -82 if compact else -96
		station_departure.offset_bottom = -safe
	if is_instance_valid(toast):
		toast.offset_left = safe if panel.visible or station_layer.visible else 244 if compact else 370
		toast.offset_right = -safe if panel.visible or station_layer.visible else -206 if compact else -320
		toast.offset_top = -41 if panel.visible else 52 if station_layer.visible else 22
		toast.anchor_top = 1.0 if panel.visible else 0.0
		toast.anchor_bottom = toast.anchor_top
		toast.offset_bottom = -10 if panel.visible else toast.offset_top + 40

func _setting_text(title: String, value: float, field: String) -> String:
	return "%s %.4f" % [title, value] if field == "mouse_sensitivity" else "%s %d%%" % [title, roundi(value * 100)]

func _update_work() -> void:
	var worker: RefCounted = gameplay.get("work")
	if worker == null: return
	var scan: String = str(worker.get("scan_target"))
	var mining: String = str(worker.get("mining_target"))
	work_mode = "scan" if not scan.is_empty() else "mining" if not mining.is_empty() else ""
	work_box.visible = not work_mode.is_empty() and not panel.visible and not station_layer.visible
	objective.visible = root.size.x >= 950 or work_mode.is_empty()
	if work_mode == "scan":
		var definition: Dictionary = _one("signal_defs", "signal_id", scan)
		var threshold: float = float(definition.get("threshold_progress", 1.0))
		work_progress.value = clampf(float(worker.get("scan_progress")) / maxf(threshold, 0.0001) * 100.0, 0, 100)
		work_label.text = "扫描 · %s\n已解析 %.0f%% · 周期剩余 %.1f 秒" % [str(definition.get("display_name", "未知信号")), work_progress.value, float(worker.get("scan_remaining"))]
	elif work_mode == "mining":
		var definition: Dictionary = _one("resource_node_defs", "node_id", mining)
		var cycles: Dictionary = worker.get("mining_cycles")
		var remaining: float = 0.0
		var cycle_s: float = 1.0
		for item_id: String in cycles:
			remaining = float(cycles[item_id])
			var equipment: Dtos.EquipmentStateDto = state.find("equipment_state", "item_instance_id", item_id)
			if equipment != null: cycle_s = float(_one("module_defs", "module_id", equipment.module_def_id).get("cycle_s", 1.0))
			break
		work_progress.value = clampf((1.0 - remaining / maxf(cycle_s, 0.0001)) * 100.0, 0, 100) if not cycles.is_empty() else 0.0
		work_label.text = "采矿 · %s\n%s" % [_item_name(str(definition.get("item_id", ""))), "当前周期剩余 %.1f 秒" % remaining if not cycles.is_empty() else "等待可用采集周期"]

func _update_live_missions() -> void:
	for row: Dictionary in live_missions:
		if not is_instance_valid(row.label): continue
		var mission: Dtos.MissionStateDto = row.mission
		row.label.text = _mission_status(mission.status) + (" · 剩余 %.0f 秒" % mission.deadline_remaining_s if mission.has_deadline_remaining_s else "")
		for entry: Dictionary in row.progress:
			if is_instance_valid(entry.label): entry.label.text = _objective_description(entry.definition) + " · %d/%d" % [entry.state.progress_units, int(entry.definition.get("required_count", 1))]

func _update_npc_target() -> void:
	var npc: Dtos.NpcStateDto = state.find("npc_state", "npc_instance_id", target_id)
	npc_detail.visible = npc != null and npc.alive
	var scroll: ScrollContainer = target_panel.find_child("TargetScroll", true, false)
	if scroll != null: scroll.visible = not npc_detail.visible or root.size.x >= 950
	if not npc_detail.visible: return
	var spawn: Dictionary = _one("npc_spawn_defs", "spawn_id", npc.spawn_id)
	var definition: Dictionary = _one("npc_full_defs", "npc_id", str(spawn.get("npc_id", "")))
	npc_title.text = str(definition.get("display_name", "敌方舰船"))
	for index: int in range(3):
		var key: String = ["shield", "armor", "hull"][index]
		var maximum: float = float(definition.get(key + "_max", 0))
		var current: float = float(npc.get(key))
		npc_bars[index].label.text = "%s %.0f/%.0f" % [npc_bars[index].name, current, maximum]
		npc_bars[index].bar.max_value = maxf(maximum, 1.0)
		npc_bars[index].bar.value = current

func _mission_status(status: String) -> String:
	return str({"active": "进行中", "ready": "可返航交付", "completed": "已完成", "failed": "已失败", "abandoned": "已放弃", "available": "可接取", "locked": "未解锁", "busy": "需先完成当前任务", "finished": "已完成"}.get(status, "待接取"))

func _policy_name(id: String) -> String:
	return str({"normal_owned": "普通自有", "tutorial_protected": "保障资产", "mission_bound": "任务绑定", "loan_protected": "任务借用", "loan_bound": "任务借用"}.get(id, "受用途限制"))

func _unlocked(id: String) -> bool:
	return id.is_empty() or state.find("unlock_state", "unlock_id", id) != null

func _unlock_name(id: String) -> String:
	return str(_one("unlock_defs", "unlock_id", id).get("display_name", "指定科技资格"))

func _mission_name(id: String) -> String:
	var value: String = str(_one("mission_defs", "mission_id", id).get("display_name", "指定任务"))
	var prefix: String = value.get_slice(" ", 0)
	return value.trim_prefix(prefix + " ") if prefix.begins_with("T") and prefix.substr(1).is_valid_int() else value

func _anchor_name(id: String) -> String:
	return str(friendly_names.get(id, "指定航路标"))

func _latest_mission(id: String) -> Dtos.MissionStateDto:
	var latest: Dtos.MissionStateDto
	for mission: Dtos.MissionStateDto in state.rows("mission_state"):
		if mission.mission_def_id == id and (latest == null or mission.attempt_number > latest.attempt_number): latest = mission
	return latest

func _mission_completed(id: String) -> bool:
	for mission: Dtos.MissionStateDto in state.rows("mission_state"):
		if mission.mission_def_id == id and mission.reward_claimed: return true
	return false

func _mission_progress(id: String, index: int) -> Dtos.MissionObjectiveStateDto:
	for objective_state: Dtos.MissionObjectiveStateDto in state.rows("mission_objective_state"):
		if objective_state.mission_instance_id == id and objective_state.objective_index == index: return objective_state
	return null

func _current_mission_target(mission: Dtos.MissionStateDto) -> String:
	if mission.status == "ready": return str(_one("mission_defs", "mission_id", mission.mission_def_id).get("turnin_station_id", ""))
	for definition: Dictionary in _defs("mission_objective_defs"):
		if definition.mission_id != mission.mission_def_id: continue
		var progress: Dtos.MissionObjectiveStateDto = _mission_progress(mission.mission_instance_id, int(definition.objective_index))
		if progress != null and progress.progress_units < int(definition.required_count) and definition.objective_kind != "deliver": return _objective_target(definition)
	return ""

func _mission_reason(definition: Dictionary, current: Dtos.MissionStateDto) -> String:
	if current != null and current.status in ["active", "ready"]: return "任务正在进行"
	if not bool(definition.get("repeatable", false)) and _mission_completed(str(definition.mission_id)): return "已完成"
	if not _unlocked(str(definition.get("required_unlock_id", ""))): return "需解锁 " + _unlock_name(str(definition.get("required_unlock_id", "")))
	for prerequisite: Dictionary in _defs("mission_prerequisites"):
		if prerequisite.mission_id == definition.mission_id and not _mission_completed(str(prerequisite.prerequisite_mission_id)): return "前置任务 · " + _mission_name(str(prerequisite.prerequisite_mission_id))
	if current != null and current.cooldown_remaining_s > 0: return "重接等待 %.0f 秒" % current.cooldown_remaining_s
	var window: Dtos.MissionWindowStateDto = state.find("mission_window_state", "mission_def_id", str(definition.mission_id))
	if window != null and bool(definition.get("repeatable", false)):
		if window.accepted_window_count >= int(catalog.rule("contract_max_accepts_per_window")) or window.completed_window_count >= int(definition.get("max_completions_per_window", 1)): return "本轮额度已用完 · %.0f 秒后恢复" % window.remaining_s
	for mission: Dtos.MissionStateDto in state.rows("mission_state"):
		if mission.status in ["active", "ready"]: return "先完成或放弃当前任务"
	if not state.player().has_docked_station_id or state.player().docked_station_id != definition.accept_station_id: return "需停靠 " + _station_name(str(definition.accept_station_id))
	return ""

func _stock_definition(item_id: String) -> Dictionary:
	for definition: Dictionary in _defs("station_stock_defs"):
		if definition.station_id == state.player().docked_station_id and definition.item_id == item_id: return definition
	return {}

func _inputs_text(table: String, key: String, id: String) -> String:
	var parts: PackedStringArray = []
	for ingredient: Dictionary in _defs(table):
		if ingredient.get(key) == id: parts.append("%s × %d" % [_item_name(str(ingredient.get("item_id", ""))), int(ingredient.get("quantity", 0))])
	return "每批材料：" + "、".join(parts)

func _update_quotes() -> void:
	if gameplay == null: return
	var economy: RefCounted = gameplay.get("economy")
	for row: Dictionary in quotes:
		if not is_instance_valid(row.label) or not is_instance_valid(row.button): continue
		var quantity: int = int(row.get("fixed", 1 if row.kind == "ship" else quantity_value))
		var price: int = 0
		if row.kind == "ship": price = int(economy.call("quote_ship", str(row.id), bool(row.selling)))
		elif row.kind == "recipe": price = int(economy.call("quote_manufacture", str(row.id), quantity))
		else: price = int(economy.call("quote", str(row.id), quantity, bool(row.selling)))
		var selling: bool = bool(row.get("selling", false))
		var reason: String = ""
		if not _unlocked(str(row.get("unlock", ""))): reason = "需解锁 " + _unlock_name(str(row.get("unlock", "")))
		if row.has("policy") and not bool(_one("asset_policy_defs", "policy_id", str(row.policy)).get("may_sell", false)): reason = "保护 / 绑定资产不可出售"
		if row.has("maximum") and quantity > int(row.maximum): reason = "数量超过现有库存"
		if selling:
			var stock: Dtos.ShopStockStateDto
			for current_stock: Dtos.ShopStockStateDto in state.rows("shop_stock_state"):
				if current_stock.station_id == state.player().docked_station_id and current_stock.item_def_id == row.id: stock = current_stock
			var definition: Dictionary = _stock_definition(str(row.id))
			var budget: Dtos.StationEconomyStateDto = state.find("station_economy_state", "station_id", state.player().docked_station_id)
			if stock == null or quantity > stock.buyback_remaining_units or stock.quantity + quantity > int(definition.get("hard_cap_units", 0)): reason = "本站本轮回购数量额度不足"
			elif budget != null and budget.buyback_remaining_credit < price: reason = "本站本轮回购预算不足"
		if not selling and state.player().credit < price: reason = "信用点不足"
		row.label.text = ("实收" if selling else "含税总价" if row.kind != "recipe" else "生产服务费") + " %d 信用点 · 数量 %d" % [price, quantity] + ("\n" + reason if not reason.is_empty() else "")
		row.button.disabled = not reason.is_empty()

func _mission_rank(definition: Dictionary) -> int:
	var mission: Dtos.MissionStateDto = _latest_mission(str(definition.mission_id))
	if mission != null and mission.status in ["active", "ready"]: return 0
	if not bool(definition.get("repeatable", false)) and _mission_completed(str(definition.mission_id)): return 3
	return 1 if _mission_reason(definition, mission).is_empty() else 2

func _frame(parent: Node, name_hint: String) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.name = name_hint
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(frame)
	UISkin.decorate(frame, 0.52)
	return frame

func _bar(parent: Node, color: Color, height: float = 7.0) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.add_theme_stylebox_override("fill", UISkin.flat(color, color, 0))
	parent.add_child(bar)
	return bar

func _module_heading(parent: Node, title: String, subtitle: String = "") -> void:
	var line: Label = _text_to(parent, "▰  " + title, 14)
	line.add_theme_color_override("font_color", UISkin.ICE)
	if not subtitle.is_empty():
		var caption: Label = _text_to(parent, subtitle, 11)
		caption.add_theme_color_override("font_color", UISkin.MUTED)

func _build_instrument() -> void:
	instrument = _frame(root, "ShipInstrument")
	instrument.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	instrument.offset_left = -325
	instrument.offset_right = 325
	instrument.offset_top = -190
	instrument.offset_bottom = -48
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	instrument.add_child(layout)
	instrument_title = _text_to(layout, "舰况 / 巡航", 14)
	instrument_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instrument_title.add_theme_color_override("font_color", UISkin.MUTED)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	layout.add_child(row)
	var defense: VBoxContainer = VBoxContainer.new()
	defense.custom_minimum_size.x = 145
	defense.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defense.add_theme_constant_override("separation", 6)
	row.add_child(defense)
	for index: int in range(3):
		var name_value: String = ["护盾", "装甲", "结构"][index]
		var label: Label = _text_to(defense, name_value, 13)
		label.custom_minimum_size.x = 0
		var bar: ProgressBar = _bar(defense, [UISkin.ICE, UISkin.AMBER, Color("a6b2be")][index], 5)
		condition_bars.append({"label": label, "bar": bar, "name": name_value})
	dial = UISkin.Dial.new()
	dial.name = "SpeedDial"
	dial.custom_minimum_size = Vector2(154, 125)
	row.add_child(dial)
	var resources: VBoxContainer = VBoxContainer.new()
	resources.custom_minimum_size.x = 145
	resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources.add_theme_constant_override("separation", 6)
	row.add_child(resources)
	energy_label = _text_to(resources, "电容", 13)
	energy_label.custom_minimum_size.x = 0
	energy_bar = _bar(resources, UISkin.ICE, 5)
	heat_label = _text_to(resources, "热量", 13)
	heat_label.custom_minimum_size.x = 0
	heat_bar = _bar(resources, UISkin.AMBER, 5)
	cargo_label = _text_to(resources, "载荷", 12)
	cargo_label.custom_minimum_size.x = 0
	cargo_label.add_theme_color_override("font_color", UISkin.MUTED)
	health = _label(root, "", 12)
	health.hide() # 保留测试/辅助读取接口，正式仪表只使用条形与弧形读数。

func _build_navigation() -> void:
	navigation = _frame(root, "FlightNavigation")
	navigation.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	navigation.offset_left = -220
	navigation.offset_right = 220
	navigation.offset_top = -58
	navigation.offset_bottom = -8
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	navigation.add_child(row)
	for key: String in ["missions", "map", "pause"]:
		var title: String = {"missions": "任务  J", "map": "星图  M", "pause": "系统  Esc"}[key]
		var button: Button = _button(row, title, show_page.bind(key))
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(104, 25)
		button.add_theme_font_size_override("font_size", 12)
		_secondary(button)
		button.add_theme_stylebox_override("normal", UISkin.flat(Color(0.08, 0.105, 0.125, 0.65), Color("384650"), 4))
		button.add_theme_stylebox_override("hover", UISkin.flat(Color("253b45"), UISkin.ICE, 4))
		button.add_theme_stylebox_override("pressed", UISkin.flat(Color("192b34"), UISkin.ICE, 4))

func _build_target_module() -> void:
	target_panel = _frame(root, "TargetModule")
	target_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	target_panel.offset_left = -270
	target_panel.offset_right = -22
	target_panel.offset_top = 22
	target_panel.offset_bottom = 390
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	target_panel.add_child(layout)
	_module_heading(layout, "目标识别", "Tab 切换 / 点击选中")
	npc_detail = VBoxContainer.new()
	npc_detail.add_theme_constant_override("separation", 4)
	layout.add_child(npc_detail)
	npc_title = _text_to(npc_detail, "", 15)
	for layer_name: String in ["护盾", "装甲", "结构"]:
		var label: Label = _text_to(npc_detail, layer_name, 12)
		var bar: ProgressBar = _bar(npc_detail, UISkin.ICE if layer_name == "护盾" else UISkin.AMBER if layer_name == "装甲" else Color("a6b2be"), 7)
		npc_bars.append({"label": label, "bar": bar, "name": layer_name})
	npc_detail.hide()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "TargetScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	target_list = VBoxContainer.new()
	target_list.add_theme_constant_override("separation", 6)
	target_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(target_list)

func _update_instrument(ship: Dtos.ShipStateDto, metrics: Dictionary) -> void:
	var values: Array[float] = [ship.shield, ship.armor, ship.hull]
	var maximums: Array[float] = [float(metrics.shield_max), float(metrics.armor_max), float(metrics.hull_max)]
	var signature: String = JSON.stringify([ship.ship_def_id, ship.shield, ship.armor, ship.hull, ship.energy, ship.heat, ship.overheated, Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length(), metrics.shield_max, metrics.armor_max, metrics.hull_max, metrics.energy_max, metrics.heat_max, metrics.cargo_used_l, metrics.cargo_capacity_l, metrics.mineral_used_l, metrics.mineral_capacity_l])
	if signature == telemetry_signature: return
	telemetry_signature = signature
	instrument_title.text = _ship_name(ship.ship_def_id) + "  /  " + ("过热警报" if ship.overheated else "巡航状态")
	instrument_title.modulate = UISkin.AMBER if ship.overheated else Color.WHITE
	for index: int in range(3):
		condition_bars[index].label.text = "%s  %.0f / %.0f" % [condition_bars[index].name, values[index], maximums[index]]
		condition_bars[index].bar.max_value = maxf(maximums[index], 1.0)
		condition_bars[index].bar.value = values[index]
	dial.speed = Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length()
	dial.ratios = Vector3(values[0] / maxf(maximums[0], 1.0), values[1] / maxf(maximums[1], 1.0), values[2] / maxf(maximums[2], 1.0))
	dial.queue_redraw()
	energy_label.text = "电容  %.0f / %.0f" % [ship.energy, float(metrics.energy_max)]
	energy_bar.max_value = maxf(float(metrics.energy_max), 1.0)
	energy_bar.value = ship.energy
	heat_label.text = "热量  %.0f%%" % (ship.heat / maxf(float(metrics.heat_max), 1.0) * 100)
	heat_bar.max_value = maxf(float(metrics.heat_max), 1.0)
	heat_bar.value = ship.heat
	cargo_label.text = "货 %.0f/%.0f L · 矿 %.0f/%.0f L" % [float(metrics.cargo_used_l), float(metrics.cargo_capacity_l), float(metrics.mineral_used_l), float(metrics.mineral_capacity_l)]

func _update_station_info() -> void:
	if state == null or not is_instance_valid(station_ship_status): return
	var metrics: Dictionary = gameplay.call("metrics", state.ship())
	station_ship_name.text = _ship_name(state.ship().ship_def_id)
	station_ship_status.text = "护盾  %.0f / %.0f\n装甲  %.0f / %.0f\n结构  %.0f / %.0f\n\n电容  %.0f / %.0f\n热量  %.0f%%\n\n货舱  %.0f / %.0f L\n矿舱  %.0f / %.0f L" % [state.ship().shield, float(metrics.shield_max), state.ship().armor, float(metrics.armor_max), state.ship().hull, float(metrics.hull_max), state.ship().energy, float(metrics.energy_max), state.ship().heat / maxf(float(metrics.heat_max), 1.0) * 100, float(metrics.cargo_used_l), float(metrics.cargo_capacity_l), float(metrics.mineral_used_l), float(metrics.mineral_capacity_l)]

func _npc_service(parent: Node, portrait: int, title: String, subtitle: String, destination: String) -> void:
	# Two sibling buttons keep viewing a person separate from opening their service.
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "NpcCard" + str(portrait)
	row.custom_minimum_size.y = 87
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var roles: Array[String] = ["operations", "supplies", "industry", "research"]
	var view: Button = _command(row, "", "hangar_focus", roles[portrait])
	view.name = "NpcPortrait" + str(portrait)
	view.tooltip_text = "查看人员 · " + subtitle
	view.custom_minimum_size = Vector2(70, 87)
	var image: TextureRect = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2(62, 62)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	image.offset_left = 4
	image.offset_right = -4
	image.offset_top = 8
	image.offset_bottom = 70
	var atlas: Texture2D = UISkin.texture("res://assets/interface_v2/npc_portraits.png")
	if atlas != null:
		var region: AtlasTexture = AtlasTexture.new()
		region.atlas = atlas
		region.region = Rect2(Vector2((portrait % 2) * atlas.get_width() * 0.5, floori(portrait / 2.0) * atlas.get_height() * 0.5), Vector2(atlas.get_size()) * 0.5)
		image.texture = region
	station_portraits.append(image)
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", UISkin.flat(Color(0.04, 0.07, 0.09, 0.92), UISkin.ICE, 0))
	view.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	badge.offset_left = 4
	badge.offset_right = -4
	badge.offset_top = 52
	badge.offset_bottom = 72
	var badge_text: Label = _label(badge, "查看", 11)
	badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_text.add_theme_color_override("font_color", UISkin.ICE)
	var button: Button = _button(row, "", show_page.bind(destination))
	button.name = "NpcService" + str(portrait)
	button.custom_minimum_size = Vector2(0, 87)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = title + " · 打开服务"
	var caption: VBoxContainer = VBoxContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left = 8
	caption.offset_right = -8
	caption.offset_top = 10
	caption.offset_bottom = -10
	var heading: Label = _text_to(caption, title, 13 if root.size.x < 950 else 15)
	heading.name = "NpcServiceTitle"
	heading.custom_minimum_size.x = 0
	var detail: Label = _text_to(caption, subtitle, 11)
	detail.custom_minimum_size.x = 0
	detail.add_theme_color_override("font_color", UISkin.MUTED)

func _primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", UISkin.button_style(Color("e2b46d")))
	button.add_theme_color_override("font_color", Color("ffdf9d"))

func _secondary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", UISkin.flat(Color(0.08, 0.105, 0.125, 0.65), Color("384650"), 8))
	button.add_theme_color_override("font_color", UISkin.MUTED)

func _back() -> void:
	var destination: String = return_page if page == "settings" and not return_page.is_empty() else "title" if state == null else "station" if state.player().has_docked_station_id else ""
	show_page(destination)

func _responsive_title() -> void:
	if page != "title" or not is_instance_valid(panel): return
	var width: float = root.size.x
	var compact: bool = width < 950
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 28 if compact else 80
	panel.offset_right = minf(width - 28, 430 if compact else 520)
	panel.offset_top = 28 if compact else 120
	panel.offset_bottom = -50 if compact else -100

func _button_feedback(candidate: Variant, hovering: bool) -> void:
	# A queued signal can outlive the page; validate before casting a freed Object.
	if not is_instance_valid(candidate) or not candidate is Button: return
	var button: Button = candidate
	if button.is_queued_for_deletion() or not button.is_inside_tree() or button.disabled: return
	# A null get_meta default still reports a missing key; first hover has no tween.
	var old: Variant = button.get_meta("hover_tween") if button.has_meta("hover_tween") else null
	if is_instance_valid(old) and old is Tween and old.is_valid(): old.kill()
	var animation: Tween = button.create_tween()
	animation.tween_property(button, "modulate", Color(1.09, 1.09, 1.09, 1.0) if hovering else Color.WHITE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.set_meta("hover_tween", animation)

func _animate_panel() -> void:
	if ui_motion != null and ui_motion.is_valid(): ui_motion.kill()
	panel.modulate.a = 0.0
	ui_motion = create_tween()
	ui_motion.tween_property(panel, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _focus_controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.focus_mode != Control.FOCUS_NONE and not (child is BaseButton and child.disabled): result.append(child)
		result.append_array(_focus_controls(child))
	return result

func _focus_page() -> void:
	if not is_instance_valid(body) or page.is_empty():
		root.get_viewport().gui_release_focus()
		return
	var entries: Array[Control] = _focus_controls(station_layer if page == "station" else panel)
	if is_instance_valid(operation_bar) and operation_bar.visible:
		entries.append_array(_focus_controls(operation_bar))
	for index: int in range(entries.size()):
		entries[index].focus_next = entries[(index + 1) % entries.size()].get_path()
		entries[index].focus_previous = entries[(index - 1 + entries.size()) % entries.size()].get_path()
		entries[index].focus_neighbor_bottom = entries[index].focus_next
		entries[index].focus_neighbor_top = entries[index].focus_previous
	var default: Array[Control] = _focus_controls(body)
	for entry: Control in default:
		if entry is Button and not entry.disabled:
			entry.grab_focus()
			return
	if not default.is_empty(): default[0].grab_focus()
	elif not entries.is_empty(): entries[0].grab_focus()
