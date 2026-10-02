extends SceneTree
## Native art inspection only; fixed framing never enters gameplay balance.
const Factory=preload("res://runtime/visuals/visual_factory.gd")
const Style=preload("res://runtime/surface_style.gd")
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var mode:String="fleet"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	root.size=Vector2i(1920,1080)
	var stage:Node3D=Node3D.new();root.add_child(stage)
	stage.add_child(Factory.space_background({"visual_seed":31.0,"nebula_color":Color(.08,.24,.35),"nebula_accent":Color(.2,.09,.27)}))
	var camera:Camera3D=Camera3D.new();camera.position=Vector3(0,0,430);camera.fov=30;camera.far=2000;stage.add_child(camera);camera.look_at(Vector3.ZERO);camera.make_current()
	for index:int in range(2):
		var light:DirectionalLight3D=DirectionalLight3D.new();light.light_energy=2.3 if index==0 else 1.0;light.light_color=Color(.8,.9,1) if index==0 else Color(1,.75,.5);light.rotation_degrees=Vector3(-30,-35,0) if index==0 else Vector3(30,140,0);stage.add_child(light)
	if mode=="fleet":
		for index:int in range(Factory.SHIPS.size()):
			var id:String=Factory.SHIPS[index];var model:Node3D=Factory.ship(id);Style.apply_ship(model)
			var geometry:Dictionary=Factory.geometry(id);model.scale=Vector3.ONE*72/maxf(float(geometry.length_m),float(geometry.width_m));model.rotation_degrees=Vector3(-28,145,-5);model.position=Vector3((index%3-1)*110,(1-floori(float(index)/3))*64,0);stage.add_child(model)
			_label(stage,id,model.position+Vector3(0,-26,45))
	else:
		for index:int in range(4):
			var id:String="enemy_silent" if index>1 else "frigate_kestrel";var model:Node3D=Factory.ship(id)
			if index%2==1:Style.apply_ship(model)
			model.scale=Vector3.ONE*85/(30 if index<2 else 28);model.rotation_degrees=Vector3(-28,145,-5);model.position=Vector3((-1 if index%2==0 else 1)*80,(1 if index<2 else -1)*50,0);stage.add_child(model)
			_label(stage,("ORIGINAL / " if index%2==0 else "SURFACE V2 / ")+id,model.position+Vector3(0,-34,45))
	for frame:int in range(100):await process_frame
	await RenderingServer.frame_post_draw
	var status:Error=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../jiaoben/tmp/art/surface_v2_"+mode+".png"))
	print("SURFACE_PREVIEW ",mode," renderer=",RenderingServer.get_current_rendering_method()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," capture=",status)
	stage.queue_free();await process_frame;quit(0 if status==OK else 1)
func _label(stage:Node3D,text:String,position:Vector3)->void:
	var label:Label3D=Label3D.new();label.text=text;label.position=position;label.font_size=32;label.pixel_size=.045;label.modulate=Color(.74,.86,.94);label.outline_size=6;stage.add_child(label)
