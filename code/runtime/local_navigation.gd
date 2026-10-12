class_name XJLocalNavigation
extends RefCounted
## Single active owner of flight motion. Main saves stable boundaries and routes dock.
signal changed(mode: String, phase: String, message: String)
signal arrived(target_id: String)
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
const Rules = preload("res://runtime/local_navigation_rules.gd")
const Space = preload("res://runtime/space_coordinates.gd")
const Party = preload("res://runtime/data/party_rules.gd")
var rules: Rules = Rules.new()
var world: XJSector
var state: XJRuntimeState
var catalog: XJCatalog
var gameplay: RefCounted
var stable: Callable
var mode: String = ""
var phase: String = "idle"
var target_id: String = ""
var _target_site_snapshot: String = ""
var last_error: String = ""
var remaining_s: float = 0.0
var origin: Vector3 = Vector3.ZERO
var destination: Vector3 = Vector3.ZERO
var last_safe_position: Vector3 = Vector3.ZERO
var _safe_positions: Array[Vector3] = []
var orbit_normal: Vector3 = Vector3.UP
var _ship_id: String = ""
var _sector_id: String = ""
var _configured: bool = false
var combat_managed: bool = false
var combat_distance_m: float = 0.0
var path_length_m: float = 0.0
var travel_duration_s: float = 0.0
var travel_elapsed_s: float = 0.0
var warp_heading: Vector3 = Vector3.FORWARD
var _origin_site: String = ""
var _companion_origin: Dictionary = {}
var _owned_origin: Array[Dictionary] = []
var _owned_shapes: Dictionary = {}
var _destination_site: String = ""
var _macro_origin: Dictionary = {}
var _macro_destination: Dictionary = {}
var _after_warp_mode: String = ""
var _gate_approach_phase: String = ""
var _gate_approach_axis: Vector3 = Vector3.ZERO
var _gate_clearance: float = 0.0
var _gate_ship_radius: float = 0.0

func configure(sector: XJSector, runtime: XJRuntimeState, definitions: XJCatalog, business: RefCounted, stability: Callable = Callable()) -> bool:
	world = sector
	state = runtime
	catalog = definitions
	gameplay = business
	stable = stability
	mode = ""
	phase = "idle"
	target_id = ""
	_clear_combat_order()
	_configured = rules.load_rules(catalog.table_names.has("site_defs"))
	last_error = "" if _configured else rules.last_error
	return _configured

func active() -> bool:
	return phase in ["warmup", "travel", "arrival_check", "approach", "orbit"]

func warp_active() -> bool:
	return active() and mode == "warp"

func inspect(id: String) -> Dictionary:
	var result: Dictionary = {"target_id": id, "title": "", "kind": "", "distance_m": 0.0, "ready": false, "reason": "", "warp_ready": false, "warp_reason": "", "approach_ready": false, "approach_reason": "", "orbit_ready": false, "orbit_reason": "", "dock_ready": false, "dock_reason": "", "mode": mode, "phase": phase, "remaining_s": remaining_s, "combat_managed": combat_managed, "combat_distance_m": combat_distance_m}
	var reason: String = _target_reason(id)
	if not reason.is_empty(): return _deny_all(result, reason)
	var entry: Dictionary = world.targets[id]
	var node: Node3D = entry.node
	result.title = str(entry.title)
	result.kind = str(entry.kind)
	result.distance_m = world.target_distance(id)
	result["remote_site"] = not world.target_is_local(id)
	result["warp_distance_m"] = 0.0
	result.approach_ready = true
	result.orbit_ready = true
	result.ready = true
	var pending: String = XJInteractionContext.pending_attack_reason(world)
	result.dock_ready = entry.kind == "station" and pending.is_empty() and not bool(gameplay.call("in_combat"))
	result.dock_reason = pending if entry.kind == "station" and not pending.is_empty() else "交战中不能停靠" if entry.kind == "station" and not result.dock_ready else ("仅空间站可以停靠" if entry.kind != "station" else "")
	var target_rule: Dictionary = _target_rule(entry)
	var arrival_point: Vector3 = _arrival_point(node, float(target_rule.warp_arrival_m)) if target_rule.warp_arrival_m != null else node.global_position
	var path: float = _distance_to_landing(id, arrival_point)
	result.warp_distance_m = path
	if target_rule.warp_arrival_m == null:
		result.warp_reason = "此目标只支持接近和环绕"
	elif active():
		result.warp_reason = "先停止当前自动航行"
	elif not gameplay.scenarios.navigation_reason().is_empty():
		result.warp_reason=gameplay.scenarios.navigation_reason()
	elif not gameplay.hired.travel_reason().is_empty():
		result.warp_reason=gameplay.hired.travel_reason()
	elif not _stable():
		result.warp_reason = pending + "后才能跃迁" if not pending.is_empty() else "脱离交战并等待设备周期结束后才能跃迁"
	elif not _landing_clear(world.flight.global_position):
		result.warp_reason = "先离开障碍物，再启动跃迁"
	elif not is_finite(path) or path < rules.value("min_warp_distance_m"):
		result.warp_reason = "实际航程 %s，最低跃迁航程 %s；使用接近或停靠" % [XJSpaceUnits.distance(path), XJSpaceUnits.distance(rules.value("min_warp_distance_m"))]
	else:
		if world.target_is_local(id) and not _landing_clear(arrival_point): result.warp_reason = "目标附近没有安全跃迁落点，请使用接近"
		else: result.warp_ready = true
	if bool(result.remote_site):
		result.approach_ready = result.warp_ready
		result.approach_reason = result.warp_reason
		result.dock_ready = entry.kind == "station" and result.warp_ready
		result.dock_reason = result.warp_reason if entry.kind == "station" else "仅空间站可以停靠"
		result.orbit_ready = false
		result.orbit_reason = "目标位于其他地点，先跃迁抵达后再环绕"
	return result

