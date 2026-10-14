extends Node
## Production Main commands, formal site geometry, real sky/planet pixels and
## fresh SQLite only. Initial site/pose and unlock grants are explicit fixtures.
const Main = preload("res://runtime/main.gd")
const Space = preload("res://runtime/space_coordinates.gd")
const T = preload("res://contracts/contract_types.gd")
class UnavailableEnemyFactory extends RefCounted:
	static func enemy_scene(_archetype: String) -> CharacterBody3D:
		return null
var host: Main
var directory: String = ""
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var observations: Array[Dictionary] = []
var baseline: bool = false
var glyph_helper_only: bool = false
var finishing: bool = false
var requested_window_size: Vector2i = Vector2i(1440, 900)
var label_alpha_geometry: Dictionary = {}
@onready var root: Window = get_tree().root

func _ready() -> void:
	get_tree().set_meta("xj_warp_scene_v21_diagnostic", true)
	# A thin fixed v20 wrapper may load this Node against the old actual PCK.
	# This keeps the old production diagnostic from recursively launching itself.
	get_tree().set_meta("xj_warp_visual_v20_diagnostic", true)
	baseline = OS.get_environment("XJ_WARP_SCENE_V21_BASELINE") == "1"
	glyph_helper_only = OS.get_environment("XJ_WARP_SCENE_V21_GLYPH_ONLY") == "1"
	get_tree().create_timer(360.0).timeout.connect(func(): check(false, "watchdog"); finish())
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func has_property(object: Object, name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if str(property.name) == name: return true
	return false

func departure_active() -> bool:
	return has_property(host.world, "departure_active") and bool(host.world.get("departure_active"))

func projection() -> Node3D:
	return host.world.get("departure_projection") as Node3D if has_property(host.world, "departure_projection") else null

func _run() -> void:
	var script_path: String = OS.get_environment("XJ_WARP_SCENE_V21_SCRIPT").replace("\\", "/")
	var prefix: String = script_path.get_base_dir().get_base_dir().path_join("tmp/warp-scene-v21") if not script_path.is_empty() else ProjectSettings.globalize_path("res://../jiaoben/tmp/warp-scene-v21").replace("\\", "/")
	directory = OS.get_environment("XJ_WARP_SCENE_V21_DIRECTORY").replace("\\", "/")
	var uuid := RegEx.new()
	uuid.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	if not check(directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == prefix and uuid.search(directory.get_file()) != null and not FileAccess.file_exists(directory.path_join("progress.db")), "fresh scoped UUID database required"):
		await finish(); return
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1440, 900)
	root.content_scale_factor = 1.0
	host = Main.new()
	host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host)
	await frames(4)
	if not check(host.services_ready, "real Main opens formal PCK catalog and isolated SQLite"): await finish(); return
	await host._command("new_world", "真实跃迁场景独立验收", 1, "")
	if not check(host.state != null and host.store.catalog.table_names.has("site_defs"), "formal spatial world initialized"): await finish(); return
	host.set_process(false)
	host.set_physics_process(false)
	host._command("undock", "", 1, "")
	await wait_stable()
	if not check(host.state.ship().status == T.ShipStatus.FLYING and is_instance_valid(host.world), "real undock reaches flight"): await finish(); return
	host.ui.show_page("")
	host.preferences["vfx_intensity"] = 1.0
	host._process(0.0)
	if glyph_helper_only:
		await glyph_helper_checks()
		await finish(); return
	if baseline:
		await baseline_route()
		await finish(); return
	if not check(has_property(host.world, "departure_active") and has_property(host.world, "departure_projection"), "scene supplies strategic departure presentation"):
		await finish(); return
	for kind: String in ["station", "gate", "resource"]:
		await departure_route(kind)
	await real_sky_camera_matrix()
	await interruption_and_arrival_checks()
	await finish()

func wait_stable() -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while host.busy and Time.get_ticks_msec() < deadline: await frames(1)
	await frames(4)
	check(not host.busy, "asynchronous business/save endpoint settles")

func formal_target(kind: String, different_site: String = "") -> String:
	for id: String in host.world.targets:
		var entry: Dictionary = host.world.targets[id]
		if str(entry.kind) == kind and (different_site.is_empty() or host.world.target_site(id) != different_site): return id
	return ""

func place_near(id: String) -> void:
	if host.local_navigation.active(): host._command("nav_stop", "", 1, "")
	var site_id: String = host.world.target_site(id)
	Space.assign(host.state, "ship", host.state.ship().ship_instance_id, site_id)
	host.world.strategic_render_position = {}
	host.world.flight.global_position = host.world.targets[id].node.global_position + Vector3(0, 0, 650)
	host.world.flight.global_basis = Basis.IDENTITY
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.refresh_site()
	check(host.world.sync_entities(), "explicit formal-site positioning synchronizes entities")
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.camera.mode = T.CameraMode.FOLLOW
	host.camera.reset_observation()
	host.camera.zoom = 1.0
	host.camera.snapped = false
	host.ui.show_page("")
	host._process(1.0)
	await frames(4)
	host._process(0.0)

func advance_to_travel() -> void:
	for index: int in range(3000):
		if host.local_navigation.phase != "warmup": break
		host._physics_process(1.0 / 60.0)
		host._process(1.0 / 60.0)
		if index % 30 == 0: await frames(2)
	await frames(3)
	check(host.local_navigation.phase == "travel", "actual alignment and charging enter travel")

