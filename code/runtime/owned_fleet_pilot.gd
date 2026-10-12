class_name XJOwnedFleetPilot
extends RefCounted
## Uses the actual hull, mounted weapons, ammunition, capacitor and heat.
const T=preload("res://contracts/contract_types.gd")
static func step(world: Node3D,npc: RefCounted,body: CharacterBody3D,delta: float) -> bool:
	var g: RefCounted=world.gameplay;var fleet: RefCounted=g.owned_fleet;var deployment: RefCounted=fleet.row(npc.npc_instance_id)
	if deployment==null or deployment.phase not in ["deployed","retreating"]:return false
	if not fleet.spatial_active:return true
	var hull: RefCounted=fleet.ship(deployment.ship_instance_id);var metrics: Dictionary=g.metrics(hull)
	var behavior: Dictionary=g.definition("npc_behavior_defs","behavior_id",g.definition("npc_spawn_defs","spawn_id",npc.spawn_id).behavior_id)
	var destination: Vector3=Vector3(deployment.goal_x,deployment.goal_y,deployment.goal_z)
	var target: Node3D=null;var target_id: String="";var nearest: float=INF;var weapons: Array=[];var range_m: float=0.0
	for equipment: RefCounted in g.equipped(hull):
		var item: RefCounted=g.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
		var profile: Dictionary=g.specializations.weapon_spec(equipment,hull)
		if equipment.enabled and item!=null and item.durability>0 and not profile.is_empty():weapons.append({"equipment":equipment,"profile":profile});range_m=maxf(range_m,float(profile.range_m))
	if deployment.phase=="deployed" and fleet.connected(deployment):
		var index: int=fleet.active().find(deployment)+1;var spacing: float=float(fleet.balance.formation_m)*float(index)
		destination=world.flight.position+world.flight.basis*Vector3(spacing,spacing*0.1,spacing*0.25)
		deployment.goal_x=destination.x;deployment.goal_y=destination.y;deployment.goal_z=destination.z
		if not weapons.is_empty() and deployment.order_kind in ["advance","focus"]:
			for id: String in world.npcs:
				var enemy: RefCounted=g.state.find("npc_state","npc_instance_id",id)
				if enemy==null or not enemy.alive or not g.civilizations.hostile_to(npc.npc_instance_id,id) or not g.same_entity_site("npc",npc,"npc",enemy):continue
				if deployment.order_kind=="focus" and id!=deployment.focus_target_id:continue
				var distance: float=body.position.distance_to(world.npcs[id].position)
				var base_strength: float=float(g.definition("ship_defs","ship_id",hull.ship_def_id).scan_strength)
				var sensor_ratio: float=float(metrics.scan_strength)/base_strength if base_strength>0 else 1.0
				var limit: float=float(fleet.balance.communication_m) if deployment.order_kind=="focus" else minf(float(fleet.balance.communication_m),float(behavior.detection_range_m)*sensor_ratio)
				if distance<nearest and distance<=limit:nearest=distance;target=world.npcs[id];target_id=id
		if target!=null:
			var direction: Vector3=body.position.direction_to(target.position);var flank: Vector3=Vector3.UP.cross(direction).normalized()
			if flank.is_zero_approx():flank=Vector3.RIGHT
			destination=target.position-direction*range_m*float(behavior.preferred_range_ratio)+flank*float(behavior.return_radius_m)
	var heading: Vector3=body.position.direction_to(target.position if target!=null else destination)
	if heading.length_squared()>0.00001:
		var up: Vector3=Vector3.UP if absf(heading.dot(Vector3.UP))<0.99 else Vector3.FORWARD
		var rotation: Quaternion=Basis.looking_at(heading,up).get_rotation_quaternion()
		body.quaternion=body.quaternion.slerp(rotation,minf(1.0,float(metrics.turn_radps)*delta/maxf(body.quaternion.angle_to(rotation),0.00001)))
	npc.behavior_phase=T.NpcPhase.RETURN if deployment.phase=="retreating" else T.NpcPhase.PATROL
	if target!=null and deployment.phase=="deployed":
		for entry: Dictionary in weapons:
			var equipment: RefCounted=entry.equipment;var profile: Dictionary=entry.profile
			if equipment.cooldown_remaining_s>0 or world.projectiles.module_busy(equipment.item_instance_id):continue
			var container: RefCounted=g.state.find("container_state","container_id",equipment.slot_container_id)
			var muzzle: Node3D=body.get_node_or_null("Hardpoints/weapon_%d/muzzle" % container.slot_index)
			var origin: Vector3=muzzle.global_position if muzzle!=null else body.global_position
			var direction: Vector3=origin.direction_to(target.global_position)
			if origin.distance_to(target.global_position)>float(profile.range_m) or (-body.basis.z).angle_to(direction)>float(profile.fire_cone_half_angle_rad) or not world.line_of_sight(origin,target.global_position,body.get_rid(),target_id):continue
			var cycle: Dictionary=g.consume_weapon_cycle(equipment.item_instance_id,hull)
			if cycle.is_empty():continue
			npc.behavior_phase=T.NpcPhase.ATTACK
			world.projectiles.fire(npc.npc_instance_id,body.get_rid(),origin,direction,float(cycle.speed),float(cycle.range),cycle.damage_vector,cycle.profile,equipment.item_instance_id,target_id)
	var moving: bool=body.position.distance_to(destination)>float(behavior.return_radius_m)
	if deployment.phase=="retreating":moving=body.position.distance_to(Vector3(deployment.retreat_origin_x,deployment.retreat_origin_y,deployment.retreat_origin_z))<float(fleet.balance.retreat_distance_m)
	var before: Vector3=body.position;var velocity: Vector3=body.position.direction_to(destination)*float(metrics.speed_mps) if moving else Vector3.ZERO
	body.velocity=body.velocity.move_toward(velocity,float(metrics.acceleration_mps2)*delta);body.move_and_slide()
	npc.pos_x=body.position.x;npc.pos_y=body.position.y;npc.pos_z=body.position.z;npc.vel_x=body.velocity.x;npc.vel_y=body.velocity.y;npc.vel_z=body.velocity.z
	npc.quat_x=body.quaternion.x;npc.quat_y=body.quaternion.y;npc.quat_z=body.quaternion.z;npc.quat_w=body.quaternion.w
	fleet.sync_hull(deployment);g.crew.contribute(hull.ship_instance_id,"distance",before.distance_to(body.position))
	if deployment.phase=="retreating":fleet.retreat_step(deployment,delta)
	return true
