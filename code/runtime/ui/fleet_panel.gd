extends VBoxContainer
## Compact asset/crew management under the existing fleet service.
const T=preload("res://contracts/contract_types.gd")
const Services=preload("res://runtime/ui/service_navigation.gd")
var u: Node
var section: String
var _signature: String=""
var _elapsed: float=0.0
var readouts: Array[Dictionary]=[]
var actions: Array[Dictionary]=[]
var _state: RefCounted
var _generation: int

func setup(ui: Node,kind: String) -> void:
	u=ui;section=kind;name="CrewPanel" if kind=="crew" else "OwnedFleetPanel";add_theme_constant_override("separation",10)
	_state=u.state;_generation=u.business_generation
	if section=="crew":_crew()
	else:_fleet()
	_signature=_current_signature();_update()

func _flow(parent: Node) -> HFlowContainer:
	var flow:=HFlowContainer.new();flow.add_theme_constant_override("h_separation",8);flow.add_theme_constant_override("v_separation",6);parent.add_child(flow);return flow

func _card(title: String,icon: String) -> VBoxContainer:
	var panel:=PanelContainer.new();add_child(panel)
	var margin:=MarginContainer.new();panel.add_child(margin)
	for edge: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,10)
	var content:=VBoxContainer.new();content.add_theme_constant_override("separation",6);margin.add_child(content)
	var heading:=HBoxContainer.new();content.add_child(heading)
	var image:=TextureRect.new();image.texture=Services.icon(icon);image.custom_minimum_size=Vector2(24,24);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;heading.add_child(image)
	u._text_to(heading,title,16).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return content

func _crew() -> void:
	var service: RefCounted=u.gameplay.crew
	u._text_to(self,"工资按实际出航时间结算 · 每 %.0f 分钟一次" % (float(service.balance.salary_period_s)/60.0),14)
	var selector:=OptionButton.new();selector.name="CrewTargetShip";selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(selector)
	var hulls: Array=[]
	for ship: RefCounted in u.state.rows("ship_state"):
		if ship.policy_id!="normal_owned" or ship.status in [T.ShipStatus.DESTROYED,T.ShipStatus.RETURNED]:continue
		hulls.append(ship.ship_instance_id);selector.add_item(str(u.gameplay.definition("ship_defs","ship_id",ship.ship_def_id).display_name)+(" · 主舰" if ship==u.state.ship() else " · "+ship.ship_instance_id.right(6)))
		selector.set_item_metadata(selector.item_count-1,ship.ship_instance_id)
	if not hulls.has(u.crew_target_ship):u.crew_target_ship=u.state.ship().ship_instance_id
	selector.select(maxi(0,hulls.find(u.crew_target_ship)))
	var ui_ref: WeakRef=weakref(u);var original: RefCounted=u.state;var generation: int=u.business_generation
	selector.item_selected.connect(func(index: int):
		var ui: Node=ui_ref.get_ref() as Node
		if not is_instance_valid(ui) or ui.state!=original or ui.business_generation!=generation or ui.page!="ships" or ui.fleet_section!="crew" or index>=hulls.size():return
		ui.crew_target_ship=hulls[index];ui.call_deferred("refresh_page"))
	for member: RefCounted in u.state.rows("crew_member_state"):
		var profile: Dictionary=service.profile(member.profile_id);var job: Dictionary=service.profession(member.profile_id)
		var card: VBoxContainer=_card(str(profile.display_name)+" · "+str(job.display_name),{"pilot":"ships","gunner":"fitting","engineer":"industry","scout":"map"}.get(job.duty_kind,"ships"))
		var label: Label=u._text_to(card,"",14);label.name="CrewReadout_"+member.profile_id;readouts.append({"id":member.profile_id,"label":label})
		var flow: HFlowContainer=_flow(card)
		if member.phase=="available":_action(flow,"招募 · %d" % int(job.hire_fee_credit),member.profile_id,"hire")
		else:
			_action(flow,"指派到所选舰",member.profile_id,"assign",u.crew_target_ship)
			_action(flow,"取消指派",member.profile_id,"unassign")
			if member.arrears_credit>0:_action(flow,"补薪 · %d" % member.arrears_credit,member.profile_id,"arrears")
			if member.phase=="injured":_action(flow,"治疗 · %d" % int(service.balance.injury_treatment_credit),member.profile_id,"treat")
			elif member.phase=="hired":
				if member.loyalty<int(service.balance.loyalty_initial):_action(flow,"休整 · %d" % int(service.balance.rest_credit),member.profile_id,"rest")
				_action(flow,"解雇",member.profile_id,"dismiss")

