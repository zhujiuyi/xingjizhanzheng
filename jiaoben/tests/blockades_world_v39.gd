extends "scenarios_world_v39.gd"
## Only wealth, unlocks, hull and initial entrance pose are fixtures. Every
## node-to-node segment, survey, hit and cargo delivery uses the real Main.
var survey_traveled: float=0
var relay_traveled: float=0
var survey_delivered: int=0
var relay_delivered: int=0
var current_route: String=""
func _ready() -> void:
	get_tree().set_meta("xj_blockades_world_v39_diagnostic",true)
	get_tree().create_timer(900).timeout.connect(func():check(false,"bounded two-route native blockade watchdog");finish())
	run.call_deferred()
func movement(before: Vector3) -> Vector3:
	var now: Vector3=host.gameplay.position(host.state.ship())
	if current_route=="survey":survey_traveled+=before.distance_to(now)
	else:relay_traveled+=before.distance_to(now)
	return now
func move_to(id: String,anchor_id: String) -> bool:
	host.ui.show_page("");await run_for(0.1)
	var target: String="scenario:blockade:"+id+":"+anchor_id
	host.ui._select_target(target)
	var readout: Dictionary=host.ui._selected_details()
	check(readout.get("kind")=="marker" and not readout.has("encounter_info") and not str(readout.get("title","")).contains("0/0"),"scenario navigation point is displayed as a beacon rather than an empty enemy group")
	if not check(host._navigation_command("approach",target),"normal local navigation starts toward "+anchor_id):return false
	var anchor: Dictionary=host.gameplay.definition("anchor_defs","anchor_id",anchor_id)
	var radius: float=float(host.gameplay.scenarios.definition("blockade",id).interaction_radius_m)
	var previous: Vector3=host.gameplay.position(host.state.ship());var deadline: int=Time.get_ticks_msec()+240000
	host.set_process(true);host.set_physics_process(true)
	while host.gameplay.anchor_distance(host.state.ship(),anchor)>radius and host.gameplay.scenarios.instance("blockade",id).phase=="active" and Time.get_ticks_msec()<deadline:
		await frames(2);previous=movement(previous)
	host.set_process(false);host.set_physics_process(false)
	await host._command("nav_stop","",1,"");await settle()
	return check(host.gameplay.scenarios.instance("blockade",id).phase=="active" and host.gameplay.anchor_distance(host.state.ship(),anchor)<=radius,"actual loaded ship reaches the node's interaction radius "+anchor_id)
func deliver(id: String,station_id: String) -> bool:
	var row: RefCounted=host.gameplay.scenarios.instance("blockade",id);var units: int=row.cargo_units
	await show("blockades")
	if not await click(host.ui.body.find_child("BlockadeExit",true,false),"exit with actual surviving cargo"):return false
	check(host.gameplay.scenarios.instance("blockade",id).phase=="ready" and host.gameplay.scenarios.instance("blockade",id).completed_units==units,"physical exit banks exactly the surviving task cargo")
	if not await settle_at(host.gameplay.definition("station_defs","station_id",station_id).station_anchor_id,station_id):return false
	await show("blockades");var credit: int=host.state.player().credit
	if not await click(host.ui.body.find_child("ScenarioAction_claim",true,false),"pay actual delivered corridor units"):return false
	check(host.state.player().credit==credit+units*int(host.gameplay.scenarios.definition("blockade",id).credit_per_unit),"native station reward equals actual delivery units")
	if current_route=="survey":survey_delivered=units
	else:relay_delivered=units
	return true
