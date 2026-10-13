extends "owned_fleet_v40.gd"
## Closed test-owned natural and legacy-branch databases only. No personal saves.
const Sig=preload("snapshot_signature.gd")
class FaultStore extends Store:
	var reject: String=""
	func _checkpoint(point: String) -> bool:return point!=reject
var results: Array[Dictionary]=[]
func _ready() -> void:
	get_tree().set_meta("xj_retention_v48_diagnostic",true);run.call_deferred()
func count_snapshots() -> int:
	return int(store._records("SELECT COUNT(*) AS n FROM save_snapshot")[0].n)
func pinned_payloads() -> Dictionary:
	var ids: Dictionary={}
	for slot: Dictionary in store.list_slots():
		if slot.slot_kind=="manual":ids[str(slot.current_snapshot_id)]=true
	for row: Dictionary in store._records("SELECT initial_snapshot_id AS id FROM world_initialization_grant UNION SELECT source_snapshot_id FROM content_upgrade_record UNION SELECT upgraded_snapshot_id FROM content_upgrade_record"):
		ids[str(row.id)]=true
	var result: Dictionary={}
	for id: String in ids:result[id]=Sig.saved(store,id)
	return result
func run() -> void:
	directory=OS.get_environment("XJ_RETENTION_V48_DIRECTORY").replace("\\","/")
	var index: String=OS.get_environment("XJ_RETENTION_V48_INPUTS").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/retention-v48/") and not directory.contains("..") and index.is_absolute_path() and index.ends_with("/jiaoben/logs/v48-retention-inputs.json") and not index.contains(".."),"fresh retention scope and fixed test input registry"):await finish();return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(index))
	for i: int in range(manifest.inputs.size()):
		var entry: Dictionary=manifest.inputs[i];var source: String=str(entry.path)
		if not check(source.contains("/jiaoben/tmp/") and not source.contains("..") and FileAccess.get_sha256(source)==entry.sha256,"closed input identity matches "+str(i)):break
		var path: String=directory.path_join("case%d/progress.db" % i);DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if not check(DirAccess.copy_absolute(source,path)==OK,"copy preserves source "+str(i)):break
		var faulty: FaultStore=FaultStore.new(path);store=faulty
		if not check(store.open(),"open real current and historical branch database "+store.last_error):break
		var selected: Dictionary={}
		for slot: Dictionary in store.list_slots():
			if slot.slot_kind=="manual" and (selected.is_empty() or int(slot.slot_index)>int(selected.slot_index)):selected=slot
		state=store.load(selected.slot_id)
		if not check(state!=null,"load actual manual endpoint "+store.last_error):break
		var pinned: Dictionary=pinned_payloads();var initial: int=count_snapshots();var slots: String=JSON.stringify(store.list_slots())
		faulty.reject="pointer"
		check(not store.save(state,"auto",0) and count_snapshots()==initial and JSON.stringify(store.list_slots())==slots,"failed save neither publishes nor prunes snapshots")
		faulty.reject=""
		check(store.save(state,"auto",0) and store.last_retention_error.is_empty(),"ordinary durable save runs successful separate retention "+store.last_error)
		var retained: int=count_snapshots()
		check(retained<=store.list_slots().size()+pinned.size()+5,"unreferenced history is bounded while durable roots remain")
		if i==0:check(retained*2<initial,"long natural-play sample loses obsolete snapshots")
		for id: String in pinned:
			check(not store._records("SELECT snapshot_id FROM save_snapshot WHERE snapshot_id=?",[id]).is_empty() and Sig.saved(store,id)==pinned[id],"manual initial or upgrade endpoint remains exact "+id)
		check(store._records("PRAGMA foreign_key_check").is_empty(),"retention preserves foreign keys and lineage")
		var count_before: int=count_snapshots();faulty.reject="retention"
		for attempt: int in range(5):
			check(store.save(state,"auto",0) and not store.last_retention_error.is_empty() and store.last_error.is_empty() and store.phase=="READY","cleanup interruption cannot revoke committed save "+str(attempt))
		check(count_snapshots()==count_before+5,"interrupted cleanup transaction rolls back all attempted deletes")
		var latest: String=state.snapshot.meta.snapshot_id
		check(str(store._records("SELECT resume_snapshot_id FROM runtime_session WHERE world_id=?",[state.world_id])[0].resume_snapshot_id)==latest,"resume pointer is latest committed save despite cleanup failure")
		faulty.reject=""
		check(store.save(state,"auto",0) and store.last_retention_error.is_empty(),"next successful save retries retention")
		var after_retry: int=count_snapshots()
		check(after_retry<count_before+5,"retry reclaims deferred unreferenced snapshots")
		var pages_before: int=int(store._records("PRAGMA page_count")[0].values()[0])
		for repeat: int in range(8):
			if not check(store.save(state,"auto",repeat%3),"steady ordinary save "+str(repeat)):break
		var pages_after: int=int(store._records("PRAGMA page_count")[0].values()[0])
		var free: int=int(store._records("PRAGMA freelist_count")[0].values()[0])
		check(count_snapshots()<=store.list_slots().size()+pinned.size()+5,"continued play keeps bounded unreferenced history")
		if i==0:check(pages_after<=pages_before and free>0,"existing pages are reused rather than growing the large natural database")
		for slot: Dictionary in store.list_slots():
			if slot.slot_kind!="manual":continue
			var expected: String=Sig.saved(store,slot.current_snapshot_id)
			state=store.load(slot.slot_id)
			check(state!=null and Sig.runtime(state)==expected,"each old and current manual slot independently restores all authoritative groups")
		if i==1:
			var previous_world: String=state.world_id;var old_roots: Dictionary=pinned_payloads()
			var second: XJRuntimeState=store.new_world("保留策略第二世界",4802)
			check(second!=null and second.world_id!=previous_world and store.save(second,"auto",0),"new world's ordinary save also maintains old-world roots")
			for id: String in old_roots:check(Sig.saved(store,id)==old_roots[id],"saving another world preserves prior manual and upgrade payload "+id)
			state=store.load(selected.slot_id)
			check(state!=null and state.world_id==previous_world,"old world remains selectable after another world's cleanup")
		check(store._records("PRAGMA foreign_key_check").is_empty() and str(store._records("PRAGMA integrity_check")[0].values()[0])=="ok","post-retention integrity and references remain valid")
		check(FileAccess.get_sha256(source)==entry.sha256,"original input bytes unchanged")
		results.append({"initial_snapshots":initial,"after_first_cleanup":retained,"final_snapshots":count_snapshots(),"free_pages":free,"pages_before":pages_before,"pages_after":pages_after})
		state=null;store.close();store=null
	await finish()
func finish() -> void:
	if store!=null:store.close();store=null
	state=null;var result: String="PASS" if failures.is_empty() else "FAIL"
	print("RETENTION_V48_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"cases":results}))
	print("RETENTION_V48_RESULT ",result," checks=",checks," failures=",failures.size());await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
