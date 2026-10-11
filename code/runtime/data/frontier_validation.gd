extends RefCounted
var last_error: String=""
const GROUPS: Array[String]=["frontier_campaign_state","frontier_actor_state","frontier_campaign_receipt_state","frontier_territory_state","frontier_journal_state","frontier_supply_order_state","frontier_director_state"]

func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("frontier_campaign_defs"):
		for table: String in GROUPS:
			if not state.rows(table).is_empty():return _fail("Frontier state under legacy rules")
		return true
	var b: Dictionary=catalog.rows("frontier_balance_defs")[0]
	if state.rows("frontier_campaign_state").size()!=catalog.rows("frontier_campaign_defs").size() or state.rows("frontier_territory_state").size()!=catalog.rows("frontier_governance_defs").size() or state.rows("frontier_director_state").size()!=1:return _fail("Frontier coverage incomplete")
	var wars: Dictionary={};var territories: Dictionary={};var receipts: Dictionary={};var journals: Dictionary={};var actor_ids: Dictionary={}
	for r: RefCounted in state.rows("frontier_campaign_receipt_state"):
		if receipts.has(r.source_token) or catalog.one("frontier_campaign_defs","war_id",r.war_id).is_empty() or r.attempt<1 or r.event_tick<0 or r.event_tick>state.snapshot.meta.simulation_tick or r.units<0 or r.material_units<0:return _fail("Invalid frontier campaign receipt")
		receipts[r.source_token]=r
		if r.event_kind not in ["register","survey","supply","structure","hold","repair","capture","failed","cancelled"]:return _fail("Unknown frontier receipt kind")
		if (r.event_kind=="register" and r.material_units!=int(b.supply_units)) or (r.event_kind=="repair" and r.material_units!=int(b.rebuild_units)):return _fail("Invalid frontier material payment")
	for r: RefCounted in state.rows("frontier_campaign_state"):
		var def: Dictionary=catalog.one("frontier_campaign_defs","war_id",r.war_id)
		if def.is_empty() or wars.has(r.war_id):return _fail("Invalid frontier campaign identity")
		wars[r.war_id]=r
		if r.phase not in ["idle","legacy","scouting","escorting","hold","demolition","rebuilding","completed","failed","cancelled"] or r.attempt<0 or r.legacy_attempt<0 or r.legacy_attempt>r.attempt:return _fail("Invalid frontier phase or attempt")
		if r.survey_remaining_s<0.0 or r.survey_remaining_s>float(b.survey_s) or r.repair_remaining_s<0.0 or r.repair_remaining_s>float(b.rebuild_s) or r.hold_remaining_s<0.0 or r.hold_remaining_s>float(b.hold_s) or r.demolition_units<0 or r.demolition_units>int(def.structure_count):return _fail("Invalid frontier work or objective progress")
		var paid: int=0;var repaired: int=0;var structures: int=0;var single: Dictionary={}
		for e: RefCounted in receipts.values():
			if e.war_id!=r.war_id or e.attempt!=r.attempt:continue
			if e.event_kind!="structure":
				if single.has(e.event_kind):return _fail("Repeated frontier phase receipt")
				single[e.event_kind]=true
			if e.event_kind=="register":paid+=e.material_units
			elif e.event_kind=="repair":repaired+=e.material_units
			elif e.event_kind=="structure":structures+=e.units
		if r.supplies_paid_units!=paid or r.repair_paid_units!=repaired or r.demolition_units!=structures:return _fail("Frontier paid work conservation failed")
		var war: RefCounted=state.find("war_campaign_state","war_id",r.war_id)
		if r.phase=="idle":
			if r.attempt!=0 or war!=null or paid!=0 or repaired!=0:return _fail("Idle frontier has an accepted campaign")
		else:
			if war==null or war.attempt!=r.attempt:return _fail("Frontier campaign missing ordinary authority")
			if r.legacy_attempt==r.attempt:
				if paid!=0 or repaired!=0 or r.phase not in ["legacy","completed","failed","cancelled"]:return _fail("Legacy frontier exemption changed its activity")
			else:
				if paid!=int(b.supply_units):return _fail("New frontier campaign lacks paid supplies")
				if r.phase in ["escorting","hold","demolition","rebuilding","completed"] and not single.has("survey"):return _fail("Frontier phase skipped real survey")
				if r.phase in ["hold","demolition","rebuilding","completed"] and (not r.supply_delivered or not single.has("supply")):return _fail("Frontier phase skipped actual escort delivery")
				if r.phase=="completed" and (repaired!=int(b.rebuild_units) or r.repair_remaining_s!=0.0 or not single.has("capture") or war.status!="won"):return _fail("Frontier victory lacks paid reconstruction")
	for r: RefCounted in state.rows("frontier_territory_state"):
		var def: Dictionary=catalog.one("frontier_governance_defs","sector_id",r.sector_id);var owner: RefCounted=state.find("territory_state","sector_id",r.sector_id)
		if def.is_empty() or owner==null or territories.has(r.sector_id):return _fail("Invalid frontier governance identity")
		territories[r.sector_id]=r
		if r.phase not in ["neutral","controlled","warning","defending"] or (r.phase=="neutral")==owner.has_faction_id:return _fail("Frontier governance disagrees with current owner")
		if r.revision<0 or r.reserve_units<0 or r.reserve_units>int(b.reserve_max_units) or r.crisis_generation<0 or r.warning_remaining_s<0.0 or r.warning_remaining_s>float(b.warning_s) or r.defense_remaining_s<0.0 or r.defense_remaining_s>float(b.defense_s) or r.hold_remaining_s<0.0 or r.hold_remaining_s>float(b.hold_s):return _fail("Invalid frontier reserve or warning clock")
		if r.phase=="neutral" and (r.reserve_units!=0 or r.warning_remaining_s!=0.0 or r.defense_remaining_s!=0.0 or r.hold_remaining_s!=0.0):return _fail("Neutral frontier retains controlled activity")
	for j: RefCounted in state.rows("frontier_journal_state"):
		if journals.has(j.source_token) or not territories.has(j.sector_id) or j.event_kind not in ["capture","import","loss","warning","defense","supply"] or j.event_tick<0 or j.event_tick>state.snapshot.meta.simulation_tick:return _fail("Invalid frontier history identity or time")
		journals[j.source_token]=j
		if j.event_kind in ["capture","import"]:
			var w: Dictionary=catalog.one("civilization_war_defs","war_id",j.war_id)
			if not j.has_faction_id or not j.has_war_id or w.is_empty() or w.target_sector_id!=j.sector_id or w.faction_id!=j.faction_id or j.attempt<1:return _fail("Frontier ownership history lacks a real war")
			if j.event_kind=="import" and (j.reward_credit!=0 or j.reward_reputation!=0):return _fail("Imported frontier cannot duplicate past rewards")
			if j.event_kind=="capture":
				var prior: bool=false
				for earlier: RefCounted in state.rows("frontier_journal_state"):
					if earlier.sector_id==j.sector_id and earlier.faction_id==j.faction_id and earlier.event_kind in ["capture","import"] and earlier.revision<j.revision:prior=true
				if j.reward_credit!=int(b.recapture_credit if prior else w.reward_credit) or j.reward_reputation!=int(b.recapture_reputation if prior else w.reward_reputation):return _fail("Frontier conquest reward exceeds its first/repeat entitlement")
		elif j.event_kind=="loss" and (j.has_faction_id or j.crisis_generation<1):return _fail("Invalid frontier loss event")
		if j.event_kind=="defense" and (j.reward_credit!=(int(b.defense_credit) if j.units==0 else 0) or j.reward_reputation!=(int(b.defense_reputation) if j.units==0 else 0)):return _fail("Invalid frontier defense reward")
		if j.event_kind not in ["capture","defense"] and (j.reward_credit!=0 or j.reward_reputation!=0):return _fail("Unpaid frontier event has a reward")
	for id: String in territories:
		var r: RefCounted=territories[id];var changes: Dictionary={}
		for j: RefCounted in journals.values():
			if j.sector_id!=id or j.event_kind not in ["capture","import","loss"]:continue
			if j.revision<1 or j.revision>r.revision or changes.has(j.revision):return _fail("Invalid frontier ownership revision")
			changes[j.revision]=j
		if changes.size()!=r.revision:return _fail("Frontier ownership history incomplete")
		if r.revision>0:
			var j: RefCounted=changes[r.revision];var owner: RefCounted=state.find("territory_state","sector_id",id)
			if j.has_faction_id!=owner.has_faction_id or (j.has_faction_id and j.faction_id!=owner.faction_id):return _fail("Frontier current owner differs from its last transition")
	var d: RefCounted=state.rows("frontier_director_state")[0];var events: int=0
	if d.player_id!=state.player().player_id or d.next_event_s<0.0 or d.next_event_s>float(b.crisis_max_s) or d.has_active_sector_id!=d.has_active_faction_id:return _fail("Invalid frontier director")
	for r: RefCounted in territories.values():
		if r.phase in ["warning","defending"]:
			events+=1
			if not d.has_active_sector_id or d.active_sector_id!=r.sector_id:return _fail("Frontier crisis not owned by its director")
	if events!=(1 if d.has_active_sector_id else 0):return _fail("Multiple or missing frontier crises")
	if d.has_active_sector_id:
		var owner: RefCounted=state.find("territory_state","sector_id",d.active_sector_id)
		if owner==null or not owner.has_faction_id or owner.faction_id!=d.active_faction_id:return _fail("Frontier director changed the current crisis owner")
	for a: RefCounted in state.rows("frontier_actor_state"):
		var n: RefCounted=state.find("npc_state","npc_instance_id",a.npc_instance_id)
		if n==null or actor_ids.has(a.npc_instance_id) or a.generation<1 or n.generation!=a.generation or n.sector_id!=a.sector_id:return _fail("Invalid frontier actor generation")
		actor_ids[a.npc_instance_id]=true
		if a.actor_role=="beacon":
			var def: Dictionary=catalog.one("frontier_beacon_defs","spawn_id",n.spawn_id)
			if def.is_empty() or def.sector_id!=a.sector_id or a.has_war_id:return _fail("Invalid frontier beacon")
		else:
			var def: Dictionary=catalog.one("frontier_actor_defs","spawn_id",n.spawn_id)
			if def.is_empty() or def.sector_id!=a.sector_id or def.actor_role!=a.actor_role or (def.war_id!=null)!=a.has_war_id or (a.has_war_id and def.war_id!=a.war_id):return _fail("Frontier actor binding changed")
		if a.has_war_id:
			if not wars.has(a.war_id) or wars[a.war_id].attempt!=a.generation:return _fail("Frontier actor belongs to another attempt")
		elif territories[a.sector_id].phase!="defending" or territories[a.sector_id].crisis_generation!=a.generation:return _fail("Defense actor outside its active generation")
	var orders: Dictionary={}
	for o: RefCounted in state.rows("frontier_supply_order_state"):
		if orders.has(o.order_id) or not territories.has(o.sector_id) or catalog.one("civilization_defs","faction_id",o.faction_id).is_empty() or o.units<1 or o.units>int(b.reserve_max_units) or o.paid_credit!=int(b.dispatch_fee_credit) or o.remaining_s<0.0 or o.remaining_s>float(b.dispatch_s) or o.created_tick<0 or o.created_tick>state.snapshot.meta.simulation_tick or o.finished_tick<0 or o.finished_tick>state.snapshot.meta.simulation_tick:return _fail("Invalid strategic supply order")
		orders[o.order_id]=o
		if o.phase not in ["inflight","delivered","lost"] or (o.phase=="inflight" and o.finished_tick!=0) or (o.phase!="inflight" and o.remaining_s!=0.0):return _fail("Invalid strategic supply phase")
	return true
