extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://art-pipeline.glb")
	if scene == null:
		push_error("GLB import failed")
		quit(1)
		return
	var instance := scene.instantiate()
	var correct := true
	var expected := {"Nose": Vector3(0, 0, -2), "Up": Vector3(0, 1, 0), "Right": Vector3(1, 0, 0)}
	for marker_name: String in expected:
		var marker: Node3D = instance.find_child(marker_name, true, false)
		var matches: bool = marker != null and marker.position.is_equal_approx(expected[marker_name])
		print("AXIS ", marker_name, " ", marker.position if marker != null else "missing", " ", matches)
		correct = correct and matches
	instance.free()
	print("GLB_PIPELINE ", "PASS" if correct else "FAIL")
	quit(0 if correct else 1)