func _fleet() -> void:
	var service: RefCounted=u.gameplay.owned_fleet
	u._text_to(self,"自有僚舰 %d / %d · 雇佣合同单独管理" % [service.active().size(),int(service.balance.max_owned_companions)],16)
	u._text_to(self,"随行 %d 艘 · 总质量 %.1f 吨 · 过门按舰计费" % [u.gameplay.hired.party_fee(1),(float(u.gameplay.metrics(u.state.ship()).total_mass_kg)+u.gameplay.hired.party_mass_kg())/1000.0],14)
	u._text_to(self,"停靠后部署；出航前指派操舰员。跃迁前集结，弹药和电容取自各舰。",13)
	var count: int=0
	for ship: RefCounted in u.state.rows("ship_state"):
		if ship.policy_id!="normal_owned" or ship==u.state.ship() or ship.status==T.ShipStatus.RETURNED:continue
		count+=1
		var card: VBoxContainer=_card(str(u.gameplay.definition("ship_defs","ship_id",ship.ship_def_id).display_name)+" · "+ship.ship_instance_id.right(6),"ships")
		var label: Label=u._text_to(card,"",14);label.name="OwnedReadout_"+ship.ship_instance_id;readouts.append({"id":ship.ship_instance_id,"label":label})
		var flow: HFlowContainer=_flow(card);var deployment: RefCounted=service.row(ship.ship_instance_id)
		if deployment==null or deployment.phase=="docked":_action(flow,"部署 · %d" % service.quote(ship.ship_instance_id),ship.ship_instance_id,"deploy")
		elif deployment.phase=="deployed":
			for pair: Array in [["推进","advance"],["集结","regroup"],["集火","focus"],["撤退","retreat"],["归港收回","recover"]]:_action(flow,pair[0],ship.ship_instance_id,pair[1])
	if count==0:u._text_to(self,"暂无闲置自有舰。购买或建造舰船后，在这里部署。",14)

func _action(parent: Node,title: String,id: String,kind: String,ship_id: String="") -> void:
	var service: RefCounted=u.gameplay.crew if section=="crew" else u.gameplay.owned_fleet
	var extra: String=kind+"|"+service.token(id)
	var focus: String=str(u.target_id) if section=="owned" and kind=="focus" else ""
	var target: RefCounted=u.state.find("npc_state","npc_instance_id",focus) if not focus.is_empty() else null
	var target_generation: int=target.generation if target!=null else 0
	if section=="crew" and kind=="assign":extra+="|"+ship_id
	elif kind=="focus":extra+="|"+focus+"|"+str(target_generation)
	var ui_ref: WeakRef=weakref(u);var original: RefCounted=u.state;var definitions: RefCounted=u.catalog;var epoch: int=original.epoch;var generation: int=u.business_generation;var original_section: String=section
	var callback: Callable=func():
		var ui: Node=ui_ref.get_ref() as Node
		if not is_instance_valid(ui) or ui.state!=original or ui.catalog!=definitions or original.epoch!=epoch or ui.business_generation!=generation or ui.page!="ships" or ui.fleet_section!=original_section:return
		ui.requested.emit("crew_action" if original_section=="crew" else "owned_fleet_action",id,1,extra)
	var button: Button=u._button(parent,title,callback);button.name=("Crew_" if section=="crew" else "Owned_")+kind+"_"+id
	actions.append({"button":button,"id":id,"kind":kind,"ship":ship_id,"focus":focus,"generation":target_generation})

func _current_signature() -> String:
	var values: Array=[u.state.ship().status,u.state.ship().ship_instance_id,u.target_id,u.state.rows("ship_state").size()]
	if section=="crew":
		for row: RefCounted in u.state.rows("crew_member_state"):values.append(u.gameplay.crew.token(row.profile_id))
	else:
		for row: RefCounted in u.state.rows("ship_state"):values.append(u.gameplay.owned_fleet.token(row.ship_instance_id))
	return JSON.stringify(values)

