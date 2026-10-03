class_name XJUI
extends CanvasLayer
signal requested(action: String, target: String, quantity: int, extra: String)
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
const NavigationHUD = preload("res://runtime/ui/navigation_hud.gd")
const OverviewPanel = preload("res://runtime/ui/overview_panel.gd")
const EquipmentBar = preload("res://runtime/ui/equipment_bar.gd")
const Context = preload("res://runtime/interaction_context.gd")
const ResourceStatus = preload("res://runtime/resource_status.gd")
const BusinessList = preload("res://runtime/ui/business_list.gd")
const ItemPortraits = preload("res://runtime/ui/item_portraits.gd")
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
var compact_speed_label: Label
var show_ship_button: Button
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
var navigation_hud: XJNavigationHUD
var interaction_button: Button
var interaction_label: Label
var interaction_candidate: Dictionary = {}
var overview: PanelContainer
var equipment_bar: PanelContainer
var navigation_frame: PanelContainer
var navigation_status: Label
var navigation_stop_button: Button
var map_resource_readouts: Array[Dictionary] = []
var resource_chart: Control
var flight_dock: HBoxContainer
var top_toolbar_frame: PanelContainer
var toolbar_buttons: Dictionary = {}
var flight_content_top: float = 0.0
var flight_content_bottom: float = 0.0

func set_operation_status(kind: String, message: String, waiting: bool = false) -> void:
	operation_kind = kind
	operation_message = _friendly(message)
	operation_waiting = waiting
	if is_instance_valid(operation_bar):
		operation_bar.visible = kind not in ["idle", "local_navigation"] and not message.is_empty()
		operation_label.text = operation_message
		operation_label.tooltip_text = operation_message
		operation_cancel.visible = waiting and "save" in kind
		_responsive()
		_update_navigation()

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
	navigation_hud = NavigationHUD.new()
	navigation_hud.name = "NavigationHUD"
	root.add_child(navigation_hud)
	navigation_hud.selection_readout_enabled = false
	navigation_hud.selected.connect(_select_target)
	navigation_frame = _frame(root, "NavigationStatus")
	navigation_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	navigation_frame.add_theme_stylebox_override("panel", UISkin.hud_panel(8))
	var navigation_layout: VBoxContainer = VBoxContainer.new()
	navigation_layout.add_theme_constant_override("separation", 3)
	navigation_frame.add_child(navigation_layout)
	top = _text_to(navigation_layout, "航行", 14)
	top.add_theme_color_override("font_color", UISkin.AMBER)
	var navigation_row: HBoxContainer = HBoxContainer.new()
	navigation_row.add_theme_constant_override("separation", 4)
	navigation_layout.add_child(navigation_row)
	navigation_status = _text_to(navigation_row, "手动航行", 11)
	navigation_status.max_lines_visible = 2
	navigation_stop_button = _button(navigation_row, "停止", func(): requested.emit("nav_stop", target_id, 1, ""))
	navigation_stop_button.custom_minimum_size = Vector2(40, 22)
	navigation_stop_button.focus_mode = Control.FOCUS_NONE
	navigation_stop_button.add_theme_stylebox_override("normal", UISkin.hud_button(false))
	navigation_stop_button.add_theme_font_size_override("font_size", 10)
	navigation_stop_button.hide()
	var objective_frame: PanelContainer = _frame(root, "FlightObjective")
	objective_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	objective_frame.offset_left = 22
	objective_frame.offset_top = 106
	objective_frame.offset_right = 342
	objective_frame.offset_bottom = 214
	objective_frame.add_theme_stylebox_override("panel", UISkin.hud_panel(8))
	hud_left = VBoxContainer.new()
	hud_left.add_theme_constant_override("separation", 9)
	hud_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_frame.add_child(hud_left)
	var mission_heading: Label = _text_to(hud_left, "航行任务", 11)
	mission_heading.name = "MissionHeading"
	mission_heading.add_theme_color_override("font_color", UISkin.AMBER)
	objective = _text_to(hud_left, "", 14)
	objective.max_lines_visible = 4
	work_box = VBoxContainer.new()
	work_box.add_theme_constant_override("separation", 5)
	hud_left.add_child(work_box)
	work_label = _text_to(work_box, "", 13)
	work_label.mouse_filter = Control.MOUSE_FILTER_PASS
	work_progress = _bar(work_box, UISkin.AMBER, 6)
	work_progress.show_percentage = true
	work_stop = _button(work_box, "停止作业", func(): requested.emit("stop_scan" if work_mode == "scan" else "stop_mining", "", 1, ""))
	work_stop.custom_minimum_size.y = 24
	work_stop.focus_mode = Control.FOCUS_NONE
	work_stop.add_theme_stylebox_override("normal", UISkin.hud_button(false))
	work_box.hide()
	flight_dock = HBoxContainer.new()
	flight_dock.name = "FlightDock"
	flight_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	flight_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	root.add_child(flight_dock)
	_build_instrument()
	_build_equipment_bar()
	_build_navigation()
	controls = _label(root, "左拖视角 · 双击总览接近 · 滚轮缩放", 11)
	controls.mouse_filter = Control.MOUSE_FILTER_PASS
	controls.tooltip_text = "光标常驻；左键短击模型、总览或雷达只选择目标，长按拖动观察，松开保留角度；双击总览目标自动转向并接近。W/S 沿当前观察航向加速/反向加速，A/D 左右转弯；Space/C 升降、Q/E 滚转；Ctrl 发射、Z 自动开火、X 停船、Shift 增推、F 交互、V 视角。右键禁用。"
	show_ship_button.tooltip_text += "\n\n" + controls.tooltip_text
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 22
	controls.offset_top = -37
	controls.offset_right = 302
	controls.add_theme_color_override("font_color", UISkin.MUTED)
	toast = _label(root, "", 14)
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	toast.offset_left = 370
	toast.offset_right = -320
	toast.offset_top = 22
	toast.offset_bottom = 68
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.mouse_filter = Control.MOUSE_FILTER_PASS
	toast.max_lines_visible = 2
	_build_target_module()
	operation_bar = _frame(root, "OperationStatus")
	operation_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
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
	operation_label.mouse_filter = Control.MOUSE_FILTER_PASS
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
	navigation_hud.configure(sector, camera, catalog)
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
		_responsive()
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
	_responsive.call_deferred()
	_focus_page.call_deferred()

func notify(message: String, is_error: bool = false) -> void:
	toast.text = _friendly(message)
	toast.tooltip_text = toast.text
	toast.modulate = Color("ff8578") if is_error else UISkin.AMBER
	_responsive()
	message_age = 0.0

func tick(delta: float) -> void:
	message_age += delta
	if message_age > 12.0 and not toast.text.is_empty():
		toast.text = ""
		_responsive()
	marker_layer.queue_redraw()
	# Selection projection follows the current frame, independently of telemetry.
	if is_instance_valid(navigation_hud):
		navigation_hud.selected_id = target_id
		navigation_hud.selection_obstructed = is_instance_valid(operation_bar) and operation_bar.visible
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
		top.text = "%s · %s" % [_sector_name(ship.sector_id), _risk_name(str(definition.get("risk_zone_id", "")))]
		health.text = "护盾 %.0f%% · 装甲 %.0f%% · 结构 %.0f%%\n电容 %.0f%% · 热量 %.0f%% %s\n速度 %.0f m/s · 货 %.0f/%.0f L" % [ship.shield / maxf(metrics.shield_max, 1.0) * 100, ship.armor / maxf(metrics.armor_max, 1.0) * 100, ship.hull / maxf(metrics.hull_max, 1.0) * 100, ship.energy / maxf(metrics.energy_max, 1.0) * 100, ship.heat / maxf(metrics.heat_max, 1.0) * 100, "过热" if ship.overheated else "", Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length(), metrics.cargo_used_l + metrics.mineral_used_l, metrics.cargo_capacity_l + metrics.mineral_capacity_l]
	objective.text = _objective_text()
	objective.tooltip_text = objective.text
	_update_instrument(ship, metrics)
	_update_module_bar(ship, metrics)
	if page == "station": _update_station_info()
	_update_work()
	_reflow_flight_left()
	_update_live_missions()
	_update_map_resources()
	_refresh_targets()
	_update_npc_target()
	_update_navigation()
	navigation_hud.update_annotations()

func input_blocked() -> bool:
	return ui_input_blocked()

func ui_input_blocked() -> bool:
	return keyboard_blocked() or _pointer_over(target_panel) or _pointer_over(work_box) or _pointer_over(operation_bar) or _pointer_over(navigation) or _pointer_over(flight_dock) or _pointer_over(instrument) or _pointer_over(equipment_bar) or _pointer_over(navigation_frame) or _pointer_over(controls) or _pointer_over(toast) or (is_instance_valid(navigation_hud) and _pointer_over(navigation_hud.radar_frame))

func keyboard_blocked() -> bool:
	var focus: Control = root.get_viewport().gui_get_focus_owner()
	return menu_open or panel.visible or station_layer.visible or focus is LineEdit or focus is TextEdit

func refresh_page() -> void:
	if not page.is_empty() and page != "settings" and page != "title":
		var previous_scroll: int = page_scroll.scroll_vertical if is_instance_valid(page_scroll) else 0
		show_page(page)
		if is_instance_valid(page_scroll): page_scroll.set_deferred("scroll_vertical", previous_scroll)

func select_next() -> void:
	if sector == null:
		return
	var keys: Array[String] = []
	for entry: Dictionary in sector.targets.values():
		var node: Variant = entry.get("node")
		if not is_instance_valid(node) or not node is Node3D: continue
		if str(entry.get("kind", "")) != "npc" or sector.flight.global_position.distance_to(node.global_position) <= float(catalog.rule("target_marker_detection_range_m")):
			keys.append(str(entry.id))
	if keys.is_empty():
		target_id = ""
		return
	_select_target(str(keys[(keys.find(target_id) + 1) % keys.size()]))

