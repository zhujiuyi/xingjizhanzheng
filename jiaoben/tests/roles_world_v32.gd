extends "fitting_world_v31.gd"
## Actual Main input/physics; qualification, actor health and initial poses are fixtures.
var friend_id: String=""
var remote_patch: String=""
var remote_shield: String=""
var scout_scanner: String=""
var measured_enemy: String=""
func _ready() -> void:
	get_tree().set_meta("xj_roles_world_v32_diagnostic",true)
	get_tree().create_timer(900.0).timeout.connect(func():check(false,"native role watchdog");finish())
	run.call_deferred()
func install(business: Gameplay,module: String,slot_ref: String) -> String:
	var item: String=business.inventory.grant(business.inventory.warehouse(business.station()),module,1)[0]
	check(business.act("fit_module",item,1,slot_ref).phase==T.ActionPhase.APPLIED,"native qualified role fits "+module)
	return item
func advance_business(business: Gameplay,seconds: float) -> void:
	var dt: float=1.0/business.rule("simulation_hz")
	for _i: int in range(int(ceil(seconds/dt))):business.tick(dt)
func fixture_boundary() -> bool:
	# Scenarios cannot abandon live sorties by cloning their counters. Recall
	# through the real simulation before replacing the current test world.
	host._reset_combat_automation();host.gameplay.ship_roles.stop_support();host.world.projectiles.recall_drones()
	host.set_process(true);host.set_physics_process(true)
	var deadline: int=Time.get_ticks_msec()+30000
	while (host.world.projectiles.has_pending() or finite_cycle_pending()) and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	return check(not host.world.projectiles.has_pending() and not finite_cycle_pending(),"scenario boundary really recalls attacks and completes paid equipment cycles")
func finite_cycle_pending() -> bool:
	for equipment: RefCounted in host.state.rows("equipment_state"):
		if equipment.active_remaining_s>0.0:return true
	return false
func qualified(hull_id: String) -> Dictionary:
	var candidate: XJRuntimeState=host.store.clone_state(host.state)
	var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	business.ship_roles.stop_support()
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	business.missions.refresh();business._sync_spawns()
	var home: Dictionary=business.definition("station_defs","station_id","station_anchor_port")
	place(candidate,business,home.station_anchor_id,home.station_id)
	var ship: RefCounted=business.inventory.create_ship(hull_id,home.station_id)
	candidate.player().controlled_ship_id=ship.ship_instance_id;candidate.player().credit=1000000
	place(candidate,business,home.station_anchor_id,home.station_id)
	return {"state":candidate,"business":business,"ship":ship,"home":home}
