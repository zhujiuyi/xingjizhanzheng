extends "civilization_world_v24.gd"
## Isolated role measurements use declared equipment/pose/other-actor fixtures. Combat is real Main physics.
var role_actor: String = ""
var victim_actor: String = ""
var bay_id: String = ""
var trace_page: String = ""

func _input(event: InputEvent) -> void:
	if OS.get_environment("XJ_TACTICS_UI_TRACE")!="1":return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_J,KEY_M,KEY_ESCAPE]:
		print("TACTICS_UI_TRACE navigation_key=",event.keycode)

func _process(_delta: float) -> void:
	if OS.get_environment("XJ_TACTICS_UI_TRACE")!="1" or not is_instance_valid(host) or host.ui==null:return
	if host.ui.page!=trace_page:
		print("TACTICS_UI_TRACE page ",trace_page," -> ",host.ui.page," tick=",host.state.snapshot.meta.simulation_tick if host.state!=null else -1)
		trace_page=host.ui.page
	if not host.ui.mission_guide_button.has_meta("tactics_trace"):
		host.ui.mission_guide_button.set_meta("tactics_trace",true)
		host.ui.mission_guide_button.pressed.connect(func():print("TACTICS_UI_TRACE hud_guide_pressed"))

func trace_controls(label: String) -> void:
	if OS.get_environment("XJ_TACTICS_UI_TRACE")!="1":return
	var button: Button=host.ui.body.find_child("DroneOrder_recall",true,false)
	print("TACTICS_UI_TRACE ",label," page=",host.ui.page," recall=",button!=null," visible=",button.is_visible_in_tree() if button!=null else false," disabled=",button.disabled if button!=null else false," busy=",host.busy)
func _ready() -> void:
	get_tree().set_meta("xj_tactics_world_v29_diagnostic",true)
	get_tree().create_timer(540.0).timeout.connect(func():check(false,"native tactics watchdog");finish())
	run.call_deferred()
func run_for(seconds: float) -> void:
	host.set_process(true);host.set_physics_process(true);await get_tree().create_timer(seconds).timeout
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
func simulation_ticks(count: int) -> int:
	var start: int=host.state.snapshot.meta.simulation_tick
	var deadline: int=Time.get_ticks_msec()+30000
	while host.state.snapshot.meta.simulation_tick-start<count and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	return host.state.snapshot.meta.simulation_tick-start
