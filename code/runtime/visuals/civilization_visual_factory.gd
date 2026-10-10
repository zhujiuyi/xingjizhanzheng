class_name XJCivilizationVisualFactory
extends RefCounted
## Additive visual adapter; previously published industrial resource bytes stay fixed.
const Base = preload("res://runtime/visuals/industrial_visual_factory.gd")
const SHIPS = Base.SHIPS
static var _geometry: Dictionary = {}

static func scene(ship_id: String) -> CharacterBody3D:
	var model_path: String = "res://assets/civilization_v1/hulls/" + ship_id + ".tscn"
	if not ResourceLoader.exists(model_path): return Base.scene(ship_id)
	var wrapper: CharacterBody3D = (load("res://assets/ships/" + ship_id + ".tscn") as PackedScene).instantiate() as CharacterBody3D
	var visual: Node3D = wrapper.get_node("VisualRoot")
	var old: Node3D = visual.get_node("Model")
	var model: Node3D = (load(model_path) as PackedScene).instantiate() as Node3D
	model.transform = old.transform
	visual.remove_child(old); old.free()
	model.name = "Model"; visual.add_child(model)
	wrapper.set_meta("visual_asset_version", "civilization-v1")
	return wrapper

static func ship(ship_id: String, color: Color = Color.TRANSPARENT) -> Node3D:
	var path: String = "res://assets/civilization_v1/hulls/" + ship_id + ".tscn"
	if not ResourceLoader.exists(path): return Base.ship(ship_id, color)
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	model.name = "Visual_" + ship_id
	model.set_meta("ship_def_id", ship_id)
	if color.a > 0: Base._tint(model, color)
	return model

static func geometry(ship_id: String) -> Dictionary:
	if _geometry.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/civilization_v1/geometry.json"))
		if value is Dictionary: _geometry = value
	return _geometry[ship_id] if _geometry.has(ship_id) else Base.geometry(ship_id)

static func enemy_scene(archetype: String = "scout") -> CharacterBody3D: return Base.enemy_scene(archetype)
static func enemy(archetype: String = "scout") -> Node3D: return Base.enemy(archetype)
static func sector(id: String) -> Node3D: return Base.sector(id)
static func space_background(config: Dictionary) -> Node3D: return Base.space_background(config)
static func sound(id: String) -> AudioStream: return Base.sound(id)
static func static_body(kind: String, id: String, parameter: String = "") -> StaticBody3D: return Base.static_body(kind, id, parameter)
static func station() -> Node3D: return Base.station()
static func gate() -> Node3D: return Base.gate()
static func ore(kind: String = "iron") -> Node3D: return Base.ore(kind)
static func wreck() -> Node3D: return Base.wreck()
static func configure(node: Node3D, profile: Dictionary) -> void: Base.configure(node, profile)
