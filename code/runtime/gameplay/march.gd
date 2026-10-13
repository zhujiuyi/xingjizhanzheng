extends RefCounted
## Original war actors travel through actual sites/gates. Unloaded local motion
## is coarse; loaded actors remain in the existing body/projectile pipeline.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
const Space=preload("res://runtime/space_coordinates.gd")
const Units=preload("res://runtime/space_units.gd")
var g: RefCounted
var balance: Dictionary={}
var spatial_active: bool=false

func _init(game: RefCounted) -> void:
	g=game
	if supported():balance=g.rows("march_balance_defs")[0]

func supported() -> bool:return g.catalog.table_names.has("march_balance_defs")
func state_for(war_id: String) -> RefCounted:return g.state.find("march_state","war_id",war_id)
func member(id: String) -> RefCounted:return g.state.find("march_member_state","npc_instance_id",id)
func definition(war_id: String) -> Dictionary:return g.definition("march_campaign_defs","war_id",war_id)
func active(row: RefCounted) -> bool:return row!=null and row.phase not in ["arrived","returned","failed","cancelled","completed"]

func quote_reason(war_id: String) -> String:
	if not supported():return ""
	var spec: Dictionary=definition(war_id)
	if spec.is_empty():return "战役行军路线缺失"
	var hull: Dictionary=g.definition("ship_defs","ship_id",spec.travel_hull_id)
	var material: Dictionary=g.definition("item_defs","item_id",g.frontier.balance.material_id)
	var count: int=0
	for original: Dictionary in g.rows("civilization_war_members"):
		if original.war_id==war_id and original.side=="ally":count+=1
	var payload: float=float(g.frontier.balance.supply_units)*float(material.unit_mass_kg)
	for leg: Dictionary in g.rows("march_route_defs"):
		if leg.war_id!=war_id:continue
		var endpoint: Dictionary=g.definition("gate_endpoint_defs","endpoint_id",leg.endpoint_id)
		if not str(endpoint.required_unlock_id).is_empty() and not g.unlocked(str(endpoint.required_unlock_id)):return "行军航门许可未解锁"
		var connection: Dictionary=g.definition("effective_connection_defs","connection_id",endpoint.connection_id)
		var gate: RefCounted=g.state.find("gate_state","connection_id",endpoint.connection_id)
		if gate==null or not gate.enabled or (gate.has_lifetime_remaining_s and gate.lifetime_remaining_s<=0):return "行军路线存在关闭的航门"
		if float(hull.dry_mass_kg)+payload>float(connection.max_gross_mass_kg):return "行军舰体超出航门吨位"
		if gate.has_remaining_mass_budget_kg and float(hull.dry_mass_kg)*count+payload>gate.remaining_mass_budget_kg:return "行军航门剩余质量不足"
	return ""

func protects_identity(id: String) -> bool:return member(id)!=null

func has_local_member(sector_id: String,site_id: String) -> bool:
	for m: RefCounted in g.state.rows("march_member_state"):
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",m.npc_instance_id)
		if npc!=null and npc.alive and m.sector_id==sector_id and m.site_id==site_id and not hidden(m.npc_instance_id):return true
	return false

func members(row: RefCounted,alive_only: bool=false) -> Array[RefCounted]:
	var result: Array[RefCounted]=[]
	for m: RefCounted in g.state.rows("march_member_state"):
		if m.war_id!=row.war_id or m.attempt!=row.attempt:continue
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",m.npc_instance_id)
		if not alive_only or (npc!=null and npc.alive and m.phase!="lost"):result.append(m)
	return result

func route(row: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for leg: Dictionary in g.rows("march_route_defs"):
		if leg.war_id==row.war_id:result.append(leg)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return int(a.leg_index)<int(b.leg_index))
	return result

func hidden(id: String) -> bool:
	var m: RefCounted=member(id)
	var row: RefCounted=state_for(m.war_id) if m!=null else null
	return row!=null and row.attempt==m.attempt and (row.phase=="site_warp" or m.phase=="gate_transit") and m.phase!="lost"