func _build_panel(title: String, description: String) -> void:
	for child: Node in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	quotes.clear()
	live_missions.clear()
	map_resource_readouts.clear()
	resource_chart = null
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
	sidebar.visible = root.size.x >= 950 and state != null and page not in ["title", "settings"]
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
	var overview_button: Button = _command(shortcuts, "观察舰船", "hangar_focus")
	overview_button.name = "HangarOverview"
	_secondary(overview_button)
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
	var list: VBoxContainer = _business_list("舰体与借船", "单价 / 服务费", "数量")
	list.call("add_section", "自有舰队")
	for row: Dtos.ShipStateDto in state.rows("ship_state"):
		if row.status in [Types.ShipStatus.RETURNED, Types.ShipStatus.DESTROYED]: continue
		var local: bool = row.status == Types.ShipStatus.DOCKED and row.station_id == state.player().docked_station_id
		var current: bool = row.ship_instance_id == state.ship().ship_instance_id
		var may_sell: bool = bool(_one("asset_policy_defs", "policy_id", row.policy_id).get("may_sell", false))
		var sale_reason: String = _ship_sale_reason(row) if may_sell else "保障 / 借用舰体不可出售"
		var has_quote: bool = may_sell and state.rows("shop_ship_stock_state").any(func(stock: Dtos.ShopShipStockStateDto): return stock.station_id == state.player().docked_station_id and stock.ship_def_id == row.ship_def_id)
		var price: int = int(gameplay.get("economy").call("quote_ship", row.ship_instance_id, true)) if has_quote else 0
		var entry: Dictionary = _asset_row(list, row.ship_instance_id, "ship", row.ship_def_id, _ship_name(row.ship_def_id), _ship_description(row.ship_def_id) + "\n结构 %.0f · 装甲 %.0f · %s" % [row.hull, row.armor, _policy_name(row.policy_id)], "艘", "1", str(price) if has_quote else "—", str(price) if has_quote else "—", ("当前驾驶" if current else "停靠 " + _station_name(row.station_id) if row.status == Types.ShipStatus.DOCKED else "位于 " + _sector_name(row.sector_id)) + ("\n" + sale_reason if not sale_reason.is_empty() else "\n可出售裸舰；设备与货物移入仓库"))
		var switch: Button = _command(entry.actions, "切换驾驶", "switch_ship", row.ship_instance_id)
		switch.disabled = not local or current or row.owner_player_id != state.player().player_id
		if may_sell:
			var sell: Button = _command(entry.actions, "出售舰体", "sell_ship", row.ship_instance_id)
			sell.disabled = not sale_reason.is_empty()
			sell.tooltip_text = sale_reason if not sale_reason.is_empty() else "实收 %d 信用点；普通设备与货物移入本站仓库。" % price
	list.call("add_section", "任务舰领取与换发")
	for definition: Dictionary in _defs("loan_service_defs"):
		if definition.station_id != state.player().docked_station_id: continue
		var loadout: Dictionary = _one("ship_loadout_defs", "loadout_id", str(definition.loadout_id))
		var mission: Dtos.MissionStateDto = _latest_mission(str(definition.required_mission_id))
		var reason: String = _service_reason("loan")
		if not _unlocked(str(definition.required_unlock_id)): reason = "需解锁 " + _unlock_name(str(definition.required_unlock_id))
		elif mission == null or mission.status not in ["active", "ready"]: reason = "需先接取 " + _mission_name(str(definition.required_mission_id))
		var loan: Dtos.LoanStateDto
		for candidate: Dtos.LoanStateDto in state.rows("loan_state"):
			if candidate.loan_service_id == definition.loan_service_id and mission != null and candidate.mission_instance_id == mission.mission_instance_id: loan = candidate
		if loan != null and loan.status == Types.LoanStatus.ACTIVE: reason = "已有借船在使用"
		elif loan != null and loan.replacement_remaining_s > 0: reason = "补领等待 %.0f 秒" % loan.replacement_remaining_s
		elif loan != null and loan.status == Types.LoanStatus.LOST and not bool(definition.get("replace_destroyed", false)): reason = "此合同不提供损毁换发"
		if state.player().credit < int(definition.fee_credit): reason = "信用点不足"
		for other: Dtos.LoanStateDto in state.rows("loan_state"):
			if other.status in [Types.LoanStatus.ACTIVE, Types.LoanStatus.LOST] and (mission == null or other.mission_instance_id != mission.mission_instance_id or other.loan_service_id != definition.loan_service_id): reason = "已有另一份有效借船"
		var ship_id: String = str(loadout.get("ship_id", ""))
		var entry: Dictionary = _asset_row(list, str(definition.loan_service_id), "ship", ship_id, "任务借船 · " + _ship_name(ship_id), _ship_description(ship_id) + "\n归还 " + _station_name(str(definition.return_station_id)) + "；绑定设备不可交易，换发保留任务与采额。", "艘", "1", str(int(definition.fee_credit)), str(int(definition.fee_credit)), reason if not reason.is_empty() else "可领取 / 换领")
		var claim: Button = _command(entry.actions, "领取 / 换领", "claim_loan", str(definition.loan_service_id))
		claim.disabled = not reason.is_empty()
	list.call("add_section", "借船归还")
	for loan: Dtos.LoanStateDto in state.rows("loan_state"):
		if loan.status not in [Types.LoanStatus.ACTIVE, Types.LoanStatus.LOST]: continue
		var definition: Dictionary = _one("loan_service_defs", "loan_service_id", loan.loan_service_id)
		var loadout: Dictionary = _one("ship_loadout_defs", "loadout_id", str(definition.get("loadout_id", "")))
		var description: String = "返航 " + _station_name(str(definition.get("return_station_id", ""))) + " 后归还；普通战利品转入当地仓库。"
		if loan.has_quota_remaining_units:
			var quota_note := "教学样本丢失可补采缺额，已有有效样本不会重复补领" if definition.get("gathered_policy_id", "") == "mission_bound" else "普通合同累计额度；补领不会恢复额度"
			description += "\n剩余可采额度 %d · %s" % [loan.quota_remaining_units, quota_note]
		var ship_id: String = str(loadout.get("ship_id", ""))
		var entry: Dictionary = _asset_row(list, loan.loan_id, "ship", ship_id, "借船管理 · " + _ship_name(ship_id), description, "艘", "1", "—", "—", "借船使用中" if loan.status == Types.LoanStatus.ACTIVE else "舰体已损失")
		var handoff: Button = _command(entry.actions, "归还并换舰", "handoff_loan", loan.loan_id)
		handoff.disabled = definition.get("return_station_id") != state.player().docked_station_id

func _warehouse() -> void:
	_quantity()
	_text("仅显示当前站点仓库和当前驾驶舰的货舱。保护或任务绑定物资保留用途限制。", 14)
	var warehouse: String = _warehouse_id()
	var cargo: String = _ship_container(Types.ContainerKind.CARGO)
	var mineral: String = _ship_container(Types.ContainerKind.MINERAL)
	var count: int = 0
	var list: VBoxContainer = _business_list("本地货物与设备")
	list.call("add_section", "堆叠物资")
	for stack: Dtos.InventoryStackStateDto in state.rows("inventory_stack_state"):
		if not _local_container(stack.container_id): continue
		var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", stack.container_id)
		count += 1
		var entry: Dictionary = _asset_row(list, stack.stack_id, "item", stack.item_def_id, _item_name(stack.item_def_id), _item_description(stack.item_def_id), _item_unit(stack.item_def_id), str(stack.quantity), "—", "—", _container_name(container) + "\n" + _policy_name(stack.policy_id))
		if stack.policy_id != "normal_owned":
			entry.status.text += "\n仅供指定教学或合同使用"
			continue
		for destination: Dictionary in [{"id": warehouse, "title": "转入站点仓库"}, {"id": cargo, "title": "装入当前舰货舱"}, {"id": mineral, "title": "装入当前舰矿舱"}]:
			if not str(destination.id).is_empty() and stack.container_id != destination.id:
				_command(entry.actions, str(destination.title), "move_stack", stack.stack_id, str(destination.id))
	list.call("add_section", "独立设备")
	for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
		if not _local_container(item.container_id): continue
		var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", item.container_id)
		count += 1
		var entry: Dictionary = _asset_row(list, item.item_instance_id, "item", item.item_def_id, _item_name(item.item_def_id), _item_description(item.item_def_id) + "\n耐久 %.0f · 品质 %.2f" % [item.durability, item.quality_multiplier], _item_unit(item.item_def_id), "1", "—", "—", _container_name(container) + "\n" + _policy_name(item.policy_id))
		if item.policy_id != "normal_owned": continue
		if item.container_id != warehouse and not warehouse.is_empty(): _command(entry.actions, "移至站点仓库", "move_item", item.item_instance_id, warehouse)
		if item.container_id != cargo and not cargo.is_empty(): _command(entry.actions, "装入当前舰货舱", "move_item", item.item_instance_id, cargo)
	if count == 0: _text("本地没有可整理的货物。")

func _fitting() -> void:
	var metrics: Dictionary = gameplay.call("metrics", state.ship())
	_text("供能 %.0f/%.0f · 算力 %.0f/%.0f · 总质量 %.2f kg" % [metrics.power_used, metrics.power_capacity, metrics.cpu_used, metrics.cpu_capacity, metrics.total_mass_kg])
	var list: VBoxContainer = _business_list("舰船挂点与适配设备")
	list.call("add_section", "当前驾驶舰挂点")
	var empty_slots: Array[Dictionary] = []
	for container: Dtos.ContainerStateDto in state.rows("container_state"):
		if container.ship_instance_id != state.ship().ship_instance_id or container.kind != Types.ContainerKind.SLOT: continue
		var slot_type: String = ["weapon", "work", "utility", "structure"][int(container.slot_type)]
		var slot_name: String = "%s槽 %d" % [["武器", "作业", "通用", "结构"][int(container.slot_type)], container.slot_index + 1]
		var equipped: Dtos.EquipmentStateDto = state.find("equipment_state", "slot_container_id", container.container_id)
		if equipped != null:
			var item: Dtos.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", equipped.item_instance_id)
			var description: String = _item_description(equipped.module_def_id)
			if item != null: description += "\n耐久 %.0f · 品质 %.2f · %s" % [item.durability, item.quality_multiplier, _policy_name(item.policy_id)]
			var entry: Dictionary = _asset_row(list, equipped.item_instance_id, "item", equipped.module_def_id, _item_name(equipped.module_def_id), description, "件", "1", "—", "—", slot_name + "\n" + ("已启用" if equipped.enabled else "已关闭"))
			var unfit: Button = _command(entry.actions, "卸至仓库", "unfit_module", equipped.item_instance_id)
			unfit.disabled = item == null or item.policy_id != "normal_owned" or not _service_reason("fitting").is_empty()
			_command(entry.actions, "关闭设备" if equipped.enabled else "启用设备", "set_module_enabled", equipped.item_instance_id, "off" if equipped.enabled else "on")
		else:
			empty_slots.append({"type": slot_type, "index": container.slot_index, "title": slot_name})
			_asset_row(list, container.container_id, "generic", slot_type, slot_name, "空挂点；在下方设备列表选择适配模块安装。", "槽", "1", "—", "—", "未安装")
	list.call("add_section", "本地可安装设备")
	var available: int = 0
	for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
		if not _local_container(item.container_id) or item.policy_id != "normal_owned": continue
		var module: Dictionary = _one("module_defs", "module_id", item.item_def_id)
		if module.is_empty(): continue
		var compatible: Array[Dictionary] = []
		for empty: Dictionary in empty_slots:
			if str(module.slot_type) == str(empty.type): compatible.append(empty)
		available += 1
		var reason: String = _fitting_reason(item, metrics)
		if compatible.is_empty(): reason = "没有同类空挂点"
		var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", item.container_id)
		var entry: Dictionary = _asset_row(list, item.item_instance_id, "item", item.item_def_id, _item_name(item.item_def_id), _item_description(item.item_def_id) + "\n耐久 %.0f · 品质 %.2f" % [item.durability, item.quality_multiplier], "件", "1", "—", "—", reason if not reason.is_empty() else _container_name(container) + "\n可安装")
		for empty: Dictionary in compatible:
			var install: Button = _command(entry.actions, "安装至 " + str(empty.title), "fit_module", item.item_instance_id, "%s:%d" % [str(empty.type), int(empty.index)])
			install.disabled = not reason.is_empty()
	if available == 0: _text("本地没有可安装设备；可在市场购买或工业制造。", 14)

