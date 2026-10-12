class_name XJUI
extends CanvasLayer
signal requested(action: String, target: String, quantity: int, extra: String)
signal target_selected(id: String)
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
const NavigationHUD = preload("res://runtime/ui/navigation_hud.gd")
const OverviewPanel = preload("res://runtime/ui/overview_panel.gd")
const EquipmentBar = preload("res://runtime/ui/equipment_bar.gd")
const Context = preload("res://runtime/interaction_context.gd")
const ResourceStatus = preload("res://runtime/resource_status.gd")
const BusinessList = preload("res://runtime/ui/business_list.gd")
const WarehousePanel = preload("res://runtime/ui/warehouse_panel.gd")
const ItemPortraits = preload("res://runtime/ui/item_portraits.gd")
const ServiceNavigation = preload("res://runtime/ui/service_navigation.gd")
const CampaignPanel = preload("res://runtime/ui/campaign_panel.gd")
const FlightCues = preload("res://runtime/ui/flight_cues.gd")
const CivilizationPanel = preload("res://runtime/ui/civilization_panel.gd")
var civilization_selected_faction: String = ""
var civilization_panel: RefCounted
var source_item_id: String = ""
var source_search: String = ""
var source_filter: String = "全部"
var source_page: int = 0
var sources_return_page: String = "map"
var exploration_selected: String = ""
var frontier_selected_id: String=""
var war_navigation_row: HFlowContainer
var state: XJRuntimeState
var catalog: XJCatalog
var gameplay: RefCounted
var sector: XJSector
var camera: XJCameraRig
var root: Control
var top: Label
var flight_header: PanelContainer
var radar_button: Button
var radar_expanded: bool = false
var health: Label
var objective: Label
var toast: Label
var flight_cues: PanelContainer
var map_demand_readouts: Array[Dictionary] = []
var project_selected_id: String=""
var map_war_readout: Label
var controls: Label
var marker_layer: Control
var panel: PanelContainer
var body: VBoxContainer
var page: String = ""
var target_id: String = ""
var quantity_input: SpinBox
var warehouse_panel: XJWarehousePanel
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
var mission_filter: String = "all"
var mission_status_filter: String = "all"
var mission_location_filter: String = "local"
var mission_page: int = 0
var mission_focus_id: String = ""
var trial_selected_id: String = ""
var blockade_selected_id: String = ""
var mission_navigation_row: HFlowContainer
var mission_locate_button: Button
var mission_travel_button: Button
var mission_guide_button: Button
var market_filter: String = "buy"
var quantity_value: int = 1
var quotes: Array[Dictionary] = []
var business_list_view: XJBusinessList
var business_generation: int = 0
var business_quantities: Dictionary = {}
var business_quantity_identity: String = ""
var business_preserve_view: bool = false
var live_missions: Array[Dictionary] = []
var definition_cache: Dictionary = {}
var friendly_names: Dictionary = {}
const ACTION_NAMES: Dictionary = {"remote_support":"远程维修已开始","stop_remote_support":"远程维修已停止","consignment_action":"承运状态已更新","undock": "已出港", "dock": "已停靠", "switch_ship": "已切换驾驶舰", "buy_item": "购买完成", "sell_item": "出售完成", "buy_ship": "船体购买完成", "sell_ship": "船体出售完成", "move_stack": "货物转移完成", "move_item": "设备转移完成", "fit_module": "配装完成", "unfit_module": "设备已卸下", "repair": "维修完成", "manufacture": "生产完成", "recycle": "拆解完成", "accept_mission": "任务已接取", "abandon_mission": "任务已放弃", "deliver_mission": "任务已交付", "claim_loan": "任务舰已交接", "handoff_loan": "借船已归还", "request_rescue": "救援完成", "start_scan": "扫描已开始", "stop_scan": "扫描已停止", "start_mining": "采矿已开始", "stop_mining": "采矿已停止", "set_module_enabled": "设备开关已更新", "request_engine_cycle": "增推已启用", "research": "研究完成", "build_base": "设施已建成", "recover_resource": "组件已回收", "pickup_wreck": "残骸已回收"}
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
var operation_blocks_flight: bool = false
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
var map_details: VBoxContainer
var map_view_state: Dictionary = {}
var map_view_identity: String = ""
var map_origin_sector: String = ""
var map_route_button: Button
var map_route_destination: String = ""
var resource_chart: Control
var flight_dock: HBoxContainer
var top_toolbar_frame: PanelContainer
var toolbar_buttons: Dictionary = {}
var flight_content_top: float = 0.0
var flight_content_bottom: float = 0.0

func set_operation_status(kind: String, message: String, waiting: bool = false, blocks_flight: bool = false) -> void:
	operation_kind = kind
	operation_message = _friendly(message)
	operation_waiting = waiting
	# A queued snapshot waits for flight to finish; it must not prevent that flight.
	operation_blocks_flight = blocks_flight or kind in ["load", "travel"] or (kind == "save" and not waiting)
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
	flight_header = _frame(root, "FlightHeader")
	flight_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.reparent(flight_header)
	_text_to(navigation_layout, "导航", 11).add_theme_color_override("font_color", UISkin.MUTED)
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
	mission_navigation_row = HFlowContainer.new()
	mission_navigation_row.name = "MissionNavigationActions"
	mission_navigation_row.add_theme_constant_override("h_separation", 4)
	mission_navigation_row.add_theme_constant_override("v_separation", 3)
	hud_left.add_child(mission_navigation_row)
	mission_locate_button = _button(mission_navigation_row, "定位任务", func(): _hud_task_navigation(false))
	mission_locate_button.name = "MissionLocate"
	mission_travel_button = _button(mission_navigation_row, "前往目标", func(): _hud_task_navigation(true))
	mission_travel_button.name = "MissionTravel"
	mission_guide_button = _button(mission_navigation_row, "主线指引", _hud_task_details)
	mission_guide_button.name = "MissionGuide"
	for action_button: Button in [mission_locate_button, mission_travel_button, mission_guide_button]:
		action_button.custom_minimum_size = Vector2(76, 24)
		action_button.add_theme_font_size_override("font_size", 11)
		action_button.add_theme_stylebox_override("normal", UISkin.hud_button(false))
		# A focused HUD button must still leave W/S and other flight controls usable.
		action_button.focus_mode = Control.FOCUS_NONE
	mission_navigation_row.hide()
	war_navigation_row = HFlowContainer.new()
	war_navigation_row.name = "WarNavigationActions"
	war_navigation_row.add_theme_constant_override("h_separation", 4)
	war_navigation_row.add_theme_constant_override("v_separation", 3)
	hud_left.add_child(war_navigation_row)
	for order: String in ["route", "advance", "focus", "panel"]:
		var title: String = {"route": "战区航路", "advance": "舰队推进", "focus": "集火目标", "panel": "舰队指挥"}[order]
		var button: Button = _button(war_navigation_row, title, func():
			if order == "panel": show_page("civilizations")
			elif order == "route": requested.emit("war_navigate", "", 1, "")
			else: requested.emit("fleet_command", order, 1, target_id if order == "focus" else ""))
		button.custom_minimum_size = Vector2(76, 24)
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_stylebox_override("normal", UISkin.hud_button())
		button.focus_mode = Control.FOCUS_NONE
	war_navigation_row.hide()
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
	flight_cues = FlightCues.new()
	root.add_child(flight_cues)
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
	business_quantities.clear()
	business_quantity_identity = ""
	if map_view_identity != runtime.world_id + ":" + db.content_hash or map_origin_sector != runtime.current_sector():
		map_view_state.clear()
		map_view_identity = ""
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
	mission_focus_id = ""
	set_combat_automation_status({})
	show_page("station" if state.player().has_docked_station_id else "")
	navigation_hud.configure(sector, camera, catalog)
	_refresh_targets()

func show_title(save_slots: Array[Dictionary]) -> void:
	business_quantities.clear()
	business_quantity_identity = ""
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
	if not business_preserve_view:
		business_quantities.clear()
		business_quantity_identity = ""
	business_preserve_view = false
	if page == "map": _retain_map_view()
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
	_build_panel("配装挑战" if next_page=="trials" else "航路封锁" if next_page=="blockades" else "边疆工程" if next_page=="projects" else "远征航线" if next_page=="expeditions" else "航行战报" if next_page=="reports" else "雇佣僚舰" if next_page=="hire" else "边疆战役与治理" if next_page=="frontier" else "承运合同" if next_page=="consignments" else "配装分析" if next_page=="fitting_analysis" else "舰船角色" if next_page=="ship_roles" else "战术行动" if next_page == "operations" else "无人机管理" if next_page == "drones" else "星域事件" if next_page == "exploration" else "物资来源" if next_page == "sources" else ServiceNavigation.label(next_page), "%s  /  %s  /  %d 信用点" % [_station_name(state.player().docked_station_id) if state.player().has_docked_station_id else _sector_name(state.current_sector()), _ship_name(state.ship().ship_def_id), state.player().credit])
	if next_page in ["ships", "warehouse", "fitting", "market", "industry", "salvage", "research"] and not state.player().has_docked_station_id:
		if next_page=="ships" and gameplay.fitting_analysis.supported():_button(body,"舰船定位",show_page.bind("ship_roles")).name="ShipRolesEntry"
		if next_page=="ships" and gameplay.hired.supported():_button(body,"雇佣僚舰",show_page.bind("hire")).name="HireFleetEntry"
		_text("此服务需要停靠空间站。使用星图找到站点，进入停靠范围并减速后按 F。")
		_focus_page.call_deferred()
		return
	match next_page:
		"hire":
			var hire_panel: VBoxContainer=preload("res://runtime/ui/hire_panel.gd").new();body.add_child(hire_panel);hire_panel.setup(self)
		"frontier":
			var frontier_panel: VBoxContainer=preload("res://runtime/ui/frontier_panel.gd").new();body.add_child(frontier_panel);frontier_panel.setup(self,frontier_selected_id)
		"trials","blockades":
			var scenario_panel: VBoxContainer=preload("res://runtime/ui/scenario_panel.gd").new();body.add_child(scenario_panel);scenario_panel.setup(self,next_page)
		"projects","expeditions","reports":
			var campaign_panel: VBoxContainer=CampaignPanel.new();body.add_child(campaign_panel);campaign_panel.setup(self,next_page)
		"consignments":
			if gameplay.consignments.supported():
				var consignments: VBoxContainer=preload("res://runtime/ui/consignment_panel.gd").new();body.add_child(consignments);consignments.setup(self)
		"fitting_analysis":
			if gameplay.fitting_analysis.supported():
				var analysis: VBoxContainer=preload("res://runtime/ui/fitting_panel.gd").new();body.add_child(analysis);analysis.setup(self)
			else:_text("当前规则世界可升级后使用配装分析。")
		"ship_roles":
			if gameplay.fitting_analysis.supported():
				var roles: VBoxContainer=preload("res://runtime/ui/ship_roles_panel.gd").new();body.add_child(roles);roles.setup(self)
		"operations":
			var operations: VBoxContainer = preload("res://runtime/ui/operations_panel.gd").new(); body.add_child(operations); operations.setup(self)
		"drones":
			var drones: VBoxContainer = preload("res://runtime/ui/drone_panel.gd").new(); body.add_child(drones); drones.setup(self)
		"exploration":
			var explorer: VBoxContainer = preload("res://runtime/ui/exploration_panel.gd").new()
			body.add_child(explorer); explorer.setup(self)
		"sources":
			var sources: VBoxContainer = preload("res://runtime/ui/resource_sources.gd").new()
			body.add_child(sources); sources.setup(self)
		"ships": _ships()
		"warehouse": _warehouse()
		"fitting": _fitting()
		"market": _market()
		"industry": _industry()
		"salvage": _salvage()
		"missions": _missions()
		"research": _research()
		"civilizations":
			civilization_panel = CivilizationPanel.new()
			civilization_panel.build(self)
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
	if page=="consignments":
		var freight_panel: Node=body.find_child("ConsignmentPanel",true,false)
		if freight_panel!=null:freight_panel.call("refresh")
	if page == "civilizations" and civilization_panel != null: civilization_panel.tick()
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
	top.text = "%s · %s       %d 信用点       %s" % [_sector_name(ship.sector_id), _risk_name(str(definition.get("risk_zone_id", ""))), state.player().credit, _ship_name(ship.ship_def_id)]
	top.tooltip_text = top.text
	health.text = "护盾 %.0f/%.0f  装甲 %.0f/%.0f  结构 %.0f/%.0f\n电容 %.0f/%.0f  热量 %.0f/%.0f %s\n速度 %s\n货舱 %.0f/%.0f L  矿舱 %.0f/%.0f L" % [ship.shield, metrics.shield_max, ship.armor, metrics.armor_max, ship.hull, metrics.hull_max, ship.energy, metrics.energy_max, ship.heat, metrics.heat_max, "过热" if ship.overheated else "", XJSpaceUnits.speed(_display_speed()), metrics.cargo_used_l, metrics.cargo_capacity_l, metrics.mineral_used_l, metrics.mineral_capacity_l]
	if root.size.x < 900:
		health.text = "护盾 %.0f%% · 装甲 %.0f%% · 结构 %.0f%%\n电容 %.0f%% · 热量 %.0f%% %s\n速度 %s · 货 %.0f/%.0f L" % [ship.shield / maxf(metrics.shield_max, 1.0) * 100, ship.armor / maxf(metrics.armor_max, 1.0) * 100, ship.hull / maxf(metrics.hull_max, 1.0) * 100, ship.energy / maxf(metrics.energy_max, 1.0) * 100, ship.heat / maxf(metrics.heat_max, 1.0) * 100, "过热" if ship.overheated else "", XJSpaceUnits.speed(_display_speed()), metrics.cargo_used_l + metrics.mineral_used_l, metrics.cargo_capacity_l + metrics.mineral_capacity_l]
	objective.text = _objective_text()
	var operation: RefCounted = _hud_operation()
	if not gameplay.scenarios.pending().is_empty():objective.text=gameplay.scenarios.hud_text()
	elif not gameplay.frontier.focused_id().is_empty():objective.text=gameplay.frontier.status_text(gameplay.frontier.focused_id())
	elif operation != null: objective.text = gameplay.operations.hud_text()
	elif _hud_freight()!=null:objective.text=gameplay.consignments.hud_text(_hud_freight())
	elif _hud_expedition()!=null:
		var run: RefCounted=_hud_expedition()
		objective.text="远征 %d/3 · %s\n%s" % [run.stage_index,{"active":"处理当前事件","checkpoint":"已结算，选择后续","returning":"撤回并交付成果"}.get(run.phase,run.phase),str(gameplay.expeditions.guidance().get("target_title","查看远征详情"))]
	elif _hud_exploration()!=null and gameplay.situational.supported():
		var event: RefCounted=_hud_exploration()
		objective.text="探索 · "+gameplay.exploration.status_text(event.event_id).split("\n")[0]+"\n"+str(gameplay.exploration.guidance(event.event_id).target_title)
		var note: Dictionary=gameplay.situational.exploration_equipment(event.event_id)
		if not str(note.note).is_empty(): objective.text+="\n"+str(note.note)
	if operation == null and gameplay.frontier.focused_id().is_empty() and gameplay.exploration.supported() and not gameplay.situational.supported():
		for event: RefCounted in state.rows("exploration_instance_state"):
			if gameplay.exploration._site(event) and event.phase not in ["claimed", "failed", "withdrawn"]:
				objective.text += "\n" + gameplay.exploration.status_text(event.event_id)
				break
	objective.tooltip_text = objective.text
	_update_instrument(ship, metrics)
	_update_module_bar(ship, metrics)
	if page == "station": _update_station_info()
	_update_work()
	_update_mission_guidance()
	flight_cues.refresh(gameplay,root.size.x<950,state.ship().status==Types.ShipStatus.FLYING and not panel.visible and not station_layer.visible and not menu_open)
	_reflow_flight_left()
	_update_live_missions()
	_update_map_resources(float(metrics.total_mass_kg))
	_refresh_targets()
	_update_npc_target()
	_update_navigation()
	navigation_hud.update_annotations()

func input_blocked() -> bool:
	return ui_input_blocked()

func ui_input_blocked() -> bool:
	return keyboard_blocked() or _pointer_over(flight_header) or _pointer_over(target_panel) or _pointer_over(work_box) or _pointer_over(mission_navigation_row) or _pointer_over(operation_bar) or _pointer_over(navigation) or _pointer_over(flight_dock) or _pointer_over(instrument) or _pointer_over(equipment_bar) or _pointer_over(navigation_frame) or _pointer_over(controls) or _pointer_over(toast) or _pointer_over(flight_cues) or (is_instance_valid(navigation_hud) and _pointer_over(navigation_hud.radar_frame))

func keyboard_blocked() -> bool:
	var focus: Control = root.get_viewport().gui_get_focus_owner()
	return menu_open or panel.visible or station_layer.visible or focus is LineEdit or focus is TextEdit

func refresh_page() -> void:
	if not page.is_empty() and page != "settings" and page != "title":
		var previous_scroll: int = page_scroll.scroll_vertical if is_instance_valid(page_scroll) else 0
		var business_scroll: int = business_list_view.horizontal_scroll.scroll_horizontal if page in ["market", "industry"] and is_instance_valid(business_list_view) else 0
		if page in ["market", "industry"]:
			_retain_business_quantities()
			business_preserve_view = true
		var warehouse_view: Dictionary = warehouse_panel.snapshot_view() if page == "warehouse" and is_instance_valid(warehouse_panel) else {}
		show_page(page)
		if is_instance_valid(page_scroll): page_scroll.set_deferred("scroll_vertical", previous_scroll)
		if page in ["market", "industry"] and is_instance_valid(business_list_view): business_list_view.horizontal_scroll.set_deferred("scroll_horizontal", business_scroll)
		if not warehouse_view.is_empty() and is_instance_valid(warehouse_panel): warehouse_panel.restore_view(warehouse_view)

func select_next() -> void:
	if sector == null:
		return
	var keys: Array[String] = []
	for entry: Dictionary in sector.targets.values():
		var node: Variant = entry.get("node")
		if not is_instance_valid(node) or not node is Node3D: continue
		if str(entry.get("kind", "")) != "npc" or _npc_visible(entry, sector.target_distance(str(entry.id))):
			keys.append(str(entry.id))
	if keys.is_empty():
		target_id = ""
		return
	_select_target(str(keys[(keys.find(target_id) + 1) % keys.size()]))

