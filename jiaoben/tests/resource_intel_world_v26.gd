extends "civilization_world_v24.gd"
## Real window entry, source navigation and readonly UI. Supplies/unlocks are explicit fixtures.
var source_focus_sink: Window
var background_focus_observations: Array[Dictionary] = []

func source_focus_observation(stage: String) -> Dictionary:
	var sink_valid: bool = is_instance_valid(source_focus_sink)
	return {"stage":stage, "tick_ms":Time.get_ticks_msec(), "root_focus":root.has_focus(), "root_window_id":root.get_window_id(), "sink_focus":source_focus_sink.has_focus() if sink_valid else false, "sink_window_id":source_focus_sink.get_window_id() if sink_valid else -1, "sink_native":not source_focus_sink.is_embedded() if sink_valid else false, "sector":host.state.current_sector() if is_instance_valid(host) and host.state != null else "", "page":host.ui.page if is_instance_valid(host) and host.ui != null else "", "navigation_phase":host.local_navigation.phase if is_instance_valid(host) and host.local_navigation != null else "", "navigation_target":host.local_navigation.target_id if is_instance_valid(host) and host.local_navigation != null else ""}

func acquire_background_focus_fixture() -> bool:
	# Official Window.force_native must be set while hidden. A separate native
	# window creates OS focus loss, rather than merely moving Control focus.
	source_focus_sink = Window.new()
	source_focus_sink.hide()
	source_focus_sink.force_native = true
	source_focus_sink.transient = false
	source_focus_sink.exclusive = false
	source_focus_sink.title = "Source navigation native focus fixture"
	source_focus_sink.size = Vector2i(360, 100)
	source_focus_sink.position = root.position + Vector2i(24, 24)
	var caption := Label.new()
	caption.text = "Background navigation focus boundary\nTest-owned window; no player input"
	caption.position = Vector2(12, 12)
	source_focus_sink.add_child(caption)
	root.add_child(source_focus_sink)
	source_focus_sink.show()
	source_focus_sink.grab_focus()
	var deadline: int = Time.get_ticks_msec() + 10000
	var stable: int = 0
	while stable < 3 and Time.get_ticks_msec() < deadline and not finishing:
		await frames(1)
		if finishing: return false
		stable = stable + 1 if source_focus_sink.has_focus() and not root.has_focus() else 0
	if finishing: return false
	var observation: Dictionary = source_focus_observation("background_focus_acquired")
	observation["stable_frames"] = stable
	background_focus_observations.append(observation)
	print("SOURCE_BACKGROUND_FOCUS ", JSON.stringify(observation))
	return check(source_focus_sink.force_native and not source_focus_sink.is_embedded() and source_focus_sink.get_window_id() != root.get_window_id() and source_focus_sink.has_focus() and not root.has_focus() and stable == 3, "declared independent native window really removes main-window focus")

func release_background_focus_fixture() -> void:
	if not is_instance_valid(source_focus_sink): return
	source_focus_sink.hide()
	source_focus_sink.queue_free()
	source_focus_sink = null
	await frames(3)
	root.grab_focus()
	var deadline: int = Time.get_ticks_msec() + 10000
	var stable: int = 0
	while stable < 3 and Time.get_ticks_msec() < deadline:
		await frames(1)
		stable = stable + 1 if root.has_focus() else 0
	background_focus_observations.append(source_focus_observation("background_fixture_released"))
	check(root.has_focus() and stable == 3, "native focus fixture is destroyed and main window regains stable focus")

