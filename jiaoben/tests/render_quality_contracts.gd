extends RefCounted
## After-only semantic/geometry/lifecycle assertions. No gameplay physics ticks.
## A second fresh test database declares qualified assets for real projection routes.
const ROLE_IDS: Dictionary = {"metal": 0, "steel": 1, "recess": 2, "paint": 3, "ceramic": 4, "rock": 5, "ore_metal": 6, "crystal": 7, "glass": 8, "fabric": 9, "rubber": 10, "skin": 11}
const Dto = preload("res://contracts/contract_dtos.gd")
const Types = preload("res://contracts/contract_types.gd")
const Space = preload("res://runtime/space_coordinates.gd")
var audit: Node
var role_counts: Dictionary = {}
var chamfered_meshes: int = 0
var debris_meshes: int = 0
var ore_boulders: int = 0
var ore_evidence: Array[Dictionary] = []
var effect_checks: Array[Dictionary] = []
var intensity_evidence: Array[Dictionary] = []
var ship_contracts: Array[Dictionary] = []
var route_evidence: Dictionary = {}
var reflection_evidence: Array[Dictionary] = []

func _init(owner_audit: Node) -> void: audit = owner_audit

func verify(ok: bool, label: String) -> void: audit.check(ok, label)

func triangle_contract(mesh: Mesh, expected_count: int, source_bounds: AABB, label: String) -> void:
	var count: int = 0
	var outward: bool = true
	var clockwise: bool = true
	var normal_valid: bool = true
	var center: Vector3 = source_bounds.get_center()
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			verify(false, "complete actual triangle vertex array " + label)
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array else PackedVector3Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		var size: int = indices.size() if not indices.is_empty() else vertices.size()
		verify(size % 3 == 0, "actual surface contains complete triangles " + label)
		normal_valid = normal_valid and normals.size() == vertices.size()
		if normals.size() != vertices.size():
			count += int(size / 3); clockwise = false; outward = false
			continue
		for start: int in range(0, size - size % 3, 3):
			var ia: int = indices[start] if not indices.is_empty() else start
			var ib: int = indices[start + 1] if not indices.is_empty() else start + 1
			var ic: int = indices[start + 2] if not indices.is_empty() else start + 2
			var a: Vector3 = vertices[ia]; var b: Vector3 = vertices[ib]; var c: Vector3 = vertices[ic]
			var face: Vector3 = (b - a).cross(c - a)
			for index: int in [ia, ib, ic]:
				var normal: Vector3 = normals[index]
				normal_valid = normal_valid and normal.is_finite() and absf(normal.length() - 1.0) < 0.001
				clockwise = clockwise and face.length_squared() > 0.000000000001 and face.dot(normal) < 0.0
				outward = outward and normal.dot((a + b + c) / 3.0 - center) > 0.0
			count += 1
	verify(count == expected_count and mesh.get_aabb().is_equal_approx(source_bounds), "actual triangle count and source envelope " + label)
	verify(normal_valid and clockwise and outward, "actual mesh has finite unit outward normals and clockwise nondegenerate triangles " + label)

