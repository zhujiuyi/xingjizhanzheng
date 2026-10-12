extends RefCounted
## Owned actors bind existing ships; no hull, equipment or cargo is cloned.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
const Binding=preload("res://runtime/data/fleet_validation.gd")
const Space=preload("res://runtime/space_coordinates.gd")
const Party=preload("res://runtime/data/party_rules.gd")
const POSE: Array[String]=["pos_x","pos_y","pos_z","quat_x","quat_y","quat_z","quat_w","vel_x","vel_y","vel_z"]
var g: RefCounted
var balance: Dictionary={}
var spatial_active: bool=true
var pending_attacks: Callable
signal changed(message: String)
func _init(host: RefCounted) -> void:
	g=host
	if supported():balance=g.rows("fleet_balance_defs")[0]
func supported() -> bool:return g!=null and g.catalog.table_names.has("fleet_hull_defs")
func row(id: String) -> RefCounted:return g.state.find("fleet_deployment_state","ship_instance_id",id) if supported() else null
func ship(id: String) -> RefCounted:return g.state.find("ship_state","ship_instance_id",id)
func actor(value: RefCounted) -> RefCounted:return g.state.find("npc_state","npc_instance_id",value.npc_instance_id) if value!=null and value.has_npc_instance_id else null
func active() -> Array:
	return g.state.rows("fleet_deployment_state").filter(func(r: RefCounted):return r.phase in ["deployed","retreating","returning"]) if supported() else []
func friendly(id: String) -> bool:return Binding.actor_binding(g.state,g.catalog,id)
func owns(id: String) -> bool:
	var hull: RefCounted=ship(id)
	return hull!=null and hull.owner_player_id==g.state.player().player_id and hull.policy_id=="normal_owned"
func model(id: String) -> String:
	var hull: RefCounted=ship(id)
	return hull.ship_def_id if hull!=null else ""
func total() -> RefCounted:return g.state.rows("fleet_total_state")[0] if supported() else null
func stats(id: String) -> Dictionary:
	var hull: RefCounted=ship(id);var value: RefCounted=row(id);var npc: RefCounted=actor(value)
	if hull==null or npc==null:return {}
	var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",npc.spawn_id)
	var result: Dictionary=g.definition("npc_full_defs","npc_id",spawn.npc_id).duplicate(true);var metrics: Dictionary=g.metrics(hull)
	result.shield_max=metrics.shield_max;result.armor_max=metrics.armor_max;result.hull_max=metrics.hull_max;result.speed_mps=metrics.speed_mps;result.range_m=0.0;result.raw_dps=0.0;result.reward_credit=0
	for equipment: RefCounted in g.equipped(hull):
		var item: RefCounted=g.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
		var profile: Dictionary=g.specializations.weapon_spec(equipment,hull)
		if not equipment.enabled or item==null or item.durability<=0 or profile.is_empty():continue
		result.range_m=maxf(float(result.range_m),float(profile.range_m));result.raw_dps+=float(profile.raw_damage)/float(profile.cycle_s)
	return result
func quote(id: String) -> int:
	var hull: RefCounted=ship(id)
	return int(balance.deploy_fee_credit)+int(ceil(float(g.definition("ship_defs","ship_id",hull.ship_def_id).base_ask_credit)*float(balance.deploy_hull_fee_bp)/10000.0)) if hull!=null and supported() else 0
func token(id: String) -> String:
	var value: RefCounted=row(id);var hull: RefCounted=ship(id)
	return "%s:%s:%d:%s:%s:%d:%d" % [g.state.world_id,g.state.session_id,g.state.epoch,id,value.phase if value!=null else "idle",value.generation if value!=null else 0,value.order_revision if value!=null else (hull.state_version if hull!=null else -1)]
func connected(value: RefCounted) -> bool:
	var npc: RefCounted=actor(value)
	return npc!=null and npc.alive and g.same_entity_site("ship",g.state.ship(),"npc",npc) and g.position(npc).distance_to(g.position(g.state.ship()))<=float(balance.communication_m)
func busy(id: String) -> bool:
	var hull: RefCounted=ship(id)
	if hull!=null:
		for equipment: RefCounted in g.equipped(hull):
			if equipment.active_remaining_s>0:return true
	return pending_attacks.is_valid() and pending_attacks.call(id)
