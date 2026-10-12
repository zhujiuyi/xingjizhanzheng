extends RefCounted
## Frozen combat sites and uniquely owned recovery packages.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Rng = preload("res://runtime/rng.gd")
var g: RefCounted

func _init(gameplay: RefCounted) -> void:
	g = gameplay

func supported() -> bool:
	return g.catalog.table_names.has("encounter_defs")

func group_for_spawn(spawn_id: String) -> String:
	if not supported(): return ""
	return str(g.definition("encounter_members", "spawn_id", spawn_id).get("encounter_id", ""))

func handles(spawn_id: String) -> bool:
	return not group_for_spawn(spawn_id).is_empty()

func _members(encounter_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member in g.rows("encounter_members"):
		if member.encounter_id == encounter_id: result.append(member)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.member_index < b.member_index)
	return result

func _spawn(member: Dictionary, generation: int) -> void:
	var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", member.spawn_id)
	var definition: Dictionary = g.definition("npc_full_defs", "npc_id", spawn.npc_id)
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", spawn.anchor_id)
	var row: D.NpcStateDto = D.NpcStateDto.new()
	row.npc_instance_id = g.id("npc"); row.spawn_id = spawn.spawn_id; row.sector_id = spawn.sector_id
	row.generation = generation; row.alive = true
	row.shield = definition.shield_max; row.armor = definition.armor_max; row.hull = definition.hull_max
	row.pos_x = anchor.x_m; row.pos_y = anchor.y_m; row.pos_z = anchor.z_m; row.behavior_phase = T.NpcPhase.PATROL
	g.state.add("npc_state", row)
	g.assign_anchor_site("npc", row.npc_instance_id, str(anchor.anchor_id))

func remaining(encounter_id: String) -> int:
	var count: int = 0
	for member in _members(encounter_id):
		var npc: RefCounted = g.state.find("npc_state", "spawn_id", member.spawn_id)
		if npc != null and npc.alive: count += 1
	return count

func tick(delta: float) -> void:
	if not supported(): return
	for definition in g.rows("encounter_defs"):
		if not g.unlocked(definition.required_unlock_id): continue
		var row: D.EncounterStateDto = g.state.find("encounter_state", "encounter_id", definition.encounter_id)
		var members: Array[Dictionary] = _members(definition.encounter_id)
		if row == null:
			row = D.EncounterStateDto.new(); row.encounter_id = definition.encounter_id
			var found: bool = false
			for member in members:
				var previous: RefCounted = g.state.find("npc_state", "spawn_id", member.spawn_id)
				if previous != null:
					found = true; row.generation = maxi(row.generation, previous.generation)
					row.respawn_remaining_s = maxf(row.respawn_remaining_s, previous.respawn_remaining_s)
			g.state.add("encounter_state", row)
			# Adopt old members without restoring a slain ship or resetting its loot.
			if found and remaining(row.encounter_id) == 0:
				row.respawn_remaining_s = maxf(row.respawn_remaining_s, float(definition.respawn_seconds))
			else:
				for member in members:
					if g.state.find("npc_state", "spawn_id", member.spawn_id) == null: _spawn(member, row.generation)
			continue
		if remaining(row.encounter_id) > 0:
			for member in members:
				if g.state.find("npc_state", "spawn_id", member.spawn_id) == null: _spawn(member, row.generation)
			continue
		row.respawn_remaining_s = maxf(0.0, row.respawn_remaining_s - delta)
		if row.respawn_remaining_s > 0.0: continue
		row.generation += 1
		for member in members:
			var previous: RefCounted = g.state.find("npc_state", "spawn_id", member.spawn_id)
			if previous != null: g.remove_npc(previous)
			_spawn(member, row.generation)

func on_destroy(npc: D.NpcStateDto) -> bool:
	var group_id: String = group_for_spawn(npc.spawn_id)
	if not group_id.is_empty() and remaining(group_id) == 0:
		var group: RefCounted = g.state.find("encounter_state", "encounter_id", group_id)
		if group != null: group.respawn_remaining_s = g.definition("encounter_defs", "encounter_id", group_id).respawn_seconds
	if not supported() or npc.loot_claimed: return false
	var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", npc.spawn_id)
	if spawn.occurrence_mode != "ambient" or not bool(spawn.loot_enabled): return false
	var mapping: Dictionary = g.definition("npc_salvage_defs", "npc_def_id", spawn.npc_id)
	if mapping.is_empty(): return false
	var pool: Array[Dictionary] = []; var total: int = 0
	for reward in g.rows("salvage_reward_defs"):
		if reward.package_def_id == mapping.package_def_id: pool.append(reward); total += int(reward.weight)
	if pool.is_empty() or total <= 0: return false
	var draw: int = Rng.new(g.state.rows("rng_state")[0]).bounded(total)
	var selected: Dictionary = pool[0]
	for reward in pool:
		if draw < int(reward.weight): selected = reward; break
		draw -= int(reward.weight)
	var row: D.SalvagePackageStateDto = D.SalvagePackageStateDto.new()
	row.package_id = g.id("salvage"); row.package_def_id = mapping.package_def_id
	row.source_npc_instance_id = npc.npc_instance_id; row.source_generation = npc.generation
	row.has_host_container_id = true; row.host_container_id = g.inventory.wreck(npc.sector_id, g.position(npc), g.spatial_site("npc", npc.npc_instance_id))
	row.reward_id = selected.reward_id
	g.state.add("salvage_package_state", row)
	return true

