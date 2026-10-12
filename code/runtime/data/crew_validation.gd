extends RefCounted
const T=preload("res://contracts/contract_types.gd")
var last_error: String=""
func fail(message: String) -> bool:last_error=message;return false
func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("crew_profile_defs"):
		for table: String in ["crew_member_state","crew_assignment_state","crew_receipt_state","crew_support_quote_state"]:
			if not state.rows(table).is_empty():return fail("Crew rows under legacy rules")
		return true
	var balance: Dictionary=catalog.rows("fleet_balance_defs")[0]
	var members: Dictionary={};var assignments: Dictionary={};var slots: Dictionary={};var jobs: Dictionary={};var recruited: int=0
	var tick: int=state.snapshot.meta.simulation_tick
	var hz: float=0.0
	for parameter: Dictionary in catalog.rows("rule_parameters"):
		if parameter.parameter_id=="simulation_hz":hz=float(parameter.value_real if parameter.value_real!=null else parameter.value_integer)
	for row: RefCounted in state.rows("crew_member_state"):
		var profile: Dictionary=catalog.one("crew_profile_defs","profile_id",row.profile_id)
		if profile.is_empty() or members.has(row.profile_id):return fail("Crew identity is missing or duplicated")
		var job: Dictionary=catalog.one("crew_profession_defs","profession_id",profile.profession_id)
		if row.phase not in ["available","hired","injured","resting"] or row.generation<0 or row.revision<0:return fail("Invalid crew lifecycle")
		if row.phase!="available":recruited+=1
		if row.phase!="available" and row.generation<1:return fail("Employed crew lacks recruitment")
		if row.hire_paid_credit!=row.generation*int(job.hire_fee_credit):return fail("Crew recruitment payment differs from generations")
		if row.loyalty<0 or row.loyalty>100 or row.experience<0 or row.experience>int(balance.experience_cap):return fail("Crew career exceeds bounds")
		var unit: float=float(job.contribution_per_xp)
		if not is_finite(row.contribution_total) or row.contribution_total<0 or row.contribution_total>float(balance.experience_cap)*unit:return fail("Invalid crew contribution total")
		if row.experience!=mini(int(balance.experience_cap),int(floor(row.contribution_total/unit))) or not is_finite(row.contribution_remainder) or absf(row.contribution_remainder-(row.contribution_total-row.experience*unit))>0.00001:return fail("Crew experience lacks matching contribution")
		if not is_finite(row.salary_elapsed_s) or row.salary_elapsed_s<0 or row.salary_elapsed_s>=float(balance.salary_period_s):return fail("Crew salary clock out of range")
		var quotes: Array[int]=[]
		for rank: Dictionary in catalog.rows("crew_rank_defs"):
			if rank.profession_id==profile.profession_id:quotes.append(int(ceil(float(job.salary_credit)*float(rank.salary_multiplier))))
		if row.generation>0 and row.salary_period_credit not in quotes:return fail("Crew salary quote is not an authored rank")
		if row.salary_periods<0 or float(row.salary_periods)*float(balance.salary_period_s)>float(tick)/hz+0.00001:return fail("Crew salary precedes actual world time")
		if row.unpaid_periods<0 or row.unpaid_periods>int(balance.arrears_period_limit) or row.arrears_credit<0 or row.arrears_credit>row.unpaid_periods*quotes.max():return fail("Crew arrears exceed bounded work")
		if row.salary_paid_credit<0 or row.salary_paid_credit+row.arrears_credit>row.salary_periods*quotes.max():return fail("Crew salary accounting exceeds elapsed periods")
		if row.treatment_paid_credit<0 or row.treatment_paid_credit%int(balance.injury_treatment_credit)!=0 or row.rest_paid_credit<0 or row.rest_paid_credit%int(balance.rest_credit)!=0:return fail("Crew treatment/leave payment is invalid")
		if not is_finite(row.recovery_remaining_s) or row.recovery_remaining_s<0:return fail("Crew recovery clock invalid")
		if row.phase in ["injured","resting"]:
			var limit: float=float(balance.injury_recovery_s if row.phase=="injured" else balance.rest_duration_s)
			if row.recovery_remaining_s<=0 or row.recovery_remaining_s>limit or not row.has_station_id:return fail("Crew recovery needs a real station and finite duration")
		elif row.recovery_remaining_s!=0:return fail("Recovered crew retains an active recovery timer")
		if row.has_station_id and catalog.one("station_defs","station_id",row.station_id).is_empty():return fail("Crew station is unknown")
		if row.generation==0 and (row.phase!="available" or row.experience!=0 or row.contribution_total!=0 or row.loyalty!=int(balance.loyalty_initial) or row.salary_paid_credit!=0 or row.salary_periods!=0 or row.arrears_credit!=0 or row.rest_paid_credit!=0 or row.treatment_paid_credit!=0):return fail("Unrecruited crew has invented career progress")
		members[row.profile_id]=row
	if members.size()!=catalog.rows("crew_profile_defs").size() or recruited>int(balance.max_recruited_crew):return fail("Crew roster coverage/capacity invalid")
	for a: RefCounted in state.rows("crew_assignment_state"):
		var row: RefCounted=members.get(a.profile_id);var ship: RefCounted=state.find("ship_state","ship_instance_id",a.ship_instance_id)
		if row==null or assignments.has(a.profile_id) or row.phase!="hired" or row.has_station_id:return fail("Crew assignment does not bind one employed member")
		if ship==null or ship.policy_id!="normal_owned" or ship.status not in [T.ShipStatus.DOCKED,T.ShipStatus.FLYING]:return fail("Crew assigned to an unavailable/protected hull")
		if a.profession_id!=catalog.one("crew_profile_defs","profile_id",a.profile_id).profession_id or a.assigned_tick<0 or a.assigned_tick>tick:return fail("Crew assignment profession/time invalid")
		var key: String=a.ship_instance_id+":"+a.profession_id
		if jobs.has(key):return fail("Duplicate crew profession on one hull")
		jobs[key]=true;assignments[a.profile_id]=a;slots[a.ship_instance_id]=int(slots.get(a.ship_instance_id,0))+1
		var hull: Dictionary=catalog.one("fleet_hull_defs","ship_id",ship.ship_def_id)
		if hull.is_empty() or int(slots[a.ship_instance_id])>int(hull.crew_slots):return fail("Crew exceeds real hull capacity")
	for id: String in members:
		var row: RefCounted=members[id]
		if row.phase=="available" and (row.has_station_id or assignments.has(id)):return fail("Available recruit retains an owned location")
		if row.phase!="available" and not assignments.has(id) and not row.has_station_id:return fail("Unassigned employed crew has no station")
	if state.rows("crew_receipt_state").size()>int(balance.history_limit):return fail("Crew history exceeds retention limit")
	for receipt: RefCounted in state.rows("crew_receipt_state"):
		var row: RefCounted=members.get(receipt.profile_id)
		if row==null or receipt.event_kind not in ["hire","dismiss","salary","arrears","injury","treatment","rest"] or receipt.paid_credit<0 or receipt.revision>row.revision or receipt.revision<0 or receipt.event_tick<0 or receipt.event_tick>tick:return fail("Crew receipt identity/time invalid")
	for quote: RefCounted in state.rows("crew_support_quote_state"):
		var member: RefCounted=members.get(quote.profile_id);var support: RefCounted=state.find("remote_support_state","item_instance_id",quote.item_instance_id)
		var job: Dictionary=catalog.one("crew_profession_defs","profession_id",quote.profession_id);var rank: Dictionary={}
		for definition: Dictionary in catalog.rows("crew_rank_defs"):
			if definition.profession_id==quote.profession_id and int(definition.rank)==quote.rank_at_payment:rank=definition;break
		if member==null or support==null or support.phase!="cycling" or job.get("effect_stat","")!="remote_repair_multiplier" or rank.is_empty() or member.experience<int(rank.experience_required) or quote.paid_tick<0 or quote.paid_tick>tick or quote.loyalty_at_payment<int(balance.loyalty_ready_min) or quote.loyalty_at_payment>100:return fail("Crew support quote identity or qualification invalid")
		var assignment: RefCounted=assignments.get(quote.profile_id)
		if assignment==null or assignment.ship_instance_id!=support.ship_instance_id or assignment.profession_id!=quote.profession_id:return fail("Crew support quote lacks its actual engineering assignment")
		if not is_finite(quote.restore_multiplier) or absf(quote.restore_multiplier-(1.0+float(rank.effect_value)*quote.loyalty_at_payment/100.0))>0.000001:return fail("Crew support quote exceeds its paid rank/loyalty")
	return true
