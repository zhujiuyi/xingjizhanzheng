extends RefCounted
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
func _init(gameplay: RefCounted) -> void:g=gameplay

func completed(mission_id: String) -> bool:
	for row in g.state.rows("mission_state"):
		if row.mission_def_id==mission_id and row.reward_claimed:return true
	return false
func active() -> D.MissionStateDto:
	for row in g.state.rows("mission_state"):
		if row.status in ["active","ready"]:return row
	return null
func resolve(mission_id: String) -> D.MissionStateDto:
	for row in g.state.rows("mission_state"):
		if row.status in ["active","ready"] and mission_id in [row.mission_instance_id,row.mission_def_id]:return row
	return null
func objectives(mission_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	for row in g.rows("mission_objective_defs"):
		if row.mission_id==mission_id:rows.append(row)
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.objective_index<b.objective_index)
	return rows
func progress(mission: D.MissionStateDto,index: int) -> D.MissionObjectiveStateDto:
	for row in g.state.rows("mission_objective_state"):
		if row.mission_instance_id==mission.mission_instance_id and row.objective_index==index:return row
	return null
func window(mission_id: String) -> D.MissionWindowStateDto:
	var row: D.MissionWindowStateDto=g.state.find("mission_window_state","mission_def_id",mission_id)
	if row==null:
		row=D.MissionWindowStateDto.new();row.player_id=g.state.player().player_id;row.mission_def_id=mission_id;g.state.add("mission_window_state",row)
	var def:Dictionary=g.definition("mission_defs","mission_id",mission_id)
	if def.repeat_window_s>0:
		var elapsed:float=g.state.snapshot.meta.simulation_tick/g.rule("simulation_hz")
		var index:int=int(floor(elapsed/def.repeat_window_s))
		if row.window_index!=index:row.window_index=index;row.accepted_window_count=0;row.completed_window_count=0
		row.remaining_s=def.repeat_window_s-fmod(elapsed,def.repeat_window_s)
	return row

func eligible(def: Dictionary) -> bool:
	if not g.unlocked(def.required_unlock_id):return false
	for row in g.rows("mission_prerequisites"):
		if row.mission_id==def.mission_id and not completed(row.prerequisite_mission_id):return false
	if not def.repeatable and completed(def.mission_id):return false
	var w:D.MissionWindowStateDto=window(def.mission_id)
	if def.repeatable and (w.accepted_window_count>=g.rule("contract_max_accepts_per_window") or w.completed_window_count>=def.max_completions_per_window):return false
	for row in g.state.rows("mission_state"):
		if row.mission_def_id==def.mission_id and row.cooldown_remaining_s>0:return false
	return true

func refresh() -> void:
	for def in g.rows("mission_defs"):
		var row:D.MissionAvailabilityStateDto=g.state.find("mission_availability_state","mission_def_id",def.mission_id)
		if row==null:row=D.MissionAvailabilityStateDto.new();row.player_id=g.state.player().player_id;row.mission_def_id=def.mission_id;g.state.add("mission_availability_state",row)
		row.status="finished" if not def.repeatable and completed(def.mission_id) else "available" if eligible(def) else "locked"
		if active()!=null:row.status="busy" if row.status=="available" else row.status
	var mission:D.MissionStateDto=active()
	if mission==null:return
	var all_done:bool=true
	for obj in objectives(mission.mission_def_id):
		var p:D.MissionObjectiveStateDto=progress(mission,obj.objective_index)
		if obj.objective_kind=="deliver":continue
		if p.progress_units<obj.required_count:all_done=false
	mission.status="ready" if all_done else "active"