func qualify(kind: String, close: bool = false, hull_id: String = "battleship_bastion") -> bool:
	var candidate: XJRuntimeState = host.store.clone_state(host.state)
	var g: Gameplay = Gameplay.new();g.setup(candidate,host.store.catalog)
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	g.tactics.sync()
	role_actor="";victim_actor=""
	for row: RefCounted in candidate.rows("npc_tactic_state"):
		if g.tactics.definition(row.npc_instance_id).tactic_kind==kind:role_actor=row.npc_instance_id;break
	var role: RefCounted = candidate.find("npc_state","npc_instance_id",role_actor)
	var site_id: String = g.tactics.bindings[role.spawn_id].site_id
	# Other actors are disabled only for individual role measurement, not a victory claim.
	for row: RefCounted in candidate.rows("npc_tactic_state"):
		var npc: RefCounted = candidate.find("npc_state","npc_instance_id",row.npc_instance_id)
		var spec: Dictionary = g.tactics.definition(npc.npc_instance_id)
		row.deployed_drones=0;row.phase="ready";row.remaining_s=0;row.cooldown_remaining_s=0;row.has_target_entity_id=false;row.target_entity_id="";row.energy=spec.energy_max
		if row.npc_instance_id==role_actor or (kind=="support" and g.tactics.bindings[npc.spawn_id].site_id==site_id and spec.tactic_kind=="siege"):
			var stats: Dictionary = g.definition("npc_full_defs","npc_id",g.definition("npc_spawn_defs","spawn_id",npc.spawn_id).npc_id)
			npc.alive=true;npc.shield=stats.shield_max;npc.armor=stats.armor_max;npc.hull=stats.hull_max;npc.behavior_phase=T.NpcPhase.PATROL
			if row.npc_instance_id!=role_actor:victim_actor=npc.npc_instance_id
			continue
		npc.alive=false;npc.shield=0;npc.armor=0;npc.hull=0;npc.behavior_phase=T.NpcPhase.DEAD;npc.bounty_claimed=true
		row.phase="ready";row.remaining_s=0;row.cooldown_remaining_s=0;row.has_target_entity_id=false;row.target_entity_id=""
	for site: RefCounted in candidate.rows("tactical_site_state"):site.respawn_remaining_s=g.definition("tactical_site_defs","site_id",site.site_id).respawn_s
	for bay: RefCounted in candidate.rows("drone_bay_state"):bay.deployed_units=0
	if kind=="support":
		var victim: RefCounted = candidate.find("npc_state","npc_instance_id",victim_actor)
		victim.pos_x=role.pos_x+300.0;victim.pos_y=role.pos_y;victim.pos_z=role.pos_z
	var hull: RefCounted = g.inventory.create_ship(hull_id,"station_anchor_port")
	candidate.player().controlled_ship_id=hull.ship_instance_id;candidate.player().credit=1000000
	var home: Dictionary = g.definition("station_defs","station_id","station_anchor_port")
	place(candidate,g,home.station_anchor_id,home.station_id)
	var weapon: String = g.inventory.grant(g.inventory.warehouse(home.station_id),"module_thermal_sunline_iii",1)[0]
	check(g.act("fit_module",weapon,1,"weapon:1").phase==T.ActionPhase.APPLIED,"qualified native ship fits a legal ray weapon")
	bay_id=g.inventory.grant(g.inventory.warehouse(home.station_id),"module_drone_swarm_i",1)[0]
	check(g.act("fit_module",bay_id,1,"weapon:2").phase==T.ActionPhase.APPLIED,"qualified native ship fits a legal drone bay")
	place(candidate,g,g.definition("npc_spawn_defs","spawn_id",role.spawn_id).anchor_id)
	hull.pos_z-=300.0 if kind=="interceptor" else float(g.definition("module_defs","module_id","module_drone_swarm_i").range_m)*0.5 if close or kind=="support" else 1300.0
	var direction: Vector3 = g.position(hull).direction_to(g.position(role))
	var rotation: Quaternion = Basis.looking_at(direction,Vector3.UP).get_rotation_quaternion()
	hull.quat_x=rotation.x;hull.quat_y=rotation.y;hull.quat_z=rotation.z;hull.quat_w=rotation.w
	g.dispose();return await activate(candidate)
func fire_at(id: String) -> void:
	host.ui.show_page("");host.ui._select_target(id)
	root.grab_focus();await frames(3);await settle()
	check(host._keyboard_control_allowed(),"real ray input has foreground focus and an available controller")
	print("TACTICS_INPUT_CONTEXT ",JSON.stringify({"focus":root.has_focus(),"busy":host.busy,"keyboard_blocked":host.ui.keyboard_blocked(),"exit_pending":host._exit_save_pending(),"paused":host._paused()}))
	var node: Node3D = host.world.targets[id].node
	# Fixture aims the actual fitted muzzle. A tiny close drone is not centered
	# on a large hull's offset hardpoint; aiming from hull origin can legally miss.
	for adjustment: int in range(3):
		var muzzle: Transform3D = host.world.flight.muzzle(1)
		var direction: Vector3 = muzzle.origin.direction_to(node.global_position)
		if not direction.is_zero_approx():host.world.flight.quaternion=(Quaternion(-muzzle.basis.z,direction)*host.world.flight.quaternion).normalized();host.world.flight.write_back()
	host._process(0.0);await frames(3)
	host.set_process(true);host.set_physics_process(true)
	for down: bool in [true,false]:
		var event: InputEventKey = InputEventKey.new();event.keycode=KEY_CTRL;event.physical_keycode=KEY_CTRL;event.pressed=down;event.ctrl_pressed=down;event.window_id=root.get_window_id()
		Input.parse_input_event(event)
		await get_tree().physics_frame;await frames(2)
	await get_tree().create_timer(0.15).timeout
	host.set_process(false);host.set_physics_process(false)
func hp(id: String) -> float:
	var npc: RefCounted = host.state.find("npc_state","npc_instance_id",id)
	return npc.shield+npc.armor+npc.hull
