extends RefCounted
const D=preload("res://contracts/contract_dtos.gd")

static func rows(catalog: XJCatalog,state: XJRuntimeState) -> Dictionary:
	if not catalog.table_names.has("fleet_balance_defs"):return {}
	var result: Dictionary={"crew_member_state":[],"fleet_total_state":[D.FleetTotalStateDto.new()],"auxiliary_bay_state":[]}
	var balance: Dictionary=catalog.rows("fleet_balance_defs")[0]
	result.fleet_total_state[0].singleton=1
	for profile: Dictionary in catalog.rows("crew_profile_defs"):
		var row: RefCounted=D.CrewMemberStateDto.new();row.profile_id=profile.profile_id;row.phase="available";row.loyalty=int(balance.loyalty_initial)
		result.crew_member_state.append(row)
	for item: RefCounted in state.rows("item_instance_state"):
		var spec: Dictionary=catalog.one("auxiliary_drone_defs","module_id",item.item_def_id)
		if spec.is_empty():continue
		var bay: RefCounted=D.AuxiliaryBayStateDto.new();bay.item_instance_id=item.item_instance_id;bay.stock_units=int(spec.drone_count);bay.command_kind="follow";result.auxiliary_bay_state.append(bay)
	return result