func materials(model: Node3D, kind: String, label: String) -> void:
	var matched: int = 0
	var physical: bool = true
	var metadata: bool = true
	for node: Node in audit.descendants(model):
		if not node is MeshInstance3D or node.mesh == null: continue
		if node.mesh.resource_name == "materials_v1_chamfer_box":
			var original: BoxMesh = audit.optional_meta(node, "xj_chamfer_source") as BoxMesh
			if original != null: triangle_contract(node.mesh, 44, original.get_aabb(), label + "/" + str(node.name))
			elif kind == "jammer":
				var dimensions: Vector3 = Vector3(20, 8, 20) if node.get_index() == 0 else Vector3(9, 16, 9)
				triangle_contract(node.mesh, 44, AABB(-dimensions * 0.5, dimensions), "actual operation generator piece " + str(node.get_index()))
			else: verify(false, "bevel retains authored BoxMesh provenance " + label)
			chamfered_meshes += 1
		for surface: int in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface)
			if not material is ShaderMaterial or str(audit.optional_meta(material, "xj_materials_version", "")) != "materials-v1": continue
			matched += 1
			var role: String = str(audit.optional_meta(material, "surface_role", ""))
			role_counts[role] = int(role_counts.get(role, 0)) + 1
			var source: StandardMaterial3D = audit.optional_meta(material, "source_material") as StandardMaterial3D
			metadata = metadata and ROLE_IDS.has(role) and source != null and material.shader != null and material.shader.resource_path == "res://assets/materials_v1/surface.gdshader"
			if not ROLE_IDS.has(role): continue
			metadata = metadata and int(material.get_shader_parameter("surface_role")) == int(ROLE_IDS[role])
			var metallic: float = float(material.get_shader_parameter("base_metallic"))
			var roughness: float = float(material.get_shader_parameter("base_roughness"))
			physical = physical and metallic >= 0.0 and metallic <= 1.0 and roughness >= 0.0 and roughness <= 1.0
			if role in ["rock", "paint", "ceramic", "crystal", "glass", "fabric", "rubber", "skin"]: physical = physical and is_zero_approx(metallic)
			if role == "metal": physical = physical and metallic >= 0.85
			if role == "steel": physical = physical and metallic >= 0.75
			if role == "ore_metal": physical = physical and metallic >= 0.65
			if role == "rock": physical = physical and roughness >= 0.8 and float(material.get_shader_parameter("micro_relief_m")) > 0.0
			if role == "crystal": physical = physical and is_equal_approx(float(material.get_shader_parameter("emission_scale")), 0.18)
			if source != null: metadata = metadata and material.get_shader_parameter("base_color") == source.albedo_color
	verify(matched > 0 and metadata and physical, "actual material roles preserve authored color and distinguish dielectric rock/paint from exposed metal " + label + " " + kind)
	if kind == "ore": ore(model, label)

func ore(model: Node3D, label: String) -> void:
	var mode: String = str(audit.optional_meta(model, "xj_ore_geometry_mode", ""))
	var sources: Array = audit.optional_meta(model, "xj_ore_geometry_sources", [])
	var meshes: int = 0
	var surfaces: int = 0
	var boulders: int = 0
	var minerals: bool = true
	for node: Node in audit.descendants(model):
		if not node is MeshInstance3D or node.mesh == null: continue
		meshes += 1; surfaces += node.mesh.get_surface_count()
		if node.mesh.resource_name != "materials_v1_irregular_ore": continue
		boulders += 1; ore_boulders += 1
		var source_bounds: AABB = audit.optional_meta(node, "xj_ore_geometry_bounds", AABB())
		triangle_contract(node.mesh, 2048, source_bounds, "actual irregular ore mother rock " + label)
		var material: ShaderMaterial = node.get_active_material(0) as ShaderMaterial
		minerals = minerals and material != null and str(audit.optional_meta(material, "surface_role", "")) == "rock" and is_zero_approx(float(material.get_shader_parameter("base_metallic")))
		if mode == "mineralized_rock" and material != null:
			var amount: Variant = shader_value(material, "mineral_amount")
			var scale: Variant = shader_value(material, "mineral_scale")
			minerals = minerals and (amount is float or amount is int) and (scale is float or scale is int)
			if amount is float or amount is int: minerals = minerals and float(amount) > 0.0
			if scale is float or scale is int: minerals = minerals and float(scale) > 0.0
			minerals = minerals and shader_value(material, "mineral_color") is Color
	verify(str(audit.optional_meta(model, "xj_ore_geometry_version", "")) == "materials-v1" and not sources.is_empty() and boulders == 1 and minerals, "actual ore carries authored source provenance and one dielectric mineralized mother rock " + label)
	verify((mode == "mineralized_rock" and meshes == 1) or (mode == "crystal_matrix" and meshes >= 2), "ore removes rectangular mineral display geometry while preserving real crystal clusters " + label)
	verify(surfaces == int(audit.optional_meta(model, "xj_ore_surface_count_after", -1)), "ore surface provenance matches actual rendered surface inventory " + label)
	ore_evidence.append({"case": label, "mode": mode, "source_count": sources.size(), "surface_count_before": int(audit.optional_meta(model, "xj_ore_surface_count_before", -1)), "surface_count_after": surfaces, "visible_meshes": meshes, "boulders": boulders, "mother_rock_triangles": 2048})

func shader_value(material: ShaderMaterial, parameter: String) -> Variant:
	var value: Variant = material.get_shader_parameter(parameter)
	return value if value != null else RenderingServer.shader_get_parameter_default(material.shader.get_rid(), parameter)