func support_fixture(hull_id: String="support_weaver",fight: bool=false) -> bool:
	if not await fixture_boundary():return false
	var fixture: Dictionary=qualified(hull_id);var candidate: XJRuntimeState=fixture.state;var business: Gameplay=fixture.business
	remote_patch=install(business,"module_support_patch_i","work:0")
	remote_shield=install(business,"module_shield_lattice_i","utility:0")
	install(business,"module_drone_swarm_i","weapon:0")
	var hold: String=business.inventory.hold(candidate.ship(),T.ContainerKind.CARGO)
	business.inventory.grant(hold,"repair_kit_i",20);business.inventory.grant(hold,"material_structural_stock",50)
	var row: RefCounted=business.exploration.instance("exp_echo_rescue")
	business.exploration._clear_actors(row);row.generation+=1;row.phase="clue";row.operation_kind="";row.operation_remaining_s=0.0;row.elapsed_s=0.0;row.stabilized=false;row.evidence_units=0;row.outcome=""
	var event: Dictionary=business.exploration.definition(row.event_id);place(candidate,business,event.entry_anchor_id)
	check(business.act("exploration_action",row.event_id,1,"survey:"+str(row.generation)).phase==T.ActionPhase.APPLIED,"native qualification uses actual paid survey")
	advance_business(business,float(business.exploration.variant(row).survey_duration_s)/float(business.exploration.balance.em_scan_multiplier)+0.2)
	check(business.act("exploration_action",row.event_id,1,"rescue:"+str(row.generation)).phase==T.ActionPhase.APPLIED,"native qualification creates real rescue and hostile actors")
	advance_business(business,float(business.exploration.variant(row).work_duration_s)+0.2)
	friend_id="";measured_enemy=""
	for member: RefCounted in candidate.rows("exploration_actor_state"):
		if member.event_id!=row.event_id:continue
		if member.actor_role=="escort":friend_id=member.npc_instance_id
		elif measured_enemy.is_empty():measured_enemy=member.npc_instance_id
	if not check(not friend_id.is_empty() and not measured_enemy.is_empty(),"real rescue provides friendly and enemy identities"):business.dispose();return false
	for npc: RefCounted in candidate.rows("npc_state"):
		if npc.npc_instance_id==friend_id or (fight and npc.npc_instance_id==measured_enemy):continue
		npc.alive=false;npc.shield=0.0;npc.armor=0.0;npc.hull=0.0;npc.behavior_phase=T.NpcPhase.DEAD;npc.bounty_claimed=true
	for tactic: RefCounted in candidate.rows("npc_tactic_state"):
		tactic.phase="ready";tactic.has_target_entity_id=false;tactic.target_entity_id="";tactic.remaining_s=0.0;tactic.deployed_drones=0
	for site: RefCounted in candidate.rows("tactical_site_state"):site.respawn_remaining_s=business.definition("tactical_site_defs","site_id",site.site_id).respawn_s
	var friend: RefCounted=candidate.find("npc_state","npc_instance_id",friend_id)
	var axis: Vector3=business.anchor_position(business.definition("anchor_defs","anchor_id",event.entry_anchor_id)).direction_to(business.anchor_position(business.definition("anchor_defs","anchor_id",event.exit_anchor_id)))
	var origin: Vector3=business.position(friend)
	var position: Vector3=origin-axis*300.0
	candidate.ship().pos_x=position.x;candidate.ship().pos_y=position.y;candidate.ship().pos_z=position.z
	if fight:
		var enemy: RefCounted=candidate.find("npc_state","npc_instance_id",measured_enemy)
		var enemy_position: Vector3=origin+axis*250.0+Vector3.UP*80.0
		enemy.pos_x=enemy_position.x;enemy.pos_y=enemy_position.y;enemy.pos_z=enemy_position.z
		var rotation: Quaternion=Basis.looking_at(enemy_position.direction_to(origin),Vector3.UP).get_rotation_quaternion()
		enemy.quat_x=rotation.x;enemy.quat_y=rotation.y;enemy.quat_z=rotation.z;enemy.quat_w=rotation.w
	else:
		var stats: Dictionary=business.ship_roles.target_limits(friend)
		friend.armor=maxf(0.0,float(stats.armor_max)-180.0);friend.shield=maxf(0.0,float(stats.shield_max)-100.0)
	var m: Dictionary=business.metrics(candidate.ship())
	for layer_name: String in ["shield","armor","hull","energy"]:candidate.ship().set(layer_name,m[layer_name+"_max"])
	candidate.ship().heat=0.0;candidate.ship().overheated=false
	business.dispose();return await activate(candidate)
func scout_fixture(hull_id: String) -> bool:
	if not await fixture_boundary():return false
	var fixture: Dictionary=qualified(hull_id);var candidate: XJRuntimeState=fixture.state;var business: Gameplay=fixture.business
	scout_scanner=install(business,"module_scanner_beacon_i","utility:0")
	measured_enemy=""
	for npc: RefCounted in candidate.rows("npc_state"):
		if business.tactics.handles(npc.spawn_id):measured_enemy=npc.npc_instance_id;break
	var enemy: RefCounted=candidate.find("npc_state","npc_instance_id",measured_enemy)
	if not check(enemy!=null,"actual reconnaissance target exists"):business.dispose();return false
	var spawn: Dictionary=business.definition("npc_spawn_defs","spawn_id",enemy.spawn_id)
	var stats: Dictionary=business.definition("npc_full_defs","npc_id",spawn.npc_id)
	enemy.alive=true;enemy.shield=stats.shield_max;enemy.armor=stats.armor_max;enemy.hull=stats.hull_max;enemy.behavior_phase=T.NpcPhase.PATROL;enemy.bounty_claimed=false;enemy.loot_claimed=false
	var site_id: String=business.tactics.bindings[enemy.spawn_id].site_id
	candidate.find("tactical_site_state","site_id",site_id).respawn_remaining_s=0.0
	place(candidate,business,business.definition("npc_spawn_defs","spawn_id",enemy.spawn_id).anchor_id)
	enemy.pos_x=candidate.ship().pos_x;enemy.pos_y=candidate.ship().pos_y;enemy.pos_z=candidate.ship().pos_z+float(business.rule("target_marker_detection_range_m"))*1.25
	business.dispose();return await activate(candidate)
