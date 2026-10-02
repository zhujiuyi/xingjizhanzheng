class_name XJStationVisualAdapter
extends RefCounted
## 新空间站只替换 Model；旧 wrapper 的碰撞、位置与交互锚点保持原状。

const MODEL_PATH: String = "res://assets/station_v3/station_industrial.glb"
const SHADER_PATH: String = "res://assets/station_v3/industrial_station.gdshader"
const TEXTURE_PATH: String = "res://assets/interface_v2/metal_albedo.png"

static func apply(body: StaticBody3D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if str(body.get_meta("asset_id", "")) != "asset_object_station_anchor":
		return false
	var visual: Node3D = body.get_node_or_null("VisualRoot") as Node3D
	if visual == null or not ResourceLoader.exists(MODEL_PATH):
		return false
	if visual.has_meta("station_visual_version"):
		return str(visual.get_meta("station_visual_version")) == "station-v3"
	var scene: PackedScene = load(MODEL_PATH) as PackedScene
	if scene == null:
		return false
	var replacement: Node3D = scene.instantiate() as Node3D
	if replacement == null:
		return false
	_style(replacement)
	var old_model: Node = visual.get_node_or_null("Model")
	if old_model != null:
		visual.remove_child(old_model)
		old_model.free()
	replacement.name = "Model"
	visual.add_child(replacement)
	visual.set_meta("station_visual_version", "station-v3")
	return true

static func _style(node: Node3D) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			for index: int in range(instance.mesh.get_surface_count()):
				var original: Material = instance.mesh.surface_get_material(index)
				if not original is StandardMaterial3D:
					continue
				var source: StandardMaterial3D = original as StandardMaterial3D
				if source.emission_enabled:
					# Low-power windows and docking lamps retain their PBR emissive slots.
					continue
				var material: ShaderMaterial = ShaderMaterial.new()
				material.shader = load(SHADER_PATH) as Shader
				material.set_shader_parameter("base_color", source.albedo_color)
				material.set_shader_parameter("base_metallic", source.metallic)
				material.set_shader_parameter("base_roughness", source.roughness)
				material.set_shader_parameter("metal_albedo", load(TEXTURE_PATH) as Texture2D)
				material.set_shader_parameter("has_albedo", true)
				instance.set_surface_override_material(index, material)
	for child: Node in node.get_children():
		if child is Node3D:
			_style(child as Node3D)
