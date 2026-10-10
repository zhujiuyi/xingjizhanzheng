extends SceneTree
const Factory = preload("res://runtime/visuals/civilization_visual_factory.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(384, 384)
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/civilization_v1/visuals.json"))
	if not definitions is Dictionary: quit(1); return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 384)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.TRANSPARENT
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.72, 0.78, 0.85)
	environment.environment.ambient_light_energy = 0.55
	viewport.add_child(environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38, -32, 0)
	key_light.light_energy = 2.3
	viewport.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-15, 140, 0)
	fill_light.light_energy = 0.8
	fill_light.light_color = Color(0.45, 0.6, 0.8)
	viewport.add_child(fill_light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 10000
	viewport.add_child(camera)
	camera.make_current()
	var count: int = 0
	for id: String in definitions:
		var model: Node3D = Factory.ship(id)
		if model == null: quit(1); return
		viewport.add_child(model)
		var geometry: Dictionary = Factory.geometry(id)
		var box: Array = geometry.collision_box_m
		var length: float = maxf(float(box[0]), maxf(float(box[1]), float(box[2])))
		camera.size = length * 1.35
		camera.position = Vector3(1.15, 0.8, 1.45) * length
		camera.look_at(Vector3.ZERO)
		for frame: int in range(12): await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		if image.is_empty() or image.get_used_rect().size.x < 50: quit(1); return
		if image.save_png(str(definitions[id].portrait_path)) != OK: quit(1); return
		count += 1
		viewport.remove_child(model); model.free()
	viewport.queue_free()
	await process_frame
	await process_frame
	print("CIVILIZATION_PORTRAITS PASS count=", count)
	quit(0 if count == 9 else 1)
