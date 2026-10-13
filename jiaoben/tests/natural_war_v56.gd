extends "natural_command_v55.gd"
## First frontier war from actually earned commander qualification. All route,
## scouting, escort, battle and repair progress is produced by engine physics.
var won: bool=false
var passages: int=0
var original_fleet: Array[String]=[]
var campaign_id: String="war_forge_01"

func _ready() -> void:
	for diagnostic: String in ["natural_war_v56","natural_command_v55","natural_logistics_v54","natural_rescue_v53","natural_scout_v51","natural_recovery_v45","natural_growth_v45"]:
		get_tree().set_meta("xj_"+diagnostic+"_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func frontier_action(action: String) -> bool:
	await command("frontier_action",campaign_id,1,action+":"+host.gameplay.frontier.expected_token(campaign_id))
	return check(host.gameplay.last_error.is_empty(),"ordinary campaign action "+action+" "+host.gameplay.last_error)

func steer_campaign() -> void:
	if not host.local_navigation.active():
		await command("frontier_navigate",campaign_id,1,host.gameplay.frontier.expected_token(campaign_id))

func campaign_battle() -> bool:
	await command("undock");host.ui.show_page("")
	var started: int=tick();var last: String=""
	while failures.is_empty() and tick()-started<int(host.gameplay.rule("simulation_hz")*1800):
		await frames(12);record_distance()
		if not check_alive():return false
		var war: RefCounted=host.state.find("war_campaign_state","war_id",campaign_id)
		var row: RefCounted=host.gameplay.frontier.campaign(campaign_id)
		var march: RefCounted=host.gameplay.march.state_for(campaign_id)
		var key: String=war.status+":"+row.phase+":"+march.phase+":"+str(march.completed_legs)
		if key!=last:last=key;mark("normal-war:"+key)
		if war.status in ["failed","cancelled"]:check(false,"natural frontier campaign failed "+row.phase);return false
		if war.status=="won":
			won=check(row.phase=="completed" and war.rewards_claimed,"real survey escort hold and paid repair earn first victory")
			for receipt: RefCounted in host.state.rows("march_journal_state"):
				if receipt.war_id==campaign_id and receipt.event_kind=="gate":
					check(original_fleet.has(receipt.npc_instance_id),"actual march passage belongs to an original funded actor")
					passages+=1
			check(passages>=original_fleet.size()*host.gameplay.march.route(march).size(),"original army traversed every actual gate leg")
			return won
		if host.busy or host.travel.active() or host.local_navigation.warp_active():continue
		var guidance: Dictionary=host.gameplay.frontier.guidance(campaign_id)
		if str(guidance.get("waypoint_kind",""))=="gate" and bool(host.interaction_context(str(guidance.waypoint_id)).get("ready",false)):
			await command("interact_target",str(guidance.waypoint_id));continue
		if row.phase=="scouting":
			if row.survey_paid and row.survey_remaining_s<=0.0:continue
			if not row.survey_paid and host.gameplay.frontier.action_reason(campaign_id,"survey").is_empty():
				if not await frontier_action("survey"):return false
			elif not row.survey_paid:await steer_campaign()
		elif row.phase=="escorting":
			var hostile: String=""
			for actor: RefCounted in host.state.rows("frontier_actor_state"):
				if actor.has_war_id and actor.war_id==campaign_id and actor.actor_role=="ambusher" and host._combat_target_valid(actor.npc_instance_id):hostile=actor.npc_instance_id;break
			if not hostile.is_empty():
				if host.auto_fire_target!=hostile:await command("combat_engage",hostile)
				if host.gameplay.hired.active()!=null and host.gameplay.hired.order_reason("focus",hostile).is_empty():
					var lease: RefCounted=host.gameplay.hired.active()
					if lease.order_kind!="focus" or lease.focus_target_id!=hostile:await command("hire_action","focus",1,host.gameplay.hired.token()+"|"+hostile)
			else:
				var convoy: RefCounted=host.gameplay.frontier._actor_for(campaign_id,"convoy")
				if convoy!=null and host.world.targets.has(convoy.npc_instance_id):
					if host.local_navigation.mode!="orbit" or host.local_navigation.target_id!=convoy.npc_instance_id:await command("nav_orbit",convoy.npc_instance_id)
				else:await steer_campaign()
		elif row.phase=="hold":
			# Command the paid army while holding the objective in an industrial
			# hull; no battle progress or damage is injected by this pilot.
			var defenders: Array=host.gameplay.civilizations.living_fleet(war,"defender")
			if not defenders.is_empty():
				var target: String=defenders[0].npc_instance_id
				if (war.fleet_order!="focus" or war.focus_target_id!=target) and host._combat_target_valid(target):await command("fleet_command","focus",1,target)
			var spec: Dictionary=host.gameplay.definition("civilization_war_defs","war_id",campaign_id)
			if not host.gameplay.frontier._at(spec.capture_anchor_id,float(spec.capture_radius_m)*0.5):
				if host.local_navigation.mode=="orbit":await command("nav_stop")
				await steer_campaign()
		elif row.phase=="rebuilding":
			if row.repair_paid_units>0:continue
			if host.gameplay.frontier.action_reason(campaign_id,"repair").is_empty():
				if not await frontier_action("repair"):return false
			else:await steer_campaign()
	check(false,"natural first war exceeded bounded play window");return false

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_WAR_V56_DIRECTORY").replace("\\","/")
	var proof_path: String=OS.get_environment("XJ_NATURAL_COMMAND_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-war-v56/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v55-command-origin-") and not proof_path.contains(".."),"fresh earned first-war scope"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));source_path=str(origin.database)
	if not check(origin.result=="PASS" and source_path.contains("/jiaoben/tmp/natural-command-v55/") and not source_path.contains("..") and FileAccess.get_sha256(source_path)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"actual certified commander source is bound to accepted report"):await finish();return
	if not check(DirAccess.copy_absolute(source_path,directory.path_join("progress.db"))==OK,"copy earned commander checkpoint"):await finish();return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens first frontier war"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot):slot=entry;break
	if not check(not slot.is_empty(),"earned commander manual exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle();initial_credit=host.state.player().credit
	if not check(initial_credit==int(origin.credit) and host.gameplay.honors.instance("faction_deepforge").phase=="certified","normal funds and all four certified proofs retained"):await finish();return
	check(Engine.physics_ticks_per_second==60 and int(host.gameplay.rule("simulation_hz"))==60,"first war retains production60Hz physics")
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	var material: String=host.gameplay.frontier.balance.material_id
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	var repair: Dictionary=host.gameplay.economy.repair_requirements()
	var missing: int=maxi(0,int(repair.structural_units)+int(host.gameplay.frontier.balance.supply_units)-host.gameplay.inventory.count(warehouse,material,true))
	if missing>0:await command("buy_item",material,missing)
	if int(repair.credit)>0:await command("repair")
	if not check(host.gameplay.economy.quote_repair()==0,"paid ordinary repairs prepare the original earned ship"):await finish();return
	var cargo: String=host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO)
	missing=maxi(0,int(host.gameplay.frontier.balance.rebuild_units)-host.gameplay.inventory.count(cargo,material,true))
	if missing>0:await command("buy_item",material,missing,cargo)
	await command("hire_action","hire_escort",1,host.gameplay.hired.token())
	if not check(host.gameplay.hired.active()!=null and host.gameplay.hired.active().profile_id=="hire_escort","normal balance pays first-war combat escort"):await finish();return
	await command("start_war",campaign_id)
	var march: RefCounted=host.gameplay.march.state_for(campaign_id)
	if not check(march!=null and host.gameplay.civilizations.active_war()!=null,"earned qualification actually starts funded war and march"):await finish();return
	for member: RefCounted in host.gameplay.march.members(march):original_fleet.append(member.npc_instance_id)
	check(original_fleet.size()==3,"paid government expedition starts with three original actors")
	if not await campaign_battle():await finish();return
	mark("normal-first-war-won")
	var war: Dictionary=host.gameplay.definition("civilization_war_defs","war_id",campaign_id)
	var station: String=host.gameplay.definition("frontier_governance_defs","sector_id",war.target_sector_id).station_id
	if host.gameplay.hired.active()!=null and host.gameplay.hired.active().phase=="deployed" and host.gameplay.hired.order_reason("retreat").is_empty():
		await command("hire_action","retreat",1,host.gameplay.hired.token())
	if not await clear_for_warp(station,"back"):await finish();return
	if not await reach_station(station):await finish();return
	# Preserve victory before any later procurement or another development branch.
	host.ui.show_page("pause");await settle();await command("save","3",1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==3:saved=entry;break
	if not check(not saved.is_empty(),"earned first-war checkpoint saves"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG reload at earned victory")
	check(FileAccess.get_sha256(source_path)==origin.database_sha256,"earned commander source stays unchanged")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	Input.action_release("forward");Input.action_release("back");Input.action_release("boost")
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"won":won,"gate_passages":passages,"original_fleet":original_fleet,"origin":origin,"initial_credit":initial_credit,"final_credit":credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"scope":"normally funded first frontier war with actual NPC march, escort, hold and repair; no progression fixtures"}
	print("NATURAL_WAR_V56_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_WAR_V56_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
