class_name XJVisualEffects
extends RefCounted
## config直接传presentation_defs键值。缺参数拒绝创建，避免藏有另一套数值。
const EFFECT_NODE: Script = preload("res://runtime/visuals/visual_effect_node.gd")
const SHADER_ROOT: String = "res://runtime/visuals/shaders/"

static func beam(from: Vector3, to: Vector3, color: Color, config: Dictionary) -> Node3D:
	if not _requires(config, ["fx_beam_width_m", "fx_beam_lifetime_s"]):
		return Node3D.new()
	var node: Node3D = _effect(float(config["fx_beam_lifetime_s"]))
	var vector: Vector3 = to - from
	if vector.length_squared() <= 0.000001:
		return node
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = float(config["fx_beam_width_m"]) * 0.5
	cylinder.bottom_radius = cylinder.top_radius
	cylinder.height = vector.length()
	cylinder.radial_segments = 8
	mesh.mesh = cylinder
	mesh.basis = Basis(Quaternion(Vector3.UP, vector.normalized()))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = (from + to) * 0.5
	_attach_material(node, mesh, "beam.gdshader", color)
	node.add_child(mesh)
	return node

static func shield(radius_m: float, color: Color, config: Dictionary) -> Node3D:
	if not _requires(config, ["fx_shield_lifetime_s"]):
		return Node3D.new()
	var node: Node3D = _effect(float(config["fx_shield_lifetime_s"]))
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius_m
	sphere.height = radius_m * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach_material(node, mesh, "shield.gdshader", color)
	node.add_child(mesh)
	return node

static func wormhole(radius_m: float, color: Color, config: Dictionary) -> Node3D:
	if not _requires(config, ["fx_wormhole_intensity"]):
		return Node3D.new()
	var node: Node3D = _effect(0.0)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * radius_m * 2.0
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = _attach_material(node, mesh, "wormhole.gdshader", color)
	material.set_shader_parameter("intensity", float(config["fx_wormhole_intensity"]))
	node.add_child(mesh)
	return node

static func explosion(at: Vector3, radius_m: float, color: Color, config: Dictionary) -> Node3D:
	if not _requires(config, ["fx_explosion_lifetime_s", "explosion_particles_near"]):
		return Node3D.new()
	var lifetime: float = float(config["fx_explosion_lifetime_s"])
	var node: Node3D = _effect(lifetime)
	node.position = at
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = maxi(1, int(config["explosion_particles_near"]))
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(Vector3.ONE * -radius_m * 2.0, Vector3.ONE * radius_m * 4.0)
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = radius_m / lifetime * 0.3
	process.initial_velocity_max = radius_m / lifetime
	process.scale_min = radius_m * 0.025
	process.scale_max = radius_m * 0.075
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = ramp
	process.color_ramp = texture
	particles.process_material = process
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	particles.draw_pass_1 = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = color
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(particles)
	return node

static func engine_trail(nozzle_radius_m: float, color: Color, config: Dictionary) -> GPUParticles3D:
	## 父节点为FXAnchors/engine_*；挂点-Z轴向舰尾，缩放只影响光焰。
	if not _requires(config, ["fx_engine_particle_lifetime_s", "engine_particles_near", "fx_engine_emission"]):
		return GPUParticles3D.new()
	var lifetime: float = float(config["fx_engine_particle_lifetime_s"])
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = int(config["engine_particles_near"])
	particles.lifetime = lifetime
	particles.visibility_aabb = AABB(Vector3.ONE * -nozzle_radius_m * 13.0, Vector3.ONE * nozzle_radius_m * 26.0)
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3.FORWARD
	process.spread = 7.0
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = nozzle_radius_m * 6.0 / lifetime
	process.initial_velocity_max = nozzle_radius_m * 12.0 / lifetime
	process.scale_min = nozzle_radius_m * 0.25
	process.scale_max = nozzle_radius_m * 0.65
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = ramp
	process.color_ramp = texture
	particles.process_material = process
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	particles.draw_pass_1 = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = float(config["fx_engine_emission"])
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

static func space_background(config: Dictionary) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = "SpaceBackground"
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_ROOT + "space_sky.gdshader") as Shader
	if config.has("nebula_color"):
		material.set_shader_parameter("nebula_color", config["nebula_color"])
	if config.has("nebula_accent"):
		material.set_shader_parameter("nebula_accent", config["nebula_accent"])
	material.set_shader_parameter("visual_seed", float(config.get("visual_seed", 0.0)))
	sky.sky_material = material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.44, 0.58)
	environment.ambient_light_energy = 0.7
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	world.environment = environment
	node.add_child(world)
	return node

static func _requires(config: Dictionary, keys: Array[String]) -> bool:
	for key: String in keys:
		if not config.has(key) or float(config[key]) <= 0.0:
			push_warning("Missing positive presentation parameter: " + key)
			return false
	return true

static func _effect(duration: float) -> Node3D:
	var node: Node3D = Node3D.new()
	node.set_script(EFFECT_NODE)
	node.set("duration_s", duration)
	return node

static func _attach_material(node: Node3D, mesh: MeshInstance3D, shader_file: String, color: Color) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_ROOT + shader_file) as Shader
	material.set_shader_parameter("effect_color", color)
	mesh.material_override = material
	var materials: Array = node.get("shader_materials")
	materials.append(material)
	return material
