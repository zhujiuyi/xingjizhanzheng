extends RefCounted
var last_error: String=""
const T=preload("res://contracts/contract_types.gd")
const Journal=preload("res://runtime/gameplay/journal.gd")
const TABLES: Array[String]=["trial_state","trial_result_state","scenario_actor_state","tactical_award_state","blockade_state","blockade_node_state","blockade_result_state","telemetry_source_state","activity_record_state","telemetry_menu_state","telemetry_timing_state","activity_total_state"]
func fail(message: String) -> bool:last_error=message;return false
func finite(row: RefCounted,fields: Array[String]) -> bool:
	for field: String in fields:
		if not is_finite(float(row.get(field))) or float(row.get(field))<0:return false
	return true
func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("trial_defs"):
		for table: String in TABLES:
			if not state.rows(table).is_empty():return fail("Scenario state under legacy rules")
		return true
	var tick: int=state.snapshot.meta.simulation_tick
	if state.rows("trial_state").size()!=catalog.rows("trial_defs").size() or state.rows("blockade_state").size()!=catalog.rows("blockade_defs").size() or state.rows("blockade_node_state").size()!=catalog.rows("blockade_node_defs").size():return fail("Scenario definition coverage incomplete")
	var trials: Dictionary={};var blocks: Dictionary={};var results: Dictionary={};var trial_wins: Dictionary={};var awards: Dictionary={};var active: int=0
	for row: RefCounted in state.rows("trial_state"):
		var d: Dictionary=catalog.one("trial_defs","trial_id",row.trial_id)
		if d.is_empty() or trials.has(row.trial_id) or row.phase not in ["available","accepted","active","ready","completed","failed","withdrawn"] or row.generation<0:return fail("Invalid trial identity or phase")
		if (row.phase=="available")!=(row.generation==0):return fail("Invalid initial trial generation")
		if not finite(row,["remaining_s","elapsed_s","effective_hp","best_elapsed_s","cooldown_remaining_s"]) or row.remaining_s>float(d.duration_s) or row.cooldown_remaining_s>float(d.cooldown_s):return fail("Invalid trial time")
		if row.reference_cost<0 or row.reference_cost>int(d.budget_credit) or row.paid_credit_total!=row.generation*int(d.fee_credit) or row.wins<0:return fail("Trial budget or fee differs from catalog")
		if row.phase in ["accepted","active","ready"]:
			active+=1
			var ship: RefCounted=state.find("ship_state","ship_instance_id",row.ship_instance_id)
			if not row.has_ship_instance_id or ship==null or ship.policy_id!="normal_owned" or not catalog.rows("trial_hull_defs").any(func(h: Dictionary):return h.trial_id==row.trial_id and h.ship_id==ship.ship_def_id):return fail("Trial ship binding unavailable")
			if row.loadout_signature.length()!=64:return fail("Trial equipment binding missing")
		trials[row.trial_id]=row
	for row: RefCounted in state.rows("trial_result_state"):
		var d: Dictionary=catalog.one("trial_defs","trial_id",row.trial_id);var key: String=row.trial_id+":"+str(row.generation)
		if d.is_empty() or results.has(key) or not trials.has(row.trial_id) or row.generation<1 or row.generation>trials[row.trial_id].generation or row.outcome not in ["completed","failed","withdrawn"]:return fail("Invalid trial result generation")
		if row.reference_cost<=0 or row.reference_cost>int(d.budget_credit) or row.paid_credit!=int(d.fee_credit) or row.finished_tick<0 or row.finished_tick>tick or not catalog.rows("trial_hull_defs").any(func(h: Dictionary):return h.trial_id==row.trial_id and h.ship_id==row.ship_def_id):return fail("Invalid trial result budget or hull")
		if row.reason_code not in Journal.REASONS:return fail("Unrecognized trial reason")
		if not finite(row,["elapsed_s","effective_hp"]) or row.elapsed_s>float(d.duration_s)+1:return fail("Invalid trial result measurement")
		if row.outcome=="completed":
			if d.objective_kind in ["precision","support"] and row.effective_hp<float(d.target_hp):return fail("Trial success lacks effective contribution")
			trial_wins[row.trial_id]=int(trial_wins.get(row.trial_id,0))+1;awards[d.award_id]=true
		results[key]=row
	for id: String in trials:
		var row: RefCounted=trials[id]
		var count: int=0
		for result: RefCounted in state.rows("trial_result_state"):
			if result.trial_id==id:count+=1
		if count!=row.generation-(1 if row.phase in ["accepted","active","ready"] else 0):return fail("Trial attempt results incomplete")
		if row.wins!=int(trial_wins.get(id,0)):return fail("Trial win total lacks results")
		if row.generation>0:
			var last: RefCounted=results.get(id+":"+str(row.generation))
			if (row.phase in ["completed","failed","withdrawn"])!=(last!=null):return fail("Trial terminal result missing or premature")
	var block_results: Dictionary={};var units: Dictionary={};var rewards: Dictionary={}
	for row: RefCounted in state.rows("blockade_state"):
		var d: Dictionary=catalog.one("blockade_defs","blockade_id",row.blockade_id)
		if d.is_empty() or blocks.has(row.blockade_id) or row.generation<0 or row.phase not in ["available","accepted","active","ready","claimed","failed","withdrawn"]:return fail("Invalid blockade identity or phase")
		if (row.phase=="available")!=(row.generation==0):return fail("Invalid initial blockade generation")
		if row.loaded_units<0 or row.loaded_units>int(d.target_units) or mini(row.cargo_units,mini(row.completed_units,mini(row.lost_units,row.jettisoned_units)))<0 or row.loaded_units!=row.cargo_units+row.completed_units+row.lost_units+row.jettisoned_units:return fail("Blockade cargo conservation failed")
		if not finite(row,["remaining_s","elapsed_s","bypass_remaining_s","damage_debt_hp","scan_remaining_s","cooldown_remaining_s"]) or row.remaining_s>float(d.duration_s) or row.bypass_remaining_s>float(d.bypass_window_s) or row.cooldown_remaining_s>float(d.cooldown_s):return fail("Invalid blockade timer")
		if row.paid_credit_total!=row.generation*int(d.fee_credit):return fail("Blockade acceptance fee mismatch")
		if row.phase in ["accepted","active","ready"]:active+=1
		if row.phase=="active":
			var ship: RefCounted=state.find("ship_state","ship_instance_id",row.payload_ship_id)
			if not row.has_payload_ship_id or ship==null or ship.policy_id!="normal_owned" or ship.ship_instance_id!=state.ship().ship_instance_id or ship.status!=T.ShipStatus.FLYING:return fail("Blockade carrying ship unavailable")
		elif row.has_payload_ship_id or row.cargo_units!=0 or row.has_scan_node_index or row.scan_remaining_s!=0:return fail("Inactive blockade retains active cargo or scan")
		blocks[row.blockade_id]=row
	if active>1:return fail("Multiple accepted tactical scenarios")
	for row: RefCounted in state.rows("blockade_result_state"):
		var d: Dictionary=catalog.one("blockade_defs","blockade_id",row.blockade_id);var key: String=row.blockade_id+":"+str(row.generation)
		if d.is_empty() or block_results.has(key) or not blocks.has(row.blockade_id) or row.generation<1 or row.generation>blocks[row.blockade_id].generation or row.outcome not in ["claimed","failed","withdrawn"]:return fail("Invalid blockade result generation")
		if row.loaded_units<0 or row.loaded_units>int(d.target_units) or mini(row.delivered_units,mini(row.lost_units,row.jettisoned_units))<0 or row.loaded_units!=row.delivered_units+row.lost_units+row.jettisoned_units:return fail("Invalid settled blockade cargo")
		if row.paid_credit!=int(d.fee_credit) or row.reward_credit!=row.delivered_units*int(d.credit_per_unit) or row.finished_tick<0 or row.finished_tick>tick or not finite(row,["elapsed_s"]):return fail("Invalid blockade settlement payment")
		if row.outcome!="claimed" and row.delivered_units!=0:return fail("Failed blockade produced delivery")
		if row.reason_code not in Journal.REASONS:return fail("Unrecognized blockade reason")
		units[row.blockade_id]=int(units.get(row.blockade_id,0))+row.delivered_units;rewards[row.blockade_id]=int(rewards.get(row.blockade_id,0))+row.reward_credit
		if row.delivered_units==int(d.target_units):awards[d.award_id]=true
		block_results[key]=row
	for id: String in blocks:
		var row: RefCounted=blocks[id]
		var count: int=0
		for result: RefCounted in state.rows("blockade_result_state"):
			if result.blockade_id==id:count+=1
		if count!=row.generation-(1 if row.phase in ["accepted","active","ready"] else 0):return fail("Blockade attempt results incomplete")
		if row.rewarded_units_total!=int(units.get(id,0)) or row.reward_credit_total!=int(rewards.get(id,0)):return fail("Blockade cumulative rewards lack receipts")
		if row.generation>0 and ((row.phase in ["claimed","failed","withdrawn"])!=block_results.has(id+":"+str(row.generation))):return fail("Blockade terminal result missing or premature")
	var node_keys: Dictionary={}
	for row: RefCounted in state.rows("blockade_node_state"):
		var key: String=row.blockade_id+":"+str(row.node_index);var d: Dictionary={}
		for candidate: Dictionary in catalog.rows("blockade_node_defs"):
			if candidate.blockade_id==row.blockade_id and int(candidate.node_index)==row.node_index:d=candidate;break
		if d.is_empty() or node_keys.has(key) or not blocks.has(row.blockade_id) or row.generation!=blocks[row.blockade_id].generation:return fail("Invalid blockade node generation")
		node_keys[key]=true
	var actor_keys: Dictionary={}
	for row: RefCounted in state.rows("scenario_actor_state"):
		var npc: RefCounted=state.find("npc_state","npc_instance_id",row.npc_instance_id);var d: Dictionary=catalog.one("trial_actor_defs" if row.scenario_kind=="trial" else "blockade_actor_defs","spawn_id",row.spawn_id)
		var parent: RefCounted=trials.get(row.scenario_id) if row.scenario_kind=="trial" else blocks.get(row.scenario_id)
		if npc==null or d.is_empty() or parent==null or parent.phase!="active" or actor_keys.has(row.npc_instance_id) or npc.spawn_id!=row.spawn_id or npc.generation!=row.generation or parent.generation!=row.generation or row.actor_role!=d.actor_role:return fail("Invalid managed scenario actor")
		if str(d.get("trial_id",d.get("blockade_id","")))!=row.scenario_id:return fail("Scenario actor ownership mismatch")
		actor_keys[row.npc_instance_id]=true
	for kind: String in ["trial","blockade"]:
		for parent: RefCounted in state.rows(kind+"_state"):
			if parent.phase!="active":continue
			for d: Dictionary in catalog.rows(kind+"_actor_defs"):
				if d.get(kind+"_id")!=parent.get(kind+"_id"):continue
				var matches: int=0
				for member: RefCounted in state.rows("scenario_actor_state"):
					if member.scenario_kind==kind and member.scenario_id==parent.get(kind+"_id") and member.generation==parent.generation and member.spawn_id==d.spawn_id:matches+=1
				if matches!=1:return fail("Active scenario actor coverage incomplete")
	var seen_awards: Dictionary={};var selected: int=0
	for row: RefCounted in state.rows("tactical_award_state"):
		if seen_awards.has(row.award_id) or not awards.has(row.award_id) or row.earned_tick<0 or row.earned_tick>tick:return fail("Tactical award lacks a full success")
		seen_awards[row.award_id]=true
		if row.selected:selected+=1
	if selected>1:return fail("Multiple selected tactical titles")
	for id: String in trials:
		if trials[id].award_earned!=seen_awards.has(catalog.one("trial_defs","trial_id",id).award_id):return fail("Trial award flag mismatch")
	for id: String in blocks:
		if blocks[id].award_earned!=seen_awards.has(catalog.one("blockade_defs","blockade_id",id).award_id):return fail("Blockade award flag mismatch")
	return measurements(state,catalog)
