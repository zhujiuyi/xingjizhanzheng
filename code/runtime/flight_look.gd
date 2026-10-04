class_name XJFlightLook
extends RefCounted
## Keyboard attitude requests are independent of the camera and screen pointer.
## The fixed-step ship turn limit remains authoritative in the catalog.
var pending_angles: Vector2 = Vector2.ZERO

static func world_rotation_to_input(ship_basis: Basis, world_rotation: Vector3) -> Vector3:
	# Camera yaw can use world-up while the ship is pitched or banked. Convert
	# that same physical axis into FlightInputDto's local (pitch, yaw, -roll)
	# convention before composing it with the other keyboard requests.
	if not ship_basis.is_finite() or not world_rotation.is_finite() or absf(ship_basis.determinant()) < 0.000001:
		return Vector3.ZERO
	var local_spin: Vector3 = ship_basis.orthonormalized().inverse() * world_rotation
	return Vector3(local_spin.x, local_spin.y, -local_spin.z)

func keyboard_turn(ignore_ui_axes: bool = false) -> Vector3:
	# X=pitch, Y=yaw, Z=roll, matching FlightInputDto request fields. A combined
	# attitude command consumes the same catalog turn budget as a single axis.
	return Vector3(0.0 if ignore_ui_axes else _axis("pitch_down", "pitch_up"), _axis("yaw_right", "yaw_left"), _axis("roll_left", "roll_right")).limit_length(1.0)

func manual_override_requested(ignore_ui_axes: bool = false) -> bool:
	# Pointer movement, selection, camera observation and weapon activation are
	# intentionally absent: only explicit motion commands take navigation over.
	for action: String in ["forward", "back", "left", "right", "up", "down", "pitch_up", "pitch_down", "yaw_left", "yaw_right", "roll_left", "roll_right", "brake"]:
		if ignore_ui_axes and action in ["up", "pitch_up", "pitch_down"]: continue
		if InputMap.has_action(action) and Input.is_action_pressed(action): return true
	return false

func _axis(negative: String, positive: String) -> float:
	var negative_strength: float = Input.get_action_strength(negative) if InputMap.has_action(negative) else 0.0
	var positive_strength: float = Input.get_action_strength(positive) if InputMap.has_action(positive) else 0.0
	return positive_strength - negative_strength

# Historical v2 probes exercise these finite motion helpers. The live input
# path uses keyboard_turn(); ordinary mouse movement never calls add_motion().
func add_motion(screen_motion: Vector2, sensitivity: float) -> void:
	var angles := screen_motion * sensitivity
	if is_finite(angles.x) and is_finite(angles.y):
		# One shortest orientation request is sufficient; never queue unlimited spins.
		pending_angles = (pending_angles + angles).limit_length(PI)

func consume(turn_radps: float, delta: float) -> Vector2:
	var budget := turn_radps * delta
	if budget <= 0.0 or pending_angles.is_zero_approx():
		return Vector2.ZERO
	var step := pending_angles.limit_length(budget)
	# Retain at most one extra fixed step for motion arriving between render
	# frames. A large flick must not keep a slow capital ship turning for seconds.
	pending_angles = (pending_angles - step).limit_length(budget)
	return -step / budget

func clear() -> void:
	pending_angles = Vector2.ZERO
