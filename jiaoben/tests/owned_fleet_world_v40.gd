extends "hire_world_v35.gd"
## Funds/licenses/spare hull and encounter isolation are declared fixtures.
## Recruitment/assignment/deployment use real GUI and atomic Main actions.
var owned_id: String=""
var owned_moved_m: float=0.0
var owned_cancelled: bool=false
var owned_arrived: bool=false
class ObservedFaultStore extends FaultStore:
	var rejected_writes: int=0
	func _checkpoint(point: String) -> bool:
		if point==reject_point:rejected_writes+=1
		return super._checkpoint(point)

func reveal(control: Control) -> void:
	# A blocking SQLite open can defer the first scroll/layout update. Settle
	# actual ancestor clipping before the inherited real-pointer click check.
	for attempt: int in range(3):
		if not is_instance_valid(control):return
		await super.reveal(control)
		var visible: bool=true;var parent: Node=control.get_parent()
		while parent!=null:
			if parent is ScrollContainer and not parent.get_global_rect().encloses(control.get_global_rect()):visible=false
			parent=parent.get_parent()
		if visible:return

func _ready() -> void:
	get_tree().set_meta("xj_owned_fleet_world_v40_diagnostic",true)
	get_tree().create_timer(300.0).timeout.connect(func():check(false,"owned fleet native watchdog");finish())
	run.call_deferred()

func owned_fixture() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	candidate.player().credit=1000000
	var home: Dictionary=business.definition("station_defs","station_id","station_anchor_port")
	var flagship: RefCounted=business.inventory.create_ship("frigate_kestrel",home.station_id);candidate.player().controlled_ship_id=flagship.ship_instance_id
	var companion: RefCounted=business.inventory.create_ship("frigate_kestrel",home.station_id);owned_id=companion.ship_instance_id
	place(candidate,business,home.station_anchor_id,home.station_id);business.missions.refresh();business._sync_spawns()
	for npc: RefCounted in candidate.rows("npc_state"):business.frontier._dormant(npc)
	business.dispose();return await activate(candidate)

