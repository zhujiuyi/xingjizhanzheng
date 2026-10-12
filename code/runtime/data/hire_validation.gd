extends RefCounted
const T=preload("res://contracts/contract_types.gd")
const Party=preload("res://runtime/data/party_rules.gd")
var last_error: String=""
func _fail(message: String) -> bool:last_error=message;return false

static func actor_binding(state: XJRuntimeState,catalog: XJCatalog,id: String) -> bool:
	if not catalog.table_names.has("hire_profile_defs"):return false
	var npc: RefCounted=state.find("npc_state","npc_instance_id",id)
	if npc==null or not npc.alive or npc.generation!=1:return false
	for row: RefCounted in state.rows("hire_contract_state"):
		if not row.has_npc_instance_id or row.npc_instance_id!=id or row.phase not in ["deployed","retreating"]:continue
		var spec: Dictionary=catalog.one("hire_profile_defs","profile_id",row.profile_id)
		var at: RefCounted=state.find("spatial_state","entity_id",id)
		return not spec.is_empty() and row.player_id==state.player().player_id and spec.spawn_id==npc.spawn_id and row.sector_id==npc.sector_id and at!=null and at.entity_kind=="npc" and at.site_id==row.site_id
	return false

static func friendly(state: XJRuntimeState,catalog: XJCatalog,id: String) -> bool:
	if actor_binding(state,catalog,id):return true
	var escort: RefCounted=state.find("exploration_actor_state","npc_instance_id",id)
	if escort!=null and escort.actor_role=="escort":return true
	var fleet: RefCounted=state.find("war_fleet_state","npc_instance_id",id)
	if fleet!=null and fleet.side=="ally":return true
	return catalog.table_names.has("frontier_campaign_defs") and preload("res://runtime/data/frontier_validation.gd").new().friendly(state,id)

static func travel_reason(state: XJRuntimeState,catalog: XJCatalog) -> String:
	var owned_reason: String=Party.travel_reason(state,catalog)
	if not owned_reason.is_empty():return owned_reason
	if not catalog.table_names.has("hire_profile_defs"):return ""
	for row: RefCounted in state.rows("hire_contract_state"):
		if row.phase=="retreating":return "等待僚舰完成脱离后再跃迁"
		if row.phase!="deployed":continue
		if row.order_kind!="regroup":return "先命令僚舰集结，再进行编队跃迁"
		if not row.has_npc_instance_id or not actor_binding(state,catalog,row.npc_instance_id):return "僚舰状态变化，等待编队稳定"
		var npc: RefCounted=state.find("npc_state","npc_instance_id",row.npc_instance_id);var ship: RefCounted=state.ship()
		var from: Vector3=Vector3(npc.pos_x,npc.pos_y,npc.pos_z);var to: Vector3=Vector3(ship.pos_x,ship.pos_y,ship.pos_z)
		if npc.sector_id!=ship.sector_id or row.site_id!=XJSpaceCoordinates.current_site(state) or from.distance_to(to)>float(catalog.rows("hire_balance_defs")[0].warp_ready_m):return "僚舰尚未进入跃迁编队距离"
	return ""
static func party_mass(state: XJRuntimeState,catalog: XJCatalog) -> float:
	var mass: float=Party.owned_mass(state,catalog)
	if not catalog.table_names.has("hire_profile_defs"):return mass
	for row: RefCounted in state.rows("hire_contract_state"):
		if row.phase!="deployed":continue
		var spec: Dictionary=catalog.one("hire_profile_defs","profile_id",row.profile_id)
		if not spec.is_empty():mass+=float(catalog.one("ship_defs","ship_id",spec.hull_id).dry_mass_kg)
	return mass
static func largest_party_mass(state: XJRuntimeState,catalog: XJCatalog) -> float:
	var mass: float=Party.largest_owned(state,catalog)
	if catalog.table_names.has("hire_profile_defs"):
		for row: RefCounted in state.rows("hire_contract_state"):
			if row.phase!="deployed":continue
			var spec: Dictionary=catalog.one("hire_profile_defs","profile_id",row.profile_id)
			if not spec.is_empty():mass=maxf(mass,float(catalog.one("ship_defs","ship_id",spec.hull_id).dry_mass_kg))
	return mass
static func party_fee(state: XJRuntimeState,catalog: XJCatalog,base: int) -> int:
	var count: int=1+Party.owned(state,catalog).size()
	if catalog.table_names.has("hire_profile_defs"):
		for row: RefCounted in state.rows("hire_contract_state"):
			if row.phase=="deployed":count+=1
	return base*count

