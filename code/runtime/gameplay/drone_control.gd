extends RefCounted
signal warning_changed(message: String)
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var live: Dictionary = {} # Typed transient actors. Stable saves require all of them recovered.
func _init(game: RefCounted) -> void: g = game
func supported() -> bool: return g != null and g.catalog.table_names.has("drone_management_defs")
func bay(item_id: String) -> D.DroneBayStateDto: return g.state.find("drone_bay_state", "item_instance_id", item_id)
static func initial_bays(catalog: XJCatalog, state: XJRuntimeState) -> Array[D.DroneBayStateDto]:
	var result: Array[D.DroneBayStateDto] = []
	if not catalog.table_names.has("drone_management_defs"): return result
	for item: RefCounted in state.rows("item_instance_state"):
		var spec: Dictionary = catalog.one("drone_defs", "module_id", item.item_def_id)
		if spec.is_empty(): continue
		var row: D.DroneBayStateDto = D.DroneBayStateDto.new(); row.item_instance_id = item.item_instance_id; row.stock_units = int(spec.drone_count); result.append(row)
	return result
func sync() -> void:
	if not supported(): return
	for row: RefCounted in initial_bays(g.catalog, g.state):
		if bay(row.item_instance_id) == null: g.state.add("drone_bay_state", row)
func module_live(owner_id: String, item_id: String) -> bool:
	if owner_id == g.state.ship().ship_instance_id:
		if g.state.ship().status != T.ShipStatus.FLYING: return false
		var equipment: RefCounted = g.state.find("equipment_state", "item_instance_id", item_id)
		var item: RefCounted = g.state.find("item_instance_state", "item_instance_id", item_id)
		return equipment != null and equipment.enabled and item != null and item.durability > 0.0 and g.equipped(g.state.ship()).has(equipment)
	var npc: RefCounted = g.state.find("npc_state", "npc_instance_id", owner_id)
	if g.owned_fleet.friendly(owner_id):
		var hull: RefCounted=g.owned_fleet.ship(owner_id);var equipment: RefCounted=g.state.find("equipment_state","item_instance_id",item_id);var item: RefCounted=g.state.find("item_instance_state","item_instance_id",item_id)
		return hull!=null and equipment!=null and item!=null and equipment.enabled and item.durability>0 and g.equipped(hull).has(equipment)
	var tactic: RefCounted = g.tactics.instance(owner_id)
	return npc != null and npc.alive and tactic != null and g.tactics.definition(owner_id).tactic_kind == "carrier" and item_id == "npc_bay_" + owner_id
func stock(owner_id: String, item_id: String) -> int:
	if not supported(): return 0
	if owner_id == g.state.ship().ship_instance_id or g.owned_fleet.friendly(owner_id):
		var row: RefCounted = bay(item_id); return row.stock_units if row != null else 0
	var tactic: RefCounted = g.tactics.instance(owner_id)
	return tactic.drone_stock if tactic != null else 0
func deployed(item_id: String) -> int:
	var count: int = 0
	for row: RefCounted in live.values():
		if row.module_instance_id == item_id: count += 1
	return count
func register(owner_id: String, item_id: String, module_id: String, target_id: String) -> D.DroneRuntimeDto:
	if not module_live(owner_id, item_id) or deployed(item_id) >= mini(stock(owner_id, item_id), int(g.definition("drone_defs", "module_id", module_id).get("drone_count", 0))): return null
	var spec: Dictionary = g.definition("drone_management_defs", "module_id", module_id)
	if spec.is_empty(): return null
	var row: D.DroneRuntimeDto = D.DroneRuntimeDto.new()
	row.drone_id = g.id("drone"); row.owner_id = owner_id; row.module_instance_id = item_id; row.module_def_id = module_id; row.target_id = target_id
	row.health_max = float(spec.hull_hp); row.health = row.health_max
	var record: RefCounted = bay(item_id)
	row.command_kind = record.command_kind if record != null else "attack"
	row.returning = row.command_kind == "recall"
	if record != null: record.deployed_units += 1
	else: g.tactics.instance(owner_id).deployed_drones += 1
	live[row.drone_id] = row; return row
func owner(drone_id: String) -> String:
	return str(live[drone_id].owner_id) if live.has(drone_id) else ""
func retire(drone_id: String, lost: bool) -> void:
	if not live.has(drone_id): return
	var row: RefCounted = live[drone_id]; live.erase(drone_id)
	var record: RefCounted = bay(row.module_instance_id)
	var tactic: RefCounted = g.tactics.instance(row.owner_id)
	if record != null: record.deployed_units = maxi(0, record.deployed_units - 1)
	elif tactic != null: tactic.deployed_drones = maxi(0, tactic.deployed_drones - 1)
	if not lost: return
	if record != null:
		g.telemetry.stat("drone_losses")
		record.stock_units = maxi(0, record.stock_units - 1); record.lost_units += 1; record.revision += 1
	else:
		if tactic != null: tactic.drone_stock = maxi(0, tactic.drone_stock - 1); tactic.lost_drones += 1
	warning_changed.emit("无人机损失；机库余量已减少，可在空间站补充。" if row.owner_id == g.state.ship().ship_instance_id else "敌方无人机已被摧毁，母舰储备减少。")
	g.request_autosave()
