extends RefCounted
## Decorative construction attachments; original collision and damage stay authoritative.
const Materials = preload("res://runtime/rendering/surface_materials.gd")
const Meshes = preload("res://runtime/rendering/surface_meshes.gd")
static func refresh(world: Node,game: RefCounted) -> void:
	if not game.projects.supported():return
	for def: Dictionary in game.rows("construction_project_defs"):
		var target: Variant=world.targets.get(def.station_id,{}).get("node")
		if not is_instance_valid(target):continue
		var row: RefCounted=game.projects.instance(def.project_id)
		if row==null:continue
		var completed: int=3 if row.phase=="completed" else row.stage_index-1
		var owned: bool=game.projects.owned(def.project_id)
		var signature: String="%d:%s" % [completed,str(owned)]
		if target.get_meta("project_visual_signature","")==signature:continue
		target.set_meta("project_visual_signature",signature)
		var previous: Node=target.get_node_or_null("ProjectUpgrades")
		if previous!=null:target.remove_child(previous);previous.queue_free()
		var root: Node3D=Node3D.new();root.name="ProjectUpgrades";target.add_child(root)
		for stage: int in range(completed):
			var mesh: MeshInstance3D=MeshInstance3D.new();var shape: BoxMesh=BoxMesh.new()
			shape.size=Vector3(80.0,20.0+stage*10.0,28.0);mesh.mesh=Meshes.chamfer_box(shape)
			mesh.position=Vector3((stage-1)*95.0,70.0,-100.0)
			var material: StandardMaterial3D=StandardMaterial3D.new()
			material.albedo_color=Color("4b8494") if owned else Color("695747");material.metallic=0.7;material.roughness=0.5
			material.emission_enabled=true;material.emission=Color("286b79") if owned else Color("5a3324");material.emission_energy_multiplier=0.3
			mesh.material_override=Materials.material(material,"project","paint");root.add_child(mesh)
		root.set_meta("completed_stages",completed)
