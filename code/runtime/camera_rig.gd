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
var observing: bool = false
var observation_basis: Basis = Basis.IDENTITY
var _render_pose: Transform3D = Transform3D.IDENTITY
var _render_frame: int = -1

func _ready() -> void:
	# Camera motion is updated at render frequency from the interpolated ship
	# pose. Interpolating this branch again would introduce a second frame lag.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.current = true
	add_child(camera)

func bind(body: XJFlight, definitions: RefCounted, camera_mode: Types.CameraMode) -> void:
	ship = body
	catalog = definitions
	mode = camera_mode
	reset_observation()
	zoom = 1.0
	snapped = false
	_render_frame = -1
	if is_instance_valid(ship) and ship.is_inside_tree():
		# Prime the interpolation pump before the host's teleport/reset boundary.
		ship.get_global_transform_interpolated()

func cycle_mode() -> void:
	mode = ((int(mode) + 1) % Types.CameraMode.size()) as Types.CameraMode
	reset_observation()
	zoom = 1.0
	snapped = false

func reset_observation() -> void:
	observing = false
	orbit = Vector2.ZERO
	# A deliberate V / show-ship action recenters on the current vessel heading.
	# Afterward this world-space reference remains independent of ship attitude.
	observation_basis = XJFlight.leveled_basis(ship.global_basis) if mode == Types.CameraMode.FOLLOW and is_instance_valid(ship) and ship.is_inside_tree() else Basis.IDENTITY

func begin_observation() -> void:
	observing = true

func end_observation() -> void:
	# Releasing the button ends dragging without a camera jump or heading reset.
	observing = false

func control_forward() -> Vector3:
	# Manual forward/reverse thrust follows the view that is currently visible.
	# Flight still owns acceleration and bounded physical attitude changes.
	if camera != null: return -camera.global_basis.z.normalized()
	return -render_ship_transform().basis.z.normalized()

func steer_yaw(radians: float) -> void:
	if not is_finite(radians) or is_zero_approx(radians) or camera == null: return
	var up: Vector3 = render_ship_transform().basis.y if mode == Types.CameraMode.FRONT else Vector3.UP
	var rotation_step := Basis(up.normalized(), radians)
	if mode != Types.CameraMode.FRONT:
		# Rotate both the visible view and its retained destination. W + A/D then
		# curves along the new heading instead of steering back toward an old view.
		observation_basis = (rotation_step * observation_basis).orthonormalized()
		var pivot: Vector3 = render_position()
		camera.global_position = pivot + rotation_step * (camera.global_position - pivot)
	# FRONT follows the next physical ship yaw. Retaining the existing orbit
	# avoids applying the same keyboard yaw twice when that ship pose is rendered.
	camera.global_basis = (rotation_step * camera.global_basis).orthonormalized()

func observe(motion: Vector2, sensitivity: float) -> void:
	if catalog == null or not motion.is_finite() or not is_finite(sensitivity): return
	orbit.x = wrapf(orbit.x - motion.x * sensitivity, -PI, PI)
	orbit.y -= motion.y * sensitivity
	_clamp_orbit(_profile())

func scroll_zoom(steps: int) -> void:
	if mode != Types.CameraMode.FRONT and is_instance_valid(ship) and catalog != null:
		zoom *= pow(_presentation("camera_zoom_scroll_factor"), steps)
		var profile: Dictionary = _profile()
		if not profile.is_empty():
			zoom = clampf(zoom, float(profile.zoom_min_m) / float(profile.distance_m), float(profile.zoom_max_m) / float(profile.distance_m))
			_clamp_orbit(profile)

func _presentation(key: String) -> float:
	return float(catalog.one("presentation_defs", "presentation_id", key).value_real)

func _profile() -> Dictionary:
	if not is_instance_valid(ship) or ship.record == null or catalog == null: return {}
	var mode_id: String = ["follow", "front", "tactical"][int(mode)]
	for row in catalog.rows("camera_profile_defs"):
		if row.ship_id == ship.record.ship_def_id and row.mode == mode_id:
			return row
	return {}

func _clamp_orbit(profile: Dictionary) -> void:
	if profile.is_empty(): return
	var limit: float = _presentation("camera_orbit_pitch_limit_rad")
	var elevation: float = 0.0
	if mode != Types.CameraMode.FRONT:
		var distance: float = clampf(float(profile.distance_m) * zoom, float(profile.zoom_min_m), float(profile.zoom_max_m))
		elevation = atan2(float(profile.height_m), distance)
	orbit.y = clampf(orbit.y, elevation - limit, elevation + limit)

func render_ship_transform() -> Transform3D:
	# UI projections reuse the camera's same-frame sample; gameplay and saves
	# continue to use the physical pose, never this presentation-only transform.
	if not is_instance_valid(ship) or not ship.is_inside_tree(): return Transform3D.IDENTITY
	if _render_frame == Engine.get_process_frames(): return _render_pose
	return _sample_ship_transform()

