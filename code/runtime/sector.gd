class_name XJSector
extends Node3D
## Scene is a projection of typed state; no node is persisted.
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const Factory = preload("res://runtime/visuals/civilization_visual_factory.gd")
const StationVisual = preload("res://runtime/visuals/station_visual_adapter.gd")
const Celestials = preload("res://runtime/celestial_backdrop.gd")
const Space = preload("res://runtime/space_coordinates.gd")
const WarFleetPilot = preload("res://runtime/war_fleet_pilot.gd")
var state: XJRuntimeState
var catalog: XJCatalog
var gameplay: RefCounted
var flight: XJFlight
var projectiles: XJProjectiles
var definitions: Dictionary = {}
var targets: Dictionary = {}
var exploration_view: RefCounted
var npcs: Dictionary = {}
var last_error: String = ""
var factory: Script
var visual_environment: Environment
var key_light: DirectionalLight3D
var stellar_position: Vector3
var stellar_disc: MeshInstance3D
var lighting_definition: Dictionary = {}
var strategic_render_position: Dictionary = {}
var collision_site_id: String = ""
var _loaded_site_id: String = ""
## A short departure projection is visual only. The real source nodes stay at
## their encoded site coordinates while strategic navigation advances scalars.
var departure_active: bool = false
var departure_elapsed_s: float = 0.0
var departure_projection: Node3D
var _departure_heading: Vector3 = Vector3.FORWARD
var _departure_duration_s: float = 0.0
var _departure_distance_m: float = 0.0
var _departure_parameters: Dictionary = {}

func _process(_delta: float) -> void:
	update_starlight()
	Celestials.update(self)

func update_starlight() -> void:
	if lighting_definition.is_empty() or not is_instance_valid(key_light):
		return
	var reference: Vector3 = flight.get_global_transform_interpolated().origin if is_instance_valid(flight) else Vector3.ZERO
	var to_star: Vector3 = stellar_position - reference
	var star: Dictionary = {}
	var star_distance: float = to_star.length()
	if Space.supported(catalog):
		for celestial: Dictionary in catalog.rows("celestial_defs"):
			if celestial.sector_id == state.current_sector() and celestial.celestial_kind == "star": star = celestial; break
		var components: Dictionary = {"x": float(star.get("x_m", 0.0)), "y": float(star.get("y_m", 0.0)), "z": float(star.get("z_m", 0.0))}
		to_star = Space.scalar_direction(strategic_components(reference), components)
		star_distance = Space.scalar_distance(strategic_components(reference), components)
	if to_star.length_squared() <= 0.000001:
		return
	var direction: Vector3 = to_star.normalized()
	var up: Vector3 = Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	# A directional light emits along local -Z; its position is ignored.
	# Shadow splits follow the camera while the star determines ray direction.
	key_light.global_basis = Basis.looking_at(-direction, up)
	if is_instance_valid(stellar_disc):
		# The star's compressed scenic coordinate defines lighting. Its visible
		# disc is projected within the camera far plane and never collides.
		var camera: Camera3D = get_viewport().get_camera_3d()
		var eye: Vector3 = camera.get_global_transform_interpolated().origin if camera != null else reference
		var ray: Vector3 = to_star if Space.supported(catalog) else stellar_position - eye
		var visible_distance: float = camera.far * 0.75 if camera != null else 8000.0
		stellar_disc.global_position = eye + ray.normalized() * visible_distance
		stellar_disc.scale = Vector3.ONE * visible_distance * (float(star.radius_m) / star_distance if not star.is_empty() and star_distance > 0.0 else 0.009)

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
		if gameplay.exploration.managed_resources.has(location.node_id): continue
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
	replacement.metrics = gameplay.call("metrics", row)
	XJSurfaceStyle.apply_ship(replacement.visual)
	if is_instance_valid(flight):
		# A deferred deletion must not leave the previous hull in the rendered
		# scene alongside its replacement, even for the remainder of this frame.
		flight.hide()
		remove_child(flight)
		flight.queue_free()
	add_child(replacement)
	# Prime the render-pose pump before resetting its initial spawn history.
	# Physics and saved DTOs continue to use the authoritative current pose.
	replacement.get_global_transform_interpolated()
	replacement.reset_physics_interpolation()
	flight = replacement
	return true

