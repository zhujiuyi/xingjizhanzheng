class_name XJStateValidation
extends RefCounted
const State = preload("res://runtime/state.gd")
const Types = preload("res://contracts/contract_types.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Rng = preload("res://runtime/rng.gd")
var last_error: String = ""

func validate(state: State, catalog: XJCatalog) -> bool:
	if state.rows("player_state").size() != 1 or state.ship() == null:
		return _fail("Exactly one player and owned controlled ship required")
	if state.rows("rng_state").size() != 1 or not Rng.new(state.rows("rng_state")[0]).valid():
		return _fail("Invalid world RNG stream")
	var codec: Codec = Codec.new()
	for table in State.TABLES:
		for row in state.rows(table):
			if codec.encode_row(table, row).is_empty(): return _fail(codec.last_error)
	if not _validate_encounters(state, catalog): return false
	for ship in state.rows("ship_state"):
		var norm: float = ship.quat_x * ship.quat_x + ship.quat_y * ship.quat_y + ship.quat_z * ship.quat_z + ship.quat_w * ship.quat_w
		if abs(norm - 1.0) >= 0.00001: return _fail("Invalid normalized ship quaternion")
		var definition: Dictionary = catalog.one("ship_defs", "ship_id", ship.ship_def_id)
		if definition.is_empty(): return _fail("Unknown ship definition")
		var counts: Dictionary = {}
		var power: float = 0.0
		var cpu: float = 0.0
		var mass: float = 0.0
		for equipment in state.rows("equipment_state"):
			var container: RefCounted = state.find("container_state", "container_id", equipment.slot_container_id)
			var item: RefCounted = state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
			if container == null or item == null: return _fail("Missing equipped item/container")
			if container.ship_instance_id != ship.ship_instance_id: continue
			if item.owner_player_id != ship.owner_player_id or item.container_id != equipment.slot_container_id: return _fail("Equipment ownership/location mismatch")
			var module: Dictionary = catalog.one("module_defs", "module_id", equipment.module_def_id)
			var item_def: Dictionary = catalog.one("item_defs", "item_id", item.item_def_id)
			if module.is_empty() or item_def.is_empty(): return _fail("Missing fitted definition")
			counts[equipment.module_def_id] = int(counts.get(equipment.module_def_id, 0)) + 1
			power += module.power_pu
			cpu += module.cpu_cu
			mass += item_def.unit_mass_kg
		if power > definition.power_capacity or cpu > definition.cpu_capacity or mass > definition.max_installed_mass_kg: return _fail("Installation budget exceeded")
		var groups: Dictionary = {}
		for module_id in counts:
			var module: Dictionary = catalog.one("module_defs", "module_id", module_id)
			if module.max_per_ship != null and counts[module_id] > module.max_per_ship: return _fail("Module installation limit exceeded")
			for member in catalog.rows("module_group_members"):
				if member.module_id == module_id: groups[member.group_id] = int(groups.get(member.group_id, 0)) + counts[module_id]
		for group in groups:
			if groups[group] > catalog.one("module_exclusion_groups", "group_id", group).max_installed: return _fail("Module exclusion exceeded")
		var extra: Dictionary = {}
		for modifier in catalog.rows("module_stat_modifiers"):
			if modifier.operation == "add": extra[modifier.stat_id] = float(extra.get(modifier.stat_id, 0.0)) + modifier.amount * counts.get(modifier.module_id, 0)
		for layer in ["shield", "armor", "hull", "energy", "heat"]:
			if ship.get(layer) > definition[layer + "_max"] + extra.get(layer + "_max", 0.0) + 0.0000001: return _fail("Ship field over fitted maximum: " + layer)
		var payload: float = 0.0
		for container in state.rows("container_state"):
			if not container.has_ship_instance_id or container.ship_instance_id != ship.ship_instance_id or container.kind not in [Types.ContainerKind.CARGO, Types.ContainerKind.MINERAL]: continue
			var cargo: Array[Dictionary] = []
			for item in state.rows("item_instance_state"):
				if item.container_id == container.container_id: cargo.append({"id": item.item_def_id, "quantity": 1})
			for stack in state.rows("inventory_stack_state"):
				if stack.container_id == container.container_id: cargo.append({"id": stack.item_def_id, "quantity": stack.quantity})
			var volume: float = 0.0
			for item in cargo:
				var item_def: Dictionary = catalog.one("item_defs", "item_id", item.id)
				if item_def.is_empty(): return _fail("Unknown cargo item")
				if container.kind == Types.ContainerKind.MINERAL and item_def.item_type != "ore": return _fail("Non-ore in mineral hold")
				volume += item_def.unit_volume_l * item.quantity
				payload += item_def.unit_mass_kg * item.quantity
			for package in state.rows("salvage_package_state"):
				if package.status != "sealed" or package.host_container_id != container.container_id: continue
				if container.kind != Types.ContainerKind.CARGO: return _fail("Recovery package in mineral hold")
				var package_def: Dictionary = catalog.one("salvage_package_defs", "package_def_id", package.package_def_id)
				if package_def.is_empty(): return _fail("Unknown recovery package")
				volume += float(package_def.volume_m3) * 1000.0
				payload += float(package_def.mass_kg)
			var capacity: int = definition.cargo_l if container.kind == Types.ContainerKind.CARGO else definition.mineral_cargo_l
			if volume > capacity: return _fail("Cargo volume exceeded")
		if payload > definition.max_payload_mass_kg + 0.0000001: return _fail("Shared payload mass exceeded")
	return true

func _validate_encounters(state: State, catalog: XJCatalog) -> bool:
	var supported: bool = catalog.table_names.has("encounter_defs")
	if not supported:
		return (state.rows("encounter_state").is_empty() and state.rows("salvage_package_state").is_empty()) or _fail("New state references legacy content")
	var seen_groups: Dictionary = {}
	for group in state.rows("encounter_state"):
		var definition: Dictionary = catalog.one("encounter_defs", "encounter_id", group.encounter_id)
		if definition.is_empty() or seen_groups.has(group.encounter_id) or group.respawn_remaining_s < 0 or group.respawn_remaining_s > float(definition.respawn_seconds): return _fail("Invalid combat site state")
		seen_groups[group.encounter_id] = true
		if group.respawn_remaining_s > 0:
			for member in catalog.rows("encounter_members"):
				if member.encounter_id != group.encounter_id: continue
				var npc: RefCounted = state.find("npc_state", "spawn_id", member.spawn_id)
				if npc != null and npc.alive: return _fail("Refresh timer started before group clear")
	if seen_groups.size() != catalog.rows("encounter_defs").size(): return _fail("Incomplete combat site state")
	var sources: Dictionary = {}; var ids: Dictionary = {}
	for package in state.rows("salvage_package_state"):
		var definition: Dictionary = catalog.one("salvage_package_defs", "package_def_id", package.package_def_id)
		var reward: Dictionary = catalog.one("salvage_reward_defs", "reward_id", package.reward_id)
		var source_key: String = "%s:%d" % [package.source_npc_instance_id, package.source_generation]
		if definition.is_empty() or reward.is_empty() or reward.package_def_id != package.package_def_id or package.source_npc_instance_id.is_empty() or package.source_generation < 0 or ids.has(package.package_id) or sources.has(source_key): return _fail("Invalid or duplicate recovery package")
		ids[package.package_id] = true; sources[source_key] = true
		if package.status == "sealed":
			var container: RefCounted = state.find("container_state", "container_id", package.host_container_id)
			if not package.has_host_container_id or package.has_opened_station_id or package.opened_tick != 0 or container == null or container.kind not in [Types.ContainerKind.STATION, Types.ContainerKind.CARGO, Types.ContainerKind.WRECK] or container.owner_player_id != state.player().player_id: return _fail("Invalid recovery package host")
		elif package.status == "opened":
			if package.has_host_container_id or not package.has_opened_station_id or catalog.one("station_defs", "station_id", package.opened_station_id).is_empty() or package.opened_tick > state.snapshot.meta.simulation_tick: return _fail("Invalid opened recovery package receipt")
		else: return _fail("Unknown recovery package status")
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false
