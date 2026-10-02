extends SceneTree
## Source/native-scale art QA. Original PNG files are never modified.
const DIRECTORY := "res://assets/interface_v2/"
var timeout_guard: SceneTreeTimer

func _initialize() -> void:
	timeout_guard = create_timer(15.0)
	timeout_guard.timeout.connect(func(): print("INTERFACE_ART_QA FAIL timeout"); quit(1))
	call_deferred("_run")

func _texture(filename: String) -> ImageTexture:
	var original := Image.load_from_file(ProjectSettings.globalize_path(DIRECTORY + filename))
	if original == null or original.is_empty():
		push_error("Missing generated source: " + filename)
		quit(1)
		return null
	return ImageTexture.create_from_image(original)

func _rect(texture: Texture2D, parent: Node, position: Vector2, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(rect)
	rect.position = position
	rect.size = size
	return rect

func _repeat_grid(texture: Texture2D, parent: Node, position: Vector2, cell_size: float) -> void:
	for index in range(9):
		_rect(texture, parent, position + Vector2(index % 3, index / 3) * cell_size, Vector2.ONE * cell_size)

func _label(text: String, parent: Node, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func _edge_difference(image: Image, horizontal: bool) -> float:
	var count: int = image.get_height() if horizontal else image.get_width()
	var error := 0.0
	for index in range(count):
		var a: Color = image.get_pixel(0, index) if horizontal else image.get_pixel(index, 0)
		var b: Color = image.get_pixel(image.get_width() - 1, index) if horizontal else image.get_pixel(index, image.get_height() - 1)
		error += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
	return error / count

func _run() -> void:
	root.size = Vector2i(1280, 960)
	var screen := Control.new()
	root.add_child(screen)
	var backdrop := ColorRect.new()
	backdrop.color = Color("0a0e13")
	backdrop.size = Vector2(1280, 960)
	screen.add_child(backdrop)
	var metal := _texture("metal_albedo.png")
	var portraits := _texture("npc_portraits.png")
	var title := _texture("title_background.png")
	if metal == null or portraits == null or title == null: return
	_label("GENERATED SOURCE QA · 3x3 REPEAT / 128px PORTRAITS", screen, Vector2(24, 12), 22)
	_repeat_grid(metal, screen, Vector2(24, 58), 128.0)
	var roles := ["STATION TRAFFIC", "QUARTERMASTER", "INDUSTRIAL ENGINEER", "RESEARCH OFFICER"]
	for index in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = portraits
		atlas.region = Rect2((index % 2) * 627, (index / 2) * 627, 627, 627)
		atlas.filter_clip = true
		_rect(atlas, screen, Vector2(448 + index * 192, 86), Vector2(128, 128))
		_label(roles[index], screen, Vector2(448 + index * 192, 228), 16)
	_label("Original files preserved · UI text stays engine-native", screen, Vector2(448, 280), 20)
	_label("Title image: approximately 16:9 · dark left menu safe area", screen, Vector2(448, 312), 20)
	_rect(title, screen, Vector2(24, 472), Vector2(854, 480))
	_label("星际战舰", screen, Vector2(62, 542), 44)
	_label("继续航行\n新建档案\n设置\n退出", screen, Vector2(62, 626), 24)
	var native_repeat := SubViewport.new()
	native_repeat.size = Vector2i(3762, 3762)
	native_repeat.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(native_repeat)
	_repeat_grid(metal, native_repeat, Vector2.ZERO, 1254.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var preview_path := ProjectSettings.globalize_path("res://../jiaoben/tmp/interface-v2-native-scale.png")
	var repeat_path := ProjectSettings.globalize_path("res://../jiaoben/tmp/interface-v2-repeat-3x3.png")
	var preview := root.get_texture().get_image()
	var tiled := native_repeat.get_texture().get_image()
	if preview == null or tiled == null or preview.is_empty() or tiled.is_empty():
		push_error("Art QA rendering returned an empty capture")
		quit(1)
		return
	if preview.save_png(preview_path) != OK or tiled.save_png(repeat_path) != OK:
		push_error("Art QA preview save failed")
		quit(1)
		return
	var source := metal.get_image()
	print("INTERFACE_ART_QA ", JSON.stringify({"preview": preview_path, "repeat_3x3": repeat_path,
		"metal_edge_rgb_mae_horizontal": _edge_difference(source, true),
		"metal_edge_rgb_mae_vertical": _edge_difference(source, false),
		"atlas_regions": [[0,0,627,627],[627,0,627,627],[0,627,627,627],[627,627,627,627]],
		"original_images_edited": false}))
	native_repeat.queue_free()
	screen.queue_free()
	await process_frame
	print("INTERFACE_ART_QA PASS source dimensions and rendered previews only; context approval is separate")
	quit(0)