func _clear_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owners(child)

func sync_entities() -> bool:
	refresh_site()
	if exploration_view == null: exploration_view = preload("res://runtime/exploration_view.gd").new(self)
	exploration_view.sync()
	_sync_waypoints()
	for id: String in npcs.keys():
		if state.find("npc_state", "npc_instance_id", id) == null or (Space.supported(catalog) and Space.site_for_entity(state, "npc", id) != Space.current_site(state)):
			npcs.erase(id)
			_remove_target(id)
	for row: Dtos.NpcStateDto in state.rows("npc_state"):
		if row.sector_id != state.current_sector():
			continue
		if Space.supported(catalog) and Space.site_for_entity(state, "npc", row.npc_instance_id) != Space.current_site(state): continue
		if not row.alive:
			if npcs.has(row.npc_instance_id):
				var retired: CharacterBody3D = npcs[row.npc_instance_id]
				retired.hide()
				remove_child(retired)
				retired.queue_free()
				npcs.erase(row.npc_instance_id)
				targets.erase(row.npc_instance_id)
			continue
		if not npcs.has(row.npc_instance_id):
			var spawn: Dictionary = catalog.one("npc_spawn_defs", "spawn_id", row.spawn_id)
			var definition: Dictionary = catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
			var escort_hull: String = gameplay.civilizations.escort_hull(row.npc_instance_id)
			var body: CharacterBody3D = factory.scene(escort_hull) if not escort_hull.is_empty() else factory.enemy_scene(str(definition.archetype_id))
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
			targets[row.npc_instance_id]["friendly"] = gameplay.civilizations.friendly(row.npc_instance_id)
			if bool(targets[row.npc_instance_id].friendly): targets[row.npc_instance_id].title = "友军 · " + str(catalog.one("ship_defs", "ship_id", escort_hull).display_name)
			elif gameplay.civilizations.fleet_member(row.npc_instance_id) != null: targets[row.npc_instance_id].title = "中立守军 · Lv.%d" % int(definition.level)
		var group_id: String = gameplay.get("encounters").group_for_spawn(row.spawn_id)
		targets[row.npc_instance_id]["group_target_id"] = "group:" + group_id if not group_id.is_empty() else "encounter:" + row.spawn_id if row.has_mission_instance_id else ""
	for id: String in targets.keys():
		if targets[id].kind == "wreck" and (state.find("container_state", "container_id", id) == null or not target_is_local(id)):
			_remove_target(id)
	for container: Dtos.ContainerStateDto in state.rows("container_state"):
		if container.kind != Types.ContainerKind.WRECK or container.sector_id != state.current_sector() or targets.has(container.container_id):
			continue
		if Space.supported(catalog) and Space.site_for_entity(state, "wreck", container.container_id) != Space.current_site(state): continue
		var wreck := _visual("wreck")
		add_child(wreck)
		wreck.position = Vector3(container.pos_x, container.pos_y, container.pos_z)
		_target(container.container_id, "可回收残骸", "wreck", wreck, "")
	return true

func _remove_target(id: String) -> void:
	if not targets.has(id): return
	var node: Node3D = targets[id].node
	targets.erase(id)
	if is_instance_valid(node):
		node.hide()
		remove_child(node)
		node.queue_free()

