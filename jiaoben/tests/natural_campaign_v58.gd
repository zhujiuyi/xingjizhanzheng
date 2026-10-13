extends "natural_hull_v57.gd"
## Continuous earned expedition and construction. Separate closed checkpoints
## keep the two long activities resumable without repeating earlier travel.
var mode: String=""
var expedition_completed: bool=false
var project_completed: bool=false
var maintained: int=0
var maintaining: bool=false
var resuming_campaign: bool=false
var observed_tick: int=-1
var observed_tick_ms: int=0
var next_observation_ms: int=0
const HOME: String="sector_frontier_01"
const PROJECT: String="project_frontier_01"

func _ready() -> void:
	for diagnostic: String in ["natural_campaign_v58","natural_hull_v57","natural_war_v56","natural_command_v55","natural_logistics_v54","natural_rescue_v53","natural_scout_v51","natural_recovery_v45","natural_growth_v45"]:
		get_tree().set_meta("xj_"+diagnostic+"_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func _process(_delta: float) -> void:
	if finishing or not is_instance_valid(host) or host.state==null or host.world==null:return
	var now: int=Time.get_ticks_msec()
	if tick()!=observed_tick:observed_tick=tick();observed_tick_ms=now
	if now<next_observation_ms:return
	next_observation_ms=now+15000
	var observed: Dictionary={"tick":tick(),"busy":host.busy,"paused":host._paused(),"page":host.ui.page,"menu_open":host.ui.menu_open,"world_error":host.world.last_error,"gameplay_error":host.gameplay.last_error,"status":host.state.ship().status,"shield":host.state.ship().shield,"hull":host.state.ship().hull}
	observed.position=str(host.gameplay.position(host.state.ship()))
	observed.auto_target=host.auto_fire_target
	if host.local_navigation!=null:observed.navigation={"active":host.local_navigation.active(),"mode":host.local_navigation.mode,"phase":host.local_navigation.phase,"target":host.local_navigation.target_id}
	var current: RefCounted=host.gameplay.exploration.instance(event_id)
	if current!=null:observed.event={"id":event_id,"phase":current.phase,"operation":current.operation_kind,"remaining_s":current.operation_remaining_s,"at_site":host.gameplay.exploration._at(current)}
	var actors: Array[Dictionary]=[]
	for member: RefCounted in host.state.rows("exploration_actor_state"):
		if member.event_id!=event_id:continue
		var npc: RefCounted=host.state.find("npc_state","npc_instance_id",member.npc_instance_id)
		if npc!=null:actors.append({"id":npc.npc_instance_id,"role":member.actor_role,"alive":npc.alive,"hp":npc.shield+npc.armor+npc.hull,"distance_m":host.gameplay.position(npc).distance_to(host.gameplay.position(host.state.ship()))})
	observed.actors=actors
	print("NATURAL_CAMPAIGN_OBSERVATION ",JSON.stringify(observed))
	if now-observed_tick_ms>60000:
		check(false,"normal long-term simulation stopped for60wallseconds: "+JSON.stringify(observed));finish()

func command(action: String,target: String="",quantity: int=1,extra: String="") -> void:
	# Respond through the existing remote reserve command, never edit ownership
	# or crisis clocks. This is the pilot's normal response to an actual warning.
	if not maintaining and is_instance_valid(host) and host.state!=null and host.gameplay!=null:
		var home: RefCounted=host.gameplay.frontier.territory(HOME)
		if home!=null and home.phase=="warning" and host.gameplay.frontier.action_reason(HOME,"secure").is_empty():
			maintaining=true
			await super.command("frontier_action",HOME,1,"secure:"+host.gameplay.frontier.expected_token(HOME))
			maintained+=1;maintaining=false
	await super.command(action,target,quantity,extra)

func top_up_home() -> bool:
	if host.gameplay.station()!=host.gameplay.projects.definition(PROJECT).station_id:return true
	var row: RefCounted=host.gameplay.frontier.territory(HOME)
	var quantity: int=maxi(0,int(host.gameplay.frontier.balance.reserve_max_units)-int(row.reserve_units))
	if quantity==0:return true
	var material: String=host.gameplay.frontier.balance.material_id
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	var missing: int=maxi(0,quantity-host.gameplay.inventory.count(warehouse,material,true))
	if missing>0:await command("buy_item",material,missing)
	await command("frontier_action",HOME,quantity,"supply:"+host.gameplay.frontier.expected_token(HOME))
	return check(host.gameplay.frontier.territory(HOME).reserve_units>=int(host.gameplay.frontier.balance.crisis_supply_base_units),"normal materials replenish actual colonial reserve")

func prepare_event(id: String) -> bool:
	var event: Dictionary=host.gameplay.exploration.definition(id)
	if not await reach_station(event.station_id):return false
	var repair: Dictionary=host.gameplay.economy.repair_requirements()
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	var missing: int=maxi(0,int(repair.structural_units)-host.gameplay.inventory.count(warehouse,"material_structural_stock",true))
	if missing>0:await command("buy_item","material_structural_stock",missing)
	if int(repair.credit)>0:await command("repair")
	var cargo: String=host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO)
	missing=maxi(0,10-host.gameplay.inventory.count(cargo,"material_structural_stock",true))
	if missing>0:await command("buy_item","material_structural_stock",missing,cargo)
	var gun: Dictionary=host.gameplay.definition("weapon_defs","module_id","module_kinetic_needle_ii")
	missing=maxi(0,200-host.gameplay.inventory.count(cargo,gun.ammo_item_id,true))
	if missing>0:await command("buy_item",gun.ammo_item_id,missing,cargo)
	return check(host.gameplay.economy.quote_repair()==0,"ordinary expedition repair and supplies prepare original faction ship")