func _market() -> void:
	_quantity()
	var filters: HFlowContainer = HFlowContainer.new()
	body.add_child(filters)
	for filter: String in ["buy", "ships", "sell"]:
		var button: Button = _button(filters, str({"buy": "购买物资", "ships": "购买船体", "sell": "出售本地资产"}[filter]) + (" · 当前" if filter == market_filter else ""), func(): market_filter = filter; show_page("market"))
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size = Vector2(132, 36)
	_text("以下为选定数量的含税成交报价，包含当前声望优惠。成交时重新校验库存、额度和资金。", 14)
	var count: int = 0
	var list: VBoxContainer = _business_list("站点交易清单", "实收单价" if market_filter == "sell" else "含税单价", "成交数量")
	if market_filter == "buy":
		for stock: Dtos.ShopStockStateDto in state.rows("shop_stock_state"):
			if stock.station_id != state.player().docked_station_id: continue
			var definition: Dictionary = _stock_definition(stock.item_def_id)
			if not bool(definition.get("allow_buy", false)): continue
			count += 1
			var entry: Dictionary = _asset_row(list, stock.item_def_id, "item", stock.item_def_id, _item_name(stock.item_def_id), _item_description(stock.item_def_id), _item_unit(stock.item_def_id), str(quantity_value), "—", "—", "库存 %d" % stock.quantity)
			var button: Button = _command(entry.actions, "购买", "buy_item", stock.item_def_id)
			quotes.append(_quote_row(entry, {"kind": "item", "id": stock.item_def_id, "selling": false, "button": button, "maximum": stock.quantity, "unlock": str(definition.get("required_unlock_id", "")), "service": "trade", "status_prefix": "站点库存 %d" % stock.quantity}))
	elif market_filter == "ships":
		for stock: Dtos.ShopShipStockStateDto in state.rows("shop_ship_stock_state"):
			if stock.station_id != state.player().docked_station_id: continue
			count += 1
			var entry: Dictionary = _asset_row(list, stock.ship_def_id, "ship", stock.ship_def_id, _ship_name(stock.ship_def_id) + " · 裸舰", _ship_description(stock.ship_def_id) + "\n不含设备与弹药；舰体成交数量固定为一艘。", "艘", "1", "—", "—", "库存 %d" % stock.quantity)
			var button: Button = _command(entry.actions, "购买舰体", "buy_ship", stock.ship_def_id)
			var role: Dictionary = _one("ship_role_defs", "ship_id", stock.ship_def_id)
			quotes.append(_quote_row(entry, {"kind": "ship", "id": stock.ship_def_id, "selling": false, "button": button, "maximum": stock.quantity, "unlock": str(role.get("required_unlock_id", "")), "service": "ship_purchase", "status_prefix": "站点库存 %d" % stock.quantity}))
	else:
		var budget: Dtos.StationEconomyStateDto = state.find("station_economy_state", "station_id", state.player().docked_station_id)
		if budget != null: _text("本站本轮回购预算 %d 信用点" % budget.buyback_remaining_credit, 14)
		for stack: Dtos.InventoryStackStateDto in state.rows("inventory_stack_state"):
			if not _local_container(stack.container_id): continue
			var definition: Dictionary = _stock_definition(stack.item_def_id)
			if not bool(definition.get("allow_sell", false)): continue
			count += 1
			var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", stack.container_id)
			var entry: Dictionary = _asset_row(list, stack.stack_id, "item", stack.item_def_id, _item_name(stack.item_def_id), _item_description(stack.item_def_id) + "\n" + _container_name(container), _item_unit(stack.item_def_id), str(quantity_value), "—", "—", "持有 %d · %s" % [stack.quantity, _policy_name(stack.policy_id)])
			var button: Button = _command(entry.actions, "出售", "sell_item", stack.stack_id)
			quotes.append(_quote_row(entry, {"kind": "item", "id": stack.item_def_id, "selling": true, "button": button, "maximum": stack.quantity, "policy": stack.policy_id, "service": "trade", "status_prefix": "持有 %d · %s" % [stack.quantity, _policy_name(stack.policy_id)]}))
		for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
			if not _local_container(item.container_id): continue
			var definition: Dictionary = _stock_definition(item.item_def_id)
			if not bool(definition.get("allow_sell", false)): continue
			count += 1
			var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", item.container_id)
			var entry: Dictionary = _asset_row(list, item.item_instance_id, "item", item.item_def_id, _item_name(item.item_def_id), _item_description(item.item_def_id) + "\n耐久 %.0f · 品质 %.2f · %s" % [item.durability, item.quality_multiplier, _container_name(container)], "件", "1", "—", "—", _policy_name(item.policy_id))
			var button: Button = _button(entry.actions, "出售设备", func(): requested.emit("sell_item", item.item_instance_id, 1, ""))
			button.set_meta("action", "sell_item")
			button.set_meta("target", item.item_instance_id)
			button.set_meta("extra", "")
			button.set_meta("uses_quantity", false)
			quotes.append(_quote_row(entry, {"kind": "item", "id": item.item_def_id, "selling": true, "button": button, "maximum": 1, "fixed": 1, "policy": item.policy_id, "service": "trade", "status_prefix": _policy_name(item.policy_id)}))
	if count == 0: _text("此页没有当前站点可交易的资产。")
	_update_quotes()

func _industry() -> void:
	_quantity()
	_text("数量表示生产批数；材料仅取当前站点仓库的普通自有物资。费用包含设施优惠。", 14)
	var list: VBoxContainer = _business_list("生产与回收清单", "单位服务费", "数量 / 批数")
	list.call("add_section", "制造与提炼")
	for access: Dictionary in _defs("recipe_access_defs"):
		if access.station_id != state.player().docked_station_id: continue
		var recipe: Dictionary = _one("recipe_defs", "recipe_id", str(access.recipe_id))
		var item_id: String = str(recipe.get("output_item_id", ""))
		var entry: Dictionary = _asset_row(list, str(access.recipe_id), "item", item_id, "制造 / 提炼 · " + _item_name(item_id), _item_description(item_id) + "\n" + _inputs_text("recipe_inputs", "recipe_id", str(access.recipe_id)) + "\n每批产出 %d %s" % [int(recipe.get("output_quantity", 1)), _item_unit(item_id)], "批", str(quantity_value), "—", "—", "材料来自本站仓库")
		var button: Button = _command(entry.actions, "生产", "manufacture", str(access.recipe_id))
		quotes.append(_quote_row(entry, {"kind": "recipe", "id": str(access.recipe_id), "button": button, "unlock": str(access.required_unlock_id), "service": "manufacture", "inputs_table": "recipe_inputs", "inputs_key": "recipe_id", "status_prefix": "材料来自本站仓库"}))
	list.call("add_section", "船坞制造")
	for recipe: Dictionary in _defs("hull_recipe_defs"):
		var local_yard: bool = false
		for stock: Dtos.ShopShipStockStateDto in state.rows("shop_ship_stock_state"):
			if stock.station_id == state.player().docked_station_id and stock.ship_def_id == recipe.ship_id: local_yard = true
		if not local_yard: continue
		var entry: Dictionary = _asset_row(list, str(recipe.hull_recipe_id), "ship", str(recipe.ship_id), "船坞 · " + _ship_name(str(recipe.ship_id)), _ship_description(str(recipe.ship_id)) + "\n" + _inputs_text("hull_recipe_inputs", "hull_recipe_id", str(recipe.hull_recipe_id)) + "\n每批制造一艘裸舰，不含设备与弹药。", "批", str(quantity_value), "—", "—", "本站船坞")
		var button: Button = _command(entry.actions, "制造舰体", "manufacture", str(recipe.hull_recipe_id))
		quotes.append(_quote_row(entry, {"kind": "recipe", "id": str(recipe.hull_recipe_id), "button": button, "unlock": str(recipe.required_unlock_id), "service": "manufacture", "inputs_table": "hull_recipe_inputs", "inputs_key": "hull_recipe_id", "status_prefix": "本站船坞"}))
	list.call("add_section", "设备拆解 · 普通本地资产")
	for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
		if item.container_id != _warehouse_id() or item.policy_id != "normal_owned": continue
		var fee: int = int(catalog.rule("recycle_service_fee_credit"))
		var reason: String = _recycle_reason(item)
		var entry: Dictionary = _asset_row(list, item.item_instance_id, "item", item.item_def_id, "拆解 · " + _item_name(item.item_def_id), _item_description(item.item_def_id) + "\n按冻结材料来源回收；拆解后设备消失。", "件", "1", str(fee), str(fee), reason if not reason.is_empty() else "可拆解")
		var button: Button = _command(entry.actions, "拆解设备", "recycle", item.item_instance_id)
		button.disabled = not reason.is_empty()
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
	var list: VBoxContainer = _business_list("任务与合同清单", "接取费用", "合同数")
	for definition: Dictionary in filtered.slice(mission_page * 6, mini((mission_page + 1) * 6, filtered.size())):
		var current: Dtos.MissionStateDto = _latest_mission(str(definition.mission_id))
		var active: bool = current != null and current.status in ["active", "ready"]
		var reason: String = _mission_reason(definition, current)
		var entry: Dictionary = _asset_row(list, str(definition.mission_id), "mission", str(definition.mission_id), _mission_name(str(definition.mission_id)), _mission_list_description(definition, current), "份", "1", "—", "奖励 %d" % int(definition.get("reward_credit", 0)), _mission_status(current.status) if active else reason if not reason.is_empty() else "可接取")
		entry.row.set_meta("mission_row", true)
		if active:
			live_missions.append({"label": entry.status, "mission": current, "description": entry.description, "definition": definition, "progress": []})
			var target: String = _current_mission_target(current)
			if not target.is_empty() and sector != null and sector.targets.has(target):
				var locate: Button = _button(entry.actions, "定位目标", func(): target_id = target; _back())
				locate.set_meta("action", "locate_mission")
				locate.set_meta("target", target)
			var deliver: Button = _command(entry.actions, "交付任务", "deliver_mission", current.mission_instance_id)
			deliver.disabled = current.status != "ready" or state.player().docked_station_id != definition.turnin_station_id
			_command(entry.actions, "放弃任务", "abandon_mission", current.mission_instance_id)
		else:
			var accept: Button = _command(entry.actions, "接取任务" if current == null else "重新接取", "accept_mission", str(definition.mission_id))
			accept.disabled = not reason.is_empty()
	_update_live_missions()

func _research() -> void:
	var station_faction: String = str(_one("station_defs", "station_id", state.player().docked_station_id).get("faction_id", ""))
	var list: VBoxContainer = _business_list("科技与个人设施", "服务费", "数量")
	list.call("add_section", "势力研究")
	for definition: Dictionary in _defs("research_defs"):
		if definition.station_faction_id != station_faction: continue
		var done: bool = _unlocked(str(definition.reward_unlock_id))
		var reason: String = "已完成研究" if done else _service_reason("manufacture")
		for prerequisite: Dictionary in _defs("research_prerequisites"):
			if prerequisite.research_id == definition.research_id and not _unlocked(str(prerequisite.unlock_id)): reason = "需先解锁 " + _unlock_name(str(prerequisite.unlock_id))
		var reputation: int = int(gameplay.get("economy").call("reputation", station_faction))
		if not done and reputation < int(definition.required_reputation): reason = "声望 %d/%d" % [reputation, int(definition.required_reputation)]
		if not done and definition.get("verification_mission_id") != null and not _mission_completed(str(definition.verification_mission_id)): reason = "需先完成 " + _mission_name(str(definition.verification_mission_id))
		if not done and reason.is_empty(): reason = _materials_reason("research_inputs", "research_id", str(definition.research_id), 1)
		if not done and state.player().credit < int(definition.required_credit): reason = "信用点不足"
		var description: String = "解锁 " + _unlock_name(str(definition.reward_unlock_id)) + " · 需声望 %d\n" % int(definition.required_reputation) + _inputs_text("research_inputs", "research_id", str(definition.research_id))
		var entry: Dictionary = _asset_row(list, str(definition.research_id), "research", str(definition.research_id), str(definition.display_name), description, "项", "1", str(int(definition.required_credit)), str(int(definition.required_credit)), reason if not reason.is_empty() else "可研究")
		var button: Button = _command(entry.actions, "完成研究", "research", str(definition.research_id))
		button.disabled = not reason.is_empty()
	list.call("add_section", "本站个人设施")
	for definition: Dictionary in _defs("base_module_defs"):
		var built: bool = false
		for facility: RefCounted in state.rows("base_module_state"):
			if facility.station_id == state.player().docked_station_id and facility.base_module_id == definition.base_module_id: built = true
		var reason: String = "已建成" if built else _service_reason("manufacture")
		if not _unlocked(str(definition.required_unlock_id)): reason = "需解锁 " + _unlock_name(str(definition.required_unlock_id))
		if not built and reason.is_empty(): reason = _materials_reason("base_module_inputs", "base_module_id", str(definition.base_module_id), 1)
		if not built and state.player().credit < int(definition.service_fee_credit): reason = "信用点不足"
		var service: String = str({"industry": "工业", "repair": "维修", "navigation": "导航", "warehouse": "仓储"}.get(str(definition.service_kind), "站点"))
		var description: String = "%s设施 · 效率系数 %.2f\n%s" % [service, float(definition.effect_multiplier), _inputs_text("base_module_inputs", "base_module_id", str(definition.base_module_id))]
		var entry: Dictionary = _asset_row(list, str(definition.base_module_id), "facility", str(definition.base_module_id), str(definition.display_name), description, "座", "1", str(int(definition.service_fee_credit)), str(int(definition.service_fee_credit)), reason if not reason.is_empty() else "可建造")
		var button: Button = _command(entry.actions, "设施已建成" if built else "建造设施", "build_base", str(definition.base_module_id))
		button.disabled = not reason.is_empty()
	_text("已解锁科技与资格", 20)
	for row: Dtos.UnlockStateDto in state.rows("unlock_state"): _text(_unlock_name(row.unlock_id), 14)
	for reputation: Dtos.ReputationStateDto in state.rows("reputation_state"):
		_text("%s · 声望 %d" % [str(_one("faction_defs", "faction_id", reputation.faction_id).get("display_name", "未知势力")), reputation.reputation], 14)

