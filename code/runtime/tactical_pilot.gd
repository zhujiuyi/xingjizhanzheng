class_name XJTacticalPilot
extends RefCounted
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
static func step(world: Node3D, npc: D.NpcStateDto, body: CharacterBody3D, delta: float) -> bool:
	var g: RefCounted = world.gameplay
	var tactic: RefCounted = g.tactics.instance(npc.npc_instance_id)
	if tactic == null: return false
	var spec: Dictionary = g.tactics.definition(npc.npc_instance_id)
	var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", npc.spawn_id)
	var behavior: Dictionary = g.definition("npc_behavior_defs", "behavior_id", spawn.behavior_id)
	var stats: Dictionary = g.definition("npc_full_defs", "npc_id", spawn.npc_id)
	var player: Node3D = world.flight
	var home: Vector3 = world.anchor_position(spawn.anchor_id)
	var player_distance: float = body.position.distance_to(player.position)
	var detection: float = float(behavior.detection_range_m) if npc.behavior_phase in [T.NpcPhase.IDLE,T.NpcPhase.PATROL,T.NpcPhase.RETURN] else float(behavior.target_drop_range_m)
	detection = maxf(detection, g.operations.detection_range())
	var engaged: bool = g.state.ship().status == T.ShipStatus.FLYING and player_distance <= detection and body.position.distance_to(home) <= float(behavior.leash_radius_m) and not world.in_safe_zone(player.position)
	var target: Node3D = player
	var target_id: String = g.state.ship().ship_instance_id
	var destination: Vector3 = home
	var ability: bool = engaged
	npc.cooldown_remaining_s = maxf(0.0, npc.cooldown_remaining_s - delta)
	if engaged:
		npc.behavior_phase = T.NpcPhase.PURSUE
		var radial: Vector3 = player.position.direction_to(body.position)
		destination = player.position + radial * float(spec.range_m) * float(behavior.preferred_range_ratio)
		if spec.tactic_kind == "interceptor": destination = player.position + player.basis.z * float(spec.range_m) * float(behavior.preferred_range_ratio)
		if spec.tactic_kind == "support":
			target_id = ""; target = null
			if tactic.has_target_entity_id and world.npcs.has(tactic.target_entity_id):
				target_id = tactic.target_entity_id; target = world.npcs[target_id]
			else:
				var lowest: float = 1.0
				for id: String in world.npcs:
					if id == npc.npc_instance_id: continue
					var ally: RefCounted = g.state.find("npc_state", "npc_instance_id", id)
					if ally == null or not ally.alive or not g.tactics.bindings.has(ally.spawn_id) or g.tactics.bindings[ally.spawn_id].site_id != g.tactics.bindings[npc.spawn_id].site_id: continue
					var maximum: Dictionary = g.definition("npc_full_defs", "npc_id", g.definition("npc_spawn_defs", "spawn_id", ally.spawn_id).npc_id)
					var fraction: float = (ally.shield + ally.armor + ally.hull) / float(maximum.shield_max + maximum.armor_max + maximum.hull_max)
					if fraction < lowest: lowest = fraction; target_id = id; target = world.npcs[id]
			if target != null: destination = target.position + player.position.direction_to(target.position) * float(spec.range_m) * float(behavior.preferred_range_ratio)
			else: ability = false
		if spec.tactic_kind == "carrier" and (tactic.drone_stock <= 0 or world.projectiles.module_busy("npc_bay_" + npc.npc_instance_id)): ability = false
		var visible: bool = target != null and world.line_of_sight(body.position, target.position, body.get_rid(), target_id)
		var cycle: Dictionary = g.tactics.step(npc.npc_instance_id, target_id, visible and ability, delta)
		if not cycle.is_empty():
			var muzzle: Node3D = body.get_node_or_null("Hardpoints/weapon_0/muzzle")
			var origin: Vector3 = muzzle.global_position if muzzle != null else body.global_position
			var aim: Vector3 = cycle.aim
			var profile: Dictionary = {"family_id":"kinetic","fire_mode":"projectile"}
			var module_key: String = ""
			if cycle.kind == "carrier":
				profile = {"family_id":"drone","fire_mode":"drone","module_id":cycle.module_id,"drone":g.definition("drone_defs", "module_id", cycle.module_id)}
				module_key = "npc_bay_" + npc.npc_instance_id; aim = player.global_position
			world.projectiles.fire(npc.npc_instance_id, body.get_rid(), origin, origin.direction_to(aim), cycle.speed, cycle.range, cycle.damage, profile, module_key, g.state.ship().ship_instance_id)
			g.mark_hostile_attempt()
		var gun_target: Node3D = player
		var gun_id: String = g.state.ship().ship_instance_id
		if spec.tactic_kind == "interceptor":
			var nearest: float = float(stats.range_m)
			for id: String in g.drone_control.live:
				if not world.targets.has(id) or not g.civilizations.hostile_to(npc.npc_instance_id, id): continue
				var candidate: Node3D = world.targets[id].node
				if body.position.distance_to(candidate.position) < nearest: nearest = body.position.distance_to(candidate.position); gun_target = candidate; gun_id = id
		if spec.tactic_kind in ["support","interceptor"] and body.position.distance_to(gun_target.position) <= float(stats.range_m) and npc.cooldown_remaining_s <= 0.0 and world.line_of_sight(body.position, gun_target.position, body.get_rid(), gun_id):
			var direction: Vector3 = body.position.direction_to(gun_target.position)
			if (-body.basis.z).angle_to(direction) <= float(behavior.fire_cone_half_angle_rad):
				var damage: Vector3 = Vector3.ZERO; damage[g.damage_index(stats.damage_type)] = float(stats.raw_dps) * float(behavior.attack_cycle_s)
				world.projectiles.fire(npc.npc_instance_id, body.get_rid(), body.global_position, direction, behavior.projectile_speed_mps, stats.range_m, damage, {"family_id":stats.damage_type,"fire_mode":behavior.fire_mode})
				npc.cooldown_remaining_s = float(behavior.attack_cycle_s); g.mark_hostile_attempt()
		if tactic.phase in ["charging","active"]: npc.behavior_phase = T.NpcPhase.ATTACK
	else:
		npc.behavior_phase = T.NpcPhase.RETURN
		g.tactics.step(npc.npc_instance_id, "", false, delta)
	var facing: Vector3 = body.position.direction_to(target.position if engaged and target != null else destination)
	if not facing.is_zero_approx():
		var up: Vector3 = Vector3.UP if absf(facing.y) < 0.99 else Vector3.FORWARD
		var wanted: Quaternion = Basis.looking_at(facing, up).get_rotation_quaternion()
		body.quaternion = body.quaternion.slerp(wanted, minf(1.0, float(behavior.turn_rad_s) * delta / maxf(body.quaternion.angle_to(wanted), 0.000001)))
	var velocity: Vector3 = body.position.direction_to(destination) * float(stats.speed_mps) if body.position.distance_to(destination) > float(behavior.return_radius_m) else Vector3.ZERO
	if tactic.phase == "charging" and spec.tactic_kind == "siege": velocity = Vector3.ZERO
	body.velocity = body.velocity.move_toward(velocity, float(behavior.acceleration_mps2) * delta)
	body.move_and_slide()
	npc.pos_x = body.position.x; npc.pos_y = body.position.y; npc.pos_z = body.position.z
	npc.vel_x = body.velocity.x; npc.vel_y = body.velocity.y; npc.vel_z = body.velocity.z
	npc.quat_x = body.quaternion.x; npc.quat_y = body.quaternion.y; npc.quat_z = body.quaternion.z; npc.quat_w = body.quaternion.w
	return true
