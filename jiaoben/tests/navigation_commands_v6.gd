extends Node
## Full Main commands + fresh SQLite. Explicit fixed ticks, no personal saves.
## Synthetic UI contacts are removed before any database capture.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
const XJSpaceCoordinates = preload("res://runtime/space_coordinates.gd")
const D = preload("res://contracts/contract_dtos.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var database_path: String
var station_id: String
var gate_id: String
var planet_id: String
var finishing: bool = false
var root: Window
var directory: String
var observations: Array[Dictionary] = []

func _ready() -> void:
	get_tree().set_meta("xj_navigation_commands_v6_diagnostic", true)
	root = get_tree().root
	# Real site transitions, physics frames and durable saves make this a full
	# integration run. Leave 30 seconds for shutdown before the runner's 600 s cap.
	get_tree().create_timer(570.0).timeout.connect(func(): print("NAVIGATION_COMMANDS_V6_RESULT FAIL watchdog"); get_tree().quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 2) -> void:
	for frame: int in range(count): await get_tree().process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	var stable_frames: int = 0
	while is_instance_valid(host) and stable_frames < 3 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		stable_frames = stable_frames + 1 if _writer_idle() else 0
	check(_writer_idle() and stable_frames == 3, "actual SQLite writer reaches stable boundary")

func _writer_idle() -> bool:
	return is_instance_valid(host) and not host.busy and host.loading_job == null and (host.ui == null or not host.ui.loading_suspended)

func start_host() -> void:
	host = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	# Keep child physics bodies registered in their World3D; only Main's normal
	# callbacks are suppressed. DISABLED inheritance removes collision spaces.
	host.set_physics_process(false)
	host.set_process(false)
	await frames()
	check(host.services_ready, "real Main opens isolated SQLite and validates presentation")

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames()
	await get_tree().create_timer(0.25).timeout

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var path: String = directory.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "native capture " + label)
	captures += 1

func first_kind(kind: String) -> String:
	for id: String in host.world.targets:
		if str(host.world.targets[id].kind) == kind: return id
	return ""

func pose() -> Transform3D:
	return host.world.flight.global_transform

func position() -> Vector3:
	return host.world.flight.global_position

func place_far() -> void:
	# Station distance comes from a real inter-site warp, never an out-of-bounds
	# local teleport. This declared picking/tactical pose stays inside the gate site.
	if not await ensure_target_site(gate_id): return
	var target: Node3D = host.world.targets[gate_id].node
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, target.global_position + Vector3(4000, 1000, 4000))
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.camera.step(1.0)
	host.ui.target_id = station_id
	host.ui.tick(1.0)
	var site: Dictionary = host.store.catalog.one("site_defs", "site_id", XJSpaceCoordinates.current_site(host.state))
	var pivot := Vector3(site.pivot_x_m, site.pivot_y_m, site.pivot_z_m)
	check(position().distance_to(pivot) < float(site.local_radius_m) and host.world.target_is_local(gate_id) and not host.world.target_is_local(station_id), "warp fixture uses actual transitioned site and legal local coordinates")

func ensure_target_site(id: String) -> bool:
	if host.world.target_is_local(id): return true
	if navigation().call("active"): await stop_navigation()
	await wait_writer()
	var before_site: String = XJSpaceCoordinates.current_site(host.state)
	var target_site: String = host.world.target_site(id)
	var before_pose: Transform3D = pose()
	await host._command("nav_warp", id, 1, "")
	if not check(navigation().call("warp_active") and navigation().get("target_id") == id and pose().is_equal_approx(before_pose), "real site transition starts from captured source without teleport " + id): return false
	var ticks: int = 0
	while navigation().call("active") and ticks < 1800:
		await step()
		ticks += 1
		if host.busy: await wait_writer()
	await frames(3)
	await wait_writer()
	if not host.deferred_save.is_empty(): await step(); await wait_writer()
	observations.append({"case":"actual_site_transition", "target":id, "origin_site":before_site, "destination_site":XJSpaceCoordinates.current_site(host.state), "ticks":ticks})
	return check(ticks < 1800 and navigation().get("phase") == "arrived" and XJSpaceCoordinates.current_site(host.state) == target_site and before_site != target_site and host.world.target_is_local(id) and host.deferred_save.is_empty() and _writer_idle(), "real site transition commits destination and stable arrival " + id)

func boundary_alignment_checks() -> void:
	var site: Dictionary = host.store.catalog.one("site_defs", "site_id", XJSpaceCoordinates.current_site(host.state))
	var pivot := Vector3(site.pivot_x_m, site.pivot_y_m, site.pivot_z_m)
	var local_offset := Vector3(80000, 40000, 120000)
	if not check(local_offset.length() < float(site.local_radius_m), "alignment fixture is inside the actual local flight boundary"): return
	host.world.flight.global_transform = Transform3D(Basis.from_euler(Vector3(0.42, -1.15, 0.25)), pivot + local_offset)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	var initial: Transform3D = pose()
	var heading: Vector3 = host.world.target_direction(station_id)
	var initial_error: float = (-initial.basis.z).angle_to(heading)
	check(initial_error > float(host.local_navigation.rules.value("alignment_tolerance_rad")) and absf(initial.basis.x.y) > 0.01, "boundary alignment starts with genuine non-default heading and roll")
	await host._command("nav_warp", station_id, 1, "")
	if not check(navigation().call("warp_active") and navigation().get("phase") == "warmup", "legal boundary pose starts actual remote-site warp"): return
	var ticks: int = 0
	var budget_valid: bool = true
	var finite_attitude: bool = true
	var max_arc: float = 0.0
	var max_budget: float = 0.0
	var position_retained: bool = true
	while navigation().get("phase") == "warmup" and ticks < 600:
		var before: Quaternion = host.world.flight.global_basis.get_rotation_quaternion()
		var budget: float = float(host.gameplay.call("metrics", host.state.ship()).turn_radps) / 60.0
		await step()
		var after: Quaternion = host.world.flight.global_basis.get_rotation_quaternion()
		var arc: float = before.angle_to(after)
		# angle_to's float32 dot/acos has measurement roundoff. This 0.001-rad
		# tolerance does not change the catalog turn rate or production budget.
		budget_valid = budget_valid and is_finite(arc) and arc <= budget + 0.001
		finite_attitude = finite_attitude and host.world.flight.global_basis.is_finite()
		position_retained = position_retained and position().is_equal_approx(initial.origin)
		max_arc = maxf(max_arc, arc); max_budget = maxf(max_budget, budget)
		ticks += 1
	var final_error: float = (-host.world.flight.global_basis.z).angle_to(heading)
	observations.append({"case":"legal_boundary_alignment", "site":XJSpaceCoordinates.current_site(host.state), "position":[initial.origin.x,initial.origin.y,initial.origin.z], "local_radius_m":float(site.local_radius_m), "offset_m":local_offset.length(), "initial_heading_error_rad":initial_error, "final_heading_error_rad":final_error, "maximum_tick_arc_rad":max_arc, "maximum_catalog_tick_budget_rad":max_budget, "angle_measurement_tolerance_rad":0.001, "ticks":ticks})
	check(budget_valid and finite_attitude and position_retained, "every actual warmup tick respects catalog angle budget and keeps a finite stationary pose")
	check(ticks < 600 and navigation().get("phase") == "travel" and final_error <= float(host.local_navigation.rules.value("alignment_tolerance_rad")) + 0.00001 and final_error < initial_error, "boundary alignment reaches real travel only after facing the accepted direction")
	await stop_navigation()

func press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	host._unhandled_input(event)