func freight_fixture() -> bool:
	if not await fixture_boundary():return false
	var fixture: Dictionary=qualified("transport_caravan");var business: Gameplay=fixture.business
	install(business,"module_engine_vector_i","utility:0")
	business.dispose();return await activate(fixture.state)
func reference_cost() -> int:
	var g: Gameplay=host.gameplay;var ship: RefCounted=host.state.ship()
	var cost: int=int(g.definition("ship_defs","ship_id",ship.ship_def_id).base_ask_credit)
	for equipment: RefCounted in g.equipped(ship):cost+=int(g.definition("item_defs","item_id",equipment.module_def_id).base_ask_credit)
	for container: RefCounted in host.state.rows("container_state"):
		if not container.has_ship_instance_id or container.ship_instance_id!=ship.ship_instance_id or container.kind==T.ContainerKind.SLOT:continue
		for stack: RefCounted in host.state.rows("inventory_stack_state"):
			if stack.container_id==container.container_id:cost+=stack.quantity*int(g.definition("item_defs","item_id",stack.item_def_id).base_ask_credit)
	return cost
func protection_comparison() -> void:
	var results: Dictionary={}
	for hull_id: String in ["support_weaver","cruiser_horizon"]:
		if not await support_fixture(hull_id,true):return
		host.ui.show_page("");host.ui.tick(1.0);await frames(3)
		var cost: int=reference_cost()
		check(cost<=225000,"identical defensive/drone loadouts fit the common protection budget "+hull_id)
		var initial: float=hp(friend_id);var enemy_initial: float=hp(measured_enemy)
		await run_for(2.0)
		check(hp(friend_id)<initial,"actual hostile fire reaches the friendly convoy "+hull_id)
		host.ui._select_target(measured_enemy);host.ui.tick(1.0);await frames(3)
		await click(host.ui.overview.action_buttons.combat_toggle,"native enables common drone fire "+hull_id)
		host.ui._select_target(friend_id);host.ui.tick(1.0);await frames(3)
		if hull_id=="support_weaver":
			await click(host.ui.overview.support_buttons[remote_shield],"native adds defensive support under real fire")
			check(host.gameplay.ship_roles.channel(remote_shield)!=null,"support cycle binds while enemy attacks")
		else:check(host.ui.overview.support_buttons.is_empty(),"combat cruiser retains self repair without acquiring remote repair")
		# Both pilots approach the moving convoy while maintaining the same enemy
		# fire target. This is a real navigation command, not an HP/AI override.
		if not host.ui.overview.action_buttons.nav_approach.is_visible_in_tree():await click(host.ui.overview.more_actions,"native reveals convoy following command "+hull_id)
		await click(host.ui.overview.action_buttons.nav_approach,"native follows the convoy "+hull_id)
		await run_for(12.0)
		var final_hp: float=hp(friend_id)
		check(final_hp>0.0 and hp(measured_enemy)<enemy_initial,"real protection and offensive results are measurable "+hull_id)
		results[hull_id]=final_hp
		observations.append({"kind":"protection","hull":hull_id,"reference_cost":cost,"budget":225000,"initial_friend_hp":initial,"final_friend_hp":final_hp,"initial_enemy_hp":enemy_initial,"final_enemy_hp":hp(measured_enemy)})
		await capture("roles-protection-"+hull_id)
	check(results.has("support_weaver") and results.has("cruiser_horizon") and float(results.support_weaver)>float(results.cruiser_horizon),"support preserves more convoy HP in the same budget scenario while both attack")
func wait_navigation() -> bool:
	host.set_process(true);host.set_physics_process(true)
	# AU legs have their real travel duration; loaded carriers also need time
	# for collider-safe turning and braking before the interaction threshold.
	var deadline: int=Time.get_ticks_msec()+180000
	var next_log: int=Time.get_ticks_msec()+10000
	while (host.local_navigation.active() or host.busy) and Time.get_ticks_msec()<deadline:
		await get_tree().physics_frame
		if Time.get_ticks_msec()>=next_log:
			print("ROLE_NAV_PROGRESS ",JSON.stringify({"phase":host.local_navigation.phase,"mode":host.local_navigation.mode,"gate_stage":host.local_navigation._gate_approach_phase,"target":host.local_navigation.target_id,"distance":host.world.target_distance(host.local_navigation.target_id),"speed":host.world.flight.velocity.length(),"paused":host._paused(),"busy":host.busy}))
			next_log+=10000
	host.set_process(false);host.set_physics_process(false);host._process(0.0);await frames(3)
	if host.local_navigation.active() or host.busy:await capture("roles-navigation-stall")
	return check(not host.local_navigation.active() and not host.busy,"actual loaded navigation reaches a stable local target")