func run() -> void:
	directory=OS.get_environment("XJ_BLOCKADES_WORLD_V39_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/blockades-world-v39/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"two native blockade routes use fresh scoped data"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(6)
	if not check(host.services_ready,"native corridor Main initializes"):await finish();return
	await host._command("new_world","封锁航路物理验收",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	current_route="survey"
	if not await prepare("blockade","blockade_echo","transport_caravan","module_scanner_beacon_i","utility:0","station_echo_depot"):await finish();return
	var block: RefCounted=host.gameplay.scenarios.instance("blockade","blockade_echo")
	check(block.loaded_units==12 and host.gameplay.scenarios.cargo(host.state.ship().ship_instance_id).mass==120000,"physical route begins with real 120-ton cargo")
	for index: int in [0,1]:
		var node: Dictionary=host.gameplay.scenarios.node_definition("blockade_echo",index)
		if not await move_to("blockade_echo",node.anchor_id):await finish();return
		await show("blockades")
		var energy: float=host.state.ship().energy
		if not await click(host.ui.body.find_child("BlockadeSurvey_"+str(index),true,false),"pay real survey cycle "+str(index)):await finish();return
		check(host.state.ship().energy<energy,"survey pays actual capacitor energy before completion")
		host.ui.show_page("");host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+45000
		while not host.gameplay.scenarios._node("blockade_echo",index).completed and host.gameplay.scenarios.instance("blockade","blockade_echo").phase=="active" and Time.get_ticks_msec()<deadline:await frames(2)
		host.set_process(false);host.set_physics_process(false)
		check(host.gameplay.scenarios._node("blockade_echo",index).completed,"actual survey finishes at its real node")
		await capture("blockade-survey-"+str(index))
	block=host.gameplay.scenarios.instance("blockade","blockade_echo")
	check(block.bypass_remaining_s>0 and not host.gameplay.scenarios.relays_open("blockade_echo"),"investigation creates a finite bypass while both physical relays remain intact")
	if not await move_to("blockade_echo",host.gameplay.scenarios.definition("blockade","blockade_echo").exit_anchor_id):await finish();return
	if not await deliver("blockade_echo","station_echo_depot"):await finish();return
	check(survey_traveled>9000 and survey_delivered==12,"actual survey route flies its full local corridor and delivers all finite cargo")
	await capture("blockade-survey-delivered")
	current_route="relay"
	if not await prepare("blockade","blockade_mirror","cruiser_horizon","module_thermal_sunline_iii","weapon:1","station_mirror_hub"):await finish();return
	var node: Dictionary=host.gameplay.scenarios.node_definition("blockade_mirror",2)
	if not await move_to("blockade_mirror",node.anchor_id):await finish();return
	block=host.gameplay.scenarios.instance("blockade","blockade_mirror")
	check(block.alerted and host.gameplay.scenarios.field_active("blockade_mirror") and not host.gameplay.scenarios.navigation_reason().is_empty(),"actual fast entry triggers live relay detection and its bounded warp denial")
	var relays: Array[String]=[]
	for member: RefCounted in host.state.rows("scenario_actor_state"):
		if member.scenario_id=="blockade_mirror" and member.actor_role=="relay":relays.append(member.npc_instance_id)
	for relay_id: String in relays:
		var npc: RefCounted=host.state.find("npc_state","npc_instance_id",relay_id);var previous: Vector3=host.gameplay.position(host.state.ship())
		check(host.world.targets[relay_id].title.begins_with("封锁中继舰"),"the real destructible relay has an unambiguous role name")
		host.ui.show_page("");await host._command("combat_engage",relay_id,1,"");await settle()
		check(host.auto_fire_target==relay_id,"normal engagement targets a real destructible relay")
		host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+120000
		while npc.alive and host.gameplay.scenarios.instance("blockade","blockade_mirror").phase=="active" and Time.get_ticks_msec()<deadline:
			await frames(2);previous=movement(previous)
		host.set_process(false);host.set_physics_process(false)
		if not check(not npc.alive,"actual weapon collision destroys one physical relay"):await finish();return
	check(host.gameplay.scenarios.relays_open("blockade_mirror") and not host.gameplay.scenarios.field_active("blockade_mirror") and host.gameplay.scenarios.navigation_reason().is_empty(),"two real relay destructions remove blockade influence without surveying")
	await capture("blockade-relays-destroyed")
	if not await move_to("blockade_mirror",host.gameplay.scenarios.definition("blockade","blockade_mirror").exit_anchor_id):await finish();return
	if not await deliver("blockade_mirror","station_mirror_hub"):await finish();return
	check(relay_traveled>9000 and relay_delivered>0,"actual combat route flies the corridor and retains a deliverable outcome")
	await capture("blockade-relay-delivered")
	check(host.state.rows("blockade_result_state").size()==2,"two different physical choices retain independent typed results")
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(6);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"survey_traveled":survey_traveled,"relay_traveled":relay_traveled,"survey_delivered":survey_delivered,"relay_delivered":relay_delivered}
	print("BLOCKADES_WORLD_V39_FINAL_JSON ",JSON.stringify(summary));print("BLOCKADES_WORLD_V39_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