func holds_campaign(war: RefCounted) -> bool:
	var row: RefCounted=state_for(war.war_id)
	return row!=null and row.attempt==war.attempt and active(row)

func start(war: RefCounted) -> void:
	if not supported():return
	var spec: Dictionary=definition(war.war_id)
	var station: Dictionary=g.definition("station_defs","station_id",spec.origin_station_id)
	var anchor: Dictionary=g.definition("anchor_defs","anchor_id",station.undock_anchor_id)
	var row: RefCounted=state_for(war.war_id)
	if row!=null:g.state.remove("march_state",row)
	row=D.MarchStateDto.new();row.war_id=war.war_id;row.attempt=war.attempt;row.phase="assembling";row.direction=1
	row.sector_id=station.sector_id;row.site_id=Space.site_for_anchor(g.catalog,anchor.anchor_id);row.goal_anchor_id=anchor.anchor_id
	row.phase_remaining_s=float(balance.assembly_s);row.started_tick=g.state.snapshot.meta.simulation_tick
	row.initial_supply_units=g.frontier.campaign(war.war_id).supplies_paid_units
	g.state.add("march_state",row)
	var allies: Array[RefCounted]=[]
	for fleet: RefCounted in g.state.rows("war_fleet_state"):
		if fleet.war_id==war.war_id and fleet.side=="ally":allies.append(fleet)
	for index: int in range(allies.size()):
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",allies[index].npc_instance_id)
		# This is the initial funded assembly, never an intermediate respawn.
		g.frontier._revive(npc)
		var m: RefCounted=D.MarchMemberStateDto.new();m.npc_instance_id=npc.npc_instance_id;m.spawn_id=npc.spawn_id;m.war_id=war.war_id;m.attempt=war.attempt
		m.ship_def_id=spec.travel_hull_id;m.phase="active";m.cargo_units=row.initial_supply_units if npc.spawn_id==spec.supply_carrier_spawn_id else 0
		g.state.add("march_member_state",m)
		_place(npc,m,anchor,Vector3(0,0,float(balance.gate_exit_m))+_formation(index,allies.size()))
		_goal(m,g.position(npc))
	_journal(row,"start",row.initial_supply_units)
	g.frontier.warning_changed.emit("舰队正在核心站集结 · 将沿航门前往战区")

func cleanup_members(war_id: String) -> void:
	for m: RefCounted in g.state.rows("march_member_state").duplicate():
		if m.war_id==war_id:g.state.remove("march_member_state",m)

func finished(war_id: String,status: String) -> void:
	var row: RefCounted=state_for(war_id)
	if row==null:return
	row.has_gate_actor_id=false;row.gate_actor_id=""
	if row.phase!="returned":
		for m: RefCounted in members(row):row.lost_supply_units+=m.cargo_units;m.cargo_units=0
		row.phase="completed" if status=="won" else status
	row.finished_tick=g.state.snapshot.meta.simulation_tick
	_journal(row,"finish")
	cleanup_members(war_id)

func request_retreat(war: RefCounted) -> bool:
	var row: RefCounted=state_for(war.war_id)
	if row==null or row.attempt!=war.attempt or row.phase in ["returned","failed","cancelled","completed"]:return false
	row.retreat_requested=true;war.fleet_order="advance";war.focus_target_id=""
	_journal(row,"retreat")
	if row.phase not in ["site_warp","gate_transit"] and not _partial_gate(row):_reverse(row)
	g.request_autosave();return true

func local_plan(id: String) -> Dictionary:
	var m: RefCounted=member(id)
	if m==null:return {}
	var row: RefCounted=state_for(m.war_id)
	if not active(row) or m.phase=="lost":return {}
	var selected: bool=row.has_gate_actor_id and row.gate_actor_id==id
	var hold: bool=m.phase=="gate_wait" or row.phase in ["assembling","blocked","gate_transit"] or (row.phase=="gate_prepare" and not selected) or hidden(id)
	var result: Dictionary={"destination":Vector3(m.goal_x,m.goal_y,m.goal_z),"hold":hold}
	if row.phase=="gate_prepare" and selected:result.stop_radius=float(balance.gate_stop_m)
	return result

