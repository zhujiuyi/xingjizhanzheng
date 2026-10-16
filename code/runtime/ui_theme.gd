class_name XJUITheme
extends RefCounted
## Presentation tokens only; gameplay values remain in the catalog.
##
## Colour semantics are deliberate, not decorative:
##   AMBER  one meaning - current/selected, and the single primary action on a screen.
##   WARN   blocked, short of materials, exposure, low reserve, a negative figure.
##   GAIN   income, repair, friendly. Always paired with a shape or a word.
##   DANGER irreversible action, hostile, real failure.
## An earlier revision let AMBER carry all seven of those at once, which is why the
## interface read as noise: one accent cannot mean everything.
const ICE: Color = Color("86b8ca")
const AMBER: Color = Color("c6a76d")
const WARN: Color = Color("d98a3c")
const GAIN: Color = Color("74b39a")
const DANGER: Color = Color("db827b")
const TEXT: Color = Color("dce2e5")
const MUTED: Color = Color("9ba7af")
const COAL: Color = Color("101418")
const SURFACE: Color = Color("171d23")
const BORDER: Color = Color("39444d")
const GAP: int = 8
const SECTION_GAP: int = 16

## Shield / armour / structure are one instrument family, so they share a cold
## grey-blue ramp instead of borrowing the accent colour. Using AMBER for the
## armour layer was one of the ways the accent lost its meaning.
const LAYER_SERIES: Array[Color] = [ICE, Color("a6b2be"), Color("6f7d88")]

## Type scale. Six steps, one of them for Latin/digit data. Hierarchy is carried
## by weight; the size steps only jump where the change must be obvious. The set
## previously used 13 sizes between 9 and 22 px, with 13 and 14 both heavy - a
## one-pixel difference that no reader can see but that made every screen uneven.
const SIZE_DISPLAY: int = 28
const SIZE_PAGE: int = 20
const SIZE_SECTION: int = 15
const SIZE_BODY: int = 13
const SIZE_DATA: int = 13
const SIZE_NOTE: int = 11
const TEXT_ROLES: Dictionary = {
	"display": {"size": 28, "medium": true},
	"page": {"size": 20, "medium": true},
	"section": {"size": 15, "medium": true},
	# A heading inside a table or a compact HUD panel: same weight as "section",
	# no extra size, because the surrounding rows already set the rhythm.
	"subhead": {"size": 13, "medium": true},
	"body": {"size": 13, "medium": false},
	"data": {"size": 13, "medium": false},
	"note": {"size": 11, "medium": false},
}

static var FONT: FontFile = preload("res://assets/interface_v3/NotoSansCJKsc-Regular.otf")
static var FONT_MEDIUM: FontFile = preload("res://assets/interface_v3/NotoSansCJKsc-Medium.otf")

static func font() -> FontFile:
	FONT.allow_system_fallback = false
	return FONT

static func font_medium() -> FontFile:
	FONT_MEDIUM.allow_system_fallback = false
	return FONT_MEDIUM

## Applies one of TEXT_ROLES to a label. Panels should not hand-write font sizes:
## that is how the previous thirteen-step scale accumulated.
static func apply_text_style(label: Label, role: String = "body") -> void:
	var spec: Dictionary = TEXT_ROLES.get(role, TEXT_ROLES.body)
	label.add_theme_font_size_override("font_size", int(spec.size))
	if bool(spec.medium):
		label.add_theme_font_override("font", font_medium())
	else:
		label.remove_theme_font_override("font")

static func text_size(role: String) -> int:
	return int(TEXT_ROLES.get(role, TEXT_ROLES.body).size)

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

## A panel floating over the 3D scene is a backing, not a container. No border and no
## title bar: just enough dark fill for the text on it to stay readable over whatever
## the scene happens to be. Panels on an opaque page keep their edge - see
## panel_style() - because there the border carries the grouping that a scene no
## longer does. Drawing a bordered box on top of a scene made the HUD read as a stack
## of windows rather than as an instrument panel.
static func hud_panel(inset: int = 8) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(COAL, 0.68)
	result.set_content_margin_all(inset)
	return result

## A hit target that is invisible until it is used. The equipment slot draws its own
## circle, so a persistent button surface put a square tile around every round slot -
## precisely the shape the slot rule removes. Only feedback appears, and only while the
## pointer is on it, so the resting state is a circle and nothing else. The four states
## still differ from each other: a control that cannot show it was pressed is not
## interactive, it is decoration.
static func slot_hit(state: String = "normal") -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.set_content_margin_all(1)
	match state:
		"hover": result.bg_color = Color(ICE, 0.10)
		"pressed": result.bg_color = Color(AMBER, 0.18)
		"hover_pressed": result.bg_color = Color(AMBER, 0.26)
		"disabled": result.bg_color = Color(COAL, 0.34)
		_: result.bg_color = Color(0, 0, 0, 0)
	return result

