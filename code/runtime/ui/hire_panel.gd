extends VBoxContainer
const UISkin=preload("res://runtime/ui_theme.gd")
const Interaction=preload("res://runtime/ui/ui_interaction.gd")
var u: Node
var status: Label
var health: Label
var supplies: Label
var _token: String=""
var _elapsed: float=0.0
var _party_count: int=1
var _context: Dictionary={}
var _profiles: Dictionary={}
func setup(ui: Node) -> void:
	u=ui;name="HirePanel";add_theme_constant_override("separation",UISkin.SECTION_GAP)
	_context=Interaction.context(u)
	var service: RefCounted=u.gameplay.hired
	if not service.supported():u._text_to(self,"当前世界尚未升级雇佣规则。",14);return
	_token=service.token();_party_count=service.party_fee(1);status=u._text_to(self,service.status_text(),18);status.name="HireStatus"
	status.add_theme_color_override("font_color",UISkin.ICE)
	var row: RefCounted=service.active()
	var list: VBoxContainer=u._information_list(self,"雇佣合同","hire_profiles",str(row.profile_id) if row!=null else "")
	for spec: Dictionary in u.gameplay.rows("hire_profile_defs"):
		var entry: Dictionary=u._asset_row(list,str(spec.profile_id),"ship",str(spec.hull_id),str(spec.display_name),"","","","","","")
		var frame: VBoxContainer=entry.details
		_profiles[spec.profile_id]={"summary":entry.status,"name":str(spec.display_name),"button":null,"reason":null}
		if row!=null and row.profile_id==spec.profile_id:
			_active_contract(service,row,frame,entry.actions)
		else:
			u._text_to(frame,"雇佣费 %d · 押金 %d · 租期 %.0f秒" % [spec.hire_fee_credit,spec.deposit_credit,spec.lease_s],UISkin.SIZE_BODY)
			u._text_to(frame,"押金按返航船况结算；主舰损毁会触发紧急回收，押金不退。",13).add_theme_color_override("font_color",UISkin.MUTED)
			var reason: String=service.hire_reason(spec.profile_id);var button: Button=_button(entry.actions,"雇佣","hire_action",spec.profile_id,_token)
			button.name="Hire_"+str(spec.profile_id);button.disabled=not reason.is_empty();button.tooltip_text=reason
			var explanation: Label=u._text_to(frame,reason,13);explanation.visible=not reason.is_empty()
			_profiles[spec.profile_id].button=button;_profiles[spec.profile_id].reason=explanation
		frame.move_child(entry.actions,frame.get_child_count()-1)
	if row==null:
		if not u.state.rows("hire_contract_state").is_empty():
			var previous: RefCounted=u.state.rows("hire_contract_state")[-1]
			u._text_to(self,"上次结算 · %s · 退押 %d" % ["归港" if previous.phase=="returned" else "损失",previous.refund_credit],13)
	_update()
func _active_contract(service: RefCounted,row: RefCounted,frame: VBoxContainer,commands: HFlowContainer) -> void:
	health=u._text_to(frame,"",14);health.name="HireHealth"
	supplies=u._text_to(frame,"",14);supplies.name="HireSupplies"
	health.add_theme_color_override("font_color",UISkin.ICE)
	supplies.add_theme_color_override("font_color",UISkin.ICE)
	u._text_to(frame,"已付雇佣费 %d · 押金 %d · 同行航门按 %d 舰计费" % [row.fee_paid_credit,row.deposit_paid_credit,_party_count],13).add_theme_color_override("font_color",UISkin.MUTED)
	for pair: Array in [["推进","advance"],["集结","regroup"],["集火","focus"],["撤退","retreat"]]:
		var focus_id: String=str(u.target_id) if pair[1]=="focus" else "";var reason: String=service.order_reason(pair[1],focus_id)
		var button: Button=_button(commands,pair[0],"hire_action",pair[1],_token+("|"+focus_id if pair[1]=="focus" else ""));button.name="HireOrder_"+str(pair[1]);button.disabled=not reason.is_empty();button.tooltip_text=reason
	var reason: String=service.order_reason("dismiss");var button: Button=_button(commands,"解约归港","hire_action","dismiss",_token)
	button.name="HireDismiss";button.disabled=not reason.is_empty();button.tooltip_text=reason
	UISkin.apply_button(button,"danger")
	u._text_to(frame,"维修储备有限；撤退需实际脱离后返航，暂停和退出不推进计时。",13).add_theme_color_override("font_color",UISkin.MUTED)
func _button(parent: Node,title: String,action: String,target: String,extra: String) -> Button:
	var ui_ref: WeakRef=weakref(u);var parent_ref: WeakRef=weakref(parent);var token: Dictionary=Interaction.context(u)
	var callback: Callable=func():
		var ui: Node=ui_ref.get_ref() as Node
		var surface: Control=parent_ref.get_ref() as Control
		if not is_instance_valid(surface) or not surface.is_visible_in_tree():return
		if not Interaction.current(ui,token,surface):return
		ui.requested.emit(action,target,1,extra)
	return u._button(parent,title,callback)
func _update() -> void:
	var service: RefCounted=u.gameplay.hired;status.text=service.status_text();var row: RefCounted=service.active()
	for id: String in _profiles:
		var entry: Dictionary=_profiles[id]
		if row!=null and row.profile_id==id:entry.summary.text=service.status_text().trim_prefix(str(entry.name)+" · ")
		else:
			var reason: String=service.hire_reason(id)
			entry.summary.text="可雇佣" if reason.is_empty() else "需满足条件"
			entry.summary.tooltip_text=reason
			if is_instance_valid(entry.button):entry.button.disabled=not reason.is_empty();entry.button.tooltip_text=reason
			if is_instance_valid(entry.reason):entry.reason.text=reason;entry.reason.visible=not reason.is_empty()
	if row==null or not is_instance_valid(health):return
	var npc: RefCounted=service.actor(row)
	if npc!=null:
		var stats: Dictionary=u.gameplay.definition("npc_full_defs","npc_id",u.gameplay.definition("npc_spawn_defs","spawn_id",npc.spawn_id).npc_id)
		health.text="护盾 %.0f%% / 装甲 %.0f%% / 结构 %.0f%%" % [100.0*npc.shield/float(stats.shield_max),100.0*npc.armor/float(stats.armor_max),100.0*npc.hull/float(stats.hull_max)]
	else:health.text="预计退押 %d · 按实际装甲/结构船况结算" % int(float(row.deposit_paid_credit)*row.condition_ratio)
	var spec: Dictionary=service.profile(row.profile_id)
	supplies.text="维修储备 %d / %d · 冷却 %.1f秒" % [row.support_cycles_remaining,spec.support_cycles,row.support_cooldown_s] if spec.role_id=="support" else "护航火力 · 编队距离 %s" % XJSpaceUnits.distance(float(service.balance.warp_ready_m))
func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<0.25 or not is_instance_valid(status) or not Interaction.current(u,_context,self):return
	_elapsed=0.0;_update()
	var current: String=u.gameplay.hired.token()
	if current!=_token or u.gameplay.hired.party_fee(1)!=_party_count:_token=current;_party_count=u.gameplay.hired.party_fee(1);u.call_deferred("refresh_page")
