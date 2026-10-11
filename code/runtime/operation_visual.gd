extends RefCounted
## Simple industrial jammer silhouette. Collision and HP remain authoritative NPCs.
static func generator() -> CharacterBody3D:
	var body: CharacterBody3D = CharacterBody3D.new()
	for piece: int in range(3):
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new(); box.size = Vector3(20.0 if piece == 0 else 9.0, 8.0 if piece == 0 else 16.0, 20.0 if piece == 0 else 9.0)
		mesh.mesh = box; mesh.position.y = float(piece) * 9.0
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.18,0.23,0.28) if piece != 2 else Color(0.65,0.35,0.12)
		material.metallic = 0.65; material.roughness = 0.45
		mesh.material_override = material; body.add_child(mesh)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new(); shape.size = Vector3(22,36,22)
	collision.shape = shape; collision.position.y = 10.0; body.add_child(collision)
	return body
