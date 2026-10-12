extends RefCounted
## Finite paid agency contracts. Physical actions are performed by HirePilot.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
const Binding=preload("res://runtime/data/hire_validation.gd")
var g: RefCounted
var balance: Dictionary={}
var spatial_active: bool=true
var _last_link: bool=true
signal warning_changed(message: String)
signal healed(npc_id: String,ship_id: String,layer: String)

func _init(host: RefCounted) -> void:
	g=host
	if supported():balance=g.rows("hire_balance_defs")[0]
func supported() -> bool:return g!=null and g.catalog.table_names.has("hire_profile_defs")
func profile(id: String) -> Dictionary:return g.definition("hire_profile_defs","profile_id",id) if supported() else {}
func active() -> RefCounted:
	for row: RefCounted in g.state.rows("hire_contract_state"):
		if row.phase in ["deployed","retreating","returning"]:return row
	return null
func actor(row: RefCounted=null) -> RefCounted:
	if row==null:row=active()
	return g.state.find("npc_state","npc_instance_id",row.npc_instance_id) if row!=null and row.has_npc_instance_id else null
func contract_for(id: String) -> RefCounted:
	for row: RefCounted in g.state.rows("hire_contract_state"):
		if row.has_npc_instance_id and row.npc_instance_id==id:return row
	return null
func handles_spawn(id: String) -> bool:return supported() and not g.definition("hire_profile_defs","spawn_id",id).is_empty()
func friendly(id: String) -> bool:return Binding.actor_binding(g.state,g.catalog,id)
func model(id: String) -> String:
	var row: RefCounted=contract_for(id)
	return str(profile(row.profile_id).hull_id) if row!=null else ""
func token() -> String:
	var row: RefCounted=active()
	return "%s:%s:%d" % [row.contract_id,row.phase,row.order_revision] if row!=null else "vacant:%d" % g.state.rows("hire_contract_state").size()
func connected(row: RefCounted=null) -> bool:
	if row==null:row=active()
	var npc: RefCounted=actor(row)
	return npc!=null and npc.alive and g.same_entity_site("ship",g.state.ship(),"npc",npc) and g.position(npc).distance_to(g.position(g.state.ship()))<=float(balance.communication_m)
func hire_reason(id: String) -> String:
	if not supported():return "当前世界尚未升级雇佣规则"
	var spec: Dictionary=profile(id)
	if spec.is_empty():return "未知雇佣配置"
	if active()!=null:return "已有僚舰合同；归港或结算后再雇佣"
	if g.state.ship().status!=T.ShipStatus.DOCKED or g.station().is_empty():return "停靠空间站后雇佣"
	var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",spec.spawn_id)
	if spawn.required_unlock_id!=null and not g.unlocked(spawn.required_unlock_id):return "完成航路教学后开放雇佣"
	if g.state.player().credit<int(spec.hire_fee_credit)+int(spec.deposit_credit):return "信用点不足 · 需雇佣费与押金"
	return ""
func order_reason(order: String,focus_id: String="") -> String:
	var row: RefCounted=active()
	if row==null:return "没有进行中的僚舰合同"
	if row.phase!="deployed":return "僚舰正在脱离或返航"
	if not spatial_active:return "航行转移期间等待编队稳定"
	if not connected(row):return "僚舰失联；先接近或等待归队"
	if order=="dismiss":return "停靠并等僚舰实际归队后解约" if g.state.ship().status!=T.ShipStatus.DOCKED or g.position(actor(row)).distance_to(g.position(g.state.ship()))>float(balance.warp_ready_m) else ""
	if order not in ["advance","regroup","focus","retreat"]:return "未知僚舰指令"
	if order=="focus":return focus_reason(row,focus_id)
	return ""
func focus_reason(row: RefCounted,id: String) -> String:
	var enemy: RefCounted=g.state.find("npc_state","npc_instance_id",id)
	var npc: RefCounted=actor(row)
	if enemy==null or not enemy.alive or npc==null or g.civilizations.friendly(id) or not g.same_entity_site("npc",npc,"npc",enemy):return "选择当前地点中存活的敌人后集火"
	if g.position(npc).distance_to(g.position(enemy))>float(balance.communication_m):return "集火目标超出通信范围"
	return ""
func execute(target: String,expected: String,focus_id: String="") -> bool:
	if not supported():return g.fail("当前世界尚未升级雇佣规则")
	if expected!=token():return g.fail("僚舰合同或指令已变化，请刷新后操作")
	if not profile(target).is_empty():return _hire(target)
	var reason: String=order_reason(target,focus_id)
	if not reason.is_empty():return g.fail(reason)
	var row: RefCounted=active()
	if target=="dismiss":_settle(row,false,"withdrawn");return true
	if target=="retreat":_retreat(row,"withdrawn");return true
	row.order_kind=target;row.order_revision+=1;row.has_focus_target_id=target=="focus";row.focus_target_id=focus_id if row.has_focus_target_id else ""
	var npc: RefCounted=actor(row)
	if target=="regroup":npc.behavior_phase=T.NpcPhase.PATROL
	_changed("僚舰 · "+{"advance":"推进","regroup":"集结","focus":"集火"}[target]);return true
