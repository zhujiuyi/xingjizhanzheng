class_name XJProjectiles
extends Node3D
## Real rays, swept projectiles and finite reusable drone sorties. Visuals do
## not settle damage. Every drone has one paid shot, then returns to its bay.
signal hit(target_id: String, raw_damage: Vector3, point: Vector3, owner_id: String)
signal impact(point: Vector3, color: Color)
signal surface_impact(point: Vector3, color: Color, normal: Vector3)
const Effects = preload("res://runtime/rendering/realistic_effects.gd")
const Types = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
class Projectile extends RefCounted:
	var owner_id: String
	var excluded_rid: RID
	var position: Vector3
	var direction: Vector3
	var speed: float
	var range_left: float
	var raw_damage: Vector3
	var visual: Node3D
class Drone extends RefCounted:
	var data: D.DroneRuntimeDto
	var owner_id: String
	var excluded_rid: RID
	var module_instance_id: String
	var target_id: String
	var position: Vector3
	var direction: Vector3
	var velocity: Vector3 = Vector3.ZERO
	var raw_damage: Vector3
	var visual: Node3D
	var profile: Dictionary
	var control_range_m: float
	var age_s: float = 0.0
	var returning: bool = false
	var fired: bool = false
	var owner_clearance_m: float = 0.0
	var formation_index: float = 0.0
	var observe_elapsed_s: float = 0.0
var active: Array[Projectile] = []
var drones: Array[Drone] = []
var flashes: Array[Dictionary] = []
var config: Dictionary = {}
var paused: bool = false
var warned_bays: Dictionary = {}

func _control() -> RefCounted:
	var world: Node = get_parent()
	var game: RefCounted = world.get("gameplay") if world != null else null
	return game.drone_control if game != null else null

func setup(catalog: XJCatalog) -> void:
	for row in catalog.rows("presentation_defs"):
		config[row.presentation_id] = row.value_integer if row.value_integer != null else row.value_real

func set_paused(stopped: bool) -> void:
	paused = stopped

func has_pending() -> bool:
	# Cosmetic fades cannot change future damage and need not delay saving.
	return not active.is_empty() or not drones.is_empty()

func module_busy(module_instance_id: String) -> bool:
	for drone in drones:
		if drone.module_instance_id == module_instance_id: return true
	return false

func owner_busy(owner_id: String) -> bool:
	for shot: Projectile in active:
		if shot.owner_id==owner_id:return true
	for drone: Drone in drones:
		if drone.owner_id==owner_id:return true
	return false

func recall_drones() -> void:
	# Disarm future shots without deleting already launched projectiles.
	var state: XJRuntimeState = get_parent().get("state") as XJRuntimeState
	for drone in drones:
		if drone.data != null and state != null and drone.owner_id != state.ship().ship_instance_id and not _control().g.owned_fleet.owns(drone.owner_id): continue
		drone.returning = true
		if drone.data != null: drone.data.returning = true

func fire(owner_id: String, excluded: RID, origin: Vector3, direction: Vector3, speed: float, range_m: float, raw_damage: Vector3, profile: Dictionary = {}, module_instance_id: String = "", target_id: String = "") -> void:
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx() or range_m <= 0.0 or not raw_damage.is_finite(): return
	var family: String = str(profile.get("family_id", _family(raw_damage)))
	var mode: String = str(profile.get("fire_mode", "ray" if speed <= 0.0 else "projectile"))
	if mode == "drone":
		_launch_drones(owner_id, excluded, origin, direction.normalized(), range_m, raw_damage, profile.get("drone", {}), module_instance_id, target_id)
		return
	if mode == "ray":
		_cast(owner_id, excluded, origin, origin + direction.normalized() * range_m, raw_damage, true)
		return
	if speed <= 0.0: return
	var shot := Projectile.new()
	shot.owner_id = owner_id
	shot.excluded_rid = excluded
	shot.position = origin
	shot.direction = direction.normalized()
	shot.speed = speed
	shot.range_left = range_m
	shot.raw_damage = raw_damage
	shot.visual = _visual(family)
	add_child(shot.visual)
	_place(shot.visual, origin, shot.direction)
	active.append(shot)

