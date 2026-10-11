extends VBoxContainer
const T = preload("res://contracts/contract_types.gd")
var u: Node
var selected: String=""
var status: Label
var _token: String=""
var _elapsed: float=0.0

func setup(ui: Node,id: String) -> void:
	u=ui;selected=id
	if selected.is_empty():selected=u.gameplay.frontier.focused_id()
	if selected.is_empty() and u.gameplay.frontier.supported():selected=str(u.catalog.rows("frontier_governance_defs")[0].sector_id)
	u.frontier_selected_id=selected
	if not u.gameplay.frontier.supported():u._text_to(self,"当前世界尚未升级边疆规则。",14);return
	var service: RefCounted=u.gameplay.frontier;var row: RefCounted=service.campaign(selected)
	var title: String=u._sector_name(selected)
	if row!=null:title=u._sector_name(u.catalog.one("civilization_war_defs","war_id",selected).target_sector_id)
	u._text_to(self,"边疆 · "+title,18)
	status=u._text_to(self,service.status_text(selected),16);status.name="FrontierStatus"
	var nav: HFlowContainer=HFlowContainer.new();add_child(nav)
	_button(nav,"定位","frontier_map",selected,null,service.expected_token(selected)).name="FrontierLocate"
	var travel: Button=_button(nav,"前往目标","frontier_navigate",selected,null,service.expected_token(selected));travel.name="FrontierNavigate";travel.disabled=u.state.ship().status!=T.ShipStatus.FLYING
	if row!=null:_campaign(service,row)
	else:_governance(service)
	_token=service.expected_token(selected)
func _campaign(service: RefCounted,row: RefCounted) -> void:
	var actions: HFlowContainer=HFlowContainer.new();add_child(actions)
	for pair: Array in [["survey","开始侦察"],["repair","投入修复"]]:
		var reason: String=service.action_reason(selected,pair[0]);var button: Button=_button(actions,pair[1],"frontier_action",selected,null,pair[0]+":"+service.expected_token(selected))
		button.name="Frontier_"+str(pair[0]);button.disabled=not reason.is_empty();button.tooltip_text=reason
	u._text_to(self,"补给 %d份已托管 · 修复需 %d份结构料" % [row.supplies_paid_units,service.balance.rebuild_units],13)
	u._text_to(self,"维修/侦察离开范围会暂停；撤退损失已交接物资。",13)
	var fleet: HFlowContainer=HFlowContainer.new();add_child(fleet)
	for pair: Array in [["推进","advance"],["集结","regroup"],["撤退","retreat"]]:_button(fleet,pair[0],"fleet_command",pair[1]).name="FrontierFleet_"+str(pair[1])
	_button(fleet,"集火当前目标","fleet_command","focus",null,str(u.target_id)).name="FrontierFleet_focus"
	if row.phase=="rebuilding":
		var source: Button=_button(self,"查看结构料来源","frontier_sources",selected)
		source.tooltip_text="材料来源沿用物资情报入口；舰上带到登陆点后投入修复。"
func _governance(service: RefCounted) -> void:
	var row: RefCounted=service.territory(selected);var spec: Dictionary=u.catalog.one("frontier_governance_defs","sector_id",selected)
	u._text_to(self,"主权 · "+u.gameplay.civilizations.faction_name(u.gameplay.civilizations.owner(selected)),14)
	u._text_to(self,"当前补给 %d / %d · 预警保障需 %d份" % [row.reserve_units,service.balance.reserve_max_units,service.pressure_units(u.gameplay.civilizations.owner(selected))],14)
	u._text_to(self,"当地维修 %.0f%% / 工业 %.0f%% 服务费" % [service.station_factor(spec.station_id,"repair")*100.0,service.station_factor(spec.station_id,"industry")*100.0],13)
	u._text_to(self,"普通敌舰警戒 %.0f%% · 当地补货 %.0f%%" % [service.hostile_detection_ratio(selected)*100.0,service.restock_rate(spec.station_id)*100.0],13)
	var actions: HFlowContainer=HFlowContainer.new();add_child(actions)
	for pair: Array in [["defend","到场防守"],["secure","启用驻防补给"]]:
		var reason: String=service.action_reason(selected,pair[0]);var button: Button=_button(actions,pair[1],"frontier_action",selected,null,pair[0]+":"+service.expected_token(selected))
		button.name="Frontier_"+str(pair[0]);button.disabled=not reason.is_empty();button.tooltip_text=reason
	var quantities: HFlowContainer=HFlowContainer.new();add_child(quantities)
	var amount: SpinBox=SpinBox.new();amount.name="FrontierSupplyQuantity";amount.min_value=1;amount.max_value=service.balance.reserve_max_units;amount.step=1;amount.value=maxi(1,mini(int(service.balance.crisis_supply_base_units),int(service.balance.reserve_max_units)-row.reserve_units));amount.custom_minimum_size=Vector2(88,32);quantities.add_child(amount)
	for pair: Array in [["supply","当地交付"],["dispatch","核心站发运"]]:
		var button: Button=_button(quantities,pair[1],"frontier_action",selected,amount,pair[0]+":"+service.expected_token(selected));button.name="Frontier_"+str(pair[0])
		var reason: String=service.action_reason(selected,pair[0]);button.disabled=not reason.is_empty();button.tooltip_text=reason
	u._text_to(self,"核心站运输 · %d信用点 / %.0f秒 · 普通结构料" % [service.balance.dispatch_fee_credit,service.balance.dispatch_s],13)
	for order: RefCounted in u.state.rows("frontier_supply_order_state"):
		if order.sector_id==selected and order.phase=="inflight":u._text_to(self,"在途 %d份 · %.0f秒" % [order.units,order.remaining_s],13)
func _button(parent: Node,title: String,action: String,target: String,amount: SpinBox=null,extra: String="") -> Button:
	var ui_ref: WeakRef=weakref(u);var amount_ref: WeakRef=weakref(amount) if amount!=null else null
	var state: RefCounted=u.state;var catalog: RefCounted=u.catalog;var epoch: int=state.epoch;var generation: int=u.business_generation;var id: String=selected
	var callback: Callable=func():
		var ui: Node=ui_ref.get_ref() as Node
		if not is_instance_valid(ui) or ui.state!=state or ui.catalog!=catalog or state.epoch!=epoch or ui.business_generation!=generation or ui.page!="frontier" or ui.frontier_selected_id!=id:return
		var quantity: int=1
		if amount_ref!=null:
			var spin: SpinBox=amount_ref.get_ref() as SpinBox
			if not is_instance_valid(spin):return
			var raw: String=spin.get_line_edit().text.strip_edges()
			if not raw.is_valid_int() or int(raw)<1 or int(raw)>int(spin.max_value):ui.notify("请输入合法整数份数。",true);return
			quantity=int(raw)
		ui.requested.emit(action,target,quantity,extra)
	return u._button(parent,title,callback)
func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<0.25 or not is_instance_valid(status) or not is_instance_valid(u):return
	_elapsed=0.0
	if u.page!="frontier" or u.frontier_selected_id!=selected:return
	var service: RefCounted=u.gameplay.frontier
	status.text=service.status_text(selected)
	var current: String=service.expected_token(selected)
	if current!=_token:
		_token=current;u.call_deferred("refresh_page")