func _hire(id: String) -> bool:
	var reason: String=hire_reason(id)
	if not reason.is_empty():return g.fail(reason)
	if not g.allowed_service("repair"):return false
	var spec: Dictionary=profile(id);var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",spec.spawn_id)
	var stats: Dictionary=g.definition("npc_full_defs","npc_id",spawn.npc_id)
	var npc: RefCounted=D.NpcStateDto.new();npc.npc_instance_id=g.id("companion");npc.spawn_id=spec.spawn_id;npc.sector_id=g.state.current_sector();npc.generation=1;npc.alive=true
	npc.shield=stats.shield_max;npc.armor=stats.armor_max;npc.hull=stats.hull_max;npc.behavior_phase=T.NpcPhase.PATROL;npc.bounty_claimed=true;npc.loot_claimed=true
	var station: Dictionary=g.definition("station_defs","station_id",g.station());var pose: Vector3=g.anchor_position(g.definition("anchor_defs","anchor_id",station.undock_anchor_id))+Vector3(float(balance.formation_m),0.0,float(balance.formation_m)*0.25)
	npc.pos_x=pose.x;npc.pos_y=pose.y;npc.pos_z=pose.z
	var row: RefCounted=D.HireContractStateDto.new();row.contract_id=g.id("hire");row.player_id=g.state.player().player_id;row.profile_id=id;row.origin_station_id=g.station();row.has_npc_instance_id=true;row.npc_instance_id=npc.npc_instance_id
	row.sector_id=npc.sector_id;row.site_id=XJSpaceCoordinates.current_site(g.state);row.lease_remaining_s=float(spec.lease_s);row.fee_paid_credit=int(spec.hire_fee_credit);row.deposit_paid_credit=int(spec.deposit_credit);row.support_cycles_remaining=int(spec.support_cycles);row.created_tick=g.state.snapshot.meta.simulation_tick
	row.goal_x=pose.x;row.goal_y=pose.y;row.goal_z=pose.z
	g.state.player().credit-=row.fee_paid_credit+row.deposit_paid_credit;g.state.add("npc_state",npc);XJSpaceCoordinates.assign(g.state,"npc",npc.npc_instance_id,row.site_id);g.state.add("hire_contract_state",row)
	_receipt(row,"hire",row.fee_paid_credit+row.deposit_paid_credit);_changed("僚舰已受领 · "+str(spec.display_name));return true
func _receipt(row: RefCounted,kind: String,paid: int=0) -> void:
	var receipt: RefCounted=D.HireReceiptStateDto.new();receipt.source_token=row.contract_id+":"+kind;receipt.contract_id=row.contract_id;receipt.event_kind=kind;receipt.paid_credit=paid;receipt.refund_credit=row.refund_credit if kind=="return" else 0;receipt.event_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("hire_receipt_state",receipt)
func _changed(message: String) -> void:
	g.status_text=message;warning_changed.emit(message);g.request_autosave()
func _remove_actor(row: RefCounted) -> void:
	if not row.has_npc_instance_id:return
	for channel: RefCounted in g.state.rows("remote_support_state").duplicate():
		if channel.target_npc_id==row.npc_instance_id:g.ship_roles.stop_support(channel.item_instance_id)
	var npc: RefCounted=actor(row)
	XJSpaceCoordinates.remove(g.state,"npc",row.npc_instance_id)
	if npc!=null:g.state.remove("npc_state",npc)
	row.has_npc_instance_id=false;row.npc_instance_id=""
func _condition(npc: RefCounted) -> float:
	var stats: Dictionary=g.definition("npc_full_defs","npc_id",g.definition("npc_spawn_defs","spawn_id",npc.spawn_id).npc_id)
	return clampf((npc.armor+npc.hull)/(float(stats.armor_max)+float(stats.hull_max)),0.0,1.0)
