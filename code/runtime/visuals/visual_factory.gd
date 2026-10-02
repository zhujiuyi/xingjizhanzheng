class_name XJVisualFactory
extends RefCounted
## 表现资源入口；几何尺寸是资产结构，速度/命中/伤害由调用者的数据库规则决定。

const ASSET_ROOT: String = "res://assets/models/"
const SHIPS: Array[String] = ["shuttle_swift", "frigate_lantern", "frigate_kestrel", "miner_anvil", "destroyer_raptor", "cruiser_horizon", "battleship_bastion", "transport_caravan", "support_weaver"]

static func scene(ship_id: String) -> CharacterBody3D:
	## wrapper是版本化几何权威，包含碰撞、镜头与catalog槽对应的挂点。
	var path: String = "res://assets/ships/" + ship_id + ".tscn"
	if not ResourceLoader.exists(path):
		push_error("Missing ship geometry wrapper: " + ship_id)
		return null
	return (load(path) as PackedScene).instantiate() as CharacterBody3D

static func sector(sector_id: String) -> Node3D:
	var path: String = "res://assets/sectors/" + sector_id + ".tscn"
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate() as Node3D
	return Node3D.new()

static func space_background(config: Dictionary) -> Node3D:
	return XJVisualEffects.space_background(config)

static func sound(sound_id: String) -> AudioStream:
	var path: String = "res://assets/audio/" + sound_id + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path) as AudioStream
	if sound_id.ends_with("_loop") or sound_id == "station_ambience":
		var loop_stream: AudioStreamWAV = stream.duplicate() as AudioStreamWAV
		loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop_stream.loop_begin = 0
		loop_stream.loop_end = int(loop_stream.get_length() * loop_stream.mix_rate)
		return loop_stream
	return stream

static func static_body(kind: String, id: String, parameter: String = "") -> StaticBody3D:
	var model_id: String = "station_anchor"
	match kind:
		"gate": model_id = "gate_anchor"
		"ore": model_id = _ore_model_id(parameter)
		"wreck": model_id = "wreck"
		"station": model_id = "station_anchor"
		_:
			push_error("Unknown static geometry kind: " + kind)
			return null
	var path: String = "res://assets/objects/" + model_id + ".tscn"
	if not ResourceLoader.exists(path):
		push_error("Missing static geometry wrapper: " + model_id)
		return null
	var result: StaticBody3D = (load(path) as PackedScene).instantiate() as StaticBody3D
	result.set_meta("entity_id", id)
	return result

static func enemy_scene(archetype: String = "scout") -> CharacterBody3D:
	var result: CharacterBody3D = scene(_enemy_ship_id(archetype))
	if result != null and not ("silent" in archetype or "relic" in archetype):
		_tint(result.get_node("VisualRoot") as Node3D, Color(0.44, 0.12, 0.14))
	return result

static func ship(ship_id: String, color: Color = Color.TRANSPARENT) -> Node3D:
	var result: Node3D = _load_model("ships/" + ship_id + ".glb")
	if result == null:
		result = _fallback_ship(ship_id)
	result.name = "Visual_" + ship_id
	result.set_meta("ship_def_id", ship_id)
	if color.a > 0.0:
		_tint(result, color)
	return result

static func station() -> Node3D:
	return _model_or_fallback("structures/station_anchor.glb", "Station", Vector3(250, 180, 250), Color(0.38, 0.48, 0.6))

static func gate() -> Node3D:
	return _model_or_fallback("structures/gate_anchor.glb", "Gate", Vector3(160, 160, 30), Color(0.24, 0.59, 0.68))

static func ore(kind: String = "iron") -> Node3D:
	var file_id: String = _ore_model_id(kind)
	return _model_or_fallback("environment/" + file_id + ".glb", "Ore", Vector3(40, 30, 40), Color(0.3, 0.38, 0.43))

static func wreck() -> Node3D:
	return _model_or_fallback("environment/wreck.glb", "Wreck", Vector3(16, 7, 23), Color(0.21, 0.23, 0.25))

static func enemy(template_id: String = "scout") -> Node3D:
	if "silent" in template_id or "relic" in template_id:
		return _model_or_fallback("ships/enemy_silent.glb", "Silent", Vector3(28, 20, 30), Color(0.08, 0.16, 0.2))
	return ship(_enemy_ship_id(template_id), Color(0.44, 0.12, 0.14))

static func _ore_model_id(kind: String) -> String:
	if kind in ["crystal", "conductive", "ore_conductive_crystal"]:
		return "ore_crystal"
	if kind in ["ore_echo_silica", "ore_mirror_crystal", "ore_corrosion_titanium", "ore_pressure_steel", "ore_solar_core", "ore_phase_stone"]:
		return kind
	return "ore_iron"

static func _enemy_ship_id(archetype: String) -> String:
	if "silent" in archetype or "relic" in archetype:
		return "enemy_silent"
	if archetype in SHIPS:
		return archetype
	if "raider" in archetype:
		return "destroyer_raptor"
	if "guardian" in archetype:
		return "cruiser_horizon"
	return "frigate_kestrel"

static func geometry(ship_id: String) -> Dictionary:
	var path: String = ASSET_ROOT + "geometry.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return (parsed as Dictionary).get(ship_id, {})
	return {}

static func configure(node: Node3D, profile: Dictionary) -> void:
	## 由catalog传入表现预算；此层不设游戏平衡默认值。
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child as MeshInstance3D
			if profile.has("visibility_end_m"):
				mesh.visibility_range_end = float(profile["visibility_end_m"])
			if profile.has("cast_shadows"):
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(profile["cast_shadows"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if child is Node3D:
			configure(child as Node3D, profile)

static func _load_model(relative_path: String) -> Node3D:
	var path: String = ASSET_ROOT + relative_path
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if resource is PackedScene:
		return (resource as PackedScene).instantiate() as Node3D
	return null

static func _model_or_fallback(path: String, title: String, size: Vector3, color: Color) -> Node3D:
	var result: Node3D = _load_model(path)
	if result == null:
		result = Node3D.new()
		result.add_child(_box(size, Vector3.ZERO, color))
	result.name = title
	return result

static func _fallback_ship(ship_id: String) -> Node3D:
	var placeholder_path: String = "res://assets/placeholders/" + ship_id + ".tscn"
	if ResourceLoader.exists(placeholder_path):
		var scene: PackedScene = load(placeholder_path) as PackedScene
		var temporary: Node3D = scene.instantiate() as Node3D
		var visual: Node3D = temporary.get_node("VisualRoot") as Node3D
		temporary.remove_child(visual)
		temporary.free()
		return visual
	var result: Node3D = Node3D.new()
	result.add_child(_box(Vector3(8, 4, 20), Vector3.ZERO, Color(0.3, 0.44, 0.55)))
	return result

static func _box(size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.65
	material.roughness = 0.4
	mesh.material_override = material
	return mesh

static func _tint(node: Node3D, color: Color) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child as MeshInstance3D
			for surface: int in range(mesh.mesh.get_surface_count()):
				var source: Material = mesh.get_active_material(surface)
				if source is StandardMaterial3D:
					var material: StandardMaterial3D = source.duplicate() as StandardMaterial3D
					material.albedo_color = material.albedo_color.lerp(color, 0.45)
					mesh.set_surface_override_material(surface, material)
		if child is Node3D:
			_tint(child as Node3D, color)
