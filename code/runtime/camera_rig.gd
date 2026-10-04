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
var _collision_sphere := SphereShape3D.new()

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
	var up: Vector3 = ship.global_basis.y if mode == Types.CameraMode.FRONT else Vector3.UP
	var rotation_step := Basis(up.normalized(), radians)
	if mode != Types.CameraMode.FRONT:
		# Rotate both the visible view and its retained destination. W + A/D then
		# curves along the new heading instead of steering back toward an old view.
		observation_basis = (rotation_step * observation_basis).orthonormalized()
		# Position is advanced only by the collision solver in step(). Moving
		# it here could rotate the camera through a nearby station or gate.
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
	_configure_collision_sphere(profile)
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
		if _camera_clear(target_point): desired = _sweep_end(target_point, desired)
		if not _camera_clear(desired) and _camera_clear(target_point): desired = target_point
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
	var smoothing: float = float(profile.position_smooth_s)
	var mix: float = 1.0 - exp(-maxf(delta, 0.0) / smoothing) if smoothing > 0.0 else 1.0
	camera.global_position = _safe_orbit_position(target_point, desired, profile, mix) if ship.record.status != Types.ShipStatus.DOCKED else (desired if not snapped else camera.global_position.lerp(desired, mix))
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

func _sphere_query(at: Vector3, motion: Vector3 = Vector3.ZERO) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _collision_sphere
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.motion = motion
	query.margin = 0.0
	query.collision_mask = 64
	query.exclude = [ship.get_rid()]
	return query

