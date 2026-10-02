extends SceneTree
## 把实际GLB导入几何封装为受版本控制的固定碰撞；不是运行时推导。
const ROOT_PATH: String = "res://assets/"

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var geometry_path: String = ROOT_PATH + "models/geometry.json"
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
	var assets: Dictionary = {"station_anchor": "structures", "gate_anchor": "structures", "wreck": "environment"}
	for name: String in ["ore_iron", "ore_crystal", "ore_echo_silica", "ore_mirror_crystal", "ore_corrosion_titanium", "ore_pressure_steel", "ore_solar_core", "ore_phase_stone"]:
		assets[name] = "environment"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT_PATH + "objects"))
	for name: String in assets:
		var model_path: String = ROOT_PATH + "models/" + str(assets[name]) + "/" + name + ".glb"
		var model: Node3D = (load(model_path) as PackedScene).instantiate() as Node3D
		var measured: Dictionary = _measure(model, Transform3D.IDENTITY)
		var box: AABB = measured.box
		var size: Vector3 = box.size
		var center: Vector3 = box.position + size * 0.5
		var lines: PackedStringArray = PackedStringArray([
			'[gd_scene load_steps=3 format=3]', '',
			'[ext_resource type="PackedScene" path="' + model_path + '" id="1_model"]', '',
			'[sub_resource type="BoxShape3D" id="Collision"]',
			'size = ' + _v3(Vector3(48,16,40) if name == "gate_anchor" else size), '',
			'[node name="ObjectBody" type="StaticBody3D"]',
			'collision_layer = 1', 'collision_mask = 2',
			'metadata/asset_id = "asset_object_' + name + '"',
			'metadata/asset_version = "art-full-v1"', '',
			'[node name="VisualRoot" type="Node3D" parent="."]', '',
			'[node name="Model" parent="VisualRoot" instance=ExtResource("1_model")]', '',
			'[node name="InteractionAnchor" type="Marker3D" parent="."]',
			'position = ' + _v3(center), '',
		])
		if name == "gate_anchor":
			# +Y上/-Z前。环面在XY平面，中央孔径保持畅通。
			for index: int in range(12):
				var angle: float = TAU * float(index) / 12.0
				lines.append('[node name="FrameCollision_' + str(index) + '" type="CollisionShape3D" parent="."]')
				lines.append('position = ' + _v3(Vector3(cos(angle) * 92.0, sin(angle) * 92.0, 0.0)))
				lines.append('rotation = ' + _v3(Vector3(0, 0, angle + PI * 0.5)))
				lines.append('shape = SubResource("Collision")')
				lines.append('')
		else:
			lines.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="."]')
			lines.append('position = ' + _v3(center))
			lines.append('shape = SubResource("Collision")')
		var target: String = ROOT_PATH + "objects/" + name + ".tscn"
		var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
		file.close()
		metadata[name] = {"asset_version": "art-full-v1", "wrapper_path": target,
			"bounds_m": [size.x, size.y, size.z], "bounds_center_m": [center.x, center.y, center.z],
			"collision_kind": "compound_ring_12" if name == "gate_anchor" else "box"}
		model.free()
	var output: FileAccess = FileAccess.open(geometry_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(metadata, "  ") + "\n")
	output.close()
	print("ART_STATIC_WRAPPERS_COMPLETE ", assets.size())
	quit(0)

func _measure(node: Node3D, parent_transform: Transform3D) -> Dictionary:
	var transform: Transform3D = parent_transform * node.transform
	var result: Dictionary = {"valid": false, "box": AABB()}
	if node is MeshInstance3D:
		result = {"valid": true, "box": transform * (node as MeshInstance3D).get_aabb()}
	for child: Node in node.get_children():
		if child is Node3D:
			var measured: Dictionary = _measure(child as Node3D, transform)
			if measured.valid:
				result.box = (result.box as AABB).merge(measured.box) if result.valid else measured.box
				result.valid = true
	return result

func _v3(value: Vector3) -> String:
	return "Vector3(%.8f, %.8f, %.8f)" % [value.x, value.y, value.z]
