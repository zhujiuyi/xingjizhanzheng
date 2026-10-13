extends Node
## Initial persistence/crew business checkpoint. Funds, an existing owned hull,
## contribution amounts and near-payroll time are declared fixtures. This does
## not establish natural progression or physical fleet/drone behavior.
const Store=preload("res://runtime/data/store.gd")
const Gameplay=preload("res://runtime/gameplay.gd")
const Codec=preload("res://runtime/data/codec.gd")
const T=preload("res://contracts/contract_types.gd")
var store: Store
var state: XJRuntimeState
var g: Gameplay
var checks: int=0
var failures: Array[String]=[]
var directory: String
func check(ok: bool,message: String) -> bool:
	checks+=1;print(("PASS " if ok else "FAIL ")+message)
	if not ok:failures.append(message)
	return ok
func _ready() -> void:
	get_tree().set_meta("xj_owned_fleet_v40_diagnostic",true)
	get_tree().create_timer(120.0).timeout.connect(func():check(false,"owned fleet business watchdog");finish())
	run.call_deferred()
func action(id: String,kind: String,ship_id: String="") -> bool:
	var extra: String=kind+"|"+g.crew.token(id)+("|"+ship_id if not ship_id.is_empty() else "")
	var result: RefCounted=g.act("crew_action",id,1,extra)
	if result.phase!=T.ActionPhase.APPLIED:print("CREW_REASON ",g.last_error)
	return result.phase==T.ActionPhase.APPLIED
