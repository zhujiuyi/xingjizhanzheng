class_name XJUITheme
extends RefCounted
## Presentation tokens only; gameplay values remain in the catalog.
const ICE: Color = Color("86b8ca")
const AMBER: Color = Color("c6a76d")
const DANGER: Color = Color("db827b")
const TEXT: Color = Color("dce2e5")
const MUTED: Color = Color("9ba7af")
const COAL: Color = Color("101418")
const SURFACE: Color = Color("171d23")
const BORDER: Color = Color("39444d")
const GAP: int = 8
const SECTION_GAP: int = 16
static var FONT: FontFile = preload("res://assets/interface_v3/NotoSansCJKsc-Regular.otf")

static func font() -> FontFile:
	FONT.allow_system_fallback = false
	return FONT

static func flat(fill: Color, border: Color, inset: int = 8) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_content_margin_all(inset)
	return result

static func plate() -> StyleBoxFlat:
	return panel_style()

static func panel_style(inset: int = 12) -> StyleBoxFlat:
	return flat(Color(COAL, 0.96), BORDER, inset)

static func table_header(inset: int = 8) -> StyleBoxFlat:
	return flat(SURFACE, BORDER, inset)

static func table_row(alternate: bool = false, inset: int = 8) -> StyleBoxFlat:
	var result := flat(Color("151b21") if alternate else COAL, BORDER, inset)
	result.border_width_top = 0
	result.border_width_left = 0
	result.border_width_right = 0
	return result

static func input_style(read_only: bool = false, inset: int = 8) -> StyleBoxFlat:
	return flat(COAL if read_only else Color("0c1014"), BORDER, inset)

static func hud_panel(inset: int = 8) -> StyleBoxFlat:
	return flat(Color(COAL, 0.88), Color(BORDER, 0.85), inset)

static func button_surface(role: String = "default", state: String = "normal", compact: bool = false, active: bool = false) -> StyleBoxFlat:
	var accent: Color = DANGER if role == "danger" else AMBER if role == "primary" or active else ICE
	var emphasized: bool = role in ["primary", "danger"] or active
	var fill: Color = COAL.lerp(accent, 0.14) if emphasized else SURFACE
	var edge: Color = accent.darkened(0.25) if emphasized else BORDER
	if state == "hover":
		fill = fill.lerp(accent, 0.12)
		edge = accent
	elif state in ["pressed", "hover_pressed"]:
		fill = fill.lerp(accent, 0.22)
		edge = accent
	elif state == "disabled":
		fill = COAL
		edge = BORDER.darkened(0.18)
	var result := flat(fill, edge, 8 if compact else 12)
	result.content_margin_top = 4 if compact else 8
	result.content_margin_bottom = 4 if compact else 8
	return result

static func hud_button(active: bool = false) -> StyleBoxFlat:
	return button_surface("filter", "normal", true, active)

static func button_style(tint: Color) -> StyleBoxFlat:
	return button_surface("primary" if tint.r > tint.b * 1.2 else "default")

static func focus_style() -> StyleBoxFlat:
	var result := flat(Color.TRANSPARENT, ICE, 0)
	result.draw_center = false
	return result

static func apply_button(button: Button, role: String = "default", compact: bool = false, active: bool = false) -> void:
	button.set_meta("ui_role", role)
	if role == "filter": button.autowrap_mode = TextServer.AUTOWRAP_OFF
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, button_surface(role, state, compact, active))
	button.add_theme_stylebox_override("focus", focus_style())
	var foreground: Color = DANGER if role == "danger" else AMBER if role == "primary" or active else MUTED if role == "secondary" else TEXT
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		button.add_theme_color_override(key, foreground)
	button.add_theme_color_override("font_disabled_color", Color("77848d"))
	button.add_theme_color_override("icon_disabled_color", Color("77848d"))

static func navigation_phase(phase: String) -> String:
	return str({"idle": "手动航行", "align": "正在对准", "warmup": "跃迁充能", "charging": "跃迁充能", "travel": "正在跃迁", "approach": "自动接近", "orbit": "自动环绕", "dock": "接近停靠", "arrived": "已到达", "stopped": "已停止", "cancelled": "导航中断", "failed": "导航中断"}.get(phase, "自动航行"))

