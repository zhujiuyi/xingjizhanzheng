extends SceneTree
## Production Main, formal station/gate boxes and isolated fresh SQLite.
## Explicit positions exercise legal near-hull space plus abnormal embedded
## pivots/cameras; these fixtures are not natural navigation or player saves.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
const Factory = preload("res://runtime/visuals/industrial_visual_factory.gd")
var host: Main
var directory: String
var database_path: String
var checks: int = 0
var failures: Array[String] = []
var captures: Array[String] = []
var geometry: Array[Dictionary] = []
var render_cadence: Array[Dictionary] = []
var front_geometry: Array[Dictionary] = []
var distance_recovery: Array[Dictionary] = []
var finishing: bool = false
var old_interpolation: bool
var old_max_fps: int
var station: StaticBody3D
var gate: StaticBody3D

func _initialize() -> void:
	create_timer(240.0).timeout.connect(func(): print("CAMERA_COLLISION_V14_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 2) -> void:
	for index: int in range(count): await process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 6000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "actual SQLite writer settles")

func start_host() -> void:
	host = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	host.set_process(false)
	host.set_physics_process(false)
	await frames()
	check(host.services_ready, "actual Main opens formal catalog and fresh isolated SQLite")

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames()
	await create_timer(0.25).timeout

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	root.warp_mouse(Vector2(4, 4))
	await frames(4)
	await RenderingServer.frame_post_draw
	var path: String = directory.path_join(label + ".png")
	if check(root.get_texture().get_image().save_png(path) == OK, "native rendered capture " + label): captures.append(path)

func _run() -> void:
	old_interpolation = physics_interpolation
	old_max_fps = Engine.max_fps
	physics_interpolation = false
	Engine.max_fps = 144
	directory = OS.get_environment("XJ_CAMERA_V14_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/camera-collision-v14/%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	database_path = directory.path_join("progress.db")
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	await start_host()
	if not host.services_ready: await finish(); return
	await host._command("new_world", "近障碍镜头独立验收", 1, "")
	await wait_writer()
	if not check(host.state != null, "actual world is created by production Main and SQLite"): await finish(); return
	await host._command("undock", "", 1, "")
	await wait_writer()
	host.ui.show_page("")
	host._sync_presentation_stage()
	host._sync_mouse_mode()
	for id: String in host.world.targets:
		var entry: Dictionary = host.world.targets[id]
		if str(entry.kind) == "station" and station == null: station = entry.node
		if str(entry.kind) == "gate" and gate == null: gate = entry.node
	if not check(station != null and gate != null, "current real sector has formal station and wormhole colliders"): await finish(); return
	check(station.collision_layer == 65 and gate.collision_layer == 65, "real environmental bodies retain camera layer 64 and gameplay layer 1")
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
		check(root.has_focus(), "native suite owns actual OS window focus")
	await geometry_checks()
	await actual_input_checks()
	await persistence_checks()
	await finish()

func profile(rig: XJCameraRig) -> Dictionary:
	return rig._profile()

func set_pose(body: XJFlight, pose: Transform3D) -> void:
	body.global_transform = pose
	body.velocity = Vector3.ZERO
	body.clear_intent()
	body.write_back()
	body.get_global_transform_interpolated()
	body.reset_physics_interpolation()

func make_flight(definition: Dictionary) -> XJFlight:
	var wrapper: CharacterBody3D = Factory.scene(str(definition.ship_id))
	var flight := XJFlight.new()
	for child: Node in wrapper.get_children():
		wrapper.remove_child(child)
		child.owner = null
		flight.add_child(child)
	wrapper.free()
	host.world.add_child(flight)
	var record := D.ShipStateDto.new()
	record.ship_instance_id = "camera_v14_" + str(definition.ship_id)
	record.ship_def_id = str(definition.ship_id)
	record.status = T.ShipStatus.FLYING
	record.quat_w = 1.0
	flight.bind(record, host.store.catalog)
	flight.visual = flight.get_node("VisualRoot")
	return flight

func sphere_query(rig: XJCameraRig, position: Vector3) -> PhysicsShapeQueryParameters3D:
	var ball := SphereShape3D.new()
	# The profile's clearance is a public catalog value, not a duplicated tune.
	# Small tolerance permits contact at floating-point tangency.
	ball.radius = maxf(0.01, float(profile(rig).collision_margin_m) - 0.002)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 64
	query.exclude = [rig.ship.get_rid()]
	query.margin = 0.0
	return query

func overlap(rig: XJCameraRig, position: Vector3) -> bool:
	return not rig.get_world_3d().direct_space_state.intersect_shape(sphere_query(rig, position), 1).is_empty()

func segment_blocked(rig: XJCameraRig, from: Vector3, to: Vector3) -> bool:
	if from.distance_squared_to(to) < 0.000001: return false
	var query: PhysicsShapeQueryParameters3D = sphere_query(rig, from)
	query.motion = to - from
	var fractions: PackedFloat32Array = rig.get_world_3d().direct_space_state.cast_motion(query)
	return fractions.size() >= 2 and fractions[0] < 0.999

func finite_camera(rig: XJCameraRig) -> bool:
	var basis: Basis = rig.camera.global_basis
	return rig.camera.global_position.is_finite() and basis.is_finite() and absf(basis.determinant() - 1.0) < 0.0001 and absf(basis.x.dot(basis.y)) < 0.0001 and absf(basis.y.dot(basis.z)) < 0.0001

func cases_for(body: XJFlight) -> Array[Dictionary]:
	var collision: CollisionShape3D = body.get_node("CollisionShape3D")
	var hull: Vector3 = (collision.shape as BoxShape3D).size * 0.5
	var station_shape: CollisionShape3D = station.get_node("CollisionShape3D")
	var box: Vector3 = (station_shape.shape as BoxShape3D).size * 0.5
	var ring: CollisionShape3D = gate.get_node("FrameCollision_0")
	var ring_box: Vector3 = (ring.shape as BoxShape3D).size * 0.5
	return [
		{"label": "station-face", "pose": station.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, box.z + hull.z + 0.1)), "orbit": Vector2.ZERO},
		{"label": "station-edge", "pose": station.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.75), Vector3(box.x + hull.x + 0.1, 0, box.z + hull.z + 0.1)), "orbit": Vector2(0.25, 0.2)},
		{"label": "station-top", "pose": station.global_transform * Transform3D(Basis(Vector3.RIGHT, 0.8), Vector3(0, box.y + hull.y + 0.1, 0)), "orbit": Vector2(0.4, 0.9)},
		{"label": "station-pivot-close", "pose": station.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, box.z + 0.1)), "orbit": Vector2.ZERO, "abnormal": true},
		{"label": "station-pivot-inside", "pose": station.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, box.z - 1.0)), "orbit": Vector2(0.1, 0.3), "abnormal": true},
		{"label": "station-camera-inside", "pose": station.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(box.x + hull.x + 0.1, 0, box.z + hull.z + 0.1)), "orbit": Vector2(0.5, 0.15), "camera_inside": station.global_position},
		{"label": "gate-face", "pose": ring.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, ring_box.z + hull.z + 0.1)), "orbit": Vector2(0.1, -0.2)},
		{"label": "gate-inner-edge", "pose": ring.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, ring_box.y + hull.y + 0.1, ring_box.z + hull.z + 0.1)), "orbit": Vector2(-0.25, 0.45)},
		{"label": "gate-pivot-close", "pose": ring.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, ring_box.z + 0.1)), "orbit": Vector2.ZERO, "abnormal": true},
		{"label": "gate-camera-inside", "pose": ring.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, ring_box.z + hull.z + 0.1)), "orbit": Vector2(0.2, -0.15), "camera_inside": ring.global_position},
		{"label": "gate-center-open", "pose": gate.global_transform * Transform3D(Basis.IDENTITY, Vector3.ZERO), "orbit": Vector2(0.1, 0.1)},
	]