func particle_state(node: GPUParticles3D) -> Dictionary:
	var process: ParticleProcessMaterial = node.process_material as ParticleProcessMaterial
	var result: Dictionary = {"amount": node.amount, "lifetime": node.lifetime, "one_shot": node.one_shot, "explosiveness": node.explosiveness, "local_coords": node.local_coords, "draw_passes": node.draw_passes, "visibility_aabb": [audit.vec(node.visibility_aabb.position), audit.vec(node.visibility_aabb.size)], "process_class": process.get_class() if process != null else "none"}
	if process != null:
		for field: String in ["direction", "spread", "gravity", "initial_velocity_min", "initial_velocity_max", "scale_min", "scale_max"]: result[field] = audit.scalar(process.get(field))
		var ramp: GradientTexture1D = process.color_ramp as GradientTexture1D
		if ramp != null and ramp.gradient != null:
			var colors: Array = []
			for index: int in range(ramp.gradient.get_point_count()): colors.append([ramp.gradient.get_offset(index), ramp.gradient.get_color(index).to_html(true)])
			result["process_color_ramp"] = colors
	return result

func node_counts(model: Node) -> Dictionary:
	var counts: Dictionary = {}
	for node: Node in audit.descendants(model): counts[node.get_class()] = int(counts.get(node.get_class(), 0)) + 1
	return counts

func effect(model: Node3D, legacy: Node3D, label: String) -> void:
	var expected_particles: Array[Dictionary] = []
	var actual_particles: Array[Dictionary] = []
	var shader_resources: bool = true
	var soft_particles: int = 0
	var material_clocks: bool = true
	for node: Node in audit.descendants(legacy):
		if node is GPUParticles3D: expected_particles.append(particle_state(node))
	for node: Node in audit.descendants(model):
		if node is GPUParticles3D:
			actual_particles.append(particle_state(node))
			soft_particles += 1
			shader_resources = shader_resources and node.draw_pass_1 is QuadMesh and node.material_override is ShaderMaterial and str(audit.optional_meta(node, "effect_material_version", "")) == "effects-v1"
			if node.material_override is ShaderMaterial: shader_resources = shader_resources and node.material_override.shader.resource_path == "res://assets/effects_v1/particle.gdshader" and node.material_override.shader.code.contains("INSTANCE_CUSTOM")
		if node is MeshInstance3D and str(audit.optional_meta(node, "effect_material_version", "")) == "effects-v1":
			var material: ShaderMaterial = node.material_override as ShaderMaterial
			shader_resources = shader_resources and material != null and material.shader.resource_path.begins_with("res://assets/effects_v1/")
			var clocks: Array = model.get("shader_materials")
			material_clocks = material_clocks and clocks.has(material)
	var durations: bool = true
	if not model is GPUParticles3D: durations = is_equal_approx(float(model.get("duration_s")), float(legacy.get("duration_s")))
	verify(expected_particles == actual_particles and durations and node_counts(model) == node_counts(legacy), "FX facelift preserves visual node/particle counts simulation bounds process and owner lifetime " + label)
	verify(shader_resources and material_clocks, "FX uses real soft quad/shader resources and replaces live material clocks " + label)
	effect_checks.append({"case": label, "gpu_emitters": soft_particles, "particle_contract": actual_particles, "node_counts": node_counts(model), "same_lifetime": durations})

func hangar(hangar: Node3D) -> void:
	verify(hangar.find_children("*", "ReflectionProbe", true, false).is_empty(), "actual hangar uses baked reflections without a realtime reflection atlas")
	var static_count: int = 0
	var dynamic_count: int = 0
	var separated: bool = true
	for node: Node in audit.descendants(hangar):
		if not node is MeshInstance3D: continue
		if bool(audit.optional_meta(node, "materials_reflection_static", false)):
			static_count += 1; separated = separated and (node.layers & (1 << 18)) != 0
		else:
			dynamic_count += 1; separated = separated and (node.layers & (1 << 18)) == 0
	verify(separated and static_count > 0 and dynamic_count > 0, "static room/window enter capture layer while dynamic hull and crew stay excluded")
	for quality: String in ["high", "medium", "low"]:
		hangar.call("set_visual_quality", quality)
		var env: Environment = hangar.call("get_camera").environment
		verify(env.reflected_light_source == Environment.REFLECTION_SOURCE_SKY and env.ssao_enabled == (quality == "high") and env.glow_enabled == (quality != "low"), "actual hangar quality switches reflection SSAO and glow " + quality)
		if quality == "low":
			verify(env.sky != null and env.sky.radiance_size == Sky.RADIANCE_SIZE_128 and env.sky.sky_material is ProceduralSkyMaterial, "low quality uses the small neutral reflection sky")
		else:
			var material: ShaderMaterial = env.sky.sky_material as ShaderMaterial if env.sky != null else null
			var cube: Cubemap = shader_value(material, "room_map") as Cubemap if material != null else null
			verify(material != null and material.shader.resource_path == "res://assets/materials_v1/hangar_reflection.gdshader" and cube != null and cube.get_layers() == 6, "high and medium use actual six-face room reflection resource " + quality)
			if cube != null:
				for face: int in range(cube.get_layers()):
					var image: Image = cube.get_layer_data(face)
					var low := Vector3.ONE; var high := Vector3.ZERO
					for y: int in range(0, image.get_height(), 8):
						for x: int in range(0, image.get_width(), 8):
							var color: Color = image.get_pixel(x, y); var sample := Vector3(color.r, color.g, color.b)
							low = low.min(sample); high = high.max(sample)
					verify(not image.is_empty() and image.get_size() == Vector2i(256, 256) and image.has_mipmaps() and (high - low).length() > 0.05, "baked room face contains real nonuniform native content and mipmaps " + quality + "/" + str(face))
					reflection_evidence.append({"quality": quality, "face": face, "sha256": image.get_data().hex_encode().sha256_text(), "size": [image.get_width(), image.get_height()], "rgb_range": audit.vec(high - low)})
	hangar.call("set_visual_quality", "high")

