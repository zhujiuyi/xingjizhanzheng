extends "auxiliary_world_v41.gd"
## Initial hull/gear/damage and transient deadline boundaries are fixtures.
## Recovery, loss, cleanup, rescue and restored progress use actual Main.
var timeout_recovered: bool=false
var timeout_lost: bool=false
var mother_loss: bool=false
var rescue_valid: bool=false
func _ready() -> void:
	get_tree().set_meta("xj_auxiliary_boundaries_v43_diagnostic",true)
	get_tree().create_timer(360.0).timeout.connect(func():check(false,"auxiliary boundary watchdog");finish())
	run.call_deferred()
func launch(kind: String,item_id: String) -> void:
	host.ui._select_target(owned_id);await show("drones")
	await click(host.ui.body.find_child("AuxiliaryLaunch_"+item_id+"_target",true,false),"native launches "+kind+" boundary sortie")
func run() -> void:
	directory=OS.get_environment("XJ_AUXILIARY_BOUNDARIES_V43_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/auxiliary-boundaries-v43/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped auxiliary boundary world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=AtomicHost.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5);await host._command("new_world","辅助母舰损失与超时",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await prepare_owned():await finish();return
	await launch("recon",recon_id);await click(host.ui.body.find_child("DroneOrder_follow",true,false),"actual follow disarms reconnaissance work")
	await run_for(2.0)
	var spec: Dictionary=host.gameplay.auxiliary_drones.spec(recon_id);var dt: float=1.0/host.gameplay.rule("simulation_hz")
	for drone: RefCounted in host.world.projectiles.drones:
		if drone.module_instance_id==recon_id:drone.age_s=float(spec.sortie_timeout_s)-dt
	await run_for(dt*3.0)
	check(host.gameplay.drone_control.live.values().all(func(drone: RefCounted):return drone.returning),"declared finite work deadline causes actual automatic return")
	if not await drain_sorties():await finish();return
	var bay: RefCounted=host.gameplay.auxiliary_drones.bay(recon_id)
	timeout_recovered=check(bay.stock_units==3 and bay.deployed_units==0 and bay.lost_units==0,"physical timed return restores availability without losing surviving probes")
	await capture("aux-timeout-return")
	await launch("recon",recon_id)
	var origin: Vector3=host.world.flight.position
	host.world.flight.position+=Vector3(float(host.gameplay.definition("module_defs","module_id","module_aux_recon_ii").range_m)*1.1,0,0);host.world.flight.write_back();host.world.flight.reset_physics_interpolation()
	for drone: RefCounted in host.world.projectiles.drones:
		if drone.module_instance_id==recon_id:drone.age_s=float(spec.sortie_timeout_s)*2.0-dt
	await run_for(dt*3.0)
	timeout_lost=check(bay.stock_units==0 and bay.deployed_units==0 and bay.lost_units==3 and host.gameplay.drone_control.live.is_empty() and host.world.projectiles.drones.is_empty(),"unrecoverable physical deadline retires entities and charges actual remaining stock once")
	host.world.flight.position=origin;host.world.flight.write_back();host.world.flight.reset_physics_interpolation()
	if not await drain_sorties():await finish();return
	await capture("aux-timeout-lost")
	await launch("repair",repair_id)
	var mother_id: String=host.state.ship().ship_instance_id;var hulls: int=host.state.rows("ship_state").size();var repair: RefCounted=host.gameplay.auxiliary_drones.bay(repair_id);var credit: int=host.state.player().credit
	check(repair.deployed_units==2,"actual repair entities exist before mother destruction")
	# Explicit fatal damage boundary; not evidence of naturally balanced enemy DPS.
	host.gameplay.damage_ship(Vector3(1000000,0,0));await run_for(0.2)
	mother_loss=check(host.state.find("ship_state","ship_instance_id",mother_id).status==T.ShipStatus.DESTROYED and host.gameplay.drone_control.live.is_empty() and host.world.projectiles.drones.is_empty() and repair.lost_units==2,"destroyed mother loses its actual in-space repair drones without ghost entities")
	check(host.state.rows("ship_state").size()==hulls and host.state.player().credit==credit,"fatal mother boundary creates no private replacement or unearned refund")
	check(host.gameplay.crew.member("crew_engineer_1").phase=="injured" and host.gameplay.crew.assignment("crew_engineer_1")==null,"lost mother's real engineer enters rescued injury state")
	check(host.gameplay.owned_fleet.row(owned_id).phase=="retreating","actual surviving owned hull receives emergency retreat")
	await capture("aux-mother-destroyed")
	await host._command("request_rescue","",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	rescue_valid=check(host.state.ship().policy_id!="normal_owned" and host.state.ship().status==T.ShipStatus.DOCKED and host.state.find("ship_state","ship_instance_id",mother_id).status==T.ShipStatus.DESTROYED,"real rescue returns a protected guarantee while preserving destroyed original assets")
	check(host.gameplay.crew.member("crew_engineer_1").phase=="injured" and host.gameplay.owned_fleet.row(owned_id)!=null,"rescue retains actual crew injury and surviving fleet deployment")
	await run_for(host.gameplay.combat_remaining_s+0.1)
	check(host.store.save(host.state,"manual",0),"mother loss timeout and rescued fleet state seal together "+host.store.last_error)
	await capture("aux-mother-rescued")
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var result: String="PASS" if failures.is_empty() else "FAIL"
	print("AUXILIARY_BOUNDARIES_V43_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"timeout_recovered":timeout_recovered,"timeout_lost":timeout_lost,"mother_loss":mother_loss,"rescued":rescue_valid}))
	print("AUXILIARY_BOUNDARIES_V43_RESULT ",result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