func _formation(index: int,count: int) -> Vector3:
	var distance: float=float(balance.formation_m)
	return Vector3((float(index)-float(count-1)*0.5)*distance,distance*(0.25 if index%2 else -0.25),0)

func _goal(m: RefCounted,position: Vector3) -> void:m.goal_x=position.x;m.goal_y=position.y;m.goal_z=position.z

func _place(npc: RefCounted,m: RefCounted,anchor: Dictionary,offset: Vector3) -> void:
	npc.sector_id=anchor.sector_id;var attitude: Basis=Basis(Vector3.UP,float(anchor.yaw_rad));var position: Vector3=g.anchor_position(anchor)+attitude*offset
	npc.pos_x=position.x;npc.pos_y=position.y;npc.pos_z=position.z;npc.vel_x=0;npc.vel_y=0;npc.vel_z=0
	var rotation: Quaternion=attitude.get_rotation_quaternion();npc.quat_x=rotation.x;npc.quat_y=rotation.y;npc.quat_z=rotation.z;npc.quat_w=rotation.w
	g.assign_anchor_site("npc",npc.npc_instance_id,anchor.anchor_id)
	m.sector_id=npc.sector_id;m.site_id=g.spatial_site("npc",npc.npc_instance_id)

func _phase(row: RefCounted,phase: String,seconds: float=0.0) -> void:
	row.phase=phase;row.phase_remaining_s=seconds;row.revision+=1;g.request_autosave()

func _endpoint(row: RefCounted) -> Dictionary:
	var legs: Array[Dictionary]=route(row);var index: int=row.completed_legs if row.direction==1 else row.completed_legs-1
	if index<0 or index>=legs.size():return {}
	return g.definition("gate_endpoint_defs","endpoint_id",legs[index].endpoint_id if row.direction==1 else legs[index].reverse_endpoint_id)

func _next(row: RefCounted) -> void:
	var endpoint: Dictionary=_endpoint(row);var spec: Dictionary=definition(row.war_id)
	if endpoint.is_empty():
		row.goal_anchor_id=spec.destination_anchor_id if row.direction==1 else g.definition("station_defs","station_id",spec.origin_station_id).undock_anchor_id
	else:row.goal_anchor_id=endpoint.entry_anchor_id
	var anchor: Dictionary=g.definition("anchor_defs","anchor_id",row.goal_anchor_id)
	var group: Array[RefCounted]=members(row,true)
	if Space.site_for_anchor(g.catalog,row.goal_anchor_id)==row.site_id:
		for index: int in range(group.size()):
			var offset: Vector3=_formation(index,group.size())
			if not endpoint.is_empty():offset+=Vector3(0,0,float(balance.gate_exit_m))
			_goal(group[index],g.anchor_position(anchor)+Basis(Vector3.UP,float(anchor.yaw_rad))*offset)
		_phase(row,"arrival_approach" if endpoint.is_empty() else "gate_approach");return
	for m: RefCounted in group:
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",m.npc_instance_id)
		var direction: Vector3=Space.anchor_direction(g.state,g.catalog,npc,anchor)
		_goal(m,g.position(npc)+direction*float(balance.clear_distance_m))
	_phase(row,"site_align",float(balance.align_s))

func _reverse(row: RefCounted) -> void:
	row.direction=-1;row.retreat_requested=false;row.blocked_reason="";row.blocked_elapsed_s=0;row.has_gate_actor_id=false;row.gate_actor_id=""
	for m: RefCounted in members(row,true):m.phase="active"
	_next(row)

func _at_goals(row: RefCounted) -> bool:
	for m: RefCounted in members(row,true):
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",m.npc_instance_id)
		if g.position(npc).distance_to(Vector3(m.goal_x,m.goal_y,m.goal_z))>float(balance.arrival_radius_m):return false
	return true

