extends Node
## Real Main, production services and independently saved SQLite. Relocations
## and earlier tutorial objective events are explicit isolated preconditions;
## they do not claim natural travel or a complete human campaign playthrough.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Store = preload("res://runtime/data/store.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Rng = preload("res://runtime/rng.gd")
var root: Window:
	get: return get_tree().root
var process_frame: Signal:
	get: return get_tree().process_frame
var physics_frame: Signal:
	get: return get_tree().physics_frame
var host: Main
var directory: String
var database_path: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var requested_events: Array[Dictionary] = []
var salvage_ids: Array[String] = []
var opened_ids: Array[String] = []
var pending_package: Dictionary = {}
var pending_rng: Dictionary = {}
var refresh_group_id: String = ""
var old_member_ids: Array[String] = []

class FaultStore extends Store:
	var fault: String = ""
	func _checkpoint(point: String) -> bool:
		return point != fault

func _ready() -> void:
	_initialize()

func create_timer(wait: float) -> SceneTreeTimer:
	return get_tree().create_timer(wait)

func quit(code: int = 0) -> void:
	get_tree().quit(code)

func _initialize() -> void:
	create_timer(390.0).timeout.connect(func(): check(false, "watchdog"); finish())
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func finish() -> void:
	var passed: bool = failures.is_empty()
	print("ENCOUNTER_MISSION_V12_FINAL_JSON " + JSON.stringify({"result": "PASS" if passed else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory}))
	print("ENCOUNTER_MISSION_V12_RESULT ", "PASS" if passed else "FAIL", " checks=", checks, " failures=", failures.size(), " captures=", captures)
	quit(0 if passed else 1)

func frames(count: int = 3) -> void:
	for frame: int in range(count): await process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 6000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "real SQLite writer settles")

func start_host() -> bool:
	host = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	host.set_process(false); host.set_physics_process(false)
	await frames()
	if not check(host.services_ready, "Main opens formal catalog, presentation and isolated SQLite"): return false
	# The subclass executes every production Store operation unchanged, except
	# when a named transaction checkpoint is explicitly selected below.
	host.store.close()
	host.store = FaultStore.new(database_path)
	host.store.status_changed.connect(host._store_status)
	if not check(host.store.open(), "real Store subclass opens the isolated checkpoint-test database"): return false
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): requested_events.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))
	return true

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(4)
	await create_timer(0.25).timeout

func show_page(page: String) -> void:
	host.ui.show_page(page)
	await frames(4)
	host.ui.tick(0.3)
	await frames(2)

