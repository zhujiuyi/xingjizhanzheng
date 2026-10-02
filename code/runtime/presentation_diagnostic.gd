extends RefCounted
## Fixed opt-in release health endpoint, confined by Main to a fresh tmp database.
## No arbitrary script, source path, command or production save can be supplied.
const Types = preload("res://contracts/contract_types.gd")

static func run(host: Node, output_dir: String) -> bool:
	var evidence := {"checks": 0, "failures": 0}
	await host._command("new_world", "发布包表现检查", 1, "")
	_check(evidence, host.state != null, "actual packed client creates isolated world")
	if host.state == null: return _finish(evidence)
	host.ui.show_title(host.store.list_slots())
	await host.get_tree().process_frame
	var continue_button: Button = null
	for button: Node in host.ui.panel.find_children("*", "Button", true, false):
		if str(button.text) == "继续航行": continue_button = button
	_check(evidence, continue_button != null, "existing-slot title retains compact continue action")
	if continue_button != null:
		var padding: Vector2 = continue_button.get_theme_stylebox("normal").get_minimum_size()
		var text_width: float = continue_button.get_theme_font("font").get_string_size(continue_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, continue_button.get_theme_font_size("font_size")).x
		_check(evidence, text_width <= continue_button.size.x - padding.x + 1.0, "existing-slot continue label fits one line")
		continue_button.mouse_entered.emit()
		continue_button.mouse_exited.emit()
		_check(evidence, continue_button.has_meta("hover_tween"), "first hover creates feedback without missing metadata")
	await _capture(host, output_dir, "title")
	for page: String in ["station", "missions", "market", "industry", "research", "map", "pause", "settings", "station"]:
		host.ui.show_page(page)
		await host.get_tree().process_frame
		_check(evidence, host.ui.page == page and host.ui.body.get_child_count() > 0, "packed service page " + page)
		for button: Node in host.ui.body.find_children("*", "Button", true, false):
			if not button.disabled:
				button.mouse_entered.emit()
				button.mouse_exited.emit()
				break
	await _capture(host, output_dir, "station")
	host.hangar.focus_service("operations")
	for frame: int in range(90): await host.get_tree().process_frame
	await _capture(host, output_dir, "npc")
	host.hangar.focus_service("")
	host.ui.show_page("station")
	var presentation: XJPresentation = host.presentation
	var dead_voice := AudioStreamPlayer.new()
	presentation.add_child(dead_voice)
	presentation.voices.append(dead_voice)
	dead_voice.free()
	presentation.set_paused(false)
	_check(evidence, presentation.voices.all(func(value: Variant): return is_instance_valid(value)), "pause safely removes freed voice slots")
	var dead_effect := Node3D.new()
	presentation.add_child(dead_effect)
	presentation.effects.append(dead_effect)
	dead_effect.free()
	presentation.hit(host.state.ship().ship_instance_id, true, host.world.flight.global_position)
	_check(evidence, presentation.effects.all(func(value: Variant): return is_instance_valid(value)), "hit safely removes freed effect slots")
	host.ui.show_page("pause")
	await host.get_tree().process_frame
	presentation.ui_result(true)
	var short_voice: Variant = presentation.voices[-1]
	var deadline := Time.get_ticks_msec() + 3000
	while is_instance_valid(short_voice) and Time.get_ticks_msec() < deadline:
		await host.get_tree().process_frame
	_check(evidence, not is_instance_valid(short_voice), "real CoreAudio UI sound finishes during paused menu")
	host.ui.show_page("station")
	presentation.consume(0.0)
	_check(evidence, presentation.voices.all(func(value: Variant): return is_instance_valid(value)), "next frame prunes finished voices without typed-callback errors")
	host._business_action("undock", "", 1, "")
	while host.busy: await host.get_tree().process_frame
	_check(evidence, host.state.ship().status == Types.ShipStatus.FLYING, "packed authoritative departure")
	await _capture(host, output_dir, "flight")
	host.ui.show_page("pause")
	_check(evidence, host.store.save(host.state, "manual", 0), "packed presentation world saves to isolated SQLite")
	# Leave a freed reference immediately before quit to exercise cleanup too.
	var exit_voice := AudioStreamPlayer.new()
	presentation.add_child(exit_voice)
	presentation.voices.append(exit_voice)
	exit_voice.free()
	return _finish(evidence)

static func _capture(host: Node, directory: String, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(8): await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := directory.path_join("release-" + name + ".png")
	var result := host.get_viewport().get_texture().get_image().save_png(path)
	if result != OK: push_error("Release presentation capture failed: " + path)
	else: print("PRESENTATION_CAPTURE ", path)

static func _check(evidence: Dictionary, value: bool, label: String) -> void:
	evidence.checks += 1
	if not value: evidence.failures += 1
	print(("PASS " if value else "FAIL ") + label)

static func _finish(evidence: Dictionary) -> bool:
	print("PRESENTATION_CLIENT_RESULT ", "PASS" if int(evidence.failures) == 0 else "FAIL", " checks=", evidence.checks, " failures=", evidence.failures)
	return int(evidence.failures) == 0