func accept(mission_id: String) -> bool:
	if not g.allowed_service("mission_board"):return false
	var def:Dictionary=g.definition("mission_defs","mission_id",mission_id)
	if def.is_empty() or def.accept_station_id!=g.station() or not eligible(def):return g.fail("任务地点、前置或窗口额度不满足")
	if active()!=null:return g.fail("先完成或放弃当前任务")
	var attempt:int=1
	for old in g.state.rows("mission_state"):
		if old.mission_def_id==mission_id:attempt=maxi(attempt,old.attempt_number+1)
	var row:D.MissionStateDto=D.MissionStateDto.new();row.mission_instance_id=g.id("mission");row.player_id=g.state.player().player_id;row.mission_def_id=mission_id;row.attempt_number=attempt;row.status="active";row.has_deadline_remaining_s=def.deadline_s!=null;row.deadline_remaining_s=float(def.deadline_s) if def.deadline_s!=null else 0.0;g.state.add("mission_state",row)
	for obj in objectives(mission_id):
		var p:D.MissionObjectiveStateDto=D.MissionObjectiveStateDto.new();p.mission_instance_id=row.mission_instance_id;p.mission_def_id=mission_id;p.objective_index=obj.objective_index
		if obj.objective_kind=="scan_signal":
			var signal_def:Dictionary=g.definition("signal_defs","signal_id",obj.target_signal_id)
			if signal_def.occurrence_mode=="fixed" and g.state.find("discovery_state","signal_id",obj.target_signal_id)!=null:p.progress_units=obj.required_count
		g.state.add("mission_objective_state",p)
	var w:D.MissionWindowStateDto=window(mission_id);w.accepted_window_count+=1;w.has_last_accept_tick=true;w.last_accept_tick=g.state.snapshot.meta.simulation_tick
	g._sync_spawns();refresh()
	return true

func record(kind: String,target: String,quantity: int) -> void:
	var mission:D.MissionStateDto=active()
	if mission==null or quantity<=0:return
	for obj in objectives(mission.mission_def_id):
		var p:D.MissionObjectiveStateDto=progress(mission,obj.objective_index)
		if p.progress_units>=obj.required_count:continue
		# Sequential objectives, with delivery checked only during atomic turn-in.
		if obj.objective_kind!=kind:break
		var matches:bool=false
		for key in ["target_anchor_id","target_station_id","target_signal_id","target_node_id","target_spawn_id","target_connection_id","target_loan_service_id"]:
			if obj[key]!=null and obj[key]==target:matches=true
		if not matches:break
		var amount:int=mini(quantity,obj.required_count-p.progress_units)
		p.progress_units+=amount
		if kind=="collect":
			mission.collected_units+=amount
			var proof:D.MissionCollectEventStateDto=D.MissionCollectEventStateDto.new();proof.event_id=g.id("collect");proof.mission_instance_id=mission.mission_instance_id;proof.item_def_id=obj.target_item_id;proof.quantity=amount;proof.event_tick=g.state.snapshot.meta.simulation_tick;g.state.add("mission_collect_event_state",proof)
		break
	refresh()

func active_for_target(kind: String,target: String) -> D.MissionStateDto:
	var mission:D.MissionStateDto=active()
	if mission==null:return null
	for obj in objectives(mission.mission_def_id):
		if obj.objective_kind!=kind:continue
		for key in ["target_signal_id","target_spawn_id","target_node_id"]:
			if obj[key]!=null and obj[key]==target:return mission
	return null

func _delivery_sources(mission:D.MissionStateDto,obj:Dictionary) -> Array[String]:
	var sources:Array[String]=[g.inventory.warehouse(g.station())]
	for kind in [T.ContainerKind.CARGO,T.ContainerKind.MINERAL]:
		var hold:String=g.inventory.hold(g.state.ship(),kind)
		if not hold.is_empty():sources.append(hold)
	return sources

