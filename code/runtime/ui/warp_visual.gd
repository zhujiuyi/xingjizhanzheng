class_name XJWarpVisual
extends Control
## Read-only warp presentation. No motion, damage, gameplay RNG or save state.
const BLUR_SHADER = preload("res://runtime/ui/warp_environment.gdshader")
const Types = preload("res://contracts/contract_types.gd")
const FX_KEYS: Array[String] = ["warp_fx_fade_in_s", "warp_fx_fade_out_s", "warp_fx_warmup_strength", "warp_fx_blur_radius_px", "warp_fx_blur_lod", "warp_fx_fov_add_deg", "warp_fx_mask_padding_ratio", "warp_fx_mask_feather_px", "warp_fx_center_clear_ratio", "warp_fx_streak_count", "warp_fx_streak_radius_ship_lengths", "warp_fx_streak_length_ship_lengths", "warp_fx_streak_extent_ship_lengths", "warp_fx_streak_speed_ship_lengths_s", "warp_fx_streak_width_ship_lengths", "warp_fx_streak_alpha", "warp_fx_warmup_speed_ratio"]
var elapsed: float = 0.0
var phase: String = "idle"
var strength: float = 1.0
var last_error: String = ""
var configured: bool = false
var envelope: float = 0.0
var config: Dictionary = {}
var ship_rect: Rect2 = Rect2()
var stream_heading: Vector3 = Vector3.FORWARD
var stream: MeshInstance3D
var _scene: Node3D
var _rig: XJCameraRig
var _blur: ColorRect
var _material: ShaderMaterial
var _mesh: ImmediateMesh
var _stream_material: StandardMaterial3D
var _ship: XJFlight
var _hull_bounds: AABB
var _transition_from: float = 0.0
var _transition_to: float = 0.0
var _transition_elapsed: float = 0.0
var _transition_duration: float = 0.0
var _stream_distance_ship_lengths: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur = ColorRect.new()
	_blur.name = "WarpEnvironmentBlur"
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = BLUR_SHADER
	_blur.material = _material
	add_child(_blur)
	hide()

func _exit_tree() -> void:
	unbind()

func bind(scene: Node3D, rig: XJCameraRig, parameters: Dictionary) -> bool:
	unbind()
	last_error = ""
	if not is_instance_valid(scene) or not is_instance_valid(rig): return _fail("跃迁表现缺少场景或相机")
	for key: String in FX_KEYS:
		if not parameters.has(key) or not is_finite(float(parameters[key])) or float(parameters[key]) < 0.0:
			return _fail("跃迁表现数据库参数缺失或无效：" + key)
	for key: String in ["warp_fx_fade_in_s", "warp_fx_fade_out_s", "warp_fx_mask_feather_px", "warp_fx_streak_radius_ship_lengths", "warp_fx_streak_length_ship_lengths", "warp_fx_streak_extent_ship_lengths", "warp_fx_streak_speed_ship_lengths_s", "warp_fx_streak_width_ship_lengths"]:
		if float(parameters[key]) <= 0.0: return _fail("跃迁表现数据库参数必须大于零：" + key)
	if float(parameters.warp_fx_mask_padding_ratio) < 1.0 or float(parameters.warp_fx_warmup_strength) > 1.0 or float(parameters.warp_fx_streak_alpha) > 1.0 or float(parameters.warp_fx_center_clear_ratio) >= 1.0 or float(parameters.warp_fx_warmup_speed_ratio) > 1.0:
		return _fail("跃迁表现数据库比例超出范围")
	var count: float = float(parameters.warp_fx_streak_count)
	if count < 8.0 or count > 256.0 or count != floorf(count): return _fail("跃迁表现流线数量必须是 8 至 256 的整数")
	for key: String in FX_KEYS: config[key] = float(parameters[key])
	_scene = scene
	_rig = rig
	_scene.tree_exiting.connect(unbind)
	_mesh = ImmediateMesh.new()
	_stream_material = StandardMaterial3D.new()
	_stream_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stream_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stream_material.vertex_color_use_as_albedo = true
	_stream_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	stream = MeshInstance3D.new()
	stream.name = "WarpDirectionalStream"
	stream.mesh = _mesh
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stream.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	stream.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	stream.hide()
	_scene.add_child(stream)
	configured = true
	return true

func unbind() -> void:
	# World switches and menu returns must remove the lens offset immediately,
	# including when no further simulation/render callback will be delivered.
	if is_instance_valid(_rig): _rig.set_warp_fov_offset(0.0)
	if is_instance_valid(_scene) and _scene.tree_exiting.is_connected(unbind): _scene.tree_exiting.disconnect(unbind)
	if is_instance_valid(stream): stream.free()
	stream = null
	_mesh = null
	_stream_material = null
	_scene = null
	_rig = null
	_ship = null
	config.clear()
	configured = false
	elapsed = 0.0
	phase = "idle"
	envelope = 0.0
	_transition_from = 0.0
	_transition_to = 0.0
	_transition_elapsed = 0.0
	_stream_distance_ship_lengths = 0.0
	ship_rect = Rect2()
	if is_instance_valid(_material): _material.set_shader_parameter("effect_strength", 0.0)
	hide()

