class_name XJStarChart
extends VBoxContainer
## Read-only navigation intelligence over the world's frozen SQLite definitions.
signal sector_selected(sector_id: String)
signal navigation_changed()
const UISkin = preload("res://runtime/ui_theme.gd")
const ResourceStatus = preload("res://runtime/resource_status.gd")
var catalog: XJCatalog
var state: XJRuntimeState
var business: RefCounted
var selected_sector: String = ""
var sectors: Dictionary = {}
var links: Array[Dictionary] = []
var diagram: ChartDrawing
var information: Label
var resource_information: Label
var search_box: LineEdit
var risk_filter: OptionButton
var sovereignty_filter: OptionButton
var navigator: OptionButton
var result_count: Label
var zoom_readout: Label
var _resource_nodes: Array[Dictionary] = []
var _selected_route: Array[String] = []
var _filter_text: String = ""
var _risk_id: String = ""
var _sovereignty_id: String = ""
var _route_mass: float = 0.0
var _pending_camera: Dictionary = {}
var _navigation_signature: String = ""

class ChartDrawing extends Control:
	var chart: XJStarChart
	var world_points: Dictionary = {}
	var points: Dictionary = {}
	var label_rects: Dictionary = {}
	var hit_rects: Dictionary = {}
	var visible_ids: Array[String] = []
	var label_ids: Array[String] = []
	var zoom: float = 1.0
	var fit_zoom: float = 1.0
	var pan: Vector2 = Vector2.ZERO
	var _previous_size: Vector2 = Vector2.ZERO
	var _camera_ready: bool = false
	var _press_position: Vector2 = Vector2.ZERO
	var _press_pan: Vector2 = Vector2.ZERO
	var _pressed: bool = false
	var _dragging: bool = false
	var _hovered: String = ""

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 380)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_force_pass_scroll_events = false
		focus_mode = Control.FOCUS_ALL
		clip_contents = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		resized.connect(_on_canvas_resized)
		mouse_exited.connect(func():
			_hovered = ""
			tooltip_text = ""
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _pressed = false
			queue_redraw())
		if chart != null and not chart.sectors.is_empty(): rebuild_layout()

	func rebuild_layout() -> void:
		world_points.clear()
		points.clear()
		label_rects.clear()
		hit_rects.clear()
		visible_ids.clear()
		label_ids.clear()
		_pressed = false
		_dragging = false
		_camera_ready = false
		if chart == null or chart.sectors.is_empty():
			queue_redraw()
			return
		var ids: Array[String] = chart._sorted_ids()
		var fixed_layout: bool = true
		for id: String in ids:
			if not chart.sectors[id].has("chart_point"): fixed_layout = false; break
		if fixed_layout:
			for id: String in ids: world_points[id] = chart.sectors[id].chart_point
			fit_all()
			return
		# Display coordinates derive from stable IDs and real fixed connections.
		# They are neither physical distances nor a second catalog of game values.
		for index: int in range(ids.size()):
			var angle: float = float(index) * 2.39996323 + float(absi(ids[index].hash()) % 37) * 0.013
			var radius: float = 180.0 * sqrt(float(index) + 1.0)
			world_points[ids[index]] = Vector2(cos(angle), sin(angle)) * radius
		var steps: int = 110 if ids.size() <= 160 else 70
		for iteration: int in range(steps):
			var displacement: Dictionary = {}
			for id: String in ids: displacement[id] = Vector2.ZERO
			for first: int in range(ids.size()):
				for second: int in range(first + 1, ids.size()):
					var a: String = ids[first]
					var b: String = ids[second]
					var delta: Vector2 = world_points[a] - world_points[b]
					var distance: float = maxf(delta.length(), 1.0)
					var repulsion: Vector2 = delta / distance * (44000.0 / distance)
					displacement[a] += repulsion
					displacement[b] -= repulsion
			for link: Dictionary in chart.links:
				if bool(link.get("wandering", false)): continue
				var origin: String = str(link.origin)
				var destination: String = str(link.destination)
				if not world_points.has(origin) or not world_points.has(destination): continue
				var delta: Vector2 = world_points[origin] - world_points[destination]
				var distance: float = maxf(delta.length(), 1.0)
				var attraction: Vector2 = delta / distance * (distance * distance / 240.0)
				displacement[origin] -= attraction
				displacement[destination] += attraction
			var limit: float = 32.0 * (1.0 - float(iteration) / float(steps)) + 1.5
			for id: String in ids:
				var motion: Vector2 = displacement[id]
				motion -= Vector2(world_points[id]) * 0.025
				world_points[id] += motion.limit_length(limit)
		var center: Vector2 = Vector2.ZERO
		for id: String in ids: center += Vector2(world_points[id])
		center /= float(ids.size())
		for id: String in ids: world_points[id] -= center
		# Orient the graph's longest axis across a wide chart. Rotation preserves
		# its topology and relative distances; resizing only moves the camera.
		var covariance_xx: float = 0.0
		var covariance_xy: float = 0.0
		var covariance_yy: float = 0.0
		for id: String in ids:
			var point: Vector2 = world_points[id]
			covariance_xx += point.x * point.x
			covariance_xy += point.x * point.y
			covariance_yy += point.y * point.y
		var axis_angle: float = 0.5 * atan2(2.0 * covariance_xy, covariance_xx - covariance_yy)
		for id: String in ids: world_points[id] = Vector2(world_points[id]).rotated(-axis_angle)
		fit_all()

	func _on_canvas_resized() -> void:
		if not _camera_ready:
			fit_all()
		else:
			pan += (size - _previous_size) * 0.5
			_previous_size = size
			queue_redraw()

	func fit_all() -> void:
		if world_points.is_empty() or size.x < 20 or size.y < 20:
			queue_redraw()
			return
		var bounds: Rect2 = _world_bounds()
		var padding: Vector2 = Vector2(clampf(size.x * 0.15, 60.0, 150.0), clampf(size.y * 0.23, 44.0, 100.0))
		var room: Vector2 = Vector2(maxf(40.0, size.x - padding.x), maxf(40.0, size.y - padding.y))
		fit_zoom = clampf(minf(room.x / maxf(bounds.size.x, 1.0), room.y / maxf(bounds.size.y, 1.0)), 0.025, 2.5)
		zoom = fit_zoom
		pan = size * 0.5 - bounds.get_center() * zoom
		_previous_size = size
		_camera_ready = true
		_changed()
		if chart != null and not chart._pending_camera.is_empty(): chart._restore_camera(chart._pending_camera)

	func _world_bounds() -> Rect2:
		var ids: Array = world_points.keys()
		var bounds: Rect2 = Rect2(Vector2(world_points[ids[0]]), Vector2.ONE)
		for id: String in world_points: bounds = bounds.expand(Vector2(world_points[id]))
		return bounds

	func center_on(id: String) -> void:
		if not world_points.has(id): return
		zoom = maxf(zoom, minf(1.25, fit_zoom * 2.4))
		pan = size * 0.5 - Vector2(world_points[id]) * zoom
		_camera_ready = true
		_changed()

	func zoom_at(factor: float, anchor: Vector2) -> void:
		var before: Vector2 = screen_to_world(anchor)
		zoom = clampf(zoom * factor, maxf(0.01, fit_zoom * 0.35), maxf(3.5, fit_zoom * 5.0))
		pan = anchor - before * zoom
		_changed()

	func screen_to_world(point: Vector2) -> Vector2:
		return (point - pan) / maxf(zoom, 0.001)

	func _changed() -> void:
		queue_redraw()
		if chart != null and is_instance_valid(chart.zoom_readout):
			chart.zoom_readout.text = "%d%%" % roundi(zoom / maxf(fit_zoom, 0.001) * 100.0)

	func _draw() -> void:
		_draw_space()
		points.clear()
		label_rects.clear()
		hit_rects.clear()
		visible_ids.clear()
		label_ids.clear()
		if chart == null or world_points.is_empty(): return
		for id: String in world_points: points[id] = Vector2(world_points[id]) * zoom + pan
		var viewport: Rect2 = Rect2(Vector2.ZERO, size).grow(36)
		for link: Dictionary in chart.links:
			var origin: String = str(link.origin)
			var destination: String = str(link.destination)
			if not points.has(origin) or not points.has(destination): continue
			var from: Vector2 = points[origin]
			var to: Vector2 = points[destination]
			if not _segment_visible(from, to, viewport): continue
			var on_route: bool = chart._route_contains(origin, destination)
			var emphasized: bool = on_route or origin == chart.selected_sector or destination == chart.selected_sector
			var opacity: float = 0.7 if emphasized else 0.32
			if not chart.matches_filter(origin) and not chart.matches_filter(destination) and not on_route: opacity *= 0.24
			var status: String = str(link.get("status", "open"))
			var color: Color = Color(UISkin.AMBER if emphasized else UISkin.ICE, opacity)
			if status != "open": color = Color(UISkin.MUTED, opacity * 0.75)
			var width: float = 2.0 if on_route else 1.25
			if bool(link.get("wandering", false)):
				_dashed_line(from, to, color, width, 2.0, 4.0)
			elif status != "open":
				_dashed_line(from, to, color, width, 8.0, 4.0)
			else:
				draw_line(from, to, color, width, true)
			if not bool(link.get("bidirectional", true)):
				_draw_arrow(from.lerp(to, 0.55), (to - from).normalized(), color)
		for id: String in chart._sorted_ids():
			var point: Vector2 = points[id]
			if not viewport.has_point(point): continue
			visible_ids.append(id)
			var selected: bool = id == chart.selected_sector
			var current: bool = chart.state != null and id == chart.state.current_sector()
			var context: bool = selected or current or chart._selected_route.has(id)
			var opacity: float = 1.0 if chart.matches_filter(id) or context else 0.2
			var color: Color = Color(chart._sovereignty_color(id), opacity)
			var radius: float = 5.5 if world_points.size() <= 40 or zoom > fit_zoom * 1.3 else 3.6
			draw_circle(point, radius, color)
			if bool(chart.sectors[id].get("contested", false)):
				var edge: float = radius + 5.0
				draw_polyline(PackedVector2Array([point + Vector2(0, -edge), point + Vector2(edge, 0), point + Vector2(0, edge), point + Vector2(-edge, 0), point + Vector2(0, -edge)]), UISkin.AMBER, 1.5, true)
			draw_arc(point, radius + 2.0, 0, TAU, 24, Color(chart._risk_color(str(chart.sectors[id].risk_zone_id)), opacity), 1.0, true)
			if selected:
				draw_arc(point, radius + 7.0, 0, TAU, 48, UISkin.AMBER, 1.8, true)
			if current:
				draw_arc(point, radius + 15.0, 0, TAU, 48, UISkin.TEXT, 1.1, true)
				draw_line(point + Vector2(0, -radius - 21), point + Vector2(0, -radius - 15), UISkin.TEXT, 1.0, true)
			if id == _hovered: draw_arc(point, radius + 4.0, 0, TAU, 32, UISkin.TEXT, 1.0, true)
			hit_rects[id] = Rect2(point - Vector2(13, 13), Vector2(26, 26))
		_draw_labels()
		_draw_coordinates()

	func _draw_space() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UISkin.COAL)
		var grid: float = 96.0
		for x: int in range(int(size.x / grid) + 1):
			draw_line(Vector2(float(x) * grid, 0), Vector2(float(x) * grid, size.y), Color(UISkin.BORDER, 0.16), 1)
		for y: int in range(int(size.y / grid) + 1):
			draw_line(Vector2(0, float(y) * grid), Vector2(size.x, float(y) * grid), Color(UISkin.BORDER, 0.16), 1)
		draw_rect(Rect2(Vector2.ZERO, size), UISkin.BORDER, false, 1)
		if has_focus(): draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(UISkin.ICE, 0.8), false, 1)

	func _draw_labels() -> void:
		var ids: Array[String] = chart._sorted_ids()
		ids.sort_custom(func(a: String, b: String) -> bool:
			var a_priority: int = _label_priority(a)
			var b_priority: int = _label_priority(b)
			return a < b if a_priority == b_priority else a_priority < b_priority)
		var occupied: Array[Rect2] = []
		var relative_zoom: float = zoom / maxf(fit_zoom, 0.001)
		var budget: int = mini(visible_ids.size(), maxi(14, int(size.x * size.y / 8000.0 * relative_zoom)))
		for id: String in ids:
			if not visible_ids.has(id): continue
			var priority: int = _label_priority(id)
			if priority >= 4 and not chart.matches_filter(id): continue
			if priority >= 4 and label_ids.size() >= budget: continue
			var title: String = str(chart.sectors[id].title)
			var point: Vector2 = points[id]
			var font_size: int = 13 if priority <= 1 else 12
			var text_size: Vector2 = UISkin.font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var label_size: Vector2 = text_size + Vector2(16, 8)
			var offsets: Array[Vector2] = [Vector2(16, -label_size.y * 0.5), Vector2(-label_size.x - 16, -label_size.y * 0.5), Vector2(-label_size.x * 0.5, -label_size.y - 24), Vector2(-label_size.x * 0.5, 24)]
			var rect: Rect2 = Rect2()
			var found: bool = false
			for offset: Vector2 in offsets:
				var candidate: Rect2 = Rect2(point + offset, label_size)
				if not Rect2(Vector2(7, 7), size - Vector2(14, 35)).encloses(candidate): continue
				var collision: bool = false
				for previous: Rect2 in occupied:
					if previous.grow(3).intersects(candidate): collision = true; break
				if collision: continue
				for other: String in visible_ids:
					if other != id and candidate.grow(5).has_point(Vector2(points[other])): collision = true; break
				if not collision:
					rect = candidate
					found = true
					break
			if not found and priority <= 1:
				var label_position: Vector2 = point + offsets[0]
				label_position.x = clampf(label_position.x, 7.0, maxf(7.0, size.x - label_size.x - 7.0))
				label_position.y = clampf(label_position.y, 7.0, maxf(7.0, size.y - label_size.y - 28.0))
				rect = Rect2(label_position, label_size)
				found = true
			if not found: continue
			occupied.append(rect)
			label_rects[id] = rect
			hit_rects[id] = Rect2(hit_rects[id]).merge(rect)
			label_ids.append(id)
			var bright: bool = priority <= 1 or id == _hovered
			draw_rect(rect, Color(UISkin.SURFACE, 0.96 if bright else 0.78))
			draw_rect(rect, Color(UISkin.BORDER, 0.8 if bright else 0.35), false, 1)
			draw_string(UISkin.font(), rect.position + Vector2(8, 4 + UISkin.font().get_ascent(font_size)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UISkin.AMBER if id == chart.selected_sector else UISkin.TEXT)

	func _label_priority(id: String) -> int:
		if id == chart.selected_sector: return 0
		if chart.state != null and id == chart.state.current_sector(): return 1
		if id == _hovered: return 2
		if chart._selected_route.has(id): return 3
		if bool(chart.sectors[id].get("capital", false)): return 3
		return 4

	func _draw_coordinates() -> void:
		var count: String = "%d 个星系 · %d 条航路" % [chart.sectors.size(), chart.links.size()]
		draw_string(UISkin.font(), Vector2(12, size.y - 11), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UISkin.MUTED)
		var note: String = "航路拓扑 · 非物理距离"
		var width: float = UISkin.font().get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		if size.x > 400: draw_string(UISkin.font(), Vector2(size.x - width - 12, size.y - 11), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UISkin.MUTED)

	func _segment_visible(from: Vector2, to: Vector2, bounds: Rect2) -> bool:
		return bounds.intersects(Rect2(from, Vector2.ZERO).expand(to).grow(2))

	func _dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
		var distance: float = from.distance_to(to)
		if distance < 1.0: return
		var direction: Vector2 = (to - from) / distance
		var start: float = 0.0
		while start < distance:
			draw_line(from + direction * start, from + direction * minf(start + dash, distance), color, width, true)
			start += dash + gap

	func _draw_arrow(point: Vector2, direction: Vector2, color: Color) -> void:
		var side: Vector2 = direction.orthogonal()
		draw_line(point, point - direction * 7 + side * 4, color, 1.2, true)
		draw_line(point, point - direction * 7 - side * 4, color, 1.2, true)

	func _hit_sector(local_point: Vector2) -> String:
		# Test individual shapes; a merged node/name box would hit blank space.
		for id: String in label_ids:
			if Rect2(label_rects[id]).has_point(local_point): return id
		var nearest: String = ""
		var distance: float = 16.0
		for id: String in visible_ids:
			var candidate: float = local_point.distance_to(Vector2(points[id]))
			if candidate < distance:
				nearest = id
				distance = candidate
		return nearest

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: zoom_at(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2, event.position)
				accept_event()
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					grab_focus()
					_pressed = true
					_dragging = false
					_press_position = event.position
					_press_pan = pan
				else:
					if _pressed and not _dragging:
						var id: String = _hit_sector(event.position)
						if not id.is_empty(): chart.select_sector(id)
					_pressed = false
					_dragging = false
					mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				accept_event()
				return
			accept_event()
		elif event is InputEventMouseMotion:
			if _pressed and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_pressed = false
				_dragging = false
			if _pressed:
				var movement: Vector2 = event.position - _press_position
				if movement.length() >= 6.0: _dragging = true
				if _dragging:
					pan = _press_pan + movement
					mouse_default_cursor_shape = Control.CURSOR_DRAG
					_changed()
			else:
				var hovered: String = _hit_sector(event.position)
				if hovered != _hovered:
					_hovered = hovered
					tooltip_text = chart._hover_text(hovered)
					queue_redraw()
			accept_event()
		elif event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_LEFT: pan += Vector2(44, 0); _changed()
				KEY_RIGHT: pan -= Vector2(44, 0); _changed()
				KEY_UP: pan += Vector2(0, 44); _changed()
				KEY_DOWN: pan -= Vector2(0, 44); _changed()
				KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: zoom_at(1.2, size * 0.5)
				KEY_MINUS, KEY_KP_SUBTRACT: zoom_at(1.0 / 1.2, size * 0.5)
				KEY_HOME: fit_all()
				KEY_END: chart.focus_selected()
				KEY_ENTER, KEY_KP_ENTER: chart.focus_selected()
				_: return
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_pressed = false
			_dragging = false

func _ready() -> void:
	name = "StarChart"
	add_theme_constant_override("separation", UISkin.GAP)
	var find_row: HBoxContainer = HBoxContainer.new()
	find_row.add_theme_constant_override("separation", UISkin.GAP)
	add_child(find_row)
	search_box = LineEdit.new()
	search_box.name = "SectorSearch"
	search_box.placeholder_text = "搜索星系名称 / ID"
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.custom_minimum_size.x = 130
	search_box.text_changed.connect(_search_changed)
	search_box.text_submitted.connect(func(_text: String): _select_first_match())
	find_row.add_child(search_box)
	risk_filter = OptionButton.new()
	risk_filter.name = "RiskFilter"
	for title: String in ["全部安全区", "高安全区", "中安全区", "低安全区"]: risk_filter.add_item(title)
	risk_filter.item_selected.connect(_risk_changed)
	find_row.add_child(risk_filter)
	sovereignty_filter = OptionButton.new()
	sovereignty_filter.name = "SovereigntyFilter"
	sovereignty_filter.custom_minimum_size.x = 112
	sovereignty_filter.add_theme_font_size_override("font_size", UISkin.text_size("note"))
	sovereignty_filter.item_selected.connect(_sovereignty_changed)
	find_row.add_child(sovereignty_filter)
	navigator = OptionButton.new()
	navigator.name = "SectorNavigator"
	# Content-sized. Two children of this row used to expand and shared the slack, so
	# a four-character sector dropdown was drawn 552 px wide next to the search box.
	navigator.size_flags_horizontal = Control.SIZE_FILL
	navigator.fit_to_longest_item = false
	navigator.custom_minimum_size.x = 100
	navigator.item_selected.connect(_navigator_selected)
	find_row.add_child(navigator)
	var view_row: HBoxContainer = HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 4)
	add_child(view_row)
	_toolbar_button(view_row, "全图", "ChartFitAll", fit_all)
	_toolbar_button(view_row, "当前", "ChartFocusCurrent", focus_current)
	_toolbar_button(view_row, "选中", "ChartFocusSelected", focus_selected)
	_toolbar_button(view_row, "−", "ChartZoomOut", func(): diagram.zoom_at(1.0 / 1.2, diagram.size * 0.5))
	_toolbar_button(view_row, "+", "ChartZoomIn", func(): diagram.zoom_at(1.2, diagram.size * 0.5))
	zoom_readout = Label.new()
	zoom_readout.add_theme_font_size_override("font_size", UISkin.text_size("note"))
	view_row.add_child(zoom_readout)
	result_count = Label.new()
	result_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	result_count.add_theme_font_size_override("font_size", UISkin.text_size("note"))
	result_count.add_theme_color_override("font_color", UISkin.MUTED)
	view_row.add_child(result_count)
	diagram = ChartDrawing.new()
	diagram.chart = self
	diagram.name = "WormholeTopology"
	add_child(diagram)
	var legend: Label = Label.new()
	legend.name = "ChartLegend"
	legend.text = "外圈安全色：高青 / 中琥珀 / 低红 · 青灰节点归属见详情 · 菱形争夺\n白圈当前位置 · 琥珀圈选中 · 实线开放 / 虚线受限 / 点线游离航路\n滚轮缩放 · 左拖平移 · 点击星系查看 · 方向键平移 · Home 全图"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", UISkin.text_size("note"))
	legend.add_theme_color_override("font_color", UISkin.MUTED)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)
	move_child(legend, diagram.get_index())
	information = Label.new()
	information.name = "SectorIntelligence"
	information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.add_theme_font_size_override("font_size", 13)
	information.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(information)
	resource_information = Label.new()
	resource_information.name = "ResourceIntelligence"
	resource_information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_information.add_theme_font_size_override("font_size", 13)
	resource_information.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(resource_information)
	_update_navigator()
	_update_information()

