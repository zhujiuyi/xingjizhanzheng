class_name XJRealisticEffects
extends RefCounted
## Presentation facade. Signed effects keep lifetime, bounds, count and owner clocks.
const Base = preload("res://runtime/visuals/visual_effects.gd")
const Surface = preload("res://runtime/surface_style.gd")
const Materials = preload("res://runtime/rendering/surface_materials.gd")
const ROOT: String = "res://assets/effects_v1/"

static func weapon_visual(family: String, config: Dictionary) -> Node3D:
	var node: Node3D = Base.weapon_visual(family, config)
	Surface.apply_object(node, "drone")
	for child: Node in node.get_children():
		if not child is MeshInstance3D: continue
		var mesh: MeshInstance3D = child
		if str(mesh.name).begins_with("Drone") and "Engine" not in str(mesh.name): continue
		if mesh.name == "KineticSlug":
			var metal := StandardMaterial3D.new()
			metal.resource_name = "Ballistic_Bare_Metal"
			metal.albedo_color = Color("adb6bf"); metal.metallic = 0.96; metal.roughness = 0.24
			mesh.material_override = Materials.material(metal, "drone", "metal")
			continue
		var source: Material = mesh.material_override
		var color: Color = Color.WHITE
		var power: float = float(config.projectile_emission)
		if source is StandardMaterial3D:
			color = source.albedo_color
			power = source.emission_energy_multiplier
		elif source is ShaderMaterial:
			color = source.get_shader_parameter("effect_color")
			power = float(source.get_shader_parameter("emission_power"))
		_install(node, mesh, "energy.gdshader", color, power, "Halo" in str(mesh.name) or "Trail" in str(mesh.name) or "Shell" in str(mesh.name))
	return node

static func muzzle(at: Vector3, family: String, config: Dictionary) -> Node3D:
	var node: Node3D = Base.muzzle(at, family, config)
	_energy_children(node, float(config.projectile_emission) * 0.3)
	return node

static func impact(at: Vector3, color: Color, config: Dictionary, normal: Vector3 = Vector3.UP) -> Node3D:
	var node: Node3D = Base.impact(at, color, config, normal)
	_energy_children(node, float(config.projectile_emission) * 0.25)
	for child: Node in node.get_children():
		if child is GPUParticles3D: _soft_particles(child, color, float(config.projectile_emission) * 0.4, true)
	return node

static func explosion(at: Vector3, radius: float, color: Color, config: Dictionary) -> Node3D:
	var node: Node3D = Base.explosion(at, radius, color, config)
	for child: Node in node.get_children():
		if child is GPUParticles3D: _soft_particles(child, color, 1.8, true)
	return node

static func engine_trail(radius: float, color: Color, config: Dictionary) -> GPUParticles3D:
	var node: GPUParticles3D = Base.engine_trail(radius, color, config)
	_soft_particles(node, color, float(config.fx_engine_emission), false)
	return node

static func beam(from: Vector3, to: Vector3, color: Color, config: Dictionary) -> Node3D:
	var node: Node3D = Base.beam(from, to, color, config)
	for child: Node in node.get_children():
		if child is MeshInstance3D: _install(node, child, "energy.gdshader", color, 2.2, false)
	return node

static func shield_contact(half_extents: Vector3, direction: Vector3, color: Color, config: Dictionary) -> Node3D:
	var node: Node3D = Base.shield_contact(half_extents, direction, color, config)
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var shader: ShaderMaterial = _install(node, child, "shield_contact.gdshader", color)
			shader.set_shader_parameter("hit_direction", direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD)
	return node

static func shield(radius: float, color: Color, config: Dictionary) -> Node3D:
	var node: Node3D = Base.shield(radius, color, config)
	for child: Node in node.get_children():
		if child is MeshInstance3D: _install(node, child, "energy.gdshader", color, 0.7, true)
	return node

static func wormhole(radius: float, color: Color, config: Dictionary) -> Node3D:
	var node: Node3D = Base.wormhole(radius, color, config)
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var shader: ShaderMaterial = _install(node, child, "aperture.gdshader", color)
			shader.set_shader_parameter("intensity", float(config.fx_wormhole_intensity))
	return node

static func space_background(config: Dictionary) -> Node3D:
	return Base.space_background(config)

static func _energy_children(node: Node3D, power: float) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var color: Color = child.material_override.get_shader_parameter("effect_color") if child.material_override is ShaderMaterial else child.material_override.albedo_color
			_install(node, child, "energy.gdshader", color, power)

static func _install(node: Node3D, mesh: MeshInstance3D, filename: String, color: Color, power: float = 1.0, halo: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(ROOT + filename) as Shader
	material.set_shader_parameter("effect_color", color)
	if filename == "energy.gdshader":
		material.set_shader_parameter("emission_power", power)
		material.set_shader_parameter("halo", 1.0 if halo else 0.0)
	var clocks: Array = node.get("shader_materials")
	if mesh.material_override is ShaderMaterial: clocks.erase(mesh.material_override)
	clocks.append(material)
	mesh.material_override = material
	mesh.set_meta("effect_material_version", "effects-v1")
	return material

static func _soft_particles(particles: GPUParticles3D, color: Color, power: float, cooling: bool) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	particles.draw_pass_1 = quad
	var material := ShaderMaterial.new()
	material.shader = load(ROOT + "particle.gdshader") as Shader
	material.set_shader_parameter("effect_color", color)
	material.set_shader_parameter("emission_power", power)
	material.set_shader_parameter("cooling", 1.0 if cooling else 0.0)
	particles.material_override = material
	particles.set_meta("effect_material_version", "effects-v1")
