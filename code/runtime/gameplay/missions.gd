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

func has_pending_loans() -> bool:
	for loan:D.LoanStateDto in g.state.rows("loan_state"):
		if loan.status not in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:continue
		var mission:D.MissionStateDto=g.state.find("mission_state","mission_instance_id",loan.mission_instance_id)
		if mission!=null and mission.status in ["completed","failed","abandoned"]:return true
	return false

func cleanup_pending_loans() -> void:
	if g.station().is_empty():return
	for loan:D.LoanStateDto in g.state.rows("loan_state"):
		if loan.status not in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:continue
		var mission:D.MissionStateDto=g.state.find("mission_state","mission_instance_id",loan.mission_instance_id)
		if mission!=null and mission.status in ["completed","failed","abandoned"]:_cleanup_loan(loan)

func eligible(def: Dictionary) -> bool:
	if has_pending_loans():return false
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
	if has_pending_loans():return g.fail("先返航归还待清理借船")
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
	g.work.ensure_tutorial_supplies()
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

func guidance(mission_id: String = "", origin_sector: String = "") -> Dictionary:
	# Location intelligence belongs to the frozen objective definition. A combat
	# site remains navigable before individual ships enter sensor range.
	var mission: D.MissionStateDto = active() if mission_id.is_empty() else resolve(mission_id)
	if mission == null:
		return station_guidance(mission_id, origin_sector) if not mission_id.is_empty() else {}
	var def: Dictionary = g.definition("mission_defs", "mission_id", mission.mission_def_id)
	var result: Dictionary = {}
	if mission.status == "ready":
		result = _station_location(str(def.turnin_station_id))
		result["objective_kind"] = "turnin"
	else:
		for obj: Dictionary in objectives(mission.mission_def_id):
			var current: D.MissionObjectiveStateDto = progress(mission, int(obj.objective_index))
			if current != null and current.progress_units >= int(obj.required_count): continue
			result = objective_guidance(obj, origin_sector)
			result["progress_units"] = current.progress_units if current != null else 0
			break
	if result.is_empty():
		result = _station_location(str(def.turnin_station_id))
		result["objective_kind"] = "turnin"
	result["mission_id"] = mission.mission_def_id
	result["mission_instance_id"] = mission.mission_instance_id
	result["status"] = mission.status
	return _route_location(result, origin_sector)

func station_guidance(mission_id: String, origin_sector: String = "") -> Dictionary:
	var def: Dictionary = g.definition("mission_defs", "mission_id", mission_id)
	if def.is_empty(): return {}
	var result: Dictionary = _station_location(str(def.accept_station_id))
	result["mission_id"] = mission_id
	result["objective_kind"] = "accept"
	result["status"] = "completed" if completed(mission_id) else "unaccepted"
	return _route_location(result, origin_sector)

func objective_guidance(obj: Dictionary, origin_sector: String = "") -> Dictionary:
	var kind: String = str(obj.get("objective_kind", ""))
	var result: Dictionary = {}
	match kind:
		"destroy_spawn":
			var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", str(obj.get("target_spawn_id", "")))
			if not spawn.is_empty():
				var enemy: Dictionary = g.definition("npc_full_defs", "npc_id", str(spawn.npc_id))
				result = _anchor_location(str(spawn.anchor_id), "encounter:" + str(spawn.spawn_id), "encounter", str(enemy.get("display_name", "敌方舰船")) + "群 · 任务地点")
				result["spawn_id"] = str(spawn.spawn_id)
		"scan_signal":
			var signal_def: Dictionary = g.definition("signal_defs", "signal_id", str(obj.get("target_signal_id", "")))
			if not signal_def.is_empty(): result = _anchor_location(str(signal_def.anchor_id), str(signal_def.signal_id), "signal", str(signal_def.display_name))
		"collect":
			var node: Dictionary = g.definition("resource_node_locations", "node_id", str(obj.get("target_node_id", "")))
			var item: Dictionary = g.definition("item_defs", "item_id", str(obj.get("target_item_id", "")))
			if not node.is_empty(): result = _anchor_location(str(node.anchor_id), str(node.node_id), "resource", str(item.get("display_name", "指定矿物")) + "矿点")
		"reach_anchor", "brake_at_anchor":
			var anchor_id: String = str(obj.get("target_anchor_id", ""))
			result = _anchor_location(anchor_id, anchor_id, "marker", "教学航路标")
		"loan_checkout", "fit_validate":
			var service: Dictionary = g.definition("loan_service_defs", "loan_service_id", str(obj.get("target_loan_service_id", "")))
			if not service.is_empty():
				result = _station_location(str(service.station_id))
				result["required_page"] = "ships" if kind == "loan_checkout" else "fitting"
		"dock", "undock", "deliver":
			result = _station_location(str(obj.get("target_station_id", "")))
		"transit_connection":
			var source: String = origin_sector if not origin_sector.is_empty() else g.state.current_sector()
			var connection_id: String = str(obj.get("target_connection_id", ""))
			for endpoint: Dictionary in g.rows("gate_endpoint_defs"):
				if str(endpoint.connection_id) != connection_id: continue
				if result.is_empty() or str(endpoint.origin_sector_id) == source:
					result = _anchor_location(str(endpoint.entry_anchor_id), str(endpoint.endpoint_id), "gate", "任务虫洞门")
					result["connection_id"] = connection_id
					result["destination_sector_id"] = str(endpoint.target_sector_id)
				if str(endpoint.origin_sector_id) == source: break
	if result.is_empty(): return {}
	result["objective_kind"] = kind
	result["objective_index"] = int(obj.get("objective_index", -1))
	result["required_count"] = int(obj.get("required_count", 1))
	return _route_location(result, origin_sector)

