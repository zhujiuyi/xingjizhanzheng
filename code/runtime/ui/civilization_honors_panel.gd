extends RefCounted
var u: Node
var faction: String=""
var title: Label
var register_button: Button
var certify_button: Button
var values: Dictionary={}
var grant_buttons: Dictionary={}

func build(ui: Node,id: String,owner: RefCounted) -> void:
	u=ui;faction=id
	if not u.gameplay.honors.supported():return
	var row: RefCounted=u.gameplay.honors.instance(faction)
	title=u._text_to(u.body,"",18);title.name="CommanderExaminationStatus"
	var actions: HFlowContainer=HFlowContainer.new();u.body.add_child(actions)
	register_button=owner._command(actions,"登记考核","honor_action",faction,null,"register:"+str(row.phase))
	register_button.name="CommanderRegister"
	certify_button=owner._command(actions,"认证资格","honor_action",faction,null,"certify:"+str(row.phase))
	certify_button.name="CommanderCertify"
	var spec: Dictionary=u.gameplay.honors.definition(faction)
	var reward: Label=u._text_to(u.body,"认证奖励 · %d信用点 / %d声望" % [spec.reward_credit,spec.reward_reputation],13)
	reward.tooltip_text="完成登记后的四类实际行动，回所属核心站认证一次；新战争还需达到原爵位。旧战役继续履行。"
	for task: Dictionary in u.gameplay.honors.tasks(faction):
		var block: VBoxContainer=VBoxContainer.new();block.add_theme_constant_override("separation",4);u.body.add_child(block)
		var label: Label=u._text_to(block,"",14);label.name="CommanderProgress_"+str(task.task_kind)
		values[str(task.task_id)]=label
		var controls: HFlowContainer=HFlowContainer.new();block.add_child(controls)
		var sources: Array[Dictionary]=u.gameplay.honors.sources(task.task_id)
		var choices: OptionButton=OptionButton.new();choices.name="CommanderSource_"+str(task.task_kind)
		choices.custom_minimum_size=Vector2(180,30)
		for source: Dictionary in sources:
			var definition: Dictionary=u.catalog.one("exploration_event_defs","event_id",source.id) if source.kind=="exploration" else u.catalog.one("consignment_defs","contract_id",source.id) if source.kind=="consignment" else u.catalog.one("operation_defs","operation_id",source.id)
			choices.add_item(str(definition.display_name))
		controls.add_child(choices)
		var choices_ref: WeakRef=weakref(choices)
		for navigate: bool in [false,true]:
			var state: RefCounted=u.state;var catalog: RefCounted=u.catalog;var epoch: int=state.epoch;var generation: int=u.business_generation
			var callback: Callable=func():
				if u.state!=state or u.catalog!=catalog or state.epoch!=epoch or u.business_generation!=generation or u.page!="civilizations" or u.civilization_selected_faction!=faction:return
				var live_choices: OptionButton=choices_ref.get_ref() as OptionButton
				if not is_instance_valid(live_choices):return
				var index: int=live_choices.selected
				if index<0 or index>=sources.size():return
				var source: Dictionary=sources[index]
				var action: String=("exploration_nav" if navigate else "exploration_map") if source.kind=="exploration" else ("consignment_navigate" if navigate else "consignment_map") if source.kind=="consignment" else ("operation_nav" if navigate else "operation_map")
				u.requested.emit(action,source.id,1,str(source.generation))
			var button: Button=u._button(controls,"前往" if navigate else "定位",callback)
			button.name=("CommanderNavigate_" if navigate else "CommanderLocate_")+str(task.task_kind)
			button.tooltip_text="完整调查/救援/拆除结算计入考核；承运按实际送达批数累计。登记前已结算、失败和退回不计。"
		if u.gameplay.growth.supported():_add_grant(controls,task)
	tick()

func _add_grant(parent: Node,task: Dictionary) -> void:
	var id: String=str(task.task_id)
	var state: RefCounted=u.state;var catalog: RefCounted=u.catalog;var epoch: int=state.epoch;var generation: int=u.business_generation;var selected_faction: String=faction
	var callback: Callable=func():
		if u.state!=state or u.catalog!=catalog or state.epoch!=epoch or u.business_generation!=generation or u.page!="civilizations" or u.civilization_selected_faction!=selected_faction:return
		u.requested.emit("growth_claim",id,1,u.gameplay.growth.grant_token(id))
	var button: Button=u._button(parent,"",callback);button.name="GrowthGrant_"+str(task.task_kind);grant_buttons[id]=button
func tick() -> void:
	if not is_instance_valid(title):return
	var honors: RefCounted=u.gameplay.honors;var row: RefCounted=honors.instance(faction)
	if row==null:return
	var phase: String="已认证" if row.phase=="certified" else "考核中" if row.phase=="assessing" else "待登记"
	title.text="指挥资格 · %s · %d / %d" % [phase,honors.completed(faction),honors.tasks(faction).size()]
	var reason: String=honors.registration_reason(faction)
	register_button.disabled=not reason.is_empty();register_button.tooltip_text=reason
	reason=honors.certification_reason(faction)
	certify_button.disabled=not reason.is_empty();certify_button.tooltip_text=reason
	for task: Dictionary in honors.tasks(faction):
		var label: Label=values[str(task.task_id)]
		var count: int=honors.progress(task.task_id)
		label.text="%s%s · %d / %d%s" % ["✓ " if count==int(task.required_units) else "",task.display_name,count,task.required_units,"批" if task.task_kind=="logistics" else ""]
		if grant_buttons.has(str(task.task_id)):
			var grant: Dictionary=u.catalog.one("growth_grant_defs","task_id",task.task_id)
			var button: Button=grant_buttons[str(task.task_id)]
			var claimed: bool=u.state.find("growth_grant_receipt_state","task_id",task.task_id)!=null
			button.text=("已领" if claimed else "领取整备款")+" · %d信用点 / %d声望" % [int(grant.reward_credit),int(grant.reward_reputation)]
			var why: String=u.gameplay.growth.grant_reason(task.task_id);button.disabled=not why.is_empty();button.tooltip_text=why if not why.is_empty() else "每个真实考核项目仅领取一次，资格认证奖励另计。"
