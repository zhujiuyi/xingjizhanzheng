class_name XJHirePilot
extends RefCounted
## Real movement, collision, line of sight and projectile damage for leased NPCs.
const T=preload("res://contracts/contract_types.gd")
static func step(world: Node3D,row: RefCounted,body: CharacterBody3D,delta: float) -> bool:
	var g: RefCounted=world.gameplay;var service: RefCounted=g.hired;var lease: RefCounted=service.contract_for(row.npc_instance_id)
	if lease==null:return false
	if not service.spatial_active:return true
	var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",row.spawn_id)
	var stats: Dictionary=g.definition("npc_full_defs","npc_id",spawn.npc_id)
	var behavior: Dictionary=g.definition("npc_behavior_defs","behavior_id",spawn.behavior_id)
	var destination: Vector3=Vector3(lease.goal_x,lease.goal_y,lease.goal_z)
	var target: Node3D=null;var target_id: String="";var nearest: float=INF
	var linked: bool=service.connected(lease)
	if lease.phase=="deployed" and linked:
		var spacing: float=float(service.balance.formation_m)
		destination=world.flight.position+world.flight.basis*Vector3(spacing,spacing*0.1,spacing*0.25)
		lease.goal_x=destination.x;lease.goal_y=destination.y;lease.goal_z=destination.z
		if lease.order_kind in ["advance","focus"] and world.flight.record.status==T.ShipStatus.FLYING:
			for id: String in world.npcs:
				var other: RefCounted=g.state.find("npc_state","npc_instance_id",id)
				if other==null or not other.alive or not g.civilizations.hostile_to(row.npc_instance_id,id) or not g.same_entity_site("npc",row,"npc",other):continue
				if lease.order_kind=="focus" and id!=lease.focus_target_id:continue
				var candidate: Node3D=world.npcs[id];var distance: float=body.position.distance_to(candidate.position)
				var limit: float=float(service.balance.communication_m) if lease.order_kind=="focus" else float(behavior.detection_range_m)
				if distance<=limit and distance<nearest:nearest=distance;target=candidate;target_id=id
		if target!=null:
			var approach: Vector3=body.position.direction_to(target.position)
			var flank: Vector3=Vector3.UP.cross(approach).normalized()
			if flank.is_zero_approx():flank=Vector3.RIGHT
			destination=target.position-approach*float(stats.range_m)*float(behavior.preferred_range_ratio)+flank*float(behavior.return_radius_m)
	var healing: bool=false
	if lease.phase=="deployed" and linked and service.profile(lease.profile_id).role_id=="support" and world.flight.record.status==T.ShipStatus.FLYING:
		var ship: RefCounted=g.state.ship();var metrics: Dictionary=g.metrics(ship)
		healing=lease.support_cycles_remaining>0 and (ship.shield<float(metrics.shield_max) or ship.armor<float(metrics.armor_max))
		if healing:
			destination=world.flight.position+world.flight.basis*Vector3(float(service.balance.formation_m),0.0,float(service.balance.formation_m)*0.25)
			if body.position.distance_to(world.flight.position)<=float(service.balance.support_range_m) and world.line_of_sight(body.position,world.flight.position,body.get_rid(),ship.ship_instance_id):service.repair_step(lease)
	row.cooldown_remaining_s=maxf(0.0,row.cooldown_remaining_s-delta)
	row.behavior_phase=T.NpcPhase.RETURN if lease.phase=="retreating" else T.NpcPhase.PATROL
	if target!=null and not healing and lease.phase=="deployed":
		var direction: Vector3=body.position.direction_to(target.position)
		if nearest<=float(stats.range_m) and world.line_of_sight(body.position,target.position,body.get_rid(),target_id):
			row.behavior_phase=T.NpcPhase.ATTACK
			if row.cooldown_remaining_s<=0.0 and (-body.basis.z).angle_to(direction)<=float(behavior.fire_cone_half_angle_rad):
				var raw: Vector3=Vector3.ZERO;raw[g.damage_index(stats.damage_type)]=float(stats.raw_dps)*float(behavior.attack_cycle_s)
				var muzzle: Node3D=body.get_node_or_null("Hardpoints/weapon_0/muzzle");var origin: Vector3=muzzle.global_position if muzzle!=null else body.global_position
				world.projectiles.fire(row.npc_instance_id,body.get_rid(),origin,origin.direction_to(target.global_position),float(behavior.projectile_speed_mps),float(stats.range_m),raw,{"family_id":stats.damage_type,"fire_mode":behavior.fire_mode},"",target_id)
				g.mark_hostile_attempt();row.cooldown_remaining_s=float(behavior.attack_cycle_s)
	var heading: Vector3=body.position.direction_to(target.position if target!=null and not healing else destination)
	if heading.length_squared()>0.00001:
		var up: Vector3=Vector3.UP if absf(heading.dot(Vector3.UP))<0.99 else Vector3.FORWARD
		var rotation: Quaternion=Basis.looking_at(heading,up).get_rotation_quaternion()
		body.quaternion=body.quaternion.slerp(rotation,minf(1.0,float(behavior.turn_rad_s)*delta/maxf(body.quaternion.angle_to(rotation),0.00001)))
	var moving: bool=body.position.distance_to(destination)>float(behavior.return_radius_m)
	if lease.phase=="retreating":moving=body.position.distance_to(Vector3(lease.retreat_origin_x,lease.retreat_origin_y,lease.retreat_origin_z))<float(service.balance.retreat_distance_m)
	var velocity: Vector3=body.position.direction_to(destination)*float(stats.speed_mps) if moving else Vector3.ZERO
	body.velocity=body.velocity.move_toward(velocity,float(behavior.acceleration_mps2)*delta);body.move_and_slide()
	row.pos_x=body.position.x;row.pos_y=body.position.y;row.pos_z=body.position.z;row.vel_x=body.velocity.x;row.vel_y=body.velocity.y;row.vel_z=body.velocity.z
	row.quat_x=body.quaternion.x;row.quat_y=body.quaternion.y;row.quat_z=body.quaternion.z;row.quat_w=body.quaternion.w
	if lease.phase=="retreating":service.retreat_step(lease,delta)
	return true