func run() -> void:
	directory=OS.get_environment("XJ_OWNED_FLEET_WORLD_V40_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/owned-fleet-world-v40/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped owned fleet native world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=AtomicHost.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","自有编队与船员界面",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await owned_fixture():await finish();return
	await show("ships");await click(host.ui.body.find_child("FleetSection_crew",true,false),"opens crew under canonical fleet service")
	check(host.ui.page=="ships" and host.ui.body.find_child("CrewPanel",true,false)!=null,"crew has no duplicate station service")
	var button: Button=host.ui.body.find_child("Crew_hire_crew_pilot_1",true,false);var stale: Callable=button.get_signal_connection_list("pressed")[0].callable
	var before: String=state_signature();var slots: String=JSON.stringify(host.store.list_slots())
	host.reject_stage=true;await click(button,"failed crew model staging")
	check(host.last_error.contains("Declared native staging fault") and state_signature()==before and JSON.stringify(host.store.list_slots())==slots,"staging failure preserves all money crew and save slots");host.reject_stage=false
	var original: RefCounted=host.store;var faulty: ObservedFaultStore=ObservedFaultStore.new(directory.path_join("progress.db"));check(faulty.open(),"isolated crew failure writer opens")
	# Opening a second connection does not acquire an active world. Bind the
	# existing test session so the real SQL sequence/epoch guard still runs.
	faulty.active_state=host.state;faulty.reject_point="state";host.store=faulty;await frames(6)
	if not await click(button,"failed crew SQL commit"):
		host.store=original;faulty.close();await finish();return
	print("OWNED_SQL_FAULT ",JSON.stringify({"rejected_writes":faulty.rejected_writes,"error":faulty.last_error,"state_equal":state_signature()==before,"slots_equal":JSON.stringify(host.store.list_slots())==slots}))
	if not check(faulty.rejected_writes==1 and state_signature()==before and JSON.stringify(host.store.list_slots())==slots,"observed SQL failure publishes no recruitment or fee"):
		host.store=original;faulty.close();await finish();return
	host.store=original;faulty.close();faulty=null
	var credit: int=host.state.player().credit;var cost: int=int(host.gameplay.crew.profession("crew_pilot_1").hire_fee_credit)
	await click(button,"recruits named paid pilot");await settle()
	check(host.gameplay.crew.member("crew_pilot_1").phase=="hired" and host.state.player().credit==credit-cost,"actual crew fee and receipt commit once")
	before=state_signature();stale.call();await frames(3);check(state_signature()==before,"old crew callback cannot charge a replacement world")
	await pick(host.ui.body.find_child("CrewTargetShip",true,false),owned_id)
	await click(host.ui.body.find_child("Crew_assign_crew_pilot_1",true,false),"assigns pilot to selected actual spare hull");await settle()
	check(host.gameplay.crew.assignment("crew_pilot_1").ship_instance_id==owned_id,"crew dropdown identifies unique actual hull")
	await capture("owned-crew")
	await click(host.ui.body.find_child("FleetSection_owned",true,false),"opens owned deployment")
	button=host.ui.body.find_child("Owned_deploy_"+owned_id,true,false);before=state_signature();credit=host.state.player().credit
	host.reject_stage=true;await click(button,"failed owned deployment staging")
	check(host.last_error.contains("Declared native staging fault") and state_signature()==before and host.state.player().credit==credit,"failed deployment preserves original hull pilot and funds");host.reject_stage=false
	await click(button,"deploys existing paid hull");await settle()
	check(host.gameplay.owned_fleet.friendly(owned_id) and host.world.npcs.has(owned_id) and host.state.player().credit==credit-host.gameplay.owned_fleet.quote(owned_id),"committed deployment stages actual body and exact fee")
	for layout: Dictionary in [{"size":Vector2i(1440,900),"scale":1.0,"tag":"standard"},{"size":Vector2i(3440,1188),"scale":1.0,"tag":"ultrawide"},{"size":Vector2i(1280,720),"scale":2.0,"tag":"compact-200"}]:
		root.size=layout.size;root.content_scale_size=Vector2i(Vector2(layout.size)/float(layout.scale));await frames(5);await show("ships")
		for kind: String in ["advance","regroup","focus","retreat","recover"]:
			var control: Control=host.ui.body.find_child("Owned_"+kind+"_"+owned_id,true,false);await reveal(control)
			check(Rect2(Vector2.ZERO,host.ui.root.size).encloses(control.get_global_rect()) and control.size.y>=38,"owned command accessible "+kind+" "+str(layout.tag))
		await capture("owned-"+str(layout.tag))
	root.size=Vector2i(1440,900);root.content_scale_size=root.size;await frames(5)
	await host._command("undock","",1,"");await settle();host.set_process(false);host.set_physics_process(false);await show("ships")
	check(host.ui.body.find_child("Owned_regroup_"+owned_id,true,false)!=null,"owned management remains accessible in space")
	host.ui.show_page("");var initial: Vector3=host.gameplay.position(host.gameplay.owned_fleet.actor(host.gameplay.owned_fleet.row(owned_id)))
	var down:=InputEventKey.new();down.keycode=KEY_W;down.physical_keycode=KEY_W;down.pressed=true;Input.parse_input_event(down);await frames(2);await run_for(6.0)
	var up:=InputEventKey.new();up.keycode=KEY_W;up.physical_keycode=KEY_W;up.pressed=false;Input.parse_input_event(up);await frames(2);await key(KEY_X);await run_for(3.0)
	var actor: RefCounted=host.gameplay.owned_fleet.actor(host.gameplay.owned_fleet.row(owned_id));owned_moved_m=initial.distance_to(host.gameplay.position(actor))
	check(owned_moved_m>50.0 and host.gameplay.position(actor).distance_to(host.gameplay.position(host.gameplay.owned_fleet.ship(owned_id)))<1.0,"actual own body follows and writes original hull pose")
	var gate_id: String="endpoint_anchor_mirror";host.ui._select_target(gate_id);host.ui.tick(1.0);await frames(4)
	if not host.ui.overview.action_buttons.nav_warp.is_visible_in_tree():await click(host.ui.overview.more_actions,"reveals owned AU warp")
	if not check(host.navigation_context(gate_id).warp_ready,"actual own formation ready for AU route"):await finish();return
	var origin_site: String=XJSpaceCoordinates.current_site(host.state);var origin_pose: Vector3=host.gameplay.position(actor)
	await click(host.ui.overview.action_buttons.nav_warp,"begins actual own AU departure")
	host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+20000
	while host.local_navigation.phase=="warmup" and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	check(host.local_navigation.phase=="travel","owned formation reaches actual strategic transit")
	await click(host.ui.navigation_stop_button,"cancels actual owned warp")
	actor=host.gameplay.owned_fleet.actor(host.gameplay.owned_fleet.row(owned_id))
	owned_cancelled=check(not host.local_navigation.active() and XJSpaceCoordinates.current_site(host.state)==origin_site and host.gameplay.position(actor).distance_to(origin_pose)<1.0 and host.world.npcs[owned_id].position.distance_to(host.gameplay.position(actor))<1.0,"cancel restores authoritative original hull actor site and body")
	host.ui._select_target(gate_id);host.ui.tick(1.0);await frames(4)
	if not host.ui.overview.action_buttons.nav_warp.is_visible_in_tree():await click(host.ui.overview.more_actions,"reveals second own warp")
	await click(host.ui.overview.action_buttons.nav_warp,"completes owned AU itinerary")
	if await wait_navigation():
		actor=host.gameplay.owned_fleet.actor(host.gameplay.owned_fleet.row(owned_id))
		owned_arrived=check(host.gameplay.same_entity_site("ship",host.state.ship(),"npc",actor) and host.world.npcs.has(owned_id) and host.world.npcs[owned_id].position.distance_to(host.gameplay.position(actor))<1.0,"real AU arrival keeps actual own hull and physical actor together")
		await capture("owned-au-arrival")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var result: String="PASS" if failures.is_empty() else "FAIL"
	print("OWNED_FLEET_WORLD_V40_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"owned_moved_m":owned_moved_m,"owned_cancelled":owned_cancelled,"owned_arrived":owned_arrived}))
	print("OWNED_FLEET_WORLD_V40_RESULT ",result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
