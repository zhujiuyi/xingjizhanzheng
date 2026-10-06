class_name XJVisualEffects
extends RefCounted
## config直接传presentation_defs键值。缺参数拒绝创建，避免藏有另一套数值。
const EFFECT_NODE: Script = preload("res://runtime/visuals/visual_effect_node.gd")
const SHADER_ROOT: String = "res://runtime/visuals/shaders/"

static func weapon_visual(family: String, config: Dictionary) -> Node3D:
	## Pure geometry. The combat owner controls flight, lifetime and collision.
	## Local -Z is forward; thermal spans z=0 to z=-1 for scale.z=range.
	var node: Node3D = _effect(0.0)
	node.set_meta("weapon_family", family)
	var radius: float = float(config.projectile_radius_m)
	var emission: float = float(config.projectile_emission)
	match family:
		"legacy":
			node.name = "LegacyProjectile"
			var legacy_color: Color = Color(0.2, 0.85, 1.0)
			if str(config.get("legacy_family", "")) == "thermal": legacy_color = Color(1.0, 0.4, 0.15)
			elif str(config.get("legacy_family", "")) == "pulse": legacy_color = Color(0.5, 0.4, 1.0)
			_weapon_cylinder(node, "LegacyTrail", radius, 1.0, Vector3(0, 0, -0.5), legacy_color, emission)
		"thermal":
			node.name = "LaserRay"
			_weapon_cylinder(node, "LaserCore", radius * 0.24, 1.0, Vector3(0, 0, -0.5), Color("ffe2bd"), emission)
			_weapon_cylinder(node, "LaserHalo", radius * 0.6, 1.0, Vector3(0, 0, -0.5), Color("f78b46"), emission * 0.35, true)
		"pulse":
			node.name = "PulsePacket"
			var pulse_radius: float = float(config.get("fx_pulse_radius_m", radius * 2.4))
			_weapon_sphere(node, "PulseCore", pulse_radius * 0.4, Vector3.ZERO, Color("c9b9ff"), emission * 0.4)
			_weapon_sphere(node, "PulseShell", pulse_radius, Vector3.ZERO, Color("9772ec"), emission * 0.2, true)
		"drone":
			node.name = "CombatDrone"
			var length: float = float(config.get("fx_drone_length_m", radius * 14.4))
			_weapon_box(node, "DroneHull", Vector3(length * 0.34, length * 0.2, length), Vector3.ZERO, Color("434e59"))
			_weapon_box(node, "DroneWingLeft", Vector3(length * 0.55, length * 0.08, length * 0.35), Vector3(-length * 0.4, 0, length * 0.16), Color("57616b"))
			_weapon_box(node, "DroneWingRight", Vector3(length * 0.55, length * 0.08, length * 0.35), Vector3(length * 0.4, 0, length * 0.16), Color("57616b"))
			_weapon_sphere(node, "DroneEngineLeft", radius * 0.5, Vector3(-length * 0.3, 0, length * 0.36), Color("69c7ec"), emission * 0.3)
			_weapon_sphere(node, "DroneEngineRight", radius * 0.5, Vector3(length * 0.3, 0, length * 0.36), Color("69c7ec"), emission * 0.3)
			_weapon_box(node, "DroneGun", Vector3(length * 0.12, length * 0.12, length * 0.38), Vector3(0, -length * 0.13, -length * 0.4), Color("292e33"))
		_:
			node.name = "KineticRound"
			var length: float = float(config.get("fx_kinetic_length_m", radius * 11.2))
			_weapon_cylinder(node, "KineticSlug", radius * 0.6, length * 0.34, Vector3.ZERO, Color("c2ced9"), emission * 0.15)
			_weapon_cylinder(node, "KineticShortTrail", radius * 0.24, length, Vector3(0, 0, length * 0.5), Color("a1c9e0"), emission * 0.3, true)
	return node

