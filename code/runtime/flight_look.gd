class_name XJFlightLook
extends RefCounted
## Relative mouse motion is an angular request, never a permanent screen offset.
## The fixed-step ship turn limit remains authoritative in the catalog.
var pending_angles: Vector2 = Vector2.ZERO

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
