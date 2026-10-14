extends Node
## Native source/release paired visual evidence. Stages use real production assets.
## Fixed poses/lights and seed 71 are declared art fixtures, not gameplay travel.
const Main = preload("res://runtime/main.gd")
const ProductionFactory = preload("res://runtime/visuals/civilization_visual_factory.gd")
const ProductionSurface = preload("res://runtime/surface_style.gd")
const StationVisual = preload("res://runtime/visuals/station_visual_adapter.gd")
const ProductionEffects = preload("res://runtime/visuals/visual_effects.gd")
const Codec = preload("res://runtime/data/codec.gd")
const SEED: int = 71
var host: Node
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var key: DirectionalLight3D
var fill: DirectionalLight3D
var environment: Environment
var preview: TextureRect
var directory: String
var label: String
var effects: Script = ProductionEffects
var material_adapter: Script
var ship_factory: Script = ProductionFactory
var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var captures: int = 0
var finishing: bool = false
var initial_state: String = ""
var baseline_cases: Dictionary = {}
var contracts: RefCounted
var root: Window:
	get: return get_tree().root

func _ready() -> void:
	get_tree().set_meta("xj_render_quality_v61_diagnostic", true)
	get_tree().create_timer(480.0).timeout.connect(func(): check(false, "native render watchdog"); finish())
	run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
	return ok

func frames(count: int = 8) -> void:
	for index: int in range(count): await get_tree().process_frame