func _map() -> void:
	_text("虫洞门连接星系。星图只展示航路，定位只选择目标；同星系可跃迁或接近门口，减速后按 F 穿过虫洞。准入与冷却在交互时校验。", 14)
	if ResourceLoader.exists("res://runtime/ui/star_chart.gd"):
		var chart_script: Script = load("res://runtime/ui/star_chart.gd")
		var chart: Control = chart_script.new()
		body.add_child(chart)
		chart.call("configure", catalog, state)
		resource_chart = chart
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
				if resource.sector_id != sector_def.sector_id: continue
				var readout: Label = _text_to(card, _resource_map_readout(str(resource.node_id), str(resource.sector_id)), 13)
				readout.name = "ResourceIntel_" + str(resource.node_id).validate_node_name()
				readout.tooltip_text = readout.text + "\n矿量来自当前世界的SQLite状态；再生按世界时间推进，暂停与退出不推进。"
				map_resource_readouts.append({"node_id": str(resource.node_id), "sector_id": str(resource.sector_id), "label": readout})
				if resource.sector_id == state.current_sector():
					_button(card, "定位 " + _item_name(str(resource.item_id)) + "矿点", func(): _select_target(str(resource.node_id)); _back())
			for endpoint: Dictionary in _defs("gate_endpoint_defs"):
				if endpoint.origin_sector_id != sector_def.sector_id: continue
				_text_to(card, "航路 → " + _sector_name(str(endpoint.target_sector_id)), 14)
				if endpoint.origin_sector_id == state.current_sector(): _button(card, "定位通往 " + _sector_name(str(endpoint.target_sector_id)) + " 的虫洞门", func(): target_id = str(endpoint.endpoint_id); _back())

func _pause() -> void:
	_text("世界时间已暂停。保存成功后才会更新存档；等待中的保存可取消。", 14)
	var flight_card: VBoxContainer = _card("航行控制")
	var resume: Button = _wide_button(_button(flight_card, "继续航行", _back))
	_primary(resume)
	_secondary(_wide_button(_button(flight_card, "设置", show_page.bind("settings"))))
	_text_to(flight_card, "光标常驻：左键短击只选目标，长按拖动观察；双击总览目标自动转向并接近。拖动松开后保留角度，滚轮缩放，右键禁用。", 13)
	_text_to(flight_card, "W/S 沿当前观察航向加速/反向加速，A/D 左右转弯；Space/C 升降、Q/E 滚转；Ctrl 发射、Z 自动开火、X 停船、Shift 增推、F 交互、V 视角。X 只停船；左拖看向上方后按 W 可向上航行。", 13)
	var rescue: Button = _wide_button(_command(flight_card, "舰船损失后返回保障站", "request_rescue"))
	rescue.name = "RescueButton"
	rescue.disabled = state.ship().status != Types.ShipStatus.DESTROYED
	_text_to(flight_card, "仅在驾驶舰损毁后可请求救援。", 13).add_theme_color_override("font_color", UISkin.MUTED)
	var session_card: VBoxContainer = _card("保存与离开")
	_text_to(session_card, "保存完成后再离开；保存请求仍受当前航行状态校验。", 13)
	_primary(_wide_button(_button(session_card, "快速保存", func(): requested.emit("save", "0", 1, "quick"))))
	_secondary(_wide_button(_button(session_card, "保存并返回主菜单", func(): requested.emit("return_title", "", 1, ""))))
	_secondary(_wide_button(_button(session_card, "保存并退出", func(): requested.emit("quit", "", 1, ""))))
	if operation_waiting and operation_kind == "save":
		_wide_button(_command(session_card, "取消等待中的保存", "cancel_save"))
	_show_slots(true)
	_text("谨慎操作", 20)
	var danger: VBoxContainer = _card("放弃本次未保存进度")
	_text_to(danger, "此操作直接退出；下次从最后成功存档恢复。本次尚未保存的变化会丢失。", 14)
	var discard: Button = _wide_button(_button(danger, "放弃未保存进度并退出", func(): requested.emit("quit_without_save", "", 1, "")))
	discard.name = "QuitWithoutSave"
	discard.add_theme_stylebox_override("normal", UISkin.button_style(Color("c88d79")))
	discard.add_theme_color_override("font_color", Color("efbca6"))

func _settings() -> void:
	if preferences.is_empty():
		_text("偏好尚未加载，请稍后重新打开设置。")
		return
	for field: String in ["master_volume", "mouse_sensitivity", "vfx_intensity"]:
		var title: String = {"master_volume": "主音量", "mouse_sensitivity": "观察灵敏度", "vfx_intensity": "特效强度"}[field]
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
	_text("观察灵敏度调整左键拖动镜头；普通鼠标移动不控制舰船。主音量为 0 时静音。")
	var quality_row: HFlowContainer = HFlowContainer.new()
	body.add_child(quality_row)
	for quality: String in ["high", "medium", "low"]:
		var label: String = {"high": "高", "medium": "中", "low": "低"}[quality]
		_button(quality_row, "画质 · " + label + ("（当前）" if preferences.get("quality_mode") == quality else ""), func(): requested.emit("preference", "quality_mode", 1, quality))

func _show_slots(allow_save: bool = false) -> void:
	var shown: Array[String] = []
	if allow_save and state != null:
		_text("手动存档", 20)
		for index: int in range(5):
			var existing: Dictionary = {}
			for slot: Dictionary in slots:
				if str(slot.get("world_id", "")) == state.world_id and str(slot.get("slot_kind", "")) == "manual" and int(slot.get("slot_index", -1)) == index:
					existing = slot
					shown.append(str(slot.slot_id))
					break
			_slot_card(existing, "手动槽 %d" % (index + 1), index)
	var remaining: Array[Dictionary] = []
	for slot: Dictionary in slots:
		if not shown.has(str(slot.get("slot_id", ""))): remaining.append(slot)
	if not remaining.is_empty():
		_text("已保存档案", 20)
		for slot: Dictionary in remaining:
			var kind: String = {"manual": "手动", "quick": "快速", "auto": "自动"}.get(str(slot.get("slot_kind", "")), "存档")
			_slot_card(slot, "%s槽 %d" % [kind, int(slot.get("slot_index", 0)) + 1])
	elif not allow_save:
		_text("暂无已保存的航行。")

func _slot_card(slot: Dictionary, title: String, save_index: int = -1) -> void:
	var card: VBoxContainer = _card(title)
	card.name = "SaveSlotCard"
	if slot.is_empty():
		_text_to(card, "空槽 · 尚未保存", 14).add_theme_color_override("font_color", UISkin.MUTED)
		_text_to(card, "将当前远征保存到此槽。", 13)
	else:
		var world_name: String = str(slot.get("world_name", ""))
		var world: Label = _text_to(card, "远征 · " + (world_name if not world_name.is_empty() else "名称未记录"), 16)
		world.max_lines_visible = 2
		world.tooltip_text = world.text
		var updated: String = str(slot.get("updated_utc", "")).replace("T", " ").replace("Z", "")
		_text_to(card, "保存时间（UTC）", 12).add_theme_color_override("font_color", UISkin.MUTED)
		_text_to(card, updated if not updated.is_empty() else "时间未记录", 14)
	if save_index >= 0:
		var save: Button = _wide_button(_button(card, "保存至手动槽 %d" % (save_index + 1), func(): requested.emit("save", str(save_index), 1, "manual")))
		_secondary(save)
		if not slot.is_empty(): _text_to(card, "保存将替换此槽当前档案。", 12).add_theme_color_override("font_color", UISkin.MUTED)
	if not slot.is_empty():
		var load: Button = _wide_button(_button(card, "读取 " + title, func(): requested.emit("load", str(slot.slot_id), int(slot.get("generation", 0)), str(slot.get("current_snapshot_id", "")))))
		_primary(load)

func _refresh_targets() -> void:
	if sector == null or not is_instance_valid(sector.flight) or not is_instance_valid(overview):
		return
	var entries: Array[Dictionary] = []
	var detected_ids: Array[String] = []
	for entry: Variant in sector.targets.values():
		if not entry is Dictionary or not is_instance_valid(entry.get("node")) or not entry.node is Node3D: continue
		var node: Node3D = entry.node
		var distance: float = sector.flight.global_position.distance_to(node.global_position)
		var kind: String = str(entry.get("kind", ""))
		if kind == "npc":
			if distance > float(catalog.rule("target_marker_detection_range_m")): continue
			var npc: Dtos.NpcStateDto = state.find("npc_state", "npc_instance_id", str(entry.id))
			if npc != null and not npc.alive: continue
		var record: Dictionary = {"id": str(entry.id), "title": _target_title(entry), "kind": kind, "type_title": _target_type(kind), "distance_m": distance, "navigation_only": bool(entry.get("navigation_only", false)), "known": kind != "npc"}
		if kind == "resource":
			var resource_info: Dictionary = ResourceStatus.inspect(state, catalog, str(entry.id))
			record["resource_info"] = resource_info
			record["resource_summary"] = ResourceStatus.summary(resource_info)
		entries.append(record)
		detected_ids.append(str(entry.id))
	if not target_id.is_empty() and target_id not in detected_ids:
		target_id = ""
	overview.call("set_entries", entries, target_id)
	target_buttons = overview.get("target_buttons")

func _select_target(id: String) -> void:
	target_id = id
	_refresh_targets()
	_update_npc_target()
	_update_navigation()

func _target_type(kind: String) -> String:
	return str({"station": "空间站", "gate": "虫洞门", "npc": "敌舰", "resource": "矿体", "signal": "信号", "wreck": "残骸", "marker": "航标", "planet": "天体"}.get(kind, "目标"))

func _selected_details() -> Dictionary:
	if sector == null or not is_instance_valid(sector.flight) or not sector.targets.has(target_id): return {}
	var entry: Dictionary = sector.targets[target_id]
	var node: Variant = entry.get("node")
	if not is_instance_valid(node) or not node is Node3D: return {}
	var details: Dictionary = {"id": target_id, "title": _target_title(entry), "kind": str(entry.kind), "type_title": _target_type(str(entry.kind)), "distance_m": sector.flight.global_position.distance_to(node.global_position), "navigation_only": bool(entry.get("navigation_only", false))}
	if str(entry.kind) == "resource": details["resource_info"] = ResourceStatus.inspect(state, catalog, target_id)
	return details

func _navigation_context() -> Dictionary:
	var host: Node = get_parent()
	if is_instance_valid(host) and host.has_method("navigation_context"):
		var result: Variant = host.call("navigation_context", target_id)
		if result is Dictionary: return result
	return {"active": false, "reason": "选择目标后可查看航行指令。"}

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
	# All world-target annotations belong to NavigationHUD. Drawing a second
	# selected ring here created concentric outlines over the actual model.

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
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.name = "BusinessQuantityToolbar"
	toolbar.add_theme_constant_override("separation", 12)
	body.add_child(toolbar)
	var heading: Label = _text_to(toolbar, "操作数量", 14)
	heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	quantity_input = SpinBox.new()
	quantity_input.name = "OperationQuantity"
	quantity_input.min_value = 1
	quantity_input.max_value = float(catalog.rule("business_quantity_limit"))
	quantity_input.step = 1
	quantity_input.value = clampi(quantity_value, 1, int(quantity_input.max_value))
	quantity_input.custom_minimum_size = Vector2(126, 34)
	quantity_input.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quantity_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toolbar.add_child(quantity_input)
	_text_to(toolbar, "物资购买和堆叠按数量；制造按批；舰体交易、单件设备出售固定为 1。", 12).add_theme_color_override("font_color", UISkin.MUTED)
	quantity_input.value_changed.connect(func(value: float): quantity_value = int(value); _update_quotes())