func departure_poses() -> Array[Dictionary]:return Party.departure_owned(g.state,g.catalog)
func restore_departure(poses: Array[Dictionary]) -> void:Party.restore_owned(g.state,g.catalog,poses)
func follow_arrival() -> void:Party.arrive_owned(g.state,g.catalog)
func deploy_reason(id: String) -> String:
	if not supported():return "当前世界尚未升级自有舰队规则"
	if g.scenarios!=null and not g.scenarios.party_change_reason(id,true).is_empty():return g.scenarios.party_change_reason(id,true)
	if g.station().is_empty() or g.state.ship().status!=T.ShipStatus.DOCKED:return "停靠空间站后部署自有舰"
	if not g.unlocked(str(balance.required_unlock_id)):return "完成航路教学后开放自有编队"
	var hull: RefCounted=ship(id);var value: RefCounted=row(id)
	if hull==null or hull.owner_player_id!=g.state.player().player_id or hull.policy_id!="normal_owned" or hull.ship_instance_id==g.state.player().controlled_ship_id:return "选择普通自有的闲置舰船"
	if hull.status!=T.ShipStatus.DOCKED or not hull.has_station_id or hull.station_id!=g.station():return "该舰必须停靠在当前站"
	if value!=null and value.phase in ["deployed","retreating","returning"]:return "该舰已有进行中的部署"
	if active().size()>=int(balance.max_owned_companions):return "自有僚舰名额已满"
	if g.crew.pilot(id)==null:return "先为该舰指派可出勤的操舰员"
	if g.state.player().credit<quote(id):return "出航准备费不足"
	for equipment: RefCounted in g.equipped(hull):
		var item: RefCounted=g.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
		if item==null or item.policy_id!="normal_owned":return "自有编队不能携带借用或受保护设备"
	for container: RefCounted in g.state.rows("container_state"):
		if not container.has_ship_instance_id or container.ship_instance_id!=id:continue
		for stack: RefCounted in g.state.rows("inventory_stack_state"):
			if stack.container_id==container.container_id and stack.policy_id!="normal_owned":return "先移出该舰的受保护物资"
	for table: String in ["consignment_state","operation_state","blockade_state","trial_state"]:
		for task: RefCounted in g.state.rows(table):
			var field: String="ship_instance_id" if table=="trial_state" else "payload_ship_id"
			if task.get("has_"+field)==true and task.get(field)==id and task.phase in ["accepted","active","ready"]:return "该舰正被任务或运输锁定"
	return ""
func order_reason(id: String,order: String,focus_id: String="",focus_generation: int=0) -> String:
	if order in ["retreat","recover"] and not g.scenarios.party_change_reason(id).is_empty():return g.scenarios.party_change_reason(id)
	var value: RefCounted=row(id);var npc: RefCounted=actor(value)
	if value==null or value.phase!="deployed" or npc==null:return "该舰尚未部署或正在返航"
	if not spatial_active:return "等待编队航行转移完成"
	if order=="recover":
		if g.state.ship().status!=T.ShipStatus.DOCKED or not connected(value) or g.position(npc).distance_to(g.position(g.state.ship()))>float(balance.warp_ready_m):return "停靠后等自有僚舰实际归队，再收回"
		if g.in_combat() or busy(id):return "等待交战和已发出的攻击/无人机结束"
		return ""
	if order not in ["advance","regroup","focus","retreat"]:return "未知编队指令"
	if not connected(value):return "该舰失联；先回到同一地点并接近"
	if order=="focus":
		var target: RefCounted=g.state.find("npc_state","npc_instance_id",focus_id)
		if target==null or not target.alive or target.generation!=focus_generation or not g.civilizations.hostile_to(id,focus_id) or not g.same_entity_site("npc",npc,"npc",target):return "集火目标已变化或不是本地敌舰"
		if g.position(npc).distance_to(g.position(target))>float(balance.communication_m):return "集火目标超出通信范围"
	return ""
func execute(id: String,action: String,expected: String,focus_id: String="",focus_generation: int=0) -> bool:
	if expected!=token(id):return g.fail("舰船部署或指令已变化，请刷新后操作")
	var blocked: String=deploy_reason(id) if action=="deploy" else order_reason(id,action,focus_id,focus_generation)
	if not blocked.is_empty():return g.fail(blocked)
	if action=="deploy":return _deploy(id)
	var value: RefCounted=row(id)
	if action=="recover":_dock(value,g.station(),"recovered");return true
	if action=="retreat":_retreat(value,"withdrawn");return true
	value.order_kind=action;value.order_revision+=1;value.has_focus_target_id=action=="focus";value.focus_target_id=focus_id if value.has_focus_target_id else ""
	_changed("自有僚舰 · "+{"advance":"推进","regroup":"集结","focus":"集火"}[action]);return true