func reject_unfocused_explicit_navigation(target_id: String, accepted_goal: Dictionary) -> void:
	var context: Dictionary = host.navigation_context(target_id)
	if not check(source_writer_idle() and not host._exit_save_pending() and host.state.ship().status == T.ShipStatus.FLYING and not host.travel.active() and not host.local_navigation.active() and not host.local_navigation.warp_active() and host.ui.page.is_empty() and not host.ui.command_input_blocked() and not root.has_focus() and source_focus_sink.has_focus() and bool(context.get("approach_ready", false)), "unfocused explicit-navigation negative uses idle writer and actually qualified destination"): return
	var actions: Array[String] = ["nav_approach"]
	if bool(context.get("orbit_ready", false)): actions.append("nav_orbit")
	for action: String in actions:
		var pose: Transform3D = host.world.flight.global_transform
		var velocity: Vector3 = host.world.flight.velocity
		var generation: int = host.navigation_generation
		var phase: String = host.local_navigation.phase
		var mode: String = host.local_navigation.mode
		var previous_target: String = host.local_navigation.target_id
		await host._command(action, target_id, 1, "")
		await frames(2)
		var unchanged: bool = not root.has_focus() and source_focus_sink.has_focus() and host.navigation_generation == generation and host.local_navigation.phase == phase and host.local_navigation.mode == mode and host.local_navigation.target_id == previous_target and host.world.flight.global_transform.is_equal_approx(pose) and host.world.flight.velocity.is_equal_approx(velocity) and host.source_goal == accepted_goal
		var observation: Dictionary = source_focus_observation("unfocused_explicit_command")
		observation.merge({"action":action, "eligible":bool(context.get(action.trim_prefix("nav_") + "_ready", false)), "unchanged":unchanged, "goal_preserved":host.source_goal == accepted_goal, "generation_before":generation, "generation_after":host.navigation_generation})
		background_focus_observations.append(observation)
		print("SOURCE_BACKGROUND_EXPLICIT ", JSON.stringify(observation))
		check(unchanged, "unfocused explicit " + action + " cannot replace pose phase or the accepted source goal")

func source_writer_idle() -> bool:
	return is_instance_valid(host) and not host.busy and host.loading_job == null and (host.ui == null or not host.ui.loading_suspended)

func settle() -> void:
	# Arrival emits a deferred save. Several quiet frames include that boundary;
	# local_navigation.active=false alone does not mean the writer has finished.
	var deadline: int = Time.get_ticks_msec() + 60000
	var stable_frames: int = 0
	while is_instance_valid(host) and stable_frames < 3 and Time.get_ticks_msec() < deadline:
		await frames(1)
		stable_frames = stable_frames + 1 if source_writer_idle() else 0
	check(source_writer_idle() and stable_frames == 3, "source navigation waits for busy job and loading suspension to clear")
	if source_writer_idle(): host._process(0.0)

func source_popup_key(code: Key, popup: PopupMenu) -> void:
	for down: bool in [true, false]:
		# A PopupMenu is a Window. Route through the native window dispatcher even
		# for embedded popups; viewport.push_input bypasses this routing contract.
		# Enter may dispose the old menu before key-up, which then targets root.
		var target_window: Window = popup if is_instance_valid(popup) else root
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = down
		event.window_id = target_window.get_window_id()
		Input.parse_input_event(event)
		await frames(1)
	await frames(2)

func reopen_sources_from_chart() -> bool:
	var menu: MenuButton = host.ui.panel.find_child("RelatedNavigation", true, false) as MenuButton
	if not check(menu != null, "star chart exposes its actual related navigation menu"): return false
	var popup: PopupMenu = menu.get_popup()
	var wanted: int = -1
	for index: int in range(popup.item_count):
		if str(popup.get_item_metadata(index)) == "sources" and not popup.is_item_disabled(index): wanted = index; break
	if not check(wanted >= 0, "actual related menu offers the eligible resource intelligence destination"): return false
	var wanted_id: int = popup.get_item_id(wanted)
	if not await click(menu, "reopen sources through star chart"): return false
	if not check(popup.visible, "native related popup opens from the actual pointer press"): return false
	for step: int in range(popup.item_count + 1):
		if popup.get_focused_item() == wanted: break
		await source_popup_key(KEY_DOWN, popup)
	if not check(popup.get_focused_item() == wanted, "native popup keyboard focuses the exact resource intelligence item"): return false
	var selections: Array[int] = []
	popup.id_pressed.connect(func(id: int): selections.append(id), CONNECT_ONE_SHOT)
	await source_popup_key(KEY_ENTER, popup)
	await settle()
	return check(selections == [wanted_id], "native popup Enter submits exactly one resource intelligence selection")

func _ready() -> void:
	get_tree().set_meta("xj_resource_intel_world_v26_diagnostic", true)
	get_tree().create_timer(180.0).timeout.connect(func(): check(false, "source native watchdog"); finish())
	run.call_deferred()