func click_button(button: Button, label: String) -> bool:
	await frames(3)
	if not check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "actual navigation button is reachable " + label): return false
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.global_position = point; event.pressed = pressed
		root.push_input(event, true)
		await frames(1)
	await wait_writer()
	return true

func snapshots() -> int:
	return int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)

func _run() -> void:
	directory = OS.get_environment("XJ_NAVIGATION_COMMANDS_V6_DIRECTORY").replace("\\", "/")
	var source_path: String = (get_script() as Script).resource_path.replace("\\", "/")
	var expected_root: String = source_path.get_base_dir().get_base_dir().path_join("tmp/navigation-commands-v6")
	var uuid := RegEx.new()
	uuid.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	database_path = directory.path_join("progress.db")
	if not check(source_path.is_absolute_path() and not source_path.contains("..") and source_path.ends_with("/jiaoben/tests/navigation_commands_v6.gd") and directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == expected_root and uuid.search(directory.get_file()) != null and not FileAccess.file_exists(database_path), "fresh UUID navigation database is test-owned"):
		get_tree().quit(2); return
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	await start_host()
	if not host.services_ready: await finish(); return
	await host._command("new_world", "本星系导航与紧凑态势独立验收", 1, "")
	if not check(host.state != null, "fresh world created through Main and actual SQLite"): await finish(); return
	await host._command("undock", "", 1, "")
	await wait_writer()
	host.ui.show_page("")
	host._sync_presentation_stage()
	station_id = first_kind("station")
	gate_id = first_kind("gate")
	planet_id = first_kind("planet")
	if not check(not station_id.is_empty() and not gate_id.is_empty() and not planet_id.is_empty(), "real current sector provides station, gate and scenic planet"): await finish(); return
	check(host.world.visible and not host.hangar.visible and root.get_camera_3d() == host.camera.camera, "fixture explicitly activates real flight scene and camera")
	if not check(host.has_method("navigation_context") and host.get("local_navigation") != null, "Main wires the production local navigation controller"): await finish(); return
	await place_far()
	await boundary_alignment_checks()
	await place_far()
	await eligibility_checks()
	await npc_sensor_checks()
	await physical_pick_checks()
	await tactical_fire_navigation_checks()
	await place_far()
	await source_failure_check()
	await charge_and_cancel_checks()
	await transit_stop_checks()
	await warp_and_restart_checks()
	if host.state == null: await finish(); return
	await approach_orbit_checks()
	if OS.get_environment("XJ_NAV_TEST_SCOPE") != "core": await ui_checks()
	else: print("SKIP overview/equipment UI assertions in explicit navigation-only scope")
	await dock_command_check()
	await finish()

func navigation() -> RefCounted:
	return host.get("local_navigation")

func context(id: String) -> Dictionary:
	return host.call("navigation_context", id)

func step(delta: float = 1.0 / 60.0) -> void:
	# CharacterBody3D uses the engine's real physics-frame delta internally.
	# Resume inside physics_frame so move_and_slide matches this explicit tick.
	await get_tree().physics_frame
	host._physics_process(delta)
	host.ui.tick(delta)
	host.camera.step(delta)

func stop_navigation() -> void:
	await host._command("nav_stop", "", 1, "")
	await wait_writer()

func eligibility_checks() -> void:
	check(not context("").get("ready", true) and not str(context("").get("reason", "")).is_empty(), "empty selection has an explicit refusal and no implicit destination")
	var planet: Dictionary = context(planet_id)
	check(not planet.get("warp_ready", true) and not planet.get("approach_ready", true) and not planet.get("orbit_ready", true), "scenic celestial remains bearing-only for every navigation mode")
	var foreign_station: String = ""
	for row: Dictionary in host.store.catalog.rows("station_defs"):
		if str(row.sector_id) != host.state.current_sector(): foreign_station = str(row.station_id); break
	check(not foreign_station.is_empty() and not context(foreign_station).get("ready", true), "a station in another sector cannot masquerade as local navigation")
	var station: Dictionary = context(station_id)
	check(float(station.get("distance_m", 0.0)) > float(host.store.catalog.rule("target_marker_detection_range_m")) and station.get("warp_ready", false), "catalog-known current-sector station stays warp-selectable beyond local sensor range got distance=" + str(station.get("distance_m")) + " ready=" + str(station.get("warp_ready")) + " reason='" + str(station.get("warp_reason")) + "' site='" + str(XJSpaceCoordinates.site_for_entity(host.state, "station", station_id)) + "' current='" + str(XJSpaceCoordinates.current_site(host.state)) + "'")
	host.gameplay.combat_remaining_s = float(host.store.catalog.rule("combat_exit_delay_s"))
	check(not context(station_id).get("warp_ready", true) and not str(context(station_id).get("warp_reason", context(station_id).get("reason", ""))).is_empty(), "combat blocks local warp with an actionable refusal")
	check(context(gate_id).get("approach_ready", false) and context(gate_id).get("orbit_ready", false), "combat retains tactical approach and orbit controls")
	host.gameplay.combat_remaining_s = 0.0
	host.world.projectiles.fire(host.state.ship().ship_instance_id, host.world.flight.get_rid(), position(), Vector3.FORWARD, 100.0, 1000.0, Vector3.ZERO)
	check(not context(station_id).get("warp_ready", true), "an actual in-flight projectile blocks warp source capture")
	host.world.projectiles.clear()
	var paid: D.EquipmentStateDto = null
	for equipment: D.EquipmentStateDto in host.gameplay.call("equipped", host.state.ship()):
		if not equipment.module_def_id.begins_with("module_engine_"): paid = equipment; break
	if check(paid != null, "fresh actual ship has a non-engine equipment cycle fixture"):
		paid.active_remaining_s = 2.0
		paid.cycle_paid = true
		check(not context(station_id).get("warp_ready", true), "paid non-engine device cycle blocks warp without silently discarding work")
		paid.active_remaining_s = 0.0
		paid.cycle_paid = false
	check(context(station_id).get("warp_ready", false) and not navigation().call("active"), "clearing real blockers restores ready state without starting navigation got ready=" + str(context(station_id).get("warp_ready")) + " reason='" + str(context(station_id).get("warp_reason")) + "' site='" + str(host.state.find("spatial_state", "entity_id", station_id)) + "'")

func source_failure_check() -> void:
	var original: Transform3D = pose()
	var count: int = snapshots()
	var epoch: int = host.state.epoch
	host.state.epoch += 1
	await host._command("nav_warp", station_id, 1, "")
	host.state.epoch = epoch
	await wait_writer()
	check(not navigation().call("active") and pose().is_equal_approx(original) and host.world.flight.velocity.is_zero_approx(), "real SQLite CAS source-save refusal cannot move or arm warp")
	check(snapshots() == count, "failed warp source capture publishes no new snapshot or slot")
	check(host.store.last_error.contains("STALE"), "source refusal comes from durable session CAS validation got '" + host.store.last_error + "'")