func funding_candidate() -> Dictionary:
	var best: Dictionary={};var best_distance: int=1000000
	for activity: Dictionary in host.gameplay.growth.activities("faction_deepforge_rank5"):
		if activity.activity_kind!="mission":continue
		var available: RefCounted=host.state.find("mission_availability_state","mission_def_id",activity.reference_id)
		if available==null or available.status!="available":continue
		var mission: Dictionary=host.gameplay.definition("mission_defs","mission_id",activity.reference_id)
		var suitable: bool=mission.mission_id=="civ_patrol_forge"
		if not suitable:
			suitable=true
			for objective: Dictionary in host.gameplay.missions.objectives(mission.mission_id):
				if objective.objective_kind!="scan_signal":suitable=false;break
		if not suitable:continue
		var station: Dictionary=host.gameplay.definition("station_defs","station_id",mission.accept_station_id)
		var route: Array[Dictionary]=host.gameplay.missions._route(host.state.current_sector(),station.sector_id,true)
		if station.sector_id!=host.state.current_sector() and route.is_empty():continue
		var distance: int=route.size()*2+(0 if host.gameplay.station()==station.station_id else 1)
		if distance<best_distance:best=mission;best_distance=distance
	return best

func expedition() -> bool:
	# Earn a construction/repair reserve by playing existing, distinct contracts.
	# The threshold is this pilot's budget choice, not a production reward.
	var active: RefCounted=host.gameplay.expeditions.active()
	var contracts: int=0
	while active==null and host.state.player().credit<25000 and contracts<8:
		var mission: Dictionary=funding_candidate()
		if not check(not mission.is_empty(),"current availability offers an unlocked funding contract"):return false
		if not await reach_station(mission.accept_station_id):return false
		if not await drive_mission(mission.mission_id):return false
		contracts+=1
	if active==null:
		if not check(host.state.player().credit>=25000,"ordinary income prepares expedition and subsequent construction budget"):return false
		if not await reach_station("station_mirror_hub"):return false
	var run_id: String=active.run_id if active!=null else ""
	var first: int=(int(active.stage_index)-1 if active.phase=="active" else int(active.stage_index)) if active!=null else 0
	var choices: Array[String]=["archive","relief","archive"]
	for index: int in range(first,3):
		var restoring_stage: bool=active!=null and active.phase=="active" and int(active.stage_index)==index+1
		if not restoring_stage:
			var id: String="route_archive" if index==0 else run_id
			await command("expedition_action",id,1,("start" if index==0 else "continue")+"|"+choices[index]+"|"+host.gameplay.expeditions.token(id))
		active=host.gameplay.expeditions.active()
		if not check(active!=null and active.stage_index==index+1,"normal route choice begins actual expedition stage "+str(index+1)):return false
		run_id=active.run_id
		event_id=host.gameplay.expeditions.option("route_archive",index+1,choices[index]).event_id
		if not restoring_stage and not await prepare_event(event_id):return false
		var success: bool
		if choices[index]=="relief":success=await drive_rescue()
		else:success=await drive_relic()
		if not success:return false
		var run: RefCounted=host.gameplay.expeditions.instance(run_id)
		if not check(run.phase==("completed" if index==2 else "checkpoint"),"real exploration settlement advances expedition stage "+str(index+1)):return false
		mark("normal-expedition-stage:"+str(index+1))
		if index==0 and not await top_up_home():return false
	expedition_completed=check(host.state.find("expedition_route_state","route_id","route_archive").completed_runs>=1,"three normally played stages complete a persistent expedition")
	check(host.gameplay.projects.evidence(PROJECT)>=int(host.gameplay.projects.definition(PROJECT).required_evidence_units),"real first-system exploration supplies local construction evidence")
	return expedition_completed