func _update() -> void:
	for value: Dictionary in readouts:
		if section=="crew":
			var service: RefCounted=u.gameplay.crew;var member: RefCounted=service.member(value.id);var assignment: RefCounted=service.assignment(value.id)
			var assigned: RefCounted=u.state.find("ship_state","ship_instance_id",assignment.ship_instance_id) if assignment!=null else null
			var where: String=str(u.gameplay.definition("ship_defs","ship_id",assigned.ship_def_id).display_name) if assigned!=null else "未指派"
			value.label.text="Lv.%d · 经验 %d · 忠诚 %d%% · 工资 %d\n%s · %s%s" % [int(service.rank_for(member).rank),member.experience,member.loyalty,service.salary(member),{"available":"待招募","hired":"可出勤" if service.ready(member) else "暂不可出勤","injured":"受伤 %.0f秒" % member.recovery_remaining_s,"resting":"休整 %.0f秒" % member.recovery_remaining_s}[member.phase],where," · 欠薪 %d" % member.arrears_credit if member.arrears_credit>0 else ""]
			var job: Dictionary=service.profession(value.id);var effect: float=float(service.rank_for(member).effect_value)*member.loyalty/100.0 if service.ready(member) and assigned!=null else 0.0
			value.label.text+=" · "+{"pilot":"转向 +%.1f%%" % (effect*100.0),"gunner":"散热 +%.1f%%" % (effect*100.0),"engineer":"远修 +%.1f%%" % (effect*100.0),"scout":"扫描 +%.1f" % effect}.get(job.duty_kind,"")
		else:
			var service: RefCounted=u.gameplay.owned_fleet;var ship: RefCounted=service.ship(value.id);var deployment: RefCounted=service.row(value.id);var pilot: RefCounted=u.gameplay.crew.pilot(value.id);var metrics: Dictionary=u.gameplay.metrics(ship)
			var phase: String={"deployed":"编队中","retreating":"脱离中","returning":"返航 %.0f秒" % (deployment.return_remaining_s if deployment!=null else 0.0),"docked":"已归港","lost":"已损毁"}.get(deployment.phase,"闲置") if deployment!=null else "闲置"
			if deployment!=null and deployment.phase=="deployed":phase+=" · "+({"advance":"推进","regroup":"集结","focus":"集火"}.get(deployment.order_kind,"") if service.connected(deployment) else "失联")
			var location: String=" · "+XJSpaceUnits.distance(u.gameplay.position(ship).distance_to(u.gameplay.position(u.state.ship()))) if deployment!=null and deployment.phase=="deployed" and deployment.site_id==XJSpaceCoordinates.current_site(u.state) else ""
			value.label.text="%s%s · 操舰员 %s\n盾 %.0f%% · 甲 %.0f%% · 结构 %.0f%% · 电容 %.0f / %.0f" % [phase,location,str(u.gameplay.crew.profile(pilot.profile_id).display_name) if pilot!=null else "未就绪",100.0*ship.shield/maxf(1.0,float(metrics.shield_max)),100.0*ship.armor/maxf(1.0,float(metrics.armor_max)),100.0*ship.hull/maxf(1.0,float(metrics.hull_max)),ship.energy,float(metrics.energy_max)]
	for value: Dictionary in actions:
		var reason: String=u.gameplay.crew.reason(value.id,value.kind,value.ship) if section=="crew" else (u.gameplay.owned_fleet.deploy_reason(value.id) if value.kind=="deploy" else u.gameplay.owned_fleet.order_reason(value.id,value.kind,value.focus,value.generation))
		value.button.disabled=not reason.is_empty();value.button.tooltip_text=reason

func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<0.5 or is_queued_for_deletion() or not is_instance_valid(u) or u.state!=_state or u.business_generation!=_generation or u.page!="ships" or u.fleet_section!=section:return
	_elapsed=0.0
	var signature: String=_current_signature()
	if signature!=_signature:_signature=signature;u.call_deferred("refresh_page");return
	_update()