func geometry_checks() -> void:
	var rig := XJCameraRig.new()
	host.world.add_child(rig)
	var snapshots_before: int = int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	for definition: Dictionary in host.store.catalog.rows("ship_defs"):
		var body: XJFlight = make_flight(definition)
		# Every official ship and all three camera enums first keep the established
		# free-space contract. Heavy collision matrix uses representative hulls.
		for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.TACTICAL, T.CameraMode.FRONT]:
			set_pose(body, Transform3D(Basis.IDENTITY, station.global_position + Vector3(0, 1200, 8000)))
			rig.bind(body, host.store.catalog, mode)
			rig.step(0.0)
			var old_pose: Transform3D = body.global_transform
			rig.begin_observation()
			rig.observe(Vector2(130, -65), 0.002)
			rig.step(0.2)
			rig.end_observation()
			check(finite_camera(rig) and not rig.orbit.is_zero_approx() and old_pose.is_equal_approx(body.global_transform), "%s mode%d free observation stays finite and cannot move ship" % [definition.ship_id, mode])
			if mode == T.CameraMode.FRONT:
				var front: Node3D = body.get_node("FrontCamera")
				check(rig.camera.global_position.is_equal_approx(front.global_position) and not body.visual.visible, "%s retains actual front-camera anchor and deliberate hidden hull" % definition.ship_id)
		await exercise_front_clearance(rig, body)
		if str(definition.ship_id) in ["shuttle_swift", "frigate_kestrel", "miner_anvil", "battleship_bastion"]:
			for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.TACTICAL]:
				for item: Dictionary in cases_for(body):
					for fps: int in [30, 60, 144]:
						await exercise_case(rig, body, mode, item, fps)
		if str(definition.ship_id) == "shuttle_swift":
			for item: Dictionary in cases_for(body):
				if str(item.label) not in ["station-face", "gate-face"]: continue
				for fps: int in [30, 60, 144]:
					await exercise_render_cadence(rig, body, item, fps)
		if str(definition.ship_id) == "battleship_bastion":
			for fps: int in [30, 60, 144]: await exercise_distance_recovery(rig, body, fps)
		host.world.remove_child(body)
		body.free()
	rig.free()
	host.camera.camera.make_current()
	check(int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == snapshots_before, "collision queries and observation create no SQLite snapshots")