func signature() -> String:
	var data: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		var rows: Array=[]
		for row: RefCounted in state.rows(table):rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary):return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func run() -> void:
	directory=OS.get_environment("XJ_OWNED_FLEET_V40_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/owned-fleet-v40/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh test-owned progress path"):await finish();return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format25 store opens "+store.last_error):await finish();return
	state=store.new_world("自有编队与船员检查",4001)
	if not check(state!=null,"new fleet world seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==114 and state.rows("crew_member_state").size()==8 and state.rows("crew_member_state").all(func(c: RefCounted):return c.phase=="available" and c.generation==0 and c.experience==0),"new roster gives no free employed crew or experience")
	check(state.rows("fleet_deployment_state").is_empty() and not state.rows("npc_state").any(func(n: RefCounted):return n.spawn_id.begins_with("owned_")),"new world never creates duplicate owned actors")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	g.missions.refresh();g._sync_spawns();state.player().credit=100000
	var station: String=g.station();var ship: RefCounted=g.inventory.create_ship("frigate_kestrel",station)
	check(g.act("switch_ship",ship.ship_instance_id).phase==T.ActionPhase.APPLIED,"declared existing ordinary hull can become the flagship")
	var before_turn: float=float(g.metrics(ship).turn_radps);var pilot_id: String="crew_pilot_1";var credits: int=state.player().credit;var old_token: String=g.crew.token(pilot_id)
	check(action(pilot_id,"hire"),"crew recruitment is a real business action")
	check(state.player().credit==credits-int(g.crew.profession(pilot_id).hire_fee_credit),"recruitment deducts the frozen fee exactly")
	credits=state.player().credit
	check(not g.crew.execute(pilot_id,"hire",old_token) and state.player().credit==credits,"stale recruitment cannot charge twice")
	check(action(pilot_id,"assign",ship.ship_instance_id) and float(g.metrics(ship).turn_radps)>before_turn,"pilot assignment improves actual maneuvering metrics")
	check(action("crew_pilot_2","hire"),"second named pilot requires an independent fee")
	check(not action("crew_pilot_2","assign",ship.ship_instance_id),"same profession cannot stack on one hull")
	check(not action("crew_pilot_2","assign","ship-guarantee"),"protected guarantee hull cannot gain owned-fleet crew")
	var companion: RefCounted=g.inventory.create_ship("frigate_kestrel",station)
	check(g.act("switch_ship",companion.ship_instance_id).phase==T.ActionPhase.APPLIED,"declared second owned hull is available for normal fitting")
	var weapon_id: String=g.inventory.grant(g.inventory.warehouse(station),"module_kinetic_needle_i",1)[0]
	check(g.act("fit_module",weapon_id,1,"weapon:0").phase==T.ActionPhase.APPLIED,"companion fits a real declared owned weapon")
	var weapon: Dictionary=g.definition("weapon_defs","module_id","module_kinetic_needle_i")
	var hold: String=g.inventory.hold(companion,T.ContainerKind.CARGO)
	if weapon.ammo_item_id!=null:g.inventory.grant(hold,weapon.ammo_item_id,100)
	check(action("crew_pilot_2","assign",companion.ship_instance_id),"second pilot binds the actual spare hull")
	check(g.act("switch_ship",ship.ship_instance_id).phase==T.ActionPhase.APPLIED,"flagship remains distinct from its deployment")
	var hull_count: int=state.rows("ship_state").size();credits=state.player().credit
	var deploy_token: String=g.owned_fleet.token(companion.ship_instance_id)
	check(g.act("owned_fleet_action",companion.ship_instance_id,1,"deploy|"+deploy_token).phase==T.ActionPhase.APPLIED,"public business action deploys the existing hull")
	check(state.rows("ship_state").size()==hull_count and g.owned_fleet.friendly(companion.ship_instance_id) and state.player().credit==credits-g.owned_fleet.quote(companion.ship_instance_id),"deployment charges exact fee and creates no extra owned ship")
	credits=state.player().credit
	check(not g.owned_fleet.execute(companion.ship_instance_id,"deploy",deploy_token) and state.player().credit==credits,"stale deployment cannot duplicate an actor or fee")
	var energy: float=companion.energy;var ammo: int=g.inventory.count(hold,str(weapon.ammo_item_id),false) if weapon.ammo_item_id!=null else 0
	var paid_cycle: Dictionary=g.consume_weapon_cycle(weapon_id,companion)
	check(not paid_cycle.is_empty() and companion.energy<energy and (weapon.ammo_item_id==null or g.inventory.count(hold,weapon.ammo_item_id,false)==ammo-int(weapon.ammo_per_cycle)),"owned firing cycle consumes its own actual capacitor and ammunition")
	g.owned_fleet.damage_actor(companion.ship_instance_id,Vector3(20,0,0))
	var actor: RefCounted=g.owned_fleet.actor(g.owned_fleet.row(companion.ship_instance_id))
	check(companion.shield<float(g.metrics(companion).shield_max) and actor.shield==companion.shield,"owned actor damage changes the original hull")
	companion.shield+=1.0
	check(not store.save(state,"manual",1),"inconsistent actor/hull health cannot seal")
	companion.shield-=1.0
	check(not g.save_eligible(),"owned paid weapon cycle preserves the existing stable-save barrier")
	g.tick(maxf(g.combat_remaining_s,float(paid_cycle.cycle))+1.0/g.rule("simulation_hz"))
	check(g.save_eligible(),"actual gameplay completes the paid cycle before a stable save")
	check(store.save(state,"manual",1),"paid deployed hull and crew persist together "+store.last_error)
	var member: RefCounted=g.crew.member(pilot_id)
	g.crew.contribute(ship.ship_instance_id,"distance",float(g.crew.profession(pilot_id).contribution_per_xp)*100.0)
	check(member.experience==100 and int(g.crew.rank_for(member).rank)==2 and float(g.metrics(ship).turn_radps)>before_turn,"declared contribution advances finite career and real effect")
	check(g.act("undock").phase==T.ActionPhase.APPLIED,"real undock enables assigned-crew salary clock")
	# Explicit strategy-time boundary, not a claim of 600 seconds of natural play.
	var period: float=float(g.crew.balance.salary_period_s);var dt: float=1.0/g.rule("simulation_hz")
	state.snapshot.meta.simulation_tick=int(ceil(period*g.rule("simulation_hz")))
	member.salary_elapsed_s=period-dt;credits=state.player().credit;var due: int=member.salary_period_credit
	g.tick(dt*2.0)
	check(member.salary_periods==1 and state.player().credit==credits-due and member.salary_paid_credit==due,"actual gameplay tick settles exactly one previously quoted salary")
	var original_xp: int=member.experience;member.experience+=1
	check(not store.save(state,"manual",0),"runtime rejects invented career experience without contribution")
	member.experience=original_xp
	credits=state.player().credit
	g.owned_fleet.damage_actor(companion.ship_instance_id,Vector3(1000000,0,0))
	check(companion.status==T.ShipStatus.DESTROYED and companion.hull==0 and g.owned_fleet.row(companion.ship_instance_id).phase=="lost" and state.find("npc_state","npc_instance_id",companion.ship_instance_id)==null,"fatal damage destroys the original deployed hull and removes its actor")
	check(g.crew.member("crew_pilot_2").phase=="injured" and g.crew.assignment("crew_pilot_2")==null and state.player().credit==credits,"lost crew is rescued without duplicate bounty or refund")
	if not check(store.save(state,"manual",0),"crew salary and contribution seal to SQLite "+store.last_error):await finish();return
	var before: String=signature();var slot: Dictionary={}
	for record: Dictionary in store.list_slots():
		if record.slot_kind=="manual" and int(record.slot_index)==0:slot=record;break
	g.dispose();g=null;state=store.load(slot.slot_id)
	check(state!=null and signature()==before,"all108 state groups and RNG restore exactly")
	await finish()
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	print("OWNED_FLEET_V40_FINAL_JSON ",JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"scope":"crew-store-checkpoint"}))
	print("OWNED_FLEET_V40_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