func _station_location(station_id: String) -> Dictionary:
	var station_def: Dictionary = g.definition("station_defs", "station_id", station_id)
	if station_def.is_empty(): return {}
	return _anchor_location(str(station_def.station_anchor_id), station_id, "station", str(station_def.display_name))

func _anchor_location(anchor_id: String, target_id: String, kind: String, title: String) -> Dictionary:
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", anchor_id)
	if anchor.is_empty(): return {}
	return {"target_id": target_id, "target_kind": kind, "target_title": title, "anchor_id": anchor_id, "sector_id": str(anchor.sector_id), "position": Vector3(float(anchor.x_m), float(anchor.y_m), float(anchor.z_m)), "required_page": ""}

func _route_location(location: Dictionary, origin_sector: String) -> Dictionary:
	if location.is_empty(): return {}
	var source: String = origin_sector if not origin_sector.is_empty() else g.state.current_sector()
	var destination: String = str(location.get("sector_id", ""))
	location["local"] = source == destination
	location["waypoint_id"] = str(location.get("target_id", "")) if source == destination else ""
	location["waypoint_kind"] = str(location.get("target_kind", "")) if source == destination else ""
	location["waypoint_title"] = str(location.get("target_title", "")) if source == destination else ""
	location["route_reason"] = ""
	location["route_sectors"] = [source]
	if source == destination:
		if str(location.get("target_kind", "")) == "gate":
			var endpoint: Dictionary = g.definition("gate_endpoint_defs", "endpoint_id", str(location.get("target_id", "")))
			location["route_reason"] = _gate_route_reason(endpoint, float(g.metrics(g.state.ship()).total_mass_kg))
		return location
	var route: Array[Dictionary] = _route(source, destination, true)
	if route.is_empty(): route = _route(source, destination, false)
	if route.is_empty():
		location["route_reason"] = "未找到通往任务地点的虫洞航路"
		return location
	var first: Dictionary = route[0]
	location["waypoint_id"] = str(first.endpoint_id)
	location["waypoint_kind"] = "gate"
	location["waypoint_title"] = "通往 " + _sector_title(str(first.target_sector_id)) + " 的虫洞门"
	var sectors: Array[String] = [source]
	var mass: float = float(g.metrics(g.state.ship()).total_mass_kg)
	for endpoint: Dictionary in route:
		sectors.append(str(endpoint.target_sector_id))
		if str(location.route_reason).is_empty():
			var reason: String = _gate_route_reason(endpoint, mass)
			if not reason.is_empty(): location["route_reason"] = _sector_title(str(endpoint.origin_sector_id)) + " → " + _sector_title(str(endpoint.target_sector_id)) + "：" + reason
	location["route_sectors"] = sectors
	return location

func _route(source: String, destination: String, unlocked_only: bool) -> Array[Dictionary]:
	var queue: Array[String] = [source]
	var seen: Dictionary = {source: true}
	var paths: Dictionary = {source: []}
	var endpoints: Array[Dictionary] = g.rows("gate_endpoint_defs").duplicate()
	endpoints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.endpoint_id) < str(b.endpoint_id))
	var mass: float = float(g.metrics(g.state.ship()).total_mass_kg)
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for endpoint: Dictionary in endpoints:
			if str(endpoint.origin_sector_id) != current: continue
			if unlocked_only and not _gate_route_reason(endpoint, mass).is_empty(): continue
			var next: String = str(endpoint.target_sector_id)
			if seen.has(next): continue
			seen[next] = true
			var path: Array[Dictionary] = []
			for previous: Dictionary in paths[current]: path.append(previous)
			path.append(endpoint)
			if next == destination: return path
			paths[next] = path
			queue.append(next)
	return []

