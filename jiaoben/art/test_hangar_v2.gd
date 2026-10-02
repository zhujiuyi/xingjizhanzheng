extends SceneTree
const Hangar=preload("res://runtime/station_hangar.gd")
const Factory=preload("res://runtime/visuals/visual_factory.gd")
const Style=preload("res://runtime/surface_style.gd")
var checked:int=0
var failed:int=0
func _initialize()->void:_run.call_deferred()
func _check(condition:bool,label:String)->void:
	checked+=1
	if not condition:failed+=1;push_error(label)
func _run()->void:
	var hangar:Hangar=Hangar.new();hangar.configure("shuttle_swift",null);root.add_child(hangar)
	hangar.position+=Vector3(100000,6000,12000)
	await process_frame
	_check(hangar.get_camera().environment!=null,"Private camera environment")
	_check(hangar.get_camera().cull_mask==1<<19,"Private visual layer")
	var target:Vector3=hangar.to_global(Vector3(0,5,-2))
	_check((-hangar.get_camera().global_basis.z).dot((target-hangar.get_camera().global_position).normalized())>.999,"Camera framing follows translated root")
	_check(_no_physics(hangar),"Exhibition never contains collision/physics nodes")
	for role:String in ["operations","industry","research","supplies"]:
		var crew:Node3D=hangar.get_service_anchor(role)
		_check(crew!=null and crew.find_child("HeadPivot",true,false)!=null and crew.find_child("RightArmPivot",true,false)!=null,"Articulated profession "+role)
	for id:String in Factory.SHIPS:
		hangar.change_ship(id)
		var showcase:Node3D=hangar.get_node("ShipExhibition")
		_check(showcase.get_child_count()==1 and _no_physics(showcase),"Single visual-only showcase "+id)
		var model:Node3D=Factory.ship(id);root.add_child(model)
		var before:Dictionary={};_capture(model,before)
		Style.apply_ship(model)
		var metal_count:int=0;var untouched_count:int=0
		for mesh:MeshInstance3D in before.keys():
			var old:Dictionary=before[mesh]
			_check(mesh.mesh==old.mesh and mesh.transform==old.transform,"Unchanged mesh and transform "+id)
			for surface:int in range(mesh.mesh.get_surface_count()):
				var original:Material=old.materials[surface];var current:Material=mesh.get_active_material(surface)
				if original is StandardMaterial3D and (original.resource_name.ends_with("_hull") or original.resource_name.ends_with("_dark") or original.resource_name.ends_with("_trim")):
					metal_count+=1
					_check(current is ShaderMaterial and current.get_shader_parameter("base_color")==original.albedo_color,"Original faction surface color "+id)
				else:
					untouched_count+=1;_check(current==original,"Unchanged glass/emission "+id)
		_check(metal_count>0 and untouched_count>0,"Distinct hull and glass/light surfaces "+id)
		var styled:Dictionary={};_capture(model,styled);Style.apply_ship(model)
		for mesh:MeshInstance3D in styled.keys():
			for surface:int in range(mesh.mesh.get_surface_count()):_check(mesh.get_active_material(surface)==styled[mesh].materials[surface],"Idempotent style "+id)
		model.queue_free()
	hangar.queue_free();await process_frame
	print("HANGAR_V2_CHECKS ",checked," failed=",failed)
	quit(0 if failed==0 else 1)
func _no_physics(node:Node)->bool:
	if node is CollisionObject3D or node is CollisionShape3D:return false
	for child:Node in node.get_children():
		if not _no_physics(child):return false
	return true
func _capture(node:Node,output:Dictionary)->void:
	if node is MeshInstance3D:
		var materials:Array=[]
		for surface:int in range(node.mesh.get_surface_count()):materials.append(node.get_active_material(surface))
		output[node]={"mesh":node.mesh,"transform":node.transform,"materials":materials}
	for child:Node in node.get_children():_capture(child,output)