func _camera_clear(at: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_shape(_sphere_query(at), 1).is_empty()

func _sweep_end(start: Vector3, end: Vector3) -> Vector3:
	var motion: Vector3 = end - start
	if motion.is_zero_approx(): return start
	var fractions: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(_sphere_query(start, motion))
	var fraction: float = fractions[0] if fractions.size() == 2 else 0.0
	if fraction < 1.0:
		# Leave a small geometric gap rather than relying on exact contact.
		fraction = maxf(0.0, fraction - _collision_sphere.radius * 0.02 / motion.length())
	return start + motion * fraction

func _dolly_end(start: Vector3, wanted: Vector3) -> Vector3:
	var at: Vector3 = _sweep_end(start, wanted)
	if at.distance_to(wanted) <= _collision_sphere.radius * 0.02: return at
	# A blocked dolly can still move along its surface. Otherwise a safe
	# endpoint pressed against a wall would stop responding to orbit forever.
	for _attempt: int in range(2):
		var query: PhysicsShapeQueryParameters3D = _sphere_query(at)
		query.margin = _collision_sphere.radius * 0.08
		var contact: Dictionary = get_world_3d().direct_space_state.get_rest_info(query)
		if contact.is_empty() or contact.normal.is_zero_approx(): break
		var along: Vector3 = (wanted - at).slide(contact.normal.normalized())
		if along.length() <= _collision_sphere.radius * 0.02: break
		var next: Vector3 = _sweep_end(at, at + along)
		if not _camera_clear(next): break
		at = next
	# The actual frame-to-frame chord must also be safe after any sliding.
	return _sweep_end(start, at)

func _minimum_view_distance(profile: Dictionary) -> float:
	# Presentation clearance comes from the existing hull geometry and camera
	# near plane, not a second set of maneuverability or zoom balance values.
	var hull := ship.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var radius: float = camera.near * 2.0
	if hull != null and hull.shape != null:
		var bounds: AABB = hull.shape.get_debug_mesh().get_aabb()
		var hull_radius: float = bounds.size.length() * 0.5 + hull.position.length()
		var size: Vector2 = camera.get_viewport().get_visible_rect().size
		var half_angle: float = atan(tan(deg_to_rad(camera.fov) * 0.5) * minf(1.0, size.x / maxf(1.0, size.y)))
		var framing: float = hull_radius / maxf(0.01, sin(half_angle))
		var closest_profile_arm: float = Vector2(float(profile.zoom_min_m), float(profile.height_m)).length()
		radius = maxf(radius, maxf(hull_radius, minf(framing, closest_profile_arm - _collision_sphere.radius)))
	return radius + _collision_sphere.radius

func _hull_clearance() -> float:
	var hull := ship.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var radius: float = camera.near * 2.0
	if hull != null and hull.shape != null:
		radius = maxf(radius, hull.shape.get_debug_mesh().get_aabb().size.length() * 0.5 + hull.position.length())
	return radius + _collision_sphere.radius

func _configure_collision_sphere(profile: Dictionary) -> void:
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var aspect: float = maxf(size.x, size.y) / maxf(1.0, minf(size.x, size.y))
	var near_half: float = camera.near * tan(deg_to_rad(camera.fov) * 0.5)
	_collision_sphere.radius = maxf(float(profile.collision_margin_m), near_half * sqrt(1.0 + aspect * aspect))

func _safe_orbit_position(pivot: Vector3, wanted: Vector3, profile: Dictionary, mix: float) -> Vector3:
	var requested: Vector3 = wanted - pivot
	var distance: float = requested.length()
	if distance <= camera.near: return camera.global_position
	var minimum: float = _minimum_view_distance(profile)
	var direction: Vector3 = requested / distance
	var pivot_clear: bool = _camera_clear(pivot)
	var previous: Vector3 = camera.global_position - pivot
	# A safe old endpoint still needs a swept path when ship motion or viewport
	# framing changes its distance. Only an embedded/uninitialized camera can
	# use the explicit recovery snap below.
	var previous_clear: bool = snapped and _camera_clear(camera.global_position)
	var previous_direction: Vector3 = previous.normalized() if previous.length() > camera.near else camera.global_basis.z.normalized()
	var selected: Vector3 = _sweep_end(pivot, wanted) if pivot_clear else wanted
	var selected_valid: bool = selected.distance_to(pivot) >= minimum and _camera_clear(selected)
	# A shortened arm is useful until it reaches the hull. Then search nearby
	# arms and keep the previous side in the score so tiny orbit changes don't
	# bounce between wall normals or flip to the other side of the vessel.
	if not selected_valid:
		var candidates: Array[Vector3] = []
		# Project the requested arm along the blocking surface. This remains a
		# continuous function of drag input; choosing the previous arm itself as
		# a candidate would repeatedly win the score and freeze the view.
		var ray := PhysicsRayQueryParameters3D.create(pivot, wanted, 64, [ship.get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and not hit.normal.is_zero_approx():
			var normal: Vector3 = hit.normal.normalized()
			var clearance: float = normal.dot(pivot - hit.position) - _collision_sphere.radius * 1.02
			var tangent: Vector3 = direction.slide(normal)
			if tangent.is_zero_approx(): tangent = observation_basis.y.slide(normal)
			if not tangent.is_zero_approx():
				var component: float = clampf(-clearance / distance, -1.0, 1.0)
				candidates.append((tangent.normalized() * sqrt(maxf(0.0, 1.0 - component * component)) + normal * component).normalized())
		for angle: float in [PI / 6.0, -PI / 6.0, PI / 3.0, -PI / 3.0, PI / 2.0, -PI / 2.0, PI]:
			candidates.append(Basis(Vector3.UP, angle) * direction)
			candidates.append(Basis(observation_basis.x, angle) * direction)
		candidates.append(Vector3.UP)
		candidates.append(Vector3.DOWN)
		var best_score: float = INF
		for candidate: Vector3 in candidates:
			var end: Vector3 = pivot + candidate * distance
			if pivot_clear: end = _sweep_end(pivot, end)
			if end.distance_to(pivot) < minimum or not _camera_clear(end): continue
			var score: float = direction.angle_to(candidate)
			if previous_clear: score += previous_direction.angle_to(candidate) * 0.75
			if score < best_score:
				best_score = score
				selected = end
				selected_valid = true
	if not selected_valid:
		# Fully enclosed invalid spawn geometry has no safe spring arm. Keep
		# the last verified view when possible; never force a minimum into a wall.
		return camera.global_position
	if not previous_clear: return selected
	# Smooth a safe dolly segment; if its chord would enter the hull clearance,
	# use an orbital step. Release still uses the profile's smoothing.
	var selected_offset: Vector3 = selected - pivot
	var length: float = minf(previous.length(), selected_offset.length())
	if selected_offset.length() > previous.length(): length = lerpf(previous.length(), selected_offset.length(), mix)
	var rotation: Quaternion = Quaternion(previous_direction, selected_offset.normalized())
	var next_direction: Vector3 = Quaternion.IDENTITY.slerp(rotation, mix) * previous_direction
	var candidate: Vector3 = camera.global_position.lerp(selected, mix)
	if candidate.distance_to(pivot) < minimum:
		candidate = pivot + next_direction * maxf(_hull_clearance(), length)
	# A moving obstacle must retract the arm now, rather than allowing the old
	# dolly position to remain behind its newly obstructed spoke.
	if selected_offset.length() < previous.length() and pivot_clear:
		var safe_arm: Vector3 = _sweep_end(pivot, candidate)
		if safe_arm.distance_to(pivot) >= minimum: candidate = safe_arm
	var end: Vector3 = _dolly_end(camera.global_position, candidate)
	if not _camera_clear(end): return camera.global_position
	# A safe view below the new framing distance can slide out gradually. The
	# hull/near-plane clearance remains hard; desired framing is recovered as
	# soon as the obstacle permits it.
	if end.distance_to(pivot) < _hull_clearance(): return camera.global_position
	return end