func npc_sensor_checks() -> void:
	# Read-only navigation/overview fixture, removed before any new snapshot.
	# This uses a frozen SQLite archetype; it is not a natural campaign unlock.
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	var definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", str(spawn.npc_id))
	var npc := D.NpcStateDto.new()
	npc.npc_instance_id = "navigation-readonly-npc-fixture"
	npc.spawn_id = str(spawn.spawn_id)
	npc.sector_id = host.state.current_sector()
	npc.alive = true
	npc.shield = float(definition.shield_max)
	npc.armor = float(definition.armor_max)
	npc.hull = float(definition.hull_max)
	npc.behavior_phase = T.NpcPhase.PATROL
	var point: Vector3 = position() + Vector3(100, 120, -550)
	npc.pos_x = point.x; npc.pos_y = point.y; npc.pos_z = point.z
	# A real spawn is always assigned to a site; world.sync_entities filters by
	# site, so a synthetic row without one is projected nowhere.
	XJSpaceCoordinates.assign(host.state, "npc", npc.npc_instance_id, XJSpaceCoordinates.current_site(host.state))
	if not check(host.state.add("npc_state", npc) and host.world.sync_entities(), "temporary NPC uses actual catalog archetype and production state-to-body projection"): return
	if host.world.npcs.has(npc.npc_instance_id): host.world.npcs[npc.npc_instance_id].global_position = point
	var id: String = npc.npc_instance_id
	check(not context(id).warp_ready and context(id).approach_ready and context(id).orbit_ready, "visible live hostile permits tactical navigation while forbidding warp to a moving NPC")
	point = position() + Vector3(float(host.store.catalog.rule("target_marker_detection_range_m")) + 1.0, 0, 0)
	npc.pos_x = point.x; npc.pos_y = point.y; npc.pos_z = point.z
	host.world.npcs[id].global_position = point
	host.ui.target_id = id
	host.ui._refresh_targets()
	check(not context(id).ready and not host.ui.target_buttons.has(id) and host.ui.target_id.is_empty(), "NPC beyond the real sensor cap disappears from overview and cannot stay a tactical destination")
	host.state.remove("npc_state", npc)
	XJSpaceCoordinates.remove(host.state, "npc", id)
	host.world.npcs[id].queue_free()
	host.world.npcs.erase(id)
	host.world.targets.erase(id)
	host.ui.target_id = station_id
	await frames()
	check(host.state.find("npc_state", "npc_instance_id", id) == null and not host.world.targets.has(id), "read-only synthetic NPC is fully removed before any SQLite capture")

func spawn_readonly_npc(point: Vector3, id: String) -> D.NpcStateDto:
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	var definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", str(spawn.npc_id))
	var npc := D.NpcStateDto.new()
	npc.npc_instance_id = id
	npc.spawn_id = str(spawn.spawn_id)
	npc.sector_id = host.state.current_sector()
	npc.alive = true
	npc.shield = float(definition.shield_max)
	npc.armor = float(definition.armor_max)
	npc.hull = float(definition.hull_max)
	npc.behavior_phase = T.NpcPhase.PATROL
	npc.pos_x = point.x; npc.pos_y = point.y; npc.pos_z = point.z
	XJSpaceCoordinates.assign(host.state, "npc", id, XJSpaceCoordinates.current_site(host.state))
	if not host.state.add("npc_state", npc) or not host.world.sync_entities(): return null
	# Place the body explicitly, the same way place_far() does for the ship: the
	# stored position and the world's own transform are not the same frame.
	if host.world.npcs.has(id): host.world.npcs[id].global_position = point
	return npc

func remove_readonly_npc(npc: D.NpcStateDto) -> void:
	if npc == null: return
	var id: String = npc.npc_instance_id
	host.world.projectiles.clear()
	host.pending_damage.clear()
	host.auto_fire_target = ""
	host.state.remove("npc_state", npc)
	XJSpaceCoordinates.remove(host.state, "npc", id)
	if host.world.npcs.has(id): host.world.npcs[id].queue_free(); host.world.npcs.erase(id)
	host.world.targets.erase(id)
	if host.ui.target_id == id: host.ui.target_id = ""
	await frames()

func physical_target_point(id: String, distance_m: float = 1600.0) -> Vector2:
	# Only a committed local site has live physics colliders. Reach it through the
	# actual controller before applying the declared local camera/picking pose.
	if not await ensure_target_site(id): return Vector2(-1, -1)
	var node: Node3D = host.world.targets[id].node
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, node.global_position + Vector3(0, 0, distance_m))
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	# The v0.8 rig samples an interpolated render pose. Settle the real physics
	# and render pump after teleporting this explicit picking fixture, then
	# project with the same current camera used by Main's physical ray.
	await get_tree().physics_frame
	await frames(4)
	host.camera.snapped = false
	host.camera.step(0.0)
	# A wormhole's middle is an intentional hole. Aim at an actual frame shape,
	# never at a fake ray result or an invisible proxy target.
	var colliders: Array[Node] = node.find_children("*", "CollisionShape3D", true, false)
	var aim: Vector3 = colliders[0].global_position if not colliders.is_empty() else node.global_position
	host.camera.camera.look_at(aim, Vector3.UP)
	await get_tree().physics_frame
	return host.camera.camera.unproject_position(aim)

func physical_pick_checks() -> void:
	if not check(host.has_method("_world_target_at"), "Main exposes actual physics-space target picking"): return
	var station_point: Vector2 = await physical_target_point(station_id)
	check(host.call("_world_target_at", station_point) == station_id, "real station collision and main camera projection resolve exact world target")
	var gate_point: Vector2 = await physical_target_point(gate_id)
	check(host.call("_world_target_at", gate_point) == gate_id, "real wormhole frame collider can be picked without filling its opening")
	var gate: Node3D = host.world.targets[gate_id].node
	var opening: Vector2 = host.camera.camera.unproject_position(gate.global_position)
	check(host.world.target_is_local(gate_id) and host.call("_world_target_at", opening) != gate_id, "actual local wormhole opening remains free of a fabricated solid pick collider")
	await place_far()
	var npc: D.NpcStateDto = spawn_readonly_npc(position() + Vector3(200, 160, -1500), "navigation-ray-npc-fixture")
	if check(npc != null, "ray-pick NPC uses real archetype, runtime row and production body"):
		var id: String = npc.npc_instance_id
		var npc_point: Vector2 = await physical_target_point(id, 1600.0)
		check(host.call("_world_target_at", npc_point) == id, "physical ray picks actual live hostile inside the sensor cap")
		npc_point = await physical_target_point(id, float(host.store.catalog.rule("target_marker_detection_range_m")) + 1.0)
		check(host.call("_world_target_at", npc_point).is_empty(), "physical ray refuses a rendered hostile just outside the actual 6km sensor cap")
		await remove_readonly_npc(npc)
	station_point = await physical_target_point(station_id)
	host.ui.target_id = ""
	host._sync_mouse_mode()
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		var focus_deadline: int = Time.get_ticks_msec() + 1500
		while not root.has_focus() and Time.get_ticks_msec() < focus_deadline: await get_tree().process_frame
		host.get_viewport().warp_mouse(station_point)
		await frames(4)
		await RenderingServer.frame_post_draw
	check(host.pointer_mode and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not InputMap.has_action("pointer") and host._keyboard_control_allowed() and not host.ui.ui_input_blocked(), "scene selection uses the permanently visible pointer and actual world-input guards without an Alt mode")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = station_point
	click.pressed = true
	host.fire_held = false
	host._unhandled_input(click)
	click.pressed = false
	host._input(click)
	check(host.pointer_pick_pending and not host.pointer_drag_pressed and not host.pointer_dragged and not host.observing and host.ui.target_id.is_empty() and not host.fire_held, "scene left-button short press and release queue only physical selection without a weapon hold")
	await step()
	check(not host.pointer_pick_pending and host.ui.target_id == station_id and not host.fire_held and host.world.projectiles.active.is_empty(), "actual next Main physics boundary selects the station without firing")
	# Move the real HUD over its current cursor; headless cannot warp an OS
	# cursor, but Control hit testing still uses the same production predicate.
	var hud: Control = host.ui.target_panel
	var old_position: Vector2 = hud.position
	hud.position = host.ui.root.get_global_mouse_position() - Vector2(4, 4)
	host.ui.target_id = ""
	host.pointer_pick_pending = false
	click.pressed = true
	host._unhandled_input(click)
	click.pressed = false
	host._input(click)
	check(host.ui.ui_input_blocked() and not host.pointer_drag_pressed and not host.pointer_pick_pending and host.ui.target_id.is_empty() and not host.fire_held, "actual HUD hit-test blocks both gesture start and short-click world selection without firing")
	hud.position = old_position
	host.pointer_pick_pending = false
	host._sync_mouse_mode()
	host.flight_look.clear()
	host.ui.target_id = station_id
	host.ui.tick(1.0)
	await frames()
	check(host.state.rows("npc_state").all(func(row: RefCounted): return row.npc_instance_id != "navigation-ray-npc-fixture") and host.world.projectiles.active.is_empty(), "ray-pick fixture leaves no transient hostile or projectile for later saves")

