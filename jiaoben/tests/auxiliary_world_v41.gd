extends "owned_fleet_world_v40.gd"
## Funds, hulls/gear/licenses, initial damage and encounter poses are fixtures.
## Sorties, effective repair, sensing, recovery and interception use real Main.
var repair_id: String=""
var recon_id: String=""
var contact_id: String=""
var repaired_hp: float=0.0
var recon_distance_m: float=0.0
var intercepted: bool=false
var frozen_intel: bool=false
var restored: bool=false
var comm_returned: bool=false
var blocked_sensing: bool=false

func state_signature() -> String:
	# SQLite row order is not state. Include every field, key and RNG stream
	# while canonicalizing relational rows for comparison after reopening.
	var values: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		var rows: Array=[]
		for row: RefCounted in host.state.rows(table):rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary):return JSON.stringify(a)<JSON.stringify(b));values[table]=rows
	return JSON.stringify(values)

func _ready() -> void:
	get_tree().set_meta("xj_auxiliary_world_v41_diagnostic",true)
	get_tree().create_timer(480.0).timeout.connect(func():check(false,"auxiliary native watchdog");finish())
	run.call_deferred()

func prepare_owned() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	candidate.player().credit=1000000
	var home: Dictionary=business.definition("station_defs","station_id","station_anchor_port");var warehouse: String=business.inventory.warehouse(home.station_id)
	var cruiser: RefCounted=business.inventory.create_ship("cruiser_horizon",home.station_id);candidate.player().controlled_ship_id=cruiser.ship_instance_id;place(candidate,business,home.station_anchor_id,home.station_id)
	repair_id=business.inventory.grant(warehouse,"module_aux_repair_i",1)[0];recon_id=business.inventory.grant(warehouse,"module_aux_recon_ii",1)[0]
	check(business.act("fit_module",repair_id,1,"work:0").phase==T.ActionPhase.APPLIED,"actual permitted cruiser fits repair work bay")
	check(business.act("fit_module",recon_id,1,"work:1").phase==T.ActionPhase.APPLIED,"actual permitted cruiser fits recon work bay")
	business.inventory.grant(business.inventory.hold(cruiser,T.ContainerKind.CARGO),"repair_kit_i",12);business.inventory.grant(warehouse,"material_structural_stock",100)
	var buddy: RefCounted=business.inventory.create_ship("frigate_kestrel",home.station_id);owned_id=buddy.ship_instance_id
	check(not business.weapon_fit_reason(buddy,"module_aux_repair_i").is_empty(),"ordinary combat frigate cannot acquire auxiliary role permission")
	check(business.crew.execute("crew_pilot_1","hire",business.crew.token("crew_pilot_1")) and business.crew.execute("crew_pilot_1","assign",business.crew.token("crew_pilot_1"),owned_id),"paid pilot prepares actual repair patient")
	check(business.crew.execute("crew_engineer_1","hire",business.crew.token("crew_engineer_1")) and business.crew.execute("crew_engineer_1","assign",business.crew.token("crew_engineer_1"),cruiser.ship_instance_id),"paid engineer receives only effective repair contribution")
	check(business.owned_fleet.execute(owned_id,"deploy",business.owned_fleet.token(owned_id)),"repair patient is the existing paid owned hull")
	check(business.act("undock").phase==T.ActionPhase.APPLIED,"auxiliary mother actually undocks")
	for npc: RefCounted in candidate.rows("npc_state"):
		if not business.owned_fleet.friendly(npc.npc_instance_id):business.frontier._dormant(npc)
	var actor: RefCounted=business.owned_fleet.actor(business.owned_fleet.row(owned_id));actor.pos_x=cruiser.pos_x;actor.pos_y=cruiser.pos_y;actor.pos_z=cruiser.pos_z-700.0;business.owned_fleet.sync_hull(business.owned_fleet.row(owned_id))
	buddy.armor-=60.0;business.owned_fleet.sync_actor_health(owned_id)
	business.dispose();return await activate(candidate)