func descendants(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children(): nodes.append_array(descendants(child))
	return nodes

func vec(value: Vector3) -> Array[float]: return [value.x, value.y, value.z]

func pose(value: Transform3D) -> Dictionary:
	return {"origin": vec(value.origin), "basis_x": vec(value.basis.x), "basis_y": vec(value.basis.y), "basis_z": vec(value.basis.z)}

func scalar(value: Variant) -> Variant:
	if value is Color: return {"color": value.to_html(true)}
	if value is Vector2: return [value.x, value.y]
	if value is Vector3: return vec(value)
	if value is Transform3D: return pose(value)
	if value is Texture2D:
		return {"class": value.get_class(), "path": value.resource_path, "size": [value.get_width(), value.get_height()]}
	if value is Resource: return {"class": value.get_class(), "path": value.resource_path, "name": value.resource_name}
	if value is Object: return {"class": value.get_class()}
	return value

func optional_meta(value: Object, key_name: String, fallback: Variant = null) -> Variant:
	# Godot treats get_meta(key, null) as "no default" and emits an error.
	return value.get_meta(key_name) if value.has_meta(key_name) else fallback

func state_signature() -> String:
	return state_signature_for(host.state)

func state_signature_for(runtime: XJRuntimeState) -> String:
	var state: Dictionary = {}
	var codec: RefCounted = Codec.new()
	for table: String in XJRuntimeState.TABLES:
		var rows: Array = []
		for row: RefCounted in runtime.rows(table): rows.append(codec.encode_row(table, row))
		rows.sort_custom(func(a: Dictionary, b: Dictionary): return JSON.stringify(a) < JSON.stringify(b))
		state[table] = rows
	return JSON.stringify(state).sha256_text()

func geometry_signature(model: Node) -> Dictionary:
	var result: Dictionary = {"collisions": [], "anchors": [], "meshes": []}
	for node: Node in descendants(model):
		var path: String = str(model.get_path_to(node))
		if node is CollisionObject3D: result.collisions.append({"path": path, "class": node.get_class(), "layer": node.collision_layer, "mask": node.collision_mask, "pose": pose(node.transform)})
		if node is CollisionShape3D:
			var shape: Shape3D = node.shape
			var data: Dictionary = {"path": path, "pose": pose(node.transform), "disabled": node.disabled, "class": shape.get_class() if shape != null else "none"}
			if shape != null:
				for property: Dictionary in shape.get_property_list():
					if str(property.name) in ["size", "radius", "height", "points", "margin", "backface_collision"]: data[str(property.name)] = scalar(shape.get(property.name))
			result.collisions.append(data)
		if node is Node3D and ("Hardpoints" in path or "FXAnchors" in path or str(node.name) in ["CameraTarget", "FrontCamera", "InteractionAnchor"]): result.anchors.append({"path": path, "pose": pose(node.transform)})
		if node is MeshInstance3D and node.mesh != null:
			var surfaces: Array[String] = []
			var triangles: int = 0
			var normals: int = 0
			for surface: int in range(node.mesh.get_surface_count()):
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				if not check(arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array, "real mesh surface exposes complete vertex arrays " + path): continue
				surfaces.append(var_to_bytes(arrays).hex_encode().sha256_text())
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				triangles += int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
				if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array: normals += arrays[Mesh.ARRAY_NORMAL].size()
			result.meshes.append({"path": path, "pose": pose(node.transform), "surfaces": surfaces, "triangles": triangles, "normal_count": normals, "aabb": [vec(node.get_aabb().position), vec(node.get_aabb().size)]})
	return result

func material_data(model: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in descendants(model):
		if not node is MeshInstance3D or node.mesh == null: continue
		for surface: int in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface)
			var row: Dictionary = {"node": str(model.get_path_to(node)), "surface": surface, "class": material.get_class() if material != null else "none", "cast_shadow": node.cast_shadow}
			if material != null:
				row.merge({"name": material.resource_name, "path": material.resource_path, "next_pass": material.next_pass != null})
				row["materials_version"] = str(optional_meta(material, "xj_materials_version", ""))
				row["surface_role"] = str(optional_meta(material, "surface_role", ""))
				row["source_material"] = scalar(optional_meta(material, "source_material"))
				if material is ShaderMaterial:
					row["shader"] = material.shader.resource_path
					row["shader_sha256"] = material.shader.code.sha256_text()
					var uniforms: Dictionary = {}
					for uniform: Dictionary in material.shader.get_shader_uniform_list(): uniforms[str(uniform.name)] = scalar(material.get_shader_parameter(uniform.name))
					row["uniforms"] = uniforms
				elif material is StandardMaterial3D:
					for field: String in ["albedo_color", "metallic", "roughness", "emission_enabled", "emission", "emission_energy_multiplier", "transparency", "shading_mode", "cull_mode", "albedo_texture", "normal_enabled", "normal_texture", "normal_scale"]: row[field] = scalar(material.get(field))
			result.append(row)
	return result

func bounds(model: Node3D) -> AABB:
	var merged := AABB()
	var found: bool = false
	var inverse: Transform3D = model.global_transform.affine_inverse()
	for node: Node in descendants(model):
		if node is MeshInstance3D and node.mesh != null:
			var box: AABB = inverse * node.global_transform * node.get_aabb()
			merged = merged.merge(box) if found else box
			found = true
	return merged

func fixed_camera(model: Node3D, view: String = "hero") -> void:
	var box: AABB = model.global_transform * bounds(model)
	var span: float = maxf(box.size.length(), 1.0)
	var center: Vector3 = box.get_center()
	var direction: Vector3 = Vector3(-0.7, 0.35, 1.0) if view == "rear" else Vector3(-0.9, 0.25, -0.6) if view == "port" else Vector3(0.78, 0.48, -0.92)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 38.0; camera.near = maxf(0.01, span * 0.0001); camera.far = span * 20.0
	camera.position = center + direction.normalized() * span * 1.6
	camera.look_at(center)
	camera.make_current()
	key.directional_shadow_max_distance = span * 5.0

func composition(active_camera: Camera3D, model: Node3D) -> Dictionary:
	var result: Dictionary = {"camera": pose(active_camera.global_transform), "projection": active_camera.projection, "fov": active_camera.fov, "orthogonal_size": active_camera.size, "near": active_camera.near, "far": active_camera.far, "model_pose": pose(model.global_transform), "key_pose": pose(key.global_transform), "key_energy": key.light_energy, "key_color": key.light_color.to_html(true), "key_shadows": key.shadow_enabled, "fill_pose": pose(fill.global_transform), "fill_energy": fill.light_energy, "fill_color": fill.light_color.to_html(true), "environment_ambient_color": environment.ambient_light_color.to_html(true), "environment_ambient_energy": environment.ambient_light_energy, "environment_background": environment.background_color.to_html(true), "tonemap": environment.tonemap_mode, "ssao": environment.ssao_enabled, "size": [root.size.x, root.size.y], "seed": SEED, "controlled_studio": active_camera == camera}
	if active_camera != camera:
		var lighting: Array[Dictionary] = []
		for node: Node in descendants(host.hangar):
			if node is Light3D: lighting.append({"path": str(host.hangar.get_path_to(node)), "class": node.get_class(), "pose": pose(node.global_transform), "color": node.light_color.to_html(true), "energy": node.light_energy, "shadows": node.shadow_enabled})
			if node is ReflectionProbe: lighting.append({"path": str(host.hangar.get_path_to(node)), "class": node.get_class(), "pose": pose(node.global_transform), "intensity": node.intensity, "size": vec(node.size), "ambient_color": node.ambient_color.to_html(true), "ambient_energy": node.ambient_color_energy, "interior": node.interior, "update_mode": node.update_mode, "cull_mask": node.cull_mask, "reflection_mask": node.reflection_mask, "layers": node.layers, "box_projection": node.box_projection, "visible": node.visible})
		result["actual_hangar_lights_and_probes"] = lighting
		var env: Environment = active_camera.environment
		if env != null:
			var data: Dictionary = {}
			for field: String in ["ambient_light_color", "ambient_light_energy", "ambient_light_source", "reflected_light_source", "tonemap_mode", "tonemap_exposure", "ssao_enabled", "ssr_enabled", "glow_enabled", "background_mode", "background_color"]: data[field] = scalar(env.get(field))
			result["actual_camera_environment"] = data
	else:
		var studio_sky: ProceduralSkyMaterial = environment.sky.sky_material
		result["studio_reflection"] = {"source": environment.reflected_light_source, "sky_top": studio_sky.sky_top_color.to_html(), "sky_horizon": studio_sky.sky_horizon_color.to_html(), "ground_bottom": studio_sky.ground_bottom_color.to_html(), "ground_horizon": studio_sky.ground_horizon_color.to_html()}
	return result

func capture(name: String, model: Node3D, kind: String, active_camera: Camera3D = null, details: Dictionary = {}) -> void:
	if label == "after" and active_camera == null and baseline_cases.has(name):
		var reference: Dictionary = baseline_cases[name].composition
		var location: Dictionary = reference.camera
		camera.transform = Transform3D(Basis(Vector3(location.basis_x[0], location.basis_x[1], location.basis_x[2]), Vector3(location.basis_y[0], location.basis_y[1], location.basis_y[2]), Vector3(location.basis_z[0], location.basis_z[1], location.basis_z[2])), Vector3(location.origin[0], location.origin[1], location.origin[2]))
		camera.projection = int(reference.projection); camera.fov = float(reference.fov); camera.size = float(reference.orthogonal_size); camera.near = float(reference.near); camera.far = float(reference.far)
		# Original studio uses far=span*20 and directional_shadow_max_distance=span*5.
		# Restore the same light's shadow range even when the new silhouette shrinks.
		key.directional_shadow_max_distance = float(reference.far) * 0.25
	var background: Image
	if kind == "effect":
		model.hide()
		await frames(3)
		await RenderingServer.frame_post_draw
		background = viewport.get_texture().get_image()
		model.show()
	await frames(10)
	await RenderingServer.frame_post_draw
	var image: Image = (viewport if active_camera == null else root).get_texture().get_image()
	var path: String = directory.path_join(name + ".png")
	check(not image.is_empty() and image.get_size() == Vector2i(1440, 900) and image.save_png(path) == OK, "native paired capture " + name)
	var current: Camera3D = camera if active_camera == null else active_camera
	if kind == "effect":
		var pixels: Dictionary = pixel_signal(image, background)
		details["native_visible_signal"] = pixels
		if label == "after": check(int(pixels.changed_samples) >= 8 and float(pixels.max_rgb_delta) > 0.02, "after FX contributes real non-background pixels " + name)
	observations.append({"case": name, "kind": kind, "screenshot": path, "composition": composition(current, model), "geometry": geometry_signature(model), "materials": material_data(model), "details": details, "renderer_counters": {"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "scope": "staged native snapshot counters; no gameplay FPS or GPU timing claim"}})
	captures += 1
	print("RENDER_QUALITY_AUDIT_CAPTURE ", name)

func pixel_signal(image: Image, background: Image) -> Dictionary:
	var changed: int = 0
	var maximum: float = 0.0
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i.ZERO
	if background == null or background.get_size() != image.get_size(): return {"changed_samples": 0, "max_rgb_delta": 0.0, "sample_stride": 2}
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var color: Color = image.get_pixel(x, y)
			var prior: Color = background.get_pixel(x, y)
			var delta: float = maxf(absf(color.r - prior.r), maxf(absf(color.g - prior.g), absf(color.b - prior.b)))
			maximum = maxf(maximum, delta)
			if delta > 0.02:
				changed += 1; low = low.min(Vector2i(x, y)); high = high.max(Vector2i(x, y))
	return {"changed_samples": changed, "estimated_visible_pixels": changed * 4, "max_rgb_delta": maximum, "sample_stride": 2, "bounds": [low.x, low.y, high.x - low.x + 1, high.y - low.y + 1] if changed > 0 else [0, 0, 0, 0], "method": "same native camera/framebuffer with only tested FX hidden versus visible"}

func build_stage() -> void:
	viewport = SubViewport.new(); viewport.size = Vector2i(1440, 900); viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	preview = TextureRect.new(); preview.texture = viewport.get_texture(); preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(preview)
	stage = Node3D.new(); viewport.add_child(stage)
	var world_environment := WorldEnvironment.new(); environment = Environment.new(); world_environment.environment = environment
	environment.background_mode = Environment.BG_COLOR; environment.background_color = Color("0a0d11")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color = Color("707a84"); environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC; environment.ssao_enabled = true
	# Fixed neutral studio IBL makes conductor reflections observable in both runs.
	var studio_sky := ProceduralSkyMaterial.new()
	studio_sky.sky_top_color = Color(0.16, 0.20, 0.27)
	studio_sky.sky_horizon_color = Color(0.90, 0.92, 0.96)
	studio_sky.ground_bottom_color = Color(0.045, 0.05, 0.06)
	studio_sky.ground_horizon_color = Color(0.55, 0.52, 0.48)
	environment.sky = Sky.new(); environment.sky.sky_material = studio_sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	stage.add_child(world_environment)
	key = DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35, -30, 0); key.light_energy = 2.0; key.light_color = Color(1.0, 0.96, 0.89); key.shadow_enabled = true; stage.add_child(key)
	fill = DirectionalLight3D.new(); fill.rotation_degrees = Vector3(30, 140, 0); fill.light_energy = 0.65; fill.light_color = Color(0.57, 0.65, 0.71); stage.add_child(fill)
	camera = Camera3D.new(); stage.add_child(camera)

func cover(model: Node3D, kind: String) -> void:
	if kind == "ship":
		ProductionSurface.apply_ship(model)
	elif material_adapter != null: material_adapter.call("apply_object", model, kind)

func view_inspection(model: Node3D, id: String, kind: String) -> void:
	var before: String = state_signature()
	var geometry: Dictionary = geometry_signature(model)
	var materials: Array[Dictionary] = material_data(model)
	contracts.static_surface(model, id)
	for view: String in ["rear", "port"]:
		fixed_camera(model, view)
		await capture("extra-view-" + kind + "-" + id + "-" + view, model, kind + "_view", null, {"view": view, "fixture": "camera-only inspection of static object-space microtexture and view-dependent reflection"})
	check(state_signature() == before and geometry_signature(model) == geometry and material_data(model) == materials, "camera inspection preserves mesh/texture uniforms and full gameplay/RNG state " + id)

func preserved(before: Dictionary, after: Dictionary, before_box: AABB, after_box: AABB, before_pose: Transform3D, after_pose: Transform3D) -> bool:
	# New bevel topology is allowed; physics, anchors, root pose and envelope are not.
	if not check(before.has("collisions") and before.has("anchors") and after.has("collisions") and after.has("anchors"), "both physical snapshots contain their complete collision/anchor contract"): return false
	return before.collisions == after.collisions and before.anchors == after.anchors and before_pose.is_equal_approx(after_pose) and before_box.is_equal_approx(after_box)

func asset_matrix() -> void:
	var ships: Array = host.store.catalog.rows("ship_defs").duplicate()
	ships.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.ship_id) < str(b.ship_id))
	check(ships.size() == 18, "all eighteen actual catalog ships are enumerated")
	for definition: Dictionary in ships:
		var id: String = str(definition.ship_id)
		var model: Node3D = ship_factory.call("scene", id)
		if not check(model != null, "real production wrapper loads " + id): continue
		stage.add_child(model)
		if contracts != null: contracts.ship_wrapper(model, id)
		var before: Dictionary = geometry_signature(model)
		var before_box: AABB = bounds(model)
		var before_pose: Transform3D = model.transform
		cover(model, "ship")
		check(preserved(before, geometry_signature(model), before_box, bounds(model), before_pose, model.transform), "material cover preserves collision mounts root pose and model envelope " + id)
		if contracts != null: contracts.materials(model, "ship", id)
		fixed_camera(model)
		await capture("ship-" + id, model, "ship", null, {"ship_id": id})
		if contracts != null and id == "cruiser_horizon": await view_inspection(model, id, "ship")
		stage.remove_child(model); model.queue_free(); await frames(2)
	if contracts != null:
		var enemy: Node3D = ship_factory.call("scene", "enemy_silent")
		stage.add_child(enemy); contracts.ship_wrapper(enemy, "enemy_silent"); cover(enemy, "ship"); contracts.materials(enemy, "ship", "enemy_silent")
		fixed_camera(enemy)
		await capture("extra-ship-enemy_silent", enemy, "enemy_ship", null, {"ship_id": "enemy_silent"})
		stage.remove_child(enemy); enemy.queue_free(); await frames(2)
	for spec: Array in [["station", ""], ["gate", ""], ["wreck", ""], ["ore", "ore_iron_silicate"], ["ore", "ore_conductive_crystal"], ["ore", "ore_echo_silica"], ["ore", "ore_mirror_crystal"], ["ore", "ore_corrosion_titanium"], ["ore", "ore_pressure_steel"], ["ore", "ore_solar_core"], ["ore", "ore_phase_stone"]]:
		var kind: String = spec[0]; var item: String = spec[1]
		var model: Node3D = ProductionFactory.static_body(kind, "render-quality-" + kind, item)
		if not check(model != null, "real production static wrapper loads " + kind + item): continue
		if kind == "station": check(StationVisual.apply(model), "actual legacy station visual adapter runs before new material cover")
		stage.add_child(model)
		var before: Dictionary = geometry_signature(model)
		var before_box: AABB = bounds(model)
		var before_pose: Transform3D = model.transform
		cover(model, kind)
		check(preserved(before, geometry_signature(model), before_box, bounds(model), before_pose, model.transform), "static material cover preserves collision anchors root pose and envelope " + kind + item)
		if contracts != null: contracts.materials(model, kind, kind + item)
		fixed_camera(model)
		await capture("object-" + kind + ("-" + item if not item.is_empty() else ""), model, kind, null, {"item_id": item})
		if contracts != null and kind == "ore" and item == "ore_iron_silicate": await view_inspection(model, item, "ore")
		stage.remove_child(model); model.queue_free(); await frames(2)

func hangar_matrix() -> void:
	preview.hide(); host.world.hide(); host.hangar.show(); host.hangar.process_mode = Node.PROCESS_MODE_DISABLED
	check(host.hangar.get_script().resource_path.ends_with("civilization_hangar.gd") if label == "before" else host.hangar.get_script().resource_path.ends_with("ship_v4_hangar.gd"), "actual Main uses the declared production hangar subclass")
	var ships: Array = host.store.catalog.rows("ship_defs").duplicate()
	ships.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.ship_id) < str(b.ship_id))
	for definition: Dictionary in ships:
		host.hangar.change_ship(str(definition.ship_id))
		var exhibit: Node3D = host.hangar.get_node("ShipExhibition")
		if not check(exhibit.get_child_count() == 1, "actual subclass has one exhibition model " + str(definition.ship_id)): continue
		if contracts != null: check(contracts.v4_marked(exhibit), "actual hangar model carries v4 provenance " + str(definition.ship_id))
		var view: Camera3D = host.hangar.get_camera()
		view.position = host.hangar._camera_destination; view.look_at(host.hangar.to_global(host.hangar._camera_target)); view.make_current()
		if contracts != null: contracts.materials(exhibit, "ship", "actual-hangar-" + str(definition.ship_id))
		await capture("hangar-" + str(definition.ship_id), exhibit, "hangar", view, {"ship_id": definition.ship_id, "hangar_camera_environment": scalar(view.environment)})
	if contracts != null:
		contracts.hangar(host.hangar)
		for quality: String in ["high", "medium", "low"]:
			host.hangar.set_visual_quality(quality)
			await capture("extra-hangar-quality-" + quality, host.hangar.get_node("ShipExhibition"), "hangar_quality", host.hangar.get_camera(), {"quality": quality})
		host.hangar.set_visual_quality("high")
	host.hangar.hide(); preview.show()

