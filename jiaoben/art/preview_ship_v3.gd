extends SceneTree
const Factory=preload("res://runtime/visuals/industrial_visual_factory.gd")
const Style=preload("res://runtime/surface_style.gd")
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var id:String="shuttle_swift";var view:String="hero"
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="):id=arg.trim_prefix("--ship=")
		if arg.begins_with("--view="):view=arg.trim_prefix("--view=")
	root.size=Vector2i(1600,1000)
	var stage:Node3D=Node3D.new();root.add_child(stage)
	var space:Node3D=Factory.space_background({"visual_seed":39.,"nebula_color":Color(.022,.028,.033),"nebula_accent":Color(.038,.033,.026)});stage.add_child(space)
	var world_env:WorldEnvironment=space.get_child(0) as WorldEnvironment;world_env.environment.ambient_light_color=Color(.38,.40,.43)
	var panorama:PanoramaSkyMaterial=PanoramaSkyMaterial.new();panorama.panorama=load("res://assets/navigation_v3/space_panorama.png");panorama.energy_multiplier=.65;world_env.environment.sky.sky_material=panorama
	var model:Node3D=Factory.ship(id);stage.add_child(model);Style.apply_ship(model)
	var dims:Dictionary=Factory.geometry(id);var length_m:float=float(dims.length_m)
	var camera:Camera3D=Camera3D.new();camera.fov=38;camera.position=Vector3(length_m*.78,length_m*.48,length_m*.95 if view=="rear" else -length_m*.95);camera.far=length_m*10;stage.add_child(camera);camera.look_at(Vector3.ZERO);camera.make_current()
	for index:int in range(2):
		var light:DirectionalLight3D=DirectionalLight3D.new();light.light_energy=2.0 if index==0 else .65;light.light_color=Color(1.,.96,.89) if index==0 else Color(.57,.65,.71);light.rotation_degrees=Vector3(-35,-30,0) if index==0 else Vector3(30,140,0);light.shadow_enabled=index==0;light.directional_shadow_max_distance=length_m*3.;stage.add_child(light)
	var draw_sum:float=0.;var process_sum:float=0.
	for frame:int in range(100):
		await process_frame
		if frame>=40:draw_sum+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME);process_sum+=Performance.get_monitor(Performance.TIME_PROCESS)
	await RenderingServer.frame_post_draw
	var status:Error=root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../jiaoben/tmp/art/ship_v3_"+id+"_"+view+".png"))
	print("SHIP_V3_HERO ",id," view=",view," renderer=",RenderingServer.get_current_rendering_method()," draw_calls_avg=",draw_sum/60.," process_ms_avg=",process_sum/60.*1000.," capture=",status)
	stage.queue_free();await process_frame;quit(0 if status==OK else 1)