func _deploy(id: String) -> bool:
	var hull: RefCounted=ship(id);var value: RefCounted=row(id);var fee: int=quote(id)
	if value==null:value=D.FleetDeploymentStateDto.new();value.ship_instance_id=id;g.state.add("fleet_deployment_state",value)
	value.generation+=1;value.phase="deployed";value.has_npc_instance_id=true;value.npc_instance_id=id;value.origin_station_id=g.station();value.has_return_station_id=false;value.return_station_id=""
	value.sector_id=g.state.current_sector();value.site_id=Space.current_site(g.state);value.order_kind="regroup";value.has_focus_target_id=false;value.focus_target_id="";value.order_revision+=1
	value.created_tick=g.state.snapshot.meta.simulation_tick;value.finished_tick=0;value.end_reason="";value.deploy_paid_credit+=fee;value.retreat_remaining_s=0;value.return_remaining_s=0
	var station: Dictionary=g.definition("station_defs","station_id",g.station());var anchor: Dictionary=g.definition("anchor_defs","anchor_id",station.undock_anchor_id)
	var position: Vector3=g.anchor_position(anchor)+Basis(Vector3.UP,float(anchor.yaw_rad))*Party.offset(g.catalog,Party.owned(g.state,g.catalog).find(value))
	hull.status=T.ShipStatus.FLYING;hull.has_station_id=false;hull.station_id="";hull.pos_x=position.x;hull.pos_y=position.y;hull.pos_z=position.z;hull.vel_x=0;hull.vel_y=0;hull.vel_z=0
	value.goal_x=position.x;value.goal_y=position.y;value.goal_z=position.z
	var npc: RefCounted=D.NpcStateDto.new();npc.npc_instance_id=id;npc.spawn_id=g.definition("fleet_hull_defs","ship_id",hull.ship_def_id).spawn_id;npc.sector_id=hull.sector_id
	# The legacy NPC key is (spawn, generation). Two owned hulls of the same
	# type share a spawn definition but need separate, monotonic actor versions.
	value.actor_generation=maxi(value.actor_generation+1,value.generation)
	for other: RefCounted in g.state.rows("npc_state"):
		if other.spawn_id==npc.spawn_id:value.actor_generation=maxi(value.actor_generation,other.generation+1)
	npc.generation=value.actor_generation;npc.alive=true;npc.bounty_claimed=true;npc.loot_claimed=true;npc.behavior_phase=T.NpcPhase.PATROL
	for field: String in POSE:npc.set(field,hull.get(field))
	npc.shield=hull.shield;npc.armor=hull.armor;npc.hull=hull.hull
	g.state.add("npc_state",npc);Space.assign(g.state,"ship",id,value.site_id);Space.assign(g.state,"npc",id,value.site_id)
	g.state.player().credit-=fee;total().deployments+=1;total().paid_credit+=fee;_receipt(value,"deploy",fee)
	_changed("已部署 · "+str(g.definition("ship_defs","ship_id",hull.ship_def_id).display_name));return true
func sync_hull(value: RefCounted) -> void:
	var hull: RefCounted=ship(value.ship_instance_id);var npc: RefCounted=actor(value)
	if hull==null or npc==null:return
	for field: String in POSE:hull.set(field,npc.get(field))
	hull.sector_id=npc.sector_id
	npc.shield=hull.shield;npc.armor=hull.armor;npc.hull=hull.hull
func sync_health(id: String) -> void:
	var value: RefCounted=row(id);var npc: RefCounted=actor(value);var hull: RefCounted=ship(id)
	if npc!=null and hull!=null:hull.shield=npc.shield;hull.armor=npc.armor;hull.hull=npc.hull
func sync_actor_health(id: String) -> void:
	var value: RefCounted=row(id);var npc: RefCounted=actor(value);var hull: RefCounted=ship(id)
	if npc!=null and hull!=null:npc.shield=hull.shield;npc.armor=hull.armor;npc.hull=hull.hull