static func shield_contact(half_extents: Vector3, local_direction: Vector3, color: Color, config: Dictionary) -> Node3D:
	var node: Node3D = _effect(float(config.fx_shield_lifetime_s))
	node.name = "ShieldContact"
	var mesh := MeshInstance3D.new()
	mesh.name = "LocalShieldArc"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh.mesh = sphere
	mesh.scale = half_extents * 1.08
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = _attach_material(node, mesh, "contact_shield.gdshader", color)
	material.set_shader_parameter("hit_direction", local_direction.normalized() if not local_direction.is_zero_approx() else Vector3.FORWARD)
	node.add_child(mesh)
	return node

static func impact(at: Vector3, color: Color, config: Dictionary, normal: Vector3 = Vector3.UP) -> Node3D:
	## A brief contact flash and bounded sparks; no explosion, lights or damage.
	var lifetime: float = float(config.get("fx_impact_lifetime_s", config.fx_shield_lifetime_s))
	var radius: float = float(config.get("fx_impact_radius_m", config.projectile_radius_m * 4.8))
	var node: Node3D = _effect(lifetime)
	node.name = "SurfaceContact"
	node.position = at
	_weapon_sphere(node, "ContactFlash", radius * 0.18, Vector3.ZERO, color, float(config.projectile_emission) * 0.25, true)
	var particles := GPUParticles3D.new()
	particles.name = "ContactSparks"
	particles.amount = int(config.get("fx_impact_particle_count", config.trail_particles_mid))
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	var speed: float = float(config.get("fx_impact_speed_mps", radius * 12.0))
	var bounds: float = maxf(radius, speed * lifetime)
	particles.visibility_aabb = AABB(Vector3.ONE * -bounds, Vector3.ONE * bounds * 2.0)
	var process := ParticleProcessMaterial.new()
	process.direction = normal.normalized() if not normal.is_zero_approx() else Vector3.UP
	process.spread = 65.0
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = speed * 0.4
	process.initial_velocity_max = speed
	process.scale_min = radius * 0.025
	process.scale_max = radius * 0.07
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.8))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 6
	shape.rings = 3
	particles.draw_pass_1 = shape
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = float(config.projectile_emission) * 0.4
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(particles)
	return node

static func muzzle(at: Vector3, family: String, config: Dictionary) -> Node3D:
	var node: Node3D = _effect(float(config.get("fx_muzzle_lifetime_s", config.fx_beam_lifetime_s)))
	node.name = "MuzzleFlash"
	node.position = at
	_weapon_sphere(node, "BriefMuzzle", float(config.projectile_radius_m) * 1.5, Vector3.ZERO, Color("b0a0f5") if family == "pulse" else Color("ffe1ab"), float(config.projectile_emission) * 0.3, true)
	return node

static func _weapon_box(node: Node3D, title: String, size: Vector3, position: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = position
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	material.roughness = 0.65
	mesh.material_override = material
	node.add_child(mesh)

static func _weapon_sphere(node: Node3D, title: String, radius: float, position: Vector3, color: Color, emission: float, translucent: bool = false) -> void:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 12
	shape.rings = 6
	_weapon_mesh(node, title, shape, position, color, emission, translucent)

static func _weapon_cylinder(node: Node3D, title: String, radius: float, length: float, position: Vector3, color: Color, emission: float, translucent: bool = false) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = length
	shape.radial_segments = 8
	var mesh: MeshInstance3D = _weapon_mesh(node, title, shape, position, color, emission, translucent)
	mesh.rotation.x = PI * 0.5

static func _weapon_mesh(node: Node3D, title: String, shape: Mesh, position: Vector3, color: Color, emission: float, translucent: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = shape
	mesh.position = position
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if translucent:
		var material: ShaderMaterial = _attach_material(node, mesh, "weapon_glow.gdshader", color)
		material.set_shader_parameter("emission_power", emission)
	else:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
		mesh.material_override = material
	node.add_child(mesh)
	return mesh

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
