class_name XJSector
extends Node3D
## Scene is a projection of typed state; no node is persisted.
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const Factory = preload("res://runtime/visuals/industrial_visual_factory.gd")
const StationVisual = preload("res://runtime/visuals/station_visual_adapter.gd")
const Celestials = preload("res://runtime/celestial_backdrop.gd")
var state: XJRuntimeState
var catalog: XJCatalog
var gameplay: RefCounted
var flight: XJFlight
var projectiles: XJProjectiles
var definitions: Dictionary = {}
var targets: Dictionary = {}
var npcs: Dictionary = {}
var last_error: String = ""
var factory: Script

func build(runtime: XJRuntimeState, db: XJCatalog, business: RefCounted) -> bool:
	state = runtime
	catalog = db
	gameplay = business
	if state.ship() == null:
		last_error = "缺少可驾驶舰船"
		return false
	factory = Factory
	for anchor in catalog.rows("anchor_defs"):
		if anchor.sector_id == state.current_sector():
			definitions[anchor.anchor_id] = anchor
	_make_environment()
	for station in catalog.rows("station_defs"):
		if station.sector_id == state.current_sector():
			var body: StaticBody3D = Factory.static_body("station", station.station_id)
			if not StationVisual.apply(body):
				if body != null: body.free()
				last_error = "空间站表现资源不可用：" + str(station.station_id)
				return false
			body.collision_layer = 65
			body.collision_mask = 2
			add_child(body)
			body.position = anchor_position(station.station_anchor_id)
			_target(station.station_id, station.display_name, "station", body, station.station_anchor_id)
	for endpoint in catalog.rows("gate_endpoint_defs"):
		if endpoint.origin_sector_id == state.current_sector():
			var visual: StaticBody3D = Factory.static_body("gate", endpoint.endpoint_id)
			visual.collision_layer = 65
			visual.collision_mask = 2
			add_child(visual)
			visual.position = anchor_position(endpoint.entry_anchor_id)
			visual.rotation.y = float(definitions[endpoint.entry_anchor_id].yaw_rad)
			var destination: Dictionary = catalog.one("sector_defs", "sector_id", endpoint.target_sector_id)
			var system: Dictionary = catalog.one("system_defs", "system_id", destination.get("system_id", ""))
			_target(endpoint.endpoint_id, "虫洞 · " + str(system.get("display_name", endpoint.target_sector_id)), "gate", visual, endpoint.entry_anchor_id)
	for location in catalog.rows("resource_node_locations"):
		if not definitions.has(location.anchor_id):
			continue
		var resource: Dictionary = catalog.one("resource_node_defs", "node_id", location.node_id)
		var item: Dictionary = catalog.one("item_defs", "item_id", resource.item_id)
		var body: StaticBody3D = Factory.static_body("ore", location.node_id, str(resource.item_id))
		body.collision_layer = 65
		body.collision_mask = 2
		add_child(body)
		body.position = anchor_position(location.anchor_id)
		_target(location.node_id, str(item.display_name) + "矿体", "resource", body, location.anchor_id)
	for signal_def in catalog.rows("signal_defs"):
		if definitions.has(signal_def.anchor_id):
			var marker := _beacon()
			add_child(marker)
			marker.position = anchor_position(signal_def.anchor_id)
			_target(signal_def.signal_id, signal_def.display_name, "signal", marker, signal_def.anchor_id)
	for key in definitions:
		var anchor: Dictionary = definitions[key]
		if anchor.anchor_kind == "flight_marker":
			var marker := _beacon()
			add_child(marker)
			marker.position = anchor_position(key)
			_target(key, "教学航路标 · " + str(key).get_slice("_", 3), "marker", marker, key)
	projectiles = XJProjectiles.new()
	add_child(projectiles)
	projectiles.setup(catalog)
	if not rebuild_player():
		return false
	return sync_entities()

func rebuild_player() -> bool:
	var row := state.ship()
	var source: CharacterBody3D
	source = factory.scene(row.ship_def_id)
	if source == null:
		last_error = "舰船资源不可用：" + row.ship_def_id
		return false
	var replacement := XJFlight.new()
	for child in source.get_children():
		source.remove_child(child)
		_clear_owners(child)
		replacement.add_child(child)
	replacement.visual = replacement.get_node_or_null("VisualRoot") as Node3D
	if replacement.visual == null:
		source.free()
		replacement.free()
		last_error = "舰船视觉结构不可用：" + row.ship_def_id
		return false
	replacement.visual.set_meta("visual_asset_version", source.get_meta("visual_asset_version", ""))
	source.free()
	replacement.bind(row, catalog)
	XJSurfaceStyle.apply_ship(replacement.visual)
	add_child(replacement)
	if is_instance_valid(flight):
		flight.queue_free()
	flight = replacement
	return true

func _clear_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owners(child)