func _sync_waypoints() -> void:
	var entries: Array[Dictionary] = gameplay.get("encounters").waypoints(state.current_sector())
	# Task sites survive range filtering; only their actual enemies are sensor
	# contacts. A site has no mesh or collider that could duplicate the ship.
	for spawn in catalog.rows("npc_spawn_defs"):
		if spawn.sector_id != state.current_sector(): continue
		var mission: RefCounted = gameplay.get("missions").active_for_target("destroy_spawn", spawn.spawn_id)
		if mission == null: continue
		var outstanding: bool = false
		for objective in gameplay.get("missions").objectives(mission.mission_def_id):
			if objective.objective_kind != "destroy_spawn" or objective.target_spawn_id != spawn.spawn_id: continue
			var progress: RefCounted = gameplay.get("missions").progress(mission, int(objective.objective_index))
			if progress == null or progress.progress_units < int(objective.required_count): outstanding = true
		if not outstanding: continue
		var npc: RefCounted = state.find("npc_state", "spawn_id", spawn.spawn_id)
		var definition: Dictionary = catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
		var behavior: Dictionary = catalog.one("npc_behavior_defs", "behavior_id", spawn.behavior_id)
		entries.append({"id": "encounter:" + str(spawn.spawn_id), "title": "任务目标 · " + str(definition.display_name), "kind": "encounter", "anchor_id": spawn.anchor_id, "remaining_count": 1 if npc != null and npc.alive else 0, "total_count": 1, "respawn_remaining_s": 0.0, "level": definition.level, "mission_target": true, "reveal_range_m": float(catalog.rule("target_marker_detection_range_m")), "warp_arrival_m": float(behavior.detection_range_m) + float(behavior.return_radius_m)})
	var retained: Dictionary = {}
	for entry in entries:
		var id: String = entry.id
		retained[id] = true
		var node: Node3D
		if targets.has(id): node = targets[id].node
		else:
			node = Node3D.new()
			add_child(node)
			node.position = anchor_position(entry.anchor_id)
			_target(id, entry.title, "encounter", node, entry.anchor_id)
		for field in entry: targets[id][field] = entry[field]
	for id: String in targets.keys():
		if targets[id].kind == "encounter" and not retained.has(id): _remove_target(id)

func simulate_npcs(delta: float) -> void:
	if not is_instance_valid(flight):
		return
	for id in npcs:
		var row := state.find("npc_state", "npc_instance_id", id) as Dtos.NpcStateDto
		if row == null or not row.alive:
			continue
		var body: CharacterBody3D = npcs[id]
		if WarFleetPilot.step(self, row, body, delta): continue
		if XJExplorationPilot.step(self, row, body, delta): continue
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
						var profile: Dictionary = {}
						if catalog.table_names.has("weapon_behavior_defs"):
							profile = {"family_id": str(definition.damage_type), "fire_mode": str(behavior.fire_mode)}
						projectiles.fire(id, body.get_rid(), origin, origin.direction_to(flight.global_position), float(behavior.projectile_speed_mps) if behavior.projectile_speed_mps != null else 0.0, float(definition.range_m), raw, profile)
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

func contact_visible(entry: Dictionary, distance: float) -> bool:
	# A durable source site is retained throughout strategic travel for safe
	# cancellation. It must not remain a local radar echo during that transit.
	if departure_active and target_is_local(str(entry.get("id", ""))) and not bool(entry.get("navigation_only", false)): return false
	if str(entry.get("kind", "")) in ["npc", "wreck"] and not target_is_local(str(entry.get("id", ""))): return false
	if str(entry.get("kind", "")) != "npc": return true
	var sensor: float = float(catalog.rule("target_marker_detection_range_m"))
	if distance > sensor: return false
	var group_id: String = str(entry.get("group_target_id", ""))
	if group_id.is_empty() or not targets.has(group_id): return true
	var group: Dictionary = targets[group_id]
	var node: Variant = group.get("node")
	var reveal: float = float(group.get("reveal_range_m", sensor))
	return distance <= reveal or (node is Node3D and is_instance_valid(node) and flight.global_position.distance_to(node.global_position) <= reveal)

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
		if anchor.anchor_kind == "station" and (not Space.supported(catalog) or Space.site_for_anchor(catalog, key) == Space.current_site(state)) and point.distance_to(anchor_position(key)) <= float(anchor.safe_radius_m):
			return true
	return false

func _target(id: String, title: String, kind: String, node: Node3D, anchor_id: String) -> void:
	# All target nodes have reached their final spawn transform here. Initializing
	# the interpolation pump now prevents a first-frame trail from the origin.
	node.get_global_transform_interpolated()
	node.reset_physics_interpolation()
	targets[id] = {"id": id, "title": title, "kind": kind, "node": node, "anchor_id": anchor_id}
	if node is CollisionObject3D:
		node.set_meta("site_collision_layer", node.collision_layer)
	apply_target_site(id)

