extends RefCounted
## Data-only party calculations used by navigation, quotes and transactions.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
const Space=preload("res://runtime/space_coordinates.gd")
const Owned=preload("res://runtime/data/fleet_validation.gd")
const POSE: Array[String]=["pos_x","pos_y","pos_z","quat_x","quat_y","quat_z","quat_w","vel_x","vel_y","vel_z"]
static func owned(state: XJRuntimeState,catalog: XJCatalog) -> Array:
	return state.rows("fleet_deployment_state").filter(func(row: RefCounted):return row.phase=="deployed") if catalog.table_names.has("fleet_hull_defs") else []
static func offset(catalog: XJCatalog,index: int) -> Vector3:
	var spacing: float=float(catalog.rows("fleet_balance_defs")[0].formation_m)
	var side: float=-1.0 if index%2==0 else 1.0
	# Both wings trail the flagship, leaving their support corridor behind it.
	return Vector3(side*spacing,0.0,spacing)
static func hull_mass(state: XJRuntimeState,catalog: XJCatalog,ship: RefCounted) -> float:
	var mass: float=float(catalog.one("ship_defs","ship_id",ship.ship_def_id).dry_mass_kg)
	var containers: Array[String]=[]
	for row: RefCounted in state.rows("container_state"):
		if row.has_ship_instance_id and row.ship_instance_id==ship.ship_instance_id:containers.append(row.container_id)
	for row: RefCounted in state.rows("item_instance_state"):
		if containers.has(row.container_id):mass+=float(catalog.one("item_defs","item_id",row.item_def_id).unit_mass_kg)
	for row: RefCounted in state.rows("inventory_stack_state"):
		if containers.has(row.container_id):mass+=float(catalog.one("item_defs","item_id",row.item_def_id).unit_mass_kg)*row.quantity
	for row: RefCounted in state.rows("salvage_package_state"):
		if row.status=="sealed" and row.has_host_container_id and containers.has(row.host_container_id):mass+=float(catalog.one("salvage_package_defs","package_def_id",row.package_def_id).mass_kg)
	for table: String in ["operation_state","consignment_state","blockade_state"]:
		if not catalog.table_names.has(table.replace("_state","_defs")):continue
		for row: RefCounted in state.rows(table):
			if not row.has_payload_ship_id or row.payload_ship_id!=ship.ship_instance_id:continue
			if table=="operation_state":mass+=row.cargo_units*float(catalog.one("operation_defs","operation_id",row.operation_id).cargo_mass_kg)
			elif table=="consignment_state":mass+=row.cargo_units*float(catalog.one("consignment_defs","contract_id",row.contract_id).unit_mass_kg)
			else:mass+=row.cargo_units*float(catalog.one("blockade_defs","blockade_id",row.blockade_id).cargo_mass_kg)
	return mass
static func owned_mass(state: XJRuntimeState,catalog: XJCatalog) -> float:
	var mass: float=0.0
	for row: RefCounted in owned(state,catalog):mass+=hull_mass(state,catalog,state.find("ship_state","ship_instance_id",row.ship_instance_id))
	return mass
static func largest_owned(state: XJRuntimeState,catalog: XJCatalog) -> float:
	var mass: float=0.0
	for row: RefCounted in owned(state,catalog):mass=maxf(mass,hull_mass(state,catalog,state.find("ship_state","ship_instance_id",row.ship_instance_id)))
	return mass
static func travel_reason(state: XJRuntimeState,catalog: XJCatalog) -> String:
	if not catalog.table_names.has("fleet_hull_defs"):return ""
	var balance: Dictionary=catalog.rows("fleet_balance_defs")[0]
	for row: RefCounted in state.rows("fleet_deployment_state"):
		if row.phase=="retreating":return "等待自有僚舰实际脱离后再跃迁"
		if row.phase!="deployed":continue
		if row.order_kind!="regroup":return "先命令全部自有僚舰集结"
		if not Owned.actor_binding(state,catalog,row.ship_instance_id) or not Owned.pilot_ready(state,catalog,row.ship_instance_id):return "自有僚舰或操舰员状态变化，等待编队稳定"
		var npc: RefCounted=state.find("npc_state","npc_instance_id",row.npc_instance_id);var ship: RefCounted=state.ship()
		if npc.sector_id!=ship.sector_id or row.site_id!=Space.current_site(state) or Vector3(npc.pos_x,npc.pos_y,npc.pos_z).distance_to(Vector3(ship.pos_x,ship.pos_y,ship.pos_z))>float(balance.warp_ready_m):return "自有僚舰尚未实际进入跃迁编队距离"
	return ""
static func departure_owned(state: XJRuntimeState,catalog: XJCatalog) -> Array[Dictionary]:
	var poses: Array[Dictionary]=[]
	for row: RefCounted in owned(state,catalog):
		var npc: RefCounted=state.find("npc_state","npc_instance_id",row.npc_instance_id)
		var pose: Dictionary={"world":state.world_id,"ship":row.ship_instance_id,"generation":row.generation,"sector":row.sector_id,"site":row.site_id,"goal":Vector3(row.goal_x,row.goal_y,row.goal_z)}
		for field: String in POSE:pose[field]=npc.get(field)
		poses.append(pose)
	return poses
