extends "frontier_world_v34.gd"
## Explicit wealth, licenses, owned hull, isolation/arrival and near-boundary
## health/time fixtures. Inputs, hits, following, retreat and repair are real.
class AtomicHost extends "res://runtime/main.gd":
	var reject_stage: bool=false
	func _stage_candidate(candidate: XJRuntimeState,definitions: XJCatalog) -> bool:
		if reject_stage:last_error="Declared native staging fault";return false
		return super._stage_candidate(candidate,definitions)
class FaultStore extends "res://runtime/data/store.gd":
	var reject_point: String=""
	func _checkpoint(point: String) -> bool:return point!=reject_point
var escort_distance: float=0.0
var enemy_damage: float=0.0
var companion_damage: float=0.0
var healed_cycles: int=0
var refunded: bool=false
var pause_checked: bool=false
func _ready() -> void:
	get_tree().set_meta("xj_hire_world_v35_diagnostic",true)
	get_tree().create_timer(600.0).timeout.connect(func():check(false,"native hired fleet watchdog");finish())
	run.call_deferred()
func qualification_fixture() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	candidate.player().credit=100000
	var station: Dictionary=business.definition("station_defs","station_id","station_anchor_port")
	var ship: RefCounted=business.inventory.create_ship("battleship_bastion",station.station_id);candidate.player().controlled_ship_id=ship.ship_instance_id
	place(candidate,business,station.station_anchor_id,station.station_id);business.missions.refresh();business._sync_spawns();business.dispose();return await activate(candidate)
func combat_arrival_fixture() -> String:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var enemy: RefCounted=null
	for n: RefCounted in candidate.rows("npc_state"):
		var spawn: Dictionary=business.definition("npc_spawn_defs","spawn_id",n.spawn_id);var stats: Dictionary=business.definition("npc_full_defs","npc_id",spawn.npc_id)
		if n.alive and spawn.occurrence_mode!="mission_scoped" and float(stats.range_m)>=700.0 and float(stats.raw_dps)>=8.0 and float(stats.raw_dps)<=30.0:enemy=n;break
	if not check(enemy!=null,"native fixture selects an authored ordinary medium enemy"):business.dispose();return ""
	var lease: RefCounted=business.hired.active();var buddy: RefCounted=business.hired.actor(lease)
	var anchor_id: String=business.definition("npc_spawn_defs","spawn_id",enemy.spawn_id).anchor_id
	place(candidate,business,anchor_id);var home: Vector3=business.position(enemy)
	candidate.ship().pos_x=home.x;candidate.ship().pos_y=home.y+250.0;candidate.ship().pos_z=home.z+minf(1600.0,business.ship_roles.detection_range()*0.8)
	business.hired.follow_arrival();buddy.pos_x=home.x;buddy.pos_y=home.y+250.0;buddy.pos_z=home.z+300.0;buddy.shield=0.0
	enemy.pos_y=home.y+250.0;enemy.quat_x=0.0;enemy.quat_y=1.0;enemy.quat_z=0.0;enemy.quat_w=0.0;enemy.behavior_phase=T.NpcPhase.ACQUIRE;enemy.wait_remaining_s=0.0
	for n: RefCounted in candidate.rows("npc_state"):
		if n.npc_instance_id in [enemy.npc_instance_id,buddy.npc_instance_id]:continue
		n.alive=false;n.shield=0.0;n.armor=0.0;n.hull=0.0;n.behavior_phase=T.NpcPhase.DEAD;n.bounty_claimed=true;n.loot_claimed=true
	var id: String=enemy.npc_instance_id;business.dispose();return id if await activate(candidate) else ""
func return_boundary_fixture() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var home: Dictionary=business.definition("station_defs","station_id","station_anchor_port");place(candidate,business,home.station_anchor_id,home.station_id)
	var lease: RefCounted=business.hired.active();lease.return_remaining_s=1.0
	for n: RefCounted in candidate.rows("npc_state"):n.alive=false;n.shield=0.0;n.armor=0.0;n.hull=0.0;n.behavior_phase=T.NpcPhase.DEAD;n.bounty_claimed=true;n.loot_claimed=true
	business.dispose();return await activate(candidate)
func support_arrival_fixture() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	place(candidate,business,"anchor_anchor_undock");business.hired.follow_arrival()
	candidate.ship().shield=maxf(0.0,float(business.metrics(candidate.ship()).shield_max)-150.0)
	business.dispose();return await activate(candidate)
