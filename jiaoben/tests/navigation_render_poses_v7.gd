extends SceneTree
## Actual engine interpolation + production navigation HUD. Physics distance and
## the display pose intentionally differ; no fabricated state is saved.
const NavigationHUD = preload("res://runtime/ui/navigation_hud.gd")
const Store = preload("res://runtime/data/store.gd")
var checks: int = 0
var failures: Array[String] = []
var interpolated_frames: int = 0
var max_pose_difference: float = 0.0

class PresentationWorld extends Node3D:
	var flight: Node3D
	var targets: Dictionary = {}

class CachedRenderRig extends Node3D:
	var camera: Camera3D
	var cached_ship: Transform3D = Transform3D.IDENTITY
	func render_ship_transform() -> Transform3D: return cached_ship
	func render_position() -> Vector3: return cached_ship.origin

class MovingContact extends MeshInstance3D:
	func _physics_process(delta: float) -> void:
		# Test-only translation exercises the consumer with a real interpolated
		# transform; this is not a second gameplay speed configuration.
		position += Vector3(160.0, 30.0, 0.0) * delta

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): print("NAVIGATION_RENDER_POSES_V7 FAIL timeout"); quit(1))
	call_deferred("_run")

func check(value: bool, title: String) -> void:
	checks += 1
	if not value: failures.append(title); print("FAIL ", title)

func _entry(id: String, kind: String, node: Node3D) -> Dictionary:
	return {"id": id, "title": "插值投影验证体", "kind": kind, "node": node, "navigation_only": false}

func _run() -> void:
	var original_fps: int = Engine.max_fps
	Engine.max_fps = 240
	set_physics_interpolation_enabled(true)
	var store: Store = Store.new(ProjectSettings.globalize_path("res://../jiaoben/tmp/navigation-render-poses-v7-%d.db" % Time.get_ticks_usec()))
	check(store.open(), "isolated actual SQLite source opens")
	var state: XJRuntimeState = store.new_world("导航投影独立检查", 72)
	check(state != null, "fresh catalog is frozen and available")
	if state == null: store.close(); quit(1); return
	# A headless Window has no drawable size. Use an actual sized Viewport for
	# projection math rather than an invented screen point or zero-size Control.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var world: PresentationWorld = PresentationWorld.new()
	viewport.add_child(world)
	world.flight = Node3D.new()
	world.add_child(world.flight)
	world.flight.position = Vector3(0, 0, -300)
	world.flight.reset_physics_interpolation()
	var target: MovingContact = MovingContact.new()
	target.set_physics_process(false)
	target.mesh = SphereMesh.new()
	target.position = Vector3(200, 80, -1800)
	world.add_child(target)
	target.get_global_transform_interpolated()
	target.reset_physics_interpolation()
	var fixed: Node3D = Node3D.new()
	fixed.position = Vector3(-100, 120, -2200)
	world.add_child(fixed)
	fixed.get_global_transform_interpolated()
	fixed.reset_physics_interpolation()
	world.targets["moving"] = _entry("moving", "npc", target)
	world.targets["fixed"] = _entry("fixed", "marker", fixed)
	var rig: CachedRenderRig = CachedRenderRig.new()
	viewport.add_child(rig)
	rig.camera = Camera3D.new()
	rig.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	rig.camera.current = true
	rig.camera.fov = 60.0
	rig.camera.far = 16000.0
	rig.add_child(rig.camera)
	# Simulate the camera's once-per-render cached ship pose, rather than using
	# the newest physics coordinates. This deliberate difference catches a HUD
	# accidentally bypassing the camera contract even on a headless viewport.
	rig.cached_ship = Transform3D(Basis(Vector3.UP, 0.15), Vector3(36, 14, -300))
	var hud: NavigationHUD = NavigationHUD.new()
	viewport.add_child(hud)
	await process_frame
	hud.configure(world, rig, store.catalog)
	check(hud.radar.tooltip_text == "左键拖动观察 · 双击总览接近 · 滚轮缩放", "navigation hint matches the current pointer controls")
	target.set_physics_process(true)
	for frame: int in range(80):
		await process_frame
		var actual_pose: Transform3D = target.global_transform
		var rendered_pose: Transform3D = target.get_global_transform_interpolated()
		var difference: float = rendered_pose.origin.distance_to(actual_pose.origin)
		max_pose_difference = maxf(max_pose_difference, difference)
		if difference > 0.00001: interpolated_frames += 1
		hud.selected_id = "moving"
		var selected: Dictionary = hud.target_geometry()
		var expected: Vector2 = rig.camera.unproject_position(rendered_pose.origin)
		check(not selected.is_empty() and selected.on_screen and selected.end.distance_to(expected) < 0.001, "selection uses actual rendered contact pose frame " + str(frame))
		check(selected.start.distance_to(rig.camera.unproject_position(rig.cached_ship.origin)) < 0.001, "link starts at the camera's cached rendered hull frame " + str(frame))
		check(is_equal_approx(float(selected.distance_m), world.flight.global_position.distance_to(actual_pose.origin)), "selected distance remains physical frame " + str(frame))
		hud.refresh()
		var moving: Dictionary = {}
		for contact: Dictionary in hud.contacts:
			if str(contact.id) == "moving": moving = contact
		var relative: Vector3 = rig.cached_ship.basis.inverse() * (rendered_pose.origin - rig.cached_ship.origin)
		check(not moving.is_empty() and (moving.relative as Vector3).distance_to(relative) < 0.001, "radar shares camera render pose frame " + str(frame))
		check(is_equal_approx(float(moving.distance_m), float(selected.distance_m)), "radar distance remains physical frame " + str(frame))
		hud.selected_id = "fixed"
		var markers: Array[Dictionary] = hud.marker_geometry()
		var moving_marker: Dictionary = {}
		for marker: Dictionary in markers:
			if str(marker.id) == "moving": moving_marker = marker
		check(not moving_marker.is_empty() and moving_marker.point.distance_to(expected) < 0.001, "unselected marker matches rendered model frame " + str(frame))
		check(target.global_transform.is_equal_approx(actual_pose), "drawing consumers do not change physics frame " + str(frame))
	check(interpolated_frames > 0 and max_pose_difference > 0.00001, "real 60Hz physics and 240fps frames expose different interpolation poses")
	target.set_physics_process(false)
	# A target that crosses the physical sensor edge may still have an old
	# interpolated image. Detection must not accidentally authorize that image.
	target.position = Vector3(0, 0, -hud.sensor_limit - 1000.0)
	hud.refresh()
	check(not hud.contacts.any(func(contact: Dictionary): return str(contact.id) == "moving"), "physical sensor range rejects a lingering display pose")
	check(not hud.marker_geometry().any(func(marker: Dictionary): return str(marker.id) == "moving"), "unselected markers obey physical detection rather than interpolation history")
	await physics_frame
	target.force_update_transform()
	target.get_global_transform_interpolated()
	target.reset_physics_interpolation()
	await process_frame
	check(target.get_global_transform_interpolated().is_equal_approx(target.global_transform), "physics-boundary reset collapses a teleported contact to its actual pose")
	root.remove_child(viewport); viewport.queue_free()
	store.close()
	await process_frame
	await create_timer(0.25).timeout
	Engine.max_fps = original_fps
	print("NAVIGATION_RENDER_POSES_V7 %s checks=%d failures=%d interpolated_frames=%d maximum_pose_difference_m=%.6f" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), interpolated_frames, max_pose_difference])
	quit(0 if failures.is_empty() else 1)