func _settle(row: RefCounted,lost: bool,reason: String) -> void:
	if row.phase in ["returned","lost"]:return
	var npc: RefCounted=actor(row)
	if npc!=null:row.condition_ratio=_condition(npc)
	if lost:row.condition_ratio=0.0
	_remove_actor(row);row.phase="lost" if lost else "returned";row.end_reason=reason;row.order_kind="retreat";row.has_focus_target_id=false;row.focus_target_id="";row.order_revision+=1
	row.lease_remaining_s=0.0;row.return_remaining_s=0.0;row.retreat_remaining_s=0.0;row.support_cooldown_s=0.0;row.finished_tick=g.state.snapshot.meta.simulation_tick
	row.refund_credit=0 if lost else int(float(row.deposit_paid_credit)*row.condition_ratio)
	g.state.player().credit+=row.refund_credit;_receipt(row,"loss" if lost else "return")
	_changed("僚舰损失 · 押金用于损失补偿" if lost else "僚舰归港 · 退还押金 %d 信用点" % row.refund_credit)
func controlled_ship_lost() -> void:
	var row: RefCounted=active()
	if row!=null and row.phase in ["deployed","retreating"]:_settle(row,true,"player_destroyed")
func _retreat(row: RefCounted,reason: String) -> void:
	var npc: RefCounted=actor(row)
	if npc==null or not npc.alive:_settle(row,true,"destroyed");return
	var start: Vector3=g.position(npc);var away: Vector3=start-g.position(g.state.ship())
	var nearest: float=INF
	for threat: RefCounted in g.state.rows("npc_state"):
		if not threat.alive or g.civilizations.friendly(threat.npc_instance_id) or not g.same_entity_site("npc",npc,"npc",threat):continue
		var distance: float=start.distance_to(g.position(threat))
		if distance<nearest:nearest=distance;away=start-g.position(threat)
	if away.is_zero_approx():away=Vector3.BACK
	var flank: Vector3=Vector3.UP.cross(away.normalized()).normalized()
	if flank.is_zero_approx():flank=Vector3.RIGHT
	var destination: Vector3=start+(away.normalized()+flank).normalized()*float(balance.retreat_distance_m)
	row.phase="retreating";row.order_kind="retreat";row.order_revision+=1;row.has_focus_target_id=false;row.focus_target_id="";row.end_reason=reason;row.retreat_remaining_s=float(balance.retreat_charge_s)
	row.retreat_origin_x=start.x;row.retreat_origin_y=start.y;row.retreat_origin_z=start.z;row.goal_x=destination.x;row.goal_y=destination.y;row.goal_z=destination.z;npc.behavior_phase=T.NpcPhase.RETURN
	_changed("僚舰撤退 · 先脱离交战位置，再返回雇佣站")
func tick(delta: float) -> void:
	if not supported():return
	var row: RefCounted=active()
	if row==null:return
	if row.phase=="returning":
		row.return_remaining_s=maxf(0.0,row.return_remaining_s-delta)
		if row.return_remaining_s<=0.0:_settle(row,false,row.end_reason)
		return
	var npc: RefCounted=actor(row)
	if npc==null or not npc.alive:_settle(row,true,"destroyed");return
	if g.state.ship().status==T.ShipStatus.DESTROYED:_settle(row,true,"player_destroyed");return
	row.lease_remaining_s=maxf(0.0,row.lease_remaining_s-delta);row.support_cooldown_s=maxf(0.0,row.support_cooldown_s-delta)
	if row.phase=="retreating":return
	if spatial_active:
		var linked: bool=connected(row)
		if linked!=_last_link:warning_changed.emit("僚舰通信已恢复" if linked else "僚舰失联 · 先接近原地点归队")
		_last_link=linked
	if not row.expiry_warned and row.lease_remaining_s<=float(balance.warning_s):row.expiry_warned=true;warning_changed.emit("僚舰租期即将结束 · 准备归港")
	if row.lease_remaining_s<=0.0 and spatial_active:_retreat(row,"expired");return
	if row.order_kind=="focus" and not focus_reason(row,row.focus_target_id).is_empty():
		row.order_kind="regroup";row.order_revision+=1;row.has_focus_target_id=false;row.focus_target_id="";npc.behavior_phase=T.NpcPhase.PATROL;_changed("僚舰集火目标失效 · 返回编队")
func retreat_step(row: RefCounted,delta: float) -> void:
	if row.phase!="retreating" or not spatial_active:return
	var npc: RefCounted=actor(row)
	if npc==null:return
	var start: Vector3=Vector3(row.retreat_origin_x,row.retreat_origin_y,row.retreat_origin_z)
	if g.position(npc).distance_to(start)<float(balance.retreat_distance_m):return
	row.retreat_remaining_s=maxf(0.0,row.retreat_remaining_s-delta)
	if row.retreat_remaining_s>0.0:return
	row.condition_ratio=_condition(npc);_remove_actor(row);row.phase="returning";row.lease_remaining_s=0.0;row.return_remaining_s=float(balance.return_s);row.support_cooldown_s=0.0;row.order_revision+=1
	_changed("僚舰已脱离 · 返航 %.0f 秒" % row.return_remaining_s)
