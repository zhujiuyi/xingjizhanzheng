extends "auxiliary_world_v41.gd"
## Hulls/licenses/gear/funds, isolation and entry poses are explicit fixtures.
## Weapons, hits, resource use, auxiliary repair, retreat and loss use real Main.
var fighter_id: String=""
var support_id: String=""
var gun_id: String=""
var fleet_repair_id: String=""
var enemy_id: String=""
var ammo_id: String=""
var real_damage: float=0.0
var real_taken: float=0.0
var fleet_repaired: float=0.0
var retreat_m: float=0.0
var loss_checked: bool=false
var return_checked: bool=false
var source_empty_shots: int=0

func _ready() -> void:
	get_tree().set_meta("xj_owned_combat_world_v43_diagnostic",true)
	get_tree().create_timer(540.0).timeout.connect(func():check(false,"owned combat native watchdog");finish())
	run.call_deferred()
func equip_for(business: Gameplay,module: String,slot: String) -> String:
	var id: String=business.inventory.grant(business.inventory.warehouse(business.station()),module,1)[0]
	check(business.act("fit_module",id,1,slot).phase==T.ActionPhase.APPLIED,"real spare hull fits "+module);return id
func recruit(business: Gameplay,id: String,ship_id: String) -> void:
	check(business.crew.execute(id,"hire",business.crew.token(id)) and business.crew.execute(id,"assign",business.crew.token(id),ship_id),"actual paid crew role "+id)
func isolate(business: Gameplay,selected_id: String="") -> void:
	for npc: RefCounted in business.state.rows("npc_state"):
		if npc.npc_instance_id==selected_id or business.owned_fleet.friendly(npc.npc_instance_id):continue
		business.frontier._dormant(npc)
		var spawn: Dictionary=business.definition("npc_spawn_defs","spawn_id",npc.spawn_id)
		if spawn.respawn_s!=null:npc.respawn_remaining_s=float(spawn.respawn_s)
	for group: RefCounted in business.state.rows("encounter_state"):
		group.respawn_remaining_s=float(business.definition("encounter_defs","encounter_id",group.encounter_id).respawn_seconds) if business.encounters.remaining(group.encounter_id)==0 else 0.0
func prepared_fleet() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	candidate.player().credit=3000000
	var home: Dictionary=business.definition("station_defs","station_id","station_anchor_port")
	var mother: RefCounted=business.inventory.create_ship("cruiser_horizon",home.station_id);var fighter: RefCounted=business.inventory.create_ship("frigate_kestrel",home.station_id);var support: RefCounted=business.inventory.create_ship("support_weaver",home.station_id)
	fighter_id=fighter.ship_instance_id;support_id=support.ship_instance_id;candidate.player().controlled_ship_id=fighter_id;place(candidate,business,home.station_anchor_id,home.station_id)
	gun_id=equip_for(business,"module_kinetic_needle_ii","weapon:0");ammo_id=str(business.definition("weapon_defs","module_id","module_kinetic_needle_ii").ammo_item_id);business.inventory.grant(business.inventory.hold(fighter,T.ContainerKind.CARGO),ammo_id,100)
	recruit(business,"crew_pilot_1",fighter_id);recruit(business,"crew_gunner_1",fighter_id)
	candidate.player().controlled_ship_id=support_id;place(candidate,business,home.station_anchor_id,home.station_id)
	fleet_repair_id=equip_for(business,"module_aux_repair_i","work:0");business.inventory.grant(business.inventory.hold(support,T.ContainerKind.CARGO),"repair_kit_i",6)
	recruit(business,"crew_pilot_2",support_id);recruit(business,"crew_engineer_1",support_id)
	candidate.player().controlled_ship_id=mother.ship_instance_id;place(candidate,business,home.station_anchor_id,home.station_id)
	for id: String in [fighter_id,support_id]:check(business.owned_fleet.execute(id,"deploy",business.owned_fleet.token(id)),"existing hull joins physical owned fleet")
	check(business.act("undock").phase==T.ActionPhase.APPLIED,"human mother launches normally")
	business.missions.refresh();business._sync_spawns();business.dispose();return await activate(candidate)
