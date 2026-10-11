extends "frontier_world_v34.gd"
## Qualification, paid conquest arrival poses and forecast/transit boundary are
## declared fixtures. UI payments and real beacon combat run in actual Main.
var sector: String="sector_frontier_01"
var defended: bool=false
var dispatched: bool=false
func _ready() -> void:
	get_tree().set_meta("xj_frontier_governance_world_v34_diagnostic",true)
	get_tree().create_timer(600.0).timeout.connect(func():check(false,"native governance watchdog");finish())
	run.call_deferred()
func conquered_warning(at_core: bool=false) -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var helper: Node=(load(get_script().resource_path.get_base_dir().path_join("frontier_v34.gd")) as Script).new();helper.g=business;helper.state=candidate;helper.store=host.store
	if business.civilizations.owner(sector).is_empty():
		helper.prepare("war_council_01");helper.capture("war_council_01")
	check(helper.failures.is_empty(),"native governance fixture uses actual paid conquest and reconstruction")
	business.frontier.director().next_event_s=0.0;helper.tick(0.1)
	if at_core:helper.at_capital(faction);helper.materials(business.inventory.warehouse(business.station()),int(business.frontier.balance.crisis_supply_base_units))
	else:helper.place(business.definition("frontier_governance_defs","sector_id",sector).defense_anchor_id)
	helper.g=null;helper.state=null;helper.store=null;helper.free();business.dispose();return await activate(candidate)
func forecast_again(at_core: bool=false,near_transit: bool=false) -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var helper: Node=(load(get_script().resource_path.get_base_dir().path_join("frontier_v34.gd")) as Script).new();helper.g=business;helper.state=candidate;helper.store=host.store
	if near_transit:
		candidate.rows("frontier_supply_order_state")[-1].remaining_s=0.5
	else:
		business.frontier.director().next_event_s=0.0;helper.tick(0.1)
	if at_core:helper.at_capital(faction);helper.materials(business.inventory.warehouse(business.station()),int(business.frontier.balance.crisis_supply_base_units))
	else:helper.place(business.definition("frontier_governance_defs","sector_id",sector).defense_anchor_id)
	helper.g=null;helper.state=null;helper.store=null;helper.free();business.dispose();return await activate(candidate)