func v4_marked(model: Node) -> bool:
	if not is_instance_valid(model): return false
	for node: Node in audit.descendants(model):
		if str(audit.optional_meta(node, "visual_asset_version", "")) == "ship-v4": return true
	return false

func ship_wrapper(model: Node3D, id: String) -> void:
	var resource: PackedScene = load("res://assets/ships/" + id + ".tscn") as PackedScene
	var signed: Node3D = resource.instantiate() as Node3D
	var prior: Dictionary = audit.geometry_signature(signed)
	var actual: Dictionary = audit.geometry_signature(model)
	verify(prior.collisions == actual.collisions and prior.anchors == actual.anchors and signed.transform.is_equal_approx(model.transform), "v4 preserves signed collider FX hardpoints cameras interaction and root pose " + id)
	var collision: CollisionShape3D = signed.get_node("CollisionShape3D")
	var box: BoxShape3D = collision.shape as BoxShape3D
	var visual: AABB = audit.bounds(model)
	var limit: AABB = collision.transform * AABB(-box.size * 0.5025, box.size * 1.005)
	verify(v4_marked(model) and limit.encloses(visual), "v4 actual mesh stays inside old physical box within half-percent tolerance " + id)
	ship_contracts.append({"id": id, "visual_bounds": [audit.vec(visual.position), audit.vec(visual.size)], "collision_size": audit.vec(box.size), "tolerance_fraction": 0.005})
	signed.free()

func operation_fixture() -> Node3D:
	var generator: Script = load("res://runtime/operation_visual.gd")
	var model: Node3D = generator.call("generator")
	if not audit.check(model != null, "actual operation generator returns its real body"): return null
	# The production generator leaves node names automatic, so an off-tree
	# CollisionShape3D is named @CollisionShape3D@... rather than its class name.
	var collisions: Array[Node] = model.find_children("*", "CollisionShape3D", true, false)
	if not audit.check(collisions.size() == 1, "actual operation generator has exactly one physical shape"):
		model.free(); return null
	var collision: CollisionShape3D = collisions[0] as CollisionShape3D
	if not audit.check(collision != null and collision.shape is BoxShape3D and collision.shape.size == Vector3(22, 36, 22) and collision.position == Vector3(0, 10, 0), "actual operation generator retains its original collision contract"):
		model.free(); return null
	return model

func close_route(host: Node) -> void:
	host.queue_free()
	await audit.frames(6)

