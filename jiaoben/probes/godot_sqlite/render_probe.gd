extends Node3D
## Small fixed test fixture; these are not gameplay parameters.

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.012, 0.018, 0.035)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.5, 0.6, 0.8)
	world.environment.ambient_light_energy = 0.5
	world.environment.glow_enabled = true
	add_child(world)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 2, 10)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 35, 0)
	add_child(light)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.3
	ring.mesh = torus
	ring.rotation_degrees.x = 90
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.05, 0.7, 0.9)
	glow.emission_enabled = true
	glow.emission = Color(0.04, 0.55, 0.95)
	glow.emission_energy_multiplier = 4.0
	ring.material_override = glow
	add_child(ring)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	add_child(box)
	var particles := GPUParticles3D.new()
	particles.amount = 128
	particles.lifetime = 2.0
	particles.draw_pass_1 = SphereMesh.new()
	particles.draw_pass_1.radius = 0.03
	particles.draw_pass_1.height = 0.06
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 180
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 1.2
	process.gravity = Vector3.ZERO
	particles.process_material = process
	particles.material_override = glow
	add_child(particles)
	for frame in range(90):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("STARSHIP_PROBE_OUTPUT")
	var status := get_viewport().get_texture().get_image().save_png(output)
	print("RENDER_METHOD ", RenderingServer.get_current_rendering_method())
	print("RENDER_CAPTURE ", status)
	get_tree().quit(0 if status == OK else 1)