func run() -> void:
	directory=OS.get_environment("XJ_FRONTIER_GOVERNANCE_WORLD_V34_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/frontier-governance-world-v34/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped native governance world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5);await host._command("new_world","边疆治理原生",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await qualified_frontier():await finish();return
	if not await conquered_warning():await finish();return
	host.ui.frontier_selected_id=sector;await show("frontier");await capture("governance-warning")
	var credit: int=host.state.player().credit;var reserve: int=host.gameplay.frontier.territory(sector).reserve_units
	await click(host.ui.body.find_child("Frontier_secure",true,false),"native uses the real delivered depot reserves")
	check(host.gameplay.frontier.territory(sector).phase=="controlled" and host.gameplay.frontier.territory(sector).reserve_units<reserve and host.state.player().credit==credit,"native supply protection keeps sovereignty without combat reward")
	if not await forecast_again():await finish();return
	await show("frontier");await click(host.ui.body.find_child("Frontier_secure",true,false),"native consumes the remaining deposited reserves")
	if not await forecast_again(true):await finish();return
	await show("frontier")
	var amount: SpinBox=host.ui.body.find_child("FrontierSupplyQuantity",true,false);await enter_number(amount,str(host.gameplay.frontier.balance.crisis_supply_base_units))
	var dispatch: Button=host.ui.body.find_child("Frontier_dispatch",true,false);var stale: Callable=dispatch.get_signal_connection_list("pressed")[0].callable
	credit=host.state.player().credit;var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station());var before_units: int=host.gameplay.inventory.count(warehouse,host.gameplay.frontier.balance.material_id,true)
	await click(dispatch,"native core warehouse pays a strategic supply order")
	check(host.state.rows("frontier_supply_order_state").size()==1 and host.state.player().credit==credit-int(host.gameplay.frontier.balance.dispatch_fee_credit) and host.gameplay.inventory.count(warehouse,host.gameplay.frontier.balance.material_id,true)==before_units-int(host.gameplay.frontier.balance.crisis_supply_base_units),"native dispatch charges exactly the material and fee")
	var signature: String=state_signature();stale.call();await frames(3)
	check(state_signature()==signature,"retired dispatch callback cannot charge a second order")
	dispatched=true;await capture("governance-inflight")
	if not await forecast_again(true,true):await finish();return
	await run_for(1.0)
	check(host.state.rows("frontier_supply_order_state")[0].phase=="delivered" and host.gameplay.frontier.territory(sector).phase=="controlled","real game-time completion delivers and resolves the paid strategic order")
	if not await forecast_again():await finish();return
	await show("frontier");await click(host.ui.body.find_child("Frontier_defend",true,false),"native actual arrival deploys a defense encounter")
	host.set_process(true);host.set_physics_process(true);await settle();await get_tree().physics_frame;await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	var beacon: RefCounted=host.gameplay.frontier._actor_for("","beacon",sector);var beacon_id: String=beacon.npc_instance_id
	host.ui.show_page("");host.ui._select_target(beacon_id);host.ui.tick(1.0);await frames(3)
	if not host.ui.overview.action_buttons.nav_orbit.is_visible_in_tree():await click(host.ui.overview.more_actions,"native reveals beacon positioning")
	await click(host.ui.overview.action_buttons.nav_orbit,"native holds the real beacon defense area")
	var initial: float=hp(beacon_id);var deadline: int=Time.get_ticks_msec()+15000
	host.set_process(true);host.set_physics_process(true)
	while hp(beacon_id)>=initial and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	physical_damage=initial-hp(beacon_id);check(physical_damage>0.0,"actual raid projectiles damage the defended beacon")
	host.ui._select_target(beacon_id);host.ui.tick(1.0);await frames(3)
	await click(host.ui.overview.support_buttons[shield_id],"native support repairs the new defense beacon")
	await capture("governance-real-defense")
	credit=host.state.player().credit;deadline=Time.get_ticks_msec()+90000
	host.set_process(true);host.set_physics_process(true)
	while host.gameplay.frontier.territory(sector).phase=="defending" and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	host.set_process(false);host.set_physics_process(false);host._process(0.0)
	defended=host.gameplay.frontier.territory(sector).phase=="controlled"
	check(defended and host.state.player().credit==credit+int(host.gameplay.frontier.balance.defense_credit),"actual raid pressure and position produce one valid defense reward")
	if not await fixture_boundary():await finish();return
	for layout: Dictionary in [{"size":Vector2i(3440,1188),"scale":1.0,"tag":"ultrawide"},{"size":Vector2i(1280,720),"scale":2.0,"tag":"compact-200"}]:
		root.size=layout.size;root.content_scale_factor=1.0;root.content_scale_size=Vector2i(Vector2(layout.size)/float(layout.scale));await frames(4);await show("frontier")
		check(host.ui.root.size.is_equal_approx(Vector2(root.content_scale_size)),"governance uses exact logical dimensions "+str(layout.tag))
		for name: String in ["FrontierLocate","FrontierNavigate","FrontierSupplyQuantity","Frontier_supply","Frontier_dispatch"]:
			var control: Control=host.ui.body.find_child(name,true,false);await reveal(control);await frames(2)
			check(Rect2(Vector2.ZERO,host.ui.root.size).encloses(control.get_global_rect()),"governance action remains reachable "+name+" "+str(layout.tag))
		await capture("governance-"+str(layout.tag))
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"defended":defended,"dispatched":dispatched,"physical_damage":physical_damage}
	print("FRONTIER_GOVERNANCE_WORLD_V34_FINAL_JSON ",JSON.stringify(summary));print("FRONTIER_GOVERNANCE_WORLD_V34_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
