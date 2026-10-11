extends "tactics_world_v29.gd"
## Native controls, rays, opposing fire and 5.2 km travel. Assets/qualification/poses are declared fixtures.
var transport_baseline: XJRuntimeState
func _ready() -> void:
	get_tree().set_meta("xj_operations_world_v30_diagnostic",true)
	get_tree().create_timer(540.0).timeout.connect(func():check(false,"native operation watchdog");finish())
	run.call_deferred()
func button(id: String, verb: String) -> Control:
	return host.ui.body.find_child("OperationAction_"+id+"_"+verb,true,false)
func fixture(id: String, hull_id: String) -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state)
	var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	business._sync_spawns()
	var spec: Dictionary=business.operations.definition(id)
	var home: Dictionary=business.definition("station_defs","station_id",spec.station_id)
	var hull: RefCounted=business.inventory.create_ship(hull_id,home.station_id)
	candidate.player().controlled_ship_id=hull.ship_instance_id;candidate.player().credit=1000000
	place(candidate,business,home.station_anchor_id,home.station_id)
	var gun: String=business.inventory.grant(business.inventory.warehouse(home.station_id),"module_thermal_sunline_iii",1)[0]
	check(business.act("fit_module",gun,1,"weapon:1").phase==T.ActionPhase.APPLIED,"qualified native hull installs legal ray weapon")
	var engine: String=business.inventory.grant(business.inventory.warehouse(home.station_id),"module_engine_vector_i",1)[0]
	check(business.act("fit_module",engine,1,"utility:0").phase==T.ActionPhase.APPLIED,"qualified native hull installs paid propulsion module")
	# Demolition measurements isolate generator rays; opponents remain alive, outside detection.
	if id=="op_demolition":
		for npc: RefCounted in candidate.rows("npc_state"):
			if npc.spawn_id.begins_with("tac_sector_echo"):npc.pos_x+=12000.0
	business.dispose();return await activate(candidate)
func arrive_entry(id: String) -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	place(candidate,business,business.operations.definition(id).entry_anchor_id)
	business.dispose();return await activate(candidate)