func _coarse(row: RefCounted,delta: float,only_selected: bool=false) -> void:
	for m: RefCounted in members(row,true):
		if m.phase in ["gate_wait","gate_transit"] or (only_selected and m.npc_instance_id!=row.gate_actor_id):continue
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",m.npc_instance_id)
		if spatial_active and g.state.ship().status==T.ShipStatus.FLYING and g.same_entity_site("npc",npc,"ship",g.state.ship()):continue
		var before: Vector3=g.position(npc);var goal: Vector3=Vector3(m.goal_x,m.goal_y,m.goal_z)
		var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",npc.spawn_id)
		var speed: float=float(g.definition("npc_full_defs","npc_id",spawn.npc_id).speed_mps)
		var position: Vector3=before.move_toward(goal,speed*delta)
		npc.pos_x=position.x;npc.pos_y=position.y;npc.pos_z=position.z
		var velocity: Vector3=(position-before)/maxf(delta,0.000001)
		npc.vel_x=velocity.x;npc.vel_y=velocity.y;npc.vel_z=velocity.z;m.moved_distance_m+=before.distance_to(position)

func record_motion(id: String,before: Vector3,after: Vector3) -> void:
	var m: RefCounted=member(id)
	if m!=null and active(state_for(m.war_id)):m.moved_distance_m+=before.distance_to(after)

func _hold_coarse(row: RefCounted,moving_id: String="") -> void:
	for m: RefCounted in members(row,true):
		if m.npc_instance_id==moving_id:continue
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",m.npc_instance_id)
		if spatial_active and g.state.ship().status==T.ShipStatus.FLYING and g.same_entity_site("npc",npc,"ship",g.state.ship()):continue
		npc.vel_x=0;npc.vel_y=0;npc.vel_z=0

func _gate_stationary(row: RefCounted) -> bool:
	var endpoint: Dictionary=_endpoint(row)
	var anchor: Dictionary=g.definition("anchor_defs","anchor_id",endpoint.entry_anchor_id)
	var npc: RefCounted=g.state.find("npc_state","npc_instance_id",row.gate_actor_id) if row.has_gate_actor_id else null
	return npc!=null and npc.alive and g.position(npc).distance_to(g.anchor_position(anchor))<=g.rule("gate_entry_radius_m") and g.velocity(npc).length()<=g.rule("gate_max_entry_speed_mps")

func _partial_gate(row: RefCounted) -> bool:
	for m: RefCounted in members(row,true):
		if m.completed_legs!=row.completed_legs:return true
	return false

func _pending_gate(row: RefCounted) -> Array[RefCounted]:
	var pending: Array[RefCounted]=[]
	for m: RefCounted in members(row,true):
		if m.completed_legs==row.completed_legs:pending.append(m)
	pending.sort_custom(func(a: RefCounted,b: RefCounted) -> bool:return int(g.definition("civilization_war_members","spawn_id",a.spawn_id).formation_index)<int(g.definition("civilization_war_members","spawn_id",b.spawn_id).formation_index))
	return pending

func _advance_gate(row: RefCounted) -> void:
	row.has_gate_actor_id=false;row.gate_actor_id=""
	var endpoint: Dictionary=_endpoint(row);var pending: Array[RefCounted]=_pending_gate(row)
	if pending.is_empty():
		var exit_anchor: Dictionary=g.definition("anchor_defs","anchor_id",endpoint.exit_anchor_id)
		row.completed_legs+=row.direction;row.sector_id=exit_anchor.sector_id;row.site_id=Space.site_for_anchor(g.catalog,exit_anchor.anchor_id)
		for m: RefCounted in members(row,true):m.phase="active"
		if row.retreat_requested:_reverse(row)
		else:_next(row)
		return
	var selected: RefCounted=pending[0];var entry_anchor: Dictionary=g.definition("anchor_defs","anchor_id",endpoint.entry_anchor_id)
	row.has_gate_actor_id=true;row.gate_actor_id=selected.npc_instance_id
	_goal(selected,g.anchor_position(entry_anchor)+Basis(Vector3.UP,float(entry_anchor.yaw_rad))*Vector3(0,0,float(balance.gate_approach_m)))
	var connection: Dictionary=g.definition("effective_connection_defs","connection_id",endpoint.connection_id)
	_phase(row,"gate_prepare",float(connection.prepare_s))

