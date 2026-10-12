extends VBoxContainer
const T=preload("res://contracts/contract_types.gd")
const ResourceStatus=preload("res://runtime/resource_status.gd")
var u: Node
var mode: String
var context: Dictionary
var signature: String=""
var elapsed: float=0.0
var live_labels: Array[Dictionary]=[]
func setup(ui: Node,page: String) -> void:
	u=ui;mode=page;context={"state":u.state,"session":u.state.session_id,"epoch":u.state.epoch,"generation":u.business_generation}
	add_theme_constant_override("separation",10);_build()
func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(u) and u.page==mode and u.state==context.state and u.state.session_id==context.session and u.state.epoch==context.epoch and u.business_generation==context.generation and u.body.is_ancestor_of(self)
func _signature() -> String:
	if mode=="projects":
		var text: String=u.project_selected_id
		for row: RefCounted in u.state.rows("construction_state"):text+="|%s:%d:%s" % [row.project_id,row.revision,u.gameplay.projects.owned(row.project_id)]
		return text
	if mode=="expeditions":
		var run: RefCounted=u.gameplay.expeditions.active()
		return "%d:%s:%s:%s" % [u.gameplay.expeditions.director().generation,run.run_id if run!=null else "",run.phase if run!=null else "",run.stage_index if run!=null else 0]
	var latest: RefCounted=u.gameplay.telemetry.latest()
	return "%d:%s:%s" % [u.state.rows("flight_record_state").size(),latest.sequence if latest!=null else 0,latest.phase if latest!=null else ""]
func _build() -> void:
	for child: Node in get_children():remove_child(child);child.queue_free()
	live_labels.clear()
	if not u.gameplay.projects.supported():u._text_to(self,"当前旧规则世界尚未开启主题行动。",15);return
	if mode=="projects":_projects()
	elif mode=="expeditions":_expeditions()
	else:_reports()
	signature=_signature();_update()
func _request(parent: Node,title: String,action: String,target: String,extra: String,quantity: int=1) -> Button:
	var button: Button=u._button(parent,title,func():
		if _current():u.requested.emit(action,target,quantity,extra))
	return button
func _nav(parent: Node,kind: String,id: String,token: String) -> void:
	_request(parent,"星图定位","campaign_map",kind+":"+id,token)
	var go: Button=_request(parent,"前往当前目标","campaign_navigate",kind+":"+id,token)
	go.disabled=u.state.ship().status!=T.ShipStatus.FLYING
	go.tooltip_text="出港后沿实际AU航程与航门前往；跨门仍按F确认。"
func _projects() -> void:
	var service: RefCounted=u.gameplay.projects
	var choices: HFlowContainer=HFlowContainer.new();add_child(choices)
	var definitions: Array=u.catalog.rows("construction_project_defs")
	if u.project_selected_id.is_empty():u.project_selected_id=definitions[0].project_id
	for def: Dictionary in definitions:
		var id: String=def.project_id
		u._button(choices,def.display_name,func():
			if _current():u.project_selected_id=id;_build()).name="ProjectSelect_"+id
	var id: String=u.project_selected_id
	var row: RefCounted=service.instance(id);var def: Dictionary=service.definition(id);var token: String=service.token(id)
	u._text_to(self,def.display_name+" · "+u._sector_name(def.sector_id),20)
	u._text_to(self,"阶段 %d/3 · %s · 探索贡献 %d/%d" % [row.stage_index,"已完成" if row.phase=="completed" else service.stage(id,row.stage_index).display_name,service.evidence(id),def.required_evidence_units],14)
	var status: Label=u._text_to(self,"",14);status.name="ProjectStatus";live_labels.append({"label":status,"kind":"project","id":id})
	var actions: HFlowContainer=HFlowContainer.new();add_child(actions);_nav(actions,"project",id,token)
	var pause: Button=_request(actions,"恢复工程" if row.paused else "暂停工程","construction_action",id,("resume" if row.paused else "pause")+"||"+token)
	pause.name="ProjectPause"
	pause.disabled=row.phase=="completed"
	if row.phase=="completed":u._text_to(self,"制造费、维修费与补货改善已生效。" if service.owned(id) else "已建阶段保留；收复后恢复服务收益。",14);return
	var spec: Dictionary=service.stage(id,row.stage_index)
	u._text_to(self,"施工 %s · 服务费 %d 信用点" % [ResourceStatus.countdown(spec.work_s),spec.fee_credit],14)
	for input: Dictionary in service.inputs(id,row.stage_index):
		var delivered: RefCounted=service.delivered(input);var item_id: String=input.item_id
		var remaining: int=int(input.required_units)-delivered.delivered_units
		u._text_to(self,"%s · %d/%d · 集货站：%s" % [u._item_name(item_id),delivered.delivered_units,input.required_units,u._station_name(input.delivery_station_id)],14)
		var controls: HFlowContainer=HFlowContainer.new();add_child(controls)
		var spin: SpinBox=SpinBox.new();spin.min_value=1;spin.max_value=maxi(1,remaining);spin.step=1;spin.value=mini(10,maxi(1,remaining));spin.custom_minimum_size=Vector2(100,36);controls.add_child(spin)
		var witness: WeakRef=weakref(spin)
		var deliver: Button=u._button(controls,"交付本站物资",func():
			var current: Variant=witness.get_ref()
			if _current() and is_instance_valid(current) and current.is_inside_tree():u.requested.emit("construction_action",id,int(current.value),"deliver|"+item_id+"|"+token))
		deliver.name="ProjectDeliver_"+item_id;deliver.disabled=remaining<=0 or not service.reason(id,"deliver",1,item_id).is_empty()
		deliver.tooltip_text=service.reason(id,"deliver",1,item_id)
		u._button(controls,"物资来源",func():
			if _current():u.open_sources(item_id))
		_request(controls,"定位集货站","campaign_map","station:"+str(input.delivery_station_id),"")
	var begin: Button=_request(self,"支付并开始本阶段","construction_action",id,"start||"+token)
	begin.name="ProjectStart";begin.disabled=not service.reason(id,"start").is_empty();begin.tooltip_text=service.reason(id,"start")
