class_name XJPresentation
extends Node3D
## Bounded visual/audio consumer. It never settles damage, work or currency.
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const Factory = preload("res://runtime/visuals/visual_factory.gd")
const Effects = preload("res://runtime/visuals/visual_effects.gd")
var world: XJSector
var gameplay: RefCounted
var catalog: XJCatalog
var config: Dictionary = {}
var intensity: float = 1.0
var effects: Array[Node3D] = []
var voices: Array[Node] = []
var loops: Dictionary = {}
var beam_clock: float = 0.0
var gates: Array[Node3D] = []
var effects_paused: bool = false

func _exit_tree() -> void:
	_prune_nodes(voices)
	for voice: Node in voices:
		if is_instance_valid(voice):
			voice.call("stop")
			voice.set("stream", null)
	voices.clear()
	loops.clear()

func setup(sector: XJSector, business: RefCounted, definitions: XJCatalog, effect_intensity: float) -> void:
	world = sector
	gameplay = business
	catalog = definitions
	intensity = effect_intensity
	for row in catalog.rows("presentation_defs"):
		config[row.presentation_id] = row.value_integer if row.value_integer != null else row.value_real
	for bus in ["SFX", "Music", "UI"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), float(config["audio_" + bus.to_lower() + "_db"]))
	for target: Dictionary in world.targets.values():
		if target.kind == "gate" and intensity > 0.0:
			var gate := Effects.wormhole(float(target.node.get_meta("aperture_radius_m", 64.0)), Color("4edcf2"), config)
			target.node.add_child(gate)
			gates.append(gate)

func set_paused(stopped: bool) -> void:
	effects_paused = stopped
	_prune_nodes(gates)
	_prune_nodes(effects)
	_prune_nodes(voices)
	for gate: Node3D in gates:
		if is_instance_valid(gate): gate.process_mode = Node.PROCESS_MODE_DISABLED if stopped else Node.PROCESS_MODE_INHERIT
	for effect: Node3D in effects:
		_pause_particles(effect, stopped)
	for voice in voices:
		if is_instance_valid(voice) and voice.get("bus") != "UI":
			voice.set("stream_paused", stopped)

func _pause_particles(node: Node, stopped: bool) -> void:
	# GPU simulation is driven by RenderingServer, independently of the
	# effect Node's visual clock. Freeze both clocks when menus pause combat.
	if node is GPUParticles3D: (node as GPUParticles3D).speed_scale = 0.0 if stopped else 1.0
	for child: Node in node.get_children(): _pause_particles(child, stopped)

func consume(delta: float) -> void:
	if gameplay == null:
		return
	var events: Array = gameplay.get("events")
	for event: Dtos.EventDto in events:
		var source := _node(event.source_entity_id)
		var point := source.global_position if source != null else Vector3(event.pos_x, event.pos_y, event.pos_z)
		match event.kind:
			Types.EventKind.WEAPON_FIRED:
				var equipment := world.state.find("equipment_state", "item_instance_id", event.module_instance_id) as Dtos.EquipmentStateDto
				if equipment != null:
					var weapon: Dictionary = catalog.one("weapon_defs", "module_id", equipment.module_def_id)
					_play("weapon_" + str(weapon.get("damage_type", "kinetic")), point)
					var slot := world.state.find("container_state", "container_id", equipment.slot_container_id) as Dtos.ContainerStateDto
					if slot != null and source != null:
						var muzzle := source.get_node_or_null("Hardpoints/weapon_%d/muzzle" % slot.slot_index) as Node3D
						var family: String = str(weapon.get("damage_type", "kinetic"))
						if catalog.table_names.has("weapon_behavior_defs"):
							family = str(catalog.one("weapon_behavior_defs", "module_id", equipment.module_def_id).get("family_id", family))
						if muzzle != null and family != "drone": _add(Effects.muzzle(muzzle.global_position, family, config))
			Types.EventKind.SHIP_DESTROYED:
				var radius := _radius(source)
				_add(Effects.explosion(point, radius * float(config.fx_explosion_radius_ship_multiplier), Color("ffc078"), config))
				_play("explosion", point)
			Types.EventKind.SCAN_STARTED: _play("scan_pulse", point)
			Types.EventKind.SCAN_ENDED: _play("ui_confirm", point, "UI")
			Types.EventKind.MINING_STARTED: _play("mining_loop", point, "SFX", "mining")
			Types.EventKind.MINING_ENDED: _stop_loop("mining")
			_: pass
	events.clear()
	beam_clock += delta
	if beam_clock >= float(config.fx_beam_lifetime_s) * 0.5:
		beam_clock = 0.0
		var work: RefCounted = gameplay.get("work")
		var target_id: String = str(work.get("mining_target"))
		if not target_id.is_empty() and world.targets.has(target_id):
			var target: Node3D = world.targets[target_id].node
			for slot: Dtos.ContainerStateDto in world.state.rows("container_state"):
				if slot.ship_instance_id != world.state.ship().ship_instance_id or slot.kind != Types.ContainerKind.SLOT or slot.slot_type != Types.SlotType.WORK:
					continue
				var hardpoint := world.flight.get_node_or_null("Hardpoints/work_%d" % slot.slot_index) as Node3D
				if hardpoint != null:
					_add(Effects.beam(hardpoint.global_position, target.global_position, Color("ffc47e"), config))
	var thrust := world.flight.intent
	var running: bool = absf(thrust.thrust_z) + absf(thrust.thrust_x) + absf(thrust.thrust_y) > 0.0
	if running and world.state.ship().status == Types.ShipStatus.FLYING:
		if not loops.has("engine"): _play("engine_loop", world.flight.global_position, "SFX", "engine")
	else:
		_stop_loop("engine")
	if world.state.player().has_docked_station_id:
		if not loops.has("station"): _play("station_ambience", world.flight.global_position, "Music", "station")
	else:
		_stop_loop("station")
	for key in loops:
		var voice: Variant = loops[key]
		if is_instance_valid(voice): voice.global_position = world.flight.global_position
	_prune_nodes(effects)
	_prune_nodes(voices)

