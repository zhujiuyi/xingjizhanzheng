extends "natural_recovery_v45.gd"
## Normally funded refit and a real random relic encounter. No balance/state,
## variant, damage, pose or time injection; combat and investigation run in Main.
var scout_earned: bool=false
var grant_earned: bool=false
var ship_bought: bool=false
var event_id: String="exp_forge_relic"

func _ready() -> void:
	get_tree().set_meta("xj_natural_scout_v51_diagnostic",true)
	get_tree().set_meta("xj_natural_recovery_v45_diagnostic",true)
	get_tree().set_meta("xj_natural_growth_v45_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func item_for(module_id: String) -> RefCounted:
	for item: RefCounted in host.state.rows("item_instance_state"):
		if item.item_def_id==module_id and item.policy_id=="normal_owned":return item
	return null

func explore_command(action: String) -> bool:
	var row: RefCounted=host.gameplay.exploration.instance(event_id)
	await command("exploration_action",event_id,1,action+":"+str(row.generation))
	if host.gameplay.last_error.contains("电容不足") or host.gameplay.last_error.contains("热量过高"):
		await frames(60);return true
	return check(host.gameplay.last_error.is_empty(),"normal exploration action "+action+" "+host.gameplay.last_error)

func drive_relic() -> bool:
	var event: Dictionary=host.gameplay.exploration.definition(event_id)
	if host.state.ship().status==T.ShipStatus.DOCKED:
		if not await reach_station(event.station_id):return false
		await command("undock")
	host.ui.show_page("")
	var started: int=tick();var last: String=""
	while failures.is_empty() and tick()-started<int(host.gameplay.rule("simulation_hz")*1200.0):
		await frames(12);record_distance()
		if not check_alive():return false
		var row: RefCounted=host.gameplay.exploration.instance(event_id)
		var key: String=str(row.phase)+":"+str(row.operation_kind)+":"+str(row.evidence_units)
		if key!=last:last=key;mark("relic:"+key)
		if row.phase in ["failed","withdrawn"]:check(false,"normal relic failed "+row.phase);return false
		if row.phase=="ready":
			if not check(row.outcome=="full","normal relic obtains complete evidence"):return false
			if not await reach_station(event.station_id):return false
			return await explore_command("claim")
		if host.busy or host.travel.active() or host.local_navigation.warp_active():continue
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
		if row.phase=="clue":
			if host.gameplay.exploration.action_reason(event_id,"survey").is_empty():
				if not await explore_command("survey"):return false
			elif not host.local_navigation.active():await command("exploration_nav",event_id,1,str(row.generation))
		elif row.phase in ["surveyed","relic"]:
			var action: String="stabilize" if not row.stabilized else "deepen" if row.evidence_units<int(host.gameplay.exploration.variant(row).relic_layers) else "extract"
			if host.gameplay.exploration.action_reason(event_id,action).is_empty():
				if not await explore_command(action):return false
			elif not host.local_navigation.active():await command("exploration_nav",event_id,1,str(row.generation))
		elif row.phase=="extracting" and not host.local_navigation.active():await command("exploration_nav",event_id,1,str(row.generation))
	check(false,"normal relic route exceeded its bounded play window");return false

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_SCOUT_V51_DIRECTORY").replace("\\","/")
	var proof_path: String=OS.get_environment("XJ_NATURAL_EXAM_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-scout-v51/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v51-exam-origin-") and not proof_path.contains(".."),"fresh normal scout scope"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));var source: String=str(origin.database)
	if not check(origin.result=="PASS" and source.contains("/jiaoben/tmp/natural-rank-v50/") and not source.contains("..") and FileAccess.get_sha256(source)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"normal rank source is bound to completed actual replay"):await finish();return
	check(DirAccess.copy_absolute(source,directory.path_join("progress.db"))==OK,"copy earned commander training checkpoint")
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens scout continuation"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot):slot=entry;break
	if not check(not slot.is_empty(),"earned rank checkpoint exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle();initial_credit=host.state.player().credit
	if not check(initial_credit==int(origin.credit) and host.gameplay.honors.instance("faction_deepforge").phase=="assessing","normal funds and registered exam survive continuation"):await finish();return
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	mark("scout-earned-origin")
	for equipment: RefCounted in host.gameplay.equipped(host.state.ship()).duplicate():
		if equipment.module_def_id=="module_engine_vector_i":await command("unfit_module",equipment.item_instance_id)
	await command("buy_ship","frigate_lantern")
	var ship: RefCounted=null
	for owned: RefCounted in host.state.rows("ship_state"):
		if owned.ship_def_id=="frigate_lantern" and owned.policy_id=="normal_owned" and owned.status==T.ShipStatus.DOCKED:ship=owned
	ship_bought=check(ship!=null,"real accumulated earnings buy a reconnaissance hull")
	if not ship_bought:await finish();return
	await command("switch_ship",ship.ship_instance_id)
	for pair: Array in [["module_engine_vector_i","utility:0"],["module_scanner_beacon_i","utility:1"],["module_shield_lattice_i","utility:2"],["module_thermal_sunline_i","weapon:0"]]:
		var item: RefCounted=item_for(pair[0])
		if item==null:await command("buy_item",pair[0]);item=item_for(pair[0])
		if not check(item!=null,"normal exploration equipment obtained "+str(pair[0])):await finish();return
		await command("fit_module",item.item_instance_id,1,pair[1]);await command("set_module_enabled",item.item_instance_id,1,"on")
		if not check(host.state.find("equipment_state","item_instance_id",item.item_instance_id)!=null,"paid exploration equipment legally fitted "+str(pair[0])):await finish();return
	await command("crew_action","crew_pilot_1",1,"assign|"+host.gameplay.crew.token("crew_pilot_1")+"|"+host.state.ship().ship_instance_id)
	await command("buy_item","material_structural_stock",20,host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO))
	mark("paid-reconnaissance-refit")
	if not await drive_relic():await finish();return
	var task: String="honor_faction_deepforge_scout"
	scout_earned=check(host.gameplay.honors.progress(task)>=1,"actual full relic settlement earns the scouting proof")
	if not await reach_station("station_forge_01"):await finish();return
	var credit: int=host.state.player().credit;var rep: int=host.gameplay.growth.reputation("faction_deepforge");var grant: Dictionary=host.gameplay.definition("growth_grant_defs","task_id",task)
	await command("growth_claim",task,1,host.gameplay.growth.grant_token(task))
	grant_earned=check(host.state.player().credit==credit+int(grant.reward_credit) and host.gameplay.growth.reputation("faction_deepforge")==rep+int(grant.reward_reputation),"actual earned scout proof pays its once-only outfitting funds")
	mark("scout-grant-earned")
	host.ui.show_page("pause");await settle();await command("save","3",1,"manual")
	check(FileAccess.get_sha256(source)==origin.database_sha256,"earlier normal rank source remains untouched")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"ship_bought":ship_bought,"scout_earned":scout_earned,"grant_earned":grant_earned,"initial_credit":initial_credit,"final_credit":credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"scope":"normally funded ship/refit, natural random relic/combat, actual payout; no progression/damage/pose/clock fixtures"}
	print("NATURAL_SCOUT_V51_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_SCOUT_V51_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
