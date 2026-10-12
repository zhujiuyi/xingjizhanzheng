extends RefCounted
## Pure crew effects shared by gameplay and snapshot validation.
static func amount(state: XJRuntimeState,catalog: XJCatalog,ship_id: String,stat: String) -> float:
	if not catalog.table_names.has("crew_profile_defs"):return 0.0
	var balance: Dictionary=catalog.rows("fleet_balance_defs")[0];var result: float=0.0
	for assignment: RefCounted in state.rows("crew_assignment_state"):
		if assignment.ship_instance_id!=ship_id:continue
		var member: RefCounted=state.find("crew_member_state","profile_id",assignment.profile_id)
		var profession: Dictionary=catalog.one("crew_profession_defs","profession_id",assignment.profession_id)
		if member==null or member.phase!="hired" or member.loyalty<int(balance.loyalty_ready_min) or member.unpaid_periods>=int(balance.arrears_period_limit) or profession.get("effect_stat","")!=stat:continue
		var level: int=0;var value: float=0.0
		for rank: Dictionary in catalog.rows("crew_rank_defs"):
			if rank.profession_id==assignment.profession_id and int(rank.experience_required)<=member.experience and int(rank.rank)>level:level=int(rank.rank);value=float(rank.effect_value)
		result+=value*float(member.loyalty)/100.0
	return result