func complete_freight_trip(id: String) -> bool:
	var d: Dictionary=host.gameplay.consignments.definition(id)
	var destination: Dictionary=host.gameplay.definition("station_defs","station_id",d.destination_station_id)
	var legs: int=0
	while host.state.current_sector()!=destination.sector_id and legs<8:
		var info: Dictionary=host.gameplay.consignments.guidance(id)
		if not check(not str(info.waypoint_id).is_empty() and str(info.route_reason).is_empty(),"current full-load itinerary has a legal next gate"):return false
		host.ui.tick(1.0);await frames(3)
		if not host.local_navigation.active():await click(host.ui.mission_travel_button,"native follows the loaded freight itinerary")
		if not host.local_navigation.active() and not bool(host.interaction_context(info.waypoint_id).get("ready",false)):
			print("ROLE_NAV_REJECTED ",JSON.stringify({"reason":host._save_block_reason(),"toast":host.ui.toast.text,"finite_cycle":finite_cycle_pending()}))
			check(false,"freight navigation is accepted or already physically at its gate");return false
		if not await wait_navigation():return false
		var context: Dictionary=host.interaction_context(info.waypoint_id)
		if not bool(context.get("ready",false)) and str(context.get("reason","")).contains("交战"):
			var attackers: Array[Dictionary]=[]
			for npc: RefCounted in host.state.rows("npc_state"):
				if npc.alive and host.gameplay.same_entity_site("ship",host.state.ship(),"npc",npc) and npc.behavior_phase in [T.NpcPhase.ACQUIRE,T.NpcPhase.PURSUE,T.NpcPhase.ATTACK,T.NpcPhase.DISENGAGE]:attackers.append({"id":npc.npc_instance_id,"spawn":npc.spawn_id,"phase":npc.behavior_phase})
			print("ROLE_GATE_COMBAT ",JSON.stringify({"remaining_s":host.gameplay.combat_remaining_s,"attackers":attackers,"site":host.gameplay.spatial_site("ship",host.state.ship().ship_instance_id)}))
			host.set_process(true);host.set_physics_process(true)
			var combat_deadline: int=Time.get_ticks_msec()+45000
			while host.gameplay.in_combat() and Time.get_ticks_msec()<combat_deadline:await get_tree().physics_frame
			host.set_process(false);host.set_physics_process(false);host._process(0.0);context=host.interaction_context(info.waypoint_id)
		if not bool(context.get("ready",false)):print("ROLE_FREIGHT_GATE_CONTEXT ",JSON.stringify(context))
		if not check(bool(context.get("ready",false)),"actual approach satisfies gate distance speed and loaded mass"):return false
		var origin: String=host.state.current_sector();var credit: int=host.state.player().credit
		var units: int=host.gameplay.consignments.instance(id).cargo_units
		# A completed AU leg can queue its ordinary autosave. Let the real
		# asynchronous writer finish before native interaction is permitted.
		await settle()
		if not root.has_focus():root.grab_focus();await frames(2)
		if not check(host._keyboard_control_allowed(),"native gate input waits for the real save barrier"):return false
		await key(KEY_F)
		host.set_process(true);host.set_physics_process(true)
		var deadline: int=Time.get_ticks_msec()+45000
		while (host.travel.active() or host.busy) and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
		await frames(4);host.set_process(false);host.set_physics_process(false);host._process(0.0)
		if host.state.current_sector()==origin or host.travel.active():
			print("ROLE_TRANSFER_REJECTED ",JSON.stringify({"phase":host.travel.phase,"travel_error":host.travel.last_error,"store_error":host.store.last_error,"toast":host.ui.toast.text,"context":host.interaction_context(info.waypoint_id),"save_block":host._save_block_reason(),"state_speed":Vector3(host.state.ship().vel_x,host.state.ship().vel_y,host.state.ship().vel_z).length(),"paused":host._paused()}))
		if not check(host.state.current_sector()!=origin and not host.travel.active(),"real wormhole transfer commits the loaded carrier"):return false
		check(host.gameplay.consignments.instance(id).cargo_units==units,"custody survives real origin/destination SQLite endpoints")
		observations.append({"kind":"freight_leg","origin":origin,"destination":host.state.current_sector(),"cargo_units":units,"mass_kg":host.gameplay.metrics(host.state.ship()).total_mass_kg,"gate_credit":credit-host.state.player().credit})
		legs+=1
	if not check(host.state.current_sector()==destination.sector_id,"real carrier reaches the freight destination system"):return false
	host.ui.tick(1.0);await frames(3)
	if not host.local_navigation.active():await click(host.ui.mission_travel_button,"native approaches the actual receiving station")
	if not await wait_navigation():return false
	var context: Dictionary=host.interaction_context(destination.station_id)
	if not bool(context.get("ready",false)):print("ROLE_FREIGHT_DOCK_CONTEXT ",JSON.stringify(context))
	if not check(bool(context.get("ready",false)),"actual station exterior meets docking conditions"):return false
	await key(KEY_F);await settle();host.set_process(false);host.set_physics_process(false)
	if not check(host.state.player().has_docked_station_id and host.state.player().docked_station_id==destination.station_id,"native input docks the still-loaded carrier at its receiving station"):return false
	await show("consignments");var credit: int=host.state.player().credit;var row: RefCounted=host.gameplay.consignments.instance(id);var units: int=row.cargo_units
	await click(host.ui.body.find_child("Freight_deliver_"+id,true,false),"native delivers physically transported goods")
	check(host.gameplay.consignments.instance(id).cargo_units==0 and host.gameplay.consignments.instance(id).delivered_units==units,"real receiving station removes only its own entrusted goods")
	await capture("roles-freight-delivered")
	await click(host.ui.body.find_child("Freight_claim_"+id,true,false),"native claims physically earned freight payment")
	check(host.state.player().credit==credit+units*(int(d.deposit_per_unit)+int(d.reward_per_unit)),"native freight settlement returns exact delivered deposits and rewards")
	observations.append({"kind":"freight_delivery","legs":legs,"delivered_units":units,"station":destination.station_id,"payment_credit":host.state.player().credit-credit})
	return true