func exercise_case(rig: XJCameraRig, body: XJFlight, mode: T.CameraMode, item: Dictionary, fps: int) -> void:
	set_pose(body, item.pose)
	rig.bind(body, host.store.catalog, mode)
	rig.orbit = item.orbit
	if fps == 30: rig.scroll_zoom(-100)
	if fps == 144: rig.scroll_zoom(100)
	await physics_frame
	await process_frame
	rig.step(0.0)
	if item.has("camera_inside"):
		rig.camera.global_position = item.camera_inside
		rig.snapped = true
	var pose: Transform3D = body.global_transform
	var velocity: Vector3 = body.velocity
	var old_orbit: Vector2 = rig.orbit
	var finite: bool = true
	var overlaps: int = 0
	var unsafe_segments: int = 0
	var smallest_distance: float = INF
	var largest_direction_step: float = 0.0
	var turns: float = 0.0
	var previous_position: Vector3 = rig.camera.global_position
	var previous_forward: Vector3 = -rig.camera.global_basis.z
	var previous_overlaps: bool = overlap(rig, previous_position)
	rig.begin_observation()
	for tick: int in range(24):
		# Constant input angular speed at every tested frame interval.
		var motion: Vector2 = Vector2(220.0 / float(fps), -70.0 / float(fps))
		rig.observe(motion, 0.002)
		rig.step(1.0 / float(fps))
		var position: Vector3 = rig.camera.global_position
		var forward: Vector3 = -rig.camera.global_basis.z
		var embedded: bool = overlap(rig, position)
		if embedded: overlaps += 1
		# The first recovery of an already embedded camera can cross a boundary;
		# once recovered, every subsequently interpolated motion must be clear.
		if not previous_overlaps and segment_blocked(rig, previous_position, position): unsafe_segments += 1
		finite = finite_camera(rig) and finite
		smallest_distance = minf(smallest_distance, position.distance_to(rig.render_position()))
		if tick > 0: largest_direction_step = maxf(largest_direction_step, previous_forward.angle_to(forward))
		turns += previous_forward.angle_to(forward)
		previous_forward = forward
		previous_position = position
		previous_overlaps = embedded
	rig.end_observation()
	var label: String = "%s mode%d %s %dfps" % [body.record.ship_def_id, mode, item.label, fps]
	check(finite and overlaps == 0, "camera sphere stays finite and outside actual environmental volumes " + label)
	check(unsafe_segments == 0, "safe camera endpoints also have a safe interpolated movement path " + label)
	check(smallest_distance >= maxf(0.2, rig.camera.near * 2.0), "collision never collapses observation to the target singularity " + label)
	check(not rig.orbit.is_equal_approx(old_orbit) and turns > 0.002 and largest_direction_step < 0.8, "near-obstacle orbit responds visibly without a sudden direction reversal " + label)
	check(pose.is_equal_approx(body.global_transform) and velocity.is_equal_approx(body.velocity), "collision and orbit never mutate actual ship motion " + label)
	geometry.append({"ship": body.record.ship_def_id, "mode": int(mode), "case": str(item.label), "fps": fps, "abnormal_pivot": bool(item.get("abnormal", false)), "zoom": rig.zoom, "sphere_overlaps": overlaps, "unsafe_segments": unsafe_segments, "minimum_target_distance_m": smallest_distance, "maximum_direction_step_rad": largest_direction_step, "visible_direction_travel_rad": turns, "orbit_changed": not rig.orbit.is_equal_approx(old_orbit), "camera_position": vector_json(rig.camera.global_position), "target_position": vector_json(rig.render_position())})
	if body.record.ship_def_id == "shuttle_swift" and mode == T.CameraMode.FOLLOW and fps == 60 and str(item.label) in ["station-face", "station-edge", "gate-face"]:
		rig.camera.make_current()
		await capture(str(item.label))