func claim(mission_id: String) -> bool:
	if not g.allowed_service("mission_board"):return false
	var mission:D.MissionStateDto=resolve(mission_id)
	if mission==null:return g.fail("任务不存在或已经领取")
	refresh()
	var def:Dictionary=g.definition("mission_defs","mission_id",mission.mission_def_id)
	if def.turnin_station_id!=g.station() or mission.status!="ready":return g.fail("尚未完成目标或不在交接站点")
	for obj in objectives(mission.mission_def_id):
		if obj.objective_kind!="deliver":continue
		var total:int=0
		var bound:bool=def.mission_kind=="tutorial"
		for source in _delivery_sources(mission,obj):total+=g.inventory.count(source,obj.target_item_id,not bound,mission.mission_instance_id if bound else "")
		if total<obj.required_count:return g.fail("返航货物不足；历史采集记录不代替实物")
	for obj in objectives(mission.mission_def_id):
		if obj.objective_kind!="deliver":continue
		var left:int=obj.required_count
		var bound:bool=def.mission_kind=="tutorial"
		for source in _delivery_sources(mission,obj):
			var used:int=mini(left,g.inventory.count(source,obj.target_item_id,not bound,mission.mission_instance_id if bound else ""))
			if used>0:g.inventory.consume(source,obj.target_item_id,used,not bound,mission.mission_instance_id if bound else "")
			left-=used
		progress(mission,obj.objective_index).progress_units=obj.required_count;mission.delivered_units+=obj.required_count
	var reward:Dictionary=g.definition("mission_reward_defs","mission_id",mission.mission_def_id)
	g.state.player().credit+=reward.reward_credit;mission.reward_claimed=true;mission.status="completed";mission.has_deadline_remaining_s=false;mission.deadline_remaining_s=0
	mission.cooldown_remaining_s=def.repeat_cooldown_s
	var claimrow:D.MissionClaimStateDto=D.MissionClaimStateDto.new();claimrow.mission_instance_id=mission.mission_instance_id;claimrow.action_id=g._active_action.action_id;g.state.add("mission_claim_state",claimrow)
	var w:D.MissionWindowStateDto=window(mission.mission_def_id);w.completed_window_count+=1;w.has_last_settle_tick=true;w.last_settle_tick=g.state.snapshot.meta.simulation_tick
	for reward_unlock in g.rows("mission_unlock_rewards"):
		if reward_unlock.mission_id==mission.mission_def_id:g.grant_unlock(reward_unlock.unlock_id)
	for rep in g.rows("mission_reputation_rewards"):
		if rep.mission_id!=mission.mission_def_id:continue
		var row:D.ReputationStateDto=g.state.find("reputation_state","faction_id",rep.faction_id)
		if row==null:row=D.ReputationStateDto.new();row.player_id=g.state.player().player_id;row.faction_id=rep.faction_id;g.state.add("reputation_state",row)
		row.reputation+=rep.reputation_delta
	for loan in g.state.rows("loan_state"):
		if loan.mission_instance_id==mission.mission_instance_id and loan.status in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:return_loan(loan.loan_id)
	refresh()
	return true

func abandon(mission_id: String) -> bool:
	var mission:D.MissionStateDto=resolve(mission_id)
	if mission==null:return g.fail("没有可放弃的任务")
	# Lost or remote loan is invalidated; ordinary cargo first unloads at current station if docked.
	for loan in g.state.rows("loan_state"):
		if loan.mission_instance_id==mission.mission_instance_id and loan.status in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:_cleanup_loan(loan)
	mission.status="abandoned";mission.has_deadline_remaining_s=false
	mission.cooldown_remaining_s=g.rule("contract_failure_retry_cooldown_s") if g.definition("mission_defs","mission_id",mission.mission_def_id).repeatable else 0.0
	var w:D.MissionWindowStateDto=window(mission.mission_def_id);w.has_last_failure_tick=true;w.last_failure_tick=g.state.snapshot.meta.simulation_tick
	refresh();return true