func construction() -> bool:
	if not check(host.gameplay.projects.evidence(PROJECT)>=int(host.gameplay.projects.definition(PROJECT).required_evidence_units),"earned expedition evidence opens final construction phase"):return false
	var project: RefCounted=host.gameplay.projects.instance(PROJECT)
	var station: String=host.gameplay.projects.definition(PROJECT).station_id
	for stage_index: int in range(int(project.stage_index),4):
		for material: Dictionary in host.gameplay.projects.inputs(PROJECT,stage_index):
			if not await reach_station(material.delivery_station_id):return false
			if not await top_up_home():return false
			var delivered: RefCounted=host.gameplay.projects.delivered(material)
			var quantity: int=int(material.required_units)-int(delivered.delivered_units)
			if quantity<=0:continue
			var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
			var missing: int=maxi(0,quantity-host.gameplay.inventory.count(warehouse,material.item_id,true))
			if missing>0:await command("buy_item",material.item_id,missing)
			await command("construction_action",PROJECT,quantity,"deliver|"+str(material.item_id)+"|"+host.gameplay.projects.token(PROJECT))
			if not check(host.gameplay.projects.delivered(material).delivered_units==int(material.required_units),"normal station stock fulfils actual project delivery "+str(stage_index)+":"+str(material.item_id)):return false
		if not await reach_station(station):return false
		var recipe: String=""
		for candidate: Dictionary in host.gameplay.rows("recipe_defs"):
			if int(candidate.service_fee_credit)>0:recipe=candidate.recipe_id;break
		var previous_quote: int=host.gameplay.economy.quote_manufacture(recipe)
		await command("construction_action",PROJECT,1,"start||"+host.gameplay.projects.token(PROJECT))
		project=host.gameplay.projects.instance(PROJECT)
		if not check(project.phase=="working","real local materials and fee start construction stage "+str(stage_index)):return false
		host.ui.show_page("");var started: int=tick()
		var spec: Dictionary=host.gameplay.projects.stage(PROJECT,stage_index)
		while project.phase=="working" and tick()-started<int(host.gameplay.rule("simulation_hz")*(float(spec.work_s)+60.0)):
			await frames(12);project=host.gameplay.projects.instance(PROJECT)
		if not check(project.phase=="completed" if stage_index==3 else project.stage_index==stage_index+1,"ordinary world time completes construction stage "+str(stage_index)):return false
		if stage_index==1:check(host.gameplay.economy.quote_manufacture(recipe)<previous_quote,"earned construction lowers the real station manufacturing quote")
		mark("normal-project-stage:"+str(stage_index))
	project_completed=check(project.phase=="completed" and host.gameplay.projects.owned(PROJECT),"three paid cross-station phases finish the still-owned colony project")
	return project_completed

