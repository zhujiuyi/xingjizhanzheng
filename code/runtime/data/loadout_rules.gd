extends RefCounted
## One data-only calculation shared by challenges and snapshot validation.
const T=preload("res://contracts/contract_types.gd")
static func equipment(state: XJRuntimeState,ship_id: String) -> Array:
	var slots: Dictionary={}
	for row: RefCounted in state.rows("container_state"):
		if row.has_ship_instance_id and row.ship_instance_id==ship_id and row.kind==T.ContainerKind.SLOT:slots[row.container_id]=true
	return state.rows("equipment_state").filter(func(row: RefCounted):return slots.has(row.slot_container_id))
static func companions(state: XJRuntimeState,catalog: XJCatalog) -> Array:
	return state.rows("fleet_deployment_state").filter(func(row: RefCounted):return row.phase=="deployed") if catalog.table_names.has("fleet_hull_defs") else []
static func supplies(catalog: XJCatalog) -> Dictionary:
	var result: Dictionary={}
	for item: Dictionary in catalog.rows("item_defs"):
		if item.item_type in ["ammo","consumable"]:result[item.item_id]=true
	for table: String in ["weapon_defs","repair_defs","auxiliary_drone_defs"]:
		if not catalog.table_names.has(table):continue
		for rule: Dictionary in catalog.rows(table):
			var id: Variant=rule.get("ammo_item_id") if table=="weapon_defs" else rule.get("consumable_item_id")
			if id!=null:result[str(id)]=true
	return result
static func hull_budget(state: XJRuntimeState,catalog: XJCatalog,hull: RefCounted,consumables: Dictionary) -> int:
	var amount: int=int(catalog.one("ship_defs","ship_id",hull.ship_def_id).base_ask_credit)
	for gear: RefCounted in equipment(state,hull.ship_instance_id):
		amount+=int(catalog.one("item_defs","item_id",gear.module_def_id).base_ask_credit)
		var bay: RefCounted=state.find("drone_bay_state","item_instance_id",gear.item_instance_id)
		var rule: Dictionary=catalog.one("drone_management_defs","module_id",gear.module_def_id) if catalog.table_names.has("drone_management_defs") else {}
		if bay==null and catalog.table_names.has("auxiliary_drone_defs"):
			bay=state.find("auxiliary_bay_state","item_instance_id",gear.item_instance_id);rule=catalog.one("auxiliary_drone_defs","module_id",gear.module_def_id)
		# Stock includes deployed surviving units; launching cannot double value.
		if bay!=null and not rule.is_empty():amount+=bay.stock_units*(int(rule.credit_per_unit)+int(rule.material_per_unit)*int(catalog.one("item_defs","item_id",rule.material_id).base_ask_credit))
	for container: RefCounted in state.rows("container_state"):
		if not container.has_ship_instance_id or container.ship_instance_id!=hull.ship_instance_id or container.kind==T.ContainerKind.SLOT:continue
		for stack: RefCounted in state.rows("inventory_stack_state"):
			if stack.container_id==container.container_id and consumables.has(stack.item_def_id):amount+=stack.quantity*int(catalog.one("item_defs","item_id",stack.item_def_id).base_ask_credit)
		for item: RefCounted in state.rows("item_instance_state"):
			if item.container_id==container.container_id and consumables.has(item.item_def_id):amount+=int(catalog.one("item_defs","item_id",item.item_def_id).base_ask_credit)
	if catalog.table_names.has("crew_profession_defs"):
		for assignment: RefCounted in state.rows("crew_assignment_state"):
			if assignment.ship_instance_id==hull.ship_instance_id:amount+=int(catalog.one("crew_profession_defs","profession_id",assignment.profession_id).hire_fee_credit)
	return amount
static func budget(state: XJRuntimeState,catalog: XJCatalog,ship: RefCounted=null) -> int:
	var hull: RefCounted=state.ship() if ship==null else ship;var consumables: Dictionary=supplies(catalog)
	var amount: int=hull_budget(state,catalog,hull,consumables)
	for row: RefCounted in companions(state,catalog):amount+=hull_budget(state,catalog,state.find("ship_state","ship_instance_id",row.ship_instance_id),consumables)
	if catalog.table_names.has("hire_profile_defs"):
		for row: RefCounted in state.rows("hire_contract_state"):
			if row.phase not in ["deployed","retreating","returning"]:continue
			var profile: Dictionary=catalog.one("hire_profile_defs","profile_id",row.profile_id);amount+=int(catalog.one("ship_defs","ship_id",profile.hull_id).base_ask_credit)
	return amount
static func fingerprint(state: XJRuntimeState,catalog: XJCatalog,ship: RefCounted=null) -> String:
	var hull: RefCounted=state.ship() if ship==null else ship;var pieces: Array[String]=[hull.ship_def_id];var party: Dictionary={hull.ship_instance_id:true}
	for gear: RefCounted in equipment(state,hull.ship_instance_id):pieces.append(gear.slot_container_id+":"+gear.item_instance_id+":"+gear.module_def_id)
	if catalog.table_names.has("hire_profile_defs"):
		for row: RefCounted in state.rows("hire_contract_state"):
			if row.phase in ["deployed","retreating","returning"]:pieces.append("hired:"+row.contract_id+":"+row.profile_id)
	for row: RefCounted in companions(state,catalog):
		party[row.ship_instance_id]=true;var owned: RefCounted=state.find("ship_state","ship_instance_id",row.ship_instance_id)
		pieces.append("owned:%s:%d:%s" % [owned.ship_instance_id,row.generation,owned.ship_def_id])
		for gear: RefCounted in equipment(state,owned.ship_instance_id):pieces.append("ownedgear:"+owned.ship_instance_id+":"+gear.slot_container_id+":"+gear.item_instance_id+":"+gear.module_def_id)
	if catalog.table_names.has("crew_profession_defs"):
		for assignment: RefCounted in state.rows("crew_assignment_state"):
			if party.has(assignment.ship_instance_id):
				var crew: RefCounted=state.find("crew_member_state","profile_id",assignment.profile_id);pieces.append("crew:%s:%d:%s:%s" % [crew.profile_id,crew.generation,assignment.ship_instance_id,assignment.profession_id])
	pieces.sort();return "|".join(pieces).sha256_text()