func buttons_below(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button: result.append(child)
		result.append_array(buttons_below(child))
	return result

func action_button(action: String, target: String = "") -> Button:
	for button: Button in buttons_below(host.ui.body):
		if str(button.get_meta("action", "")) == action and (target.is_empty() or str(button.get_meta("target", "")) == target): return button
	for button: Button in buttons_below(host.ui.root):
		if button.is_visible_in_tree() and str(button.get_meta("action", "")) == action and (target.is_empty() or str(button.get_meta("target", "")) == target): return button
	return null

func scroll_ancestors(control: Control) -> Array[ScrollContainer]:
	var result: Array[ScrollContainer] = []
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer: result.append(node)
		node = node.get_parent()
	return result

func reveal(control: Control) -> void:
	for scroll: ScrollContainer in scroll_ancestors(control): scroll.ensure_control_visible(control)
	await frames(4)

func visible_control(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree() or not Rect2(Vector2.ZERO, host.ui.root.size).encloses(control.get_global_rect()): return false
	for scroll: ScrollContainer in scroll_ancestors(control):
		if not scroll.get_global_rect().encloses(control.get_global_rect()): return false
	return true

func actual_click(button: Button, label: String) -> bool:
	if not check(button != null and not button.disabled, "legal GUI action exists " + label): return false
	await reveal(button)
	var count: Dictionary = {"value": 0}
	var observer: Callable = func(): count["value"] = int(count["value"]) + 1
	button.pressed.connect(observer)
	var ready: bool = false
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 2000
	var previous: Rect2 = button.get_global_rect()
	while Time.get_ticks_msec() < deadline:
		if DisplayServer.get_name() != "headless" and not root.has_focus(): root.grab_focus()
		var center: Vector2 = button.get_global_rect().get_center()
		host.get_viewport().warp_mouse(center)
		var motion := InputEventMouseMotion.new()
		motion.position = center; motion.global_position = center
		host.get_viewport().push_input(motion, true)
		await process_frame
		var hover: Control = host.get_viewport().gui_get_hovered_control()
		var hovered: bool = hover != null and (hover == button or button.is_ancestor_of(hover))
		if DisplayServer.get_name() != "headless": hovered = hovered and root.has_focus() and button.get_global_rect().has_point(button.get_global_mouse_position())
		stable = stable + 1 if previous.is_equal_approx(button.get_global_rect()) and hovered and visible_control(button) else 0
		previous = button.get_global_rect()
		if stable >= 2: ready = true; break
	if not check(ready, "actual pointer reaches " + label):
		print("ENCOUNTER_MISSION_V12_GUI_TIMEOUT ", label, " rect=", button.get_global_rect(), " hover=", host.get_viewport().gui_get_hovered_control())
		button.pressed.disconnect(observer)
		return false
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		event.position = button.get_global_rect().get_center(); event.global_position = event.position
		host.get_viewport().push_input(event, true)
	await frames(4); await wait_writer()
	if is_instance_valid(button) and button.pressed.is_connected(observer): button.pressed.disconnect(observer)
	return check(int(count.value) == 1, "one real GUI click activates exactly once " + label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if check(not image.is_empty() and image.save_png(directory.path_join(label + ".png")) == OK, "native capture " + label): captures += 1

func production_action(action: String, target: String = "", quantity: int = 1, extra: String = "", expected: bool = true) -> bool:
	var result: D.ActionResultDto = host.gameplay.call("act", action, target, quantity, extra)
	var applied: bool = result.phase == T.ActionPhase.APPLIED
	check(applied == expected, "production " + action + " " + target + (" applies" if expected else " rejects") + ": " + result.display_reason_key)
	return applied

func command(action: String, target: String = "", quantity: int = 1, extra: String = "") -> void:
	host._command(action, target, quantity, extra)
	await frames(3); await wait_writer()

func place(point: Vector3) -> void:
	# Explicit positioning witness; collision and production eligibility still run.
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, point)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.camera.step(0.0)

func relocate(sector_id: String) -> bool:
	var ship: D.ShipStateDto = host.state.ship()
	ship.sector_id = sector_id; ship.status = T.ShipStatus.FLYING
	ship.has_station_id = false; ship.station_id = ""
	ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	host.state.player().has_docked_station_id = false; host.state.player().docked_station_id = ""
	for container: D.ContainerStateDto in host.state.rows("container_state"):
		if container.ship_instance_id == ship.ship_instance_id: container.sector_id = sector_id
	var visited := host.state.find("sector_state", "sector_id", sector_id) as D.SectorStateDto
	visited.visited = true
	if not check(host._stage_candidate(host.state, host.store.catalog), "Main prepares explicit fixture sector " + sector_id): return false
	host._activate(host.state)
	host.ui.show_page(""); host._sync_presentation_stage(); host._sync_mouse_mode()
	await frames()
	return true

func dock_at(station_id: String) -> bool:
	var station: Dictionary = host.store.catalog.one("station_defs", "station_id", station_id)
	if host.state.current_sector() != str(station.sector_id):
		if not await relocate(str(station.sector_id)): return false
	place(host.world.anchor_position(str(station.station_anchor_id)))
	await command("dock", station_id)
	return check(host.state.player().has_docked_station_id and host.state.player().docked_station_id == station_id, "real docking service accepts fixture placement " + station_id)

func sync_ui() -> void:
	check(host.world.sync_entities(), "real authority-to-scene projection synchronizes")
	host.camera.step(0.0)
	# Main's ordinary process is deliberately frozen in this fixture. Advance
	# actual UI elapsed time past its 0.25s telemetry interval after relocating;
	# zero-time redraw would leave the previous overview contacts unchanged.
	host.ui.tick(0.3)
	await frames(3)

func overview_diagnostic(label: String, ids: Array[String]) -> void:
	var contacts: Array[Dictionary] = []
	for id: String in ids:
		var entry: Dictionary = host.world.targets.get(id, {})
		var node: Node3D = entry.get("node") as Node3D
		var row := host.state.find("npc_state", "npc_instance_id", id) as D.NpcStateDto
		var group_id: String = str(entry.get("group_target_id", ""))
		var group: Dictionary = host.world.targets.get(group_id, {})
		var group_node: Node3D = group.get("node") as Node3D
		var distance: float = host.world.flight.global_position.distance_to(node.global_position) if is_instance_valid(node) else -1.0
		contacts.append({"id": id, "kind": str(entry.get("kind", "")), "node_position": str(node.global_position) if is_instance_valid(node) else "missing", "row_position": str(Vector3(row.pos_x, row.pos_y, row.pos_z)) if row != null else "none", "distance_m": distance, "group_id": group_id, "group_distance_m": host.world.flight.global_position.distance_to(group_node.global_position) if is_instance_valid(group_node) else -1.0, "production_visible": host.ui._npc_visible(entry, distance) if str(entry.get("kind", "")) == "npc" and is_instance_valid(node) else false})
	print("ENCOUNTER_MISSION_V12_OVERVIEW_DIAGNOSTIC " + JSON.stringify({"label": label, "filter": host.ui.overview.filter_mode, "filtered_ids": host.ui.overview.filtered_ids, "ship_position": str(host.world.flight.global_position), "hud_refresh": host.ui.hud_refresh, "contacts": contacts}))

func _run() -> void:
	var native: bool = DisplayServer.get_name() != "headless"
	directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/encounter-mission-v12/" + ("native" if native else "headless"))
	var output_override: String = OS.get_environment("XJ_ENCOUNTER_V12_OUTPUT").strip_edges()
	if not output_override.is_empty():
		# An exported .app reads production assets from its PCK, but test artifacts
		# remain beside this external test script under the workspace's jiaoben/tmp.
		var temporary: String = ProjectSettings.globalize_path(get_script().resource_path).get_base_dir().get_base_dir().path_join("tmp").simplify_path()
		if not check(output_override.is_absolute_path() and output_override.simplify_path().begins_with(temporary + "/"), "output override is an absolute test-owned jiaoben/tmp directory"):
			finish(); return
		directory = output_override.simplify_path()
	if not check(DirAccess.make_dir_recursive_absolute(directory) == OK, "test output directory is writable"):
		finish(); return
	database_path = directory.path_join("progress.db")
	DirAccess.remove_absolute(database_path)
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	if not await start_host(): await release_host(); finish(); return
	var fresh: XJRuntimeState = host.store.new_world("任务敌群与打捞测试", 42, host._prepare_loaded)
	if not check(fresh != null, "fresh production world freezes and seals definitions: " + host.store.last_error): await release_host(); finish(); return
	host._activate(fresh)
	await frames()
	if native:
		root.grab_focus()
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
		check(root.has_focus(), "native window has real OS focus")
	await campaign_entry_checks()
	await tutorial_preconditions()
	await combat_mission_checks()
	await story_route_checks()
	await encounter_checks()
	await salvage_checks()
	await persistence_checks()
	await rare_reward_checks()
	await legacy_checks()
	await release_host()
	finish()

func business_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: Array[Node] = [host.ui.body]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if bool(node.get_meta("business_list", false)):
			for row: Dictionary in node.get("rows"): result.append(row)
		for child: Node in node.get_children(): pending.append(child)
	return result

func campaign_entry_checks() -> void:
	await show_page("missions")
	var kinds: Dictionary = {}
	for button: Button in buttons_below(host.ui.body):
		if button.has_meta("mission_filter"): kinds[str(button.get_meta("mission_filter"))] = button
	check(kinds.has("tutorial") and kinds.has("story") and kinds.has("contract") and kinds.story.text.contains("主线"), "mission tabs explicitly distinguish tutorial, main story and contracts")
	if kinds.has("story"): await actual_click(kinds.story, "main story tab")
	var missions: RefCounted = host.gameplay.get("missions")
	var chain: Array = missions.call("chain", "story")
	check(chain.size() == 8 and str(chain[0].mission_id) == "story_mirror" and str(chain[-1].mission_id) == "story_silent", "real eight-chapter story chain is ordered from Mirror to Silent")
	var visible: Array[Dictionary] = host.ui._filtered_mission_definitions()
	check(visible.size() == chain.size() and visible.any(func(row: Dictionary): return str(row.accept_station_id) != host.state.player().docked_station_id), "story tab includes remote chapters rather than only local station offers")
	for row: Dictionary in business_rows():
		check(row.name.text.contains("主线剧情") and row.description.text.contains("接取"), "each story row labels its chapter and remote acceptance station")
	check(str(missions.call("missing_prerequisite", "story_mirror")) == "tutorial_flight", "locked first chapter resolves the earliest incomplete tutorial")
	await capture("story-locked")
	await show_page("research")
	var research: Dictionary = host.store.catalog.one("research_defs", "research_id", "research_tech_ii")
	var prerequisite: Button = action_button("show_mission", str(research.verification_mission_id))
	if await actual_click(prerequisite, "research mainline prerequisite"):
		check(host.ui.page == "missions" and host.ui.mission_filter == "story" and host.ui.mission_focus_id == str(research.verification_mission_id), "research action opens the precise story chapter with focus")
		check(business_rows().any(func(row: Dictionary): return str(row.id) == str(research.verification_mission_id) and bool(row.row.get_meta("mission_focused", false))), "research prerequisite remains visible despite former task pagination")
	await capture("research-story-prerequisite")

func tutorial_preconditions() -> void:
	# Earlier objective records deliberately establish eligibility. All offers,
	# paid scans, finite mining, bound goods, claims and loan cleanup are real.
	await command("accept_mission", "tutorial_flight")
	await command("undock")
	host.gameplay.call("record_event", "reach_anchor", "anchor_anchor_flight_forward", 1)
	host.gameplay.call("record_event", "brake_at_anchor", "anchor_anchor_flight_forward", 1)
	host.gameplay.call("record_event", "reach_anchor", "anchor_anchor_flight_turn", 1)
	await dock_at("station_anchor_port")
	await command("deliver_mission", "tutorial_flight")
	check(bool(host.gameplay.get("missions").call("completed", "tutorial_flight")), "actual tutorial flight claim establishes scanner eligibility")
	await command("accept_mission", "tutorial_scan_gate")
	await command("undock")
	var scan: Dictionary = host.store.catalog.one("signal_defs", "signal_id", "signal_anchor_gate_calibration")
	place(host.world.anchor_position(str(scan.anchor_id)))
	production_action("start_scan", "signal_anchor_gate_calibration")
	host.gameplay.call("tick", 11.0)
	check(host.state.find("discovery_state", "signal_id", "signal_anchor_gate_calibration") != null, "real paid scanner completes the prerequisite discovery")
	await dock_at("station_anchor_port")
	await command("deliver_mission", "tutorial_scan_gate")
	await command("accept_mission", "tutorial_mining_delivery")
	await command("claim_loan", "loan_tutorial_miner")
	await command("undock")
	host.gameplay.call("record_event", "transit_connection", "conn_anchor_echo", 1)
	if not await relocate("sector_echo"): return
	var mine: Dictionary = host.store.catalog.one("resource_node_locations", "node_id", "node_echo_ferrosilicate")
	place(host.world.anchor_position(str(mine.anchor_id)) + Vector3.UP * 100.0)
	production_action("start_mining", "node_echo_ferrosilicate")
	host.gameplay.call("tick", 32.0)
	host.gameplay.call("stop_interactions")
	await dock_at("station_anchor_port")
	await command("deliver_mission", "tutorial_mining_delivery")
	check(bool(host.gameplay.get("missions").call("completed", "tutorial_mining_delivery")), "real finite mining and atomic delivery establish combat mission prerequisites")

func combat_mission_checks() -> void:
	await command("accept_mission", "tutorial_combat")
	var missions: RefCounted = host.gameplay.get("missions")
	var abandoned: D.MissionStateDto = missions.call("active")
	var previous_scout := host.state.find("npc_state", "spawn_id", "spawn_anchor_tutorial_scout") as D.NpcStateDto
	if check(previous_scout != null and previous_scout.alive and previous_scout.mission_instance_id == abandoned.mission_instance_id, "first accepted combat attempt owns its live scout"):
		var old_scout_id: String = previous_scout.npc_instance_id
		await command("abandon_mission", "tutorial_combat")
		host.gameplay.call("tick", 0.0)
		await sync_ui()
		check(host.state.find("npc_state", "npc_instance_id", old_scout_id) == null and not host.world.targets.has(old_scout_id) and not host.world.targets.has("encounter:spawn_anchor_tutorial_scout"), "abandonment removes prior live scout authority, model and mission beacon")
		await command("accept_mission", "tutorial_combat")
		await sync_ui()
		var retry: D.MissionStateDto = missions.call("active")
		var retry_scout := host.state.find("npc_state", "spawn_id", "spawn_anchor_tutorial_scout") as D.NpcStateDto
		check(retry != null and retry.mission_instance_id != abandoned.mission_instance_id and retry_scout != null and retry_scout.alive and retry_scout.npc_instance_id != old_scout_id and retry_scout.mission_instance_id == retry.mission_instance_id and not host.world.targets.has(old_scout_id), "reaccepted combat attempt creates a fresh scout bound to the new mission identity")
	var info: Dictionary = missions.call("guidance")
	check(str(info.get("required_page", "")) == "ships", "combat mission first guides the required loan rather than an unavailable enemy")
	host.ui.show_mission("tutorial_combat")
	await frames(4)
	host.ui.tick(0.3)
	if await actual_click(action_button("mission_locate", "tutorial_combat"), "combat mission loan locator"):
		check(host.ui.page == "ships", "docked loan locator opens usable fleet service")
	await command("claim_loan", "loan_tutorial_kestrel")
	var npc := host.state.find("npc_state", "spawn_id", "spawn_anchor_tutorial_scout") as D.NpcStateDto
	if not check(npc != null and npc.alive, "accept and loan produce a real mission-scoped scout"): return
	info = missions.call("guidance")
	var waypoint_id: String = "encounter:" + npc.spawn_id
	check(str(info.get("waypoint_id", "")) == waypoint_id and str(info.get("target_kind", "")) == "encounter", "scout guidance has a stable encounter waypoint beyond sensor range")
	await command("undock")
	await sync_ui()
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
	var anchor: Vector3 = host.world.anchor_position(str(spawn.anchor_id))
	place(anchor + Vector3(0.0, 500.0, float(host.store.catalog.rule("target_marker_detection_range_m")) * 2.0))
	await sync_ui()
	if not check(host.ui.overview.filtered_ids.has(waypoint_id) and not host.ui.overview.filtered_ids.has(npc.npc_instance_id), "far scout appears as a mission site while individual ship remains undetected"): overview_diagnostic("scout-far", [waypoint_id, npc.npc_instance_id])
	check(host.ui.mission_locate_button.is_visible_in_tree() and host.ui.mission_travel_button.is_visible_in_tree(), "flight HUD exposes persistent locate and travel actions")
	var pose: Transform3D = host.world.flight.global_transform
	if await actual_click(host.ui.mission_locate_button, "flight scout locator"):
		await sync_ui()
		check(host.ui.target_id == waypoint_id and host.ui.overview.selected_id == waypoint_id, "locator persists through ordinary overview refresh rather than clearing a distant NPC")
		check(host.world.flight.global_transform.is_equal_approx(pose) and not host.local_navigation.active(), "locate selects an actual waypoint without moving the ship")
		check(host.world.targets.has(waypoint_id) and is_instance_valid(host.world.targets[waypoint_id].node), "selected mission waypoint references a real world node")
	await capture("scout-far-guidance")
	if await actual_click(host.ui.mission_travel_button, "flight scout travel"):
		check(host.local_navigation.active() and host.local_navigation.target_id == waypoint_id, "explicit mission travel starts actual local navigation to the selected site")
		var before_mode: String = host.local_navigation.mode
		var before_phase: String = host.local_navigation.phase
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(20.0, 8.0); event.position = host.ui.root.size * 0.5
		host._unhandled_input(event)
		check(host.local_navigation.mode == before_mode and host.local_navigation.phase == before_phase and host.local_navigation.target_id == waypoint_id, "ordinary mouse observation does not cancel the task navigation order")
		host.local_navigation.stop()
	place(anchor + Vector3(0.0, 100.0, 900.0))
	await sync_ui()
	if not check(host.ui.overview.filtered_ids.has(npc.npc_instance_id), "actual scout becomes individually selectable nearby"): overview_diagnostic("scout-near", [waypoint_id, npc.npc_instance_id])
	host.ui._select_target(npc.npc_instance_id)
	check(host._combat_target_valid(npc.npc_instance_id), "nearby tutorial scout is a valid real combat target on the borrowed armed hull")
	await capture("scout-near-combat")
	await guidance_layout_checks()
	var before_credit: int = host.state.player().credit
	host.gameplay.call("damage_npc", npc.npc_instance_id, Vector3.ONE * 100000.0)
	await sync_ui()
	check(not npc.alive and not host.world.targets.has(npc.npc_instance_id), "real death removes the enemy's scene target")
	check(not host.world.targets.has(waypoint_id), "completed combat objective removes its task-site beacon")
	check(host.state.player().credit == before_credit, "tutorial target supplies no unintended farmable bounty")
	check(host.gameplay.get("missions").call("progress", missions.call("active"), 2).progress_units == 1, "actual death event advances the scout objective")
	host.gameplay.call("tick", float(host.store.catalog.rule("combat_exit_delay_s")) + 0.1)
	await dock_at("station_anchor_port")
	await command("deliver_mission", "tutorial_combat")
	check(bool(missions.call("completed", "tutorial_combat")), "combat tutorial actual claim and loan return complete")

func guidance_layout_checks() -> void:
	for dimensions: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = dimensions
			root.content_scale_size = Vector2i(Vector2(dimensions) / scale)
			await frames(5)
			host.ui.tick(0.3)
			await frames(3)
			var label: String = "%dx%d-%d" % [dimensions.x, dimensions.y, int(scale * 100)]
			var bounds: Rect2 = Rect2(Vector2.ZERO, host.ui.root.size)
			check(host.ui.mission_locate_button.is_visible_in_tree() and bounds.encloses(host.ui.mission_locate_button.get_global_rect()) and host.ui.mission_travel_button.is_visible_in_tree() and bounds.encloses(host.ui.mission_travel_button.get_global_rect()), "flight task navigation buttons fit the actual logical viewport " + label)
			check(not host.ui.mission_locate_button.tooltip_text.is_empty() and not host.ui.mission_travel_button.tooltip_text.is_empty(), "compact task actions retain full instruction tooltips " + label)
			await capture("mission-guidance-" + label)
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	await frames(5)

func story_route_checks() -> void:
	await command("accept_mission", "tutorial_exploration")
	await command("claim_loan", "loan_tutorial_lantern")
	await command("undock")
	var missions: RefCounted = host.gameplay.get("missions")
	var info: Dictionary = missions.call("guidance")
	check(not bool(info.get("local", true)) and str(info.get("waypoint_kind", "")) == "gate" and str(info.get("sector_id", "")) == "sector_echo", "remote mission resolves the next real wormhole gate and final destination")
	await sync_ui()
	if await actual_click(host.ui.mission_locate_button, "cross-sector mission locator"):
		check(host.ui.target_id == str(info.waypoint_id) and host.world.targets.has(host.ui.target_id), "remote locator selects a present gate instead of a missing off-sector object")
	if not await relocate("sector_echo"): return
	missions = host.gameplay.get("missions")
	info = missions.call("guidance")
	check(bool(info.get("local", false)) and str(info.get("waypoint_id", "")) == "signal_echo_common_survey", "guidance automatically switches to the local objective in the destination system")
	var scan: Dictionary = host.store.catalog.one("signal_defs", "signal_id", "signal_echo_common_survey")
	place(host.world.anchor_position(str(scan.anchor_id)))
	production_action("start_scan", "signal_echo_common_survey")
	host.gameplay.call("tick", 11.0)
	info = missions.call("guidance")
	check(str(info.get("target_id", "")) == "station_anchor_port" and str(info.get("waypoint_kind", "")) == "gate", "completed field objective guides return to its real turn-in station across systems")
	await dock_at("station_anchor_port")
	await command("deliver_mission", "tutorial_exploration")
	missions = host.gameplay.get("missions")
	check(bool(missions.call("completed", "tutorial_exploration")), "real T4 scanner, delivery and loan return unlock the story route")
	info = missions.call("station_guidance", "story_mirror")
	check(str(info.get("sector_id", "")) == "sector_mirror" and not str(info.get("waypoint_id", "")).is_empty() and str(info.get("route_reason", "" )).is_empty(), "first mainline chapter has an unlocked navigable route to Mirror station")
	await show_page("missions")
	host.ui.show_mission("story_mirror")
	await frames()
	var row_exists: bool = business_rows().any(func(row: Dictionary): return str(row.id) == "story_mirror")
	check(row_exists and action_button("mission_station", "story_mirror") != null, "first chapter remains discoverable from Anchor with a usable station locator")
	await capture("story-next-chapter")

func encounter_checks() -> void:
	var encounters: RefCounted = host.gameplay.get("encounters")
	if not check(encounters != null and bool(encounters.call("supported")), "production encounter service uses the world's reviewed frozen extension"): return
	var definitions: Array[Dictionary] = host.store.catalog.rows("encounter_defs")
	check(definitions.size() == 10, "formal catalog defines one combat site in each of the ten systems")
	# Content coverage uses explicit frozen unlock preparation. It is not a
	# claim that the eight story chapters were naturally completed here.
	for unlock: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.call("grant_unlock", str(unlock.unlock_id))
	host.gameplay.call("_sync_spawns")
	host.state.player().credit = 100000
	await command("buy_ship", "frigate_kestrel")
	var owned: D.ShipStateDto
	for ship: D.ShipStateDto in host.state.rows("ship_state"):
		if ship.ship_def_id == "frigate_kestrel" and ship.policy_id == "normal_owned": owned = ship
	if not check(owned != null, "actual market purchase supplies the normal cargo test hull"): return
	await command("switch_ship", owned.ship_instance_id)
	await command("undock")
	for definition: Dictionary in definitions:
		if not await relocate(str(definition.sector_id)): return
		encounters = host.gameplay.get("encounters")
		var waypoint_id: String = "group:" + str(definition.encounter_id)
		var anchor: Vector3 = host.world.anchor_position(str(definition.anchor_id))
		place(anchor + Vector3(0.0, 800.0, float(definition.reveal_range_m) * 2.5))
		await sync_ui()
		check(host.world.targets.has(waypoint_id) and str(host.world.targets[waypoint_id].kind) == "encounter", "real system group waypoint exists " + str(definition.sector_id))
		check(host.ui.overview.filtered_ids.has(waypoint_id), "distant encounter group is discoverable in overview " + str(definition.sector_id))
		var member_ids: Array[String] = []
		for member: Dictionary in host.store.catalog.rows("encounter_members"):
			if member.encounter_id != definition.encounter_id: continue
			var npc := host.state.find("npc_state", "spawn_id", str(member.spawn_id)) as D.NpcStateDto
			if check(npc != null and npc.alive, "frozen member has a real active NPC " + str(member.spawn_id)):
				member_ids.append(npc.npc_instance_id)
				check(not host.ui.overview.filtered_ids.has(npc.npc_instance_id), "far overview avoids individual contacts beyond sensors " + str(member.spawn_id))
		check(member_ids.size() == 2 and int(encounters.call("remaining", str(definition.encounter_id))) == 2, "site contains its two independent authored ships " + str(definition.sector_id))
		place(anchor + Vector3(0.0, 0.0, float(definition.reveal_range_m) * 1.5))
		await sync_ui()
		var compact: bool = host.ui.overview.filtered_ids.has(waypoint_id)
		for member_id: String in member_ids: compact = compact and not host.ui.overview.filtered_ids.has(member_id)
		check(compact, "intermediate range retains a group without prematurely expanding individual contacts " + str(definition.sector_id))
		if definition.sector_id == "sector_anchor" and not member_ids.is_empty():
			var wandering := host.state.find("npc_state", "npc_instance_id", member_ids[0]) as D.NpcStateDto
			var body: CharacterBody3D = host.world.npcs[wandering.npc_instance_id]
			var old_transform: Transform3D = body.global_transform
			# Explicit spatial precondition for an actual authored NPC that has left
			# its group's vicinity. Detection still uses the real row and model.
			body.global_position = host.world.flight.global_position + Vector3.RIGHT * float(definition.reveal_range_m) * 0.4
			wandering.pos_x = body.global_position.x; wandering.pos_y = body.global_position.y; wandering.pos_z = body.global_position.z
			body.reset_physics_interpolation()
			await sync_ui()
			check(host.world.flight.global_position.distance_to(anchor) > float(definition.reveal_range_m) and host.ui.overview.filtered_ids.has(wandering.npc_instance_id), "a real nearby NPC remains detectable after leaving a still-distant group")
			body.global_transform = old_transform
			wandering.pos_x = body.global_position.x; wandering.pos_y = body.global_position.y; wandering.pos_z = body.global_position.z
			body.reset_physics_interpolation()
		place(anchor + Vector3(0.0, 800.0, float(definition.reveal_range_m) * 2.5))
		await sync_ui()
		var navigation: Dictionary = host.local_navigation.inspect(waypoint_id)
		check(bool(navigation.get("warp_ready", false)), "real local navigation accepts a distant group warp " + str(definition.sector_id) + ": " + str(navigation.get("warp_reason", "")))
		if definition.sector_id == "sector_anchor":
			host.ui._select_target(waypoint_id)
			await capture("encounter-far")
			if check(host._navigation_command("warp", waypoint_id), "production warp command durably saves its origin and starts"):
				var steps: int = 0
				while host.local_navigation.active() and steps < 1800:
					host.local_navigation.tick(1.0 / 60.0)
					steps += 1
				await frames(4); await wait_writer()
				check(not host.local_navigation.active() and host.local_navigation.phase == "arrived", "real group warp completes without disappearing target")
				check(host.world.flight.global_position.distance_to(anchor) < float(definition.reveal_range_m) and host.world.flight.velocity.is_zero_approx(), "group warp stops inside the detailed-contact reveal range")
		else:
			place(anchor + Vector3(0.0, 300.0, float(definition.warp_arrival_m)))
		await sync_ui()
		var found: bool = true
		for member_id: String in member_ids: found = found and host.ui.overview.filtered_ids.has(member_id)
		if not check(found and host.ui.overview.filtered_ids.has(waypoint_id), "nearby group expands to real member contacts and retains the stable beacon " + str(definition.sector_id)): overview_diagnostic("group-near-" + str(definition.sector_id), member_ids + [waypoint_id])
		if definition.sector_id == "sector_anchor": await capture("encounter-near-members")
		place(anchor + Vector3(0.0, 800.0, float(definition.reveal_range_m) * 2.5))
		await sync_ui()
		found = host.ui.overview.filtered_ids.has(waypoint_id)
		for member_id: String in member_ids: found = found and not host.ui.overview.filtered_ids.has(member_id)
		check(found, "leaving a site restores the distant group view " + str(definition.sector_id))
	check(host.state.rows("encounter_state").size() == definitions.size(), "all ten world-time encounter states are persistent typed authority")

func rng_record() -> Dictionary:
	return Codec.new().encode_row("rng_state", host.state.rows("rng_state")[0])

func package_row(package_id: String) -> D.SalvagePackageStateDto:
	return host.state.find("salvage_package_state", "package_id", package_id) as D.SalvagePackageStateDto

func warehouse_id(station_id: String) -> String:
	return str(host.gameplay.get("inventory").call("warehouse", station_id))

func warehouse_row_for(asset_id: String) -> Dictionary:
	var panel: Control = host.ui.get("warehouse_panel") as Control
	if not is_instance_valid(panel): return {}
	var data: Dictionary = panel.get("refs")
	return data.get("rows_by_id", {}).get(asset_id, {})

func packages_from_sources(ids: Array[String]) -> Array[D.SalvagePackageStateDto]:
	var result: Array[D.SalvagePackageStateDto] = []
	for package: D.SalvagePackageStateDto in host.state.rows("salvage_package_state"):
		if ids.has(package.source_npc_instance_id): result.append(package)
	return result

func package_interaction_checks(package: D.SalvagePackageStateDto, point: Vector3) -> void:
	var origin: String = package.host_container_id
	var only_package: bool = true
	for row: RefCounted in host.state.rows("inventory_stack_state") + host.state.rows("item_instance_state"):
		if row.container_id == origin: only_package = false
	check(only_package, "ambient recovery wreck genuinely contains only its sealed package")
	var context: Dictionary = host.interaction_context(origin)
	check(bool(context.get("ready", false)) and str(context.get("action", "")) == "pickup_wreck", "package-only wreck exposes a legal nearby F interaction")
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 1; obstacle.collision_mask = 0
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = host.world.flight.global_position.distance_to(point) * 0.2
	collision.shape = sphere; obstacle.add_child(collision)
	host.world.add_child(obstacle)
	obstacle.global_position = (host.world.flight.global_position + point) * 0.5
	await physics_frame; await physics_frame
	context = host.interaction_context(origin)
	check(not bool(context.get("ready", false)) and str(context.get("reason", "")).contains("遮挡"), "real physics occluder prevents the F interaction preview")
	production_action("pickup_wreck", origin, 1, "", false)
	check(package.host_container_id == origin and package.status == "sealed", "same production line-of-sight guard rejects backend salvage without moving its package")
	host.world.remove_child(obstacle); obstacle.queue_free()
	await physics_frame; await frames(2)
	context = host.interaction_context(origin)
	check(bool(context.get("ready", false)), "removing the real occluder restores the interaction")
	host.ui.show_page(""); host.ui._select_target(origin)
	var focus: Control = host.get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F; event.keycode = KEY_F; event.pressed = pressed
		host.get_viewport().push_input(event, true)
	await frames(4); await wait_writer()
	check(package.host_container_id != origin and package.status == "sealed", "actual F key routes through Main and recovers the package-only wreck")

func atomic_open_failure_checks(package_id: String) -> void:
	var checkpoint_store := host.store as FaultStore
	if not check(checkpoint_store != null, "atomic identification fixture uses a controllable real transaction checkpoint"): return
	var authority: XJRuntimeState = host.state
	var package_before: Dictionary = Codec.new().encode_row("salvage_package_state", package_row(package_id))
	var credit_before: int = host.state.player().credit
	var rng_before: Dictionary = rng_record()
	var receipts_before: int = host.state.rows("action_receipt_state").size()
	var snapshots_before: Array = host.store._records("SELECT snapshot_id,status,simulation_tick FROM save_snapshot ORDER BY snapshot_id")
	var slots_before: Array = host.store._records("SELECT slot_id,current_snapshot_id,content_snapshot_id,generation FROM save_slot ORDER BY slot_id")
	var resume_before: Array = host.store._records("SELECT p.profile_id,p.world_id,r.resume_snapshot_id,r.last_committed_sequence FROM profile_resume p JOIN runtime_session r ON r.world_id=p.world_id ORDER BY p.profile_id")
	var auto_before: int = host.auto_slot
	checkpoint_store.fault = "pointer"
	await actual_click(action_button("open_salvage", package_id), "salvage identification with injected durable-save failure")
	checkpoint_store.fault = ""
	check(host.state == authority and host.store.active_state == authority and Codec.new().encode_row("salvage_package_state", package_row(package_id)) == package_before and host.state.player().credit == credit_before and rng_record() == rng_before and host.state.rows("action_receipt_state").size() == receipts_before and host.auto_slot == auto_before, "failed GUI identification preserves original live authority, sealed reward, funds, RNG, action receipts and slot rotation")
	check(host.store._records("SELECT snapshot_id,status,simulation_tick FROM save_snapshot ORDER BY snapshot_id") == snapshots_before and host.store._records("SELECT slot_id,current_snapshot_id,content_snapshot_id,generation FROM save_slot ORDER BY slot_id") == slots_before and host.store._records("SELECT p.profile_id,p.world_id,r.resume_snapshot_id,r.last_committed_sequence FROM profile_resume p JOIN runtime_session r ON r.world_id=p.world_id ORDER BY p.profile_id") == resume_before, "injected failure after pointer publication rolls back snapshots, save slots and durable resume endpoint")
	await show_page("salvage")
	check(action_button("open_salvage", package_id) != null and package_row(package_id).status == "sealed", "failed durable identification remains retryable through the actual station UI")

func route_and_gate_mass_checks() -> void:
	if not await relocate("sector_mirror"): return
	var missions: RefCounted = host.gameplay.get("missions")
	var endpoint: Dictionary = host.store.catalog.one("gate_endpoint_defs", "endpoint_id", "endpoint_wandering_mirror_mist")
	var gate := host.state.find("gate_state", "connection_id", str(endpoint.connection_id)) as D.GateStateDto
	if not check(gate != null and gate.has_remaining_mass_budget_kg and gate.has_lifetime_remaining_s, "real finite wormhole exposes persistent mass and lifetime authority"): return
	var mass: float = float(host.gameplay.call("metrics", host.state.ship()).total_mass_kg)
	check(is_equal_approx(host.travel._mass(host.state.ship()), mass), "travel and gameplay compute identical loaded-hull mass including sealed salvage")
	var single_limit: float = float(host.store.catalog.one("effective_connection_defs", "connection_id", str(endpoint.connection_id)).max_gross_mass_kg)
	check(str(missions.call("_gate_route_reason", endpoint, single_limit + 1.0)).contains("单舰"), "route eligibility also exposes the frozen single-hull gross-mass limit")
	var original: Dictionary = Codec.new().encode_row("gate_state", gate)
	var baseline: Dictionary = missions.call("station_guidance", "story_mist", "sector_mirror")
	check(str(baseline.get("waypoint_id", "")) == str(endpoint.endpoint_id) and str(baseline.get("route_reason", "")).is_empty(), "actual task routing chooses the currently legal direct finite wormhole")
	gate.enabled = false
	var blocked: Dictionary = missions.call("station_guidance", "story_mist", "sector_mirror")
	check(str(blocked.get("waypoint_id", "")) != str(endpoint.endpoint_id) and str(blocked.get("route_reason", "")).is_empty() and str(missions.call("_gate_route_reason", endpoint, mass)).contains("关闭"), "routing bypasses a disabled wormhole and explains the direct door rejection")
	gate.enabled = true; gate.lifetime_remaining_s = 0.0
	blocked = missions.call("station_guidance", "story_mist", "sector_mirror")
	check(str(blocked.get("waypoint_id", "")) != str(endpoint.endpoint_id) and str(blocked.get("route_reason", "")).is_empty() and str(missions.call("_gate_route_reason", endpoint, mass)).contains("寿命"), "routing bypasses an expired wormhole and explains the exhausted lifetime")
	gate.lifetime_remaining_s = float(original.lifetime_remaining_s)
	var package_mass: float = 0.0
	for package: D.SalvagePackageStateDto in host.state.rows("salvage_package_state"):
		if package.status == "sealed" and package.has_host_container_id:
			var container := host.state.find("container_state", "container_id", package.host_container_id) as D.ContainerStateDto
			if container != null and container.ship_instance_id == host.state.ship().ship_instance_id: package_mass += float(host.store.catalog.one("salvage_package_defs", "package_def_id", package.package_def_id).mass_kg)
	gate.remaining_mass_budget_kg = mass - package_mass * 0.5
	blocked = missions.call("station_guidance", "story_mist", "sector_mirror")
	check(package_mass > 0.0 and gate.remaining_mass_budget_kg > mass - package_mass and str(blocked.get("waypoint_id", "")) != str(endpoint.endpoint_id) and str(blocked.get("route_reason", "")).is_empty() and str(missions.call("_gate_route_reason", endpoint, mass)).contains("质量"), "sealed salvage payload changes gate eligibility and task routing selects a legal alternate route")
	var altered: Array[Dictionary] = []
	for door: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
		if str(door.origin_sector_id) != "sector_mirror" or str(door.connection_id) == str(endpoint.connection_id): continue
		var row := host.state.find("gate_state", "connection_id", str(door.connection_id)) as D.GateStateDto
		altered.append({"row": row, "enabled": row.enabled}); row.enabled = false
	blocked = missions.call("station_guidance", "story_mist", "sector_mirror")
	check(str(blocked.get("waypoint_id", "")) == str(endpoint.endpoint_id) and str(blocked.get("route_reason", "")).contains("质量"), "when every legal route is blocked, actual guidance exposes the physical route's specific mass-budget reason")
	gate.remaining_mass_budget_kg = float(original.remaining_mass_budget_kg); gate.lifetime_remaining_s = 0.0
	blocked = missions.call("station_guidance", "story_mist", "sector_mirror")
	check(str(blocked.get("route_reason", "")).contains("寿命"), "blocked task guidance reports lifetime exhaustion rather than a usable travel action")
	for changed: Dictionary in altered: changed.row.enabled = changed.enabled
	gate.enabled = bool(original.enabled); gate.lifetime_remaining_s = float(original.lifetime_remaining_s)
	gate.remaining_mass_budget_kg = float(original.remaining_mass_budget_kg)
	host.gameplay.call("tick", float(host.store.catalog.rule("combat_exit_delay_s")) + 0.2)
	var anchor: Vector3 = host.world.anchor_position(str(endpoint.entry_anchor_id))
	place(anchor)
	var budget_before: float = gate.remaining_mass_budget_kg
	mass = float(host.gameplay.call("metrics", host.state.ship()).total_mass_kg)
	if check(host.travel.begin(str(endpoint.endpoint_id)), "real finite wormhole accepts the salvaging hull and its sealed payload"):
		var prepare_s: float = float(host.store.catalog.one("effective_connection_defs", "connection_id", str(endpoint.connection_id)).prepare_s)
		host.travel.tick(prepare_s + 0.1)
		await frames(4); await wait_writer()
		var arrived := host.state.find("gate_state", "connection_id", str(endpoint.connection_id)) as D.GateStateDto
		check(host.state.current_sector() == "sector_mist" and is_equal_approx(budget_before - arrived.remaining_mass_budget_kg, mass), "real durable wormhole transfer deducts the exact loaded gross mass including salvage packages")
		check(salvage_ids.all(func(id: String): return package_row(id).status == "sealed" and package_row(id).has_host_container_id), "actual wormhole transfer preserves every sealed pre-drawn recovery package")

func salvage_checks() -> void:
	check(host.state.rows("salvage_package_state").is_empty(), "protected tutorial encounter creates no salvage packages")
	if not await relocate("sector_anchor"): return
	var encounters: RefCounted = host.gameplay.get("encounters")
	refresh_group_id = "encounter_anchor_patrol"
	var definition: Dictionary = host.store.catalog.one("encounter_defs", "encounter_id", refresh_group_id)
	var group := host.state.find("encounter_state", "encounter_id", refresh_group_id) as D.EncounterStateDto
	var sources: Array[D.NpcStateDto] = []
	for member: Dictionary in host.store.catalog.rows("encounter_members"):
		if str(member.encounter_id) == refresh_group_id:
			var npc := host.state.find("npc_state", "spawn_id", str(member.spawn_id)) as D.NpcStateDto
			if npc != null: sources.append(npc); old_member_ids.append(npc.npc_instance_id)
	if not check(sources.size() == 2, "salvage source is the real two-member Anchor group"): return
	var before_packages: int = host.state.rows("salvage_package_state").size()
	var credit_before: int = host.state.player().credit
	var expected_bounty: int = 0
	for index: int in range(sources.size()):
		var npc: D.NpcStateDto = sources[index]
		var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
		var enemy: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", str(spawn.npc_id))
		expected_bounty += int(enemy.reward_credit)
		host.gameplay.call("damage_npc", npc.npc_instance_id, Vector3.ONE * 100000.0)
		check(not npc.alive, "real aggregate combat damage destroys source " + npc.spawn_id)
		if index == 0:
			check(is_zero_approx(group.respawn_remaining_s), "killing one member does not start a group replacement timer")
			encounters.call("tick", float(definition.respawn_seconds) + 1.0)
			check(host.state.find("npc_state", "npc_instance_id", npc.npc_instance_id) == npc and not npc.alive, "dead member is not replaced while the surviving escort remains")
	await sync_ui()
	var packages: Array[D.SalvagePackageStateDto] = packages_from_sources(old_member_ids)
	if not check(packages.size() == 2 and host.state.rows("salvage_package_state").size() == before_packages + 2, "each real ambient death creates one pre-drawn recovery package"): return
	check(host.state.player().credit == credit_before + expected_bounty, "existing actual kill bounties remain exact and distinct from salvage rewards")
	check(is_equal_approx(group.respawn_remaining_s, float(definition.respawn_seconds)), "the last actual death starts the catalog's whole-group world-time cooldown")
	var after_rng: Dictionary = rng_record()
	for npc: D.NpcStateDto in sources:
		host.gameplay.call("damage_npc", npc.npc_instance_id, Vector3.ONE * 100000.0)
		check(not bool(encounters.call("on_destroy", npc)), "duplicate death callback cannot create a second package " + npc.npc_instance_id)
	check(rng_record() == after_rng and packages_from_sources(old_member_ids).size() == 2 and host.state.player().credit == credit_before + expected_bounty, "duplicate kills draw no RNG and pay no additional credit")
	var cargo: String = str(host.gameplay.get("inventory").call("hold", host.state.ship(), T.ContainerKind.CARGO))
	for package: D.SalvagePackageStateDto in packages:
		salvage_ids.append(package.package_id)
		var reward: Dictionary = host.store.catalog.one("salvage_reward_defs", "reward_id", package.reward_id)
		check(package.status == "sealed" and not reward.is_empty() and str(reward.package_def_id) == package.package_def_id, "package stores an actual frozen reward identity before opening")
		var wreck := host.state.find("container_state", "container_id", package.host_container_id) as D.ContainerStateDto
		if not check(wreck != null and wreck.kind == T.ContainerKind.WRECK, "package is contained in a durable physical wreck"): continue
		var point: Vector3 = Vector3(wreck.pos_x, wreck.pos_y, wreck.pos_z)
		place(point + Vector3.UP * float(host.store.catalog.rule("wreck_pickup_radius_m")) * 2.0)
		var origin: String = package.host_container_id
		production_action("pickup_wreck", origin, 1, "", false)
		check(package.host_container_id == origin and package.status == "sealed", "out-of-range salvage keeps the unopened package in its original wreck")
		production_action("open_salvage", package.package_id, 1, "", false)
		check(package.status == "sealed" and rng_record() == after_rng, "opening in flight is rejected without consuming the package or RNG")
		place(point + Vector3.UP * float(host.store.catalog.rule("wreck_pickup_radius_m")) * 0.5)
		if package == packages[0]:
			var inventory: RefCounted = host.gameplay.get("inventory")
			var filler: String = "ammo_kinetic_slug_i"
			var capacity: int = int(host.gameplay.call("metrics", host.state.ship()).cargo_capacity_l)
			var fill_count: int = int(inventory.call("room", cargo, filler, capacity + 1))
			var created: Array = inventory.call("grant", cargo, filler, fill_count)
			check(fill_count > 0 and not created.is_empty() and not bool(encounters.call("can_hold", cargo, package.package_def_id)), "catalog-derived cargo fill leaves insufficient volume or payload for a whole package")
			production_action("pickup_wreck", origin, 1, "", false)
			check(package.host_container_id == origin and package.status == "sealed", "capacity rejection retains the complete package at its source")
			check(bool(inventory.call("consume", cargo, filler, fill_count)), "explicit filler is consumed without removing the source wreck")
		var before: Dictionary = host.gameplay.get("inventory").call("totals", cargo)
		var travel_mass_before: float = host.travel._mass(host.state.ship())
		var dimensions: Dictionary = host.store.catalog.one("salvage_package_defs", "package_def_id", package.package_def_id)
		if package == packages[0]: await package_interaction_checks(package, point)
		else: production_action("pickup_wreck", origin)
		var totals: Dictionary = host.gameplay.get("inventory").call("totals", cargo)
		check(package.host_container_id == cargo and is_equal_approx(float(totals.volume) - float(before.volume), float(dimensions.volume_m3) * 1000.0) and is_equal_approx(float(totals.mass) - float(before.mass), float(dimensions.mass_kg)), "actual salvage enters cargo and consumes database volume and payload")
		check(is_equal_approx(host.travel._mass(host.state.ship()) - travel_mass_before, float(dimensions.mass_kg)), "real travel hull mass increases by the exact picked-up package payload")
		await sync_ui()
		check(host.state.find("container_state", "container_id", origin) == null and not host.world.targets.has(origin), "empty wreck is immediately removed from state and the target scene")
		production_action("pickup_wreck", origin, 1, "", false)
	check(rng_record() == after_rng, "salvage movement and rejected interactions do not change the pre-drawn reward stream")
	await capture("salvage-picked-cargo")
	# Pause is exercised through Main, which owns whether simulation advances.
	await show_page("pause")
	var paused_tick: int = host.state.snapshot.meta.simulation_tick
	var paused_remaining: float = group.respawn_remaining_s
	host._physics_process(1.0)
	check(host.state.snapshot.meta.simulation_tick == paused_tick and group.respawn_remaining_s == paused_remaining, "pause stops whole-group cooldown and ordinary world time")
	await show_page("")
	await route_and_gate_mass_checks()
	# A different loaded sector still advances the same authoritative world.
	if not await relocate("sector_echo"): return
	group = host.state.find("encounter_state", "encounter_id", refresh_group_id) as D.EncounterStateDto
	var outside_before: float = group.respawn_remaining_s
	host.gameplay.call("tick", 2.0)
	check(is_equal_approx(group.respawn_remaining_s, outside_before - 2.0), "world time advances encounter cooldown outside its currently loaded system")
	host.gameplay.call("tick", float(host.store.catalog.rule("combat_exit_delay_s")) + 0.2)
	if not await dock_at("station_echo_depot"): return
	await show_page("salvage")
	var first: D.SalvagePackageStateDto = package_row(salvage_ids[0])
	var first_reward: Dictionary = host.store.catalog.one("salvage_reward_defs", "reward_id", first.reward_id)
	var warehouse: String = warehouse_id("station_echo_depot")
	var reward_item: String = str(first_reward.item_def_id) if first_reward.item_def_id != null else ""
	var before_quantity: int = int(host.gameplay.get("inventory").call("count", warehouse, reward_item, true)) if not reward_item.is_empty() else 0
	var before_credit: int = host.state.player().credit
	var before_open_rng: Dictionary = rng_record()
	await atomic_open_failure_checks(first.package_id)
	if await actual_click(action_button("open_salvage", first.package_id), "station salvage identification"):
		first = package_row(salvage_ids[0])
		check(first.status == "opened" and not first.has_host_container_id and first.opened_station_id == "station_echo_depot", "any legal station records exactly one opened provenance record")
		check(host.state.player().credit == before_credit + int(first_reward.credit_units), "station service grants the exact pre-drawn credit amount")
		if not reward_item.is_empty():
			check(int(host.gameplay.get("inventory").call("count", warehouse, reward_item, true)) == before_quantity + int(first_reward.quantity), "station service grants exact frozen goods to the local warehouse")
		opened_ids.append(first.package_id)
	production_action("open_salvage", first.package_id, 1, "", false)
	check(host.state.player().credit == before_credit + int(first_reward.credit_units) and rng_record() == before_open_rng, "opening twice does not pay or redraw the package")
	await capture("salvage-station-opened")
	var second: D.SalvagePackageStateDto = package_row(salvage_ids[1])
	await show_page("warehouse")
	var transfer_row: Dictionary = warehouse_row_for(second.package_id)
	check(not transfer_row.is_empty() and str(transfer_row.kind) == "salvage" and str(transfer_row.container_id) == second.host_container_id and not bool(transfer_row.remote), "sealed package has its exact current-cargo identity in the real dual warehouse list")
	if not transfer_row.is_empty():
		var transfer_button: Button = transfer_row.get("button") as Button
		var transfer_amount: SpinBox = transfer_row.get("amount") as SpinBox
		check(transfer_button != null and not transfer_button.disabled and str(transfer_button.get_meta("action", "")) == "move_salvage" and str(transfer_button.get_meta("target", "")) == second.package_id and str(transfer_button.get_meta("extra", "")) == warehouse and transfer_amount != null and is_equal_approx(transfer_amount.min_value, 1.0) and is_equal_approx(transfer_amount.max_value, 1.0), "dual warehouse package row exposes only its real one-package station transfer")
	production_action("move_salvage", second.package_id, 1, warehouse)
	check(second.host_container_id == warehouse, "sealed recovery package can move to the actual local station warehouse")
	pending_package = Codec.new().encode_row("salvage_package_state", second)
	pending_rng = rng_record()
	await show_page("salvage")
	check(action_button("open_salvage", second.package_id) != null, "unopened station recovery package has a discoverable identification action")
	await capture("salvage-station-sealed")

func persistence_checks() -> void:
	check(host.store.save(host.state, "manual", 1), "complete new mission state seals in SQLite: " + host.store.last_error)
	var identity: String = host.state.world_id
	var credit: int = host.state.player().credit
	var group_before: Dictionary = Codec.new().encode_row("encounter_state", host.state.find("encounter_state", "encounter_id", refresh_group_id)) if not refresh_group_id.is_empty() else {}
	await release_host()
	if not await start_host(): return
	await command("continue")
	check(host.state != null and host.state.world_id == identity and host.state.player().credit == credit, "closed SQLite and Main restart restore the actual mission world")
	check(bool(host.gameplay.get("missions").call("completed", "tutorial_combat")), "claimed combat tutorial remains complete after restart")
	if not pending_package.is_empty():
		var package: D.SalvagePackageStateDto = package_row(str(pending_package.package_id))
		check(package != null and Codec.new().encode_row("salvage_package_state", package) == pending_package and rng_record() == pending_rng, "SQLite restart preserves the sealed reward, location, provenance and PCG state")
		var reward: Dictionary = host.store.catalog.one("salvage_reward_defs", "reward_id", package.reward_id)
		var warehouse: String = warehouse_id(host.state.player().docked_station_id)
		var item_id: String = str(reward.item_def_id) if reward.item_def_id != null else ""
		var quantity_before: int = int(host.gameplay.get("inventory").call("count", warehouse, item_id, true)) if not item_id.is_empty() else 0
		var credit_before: int = host.state.player().credit
		production_action("open_salvage", package.package_id)
		check(package.status == "opened" and host.state.player().credit == credit_before + int(reward.credit_units) and rng_record() == pending_rng, "reopened SQLite identifies the same fixed reward without a new random draw")
		if not item_id.is_empty(): check(int(host.gameplay.get("inventory").call("count", warehouse, item_id, true)) == quantity_before + int(reward.quantity), "reopened package grants its original exact item quantity")
		opened_ids.append(package.package_id)
		check(host.store.save(host.state, "manual", 2), "opened one-time reward records seal durably")
		credit = host.state.player().credit
		await release_host()
		if not await start_host(): return
		await command("continue")
		for id: String in opened_ids: production_action("open_salvage", id, 1, "", false)
		check(host.state.player().credit == credit and opened_ids.all(func(id: String): return package_row(id).status == "opened"), "opened packages remain consumed and unpaid after a second process restart")
	var group := host.state.find("encounter_state", "encounter_id", refresh_group_id) as D.EncounterStateDto
	if group == null or group_before.is_empty(): return
	check(is_equal_approx(group.respawn_remaining_s, float(group_before.respawn_remaining_s)) and group.generation == int(group_before.generation), "database restart preserves the whole-group remaining time and generation")
	var before_generation: int = group.generation
	var remaining: float = group.respawn_remaining_s
	var safety_step: float = 1.0 / float(host.store.catalog.rule("simulation_hz"))
	host.gameplay.call("tick", maxf(0.0, remaining - safety_step * 2.0))
	check(group.generation == before_generation and int(host.gameplay.get("encounters").call("remaining", refresh_group_id)) == 0, "whole group remains empty before the final simulation step")
	host.gameplay.call("tick", safety_step * 3.0)
	check(group.generation == before_generation + 1 and int(host.gameplay.get("encounters").call("remaining", refresh_group_id)) == 2, "expiration generates one complete new two-ship wave")
	var all_new: bool = true
	for member: Dictionary in host.store.catalog.rows("encounter_members"):
		if str(member.encounter_id) != refresh_group_id: continue
		var npc := host.state.find("npc_state", "spawn_id", str(member.spawn_id)) as D.NpcStateDto
		all_new = all_new and npc != null and npc.alive and npc.generation == group.generation and not old_member_ids.has(npc.npc_instance_id)
	check(all_new and host.state.rows("salvage_package_state").size() == salvage_ids.size(), "wave members use new NPC identity while old opened package provenance remains intact")
	if await relocate("sector_anchor"):
		await sync_ui()
		check(old_member_ids.all(func(id: String): return not host.world.targets.has(id)), "retired wave members do not leave stale model or overview identities")
	await dock_at("station_anchor_port")
	check(host.store.save(host.state, "manual", 3), "refreshed NPC wave and old salvage provenance save together")
	check(host.store._records("PRAGMA integrity_check")[0].values()[0] == "ok" and host.store._records("PRAGMA foreign_key_check").is_empty(), "final encounter and package snapshots have physical and relational integrity")

func rare_reward_checks() -> void:
	# Choose an isolated new-world seed as an explicit low-probability branch
	# fixture. The package and award still come only from production services;
	# no live stream is reset and no reward or package DTO is forged.
	var total: int = 0
	var module_reward: Dictionary = {}
	var module_lower: int = -1
	for reward: Dictionary in host.store.catalog.rows("salvage_reward_defs"):
		if str(reward.package_def_id) != "package_scout_salvage": continue
		if reward.item_def_id != null:
			var item: Dictionary = host.store.catalog.one("item_defs", "item_id", str(reward.item_def_id))
			if str(item.get("item_type", "")) == "module": module_reward = reward; module_lower = total
		total += int(reward.weight)
	if not check(not module_reward.is_empty() and module_lower >= 0, "formal scout pool contains an authored equipment reward"): return
	var seed: int = -1
	for trial: int in range(1000):
		var reference: Rng = Rng.new()
		reference.initialize(trial)
		var draw: int = reference.bounded(total)
		if draw >= module_lower and draw < module_lower + int(module_reward.weight): seed = trial; break
	if not check(seed >= 0, "actual PCG supplies a deterministic isolated rare-equipment test seed"): return
	var fresh: XJRuntimeState = host.store.new_world("低概率配件奖励独立夹具", seed, host._prepare_loaded)
	if not check(fresh != null, "rare-branch world is initialized through the real store"): return
	host._activate(fresh)
	host.gameplay.call("grant_unlock", "unlock_combat_contracts")
	host.gameplay.call("_sync_spawns")
	await command("undock")
	await sync_ui()
	var npc := host.state.find("npc_state", "spawn_id", "spawn_anchor_patrol_leader") as D.NpcStateDto
	if not check(npc != null and npc.alive, "rare test uses a real authored ambient scout"): return
	host.gameplay.call("damage_npc", npc.npc_instance_id, Vector3.ONE * 100000.0)
	var packages: Array[D.SalvagePackageStateDto] = packages_from_sources([npc.npc_instance_id])
	if not check(packages.size() == 1 and packages[0].reward_id == str(module_reward.reward_id), "production destruction seals the catalog's equipment reward for the chosen world seed"): return
	var package: D.SalvagePackageStateDto = packages[0]
	var wreck := host.state.find("container_state", "container_id", package.host_container_id) as D.ContainerStateDto
	var wreck_point: Vector3 = Vector3(wreck.pos_x, wreck.pos_y, wreck.pos_z)
	var pickup_offset: Vector3 = Vector3(1.0, 0.45, 0.7).normalized() * minf(80.0, float(host.store.catalog.rule("wreck_pickup_radius_m")) * 0.5)
	# Damage is real authority, while scene projection is an explicit step in
	# this frozen-process fixture. Before projection the dead enemy's collider
	# occupies the wreck origin and correctly blocks production salvage LOS.
	var ray := PhysicsRayQueryParameters3D.create(wreck_point + pickup_offset, wreck_point, 3, [host.world.flight.get_rid()])
	var hit: Dictionary = host.world.get_world_3d().direct_space_state.intersect_ray(ray)
	var collider: Node = hit.get("collider") as Node
	print("ENCOUNTER_MISSION_V12_RARE_PRE_PROJECTION " + JSON.stringify({"source_npc_id": npc.npc_instance_id, "blocker_entity_id": str(collider.get_meta("entity_id", "")) if is_instance_valid(collider) else "", "blocker_path": str(collider.get_path()) if is_instance_valid(collider) else "none"}))
	await sync_ui()
	check(not host.world.targets.has(npc.npc_instance_id) and host.world.targets.has(package.host_container_id), "rare reward branch projects the dead scout away and creates its real wreck target")
	place(wreck_point + pickup_offset)
	host.world.flight.global_basis = Basis.looking_at(host.world.flight.global_position.direction_to(wreck_point), Vector3.UP)
	host.world.flight.write_back(); host.world.flight.reset_physics_interpolation()
	host.camera.step(0.0)
	await frames(3)
	var interaction: Dictionary = host.interaction_context(package.host_container_id)
	check(host.world.flight.global_position.distance_to(wreck_point) < 100.0 and host.world.line_of_sight(host.world.flight.global_position, wreck_point, host.world.flight.get_rid(), package.host_container_id) and bool(interaction.get("ready", false)) and (-host.world.flight.global_basis.z).angle_to(host.world.flight.global_position.direction_to(wreck_point)) < 0.01, "rare reward salvage uses an actual nearby facing hull with unobstructed production LOS")
	production_action("pickup_wreck", package.host_container_id)
	host.gameplay.call("tick", float(host.store.catalog.rule("combat_exit_delay_s")) + 0.2)
	if not await dock_at("station_anchor_port"): return
	var warehouse: String = warehouse_id("station_anchor_port")
	var before: int = int(host.gameplay.get("inventory").call("count", warehouse, str(module_reward.item_def_id), true))
	production_action("open_salvage", package.package_id)
	var instances: Array[D.ItemInstanceStateDto] = []
	for item: D.ItemInstanceStateDto in host.state.rows("item_instance_state"):
		if item.container_id == warehouse and item.item_def_id == str(module_reward.item_def_id) and item.origin_kind == T.ItemOrigin.LOOT: instances.append(item)
	check(instances.size() == int(module_reward.quantity) and int(host.gameplay.get("inventory").call("count", warehouse, str(module_reward.item_def_id), true)) == before + int(module_reward.quantity), "actual identification creates the exact normal-owned equipment instances")
	for item: D.ItemInstanceStateDto in instances:
		check(item.policy_id == "normal_owned" and item.quality_multiplier == float(host.store.catalog.rule("standard_quality_multiplier")) and item.durability == float(host.store.catalog.rule("module_durability_max")) and not item.salvage_recipe_id.is_empty(), "loot equipment has usable standard quality, durability and frozen recycle provenance")
	var after: int = host.state.rows("item_instance_state").size()
	production_action("open_salvage", package.package_id, 1, "", false)
	check(host.state.rows("item_instance_state").size() == after, "duplicate identification cannot clone a rare module")
	check(host.store.save(host.state, "manual", 0), "rare loot equipment and opened provenance seal with actual foreign keys")
	await show_page("warehouse")
	await capture("salvage-rare-equipment")

func source_backup_check(world_id: String, snapshot_id: String) -> String:
	var backup_path: String = directory.path_join("content-upgrade-%s-%s-backup.db" % [world_id, snapshot_id])
	if not check(FileAccess.file_exists(backup_path), "content upgrade retains a closed backup unique to source " + snapshot_id): return ""
	var backup: Object = ClassDB.instantiate("SQLite")
	backup.path = backup_path; backup.read_only = true; backup.verbosity_level = 0
	if not check(backup.open_db(), "source-specific native backup independently opens read-only"): return ""
	backup.query("PRAGMA integrity_check")
	var integrity: bool = not backup.query_result.is_empty() and backup.query_result[0].values()[0] == "ok"
	backup.query_with_bindings("SELECT status FROM save_snapshot WHERE snapshot_id=? AND world_id=?", [snapshot_id, world_id])
	check(integrity and backup.query_result.size() == 1 and str(backup.query_result[0].status) == "sealed", "independent native backup contains its exact sealed source and has physical integrity")
	backup.close_db(); backup = null
	return backup_path

func legacy_checks() -> void:
	var source: String = OS.get_environment("XJ_ENCOUNTER_V12_LEGACY")
	if source.is_empty(): print("ENCOUNTER_MISSION_V12_LEGACY NOT_REQUESTED"); return
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/") and not source.contains("..") and FileAccess.file_exists(source), "legacy witness is test-owned and present"): return
	var source_hash: String = FileAccess.get_sha256(source)
	var target: String = directory.path_join("legacy-v084.db")
	DirAccess.remove_absolute(target)
	if not check(DirAccess.copy_absolute(source, target) == OK, "closed actual v0.8.4 fixture is copied without changing its source"): return
	var witness: Object = ClassDB.instantiate("SQLite")
	witness.path = target; witness.read_only = true; witness.verbosity_level = 0
	if not check(witness.open_db(), "read-only copied fixture can be inspected"): return
	witness.query("SELECT format_version FROM database_meta")
	check(int(witness.query_result[0].format_version) == 5, "actual released fixture has historical format 5 before migration")
	witness.query("SELECT snapshot_id,world_id,content_snapshot_id,status,simulation_tick FROM save_snapshot WHERE status='sealed' ORDER BY snapshot_id")
	var old_snapshots: Array = witness.query_result.duplicate(true)
	witness.query("SELECT slot_id,current_snapshot_id,content_snapshot_id,generation FROM save_slot WHERE slot_kind='manual' ORDER BY slot_id")
	var old_manual_slots: Array = witness.query_result.duplicate(true)
	witness.query("SELECT content_snapshot_id,content_hash,frozen_adapter_version FROM content_snapshot WHERE status='sealed' ORDER BY content_snapshot_id")
	var old_content: Array = witness.query_result.duplicate(true)
	witness.close_db(); witness = null
	var legacy: FaultStore = FaultStore.new(target)
	if not check(legacy.open(), "real released format5 upgrades schema with reviewed migration: " + legacy.last_error): legacy.close(); return
	check(int(legacy._records("SELECT format_version FROM database_meta")[0].format_version) == 6 and int(legacy._records("SELECT count(*) AS n FROM migration_history")[0].n) == 9, "format6 registers nine exact migration checksums")
	check(FileAccess.file_exists(directory.path_join("migration-format5-backup.db")), "closed pre-schema-upgrade native backup is retained")
	var snapshots_after_schema: Array = legacy._records("SELECT snapshot_id,world_id,content_snapshot_id,status,simulation_tick FROM save_snapshot WHERE status='sealed' ORDER BY snapshot_id")
	check(snapshots_after_schema == old_snapshots and legacy._records("SELECT content_snapshot_id,content_hash,frozen_adapter_version FROM content_snapshot WHERE status='sealed' ORDER BY content_snapshot_id") == old_content, "schema migration preserves every sealed historical snapshot and frozen identity")
	var previous: XJRuntimeState = legacy.resume()
	if not check(previous != null, "original released world resumes against its own frozen definitions: " + legacy.last_error): legacy.close(); return
	check(not legacy.catalog.table_names.has("encounter_defs"), "before explicit content upgrade the legacy world still uses its frozen old rules")
	var previous_world: String = previous.world_id
	var previous_hash: String = previous.snapshot.content.content_hash
	var previous_content_id: String = previous.snapshot.content.content_snapshot_id
	var previous_snapshot: String = previous.snapshot.meta.snapshot_id
	var previous_credit: int = previous.player().credit
	var previous_cargo: Array[Dictionary] = []
	for stack: D.InventoryStackStateDto in previous.rows("inventory_stack_state"): previous_cargo.append(Codec.new().encode_row("inventory_stack_state", stack))
	var previous_assets: Array[Dictionary] = []
	for item: D.ItemInstanceStateDto in previous.rows("item_instance_state"): previous_assets.append(Codec.new().encode_row("item_instance_state", item))
	var previous_claims: Array[Dictionary] = []
	for receipt: D.MissionClaimStateDto in previous.rows("mission_claim_state"): previous_claims.append(Codec.new().encode_row("mission_claim_state", receipt))
	var old_gameplay: Gameplay = Gameplay.new()
	old_gameplay.setup(previous, legacy.catalog)
	check(not bool(old_gameplay.encounters.call("supported")) and old_gameplay.encounters.call("waypoints", previous.current_sector()).is_empty(), "legacy frozen content safely exposes no invented live-catalog groups")
	old_gameplay.dispose(); old_gameplay = null
	var definitions_before: Dictionary = {}
	for table: String in legacy.catalog.table_names:
		if table != "catalog_meta": definitions_before[table] = legacy.catalog.rows(table)
	# The real store must rollback if candidate scene preparation fails, retaining
	# all old slot endpoints. No fake frozen content or DTO is substituted.
	var count_before: int = int(legacy._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	var rejected: XJRuntimeState = legacy.upgrade_content(previous, func(_candidate: XJRuntimeState): return false)
	check(rejected == null and legacy.active_state == previous and not legacy.catalog.table_names.has("encounter_defs"), "failed content candidate preparation keeps the prior live authority")
	check(int(legacy._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == count_before and legacy._records("SELECT slot_id,current_snapshot_id,content_snapshot_id,generation FROM save_slot WHERE slot_kind='manual' ORDER BY slot_id") == old_manual_slots, "failed additive upgrade publishes no snapshot or manual slot change")
	var prepare: Callable = func(candidate: XJRuntimeState) -> bool:
		var service: Gameplay = Gameplay.new()
		service.setup(candidate, legacy.staging_catalog)
		service.dispose()
		return true
	legacy.fault = "content_upgrade"
	rejected = legacy.upgrade_content(previous, prepare)
	check(rejected == null and int(legacy._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == count_before and legacy.active_state == previous, "injected after-publication failure rolls back the complete content upgrade transaction")
	legacy.fault = ""
	var upgraded: XJRuntimeState = legacy.upgrade_content(previous, prepare)
	if not check(upgraded != null, "real additive content upgrade publishes a complete new frozen snapshot: " + legacy.last_error): legacy.close(); return
	check(upgraded.world_id == previous_world and upgraded.player().credit == previous_credit and upgraded.snapshot.content.content_hash != previous_hash and upgraded.snapshot.content.content_snapshot_id != previous_content_id, "successful upgrade retains the world and credit while introducing a distinct reviewed content identity")
	check(legacy._records("SELECT slot_id,current_snapshot_id,content_snapshot_id,generation FROM save_slot WHERE slot_kind='manual' ORDER BY slot_id") == old_manual_slots, "successful upgrade preserves every old manual recovery slot")
	var previous_rows_preserved: bool = true
	for row: Dictionary in previous_cargo:
		var loaded: RefCounted = upgraded.find("inventory_stack_state", "stack_id", row.stack_id)
		previous_rows_preserved = previous_rows_preserved and loaded != null and Codec.new().encode_row("inventory_stack_state", loaded) == row
	for row: Dictionary in previous_assets:
		var loaded: RefCounted = upgraded.find("item_instance_state", "item_instance_id", row.item_instance_id)
		previous_rows_preserved = previous_rows_preserved and loaded != null and Codec.new().encode_row("item_instance_state", loaded) == row
	for row: Dictionary in previous_claims:
		var loaded: RefCounted = upgraded.find("mission_claim_state", "mission_instance_id", row.mission_instance_id)
		previous_rows_preserved = previous_rows_preserved and loaded != null and Codec.new().encode_row("mission_claim_state", loaded) == row
	check(previous_rows_preserved, "all existing cargo, equipment identity/policy and unique mission claims survive additive content upgrade")
	var old_definitions_preserved: bool = true
	for table: String in definitions_before:
		var next: Array[Dictionary] = legacy.catalog.rows(table)
		for row: Dictionary in definitions_before[table]: old_definitions_preserved = old_definitions_preserved and next.has(row)
	check(old_definitions_preserved, "every old definition remains equal inside the reviewed additive catalog")
	check(legacy._records("SELECT snapshot_id,world_id,content_snapshot_id,status,simulation_tick FROM save_snapshot WHERE snapshot_id=?", [previous_snapshot]).size() == 1 and legacy._records("SELECT status FROM save_snapshot WHERE snapshot_id=?", [previous_snapshot])[0].status == "sealed", "upgraded lineage retains the actual old sealed parent endpoint")
	check(legacy._records("SELECT parent_snapshot_id FROM snapshot_lineage WHERE child_snapshot_id=?", [upgraded.snapshot.meta.snapshot_id])[0].parent_snapshot_id == previous_snapshot, "new snapshot has explicit lineage back to its historical parent")
	check(legacy._records("SELECT count(*) AS n FROM content_upgrade_record WHERE world_id=?", [previous_world])[0].n == 1, "failed upgrades leave no receipt and the successful upgrade records exactly once")
	var first_backup: String = source_backup_check(previous_world, previous_snapshot)
	var new_hash: String = upgraded.snapshot.content.content_hash
	legacy.close()
	legacy = FaultStore.new(target)
	if check(legacy.open(), "upgraded actual old archive reopens"):
		var resumed: XJRuntimeState = legacy.resume()
		check(resumed != null and resumed.world_id == previous_world and resumed.player().credit == previous_credit and resumed.snapshot.content.content_hash == new_hash, "resume selects the upgraded endpoint after complete database close")
		if not old_manual_slots.is_empty():
			var old_slot: Dictionary = old_manual_slots[0]
			var recovered: XJRuntimeState = legacy.load(str(old_slot.slot_id), str(old_slot.current_snapshot_id), int(old_slot.generation))
			check(recovered != null and recovered.snapshot.content.content_hash == previous_hash and not legacy.catalog.table_names.has("encounter_defs"), "historical manual slot still recovers its original frozen rules")
			if recovered != null and check(legacy.save(recovered, "auto", 2), "independent old-content recovery can seal another test-owned source endpoint"):
				var second_source: String = recovered.snapshot.meta.snapshot_id
				var first_backup_hash: String = FileAccess.get_sha256(first_backup) if not first_backup.is_empty() else ""
				var second_prepare: Callable = func(candidate: XJRuntimeState) -> bool:
					var service: Gameplay = Gameplay.new()
					service.setup(candidate, legacy.staging_catalog); service.dispose()
					return true
				var branch: XJRuntimeState = legacy.upgrade_content(recovered, second_prepare)
				if check(branch != null, "second sealed source upgrades independently through the same reviewed frozen catalog"):
					var second_backup: String = source_backup_check(recovered.world_id, second_source)
					check(second_source != previous_snapshot and second_backup != first_backup and not first_backup.is_empty() and FileAccess.get_sha256(first_backup) == first_backup_hash, "a later source snapshot creates its own backup and preserves the earlier backup byte-for-byte")
					check(legacy._records("SELECT slot_id,current_snapshot_id,content_snapshot_id,generation FROM save_slot WHERE slot_kind='manual' ORDER BY slot_id") == old_manual_slots, "multiple source upgrades leave all historical manual recovery endpoints intact")
		check(legacy._records("PRAGMA integrity_check")[0].values()[0] == "ok" and legacy._records("PRAGMA foreign_key_check").is_empty(), "old and upgraded sealed branches retain physical and relational integrity")
	legacy.close()
	check(FileAccess.get_sha256(source) == source_hash, "original actual v0.8.4 evidence file remains byte-identical")
