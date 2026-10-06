class_name XJWarpVisual
extends Control
## Read-only warp presentation. No motion, damage, gameplay RNG or save state.
const BLUR_SHADER = preload("res://runtime/ui/warp_environment.gdshader")
const Types = preload("res://contracts/contract_types.gd")
const FX_KEYS: Array[String] = ["warp_fx_fade_in_s", "warp_fx_fade_out_s", "warp_fx_warmup_strength", "warp_fx_blur_radius_px", "warp_fx_blur_lod", "warp_fx_fov_add_deg", "warp_fx_mask_padding_ratio", "warp_fx_mask_feather_px", "warp_fx_center_clear_ratio", "warp_fx_streak_count", "warp_fx_streak_radius_ship_lengths", "warp_fx_streak_length_ship_lengths", "warp_fx_streak_extent_ship_lengths", "warp_fx_streak_speed_ship_lengths_s", "warp_fx_streak_width_ship_lengths", "warp_fx_streak_alpha", "warp_fx_warmup_speed_ratio", "warp_fx_reference_height_px", "warp_fx_mask_resolution_scale"]
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
var _mask_viewport: SubViewport
var _mask_camera: Camera3D
var _mask_body: Node3D
var _mask_material: StandardMaterial3D
var _mask_meshes: Array[Dictionary] = []
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
	for key: String in ["warp_fx_fade_in_s", "warp_fx_fade_out_s", "warp_fx_mask_feather_px", "warp_fx_streak_radius_ship_lengths", "warp_fx_streak_length_ship_lengths", "warp_fx_streak_extent_ship_lengths", "warp_fx_streak_speed_ship_lengths_s", "warp_fx_streak_width_ship_lengths", "warp_fx_reference_height_px"]:
		if float(parameters[key]) <= 0.0: return _fail("跃迁表现数据库参数必须大于零：" + key)
	if float(parameters.warp_fx_mask_padding_ratio) < 1.0 or float(parameters.warp_fx_warmup_strength) > 1.0 or float(parameters.warp_fx_streak_alpha) > 1.0 or float(parameters.warp_fx_center_clear_ratio) >= 1.0 or float(parameters.warp_fx_warmup_speed_ratio) > 1.0:
		return _fail("跃迁表现数据库比例超出范围")
	if float(parameters.warp_fx_mask_resolution_scale) < 0.25 or float(parameters.warp_fx_mask_resolution_scale) > 1.0:
		return _fail("跃迁舰体轮廓分辨率比例必须在 0.25 至 1 之间")
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
	_create_ship_mask()
	configured = true
	return true

func unbind() -> void:
	# World switches and menu returns must remove the lens offset immediately,
	# including when no further simulation/render callback will be delivered.
	if is_instance_valid(_rig): _rig.set_warp_fov_offset(0.0)
	if is_instance_valid(_scene) and _scene.tree_exiting.is_connected(unbind): _scene.tree_exiting.disconnect(unbind)
	if is_instance_valid(stream): stream.free()
	if is_instance_valid(_material):
		_material.set_shader_parameter("protect_ship", false)
		_material.set_shader_parameter("ship_mask", null)
	if is_instance_valid(_mask_viewport): _mask_viewport.free()
	_mask_viewport = null
	_mask_camera = null
	_mask_body = null
	_mask_material = null
	_mask_meshes.clear()
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
		if is_instance_valid(_mask_viewport): _mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	if not visible and is_instance_valid(_mask_viewport): _mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func update_pose(heading: Vector3 = Vector3.ZERO) -> void:
	# Called after camera.step() and before HUD projections. Use its one cached
	# render pose; never write the physical body, DTO or camera observation.
	if not configured or not visible or not is_instance_valid(_rig) or not is_instance_valid(_rig.ship) or not is_instance_valid(_rig.camera) or not is_instance_valid(stream): return
	if not heading.is_zero_approx() and heading.is_finite(): stream_heading = heading.normalized()
	if not is_instance_valid(_ship) or _ship != _rig.ship:
		_ship = _rig.ship
		_hull_bounds = _ship_visual_bounds(_ship)
		_rebuild_mask_meshes()
	if not _hull_bounds.has_volume():
		_material.set_shader_parameter("effect_strength", 0.0)
		stream.hide()
		return
	var pose: Transform3D = _rig.render_ship_transform()
	var lens: Camera3D = _rig.camera
	var viewport_size: Vector2 = lens.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0: return
	ship_rect = _project_hull(pose, lens, viewport_size) if is_instance_valid(_ship.visual) and _ship.visual.is_visible_in_tree() else Rect2()
	_update_ship_mask(pose, lens, viewport_size)
	# The rectangle is diagnostic ROI only. Actual protection comes from the
	# separately rendered mesh silhouette, so empty sky within it still blurs.
	_material.set_shader_parameter("ship_rect_uv", Vector4(ship_rect.position.x, ship_rect.position.y, ship_rect.end.x, ship_rect.end.y))
	_material.set_shader_parameter("protect_ship", ship_rect.has_area())
	# SCREEN_PIXEL_SIZE is the screen sampler's actual pixel density. Viewport
	# texture getters can include UI oversampling and cannot establish this.
	_material.set_shader_parameter("reference_height_px", float(config.warp_fx_reference_height_px))
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