func loan(service_id: String) -> bool:
	if not g.allowed_service("loan"):return false
	var def:Dictionary=g.definition("loan_service_defs","loan_service_id",service_id)
	var mission:D.MissionStateDto=active()
	if def.is_empty() or mission==null or def.required_mission_id!=mission.mission_def_id or def.station_id!=g.station() or not g.unlocked(def.required_unlock_id):return g.fail("借船合同或站点不满足")
	if g.state.player().credit<def.fee_credit:return g.fail("借船费用不足")
	var loanrow:D.LoanStateDto=null
	for row in g.state.rows("loan_state"):
		if row.status not in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:continue
		if row.mission_instance_id!=mission.mission_instance_id:return g.fail("已有另一份有效借船")
		loanrow=row
	if loanrow!=null:
		if loanrow.status!=T.LoanStatus.LOST or not def.replace_destroyed or loanrow.replacement_remaining_s>0:return g.fail("借船尚在使用或替换冷却")
		_cleanup_assets(loanrow)
	else:
		loanrow=D.LoanStateDto.new();loanrow.loan_id=g.id("loan");loanrow.player_id=g.state.player().player_id;loanrow.loan_service_id=service_id;loanrow.mission_instance_id=mission.mission_instance_id;loanrow.has_quota_remaining_units=def.operation_quota_units!=null;loanrow.quota_remaining_units=def.operation_quota_units if def.operation_quota_units!=null else 0;g.state.add("loan_state",loanrow)
	if g.state.player().credit<def.fee_credit:return g.fail("借船费用不足")
	g.state.player().credit-=def.fee_credit
	var loadout:Dictionary=g.definition("ship_loadout_defs","loadout_id",def.loadout_id)
	var ship:D.ShipStateDto=g.inventory.create_ship(loadout.ship_id,g.station(),def.policy_id,def.loadout_id,loanrow.loan_id)
	loanrow.status=T.LoanStatus.ACTIVE;loanrow.has_current_ship_id=true;loanrow.current_ship_id=ship.ship_instance_id;loanrow.issuance_count+=1
	var issue:D.LoanIssueStateDto=D.LoanIssueStateDto.new();issue.loan_id=loanrow.loan_id;issue.issuance_index=loanrow.issuance_count;issue.ship_instance_id=ship.ship_instance_id;issue.status="active";g.state.add("loan_issue_state",issue)
	g.state.player().controlled_ship_id=ship.ship_instance_id
	record("loan_checkout",service_id,1);record("fit_validate",service_id,1)
	return true

func _cleanup_assets(loan:D.LoanStateDto) -> void:
	for asset in g.state.rows("loan_asset_state").duplicate():
		if asset.loan_id!=loan.loan_id:continue
		var item:RefCounted=g.state.find("item_instance_state","item_instance_id",asset.item_instance_id)
		if item!=null:g.inventory.erase_item(item)
	for stack in g.state.rows("inventory_stack_state").duplicate():
		if stack.loan_id==loan.loan_id:g.state.remove("inventory_stack_state",stack)
func _cleanup_loan(loan:D.LoanStateDto) -> void:
	var ship:D.ShipStateDto=g.state.find("ship_state","ship_instance_id",loan.current_ship_id)
	if ship!=null:
		if not g.station().is_empty():g.inventory.unload(ship,g.station())
		if g.state.player().controlled_ship_id==ship.ship_instance_id:
			var restore:D.ShipStateDto=null
			for other in g.state.rows("ship_state"):
				if other.ship_instance_id!=ship.ship_instance_id and other.status==T.ShipStatus.DOCKED and other.station_id==g.station():restore=other;break
			if restore==null:
				var station_id:String=g.station() if not g.station().is_empty() else g.definition("loan_service_defs","loan_service_id",loan.loan_service_id).return_station_id
				restore=g.inventory.create_ship("shuttle_swift",station_id,"tutorial_protected","loadout_shuttle_swift")
			g.state.player().controlled_ship_id=restore.ship_instance_id;g.state.player().has_docked_station_id=true;g.state.player().docked_station_id=restore.station_id
		g.inventory.retire(ship)
	_cleanup_assets(loan)
	for issue in g.state.rows("loan_issue_state"):
		if issue.loan_id==loan.loan_id and issue.status=="active":issue.status="returned"
	loan.status=T.LoanStatus.RETURNED;loan.has_current_ship_id=false;loan.current_ship_id=""
