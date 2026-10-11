class_name XJExplorationView
extends RefCounted
var world: Node3D
var fields: Dictionary = {}

func _init(owner_world: Node3D) -> void: world = owner_world

func sync() -> void:
	var service: RefCounted = world.gameplay.exploration
	if not service.supported(): return
	for event: Dictionary in world.catalog.rows("exploration_event_defs"):
		if event.sector_id != world.state.current_sector() or not world.gameplay.unlocked(event.required_unlock_id): continue
		var row: RefCounted = service.instance(event.event_id)
		for exit_point: bool in [false, true]:
			var id: String = ("explore_exit:" if exit_point else "explore:") + str(event.event_id)
			var anchor: String = str(event.exit_anchor_id if exit_point else event.entry_anchor_id)
			if not world.targets.has(id):
				var beacon: Node3D = world._beacon()
				world.add_child(beacon); beacon.position = world.anchor_position(anchor)
				world._target(id, ("撤离点 · " if exit_point else "探索 · ") + str(event.display_name), "exploration_exit" if exit_point else "exploration", beacon, anchor)
				world.targets[id]["event_id"] = event.event_id
			world.targets[id]["status"] = service.status_text(event.event_id)
		if event.environment_kind != "fragments" and not fields.has(event.event_id):
			var marker: Node3D = Node3D.new()
			var sphere: MeshInstance3D = MeshInstance3D.new()
			var mesh: SphereMesh = SphereMesh.new(); mesh.radius = float(service.balance.hazard_radius_m); mesh.height = mesh.radius * 2.0; mesh.radial_segments = 24; mesh.rings = 12
			sphere.mesh = mesh; sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.albedo_color = Color(0.15, 0.45, 0.7, 0.035) if event.environment_kind == "em" else Color(0.9, 0.45, 0.15, 0.025)
			sphere.material_override = material; marker.add_child(sphere)
			world.add_child(marker); marker.position = world.anchor_position(event.entry_anchor_id)
			world._target("exp_field:" + str(event.event_id), "电磁扰动区域" if event.environment_kind == "em" else "恒星喷流区域", "scenery", marker, event.entry_anchor_id)
			fields[event.event_id] = material
		if event.environment_kind == "solar" and fields.has(event.event_id):
			var phase: String = service.hazard_phase(row)
			fields[event.event_id].albedo_color.a = 0.12 if phase == "active" else 0.07 if phase == "warning" else 0.025
	for obstacle: Dictionary in world.catalog.rows("exploration_obstacle_defs"):
		var event: Dictionary = service.definition(obstacle.event_id)
		if event.sector_id != world.state.current_sector() or not world.gameplay.unlocked(event.required_unlock_id): continue
		var id: String = "exp_debris:" + str(obstacle.obstacle_id)
		if world.targets.has(id): continue
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 65; body.collision_mask = 2
		var shape: CollisionShape3D = CollisionShape3D.new()
		var collider: SphereShape3D = SphereShape3D.new(); collider.radius = float(obstacle.radius_m); shape.shape = collider; body.add_child(shape)
		var surface: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new(); mesh.radius = collider.radius; mesh.height = collider.radius * 2; mesh.radial_segments = 12; mesh.rings = 6; surface.mesh = mesh
		var material: StandardMaterial3D = StandardMaterial3D.new(); material.albedo_color = Color(0.2, 0.24, 0.26); material.roughness = 0.92
		surface.material_override = material; body.add_child(surface)
		world.add_child(body); body.position = world.anchor_position(obstacle.anchor_id)
		world._target(id, "碎片遮挡 · %d 米" % int(obstacle.radius_m), "scenery", body, obstacle.anchor_id)
	for node: Dictionary in world.catalog.rows("exploration_resource_defs"):
		var location: Dictionary = world.catalog.one("resource_node_locations", "node_id", node.node_id)
		if location.sector_id != world.state.current_sector(): continue
		var visible: bool = service.resource_visible(node.node_id)
		if not visible:
			if world.targets.has(node.node_id): world._remove_target(node.node_id)
			continue
		if world.targets.has(node.node_id): continue
		var resource: Dictionary = world.catalog.one("resource_node_defs", "node_id", node.node_id)
		var item: Dictionary = world.catalog.one("item_defs", "item_id", resource.item_id)
		var body: StaticBody3D = world.factory.static_body("ore", node.node_id, str(resource.item_id))
		body.collision_layer = 65; body.collision_mask = 2; world.add_child(body); body.position = world.anchor_position(location.anchor_id)
		world._target(node.node_id, "临时矿脉 · " + str(item.display_name), "resource", body, location.anchor_id)
