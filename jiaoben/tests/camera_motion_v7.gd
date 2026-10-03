extends Node
## Test-only driver: actual Flight.simulate at physical ticks, actual rig at render ticks.
var flight: XJFlight
var rig: XJCameraRig
var moving: bool = false
var physics_steps: int = 0
var render_samples: Array[Dictionary] = []

func _physics_process(delta: float) -> void:
	if not moving: return
	flight.simulate(delta)
	physics_steps += 1

func _process(delta: float) -> void:
	if not moving: return
	rig.step(delta)
	var displayed: Transform3D = rig.render_ship_transform()
	var expected: Transform3D = flight.get_global_transform_interpolated()
	var center: Vector2 = rig.camera.get_viewport().get_visible_rect().size * 0.5
	render_samples.append({"fraction": Engine.get_physics_interpolation_fraction(), "displayed": displayed,
		"expected": expected, "physical": flight.global_transform, "camera": rig.camera.global_transform,
		"center_error": rig.camera.unproject_position(displayed.origin).distance_to(center)})