func render_position() -> Vector3:
	return render_ship_transform().origin

func _sample_ship_transform() -> Transform3D:
	if get_tree().physics_interpolation and ship.is_physics_interpolated() and not Engine.is_in_physics_frame():
		return ship.get_global_transform_interpolated()
	return ship.global_transform

func step(delta: float) -> void:
	if not is_instance_valid(ship) or catalog == null or camera == null: return
	var profile: Dictionary = _profile()
	if profile.is_empty():
		return
	_render_pose = _sample_ship_transform()
	_render_frame = Engine.get_process_frames()
	_clamp_orbit(profile)
	camera.fov = float(profile.fov_deg)
	camera.near = float(profile.near_m)
	camera.far = float(profile.far_m)
	var up := Vector3.UP
	# Frame the player at the actual viewport center. Legacy forward look-ahead
	# moved the vessel away from the center; independent rotation damping then
	# added a second, moving offset while steering.
	var target_point: Vector3 = _render_pose.origin
	var desired: Vector3
	if ship.visual != null:
		ship.visual.visible = mode != Types.CameraMode.FRONT or ship.record.status == Types.ShipStatus.DOCKED
	if ship.record.status == Types.ShipStatus.DOCKED:
		var distance_def: Dictionary = catalog.one("presentation_defs", "presentation_id", "station_camera_distance_m")
		var height_def: Dictionary = catalog.one("presentation_defs", "presentation_id", "station_camera_height_m")
		var fov_def: Dictionary = catalog.one("presentation_defs", "presentation_id", "station_camera_fov_deg")
		if distance_def.is_empty() or height_def.is_empty() or fov_def.is_empty():
			return
		desired = target_point + Vector3(0, float(height_def.value_real), float(distance_def.value_real))
		camera.fov = float(fov_def.value_real)
	elif mode == Types.CameraMode.FRONT:
		var front := ship.get_node_or_null("FrontCamera") as Node3D
		var front_local: Transform3D = ship.global_transform.affine_inverse() * front.global_transform if front != null else Transform3D.IDENTITY
		desired = (_render_pose * front_local).origin
		if ship.visual != null:
			ship.visual.visible = false
		# A cockpit view must inherit the ship pose without positional lag.
		# Free look stays at its last angle after the drag button is released.
		camera.global_position = desired
		camera.global_basis = (_render_pose.basis * Basis(Vector3.UP, orbit.x) * Basis(Vector3.RIGHT, orbit.y)).orthonormalized()
		snapped = true
		return
	else:
		if ship.visual != null:
			ship.visual.visible = true
		var distance := clampf(float(profile.distance_m) * zoom, float(profile.zoom_min_m), float(profile.zoom_max_m))
		var offset := Vector3(0.0, float(profile.height_m), distance)
		offset = Basis(Vector3.UP, orbit.x) * Basis(Vector3.RIGHT, orbit.y) * offset
		desired = target_point + observation_basis * offset
		up = Vector3.UP
		var query := PhysicsRayQueryParameters3D.create(target_point, desired, 64, [ship.get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			desired = hit.position + hit.normal * float(profile.collision_margin_m)
	var smoothing: float = float(profile.position_smooth_s)
	var mix: float = 1.0 - exp(-maxf(delta, 0.0) / smoothing) if smoothing > 0.0 else 1.0
	camera.global_position = desired if not snapped else camera.global_position.lerp(desired, mix)
	if camera.global_position.distance_squared_to(target_point) > 0.0001:
		var direction := camera.global_position.direction_to(target_point)
		var reference_right: Vector3 = camera.global_basis.x if snapped else observation_basis.x
		if direction.cross(up).length_squared() < 0.000001:
			# A moving dolly can transiently pass directly above its target. Project
			# the preceding up axis; deliberate resets use the leveled ship frame.
			up = (camera.global_basis.y if snapped else observation_basis.y).slide(direction)
			if up.length_squared() < 0.000001:
				var right: Vector3 = reference_right.slide(direction)
				if right.length_squared() >= 0.000001: up = right.normalized().cross(direction)
			if up.length_squared() < 0.000001:
				up = (Vector3.RIGHT if absf(direction.x) < 0.9 else Vector3.FORWARD).slide(direction)
		else:
			# Keep screen-right horizontal and continuous across the world-up
			# pole. Near vertical headings the local camera height can cross that
			# pole, so an unconditional +UP would invert a recentered vessel.
			if direction.cross(up).dot(reference_right) < 0.0: up = -up
		var aim: Basis = Transform3D(Basis.IDENTITY, camera.global_position).looking_at(target_point, up.normalized()).basis
		# Smooth the dolly position, then aim at the current vessel, so center
		# framing is exact even while the ship moves and the camera catches up.
		camera.global_basis = aim.orthonormalized()
	snapped = true
