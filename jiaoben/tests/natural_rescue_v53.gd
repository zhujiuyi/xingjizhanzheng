extends "natural_scout_v51.gd"
## Continues earned research funds through a real rescue, without actor,
## damage, cargo, pose, clock, reward or qualification fixtures.
var rescue_earned: bool=false
var source_path: String=""

func _ready() -> void:
	for diagnostic: String in ["natural_rescue_v53","natural_scout_v51","natural_recovery_v45","natural_growth_v45"]:
		get_tree().set_meta("xj_"+diagnostic+"_diagnostic",true)
	start_msec=Time.get_ticks_msec();event_id="exp_echo_rescue";run.call_deferred()

func drive_rescue() -> bool:
	if host.state.ship().status==T.ShipStatus.DOCKED:await command("undock")
	host.ui.show_page("")
	var started: int=tick();var last: String=""
	while failures.is_empty() and tick()-started<int(host.gameplay.rule("simulation_hz")*1200.0):
		await frames(12);record_distance()
		if not check_alive():return false
		var row: RefCounted=host.gameplay.exploration.instance(event_id)
		var key: String=row.phase+":"+row.operation_kind+":"+str(row.stabilized)
		if key!=last:last=key;mark("rescue:"+key)
		if row.phase in ["failed","withdrawn"]:check(false,"normal rescue failed "+row.phase);return false
		if row.phase=="ready":
			if not check(row.outcome=="full","real escort reaches extraction alive"):return false
			if not await reach_station(host.gameplay.exploration.definition(event_id).station_id):return false
			return await explore_command("claim")
		if host.busy or host.travel.active() or host.local_navigation.warp_active():continue
		var guidance: Dictionary=host.gameplay.exploration.guidance(event_id)
		if str(guidance.get("waypoint_kind",""))=="gate" and bool(host.interaction_context(str(guidance.waypoint_id)).get("ready",false)):
			await command("interact_target",str(guidance.waypoint_id))
			mark("rescue-gate:"+str(guidance.waypoint_id));continue
		var hostile: String=""
		for member: RefCounted in host.state.rows("exploration_actor_state"):
			if member.event_id==event_id and member.actor_role!="escort":
				var npc: RefCounted=host.state.find("npc_state","npc_instance_id",member.npc_instance_id)
				if npc!=null and npc.alive and host._combat_target_valid(npc.npc_instance_id):hostile=npc.npc_instance_id;break
		if not hostile.is_empty():
			if host.auto_fire_target!=hostile:
				await command("combat_engage",hostile)
				await command("set_combat_option","orbit",1,"on")
			continue
		if not row.operation_kind.is_empty():
			if not host.gameplay.exploration._at(row) and not host.local_navigation.active():await command("exploration_nav",event_id,1,str(row.generation))
			continue
		if row.phase=="rescue" and row.stabilized:
			for member: RefCounted in host.state.rows("exploration_actor_state"):
				if member.event_id==event_id and member.actor_role=="escort" and host.world.targets.has(member.npc_instance_id):
					if host.local_navigation.mode!="orbit" or host.local_navigation.target_id!=member.npc_instance_id:
						await command("nav_orbit",member.npc_instance_id)
			continue
		var action: String="survey" if row.phase=="clue" else "rescue" if row.phase=="surveyed" else ""
		if not action.is_empty() and host.gameplay.exploration.action_reason(event_id,action).is_empty():
			if not await explore_command(action):return false
		elif not host.local_navigation.active():await command("exploration_nav",event_id,1,str(row.generation))
	check(false,"normal rescue exceeded bounded play window");return false

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_RESCUE_V53_DIRECTORY").replace("\\","/")
	var proof_path: String=OS.get_environment("XJ_NATURAL_RESEARCH_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-rescue-v53/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v53-research-origin-") and not proof_path.contains(".."),"fresh normal rescue scope"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));source_path=str(origin.database)
	if not check(origin.result=="PASS" and source_path.contains("/jiaoben/tmp/natural-research-v52/") and not source_path.contains("..") and FileAccess.get_sha256(source_path)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"earned research source matches closed accepted report"):await finish();return
	if not check(DirAccess.copy_absolute(source_path,directory.path_join("progress.db"))==OK,"copy earned research checkpoint"):await finish();return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens rescue continuation"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot):slot=entry;break
	if not check(not slot.is_empty(),"earned research manual slot exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle();initial_credit=host.state.player().credit
	if not check(Engine.physics_ticks_per_second==60 and int(host.gameplay.rule("simulation_hz"))==60,"production physics remains60Hz at reduced render cadence"):await finish();return
	if not check(initial_credit==int(origin.credit) and host.gameplay.unlocked("unlock_hulls_advanced"),"normal research and funds retained"):await finish();return
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	var hold: String=host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO)
	var stocked: int=host.gameplay.inventory.count(hold,"material_structural_stock",true)
	if stocked<10:await command("buy_item","material_structural_stock",10-stocked,hold)
	if host.gameplay.economy.quote_repair()>0:
		var repair: Dictionary=host.gameplay.economy.repair_requirements()
		var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
		var missing: int=maxi(0,int(repair.structural_units)-host.gameplay.inventory.count(warehouse,"material_structural_stock",true))
		if missing>0:await command("buy_item","material_structural_stock",missing)
		await command("repair")
		if not check(host.gameplay.economy.quote_repair()==0,"ordinary market materials pay actual station repair"):await finish();return
	mark("normal-rescue-departure")
	if not await drive_rescue():await finish();return
	var task: String="honor_faction_deepforge_rescue"
	rescue_earned=check(host.gameplay.honors.progress(task)>=1,"full normal rescue earns commander rescue proof")
	if not await reach_station("station_forge_01"):await finish();return
	var credit: int=host.state.player().credit;var rep: int=host.gameplay.growth.reputation("faction_deepforge");var grant: Dictionary=host.gameplay.definition("growth_grant_defs","task_id",task)
	await command("growth_claim",task,1,host.gameplay.growth.grant_token(task))
	grant_earned=check(host.state.player().credit==credit+int(grant.reward_credit) and host.gameplay.growth.reputation("faction_deepforge")==rep+int(grant.reward_reputation),"earned rescue proof pays finite outfitting grant")
	mark("normal-rescue-grant-earned")
	host.ui.show_page("pause");await settle();await command("save","0",1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==0:saved=entry;break
	if not check(not saved.is_empty(),"rescue checkpoint saves"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG reload at rescue checkpoint")
	check(FileAccess.get_sha256(source_path)==origin.database_sha256,"research source stays unchanged")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"rescue_earned":rescue_earned,"grant_earned":grant_earned,"initial_credit":initial_credit,"final_credit":credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"scope":"normal rescue physics, combat, costs and grants; no progression fixtures"}
	print("NATURAL_RESCUE_V53_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_RESCUE_V53_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
