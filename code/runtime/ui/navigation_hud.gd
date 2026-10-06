class_name XJNavigationHUD
extends Control
## Local echoes use authoritative detection radius. Known remote locations and
## celestial bearings sit on the perimeter, distinguished from local echoes.
signal selected(target_id: String)
const UISkin = preload("res://runtime/ui_theme.gd")
const Navigation = preload("res://runtime/navigation_catalog.gd")
var world: Node3D
var rig: Node3D
var selected_id: String = ""
var contacts: Array[Dictionary] = []
var scales: Array[float] = []
var scale_index: int = 1
var sensor_limit: float = 0.0
var radar_frame: PanelContainer
var radar: Radar
var range_label: Label
var selection_frame: PanelContainer
var selection_label: Label
var target_caption: Label
var selection_readout_enabled: bool = true:
	set(value):
		selection_readout_enabled = value
		if not value and is_instance_valid(selection_frame): selection_frame.hide()
var selection_obstructed: bool = false
var caption_obstacles: Array[Rect2] = []

class Radar extends Control:
	var host: XJNavigationHUD
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var center := size * Vector2(0.5, 0.47)
		var radius := minf(size.x * 0.42, size.y * 0.39)
		draw_circle(center, radius, Color(0.025, 0.055, 0.075, 0.76))
		for fraction: float in [0.33, 0.66, 1.0]: draw_arc(center, radius * fraction, 0, TAU, 72, Color(0.19, 0.38, 0.44, 0.65), 1, true)
		for index: int in range(24):
			var direction := Vector2.from_angle(float(index) * TAU / 24.0)
			draw_line(center + direction * (radius - 3), center + direction * (radius + (4 if index % 3 == 0 else 1)), UISkin.ICE * Color(1, 1, 1, 0.7), 1, true)
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.24, 0.45, 0.5, 0.38), 1, true)
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.24, 0.45, 0.5, 0.38), 1, true)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(-5, 6), center + Vector2(5, 6)]), UISkin.TEXT)
		for contact: Dictionary in host.contacts:
			var point: Vector2 = host.radar_point(contact, size)
			var color: Color = host.contact_color(str(contact.kind))
			if contact.kind in ["npc", "ship"]:
				draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(-4, 4), point + Vector2(4, 4)]), color)
			elif contact.kind == "planet":
				draw_arc(point, 4, 0, TAU, 18, color, 1.5, true)
				draw_line(point + Vector2(-7, 3), point + Vector2(7, -3), color, 1, true)
			elif contact.kind == "gate":
				draw_polyline(PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 0), point + Vector2(0, 5), point + Vector2(-5, 0), point + Vector2(0, -5)]), color, 1.5, true)
			else: draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), color, false, 1.3)
			if bool(contact.bearing):
				var outward: Vector2 = (point - center).normalized()
				var across: Vector2 = outward.orthogonal()
				draw_polyline(PackedVector2Array([point + outward * 5 - across * 3, point + outward * 9, point + outward * 5 + across * 3]), color, 1.0, true)
			if contact.id == host.selected_id: draw_arc(point, 9, 0, TAU, 24, UISkin.TEXT, 1.3, true)
			var elevation_threshold: float = float(contact.distance_m) * 0.12 if contact.bearing else host.radius_m() * 0.12
			if absf(float(contact.height_m)) > elevation_threshold:
				var direction: float = -1.0 if contact.height_m > 0 else 1.0
				draw_line(point + Vector2(0, direction * 5), point + Vector2(0, direction * 10), color, 1, true)
		var face: Font = UISkin.font()
		# At high UI scale the plot can be only a few text lines tall. Its real
		# range remains in the header; keep the plot clear of optional captions.
		if size.y >= face.get_height(10) * 6.0:
			draw_string(face, Vector2(0, 12), "舰首 ↑", HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, UISkin.MUTED)
			draw_string(face, Vector2(0, size.y - 9), "局部回波 / 边缘航向", HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, UISkin.MUTED)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var closest: String = ""
			var best: float = 14.0
			for contact: Dictionary in host.contacts:
				var distance: float = host.radar_point(contact, size).distance_to(event.position)
				if distance < best: best = distance; closest = str(contact.id)
			if not closest.is_empty(): host.selected.emit(closest)
			accept_event()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row: Dictionary in Navigation.rows("radar_range_defs"): scales.append(float(row.radius_m))
	scales.sort()
	radar_frame = PanelContainer.new()
	radar_frame.name = "LocalRadar"
	radar_frame.add_theme_stylebox_override("panel", UISkin.plate())
	add_child(radar_frame)
	UISkin.decorate(radar_frame, 0.38)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 2)
	radar_frame.add_child(layout)
	var row := HBoxContainer.new()
	layout.add_child(row)
	range_label = Label.new()
	range_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_label.clip_text = true
	range_label.add_theme_font_size_override("font_size", 12)
	row.add_child(range_label)
	for direction: int in [-1, 1]:
		var button := Button.new()
		button.text = "−" if direction < 0 else "+"
		button.tooltip_text = "减小雷达范围" if direction < 0 else "增大雷达范围"
		button.custom_minimum_size = Vector2(24, 24)
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_stylebox_override("normal", UISkin.flat(Color.TRANSPARENT, UISkin.ICE, 2))
		button.add_theme_stylebox_override("hover", UISkin.flat(Color(0.1, 0.25, 0.3, 0.5), UISkin.ICE, 2))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): scale_index = clampi(scale_index + direction, 0, scales.size() - 1); refresh())
		row.add_child(button)
	radar = Radar.new()
	radar.host = self
	radar.tooltip_text = "左键拖动观察 · 双击总览接近 · 滚轮缩放\n雷达以舰首向上。内部为当前量程内的局部回波；边缘带外向箭头的是远程地点或天体航向，并非量程内回波。上下箭头表示相对高度。"
	radar.custom_minimum_size = Vector2(200, 186)
	layout.add_child(radar)
	selection_frame = PanelContainer.new()
	selection_frame.name = "SelectedContact"
	selection_frame.add_theme_stylebox_override("panel", UISkin.plate())
	selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selection_frame)
	UISkin.decorate(selection_frame, 0.28)
	selection_label = Label.new()
	selection_label.add_theme_font_size_override("font_size", 13)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_frame.add_child(selection_label)
	target_caption = Label.new()
	target_caption.name = "WorldTargetCaption"
	target_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_caption.clip_text = true
	target_caption.add_theme_font_override("font", UISkin.font())
	target_caption.add_theme_font_size_override("font_size", 13)
	target_caption.add_theme_constant_override("outline_size", 0)
	target_caption.add_theme_constant_override("shadow_outline_size", 0)
	target_caption.add_theme_constant_override("shadow_offset_x", 0)
	target_caption.add_theme_constant_override("shadow_offset_y", 0)
	target_caption.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	var backing: StyleBoxFlat = UISkin.flat(Color(0.007, 0.02, 0.03, 0.9), Color(0.2, 0.3, 0.34, 0.45), 6)
	backing.content_margin_top = 3
	backing.content_margin_bottom = 3
	target_caption.add_theme_stylebox_override("normal", backing)
	add_child(target_caption)
	target_caption.hide()