func _expeditions() -> void:
	var service: RefCounted=u.gameplay.expeditions
	var director: RefCounted=service.director()
	var focus: Dictionary={}
	for def: Dictionary in u.catalog.rows("expedition_route_defs"):
		if int(def.focus_index)==director.focus_index:focus=def
	var label: Label=u._text_to(self,"",14);label.name="ExpeditionFocus";live_labels.append({"label":label,"kind":"focus"})
	var run: RefCounted=service.active()
	if run==null:
		for def: Dictionary in u.catalog.rows("expedition_route_defs"):
			u._text_to(self,def.display_name+" · 准备费 %d" % int(def.start_fee_credit),19)
			u._text_to(self,"受领站："+u._station_name(def.origin_station_id)+" · "+def.description,13)
			var options: HFlowContainer=HFlowContainer.new();add_child(options)
			_request(options,"定位准备站","campaign_map","station:"+str(def.origin_station_id),"")
			for choice: Dictionary in service.options(def.route_id,1):
				var button: Button=_request(options,"出航 · "+u.gameplay.exploration.definition(choice.event_id).display_name,"expedition_action",def.route_id,"start|"+str(choice.option_id)+"|"+service.token(def.route_id))
				button.name="ExpeditionStart_"+str(def.route_id)+"_"+str(choice.option_id)
				button.disabled=not service.reason(def.route_id,"start",choice.option_id).is_empty();button.tooltip_text=service.reason(def.route_id,"start",choice.option_id)
		return
	var current: RefCounted=service.stage(run);var token: String=service.token(run.run_id)
	u._text_to(self,service.route(run.route_id).display_name+" · 第%d/3段" % run.stage_index,20)
	u._text_to(self,"本轮协调成果已入账：%d信用点 / %d探索证据" % [run.bonus_credit_total,run.bonus_insight_total],14)
	var state_label: Label=u._text_to(self,"",14);state_label.name="ExpeditionStatus";live_labels.append({"label":state_label,"kind":"expedition","id":run.run_id})
	var actions: HFlowContainer=HFlowContainer.new();add_child(actions);_nav(actions,"expedition",run.run_id,token)
	u._button(actions,"处理本段事件",func():
		if _current():u.open_exploration(current.event_id)).name="ExpeditionEvent"
	var end: Button=_request(actions,"结束并撤回","expedition_action",run.run_id,"withdraw||"+token)
	end.name="ExpeditionWithdraw";end.disabled=not service.reason(run.run_id,"withdraw").is_empty();end.tooltip_text=service.reason(run.run_id,"withdraw")
	if run.phase=="checkpoint":
		u._text_to(self,"已结算段落保留。选择下一段，或在此结束本轮。",14)
		for choice: Dictionary in service.options(run.route_id,run.stage_index+1):
			var button: Button=_request(self,"继续 · "+u.gameplay.exploration.definition(choice.event_id).display_name,"expedition_action",run.run_id,"continue|"+str(choice.option_id)+"|"+token)
			button.disabled=not service.reason(run.run_id,"continue",choice.option_id).is_empty();button.tooltip_text=service.reason(run.run_id,"continue",choice.option_id)
