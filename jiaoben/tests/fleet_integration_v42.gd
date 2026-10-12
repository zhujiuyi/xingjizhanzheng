extends "owned_fleet_v40.gd"
## Asset/fund/arrival, contribution and payroll boundaries are declared fixtures.
## Tests real business guards, budget accounting, durable quotes and all108 groups.
const Space=preload("res://runtime/space_coordinates.gd")
const Party=preload("res://runtime/data/party_rules.gd")
var buddy_id: String=""
var patch_id: String=""
func _ready() -> void:
	get_tree().set_meta("xj_fleet_integration_v42_diagnostic",true)
	get_tree().create_timer(360.0).timeout.connect(func():check(false,"fleet integration watchdog");finish())
	run.call_deferred()
func place(station_id: String) -> void:
	var station: Dictionary=g.definition("station_defs","station_id",station_id);var anchor: Dictionary=g.definition("anchor_defs","anchor_id",station.station_anchor_id);var ship: RefCounted=state.ship()
	ship.sector_id=station.sector_id;ship.pos_x=anchor.x_m;ship.pos_y=anchor.y_m;ship.pos_z=anchor.z_m;ship.vel_x=0;ship.vel_y=0;ship.vel_z=0;ship.status=T.ShipStatus.DOCKED;ship.has_station_id=true;ship.station_id=station_id
	state.player().has_docked_station_id=true;state.player().docked_station_id=station_id;Space.assign(state,"ship",ship.ship_instance_id,Space.site_for_anchor(g.catalog,anchor.anchor_id));g.inventory.warehouse(station_id)
	for container: RefCounted in state.rows("container_state"):
		if container.has_ship_instance_id and container.ship_instance_id==ship.ship_instance_id:container.sector_id=ship.sector_id
func install(module: String,slot: String) -> String:
	var id: String=g.inventory.grant(g.inventory.warehouse(g.station()),module,1)[0]
	check(g.act("fit_module",id,1,slot).phase==T.ActionPhase.APPLIED,"actual fixture fits "+module);return id