func vector_json(vector: Vector3) -> Array[float]:
	return [vector.x, vector.y, vector.z]

func exercise_distance_recovery(rig: XJCameraRig, body: XJFlight, fps: int) -> void:
	# The previous camera sphere is safe, but its distance is below FOV framing.
	# It must recover around geometry instead of treating this as an embedded
	# camera and jumping straight to the desired arm on the opposite gate side.
	var hull_shape: CollisionShape3D = body.get_node("CollisionShape3D")
	var half_hull: Vector3 = (hull_shape.shape as BoxShape3D).size * 0.5
	var ring: CollisionShape3D = gate.get_node("FrameCollision_0")
	var half_ring: Vector3 = (ring.shape as BoxShape3D).size * 0.5
	var pivot: Vector3 = ring.global_transform * Vector3(0, 0, half_ring.z + half_hull.z + 5.0)
	set_pose(body, Transform3D(ring.global_basis, pivot))
	rig.bind(body, host.store.catalog, T.CameraMode.TACTICAL)
	# Align the retained world observation with the actual gate yaw, keeping
	# the desired arm on the same normal side even on rotated formal gates.
	rig.observation_basis = gate.global_basis.orthonormalized()
	await physics_frame
	await process_frame
	rig.step(0.0)
	var settings: Dictionary = profile(rig)
	var old_camera: Vector3 = ring.global_transform * Vector3(0, 0, -half_ring.z - 2.0)
	var wanted: Vector3 = pivot + rig.observation_basis * Vector3(0, float(settings.height_m), float(settings.distance_m))
	var clearance: float = float(settings.collision_margin_m)
	var hull_clearance: float = half_hull.length() + clearance
	var framing_distance: float = minf(half_hull.length() / sin(deg_to_rad(rig.camera.fov) * 0.5) + clearance, Vector2(float(settings.zoom_min_m), float(settings.height_m)).length())
	var old_distance: float = old_camera.distance_to(pivot)
	var initial_sphere_safe: bool = not overlap(rig, old_camera)
	var shortcut_blocked: bool = segment_blocked(rig, old_camera, wanted)
	check(initial_sphere_safe and not overlap(rig, pivot) and old_distance > hull_clearance and old_distance < framing_distance and not overlap(rig, wanted) and shortcut_blocked, "distance-recovery fixture proves safe short arm and a blocked direct shortcut %dfps" % fps)
	rig.camera.global_position = old_camera
	rig.camera.global_basis = Transform3D(Basis.IDENTITY, old_camera).looking_at(pivot, Vector3.UP).basis
	rig.snapped = true
	var pose: Transform3D = body.global_transform
	var velocity: Vector3 = body.velocity
	var previous_position: Vector3 = old_camera
	var previous_forward: Vector3 = -rig.camera.global_basis.z
	var orbit_before: Vector2 = rig.orbit
	var overlaps: int = 0
	var unsafe_segments: int = 0
	var hull_intrusions: int = 0
	var finite: bool = true
	var minimum_distance: float = old_distance
	var direction_travel: float = 0.0
	var maximum_direction_step: float = 0.0
	var positions: Array[Dictionary] = []
	for tick: int in range(24):
		rig.observe(Vector2(80.0 / float(fps), -40.0 / float(fps)), 0.002)
		rig.step(1.0 / float(fps))
		var position: Vector3 = rig.camera.global_position
		var distance: float = position.distance_to(rig.render_position())
		var forward: Vector3 = -rig.camera.global_basis.z
		var embedded: bool = overlap(rig, position)
		var blocked: bool = segment_blocked(rig, previous_position, position)
		if embedded: overlaps += 1
		if blocked: unsafe_segments += 1
		if distance < hull_clearance - 0.01: hull_intrusions += 1
		finite = finite_camera(rig) and finite
		minimum_distance = minf(minimum_distance, distance)
		var direction_step: float = previous_forward.angle_to(forward)
		direction_travel += direction_step
		maximum_direction_step = maxf(maximum_direction_step, direction_step)
		positions.append({"position": vector_json(position), "distance_m": distance, "sphere_overlap": embedded, "movement_path_blocked": blocked, "direction_step_rad": direction_step})
		previous_position = position
		previous_forward = forward
	check(finite and overlaps == 0 and unsafe_segments == 0, "a sphere-safe short camera arm recovers with every endpoint and movement segment safe %dfps" % fps)
	check(hull_intrusions == 0 and minimum_distance >= maxf(hull_clearance - 0.01, rig.camera.near * 2.0), "framing recovery may remain short but cannot enter actual hull clearance or target singularity %dfps" % fps)
	check(not orbit_before.is_equal_approx(rig.orbit) and direction_travel > 0.002 and maximum_direction_step < 0.8, "short-arm recovery visibly responds without a blocked shortcut or direction reversal %dfps" % fps)
	check(pose.is_equal_approx(body.global_transform) and velocity.is_equal_approx(body.velocity), "short-arm camera recovery preserves the physical battleship %dfps" % fps)
	distance_recovery.append({"ship": body.record.ship_def_id, "mode": int(T.CameraMode.TACTICAL), "fps_delta_model": fps, "initial_camera_position": vector_json(old_camera), "pivot": vector_json(pivot), "wanted": vector_json(wanted), "initial_sphere_safe": initial_sphere_safe, "direct_shortcut_blocked": shortcut_blocked, "initial_distance_m": old_distance, "hull_clearance_m": hull_clearance, "expected_fov_framing_m": framing_distance, "minimum_distance_m": minimum_distance, "sphere_overlaps": overlaps, "unsafe_segments": unsafe_segments, "hull_clearance_intrusions": hull_intrusions, "visible_direction_travel_rad": direction_travel, "maximum_direction_step_rad": maximum_direction_step, "steps": positions})

