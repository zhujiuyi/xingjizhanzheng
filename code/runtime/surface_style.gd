class_name XJSurfaceStyle
extends RefCounted
## Presentation-only material copies. Geometry, glass, emission and collision stay intact.
const SHADER_PATH:String="res://assets/hangar_v2/ship_metal.gdshader"
const INDUSTRIAL_SHADER_PATH:String="res://assets/ship_v3/industrial_metal.gdshader"
const TEXTURE_PATH:String="res://assets/interface_v2/metal_albedo.png"

static func apply_ship(root:Node3D)->void:
	if root==null:return
	if root is MeshInstance3D:
		var mesh:MeshInstance3D=root
		if mesh.mesh!=null and not mesh.has_meta("xj_surface_v2"):
			for surface:int in range(mesh.mesh.get_surface_count()):
				var original:Material=mesh.get_active_material(surface)
				if not original is StandardMaterial3D:continue
				var source:StandardMaterial3D=original as StandardMaterial3D
				var material_name:String=source.resource_name.to_lower()
				var industrial:bool=material_name.begins_with("v3_")
				if not (material_name.ends_with("_hull") or material_name.ends_with("_dark") or material_name.ends_with("_trim") or (industrial and (material_name.ends_with("_secondary") or material_name.ends_with("_paint")))):continue
				# Copy this surface's authored values, including enemy tint. Never apply a
				# whole-mesh material_override, which would replace glass and emitters.
				var copy:ShaderMaterial=ShaderMaterial.new()
				copy.resource_name=source.resource_name+"_surface_v2"
				copy.shader=load(INDUSTRIAL_SHADER_PATH if industrial else SHADER_PATH) as Shader
				copy.set_shader_parameter("base_color",source.albedo_color)
				copy.set_shader_parameter("base_metallic",source.metallic)
				copy.set_shader_parameter("base_roughness",source.roughness if industrial else clampf(source.roughness+.10,.28,.84))
				if ResourceLoader.exists(TEXTURE_PATH):
					copy.set_shader_parameter("metal_albedo",load(TEXTURE_PATH))
					copy.set_shader_parameter("has_albedo",true)
				mesh.set_surface_override_material(surface,copy)
			mesh.set_meta("xj_surface_v2",true)
	for child:Node in root.get_children():
		if child is Node3D:apply_ship(child as Node3D)