func update_navigation(next_phase: String, delta: float, intensity: float, paused: bool) -> void:
	# Keep the existing call shape. Bind() supplies all dimensional/visual
	# parameters from the versioned SQLite extension, never script defaults.
	var active_phase: bool = next_phase in ["warmup", "travel"]
	strength = clampf(intensity, 0.0, 1.0) if is_finite(intensity) else 0.0
	if not configured:
		phase = next_phase
		hide()
		return
	if not is_instance_valid(_scene) or not is_instance_valid(_rig) or not is_instance_valid(_rig.ship):
		unbind()
		return
	if _rig.ship.record == null or _rig.ship.record.status != Types.ShipStatus.FLYING:
		phase = "idle"
		envelope = 0.0
		_transition_from = 0.0
		_transition_to = 0.0
		_transition_elapsed = 0.0
		_rig.set_warp_fov_offset(0.0)
		_material.set_shader_parameter("effect_strength", 0.0)
		stream.hide()
		_mesh.clear_surfaces()
		hide()
		return
	if next_phase != phase:
		if active_phase and phase not in ["warmup", "travel"]:
			elapsed = 0.0
			_stream_distance_ship_lengths = 0.0
		phase = next_phase
		_transition_from = envelope
		_transition_to = float(config.warp_fx_warmup_strength) if phase == "warmup" else 1.0 if phase == "travel" else 0.0
		_transition_elapsed = 0.0
		_transition_duration = float(config.warp_fx_fade_in_s if _transition_to > envelope else config.warp_fx_fade_out_s)
	var step: float = maxf(0.0, delta) if is_finite(delta) else 0.0
	if not paused:
		if active_phase or envelope > 0.0:
			elapsed += step
			var rate: float = float(config.warp_fx_streak_speed_ship_lengths_s)
			if phase == "warmup": rate *= float(config.warp_fx_warmup_speed_ratio)
			_stream_distance_ship_lengths += step * rate
		_transition_elapsed = minf(_transition_elapsed + step, _transition_duration)
		if _transition_duration > 0.0:
			envelope = float(Tween.interpolate_value(_transition_from, _transition_to - _transition_from, _transition_elapsed, _transition_duration, Tween.TRANS_CUBIC, Tween.EASE_OUT))
	var effect: float = envelope * strength
	visible = effect > 0.0
	if is_instance_valid(stream): stream.visible = visible
	_rig.set_warp_fov_offset(float(config.warp_fx_fov_add_deg) * effect)
	if is_instance_valid(_material): _material.set_shader_parameter("effect_strength", effect)
	if not visible and is_instance_valid(_mesh): _mesh.clear_surfaces()

func update_pose(heading: Vector3 = Vector3.ZERO) -> void:
	# Called after camera.step() and before HUD projections. Use its one cached
	# render pose; never write the physical body, DTO or camera observation.
	if not configured or not visible or not is_instance_valid(_rig) or not is_instance_valid(_rig.ship) or not is_instance_valid(_rig.camera) or not is_instance_valid(stream): return
	if not heading.is_zero_approx() and heading.is_finite(): stream_heading = heading.normalized()
	if not is_instance_valid(_ship) or _ship != _rig.ship:
		_ship = _rig.ship
		_hull_bounds = _ship_visual_bounds(_ship)
	if not _hull_bounds.has_volume():
		_material.set_shader_parameter("effect_strength", 0.0)
		stream.hide()
		return
	var pose: Transform3D = _rig.render_ship_transform()
	var lens: Camera3D = _rig.camera
	var viewport_size: Vector2 = lens.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0: return
	ship_rect = _project_hull(pose, lens, viewport_size) if is_instance_valid(_ship.visual) and _ship.visual.is_visible_in_tree() else Rect2()
	_material.set_shader_parameter("ship_rect_uv", Vector4(ship_rect.position.x, ship_rect.position.y, ship_rect.end.x, ship_rect.end.y))
	_material.set_shader_parameter("protect_ship", ship_rect.has_area())
	_material.set_shader_parameter("mask_feather_px", float(config.warp_fx_mask_feather_px))
	_material.set_shader_parameter("center_clear_ratio", float(config.warp_fx_center_clear_ratio))
	_material.set_shader_parameter("blur_radius_px", float(config.warp_fx_blur_radius_px))
	_material.set_shader_parameter("blur_lod", float(config.warp_fx_blur_lod))
	var view_heading: Vector3 = lens.global_basis.inverse() * stream_heading
	var side_direction: Vector2 = Vector2(-view_heading.x, view_heading.y)
	var side_weight: float = clampf(side_direction.length(), 0.0, 1.0)
	_material.set_shader_parameter("flow_axis", side_direction.normalized() if side_weight > 0.0 else Vector2.ZERO)
	_material.set_shader_parameter("side_weight", side_weight)
	var focus: Vector2 = Vector2(0.5, 0.5)
	if absf(view_heading.z) > 0.000001:
		var forward: Vector3 = stream_heading if view_heading.z < 0.0 else -stream_heading
		focus = lens.unproject_position(lens.global_position + forward * lens.far) / viewport_size
	_material.set_shader_parameter("flow_focus_uv", focus)
	var up: Vector3 = pose.basis.y
	if up.cross(stream_heading).length_squared() < 0.000001: up = pose.basis.x
	stream.global_transform = Transform3D(Basis.looking_at(stream_heading, up), pose.origin)
	_draw_stream(lens)