func tactical_fire_navigation_checks() -> void:
	await place_far()
	var weapon_range: float = 0.0
	for equipment: D.EquipmentStateDto in host.gameplay.call("equipped", host.state.ship()):
		var definition: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment.module_def_id)
		if str(definition.get("slot_type", "")) == "weapon" and equipment.enabled:
			weapon_range = maxf(weapon_range, float(definition.range_m))
	if not check(weapon_range > 0.0, "fresh guaranteed ship has an actual enabled catalog weapon for explicit auto-fire"): return
	var npc: D.NpcStateDto = spawn_readonly_npc(position() + Vector3(250, 180, -(weapon_range + 600.0)), "navigation-fire-npc-fixture")
	if not check(npc != null, "tactical auto-fire fixture projects an actual catalog hostile"): return
	var id: String = npc.npc_instance_id
	var count: int = snapshots()
	await host._command("combat_toggle", id, 1, "")
	check(host.auto_fire_target == id and host.navigation_context(id).combat_active, "explicit Main combat action starts auto-fire only for a qualified live enemy got target=" + host.auto_fire_target + " expected=" + id + " combat=" + str(host.navigation_context(id).combat_active) + " npcs=" + str(host.world.npcs.keys()))
	await host._command("nav_approach", id, 1, "")
	check(navigation().call("active") and navigation().get("mode") == "approach" and host.auto_fire_target == id, "starting tactical approach retains explicitly armed auto-fire identity")
	await step()
	check(host.auto_fire_target == id and navigation().get("mode") == "approach", "actual approach physics tick retains the requested auto-fire target")
	await host._command("nav_orbit", id, 1, "")
	check(navigation().call("active") and navigation().get("mode") == "orbit" and host.auto_fire_target == id, "switching to tactical orbit does not disarm explicit auto-fire got active=" + str(navigation().call("active")) + " mode=" + str(navigation().get("mode")) + " phase=" + str(navigation().get("phase")) + " fire=" + host.auto_fire_target + " orbit_ready=" + str(host.navigation_context(id).get("orbit_ready")) + " reason='" + str(host.navigation_context(id).get("orbit_reason")) + "' npc_dist=" + str(host.world.flight.global_position.distance_to((host.world.targets[id].node as Node3D).global_position)) + " sensor=" + str(host.gameplay.ship_roles.detection_range()) + " spawn_dist=" + str(host.auto_fire_target) + "'")
	await step()
	check(host.auto_fire_target == id and navigation().get("mode") == "orbit", "actual orbit physics tick retains explicit auto-fire target got fire=" + host.auto_fire_target + " mode=" + str(navigation().get("mode")) + " phase=" + str(navigation().get("phase")))
	await host._command("combat_toggle", id, 1, "")
	check(host.auto_fire_target.is_empty() and navigation().call("active"), "explicit stop-fire action disarms fire while keeping tactical navigation got fire=" + host.auto_fire_target + " active=" + str(navigation().call("active")) + " mode=" + str(navigation().get("mode")))
	await remove_readonly_npc(npc)
	await host._command("nav_stop", "", 1, "")
	host.gameplay.combat_remaining_s = 0.0
	check(snapshots() == count and host.world.projectiles.active.is_empty() and host.pending_damage.is_empty() and host.state.find("npc_state", "npc_instance_id", id) == null, "tactical fixture is removed and projectiles cleared before any following SQLite snapshot")

