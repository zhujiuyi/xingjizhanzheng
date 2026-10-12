extends "campaign_world_v37.gd"
## Wealth, unlocks and initial poses are declared fixtures. Motion, shots,
## repair, UI input and report files run through the actual Main client.
var physical_precision: float=0
var physical_escort_m: float=0
var physical_repair: float=0
func _ready() -> void:
	get_tree().set_meta("xj_scenarios_world_v39_diagnostic",true)
	get_tree().create_timer(540).timeout.connect(func():check(false,"native scenario watchdog");finish())
	run.call_deferred()
func prepare(kind: String,id: String,hull_id: String,module_id: String,slot_ref: String,station_id: String) -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state)
	var g: Gameplay=Gameplay.new();g.setup(candidate,host.store.catalog)
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	candidate.player().credit=1000000
	var ship: RefCounted=g.inventory.create_ship(hull_id,station_id);candidate.player().controlled_ship_id=ship.ship_instance_id
	place(candidate,g,g.definition("station_defs","station_id",station_id).station_anchor_id,station_id)
	var gear: String=g.inventory.grant(g.inventory.warehouse(station_id),module_id,1)[0]
	check(g.act("fit_module",gear,1,slot_ref).phase==T.ActionPhase.APPLIED,"native fixture uses a legally fitted normal module")
	if kind=="trial" and id=="trial_support":g.inventory.grant(g.inventory.hold(ship,T.ContainerKind.CARGO),"repair_kit_i",8)
	g.dispose()
	if not await activate(candidate):return false
	await show("trials" if kind=="trial" else "blockades")
	if not await click(host.ui.body.find_child("ScenarioSelect_"+id,true,false),"select "+id):return false
	if not await click(host.ui.body.find_child("ScenarioAction_accept",true,false),"pay and accept "+id):return false
	check(host.gameplay.scenarios.instance(kind,id).phase=="accepted","native acceptance commits the selected scenario")
	candidate=host.store.clone_state(host.state);g=Gameplay.new();g.setup(candidate,host.store.catalog)
	place(candidate,g,g.scenarios.definition(kind,id).entry_anchor_id);g.dispose()
	if not await activate(candidate):return false
	await show("trials" if kind=="trial" else "blockades")
	await click(host.ui.body.find_child("ScenarioSelect_"+id,true,false),"select accepted "+id)
	if not await click(host.ui.body.find_child("ScenarioAction_start",true,false),"start "+id):return false
	return check(host.gameplay.scenarios.instance(kind,id).phase=="active","native start creates active physical actors")
func actor_for(id: String,role: String) -> RefCounted:
	for member: RefCounted in host.state.rows("scenario_actor_state"):
		if member.scenario_id==id and member.actor_role==role:return host.state.find("npc_state","npc_instance_id",member.npc_instance_id)
	return null
func settle_at(anchor: String,station: String="") -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var g: Gameplay=Gameplay.new();g.setup(candidate,host.store.catalog)
	place(candidate,g,anchor,station);g.dispose();return await activate(candidate)
func shoot(id: String,seconds: float) -> void:
	var deadline: int=Time.get_ticks_msec()+int(seconds*1000)
	while host.gameplay.scenarios.instance("trial","trial_precision").phase=="active" and Time.get_ticks_msec()<deadline:
		# Each pulse verifies foreground/controller access and uses real press /
		# release events; an OS focus change cannot masquerade as a held key.
		await fire_at(id)
		if host.gameplay.scenarios.instance("trial","trial_precision").phase=="active":await run_for(0.6)
