class_name XJFlight
extends CharacterBody3D
## One fixed-tick owner for player motion. All flight limits come from metrics.
const Dtos = preload("res://contracts/contract_dtos.gd")
const Types = preload("res://contracts/contract_types.gd")
var record: Dtos.ShipStateDto
var metrics: Dictionary = {}
var catalog: RefCounted
var intent: Dtos.FlightInputDto = Dtos.FlightInputDto.new()
var blocked: bool = false
var cruising: bool = false
var visual: Node3D
var has_restore: bool = false

func bind(row: Dtos.ShipStateDto, definitions: RefCounted) -> void:
	record = row
	catalog = definitions
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 3
	set_meta("entity_id", row.ship_instance_id)
	set_meta("entity_kind", "player")
	position = Vector3(row.pos_x, row.pos_y, row.pos_z)
	quaternion = Quaternion(row.quat_x, row.quat_y, row.quat_z, row.quat_w).normalized()
	velocity = Vector3(row.vel_x, row.vel_y, row.vel_z)
	has_restore = true

func simulate(delta: float) -> void:
	if record == null or blocked or record.status != Types.ShipStatus.FLYING:
		return
	if metrics.is_empty():
		return
	var turn: float = float(metrics.turn_radps)
	var local_spin := Vector3(intent.pitch_request, intent.yaw_request, -intent.roll_request) * turn
	if local_spin.length_squared() > 0.0:
		var rotation_step := Quaternion(local_spin.normalized(), minf(local_spin.length(), turn) * delta)
		quaternion = (quaternion * rotation_step).normalized()
	var thrust := Vector3(intent.thrust_x, intent.thrust_y, -intent.thrust_z)
	if thrust.length_squared() > 1.0:
		thrust = thrust.normalized()
	thrust.x *= float(metrics.strafe_multiplier)
	thrust.y *= float(metrics.strafe_multiplier)
	if thrust.z > 0.0:
		thrust.z *= float(metrics.reverse_multiplier)
	var acceleration: float = float(metrics.acceleration_mps2)
	var top_speed: float = float(metrics.speed_mps)
	velocity += basis * thrust * acceleration * delta
	if intent.brake_requested:
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * float(metrics.brake_multiplier) * delta)
	if velocity.length() > top_speed:
		velocity = velocity.move_toward(velocity.normalized() * top_speed, acceleration * float(metrics.brake_multiplier) * delta)
	move_and_slide()
	write_back(local_spin)

func write_back(spin: Vector3 = Vector3.ZERO) -> void:
	if record == null:
		return
	record.pos_x = position.x
	record.pos_y = position.y
	record.pos_z = position.z
	record.vel_x = velocity.x
	record.vel_y = velocity.y
	record.vel_z = velocity.z
	var q := quaternion.normalized()
	record.quat_x = q.x
	record.quat_y = q.y
	record.quat_z = q.z
	record.quat_w = q.w
	record.angular_x = spin.x
	record.angular_y = spin.y
	record.angular_z = spin.z

func clear_intent() -> void:
	intent = Dtos.FlightInputDto.new()
	cruising = false

func muzzle(slot_index: int) -> Transform3D:
	var anchor := get_node_or_null("Hardpoints/weapon_%d/muzzle" % slot_index) as Node3D
	if anchor != null:
		return anchor.global_transform
	return global_transform