func member_mass(m: RefCounted) -> float:
	var material: Dictionary=g.definition("item_defs","item_id",g.frontier.balance.material_id)
	return float(g.definition("ship_defs","ship_id",m.ship_def_id).dry_mass_kg)+float(material.unit_mass_kg)*m.cargo_units

func mass(row: RefCounted,largest: bool=false) -> float:
	var result: float=0.0
	for m: RefCounted in members(row,true):
		var value: float=member_mass(m)
		result=maxf(result,value) if largest else result+value
	return result

func _gate_reason(row: RefCounted) -> String:
	var endpoint: Dictionary=_endpoint(row)
	if endpoint.is_empty():return "行军航段缺失"
	if not str(endpoint.required_unlock_id).is_empty() and not g.unlocked(str(endpoint.required_unlock_id)):return "航门许可未解锁"
	var connection: Dictionary=g.definition("effective_connection_defs","connection_id",endpoint.connection_id)
	var gate: RefCounted=g.state.find("gate_state","connection_id",endpoint.connection_id)
	if gate==null or not gate.enabled:return "航门关闭"
	if gate.has_lifetime_remaining_s and gate.lifetime_remaining_s<=0:return "航门已消失"
	if largest_mass_exceeds(row,connection):return "编队舰体超出航门吨位"
	var pending_mass: float=0.0
	for m: RefCounted in _pending_gate(row):pending_mass+=member_mass(m)
	if gate.has_remaining_mass_budget_kg and pending_mass>gate.remaining_mass_budget_kg:return "航门剩余通行质量不足"
	var selected: RefCounted=member(row.gate_actor_id) if row.has_gate_actor_id else null
	if selected!=null and selected.gate_cooldown_remaining_s>0:return "舰船跃迁冷却"
	return ""

func largest_mass_exceeds(row: RefCounted,connection: Dictionary) -> bool:return mass(row,true)>float(connection.max_gross_mass_kg)

func _journal(row: RefCounted,kind: String,material: int=0,endpoint: String="",weight: float=0.0,npc: String="") -> void:
	var event: RefCounted=D.MarchJournalStateDto.new()
	event.source_token="%s:%d:%d:%s:%s" % [row.war_id,row.attempt,row.revision,kind,npc]
	if g.state.find("march_journal_state","source_token",event.source_token)!=null:return
	event.war_id=row.war_id;event.attempt=row.attempt;event.event_kind=kind;event.sector_id=row.sector_id;event.completed_legs=row.completed_legs;event.direction=row.direction
	event.has_endpoint_id=not endpoint.is_empty();event.endpoint_id=endpoint;event.has_npc_instance_id=not npc.is_empty();event.npc_instance_id=npc
	event.material_units=material;event.mass_kg=weight;event.event_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("march_journal_state",event)
	while g.state.rows("march_journal_state").size()>int(balance.history_limit):g.state.remove("march_journal_state",g.state.rows("march_journal_state")[0])

func _losses(row: RefCounted) -> bool:
	var carrier_lost: bool=false
	for m: RefCounted in members(row):
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",m.npc_instance_id)
		if m.phase=="lost" or (npc!=null and npc.alive):continue
		m.phase="lost";m.lost_tick=g.state.snapshot.meta.simulation_tick;row.lost_supply_units+=m.cargo_units
		carrier_lost=carrier_lost or m.cargo_units>0;_journal(row,"member_loss",m.cargo_units,"",0,m.npc_instance_id);m.cargo_units=0
	return carrier_lost or members(row,true).is_empty()

func destroyed(npc: RefCounted) -> void:
	var m: RefCounted=member(npc.npc_instance_id)
	if m==null:return
	var row: RefCounted=state_for(m.war_id)
	if _losses(row):g.frontier._fail(g.civilizations.active_war(),"failed")
	else:
		if row.has_gate_actor_id and row.gate_actor_id==npc.npc_instance_id:_advance_gate(row)
		g.request_autosave()

