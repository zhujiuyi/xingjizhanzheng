extends "honors_v33.gd"
## Explicit funds, qualification, variant and arrival-pose fixtures. Physical
## convoy movement and combat pressure require the separate native scene suite.
var conquered: Array[String]=[]
var stages: Array[String]=[]
func _ready() -> void:
	get_tree().set_meta("xj_frontier_v34_diagnostic",true)
	get_tree().create_timer(600.0).timeout.connect(func():print("FRONTIER_V34_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func frontier(action: String,id: String,quantity: int=1) -> bool:
	var result: bool=apply("frontier_action",id,quantity,action+":"+g.frontier.expected_token(id))
	if not result:print("FRONTIER_ACTION_REASON ",action," ",g.last_error)
	return result
func tick(seconds: float) -> void:
	if seconds<=1.0:step(seconds);return
	# Declared strategy-time boundary fixture, not full-world/natural play.
	# Local movement, projectiles and pressure belong to native real-time QA.
	state.snapshot.meta.simulation_tick+=int(ceil(seconds*g.rule("simulation_hz")))
	g.civilizations.tick(seconds);g.frontier.tick(seconds);g.industry.tick(seconds)
func materials(container: String,units: int) -> void:g.inventory.grant(container,g.frontier.balance.material_id,units)
func preserve(index: int,label: String) -> bool:
	var signature: String=full_signature(state)
	if not check(store.save(state,"manual",index),label+" seals all 72 groups "+store.last_error):return false
	var slot: String=saved_slot(index);g.dispose();g=null;state=store.load(slot)
	if not check(state!=null,label+" loads "+store.last_error):return false
	check(full_signature(state)==signature,label+" preserves every typed group and random stream")
	g=Gameplay.new();g.setup(state,store.catalog);return true
func prepare(war_id: String,save_work: bool=false) -> bool:
	at_capital(g.civilizations.allegiance());var warehouse: String=g.inventory.warehouse(g.station());materials(warehouse,int(g.frontier.balance.supply_units))
	var amount: int=g.inventory.count(warehouse,g.frontier.balance.material_id,true)
	check(apply("start_war",war_id),"real core station accepts paid staged war "+war_id)
	var row: RefCounted=g.frontier.campaign(war_id);var war: RefCounted=g.civilizations.active_war();var spec: Dictionary=g.frontier.definition(war_id)
	if not check(war!=null and row.phase=="scouting" and g.inventory.count(warehouse,g.frontier.balance.material_id,true)==amount-int(g.frontier.balance.supply_units),"acceptance escrows exactly the authored ordinary supplies"):return false
	check(g.civilizations.living_fleet(war,"ally").is_empty() and g.civilizations.living_fleet(war,"defender").is_empty(),"battle actors wait for completed preparation")
	check(not frontier("survey",war_id),"distant survey cannot be started from the capital")
	place(spec.scout_anchor_id);cold();var energy: float=state.ship().energy
	check(frontier("survey",war_id),"actual close survey pays once")
	check(state.ship().energy==energy-float(g.frontier.balance.survey_energy_eu) and row.survey_paid,"paid reconnaissance uses real capacitor")
	check(not frontier("survey",war_id),"paid reconnaissance cannot be started twice")
	tick(row.survey_remaining_s/2.0)
	if save_work:
		var remaining: float=row.survey_remaining_s
		if not preserve(0,"partial frontier survey"):return false
		row=g.frontier.campaign(war_id);war=g.civilizations.active_war()
		check(is_equal_approx(row.survey_remaining_s,remaining),"partial paid survey clock is restored without recharging")
		at_capital(g.civilizations.allegiance());tick(1.0)
		check(is_equal_approx(row.survey_remaining_s,remaining),"paid survey pauses outside its real local range")
		place(spec.scout_anchor_id)
	tick(row.survey_remaining_s+0.2)
	check(row.phase=="escorting" and state.rows("frontier_actor_state").size()==3,"completed reconnaissance creates a real convoy and two ambushers")
	var convoy: RefCounted=g.frontier._actor_for(war_id,"convoy")
	check(convoy!=null and convoy.alive and g.civilizations.friendly(convoy.npc_instance_id),"convoy has actual HP and friendly identity")
	var position: Vector3=g.position(convoy);tick(1.0)
	check(row.phase=="escorting" and g.position(convoy)==position,"gameplay-only time cannot fabricate physical convoy movement")
	var exit_: Dictionary=g.definition("anchor_defs","anchor_id",spec.convoy_exit_anchor_id)
	convoy.pos_x=exit_.x_m;convoy.pos_y=exit_.y_m;convoy.pos_z=exit_.z_m # Declared endpoint pose; native suite drives real bodies.
	place(spec.convoy_exit_anchor_id);tick(0.1)
	check(row.supply_delivered and row.phase==spec.battle_kind and g.civilizations.living_fleet(war,"ally").size()==3 and g.civilizations.living_fleet(war,"defender").size()==4,"real endpoint delivery activates the correct battle and seven ordinary fleet actors")
	stages.append(str(row.phase));return true
func capture(war_id: String,save_work: bool=false) -> void:
	var row: RefCounted=g.frontier.campaign(war_id);var war: RefCounted=g.civilizations.active_war();var w: Dictionary=g.definition("civilization_war_defs","war_id",war_id)
	place(w.capture_anchor_id)
	if row.phase=="hold":
		tick(float(g.frontier.balance.hold_s)+0.1)
		check(row.phase=="rebuilding","hold objective succeeds without requiring enemy fleet kills")
	else:
		var actors: Array=state.rows("frontier_actor_state").duplicate()
		for a: RefCounted in actors:
			if a.actor_role!="structure" or a.war_id!=war_id:continue
			var npc: RefCounted=state.find("npc_state","npc_instance_id",a.npc_instance_id)
			check(g.damage_npc(npc.npc_instance_id,Vector3(100000,0,0))>0.0,"real structure HP destruction advances demolition")
		tick(0.1);check(row.demolition_units==2 and row.phase=="rebuilding","two physical structure destructions complete demolition")
	check(g.civilizations.owner(w.target_sector_id).is_empty() and not war.rewards_claimed,"combat completion alone cannot grant sovereignty or rewards")
	materials(g.inventory.hold(state.ship(),T.ContainerKind.CARGO),int(g.frontier.balance.rebuild_units))
	var units: int=g.inventory.count(g.inventory.hold(state.ship(),T.ContainerKind.CARGO),g.frontier.balance.material_id,true)
	check(frontier("repair",war_id),"actual occupation point accepts ordinary reconstruction material")
	check(g.inventory.count(g.inventory.hold(state.ship(),T.ContainerKind.CARGO),g.frontier.balance.material_id,true)==units-int(g.frontier.balance.rebuild_units),"reconstruction consumes its exact one-time material payment")
	check(not frontier("repair",war_id),"paid construction cannot consume or start twice")
	tick(row.repair_remaining_s/2.0)
	if save_work:
		if not preserve(1,"partial frontier reconstruction"):return
		row=g.frontier.campaign(war_id);war=g.civilizations.active_war()
	var credit: int=state.player().credit;var previous: bool=not conquered.is_empty() and w.target_sector_id in conquered
	tick(row.repair_remaining_s+0.1)
	check(row.phase=="completed" and war.status=="won" and g.civilizations.owner(w.target_sector_id)==w.faction_id,"completed reconstruction durably controls the frontier")
	check(state.player().credit==credit+int(g.frontier.balance.recapture_credit if previous else w.reward_credit),"first conquest and repeated recapture use their separate exact reward")
	check(g.frontier.territory(w.target_sector_id).reserve_units==int(g.frontier.balance.supply_units),"depot retains the delivered supplies without generating private cargo")
	if not previous:conquered.append(w.target_sector_id)
	check(not frontier("repair",war_id),"completed conquest cannot reward again")
func warning() -> String:
	g.frontier.director().next_event_s=0.0 # Explicit near-event boundary, not natural timing evidence.
	tick(0.1)
	var d: RefCounted=g.frontier.director()
	check(d.has_active_sector_id and g.frontier.territory(d.active_sector_id).phase=="warning","coarse director starts one real warning in eligible controlled territory")
	return d.active_sector_id
func _run() -> void:
	directory=OS.get_environment("XJ_FRONTIER_V34_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/frontier-v34/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped frontier world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format19 opens "+store.last_error):get_tree().quit(1);return
	state=store.new_world("边疆完整阶段",3401)
	if not check(state!=null,"full staged frontier world seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==87 and state.rows("frontier_campaign_state").size()==24 and state.rows("frontier_territory_state").size()==8,"all existing wars and only eight conquerable sectors receive new authority")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=1000000;g.missions.refresh();g._sync_spawns();hull("transport_caravan");fit("module_scanner_beacon_i","utility:0")
	var faction: String="faction_route_council";qualified_faction(faction)
	check(apply("honor_action",faction,1,"register:unregistered"),"real commander examination registration remains available")
	complete_event("exp_mirror_relic");complete_event("exp_echo_rescue");freight(6);demolition();at_capital(faction)
	check(apply("honor_action",faction,1,"certify:assessing"),"frontier qualification uses four real settled abilities")
	if not prepare("war_council_01",true):await finish();return
	capture("war_council_01",true)
	var sector: String="sector_frontier_01";var station: Dictionary=g.definition("station_defs","station_id",g.definition("frontier_governance_defs","sector_id",sector).station_id)
	at_station(station.station_id);state.ship().armor-=100.0;state.ship().hull-=100.0
	var discounted: int=g.economy.quote_repair();var member: RefCounted=g.civilizations.membership();member.faction_id="faction_deepforge"
	var ordinary: int=g.economy.quote_repair();member.faction_id=faction
	check(discounted<ordinary and g.frontier.station_factor(station.station_id,"repair")==float(g.frontier.balance.repair_fee_ratio),"controlled allegiance changes the actual station repair quote")
	check(g.industry.discount(station.station_id)<=float(g.frontier.balance.industry_fee_ratio),"controlled industry feeds its real service fee multiplier")
	var requirement: Dictionary=g.economy.repair_requirements();var local_store: String=g.inventory.warehouse(g.station())
	materials(local_store,int(requirement.structural_units));var funds: int=state.player().credit;var stock_before: int=g.inventory.count(local_store,g.frontier.balance.material_id,true)
	check(apply("repair"),"controlled repair executes its actual service payment")
	check(state.player().credit==funds-int(requirement.credit) and g.inventory.count(local_store,g.frontier.balance.material_id,true)==stock_before-int(requirement.structural_units),"repair consumes exactly the discounted fee and real repair material")
	var recipe: Dictionary={}
	for candidate: Dictionary in g.rows("recipe_defs"):
		if candidate.output_item_id=="module_engine_vector_i":recipe=candidate;break
	for input: Dictionary in g.rows("recipe_inputs"):
		if input.recipe_id==recipe.recipe_id:g.inventory.grant(local_store,input.item_id,int(input.quantity))
	var fee: int=g.economy.quote_manufacture(recipe.recipe_id,1);funds=state.player().credit
	check(apply("manufacture",recipe.recipe_id,1) and state.player().credit==funds-fee,"controlled industry actually pays its discounted frozen service quote")
	var shop: RefCounted=g.economy._stock("repair_kit_i");shop.quantity=0;shop.refresh_remaining_s=1.0 # Explicit depletion/timer boundary.
	member.faction_id="faction_deepforge";g.economy.tick(0.8)
	check(shop.quantity==0 and shop.refresh_remaining_s>0.0,"foreign allegiance retains ordinary station supply timing")
	member.faction_id=faction;shop.refresh_remaining_s=1.0;g.economy.tick(0.8)
	check(shop.quantity>0 and g.frontier.restock_rate(station.station_id)==float(g.frontier.balance.restock_rate),"controlled stock is really replenished at the improved delivery rate")
	check(g.frontier.hostile_detection_ratio(sector)==float(g.frontier.balance.hostile_detection_ratio),"controlled route safety supplies its actual ordinary-hostile acquisition multiplier")
	var id: String=warning();var credit: int=state.player().credit;var reserve: int=g.frontier.territory(id).reserve_units
	check(frontier("secure",id) and g.frontier.territory(id).reserve_units==reserve-g.frontier.pressure_units(faction) and state.player().credit==credit,"real deposited reserves can resolve a warning without combat rewards")
	id=warning();check(frontier("secure",id),"second supported warning consumes the remaining real reserves")
	id=warning();at_capital(faction);materials(g.inventory.warehouse(g.station()),g.frontier.pressure_units(faction));credit=state.player().credit
	check(frontier("dispatch",id,g.frontier.pressure_units(faction)),"real core warehouse dispatch escrows materials and pays transport")
	check(state.player().credit==credit-int(g.frontier.balance.dispatch_fee_credit),"strategic supply pays its exact finite fee")
	check(not g.frontier.quantity_reason(id,"dispatch",int(g.frontier.balance.reserve_max_units)).is_empty(),"inflight orders reserve their actual depot capacity")
	var order: RefCounted=state.rows("frontier_supply_order_state")[-1];g.frontier.tick(0.0)
	check(order.remaining_s==float(g.frontier.balance.dispatch_s),"paused world time cannot deliver strategic supplies")
	tick(order.remaining_s/2.0)
	if not preserve(2,"inflight strategic supplies and warning"):await finish();return
	order=state.rows("frontier_supply_order_state")[-1];tick(order.remaining_s+0.1)
	check(order.phase=="delivered" and g.frontier.territory(id).phase=="controlled" and state.player().credit==credit-int(g.frontier.balance.dispatch_fee_credit),"actual transit completion resolves the warning once without a free payout")
	id=warning();tick(float(g.frontier.balance.warning_s)+0.1)
	check(g.civilizations.owner(id).is_empty() and g.frontier.territory(id).phase=="neutral" and state.find("war_campaign_state","war_id","war_council_01").status=="won","ignored forecast reverses current sovereignty while retaining historical victory")
	if not preserve(3,"lost territory and historical conquest"):await finish();return
	if not prepare("war_council_01"):await finish();return
	capture("war_council_01")
	if not prepare("war_council_02"):await finish();return
	capture("war_council_02")
	id=warning();place(g.definition("frontier_governance_defs","sector_id",id).defense_anchor_id)
	check(frontier("defend",id),"real arrival deploys the beacon and three actual raid actors")
	check(state.rows("frontier_actor_state").size()==4 and g.frontier._actor_for("","beacon",id).alive,"defense has real HP targets and actor identity")
	credit=state.player().credit;tick(float(g.frontier.balance.hold_s)+0.1)
	check(g.frontier.territory(id).phase=="controlled" and state.player().credit==credit+int(g.frontier.balance.defense_credit),"surviving within the real defense range produces one combat reward")
	check(not frontier("defend",id),"completed defense cannot be deployed or paid again")
	check(Validation.new().validate(state,store.catalog),"all frontier history and costs validate")
	preserve(4,"complete staged wars and governance")
	if not OS.get_environment("XJ_FRONTIER_LEGACY_DATABASE").is_empty():legacy_frontier()
	await finish()
func prior_frontier_signature(value: XJRuntimeState) -> String:
	var data: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		if table in CAMPAIGN_STATE_ADDITIONS:continue
		if table.begins_with("frontier_"):continue
		var rows: Array=[]
		for row: RefCounted in value.rows(table):
			if not campaign_added_row(table,row):rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func legacy_frontier() -> void:
	if g!=null:g.dispose();g=null
	store.close();store=null
	var source: String=OS.get_environment("XJ_FRONTIER_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.file_exists(source),"actual v0.25 legacy fixture is closed and scoped"):return
	var path: String=directory.path_join("legacy.db");check(DirAccess.copy_absolute(source,path)==OK,"copy old territory campaign escrow and paid progress without touching source")
	var faulty: FaultStore=FaultStore.new(path);faulty.failure="migration:022_frontier.sql";store=faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==18,"022 failure preserves actual old format18")
	faulty.failure=""
	if not check(store.open(),"frontier migration retries to format19 "+store.last_error):return
	var slot: Dictionary={}
	for row: Dictionary in store.list_slots():
		if row.slot_kind=="manual" and int(row.slot_index)==2:slot=row;break
	state=store.load(slot.slot_id)
	if not check(state!=null,"actual old conquest and active-war snapshot loads "+store.last_error):return
	check(state.find("war_campaign_state","war_id","war_council_01").status=="won" and state.find("war_campaign_state","war_id","war_council_02").status=="assembling" and state.find("consignment_state","contract_id","freight_anchor_echo").cargo_units==2,"old package has actual completed territory active fleet and paid cargo")
	var before: String=prior_frontier_signature(state);faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and prior_frontier_signature(state)==before,"failed frontier branch preserves all sixty-one old groups")
	faulty.failure="";state=store.upgrade_content(state)
	if not check(state!=null,"reviewed additive frontier branch succeeds "+store.last_error):return
	check(prior_frontier_signature(state)==before,"all sixty-one assets knowledge jobs custody territory campaigns clock and RNG are unchanged on upgrade")
	check(state.rows("frontier_campaign_state").size()==24 and state.rows("frontier_territory_state").size()==8 and state.rows("frontier_actor_state").is_empty(),"upgrade seeds only declared governance and dormant phase state")
	check(state.find("frontier_territory_state","sector_id","sector_frontier_01").phase=="controlled" and state.rows("frontier_director_state")[0].next_event_s==float(store.catalog.rows("frontier_balance_defs")[0].crisis_max_s),"old legitimate territory receives its explicit safe preparation window")
	check(state.find("frontier_campaign_state","war_id","war_council_02").phase=="legacy" and state.find("frontier_campaign_state","war_id","war_council_02").legacy_attempt==1,"old active campaign receives only its exact attempt exemption")
	check(store.upgrade_content(state)==state,"frontier upgrade is idempotent")
	g=Gameplay.new();g.setup(state,store.catalog)
	var war: RefCounted=g.civilizations.active_war();var spec: Dictionary=g.definition("civilization_war_defs","war_id",war.war_id)
	check(not g.frontier.owns_campaign(war) and apply("fleet_command","regroup"),"old active war keeps real original fleet control")
	place(spec.capture_anchor_id)
	for npc: RefCounted in state.rows("npc_state").duplicate():
		if npc.alive and not g.civilizations.friendly(npc.npc_instance_id) and g.same_anchor_site(npc,g.definition("anchor_defs","anchor_id",spec.capture_anchor_id)):g.damage_npc(npc.npc_instance_id,Vector3(100000,0,0))
	g.civilizations.tick(float(spec.capture_duration_s)+0.1)
	check(war.status=="won" and g.frontier.territory(spec.target_sector_id).phase=="controlled","old battle still reaches its original victory and compatible governance")
	check(store.save(state,"manual",3),"completed legacy battle and imported governance seal together "+store.last_error)
	g.dispose();g=null;state=store.load(slot.slot_id)
	check(state!=null and not store.catalog.table_names.has("frontier_campaign_defs") and state.rows("frontier_campaign_state").is_empty() and prior_frontier_signature(state)==before,"original manual snapshot remains independent v0.25 with exact progress")
	legacy_checked=true
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"stages":stages,"conquered":conquered,"legacy_checked":legacy_checked}
	print("FRONTIER_V34_FINAL_JSON ",JSON.stringify(summary));print("FRONTIER_V34_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