func simulate(delta: float) -> void:
	if paused or delta <= 0.0: return
	if get_parent().has_method("expire_auxiliary_markers"):get_parent().expire_auxiliary_markers()
	_simulate_drones(delta)
	for shot: Projectile in active.duplicate():
		var travel := minf(shot.range_left, shot.speed * delta)
		var destination := shot.position + shot.direction * travel
		var collided := _cast(shot.owner_id, shot.excluded_rid, shot.position, destination, shot.raw_damage, false)
		shot.position = destination
		shot.range_left -= travel
		if collided or shot.range_left <= 0.0:
			shot.visual.queue_free()
			active.erase(shot)
		else: _place(shot.visual, shot.position, shot.direction)

func _process(delta: float) -> void:
	if paused: return
	for flash: Dictionary in flashes.duplicate():
		flash.remaining_s = maxf(0.0, float(flash.remaining_s) - delta)
		var node: Node3D = flash.visual
		if not is_instance_valid(node): flashes.erase(flash); continue
		if float(flash.remaining_s) <= 0.0:
			node.queue_free()
			flashes.erase(flash)
		else: _fade(node, 1.0 - float(flash.remaining_s) / float(flash.lifetime_s))

func clear() -> void:
	# Only abandon attacks on an explicit world rewind/load, or after the stable
	# barrier passed. This function must never be used to make a save eligible.
	for shot in active:
		if is_instance_valid(shot.visual): shot.visual.queue_free()
	for drone in drones:
		var control: RefCounted = _control()
		if drone.data != null and control != null: control.retire(drone.data.drone_id, false)
		if drone.data != null: get_parent()._remove_target(drone.data.drone_id)
		elif is_instance_valid(drone.visual): drone.visual.queue_free()
	for flash: Dictionary in flashes:
		if is_instance_valid(flash.visual): flash.visual.queue_free()
	active.clear()
	drones.clear()
	flashes.clear()