func charge_and_cancel_checks() -> void:
	await place_far()
	await wait_writer()
	var original: Transform3D = pose()
	var retained_before: int = snapshots()
	var sequence_before: int = host.state.capture_sequence
	var snapshot_before: String = host.state.snapshot.meta.snapshot_id
	var world_before: String = host.state.world_id
	var session_id_before: String = host.state.session_id
	var epoch_before: int = host.state.epoch
	var session_before: Array[Dictionary] = host.store._records("SELECT last_committed_sequence FROM runtime_session WHERE world_id=? AND session_id=? AND epoch=?", [world_before, session_id_before, epoch_before])
	if not check(session_before.size() == 1 and int(session_before[0].last_committed_sequence) == sequence_before, "current warmup source begins at the actual committed session sequence"): return
	await host._command("nav_warp", station_id, 1, "")
	await wait_writer()
	check(navigation().call("warp_active") and str(navigation().get("phase")) == "warmup", "Main starts warp only after durable source capture and enters visible warmup got active=" + str(navigation().call("warp_active")) + " phase=" + str(navigation().get("phase")) + " store='" + host.store.last_error + "'")
	# Ordinary saves prune unreferenced old snapshots after commit. Net retained
	# row count is not the number of writes once the keep-recent window is full.
	# Pin this command's session/epoch and require exactly one new sealed commit.
	var sealed: Array[Dictionary] = host.store._records("SELECT snapshot_id,capture_sequence,reason FROM save_snapshot WHERE world_id=? AND writer_session_id=? AND writer_epoch=? AND capture_sequence>? AND status='sealed'", [world_before, session_id_before, epoch_before, sequence_before])
	var session_after: Array[Dictionary] = host.store._records("SELECT last_committed_sequence,resume_snapshot_id FROM runtime_session WHERE world_id=? AND session_id=? AND epoch=?", [world_before, session_id_before, epoch_before])
	var sequence_after: int = host.state.capture_sequence
	var snapshot_after: String = host.state.snapshot.meta.snapshot_id
	observations.append({"case":"warmup_source_commit", "retained_before":retained_before, "retained_after":snapshots(), "sequence_before":sequence_before, "sequence_after":sequence_after, "snapshot_before":snapshot_before, "snapshot_after":snapshot_after, "new_sealed_snapshots":sealed.size(), "durable_session":session_after})
	check(host.state.world_id == world_before and host.state.session_id == session_id_before and host.state.epoch == epoch_before and sequence_after == sequence_before + 1 and sealed.size() == 1 and int(sealed[0].capture_sequence) == sequence_before + 1 and str(sealed[0].reason) == "auto" and str(sealed[0].snapshot_id) == snapshot_after and snapshot_after != snapshot_before and session_after.size() == 1 and int(session_after[0].last_committed_sequence) == sequence_before + 1 and str(session_after[0].resume_snapshot_id) == snapshot_after and pose().is_equal_approx(original), "warmup has exactly one committed source snapshot and no teleport")
	var tick: int = host.state.snapshot.meta.simulation_tick
	host.ui.show_page("pause")
	for i: int in range(90): await step()
	check(host.state.snapshot.meta.simulation_tick == tick and str(navigation().get("phase")) == "warmup" and pose().is_equal_approx(original), "pause freezes navigation charge and all movement at the production Main boundary")
	host.ui.show_page("")
	await stop_navigation()
	check(not navigation().call("active") and pose().is_equal_approx(original), "explicit stop cancels warmup without moving the ship")
	await host._command("nav_warp", station_id, 1, "")
	await wait_writer()
	Input.action_press("forward")
	await step()
	Input.action_release("forward")
	check(not navigation().call("active"), "manual thrust input takes control and cancels local navigation")
	await wait_writer()
	await place_far()
	await host._command("nav_warp", station_id, 1, "")
	await wait_writer()
	Input.action_press("brake")
	await step()
	Input.action_release("brake")
	check(not navigation().call("active") and host.world.flight.velocity.is_zero_approx(), "X brake cancels charge and leaves no autonomous velocity")
	await wait_writer()
	await place_far()
	await host._command("nav_warp", station_id, 1, "")
	await wait_writer()
	host._sync_mouse_mode()
	var pointer_origin: Vector2 = Vector2(root.size) * 0.5
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		host.get_viewport().warp_mouse(pointer_origin)
		await frames(4)
		await RenderingServer.frame_post_draw
	var orbit_before: Vector2 = host.camera.orbit
	var velocity_before: Vector3 = host.world.flight.velocity
	var camera_before: Basis = host.camera.camera.global_basis
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.position = pointer_origin
	right.pressed = true
	host._input(right)
	var motion := InputEventMouseMotion.new()
	motion.position = pointer_origin + Vector2(28, -12)
	motion.relative = Vector2(28, -12)
	motion.screen_relative = motion.relative
	host._input(motion)
	right.pressed = false
	host._input(right)
	var right_inactive: bool = not host.observing and host.camera.orbit.is_equal_approx(orbit_before)
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.position = pointer_origin
	left.pressed = true
	host._unhandled_input(left)
	host._input(motion)
	host.camera.step(1.0)
	var actual_drag: bool = host.observing and host.camera.observing and not host.camera.orbit.is_equal_approx(orbit_before) and not host.camera.camera.global_basis.is_equal_approx(camera_before)
	var held_angle: Vector2 = host.camera.orbit
	left.position = motion.position
	left.pressed = false
	host._input(left)
	check(right_inactive and actual_drag and not host.observing and not host.camera.observing and host.camera.orbit.is_equal_approx(held_angle) and navigation().call("warp_active") and pose().is_equal_approx(original) and host.world.flight.velocity.is_equal_approx(velocity_before) and not host.pointer_pick_pending and not host.fire_held and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "right button stays disabled while actual left drag rotates only the camera, retains its angle on release and preserves warp without firing")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and root.has_focus() and not host.ui.ui_input_blocked(), "native DisplayServer retains actual window focus and visible unobstructed pointer during observation")
		host._input(motion)
		host._read_flight_input(0.0)
		check(navigation().call("warp_active") and host.camera.orbit.is_equal_approx(held_angle) and host.flight_look.pending_angles.is_zero_approx() and pose().is_equal_approx(original) and not host.fire_held, "ordinary visible-pointer movement after drag cannot steer, fire or cancel autonomous navigation")
	else:
		print("SKIP actual native window focus and OS pointer state under headless DisplayServer")
	await stop_navigation()
	host.flight_look.clear()
	await wait_writer()

func _pose_evidence(value: Transform3D) -> Dictionary:
	var attitude: Quaternion = value.basis.get_rotation_quaternion()
	return {"origin":[value.origin.x,value.origin.y,value.origin.z], "quaternion":[attitude.x,attitude.y,attitude.z,attitude.w]}

func _ship_pose_evidence() -> Dictionary:
	var ship: D.ShipStateDto = host.state.ship()
	return {"position":[ship.pos_x,ship.pos_y,ship.pos_z], "quaternion":[ship.quat_x,ship.quat_y,ship.quat_z,ship.quat_w], "velocity":[ship.vel_x,ship.vel_y,ship.vel_z]}