func _build_panel(title: String, description: String) -> void:
	business_generation += 1
	civilization_panel = null
	business_list_view = null
	for child: Node in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	quotes.clear()
	live_missions.clear()
	map_resource_readouts.clear()
	map_demand_readouts.clear()
	map_details = null
	map_route_button = null
	map_route_destination = ""
	resource_chart = null
	quantity_input = null
	warehouse_panel = null
	card_grid = null
	panel.visible = true
	panel.modulate = Color.WHITE
	panel.add_theme_stylebox_override("panel", UISkin.plate() if page != "title" else StyleBoxEmpty.new())
	var shell: HBoxContainer = HBoxContainer.new()
	shell.add_theme_constant_override("separation", 18)
	panel.add_child(shell)
	sidebar = VBoxContainer.new()
	sidebar.name = "ServiceSidebar"
	sidebar.visible = root.size.x >= 950 and state != null and page not in ["title", "settings"]
	sidebar.custom_minimum_size.x = 190
	sidebar.add_theme_constant_override("separation", 8)
	shell.add_child(sidebar)
	if state != null and page not in ["title", "settings"]:
		_module_heading(sidebar, "服务导航")
		var service_scroll: ScrollContainer = ScrollContainer.new()
		service_scroll.name = "ServiceSidebarScroll"
		service_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		service_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		service_scroll.follow_focus = true
		sidebar.add_child(service_scroll)
		var service_rows: VBoxContainer = VBoxContainer.new()
		service_rows.name = "ServiceSidebarRows"
		service_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		service_rows.add_theme_constant_override("separation", 3)
		service_scroll.add_child(service_rows)
		for record: Dictionary in ServiceNavigation.pages(state.player().has_docked_station_id):
			_service_button(service_rows, str(record.id), "sidebar")
		var divider: HSeparator = HSeparator.new()
		sidebar.add_child(divider)
		var location: Label = _text_to(sidebar, _station_name(state.player().docked_station_id) if state.player().has_docked_station_id else _sector_name(state.current_sector()), 12)
		location.add_theme_color_override("font_color", UISkin.MUTED)
	else: sidebar.hide()
	if sidebar.visible: sidebar.visible = not _service_sidebar_compact()
	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	shell.add_child(layout)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	if state != null and page not in ["title", "settings"]:
		var heading_icon: TextureRect = TextureRect.new()
		heading_icon.name = "PageHeadingIcon"
		heading_icon.texture = ServiceNavigation.icon(_service_context_page())
		heading_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heading_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heading_icon.custom_minimum_size = Vector2(26, 26)
		heading_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heading_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(heading_icon)
	var heading: Label = _text_to(header, title, 48 if page == "title" else 25)
	heading.name = "PageHeading"
	heading.custom_minimum_size.x = 90
	heading.max_lines_visible = 2
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if state != null and page not in ["title", "settings"]:
		var selector: OptionButton = OptionButton.new()
		selector.name = "PageSelector"
		selector.custom_minimum_size = Vector2(164, 32)
		selector.add_theme_font_size_override("font_size", 12)
		selector.add_theme_constant_override("icon_max_width", 20)
		for record: Dictionary in ServiceNavigation.pages(state.player().has_docked_station_id):
			selector.add_icon_item(ServiceNavigation.icon(str(record.id)), str(record.label))
			selector.set_item_metadata(selector.item_count - 1, str(record.id))
		for index: int in range(selector.item_count):
			if selector.get_item_metadata(index) == _service_context_page(): selector.select(index)
		selector.item_selected.connect(func(index: int): show_page(str(selector.get_item_metadata(index))))
		selector.tooltip_text = "切换服务 · " + ServiceNavigation.label(_service_context_page())
		selector.visible = _service_sidebar_compact()
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
	page_scroll.resized.connect(_resize_map_canvas)
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
	station_services.add_theme_stylebox_override("panel", UISkin.hud_panel(8))
	station_services.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	station_services.offset_left = 22
	station_services.offset_right = 242
	station_services.offset_top = 64
	station_services.offset_bottom = -110
	var services: VBoxContainer = VBoxContainer.new()
	services.add_theme_constant_override("separation", 8)
	station_services.add_child(services)
	var heading: Label = _text_to(services, "服务导航", 14)
	heading.name = "StationNavigationHeading"
	heading.add_theme_color_override("font_color", UISkin.ICE)
	var service_scroll: ScrollContainer = ScrollContainer.new()
	service_scroll.name = "StationServiceScroll"
	page_scroll = service_scroll
	service_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	service_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	service_scroll.follow_focus = true
	services.add_child(service_scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	service_scroll.add_child(body)
	for record: Dictionary in ServiceNavigation.pages(true):
		_service_button(body, str(record.id), "hangar")
	var context_divider: HSeparator = HSeparator.new()
	body.add_child(context_divider)
	var overview_button: Button = _command(body, "观察舰船", "hangar_focus")
	overview_button.name = "HangarOverview"
	overview_button.icon = ServiceNavigation.texture(ServiceNavigation.OBSERVE_ICON)
	overview_button.tooltip_text = "恢复机库全景，观察当前驾驶舰。"
	_service_button_style(overview_button, false)
	var needs: Dictionary = gameplay.get("economy").call("repair_requirements")
	var price: int = int(gameplay.get("economy").call("quote_repair"))
	var repair: Button = _command(body, "维修补给 · %d 信用点" % price, "repair", state.ship().ship_instance_id)
	repair.name = "StationRepair"
	repair.icon = ServiceNavigation.icon("fitting")
	repair.tooltip_text = "维修补给 · %d 信用点\n需结构部件 × %d" % [price, int(needs.get("structural_units", 0))]
	repair.disabled = state.player().credit < price
	_service_button_style(repair, false)
	_text_to(body, "需结构部件 × %d" % int(needs.get("structural_units", 0)), 11).add_theme_color_override("font_color", UISkin.MUTED)
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
	_update_station_info()
	_focus_page.call_deferred()

func _ships() -> void:
	var fleet_tools: HFlowContainer=HFlowContainer.new();body.add_child(fleet_tools)
	if gameplay.fitting_analysis.supported():_button(fleet_tools,"查看18舰角色与预算",show_page.bind("ship_roles")).name="ShipRolesEntry"
	if gameplay.hired.supported():_button(fleet_tools,"雇佣僚舰",show_page.bind("hire")).name="HireFleetEntry"
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
	for operation: RefCounted in state.rows("operation_state"):
		if operation.cargo_units > 0 and operation.payload_ship_id == state.ship().ship_instance_id:
			_text("突破物资 × %d 已计入本舰货舱/载荷；送达、受损或任务页抛弃时移除。" % operation.cargo_units,14)
	var warehouse: String = ""
	var cargo: String = ""
	for container: Dtos.ContainerStateDto in state.rows("container_state"):
		if container.owner_player_id != state.player().player_id: continue
		if container.kind == Types.ContainerKind.STATION and container.station_id == state.player().docked_station_id: warehouse = container.container_id
		elif container.kind == Types.ContainerKind.CARGO and container.ship_instance_id == state.ship().ship_instance_id: cargo = container.container_id
	var ship_rows: Array[Dictionary] = []
	var station_rows: Array[Dictionary] = []
	for stack: Dtos.InventoryStackStateDto in state.rows("inventory_stack_state"):
		var data: Dictionary = _warehouse_row_data(stack.container_id, "stack", stack.stack_id, stack.item_def_id, stack.quantity, stack.policy_id, warehouse, cargo)
		if data.is_empty(): continue
		data.merge({"title": _item_name(stack.item_def_id), "description": _item_description(stack.item_def_id), "detail": "", "unit": _item_unit(stack.item_def_id), "thumbnail": ItemPortraits.texture("item", stack.item_def_id)})
		if data.is_station: station_rows.append(data)
		else: ship_rows.append(data)
	for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
		var data: Dictionary = _warehouse_row_data(item.container_id, "item", item.item_instance_id, item.item_def_id, 1, item.policy_id, warehouse, cargo)
		if data.is_empty(): continue
		var condition: String = "耐久 %.0f · 品质 %.2f" % [item.durability, item.quality_multiplier]
		data.merge({"title": _item_name(item.item_def_id), "description": _item_description(item.item_def_id) + "\n" + condition, "detail": condition, "unit": _item_unit(item.item_def_id), "thumbnail": ItemPortraits.texture("item", item.item_def_id)})
		if data.is_station: station_rows.append(data)
		else: ship_rows.append(data)
	var encounters: RefCounted = gameplay.get("encounters")
	if encounters != null and encounters.has_method("packages"):
		var packages: Array[Dictionary] = encounters.call("packages")
		for package: Dictionary in packages:
			var data: Dictionary = _warehouse_row_data(str(package.container_id), "salvage", str(package.package_id), "item", 1, "normal_owned", warehouse, cargo)
			if data.is_empty(): continue
			data.merge({"title": str(package.get("title", "未鉴定打捞包")), "description": "未鉴定密封包 · 体积 %.0f L · 质量 %.2f kg\n%s\n运到任意空间站后，在打捞鉴定页领取已封存的战利品。" % [float(package.get("volume_l", 0.0)), float(package.get("mass_kg", 0.0)), str(package.get("possible_rewards", "见数据库打捞说明"))], "detail": "密封打捞包 · 前往打捞鉴定页鉴定", "unit": "包", "thumbnail": ItemPortraits.texture("generic", "item")})
			if data.is_station: station_rows.append(data)
			else: ship_rows.append(data)
	ship_rows.sort_custom(_warehouse_row_before)
	station_rows.sort_custom(_warehouse_row_before)
	warehouse_panel = WarehousePanel.new()
	body.add_child(warehouse_panel)
	var inventory: RefCounted = gameplay.get("inventory")
	warehouse_panel.configure(ship_rows, station_rows, _ship_name(state.ship().ship_def_id) + " · 分舱位置见右列", "本站：" + _station_name(state.player().docked_station_id) + " · 异地只读", int(catalog.rule("business_quantity_limit")), Callable(inventory, "quote_transfer"))
	var token: Dictionary = {"state": state, "world_id": state.world_id, "session_id": state.session_id, "epoch": state.epoch, "station_id": state.player().docked_station_id, "ship_id": state.ship().ship_instance_id}
	warehouse_panel.transfer_requested.connect(_warehouse_transfer.bind(warehouse_panel, token))
	page_scroll.resized.connect(_resize_warehouse_panel)
	_resize_warehouse_panel.call_deferred()

func _warehouse_row_data(container_id: String, kind: String, id: String, asset_id: String, quantity: int, policy_id: String, warehouse: String, cargo: String) -> Dictionary:
	var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", container_id)
	if container == null or container.owner_player_id != state.player().player_id: return {}
	var is_station: bool = container.kind == Types.ContainerKind.STATION and container.has_station_id
	if not is_station and not _local_container(container_id): return {}
	var current: bool = is_station and container.station_id == state.player().docked_station_id
	var remote: bool = is_station and not current
	var location: String = "当前站\n" + _station_name(container.station_id) if current else _station_name(container.station_id) if is_station else "矿舱" if container.kind == Types.ContainerKind.MINERAL else "货舱"
	return {"id": id, "kind": kind, "asset_id": asset_id, "container_id": container_id, "station_id": container.station_id if is_station else "", "current_station": current, "remote": remote, "is_station": is_station, "location": location, "quantity": quantity, "policy_id": policy_id, "policy": _policy_name(policy_id), "destination": "" if remote else cargo if is_station else warehouse, "compartment_order": 1 if container.kind == Types.ContainerKind.MINERAL else 0}

func _warehouse_row_before(left: Dictionary, right: Dictionary) -> bool:
	if left.current_station != right.current_station: return bool(left.current_station)
	if left.station_id != right.station_id: return _station_name(str(left.station_id)).naturalnocasecmp_to(_station_name(str(right.station_id))) < 0
	if left.compartment_order != right.compartment_order: return int(left.compartment_order) < int(right.compartment_order)
	var kinds: Dictionary = {"stack": 0, "item": 1, "salvage": 2}
	if left.kind != right.kind: return int(kinds[left.kind]) < int(kinds[right.kind])
	var compared: int = str(left.title).naturalnocasecmp_to(str(right.title))
	return compared < 0 if compared != 0 else str(left.id) < str(right.id)

func _warehouse_transfer(kind: String, id: String, quantity: int, destination: String, source: XJWarehousePanel, token: Dictionary) -> void:
	if not is_inside_tree() or page != "warehouse" or not is_instance_valid(source) or source.is_queued_for_deletion() or warehouse_panel != source or state != token.state: return
	if state.world_id != token.world_id or state.session_id != token.session_id or state.epoch != token.epoch: return
	if not state.player().has_docked_station_id or state.player().docked_station_id != token.station_id or state.ship().ship_instance_id != token.ship_id: return
	var inventory: RefCounted = gameplay.get("inventory")
	var quote: Dictionary = inventory.call("quote_transfer", kind, id, quantity, destination)
	if not bool(quote.get("ok", false)):
		notify(str(quote.get("reason", "当前货物不可搬运")), true)
		return
	requested.emit(str({"stack": "move_stack", "item": "move_item", "salvage": "move_salvage"}.get(kind, "")), id, quantity, destination)

func _resize_warehouse_panel() -> void:
	if page == "warehouse" and is_instance_valid(warehouse_panel) and is_instance_valid(page_scroll) and page_scroll.size.y > 0.0:
		warehouse_panel.fit_height(page_scroll.size.y)

func _salvage() -> void:
	_text("击毁普通遭遇群 → 靠近并回收残骸 → 将未鉴定打捞包运到任意空间站 → 鉴定并领取真实战利品。", 14)
	_text("这里只显示本站仓库或当前舰货舱中的密封包；远方仓库与其他舰船的包需先运到本站。内容在包生成时确定，读档不会改变包内内容，已鉴定的包不能重复领取。", 13)
	var reason: String = _service_reason("warehouse")
	if not reason.is_empty(): _text(reason, 14)
	var list: VBoxContainer = _business_list("未鉴定打捞包", "鉴定费用", "数量")
	if _salvage_rows(list, false) == 0: _text("本地没有未鉴定打捞包。出港后可从目标总览的敌舰群选择遭遇地点；击毁后选择残骸，进入回收范围再按 F。教学目标只推进教学，不产生普通战利品。", 14)

func _salvage_rows(list: VBoxContainer, section: bool = true) -> int:
	var service: RefCounted = gameplay.get("encounters")
	if service == null or not service.has_method("packages"): return 0
	var count: int = 0
	var warehouse: String = _warehouse_id()
	var cargo: String = _ship_container(Types.ContainerKind.CARGO)
	var packages: Array[Dictionary] = service.call("packages")
	for package: Dictionary in packages:
		var container_id: String = str(package.get("container_id", ""))
		if not _local_container(container_id): continue
		var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", container_id)
		if container == null or container.kind not in [Types.ContainerKind.STATION, Types.ContainerKind.CARGO]: continue
		if count == 0 and section: list.call("add_section", "密封打捞包 · 鉴定后揭示内容")
		count += 1
		var package_id: String = str(package.package_id)
		var description: String = "未鉴定密封包 · 体积 %.0f L · 质量 %.2f kg\n可能内容 · %s\n鉴定后包消耗，战利品进入当前站仓库，信用点进入钱包。" % [float(package.get("volume_l", 0.0)), float(package.get("mass_kg", 0.0)), str(package.get("possible_rewards", "见数据库打捞说明"))]
		# The established unidentified industrial crate mark conveys a sealed
		# package; it does not imply that a specific module is inside.
		var entry: Dictionary = _asset_row(list, package_id, "generic", "item", str(package.get("title", "未鉴定打捞包")), description, "包", "1", "—", "—", _container_name(container) + "\n等待站内鉴定")
		entry.row.set_meta("salvage_package", true)
		var open: Button = _command(entry.actions, "鉴定战利品", "open_salvage", package_id)
		open.disabled = not state.player().has_docked_station_id or not _service_reason("warehouse").is_empty()
		if container_id != warehouse and not warehouse.is_empty(): _command(entry.actions, "移至站点仓库", "move_salvage", package_id, warehouse)
		if container_id != cargo and not cargo.is_empty(): _command(entry.actions, "装入当前舰货舱", "move_salvage", package_id, cargo)
	return count

func _fitting() -> void:
	if gameplay.fitting_analysis.supported():_button(body,"比较配装与资源预算",show_page.bind("fitting_analysis")).name="FittingAnalysisEntry"
	if gameplay.scenarios.supported():_button(body,"配装挑战",show_page.bind("trials")).name="FittingTrialEntry"
	if gameplay.drone_control.supported(): _button(body, "无人机管理", show_page.bind("drones")).name = "FittingDroneManagement"
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
			var slot_description: String = "空挂点；在下方设备列表选择适配模块安装。"
			if slot_type == "weapon": slot_description += "\n" + _ship_weapon_description(state.ship().ship_def_id)
			_asset_row(list, container.container_id, "generic", slot_type, slot_name, slot_description, "槽", "1", "—", "—", "未安装")
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
		if reason.is_empty() and compatible.is_empty(): reason = "没有同类空挂点"
		var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", item.container_id)
		var entry: Dictionary = _asset_row(list, item.item_instance_id, "item", item.item_def_id, _item_name(item.item_def_id), _item_description(item.item_def_id) + "\n耐久 %.0f · 品质 %.2f" % [item.durability, item.quality_multiplier], "件", "1", "—", "—", reason if not reason.is_empty() else _container_name(container) + "\n可安装")
		for empty: Dictionary in compatible:
			var install: Button = _command(entry.actions, "安装至 " + str(empty.title), "fit_module", item.item_instance_id, "%s:%d" % [str(empty.type), int(empty.index)])
			install.disabled = not reason.is_empty()
			install.tooltip_text = reason if not reason.is_empty() else "安装到 %s；舰种、口径、预算与科技在提交时再次校验。" % str(empty.title)
	if available == 0: _text("本地没有可安装设备；可在市场购买或工业制造。", 14)

func _market() -> void:
	var filters: HFlowContainer = HFlowContainer.new()
	body.add_child(filters)
	for filter: String in ["buy", "ships", "sell"]:
		var button: Button = _button(filters, str({"buy": "购买物资", "ships": "购买船体", "sell": "出售本地资产"}[filter]) + (" · 当前" if filter == market_filter else ""), _set_market_filter.bind(filter))
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size = Vector2(132, 36)
	_text("在各行填写成交数量；报价含税与声望优惠。悬停名称查看物品详情。", 14)
	var count: int = 0
	var list: VBoxContainer = _business_list("站点交易清单", "实收单价" if market_filter == "sell" else "含税单价", "成交数量")
	if market_filter == "buy":
		for stock: Dtos.ShopStockStateDto in state.rows("shop_stock_state"):
			if stock.station_id != state.player().docked_station_id: continue
			var definition: Dictionary = _stock_definition(stock.item_def_id)
			if not bool(definition.get("allow_buy", false)): continue
			count += 1
			var entry: Dictionary = _asset_row(list, stock.item_def_id, "item", stock.item_def_id, _item_name(stock.item_def_id), _item_description(stock.item_def_id), _item_unit(stock.item_def_id), "1", "—", "—", "库存 %d" % stock.quantity)
			_register_business_row(entry, "购买", "buy_item", stock.item_def_id, {"kind": "item", "id": stock.item_def_id, "selling": false, "maximum": stock.quantity, "unlock": str(definition.get("required_unlock_id", "")), "service": "trade"})
	elif market_filter == "ships":
		for stock: Dtos.ShopShipStockStateDto in state.rows("shop_ship_stock_state"):
			if stock.station_id != state.player().docked_station_id: continue
			count += 1
			var entry: Dictionary = _asset_row(list, stock.ship_def_id, "ship", stock.ship_def_id, _ship_name(stock.ship_def_id) + " · 裸舰", _ship_description(stock.ship_def_id) + "\n不含设备与弹药；舰体成交数量固定为一艘。", "艘", "1", "—", "—", "库存 %d" % stock.quantity)
			var role: Dictionary = _one("ship_role_defs", "ship_id", stock.ship_def_id)
			_register_business_row(entry, "购买舰体", "buy_ship", stock.ship_def_id, {"kind": "ship", "id": stock.ship_def_id, "selling": false, "fixed": 1, "maximum": stock.quantity, "unlock": str(role.get("required_unlock_id", "")), "service": "ship_purchase"})
	else:
		var budget: Dtos.StationEconomyStateDto = state.find("station_economy_state", "station_id", state.player().docked_station_id)
		if budget != null: _text("本站本轮回购预算 %d 信用点" % budget.buyback_remaining_credit, 14)
		for stack: Dtos.InventoryStackStateDto in state.rows("inventory_stack_state"):
			if not _local_container(stack.container_id): continue
			var definition: Dictionary = _stock_definition(stack.item_def_id)
			if not bool(definition.get("allow_sell", false)): continue
			count += 1
			var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", stack.container_id)
			var entry: Dictionary = _asset_row(list, stack.stack_id, "item", stack.item_def_id, _item_name(stack.item_def_id), _item_description(stack.item_def_id) + "\n" + _container_name(container), _item_unit(stack.item_def_id), "1", "—", "—", "持有 %d · %s" % [stack.quantity, _policy_name(stack.policy_id)])
			_register_business_row(entry, "出售", "sell_item", stack.stack_id, {"kind": "item", "id": stack.item_def_id, "selling": true, "maximum": stack.quantity, "policy": stack.policy_id, "service": "trade"})
		for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
			if not _local_container(item.container_id): continue
			var definition: Dictionary = _stock_definition(item.item_def_id)
			if not bool(definition.get("allow_sell", false)): continue
			count += 1
			var container: Dtos.ContainerStateDto = state.find("container_state", "container_id", item.container_id)
			var entry: Dictionary = _asset_row(list, item.item_instance_id, "item", item.item_def_id, _item_name(item.item_def_id), _item_description(item.item_def_id) + "\n耐久 %.0f · 品质 %.2f · %s" % [item.durability, item.quality_multiplier, _container_name(container)], "件", "1", "—", "—", _policy_name(item.policy_id))
			_register_business_row(entry, "出售设备", "sell_item", item.item_instance_id, {"kind": "item", "id": item.item_def_id, "selling": true, "maximum": 1, "fixed": 1, "policy": item.policy_id, "service": "trade"})
	if count == 0: _text("此页没有当前站点可交易的资产。")
	_update_quotes()

func _industry() -> void:
	if gameplay.projects.supported():_button(body,"边疆工程",show_page.bind("projects")).name="IndustryProjects"
	if gameplay.industry.supported():
		var jobs_panel: VBoxContainer = preload("res://runtime/ui/industry_panel.gd").new()
		body.add_child(jobs_panel); jobs_panel.setup(self, "jobs")
		var demand_panel: VBoxContainer = preload("res://runtime/ui/industry_panel.gd").new()
		body.add_child(demand_panel); demand_panel.setup(self, "demands")
	var has_manufacture: bool = false
	for service in _defs("station_service_defs"):
		if service.station_id == state.player().docked_station_id and service.service_id == "manufacture": has_manufacture = true
	if not has_manufacture:
		_text("本站不提供制造服务。请前往设有工业服务的空间站加工物资与建造舰体。")
		return
	_text("在各配方行填写生产批数；材料仅取本站仓库的普通自有物资。悬停名称查看本次材料与产出。", 14)
	var list: VBoxContainer = _business_list("生产与回收清单", "单位服务费", "数量 / 批数")
	list.call("add_section", "制造与提炼")
	for access: Dictionary in _defs("recipe_access_defs"):
		if access.station_id != state.player().docked_station_id: continue
		var recipe: Dictionary = _one("recipe_defs", "recipe_id", str(access.recipe_id))
		var item_id: String = str(recipe.get("output_item_id", ""))
		var entry: Dictionary = _asset_row(list, str(access.recipe_id), "item", item_id, "制造 / 提炼 · " + _item_name(item_id), _item_description(item_id), "批", "1", "—", "—", "材料来自本站仓库")
		_register_business_row(entry, "提交订单" if gameplay.industry.supported() else "生产", "manufacture", str(access.recipe_id), {"kind": "recipe", "id": str(access.recipe_id), "unlock": str(access.required_unlock_id), "service": "manufacture", "inputs_table": "recipe_inputs", "inputs_key": "recipe_id", "output_id": item_id, "output_quantity": int(recipe.get("output_quantity", 1)), "status_prefix": "材料来自本站仓库"})
		_source_button(entry.actions, str(access.recipe_id))
	list.call("add_section", "船坞制造")
	for recipe: Dictionary in _defs("hull_recipe_defs"):
		var local_yard: bool = false
		for stock: Dtos.ShopShipStockStateDto in state.rows("shop_ship_stock_state"):
			if stock.station_id == state.player().docked_station_id and stock.ship_def_id == recipe.ship_id: local_yard = true
		if not local_yard: continue
		var entry: Dictionary = _asset_row(list, str(recipe.hull_recipe_id), "ship", str(recipe.ship_id), "船坞 · " + _ship_name(str(recipe.ship_id)), _ship_description(str(recipe.ship_id)), "批", "1", "—", "—", "本站船坞")
		_register_business_row(entry, "制造舰体", "manufacture", str(recipe.hull_recipe_id), {"kind": "recipe", "id": str(recipe.hull_recipe_id), "unlock": str(recipe.required_unlock_id), "service": "manufacture", "inputs_table": "hull_recipe_inputs", "inputs_key": "hull_recipe_id", "output_id": str(recipe.ship_id), "output_quantity": 1, "status_prefix": "本站船坞"})
		_source_button(entry.actions, str(recipe.hull_recipe_id))
	list.call("add_section", "设备拆解 · 普通本地资产")
	for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
		if item.container_id != _warehouse_id() or item.policy_id != "normal_owned": continue
		var fee: int = int(catalog.rule("recycle_service_fee_credit"))
		var reason: String = _recycle_reason(item)
		var entry: Dictionary = _asset_row(list, item.item_instance_id, "item", item.item_def_id, "拆解 · " + _item_name(item.item_def_id), _item_description(item.item_def_id) + "\n" + _recycle_source_description(item), "件", "1", str(fee), str(fee), reason if not reason.is_empty() else "可拆解")
		_register_business_row(entry, "拆解设备", "recycle", item.item_instance_id, {"kind": "recycle", "id": item.item_def_id, "fixed": 1, "service": "recycle"})
	_update_quotes()

func _service_context_page() -> String:
	if page in ["fitting_analysis","trials"]: return "fitting"
	if page in ["ship_roles","hire"]: return "ships"
	if page in ["operations","expeditions","blockades"]: return "missions"
	if page=="projects":return "industry"
	if page=="reports":return "pause"
	if page=="frontier":return "civilizations"
	if page == "consignments": return "missions"
	if page == "exploration": return "map"
	if page == "drones": return "fitting"
	if page != "sources": return page
	if sources_return_page=="frontier":return "civilizations"
	return sources_return_page if sources_return_page in ["industry", "market", "map"] else "map"

func open_exploration(event_id: String = "") -> void:
	if not event_id.is_empty(): exploration_selected = event_id
	show_page("exploration")

func open_sources(item_id: String = "") -> void:
	if state == null: return
	sources_return_page = page if page != "sources" else sources_return_page
	if not item_id.is_empty(): source_item_id = item_id
	source_search = ""; source_page = 0; source_filter = "全部"
	show_page("sources")

func _source_button(parent: Node, blueprint_id: String) -> void:
	var quote: Dictionary = quotes[-1]
	var button: Button = _button(parent, "材料来源", func():
		if not _business_context_valid(quote): return
		var inputs: Array = gameplay.resource_intel.ingredients(blueprint_id)
		if inputs.is_empty(): return
		var selected: String = str(inputs[0].item_id)
		var batches: int = maxi(1, _business_row_quantity(quote))
		for input: Dictionary in inputs:
			if gameplay.inventory.count(_warehouse_id(), input.item_id, true) < int(input.quantity) * batches: selected = input.item_id; break
		open_sources(selected))
	button.name = "RecipeSources_" + blueprint_id
	button.tooltip_text = "查询本行缺料的采集、采购、加工和打捞地点及实际航路，不消耗任何物资。"

func _missions() -> void:
	if gameplay.expeditions.supported():_button(body,"远征航线",show_page.bind("expeditions")).name="MissionExpeditions"
	if gameplay.scenarios.supported():_button(body,"航路封锁",show_page.bind("blockades")).name="MissionBlockades"
	if gameplay.consignments.supported():_button(body,"承运合同",show_page.bind("consignments")).name="MissionFreight"
	if gameplay.operations.supported():
		_button(body,"查看拆除与突破行动",func(): show_page("operations")).name = "MissionOperations"
	_text("本页不暂停飞行。目标按顺序完成；舰船损失保留当前任务，交付需要指定实物。", 14)
	_campaign_summary()
	_mission_filter_group("type", "类型", ["all", "tutorial", "story", "civilization", "contract"], {"all": "全部类型", "tutorial": "新手教学", "story": "主线剧情", "civilization": "文明入籍", "contract": "地区合同"}, mission_filter)
	_mission_filter_group("status", "状态", ["all", "active", "available", "completed"], {"all": "全部状态", "active": "进行中", "available": "可接取", "completed": "已完成"}, mission_status_filter)
	_mission_filter_group("location", "地点", ["local", "all"], {"local": "本站" if state.player().has_docked_station_id else "本星系", "all": "所有地点"}, mission_location_filter)
	var filtered: Array[Dictionary] = _filtered_mission_definitions()
	var pages: int = maxi(1, ceili(float(filtered.size()) / 6.0))
	mission_page = clampi(mission_page, 0, pages - 1)
	var navigation: HBoxContainer = HBoxContainer.new()
	body.add_child(navigation)
	var previous: Button = _button(navigation, "上一页", func(): mission_page -= 1; show_page("missions"))
	previous.disabled = mission_page <= 0
	_text_to(navigation, "%d 项 · %d / %d 页" % [filtered.size(), mission_page + 1, pages], 14)
	var next: Button = _button(navigation, "下一页", func(): mission_page += 1; show_page("missions"))
	next.disabled = mission_page >= pages - 1
	if filtered.is_empty():
		_text("没有同时符合这些筛选条件的任务。清除筛选可查看异地任务与尚未满足的前置条件。", 13)
		var clear: Button = _button(body, "清除筛选", _clear_mission_filters)
		clear.set_meta("mission_clear_filters", true)
	var list: VBoxContainer = _business_list("任务与合同清单", "接取费用", "合同数")
	var focused_action: Button
	for definition: Dictionary in filtered.slice(mission_page * 6, mini((mission_page + 1) * 6, filtered.size())):
		var current: Dtos.MissionStateDto = _latest_mission(str(definition.mission_id))
		var active: bool = current != null and current.status in ["active", "ready"]
		var reason: String = _mission_reason(definition, current)
		var entry: Dictionary = _asset_row(list, str(definition.mission_id), "mission", str(definition.mission_id), _mission_category_title(definition) + " · " + _mission_name(str(definition.mission_id)), _mission_list_description(definition, current), "份", "1", "—", "奖励 %d" % int(definition.get("reward_credit", 0)), _mission_status(current.status) if active else reason if not reason.is_empty() else "可接取")
		entry.row.set_meta("mission_row", true)
		entry.row.set_meta("mission_kind", str(definition.mission_kind))
		if active:
			live_missions.append({"label": entry.status, "mission": current, "description": entry.description, "definition": definition, "progress": []})
			var deliver: Button = _command(entry.actions, "交付任务", "deliver_mission", current.mission_instance_id)
			deliver.disabled = current.status != "ready" or state.player().docked_station_id != definition.turnin_station_id
			if current.status == "ready": _mission_row_primary(deliver)
			var locate: Button = _mission_action(entry.actions, "定位任务目标", "mission_locate", str(definition.mission_id))
			if str(definition.mission_id) == mission_focus_id: focused_action = locate
			if current.status != "ready": _mission_row_primary(locate)
			_mission_action(entry.actions, "前往任务目标", "mission_travel", str(definition.mission_id))
			if gameplay.situational.supported(): _equipment_guide_button(entry.actions,entry.row,_mission_guidance(current))
			_secondary(_command(entry.actions, "放弃任务", "abandon_mission", current.mission_instance_id))
		else:
			var accept: Button = _command(entry.actions, "接取任务" if current == null else "重新接取", "accept_mission", str(definition.mission_id))
			accept.disabled = not reason.is_empty()
			_mission_row_primary(accept)
			var station_action: Button = _mission_action(entry.actions, "定位接取站点", "mission_station", str(definition.mission_id))
			_secondary(station_action)
			if str(definition.mission_id) == mission_focus_id: focused_action = station_action
		var prerequisite_id: String = str(gameplay.get("missions").call("missing_prerequisite", str(definition.mission_id)))
		if not prerequisite_id.is_empty():
			var predecessor: Button = _button(entry.actions, "查看前置任务", show_mission.bind(prerequisite_id))
			predecessor.set_meta("action", "show_mission")
			predecessor.set_meta("target", prerequisite_id)
		if str(definition.mission_id) == mission_focus_id:
			entry.row.set_meta("mission_focused", true)
			entry.name.add_theme_color_override("font_color", UISkin.AMBER)
	_update_live_missions()
	if focused_action != null: _focus_mission_action.call_deferred(focused_action)

func _equipment_guide_button(parent: Node, witness_node: Control, info: Dictionary) -> void:
	var note: Dictionary=gameplay.situational.mission_equipment(info)
	if str(note.note).is_empty(): return
	var expected_state: XJRuntimeState=state
	var expected_epoch: int=state.epoch
	var expected_generation: int=business_generation
	var witness: WeakRef=weakref(witness_node)
	var button: Button=_button(parent,"检查配装",func():
		var node: Variant=witness.get_ref()
		if state!=expected_state or state.epoch!=expected_epoch or business_generation!=expected_generation or page!="missions": return
		if not is_instance_valid(node) or not node.is_inside_tree() or not body.is_ancestor_of(node): return
		show_page("fitting" if state.ship().status==Types.ShipStatus.DOCKED else "fitting_analysis"))
	button.name="MissionEquipmentGuide"
	button.tooltip_text=str(note.note)+"。已装设备可在飞行设备栏启用；安装和补充需到站。"

func _mission_row_primary(button: Button) -> void:
	# BusinessList uses compact style margins for every state. Keep those
	# metrics when emphasizing an action so disabling it cannot shrink its cell.
	button.add_theme_stylebox_override("normal", UISkin.hud_button(true))
	button.add_theme_stylebox_override("hover", UISkin.hud_button(true))
	button.add_theme_stylebox_override("pressed", UISkin.hud_button(true))
	button.add_theme_color_override("font_color", Color("ffdf9d"))

func _mission_filter_group(dimension: String, title: String, values: Array[String], titles: Dictionary, selected: String) -> void:
	var row: HFlowContainer = HFlowContainer.new()
	row.name = "MissionFilter" + dimension.capitalize()
	row.set_meta("mission_filter_dimension", dimension)
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	body.add_child(row)
	var label: Label = _label(row, title, 13)
	label.custom_minimum_size = Vector2(36, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", UISkin.MUTED)
	for value: String in values:
		var button: Button = _button(row, str(titles[value]), _set_mission_filter.bind(dimension, value))
		button.custom_minimum_size = Vector2(0, 30)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", 13)
		button.toggle_mode = true
		button.button_pressed = value == selected
		button.set_meta("mission_filter_dimension", dimension)
		button.set_meta("mission_filter_value", value)
		if value == selected: _primary(button)
		else: _secondary(button)
		button.tooltip_text = "仅修改%s筛选，保留其他筛选条件。" % title
		if dimension == "location": button.tooltip_text += "\n按任务接取站点筛选；当前任务始终显示在页首。"
		if dimension == "status" and value == "completed": button.tooltip_text += "\n展示已领取过奖励的任务；重接后正在进行的任务归入“进行中”。"

func _set_mission_filter(dimension: String, value: String) -> void:
	match dimension:
		"type": mission_filter = value
		"status": mission_status_filter = value
		"location": mission_location_filter = value
	mission_focus_id = ""
	mission_page = 0
	show_page("missions")

func _clear_mission_filters() -> void:
	mission_filter = "all"
	mission_status_filter = "all"
	mission_location_filter = "all"
	mission_focus_id = ""
	mission_page = 0
	show_page("missions")

func _filtered_mission_definitions() -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for definition: Dictionary in _defs("mission_summary_defs"):
		var current: Dtos.MissionStateDto = _latest_mission(str(definition.mission_id))
		var active: bool = current != null and current.status in ["active", "ready"]
		var local: bool = definition.accept_station_id == state.player().docked_station_id if state.player().has_docked_station_id else _one("station_defs", "station_id", str(definition.accept_station_id)).get("sector_id") == state.current_sector()
		if mission_location_filter == "local" and not local: continue
		if mission_status_filter == "available" and not _mission_reason(definition, current).is_empty(): continue
		if mission_status_filter == "active" and not active: continue
		if mission_status_filter == "completed" and (active or not _mission_completed(str(definition.mission_id))): continue
		if mission_filter in ["tutorial", "story", "civilization", "contract"] and _mission_display_kind(definition) != mission_filter: continue
		filtered.append(definition)
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if mission_filter in ["tutorial", "story"]: return _mission_chain_index(a) < _mission_chain_index(b)
		var rank_a: int = _mission_rank(a)
		var rank_b: int = _mission_rank(b)
		return str(a.mission_id) < str(b.mission_id) if rank_a == rank_b else rank_a < rank_b)
	return filtered

func show_mission(mission_id: String) -> void:
	var definition: Dictionary = _one("mission_defs", "mission_id", mission_id)
	if definition.is_empty(): notify("未找到此任务的冻结定义。", true); return
	mission_focus_id = mission_id
	mission_filter = _mission_display_kind(definition)
	mission_status_filter = "all"
	mission_location_filter = "all"
	var index: int = 0
	for entry: Dictionary in _filtered_mission_definitions():
		if str(entry.mission_id) == mission_id: break
		index += 1
	mission_page = floori(float(index) / 6.0)
	show_page("missions")

func _focus_mission_action(button: Button) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree() or not button.is_visible_in_tree() or page != "missions": return
	button.grab_focus()
	if is_instance_valid(page_scroll) and page_scroll.is_ancestor_of(button): page_scroll.ensure_control_visible(button)

func _mission_action(parent: Node, title: String, action: String, mission_id: String) -> Button:
	var button: Button = _button(parent, title, func(): requested.emit(action, mission_id, 1, ""))
	button.set_meta("action", action)
	button.set_meta("target", mission_id)
	return button

func _mission_chain_index(definition: Dictionary) -> int:
	var index: int = 0
	for entry: Dictionary in gameplay.get("missions").call("chain", str(definition.mission_kind)):
		if str(entry.mission_id) == str(definition.mission_id): return index
		index += 1
	return index

func _mission_display_kind(definition: Dictionary) -> String:
	if catalog.table_names.has("civilization_join_missions") and not _one("civilization_join_missions", "mission_id", str(definition.mission_id)).is_empty(): return "civilization"
	return str(definition.mission_kind)

func _mission_category_title(definition: Dictionary) -> String:
	if _mission_display_kind(definition) == "civilization": return "文明入籍"
	var kind: String = str(definition.get("mission_kind", ""))
	var title: String = str({"tutorial": "新手教学", "story": "主线剧情", "contract": "地区合同"}.get(kind, "任务"))
	if kind in ["tutorial", "story"]: title += " %d" % (_mission_chain_index(definition) + 1)
	return title

func _campaign_summary() -> void:
	var service: RefCounted = gameplay.get("missions")
	var summary: Array[String] = []
	var current: Dtos.MissionStateDto = service.call("active")
	var next_id: String = current.mission_def_id if current != null else ""
	for kind: String in ["tutorial", "story"]:
		var nodes: Array[Dictionary] = service.call("chain", kind)
		var done: int = 0
		for node: Dictionary in nodes:
			if _mission_completed(str(node.mission_id)): done += 1
			elif next_id.is_empty(): next_id = str(node.mission_id)
		summary.append("%s %d/%d" % ["新手教学" if kind == "tutorial" else "主线剧情", done, nodes.size()])
	_text_to(body, "航路重建进度 · " + "   /   ".join(summary), 16).add_theme_color_override("font_color", UISkin.AMBER)
	if next_id.is_empty(): _text("主线航路已全部重建，可继续接取地区合同、研究与自由探索。", 13); return
	var next_def: Dictionary = _one("mission_defs", "mission_id", next_id)
	var missing: String = str(service.call("missing_prerequisite", next_id))
	var card: PanelContainer = _frame(body, "MissionRecommendation")
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	card.add_child(content)
	_text_to(content, ("当前任务 · " if current != null else "推荐任务 · ") + _mission_category_title(next_def) + " · " + _mission_name(next_id), 15).add_theme_color_override("font_color", UISkin.AMBER)
	var guidance: Dictionary = service.call("guidance", next_id) if current != null else service.call("station_guidance", next_id)
	var note: String = "状态 · " + (_mission_status(current.status) if current != null else _mission_reason(next_def, _latest_mission(next_id)))
	if note == "状态 · ": note += "可接取"
	note += "\n" + _mission_location_text(guidance)
	if not missing.is_empty(): note += "\n尚需完成 · " + _mission_name(missing)
	if current == null and str(next_def.mission_kind) == "tutorial":
		var story_nodes: Array[Dictionary] = service.call("chain", "story")
		if not story_nodes.is_empty():
			var first_story_station: String = str(story_nodes[0].accept_station_id)
			note += "\n完成新手教学后开启主线；第一章接取点 · " + _station_name(first_story_station)
	_text_to(content, note, 13)
	var actions: HFlowContainer = HFlowContainer.new()
	content.add_child(actions)
	var show_next: Button = _button(actions, "查看当前任务" if current != null else "查看推荐任务", show_mission.bind(next_id))
	show_next.autowrap_mode = TextServer.AUTOWRAP_OFF
	show_next.set_meta("action", "show_mission")
	show_next.set_meta("target", next_id)
	show_next.set_meta("mission_recommendation", "view")
	_primary(show_next)
	var marker: Button = _mission_action(actions, "标记交付站" if current != null and current.status == "ready" else "标记任务目标" if current != null else "标记接取站", "mission_locate" if current != null else "mission_station", next_id)
	marker.autowrap_mode = TextServer.AUTOWRAP_OFF
	marker.set_meta("mission_recommendation", "marker")
	marker.disabled = guidance.is_empty()
	marker.tooltip_text = "指示任务地点，出港后选中相应航点；不会自动移动舰船或接取任务。\n" + _mission_location_text(guidance)
	_secondary(marker)

func _research() -> void:
	if gameplay.specializations.supported():
		var specialization: VBoxContainer=preload("res://runtime/ui/specialization_panel.gd").new();body.add_child(specialization);specialization.setup(self)
	if gameplay.exploration.supported():
		var progress: RefCounted = state.rows("exploration_progress_state")[0]
		_text("探索证据 %d · 累计 %d；救援、遗迹和临时矿带都可积累。" % [progress.insight_available, progress.insight_earned], 17)
		for project: Dictionary in _defs("exploration_research_defs"):
			var frame: PanelContainer = _frame(body, "ExplorationResearch_" + str(project.research_id))
			var contents: VBoxContainer = VBoxContainer.new(); frame.add_child(contents)
			_text_to(contents, str(project.display_name) + " · " + str(project.description), 15)
			_text_to(contents, "需要探索证据 %d / 信用点 %d" % [int(project.required_insight), int(project.required_credit)], 13)
			var context: Dictionary = {"state": state, "epoch": state.epoch, "session": state.session_id, "station": state.player().docked_station_id}
			var research_id: String = project.research_id
			var study: Button = _button(contents, "研究", func():
				if page == "research" and state == context.state and state.epoch == context.epoch and state.session_id == context.session and state.player().docked_station_id == context.station: requested.emit("exploration_research", research_id, 1, ""))
			study.name = "ExploreResearch_" + research_id
			var done: bool = state.find("exploration_research_state", "research_id", research_id) != null
			study.disabled = done or progress.insight_available < int(project.required_insight) or state.player().credit < int(project.required_credit) or not _service_reason("manufacture").is_empty()
			study.tooltip_text = "已掌握" if done else "需要足够探索证据、信用点与工业实验设施。"
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
		var civilization_reason: String = gameplay.civilizations.research_reason(str(definition.research_id))
		if not done and not civilization_reason.is_empty(): reason = civilization_reason
		var description: String = "解锁 " + _unlock_name(str(definition.reward_unlock_id)) + " · 需声望 %d\n" % int(definition.required_reputation) + _inputs_text("research_inputs", "research_id", str(definition.research_id))
		for prerequisite: Dictionary in _defs("research_prerequisites"):
			if str(prerequisite.research_id) == str(definition.research_id): description += "\n前置科技 · " + _unlock_name(str(prerequisite.unlock_id)) + ("（已解锁）" if _unlocked(str(prerequisite.unlock_id)) else "（未解锁）")
		var verification_id: String = str(definition.verification_mission_id) if definition.get("verification_mission_id") != null else ""
		if not verification_id.is_empty():
			var verification: Dictionary = _one("mission_defs", "mission_id", verification_id)
			description += "\n验证要求 · " + _mission_category_title(verification) + " · " + _mission_name(verification_id) + ("（已完成）" if _mission_completed(verification_id) else "（未完成）")
			description += "\n接取地点 · " + _sector_name(str(_one("station_defs", "station_id", str(verification.accept_station_id)).get("sector_id", ""))) + " / " + _station_name(str(verification.accept_station_id))
		var entry: Dictionary = _asset_row(list, str(definition.research_id), "research", str(definition.research_id), str(definition.display_name), description, "项", "1", str(int(definition.required_credit)), str(int(definition.required_credit)), reason if not reason.is_empty() else "可研究")
		var button: Button = _command(entry.actions, "完成研究", "research", str(definition.research_id))
		button.disabled = not reason.is_empty()
		if not verification_id.is_empty():
			var prerequisite_button: Button = _button(entry.actions, "查看主线前置" if not _mission_completed(verification_id) else "查看验证任务", show_mission.bind(verification_id))
			prerequisite_button.set_meta("action", "show_mission")
			prerequisite_button.set_meta("target", verification_id)
			prerequisite_button.tooltip_text = "打开 " + _mission_name(verification_id) + "，显示前置链、接取站点与任务目标。"
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
	_text("选择星系查看情报；拖动视图、滚轮缩放。定位后，前往虫洞并减速按 F 穿越。", 14)
	if gameplay.exploration.supported():
		var events: Button = _button(body, "查看星域探索事件", func(): open_exploration())
		events.name = "MapExplorationEvents"
	var sources: Button = _button(body, "查询物资来源", func(): open_sources())
	sources.name = "MapResourceSources"
	var identity: String = state.world_id + ":" + catalog.content_hash
	if map_view_identity != identity: map_view_state.clear()
	map_view_identity = identity
	map_origin_sector = state.current_sector()
	var chart_script: Script = load("res://runtime/ui/star_chart.gd")
	var chart: Control = chart_script.new()
	body.add_child(chart)
	resource_chart = chart
	chart.call("configure", catalog, state, gameplay)
	map_details = VBoxContainer.new()
	map_details.name = "SelectedSectorDetails"
	map_details.add_theme_constant_override("separation", 8)
	body.add_child(map_details)
	chart.connect("sector_selected", _map_sector_selected)
	chart.connect("navigation_changed", _update_map_route_action)
	if not map_view_state.is_empty(): chart.call("restore_view", map_view_state)
	_map_sector_selected(str(chart.get("selected_sector")))
	_resize_map_canvas()

func _retain_map_view() -> void:
	if not is_instance_valid(resource_chart) or state == null or catalog == null: return
	var chart_state: XJRuntimeState = resource_chart.get("state")
	var chart_catalog: XJCatalog = resource_chart.get("catalog")
	if chart_state == null or chart_catalog == null or chart_state.world_id != state.world_id or chart_state.current_sector() != state.current_sector() or chart_catalog.content_hash != catalog.content_hash: return
	map_view_identity = state.world_id + ":" + catalog.content_hash
	map_view_state = resource_chart.call("export_view")

func _map_sector_selected(id: String) -> void:
	if page != "map" or not is_instance_valid(map_details): return
	var selected: Dictionary = _one("sector_defs", "sector_id", id)
	if selected.is_empty(): return
	var focused: Control = root.get_viewport().gui_get_focus_owner()
	for child: Node in map_details.get_children():
		map_details.remove_child(child)
		child.queue_free()
	map_resource_readouts.clear()
	map_route_button = null
	map_route_destination = ""
	map_details.set_meta("selected_sector", id)
	var frame: PanelContainer = _frame(map_details, "SelectedSectorLocations")
	var locations: VBoxContainer = VBoxContainer.new()
	locations.add_theme_constant_override("separation", 8)
	frame.add_child(locations)
	_module_heading(locations, "星系地点 · " + _sector_name(id), "本星系地点可定位；外星系先规划虫洞航路。")
	var local: bool = id == state.current_sector()
	for station: Dictionary in _defs("station_defs"):
		if str(station.sector_id) != id: continue
		_text_to(locations, "空间站 · " + _station_name(str(station.station_id)), 14)
		if local: _map_location_button(locations, "定位 " + _station_name(str(station.station_id)), str(station.station_id), id)
	for resource: Dictionary in _defs("resource_node_defs"):
		if str(resource.sector_id) != id: continue
		if gameplay.situational.supported() and not gameplay.exploration.resource_visible(resource.node_id) and state.find("resource_intel_state","node_id",resource.node_id)==null:continue
		var readout: Label = _text_to(locations, _resource_map_readout(str(resource.node_id), id), 13)
		readout.name = "ResourceIntel_" + str(resource.node_id).validate_node_name()
		readout.tooltip_text = readout.text + "\n现场更新；远程只显示上次观测，过期需复测。暂停与退出不推进。"
		map_resource_readouts.append({"node_id": str(resource.node_id), "sector_id": id, "label": readout})
		if local: _map_location_button(locations, "定位 " + _item_name(str(resource.item_id)) + "矿点", str(resource.node_id), id)
	for endpoint: Dictionary in _defs("gate_endpoint_defs"):
		if str(endpoint.origin_sector_id) != id: continue
		_text_to(locations, "虫洞航路 → " + _sector_name(str(endpoint.target_sector_id)), 14)
		if local: _map_location_button(locations, "定位通往 " + _sector_name(str(endpoint.target_sector_id)) + " 的虫洞门", str(endpoint.endpoint_id), id)
	if gameplay.situational.supported():
		_map_demands(locations,id)
		map_war_readout = _text_to(locations,_map_war_note(id),13)
		map_war_readout.name="SectorWarBulletin"
		map_war_readout.set_meta("sector_id",id)
		map_war_readout.visible=not map_war_readout.text.is_empty()
	if not local and gameplay != null:
		map_route_destination = id
		map_route_button = _button(locations, "定位航路起点", _map_locate_route.bind(id))
		map_route_button.set_meta("map_route_destination", id)
		_update_map_route_action()
	# Relink current controls without stealing the graph/search focus on selection.
	_focus_page()
	if is_instance_valid(focused) and focused.is_inside_tree(): focused.grab_focus()

func _map_location_button(parent: Node, title: String, id: String, origin: String) -> Button:
	var button: Button = _button(parent, title, _map_locate_target.bind(id))
	button.set_meta("map_target_id", id)
	button.set_meta("map_sector_id", origin)
	button.disabled = not _map_target_available(id)
	button.tooltip_text = "选择实际航行目标并返回航行界面；距离、速度、权限和费用由实际操作校验。" if not button.disabled else "当前位置尚没有此地点的实际目标。"
	return button

func _map_demands(parent: Node, sector_id: String) -> void:
	var captured_state: XJRuntimeState = state
	var captured_epoch: int = state.epoch
	var generation: int = business_generation
	for spec: Dictionary in _defs("station_demand_defs"):
		var station: Dictionary = _one("station_defs","station_id",spec.station_id)
		if str(station.get("sector_id",""))!=sector_id: continue
		var demand_id: String = spec.demand_id
		_text_to(parent,"需求 · "+_station_name(spec.station_id)+" · "+_item_name(spec.item_id),14)
		var label: Label = _text_to(parent,gameplay.situational.demand_text(demand_id),13)
		label.name="DemandIntel_"+demand_id
		var witness: WeakRef=weakref(label)
		map_demand_readouts.append({"id":demand_id,"label":label})
		var info: Dictionary = gameplay.missions._route_location(gameplay.missions._station_location(spec.station_id),"")
		var button: Button = _button(parent,"查看工业与回收" if gameplay.station()==str(spec.station_id) else "前往需求站",func():
			if page!="map" or state!=captured_state or state.epoch!=captured_epoch or business_generation!=generation: return
			var current_label: Variant=witness.get_ref()
			if not is_instance_valid(current_label) or not current_label.is_inside_tree() or not map_details.is_ancestor_of(current_label): return
			if gameplay.station()==str(spec.station_id): show_page("industry")
			else: requested.emit("demand_navigate",demand_id,1,""))
		button.name="DemandTravel_"+demand_id
		button.disabled=gameplay.station()!=str(spec.station_id) and (state.ship().status!=Types.ShipStatus.FLYING or not str(info.route_reason).is_empty())
		button.tooltip_text="到站重新核实报价和余量；本按钮只规划实际航路。"+str(info.route_reason)

func _map_war_note(id: String) -> String:
	var notes: PackedStringArray=[]
	for war: RefCounted in state.rows("war_campaign_state"):
		var def: Dictionary=_one("civilization_war_defs","war_id",war.war_id)
		if str(def.get("target_sector_id",""))==id and war.status in ["assembling","fighting","occupying"]:
			notes.append("已受领战役 · "+gameplay.frontier.status_text(war.war_id))
	var row: RefCounted=gameplay.frontier.territory(id)
	if row!=null and row.phase in ["warning","defending"]: notes.append("驻防通报 · "+gameplay.frontier.status_text(id))
	return "\n".join(notes)

func _map_target_available(id: String) -> bool:
	if not is_instance_valid(sector) or not sector.targets.has(id): return false
	var node: Variant = sector.targets[id].get("node")
	return is_instance_valid(node) and node is Node3D and node.is_inside_tree()

func _map_locate_target(id: String) -> void:
	if page != "map" or state == null: return
	if not _map_target_available(id):
		notify("地点已失效，请重新选择星系。", true)
		return
	_select_target(id)
	_back()

func _update_map_route_action() -> void:
	if not is_instance_valid(map_route_button) or not is_instance_valid(resource_chart): return
	var status: Dictionary = resource_chart.call("route_status", map_route_destination)
	map_route_button.disabled = not bool(status.get("open", false))
	var reasons: Array[String] = []
	for reason: Variant in status.get("blocked", []): reasons.append(str(reason))
	map_route_button.tooltip_text = "按当前合法航路选择第一座虫洞；通行条件在门口再次检查。" if not map_route_button.disabled else "\n".join(reasons) if not reasons.is_empty() else "当前位置没有可规划的虫洞航路。"

func _map_locate_route(destination: String) -> void:
	if page != "map" or state == null or gameplay == null or destination != map_route_destination: return
	var route: Array = gameplay.missions._route(state.current_sector(), destination, true)
	if route.is_empty():
		_update_map_route_action()
		notify("航路条件已变化，请查看当前星系情报。", true)
		return
	_map_locate_target(str(route[0].endpoint_id))

func _resize_map_canvas() -> void:
	if page != "map" or not is_instance_valid(resource_chart): return
	var canvas: Control = resource_chart.get("diagram")
	if not is_instance_valid(canvas): return
	var height: float = clampf(root.size.y * 0.48, 120.0, 460.0)
	if is_instance_valid(page_scroll) and page_scroll.size.y > 100.0:
		# The page's fixed heading is outside its scroll viewport. Fit the whole
		# graph inside that viewport, including at 200% text scaling.
		height = minf(height, maxf(96.0, page_scroll.size.y - 4.0))
	canvas.custom_minimum_size.y = height

func _pause() -> void:
	if gameplay.telemetry.supported():_button(body,"航行战报",show_page.bind("reports")).name="PauseReports"
	if gameplay.fitting_analysis.supported():_button(body,"查看当前配装分析",show_page.bind("fitting_analysis")).name="PauseFittingAnalysis"
	_text("世界时间已暂停。保存成功后才会更新存档；等待中的保存可取消。", 14)
	var flight_card: VBoxContainer = _card("航行控制")
	var resume: Button = _wide_button(_button(flight_card, "继续航行", _back))
	_primary(resume)
	_secondary(_wide_button(_button(flight_card, "设置", show_page.bind("settings"))))
	if gameplay.drone_control.supported(): _secondary(_wide_button(_button(flight_card, "无人机管理", show_page.bind("drones"))))
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
		var distance: float = sector.target_distance(str(entry.id))
		var kind: String = str(entry.get("kind", ""))
		if kind in ["npc","drone"]:
			if not _npc_visible(entry, distance): continue
			var npc: Dtos.NpcStateDto = state.find("npc_state", "npc_instance_id", str(entry.id))
			if npc != null and not npc.alive: continue
		var record: Dictionary = {"id": str(entry.id), "title": _target_title(entry), "kind": kind, "type_title": _target_type(kind), "distance_m": distance, "navigation_only": bool(entry.get("navigation_only", false)), "remote_site": not sector.target_is_local(str(entry.id)), "known": kind != "npc"}
		if entry.get("operation_id") != null: record.type_title = "撤离点" if str(entry.id).ends_with(":exit") else "行动起点"
		record["friendly"] = bool(entry.get("friendly", false))
		if record.friendly: record.type_title = "友军"
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

func _npc_visible(entry: Dictionary, distance: float) -> bool:
	return sector.contact_visible(entry, distance)

func _select_target(id: String) -> void:
	target_id = id
	_refresh_targets()
	_update_npc_target()
	_update_navigation()
	target_selected.emit(target_id)

func _target_type(kind: String) -> String:
	return str({"station": "空间站", "gate": "虫洞门", "npc": "敌舰", "drone":"无人机", "encounter": "敌舰群", "group": "敌舰群", "resource": "矿体", "signal": "信号", "wreck": "残骸", "marker": "航标", "planet": "天体", "exploration": "探索事件", "exploration_exit": "撤离点"}.get(kind, "目标"))

func _selected_details() -> Dictionary:
	if sector == null or not is_instance_valid(sector.flight) or not sector.targets.has(target_id): return {}
	var entry: Dictionary = sector.targets[target_id]
	var node: Variant = entry.get("node")
	if not is_instance_valid(node) or not node is Node3D: return {}
	var details: Dictionary = {"id": target_id, "title": _target_title(entry), "kind": str(entry.kind), "type_title": _target_type(str(entry.kind)), "distance_m": sector.target_distance(target_id), "navigation_only": bool(entry.get("navigation_only", false)), "remote_site": not sector.target_is_local(target_id)}
	details["friendly"]=bool(entry.get("friendly",false))
	if bool(entry.get("friendly", false)): details.type_title = "友军"
	if str(entry.kind) == "drone" and gameplay.drone_control.live.has(target_id):
		var drone: RefCounted = gameplay.drone_control.live[target_id]
		details.type_title = ("友方" if bool(entry.get("friendly", false)) else "敌方") + "无人机 · 结构 %.0f/%.0f" % [drone.health,drone.health_max]
	if str(entry.kind) == "resource":
		details["resource_info"] = ResourceStatus.inspect(state, catalog, target_id)
		details["resource_forecast"] = gameplay.resource_intel.forecast(target_id)
	if entry.get("operation_id") != null: details.type_title = "撤离点" if target_id.ends_with(":exit") else "行动起点"
	elif str(entry.kind) == "encounter":
		details["encounter_info"] = _encounter_summary(entry)
		details["type_title"] = _encounter_summary(entry)
	return details

func _navigation_context() -> Dictionary:
	var host: Node = get_parent()
	if is_instance_valid(host) and host.has_method("navigation_context"):
		var result: Variant = host.call("navigation_context", target_id)
		if result is Dictionary: return result
	return {"active": false, "reason": "选择目标后可查看航行指令。"}

func _display_speed() -> float:
	var context: Dictionary = _navigation_context()
	return float(context.display_speed_mps) if context.has("display_speed_mps") else Vector3(state.ship().vel_x, state.ship().vel_y, state.ship().vel_z).length()

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
	var war: RefCounted = gameplay.civilizations.active_war()
	if war != null:
		var definition: Dictionary = _one("civilization_war_defs", "war_id", war.war_id)
		var phase: String = str({"assembling": "前往战区会合", "fighting": "清除全部敌舰", "occupying": "占领剩余 %.1f 秒" % war.capture_remaining_s}.get(war.status, war.status))
		return "文明战争 · " + _sector_name(str(definition.target_sector_id)) + "\n" + phase + "\n友军 %d / 3 · 战役守军 %d / 4" % [gameplay.civilizations.living_fleet(war, "ally").size(), gameplay.civilizations.living_fleet(war, "defender").size()]
	for mission: Dtos.MissionStateDto in state.rows("mission_state"):
		if mission.status not in ["active", "ready"]: continue
		var definition: Dictionary = _one("mission_defs", "mission_id", mission.mission_def_id)
		var heading: String = _mission_category_title(definition) + " · " + _mission_name(mission.mission_def_id)
		var location: String = _mission_location_text(_mission_guidance(mission))
		if mission.status == "ready": return heading + "\n返回 " + _station_name(str(definition.get("turnin_station_id", ""))) + " 交付\n" + location
		for objective_def: Dictionary in _defs("mission_objective_defs"):
			if objective_def.mission_id != mission.mission_def_id: continue
			var progress: Dtos.MissionObjectiveStateDto = _mission_progress(mission.mission_instance_id, int(objective_def.objective_index))
			if progress != null and progress.progress_units < int(objective_def.required_count) and objective_def.objective_kind != "deliver":
				var instruction: String = _objective_description(objective_def) + " · %d/%d" % [progress.progress_units, int(objective_def.required_count)]
				if root.size.x<950 and gameplay.situational.supported():
					var equipment: Dictionary=gameplay.situational.mission_equipment(_mission_guidance(mission))
					if not str(equipment.missing).is_empty():return instruction+"\n"+str(equipment.missing)
				return (instruction if root.size.x < 950 else heading + "\n" + instruction) + "\n" + location
		return heading + "\n检查实物并返航交付。"
	return "J 任务 · M 星图\n在空间站接取教学、地区合同和主线。"

func _mission_guidance(mission: Dtos.MissionStateDto = null) -> Dictionary:
	if gameplay == null or gameplay.get("missions") == null: return {}
	return gameplay.get("missions").call("guidance", mission.mission_def_id if mission != null else "")

func _mission_location_text(info: Dictionary) -> String:
	if info.is_empty(): return "任务地点暂不可用，打开任务页查看目标。"
	var result: String = "地点 · " + _sector_name(str(info.get("sector_id", ""))) + " / " + str(info.get("target_title", "任务地点"))
	if not bool(info.get("local", false)):
		result += "\n下一航点 · " + str(info.get("waypoint_title", "查看星图航路"))
	elif not str(info.get("required_page", "")).is_empty():
		result += "\n站内操作 · " + ServiceNavigation.label(str(info.required_page), "空间站")
	if not str(info.get("route_reason", "")).is_empty(): result += "\n" + str(info.route_reason)
	if gameplay.situational.supported():
		var equipment: Dictionary=gameplay.situational.mission_equipment(info)
		if not str(equipment.note).is_empty(): result+="\n"+str(equipment.note)
	return result

func _hud_operation() -> RefCounted:
	if gameplay == null: return null
	var operation: RefCounted = gameplay.operations.focused()
	if operation != null and operation.phase != "active" and (gameplay.civilizations.active_war() != null or gameplay.missions.active() != null): return null
	return operation

func _hud_freight() -> RefCounted:
	if gameplay==null or _hud_operation()!=null or gameplay.civilizations.active_war()!=null:return null
	return gameplay.consignments.focused()

func _hud_expedition() -> RefCounted:
	if gameplay==null or not gameplay.expeditions.supported() or gameplay.missions.active()!=null or gameplay.civilizations.active_war()!=null:return null
	return gameplay.expeditions.active()

func _hud_exploration() -> RefCounted:
	if gameplay==null or not gameplay.exploration.supported() or gameplay.missions.active()!=null: return null
	for row: RefCounted in state.rows("exploration_instance_state"):
		if gameplay.exploration._site(row) and row.phase in ["surveyed","rescue","relic","mineral","extracting"]: return row
	var selected: RefCounted=gameplay.exploration.instance(exploration_selected)
	return selected if selected!=null and selected.phase=="ready" else null

func _hud_task_navigation(travel_to: bool) -> void:
	var scenario: Dictionary=gameplay.scenarios.pending()
	if not scenario.is_empty():requested.emit("scenario_navigate" if travel_to else "scenario_map",scenario.kind+":"+scenario.id,1,gameplay.scenarios.token(scenario.kind,scenario.id));return
	var frontier_id: String=gameplay.frontier.focused_id()
	if not frontier_id.is_empty():requested.emit("frontier_navigate" if travel_to else "frontier_map",frontier_id,1,gameplay.frontier.expected_token(frontier_id));return
	var operation: RefCounted = _hud_operation()
	if operation != null: requested.emit("operation_nav" if travel_to else "operation_map",operation.operation_id,1,str(operation.generation))
	elif _hud_freight()!=null:
		var freight: RefCounted=_hud_freight();requested.emit("consignment_navigate" if travel_to else "consignment_map",freight.contract_id,1,str(freight.generation))
	elif _hud_expedition()!=null:
		var run: RefCounted=_hud_expedition();requested.emit("campaign_navigate" if travel_to else "campaign_map","expedition:"+str(run.run_id),1,gameplay.expeditions.token(run.run_id))
	elif _hud_exploration()!=null:
		var event: RefCounted=_hud_exploration();requested.emit("exploration_nav" if travel_to else "exploration_map",event.event_id,1,str(event.generation))
	else: requested.emit("mission_travel" if travel_to else "mission_locate","",1,"")

func _hud_task_details() -> void:
	var scenario: Dictionary=gameplay.scenarios.pending()
	if not scenario.is_empty():set(scenario.kind+"_selected_id",scenario.id);show_page("trials" if scenario.kind=="trial" else "blockades");return
	if not gameplay.frontier.focused_id().is_empty():frontier_selected_id=gameplay.frontier.focused_id();show_page("frontier");return
	if _hud_operation() != null: show_page("operations"); return
	if _hud_freight()!=null:show_page("consignments");return
	if _hud_expedition()!=null:show_page("expeditions");return
	if _hud_exploration()!=null:open_exploration(_hud_exploration().event_id);return
	mission_filter = "story"; mission_status_filter = "all"; mission_location_filter = "all"; mission_focus_id = ""; mission_page = 0; show_page("missions")

func _update_mission_guidance() -> void:
	if not is_instance_valid(mission_navigation_row) or gameplay == null: return
	var scenario: Dictionary=gameplay.scenarios.pending()
	if not scenario.is_empty():
		war_navigation_row.hide();mission_navigation_row.show();mission_locate_button.show();mission_travel_button.show();mission_guide_button.show()
		mission_guide_button.text="挑战详情" if scenario.kind=="trial" else "封锁详情"
		mission_locate_button.disabled=operation_blocks_flight;mission_travel_button.disabled=operation_blocks_flight or state.ship().status!=Types.ShipStatus.FLYING
		mission_travel_button.text="返回交付" if scenario.row.phase=="ready" else "前往目标"
		mission_locate_button.tooltip_text="定位本次行动的入口、出口或签发站。";mission_travel_button.tooltip_text="按本次行动的实际航路导航。"
		mission_locate_button.set_meta("action","scenario_map");mission_locate_button.set_meta("target",scenario.kind+":"+scenario.id)
		mission_travel_button.set_meta("action","scenario_navigate");mission_travel_button.set_meta("target",scenario.kind+":"+scenario.id)
		return
	var frontier_id: String=gameplay.frontier.focused_id()
	if not frontier_id.is_empty():
		war_navigation_row.hide();mission_navigation_row.show();mission_locate_button.show();mission_travel_button.show();mission_guide_button.show()
		mission_guide_button.text="战役详情";mission_locate_button.disabled=operation_blocks_flight;mission_travel_button.disabled=operation_blocks_flight or state.ship().status!=Types.ShipStatus.FLYING
		mission_locate_button.set_meta("action","frontier_map");mission_locate_button.set_meta("target",frontier_id);mission_travel_button.set_meta("action","frontier_navigate");mission_travel_button.set_meta("target",frontier_id)
		return
	var operation: RefCounted = _hud_operation()
	mission_guide_button.text = "行动详情" if operation != null else "主线指引"
	if operation != null:
		war_navigation_row.hide(); mission_navigation_row.show()
		mission_locate_button.show(); mission_travel_button.show(); mission_guide_button.show()
		var location: Dictionary = gameplay.operations.guidance(operation.operation_id)
		mission_locate_button.disabled = operation_blocks_flight
		mission_travel_button.disabled = operation_blocks_flight or state.ship().status != Types.ShipStatus.FLYING or not str(location.get("route_reason", "")).is_empty()
		mission_travel_button.text = "前往目标"
		mission_travel_button.tooltip_text = "前往当前行动起点、撤离点或交付站；按真实航程选择跃迁或接近。"
		mission_locate_button.tooltip_text = "在星图定位当前行动地点。"
		mission_locate_button.set_meta("action","operation_map"); mission_locate_button.set_meta("target",operation.operation_id)
		mission_travel_button.set_meta("action","operation_nav"); mission_travel_button.set_meta("target",operation.operation_id)
		return
	var freight: RefCounted=_hud_freight()
	if freight!=null:
		war_navigation_row.hide();mission_navigation_row.show();mission_locate_button.show();mission_travel_button.show();mission_guide_button.show()
		mission_guide_button.text="承运详情"
		var location: Dictionary=gameplay.consignments.guidance(freight.contract_id)
		mission_locate_button.disabled=operation_blocks_flight
		mission_travel_button.disabled=operation_blocks_flight or state.ship().status!=Types.ShipStatus.FLYING or not str(location.get("route_reason","")).is_empty()
		mission_travel_button.text="前往目标";mission_locate_button.tooltip_text="在星图定位承运站点。";mission_travel_button.tooltip_text="按当前载重航路前往交付站；跨门后继续导航。"
		mission_locate_button.set_meta("action","consignment_map");mission_locate_button.set_meta("target",freight.contract_id)
		mission_travel_button.set_meta("action","consignment_navigate");mission_travel_button.set_meta("target",freight.contract_id)
		return
	var expedition: RefCounted=_hud_expedition()
	if expedition!=null:
		var info: Dictionary=gameplay.expeditions.guidance()
		war_navigation_row.hide();mission_navigation_row.show();mission_locate_button.show();mission_travel_button.show();mission_guide_button.show()
		mission_guide_button.text="远征详情";mission_travel_button.text="前往目标"
		mission_locate_button.disabled=operation_blocks_flight
		mission_travel_button.disabled=operation_blocks_flight or state.ship().status!=Types.ShipStatus.FLYING or not str(info.get("route_reason","")).is_empty()
		mission_locate_button.set_meta("action","campaign_map");mission_locate_button.set_meta("target","expedition:"+str(expedition.run_id))
		mission_travel_button.set_meta("action","campaign_navigate");mission_travel_button.set_meta("target","expedition:"+str(expedition.run_id))
		mission_travel_button.tooltip_text=_mission_location_text(info)
		return
	var event: RefCounted=_hud_exploration()
	if event!=null and gameplay.civilizations.active_war()==null:
		var info: Dictionary=gameplay.exploration.guidance(event.event_id)
		war_navigation_row.hide();mission_navigation_row.show();mission_locate_button.show();mission_travel_button.show();mission_guide_button.show()
		mission_guide_button.text="探索详情";mission_travel_button.text="前往目标"
		mission_locate_button.disabled=operation_blocks_flight
		mission_travel_button.disabled=operation_blocks_flight or state.ship().status!=Types.ShipStatus.FLYING or not str(info.get("route_reason","")).is_empty()
		mission_locate_button.set_meta("action","exploration_map");mission_locate_button.set_meta("target",event.event_id)
		mission_travel_button.set_meta("action","exploration_nav");mission_travel_button.set_meta("target",event.event_id)
		mission_travel_button.tooltip_text=_mission_location_text(info)
		return
	var war: RefCounted = gameplay.civilizations.active_war()
	war_navigation_row.visible = war != null
	if war != null:
		mission_navigation_row.hide()
		return
	var current: Dtos.MissionStateDto = gameplay.get("missions").call("active")
	var has_mission: bool = current != null
	mission_navigation_row.visible = root.size.x >= 950 or work_mode.is_empty()
	mission_locate_button.visible = has_mission
	mission_travel_button.visible = has_mission
	mission_guide_button.visible = not has_mission
	if not has_mission: return
	var info: Dictionary = _mission_guidance(current)
	var flight: bool = state.ship().status == Types.ShipStatus.FLYING
	var target: String = str(info.get("waypoint_id", ""))
	var route_ok: bool = not target.is_empty() and str(info.get("route_reason", "")).is_empty()
	mission_locate_button.disabled = info.is_empty() or operation_blocks_flight
	mission_travel_button.disabled = not flight or not route_ok or operation_blocks_flight
	mission_travel_button.text = "前往目标" if bool(info.get("local", false)) else "前往虫洞"
	var note: String = _mission_location_text(info)
	mission_locate_button.tooltip_text = "选择并指示任务地点；不会自动移动舰船。\n" + note
	mission_travel_button.tooltip_text = "明确下达前往指令：可跃迁时跃迁，否则自动接近。跨星系只到下一虫洞门，减速后按 F 穿越。\n" + note
	mission_locate_button.set_meta("action", "mission_locate")
	mission_travel_button.set_meta("action", "mission_travel")
	mission_locate_button.set_meta("target", current.mission_def_id)
	mission_travel_button.set_meta("target", current.mission_def_id)

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
	if gameplay == null or gameplay.get("missions") == null: return ""
	var info: Dictionary = gameplay.get("missions").call("objective_guidance", definition)
	return str(info.get("waypoint_id", ""))

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
	var list: XJBusinessList = BusinessList.new()
	body.add_child(list)
	list.call("configure", title, price_heading, quantity_heading, page in ["market", "industry"])
	if page in ["market", "industry"]: business_list_view = list
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
	row["name_label"] = entry.name
	row["description_label"] = entry.description
	row["description_base"] = entry.description.text
	return row

func _business_view_identity() -> String:
	if state == null or state.player() == null or state.ship() == null: return ""
	return "%d:%s:%s:%d:%s:%s" % [state.get_instance_id(), state.world_id, state.session_id, state.epoch, state.player().docked_station_id, state.ship().ship_instance_id]

func _retain_business_quantities() -> void:
	if business_quantity_identity != _business_view_identity():
		business_quantities.clear()
		business_quantity_identity = _business_view_identity()
	for row: Dictionary in quotes:
		if not _business_context_valid(row) or not is_instance_valid(row.get("amount")): continue
		var quantity: int = _business_row_quantity(row)
		if quantity > 0: business_quantities[str(row.action) + ":" + str(row.target)] = quantity

func _set_market_filter(filter: String) -> void:
	_retain_business_quantities()
	market_filter = filter
	business_preserve_view = true
	show_page("market")

func _register_business_row(entry: Dictionary, title: String, action: String, target: String, fields: Dictionary) -> Dictionary:
	if business_quantity_identity != _business_view_identity():
		business_quantities.clear()
		business_quantity_identity = _business_view_identity()
	var row: Dictionary = _quote_row(entry, fields)
	row.merge({"action": action, "target": target, "extra": "", "amount": null}, true)
	if not row.has("fixed"):
		row.amount = business_list_view.enable_row_quantity(entry, int(catalog.rule("business_quantity_limit")), int(business_quantities.get(action + ":" + target, 1)))
	var button: Button = _button(entry.actions, title, _business_submit.bind(row))
	row.button = button
	for key: String in ["action", "target", "extra"]: button.set_meta(key, row[key])
	button.set_meta("uses_quantity", not row.has("fixed"))
	button.set_meta("row_id", entry.id)
	row["context"] = {"state": state, "catalog": catalog, "gameplay": gameplay, "world_id": state.world_id, "session_id": state.session_id, "epoch": state.epoch, "station_id": state.player().docked_station_id, "ship_id": state.ship().ship_instance_id, "page": page, "generation": business_generation, "row": entry.row, "action": action, "target": target, "kind": str(row.kind), "id": str(row.id), "signature": _business_asset_signature(action, target)}
	quotes.append(row)
	if is_instance_valid(row.amount):
		row.amount.value_changed.connect(func(_value: float):
			if _business_context_valid(row):
				business_quantities[action + ":" + target] = int(row.amount.value)
				_update_quote(row, int(row.amount.value)))
		row.amount.get_line_edit().text_changed.connect(func(_text: String):
			if _business_context_valid(row): _update_quote(row))
		# SpinBox may restore its previous value on blur without emitting a value
		# change. Re-quote after its internal text normalization has completed.
		row.amount.get_line_edit().focus_exited.connect(func():
			_update_quote.call_deferred(row))
	return row

func _business_asset_signature(action: String, target: String) -> String:
	if action not in ["sell_item", "recycle"]: return action + ":" + target
	var item: Dtos.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", target)
	if item != null:
		return "%s:%s:%s:%s:%d:%s" % [target, item.item_def_id, item.container_id, item.policy_id, item.origin_kind, item.salvage_recipe_id]
	var stack: Dtos.InventoryStackStateDto = state.find("inventory_stack_state", "stack_id", target)
	return "%s:%s:%s:%s" % [target, stack.item_def_id, stack.container_id, stack.policy_id] if stack != null else ""

func _business_context_valid(row: Dictionary) -> bool:
	var token: Dictionary = row.get("context", {})
	if token.is_empty() or state == null or state != token.state or catalog != token.catalog or gameplay != token.gameplay: return false
	if not is_inside_tree() or page != token.page or business_generation != token.generation: return false
	if state.world_id != token.world_id or state.session_id != token.session_id or state.epoch != token.epoch: return false
	if state.player() == null or state.ship() == null or not state.player().has_docked_station_id: return false
	if state.player().docked_station_id != token.station_id or state.ship().ship_instance_id != token.ship_id: return false
	if state.ship().status != Types.ShipStatus.DOCKED: return false
	if row.action != token.action or row.target != token.target or row.kind != token.kind or row.id != token.id: return false
	if not is_instance_valid(row.get("row")) or row.row != token.row or row.row.is_queued_for_deletion() or not row.row.is_inside_tree(): return false
	if not quotes.has(row) or not is_instance_valid(row.get("button")) or row.button.is_queued_for_deletion(): return false
	return _business_asset_signature(str(row.action), str(row.target)) == str(token.signature)

func _business_row_quantity(row: Dictionary) -> int:
	if row.has("fixed"): return int(row.fixed)
	if not is_instance_valid(row.get("amount")): return 0
	var text: String = row.amount.get_line_edit().text.strip_edges()
	if not text.is_valid_int(): return 0
	var quantity: int = int(text)
	return quantity if quantity >= 1 and quantity <= int(row.amount.max_value) else 0

func _business_submit(row: Dictionary) -> void:
	# An old row must never commit text or emit against a new page/session.
	if not _business_context_valid(row): return
	if _business_row_quantity(row) <= 0:
		_update_quote(row)
		return
	if is_instance_valid(row.get("amount")): row.amount.apply()
	_update_quote(row)
	if not _business_context_valid(row) or row.button.disabled: return
	var quantity: int = _business_row_quantity(row)
	_retain_business_quantities()
	requested.emit(str(row.action), str(row.target), quantity, str(row.extra))

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
		var weapon: Dictionary = _one("weapon_defs", "module_id", id)
		if not weapon.is_empty():
			description += _weapon_description(id, module, weapon)
		else:
			if float(module.range_m) > 0: description += " · 作用距离 " + XJSpaceUnits.distance(float(module.range_m))
			if float(module.cycle_s) > 0: description += " · 周期 %.2f s" % float(module.cycle_s)
		var tech: Dictionary = _one("module_tech_defs", "module_id", id)
		if not tech.is_empty(): description += "\n科技 %s · %s（%s）" % [str(tech.tech_level), _unlock_name(str(tech.required_unlock_id)), "已解锁" if _unlocked(str(tech.required_unlock_id)) else "未解锁"]
	var tuning: String=gameplay.specializations.description(id) if gameplay!=null else ""
	if not tuning.is_empty():description+="\n"+tuning
	return description

func _weapon_family_name(family: String) -> String:
	return str({"kinetic": "动能炮", "thermal": "热束", "pulse": "脉冲弹", "drone": "攻击无人机"}.get(family, "武器"))

func _weapon_size_name(size: int) -> String:
	return str({1: "轻型", 2: "中型", 3: "重型"}.get(size, "未定义口径"))

func _weapon_description(id: String, module: Dictionary, weapon: Dictionary) -> String:
	var profile: Dictionary = _one("weapon_behavior_defs", "module_id", id) if catalog.table_names.has("weapon_behavior_defs") else {}
	var is_drone: bool = str(profile.get("fire_mode", "")) == "drone"
	var result: String = ""
	if not profile.is_empty(): result += "\n%s · %s" % [_weapon_family_name(str(profile.family_id)), _weapon_size_name(int(profile.size_class))]
	var damage: float = float(weapon.raw_damage)
	var cycle: float = float(module.cycle_s)
	result += "\n%s %.2f · 周期 %.2f s · %s %.2f" % ["单次集群总伤害" if is_drone else "单发原始伤害", damage, cycle, "理论 DPS 上界" if is_drone else "理论 DPS", damage / cycle if cycle > 0 else 0.0]
	result += "\n%s %s" % ["控制范围" if is_drone else "射程", XJSpaceUnits.distance(float(module.range_m))]
	if is_drone:
		var drone: Dictionary = _one("drone_defs", "module_id", id) if catalog.table_names.has("drone_defs") else {}
		if not drone.is_empty():
			result += " · 无人机 %d 架\n巡航 %s · 攻击距离 %s · 弹速 %s" % [int(drone.drone_count), XJSpaceUnits.speed(float(drone.speed_mps)), XJSpaceUnits.distance(float(drone.attack_range_m)), XJSpaceUnits.speed(float(drone.projectile_speed_mps))]
		result += "\n每次付费出击，每架攻击一次后回收；回收与冷却结束后再出击。"
	elif weapon.projectile_speed_mps == null:
		result += " · 瞬时射线"
	else:
		result += " · 弹速 " + XJSpaceUnits.speed(float(weapon.projectile_speed_mps))
	result += "\n每周期能量 %.2f EU · 热量 %.2f HU" % [float(module.energy_eu), float(module.heat_hu)]
	result += " · 弹药 %s ×%d" % [_item_name(str(weapon.ammo_item_id)), int(weapon.ammo_per_cycle)] if weapon.ammo_item_id != null else " · 无弹药消耗"
	result += "\n理论值不计命中、供能、散热" + ("与无人机往返耗时。" if is_drone else "。")
	return result

func _ship_weapon_description(id: String) -> String:
	if not catalog.table_names.has("ship_weapon_permissions"): return "配装资格按此存档的原有槽位与预算校验。"
	var allowed: Array[String] = []
	var drone_allowed: bool = false
	for permission: Dictionary in _defs("ship_weapon_permissions"):
		if str(permission.ship_id) != id: continue
		var family: String = str(permission.family_id)
		allowed.append("%s≤%s，最多 %d 件" % [_weapon_family_name(family), _weapon_size_name(int(permission.max_size)), int(permission.max_installed)])
		drone_allowed = drone_allowed or family == "drone"
	return "武器挂载：" + "；".join(allowed) + ("。" if drone_allowed else "；不支持攻击无人机机库。")

func _ship_description(id: String) -> String:
	var definition: Dictionary = _one("ship_defs", "ship_id", id)
	if definition.is_empty(): return "舰体定义未提供"
	var role: Dictionary = _one("ship_role_defs", "ship_id", id)
	var faction: String = str(_one("faction_defs", "faction_id", str(role.get("faction_id", ""))).get("display_name", ""))
	return (faction + " · " if not faction.is_empty() else "") + "舰体基准：速度 %s · 货舱 %d L · 矿舱 %d L\n护盾 %.0f · 装甲 %.0f · 结构 %.0f\n%s" % [XJSpaceUnits.speed(float(definition.max_speed_mps)), int(definition.cargo_l), int(definition.mineral_cargo_l), float(definition.shield_max), float(definition.armor_max), float(definition.hull_max), _ship_weapon_description(id)]

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
	if state.ship().policy_id != "normal_owned": return "借用或保障舰仅使用随船设备；自有设备需安装在自有舰上"
	var tech: Dictionary = _one("module_tech_defs", "module_id", item.item_def_id)
	if not tech.is_empty() and not _unlocked(str(tech.required_unlock_id)): return "需解锁 " + _unlock_name(str(tech.required_unlock_id))
	var module: Dictionary = _one("module_full_defs", "module_id", item.item_def_id)
	if module.is_empty(): return "缺少模块定义"
	if str(module.slot_type) == "weapon" and gameplay.has_method("weapon_fit_reason"):
		var weapon_reason: String = str(gameplay.call("weapon_fit_reason", state.ship(), item.item_def_id))
		if not weapon_reason.is_empty(): return weapon_reason
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
	for ledger: RefCounted in state.rows("manufacture_input_state"):
		if ledger.item_instance_id == item.item_instance_id: return ""
	if item.origin_kind == Types.ItemOrigin.MANUFACTURE: return "缺少合法材料追溯账本"
	if item.salvage_recipe_id.is_empty(): return "设备没有冻结拆解来源"
	for ingredient: Dictionary in _defs("recipe_inputs"):
		if str(ingredient.recipe_id) == item.salvage_recipe_id: return ""
	return "缺少合法材料追溯账本"

func _recycle_source_description(item: Dtos.ItemInstanceStateDto) -> String:
	for ledger: RefCounted in state.rows("manufacture_input_state"):
		if ledger.item_instance_id == item.item_instance_id:
			return "按此设备保存的" + ("实际制造投入" if item.origin_kind == Types.ItemOrigin.MANUFACTURE else "历史标准投入") + "返料，逐项向下取整；拆解后设备消失。"
	return "缺少实际制造投入，不能拆解。" if item.origin_kind == Types.ItemOrigin.MANUFACTURE else "按当前世界冻结的标准配方返料，逐项向下取整；拆解后设备消失。"

func _mission_list_description(definition: Dictionary, current: Dtos.MissionStateDto) -> String:
	var description: String = "接取 " + _station_name(str(definition.accept_station_id)) + " · 交付 " + _station_name(str(definition.turnin_station_id))
	for prerequisite: Dictionary in _defs("mission_prerequisites"):
		if str(prerequisite.mission_id)==str(definition.mission_id): description+="\n前置 · "+_mission_name(str(prerequisite.prerequisite_mission_id))+("（已完成）" if _mission_completed(str(prerequisite.prerequisite_mission_id)) else "（未完成）")
	if not _unlocked(str(definition.get("required_unlock_id",""))): description+="\n许可 · "+_unlock_name(str(definition.get("required_unlock_id","")))+"（未解锁）"
	if current==null or current.status not in ["active","ready"]:
		for objective_def: Dictionary in _defs("mission_objective_defs"):
			if str(objective_def.mission_id)==str(definition.mission_id): description+="\n"+_objective_description(objective_def)
		return description
	var info: Dictionary=_mission_guidance(current)
	if current.status=="ready":
		description+="\n当前步骤 · 返航交付"
		for obj: Dictionary in gameplay.missions.objectives(current.mission_def_id):
			if obj.objective_kind=="deliver": description+="\n"+_item_name(str(obj.target_item_id))+" × %d" % int(obj.required_count)
	else:
		for obj: Dictionary in gameplay.missions.objectives(current.mission_def_id):
			if int(obj.objective_index)!=int(info.get("objective_index",-1)): continue
			description+="\n当前步骤 %d · %s · %d/%d" % [int(obj.objective_index)+1,_objective_description(obj),int(info.get("progress_units",0)),int(obj.required_count)]
			break
	return description+"\n"+_mission_location_text(info)

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
		definition_cache[table] = catalog.rows(table) if catalog != null and (catalog.table_names.has(table) or catalog.view_sql.has(table)) else []
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
	var civilization_actions: Dictionary = {"join_civilization": "效忠身份已更新", "donate_civilization": "材料已捐献，文明声望已增加", "start_war": "远征委托已受领，友军已在战区集结", "fleet_command": "舰队指令已下达"}
	for action: String in civilization_actions:
		if message == "操作完成：" + action: return civilization_actions[action]
	if message.begins_with("操作完成："):
		if message == "操作完成：manufacture" and gameplay != null and gameplay.industry.supported(): return "制造订单已提交，完工后请到原站领取"
		if message == "操作完成：claim_industry": return "制造成品已领取"
		if message == "操作完成：cancel_industry": return "订单已取消，返还物资已入本站仓库"
		if message == "操作完成：deliver_demand": return "区域需求交付完成"
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
	var title: String = _friendly(str(target.get("title", "未知目标"))).replace("Lv.", "等级 ")
	if str(target.get("kind", "")) == "encounter":
		title += " · %d/%d" % [int(target.get("remaining_count", 0)), int(target.get("total_count", 0))]
		if int(target.get("remaining_count", 0)) == 0:
			var remaining: float = float(target.get("respawn_remaining_s", 0.0))
			title += " · %.0f 秒后复生" % remaining if remaining > 0.0 else " · 已肃清"
	return title

func _encounter_summary(entry: Dictionary) -> String:
	var title: String = "任务战斗地点" if bool(entry.get("mission_target", false)) else "星系敌舰群"
	title += " · 等级 %d · %d/%d 艘" % [int(entry.get("level", 0)), int(entry.get("remaining_count", 0)), int(entry.get("total_count", 0))]
	if int(entry.get("remaining_count", 0)) == 0:
		var remaining: float = float(entry.get("respawn_remaining_s", 0.0))
		title += " · %.0f 秒后复生" % remaining if remaining > 0.0 else " · 已肃清"
	return title

func _pointer_over(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(control.get_global_mouse_position())

func _update_navigation() -> void:
	if state == null or not is_instance_valid(sector) or catalog == null or gameplay == null: return
	var navigation_context: Dictionary = _navigation_context()
	if toolbar_buttons.has("drones"): toolbar_buttons.drones.visible = gameplay.drone_control.supported()
	var automatic: bool = bool(navigation_context.get("active", false))
	navigation_status.text = (UISkin.navigation_phase(str(navigation_context.get("phase", ""))) + " · " + _friendly(str(navigation_context.get("title", "")))) if automatic else "手动航行 · 已知位置可跃迁"
	if automatic and float(navigation_context.get("remaining_s", 0.0)) > 0.0: navigation_status.text += " · %.1f s" % float(navigation_context.remaining_s)
	navigation_status.tooltip_text = navigation_status.text
	navigation_stop_button.visible = automatic
	navigation_stop_button.disabled = operation_blocks_flight
	if is_instance_valid(overview): overview.call("set_selection", _selected_details(), navigation_context, operation_blocks_flight)
	if is_instance_valid(overview):
		var support_options: Array[Dictionary] = []
		if gameplay.civilizations.friendly(target_id):support_options=gameplay.ship_roles.options(target_id)
		overview.set_support_options(support_options,operation_blocks_flight)
	navigation_hud.selected_id = target_id
	navigation_hud.refresh()
	navigation_hud.caption_obstacles.clear()
	for control: Control in [flight_header, target_panel, hud_left.get_parent(), navigation_frame, instrument, equipment_bar, navigation, navigation_hud.radar_frame, operation_bar]:
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
	var label: String = {"dock": "停靠空间站", "travel": "进入虫洞", "pickup_wreck": "回收残骸", "start_scan": "扫描信号", "start_mining": "开采矿体", "recover_resource": "回收组件", "operation_open": "查看战术行动", "exploration_open": "查看探索事件"}.get(str(interaction_candidate.action), "交互")
	interaction_button.text = "[F] " + label
	interaction_button.disabled = not bool(interaction_candidate.ready)
	interaction_button.tooltip_text = str(interaction_candidate.title) + " · " + str(interaction_candidate.reason)
	interaction_label.text = str(interaction_candidate.title) + "\n" + ("接口就绪 · " + XJSpaceUnits.distance(float(interaction_candidate.distance_m)) if interaction_candidate.ready else _friendly(str(interaction_candidate.reason)))
	interaction_label.tooltip_text = interaction_label.text
	interaction_label.add_theme_color_override("font_color", UISkin.ICE if interaction_candidate.ready else UISkin.AMBER)

func _update_hud_visibility() -> void:
	var show_hud: bool = state != null and state.ship() != null and state.ship().status == Types.ShipStatus.FLYING and not panel.visible and not station_layer.visible and not menu_open
	if is_instance_valid(hud_left): hud_left.get_parent().visible = show_hud and not radar_expanded
	if is_instance_valid(navigation_frame): navigation_frame.visible = show_hud
	if is_instance_valid(instrument): instrument.visible = show_hud
	if is_instance_valid(flight_dock): flight_dock.visible = show_hud
	if is_instance_valid(equipment_bar): equipment_bar.visible = show_hud
	if is_instance_valid(navigation): navigation.visible = show_hud
	if is_instance_valid(flight_header): flight_header.visible = show_hud
	if is_instance_valid(target_panel): target_panel.visible = show_hud
	if is_instance_valid(controls): controls.hide()
	if is_instance_valid(navigation_hud): navigation_hud.visible = show_hud
	if is_instance_valid(navigation_hud): navigation_hud.radar_frame.visible = show_hud and radar_expanded
	if is_instance_valid(title_background): title_background.visible = page == "title"
	if is_instance_valid(title_shade): title_shade.visible = page == "title"
	if is_instance_valid(station_layer): station_layer.visible = page == "station" and state != null
	_responsive_title()

func _service_sidebar_compact() -> bool:
	if root.size.x < 950 or root.size.y < 560: return true
	if not is_instance_valid(sidebar): return false
	var top: float = 22.0
	if is_instance_valid(operation_bar) and operation_bar.visible:
		top = maxf(top, operation_bar.position.y + operation_bar.size.y + 8.0)
	# Wide high-DPI windows can be logically short. Keep the complete page
	# inside the viewport and use its existing selector when navigation cannot fit.
	return root.size.y - top - 52.0 < sidebar.get_combined_minimum_size().y

func _responsive() -> void:
	if not is_instance_valid(root): return
	_resize_map_canvas()
	var compact: bool = root.size.x < 950
	# Hide tall navigation before resizing; its previous minimum otherwise
	# clamps the panel and leaves stale offsets after a page/scale change.
	if is_instance_valid(sidebar): sidebar.visible = state != null and page not in ["title", "settings"] and not _service_sidebar_compact()
	var safe: float = 8.0 if compact else 16.0
	var rail_width: float = 40.0 if compact else 48.0
	var left_edge: float = safe + rail_width + 12.0
	var sidebar_width: float = 210.0 if compact else 290.0
	var left_width: float = 174.0 if compact else 252.0
	var header_height: float = 26.0 if compact else 34.0
	var dock_height: float = 108.0 if compact else 132.0
	flight_content_top = safe + header_height + 12.0
	flight_content_bottom = root.size.y - safe - dock_height - 12.0
	if is_instance_valid(flight_header):
		flight_header.offset_left = safe
		flight_header.offset_right = -safe
		flight_header.offset_top = safe
		flight_header.offset_bottom = safe + header_height
		flight_header.add_theme_stylebox_override("panel", UISkin.hud_panel(4))
		top.add_theme_font_size_override("font_size", 10 if compact else 13)
		top.autowrap_mode = TextServer.AUTOWRAP_OFF
		top.clip_text = true
	if is_instance_valid(flight_dock):
		# A bounded central dock leaves the screen edges and the ship unobstructed.
		var dock_width: float = minf(940.0, root.size.x - left_edge - safe)
		flight_dock.offset_left = maxf(left_edge, (root.size.x - dock_width) * 0.5)
		flight_dock.offset_right = flight_dock.offset_left + dock_width - root.size.x
		flight_dock.offset_top = -safe - dock_height
		flight_dock.offset_bottom = -safe
		flight_dock.add_theme_constant_override("separation", 8)
	if is_instance_valid(navigation):
		navigation.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		navigation.offset_left = safe
		navigation.offset_right = safe + rail_width
		navigation.offset_top = flight_content_top
		navigation.offset_bottom = flight_content_top + toolbar_buttons.size()*(36.0 if compact else 42.0)+maxi(0,toolbar_buttons.size()-1)*(4.0 if compact else 8.0)+8.0
		navigation.add_theme_stylebox_override("panel", UISkin.flat(Color(0.025,0.035,0.05,0.4),Color(0.15,0.21,0.27,0.35),2))
		var toolbar_row: VBoxContainer = navigation.get_node("ToolbarActions")
		toolbar_row.add_theme_constant_override("separation", 4 if compact else 8)
		for button: Variant in toolbar_buttons.values():
			button.add_theme_font_size_override("font_size", 9 if compact else 10)
			button.custom_minimum_size = Vector2(0,36 if compact else 42)
			button.add_theme_stylebox_override("normal", UISkin.flat(Color(0,0,0,0),Color(0,0,0,0),1))
		if is_instance_valid(radar_button): radar_button.modulate = UISkin.AMBER if radar_expanded else Color.WHITE
	if is_instance_valid(navigation_frame):
		navigation_frame.offset_left = left_edge
		navigation_frame.offset_right = left_edge + left_width
		navigation_frame.offset_top = flight_content_top
		navigation_frame.offset_bottom = flight_content_top + (50 if compact else 76)
		navigation_frame.add_theme_stylebox_override("panel", UISkin.hud_panel(5 if compact else 10))
		navigation_status.max_lines_visible = 1 if compact else 2
		navigation_status.add_theme_font_size_override("font_size", 10 if compact else 12)
		navigation_stop_button.custom_minimum_size.y = 20
	if is_instance_valid(hud_left):
		var frame: PanelContainer = hud_left.get_parent()
		frame.offset_left = left_edge
		frame.offset_top = navigation_frame.offset_bottom + 14.0
		frame.offset_bottom = frame.offset_top + ((70 if work_box.visible else 68) if compact else 166)
		frame.offset_right = left_edge + left_width
		frame.add_theme_stylebox_override("panel", UISkin.hud_panel(5 if compact else 10))
		hud_left.add_theme_constant_override("separation", 3 if compact else 8)
		objective.add_theme_font_size_override("font_size", 10 if compact else 13)
		objective.max_lines_visible = 2 if compact else 5
		for action_button: Button in [mission_locate_button,mission_travel_button,mission_guide_button]:
			action_button.custom_minimum_size = Vector2(72,22 if compact else 26)
			action_button.add_theme_font_size_override("font_size",10 if compact else 11)
		var heading: Control = hud_left.find_child("MissionHeading",false,false)
		if heading != null: heading.visible = not compact or not work_box.visible
		work_progress.show_percentage = not compact
		work_label.add_theme_font_size_override("font_size",10 if compact else 12)
		work_label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
		work_label.clip_text = compact
		work_label.max_lines_visible = 1 if compact else 3
	if is_instance_valid(instrument):
		instrument.custom_minimum_size.x = 200.0 if compact else 268.0
		instrument.add_theme_stylebox_override("panel",UISkin.hud_panel(4 if compact else 6))
		instrument_title.visible = not compact
		instrument_title.add_theme_font_size_override("font_size",10)
		instrument_title.clip_text = true
		instrument_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		dial.visible = true
		dial.custom_minimum_size = Vector2(62,66) if compact else Vector2(88,88)
		dial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		compact_speed_label.hide()
		var instrument_row: HBoxContainer = instrument.find_child("InstrumentReadouts",true,false)
		instrument_row.add_theme_constant_override("separation",4 if compact else 8)
		for entry: Dictionary in condition_bars:
			entry.label.add_theme_font_size_override("font_size",10)
			entry.label.autowrap_mode = TextServer.AUTOWRAP_OFF
			entry.label.clip_text = true
			entry.bar.visible = not compact
			entry.bar.custom_minimum_size.y = 3
		energy_bar.visible = not compact
		heat_bar.visible = not compact
		energy_bar.custom_minimum_size.y = 3
		heat_bar.custom_minimum_size.y = 3
		for readout_label: Label in [energy_label,heat_label,cargo_label]:
			readout_label.add_theme_font_size_override("font_size",10)
			readout_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			readout_label.clip_text = true
		cargo_label.visible = not compact
		for name_value: String in ["DefenseReadout","ResourceReadout"]:
			var readout: VBoxContainer = instrument.find_child(name_value,true,false)
			readout.custom_minimum_size.x = 54 if compact else 68
			readout.add_theme_constant_override("separation",2)
	if is_instance_valid(equipment_bar): equipment_bar.call("responsive",compact)
	if is_instance_valid(navigation_hud):
		navigation_hud.responsive(root.size)
		navigation_hud.radar_frame.add_theme_stylebox_override("panel",UISkin.hud_panel(5))
		navigation_hud.radar_frame.offset_left = left_edge
		navigation_hud.radar_frame.offset_right = left_edge + (150 if compact else 220)
		navigation_hud.range_label.add_theme_font_size_override("font_size",10 if compact else 12)
	if is_instance_valid(controls):
		# Detailed controls live on the ship button's tooltip, freeing the top strip.
		controls.hide()
	if is_instance_valid(target_panel):
		var overview_height: float = minf(430.0,flight_content_bottom-flight_content_top)
		target_panel.offset_left = -safe-sidebar_width
		target_panel.offset_right = -safe
		target_panel.offset_top = flight_content_top
		target_panel.offset_bottom = flight_content_top+overview_height
		if is_instance_valid(overview): overview.call("responsive",compact,overview_height)
	# Limit notification width to the free center lane. Different feedback owns
	# a second small line; only an exact duplicate of the active operation hides.
	var center_left: float = left_edge + left_width + 10.0
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
	if is_instance_valid(flight_cues):
		flight_cues.offset_left=notice_left
		flight_cues.offset_right=notice_left+notice_width
		flight_cues.offset_top=toast.offset_bottom+6.0 if toast.visible else notification_top+(operation_height+6.0 if operation_bar.visible else 0.0)
		flight_cues.offset_bottom=flight_cues.offset_top+maxf(28.0,flight_cues.get_combined_minimum_size().y)
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
		if selector != null: selector.visible = _service_sidebar_compact()
		var heading: Label = panel.find_child("PageHeading", true, false)
		if heading != null and page != "title": heading.add_theme_font_size_override("font_size", 19 if compact else 25)
		if is_instance_valid(sidebar):
			for service_button: Button in sidebar.find_children("Service*", "Button", true, false):
				if service_button.has_meta("service_page_id"):
					_service_button_style(service_button, str(service_button.get_meta("service_page_id")) == _service_context_page())
	if is_instance_valid(panel):
		for grid: Node in panel.find_children("ModuleCards*", "GridContainer", true, false):
			grid.columns = 2 if root.size.x >= 1200 and page != "title" else 1
	if is_instance_valid(station_services):
		station_services.add_theme_stylebox_override("panel", UISkin.hud_panel(6 if compact else 8))
		station_services.offset_left = safe
		station_services.offset_right = safe + (198 if compact else 220)
		station_services.offset_top = 44 if compact else 64
		station_services.offset_bottom = (-94 if compact else -110) - (40 if station_layer.visible and toast.visible else 0)
		for service_button: Button in station_services.find_children("*", "Button", true, false):
			_service_button_style(service_button, service_button.has_meta("service_page_id") and str(service_button.get_meta("service_page_id")) == "station")
	if is_instance_valid(station_details):
		station_details.visible = not compact and root.size.y >= 560
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
	var base_height: float = (70.0 if work_box.visible else 68.0) if compact else 166.0
	# Work and objective text can grow after telemetry changes. Reserve their
	# real container minimum before placing the radar, without rebuilding nodes.
	var frame_bottom: float = frame.offset_top + maxf(base_height, frame.get_combined_minimum_size().y)
	if absf(frame.offset_bottom - frame_bottom) > 0.5: frame.offset_bottom = frame_bottom
	if radar_expanded: frame_bottom = navigation_frame.offset_bottom + 8.0
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
	if gameplay!=null and gameplay.situational.supported(): return heading+"\n"+gameplay.situational.resource_text(node_id)
	var visit: Dtos.SectorStateDto = state.find("sector_state", "sector_id", sector_id)
	if sector_id != state.current_sector() and (visit == null or not visit.visited):
		return heading + "\n尚未到访 · 实时矿量未知"
	var info: Dictionary = ResourceStatus.inspect(state, catalog, node_id)
	var summary: String = ResourceStatus.summary(info)
	if bool(info.get("available", false)) and int(info.get("capacity_units", 0)) > 0:
		summary += " · %.0f%%" % (float(info.remaining_units) / float(info.capacity_units) * 100.0)
	return heading + "\n" + summary

func _update_map_resources(total_mass_kg: float = -1.0) -> void:
	if page != "map": return
	# Reuse the existing telemetry cadence and nodes; preserve scroll/focus.
	for readout: Dictionary in map_resource_readouts:
		if not is_instance_valid(readout.label): continue
		var text: String = _resource_map_readout(str(readout.node_id), str(readout.sector_id))
		if readout.label.text != text:
			readout.label.text = text
			readout.label.tooltip_text = text + "\n现场更新；远程只显示上次观测，过期需复测。暂停与退出不推进。"
	if gameplay.situational.supported():
		for entry: Dictionary in map_demand_readouts:
			if is_instance_valid(entry.label): entry.label.text=gameplay.situational.demand_text(entry.id)
		if is_instance_valid(map_war_readout):
			map_war_readout.text=_map_war_note(str(map_war_readout.get_meta("sector_id","")))
			map_war_readout.visible=not map_war_readout.text.is_empty()
	if is_instance_valid(resource_chart): resource_chart.call("refresh_resource_status", total_mass_kg)

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
	var tactic_status: String = gameplay.tactics.status(target_id)
	if not tactic_status.is_empty(): npc_title.text += "\n" + tactic_status
	for index: int in range(3):
		var key: String = ["shield", "armor", "hull"][index]
		var maximum: float = float(definition.get(key + "_max", 0))
		var current: float = float(npc.get(key))
		npc_bars[index].label.tooltip_text = "%s %.0f/%.0f" % [npc_bars[index].name, current, maximum]
		npc_bars[index].label.text = "%s %.0f%%" % [npc_bars[index].name, current / maxf(maximum, 1.0) * 100.0]
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
	return str(_mission_guidance(mission).get("waypoint_id", ""))

func _mission_reason(definition: Dictionary, current: Dtos.MissionStateDto) -> String:
	if gameplay != null and gameplay.missions.has_pending_loans(): return "借船待返航归还；请先停靠空间站清理上次借约"
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
	for row: Dictionary in quotes:
		_update_quote(row)

func _update_quote(row: Dictionary, quantity_override: int = -1) -> void:
	if not _business_context_valid(row): return
	var quantity: int = quantity_override if quantity_override >= 0 else _business_row_quantity(row)
	var economy: RefCounted = gameplay.get("economy")
	var price: int = 0
	var unit_price: int = 0
	var selling: bool = bool(row.get("selling", false))
	if row.kind == "ship":
		price = int(economy.call("quote_ship", str(row.id), selling))
		unit_price = price
	elif row.kind == "recipe":
		price = int(economy.call("quote_manufacture", str(row.id), maxi(1, quantity)))
		unit_price = int(economy.call("quote_manufacture", str(row.id), 1))
	elif row.kind == "recycle":
		price = int(catalog.rule("recycle_service_fee_credit"))
		unit_price = price
	else:
		price = int(economy.call("quote", str(row.id), maxi(1, quantity), selling))
		unit_price = int(economy.call("quote", str(row.id), 1, selling))
	var reason: String = _service_reason(str(row.get("service", "")))
	var prefix: String = str(row.get("status_prefix", ""))
	var inventory: RefCounted = gameplay.get("inventory")
	match str(row.action):
		"buy_item":
			var stock: Dtos.ShopStockStateDto = _business_stock(str(row.id))
			var definition: Dictionary = _stock_definition(str(row.id))
			row.maximum = stock.quantity if stock != null else 0
			prefix = "站点库存 %d" % int(row.maximum)
			if stock == null or definition.is_empty() or not bool(definition.get("allow_buy", false)): reason = "本站不出售此物品"
			elif not _unlocked(str(definition.get("required_unlock_id", ""))): reason = "需解锁 " + _unlock_name(str(definition.get("required_unlock_id", "")))
			elif quantity > stock.quantity: reason = "数量超过现有库存"
			elif not _warehouse_id().is_empty() and (not bool(inventory.call("accessible", _warehouse_id())) or int(inventory.call("room", _warehouse_id(), str(row.id), quantity)) < quantity): reason = "目标仓库无空间"
		"buy_ship":
			var stock: Dtos.ShopShipStockStateDto
			for candidate: Dtos.ShopShipStockStateDto in state.rows("shop_ship_stock_state"):
				if candidate.station_id == state.player().docked_station_id and candidate.ship_def_id == row.id: stock = candidate
			row.maximum = stock.quantity if stock != null else 0
			prefix = "站点库存 %d" % int(row.maximum)
			var role: Dictionary = _one("ship_role_defs", "ship_id", str(row.id))
			if not _unlocked(str(role.get("required_unlock_id", ""))): reason = "需解锁 " + _unlock_name(str(role.get("required_unlock_id", "")))
			elif stock == null or stock.quantity < 1: reason = "暂无舰体库存"
		"sell_item":
			var stack: Dtos.InventoryStackStateDto = state.find("inventory_stack_state", "stack_id", str(row.target))
			var item: Dtos.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", str(row.target))
			var policy: String = item.policy_id if item != null else stack.policy_id if stack != null else ""
			var container_id: String = item.container_id if item != null else stack.container_id if stack != null else ""
			row.maximum = stack.quantity if stack != null else 1 if item != null else 0
			prefix = "持有 %d · %s" % [int(row.maximum), _policy_name(policy)]
			var definition: Dictionary = _stock_definition(str(row.id))
			var stock: Dtos.ShopStockStateDto = _business_stock(str(row.id))
			var budget: Dtos.StationEconomyStateDto = state.find("station_economy_state", "station_id", state.player().docked_station_id)
			if item == null and stack == null: reason = "出售目标已不存在"
			elif not bool(_one("asset_policy_defs", "policy_id", policy).get("may_sell", false)): reason = "保护 / 绑定资产不可出售"
			elif not bool(inventory.call("accessible", container_id)): reason = "异地货物不可出售"
			elif item != null and state.find("equipment_state", "item_instance_id", item.item_instance_id) != null: reason = "先卸下设备再出售"
			elif quantity > int(row.maximum): reason = "数量超过现有库存"
			elif stock == null or definition.is_empty() or not bool(definition.get("allow_sell", false)): reason = "本站不收购此物品"
			elif quantity > stock.buyback_remaining_units or stock.quantity + quantity > int(definition.get("hard_cap_units", 0)): reason = "本站本轮回购数量额度不足"
			elif budget == null or budget.buyback_remaining_credit < price: reason = "本站本轮回购预算不足"
		"manufacture":
			if not _unlocked(str(row.get("unlock", ""))): reason = "需解锁 " + _unlock_name(str(row.get("unlock", "")))
			if reason.is_empty(): reason = _materials_reason(str(row.inputs_table), str(row.inputs_key), str(row.id), maxi(1, quantity))
			if reason.is_empty() and gameplay.industry.supported(): reason = gameplay.industry.start_reason(str(row.id), maxi(1, quantity))
			var materials: String = _business_inputs_text(str(row.inputs_table), str(row.inputs_key), str(row.id), maxi(1, quantity))
			var output: String = "%s × %d %s" % [_item_name(str(row.output_id)), int(row.output_quantity) * maxi(1, quantity), _item_unit(str(row.output_id))]
			if row.inputs_table == "hull_recipe_inputs": output = "%s × %d 艘裸舰；不含设备与弹药" % [_ship_name(str(row.output_id)), maxi(1, quantity)]
			var detail: String = str(row.description_base) + "\n本次材料：" + materials + "\n本次产出：" + output
			if gameplay.industry.supported(): detail += "\n加工用时：%.0f 秒；完工后在本站领取，出航期间继续生产。" % ceil(gameplay.industry.duration(str(row.id), maxi(1, quantity)))
			row.description_label.text = detail
			row.name_label.tooltip_text = row.name_label.text + "\n" + detail
			row.row.tooltip_text = row.name_label.tooltip_text
		"recycle":
			var item: Dtos.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", str(row.target))
			reason = "设备已不存在" if item == null else "先将设备卸到本站仓库" if item.container_id != _warehouse_id() else _recycle_reason(item)
			prefix = "固定拆解一件"
	var civilization_ship: String = str(row.id) if row.action == "buy_ship" else str(row.get("output_id", "")) if row.action == "manufacture" and str(row.get("inputs_table", "")) == "hull_recipe_inputs" else ""
	if not civilization_ship.is_empty():
		var civilization_reason: String = gameplay.civilizations.hull_reason(civilization_ship)
		if not civilization_reason.is_empty(): reason = civilization_reason
	if not selling and state.player().credit < price: reason = "信用点不足"
	if quantity <= 0: reason = "请输入 1–%d 的整数" % int(catalog.rule("business_quantity_limit"))
	row.label.text = str(price) if quantity > 0 else "—"
	row.label.set_meta("quote_amount", price if quantity > 0 else 0)
	row.label.tooltip_text = ("实收" if selling else "生产服务费" if row.kind == "recipe" else "拆解服务费" if row.kind == "recycle" else "含税总价") + " %d 信用点；本行数量 %d。" % [price, quantity]
	row.unit_label.text = str(unit_price)
	row.unit_label.set_meta("quote_amount", unit_price)
	row.unit_label.tooltip_text = "每批服务费" if row.kind == "recipe" else "每件拆解服务费" if row.kind == "recycle" else "每单位实收" if selling else "每单位含税价格"
	row.quantity_label.text = str(quantity) if quantity > 0 else "—"
	var status: String = reason if not reason.is_empty() else "可生产" if row.kind == "recipe" else "可拆解" if row.kind == "recycle" else "可成交"
	row.status_label.text = prefix + (" · " if not prefix.is_empty() else "") + status
	row.status_label.tooltip_text = row.status_label.text
	row.button.disabled = not reason.is_empty()
	row.button.tooltip_text = status

func _business_stock(id: String) -> Dtos.ShopStockStateDto:
	for stock: Dtos.ShopStockStateDto in state.rows("shop_stock_state"):
		if stock.station_id == state.player().docked_station_id and stock.item_def_id == id: return stock
	return null

func _business_inputs_text(table: String, key: String, id: String, batches: int) -> String:
	var parts: PackedStringArray = []
	for ingredient: Dictionary in _defs(table):
		if str(ingredient.get(key, "")) == id: parts.append("%s × %d" % [_item_name(str(ingredient.item_id)), int(ingredient.quantity) * batches])
	return "、".join(parts)

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
	compact_speed_label = _text_to(resources, XJSpaceUnits.speed(0.0) + " · 跟随", 10)
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
	var row: VBoxContainer = VBoxContainer.new()
	row.name = "ToolbarActions"
	row.add_theme_constant_override("separation", 6)
	navigation.add_child(row)
	for key: String in ["show_ship", "missions", "map", "drones", "hire", "pause"]:
		var title: String = {"show_ship": "舰船", "missions": "任务", "map": "星图", "drones":"无人机", "hire":"僚舰", "pause": "系统"}[key]
		var callback: Callable = func(): requested.emit("show_ship", "", 1, "")
		if key != "show_ship": callback = show_page.bind(key)
		var button: Button = _button(row, title, callback)
		toolbar_buttons[key] = button
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(42, 42)
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", 12)
		button.icon = ServiceNavigation.texture(ServiceNavigation.OBSERVE_ICON) if key == "show_ship" else ServiceNavigation.icon("ships" if key in ["drones","hire"] else key)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", 18)
		button.tooltip_text = {"missions":"任务与合同 · J", "map":"星域航路 · M", "drones":"无人机管理", "hire":"雇佣僚舰与四种编队指令", "pause":"暂停与存读档 · Esc"}.get(key, "显示舰船")
		if key == "show_ship":
			show_ship_button = button
			button.name = "ShowPlayerShip"
			button.tooltip_text = "恢复跟随视角、默认观察角度和镜头距离，舰船居中显示。V 切换视角；左键拖动观察，松开后保留角度。"
		_secondary(button)
		button.add_theme_stylebox_override("normal", UISkin.flat(Color(0.08, 0.105, 0.125, 0.65), Color("384650"), 4))
		button.add_theme_stylebox_override("hover", UISkin.flat(Color("253b45"), UISkin.ICE, 4))
		button.add_theme_stylebox_override("pressed", UISkin.flat(Color("192b34"), UISkin.ICE, 4))
	radar_button = _button(row, "雷达", func():
		radar_expanded = not radar_expanded
		_update_hud_visibility()
		_responsive())
	radar_button.name = "FlightRadarToggle"
	radar_button.icon = ServiceNavigation.icon("research")
	radar_button.expand_icon = true
	radar_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radar_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	radar_button.add_theme_constant_override("icon_max_width", 18)
	radar_button.focus_mode = Control.FOCUS_NONE
	radar_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radar_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	radar_button.add_theme_stylebox_override("hover", UISkin.hud_button(true))
	radar_button.add_theme_stylebox_override("pressed", UISkin.hud_button(true))
	radar_button.tooltip_text = "展开 / 收起局部雷达；雷达中的目标可直接选择。"
	toolbar_buttons["radar"] = radar_button

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
	overview.connect("support_requested",func(item_id: String,selected_id: String,stop: bool):
		requested.emit("stop_remote_support" if stop else "remote_support",item_id,1,"" if stop else selected_id))
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
	equipment_bar.connect("combat_option_requested", func(option: String, enabled: bool): requested.emit("set_combat_option", option, 1, "on" if enabled else "off"))

func set_combat_automation_status(options: Dictionary, message: String = "", blocked: bool = false) -> void:
	if is_instance_valid(equipment_bar): equipment_bar.call("set_combat_automation_status", options, message, blocked)

func combat_option_has_focus() -> bool:
	return is_instance_valid(equipment_bar) and bool(equipment_bar.call("has_combat_option_focus"))

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
		var tuned: Dictionary = gameplay.specializations.weapon_spec(equipment,ship)
		if not tuned.is_empty(): module = tuned
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
	equipment_bar.call("refresh", records, {"energy": ship.energy, "energy_max": metrics.energy_max, "heat_ratio": ship.heat / maxf(float(metrics.heat_max), 1.0), "engine_ready": engine_ready, "engine_reason": engine_reason, "empty_slots": empty_slots}, operation_blocks_flight)

func _update_instrument(ship: Dtos.ShipStateDto, metrics: Dictionary) -> void:
	update_camera_status()
	var values: Array[float] = [ship.shield, ship.armor, ship.hull]
	var maximums: Array[float] = [float(metrics.shield_max), float(metrics.armor_max), float(metrics.hull_max)]
	var signature: String = JSON.stringify([root.size.x < 950, ship.ship_def_id, ship.shield, ship.armor, ship.hull, ship.energy, ship.heat, ship.overheated, _display_speed(), metrics.shield_max, metrics.armor_max, metrics.hull_max, metrics.energy_max, metrics.heat_max, metrics.cargo_used_l, metrics.cargo_capacity_l, metrics.mineral_used_l, metrics.mineral_capacity_l])
	if signature == telemetry_signature: return
	telemetry_signature = signature
	for index: int in range(3):
		condition_bars[index].label.tooltip_text = "%s  %.0f / %.0f" % [condition_bars[index].name, values[index], maximums[index]]
		condition_bars[index].label.text = "%s %.0f%%" % [condition_bars[index].name, values[index] / maxf(maximums[index], 1.0) * 100.0]
		condition_bars[index].bar.max_value = maxf(maximums[index], 1.0)
		condition_bars[index].bar.value = values[index]
	dial.speed = _display_speed()
	dial.ratios = Vector3(values[0] / maxf(maximums[0], 1.0), values[1] / maxf(maximums[1], 1.0), values[2] / maxf(maximums[2], 1.0))
	dial.queue_redraw()
	energy_label.tooltip_text = "电容  %.0f / %.0f" % [ship.energy, float(metrics.energy_max)]
	energy_label.text = "电容 %.0f%%" % (ship.energy / maxf(float(metrics.energy_max), 1.0) * 100)
	energy_bar.max_value = maxf(float(metrics.energy_max), 1.0)
	energy_bar.value = ship.energy
	var heat_ratio: float = ship.heat / maxf(float(metrics.heat_max), 1.0)
	var heat_warning: bool = heat_ratio >= float(catalog.rule("overheat_warning_ratio"))
	heat_label.text = ("过热锁定 " if ship.overheated else "热量预警 " if heat_warning else "热量 ") + "%.0f%%" % (heat_ratio * 100)
	heat_label.add_theme_color_override("font_color", UISkin.AMBER if ship.overheated or heat_warning else UISkin.TEXT)
	heat_bar.max_value = maxf(float(metrics.heat_max), 1.0)
	heat_bar.value = ship.heat
	cargo_label.tooltip_text = "货 %.0f/%.0f L · 矿 %.0f/%.0f L" % [float(metrics.cargo_used_l), float(metrics.cargo_capacity_l), float(metrics.mineral_used_l), float(metrics.mineral_capacity_l)]
	var entrusted: Dictionary=gameplay.consignments.cargo(ship.ship_instance_id)
	if float(entrusted.volume)>0.0:cargo_label.tooltip_text+="\n承运货物 %.0f L / %.0f kg" % [entrusted.volume,entrusted.mass]
	cargo_label.text = "载荷 %.0f%%" % (100.0 * float(metrics.cargo_used_l) / maxf(float(metrics.cargo_capacity_l),1.0))
	compact_speed_label.tooltip_text = instrument_title.text + "\n" + instrument_title.tooltip_text + "\n" + cargo_label.tooltip_text
	instrument.tooltip_text = compact_speed_label.tooltip_text

func update_camera_status() -> void:
	if state == null or camera == null or not is_instance_valid(instrument_title): return
	var ship: Dtos.ShipStateDto = state.ship()
	var view: String = ["跟随视角", "舰首视角（舰体隐藏）", "战术视角"][int(camera.mode)]
	instrument_title.text = _ship_name(ship.ship_def_id) + "  /  " + view + " · V" + (" · 过热警报" if ship.overheated else "")
	var earned_title: String=gameplay.scenarios.title() if gameplay!=null else ""
	if not earned_title.is_empty():instrument_title.text+=" · "+earned_title
	instrument_title.modulate = UISkin.AMBER if ship.overheated else Color.WHITE
	instrument_title.tooltip_text = "V 循环切换跟随、舰首、战术视角。舰首视角从船头观察，不显示外部舰体；点击上方‘显示舰船’回到跟随视角。"
	compact_speed_label.text = "%s · %s" % [XJSpaceUnits.speed(_display_speed()), ["跟随", "舰首隐藏", "战术"][int(camera.mode)]]
	compact_speed_label.tooltip_text = instrument_title.text + "\n" + instrument_title.tooltip_text + "\n" + cargo_label.tooltip_text
	instrument.tooltip_text = compact_speed_label.tooltip_text

func _update_station_info() -> void:
	if state == null or not is_instance_valid(station_ship_status): return
	var metrics: Dictionary = gameplay.call("metrics", state.ship())
	station_ship_name.text = _ship_name(state.ship().ship_def_id)
	station_ship_status.text = "护盾  %.0f / %.0f\n装甲  %.0f / %.0f\n结构  %.0f / %.0f\n\n电容  %.0f / %.0f\n热量  %.0f%%\n\n货舱  %.0f / %.0f L\n矿舱  %.0f / %.0f L" % [state.ship().shield, float(metrics.shield_max), state.ship().armor, float(metrics.armor_max), state.ship().hull, float(metrics.hull_max), state.ship().energy, float(metrics.energy_max), state.ship().heat / maxf(float(metrics.heat_max), 1.0) * 100, float(metrics.cargo_used_l), float(metrics.cargo_capacity_l), float(metrics.mineral_used_l), float(metrics.mineral_capacity_l)]

func _service_button(parent: Node, destination: String, surface: String) -> Button:
	var button: Button = _button(parent, ServiceNavigation.label(destination), show_page.bind(destination))
	button.name = "Service" + destination.to_pascal_case()
	button.icon = ServiceNavigation.icon(destination)
	button.tooltip_text = ServiceNavigation.label(destination)
	button.set_meta("service_page_id", destination)
	button.set_meta("service_surface", surface)
	_service_button_style(button, destination == _service_context_page())
	return button

func _service_button_style(button: Button, active: bool) -> void:
	var small: bool = root.size.x < 950 or root.size.y < 560
	button.custom_minimum_size = Vector2(0, 28 if small else 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 20 if small else 22)
	button.add_theme_constant_override("h_separation", 7)
	button.add_theme_font_size_override("font_size", 11 if small else 13)
	button.add_theme_color_override("font_color", UISkin.AMBER if active else UISkin.TEXT)
	button.add_theme_color_override("icon_normal_color", UISkin.AMBER if active else Color.WHITE)
	for color_key: String in ["font_hover_color", "font_pressed_color", "font_focus_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(color_key, UISkin.AMBER if active else Color.WHITE)
	button.add_theme_stylebox_override("normal", UISkin.hud_button(active))
	var hover: StyleBoxFlat = UISkin.hud_button(active)
	if not active:
		hover.bg_color = Color(0.06, 0.075, 0.085, 0.6)
		hover.border_color = Color(0.31, 0.36, 0.39, 0.7)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", UISkin.hud_button())
	# The amber fill identifies the current page; keyboard focus is a thin outline.
	var keyboard_focus: StyleBoxFlat = UISkin.flat(Color.TRANSPARENT, Color("56717d"), 0)
	keyboard_focus.draw_center = false
	button.add_theme_stylebox_override("focus", keyboard_focus)

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
	if page == "missions" and not mission_focus_id.is_empty():
		for entry: Control in entries:
			if entry is Button and not entry.disabled and str(entry.get_meta("target", "")) == mission_focus_id and str(entry.get_meta("action", "")) in ["mission_locate", "mission_station"]:
				_focus_mission_action(entry)
				return
	var default: Array[Control] = _focus_controls(body)
	if page == "civilizations":
		var selected_civilization: Button = body.find_child("CivilizationSelect_" + civilization_selected_faction, true, false)
		if selected_civilization != null:
			selected_civilization.grab_focus()
			return
	if page == "map" and is_instance_valid(resource_chart):
		var canvas: Control = resource_chart.get("diagram")
		if is_instance_valid(canvas):
			canvas.grab_focus()
			return
	for entry: Control in default:
		if entry is Button and not entry.disabled:
			entry.grab_focus()
			return
	if not default.is_empty():
		default[0].grab_focus()
		return
	# A page whose business actions are all disabled still focuses its own
	# navigation row, rather than the first unrelated row in the sidebar.
	for entry: Control in entries:
		if str(entry.get_meta("service_surface", "")) == "sidebar" and str(entry.get_meta("service_page_id", "")) == page:
			entry.grab_focus()
			return
	if not entries.is_empty(): entries[0].grab_focus()
