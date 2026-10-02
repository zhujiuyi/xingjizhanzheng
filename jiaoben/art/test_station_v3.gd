extends SceneTree
## Actual imported station and immutable wrapper checks; no user database is opened.
const Adapter = preload("res://runtime/visuals/station_visual_adapter.gd")
const WRAPPER = "res://assets/objects/station_anchor.tscn"
var checked: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failed += 1
		push_error(label)

func _run() -> void:
	_check(FileAccess.get_sha256("res://data/catalog.db") == "38f9d73575a17a578884e335d1b19ee4833e490cbbd2047b2953c69dd367e25b", "Frozen catalog bytes preserved")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json")) as Dictionary
	for entry: Dictionary in legacy.resources:
		_check(FileAccess.get_sha256(str(entry.resource_path)) == str(entry.sha256), "Frozen art: " + str(entry.resource_path))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/station_v3/manifest.json")) as Dictionary
	for entry: Dictionary in manifest.resources:
		_check(FileAccess.get_sha256(str(entry.resource_path)) == str(entry.sha256), "Station resource digest: " + str(entry.resource_path))
	var body: StaticBody3D = (load(WRAPPER) as PackedScene).instantiate() as StaticBody3D
	root.add_child(body)
	body.position = Vector3(132, 56, -849)
	body.rotation = Vector3(0, 0.34, 0)
	body.collision_layer = 65
	body.collision_mask = 2
	var prior_transform: Transform3D = body.transform
	var collision: CollisionShape3D = body.get_node("CollisionShape3D") as CollisionShape3D
	var prior_shape: Shape3D = collision.shape
	var prior_anchor: Marker3D = body.get_node("InteractionAnchor") as Marker3D
	var prior_visual: Node3D = body.get_node("VisualRoot") as Node3D
	var old_model_id: int = prior_visual.get_node("Model").get_instance_id()
	_check(Adapter.apply(body), "Adapter accepts original station")
	_check(body.transform == prior_transform, "World pose unchanged")
	_check(body.collision_layer == 65 and body.collision_mask == 2, "Physical layers unchanged")
	_check(collision == body.get_node("CollisionShape3D") and collision.shape == prior_shape, "Collider instance and resource unchanged")
	_check((collision.shape as BoxShape3D).size == Vector3(440, 230, 440), "Original 440x230x440 collision box")
	_check(collision.transform == Transform3D.IDENTITY, "Collision pose unchanged")
	_check(prior_anchor == body.get_node("InteractionAnchor") and prior_anchor.transform == Transform3D.IDENTITY, "Interaction anchor unchanged")
	_check(prior_visual == body.get_node("VisualRoot") and prior_visual.transform == Transform3D.IDENTITY, "Visual root and pose unchanged")
	_check(prior_visual.get_child_count() == 1 and not is_instance_id_valid(old_model_id), "Only prior Model removed")
	var replacement: Node3D = prior_visual.get_node("Model") as Node3D
	_check(replacement != null and _no_collision(replacement), "Replacement contains no physical nodes")
	var result: Dictionary = {"bounds": AABB(), "has_bounds": false, "surfaces": 0, "shaders": 0, "emission": 0, "triangles": 0}
	_measure(replacement, Transform3D.IDENTITY, result)
	var bounds: AABB = result.bounds
	_check(bool(result.has_bounds) and bounds.position.is_finite() and bounds.end.is_finite(), "Imported GLB bounds are finite")
	_check(bounds.position.x >= -220.01 and bounds.position.y >= -115.01 and bounds.position.z >= -220.01 and bounds.end.x <= 220.01 and bounds.end.y <= 115.01 and bounds.end.z <= 220.01, "StationBoundsNoCollision: all visuals within immutable box")
	_check(bounds.size.x > 400 and bounds.size.z > 410 and bounds.size.y > 190, "Industrial silhouette has intended station scale")
	_check(int(result.surfaces) == 8 and int(result.shaders) == 6 and int(result.emission) == 2, "Shared six rough metal/coating and two emissive surfaces")
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/station_v3/geometry.json")) as Dictionary
	_check(int(result.triangles) == int(metadata.triangles), "Imported triangle count matches source metadata")
	_check(int(result.triangles) <= 100000, "Station stays under agreed presentation triangle budget")
	var model_id: int = replacement.get_instance_id()
	_check(Adapter.apply(body) and replacement.get_instance_id() == model_id, "Adapter is idempotent")
	var unrelated: StaticBody3D = StaticBody3D.new()
	_check(not Adapter.apply(unrelated) and unrelated.get_child_count() == 0, "Reject unrelated body without mutation")
	unrelated.free()
	_check(not Adapter.apply(null), "Reject missing station")
	body.queue_free()
	await process_frame
	await process_frame
	print("STATION_V3_CHECKS ", checked, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _no_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return false
	for child: Node in node.get_children():
		if not _no_collision(child):
			return false
	return true

func _measure(node: Node3D, parent_pose: Transform3D, result: Dictionary) -> void:
	var pose: Transform3D = parent_pose * node.transform
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		var local_bounds: AABB = pose * mesh.get_aabb()
		result.bounds = (result.bounds as AABB).merge(local_bounds) if bool(result.has_bounds) else local_bounds
		result.has_bounds = true
		for i: int in range(mesh.mesh.get_surface_count()):
			result.surfaces += 1
			var material: Material = mesh.get_active_material(i)
			if material is ShaderMaterial:
				result.shaders += 1
				_check(float(material.get_shader_parameter("base_roughness")) >= 0.699, "Rough industrial finish")
				_check(bool(material.get_shader_parameter("has_albedo")), "Original authored metal texture active")
			elif material is StandardMaterial3D:
				result.emission += 1 if material.emission_enabled else 0
			var arrays: Array = mesh.mesh.surface_get_arrays(i)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			result.triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	for child: Node in node.get_children():
		if child is Node3D:
			_measure(child as Node3D, pose, result)