func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("hire_profile_defs"):
		return (state.rows("hire_contract_state").is_empty() and state.rows("hire_receipt_state").is_empty()) or _fail("Hire state under legacy rules")
	var balance: Dictionary=catalog.rows("hire_balance_defs")[0];var ids: Dictionary={};var actors: Dictionary={};var active: int=0
	for row: RefCounted in state.rows("hire_contract_state"):
		var spec: Dictionary=catalog.one("hire_profile_defs","profile_id",row.profile_id)
		var site: Dictionary=catalog.one("site_defs","site_id",row.site_id)
		if ids.has(row.contract_id) or spec.is_empty() or row.player_id!=state.player().player_id or site.is_empty() or site.sector_id!=row.sector_id or catalog.one("station_defs","station_id",row.origin_station_id).is_empty():return _fail("Invalid companion identity or owner")
		ids[row.contract_id]=row
		if row.phase not in ["deployed","retreating","returning","returned","lost"] or row.order_kind not in ["advance","regroup","focus","retreat"] or row.order_revision<0:return _fail("Invalid companion phase or order")
		if row.fee_paid_credit!=int(spec.hire_fee_credit) or row.deposit_paid_credit!=int(spec.deposit_credit):return _fail("Companion costs differ from the actual frozen contract")
		if row.lease_remaining_s<0.0 or row.lease_remaining_s>float(spec.lease_s) or row.return_remaining_s<0.0 or row.return_remaining_s>float(balance.return_s) or row.retreat_remaining_s<0.0 or row.retreat_remaining_s>float(balance.retreat_charge_s):return _fail("Invalid companion timers")
		if row.support_cycles_remaining<0 or row.support_cycles_remaining>int(spec.support_cycles) or row.support_cooldown_s<0.0 or row.support_cooldown_s>float(balance.support_cycle_s) or row.condition_ratio<0.0 or row.condition_ratio>1.0:return _fail("Invalid companion supplies or condition")
		if row.created_tick<0 or row.created_tick>state.snapshot.meta.simulation_tick or row.finished_tick<0 or row.finished_tick>state.snapshot.meta.simulation_tick:return _fail("Companion time exceeds its snapshot")
		var embodied: bool=row.phase in ["deployed","retreating"]
		if row.has_npc_instance_id!=embodied:return _fail("Companion actor presence differs from lifecycle")
		if embodied:
			if actors.has(row.npc_instance_id) or not actor_binding(state,catalog,row.npc_instance_id):return _fail("Companion actor binding invalid")
			actors[row.npc_instance_id]=true
		if row.phase in ["deployed","retreating","returning"]:
			active+=1
			if row.finished_tick!=0 or row.refund_credit!=0:return _fail("Active companion has already settled")
		else:
			if row.finished_tick<row.created_tick or row.lease_remaining_s!=0.0 or row.return_remaining_s!=0.0 or row.retreat_remaining_s!=0.0 or row.support_cooldown_s!=0.0:return _fail("Terminal companion retains active work")
			if row.phase=="returned" and row.refund_credit!=int(float(row.deposit_paid_credit)*row.condition_ratio):return _fail("Companion refund exceeds actual condition")
			if row.phase=="lost" and (row.condition_ratio!=0.0 or row.refund_credit!=0):return _fail("Lost companion refunds its deposit")
		if row.phase=="deployed" and (row.order_kind=="retreat" or row.return_remaining_s!=0.0 or row.retreat_remaining_s!=0.0):return _fail("Deployed companion has retreat work")
		if row.phase=="retreating" and (row.order_kind!="retreat" or row.return_remaining_s!=0.0):return _fail("Retreat order missing")
		if row.phase=="returning" and (row.return_remaining_s<=0.0 or row.retreat_remaining_s!=0.0):return _fail("Strategic companion return has no duration")
		if row.order_kind=="focus":
			var enemy: RefCounted=state.find("npc_state","npc_instance_id",row.focus_target_id) if row.has_focus_target_id else null
			var at: RefCounted=state.find("spatial_state","entity_id",row.focus_target_id) if enemy!=null else null
			if enemy==null or not enemy.alive or enemy.sector_id!=row.sector_id or at==null or at.entity_kind!="npc" or at.site_id!=row.site_id or friendly(state,catalog,enemy.npc_instance_id):return _fail("Companion focus is not a live local enemy")
		elif row.has_focus_target_id:return _fail("Non-focus companion retains a target")
	if active>int(balance.max_companions):return _fail("Too many active companions")
	for npc: RefCounted in state.rows("npc_state"):
		if not catalog.one("hire_profile_defs","spawn_id",npc.spawn_id).is_empty() and not actors.has(npc.npc_instance_id):return _fail("Orphan companion NPC")
	var ledger: Dictionary={}
	for receipt: RefCounted in state.rows("hire_receipt_state"):
		if not ids.has(receipt.contract_id) or receipt.event_tick<0 or receipt.event_tick>state.snapshot.meta.simulation_tick:return _fail("Invalid companion receipt identity")
		var row: RefCounted=ids[receipt.contract_id];var key: String=row.contract_id+(":hire" if receipt.event_kind=="hire" else ":outcome")
		if ledger.has(key):return _fail("Repeated companion settlement")
		ledger[key]=true
		if receipt.event_kind=="hire":
			if receipt.paid_credit!=row.fee_paid_credit+row.deposit_paid_credit or receipt.refund_credit!=0 or receipt.event_tick!=row.created_tick:return _fail("Companion payment lacks entitlement")
		elif receipt.event_kind=="return":
			if row.phase!="returned" or receipt.paid_credit!=0 or receipt.refund_credit!=row.refund_credit or receipt.event_tick!=row.finished_tick:return _fail("Companion refund lacks entitlement")
		elif receipt.event_kind=="loss":
			if row.phase!="lost" or receipt.paid_credit!=0 or receipt.refund_credit!=0 or receipt.event_tick!=row.finished_tick:return _fail("Companion loss incorrectly pays")
		else:return _fail("Unknown companion receipt kind")
	for row: RefCounted in ids.values():
		if not ledger.has(row.contract_id+":hire") or ledger.has(row.contract_id+":outcome")!=(row.phase in ["returned","lost"]):return _fail("Missing companion payment or terminal receipt")
	return true