func target_site(id: String) -> String:
	if not targets.has(id): return ""
	var entry: Dictionary = targets[id]
	if entry.kind in ["npc", "wreck"]: return Space.site_for_entity(state, str(entry.kind), id)
	return Space.site_for_anchor(catalog, str(entry.get("anchor_id", "")))

func target_is_local(id: String) -> bool:
	return not Space.supported(catalog) or (not target_site(id).is_empty() and target_site(id) == Space.current_site(state))

func target_is_render_local(id: String) -> bool:
	# Site identity stays at the durable origin until arrival. Display locality
	# instead follows departure, so selecting the origin uses its true bearing.
	return not departure_active and target_is_local(id)

func strategic_components(encoded_position: Vector3) -> Dictionary:
	return strategic_render_position if not strategic_render_position.is_empty() else Space.global_components(catalog, Space.current_site(state), encoded_position)

func target_components(id: String) -> Dictionary:
	if not targets.has(id): return {}
	if bool(targets[id].get("navigation_only", false)) and Space.supported(catalog):
		var celestial: Dictionary = catalog.one("celestial_defs", "celestial_id", id)
		if not celestial.is_empty(): return {"x": float(celestial.x_m), "y": float(celestial.y_m), "z": float(celestial.z_m)}
	var node: Node3D = targets[id].node
	return Space.global_components(catalog, target_site(id), node.global_position)

func target_distance(id: String) -> float:
	if not targets.has(id) or not is_instance_valid(flight): return INF
	var node: Node3D = targets[id].node
	if not Space.supported(catalog) or (target_is_local(id) and strategic_render_position.is_empty()): return flight.global_position.distance_to(node.global_position)
	return Space.scalar_distance(strategic_components(flight.global_position), target_components(id))

func target_direction(id: String) -> Vector3:
	if not targets.has(id) or not is_instance_valid(flight): return Vector3.ZERO
	var node: Node3D = targets[id].node
	if not Space.supported(catalog) or (target_is_local(id) and strategic_render_position.is_empty()): return flight.global_position.direction_to(node.global_position)
	return Space.scalar_direction(strategic_components(flight.global_position), target_components(id))

func apply_target_site(id: String) -> void:
	if not Space.supported(catalog) or not targets.has(id): return
	var entry: Dictionary = targets[id]
	if bool(entry.get("navigation_only", false)): return
	var node: Node3D = entry.node
	node.visible = target_is_local(id) and not departure_active
	if node is CollisionObject3D:
		var collider_site: String = collision_site_id if not collision_site_id.is_empty() else Space.current_site(state)
		node.collision_layer = int(node.get_meta("site_collision_layer", 0)) if target_site(id) == collider_site else 0

func configure_warp_projection(parameters: Dictionary) -> bool:
	_departure_parameters.clear()
	for key: String in ["warp_fx_departure_duration_s", "warp_fx_departure_distance_ship_lengths"]:
		if not parameters.has(key) or not is_finite(float(parameters[key])) or float(parameters[key]) <= 0.0:
			last_error = "跃迁离场表现数据库参数缺失或无效：" + key
			return false
	for key: String in ["warp_fx_departure_duration_s", "warp_fx_departure_distance_ship_lengths"]:
		_departure_parameters[key] = float(parameters[key])
	last_error = ""
	return true

