extends RefCounted
## Finite commander proofs are written only by real activity settlement hooks.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
signal warning_changed(message: String)

func _init(game: RefCounted) -> void:g=game
func supported() -> bool:return g!=null and g.catalog.table_names.has("civilization_command_defs")
func instance(faction: String) -> D.CivilizationCommandStateDto:
	return g.state.find("civilization_command_state","faction_id",faction) as D.CivilizationCommandStateDto
func definition(faction: String) -> Dictionary:return g.definition("civilization_command_defs","faction_id",faction) if supported() else {}
static func initial_rows(catalog: XJCatalog,state: XJRuntimeState,legacy: bool=false) -> Array[RefCounted]:
	var result: Array[RefCounted]=[]
	if not catalog.table_names.has("civilization_command_defs"):return result
	for spec: Dictionary in catalog.rows("civilization_command_defs"):
		var row: D.CivilizationCommandStateDto=D.CivilizationCommandStateDto.new()
		row.player_id=state.player().player_id;row.faction_id=spec.faction_id
		if legacy:
			for war: RefCounted in state.rows("war_campaign_state"):
				var d: Dictionary=catalog.one("civilization_war_defs","war_id",war.war_id)
				if war.status in ["assembling","fighting","occupying"] and d.get("faction_id","")==row.faction_id:
					row.has_legacy_war_id=true;row.legacy_war_id=war.war_id;row.legacy_attempt=war.attempt
		result.append(row)
	return result
func tasks(faction: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not supported():return result
	for task: Dictionary in g.rows("civilization_honor_task_defs"):
		if task.faction_id==faction:result.append(task)
	var order: Array[String]=["scout","logistics","rescue","combat"]
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return order.find(a.task_kind)<order.find(b.task_kind))
	return result
func progress(task_id: String) -> int:
	var result: int=0
	for receipt: RefCounted in g.state.rows("civilization_honor_evidence_state"):
		if receipt.task_id==task_id:result+=receipt.credited_units
	return result
func completed(faction: String) -> int:
	var result: int=0
	for task: Dictionary in tasks(faction):
		if progress(task.task_id)==int(task.required_units):result+=1
	return result
func registration_reason(faction: String) -> String:
	var spec: Dictionary=definition(faction);var row: RefCounted=instance(faction)
	if spec.is_empty() or row==null:return "当前世界尚未升级指挥考核"
	if row.phase!="unregistered":return "此文明考核已登记"
	var reason: String=g.civilizations.permission_reason(faction,int(spec.registration_rank))
	if not reason.is_empty():return reason
	reason=g.civilizations.capital_reason(faction)
	if not reason.is_empty():return reason
	return "" if g.unlocked(spec.required_unlock_id) else "需要远域航路许可"
func certification_reason(faction: String) -> String:
	var spec: Dictionary=definition(faction);var row: RefCounted=instance(faction)
	if spec.is_empty() or row==null:return "指挥考核状态缺失"
	if row.phase=="certified":return "已取得此文明指挥资格"
	if row.phase!="assessing":return "先在所属核心站登记考核"
	if g.civilizations.allegiance()!=faction:return "需效忠 "+g.civilizations.faction_name(faction)
	var reason: String=g.civilizations.capital_reason(faction)
	if not reason.is_empty():return reason
	return "" if completed(faction)==tasks(faction).size() else "能力考核 · %d / %d" % [completed(faction),tasks(faction).size()]
func war_reason(faction: String) -> String:
	if not supported():return ""
	var row: RefCounted=instance(faction)
	if row!=null and row.phase=="certified":return ""
	return "需取得文明指挥资格 · 考核 %d / %d" % [completed(faction),tasks(faction).size()]
