class_name XJResourceStatus
extends RefCounted
## Read-only mineral intelligence from the world's frozen definitions and typed snapshot.
const T = preload("res://contracts/contract_types.gd")

static func inspect(state: XJRuntimeState, catalog: XJCatalog, node_id: String) -> Dictionary:
	var info := {"node_id": node_id, "item_id": "", "item_name": "", "remaining_units": 0,
		"capacity_units": 0, "respawn_remaining_s": 0.0, "respawn_interval_s": 0.0,
		"depleted": false, "available": false, "temporary": false, "reserved_units": 0, "grade_name": "", "grade_level": 1, "yield_multiplier_bp": 10000}
	if state == null or catalog == null: return info
	var definition := catalog.one("resource_node_defs", "node_id", node_id)
	var resource: RefCounted = state.find("resource_state", "node_id", node_id)
	if definition.is_empty() or resource == null: return info
	var item := catalog.one("item_defs", "item_id", definition.item_id)
	info.item_id = definition.item_id
	info.item_name = str(item.get("display_name", definition.item_id))
	info.remaining_units = resource.remaining_units
	info.capacity_units = int(definition.capacity_units)
	info.respawn_remaining_s = resource.respawn_remaining_s
	info.respawn_interval_s = float(definition.respawn_s)
	if catalog.table_names.has("exploration_resource_defs"):
		var managed: Dictionary = catalog.one("exploration_resource_defs", "node_id", node_id)
		if not managed.is_empty():
			info.temporary = true; info.respawn_interval_s = 0.0
			var event: RefCounted = state.find("exploration_instance_state", "event_id", managed.event_id)
			if event != null: info.capacity_units = int(catalog.one("exploration_variant_defs", "variant_id", event.variant_id).mineral_units)
	info.depleted = resource.remaining_units <= 0
	info.available = true
	info.reserved_units = mini(resource.remaining_units, int(tutorial_reservation(state, catalog, node_id).get("outstanding_units", 0)))
	if catalog.table_names.has("resource_grade_defs"):
		var grade: Dictionary = catalog.one("resource_grade_defs", "node_id", node_id)
		info.grade_name = str(grade.get("display_name", "")); info.grade_level = int(grade.get("grade_level", 1)); info.yield_multiplier_bp = int(grade.get("yield_multiplier_bp", 10000))
	return info

static func yield_per_cycle(catalog: XJCatalog, node_id: String, ship_id: String, module_id: String, additional_multiplier: float = 1.0) -> int:
	var mining: Dictionary = catalog.one("mining_defs", "module_id", module_id)
	var ship: Dictionary = catalog.one("ship_defs", "ship_id", ship_id)
	if mining.is_empty() or ship.is_empty(): return 0
	var multiplier: float = 1.0
	if catalog.table_names.has("resource_grade_defs"):
		multiplier = float(catalog.one("resource_grade_defs", "node_id", node_id).get("yield_multiplier_bp", 10000)) / 10000.0
	return int(floor(float(mining.base_yield_units) * float(ship.mining_multiplier) * multiplier * additional_multiplier))

static func summary(info: Dictionary) -> String:
	if not info.get("available", false): return "资源状态不可用"
	if info.depleted:
		if info.get("temporary", false): return "已采空 · 本轮不再生，等待下次线索"
		return "已耗尽 · 再生 %s（世界时间）" % countdown(float(info.respawn_remaining_s))
	var text := "剩余 %d / %d 单位" % [info.remaining_units, info.capacity_units]
	if info.get("reserved_units", 0) > 0: text += " · 教学预留 %d" % info.reserved_units
	if not str(info.get("grade_name", "")).is_empty(): text += " · " + str(info.grade_name)
	return text

static func countdown(seconds: float) -> String:
	var total := int(ceil(maxf(0.0, seconds)))
	var minutes := floori(float(total) / 60.0)
	if total >= 3600: return "%02d:%02d:%02d" % [floori(float(total) / 3600.0), minutes % 60, total % 60]
	return "%02d:%02d" % [minutes, total % 60]

static func tutorial_reservation(state: XJRuntimeState, catalog: XJCatalog, node_id: String) -> Dictionary:
	# Only finite, non-tradable tutorial samples qualify. Ordinary contracts never restock.
	for definition: Dictionary in catalog.rows("mission_defs"):
		if definition.mission_kind != "tutorial" or definition.repeatable: continue
		var mission: RefCounted = null
		var completed := false
		for candidate: RefCounted in state.rows("mission_state"):
			if candidate.mission_def_id != definition.mission_id: continue
			if candidate.reward_claimed: completed = true
			if candidate.status in ["active", "ready"]: mission = candidate
		if completed: continue
		for objective: Dictionary in catalog.rows("mission_objective_defs"):
			if objective.mission_id != definition.mission_id or objective.objective_kind != "collect" or objective.target_node_id != node_id: continue
			for service: Dictionary in catalog.rows("loan_service_defs"):
				if service.required_mission_id != definition.mission_id or service.gathered_policy_id != "mission_bound": continue
				var required := 0
				for delivery: Dictionary in catalog.rows("mission_objective_defs"):
					if delivery.mission_id == definition.mission_id and delivery.objective_kind == "deliver" and delivery.target_item_id == objective.target_item_id:
						required += int(delivery.required_count)
				if required <= 0: continue
				var held := 0
				for stack: RefCounted in state.rows("inventory_stack_state"):
					if mission == null or stack.policy_id != "mission_bound" or stack.bound_mission_instance_id != mission.mission_instance_id or stack.item_def_id != objective.target_item_id: continue
					var container: RefCounted = state.find("container_state", "container_id", stack.container_id)
					if container == null or container.owner_player_id != state.player().player_id or container.kind == T.ContainerKind.WRECK: continue
					if container.has_ship_instance_id:
						var ship: RefCounted = state.find("ship_state", "ship_instance_id", container.ship_instance_id)
						if ship == null or ship.status in [T.ShipStatus.DESTROYED, T.ShipStatus.RETURNED]: continue
					held += stack.quantity
				# Keep the finite reserve protected even between abandoned attempts. No source ledger
				# is needed because it cannot turn into tradable ore before the one-time tutorial settles.
				return {"mission_instance_id": mission.mission_instance_id if mission != null else "", "loan_service_id": service.loan_service_id,
					"item_id": objective.target_item_id, "outstanding_units": maxi(0, required - held)}
	return {}