func production_routes() -> void:
	var primary_before: String = audit.state_signature()
	var path: String = audit.directory.path_join("route-progress.db")
	if not audit.check(not FileAccess.file_exists(path), "production route fixture has a separate fresh test-owned database"): return
	var host: Node = audit.host.get_script().new()
	host.progress_database_path = path
	host.process_mode = Node.PROCESS_MODE_DISABLED
	audit.root.add_child(host)
	await audit.frames(3)
	if not audit.check(host.services_ready, "secondary real Main opens only its route fixture database"):
		await close_route(host); return
	var candidate: XJRuntimeState = host.store.new_world("v4真实表现入口夹具", 71, Callable(host, "_prepare_loaded"))
	if not audit.check(candidate != null, "normal store constructs seed71 route fixture world"):
		await close_route(host); return
	host._activate(candidate)
	host.ui.root.hide(); host.hangar.hide(); host.world.hide()
	var g: RefCounted = host.gameplay
	# These are declared presentation qualifications, not a natural growth test.
	host.state.player().credit = 1000000
	for definition: Dictionary in g.rows("unlock_defs"): g.grant_unlock(str(definition.unlock_id))
	var owned: RefCounted = g.inventory.create_ship("frigate_kestrel", g.station())
	if not audit.check(owned != null, "catalog asset fixture creates one normal owned spare hull"):
		await close_route(host); return
	var pilot: String = "crew_pilot_1"
	var result: RefCounted = g.act("crew_action", pilot, 1, "hire|" + g.crew.token(pilot))
	verify(result.phase == Types.ActionPhase.APPLIED, "actual crew action recruits fixture pilot")
	result = g.act("crew_action", pilot, 1, "assign|" + g.crew.token(pilot) + "|" + owned.ship_instance_id)
	verify(result.phase == Types.ActionPhase.APPLIED, "actual crew action assigns fixture pilot to spare hull")
	result = g.act("owned_fleet_action", owned.ship_instance_id, 1, "deploy|" + g.owned_fleet.token(owned.ship_instance_id))
	verify(result.phase == Types.ActionPhase.APPLIED and g.owned_fleet.actor(g.owned_fleet.row(owned.ship_instance_id)) != null, "actual owned fleet action creates deployed production actor")
	var profile: String = str(g.rows("hire_profile_defs")[0].profile_id)
	result = g.act("hire_action", profile, 1, g.hired.token())
	var hired: RefCounted = g.hired.actor()
	if not audit.check(result.phase == Types.ActionPhase.APPLIED and hired != null, "actual paid hire action creates production companion actor"):
		await close_route(host); return
	var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	if not audit.check(not spawn.is_empty(), "ordinary NPC pose fixture uses an actual frozen spawn prototype"):
		await close_route(host); return
	var stats: Dictionary = g.definition("npc_full_defs", "npc_id", str(spawn.npc_id))
	var npc: RefCounted = Dto.NpcStateDto.new()
	npc.npc_instance_id = "render-route-ordinary-scout"; npc.spawn_id = str(spawn.spawn_id); npc.sector_id = host.state.current_sector(); npc.generation = 1
	for existing: RefCounted in host.state.rows("npc_state"):
		if existing.spawn_id == npc.spawn_id: npc.generation = maxi(npc.generation, existing.generation + 1)
	npc.alive = true; npc.shield = stats.shield_max; npc.armor = stats.armor_max; npc.hull = stats.hull_max; npc.behavior_phase = Types.NpcPhase.PATROL
	var location: Vector3 = g.position(host.state.ship()) + Vector3(100, 30, 100)
	npc.pos_x = location.x; npc.pos_y = location.y; npc.pos_z = location.z
	verify(host.state.add("npc_state", npc) and Space.assign(host.state, "npc", npc.npc_instance_id, Space.current_site(host.state)), "ordinary NPC fixture declares one local pose without combat simulation")
	var before: String = audit.state_signature_for(host.state)
	verify(host.world.factory.resource_path == "res://runtime/rendering/ship_v4_factory.gd" and host.world.sync_entities(), "actual Sector projects route actors with the shipped v4 factory")
	verify(v4_marked(host.world.flight.visual) and host.world.flight.record.ship_instance_id == host.state.ship().ship_instance_id, "actual controlled player projection uses its authoritative v4 hull")
	var routes: Dictionary = {"ordinary_npc": npc.npc_instance_id, "owned_fleet": owned.ship_instance_id, "paid_hire": hired.npc_instance_id}
	for kind: String in routes:
		var id: String = str(routes[kind])
		var body: Node = host.world.npcs.get(id)
		verify(body != null and v4_marked(body), "actual Sector actor route renders v4 geometry " + kind)
		if kind != "ordinary_npc": verify(not g.civilizations.escort_hull(id).is_empty(), "actual escort identity resolves catalog hull " + kind)
	host.ui.show_page("ship_roles")
	await audit.frames(5)
	var ui_portraits: Dictionary = {}
	for node: Node in audit.descendants(host.ui.body):
		if not bool(audit.optional_meta(node, "business_list", false)): continue
		for row: Dictionary in node.get("rows"):
			if str(audit.optional_meta(row.row, "asset_kind", "")) != "ship": continue
			var id: String = str(audit.optional_meta(row.row, "asset_id", ""))
			var image: TextureRect = row.image
			var expected: String = "res://assets/ship_v4/portraits/" + id + ".png"
			verify(image.texture != null and image.texture.resource_path == expected and not image.texture.get_image().is_empty(), "actual ship role UI row displays its v4 thumbnail " + id)
			ui_portraits[id] = image.texture.resource_path if image.texture != null else ""
	verify(ui_portraits.size() == 18, "actual business panel exposes all eighteen catalog ship portraits")
	var portraits: Script = load("res://runtime/ui/item_portraits.gd")
	var resolved: Dictionary = {}
	var ids: Array[String] = ["enemy_silent"]
	for definition: Dictionary in g.rows("ship_defs"): ids.append(str(definition.ship_id))
	for id: String in ids:
		var expected: String = "res://assets/ship_v4/portraits/" + id + ".png"
		var texture: Texture2D = portraits.call("texture", "ship", id)
		verify(str(portraits.call("asset_path", "ship", id)) == expected and texture != null and texture.resource_path == expected and not texture.get_image().is_empty(), "actual portrait resolver selects new resource " + id)
		resolved[id] = expected
	verify(audit.state_signature_for(host.state) == before and audit.state_signature() == primary_before, "projection routes and UI portraits preserve both complete post-fixture states including RNG")
	route_evidence = {"database": path, "seed": 71, "routes": routes, "ui_portraits": ui_portraits, "resolved_portraits": resolved, "state_before": before, "state_after": audit.state_signature_for(host.state), "fixture": "secondary normal new world; credit/unlocks/one normal-owned spare hull and ordinary NPC pose declared; crew recruitment/assignment/deployment/hire use actual gameplay APIs; no physical simulation or natural-growth claim"}
	await close_route(host)
	verify(audit.state_signature() == primary_before, "secondary route host disposal preserves primary complete gameplay/RNG state")