func configure(sector: Node3D, camera_rig: Node3D, catalog: RefCounted) -> void:
	world = sector
	rig = camera_rig
	sensor_limit = float(catalog.rule("target_marker_detection_range_m"))
	refresh()

func radius_m() -> float:
	return minf(scales[clampi(scale_index, 0, scales.size() - 1)], sensor_limit) if not scales.is_empty() else sensor_limit

func _render_ship_transform() -> Transform3D:
	# Reuse the pose that the camera sampled for this render frame. Eligibility,
	# distances and all gameplay keep using the current physics transforms.
	if is_instance_valid(rig) and rig.has_method("render_ship_transform"):
		return rig.call("render_ship_transform")
	return world.flight.get_global_transform_interpolated()

func _target_distance(id: String, node: Node3D) -> float:
	if world.has_method("target_distance"): return float(world.call("target_distance", id))
	# Legacy presentation-only fixtures have no strategic coordinates.
	return world.flight.global_position.distance_to(node.global_position)

func _target_is_local(id: String) -> bool:
	if world.has_method("target_is_render_local"): return bool(world.call("target_is_render_local", id))
	return bool(world.call("target_is_local", id)) if world.has_method("target_is_local") else true

func _target_direction(id: String, node: Node3D) -> Vector3:
	return world.call("target_direction", id) if world.has_method("target_direction") else world.flight.global_position.direction_to(node.global_position)

func _render_target_position(node: Node3D, id: String = "") -> Vector3:
	if not id.is_empty() and not _target_is_local(id) and is_instance_valid(rig) and is_instance_valid(rig.camera):
		# A remote hidden node only stores its site's local encoding. Project its
		# true strategic direction within the far plane; never project that code.
		return rig.camera.global_position + _target_direction(id, node) * rig.camera.far * 0.7
	return node.get_global_transform_interpolated().origin