func return_loan(target:String) -> bool:
	var loan:D.LoanStateDto=g.state.find("loan_state","loan_id",target)
	if loan==null:
		for row in g.state.rows("loan_state"):
			if row.loan_service_id==target and row.status in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:loan=row
	if loan==null or loan.status not in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:return g.fail("没有有效借船")
	var def:Dictionary=g.definition("loan_service_defs","loan_service_id",loan.loan_service_id)
	if g.station()!=def.return_station_id:return g.fail("需回借船交接点归还")
	_cleanup_loan(loan);return true

func ship_destroyed(ship:D.ShipStateDto) -> void:
	for loan in g.state.rows("loan_state"):
		if loan.current_ship_id==ship.ship_instance_id and loan.status==T.LoanStatus.ACTIVE:
			loan.status=T.LoanStatus.LOST;loan.has_current_ship_id=false;loan.current_ship_id="";loan.replacement_remaining_s=g.definition("loan_service_defs","loan_service_id",loan.loan_service_id).replacement_cooldown_s
			for issue in g.state.rows("loan_issue_state"):
				if issue.ship_instance_id==ship.ship_instance_id:issue.status="destroyed"
			# Bound tutorial samples: historical collect proof survives, invalidated capacity can be replaced.
			var def:Dictionary=g.definition("loan_service_defs","loan_service_id",loan.loan_service_id)
			if def.gathered_policy_id=="mission_bound":loan.quota_remaining_units=def.operation_quota_units

func rescue() -> bool:
	if g.state.ship().status!=T.ShipStatus.DESTROYED:return g.fail("仅舰船损失后可申请最低保障")
	var station_id:String="station_anchor_port"
	for loan in g.state.rows("loan_state"):
		for issue in g.state.rows("loan_issue_state"):
			if issue.loan_id==loan.loan_id and issue.ship_instance_id==g.state.ship().ship_instance_id:station_id=g.definition("loan_service_defs","loan_service_id",loan.loan_service_id).station_id
	for npc in g.state.rows("npc_state"):
		if npc.alive and npc.sector_id==g.state.ship().sector_id and npc.behavior_phase in [T.NpcPhase.ACQUIRE,T.NpcPhase.PURSUE,T.NpcPhase.ATTACK,T.NpcPhase.DISENGAGE]:npc.behavior_phase=T.NpcPhase.RETURN
	var ship:D.ShipStateDto=null
	for candidate in g.state.rows("ship_state"):
		if candidate.status==T.ShipStatus.DOCKED and candidate.station_id==station_id and candidate.owner_player_id==g.state.player().player_id:
			ship=candidate;break
	if ship==null:ship=g.inventory.create_ship("shuttle_swift",station_id,"tutorial_protected","loadout_shuttle_swift")
	g.state.player().controlled_ship_id=ship.ship_instance_id;g.state.player().has_docked_station_id=true;g.state.player().docked_station_id=station_id;g.combat_remaining_s=0
	return true

func tick(delta:float) -> void:
	for loan in g.state.rows("loan_state"):loan.replacement_remaining_s=maxf(0,loan.replacement_remaining_s-delta)
	for row in g.state.rows("mission_state"):
		row.cooldown_remaining_s=maxf(0,row.cooldown_remaining_s-delta)
		if row.status in ["active","ready"] and row.has_deadline_remaining_s:
			row.deadline_remaining_s=maxf(0,row.deadline_remaining_s-delta)
			if row.deadline_remaining_s==0:
				for loan in g.state.rows("loan_state"):
					if loan.mission_instance_id==row.mission_instance_id and loan.status in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:_cleanup_loan(loan)
				row.status="failed";row.has_deadline_remaining_s=false;row.cooldown_remaining_s=g.rule("contract_failure_retry_cooldown_s")
	for def in g.rows("mission_defs"):window(def.mission_id)
	refresh()