static func apply_toolbar_button(button: Button, active: bool = false) -> void:
	apply_button(button, "filter", true, active)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var surface: StyleBoxFlat = button.get_theme_stylebox(state)
		surface.set_content_margin_all(2)
		if state == "normal" and not active:
			surface.bg_color = Color.TRANSPARENT
			surface.border_color = Color.TRANSPARENT

static func glyph(kind: String, color: Color = ICE) -> Texture2D:
	var shapes: Dictionary = {"check": '<rect x="2.5" y="2.5" width="11" height="11"/><path d="m5 8 2 2 4-5"/>', "box": '<rect x="2.5" y="2.5" width="11" height="11"/>', "radio": '<circle cx="8" cy="8" r="5.5"/>', "radio_on": '<circle cx="8" cy="8" r="5.5"/><circle cx="8" cy="8" r="2.5" fill="currentColor"/>', "arrow": '<path d="m4 6 4 4 4-4"/>', "up": '<path d="m4 10 4-4 4 4"/>', "updown": '<path d="m4 6 4-4 4 4m-8 4 4 4 4-4"/>', "handle": '<rect x="4.5" y="2.5" width="7" height="11" fill="currentColor"/>', "clear": '<path d="m4 4 8 8m0-8-8 8"/>'}
	var source: String = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><g fill="none" stroke="#%s" color="#%s" stroke-width="1.6">%s</g></svg>' % [color.to_html(false), color.to_html(false), shapes.get(kind, shapes.box)]
	var raster := Image.new()
	if raster.load_svg_from_string(source) != OK: return null
	return ImageTexture.create_from_image(raster)

