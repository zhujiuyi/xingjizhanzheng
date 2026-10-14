class_name XJSurfaceMaterials
extends RefCounted
## Independent presentation adapter. Published material, mesh and manifest bytes remain fixed.
const Meshes = preload("res://runtime/rendering/surface_meshes.gd")
const SURFACE_SHADER: Shader = preload("res://assets/materials_v1/surface.gdshader")
const MICRO_SURFACE: Texture2D = preload("res://assets/materials_v1/micro_surface.png")
const ROCK_STRATA: Texture2D = preload("res://assets/materials_v1/rock_strata.png")
const VERSION: String = "materials-v1"
const OLD_SHADERS: Array[String] = ["res://assets/ship_v3/industrial_metal.gdshader", "res://assets/station_v3/industrial_station.gdshader", "res://assets/hangar_v2/ship_metal.gdshader", "res://assets/hangar_v2/metal.gdshader"]
const ROLES: Dictionary = {"metal": 0, "steel": 1, "recess": 2, "paint": 3, "ceramic": 4, "rock": 5, "ore_metal": 6, "crystal": 7, "glass": 8, "fabric": 9, "rubber": 10, "skin": 11}
# metallic, roughness, specular, texture repeats/m, relief m, roughness variation, albedo variation
const PROFILES: Dictionary = {
	"metal": [0.92, 0.36, 0.5, 0.45, 0.0012, 0.025, 0.012],
	"steel": [0.82, 0.47, 0.5, 0.40, 0.0015, 0.025, 0.012],
	"recess": [0.48, 0.76, 0.42, 0.55, 0.001, 0.02, 0.012],
	"paint": [0.0, 0.56, 0.5, 0.65, 0.0008, 0.025, 0.015],
	"ceramic": [0.0, 0.82, 0.38, 2.1, 0.005, 0.05, 0.035],
	"rock": [0.0, 0.93, 0.28, 0.025, 0.12, 0.08, 0.40],
	"ore_metal": [0.72, 0.48, 0.5, 0.6, 0.03, 0.10, 0.08],
	"crystal": [0.0, 0.24, 0.65, 0.8, 0.004, 0.015, 0.02],
	"glass": [0.0, 0.13, 0.65, 1.3, 0.0004, 0.003, 0.005],
	"fabric": [0.0, 0.92, 0.28, 10.0, 0.001, 0.045, 0.025],
	"rubber": [0.0, 0.92, 0.28, 7.0, 0.002, 0.035, 0.02],
	"skin": [0.0, 0.72, 0.35, 8.0, 0.0003, 0.008, 0.005]
}

static func apply(root: Node3D, kind: String = "ship") -> void:
	if root == null or not is_instance_valid(root): return
	if kind == "ore": _prepare_ore(root)
	_apply_tree(root, kind)

static func _apply_tree(root: Node3D, kind: String) -> void:
	if root is MeshInstance3D: _apply_mesh(root as MeshInstance3D, kind)
	for child: Node in root.get_children():
		if child is Node3D: _apply_tree(child as Node3D, kind)

static func material(source: StandardMaterial3D, kind: String = "ship", role_hint: String = "") -> ShaderMaterial:
	if source == null or source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: return null
	var role: String = role_hint if ROLES.has(role_hint) else role_for(source, kind)
	if not ROLES.has(role): return null
	var profile: Array = PROFILES[role]
	var result := ShaderMaterial.new()
	result.resource_name = source.resource_name + "_materials_v1_" + role
	result.shader = SURFACE_SHADER
	result.set_shader_parameter("base_color", source.albedo_color)
	result.set_shader_parameter("base_metallic", float(profile[0]))
	result.set_shader_parameter("base_roughness", float(profile[1]))
	result.set_shader_parameter("base_specular", float(profile[2]))
	result.set_shader_parameter("surface_role", int(ROLES[role]))
	result.set_shader_parameter("texture_scale", float(profile[3]))
	result.set_shader_parameter("micro_relief_m", float(profile[4]))
	result.set_shader_parameter("roughness_variation", float(profile[5]))
	result.set_shader_parameter("albedo_variation", float(profile[6]))
	result.set_shader_parameter("clearcoat_amount", 0.06 if role == "paint" else 0.0)
	result.set_shader_parameter("micro_surface", MICRO_SURFACE)
	result.set_shader_parameter("rock_strata", ROCK_STRATA)
	result.set_shader_parameter("emission_color", source.emission if source.emission_enabled else Color.BLACK)
	result.set_shader_parameter("emission_strength", source.emission_energy_multiplier if source.emission_enabled else 0.0)
	result.set_shader_parameter("emission_scale", 0.18 if role == "crystal" else 1.0)
	result.set_meta("xj_materials_version", VERSION)
	result.set_meta("surface_role", role)
	result.set_meta("source_material", source)
	return result

static func role_for(source: StandardMaterial3D, kind: String = "ship") -> String:
	var title: String = source.resource_name.to_lower()
	if kind == "ore":
		if title.ends_with("_vein"): return "crystal" if source.emission_enabled else "ore_metal"
		return "rock"
	if kind == "debris": return "rock"
	# These surfaces carry functional lights or live terminal shaders.
	if "screen" in title or "window" in title or "light" in title or title.ends_with("_glow") or title.ends_with("_lamp"): return ""
	if "glass" in title or title.ends_with("_eyes"): return "glass"
	if "skin" in title: return "skin"
	if "hair" in title or title in ["crew_operations_navy", "crew_industry_orange", "crew_research_coat", "crew_supply_olive"]: return "fabric"
	if "boots" in title: return "rubber"
	if "ceramic" in title or "radiator" in title: return "ceramic"
	if "paint" in title or "safety" in title or "warning" in title or kind == "project": return "paint"
	if "recess" in title or title.ends_with("_dark"): return "recess"
	if "trim" in title or "exposed_structure" in title: return "metal"
	if "hull" in title or "plate" in title or "steel" in title or "metal" in title: return "steel"
	if kind in ["ship", "station", "gate", "wreck", "hangar", "drone", "jammer"]:
		return "steel" if source.metallic >= 0.5 else "paint"
	return ""

