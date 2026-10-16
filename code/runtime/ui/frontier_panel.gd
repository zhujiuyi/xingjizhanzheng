extends VBoxContainer
const T = preload("res://contracts/contract_types.gd")
const Interaction=preload("res://runtime/ui/ui_interaction.gd")
var u: Node
var selected: String=""
var status: Label
var _token: String=""
var _elapsed: float=0.0
var context: Dictionary={}

func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(u) and not u.loading_suspended and not context.is_empty() and Interaction.current(u,context,self) and u.page=="frontier" and u.frontier_selected_id==selected

func _default_target() -> String:
	var service: RefCounted=u.gameplay.frontier
	var civ: RefCounted=u.gameplay.civilizations
	var war: RefCounted=civ.active_war()
	if service.owns_campaign(war):return str(war.war_id)
	var faction: String=civ.allegiance()
	if faction.is_empty():return ""
	var focused: String=service.focused_id()
	if not focused.is_empty() and civ.owner(focused)==faction and service.territory(focused)!=null:return focused
	var owned: Array[String]=[]
	for definition: Dictionary in u.catalog.rows("frontier_governance_defs"):
		var id: String=str(definition.sector_id)
		if civ.owner(id)!=faction or service.territory(id)==null:continue
		if id==u.state.current_sector():return id
		owned.append(id)
	return owned[0] if not owned.is_empty() else ""

func setup(ui: Node,id: String) -> void:
	u=ui;selected=id;context=Interaction.context(u)
	if not u.gameplay.frontier.supported():u._text_to(self,"当前世界尚未升级边疆规则。",14);return
	var service: RefCounted=u.gameplay.frontier
	if not selected.is_empty() and service.campaign(selected)==null and service.territory(selected)==null:selected=""
	if selected.is_empty():selected=_default_target()
	u.frontier_selected_id=selected
	if selected.is_empty():
		u._text_to(self,"边疆战役与治理",u.UISkin.SIZE_SECTION)
		u._text_to(self,"当前没有进行中的边疆战役或属于你的可治理星系。文明页可查看战役委托与主权条件。",14).name="FrontierEmptyState"
		var entry: Button=u._button(self,"查看文明战役与治理",func():
			if _current():u.set_meta("civilization_section","campaign");u.show_page("civilizations"))
		entry.name="FrontierCivilizationsEntry"
		return
	var row: RefCounted=service.campaign(selected)
	var title: String=u._sector_name(selected)
	if row!=null:title=u._sector_name(u.catalog.one("civilization_war_defs","war_id",selected).target_sector_id)
	u._text_to(self,"边疆 · "+title,u.UISkin.SIZE_SECTION)
	status=u._text_to(self,service.status_text(selected),16);status.name="FrontierStatus"
	var nav: HFlowContainer=HFlowContainer.new();add_child(nav)
	_button(nav,"定位","frontier_map",selected,null,service.expected_token(selected)).name="FrontierLocate"
	var travel: Button=_button(nav,"前往目标","frontier_navigate",selected,null,service.expected_token(selected));travel.name="FrontierNavigate";travel.disabled=u.state.ship().status!=T.ShipStatus.FLYING
	Interaction.action_state(travel,"请先出港；可用定位查看目标。" if travel.disabled else "")
	if row!=null:_campaign(service,row)
	else:_governance(service)
	_token=service.expected_token(selected)
func _campaign(service: RefCounted,row: RefCounted) -> void:
	var march_info: Dictionary=u.gameplay.march.view(selected)
	if not march_info.is_empty() and u.gameplay.march.active(u.gameplay.march.state_for(selected)):
		u._text_to(self,"当前位置 · %s · 下一地点可用上方按钮定位" % march_info.sector_name,13)
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
		var quantity_action: String=pair[0]
		var update_quantity: Callable=func():
			if not _current() or not is_instance_valid(button) or not is_instance_valid(amount):return
			var quantity_value: int=Interaction.integer_input(amount)
			var reason: String=service.action_reason(selected,quantity_action)
			if reason.is_empty():reason="请输入范围内的整数份数。" if quantity_value<=0 else service.quantity_reason(selected,quantity_action,quantity_value)
			Interaction.action_state(button,reason)
		Interaction.watch_integer(amount,update_quantity);update_quantity.call()
	u._text_to(self,"核心站运输 · %d信用点 / %.0f秒 · 普通结构料" % [service.balance.dispatch_fee_credit,service.balance.dispatch_s],13)
	for order: RefCounted in u.state.rows("frontier_supply_order_state"):
		if order.sector_id==selected and order.phase=="inflight":u._text_to(self,"在途 %d份 · %.0f秒" % [order.units,order.remaining_s],13)
func _button(parent: Node,title: String,action: String,target: String,amount: SpinBox=null,extra: String="") -> Button:
	var ui_ref: WeakRef=weakref(u);var amount_ref: WeakRef=weakref(amount) if amount!=null else null
	var state: RefCounted=u.state;var catalog: RefCounted=u.catalog;var epoch: int=state.epoch;var generation: int=u.business_generation;var id: String=selected
	var callback: Callable=func():
		if not _current():return
		var ui: Node=ui_ref.get_ref() as Node
		if not is_instance_valid(ui) or ui.state!=state or ui.catalog!=catalog or state.epoch!=epoch or ui.business_generation!=generation or ui.page!="frontier" or ui.frontier_selected_id!=id:return
		var quantity: int=1
		if amount_ref!=null:
			var spin: SpinBox=amount_ref.get_ref() as SpinBox
			if not is_instance_valid(spin):return
			quantity=Interaction.integer_input(spin)
			if quantity<=0:ui.notify("请输入范围内的整数份数。",true);return
			var reason: String=ui.gameplay.frontier.action_reason(id,extra.get_slice(":",0))
			if reason.is_empty():reason=ui.gameplay.frontier.quantity_reason(id,extra.get_slice(":",0),quantity)
			if not reason.is_empty():ui.notify(reason,true);return
			spin.apply()
		ui.requested.emit(action,target,quantity,extra)
	return u._button(parent,title,callback)
func _process(delta: float) -> void:
	if not _current():return
	_elapsed+=delta
	if _elapsed<0.25 or not is_instance_valid(status) or not is_instance_valid(u):return
	_elapsed=0.0
	if u.page!="frontier" or u.frontier_selected_id!=selected:return
	var service: RefCounted=u.gameplay.frontier
	status.text=service.status_text(selected)
	var current: String=service.expected_token(selected)
	if current!=_token:
		_token=current;u.call_deferred("refresh_page")