func _cast(owner_id: String, excluded: RID, from: Vector3, to: Vector3, damage: Vector3, draw: bool) -> bool:
	var exclusions: Array[RID] = []
	if excluded.is_valid(): exclusions.append(excluded)
	var control: RefCounted = _control()
	if control != null and control.supported():
		for drone: Drone in drones:
			if drone.data != null and drone.visual is CollisionObject3D and is_instance_valid(drone.visual) and not control.g.civilizations.hostile_to(owner_id, drone.data.drone_id): exclusions.append((drone.visual as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 131, exclusions)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = result.position if not result.is_empty() else to
	if draw:
		var ray: Node3D = _visual("thermal")
		add_child(ray)
		_place(ray, from, (end - from).normalized())
		ray.scale.z = maxf(from.distance_to(end), 0.01)
		var lifetime: float = float(config.ray_fade_s)
		flashes.append({"visual": ray, "remaining_s": lifetime, "lifetime_s": lifetime})
	if result.is_empty(): return false
	var collider: Object = result.collider
	if collider.get_meta("entity_kind", "") == "drone" and control != null:
		var drone_id: String = str(collider.get_meta("entity_id", ""))
		control.damage(drone_id, owner_id, damage)
		if not control.live.has(drone_id):
			for drone: Drone in drones.duplicate():
				if drone.data != null and drone.data.drone_id == drone_id: _retire_drone(drone)
	elif collider.has_meta("entity_id"):
		hit.emit(str(collider.get_meta("entity_id")), damage, end, owner_id)
	if str(collider.get_meta("entity_kind", "")) not in ["player", "npc"]:
		# Stable station/ore IDs are interactive identities, not damageable ships.
		# Ship contact effects consume the hit route exactly once.
		surface_impact.emit(end, _color(damage), result.get("normal", Vector3.UP))
	impact.emit(end, _color(damage))
	return true

func _launch_drones(owner_id: String, excluded: RID, origin: Vector3, direction: Vector3, range_m: float, damage: Vector3, definition: Dictionary, module_instance_id: String, target_id: String) -> void:
	if definition.is_empty() or module_instance_id.is_empty() or target_id.is_empty() or module_busy(module_instance_id) or _entity_node(owner_id) == null or _entity_node(target_id) == null: return
	var count: int = int(definition.drone_count)
	var nominal: int = count
	var control: RefCounted = _control()
	var modern: bool = control != null and control.supported()
	if modern: count = mini(count, control.stock(owner_id, module_instance_id))
	if count <= 0: return
	warned_bays.erase(module_instance_id)
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	for index: int in count:
		var drone := Drone.new()
		drone.owner_id = owner_id
		drone.excluded_rid = excluded
		drone.module_instance_id = module_instance_id
		drone.target_id = target_id
		drone.direction = direction
		# Launch separation uses existing frozen geometry, never a combat constant.
		drone.position = origin + right * (float(index) - float(count - 1) * 0.5) * float(config.projectile_initial_trail_m)
		drone.raw_damage = damage / float(count)
		drone.control_range_m = range_m
		drone.profile = definition.duplicate(true)
		drone.owner_clearance_m = _owner_radius(_entity_node(owner_id))
		drone.formation_index = float(index) - float(count - 1) * 0.5
		if modern:
			drone.data = control.register(owner_id, module_instance_id, str(definition.module_id), target_id)
			if drone.data == null: continue
			drone.raw_damage = damage / float(nominal)
			var body: StaticBody3D = StaticBody3D.new()
			body.collision_layer = 128; body.collision_mask = 0
			body.set_meta("entity_kind", "drone"); body.set_meta("entity_id", drone.data.drone_id)
			var shape: CollisionShape3D = CollisionShape3D.new(); var sphere: SphereShape3D = SphereShape3D.new(); sphere.radius = float(control.g.tactics.balance.drone_radius_m); shape.shape = sphere
			body.add_child(shape); body.add_child(_visual("drone"))
			drone.visual = body; get_parent().add_child(body)
			_place(body, drone.position, direction)
			get_parent()._target(drone.data.drone_id, "友方无人机" if control.g.civilizations.friendly(drone.data.drone_id) else "敌方无人机", "drone", body, "")
			get_parent().targets[drone.data.drone_id]["friendly"] = control.g.civilizations.friendly(drone.data.drone_id)
		else:
			drone.visual = _visual("drone"); add_child(drone.visual)
		_place(drone.visual, drone.position, direction)
		if drone.data != null:
			drone.data.pos_x = drone.position.x; drone.data.pos_y = drone.position.y; drone.data.pos_z = drone.position.z
		drones.append(drone)

func auxiliary_target(id: String) -> Dictionary:
	var world: Node3D=get_parent();var g: RefCounted=_control().g;var node: Node3D=null;var kind: String="";var generation: int=0;var site: String="";var units: int=0
	if id==g.state.ship().ship_instance_id:
		node=_entity_node(id);kind="ship";site=XJSpaceCoordinates.current_site(g.state)
	elif world.targets.has(id) and world.target_is_local(id):
		var entry: Dictionary=world.targets[id];node=entry.node;kind=entry.kind;site=world.target_site(id)
		generation=int(entry.get("generation",0))
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",id)
		if npc!=null:generation=npc.generation
		if kind=="resource":
			for resource: RefCounted in g.state.rows("resource_state"):
				if resource.node_id==id:units=resource.remaining_units;break
	if not is_instance_valid(node):return {}
	return {"id":id,"kind":kind,"generation":generation,"position":node.global_position,"site_id":site,"remaining_units":units,"title":str(world.targets.get(id,{}).get("title",g.definition("ship_defs","ship_id",g.state.ship().ship_def_id).display_name)),"synthetic":bool(world.targets.get(id,{}).get("auxiliary_record",false))}

func auxiliary_sight(drone_id: String,target_id: String,range_m: float) -> bool:
	var info: Dictionary=auxiliary_target(target_id)
	if info.is_empty():return false
	for drone: Drone in drones:
		if drone.data==null or drone.data.drone_id!=drone_id or drone.returning or drone.data.returning:continue
		if drone.position.distance_to(info.position)>range_m:return false
		var world: Node3D=get_parent();var entry: Dictionary=world.targets.get(target_id,{})
		var group: Dictionary=world.targets.get(str(entry.get("group_target_id","")),{})
		if not group.is_empty():
			var reveal: float=float(group.get("reveal_range_m",range_m))
			if drone.position.distance_to(info.position)>reveal and drone.position.distance_to(group.node.global_position)>reveal:return false
		return world.line_of_sight(drone.position,info.position,drone.excluded_rid,target_id)
	return false

func prepare_auxiliary(item_id: String,target_id: String) -> Array:
	var control: RefCounted=_control();var service: RefCounted=control.g.auxiliary_drones;var hull: RefCounted=service.owner(item_id)
	var owner: CollisionObject3D=_entity_node(hull.ship_instance_id) as CollisionObject3D if hull!=null else null;var info: Dictionary=auxiliary_target(target_id)
	if owner==null or info.is_empty() or module_busy(item_id):return []
	var result: Array=[];var definition: Dictionary=service.spec(item_id);var count: int=mini(control.stock(hull.ship_instance_id,item_id),int(definition.drone_count))
	var direction: Vector3=owner.global_position.direction_to(info.position)
	if direction.is_zero_approx():direction=-owner.global_basis.z
	var right: Vector3=direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx():right=Vector3.RIGHT
	for index: int in range(count):
		var drone:=Drone.new();drone.owner_id=hull.ship_instance_id;drone.module_instance_id=item_id;drone.target_id=target_id;drone.direction=direction;drone.profile=definition.duplicate(true);drone.control_range_m=float(control.g.definition("module_defs","module_id",definition.module_id).range_m)
		drone.excluded_rid=owner.get_rid();drone.owner_clearance_m=_owner_radius(owner);drone.formation_index=float(index)-float(count-1)*0.5;drone.raw_damage=Vector3.ZERO
		drone.position=owner.global_position+direction*(drone.owner_clearance_m+float(config.projectile_initial_trail_m))+right*drone.formation_index*float(config.projectile_initial_trail_m)
		drone.data=control.register_auxiliary(drone.owner_id,item_id,target_id)
		if drone.data==null:discard_auxiliary(result);return []
		drone.data.pos_x=drone.position.x;drone.data.pos_y=drone.position.y;drone.data.pos_z=drone.position.z
		var body:=StaticBody3D.new();body.collision_layer=128;body.collision_mask=0;body.set_meta("entity_kind","drone");body.set_meta("entity_id",drone.data.drone_id)
		var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=float(control.g.tactics.balance.drone_radius_m);shape.shape=sphere;body.add_child(shape);body.add_child(_visual("drone"));drone.visual=body;result.append(drone)
	return result

func discard_auxiliary(staged: Array) -> void:
	for drone: Drone in staged:
		_control().retire(drone.data.drone_id,false)
		if is_instance_valid(drone.visual):drone.visual.free()

func publish_auxiliary(staged: Array) -> void:
	for drone: Drone in staged:
		get_parent().add_child(drone.visual);_place(drone.visual,drone.position,drone.direction)
		get_parent()._target(drone.data.drone_id,"维修无人机" if drone.data.role_kind=="repair" else "侦察无人机","drone",drone.visual,"");get_parent().targets[drone.data.drone_id]["friendly"]=true;drones.append(drone)

func _auxiliary_work(drone: Drone,target: Node3D,delta: float) -> void:
	if drone.returning or drone.data.command_kind=="follow" or drone.data.command_kind=="recall":return
	var service: RefCounted=_control().g.auxiliary_drones;var info: Dictionary=auxiliary_target(drone.target_id)
	if info.is_empty() or info.generation!=drone.data.target_generation or info.site_id!=drone.data.site_id:drone.returning=true;return
	if drone.data.role_kind=="repair":
		if drone.position.distance_to(target.global_position)<=float(drone.profile.work_range_m) and _drone_has_sight(drone,target):
			var restored: float=service.repair(drone.data)
			if restored>0:surface_impact.emit(target.global_position,Color("73e5c1"),drone.direction)
			drone.fired=drone.data.fired;drone.returning=true
	else:
		drone.observe_elapsed_s+=delta
		if drone.observe_elapsed_s>=float(drone.profile.observe_cycle_s):
			drone.observe_elapsed_s=fmod(drone.observe_elapsed_s,float(drone.profile.observe_cycle_s))
			for id: String in get_parent().targets:service.observe(drone.data,id)

func _simulate_drones(delta: float) -> void:
	for drone: Drone in drones.duplicate():
		var control: RefCounted = _control()
		if drone.data != null:
			if control == null or not control.live.has(drone.data.drone_id): _retire_drone(drone); continue
			drone.target_id = drone.data.target_id; drone.returning = drone.data.returning; drone.fired = drone.data.fired
		var owner: Node3D = _entity_node(drone.owner_id)
		if owner == null: _retire_drone(drone, true); continue
		drone.age_s += delta
		var target: Node3D = _entity_node(drone.target_id)
		var auxiliary: bool=drone.data!=null and drone.data.role_kind!="attack"
		if auxiliary and target==null and get_parent().targets.has(drone.target_id) and get_parent().target_is_local(drone.target_id):target=get_parent().targets[drone.target_id].node
		var follow_order: bool = drone.data != null and drone.data.command_kind == "follow"
		if not _drone_module_live(drone) or (target == null and not follow_order) or drone.age_s >= float(drone.profile.sortie_timeout_s): drone.returning = true
		var disconnected: bool = (not follow_order and target != null and owner.global_position.distance_to(target.global_position) > drone.control_range_m) or owner.global_position.distance_to(drone.position) > drone.control_range_m
		if disconnected:
			drone.returning = true
			if drone.data != null:
				drone.data.communication_lost = true
				if not warned_bays.has(drone.module_instance_id) and drone.owner_id == control.g.state.ship().ship_instance_id:
					warned_bays[drone.module_instance_id] = true; control.warning_changed.emit("无人机超出通信范围：攻击已停止，正在自动返航。")
		if drone.returning and drone.position.distance_to(owner.global_position) <= float(drone.profile.return_radius_m): _retire_drone(drone); continue
		# The recovery window is finite. Recalled drones are already disarmed and
		# expiration cannot erase a projectile in the independent active array.
		if drone.age_s >= float(drone.profile.sortie_timeout_s) * 2.0: _retire_drone(drone, true); continue
		if auxiliary:_auxiliary_work(drone,target,delta)
		var destination: Vector3 = owner.global_position if drone.returning or follow_order else target.global_position
		var follow: bool = drone.data != null and drone.data.command_kind == "follow" and not drone.returning
		if follow: destination = owner.global_position + owner.global_basis.x * (drone.owner_clearance_m + float(drone.profile.return_radius_m) * 2.0) + owner.global_basis.z * drone.formation_index * float(drone.profile.return_radius_m)
		var wanted: Vector3 = drone.position.direction_to(destination)
		if wanted.is_zero_approx():wanted=drone.direction
		var turn: float = float(drone.profile.turn_rad_s) * delta
		var angle: float = drone.direction.angle_to(wanted)
		if angle <= turn: drone.direction = wanted
		else:
			var axis: Vector3 = drone.direction.cross(wanted).normalized()
			if axis.is_zero_approx(): axis = drone.direction.cross(Vector3.UP if absf(drone.direction.y) < 0.99 else Vector3.RIGHT).normalized()
			drone.direction = drone.direction.rotated(axis, turn).normalized()
		if not auxiliary and not follow and not drone.returning and not drone.fired and drone.position.distance_to(destination) <= float(drone.profile.attack_range_m) and drone.direction.angle_to(wanted) <= turn and _drone_has_sight(drone, target):
			fire(drone.owner_id, drone.excluded_rid, drone.position, drone.direction, float(drone.profile.projectile_speed_mps), float(drone.profile.attack_range_m), drone.raw_damage, {"family_id": "kinetic", "fire_mode": "projectile"})
			drone.fired = true
			drone.returning = true
		var speed: float = float(drone.profile.speed_mps)
		if follow: speed = minf(speed, sqrt(2.0 * float(drone.profile.acceleration_mps2) * maxf(0.0, drone.position.distance_to(destination) - float(drone.profile.return_radius_m))))
		if auxiliary and not drone.returning and not follow:speed=minf(speed,sqrt(2.0*float(drone.profile.acceleration_mps2)*maxf(0.0,drone.position.distance_to(destination)-float(drone.profile.work_range_m))))
		if drone.returning:
			var stopping_distance: float = maxf(0.0, drone.position.distance_to(owner.global_position) - float(drone.profile.return_radius_m))
			speed = minf(speed, sqrt(2.0 * float(drone.profile.acceleration_mps2) * stopping_distance))
		drone.velocity = drone.velocity.move_toward(drone.direction * speed, float(drone.profile.acceleration_mps2) * delta)
		var next_position: Vector3 = drone.position + drone.velocity * delta
		if not drone.position.is_equal_approx(next_position):
			var query := PhysicsRayQueryParameters3D.create(drone.position, next_position, 3, [drone.excluded_rid])
			var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if not collision.is_empty():
				# Blockage aborts an unfired attack instead of turning contact into
				# direct damage or teleporting the drone through a solid station.
				drone.returning = true
				drone.velocity = Vector3.ZERO
				drone.position = collision.position + collision.normal * float(config.projectile_radius_m)
			else: drone.position = next_position
		_place(drone.visual, drone.position, drone.direction)
		if drone.data != null:
			drone.data.returning = drone.returning; drone.data.fired = drone.fired; drone.data.pos_x = drone.position.x; drone.data.pos_y = drone.position.y; drone.data.pos_z = drone.position.z

func _owner_radius(owner: Node3D) -> float:
	if owner == null: return 0.0
	return _shape_radius(owner, owner.global_position)
func _shape_radius(node: Node, center: Vector3) -> float:
	var radius: float = 0.0
	if node is CollisionShape3D and node.shape != null:
		var bounds: AABB = node.shape.get_debug_mesh().get_aabb()
		for index: int in range(8): radius = maxf(radius, (node.global_transform * bounds.get_endpoint(index)).distance_to(center))
	for child: Node in node.get_children(): radius = maxf(radius, _shape_radius(child, center))
	return radius

func _entity_node(entity_id: String) -> Node3D:
	var sector: Node = get_parent()
	if sector == null: return null
	var state: XJRuntimeState = sector.get("state") as XJRuntimeState
	if state == null: return null
	if entity_id == state.ship().ship_instance_id:
		if state.ship().status != Types.ShipStatus.FLYING: return null
		return sector.get("flight") as Node3D
	var control: RefCounted = _control()
	if control != null and control.live.has(entity_id):
		return sector.targets[entity_id].node if sector.targets.has(entity_id) else null
	var npc: RefCounted = state.find("npc_state", "npc_instance_id", entity_id)
	if npc == null or not npc.alive: return null
	var targets: Dictionary = sector.get("targets")
	if not targets.has(entity_id) or not is_instance_valid(targets[entity_id].node): return null
	return targets[entity_id].node as Node3D

func _drone_module_live(drone: Drone) -> bool:
	var control: RefCounted = _control()
	if drone.data != null and control != null: return control.module_live(drone.owner_id, drone.module_instance_id)
	var state: XJRuntimeState = get_parent().get("state") as XJRuntimeState
	if state == null or state.ship().ship_instance_id != drone.owner_id: return false
	var equipment: RefCounted = state.find("equipment_state", "item_instance_id", drone.module_instance_id)
	var item: RefCounted = state.find("item_instance_state", "item_instance_id", drone.module_instance_id)
	return equipment != null and equipment.enabled and item != null and item.durability > 0.0

func _drone_has_sight(drone: Drone, target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(drone.position, target.global_position, 3, [drone.excluded_rid])
	var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return collision.is_empty() or (collision.collider.has_meta("entity_id") and str(collision.collider.get_meta("entity_id")) == drone.target_id)

func _retire_drone(drone: Drone, lost: bool = false) -> void:
	var control: RefCounted = _control()
	if drone.data != null:
		if control != null: control.retire(drone.data.drone_id, lost)
		get_parent()._remove_target(drone.data.drone_id)
	elif is_instance_valid(drone.visual): drone.visual.queue_free()
	drones.erase(drone)

func _visual(family: String) -> Node3D:
	var modern: bool = config.has("fx_kinetic_length_m")
	var visual_config: Dictionary = config if modern else config.duplicate()
	if not modern: visual_config["legacy_family"] = family
	var node: Node3D = Effects.weapon_visual(family if modern else "legacy", visual_config)
	if not modern and family != "thermal": node.scale.z = float(config.projectile_initial_trail_m)
	return node

func _place(visual: Node3D, position: Vector3, direction: Vector3) -> void:
	visual.global_position = position
	if not direction.is_zero_approx(): visual.global_basis = Basis.looking_at(direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT).scaled(visual.scale)

func _fade(node: Node, amount: float) -> void:
	if node is GeometryInstance3D: (node as GeometryInstance3D).transparency = amount
	for child in node.get_children(): _fade(child, amount)

func _family(damage: Vector3) -> String:
	if damage.y > 0.0: return "thermal"
	if damage.z > 0.0: return "pulse"
	return "kinetic"

func _color(damage: Vector3) -> Color:
	if damage.y > 0.0: return Color(1.0, 0.4, 0.15)
	if damage.z > 0.0: return Color(0.5, 0.4, 1.0)
	return Color(0.2, 0.85, 1.0)
