extends SceneTree
## Calls the production input callback before _ready; no player database opens.
const Main = preload("res://runtime/main.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func key_event(key: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	return event

func _initialize() -> void:
	if InputMap.has_action("fire"): InputMap.erase_action("fire")
	var host := Main.new()
	host.weapon_errors["fixture"] = "pending"
	check(not InputMap.has_action("fire"), "fixture delivers input before action registration")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = false
	var early_events: Array[InputEvent] = [key_event(KEY_CTRL, false), key_event(KEY_CTRL, true), mouse, InputEventMouseMotion.new()]
	for event: InputEvent in early_events:
		host._input(event)
		check(not host.fire_held and host.weapon_errors.has("fixture"), "unmapped startup event preserves input state: " + event.get_class())
	check(not InputMap.has_action("fire"), "early callbacks do not create alternate input mappings")
	host._install_input()
	check(InputMap.has_action("fire"), "normal initialization registers the production fire action")
	host.fire_held = true
	host._input(key_event(KEY_CTRL, false))
	check(not host.fire_held and host.weapon_errors.is_empty(), "registered fire release clears firing and weapon errors")
	host.fire_held = true
	host.weapon_errors["fixture"] = "pending"
	host._input(key_event(KEY_CTRL, true))
	check(host.fire_held and host.weapon_errors.has("fixture"), "fire press preserves the existing release semantics")
	host._input(key_event(KEY_W, false))
	check(host.fire_held and host.weapon_errors.has("fixture"), "unrelated key release does not cancel firing")
	host.free()
	print("INPUT_STARTUP_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
