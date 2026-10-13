extends "natural_rescue_v53.gd"
## Earn the remaining purchase budget, manufacture a transport and deliver real
## entrusted cargo. No inventory, unlock, clock, actor or pose fixtures.
var built: bool=false
var delivered: bool=false
var income_contracts: int=0
var resumed: bool=false

func _ready() -> void:
	for diagnostic: String in ["natural_logistics_v54","natural_rescue_v53","natural_scout_v51","natural_recovery_v45","natural_growth_v45"]:
		get_tree().set_meta("xj_"+diagnostic+"_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_LOGISTICS_V54_DIRECTORY").replace("\\","/")
	resumed=not OS.get_environment("XJ_NATURAL_LOGISTICS_PARTIAL_ORIGIN").is_empty()
	var proof_path: String=OS.get_environment("XJ_NATURAL_LOGISTICS_PARTIAL_ORIGIN" if resumed else "XJ_NATURAL_RESCUE_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-logistics-v54/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v54-logistics-partial-" if resumed else "/jiaoben/logs/v53-rescue-origin-") and not proof_path.contains(".."),"fresh normal industrial career scope"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));source_path=str(origin.database)
	if not check(origin.result==("EARNED_CHECKPOINT" if resumed else "PASS") and source_path.contains("/jiaoben/tmp/natural-logistics-v54/" if resumed else "/jiaoben/tmp/natural-rescue-v53/") and not source_path.contains("..") and FileAccess.get_sha256(source_path)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"earned source matches bound report and declared completion status"):await finish();return
	if not check(DirAccess.copy_absolute(source_path,directory.path_join("progress.db"))==OK,"copy earned checkpoint without modifying its source"):await finish();return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens industrial career"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if ((entry.slot_id==origin.slot_id and entry.current_snapshot_id==origin.snapshot_id) if resumed else (entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot))):slot=entry;break
	if not check(not slot.is_empty(),"earned checkpoint slot exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle();initial_credit=host.state.player().credit
	if not check(initial_credit==int(origin.credit) and host.gameplay.unlocked("unlock_hulls_advanced") and host.gameplay.honors.progress("honor_faction_deepforge_rescue")>=1,"research funds and earned rescue evidence retained"):await finish();return
	check(Engine.physics_ticks_per_second==60 and int(host.gameplay.rule("simulation_hz"))==60,"normal industrial replay retains production60Hz physics")
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	var task: String="honor_faction_deepforge_logistics"
	if resumed:
		check(FileAccess.get_sha256(origin.source_log)==origin.source_log_sha256,"original timeout log remains unchanged")
		for job: RefCounted in host.state.rows("industry_job_state"):
			if job.blueprint_id=="hull_recipe_transport_caravan" and job.status=="claimed":built=true
		built=check(built and host.state.ship().ship_def_id=="transport_caravan" and host.state.ship().policy_id=="normal_owned","resume retains actual paid construction and original transport")
		delivered=check(host.gameplay.honors.progress(task)==6,"resume retains six actual delivery proofs")
		if not built or not delivered:await finish();return
		mark("earned-logistics-resumed-after-harness-timeout")
	else:
		# 50,000 is this pilot's intended budget, not a grant or production rule.
		# Alternate existing survey and patrol contracts rather than advance cooldowns.
		for mission_id: String in ["civ_patrol_forge","contract_forge_survey","civ_patrol_forge","contract_forge_survey","civ_patrol_forge"]:
			if host.state.player().credit>=50000:break
			var mission: Dictionary=host.gameplay.definition("mission_defs","mission_id",mission_id)
			if not await reach_station(mission.accept_station_id):await finish();return
			if not await drive_mission(mission_id):await finish();return
			income_contracts+=1
		if not check(host.state.player().credit>=50000,"bounded ordinary work funds transport construction budget"):await finish();return
		mark("transport-budget-earned")
		if not await reach_station("station_drift_hub"):await finish();return
		var blueprint: String="hull_recipe_transport_caravan"
		var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
		var inputs: Dictionary=host.gameplay.industry.inputs(blueprint,1)
		for id: String in inputs:
			var missing: int=maxi(0,int(inputs[id])-host.gameplay.inventory.count(warehouse,id,true))
			if missing>0:await command("buy_item",id,missing)
			if not check(host.gameplay.inventory.count(warehouse,id,true)>=int(inputs[id]),"normal station market supplies transport input "+id):await finish();return
		var reason: String=host.gameplay.industry.start_reason(blueprint,1)
		if not check(reason.is_empty(),"actual transport recipe can be funded "+reason):await finish();return
		await command("manufacture",blueprint)
		var job: RefCounted=null
		for row: RefCounted in host.gameplay.industry.jobs(host.gameplay.station()):
			if row.blueprint_id==blueprint:job=row;break
		if not check(job!=null,"ordinary money and materials enter actual manufacturing escrow"):await finish();return
		var job_id: String=job.job_id;var started: int=tick()
		host.ui.show_page("")
		while job.status!="ready" and tick()-started<int(host.gameplay.rule("simulation_hz")*300):
			await frames(12);job=host.state.find("industry_job_state","job_id",job_id)
		if not check(job.status=="ready","transport completes through normal world time"):await finish();return
		await command("claim_industry",job_id)
		var transport: RefCounted=null
		for owned: RefCounted in host.state.rows("ship_state"):
			if owned.ship_def_id=="transport_caravan" and owned.policy_id=="normal_owned" and owned.status==T.ShipStatus.DOCKED and owned.station_id==host.gameplay.station():transport=owned;break
		built=check(transport!=null,"paid manufacturing delivers an ordinary owned transport")
		if not built:await finish();return
		var engine: RefCounted=item_for("module_engine_vector_i")
		if not check(engine!=null,"previously purchased engine remains owned"):await finish();return
		await command("unfit_module",engine.item_instance_id)
		await command("switch_ship",transport.ship_instance_id)
		await command("fit_module",engine.item_instance_id,1,"utility:0")
		await command("set_module_enabled",engine.item_instance_id,1,"on")
		await command("crew_action","crew_pilot_1",1,"assign|"+host.gameplay.crew.token("crew_pilot_1")+"|"+host.state.ship().ship_instance_id)
		mark("transport-built-and-equipped")
		var contract: String="freight_echo_mirror"
		var freight: Dictionary=host.gameplay.consignments.definition(contract)
		if not await reach_station(freight.origin_station_id):await finish();return
		var row: RefCounted=host.gameplay.consignments.instance(contract)
		await command("consignment_action",contract,6,"dispatch:"+str(row.generation))
		row=host.gameplay.consignments.instance(contract)
		if not check(row.phase=="active" and row.cargo_units==6,"normal deposit loads six physical freight batches"):await finish();return
		if not await reach_station(freight.destination_station_id):await finish();return
		row=host.gameplay.consignments.instance(contract)
		await command("consignment_action",contract,1,"deliver:"+str(row.generation))
		row=host.gameplay.consignments.instance(contract)
		await command("consignment_action",contract,1,"claim:"+str(row.generation))
		delivered=check(host.gameplay.honors.progress(task)==6,"six normally delivered batches earn actual logistics examination")
		if not delivered:await finish();return
	if not await reach_station("station_forge_01"):await finish();return
	var credit: int=host.state.player().credit;var grant: Dictionary=host.gameplay.definition("growth_grant_defs","task_id",task)
	await command("growth_claim",task,1,host.gameplay.growth.grant_token(task))
	grant_earned=check(host.state.player().credit==credit+int(grant.reward_credit),"earned logistics proof pays finite outfitting grant")
	mark("normal-logistics-grant-earned")
	host.ui.show_page("pause");await settle();await command("save","1",1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==1:saved=entry;break
	if not check(not saved.is_empty(),"industrial career checkpoint saves"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG reload at logistics checkpoint")
	check(FileAccess.get_sha256(source_path)==origin.database_sha256,"rescue source stays unchanged")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"built":built,"delivered":delivered,"grant_earned":grant_earned,"income_contracts":income_contracts,"resumed":resumed,"origin":origin,"initial_credit":initial_credit,"final_credit":credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"scope":"normal logistics closeout from a proved earned checkpoint; original2400s whole-run timeout remains INCOMPLETE" if resumed else "normal work income, ship manufacture, outfitting and physical freight delivery; no progression fixtures"}
	print("NATURAL_LOGISTICS_V54_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_LOGISTICS_V54_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
