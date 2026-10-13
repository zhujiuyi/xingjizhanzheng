extends Node
const Store=preload("res://runtime/data/store.gd")
const Gameplay=preload("res://runtime/gameplay.gd")
const Codec=preload("res://runtime/data/codec.gd")
const Signature=preload("snapshot_signature.gd")
class FaultStore extends Store:
	var failure: String=""
	func _checkpoint(point: String) -> bool:return point!=failure
var checks: int=0
var failures: Array[String]=[]
var directory: String=""
var store: Store
var state: XJRuntimeState
var game: RefCounted
var source: String=""
var digest: String=""

func check(value: bool,label: String) -> bool:
	checks+=1;print(("PASS " if value else "FAIL ")+label)
	if not value:failures.append(label)
	return value

func _ready() -> void:
	get_tree().set_meta("xj_march_upgrade_v49_diagnostic",true)
	get_tree().create_timer(420.0).timeout.connect(func():check(false,"march upgrade watchdog");finish())
	run.call_deferred()

func prior(value: XJRuntimeState) -> String:
	var rows: Dictionary={}
	for table: String in XJRuntimeState.TABLES.slice(0,108):
		rows[table]=[]
		for row: RefCounted in value.rows(table):rows[table].append(Codec.new().encode_row(table,row))
	return Signature.canonical(rows)

func manual_slots() -> String:
	var rows: Array=[]
	for slot: Dictionary in store.list_slots():
		if slot.slot_kind=="manual":rows.append(slot)
	return JSON.stringify(rows)

func run() -> void:
	directory=OS.get_environment("XJ_MARCH_UPGRADE_V49_DIRECTORY").replace("\\","/")
	var proof_path: String=OS.get_environment("XJ_MARCH_LEGACY_PROVENANCE").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/march-upgrade-v49/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v49-march-legacy-source-") and not proof_path.contains(".."),"fresh upgrade scope and bounded source proof"):await finish();return
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(proof_path))
	source=str(proof.database);digest=str(proof.database_sha256)
	if not check(proof.result=="PASS" and source.contains("/jiaoben/tmp/frontier-v34/") and not source.contains("..") and FileAccess.get_sha256(source)==digest and FileAccess.get_sha256(proof.source_report)==proof.source_report_sha256,"actual v0.31 fixture and acceptance proof retain exact bytes"):await finish();return
	check(DirAccess.copy_absolute(source,directory.path_join("progress.db"))==OK,"copy closed legacy fixture only")
	var faulty: FaultStore=FaultStore.new(directory.path_join("progress.db"));store=faulty;faulty.failure="migration:029_march.sql"
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==25,"new schema fault rolls back to original format25")
	check(FileAccess.file_exists(directory.path_join("migration-format25-backup.db")),"full old-format backup is created first")
	faulty.failure=""
	if not check(store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==26,"format26 opens after migration retry"):await finish();return
	var old_slot: Dictionary={}
	for slot: Dictionary in store.list_slots():
		if slot.slot_kind=="manual" and int(slot.slot_index)==0:old_slot=slot;break
	if not check(not old_slot.is_empty(),"original manual scouting slot is retained"):await finish();return
	state=store.load(old_slot.slot_id)
	if not check(state!=null,"old rule world loads "+store.last_error):await finish();return
	check(not store.catalog.table_names.has("march_balance_defs") and state.rows("march_state").is_empty(),"old manual retains its v0.31 rules")
	var war: RefCounted=state.find("war_campaign_state","war_id","war_council_01")
	var preparation: RefCounted=state.find("frontier_campaign_state","war_id","war_council_01")
	check(war!=null and war.status=="assembling" and preparation.survey_paid and preparation.survey_remaining_s>0.0,"actual old paid active war is present")
	var original: String=prior(state);var slots: String=manual_slots();var before: int=int(store._records("SELECT count(*) AS n FROM content_snapshot")[0].n)
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and prior(state)==original and manual_slots()==slots and int(store._records("SELECT count(*) AS n FROM content_snapshot")[0].n)==before,"content branch failure preserves all108 original groups RNG and manual pointers")
	faulty.failure=""
	var upgraded: XJRuntimeState=store.upgrade_content(state)
	if not check(upgraded!=null,"reviewed fleet bridge reaches march rules "+store.last_error):await finish();return
	check(prior(upgraded)==original and manual_slots()==slots,"new rule branch retains every original field and manual save")
	check(upgraded.rows("march_state").is_empty() and upgraded.rows("growth_grant_receipt_state").is_empty(),"upgrade creates neither retroactive fleets nor automatic payouts")
	state=upgraded;game=Gameplay.new();game.setup(state,store.catalog)
	check(game.march.supported() and not game.march.holds_campaign(game.civilizations.active_war()),"already accepted old war continues its original preparation")
	var paid_remaining: float=state.find("frontier_campaign_state","war_id","war_council_01").survey_remaining_s
	game.tick(1.0/game.rule("simulation_hz"))
	check(state.find("frontier_campaign_state","war_id","war_council_01").survey_remaining_s<paid_remaining and state.rows("march_state").is_empty(),"old paid survey advances without teleporting in new reinforcements")
	if not check(store.save(state,"auto",1),"upgraded114-group world saves "+store.last_error):await finish();return
	var snapshot: String=state.snapshot.meta.snapshot_id;var expected: String=Signature.saved(store,snapshot)
	game.dispose();game=null;state=store.load("snapshot:"+snapshot)
	check(state!=null and Signature.runtime(state)==expected,"all114 groups and RNG restore after upgrading")
	check(manual_slots()==slots,"new saves still preserve all old manual pointers")
	state=store.load(old_slot.slot_id)
	check(state!=null and prior(state)==original and not store.catalog.table_names.has("march_balance_defs"),"original paid manual remains independently loadable")
	var reused: XJRuntimeState=store.upgrade_content(state)
	check(reused!=null and int(store._records("SELECT count(*) AS n FROM content_upgrade_record WHERE upgrade_kind='march_v1'")[0].n)==1,"repeated source upgrade reuses one rules branch")
	check(FileAccess.get_sha256(source)==digest,"original actual v0.31 database remains byte-identical")
	await finish()

func finish() -> void:
	if game!=null:game.dispose();game=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"groups":XJRuntimeState.TABLES.size(),"directory":directory,"source":source,"source_sha256":digest}
	print("MARCH_UPGRADE_V49_FINAL_JSON ",JSON.stringify(summary));print("MARCH_UPGRADE_V49_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