func drain_sorties(timeout_s: float=60.0) -> bool:
	host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+int(timeout_s*1000.0)
	while (host.world.projectiles.has_pending() or not host.gameplay.save_eligible()) and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	return check(not host.world.projectiles.has_pending() and host.gameplay.save_eligible(),"real sortie and paid cycle reach stable boundary")

func prepare_contact() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var selected: RefCounted=null
	for npc: RefCounted in candidate.rows("npc_state"):
		var spawn: Dictionary=business.definition("npc_spawn_defs","spawn_id",npc.spawn_id);var stats: Dictionary=business.definition("npc_full_defs","npc_id",spawn.npc_id)
		if spawn.occurrence_mode!="mission_scoped" and business.tactics.instance(npc.npc_instance_id)==null and business.civilizations.hostile_to(candidate.ship().ship_instance_id,npc.npc_instance_id) and float(stats.raw_dps)>0 and float(stats.raw_dps)<30:selected=npc;break
	if not check(selected!=null,"authored ordinary contact exists for physical scouting"):business.dispose();return false
	var spawn: Dictionary=business.definition("npc_spawn_defs","spawn_id",selected.spawn_id);var stats: Dictionary=business.definition("npc_full_defs","npc_id",spawn.npc_id)
	place(candidate,business,spawn.anchor_id);selected.alive=true;selected.behavior_phase=T.NpcPhase.PATROL;selected.shield=float(stats.shield_max);selected.armor=float(stats.armor_max);selected.hull=float(stats.hull_max);selected.respawn_remaining_s=0;selected.wait_remaining_s=0
	var separation: float=business.ship_roles.detection_range()+float(business.auxiliary_drones.spec(recon_id).sensor_range_m)*0.5
	if not check(separation<float(business.definition("module_defs","module_id","module_aux_recon_ii").range_m),"authored recon communications cover the beyond-mother sensor fixture"):business.dispose();return false
	candidate.ship().pos_x=selected.pos_x;candidate.ship().pos_y=selected.pos_y;candidate.ship().pos_z=selected.pos_z+separation
	business.owned_fleet.follow_arrival();contact_id=selected.npc_instance_id;business.dispose();return await activate(candidate)

