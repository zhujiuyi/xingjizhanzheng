extends "exploration_v27.gd"
## Qualified ship/unlocks and direct poses isolate business invariants; native suite proves motion/hits.
func _ready() -> void:
	get_tree().set_meta("xj_operations_v30_diagnostic",true)
	get_tree().create_timer(360.0).timeout.connect(func(): print("OPERATIONS_V30_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func command(verb: String, id: String, gen: String = "") -> bool:
	return g.act("operation_action",id,1,verb+":"+(str(g.operations.instance(id).generation) if gen.is_empty() else gen)).phase == T.ActionPhase.APPLIED
func station(id: String) -> void:
	var spec: Dictionary = g.operations.definition(id); var home: Dictionary = g.definition("station_defs","station_id",spec.station_id)
	place(home.station_anchor_id,home.station_id)
func op_fingerprint(value: XJRuntimeState, skip_new: bool = false) -> String:
	var data: Dictionary = {}
	var compared: Array[String]=XJRuntimeState.TABLES.slice(0,52) if skip_new else XJRuntimeState.TABLES
	for table: String in compared:
		if skip_new and table == "operation_state": continue
		var rows: Array = []
		for row: RefCounted in value.rows(table):
			if skip_new:
				if table in ["exploration_instance_state","exploration_belt_state"] and str(row.event_id).begins_with("exp_theme_"):continue
				if table=="resource_state" and str(row.node_id).begins_with("exp_theme_"):continue
				if table=="tactical_site_state" and str(row.site_id).begins_with("tac_exp_theme_"):continue
				if table=="shop_stock_state" and row.item_def_id in ["module_spec_burst","module_spec_sustain","module_spec_range"]:continue
			rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func _run() -> void:
	directory=OS.get_environment("XJ_OPERATIONS_V30_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/operations-v30/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh isolated operation world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format15 opens "+store.last_error):get_tree().quit(1);return
	state=store.new_world("拆除与突破",3001)
	if not check(state != null,"new relational operation world "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(state.rows("operation_state").size()==2 and not state.rows("npc_state").any(func(n: RefCounted)->bool:return n.spawn_id.begins_with("op_")),"two locked operations never spawn free generators")
	check(not command("accept","op_demolition"),"locked operation refuses acceptance")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	g._sync_spawns()
	state.player().credit=1000000
	var home: Dictionary=g.definition("station_defs","station_id",g.operations.definition("op_breakthrough").station_id)
	var ship: RefCounted=g.inventory.create_ship("transport_caravan",home.station_id)
	if not check(ship != null,"qualified transport creates real holds"):await finish();return
	state.player().controlled_ship_id=ship.ship_instance_id
	_demolition();_breakthrough()
	var validation: Validation=Validation.new()
	check(validation.validate(state,store.catalog),"all fifty-three groups validate "+validation.last_error)
	if check(store.save(state,"manual",0),"partial results and paid rewards seal "+store.last_error):
		var before: String=op_fingerprint(state);var slot: Dictionary
		for row: Dictionary in store.list_slots():
			if row.slot_kind=="manual":slot=row;break
		g.dispose();g=null;state=store.load(slot.slot_id);g=Gameplay.new();g.setup(state,store.catalog)
		check(op_fingerprint(state)==before,"all fifty-three groups restore exactly")
	if not OS.get_environment("XJ_OPERATIONS_LEGACY_DATABASE").is_empty():_legacy()
	await finish()
func _demolition() -> void:
	var id: String="op_demolition";var spec: Dictionary=g.operations.definition(id);var row: RefCounted=g.operations.instance(id)
	station(id);check(command("accept",id),"station accepts demolition")
	check(not command("accept",id,"0"),"stale generation rejected")
	check(not command("start",id),"cannot remotely start")
	place(spec.entry_anchor_id);check(command("start",id),"actual entry starts demolition")
	var structures: Array[RefCounted]=[]
	for npc: RefCounted in state.rows("npc_state"):
		if g.operations.handles(npc.spawn_id):structures.append(npc)
	check(structures.size()==2 and g.operations.thrust_ratio(state.ship().ship_instance_id)<1.0,"two actual HP structures apply bounded field")
	var amount: float=g.damage_npc(structures[0].npc_instance_id,Vector3(100000,0,0))
	check(amount>0.0 and not structures[0].alive and row.completed_units==1,"real HP destruction advances one objective")
	check(not command("exit",id),"cannot remotely finish at entry")
	place(spec.exit_anchor_id);check(command("exit",id),"one generator permits partial exit")
	check(row.phase=="ready" and row.completed_units==1 and structures[1].alive and g.tactics.remaining(spec.tactical_site_id)>0,"partial win keeps remaining structure and enemies alive")
	check(g.operations.thrust_ratio(state.ship().ship_instance_id)==1.0,"ended operation stops its field")
	station(id);var credit: int=state.player().credit
	check(command("claim",id) and state.player().credit==credit+int(spec.credit_per_unit),"partial reward pays exact completed fraction")
	credit=state.player().credit;check(not command("claim",id) and state.player().credit==credit,"duplicate claim rejected")
	check(not command("accept",id),"cooldown prevents free repeat")
	row.cooldown_remaining_s=0.0 # Explicit turn boundary fixture, not elapsed-world evidence.
	check(command("accept",id),"next generation is available after cooldown")
	place(spec.entry_anchor_id);check(command("start",id),"next generation creates fresh physical objectives")
	for npc: RefCounted in state.rows("npc_state"):
		if g.operations.handles(npc.spawn_id):g.damage_npc(npc.npc_instance_id,Vector3(100000,0,0))
	place(spec.exit_anchor_id);check(command("exit",id) and row.completed_units==int(spec.target_units),"full demolition succeeds without clearing enemy fleet")
	station(id);check(command("claim",id),"full demolition claim")
func _breakthrough() -> void:
	var id: String="op_breakthrough";var spec: Dictionary=g.operations.definition(id);var row: RefCounted=g.operations.instance(id)
	station(id);check(command("accept",id),"station accepts breakthrough")
	place(spec.entry_anchor_id);var used: float=g.metrics(state.ship()).cargo_used_l
	check(command("start",id) and row.loaded_units==3,"qualified large hold loads real three batches")
	check(g.metrics(state.ship()).cargo_used_l==used+row.cargo_units*float(spec.cargo_volume_l) and g.metrics(state.ship()).payload_mass_kg>=row.cargo_units*float(spec.cargo_mass_kg),"objective cargo consumes real volume and mass")
	var saved: String=op_fingerprint(state)
	check(store.save(state,"manual",1),"active cargo snapshot seals "+store.last_error)
	var slot: Dictionary
	for candidate: Dictionary in store.list_slots():
		if candidate.slot_kind=="manual" and int(candidate.slot_index)==1:slot=candidate;break
	g.dispose();g=null;state=store.load(slot.slot_id);g=Gameplay.new();g.setup(state,store.catalog);row=g.operations.instance(id)
	check(op_fingerprint(state)==saved and row.cargo_units==3,"active cargo and remaining time restore exactly")
	var count: int=row.cargo_units;g.damage_ship(Vector3(20,0,0))
	check(row.cargo_units==count and row.damage_debt_hp==0.0,"ordinary unexposed hits preserve cargo")
	g.operations.boosted();check(row.exposure_remaining_s==float(spec.exposure_duration_s) and g.operations.detection_range()==float(spec.exposure_detection_m),"boost exposes cargo and increases actual detection budget")
	g.damage_ship(Vector3(120,0,0));check(row.cargo_units<count and row.lost_units>0,"exposed actual HP damage destroys finite cargo")
	if row.cargo_units>1:check(command("jettison",id) and row.jettisoned_units==1,"jettison releases one real batch")
	place(spec.exit_anchor_id);check(command("exit",id) and row.phase=="ready" and row.completed_units<3,"actual exit delivers surviving partial cargo")
	check(g.operations.cargo(state.ship().ship_instance_id).volume==0.0 and row.loaded_units==row.completed_units+row.lost_units+row.jettisoned_units,"delivery conserves cargo and releases hold")
	station(id);var credit: int=state.player().credit;var expected: int=row.completed_units*int(spec.credit_per_unit)
	check(command("claim",id) and state.player().credit==credit+expected,"surviving cargo pays exact amount")
	row.cooldown_remaining_s=0.0;check(command("accept",id),"new transport generation after cooldown fixture")
	place(spec.entry_anchor_id);check(command("start",id),"new cargo start")
	row.remaining_s=0.05;g.operations.tick(0.1)
	check(row.phase=="withdrawn" and row.cargo_units==0 and row.completed_units==0 and row.lost_units==row.loaded_units,"timeout has explicit failure and no undelivered reward")
	row.cooldown_remaining_s=0.0;station(id);check(command("accept",id),"repeat after failure")
	place(spec.entry_anchor_id);check(command("start",id),"start before leaving")
	station(id);g.operations.tick(0.1)
	check(row.phase=="withdrawn" and row.cargo_units==0 and not command("claim",id),"leaving site forfeits undelivered cargo")
func _legacy() -> void:
	g.dispose();g=null;store.close();store=null
	var source: String=OS.get_environment("XJ_OPERATIONS_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/") and FileAccess.file_exists(source),"old actual PCK fixture scoped"):return
	var path: String=directory.path_join("legacy.db");check(DirAccess.copy_absolute(source,path)==OK,"copy closed format14 fixture")
	var faulty: FaultStore=FaultStore.new(path);faulty.failure="migration:018_operations.sql";store=faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==14,"018 failure rolls back original format14")
	faulty.failure="";if not check(store.open(),"migration retry reaches format15"):return
	var slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind=="manual":slot=row;break
	state=store.load(slot.slot_id)
	if not check(state != null,"old manual loads original frozen v0.13"):return
	check(state.rows("industry_job_state").size()==4 and state.rows("drone_bay_state").size()>0,"actual previous PCK retains paid running/queued/cancelled orders and installed drone stock")
	var before: String=op_fingerprint(state,true)
	faulty.failure="content_upgrade";check(store.upgrade_content(state)==null and op_fingerprint(state,true)==before,"failed content branch preserves old assets and RNG")
	faulty.failure="";state=store.upgrade_content(state)
	if not check(state != null,"reviewed operation branch "+store.last_error):return
	check(op_fingerprint(state,true)==before and state.rows("operation_state").size()==2,"all fifty-two old groups preserved; only new objectives added")
	check(store.upgrade_content(state)==state,"upgrade idempotent")
	state=store.load(slot.slot_id);check(state != null and state.rows("operation_state").is_empty() and not store.catalog.table_names.has("operation_defs"),"old manual remains independently loadable")
func finish() -> void:
	if g != null:g.dispose();g=null
	if store != null:store.close();store=null
	state=null
	print("OPERATIONS_V30_FINAL_JSON ",JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"cases":cases,"directory":directory}))
	print("OPERATIONS_V30_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