func _command(parent: Node, title: String, action: String, target: String = "", extra: String = "") -> Button:
	var uses_quantity: bool = action in ["buy_item", "sell_item", "move_stack", "manufacture", "recover_resource"]
	var button: Button = _button(parent, title, func(): requested.emit(action, target, quantity_value if uses_quantity else 1, extra))
	button.set_meta("action", action)
	button.set_meta("target", target)
	button.set_meta("extra", extra)
	button.set_meta("uses_quantity", uses_quantity)
	return button

func _business_list(title: String, price_heading: String = "单价 / 信用点", quantity_heading: String = "数量") -> VBoxContainer:
	var list: VBoxContainer = BusinessList.new()
	body.add_child(list)
	list.call("configure", title, price_heading, quantity_heading)
	return list

func _asset_row(list: Node, id: String, kind: String, asset_id: String, title: String, description: String, unit: String, quantity: String, unit_price: String, total: String, status: String) -> Dictionary:
	var entry: Dictionary = list.call("append_row", id, ItemPortraits.texture(kind, asset_id), title, description, unit, quantity, unit_price, total, status)
	entry.row.set_meta("asset_kind", kind)
	entry.row.set_meta("asset_id", asset_id)
	return entry

func _quote_row(entry: Dictionary, fields: Dictionary) -> Dictionary:
	var row: Dictionary = fields.duplicate()
	row["label"] = entry.total
	row["unit_label"] = entry.unit_price
	row["total_label"] = entry.total
	row["status_label"] = entry.status
	row["quantity_label"] = entry.quantity
	row["row"] = entry.row
	return row

func _item_unit(id: String) -> String:
	return str({"module": "件", "ammo": "发", "component": "件", "consumable": "件"}.get(str(_one("item_defs", "item_id", id).get("item_type", "")), "单位"))

func _item_description(id: String) -> String:
	var definition: Dictionary = _one("item_defs", "item_id", id)
	if definition.is_empty(): return "物资定义未提供"
	var category: String = str({"ore": "原矿", "material": "精炼材料", "component": "组件", "ammo": "弹药", "consumable": "消耗品", "module": "舰载模块"}.get(str(definition.item_type), "物资"))
	var description: String = "%s · 质量 %.2f kg · 容积 %d L" % [category, float(definition.unit_mass_kg), int(definition.unit_volume_l)]
	var module: Dictionary = _one("module_defs", "module_id", id)
	if not module.is_empty():
		description += "\n供能 %.0f · 算力 %.0f" % [float(module.power_pu), float(module.cpu_cu)]
		if float(module.range_m) > 0: description += " · 作用距离 %.0f m" % float(module.range_m)
		if float(module.cycle_s) > 0: description += " · 周期 %.1f s" % float(module.cycle_s)
	return description

func _ship_description(id: String) -> String:
	var definition: Dictionary = _one("ship_defs", "ship_id", id)
	if definition.is_empty(): return "舰体定义未提供"
	var role: Dictionary = _one("ship_role_defs", "ship_id", id)
	var faction: String = str(_one("faction_defs", "faction_id", str(role.get("faction_id", ""))).get("display_name", ""))
	return (faction + " · " if not faction.is_empty() else "") + "舰体基准：速度 %.0f m/s · 货舱 %d L · 矿舱 %d L\n护盾 %.0f · 装甲 %.0f · 结构 %.0f" % [float(definition.max_speed_mps), int(definition.cargo_l), int(definition.mineral_cargo_l), float(definition.shield_max), float(definition.armor_max), float(definition.hull_max)]

func _service_reason(service: String) -> String:
	for definition: Dictionary in _defs("station_service_defs"):
		if definition.station_id == state.player().docked_station_id and definition.service_id == service:
			return "" if _unlocked(str(definition.required_unlock_id)) else "站点服务需解锁 " + _unlock_name(str(definition.required_unlock_id))
	return "本站不提供此项服务"

func _materials_reason(table: String, key: String, id: String, batches: int) -> String:
	var inventory: RefCounted = gameplay.get("inventory")
	for ingredient: Dictionary in _defs(table):
		if str(ingredient.get(key, "")) != id: continue
		var required: int = int(ingredient.quantity) * batches
		var available: int = int(inventory.call("count", _warehouse_id(), str(ingredient.item_id), true))
		if available < required: return "缺少 %s · %d/%d" % [_item_name(str(ingredient.item_id)), available, required]
	return ""

func _ship_sale_reason(ship: Dtos.ShipStateDto) -> String:
	var service: String = _service_reason("ship_purchase")
	if not service.is_empty(): return service
	if ship.status != Types.ShipStatus.DOCKED or ship.station_id != state.player().docked_station_id or ship.owner_player_id != state.player().player_id: return "仅可出售同站点自有舰体"
	if ship.ship_instance_id == state.ship().ship_instance_id: return "先切换到另一艘舰船"
	var stock: Dtos.ShopShipStockStateDto
	for candidate: Dtos.ShopShipStockStateDto in state.rows("shop_ship_stock_state"):
		if candidate.station_id == state.player().docked_station_id and candidate.ship_def_id == ship.ship_def_id: stock = candidate
	var definition: Dictionary = {}
	for candidate: Dictionary in _defs("station_ship_stock_defs"):
		if candidate.station_id == state.player().docked_station_id and candidate.ship_id == ship.ship_def_id: definition = candidate
	if stock == null or definition.is_empty() or stock.quantity >= int(definition.get("hard_cap_units", 0)): return "本站不收购此舰体或库存已满"
	var price: int = int(gameplay.get("economy").call("quote_ship", ship.ship_instance_id, true))
	var budget: Dtos.StationEconomyStateDto = state.find("station_economy_state", "station_id", state.player().docked_station_id)
	if budget == null or budget.buyback_remaining_credit < price: return "本站回购预算不足"
	for equipped: Dtos.EquipmentStateDto in gameplay.call("equipped", ship):
		var item: Dtos.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", equipped.item_instance_id)
		if item != null and item.policy_id != "normal_owned": return "先处理舰上绑定设备"
	return ""

func _fitting_reason(item: Dtos.ItemInstanceStateDto, metrics: Dictionary) -> String:
	var service: String = _service_reason("fitting")
	if not service.is_empty(): return service
	var tech: Dictionary = _one("module_tech_defs", "module_id", item.item_def_id)
	if not tech.is_empty() and not _unlocked(str(tech.required_unlock_id)): return "需解锁 " + _unlock_name(str(tech.required_unlock_id))
	var module: Dictionary = _one("module_full_defs", "module_id", item.item_def_id)
	if module.is_empty(): return "缺少模块定义"
	if float(metrics.power_used) + float(module.power_pu) > float(metrics.power_capacity) or float(metrics.cpu_used) + float(module.cpu_cu) > float(metrics.cpu_capacity) or float(metrics.installed_mass_kg) + float(module.mass_kg) > float(metrics.max_installed_mass_kg): return "供能、算力或安装质量超限"
	var equipped: Array = gameplay.call("equipped", state.ship())
	var same: int = 0
	for other: Dtos.EquipmentStateDto in equipped:
		if other.module_def_id == item.item_def_id: same += 1
	if module.get("max_per_ship") != null and same >= int(module.max_per_ship): return "同类设备数量超限"
	for member: Dictionary in _defs("module_group_members"):
		if str(member.module_id) != item.item_def_id: continue
		var group: Dictionary = _one("module_exclusion_groups", "group_id", str(member.group_id))
		var installed: int = 0
		for other: Dtos.EquipmentStateDto in equipped:
			for other_member: Dictionary in _defs("module_group_members"):
				if other_member.module_id == other.module_def_id and other_member.group_id == member.group_id: installed += 1
		if installed >= int(group.get("max_installed", 0)): return "互斥设备组数量超限"
	return ""

func _recycle_reason(item: Dtos.ItemInstanceStateDto) -> String:
	var service: String = _service_reason("recycle")
	if not service.is_empty(): return service
	if not bool(_one("asset_policy_defs", "policy_id", item.policy_id).get("may_recycle", false)): return "受保护设备不可拆解"
	if state.find("equipment_state", "item_instance_id", item.item_instance_id) != null: return "先卸下设备"
	if state.player().credit < int(catalog.rule("recycle_service_fee_credit")): return "信用点不足"
	if item.origin_kind == Types.ItemOrigin.MANUFACTURE:
		for ledger: RefCounted in state.rows("manufacture_input_state"):
			if ledger.item_instance_id == item.item_instance_id: return ""
		return "缺少合法材料追溯账本"
	if item.salvage_recipe_id.is_empty(): return "设备没有冻结拆解来源"
	for ingredient: Dictionary in _defs("recipe_inputs"):
		if str(ingredient.recipe_id) == item.salvage_recipe_id: return ""
	return "缺少合法材料追溯账本"

func _mission_list_description(definition: Dictionary, current: Dtos.MissionStateDto) -> String:
	var description: String = "接取 " + _station_name(str(definition.accept_station_id)) + " · 交付 " + _station_name(str(definition.turnin_station_id))
	if current == null or current.status not in ["active", "ready"]:
		for objective_def: Dictionary in _defs("mission_objective_defs"):
			if str(objective_def.mission_id) == str(definition.mission_id): description += "\n" + _objective_description(objective_def)
		return description
	for objective_def: Dictionary in _defs("mission_objective_defs"):
		if objective_def.mission_id != current.mission_def_id: continue
		var progress: Dtos.MissionObjectiveStateDto = _mission_progress(current.mission_instance_id, int(objective_def.objective_index))
		if progress == null: continue
		description += "\n" + _objective_description(objective_def) + " · %d/%d" % [progress.progress_units, int(objective_def.required_count)]
	if current.status == "ready": description += "\n将所需实物带入当前舰或交付站仓库。"
	return description

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

func _wide_button(button: Button) -> Button:
	button.custom_minimum_size.x = 0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		card_grid.columns = 2 if root.size.x >= 1200 and page != "title" else 1
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

func _update_navigation() -> void:
	if state == null or not is_instance_valid(sector) or catalog == null or gameplay == null: return
	var navigation_context: Dictionary = _navigation_context()
	var automatic: bool = bool(navigation_context.get("active", false))
	navigation_status.text = (UISkin.navigation_phase(str(navigation_context.get("phase", ""))) + " · " + _friendly(str(navigation_context.get("title", "")))) if automatic else "手动航行 · 已知位置可跃迁"
	if automatic and float(navigation_context.get("remaining_s", 0.0)) > 0.0: navigation_status.text += " · %.1f s" % float(navigation_context.remaining_s)
	navigation_status.tooltip_text = navigation_status.text
	navigation_stop_button.visible = automatic
	navigation_stop_button.disabled = operation_waiting or operation_kind == "travel"
	if is_instance_valid(overview): overview.call("set_selection", _selected_details(), navigation_context, operation_waiting or operation_kind == "travel")
	navigation_hud.selected_id = target_id
	navigation_hud.refresh()
	navigation_hud.caption_obstacles.clear()
	for control: Control in [target_panel, hud_left.get_parent(), navigation_frame, instrument, equipment_bar, navigation, navigation_hud.radar_frame, operation_bar]:
		if control.is_visible_in_tree(): navigation_hud.caption_obstacles.append(control.get_global_rect())
	# The selected-target card owns this readout; the HUD's flag keeps it
	# disabled through every render update, independently of UI telemetry.
	if operation_kind == "travel":
		interaction_candidate = {}
		interaction_button.visible = true
		interaction_label.visible = true
		interaction_button.text = "[F] 取消虫洞充能" if operation_waiting else "虫洞传送处理中"
		interaction_button.disabled = not operation_waiting
		interaction_label.text = "充能期间可取消；提交开始后等待传送完成。" if operation_waiting else "航行进度正在提交，请等待传送完成。"
		interaction_label.tooltip_text = interaction_label.text
		interaction_button.tooltip_text = interaction_label.text
		return
	interaction_candidate = Context.choose(sector, state, catalog, gameplay, target_id)
	var candidate_id: String = str(interaction_candidate.get("target_id", ""))
	interaction_button.visible = not candidate_id.is_empty() and (bool(interaction_candidate.in_range) or candidate_id == target_id)
	interaction_label.visible = interaction_button.visible
	if not interaction_button.visible: return
	var label: String = {"dock": "停靠空间站", "travel": "进入虫洞", "pickup_wreck": "回收残骸", "start_scan": "扫描信号", "start_mining": "开采矿体", "recover_resource": "回收组件"}.get(str(interaction_candidate.action), "交互")
	interaction_button.text = "[F] " + label
	interaction_button.disabled = not bool(interaction_candidate.ready)
	interaction_button.tooltip_text = str(interaction_candidate.title) + " · " + str(interaction_candidate.reason)
	interaction_label.text = str(interaction_candidate.title) + "\n" + ("接口就绪 · %.0f m" % float(interaction_candidate.distance_m) if interaction_candidate.ready else _friendly(str(interaction_candidate.reason)))
	interaction_label.tooltip_text = interaction_label.text
	interaction_label.add_theme_color_override("font_color", UISkin.ICE if interaction_candidate.ready else UISkin.AMBER)

