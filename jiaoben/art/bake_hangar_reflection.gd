extends SceneTree
## Offline capture of the real static room. No reflection-atlas allocation.
class CaptureHangar:
	extends "res://runtime/rendering/material_hangar.gd"
	func _configure_room_reflections() -> void: pass
	func set_visual_quality(_quality: String) -> void: pass
	func _camera_environment() -> Environment:
		var result := Environment.new()
		result.background_mode = Environment.BG_COLOR
		result.background_color = Color(.015,.02,.025)
		result.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		result.ambient_light_color = Color(.35,.38,.40); result.ambient_light_energy = .32
		result.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		var sky := Sky.new(); var material := ProceduralSkyMaterial.new()
		material.sky_top_color = Color(.18,.20,.22); material.sky_horizon_color = Color(.46,.48,.50)
		material.ground_bottom_color = Color(.055,.060,.065); material.ground_horizon_color = Color(.26,.28,.30)
		sky.sky_material = material; result.sky = sky
		result.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		return result

func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for index: int in range(count): await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	var hangar := CaptureHangar.new(); root.add_child(hangar)
	for light: Node in hangar.find_children("*", "Light3D", true, false): light.layers |= 1 << 18
	var viewport := SubViewport.new(); viewport.size = Vector2i(256,256)
	viewport.world_3d = root.world_3d; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new(); viewport.add_child(camera)
	camera.fov = 90; camera.near = .1; camera.far = 200; camera.cull_mask = 1 << 18
	camera.environment = hangar.get_camera().environment; camera.make_current()
	camera.global_position = hangar.to_global(Vector3(0,8,-2))
	var directions: Array[Vector3] = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	var images: Array[Image] = []
	var output: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/hangar-reflection-bake")
	DirAccess.make_dir_recursive_absolute(output)
	for index: int in range(6):
		var up: Vector3 = Vector3.FORWARD if index == 2 else Vector3.BACK if index == 3 else Vector3.UP
		camera.look_at(camera.global_position + directions[index],up)
		await frames(12); await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		if image.is_empty(): quit(2); return
		image.convert(Image.FORMAT_RGB8); image.save_png(output.path_join("face_"+str(index)+".png"))
		image.generate_mipmaps(); images.append(image)
	var cube := Cubemap.new()
	if cube.create_from_images(images) != OK: quit(2); return
	if ResourceSaver.save(cube,"res://assets/materials_v1/hangar_reflection.res") != OK: quit(2); return
	print("HANGAR_REFLECTION_BAKE PASS faces=6 size=256 static_layer=18 origin=(0,8,-2)")
	camera.environment = null; viewport.queue_free(); hangar.queue_free(); await frames(12); quit(0)