static func restore_owned(state: XJRuntimeState,catalog: XJCatalog,poses: Array[Dictionary]) -> void:
	if not catalog.table_names.has("fleet_hull_defs"):return
	for pose: Dictionary in poses:
		var row: RefCounted=state.find("fleet_deployment_state","ship_instance_id",pose.ship)
		if row==null or row.phase!="deployed" or pose.world!=state.world_id or pose.generation!=row.generation:continue
		var ship: RefCounted=state.find("ship_state","ship_instance_id",row.ship_instance_id)
		var npc: RefCounted=state.find("npc_state","npc_instance_id",row.npc_instance_id)
		if ship==null or npc==null:continue
		for field: String in POSE:ship.set(field,pose[field]);npc.set(field,pose[field])
		row.sector_id=pose.sector;row.site_id=pose.site;row.goal_x=pose.goal.x;row.goal_y=pose.goal.y;row.goal_z=pose.goal.z;row.order_kind="regroup";row.has_focus_target_id=false;row.focus_target_id="";row.order_revision+=1
		ship.sector_id=row.sector_id;npc.sector_id=row.sector_id;npc.behavior_phase=T.NpcPhase.PATROL
		Space.assign(state,"ship",ship.ship_instance_id,row.site_id);Space.assign(state,"npc",npc.npc_instance_id,row.site_id)
		for container: RefCounted in state.rows("container_state"):
			if container.has_ship_instance_id and container.ship_instance_id==ship.ship_instance_id:container.sector_id=ship.sector_id
static func departure_valid(state: XJRuntimeState,catalog: XJCatalog,poses: Array[Dictionary]) -> bool:
	if owned(state,catalog).size()!=poses.size():return false
	for pose: Dictionary in poses:
		var row: RefCounted=state.find("fleet_deployment_state","ship_instance_id",pose.ship)
		if pose.world!=state.world_id or row==null or row.generation!=pose.generation or row.phase!="deployed" or row.order_kind!="regroup" or not Owned.actor_binding(state,catalog,pose.ship) or not Owned.pilot_ready(state,catalog,pose.ship):return false
	return true
static func gate_reason(state: XJRuntimeState,catalog: XJCatalog,connection: Dictionary) -> String:
	for row: RefCounted in owned(state,catalog):
		var ship: RefCounted=state.find("ship_state","ship_instance_id",row.ship_instance_id)
		if hull_mass(state,catalog,ship)>float(connection.max_gross_mass_kg):return "自有僚舰超过航门单舰质量上限"
		if ship.energy<float(connection.energy_cost_eu):return "自有僚舰电容不足，等待恢复后过门"
		var cooldown: RefCounted=state.find("ship_gate_cooldown_state","ship_instance_id",ship.ship_instance_id)
		if cooldown!=null and cooldown.remaining_s>0:return "自有僚舰航门冷却尚未结束"
	return ""
static func charge_owned_gate(state: XJRuntimeState,catalog: XJCatalog,connection: Dictionary) -> void:
	for row: RefCounted in owned(state,catalog):
		var ship: RefCounted=state.find("ship_state","ship_instance_id",row.ship_instance_id);ship.energy-=float(connection.energy_cost_eu)
		var cooldown: RefCounted=state.find("ship_gate_cooldown_state","ship_instance_id",ship.ship_instance_id)
		if cooldown==null:cooldown=D.ShipGateCooldownStateDto.new();cooldown.ship_instance_id=ship.ship_instance_id;state.add("ship_gate_cooldown_state",cooldown)
		cooldown.remaining_s=float(connection.cooldown_s)
static func arrive_owned(state: XJRuntimeState,catalog: XJCatalog) -> void:
	var leader: RefCounted=state.ship();var orientation: Quaternion=Quaternion(leader.quat_x,leader.quat_y,leader.quat_z,leader.quat_w)
	var index: int=0
	for row: RefCounted in owned(state,catalog):
		var ship: RefCounted=state.find("ship_state","ship_instance_id",row.ship_instance_id);var npc: RefCounted=state.find("npc_state","npc_instance_id",row.npc_instance_id)
		var position: Vector3=Vector3(leader.pos_x,leader.pos_y,leader.pos_z)+Basis(orientation)*offset(catalog,index);index+=1
		row.sector_id=leader.sector_id;row.site_id=Space.current_site(state);row.order_kind="regroup";row.has_focus_target_id=false;row.focus_target_id="";row.order_revision+=1;row.goal_x=position.x;row.goal_y=position.y;row.goal_z=position.z
		ship.sector_id=leader.sector_id;ship.pos_x=position.x;ship.pos_y=position.y;ship.pos_z=position.z;ship.vel_x=0;ship.vel_y=0;ship.vel_z=0;ship.quat_x=orientation.x;ship.quat_y=orientation.y;ship.quat_z=orientation.z;ship.quat_w=orientation.w
		npc.sector_id=ship.sector_id;npc.behavior_phase=T.NpcPhase.PATROL
		for field: String in POSE:npc.set(field,ship.get(field))
		npc.shield=ship.shield;npc.armor=ship.armor;npc.hull=ship.hull
		Space.assign(state,"ship",ship.ship_instance_id,row.site_id);Space.assign(state,"npc",npc.npc_instance_id,row.site_id)
		for container: RefCounted in state.rows("container_state"):
			if container.has_ship_instance_id and container.ship_instance_id==ship.ship_instance_id:container.sector_id=ship.sector_id