func _update_hud_visibility() -> void:
	var show_hud: bool = state != null and state.ship() != null and state.ship().status == Types.ShipStatus.FLYING and not panel.visible and not station_layer.visible and not menu_open
	if is_instance_valid(hud_left): hud_left.get_parent().visible = show_hud
	if is_instance_valid(navigation_frame): navigation_frame.visible = show_hud
	if is_instance_valid(instrument): instrument.visible = show_hud
	if is_instance_valid(flight_dock): flight_dock.visible = show_hud
	if is_instance_valid(equipment_bar): equipment_bar.visible = show_hud
	if is_instance_valid(navigation): navigation.visible = show_hud
	if is_instance_valid(target_panel): target_panel.visible = show_hud
	if is_instance_valid(controls): controls.visible = show_hud and root.size.x >= 1100
	if is_instance_valid(navigation_hud): navigation_hud.visible = show_hud
	if is_instance_valid(title_background): title_background.visible = page == "title"
	if is_instance_valid(title_shade): title_shade.visible = page == "title"
	if is_instance_valid(station_layer): station_layer.visible = page == "station" and state != null
	_responsive_title()

func _responsive() -> void:
	if not is_instance_valid(root): return
	var compact: bool = root.size.x < 950
	# Hide tall navigation before resizing; its previous minimum otherwise
	# clamps the panel and leaves stale offsets after a page/scale change.
	if is_instance_valid(sidebar): sidebar.visible = state != null and page not in ["title", "settings"] and not compact
	var safe: float = 14.0 if compact else 22.0
	var sidebar_width: float = 206.0 if compact else 300.0
	var left_width: float = 180.0 if compact else 316.0
	var toolbar_height: float = 32.0 if compact else 36.0
	var dock_height: float = 70.0 if compact else 128.0
	flight_content_top = safe + toolbar_height + 8.0
	flight_content_bottom = root.size.y - safe - dock_height - 8.0
	# A single horizontal owner keeps instruments and every equipment slot in
	# the same row, even when logical resolution is reduced by UI scaling.
	if is_instance_valid(flight_dock):
		flight_dock.offset_left = safe
		flight_dock.offset_right = -safe
		flight_dock.offset_top = -safe - dock_height
		flight_dock.offset_bottom = -safe
		flight_dock.add_theme_constant_override("separation", 8 if compact else 10)
	if is_instance_valid(navigation):
		var toolbar_width: float = minf(376.0 if compact else 480.0, root.size.x - safe * 2.0)
		navigation.add_theme_stylebox_override("panel", UISkin.hud_panel(2 if compact else 4))
		navigation.offset_left = -safe - toolbar_width
		navigation.offset_right = -safe
		navigation.offset_top = safe
		navigation.offset_bottom = safe + toolbar_height
		var toolbar_row: HBoxContainer = navigation.get_node("ToolbarActions")
		toolbar_row.add_theme_constant_override("separation", 4 if compact else 8)
		for button: Variant in toolbar_buttons.values():
			button.add_theme_font_size_override("font_size", 10 if compact else 12)
			button.custom_minimum_size.y = 24
	if is_instance_valid(navigation_frame):
		navigation_frame.offset_left = safe
		navigation_frame.offset_right = safe + left_width
		navigation_frame.offset_top = flight_content_top
		navigation_frame.offset_bottom = flight_content_top + (48 if compact else 76)
		navigation_frame.add_theme_stylebox_override("panel", UISkin.hud_panel(4 if compact else 8))
		navigation_status.max_lines_visible = 1 if compact else 2
		navigation_status.add_theme_font_size_override("font_size", 10 if compact else 11)
		navigation_stop_button.custom_minimum_size.y = 20
	if is_instance_valid(hud_left):
		var frame: PanelContainer = hud_left.get_parent()
		frame.offset_left = safe
		frame.offset_top = navigation_frame.offset_bottom + 8.0
		frame.offset_bottom = frame.offset_top + ((70 if work_box.visible else 52) if compact else 138)
		frame.offset_right = safe + left_width
		frame.add_theme_stylebox_override("panel", UISkin.hud_panel(6 if compact else 8))
		hud_left.add_theme_constant_override("separation", 3 if compact else 7)
		top.add_theme_font_size_override("font_size", 10 if compact else 14)
		objective.add_theme_font_size_override("font_size", 10 if compact else 13)
		objective.max_lines_visible = 1 if compact else 4
		var heading: Control = hud_left.find_child("MissionHeading", false, false)
		if heading != null: heading.visible = not compact or not work_box.visible
		work_progress.show_percentage = not compact
		work_label.add_theme_font_size_override("font_size", 10 if compact else 13)
		work_label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
		work_label.clip_text = compact
		work_label.max_lines_visible = 1 if compact else 3
	if is_instance_valid(instrument):
		instrument.custom_minimum_size.x = 204.0 if compact else minf(420.0, maxf(360.0, root.size.x * 0.3))
		instrument.add_theme_stylebox_override("panel", UISkin.hud_panel(2 if compact else 6))
		instrument_title.visible = not compact
		instrument_title.add_theme_font_size_override("font_size", 11)
		instrument_title.clip_text = true
		instrument_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		dial.visible = not compact
		dial.custom_minimum_size = Vector2(80, 76)
		compact_speed_label.visible = compact
		compact_speed_label.add_theme_font_size_override("font_size", 10)
		var instrument_row: HBoxContainer = instrument.find_child("InstrumentReadouts", true, false)
		if instrument_row != null: instrument_row.add_theme_constant_override("separation", 8 if compact else 10)
		for entry: Dictionary in condition_bars:
			entry.label.add_theme_font_size_override("font_size", 10 if compact else 11)
			entry.label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
			entry.label.clip_text = compact
			entry.bar.visible = not compact
			entry.bar.custom_minimum_size.y = 4
		energy_bar.visible = not compact
		heat_bar.visible = not compact
		energy_bar.custom_minimum_size.y = 4
		heat_bar.custom_minimum_size.y = 4
		energy_label.add_theme_font_size_override("font_size", 10 if compact else 11)
		heat_label.add_theme_font_size_override("font_size", 10 if compact else 11)
		energy_label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
		heat_label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
		energy_label.clip_text = compact
		heat_label.clip_text = compact
		cargo_label.visible = not compact
		cargo_label.add_theme_font_size_override("font_size", 10)
		for name_value: String in ["DefenseReadout", "ResourceReadout"]:
			var readout: VBoxContainer = instrument.find_child(name_value, true, false)
			if readout != null:
				readout.custom_minimum_size.x = (80 if name_value == "DefenseReadout" else 100) if compact else (92 if name_value == "DefenseReadout" else 110)
				readout.add_theme_constant_override("separation", 0 if compact else 3)
	if is_instance_valid(equipment_bar): equipment_bar.call("responsive", compact)
	if is_instance_valid(navigation_hud):
		navigation_hud.responsive(root.size)
		var radar_height: float = minf(140.0 if compact else 246.0, maxf(66.0, flight_content_bottom - hud_left.get_parent().offset_bottom - 8.0))
		navigation_hud.radar_frame.add_theme_stylebox_override("panel", UISkin.hud_panel(5 if compact else 8))
		navigation_hud.radar_frame.offset_left = safe
		navigation_hud.radar_frame.offset_right = safe + (150 if compact else 236)
		navigation_hud.radar_frame.offset_top = flight_content_bottom - radar_height - root.size.y
		navigation_hud.radar_frame.offset_bottom = flight_content_bottom - root.size.y
		navigation_hud.radar.custom_minimum_size = Vector2(140 if compact else 200, maxf(30.0, radar_height - (36.0 if compact else 44.0)))
		navigation_hud.range_label.add_theme_font_size_override("font_size", 10 if compact else 12)
	if is_instance_valid(controls):
		controls.visible = root.size.x >= 1100 and navigation_hud.visible
		controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		controls.offset_left = safe
		controls.offset_right = safe + 300
		controls.offset_top = safe + 8.0
		controls.offset_bottom = safe + 26.0
	if is_instance_valid(target_panel):
		target_panel.offset_left = -safe - sidebar_width
		target_panel.offset_right = -safe
		target_panel.offset_top = flight_content_top
		target_panel.offset_bottom = flight_content_bottom
		if is_instance_valid(overview): overview.call("responsive", compact, flight_content_bottom - flight_content_top)
	# Limit notification width to the free center lane. Different feedback owns
	# a second small line; only an exact duplicate of the active operation hides.
	var center_left: float = safe + left_width + 10.0
	var center_right: float = root.size.x - safe - sidebar_width - 10.0
	var center_width: float = maxf(100.0, center_right - center_left)
	var notification_top: float = flight_content_top
	if panel != null and (panel.visible or station_layer.visible):
		center_left = safe
		center_width = root.size.x - safe * 2.0
		notification_top = safe
	var notice_width: float = minf(520.0, center_width)
	var notice_left: float = center_left + (center_width - notice_width) * 0.5
	var operation_height: float = 64.0 if compact else 56.0
	if is_instance_valid(operation_bar):
		operation_bar.offset_left = notice_left
		operation_bar.offset_right = notice_left + notice_width
		operation_bar.offset_top = notification_top
		operation_bar.offset_bottom = notification_top + operation_height
		operation_bar.add_theme_stylebox_override("panel", UISkin.hud_panel(4 if compact else 6))
		operation_label.add_theme_font_size_override("font_size", 10 if compact else 12)
		operation_label.max_lines_visible = 3 if compact else 2
		operation_cancel.custom_minimum_size = Vector2(64 if compact else 96, 24 if compact else 28)
		operation_cancel.add_theme_font_size_override("font_size", 10 if compact else 11)
		operation_bar.get_child(1).add_theme_constant_override("separation", 6 if compact else 10)
	if is_instance_valid(toast):
		toast.visible = not toast.text.is_empty() and not (operation_bar.visible and toast.text == operation_message)
		toast.offset_left = notice_left
		toast.offset_right = notice_left + notice_width
		toast.offset_top = notification_top + operation_height + 4.0 if operation_bar.visible else notification_top
		toast.offset_bottom = toast.offset_top + (33 if compact else 39)
		toast.add_theme_font_size_override("font_size", 10 if compact else 12)
		if panel != null and (panel.visible or station_layer.visible):
			toast.offset_top = root.size.y - 45.0
			toast.offset_bottom = root.size.y - 8.0
	if is_instance_valid(npc_title): npc_title.add_theme_font_size_override("font_size", 10 if compact else 11)
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
	if is_instance_valid(panel):
		var selector: OptionButton = panel.find_child("PageSelector", true, false)
		if selector != null: selector.visible = compact
	if is_instance_valid(panel):
		for grid: Node in panel.find_children("ModuleCards*", "GridContainer", true, false):
			grid.columns = 2 if root.size.x >= 1200 and page != "title" else 1
	if is_instance_valid(station_services):
		station_services.offset_left = safe
		station_services.offset_right = safe + (200 if compact else 260)
		station_services.offset_top = 44 if compact else 96
		station_services.offset_bottom = (-94 if compact else -120) - (40 if station_layer.visible and toast.visible else 0)
		for heading: Label in station_services.find_children("NpcServiceTitle", "Label", true, false):
			heading.add_theme_font_size_override("font_size", 13 if compact else 15)
	if is_instance_valid(station_details):
		station_details.visible = not compact
	if is_instance_valid(station_departure):
		var station_notice_gap: float = 40.0 if station_layer.visible and toast.visible else 0.0
		station_departure.offset_left = safe
		station_departure.offset_right = -safe
		station_departure.offset_top = (-82 if compact else -96) - station_notice_gap
		station_departure.offset_bottom = -safe - station_notice_gap
	_reflow_flight_left()

