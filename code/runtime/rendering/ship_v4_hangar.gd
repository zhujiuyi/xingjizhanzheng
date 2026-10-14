class_name XJShipV4Hangar
extends "res://runtime/rendering/material_hangar.gd"
## All catalog hulls share the current material/reflection stage and new silhouettes.
const ShipFactory = preload("res://runtime/rendering/ship_v4_factory.gd")

func change_ship(definition_id: String) -> void:
	ship_def_id = definition_id
	if not _built: return
	for child: Node in _showcase.get_children():
		_showcase.remove_child(child); child.queue_free()
	var wrapper: CharacterBody3D = ShipFactory.scene(definition_id)
	if wrapper == null:
		push_error("Missing v4 exhibition ship: " + definition_id)
		return
	var visual: Node3D = wrapper.get_node("VisualRoot") as Node3D
	wrapper.remove_child(visual); wrapper.free()
	_showcase.add_child(visual)
	SurfaceStyle.apply_ship(visual)
	visual.scale *= float(_layout.showcase_length_m) / maxf(float(ShipFactory.geometry(definition_id).get("length_m", 1.0)), 1.0)
	_layer_subtree(visual)
	focus_service("")