func advance(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001 and host.local_navigation.phase == "travel":
		var step: float = minf(1.0 / 60.0, remaining)
		host._physics_process(step)
		host._process(step)
		remaining -= step
	await frames(3)
	host._process(0.0)

func local_echo(id: String) -> bool:
	host.ui.navigation_hud.refresh()
	for contact: Dictionary in host.ui.navigation_hud.contacts:
		if str(contact.id) == id and not bool(contact.bearing): return true
	return false

func static_poses(site_id: String) -> Dictionary:
	var result: Dictionary = {}
	for id: String in host.world.targets:
		var entry: Dictionary = host.world.targets[id]
		if not bool(entry.get("navigation_only", false)) and str(entry.kind) not in ["npc", "wreck"] and host.world.target_site(id) == site_id:
			result[id] = entry.node.global_transform
	return result

func unchanged_poses(values: Dictionary) -> bool:
	for id: String in values:
		if not host.world.targets.has(id): return false
		var transform: Transform3D = host.world.targets[id].node.global_transform
		if not transform.is_equal_approx(values[id]): return false
	return true

func persisted_pose() -> String:
	var snapshot_id: String = host.state.snapshot.meta.snapshot_id
	return JSON.stringify({"ship": host.store._records("SELECT * FROM ship_state WHERE snapshot_id=?", [snapshot_id]), "spatial": host.store._records("SELECT * FROM spatial_state WHERE snapshot_id=?", [snapshot_id])})

func departure_route(kind: String) -> void:
	var source: String = formal_target(kind)
	if not check(not source.is_empty(), "formal departure geometry exists: " + kind): return
	await place_near(source)
	var origin_site: String = Space.current_site(host.state)
	var destination: String = formal_target("resource" if kind != "resource" else "station", origin_site)
	var body: Node3D = host.world.targets[source].node
	var start: Vector3 = host.world.flight.global_position
	var originals: Dictionary = static_poses(origin_site)
	check(body.is_visible_in_tree() and local_echo(source), "departure body and real local echo visible before charging: " + kind)
	if not check(host._navigation_command("warp", destination), "production saved warp command accepted: " + kind): return
	var sql_before: String = persisted_pose()
	var snapshot_count: int = int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	check(host.local_navigation.phase == "warmup" and body.is_visible_in_tree() and local_echo(source) and not departure_active(), "charging retains actual departure geometry and local echoes: " + kind)
	if DisplayServer.get_name() != "headless": await capture(kind + "-charge")
	await advance_to_travel()
	check(departure_active() and not body.is_visible_in_tree() and not local_echo(source), "travel removes departure originals and local echoes immediately: " + kind)
	check(not host.world.targets[destination].node.is_visible_in_tree(), "destination geometry cannot appear before arrival: " + kind)
	var projected: Node3D = projection()
	if check(is_instance_valid(projected) and projected.is_visible_in_tree(), "departure retains a short visual recession: " + kind):
		check(projected.find_children("*", "CollisionObject3D", true, false).is_empty(), "recession contains no collision authority: " + kind)
		var meshes: Array[Node] = projected.find_children("*", "MeshInstance3D", true, false)
		var scripted: bool = projected.get_script() != null
		for mesh: Node in meshes: scripted = scripted or mesh.get_script() != null
		check(not meshes.is_empty() and not scripted, "recession uses formal mesh copies with no executable scripts: " + kind)
	await advance(0.15)
	projected = projection()
	check(is_instance_valid(projected) and projected.position.dot(-host.local_navigation.warp_heading) > 1.0, "real elapsed travel moves scenery behind the ship: " + kind)
	if DisplayServer.get_name() != "headless": await capture(kind + "-recession")
	await advance(0.45)
	projected = projection()
	check(departure_active() and (not is_instance_valid(projected) or not projected.is_visible_in_tree()) and not body.is_visible_in_tree() and not local_echo(source), "old site disappears during travel instead of persisting until arrival: " + kind)
	check(unchanged_poses(originals) and host.world.flight.global_position == start and Space.current_site(host.state) == origin_site, "recession never displaces formal geometry or durable local ship/site: " + kind)
	check(not host.world.strategic_render_position.is_empty() and persisted_pose() == sql_before and int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == snapshot_count, "strategic route changes no committed endpoint pose: " + kind)
	if DisplayServer.get_name() != "headless": await capture(kind + "-transit")
	host._command("nav_stop", "", 1, "")
	host._process(1.0)
	await frames(4)
	check(host.local_navigation.phase == "cancelled" and not departure_active() and projection() == null and body.is_visible_in_tree() and local_echo(source), "real stop restores departure visuals and radar: " + kind)
	check(Space.current_site(host.state) == origin_site and host.world.flight.global_position == start and host.world.flight.velocity == Vector3.ZERO and host.world.strategic_render_position.is_empty() and unchanged_poses(originals), "real stop restores precise origin and removes transient route: " + kind)
	check(not host.warp_visual.visible and is_zero_approx(host.camera._warp_fov_offset_deg), "stop finishes blur and lens recovery: " + kind)
	if DisplayServer.get_name() != "headless": await capture(kind + "-stopped")

func baseline_route() -> void:
	var source: String = formal_target("gate")
	if not check(not source.is_empty(), "old formal wormhole exists"): return
	await place_near(source)
	var destination: String = formal_target("station", Space.current_site(host.state))
	check(host._navigation_command("warp", destination), "old actual PCK accepts saved strategic route")
	if DisplayServer.get_name() != "headless": await capture("baseline-wormhole-charge")
	await advance_to_travel()
	await advance(0.6)
	var old_geometry_visible: bool = host.world.targets[source].node.is_visible_in_tree()
	var old_local_echo: bool = local_echo(source)
	observations.append({"kind": "old-actual-pck", "phase": host.local_navigation.phase, "source_visible_during_travel": old_geometry_visible, "source_local_echo_during_travel": old_local_echo, "strategic_render_position": host.world.strategic_render_position.duplicate(true)})
	check(host.local_navigation.phase == "travel" and old_geometry_visible, "EXPECTED_DEFECT: old departure wormhole remains visible after 0.6 s of actual travel")
	if DisplayServer.get_name() != "headless":
		await capture("baseline-wormhole-transit")
		await pixel_pair("baseline-natural-sky", false)

func real_sky_camera_matrix() -> void:
	var source: String = formal_target("station")
	await place_near(source)
	var destination: String = formal_target("resource", Space.current_site(host.state))
	if not check(host._navigation_command("warp", destination), "natural background matrix uses a real saved route"): return
	await advance_to_travel()
	await advance(0.6)
	var fixed_pose: Transform3D = host.world.flight.global_transform
	var fixed_sql: String = persisted_pose()
	var fixed_elapsed: float = host.local_navigation.travel_elapsed_s
	for physical_size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(2859, 945), Vector2i(3440, 1370)]:
		for scale_factor: float in [1.0, 2.0]:
			requested_window_size = physical_size
			root.size = physical_size
			root.content_scale_factor = scale_factor
			await frames(5)
			for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.FRONT, T.CameraMode.TACTICAL]:
				host.camera.mode = mode
				host.camera.reset_observation()
				host.camera.zoom = 1.0
				host.camera.snapped = false
				host._process(0.0)
				await frames(4)
				host._process(0.0)
				var fx: XJWarpVisual = host.warp_visual
				check(fx.envelope > 0.9 and fx.visible and not host.world.targets[source].node.is_visible_in_tree(), "real transit presentation active %s/%s/%s" % [physical_size, scale_factor, mode])
				check(not fx.ship_rect.has_area() if mode == T.CameraMode.FRONT else fx.ship_rect.has_area() and fx.ship_rect.get_area() < 0.95, "camera hull protection is limited to visible ship %s/%s/%s" % [physical_size, scale_factor, mode])
				if DisplayServer.get_name() != "headless": await pixel_pair("sky-%dx%d-%d-%d" % [physical_size.x, physical_size.y, int(scale_factor), mode], true)
	# The close external view used in the user's screenshot must not cause a
	# single behind-camera AABB corner to protect the entire background.
	host.camera.mode = T.CameraMode.FOLLOW
	host.camera.reset_observation()
	var profile: Dictionary = host.camera._profile()
	host.camera.zoom = float(profile.zoom_min_m) / float(profile.distance_m)
	host.camera.snapped = false
	host._process(0.0)
	await frames(4)
	host._process(0.0)
	check(host.warp_visual.ship_rect.get_area() < 0.95, "minimum external camera distance cannot disable full-screen blur")
	if DisplayServer.get_name() != "headless": await pixel_pair("sky-close-follow", true)
	host.camera.zoom = 1.0
	var before_orbit: Vector2 = host.camera.orbit
	host.camera.observe(Vector2(70, 18), 0.006)
	host.camera.step(1.0)
	host._process(0.0)
	check(host.camera.orbit != before_orbit and host.warp_visual.stream.global_basis.z.dot(-host.local_navigation.warp_heading) > 0.999, "free observation retains real world-direction wake")
	if DisplayServer.get_name() != "headless": await pixel_pair("sky-free-observation", true)
	# Put the real catalog planet within view without substituting geometry or
	# changing its position/radius. This is an explicit camera-only fixture.
	var planet: String = formal_target("planet")
	if check(not planet.is_empty(), "formal celestial planet exists in the route"):
		var ray: Vector3 = host.world.target_direction(planet)
		host.camera.mode = T.CameraMode.FOLLOW
		host.camera.observation_basis = Basis.looking_at(ray, Vector3.UP if absf(ray.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
		host.camera.orbit = Vector2.ZERO
		host.camera.snapped = false
		host.camera.step(1.0)
		host._process(0.0)
		await frames(4)
		host._process(0.0)
		var node: Node3D = host.world.targets[planet].node
		var projected: Vector2 = host.camera.camera.unproject_position(node.global_position)
		check(node.is_visible_in_tree() and not host.camera.camera.is_position_behind(node.global_position) and Rect2(Vector2.ZERO, host.camera.camera.get_viewport().get_visible_rect().size).has_point(projected), "real celestial remains visible and correctly projected during transit")
		if DisplayServer.get_name() != "headless": await pixel_pair("sky-real-planet", true)
	var frozen_clock: float = host.warp_visual.elapsed
	var frozen_envelope: float = host.warp_visual.envelope
	var frozen_projection_elapsed: float = float(host.world.get("departure_elapsed_s"))
	host.ui.show_page("pause")
	host._physics_process(0.7)
	host._process(0.7)
	check(host.local_navigation.travel_elapsed_s == fixed_elapsed and host.warp_visual.elapsed == frozen_clock and host.warp_visual.envelope == frozen_envelope and float(host.world.get("departure_elapsed_s")) == frozen_projection_elapsed, "pause freezes actual route, recession and effect clocks")
	host.ui.show_page("")
	host.preferences["vfx_intensity"] = 0.0
	host._process(0.0)
	check(not host.warp_visual.visible and not host.warp_visual.stream.visible and host.warp_visual._mesh.get_surface_count() == 0 and is_zero_approx(host.camera._warp_fov_offset_deg), "intensity zero disables all presentation during an actual route")
	check(not host.world.targets[source].node.is_visible_in_tree() and not local_echo(source) and departure_active(), "intensity zero cannot restore departed geometry or local echoes")
	host.preferences["vfx_intensity"] = 1.0
	host._process(0.0)
	check(host.world.flight.global_transform.is_equal_approx(fixed_pose) and persisted_pose() == fixed_sql and host.local_navigation.travel_elapsed_s == fixed_elapsed, "all camera, pixel, pause and intensity experiments leave navigation/SQL pose untouched")
	host._command("nav_stop", "", 1, "")
	host._process(1.0)
	root.size = Vector2i(1440, 900)
	root.content_scale_factor = 1.0
	await frames(5)

func pixel_pair(label: String, require_blur: bool) -> void:
	var fx: XJWarpVisual = host.warp_visual
	var old_effect: float = float(fx._material.get_shader_parameter("effect_strength"))
	var stream_visible: bool = fx.stream.visible
	fx.stream.hide()
	# Keep the same camera/FOV, route fraction, source sky and actual hull/HUD.
	# Only toggle shader strength; changing preferences would also change FOV.
	fx._material.set_shader_parameter("effect_strength", 0.0)
	var sharp: Image = await capture(label + "-sharp")
	fx._material.set_shader_parameter("effect_strength", old_effect)
	var blurred: Image = await capture(label + "-blur")
	if sharp == null or blurred == null or sharp.get_size() != blurred.get_size(): return
	var glyph_witness: Dictionary = await actual_label_compositing(host.ui.top, sharp, blurred, fx)
	var glyph_alpha: Image = glyph_witness.coverage_image
	glyph_witness.erase("coverage_image")
	if not check(glyph_alpha != null and glyph_alpha.get_size() == sharp.get_size(), "actual foreground coverage is derived at client pixel size: " + label): return
	fx.stream.visible = stream_visible
	var picture_size: Vector2 = Vector2(sharp.get_size())
	var hull_mask: Image = null
	var mask_active: bool = bool(fx._material.get_shader_parameter("protect_ship"))
	if has_property(fx, "_mask_viewport"):
		var mask_viewport: SubViewport = fx.get("_mask_viewport") as SubViewport
		if is_instance_valid(mask_viewport): hull_mask = mask_viewport.get_texture().get_image()
	if require_blur and not check(hull_mask != null and not hull_mask.is_empty(), "production silhouette mask renders formal hull geometry: " + label): return
	if require_blur:
		var mask_camera: Camera3D = fx.get("_mask_camera") as Camera3D
		var mask_body: Node3D = fx.get("_mask_body") as Node3D
		var lens: Camera3D = host.camera.camera
		if mask_active:
			check(is_instance_valid(mask_camera) and mask_camera.global_transform.is_equal_approx(lens.global_transform) and is_equal_approx(mask_camera.fov, lens.fov) and mask_camera.projection == lens.projection and mask_camera.keep_aspect == lens.keep_aspect and is_equal_approx(mask_camera.near, lens.near) and is_equal_approx(mask_camera.far, lens.far), "active mask camera matches actual projection and same-frame view: " + label)
			check(is_instance_valid(mask_body) and mask_body.global_transform.is_equal_approx(host.camera.render_ship_transform()), "active formal silhouette shares visible ship render pose: " + label)
		else:
			var inactive_viewport: SubViewport = fx.get("_mask_viewport") as SubViewport
			check(not mask_body.is_visible_in_tree() and inactive_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden cockpit hull disables silhouette rendering and protection: " + label)
		check(is_instance_valid(mask_body) and mask_body.find_children("*", "CollisionObject3D", true, false).is_empty() and mask_body.find_children("*", "Light3D", true, false).is_empty() and mask_body.get_script() == null, "formal silhouette contains no gameplay authority: " + label)
	var client_bounds := Rect2i(Vector2i.ZERO, sharp.get_size())
	var hull: Rect2i = clip_positive_rect(Rect2i(Vector2i(fx.ship_rect.position * picture_size), Vector2i(fx.ship_rect.size * picture_size)), client_bounds)
	# FRONT has no hull region. Shrinking an empty/small Rect2i produces a
	# negative size, and has_point() then emits one diagnostic per sampled pixel.
	# An invalid or absent ROI stays empty; never abs() it into another region.
	var hull_inner: Rect2i = Rect2i(hull.position + Vector2i(3, 3), hull.size - Vector2i(6, 6)) if hull.size.x > 6 and hull.size.y > 6 else Rect2i()
	var panels: Array[Rect2i] = []
	for control: Control in [host.ui.navigation_frame, host.ui.hud_left, host.ui.instrument, host.ui.overview, host.ui.equipment_bar, host.ui.target_panel, host.ui.controls, host.ui.toast, host.ui.navigation_hud.radar_frame]:
		if is_instance_valid(control) and control.is_visible_in_tree():
			var panel: Rect2i = pixel_rect(control, sharp.get_size())
			if positive_rect(panel):
				panel = clip_positive_rect(panel.grow(8), client_bounds)
				if positive_rect(panel): panels.append(panel)
	var changed: int = 0
	var scenery_samples: int = 0
	var sharp_energy: float = 0.0
	var blurred_energy: float = 0.0
	var hull_max: float = 0.0
	var hull_samples: int = 0
	var hull_worst: Dictionary = {}
	var dense_hull_max: float = 0.0
	var dense_hull_samples: int = 0
	var aabb_background_samples: int = 0
	var aabb_background_changed: int = 0
	var aabb_background_sharp_energy: float = 0.0
	var aabb_background_blurred_energy: float = 0.0
	var glyph_samples: int = int(glyph_witness.samples)
	var preserved_glyphs: int = int(glyph_witness.preserved)
	for y: int in range(1, sharp.get_height() - 3, 3):
		for x: int in range(1, sharp.get_width() - 3, 3):
			var point := Vector2i(x, y)
			var before: Color = sharp.get_pixelv(point)
			var after: Color = blurred.get_pixelv(point)
			var difference: float = channel_difference(before, after)
			var coverage: Vector2 = Vector2.ZERO
			if mask_active and hull_mask != null and positive_rect(hull) and hull.grow(12).has_point(point):
				coverage = mask_coverage_range(hull_mask, point, sharp.get_size())
			elif baseline and mask_active and positive_rect(hull_inner) and hull_inner.has_point(point):
				coverage = Vector2.ONE
			if coverage.x >= 0.995:
				hull_samples += 1
				if hull_mask != null and difference > hull_max:
					hull_worst = mask_sample_evidence(hull_mask, point, sharp.get_size())
					hull_worst["pixel"] = [x, y]
					hull_worst["difference"] = difference
				hull_max = maxf(hull_max, difference)
				if hull_mask != null:
					var dense: Dictionary = mask_sample_evidence(hull_mask, point, sharp.get_size())
					if float(dense.dense_minimum) >= 0.995:
						dense_hull_samples += 1
						dense_hull_max = maxf(dense_hull_max, difference)
			if coverage.y > 0.01: continue
			var covered: bool = false
			for panel: Rect2i in panels:
				if panel.has_point(point): covered = true; break
			if covered: continue
			scenery_samples += 1
			if difference > 0.008: changed += 1
			var neighbor_x := Vector2i(x + 2, y)
			var neighbor_y := Vector2i(x, y + 2)
			var sharp_gradient: float = absf(luma(before) - luma(sharp.get_pixelv(neighbor_x))) + absf(luma(before) - luma(sharp.get_pixelv(neighbor_y)))
			var blurred_gradient: float = absf(luma(after) - luma(blurred.get_pixelv(neighbor_x))) + absf(luma(after) - luma(blurred.get_pixelv(neighbor_y)))
			sharp_energy += sharp_gradient
			blurred_energy += blurred_gradient
			if positive_rect(hull_inner) and hull_inner.has_point(point) and coverage.y <= 0.01:
				aabb_background_samples += 1
				if difference > 1.0 / 255.0: aabb_background_changed += 1
				aabb_background_sharp_energy += sharp_gradient
				aabb_background_blurred_energy += blurred_gradient
	var ratio: float = blurred_energy / maxf(sharp_energy, 0.000001)
	var viewport: Viewport = host.camera.camera.get_viewport()
	var texture: ViewportTexture = viewport.get_texture()
	var visible_size: Vector2 = viewport.get_visible_rect().size
	var native_size: Vector2i = DisplayServer.window_get_size(root.get_window_id())
	var final_transform: Transform2D = root.get_final_transform()
	var record: Dictionary = {"label": label, "fixture": "formal-panorama-planet-player-hull-real-HUD-no-added-environment-geometry", "size": [sharp.get_width(), sharp.get_height()], "actual_image_size": [sharp.get_width(), sharp.get_height()], "requested_window_size": [requested_window_size.x, requested_window_size.y], "window_size_property": [root.size.x, root.size.y], "native_client_size": [native_size.x, native_size.y], "viewport_texture_metadata_size": [texture.get_width(), texture.get_height()], "viewport_visible_size": [visible_size.x, visible_size.y], "window_content_scale_size": [root.content_scale_size.x, root.content_scale_size.y], "viewport_final_transform": [final_transform.x.x, final_transform.x.y, final_transform.y.x, final_transform.y.y, final_transform.origin.x, final_transform.origin.y], "ui_scale": root.content_scale_factor, "mode": int(host.camera.mode), "scenery_samples": scenery_samples, "changed_samples": changed, "sharp_gradient_energy": sharp_energy, "blurred_gradient_energy": blurred_energy, "sharpness_ratio": ratio, "hull_samples": hull_samples, "hull_max_difference": hull_max, "hud_glyph_mask": "actual-shaped-label-full-alpha-coverage-isolated-transparent-viewport", "hud_glyph_samples": glyph_samples, "hud_preserved_glyphs": preserved_glyphs, "shader_radius_px": fx._material.get_shader_parameter("blur_radius_px"), "shader_lod": fx._material.get_shader_parameter("blur_lod"), "ship_rect_area": fx.ship_rect.get_area()}
	record["hull_mask_kind"] = "real-formal-hull-silhouette" if hull_mask != null else "historical-AABB-only-baseline"
	record["hud_alpha_geometry"] = label_alpha_geometry.duplicate(true)
	record["hud_compositing_witness"] = glyph_witness
	record["hud_glyph_mask"] = "actual-main-label-colour-and-coverage-background-witness-no-auxiliary-font-renderer"
	record["hull_mask_active"] = mask_active
	record["hull_mask_image_size"] = [hull_mask.get_width(), hull_mask.get_height()] if hull_mask != null else []
	# The native fdf08c3c evidence showed narrow holes at skipped +/-1 texels:
	# nine sparse probes were white while the shader's bilinear core was partial.
	# Keep the same erosion radius and pixel tolerance, checking every texel.
	record["hull_sampling"] = "complete-5x5-two-mask-texel-erosion-coverage-0.995-pixel-tolerance-2/255"
	record["hull_worst_interior_sample"] = hull_worst
	record["hull_dense_diagnostic"] = {"samples": dense_hull_samples, "maximum_difference": dense_hull_max, "method": "all 25 texels of the same two-texel erosion, no skipped adjacent texels"}
	if mask_active:
		var mask_camera: Camera3D = fx.get("_mask_camera") as Camera3D
		if is_instance_valid(mask_camera):
			record["hull_projection_diagnostic"] = {"actual_camera": projection_values(host.camera.camera.get_camera_projection()), "mask_camera": projection_values(mask_camera.get_camera_projection()), "actual_viewport_aspect": visible_size.x / visible_size.y, "mask_texture_aspect": float(hull_mask.get_width()) / float(hull_mask.get_height()) if hull_mask != null else 0.0}
	if hull_mask != null and hull_max > 2.0 / 255.0:
		var mask_directory: String = directory.path_join("hull-mask-debug")
		DirAccess.make_dir_recursive_absolute(mask_directory)
		var mask_path: String = mask_directory.path_join(label + ".png")
		check(hull_mask.save_png(mask_path) == OK, "failed hull mask evidence saved: " + label)
		record["failed_hull_mask"] = mask_path
	record["aabb_background_samples"] = aabb_background_samples
	record["aabb_background_changed"] = aabb_background_changed
	record["aabb_background_sharp_energy"] = aabb_background_sharp_energy
	record["aabb_background_blurred_energy"] = aabb_background_blurred_energy
	record["aabb_background_sharpness_ratio"] = aabb_background_blurred_energy / maxf(aabb_background_sharp_energy, 0.000001)
	if fx.config.has("warp_fx_reference_height_px"):
		var render_scale: float = float(sharp.get_height()) / float(fx.config.warp_fx_reference_height_px)
		record["effective_radius_px"] = float(fx.config.warp_fx_blur_radius_px) * render_scale
		record["effective_lod"] = maxf(0.0, float(fx.config.warp_fx_blur_lod) + log(render_scale) / log(2.0))
		record["effect_density_source"] = "shader-SCREEN_PIXEL_SIZE-actual-image-height-reference-height-no-ViewportTexture-metadata"
	observations.append(record)
	if require_blur:
		check(scenery_samples > 1000 and changed > 40 and sharp_energy > 0.05 and ratio < 0.88, "natural starfield/celestial pixels lose detail under actual transit blur: " + label)
		check(hull_samples == 0 if host.camera.mode == T.CameraMode.FRONT else hull_samples > 0 and hull_max <= 2.0 / 255.0, "actual hull protected sharp pixels: " + label)
		check(glyph_samples >= 8 and preserved_glyphs >= int(float(glyph_samples) * 0.98) and bool(glyph_witness.actual_label_restored), "real foreground HUD glyphs remain sharp: " + label)
		if glyph_samples < 8 or preserved_glyphs < int(float(glyph_samples) * 0.98):
			var debug_directory: String = directory.path_join("hud-mask-debug")
			DirAccess.make_dir_recursive_absolute(debug_directory)
			glyph_alpha.save_png(debug_directory.path_join(label + "-alpha.png"))
		if host.camera.mode != T.CameraMode.FRONT:
			check(aabb_background_samples > 0 and aabb_background_changed > 0, "sky inside old hull AABB receives blur instead of a clear rectangular patch: " + label)
		if label == "sky-close-follow":
			check(aabb_background_samples > 50 and aabb_background_changed > 10 and aabb_background_blurred_energy < aabb_background_sharp_energy * 0.88, "close external ship has a sharp silhouette within fully blurred surrounding sky")
	else: print("BASELINE_PIXEL_OBSERVATION " + JSON.stringify(record))

func mask_coverage_range(mask: Image, point: Vector2i, client_size: Vector2i) -> Vector2:
	# Normalized UVs match the production shader's half-resolution sampler.
	# Erode two mask texels using the COMPLETE neighborhood. Skipping +/-1
	# mistook narrow holes/anti-aliased boundaries for fully opaque interior.
	var uv := (Vector2(point) + Vector2(0.5, 0.5)) / Vector2(client_size)
	var center := Vector2i(Vector2(mask.get_size()) * uv)
	var lowest: float = 1.0
	var highest: float = 0.0
	for y: int in range(-2, 3):
		for x: int in range(-2, 3):
			var coordinate := Vector2i(clampi(center.x + x, 0, mask.get_width() - 1), clampi(center.y + y, 0, mask.get_height() - 1))
			var value: float = mask.get_pixelv(coordinate).r
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
	return Vector2(lowest, highest)

func mask_sample_evidence(mask: Image, point: Vector2i, client_size: Vector2i) -> Dictionary:
	var uv: Vector2 = (Vector2(point) + Vector2(0.5, 0.5)) / Vector2(client_size)
	var center: Vector2i = Vector2i(Vector2(mask.get_size()) * uv)
	var values: Array[float] = []
	var minimum: float = 1.0
	for y: int in range(-2, 3):
		for x: int in range(-2, 3):
			var coordinate := Vector2i(clampi(center.x + x, 0, mask.get_width() - 1), clampi(center.y + y, 0, mask.get_height() - 1))
			var value: float = mask.get_pixelv(coordinate).r
			values.append(value); minimum = minf(minimum, value)
	# Standard normalized linear sampling addresses texel centers at index+.5.
	var texel: Vector2 = Vector2(mask.get_size()) * uv - Vector2(0.5, 0.5)
	var origin := Vector2i(floori(texel.x), floori(texel.y))
	var weight: Vector2 = texel - Vector2(origin)
	var bilinear: float = 0.0
	for y: int in range(2):
		for x: int in range(2):
			var coordinate := Vector2i(clampi(origin.x + x, 0, mask.get_width() - 1), clampi(origin.y + y, 0, mask.get_height() - 1))
			bilinear += mask.get_pixelv(coordinate).r * (weight.x if x == 1 else 1.0 - weight.x) * (weight.y if y == 1 else 1.0 - weight.y)
	return {"mask_center": [center.x, center.y], "dense_minimum": minimum, "dense_5x5_row_major": values, "shader_bilinear_coverage": bilinear, "client_uv": [uv.x, uv.y]}

func projection_values(value: Projection) -> Array[float]:
	var result: Array[float] = []
	for index: int in range(4):
		var column: Vector4 = value[index]
		result.append_array([column.x, column.y, column.z, column.w])
	return result

func transform_values(transform: Transform2D) -> Array:
	return [transform.x.x, transform.x.y, transform.y.x, transform.y.y, transform.origin.x, transform.origin.y]

func capture_unsaved() -> Image:
	await frames(4)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func actual_label_compositing(source: Label, sharp: Image, blurred: Image, fx: XJWarpVisual) -> Dictionary:
	# An anti-aliased text pixel is F*a+B*(1-a). Its final RGB may change when
	# B is blurred, even though F and the glyph coverage remain unchanged. Obtain
	# the exact backgrounds by suppressing only this Label's draw alpha, keeping
	# its real layout/font and every other production scene/HUD node untouched.
	# This temporary presentation-only fixture is restored before returning.
	var prior_modulate: Color = source.self_modulate
	var prior_size: Vector2 = source.size
	var prior_transform: Transform2D = source.get_global_transform_with_canvas()
	var effect: float = float(fx._material.get_shader_parameter("effect_strength"))
	source.self_modulate = Color(prior_modulate.r, prior_modulate.g, prior_modulate.b, 0.0)
	fx._material.set_shader_parameter("effect_strength", 0.0)
	var background_sharp: Image = await capture_unsaved()
	fx._material.set_shader_parameter("effect_strength", effect)
	var background_blurred: Image = await capture_unsaved()
	source.self_modulate = prior_modulate
	await frames(3)
	var samples: int = 0
	var preserved: int = 0
	var fit_rejected: int = 0
	var max_error: float = 0.0
	var max_alpha: float = 0.0
	var opaque_mask_samples: int = 0
	var actual_contrast_samples: int = 0
	var effective_alpha_image: Image = Image.create(sharp.get_width(), sharp.get_height(), false, Image.FORMAT_RGBA8)
	var foreground: Color = source.get_theme_color("font_color") * source.modulate * prior_modulate
	var rectangle: Rect2i = pixel_rect(source, sharp.get_size())
	if positive_rect(rectangle):
		for y: int in range(rectangle.position.y, rectangle.end.y):
			for x: int in range(rectangle.position.x, rectangle.end.x):
				var point := Vector2i(x, y)
				var before: Color = sharp.get_pixelv(point)
				var base_before: Color = background_sharp.get_pixelv(point)
				var residual := Vector3(before.r - base_before.r, before.g - base_before.g, before.b - base_before.b)
				# Contrast comes from the actual Label draw, not another viewport's
				# font rasterization, which can use different canvas oversampling.
				if maxf(absf(residual.x), maxf(absf(residual.y), absf(residual.z))) < 0.03: continue
				actual_contrast_samples += 1
				var target := Vector3(foreground.r - base_before.r, foreground.g - base_before.g, foreground.b - base_before.b)
				var alpha_value: float = clampf(residual.dot(target) / maxf(target.length_squared(), 0.000001), 0.0, 1.0)
				max_alpha = maxf(max_alpha, alpha_value)
				if alpha_value >= 0.995: opaque_mask_samples += 1
				effective_alpha_image.set_pixelv(point, Color(1.0, 1.0, 1.0, alpha_value))
				if alpha_value < 0.60: continue
				var predicted_before: Color = base_before.lerp(foreground, alpha_value)
				if channel_difference(predicted_before, before) > 1.0 / 255.0:
					fit_rejected += 1
					continue
				samples += 1
				var predicted_after: Color = background_blurred.get_pixelv(point).lerp(foreground, alpha_value)
				var error: float = channel_difference(predicted_after, blurred.get_pixelv(point))
				max_error = maxf(max_error, error)
				if error <= 1.0 / 255.0: preserved += 1
	var used: Rect2i = effective_alpha_image.get_used_rect()
	var pixel_transform: Transform2D = root.get_final_transform() * source.get_global_transform_with_canvas()
	label_alpha_geometry = {"source_text": source.text, "source_font_size": source.get_theme_font_size("font_size"), "source_size": [source.size.x, source.size.y], "source_global_transform": transform_values(source.get_global_transform()), "source_canvas_transform": transform_values(source.get_canvas_transform()), "source_with_canvas_transform": transform_values(source.get_global_transform_with_canvas()), "window_final_transform": transform_values(root.get_final_transform()), "pixel_transform": transform_values(pixel_transform), "used_rect": [used.position.x, used.position.y, used.size.x, used.size.y], "coverage_source": "actual-real-label-draw-minus-the-same-renderer-background-with-only-label-alpha-zero"}
	return {"coverage_image": effective_alpha_image, "samples": samples, "preserved": preserved, "fit_rejected": fit_rejected, "max_prediction_error": max_error, "actual_coverage_max_alpha": max_alpha, "actual_opaque_samples": opaque_mask_samples, "actual_contrast_samples": actual_contrast_samples, "actual_label_restored": source.self_modulate == prior_modulate and source.size == prior_size and source.get_global_transform_with_canvas().is_equal_approx(prior_transform), "method": "C=F*a+B*(1-a)-same-real-label-with-only-self-modulate-alpha-suppressed-for-background-pair-no-auxiliary-font-renderer", "alpha_minimum_for_foreground_stem": 0.60, "actual_draw_contrast_minimum": 0.03, "prediction_error_limit": 1.0 / 255.0}

func glyph_helper_checks() -> void:
	if not check(DisplayServer.get_name() != "headless", "glyph helper diagnosis requires a native renderer"): return
	for physical_size: Vector2i in [Vector2i(1280, 720), Vector2i(3440, 1370)]:
		for scale_factor: float in [1.0, 2.0]:
			requested_window_size = physical_size
			root.size = physical_size
			root.content_scale_factor = scale_factor
			await frames(5)
			host._process(0.26)
			await frames(4)
			var label: String = "glyph-%dx%d-%d" % [physical_size.x, physical_size.y, int(scale_factor)]
			var actual: Image = await capture(label + "-actual")
			var witness: Dictionary = await actual_label_compositing(host.ui.top, actual, actual, host.warp_visual)
			var alpha: Image = witness.coverage_image
			witness.erase("coverage_image")
			check(alpha != null and alpha.get_size() == actual.get_size() and alpha.save_png(directory.path_join(label + "-alpha.png")) == OK, "actual foreground coverage screenshot " + label)
			captures += 1
			observations.append({"label": label, "actual_image_size": [actual.get_width(), actual.get_height()], "ui_scale": scale_factor, "geometry": label_alpha_geometry.duplicate(true), "witness": witness})
			check(int(witness.samples) >= 8 and int(witness.actual_contrast_samples) >= int(witness.samples) and bool(witness.actual_label_restored), "actual real label has at least eight measured stems and its draw/layout restores exactly: " + label)
			check(int(witness.preserved) >= int(float(witness.samples) * 0.98), "same real-label foreground reconstructs within one byte of colour: " + label)

func pixel_rect(control: Control, picture_size: Vector2i) -> Rect2i:
	var transform: Transform2D = root.get_final_transform() * control.get_global_transform_with_canvas()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for local: Vector2 in [Vector2.ZERO, Vector2(control.size.x, 0.0), Vector2(0.0, control.size.y), control.size]:
		var point: Vector2 = transform * local
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var rectangle := Rect2i(Vector2i(minimum.floor()), Vector2i((maximum.ceil() - minimum.floor())))
	return clip_positive_rect(rectangle, Rect2i(Vector2i.ZERO, picture_size))

func positive_rect(rectangle: Rect2i) -> bool:
	return rectangle.size.x > 0 and rectangle.size.y > 0

func clip_positive_rect(rectangle: Rect2i, bounds: Rect2i) -> Rect2i:
	if not positive_rect(rectangle) or not positive_rect(bounds): return Rect2i()
	var start: Vector2i = rectangle.position.max(bounds.position)
	var end: Vector2i = rectangle.end.min(bounds.end)
	if end.x <= start.x or end.y <= start.y: return Rect2i()
	return Rect2i(start, end - start)

func luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func channel_difference(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))

func interruption_and_arrival_checks() -> void:
	var source: String = formal_target("station")
	await place_near(source)
	var origin_site: String = Space.current_site(host.state)
	var start: Vector3 = host.world.flight.global_position
	var destination: String = formal_target("resource", origin_site)
	check(host._navigation_command("warp", destination), "target-loss scenario begins through production save command")
	await advance_to_travel()
	await advance(0.15)
	var removed: Dictionary = host.world.targets[destination]
	host.world.targets.erase(destination)
	host._physics_process(1.0 / 60.0)
	host.world.targets[destination] = removed
	host._process(1.0)
	check(host.local_navigation.phase == "failed" and not departure_active() and projection() == null and host.world.targets[source].node.is_visible_in_tree() and local_echo(source), "lost target restores original visual scene and local echoes")
	check(host.world.flight.global_position == start and Space.current_site(host.state) == origin_site and host.world.flight.velocity == Vector3.ZERO, "lost target cannot publish a false destination pose")
	# Explicit unlock grants permit the existing formal enemy model failure
	# injection. Neither catalog rows nor manufactured assets are substituted.
	for unlock: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.call("grant_unlock", unlock.unlock_id)
	host.gameplay.call("_sync_spawns")
	check(host.world.sync_entities(), "formal unlocked encounters synchronize in the departure fixture")
	var encounter: String = formal_target("encounter", origin_site)
	if check(not encounter.is_empty(), "formal remote encounter exists for visual-construction failure"):
		check(host._navigation_command("warp", encounter), "construction-failure route commits a genuine origin")
		await advance_to_travel()
		var original_factory: Script = host.world.factory
		host.world.factory = UnavailableEnemyFactory
		await complete_route()
		host.world.factory = original_factory
		check(host.world.sync_entities(), "formal factory restores after failure injection")
		host._process(1.0)
		check(host.local_navigation.phase == "failed" and not departure_active() and projection() == null and host.world.targets[source].node.is_visible_in_tree() and local_echo(source), "destination model failure removes projection and restores departure scene")
		check(host.world.flight.global_position == start and Space.current_site(host.state) == origin_site and host.world.strategic_render_position.is_empty(), "model failure restores exact durable origin pose/site")
	check(host._navigation_command("warp", destination), "successful arrival starts with the same real route")
	await advance_to_travel()
	await complete_route()
	await wait_stable()
	host._process(1.0)
	check(host.local_navigation.phase == "arrived" and host.world.target_is_local(destination) and host.world.targets[destination].node.is_visible_in_tree() and local_echo(destination), "real arrival reveals only destination geometry and local echoes")
	check(not host.world.targets[source].node.is_visible_in_tree() and not local_echo(source) and not departure_active() and projection() == null and not host.warp_visual.visible and is_zero_approx(host.camera._warp_fov_offset_deg), "arrival removes all old scene, blur, wake and temporary lens state")
	check(host.world.flight.global_position.distance_to(host.world.targets[destination].node.global_position) < 181.0 and host.world.flight.velocity == Vector3.ZERO, "safe arrival retains precise local stand-off position")
	var saved_pose: Vector3 = host.world.flight.global_position
	var saved_site: String = Space.current_site(host.state)
	check(host.store.save(host.state, "manual", 3), "stable destination saves to isolated SQLite")
	var slot_id: String = ""
	for slot: Dictionary in host.store.list_slots():
		if str(slot.slot_kind) == "manual" and int(slot.slot_index) == 3: slot_id = str(slot.slot_id)
	var restored: XJRuntimeState = host.store.load(slot_id)
	check(restored != null and Space.current_site(restored) == saved_site and Vector3(restored.ship().pos_x, restored.ship().pos_y, restored.ship().pos_z) == saved_pose, "SQL reopen contains genuine destination rather than a departing mesh offset")

func complete_route() -> void:
	for index: int in range(150):
		if host.local_navigation.phase not in ["travel", "arrival_check"]: break
		host._physics_process(0.5 if host.local_navigation.phase == "travel" else 1.0 / 60.0)
		host._process(0.016)
		await frames(2)
	await frames(5)

func capture(label: String) -> Image:
	await frames(4)
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if check(picture != null and not picture.is_empty() and picture.save_png(directory.path_join(label + ".png")) == OK, "native full-client screenshot " + label): captures += 1
	return picture

func finish() -> void:
	if finishing: return
	finishing = true
	var result: String = "DIAGNOSTIC_ONLY" if glyph_helper_only and failures.is_empty() else "EXPECTED_DEFECT" if baseline and failures.is_empty() else "PASS" if failures.is_empty() else "FAIL"
	var summary: Dictionary = {"result": result, "checks": checks, "captures": captures, "failures": failures.size(), "failure_labels": failures, "directory": directory, "native": DisplayServer.get_name() != "headless", "baseline": baseline, "scope": "true-main-saved-warp-three-formal-departure-bodies-natural-sky-planet-and-hull-HUD-pixels-camera-scale-pause-zero-intensity-cancel-loss-model-failure-arrival-SQL", "fixture": "explicit-formal-site-nearby-pose-camera-and-model-failure-unlock-grants-no-catalog-numeric-edits-no-personal-save", "observations": observations}
	if glyph_helper_only:
		summary["scope"] = "diagnostic-only-native-real-label-alpha-mapping-and-foreground-compositing-four-client-size-scale-combinations"
	if not directory.is_empty() and DirAccess.dir_exists_absolute(directory):
		var output: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
		if output != null: output.store_string(JSON.stringify(summary, "\t") + "\n"); output.close()
	print("WARP_SCENE_V21_FINAL_JSON " + JSON.stringify(summary))
	print("WARP_SCENE_V21_RESULT %s checks=%d captures=%d failures=%d" % [result, checks, captures, failures.size()])
	if is_instance_valid(host):
		host.set_process(false); host.set_physics_process(false)
		if host.gameplay != null: host.gameplay.call("dispose")
		if host.store != null: host.store.close()
		host.queue_free()
	host = null
	await frames(5)
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
