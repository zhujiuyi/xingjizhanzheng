extends SceneTree
## Native source preview only; no Main, catalog writer or personal database.
const Surface = preload("res://runtime/surface_style.gd")
var stage: Node3D
var camera: Camera3D
var environment: Environment
var output: String

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for index: int in range(count): await process_frame

func _run() -> void:
	output = OS.get_environment("XJ_SHIP_V4_PREVIEW_DIRECTORY")
	if output.is_empty() or DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 900)
	stage = Node3D.new(); root.add_child(stage)
	var world := WorldEnvironment.new(); stage.add_child(world)
	environment = Environment.new(); world.environment = environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0f14")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.50,.56,.63); environment.ambient_light_energy = .28
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky := Sky.new(); var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(.19,.25,.35); sky_material.sky_horizon_color = Color(.83,.87,.94)
	sky_material.ground_bottom_color = Color(.045,.05,.065); sky_material.ground_horizon_color = Color(.39,.36,.31)
	sky.sky_material = sky_material; environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var key := DirectionalLight3D.new(); stage.add_child(key)
	key.rotation_degrees = Vector3(-44,-35,0); key.light_color = Color(.96,.97,1); key.light_energy = 2.0
	key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	var fill := DirectionalLight3D.new(); stage.add_child(fill)
	fill.rotation_degrees = Vector3(30,135,0); fill.light_color = Color(.61,.73,.89); fill.light_energy = .55
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	camera = Camera3D.new(); stage.add_child(camera); camera.current = true; camera.fov = 42
	RenderingServer.viewport_set_msaa_3d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)
	for id: String in OS.get_environment("XJ_SHIP_V4_PREVIEW_IDS").split(",",false):
		var resource: PackedScene = load("res://assets/ship_v4/" + id + ".glb") as PackedScene
		if resource == null: push_error("Missing v4 model " + id); quit(2); return
		var model: Node3D = resource.instantiate() as Node3D
		stage.add_child(model); Surface.apply_ship(model)
		var bounds := AABB()
		var first: bool = true
		for mesh: Node in model.find_children("*","MeshInstance3D",true,false):
			var box: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			bounds = box if first else bounds.merge(box); first = false
		var span: float = bounds.size.length()
		camera.near = .01; camera.far = span * 8
		for view: String in ["front", "rear", "top"]:
			var direction := Vector3(.95,.58,-1.1) if view == "front" else Vector3(-.90,.40,1.0)
			if view == "top": direction = Vector3(.001,1,.001)
			camera.position = bounds.get_center() + direction.normalized() * span * 1.45
			camera.look_at(bounds.get_center())
			await frames(8); await RenderingServer.frame_post_draw
			var path: String = output.path_join(id + "-" + view + ".png")
			var result: int = root.get_texture().get_image().save_png(path)
			if result != OK: push_error("Cannot save " + path); quit(2); return
			print("SHIP_V4_PREVIEW ",id," ",view," ",path)
		if OS.get_environment("XJ_SHIP_V4_BAKE_PORTRAITS") == "1":
			root.size = Vector2i(384,384); root.transparent_bg = true
			environment.background_color = Color.TRANSPARENT
			camera.position = bounds.get_center() + Vector3(.95,.58,-1.1).normalized() * span * 1.45
			camera.look_at(bounds.get_center())
			await frames(12); await RenderingServer.frame_post_draw
			var portrait_dir: String = "res://assets/ship_v4/portraits"
			DirAccess.make_dir_recursive_absolute(portrait_dir)
			var portrait: Image = root.get_texture().get_image()
			if portrait.is_empty() or portrait.get_used_rect().size.x < 70: push_error("Empty portrait " + id); quit(2); return
			if portrait.save_png(portrait_dir.path_join(id+".png")) != OK: quit(2); return
			print("SHIP_V4_PORTRAIT ",id)
			root.size = Vector2i(1440,900); root.transparent_bg = false
			environment.background_color = Color("0b0f14")
		model.queue_free(); await frames(3)
	environment.sky = null; stage.queue_free(); await frames(8); quit(0)