func exercise_front_clearance(rig: XJCameraRig, body: XJFlight) -> void:
	var hull_shape: CollisionShape3D = body.get_node("CollisionShape3D")
	var half_hull: Vector3 = (hull_shape.shape as BoxShape3D).size * 0.5
	var station_shape: CollisionShape3D = station.get_node("CollisionShape3D")
	var half_station: Vector3 = (station_shape.shape as BoxShape3D).size * 0.5
	var ring: CollisionShape3D = gate.get_node("FrameCollision_0")
	var half_ring: Vector3 = (ring.shape as BoxShape3D).size * 0.5
	var cases: Array[Dictionary] = [
		{"label": "station-front-face", "pose": station.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, half_station.z + half_hull.z + 0.1))},
		{"label": "gate-front-face", "pose": ring.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, half_ring.z + half_hull.z + 0.1))}
	]
	for item: Dictionary in cases:
		set_pose(body, item.pose)
		rig.bind(body, host.store.catalog, T.CameraMode.FRONT)
		await physics_frame
		await process_frame
		rig.step(0.0)
		var pose: Transform3D = body.global_transform
		var velocity: Vector3 = body.velocity
		var initial_orbit: Vector2 = rig.orbit
		var finite: bool = finite_camera(rig)
		var overlaps: int = 1 if overlap(rig, rig.camera.global_position) else 0
		var orientation_correct: bool = true
		var previous_forward: Vector3 = -rig.camera.global_basis.z
		var direction_travel: float = 0.0
		var largest_direction_step: float = 0.0
		for tick: int in range(24):
			rig.observe(Vector2(4, -2), 0.002)
			rig.step(1.0 / 60.0)
			finite = finite_camera(rig) and finite
			if overlap(rig, rig.camera.global_position): overlaps += 1
			var expected_basis: Basis = (rig.render_ship_transform().basis * Basis(Vector3.UP, rig.orbit.x) * Basis(Vector3.RIGHT, rig.orbit.y)).orthonormalized()
			orientation_correct = rig.camera.global_basis.is_equal_approx(expected_basis) and orientation_correct
			var forward: Vector3 = -rig.camera.global_basis.z
			var direction_step: float = previous_forward.angle_to(forward)
			direction_travel += direction_step
			largest_direction_step = maxf(largest_direction_step, direction_step)
			previous_forward = forward
		var label: String = "%s %s" % [body.record.ship_def_id, item.label]
		check(finite and overlaps == 0, "FRONT sphere remains outside the formal surface with legal hull clearance " + label)
		check(orientation_correct and not initial_orbit.is_equal_approx(rig.orbit) and direction_travel > 0.002 and largest_direction_step < 0.1, "FRONT collision keeps exact ship-relative free-look response " + label)
		check(pose.is_equal_approx(body.global_transform) and velocity.is_equal_approx(body.velocity) and not body.visual.visible, "FRONT clearance cannot alter physical ship or reveal exterior hull " + label)
		front_geometry.append({"ship": body.record.ship_def_id, "case": str(item.label), "sphere_overlaps": overlaps, "orientation_matches_ship_relative_orbit": orientation_correct, "visible_direction_travel_rad": direction_travel, "maximum_direction_step_rad": largest_direction_step, "camera_position": vector_json(rig.camera.global_position), "target_position": vector_json(rig.render_position())})