func refresh() -> void:
	contacts.clear()
	if not is_instance_valid(world) or not is_instance_valid(world.flight): return
	var render_ship: Transform3D = _render_ship_transform()
	for target: Dictionary in world.targets.values():
		var node: Variant = target.get("node")
		if not is_instance_valid(node) or not node is Node3D: continue
		var id: String = str(target.id)
		var distance: float = _target_distance(id, node)
		if world.has_method("contact_visible") and not world.call("contact_visible", target, distance): continue
		var bearing: bool = bool(target.get("navigation_only", false)) or not _target_is_local(id)
		var relative: Vector3 = render_ship.basis.inverse() * _target_direction(id, node) if bearing else render_ship.basis.inverse() * (_render_target_position(node, id) - render_ship.origin)
		if not bearing and distance > minf(radius_m(), sensor_limit): continue
		contacts.append({"id": id, "title": str(target.title), "kind": str(target.kind), "relative": relative, "height_m": float(relative.y) * distance if bearing else float(relative.y), "distance_m": distance, "bearing": bearing})
	if is_instance_valid(range_label): range_label.text = ("雷达 " if size.x < 950 else "局部态势 · ") + XJSpaceUnits.distance(radius_m())
	if is_instance_valid(radar): radar.queue_redraw()
	_update_selection()
	queue_redraw()

func responsive(viewport_size: Vector2) -> void:
	var compact: bool = viewport_size.x < 950
	var safe: float = 14 if compact else 22
	radar_frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	radar_frame.offset_left = safe
	radar_frame.offset_right = safe + (174 if compact else 236)
	radar_frame.offset_bottom = -48 if compact else -54
	radar_frame.offset_top = -204 if compact else -300
	var inset: StyleBox = UISkin.plate()
	inset.content_margin_top = 6 if compact else 12
	inset.content_margin_bottom = 6 if compact else 12
	radar_frame.add_theme_stylebox_override("panel", inset)
	radar.custom_minimum_size = Vector2(146, 112) if compact else Vector2(200, 186)
	selection_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	selection_frame.offset_left = -minf(190, viewport_size.x * 0.2)
	selection_frame.offset_right = -selection_frame.offset_left
	selection_frame.offset_top = 12 if compact else 18
	selection_frame.offset_bottom = 64 if compact else 86
	selection_frame.visible = selection_readout_enabled and selection_frame.visible and not compact

func radar_point(contact: Dictionary, canvas_size: Vector2) -> Vector2:
	var center := canvas_size * Vector2(0.5, 0.47)
	var radius := minf(canvas_size.x * 0.42, canvas_size.y * 0.39)
	var offset: Vector3 = contact.relative
	var planar := Vector2(offset.x, offset.z)
	if bool(contact.bearing):
		var direction: Vector2 = planar.normalized() if planar.length_squared() > 0.0001 else Vector2(0, -1 if offset.y >= 0 else 1)
		return center + direction * radius
	return center + planar / maxf(radius_m(), 1.0) * radius

func contact_color(kind: String) -> Color:
	if kind == "npc": return Color("ee816e")
	if kind == "planet": return UISkin.AMBER
	if kind == "gate": return Color("b7c9e8")
	return UISkin.ICE

func target_geometry() -> Dictionary:
	if not is_instance_valid(world) or not is_instance_valid(rig) or not is_instance_valid(rig.camera) or not world.targets.has(selected_id): return {}
	var entry: Dictionary = world.targets[selected_id]
	var node: Variant = entry.get("node")
	if not is_instance_valid(node) or not node is Node3D or not is_instance_valid(world.flight): return {}
	var camera: Camera3D = rig.camera
	var inverse: Transform3D = camera.global_transform.affine_inverse()
	var render_ship_position: Vector3 = _render_ship_transform().origin
	var render_target_position: Vector3 = _render_target_position(node, selected_id)
	var ship_local: Vector3 = inverse * render_ship_position
	var from: Vector2 = size * 0.5 if ship_local.z >= -0.001 else camera.unproject_position(render_ship_position)
	var local: Vector3 = inverse * render_target_position
	var behind: bool = local.z >= -0.001
	var point: Vector2
	if behind:
		var direction := Vector2(local.x, -local.y)
		if direction.length_squared() < 0.001: direction = Vector2(0, -1)
		point = size * 0.5 + direction.normalized() * size.length()
	else: point = camera.unproject_position(render_target_position)
	var bounds := Rect2(Vector2(40, 40), size - Vector2(80, 80))
	var on_screen: bool = not behind and bounds.has_point(point)
	if not on_screen:
		var direction: Vector2 = (point - size * 0.5).normalized()
		var half := size * 0.5 - Vector2(40, 40)
		var factor: float = minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		point = size * 0.5 + direction * factor
	return {"start": from, "end": point, "on_screen": on_screen, "behind": behind, "kind": str(entry.kind), "title": str(entry.title), "distance_m": _target_distance(selected_id, node), "bearing": bool(entry.get("navigation_only", false)) or not _target_is_local(selected_id), "navigation_only": bool(entry.get("navigation_only", false))}