func sync_entities() -> bool:
	for row: Dtos.NpcStateDto in state.rows("npc_state"):
		if row.sector_id != state.current_sector():
			continue
		if not row.alive:
			if npcs.has(row.npc_instance_id):
				npcs[row.npc_instance_id].queue_free()
				npcs.erase(row.npc_instance_id)
				targets.erase(row.npc_instance_id)
			continue
		if not npcs.has(row.npc_instance_id):
			var spawn: Dictionary = catalog.one("npc_spawn_defs", "spawn_id", row.spawn_id)
			var definition: Dictionary = catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
			var body: CharacterBody3D = factory.enemy_scene(str(definition.archetype_id))
			if body == null:
				last_error = "敌舰表现资源不可用：" + str(definition.archetype_id)
				return false
			XJSurfaceStyle.apply_ship(body)
			body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
			body.collision_layer = 2
			body.collision_mask = 3
			body.set_meta("entity_id", row.npc_instance_id)
			body.set_meta("entity_kind", "npc")
			add_child(body)
			body.position = Vector3(row.pos_x, row.pos_y, row.pos_z)
			body.quaternion = Quaternion(row.quat_x, row.quat_y, row.quat_z, row.quat_w).normalized()
			npcs[row.npc_instance_id] = body
			_target(row.npc_instance_id, "%s · Lv.%d" % [definition.display_name, definition.level], "npc", body, spawn.anchor_id)
	for container: Dtos.ContainerStateDto in state.rows("container_state"):
		if container.kind != Types.ContainerKind.WRECK or container.sector_id != state.current_sector() or targets.has(container.container_id):
			continue
		var wreck := _visual("wreck")
		add_child(wreck)
		wreck.position = Vector3(container.pos_x, container.pos_y, container.pos_z)
		_target(container.container_id, "可回收残骸", "wreck", wreck, "")
	return true

func simulate_npcs(delta: float) -> void:
	if not is_instance_valid(flight):
		return
	for id in npcs:
		var row := state.find("npc_state", "npc_instance_id", id) as Dtos.NpcStateDto
		if row == null or not row.alive:
			continue
		var body: CharacterBody3D = npcs[id]
		var spawn: Dictionary = catalog.one("npc_spawn_defs", "spawn_id", row.spawn_id)
		var behavior: Dictionary = catalog.one("npc_behavior_defs", "behavior_id", spawn.behavior_id)
		var definition: Dictionary = catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
		var home := anchor_position(spawn.anchor_id)
		var distance := body.position.distance_to(flight.position)
		var visible := line_of_sight(body.position, flight.position, body.get_rid(), flight.record.ship_instance_id)
		var can_acquire := flight.record.status == Types.ShipStatus.FLYING and not in_safe_zone(flight.position) and not in_safe_zone(body.position)
		var destination := home
		var should_move := true
		row.cooldown_remaining_s = maxf(0.0, row.cooldown_remaining_s - delta)
		match row.behavior_phase:
			Types.NpcPhase.IDLE, Types.NpcPhase.PATROL:
				row.behavior_phase = Types.NpcPhase.PATROL
				var points: Array[Dictionary] = []
				for point in catalog.rows("npc_patrol_points"):
					if point.spawn_id == row.spawn_id:
						points.append(point)
				if not points.is_empty():
					var point: Dictionary = points[row.patrol_point_index % points.size()]
					destination = anchor_position(point.anchor_id) if point.has("anchor_id") else Vector3(point.x_m, point.y_m, point.z_m)
					if body.position.distance_to(destination) <= float(behavior.return_radius_m):
						row.wait_remaining_s += delta
						should_move = false
						if row.wait_remaining_s >= float(behavior.patrol_wait_s):
							row.patrol_point_index += 1
							row.wait_remaining_s = 0.0
				if can_acquire and distance <= float(behavior.detection_range_m) and visible:
					row.behavior_phase = Types.NpcPhase.ACQUIRE
					row.wait_remaining_s = float(behavior.reaction_s)
			Types.NpcPhase.ACQUIRE:
				should_move = false
				row.wait_remaining_s = maxf(0.0, row.wait_remaining_s - delta)
				if row.wait_remaining_s <= 0.0:
					row.behavior_phase = Types.NpcPhase.PURSUE
			Types.NpcPhase.PURSUE, Types.NpcPhase.ATTACK:
				destination = flight.position
				row.wait_remaining_s = 0.0 if visible else row.wait_remaining_s + delta
				if not can_acquire or distance > float(behavior.target_drop_range_m) or body.position.distance_to(home) > float(behavior.leash_radius_m) or row.wait_remaining_s >= float(behavior.los_loss_timeout_s):
					row.behavior_phase = Types.NpcPhase.DISENGAGE
					row.wait_remaining_s = float(behavior.reaction_s)
				elif distance <= float(definition.range_m) and visible:
					row.behavior_phase = Types.NpcPhase.ATTACK
					should_move = distance > float(definition.range_m) * float(behavior.preferred_range_ratio)
					var direction := body.position.direction_to(flight.position)
					if row.cooldown_remaining_s <= 0.0 and (-body.basis.z).angle_to(direction) <= float(behavior.fire_cone_half_angle_rad):
						var amount: float = float(definition.raw_dps) * float(behavior.attack_cycle_s)
						var raw := Vector3.ZERO
						match definition.damage_type:
							"kinetic": raw.x = amount
							"thermal": raw.y = amount
							"pulse": raw.z = amount
						var muzzle := body.get_node_or_null("Hardpoints/weapon_0/muzzle") as Node3D
						var origin := muzzle.global_position if muzzle != null else body.global_position
						projectiles.fire(id, body.get_rid(), origin, origin.direction_to(flight.global_position), float(behavior.projectile_speed_mps) if behavior.projectile_speed_mps != null else 0.0, float(definition.range_m), raw)
						gameplay.call("mark_hostile_attempt")
						row.cooldown_remaining_s = float(behavior.attack_cycle_s)
				else:
					row.behavior_phase = Types.NpcPhase.PURSUE
			Types.NpcPhase.DISENGAGE:
				row.wait_remaining_s = maxf(0.0, row.wait_remaining_s - delta)
				if row.wait_remaining_s <= 0.0:
					row.behavior_phase = Types.NpcPhase.RETURN
			Types.NpcPhase.RETURN:
				if body.position.distance_to(home) <= float(behavior.return_radius_m):
					row.behavior_phase = Types.NpcPhase.PATROL
					row.wait_remaining_s = 0.0
		var direction := body.position.direction_to(destination)
		if direction.length_squared() > 0.0:
			var wanted := Basis.looking_at(direction, Vector3.UP)
			var angle := body.quaternion.angle_to(wanted.get_rotation_quaternion())
			body.quaternion = body.quaternion.slerp(wanted.get_rotation_quaternion(), minf(1.0, float(behavior.turn_rad_s) * delta / maxf(angle, 0.00001)))
		var desired := direction * float(definition.speed_mps) if should_move else Vector3.ZERO
		body.velocity = body.velocity.move_toward(desired, float(behavior.acceleration_mps2) * delta)
		body.move_and_slide()
		row.pos_x = body.position.x
		row.pos_y = body.position.y
		row.pos_z = body.position.z
		row.vel_x = body.velocity.x
		row.vel_y = body.velocity.y
		row.vel_z = body.velocity.z
		row.quat_x = body.quaternion.x
		row.quat_y = body.quaternion.y
		row.quat_z = body.quaternion.z
		row.quat_w = body.quaternion.w

