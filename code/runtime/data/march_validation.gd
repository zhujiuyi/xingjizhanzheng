extends RefCounted
const Space=preload("res://runtime/space_coordinates.gd")
var last_error: String=""

func fail(message: String) -> bool:last_error=message;return false

static func current_endpoint(catalog: XJCatalog,row: RefCounted) -> Dictionary:
	var index: int=row.completed_legs if row.direction==1 else row.completed_legs-1
	for leg: Dictionary in catalog.rows("march_route_defs"):
		if leg.war_id==row.war_id and int(leg.leg_index)==index:return catalog.one("gate_endpoint_defs","endpoint_id",leg.endpoint_id if row.direction==1 else leg.reverse_endpoint_id)
	return {}

static func allowed_sites(catalog: XJCatalog,war_id: String) -> Dictionary:
	var result: Dictionary={}
	var spec: Dictionary=catalog.one("march_campaign_defs","war_id",war_id)
	if spec.is_empty():return result
	var station: Dictionary=catalog.one("station_defs","station_id",spec.origin_station_id)
	for anchor: String in [str(station.undock_anchor_id),str(spec.destination_anchor_id)]:result[Space.site_for_anchor(catalog,anchor)]=true
	for leg: Dictionary in catalog.rows("march_route_defs"):
		if leg.war_id!=war_id:continue
		for id: String in [str(leg.endpoint_id),str(leg.reverse_endpoint_id)]:
			var endpoint: Dictionary=catalog.one("gate_endpoint_defs","endpoint_id",id)
			result[Space.site_for_anchor(catalog,str(endpoint.entry_anchor_id))]=true
			result[Space.site_for_anchor(catalog,str(endpoint.exit_anchor_id))]=true
	return result

static func actor_binding(state: XJRuntimeState,catalog: XJCatalog,id: String) -> bool:
	if not catalog.table_names.has("march_balance_defs"):return false
	var m: RefCounted=state.find("march_member_state","npc_instance_id",id)
	if m==null:return false
	var row: RefCounted=state.find("march_state","war_id",m.war_id)
	var war: RefCounted=state.find("war_campaign_state","war_id",m.war_id)
	var npc: RefCounted=state.find("npc_state","npc_instance_id",id)
	var fleet: RefCounted=state.find("war_fleet_state","npc_instance_id",id)
	if row==null or war==null or npc==null or fleet==null or fleet.side!="ally" or fleet.war_id!=m.war_id:return false
	var definition: Dictionary=catalog.one("civilization_war_members","spawn_id",npc.spawn_id)
	if definition.is_empty() or definition.war_id!=m.war_id or definition.side!="ally":return false
	return row.attempt==m.attempt and war.attempt==m.attempt and npc.generation==m.attempt and npc.spawn_id==m.spawn_id and npc.sector_id==m.sector_id and Space.site_for_entity(state,"npc",id)==m.site_id and allowed_sites(catalog,m.war_id).has(m.site_id)