func begin_strategic_departure(heading: Vector3, travel_duration_s: float) -> bool:
	end_strategic_departure()
	if _departure_parameters.is_empty():
		last_error = "跃迁离场表现尚未从数据库配置，已停止跃迁"
		return false
	if not Space.supported(catalog) or not is_instance_valid(flight) or not is_finite(travel_duration_s) or travel_duration_s <= 0.0:
		last_error = "跃迁离场表现缺少有效航行场景或航程"
		return false
	var ship_length: float = _departure_ship_length()
	if ship_length <= 0.0:
		last_error = "跃迁离场表现缺少舰船几何，已停止跃迁"
		return false
	departure_projection = Node3D.new()
	departure_projection.name = "DepartureProjection"
	add_child(departure_projection)
	_departure_heading = heading.normalized() if not heading.is_zero_approx() else -flight.global_basis.z
	_departure_duration_s = minf(float(_departure_parameters.warp_fx_departure_duration_s), travel_duration_s)
	var extent: float = 0.0
	for id: String in targets:
		if not target_is_local(id) or bool(targets[id].get("navigation_only", false)): continue
		var source: Node3D = targets[id].node
		if not is_instance_valid(source) or not source.is_visible_in_tree(): continue
		extent = maxf(extent, _copy_departure_meshes(source, id))
	var camera: Camera3D = get_viewport().get_camera_3d()
	# The displacement only needs to leave this camera's finite render volume.
	# It does not represent, round, or overwrite the actual AU route distance.
	var scene_distance: float = extent + ship_length * float(_departure_parameters.warp_fx_departure_distance_ship_lengths)
	# 1.2 is a finite-camera clipping margin, not a route or gameplay distance.
	_departure_distance_m = maxf(camera.far * 1.2, scene_distance + camera.global_position.distance_to(flight.global_position)) if camera != null else scene_distance
	departure_elapsed_s = 0.0
	departure_active = true
	departure_projection.get_global_transform_interpolated()
	departure_projection.reset_physics_interpolation()
	for id: String in targets: apply_target_site(id)
	last_error = ""
	return true

func _departure_ship_length() -> float:
	var points: Array[Vector3] = []
	if is_instance_valid(flight.visual): _collect_departure_hull(flight.visual, flight.global_transform.affine_inverse(), points)
	if points.is_empty(): return 0.0
	var bounds := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points: bounds = bounds.expand(point)
	return maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))