func trial(action: String) -> bool:return g.act("trial_action","trial_support",1,action+"|"+g.scenarios.token("trial","trial_support")).phase==T.ActionPhase.APPLIED
func run() -> void:
	directory=OS.get_environment("XJ_FLEET_INTEGRATION_V42_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/fleet-integration-v42/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh fleet integration scope"):await finish();return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format25 opens "+store.last_error):await finish();return
	state=store.new_world("编队挑战与工程报价",4201)
	if not check(state!=null,"new integration world seals"):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog);state.player().credit=2000000
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	var station: String="station_mirror_hub";var mother: RefCounted=g.inventory.create_ship("support_weaver",station);state.player().controlled_ship_id=mother.ship_instance_id;place(station)
	patch_id=install("module_support_patch_i","work:0");var attack_id: String=install("module_drone_swarm_ii","weapon:0")
	var legacy: Array[String]=[mother.ship_def_id]
	for gear: RefCounted in g.equipped(mother):legacy.append(gear.slot_container_id+":"+gear.item_instance_id+":"+gear.module_def_id)
	legacy.sort();check(g.scenarios.fingerprint()=="|".join(legacy).sha256_text(),"no new roster preserves exact legacy challenge fingerprint")
	var before: int=g.scenarios.budget();var attack: RefCounted=g.drone_control.bay(attack_id);attack.deployed_units=2
	check(g.scenarios.budget()==before,"declared deployed attack count does not double-count surviving stock");attack.deployed_units=0
	var aux_id: String=install("module_aux_repair_i","work:1");var aux: RefCounted=g.auxiliary_drones.bay(aux_id)
	var spec: Dictionary=g.auxiliary_drones.spec(aux_id);var unit: int=int(spec.credit_per_unit)+int(spec.material_per_unit)*int(g.definition("item_defs","item_id",spec.material_id).base_ask_credit)
	check(g.scenarios.budget()==before+int(g.definition("item_defs","item_id","module_aux_repair_i").base_ask_credit)+int(spec.drone_count)*unit,"auxiliary installed module and real stock enter reference budget")
	before=g.scenarios.budget();aux.deployed_units=1;check(g.scenarios.budget()==before,"declared deployed auxiliary count does not double-count stock");aux.deployed_units=0
	check(action("crew_engineer_1","hire"),"engineer pays normal recruitment fee")
	check(g.scenarios.budget()==before,"unassigned recruited crew are not combat loadout")
	check(action("crew_engineer_1","assign",mother.ship_instance_id),"engineer takes actual mother role")
	check(g.scenarios.budget()==before+int(g.crew.profession("crew_engineer_1").hire_fee_credit),"assigned crew add their authored reference cost")
	before=g.scenarios.budget();var buddy: RefCounted=g.inventory.create_ship("frigate_kestrel",station);buddy_id=buddy.ship_instance_id
	check(g.scenarios.budget()==before,"idle owned spare hull is not charged to current battle")
	check(g.act("switch_ship",buddy_id).phase==T.ActionPhase.APPLIED,"spare hull is fitted through normal switch")
	var weapon_id: String=install("module_kinetic_needle_i","weapon:0");var ammo: String=str(g.definition("weapon_defs","module_id","module_kinetic_needle_i").ammo_item_id)
	g.inventory.grant(g.inventory.hold(buddy,T.ContainerKind.CARGO),ammo,13)
	check(action("crew_pilot_1","hire") and action("crew_pilot_1","assign",buddy_id),"spare actual pilot is paid and assigned")
	check(g.act("switch_ship",mother.ship_instance_id).phase==T.ActionPhase.APPLIED,"fixture returns to distinct mother")
	before=g.scenarios.budget()
	check(g.owned_fleet.execute(buddy_id,"deploy",g.owned_fleet.token(buddy_id)),"spare joins actual owned party")
	var expected: int=int(g.definition("ship_defs","ship_id",buddy.ship_def_id).base_ask_credit)+int(g.definition("item_defs","item_id","module_kinetic_needle_i").base_ask_credit)+13*int(g.definition("item_defs","item_id",ammo).base_ask_credit)+int(g.crew.profession("crew_pilot_1").hire_fee_credit)
	check(g.scenarios.budget()==before+expected,"owned party adds original hull weapon cargo ammunition and pilot")
	var heavy: RefCounted=g.inventory.create_ship("battleship_bastion",station)
	check(action("crew_pilot_2","hire") and action("crew_pilot_2","assign",heavy.ship_instance_id),"second existing hull has independent paid pilot")
	check(g.owned_fleet.execute(heavy.ship_instance_id,"deploy",g.owned_fleet.token(heavy.ship_instance_id)),"actual heavy hull joins within fleet cap")
	var credit: int=state.player().credit
	check(g.scenarios.budget()>int(g.scenarios.definition("trial","trial_support").budget_credit) and not trial("accept") and state.player().credit==credit,"full-party over-budget challenge refuses before fee")
	Party.arrive_owned(state,g.catalog)
	check(g.owned_fleet.execute(heavy.ship_instance_id,"recover",g.owned_fleet.token(heavy.ship_instance_id)),"declared close formation permits actual heavy recovery")
	check(trial("accept"),"within-budget party actually binds one challenge")
	var challenge: RefCounted=g.scenarios.instance("trial","trial_support");var stamp: String=challenge.loadout_signature
	check(not g.owned_fleet.execute(heavy.ship_instance_id,"deploy",g.owned_fleet.token(heavy.ship_instance_id)) and not g.owned_fleet.execute(buddy_id,"retreat",g.owned_fleet.token(buddy_id)),"accepted challenge rejects adding or removing party members")
	check(not action("crew_engineer_1","unassign") and not g.inventory.unfit(patch_id) and not g.hired.hire_reason("hire_escort").is_empty(),"accepted challenge locks crew gear and rental changes")
	check(challenge.phase=="accepted" and challenge.loadout_signature==stamp,"rejected changes preserve accepted binding")
	challenge.loadout_signature="0".repeat(64);check(not store.save(state,"manual",0),"snapshot runtime guard rejects invented party binding");challenge.loadout_signature=stamp
	var hold: String=g.inventory.hold(mother,T.ContainerKind.CARGO);var reference: int=challenge.reference_cost;g.inventory.grant(hold,ammo,3);g.scenarios.refresh_bound_trials()
	check(challenge.reference_cost==reference+3*int(g.definition("item_defs","item_id",ammo).base_ask_credit),"reference score records legitimate higher combat supply budget")
	g.inventory.consume(hold,ammo,3,true);g.scenarios.refresh_bound_trials();check(challenge.reference_cost>g.scenarios.budget(),"consuming supplies cannot rewrite a lower historical reference score")
	check(store.save(state,"manual",1),"bound fleet crew and reference score seal together "+store.last_error)
	check(trial("withdraw"),"explicit withdrawal releases roster locks")
	g.inventory.grant(hold,"repair_kit_i",10);check(g.act("undock").phase==T.ActionPhase.APPLIED,"real business undock enables remote support")
	Party.arrive_owned(state,g.catalog);var actor: RefCounted=g.owned_fleet.actor(g.owned_fleet.row(buddy_id));actor.pos_x=mother.pos_x+100;actor.pos_y=mother.pos_y;actor.pos_z=mother.pos_z;g.owned_fleet.sync_hull(g.owned_fleet.row(buddy_id));buddy.armor=0;g.owned_fleet.sync_actor_health(buddy_id)
	g.set_spatial_validator(func(_from: Vector3,_to: Vector3,_id: String):return true) # Declared business LOS stub; native suite owns geometric proof.
	var engineer: RefCounted=g.crew.member("crew_engineer_1");var dt: float=1.0/g.rule("simulation_hz");var period: float=float(g.crew.balance.salary_period_s)
	state.snapshot.meta.simulation_tick=int(ceil(period*g.rule("simulation_hz")))
	check(g.ship_roles.start_support(patch_id,buddy_id),"actual support cycle pays before career changes")
	var quote: RefCounted=state.find("crew_support_quote_state","item_instance_id",patch_id);var paid: float=g.ship_roles.channel(patch_id).paid_restore;var original_loyalty: int=engineer.loyalty
	check(quote!=null and quote.rank_at_payment==1 and quote.loyalty_at_payment==original_loyalty,"paid support captures exact engineer rank and loyalty")
	g.crew.contribute(mother.ship_instance_id,"repair",float(g.crew.profession("crew_engineer_1").contribution_per_xp)*100)
	engineer.salary_elapsed_s=period-dt;g.tick(dt*2)
	check(int(g.crew.rank_for(engineer).rank)==2 and engineer.loyalty>original_loyalty and g.ship_roles.channel(patch_id).paid_restore==paid,"declared contribution and actual payroll cannot reprice a paid repair")
	check(quote.rank_at_payment==1 and quote.loyalty_at_payment==original_loyalty,"quote keeps historical career inputs after current rank and loyalty advance")
	check(g.save_eligible() and store.save(state,"manual",3),"durable paid quote seals mid-cycle after career changes "+store.last_error)
	var saved: String=signature();var slot_id: String=""
	for slot: Dictionary in store.list_slots():
		if slot.slot_kind=="manual" and int(slot.slot_index)==3:slot_id=slot.slot_id;break
	g.dispose();g=null;state=store.load(slot_id)
	if not check(state!=null and signature()==saved,"all108 groups and RNG reopen with original paid quote"):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog);g.set_spatial_validator(func(_from: Vector3,_to: Vector3,_id: String):return true)
	var channel: RefCounted=g.ship_roles.channel(patch_id);var before_hp: float=g.owned_fleet.ship(buddy_id).armor
	for step: int in range(int(ceil(channel.remaining_s/dt))+2):
		if channel.phase!="cycling":break
		g.tick(dt)
	check(is_equal_approx(g.owned_fleet.ship(buddy_id).armor-before_hp,paid) and state.rows("crew_support_quote_state").is_empty(),"reopened real cycle applies original paid amount once then releases quote")
	g.ship_roles.stop_support(patch_id)
	check(g.ship_roles.start_support(patch_id,buddy_id),"next cycle can use current engineer quote")
	var after_pay_energy: float=state.ship().energy;var armor: float=g.owned_fleet.ship(buddy_id).armor
	check(g.act("set_module_enabled",patch_id,1,"off").phase==T.ActionPhase.APPLIED and g.ship_roles.channel(patch_id)==null and state.rows("crew_support_quote_state").is_empty() and state.ship().energy==after_pay_energy and g.owned_fleet.ship(buddy_id).armor==armor,"stop after payment clears durable quote without healing or energy refund")
	check(store.save(state,"manual",0),"final integration receipts and resources remain consistent "+store.last_error)
	await finish()
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var result: String="PASS" if failures.is_empty() else "FAIL"
	print("FLEET_INTEGRATION_V42_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":108}))
	print("FLEET_INTEGRATION_V42_RESULT ",result," checks=",checks," failures=",failures.size());await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
