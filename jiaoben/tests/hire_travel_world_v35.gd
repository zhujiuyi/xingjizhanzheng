extends "hire_world_v35.gd"
## Initial wealth, licenses, owned hull, carried injury and encounter isolation
## are fixtures. AU legs, gate approach, F, costs and endpoints are real.
var crossed: int=0
var cancelled: bool=false
var failed_destination: bool=false
var mass_checked: bool=false
var actor_id: String=""
var carried_armor: float=0.0
func _ready() -> void:
	get_tree().set_meta("xj_hire_travel_world_v35_diagnostic",true)
	get_tree().create_timer(600.0).timeout.connect(func():check(false,"native hired itinerary watchdog");finish())
	run.call_deferred()
func qualification_fixture() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	candidate.player().credit=100000
	var home: Dictionary=business.definition("station_defs","station_id","station_anchor_port")
	var ship: RefCounted=business.inventory.create_ship("frigate_kestrel",home.station_id);candidate.player().controlled_ship_id=ship.ship_instance_id
	place(candidate,business,home.station_anchor_id,home.station_id);business.missions.refresh();business._sync_spawns();business.dispose();return await activate(candidate)
func isolate_and_injure() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var buddy: RefCounted=business.hired.actor();actor_id=buddy.npc_instance_id;buddy.armor-=10.0;carried_armor=buddy.armor
	for n: RefCounted in candidate.rows("npc_state"):
		if n.npc_instance_id==actor_id:continue
		n.alive=false;n.shield=0.0;n.armor=0.0;n.hull=0.0;n.behavior_phase=T.NpcPhase.DEAD;n.bounty_claimed=true;n.loot_claimed=true;n.respawn_remaining_s=6000.0
	business.dispose();return await activate(candidate)
func select_gate(id: String) -> void:
	host.ui.show_page("");host.ui._select_target(id);host.ui.tick(1.0);await frames(4)
func warp_to_gate(id: String) -> bool:
	await select_gate(id)
	if not host.ui.overview.action_buttons.nav_warp.is_visible_in_tree():await click(host.ui.overview.more_actions,"native reveals fleet warp")
	if not check(host.navigation_context(id).warp_ready,"actual fleet is ready for the selected AU leg"):return false
	await click(host.ui.overview.action_buttons.nav_warp,"native takes the hired formation through a real AU leg")
	if not await wait_navigation():return false
	var buddy: RefCounted=host.gameplay.hired.actor()
	check(buddy!=null and buddy.npc_instance_id==actor_id and host.gameplay.same_entity_site("ship",host.state.ship(),"npc",buddy),"completed AU arrival retains the same companion in the player's real site")
	check(buddy.armor==carried_armor,"AU movement does not repair or replace the paid actor")
	check(host.world.npcs.has(actor_id) and host.world.npcs[actor_id].position.distance_to(host.gameplay.position(buddy))<1.0,"arrived companion body matches its authoritative physical pose")
	await select_gate(id)
	await click(host.ui.overview.action_buttons.nav_approach,"native approaches the gate with its physical companion")
	return await wait_navigation()
func gate_attempt(id: String,inject: bool=false) -> bool:
	await settle()
	if not root.has_focus():root.grab_focus();await frames(2)
	if not check(host._keyboard_control_allowed() and bool(host.interaction_context(id).get("ready",false)),"real fleet gate input passes stable distance speed and permissions"):return false
	var endpoint: Dictionary=host.gameplay.definition("gate_endpoint_defs","endpoint_id",id)
	var connection: Dictionary=host.gameplay.definition("effective_connection_defs","connection_id",endpoint.connection_id)
	var origin: String=host.state.current_sector();var credit: int=host.state.player().credit
	var total_mass: float=host.gameplay.metrics(host.state.ship()).total_mass_kg+host.gameplay.hired.party_mass_kg()
	var gate: RefCounted=host.state.find("gate_state","connection_id",connection.connection_id)
	var finite: bool=gate.has_remaining_mass_budget_kg;var budget: float=gate.remaining_mass_budget_kg
	host.reject_stage=inject
	await key(KEY_F)
	var transfer: RefCounted=host.travel;var tx: String=transfer.transfer_id
	if not check(transfer.active(),"actual F starts a fleet wormhole transfer"):return false
	host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+45000
	while (host.travel.active() or host.busy) and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	await get_tree().physics_frame;await get_tree().physics_frame;host.set_process(false);host.set_physics_process(false);host._process(0.0);host.reject_stage=false
	if inject:
		var buddy: RefCounted=host.gameplay.hired.actor()
		failed_destination=check(host.state.current_sector()==origin and host.state.player().credit==credit and buddy!=null and buddy.sector_id==origin and buddy.armor==carried_armor,"failed destination preparation preserves original funds actor and carried injury")
		var saved: Array[Dictionary]=host.store._records("SELECT snapshot_id FROM save_snapshot WHERE transfer_id=? AND reason='travel_origin' AND status='sealed'",[tx])
		check(saved.size()==1,"failed transfer retains its actual durable origin checkpoint")
		return failed_destination
	if not check(host.state.current_sector()==endpoint.target_sector_id and not host.travel.active(),"real fleet wormhole transfer commits the selected destination"):return false
	crossed+=1
	check(host.state.player().credit==credit-int(connection.fee_credit)*2,"fleet charges each of the two actual ships once")
	var buddy: RefCounted=host.gameplay.hired.actor()
	check(buddy!=null and buddy.npc_instance_id==actor_id and buddy.armor==carried_armor and buddy.sector_id==host.state.current_sector() and host.gameplay.same_entity_site("ship",host.state.ship(),"npc",buddy),"cross-sector arrival keeps identity injury and authoritative companion location")
	if finite:
		var after: RefCounted=host.state.find("gate_state","connection_id",connection.connection_id)
		mass_checked=check(is_equal_approx(after.remaining_mass_budget_kg,budget-total_mass),"real finite wormhole consumes combined player and companion mass")
	var snapshots: Array[Dictionary]=host.store._records("SELECT s.reason,n.sector_id,h.site_id,h.profile_id FROM save_snapshot s JOIN npc_state n ON n.snapshot_id=s.snapshot_id JOIN hire_contract_state h ON h.snapshot_id=s.snapshot_id AND h.npc_instance_id=n.npc_instance_id WHERE s.transfer_id=? AND s.status='sealed' AND n.npc_instance_id=? ORDER BY s.reason",[tx,actor_id])
	check(snapshots.size()==2 and snapshots[0].sector_id==endpoint.target_sector_id and snapshots[1].sector_id==origin,"both durable transfer endpoints contain the same paid mobile actor")
	return true