func begin(requested_mode: String, id: String) -> bool:
	return _begin(requested_mode, id)

func begin_combat(requested_mode: String, id: String, weapon_distance_m: float) -> bool:
	# Combat supplies a range derived from the installed weapons and real muzzles.
	# Failed validation must leave an existing accepted navigation order intact.
	return _begin(requested_mode, id, true, weapon_distance_m)

func _begin(requested_mode: String, id: String, combat_order: bool = false, weapon_distance_m: float = 0.0) -> bool:
	if requested_mode not in ["warp", "approach", "orbit", "dock"]: return _fail("未知导航操作")
	if active() and (not combat_order or warp_active()): return _fail("先停止当前自动航行")
	var context: Dictionary = inspect(id)
	if not bool(context.get(requested_mode + "_ready", false)):
		return _fail(str(context.get(requested_mode + "_reason", context.reason)))
	if requested_mode=="warp" or bool(context.get("remote_site",false)):
		for row: RefCounted in Party.owned(state,catalog):
			if not world.npcs.has(row.npc_instance_id):return _fail("自有僚舰实体尚未就绪，等待编队稳定")
	if combat_order:
		if requested_mode not in ["approach", "orbit"] or str(context.kind) != "npc": return _fail("战斗导航仅支持接近或环绕当前敌舰")
		if not is_finite(weapon_distance_m) or weapon_distance_m <= 0.0: return _fail("有效武器射程不可用")
		var target_rule: Dictionary = _target_rule(world.targets[id])
		var requested_distance: float = minf(float(target_rule.orbit_radius_m if requested_mode == "orbit" else target_rule.approach_arrival_m), weapon_distance_m)
		var target_node: Node3D = world.targets[id].node
		var clearance: float = _radius_from_center(world.flight, world.flight.global_position) + _radius_from_center(target_node, target_node.global_position) + rules.value("collision_margin_m")
		if not is_finite(clearance) or requested_distance <= clearance: return _fail("武器射程不足以保持舰体安全间距")
	# A validated combat toggle may replace ordinary movement or its own order.
	# Preserve the old navigation, velocity and ownership until all checks pass.
	if active(): release_to_manual(false)
	_gate_approach_phase="";_gate_approach_axis=Vector3.ZERO;_gate_clearance=0.0
	_after_warp_mode = requested_mode if requested_mode in ["approach", "dock"] and bool(context.get("remote_site", false)) else ""
	mode = "warp" if not _after_warp_mode.is_empty() else requested_mode
	target_id = id
	_target_site_snapshot = world.target_site(id)
	combat_managed = combat_order
	combat_distance_m = weapon_distance_m if combat_order else 0.0
	_ship_id = state.ship().ship_instance_id
	_sector_id = state.current_sector()
	world.flight.clear_intent()
	if world.flight.metrics.is_empty(): world.flight.metrics = gameplay.call("metrics", state.ship())
	var node: Node3D = world.targets[id].node
	if mode == "warp":
		_companion_origin=gameplay.hired.departure_pose()
		_owned_origin=gameplay.owned_fleet.departure_poses()
		_owned_shapes.clear()
		for pose: Dictionary in _owned_origin:
			var body: CharacterBody3D=world.npcs[pose.ship]
			_owned_shapes[pose.ship]=_capture_shapes(body,body.global_transform.affine_inverse())
		origin = world.flight.global_position
		last_safe_position = origin
		_safe_positions = [origin]
		destination = _arrival_point(node, float(_target_rule(world.targets[id]).warp_arrival_m))
		warp_heading = world.target_direction(id)
		_origin_site = Space.current_site(state)
		_destination_site = world.target_site(id)
		path_length_m = _distance_to_landing(id, destination)
		travel_elapsed_s = 0.0
		travel_duration_s = maxf(rules.value("min_warp_travel_s"), path_length_m / rules.value("warp_speed_mps")) if rules.version == 2 else path_length_m / rules.value("warp_speed_mps")
		_macro_origin = Space.entity_components(state, catalog, "ship", state.ship())
		_macro_destination = Space.global_components(catalog, _destination_site, destination)
		remaining_s = rules.value("warmup_s")
		world.flight.velocity = Vector3.ZERO
		world.flight.write_back()
		phase = "warmup"
		changed.emit(mode, phase, "跃迁充能 · " + str(context.title) + "；X 可停止")
	elif mode == "orbit":
		orbit_normal = world.flight.global_basis.y.normalized()
		var radial: Vector3 = world.flight.global_position - node.global_position
		if radial.length_squared() > 0.000001 and radial.normalized().cross(orbit_normal).length_squared() < 0.000001:
			orbit_normal = world.flight.global_basis.x.normalized()
		phase = "orbit"
		changed.emit(mode, phase, "环绕 · " + str(context.title) + "；X 可停止")
	else:
		phase = "approach"
		changed.emit(mode, phase, ("自动接近并停靠 · " if mode == "dock" else "接近 · ") + str(context.title) + "；X 可停止")
	last_error = ""
	return true

