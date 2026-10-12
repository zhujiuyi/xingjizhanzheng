extends RefCounted
## Check pure snapshots before scene staging; SQL sealing repeats durable guards.
var last_error: String=""
const TABLES: Array[String]=["construction_state","construction_input_state","construction_receipt_state","construction_evidence_state","expedition_route_state","expedition_run_state","expedition_stage_state","expedition_receipt_state","campaign_director_state","flight_record_state","telemetry_total_state","flight_material_state","telemetry_material_state","flight_repair_state","telemetry_repair_state"]
func _fail(message: String) -> bool:last_error=message;return false
func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("campaign_balance_defs"):
		for table: String in TABLES:
			if not state.rows(table).is_empty():return _fail("Campaign state under legacy definitions")
		return true
	var tick: int=state.snapshot.meta.simulation_tick
	var policy: Dictionary=catalog.rows("campaign_balance_defs")[0]
	if state.rows("campaign_director_state").size()!=1 or state.rows("telemetry_total_state").size()!=1:return _fail("Missing campaign director or measured totals")
	var director: RefCounted=state.rows("campaign_director_state")[0]
	if director.singleton!=1 or director.generation<1 or director.focus_index<0 or director.focus_index>2 or not is_finite(director.remaining_s) or director.remaining_s<0 or director.remaining_s>float(policy.director_period_s):return _fail("Invalid world-time rotation")
	var projects: Dictionary={};var inputs: Dictionary={};var paid: Dictionary={};var receipt_ids: Dictionary={};var starts: Dictionary={}
	for row: RefCounted in state.rows("construction_receipt_state"):
		var key: String="%s:%d" % [row.project_id,row.stage_index]
		var spec: Dictionary={}
		for def: Dictionary in catalog.rows("construction_stage_defs"):
			if def.project_id==row.project_id and int(def.stage_index)==row.stage_index:spec=def;break
		if spec.is_empty() or receipt_ids.has(row.receipt_id) or row.event_tick<0 or row.event_tick>tick or catalog.one("station_defs","station_id",row.station_id).is_empty():return _fail("Invalid construction receipt identity")
		receipt_ids[row.receipt_id]=true
		if row.action_kind=="start":
			if starts.has(key) or row.paid_credit!=int(spec.fee_credit) or row.has_item_id or row.units!=0:return _fail("Duplicate or invalid construction payment")
			starts[key]=true;paid[row.project_id]=int(paid.get(row.project_id,0))+row.paid_credit
		elif row.action_kind=="deliver":
			if not row.has_item_id or row.units<=0 or row.paid_credit!=0:return _fail("Invalid material delivery receipt")
			var matching: bool=false
			for def: Dictionary in catalog.rows("construction_input_defs"):
				if def.project_id==row.project_id and int(def.stage_index)==row.stage_index and def.item_id==row.item_id and def.delivery_station_id==row.station_id:matching=true;break
			if not matching:return _fail("Construction delivery at wrong collection station")
			key+="|"+row.item_id+"|"+row.station_id;inputs[key]=int(inputs.get(key,0))+row.units
		else:return _fail("Unknown construction receipt")
	var input_seen: Dictionary={}
	for row: RefCounted in state.rows("construction_input_state"):
		var key: String="%s:%d|%s|%s" % [row.project_id,row.stage_index,row.item_id,row.delivery_station_id]
		var spec: Dictionary={}
		for def: Dictionary in catalog.rows("construction_input_defs"):
			if def.project_id==row.project_id and int(def.stage_index)==row.stage_index and def.item_id==row.item_id and def.delivery_station_id==row.delivery_station_id:spec=def;break
		if spec.is_empty() or input_seen.has(key) or row.delivered_units<0 or row.delivered_units>int(spec.required_units) or row.delivered_units!=int(inputs.get(key,0)):return _fail("Construction material ledger differs from finite receipts")
		input_seen[key]=true
	if input_seen.size()!=catalog.rows("construction_input_defs").size():return _fail("Incomplete construction input coverage")
	for row: RefCounted in state.rows("construction_state"):
		var spec: Dictionary=catalog.one("construction_project_defs","project_id",row.project_id)
		if spec.is_empty() or projects.has(row.project_id) or row.stage_index<1 or row.stage_index>3 or row.phase not in ["gathering","working","completed"]:return _fail("Invalid construction stage")
		projects[row.project_id]=true
		if row.revision<0 or row.completed_tick<0 or row.completed_tick>tick or not is_finite(row.work_remaining_s) or row.work_remaining_s<0 or row.paid_credit_total!=int(paid.get(row.project_id,0)):return _fail("Invalid construction timers or expense")
		for index: int in range(1,row.stage_index):
			if not starts.has("%s:%d" % [row.project_id,index]):return _fail("Construction skipped an unpaid stage")
		if row.phase in ["working","completed"] and not starts.has("%s:%d" % [row.project_id,row.stage_index]):return _fail("Unpaid construction work")
		if row.phase=="gathering" and row.work_remaining_s!=0:return _fail("Gathering construction has work timer")
		if row.phase=="completed" and (row.stage_index!=3 or row.work_remaining_s!=0):return _fail("Invalid completed construction")
	if projects.size()!=catalog.rows("construction_project_defs").size():return _fail("Incomplete construction projects")
	var proof_seen: Dictionary={}
	for row: RefCounted in state.rows("construction_evidence_state"):
		var binding: Dictionary=catalog.one("campaign_event_defs","event_id",row.event_id)
		var claim: RefCounted=null
		for r: RefCounted in state.rows("exploration_claim_state"):
			if r.event_id==row.event_id and r.generation==row.generation:claim=r;break
		var key: String="%s:%d" % [row.event_id,row.generation]
		if binding.is_empty() or claim==null or row.player_id!=claim.player_id or row.project_id!=str(binding.project_id) or proof_seen.has(key) or row.units!=int(binding.full_units if claim.outcome=="full" else binding.partial_units):return _fail("Construction evidence lacks a unique actual claim")
		proof_seen[key]=true
	var route_seen: Dictionary={}
	for row: RefCounted in state.rows("expedition_route_state"):
		var spec: Dictionary=catalog.one("expedition_route_defs","route_id",row.route_id)
		if spec.is_empty() or route_seen.has(row.route_id) or row.completed_runs<0 or row.withdrawn_runs<0 or not is_finite(row.cooldown_remaining_s) or row.cooldown_remaining_s<0 or row.cooldown_remaining_s>float(spec.cooldown_s):return _fail("Invalid expedition availability")
		route_seen[row.route_id]=true
	if route_seen.size()!=catalog.rows("expedition_route_defs").size():return _fail("Incomplete expedition routes")
	var runs: Dictionary={};var active_count: int=0
	for row: RefCounted in state.rows("expedition_run_state"):
		var spec: Dictionary=catalog.one("expedition_route_defs","route_id",row.route_id)
		if spec.is_empty() or runs.has(row.run_id) or row.stage_index<1 or row.stage_index>3 or row.phase not in ["active","checkpoint","returning","completed","withdrawn","failed"] or row.fee_paid_credit!=int(spec.start_fee_credit) or row.focus_bonus_bp not in [10000,int(policy.focus_bonus_bp)]:return _fail("Invalid accepted expedition")
		if row.started_tick<0 or row.started_tick>tick or row.finished_tick<0 or row.finished_tick>tick:return _fail("Invalid expedition time")
		if row.phase in ["active","checkpoint","returning"]:
			active_count+=1
			if row.finished_tick!=0:return _fail("Unfinished expedition has terminal time")
		elif row.finished_tick<row.started_tick:return _fail("Expedition finished before acceptance")
		runs[row.run_id]=row
	if active_count>1:return _fail("Multiple active expeditions")
	var stage_seen: Dictionary={};var counts: Dictionary={};var credits: Dictionary={};var insights: Dictionary={}
	for row: RefCounted in state.rows("expedition_stage_state"):
		var run: RefCounted=runs.get(row.run_id)
		var option: Dictionary={}
		for def: Dictionary in catalog.rows("expedition_option_defs"):
			if run!=null and def.route_id==run.route_id and int(def.stage_index)==row.stage_index and def.option_id==row.option_id:option=def;break
		var key: String="%s:%d" % [row.run_id,row.stage_index]
		if option.is_empty() or run==null or stage_seen.has(key) or row.stage_index>run.stage_index or row.event_id!=str(option.event_id) or row.event_generation<1:return _fail("Invalid expedition option or stage ordering")
		stage_seen[key]=row;counts[row.run_id]=int(counts.get(row.run_id,0))+1
		if row.settled:
			var claim: RefCounted=null
			for r: RefCounted in state.rows("exploration_claim_state"):
				if r.event_id==row.event_id and r.generation==row.event_generation:claim=r;break
			if claim==null or row.outcome!=claim.outcome:return _fail("Expedition settlement without actual exploration claim")
			var multiplier: float=float(run.focus_bonus_bp)/10000.0*(1.0 if claim.outcome=="full" else float(policy.partial_bonus_bp)/10000.0)
			if row.bonus_credit!=int(floor(float(option.bonus_credit)*multiplier)) or row.bonus_insight!=int(floor(float(option.bonus_insight)*multiplier)):return _fail("Expedition coordination reward differs from accepted rules")
		elif row.outcome!="" or row.bonus_credit!=0 or row.bonus_insight!=0:return _fail("Unsettled expedition produced coordination rewards")
		credits[row.run_id]=int(credits.get(row.run_id,0))+row.bonus_credit;insights[row.run_id]=int(insights.get(row.run_id,0))+row.bonus_insight
	for id: String in runs:
		var run: RefCounted=runs[id]
		if int(counts.get(id,0))!=run.stage_index or run.bonus_credit_total!=int(credits.get(id,0)) or run.bonus_insight_total!=int(insights.get(id,0)):return _fail("Expedition stages or totals incomplete")
		var current: RefCounted=stage_seen["%s:%d" % [id,run.stage_index]]
		if run.phase=="checkpoint" and (not current.settled or run.stage_index>=3 or run.withdraw_requested):return _fail("Invalid expedition checkpoint")
		if run.phase=="completed" and (run.stage_index!=3 or not current.settled):return _fail("Incomplete expedition marked completed")
	var total: RefCounted=state.rows("telemetry_total_state")[0];var record_seen: Dictionary={};var sequences: Dictionary={};active_count=0
	if total.singleton!=1 or total.next_sequence<1 or total.wallet_last<0:return _fail("Invalid measured totals identity")
	if state.rows("flight_record_state").size()>int(policy.report_limit):return _fail("Too many retained outing reports")
	for row: RefCounted in state.rows("flight_record_state"):
		if record_seen.has(row.record_id) or sequences.has(row.sequence) or row.sequence<1 or row.sequence>=total.next_sequence or catalog.one("ship_defs","ship_id",row.ship_def_id).is_empty() or row.phase not in ["active","docked","lost"]:return _fail("Invalid outing report identity")
		record_seen[row.record_id]=true;sequences[row.sequence]=true
		if row.started_tick<0 or row.started_tick>tick or row.finished_tick<0 or row.finished_tick>tick or row.credit_last!=row.credit_start+row.flight_income+row.return_income-row.flight_spent-row.return_spent:return _fail("Invalid outing time or wallet reconciliation")
		if row.phase=="active":
			active_count+=1
			if row.finished_tick!=0:return _fail("Active outing has terminal time")
		elif row.finished_tick<row.started_tick:return _fail("Outing ended before departure")
		for key: String in ["elapsed_s","combat_s","transit_s","damage_dealt","damage_taken"]:
			if not is_finite(row.get(key)) or float(row.get(key))<0:return _fail("Invalid measured scalar")
		if row.combat_s>row.elapsed_s or row.transit_s>row.elapsed_s:return _fail("Measured activity time exceeds outing")
	if active_count>1:return _fail("Multiple measured active outings")
	var material_totals: Dictionary={};var material_seen: Dictionary={}
	for row: RefCounted in state.rows("telemetry_material_state"):
		if material_totals.has(row.item_id) or catalog.one("item_defs","item_id",row.item_id).is_empty() or row.used_units<0 or row.returned_units<0:return _fail("Invalid measured material total")
		material_totals[row.item_id]=row
	var used: Dictionary={};var returned: Dictionary={}
	for row: RefCounted in state.rows("flight_material_state"):
		var key: String=row.record_id+"|"+row.item_id
		if not record_seen.has(row.record_id) or not material_totals.has(row.item_id) or material_seen.has(key) or row.used_units<0 or row.returned_units<0:return _fail("Invalid outing material record")
		material_seen[key]=true;used[row.item_id]=int(used.get(row.item_id,0))+row.used_units;returned[row.item_id]=int(returned.get(row.item_id,0))+row.returned_units
	for id: String in material_totals:
		if material_totals[id].used_units<int(used.get(id,0)) or material_totals[id].returned_units<int(returned.get(id,0)):return _fail("Material totals below retained outings")
	var repair_totals: Dictionary={};var repair_seen: Dictionary={};var measured: Dictionary={}
	for row: RefCounted in state.rows("telemetry_repair_state"):
		if row.repair_kind not in ["self","provided","received","station"] or repair_totals.has(row.repair_kind) or not is_finite(row.restored_hp) or row.restored_hp<=0:return _fail("Invalid measured repair total")
		repair_totals[row.repair_kind]=row.restored_hp
	for row: RefCounted in state.rows("flight_repair_state"):
		var key: String=row.record_id+"|"+row.repair_kind
		if not record_seen.has(row.record_id) or not repair_totals.has(row.repair_kind) or repair_seen.has(key) or not is_finite(row.restored_hp) or row.restored_hp<=0:return _fail("Invalid outing repair record")
		repair_seen[key]=true;measured[row.repair_kind]=float(measured.get(row.repair_kind,0.0))+row.restored_hp
	for kind: String in measured:
		if float(measured[kind])>float(repair_totals[kind])+0.00001:return _fail("Repair totals below retained outings")
	return true
