extends "owned_fleet_v40.gd"
## Actual v0.30 EXE/PCK provenance is checked before copying its closed fixture.
const Crew=preload("res://runtime/data/crew_validation.gd")
const Fleet=preload("res://runtime/data/fleet_validation.gd")
class FaultStore extends Store:
	var failure: String=""
	func _checkpoint(point: String) -> bool:return point!=failure
func _ready() -> void:
	get_tree().set_meta("xj_fleet_upgrade_v42_diagnostic",true)
	get_tree().create_timer(420.0).timeout.connect(func():check(false,"actual fleet upgrade watchdog");finish())
	run.call_deferred()
func prior(value: XJRuntimeState) -> String:
	var data: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		if table in Crew.TABLES+Fleet.TABLES:continue
		var rows: Array=[]
		for row: RefCounted in value.rows(table):
			# Only the four new products' station listings augment an old group.
			if table=="shop_stock_state" and row.item_def_id.begins_with("module_aux_"):continue
			rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary):return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func run() -> void:
	directory=OS.get_environment("XJ_FLEET_UPGRADE_V42_DIRECTORY").replace("\\","/")
	var source: String=OS.get_environment("XJ_FLEET_LEGACY_DATABASE").replace("\\","/");var provenance: String=OS.get_environment("XJ_FLEET_LEGACY_PROVENANCE").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/fleet-upgrade-v42/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh isolated upgrade target"):await finish();return
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.file_exists(source) and provenance.is_absolute_path() and provenance.contains("/jiaoben/logs/v42-legacy-") and not provenance.contains(".."),"actual old source and provenance stay in test scopes"):await finish();return
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(provenance))
	var digest: String=FileAccess.get_sha256(source)
	if not check(proof.result=="PASS" and int(proof.format)==24 and str(proof.database).replace("\\","/")==source and proof.database_sha256==digest and proof.exe_sha256=="7f1f9b3cf086b70cdb06fd70466897a3f37531fbd96cc04f8b3135755e2381af" and proof.pck_sha256=="b10f63ad76dd7e8a2406bf7cd7fee5ed4419a3162f958c830ee68c4653f71389","closed fixture is tied to the verified actual v0.30 executable and PCK"):await finish();return
	var path: String=directory.path_join("progress.db");check(DirAccess.copy_absolute(source,path)==OK,"old fixture copies without editing original")
	var faulty: FaultStore=FaultStore.new(path);store=faulty;faulty.failure="migration:028_owned_fleet.sql"
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==24 and store._records("SELECT name FROM sqlite_schema WHERE name='fleet_deployment_state'").is_empty(),"028 failure rolls back tables and leaves real format24")
	check(FileAccess.file_exists(directory.path_join("migration-format24-backup.db")),"full old database backed up before migration")
	faulty.failure=""
	if not check(store.open(),"028 retry opens format25 "+store.last_error):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==2:slot=entry;break
	if not check(not slot.is_empty(),"original populated manual slot survives migration"):await finish();return
	state=store.load(slot.slot_id)
	if not check(state!=null,"actual old99-group world restores "+store.last_error):await finish();return
	check(not store.catalog.table_names.has("fleet_balance_defs") and state.rows("crew_member_state").is_empty() and state.rows("fleet_total_state").is_empty(),"old manual endpoint retains old rules and no invented fleet progress")
	check(state.rows("industry_job_state").size()>=3 and state.rows("hire_contract_state").any(func(r: RefCounted):return r.phase=="deployed") and state.rows("trial_state").any(func(r: RefCounted):return r.phase=="accepted") and state.rows("exploration_instance_state").any(func(r: RefCounted):return r.operation_kind=="survey" and r.operation_remaining_s>0),"actual paid queues lease challenge and unfinished survey are present")
	var original: String=prior(state);var slots: String=JSON.stringify(store.list_slots());var content_count: int=int(store._records("SELECT count(*) AS count FROM content_snapshot")[0].count)
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and prior(state)==original and JSON.stringify(store.list_slots())==slots and int(store._records("SELECT count(*) AS count FROM content_snapshot")[0].count)==content_count,"content branch failure preserves all99 original groups RNG pointers and frozen content")
	faulty.failure=""
	var upgraded: XJRuntimeState=store.upgrade_content(state)
	if not check(upgraded!=null,"reviewed actual old content upgrades "+store.last_error):await finish();return
	check(prior(upgraded)==original,"every original99 group is preserved excluding only new product listings")
	check(upgraded.rows("crew_member_state").size()==8 and upgraded.rows("crew_member_state").all(func(r: RefCounted):return r.phase=="available" and r.experience==0 and r.hire_paid_credit==0) and upgraded.rows("fleet_deployment_state").is_empty() and upgraded.rows("auxiliary_bay_state").is_empty(),"new branch adds available recruits without free crew equipment or ships")
	var listings: int=0
	for entry: RefCounted in upgraded.rows("shop_stock_state"):
		if entry.item_def_id.begins_with("module_aux_"):listings+=1
	var expected: int=0
	for entry: Dictionary in store.catalog.rows("station_stock_defs"):
		if str(entry.item_id).begins_with("module_aux_"):expected+=1
	check(listings==expected and listings>0,"upgraded old world can actually obtain every new auxiliary product listing")
	var backups: Array=Array(DirAccess.get_files_at(directory));check(backups.any(func(name: String):return name.begins_with("content-upgrade-") and name.ends_with("-backup.db")),"source-snapshot content backup exists independently of schema backup")
	state=upgraded;g=Gameplay.new();g.setup(state,store.catalog)
	check(g.scenarios.trial_reason("trial_support","withdraw").is_empty() and g.scenarios.fingerprint()==state.find("trial_state","trial_id","trial_support").loadout_signature,"old accepted challenge and paid lease keep their exact compatible binding")
	if not check(store.save(state,"manual",3),"upgraded108-group world seals "+store.last_error):await finish();return
	var before: String=signature();var new_slot: String=""
	for entry: Dictionary in store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==3:new_slot=entry.slot_id;break
	g.dispose();g=null;state=store.load(new_slot)
	check(state!=null and signature()==before,"upgraded108 groups and RNG restore exactly")
	state=store.load(slot.slot_id)
	check(state!=null and prior(state)==original and not store.catalog.table_names.has("fleet_balance_defs"),"old manual slot independently restores original99 groups and rules")
	var reused: XJRuntimeState=store.upgrade_content(state)
	check(reused!=null and int(store._records("SELECT count(*) AS count FROM content_upgrade_record WHERE upgrade_kind='owned_fleet_v1'")[0].count)==1,"repeated source-snapshot upgrade reuses one rules branch without duplicate recruits")
	check(FileAccess.get_sha256(source)==digest,"schema migration content upgrade and rollback leave old input bytes unchanged")
	await finish()
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null;var result: String="PASS" if failures.is_empty() else "FAIL"
	print("FLEET_UPGRADE_V42_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":108}))
	print("FLEET_UPGRADE_V42_RESULT ",result," checks=",checks," failures=",failures.size());await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