func tick(delta: float) -> void:
	if not active() or delta <= 0.0 or not is_finite(delta): return
	var reason: String = _target_reason(target_id)
	if not reason.is_empty(): _abort(reason); return
	if Space.supported(catalog) and world.target_site(target_id) != _target_site_snapshot:
		_abort("目标已迁移，自动航行已停止；重新定位后前往新地点"); return
	if state.ship().ship_instance_id != _ship_id or state.current_sector() != _sector_id:
		_abort("舰船或星区已改变，自动航行停止"); return
	if warp_active() and not _stable(): _abort("跃迁中断：交战、弹丸或设备周期尚未结束"); return
	if warp_active() and not Party.departure_valid(state,catalog,_owned_origin):_abort("跃迁中断：自有僚舰或操舰员状态已变化");return
	var node: Node3D = world.targets[target_id].node
	if mode == "warp":
		if phase == "warmup":
			var angle: float = _heading_delta(warp_heading, delta)
			remaining_s = maxf(0.0, remaining_s - delta)
			if remaining_s <= 0.0 and angle <= rules.value("alignment_tolerance_rad"):
				phase = "travel"
				remaining_s = travel_duration_s
				if _cross_site():
					if not world.begin_strategic_departure(warp_heading, travel_duration_s):
						_abort(world.last_error)
						return
					world.set_collision_site(_destination_site)
				changed.emit(mode, phase, "正在跃迁 · " + str(world.targets[target_id].title))
			return
		if phase == "arrival_check":
			if not _landing_clear(destination) or not _owned_landing_clear(destination): _abort("编队落点被占用，已退回出发地点"); return
			_arrive()
			return
		if not _landing_clear(destination) or not _owned_landing_clear(destination): _abort("编队落点被占用，跃迁已停止"); return
		if _cross_site():
			travel_elapsed_s = minf(travel_duration_s, travel_elapsed_s + delta)
			world.advance_strategic_departure(travel_elapsed_s)
			remaining_s = maxf(0.0, travel_duration_s - travel_elapsed_s)
			var fraction: float = travel_elapsed_s / travel_duration_s
			world.strategic_render_position = {"x": lerpf(float(_macro_origin.x), float(_macro_destination.x), fraction), "y": lerpf(float(_macro_origin.y), float(_macro_destination.y), fraction), "z": lerpf(float(_macro_origin.z), float(_macro_destination.z), fraction)}
			if remaining_s <= 0.0:
				phase = "arrival_check"
				world.end_strategic_departure()
				Space.assign(state, "ship", state.ship().ship_instance_id, _destination_site)
				world.strategic_render_position = {}
				world.flight.global_position = destination
				world.flight.velocity = Vector3.ZERO
				world.flight.write_back()
				world.refresh_site()
				if not world.sync_entities(): _abort(world.last_error); return
				world.flight.reset_physics_interpolation()
			return
		var previous: Vector3 = world.flight.global_position
		var effective_speed: float = minf(rules.value("warp_speed_mps"), path_length_m / rules.value("min_warp_travel_s")) if rules.version == 2 else rules.value("warp_speed_mps")
		var next: Vector3 = previous.move_toward(destination, effective_speed * delta)
		if _landing_clear(next):
			last_safe_position = next
			_safe_positions.append(next)
			if _safe_positions.size() > 256: _safe_positions.remove_at(1)
		world.flight.global_position = next
		world.flight.velocity = (next - previous) / delta
		world.flight.write_back()
		if next.is_equal_approx(destination): _arrive()
		return
	var target_rule: Dictionary = _target_rule(world.targets[target_id])
	if combat_managed:
		# Keep the ordinary NPC stand-off rules, capped by actual weapon geometry.
		target_rule.approach_arrival_m = minf(float(target_rule.approach_arrival_m), combat_distance_m)
		target_rule.orbit_radius_m = minf(float(target_rule.orbit_radius_m), combat_distance_m)
	var metrics: Dictionary = world.flight.metrics
	if metrics.is_empty() or float(metrics.acceleration_mps2)<=0.0 or float(metrics.strafe_multiplier)<=0.0 or float(metrics.turn_radps)<=0.0:_abort("舰船运动参数不可用");return
	var approach_center: Vector3=node.global_position
	var approach_arrival: float=float(target_rule.approach_arrival_m)
	var gate_stage: bool=false
	var gate_heading: Vector3=Vector3.ZERO
	var gate_speed: float=INF
	if mode!="orbit" and str(world.targets[target_id].kind)=="gate":
		var path: Dictionary=_gate_approach(node,approach_arrival)
		approach_center=path.center;approach_arrival=path.arrival;gate_stage=path.staging;gate_heading=path.heading;gate_speed=path.speed
	var offset: Vector3 = world.flight.global_position - approach_center
	var distance: float = offset.length()
	var radial: Vector3 = offset / distance if distance > 0.000001 else -world.flight.global_basis.z
	var desired_velocity: Vector3
	if mode == "orbit":
		var tangent: Vector3 = orbit_normal.cross(radial).normalized()
		if tangent.length_squared() < 0.000001: tangent = world.flight.global_basis.x
		var radial_error: float = distance - float(target_rule.orbit_radius_m)
		desired_velocity = tangent * float(metrics.speed_mps) * rules.value("orbit_speed_fraction") - radial * radial_error / rules.value("orbit_radial_response_s")
		if node is CharacterBody3D: desired_velocity += (node as CharacterBody3D).velocity
		desired_velocity = desired_velocity.limit_length(float(metrics.speed_mps))
	else:
		var remaining: float = maxf(0.0, distance - approach_arrival)
		var safe_speed: float = sqrt(2.0 * float(metrics.acceleration_mps2) * remaining)
		desired_velocity = -radial * minf(gate_speed,minf(float(metrics.speed_mps) * rules.value("approach_speed_fraction"), safe_speed))
		if remaining <= rules.value("arrival_tolerance_m") and world.flight.velocity.length() <= rules.value("arrival_speed_mps"):
			if gate_stage:_drive(Vector3.ZERO,-radial,delta);return
			_arrive(); return
	_drive(desired_velocity, gate_heading if gate_heading.length_squared()>0.0 else -radial if mode != "orbit" or combat_managed else desired_velocity.normalized(), delta)

