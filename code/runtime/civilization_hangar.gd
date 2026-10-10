class_name XJCivilizationHangar
extends "res://runtime/station_hangar.gd"
## Extend ship preview without modifying the published strategic-window stage.
const CivilizationFactory = preload("res://runtime/visuals/civilization_visual_factory.gd")

func change_ship(definition_id: String) -> void:
	if not ResourceLoader.exists("res://assets/civilization_v1/hulls/" + definition_id + ".tscn"):
		super.change_ship(definition_id)
		return
	ship_def_id = definition_id
	if not _built: return
	for child: Node in _showcase.get_children():
		_showcase.remove_child(child); child.queue_free()
	var wrapper: CharacterBody3D = CivilizationFactory.scene(definition_id)
	if wrapper == null: push_error("Missing civilization exhibition ship: " + definition_id); return
	var visual: Node3D = wrapper.get_node("VisualRoot")
	wrapper.remove_child(visual); wrapper.free()
	_showcase.add_child(visual)
	SurfaceStyle.apply_ship(visual)
	visual.scale *= float(_layout.showcase_length_m) / maxf(float(CivilizationFactory.geometry(definition_id).get("length_m", 1.0)), 1.0)
	_layer_subtree(visual)
	focus_service("")
