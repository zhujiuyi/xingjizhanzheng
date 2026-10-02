extends SceneTree
## 离线视觉验收夹具；布光、排版与显示缩放只用于截图，不是运行数值。
const FACTORY: Script = preload("res://runtime/visuals/visual_factory.gd")
const EFFECTS: Script = preload("res://runtime/visuals/visual_effects.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mode: String = "fleet"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
	root.size = Vector2i(1920, 1080)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	world.add_child(FACTORY.space_background({"visual_seed": 31.0, "nebula_color": Color(0.08, 0.24, 0.35), "nebula_accent": Color(0.2, 0.09, 0.27)}))
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 30.0
	camera.position = Vector3(0, 0, 430)
	camera.far = 2000.0
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	for index: int in range(2):
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.light_energy = 2.3 if index == 0 else 1.0
		light.light_color = Color(0.8, 0.9, 1.0) if index == 0 else Color(1.0, 0.75, 0.5)
		light.rotation_degrees = Vector3(-30, -35, 0) if index == 0 else Vector3(30, 140, 0)
		world.add_child(light)
	if mode == "fleet":
		var names: Array[String] = ["雨燕 · 穿梭器", "提灯 · 探索护卫舰", "游隼 · 战斗护卫舰", "铁砧 · 采矿舰", "矛隼 · 驱逐舰", "远际 · 巡洋舰", "磐垒 · 战列舰", "长旅 · 运输舰", "织桥 · 支援舰"]
		for index: int in range(FACTORY.SHIPS.size()):
			var ship_id: String = FACTORY.SHIPS[index]
			var model: Node3D = FACTORY.ship(ship_id)
			var geometry: Dictionary = FACTORY.geometry(ship_id)
			var size: float = maxf(float(geometry["length_m"]), float(geometry["width_m"]))
			model.scale = Vector3.ONE * 72.0 / size
			model.rotation_degrees = Vector3(-28, 145, -5)
			model.position = Vector3((index % 3 - 1) * 110, (1 - floori(float(index) / 3.0)) * 64, 0)
			world.add_child(model)
			_label(world, names[index], model.position + Vector3(0, -26, 45))
	elif mode == "effects":
		var config: Dictionary = {}
		var db: Object = ClassDB.instantiate("SQLite")
		db.path = "res://data/catalog.db"
		db.read_only = true
		db.verbosity_level = 0
		db.open_db()
		db.query("SELECT * FROM presentation_defs")
		for entry: Dictionary in db.query_result:
			config[entry.presentation_id] = entry.value_integer if entry.value_integer != null else entry.value_real
		db.close_db()
		var ship: Node3D = FACTORY.ship("frigate_kestrel")
		ship.position = Vector3(-110, 0, 0)
		ship.scale = Vector3.ONE * 2.0
		ship.rotation_degrees = Vector3(-20, 145, 0)
		world.add_child(ship)
		var shield: Node3D = EFFECTS.shield(37.0, Color(0.1,0.6,1.0), config)
		shield.position = ship.position
		shield.set_process(false)
		world.add_child(shield)
		shield.set("duration_s", 0.0) # 只冻结验收夹具显示时长，运行时仍用DB周期。
		var beam: Node3D = EFFECTS.beam(Vector3(-78,10,40), Vector3(60,-10,0), Color(1.0,0.3,0.05), config)
		beam.set_process(false)
		world.add_child(beam)
		beam.set("duration_s", 0.0)
		var explosion: Node3D = EFFECTS.explosion(Vector3(110,0,0), 32.0, Color(1.0,0.5,0.08), config)
		explosion.set_process(false)
		world.add_child(explosion)
		explosion.set("duration_s", 0.0)
		_label(world, "护盾命中 · 半透明网格", Vector3(-110,-50,45))
		_label(world, "定向光束", Vector3(0,-50,45))
		_label(world, "爆炸 · 原创粒子", Vector3(110,-50,45))
		await create_timer(0.45).timeout
		(explosion.get_child(0) as GPUParticles3D).speed_scale = 0.0
	else:
		var items: Array[Node3D] = [FACTORY.station(), FACTORY.gate(), FACTORY.ore("iron"), FACTORY.ore("crystal"), FACTORY.wreck(), FACTORY.enemy("silent")]
		var sizes: Array[float] = [440.0, 210.0, 60.0, 60.0, 23.0, 30.0]
		var names: Array[String] = ["轨道站 · 环形港", "锚定虫洞门", "铁硅矿", "导能晶体", "舰船残骸", "静默遗构 · 无人舰"]
		for index: int in range(items.size()):
			var model: Node3D = items[index]
			model.scale = Vector3.ONE * 65.0 / sizes[index]
			model.rotation_degrees = Vector3(20, 35, 0)
			if index == 1:
				var hole: Node3D = EFFECTS.wormhole(80.0, Color(0.1,0.6,1.0), {"fx_wormhole_intensity": 2.2})
				model.add_child(hole)
			model.position = Vector3((index % 3 - 1) * 110, (0.5 - floori(float(index) / 3.0)) * 90, 0)
			world.add_child(model)
			_label(world, names[index], model.position + Vector3(0, -37, 45))
	for frame: int in range(70):
		await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("STARSHIP_ART_OUTPUT")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://../jiaoben/tmp/art/" + mode + ".png")
	var status: Error = root.get_texture().get_image().save_png(output)
	print("ART_PREVIEW ", mode, " ", RenderingServer.get_current_rendering_method(), " capture=", status)
	quit(0 if status == OK else 1)

func _label(parent: Node3D, text: String, position: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC"])
	label.font = font
	label.font_size = 44
	label.pixel_size = 0.045
	label.modulate = Color(0.75, 0.86, 0.97)
	label.outline_size = 8
	label.position = position
	parent.add_child(label)