static func apply_slot_hit(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, slot_hit(state))

## A borderless chip for a compact aggregate, such as "empty slots x 10". It is one
## count standing for many sockets rather than a socket, so it stays a rectangle - but
## a rectangle with no edge, so it does not reintroduce the boxes this revision removes.
static func chip(state: String = "normal") -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.set_content_margin_all(6)
	match state:
		"hover": result.bg_color = Color(COAL, 0.5).lerp(ICE, 0.12)
		"pressed": result.bg_color = Color(COAL, 0.5).lerp(AMBER, 0.18)
		"hover_pressed": result.bg_color = Color(COAL, 0.5).lerp(AMBER, 0.24)
		"disabled": result.bg_color = Color(COAL, 0.34)
		_: result.bg_color = Color(COAL, 0.5)
	return result

## A backing for a dense list rather than for a few labels. World markers and the scene
## are drawn before the panels, so the lighter fill lets them show through: over a
## sentence that reads as depth, over a column of numbers it reads as a stray mark that
## belongs to the list and is not in it. Measured, not guessed - a marker behind the
## overview came through at about half brightness, which is legible noise.
static func hud_list_panel(inset: int = 8) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(COAL, 0.9)
	result.set_content_margin_all(inset)
	return result

static func apply_chip(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, chip(state))

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
	result.default_font_size = SIZE_BODY
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

## Shared instrument geometry. Every ring in the interface - a slot's cycle, a target's
## range, the ship's own gauges - starts at the same angle, turns the same way and draws
## its backing at the same weight. A ring that started somewhere else or drew its
## backing darker was one of the ways the old HUD looked assembled from parts rather
## than designed.
const RING_START: float = -PI * 0.5
const RING_SWEEP: float = TAU
const RING_WIDTH: float = 3.0
const RING_WIDTH_COMPACT: float = 2.0
const RING_BACKING: float = 0.4
## A ring's own gap from its neighbour, so two rings never touch.
const RING_STEP: float = 7.0

## One backing arc plus one value arc. `start`/`sweep` are parameters because the speed
## gauge is a gauge, not a progress ring: it deliberately leaves a gap at the bottom for
## the number to sit in. Everything else uses the defaults, which is a full circle from
## the top going clockwise.
static func draw_arc_meter(canvas: CanvasItem, center: Vector2, radius: float, ratio: float, color: Color, width: float = RING_WIDTH, start: float = RING_START, sweep: float = RING_SWEEP) -> void:
	if radius <= 0.0: return
	canvas.draw_arc(center, radius, start, start + sweep, 64, Color(BORDER, RING_BACKING), width, true)
	if ratio <= 0.0: return
	canvas.draw_arc(center, radius, start, start + sweep * clampf(ratio, 0.0, 1.0), 64, color, width, true)

## Splits "650 m" / "0.019 AU" / "0.0 m/s" into a value and a unit so they can be drawn
## as two lines. Presentation only: both halves come from the string the game already
## produced, so nothing here decides scale, precision or rounding.
static func split_value_unit(text: String) -> Array[String]:
	var parts: PackedStringArray = text.split(" ", false)
	if parts.size() < 2: return [text, ""]
	var unit: String = ""
	for index: int in range(1, parts.size()):
		unit += (" " if not unit.is_empty() else "") + parts[index]
	return [parts[0], unit]

## The two-line readout: the value carries, the unit only names it.
static func draw_value_unit(canvas: CanvasItem, center: Vector2, width: float, value: String, unit: String, value_size: int = SIZE_PAGE, unit_size: int = SIZE_NOTE) -> void:
	var face: Font = font_medium()
	var value_y: float = center.y + value_size * 0.36
	canvas.draw_string(face, Vector2(center.x - width * 0.5, value_y), value, HORIZONTAL_ALIGNMENT_CENTER, width, value_size, TEXT)
	if unit.is_empty(): return
	canvas.draw_string(font(), Vector2(center.x - width * 0.5, value_y + unit_size + 1.0), unit, HORIZONTAL_ALIGNMENT_CENTER, width, unit_size, MUTED)

