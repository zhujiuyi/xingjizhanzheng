extends VBoxContainer
const T=preload("res://contracts/contract_types.gd")
const Status=preload("res://runtime/resource_status.gd")
var u: Node
var kind: String
var context: Dictionary
var selected: String=""
var signature: String=""
var clock: float=0
var status_label: Label
func setup(ui: Node,page: String) -> void:
	u=ui;kind="trial" if page=="trials" else "blockade"
	selected=u.get(kind+"_selected_id")
	context={"state":u.state,"epoch":u.state.epoch,"generation":u.business_generation,"page":page}
	add_theme_constant_override("separation",10);build()
func current() -> bool:return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(u) and u.state==context.state and u.state.epoch==context.epoch and u.business_generation==context.generation and u.page==context.page and u.body.is_ancestor_of(self)
func service() -> RefCounted:return u.gameplay.scenarios
func stamp() -> String:
	var text: String=selected
	for row: RefCounted in u.state.rows(kind+"_state"):
		text+="|%s:%d:%s:%s" % [row.get(kind+"_id"),row.generation,row.phase,row.cooldown_remaining_s>0]
		if kind=="blockade":text+=str(row.has_scan_node_index)+str(row.alerted)+str(row.cargo_units)
	if kind=="blockade":
		for row: RefCounted in u.state.rows("blockade_node_state"):text+=str(row.completed)
	return text+str(u.state.rows("tactical_award_state").size())
func button(parent: Node,text: String,action: String,extra: String) -> Button:
	var captured: String=selected
	return u._button(parent,text,func():
		if current() and selected==captured:u.requested.emit(action,captured,1,extra))
func route(parent: Node,node: int=-1) -> void:
	var captured: String=selected
	var target: String=kind+":"+selected+(":"+str(node) if node>=0 else "")
	var expected: String=service().token(kind,selected)
	u._button(parent,"星图定位",func():
		if current() and selected==captured:u.requested.emit("scenario_map",target,1,expected))
	var go: Button=u._button(parent,"前往目标",func():
		if current() and selected==captured:u.requested.emit("scenario_navigate",target,1,expected))
	go.disabled=u.state.ship().status!=T.ShipStatus.FLYING
func build() -> void:
	for child: Node in get_children():remove_child(child);child.queue_free()
	if not service().supported():u._text_to(self,"当前旧规则世界尚未开放战术场景。",15);return
	var defs: Array=u.catalog.rows("trial_defs" if kind=="trial" else "blockade_defs")
	if not defs.any(func(d: Dictionary):return d.get(kind+"_id")==selected):
		var pending: Dictionary=service().pending()
		selected=pending.id if not pending.is_empty() and pending.kind==kind else defs[0].get(kind+"_id")
		if pending.is_empty():
			for def: Dictionary in defs:
				if def.station_id==u.gameplay.station():selected=def.get(kind+"_id");break
	u.set(kind+"_selected_id",selected)
	var choices: HFlowContainer=HFlowContainer.new();add_child(choices)
	for def: Dictionary in defs:
		var id: String=def.get(kind+"_id")
		var choice: Button=u._button(choices,def.display_name,func():
			if current():selected=id;u.set(kind+"_selected_id",id);build())
		choice.name="ScenarioSelect_"+id;choice.toggle_mode=true;choice.button_pressed=id==selected
		if id==selected:u._primary(choice)
		else:u._secondary(choice)
	var spec: Dictionary=service().definition(kind,selected);var row: RefCounted=service().instance(kind,selected)
	u._text_to(self,spec.display_name,20)
	if kind=="trial":
		var hulls: PackedStringArray=[]
		for allowed: Dictionary in u.catalog.rows("trial_hull_defs"):
			if allowed.trial_id==selected:hulls.append(u._ship_name(allowed.ship_id))
		u._text_to(self,"参考预算 %d / %d 信用点 · 服务费 %d" % [service().budget(),spec.budget_credit,spec.fee_credit],15).tooltip_text="包含舰体、已装设备、作战耗材、无人机储备及已雇佣僚舰的舰体参考造价；雇佣关系变化也会改变本次绑定。"
		u._text_to(self,"舰型："+"、".join(hulls),14)
		if spec.objective_kind=="precision":u._text_to(self,"计分距离 %.1f–%.1f km · 有效伤害 %.0f HP" % [spec.min_range_m/1000.0,spec.max_range_m/1000.0,spec.target_hp],14)
		elif spec.objective_kind=="support":u._text_to(self,"有效远修 %.0f HP · 保护友舰抵达出口" % spec.target_hp,14)
		if row.best_elapsed_s>0:u._text_to(self,"最佳 %.1f 秒 · 最低参考造价 %d" % [row.best_elapsed_s,row.best_cost],14)
	else:
		u._text_to(self,"签发：%s · 服务费 %d · 送达每批 %d 信用点" % [u._station_name(spec.station_id),spec.fee_credit,spec.credit_per_unit],14)
		u._text_to(self,"侦测 %.1f km · 静默 ≤%.0f m/s · 侧路 %.0f 秒" % [spec.detection_radius_m/1000.0,spec.quiet_speed_mps,spec.bypass_window_s],14)
	u._text_to(self,spec.description,14)
	status_label=u._text_to(self,"",15);status_label.name="ScenarioStatus"
	var nav: HFlowContainer=HFlowContainer.new();add_child(nav);route(nav)
	var actions: HFlowContainer=HFlowContainer.new();add_child(actions)
	for action: String in ["accept","start","withdraw","claim"]:
		var expected: String=service().token(kind,selected)
		var command: String="trial_action" if kind=="trial" else "blockade_action"
		var b: Button=button(actions,{"accept":"支付并受领","start":"开始行动","withdraw":"撤回本次行动","claim":"交付成果"}[action],command,action+"|"+expected)
		b.name="ScenarioAction_"+action
		var blocked: String=service().trial_reason(selected,action) if kind=="trial" else service().blockade_reason(selected,action)
		b.disabled=not blocked.is_empty();b.tooltip_text=blocked
	if kind=="blockade" and row.phase=="active":
		var controls: HFlowContainer=HFlowContainer.new();add_child(controls)
		var exit_button: Button=button(controls,"从出口脱离","blockade_action","exit|"+str(row.generation));exit_button.name="BlockadeExit";exit_button.disabled=not service().blockade_reason(selected,"exit").is_empty()
		var drop: Button=button(controls,"抛弃一批货物","blockade_action","jettison|"+str(row.generation));drop.name="BlockadeJettison";drop.disabled=row.cargo_units<=0
		for node: Dictionary in u.catalog.rows("blockade_node_defs"):
			if node.blockade_id!=selected:continue
			var index: int=int(node.node_index);var progress: RefCounted=service()._node(selected,index)
			u._text_to(self,service().node_label(selected,index)+(" · 已完成" if progress.completed else " · 未处理"),14)
			var tools: HFlowContainer=HFlowContainer.new();add_child(tools);route(tools,index)
			if node.node_kind=="survey":
				var scan: Button=button(tools,"付费调查节点","blockade_action","survey|"+str(row.generation)+"|"+str(index));scan.name="BlockadeSurvey_"+str(index)
				scan.tooltip_text=service().blockade_reason(selected,"survey",index);scan.disabled=not scan.tooltip_text.is_empty()
	awards();signature=stamp();refresh()
