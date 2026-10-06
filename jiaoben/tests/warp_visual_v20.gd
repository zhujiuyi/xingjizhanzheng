extends Node
## Real Main and hull, isolated SQLite. A temporary 3D checker plane and a
## foreground HUD swatch provide measurable blur/mask evidence, not gameplay.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
const State = preload("res://runtime/state.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Catalog = preload("res://runtime/data/catalog.gd")
const Space = preload("res://runtime/space_coordinates.gd")
var host: Main
var directory: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var measurements: Array[Dictionary] = []
var finishing: bool = false
@onready var root: Window = get_tree().root
@onready var process_frame: Signal = get_tree().process_frame

func _ready() -> void:
	get_tree().set_meta("xj_warp_visual_v20_diagnostic", true)
	get_tree().create_timer(180.0).timeout.connect(func(): check(false, "watchdog"); finish())
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func _run() -> void:
	var script_path: String = OS.get_environment("XJ_WARP_VISUAL_V20_SCRIPT").replace("\\", "/")
	var prefix: String = script_path.get_base_dir().get_base_dir().path_join("tmp/warp-visual-v20") if not script_path.is_empty() else ProjectSettings.globalize_path("res://../jiaoben/tmp/warp-visual-v20").replace("\\", "/")
	directory = OS.get_environment("XJ_WARP_VISUAL_V20_DIRECTORY").replace("\\", "/")
	if directory.is_empty():
		var token: String = Crypto.new().generate_random_bytes(16).hex_encode()
		directory = prefix.path_join("%s-%s-%s-%s-%s" % [token.substr(0, 8), token.substr(8, 4), token.substr(12, 4), token.substr(16, 4), token.substr(20, 12)])
	if not check(directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == prefix and directory.get_file().length() == 36, "fresh UUID output remains inside tmp scope"): await finish(); return
	DirAccess.make_dir_recursive_absolute(directory)
	if not check(not FileAccess.file_exists(directory.path_join("progress.db")), "pre-existing progress database is refused"): await finish(); return
	root.size = Vector2i(1440, 900)
	root.content_scale_factor = 1.0
	host = Main.new()
	host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host)
	host.set_process(false)
	host.set_physics_process(false)
	await frames(4)
	if not check(host.services_ready, "actual Main opens production catalog with isolated SQLite"): await finish(); return
	await host._command("new_world", "跃迁环境表现独立验收", 1, "")
	if not check(host.state != null, "production new-world endpoint succeeds"): await finish(); return
	await hangar_space_checks()
	host._command("undock", "", 1, "")
	var deadline: int = Time.get_ticks_msec() + 8000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	if not check(not host.busy and host.state.ship().status == T.ShipStatus.FLYING, "production undock reaches stable flight"): await finish(); return
	host.ui.show_page("")
	host._sync_presentation_stage()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.camera.step(1.0)
	host.ui.tick(0.0)
	var fx: XJWarpVisual = host.warp_visual
	if not check(fx.configured and fx._rig == host.camera and fx._scene == host.world, "Main binds warp presentation to real scene/camera and SQLite parameters"): await finish(); return
	var encoded_before: String = state_text()
	var pose_before: Transform3D = host.world.flight.global_transform
	var velocity_before: Vector3 = host.world.flight.velocity
	var snapshots_before: int = int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	var fov_base: float = host.camera.camera.fov
	var heading := Vector3(0.33, 0.17, -1.0).normalized()
	var params: Dictionary = fx.config.duplicate(true)
	await navigation_ui_checks()
	fx.update_navigation("warmup", float(params.warp_fx_fade_in_s) * 0.5, 1.0, false)
	host.camera.step(0.0)
	fx.update_pose(heading)
	check(fx.visible and fx.envelope > 0.0 and fx.envelope < float(params.warp_fx_warmup_strength), "warmup fades toward a restrained charge envelope")
	fx.update_navigation("warmup", float(params.warp_fx_fade_in_s), 1.0, false)
	check(is_equal_approx(fx.envelope, float(params.warp_fx_warmup_strength)), "warmup strength comes from database")
	var charge_envelope: float = fx.envelope
	fx.update_navigation("travel", 0.0, 1.0, false)
	check(is_equal_approx(fx.envelope, charge_envelope), "warmup-to-travel transition retains its visible envelope")
	fx.update_navigation("travel", float(params.warp_fx_fade_in_s), 1.0, false)
	host.camera.step(0.0)
	fx.update_pose(heading)
	check(is_equal_approx(fx.envelope, 1.0) and fx.stream.is_visible_in_tree() and fx._mesh.get_surface_count() == 1, "travel reaches the full bounded stream and blur state")
	check(is_equal_approx(host.camera.camera.fov, fov_base + float(params.warp_fx_fov_add_deg)), "camera applies a reversible database-defined lens offset")
	check(fx.stream.global_basis.z.dot(-heading) > 0.99999 and fx.stream.global_position.is_equal_approx(host.camera.render_position()), "three-dimensional flow follows actual world heading and same-frame rendered ship")
	check(fx.stream.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and fx.stream.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual stream adds no shadows or collision authority")
	check(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE and fx._blur.mouse_filter == Control.MOUSE_FILTER_IGNORE, "environment overlay cannot consume flight or HUD input")
	check(fx.ship_rect.has_area() and bool(fx._material.get_shader_parameter("protect_ship")), "visible external hull receives a conservative projected protection rectangle")
	for index: int in range(8):
		var projected: Vector2 = host.camera.camera.unproject_position(host.camera.render_ship_transform() * fx._hull_bounds.get_endpoint(index)) / host.camera.camera.get_viewport().get_visible_rect().size
		check(fx.ship_rect.grow(0.00001).has_point(projected), "hull mask covers visual bounds corner %d" % index)
	var paused_clock: float = fx.elapsed
	var paused_envelope: float = fx.envelope
	var paused_bounds: AABB = fx._mesh.get_aabb()
	fx.update_navigation("travel", 8.0, 1.0, true)
	fx.update_pose(heading)
	check(fx.elapsed == paused_clock and fx.envelope == paused_envelope and fx._mesh.get_aabb().is_equal_approx(paused_bounds), "pause freezes both envelope and stream phase")
	var orbit_before: Vector2 = host.camera.orbit
	host.camera.observe(Vector2(55, 12), 0.006)
	host.camera.step(1.0)
	fx.update_pose(heading)
	check(host.camera.orbit != orbit_before and fx.stream.global_basis.z.dot(-heading) > 0.99999, "free observation changes projection while world-direction flow stays behind the ship")
	host.camera.reset_observation()
	host.camera.step(1.0)
	fx.update_pose(heading)
	if DisplayServer.get_name() != "headless":
		await capture("warp-natural")
		await native_pixels(fx, heading)
	fx.update_navigation("travel", 0.0, 0.0, false)
	check(not fx.visible and not fx.stream.visible and fx._mesh.get_surface_count() == 0 and is_equal_approx(host.camera.camera.fov, fov_base), "intensity zero removes blur, geometry and lens offset immediately")
	fx.update_navigation("travel", 0.0, 1.0, false)
	host.camera.step(0.0)
	fx.update_pose(heading)
	fx.update_navigation("cancelled", float(params.warp_fx_fade_out_s) * 0.25, 1.0, false)
	check(fx.visible and fx.envelope > 0.0 and fx.envelope < 1.0, "cancellation smoothly fades existing presentation")
	fx.update_navigation("idle", float(params.warp_fx_fade_out_s), 1.0, false)
	check(not fx.visible and not fx.stream.visible and fx.envelope == 0.0 and is_equal_approx(host.camera.camera.fov, fov_base), "completed exit restores original camera and no visible effects")
	check(state_text() == encoded_before and host.world.flight.global_transform.is_equal_approx(pose_before) and host.world.flight.velocity == velocity_before and int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == snapshots_before, "visual phases and observation do not mutate any typed progress, flight pose, velocity or committed snapshot")
	fx.update_navigation("travel", float(params.warp_fx_fade_in_s), 1.0, false)
	fx.update_pose(heading)
	fx.unbind()
	check(not fx.configured and not fx.visible and fx.stream == null and is_equal_approx(host.camera.camera.fov, fov_base), "unbind clears scene geometry and restores FOV without another frame")
	var invalid: Dictionary = params.duplicate(true)
	invalid.erase("warp_fx_blur_radius_px")
	check(not fx.bind(host.world, host.camera, invalid) and not fx.last_error.is_empty() and not fx.configured, "missing database parameter disables effects with an explicit error and no fallback")
	check(fx.bind(host.world, host.camera, params), "valid formal parameters rebind after teardown")
	await finish()

func hangar_space_checks() -> void:
	var hangar: XJStationHangar = host.hangar
	var before: String = state_text()
	var station_id: String = host.state.ship().station_id
	var station: Dictionary = host.store.catalog.one("station_defs", "station_id", station_id)
	var anchor: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", str(station.station_anchor_id))
	var context: Dictionary = hangar.get_space_context()
	if not check(not context.is_empty() and str(context.station_id) == station_id and str(context.content_hash) == host.store.catalog.content_hash,
		"actual Main station stage binds the current frozen catalog and docked station to its pane"): return
	var material: ShaderMaterial = hangar.get_space_window_material()
	if not check(material != null and material.shader.resource_path == "res://runtime/ui/window_space_strategic.gdshader", "spatial station uses the independent real-direction window shader"): return
	var planet: Dictionary = host.store.catalog.one("celestial_defs", "celestial_id", str(context.planet_id))
	var star: Dictionary = host.store.catalog.one("celestial_defs", "celestial_id", str(context.star_id))
	var origin: Dictionary = Space.anchor_components(host.store.catalog, anchor)
	var p: Dictionary = {"x": float(planet.x_m), "y": float(planet.y_m), "z": float(planet.z_m)}
	var s: Dictionary = {"x": float(star.x_m), "y": float(star.y_m), "z": float(star.z_m)}
	check((material.get_shader_parameter("planet_direction") as Vector3).is_equal_approx(Space.scalar_direction(origin, p))
		and (material.get_shader_parameter("star_direction") as Vector3).is_equal_approx(Space.scalar_direction(origin, s)), "pane planet and star uniforms are real normalized catalog bearings")
	check(is_equal_approx(float(material.get_shader_parameter("planet_sin_radius")), float(planet.radius_m) / Space.scalar_distance(origin, p))
		and is_equal_approx(float(material.get_shader_parameter("star_sin_radius")), float(star.radius_m) / Space.scalar_distance(origin, s)), "pane angular disks use physical celestial radius divided by true station distance")
	check((material.get_shader_parameter("planet_light_direction") as Vector3).is_equal_approx(Space.scalar_direction(p, s)), "planet phase uses its own real stellar illumination direction")
	var stage_frame: Basis = material.get_shader_parameter("stage_to_sector")
	check(stage_frame.is_equal_approx(Basis(Vector3.UP, float(anchor.yaw_rad)) * hangar.global_basis.orthonormalized().inverse()), "pane rays map exhibition room orientation through the actual station yaw")
	check(hangar.set_space_context(host.store.catalog, station_id) and hangar.get_space_window_material() == material, "same frozen hash and station reuse the existing cached material")
	var key: DirectionalLight3D = hangar.get_node("ExhibitionKey")
	var light_pose: Transform3D = key.global_transform
	var window: MeshInstance3D = hangar.get_node("StarViewport")
	var indoor_camera: Camera3D = hangar.get_camera()
	var camera_pose: Transform3D = indoor_camera.global_transform
	var ray_before: Vector3 = stage_frame * indoor_camera.global_position.direction_to(window.global_position)
	indoor_camera.global_position += Vector3(8, 0, 0)
	var ray_after: Vector3 = stage_frame * indoor_camera.global_position.direction_to(window.global_position)
	check(ray_before.angle_to(ray_after) > 0.01 and hangar.get_space_context() == context, "moving the real indoor camera changes the pane ray while celestial context remains fixed")
	indoor_camera.global_transform = camera_pose
	var preview_station: Dictionary = host.store.catalog.one("station_defs", "sector_id", "sector_helios")
	check(hangar.set_space_context(host.store.catalog, str(preview_station.station_id)) and str(hangar.get_space_context().sector_id) == "sector_helios"
		and not (hangar.get_space_window_material().get_shader_parameter("planet_direction") as Vector3).is_equal_approx(context.planet_direction), "station-only preview adopts another system's real planet bearing without a fake gameplay trip")
	if DisplayServer.get_name() != "headless": await capture("hangar-helios-real-window-preview")
	var legacy_view: Catalog = Catalog.new()
	check(hangar.set_space_context(legacy_view, station_id) and hangar.get_space_window_material() == null
		and (window.material_override as ShaderMaterial).shader.resource_path == "res://assets/hangar_v2/window_space.gdshader", "unsupported legacy presentation restores the original untouched pane material")
	legacy_view.close(); legacy_view = null
	check(hangar.set_space_context(host.store.catalog, station_id) and hangar.get_space_window_material() == material and key.global_transform.is_equal_approx(light_pose), "restoring current station keeps the same material and unchanged indoor exhibition lights")
	check(state_text() == before, "all station window previews leave every typed progress and pose field unchanged")

func navigation_ui_checks() -> void:
	var nav: XJNavigationHUD = host.ui.navigation_hud
	var remote_id: String = ""
	var planet_id: String = ""
	for id: String in host.world.targets:
		var entry: Dictionary = host.world.targets[id]
		if bool(entry.get("navigation_only", false)): planet_id = id
		elif str(entry.kind) in ["station", "gate", "resource", "signal", "marker", "encounter"] and not host.world.target_is_local(id): remote_id = id
	check(XJSpaceUnits.distance(XJSpaceUnits.METRES_PER_AU) == "1.00 AU" and XJSpaceUnits.distance(150000.0) == "150 km" and XJSpaceUnits.distance(600.0) == "600 m", "distance labels represent AU, kilometre and metre scales without redefining units")
	if not check(not remote_id.is_empty() and not planet_id.is_empty(), "formal strategic world has a remote known destination and a celestial"): return
	var remote: Dictionary = host.world.targets[remote_id]
	var distance: float = host.world.target_distance(remote_id)
	var direction: Vector3 = host.world.target_direction(remote_id)
	check(not remote.node.visible and distance > nav.sensor_limit and XJSpaceUnits.distance(distance).contains("AU"), "hidden remote local encoding is distinct from its true AU distance")
	var old_scale: int = nav.scale_index
	nav.scale_index = 0
	nav.refresh()
	var contact: Dictionary = {}
	for row: Dictionary in nav.contacts:
		if str(row.id) == remote_id: contact = row
	if check(not contact.is_empty() and bool(contact.bearing), "remote known destination is a bearing rather than a local sensor echo"):
		check(is_equal_approx(float(contact.distance_m), distance) and contact.relative.is_equal_approx(host.camera.render_ship_transform().basis.inverse() * direction), "radar uses true strategic distance and a bounded relative unit direction")
		var canvas := Vector2(200, 186)
		check(is_equal_approx(nav.radar_point(contact, canvas).distance_to(canvas * Vector2(0.5, 0.47)), minf(canvas.x * 0.42, canvas.y * 0.39)), "remote bearing remains on radar perimeter at the smallest local range")
	var old_basis: Basis = host.camera.observation_basis
	var old_orbit: Vector2 = host.camera.orbit
	host.camera.observation_basis = Basis.looking_at(direction, Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
	host.camera.orbit = Vector2.ZERO
	host.camera.snapped = false
	host.camera.step(1.0)
	host.ui._select_target(remote_id)
	nav.selected_id = remote_id
	nav.update_annotations()
	var geometry: Dictionary = nav.target_geometry()
	var expected: Vector3 = host.camera.camera.global_position + direction * host.camera.camera.far * 0.7
	check(not geometry.is_empty() and bool(geometry.on_screen) and geometry.end.distance_to(host.camera.camera.unproject_position(expected)) < 0.1, "selected remote marker projects true direction within the camera far plane")
	check(is_equal_approx(float(host.ui._selected_details().distance_m), distance) and host.ui.overview.selected_distance.text.contains(XJSpaceUnits.distance(distance)), "overview selected details display true destination AU distance")
	if DisplayServer.get_name() != "headless": await capture("navigation-strategic")
	host.ui._select_target(planet_id)
	nav.selected_id = planet_id
	nav.update_annotations()
	var planet_distance: float = host.world.target_distance(planet_id)
	check(bool(host.ui._selected_details().navigation_only) and host.ui.overview.selected_distance.text.contains(XJSpaceUnits.distance(planet_distance)) and nav.selection_label.text.contains(XJSpaceUnits.distance(planet_distance)), "celestial retains bearing-only eligibility while both selected readouts show its real distance")
	nav.scale_index = old_scale
	host.camera.observation_basis = old_basis
	host.camera.orbit = old_orbit
	host.camera.snapped = false
	host.camera.step(1.0)
	host.ui._select_target("")
	nav.selected_id = ""
	nav.refresh()

func state_text() -> String:
	var rows: Dictionary = {}
	var codec: Codec = Codec.new()
	for table: String in State.TABLES:
		rows[table] = []
		for row: RefCounted in host.state.rows(table): rows[table].append(codec.encode_row(table, row))
	return JSON.stringify(rows)

func capture(label: String) -> Image:
	await frames(3)
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if check(picture != null and not picture.is_empty() and picture.save_png(directory.path_join(label + ".png")) == OK, "native capture " + label): captures += 1
	return picture

func native_pixels(fx: XJWarpVisual, heading: Vector3) -> void:
	# High-frequency 3D geometry provides a deterministic environment target.
	# The official hull and HUD stay on the real renderer in the same image.
	var plane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var distance: float = host.camera.camera.global_position.distance_to(host.world.flight.global_position) * 4.0
	quad.size = Vector2(distance * 3.0, distance * 2.0)
	plane.mesh = quad
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, fog_disabled; void fragment() { float stripe = mod(floor(UV.x * 240.0) + floor(UV.y * 160.0), 2.0); ALBEDO = mix(vec3(0.015, 0.025, 0.04), vec3(0.16, 0.21, 0.25), stripe); }"
	material.shader = shader
	plane.material_override = material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.world.add_child(plane)
	plane.global_transform = Transform3D(host.camera.camera.global_basis, host.camera.camera.global_position - host.camera.camera.global_basis.z * distance)
	var foreground := CanvasLayer.new()
	foreground.layer = 2
	root.add_child(foreground)
	var swatch := ColorRect.new()
	swatch.position = Vector2(12, 12)
	swatch.size = Vector2(240, 70)
	swatch.color = Color(0.03, 0.05, 0.07)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foreground.add_child(swatch)
	var label := Label.new()
	label.text = "跃迁 HUD · 0123456789"
	label.theme = host.ui.theme
	label.position = Vector2(18, 25)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foreground.add_child(label)
	fx.update_navigation("travel", 0.0, 1.0, true)
	fx.update_pose(heading)
	fx.stream.hide()
	fx._blur.hide()
	var sharp: Image = await capture("warp-grid-sharp")
	fx._blur.show()
	var blurred: Image = await capture("warp-grid-blurred")
	if sharp == null or blurred == null: plane.free(); foreground.free(); return
	var hull: Rect2i = Rect2i(Vector2i(fx.ship_rect.position * Vector2(sharp.get_size())), Vector2i(fx.ship_rect.size * Vector2(sharp.get_size()))).intersection(Rect2i(Vector2i.ZERO, sharp.get_size()))
	var hud: Rect2i = Rect2i(12, 12, 240, 70)
	var changed: int = 0
	var outside_samples: int = 0
	var hull_max: float = 0.0
	var hud_max: float = 0.0
	for y: int in range(0, sharp.get_height(), 3):
		for x: int in range(0, sharp.get_width(), 3):
			var point := Vector2i(x, y)
			var before: Color = sharp.get_pixelv(point)
			var after: Color = blurred.get_pixelv(point)
			var difference: float = maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))
			if hud.has_point(point): hud_max = maxf(hud_max, difference)
			elif hull.grow(-2).has_point(point): hull_max = maxf(hull_max, difference)
			else:
				outside_samples += 1
				if difference > 0.025: changed += 1
	check(changed > 100 and outside_samples > 1000, "actual shader measurably blurs high-frequency 3D scenery")
	check(hull.has_area() and hull_max <= 1.0 / 255.0, "protected hull-region pixels retain original sharp rendering")
	check(hud_max <= 1.0 / 255.0, "foreground HUD glyphs retain original sharp pixels")
	measurements.append({"changed_scenery_samples": changed, "scenery_samples": outside_samples, "hull_max_channel_difference": hull_max, "hud_max_channel_difference": hud_max, "fixture": "real-main-hull-plus-temporary-3d-checker-plane-and-foreground-HUD-swatch"})
	plane.free()
	foreground.free()
	fx.stream.show()

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(4)
	await get_tree().create_timer(0.25).timeout
	var result: String = "PASS" if failures.is_empty() else "FAIL"
	var summary: Dictionary = {"result": result, "checks": checks, "captures": captures, "failures": failures.size(), "failure_labels": failures, "directory": directory, "measurements": measurements, "native": DisplayServer.get_name() != "headless", "scope": "read-only-presentation-phases-real-main-scoped-sqlite-native-pixels-when-native"}
	if not directory.is_empty() and DirAccess.dir_exists_absolute(directory):
		var output: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
		if output != null: output.store_string(JSON.stringify(summary, "\t") + "\n"); output.close()
	print("WARP_VISUAL_V20_FINAL_JSON " + JSON.stringify(summary))
	print("WARP_VISUAL_V20_RESULT %s checks=%d captures=%d failures=%d" % [result, checks, captures, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