func _prune_nodes(nodes: Array) -> void:
	# Freed Node references cannot be converted into a typed lambda argument.
	# Validate the Variant slot first, then keep the original typed array alive.
	for index: int in range(nodes.size() - 1, -1, -1):
		if not is_instance_valid(nodes[index]): nodes.remove_at(index)

func hit(target_id: String, shielded: bool, point: Vector3, damage: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.ZERO) -> void:
	var node := _node(target_id)
	if node == null:
		return
	var color: Color = Color("facb8e")
	if damage.z > maxf(damage.x, damage.y): color = Color("aa91eb")
	elif damage.y > damage.x: color = Color("ffad79")
	var owner_pose: Transform3D = node.get_global_transform_interpolated()
	var local_contact: Vector3 = owner_pose.affine_inverse() * point
	var contact_normal: Vector3 = normal if not normal.is_zero_approx() else owner_pose.basis * local_contact.normalized()
	if shielded:
		_prune_nodes(effects)
		var count: int = 0
		for active: Node3D in effects:
			if is_instance_valid(active) and active.get_meta("shield_entity", "") == target_id:
				count += 1
		if count >= int(config.fx_shield_hits_per_ship_max):
			return
		var half_extents: Vector3 = _half_extents(node)
		var sphere_direction: Vector3 = local_contact / half_extents
		var pulse := Effects.shield_contact(half_extents, sphere_direction, Color("77b6e3"), config)
		pulse.set_meta("shield_entity", target_id)
		pulse.set_meta("hit_kind", "shield")
		pulse.set("follow_target", weakref(node))
		pulse.transform = owner_pose
		_add(pulse)
		_play("shield_hit", point)
	else:
		var flash := Effects.impact(point, color, config, contact_normal)
		flash.set_meta("hit_entity", target_id)
		flash.set_meta("hit_kind", "armor")
		_add(flash)
		_play("armor_hit", point)

func impact(point: Vector3, color: Color, normal: Vector3 = Vector3.UP) -> void:
	var flash := Effects.impact(point, color, config, normal)
	flash.set_meta("hit_kind", "environment")
	_add(flash)

func ui_result(success: bool) -> void:
	_play("ui_confirm" if success else "ui_error", Vector3.ZERO, "UI")

func situational_cue(cue: Dictionary) -> void:
	# Audio remains available at zero VFX intensity and follows the user's UI bus.
	var sound_id: String = str(cue.get("sound_id",""))
	if not sound_id.is_empty(): _play(sound_id,Vector3.ZERO,"UI")

func jump(charging: bool) -> void:
	_play("jump_charge" if charging else "jump_arrival", world.flight.global_position, "SFX")

func _add(node: Node3D) -> void:
	_prune_nodes(effects)
	var particle_count: int = _particles(node)
	for active in effects:
		particle_count += _particles(active)
	if intensity <= 0.0 or effects.size() >= int(config.fx_active_instances_max) or particle_count > int(config.fx_particle_budget_max):
		node.free()
		return
	add_child(node)
	_pause_particles(node, effects_paused)
	effects.append(node)

func companion_support(npc_id: String,ship_id: String,layer: String) -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.flight) or world.flight.record.ship_instance_id!=ship_id or not world.npcs.has(npc_id):return
	var node: Node3D=Effects.beam(world.npcs[npc_id].global_position,world.flight.global_position,Color("8ce6cf") if layer=="shield" else Color("e8c48a"),config)
	if node!=null:_add(node)

func _particles(node: Node) -> int:
	var count: int = node.amount if node is GPUParticles3D else 0
	for child in node.get_children():
		count += _particles(child)
	return count

func _node(id: String) -> Node3D:
	if id == world.state.ship().ship_instance_id:
		return world.flight
	if world.targets.has(id):
		var target: Variant = world.targets[id].node
		return target as Node3D if is_instance_valid(target) else null
	return null

func _radius(node: Node3D) -> float:
	if node == null:
		return 1.0
	var shape := node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		return (shape.shape as BoxShape3D).size.length() * 0.5
	return 1.0

func _half_extents(node: Node3D) -> Vector3:
	var shape := node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		return (shape.shape as BoxShape3D).size * 0.5
	return Vector3.ONE

func _play(sound_id: String, point: Vector3, bus: String = "SFX", loop_id: String = "") -> void:
	_prune_nodes(voices)
	if voices.size() >= int(config.audio_voice_limit):
		return
	var stream := Factory.sound(sound_id)
	if stream == null:
		return
	if bus == "UI":
		var voice := AudioStreamPlayer.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		voice.stream = stream
		voice.bus = bus
		voice.finished.connect(voice.queue_free)
		add_child(voice)
		voices.append(voice)
		voice.play()
	else:
		var voice := AudioStreamPlayer3D.new()
		voice.stream = stream
		voice.bus = bus
		voice.finished.connect(voice.queue_free)
		add_child(voice)
		voice.global_position = point
		voices.append(voice)
		if not loop_id.is_empty(): loops[loop_id] = voice
		voice.play()

func _stop_loop(id: String) -> void:
	if loops.has(id):
		var voice: Variant = loops[id]
		if is_instance_valid(voice):
			voice.call("stop")
			voice.set("stream", null)
			voice.queue_free()
		loops.erase(id)
