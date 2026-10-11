class_name XJExplorationPilot
extends RefCounted
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")

static func step(world: Node3D, row: D.NpcStateDto, body: CharacterBody3D, delta: float) -> bool:
	var g: RefCounted = world.gameplay
	var service: RefCounted = g.exploration
	var member: D.ExplorationActorStateDto = service.actor_member(row.npc_instance_id)
	if member == null: return false
	var event: D.ExplorationInstanceStateDto = service.instance(member.event_id)
	if event == null: return true
	var spec: Dictionary = service.definition(member.event_id)
	var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", row.spawn_id)
	var stats: Dictionary = g.definition("npc_full_defs", "npc_id", spawn.npc_id)
	var behavior: Dictionary = g.definition("npc_behavior_defs", "behavior_id", spawn.behavior_id)
	var destination: Vector3 = body.position
	var target: Node3D = null
	var target_id: String = ""
	if member.actor_role == "escort":
		if event.phase == "rescue" and event.stabilized and world.flight.position.distance_to(body.position) <= float(service.balance.escort_follow_m):
			destination = world.anchor_position(spec.exit_anchor_id)
		elif event.phase in ["ready", "claimed"] and event.outcome == "full":
			var exit_point: Vector3 = world.anchor_position(spec.exit_anchor_id)
			var direction: Vector3 = world.anchor_position(spec.entry_anchor_id).direction_to(exit_point)
			destination = exit_point + direction * float(service.balance.escort_departure_m) * 2.0
			if body.position.distance_to(exit_point) >= float(service.balance.escort_departure_m):
				g.state.remove("exploration_actor_state", member); g.remove_npc(row); return true
	else:
		var nearest: float = INF
		if world.flight.record.status == T.ShipStatus.FLYING:
			target = world.flight; target_id = world.flight.record.ship_instance_id; nearest = body.position.distance_to(target.position)
		for id: String in world.npcs:
			if not service.friendly(id): continue
			var other: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", id)
			if other == null or not other.alive: continue
			var candidate: Node3D = world.npcs[id]
			var distance: float = body.position.distance_to(candidate.position)
			if distance < nearest: target = candidate; target_id = id; nearest = distance
		row.cooldown_remaining_s = maxf(0.0, row.cooldown_remaining_s - delta)
		if target != null:
			var direction: Vector3 = body.position.direction_to(target.position)
			var layout: Dictionary = service.managed_spawns[row.spawn_id]
			var flank: Vector3 = Vector3.UP.cross(direction).normalized()
			destination = target.position - direction * float(stats.range_m) * float(behavior.preferred_range_ratio) + flank * float(layout.slot_index) * float(behavior.return_radius_m)
			var visible: bool = world.line_of_sight(body.position, target.position, body.get_rid(), target_id)
			row.behavior_phase = T.NpcPhase.PURSUE
			if nearest <= float(stats.range_m) and visible:
				row.behavior_phase = T.NpcPhase.ATTACK
				if row.cooldown_remaining_s <= 0 and (-body.basis.z).angle_to(direction) <= float(behavior.fire_cone_half_angle_rad):
					var raw: Vector3 = Vector3.ZERO; raw[g.damage_index(stats.damage_type)] = float(stats.raw_dps) * float(behavior.attack_cycle_s)
					var muzzle: Node3D = body.get_node_or_null("Hardpoints/weapon_0/muzzle")
					var origin: Vector3 = muzzle.global_position if muzzle != null else body.global_position
					world.projectiles.fire(row.npc_instance_id, body.get_rid(), origin, origin.direction_to(target.global_position), float(behavior.projectile_speed_mps) if behavior.projectile_speed_mps != null else 0.0, float(stats.range_m), raw, {"family_id": stats.damage_type, "fire_mode": behavior.fire_mode}, "", target_id)
					g.mark_hostile_attempt(); row.cooldown_remaining_s = float(behavior.attack_cycle_s)
	var direction: Vector3 = body.position.direction_to(target.position if target != null else destination)
	if direction.length_squared() > 0.00001:
		var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var rotation: Quaternion = Basis.looking_at(direction, up).get_rotation_quaternion()
		body.quaternion = body.quaternion.slerp(rotation, minf(1.0, float(behavior.turn_rad_s) * delta / maxf(body.quaternion.angle_to(rotation), 0.00001)))
	var velocity: Vector3 = body.position.direction_to(destination) * float(stats.speed_mps) if body.position.distance_to(destination) > float(behavior.return_radius_m) else Vector3.ZERO
	body.velocity = body.velocity.move_toward(velocity, float(behavior.acceleration_mps2) * delta)
	body.move_and_slide()
	row.pos_x = body.position.x; row.pos_y = body.position.y; row.pos_z = body.position.z
	row.vel_x = body.velocity.x; row.vel_y = body.velocity.y; row.vel_z = body.velocity.z
	row.quat_x = body.quaternion.x; row.quat_y = body.quaternion.y; row.quat_z = body.quaternion.z; row.quat_w = body.quaternion.w
	return true