func measurements(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	var policy: Dictionary=catalog.rows("telemetry_policy_defs")[0];var tick: int=state.snapshot.meta.simulation_tick;var seen: Dictionary={}
	for row: RefCounted in state.rows("telemetry_source_state"):
		var key: String=row.item_id+":"+row.source_kind
		if seen.has(key) or row.units<=0 or row.source_kind not in ["mining","manufacture","mission","salvage","purchase"] or catalog.one("item_defs","item_id",row.item_id).is_empty():return fail("Invalid acquired material measurement")
		seen[key]=true
	var totals: Dictionary={};var counts: Dictionary={};var times: Dictionary={}
	for row: RefCounted in state.rows("activity_total_state"):
		var key: String=row.activity_kind+":"+row.outcome+":"+row.reason_code
		if totals.has(key) or row.occurrences<=0 or not finite(row,["elapsed_s"]) or row.activity_kind not in Journal.KINDS or row.outcome not in Journal.OUTCOMES or row.reason_code not in Journal.REASONS:return fail("Invalid activity totals")
		totals[key]=row
	var ids: Dictionary={};var open: Dictionary={};var finished: int=0
	for row: RefCounted in state.rows("activity_record_state"):
		if row.activity_kind not in Journal.KINDS or (row.phase=="finished" and (row.outcome not in Journal.OUTCOMES or row.reason_code not in Journal.REASONS)):return fail("Unrecognized activity type or result")
		if ids.has(row.record_id) or row.phase not in ["active","finished"] or row.object_id.is_empty() or row.started_tick<0 or row.started_tick>tick or row.finished_tick<0 or row.finished_tick>tick or not finite(row,["elapsed_s"]):return fail("Invalid activity record")
		ids[row.record_id]=true
		if row.phase=="active":
			var key: String=row.activity_kind+":"+row.object_id
			if open.has(key) or not row.outcome.is_empty() or not row.reason_code.is_empty() or row.finished_tick!=0:return fail("Duplicate or settled open activity")
			open[key]=true
		else:
			var key: String=row.activity_kind+":"+row.outcome+":"+row.reason_code
			if not totals.has(key) or row.finished_tick<row.started_tick:return fail("Activity outcome lacks measured totals")
			finished+=1;counts[key]=int(counts.get(key,0))+1;times[key]=float(times.get(key,0))+row.elapsed_s
	if finished>int(policy.record_limit):return fail("Unbounded retained activity history")
	for key: String in counts:
		if totals[key].occurrences<int(counts[key]) or totals[key].elapsed_s+0.00001<float(times[key]):return fail("Activity totals below retained history")
	seen.clear()
	for row: RefCounted in state.rows("telemetry_menu_state"):
		if seen.has(row.page_id) or row.page_id not in Journal.PAGES or row.visits<0 or not finite(row,["duration_s"]):return fail("Invalid focused menu measurement")
		seen[row.page_id]=true
	if state.rows("telemetry_timing_state").size()!=1 or state.rows("telemetry_timing_state")[0].singleton!=1 or not finite(state.rows("telemetry_timing_state")[0],["navigation_wait_s"]):return fail("Invalid navigation timing singleton")
	return true