func anchor_position(id: String) -> Vector3:
	var anchor: Dictionary = definitions.get(id, catalog.one("anchor_defs", "anchor_id", id))
	return Vector3(float(anchor.get("x_m", 0.0)), float(anchor.get("y_m", 0.0)), float(anchor.get("z_m", 0.0)))

func line_of_sight(from: Vector3, to: Vector3, excluded: RID = RID(), target_id: String = "") -> bool:
	var exclusions: Array[RID] = []
	if excluded.is_valid():
		exclusions.append(excluded)
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, exclusions)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.collider
	return not target_id.is_empty() and collider.has_meta("entity_id") and str(collider.get_meta("entity_id")) == target_id

func in_safe_zone(point: Vector3) -> bool:
	for key in definitions:
		var anchor: Dictionary = definitions[key]
		if anchor.anchor_kind == "station" and point.distance_to(anchor_position(key)) <= float(anchor.safe_radius_m):
			return true
	return false

func _target(id: String, title: String, kind: String, node: Node3D, anchor_id: String) -> void:
	targets[id] = {"id": id, "title": title, "kind": kind, "node": node, "anchor_id": anchor_id}

func _visual(kind: String, parameter: String = "") -> Node3D:
	match kind:
		"wreck": return Factory.wreck()
		"enemy": return Factory.enemy(parameter)
		"ore": return Factory.ore(parameter)
		"gate": return Factory.gate()
		"station": return Factory.station()
	return _beacon()

func _beacon() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := TorusMesh.new()
	shape.inner_radius = 8.0
	shape.outer_radius = 10.0
	node.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.7, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.7, 0.9)
	material.emission_energy_multiplier = 3.0
	node.material_override = material
	node.rotation.x = PI * 0.5
	return node

func _make_environment() -> void:
	var space: Node3D = Factory.space_background({"visual_seed": float(state.current_sector().hash() % 1000), "nebula_color": Color(0.025, 0.048, 0.06), "nebula_accent": Color(0.061, 0.046, 0.032)})
	var world_environment: WorldEnvironment = space.get_child(0)
	world_environment.environment.ambient_light_color = Color(0.38, 0.4, 0.43)
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = preload("res://assets/navigation_v3/space_panorama.png")
	panorama.energy_multiplier = 0.65
	world_environment.environment.sky.sky_material = panorama
	world_environment.environment.sky_rotation = Vector3(0, float(absi(state.current_sector().hash()) % 1000) / 1000.0 * TAU, 0)
	add_child(space)
	Celestials.build(self, state.current_sector())
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.89)
	sun.light_energy = 2.0
	sun.rotation_degrees = Vector3(-35, -30, 0)
	add_child(sun)
	var warm := DirectionalLight3D.new()
	warm.light_color = Color(0.57, 0.65, 0.71)
	warm.light_energy = 0.65
	warm.rotation_degrees = Vector3(30, 140, 0)
	add_child(warm)