func _gate_approach(node: Node3D,arrival: float) -> Dictionary:
	var center: Vector3=node.global_position
	var offset: Vector3=world.flight.global_position-center
	var distance: float=offset.length()
	var radial: Vector3=offset.normalized() if distance>0.000001 else node.global_basis.z.normalized()
	var tolerance: float=rules.value("arrival_tolerance_m")
	if _gate_approach_phase.is_empty():
		var normal: Vector3=node.global_basis.z.normalized()
		_gate_approach_axis=normal if radial.dot(normal)>=0.0 else -normal
		_gate_ship_radius=_collider_radius(world.flight)
		_gate_clearance=_radius_from_center(node,center)+_gate_ship_radius*2.0+rules.value("collision_margin_m")+tolerance*2.0
		# An already aligned approach remains direct. Side approaches first gain
		# clearance, then use short chords outside the actual collider bounds.
		_gate_approach_phase="final" if distance<=float(catalog.rule("gate_entry_radius_m")) or radial.angle_to(_gate_approach_axis)*maxf(distance,_gate_clearance)<=tolerance else "retreat"
	var limit: float=minf(_gate_clearance*float(world.flight.metrics.turn_radps),sqrt(float(world.flight.metrics.acceleration_mps2)*float(world.flight.metrics.strafe_multiplier)*_gate_clearance))
	if _gate_approach_phase=="retreat":
		if distance<_gate_clearance-tolerance:return {"center":center+radial*_gate_clearance,"arrival":0.0,"staging":true,"heading":-radial,"speed":limit}
		_gate_approach_phase="align"
	if _gate_approach_phase=="align":
		var angle: float=radial.angle_to(_gate_approach_axis)
		if angle*_gate_clearance<=tolerance and absf(distance-_gate_clearance)<=tolerance:_gate_approach_phase="final"
		else:
			var lookahead: float=minf(1.0,(_gate_ship_radius+tolerance)/maxf(_gate_clearance*angle,tolerance))
			var direction: Vector3=radial.slerp(_gate_approach_axis,lookahead).normalized()
			return {"center":center+direction*_gate_clearance,"arrival":0.0,"staging":true,"heading":Vector3.ZERO,"speed":limit}
	return {"center":center,"arrival":arrival,"staging":false,"heading":Vector3.ZERO,"speed":INF}