func run() -> void:
	directory = OS.get_environment("XJ_RESOURCE_INTEL_WORLD_V26_DIRECTORY").replace("\\", "/")
	if not check(DisplayServer.get_name() != "headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/resource-intel-world-v26/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "native sources require fresh scoped data"):
		await finish(); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900)
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db"); root.add_child(host)
	await frames(5)
	if not check(host.services_ready, "actual Main starts resource rules"): await finish(); return
	await host._command("new_world", "物资来源原生验收", 1, ""); await settle()
	if not check(host.state != null, "actual client creates source-intelligence world"): await finish(); return
	host.set_process(false); host.set_physics_process(false)
	for def: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.grant_unlock(def.unlock_id)
	await show("industry")
	var before: String = state_signature()
	var source_button: Button
	for quote: Dictionary in host.ui.quotes:
		if quote.action == "manufacture": source_button = host.ui.body.find_child("RecipeSources_" + str(quote.target), true, false); break
	if not await click(source_button, "open actual recipe material sources"): await finish(); return
	check(host.ui.page == "sources" and host.ui.body.find_child("SourceItem", true, false) != null, "recipe opens real source picker")
	check(state_signature() == before, "opening sources writes no assets progress or RNG")
	await capture("sources-from-recipe")
	var search: LineEdit = host.ui.body.find_child("SourceSearch", true, false)
	await click(search, "search real material name")
	search.select_all()
	var name: String = host.store.catalog.one("item_defs", "item_id", "ore_ferrosilicate").display_name
	for character: String in name:
		var input: InputEventKey = InputEventKey.new(); input.unicode = character.unicode_at(0); input.pressed = true; root.push_input(input, true)
	await key(KEY_ENTER)
	check(host.ui.source_item_id == "ore_ferrosilicate", "actual keyboard search selects ore by database name")
	check(state_signature() == before, "source search preserves all authoritative state")
	var node: Dictionary = {}
	await click(host.ui.body.find_child("SourceFilter_采矿", true, false), "filter real extraction sources")
	for row: Dictionary in host.gameplay.resource_intel.sources("ore_ferrosilicate"):
		if row.kind == "采矿" and int(row.hops) == 1 and row.route_open: node = host.store.catalog.one("resource_node_defs", "node_id", row.id); break
	if not check(not node.is_empty(), "authored ore point is reachable through one actual gate"): await finish(); return
	var key_name: String = "node:" + str(node.node_id)
	var suffix: String = key_name.validate_node_name()
	var go: Button = host.ui.body.find_child("SourceTravel_" + suffix, true, false)
	check(go != null and go.disabled, "docked ship sees explicit departure prerequisite")
	await capture("sources-ore")
	await click(host.ui.body.find_child("SourceMap_" + suffix, true, false), "locate actual source on star chart")
	check(host.ui.page == "map" and host.ui.resource_chart.selected_sector == node.sector_id, "source map resolves correct actual sector")
	check(host.ui.resource_chart.information.text.contains("定位：") and host.ui.resource_chart.information.text.contains("活动："), "actual star chart explains sector roles")
	check(state_signature() == before, "star-chart source inspection is readonly")
	await capture("sources-map")
	if not await reopen_sources_from_chart(): await finish(); return
	check(host.ui.page == "sources", "map supports sources without another station menu entry")
	check(state_signature() == before, "related source navigation writes no assets progress or RNG")
	await click(host.ui.body.find_child("SourceFilter_采矿", true, false), "retain extraction navigation scope")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(3440, 1370)]:
		root.size = size; root.content_scale_factor = 2.0 if size.x == 1280 else 1.0
		await show("sources")
		var map_button: Button = host.ui.body.find_child("SourceMap_" + suffix, true, false)
		await reveal(map_button)
		check(Rect2(Vector2.ZERO, host.ui.root.size).encloses(map_button.get_global_rect()), "source operation reachable at " + str(size))
		# The origin is carried by the single return control now: it names where it
		# goes. The label shortens on narrow headers, the tooltip always spells it out.
		var close: Button = host.ui.panel.find_child("PanelClose", true, false) as Button
		check(close != null and close.tooltip_text.contains("星域航路") and (close.text.contains("星域航路") or close.text == "←"), "source detail keeps its star-chart origin as the return destination " + str(size))
		await capture("sources-" + str(size.x))
	root.size = Vector2i(1440, 900); root.content_scale_factor = 1.0
	await host._command("undock", "", 1, ""); await settle()
	check(host.state.ship().status == T.ShipStatus.FLYING, "actual departure before navigation")
	await show("sources")
	go = host.ui.body.find_child("SourceTravel_" + suffix, true, false)
	var info: Dictionary = host.gameplay.resource_intel.guidance(key_name, "ore_ferrosilicate")
	if not await click(go, "navigate to real local ore source"): await finish(); return
	check(host.local_navigation.active() and host.local_navigation.target_id == info.waypoint_id and host.source_goal.key == key_name, "source request navigates to actual next-hop gate")
	var amount: int = host.state.find("resource_state", "node_id", node.node_id).remaining_units
	host.set_process(true); host.set_physics_process(true)
	var observation_boundary_seen: bool=false
	var deadline: int = Time.get_ticks_msec() + 35000
	while host.local_navigation.active() and Time.get_ticks_msec() < deadline:
		await frames(2)
		if host.local_navigation.warp_active() and not host.gameplay.situational.spatial_active:observation_boundary_seen=true
	check(not host.local_navigation.active() and host.ui.target_id == info.waypoint_id, "real navigation reaches the selected transit gate")
	await settle()
	# A long autonomous transit can outlive the runner's initial activation.
	# Obtain actual native focus before injecting the one deliberate F press;
	# retain Main's production focus guard and every gate eligibility check.
	if DisplayServer.get_name() != "headless":
		var focus_before: bool = root.has_focus()
		root.grab_focus()
		var focus_deadline: int = Time.get_ticks_msec() + 10000
		var focus_frames: int = 0
		while focus_frames < 3 and Time.get_ticks_msec() < focus_deadline:
			await frames(1)
			focus_frames = focus_frames + 1 if root.has_focus() else 0
		print("SOURCE_NATIVE_FOCUS ", JSON.stringify({"before":focus_before, "after":root.has_focus(), "stable_frames":focus_frames}))
		if not check(root.has_focus() and focus_frames == 3, "actual native source window has stable focus before deliberate gate input"): await finish(); return
	host.get_viewport().warp_mouse(root.get_visible_rect().get_center())
	var gate_context: Dictionary = host.interaction_context()
	print("SOURCE_INPUT_CONTEXT ",JSON.stringify({"focus":root.has_focus(),"busy":host.busy,"loading_job":host.loading_job!=null,"loading_suspended":host.ui.loading_suspended,"page":host.ui.page,"keyboard_blocked":host.ui.keyboard_blocked(),"travel":host.travel.active(),"warp":host.local_navigation.warp_active(),"interaction":gate_context}))
	if not check(source_writer_idle() and host.deferred_save.is_empty() and host._keyboard_control_allowed() and bool(gate_context.get("ready",false)) and str(gate_context.get("target_id","")) == str(info.waypoint_id), "single actual F input is sent only after committed arrival and real gate eligibility"):
		await finish(); return
	await key(KEY_F)
	var accepted_goal: Dictionary = host.source_goal.duplicate(true)
	var crossing: XJTravel = host.travel
	if not check(crossing.active() and accepted_goal.get("key", "") == key_name, "single actual F starts the accepted gate transfer before focus-boundary fixture"):
		await finish(); return
	var background: Dictionary = {"committed":false, "commit_background":false, "generation_at_commit":-1, "continuation_started":false, "focus_held":true}
	crossing.changed.connect(func(phase: int, _message: String):
		if phase != T.TravelPhase.COMMITTED: return
		background.committed = true
		background.commit_background = not root.has_focus() and is_instance_valid(source_focus_sink) and source_focus_sink.has_focus()
		background.generation_at_commit = host.navigation_generation
		var observed: Dictionary = source_focus_observation("actual_gate_committed")
		observed["accepted_goal_preserved"] = host.source_goal == accepted_goal
		background_focus_observations.append(observed)
		print("SOURCE_BACKGROUND_COMMIT ", JSON.stringify(observed)))
	if not await acquire_background_focus_fixture(): await finish(); return
	deadline = Time.get_ticks_msec() + 50000
	var location: Dictionary = host.store.catalog.one("resource_node_locations", "node_id", node.node_id)
	while Time.get_ticks_msec() < deadline and not finishing:
		background.focus_held = bool(background.focus_held) and not root.has_focus() and source_focus_sink.has_focus()
		if bool(background.committed) and host.state.current_sector() == node.sector_id and host.local_navigation.active() and host.navigation_generation > int(background.generation_at_commit):
			var continuation: Dictionary = host.gameplay.resource_intel.guidance(key_name, "ore_ferrosilicate")
			if host.local_navigation.target_id == str(continuation.get("waypoint_id", "")): background.continuation_started = true
		if host.state.current_sector() == node.sector_id and host.gameplay.same_anchor_site(host.state.ship(), host.store.catalog.one("anchor_defs", "anchor_id", location.anchor_id)) and not host.local_navigation.active(): break
		await frames(2)
		if finishing: return
		if (host.local_navigation.warp_active() or host.travel.active()) and not host.gameplay.situational.spatial_active:observation_boundary_seen=true
	if finishing: return
	await settle()
	host.set_process(false); host.set_physics_process(false)
	var arrival_observation: Dictionary = source_focus_observation("background_source_arrival")
	arrival_observation.merge(background)
	arrival_observation["accepted_goal_preserved"] = host.source_goal == accepted_goal
	background_focus_observations.append(arrival_observation)
	print("SOURCE_BACKGROUND_ARRIVAL ", JSON.stringify(arrival_observation))
	check(bool(background.committed) and bool(background.commit_background), "actual gate commit occurs while the main native window is unfocused")
	check(bool(background.focus_held) and not root.has_focus() and source_focus_sink.has_focus(), "source continuation remains a real native-background boundary")
	check(bool(background.continuation_started) and host.source_goal == accepted_goal, "accepted source goal automatically starts its post-gate segment without a focus-dependent retry")
	check(host.state.current_sector() == node.sector_id, "actual F input crosses the planned star-system gate")
	check(host.gameplay.same_anchor_site(host.state.ship(), host.store.catalog.one("anchor_defs", "anchor_id", location.anchor_id)), "actual warp arrives in source's declared AU site")
	check(observation_boundary_seen,"actual strategic navigation suspends local resource observation")
	check(host.state.find("resource_state", "node_id", node.node_id).remaining_units == amount and host.gameplay.work.mining_target.is_empty(), "source arrival neither fabricates nor auto-mines goods")
	# Only after observing the independent continuation do explicit command probes
	# run. Never restore source_goal to disguise a rejected/cleared continuation.
	var destination: Dictionary = host.gameplay.resource_intel.guidance(key_name, "ore_ferrosilicate")
	await reject_unfocused_explicit_navigation(str(destination.get("waypoint_id", "")), accepted_goal)
	await release_background_focus_fixture()
	await capture("sources-arrived")
	await show("sources")
	var old_panel: Node = host.ui.body.find_child("SourceItem", true, false).get_parent().get_parent()
	var requests: Array = []
	var observer: Callable = func(action: String, target: String, quantity: int, extra: String): requests.append([action, target, quantity, extra])
	host.ui.requested.connect(observer)
	host.ui.show_page("map")
	old_panel.call("_request", "source_travel", key_name, "ore_ferrosilicate")
	check(requests.is_empty(), "obsolete source panel cannot send navigation in regenerated context")
	host.ui.requested.disconnect(observer)
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	# All early exits and the watchdog share this native-window cleanup path.
	await release_background_focus_fixture()
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(5); await get_tree().create_timer(0.25).timeout
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory, "background_focus_observations":background_focus_observations, "focus_fixture":"test-owned force_native Window after actual F; no direct source continuation or controller start; explicit commands probed only after the background arrival observation"}
	print("RESOURCE_INTEL_WORLD_V26_FINAL_JSON ", JSON.stringify(summary))
	print("RESOURCE_INTEL_WORLD_V26_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