func _ship_visual_bounds(body: XJFlight) -> AABB:
	var points: Array[Vector3] = []
	if is_instance_valid(body.visual): _collect_bounds(body.visual, body.global_transform.affine_inverse(), points)
	if points.is_empty(): return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points: bounds = bounds.expand(point)
	return bounds

func _collect_bounds(node: Node, inverse: Transform3D, points: Array[Vector3]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance := node as MeshInstance3D
		var bounds: AABB = instance.mesh.get_aabb()
		for index: int in range(8): points.append(inverse * instance.global_transform * bounds.get_endpoint(index))
	for child: Node in node.get_children(): _collect_bounds(child, inverse, points)

func _project_hull(pose: Transform3D, lens: Camera3D, viewport_size: Vector2) -> Rect2:
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	for index: int in range(8):
		var point: Vector3 = pose * _hull_bounds.get_endpoint(index)
		# A near-plane crossing protects the entire screen for this frame rather
		# than creating an invalid projection that could blur part of the hull.
		if lens.is_position_behind(point): return Rect2(Vector2.ZERO, Vector2.ONE)
		var projected: Vector2 = lens.unproject_position(point) / viewport_size
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	var center: Vector2 = (minimum + maximum) * 0.5
	var extent: Vector2 = (maximum - minimum) * float(config.warp_fx_mask_padding_ratio)
	return Rect2(center - extent * 0.5, extent)

func _draw_stream(lens: Camera3D) -> void:
	_mesh.clear_surfaces()
	var length_scale: float = maxf(_hull_bounds.size.x, maxf(_hull_bounds.size.y, _hull_bounds.size.z))
	var extent: float = length_scale * float(config.warp_fx_streak_extent_ship_lengths)
	var radius: float = length_scale * float(config.warp_fx_streak_radius_ship_lengths)
	var width: float = length_scale * float(config.warp_fx_streak_width_ship_lengths)
	var eye: Vector3 = stream.global_transform.affine_inverse() * lens.global_position
	var count: int = int(config.warp_fx_streak_count)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _stream_material)
	for index: int in range(count):
		# Deterministic visual distribution: no RNG stream or persistent state.
		var angle: float = float(index) * 2.399963
		var progress: float = fposmod(_stream_distance_ship_lengths / float(config.warp_fx_streak_extent_ship_lengths) + float(index) * 0.618034, 1.0)
		var radial: float = radius * (0.55 + float(index % 7) / 14.0)
		var start := Vector3(cos(angle) * radial, sin(angle) * radial, (progress - 0.2) * extent)
		var distance: float = length_scale * float(config.warp_fx_streak_length_ship_lengths) * (0.6 + progress * 0.4)
		var alpha: float = sin(progress * PI) * float(config.warp_fx_streak_alpha) * envelope * strength
		_strip(start, start + Vector3.BACK * distance, eye, width, Color(0.67, 0.79, 0.86, alpha))
	# A sparse wake remains recognizably behind the hull when looking sideways.
	for index: int in range(int(float(count) / 9.0)):
		var angle: float = float(index) * 2.399963
		var progress: float = fposmod(_stream_distance_ship_lengths / float(config.warp_fx_streak_extent_ship_lengths) + float(index) * 0.381966, 1.0)
		var radial: float = length_scale * (0.15 + progress * 0.22)
		var start := Vector3(cos(angle) * radial, sin(angle) * radial, length_scale * 0.55 + progress * extent * 0.55)
		var alpha: float = sin(progress * PI) * float(config.warp_fx_streak_alpha) * envelope * strength
		_strip(start, start + Vector3.BACK * length_scale * float(config.warp_fx_streak_length_ship_lengths), eye, width, Color(0.55, 0.75, 0.86, alpha))
	_mesh.surface_end()

func _strip(start: Vector3, end: Vector3, eye: Vector3, width: float, color: Color) -> void:
	var across: Vector3 = (end - start).cross(eye - (start + end) * 0.5).normalized() * width
	if across.is_zero_approx(): across = Vector3.RIGHT * width
	for vertex: Vector3 in [start - across, start + across, end + across, start - across, end + across, end - across]:
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(vertex)

func _fail(message: String) -> bool:
	last_error = message
	return false
