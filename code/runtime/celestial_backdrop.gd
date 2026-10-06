class_name XJCelestialBackdrop
extends RefCounted
const Navigation = preload("res://runtime/navigation_catalog.gd")

static func build(sector: Node3D, sector_id: String) -> void:
	for row: Dictionary in Navigation.rows("celestial_visual_defs"):
		if row.sector_id != sector_id: continue
		var body := MeshInstance3D.new()
		body.name = "Celestial_" + str(row.celestial_id)
		var shape := SphereMesh.new()
		shape.radius = 1.0 if sector.catalog.table_names.has("celestial_defs") else float(row.render_radius_m)
		shape.height = shape.radius * 2.0
		shape.radial_segments = 64
		shape.rings = 32
		body.mesh = shape
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/navigation_v3/planet.gdshader")
		material.set_shader_parameter("surface_map", preload("res://assets/navigation_v3/planet_surface.png"))
		material.set_shader_parameter("surface_color", Color(str(row.surface_color)))
		material.set_shader_parameter("cloud_color", Color(str(row.cloud_color)))
		material.set_shader_parameter("visual_seed", float(row.visual_seed))
		body.material_override = material
		body.position = Vector3(row.x_m, row.y_m, row.z_m)
		sector.add_child(body)
		body.get_global_transform_interpolated()
		body.reset_physics_interpolation()
		sector.targets[row.celestial_id] = {"id": row.celestial_id, "title": row.display_name, "kind": "planet", "node": body, "anchor_id": "", "navigation_only": true, "description": row.description}
	update(sector)

static func update(sector: Node3D) -> void:
	if not sector.catalog.table_names.has("celestial_defs"): return
	var camera: Camera3D = sector.get_viewport().get_camera_3d()
	if camera == null: return
	var eye: Vector3 = camera.global_position
	var reference: Dictionary = sector.strategic_components(sector.flight.get_global_transform_interpolated().origin if is_instance_valid(sector.flight) else Vector3.ZERO)
	for row: Dictionary in sector.catalog.rows("celestial_defs"):
		if row.sector_id != sector.state.current_sector() or row.celestial_kind != "planet" or not sector.targets.has(row.celestial_id): continue
		var position: Dictionary = {"x": float(row.x_m), "y": float(row.y_m), "z": float(row.z_m)}
		var distance: float = XJSpaceCoordinates.scalar_distance(reference, position)
		if not is_finite(distance) or distance <= 0.0: continue
		var node: Node3D = sector.targets[row.celestial_id].node
		var render_distance: float = camera.far * 0.72
		node.global_position = eye + XJSpaceCoordinates.scalar_direction(reference, position) * render_distance
		node.scale = Vector3.ONE * render_distance * float(row.radius_m) / distance
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
