class_name XJInteractionContext
extends RefCounted
## Read-only interaction preview. Business commands revalidate before mutation.
## All gameplay limits come from the active world's frozen SQLite catalog.
const T = preload("res://contracts/contract_types.gd")

static func choose(sector: XJSector, state: XJRuntimeState, catalog: XJCatalog, gameplay: RefCounted, selected_id: String = "") -> Dictionary:
	var selected := inspect(sector, state, catalog, gameplay, selected_id)
	if selected.ready: return selected
	var nearest_ready: Dictionary = {}
	var nearest_blocked: Dictionary = {}
	var nearest_any: Dictionary = {}
	if not is_instance_valid(sector): return selected
	for key: String in sector.targets:
		var context := inspect(sector, state, catalog, gameplay, key)
		if context.target_id.is_empty(): continue
		if _nearer(context, nearest_any): nearest_any = context
		if not context.in_range: continue
		if context.ready and _nearer(context, nearest_ready): nearest_ready = context
		elif not context.ready and _nearer(context, nearest_blocked): nearest_blocked = context
	if not nearest_ready.is_empty(): return nearest_ready
	if not nearest_blocked.is_empty(): return nearest_blocked
	if not selected.target_id.is_empty(): return selected
	return nearest_any if not nearest_any.is_empty() else selected

static func inspect(sector: XJSector, state: XJRuntimeState, catalog: XJCatalog, gameplay: RefCounted, target_id: String) -> Dictionary:
	var result := {"target_id": "", "title": "", "kind": "", "action": "", "ready": false,
		"reason": "附近没有可交互目标", "distance_m": 0.0, "range_m": 0.0, "in_range": false,
		"speed_mps": 0.0, "max_speed_mps": -1.0, "cooldown_s": 0.0}
	if state == null or catalog == null or gameplay == null or not is_instance_valid(sector) or not is_instance_valid(sector.flight): return result
	if state.ship() == null: return result
	if not sector.targets.has(target_id): return result
	var target: Dictionary = sector.targets[target_id]
	if target.get("navigation_only", false) or target.get("kind", "") not in ["station", "gate", "wreck", "signal", "resource"]: return result
	var candidate_node: Variant = target.get("node")
	if not is_instance_valid(candidate_node) or not candidate_node is Node3D: return result
	var node: Node3D = candidate_node as Node3D
	if not node.is_inside_tree(): return result
	result.target_id = target_id; result.title = str(target.get("title", target_id)); result.kind = str(target.kind)
	result.distance_m = sector.flight.global_position.distance_to(node.global_position)
	result.speed_mps = sector.flight.velocity.length()
	match result.kind:
		"station":
			result.action = "dock"; result.range_m = float(catalog.rule("dock_radius_m")); result.max_speed_mps = float(catalog.rule("dock_max_speed_mps"))
		"gate":
			result.action = "travel"; result.range_m = float(catalog.rule("gate_entry_radius_m")); result.max_speed_mps = float(catalog.rule("gate_max_entry_speed_mps"))
			var cooldown: RefCounted = state.find("ship_gate_cooldown_state", "ship_instance_id", state.ship().ship_instance_id)
			if cooldown != null: result.cooldown_s = cooldown.remaining_s
		"wreck": result.action = "pickup_wreck"; result.range_m = float(catalog.rule("wreck_pickup_radius_m"))
		"signal":
			result.action = "start_scan"; result.range_m = float(catalog.rule("basic_scan_range_m"))
			for equipment: RefCounted in gameplay.call("equipped", state.ship()):
				if equipment.enabled and equipment.module_def_id.begins_with("module_scanner_"):
					result.range_m = float(catalog.one("module_defs", "module_id", equipment.module_def_id).range_m)
					result.cooldown_s = equipment.cooldown_remaining_s
					break
		"resource":
			var definition := catalog.one("resource_node_defs", "node_id", target_id)
			if definition.is_empty(): return _deny(result, "资源定义不可用")
			var item := catalog.one("item_defs", "item_id", definition.item_id)
			result.action = "start_mining" if item.get("item_type", "") == "ore" else "recover_resource"
			if result.action == "recover_resource":
				result.range_m = float(catalog.one("anchor_defs", "anchor_id", str(target.anchor_id)).interaction_radius_m)
			else:
				for equipment: RefCounted in gameplay.call("equipped", state.ship()):
					if not equipment.enabled: continue
					for compatibility: Dictionary in catalog.rows("mining_compatibility"):
						if compatibility.module_id == equipment.module_def_id and compatibility.item_id == definition.item_id:
							result.range_m = maxf(result.range_m, float(catalog.one("module_defs", "module_id", equipment.module_def_id).range_m))
	result.in_range = result.distance_m <= result.range_m
	if state.ship().status != T.ShipStatus.FLYING: return _deny(result, "出港后才能交互" if state.ship().status == T.ShipStatus.DOCKED else "当前舰船不能交互")
	if result.kind == "resource" and result.range_m <= 0.0: return _deny(result, "需要启用兼容的采集模块")
	if not result.in_range: return _deny(result, "靠近目标 · 距离 %.0f / %.0f m" % [result.distance_m, result.range_m])
	if result.max_speed_mps >= 0.0 and result.speed_mps > result.max_speed_mps: return _deny(result, "按 X 制动 · 速度 %.1f / %.1f m/s" % [result.speed_mps, result.max_speed_mps])
	match result.kind:
		"station":
			var station := catalog.one("station_defs", "station_id", target_id)
			if station.is_empty() or station.sector_id != state.current_sector(): return _deny(result, "站点不在当前星区")
			if gameplay.call("in_combat"): return _deny(result, "交战中不能停靠，先脱离敌舰")
		"gate":
			var gate_reason := _gate_reason(sector, state, catalog, gameplay, target_id)
			if not gate_reason.is_empty(): return _deny(result, gate_reason)
		"wreck":
			var container: RefCounted = state.find("container_state", "container_id", target_id)
			if container == null or container.kind != T.ContainerKind.WRECK or container.owner_player_id != state.player().player_id or container.sector_id != state.current_sector(): return _deny(result, "此残骸不可打捞")
			var inventory: RefCounted = gameplay.get("inventory")
			var destination: String = inventory.call("hold", state.ship(), T.ContainerKind.CARGO)
			var has_cargo := false
			var has_room := false
			for row: RefCounted in state.rows("inventory_stack_state") + state.rows("item_instance_state"):
				if row.container_id != target_id: continue
				has_cargo = true
				if int(inventory.call("room", destination, row.item_def_id, 1)) > 0: has_room = true
			if not has_cargo: return _deny(result, "残骸为空")
			if not has_room: return _deny(result, "货舱或载荷已满")
		"signal":
			var signal_def := catalog.one("signal_defs", "signal_id", target_id)
			if signal_def.is_empty() or state.find("unlock_state", "unlock_id", signal_def.required_unlock_id) == null: return _deny(result, "扫描权限尚未解锁")
			if signal_def.occurrence_mode == "mission_scoped" and gameplay.get("missions").call("active_for_target", "scan_signal", target_id) == null: return _deny(result, "需要先接取对应测绘任务")
			if signal_def.occurrence_mode == "fixed" and state.find("discovery_state", "signal_id", target_id) != null: return _deny(result, "此信号已经完成测绘")
			if not _line_of_sight(sector, target_id, node.global_position): return _deny(result, "目标被遮挡")
		"resource":
			var location := catalog.one("resource_node_locations", "node_id", target_id)
			if location.is_empty() or state.find("unlock_state", "unlock_id", location.required_unlock_id) == null: return _deny(result, "资源权限尚未解锁")
			var resource: RefCounted = state.find("resource_node_state", "node_id", target_id)
			if resource == null or resource.remaining_units <= 0: return _deny(result, "资源已耗尽，等待补生")
			var definition := catalog.one("resource_node_defs", "node_id", target_id)
			var limit: Dictionary = gameplay.get("work").call("_output_limit", str(definition.item_id), 1)
			if int(limit.count) <= 0: return _deny(result, "货舱、载荷或借船采集额度不足")
			if not _line_of_sight(sector, target_id, node.global_position): return _deny(result, "目标被遮挡")
	result.ready = true; result.reason = ""
	return result

