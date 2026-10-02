extends SceneTree
## Native font and skin validation, isolated from gameplay and production saves.
const UISkin = preload("res://runtime/ui_theme.gd")
const Hangar = preload("res://runtime/station_hangar.gd")
var checked: int = 0
var failed: int = 0
var captures: int = 0
var hangar: Node3D
var canvas: CanvasLayer
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checked += 1
	if not value: failed += 1
	print(("PASS " if value else "FAIL ") + label)
func label(parent: Node, text: String, size: int = 16) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", size)
	parent.add_child(result)
	return result
func _run() -> void:
	var font: FontFile = UISkin.font()
	check(font.resource_path == "res://assets/interface_v3/NotoSansCJKsc-Regular.otf", "font is bundled SC OTF")
	check(font.get_font_name() == "Noto Sans CJK SC", "font family is official simplified Chinese family")
	check(not font.allow_system_fallback and font.fallbacks.is_empty(), "no OS or unregistered fallback masks missing glyphs")
	check(UISkin.font() == font and UISkin.create().default_font == font, "Theme and callers share one FontFile")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../jiaoben/logs/font-v3-glyph-report.json"))
	var missing: Array[int] = []
	for value: Variant in report.required_codepoints:
		if not font.has_char(int(value)): missing.append(int(value))
	check(missing.is_empty() and report.missing.is_empty() and report.encoding_defects.is_empty(), "all source/catalog CJK and common symbols supported by imported font")
	if not missing.is_empty(): print("MISSING_GLYPHS ", missing)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/interface_v3/manifest.json"))
	check(manifest.resources.size() == 9, "registered pack contains nine source resources")
	for entry: Dictionary in manifest.resources:
		check(FileAccess.get_sha256(entry.path) == entry.sha256, "source hash " + str(entry.id))
	for asset: String in ["ui_panel.svg", "ui_button.svg", "ui_focus.svg", "ui_chevron.svg", "ui_slider_handle.svg", "ui_glass.gdshader"]:
		check(ResourceLoader.exists("res://assets/interface_v3/" + asset), "resource imported " + asset)
	hangar = Hangar.new()
	hangar.configure("shuttle_swift", null)
	root.add_child(hangar)
	await process_frame
	hangar.get_camera().make_current()
	for role: String in ["operations", "supplies", "industry", "research"]:
		var title: Label3D = hangar.get_service_anchor(role).find_child("ProfessionLabel", true, false)
		check(title.font == font, "Label3D shares exact UI font " + role)
	canvas = CanvasLayer.new()
	root.add_child(canvas)
	for size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = size
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_size = Vector2i(Vector2(size) / scale)
			_build_sheet(report, font)
			await capture("skin-%dx%d-%dpercent" % [size.x, size.y, int(scale * 100)])
	canvas.hide()
	hangar.focus_service("operations")
	for frame: int in range(120): await process_frame
	await capture("profession-label-1280x720")
	canvas.queue_free(); hangar.queue_free()
	await process_frame; await process_frame
	print("FONT_THEME_V3_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failed == 0 else "FAIL", checked, failed, captures])
	quit(0 if failed == 0 else 1)
func _build_sheet(report: Dictionary, font: FontFile) -> void:
	for old: Node in canvas.get_children(): canvas.remove_child(old); old.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	margin.theme = UISkin.create()
	canvas.add_child(margin)
	var frame := PanelContainer.new()
	margin.add_child(frame)
	UISkin.decorate(frame, .52)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	frame.add_child(layout)
	label(layout, "星际战舰  /  断航远征", 26)
	label(layout, "舰况 · 护盾 / 装甲 / 结构　任务 · 采矿 · 保存与读取　距离 1,250 m · × 12 · Ⅰ / Ⅱ / Ⅲ", 14)
	var controls := HBoxContainer.new()
	layout.add_child(controls)
	var button := Button.new()
	button.text = "继续航行"; button.custom_minimum_size = Vector2(132, 38); controls.add_child(button); button.grab_focus()
	var disabled := Button.new()
	disabled.text = "需停靠空间站"; disabled.disabled = true; controls.add_child(disabled)
	var select := OptionButton.new()
	select.add_item("任务与合同"); controls.add_child(select)
	var slider := HSlider.new()
	slider.min_value = 0; slider.max_value = 1; slider.value = .6; slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 24; layout.add_child(slider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var grid := VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(grid)
	label(grid, "源码与数值库字形样本（字体自身覆盖，禁止系统回退）", 14)
	var text := ""
	for value: Variant in report.required_codepoints:
		if int(value) >= 0x2000: text += String.chr(int(value)) + " "
	label(grid, text, 18).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check(margin.theme.default_font == font, "resized sheet retains bundled FontFile")
func capture(name: String) -> void:
	for frame: int in range(10): await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../jiaoben/logs/font-v3-" + name + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "capture " + name)
	captures += 1