func nearest_station(sector: String,position: Vector3) -> String:
	var selected: String="";var distance: float=INF
	for station: Dictionary in g.rows("station_defs"):
		if station.sector_id!=sector:continue
		var anchor: Dictionary=g.definition("anchor_defs","anchor_id",station.station_anchor_id);var candidate: float=position.distance_to(g.anchor_position(anchor))
		if candidate<distance:distance=candidate;selected=station.station_id
	return selected
func damage_actor(id: String,raw: Vector3) -> float:
	var value: RefCounted=row(id);var hull: RefCounted=ship(id);var npc: RefCounted=actor(value)
	if value==null or hull==null or npc==null or not npc.alive or not raw.is_finite() or not spatial_active or not g.same_entity_site("ship",g.state.ship(),"npc",npc):return 0.0
	var amount: float=g.apply_damage(hull,raw.max(Vector3.ZERO),g.metrics(hull).resistances)
	hull.shield_delay_remaining_s=g.rule("shield_recharge_delay_s");hull.state_version+=1;npc.shield=hull.shield;npc.armor=hull.armor;npc.hull=hull.hull;total().damage_taken+=amount;g.mark_hostile_attempt()
	if hull.hull<=0:
		hull.status=T.ShipStatus.DESTROYED;value.phase="lost";value.end_reason="destroyed";value.finished_tick=g.state.snapshot.meta.simulation_tick;value.order_kind="retreat";value.has_focus_target_id=false;value.focus_target_id="";value.retreat_remaining_s=0;value.return_remaining_s=0;value.order_revision+=1
		var station: String=nearest_station(hull.sector_id,g.position(hull))
		g.crew.ship_lost(id,station);_remove_actor(value);g.inventory.ship_destroyed(hull);g.missions.ship_destroyed(hull);total().losses+=1;_receipt(value,"loss",0);_changed("自有僚舰损毁 · 船员已获救，资产按实际损失结算")
	return amount
func _remove_actor(value: RefCounted) -> void:
	if not value.has_npc_instance_id:return
	for support: RefCounted in g.state.rows("remote_support_state").duplicate():
		if support.target_npc_id==value.npc_instance_id:g.ship_roles.stop_support(support.item_instance_id)
	var npc: RefCounted=actor(value);Space.remove(g.state,"npc",value.npc_instance_id)
	if npc!=null:g.state.remove("npc_state",npc)
	value.has_npc_instance_id=false;value.npc_instance_id=""
func _dock(value: RefCounted,station_id: String,reason: String) -> void:
	var hull: RefCounted=ship(value.ship_instance_id);var station: Dictionary=g.definition("station_defs","station_id",station_id)
	var position: Vector3=g.anchor_position(g.definition("anchor_defs","anchor_id",station.station_anchor_id))
	_remove_actor(value);hull.status=T.ShipStatus.DOCKED;hull.has_station_id=true;hull.station_id=station_id;hull.sector_id=station.sector_id;hull.pos_x=position.x;hull.pos_y=position.y;hull.pos_z=position.z;hull.vel_x=0;hull.vel_y=0;hull.vel_z=0
	value.phase="docked";value.end_reason=reason;value.finished_tick=g.state.snapshot.meta.simulation_tick;value.order_kind="regroup";value.has_focus_target_id=false;value.focus_target_id="";value.retreat_remaining_s=0;value.return_remaining_s=0;value.has_return_station_id=true;value.return_station_id=station_id;value.order_revision+=1
	Space.assign(g.state,"ship",hull.ship_instance_id,Space.site_for_anchor(g.catalog,station.station_anchor_id));total().returns+=1;_receipt(value,"return",0);_changed("自有僚舰已归港 · 保留实际损伤、设备与货物")
func _retreat(value: RefCounted,reason: String) -> void:
	var npc: RefCounted=actor(value)
	if npc==null:return
	var position: Vector3=g.position(npc);var direction: Vector3=Vector3.BACK;var nearest: float=INF
	for enemy: RefCounted in g.state.rows("npc_state"):
		if not enemy.alive or not g.same_entity_site("npc",npc,"npc",enemy) or not g.civilizations.hostile_to(npc.npc_instance_id,enemy.npc_instance_id):continue
		var distance: float=position.distance_to(g.position(enemy))
		if distance<nearest:nearest=distance;direction=position-g.position(enemy)
	if direction.is_zero_approx():direction=Vector3.BACK
	var destination: Vector3=position+direction.normalized()*float(balance.retreat_distance_m)
	value.phase="retreating";value.order_kind="retreat";value.has_focus_target_id=false;value.focus_target_id="";value.order_revision+=1;value.end_reason=reason;value.retreat_remaining_s=float(balance.retreat_charge_s)
	value.retreat_origin_x=position.x;value.retreat_origin_y=position.y;value.retreat_origin_z=position.z;value.goal_x=destination.x;value.goal_y=destination.y;value.goal_z=destination.z
	value.return_station_id=nearest_station(npc.sector_id,position);value.has_return_station_id=not value.return_station_id.is_empty();_changed("自有僚舰撤退 · 实际脱离后返回本星系空间站")