func cancel() -> void:
	stop()

func release_to_manual(announce: bool = true) -> void:
	# Explicit manual keys take ownership without an artificial velocity reset.
	# Warp is the exception: it must stop at a collision-checked safe point.
	if warp_active():
		stop()
		return
	var previous_mode: String = mode
	phase = "cancelled"
	remaining_s = 0.0
	target_id = ""
	_clear_combat_order()
	if is_instance_valid(world) and is_instance_valid(world.flight):
		world.flight.clear_intent()
		world.flight.write_back()
	if announce: changed.emit(previous_mode, phase, "已切换手动操舰")

func stop() -> void:
	var previous_mode: String = mode
	_zero_motion()
	phase = "cancelled"
	remaining_s = 0.0
	target_id = ""
	_clear_combat_order()
	changed.emit(previous_mode, phase, "舰船已停止")

func _drive(desired_velocity: Vector3, heading: Vector3, delta: float) -> void:
	var body: XJFlight = world.flight
	var metrics: Dictionary = body.metrics
	var intent: D.FlightInputDto = D.FlightInputDto.new()
	var local_acceleration: Vector3 = body.global_basis.inverse() * ((desired_velocity - body.velocity) / delta)
	var acceleration: float = float(metrics.acceleration_mps2)
	var strafe: float = float(metrics.strafe_multiplier)
	var reverse: float = float(metrics.reverse_multiplier)
	if strafe <= 0.0 or reverse <= 0.0: _abort("舰船推力参数不可用"); return
	intent.thrust_x = local_acceleration.x / (acceleration * strafe)
	intent.thrust_y = local_acceleration.y / (acceleration * strafe)
	intent.thrust_z = -local_acceleration.z / (acceleration * (reverse if local_acceleration.z > 0.0 else 1.0))
	var thrust: Vector3 = Vector3(intent.thrust_x, intent.thrust_y, intent.thrust_z).limit_length(1.0)
	intent.thrust_x = thrust.x; intent.thrust_y = thrust.y; intent.thrust_z = thrust.z
	intent.brake_requested = desired_velocity.length() <= rules.value("arrival_speed_mps")
	if heading.length_squared() > 0.000001:
		var local_heading: Vector3 = body.global_basis.inverse() * heading.normalized()
		var yaw: float = atan2(-local_heading.x, -local_heading.z)
		var pitch: float = atan2(local_heading.y, Vector2(local_heading.x, local_heading.z).length())
		var response: float = float(metrics.turn_radps) * rules.value("steering_response_s")
		if response > 0.0:
			intent.yaw_request = clampf(yaw / response, -1.0, 1.0)
			intent.pitch_request = clampf(pitch / response, -1.0, 1.0)
	body.intent = intent
	body.blocked = false
	body.simulate(delta)

