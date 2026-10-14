extends Node
## Real title/pause button dispatch and uninterrupted native Main callbacks.
## No progression, money, pose, render, simulation or save-state fixtures.
const Main = preload("res://runtime/main.gd")
const ENV_PREFIX: String = "XJ_STARTUP_NAVIGATION_V62"
const SCRIPT_FILENAME: String = "startup_navigation_v62.gd"
const DIRECTORY_PREFIX: String = "startup-navigation-v62"
const DIAGNOSTIC_META: String = "xj_startup_navigation_v62_diagnostic"
var host: Node
var directory: String = ""
var checks: int = 0
var failures: Array[String] = []
var requests: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var screenshots: Array[String] = []
var phase: String = "initializing"
var phase_stats: Dictionary = {}
var process_frames: int = 0
var physics_frames: int = 0
var render_frames: int = 0
var last_frame_us: int = 0
var last_heartbeat_us: int = 0
var max_frame_ms: float = 1000.0
var finishing: bool = false
var profile_copy: bool = false
var profile_new_first: bool = false
var seed_sha256: String = ""
var seed_world_id: String = ""
@onready var root: Window = get_tree().root

func _ready() -> void:
	get_tree().set_meta(DIAGNOSTIC_META, true)
	RenderingServer.frame_post_draw.connect(_rendered)
	last_frame_us = Time.get_ticks_usec()
	run.call_deferred()

func _rendered() -> void:
	render_frames += 1
	if not is_instance_valid(host) or not host.busy or not phase_stats.has(phase): return
	var row: Dictionary = phase_stats[phase]
	row.busy_render_frames = int(row.get("busy_render_frames", 0)) + 1
	var status: Dictionary = loading_status()
	if not status.is_empty():
		row.visible_status_render_frames = int(row.get("visible_status_render_frames", 0)) + 1
		row.status_text = status.stage
		row.status_presenter = status.presenter
		if status.presenter == "loading_overlay":
			var elapsed_values: Dictionary = row.get("elapsed_label_values", {})
			elapsed_values[str(status.elapsed)] = true; row.elapsed_label_values = elapsed_values
			row.main_store_isolation_frames = int(row.get("main_store_isolation_frames", 0)) + (1 if host.process_mode == Node.PROCESS_MODE_DISABLED and not host.ui.root.visible else 0)
		if not row.has("status_capture"):
			var path: String = directory.path_join(phase + "-loading.png")
			var image: Image = root.get_texture().get_image()
			if not image.is_empty() and image.save_png(path) == OK:
				row.status_capture = path; screenshots.append(path)

func has_property(object: Object, key: String) -> bool:
	for item: Dictionary in object.get_property_list():
		if str(item.name) == key: return true
	return false

func loading_status() -> Dictionary:
	# Old PCKs have only operation_bar. Never read a missing property on them.
	if has_property(host, "loading_overlay"):
		var overlay: Node = host.get("loading_overlay") as Node
		if is_instance_valid(overlay):
			var stage_label: Label = overlay.get("stage_label") as Label
			var elapsed_label: Label = overlay.get("elapsed_label") as Label
			if is_instance_valid(stage_label) and stage_label.is_visible_in_tree() and not stage_label.text.is_empty() and is_instance_valid(elapsed_label):
				return {"presenter": "loading_overlay", "stage": stage_label.text, "elapsed": elapsed_label.text}
	if is_instance_valid(host.ui) and host.ui.operation_bar.is_visible_in_tree() and not host.ui.operation_label.text.is_empty():
		return {"presenter": "operation_bar", "stage": host.ui.operation_label.text, "elapsed": ""}
	return {}
func _physics_process(_delta: float) -> void: physics_frames += 1

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var gap: float = float(now - last_frame_us) / 1000.0
	last_frame_us = now; process_frames += 1
	if phase_stats.has(phase):
		var row: Dictionary = phase_stats[phase]
		row.frames = int(row.frames) + 1
		row.maximum_frame_gap_ms = maxf(float(row.maximum_frame_gap_ms), gap)
	if now - last_heartbeat_us >= 1000000:
		last_heartbeat_us = now
		print("STARTUP_NAVIGATION_HEARTBEAT ", JSON.stringify({"phase": phase, "process_frames": process_frames, "physics_frames": physics_frames, "render_frames": render_frames, "busy": host.busy if is_instance_valid(host) else false}))

