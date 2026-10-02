extends SceneTree
const Factory=preload("res://runtime/visuals/industrial_visual_factory.gd")
const Original=preload("res://runtime/visuals/visual_factory.gd")
const Style=preload("res://runtime/surface_style.gd")
var checks:int=0
var failures:int=0
func _initialize()->void:_run.call_deferred()
func _check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func _run()->void:
	var ids:Array=Factory.SHIPS.duplicate();ids.append("enemy_silent")
	for id:String in ids:
		var wrapper:CharacterBody3D=Factory.scene(id);var old:CharacterBody3D=Original.scene(id)
		_check(wrapper!=null and old!=null,"Load new and immutable original "+id)
		if wrapper==null or old==null:continue
		root.add_child(wrapper);root.add_child(old)
		_check(wrapper.collision_layer==old.collision_layer and wrapper.collision_mask==old.collision_mask,"Collision filter unchanged "+id)
		_check(wrapper.get_node("CollisionShape3D").shape.size==old.get_node("CollisionShape3D").shape.size,"Collision shape unchanged "+id)
		for group:String in ["Hardpoints","FXAnchors"]:
			for anchor:Node3D in old.get_node(group).get_children():
				var actual:Node3D=wrapper.get_node(group+"/"+str(anchor.name)) as Node3D
				_check(actual!=null and actual.transform==anchor.transform,"Same "+group+"/"+str(anchor.name)+" "+id)
		for name:String in ["CameraTarget","FrontCamera","InteractionAnchor"]:_check(wrapper.get_node(name).transform==old.get_node(name).transform,"Same "+name+" "+id)
		var dims:Dictionary=Factory.geometry(id);var box:AABB=AABB(Vector3.ZERO,Vector3.ZERO);var initialized:Array=[false]
		_bounds(wrapper.get_node("VisualRoot/Model"),Transform3D.IDENTITY,box,initialized)
		var captured:AABB=initialized[1]
		var limit:Vector3=Vector3(float(dims.width_m),float(dims.height_m),float(dims.length_m))*.5+Vector3.ONE*.026
		_check(captured.position.x>=-limit.x and captured.end.x<=limit.x and captured.position.y>=-limit.y and captured.end.y<=limit.y and captured.position.z>=-limit.z and captured.end.z<=limit.z,"Industrial model inside frozen envelope "+id+str(captured))
		_check(captured.size.x>=float(dims.width_m)*.82 and captured.size.y>=float(dims.height_m)*.80 and captured.size.z>=float(dims.length_m)*.82,"Reads at original ship scale "+id)
		var previous:Dictionary={};_materials(wrapper,previous);Style.apply_ship(wrapper)
		var count:int=0;var untouched:int=0
		for mesh:MeshInstance3D in previous:
			for i:int in range(mesh.mesh.get_surface_count()):
				var source:Material=previous[mesh][i];var result:Material=mesh.get_active_material(i)
				if result is ShaderMaterial:
					count+=1;var rough:float=float(result.get_shader_parameter("base_roughness"))
					_check(rough>=.65 and rough<=.90,"Matte metal "+id+" "+source.resource_name)
					_check(result.shader.resource_path.ends_with("industrial_metal.gdshader"),"Final PBR shader "+id)
				else:untouched+=1;_check(result==source,"Glass/window/glow remain authored "+id)
		_check(count>=4 and untouched>=1,"Separate metal and authored details "+id)
		var styled:Dictionary={};_materials(wrapper,styled);Style.apply_ship(wrapper)
		for mesh:MeshInstance3D in styled:
			for i:int in range(mesh.mesh.get_surface_count()):_check(mesh.get_active_material(i)==styled[mesh][i],"Style idempotent "+id)
		wrapper.queue_free();old.queue_free()
	await process_frame;await process_frame
	print("SHIP_V3_CHECKS ",checks," failures=",failures)
	quit(0 if failures==0 else 1)
func _bounds(node:Node3D,parent_transform:Transform3D,_box:AABB,result:Array)->void:
	var transform:Transform3D=parent_transform*node.transform
	if node is MeshInstance3D:
		var current:AABB=transform*(node as MeshInstance3D).get_aabb()
		if not result[0]:result[0]=true;result.append(current)
		else:
			var previous:AABB=result[1];result[1]=previous.merge(current)
	for child:Node in node.get_children():
		if child is Node3D:_bounds(child as Node3D,transform,_box,result)
func _materials(node:Node,output:Dictionary)->void:
	if node is MeshInstance3D:
		var list:Array=[]
		for i:int in range(node.mesh.get_surface_count()):list.append(node.get_active_material(i))
		output[node]=list
	for child:Node in node.get_children():_materials(child,output)