func debris_fixture() -> Node3D:
	var meshes: Script = load("res://runtime/rendering/surface_meshes.gd")
	var material_factory: Script = load("res://runtime/rendering/surface_materials.gd")
	var source := SphereMesh.new(); source.radius = 8.0; source.height = 16.0; source.radial_segments = 12; source.rings = 6
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new(); var sphere := SphereShape3D.new(); sphere.radius = source.radius; collision.shape = sphere; body.add_child(collision)
	var visual := MeshInstance3D.new(); visual.mesh = meshes.call("irregular_debris", source)
	var material := StandardMaterial3D.new(); material.albedo_color = Color(0.2, 0.24, 0.26); material.roughness = 0.92
	visual.material_override = material_factory.call("material", material, "debris", "rock"); body.add_child(visual)
	triangle_contract(visual.mesh, 128, source.get_aabb(), "production exploration debris generator fixture")
	verify(is_equal_approx(sphere.radius, source.radius) and body.find_children("*", "CollisionShape3D", true, false).size() == 1, "exploration generator fixture retains one original sphere collider")
	debris_meshes += 1
	return body

func lifecycle() -> void:
	var host: Node = audit.host
	var presentation: Node = host.presentation
	var old_world_mode: int = host.world.process_mode
	var old_mode: int = presentation.process_mode
	var old_intensity: float = presentation.intensity
	var old_paused: bool = presentation.effects_paused
	var before: String = audit.state_signature()
	verify(presentation.effects.is_empty(), "effect safety fixture begins without pre-existing contact visuals")
	presentation.intensity = 1.0
	host.world.process_mode = Node.PROCESS_MODE_INHERIT
	var ship: Node3D = host.world.flight
	presentation.hit(host.state.ship().ship_instance_id, true, ship.global_position + Vector3(1, 0, 0))
	var shield: Node3D = presentation.effects[-1]
	presentation.hit(host.state.ship().ship_instance_id, false, ship.global_position)
	var contact: Node3D = presentation.effects[-1]
	presentation.process_mode = Node.PROCESS_MODE_DISABLED; presentation.set_paused(true)
	var age: float = shield.get("elapsed_s")
	await audit.frames(3)
	var paused_particles: bool = true
	for node: Node in audit.descendants(contact):
		if node is GPUParticles3D: paused_particles = paused_particles and is_zero_approx(node.speed_scale)
	verify(is_instance_valid(shield) and is_equal_approx(float(shield.get("elapsed_s")), age) and paused_particles, "actual presentation pause freezes visual owner age and GPU emitter clock")
	presentation.set_paused(false)
	var resumed_particles: bool = true
	for node: Node in audit.descendants(contact):
		if node is GPUParticles3D: resumed_particles = resumed_particles and is_equal_approx(node.speed_scale, 1.0)
	verify(resumed_particles, "actual presentation resume restores GPU particle speed")
	shield.call("_process", float(shield.get("duration_s")) + 0.01)
	contact.call("_process", float(contact.get("duration_s")) + 0.01)
	await audit.frames(2)
	verify(not is_instance_valid(shield) and not is_instance_valid(contact), "production effect nodes retire at their existing finite catalog lifetime")
	presentation._prune_nodes(presentation.effects)
	var owner := Node3D.new(); presentation.add_child(owner)
	var follower: Node3D = audit.effects.call("shield_contact", Vector3.ONE, Vector3.FORWARD, Color.WHITE, presentation.config)
	follower.set("follow_target", weakref(owner)); presentation._add(follower)
	owner.queue_free(); await audit.frames(2)
	follower.call("_process", 0.0); await audit.frames(2)
	verify(not is_instance_valid(follower), "owner removal releases its live shield follower before natural expiry")
	presentation._prune_nodes(presentation.effects)
	for index: int in range(int(presentation.config.fx_active_instances_max) + 3): presentation.impact(Vector3(index, 0, 0), Color.WHITE)
	var particle_count: int = 0
	for node: Node in presentation.effects: particle_count += presentation._particles(node)
	verify(presentation.effects.size() <= int(presentation.config.fx_active_instances_max) and particle_count <= int(presentation.config.fx_particle_budget_max), "actual presentation rejects bursts beyond catalog instance and particle budgets")
	var count: int = presentation.effects.size(); presentation.intensity = 0.0; presentation.impact(Vector3.ZERO, Color.WHITE)
	verify(presentation.effects.size() == count, "zero FX intensity rejects new geometry")
	for node: Node in presentation.effects:
		if is_instance_valid(node): node.queue_free()
	await audit.frames(2); presentation._prune_nodes(presentation.effects)
	presentation.intensity = old_intensity; presentation.process_mode = old_mode; presentation.set_paused(old_paused); host.world.process_mode = old_world_mode
	verify(presentation.effects.is_empty() and audit.state_signature() == before, "FX safety checks clean all fixture nodes and preserve every gameplay and RNG table")

