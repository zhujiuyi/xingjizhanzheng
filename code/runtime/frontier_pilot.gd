class_name XJFrontierPilot
extends RefCounted
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")

static func step(world: Node3D,row: D.NpcStateDto,body: CharacterBody3D,delta: float) -> bool:
	var g: RefCounted=world.gameplay;var service: RefCounted=g.frontier;var member: RefCounted=service.actor(row.npc_instance_id)
	if member==null:return false
	if not g.same_entity_site("ship",g.state.ship(),"npc",row):return true
	if member.actor_role in ["structure","beacon"]:
		body.velocity=Vector3.ZERO;row.vel_x=0.0;row.vel_y=0.0;row.vel_z=0.0;return true
	var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",row.spawn_id);var stats: Dictionary=g.definition("npc_full_defs","npc_id",spawn.npc_id);var behavior: Dictionary=g.definition("npc_behavior_defs","behavior_id",spawn.behavior_id)
	var destination: Vector3=body.position;var target: Node3D=null;var target_id: String=""
	if member.actor_role=="convoy":
		var campaign: RefCounted=service.campaign(member.war_id);var war: RefCounted=g.civilizations.active_war()
		if campaign!=null and campaign.phase=="escorting" and war!=null and world.flight.position.distance_to(body.position)<=float(service.balance.escort_radius_m):
			if war.fleet_order=="regroup":destination=world.flight.position+world.flight.position.direction_to(body.position)*float(service.balance.arrival_radius_m)*2.0
			else:destination=world.anchor_position(service.definition(member.war_id).convoy_exit_anchor_id)
	else:
		var nearest: float=INF
		if world.flight.record.status==T.ShipStatus.FLYING:target=world.flight;target_id=world.flight.record.ship_instance_id;nearest=body.position.distance_to(target.position)
		for id: String in world.npcs:
			if not g.civilizations.friendly(id):continue
			var other: RefCounted=g.state.find("npc_state","npc_instance_id",id)
			if other==null or not other.alive or not g.same_entity_site("npc",row,"npc",other):continue
			var candidate: Node3D=world.npcs[id];var distance: float=body.position.distance_to(candidate.position)
			if distance<nearest:nearest=distance;target=candidate;target_id=id
		row.cooldown_remaining_s=maxf(0.0,row.cooldown_remaining_s-delta)
		if target!=null:
			var direction: Vector3=body.position.direction_to(target.position)
			var layout: Dictionary=g.definition("frontier_actor_defs","spawn_id",row.spawn_id)
			var flank: Vector3=Vector3.UP.cross(direction).normalized()
			destination=target.position-direction*float(stats.range_m)*float(behavior.preferred_range_ratio)+flank*float(layout.slot_index)*float(behavior.return_radius_m)
			row.behavior_phase=T.NpcPhase.PURSUE
			if nearest<=float(stats.range_m) and world.line_of_sight(body.position,target.position,body.get_rid(),target_id):
				row.behavior_phase=T.NpcPhase.ATTACK
				if row.cooldown_remaining_s<=0.0 and (-body.basis.z).angle_to(direction)<=float(behavior.fire_cone_half_angle_rad):
					var raw: Vector3=Vector3.ZERO;raw[g.damage_index(stats.damage_type)]=float(stats.raw_dps)*float(behavior.attack_cycle_s)
					var muzzle: Node3D=body.get_node_or_null("Hardpoints/weapon_0/muzzle");var origin: Vector3=muzzle.global_position if muzzle!=null else body.global_position
					world.projectiles.fire(row.npc_instance_id,body.get_rid(),origin,origin.direction_to(target.global_position),float(behavior.projectile_speed_mps) if behavior.projectile_speed_mps!=null else 0.0,float(stats.range_m),raw,{"family_id":stats.damage_type,"fire_mode":behavior.fire_mode},"",target_id)
					g.mark_hostile_attempt();row.cooldown_remaining_s=float(behavior.attack_cycle_s)
	var heading: Vector3=body.position.direction_to(target.position if target!=null else destination)
	if heading.length_squared()>0.00001:
		var up: Vector3=Vector3.UP if absf(heading.dot(Vector3.UP))<0.99 else Vector3.FORWARD
		var rotation: Quaternion=Basis.looking_at(heading,up).get_rotation_quaternion()
		body.quaternion=body.quaternion.slerp(rotation,minf(1.0,float(behavior.turn_rad_s)*delta/maxf(body.quaternion.angle_to(rotation),0.00001)))
	var velocity: Vector3=body.position.direction_to(destination)*float(stats.speed_mps) if body.position.distance_to(destination)>float(behavior.return_radius_m) else Vector3.ZERO
	body.velocity=body.velocity.move_toward(velocity,float(behavior.acceleration_mps2)*delta);body.move_and_slide()
	row.pos_x=body.position.x;row.pos_y=body.position.y;row.pos_z=body.position.z;row.vel_x=body.velocity.x;row.vel_y=body.velocity.y;row.vel_z=body.velocity.z
	row.quat_x=body.quaternion.x;row.quat_y=body.quaternion.y;row.quat_z=body.quaternion.z;row.quat_w=body.quaternion.w
	return true