static func _gate_reason(sector: XJSector, state: XJRuntimeState, catalog: XJCatalog, gameplay: RefCounted, target_id: String) -> String:
	var endpoint := catalog.one("gate_endpoint_defs", "endpoint_id", target_id)
	if endpoint.is_empty() or endpoint.origin_sector_id != state.current_sector(): return "虫洞入口不在当前星区"
	if state.find("unlock_state", "unlock_id", endpoint.required_unlock_id) == null: return "航门权限未解锁，完成对应任务"
	var connection := catalog.one("effective_connection_defs", "connection_id", endpoint.connection_id)
	var gate: RefCounted = state.find("gate_state", "connection_id", endpoint.connection_id)
	if connection.is_empty() or gate == null or not gate.enabled: return "航门处于关闭状态"
	var cooldown: RefCounted = state.find("ship_gate_cooldown_state", "ship_instance_id", state.ship().ship_instance_id)
	if cooldown != null and cooldown.remaining_s > 0.0: return "舰船航门冷却 · %.1f s" % cooldown.remaining_s
	var mass: float = float(gameplay.call("metrics", state.ship()).total_mass_kg)
	if mass > float(connection.max_gross_mass_kg) or (gate.has_remaining_mass_budget_kg and mass > gate.remaining_mass_budget_kg): return "总质量超过航门额度，卸货或换用较小舰船"
	if state.ship().energy < float(connection.energy_cost_eu) or state.player().credit < int(connection.fee_credit): return "航门费用或电容不足"
	if not bool(gameplay.call("save_eligible")) or (is_instance_valid(sector.projectiles) and not sector.projectiles.active.is_empty()): return "先脱离交战、停止采集扫描并等待设备周期或弹丸结束"
	# Travel's final validator rejects hostile phases before acquiring a barrier.
	for npc: RefCounted in state.rows("npc_state"):
		if npc.alive and npc.behavior_phase in [T.NpcPhase.ACQUIRE, T.NpcPhase.PURSUE, T.NpcPhase.ATTACK, T.NpcPhase.DISENGAGE]: return "仍处于交战，先脱离敌舰"
	return ""

static func _line_of_sight(sector: XJSector, target_id: String, point: Vector3) -> bool:
	return sector.line_of_sight(sector.flight.global_position, point, sector.flight.get_rid(), target_id)

static func _deny(result: Dictionary, reason: String) -> Dictionary:
	result.reason = reason
	return result

static func _nearer(candidate: Dictionary, previous: Dictionary) -> bool:
	return previous.is_empty() or candidate.distance_m < previous.distance_m or (candidate.distance_m == previous.distance_m and candidate.target_id < previous.target_id)