func strength_matches(node: Node3D, expected: float) -> bool:
	var shaders: int = 0
	var valid: bool = node.visible == (expected > 0.0)
	for child: Node in audit.descendants(node):
		if not child is GeometryInstance3D or not child.material_override is ShaderMaterial: continue
		var material: ShaderMaterial = child.material_override
		if not material.shader.resource_path.begins_with("res://assets/effects_v1/"): continue
		shaders += 1
		var declared: bool = false
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			if str(uniform.name) == "effect_strength": declared = true
		valid = valid and declared and is_equal_approx(float(material.get_shader_parameter("effect_strength")), expected)
	return valid and shaders > 0

func intensity() -> void:
	var host: Node = audit.host
	var presentation: Node = host.presentation
	var before: String = audit.state_signature()
	var old_intensity: float = presentation.intensity
	var old_mode: int = presentation.process_mode
	presentation.process_mode = Node.PROCESS_MODE_DISABLED
	var gates: Array = presentation.gates.duplicate()
	var ids: Array[int] = []
	for gate: Node in gates: ids.append(gate.get_instance_id())
	var voices: Array = presentation.voices.duplicate()
	var audio: Array[Dictionary] = []
	for voice: Node in voices: audio.append({"id": voice.get_instance_id(), "playing": voice.get("playing"), "paused": voice.get("stream_paused"), "stream": voice.get("stream")})
	verify(not gates.is_empty(), "persistent-strength test begins with actual Main wormholes")
	presentation.intensity = 1.0
	presentation.impact(Vector3.ZERO, Color.WHITE)
	var contact: Node3D = presentation.effects[-1]
	for value: float in [1.0, 0.0, 0.5, 1.0]:
		presentation.intensity = value
		var current: Array[int] = []
		var valid: bool = strength_matches(contact, value)
		for gate: Node3D in presentation.gates:
			current.append(gate.get_instance_id()); valid = valid and strength_matches(gate, value)
		var audio_unchanged: bool = presentation.voices.size() == voices.size()
		for index: int in range(voices.size()):
			var voice: Node = voices[index]
			audio_unchanged = audio_unchanged and is_instance_valid(voice) and voice.get_instance_id() == audio[index].id and voice.get("playing") == audio[index].playing and voice.get("stream_paused") == audio[index].paused and voice.get("stream") == audio[index].stream
		verify(valid and current == ids and audio_unchanged and audit.state_signature() == before, "persistent gate and existing FX strength keeps instances audio and gameplay/RNG intact " + str(value))
		intensity_evidence.append({"phase": "existing_main", "strength": value, "gate_count": current.size(), "same_instances": current == ids, "audio_unchanged": audio_unchanged})
	presentation.intensity = 0.5
	presentation.impact(Vector3.ONE, Color.WHITE)
	var added: Node3D = presentation.effects[-1]
	verify(strength_matches(added, 0.5), "new transient FX inherit current half-strength shader and visibility")
	var temporary: Node3D = host.presentation.get_script().new()
	host.world.add_child(temporary)
	temporary.process_mode = Node.PROCESS_MODE_DISABLED
	temporary.call("setup", host.world, host.gameplay, host.store.catalog, 0.0)
	var temporary_gates: Array = temporary.get("gates").duplicate()
	var created: bool = temporary_gates.size() == gates.size()
	for gate: Node3D in temporary_gates: created = created and strength_matches(gate, 0.0)
	verify(created and not temporary_gates.is_empty(), "zero-initialized presenter builds recoverable hidden persistent gates")
	temporary.set("intensity", 1.0)
	var recovered: bool = true
	for gate: Node3D in temporary_gates: recovered = recovered and strength_matches(gate, 1.0)
	verify(recovered, "zero-initialized persistent gates become visible when effects are enabled")
	temporary.queue_free()
	await audit.frames(3)
	var released: bool = not is_instance_valid(temporary)
	for gate_ref: Variant in temporary_gates: released = released and not is_instance_valid(gate_ref)
	var main_retained: bool = presentation.gates.size() == ids.size()
	for index: int in range(gates.size()): main_retained = main_retained and is_instance_valid(gates[index]) and gates[index].get_instance_id() == ids[index]
	verify(released and main_retained, "presenter destruction automatically releases only its own gates without manual cleanup")
	contact.queue_free(); added.queue_free(); await audit.frames(2); presentation._prune_nodes(presentation.effects)
	presentation.intensity = old_intensity; presentation.process_mode = old_mode
	verify(audit.state_signature() == before and presentation.effects.is_empty(), "strength test restores presentation and preserves full gameplay/RNG state")

