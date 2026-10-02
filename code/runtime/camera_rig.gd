class_name XJCameraRig
extends Node3D
const Types = preload("res://contracts/contract_types.gd")
var camera: Camera3D
var ship: XJFlight
var catalog: RefCounted
var mode: Types.CameraMode = Types.CameraMode.FOLLOW
var orbit: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var snapped: bool = false

func _ready() -> void:
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)

func bind(body: XJFlight, definitions: RefCounted, camera_mode: Types.CameraMode) -> void:
	ship = body
	catalog = definitions
	mode = camera_mode
	orbit = Vector2.ZERO
	zoom = 1.0
	snapped = false

func cycle_mode() -> void:
	mode = ((int(mode) + 1) % Types.CameraMode.size()) as Types.CameraMode
	orbit = Vector2.ZERO
	zoom = 1.0
	snapped = false

func observe(motion: Vector2, sensitivity: float) -> void:
	orbit.x -= motion.x * sensitivity
	var limit := _presentation("camera_orbit_pitch_limit_rad")
	orbit.y = clampf(orbit.y - motion.y * sensitivity, -limit, limit)

func scroll_zoom(steps: int) -> void:
	if mode != Types.CameraMode.FRONT:
		zoom *= pow(_presentation("camera_zoom_scroll_factor"), steps)
		for profile in catalog.rows("camera_profile_defs"):
			if profile.ship_id == ship.record.ship_def_id and profile.mode == ["follow", "front", "tactical"][int(mode)]:
				zoom = clampf(zoom, float(profile.zoom_min_m) / float(profile.distance_m), float(profile.zoom_max_m) / float(profile.distance_m))
				break

func _presentation(key: String) -> float:
	return float(catalog.one("presentation_defs", "presentation_id", key).value_real)

func step(delta: float) -> void:
	if not is_instance_valid(ship) or catalog == null or camera == null:
		return
	var profile: Dictionary = {}
	var mode_id: String = ["follow", "front", "tactical"][int(mode)]
	for row in catalog.rows("camera_profile_defs"):
		if row.ship_id == ship.record.ship_def_id and row.mode == mode_id:
			profile = row
			break
	if profile.is_empty():
		return
	camera.fov = float(profile.fov_deg)
	camera.near = float(profile.near_m)
	camera.far = float(profile.far_m)
	var up := Vector3.UP
	var target_point := ship.global_position - ship.global_basis.z * float(profile.look_ahead_m)
	var desired: Vector3
	if ship.visual != null:
		ship.visual.visible = mode != Types.CameraMode.FRONT or ship.record.status == Types.ShipStatus.DOCKED
	if ship.record.status == Types.ShipStatus.DOCKED:
		var distance_def: Dictionary = catalog.one("presentation_defs", "presentation_id", "station_camera_distance_m")
		var height_def: Dictionary = catalog.one("presentation_defs", "presentation_id", "station_camera_height_m")
		var fov_def: Dictionary = catalog.one("presentation_defs", "presentation_id", "station_camera_fov_deg")
		if distance_def.is_empty() or height_def.is_empty() or fov_def.is_empty():
			return
		desired = ship.global_position + Vector3(0, float(height_def.value_real), float(distance_def.value_real))
		target_point = ship.global_position
		camera.fov = float(fov_def.value_real)
	elif mode == Types.CameraMode.FRONT:
		var front := ship.get_node_or_null("FrontCamera") as Node3D
		desired = front.global_position if front != null else ship.global_position
		target_point = desired - ship.global_basis.z
		up = ship.global_basis.y
		if ship.visual != null:
			ship.visual.visible = false
	else:
		if ship.visual != null:
			ship.visual.visible = true
		var distance := clampf(float(profile.distance_m) * zoom, float(profile.zoom_min_m), float(profile.zoom_max_m))
		var offset := Vector3(0.0, float(profile.height_m), distance)
		if mode == Types.CameraMode.FOLLOW:
			offset = Basis(Vector3.UP, orbit.x) * Basis(Vector3.RIGHT, orbit.y) * offset
			desired = ship.global_position + ship.global_basis * offset
			up = ship.global_basis.y
		else:
			desired = ship.global_position + Basis(Vector3.UP, orbit.x) * offset
		var query := PhysicsRayQueryParameters3D.create(target_point, desired, 64, [ship.get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			desired = hit.position + hit.normal * float(profile.collision_margin_m)
	var mix := 1.0 - exp(-delta / float(profile.position_smooth_s))
	camera.global_position = desired if not snapped else camera.global_position.lerp(desired, mix)
	if camera.global_position.distance_squared_to(target_point) > 0.0001:
		var aim: Basis = Transform3D(Basis.IDENTITY, camera.global_position).looking_at(target_point, up).basis
		camera.global_basis = aim if not snapped else camera.global_basis.slerp(aim, 1.0 - exp(-delta / float(profile.rotation_smooth_s))).orthonormalized()
	snapped = true