func _gate_route_reason(endpoint: Dictionary, mass: float) -> String:
	# Route intelligence excludes doors this loaded hull cannot currently cross.
	# Entry distance, cooldown, fees and combat are revalidated at the door.
	if endpoint.is_empty(): return "任务虫洞定义不可用"
	if not g.unlocked(str(endpoint.required_unlock_id)):
		var unlock: Dictionary = g.definition("unlock_defs", "unlock_id", str(endpoint.required_unlock_id))
		return "航路需解锁 " + str(unlock.get("display_name", "虫洞权限"))
	var connection: Dictionary = g.definition("effective_connection_defs", "connection_id", str(endpoint.connection_id))
	var gate: D.GateStateDto = g.state.find("gate_state", "connection_id", str(endpoint.connection_id))
	if connection.is_empty() or gate == null: return "航门状态不可用"
	if gate.has_lifetime_remaining_s and gate.lifetime_remaining_s <= 0.0: return "虫洞寿命已耗尽"
	if not gate.enabled: return "航门处于关闭状态"
	if mass > float(connection.max_gross_mass_kg): return "当前舰船总质量超过单舰通行上限；卸货或换用较小舰船"
	if gate.has_remaining_mass_budget_kg and mass > gate.remaining_mass_budget_kg: return "虫洞剩余总质量额度不足；选择其他航路"
	return ""

func _sector_title(sector_id: String) -> String:
	var sector_def: Dictionary = g.definition("sector_defs", "sector_id", sector_id)
	var system_def: Dictionary = g.definition("system_defs", "system_id", str(sector_def.get("system_id", "")))
	return str(system_def.get("display_name", "任务星系"))

func chain(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def: Dictionary in g.rows("mission_defs"):
		if str(def.mission_kind) == kind: result.append(def)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var depth_a: int = _chain_depth(str(a.mission_id), {})
		var depth_b: int = _chain_depth(str(b.mission_id), {})
		return str(a.mission_id) < str(b.mission_id) if depth_a == depth_b else depth_a < depth_b)
	return result

func missing_prerequisite(mission_id: String, visited: Dictionary = {}) -> String:
	if visited.has(mission_id): return ""
	visited = visited.duplicate()
	visited[mission_id] = true
	for dependency: Dictionary in g.rows("mission_prerequisites"):
		if str(dependency.mission_id) != mission_id or completed(str(dependency.prerequisite_mission_id)): continue
		var prior: String = str(dependency.prerequisite_mission_id)
		var earlier: String = missing_prerequisite(prior, visited)
		return prior if earlier.is_empty() else earlier
	return ""

func _chain_depth(mission_id: String, visited: Dictionary) -> int:
	if visited.has(mission_id): return 0
	visited[mission_id] = true
	var depth: int = 0
	for dependency: Dictionary in g.rows("mission_prerequisites"):
		if str(dependency.mission_id) == mission_id: depth = maxi(depth, 1 + _chain_depth(str(dependency.prerequisite_mission_id), visited.duplicate()))
	return depth

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
	# Ending an attempt never teleports its hull. In space the same bounded
	# loan remains usable for return; docking unloads cargo before retirement.
	g.stop_interactions()
	for loan in g.state.rows("loan_state"):
		if loan.mission_instance_id==mission.mission_instance_id and loan.status in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:_cleanup_loan(loan)
	mission.status="abandoned";mission.has_deadline_remaining_s=false
	mission.cooldown_remaining_s=g.rule("contract_failure_retry_cooldown_s") if g.definition("mission_defs","mission_id",mission.mission_def_id).repeatable else 0.0
	var w:D.MissionWindowStateDto=window(mission.mission_def_id);w.has_last_failure_tick=true;w.last_failure_tick=g.state.snapshot.meta.simulation_tick
	refresh();return true