func execute(faction: String,action: String,expected_phase: String) -> bool:
	var row: RefCounted=instance(faction)
	if row==null or row.phase!=expected_phase:return g.fail("指挥考核已更新，请重新查看")
	var reason: String=registration_reason(faction) if action=="register" else certification_reason(faction) if action=="certify" else "未知考核操作"
	if not reason.is_empty():return g.fail(reason)
	if not g.allowed_service("mission_board"):return false
	if action=="register":
		row.phase="assessing";row.registered_tick=g.state.snapshot.meta.simulation_tick
		warning_changed.emit("指挥考核已登记 · 完成四类实际行动")
	else:
		var spec: Dictionary=definition(faction)
		row.phase="certified";row.certified_tick=g.state.snapshot.meta.simulation_tick
		row.paid_credit=int(spec.reward_credit);row.awarded_reputation=int(spec.reward_reputation)
		g.state.player().credit+=row.paid_credit;g.civilizations._add_reputation(faction,row.awarded_reputation)
		warning_changed.emit("指挥资格已认证 · 信用点 +%d · 声望 +%d" % [row.paid_credit,row.awarded_reputation])
	g.request_autosave()
	return true
func _record(kind: String,source_id: String,generation: int,units: int,token: String,recorded_tick: int) -> void:
	if not supported() or units<=0 or g.state.find("civilization_honor_evidence_state","source_token",token)!=null:return
	var faction: String=g.civilizations.allegiance();var command: RefCounted=instance(faction)
	if command==null or command.phase!="assessing" or recorded_tick<command.registered_tick:return
	for source: Dictionary in g.rows("civilization_honor_source_defs"):
		var matches: bool=source.event_id==source_id if kind=="exploration" else source.contract_id==source_id if kind=="consignment" else source.operation_id==source_id
		if not matches:continue
		var task: Dictionary=g.definition("civilization_honor_task_defs","task_id",source.task_id)
		if task.faction_id!=faction:continue
		var remaining: int=int(task.required_units)-progress(task.task_id)
		if remaining<=0:return
		var evidence: D.CivilizationHonorEvidenceStateDto=D.CivilizationHonorEvidenceStateDto.new()
		evidence.source_token=token;evidence.task_id=task.task_id;evidence.source_kind=kind;evidence.source_def_id=source_id
		evidence.generation=generation;evidence.credited_units=mini(remaining,units);evidence.recorded_tick=recorded_tick
		g.state.add("civilization_honor_evidence_state",evidence)
		warning_changed.emit("考核 · %s %d / %d" % [task.display_name,progress(task.task_id),task.required_units])
		return
func exploration_claimed(receipt: RefCounted) -> void:
	if receipt.outcome!="full":return
	_record("exploration",receipt.event_id,receipt.generation,1,"exploration:"+receipt.event_id+":"+str(receipt.generation),receipt.claimed_tick)
func operation_claimed(row: RefCounted) -> void:
	var spec: Dictionary=g.operations.definition(row.operation_id)
	if spec.operation_kind!="demolition" or row.completed_units!=int(spec.target_units):return
	_record("operation",row.operation_id,row.generation,row.completed_units,"operation:"+row.operation_id+":"+str(row.generation),g.state.snapshot.meta.simulation_tick)
func consignment_claimed(receipt: RefCounted) -> void:
	if receipt.action_kind!="claim" or receipt.units<=0:return
	var spec: Dictionary=g.consignments.definition(receipt.contract_id)
	if receipt.reward_credit!=receipt.units*int(spec.reward_per_unit):return
	_record("consignment",receipt.contract_id,receipt.generation,receipt.units,"consignment:"+receipt.receipt_id,g.state.snapshot.meta.simulation_tick)
func sources(task_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not supported():return result
	for source: Dictionary in g.rows("civilization_honor_source_defs"):
		if source.task_id!=task_id:continue
		var kind: String="exploration" if source.event_id!=null else "consignment" if source.contract_id!=null else "operation"
		var id: String=str(source.event_id if kind=="exploration" else source.contract_id if kind=="consignment" else source.operation_id)
		var row: RefCounted=g.exploration.instance(id) if kind=="exploration" else g.consignments.instance(id) if kind=="consignment" else g.operations.instance(id)
		result.append({"kind":kind,"id":id,"generation":row.generation if row!=null else 0})
	return result