func check(ok: bool, description: String) -> bool:
	checks += 1
	print(("PASS " if ok else "FAIL ") + description)
	if not ok: failures.append(description)
	return ok

func set_phase(next: String) -> void:
	var now: int = Time.get_ticks_usec()
	if phase_stats.has(phase):
		# A synchronous load can finish and switch phase before this Node's next
		# _process callback. Attribute that entire pending gap to its load phase.
		var previous: Dictionary = phase_stats[phase]
		previous.maximum_frame_gap_ms = maxf(float(previous.maximum_frame_gap_ms), float(now - last_frame_us) / 1000.0)
		previous.finished_us = now; previous.elapsed_ms = float(now - int(previous.started_us)) / 1000.0
	last_frame_us = now
	phase = next
	phase_stats[phase] = {"started_us": now, "frames": 0, "maximum_frame_gap_ms": 0.0, "busy_render_frames": 0, "visible_status_render_frames": 0}
	print("STARTUP_NAVIGATION_PHASE ", next)

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func wait_until(predicate: Callable, description: String, timeout_s: float = 45.0) -> bool:
	var started: int = Time.get_ticks_usec()
	while not predicate.call() and float(Time.get_ticks_usec() - started) < timeout_s * 1000000.0:
		await get_tree().process_frame
	var ok: bool = bool(predicate.call())
	observations.append({"event": description, "elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0, "phase_elapsed_ms": float(Time.get_ticks_usec() - int(phase_stats[phase].started_us)) / 1000.0, "completed": ok})
	return check(ok, description + " completes within " + str(timeout_s) + " seconds")

func find_button(caption: String) -> Button:
	for node: Node in host.ui.body.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == caption and button.is_visible_in_tree(): return button
	return null

func click(caption: String, expected_action: String) -> bool:
	var button: Button = find_button(caption)
	if not check(button != null and not button.disabled, "real visible enabled button exists: " + caption): return false
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	root.grab_focus()
	await frames(3)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	if not check(Rect2(Vector2.ZERO, root.get_visible_rect().size).has_point(point), "real button center is in the client viewport: " + caption): return false
	var before: int = requests.size()
	var moved := InputEventMouseMotion.new(); moved.position = point; moved.global_position = point
	root.push_input(moved, true); await frames(2)
	var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = point; down.global_position = point; down.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(down, true); await frames(1)
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = point; up.global_position = point
	root.push_input(up, true)
	await frames(1)
	return check(requests.size() == before + 1 and str(requests[-1].action) == expected_action, "mouse down/up dispatches exactly one real " + expected_action + " request")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = directory.path_join(name + ".png")
	if check(not image.is_empty() and image.get_size() == root.size and image.save_png(path) == OK, "native client capture " + name): screenshots.append(path)

func observe_running(name: String) -> bool:
	set_phase(name)
	var start: int = Time.get_ticks_usec()
	var process_before: int = process_frames
	var physics_before: int = physics_frames
	var render_before: int = render_frames
	var tick_before: int = host.state.snapshot.meta.simulation_tick
	while process_frames - process_before < 120 or Time.get_ticks_usec() - start < 5000000:
		await get_tree().process_frame
		if Time.get_ticks_usec() - start > 30000000: break
	var seconds: float = float(Time.get_ticks_usec() - start) / 1000000.0
	var record: Dictionary = {"event": name, "seconds": seconds, "process_frames": process_frames - process_before, "physics_frames": physics_frames - physics_before, "render_frames": render_frames - render_before, "simulation_ticks": host.state.snapshot.meta.simulation_tick - tick_before, "maximum_frame_gap_ms": phase_stats[name].maximum_frame_gap_ms}
	observations.append(record)
	var live: bool = host.is_processing() and host.is_physics_processing() and host.can_process() and host.process_mode != Node.PROCESS_MODE_DISABLED and host.ui.root.is_visible_in_tree() and not host.busy and not host.store.busy and host.store.phase == "READY" and not host._paused()
	live = live and int(record.process_frames) >= 120 and seconds >= 5.0 and int(record.physics_frames) >= 120 and int(record.render_frames) >= 120 and int(record.simulation_ticks) > 0
	check(live, name + " retains normal Main process/physics, live simulation and at least 120 rendered frames over five seconds")
	check(float(record.maximum_frame_gap_ms) <= max_frame_ms, name + " has no frame gap beyond the declared responsiveness budget")
	var docked: bool = host.state.player().has_docked_station_id
	check((host.ui.page == "station" and host.hangar.is_visible_in_tree() and root.get_camera_3d() == host.hangar.get_camera()) if docked else (host.world.is_visible_in_tree() and not host.hangar.is_visible_in_tree() and root.get_camera_3d() == host.camera.camera), name + " reaches its actual saved docked or flight scene and active native camera")
	if has_property(host, "loading_overlay"): check(host.get("loading_overlay") == null, name + " restores processing and releases the loading overlay after joining the worker")
	await capture(name)
	return live

func open_pause() -> bool:
	var down := InputEventKey.new(); down.keycode = KEY_ESCAPE; down.physical_keycode = KEY_ESCAPE; down.pressed = true
	root.push_input(down, true)
	var up := InputEventKey.new(); up.keycode = KEY_ESCAPE; up.physical_keycode = KEY_ESCAPE; up.pressed = false
	root.push_input(up, true)
	await frames(4)
	return check(host.ui.page == "pause", "real Escape input opens the pause screen after the live observation")

func return_to_title() -> bool:
	set_phase("return_title_button")
	if not await open_pause() or not await click("保存并返回主菜单", "return_title"): return false
	if not await wait_until(func() -> bool: return not host.busy and host.state == null and host.ui.page == "title", "real save and return to title"): return false
	check(not host.store.list_slots().is_empty(), "real return workflow sealed a resumable test-owned archive")
	await frames(8); await capture("title-saved")
	return true

func load_from_button(action: String) -> bool:
	set_phase("new_world_button" if action == "new_world" else "continue_button")
	if not await click("建立新远征" if action == "new_world" else "继续航行", action): return false
	if not await wait_until(func() -> bool: return not host.busy and host.state != null and host.world != null, action + " voyage through title button"): return false
	var row: Dictionary = phase_stats[phase]
	check(int(row.visible_status_render_frames) > 0, action + " operation status is visibly rendered before completion")
	if str(row.get("status_presenter", "")) == "loading_overlay":
		check(int(row.get("main_store_isolation_frames", 0)) == int(row.visible_status_render_frames), action + " suspends every Main consumer and hides old UI while the overlay renders")
		if Time.get_ticks_usec() - int(row.started_us) > 1500000: check(row.get("elapsed_label_values", {}).size() > 1, action + " updates the actual elapsed label during long loading")
	return true

func verify_seed_world_retained(event: String) -> void:
	if not profile_copy: return
	if not check(not host.busy and not host.store.busy, "seed-world preservation query runs only after loading has completed"): return
	var rows: Array = host.store._records("SELECT world_id FROM world WHERE world_id=?", [seed_world_id])
	var retained: bool = rows.size() == 1
	check(retained, "original seed world remains in the working test archive " + event)
	observations.append({"event": event, "seed_world_id": seed_world_id, "seed_world_retained": retained, "active_world_id": host.state.world_id})

func run() -> void:
	directory = OS.get_environment(ENV_PREFIX + "_DIRECTORY").replace("\\", "/")
	var script: String = str(get_script().resource_path).replace("\\", "/")
	var requested: String = OS.get_environment(ENV_PREFIX + "_SCRIPT").replace("\\", "/")
	var expected: String = script.get_base_dir().get_base_dir().path_join("tmp/" + DIRECTORY_PREFIX)
	var pattern := RegEx.new(); pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	if not check(DisplayServer.get_name() != "headless" and script.is_absolute_path() and script.ends_with("/jiaoben/tests/" + SCRIPT_FILENAME) and not script.contains("..") and requested == script and directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == expected and pattern.search(directory.get_file()) != null and not FileAccess.file_exists(directory.path_join("progress.db")), "native fixed external diagnostic and fresh scoped UUID database required"):
		get_tree().quit(2); return
	var seed: String = directory.path_join("seed.db")
	if FileAccess.file_exists(seed):
		seed_sha256 = OS.get_environment(ENV_PREFIX + "_PROFILE_SEED_SHA256")
		var origin: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("seed-origin.json")))
		if not check(seed_sha256.length() == 64 and FileAccess.get_sha256(seed) == seed_sha256 and origin is Dictionary and str(origin.get("sha256", "")) == seed_sha256 and not str(origin.get("resume_world_id", "")).is_empty(), "scoped seed is a verified closed-copy input before Main opens it"):
			await finish(); return
		seed_world_id = str(origin.resume_world_id)
		if not check(DirAccess.copy_absolute(seed, directory.path_join("progress.db")) == OK and FileAccess.get_sha256(directory.path_join("progress.db")) == seed_sha256, "only the scoped seed is copied to the fresh diagnostic progress database"):
			await finish(); return
		profile_copy = true
	profile_new_first = OS.get_environment(ENV_PREFIX + "_PROFILE_NEW_FIRST") == "1"
	if not check(not profile_new_first or profile_copy, "direct-New mode requires a verified closed profile-copy seed"):
		await finish(); return
	var budget: String = OS.get_environment("XJ_STARTUP_NAVIGATION_MAX_FRAME_MS")
	if budget.is_valid_float() and float(budget) > 0.0: max_frame_ms = float(budget)
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size; root.content_scale_factor = 1.0
	set_phase("cold_main_initialization")
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db"); root.add_child(host)
	if not await wait_until(func() -> bool: return host.services_ready, "normal Main title initialization"):
		await finish(); return
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): requests.append({"action": action, "target": target, "quantity": quantity, "extra": extra, "ticks_us": Time.get_ticks_usec()}))
	check(host.state == null and host.ui.page == "title" and host.is_processing() and host.is_physics_processing(), "normal title has no loaded state and production callbacks remain enabled")
	await frames(8); await capture("title-fresh")
	var continue_first: bool = profile_copy and not profile_new_first
	if not await load_from_button("continue" if continue_first else "new_world"):
		await finish(); return
	var world_id: String = host.state.world_id
	if continue_first: check(world_id == seed_world_id, "first real Continue resumes the original closed-copy world before any New action")
	if profile_new_first:
		check(world_id != seed_world_id, "direct New on the old archive creates a world distinct from the original resume pointer")
		verify_seed_world_retained("after_direct_new")
	if not await observe_running("continued_world_running" if continue_first else "new_world_running"):
		await finish(); return
	if not await return_to_title():
		await finish(); return
	if not await load_from_button("new_world" if continue_first else "continue"):
		await finish(); return
	check(host.state.world_id != world_id if continue_first else host.state.world_id == world_id, "New creates a distinct voyage" if continue_first else "real Continue resumes the same saved voyage")
	await observe_running("new_world_running" if continue_first else "continued_world_running")
	verify_seed_world_retained("after_complete_startup_sequence")
	observations.append({"event": "actual_startup_order", "profile_new_first": profile_new_first, "first_action": "continue" if continue_first else "new_world", "last_action": "new_world" if continue_first else "continue", "first_loaded_world_id": world_id, "final_world_id": host.state.world_id, "seed_world_id": seed_world_id})
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	for name: String in phase_stats:
		if name == "cold_main_initialization":
			# Before the first interactive title exists, measure startup wall time
			# separately from the response budget for a player's accepted action.
			check(float(phase_stats[name].get("elapsed_ms", INF)) < 15000.0, "initial interactive title appears within 15 seconds")
		else:
			check(float(phase_stats[name].maximum_frame_gap_ms) < max_frame_ms, "bounded main-thread frame gap in phase " + name)
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(6)
	RenderingServer.frame_post_draw.disconnect(_rendered)
	if profile_copy: check(FileAccess.get_sha256(directory.path_join("seed.db")) == seed_sha256, "closed seed bytes remain unchanged after all normal startup/save operations")
	var result: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "directory": directory, "native": DisplayServer.get_name() != "headless", "packed_runtime": not OS.has_feature("editor"), "profile_copy": profile_copy, "profile_new_first": profile_new_first, "seed_sha256": seed_sha256, "seed_resume_world_id": seed_world_id, "responsiveness_budget_ms": max_frame_ms, "phases": phase_stats, "observations": observations, "requests": requests, "screenshots": screenshots, "scope": "fresh independent database or scoped verified closed-copy seed; actual button order recorded (closed-copy defaults Continue then New; direct-New option creates New before any old-world Continue), pause-save-return; normal Main render/physics for five seconds and 120 frames per loaded phase; no personal database opened, no growth/render/simulation fixtures, no FPS certification"}
	var file: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t") + "\n"); file.close()
	print("STARTUP_NAVIGATION_V62_RESULT ", result.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
