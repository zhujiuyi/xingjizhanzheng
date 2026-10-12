extends "roles_v32.gd"
## Membership/rank/funds, chosen variants and endpoint poses are fixtures.
## Ability proofs use real paid actions, outcome settlement and durable sources.
var factions_checked: int=0
var evidence_checked: int=0

func _ready() -> void:
	get_tree().set_meta("xj_honors_v33_diagnostic",true)
	get_tree().create_timer(480.0).timeout.connect(func():print("HONORS_V33_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func at_station(id: String) -> void:
	var spec: Dictionary=g.definition("station_defs","station_id",id);place(spec.station_anchor_id,id)
func at_capital(faction: String) -> void:
	var spec: Dictionary=g.definition("civilization_defs","faction_id",faction)
	at_station(spec.capital_station_id)
func qualified_faction(faction: String) -> void:
	var member: RefCounted=g.civilizations.membership();member.has_faction_id=true;member.faction_id=faction;member.switch_cooldown_remaining_s=0.0
	var rep: RefCounted=state.find("reputation_state","faction_id",faction)
	if rep==null:g.civilizations._add_reputation(faction,2600)
	else:rep.reputation=2600
	at_capital(faction)
func task(faction: String,kind: String) -> Dictionary:
	for spec: Dictionary in g.honors.tasks(faction):
		if spec.task_kind==kind:return spec
	return {}
func complete_event(id: String,partial: bool=false) -> RefCounted:
	var row: RefCounted=g.exploration.instance(id);var event: Dictionary=g.exploration.definition(id);var spec: Dictionary={}
	for v: Dictionary in g.rows("exploration_variant_defs"):
		if v.event_id==id and int(v.variant_index)==(2 if partial else 1):spec=v;break
	reset_case(row,spec)
	check(act("survey",row),"honor paid survey "+id)
	# Environmental slowdown remains a real consumer after role shortening.
	# Wait for the paid operation itself instead of assuming its wall duration.
	for _i: int in range(10000):
		if row.operation_kind.is_empty():break
		advance(0.1)
	check(row.operation_kind.is_empty() and row.phase=="surveyed","honor survey completes under the real environmental rate")
	if event.event_kind=="rescue":_rescue(row,spec)
	else:_relic(row,spec)
	check(row.phase=="ready" and row.outcome==("partial" if partial else "full"),"honor actual exploration outcome "+id)
	at_station(event.station_id)
	check(act("claim",row),"honor actual exploration settlement "+id)
	for receipt: RefCounted in state.rows("exploration_claim_state"):
		if receipt.event_id==id and receipt.generation==row.generation:return receipt
	return null
func freight(units: int,returned: bool=false) -> void:
	var id: String="freight_anchor_echo";var spec: Dictionary=g.consignments.definition(id);var row: RefCounted=g.consignments.instance(id)
	if row.phase=="claimed":g.consignments.tick(float(spec.cooldown_s))
	at_station(spec.origin_station_id)
	check(apply("consignment_action",id,units,"dispatch:"+str(row.generation)),"honor dispatch uses real ordinary cargo")
	if returned:check(apply("consignment_action",id,1,"withdraw:"+str(row.generation)),"honor source return is an actual refund")
	else:
		at_station(spec.destination_station_id)
		check(apply("consignment_action",id,1,"deliver:"+str(row.generation)),"honor delivery consumes actual entrusted cargo")
	check(apply("consignment_action",id,1,"claim:"+str(row.generation)),"honor freight creates the actual settlement receipt")
func demolition(partial: bool=false) -> void:
	var id: String="op_demolition";var spec: Dictionary=g.operations.definition(id);var row: RefCounted=g.operations.instance(id)
	if row.cooldown_remaining_s>0.0:g.operations.tick(row.cooldown_remaining_s)
	at_station(spec.station_id)
	check(apply("operation_action",id,1,"accept:"+str(row.generation)),"honor accepts a real demolition generation")
	place(spec.entry_anchor_id)
	check(apply("operation_action",id,1,"start:"+str(row.generation)),"honor paid demolition creates real structures")
	var count: int=0
	for npc: RefCounted in state.rows("npc_state"):
		if not npc.alive or not g.operations.handles(npc.spawn_id):continue
		if partial and count>0:continue
		check(g.damage_npc(npc.npc_instance_id,Vector3(100000,0,0))>0.0,"honor structure loses real HP")
		count+=1
	place(spec.exit_anchor_id)
	check(apply("operation_action",id,1,"exit:"+str(row.generation)),"honor actual demolition extraction")
	at_station(spec.station_id)
	check(apply("operation_action",id,1,"claim:"+str(row.generation)),"honor actual demolition settles once")
func _run() -> void:
	directory=OS.get_environment("XJ_HONORS_V33_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/honors-v33/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped commander world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format18 opens "+store.last_error):get_tree().quit(1);return
	state=store.new_world("文明真实能力考核",3301)
	if not check(state!=null,"all commander coverage seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==99 and state.rows("civilization_command_state").size()==3 and state.rows("civilization_honor_evidence_state").is_empty(),"retained commander groups and new authority initialize without free qualifications")
	check(int(store._records("PRAGMA user_version")[0].values()[0])==24,"real newly created SQLite user version matches format24")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=1000000;g.missions.refresh();g._sync_spawns()
	hull("transport_caravan");fit("module_scanner_beacon_i","utility:0")
	var old: RefCounted=complete_event("exp_mirror_relic")
	advance(0.1)
	for def: Dictionary in g.rows("civilization_command_defs"):
		var faction: String=def.faction_id;qualified_faction(faction)
		var rep_row: RefCounted=state.find("reputation_state","faction_id",faction)
		rep_row.reputation=0
		check(not apply("honor_action",faction,1,"register:unregistered"),"registration rejects standing below its authored rank")
		rep_row.reputation=2600;at_station("station_anchor_port")
		check(not apply("honor_action",faction,1,"register:unregistered"),"registration requires the actual allegiance capital")
		at_capital(faction)
		var foreign_faction: String="faction_route_council" if faction!="faction_route_council" else "faction_deepforge"
		check(not apply("honor_action",foreign_faction,1,"register:unregistered"),"registration cannot be performed for another allegiance")
		var war_id: String=""
		for w: Dictionary in g.rows("civilization_war_defs"):
			if w.faction_id==faction:war_id=w.war_id;break
		check(not apply("start_war",war_id) and g.civilizations.war_reason(war_id).contains("指挥资格"),"rank and donations alone cannot accept a new war "+faction)
		var fingerprint_before: String=full_signature(state,false)
		check(not apply("honor_action",faction,1,"certify:unregistered") and full_signature(state,false)==fingerprint_before,"unregistered certification rejects without wealth or state changes")
		check(apply("honor_action",faction,1,"register:unregistered"),"actual core station registers commander examination "+faction)
		check(not apply("honor_action",faction,1,"register:unregistered"),"stale registration cannot restart examination")
		g.honors.exploration_claimed(old)
		check(g.honors.completed(faction)==0,"already settled pre-registration evidence is not backfilled")
		if factions_checked==0:
			complete_event("exp_echo_rescue",true)
			check(g.honors.progress(task(faction,"rescue").task_id)==0,"partial rescue cannot certify full rescue ability")
			freight(2,true)
			check(g.honors.progress(task(faction,"logistics").task_id)==0,"returned goods cannot fake supplies")
			demolition(true)
			check(g.honors.progress(task(faction,"combat").task_id)==0,"partial demolition is not a full combat examination")
		complete_event("exp_mirror_relic");complete_event("exp_echo_rescue")
		freight(3);check(g.honors.progress(task(faction,"logistics").task_id)==3,"actual smaller deliveries accumulate exact batches")
		freight(3);demolition()
		check(g.honors.completed(faction)==4,"all four distinct actual abilities complete "+faction)
		var rows_before: int=state.rows("civilization_honor_evidence_state").size()
		for receipt: RefCounted in state.rows("exploration_claim_state"):g.honors.exploration_claimed(receipt)
		check(state.rows("civilization_honor_evidence_state").size()==rows_before,"real source tokens cannot be awarded again")
		at_capital(faction)
		var credit: int=state.player().credit;var reputation: int=g.economy.reputation(faction)
		check(apply("honor_action",faction,1,"certify:assessing"),"actual core station certifies all real abilities")
		check(state.player().credit==credit+int(def.reward_credit) and g.economy.reputation(faction)==reputation+int(def.reward_reputation),"certification pays the exact one-time reward")
		credit=state.player().credit
		check(not apply("honor_action",faction,1,"certify:assessing") and state.player().credit==credit,"repeated certification cannot pay again")
		var front: RefCounted=g.get("frontier")
		if front!=null and front.supported():g.inventory.grant(g.inventory.warehouse(g.station()),front.balance.material_id,int(front.balance.supply_units))
		check(g.civilizations.war_reason(war_id).is_empty() and apply("start_war",war_id),"qualification has a real new-war permission consumer")
		check(apply("fleet_command","retreat"),"qualified campaign can use real existing retreat")
		step(g.combat_remaining_s+0.2)
		factions_checked+=1
	var validation: RefCounted=Validation.new()
	check(state.rows("civilization_command_state").filter(func(row: RefCounted)->bool:return row.phase=="certified").size()==3,"changing allegiance retains every earned civilization qualification")
	check(validation.validate(state,store.catalog),"all commander evidence and retained assets validate "+validation.last_error)
	var before: String=full_signature(state)
	if check(store.save(state,"manual",4),"61-group commander proof world saves "+store.last_error):
		var slot: String=saved_slot(4);g.dispose();g=null;state=store.load(slot)
		check(state!=null and full_signature(state)==before,"all 61 groups and proof ledgers restore exactly "+store.last_error)
	evidence_checked=state.rows("civilization_honor_evidence_state").size() if state!=null else 0
	if not OS.get_environment("XJ_HONORS_LEGACY_DATABASE").is_empty():legacy_honors()
	await finish()
func prior_honor_signature(value: XJRuntimeState) -> String:
	var data: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		if table in CAMPAIGN_STATE_ADDITIONS:continue
		if table in ["civilization_command_state","civilization_honor_evidence_state"] or table.begins_with("frontier_"):continue
		var rows: Array=[]
		for row: RefCounted in value.rows(table):
			if not campaign_added_row(table,row):rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func legacy_honors() -> void:
	if g!=null:g.dispose();g=null
	store.close();store=null
	var source: String=OS.get_environment("XJ_HONORS_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.file_exists(source),"closed actual v0.24 fixture is scoped"):return
	var path: String=directory.path_join("legacy.db")
	check(DirAccess.copy_absolute(source,path)==OK,"copy actual legacy escrow and campaign without changing source")
	var faulty: FaultStore=FaultStore.new(path);faulty.failure="migration:021_honors.sql";store=faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==17,"021 failure preserves actual old format17")
	faulty.failure=""
	if not check(store.open(),"021 migration retries successfully "+store.last_error):return
	var slot: Dictionary={}
	for row: Dictionary in store.list_slots():
		if row.slot_kind=="manual" and int(row.slot_index)==2:slot=row;break
	state=store.load(slot.slot_id)
	if not check(state!=null,"actual old activity snapshot loads "+store.last_error):return
	check(state.rows("industry_job_state").size()==3 and state.rows("specialization_research_state")[0].invested_points==3 and state.rows("war_campaign_state")[0].status=="assembling" and state.find("consignment_state","contract_id","freight_anchor_echo").cargo_units==2,"actual old jobs partial study active war and paid cargo exist")
	var before: String=prior_honor_signature(state)
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and prior_honor_signature(state)==before,"failed commander branch preserves all fifty-nine old groups")
	faulty.failure="";state=store.upgrade_content(state)
	if not check(state!=null,"reviewed commander branch succeeds "+store.last_error):return
	check(prior_honor_signature(state)==before,"all fifty-nine assets orders custody campaign identity clock and RNG are unchanged")
	var command: RefCounted=state.find("civilization_command_state","faction_id","faction_route_council")
	var war: RefCounted=state.rows("war_campaign_state")[0]
	check(state.rows("civilization_command_state").size()==3 and state.rows("civilization_honor_evidence_state").is_empty() and command.phase=="unregistered" and command.has_legacy_war_id and command.legacy_war_id==war.war_id and command.legacy_attempt==war.attempt,"upgrade creates only empty examinations and exact active legacy campaign allowance")
	check(store.upgrade_content(state)==state,"commander upgrade is idempotent")
	g=Gameplay.new();g.setup(state,store.catalog)
	check(apply("fleet_command","regroup") and g.civilizations.active_war()!=null,"previously accepted old war continues with real fleet commands")
	check(apply("fleet_command","retreat"),"old campaign can still withdraw normally")
	check(not apply("start_war",war.war_id) and g.civilizations.war_reason(war.war_id).contains("指挥资格"),"legacy exemption cannot accept a new war attempt")
	g.dispose();g=null;state=store.load(slot.slot_id)
	check(state!=null and not store.catalog.table_names.has("civilization_command_defs") and state.rows("civilization_command_state").is_empty() and prior_honor_signature(state)==before,"original manual snapshot remains independent old rules with exact paid progress")
	legacy_checked=true
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"factions":factions_checked,"evidence":evidence_checked,"legacy_checked":legacy_checked,"directory":directory}
	print("HONORS_V33_FINAL_JSON ",JSON.stringify(summary));print("HONORS_V33_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