func _target_reason(id: String) -> String:
	if not _configured: return last_error if not last_error.is_empty() else "导航规则不可用"
	if state == null or catalog == null or gameplay == null or not is_instance_valid(world) or not is_instance_valid(world.flight): return "当前没有可自动航行的舰船"
	if state.ship() == null or state.ship().status != T.ShipStatus.FLYING: return "出港后才能自动航行"
	if not world.targets.has(id): return "目标不在当前星系"
	var entry: Dictionary = world.targets[id]
	if bool(entry.get("navigation_only", false)) or not rules.targets.has(_rule_kind(str(entry.kind))): return "远景天体仅供航向参考"
	var candidate: Variant = entry.get("node")
	if not is_instance_valid(candidate) or not candidate is Node3D or not candidate.is_inside_tree(): return "目标已离开或失效"
	var definition: Dictionary
	match str(entry.kind):
		"station": definition = gameplay.call("definition", "station_defs", "station_id", id)
		"gate":
			definition = gameplay.call("definition", "gate_endpoint_defs", "endpoint_id", id)
			if definition.is_empty() or str(definition.origin_sector_id) != state.current_sector(): return "目标不在当前星系"
		"resource": definition = gameplay.call("definition", "resource_node_defs", "node_id", id)
		"signal":
			var signal_def: Dictionary = gameplay.call("definition", "signal_defs", "signal_id", id)
			if signal_def.is_empty(): return "导航信号定义不可用"
			definition = gameplay.call("definition", "anchor_defs", "anchor_id", str(signal_def.anchor_id))
		"marker": definition = gameplay.call("definition", "anchor_defs", "anchor_id", id)
		"encounter":
			definition = gameplay.call("definition", "anchor_defs", "anchor_id", str(entry.anchor_id))
			if definition.is_empty() or str(definition.sector_id) != state.current_sector(): return "战斗地点不在当前星系"
		"wreck":
			var container: RefCounted = state.find("container_state", "container_id", id)
			if container == null or container.kind != T.ContainerKind.WRECK or container.sector_id != state.current_sector(): return "残骸不在当前星系"
		"npc":
			var npc: RefCounted = state.find("npc_state", "npc_instance_id", id)
			if npc == null or not npc.alive or npc.sector_id != state.current_sector(): return "敌舰已离开或失效"
		"drone":
			if not gameplay.drone_control.live.has(id): return "无人机已回收或失效"
	if str(entry.kind) in ["station", "resource", "signal", "marker"]:
		if definition.is_empty() or str(definition.sector_id) != state.current_sector(): return "目标不在当前星系"
	if str(entry.kind) in ["npc","drone"]:
		var sensor: float = gameplay.ship_roles.detection_range()
		if world.flight.global_position.distance_to((candidate as Node3D).global_position) > sensor: return "敌舰超出探测范围"
	return ""

func _rule_kind(kind: String) -> String:
	return str({"exploration": "signal", "exploration_exit": "marker", "encounter": "marker", "drone":"npc"}.get(kind, kind))

func _target_rule(entry: Dictionary) -> Dictionary:
	# A site is a navigation marker, while its stand-off distance is frozen
	# with the combat encounter. No new balancing constants enter this controller.
	var result: Dictionary = rules.target(_rule_kind(str(entry.kind)))
	if entry.kind == "encounter": result.warp_arrival_m = entry.warp_arrival_m
	return result

func _heading_delta(direction: Vector3, delta: float) -> float:
	if direction.length_squared() < 0.000001: return 0.0
	var body: XJFlight = world.flight
	var up: Vector3 = body.global_basis.y
	if direction.normalized().cross(up).length_squared() < 0.000001: up = body.global_basis.x
	var desired: Basis = XJFlight.leveled_basis(Transform3D(Basis.IDENTITY, body.global_position).looking_at(body.global_position + direction, up).basis)
	var current: Quaternion = body.global_basis.get_rotation_quaternion()
	var destination_attitude: Quaternion = desired.get_rotation_quaternion()
	var angle: float = current.angle_to(destination_attitude)
	if angle > 0.000001:
		var maximum: float = float(body.metrics.turn_radps) * delta
		body.global_basis = Basis(current.slerp(destination_attitude, minf(1.0, maximum / angle))).orthonormalized()
	body.write_back()
	return body.global_basis.get_rotation_quaternion().angle_to(destination_attitude)

func _stable() -> bool:
	if stable.is_valid(): return stable.call() == true
	return bool(gameplay.call("save_eligible")) and not world.projectiles.has_pending()

func _arrival_point(node: Node3D, distance: float) -> Vector3:
	for id: String in world.targets:
		if world.targets[id].node==node and str(world.targets[id].kind)=="gate":
			var normal: Vector3=node.global_basis.z.normalized()
			var radial: Vector3=world.flight.global_position-node.global_position if world.target_is_local(id) else -world.target_direction(id)
			return node.global_position+normal*(distance if radial.dot(normal)>=0.0 else -distance)
		if world.targets[id].node == node and not world.target_is_local(id): return node.global_position - world.target_direction(id) * distance
	var radial: Vector3 = world.flight.global_position - node.global_position
	if radial.length_squared() < 0.000001: radial = world.flight.global_basis.z
	return node.global_position + radial.normalized() * distance

