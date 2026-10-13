extends "natural_war_v56.gd"
## Spend actual victory earnings on public technology, faction design research,
## a manufactured faction hull and a legal mixed weapon fitting.
var researched: bool=false
var hull_built: bool=false
var fitted: bool=false
var contracts_for_budget: int=0

func _ready() -> void:
	for diagnostic: String in ["natural_hull_v57","natural_war_v56","natural_command_v55","natural_logistics_v54","natural_rescue_v53","natural_scout_v51","natural_recovery_v45","natural_growth_v45"]:
		get_tree().set_meta("xj_"+diagnostic+"_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func normal_research(id: String) -> bool:
	var spec: Dictionary=host.gameplay.definition("research_defs","research_id",id)
	if host.gameplay.unlocked(spec.reward_unlock_id):return true
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	for input: Dictionary in host.gameplay.rows("research_inputs"):
		if input.research_id!=id:continue
		var missing: int=maxi(0,int(input.quantity)-host.gameplay.inventory.count(warehouse,input.item_id,true))
		if missing>0:await command("buy_item",input.item_id,missing)
		if not check(host.gameplay.inventory.count(warehouse,input.item_id,true)>=int(input.quantity),"ordinary research material acquired "+id+":"+str(input.item_id)):return false
	await command("research",id)
	return check(host.gameplay.unlocked(spec.reward_unlock_id),"earned funds and prerequisites unlock "+id)

func hull_budget() -> int:
	var inputs: Dictionary=host.gameplay.industry.inputs("hull_recipe_destroyer_forge_hammer",1)
	var research: Dictionary=host.gameplay.definition("research_defs","research_id","research_destroyer_forge_hammer")
	var total: int=host.gameplay.economy.quote_manufacture("hull_recipe_destroyer_forge_hammer")
	if not host.gameplay.unlocked(research.reward_unlock_id):
		total+=int(research.required_credit)
		for item: Dictionary in host.gameplay.rows("research_inputs"):
			if item.research_id==research.research_id:inputs[item.item_id]=int(inputs.get(item.item_id,0))+int(item.quantity)
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	for id: String in inputs:
		var count: int=maxi(0,int(inputs[id])-host.gameplay.inventory.count(warehouse,id,true))
		if count>0:total+=host.gameplay.economy.quote(id,count)
	var weapon: Dictionary=host.gameplay.definition("weapon_defs","module_id","module_kinetic_needle_ii")
	# This pilot reserves a modest repair/travel balance after the actual quote.
	return total+host.gameplay.economy.quote("module_kinetic_needle_ii",1)+host.gameplay.economy.quote(weapon.ammo_item_id,200)+2000

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_HULL_V57_DIRECTORY").replace("\\","/")
	var proof_path: String=OS.get_environment("XJ_NATURAL_WAR_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-hull-v57/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v56-war-origin-") and not proof_path.contains(".."),"fresh earned civilization hull scope"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));source_path=str(origin.database)
	if not check(origin.result=="PASS" and source_path.contains("/jiaoben/tmp/natural-war-v56/") and not source_path.contains("..") and FileAccess.get_sha256(source_path)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"actual first victory is bound to its accepted source"):await finish();return
	if not check(DirAccess.copy_absolute(source_path,directory.path_join("progress.db"))==OK,"copy earned victory checkpoint"):await finish();return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens faction industry continuation"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot):slot=entry;break
	if not check(not slot.is_empty(),"earned first-war manual exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle();initial_credit=host.state.player().credit
	if not check(initial_credit==int(origin.credit) and host.state.find("war_campaign_state","war_id","war_forge_01").status=="won","normal victory and its earned funds retained"):await finish();return
	check(Engine.physics_ticks_per_second==60 and int(host.gameplay.rule("simulation_hz"))==60,"faction industry retains production60Hz physics")
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	if not await reach_station("station_mirror_hub"):await finish();return
	if not await normal_research("research_tech_ii"):await finish();return
	if not await reach_station("station_forge_01"):await finish();return
	for mission_id: String in ["civ_patrol_forge","contract_forge_survey","civ_patrol_forge"]:
		if host.state.player().credit>=hull_budget():break
		var mission: Dictionary=host.gameplay.definition("mission_defs","mission_id",mission_id)
		if not await reach_station(mission.accept_station_id):await finish();return
		if not await drive_mission(mission_id):await finish();return
		contracts_for_budget+=1
		if not await reach_station("station_forge_01"):await finish();return
	if not check(host.state.player().credit>=hull_budget(),"actual normal income covers research hull fitting and reserve"):await finish();return
	if not await normal_research("research_destroyer_forge_hammer"):await finish();return
	researched=true;mark("faction-design-earned")
	var blueprint: String="hull_recipe_destroyer_forge_hammer"
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	var inputs: Dictionary=host.gameplay.industry.inputs(blueprint,1)
	for id: String in inputs:
		var count: int=maxi(0,int(inputs[id])-host.gameplay.inventory.count(warehouse,id,true))
		if count>0:await command("buy_item",id,count)
		if not check(host.gameplay.inventory.count(warehouse,id,true)>=int(inputs[id]),"ordinary faction hull inputs acquired "+id):await finish();return
	await command("manufacture",blueprint)
	var job: RefCounted=null
	for row: RefCounted in host.gameplay.industry.jobs(host.gameplay.station()):
		if row.blueprint_id==blueprint:job=row;break
	if not check(job!=null,"licensed faction construction enters paid escrow"):await finish();return
	var started: int=tick();var job_id: String=job.job_id
	host.ui.show_page("")
	while job.status!="ready" and tick()-started<int(host.gameplay.rule("simulation_hz")*360):
		await frames(12);job=host.state.find("industry_job_state","job_id",job_id)
	if not check(job.status=="ready","faction hull completes through ordinary work time"):await finish();return
	await command("claim_industry",job_id)
	var hull: RefCounted=null
	for owned: RefCounted in host.state.rows("ship_state"):
		if owned.ship_def_id=="destroyer_forge_hammer" and owned.policy_id=="normal_owned" and owned.status==T.ShipStatus.DOCKED and owned.station_id==host.gameplay.station():hull=owned;break
	hull_built=check(hull!=null,"actual research and construction deliver a faction-exclusive owned hull")
	if not hull_built:await finish();return
	var transferred: Dictionary={}
	for equipment: RefCounted in host.gameplay.equipped(host.state.ship()).duplicate():
		transferred[equipment.module_def_id]=equipment.item_instance_id
		await command("unfit_module",equipment.item_instance_id)
	await command("switch_ship",hull.ship_instance_id)
	for pair: Array in [["module_engine_vector_i","utility:0"],["module_scanner_beacon_i","utility:1"],["module_shield_lattice_i","utility:2"],["module_thermal_sunline_i","weapon:0"]]:
		if not check(transferred.has(pair[0]),"old paid equipment retained for faction refit "+str(pair[0])):await finish();return
		await command("fit_module",transferred[pair[0]],1,pair[1]);await command("set_module_enabled",transferred[pair[0]],1,"on")
	await command("buy_item","module_kinetic_needle_ii")
	var gun: RefCounted=local_module("module_kinetic_needle_ii")
	if not check(gun!=null,"actual budget buys unlocked second-tier kinetic weapon"):await finish();return
	await command("fit_module",gun.item_instance_id,1,"weapon:1");await command("set_module_enabled",gun.item_instance_id,1,"on")
	var weapon: Dictionary=host.gameplay.definition("weapon_defs","module_id",gun.item_def_id)
	await command("buy_item",weapon.ammo_item_id,200,host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO))
	await command("crew_action","crew_pilot_1",1,"assign|"+host.gameplay.crew.token("crew_pilot_1")+"|"+host.state.ship().ship_instance_id)
	fitted=check(host.state.find("equipment_state","item_instance_id",gun.item_instance_id)!=null and host.gameplay.equipped(host.state.ship()).size()==5,"normal faction hull carries legal reused gear and a tiered mixed battery")
	mark("faction-hull-built-and-equipped")
	host.ui.show_page("pause");await settle();await command("save","4",1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==4:saved=entry;break
	if not check(not saved.is_empty(),"faction industry checkpoint saves"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG reload at faction hull milestone")
	check(FileAccess.get_sha256(source_path)==origin.database_sha256,"earned victory source stays unchanged")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	Input.action_release("forward");Input.action_release("back");Input.action_release("boost")
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"researched":researched,"hull_built":hull_built,"fitted":fitted,"contracts_for_budget":contracts_for_budget,"origin":origin,"initial_credit":initial_credit,"final_credit":credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"scope":"normal public/faction research, manufactured exclusive hull and paid mixed-tier fitting; no progression fixtures"}
	print("NATURAL_HULL_V57_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_HULL_V57_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
