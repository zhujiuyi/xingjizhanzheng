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

func reset_observation() -> void:
	orbit = Vector2.ZERO

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
	# Frame the player at the actual viewport center. Legacy forward look-ahead
	# moved the vessel away from the center; independent rotation damping then
	# added a second, moving offset while steering.
	var target_point := ship.global_position
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
		if ship.visual != null:
			ship.visual.visible = false
		# A cockpit view must inherit the ship pose without positional lag.
		# Free look affects only this camera and returns on right-button release.
		camera.global_position = desired
		camera.global_basis = (ship.global_basis * Basis(Vector3.UP, orbit.x) * Basis(Vector3.RIGHT, orbit.y)).orthonormalized()
		snapped = true
		return
	else:
		if ship.visual != null:
			ship.visual.visible = true
		var distance := clampf(float(profile.distance_m) * zoom, float(profile.zoom_min_m), float(profile.zoom_max_m))
		var offset := Vector3(0.0, float(profile.height_m), distance)
		if mode == Types.CameraMode.FOLLOW:
			# Limit the final camera elevation, including the authored dolly height.
			# Clamping only orbit pitch crosses the up pole at minimum zoom.
			var base_elevation := atan2(offset.y, offset.z)
			var pitch_limit := _presentation("camera_orbit_pitch_limit_rad")
			orbit.y = clampf(orbit.y, base_elevation - pitch_limit, base_elevation + pitch_limit)
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
		var direction := camera.global_position.direction_to(target_point)
		if direction.cross(up).length_squared() < 0.000001:
			# A moving dolly can transiently pass directly above its target. Project
			# the preceding up axis first to retain orientation through that point.
			up = camera.global_basis.y.slide(direction)
			if up.length_squared() < 0.000001:
				up = (Vector3.RIGHT if absf(direction.x) < 0.9 else Vector3.FORWARD).slide(direction)
		var aim: Basis = Transform3D(Basis.IDENTITY, camera.global_position).looking_at(target_point, up.normalized()).basis
		# Smooth the dolly position, then aim at the current vessel, so center
		# framing is exact even while the ship moves and the camera catches up.
		camera.global_basis = aim.orthonormalized()
	snapped = true
