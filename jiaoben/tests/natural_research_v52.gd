extends "natural_recovery_v45.gd"
## Actual story/market/research continuation from the normally earned scout
## checkpoint. No story, inventory, reputation, position or clock shortcuts.
var research_earned: bool=false
var source_path: String=""

func _ready() -> void:
	get_tree().set_meta("xj_natural_research_v52_diagnostic",true)
	get_tree().set_meta("xj_natural_recovery_v45_diagnostic",true)
	get_tree().set_meta("xj_natural_growth_v45_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_RESEARCH_V52_DIRECTORY").replace("\\","/")
	var proof_path: String=OS.get_environment("XJ_NATURAL_SCOUT_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-research-v52/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v52-scout-origin-") and not proof_path.contains(".."),"fresh normal research scope"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));source_path=str(origin.database)
	if not check(origin.result=="PASS" and source_path.contains("/jiaoben/tmp/natural-scout-v51/") and not source_path.contains("..") and FileAccess.get_sha256(source_path)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"actual scout outcome is bound to its accepted source"):await finish();return
	check(DirAccess.copy_absolute(source_path,directory.path_join("progress.db"))==OK,"copy earned scout outcome only")
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens science progression"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot):slot=entry;break
	if not check(not slot.is_empty(),"actual scout manual checkpoint exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle();initial_credit=host.state.player().credit
	if not check(initial_credit==int(origin.credit) and host.state.find("growth_grant_receipt_state","task_id","honor_faction_deepforge_scout")!=null,"earned scout ship proof and funds survive continuation"):await finish();return
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	mark("research-earned-origin")
	for mission_id: String in ["story_mirror","story_forge"]:
		var mission: Dictionary=host.gameplay.definition("mission_defs","mission_id",mission_id)
		if not await reach_station(mission.accept_station_id):await finish();return
		for objective: Dictionary in host.gameplay.missions.objectives(mission_id):
			if objective.objective_kind!="deliver":continue
			var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
			var missing: int=maxi(0,int(objective.required_count)-host.gameplay.inventory.count(warehouse,objective.target_item_id,true))
			if missing>0:await command("buy_item",objective.target_item_id,missing)
			if not check(host.gameplay.inventory.count(warehouse,objective.target_item_id,true)>=int(objective.required_count),"normal market supplies story delivery "+mission_id):await finish();return
		if not await drive_mission(mission_id):await finish();return
	var research: Dictionary=host.gameplay.definition("research_defs","research_id","research_hulls")
	if not await reach_station("station_forge_hub"):await finish();return
	for input: Dictionary in host.gameplay.rows("research_inputs"):
		if input.research_id!=research.research_id:continue
		var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
		var missing: int=maxi(0,int(input.quantity)-host.gameplay.inventory.count(warehouse,input.item_id,true))
		if missing>0:await command("buy_item",input.item_id,missing)
	var credit: int=host.state.player().credit
	await command("research","research_hulls")
	research_earned=check(host.gameplay.unlocked("unlock_hulls_advanced") and host.state.player().credit==credit-int(research.required_credit),"real story verification materials and fee unlock advanced hull construction")
	mark("advanced-hull-industry-earned")
	host.ui.show_page("pause");await settle();await command("save","4",1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==4:saved=entry;break
	if not check(not saved.is_empty(),"natural research checkpoint saves"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG reload at research milestone")
	check(FileAccess.get_sha256(source_path)==origin.database_sha256,"earlier scout source remains byte-identical")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"completed":completed,"research_earned":research_earned,"initial_credit":initial_credit,"final_credit":credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"scope":"normal story tasks, market purchases, research and physics; no progression fixtures"}
	print("NATURAL_RESEARCH_V52_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_RESEARCH_V52_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