func particle_seed(model: Node) -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for node: Node in descendants(model):
		if not node is GPUParticles3D: continue
		var properties: Array[String] = []
		for property: Dictionary in node.get_property_list(): properties.append(str(property.name))
		if properties.has("use_fixed_seed"): node.set("use_fixed_seed", true)
		if properties.has("seed"): node.set("seed", SEED)
		check(properties.has("use_fixed_seed") and properties.has("seed"), "GPU emitter supports a recorded fixed random seed")
		node.fixed_fps = 60; node.preprocess = 0.08; node.restart()
		data.append({"node": str(model.get_path_to(node)), "seed": SEED, "fixed_seed_supported": properties.has("use_fixed_seed") and properties.has("seed"), "amount": node.amount, "lifetime": node.lifetime, "one_shot": node.one_shot, "fixed_fps": node.fixed_fps, "preprocess": node.preprocess})
	return data

func effect_matrix() -> void:
	var config: Dictionary = host.presentation.config
	var specifications: Array[Dictionary] = []
	for family: String in ["thermal", "kinetic", "pulse", "drone"]:
		specifications.append({"case": "weapon-" + family, "method": "weapon_visual", "args": [family, config]})
		specifications.append({"case": "muzzle-" + family, "method": "muzzle", "args": [Vector3.ZERO, family, config]})
	specifications.append_array([{"case": "shield-contact", "method": "shield_contact", "args": [Vector3(10, 5, 15), Vector3(0.4, 0.2, -1), Color("86b8ca"), config]}, {"case": "surface-impact", "method": "impact", "args": [Vector3.ZERO, Color("c6a76d"), config, Vector3.UP]}, {"case": "mining-beam", "method": "beam", "args": [Vector3(-8, 0, 0), Vector3(8, 0, 0), Color("c6a76d"), config]}, {"case": "shield-shell", "method": "shield", "args": [10.0, Color("86b8ca"), config]}, {"case": "wormhole", "method": "wormhole", "args": [10.0, Color("86b8ca"), config]}, {"case": "explosion", "method": "explosion", "args": [Vector3.ZERO, 10.0, Color("ffc078"), config]}, {"case": "engine-trail", "method": "engine_trail", "args": [1.0, Color("86b8ca"), config]}])
	for spec: Dictionary in specifications:
		var model: Node3D = effects.callv(spec.method, spec.args) as Node3D
		if not check(model != null, "production FX factory returns " + str(spec.case)): continue
		model.process_mode = Node.PROCESS_MODE_DISABLED
		stage.add_child(model)
		if spec.case == "weapon-thermal": model.scale.z = 20.0
		var particles: Array[Dictionary] = particle_seed(model)
		if contracts != null:
			var legacy_factory: Script = ProductionEffects
			var legacy: Node3D = legacy_factory.callv(spec.method, spec.args) as Node3D
			contracts.effect(model, legacy, str(spec.case)); legacy.free()
		var age: float = 0.05
		if model.has_method("_process") and not model is GPUParticles3D:
			var duration: float = float(model.get("duration_s"))
			if duration > 0.0: age = minf(age, duration * 0.25)
			model.call("_process", age)
		fixed_camera(model)
		if model is GPUParticles3D or not particles.is_empty():
			camera.position = Vector3(14, 8, -18); camera.look_at(Vector3.ZERO); camera.near = 0.01; camera.far = 200.0
		await frames(3)
		for node: Node in descendants(model):
			if node is GPUParticles3D: node.speed_scale = 0.0
		check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "FX adds no gameplay damage collision " + str(spec.case))
		await capture("fx-" + str(spec.case), model, "effect", null, {"method": spec.method, "effect_age_s": age, "gpu_particles": particles, "particle_timing_scope": "fixed GPU seed/fps/preprocess; warmed real renderer then frozen, not exact GPU timestamp"})
		stage.remove_child(model); model.queue_free(); await frames(2)