func run() -> void:
	directory=OS.get_environment("XJ_ROLES_WORLD_V32_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/roles-world-v32/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped native role world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","舰种能力原生",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if OS.get_environment("XJ_ROLES_TRIP_ONLY")=="1":
		await freight_checks();await finish();return
	if not await support_fixture():await finish();return
	host.ui.show_page("");host.ui._select_target(friend_id);host.ui.tick(1.0);await frames(5)
	var target: RefCounted=host.state.find("npc_state","npc_instance_id",friend_id)
	var before: float=target.armor;var hold: String=host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO);var kits: int=host.gameplay.inventory.count(hold,"repair_kit_i",true)
	var panel: XJOverviewPanel=host.ui.overview
	check(panel.support_box.is_visible_in_tree() and panel.support_buttons.has(remote_patch),"selected friendly vessel exposes the real repair controls")
	await click(panel.support_buttons[remote_patch],"native starts armor support")
	await settle();host.set_process(false);host.set_physics_process(false)
	check(host.gameplay.ship_roles.channel(remote_patch)!=null and host.gameplay.inventory.count(hold,"repair_kit_i",true)==kits-1,"native support pays an ordinary kit and binds the actual target")
	await frames(4)
	check(host.world.tactical_view.lines.has("player_support:"+remote_patch),"real paid cycle draws a following support line")
	await capture("roles-remote-cycle")
	await run_for(2.0)
	check(target.armor==before and host.gameplay.ship_roles.channel(remote_patch).remaining_s>0.0,"actual unfinished cycle does not heal early")
	await run_for(3.2)
	check(target.armor>before,"native physics completes a real friendly repair")
	var measured_repair: RefCounted=host.state.find("telemetry_repair_state","repair_kind","provided")
	check(measured_repair!=null and is_equal_approx(float(measured_repair.restored_hp),float(target.armor-before)),"provided repair measurement equals actual restored friendly HP")
	await capture("roles-remote-healed")
	host.ui.tick(1.0);await frames(3)
	await click(host.ui.overview.support_buttons[remote_patch],"native stops armor support")
	check(host.gameplay.ship_roles.channel(remote_patch)==null,"native stop removes the channel")
	await show("ships");await click(host.ui.body.find_child("ShipRolesEntry",true,false),"native opens concise role matrix")
	await capture("roles-eighteen-capabilities")
	if not await scout_fixture("frigate_lantern"):await finish();return
	host.ui.show_page("");host.ui.tick(1.0);await frames(5)
	var distance: float=host.world.flight.position.distance_to(host.world.npcs[measured_enemy].position)
	check(distance>host.gameplay.rule("target_marker_detection_range_m") and host.world.contact_visible(host.world.targets[measured_enemy],distance) and host.ui.overview.target_buttons.has(measured_enemy),"scout detects a real far contact beyond the common range")
	check(is_equal_approx(host.ui.navigation_hud.sensor_limit,host.gameplay.ship_roles.detection_range()) and host.local_navigation.inspect(measured_enemy).approach_ready,"radar and navigation consume the same extended sensor policy")
	await capture("roles-scout-contact")
	await click(host.ui.equipment_bar.module_buttons[scout_scanner],"native disables the reconnaissance scanner")
	host.ui.tick(1.0);await frames(4)
	check(not host.world.contact_visible(host.world.targets[measured_enemy],distance) and not host.ui.overview.target_buttons.has(measured_enemy),"disabled scanner removes the actual far contact")
	check(is_equal_approx(host.ui.navigation_hud.sensor_limit,host.gameplay.rule("target_marker_detection_range_m")) and not host.local_navigation.inspect(measured_enemy).approach_ready,"disabled scanner also removes extended radar and navigation eligibility")
	await protection_comparison()
	await freight_checks()
	await finish()