func _update_selection() -> void:
	if not is_instance_valid(selection_frame): return
	var geometry := target_geometry()
	selection_frame.visible = selection_readout_enabled and not geometry.is_empty() and size.x >= 950 and not selection_obstructed
	if geometry.is_empty(): return
	selection_label.text = "已选定 · " + str(geometry.title) + "\n距离 " + XJSpaceUnits.distance(float(geometry.distance_m)) + (" · 航向参考" if geometry.navigation_only else " · 远程地点" if geometry.bearing else "")
	selection_label.add_theme_color_override("font_color", contact_color(str(geometry.kind)))

func _process(_delta: float) -> void:
	update_annotations()

func update_annotations() -> void:
	if not is_visible_in_tree():
		if is_instance_valid(target_caption): target_caption.hide()
		return
	_update_selection()
	var geometry := target_geometry()
	if is_instance_valid(target_caption):
		var title: String = "" if geometry.is_empty() else str(geometry.title) + " · " + XJSpaceUnits.distance(float(geometry.distance_m)) + (" · 航向" if geometry.bearing else "")
		var area := Rect2() if geometry.is_empty() else caption_rect(title, geometry.end)
		target_caption.visible = area.has_area()
		if area.has_area():
			target_caption.text = title
			target_caption.tooltip_text = title
			target_caption.position = area.position.round()
			target_caption.size = area.size.ceil()
			target_caption.add_theme_color_override("font_color", contact_color(str(geometry.kind)))
	queue_redraw()

func marker_geometry() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if not is_instance_valid(world) or not is_instance_valid(world.flight) or not is_instance_valid(rig) or not is_instance_valid(rig.camera): return markers
	for entry: Dictionary in world.targets.values():
		if str(entry.id) == selected_id: continue
		var node: Variant = entry.get("node")
		if not is_instance_valid(node) or not node is Node3D: continue
		var id: String = str(entry.id)
		var distance: float = _target_distance(id, node)
		if world.has_method("contact_visible") and not world.call("contact_visible", entry, distance): continue
		var bearing: bool = bool(entry.get("navigation_only", false)) or not _target_is_local(id)
		if not bearing and distance > sensor_limit: continue
		var render_target_position: Vector3 = _render_target_position(node, id)
		if (rig.camera.global_transform.affine_inverse() * render_target_position).z >= -0.001: continue
		var point: Vector2 = rig.camera.unproject_position(render_target_position)
		if Rect2(Vector2.ZERO, size).has_point(point): markers.append({"id": id, "point": point, "color": contact_color(str(entry.kind)), "bearing": bearing})
	return markers

func caption_rect(title: String, finish: Vector2) -> Rect2:
	# Compact HUD already repeats this information in its target module.
	if size.x < 950: return Rect2()
	var text_size: Vector2 = UISkin.font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, 290, 13)
	text_size.x = minf(text_size.x, 290)
	text_size.y = UISkin.font().get_height(13)
	text_size += Vector2(12, 6)
	for candidate: Vector2 in [finish + Vector2(24, -text_size.y - 5), finish - Vector2(text_size.x + 24, text_size.y + 5), finish + Vector2(-text_size.x * 0.5, 25), finish - Vector2(text_size.x * 0.5, text_size.y + 30)]:
		var point := Vector2(clampf(candidate.x, 12, maxf(12, size.x - text_size.x - 12)), clampf(candidate.y, 12, maxf(12, size.y - text_size.y - 12)))
		var area := Rect2(point, text_size)
		if not caption_obstacles.any(func(obstacle: Rect2): return area.grow(4).intersects(obstacle)):
			return area
	return Rect2()

func _draw() -> void:
	if not is_visible_in_tree(): return
	for marker: Dictionary in marker_geometry():
		if bool(marker.bearing): draw_polyline(PackedVector2Array([marker.point + Vector2(0, -6), marker.point + Vector2(5, 4), marker.point + Vector2(-5, 4), marker.point + Vector2(0, -6)]), marker.color, 1.0, true)
		else: draw_arc(marker.point, 8, 0, TAU, 24, marker.color, 1.2, true)
	var geometry := target_geometry()
	if geometry.is_empty(): return
	var start: Vector2 = geometry.start
	var finish: Vector2 = geometry.end
	var delta: Vector2 = finish - start
	var direction: Vector2 = delta.normalized()
	var color: Color = contact_color(str(geometry.kind))
	# A subdued white dashed bearing; target/radar colors keep their own meaning.
	for offset: float in range(14, int(delta.length()), 17):
		draw_line(start + direction * offset, start + direction * minf(offset + 9, delta.length()), Color(1, 1, 1, 0.45), 1.1, true)
	# Corner brackets identify the target without tracing a second model outline.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var point := finish + corner * 20
		draw_line(point, point - Vector2(corner.x * 7, 0), color, 1.3, true)
		draw_line(point, point - Vector2(0, corner.y * 7), color, 1.3, true)
	if not geometry.on_screen:
		var normal := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([finish + direction * 8, finish - direction * 6 + normal * 5, finish - direction * 6 - normal * 5]), color)