func static_surface(model: Node3D, label: String) -> void:
	var count: int = 0
	var stable: bool = true
	for node: Node in audit.descendants(model):
		if not node is MeshInstance3D or node.mesh == null: continue
		for surface: int in range(node.mesh.get_surface_count()):
			var material: ShaderMaterial = node.get_active_material(surface) as ShaderMaterial
			if material == null or str(audit.optional_meta(material, "xj_materials_version", "")) != "materials-v1": continue
			count += 1
			stable = stable and not material.shader.code.contains("TIME") and material.get_shader_parameter("micro_surface") is Texture2D
	verify(stable and count > 0, "camera inspection material uses static object-space microtexture without a TIME dependency " + label)

func report() -> Dictionary:
	for role: String in ["metal", "paint", "rock", "crystal"]: verify(int(role_counts.get(role, 0)) > 0, "actual after matrix exercises semantic material role " + role)
	verify(chamfered_meshes > 0 and debris_meshes > 0, "actual after matrix exercises both 44-triangle bevel and 128-triangle debris")
	verify(ore_boulders == 8, "all eight actual ore variants use the bounded 2048-triangle mother-rock mesh")
	verify(ship_contracts.size() == 19 and not route_evidence.is_empty(), "all nineteen v4 signed wrappers and actual production routes were examined")
	return {"material_roles": role_counts, "beveled_meshes": chamfered_meshes, "exploration_debris_generator_fixtures": debris_meshes, "ore_boulders": ore_boulders, "ore_contracts": ore_evidence, "ship_contracts": ship_contracts, "production_routes": route_evidence, "baked_reflection_faces": reflection_evidence, "effect_contracts": effect_checks, "intensity_contracts": intensity_evidence, "scope": "real semantic materials/mesh topology/baked hangar/FX callbacks; qualified projection routes use a separate declared fixture; no active combat or GPU timing claim"}
