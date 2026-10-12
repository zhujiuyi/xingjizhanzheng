extends "owned_fleet_v40.gd"
## Declared funds/hulls/licenses, formation poses and boundary energy/quota.
## Exercises actual travel controller and SQLite; physical travel is separate.
const Travel=preload("res://runtime/travel.gd")
const Party=preload("res://runtime/data/party_rules.gd")
const Space=preload("res://runtime/space_coordinates.gd")
class FaultStore extends Store:
	var failure: String=""
	func _checkpoint(point: String) -> bool:
		if point!="state" or failure.is_empty():return true
		return _records("SELECT reason FROM save_snapshot ORDER BY rowid DESC LIMIT 1")[0].reason!=failure

func _ready() -> void:
	get_tree().set_meta("xj_owned_fleet_travel_v40_diagnostic",true)
	get_tree().create_timer(300.0).timeout.connect(func():check(false,"fleet travel transaction watchdog");finish())
	run.call_deferred()

func run() -> void:
	directory=OS.get_environment("XJ_OWNED_FLEET_TRAVEL_V40_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/owned-fleet-travel-v40/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("success/progress.db")),"fresh scoped fleet travel directory"):await finish();return
	for scenario: String in ["cancel","origin_failure","prepare_failure","destination_failure","success"]:
		var database: FaultStore=FaultStore.new(directory.path_join(scenario+"/progress.db"));store=database
		if not check(store.open(),scenario+" store opens "+store.last_error):break
		state=store.new_world("编队事务边界",4010)
		if not check(state!=null,scenario+" world creates "+store.last_error):break
		g=Gameplay.new();g.setup(state,store.catalog);state.player().credit=1000000
		for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
		var station: String=g.station();var companions: Array=[]
		for index: int in range(2):
			var hull: RefCounted=g.inventory.create_ship("frigate_kestrel",station);companions.append(hull)
			var profile_id: String="crew_pilot_"+str(index+1)
			check(action(profile_id,"hire") and action(profile_id,"assign",hull.ship_instance_id),scenario+" pays and assigns independent pilot")
			check(g.owned_fleet.execute(hull.ship_instance_id,"deploy",g.owned_fleet.token(hull.ship_instance_id)),scenario+" deploys existing owned hull")
		var cargo: String=g.inventory.hold(companions[0],T.ContainerKind.CARGO)
		var ammo: String=str(g.definition("weapon_defs","module_id","module_kinetic_needle_i").ammo_item_id)
		g.inventory.grant(cargo,ammo,7);g.inventory.grant(cargo,"module_kinetic_needle_i",1)
		check(g.act("undock").phase==T.ActionPhase.APPLIED,scenario+" undocks actual leader")
		var endpoint: Dictionary=g.definition("gate_endpoint_defs","endpoint_id","endpoint_anchor_mirror")
		var connection: Dictionary=g.definition("effective_connection_defs","connection_id",endpoint.connection_id)
		var anchor: Dictionary=g.definition("anchor_defs","anchor_id",endpoint.entry_anchor_id);var leader: RefCounted=state.ship()
		leader.pos_x=anchor.x_m;leader.pos_y=anchor.y_m;leader.pos_z=anchor.z_m;leader.vel_x=0;leader.vel_y=0;leader.vel_z=0
		Space.assign(state,"ship",leader.ship_instance_id,Space.site_for_anchor(g.catalog,anchor.anchor_id));Party.arrive_owned(state,g.catalog)
		for npc: RefCounted in state.rows("npc_state"):
			if not g.owned_fleet.friendly(npc.npc_instance_id):g.frontier._dormant(npc)
		var total_mass: float=Party.hull_mass(state,g.catalog,leader)+g.hired.party_mass_kg()
		check(g.hired.party_fee(int(connection.fee_credit))==3*int(connection.fee_credit),scenario+" quotes all three hulls once")
		check(g.hired.party_mass_kg()>float(g.definition("ship_defs","ship_id","frigate_kestrel").dry_mass_kg)*2 and g.hired.largest_party_mass_kg()<g.hired.party_mass_kg(),scenario+" gross cargo and largest single hull remain distinct")
		var deployment: RefCounted=g.owned_fleet.row(companions[0].ship_instance_id);var npc: RefCounted=g.owned_fleet.actor(deployment)
		var origin_poses: Array[Dictionary]=g.owned_fleet.departure_poses()
		npc.pos_x+=float(g.owned_fleet.balance.warp_ready_m)*2;g.owned_fleet.sync_hull(deployment)
		check(not g.hired.travel_reason().is_empty(),scenario+" actual out-of-formation pose blocks departure")
		g.owned_fleet.restore_departure(origin_poses)
		check(g.hired.travel_reason().is_empty() and Party.departure_valid(state,g.catalog,g.owned_fleet.departure_poses()),scenario+" restored paid formation is ready")
		var energy: float=companions[0].energy;companions[0].energy=0
		var travel: Travel=Travel.new();travel.setup(state,store,func(_candidate: XJRuntimeState)->bool:return scenario!="prepare_failure",Callable(),g.save_eligible)
		check(not travel.begin(endpoint.endpoint_id) and state.player().credit>0,scenario+" own capacitor prevents unsupported gate transfer")
		companions[0].energy=energy
		var cooldown:=preload("res://contracts/contract_dtos.gd").ShipGateCooldownStateDto.new();cooldown.ship_instance_id=companions[0].ship_instance_id;cooldown.remaining_s=float(connection.cooldown_s);state.add("ship_gate_cooldown_state",cooldown)
		check(not travel.begin(endpoint.endpoint_id),scenario+" each owned hull has an independent gate cooldown")
		state.remove("ship_gate_cooldown_state",cooldown)
		var gate: RefCounted=state.find("gate_state","connection_id",connection.connection_id);var finite: bool=gate.has_remaining_mass_budget_kg;var budget: float=gate.remaining_mass_budget_kg
		gate.has_remaining_mass_budget_kg=true;gate.remaining_mass_budget_kg=total_mass-1
		check(not travel.begin(endpoint.endpoint_id),scenario+" combined mass cannot exceed remaining quota")
		gate.has_remaining_mass_budget_kg=finite;gate.remaining_mass_budget_kg=budget
		if not check(store.save(state,"manual",0),scenario+" origin fleet seals "+store.last_error):break
		var before: String=signature();var credit: int=state.player().credit;var leader_energy: float=leader.energy
		check(travel.begin(endpoint.endpoint_id),scenario+" legal paid gate charge begins "+travel.last_error)
		var transfer_id: String=travel.transfer_id
		if scenario=="cancel":check(travel.cancel(),"charging cancellation accepts")
		else:
			database.failure="travel_origin" if scenario=="origin_failure" else "travel_destination" if scenario=="destination_failure" else ""
			travel.tick(travel.remaining_s+0.01)
		check(not travel.active(),scenario+" transition terminates")
		if scenario!="success":
			# A committed origin adds a transfer row but no owned resource or pose change.
			for row: RefCounted in state.rows("transfer_state").duplicate():state.remove("transfer_state",row)
			check(signature()==before and travel.ready_candidate==null,scenario+" preserves all fleet assets resources poses and crew")
			check(store._records("SELECT transfer_barrier_id FROM runtime_session")[0].transfer_barrier_id==null,scenario+" releases transfer barrier")
		else:
			var arrived: XJRuntimeState=travel.ready_candidate
			if check(arrived!=null,"complete owned party commits destination "+store.last_error):
				check(arrived.player().credit==credit-3*int(connection.fee_credit) and arrived.ship().energy==leader_energy-float(connection.energy_cost_eu),"destination charges whole party and leader energy exactly once")
				for original: RefCounted in companions:
					var carried: RefCounted=arrived.find("ship_state","ship_instance_id",original.ship_instance_id);var actor: RefCounted=arrived.find("npc_state","npc_instance_id",original.ship_instance_id)
					check(carried!=null and actor!=null and carried.energy==original.energy-float(connection.energy_cost_eu) and carried.sector_id==endpoint.target_sector_id and actor.sector_id==carried.sector_id and Space.site_for_entity(arrived,"npc",actor.npc_instance_id)==Space.current_site(arrived),"owned hull arrives with paid energy and authoritative paired location")
					check(arrived.find("ship_gate_cooldown_state","ship_instance_id",original.ship_instance_id).remaining_s==float(connection.cooldown_s),"owned cooldown persists at destination")
				var records: Array[Dictionary]=store._records("SELECT s.reason,COUNT(f.ship_instance_id) AS count FROM save_snapshot s JOIN fleet_deployment_state f ON f.snapshot_id=s.snapshot_id WHERE s.transfer_id=? AND s.status='sealed' AND f.phase='deployed' GROUP BY s.reason",[transfer_id])
				check(records.size()==2 and records.all(func(r: Dictionary):return int(r.count)==2),"both durable endpoints preserve both original fleet identities")
				g.dispose();g=null;state=arrived;var saved: String=signature();var slot: Dictionary={}
				for value: Dictionary in store.list_slots():
					if value.slot_kind=="auto":slot=value;break
				state=store.load(slot.slot_id);check(state!=null and signature()==saved,"all108 groups reopen after party transfer")
		if g!=null:g.dispose();g=null
		state=null;store.close();store=null
	await finish()

func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	print("OWNED_FLEET_TRAVEL_V40_FINAL_JSON ",JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":108}))
	print("OWNED_FLEET_TRAVEL_V40_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