func repair_step(row: RefCounted) -> String:
	if row.phase!="deployed" or profile(row.profile_id).role_id!="support" or not spatial_active or not connected(row) or row.lease_remaining_s<=0.0 or row.support_cycles_remaining<=0 or row.support_cooldown_s>0.0 or g.state.ship().status!=T.ShipStatus.FLYING:return ""
	var ship: RefCounted=g.state.ship();var metrics: Dictionary=g.metrics(ship);var layer: String=""
	if ship.shield<float(metrics.shield_max):layer="shield"
	elif ship.armor<float(metrics.armor_max):layer="armor"
	if layer.is_empty():return ""
	var before: float=float(ship.get(layer))
	ship.set(layer,minf(float(metrics[layer+"_max"]),before+float(balance["support_"+layer])))
	g.telemetry.repair("received",float(ship.get(layer))-before)
	row.support_cycles_remaining-=1;row.support_cooldown_s=float(balance.support_cycle_s);healed.emit(row.npc_instance_id,ship.ship_instance_id,layer)
	if row.support_cycles_remaining==0:warning_changed.emit("僚舰维修储备耗尽 · 可归港重新雇佣")
	return layer
func travel_reason() -> String:return Binding.travel_reason(g.state,g.catalog)
func party_mass_kg() -> float:
	return Binding.party_mass(g.state,g.catalog)
func party_fee(base: int) -> int:return Binding.party_fee(g.state,g.catalog,base)
func departure_pose() -> Dictionary:
	var row: RefCounted=active();var npc: RefCounted=actor(row)
	if row==null or row.phase!="deployed" or npc==null:return {}
	var pose: Dictionary={"world":g.state.world_id,"contract":row.contract_id,"npc":npc.npc_instance_id,"sector":row.sector_id,"site":row.site_id,"goal":Vector3(row.goal_x,row.goal_y,row.goal_z)}
	for key: String in ["pos_x","pos_y","pos_z","quat_x","quat_y","quat_z","quat_w","vel_x","vel_y","vel_z"]:pose[key]=npc.get(key)
	return pose
func restore_departure(pose: Dictionary) -> void:
	var row: RefCounted=active();var npc: RefCounted=actor(row)
	if pose.is_empty() or row==null or npc==null or pose.world!=g.state.world_id or pose.contract!=row.contract_id or pose.npc!=npc.npc_instance_id:return
	for key: String in ["pos_x","pos_y","pos_z","quat_x","quat_y","quat_z","quat_w","vel_x","vel_y","vel_z"]:npc.set(key,pose[key])
	row.sector_id=pose.sector;row.site_id=pose.site;row.goal_x=pose.goal.x;row.goal_y=pose.goal.y;row.goal_z=pose.goal.z;row.order_kind="regroup";row.has_focus_target_id=false;row.focus_target_id="";row.order_revision+=1
	npc.sector_id=row.sector_id;npc.behavior_phase=T.NpcPhase.PATROL;XJSpaceCoordinates.assign(g.state,"npc",npc.npc_instance_id,row.site_id)
func follow_arrival() -> void:
	var row: RefCounted=active();var npc: RefCounted=actor(row)
	if row==null or row.phase!="deployed" or npc==null:return
	var pose: Vector3=g.position(g.state.ship())+Vector3(float(balance.formation_m),0.0,float(balance.formation_m)*0.25)
	row.sector_id=g.state.current_sector();row.site_id=XJSpaceCoordinates.current_site(g.state);row.order_kind="regroup";row.has_focus_target_id=false;row.focus_target_id="";row.order_revision+=1;row.goal_x=pose.x;row.goal_y=pose.y;row.goal_z=pose.z
	npc.sector_id=row.sector_id;npc.pos_x=pose.x;npc.pos_y=pose.y;npc.pos_z=pose.z;npc.vel_x=0.0;npc.vel_y=0.0;npc.vel_z=0.0;npc.behavior_phase=T.NpcPhase.PATROL
	XJSpaceCoordinates.assign(g.state,"npc",npc.npc_instance_id,row.site_id)
func status_text() -> String:
	var row: RefCounted=active()
	if row==null:return "暂无雇佣僚舰"
	if row.phase=="returning":return "返航 · %.0f秒" % row.return_remaining_s
	if row.phase=="retreating":return "撤退 · 脱离后准备 %.1f秒" % row.retreat_remaining_s
	if not spatial_active:return "编队跃迁 · 租期 %.0f秒" % row.lease_remaining_s
	return "%s · %s · 租期 %.0f秒" % [profile(row.profile_id).display_name,{"advance":"推进","regroup":"集结","focus":"集火"}[row.order_kind] if connected(row) else "失联",row.lease_remaining_s]