func historical_victory(state: XJRuntimeState,catalog: XJCatalog,war: RefCounted) -> bool:
	if not catalog.table_names.has("frontier_governance_defs"):return false
	var spec: Dictionary=catalog.one("civilization_war_defs","war_id",war.war_id)
	var row: RefCounted=state.find("frontier_territory_state","sector_id",str(spec.get("target_sector_id","")))
	if row==null:return false
	for j: RefCounted in state.rows("frontier_journal_state"):
		if j.war_id==war.war_id and j.attempt==war.attempt and j.event_kind in ["capture","import"] and row.revision>j.revision:return true
	return false
func friendly(state: XJRuntimeState,id: String) -> bool:
	var a: RefCounted=state.find("frontier_actor_state","npc_instance_id",id);var identity: RefCounted=state.rows("civilization_state")[0]
	if a==null or not identity.has_faction_id:return false
	if a.actor_role=="convoy" and a.has_war_id:
		var w: RefCounted=state.find("war_campaign_state","war_id",a.war_id)
		return w!=null and w.attempt==a.generation and w.status in ["assembling","fighting","occupying"]
	if a.actor_role=="beacon" and not a.has_war_id:
		var t: RefCounted=state.find("territory_state","sector_id",a.sector_id);var f: RefCounted=state.find("frontier_territory_state","sector_id",a.sector_id)
		return t!=null and t.has_faction_id and t.faction_id==identity.faction_id and f.phase=="defending" and f.crisis_generation==a.generation
	return false
func _fail(message: String) -> bool:
	last_error=message;return false