func _reflow_flight_left() -> void:
	if not is_instance_valid(root) or not is_instance_valid(hud_left) or not is_instance_valid(navigation_hud): return
	var compact: bool = root.size.x < 950
	var frame: PanelContainer = hud_left.get_parent()
	var base_height: float = (70.0 if work_box.visible else 52.0) if compact else 138.0
	# Work and objective text can grow after telemetry changes. Reserve their
	# real container minimum before placing the radar, without rebuilding nodes.
	var frame_bottom: float = frame.offset_top + maxf(base_height, frame.get_combined_minimum_size().y)
	if absf(frame.offset_bottom - frame_bottom) > 0.5: frame.offset_bottom = frame_bottom
	var radar_height: float = minf(140.0 if compact else 246.0, maxf(66.0, flight_content_bottom - frame_bottom - 8.0))
	var radar_frame: PanelContainer = navigation_hud.radar_frame
	radar_frame.offset_top = flight_content_bottom - radar_height - root.size.y
	radar_frame.offset_bottom = flight_content_bottom - root.size.y
	navigation_hud.radar.custom_minimum_size = Vector2(140 if compact else 200, maxf(30.0, radar_height - (36.0 if compact else 44.0)))

func _setting_text(title: String, value: float, field: String) -> String:
	return "%s %.4f" % [title, value] if field == "mouse_sensitivity" else "%s %d%%" % [title, roundi(value * 100)]

func _update_work() -> void:
	var worker: RefCounted = gameplay.get("work")
	if worker == null: return
	var scan: String = str(worker.get("scan_target"))
	var mining: String = str(worker.get("mining_target"))
	work_mode = "scan" if not scan.is_empty() else "mining" if not mining.is_empty() else ""
	work_box.visible = not work_mode.is_empty() and not panel.visible and not station_layer.visible
	var mission_heading: Control = hud_left.find_child("MissionHeading", false, false)
	if mission_heading != null: mission_heading.visible = root.size.x >= 950 or work_mode.is_empty()
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
		var cycle_text: String = "周期 %.1f 秒" % remaining if not cycles.is_empty() else "等待可用采集周期"
		var resource_info: Dictionary = ResourceStatus.inspect(state, catalog, mining)
		var reserve_text: String = ResourceStatus.summary(resource_info)
		# Compact work space owns one visible line; keep the actual reserve there
		# and retain the complete mineral/cycle readout in its existing tooltip.
		work_label.text = "采矿 · " + OverviewPanel.compact_resource_summary(resource_info) if root.size.x < 950 else "采矿 · %s · %s\n%s" % [_item_name(str(definition.get("item_id", ""))), cycle_text, reserve_text]
		work_label.tooltip_text = "采矿 · %s\n%s\n%s" % [_item_name(str(definition.get("item_id", ""))), cycle_text, reserve_text]
		return
	work_label.tooltip_text = work_label.text

func _resource_map_readout(node_id: String, sector_id: String) -> String:
	var definition: Dictionary = _one("resource_node_defs", "node_id", node_id)
	var heading: String = "矿点 · " + _item_name(str(definition.get("item_id", "")))
	var visit: Dtos.SectorStateDto = state.find("sector_state", "sector_id", sector_id)
	if sector_id != state.current_sector() and (visit == null or not visit.visited):
		return heading + "\n尚未到访 · 实时矿量未知"
	var info: Dictionary = ResourceStatus.inspect(state, catalog, node_id)
	var summary: String = ResourceStatus.summary(info)
	if bool(info.get("available", false)) and int(info.get("capacity_units", 0)) > 0:
		summary += " · %.0f%%" % (float(info.remaining_units) / float(info.capacity_units) * 100.0)
	return heading + "\n" + summary

func _update_map_resources() -> void:
	if page != "map": return
	# Reuse the existing telemetry cadence and nodes; preserve scroll/focus.
	for readout: Dictionary in map_resource_readouts:
		if not is_instance_valid(readout.label): continue
		var text: String = _resource_map_readout(str(readout.node_id), str(readout.sector_id))
		if readout.label.text != text:
			readout.label.text = text
			readout.label.tooltip_text = text + "\n矿量来自当前世界的SQLite状态；再生按世界时间推进，暂停与退出不推进。"
	if is_instance_valid(resource_chart): resource_chart.call("refresh_resource_status")

func _update_live_missions() -> void:
	for row: Dictionary in live_missions:
		if not is_instance_valid(row.label): continue
		var mission: Dtos.MissionStateDto = row.mission
		row.label.text = _mission_status(mission.status) + (" · 剩余 %.0f 秒" % mission.deadline_remaining_s if mission.has_deadline_remaining_s else "")
		row.label.tooltip_text = row.label.text
		if row.has("description") and is_instance_valid(row.description):
			row.description.text = _mission_list_description(row.definition, mission)
			row.description.tooltip_text = row.description.text
		for entry: Dictionary in row.progress:
			if is_instance_valid(entry.label): entry.label.text = _objective_description(entry.definition) + " · %d/%d" % [entry.state.progress_units, int(entry.definition.get("required_count", 1))]

func _update_npc_target() -> void:
	if state == null or not is_instance_valid(npc_detail): return
	var npc: Dtos.NpcStateDto = state.find("npc_state", "npc_instance_id", target_id)
	npc_detail.visible = npc != null and npc.alive
	if not npc_detail.visible: return
	var spawn: Dictionary = _one("npc_spawn_defs", "spawn_id", npc.spawn_id)
	var definition: Dictionary = _one("npc_full_defs", "npc_id", str(spawn.get("npc_id", "")))
	npc_title.text = str(definition.get("display_name", "敌方舰船"))
	for index: int in range(3):
		var key: String = ["shield", "armor", "hull"][index]
		var maximum: float = float(definition.get(key + "_max", 0))
		var current: float = float(npc.get(key))
		npc_bars[index].label.tooltip_text = "%s %.0f/%.0f" % [npc_bars[index].name, current, maximum]
		npc_bars[index].label.text = "%s %.0f%%" % [npc_bars[index].name, current / maxf(maximum, 1.0) * 100.0] if root.size.x < 950 else npc_bars[index].label.tooltip_text
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
		var unit_price: int = 0
		var selling: bool = bool(row.get("selling", false))
		if row.kind == "ship":
			price = int(economy.call("quote_ship", str(row.id), selling))
			unit_price = price
		elif row.kind == "recipe":
			price = int(economy.call("quote_manufacture", str(row.id), quantity))
			unit_price = int(economy.call("quote_manufacture", str(row.id), 1))
		else:
			price = int(economy.call("quote", str(row.id), quantity, selling))
			unit_price = int(economy.call("quote", str(row.id), 1, selling))
		var reason: String = _service_reason(str(row.service)) if row.has("service") else ""
		if not _unlocked(str(row.get("unlock", ""))): reason = "需解锁 " + _unlock_name(str(row.get("unlock", "")))
		if row.has("policy") and not bool(_one("asset_policy_defs", "policy_id", str(row.policy)).get("may_sell", false)): reason = "保护 / 绑定资产不可出售"
		if row.has("maximum") and quantity > int(row.maximum): reason = "数量超过现有库存"
		if row.has("inputs_table") and reason.is_empty(): reason = _materials_reason(str(row.inputs_table), str(row.inputs_key), str(row.id), quantity)
		if selling:
			var stock: Dtos.ShopStockStateDto
			for current_stock: Dtos.ShopStockStateDto in state.rows("shop_stock_state"):
				if current_stock.station_id == state.player().docked_station_id and current_stock.item_def_id == row.id: stock = current_stock
			var definition: Dictionary = _stock_definition(str(row.id))
			var budget: Dtos.StationEconomyStateDto = state.find("station_economy_state", "station_id", state.player().docked_station_id)
			if stock == null or quantity > stock.buyback_remaining_units or stock.quantity + quantity > int(definition.get("hard_cap_units", 0)): reason = "本站本轮回购数量额度不足"
			elif budget != null and budget.buyback_remaining_credit < price: reason = "本站本轮回购预算不足"
		if not selling and state.player().credit < price: reason = "信用点不足"
		row.label.text = str(price)
		row.label.set_meta("quote_amount", price)
		row.label.tooltip_text = ("实收" if selling else "含税总价" if row.kind != "recipe" else "生产服务费") + " %d 信用点；成交数量 %d。" % [price, quantity]
		if is_instance_valid(row.get("unit_label")):
			row.unit_label.text = str(unit_price)
			row.unit_label.set_meta("quote_amount", unit_price)
			row.unit_label.tooltip_text = ("每单位实收" if selling else "每批服务费" if row.kind == "recipe" else "每单位含税价格") + " %d 信用点；总价按实际成交量独立计算，包含整数税费舍入。" % unit_price
		if is_instance_valid(row.get("quantity_label")): row.quantity_label.text = str(quantity)
		if is_instance_valid(row.get("status_label")):
			row.status_label.text = str(row.get("status_prefix", "")) + ("\n" if not str(row.get("status_prefix", "")).is_empty() else "") + (reason if not reason.is_empty() else "可成交" if row.kind != "recipe" else "可生产")
			row.status_label.tooltip_text = row.status_label.text
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var mark := ColorRect.new()
	mark.color = UISkin.ICE
	mark.custom_minimum_size = Vector2(5, 7)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	var line: Label = _text_to(row, title, 14)
	line.add_theme_color_override("font_color", UISkin.ICE)
	if not subtitle.is_empty():
		var caption: Label = _text_to(parent, subtitle, 11)
		caption.add_theme_color_override("font_color", UISkin.MUTED)

func _build_instrument() -> void:
	instrument = _frame(flight_dock, "ShipInstrument")
	instrument.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	instrument.add_child(layout)
	instrument_title = _text_to(layout, "舰况 / 巡航", 14)
	instrument_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instrument_title.add_theme_color_override("font_color", UISkin.MUTED)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "InstrumentReadouts"
	row.add_theme_constant_override("separation", 18)
	layout.add_child(row)
	var defense: VBoxContainer = VBoxContainer.new()
	defense.name = "DefenseReadout"
	defense.custom_minimum_size.x = 145
	defense.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defense.add_theme_constant_override("separation", 6)
	row.add_child(defense)
	for index: int in range(3):
		var name_value: String = ["护盾", "装甲", "结构"][index]
		var label: Label = _text_to(defense, name_value, 13)
		label.custom_minimum_size.x = 0
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		var bar: ProgressBar = _bar(defense, [UISkin.ICE, UISkin.AMBER, Color("a6b2be")][index], 5)
		condition_bars.append({"label": label, "bar": bar, "name": name_value})
	dial = UISkin.Dial.new()
	dial.name = "SpeedDial"
	dial.custom_minimum_size = Vector2(154, 125)
	row.add_child(dial)
	var resources: VBoxContainer = VBoxContainer.new()
	resources.name = "ResourceReadout"
	resources.custom_minimum_size.x = 145
	resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources.add_theme_constant_override("separation", 6)
	row.add_child(resources)
	compact_speed_label = _text_to(resources, "0 m/s · 跟随", 10)
	compact_speed_label.name = "CompactSpeed"
	compact_speed_label.clip_text = true
	compact_speed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	compact_speed_label.mouse_filter = Control.MOUSE_FILTER_PASS
	compact_speed_label.hide()
	energy_label = _text_to(resources, "电容", 13)
	energy_label.custom_minimum_size.x = 0
	energy_bar = _bar(resources, UISkin.ICE, 5)
	heat_label = _text_to(resources, "热量", 13)
	heat_label.custom_minimum_size.x = 0
	heat_bar = _bar(resources, UISkin.AMBER, 5)
	cargo_label = _text_to(resources, "载荷", 12)
	cargo_label.custom_minimum_size.x = 0
	cargo_label.add_theme_color_override("font_color", UISkin.MUTED)
	for readout: Label in [energy_label, heat_label, cargo_label]: readout.mouse_filter = Control.MOUSE_FILTER_PASS
	health = _label(root, "", 12)
	health.hide() # 保留测试/辅助读取接口，正式仪表只使用条形与弧形读数。