func run() -> void:
	directory=OS.get_environment("XJ_SCENARIOS_WORLD_V39_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/scenarios-world-v39/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"native scenarios use a fresh test-only database"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(6)
	if not check(host.services_ready,"actual Main and renderer initialize"):await finish();return
	await host._command("new_world","战术场景原生验收",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await prepare("trial","trial_precision","frigate_kestrel","module_thermal_sunline_i","weapon:1","station_anchor_port"):await finish();return
	await capture("scenarios-precision-entry")
	var npc: RefCounted=actor_for("trial_precision","target");var target_id: String=npc.npc_instance_id
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var g: Gameplay=Gameplay.new();g.setup(candidate,host.store.catalog)
	candidate.ship().pos_x=npc.pos_x;candidate.ship().pos_y=npc.pos_y;candidate.ship().pos_z=npc.pos_z+1020;g.dispose()
	if not await activate(candidate):await finish();return
	await shoot(target_id,90)
	physical_precision=host.gameplay.scenarios.instance("trial","trial_precision").effective_hp
	check(physical_precision>=180 and host.gameplay.scenarios.instance("trial","trial_precision").phase=="ready","real legal weapon hits meet the distance-controlled precision objective")
	await capture("scenarios-precision-fire")
	if not await settle_at(host.gameplay.definition("station_defs","station_id","station_anchor_port").station_anchor_id,"station_anchor_port"):await finish();return
	await show("trials")
	var claim: Button=host.ui.body.find_child("ScenarioAction_claim",true,false)
	check(host.ui.trial_selected_id=="trial_precision","reopening trials retains the selected actual challenge")
	print("SCENARIO_CLAIM_CONTEXT ",JSON.stringify({"phase":host.gameplay.scenarios.instance("trial","trial_precision").phase,"reason":host.gameplay.scenarios.trial_reason("trial_precision","claim"),"station":host.gameplay.station(),"fit":host.gameplay.scenarios._trial_fit("trial_precision",true),"disabled":claim.disabled,"tooltip":claim.tooltip_text}))
	await capture("scenarios-precision-claim")
	if not await click(claim,"claim real precision result"):await finish();return
	await host._command("select_tactical_award","award_precision",1,"");await settle()
	check(host.gameplay.scenarios.title()=="远距射手","earned horizontal title is selected")
	if not await prepare("trial","trial_escort","frigate_kestrel","module_thermal_sunline_i","weapon:1","station_echo_depot"):await finish();return
	npc=actor_for("trial_escort","escort");var convoy_id: String=npc.npc_instance_id;var start: Vector3=host.gameplay.position(npc)
	host.ui.show_page("");host.set_process(true);host.set_physics_process(true)
	var deadline: int=Time.get_ticks_msec()+30000
	while start.distance_to(host.gameplay.position(host.state.find("npc_state","npc_instance_id",convoy_id)))<100 and Time.get_ticks_msec()<deadline:await frames(2)
	host.set_process(false);host.set_physics_process(false)
	npc=host.state.find("npc_state","npc_instance_id",convoy_id);physical_escort_m=start.distance_to(host.gameplay.position(npc))
	check(physical_escort_m>50 and host.world.npcs.has(convoy_id),"actual escort CharacterBody moves toward its exit")
	await capture("scenarios-escort-moving")
	var convoy: RefCounted=npc
	var escort_damage_start: float=host.gameplay.telemetry.totals().damage_dealt
	var raiders: Array[String]=[]
	for member: RefCounted in host.state.rows("scenario_actor_state"):
		if member.scenario_id=="trial_escort" and member.actor_role=="raider":raiders.append(member.npc_instance_id)
	for raider_id: String in raiders:
		var enemy: RefCounted=host.state.find("npc_state","npc_instance_id",raider_id)
		if enemy==null or not enemy.alive:continue
		host.ui.show_page("");await host._command("combat_engage",raider_id,1,"");await settle()
		check(host.auto_fire_target==raider_id,"normal engagement explicitly selects one live escort threat")
		host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+90000
		while enemy.alive and host.gameplay.scenarios.instance("trial","trial_escort").phase=="active" and Time.get_ticks_msec()<deadline:
			physical_escort_m=maxf(physical_escort_m,start.distance_to(host.gameplay.position(convoy)))
			await frames(2)
		host.set_process(false);host.set_physics_process(false)
	physical_escort_m=maxf(physical_escort_m,start.distance_to(host.gameplay.position(convoy)))
	host.ui.show_page("");host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+150000
	while host.gameplay.scenarios.instance("trial","trial_escort").phase=="active" and Time.get_ticks_msec()<deadline:
		if convoy!=null:physical_escort_m=maxf(physical_escort_m,start.distance_to(host.gameplay.position(convoy)))
		await frames(2)
	host.set_process(false);host.set_physics_process(false)
	check(physical_escort_m>5000 and host.gameplay.scenarios.instance("trial","trial_escort").phase=="ready","actual protected convoy travels the full corridor and completes at the real exit")
	check(host.gameplay.telemetry.totals().damage_dealt>escort_damage_start,"escort defense includes real player weapon damage; completion does not require clearing every raider")
	await capture("scenarios-escort-complete")
	if not await settle_at(host.gameplay.definition("station_defs","station_id","station_echo_depot").station_anchor_id,"station_echo_depot"):await finish();return
	await show("trials")
	if not await click(host.ui.body.find_child("ScenarioAction_claim",true,false),"claim actual physical escort success"):await finish();return
	if not await prepare("trial","trial_support","support_weaver","module_support_patch_i","work:0","station_mirror_hub"):await finish();return
	npc=actor_for("trial_support","patient");var patient_id: String=npc.npc_instance_id
	host.ui.show_page("");await run_for(0.25)
	check(host.world.targets.has(patient_id) and host.gameplay.civilizations.friendly(patient_id),"normal Main physical synchronization creates the selectable friendly patient")
	host.ui._select_target(patient_id);host._process(0);await frames(8)
	var patch: String=""
	for gear: RefCounted in host.gameplay.equipped(host.state.ship()):
		if gear.module_def_id=="module_support_patch_i":patch=gear.item_instance_id
	var support_button: Button=host.ui.root.find_child("RemoteSupport_"+patch.validate_node_name(),true,false)
	print("SCENARIO_SUPPORT_CONTEXT ",JSON.stringify({"selected":host.ui.target_id,"patch":patch,"options":host.gameplay.ship_roles.options(patient_id),"button":support_button!=null}))
	if not await click(support_button,"start actual friendly remote repair"):await finish();return
	check(host._navigation_command("approach",patient_id),"actual autopilot can follow the repair target")
	host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+300000
	while host.gameplay.scenarios.instance("trial","trial_support").phase=="active" and Time.get_ticks_msec()<deadline:await frames(2)
	host.set_process(false);host.set_physics_process(false)
	var support: RefCounted=host.gameplay.scenarios.instance("trial","trial_support");physical_repair=support.effective_hp
	check(physical_repair>=120 and support.phase=="ready","moving patient survives real physical travel with actual paid remote repair")
	# Physics is frozen after the outcome, but the HUD is driven by Main's
	# render callback. Keep that actual callback running through its cadence.
	host.set_process(true)
	await get_tree().create_timer(0.35).timeout
	host.set_process(false)
	print("SCENARIO_HUD_CONTEXT ",JSON.stringify({"objective":host.ui.objective.text,"button":host.ui.mission_guide_button.text,"phase":support.phase,"pending":host.gameplay.scenarios.pending().get("id","")}))
	check(host.ui.objective.text.contains("返回签发站") and host.ui.mission_guide_button.text=="挑战详情","actual flight HUD shows current challenge result and its detail entry")
	await capture("scenarios-support-complete")
	if not await settle_at(host.gameplay.definition("station_defs","station_id","station_mirror_hub").station_anchor_id,"station_mirror_hub"):await finish();return
	await show("trials");await click(host.ui.body.find_child("ScenarioSelect_trial_support",true,false),"select completed support")
	await click(host.ui.body.find_child("ScenarioAction_claim",true,false),"claim real moving support result")
	await show("reports")
	check(host.ui.body.find_child("ReportMeasurements",true,false)!=null and host.ui.body.find_child("ReportRecentActivities",true,false)!=null,"report shows concise sources, outcomes and recent activity")
	await show("pause")
	var tick: int=host.state.snapshot.meta.simulation_tick;var menus: RefCounted=host.state.find("telemetry_menu_state","page_id","pause")
	var before: float=menus.duration_s if menus!=null else 0
	host.set_process(true);host.set_physics_process(true);await get_tree().create_timer(1).timeout;host.set_process(false);host.set_physics_process(false)
	check(host.state.snapshot.meta.simulation_tick==tick and host.state.find("telemetry_menu_state","page_id","pause").duration_s>before,"actual pause-menu clock advances without advancing the simulation")
	await show("reports")
	var signature: String=state_signature();await click(host.ui.body.find_child("ReportExportJSON",true,false),"export complete local journal JSON3")
	check(state_signature()==signature,"export is read-only with its menu clock frozen explicitly")
	var found: bool=false
	for file: String in DirAccess.get_files_at(directory.path_join("reports")):
		if not file.ends_with(".json"):continue
		var payload: Variant=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("reports").path_join(file)))
		found=payload is Dictionary and payload.format_version==3 and payload.measurements is Dictionary and not payload.measurements.activities.is_empty()
	check(found,"actual exported JSON3 contains bounded game-only measurements")
	for layout: Dictionary in [{"size":Vector2i(3440,1188),"scale":1.0},{"size":Vector2i(1280,720),"scale":2.0}]:
		root.size=layout.size;root.content_scale_factor=1.0;root.content_scale_size=Vector2i(Vector2(layout.size)/layout.scale)
		await show("blockades");var button: Button=host.ui.body.find_child("ScenarioSelect_blockade_echo",true,false);await reveal(button)
		check(Rect2(Vector2.ZERO,host.ui.root.size).encloses(button.get_global_rect()),"corridor choices remain reachable at exact native layout "+str(layout.size))
		await capture("scenarios-layout-"+str(int(layout.scale*100)))
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(6);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"precision_hp":physical_precision,"escort_m":physical_escort_m,"repair_hp":physical_repair}
	print("SCENARIOS_WORLD_V39_FINAL_JSON ",JSON.stringify(summary));print("SCENARIOS_WORLD_V39_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
