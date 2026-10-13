extends "natural_recovery_v45.gd"
## Resumes the real citizenship checkpoint whose original run failed only an
## incorrect rank assumption. The failed report is retained, never relabelled.
var registered: bool=false
var contracts_completed: int=0
var waiting_ticks: int=0
var earned_reputation_start: int=0
var earned_reputation_end: int=0

func _ready() -> void:
	get_tree().set_meta("xj_natural_rank_v50_diagnostic",true)
	get_tree().set_meta("xj_natural_recovery_v45_diagnostic",true)
	get_tree().set_meta("xj_natural_growth_v45_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_RANK_V50_DIRECTORY").replace("\\","/")
	var proof_path: String=OS.get_environment("XJ_NATURAL_RANK_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-rank-v50/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v50-mid-origin-") and not proof_path.contains(".."),"fresh rank replay and bounded earned checkpoint"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));var source: String=str(origin.database)
	if not check(origin.result=="EARNED_CHECKPOINT" and source.contains("/jiaoben/tmp/natural-mid-v50/") and not source.contains("..") and FileAccess.get_sha256(source)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"actual partial-run source and its declared failure remain unchanged"):await finish();return
	check(DirAccess.copy_absolute(source,directory.path_join("progress.db"))==OK,"copy only the earned checkpoint")
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens earned citizenship"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot):slot=entry;break
	if not check(not slot.is_empty(),"earned citizenship slot exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle()
	initial_credit=host.state.player().credit
	if not check(host.gameplay.civilizations.allegiance()=="faction_deepforge" and initial_credit==int(origin.credit),"membership assets and funds continue without grants"):await finish();return
	for id: String in ["civ_join_forge_1","civ_join_forge_2","civ_join_forge_3"]:check(host.gameplay.missions.completed(id),"actual completed admission retained "+id)
	earned_reputation_start=host.gameplay.growth.reputation("faction_deepforge")
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	var command_def: Dictionary=host.gameplay.honors.definition("faction_deepforge")
	var required: int=int(host.gameplay.civilizations.rank_requirement("faction_deepforge",int(command_def.registration_rank)).required_reputation)
	mark("earned-citizenship-resumed")
	while host.gameplay.growth.reputation("faction_deepforge")<required and failures.is_empty():
		if not check(contracts_completed<6,"bounded normal contribution route"):await finish();return
		if not await reach_station("station_forge_01"):await finish();return
		var ammo: String=str(host.gameplay.definition("weapon_defs","module_id","module_kinetic_needle_i").ammo_item_id)
		var hold: String=host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO)
		var stocked: int=host.gameplay.inventory.count(hold,ammo,true)
		if stocked<80:await command("buy_item",ammo,200-stocked,hold)
		if host.gameplay.economy.quote_repair()>0:await command("repair")
		var mission: Dictionary=host.gameplay.definition("mission_defs","mission_id","civ_patrol_forge")
		var wait_start: int=tick();host.ui.show_page("")
		while not host.gameplay.missions.eligible(mission):
			await frames(30)
			if tick()-wait_start>int(host.gameplay.rule("simulation_hz")*360.0):check(false,"ordinary patrol did not become available within its bounded window");await finish();return
		waiting_ticks+=tick()-wait_start
		if not await drive_mission("civ_patrol_forge"):await finish();return
		contracts_completed+=1;mark("earned-patrol-reputation:"+str(host.gameplay.growth.reputation("faction_deepforge")))
	earned_reputation_end=host.gameplay.growth.reputation("faction_deepforge")
	check(earned_reputation_end>=required and earned_reputation_end>earned_reputation_start,"actual repeatable contracts close the real registration gap")
	await command("honor_action","faction_deepforge",1,"register:unregistered")
	registered=check(host.gameplay.honors.instance("faction_deepforge").phase=="assessing","normally earned standing opens commander training")
	check(host.state.rows("growth_grant_receipt_state").is_empty(),"registration itself pays no unearned outfitting grant")
	mark("commander-registration-earned")
	host.ui.show_page("pause");await settle();await command("save","2",1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==2:saved=entry;break
	if not check(not saved.is_empty(),"earned commander entry checkpoint saves"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG restore at commander entry")
	check(FileAccess.get_sha256(source)==origin.database_sha256,"earlier normally earned source is unchanged")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"registered":registered,"contracts_completed":contracts_completed,"reputation_start":earned_reputation_start,"reputation_end":earned_reputation_end,"waiting_ticks":waiting_ticks,"initial_credit":initial_credit,"final_credit":credit,"actions":actions,"milestones":milestones,"physical_distance_m":moved_m,"scope":"real earned checkpoint and normal Main commands/physics; original failed registration premise remains excluded; no wealth, qualification, pose, damage or clock injection"}
	print("NATURAL_RANK_V50_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_RANK_V50_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
