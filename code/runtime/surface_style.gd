class_name XJSurfaceStyle
extends RefCounted
## Public presentation API. The signed visual factories and original assets stay unchanged.
const Materials = preload("res://runtime/rendering/surface_materials.gd")

static func apply_ship(root: Node3D) -> void:
	Materials.apply(root, "ship")

static func apply_object(root: Node3D, kind: String) -> void:
	Materials.apply(root, kind)