func transit_stop_checks() -> void:
	await place_far()
	var departure_site: String = XJSpaceCoordinates.current_site(host.state)
	var destination_site: String = host.world.target_site(station_id)
	var departure_pose: Transform3D = pose()
	var departure_encoded: Vector3 = XJSpaceCoordinates.encoded(host.state.ship())
	var departure_dto: Dictionary = _ship_pose_evidence()
	var departure_collision_site: String = host.world.collision_site_id
	await host._command("nav_warp", station_id, 1, "")
	await wait_writer()
	var strategic_ticks: int = 0
	while navigation().call("active") and navigation().get("phase") == "warmup" and strategic_ticks < 600:
		await step(); strategic_ticks += 1
	if not check(strategic_ticks < 600 and navigation().get("phase") == "travel", "actual cross-site warmup reaches strategic travel"): return
	# Warmup owns attitude and legitimately turns the ship. Preserve the source
	# position separately, then freeze the aligned attitude for transit/cancel.
	var aligned_departure: Transform3D = pose()
	var aligned_dto: Dictionary = _ship_pose_evidence()
	var heading_error: float = (-aligned_departure.basis.z).angle_to(host.local_navigation.warp_heading)
	check(aligned_departure.origin.is_equal_approx(departure_pose.origin) and XJSpaceCoordinates.encoded(host.state.ship()).is_equal_approx(departure_encoded) and heading_error <= host.local_navigation.rules.value("alignment_tolerance_rad") + 0.00001, "cross-site warmup aligns attitude without moving the encoded source position")
	var macro_before: Dictionary = host.world.strategic_components(position())
	var elapsed_before: float = host.local_navigation.travel_elapsed_s
	await step()
	var macro_after: Dictionary = host.world.strategic_components(position())
	var scalar_delta: float = XJSpaceCoordinates.scalar_distance(macro_before, macro_after)
	check(is_finite(scalar_delta), "cross-site scalar progress is finite")
	var transit_pose: Transform3D = pose()
	var transit_checks: Dictionary = {"scalar_progress":scalar_delta > 1.0, "time_progress":host.local_navigation.travel_elapsed_s > elapsed_before, "local_origin_retained":transit_pose.origin.is_equal_approx(departure_pose.origin), "dto_origin_retained":XJSpaceCoordinates.encoded(host.state.ship()).is_equal_approx(departure_encoded), "aligned_attitude_retained":transit_pose.basis.is_equal_approx(aligned_departure.basis), "origin_site_retained":XJSpaceCoordinates.current_site(host.state) == departure_site, "destination_collision_site":host.world.collision_site_id == destination_site, "projection_active":host.world.departure_active and is_instance_valid(host.world.departure_projection) and not host.world.strategic_render_position.is_empty(), "velocity_zero":host.world.flight.velocity.is_zero_approx()}
	var transit_record: Dictionary = {"case":"cross_site_transit", "before":_pose_evidence(departure_pose), "aligned":_pose_evidence(aligned_departure), "after":_pose_evidence(transit_pose), "dto_before":departure_dto, "dto_aligned":aligned_dto, "dto_after":_ship_pose_evidence(), "origin_site":departure_site, "destination_site":destination_site, "site_after":XJSpaceCoordinates.current_site(host.state), "collision_site_before":departure_collision_site, "collision_site_after":host.world.collision_site_id, "macro_before":macro_before, "macro_after":macro_after, "scalar_delta_m":scalar_delta, "elapsed_before_s":elapsed_before, "elapsed_after_s":host.local_navigation.travel_elapsed_s, "duration_s":host.local_navigation.travel_duration_s, "heading_error_rad":heading_error, "checks":transit_checks}
	observations.append(transit_record)
	print("NAV_CROSS_SITE_DIAGNOSTIC ", JSON.stringify(transit_record))
	check(transit_checks.values().all(func(flag: Variant): return bool(flag)), "cross-site transit advances real scalar route while preserving encoded departure pose")
	await stop_navigation()
	var cancelled_pose: Transform3D = pose()
	var cancel_checks: Dictionary = {"local_origin_retained":cancelled_pose.origin.is_equal_approx(departure_pose.origin), "dto_origin_retained":XJSpaceCoordinates.encoded(host.state.ship()).is_equal_approx(departure_encoded), "aligned_attitude_retained":cancelled_pose.basis.is_equal_approx(aligned_departure.basis), "origin_site_restored":XJSpaceCoordinates.current_site(host.state) == departure_site, "collision_site_restored":host.world.collision_site_id == departure_site, "macro_projection_cleared":host.world.strategic_render_position.is_empty(), "projection_removed":not host.world.departure_active and not is_instance_valid(host.world.departure_projection), "velocity_zero":host.world.flight.velocity.is_zero_approx(), "controller_stopped":not host.local_navigation.active()}
	var cancel_record: Dictionary = {"case":"cross_site_cancel", "before":_pose_evidence(departure_pose), "aligned":_pose_evidence(aligned_departure), "cancelled":_pose_evidence(cancelled_pose), "dto_cancelled":_ship_pose_evidence(), "origin_site":departure_site, "site_cancelled":XJSpaceCoordinates.current_site(host.state), "collision_site_cancelled":host.world.collision_site_id, "macro_cancelled":host.world.strategic_components(position()), "phase":host.local_navigation.phase, "checks":cancel_checks}
	observations.append(cancel_record)
	print("NAV_CROSS_SITE_DIAGNOSTIC ", JSON.stringify(cancel_record))
	check(cancel_checks.values().all(func(flag: Variant): return bool(flag)), "cross-site cancel restores durable departure site and removes transit projection")
	# Preserve the separate same-site clear-space stop contract. Authored teaching
	# markers are offset from the station pivot, so a source inside the 150 km
	# local volume can still exceed the unchanged 150 km minimum landing path.
	if not await ensure_target_site(station_id): return
	var local_target: String = ""
	for id: String in host.world.targets:
		if str(host.world.targets[id].kind) == "marker" and host.world.target_is_local(id): local_target = id; break
	if not check(not local_target.is_empty(), "same-site warp uses an actual authored offset flight marker"): return
	var site: Dictionary = host.store.catalog.one("site_defs", "site_id", XJSpaceCoordinates.current_site(host.state))
	var pivot := Vector3(site.pivot_x_m, site.pivot_y_m, site.pivot_z_m)
	var marker: Node3D = host.world.targets[local_target].node
	var radius: float = float(site.local_radius_m) - host.local_navigation.rules.value("arrival_tolerance_m") * 2.0
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, pivot - pivot.direction_to(marker.global_position) * radius)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	check(position().distance_to(pivot) < float(site.local_radius_m) and bool(context(local_target).warp_ready), "same-site source is legal and exceeds the actual minimum warp landing distance")
	var origin: Vector3 = position()
	await host._command("nav_warp", local_target, 1, "")
	await wait_writer()
	var ticks: int = 0
	while navigation().call("active") and navigation().get("phase") == "warmup" and ticks < 600:
		await step(); ticks += 1
	if not check(ticks < 600 and navigation().get("phase") == "travel", "warmup plus rate-limited 3D alignment reach actual travel phase"): return
	await step()
	var safe_midpoint: Vector3 = position()
	check(navigation().call("warp_active") and safe_midpoint.distance_to(origin) > 1.0, "warp moves continuously before its arrival and supports a real in-transit stop")
	await stop_navigation()
	check(position().is_equal_approx(safe_midpoint) and host.world.flight.velocity.is_zero_approx(), "ordinary clear-space transit cancel stops at the current point rather than snapping to origin")
	host.world.flight.global_position = origin
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	await host._command("nav_warp", local_target, 1, "")
	await wait_writer()
	var safe_origin: Vector3 = position()
	host.world.flight.global_position = host.world.targets[station_id].node.global_position
	host.world.flight.write_back()
	await stop_navigation()
	check(position().is_equal_approx(safe_origin) and host.world.flight.velocity.is_zero_approx(), "station-overlap cancellation recovers the last validated safe flight point")

func warp_and_restart_checks() -> void:
	await place_far()
	var sector: String = host.state.current_sector()
	await host._command("nav_warp", station_id, 1, "")
	await wait_writer()
	host._request_save("auto", 2)
	check(not host.deferred_save.is_empty() and not host.busy, "autosave waits while a local navigation controller owns motion")
	host.ui.target_id = gate_id
	var ticks: int = 0
	while navigation().call("active") and ticks < 1800:
		await step()
		ticks += 1
		if host.busy: await wait_writer()
		if ticks % 120 == 0: await frames()
	await frames(3)
	await wait_writer()
	if not host.deferred_save.is_empty(): await step(); await wait_writer()
	check(ticks < 1800 and not navigation().call("active"), "bounded actual Main fixed ticks complete charge and local warp")
	var station: Node3D = host.world.targets[station_id].node
	var gate: Node3D = host.world.targets[gate_id].node
	check(position().distance_to(station.global_position) < position().distance_to(gate.global_position) and navigation().get("target_id") == station_id and host.world.target_is_local(station_id), "rapid UI reselection does not retarget a previously accepted navigation command")
	check(host.state.current_sector() == sector and host.state.ship().status == T.ShipStatus.FLYING and host.world.flight.velocity.is_zero_approx(), "local warp arrives stationary in the same sector without automatic station entry")
	check(host.interaction_context(station_id).ready, "warp arrival meets the actual station interaction range and speed contract")
	check(host.deferred_save.is_empty() and not host.busy, "arrival reaches the real SQLite autosave boundary and drains pending request")
	var arrival_pose: Transform3D = pose()
	var world_id: String = host.state.world_id
	var old_epoch: int = host.state.epoch
	await capture("warp-arrived")
	await release_host()
	await start_host()
	await host._command("continue", "", 1, "")
	await wait_writer()
	if not check(host.state != null, "new Main actually reopens the sealed arrival snapshot"): return
	host.ui.show_page("")
	host._sync_presentation_stage()
	check(host.state.world_id == world_id and host.state.epoch > old_epoch and host.state.current_sector() == sector, "SQLite restart restores the same world and sector under a fresh session epoch")
	check(pose().is_equal_approx(arrival_pose) and host.world.flight.velocity.is_zero_approx() and host.state.ship().status == T.ShipStatus.FLYING and not navigation().call("active"), "real restart restores durable arrival pose and idle autonomous controller")
	host.ui.target_id = station_id
	await host._command("interact_target", station_id, 1, "")
	await wait_writer()
	host._sync_presentation_stage()
	check(host.state.ship().status == T.ShipStatus.DOCKED and host.hangar.visible and not host.world.visible, "the actual post-warp station interaction enters the station scene")
	await host._command("undock", "", 1, "")
	await wait_writer()
	host.ui.show_page("")
	host._sync_presentation_stage()

