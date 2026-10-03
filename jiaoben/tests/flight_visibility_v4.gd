extends SceneTree
## Save/restart the real client in FRONT, then recover visible flight without motion loss.
## All progress stays in a fresh jiaoben/tmp SQLite; native pointer checks are separate.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var native_checks: int = 0
var captures: int = 0
var database_path: String
var saved_pose: Transform3D
var saved_velocity: Vector3

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): print("FLIGHT_VISIBILITY_V4 FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "writer reaches a stable boundary")

func press_v(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_V
	event.keycode = KEY_V
	event.pressed = true
	event.echo = echo
	host._unhandled_input(event)

func same_motion() -> bool:
	var ship = host.state.ship()
	return host.world.flight.global_transform.is_equal_approx(saved_pose) and host.world.flight.velocity.is_equal_approx(saved_velocity) and Vector3(ship.pos_x, ship.pos_y, ship.pos_z).is_equal_approx(saved_pose.origin) and Quaternion(ship.quat_x, ship.quat_y, ship.quat_z, ship.quat_w).is_equal_approx(saved_pose.basis.get_rotation_quaternion()) and Vector3(ship.vel_x, ship.vel_y, ship.vel_z).is_equal_approx(saved_velocity)

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await process_frame
	await process_frame
	await create_timer(0.25).timeout

func start_host() -> void:
	host = Main.new()
	host.progress_database_path = database_path
	# Fixture authority: calls execute normally, but no unsolicited physics/autosave ticks.
	host.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(host)
	await process_frame
	check(host.services_ready, "real Main opens isolated SQLite and current presentation")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/logs/flight-visibility-v4-" + label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "native capture " + label)
	captures += 1

func _run() -> void:
	database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/flight-visibility-v4-%d.db" % Time.get_ticks_usec())
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	await start_host()
	if not host.services_ready: await finish(); return
	await host._command("new_world", "舰船可见性独立验收", 1, "")
	if not check(host.state != null, "fresh world created through actual Main"): await finish(); return
	host._command("undock", "", 1, "")
	await wait_writer()
	host.ui.show_page("")
	host._sync_presentation_stage()
	check(host.state.ship().status == T.ShipStatus.FLYING and host.world.visible and not host.hangar.visible and root.get_camera_3d() == host.camera.camera, "departure selects real visible flight stage and camera")
	saved_pose = Transform3D(Basis.from_euler(Vector3(0.23, -0.41, 0.11)), Vector3(5000, 3000, 5000))
	saved_velocity = Vector3(7, -4, -16)
	host.world.flight.global_transform = saved_pose
	host.world.flight.velocity = saved_velocity
	host.world.flight.write_back()
	press_v()
	host.camera.step(0.0)
	host.ui.update_camera_status()
	check(host.camera.mode == T.CameraMode.FRONT and host.state.player().camera_mode == T.CameraMode.FRONT and not host.world.flight.visual.visible, "real V enters persisted FRONT and deliberately hides exterior hull")
	check(host.ui.instrument_title.text.contains("舰首视角（舰体隐藏）") and host.ui.instrument_title.tooltip_text.contains("显示舰船"), "FRONT HUD identifies why the external ship is hidden and recovery action")
	check(same_motion(), "entering FRONT preserves full 3D ship pose and nonzero velocity")
	await host._command("save", "0", 1, "manual")
	await wait_writer()
	var front_rows: Array[Dictionary] = host.store._records("SELECT p.camera_mode FROM save_slot s JOIN player_state p ON p.snapshot_id=s.current_snapshot_id WHERE s.world_id=? AND s.slot_kind='manual' AND s.slot_index=0", [host.state.world_id])
	check(front_rows.size() == 1 and front_rows[0].camera_mode == "front", "actual sealed SQLite manual snapshot stores FRONT text enum")
	var world_id: String = host.state.world_id
	var old_epoch: int = host.state.epoch
	await release_host()
	await start_host()
	await host._command("continue", "", 1, "")
	if not check(host.state != null, "fresh Main continues the existing sealed world"): await finish(); return
	host.camera.step(0.0)
	host.ui.tick(1.0)
	check(host.state.world_id == world_id and host.state.epoch > old_epoch and host.camera.mode == T.CameraMode.FRONT and not host.world.flight.visual.visible, "real restart preserves FRONT preference with new session epoch")
	check(same_motion(), "SQLite reload preserves three-axis position, orientation and velocity")
	check(host.ui.show_ship_button.is_visible_in_tree() and not host.ui.show_ship_button.disabled and host.ui.show_ship_button.text == "显示舰船", "FRONT flight offers an immediately accessible show-ship button")
	await capture("saved-front")
	host.camera.zoom = 2.0
	host.camera.orbit = Vector2(0.71, -0.24)
	host.observing = true
	host.pointer_mode = true
	host.flight_look.add_motion(Vector2(32, -18), 0.002)
	host.world.flight.intent.thrust_x = 1.0
	host.ui.show_ship_button.pressed.emit()
	check(host.camera.mode == T.CameraMode.FOLLOW and host.state.player().camera_mode == T.CameraMode.FOLLOW and host.camera.zoom == 1.0 and host.camera.orbit == Vector2.ZERO, "actual button restores FOLLOW and resets camera distance/free look")
	check(not host.observing and not host.pointer_mode and host.flight_look.pending_angles.is_zero_approx() and host.world.flight.intent.thrust_x == 0.0, "recovery clears observation and pending steering intent")
	check(same_motion(), "show-ship resets camera and intent without changing current ship motion")
	check(host.world.flight.visual.is_visible_in_tree() and host.ui.instrument_title.text.contains("跟随视角"), "ship visibility and explanatory HUD change synchronously on button press")
	var body_point: Vector2 = host.camera.camera.unproject_position(host.world.flight.global_position)
	check(not host.camera.camera.is_position_behind(host.world.flight.global_position) and body_point.distance_to(root.get_visible_rect().size * 0.5) < 0.02, "recovered ship is in front of camera at viewport center immediately")
	var visible_meshes: int = 0
	for candidate: Node in host.world.flight.visual.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = candidate as MeshInstance3D
		if mesh.mesh != null and mesh.is_visible_in_tree():
			var center: Vector3 = mesh.global_transform * mesh.mesh.get_aabb().get_center()
			var depth: float = -(host.camera.camera.global_transform.affine_inverse() * center).z
			if depth > host.camera.camera.near and depth < host.camera.camera.far and not host.camera.camera.is_position_behind(center): visible_meshes += 1
	check(visible_meshes > 0, "current industrial GLB has live visible geometry between camera clipping planes")
	await capture("recovered-follow")
	press_v(true)
	check(host.camera.mode == T.CameraMode.FOLLOW, "held-key echo cannot cycle camera repeatedly")
	host.ui.show_page("pause")
	press_v()
	host.ui.show_ship_button.pressed.emit()
	check(host.camera.mode == T.CameraMode.FOLLOW and host.ui.keyboard_blocked(), "pause menu blocks V and even an emitted recovery signal")
	host.ui.show_page("")
	# Let the page's deferred focus policy finish before attaching a text-input fixture.
	for frame: int in range(3): await process_frame
	var edit := LineEdit.new()
	edit.position = Vector2(260, 200)
	edit.size = Vector2(160, 30)
	host.ui.root.add_child(edit)
	edit.grab_focus()
	check(root.gui_get_focus_owner() == edit, "text-input fixture owns focus after page transition settles")
	press_v()
	check(host.ui.keyboard_blocked() and host.camera.mode == T.CameraMode.FOLLOW, "focused text input blocks V camera shortcut")
	edit.release_focus()
	edit.queue_free()
	await process_frame
	host.ui.show_ship_button.pressed.emit()
	host.busy = true
	press_v()
	check(host.camera.mode == T.CameraMode.FOLLOW, "active writer barrier blocks V camera mutation")
	host.busy = false
	if DisplayServer.get_name() != "headless":
		host.pointer_mode = true
		host._sync_mouse_mode()
		await process_frame
		Input.warp_mouse(host.ui.show_ship_button.get_global_rect().get_center())
		await process_frame
		await process_frame
		check(host.ui.show_ship_button.get_global_rect().has_point(host.ui.root.get_global_mouse_position()) and host.ui.input_blocked() and not host.ui.keyboard_blocked(), "real OS cursor over flight navigation blocks steering but allows keyboard camera")
		press_v()
		host.camera.step(0.0)
		check(host.camera.mode == T.CameraMode.FRONT and not host.world.flight.visual.visible, "V enters FRONT while the OS pointer hovers flight HUD")
		press_v()
		host.camera.step(0.0)
		check(host.camera.mode == T.CameraMode.TACTICAL and host.world.flight.visual.visible, "V leaves FRONT while the OS pointer remains over flight HUD")
		host.ui.show_ship_button.pressed.emit()
		native_checks = 3
	for window_size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = window_size
			root.content_scale_size = Vector2i(Vector2(window_size) / scale)
			for frame: int in range(4): await process_frame
			host.ui.tick(1.0)
			for frame: int in range(4): await process_frame
			var viewport := Rect2(Vector2.ZERO, host.ui.root.size)
			var button_rect: Rect2 = host.ui.show_ship_button.get_global_rect()
			check(host.ui.show_ship_button.is_visible_in_tree() and viewport.encloses(button_rect) and button_rect.size.x > 55 and button_rect.size.y >= 25, "recovery button fits %s at %.0f%%" % [window_size, scale * 100])
			check(not button_rect.intersects(host.ui.navigation_hud.radar_frame.get_global_rect()) and not button_rect.intersects(host.ui.instrument.get_global_rect()) and not button_rect.intersects(host.ui.target_panel.get_global_rect()), "recovery button avoids flight HUD overlap %s at %.0f%%" % [window_size, scale * 100])
			var buttons: Array[Node] = host.ui.navigation.find_children("*", "Button", true, false)
			var valid: bool = buttons.size() == 4
			for other: Node in buttons:
				if other != host.ui.show_ship_button: valid = valid and not button_rect.intersects(other.get_global_rect())
			check(valid, "recovery action coexists with mission/map/system buttons %s at %.0f%%" % [window_size, scale * 100])
	check(same_motion(), "UI scaling and keyboard guards preserve original moving ship")
	await host._command("save", "0", 1, "manual")
	await wait_writer()
	var follow_rows: Array[Dictionary] = host.store._records("SELECT p.camera_mode FROM save_slot s JOIN player_state p ON p.snapshot_id=s.current_snapshot_id WHERE s.world_id=? AND s.slot_kind='manual' AND s.slot_index=0", [host.state.world_id])
	check(follow_rows.size() == 1 and follow_rows[0].camera_mode == "follow", "recovered FOLLOW preference is written through actual SQLite save")
	await release_host()
	await start_host()
	await host._command("continue", "", 1, "")
	if check(host.state != null, "reopen continues recovered snapshot"):
		host.camera.step(0.0)
		host.ui.tick(1.0)
		check(host.camera.mode == T.CameraMode.FOLLOW and host.world.flight.visual.is_visible_in_tree() and host.ui.instrument_title.text.contains("跟随视角"), "second actual restart restores FOLLOW with visible exterior hull")
		check(same_motion(), "second sealed reload retains original pose and velocity")
	await finish()

func finish() -> void:
	await release_host()
	print("FLIGHT_VISIBILITY_V4_RESULT %s checks=%d failures=%d native_checks=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), native_checks, captures])
	quit(0 if failures.is_empty() else 1)
