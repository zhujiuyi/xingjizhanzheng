class_name XJWarFleetPilot
extends RefCounted
## The same real bodies, projectiles and damage pipeline used by ordinary combat.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")

static func step(world: Node3D, row: D.NpcStateDto, body: CharacterBody3D, delta: float) -> bool:
	var g: RefCounted = world.gameplay
	var civ: RefCounted = g.civilizations
	var member: D.WarFleetStateDto = civ.fleet_member(row.npc_instance_id)
	if member == null: return false
	var campaign: D.WarCampaignStateDto = civ.active_war()
	if campaign == null or campaign.war_id != member.war_id: return true
	if g.march.hidden(row.npc_instance_id):body.velocity=Vector3.ZERO;return true
	var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", row.spawn_id)
	var definition: Dictionary = g.definition("npc_full_defs", "npc_id", spawn.npc_id)
	var behavior: Dictionary = g.definition("npc_behavior_defs", "behavior_id", spawn.behavior_id)
	var target_id: String = ""
	var target: Node3D = null
	var nearest: float = INF
	if member.side == "defender" and world.flight.record.status == T.ShipStatus.FLYING:
		target_id = world.flight.record.ship_instance_id
		target = world.flight
		nearest = body.position.distance_to(target.position)
	for id: String in world.npcs:
		var other: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", id)
		if other == null or not other.alive or g.march.hidden(id) or not civ.hostile_to(row.npc_instance_id, id): continue
		var candidate: Node3D = world.npcs[id]
		var distance: float = body.position.distance_to(candidate.position)
		if member.side == "ally" and campaign.fleet_order == "focus" and campaign.focus_target_id == id:
			target_id = id; target = candidate
			break
		if distance < nearest:
			nearest = distance; target_id = id; target = candidate
	var war_def: Dictionary = g.definition("civilization_war_defs", "war_id", campaign.war_id)
	var destination: Vector3 = world.anchor_position(war_def.capture_anchor_id)
	var march_plan: Dictionary=g.march.local_plan(row.npc_instance_id)
	if not march_plan.is_empty():destination=march_plan.destination
	var regroup: bool = member.side == "ally" and campaign.fleet_order == "regroup"
	if regroup:
		var layout: Dictionary = g.definition("civilization_war_members", "spawn_id", row.spawn_id)
		var separation: float = g.rule("civilization_fleet_regroup_m")
		destination = world.flight.position + world.flight.basis * Vector3((float(layout.formation_index) - 1.0) * separation * 0.4, separation * 0.1, separation)
	elif target != null and (march_plan.is_empty() or campaign.fleet_order=="focus"):
		# Spread the squad around its firing range. A shared target point makes
		# large allied hulls stack up and block one another's real line of sight.
		var layout: Dictionary = g.definition("civilization_war_members", "spawn_id", row.spawn_id)
		var count: int = 0
		for entry: Dictionary in g.rows("civilization_war_members"):
			if entry.war_id == campaign.war_id and entry.side == member.side: count += 1
		var approach: Vector3 = world.anchor_position(spawn.anchor_id).direction_to(target.position) if march_plan.is_empty() else body.position.direction_to(target.position)
		if approach.is_zero_approx(): approach = Vector3.FORWARD
		var side: Vector3 = Vector3.UP.cross(approach).normalized()
		if side.is_zero_approx(): side = Vector3.RIGHT
		var distance: float = float(definition.range_m) * float(behavior.preferred_range_ratio)
		var separation: float = minf(g.rule("civilization_fleet_regroup_m") * 0.4, distance * 0.4)
		var offset: float = (float(layout.formation_index) - float(count - 1) * 0.5) * separation
		var lift: float = separation * (0.4 if int(layout.formation_index) % 2 == 1 else -0.15)
		destination = target.position - approach * distance + side * offset + Vector3.UP * lift
	var should_move: bool = body.position.distance_to(destination) > float(behavior.return_radius_m)
	if march_plan.has("stop_radius"):should_move=body.position.distance_to(destination)>float(march_plan.stop_radius)
	if not march_plan.is_empty() and bool(march_plan.hold) and not regroup:should_move=false
	row.cooldown_remaining_s = maxf(0, row.cooldown_remaining_s - delta)
	row.behavior_phase = T.NpcPhase.PURSUE if target != null else T.NpcPhase.PATROL
	if target != null:
		var distance: float = body.position.distance_to(target.position)
		var visible: bool = world.line_of_sight(body.position, target.position, body.get_rid(), target_id)
		if distance <= float(definition.range_m) and visible:
			row.behavior_phase = T.NpcPhase.ATTACK
			var direction: Vector3 = body.position.direction_to(target.position)
			if row.cooldown_remaining_s <= 0 and (-body.basis.z).angle_to(direction) <= float(behavior.fire_cone_half_angle_rad):
				var raw: Vector3 = Vector3.ZERO
				raw[g.damage_index(str(definition.damage_type))] = float(definition.raw_dps) * float(behavior.attack_cycle_s)
				var muzzle: Node3D = body.get_node_or_null("Hardpoints/weapon_0/muzzle")
				var origin: Vector3 = muzzle.global_position if muzzle != null else body.global_position
				var profile: Dictionary = {"family_id": str(definition.damage_type), "fire_mode": str(behavior.fire_mode)}
				world.projectiles.fire(row.npc_instance_id, body.get_rid(), origin, origin.direction_to(target.global_position), float(behavior.projectile_speed_mps) if behavior.projectile_speed_mps != null else 0.0, float(definition.range_m), raw, profile, "", target_id)
				g.mark_hostile_attempt()
				row.cooldown_remaining_s = float(behavior.attack_cycle_s)
	var direction: Vector3 = body.position.direction_to(target.position if target != null else destination)
	if direction.length_squared() > 0.00001:
		var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var desired_rotation: Quaternion = Basis.looking_at(direction, up).get_rotation_quaternion()
		var angle: float = body.quaternion.angle_to(desired_rotation)
		body.quaternion = body.quaternion.slerp(desired_rotation, minf(1, float(behavior.turn_rad_s) * delta / maxf(angle, 0.00001)))
	var speed: float=float(definition.speed_mps)
	if not march_plan.is_empty():
		var stop_radius: float=float(march_plan.get("stop_radius",behavior.return_radius_m))
		speed=minf(speed,sqrt(2.0*float(behavior.acceleration_mps2)*maxf(0.0,body.position.distance_to(destination)-stop_radius)))
	var velocity: Vector3 = body.position.direction_to(destination) * speed if should_move else Vector3.ZERO
	body.velocity = body.velocity.move_toward(velocity, float(behavior.acceleration_mps2) * delta)
	var before: Vector3=body.position
	body.move_and_slide()
	g.march.record_motion(row.npc_instance_id,before,body.position)
	row.pos_x = body.position.x; row.pos_y = body.position.y; row.pos_z = body.position.z
	row.vel_x = body.velocity.x; row.vel_y = body.velocity.y; row.vel_z = body.velocity.z
	row.quat_x = body.quaternion.x; row.quat_y = body.quaternion.y; row.quat_z = body.quaternion.z; row.quat_w = body.quaternion.w
	return true
