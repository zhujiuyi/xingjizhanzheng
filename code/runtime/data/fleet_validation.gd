extends RefCounted
const T=preload("res://contracts/contract_types.gd")
const TABLES: Array[String]=["fleet_deployment_state","fleet_receipt_state","fleet_total_state","auxiliary_bay_state","auxiliary_intel_state"]
var last_error: String=""
func fail(message: String) -> bool:last_error=message;return false
static func actor_binding(state: XJRuntimeState,catalog: XJCatalog,id: String) -> bool:
	if not catalog.table_names.has("fleet_hull_defs") or id.is_empty():return false
	var row: RefCounted=state.find("fleet_deployment_state","ship_instance_id",id)
	var ship: RefCounted=state.find("ship_state","ship_instance_id",id)
	var npc: RefCounted=state.find("npc_state","npc_instance_id",id)
	if row==null or ship==null or npc==null or row.phase not in ["deployed","retreating"] or not row.has_npc_instance_id or row.npc_instance_id!=id:return false
	var spec: Dictionary=catalog.one("fleet_hull_defs","ship_id",ship.ship_def_id)
	return not spec.is_empty() and ship.policy_id=="normal_owned" and ship.owner_player_id==state.player().player_id and ship.status==T.ShipStatus.FLYING and npc.alive and npc.generation==row.actor_generation and npc.spawn_id==spec.spawn_id and npc.sector_id==row.sector_id and ship.sector_id==row.sector_id
static func pilot_ready(state: XJRuntimeState,catalog: XJCatalog,ship_id: String) -> bool:
	var balance: Dictionary=catalog.rows("fleet_balance_defs")[0]
	for a: RefCounted in state.rows("crew_assignment_state"):
		if a.ship_instance_id!=ship_id:continue
		var job: Dictionary=catalog.one("crew_profession_defs","profession_id",a.profession_id)
		var row: RefCounted=state.find("crew_member_state","profile_id",a.profile_id)
		if job.get("duty_kind","")=="pilot" and row!=null and row.phase=="hired" and row.loyalty>=int(balance.loyalty_ready_min) and row.unpaid_periods<int(balance.arrears_period_limit):return true
	return false