func exercise_render_cadence(rig: XJCameraRig, body: XJFlight, item: Dictionary, requested_fps: int) -> void:
	# Separate evidence from the 264 synchronous delta models above: every
	# sample here crosses an actual render/process boundary. A max_fps request
	# is a cap, not a claim that hardware renders at exactly that frequency.
	var previous_interpolation: bool = physics_interpolation
	physics_interpolation = true
	set_pose(body, item.pose)
	rig.bind(body, host.store.catalog, T.CameraMode.FOLLOW)
	rig.orbit = item.orbit
	rig.camera.make_current()
	Engine.max_fps = requested_fps
	await physics_frame
	await process_frame
	rig.step(0.0)
	for warmup: int in range(6):
		await process_frame
		rig.step(root.get_process_delta_time())
	check(physics_interpolation and body.is_physics_interpolated() and rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF and rig.camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "real cadence uses ship physics interpolation and one render-owned camera %s cap%d" % [item.label, requested_fps])
	var pose: Transform3D = body.global_transform
	var velocity: Vector3 = body.velocity
	var held_orbit: Vector2 = rig.orbit
	var deltas: Array[float] = []
	var finite: bool = true
	var overlaps: int = 0
	var blocked_segments: int = 0
	var direction_travel: float = 0.0
	var maximum_direction_step: float = 0.0
	var previous_position: Vector3 = rig.camera.global_position
	var previous_forward: Vector3 = -rig.camera.global_basis.z
	var first_frame: int = Engine.get_process_frames()
	var wall_started: int = Time.get_ticks_usec()
	for sample: int in range(20):
		await process_frame
		var delta: float = root.get_process_delta_time()
		deltas.append(delta)
		rig.observe(Vector2(220, -70) * delta, 0.002)
		rig.step(delta)
		var position: Vector3 = rig.camera.global_position
		var forward: Vector3 = -rig.camera.global_basis.z
		finite = finite_camera(rig) and finite
		if overlap(rig, position): overlaps += 1
		if not overlap(rig, previous_position) and segment_blocked(rig, previous_position, position): blocked_segments += 1
		var direction_step: float = previous_forward.angle_to(forward)
		direction_travel += direction_step
		maximum_direction_step = maxf(maximum_direction_step, direction_step)
		previous_position = position
		previous_forward = forward
	var wall_seconds: float = float(Time.get_ticks_usec() - wall_started) / 1000000.0
	var sum_delta: float = 0.0
	var minimum_delta: float = INF
	var maximum_delta: float = 0.0
	for delta: float in deltas:
		sum_delta += delta
		minimum_delta = minf(minimum_delta, delta)
		maximum_delta = maxf(maximum_delta, delta)
	var average_delta: float = sum_delta / float(deltas.size())
	var average_lower_bound: float = 0.45 / float(requested_fps)
	var average_upper_bound: float = maxf(0.10, 4.0 / float(requested_fps))
	var label: String = "%s requested %dfps actual process-frame samples" % [item.label, requested_fps]
	check(Engine.max_fps == requested_fps and Engine.get_process_frames() - first_frame >= 20 and is_finite(average_delta) and minimum_delta > 0.0 and average_delta >= average_lower_bound and average_delta <= average_upper_bound, "actual render cadence advances with bounded measured mean delta " + label)
	check(finite and overlaps == 0 and blocked_segments == 0, "actual process-frame camera sphere and its movement paths remain safe " + label)
	check(not held_orbit.is_equal_approx(rig.orbit) and direction_travel > 0.002 and maximum_direction_step < 0.8, "actual frame-sampled observation stays responsive and continuous " + label)
	check(pose.is_equal_approx(body.global_transform) and velocity.is_equal_approx(body.velocity), "actual render sampling cannot mutate the physical vessel " + label)
	var sampled_frame_advances: int = Engine.get_process_frames() - first_frame
	# Explicit 25 cm tangent position fixtures exercise the real interpolation
	# pump for three physics/render boundaries. They are not natural flight,
	# navigation or a gameplay velocity change; only the test positions move.
	var moving_origin_samples: Array[Dictionary] = []
	var moving_origin_safe: bool = true
	var fixture_pose: Transform3D = item.pose
	var tangent: Vector3 = fixture_pose.basis.x.normalized()
	for index: int in range(3):
		await physics_frame
		var from: Vector3 = body.global_position
		body.global_position += tangent * 0.25
		body.write_back()
		var to: Vector3 = body.global_position
		await process_frame
		rig.step(root.get_process_delta_time())
		var interpolated: Vector3 = body.get_global_transform_interpolated().origin
		var rendered: Vector3 = rig.render_position()
		var along: float = (rendered - from).dot(tangent)
		var transverse: Vector3 = (rendered - from) - tangent * along
		var one_safe: bool = rendered.is_equal_approx(interpolated) and along >= -0.01 and along <= 0.26 and transverse.length() < 0.01 and body.velocity.is_equal_approx(velocity) and finite_camera(rig) and not overlap(rig, rig.camera.global_position)
		moving_origin_safe = moving_origin_safe and one_safe
		moving_origin_samples.append({"physical_from": vector_json(from), "physical_to": vector_json(to), "actual_interpolated_origin": vector_json(interpolated), "camera_render_origin": vector_json(rendered), "interpolation_fraction": Engine.get_physics_interpolation_fraction(), "frame": Engine.get_process_frames(), "along_m": along, "transverse_m": transverse.length(), "sphere_safe_and_same_render_sample": one_safe})
	check(moving_origin_safe and moving_origin_samples.size() == 3, "moving tangent fixtures share the real ship render sample and remain camera-safe " + label)
	render_cadence.append({"case": str(item.label), "display_server": DisplayServer.get_name(), "requested_max_fps": requested_fps, "actual_engine_max_fps": Engine.max_fps, "engine_physics_hz": Engine.physics_ticks_per_second, "physics_interpolation": physics_interpolation, "samples": deltas.size(), "process_frame_advances": sampled_frame_advances, "average_delta_s": average_delta, "minimum_delta_s": minimum_delta, "maximum_delta_s": maximum_delta, "average_delta_lower_bound_s": average_lower_bound, "average_delta_upper_bound_s": average_upper_bound, "observed_fps_from_delta": 1.0 / average_delta, "observed_fps_from_wall_time": float(deltas.size()) / wall_seconds, "elapsed_wall_s": wall_seconds, "sphere_overlaps": overlaps, "unsafe_segments": blocked_segments, "visible_direction_travel_rad": direction_travel, "maximum_direction_step_rad": maximum_direction_step, "delta_samples_s": deltas, "moving_origin_samples": moving_origin_samples})
	physics_interpolation = previous_interpolation
	Engine.max_fps = 144