func _distance_to_landing(id: String, point: Vector3) -> float:
	if not Space.supported(catalog) or world.target_is_local(id): return world.flight.global_position.distance_to(point)
	return Space.scalar_distance(Space.entity_components(state, catalog, "ship", state.ship()), Space.global_components(catalog, world.target_site(id), point))

func _cross_site() -> bool:
	return Space.supported(catalog) and not _origin_site.is_empty() and _origin_site != _destination_site

func _landing_clear(point: Vector3) -> bool:
	if not is_instance_valid(world) or not is_instance_valid(world.flight) or not world.is_inside_tree(): return false
	return _shapes_clear(world.flight, point - world.flight.global_position)

func _capture_shapes(node: Node,inverse: Transform3D) -> Array[Dictionary]:
	var shapes: Array[Dictionary]=[]
	if node is CollisionShape3D and not node.disabled and node.shape!=null:
		shapes.append({"shape":node.shape,"transform":inverse*node.global_transform})
	for child: Node in node.get_children():shapes.append_array(_capture_shapes(child,inverse))
	return shapes

func _owned_landing_clear(point: Vector3) -> bool:
	var excludes: Array[RID]=[world.flight.get_rid()]
	for id: String in _owned_shapes:
		if world.npcs.has(id):excludes.append(world.npcs[id].get_rid())
	var index: int=0
	for pose: Dictionary in _owned_origin:
		var transform: Transform3D=Transform3D(world.flight.global_basis,point+world.flight.global_basis*Party.offset(catalog,index));index+=1
		for shape: Dictionary in _owned_shapes.get(pose.ship,[]):
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=shape.shape;query.transform=transform*shape.transform;query.margin=rules.value("collision_margin_m");query.collision_mask=world.flight.collision_mask;query.exclude=excludes
			if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	return true

func _shapes_clear(node: Node, displacement: Vector3) -> bool:
	if node is CollisionShape3D:
		var collider: CollisionShape3D = node
		if not collider.disabled and collider.shape != null:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = collider.shape
			query.transform = collider.global_transform
			query.transform.origin += displacement
			query.margin = rules.value("collision_margin_m")
			query.collision_mask = world.flight.collision_mask
			query.exclude = [world.flight.get_rid()]
			if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return false
	for child: Node in node.get_children():
		if not _shapes_clear(child, displacement): return false
	return true

func _sync_companion_pose() -> void:
	var actors: Array=[]
	var hired_actor: RefCounted=gameplay.hired.actor()
	if hired_actor!=null:actors.append(hired_actor)
	for row: RefCounted in gameplay.owned_fleet.active():
		var owned_actor: RefCounted=gameplay.owned_fleet.actor(row)
		if owned_actor!=null:actors.append(owned_actor)
	for npc: RefCounted in actors:
		if not world.npcs.has(npc.npc_instance_id):continue
		var body: CharacterBody3D=world.npcs[npc.npc_instance_id]
		body.global_position=Vector3(npc.pos_x,npc.pos_y,npc.pos_z);body.velocity=Vector3(npc.vel_x,npc.vel_y,npc.vel_z)
		body.quaternion=Quaternion(npc.quat_x,npc.quat_y,npc.quat_z,npc.quat_w).normalized();body.reset_physics_interpolation()

func _zero_motion(restore_companion: bool=true) -> void:
	var companion_restored: bool=false
	if is_instance_valid(world) and is_instance_valid(world.flight):
		if warp_active() and _cross_site():
			world.end_strategic_departure()
			world.strategic_render_position = {}
			# Travel is a strategic route between physical sites. An interrupted
			# route restores the durable departure site, never an AU Vector3 pose.
			if Space.current_site(state) == _origin_site: world.set_collision_site(_origin_site)
			else:
				Space.assign(state, "ship", state.ship().ship_instance_id, _origin_site)
				world.flight.global_position = origin
				world.flight.write_back()
				if restore_companion:
					gameplay.hired.restore_departure(_companion_origin);gameplay.owned_fleet.restore_departure(_owned_origin);companion_restored=true
				world.refresh_site()
				world.sync_entities()
		if warp_active() and restore_companion:
			if not companion_restored:
				gameplay.hired.restore_departure(_companion_origin);gameplay.owned_fleet.restore_departure(_owned_origin)
			_sync_companion_pose()
		if warp_active() and not _landing_clear(world.flight.global_position): _recover_warp_position()
		world.flight.clear_intent()
		world.flight.velocity = Vector3.ZERO
		world.flight.write_back()
		if mode == "warp":
			world.flight.get_global_transform_interpolated()
			world.flight.reset_physics_interpolation()