func damage(drone_id: String, attacker_id: String, raw: Vector3) -> bool:
	if not live.has(drone_id) or not raw.is_finite() or not g.civilizations.hostile_to(attacker_id, drone_id): return false
	var row: RefCounted = live[drone_id]
	row.health = maxf(0.0, row.health - maxf(0.0, raw.x) - maxf(0.0, raw.y) - maxf(0.0, raw.z))
	if row.health <= 0.0: retire(drone_id, true)
	return true
func command_reason(kind: String, target_id: String) -> String:
	if not supported() or g.state.ship().status != T.ShipStatus.FLYING or kind not in ["attack","follow","recall"]: return "当前无法下达无人机指令"
	var usable: bool = false
	for equipment: RefCounted in g.equipped(g.state.ship()):
		var row: RefCounted = bay(equipment.item_instance_id)
		if row != null and (kind == "recall" or (equipment.enabled and row.stock_units > 0)): usable = true
	if not usable: return "请启用有存量的无人机舱，缺损可在空间站补充"
	if kind == "attack":
		var npc: RefCounted = g.state.find("npc_state", "npc_instance_id", target_id)
		if (npc == null or not npc.alive or not g.same_entity_site("ship", g.state.ship(), "npc", npc)) and not live.has(target_id): return "选择同一空间中的存活敌舰或敌方无人机"
		if not g.civilizations.hostile_to(g.state.ship().ship_instance_id, target_id): return "不能攻击友方目标"
		var range_m: float = 0.0
		for equipment: RefCounted in g.equipped(g.state.ship()):
			if equipment.enabled and bay(equipment.item_instance_id) != null: range_m = maxf(range_m, float(g.definition("module_defs", "module_id", equipment.module_def_id).range_m))
		var target: RefCounted = live.get(target_id, npc)
		if target == null or g.position(g.state.ship()).distance_to(g.position(target)) > range_m: return "目标超出无人机通信范围"
	return ""
func command(kind: String, target_id: String) -> bool:
	var reason: String = command_reason(kind, target_id)
	if not reason.is_empty(): return g.fail(reason)
	var found: bool = false
	for equipment: RefCounted in g.equipped(g.state.ship()):
		var row: RefCounted = bay(equipment.item_instance_id)
		if row == null: continue
		row.command_kind = kind; found = true
	for row: RefCounted in live.values():
		if row.owner_id != g.state.ship().ship_instance_id: continue
		row.command_kind = kind
		if kind == "attack": row.target_id = target_id
		if not row.fired: row.returning = kind == "recall"
	return true if found else g.fail("当前舰船没有装载无人机舱")
func replenish_reason(item_id: String, quantity: int, revision: String) -> String:
	var row: RefCounted = bay(item_id)
	var item: RefCounted = g.state.find("item_instance_state", "item_instance_id", item_id)
	if row == null or item == null: return "无人机舱不存在"
	if revision != str(row.revision): return "机库库存已变化，请刷新后再补充"
	if g.state.ship().status != T.ShipStatus.DOCKED or not g.inventory.accessible(item.container_id) or not g.allowed_service("fitting"): return "需在可配装的当前空间站补充"
	if item.policy_id != "normal_owned": return "仅普通自有无人机舱可付费补充"
	var maximum: int = int(g.definition("drone_defs", "module_id", item.item_def_id).drone_count)
	if quantity <= 0 or quantity > maximum - row.stock_units: return "补充数量超出实际缺口"
	var spec: Dictionary = g.definition("drone_management_defs", "module_id", item.item_def_id)
	if g.state.player().credit < quantity * int(spec.credit_per_unit): return "信用点不足"
	if g.inventory.count(g.inventory.warehouse(g.station()), spec.material_id, true) < quantity * int(spec.material_per_unit): return "当前站仓库的普通自有结构料不足"
	return ""
func replenish(item_id: String, quantity: int, revision: String) -> bool:
	var reason: String = replenish_reason(item_id, quantity, revision)
	if not reason.is_empty(): return g.fail(reason)
	var row: RefCounted = bay(item_id)
	var item: RefCounted = g.state.find("item_instance_state", "item_instance_id", item_id)
	var spec: Dictionary = g.definition("drone_management_defs", "module_id", item.item_def_id)
	var materials: int = quantity * int(spec.material_per_unit); var credit: int = quantity * int(spec.credit_per_unit)
	if not g.inventory.consume(g.inventory.warehouse(g.station()), spec.material_id, materials, true): return g.fail("补充材料扣除失败")
	g.state.player().credit -= credit; row.stock_units += quantity; row.replenished_units += quantity; row.paid_credit_total += credit; row.material_units_total += materials; row.revision += 1
	return true
func remove_item(item_id: String) -> void:
	var row: RefCounted = bay(item_id)
	if row != null: g.state.remove("drone_bay_state", row)