func run() -> void:
	directory = OS.get_environment("XJ_RENDER_QUALITY_AUDIT_DIRECTORY").replace("\\", "/")
	label = OS.get_environment("XJ_RENDER_QUALITY_AUDIT_LABEL")
	# In a release res:// belongs to the EXE/PCK. Derive the external workspace
	# only from this fixed test script, as the production diagnostic dispatcher does.
	var source_path: String = str(get_script().resource_path).replace("\\", "/")
	var requested_script: String = OS.get_environment("XJ_RENDER_QUALITY_AUDIT_SCRIPT").replace("\\", "/")
	var expected: String = source_path.get_base_dir().get_base_dir().path_join("tmp/render-quality-audit")
	var run_name: String = directory.get_file()
	var uuid_pattern := RegEx.new()
	uuid_pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	var safe_source: bool = source_path.is_absolute_path() and source_path.ends_with("/jiaoben/tests/render_quality_audit.gd") and not source_path.contains("..") and requested_script == source_path
	var safe_directory: bool = directory.is_absolute_path() and not directory.contains("..") and directory.simplify_path() == directory and directory.get_base_dir() == expected and uuid_pattern.search(run_name) != null
	if not check(DisplayServer.get_name() != "headless" and safe_source and safe_directory and label in ["before", "after"] and not FileAccess.file_exists(directory.path_join("progress.db")) and not FileAccess.file_exists(directory.path_join("route-progress.db")), "native renderer fixed absolute external script and fresh scoped UUID databases required"):
		get_tree().quit(1); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_factor = 1.0; root.content_scale_size = root.size
	if label == "after":
		var material_path: String = OS.get_environment("XJ_RENDER_QUALITY_MATERIAL_SCRIPT")
		var effects_path: String = OS.get_environment("XJ_RENDER_QUALITY_EFFECTS_SCRIPT")
		if not check(material_path == "res://runtime/surface_style.gd" and effects_path == "res://runtime/rendering/realistic_effects.gd" and ResourceLoader.exists(material_path) and ResourceLoader.exists(effects_path), "after uses explicit production rendering facades"):
			await finish(); return
		material_adapter = load(material_path) as Script; effects = load(effects_path) as Script
		ship_factory = load("res://runtime/rendering/ship_v4_factory.gd") as Script
		var baseline_path: String = OS.get_environment("XJ_RENDER_QUALITY_BASELINE_RESULT")
		var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		if not check(baseline is Dictionary and baseline.get("label", "") == "before", "after reads the accepted test-owned before composition record"): await finish(); return
		for observation: Dictionary in baseline.observations: baseline_cases[str(observation.case)] = observation
		var helper_path: String = get_script().resource_path.get_base_dir().path_join("render_quality_contracts.gd")
		contracts = (load(helper_path) as Script).new(self)
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db"); root.add_child(host)
	host.set_process(false); host.set_physics_process(false)
	await frames(4)
	if not check(host.services_ready, "real Main opens only the isolated database"): await finish(); return
	var candidate: XJRuntimeState = host.store.new_world("原生材质效果配对审查", SEED, Callable(host, "_prepare_loaded"))
	if not check(candidate != null, "normal store creates deterministic seed71 typed world"): await finish(); return
	host._activate(candidate); host._process(0.0); await frames(6)
	host.ui.root.hide(); host.hangar.process_mode = Node.PROCESS_MODE_DISABLED; host.world.process_mode = Node.PROCESS_MODE_DISABLED
	initial_state = state_signature()
	build_stage()
	await asset_matrix()
	await hangar_matrix()
	await effect_matrix()
	if contracts != null:
		var debris: Node3D = contracts.debris_fixture()
		stage.add_child(debris); contracts.materials(debris, "debris", "exploration-generator")
		fixed_camera(debris)
		await capture("extra-exploration-debris-generator", debris, "debris_generator", null, {"fixture": "same production exploration visual generator; one unchanged standalone sphere collider"})
		stage.remove_child(debris); debris.queue_free(); await frames(2)
		var operation: Node3D = contracts.operation_fixture()
		if not check(is_instance_valid(operation), "operation fixture satisfies its real generator and collision contract before rendering"):
			await finish(); return
		stage.add_child(operation); contracts.materials(operation, "jammer", "real-operation-generator")
		fixed_camera(operation)
		await capture("extra-operation-generator", operation, "operation_generator", null, {"fixture": "actual production jammer generator with its unchanged collision and three bounded 44-triangle pieces"})
		stage.remove_child(operation); operation.queue_free(); await frames(2)
		await contracts.production_routes()
		await contracts.lifecycle()
		await contracts.intensity()
	check(state_signature() == initial_state, "all staged material and effect operations preserve every runtime table including RNG")
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	var contract_evidence: Dictionary = contracts.report() if contracts != null else {}
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory, "label": label, "native": DisplayServer.get_name() != "headless", "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "seed": SEED, "observations": observations, "state_signature_before": initial_state, "state_signature_after": state_signature() if is_instance_valid(host) and host.state != null else "", "effects_script": effects.resource_path, "materials_script": material_adapter.resource_path if material_adapter != null else "res://runtime/surface_style.gd", "scope": "native paired asset/material/FX stages and actual civilization hangar; no natural progression, physical combat, all quality modes, FPS certification, or complete FX lifecycle acceptance"}
	summary["contract_evidence"] = contract_evidence
	summary["packed_runtime"] = not OS.has_feature("editor")
	var runtime_resources: Dictionary = {}
	for path: String in ["res://assets/materials_v1/manifest.json", "res://assets/effects_v1/manifest.json", "res://runtime/surface_style.gd", "res://runtime/rendering/surface_materials.gd", "res://runtime/rendering/surface_meshes.gd", "res://runtime/rendering/material_hangar.gd", "res://runtime/rendering/realistic_effects.gd"]:
		if FileAccess.file_exists(path): runtime_resources[path] = FileAccess.get_sha256(path)
	if label == "after":
		for path: String in ["res://assets/ship_v4/manifest.json", "res://runtime/rendering/ship_v4_factory.gd", "res://runtime/rendering/ship_v4_hangar.gd", "res://assets/materials_v1/hangar_reflection.res", "res://assets/materials_v1/hangar_reflection.gdshader", "res://assets/materials_v1/rock_strata.png"]:
			if FileAccess.file_exists(path): runtime_resources[path] = FileAccess.get_sha256(path)
		for pack: String in ["materials_v1", "effects_v1", "ship_v4"]:
			var manifest_path: String = "res://assets/" + pack + "/manifest.json"
			if not FileAccess.file_exists(manifest_path): continue
			var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if not manifest is Dictionary: continue
			for resource: Dictionary in manifest.get("resources", []):
				var path: String = str(resource.get("resource_path", resource.get("path", "")))
				if path.begins_with("res://") and not path.contains("..") and FileAccess.file_exists(path): runtime_resources[path] = FileAccess.get_sha256(path)
		var ids: Array[String] = []
		if is_instance_valid(host) and host.store != null:
			for definition: Dictionary in host.store.catalog.rows("ship_defs"): ids.append(str(definition.ship_id))
		ids.append("enemy_silent")
		for id: String in ids:
			for path: String in ["res://assets/ship_v4/" + id + ".glb", "res://assets/ship_v4/portraits/" + id + ".png"]:
				if FileAccess.file_exists(path): runtime_resources[path] = FileAccess.get_sha256(path)
	summary["loaded_resource_sha256"] = runtime_resources
	if label == "after": summary["scope"] = "original 62 paired renderer cases plus 19 signed-wrapper ship contracts, isolated actual player/NPC/owned/hired projection and portraits, baked hangar quality, finite FX count/lifetime/pause/owner callbacks and non-background pixels; declared asset/qualification/pose fixtures; no natural play, active physical combat, every FX runtime route, or FPS/GPU timing certification"
	if is_instance_valid(preview): preview.queue_free()
	if is_instance_valid(viewport): viewport.queue_free()
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(6)
	var file: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(summary, "\t") + "\n"); file.close()
	print("RENDER_QUALITY_AUDIT_RESULT ", summary.result, " checks=", checks, " failures=", failures.size(), " captures=", captures)
	get_tree().quit(0 if failures.is_empty() else 1)