func run() -> void:
	directory=OS.get_environment("XJ_TACTICS_WORLD_V29_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/tactics-world-v29/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"native tactics uses fresh scoped world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","战术与无人机原生验收",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await qualify("support"):await finish();return
	var before: float = hp(victim_actor)
	await fire_at(victim_actor)
	var damaged: float = hp(victim_actor)
	check(damaged<before,"actual player ray damages the support's companion")
	await run_for(2.0)
	check(hp(victim_actor)>damaged,"actual AI support repairs companion after physical damage")
	host.ui._select_target(role_actor);host._process(0.0);await frames(3)
	await capture("tactics-support-repair")
	await support_cover()
	if not await qualify("interceptor"):await finish();return
	var baseline: float = host.gameplay.metrics(host.state.ship()).speed_mps
	await run_for(2.2)
	var effect: RefCounted = host.state.find("ship_tactical_effect_state","ship_instance_id",host.state.ship().ship_instance_id)
	check(effect!=null and effect.jam_remaining_s>0.0 and host.gameplay.metrics(host.state.ship()).speed_mps<baseline,"actual interceptor AI creates bounded propulsion interference")
	host.preferences.vfx_intensity=0.0;host._apply_preferences();host.ui._select_target(role_actor);host._process(0.0)
	check(host.ui.npc_title.text.contains("干扰"),"interference role remains readable with effects disabled")
	await capture("tactics-interference-low-effects")
	# Near-destruction fixture; a real ray must deliver the killing hit and clear the effect.
	var interceptor: RefCounted = host.state.find("npc_state","npc_instance_id",role_actor);interceptor.shield=0;interceptor.armor=0;interceptor.hull=1
	await fire_at(role_actor)
	for retry: int in range(2):
		if not interceptor.alive:break
		await run_for(float(host.store.catalog.one("module_defs","module_id","module_thermal_sunline_iii").cycle_s)+0.1)
		await fire_at(role_actor)
	check(not interceptor.alive and (effect==null or effect.jam_remaining_s==0.0),"actual source destruction releases interference")
	if not await qualify("siege"):await finish();return
	await run_for(0.5)
	check(host.gameplay.tactics.instance(role_actor).phase=="charging","actual siege AI begins visible charging")
	await capture("tactics-siege-charge")
	await fire_at(role_actor);await run_for(0.2)
	check(host.gameplay.tactics.instance(role_actor).phase=="cooldown","physical ray damage interrupts actual charged volley")
	await siege_volley()
	if not await qualify("carrier"):await finish();return
	await run_for(2.0)
	var enemies: Array[String] = []
	for id: String in host.gameplay.drone_control.live:
		if host.gameplay.drone_control.owner(id)==role_actor:enemies.append(id)
	check(enemies.size()>0,"actual carrier AI launches physical hostile drones")
	if not enemies.is_empty():
		var target: String = enemies[0]
		check(host.world.targets.has(target) and host.world.targets[target].node is CollisionObject3D,"hostile drone is a real selectable collider")
		var stock: int = host.gameplay.tactics.instance(role_actor).drone_stock
		await fire_at(target)
		check(not host.gameplay.drone_control.live.has(target) and host.gameplay.tactics.instance(role_actor).drone_stock==stock-1,"actual ray destroys hostile drone and permanently reduces carrier reserve")
	await capture("tactics-carrier-drone-counter")
	await commander()
	await finish()
func support_cover() -> void:
	if not await qualify("support"):return
	var victim: RefCounted = host.state.find("npc_state","npc_instance_id",victim_actor)
	victim.shield=maxf(0.0,victim.shield-100.0)
	var source: Node3D = host.world.npcs[role_actor]
	var target: Node3D = host.world.npcs[victim_actor]
	var wall: StaticBody3D = StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var collision: CollisionShape3D = CollisionShape3D.new();var box: BoxShape3D = BoxShape3D.new();box.size=Vector3(20,2000,2000);collision.shape=box;wall.add_child(collision);host.world.add_child(wall);wall.position=(source.position+target.position)*0.5
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not host.world.line_of_sight(source.global_position,target.global_position,source.get_rid(),victim_actor),"declared physical cover blocks actual support line of sight")
	var before: float = hp(victim_actor)
	await run_for(1.0)
	check(hp(victim_actor)==before,"actual cover prevents enemy repair rather than merely hiding its effect")
	await capture("tactics-support-cover-counter")