func loan(service_id: String) -> bool:
	if has_pending_loans():return g.fail("先返航归还待清理借船")
	if not g.allowed_service("loan"):return false
	var def:Dictionary=g.definition("loan_service_defs","loan_service_id",service_id)
	var mission:D.MissionStateDto=active()
	if def.is_empty() or mission==null or def.required_mission_id!=mission.mission_def_id or def.station_id!=g.station() or not g.unlocked(def.required_unlock_id):return g.fail("借船合同或站点不满足")
	if g.state.player().credit<def.fee_credit:return g.fail("借船费用不足")
	var loanrow:D.LoanStateDto=null
	for row in g.state.rows("loan_state"):
		if row.status not in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:continue
		if row.mission_instance_id!=mission.mission_instance_id or row.loan_service_id!=service_id:return g.fail("已有另一份有效借船")
		loanrow=row
	if loanrow==null:
		for row in g.state.rows("loan_state"):
			if row.status==T.LoanStatus.RETURNED and row.mission_instance_id==mission.mission_instance_id and row.loan_service_id==service_id:loanrow=row
	if loanrow!=null:
		if loanrow.replacement_remaining_s>0 or (loanrow.status!=T.LoanStatus.RETURNED and (loanrow.status!=T.LoanStatus.LOST or not def.replace_destroyed)):return g.fail("借船尚在使用或替换冷却")
		_cleanup_assets(loanrow)
	else:
		loanrow=D.LoanStateDto.new();loanrow.loan_id=g.id("loan");loanrow.player_id=g.state.player().player_id;loanrow.loan_service_id=service_id;loanrow.mission_instance_id=mission.mission_instance_id;loanrow.has_quota_remaining_units=def.operation_quota_units!=null;loanrow.quota_remaining_units=def.operation_quota_units if def.operation_quota_units!=null else 0;g.state.add("loan_state",loanrow)
	# SQL permits one loan per player/service/attempt. Reissuing its returned
	# hull preserves the same quota and appends to its issuance history.
	if g.state.player().credit<def.fee_credit:return g.fail("借船费用不足")
	g.state.player().credit-=def.fee_credit
	var loadout:Dictionary=g.definition("ship_loadout_defs","loadout_id",def.loadout_id)
	var ship:D.ShipStateDto=g.inventory.create_ship(loadout.ship_id,g.station(),def.policy_id,def.loadout_id,loanrow.loan_id)
	loanrow.status=T.LoanStatus.ACTIVE;loanrow.has_current_ship_id=true;loanrow.current_ship_id=ship.ship_instance_id;loanrow.issuance_count+=1
	var issue:D.LoanIssueStateDto=D.LoanIssueStateDto.new();issue.loan_id=loanrow.loan_id;issue.issuance_index=loanrow.issuance_count;issue.ship_instance_id=ship.ship_instance_id;issue.status="active";g.state.add("loan_issue_state",issue)
	g.state.player().controlled_ship_id=ship.ship_instance_id
	g.work.ensure_tutorial_supplies()
	record("loan_checkout",service_id,1);record("fit_validate",service_id,1)
	return true

func _cleanup_assets(loan:D.LoanStateDto) -> void:
	for asset in g.state.rows("loan_asset_state").duplicate():
		if asset.loan_id!=loan.loan_id:continue
		var item:RefCounted=g.state.find("item_instance_state","item_instance_id",asset.item_instance_id)
		if item!=null:g.inventory.erase_item(item)
	for stack in g.state.rows("inventory_stack_state").duplicate():
		if stack.loan_id==loan.loan_id or (stack.policy_id=="mission_bound" and stack.bound_mission_instance_id==loan.mission_instance_id):g.state.remove("inventory_stack_state",stack)
func _cleanup_loan(loan:D.LoanStateDto) -> void:
	if g.station().is_empty():return
	var ship:D.ShipStateDto=g.state.find("ship_state","ship_instance_id",loan.current_ship_id)
	if ship!=null:
		# A parked loan can be remote from the currently controlled ship.
		# Its ordinary cargo stays at that actual station, never follows the owner.
		var cargo_station:String=ship.station_id if ship.status==T.ShipStatus.DOCKED and ship.has_station_id else g.station()
		g.inventory.unload(ship,cargo_station)
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
	cleanup_pending_loans()
	return true

func tick(delta:float) -> void:
	for loan in g.state.rows("loan_state"):loan.replacement_remaining_s=maxf(0,loan.replacement_remaining_s-delta)
	for row in g.state.rows("mission_state"):
		row.cooldown_remaining_s=maxf(0,row.cooldown_remaining_s-delta)
		if row.status in ["active","ready"] and row.has_deadline_remaining_s:
			row.deadline_remaining_s=maxf(0,row.deadline_remaining_s-delta)
			if row.deadline_remaining_s==0:
				g.stop_interactions()
				for loan in g.state.rows("loan_state"):
					if loan.mission_instance_id==row.mission_instance_id and loan.status in [T.LoanStatus.ACTIVE,T.LoanStatus.LOST]:_cleanup_loan(loan)
				row.status="failed";row.has_deadline_remaining_s=false;row.cooldown_remaining_s=g.rule("contract_failure_retry_cooldown_s")
	for def in g.rows("mission_defs"):window(def.mission_id)
	refresh()
