extends "scenarios_v39.gd"
## The source fixture is produced by the verified old EXE/PCK, never by this Store.
func prior_signature(value: XJRuntimeState) -> String:
	var data: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		if table in preload("res://runtime/data/scenario_validation.gd").TABLES or table in FLEET_STATE_ADDITIONS:continue
		var rows: Array=[]
		for row: RefCounted in value.rows(table):
			if table=="shop_stock_state" and str(row.item_def_id).begins_with("module_aux_"):continue
			rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary):return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func _run() -> void:
	directory=OS.get_environment("XJ_SCENARIOS_UPGRADE_V39_DIRECTORY").replace("\\","/")
	var source: String=OS.get_environment("XJ_SCENARIOS_LEGACY_DATABASE").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/scenarios-upgrade-v39/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"upgrade uses fresh isolated target directory"):await finish();return
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.file_exists(source),"closed actual v0.29 fixture is scoped test data"):await finish();return
	var original_hash: String=FileAccess.get_sha256(source);var path: String=directory.path_join("progress.db")
	check(DirAccess.copy_absolute(source,path)==OK,"actual format23 database copied without editing original")
	var faulty: FaultStore=FaultStore.new(path);store=faulty;faulty.failure="migration:027_scenarios.sql"
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==23 and store._records("SELECT name FROM sqlite_schema WHERE name='trial_state'").is_empty(),"027 failure rolls back all new tables and keeps real format23")
	check(FileAccess.file_exists(directory.path_join("migration-format23-backup.db")),"full old database backed up before migration")
	faulty.failure=""
	if not check(store.open(),"027 retry reaches format24 "+store.last_error):await finish();return
	var slot: Dictionary={}
	for candidate: Dictionary in store.list_slots():
		if candidate.slot_kind=="manual" and int(candidate.slot_index)==2:slot=candidate;break
	if not check(not slot.is_empty(),"actual old paid world retains its manual endpoint"):await finish();return
	state=store.load(slot.slot_id)
	if not check(state!=null,"actual frozen v0.29 world loads "+store.last_error):await finish();return
	check(not store.catalog.table_names.has("trial_defs") and state.rows("trial_state").is_empty() and state.rows("telemetry_timing_state").is_empty(),"old manual world remains on old rules without invented scenario state")
	check(state.rows("industry_job_state").size()>=3 and state.rows("mission_state").any(func(m: RefCounted):return m.status in ["active","ready"]) and state.rows("exploration_instance_state").any(func(e: RefCounted):return not e.operation_kind.is_empty()),"actual old paid queues, active mission and unfinished survey are present")
	var before: String=prior_signature(state);var slots: String=JSON.stringify(store.list_slots())
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and prior_signature(state)==before and JSON.stringify(store.list_slots())==slots,"scenario branch failure preserves all87 old groups, RNG and slot pointers")
	faulty.failure=""
	var upgraded: XJRuntimeState=store.upgrade_content(state)
	if not check(upgraded!=null,"reviewed actual v0.29 content upgrades "+store.last_error):await finish();return
	check(prior_signature(upgraded)==before,"new scenario branch preserves every original87 group exactly")
	check(upgraded.rows("trial_state").size()==3 and upgraded.rows("blockade_node_state").size()==12 and upgraded.rows("trial_result_state").is_empty() and upgraded.rows("telemetry_source_state").is_empty(),"new rules create complete empty scenarios without historical rewards or production")
	check(upgraded.rows("activity_record_state").size()>=2 and upgraded.rows("activity_record_state").all(func(r: RefCounted):return r.partial_baseline and r.phase=="active" and r.started_tick==upgraded.snapshot.meta.simulation_tick),"actual active mission and paid exploration receive only a current partial time baseline")
	state=upgraded;g=Gameplay.new();g.setup(state,store.catalog)
	if not preserve(3,"real upgraded99-group world"):await finish();return
	g.dispose();g=null;state=store.load(slot.slot_id)
	check(state!=null and not store.catalog.table_names.has("trial_defs") and prior_signature(state)==before,"original old manual endpoint independently restores exact old rules and all original progress")
	check(FileAccess.get_sha256(source)==original_hash,"migration, rollback and branching leave actual old fixture bytes unchanged")
	await finish()