func _recover_warp_position() -> void:
	# Transit may pass through geometry, but a stopped ship must use a live-tested
	# clear point. Keep exact safe samples rather than blindly restoring the origin.
	for index: int in range(_safe_positions.size() - 1, -1, -1):
		if _landing_clear(_safe_positions[index]):
			world.flight.global_position = _safe_positions[index]
			last_safe_position = _safe_positions[index]
			return
	if _landing_clear(origin): world.flight.global_position = origin; last_safe_position = origin; return
	if not _cross_site() and _landing_clear(destination): world.flight.global_position = destination; last_safe_position = destination; return
	# Dynamic bodies may occupy old samples. Search around the origin with spacing
	# derived from the actual collider dimensions and SQLite safety margin.
	var spacing: float = _collider_radius(world.flight) * 2.0 + rules.value("collision_margin_m")
	var limit: float = float(catalog.rule("target_marker_detection_range_m"))
	while spacing <= limit:
		for x: int in [-1, 0, 1]:
			for y: int in [-1, 0, 1]:
				for z: int in [-1, 0, 1]:
					if x == 0 and y == 0 and z == 0: continue
					var candidate: Vector3 = origin + Vector3(x, y, z).normalized() * spacing
					if _landing_clear(candidate): world.flight.global_position = candidate; last_safe_position = candidate; return
		spacing *= 2.0

func _collider_radius(node: Node) -> float:
	var radius: float = 0.0
	if node is CollisionShape3D:
		var collider: CollisionShape3D = node
		if collider.shape != null and not collider.disabled:
			var bounds: AABB = collider.shape.get_debug_mesh().get_aabb()
			for index: int in range(8):
				var corner: Vector3 = collider.global_transform * bounds.get_endpoint(index)
				radius = maxf(radius, corner.distance_to(world.flight.global_position))
	for child: Node in node.get_children(): radius = maxf(radius, _collider_radius(child))
	return radius

func _radius_from_center(node: Node, center: Vector3) -> float:
	var radius: float = 0.0
	if node is CollisionShape3D:
		var collider: CollisionShape3D = node
		if collider.shape != null and not collider.disabled:
			var bounds: AABB = collider.shape.get_debug_mesh().get_aabb()
			for index: int in range(8):
				var corner: Vector3 = collider.global_transform * bounds.get_endpoint(index)
				radius = maxf(radius, corner.distance_to(center))
	for child: Node in node.get_children(): radius = maxf(radius, _radius_from_center(child, center))
	return radius

func _clear_combat_order() -> void:
	combat_managed = false
	combat_distance_m = 0.0

func _arrive() -> void:
	var id: String = target_id
	if mode=="warp":
		gameplay.hired.follow_arrival()
		gameplay.owned_fleet.follow_arrival()
		if not world.sync_entities():_abort(world.last_error);return
		_sync_companion_pose()
	# A completed strategic arrival keeps the destination context. Cancellation
	# and failed clearance use _zero_motion's departure restoration instead.
	if _cross_site():
		_origin_site = _destination_site
		world.strategic_render_position = {}
	_zero_motion(false)
	if not _after_warp_mode.is_empty():
		mode = _after_warp_mode
		_after_warp_mode = ""
		phase = "approach"
		remaining_s = 0.0
		changed.emit(mode, phase, "已抵达地点，正在" + ("接近并停靠" if mode == "dock" else "接近目标"))
		return
	phase = "arrived"
	remaining_s = 0.0
	_clear_combat_order()
	changed.emit(mode, phase, "已到达 · " + str(world.targets[id].title) + "，舰船已停止")
	arrived.emit(id)

func _abort(message: String) -> void:
	_zero_motion()
	remaining_s = 0.0
	phase = "failed"
	last_error = message
	_clear_combat_order()
	changed.emit(mode, phase, message)

func _fail(message: String) -> bool:
	last_error = message
	return false

func _deny_all(result: Dictionary, reason: String) -> Dictionary:
	result.reason = reason
	for action: String in ["warp", "approach", "orbit", "dock"]: result[action + "_reason"] = reason
	return result