func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("march_balance_defs"):
		for table: String in ["march_state","march_member_state","march_journal_state","growth_goal_state","growth_milestone_state","growth_grant_receipt_state"]:
			if not state.rows(table).is_empty():return fail("March/growth state under legacy definitions")
		return true
	for row: RefCounted in state.rows("march_state"):
		var war: RefCounted=state.find("war_campaign_state","war_id",row.war_id)
		var frontier: RefCounted=state.find("frontier_campaign_state","war_id",row.war_id)
		var spec: Dictionary=catalog.one("march_campaign_defs","war_id",row.war_id)
		if war==null or frontier==null or spec.is_empty() or war.attempt!=row.attempt or frontier.attempt!=row.attempt:return fail("March attempt has no matching funded campaign")
		var route_count: int=0
		for leg: Dictionary in catalog.rows("march_route_defs"):
			if leg.war_id==row.war_id:route_count+=1
		if row.completed_legs>route_count or row.initial_supply_units!=frontier.supplies_paid_units:return fail("March route or original supplies differ")
		var site: Dictionary=catalog.one("site_defs","site_id",row.site_id)
		if site.is_empty() or site.sector_id!=row.sector_id or not allowed_sites(catalog,row.war_id).has(row.site_id):return fail("March context is outside its actual itinerary")
		var terminal: bool=row.phase in ["returned","failed","cancelled","completed"]
		if terminal:
			var expected: String="cancelled" if row.phase=="returned" else "won" if row.phase=="completed" else str(row.phase)
			if war.status!=expected:return fail("Terminal march and war differ")
		elif war.status not in ["assembling","fighting","occupying"]:return fail("Active march under inactive war")
		var cargo: int=0;var count: int=0
		var endpoint: Dictionary=current_endpoint(catalog,row)
		if row.phase in ["gate_prepare","gate_transit"] and not row.has_gate_actor_id:return fail("Gate queue has no selected original actor")
		if row.has_gate_actor_id:
			var selected: RefCounted=state.find("march_member_state","npc_instance_id",row.gate_actor_id)
			if selected==null or selected.war_id!=row.war_id or selected.phase=="lost" or row.phase not in ["gate_prepare","gate_transit","blocked"]:return fail("Invalid selected gate actor")
			if (row.phase=="gate_transit")!=(selected.phase=="gate_transit"):return fail("Gate actor and transition clock differ")
		for m: RefCounted in state.rows("march_member_state"):
			if m.war_id!=row.war_id:continue
			count+=1;cargo+=m.cargo_units
			if not actor_binding(state,catalog,m.npc_instance_id) or m.ship_def_id!=spec.travel_hull_id:return fail("March member is not its original allied actor")
			var npc: RefCounted=state.find("npc_state","npc_instance_id",m.npc_instance_id)
			if m.completed_legs>route_count:return fail("Member route progress exceeds itinerary")
			if m.phase=="lost":
				if npc.alive or m.cargo_units!=0:return fail("Lost march member retains a ship or supplies")
			elif m.phase=="gate_wait":
				if endpoint.is_empty() or row.phase not in ["gate_prepare","gate_transit","blocked"] or not npc.alive or m.completed_legs!=row.completed_legs+row.direction or m.sector_id!=endpoint.target_sector_id or m.site_id!=Space.site_for_anchor(catalog,endpoint.exit_anchor_id):return fail("Gate exit member differs from the current queue")
			else:
				if not npc.alive or m.sector_id!=row.sector_id or m.site_id!=row.site_id or m.completed_legs!=row.completed_legs:return fail("Living march member differs from party context")
				if m.phase=="gate_transit" and (row.phase!="gate_transit" or not row.has_gate_actor_id or row.gate_actor_id!=m.npc_instance_id):return fail("Unselected member is in gate transit")
			if m.cargo_units>0 and m.spawn_id!=spec.supply_carrier_spawn_id:return fail("March cargo changed carriers without handoff")
		if row.initial_supply_units!=cargo+row.returned_supply_units+row.lost_supply_units+row.transferred_supply_units:return fail("March supplies are not conserved")
		var expected_count: int=0
		for member: Dictionary in catalog.rows("civilization_war_members"):
			if member.war_id==row.war_id and member.side=="ally":expected_count+=1
		if count!=(0 if terminal else expected_count):return fail("March original roster is incomplete")
		if row.phase=="arrived" and (row.completed_legs!=route_count or row.direction!=1 or row.sector_id!=catalog.one("anchor_defs","anchor_id",spec.destination_anchor_id).sector_id):return fail("March declared arrival before its route completed")
		if row.phase=="returned" and (row.completed_legs!=0 or row.direction!=-1 or row.sector_id!=catalog.one("station_defs","station_id",spec.origin_station_id).sector_id):return fail("March declared return outside its capital")
	for m: RefCounted in state.rows("march_member_state"):
		if state.find("march_state","war_id",m.war_id)==null:return fail("Orphan march member")
	if state.rows("growth_goal_state").size()>1:return fail("Multiple local growth selections")
	for goal: RefCounted in state.rows("growth_goal_state"):
		if goal.player_id!=state.player().player_id or goal.selected_tick>state.snapshot.meta.simulation_tick:return fail("Growth goal owner or time differs")
		if goal.has_stage_id:
			var stage: Dictionary=catalog.one("growth_stage_defs","stage_id",goal.stage_id)
			if stage.is_empty() or (stage.faction_id!=null and (not goal.has_faction_id or stage.faction_id!=goal.faction_id)):return fail("Growth goal belongs to another civilization")
	for milestone: RefCounted in state.rows("growth_milestone_state"):
		if catalog.one("growth_stage_defs","stage_id",milestone.stage_id).is_empty() or milestone.observed_tick>state.snapshot.meta.simulation_tick:return fail("Growth milestone identity or time differs")
	for receipt: RefCounted in state.rows("growth_grant_receipt_state"):
		var grant: Dictionary=catalog.one("growth_grant_defs","task_id",receipt.task_id)
		var task: Dictionary=catalog.one("civilization_honor_task_defs","task_id",receipt.task_id)
		if grant.is_empty() or task.is_empty() or task.faction_id!=receipt.faction_id or receipt.paid_credit!=int(grant.reward_credit) or receipt.awarded_reputation!=int(grant.reward_reputation) or receipt.claimed_tick>state.snapshot.meta.simulation_tick:return fail("Growth grant differs from its frozen award")
		var units: int=0
		for evidence: RefCounted in state.rows("civilization_honor_evidence_state"):
			if evidence.task_id==receipt.task_id:units+=evidence.credited_units
		if units<int(task.required_units):return fail("Growth grant lacks actual capability proof")
	return true
