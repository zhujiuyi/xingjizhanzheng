extends CanvasLayer
## Independent modal loading feedback; elapsed time is measured from a monotonic clock.
const UISkin = preload("res://runtime/ui_theme.gd")
var stage_label: Label
var elapsed_label: Label
var progress_track: Control
var activity_segment: ColorRect
var _screen: Control
var _panel: PanelContainer
var _stage_message: String = "正在处理航行档案"
var _started_ms: int = -1

func set_stage(message: String) -> void:
	if _started_ms < 0: _started_ms = Time.get_ticks_msec()
	_stage_message = message if not message.strip_edges().is_empty() else "正在处理航行档案"
	if is_instance_valid(stage_label): stage_label.text = _stage_message

func _ready() -> void:
	name = "LoadingOverlay"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _started_ms < 0: _started_ms = Time.get_ticks_msec()
	_screen = Control.new()
	_screen.name = "LoadingInputShield"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.focus_mode = Control.FOCUS_ALL
	var theme := Theme.new()
	theme.default_font = UISkin.font()
	theme.default_font_size = 14
	_screen.theme = theme
	add_child(_screen)
	var background := ColorRect.new()
	background.color = UISkin.COAL
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_screen.add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "LoadingPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UISkin.flat(UISkin.SURFACE, UISkin.BORDER, 20))
	center.add_child(_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	_panel.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	body.add_child(header)
	var title: Label = _label(header, "准备航行", 22, UISkin.ICE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elapsed_label = _label(header, "已用 0.0 秒", 12, UISkin.MUTED)
	elapsed_label.name = "LoadingElapsed"
	elapsed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage_label = _label(body, _stage_message, 15, UISkin.TEXT)
	stage_label.name = "LoadingStage"
	stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_label.custom_minimum_size.x = 0
	progress_track = Control.new()
	progress_track.name = "LoadingActivityTrack"
	progress_track.custom_minimum_size.y = 4
	progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(progress_track)
	var track_background := ColorRect.new()
	track_background.color = UISkin.BORDER
	track_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_track.add_child(track_background)
	activity_segment = ColorRect.new()
	activity_segment.name = "LoadingActivitySegment"
	activity_segment.color = UISkin.ICE
	activity_segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_track.add_child(activity_segment)
	var hint: Label = _label(body, "正在处理航行档案，请稍候", 12, UISkin.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 0
	_screen.resized.connect(_fit_panel)
	_fit_panel()
	_screen.grab_focus()
	_process(0.0)

func _label(parent: Node, message: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = message
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _fit_panel() -> void:
	if not is_instance_valid(_panel): return
	_panel.custom_minimum_size.x = minf(440.0, maxf(200.0, get_viewport().get_visible_rect().size.x - 48.0))

func _process(_delta: float) -> void:
	if not is_instance_valid(elapsed_label) or _started_ms < 0: return
	var elapsed: float = maxf(0.0, float(Time.get_ticks_msec() - _started_ms) / 1000.0)
	elapsed_label.text = "已用 %.1f 秒" % elapsed
	if not is_instance_valid(progress_track) or not is_instance_valid(activity_segment): return
	var width: float = progress_track.size.x
	var segment_width: float = minf(width, maxf(24.0, width * 0.22))
	activity_segment.size = Vector2(segment_width, progress_track.size.y)
	activity_segment.position = Vector2(maxf(0.0, width - segment_width) * (0.5 - 0.5 * cos(elapsed * 2.4)), 0)

func _input(_event: InputEvent) -> void:
	if visible and is_inside_tree(): get_viewport().set_input_as_handled()
