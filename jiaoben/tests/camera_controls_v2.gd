extends SceneTree
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
const Factory = preload("res://runtime/visuals/visual_factory.gd")
const Main = preload("res://runtime/main.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func _run() -> void:
	var catalog := XJCatalog.new()
	check(catalog.open(), "read actual catalog " + catalog.last_error)
	if not failures.is_empty(): quit(1); return
	var sensitivity: float = 0.002 # Deterministic test stimulus, not a game preference definition.
	# Use actual shipped motion metrics: no alternative turn-rate constants.
	var turn: float = float(catalog.one("ship_defs", "ship_id", "shuttle_swift").turn_rad_s)
	check(turn > 0.0, "catalog has authoritative turn budget")
	var expected := Vector2(120, -75) * sensitivity
	for hz: int in [30, 60, 144]:
		var input := XJFlightLook.new()
		var integrated := Vector2.ZERO
		var bounded := true
		for frame: int in range(hz):
			input.add_motion(Vector2(120, -75) / hz, sensitivity)
			var request := input.consume(turn, 1.0 / hz)
			bounded = bounded and request.length() <= 1.00001
			integrated -= request * turn / hz
		check(bounded and integrated.distance_to(expected) < 0.00001, "steady relative motion below catalog limit is time-consistent at %d Hz" % hz)
		check(input.consume(turn, 1.0 / hz).is_zero_approx(), "no cursor-offset spin after finite request at %d Hz" % hz)
	var invalid := XJFlightLook.new()
	invalid.add_motion(Vector2(INF, NAN), sensitivity)
	check(invalid.pending_angles.is_zero_approx(), "invalid motion never poisons orientation")
	invalid.add_motion(Vector2(100000, 50000), sensitivity)
	check(invalid.pending_angles.length() <= PI + 0.00001, "large motion bounded to shortest angular request")
	var held := invalid.pending_angles
	check(invalid.consume(turn, 0).is_zero_approx() and invalid.pending_angles == held, "zero time cannot consume motion")
	invalid.clear()
	check(invalid.consume(turn, 1.0 / 60).is_zero_approx(), "clear discards pending steering")
	var simulation_hz := int(catalog.rule("simulation_hz"))
	for definition: Dictionary in catalog.rows("ship_defs"):
		var flick := XJFlightLook.new()
		flick.add_motion(Vector2(100000, 50000), sensitivity)
		var first := flick.consume(float(definition.turn_rad_s), 1.0 / simulation_hz)
		var second := flick.consume(float(definition.turn_rad_s), 1.0 / simulation_hz)
		check(first.length() <= 1.00001 and second.length() <= 1.00001 and flick.consume(float(definition.turn_rad_s), 1.0 / simulation_hz).is_zero_approx(), "%s large flick stops by two physics ticks, including slow hulls" % definition.ship_id)
	for render_hz: int in [30, 60, 144]:
		var stream := XJFlightLook.new()
		var event_index: int = 0
		var total: float = 0.0
		for step_index: int in range(simulation_hz):
			var elapsed := (step_index + 0.5) / simulation_hz
			while float(event_index) / render_hz <= elapsed:
				stream.add_motion(Vector2(10000.0 / render_hz, 0), sensitivity)
				event_index += 1
			total += stream.consume(turn, 1.0 / simulation_hz).length() * turn / simulation_hz
		check(absf(total - turn) < 0.00001, "sustained saturated input preserves turn limit with %d render Hz/%d physics Hz" % [render_hz,simulation_hz])

	var stage := Node3D.new()
	root.add_child(stage)
	var rig := XJCameraRig.new()
	stage.add_child(rig)
	for definition: Dictionary in catalog.rows("ship_defs"):
		var wrapper: CharacterBody3D = Factory.scene(definition.ship_id)
		var flight := XJFlight.new()
		for child: Node in wrapper.get_children():
			wrapper.remove_child(child)
			child.owner = null
			flight.add_child(child)
		wrapper.free()
		stage.add_child(flight)
		var record := D.ShipStateDto.new()
		record.ship_instance_id = "camera_" + str(definition.ship_id)
		record.ship_def_id = definition.ship_id
		record.status = T.ShipStatus.FLYING
		record.quat_w = 1.0
		flight.bind(record, catalog)
		flight.visual = flight.get_node("VisualRoot")
		for size: Vector2i in [Vector2i(1280,720), Vector2i(1440,900), Vector2i(1920,1080)]:
			root.size = size
			await process_frame
			for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.TACTICAL]:
				rig.bind(flight, catalog, mode)
				rig.step(1.0 / 60)
				var centered := true
				for frame: int in range(8):
					flight.position = Vector3(frame * 17.0, frame * 3.0, -frame * 23.0)
					flight.rotation = Vector3(frame * 0.04, frame * 0.09, frame * 0.02)
					rig.observe(Vector2(15,-8), sensitivity)
					rig.step(1.0 / 60)
					var center := rig.camera.get_viewport().get_visible_rect().size * 0.5
					centered = centered and rig.camera.unproject_position(flight.global_position).distance_to(center) < 0.02
				check(centered, "%s mode%d centers moving/turning/orbiting ship at %s" % [definition.ship_id, mode, size])
			rig.bind(flight, catalog, T.CameraMode.FRONT)
			rig.step(1.0 / 60)
			var anchor := flight.get_node("FrontCamera") as Node3D
			check(rig.camera.global_position.is_equal_approx(anchor.global_position) and rig.camera.global_basis.is_equal_approx(flight.global_basis), "%s cockpit follows exact anchor/pose at %s" % [definition.ship_id,size])
			var pose := flight.global_transform
			rig.observe(Vector2(150,40), sensitivity)
			rig.step(1.0 / 60)
			check(flight.global_transform.is_equal_approx(pose) and not rig.camera.global_basis.is_equal_approx(flight.global_basis), "%s free look changes only camera at %s" % [definition.ship_id,size])
			rig.reset_observation()
			rig.step(1.0 / 60)
			check(rig.camera.global_basis.is_equal_approx(flight.global_basis), "%s free look reset restores cockpit at %s" % [definition.ship_id,size])
		var follow: Dictionary = {}
		for profile: Dictionary in catalog.rows("camera_profile_defs"):
			if profile.ship_id == definition.ship_id and profile.mode == "follow": follow = profile
		for steps: int in [-30, 30]:
			rig.bind(flight, catalog, T.CameraMode.FOLLOW)
			rig.scroll_zoom(steps)
			var pole := -atan2(float(follow.zoom_min_m if steps < 0 else follow.zoom_max_m), float(follow.height_m))
			var stable := true
			for pitch: float in [pole - 0.01, pole, pole + 0.01, -PI, PI]:
				rig.orbit = Vector2(0, pitch)
				rig.snapped = false
				rig.step(1.0 / 60)
				stable = stable and rig.camera.global_basis.y.dot(flight.global_basis.y) > 0 and absf(rig.camera.global_basis.determinant() - 1.0) < 0.0001
			check(stable, "%s zoom%d clamps final elevation across authored-height pole" % [definition.ship_id,steps])
		for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.TACTICAL]:
			flight.position = Vector3.ZERO
			flight.basis = Basis.IDENTITY
			rig.bind(flight, catalog, mode)
			rig.snapped = true
			rig.camera.global_position = Vector3(0,30,0)
			rig.step(0.0)
			check(absf(rig.camera.global_basis.determinant() - 1.0) < 0.0001 and rig.camera.unproject_position(flight.global_position).distance_to(rig.camera.get_viewport().get_visible_rect().size * 0.5) < 0.02, "%s mode%d transient dolly/up collinearity remains valid and centered" % [definition.ship_id,mode])
		stage.remove_child(flight)
		flight.free()
	stage.free()
	catalog.close()

	# Route actual UI + stage authority using an isolated SQLite world.
	var path := ProjectSettings.globalize_path("res://../jiaoben/tmp/camera-controls-v2.db")
	DirAccess.remove_absolute(path)
	var host := Main.new()
	host.progress_database_path = path
	root.add_child(host)
	await process_frame
	check(host.services_ready and host.hangar != null, "hangar prepared before any durable new-world boundary")
	await host._command("new_world", "镜头操控验收", 1, "")
	check(host.state != null, "actual client new world")
	if host.state != null:
		host._sync_presentation_stage()
		check(host.presentation_stage == "hangar" and not host.world.visible and host.hangar.get_camera().is_current(), "docked client uses isolated real hangar camera")
		var escape := InputEventAction.new()
		escape.action = "menu"
		escape.pressed = true
		host._unhandled_input(escape)
		check(host.ui.page == "pause", "station Esc opens pause")
		var resume: Button = null
		for button: Node in host.ui.panel.find_children("*", "Button", true, false):
			if button.text == "继续航行": resume = button
		check(resume != null, "actual pause resume button exists")
		if resume != null: resume.pressed.emit()
		check(host.ui.page == "station", "pause resume button returns docked station services")
		host.ui.show_page("pause")
		host._unhandled_input(escape)
		check(host.ui.page == "station", "pause Esc returns docked station")
		host.ui.show_page("market")
		host._unhandled_input(escape)
		check(host.ui.page == "station", "station business Esc returns real hangar")
		host.ui.show_page("map")
		var locate: Button = null
		for button: Node in host.ui.panel.find_children("*", "Button", true, false):
			if str(button.text).begins_with("定位 "): locate = button; break
		check(locate != null, "actual docked star map locate button exists")
		if locate != null: locate.pressed.emit()
		check(host.ui.page == "station", "docked star map locate retains service/undock UI")
		# Simulate a previously used flight camera at the old docking approach.
		host.camera.snapped = true
		host.camera.camera.global_position = Vector3(9000,9000,9000)
		host._business_action("undock", "", 1, "")
		while host.busy: await process_frame
		host._sync_presentation_stage()
		check(host.presentation_stage == "flight" and host.world.visible and not host.hangar.visible and host.camera.camera.is_current(), "undock restores flight camera and hides stage")
		host.camera.step(1.0 / 60)
		var current_profile: Dictionary = {}
		for profile: Dictionary in host.store.catalog.rows("camera_profile_defs"):
			if profile.ship_id == host.state.ship().ship_def_id and profile.mode == "follow": current_profile = profile
		check(host.camera.camera.global_position.distance_to(host.world.flight.global_position) <= Vector2(float(current_profile.zoom_max_m),float(current_profile.height_m)).length() + 0.001, "repeated departure snaps rather than interpolating from old docking approach")
		host.observing = true
		host.camera.observe(Vector2(150,40), 0.002)
		host.flight_look.add_motion(Vector2(300,40), 0.002)
		host._release_observation()
		check(not host.observing and not host.fire_held and host.camera.orbit.is_zero_approx() and host.flight_look.pending_angles.is_zero_approx(), "release/focus loss discards steering and resets observation")
		host.ui.show_page("pause")
	host.queue_free()
	await process_frame
	print("CAMERA_CONTROLS_V2_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