func _arrive(row: RefCounted) -> void:
	if row.direction==-1:
		var cargo: int=0
		for m: RefCounted in members(row):cargo+=m.cargo_units;m.cargo_units=0
		var refund: int=floori(float(cargo)*float(balance.return_supply_ratio))
		var station: String=str(definition(row.war_id).origin_station_id)
		if refund>0:g.inventory.grant(g.inventory.warehouse(station),g.frontier.balance.material_id,refund)
		row.returned_supply_units+=refund;row.lost_supply_units+=cargo-refund;_phase(row,"returned");_journal(row,"return",refund)
		g.civilizations._finish(g.civilizations.active_war(),"cancelled");return
	for m: RefCounted in members(row):row.transferred_supply_units+=m.cargo_units;m.cargo_units=0;m.phase="released" if m.phase!="lost" else "lost"
	_phase(row,"arrived");_journal(row,"cargo_transfer",row.transferred_supply_units)
	g.frontier.warning_changed.emit("舰队与补给已抵达战区 · 继续侦察和护送准备")

func tick(delta: float) -> void:
	if not supported():return
	var war: RefCounted=g.civilizations.active_war()
	if war==null:return
	var row: RefCounted=state_for(war.war_id)
	if row==null or row.attempt!=war.attempt:return
	if _losses(row):g.frontier._fail(war,"failed");return
	if not active(row):return
	for m: RefCounted in members(row,true):m.gate_cooldown_remaining_s=maxf(0,m.gate_cooldown_remaining_s-delta)
	if g.state.ship().status==T.ShipStatus.DESTROYED:g.frontier._fail(war,"failed");return
	if war.fleet_order=="focus":
		var target: RefCounted=g.state.find("npc_state","npc_instance_id",war.focus_target_id)
		if target==null or not target.alive or not has_local_member(target.sector_id,g.spatial_site("npc",target.npc_instance_id)):
			war.fleet_order="advance";war.focus_target_id=""
	if war.fleet_order in ["regroup","focus"] and row.phase not in ["site_warp","gate_transit"]:return
	if row.phase in ["assembling","gate_prepare","gate_transit","blocked"]:_hold_coarse(row,row.gate_actor_id if row.phase=="gate_prepare" and row.has_gate_actor_id else "")
	if row.phase=="blocked":
		var reason: String=_gate_reason(row)
		if reason.is_empty():
			row.blocked_reason="";row.blocked_elapsed_s=0
			var duration: float=float(g.definition("effective_connection_defs","connection_id",_endpoint(row).connection_id).prepare_s) if row.resume_phase=="gate_prepare" else 0.0
			_phase(row,row.resume_phase,duration)
		else:
			row.blocked_reason=reason;row.blocked_elapsed_s+=delta
			if row.blocked_elapsed_s>=float(balance.max_blocked_s):g.frontier._fail(war,"failed")
		return
	if row.phase in ["site_align","gate_approach","arrival_approach"]:_coarse(row,delta)
	if row.phase=="gate_prepare":_coarse(row,delta,true)
	if row.phase=="assembling":
		row.phase_remaining_s=maxf(0,row.phase_remaining_s-delta)
		if row.phase_remaining_s<=0:_next(row)
	elif row.phase=="site_align" and _at_goals(row):
		row.phase_remaining_s=maxf(0,row.phase_remaining_s-delta)
		if row.phase_remaining_s<=0:
			var anchor: Dictionary=g.definition("anchor_defs","anchor_id",row.goal_anchor_id)
			var first: RefCounted=g.state.find("npc_state","npc_instance_id",members(row,true)[0].npc_instance_id)
			var distance: float=Space.anchor_distance(g.state,g.catalog,first,anchor)/Units.METRES_PER_AU
			_phase(row,"site_warp",clampf(distance/float(balance.warp_speed_au_s),float(balance.warp_min_s),float(balance.warp_max_s)));_journal(row,"site_departure")
	elif row.phase=="site_warp":
		row.phase_remaining_s=maxf(0,row.phase_remaining_s-delta)
		if row.phase_remaining_s<=0:
			var anchor: Dictionary=g.definition("anchor_defs","anchor_id",row.goal_anchor_id);var group: Array[RefCounted]=members(row,true)
			for index: int in range(group.size()):_place(g.state.find("npc_state","npc_instance_id",group[index].npc_instance_id),group[index],anchor,Vector3(0,0,float(balance.gate_exit_m))+_formation(index,group.size()))
			row.sector_id=anchor.sector_id;row.site_id=Space.site_for_anchor(g.catalog,anchor.anchor_id);_journal(row,"site_arrival")
			if row.retreat_requested:_reverse(row)
			else:_next(row)
	elif row.phase=="gate_approach" and _at_goals(row):
		var reason: String=_gate_reason(row)
		if not reason.is_empty():_block(row,reason);return
		_advance_gate(row)
	elif row.phase=="gate_prepare":
		var selected: RefCounted=member(row.gate_actor_id) if row.has_gate_actor_id else null
		if selected==null or selected.phase=="lost":_advance_gate(row);return
		var connection: Dictionary=g.definition("effective_connection_defs","connection_id",_endpoint(row).connection_id)
		if not _gate_stationary(row):row.phase_remaining_s=float(connection.prepare_s);return
		var reason: String=_gate_reason(row)
		if not reason.is_empty():_block(row,reason);return
		row.phase_remaining_s=maxf(0,row.phase_remaining_s-delta)
		if row.phase_remaining_s<=0:
			var endpoint: Dictionary=_endpoint(row)
			var gate: RefCounted=g.state.find("gate_state","connection_id",endpoint.connection_id);var weight: float=member_mass(selected)
			if gate.has_remaining_mass_budget_kg:gate.remaining_mass_budget_kg-=weight
			selected.gate_cooldown_remaining_s=float(connection.cooldown_s);selected.phase="gate_transit"
			_phase(row,"gate_transit",float(balance.gate_transit_s));_journal(row,"gate",0,endpoint.endpoint_id,weight,selected.npc_instance_id)
	elif row.phase=="gate_transit":
		row.phase_remaining_s=maxf(0,row.phase_remaining_s-delta)
		if row.phase_remaining_s<=0:
			var selected: RefCounted=member(row.gate_actor_id) if row.has_gate_actor_id else null
			if selected!=null and selected.phase!="lost":
				var endpoint: Dictionary=_endpoint(row);var anchor: Dictionary=g.definition("anchor_defs","anchor_id",endpoint.exit_anchor_id)
				var original: Dictionary=g.definition("civilization_war_members","spawn_id",selected.spawn_id)
				_place(g.state.find("npc_state","npc_instance_id",selected.npc_instance_id),selected,anchor,Vector3(0,0,float(balance.gate_exit_m))+_formation(int(original.formation_index),members(row).size()))
				selected.completed_legs+=row.direction;selected.phase="gate_wait";_goal(selected,g.position(g.state.find("npc_state","npc_instance_id",selected.npc_instance_id)))
			_advance_gate(row)
	elif row.phase=="arrival_approach" and _at_goals(row):_arrive(row)