func run() -> void:
	directory=OS.get_environment("XJ_AUXILIARY_WORLD_V41_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/auxiliary-world-v41/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped auxiliary native world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=AtomicHost.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","辅助无人机实际作业",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await prepare_owned():await finish();return
	host.ui._select_target(owned_id);await show("drones")
	check(host.gameplay.auxiliary_drones.bay(repair_id).stock_units==2 and host.gameplay.auxiliary_drones.bay(recon_id).stock_units==3,"real acquired auxiliary items initialize finite stock once")
	check(not host.gameplay.drone_control.command("attack",owned_id) and host.gameplay.auxiliary_drones.bay(repair_id).command_kind=="follow","attack orders cannot convert auxiliary bays into weapons")
	var armor: float=host.gameplay.owned_fleet.ship(owned_id).armor;var mother: RefCounted=host.state.ship();var energy: float=mother.energy;var heat: float=mother.heat;var hold: String=host.gameplay.inventory.hold(mother,T.ContainerKind.CARGO);var kits: int=host.gameplay.inventory.count(hold,"repair_kit_i",true)
	await capture("aux-before-repair")
	await click(host.ui.body.find_child("AuxiliaryLaunch_"+repair_id+"_target",true,false),"launches paid physical repair drones")
	var module: Dictionary=host.gameplay.definition("module_defs","module_id","module_aux_repair_i");var bay: RefCounted=host.gameplay.auxiliary_drones.bay(repair_id)
	check(mother.energy==energy-float(module.energy_eu) and mother.heat==heat+float(module.heat_hu) and host.gameplay.inventory.count(hold,"repair_kit_i",true)==kits-1,"actual mother capacitor heat and ordinary kit pay one sortie")
	check(bay.deployed_units==2 and host.world.projectiles.drones.size()==2 and not host.gameplay.save_eligible(),"repair sorties are real hittable entities and block saving")
	check(host.gameplay.owned_fleet.ship(owned_id).armor==armor,"button alone performs no remote repair")
	var duplicate_energy: float=mother.energy;check(not host.gameplay.auxiliary_drones.launch(repair_id,owned_id,host.gameplay.auxiliary_drones.token(repair_id)) and mother.energy==duplicate_energy,"outstanding sorties cannot be launched or paid twice")
	await run_for(6.0);repaired_hp=host.gameplay.owned_fleet.ship(owned_id).armor-armor
	check(repaired_hp>0 and repaired_hp<=40.0 and is_equal_approx(bay.repaired_hp,repaired_hp),"actual approach and line of sight deliver only finite effective repair")
	check(host.gameplay.crew.member("crew_engineer_1").contribution_total==repaired_hp,"engineer career uses effective actual repair only")
	await capture("aux-physical-repair")
	if not await drain_sorties():await finish();return
	check(bay.stock_units==2 and bay.deployed_units==0,"actual recovery preserves surviving repair stock")
	var saved_kits: int=host.gameplay.inventory.count(hold,"repair_kit_i",true);energy=host.state.ship().energy
	check(not host.gameplay.auxiliary_drones.launch(repair_id,host.state.ship().ship_instance_id,host.gameplay.auxiliary_drones.token(repair_id)) and host.state.ship().energy==energy and host.gameplay.inventory.count(hold,"repair_kit_i",true)==saved_kits,"full mother armor and hull reject empty paid repair")
	host.ui._select_target(owned_id);await show("drones")
	await click(host.ui.body.find_child("AuxiliaryLaunch_"+repair_id+"_target",true,false),"launches cancellable paid repair sortie")
	armor=host.gameplay.owned_fleet.ship(owned_id).armor
	check(host.gameplay.act("set_module_enabled",repair_id,1,"off").phase==T.ActionPhase.APPLIED,"physical auxiliary bay can be disabled during a sortie")
	if not await drain_sorties():await finish();return
	check(host.gameplay.owned_fleet.ship(owned_id).armor==armor and host.gameplay.inventory.count(hold,"repair_kit_i",true)==saved_kits-1,"disabled bay returns without healing or refunding paid consumables")
	check(host.gameplay.act("set_module_enabled",repair_id,1,"on").phase==T.ActionPhase.APPLIED,"surviving repair bay can be enabled again")
	if not await prepare_contact():await finish();return
	var entry: Dictionary=host.world.targets[contact_id];var waypoint: String=str(entry.get("group_target_id",""))
	if waypoint.is_empty():
		for id: String in host.world.targets:
			if host.world.targets[id].kind=="encounter" and host.world.target_is_local(id):waypoint=id;break
	if not check(not waypoint.is_empty(),"known encounter waypoint supports scouting before enemy detection"):await finish();return
	check(not host.world.contact_visible(entry,host.world.target_distance(contact_id)),"mother sensors cannot currently reveal the fixture contact")
	host.ui._select_target(waypoint);await show("drones")
	await click(host.ui.body.find_child("AuxiliaryLaunch_"+recon_id+"_target",true,false),"launches recon toward a known local waypoint")
	var origin: Vector3=host.gameplay.position(host.state.ship());var observed: RefCounted=null
	host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+40000
	while Time.get_ticks_msec()<deadline:
		for record: RefCounted in host.state.rows("auxiliary_intel_state"):
			if record.target_id==contact_id:observed=record;break
		if observed!=null and host.gameplay.auxiliary_drones.detected(contact_id):break
		await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	for drone: RefCounted in host.gameplay.drone_control.live.values():
		if drone.role_kind=="recon":recon_distance_m=maxf(recon_distance_m,origin.distance_to(host.gameplay.position(drone)))
	if not check(observed!=null and host.gameplay.auxiliary_drones.detected(contact_id) and recon_distance_m>1000,"physical probe travels and observes beyond mother sensors"):await finish();return
	check(host.world.contact_visible(host.world.targets[contact_id],host.world.target_distance(contact_id)),"live probe sensor actually reveals the ordinary NPC contact")
	# Explicit stationary geometry fixture verifies real sensor ray occlusion.
	var probe: RefCounted=null
	for drone: RefCounted in host.gameplay.drone_control.live.values():
		if drone.role_kind=="recon":probe=drone;break
	var obstacle:=StaticBody3D.new();obstacle.collision_layer=1;obstacle.collision_mask=0;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(200,200,10);shape.shape=box;obstacle.add_child(shape);host.world.add_child(obstacle)
	var contact_position: Vector3=host.world.npcs[contact_id].position;obstacle.position=(host.gameplay.position(probe)+contact_position)*0.5;obstacle.look_at(contact_position)
	await get_tree().physics_frame;await get_tree().physics_frame
	blocked_sensing=check(not host.gameplay.auxiliary_drones.detected(contact_id),"real solid occluder blocks probe sensor sharing")
	obstacle.queue_free();await get_tree().physics_frame;await get_tree().physics_frame
	check(host.gameplay.auxiliary_drones.detected(contact_id),"removing the occluder restores actual probe sight")
	await get_tree().create_timer(1.1).timeout
	var intel_label: Label=host.ui.body.find_child("IntelReadout_"+contact_id.validate_node_name(),true,false)
	check(intel_label!=null and intel_label.text.contains("当前探测") and host.ui.body.find_child("DroneReadout_"+recon_id,true,false).text.contains("侦察作业"),"actual UI distinguishes current sensing and active reconnaissance")
	await capture("aux-recon-live")
	var captured: Vector3=Vector3(observed.pos_x,observed.pos_y,observed.pos_z);var captured_tick: int=observed.observed_tick
	await click(host.ui.body.find_child("DroneOrder_recall",true,false),"recalls all friendly drone roles")
	check(not host.gameplay.auxiliary_drones.detected(contact_id),"recall immediately removes live probe sensing")
	var npc: RefCounted=host.state.find("npc_state","npc_instance_id",contact_id);npc.pos_x+=150.0;host.world.npcs[contact_id].position.x=npc.pos_x;host.world.npcs[contact_id].reset_physics_interpolation()
	await run_for(1.0)
	frozen_intel=check(Vector3(observed.pos_x,observed.pos_y,observed.pos_z)==captured and observed.observed_tick==captured_tick,"declared subsequent NPC movement cannot update lost-probe intel")
	var original_tick: int=host.state.snapshot.meta.simulation_tick
	host.state.snapshot.meta.simulation_tick=observed.observed_tick+int(ceil(float(host.gameplay.auxiliary_drones.spec(recon_id).observation_ttl_s)*host.gameplay.rule("simulation_hz")))
	check(not host.gameplay.auxiliary_drones.current(observed),"declared observation clock boundary expires last-known intel")
	host.state.snapshot.meta.simulation_tick=original_tick
	await show("drones");await click(host.ui.body.find_child("AuxiliaryLocate_"+contact_id.validate_node_name(),true,false),"native locates frozen last-known coordinates")
	var marker_id: String=host.ui.target_id
	check(not marker_id.is_empty() and host.world.targets[marker_id].node.position==captured,"last-known marker uses observed coordinates rather than hidden live position")
	await capture("aux-last-known")
	if not await drain_sorties():await finish();return
	host.ui._select_target(waypoint);await show("drones")
	await click(host.ui.body.find_child("AuxiliaryLaunch_"+recon_id+"_target",true,false),"launches another paid sortie for actual interception")
	var victim: RefCounted=null
	for drone: RefCounted in host.gameplay.drone_control.live.values():
		if drone.role_kind=="recon":victim=drone;break
	if not check(victim!=null,"second reconnaissance creates actual interception target"):await finish();return
	var body: CollisionObject3D=host.world.targets[victim.drone_id].node;var ray_from: Vector3=body.position+(body.position-host.world.flight.position).normalized()*50.0
	var weapon: Dictionary=host.gameplay.weapon_profile("module_kinetic_needle_i")
	host.world.projectiles.fire(contact_id,host.world.npcs[contact_id].get_rid(),ray_from,ray_from.direction_to(body.position),float(weapon.projectile_speed_mps),float(host.gameplay.definition("module_defs","module_id","module_kinetic_needle_i").range_m),Vector3(victim.health_max*2,0,0),weapon)
	await run_for(0.5);var recon_bay: RefCounted=host.gameplay.auxiliary_drones.bay(recon_id)
	intercepted=check(recon_bay.deployed_units==2 and recon_bay.stock_units==2 and recon_bay.lost_units==1,"real swept projectile destroys a probe and reduces real stock")
	host.gameplay.drone_control.command("recall","")
	if not await drain_sorties():await finish();return
	host.ui._select_target(waypoint);await show("drones")
	await click(host.ui.body.find_child("AuxiliaryLaunch_"+recon_id+"_target",true,false),"launches surviving stock for communication boundary")
	var mother_position: Vector3=host.world.flight.position
	host.world.flight.position+=Vector3(float(host.gameplay.definition("module_defs","module_id","module_aux_recon_ii").range_m)*1.1,0,0);host.world.flight.write_back();host.world.flight.reset_physics_interpolation()
	await run_for(0.25)
	var disconnected: Array=[]
	for drone: RefCounted in host.gameplay.drone_control.live.values():
		if drone.role_kind=="recon":disconnected.append(drone)
	check(disconnected.size()==2 and disconnected.all(func(drone: RefCounted):return drone.communication_lost and drone.returning),"declared mother pose boundary causes finite physical return of remaining probes")
	if not await drain_sorties():await finish();return
	comm_returned=check(host.gameplay.auxiliary_drones.bay(recon_id).stock_units==2 and host.gameplay.auxiliary_drones.bay(recon_id).lost_units==1,"actual out-of-range recovery preserves survivors without free refill")
	host.world.flight.position=mother_position;host.world.flight.write_back();host.world.flight.reset_physics_interpolation();await run_for(0.25)
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog);var home: Dictionary=business.definition("station_defs","station_id","station_anchor_port")
	place(candidate,business,home.station_anchor_id,home.station_id);business.owned_fleet.follow_arrival();business.dispose()
	if not await activate(candidate):await finish();return
	await show("drones");var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station());var materials: int=host.gameplay.inventory.count(warehouse,"material_structural_stock",true);var credits: int=host.state.player().credit
	var replenish: Button=host.ui.body.find_child("DroneReplenish_"+recon_id,true,false);var stale: Callable=replenish.get_signal_connection_list("pressed")[0].callable
	await click(replenish,"replenishes actual missing probe at a station")
	var spec: Dictionary=host.gameplay.auxiliary_drones.spec(recon_id);recon_bay=host.gameplay.auxiliary_drones.bay(recon_id)
	check(recon_bay.stock_units==3 and recon_bay.replenished_units==1 and host.state.player().credit==credits-int(spec.credit_per_unit) and host.gameplay.inventory.count(warehouse,"material_structural_stock",true)==materials-int(spec.material_per_unit),"replacement debits exact actual structural materials and credits")
	var before: String=state_signature();stale.call();await frames(3);check(state_signature()==before,"stale replenishment callback cannot buy free surplus probes")
	await capture("aux-replenished")
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(640,360);await frames(5);await show("drones")
	await reveal(host.ui.body.find_child("DroneReplenish_"+recon_id,true,false));await capture("aux-compact-200")
	if not check(host.store.save(host.state,"manual",0),"auxiliary costs losses and observations seal together "+host.store.last_error):await finish();return
	before=state_signature();var slot_id: String=""
	for slot: Dictionary in host.store.list_slots():
		if slot.slot_kind=="manual" and int(slot.slot_index)==0:slot_id=slot.slot_id;break
	var loaded: XJRuntimeState=host.store.load(slot_id);var original_state: XJRuntimeState=host.state;host.state=loaded
	restored=check(loaded!=null and state_signature()==before,"all108 groups including paid auxiliary stock and frozen intel reopen exactly");host.state=original_state
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var result: String="PASS" if failures.is_empty() else "FAIL"
	print("AUXILIARY_WORLD_V41_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"repaired_hp":repaired_hp,"recon_distance_m":recon_distance_m,"intercepted":intercepted,"frozen_intel":frozen_intel,"restored":restored,"comm_returned":comm_returned,"blocked_sensing":blocked_sensing}))
	print("AUXILIARY_WORLD_V41_RESULT ",result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