func actual_input_checks() -> void:
	set_pose(host.world.flight, station.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 240)))
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.camera.step(0.0)
	host.camera.camera.make_current()
	host.state.player().camera_mode = T.CameraMode.FOLLOW
	host.ui.tick(0.3)
	await frames(4)
	if DisplayServer.get_name() != "headless": root.warp_mouse(Vector2(root.size) * 0.5)
	await frames(4)
	check(host._keyboard_control_allowed() and not host.ui.ui_input_blocked(), "actual flight input is unobstructed at near-station fixture")
	var pose: Transform3D = host.world.flight.global_transform
	var before: Vector2 = host.camera.orbit
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(root.size) * 0.5
	host._unhandled_input(down)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(90, -35)
	motion.position = down.position + motion.relative
	host._input(motion)
	host.camera.step(0.1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = motion.position
	up.pressed = false
	host._input(up)
	check(not host.camera.orbit.is_equal_approx(before) and not host.observing and not host.camera.observing and not host.pointer_pick_pending, "actual near-station drag handlers respond and release without becoming a click")
	check(pose.is_equal_approx(host.world.flight.global_transform) and not host.local_navigation.active() and not host.fire_held, "actual camera gesture never starts movement, navigation or fire")
	var held: Vector2 = host.camera.orbit
	for index: int in range(12): host.camera.step(1.0 / 60.0)
	check(host.camera.orbit.is_equal_approx(held), "released near-station observation keeps its angle")
	var view_before: Transform3D = host.camera.camera.global_transform
	host.ui.show_page("pause")
	host._sync_mouse_mode()
	host._unhandled_input(down)
	host._input(motion)
	check(host.camera.orbit.is_equal_approx(held) and not host.pointer_drag_pressed and view_before.is_equal_approx(host.camera.camera.global_transform), "pause GUI keeps the same near-obstacle input isolation")
	host.ui.show_page("")
	host._sync_mouse_mode()
	await frames(4)
	await capture("actual-main-near-station")

func persistence_checks() -> void:
	# A legal far fixture avoids conflating collision recovery with save sealing.
	set_pose(host.world.flight, Transform3D(Basis(Vector3.RIGHT, 0.23), station.global_position + Vector3(0, 1200, 8000)))
	var pose: Transform3D = host.world.flight.global_transform
	var velocity: Vector3 = host.world.flight.velocity
	var first_world: String = host.state.world_id
	for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.FRONT, T.CameraMode.TACTICAL]:
		host.camera.bind(host.world.flight, host.store.catalog, mode)
		host.state.player().camera_mode = mode
		host._request_save("manual", 0)
		await wait_writer()
		var rows: Array[Dictionary] = host.store._records("SELECT p.camera_mode,s.slot_id,s.generation,s.current_snapshot_id FROM save_slot s JOIN player_state p ON p.snapshot_id=s.current_snapshot_id WHERE s.world_id=? AND s.slot_kind='manual' AND s.slot_index=0", [host.state.world_id])
		check(rows.size() == 1 and rows[0].camera_mode == ["follow", "front", "tactical"][int(mode)], "actual SQLite keeps pre-existing camera enum " + str(mode))
		await release_host()
		await start_host()
		await host._command("continue", "", 1, "")
		await wait_writer()
		if not check(host.state != null, "actual restart restores a sealed world"): return
		host.camera.step(0.0)
		check(host.camera.mode == mode and pose.is_equal_approx(host.world.flight.global_transform) and velocity.is_equal_approx(host.world.flight.velocity) and finite_camera(host.camera), "new camera accepts existing saved mode without mutating physical ship " + str(mode))
	await host._command("new_world", "第二独立世界镜头边界", 1, "")
	await wait_writer()
	check(host.state.world_id != first_world and host.camera.ship == host.world.flight and not host.camera.observing and host.camera.orbit.is_zero_approx(), "actual world replacement binds only the new ship and clears old observer state")

func finish() -> void:
	if finishing: return
	finishing = true
	await release_host()
	physics_interpolation = old_interpolation
	Engine.max_fps = old_max_fps
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "geometry_cases": geometry.size(), "geometry": geometry, "render_cadence": render_cadence, "front_geometry": front_geometry, "distance_recovery": distance_recovery, "directory": directory, "display_server": DisplayServer.get_name()}
	print("CAMERA_COLLISION_V14_FINAL_JSON " + JSON.stringify(summary))
	print("CAMERA_COLLISION_V14_RESULT %s checks=%d failures=%d captures=%d cases=%d" % [summary.result, checks, failures.size(), captures.size(), geometry.size()])
	quit(0 if failures.is_empty() else 1)
