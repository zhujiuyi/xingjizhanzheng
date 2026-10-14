class_name XJMaterialHangar
extends "res://runtime/civilization_hangar.gd"
## Additive stage adapter; the signed strategic-window/hangar implementation is untouched.
const Materials = preload("res://runtime/rendering/surface_materials.gd")
const REFLECTION_CAPTURE_LAYER: int = 1 << 18
var _neutral_sky: Sky
var _room_sky: Sky
var _material_quality: String = "high"

func _exit_tree() -> void:
	# Detach this stage's private rendering resources before the viewport/world
	# tears down. Resource-owned RIDs remain owned by their Godot resources.
	if is_instance_valid(_camera) and _camera.environment != null:
		var environment: Environment = _camera.environment
		_camera.environment = null
		environment.sky = null
	_neutral_sky = null
	_room_sky = null

func _ready() -> void:
	super._ready()
	if not _built: return
	if is_instance_valid(_window_mesh):
		_window_mesh.set_meta("materials_reflection_static", true)
		_window_mesh.layers = HANGAR_LAYER | REFLECTION_CAPTURE_LAYER
	_configure_room_reflections()
	set_visual_quality(_material_quality)

func _model(id: String) -> Node3D:
	var model: Node3D = super._model(id)
	Materials.apply(model, "crew" if id.begins_with("crew_") else "hangar")
	if id == "hangar_environment": _mark_static(model)
	return model

func _apply_environment_metal(node: Node3D) -> void:
	Materials.apply(node, "hangar")

func _layer_subtree(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = HANGAR_LAYER | REFLECTION_CAPTURE_LAYER if bool(node.get_meta("materials_reflection_static", false)) else HANGAR_LAYER
	for child: Node in node.get_children(): _layer_subtree(child)

func _mark_static(node: Node) -> void:
	if node is MeshInstance3D: node.set_meta("materials_reflection_static", true)
	for child: Node in node.get_children(): _mark_static(child)

func _camera_environment() -> Environment:
	var environment: Environment = super._camera_environment()
	environment.ambient_light_color = Color(0.35, 0.38, 0.40)
	environment.ambient_light_energy = 0.32
	environment.glow_intensity = 0.20
	# The cheap neutral sky stays available when low quality disables the
	# room probe. The camera still draws its original solid-color background.
	var neutral := ProceduralSkyMaterial.new()
	neutral.sky_top_color = Color(0.18, 0.20, 0.22)
	neutral.sky_horizon_color = Color(0.46, 0.48, 0.50)
	neutral.ground_bottom_color = Color(0.055, 0.060, 0.065)
	neutral.ground_horizon_color = Color(0.26, 0.28, 0.30)
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.sky_material = neutral
	_neutral_sky = sky
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	return environment

func _build_lighting() -> void:
	super._build_lighting()
	for child: Node in get_children():
		if child is DirectionalLight3D:
			var light: DirectionalLight3D = child as DirectionalLight3D
			light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
			light.light_color = Color(0.95, 0.97, 1.0) if light.name == "ExhibitionKey" else Color(0.70, 0.73, 0.77)
			if light.name != "ExhibitionKey": light.light_energy = 0.40
		elif child is OmniLight3D:
			var light: OmniLight3D = child as OmniLight3D
			light.light_color = Color(0.76, 0.85, 0.91) if light.position.z < 0 else Color(0.90, 0.86, 0.78)
			light.light_energy = 2.0

func _configure_room_reflections() -> void:
	# The locked Godot 4.7.2 renderer leaks its reflection-atlas textures
	# (upstream #122498). Use an offline capture of these exact static room
	# meshes instead of allocating a live ReflectionProbe. No dynamic hull,
	# crew or service drone is present in the captured layer.
	_room_sky = Sky.new()
	_room_sky.radiance_size = Sky.RADIANCE_SIZE_256
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials_v1/hangar_reflection.gdshader")
	material.set_shader_parameter("room_map", preload("res://assets/materials_v1/hangar_reflection.res"))
	_room_sky.sky_material = material

func set_visual_quality(quality: String) -> void:
	_material_quality = quality
	if is_instance_valid(_camera) and _camera.environment != null:
		_camera.environment.sky = _neutral_sky if quality == "low" or _room_sky == null else _room_sky
		_camera.environment.ssao_enabled = quality == "high"
		_camera.environment.glow_enabled = quality != "low"