## Draws a texture clipped to a circle. Clipping is done by drawing the texture as a
## polygon whose UVs trace the circle, so no mask texture and no shader is needed and
## the widget adds nothing to the presentation manifests. The texture's central square
## is used, which keeps a non-square portrait from stretching.
static func draw_portrait(canvas: CanvasItem, center: Vector2, radius: float, texture: Texture2D, segments: int = 32) -> void:
	if texture == null or radius <= 0.0: return
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0: return
	var half_uv: Vector2 = Vector2(minf(tex_size.x, tex_size.y) / tex_size.x, minf(tex_size.x, tex_size.y) / tex_size.y) * 0.5
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		points.append(center + direction * radius)
		uvs.append(Vector2(0.5, 0.5) + Vector2(direction.x * half_uv.x, direction.y * half_uv.y))
		colors.append(Color.WHITE)
	canvas.draw_polygon(points, colors, uvs, texture)

## The ship's hero instrument: the number that matters in the middle, the state of the
## hull it is flying around it. The three rings are shield, armour and structure, held
## as Ring objects so the interface reads the same values the arcs draw rather than
## keeping a second copy of them.
class Dial extends Control:
	var speed: float = 0.0
	var rings: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if rings.is_empty():
			for index: int in range(3):
				var ring := XJUITheme.Ring.new()
				ring.color = XJUITheme.LAYER_SERIES[index]
				rings.append(ring)

	func _draw() -> void:
		var center: Vector2 = size * Vector2(0.5, 0.56)
		var radius: float = minf(size.x * 0.43, size.y * 0.44)
		# A gauge, not a progress ring: the 1.3 pi sweep leaves the bottom open for the
		# number. Everything else in the interface uses the full-circle default.
		var start: float = PI * 0.85
		var sweep: float = PI * 1.3
		for index: int in range(mini(rings.size(), 3)):
			var ring: XJUITheme.Ring = rings[index]
			XJUITheme.draw_arc_meter(self, center, radius - index * XJUITheme.RING_STEP, ring.ratio(), ring.color, XJUITheme.RING_WIDTH, start, sweep)
		var small: bool = size.x < 90
		var parts: Array[String] = XJUITheme.split_value_unit(XJSpaceUnits.speed(speed))
		var value_size: int = 17 if small else 28
		var unit_size: int = 10 if small else 11
		var face: Font = XJUITheme.font_medium()
		draw_string(face, Vector2(0, center.y + value_size * 0.3), parts[0], HORIZONTAL_ALIGNMENT_CENTER, size.x, value_size, XJUITheme.TEXT)
		if not parts[1].is_empty():
			draw_string(XJUITheme.font(), Vector2(0, center.y + value_size * 0.3 + unit_size + 2.0), parts[1], HORIZONTAL_ALIGNMENT_CENTER, size.x, unit_size, XJUITheme.MUTED)

## A stack of concentric rings over one centre, with an optional two-line caption inside.
## The value is the arc; the caption only repeats the number the outer world already
## knows, so a meter never invents a figure of its own.
## One measured value on a ring, separate from the widget that draws it. The interface
## reads the same value the arc shows - a tooltip, a caption, a state colour - so the
## number lives here rather than being derived twice from two different sources.
class Ring extends RefCounted:
	var value: float = 0.0
	var max_value: float = 1.0
	var color: Color = XJUITheme.ICE

	func ratio() -> float:
		return clampf(value / maxf(max_value, 0.001), 0.0, 1.0)

class RingMeter extends Control:
	## Outer first.
	var rings: Array = []
	var caption: String = ""
	var unit: String = ""
	var compact: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var width: float = XJUITheme.RING_WIDTH_COMPACT if compact else XJUITheme.RING_WIDTH
		var step: float = width + XJUITheme.RING_STEP - XJUITheme.RING_WIDTH
		var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
		var outer: float = minf(size.x, size.y) * 0.5 - width
		for index: int in range(rings.size()):
			var ring: XJUITheme.Ring = rings[index]
			XJUITheme.draw_arc_meter(self, center, outer - index * step, ring.ratio(), ring.color, width)
		if not caption.is_empty():
			XJUITheme.draw_value_unit(self, center, size.x, caption, unit)