func run() -> void:
	directory=OS.get_environment("XJ_HIRE_TRAVEL_WORLD_V35_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/hire-travel-world-v35/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped native hired itinerary"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=AtomicHost.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5);await host._command("new_world","僚舰真实航程",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await qualification_fixture():await finish();return
	await show("hire");await click(host.ui.body.find_child("Hire_hire_escort",true,false),"native hires its itinerary companion at the origin station")
	if not await isolate_and_injure():await finish();return
	await host._command("undock","",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	var id: String="endpoint_anchor_mirror";await select_gate(id)
	var origin_site: String=XJSpaceCoordinates.current_site(host.state);var origin_pose: Vector3=host.gameplay.position(host.gameplay.hired.actor())
	if not host.ui.overview.action_buttons.nav_warp.is_visible_in_tree():await click(host.ui.overview.more_actions,"native reveals its first AU fleet warp")
	await click(host.ui.overview.action_buttons.nav_warp,"native begins a cancellable fleet departure")
	host.set_process(true);host.set_physics_process(true);var deadline: int=Time.get_ticks_msec()+15000
	while host.local_navigation.phase=="warmup" and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	check(host.local_navigation.phase=="travel","fleet cancellation fixture reaches actual AU transit")
	await capture("hire-transit")
	await click(host.ui.navigation_stop_button,"native cancels its fleet warp in transit")
	var buddy: RefCounted=host.gameplay.hired.actor()
	cancelled=check(not host.local_navigation.active() and XJSpaceCoordinates.current_site(host.state)==origin_site and buddy!=null and host.gameplay.position(buddy).distance_to(origin_pose)<1.0 and buddy.armor==carried_armor,"cancelled AU route restores the paid companion's original site pose and injury")
	await capture("hire-transit-cancelled")
	if not await warp_to_gate(id):await finish();return
	await capture("hire-gate-formation")
	# Temporary quota boundary validates readiness only, never an illegal save.
	var gate: RefCounted=host.state.find("gate_state","connection_id","conn_anchor_mirror");var had_budget: bool=gate.has_remaining_mass_budget_kg;var old_budget: float=gate.remaining_mass_budget_kg
	gate.has_remaining_mass_budget_kg=true;gate.remaining_mass_budget_kg=host.gameplay.metrics(host.state.ship()).total_mass_kg+host.gameplay.hired.party_mass_kg()-1.0
	check(not bool(host.interaction_context(id).get("ready",false)),"real interaction refuses an insufficient combined fleet quota")
	gate.has_remaining_mass_budget_kg=had_budget;gate.remaining_mass_budget_kg=old_budget
	if not await gate_attempt(id,true):await finish();return
	if not await gate_attempt(id):await finish();return
	await capture("hire-first-gate-arrival")
	var wandering: Dictionary={}
	for endpoint: Dictionary in host.gameplay.rows("gate_endpoint_defs"):
		if endpoint.origin_sector_id==host.state.current_sector() and endpoint.connection_id=="conn_wandering_mirror_mist":wandering=endpoint;break
	if not check(not wandering.is_empty(),"real destination exposes the authored finite wandering gate"):await finish();return
	if not await warp_to_gate(wandering.endpoint_id):await finish();return
	if not await gate_attempt(wandering.endpoint_id):await finish();return
	await capture("hire-finite-gate-arrival")
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"crossed":crossed,"cancelled":cancelled,"failed_destination":failed_destination,"mass_checked":mass_checked}
	print("HIRE_TRAVEL_WORLD_V35_FINAL_JSON ",JSON.stringify(summary));print("HIRE_TRAVEL_WORLD_V35_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