func _create_ship_mask() -> void:
	# Construct plain nodes explicitly. Duplicating the gameplay ship would
	# also duplicate scripts, physics, particles or persistent/RNG authority.
	_mask_viewport = SubViewport.new()
	_mask_viewport.name = "WarpHullSilhouette"
	_mask_viewport.own_world_3d = true
	_mask_viewport.transparent_bg = false
	_mask_viewport.gui_disable_input = true
	_mask_viewport.handle_input_locally = false
	_mask_viewport.physics_object_picking = false
	_mask_viewport.audio_listener_enable_2d = false
	_mask_viewport.audio_listener_enable_3d = false
	_mask_viewport.oversampling = false
	_mask_viewport.msaa_3d = Viewport.MSAA_2X
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mask_viewport.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_mask_viewport)
	var backdrop := Environment.new()
	backdrop.background_mode = Environment.BG_COLOR
	backdrop.background_color = Color.BLACK
	backdrop.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_mask_camera = Camera3D.new()
	_mask_camera.name = "HullMaskCamera"
	_mask_camera.environment = backdrop
	_mask_camera.current = true
	_mask_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mask_viewport.add_child(_mask_camera)
	_mask_body = Node3D.new()
	_mask_body.name = "HullMeshOnly"
	_mask_body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mask_viewport.add_child(_mask_body)
	_mask_material = StandardMaterial3D.new()
	_mask_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mask_material.albedo_color = Color.WHITE
	_material.set_shader_parameter("ship_mask", _mask_viewport.get_texture())

func _rebuild_mask_meshes() -> void:
	_mask_meshes.clear()
	for child: Node in _mask_body.get_children(): child.free()
	if is_instance_valid(_ship.visual): _collect_mask_meshes(_ship.visual)