func siege_volley() -> void:
	if not await qualify("siege"):return
	var total: float = host.state.ship().shield+host.state.ship().armor+host.state.ship().hull
	await run_for(6.0)
	check(host.state.ship().shield+host.state.ship().armor+host.state.ship().hull<total,"uninterrupted actual charged projectile hits the stationary ship")
	await capture("tactics-siege-physical-impact")
	if not await qualify("siege",false,"cruiser_horizon"):return
	await run_for(0.5)
	var row: RefCounted = host.gameplay.tactics.instance(role_actor)
	var aim: Vector3 = Vector3(row.aim_x,row.aim_y,row.aim_z)
	# Lateral motion is real flight input after the AI has committed its aim.
	host.ui.show_page("");root.grab_focus();await frames(3);await settle()
	check(host._keyboard_control_allowed(),"real evasion input has foreground focus and an available controller")
	host.set_process(true);host.set_physics_process(true)
	var event: InputEventKey = InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=true;event.window_id=root.get_window_id();Input.parse_input_event(event)
	var held_ticks: int=await simulation_ticks(3*Engine.physics_ticks_per_second)
	event=InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=false;event.window_id=root.get_window_id();Input.parse_input_event(event)
	var coast_ticks: int=await simulation_ticks(3*Engine.physics_ticks_per_second)
	host.set_process(false);host.set_physics_process(false)
	check(held_ticks>=3*Engine.physics_ticks_per_second and coast_ticks>=3*Engine.physics_ticks_per_second,"evasion measures six actual simulated seconds rather than a rendering-stalled wall timer")
	var metrics: Dictionary = host.gameplay.metrics(host.state.ship())
	observations.append({"kind":"evasion","distance_m":host.world.flight.position.distance_to(aim),"shield":host.state.ship().shield,"maximum_shield":metrics.shield_max,"armor":host.state.ship().armor,"maximum_armor":metrics.armor_max,"held_ticks":held_ticks,"coast_ticks":coast_ticks})
	check(host.world.flight.position.distance_to(aim)>50.0 and is_equal_approx(host.state.ship().shield,float(metrics.shield_max)) and is_equal_approx(host.state.ship().armor,float(metrics.armor_max)),"real movement can evade a volley aimed at the original position")
	await capture("tactics-siege-evasion")
func commander() -> void:
	if not await qualify("carrier",true):return
	# Keep mother ships separated for the command measurement; actual drone physics stays live.
	var role: RefCounted = host.state.find("npc_state","npc_instance_id",role_actor)
	var ability: RefCounted = host.gameplay.tactics.instance(role_actor);ability.cooldown_remaining_s=host.gameplay.tactics.definition(role_actor).cooldown_s;ability.phase="cooldown"
	host.ui._select_target(role_actor);host.ui.show_page("drones");await frames(5)
	var energy: float = host.state.ship().energy
	await click(host.ui.body.find_child("DroneOrder_follow",true,false),"actual follow command launches a paid player sortie")
	check(host.gameplay.drone_control.bay(bay_id).deployed_units>0 and host.state.ship().energy<energy,"follow uses real deployed stock and capacitor")
	await run_for(0.6)
	var own: Array[String] = []
	for id: String in host.gameplay.drone_control.live:
		if host.gameplay.drone_control.owner(id)==host.state.ship().ship_instance_id:own.append(id)
	check(not own.is_empty() and host.world.targets[own[0]].node.position.distance_to(host.world.flight.position)>host.world.projectiles._owner_radius(host.world.flight),"actual follow formation clears mother-ship collision geometry")
	await capture("tactics-player-drone-follow")
	var paid_energy: float = host.state.ship().energy
	await click(host.ui.body.find_child("DroneOrder_attack",true,false),"attack redirects existing paid player drones")
	check(host.gameplay.drone_control.live[own[0]].target_id==role_actor and is_equal_approx(host.state.ship().energy,paid_energy),"attack order does not pay a second sortie")
	await click(host.ui.body.find_child("DroneOrder_recall",true,false),"actual recall disarms and recovers player drones")
	await run_for(3.0)
	check(host.gameplay.drone_control.bay(bay_id).deployed_units==0,"actual recall returns live actors to bay")
	await capture("tactics-player-drone-recovered")
	await loss_and_replenishment()
	root.size=Vector2i(1280,720);root.content_scale_factor=2.0
	host.ui.show_page("drones");await frames(5)
	var recall: Button = host.ui.body.find_child("DroneOrder_recall",true,false);await reveal(recall)
	check(Rect2(Vector2.ZERO,host.ui.root.size).encloses(recall.get_global_rect()),"high-scale drone orders remain reachable")
	await capture("tactics-drones-1280-200")
