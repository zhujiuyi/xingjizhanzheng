extends SceneTree
const Hangar=preload("res://runtime/station_hangar.gd")
const Catalog=preload("res://runtime/data/catalog.gd")
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1440,900)
	var mode:String="overview";var ship_id:String="shuttle_swift"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
		if arg.begins_with("--ship="):ship_id=arg.trim_prefix("--ship=")
	var catalog:Catalog=Catalog.new();catalog.open()
	var metal:Texture2D=load("res://assets/interface_v2/metal_albedo.png") as Texture2D
	print("HANGAR_TEXTURE_MIPMAPS ",metal.get_image().has_mipmaps())
	var hangar:Hangar=Hangar.new();hangar.configure(ship_id,catalog);root.add_child(hangar)
	hangar.get_camera().make_current()
	if mode!="overview":hangar.focus_service(mode)
	var draw_sum:int=0;var frame_sum:float=0
	for frame in range(150):
		await process_frame
		if frame>60:draw_sum+=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));frame_sum+=float(Performance.get_monitor(Performance.TIME_PROCESS))
	await RenderingServer.frame_post_draw
	var path:String=ProjectSettings.globalize_path("res://../jiaoben/tmp/art/hangar_v2_"+ship_id+"_"+mode+".png")
	var error:Error=root.get_texture().get_image().save_png(path)
	print("HANGAR_PREVIEW ",ship_id," ",mode," renderer=",RenderingServer.get_current_rendering_method()," draw_calls=",draw_sum/89," process_ms=",frame_sum/89*1000," capture=",error)
	print("HANGAR_CAMERA ",hangar.get_camera().position," target_root=",hangar.position)
	hangar.queue_free();await process_frame;catalog.close();quit(0 if error==OK else 1)
