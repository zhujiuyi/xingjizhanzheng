class_name XJUITheme
extends RefCounted
## Presentation only: dimensions/colors below never drive gameplay.
const ICE: Color = Color("97cbd6")
const AMBER: Color = Color("dcad67")
const TEXT: Color = Color("dae1e7")
const MUTED: Color = Color("8997a4")
const COAL: Color = Color("11171e")
const MATERIAL: Shader = preload("res://runtime/ui/ui_material.gdshader")

static func font() -> SystemFont:
	var result: SystemFont = SystemFont.new()
	result.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC"])
	result.allow_system_fallback = true
	return result

static func plate() -> StyleBox:
	var texture: Texture2D = load("res://assets/interface_v2/ui_panel.svg")
	if texture != null:
		var result: StyleBoxTexture = StyleBoxTexture.new()
		result.texture = texture
		for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: result.set_texture_margin(side, 14)
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

static func button_style(tint: Color) -> StyleBox:
	var result: StyleBoxTexture = StyleBoxTexture.new()
	result.texture = load("res://assets/interface_v2/ui_button.svg")
	result.modulate_color = tint
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: result.set_texture_margin(side, 10)
	result.content_margin_left = 16
	result.content_margin_right = 16
	result.content_margin_top = 9
	result.content_margin_bottom = 9
	return result

static func create() -> Theme:
	var result: Theme = Theme.new()
	result.default_font = font()
	result.default_font_size = 15
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color("657380"))
	result.set_stylebox("normal", "Button", button_style(Color.WHITE))
	result.set_stylebox("hover", "Button", button_style(Color("a6d7e7")))
	result.set_stylebox("pressed", "Button", button_style(Color("7ab0c4")))
	result.set_stylebox("disabled", "Button", button_style(Color("686e76")))
	result.set_stylebox("focus", "Button", flat(Color.TRANSPARENT, ICE, 0))
	result.set_stylebox("panel", "PanelContainer", plate())
	for type: String in ["OptionButton", "LineEdit", "SpinBox"]:
		result.set_stylebox("normal", type, flat(Color("10171e"), Color("485864")))
		result.set_color("font_color", type, TEXT)
	result.set_stylebox("panel", "PopupMenu", plate())
	result.set_color("font_color", "PopupMenu", TEXT)
	result.set_stylebox("hover", "PopupMenu", flat(Color("253640"), ICE))
	result.set_stylebox("background", "ProgressBar", flat(Color("080d12"), Color("303d47"), 0))
	result.set_stylebox("fill", "ProgressBar", flat(ICE, ICE, 0))
	result.set_color("font_color", "ProgressBar", TEXT)
	return result

static func texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

static func decorate(panel: Control, alpha: float = 0.9) -> void:
	var detail: ColorRect = ColorRect.new()
	detail.name = "MetalSurface"
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MATERIAL
	material.set_shader_parameter("tint", Color(0.09, 0.12, 0.145, alpha))
	var metal: Texture2D = texture("res://assets/interface_v2/metal_albedo.png")
	material.set_shader_parameter("has_metal", metal != null)
	if metal != null: material.set_shader_parameter("metal_texture", metal)
	detail.material = material
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
		draw_string(face, Vector2(0, center.y + 5), "%.0f" % speed, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, XJUITheme.TEXT)
		draw_string(face, Vector2(0, center.y + 27), "m / s", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, XJUITheme.MUTED)
