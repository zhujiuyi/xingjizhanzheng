extends "owned_fleet_v40.gd"
## Closed inputs were produced by actual old EXE/PCKs; no synthetic frozen worlds.
class FaultStore extends Store:
	var failure: String=""
	func _checkpoint(point: String) -> bool:return point!=failure
var completed: Array[int]=[]
func _ready() -> void:
	get_tree().set_meta("xj_legacy_chain_v44_diagnostic",true)
	get_tree().create_timer(1080.0).timeout.connect(func():check(false,"legacy chain watchdog");finish())
	run.call_deferred()
func helper(format: int) -> Dictionary:
	var choices: Dictionary={16:["roles_v32.gd","prior_role_signature"],17:["honors_v33.gd","prior_honor_signature"],18:["frontier_v34.gd","prior_frontier_signature"],19:["hire_v35.gd","prior_hire_signature"],20:["situational_v36.gd","old_signature"],21:["campaign_v37.gd","campaign_prior_signature"],23:["scenarios_upgrade_v39.gd","prior_signature"]}
	var pair: Array=choices[format];var node: Node=(load(get_script().resource_path.get_base_dir().path_join(pair[0])) as Script).new();node.store=store;return {"node":node,"method":pair[1]}
func run() -> void:
	directory=OS.get_environment("XJ_LEGACY_CHAIN_V44_DIRECTORY").replace("\\","/");var index: String=OS.get_environment("XJ_LEGACY_CHAIN_INDEX").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/legacy-chain-v44/") and not directory.contains("..") and index.is_absolute_path() and index.contains("/jiaoben/logs/v44-legacy-input-index-") and not index.contains(".."),"fresh isolated chain and verified input index"):await finish();return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(index))
	if not check(manifest.result=="PASS" and manifest.inputs.size()==7,"seven protected actual old-PCK inputs are present"):await finish();return
	for entry: Dictionary in manifest.inputs:
		var format: int=int(entry.format);var source: String=str(entry.database);var scope: String="format%d" % format
		if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.get_sha256(source)==entry.database_sha256,scope+" source matches retained real-package bytes"):break
		var path: String=directory.path_join(scope+"/progress.db");DirAccess.make_dir_recursive_absolute(path.get_base_dir());check(DirAccess.copy_absolute(source,path)==OK,scope+" copies without writing original")
		var faulty: FaultStore=FaultStore.new(path);store=faulty;faulty.failure="migration:028_owned_fleet.sql"
		check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==format,scope+" final migration fault rolls back all pending schema work")
		check(FileAccess.file_exists(path.get_base_dir().path_join("migration-format%d-backup.db" % format)),scope+" full schema backup exists")
		faulty.failure=""
		if not check(store.open(),scope+" migrates to format25 "+store.last_error):break
		var slot: Dictionary={}
		for value: Dictionary in store.list_slots():
			if value.slot_kind=="manual" and (slot.is_empty() or int(value.slot_index)>int(slot.slot_index)):slot=value
		if not check(not slot.is_empty(),scope+" original manual slot remains"):break
		state=store.load(slot.slot_id)
		if not check(state!=null and store.catalog.content_hash==entry.content_hash,scope+" original content and actual progress restore "+store.last_error):break
		var compare: Dictionary=helper(format);var node: Node=compare.node;var method: String=compare.method;var before: String=node.call(method,state);var slots: String=JSON.stringify(store.list_slots());faulty.failure="content_upgrade"
		check(store.upgrade_content(state)==null and node.call(method,state)==before and JSON.stringify(store.list_slots())==slots,scope+" content fault preserves old rows RNG and slot pointers")
		faulty.failure="";var upgraded: XJRuntimeState=store.upgrade_content(state)
		if not check(upgraded!=null,scope+" reviewed bridge reaches current rules "+store.last_error):node.store=null;node.free();break
		check(node.call(method,upgraded)==before,scope+" every original group and field remains exact under explicit later namespaces")
		check(upgraded.rows("crew_member_state").size()==8 and upgraded.rows("crew_member_state").all(func(row: RefCounted):return row.phase=="available" and row.experience==0 and row.hire_paid_credit==0) and upgraded.rows("fleet_deployment_state").is_empty() and upgraded.rows("auxiliary_bay_state").is_empty(),scope+" new fleet rules create no free personnel or assets")
		state=upgraded
		check(store.save(state,"manual",3),scope+" current108-group branch seals "+store.last_error)
		var full: String=signature();var new_slot: String=""
		for value: Dictionary in store.list_slots():
			if value.slot_kind=="manual" and int(value.slot_index)==3:new_slot=value.slot_id
		state=store.load(new_slot);check(state!=null and signature()==full,scope+" full108 groups and RNG reopen exactly")
		state=store.load(slot.slot_id);check(state!=null and node.call(method,state)==before and store.catalog.content_hash==entry.content_hash,scope+" old manual independently retains old rules and all rows")
		check(FileAccess.get_sha256(source)==entry.database_sha256,scope+" original input remains byte-identical")
		node.store=null;node.free();completed.append(format);state=null;store.close();store=null
	await finish()
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null;var result: String="PASS" if failures.is_empty() else "FAIL"
	print("LEGACY_CHAIN_V44_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"formats":completed,"groups":108}))
	print("LEGACY_CHAIN_V44_RESULT ",result," checks=",checks," failures=",failures.size());await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