## One equipment slot as a circle: a dark disc, the module's portrait clipped to it, and
## a static rim. Replaces the tile that traced its own rectangular perimeter, which is
## the shape rule this revision removes.
##
## The rim carries no value. A slot's cycle is drawn by RingArc in its own node, because
## the cycle must be able to disappear while the slot stays: an idle module is a visible
## slot with nothing to count down.
class CircularSlot extends Control:
	var portrait: Texture2D = null
	var empty: bool = false
	var compact: bool = false
	## Turned off while a state badge replaces the portrait, so the badge is readable
	## without also hiding the disc and rim that say a module is fitted here.
	var show_portrait: bool = true
	## The rim is the only thing that says "fitted and switched on" now that the tile
	## behind the circle is gone, so the slot's own state lives here.
	var rim: Color = Color(XJUITheme.BORDER, XJUITheme.RING_BACKING)
	var hover: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var width: float = XJUITheme.RING_WIDTH_COMPACT if compact else XJUITheme.RING_WIDTH
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		var face_radius: float = radius - width
		if face_radius <= 0.0: return
		draw_circle(center, face_radius, Color(XJUITheme.COAL, 0.92))
		if empty:
			# An empty socket, drawn as a dim inner ring: it says "nothing fitted here"
			# without a glyph that could be mistaken for a module mark.
			draw_arc(center, face_radius * 0.45, 0.0, TAU, 24, Color(XJUITheme.BORDER, 0.7), 1.0, true)
		elif show_portrait:
			XJUITheme.draw_portrait(self, center, face_radius, portrait)
		var edge: Color = rim.lerp(XJUITheme.TEXT, 0.35) if hover else rim
		draw_arc(center, radius - width * 0.5, 0.0, TAU, 48, edge, width, true)

## The value of a ring, on its own so it can be shown and hidden independently of the
## thing it circles. Carries the same value/max_value pair the bar used before, so the
## displayed arc is still the database cycle against the real remaining seconds.
class RingArc extends Control:
	var value: float = 0.0
	var max_value: float = 1.0
	var tint: Color = XJUITheme.ICE
	var compact: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func ratio() -> float:
		return clampf(value / maxf(max_value, 0.001), 0.0, 1.0)

	func _draw() -> void:
		var amount: float = ratio()
		if amount <= 0.0: return
		var width: float = XJUITheme.RING_WIDTH_COMPACT if compact else XJUITheme.RING_WIDTH
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - width * 0.5
		if radius <= 0.0: return
		self.draw_arc(center, radius, XJUITheme.RING_START, XJUITheme.RING_START + XJUITheme.RING_SWEEP * amount, 64, tint, width, true)

## A target as the reference draws one: a circular portrait with the range under it in
## two lines. Used only while the target count is small enough for the row to fit; past
## that the list takes over, and the two views never appear together.
class PortraitMarker extends Control:
	## A real portrait where one exists. Targets do not currently carry a hull
	## reference, so most of them fall through to `mark`.
	var portrait: Texture2D = null
	## One or two characters drawn in the circle instead of a portrait. The target
	## types are already named in the interface, so the mark is the first character of
	## the name the player already reads rather than a second vocabulary to learn.
	var mark: String = ""
	var value: String = ""
	var unit: String = ""
	var hostile: bool = false
	var selected: bool = false
	var compact: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var width: float = XJUITheme.RING_WIDTH_COMPACT if compact else XJUITheme.RING_WIDTH
		var diameter: float = minf(size.x, size.y - 26.0)
		var center: Vector2 = Vector2(size.x * 0.5, diameter * 0.5)
		var radius: float = diameter * 0.5
		var face_radius: float = radius - width
		if face_radius <= 0.0: return
		var tint: Color = XJUITheme.DANGER if hostile else XJUITheme.ICE
		draw_circle(center, face_radius, Color(XJUITheme.COAL, 0.92))
		if portrait != null:
			XJUITheme.draw_portrait(self, center, face_radius, portrait)
		elif not mark.is_empty():
			var mark_size: int = 20 if compact else 24
			draw_string(XJUITheme.font_medium(), Vector2(0.0, center.y + mark_size * 0.36), mark, HORIZONTAL_ALIGNMENT_CENTER, size.x, mark_size, tint)
		# A hostile ring, not just hostile text: the type is stated in words under the
		# marker as well, so colour never carries the meaning on its own.
		draw_arc(center, radius - width * 0.5, 0.0, TAU, 48, Color(tint, 0.55) if hostile else Color(XJUITheme.BORDER, 0.8), width, true)
		if selected:
			# Selection is a shape, not only a colour: a second ring outside the frame.
			draw_arc(center, radius + width, 0.0, TAU, 48, XJUITheme.AMBER, width, true)
		draw_string(XJUITheme.font_medium(), Vector2(0.0, diameter + 14.0), value, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, tint)
		if not unit.is_empty():
			draw_string(XJUITheme.font(), Vector2(0.0, diameter + 26.0), unit, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, XJUITheme.MUTED)
