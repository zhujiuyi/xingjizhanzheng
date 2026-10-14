extends RefCounted
## Availability reads this world's frozen definitions, never hull names.
const Types = preload("res://contracts/contract_types.gd")

static func capabilities(gameplay: RefCounted, ship: RefCounted = null) -> Dictionary:
	var result: Dictionary = {"attack": false, "repair": false, "recon": false}
	if not is_instance_valid(gameplay) or gameplay.state == null or gameplay.catalog == null: return result
	var hull: RefCounted = ship if ship != null else gameplay.state.ship()
	if hull == null: return result
	var slots: Dictionary = {"weapon": false, "work": false}
	for definition: Dictionary in gameplay.rows("ship_slot_defs"):
		if definition.ship_id == hull.ship_def_id and slots.has(str(definition.slot_type)): slots[str(definition.slot_type)] = true
	if slots.weapon and gameplay.catalog.table_names.has("ship_weapon_permissions") and gameplay.catalog.table_names.has("drone_defs"):
		for permission: Dictionary in gameplay.rows("ship_weapon_permissions"):
			if permission.ship_id != hull.ship_def_id or permission.family_id != "drone" or int(permission.max_installed) <= 0: continue
			for definition: Dictionary in gameplay.rows("drone_defs"):
				var behavior: Dictionary = gameplay.weapon_profile(str(definition.module_id))
				if not behavior.is_empty() and int(behavior.size_class) <= int(permission.max_size): result.attack = true
	if slots.work and gameplay.catalog.table_names.has("ship_auxiliary_permissions") and gameplay.catalog.table_names.has("auxiliary_drone_defs"):
		for permission: Dictionary in gameplay.rows("ship_auxiliary_permissions"):
			if permission.ship_id == hull.ship_def_id and int(permission.max_installed) > 0 and result.has(str(permission.role_kind)): result[str(permission.role_kind)] = true
	return result

static func capable(gameplay: RefCounted) -> bool:
	if not is_instance_valid(gameplay) or gameplay.drone_control == null or not gameplay.drone_control.supported(): return false
	var allowed: Dictionary = capabilities(gameplay)
	return bool(allowed.attack) or bool(allowed.repair) or bool(allowed.recon)

static func role(gameplay: RefCounted, module_id: String) -> String:
	if not is_instance_valid(gameplay) or gameplay.catalog == null: return ""
	if gameplay.catalog.table_names.has("drone_defs") and not gameplay.definition("drone_defs", "module_id", module_id).is_empty(): return "attack"
	if gameplay.catalog.table_names.has("auxiliary_drone_defs"):
		return str(gameplay.definition("auxiliary_drone_defs", "module_id", module_id).get("role_kind", ""))
	return ""

static func equipped(gameplay: RefCounted, requested_role: String = "") -> Array:
	var result: Array = []
	if not capable(gameplay): return result
	var hull: RefCounted = gameplay.state.ship()
	var allowed: Dictionary = capabilities(gameplay, hull)
	for equipment: RefCounted in gameplay.equipped(hull):
		var container: RefCounted = gameplay.state.find("container_state", "container_id", equipment.slot_container_id)
		var item: RefCounted = gameplay.state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
		if container == null or item == null or container.kind != Types.ContainerKind.SLOT or container.ship_instance_id != hull.ship_instance_id or item.container_id != container.container_id: continue
		var kind: String = role(gameplay, str(equipment.module_def_id))
		if kind.is_empty() or not bool(allowed.get(kind, false)) or (not requested_role.is_empty() and kind != requested_role): continue
		result.append(equipment)
	return result