func loss_and_replenishment() -> void:
	# Shoot an actual following drone with an actual enemy-owned ray; no direct loss setter.
	await wait_bay_cooldown()
	host.ui.show_page("drones");await frames(4)
	await click(host.ui.body.find_child("DroneOrder_follow",true,false),"launch following drones for physical loss measurement")
	await run_for(0.8)
	var id: String = ""
	for key: String in host.gameplay.drone_control.live:
		if host.gameplay.drone_control.owner(key)==host.state.ship().ship_instance_id:id=key;break
	if not check(not id.is_empty(),"actual player drone is available for enemy collision"):return
	var node: Node3D = host.world.targets[id].node
	var enemy: CharacterBody3D = host.world.npcs[role_actor]
	var bay: RefCounted = host.gameplay.drone_control.bay(bay_id)
	var stock: int = bay.stock_units
	trace_controls("before physical loss")
	# Qualified clear firing origin next to the drone isolates the real ray/collider route.
	var origin: Vector3 = node.global_position+Vector3(0,20,0)
	host.world.projectiles.fire(role_actor,enemy.get_rid(),origin,origin.direction_to(node.global_position),0.0,40.0,Vector3(1000,0,0),{"family_id":"thermal","fire_mode":"ray"})
	check(not host.gameplay.drone_control.live.has(id) and bay.stock_units==stock-1 and bay.lost_units>0,"real hostile physics ray creates persistent player-drone loss")
	trace_controls("after physical loss")
	await click(host.ui.body.find_child("DroneOrder_recall",true,false),"recover surviving units after physical loss")
	await run_for(3.0)
	# Declared boundary pose, then real simulation must detect communication loss.
	await wait_bay_cooldown()
	await click(host.ui.body.find_child("DroneOrder_follow",true,false),"launch surviving drone for link-boundary measurement")
	var remaining: String = ""
	for key: String in host.gameplay.drone_control.live:
		if host.gameplay.drone_control.owner(key)==host.state.ship().ship_instance_id:remaining=key;break
	if check(not remaining.is_empty(),"surviving stock can sortie without restoring lost unit"):
		var drone: RefCounted = host.gameplay.drone_control.live[remaining]
		for actor: RefCounted in host.world.projectiles.drones:
			if actor.data!=null and actor.data.drone_id==remaining:actor.position=host.world.flight.position+Vector3(float(host.store.catalog.one("module_defs","module_id","module_drone_swarm_i").range_m)+10.0,0,0);actor.visual.position=actor.position
		await run_for(0.1)
		check(drone.communication_lost and drone.returning and not drone.fired,"actual communication-boundary simulation disarms and returns drone")
		await run_for(4.0)
	await capture("tactics-drone-loss-and-link")
	# Declared near-destruction mother-ship fixture, then a real player hit ends enemy sortie.
	var mother: RefCounted = host.state.find("npc_state","npc_instance_id",role_actor)
	mother.shield=0;mother.armor=0;mother.hull=1
	await fire_at(role_actor);await run_for(1.2)
	check(not mother.alive and host.gameplay.tactics.instance(role_actor).deployed_drones==0,"physical mother-ship destruction terminates its outstanding drone wing")
	var candidate: XJRuntimeState = host.store.clone_state(host.state)
	var g: Gameplay = Gameplay.new();g.setup(candidate,host.store.catalog)
	var home: Dictionary = g.definition("station_defs","station_id","station_anchor_port")
	place(candidate,g,home.station_anchor_id,home.station_id)
	g.inventory.grant(g.inventory.warehouse(home.station_id),"material_structural_stock",100)
	g.dispose()
	if not await activate(candidate):return
	host.ui.show_page("drones");await frames(5)
	bay=host.gameplay.drone_control.bay(bay_id)
	var missing: int = int(host.store.catalog.one("drone_defs","module_id","module_drone_swarm_i").drone_count)-bay.stock_units
	var credit: int = host.state.player().credit
	await click(host.ui.body.find_child("DroneReplenish_"+bay_id,true,false),"actual station UI purchases only lost units")
	check(bay.stock_units==int(host.store.catalog.one("drone_defs","module_id","module_drone_swarm_i").drone_count) and host.state.player().credit==credit-missing*int(host.store.catalog.one("drone_management_defs","module_id","module_drone_swarm_i").credit_per_unit),"native replacement deducts exact fee and restores real missing stock")
	await capture("tactics-drone-station-replacement")
func wait_bay_cooldown() -> void:
	var equipment: RefCounted = host.state.find("equipment_state","item_instance_id",bay_id)
	if equipment.cooldown_remaining_s>0.0:await run_for(equipment.cooldown_remaining_s+0.2)
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"observations":observations}
	print("TACTICS_WORLD_V29_FINAL_JSON ",JSON.stringify(summary));print("TACTICS_WORLD_V29_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