func run() -> void:
	directory=OS.get_environment("XJ_OPERATIONS_WORLD_V30_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/operations-world-v30/") and not FileAccess.file_exists(directory.path_join("progress.db")),"native operations require isolated real renderer"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","拆除与突破原生",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await fixture("op_demolition","cruiser_horizon"):await finish();return
	await show("missions");await click(host.ui.body.find_child("MissionOperations",true,false),"mission board opens operation page")
	check(host.ui.page=="operations","operation page has real entry")
	await click(button("op_demolition","accept"),"accept demolition at actual station")
	await capture("operations-board")
	if not await arrive_entry("op_demolition"):await finish();return
	await show("operations");await click(button("op_demolition","start"),"start at real demolition entry")
	await run_for(0.2)
	var targets: Array[String]=[]
	for npc: RefCounted in host.state.rows("npc_state"):
		if host.gameplay.operations.handles(npc.spawn_id):targets.append(npc.npc_instance_id)
	if not check(targets.size()==2 and host.world.npcs.has(targets[0]),"both objective colliders and HP project into real world"):await finish();return
	await capture("operations-jammer-field")
	var before: float=hp(targets[0]);await fire_at(targets[0])
	check(hp(targets[0])<before,"actual Ctrl ray damages generator collider")
	for id: String in targets:
		# Declared near-destruction boundary. Real paid shot must deliver final damage.
		var npc: RefCounted=host.state.find("npc_state","npc_instance_id",id);npc.shield=0;npc.armor=0;npc.hull=1
		await run_for(2.2);await fire_at(id)
		check(not npc.alive,"actual final projectile destroys generator")
	check(host.gameplay.operations.instance("op_demolition").completed_units==2 and host.gameplay.tactics.remaining("tac_sector_echo_group")==3,"demolition objective succeeds while all opposing ships remain alive")
	await capture("operations-generators-disabled")
	# End demolition with an explicit withdrawal, retaining actual destroyed targets.
	await show("operations");await click(button("op_demolition","withdraw"),"withdraw with completed demolition evidence")
	check(host.gameplay.operations.instance("op_demolition").phase=="ready","withdraw retains completed demolition work")
	if not await fixture("op_breakthrough","battleship_bastion"):await finish();return
	await show("operations");await click(button("op_breakthrough","accept"),"accept breakthrough at actual station")
	if not await arrive_entry("op_breakthrough"):await finish();return
	await show("operations");await click(button("op_breakthrough","start"),"load physical cargo at actual entry")
	await run_for(0.2)
	var row: RefCounted=host.gameplay.operations.instance("op_breakthrough")
	check(row.cargo_units==3,"native UI loads three batches into actual large hold")
	transport_baseline=host.store.clone_state(host.state)
	host.ui.show_page("");host.set_process(true);host.set_physics_process(true)
	for down: bool in [true,false]:
		var event: InputEventKey=InputEventKey.new();event.keycode=KEY_SHIFT;event.physical_keycode=KEY_SHIFT;event.pressed=down;event.window_id=root.get_window_id();Input.parse_input_event(event)
		await get_tree().physics_frame;await frames(2)
	host.set_process(false);host.set_physics_process(false)
	check(row.exposure_remaining_s>0.0,"actual Shift paid engine cycle exposes cargo")
	host.preferences.vfx_intensity=0.0;host._apply_preferences();host._process(0.0)
	check(host.ui.objective.text.contains("货物暴露"),"cargo exposure remains readable with effects disabled")
	await frames(4)
	check(host.ui.objective.get_line_count()<=host.ui.objective.max_lines_visible and host.ui.objective.text.begins_with("物资突破"),"active cargo HUD stays within actual visible line budget despite earlier ready demolition")
	await click(host.ui.mission_guide_button,"HUD action details opens current operation")
	check(host.ui.page=="operations","HUD caption and action refer to same operation")
	host.ui.show_page("");host._process(0.0);await frames(3)
	root.size=Vector2i(1280,720);root.content_scale_factor=2.0;await frames(5);host._process(0.0);await frames(3)
	check(host.ui.objective.max_lines_visible==2 and host.ui.objective.get_line_count()<=2 and host.ui.objective.text.contains("货物暴露"),"1280 at 200 percent displays complete two-line exposure HUD")
	check(host.ui.objective.size.y+0.5>=host.ui.objective.get_theme_font("font").get_height(host.ui.objective.get_theme_font_size("font_size"))*host.ui.objective.get_line_count(),"actual compact label height fits all warning lines")
	await capture("operations-exposed-low-effects")
	root.size=Vector2i(1440,900);root.content_scale_factor=1.0;await frames(5);host._process(0.0)
	await run_for(8.0)
	check(row.lost_units>0,"actual siege/interceptor fire destroys exposed cargo")
	observations.append({"kind":"exposure","lost":row.lost_units,"remaining":row.cargo_units})
	await capture("operations-cargo-hit")
	# Restore declared pre-exposure scenario; no rewards are granted for abandoned measurement.
	if not await activate(transport_baseline):await finish();return
	transport_baseline=null;row=host.gameplay.operations.instance("op_breakthrough")
	await show("operations");await click(button("op_breakthrough","jettison"),"trade one batch for lower load")
	check(row.cargo_units==2 and row.jettisoned_units==1,"native jettison updates actual hold and objective ledger")
	var start: Vector3=host.world.flight.position;var start_hp: float=host.state.ship().shield+host.state.ship().armor+host.state.ship().hull
	await click(host.ui.body.find_child("OperationNavigate_op_breakthrough",true,false),"navigate to local breakthrough exit")
	var elapsed: float=0.0
	while elapsed<170.0 and host.world.target_distance("operation:op_breakthrough:exit")>175.0 and host.state.ship().status==T.ShipStatus.FLYING:
		await run_for(2.0);elapsed+=2.0
	host._process(0.0)
	var moved: float=start.distance_to(host.world.flight.position)
	var exit_distance: float=host.world.target_distance("operation:op_breakthrough:exit")
	check(moved>4800.0 and exit_distance<=180.0 and elapsed>20.0,"real navigation traverses 5.2 km without close-range warp")
	var end_hp: float=host.state.ship().shield+host.state.ship().armor+host.state.ship().hull
	check(end_hp<start_hp and row.cargo_units==2,"real opposing damage leaves unexposed cargo intact during breakthrough")
	observations.append({"kind":"breakthrough","moved_m":moved,"exit_distance_m":exit_distance,"seconds":elapsed,"lost":row.lost_units,"jettisoned":row.jettisoned_units,"hp_lost":start_hp-end_hp,"enemies_alive":host.gameplay.tactics.remaining("tac_sector_mirror_group")})
	await capture("operations-breakthrough-route")
	await show("operations");await click(button("op_breakthrough","exit"),"confirm actual delivery at exit")
	check(row.phase=="ready" and row.completed_units==2 and host.gameplay.tactics.remaining("tac_sector_mirror_group")==3,"partial breakthrough succeeds with enemy fleet alive")
	await capture("operations-partial-result")
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var station: String=business.operations.definition("op_breakthrough").station_id;place(candidate,business,business.definition("station_defs","station_id",station).station_anchor_id,station);business.dispose()
	if not await activate(candidate):await finish();return
	root.size=Vector2i(1280,720);root.content_scale_factor=2.0;host._apply_preferences();await show("operations")
	var credit: int=host.state.player().credit
	await click(button("op_breakthrough","claim"),"high-scale partial claim remains reachable")
	check(host.state.player().credit==credit+2*int(host.gameplay.operations.definition("op_breakthrough").credit_per_unit),"native partial claim pays exact credit once")
	await capture("operations-high-scale-claim")
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true;transport_baseline=null
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"observations":observations}
	print("OPERATIONS_WORLD_V30_FINAL_JSON ",JSON.stringify(summary));print("OPERATIONS_WORLD_V30_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
