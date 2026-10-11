extends "honors_world_v33.gd"
## Standing/funds, paid qualification and initial arrival poses are fixtures.
## Survey, convoy movement, hostile hits, support and battle timers run in Main.
var convoy_id: String=""
var shield_id: String=""
var moved_m: float=0.0
var physical_damage: float=0.0
var battle_kind: String="hold"
func _ready() -> void:
	get_tree().set_meta("xj_frontier_world_v34_diagnostic",true)
	get_tree().create_timer(600.0).timeout.connect(func():check(false,"native frontier watchdog");finish())
	run.call_deferred()
func qualified_frontier() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	candidate.player().credit=1000000
	var helper: Node=(load(get_script().resource_path.get_base_dir().path_join("frontier_v34.gd")) as Script).new();helper.g=business;helper.state=candidate;helper.store=host.store
	helper.hull("transport_caravan");helper.fit("module_scanner_beacon_i","utility:0");helper.qualified_faction(faction);helper.apply("honor_action",faction,1,"register:unregistered")
	helper.complete_event("exp_mirror_relic");helper.complete_event("exp_echo_rescue");helper.freight(6);helper.demolition();helper.at_capital(faction);helper.apply("honor_action",faction,1,"certify:assessing")
	if not check(helper.failures.is_empty(),"native frontier prerequisite uses real paid ability settlements"):helper.free();business.dispose();return false
	helper.hull("support_weaver");shield_id=helper.fit("module_shield_lattice_i","utility:0");helper.fit("module_scanner_beacon_i","utility:1");helper.fit("module_drone_swarm_ii","weapon:0");helper.fit("module_engine_vector_i","utility:2")
	if not check(helper.failures.is_empty(),"native frontier loadout fits every real installed slot"):helper.g=null;helper.state=null;helper.store=null;helper.free();business.dispose();return false
	helper.at_capital(faction);helper.materials(business.inventory.warehouse(business.station()),int(business.frontier.balance.supply_units));helper.materials(business.inventory.hold(candidate.ship(),T.ContainerKind.CARGO),int(business.frontier.balance.rebuild_units))
	# Isolate this explicitly authored war from unrelated ordinary encounters.
	for npc: RefCounted in candidate.rows("npc_state"):business.frontier._dormant(npc)
	for tactic: RefCounted in candidate.rows("npc_tactic_state"):
		tactic.phase="ready";tactic.remaining_s=0.0;tactic.cooldown_remaining_s=0.0;tactic.deployed_drones=0;tactic.has_target_entity_id=false;tactic.target_entity_id=""
	for site: RefCounted in candidate.rows("tactical_site_state"):site.respawn_remaining_s=business.definition("tactical_site_defs","site_id",site.site_id).respawn_s
	helper.g=null;helper.state=null;helper.store=null;helper.free();business.dispose();return await activate(candidate)
func scout_arrival(war_id: String) -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var spec: Dictionary=business.frontier.definition(war_id);place(candidate,business,spec.scout_anchor_id)
	var from: Vector3=business.anchor_position(business.definition("anchor_defs","anchor_id",spec.scout_anchor_id));var destination: Vector3=business.anchor_position(business.definition("anchor_defs","anchor_id",spec.convoy_exit_anchor_id))
	var rotation: Quaternion=Basis.looking_at(from.direction_to(destination),Vector3.UP).get_rotation_quaternion()
	candidate.ship().quat_x=rotation.x;candidate.ship().quat_y=rotation.y;candidate.ship().quat_z=rotation.z;candidate.ship().quat_w=rotation.w
	business.dispose();return await activate(candidate)
