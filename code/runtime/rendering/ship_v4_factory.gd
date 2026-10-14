class_name XJShipV4Factory
extends RefCounted
## New silhouettes over immutable physics/anchor wrappers. No balance or save data.
const Legacy = preload("res://runtime/visuals/civilization_visual_factory.gd")
const Industrial = preload("res://runtime/visuals/industrial_visual_factory.gd")
const Surface = preload("res://runtime/surface_style.gd")
const VISUAL_ROOT: String = "res://assets/ship_v4/"
const SHIPS: Array[String] = ["shuttle_swift", "frigate_lantern", "frigate_kestrel", "miner_anvil", "destroyer_raptor", "cruiser_horizon", "battleship_bastion", "transport_caravan", "support_weaver", "cruiser_council_sentinel", "support_council_choir", "battleship_council_aegis", "destroyer_forge_hammer", "cruiser_forge_citadel", "battleship_forge_ironwall", "destroyer_roaming_spear", "cruiser_roaming_kite", "battleship_roaming_tempest"]
const VISUAL_IDS: Array[String] = ["shuttle_swift", "frigate_lantern", "frigate_kestrel", "miner_anvil", "destroyer_raptor", "cruiser_horizon", "battleship_bastion", "transport_caravan", "support_weaver", "cruiser_council_sentinel", "support_council_choir", "battleship_council_aegis", "destroyer_forge_hammer", "cruiser_forge_citadel", "battleship_forge_ironwall", "destroyer_roaming_spear", "cruiser_roaming_kite", "battleship_roaming_tempest", "enemy_silent"]

static func scene(ship_id: String) -> CharacterBody3D:
	var path: String = "res://assets/ships/" + ship_id + ".tscn"
	if ship_id not in VISUAL_IDS or not ResourceLoader.exists(path):
		push_error("Missing v4 ship wrapper: " + ship_id)
		return null
	var source: PackedScene = load(path) as PackedScene
	if source == null:
		push_error("Invalid v4 ship wrapper: " + ship_id)
		return null
	var wrapper: CharacterBody3D = source.instantiate() as CharacterBody3D
	if wrapper == null: return null
	var visual: Node3D = wrapper.get_node_or_null("VisualRoot") as Node3D
	var previous: Node3D = wrapper.get_node_or_null("VisualRoot/Model") as Node3D
	var model: Node3D = _model(ship_id)
	if visual == null or previous == null or model == null:
		if model != null: model.free()
		wrapper.free()
		push_error("Incomplete v4 ship hierarchy: " + ship_id)
		return null
	model.transform = previous.transform
	visual.remove_child(previous); previous.free()
	model.name = "Model"; visual.add_child(model)
	visual.set_meta("visual_asset_version", "ship-v4")
	wrapper.set_meta("visual_asset_version", "ship-v4")
	return wrapper

static func ship(ship_id: String, color: Color = Color.TRANSPARENT) -> Node3D:
	var model: Node3D = _model(ship_id)
	if model == null: return null
	model.name = "Visual_" + ship_id
	if color.a > 0.0: _tint(model, color)
	Surface.apply_ship(model)
	return model

static func enemy_scene(archetype: String = "scout") -> CharacterBody3D:
	var wrapper: CharacterBody3D = scene(Industrial._enemy_id(archetype))
	if wrapper != null and not ("silent" in archetype or "relic" in archetype):
		_tint(wrapper.get_node("VisualRoot") as Node3D, Color(0.44, 0.12, 0.14))
	# Sector applies the shared surface adapter after tinting, as for player hulls.
	return wrapper

static func enemy(archetype: String = "scout") -> Node3D:
	return ship(Industrial._enemy_id(archetype), Color.TRANSPARENT if "silent" in archetype or "relic" in archetype else Color(0.44, 0.12, 0.14))

static func _model(ship_id: String) -> Node3D:
	var path: String = VISUAL_ROOT + ship_id + ".glb"
	if ship_id not in VISUAL_IDS or not ResourceLoader.exists(path):
		push_error("Missing v4 hull visual: " + ship_id)
		return null
	var source: PackedScene = load(path) as PackedScene
	if source == null:
		push_error("Invalid v4 hull visual: " + ship_id)
		return null
	var model: Node3D = source.instantiate() as Node3D
	if model != null:
		model.set_meta("ship_def_id", ship_id)
		model.set_meta("visual_asset_version", "ship-v4")
	return model

static func _tint(node: Node3D, color: Color) -> void: Industrial._tint(node, color)
static func geometry(ship_id: String) -> Dictionary: return Legacy.geometry(ship_id)
static func sector(id: String) -> Node3D: return Legacy.sector(id)
static func space_background(config: Dictionary) -> Node3D: return Legacy.space_background(config)
static func sound(id: String) -> AudioStream: return Legacy.sound(id)
static func static_body(kind: String, id: String, parameter: String = "") -> StaticBody3D: return Legacy.static_body(kind, id, parameter)
static func station() -> Node3D: return Legacy.station()
static func gate() -> Node3D: return Legacy.gate()
static func ore(kind: String = "iron") -> Node3D: return Legacy.ore(kind)
static func wreck() -> Node3D: return Legacy.wreck()
static func configure(node: Node3D, profile: Dictionary) -> void: Legacy.configure(node, profile)