func v43_combat_pose(heavy: bool) -> bool:
	if not await fixture_boundary():return false
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var selected: RefCounted=null;var maximum: float=0
	for npc: RefCounted in candidate.rows("npc_state"):
		var spawn: Dictionary=business.definition("npc_spawn_defs","spawn_id",npc.spawn_id);var stats: Dictionary=business.definition("npc_full_defs","npc_id",spawn.npc_id)
		if spawn.occurrence_mode=="mission_scoped" or business.tactics.instance(npc.npc_instance_id)!=null or not business.civilizations.hostile_to(candidate.ship().ship_instance_id,npc.npc_instance_id):continue
		if heavy:
			if float(stats.raw_dps)>maximum:maximum=float(stats.raw_dps);selected=npc
		elif spawn.sector_id!="sector_anchor" and float(stats.raw_dps)>=8 and float(stats.raw_dps)<=20:selected=npc;break
	if not check(selected!=null,"authored balanced hostile selected for "+("loss" if heavy else "fire")):business.dispose();return false
	var spawn: Dictionary=business.definition("npc_spawn_defs","spawn_id",selected.spawn_id);var stats: Dictionary=business.definition("npc_full_defs","npc_id",spawn.npc_id);var anchor: Dictionary=business.definition("anchor_defs","anchor_id",spawn.anchor_id)
	place(candidate,business,spawn.anchor_id);candidate.ship().pos_x=float(anchor.x_m)+(600.0 if heavy else 0.0);candidate.ship().pos_y=float(anchor.y_m)+250;candidate.ship().pos_z=float(anchor.z_m)+(-200.0 if heavy else 1400.0)
	selected.alive=true;selected.shield=float(stats.shield_max);selected.armor=float(stats.armor_max);selected.hull=float(stats.hull_max);selected.behavior_phase=T.NpcPhase.PATROL;selected.wait_remaining_s=0;selected.cooldown_remaining_s=0;selected.respawn_remaining_s=0;selected.pos_x=anchor.x_m;selected.pos_y=float(anchor.y_m)+250;selected.pos_z=anchor.z_m;selected.quat_x=0;selected.quat_y=1;selected.quat_z=0;selected.quat_w=0
	isolate(business,selected.npc_instance_id)
	business.owned_fleet.follow_arrival()
	var fighter: RefCounted=business.owned_fleet.actor(business.owned_fleet.row(fighter_id));fighter.pos_x=anchor.x_m;fighter.pos_y=selected.pos_y;fighter.pos_z=float(anchor.z_m)+400;fighter.quat_x=0;fighter.quat_y=0;fighter.quat_z=0;fighter.quat_w=1;business.owned_fleet.sync_hull(business.owned_fleet.row(fighter_id))
	var support: RefCounted=business.owned_fleet.actor(business.owned_fleet.row(support_id));support.pos_x=float(anchor.x_m)+600;support.pos_y=selected.pos_y;support.pos_z=float(anchor.z_m)+1400;business.owned_fleet.sync_hull(business.owned_fleet.row(support_id))
	if not heavy:business.owned_fleet.ship(fighter_id).armor-=60;business.owned_fleet.sync_actor_health(fighter_id)
	enemy_id=selected.npc_instance_id;business.dispose();return await activate(candidate)
func order(id: String,kind: String) -> void:
	host.ui.fleet_section="owned";host.ui.target_id=enemy_id;await show("ships")
	await click(host.ui.body.find_child("Owned_"+kind+"_"+id,true,false),"actual owned order "+kind)
	host.ui.show_page("")