static func _apply_mesh(instance: MeshInstance3D, kind: String) -> void:
	if instance.mesh == null or str(instance.get_meta("xj_materials_version", "")) == VERSION: return
	var original_mesh: Mesh = instance.mesh
	var replacements: Array[Material] = []
	var sources: Array[Material] = []
	var roles: Array[String] = []
	var adapted: bool = false
	for surface: int in range(original_mesh.get_surface_count()):
		var active: Material = instance.get_active_material(surface)
		var source: StandardMaterial3D = active as StandardMaterial3D
		if active is ShaderMaterial:
			var shader: Shader = (active as ShaderMaterial).shader
			if shader == null or shader.resource_path not in OLD_SHADERS:
				replacements.append(active); sources.append(null); roles.append(str(active.get_meta("surface_role", "preserved")))
				continue
			source = original_mesh.surface_get_material(surface) as StandardMaterial3D
		var replacement: ShaderMaterial = material(source, kind)
		if replacement != null and instance.has_meta("xj_ore_mineral_color"):
			replacement.set_shader_parameter("mineral_color", instance.get_meta("xj_ore_mineral_color"))
			replacement.set_shader_parameter("mineral_amount", 1.0)
		replacements.append(replacement if replacement != null else active)
		sources.append(source)
		roles.append(str(replacement.get_meta("surface_role")) if replacement != null else "preserved")
		adapted = adapted or replacement != null
	if not adapted: return
	if original_mesh is BoxMesh:
		instance.mesh = Meshes.chamfer_box(original_mesh as BoxMesh)
		instance.set_meta("xj_chamfer_source", original_mesh)
	# A whole-mesh override wins over every surface override. Move the authored
	# material into per-surface copies before removing that precedence.
	instance.material_override = null
	for surface: int in range(replacements.size()): instance.set_surface_override_material(surface, replacements[surface])
	instance.set_meta("xj_materials_version", VERSION)
	instance.set_meta("xj_material_roles", roles)
	instance.set_meta("xj_material_sources", sources)

static func _prepare_ore(root: Node3D) -> void:
	if str(root.get_meta("xj_ore_geometry_version", "")) == VERSION: return
	var records: Array[Dictionary] = []
	_collect_ore_meshes(root, Transform3D.IDENTITY, records)
	var matrix: Dictionary = {}
	var vein: Dictionary = {}
	for record: Dictionary in records:
		var source: StandardMaterial3D = record.source
		if source == null: continue
		if source.resource_name.to_lower().ends_with("_vein"): vein = record
		elif matrix.is_empty(): matrix = record
	if matrix.is_empty(): return
	var crystal: bool = not vein.is_empty() and (vein.source as StandardMaterial3D).emission_enabled
	var body: MeshInstance3D = matrix.node
	var bounds: AABB = matrix.bounds
	if not crystal:
		var matrix_pose: Transform3D = matrix.pose
		var inverse: Transform3D = matrix_pose.affine_inverse()
		for record: Dictionary in records:
			var record_pose: Transform3D = record.pose
			var record_bounds: AABB = record.bounds
			for corner: int in range(8): bounds = bounds.expand(inverse * record_pose * record_bounds.get_endpoint(corner))
	var original_sources: Array[Dictionary] = []
	var old_surfaces: int = 0
	for record: Dictionary in records:
		var instance: MeshInstance3D = record.node
		old_surfaces += instance.mesh.get_surface_count()
		original_sources.append({"node_name": str(instance.name), "mesh": instance.mesh, "bounds": record.bounds, "pose": instance.transform, "source_material": record.source, "surface_count": instance.mesh.get_surface_count()})
		if instance == body or crystal: continue
		# Keep the old node/transform as a source anchor, with no hidden render
		# mesh. The new mother rock, rather than invisible old geometry, owns
		# all six extrema of the original aggregate visual envelope.
		instance.mesh = null
		instance.material_override = null
		instance.set_meta("xj_ore_geometry_merged", true)
	body.mesh = Meshes.irregular_ore(bounds)
	body.material_override = matrix.source
	body.set_meta("xj_ore_geometry_source", original_sources)
	body.set_meta("xj_ore_geometry_bounds", bounds)
	if not crystal and not vein.is_empty(): body.set_meta("xj_ore_mineral_color", (vein.source as StandardMaterial3D).albedo_color)
	root.set_meta("xj_ore_geometry_version", VERSION)
	root.set_meta("xj_ore_geometry_mode", "crystal_matrix" if crystal else "mineralized_rock")
	root.set_meta("xj_ore_geometry_sources", original_sources)
	root.set_meta("xj_ore_surface_count_before", old_surfaces)
	root.set_meta("xj_ore_surface_count_after", old_surfaces if crystal else 1)

static func _collect_ore_meshes(node: Node3D, pose: Transform3D, records: Array[Dictionary]) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			var source: StandardMaterial3D = instance.get_active_material(0) as StandardMaterial3D
			if source == null: source = instance.mesh.surface_get_material(0) as StandardMaterial3D
			records.append({"node": instance, "pose": pose, "bounds": instance.get_aabb(), "source": source})
	for child: Node in node.get_children():
		if child is Node3D: _collect_ore_meshes(child as Node3D, pose * (child as Node3D).transform, records)
