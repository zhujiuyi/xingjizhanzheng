extends SceneTree
## Native Godot station material preview, deliberately isolated from player progress.
const Adapter = preload("res://runtime/visuals/station_visual_adapter.gd")
var stage: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	stage = Node3D.new()
	root.add_child(stage)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var panorama: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/navigation_v3/space_panorama.png") as Texture2D
	panorama.energy_multiplier = 0.65
	sky.sky_material = panorama
	environment.environment.sky = sky
	environment.environment.sky_rotation = Vector3(0, float(absi("sector_anchor".hash()) % 1000) / 1000.0 * TAU, 0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.38, 0.4, 0.43)
	environment.environment.ambient_light_energy = 0.7
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	stage.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_color = Color(1, 0.96, 0.89)
	sun.light_energy = 2.0
	stage.add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30, 140, 0)
	fill.light_color = Color(0.57, 0.65, 0.71)
	fill.light_energy = 0.65
	stage.add_child(fill)
	var body: StaticBody3D = (load("res://assets/objects/station_anchor.tscn") as PackedScene).instantiate() as StaticBody3D
	stage.add_child(body)
	if not Adapter.apply(body):
		push_error("Station preview adapter failed")
		quit(1)
		return
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(325, 250, 490)
	camera.fov = 48
	camera.far = 5000
	camera.look_at(Vector3(0, 5, 0))
	camera.make_current()
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/station-v3/station-native-three-quarter.png")
	var error: Error = root.get_texture().get_image().save_png(output)
	print("STATION_V3_NATIVE_PREVIEW path=", output, " error=", error)
	camera.position = Vector3(0, 45, 580)
	camera.look_at(Vector3(0, 5, 0))
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	output = ProjectSettings.globalize_path("res://../jiaoben/tmp/station-v3/station-native-front.png")
	error = root.get_texture().get_image().save_png(output)
	print("STATION_V3_NATIVE_PREVIEW path=", output, " error=", error)
	stage.queue_free()
	await process_frame
	await process_frame
	quit(0 if error == OK else 1)