func approach_orbit_checks() -> void:
	var center: Vector3 = host.world.targets[station_id].node.global_position
	host.world.flight.global_position = center + Vector3(1400, 1700, 1600)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	var before: Vector3 = position()
	await host._command("nav_approach", station_id, 1, "")
	await wait_writer()
	check(navigation().call("active") and str(navigation().get("mode")) == "approach" and position().is_equal_approx(before), "approach starts continuous flight without any instantaneous relocation")
	var max_speed: float = float(host.gameplay.call("metrics", host.state.ship()).speed_mps)
	var valid_speed: bool = true
	for i: int in range(180):
		await step()
		valid_speed = valid_speed and host.world.flight.velocity.length() <= max_speed + 0.01
	check(position().distance_to(center) < before.distance_to(center) and absf(position().y - before.y) > 0.05, "approach actually closes distance along the vertical as well as horizontal axes")
	check(valid_speed and position().distance_to(before) <= max_speed * 3.0 + 1.0, "approach obeys real ship metrics and cannot teleport between fixed ticks")
	await stop_navigation()
	check(not navigation().call("active") and host.world.flight.velocity.is_zero_approx(), "approach stop releases controller and fully stops flight")
	host.world.flight.global_position = center + Vector3(1100, 1300, 900)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	before = position()
	await host._command("nav_orbit", station_id, 1, "")
	await wait_writer()
	check(navigation().call("active") and str(navigation().get("mode")) == "orbit" and position().is_equal_approx(before), "orbit starts without a jump and owns the production flight controller")
	valid_speed = true
	for i: int in range(360):
		await step()
		valid_speed = valid_speed and host.world.flight.velocity.length() <= max_speed + 0.01
	var displacement: Vector3 = position() - before
	check(displacement.length() > 0.5 and absf(displacement.y) > 0.05 and valid_speed, "orbit produces bounded three-axis motion rather than a flat UI-only effect")
	await capture("orbit")
	await stop_navigation()
	var stopped: Vector3 = position()
	for i: int in range(30): await step()
	check(not navigation().call("active") and host.world.flight.velocity.is_zero_approx() and position().is_equal_approx(stopped), "orbit stop remains stopped on later actual Main ticks")
	check(host.store.save(host.state, "manual", 1), "stopped navigation still commits a validated relational snapshot")

