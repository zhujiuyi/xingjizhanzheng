extends "situational_v36.gd"
## Funds, qualification, arrival poses and strategy-time boundaries are explicit
## fixtures. This checks real business/SQL; native suites prove physical play.
func _ready() -> void:
	get_tree().set_meta("xj_campaign_v37_diagnostic",true)
	get_tree().create_timer(600.0).timeout.connect(func():print("CAMPAIGN_V37_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func project(id: String,action: String,quantity: int=1,item: String="") -> bool:
	var accepted: bool=apply("construction_action",id,quantity,action+"|"+item+"|"+g.projects.token(id))
	if not accepted:print("CAMPAIGN_PROJECT_REASON ",g.last_error)
	return accepted
func expedition(id: String,action: String,choice: String="") -> bool:
	var accepted: bool=apply("expedition_action",id,1,action+"|"+choice+"|"+g.expeditions.token(id))
	if not accepted:print("CAMPAIGN_ROUTE_REASON ",g.last_error)
	return accepted
func reset_case(row: D.ExplorationInstanceStateDto,spec: Dictionary) -> void:
	var generation: int=row.generation
	var run: RefCounted=g.expeditions.active()
	var current: RefCounted=g.expeditions.stage(run)
	var bound: bool=current!=null and current.event_id==row.event_id and current.event_generation==generation
	super.reset_case(row,spec)
	# The legacy isolated-case helper creates a new generation. A named variant
	# fixture for an already accepted route must retain its actual generation.
	if bound:row.generation=generation
func _run() -> void:
	directory=OS.get_environment("XJ_CAMPAIGN_V37_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/campaign-v37/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped campaign world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format23 opens "+store.last_error):await finish();return
	state=store.new_world("远征工程批次",3701)
	if not check(state!=null,"new87-group world seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==87 and state.rows("construction_state").size()==3 and state.rows("construction_input_state").size()==18,"finite projects and collection points initialize completely")
	check(state.rows("expedition_route_state").size()==3 and state.rows("expedition_run_state").is_empty() and state.rows("flight_record_state").is_empty(),"no free expedition or invented sortie history")
	check(state.rows("exploration_instance_state").size()==12 and state.rows("tactical_site_state").size()==9 and state.rows("exploration_belt_state").size()==4,"six new exploration places retain tactical and migrating belt systems")
	if OS.get_environment("XJ_CAMPAIGN_UPGRADE_ONLY")=="1":await legacy_campaign();await finish();return
	var signature: String=full_signature(state);g.projects.reason("project_frontier_01","start");g.expeditions.reason("route_relief","start","relief");g.telemetry.export_rows()
	check(full_signature(state)==signature,"browsing changes no funds, state or random stream")
	check(not project("project_frontier_01","start"),"construction refuses absent sovereignty and supplies")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=1000000;g.missions.refresh();g._sync_spawns();hull("transport_caravan");fit("module_scanner_beacon_i","utility:0")
	at_station("station_mirror_hub")
	var credit: int=state.player().credit;var before_token: String=g.expeditions.token("route_relief")
	check(expedition("route_relief","start","relief"),"real route acceptance charges preparation fee")
	var run: RefCounted=g.expeditions.active();var saved_focus: int=run.focus_bonus_bp
	check(state.player().credit==credit-int(g.expeditions.route("route_relief").start_fee_credit),"exact frozen preparation fee paid")
	check(not apply("expedition_action","route_relief",1,"start|relief|"+before_token),"stale vacant route cannot charge twice")
	check(not expedition("route_supply","start","archive"),"one active route blocks overlapping contracts")
	complete_event("exp_theme_frontier_01_rescue")
	if not check(run.phase=="checkpoint" and run.bonus_credit_total>0,"actual rescue claim banks first segment coordination rewards"):await finish();return
	check(g.projects.evidence("project_frontier_01")==2,"full actual event contributes finite construction evidence")
	credit=state.player().credit;var receipt: RefCounted=state.rows("exploration_claim_state")[-1]
	g.expeditions.exploration_claimed(receipt);g.projects.exploration_claimed(receipt)
	check(state.player().credit==credit and g.projects.evidence("project_frontier_01")==2,"replayed event receipt gives neither duplicate money nor proof")
	var period: float=float(g.expeditions.balance.director_period_s)+1.0
	state.snapshot.meta.simulation_tick+=int(ceil(period*g.rule("simulation_hz")));g.expeditions.tick(period)
	check(run.focus_bonus_bp==saved_focus and run.phase=="checkpoint","world rotation leaves accepted reward terms and accumulated progress intact")
	if not preserve(1,"checkpoint and banked segment"):await finish();return
	run=g.expeditions.active()
	check(expedition(run.run_id,"continue","relief"),"actual checkpoint accepts a second valid event")
	complete_event("exp_theme_frontier_02_rescue",true)
	check(run.phase=="checkpoint" and g.projects.evidence("project_frontier_02")==1,"partial rescue retains rewards and contributes partial construction evidence")
	credit=state.player().credit;var insights: int=state.rows("exploration_progress_state")[0].insight_available
	check(expedition(run.run_id,"withdraw"),"checkpoint can end an expedition without erasing prior segments")
	check(run.phase=="withdrawn" and state.player().credit==credit and state.rows("exploration_progress_state")[0].insight_available==insights,"ending preserves actually banked money and research")
	if not preserve(2,"withdrawn expedition"):await finish();return
	# Use existing qualification/war business helpers to create a legal owner;
	# all resulting receipts and former-state checks remain production rules.
	hull("transport_caravan");fit("module_scanner_beacon_i","utility:0");qualified_faction("faction_route_council")
	check(apply("honor_action","faction_route_council",1,"register:unregistered"),"declared qualification fixture registers actual assessments")
	complete_event("exp_mirror_relic");complete_event("exp_echo_rescue");freight(6);demolition();at_capital("faction_route_council")
	check(apply("honor_action","faction_route_council",1,"certify:assessing"),"actual qualification certifies after required recorded results")
	if not prepare("war_council_01"):await finish();return
	capture("war_council_01")
	if not check(g.projects.owned("project_frontier_01"),"real war and reconstruction enable the correct project owner"):await finish();return
	var id: String="project_frontier_01"
	for index: int in range(1,4):
		for input: Dictionary in g.projects.inputs(id,index):
			at_station(input.delivery_station_id);g.inventory.grant(g.inventory.warehouse(g.station()),input.item_id,int(input.required_units))
			var wrong: String="ore_conductive_crystal" if input.item_id=="ore_ferrosilicate" else "ore_ferrosilicate"
			check(not project(id,"deliver",1,wrong),"collection station refuses a wrong material")
			var amount: int=int(input.required_units)
			check(project(id,"deliver",amount-1,input.item_id) and project(id,"deliver",1,input.item_id),"two actual finite deliveries fill one collection gap")
			check(not project(id,"deliver",1,input.item_id),"completed input cannot be over-delivered")
		at_station("station_frontier_01");credit=state.player().credit
		check(project(id,"start"),"actual station pays and begins construction stage "+str(index))
		var row: RefCounted=g.projects.instance(id);var remaining: float=row.work_remaining_s
		check(state.player().credit==credit-int(g.projects.stage(id,index).fee_credit),"construction pays exactly once for the current stage")
		check(project(id,"pause"),"manual project pause accepted")
		g.projects.tick(10.0);check(row.work_remaining_s==remaining,"paused construction preserves work and sunk inputs")
		check(project(id,"resume"),"project resumes without repaying")
		var territory: RefCounted=state.find("territory_state","sector_id",g.projects.definition(id).sector_id)
		territory.has_faction_id=false # Explicit temporary authority-loss fixture; never saved.
		var invested: int=row.paid_credit_total
		g.projects.tick(remaining+1.0)
		check(row.work_remaining_s==remaining and row.stage_index==index and row.paid_credit_total==invested,"authority loss suspends actual work and preserves paid inputs")
		territory.has_faction_id=true
		check(g.projects.owned(id),"restored authority resumes the preserved project")
		state.snapshot.meta.simulation_tick+=int(ceil((remaining+1.0)*g.rule("simulation_hz")));g.projects.tick(remaining+1.0)
		check(row.phase=="completed" if index==3 else row.stage_index==index+1,"construction advances only after real paid work duration")
		if not preserve(3,"construction stage "+str(index)):await finish();return
	check(g.projects.factor("station_frontier_01","manufacture_fee")<1.0 and g.projects.factor("station_frontier_01","repair_fee")<1.0 and g.projects.factor("station_frontier_01","stock_refresh")>1.0,"three completed stages expose distinct actual service consumers")
	# Known mixed-damage layer allocation; no changes to combat settlement.
	var victim: RefCounted=D.ShipStateDto.new();victim.shield=10;victim.armor=10;victim.hull=10
	var resist: Dictionary={"shield":Vector3(0.5,0,0),"armor":Vector3(0,0.5,0),"hull":Vector3.ZERO}
	var contribution: float=g.damage_contribution(victim,Vector3(10,10,0),resist,Vector3(10,0,0))
	check(contribution>0 and contribution<30 and victim.shield==10 and victim.armor==10,"measured ownership allocation is bounded and does not apply duplicate damage")
	if not preserve(3,"completed campaign systems"):await finish();return
	if not OS.get_environment("XJ_CAMPAIGN_LEGACY_DATABASE").is_empty():await legacy_campaign()
	await finish()
func campaign_prior_signature(value: XJRuntimeState) -> String:
	var data: Dictionary={}
	var new_tables: Array[String]=preload("res://runtime/data/campaign_validation.gd").TABLES
	for table: String in XJRuntimeState.TABLES:
		if table in new_tables:continue
		var result: Array=[]
		for row: RefCounted in value.rows(table):
			if table in ["exploration_instance_state","exploration_belt_state"] and str(row.event_id).begins_with("exp_theme_"):continue
			if table=="resource_state" and str(row.node_id).begins_with("exp_theme_"):continue
			if table=="tactical_site_state" and str(row.site_id).begins_with("tac_exp_theme_"):continue
			result.append(Codec.new().encode_row(table,row))
		result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b));data[table]=result
	return JSON.stringify(data)
func legacy_campaign() -> void:
	if g!=null:g.dispose();g=null
	store.close();store=null
	var source: String=OS.get_environment("XJ_CAMPAIGN_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.file_exists(source),"actual v0.28 fixture is closed and test-owned"):return
	var source_hash: String=FileAccess.get_sha256(source);var path: String=directory.path_join("legacy.db")
	check(DirAccess.copy_absolute(source,path)==OK,"old actual package world copied without modifying original")
	var faulty: FaultStore=FaultStore.new(path);store=faulty;faulty.failure="migration:025_campaign.sql"
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==21,"025 failure preserves real old format21")
	faulty.failure="migration:026_metrics.sql"
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==21 and store._records("SELECT name FROM sqlite_schema WHERE name='flight_material_state'").is_empty(),"026 interruption rolls back both pending migrations and preserves old format21")
	check(FileAccess.file_exists(directory.path_join("migration-format21-backup.db")),"actual old database backed up before migration")
	faulty.failure=""
	if not check(store.open(),"appended migrations retry to format23 "+store.last_error):return
	var slot: Dictionary={}
	for item: Dictionary in store.list_slots():
		if item.slot_kind=="manual" and int(item.slot_index)==2:slot=item;break
	if not check(not slot.is_empty(),"old manual snapshot remains available"):return
	state=store.load(slot.slot_id)
	if not check(state!=null,"old real72-group world loads "+store.last_error):return
	check(state.rows("hire_contract_state").size()==1 and not state.rows("resource_intel_state").is_empty() and not state.rows("demand_intel_state").is_empty() and state.rows("industry_job_state").size()>=3,"actual old rent/condition, observations and paid jobs retained")
	var before: String=campaign_prior_signature(state);var slots: String=JSON.stringify(store.list_slots())
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and campaign_prior_signature(state)==before and JSON.stringify(store.list_slots())==slots,"failed campaign branch rolls back old72 groups, RNG and resume pointers")
	faulty.failure=""
	var upgraded: XJRuntimeState=store.upgrade_content(state)
	if not check(upgraded!=null,"reviewed campaign content upgrades "+store.last_error):return
	check(campaign_prior_signature(upgraded)==before,"all old72 groups and RNG retain exact original rows")
	check(upgraded.rows("construction_state").size()==3 and upgraded.rows("expedition_run_state").is_empty() and upgraded.rows("flight_record_state").is_empty(),"new projects start empty and prior activity is not invented")
	state=upgraded;g=Gameplay.new();g.setup(state,store.catalog)
	if not preserve(3,"actual upgraded v0.28 world"):return
	g.dispose();g=null;state=store.load(slot.slot_id)
	check(state!=null and not store.catalog.table_names.has("campaign_balance_defs") and campaign_prior_signature(state)==before,"original manual world keeps independent old rules and exact progress")
	check(FileAccess.get_sha256(source)==source_hash,"upgrade and failure checks leave actual old fixture bytes unchanged")
	legacy_checked=true
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":XJRuntimeState.TABLES.size(),"legacy_checked":legacy_checked,"upgrade_only":OS.get_environment("XJ_CAMPAIGN_UPGRADE_ONLY")=="1"}
	print("CAMPAIGN_V37_FINAL_JSON ",JSON.stringify(summary));print("CAMPAIGN_V37_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