func retreat_step(value: RefCounted,delta: float) -> void:
	var npc: RefCounted=actor(value)
	if value.phase!="retreating" or npc==null:return
	var origin: Vector3=Vector3(value.retreat_origin_x,value.retreat_origin_y,value.retreat_origin_z)
	if g.position(npc).distance_to(origin)<float(balance.retreat_distance_m):return
	value.retreat_remaining_s=maxf(0.0,value.retreat_remaining_s-delta)
	if value.retreat_remaining_s>0 or busy(value.ship_instance_id):return
	_remove_actor(value);value.phase="returning";value.return_remaining_s=float(balance.return_s);value.order_revision+=1;_changed("自有僚舰已脱离 · 正返回本星系空间站")
func controlled_ship_lost() -> void:
	for value: RefCounted in active():
		if value.phase=="deployed":_retreat(value,"player_destroyed")
func removal_reason(id: String) -> String:
	var value: RefCounted=row(id)
	if value!=null and value.phase in ["deployed","retreating","returning"]:return "先收回该舰的自有编队部署"
	return "等待该舰已经发出的攻击或无人机结束" if busy(id) else ""
func remove_ship_records(id: String) -> void:
	var hull: RefCounted=ship(id)
	if hull==null:return
	for assignment: RefCounted in g.crew.assigned(id).duplicate():
		var member: RefCounted=g.crew.member(assignment.profile_id);g.state.remove("crew_assignment_state",assignment)
		member.has_station_id=true;member.station_id=hull.station_id;member.revision+=1
	for table: String in ["fleet_receipt_state","auxiliary_intel_state"]:
		for entry: RefCounted in g.state.rows(table).duplicate():
			if entry.get("ship_instance_id" if table=="fleet_receipt_state" else "owner_ship_id")==id:g.state.remove(table,entry)
	var value: RefCounted=row(id)
	if value!=null:g.state.remove("fleet_deployment_state",value)
func tick(delta: float) -> void:
	if not supported():return
	for value: RefCounted in active():
		if value.phase=="returning":
			value.return_remaining_s=maxf(0.0,value.return_remaining_s-delta)
			if value.return_remaining_s<=0:_dock(value,value.return_station_id,value.end_reason)
			continue
		var npc: RefCounted=actor(value);var hull: RefCounted=ship(value.ship_instance_id)
		if npc==null or hull==null:continue
		npc.shield=hull.shield;npc.armor=hull.armor;npc.hull=hull.hull
		if spatial_active and value.phase=="deployed" and g.crew.pilot(value.ship_instance_id)==null:_retreat(value,"crew_unavailable")
		if value.phase=="deployed" and value.order_kind=="focus" and not order_reason(value.ship_instance_id,"focus",value.focus_target_id,g.state.find("npc_state","npc_instance_id",value.focus_target_id).generation if g.state.find("npc_state","npc_instance_id",value.focus_target_id)!=null else 0).is_empty():
			value.order_kind="regroup";value.has_focus_target_id=false;value.focus_target_id="";value.order_revision+=1
func _receipt(value: RefCounted,kind: String,paid: int) -> void:
	var receipt: RefCounted=D.FleetReceiptStateDto.new();receipt.source_token="%s:%d:%s" % [value.ship_instance_id,value.generation,kind];receipt.ship_instance_id=value.ship_instance_id;receipt.generation=value.generation;receipt.event_kind=kind;receipt.paid_credit=paid;receipt.event_tick=g.state.snapshot.meta.simulation_tick;g.state.add("fleet_receipt_state",receipt)
	while g.state.rows("fleet_receipt_state").size()>int(balance.history_limit):g.state.remove("fleet_receipt_state",g.state.rows("fleet_receipt_state")[0])
func _changed(message: String) -> void:g.status_text=message;changed.emit(message);g.request_autosave()