func _toolbar_button(parent: Control, title: String, identity: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = title
	button.name = identity
	button.custom_minimum_size = Vector2(36, 29)
	button.add_theme_font_size_override("font_size", UISkin.text_size("note"))
	UISkin.apply_button(button, "default", true)
	button.pressed.connect(callback)
	parent.add_child(button)

func configure(definitions: XJCatalog, runtime: XJRuntimeState, gameplay: RefCounted = null) -> void:
	catalog = definitions
	state = runtime
	business = gameplay
	sectors.clear()
	links.clear()
	_selected_route.clear()
	if catalog == null or state == null: return
	if business != null:
		var metrics: Dictionary = business.call("metrics", state.ship())
		_route_mass = float(metrics.get("total_mass_kg", 0.0))
	for row: Dictionary in catalog.rows("sector_defs"):
		var system: Dictionary = catalog.one("system_defs", "system_id", row.system_id)
		sectors[str(row.sector_id)] = {"title": str(system.get("display_name", row.sector_id)), "risk_zone_id": str(row.risk_zone_id), "system_id": str(row.system_id)}
		if catalog.table_names.has("sector_sovereignty_defs"):
			var policy: Dictionary = catalog.one("sector_sovereignty_defs", "sector_id", row.sector_id)
			if not policy.is_empty(): sectors[str(row.sector_id)]["chart_point"] = Vector2(float(policy.chart_x), float(policy.chart_y))
			sectors[str(row.sector_id)]["capital"] = not catalog.one("civilization_defs", "capital_sector_id", row.sector_id).is_empty()
	_refresh_sovereignty()
	if is_instance_valid(sovereignty_filter):
		sovereignty_filter.clear()
		sovereignty_filter.visible = catalog.table_names.has("civilization_defs")
		sovereignty_filter.add_item("全部主权"); sovereignty_filter.set_item_metadata(0, "")
		if sovereignty_filter.visible:
			sovereignty_filter.add_item("中立星系"); sovereignty_filter.set_item_metadata(1, "neutral")
			for faction: Dictionary in catalog.rows("civilization_defs"):
				sovereignty_filter.add_item(str(catalog.one("faction_defs", "faction_id", faction.faction_id).display_name))
				sovereignty_filter.set_item_metadata(sovereignty_filter.item_count - 1, str(faction.faction_id))
	var endpoints_by_connection: Dictionary = {}
	for endpoint: Dictionary in catalog.rows("gate_endpoint_defs"):
		var identity: String = str(endpoint.connection_id)
		if not endpoints_by_connection.has(identity): endpoints_by_connection[identity] = []
		endpoints_by_connection[identity].append(endpoint)
	for connection: Dictionary in catalog.rows("connection_defs"):
		var identity: String = str(connection.connection_id)
		var endpoints: Array = endpoints_by_connection.get(identity, [])
		# Only doors represented by this frozen world are shown.
		if endpoints.is_empty(): continue
		var gate_class: Dictionary = catalog.one("gate_class_defs", "gate_class_id", connection.gate_class_id)
		var wandering: bool = gate_class.get("lifetime_s") != null or gate_class.get("total_mass_budget_kg") != null
		var first: Dictionary = endpoints[0]
		var link: Dictionary = {"connection_id": identity, "origin": str(first.origin_sector_id), "destination": str(first.target_sector_id), "bidirectional": _has_reverse_endpoint(endpoints), "wandering": wandering, "type": "wandering" if wandering else "fixed", "endpoints": endpoints}
		link["status"] = _link_status(link)
		links.append(link)
	_navigation_signature = _build_navigation_signature()
	if not sectors.has(selected_sector): selected_sector = state.current_sector()
	if not sectors.has(selected_sector) and not sectors.is_empty(): selected_sector = _sorted_ids()[0]
	_update_navigator()
	_update_information()
	if is_instance_valid(diagram): diagram.rebuild_layout()

func _has_reverse_endpoint(endpoints: Array) -> bool:
	if endpoints.size() < 2: return false
	var first: Dictionary = endpoints[0]
	for endpoint: Dictionary in endpoints:
		if endpoint.origin_sector_id == first.target_sector_id and endpoint.target_sector_id == first.origin_sector_id: return true
	return false

func select_sector(id: String) -> void:
	if not sectors.has(id): return
	selected_sector = id
	_update_navigator()
	_update_information()
	if is_instance_valid(diagram): diagram.queue_redraw()
	sector_selected.emit(id)

func fit_all() -> void:
	if is_instance_valid(diagram): diagram.fit_all()

func focus_current() -> void:
	if state == null: return
	select_sector(state.current_sector())
	if is_instance_valid(diagram): diagram.center_on(selected_sector)

func focus_selected() -> void:
	if is_instance_valid(diagram): diagram.center_on(selected_sector)

func _sorted_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in sectors: ids.append(id)
	ids.sort()
	return ids

func matches_filter(id: String) -> bool:
	if not sectors.has(id): return false
	var row: Dictionary = sectors[id]
	var owner: String = str(row.get("owner_id", ""))
	var sovereignty_matches: bool = _sovereignty_id.is_empty() or (_sovereignty_id == "neutral" and owner.is_empty()) or _sovereignty_id == owner
	return sovereignty_matches and (_risk_id.is_empty() or str(row.risk_zone_id) == _risk_id) and (_filter_text.is_empty() or str(row.title).to_lower().contains(_filter_text) or id.to_lower().contains(_filter_text))

func _refresh_sovereignty() -> bool:
	if catalog == null or state == null or not catalog.table_names.has("civilization_defs"): return false
	var changed: bool = false
	var contested: Dictionary = {}
	for war: RefCounted in state.rows("war_campaign_state"):
		if war.status in ["assembling", "fighting", "occupying"]:
			var definition: Dictionary = catalog.one("civilization_war_defs", "war_id", war.war_id)
			if not definition.is_empty(): contested[str(definition.target_sector_id)] = true
	for id: String in sectors:
		var control: RefCounted = state.find("territory_state", "sector_id", id)
		var owner: String = str(control.faction_id) if control != null and control.has_faction_id else ""
		if sectors[id].get("owner_id", "unset") != owner:
			sectors[id]["owner_id"] = owner
			changed = true
		if bool(sectors[id].get("contested", false)) != contested.has(id):
			sectors[id]["contested"] = contested.has(id)
			changed = true
	return changed

func _sovereignty_changed(index: int) -> void:
	_sovereignty_id = str(sovereignty_filter.get_item_metadata(index))
	_update_navigator()
	if is_instance_valid(diagram): diagram.queue_redraw()

func _sovereignty_color(id: String) -> Color:
	if not catalog.table_names.has("civilization_defs"): return UISkin.ICE
	var faction: Dictionary = catalog.one("civilization_defs", "faction_id", str(sectors[id].get("owner_id", "")))
	# Ownership remains authoritative text; arbitrary faction colors do not widen the UI palette.
	return UISkin.ICE if not faction.is_empty() else UISkin.MUTED

func _search_changed(text: String) -> void:
	_filter_text = text.strip_edges().to_lower()
	_update_navigator()
	if is_instance_valid(diagram): diagram.queue_redraw()

func _risk_changed(index: int) -> void:
	_risk_id = ["", "risk_high", "risk_medium", "risk_low"][clampi(index, 0, 3)]
	_update_navigator()
	if is_instance_valid(diagram): diagram.queue_redraw()

func _update_navigator() -> void:
	if not is_instance_valid(navigator): return
	navigator.clear()
	var selected_index: int = -1
	for id: String in _sorted_ids():
		if not matches_filter(id): continue
		var index: int = navigator.item_count
		navigator.add_item(str(sectors[id].title))
		navigator.set_item_metadata(index, id)
		if id == selected_sector: selected_index = index
	var count: int = navigator.item_count
	navigator.disabled = count == 0
	if count == 0:
		navigator.add_item("没有匹配星系")
		navigator.set_item_metadata(0, "")
	elif selected_index >= 0:
		navigator.select(selected_index)
	else:
		navigator.select(-1)
		navigator.text = "选择匹配星系"
	if is_instance_valid(result_count): result_count.text = "%d / %d" % [count, sectors.size()]
	if not matches_filter(selected_sector) and not selected_sector.is_empty() and is_instance_valid(result_count):
		result_count.tooltip_text = "已选星系保留在图中及详情中；搜索和筛选仅突出匹配星系。"
	elif is_instance_valid(result_count):
		result_count.tooltip_text = "匹配星系 / 全部星系；使用下拉选择或搜索回车聚焦。"

func _select_first_match() -> void:
	for id: String in _sorted_ids():
		if matches_filter(id):
			select_sector(id)
			focus_selected()
			return

func _navigator_selected(index: int) -> void:
	var id: String = str(navigator.get_item_metadata(index))
	if id.is_empty(): return
	select_sector(id)
	focus_selected()

func _risk_color(id: String) -> Color:
	return {"risk_high": UISkin.ICE, "risk_medium": UISkin.AMBER, "risk_low": UISkin.DANGER}.get(id, UISkin.MUTED)

func _endpoint_reason(endpoint: Dictionary) -> String:
	if state == null: return "状态未知"
	if catalog != null and catalog.table_names.has("sector_runtime_defs"):
		var target: Dictionary = catalog.one("sector_runtime_defs", "sector_id", str(endpoint.get("target_sector_id", "")))
		if not target.is_empty() and not bool(target.get("enabled", true)): return "目的星区尚未开放"
	if business != null:
		var missions: RefCounted = business.get("missions")
		return str(missions.call("_gate_route_reason", endpoint, _route_mass))
	var unlock_id: String = str(endpoint.get("required_unlock_id", ""))
	if not unlock_id.is_empty() and state.find("unlock_state", "unlock_id", unlock_id) == null:
		var unlock: Dictionary = catalog.one("unlock_defs", "unlock_id", unlock_id) if catalog != null else {}
		return "航路需解锁 " + str(unlock.get("display_name", "虫洞权限"))
	var gate: RefCounted = state.find("gate_state", "connection_id", str(endpoint.get("connection_id", "")))
	if gate == null: return "航门状态未知"
	if gate.has_lifetime_remaining_s and gate.lifetime_remaining_s <= 0.0: return "虫洞寿命已耗尽"
	if not gate.enabled: return "航门处于关闭状态"
	if gate.has_remaining_mass_budget_kg and gate.remaining_mass_budget_kg <= 0.0: return "虫洞质量额度已耗尽"
	return ""

func _link_status(link: Dictionary) -> String:
	var endpoints: Array = link.get("endpoints", [])
	if endpoints.is_empty(): return "open"
	var reasons: Array[String] = []
	for endpoint: Dictionary in endpoints:
		var reason: String = _endpoint_reason(endpoint)
		if reason.is_empty(): return "open"
		reasons.append(reason)
	for reason: String in reasons:
		if reason.contains("解锁"): return "locked"
	for reason: String in reasons:
		if reason.contains("关闭") or reason.contains("耗尽"): return "closed"
	return "restricted"

func _hover_text(id: String) -> String:
	if not sectors.has(id): return ""
	var title: String = str(sectors[id].title)
	if state != null and id == state.current_sector(): title += " · 当前位置"
	if catalog.table_names.has("civilization_defs"):
		var owner: String = str(sectors[id].get("owner_id", ""))
		var faction: Dictionary = catalog.one("faction_defs", "faction_id", owner)
		title += "\n主权势力：" + str(faction.get("display_name", owner if not owner.is_empty() else "中立"))
	return title + "\n点击查看此星系详情；仅改变选择。"

func _route_contains(origin: String, destination: String) -> bool:
	for index: int in range(maxi(0, _selected_route.size() - 1)):
		if _selected_route[index] == origin and _selected_route[index + 1] == destination: return true
		if _selected_route[index] == destination and _selected_route[index + 1] == origin: return true
	return false

func _update_information() -> void:
	if not is_instance_valid(information) or catalog == null or state == null or not sectors.has(selected_sector): return
	var row: Dictionary = sectors[selected_sector]
	var risk: Dictionary = catalog.one("risk_zone_defs", "risk_zone_id", row.risk_zone_id)
	var station_names: Array[String] = []
	var factions: Array[String] = []
	for station: Dictionary in catalog.rows("station_defs"):
		if station.sector_id != selected_sector: continue
		station_names.append(str(station.display_name))
		var faction: Dictionary = catalog.one("faction_defs", "faction_id", station.faction_id)
		var title: String = str(faction.get("display_name", "未知势力"))
		if not factions.has(title): factions.append(title)
	var resources: Array[String] = []
	_resource_nodes.clear()
	for location: Dictionary in catalog.rows("resource_node_locations"):
		if business != null and not business.exploration.resource_visible(location.node_id) and (not business.situational.supported() or state.find("resource_intel_state","node_id",location.node_id)==null): continue
		var anchor: Dictionary = business.definition("anchor_defs", "anchor_id", location.anchor_id) if business != null else catalog.one("anchor_defs", "anchor_id", location.anchor_id)
		if anchor.get("sector_id", "") != selected_sector: continue
		var node: Dictionary = catalog.one("resource_node_defs", "node_id", location.node_id)
		var item: Dictionary = catalog.one("item_defs", "item_id", node.get("item_id", ""))
		var title: String = str(item.get("display_name", "未知资源"))
		if not resources.has(title): resources.append(title)
		_resource_nodes.append({"node_id": str(location.node_id), "title": title})
	var status: Dictionary = route_status(selected_sector)
	_selected_route.clear()
	for id: String in status.route: _selected_route.append(id)
	var names: Array[String] = []
	for id: String in _selected_route: names.append(str(sectors.get(id, {}).get("title", id)))
	var route_text: String = "当前位置"
	if selected_sector != state.current_sector():
		if _selected_route.is_empty():
			route_text = "暂无已登记的有向虫洞路线"
		else:
			route_text = ("可规划航路：" if bool(status.open) else "拓扑航路（当前受限）：") + " → ".join(names)
			var blocked: Array = status.blocked
			if not blocked.is_empty(): route_text += "\n" + "；".join(blocked)
	var sovereignty: String = "、".join(factions) if not factions.is_empty() else "未记录"
	if catalog.table_names.has("civilization_defs"):
		var owner: String = str(row.get("owner_id", ""))
		var policy: Dictionary = catalog.one("sector_sovereignty_defs", "sector_id", selected_sector)
		sovereignty = str(catalog.one("faction_defs", "faction_id", owner).get("display_name", owner)) if not owner.is_empty() else "中立（可争夺）" if bool(policy.get("conquerable", false)) else "中立（受保护航路）"
		if bool(row.get("capital", false)): sovereignty += " · 文明核心"
		if bool(row.get("contested", false)): sovereignty += " · 战争争夺中"
	information.text = "%s  ·  %s  ·  NPC 等级 %d–%d\n主权势力：%s  /  空间站：%s\n站点经营者：%s\n资源：%s\n%s\n星图只提供情报；距离、费用、电容、冷却及交战条件在实际虫洞入口再次校验。" % [row.title, risk.get("display_name", "未知安全区"), int(risk.get("npc_level_min", 0)), int(risk.get("npc_level_max", 0)), sovereignty, "、".join(station_names) if not station_names.is_empty() else "未记录", "、".join(factions), "、".join(resources) if not resources.is_empty() else "未记录", route_text]
	if catalog.table_names.has("sector_activity_defs"):
		var activity: Dictionary = catalog.one("sector_activity_defs", "sector_id", selected_sector)
		information.text += "\n定位：%s · %s\n活动：%s" % [str(activity.get("logistics_role", "")), str(activity.get("resource_role", "")), str(activity.get("event_hint", ""))]
	refresh_resource_status()

func refresh_resource_status(total_mass_kg: float = -1.0) -> void:
	if _refresh_sovereignty():
		_update_navigator()
		_update_information()
		if is_instance_valid(diagram): diagram.queue_redraw()
		return
	if not is_instance_valid(resource_information) or state == null or catalog == null: return
	if _refresh_navigation_intelligence(total_mass_kg): return
	var visit: RefCounted = state.find("sector_state", "sector_id", selected_sector)
	var known: bool = selected_sector == state.current_sector() or (visit != null and visit.visited)
	var lines: Array[String] = ["矿点情报 · 世界时间"]
	for entry: Dictionary in _resource_nodes:
		var status: String = "尚未到访 · 实时矿量未知"
		if business != null and business.situational.supported():
			status = business.situational.resource_text(str(entry.node_id))
		elif known:
			var info: Dictionary = ResourceStatus.inspect(state, catalog, str(entry.node_id))
			status = ResourceStatus.summary(info)
			if bool(info.get("available", false)) and int(info.get("capacity_units", 0)) > 0:
				status += " · %.0f%%" % (float(info.remaining_units) / float(info.capacity_units) * 100.0)
		lines.append(str(entry.title) + "：" + status)
	if _resource_nodes.is_empty(): lines.append("未记录矿点")
	var text: String = "\n".join(lines)
	if resource_information.text != text:
		resource_information.text = text
		resource_information.tooltip_text = text + "\n现场范围内才更新矿量；远程显示带时间的上次观测，超过有效期需复测。暂停与退出不推进情报年龄。"

func _refresh_route_mass(total_mass_kg: float = -1.0) -> void:
	if total_mass_kg >= 0.0:
		_route_mass = total_mass_kg
	elif business != null and state != null:
		var metrics: Dictionary = business.call("metrics", state.ship())
		_route_mass = float(metrics.get("total_mass_kg", 0.0))

func _build_navigation_signature() -> String:
	if state == null: return ""
	var entries: Array[String] = ["mass:" + str(_route_mass)]
	for unlock: RefCounted in state.rows("unlock_state"):
		entries.append("unlock:" + str(unlock.unlock_id))
	for gate: RefCounted in state.rows("gate_state"):
		# Only expiry affects passage; a positive lifetime ticking down does not
		# redraw the whole chart. Remaining mass affects this loaded hull.
		entries.append("gate:%s:%s:%s:%s:%s:%s" % [gate.connection_id, gate.enabled, gate.has_lifetime_remaining_s, not gate.has_lifetime_remaining_s or gate.lifetime_remaining_s > 0.0, gate.has_remaining_mass_budget_kg, gate.remaining_mass_budget_kg])
	entries.sort()
	return "|".join(entries)

func _refresh_navigation_intelligence(total_mass_kg: float) -> bool:
	_refresh_route_mass(total_mass_kg)
	var signature: String = _build_navigation_signature()
	if signature == _navigation_signature: return false
	# Store before updating information: its resource refresh re-enters here.
	_navigation_signature = signature
	for link: Dictionary in links: link["status"] = _link_status(link)
	_update_information()
	if is_instance_valid(diagram): diagram.queue_redraw()
	navigation_changed.emit()
	return true

func route_status(destination: String) -> Dictionary:
	var result: Dictionary = {"route": [], "blocked": [], "open": false}
	if state == null or not sectors.has(destination): return result
	_refresh_route_mass()
	var origin: String = state.current_sector()
	if origin == destination:
		result.route = [origin]
		result.open = true
		return result
	if business != null:
		var missions: RefCounted = business.get("missions")
		var path: Array = missions.call("_route", origin, destination, true)
		result.open = not path.is_empty()
		if path.is_empty(): path = missions.call("_route", origin, destination, false)
		if path.is_empty(): return result
		var ids: Array[String] = [origin]
		var blocked: Array[String] = []
		for endpoint: Dictionary in path:
			var id: String = str(endpoint.target_sector_id)
			ids.append(id)
			var reason: String = _endpoint_reason(endpoint)
			if not reason.is_empty(): blocked.append(str(sectors.get(id, {}).get("title", id)) + "：" + reason)
		result.route = ids
		result.blocked = blocked
		result.open = bool(result.open) and blocked.is_empty()
		return result
	var route: Array[String] = _route(origin, destination)
	var reasons: Array[String] = []
	for index: int in range(maxi(0, route.size() - 1)):
		var endpoint: Dictionary = _endpoint_between(route[index], route[index + 1])
		if endpoint.is_empty(): continue
		var reason: String = _endpoint_reason(endpoint)
		if not reason.is_empty(): reasons.append(str(sectors[route[index + 1]].title) + "：" + reason)
	result.route = route
	result.blocked = reasons
	result.open = not route.is_empty() and reasons.is_empty()
	return result

func _endpoint_between(origin: String, destination: String) -> Dictionary:
	for link: Dictionary in links:
		for endpoint: Dictionary in link.get("endpoints", []):
			if endpoint.origin_sector_id == origin and endpoint.target_sector_id == destination: return endpoint
	return {}

func _route(origin: String, destination: String) -> Array[String]:
	var queue: Array[String] = [origin]
	var predecessors: Dictionary = {origin: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == destination: break
		for link: Dictionary in links:
			var destinations: Array[String] = []
			var endpoints: Array = link.get("endpoints", [])
			if not endpoints.is_empty():
				for endpoint: Dictionary in endpoints:
					if str(endpoint.origin_sector_id) == current: destinations.append(str(endpoint.target_sector_id))
			else:
				if str(link.origin) == current: destinations.append(str(link.destination))
				elif str(link.destination) == current and bool(link.get("bidirectional", true)): destinations.append(str(link.origin))
			for other: String in destinations:
				if not sectors.has(other) or predecessors.has(other): continue
				predecessors[other] = current
				queue.append(other)
	var result: Array[String] = []
	if not predecessors.has(destination): return result
	var step: String = destination
	while not step.is_empty():
		result.push_front(step)
		step = str(predecessors[step])
	return result

func export_view() -> Dictionary:
	if not is_instance_valid(diagram): return {}
	return {"selected_sector": selected_sector, "search": search_box.text, "risk_index": risk_filter.selected, "sovereignty": _sovereignty_id, "zoom": diagram.zoom, "relative_zoom": diagram.zoom / maxf(diagram.fit_zoom, 0.001), "world_center": diagram.screen_to_world(diagram.size * 0.5)}

func restore_view(view: Dictionary) -> void:
	if view.is_empty() or not is_instance_valid(diagram): return
	search_box.text = str(view.get("search", ""))
	_search_changed(search_box.text)
	risk_filter.select(clampi(int(view.get("risk_index", 0)), 0, 3))
	_risk_changed(risk_filter.selected)
	if is_instance_valid(sovereignty_filter):
		for index: int in range(sovereignty_filter.item_count):
			if str(sovereignty_filter.get_item_metadata(index)) == str(view.get("sovereignty", "")):
				sovereignty_filter.select(index)
				_sovereignty_changed(index)
				break
	var id: String = str(view.get("selected_sector", ""))
	if sectors.has(id): select_sector(id)
	_pending_camera = view.duplicate(true)
	call_deferred("_restore_camera", _pending_camera)

func _restore_camera(view: Dictionary) -> void:
	if not is_instance_valid(diagram) or not diagram._camera_ready or diagram.size.x < 20 or diagram.size.y < 20: return
	_pending_camera = {}
	var restored_zoom: float = float(view.get("zoom", diagram.fit_zoom * float(view.get("relative_zoom", 1.0))))
	diagram.zoom = clampf(restored_zoom, maxf(0.01, diagram.fit_zoom * 0.35), maxf(3.5, diagram.fit_zoom * 5.0))
	var center: Vector2 = view.get("world_center", Vector2.ZERO)
	diagram.pan = diagram.size * 0.5 - center * diagram.zoom
	diagram._changed()