func ui_checks() -> void:
	var overview: Control = host.ui.get("overview")
	var equipment: Control = host.ui.get("equipment_bar")
	if not check(is_instance_valid(overview) and is_instance_valid(equipment), "Main binds current overview and actual equipment cycle bar"): return
	await place_far()
	await frames(3)
	host.ui.tick(1.0)
	check(host.ui.target_buttons.has(station_id) and host.ui.target_buttons.has(gate_id), "catalog-known station and gate remain in real overview beyond sensor range")
	check(host.ui.target_panel == overview and host.ui.target_list == overview.get("target_list"), "existing UI input guards alias the new overview controls")
	var original_rows: Array[Dictionary] = overview.get("entry_rows").duplicate(true)
	# Only a UI sorting/filtering fixture: these contacts are neither spawned in
	# the sector nor written to the authoritative SQLite runtime state.
	var rows: Array[Dictionary] = [
		{"id": "ui_sort_station", "title": "Zulu 空间站", "kind": "station", "type_title": "站点", "distance_m": 24000.0, "navigation_only": false, "known": true},
		{"id": "ui_sort_enemy", "title": "Bravo 敌舰", "kind": "npc", "type_title": "敌舰", "distance_m": 900.0, "navigation_only": false, "known": false},
		{"id": "ui_sort_gate", "title": "Alpha 虫洞传送门", "kind": "gate", "type_title": "虫洞", "distance_m": 1800.0, "navigation_only": false, "known": true},
		{"id": "ui_sort_planet", "title": "Omega 远景行星", "kind": "planet", "type_title": "天体", "distance_m": INF, "navigation_only": true, "known": true},
	]
	overview.call("set_entries", rows, "")
	var filters: Dictionary = overview.get("filter_buttons")
	var sorts: Dictionary = overview.get("sort_buttons")
	filters.combat.pressed.emit()
	check(overview.get("filter_mode") == "combat" and overview.get("filtered_ids") == ["ui_sort_enemy"], "real combat filter shows only combat contact fixture")
	filters.navigation.pressed.emit()
	check(overview.get("filter_mode") == "navigation" and not overview.get("filtered_ids").has("ui_sort_enemy") and overview.get("filtered_ids").size() == 3, "real navigation filter removes combat contacts while retaining known destinations and bearings")
	filters.all.pressed.emit()
	sorts.name.pressed.emit()
	check(overview.get("sort_key") == "name" and overview.get("sort_ascending") and overview.get("filtered_ids") == ["ui_sort_gate", "ui_sort_enemy", "ui_sort_planet", "ui_sort_station"], "name header sorts ascending through real UI signal")
	sorts.name.pressed.emit()
	check(not overview.get("sort_ascending") and overview.get("filtered_ids") == ["ui_sort_station", "ui_sort_planet", "ui_sort_enemy", "ui_sort_gate"], "same header reverses ordering without changing contacts")
	sorts.distance.pressed.emit()
	check(overview.get("sort_ascending") and overview.get("filtered_ids") == ["ui_sort_enemy", "ui_sort_gate", "ui_sort_station", "ui_sort_planet"], "distance sorting keeps compressed scenic bearing after finite physical distances")
	sorts.type.pressed.emit()
	check(overview.get("sort_key") == "type" and overview.get("filtered_ids").size() == rows.size(), "type header preserves one row per contact")
	overview.call("set_entries", original_rows, station_id)
	filters.all.pressed.emit()
	sorts.distance.pressed.emit()
	host.ui._refresh_targets()
	host.ui.target_id = station_id
	host.ui.tick(1.0)
	var actions: Dictionary = overview.get("action_buttons")
	check(actions.nav_warp.is_visible_in_tree() and not actions.nav_warp.disabled and actions.nav_dock.is_visible_in_tree(), "selected known station offers qualified warp and explicit dock operations")
	check(overview.get("selected_title").text == str(host.world.targets[station_id].title), "selected operation card displays the exact selected station name")
	if not await click_button(actions.nav_warp, "selected-card warp"): return
	host.ui.tick(1.0)
	check(navigation().call("warp_active") and navigation().get("target_id") == station_id, "selected-card warp invokes real Main source capture for its own target")
	check(actions.nav_stop.is_visible_in_tree() and not actions.nav_stop.disabled, "active navigation card exposes a live stop action")
	if not await click_button(actions.nav_stop, "selected-card stop without expansion"): return
	host.ui.tick(1.0)
	check(not navigation().call("active") and host.world.flight.velocity.is_zero_approx(), "selected-card stop reaches actual flight owner and stops motion")
	var actual: Array = host.gameplay.call("equipped", host.state.ship())
	var records: Array[Dictionary] = equipment.get("module_records")
	check(records.size() == actual.size() and not records.is_empty(), "equipment bar enumerates actual active ship slots without invented modules")
	var record_valid: bool = true
	for record: Dictionary in records:
		var row: D.EquipmentStateDto = host.state.find("equipment_state", "item_instance_id", str(record.id))
		var slot: D.ContainerStateDto = host.state.find("container_state", "container_id", row.slot_container_id) if row != null else null
		record_valid = record_valid and row != null and slot != null and slot.ship_instance_id == host.state.ship().ship_instance_id and record.module_id == row.module_def_id and bool(record.enabled) == row.enabled and is_equal_approx(float(record.cooldown_remaining_s), row.cooldown_remaining_s)
	check(record_valid, "each equipment card is grounded in current SQLite-derived item, slot, enable and cooldown state")
	var module: D.EquipmentStateDto = actual[0] if not actual.is_empty() else null
	if module != null:
		var id: String = module.item_instance_id
		var buttons: Dictionary = equipment.get("module_buttons")
		var enabled: bool = module.enabled
		buttons[id].pressed.emit()
		await frames()
		host.ui.tick(1.0)
		check(module.enabled != enabled and buttons[id].button_pressed == module.enabled, "actual equipment button changes authoritative enabled flag and displays the result")
		buttons[id].pressed.emit()
		await frames()
		host.ui.tick(1.0)
		check(module.enabled == enabled and buttons[id].button_pressed == enabled, "second equipment action restores actual module state")
		var definition: Dictionary = host.store.catalog.one("module_defs", "module_id", module.module_def_id)
		if check(host.gameplay.call("pay_cycle", module), "real gameplay pays a fitted device cycle with its database-defined cost"):
			host.ui.tick(1.0)
			var progress: Dictionary = equipment.get("module_progress")
			var labels: Dictionary = equipment.get("module_labels")
			check(progress[id].visible and is_equal_approx(progress[id].value, module.cooldown_remaining_s) and is_equal_approx(progress[id].max_value, float(definition.cycle_s)), "device cycle ring shows real remaining seconds and database duration")
			check(not str(labels[id].status.text).is_empty() and str(labels[id].status.text) != "就绪", "paid active device displays cycle status rather than a decorative ready icon")
			var remaining: float = module.cooldown_remaining_s
			for i: int in range(30): await step()
			host.ui.tick(1.0)
			check(module.cooldown_remaining_s < remaining and absf(progress[id].value - module.cooldown_remaining_s) <= 0.011, "actual fixed ticks advance device cycle and presentation together within display precision")
			var deadline: int = 0
			while module.active_remaining_s > 0.0 and deadline < 900:
				await step(); deadline += 1
			check(deadline < 900 and module.active_remaining_s == 0.0, "paid device finishes naturally before later save/navigation tests")
	host.ui.target_id = station_id
	for window_size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = window_size
			root.content_scale_size = Vector2i(Vector2(window_size) / scale)
			await frames(4)
			host.ui.tick(1.0)
			await frames(3)
			var viewport := Rect2(Vector2.ZERO, host.ui.root.size)
			check(overview.is_visible_in_tree() and equipment.is_visible_in_tree() and viewport.encloses(overview.get_global_rect()) and viewport.encloses(equipment.get_global_rect()), "overview and equipment panel fit %s at %.0f%%" % [window_size, scale * 100])
			check(not overview.get_global_rect().intersects(equipment.get_global_rect()) and not equipment.get_global_rect().intersects(host.ui.instrument.get_global_rect()) and not equipment.get_global_rect().intersects(host.ui.navigation_hud.radar_frame.get_global_rect()), "equipment/overview avoid radar and flight readout %s at %.0f%%" % [window_size, scale * 100])
			check(not overview.get_global_rect().intersects(host.ui.instrument.get_global_rect()) and viewport.encloses(host.ui.navigation.get_global_rect()), "selected actions and flight navigation keep independent bounds %s at %.0f%%" % [window_size, scale * 100])
			check(overview.get("filter_buttons").all.is_visible_in_tree() and overview.get("sort_buttons").distance.is_visible_in_tree() and overview.get("action_buttons").nav_warp.is_visible_in_tree() and not overview.get("action_buttons").nav_warp.disabled and bool(context(station_id).warp_ready), "overview filters, sorting and selected operations remain present %s at %.0f%% got filters=%s sorting=%s actions=%s selected='%s' warp_ready=%s reason='%s'" % [window_size, scale * 100, str(overview.get("filter_buttons").all.is_visible_in_tree()), str(overview.get("sort_buttons").distance.is_visible_in_tree()), str(overview.get("action_buttons").nav_warp.is_visible_in_tree()), str(host.ui.target_id), str(host.navigation_context(station_id).get("warp_ready")), str(host.navigation_context(station_id).get("warp_reason"))])
			if host.ui.root.size.x < 950.0:
				var long_rows: Array[Dictionary] = overview.get("entry_rows").duplicate(true)
				for row: Dictionary in long_rows:
					if row.id == station_id: row.title = "锚港主站第三工业环装配与能源补给综合泊位"
				overview.call("set_entries", long_rows, station_id)
				await frames(3)
				var button: Button = overview.get("target_buttons")[station_id]
				var name_label: Label = button.get_child(0).get_node("Name")
				check(name_label.autowrap_mode != TextServer.AUTOWRAP_OFF and name_label.max_lines_visible == 2 and name_label.get_line_count() >= 2 and button.size.y >= 32.0, "compact overview keeps long Chinese name in a bounded two-line row %s at %.0f%%" % [window_size, scale * 100])
				overview.call("set_entries", original_rows, station_id)
				host.ui.tick(1.0)
			await capture("layout-%dx%d-%d" % [window_size.x, window_size.y, int(scale * 100)])
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	await frames(3)
	host.ui.tick(1.0)
	check(host.ui.navigation_hud != null and host.ui.navigation_hud.selected_id == station_id, "overview selection continues to drive one existing radar/target annotation")
	if not await ensure_target_site(station_id): return
	host.ui.target_id = station_id
	host.ui.tick(1.0)
	check(not bool(context(station_id).warp_ready) and actions.nav_approach.is_visible_in_tree() and actions.nav_orbit.is_visible_in_tree(), "arrived station exposes qualified local actions instead of pretending near-range warp is ready")
	if not await click_button(overview.get("more_actions"), "expand unavailable station operations"): return
	host.ui.tick(1.0)
	check(actions.nav_warp.is_visible_in_tree() and actions.nav_warp.disabled and not str(context(station_id).warp_reason).is_empty() and not actions.nav_warp.tooltip_text.is_empty(), "more operations retains the near-range warp action with its actual refusal")
	host.ui.show_page("pause")
	host.ui.tick(1.0)
	check(not overview.is_visible_in_tree() and not equipment.is_visible_in_tree(), "pause hides flight overview and equipment controls together")
	host.ui.show_page("")
	host.ui.tick(1.0)

func dock_command_check() -> void:
	var center: Vector3 = host.world.targets[station_id].node.global_position
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, center + Vector3(900, 800, 1600))
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	await host._command("nav_dock", station_id, 1, "")
	await wait_writer()
	var ticks: int = 0
	while navigation().call("active") and ticks < 1800:
		await step()
		ticks += 1
		if host.busy: await wait_writer()
		if ticks % 120 == 0: await frames()
	await frames(3)
	await wait_writer()
	host._sync_presentation_stage()
	print("NAV_DOCK_FIXTURE ticks=%d phase=%s status=%s distance=%.4f speed=%.4f" % [ticks, str(navigation().get("phase")), str(host.state.ship().status), position().distance_to(center), host.world.flight.velocity.length()])
	check(ticks < 1800 and host.state.ship().status == T.ShipStatus.DOCKED and host.hangar.visible, "explicit station dock command completes local transit then actual dock eligibility")

func finish() -> void:
	if finishing: return
	finishing = true
	await release_host()
	var summary: Dictionary = {"result":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures.size(), "failure_labels":failures, "captures":captures, "directory":directory, "packed_runtime":OS.has_feature("standalone"), "observations":observations, "fixture_scope":"fresh SQLite; actual inter-site warps; explicit legal local picking/tactical poses; transient catalog NPCs and UI-only sorting rows removed before saves; no personal data"}
	var report := FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if report != null: report.store_string(JSON.stringify(summary)); report.close()
	else: get_tree().quit(2); return
	print("NAVIGATION_COMMANDS_V6_FINAL_JSON ", JSON.stringify(summary))
	print("NAVIGATION_COMMANDS_V6_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	get_tree().quit(0 if failures.is_empty() else 1)