func _build_navigation() -> void:
	navigation = _frame(root, "FlightNavigation")
	navigation.add_theme_stylebox_override("panel", UISkin.hud_panel(4))
	navigation.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_toolbar_frame = navigation
	navigation.offset_left = -280
	navigation.offset_right = 280
	navigation.offset_top = -58
	navigation.offset_bottom = -8
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ToolbarActions"
	row.add_theme_constant_override("separation", 10)
	navigation.add_child(row)
	for key: String in ["show_ship", "missions", "map", "pause"]:
		var title: String = {"show_ship": "显示舰船", "missions": "任务  J", "map": "星图  M", "pause": "系统  Esc"}[key]
		var callback: Callable = func(): requested.emit("show_ship", "", 1, "")
		if key != "show_ship": callback = show_page.bind(key)
		var button: Button = _button(row, title, callback)
		toolbar_buttons[key] = button
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 25)
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", 12)
		if key == "show_ship":
			show_ship_button = button
			button.name = "ShowPlayerShip"
			button.tooltip_text = "恢复跟随视角、默认观察角度和镜头距离，舰船居中显示。V 切换视角；左键拖动观察，松开后保留角度。"
		_secondary(button)
		button.add_theme_stylebox_override("normal", UISkin.flat(Color(0.08, 0.105, 0.125, 0.65), Color("384650"), 4))
		button.add_theme_stylebox_override("hover", UISkin.flat(Color("253b45"), UISkin.ICE, 4))
		button.add_theme_stylebox_override("pressed", UISkin.flat(Color("192b34"), UISkin.ICE, 4))

func _build_target_module() -> void:
	overview = OverviewPanel.new()
	target_panel = overview
	root.add_child(overview)
	target_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	target_panel.offset_left = -300
	target_panel.offset_right = -22
	target_panel.offset_top = 22
	target_panel.offset_bottom = 640
	target_list = overview.get("target_list")
	target_buttons = overview.get("target_buttons")
	npc_detail = overview.get("npc_detail")
	npc_title = overview.get("npc_title")
	npc_bars.assign(overview.get("npc_bars"))
	interaction_button = overview.get("interaction_button")
	interaction_label = overview.get("interaction_label")
	overview.connect("selected", _select_target)
	overview.connect("command", func(action: String, id: String):
		if action == "context_interact":
			if operation_kind == "travel" and operation_waiting: requested.emit("interact", "", 1, "")
			elif not interaction_candidate.is_empty(): requested.emit("interact_target", str(interaction_candidate.target_id), 1, "")
		else: requested.emit(action, id, 1, ""))

func _build_equipment_bar() -> void:
	equipment_bar = EquipmentBar.new()
	equipment_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flight_dock.add_child(equipment_bar)
	equipment_bar.connect("toggle_requested", func(id: String, enabled: bool): requested.emit("set_module_enabled", id, 1, "on" if enabled else "off"))
	equipment_bar.connect("engine_requested", func(): requested.emit("request_engine_cycle", "", 1, ""))

func _update_module_bar(ship: Dtos.ShipStateDto, metrics: Dictionary) -> void:
	if not is_instance_valid(equipment_bar): return
	var records: Array[Dictionary] = []
	var empty_slots: Array[Dictionary] = []
	var engine_ready: bool = false
	var engine_reason: String = "没有安装增推设备。"
	for container: Dtos.ContainerStateDto in state.rows("container_state"):
		if container.kind != Types.ContainerKind.SLOT or container.ship_instance_id != ship.ship_instance_id: continue
		var equipment: Dtos.EquipmentStateDto = state.find("equipment_state", "slot_container_id", container.container_id)
		if equipment == null:
			var empty_type: int = int(container.slot_type)
			empty_slots.append({"slot_id": container.container_id, "slot_type": empty_type, "slot_index": container.slot_index, "slot_title": ["武器", "作业", "通用", "结构"][empty_type], "slot_short": ["武", "作", "通", "构"][empty_type]})
			continue
		var item: Dtos.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
		var module: Dictionary = _one("module_defs", "module_id", equipment.module_def_id)
		var energy_cost: float = float(module.get("energy_eu", 0.0))
		var heat_cost: float = float(module.get("heat_hu", 0.0))
		var ready: bool = false
		var status: String = "已启用"
		if item == null or item.durability <= 0.0: status = "设备损坏"
		elif not equipment.enabled: status = "已关闭"
		elif equipment.active_remaining_s > 0.0: status = "运行 %.1f s" % equipment.active_remaining_s
		elif equipment.cooldown_remaining_s > 0.0: status = "冷却 %.1f s" % equipment.cooldown_remaining_s
		elif ship.overheated: status = "过热锁定"
		elif ship.energy < energy_cost: status = "电容不足"
		elif ship.heat + heat_cost > float(metrics.heat_max): status = "热量受限"
		else: ready = ship.status == Types.ShipStatus.FLYING; status = "循环就绪" if float(module.get("cycle_s", 0.0)) > 0.0 else "持续启用"
		var slot_type: int = int(container.slot_type)
		records.append({"id": equipment.item_instance_id, "slot_id": container.container_id, "module_id": equipment.module_def_id, "title": _item_name(equipment.module_def_id), "slot_type": slot_type, "slot_title": ["武器", "作业", "通用", "结构"][slot_type], "slot_short": ["武", "作", "通", "构"][slot_type], "slot_index": container.slot_index, "enabled": equipment.enabled, "cooldown_remaining_s": equipment.cooldown_remaining_s, "active_remaining_s": equipment.active_remaining_s, "cycle_s": float(module.get("cycle_s", 0.0)), "energy_eu": energy_cost, "heat_hu": heat_cost, "durability": item.durability if item != null else 0.0, "state_label": status, "ready": ready})
		if equipment.module_def_id.begins_with("module_engine_"):
			if ready and not engine_ready: engine_reason = "启动已启用增推设备的真实循环；电容 %.0f、热量 %.0f、周期 %.1f s。" % [energy_cost, heat_cost, float(module.get("cycle_s", 0.0))]
			elif not engine_ready: engine_reason = status
			engine_ready = engine_ready or ready
	records.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.slot_type) < int(b.slot_type) if a.slot_type != b.slot_type else int(a.slot_index) < int(b.slot_index))
	equipment_bar.call("refresh", records, {"energy": ship.energy, "energy_max": metrics.energy_max, "heat_ratio": ship.heat / maxf(float(metrics.heat_max), 1.0), "engine_ready": engine_ready, "engine_reason": engine_reason, "empty_slots": empty_slots}, operation_waiting or operation_kind == "travel")

func _update_instrument(ship: Dtos.ShipStateDto, metrics: Dictionary) -> void:
	update_camera_status()
	var compact: bool = root.size.x < 950
	var values: Array[float] = [ship.shield, ship.armor, ship.hull]
	var maximums: Array[float] = [float(metrics.shield_max), float(metrics.armor_max), float(metrics.hull_max)]
	var signature: String = JSON.stringify([compact, ship.ship_def_id, ship.shield, ship.armor, ship.hull, ship.energy, ship.heat, ship.overheated, Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length(), metrics.shield_max, metrics.armor_max, metrics.hull_max, metrics.energy_max, metrics.heat_max, metrics.cargo_used_l, metrics.cargo_capacity_l, metrics.mineral_used_l, metrics.mineral_capacity_l])
	if signature == telemetry_signature: return
	telemetry_signature = signature
	for index: int in range(3):
		condition_bars[index].label.tooltip_text = "%s  %.0f / %.0f" % [condition_bars[index].name, values[index], maximums[index]]
		condition_bars[index].label.text = "%s %.0f%%" % [condition_bars[index].name, values[index] / maxf(maximums[index], 1.0) * 100.0] if compact else condition_bars[index].label.tooltip_text
		condition_bars[index].bar.max_value = maxf(maximums[index], 1.0)
		condition_bars[index].bar.value = values[index]
	dial.speed = Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length()
	dial.ratios = Vector3(values[0] / maxf(maximums[0], 1.0), values[1] / maxf(maximums[1], 1.0), values[2] / maxf(maximums[2], 1.0))
	dial.queue_redraw()
	energy_label.tooltip_text = "电容  %.0f / %.0f" % [ship.energy, float(metrics.energy_max)]
	energy_label.text = "电容 %.0f%%" % (ship.energy / maxf(float(metrics.energy_max), 1.0) * 100) if compact else energy_label.tooltip_text
	energy_bar.max_value = maxf(float(metrics.energy_max), 1.0)
	energy_bar.value = ship.energy
	heat_label.text = "热量  %.0f%%" % (ship.heat / maxf(float(metrics.heat_max), 1.0) * 100)
	heat_bar.max_value = maxf(float(metrics.heat_max), 1.0)
	heat_bar.value = ship.heat
	cargo_label.tooltip_text = "货 %.0f/%.0f L · 矿 %.0f/%.0f L" % [float(metrics.cargo_used_l), float(metrics.cargo_capacity_l), float(metrics.mineral_used_l), float(metrics.mineral_capacity_l)]
	cargo_label.text = "货 %.0f L" % float(metrics.cargo_used_l) if compact else cargo_label.tooltip_text
	compact_speed_label.tooltip_text = instrument_title.text + "\n" + instrument_title.tooltip_text + "\n" + cargo_label.tooltip_text
	instrument.tooltip_text = compact_speed_label.tooltip_text

func update_camera_status() -> void:
	if state == null or camera == null or not is_instance_valid(instrument_title): return
	var ship: Dtos.ShipStateDto = state.ship()
	var view: String = ["跟随视角", "舰首视角（舰体隐藏）", "战术视角"][int(camera.mode)]
	instrument_title.text = _ship_name(ship.ship_def_id) + "  /  " + view + " · V" + (" · 过热警报" if ship.overheated else "")
	instrument_title.modulate = UISkin.AMBER if ship.overheated else Color.WHITE
	instrument_title.tooltip_text = "V 循环切换跟随、舰首、战术视角。舰首视角从船头观察，不显示外部舰体；点击上方‘显示舰船’回到跟随视角。"
	compact_speed_label.text = "%.0f m/s · %s" % [Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length(), ["跟随", "舰首隐藏", "战术"][int(camera.mode)]]
	compact_speed_label.tooltip_text = instrument_title.text + "\n" + instrument_title.tooltip_text + "\n" + cargo_label.tooltip_text
	instrument.tooltip_text = compact_speed_label.tooltip_text

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

func _reveal_page_control(control: Control) -> void:
	if not is_instance_valid(control): return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()

func _focus_page() -> void:
	if not is_instance_valid(body) or page.is_empty():
		root.get_viewport().gui_release_focus()
		return
	var entries: Array[Control] = _focus_controls(station_layer if page == "station" else panel)
	if is_instance_valid(operation_bar) and operation_bar.visible:
		entries.append_array(_focus_controls(operation_bar))
	for index: int in range(entries.size()):
		# Business row actions already reveal both nested axes. Bind the other
		# page controls once, avoiding two scroll owners applying the same delta.
		if not bool(entries[index].get_meta("business_focus_bound", false)):
			entries[index].focus_entered.connect(_reveal_page_control.bind(entries[index]))
			entries[index].set_meta("business_focus_bound", true)
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
