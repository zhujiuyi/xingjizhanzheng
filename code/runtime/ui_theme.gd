class_name XJUITheme
extends RefCounted
## Presentation only: dimensions/colors below never drive gameplay.
const ICE: Color = Color("b8c6ce")
const AMBER: Color = Color("c6a76d")
const TEXT: Color = Color("dce0e3")
const MUTED: Color = Color("91999f")
const COAL: Color = Color("101318")
const MATERIAL: Shader = preload("res://assets/interface_v3/ui_glass.gdshader")
static var FONT: FontFile = preload("res://assets/interface_v3/NotoSansCJKsc-Regular.otf")

static func font() -> FontFile:
	# A single bundled font resource is shared by Control and Label3D on both desktops.
	FONT.allow_system_fallback = false
	return FONT

static func plate() -> StyleBox:
	var texture: Texture2D = load("res://assets/interface_v3/ui_panel.svg")
	if texture != null:
		var result: StyleBoxTexture = StyleBoxTexture.new()
		result.texture = texture
		result.modulate_color = Color(0.75, 0.78, 0.81, 0.86)
		for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: result.set_texture_margin(side, 16)
		result.content_margin_left = 14
		result.content_margin_right = 14
		result.content_margin_top = 12
		result.content_margin_bottom = 12
		return result
	return flat(COAL, Color("3d4b55"))

static func flat(fill: Color, border: Color, inset: int = 10) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_content_margin_all(inset)
	return result

static func hud_panel(inset: int = 6) -> StyleBoxFlat:
	return flat(Color(0.035, 0.041, 0.049, 0.82), Color(0.24, 0.255, 0.27, 0.78), inset)

static func hud_button(active: bool = false) -> StyleBoxFlat:
	var result: StyleBoxFlat = flat(Color(0.17, 0.145, 0.095, 0.6) if active else Color(0.035, 0.042, 0.051, 0.42), Color(0.52, 0.45, 0.3, 0.72) if active else Color(0.21, 0.235, 0.25, 0.48), 3)
	result.content_margin_top = 2
	result.content_margin_bottom = 2
	return result

static func navigation_phase(phase: String) -> String:
	return str({"idle": "手动航行", "align": "正在对准", "warmup": "跃迁充能", "charging": "跃迁充能", "travel": "正在跃迁", "approach": "自动接近", "orbit": "自动环绕", "dock": "接近停靠", "arrived": "已到达", "stopped": "已停止", "cancelled": "导航中断", "failed": "导航中断"}.get(phase, "自动航行"))

static func button_style(tint: Color) -> StyleBox:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = load("res://assets/interface_v3/ui_button.svg")
	result.modulate_color = tint
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: result.set_texture_margin(side, 10)
	result.content_margin_left = 16
	result.content_margin_right = 16
	result.content_margin_top = 9
	result.content_margin_bottom = 9
	return result

static func focus_style() -> StyleBox:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = load("res://assets/interface_v3/ui_focus.svg")
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: result.set_texture_margin(side, 10)
	result.set_content_margin_all(0)
	return result

static func create() -> Theme:
	var result: Theme = Theme.new()
	result.default_font = font()
	result.default_font_size = 15
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color("687e89"))
	result.set_stylebox("normal", "Button", button_style(Color.WHITE))
	result.set_stylebox("hover", "Button", button_style(Color("c6b68d")))
	result.set_stylebox("pressed", "Button", button_style(Color("a59673")))
	result.set_stylebox("disabled", "Button", button_style(Color("686e76")))
	result.set_stylebox("focus", "Button", focus_style())
	result.set_stylebox("panel", "PanelContainer", plate())
	for type: String in ["OptionButton", "LineEdit", "SpinBox"]:
		result.set_stylebox("normal", type, flat(Color("0b1822"), Color("4b6c7b")))
		result.set_stylebox("focus", type, focus_style())
		result.set_color("font_color", type, TEXT)
	result.set_icon("arrow", "OptionButton", texture("res://assets/interface_v3/ui_chevron.svg"))
	result.set_color("caret_color", "LineEdit", ICE)
	result.set_color("selection_color", "LineEdit", Color("28516a"))
	result.set_stylebox("panel", "PopupMenu", plate())
	result.set_color("font_color", "PopupMenu", TEXT)
	result.set_stylebox("hover", "PopupMenu", flat(Color("253640"), ICE))
	result.set_stylebox("background", "ProgressBar", flat(Color("080d12"), Color("303d47"), 0))
	result.set_stylebox("fill", "ProgressBar", flat(ICE, ICE, 0))
	result.set_color("font_color", "ProgressBar", TEXT)
	result.set_stylebox("slider", "HSlider", flat(Color("0a151c"), Color("345665"), 0))
	result.set_stylebox("grabber_area", "HSlider", flat(Color("285666"), Color("527d8d"), 0))
	result.set_stylebox("grabber_area_highlight", "HSlider", flat(Color("347687"), ICE, 0))
	result.set_stylebox("focus", "HSlider", focus_style())
	var handle: Texture2D = texture("res://assets/interface_v3/ui_slider_handle.svg")
	result.set_icon("grabber", "HSlider", handle)
	result.set_icon("grabber_highlight", "HSlider", handle)
	result.set_icon("grabber_disabled", "HSlider", handle)
	return result

static func texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

static func decorate(panel: Control, alpha: float = 0.9) -> void:
	var detail: ColorRect = ColorRect.new()
	detail.name = "GlassSurface"
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MATERIAL
	material.set_shader_parameter("tint", Color(0.035, 0.041, 0.049, alpha * 0.27))
	detail.material = material
	detail.resized.connect(func(): material.set_shader_parameter("panel_size", detail.size))
	panel.add_child(detail)
	panel.move_child(detail, 0)

class Dial extends Control:
	var speed: float = 0.0
	var ratios: Vector3 = Vector3.ONE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center: Vector2 = size * Vector2(0.5, 0.56)
		var radius: float = minf(size.x * 0.43, size.y * 0.44)
		for index: int in range(3):
			var r: float = radius - index * 7.0
			draw_arc(center, r, PI * 0.85, PI * 2.15, 60, Color("293640"), 3.0, true)
			draw_arc(center, r, PI * 0.85, PI * (0.85 + 1.3 * clampf(ratios[index], 0, 1)), 60, [XJUITheme.ICE, XJUITheme.AMBER, Color("a3b2bf")][index], 3.0, true)
		for index: int in range(15):
			var angle: float = PI * (0.85 + float(index) / 14.0 * 1.3)
			var direction: Vector2 = Vector2(cos(angle), sin(angle))
			draw_line(center + direction * (radius + 5), center + direction * (radius + (10 if index % 2 == 0 else 7)), Color("536470"), 1.0, true)
		var face: Font = get_theme_default_font()
		var small: bool = size.x < 90
		draw_string(face, Vector2(0, center.y + 4), "%.0f" % speed, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17 if small else 28, XJUITheme.TEXT)
		draw_string(face, Vector2(0, center.y + (15 if small else 27)), "m / s", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8 if small else 11, XJUITheme.MUTED)
