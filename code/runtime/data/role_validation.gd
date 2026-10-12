extends RefCounted
const T = preload("res://contracts/contract_types.gd")
var last_error: String = ""
func _fail(message: String) -> bool: last_error=message; return false
func validate(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	if not catalog.table_names.has("ship_role_capability_defs"):
		for table: String in ["remote_support_state","consignment_state","consignment_receipt_state"]:
			if not state.rows(table).is_empty(): return _fail("Role state under legacy definitions")
		return true
	if not _support(state,catalog): return false
	return _freight(state,catalog)
func _support(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	var ids: Dictionary = {}
	for row: RefCounted in state.rows("remote_support_state"):
		if ids.has(row.item_instance_id): return _fail("Duplicate support channel")
		ids[row.item_instance_id]=true
		var ship: RefCounted=state.find("ship_state","ship_instance_id",row.ship_instance_id)
		var item: RefCounted=state.find("item_instance_state","item_instance_id",row.item_instance_id)
		var equipment: RefCounted=state.find("equipment_state","item_instance_id",row.item_instance_id)
		var npc: RefCounted=state.find("npc_state","npc_instance_id",row.target_npc_id)
		if ship==null or item==null or equipment==null or npc==null: return _fail("Support binding missing")
		var cap: Dictionary=catalog.one("ship_role_capability_defs","ship_id",ship.ship_def_id)
		var slot: RefCounted=state.find("container_state","container_id",equipment.slot_container_id)
		var repair: Dictionary=catalog.one("repair_defs","module_id",equipment.module_def_id)
		if cap.is_empty() or not bool(cap.remote_repair_allowed) or ship.ship_instance_id!=state.ship().ship_instance_id or ship.status!=T.ShipStatus.FLYING or ship.policy_id!="normal_owned" or item.policy_id!="normal_owned" or item.durability<=0.0 or not equipment.enabled or slot==null or slot.ship_instance_id!=ship.ship_instance_id or repair.is_empty(): return _fail("Support hull or equipment unavailable")
		var actor: RefCounted=state.find("exploration_actor_state","npc_instance_id",row.target_npc_id)
		var member: RefCounted=state.find("war_fleet_state","npc_instance_id",row.target_npc_id)
		var friendly: bool=(actor!=null and actor.actor_role=="escort") or (member!=null and member.side=="ally") or (catalog.table_names.has("frontier_campaign_defs") and preload("res://runtime/data/frontier_validation.gd").new().friendly(state,row.target_npc_id)) or preload("res://runtime/data/hire_validation.gd").actor_binding(state,catalog,row.target_npc_id)
		friendly=friendly or preload("res://runtime/data/fleet_validation.gd").actor_binding(state,catalog,row.target_npc_id)
		var scenario: RefCounted=state.find("scenario_actor_state","npc_instance_id",row.target_npc_id)
		if scenario!=null and scenario.scenario_kind=="trial" and scenario.actor_role in ["escort","patient"]:
			var trial: RefCounted=state.find("trial_state","trial_id",scenario.scenario_id)
			friendly=friendly or (trial!=null and trial.phase=="active" and trial.generation==scenario.generation)
		if not friendly or not npc.alive or npc.generation!=row.target_generation or repair.layer_id!=row.layer_id: return _fail("Support target generation or allegiance invalid")
		if row.phase=="armed":
			if row.remaining_s!=0.0 or row.paid_restore!=0.0: return _fail("Unpaid support has a paid budget")
		elif row.phase=="cycling":
			var module: Dictionary=catalog.one("module_defs","module_id",equipment.module_def_id)
			var amount: float=float(repair.restore_amount)*item.quality_multiplier*float(cap["remote_"+row.layer_id+"_multiplier"])
			var crew_quote: RefCounted=state.find("crew_support_quote_state","item_instance_id",row.item_instance_id)
			if crew_quote!=null:amount*=crew_quote.restore_multiplier
			if row.remaining_s<=0.0 or row.remaining_s>float(module.cycle_s)+0.000001 or not equipment.cycle_paid or absf(equipment.active_remaining_s-row.remaining_s)>0.000001 or absf(row.paid_restore-amount)>0.000001: return _fail("Support paid cycle invalid")
		else: return _fail("Unknown support phase")
	return true
func _freight(state: XJRuntimeState,catalog: XJCatalog) -> bool:
	var definitions: Array[Dictionary]=catalog.rows("consignment_defs")
	if state.rows("consignment_state").size()!=definitions.size(): return _fail("Consignment coverage incomplete")
	var balance: Dictionary=catalog.rows("role_balance_defs")[0]
	var sums: Dictionary={}; var rounds: Dictionary={}; var receipt_ids: Dictionary={}
	for receipt: RefCounted in state.rows("consignment_receipt_state"):
		var row: RefCounted=state.find("consignment_state","contract_id",receipt.contract_id)
		var d: Dictionary=catalog.one("consignment_defs","contract_id",receipt.contract_id)
		if row==null or d.is_empty() or receipt_ids.has(receipt.receipt_id) or receipt.generation<=0 or receipt.generation>row.generation or receipt.units<0 or mini(receipt.paid_credit,mini(receipt.refunded_credit,receipt.reward_credit))<0: return _fail("Consignment receipt binding invalid")
		receipt_ids[receipt.receipt_id]=true
		if receipt.action_kind not in ["dispatch","deliver","loss","return","claim"] or (receipt.action_kind!="claim" and receipt.units<=0): return _fail("Consignment receipt action invalid")
		var key: String=receipt.contract_id+":"+str(receipt.generation)
		if not rounds.has(key): rounds[key]={"contract_id":receipt.contract_id,"generation":receipt.generation,"dispatch":0,"deliver":0,"loss":0,"return":0,"dispatch_count":0,"claim_count":0,"claim_units":0,"refund":0,"reward":0}
		var round: Dictionary=rounds[key]
		if receipt.action_kind=="dispatch":
			if receipt.units>int(d.max_units) or receipt.paid_credit!=int(d.fee_credit)+receipt.units*int(d.deposit_per_unit) or receipt.refunded_credit!=0 or receipt.reward_credit!=0: return _fail("Consignment deposit or fee invalid")
			round.dispatch+=receipt.units;round.dispatch_count+=1
		elif receipt.action_kind=="claim":
			if receipt.paid_credit!=0: return _fail("Consignment claim charged twice")
			round.claim_count+=1;round.claim_units+=receipt.units;round.refund+=receipt.refunded_credit;round.reward+=receipt.reward_credit
		else:
			if receipt.paid_credit+receipt.refunded_credit+receipt.reward_credit!=0: return _fail("Cargo movement creates credit")
			round[receipt.action_kind]+=receipt.units
		if not sums.has(receipt.contract_id): sums[receipt.contract_id]={"paid":0,"refunded":0,"reward":0}
		sums[receipt.contract_id].paid+=receipt.paid_credit
		sums[receipt.contract_id].refunded+=receipt.refunded_credit
		sums[receipt.contract_id].reward+=receipt.reward_credit
	for round: Dictionary in rounds.values():
		var d: Dictionary=catalog.one("consignment_defs","contract_id",round.contract_id)
		var row: RefCounted=state.find("consignment_state","contract_id",round.contract_id)
		if round.dispatch_count!=1 or round.claim_count>1 or round.dispatch<round.deliver+round.loss+round["return"]: return _fail("Consignment round has duplicate or excess cargo")
		if round.claim_count==1 and (round.dispatch!=round.deliver+round.loss+round["return"] or round.claim_units!=round.deliver or round.refund!=(round.deliver+round["return"])*int(d.deposit_per_unit) or round.reward!=round.deliver*int(d.reward_per_unit)): return _fail("Consignment payout conservation failed")
		if round.generation<row.generation and round.claim_count!=1: return _fail("Past consignment round incomplete")
	var seen: Dictionary={}
	for row: RefCounted in state.rows("consignment_state"):
		var d: Dictionary=catalog.one("consignment_defs","contract_id",row.contract_id)
		if d.is_empty() or seen.has(row.contract_id) or row.generation<=0: return _fail("Consignment definition binding invalid")
		seen[row.contract_id]=true
		if mini(row.accepted_units,mini(row.cargo_units,mini(row.delivered_units,mini(row.lost_units,row.returned_units))))<0 or row.accepted_units>int(d.max_units) or row.accepted_units!=row.cargo_units+row.delivered_units+row.lost_units+row.returned_units: return _fail("Consignment cargo conservation failed")
		if minf(row.remaining_s,minf(row.cooldown_remaining_s,minf(row.exposure_remaining_s,row.damage_debt_hp)))<0.0 or row.remaining_s>float(d.deadline_s) or row.cooldown_remaining_s>float(d.cooldown_s) or row.exposure_remaining_s>float(balance.freight_exposure_s) or row.damage_debt_hp>=float(balance.freight_loss_damage_hp): return _fail("Consignment timer or damage debt invalid")
		var round: Dictionary=rounds.get(row.contract_id+":"+str(row.generation),{"dispatch":0,"deliver":0,"loss":0,"return":0,"claim_count":0})
		if row.accepted_units!=round.dispatch or row.delivered_units!=round.deliver or row.lost_units!=round.loss or row.returned_units!=round["return"]: return _fail("Consignment current round ledger differs")
		var total: Dictionary=sums.get(row.contract_id,{"paid":0,"refunded":0,"reward":0})
		if total.paid!=row.paid_credit_total or total.refunded!=row.refunded_credit_total or total.reward!=row.reward_credit_total: return _fail("Consignment financial totals differ")
		if row.phase=="idle":
			if row.accepted_units!=0 or row.has_payload_ship_id or row.remaining_s!=0.0: return _fail("Idle consignment has cargo")
		elif row.phase=="active":
			var ship: RefCounted=state.find("ship_state","ship_instance_id",row.payload_ship_id)
			if row.cargo_units<=0 or row.remaining_s<=0.0 or not row.has_payload_ship_id or ship==null or ship.owner_player_id!=state.player().player_id or ship.policy_id!="normal_owned" or ship.status not in [T.ShipStatus.FLYING,T.ShipStatus.DOCKED]: return _fail("Consignment carrying ship unavailable")
		elif row.phase in ["ready","claimed"]:
			if row.accepted_units<=0 or row.cargo_units!=0 or row.has_payload_ship_id or row.remaining_s+row.exposure_remaining_s+row.damage_debt_hp!=0.0: return _fail("Finished consignment retains cargo")
		else: return _fail("Unknown consignment phase")
		if (row.phase=="claimed")!=(round.claim_count==1) or (row.phase!="claimed" and row.cooldown_remaining_s!=0.0) or (row.exposure_remaining_s==0.0 and row.damage_debt_hp!=0.0): return _fail("Consignment closure or exposure invalid")
	return true
