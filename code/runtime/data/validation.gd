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
			var volume: int = 0
			for item in cargo:
				var item_def: Dictionary = catalog.one("item_defs", "item_id", item.id)
				if item_def.is_empty(): return _fail("Unknown cargo item")
				if container.kind == Types.ContainerKind.MINERAL and item_def.item_type != "ore": return _fail("Non-ore in mineral hold")
				volume += item_def.unit_volume_l * item.quantity
				payload += item_def.unit_mass_kg * item.quantity
			var capacity: int = definition.cargo_l if container.kind == Types.ContainerKind.CARGO else definition.mineral_cargo_l
			if volume > capacity: return _fail("Cargo volume exceeded")
		if payload > definition.max_payload_mass_kg + 0.0000001: return _fail("Shared payload mass exceeded")
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false
