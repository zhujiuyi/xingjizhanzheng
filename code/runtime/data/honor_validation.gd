extends RefCounted
var last_error: String=""

func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	var commands: Array=state.rows("civilization_command_state")
	var evidence: Array=state.rows("civilization_honor_evidence_state")
	if not catalog.table_names.has("civilization_command_defs"):
		return true if commands.is_empty() and evidence.is_empty() else _fail("Honor state under legacy rules")
	var defs: Array[Dictionary]=catalog.rows("civilization_command_defs")
	if commands.size()!=defs.size():return _fail("Commander coverage incomplete")
	var found: Dictionary={};var progress: Dictionary={};var tokens: Dictionary={}
	var tick: int=state.snapshot.meta.simulation_tick
	for row: RefCounted in commands:
		var spec: Dictionary=catalog.one("civilization_command_defs","faction_id",row.faction_id)
		if spec.is_empty() or found.has(row.faction_id) or row.player_id!=state.player().player_id:return _fail("Invalid commander ownership or duplicate faction")
		found[row.faction_id]=row
		if row.phase not in ["unregistered","assessing","certified"] or row.registered_tick<0 or row.certified_tick<0 or row.registered_tick>tick or row.certified_tick>tick:return _fail("Invalid commander phase or time")
		if row.phase=="unregistered" and (row.registered_tick!=0 or row.certified_tick!=0 or row.paid_credit!=0 or row.awarded_reputation!=0):return _fail("Unregistered commander has paid or dated state")
		if row.phase=="assessing" and (row.certified_tick!=0 or row.paid_credit!=0 or row.awarded_reputation!=0):return _fail("Unfinished commander examination has a payout")
		if row.phase=="certified" and (row.certified_tick<row.registered_tick or row.paid_credit!=int(spec.reward_credit) or row.awarded_reputation!=int(spec.reward_reputation)):return _fail("Invalid commander certification payout")
		if row.has_legacy_war_id:
			var war: RefCounted=state.find("war_campaign_state","war_id",row.legacy_war_id)
			var war_def: Dictionary=catalog.one("civilization_war_defs","war_id",row.legacy_war_id)
			if war==null or war_def.get("faction_id","")!=row.faction_id or row.legacy_attempt<=0:return _fail("Invalid preserved legacy war")
		elif not row.legacy_war_id.is_empty() or row.legacy_attempt!=0:return _fail("Unexpected legacy war identity")
	for row: RefCounted in evidence:
		var task: Dictionary=catalog.one("civilization_honor_task_defs","task_id",row.task_id)
		if task.is_empty() or tokens.has(row.source_token) or row.credited_units<=0 or row.generation<=0:return _fail("Invalid or reused honor evidence")
		tokens[row.source_token]=true
		var command: RefCounted=found.get(str(task.faction_id))
		if command==null or command.phase=="unregistered" or row.recorded_tick<command.registered_tick or row.recorded_tick>tick:return _fail("Honor evidence outside its registered examination")
		var allowed: bool=false
		for source: Dictionary in catalog.rows("civilization_honor_source_defs"):
			if source.task_id!=row.task_id:continue
			allowed=allowed or (row.source_kind=="exploration" and source.event_id==row.source_def_id) or (row.source_kind=="operation" and source.operation_id==row.source_def_id) or (row.source_kind=="consignment" and source.contract_id==row.source_def_id)
		if not allowed or not _source_valid(state,catalog,row,task):return _fail("Honor evidence lacks a real authorized settlement")
		progress[row.task_id]=int(progress.get(row.task_id,0))+row.credited_units
		if int(progress[row.task_id])>int(task.required_units):return _fail("Honor progress exceeds its requirement")
	for task: Dictionary in catalog.rows("civilization_honor_task_defs"):
		if found[str(task.faction_id)].phase=="certified" and int(progress.get(task.task_id,0))!=int(task.required_units):return _fail("Commander certification requires every ability")
	for war: RefCounted in state.rows("war_campaign_state"):
		if war.status not in ["assembling","fighting","occupying"]:continue
		var spec: Dictionary=catalog.one("civilization_war_defs","war_id",war.war_id)
		var command: RefCounted=found.get(str(spec.get("faction_id","")))
		if command==null or (command.phase!="certified" and not(command.has_legacy_war_id and command.legacy_war_id==war.war_id and command.legacy_attempt==war.attempt)):return _fail("New war lacks commander qualification")
	return true
func _source_valid(state: XJRuntimeState,catalog: XJCatalog,e: RefCounted,task: Dictionary) -> bool:
	if e.source_kind=="exploration":
		if e.credited_units!=1 or e.source_token!="exploration:"+e.source_def_id+":"+str(e.generation) or task.task_kind not in ["scout","rescue"]:return false
		var spec: Dictionary=catalog.one("exploration_event_defs","event_id",e.source_def_id)
		if spec.get("event_kind","")!=("relic" if task.task_kind=="scout" else "rescue"):return false
		for receipt: RefCounted in state.rows("exploration_claim_state"):
			if receipt.event_id==e.source_def_id and receipt.generation==e.generation:return receipt.player_id==state.player().player_id and receipt.outcome=="full" and receipt.claimed_tick==e.recorded_tick
	elif e.source_kind=="operation":
		if task.task_kind!="combat" or e.source_token!="operation:"+e.source_def_id+":"+str(e.generation):return false
		var receipt: RefCounted=state.find("specialization_evidence_state","source_token",e.source_token)
		var spec: Dictionary=catalog.one("operation_defs","operation_id",e.source_def_id)
		return receipt!=null and receipt.player_id==state.player().player_id and receipt.source_kind=="operation" and receipt.source_def_id==e.source_def_id and receipt.generation==e.generation and spec.get("operation_kind","")=="demolition" and receipt.source_units==int(spec.target_units) and e.credited_units<=receipt.source_units
	elif e.source_kind=="consignment":
		if task.task_kind!="logistics":return false
		for receipt: RefCounted in state.rows("consignment_receipt_state"):
			if "consignment:"+receipt.receipt_id!=e.source_token:continue
			var spec: Dictionary=catalog.one("consignment_defs","contract_id",receipt.contract_id)
			return receipt.contract_id==e.source_def_id and receipt.generation==e.generation and receipt.action_kind=="claim" and e.credited_units<=receipt.units and receipt.reward_credit==receipt.units*int(spec.reward_per_unit)
	return false
func _fail(message: String) -> bool:
	last_error=message;return false