func _reports() -> void:
	var service: RefCounted=u.gameplay.telemetry
	var total_label: Label=u._text_to(self,"",17);live_labels.append({"kind":"total","label":total_label})
	var actions: HFlowContainer=HFlowContainer.new();add_child(actions)
	_request(actions,"导出CSV","export_flight_report","csv","").name="ReportExportCSV"
	_request(actions,"导出JSON","export_flight_report","json","").name="ReportExportJSON"
	u._text_to(self,"导出仅包含本地游戏指标；不含角色名称、凭据、输入内容或系统路径。飞行中升级的部分记录会明确标注。",13)
	for report: Dictionary in service.export_rows():
		u._text_to(self,"#%d · %s · %s%s" % [report.sequence,report.hull,{"active":"出航中","docked":"已返港","lost":"损毁"}[report.status]," · 部分基线" if report.partial_baseline else ""],17)
		var label: Label=u._text_to(self,"",13);live_labels.append({"kind":"report","sequence":report.sequence,"label":label})
func _update() -> void:
	for entry: Dictionary in live_labels:
		if not is_instance_valid(entry.label):continue
		if entry.kind=="total":
			var total: RefCounted=u.gameplay.telemetry.totals()
			entry.label.text="累计出航 %d · 损毁 %d · 采集 %d单位\n收益 %d / 费用 %d信用点 · 分摊伤害 %.0f / 承伤 %.0f" % [total.outings,total.lost_outings,total.mined_units,total.income_credit,total.spent_credit,total.damage_dealt,total.damage_taken]
		elif entry.kind=="report":
			for report: Dictionary in u.gameplay.telemetry.export_rows():
				if report.sequence!=entry.sequence:continue
				entry.label.text="航行 %s · 交战 %s · 跃迁 %s\n飞行收支 +%d / −%d；返港收支 +%d / −%d\n参与击破 %d · 采集 %d · 无人机损失 %d · 分摊伤害 %.0f / 承伤 %.0f" % [ResourceStatus.countdown(report.elapsed_s),ResourceStatus.countdown(report.combat_s),ResourceStatus.countdown(report.transit_s),report.flight_income,report.flight_spent,report.return_income,report.return_spent,report.kills,report.mined_units,report.drone_losses,report.damage_dealt,report.damage_taken]
				var materials: PackedStringArray=[]
				for id: String in report.materials_used:
					materials.append("%s × %d（退回%d）" % [u._item_name(id),report.materials_used[id],report.materials_returned.get(id,0)])
				entry.label.text+="\n材料投入："+("、".join(materials) if not materials.is_empty() else "无记录")
				entry.label.text+="\n实际维修：自修 %.0f / 对友舰 %.0f / 支援 %.0f / 站内 %.0f HP" % [report.repair_hp.get("self",0),report.repair_hp.get("provided",0),report.repair_hp.get("received",0),report.repair_hp.get("station",0)]
		elif entry.kind=="project":
			var row: RefCounted=u.gameplay.projects.instance(entry.id)
			entry.label.text="已暂停 · 投入保留" if row.paused else "等待收复 · 投入保留" if not u.gameplay.projects.owned(entry.id) else "施工剩余 "+ResourceStatus.countdown(row.work_remaining_s) if row.phase=="working" else "已完成" if row.phase=="completed" else "集货中 · 可分批交付"
		elif entry.kind=="focus":
			var director: RefCounted=u.gameplay.expeditions.director();var title: String=""
			for def: Dictionary in u.catalog.rows("expedition_route_defs"):
				if int(def.focus_index)==director.focus_index:title=def.display_name
			entry.label.text="本轮重点：%s · %s后轮换；已受领远征条件保持" % [title,ResourceStatus.countdown(director.remaining_s)]
		else:
			var run: RefCounted=u.gameplay.expeditions.instance(entry.id)
			entry.label.text={"active":"前往并处理当前事件","checkpoint":"本段已结算，选择后续","returning":"撤回中，前往实际撤离点与交付站"}.get(run.phase,run.phase)
func _process(delta: float) -> void:
	if not _current():return
	elapsed+=delta
	if elapsed<0.25:return
	elapsed=0.0
	if _signature()!=signature:_build()
	else:_update()
