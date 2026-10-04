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
	if is_inside_tree():
		get_global_transform_interpolated()
		reset_physics_interpolation()

func simulate(delta: float) -> void:
	if record == null or blocked or record.status != Types.ShipStatus.FLYING or delta <= 0.0 or not is_finite(delta):
		return
	if metrics.is_empty():
		return
	var turn: float = float(metrics.turn_radps)
	var requested_spin := (Vector3(intent.pitch_request, intent.yaw_request, -intent.roll_request) * turn).limit_length(turn)
	var before: Quaternion = quaternion.normalized()
	var requested_angle: float = requested_spin.length() * delta
	var directed: Quaternion = before
	if requested_angle > 0.0:
		directed = (before * Quaternion(requested_spin.normalized(), requested_angle)).normalized()
	# Attitude input owns its share of the catalog budget before stabilization.
	# Combining a small heading change with a large old roll and limiting that
	# combined target made A/D spend nearly all of its first ticks on recovery.
	# The sum of these two bounded arcs never exceeds turn_radps * delta.
	var remaining_budget: float = maxf(0.0, turn * delta - requested_angle)
	quaternion = directed
	if is_zero_approx(intent.roll_request) and remaining_budget > 0.0:
		var leveled: Quaternion = leveled_basis(Basis(directed)).get_rotation_quaternion().normalized()
		var recovery: Quaternion = (directed.inverse() * leveled).normalized()
		if recovery.w < 0.0: recovery = -recovery
		var recovery_axis := Vector3(recovery.x, recovery.y, recovery.z)
		var recovery_angle: float = 2.0 * atan2(recovery_axis.length(), recovery.w)
		if recovery_angle > 0.0:
			quaternion = directed.slerp(leveled, minf(1.0, remaining_budget / recovery_angle)).normalized()
	var applied: Quaternion = (before.inverse() * quaternion).normalized()
	if applied.w < 0.0: applied = -applied
	var applied_axis := Vector3(applied.x, applied.y, applied.z)
	var applied_angle: float = 2.0 * atan2(applied_axis.length(), applied.w)
	var local_spin: Vector3 = applied_axis.normalized() * applied_angle / delta
	var thrust := Vector3(intent.thrust_x, intent.thrust_y, -intent.thrust_z)
	if thrust.length_squared() > 1.0:
		thrust = thrust.normalized()
	thrust.x *= float(metrics.strafe_multiplier)
	thrust.y *= float(metrics.strafe_multiplier)
	if thrust.z > 0.0:
		thrust.z *= float(metrics.reverse_multiplier)
	var acceleration: float = float(metrics.acceleration_mps2)
	var top_speed: float = float(metrics.speed_mps)
	var world_thrust: Vector3 = basis * thrust
	if intent.view_thrust_direction.is_finite() and not intent.view_thrust_direction.is_zero_approx():
		world_thrust = (basis * Vector3(thrust.x, thrust.y, 0.0) - intent.view_thrust_direction.normalized() * thrust.z).limit_length(1.0)
	velocity += world_thrust * acceleration * delta
	if intent.brake_requested:
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * float(metrics.brake_multiplier) * delta)
	if velocity.length() > top_speed:
		velocity = velocity.move_toward(velocity.normalized() * top_speed, acceleration * float(metrics.brake_multiplier) * delta)
	move_and_slide()
	write_back(local_spin)

static func leveled_basis(source: Basis) -> Basis:
	# World-up is the shared navigation reference, not a flattened pitch. At
	# a vertical heading roll has no unique reference: preserve the existing
	# right axis rather than passing parallel vectors to looking_at().
	var pose: Basis = source.orthonormalized()
	var forward: Vector3 = -pose.z.normalized()
	var up: Vector3 = Vector3.UP.slide(forward)
	if up.length_squared() < 0.000001:
		var right: Vector3 = pose.x.slide(forward)
		if right.length_squared() < 0.000001: right = Vector3.RIGHT.slide(forward)
		if right.length_squared() < 0.000001: right = Vector3.FORWARD.slide(forward)
		up = right.normalized().cross(forward)
	return Basis.looking_at(forward, up.normalized()).orthonormalized()

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