func waypoints(sector_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not supported(): return result
	for definition in g.rows("encounter_defs"):
		if definition.sector_id != sector_id or not g.unlocked(definition.required_unlock_id): continue
		var group: RefCounted = g.state.find("encounter_state", "encounter_id", definition.encounter_id)
		var level: int = 0
		for member in _members(definition.encounter_id):
			var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", member.spawn_id)
			level = maxi(level, int(g.definition("npc_full_defs", "npc_id", spawn.npc_id).level))
		result.append({"id": "group:" + str(definition.encounter_id), "title": definition.display_name, "kind": "encounter", "anchor_id": definition.anchor_id, "remaining_count": remaining(definition.encounter_id), "total_count": _members(definition.encounter_id).size(), "respawn_remaining_s": group.respawn_remaining_s if group != null else 0.0, "level": level, "mission_target": false, "reveal_range_m": definition.reveal_range_m, "warp_arrival_m": definition.warp_arrival_m})
	return result

func packages(container_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not supported(): return result
	for row in g.state.rows("salvage_package_state"):
		if row.status != "sealed" or not row.has_host_container_id or (not container_id.is_empty() and row.host_container_id != container_id): continue
		var definition: Dictionary = g.definition("salvage_package_defs", "package_def_id", row.package_def_id)
		result.append({"package_id": row.package_id, "title": definition.display_name, "container_id": row.host_container_id, "volume_l": float(definition.volume_m3) * 1000.0, "mass_kg": definition.mass_kg, "possible_rewards": "鉴定可获得信用点、矿物、材料或Ⅰ级配件；结果已封存。"})
	return result

func can_hold(container_id: String, package_def_id: String, moved_mass_credit: float = 0.0) -> bool:
	var container: RefCounted = g.state.find("container_state", "container_id", container_id)
	if container == null: return false
	if container.kind in [T.ContainerKind.STATION, T.ContainerKind.WRECK]: return true
	if container.kind != T.ContainerKind.CARGO: return false
	var definition: Dictionary = g.definition("salvage_package_defs", "package_def_id", package_def_id)
	if definition.is_empty(): return false
	var ship: D.ShipStateDto = g.state.find("ship_state", "ship_instance_id", container.ship_instance_id)
	var metrics: Dictionary = g.metrics(ship)
	return float(g.inventory.totals(container_id).volume) + float(definition.volume_m3) * 1000.0 <= float(metrics.cargo_capacity_l) and float(metrics.payload_mass_kg) - moved_mass_credit + float(definition.mass_kg) <= float(metrics.max_payload_mass_kg)

func move_package(package_id: String, destination: String) -> bool:
	var row: RefCounted = g.state.find("salvage_package_state", "package_id", package_id)
	if row == null or row.status != "sealed" or not row.has_host_container_id: return g.fail("回收包不存在或已鉴定")
	if destination == row.host_container_id: return g.fail("回收包已在此容器")
	if not g.inventory.accessible(row.host_container_id) or not g.inventory.accessible(destination): return g.fail("回收包或目的容器当前不可访问")
	var source: RefCounted = g.state.find("container_state", "container_id", row.host_container_id)
	var credit: float = 0.0
	if source.has_ship_instance_id: credit = float(g.definition("salvage_package_defs", "package_def_id", row.package_def_id).mass_kg)
	if not can_hold(destination, row.package_def_id, credit): return g.fail("货舱体积或载荷不足，回收包保留在原处")
	var previous: String = row.host_container_id
	row.host_container_id = destination
	g.inventory.remove_empty_wreck(previous)
	return true

func open_package(package_id: String) -> bool:
	if g.state.ship().status != T.ShipStatus.DOCKED or not g.allowed_service("warehouse"): return g.fail("停靠任意空间站后才能鉴定回收包")
	var row: RefCounted = g.state.find("salvage_package_state", "package_id", package_id)
	if row == null or row.status != "sealed" or not row.has_host_container_id: return g.fail("回收包已鉴定或不存在")
	var source: RefCounted = g.state.find("container_state", "container_id", row.host_container_id)
	if source == null or source.kind not in [T.ContainerKind.CARGO, T.ContainerKind.STATION] or not g.inventory.accessible(row.host_container_id): return g.fail("请先将回收包打捞至船舱或本地仓库")
	var reward: Dictionary = g.definition("salvage_reward_defs", "reward_id", row.reward_id)
	if reward.is_empty() or reward.package_def_id != row.package_def_id: return g.fail("回收包的封存结果无效")
	var station_id: String = g.station()
	var destination: String = g.inventory.warehouse(station_id)
	var description: String = "%d 信用点" % int(reward.credit_units)
	if reward.item_def_id != null and int(reward.quantity) > 0:
		g.inventory.grant(destination, str(reward.item_def_id), int(reward.quantity), "normal_owned", "", "", T.ItemOrigin.LOOT)
		g.journal.source(str(reward.item_def_id),int(reward.quantity),"salvage")
		description += " · %s × %d（本地仓库）" % [g.definition("item_defs", "item_id", reward.item_def_id).display_name, int(reward.quantity)]
	g.state.player().credit += int(reward.credit_units)
	row.status = "opened"; row.has_host_container_id = false; row.host_container_id = ""
	row.has_opened_station_id = true; row.opened_station_id = station_id; row.opened_tick = g.state.snapshot.meta.simulation_tick
	g.status_text = "打捞鉴定完成：" + description
	return true