func run() -> void:
	directory=OS.get_environment("XJ_OWNED_COMBAT_WORLD_V43_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/owned-combat-world-v43/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped owned combat native world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=AtomicHost.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5);await host._command("new_world","自有舰队实战",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await prepared_fleet() or not await v43_combat_pose(false):await finish();return
	check(not host.world.in_safe_zone(host.world.npcs[fighter_id].position),"actual fight is outside station safety")
	var fighter: RefCounted=host.gameplay.owned_fleet.ship(fighter_id);var hold: String=host.gameplay.inventory.hold(fighter,T.ContainerKind.CARGO);var ammo: int=host.gameplay.inventory.count(hold,ammo_id,false);var hulls: int=host.state.rows("ship_state").size()
	await order(support_id,"advance");await order(fighter_id,"focus")
	host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline and host.state.find("npc_state","npc_instance_id",enemy_id).alive and fighter.status!=T.ShipStatus.DESTROYED:
		for shot: RefCounted in host.world.projectiles.active:
			if shot.owner_id==support_id:source_empty_shots+=1
		await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0)
	real_damage=host.gameplay.owned_fleet.total().damage_dealt;real_taken=host.gameplay.owned_fleet.total().damage_taken
	if not check(real_damage>0 and not host.state.find("npc_state","npc_instance_id",enemy_id).alive,"actual owned weapons hit and destroy a balanced authored enemy"):await finish();return
	check(fighter.status==T.ShipStatus.FLYING and real_taken>0 and host.gameplay.inventory.count(hold,ammo_id,false)<ammo,"authored enemy really hits original hull and actual own ammunition is consumed")
	check(source_empty_shots==0 and host.gameplay.owned_fleet.stats(support_id).raw_dps==0,"unarmed support hull never emits descriptor fire")
	check(host.gameplay.crew.member("crew_gunner_1").contribution_total==real_damage,"owned effective damage belongs to its own gunner career")
	check(host.state.rows("ship_state").size()==hulls,"actual fleet victory creates no extra privately owned hull")
	await capture("owned-real-combat")
	if not await fixture_boundary():await finish();return
	await order(fighter_id,"regroup");await order(support_id,"regroup");await run_for(12.0)
	var support: RefCounted=host.gameplay.owned_fleet.ship(support_id);var support_energy: float=support.energy;var support_hold: String=host.gameplay.inventory.hold(support,T.ContainerKind.CARGO);var kits: int=host.gameplay.inventory.count(support_hold,"repair_kit_i",true);var armor: float=fighter.armor
	print("OWNED_AUX_ORIGIN ",JSON.stringify({"mother":str(host.gameplay.position(host.state.ship())),"support":str(host.gameplay.position(support)),"patient":str(host.gameplay.position(fighter)),"armor_before":armor,"sight":host.world.line_of_sight(host.gameplay.position(support),host.gameplay.position(fighter),host.world.npcs[support_id].get_rid(),fighter_id)}))
	host.ui._select_target(fighter_id);await show("drones")
	await click(host.ui.body.find_child("AuxiliaryLaunch_"+fleet_repair_id+"_target",true,false),"actual owned support mother launches its own repair drones")
	check(support.energy==support_energy-float(host.gameplay.definition("module_defs","module_id","module_aux_repair_i").energy_eu) and host.gameplay.inventory.count(support_hold,"repair_kit_i",true)==kits-1,"owned auxiliary consumes original support hull energy and cargo")
	await run_for(8.0);fleet_repaired=fighter.armor-armor
	print("OWNED_AUX_RESULT ",JSON.stringify({"armor_after":fighter.armor,"actual_current_armor":host.gameplay.owned_fleet.ship(fighter_id).armor,"bay_hp":host.gameplay.auxiliary_drones.bay(fleet_repair_id).repaired_hp,"fleet_hp":host.gameplay.owned_fleet.total().provided_repair_hp,"remaining_units":host.gameplay.auxiliary_drones.bay(fleet_repair_id).deployed_units}))
	for drone: RefCounted in host.gameplay.drone_control.live.values():print("OWNED_AUX_ENTITY ",JSON.stringify({"role":drone.role_kind,"fired":drone.fired,"returning":drone.returning,"lost_communication":drone.communication_lost,"position":str(host.gameplay.position(drone)),"target":drone.target_id}))
	check(fleet_repaired>0 and fleet_repaired<=40 and host.gameplay.owned_fleet.total().provided_repair_hp==fleet_repaired,"actual owned auxiliary mother repairs and records its own finite contribution")
	await capture("owned-auxiliary-mother")
	if not await drain_sorties():await finish();return
	await order(fighter_id,"retreat");var deployment: RefCounted=host.gameplay.owned_fleet.row(fighter_id);var origin: Vector3=Vector3(deployment.retreat_origin_x,deployment.retreat_origin_y,deployment.retreat_origin_z);var armor_return: float=fighter.armor
	host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+45000
	while deployment.phase=="retreating" and Time.get_ticks_msec()<deadline:
		retreat_m=maxf(retreat_m,origin.distance_to(host.gameplay.position(fighter)));await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0)
	if not check(deployment.phase=="returning" and retreat_m>=float(host.gameplay.owned_fleet.balance.retreat_distance_m),"real owned body disengages before strategic station return"):await finish();return
	check(fighter.armor==armor_return and not deployment.has_npc_instance_id and host.gameplay.owned_fleet.removal_reason(fighter_id)!="","return carries actual damage and locks the same asset")
	await show("pause");var remaining: float=deployment.return_remaining_s;var paused_tick: int=host.state.snapshot.meta.simulation_tick;await run_for(0.6)
	check(host._paused() and deployment.return_remaining_s==remaining and host.state.snapshot.meta.simulation_tick==paused_tick,"actual pause page freezes owned return and simulation clock")
	await show("");check(not host._paused(),"leaving actual pause page resumes the world before countdown boundary")
	check(host.store.save(host.state,"manual",1),"real return state seals without discarding original gear "+host.store.last_error)
	# Declared countdown boundary tests arrival without claiming a natural120s wait.
	deployment.return_remaining_s=0.1;await run_for(0.3)
	return_checked=check(deployment.phase=="docked" and fighter.armor==armor_return and fighter.has_station_id and fighter.station_id==deployment.return_station_id and host.state.find("item_instance_state","item_instance_id",gun_id)!=null,"actual countdown completion docks original damaged hull with original weapon")
	if not return_checked:await finish();return
	await capture("owned-real-return")
	if not await fixture_boundary():await finish();return
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog);var station: Dictionary=business.definition("station_defs","station_id",business.owned_fleet.ship(fighter_id).station_id)
	place(candidate,business,station.station_anchor_id,station.station_id);business.owned_fleet.follow_arrival();var token: String=business.owned_fleet.token(fighter_id);var credits: int=candidate.player().credit
	check(business.owned_fleet.execute(fighter_id,"deploy",token) and candidate.player().credit==credits-business.owned_fleet.quote(fighter_id),"same returned hull redeploys with exact second preparation fee")
	check(not business.owned_fleet.execute(fighter_id,"deploy",token),"old deployment callback cannot duplicate returned original hull")
	check(business.act("undock").phase==T.ActionPhase.APPLIED,"actual redeployed party undocks for heavy encounter");business.dispose()
	if not await activate(candidate) or not await v43_combat_pose(true):await finish();return
	await order(fighter_id,"regroup");fighter=host.gameplay.owned_fleet.ship(fighter_id);hulls=host.state.rows("ship_state").size();var money: int=host.state.player().credit;var losses: int=host.gameplay.owned_fleet.total().losses
	host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+90000
	while fighter.status!=T.ShipStatus.DESTROYED and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0)
	print("OWNED_LOSS_OBSERVATION ",JSON.stringify({"fighter_status":fighter.status,"fighter_shield":fighter.shield,"fighter_armor":fighter.armor,"fighter_hull":fighter.hull,"enemy_alive":host.state.find("npc_state","npc_instance_id",enemy_id).alive,"fighter_position":str(host.gameplay.position(fighter)),"enemy_position":str(host.gameplay.position(host.state.find("npc_state","npc_instance_id",enemy_id))),"money_delta":host.state.player().credit-money}))
	loss_checked=check(fighter.status==T.ShipStatus.DESTROYED and host.gameplay.owned_fleet.row(fighter_id).phase=="lost" and host.state.find("npc_state","npc_instance_id",fighter_id)==null,"authored heavy enemy actually destroys original owned hull and removes its actor")
	check(host.gameplay.owned_fleet.total().losses==losses+1 and host.state.rows("ship_state").size()==hulls and host.state.player().credit==money,"actual own loss creates no free replacement bounty or deposit refund")
	check(host.gameplay.crew.member("crew_pilot_1").phase=="injured" and host.gameplay.crew.member("crew_gunner_1").phase=="injured" and host.gameplay.crew.assignment("crew_pilot_1")==null,"actual lost pilot and gunner are rescued and removed from active posts")
	await capture("owned-real-loss")
	# Isolate the remaining test boundary; already launched shots still resolve.
	isolate(host.gameplay)
	if not await fixture_boundary():await finish();return
	await run_for(host.gameplay.combat_remaining_s+0.1)
	check(host.store.save(host.state,"manual",2),"physical battle repair return and original asset loss remain saveable "+host.store.last_error)
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var result: String="PASS" if failures.is_empty() else "FAIL"
	print("OWNED_COMBAT_WORLD_V43_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"damage_dealt":real_damage,"damage_taken":real_taken,"owned_repaired_hp":fleet_repaired,"retreat_m":retreat_m,"returned":return_checked,"lost":loss_checked,"empty_shots":source_empty_shots,"performance":frame_metrics.report()}))
	print("OWNED_COMBAT_WORLD_V43_RESULT ",result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