static func create() -> Theme:
	var result := Theme.new()
	result.default_font = font()
	result.default_font_size = 15
	result.set_color("font_color", "Label", TEXT)
	for type: String in ["HBoxContainer", "VBoxContainer"]: result.set_constant("separation", type, GAP)
	for type: String in ["GridContainer", "HFlowContainer", "VFlowContainer"]:
		result.set_constant("h_separation", type, GAP)
		result.set_constant("v_separation", type, GAP)
	for type: String in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			result.set_stylebox(state, type, button_surface("default", state, type in ["CheckBox", "CheckButton"]))
		result.set_stylebox("focus", type, focus_style())
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: result.set_color(key, type, TEXT)
		result.set_color("font_disabled_color", type, Color("77848d"))
		result.set_color("icon_normal_color", type, ICE)
		result.set_color("icon_disabled_color", type, MUTED)
		result.set_constant("h_separation", type, GAP)
	result.set_stylebox("panel", "PanelContainer", plate())
	result.set_icon("arrow", "OptionButton", glyph("arrow"))
	for type: String in ["LineEdit", "TextEdit", "CodeEdit"]:
		result.set_stylebox("normal", type, input_style())
		result.set_stylebox("read_only", type, input_style(true))
		result.set_stylebox("focus", type, focus_style())
		result.set_color("font_color", type, TEXT)
		result.set_color("font_uneditable_color", type, MUTED)
		result.set_color("font_placeholder_color", type, MUTED)
		result.set_color("caret_color", type, ICE)
		result.set_color("selection_color", type, Color("29434f"))
	result.set_icon("clear", "LineEdit", glyph("clear", MUTED))
	result.set_icon("updown", "SpinBox", glyph("updown"))
	result.set_constant("buttons_width", "SpinBox", 16)
	result.set_constant("field_and_buttons_separation", "SpinBox", 0)
	for direction: String in ["up", "down"]:
		for state: String in ["", "_hover", "_pressed", "_disabled"]:
			result.set_icon(direction + state, "SpinBox", glyph("up" if direction == "up" else "arrow", MUTED if state == "_disabled" else ICE))
			result.set_color(direction + state + "_icon_modulate", "SpinBox", Color.WHITE)
		for state: String in ["", "_hovered", "_pressed", "_disabled"]:
			var surface := button_surface("default", "hover" if state == "_hovered" else "pressed" if state == "_pressed" else "disabled" if state == "_disabled" else "normal", true)
			surface.set_content_margin_all(0)
			result.set_stylebox(direction + "_background" + state, "SpinBox", surface)
	result.set_stylebox("field_and_buttons_separator", "SpinBox", StyleBoxEmpty.new())
	result.set_stylebox("up_down_buttons_separator", "SpinBox", StyleBoxEmpty.new())
	for type: String in ["CheckBox", "CheckButton", "PopupMenu"]:
		for key: String in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "radio_checked", "radio_unchecked", "radio_checked_disabled", "radio_unchecked_disabled"]:
			var kind: String = ("radio_on" if "checked" in key and not "unchecked" in key else "radio") if key.begins_with("radio") else "box" if "unchecked" in key else "check"
			result.set_icon(key, type, glyph(kind, MUTED if "disabled" in key else ICE))
	result.set_stylebox("panel", "PopupMenu", plate())
	result.set_stylebox("hover", "PopupMenu", button_surface("default", "hover", true))
	result.set_color("font_color", "PopupMenu", TEXT)
	result.set_color("font_hover_color", "PopupMenu", TEXT)
	result.set_color("font_disabled_color", "PopupMenu", MUTED)
	result.set_stylebox("panel", "PopupPanel", plate())
	result.set_stylebox("panel", "TooltipPanel", panel_style(8))
	result.set_color("font_color", "TooltipLabel", TEXT)
	result.set_font_size("font_size", "TooltipLabel", 13)
	for type: String in ["HSeparator", "VSeparator"]:
		var line := flat(Color.TRANSPARENT, BORDER, 0)
		line.draw_center = false
		line.set_border_width_all(0)
		if type == "HSeparator": line.border_width_top = 1
		else: line.border_width_left = 1
		result.set_stylebox("separator", type, line)
		result.set_constant("separation", type, GAP)
	for type: String in ["HScrollBar", "VScrollBar"]:
		result.set_stylebox("scroll", type, flat(Color("0c1014"), COAL, 5))
		result.set_stylebox("scroll_focus", type, focus_style())
		for key: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
			result.set_stylebox(key, type, flat(ICE.darkened(0.45) if key == "grabber" else ICE.darkened(0.15), Color.TRANSPARENT, 5))
		for key: String in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]: result.set_icon(key, type, ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)))
	for type: String in ["TabBar", "TabContainer"]:
		for key: String in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]:
			result.set_stylebox(key, type, focus_style() if key == "tab_focus" else button_surface("filter", "disabled" if key == "tab_disabled" else "hover" if key == "tab_hovered" else "normal", false, key == "tab_selected"))
		result.set_color("font_selected_color", type, AMBER)
		result.set_color("font_unselected_color", type, MUTED)
		result.set_color("font_hovered_color", type, TEXT)
		result.set_color("font_disabled_color", type, MUTED)
	result.set_stylebox("panel", "TabContainer", panel_style())
	result.set_stylebox("background", "ProgressBar", flat(Color("080c10"), BORDER, 0))
	result.set_stylebox("fill", "ProgressBar", flat(ICE, ICE, 0))
	result.set_color("font_color", "ProgressBar", TEXT)
	for type: String in ["HSlider", "VSlider"]:
		result.set_stylebox("slider", type, flat(COAL, BORDER, 2))
		result.set_stylebox("grabber_area", type, flat(ICE.darkened(0.5), ICE.darkened(0.5), 2))
		result.set_stylebox("grabber_area_highlight", type, flat(ICE.darkened(0.25), ICE, 2))
		result.set_stylebox("focus", type, focus_style())
		for key: String in ["grabber", "grabber_highlight", "grabber_disabled"]: result.set_icon(key, type, glyph("handle", MUTED if key == "grabber_disabled" else ICE))
	return result

static func texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

static func decorate(_panel: Control, _alpha: float = 0.9) -> void:
	# Kept as an API for HUD callers; flat surfaces need no overlay node.
	pass

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
			draw_arc(center, r, PI * 0.85, PI * 2.15, 60, XJUITheme.BORDER, 3.0, true)
			draw_arc(center, r, PI * 0.85, PI * (0.85 + 1.3 * clampf(ratios[index], 0, 1)), 60, [XJUITheme.ICE, XJUITheme.AMBER, XJUITheme.TEXT][index], 3.0, true)
		var face: Font = get_theme_default_font()
		var small: bool = size.x < 90
		var speed_text: PackedStringArray = XJSpaceUnits.speed(speed).split(" ")
		draw_string(face, Vector2(0, center.y + 4), speed_text[0], HORIZONTAL_ALIGNMENT_CENTER, size.x, 17 if small else 28, XJUITheme.TEXT)
		draw_string(face, Vector2(0, center.y + (15 if small else 27)), speed_text[1] if speed_text.size() > 1 else "", HORIZONTAL_ALIGNMENT_CENTER, size.x, 10 if small else 11, XJUITheme.MUTED)
