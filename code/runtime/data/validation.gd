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
	if not _validate_industry(state, catalog): return false
	if not _validate_exploration(state, catalog): return false
	if not _validate_mobile_belts(state, catalog): return false
	if not _validate_tactics(state, catalog): return false
	if not _validate_operations(state, catalog): return false
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
			if container.kind == Types.ContainerKind.CARGO and catalog.table_names.has("operation_defs"):
				for operation: RefCounted in state.rows("operation_state"):
					if not operation.has_payload_ship_id or operation.payload_ship_id != ship.ship_instance_id: continue
					var op_def: Dictionary = catalog.one("operation_defs","operation_id",operation.operation_id)
					volume += operation.cargo_units * float(op_def.cargo_volume_l)
					payload += operation.cargo_units * float(op_def.cargo_mass_kg)
			var capacity: int = definition.cargo_l if container.kind == Types.ContainerKind.CARGO else definition.mineral_cargo_l
			if volume > capacity: return _fail("Cargo volume exceeded")
		if payload > definition.max_payload_mass_kg + 0.0000001: return _fail("Shared payload mass exceeded")
	return true

func _validate_operations(state: State, catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("operation_defs"): return state.rows("operation_state").is_empty() or _fail("Operations under legacy content")
	if state.rows("operation_state").size() != catalog.rows("operation_defs").size(): return _fail("Operation coverage incomplete")
	var seen: Dictionary = {}
	for row: RefCounted in state.rows("operation_state"):
		var spec: Dictionary = catalog.one("operation_defs","operation_id",row.operation_id)
		if spec.is_empty() or seen.has(row.operation_id): return _fail("Invalid operation identity")
		seen[row.operation_id] = true
		if row.phase not in ["available","accepted","active","ready","claimed","failed","withdrawn"] or row.generation < 0: return _fail("Invalid operation phase")
		if row.remaining_s < 0.0 or row.remaining_s > float(spec.duration_s) or row.cooldown_remaining_s < 0.0 or row.cooldown_remaining_s > float(spec.cooldown_s) or row.exposure_remaining_s < 0.0 or row.exposure_remaining_s > float(spec.exposure_duration_s) or row.damage_debt_hp < 0.0 or row.damage_debt_hp >= float(spec.loss_damage_hp): return _fail("Invalid operation timing")
		if mini(mini(row.loaded_units,row.cargo_units),mini(row.completed_units,mini(row.lost_units,row.jettisoned_units))) < 0 or row.loaded_units > int(spec.target_units) or row.completed_units > int(spec.target_units) or row.rewarded_units_total < 0 or row.paid_credit_total != row.rewarded_units_total * int(spec.credit_per_unit): return _fail("Invalid operation reward ledger")
		if spec.operation_kind == "demolition":
			if row.loaded_units + row.cargo_units + row.lost_units + row.jettisoned_units != 0 or row.has_payload_ship_id: return _fail("Demolition has unexpected cargo")
			var destroyed: int = 0
			for structure: Dictionary in catalog.rows("operation_structure_defs"):
				if structure.operation_id != row.operation_id: continue
				var npc: RefCounted = state.find("npc_state","spawn_id",structure.spawn_id)
				if row.phase in ["active","ready","claimed"] and (npc == null or npc.generation != row.generation): return _fail("Operation physical structure missing")
				if npc != null and npc.generation == row.generation and not npc.alive: destroyed += 1
			if row.phase in ["active","ready","claimed"] and destroyed != row.completed_units: return _fail("Demolition progress differs from actual HP")
		else:
			if row.loaded_units != row.cargo_units + row.completed_units + row.lost_units + row.jettisoned_units: return _fail("Operation cargo conservation failed")
			if row.cargo_units > 0:
				var ship: RefCounted = state.find("ship_state","ship_instance_id",row.payload_ship_id)
				if not row.has_payload_ship_id or row.phase != "active" or ship == null or ship.status != Types.ShipStatus.FLYING or ship.owner_player_id != state.player().player_id: return _fail("Operation cargo owner unavailable")
		if row.phase == "ready" and row.completed_units <= 0: return _fail("Empty operation claim")
	return true

func _validate_tactics(state: State, catalog: XJCatalog) -> bool:
	var tables: Array[String] = ["tactical_site_state","npc_tactic_state","ship_tactical_effect_state","drone_bay_state"]
	if not catalog.table_names.has("npc_tactic_defs"):
		for table: String in tables:
			if not state.rows(table).is_empty(): return _fail("Tactical state in legacy rules")
		return true
	var seen: Dictionary = {}
	for row: RefCounted in state.rows("tactical_site_state"):
		var spec: Dictionary = catalog.one("tactical_site_defs", "site_id", row.site_id)
		if spec.is_empty() or seen.has(row.site_id) or row.generation < 0 or row.cleared_cycles < 0 or not is_finite(row.respawn_remaining_s) or row.respawn_remaining_s < 0 or row.respawn_remaining_s > float(spec.respawn_s): return _fail("Invalid tactical site")
		seen[row.site_id] = true
	if seen.size() != catalog.rows("tactical_site_defs").size(): return _fail("Incomplete tactical sites")
	seen.clear()
	for row: RefCounted in state.rows("npc_tactic_state"):
		var npc: RefCounted = state.find("npc_state", "npc_instance_id", row.npc_instance_id)
		var spec: Dictionary = catalog.one("npc_tactic_defs", "tactic_id", row.tactic_id)
		var binding: Dictionary = catalog.one("npc_tactic_bindings", "spawn_id", npc.spawn_id) if npc != null else {}
		if npc == null or spec.is_empty() or binding.get("tactic_id", "") != row.tactic_id or seen.has(row.npc_instance_id): return _fail("Invalid tactical actor identity")
		seen[row.npc_instance_id] = true
		if row.phase not in ["ready","charging","active","cooldown"]: return _fail("Invalid tactical phase")
		for field: String in ["energy","remaining_s","cooldown_remaining_s","charge_start_hp"]:
			if not is_finite(row.get(field)) or row.get(field) < 0.0: return _fail("Invalid tactical scalar")
		for field: String in ["aim_x","aim_y","aim_z"]:
			if not is_finite(row.get(field)): return _fail("Invalid tactical aim")
		if row.energy > float(spec.energy_max) or row.remaining_s > maxf(float(spec.charge_s), float(spec.duration_s)) or row.cooldown_remaining_s > float(spec.cooldown_s) or row.drone_stock < 0 or row.lost_drones < 0 or row.drone_stock + row.lost_drones != int(spec.drone_reserve) or row.deployed_drones != 0: return _fail("Tactical limits or outstanding drones")
		if row.has_target_entity_id and state.find("ship_state", "ship_instance_id", row.target_entity_id) == null and state.find("npc_state", "npc_instance_id", row.target_entity_id) == null: return _fail("Missing tactical target")
	for npc: RefCounted in state.rows("npc_state"):
		if not catalog.one("npc_tactic_bindings", "spawn_id", npc.spawn_id).is_empty() and not seen.has(npc.npc_instance_id): return _fail("Tactical actor state missing")
	var balance: Dictionary = catalog.rows("tactical_balance_defs")[0]
	seen.clear()
	for row: RefCounted in state.rows("ship_tactical_effect_state"):
		if seen.has(row.ship_instance_id) or state.find("ship_state", "ship_instance_id", row.ship_instance_id) == null: return _fail("Invalid jammed ship")
		seen[row.ship_instance_id] = true
		for field: String in ["jam_remaining_s","immunity_remaining_s","repeat_window_s"]:
			if not is_finite(row.get(field)) or row.get(field) < 0.0: return _fail("Invalid jam timer")
		if row.jam_remaining_s > float(balance.jam_max_duration_s) or row.immunity_remaining_s > float(balance.jam_immunity_s) or row.repeat_window_s > float(balance.jam_repeat_window_s) or row.repeat_count < 0 or row.repeat_count > int(balance.jam_max_repeat): return _fail("Jam exceeds minimum-control policy")
		if row.has_source_npc_id and state.find("npc_state", "npc_instance_id", row.source_npc_id) == null: return _fail("Jam source missing")
		if row.jam_remaining_s > 0.0 and not row.has_source_npc_id: return _fail("Active jam without source")
	seen.clear()
	for row: RefCounted in state.rows("drone_bay_state"):
		var item: RefCounted = state.find("item_instance_state", "item_instance_id", row.item_instance_id)
		var spec: Dictionary = catalog.one("drone_management_defs", "module_id", item.item_def_id) if item != null else {}
		if item == null or spec.is_empty() or seen.has(row.item_instance_id): return _fail("Invalid drone bay")
		seen[row.item_instance_id] = true
		var count: int = int(catalog.one("drone_defs", "module_id", item.item_def_id).drone_count)
		if row.stock_units < 0 or row.stock_units > count or row.deployed_units != 0 or row.lost_units < 0 or row.replenished_units < 0 or row.stock_units != count - row.lost_units + row.replenished_units or row.paid_credit_total != row.replenished_units * int(spec.credit_per_unit) or row.material_units_total != row.replenished_units * int(spec.material_per_unit) or row.revision < 0 or row.command_kind not in ["attack","follow","recall"]: return _fail("Drone stock or paid replacement ledger mismatch")
		if row.replenished_units > 0 and item.policy_id != "normal_owned": return _fail("Protected drone replenishment")
	for item: RefCounted in state.rows("item_instance_state"):
		if not catalog.one("drone_management_defs", "module_id", item.item_def_id).is_empty() and not seen.has(item.item_instance_id): return _fail("Drone bay state missing")
	return true

func _validate_mobile_belts(state: State, catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("exploration_belt_route_defs"):
		return state.rows("exploration_belt_state").is_empty() or _fail("Mobile belts in legacy rules")
	var events: Dictionary = {}
	for route: Dictionary in catalog.rows("exploration_belt_route_defs"): events[route.event_id] = true
	var seen: Dictionary = {}
	for row: RefCounted in state.rows("exploration_belt_state"):
		var route: Dictionary = catalog.one("exploration_belt_route_defs", "route_id", row.route_id)
		var event: RefCounted = state.find("exploration_instance_state", "event_id", row.event_id)
		if route.is_empty() or event == null or route.event_id != row.event_id or seen.has(row.event_id): return _fail("Invalid mobile belt route context")
		seen[row.event_id] = true
		var variant: Dictionary = catalog.one("exploration_variant_defs", "variant_id", event.variant_id)
		if row.stage_index < 0 or row.stage_index > 3 or row.warning_stage_index < 0 or row.warning_stage_index > 3 or not is_finite(row.start_elapsed_s) or row.start_elapsed_s < 0 or row.initial_units < 0 or row.initial_units > int(variant.mineral_units): return _fail("Mobile belt limits invalid")
		if event.phase != "mineral": continue
		if row.start_elapsed_s >= float(variant.duration_s): return _fail("Mobile belt window exhausted")
		var expected_stage: int = 0
		for stage: Dictionary in catalog.rows("exploration_belt_stage_defs"):
			if event.elapsed_s >= row.start_elapsed_s + (float(variant.duration_s) - row.start_elapsed_s) * float(stage.threshold_bp) / 10000.0: expected_stage = maxi(expected_stage, int(stage.stage_index))
		if row.stage_index != expected_stage or row.warning_stage_index < row.stage_index: return _fail("Mobile belt stage differs from saved window")
		var cap_bp: int = 10000 if row.stage_index == 0 else int(catalog.one("exploration_belt_stage_defs", "stage_index", row.stage_index).remaining_cap_bp)
		var cap: int = int(floor(float(row.initial_units) * float(cap_bp) / 10000.0))
		for node: Dictionary in catalog.rows("exploration_resource_defs"):
			if node.event_id == row.event_id and state.find("resource_state", "node_id", node.node_id).remaining_units > cap: return _fail("Dispersed mineral regenerated")
	return seen.size() == events.size() or _fail("Incomplete mobile belt coverage")

func _validate_exploration(state: State, catalog: XJCatalog) -> bool:
	var tables: Array[String] = ["exploration_instance_state", "exploration_actor_state", "exploration_claim_state", "exploration_progress_state", "exploration_research_state"]
	if not catalog.table_names.has("exploration_event_defs"):
		for table: String in tables:
			if not state.rows(table).is_empty(): return _fail("Exploration state in legacy rules")
		return true
	var balance: Dictionary = catalog.rows("exploration_balance_defs")[0]
	var instances: Dictionary = {}
	for row: RefCounted in state.rows("exploration_instance_state"):
		var event: Dictionary = catalog.one("exploration_event_defs", "event_id", row.event_id)
		var variant: Dictionary = catalog.one("exploration_variant_defs", "variant_id", row.variant_id)
		if event.is_empty() or variant.is_empty() or variant.event_id != row.event_id or instances.has(row.event_id) or row.generation <= 0 or row.variant_seed < 0: return _fail("Invalid exploration instance identity")
		instances[row.event_id] = row
		if row.phase not in ["clue", "surveyed", "rescue", "relic", "mineral", "extracting", "ready", "claimed", "failed", "withdrawn"] or row.operation_kind not in ["", "survey", "rescue", "recover", "stabilize", "deepen"]: return _fail("Invalid exploration phase or operation")
		for field: String in ["operation_remaining_s", "elapsed_s", "cooldown_remaining_s", "hazard_clock_s"]:
			if not is_finite(row.get(field)) or float(row.get(field)) < 0.0: return _fail("Invalid exploration timer")
		if row.cooldown_remaining_s > float(event.cooldown_s) or row.operation_remaining_s > maxf(float(variant.survey_duration_s), float(variant.work_duration_s)) or row.hazard_clock_s >= float(balance.hazard_period_s) or row.evidence_units < 0: return _fail("Exploration state exceeds frozen limits")
		if row.operation_kind.is_empty() and row.operation_remaining_s != 0.0: return _fail("Idle exploration retains operation time")
		if event.event_kind == "relic" and row.evidence_units > int(variant.relic_layers): return _fail("Too many relic evidence layers")
		if row.phase in ["ready", "claimed"] and row.outcome not in ["full", "partial"]: return _fail("Ready exploration has no valid outcome")
	if instances.size() != catalog.rows("exploration_event_defs").size(): return _fail("Incomplete exploration coverage")
	var earned: int = 0
	var claims: Dictionary = {}
	for row: RefCounted in state.rows("exploration_claim_state"):
		var variant: Dictionary = catalog.one("exploration_variant_defs", "variant_id", row.variant_id)
		var key: String = row.event_id + ":" + str(row.generation)
		if not instances.has(row.event_id) or row.player_id != state.player().player_id or variant.is_empty() or variant.event_id != row.event_id or claims.has(key) or row.generation > instances[row.event_id].generation or row.generation <= 0: return _fail("Invalid exploration reward identity")
		claims[key] = true
		var current: RefCounted = instances[row.event_id]
		if row.generation == current.generation and (row.variant_id != current.variant_id or current.phase != "claimed" or row.outcome != current.outcome): return _fail("Exploration receipt differs from current result")
		if row.outcome not in ["full", "partial"] or row.credit_units != int(variant.full_credit if row.outcome == "full" else variant.partial_credit) or row.insight_units <= 0 or row.insight_units > int(variant.insight_units) or (row.outcome == "full" and row.insight_units != int(variant.insight_units)) or row.reputation_units != int(variant.reputation_units if row.outcome == "full" else 0) or row.claimed_tick > state.snapshot.meta.simulation_tick: return _fail("Invalid exploration reward amount")
		earned += row.insight_units
	for row: RefCounted in state.rows("exploration_instance_state"):
		if row.phase == "claimed" and not claims.has(row.event_id + ":" + str(row.generation)): return _fail("Exploration claim receipt missing")
	var spent: int = 0
	var projects: Dictionary = {}
	for row: RefCounted in state.rows("exploration_research_state"):
		var project: Dictionary = catalog.one("exploration_research_defs", "research_id", row.research_id)
		if project.is_empty() or projects.has(row.research_id) or row.player_id != state.player().player_id or row.spent_insight != int(project.required_insight) or row.paid_credit != int(project.required_credit) or row.completed_tick > state.snapshot.meta.simulation_tick: return _fail("Invalid exploration research receipt")
		projects[row.research_id] = true
		var knowledge: bool = false
		for unlock: RefCounted in state.rows("unlock_state"):
			if unlock.player_id == row.player_id and unlock.unlock_id == project.reward_unlock_id: knowledge = true; break
		if not knowledge: return _fail("Exploration research knowledge missing")
		spent += row.spent_insight
	if state.rows("exploration_progress_state").size() != 1: return _fail("Exploration evidence balance missing")
	var progress: RefCounted = state.rows("exploration_progress_state")[0]
	if progress.player_id != state.player().player_id or progress.insight_earned != earned or progress.insight_available != earned - spent or progress.insight_available < 0: return _fail("Exploration evidence ledger mismatch")
	var actor_ids: Dictionary = {}
	for member: RefCounted in state.rows("exploration_actor_state"):
		var npc: RefCounted = state.find("npc_state", "npc_instance_id", member.npc_instance_id)
		if npc == null or actor_ids.has(member.npc_instance_id) or not instances.has(member.event_id) or member.generation != instances[member.event_id].generation or npc.generation != member.generation: return _fail("Invalid exploration actor context")
		actor_ids[member.npc_instance_id] = true
		var definition: Dictionary = catalog.one("exploration_actor_defs", "spawn_id", npc.spawn_id)
		if definition.is_empty() or definition.event_id != member.event_id or definition.actor_role != member.actor_role: return _fail("Exploration actor role differs from definition")
	for spec: Dictionary in catalog.rows("exploration_resource_defs"):
		var resource: RefCounted = state.find("resource_state", "node_id", spec.node_id)
		if resource == null: return _fail("Managed mineral state missing")
		var row: RefCounted = instances[spec.event_id]
		var active: bool = row.phase == "mineral" and row.choice_id == spec.choice_id
		var maximum: int = int(catalog.one("exploration_variant_defs", "variant_id", row.variant_id).mineral_units)
		if resource.remaining_units < 0 or resource.remaining_units > maximum or (not active and resource.remaining_units != 0) or resource.respawn_remaining_s != 0: return _fail("Inactive or exhausted temporary mineral regenerated")
	return true

func _validate_industry(state: State, catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("industry_balance_defs"):
		for table: String in ["industry_job_state", "industry_input_state", "station_demand_state"]:
			if not state.rows(table).is_empty(): return _fail("Industry state in a legacy world")
		return true
	var balance: Dictionary = catalog.rows("industry_balance_defs")[0]
	var demands: Dictionary = {}
	for row: RefCounted in state.rows("station_demand_state"):
		var definition: Dictionary = catalog.one("station_demand_defs", "demand_id", row.demand_id)
		if definition.is_empty() or demands.has(row.demand_id) or row.generation <= 0 or row.completed_cycles < 0 or row.remaining_units < 0 or row.remaining_units > int(definition.required_units): return _fail("Invalid regional need identity or quantity")
		if row.status not in ["active", "cooldown"]: return _fail("Invalid regional need phase")
		var maximum: float = definition.duration_s if row.status == "active" else definition.cooldown_s
		if not is_finite(row.phase_remaining_s) or row.phase_remaining_s < 0 or row.phase_remaining_s > maximum or not is_finite(row.benefit_remaining_s) or row.benefit_remaining_s < 0 or row.benefit_remaining_s > float(balance.demand_benefit_duration_s): return _fail("Invalid regional need timer")
		demands[row.demand_id] = true
	if demands.size() != catalog.rows("station_demand_defs").size(): return _fail("Incomplete regional needs")
	var inputs: Dictionary = {}
	for row: RefCounted in state.rows("industry_input_state"):
		if state.find("industry_job_state", "job_id", row.job_id) == null or row.quantity <= 0: return _fail("Orphan industrial escrow")
		if not inputs.has(row.job_id): inputs[row.job_id] = {}
		if inputs[row.job_id].has(row.item_id): return _fail("Duplicate industrial escrow")
		inputs[row.job_id][row.item_id] = row.quantity
	var ids: Dictionary = {}
	var sequences: Dictionary = {}
	var active: Dictionary = {}
	var running: Dictionary = {}
	for job: RefCounted in state.rows("industry_job_state"):
		var spec: Dictionary = catalog.one("industry_recipe_defs", "blueprint_id", job.blueprint_id)
		if spec.is_empty() or ids.has(job.job_id) or sequences.has(job.queue_sequence) or job.queue_sequence <= 0 or job.job_id.is_empty() or job.player_id != state.player().player_id or catalog.one("station_defs", "station_id", job.station_id).is_empty(): return _fail("Invalid industrial job identity")
		ids[job.job_id] = true; sequences[job.queue_sequence] = true
		if job.status not in ["queued", "running", "ready", "claimed", "cancelled"] or job.batches <= 0 or job.batches > int(balance.max_batches) or job.paid_credit < 0: return _fail("Invalid industrial job state")
		if not is_finite(job.duration_s) or not is_finite(job.remaining_s) or job.duration_s <= 0 or job.remaining_s < 0 or job.remaining_s > job.duration_s or job.created_tick < 0 or job.created_tick > state.snapshot.meta.simulation_tick or job.finished_tick < 0 or job.finished_tick > state.snapshot.meta.simulation_tick: return _fail("Invalid industrial job duration")
		if job.status in ["ready", "claimed"] and job.remaining_s != 0: return _fail("Incomplete job marked completed")
		var expected: Dictionary = {}
		var table: String = "recipe_inputs" if spec.recipe_id != null else "hull_recipe_inputs"
		var key: String = "recipe_id" if spec.recipe_id != null else "hull_recipe_id"
		var id: String = str(spec.recipe_id if spec.recipe_id != null else spec.hull_recipe_id)
		for row: Dictionary in catalog.rows(table):
			if row[key] == id: expected[row.item_id] = int(row.quantity) * job.batches
		if expected != inputs.get(job.job_id, {}): return _fail("Industrial material escrow differs from frozen recipe")
		if job.status == "claimed" and spec.recipe_id != null:
			var production: RefCounted = state.find("production_state", "production_id", job.job_id)
			if production == null or not production.output_claimed or production.recipe_id != spec.recipe_id or production.batches != job.batches or production.station_id != job.station_id: return _fail("Claimed industrial job lacks production receipt")
		if job.status in ["queued", "running", "ready"]: active[job.station_id] = int(active.get(job.station_id, 0)) + 1
		if job.status == "running": running[job.station_id] = int(running.get(job.station_id, 0)) + 1
	for station_id: String in active:
		if int(active[station_id]) > int(balance.queue_limit) or int(running.get(station_id, 0)) > 1: return _fail("Industrial queue exceeds frozen capacity")
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
			var anchor_id: String = preload("res://runtime/gameplay/mobile_belts.gd").resolved_anchor(catalog, state, str(spawn.get("anchor_id", "")))
			if catalog.one("anchor_site_defs", "anchor_id", anchor_id).get("site_id") != row.site_id: return _fail("NPC site differs from its frozen spawn/route")
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