func _collect_mask_meshes(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var original := node as MeshInstance3D
		var copy := MeshInstance3D.new()
		copy.name = "HullMaskMesh"
		copy.mesh = original.mesh
		copy.material_override = _mask_material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		copy.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_mask_body.add_child(copy)
		_mask_meshes.append({"source": original, "copy": copy})
	for child: Node in node.get_children(): _collect_mask_meshes(child)

func _update_ship_mask(pose: Transform3D, lens: Camera3D, viewport_size: Vector2) -> void:
	var shown: bool = is_instance_valid(_ship.visual) and _ship.visual.is_visible_in_tree() and ship_rect.has_area()
	_mask_body.visible = shown
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if not shown: return
	# The native window is the physical client; the projection aspect remains
	# the real camera viewport aspect even under 200% UI canvas scaling.
	var render_size := Vector2(lens.get_window().size) if lens.get_viewport() is Window else viewport_size
	var mask_height: int = maxi(2, int(ceil(render_size.y * float(config.warp_fx_mask_resolution_scale))))
	_mask_viewport.size = Vector2i(maxi(2, int(ceil(float(mask_height) * viewport_size.x / viewport_size.y))), mask_height)
	_mask_camera.projection = lens.projection
	_mask_camera.keep_aspect = lens.keep_aspect
	_mask_camera.fov = lens.fov
	_mask_camera.size = lens.size
	_mask_camera.near = lens.near
	_mask_camera.far = lens.far
	_mask_camera.h_offset = lens.h_offset
	_mask_camera.v_offset = lens.v_offset
	_mask_camera.frustum_offset = lens.frustum_offset
	_mask_camera.global_transform = lens.global_transform
	_mask_body.global_transform = pose
	var inverse: Transform3D = _ship.global_transform.affine_inverse()
	for pair: Dictionary in _mask_meshes:
		var original := pair.source as MeshInstance3D
		var copy := pair.copy as MeshInstance3D
		if is_instance_valid(original):
			copy.transform = inverse * original.global_transform
			copy.visible = original.is_visible_in_tree()
		else:
			copy.hide()

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
	# Clip the actual box edges against the near plane. A single corner behind
	# the camera must not turn off background blur across the entire frame.
	var inverse: Transform3D = lens.global_transform.affine_inverse()
	var corners: Array[Vector3] = []
	var visible_points: Array[Vector3] = []
	for index: int in range(8):
		var point: Vector3 = inverse * pose * _hull_bounds.get_endpoint(index)
		corners.append(point)
		if point.z <= -lens.near: visible_points.append(point)
	for edge: Vector2i in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 4), Vector2i(1, 3), Vector2i(1, 5), Vector2i(2, 3), Vector2i(2, 6), Vector2i(3, 7), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 7), Vector2i(6, 7)]:
		var start: Vector3 = corners[edge.x]
		var end: Vector3 = corners[edge.y]
		if (start.z <= -lens.near) == (end.z <= -lens.near): continue
		var weight: float = (-lens.near - start.z) / (end.z - start.z)
		visible_points.append(start.lerp(end, weight))
	if visible_points.is_empty(): return Rect2()
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	for point: Vector3 in visible_points:
		var projected: Vector2 = lens.unproject_position(lens.global_transform * point) / viewport_size
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	var center: Vector2 = (minimum + maximum) * 0.5
	var extent: Vector2 = (maximum - minimum) * float(config.warp_fx_mask_padding_ratio)
	var projected_rect := Rect2(center - extent * 0.5, extent)
	return projected_rect.intersection(Rect2(Vector2.ZERO, Vector2.ONE))

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
		# Each streak has an independent fixed offset, radius, speed and length.
		# This is deterministic visual noise; no gameplay RNG or save state.
		var distribution: Vector3 = _distribution(index)
		var angle: float = distribution.x * TAU
		var progress: float = fposmod(_stream_distance_ship_lengths / float(config.warp_fx_streak_extent_ship_lengths) * (0.75 + distribution.y * 0.5) + distribution.z, 1.0)
		var radial: float = radius * (0.65 + distribution.y * 0.8)
		var start := Vector3(cos(angle) * radial, sin(angle) * radial, (progress - 0.06) * extent)
		var distance: float = length_scale * float(config.warp_fx_streak_length_ship_lengths) * (0.35 + distribution.z * 0.9)
		var alpha: float = sin(progress * PI) * (0.45 + distribution.x * 0.55) * float(config.warp_fx_streak_alpha) * envelope * strength
		_strip(start, start + Vector3.BACK * distance, eye, width * (0.6 + distribution.y * 0.7), Color(0.67, 0.79, 0.86, alpha))
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
	# Soft tapered heads/tails replace uniformly bright ruler-like segments.
	var fractions: PackedFloat32Array = PackedFloat32Array([0.0, 0.14, 0.35, 0.72, 1.0])
	var opacity: PackedFloat32Array = PackedFloat32Array([0.0, 0.85, 1.0, 0.3, 0.0])
	for index: int in range(fractions.size() - 1):
		var head: Vector3 = start.lerp(end, fractions[index])
		var tail: Vector3 = start.lerp(end, fractions[index + 1])
		for corner: int in [0, 1, 3, 0, 3, 2]:
			var at_end: bool = corner >= 2
			var fade: float = opacity[index + 1 if at_end else index]
			var at: Vector3 = tail if at_end else head
			_mesh.surface_set_color(Color(color.r, color.g, color.b, color.a * fade))
			_mesh.surface_add_vertex(at + across * (1.0 if corner % 2 else -1.0) * sqrt(fade))

func _distribution(index: int) -> Vector3:
	# Hash only presentation indices rather than calling any RandomNumberGenerator.
	var seed_value: float = float(index + 1)
	return Vector3(fposmod(sin(seed_value * 127.1) * 43758.5453, 1.0), fposmod(sin(seed_value * 269.5) * 43758.5453, 1.0), fposmod(sin(seed_value * 419.2) * 43758.5453, 1.0))

func _fail(message: String) -> bool:
	last_error = message
	return false