func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("fleet_balance_defs"):
		for table: String in TABLES:
			if not state.rows(table).is_empty():return fail("Owned fleet rows under legacy rules")
		return true
	var balance: Dictionary=catalog.rows("fleet_balance_defs")[0];var tick: int=state.snapshot.meta.simulation_tick
	if state.rows("fleet_total_state").size()!=1:return fail("Owned fleet total singleton missing")
	var total: RefCounted=state.rows("fleet_total_state")[0]
	if total.singleton!=1 or total.deployments<0 or total.returns<0 or total.losses<0 or total.paid_credit<0 or total.returns+total.losses>total.deployments:return fail("Owned fleet totals invalid")
	for field: String in ["damage_dealt","damage_taken","provided_repair_hp"]:
		if not is_finite(float(total.get(field))) or float(total.get(field))<0:return fail("Owned contribution totals invalid")
	var seen: Dictionary={};var active: int=0;var generations: int=0;var paid: int=0
	for row: RefCounted in state.rows("fleet_deployment_state"):
		var ship: RefCounted=state.find("ship_state","ship_instance_id",row.ship_instance_id)
		if ship==null or seen.has(row.ship_instance_id) or ship.policy_id!="normal_owned" or row.generation<1 or row.actor_generation<row.generation or row.phase not in ["deployed","retreating","returning","docked","lost"]:return fail("Owned fleet identity/lifecycle invalid")
		seen[row.ship_instance_id]=row;generations+=row.generation;paid+=row.deploy_paid_credit
		var def: Dictionary=catalog.one("ship_defs","ship_id",ship.ship_def_id)
		var quote: int=int(balance.deploy_fee_credit)+int(ceil(float(def.base_ask_credit)*float(balance.deploy_hull_fee_bp)/10000.0))
		if row.deploy_paid_credit!=row.generation*quote or row.order_revision<0 or row.created_tick<0 or row.created_tick>tick or row.finished_tick>tick:return fail("Owned fleet payment/time mismatch")
		for field: String in ["goal_x","goal_y","goal_z","retreat_origin_x","retreat_origin_y","retreat_origin_z","retreat_remaining_s","return_remaining_s"]:
			if not is_finite(float(row.get(field))):return fail("Owned fleet nonfinite pose/timer")
		if row.retreat_remaining_s<0 or row.retreat_remaining_s>float(balance.retreat_charge_s) or row.return_remaining_s<0 or row.return_remaining_s>float(balance.return_s):return fail("Owned fleet timer outside budget")
		if row.phase in ["deployed","retreating","returning"]:active+=1
		if row.phase in ["deployed","retreating"]:
			if not actor_binding(state,catalog,row.ship_instance_id) or ship.ship_instance_id==state.player().controlled_ship_id:return fail("Owned actor is not a separate ordinary hull")
			if row.phase=="deployed" and not pilot_ready(state,catalog,row.ship_instance_id):return fail("Deployed owned hull lacks an available pilot")
			var npc: RefCounted=state.find("npc_state","npc_instance_id",row.npc_instance_id)
			for field: String in ["shield","armor","hull","pos_x","pos_y","pos_z","quat_x","quat_y","quat_z","quat_w","vel_x","vel_y","vel_z"]:
				if absf(float(ship.get(field))-float(npc.get(field)))>0.00001:return fail("Owned actor differs from authoritative hull "+field)
			for kind: String in ["ship","npc"]:
				var spatial: RefCounted=null
				for candidate: RefCounted in state.rows("spatial_state"):
					if candidate.entity_kind==kind and candidate.entity_id==row.ship_instance_id:spatial=candidate;break
				if spatial==null or spatial.site_id!=row.site_id:return fail("Owned actor/hull spatial binding differs")
		elif row.has_npc_instance_id:return fail("Settled/returning fleet retains a local actor")
		if row.phase=="returning":
			var station: Dictionary=catalog.one("station_defs","station_id",row.return_station_id)
			if ship.status!=T.ShipStatus.FLYING or not row.has_return_station_id or station.is_empty() or station.sector_id!=row.sector_id or row.return_remaining_s<=0:return fail("Owned return cannot teleport across sectors")
		elif row.return_remaining_s!=0:return fail("Inactive fleet return timer")
		if row.phase!="retreating" and row.retreat_remaining_s!=0:return fail("Inactive owned retreat timer")
		if row.phase=="lost" and (ship.status!=T.ShipStatus.DESTROYED or ship.hull!=0):return fail("Lost owned hull is still usable")
		if row.phase in ["docked","lost"] and (row.finished_tick<row.created_tick or row.end_reason.is_empty()):return fail("Owned fleet outcome is missing")
		if row.order_kind not in ["advance","regroup","focus","retreat"] or (row.order_kind=="focus")!=row.has_focus_target_id:return fail("Owned command/target mismatch")
		if row.has_focus_target_id:
			var target: RefCounted=state.find("npc_state","npc_instance_id",row.focus_target_id)
			if target==null or not target.alive or target.sector_id!=row.sector_id or actor_binding(state,catalog,row.focus_target_id):return fail("Owned focus target unavailable/friendly")
	if active>int(balance.max_owned_companions) or total.deployments<generations or total.paid_credit<paid:return fail("Owned fleet capacity/totals mismatch")
	for npc: RefCounted in state.rows("npc_state"):
		if not catalog.one("fleet_hull_defs","spawn_id",npc.spawn_id).is_empty() and not actor_binding(state,catalog,npc.npc_instance_id):return fail("Unbound owned actor")
	for trial: RefCounted in state.rows("trial_state"):
		if trial.phase not in ["accepted","active","ready"]:continue
		var hull: RefCounted=state.find("ship_state","ship_instance_id",trial.ship_instance_id)
		if hull==null or trial.loadout_signature!=preload("res://runtime/data/loadout_rules.gd").fingerprint(state,catalog,hull):return fail("Challenge party or crew binding mismatch")
	var bays: Dictionary={}
	for row: RefCounted in state.rows("auxiliary_bay_state"):
		var item: RefCounted=state.find("item_instance_state","item_instance_id",row.item_instance_id)
		var spec: Dictionary=catalog.one("auxiliary_drone_defs","module_id",item.item_def_id) if item!=null else {}
		if spec.is_empty() or bays.has(row.item_instance_id):return fail("Auxiliary bay identity invalid")
		bays[row.item_instance_id]=row
		if row.stock_units<0 or row.stock_units>int(spec.drone_count) or row.lost_units<0 or row.replenished_units<0 or row.stock_units+row.lost_units!=int(spec.drone_count)+row.replenished_units or row.deployed_units!=0:return fail("Auxiliary stock or outstanding sortie invalid")
		if row.paid_credit_total!=row.replenished_units*int(spec.credit_per_unit) or row.material_units_total!=row.replenished_units*int(spec.material_per_unit) or row.revision<0 or row.sorties<0 or row.command_kind not in ["follow","recall"]:return fail("Auxiliary replenishment/payment mismatch")
		var module: Dictionary=catalog.one("module_defs","module_id",item.item_def_id)
		if not is_finite(row.energy_paid_total) or not is_finite(row.heat_paid_total) or absf(row.energy_paid_total-row.sorties*float(module.energy_eu))>0.00001 or absf(row.heat_paid_total-row.sorties*float(module.heat_hu))>0.00001 or row.consumable_paid_units!=row.sorties*int(spec.consumable_per_sortie):return fail("Auxiliary sortie lacks actual resource accounting")
		if not is_finite(row.repaired_hp) or row.repaired_hp<0 or row.repaired_hp>row.sorties*int(spec.drone_count)*float(spec.restore_amount)*item.quality_multiplier+0.00001 or (spec.role_kind=="recon" and row.repaired_hp!=0):return fail("Auxiliary role contribution invalid")
	for item: RefCounted in state.rows("item_instance_state"):
		if not catalog.one("auxiliary_drone_defs","module_id",item.item_def_id).is_empty() and not bays.has(item.item_instance_id):return fail("Auxiliary stock is missing")
	var roles: Dictionary={}
	for equipment: RefCounted in state.rows("equipment_state"):
		var definition: Dictionary=catalog.one("auxiliary_drone_defs","module_id",equipment.module_def_id)
		if definition.is_empty():continue
		var container: RefCounted=state.find("container_state","container_id",equipment.slot_container_id)
		var owner: RefCounted=state.find("ship_state","ship_instance_id",container.ship_instance_id) if container!=null and container.has_ship_instance_id else null
		var permission: Dictionary={}
		for allowed: Dictionary in catalog.rows("ship_auxiliary_permissions"):
			if owner!=null and allowed.ship_id==owner.ship_def_id and allowed.role_kind==definition.role_kind:permission=allowed;break
		if permission.is_empty():return fail("Auxiliary hull permission missing")
		var key: String=owner.ship_instance_id+":"+str(definition.role_kind);roles[key]=int(roles.get(key,0))+1
		if int(roles[key])>int(permission.max_installed):return fail("Auxiliary hull installation limit exceeded")
	for row: RefCounted in state.rows("auxiliary_intel_state"):
		var spec: Dictionary=catalog.one("auxiliary_drone_defs","module_id",row.module_id);var site: Dictionary=catalog.one("site_defs","site_id",row.site_id)
		if spec.get("role_kind","")!="recon" or row.observed_label.is_empty() or row.observed_label.length()>96 or state.find("ship_state","ship_instance_id",row.owner_ship_id)==null or site.get("sector_id","")!=row.sector_id or row.observed_tick<0 or row.observed_tick>tick or row.target_generation<0 or row.target_kind not in ["npc","resource","signal","marker"] or row.remaining_units<0:return fail("Auxiliary observation identity/location/time invalid")
		for field: String in ["pos_x","pos_y","pos_z"]:
			if not is_finite(row.get(field)):return fail("Auxiliary observation nonfinite position")
	for table: String in ["fleet_receipt_state","auxiliary_intel_state"]:
		if state.rows(table).size()>int(balance.history_limit):return fail("Owned history exceeds bounded retention")
	for row: RefCounted in state.rows("fleet_receipt_state"):
		if row.generation<1 or row.paid_credit<0 or row.event_tick<0 or row.event_tick>tick or row.event_kind not in ["deploy","return","loss"]:return fail("Owned receipt invalid")
	return true