func freight_checks() -> void:
	if not await freight_fixture():await finish();return
	await show("missions");await click(host.ui.body.find_child("MissionFreight",true,false),"native opens freight contracts")
	await capture("roles-freight-offer")
	var id: String="freight_anchor_echo";var credit: int=host.state.player().credit;var mass: float=host.gameplay.metrics(host.state.ship()).total_mass_kg
	await click(host.ui.body.find_child("Freight_dispatch_"+id,true,false),"native dispatches a fully loaded order")
	await settle();host.set_process(false);host.set_physics_process(false)
	var order: RefCounted=host.gameplay.consignments.instance(id);var d: Dictionary=host.gameplay.consignments.definition(id)
	check(order.cargo_units==24 and host.state.player().credit==credit-24*int(d.deposit_per_unit)-int(d.fee_credit),"native dispatch debits the exact deposit and fee")
	check(is_equal_approx(host.gameplay.metrics(host.state.ship()).total_mass_kg,mass+24*float(d.unit_mass_kg)),"native loaded mass includes all entrusted cargo")
	check(is_equal_approx(host.travel._mass(host.state.ship()),host.gameplay.metrics(host.state.ship()).total_mass_kg),"atomic travel validator uses the same complete entrusted mass as the HUD and route planner")
	await click(host.ui.body.find_child("FreightRoute_"+id,true,false),"native previews the current loaded-hull route")
	check(host.ui.page=="map" and host.ui.resource_chart.selected_sector=="sector_echo","freight route uses the actual destination star chart")
	await capture("roles-freight-route")
	await host._command("undock","",1,"");await settle();host.set_process(false);host.set_physics_process(false);host.ui.tick(1.0);await frames(3)
	check(host.ui.objective.text.contains("在途24批") and host.ui.mission_travel_button.get_meta("action")=="consignment_navigate","actual cargo is tracked in the compact flight HUD")
	await capture("roles-freight-hud")
	if not await complete_freight_trip(id):await finish();return
	id="freight_echo_mirror";await show("consignments")
	await click(host.ui.body.find_child("Freight_dispatch_"+id,true,false),"native dispatches the second independent route")
	await host._command("undock","",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	root.size=Vector2i(1280,720);root.content_scale_factor=1.0;root.content_scale_size=Vector2i(640,360);await show("consignments")
	await click(host.ui.body.find_child("Freight_withdraw_"+id,true,false),"high-scale freight withdrawal remains reachable")
	check(host.gameplay.consignments.instance(id).phase=="ready","native in-space withdrawal produces loss and settlement")
	await capture("roles-freight-1280-200")
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"observations":observations,"trip_only":OS.get_environment("XJ_ROLES_TRIP_ONLY")=="1"}
	print("ROLES_WORLD_V32_FINAL_JSON ",JSON.stringify(summary));print("ROLES_WORLD_V32_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
