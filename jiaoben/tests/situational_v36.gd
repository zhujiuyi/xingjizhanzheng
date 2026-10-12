extends "hire_v35.gd"
## Qualification, money, poses and distant elapsed time are explicit fixtures.
## Physical flight, native controls and audio consumer are checked separately.
var cue_signals: int = 0
func _ready() -> void:
	get_tree().set_meta("xj_situational_v36_diagnostic",true)
	if OS.get_environment("XJ_PCK_MANIFEST_ONLY")=="1":
		var probe: Node=(load(get_script().resource_path.get_base_dir().path_join("pck_manifest_v36.gd")) as Script).new()
		get_tree().root.add_child(probe)
		return
	get_tree().create_timer(420.0).timeout.connect(func():print("SITUATIONAL_V36_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func _run() -> void:
	directory=OS.get_environment("XJ_SITUATIONAL_V36_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/situational-v36/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped observation world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format21 opens "+store.last_error):await finish();return
	state=store.new_world("状态与情报",3601)
	if not check(state!=null,"all72 typed groups seal "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==83 and state.rows("resource_intel_state").is_empty() and state.rows("demand_intel_state").is_empty(),"new players receive no remote measurements")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	g.missions.refresh();g._sync_spawns();state.player().credit=1000000
	hull("frigate_kestrel")
	var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port")
	place(home.station_anchor_id,home.station_id)
	var before: String=full_signature(state)
	check(g.situational.resource_text("node_echo_ferrosilicate").contains("未测量"),"unvisited mineral quantity is unknown")
	check(g.situational.demand_text("demand_station_echo_refinery").contains("未核实"),"unvisited demand is not treated as a live quote")
	check(full_signature(state)==before,"browsing never measures or consumes random state")
	g.situational.observe()
	var home_demand: String="demand_station_anchor_port"
	check(g.situational.demand_reading(home_demand).live and state.find("demand_intel_state","demand_id",home_demand)!=null,"actually docked station records its live demand")
	var node_id: String="node_echo_ferrosilicate"
	var anchor: String=g.definition("resource_node_locations","node_id",node_id).anchor_id
	place(anchor);g.situational.observe()
	var row: RefCounted=state.find("resource_intel_state","node_id",node_id)
	if not check(row!=null and g.situational.resource_reading(node_id).live,"local in-range measurement records the node"):await finish();return
	var measured: int=row.remaining_units
	check(row.site_id==g.spatial_site("ship",state.ship().ship_instance_id),"measurement binds actual astronomical locality")
	g.situational.spatial_active=false
	var observed_tick: int=row.observed_tick
	g.situational.observe()
	check(not g.situational.resource_reading(node_id).live and row.observed_tick==observed_tick and g.situational.cues().is_empty(),"inactive strategic transit cannot measure the origin or expose local warnings")
	g.situational.spatial_active=true
	place(home.station_anchor_id,home.station_id)
	state.find("resource_state","node_id",node_id).remaining_units-=1 # Isolated remote-depletion fixture.
	check(not g.situational.resource_reading(node_id).live and int(g.situational.resource_reading(node_id).remaining_units)==measured,"remote view preserves the previous quantity instead of reading changed live state")
	before=full_signature(state);g.situational.resource_text(node_id);g.resource_intel.sources("ore_ferrosilicate")
	check(full_signature(state)==before,"source lookup also leaves observations unchanged")
	state.snapshot.meta.simulation_tick+=int(ceil((float(g.situational.balance.resource_fresh_s)+1.0)*g.rule("simulation_hz")))
	check(g.situational.resource_text(node_id).contains("已过期") and row.remaining_units==measured,"expired resource is explicitly stale and retains its last measurement")
	var age_before: float=g.situational.resource_reading(node_id).age_s
	for index: int in range(20):g.situational.resource_text(node_id)
	check(g.situational.resource_reading(node_id).age_s==age_before,"rendering/paused reads do not advance world time")
	if not preserve(1,"demand and stale resource observations"):await finish();return
	check(state.find("resource_intel_state","node_id",node_id).remaining_units==measured and g.situational.resource_text(node_id).contains("已过期"),"reopen retains quantity and age rather than manufacturing current intelligence")
	place(anchor);g.situational.observe()
	check(state.find("resource_intel_state","node_id",node_id).remaining_units==measured-1 and g.situational.resource_reading(node_id).live,"returning to the node performs a new actual local measurement")
	var scan: Dictionary=g.situational.equipment("scan_signal")
	check(str(scan.missing).is_empty() and str(scan.note).contains("基础扫描"),"built-in scanner is usable without falsely requiring a module")
	var mining: Dictionary=g.situational.equipment("collect",node_id)
	check(not str(mining.missing).is_empty(),"bare hull reports its missing compatible mining head")
	for node: Dictionary in g.rows("resource_node_defs"):
		if g.definition("item_defs","item_id",node.item_id).item_type!="ore":
			check(g.situational.equipment("collect",node.node_id).note.contains("无需矿头"),"component recovery correctly requires no mining head");break
	check(not store.save(_invalid_future_observation(),"manual",3),"runtime and seal validation reject future measurement ticks")
	place(home.station_anchor_id,home.station_id);g.situational.observe()
	var demand: RefCounted=state.find("demand_intel_state","demand_id",home_demand)
	place(anchor)
	state.snapshot.meta.simulation_tick+=int(ceil((float(g.situational.balance.demand_fresh_s)+1.0)*g.rule("simulation_hz")))
	check(g.situational.demand_text(home_demand).contains("已过期") and demand.remaining_units>0,"remote demand ages independently and remains a reference quote")
	if not preserve(2,"expired demand and resource"):await finish();return
	if not OS.get_environment("XJ_SITUATIONAL_LEGACY_DATABASE").is_empty():await legacy_situational()
	await finish()
func _invalid_future_observation() -> XJRuntimeState:
	var candidate: XJRuntimeState=store.clone_state(state)
	candidate.rows("resource_intel_state")[0].observed_tick=candidate.snapshot.meta.simulation_tick+1
	return candidate
func old_signature(value: XJRuntimeState) -> String:
	var copy: XJRuntimeState=store.clone_state(value)
	copy.rows("resource_intel_state").clear();copy.rows("demand_intel_state").clear()
	return full_signature(copy)
func legacy_situational() -> void:
	if g!=null:g.dispose();g=null
	store.close();store=null
	var source: String=OS.get_environment("XJ_SITUATIONAL_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.file_exists(source),"real v0.27 fixture is closed and test-owned"):return
	var original: String=FileAccess.get_sha256(source);var path: String=directory.path_join("legacy.db")
	check(DirAccess.copy_absolute(source,path)==OK,"legacy source copied without editing original")
	var faulty: FaultStore=FaultStore.new(path);faulty.failure="migration:024_situational.sql";store=faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==20,"024 migration failure retains real format20")
	check(FileAccess.file_exists(directory.path_join("migration-format20-backup.db")),"old database backed up before appended migration")
	faulty.failure=""
	if not check(store.open(),"024 retries to format21 "+store.last_error):return
	var slot: Dictionary={}
	for entry: Dictionary in store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==2:slot=entry;break
	if not check(not slot.is_empty(),"real old paid manual snapshot remains available"):return
	state=store.load(slot.slot_id)
	if not check(state!=null,"old actual hire snapshot loads "+store.last_error):return
	check(state.rows("hire_contract_state").size()>0 and state.rows("industry_job_state").size()>=3,"legacy fixture contains a paid rental and industrial progress")
	var before: String=old_signature(state);var slots: String=JSON.stringify(store.list_slots())
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and old_signature(state)==before and JSON.stringify(store.list_slots())==slots,"failed content branch preserves70 groups/RNG and resume pointers")
	faulty.failure=""
	var upgraded: XJRuntimeState=store.upgrade_content(state)
	if not check(upgraded!=null,"reviewed additive situational content upgrades "+store.last_error):return
	check(old_signature(upgraded)==before and upgraded.rows("resource_intel_state").is_empty() and upgraded.rows("demand_intel_state").is_empty(),"all70 old groups and RNG survive; old visits do not become measurements")
	state=upgraded;g=Gameplay.new();g.setup(state,store.catalog)
	if not preserve(3,"upgraded paid world"):return
	g.dispose();g=null;state=store.load(slot.slot_id)
	check(state!=null and not store.catalog.table_names.has("situational_balance_defs") and old_signature(state)==before,"old manual snapshot retains independent original rules")
	check(FileAccess.get_sha256(source)==original,"all upgrade failures and success leave fixture bytes unchanged")
	legacy_checked=true
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":XJRuntimeState.TABLES.size(),"legacy_checked":legacy_checked}
	print("SITUATIONAL_V36_FINAL_JSON ",JSON.stringify(summary));print("SITUATIONAL_V36_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
