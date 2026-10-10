class_name XJStateValidation
extends RefCounted
const State = preload("res://runtime/state.gd")
const Types = preload("res://contracts/contract_types.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Rng = preload("res://runtime/rng.gd")
var last_error: String = ""

func validate(state: State, catalog: XJCatalog, allow_legacy_capacity: bool = false) -> bool:
	if state.rows("player_state").size() != 1 or state.ship() == null:
		return _fail("Exactly one player and owned controlled ship required")
	if state.rows("rng_state").size() != 1 or not Rng.new(state.rows("rng_state")[0]).valid():
		return _fail("Invalid world RNG stream")
	var codec: Codec = Codec.new()
	for table in State.TABLES:
		for row in state.rows(table):
			if codec.encode_row(table, row).is_empty(): return _fail(codec.last_error)
	if not _validate_encounters(state, catalog): return false
	if not _validate_space(state, catalog): return false
	if not _validate_civilizations(state, catalog): return false
	for ship in state.rows("ship_state"):
		var norm: float = ship.quat_x * ship.quat_x + ship.quat_y * ship.quat_y + ship.quat_z * ship.quat_z + ship.quat_w * ship.quat_w
		if abs(norm - 1.0) >= 0.00001: return _fail("Invalid normalized ship quaternion")
		var definition: Dictionary = catalog.one("ship_defs", "ship_id", ship.ship_def_id)
		if definition.is_empty(): return _fail("Unknown ship definition")
		var counts: Dictionary = {}
		var power: float = 0.0
		var cpu: float = 0.0
		var mass: float = 0.0
		var weapon_families: Dictionary = {}
		for equipment in state.rows("equipment_state"):
			var container: RefCounted = state.find("container_state", "container_id", equipment.slot_container_id)
			var item: RefCounted = state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
			if container == null or item == null: return _fail("Missing equipped item/container")
			if container.ship_instance_id != ship.ship_instance_id: continue
			if item.owner_player_id != ship.owner_player_id or item.container_id != equipment.slot_container_id: return _fail("Equipment ownership/location mismatch")
			var module: Dictionary = catalog.one("module_defs", "module_id", equipment.module_def_id)
			var item_def: Dictionary = catalog.one("item_defs", "item_id", item.item_def_id)
			if module.is_empty() or item_def.is_empty(): return _fail("Missing fitted definition")
			if item.item_def_id != equipment.module_def_id or not container.has_slot_type or not container.has_slot_index or container.kind != Types.ContainerKind.SLOT or not container.has_ship_def_id or container.ship_def_id != ship.ship_def_id: return _fail("Equipment item/slot mismatch")
			var slot_type: String = ["weapon", "work", "utility", "structure"][int(container.slot_type)]
			if slot_type != module.slot_type: return _fail("Equipment slot type mismatch")
			var valid_slot: bool = false
			for slot in catalog.rows("ship_slot_defs"):
				if slot.ship_id == ship.ship_def_id and slot.slot_type == slot_type and int(slot.slot_index) == container.slot_index: valid_slot = true; break
			if not valid_slot: return _fail("Equipment slot is not defined for hull")
			if catalog.table_names.has("ship_weapon_permissions") and not catalog.one("weapon_defs", "module_id", equipment.module_def_id).is_empty():
				var profile: Dictionary = catalog.one("weapon_behavior_defs", "module_id", equipment.module_def_id)
				if profile.is_empty(): return _fail("Missing weapon behavior")
				var permission: Dictionary = {}
				for row in catalog.rows("ship_weapon_permissions"):
					if row.ship_id == ship.ship_def_id and row.family_id == profile.family_id: permission = row; break
				if permission.is_empty() or int(profile.size_class) > int(permission.max_size): return _fail("Weapon family or size is incompatible with hull")
				weapon_families[profile.family_id] = int(weapon_families.get(profile.family_id, 0)) + 1
				if int(weapon_families[profile.family_id]) > int(permission.max_installed): return _fail("Weapon family installation limit exceeded")
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
		for equipment in state.rows("equipment_state"):
			var container: RefCounted = state.find("container_state", "container_id", equipment.slot_container_id)
			if container.ship_instance_id != ship.ship_instance_id: continue
			var item: RefCounted = state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
			if not allow_legacy_capacity and (not equipment.enabled or item.durability <= 0): continue
			for modifier in catalog.rows("module_stat_modifiers"):
				if modifier.module_id == equipment.module_def_id and modifier.operation == "add": extra[modifier.stat_id] = float(extra.get(modifier.stat_id, 0.0)) + modifier.amount * (1.0 if allow_legacy_capacity else item.quality_multiplier)
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

func _validate_civilizations(state: State, catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("civilization_defs"):
		for table: String in ["civilization_state", "territory_state", "war_campaign_state", "war_fleet_state"]:
			if not state.rows(table).is_empty(): return _fail("Civilization state references legacy rules")
		return true
	if state.rows("civilization_state").size() != 1: return _fail("Exactly one civilization identity required")
	var identity: RefCounted = state.rows("civilization_state")[0]
	if identity.player_id != state.player().player_id or identity.switch_cooldown_remaining_s < 0: return _fail("Invalid civilization identity")
	if identity.has_faction_id and catalog.one("civilization_defs", "faction_id", identity.faction_id).is_empty(): return _fail("Unknown allegiance")
	var controls: Dictionary = {}
	for row: RefCounted in state.rows("territory_state"):
		var policy: Dictionary = catalog.one("sector_sovereignty_defs", "sector_id", row.sector_id)
		if policy.is_empty() or controls.has(row.sector_id): return _fail("Unknown or duplicate territory")
		var owner: Variant = row.faction_id if row.has_faction_id else null
		if not bool(policy.conquerable) and owner != policy.initial_faction_id: return _fail("Protected territory ownership changed")
		if row.has_faction_id and catalog.one("civilization_defs", "faction_id", row.faction_id).is_empty(): return _fail("Unknown territory owner")
		controls[row.sector_id] = owner
	if controls.size() != catalog.rows("sector_sovereignty_defs").size(): return _fail("Incomplete territory coverage")
	var wars: Dictionary = {}
	var active: int = 0
	for war: RefCounted in state.rows("war_campaign_state"):
		var definition: Dictionary = catalog.one("civilization_war_defs", "war_id", war.war_id)
		if definition.is_empty() or wars.has(war.war_id) or war.player_id != state.player().player_id: return _fail("Invalid war campaign identity")
		wars[war.war_id] = war
		if war.status not in ["assembling", "fighting", "occupying", "won", "failed", "cancelled"] or war.fleet_order not in ["advance", "focus", "regroup"]: return _fail("Invalid war phase or order")
		if war.capture_remaining_s < 0 or war.capture_remaining_s > float(definition.capture_duration_s) or war.attempt < 1: return _fail("Invalid war capture clock")
		if bool(war.rewards_claimed) != (war.status == "won"): return _fail("War reward receipt mismatch")
		if war.status == "won" and controls[definition.target_sector_id] != definition.faction_id: return _fail("War victory missing territory")
		if war.status in ["assembling", "fighting", "occupying"]:
			active += 1
			if not identity.has_faction_id or identity.faction_id != definition.faction_id or controls[definition.target_sector_id] != null: return _fail("Active war has wrong allegiance or occupied target")
			var reputation: RefCounted = state.find("reputation_state", "faction_id", definition.faction_id)
			for rank: Dictionary in catalog.rows("civilization_rank_defs"):
				if rank.faction_id == definition.faction_id and int(rank.rank_level) == int(definition.required_rank) and (reputation == null or reputation.reputation < int(rank.required_reputation)): return _fail("War requires its frozen reputation rank")
	if active > 1: return _fail("Multiple simultaneous war campaigns")
	var members: Dictionary = {}
	var seen: Dictionary = {}
	for fleet: RefCounted in state.rows("war_fleet_state"):
		var npc: RefCounted = state.find("npc_state", "npc_instance_id", fleet.npc_instance_id)
		if npc == null or seen.has(fleet.npc_instance_id) or not wars.has(fleet.war_id): return _fail("Orphan or duplicate war fleet member")
		seen[fleet.npc_instance_id] = true
		var definition: Dictionary = catalog.one("civilization_war_members", "spawn_id", npc.spawn_id)
		if definition.is_empty() or definition.war_id != fleet.war_id or definition.side != fleet.side: return _fail("War fleet member identity mismatch")
		var ids: Array = members.get(fleet.war_id, [])
		if ids.has(npc.spawn_id): return _fail("Duplicate war spawn")
		ids.append(npc.spawn_id); members[fleet.war_id] = ids
	for war_id: String in wars:
		if wars[war_id].status not in ["assembling", "fighting", "occupying"]: continue
		var expected: int = 0
		for member: Dictionary in catalog.rows("civilization_war_members"):
			if member.war_id == war_id: expected += 1
		if members.get(war_id, []).size() != expected: return _fail("Incomplete active war fleet")
	for sector_id: String in controls:
		var policy: Dictionary = catalog.one("sector_sovereignty_defs", "sector_id", sector_id)
		if policy.initial_faction_id != null or controls[sector_id] == null: continue
		var proved: bool = false
		for war_id: String in wars:
			var definition: Dictionary = catalog.one("civilization_war_defs", "war_id", war_id)
			if wars[war_id].status == "won" and definition.target_sector_id == sector_id and definition.faction_id == controls[sector_id]: proved = true
		if not proved: return _fail("Territory capture lacks a completed war")
	return true

func _validate_space(state: State, catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("site_defs"):
		return state.rows("spatial_state").is_empty() or _fail("Spatial state references legacy content")
	var expected: Dictionary = {}
	for ship in state.rows("ship_state"): expected["ship:" + ship.ship_instance_id] = ship.sector_id
	for npc in state.rows("npc_state"): expected["npc:" + npc.npc_instance_id] = npc.sector_id
	for container in state.rows("container_state"):
		if container.kind == Types.ContainerKind.WRECK: expected["wreck:" + container.container_id] = container.sector_id
	var seen: Dictionary = {}
	for row in state.rows("spatial_state"):
		var key: String = row.entity_kind + ":" + row.entity_id
		var site: Dictionary = catalog.one("site_defs", "site_id", row.site_id)
		if seen.has(key) or not expected.has(key) or site.is_empty() or str(site.sector_id) != str(expected[key]): return _fail("Invalid spatial entity/site context: " + key)
		if row.entity_kind == "npc":
			var npc: RefCounted = state.find("npc_state", "npc_instance_id", row.entity_id)
			var spawn: Dictionary = catalog.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
			if catalog.one("anchor_site_defs", "anchor_id", str(spawn.get("anchor_id", ""))).get("site_id") != row.site_id: return _fail("NPC site differs from its frozen spawn")
		if row.entity_kind == "ship":
			var ship: RefCounted = state.find("ship_state", "ship_instance_id", row.entity_id)
			if ship.status == Types.ShipStatus.DOCKED:
				var station: Dictionary = catalog.one("station_defs", "station_id", ship.station_id)
				if catalog.one("anchor_site_defs", "anchor_id", str(station.get("station_anchor_id", ""))).get("site_id") != row.site_id: return _fail("Docked ship site differs from its frozen station")
		seen[key] = true
	return seen.size() == expected.size() or _fail("Missing spatial context for ship, NPC or wreck")

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