func _block(row: RefCounted,reason: String) -> void:
	# Invalidating a charge restarts the full preparation after the gate clears.
	row.resume_phase=row.phase;row.blocked_reason=reason;row.blocked_elapsed_s=0;_phase(row,"blocked");_journal(row,"blocked")

func view(war_id: String) -> Dictionary:
	var row: RefCounted=state_for(war_id)
	if row==null:return {}
	var sector: Dictionary=g.definition("sector_defs","sector_id",row.sector_id)
	var labels: Dictionary={"assembling":"核心站集结","site_align":"对齐下一地点","site_warp":"星系内跃迁","gate_approach":"接近航门","gate_prepare":"航门充能","gate_transit":"跨越航门","arrival_approach":"接近集结点","arrived":"已抵达战区","blocked":"航路受阻","returned":"已返回核心站","failed":"行军失败","cancelled":"已取消","completed":"战役完成"}
	return {"phase":row.phase,"label":labels.get(row.phase,row.phase),"sector_id":row.sector_id,"site_id":row.site_id,"sector_name":sector.get("display_name",row.sector_id),"completed_legs":row.completed_legs,"total_legs":route(row).size(),"returning":row.direction==-1,"remaining_s":row.phase_remaining_s,"blocked_reason":row.blocked_reason,"members":members(row,true).size(),"goal_anchor_id":row.goal_anchor_id}
