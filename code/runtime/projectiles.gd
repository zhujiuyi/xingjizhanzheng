class_name XJProjectiles
extends Node3D
signal hit(target_id: String, raw_damage: Vector3, point: Vector3, owner_id: String)
signal impact(point: Vector3, color: Color)
class Projectile extends RefCounted:
	var owner_id: String
	var excluded_rid: RID
	var position: Vector3
	var direction: Vector3
	var speed: float
	var range_left: float
	var raw_damage: Vector3
	var visual: MeshInstance3D
var active: Array[Projectile] = []
var config: Dictionary = {}

func setup(catalog: XJCatalog) -> void:
	for row in catalog.rows("presentation_defs"):
		config[row.presentation_id] = row.value_integer if row.value_integer != null else row.value_real

func fire(owner_id: String, excluded: RID, origin: Vector3, direction: Vector3, speed: float, range_m: float, raw_damage: Vector3) -> void:
	if speed <= 0.0:
		_cast(owner_id, excluded, origin, origin + direction.normalized() * range_m, raw_damage, true)
		return
	var shot := Projectile.new()
	shot.owner_id = owner_id
	shot.excluded_rid = excluded
	shot.position = origin
	shot.direction = direction.normalized()
	shot.speed = speed
	shot.range_left = range_m
	shot.raw_damage = raw_damage
	shot.visual = _beam(origin, origin + direction.normalized() * float(config.projectile_initial_trail_m), _color(raw_damage))
	active.append(shot)

func simulate(delta: float) -> void:
	for shot: Projectile in active.duplicate():
		var travel := minf(shot.range_left, shot.speed * delta)
		var destination := shot.position + shot.direction * travel
		var collided := _cast(shot.owner_id, shot.excluded_rid, shot.position, destination, shot.raw_damage, false)
		shot.position = destination
		shot.range_left -= travel
		if collided or shot.range_left <= 0.0:
			shot.visual.queue_free()
			active.erase(shot)
		else:
			_set_beam(shot.visual, shot.position - shot.direction * minf(travel, float(config.projectile_trail_m)), shot.position)

func clear() -> void:
	for shot in active:
		if is_instance_valid(shot.visual):
			shot.visual.queue_free()
	active.clear()

func _cast(owner_id: String, excluded: RID, from: Vector3, to: Vector3, damage: Vector3, draw: bool) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [excluded])
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = result.position if not result.is_empty() else to
	if draw:
		var ray := _beam(from, end, _color(damage))
		var tween := create_tween()
		tween.tween_property(ray, "transparency", 1.0, float(config.ray_fade_s))
		tween.tween_callback(ray.queue_free)
	if result.is_empty():
		return false
	var collider: Object = result.collider
	if collider.has_meta("entity_id"):
		hit.emit(str(collider.get_meta("entity_id")), damage, end, owner_id)
	impact.emit(end, _color(damage))
	return true

func _beam(from: Vector3, to: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = float(config.projectile_radius_m)
	shape.bottom_radius = float(config.projectile_radius_m)
	shape.radial_segments = 6
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = float(config.projectile_emission)
	mesh.material_override = material
	add_child(mesh)
	_set_beam(mesh, from, to)
	return mesh

func _set_beam(mesh: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	mesh.position = (from + to) * 0.5
	mesh.scale.y = maxf(from.distance_to(to), 0.01)
	var direction := (to - from).normalized()
	if direction.length_squared() > 0.0:
		mesh.quaternion = Quaternion(Vector3.UP, direction)

func _color(damage: Vector3) -> Color:
	if damage.y > 0.0:
		return Color(1.0, 0.4, 0.15)
	if damage.z > 0.0:
		return Color(0.5, 0.4, 1.0)
	return Color(0.2, 0.85, 1.0)