func run() -> void:
	directory=OS.get_environment("XJ_FRONTIER_WORLD_V34_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/frontier-world-v34/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped native frontier world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5);await host._command("new_world","边疆实战原生",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await qualified_frontier():await finish();return
	host.ui.civilization_selected_faction=faction;await show("civilizations")
	battle_kind="demolition" if OS.get_environment("XJ_FRONTIER_BATTLE_KIND")=="demolition" else "hold"
	var war_id: String="war_council_02" if battle_kind=="demolition" else "war_council_01"
	await click(host.ui.body.find_child("CivilizationWar_"+war_id,true,false),"native core station accepts a paid staged expedition")
	check(host.gameplay.frontier.campaign(war_id).phase=="scouting","real expedition enters reconnaissance without instant combat")
	if not await scout_arrival(war_id):await finish();return
	host.ui.frontier_selected_id=war_id;await show("frontier")
	await capture("frontier-scout")
	await click(host.ui.body.find_child("Frontier_survey",true,false),"native survey starts its real paid work")
	await run_for(float(host.gameplay.frontier.balance.survey_s)+0.5)
	var phase: RefCounted=host.gameplay.frontier.campaign(war_id)
	if not check(phase.phase=="escorting","real native countdown completes the reconnaissance stage"):await finish();return
	convoy_id=host.gameplay.frontier._actor_for(war_id,"convoy").npc_instance_id
	var initial: Vector3=host.gameplay.position(host.state.find("npc_state","npc_instance_id",convoy_id))
	host.ui.show_page("");host.ui._select_target(convoy_id);host.ui.tick(1.0);await frames(3)
	await click(host.ui.mission_travel_button,"native current-step HUD approaches its actual convoy")
	check(host.local_navigation.target_id==convoy_id and host.local_navigation.mode=="approach","frontier HUD uses the real NPC target kind and navigation controller")
	if not host.ui.overview.action_buttons.nav_orbit.is_visible_in_tree():await click(host.ui.overview.more_actions,"native reveals convoy following choices")
	await click(host.ui.overview.action_buttons.nav_orbit,"native orbits and follows the real convoy")
	var start_hp: float=hp(convoy_id);var deadline: int=Time.get_ticks_msec()+12000
	host.set_process(true);host.set_physics_process(true)
	while hp(convoy_id)>=start_hp and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	physical_damage=start_hp-hp(convoy_id)
	check(physical_damage>0.0,"actual ambusher projectiles damage the moving convoy")
	host.ui._select_target(convoy_id);host.ui.tick(1.0);await frames(3)
	await click(host.ui.overview.support_buttons[shield_id],"native support repairs the authored convoy")
	check(host.gameplay.ship_roles.channel(shield_id)!=null,"new convoy keeps a real paid remote support channel")
	await capture("frontier-escort-support")
	var enemy: String=""
	for actor: RefCounted in host.state.rows("frontier_actor_state"):
		if actor.actor_role=="ambusher":enemy=actor.npc_instance_id;break
	host.ui._select_target(enemy);host.ui.tick(1.0);await frames(3)
	await click(host.ui.overview.action_buttons.combat_toggle,"native escort pilot enables actual drone attacks")
	host.ui._select_target(convoy_id);host.ui.tick(1.0)
	host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+60000
	while phase.phase=="escorting" and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	# New battle actors are published by finish_step and materialize during
	# the next real physics synchronization, after its autosave barrier.
	await settle();await get_tree().physics_frame;await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	var convoy: RefCounted=host.state.find("npc_state","npc_instance_id",convoy_id)
	moved_m=initial.distance_to(host.gameplay.anchor_position(host.gameplay.definition("anchor_defs","anchor_id",host.gameplay.frontier.definition(war_id).convoy_exit_anchor_id))) if phase.supply_delivered else initial.distance_to(host.gameplay.position(convoy)) if convoy!=null else 0.0
	check(phase.supply_delivered and phase.phase==battle_kind and moved_m>2000.0,"physical convoy crosses the full local route and unlocks the battle")
	if phase.phase!=battle_kind:print("FRONTIER_NATIVE_STALL ",JSON.stringify({"phase":phase.phase,"moved":moved_m,"player":host.world.flight.position,"navigation":host.local_navigation.phase}));await finish();return
	await capture("frontier-"+battle_kind+"-battle")
	if battle_kind=="hold":
		await click(host.ui.equipment_bar.combat_option_buttons.seek,"native commander seeks hostile ships after escort delivery")
		host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+90000
		while phase.phase=="hold" and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
		host.set_process(false);host.set_physics_process(false);host._process(0.0)
	else:
		var structures: Array[String]=[]
		for member: RefCounted in host.state.rows("frontier_actor_state"):
			if member.actor_role=="structure":structures.append(member.npc_instance_id)
		for id: String in structures:
			await settle()
			var n: RefCounted=host.state.find("npc_state","npc_instance_id",id)
			if n==null or not n.alive:continue
			host.ui._select_target(id);host.ui.tick(1.0);await frames(3)
			if not host.ui.overview.action_buttons.combat_engage.is_visible_in_tree():await click(host.ui.overview.more_actions,"native reveals the structure engagement command")
			if host.ui.overview.action_buttons.combat_engage.disabled:print("FRONTIER_STRUCTURE_CONTEXT ",JSON.stringify(host.navigation_context(id)))
			await click(host.ui.overview.action_buttons.combat_engage,"native commander attacks the actual demolition structure")
			host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+90000
			while n.alive and phase.phase=="demolition" and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
			host.set_process(false);host.set_physics_process(false);host._process(0.0)
			check(not n.alive or phase.phase=="rebuilding","physical weapon hits destroy the selected structure")
	check(phase.phase=="rebuilding" and host.state.ship().status==T.ShipStatus.FLYING,"actual fleet combat completes the authored objective")
	if phase.phase!="rebuilding":await finish();return
	await capture("frontier-battle-result")
	if not await fixture_boundary():await finish();return
	host.ui.frontier_selected_id=war_id;await show("frontier")
	await click(host.ui.body.find_child("FrontierNavigate",true,false),"native approaches the current reconstruction marker")
	if not await wait_navigation():await finish();return
	await show("frontier")
	var credit: int=host.state.player().credit
	await click(host.ui.body.find_child("Frontier_repair",true,false),"native pays actual cargo material for reconstruction")
	check(host.gameplay.frontier.campaign(war_id).repair_paid_units==int(host.gameplay.frontier.balance.rebuild_units),"real reconstruction records its paid material once")
	await run_for(float(host.gameplay.frontier.balance.rebuild_s)+0.5)
	phase=host.gameplay.frontier.campaign(war_id)
	var definition: Dictionary=host.gameplay.definition("civilization_war_defs","war_id",war_id)
	check(phase.phase=="completed" and host.gameplay.civilizations.owner(definition.target_sector_id)==faction and host.state.player().credit==credit+int(definition.reward_credit),"native paid reconstruction commits actual sovereignty and first reward")
	await show("frontier");await capture("frontier-rebuilt")
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"moved_m":moved_m,"physical_damage":physical_damage,"battle_kind":battle_kind}
	print("FRONTIER_WORLD_V34_FINAL_JSON ",JSON.stringify(summary));print("FRONTIER_WORLD_V34_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