func awards() -> void:
	if u.state.rows("tactical_award_state").is_empty():return
	u._text_to(self,"已取得称号",16)
	var tools: HFlowContainer=HFlowContainer.new();add_child(tools)
	u._button(tools,"隐藏称号",func():
		if current():u.requested.emit("select_tactical_award","",1,""))
	for award: RefCounted in u.state.rows("tactical_award_state"):
		var id: String=award.award_id
		u._button(tools,u.catalog.one("tactical_award_defs","award_id",id).display_name,func():
			if current():u.requested.emit("select_tactical_award",id,1,""))
func refresh() -> void:
	if not is_instance_valid(status_label):return
	var row: RefCounted=service().instance(kind,selected)
	var phase: String={"available":"可受领","accepted":"前往入口","active":"进行中","ready":"返回签发站交付","completed":"已完成","claimed":"已交付","failed":"失败","withdrawn":"已撤回"}.get(row.phase,row.phase)
	status_label.text=phase+" · 剩余 "+Status.countdown(row.remaining_s)
	if kind=="trial":status_label.text+=" · 有效贡献 %.0f" % row.effective_hp
	else:
		status_label.text+="\n货物 %d / %d · 损失 %d · 抛弃 %d · %s" % [row.cargo_units,row.loaded_units,row.lost_units,row.jettisoned_units,"已警戒" if row.alerted else "未警戒"]
		if row.bypass_remaining_s>0:status_label.text+=" · 侧路窗口 "+Status.countdown(row.bypass_remaining_s)
		if row.has_scan_node_index:status_label.text+=" · 调查 "+Status.countdown(row.scan_remaining_s)
		if row.phase=="active":status_label.text+=" · "+("封锁范围内" if service().field_active(selected) else "跃迁封锁已解除")
	if row.cooldown_remaining_s>0 and row.phase not in ["accepted","active","ready"]:status_label.text+=" · 整备 "+Status.countdown(row.cooldown_remaining_s)
	for result: RefCounted in u.state.rows(kind+"_result_state"):
		if result.get(kind+"_id")==selected and result.generation==row.generation:
			status_label.text+="\n本次结果："+u.gameplay.journal.reason_label(result.reason_code)
			if kind=="blockade":status_label.text+=" · 送达 %d 批 · 收益 %d 信用点" % [result.delivered_units,result.reward_credit]
func _process(delta: float) -> void:
	if not current():return
	clock+=delta
	if clock<0.25:return
	clock=0
	if stamp()!=signature:build()
	else:refresh()