func run() -> void:
	mode=OS.get_environment("XJ_NATURAL_CAMPAIGN_V58_MODE")
	resuming_campaign=not OS.get_environment("XJ_NATURAL_CAMPAIGN_PARTIAL_ORIGIN").is_empty()
	directory=OS.get_environment("XJ_NATURAL_CAMPAIGN_V58_DIRECTORY").replace("\\","/")
	var proof_path: String=OS.get_environment("XJ_NATURAL_CAMPAIGN_PARTIAL_ORIGIN" if resuming_campaign else "XJ_NATURAL_HULL_ORIGIN" if mode=="expedition" else "XJ_NATURAL_EXPEDITION_ORIGIN").replace("\\","/")
	if not check(mode in ["expedition","project"] and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-campaign-v58/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v58-campaign-partial-" if resuming_campaign else "/jiaoben/logs/v57-hull-origin-" if mode=="expedition" else "/jiaoben/logs/v58-expedition-origin-") and not proof_path.contains(".."),"fresh earned long-term activity scope"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));source_path=str(origin.database)
	if not check(origin.result==("EARNED_CHECKPOINT" if resuming_campaign else "PASS") and (not resuming_campaign or origin.mode==mode) and source_path.contains("/jiaoben/tmp/natural-campaign-v58/" if resuming_campaign or mode=="project" else "/jiaoben/tmp/natural-hull-v57/") and not source_path.contains("..") and FileAccess.get_sha256(source_path)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"earned long-term source and accepted report match"):await finish();return
	if not check(DirAccess.copy_absolute(source_path,directory.path_join("progress.db"))==OK,"copy earned long-term checkpoint"):await finish();return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens long-term continuation"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if ((entry.slot_id==origin.slot_id and entry.current_snapshot_id==origin.snapshot_id) if resuming_campaign else (entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot))):slot=entry;break
	if not check(not slot.is_empty(),"earned long-term manual exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle();initial_credit=host.state.player().credit
	if not check(initial_credit==int(origin.credit) and host.state.ship().ship_def_id=="destroyer_forge_hammer" and host.gameplay.projects.owned(PROJECT),"real faction ship funds and occupied colony retained"):await finish();return
	check(Engine.physics_ticks_per_second==60 and int(host.gameplay.rule("simulation_hz"))==60,"long-term progression retains production60Hz physics")
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	var success: bool
	if mode=="expedition":success=await expedition()
	else:success=await construction()
	if not success:await finish();return
	var index: int=0 if mode=="expedition" else 1
	host.ui.show_page("pause");await settle();await command("save",str(index),1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==index:saved=entry;break
	if not check(not saved.is_empty(),"earned long-term checkpoint saves"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG reload at long-term milestone")
	check(FileAccess.get_sha256(source_path)==origin.database_sha256,"previous earned source stays unchanged")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	Input.action_release("forward");Input.action_release("back");Input.action_release("boost")
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"mode":mode,"resumed":resuming_campaign,"expedition_completed":expedition_completed,"project_completed":project_completed,"maintained":maintained,"origin":origin,"initial_credit":initial_credit,"final_credit":credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"scope":"normal earned expedition/construction and paid reserve responses; no progression fixtures"}
	print("NATURAL_CAMPAIGN_V58_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_CAMPAIGN_V58_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