func run() -> void:
	directory=OS.get_environment("XJ_HIRE_WORLD_V35_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/hire-world-v35/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped native companion world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=AtomicHost.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5);await host._command("new_world","雇佣僚舰原生",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await qualification_fixture():await finish();return
	await show("ships");await click(host.ui.body.find_child("HireFleetEntry",true,false),"native opens hired support from the existing fleet page")
	check(host.ui.page=="hire" and host.ui._service_context_page()=="ships","hired fleet uses its canonical ship-service parent")
	var button: Button=host.ui.body.find_child("Hire_hire_escort",true,false);var stale: Callable=button.get_signal_connection_list("pressed")[0].callable
	var before: String=state_signature();var slots: String=JSON.stringify(host.store.list_slots())
	host.reject_stage=true;await click(button,"native staging failure preserves funds and existing fleet")
	check(state_signature()==before and JSON.stringify(host.store.list_slots())==slots,"failed rental model preparation publishes no money or state")
	host.reject_stage=false
	var original: RefCounted=host.store;var faulty: RefCounted=FaultStore.new(directory.path_join("progress.db"));check(faulty.open(),"isolated failure writer opens the existing test-owned database")
	faulty.reject_point="state";host.store=faulty;await click(button,"native SQL failure rolls back a paid rental candidate")
	check(state_signature()==before and JSON.stringify(host.store.list_slots())==slots,"failed rental snapshot restores the old slot and live money")
	host.store=original;faulty.close();faulty=null
	await capture("hire-offers")
	var credit: int=host.state.player().credit;var ship_count: int=host.state.rows("ship_state").size();var spec: Dictionary=host.gameplay.hired.profile("hire_escort")
	await click(button,"native signs a real paid escort contract");await settle()
	check(host.gameplay.hired.active()!=null and host.state.player().credit==credit-int(spec.hire_fee_credit)-int(spec.deposit_credit),"actual rental publishes exact fee and deposit")
	check(host.state.rows("ship_state").size()==ship_count,"native rental creates no free privately owned hull")
	before=state_signature();stale.call();await frames(3);check(state_signature()==before,"old vacant callback cannot charge after successful activation")
	await host._command("undock","",1,"");await settle();host.set_process(false);host.set_physics_process(false);host.ui.show_page("");await frames(3)
	var npc: RefCounted=host.gameplay.hired.actor();var initial: Vector3=host.gameplay.position(npc)
	var down: InputEventKey=InputEventKey.new();down.keycode=KEY_W;down.physical_keycode=KEY_W;down.pressed=true;Input.parse_input_event(down)
	await frames(2)
	check(Input.is_action_pressed("forward"),"native W updates the real mapped global forward action")
	await run_for(6.0)
	var up: InputEventKey=InputEventKey.new();up.keycode=KEY_W;up.physical_keycode=KEY_W;up.pressed=false;Input.parse_input_event(up);await frames(2)
	escort_distance=initial.distance_to(host.gameplay.position(npc));check(escort_distance>50.0,"actual hired body follows a moving player through local physics")
	await capture("hire-formation")
	var enemy_id: String=await combat_arrival_fixture()
	if enemy_id.is_empty():await finish();return
	npc=host.gameplay.hired.actor();var enemy: RefCounted=host.state.find("npc_state","npc_instance_id",enemy_id);var enemy_hp: float=enemy.shield+enemy.armor+enemy.hull;var buddy_hp: float=npc.armor+npc.hull
	host.ui._select_target(enemy_id);await show("hire");await click(host.ui.body.find_child("HireOrder_focus",true,false),"native focuses the actual local enemy")
	check(host.gameplay.hired.active().focus_target_id==enemy_id,"real focus command binds its selected hostile actor")
	host.ui.show_page("");host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+16000
	while host.gameplay.hired.actor()!=null and (enemy.shield+enemy.armor+enemy.hull>=enemy_hp or npc.armor+npc.hull>=buddy_hp) and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	enemy_damage=enemy_hp-(enemy.shield+enemy.armor+enemy.hull);companion_damage=buddy_hp-(npc.armor+npc.hull)
	check(enemy_damage>0.0 and companion_damage>0.0 and host.gameplay.hired.active()!=null,"ordinary enemies and rented escort exchange real projectile damage")
	await capture("hire-real-combat")
	await show("hire");await click(host.ui.body.find_child("HireOrder_regroup",true,false),"native regroup stops active focus")
	check(host.gameplay.hired.active().order_kind=="regroup","regroup is usable during real incoming fire")
	await click(host.ui.body.find_child("HireOrder_advance",true,false),"native advance enables autonomous escort fire")
	check(host.gameplay.hired.active().order_kind=="advance","advance is a distinct live command")
	await click(host.ui.body.find_child("HireOrder_retreat",true,false),"native retreat leaves the battle with paid assets at risk")
	var lease: RefCounted=host.gameplay.hired.active();var retreat_start: Vector3=Vector3(lease.retreat_origin_x,lease.retreat_origin_y,lease.retreat_origin_z);var retreat_m: float=0.0
	host.ui.show_page("");host.set_process(true);host.set_physics_process(true);deadline=Time.get_ticks_msec()+60000
	while lease.phase=="retreating" and Time.get_ticks_msec()<deadline:
		var live: RefCounted=host.gameplay.hired.actor(lease)
		if live!=null:retreat_m=maxf(retreat_m,retreat_start.distance_to(host.gameplay.position(live)))
		await get_tree().physics_frame
	await get_tree().physics_frame;await get_tree().physics_frame;host.set_process(false);host.set_physics_process(false);host._process(0.0)
	if not check(lease.phase=="returning" and retreat_m>=float(host.gameplay.hired.balance.retreat_distance_m) and not lease.has_npc_instance_id,"physical retreat completes real distance and disengagement before agency return"):await finish();return
	await capture("hire-escaped")
	host.set_process(true);host.set_physics_process(true);await key(KEY_ESCAPE);check(host._paused(),"real pause menu stops companion world time")
	var remaining: float=lease.return_remaining_s;await get_tree().create_timer(1.0).timeout
	pause_checked=check(lease.return_remaining_s==remaining,"paused agency return cannot advance off screen")
	await key(KEY_ESCAPE);host.set_process(false);host.set_physics_process(false)
	if not await return_boundary_fixture():await finish();return
	lease=host.gameplay.hired.active();credit=host.state.player().credit;var expected: int=int(float(lease.deposit_paid_credit)*lease.condition_ratio)
	await run_for(1.5);refunded=check(lease.phase=="returned" and host.state.player().credit==credit+expected and expected<int(lease.deposit_paid_credit),"actual damaged return refunds only the undamaged armor/hull share")
	await show("hire");await click(host.ui.body.find_child("Hire_hire_support",true,false),"native pays for a different support contract")
	if not await support_arrival_fixture():await finish();return
	lease=host.gameplay.hired.active();var cycles: int=lease.support_cycles_remaining;host.ui.show_page("");await run_for(7.0)
	healed_cycles=cycles-lease.support_cycles_remaining
	check(healed_cycles>=2 and host.state.ship().shield>0.0,"real support ship repairs the player with actual range LOS and finite supplies")
	var measured_repair: RefCounted=host.state.find("telemetry_repair_state","repair_kind","received")
	check(measured_repair!=null and measured_repair.restored_hp>0.0,"received repair records actual completed hired support cycles")
	await capture("hire-real-support")
	for layout: Dictionary in [{"size":Vector2i(3440,1188),"scale":1.0,"tag":"ultrawide"},{"size":Vector2i(1280,720),"scale":2.0,"tag":"compact-200"}]:
		root.size=layout.size;root.content_scale_factor=1.0;root.content_scale_size=Vector2i(Vector2(layout.size)/float(layout.scale));await frames(5);await show("hire")
		check(host.ui.root.size.is_equal_approx(Vector2(root.content_scale_size)),"exact native hire canvas "+str(layout.tag))
		for name: String in ["HireOrder_advance","HireOrder_regroup","HireOrder_focus","HireOrder_retreat","HireDismiss"]:
			var control: Control=host.ui.body.find_child(name,true,false);await reveal(control);check(Rect2(Vector2.ZERO,host.ui.root.size).encloses(control.get_global_rect()),"hire command remains within client "+name+" "+str(layout.tag))
		await capture("hire-"+str(layout.tag))
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"escort_distance":escort_distance,"enemy_damage":enemy_damage,"companion_damage":companion_damage,"healed_cycles":healed_cycles,"refunded":refunded,"pause_checked":pause_checked}
	print("HIRE_WORLD_V35_FINAL_JSON ",JSON.stringify(summary));print("HIRE_WORLD_V35_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
