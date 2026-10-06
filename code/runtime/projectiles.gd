class_name XJProjectiles
extends Node3D
## Real rays, swept projectiles and finite reusable drone sorties. Visuals do
## not settle damage. Every drone has one paid shot, then returns to its bay.
signal hit(target_id: String, raw_damage: Vector3, point: Vector3, owner_id: String)
signal impact(point: Vector3, color: Color)
signal surface_impact(point: Vector3, color: Color, normal: Vector3)
const Effects = preload("res://runtime/visuals/visual_effects.gd")
const Types = preload("res://contracts/contract_types.gd")
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
var active: Array[Projectile] = []
var drones: Array[Drone] = []
var flashes: Array[Dictionary] = []
var config: Dictionary = {}
var paused: bool = false

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

func recall_drones() -> void:
	# Disarm future shots without deleting already launched projectiles.
	for drone in drones: drone.returning = true

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
		if is_instance_valid(drone.visual): drone.visual.queue_free()
	for flash: Dictionary in flashes:
		if is_instance_valid(flash.visual): flash.visual.queue_free()
	active.clear()
	drones.clear()
	flashes.clear()

func _cast(owner_id: String, excluded: RID, from: Vector3, to: Vector3, damage: Vector3, draw: bool) -> bool:
	var exclusions: Array[RID] = []
	if excluded.is_valid(): exclusions.append(excluded)
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, exclusions)
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
	if collider.has_meta("entity_id"):
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
	if count <= 0: return
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
		drone.visual = _visual("drone")
		add_child(drone.visual)
		_place(drone.visual, drone.position, direction)
		drones.append(drone)

func _simulate_drones(delta: float) -> void:
	for drone: Drone in drones.duplicate():
		var owner: Node3D = _entity_node(drone.owner_id)
		if owner == null: _retire_drone(drone); continue
		drone.age_s += delta
		var target: Node3D = _entity_node(drone.target_id)
		if not _drone_module_live(drone) or target == null or drone.age_s >= float(drone.profile.sortie_timeout_s): drone.returning = true
		if target != null and owner.global_position.distance_to(target.global_position) > drone.control_range_m: drone.returning = true
		if owner.global_position.distance_to(drone.position) > drone.control_range_m: drone.returning = true
		if drone.returning and drone.position.distance_to(owner.global_position) <= float(drone.profile.return_radius_m): _retire_drone(drone); continue
		# The recovery window is finite. Recalled drones are already disarmed and
		# expiration cannot erase a projectile in the independent active array.
		if drone.age_s >= float(drone.profile.sortie_timeout_s) * 2.0: _retire_drone(drone); continue
		var destination: Vector3 = owner.global_position if drone.returning else target.global_position
		var wanted: Vector3 = drone.position.direction_to(destination)
		if wanted.is_zero_approx(): continue
		var turn: float = float(drone.profile.turn_rad_s) * delta
		var angle: float = drone.direction.angle_to(wanted)
		if angle <= turn: drone.direction = wanted
		else:
			var axis: Vector3 = drone.direction.cross(wanted).normalized()
			if axis.is_zero_approx(): axis = drone.direction.cross(Vector3.UP if absf(drone.direction.y) < 0.99 else Vector3.RIGHT).normalized()
			drone.direction = drone.direction.rotated(axis, turn).normalized()
		if not drone.returning and not drone.fired and drone.position.distance_to(destination) <= float(drone.profile.attack_range_m) and drone.direction.angle_to(wanted) <= turn and _drone_has_sight(drone, target):
			fire(drone.owner_id, drone.excluded_rid, drone.position, drone.direction, float(drone.profile.projectile_speed_mps), float(drone.profile.attack_range_m), drone.raw_damage, {"family_id": "kinetic", "fire_mode": "projectile"})
			drone.fired = true
			drone.returning = true
		var speed: float = float(drone.profile.speed_mps)
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

func _entity_node(entity_id: String) -> Node3D:
	var sector: Node = get_parent()
	if sector == null: return null
	var state: XJRuntimeState = sector.get("state") as XJRuntimeState
	if state == null: return null
	if entity_id == state.ship().ship_instance_id:
		if state.ship().status != Types.ShipStatus.FLYING: return null
		return sector.get("flight") as Node3D
	var npc: RefCounted = state.find("npc_state", "npc_instance_id", entity_id)
	if npc == null or not npc.alive: return null
	var targets: Dictionary = sector.get("targets")
	if not targets.has(entity_id) or not is_instance_valid(targets[entity_id].node): return null
	return targets[entity_id].node as Node3D

func _drone_module_live(drone: Drone) -> bool:
	var state: XJRuntimeState = get_parent().get("state") as XJRuntimeState
	if state == null or state.ship().ship_instance_id != drone.owner_id: return false
	var equipment: RefCounted = state.find("equipment_state", "item_instance_id", drone.module_instance_id)
	var item: RefCounted = state.find("item_instance_state", "item_instance_id", drone.module_instance_id)
	return equipment != null and equipment.enabled and item != null and item.durability > 0.0

func _drone_has_sight(drone: Drone, target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(drone.position, target.global_position, 3, [drone.excluded_rid])
	var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return collision.is_empty() or (collision.collider.has_meta("entity_id") and str(collision.collider.get_meta("entity_id")) == drone.target_id)

func _retire_drone(drone: Drone) -> void:
	if is_instance_valid(drone.visual): drone.visual.queue_free()
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