func _collect_departure_hull(node: Node, inverse: Transform3D, points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		if mesh.mesh != null:
			var bounds: AABB = mesh.get_aabb()
			for index: int in range(8): points.append(inverse * mesh.global_transform * bounds.get_endpoint(index))
	for child: Node in node.get_children(): _collect_departure_hull(child, inverse, points)

func _copy_departure_meshes(source: Node, target_id: String) -> float:
	var extent: float = 0.0
	if source is MeshInstance3D and source.mesh != null and source.is_visible_in_tree():
		var original: MeshInstance3D = source
		# Share immutable mesh/material resources, never duplicate scripts,
		# physics bodies, particle simulations, or persistent entity metadata.
		var copy := MeshInstance3D.new()
		copy.mesh = original.mesh
		copy.material_override = original.material_override
		copy.material_overlay = original.material_overlay
		copy.layers = original.layers
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.set_meta("departure_target_id", target_id)
		for surface: int in range(original.mesh.get_surface_count()):
			copy.set_surface_override_material(surface, original.get_surface_override_material(surface))
		departure_projection.add_child(copy)
		copy.global_transform = original.get_global_transform_interpolated()
		var bounds: AABB = original.get_aabb()
		for corner: int in range(8):
			extent = maxf(extent, (copy.global_transform * bounds.get_endpoint(corner)).distance_to(flight.global_position))
	for child: Node in source.get_children():
		extent = maxf(extent, _copy_departure_meshes(child, target_id))
	return extent

func advance_strategic_departure(elapsed_s: float) -> void:
	if not departure_active or not is_instance_valid(departure_projection): return
	departure_elapsed_s = maxf(0.0, elapsed_s)
	var fraction: float = clampf(departure_elapsed_s / _departure_duration_s, 0.0, 1.0)
	# Accelerating recession gives the ship a visible departure in every camera
	# direction, then completely removes the old site's geometry from transit.
	departure_projection.position = -_departure_heading * _departure_distance_m * fraction * fraction
	departure_projection.visible = fraction < 1.0

func end_strategic_departure() -> void:
	if is_instance_valid(departure_projection):
		departure_projection.hide()
		remove_child(departure_projection)
		departure_projection.queue_free()
	departure_projection = null
	departure_active = false
	departure_elapsed_s = 0.0
	if state != null and catalog != null:
		for id: String in targets: apply_target_site(id)

func set_collision_site(site_id: String) -> void:
	collision_site_id = site_id
	for id: String in targets: apply_target_site(id)

func refresh_site() -> void:
	if not Space.supported(catalog): return
	var site: String = Space.current_site(state)
	if site == _loaded_site_id: return
	_loaded_site_id = site
	collision_site_id = site
	for id: String in targets: apply_target_site(id)
	update_starlight()

func enforce_local_boundary() -> bool:
	if not Space.supported(catalog) or not is_instance_valid(flight): return false
	var site: Dictionary = catalog.one("site_defs", "site_id", Space.current_site(state))
	if site.is_empty(): return false
	var pivot := Vector3(site.pivot_x_m, site.pivot_y_m, site.pivot_z_m)
	var offset: Vector3 = flight.position - pivot
	if offset.length() <= float(site.local_radius_m): return false
	flight.position = pivot + offset.normalized() * float(site.local_radius_m)
	flight.velocity = Vector3.ZERO
	flight.write_back()
	flight.reset_physics_interpolation()
	return true

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
	visual_environment = world_environment.environment
	world_environment.environment.ambient_light_color = Color(0.38, 0.4, 0.43)
	world_environment.environment.ambient_light_energy = 0.25
	world_environment.environment.ssao_enabled = true
	world_environment.environment.ssao_radius = 3.0
	world_environment.environment.ssao_intensity = 1.3
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = preload("res://assets/navigation_v3/space_panorama.png")
	panorama.energy_multiplier = 0.34
	world_environment.environment.sky.sky_material = panorama
	world_environment.environment.sky_rotation = Vector3(0, float(absi(state.current_sector().hash()) % 1000) / 1000.0 * TAU, 0)
	add_child(space)
	Celestials.build(self, state.current_sector())
	# A frozen old catalog keeps its original presentation and is never
	# supplemented with the current catalog's gameplay definitions.
	if catalog.table_names.has("system_lighting_defs"):
		var sector_definition: Dictionary = catalog.one("sector_defs", "sector_id", state.current_sector())
		lighting_definition = catalog.one("system_lighting_defs", "system_id", str(sector_definition.get("system_id", "")))
	var sun := DirectionalLight3D.new()
	sun.name = "StellarKeyLight"
	key_light = sun
	sun.light_color = Color(1.0, 0.96, 0.89)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 2000.0
	sun.rotation_degrees = Vector3(-35, -30, 0)
	add_child(sun)
	if not lighting_definition.is_empty():
		stellar_position = Vector3(lighting_definition.star_x_m, lighting_definition.star_y_m, lighting_definition.star_z_m)
		sun.light_color = Color(lighting_definition.light_r, lighting_definition.light_g, lighting_definition.light_b)
		sun.light_energy = float(lighting_definition.energy)
		sun.directional_shadow_max_distance = float(lighting_definition.shadow_distance_m)
		visual_environment.ambient_light_color = Color(0.43, 0.48, 0.57)
		visual_environment.ambient_light_energy = float(lighting_definition.ambient_energy)
		sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		stellar_disc = MeshInstance3D.new()
		stellar_disc.name = "StellarDisc"
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 32
		sphere.rings = 16
		stellar_disc.mesh = sphere
		stellar_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stellar_disc.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = sun.light_color
		material.emission_enabled = true
		material.emission = sun.light_color
		material.emission_energy_multiplier = sun.light_energy
		stellar_disc.material_override = material
		add_child(stellar_disc)
		update_starlight()
		return
	var warm := DirectionalLight3D.new()
	warm.light_color = Color(0.57, 0.65, 0.71)
	warm.light_energy = 0.25
	warm.rotation_degrees = Vector3(30, 140, 0)
	add_child(warm)

func apply_visual_quality(quality: String) -> void:
	if visual_environment != null: visual_environment.ssao_enabled = quality == "high"
	if is_instance_valid(key_light): key_light.shadow_enabled = quality != "low"
