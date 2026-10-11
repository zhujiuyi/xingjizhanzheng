extends "civilization_world_v24.gd"
## Real Main/renderer/input; qualification, return poses and near-time boundaries are explicit fixtures.
var belt_warnings: int = 0
var routes_completed: int = 0
func _ready() -> void:
	get_tree().set_meta("xj_mobile_belts_world_v28_diagnostic", true)
	get_tree().create_timer(540.0).timeout.connect(func(): check(false, "mobile belt native watchdog"); finish())
	run.call_deferred()
func run_for(seconds: float) -> void:
	host.set_process(true); host.set_physics_process(true)
	await get_tree().create_timer(seconds).timeout
	host.set_process(false); host.set_physics_process(false); host._process(0.0)
func connect_warnings() -> void:
	host.gameplay.exploration.warning_changed.connect(func(message: String):
		if message.begins_with("矿带"): belt_warnings += 1)
func collected() -> int:
	var count: int = 0
	for kind: int in [T.ContainerKind.MINERAL, T.ContainerKind.CARGO]: count += host.gameplay.inventory.count(host.gameplay.inventory.hold(host.state.ship(), kind), "ore_echo_silica", true)
	return count
func prepare() -> bool:
	var candidate: XJRuntimeState = host.store.clone_state(host.state)
	var g: Gameplay = Gameplay.new(); g.setup(candidate, host.store.catalog)
	for unlock: Dictionary in g.rows("unlock_defs"): g.grant_unlock(unlock.unlock_id)
	var hull: RefCounted = g.inventory.create_ship("miner_anvil", "station_anchor_port")
	candidate.player().controlled_ship_id = hull.ship_instance_id; candidate.player().credit = 1000000
	var home: Dictionary = g.definition("station_defs", "station_id", "station_anchor_port")
	place(candidate, g, home.station_anchor_id, home.station_id)
	var module_id: String = ""
	for row: Dictionary in g.rows("mining_compatibility"):
		if row.item_id == "ore_echo_silica": module_id = row.module_id; break
	var item: String = g.inventory.grant(g.inventory.warehouse(home.station_id), module_id, 1)[0]
	check(g.act("fit_module", item, 1, "work").phase == T.ActionPhase.APPLIED, "qualified native miner legally installs a rare-ore head")
	var event: RefCounted = g.exploration.instance("exp_echo_mineral")
	event.variant_id = event.event_id + "_v1"
	g.mobile_belts.instance(event.event_id).initial_units = int(g.exploration.variant(event).mineral_units)
	place(candidate, g, g.exploration.definition(event.event_id).entry_anchor_id); candidate.ship().pos_x -= 500.0
	g.dispose()
	if not await activate(candidate): return false
	connect_warnings(); return true
func run() -> void:
	directory = OS.get_environment("XJ_MOBILE_BELTS_WORLD_V28_DIRECTORY").replace("\\", "/")
	if not check(DisplayServer.get_name() != "headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/mobile-belts-world-v28/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "native belt suite uses fresh scoped world"): await finish(); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900)
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db"); root.add_child(host); await frames(5)
	await host._command("new_world", "迁移矿带原生验收", 1, ""); await settle()
	host.set_process(false); host.set_physics_process(false)
	if not await prepare(): await finish(); return
	for index: int in range(3):
		if index > 0:
			if not await departure_pose(): await finish(); return
			await actual_warp(index)
		await mine_cycle(index)
		await settle_claim_and_renew(index)
	check(routes_completed == 3, "three actual AU routes mined and renewed through real rules")
	await departure_pose()
	var event: RefCounted = host.gameplay.exploration.instance("exp_echo_mineral")
	event.phase = "failed"; event.outcome = "failed"; event.cooldown_remaining_s = 0.2
	var origin_site: String = host.gameplay.spatial_site("ship", host.state.ship().ship_instance_id)
	var position: Vector3 = host.world.flight.position
	host.ui.show_page(""); host.ui._select_target("explore:exp_echo_mineral"); host._process(0.0); await frames(5)
	await click(host.ui.overview.action_buttons["nav_warp"], "start warp toward the soon-to-migrate target")
	check(host.local_navigation.warp_active(), "real warp enters warmup before target migration")
	await run_for(0.8)
	check(host.local_navigation.phase == "failed" and host.gameplay.spatial_site("ship", host.state.ship().ship_instance_id) == origin_site and host.world.flight.position.distance_to(position) < 1.0, "in-flight target migration cancels safely at durable origin")
	await capture("belt-migrated-navigation-cancelled")
	root.size = Vector2i(1280, 720); root.content_scale_factor = 2.0
	host.ui.open_exploration("exp_echo_mineral"); await frames(5)
	var go: Button = host.ui.body.find_child("ExploreNavigate", true, false)
	await reveal(go)
	check(Rect2(Vector2.ZERO, host.ui.root.size).encloses(go.get_global_rect()), "200-percent route guidance remains reachable")
	await capture("belt-1280-200")
	check(host.store.save(host.state, "manual", 0), "actual native cargo routes and stages seal to SQLite")
	await finish()
func actual_warp(index: int) -> void:
	var event: RefCounted = host.gameplay.exploration.instance("exp_echo_mineral")
	var belt: RefCounted = host.gameplay.mobile_belts.instance(event.event_id)
	var expected: Dictionary = host.store.catalog.one("exploration_belt_route_defs", "route_id", belt.route_id)
	var site: String = host.store.catalog.one("anchor_site_defs", "anchor_id", expected.entry_anchor_id).site_id
	check(int(expected.route_index) == index and not host.world.target_is_local("explore:" + event.event_id) and host.world.target_distance("explore:" + event.event_id) > 10000000000.0, "new route is a real remote AU location")
	host.ui.open_exploration(event.event_id); await frames(5)
	await click(host.ui.body.find_child("ExploreNavigate", true, false), "actually navigate to next AU mineral route")
	host.set_process(true); host.set_physics_process(true)
	var deadline: int = Time.get_ticks_msec() + 60000
	while host.local_navigation.active() and Time.get_ticks_msec() < deadline: await frames(2)
	await settle(); host.set_process(false); host.set_physics_process(false)
	check(not host.local_navigation.active() and host.gameplay.spatial_site("ship", host.state.ship().ship_instance_id) == site and host.world.target_is_local("explore:" + event.event_id), "actual strategic warp reaches the migrated local space")
	await capture("belt-route-" + str(index) + "-arrival")
func mine_cycle(index: int) -> void:
	var event: RefCounted = host.gameplay.exploration.instance("exp_echo_mineral")
	host.ui.open_exploration(event.event_id); await frames(5)
	await click(host.ui.body.find_child("ExploreAction_survey", true, false), "pay survey on route " + str(index))
	host.set_process(true); host.set_physics_process(true)
	var deadline: int = Time.get_ticks_msec() + 26000
	while event.phase == "clue" and Time.get_ticks_msec() < deadline: await frames(2)
	host.set_process(false); host.set_physics_process(false)
	check(event.phase == "surveyed", "actual route survey completes")
	host.ui.open_exploration(event.event_id); await frames(5)
	await click(host.ui.body.find_child("ExploreAction_rich", true, false), "choose actual rare core mineral")
	await run_for(0.2)
	var node_id: String = "exp_echo_mineral_rich"
	check(host.world.targets.has(node_id) and host.world.target_site(node_id) == host.gameplay.spatial_site("ship", host.state.ship().ship_instance_id), "mineral collider belongs to current migrated space")
	for member: RefCounted in host.state.rows("exploration_actor_state"):
		if member.event_id == event.event_id: check(host.world.npcs.has(member.npc_instance_id) and host.world.target_site(member.npc_instance_id) == host.world.target_site(node_id), "real hostile body uses same route as mineral")
	host.ui.show_page(""); host.ui._select_target(node_id); host._process(0.0); await frames(5)
	await click(host.ui.overview.action_buttons["nav_approach"], "actually approach rare mineral")
	host.set_process(true); host.set_physics_process(true)
	deadline = Time.get_ticks_msec() + 25000
	while host.local_navigation.active() and Time.get_ticks_msec() < deadline: await frames(2)
	check(not host.local_navigation.active(), "actual local approach reaches rotated mineral geometry")
	await key(KEY_F)
	check(host.gameplay.work.mining_target == node_id, "real F begins compatible paid mining after migration")
	deadline = Time.get_ticks_msec() + 18000
	while event.evidence_units <= 0 and Time.get_ticks_msec() < deadline: await frames(2)
	check(event.evidence_units > 0 and collected() > 0, "real migrated mineral produces owned rare ore")
	await click(host.ui.work_stop, "stop the actual mining cycle")
	host.set_process(false); host.set_physics_process(false); await settle()
	var ore: int = collected(); var evidence: int = event.evidence_units
	var stage: Dictionary = host.store.catalog.one("exploration_belt_stage_defs", "stage_index", 1)
	event.elapsed_s = float(host.gameplay.exploration.variant(event).duration_s) * float(stage.threshold_bp) / 10000.0 - float(stage.warning_lead_s) - 0.1
	var warnings: int = belt_warnings
	await run_for(0.4)
	check(belt_warnings > warnings and host.gameplay.mobile_belts.detail(event.event_id).contains("预警"), "actual Main delivers early warning before dispersion")
	for definition: Dictionary in host.store.catalog.rows("exploration_belt_stage_defs"):
		event.elapsed_s = float(host.gameplay.exploration.variant(event).duration_s) * float(definition.threshold_bp) / 10000.0 - 0.1
		await run_for(0.4)
		var belt: RefCounted = host.gameplay.mobile_belts.instance(event.event_id)
		var cap: int = int(floor(float(belt.initial_units) * float(definition.remaining_cap_bp) / 10000.0))
		check(belt.stage_index == int(definition.stage_index) and host.state.find("resource_state", "node_id", node_id).remaining_units <= cap and collected() == ore and event.evidence_units == evidence, "actual Main dispersion preserves collected goods at stage " + str(definition.stage_index))
	host.ui.open_exploration(event.event_id); host.ui.refresh_page(); await frames(5)
	check(host.ui.body.find_child("ExploreStatus", true, false).text.contains("散逸阶段 3/3"), "route and decay status are readable without relying on effects")
	await capture("belt-route-" + str(index) + "-dispersion")
	event.elapsed_s = float(host.gameplay.exploration.variant(event).duration_s) - 0.2
	await run_for(0.6)
	check(event.phase == "ready" and event.outcome == "partial" and not host.world.targets.has(node_id) and collected() == ore, "real expiry removes mineral while keeping actual cargo and partial result")
	routes_completed += 1
func settle_claim_and_renew(index: int) -> void:
	var candidate: XJRuntimeState = host.store.clone_state(host.state)
	var g: Gameplay = Gameplay.new(); g.setup(candidate, host.store.catalog)
	var home: Dictionary = g.definition("station_defs", "station_id", "station_anchor_port")
	place(candidate, g, home.station_anchor_id, home.station_id); g.exploration.tick(0.1); g.dispose()
	if not await activate(candidate): return
	connect_warnings()
	host.ui.open_exploration("exp_echo_mineral"); await frames(5)
	await click(host.ui.body.find_child("ExploreAction_claim", true, false), "settle genuinely mined route result")
	var event: RefCounted = host.gameplay.exploration.instance("exp_echo_mineral")
	check(event.phase == "claimed", "actual UI claims one earned result")
	var previous_route: String = host.gameplay.mobile_belts.instance(event.event_id).route_id
	var position: Vector3 = host.gameplay.position(host.state.ship())
	event.cooldown_remaining_s = 0.1
	await run_for(0.4)
	check(event.phase == "clue" and host.gameplay.mobile_belts.instance(event.event_id).route_id != previous_route and host.gameplay.position(host.state.ship()) == position, "actual cooldown migration moves only the target and keeps player position")
	observations.append({"kind": "route", "index": index, "from": previous_route, "to": host.gameplay.mobile_belts.instance(event.event_id).route_id, "ore": collected()})
func departure_pose() -> bool:
	# Explicit already-arrived Echo station precondition, then a real AU flight to the belt.
	var candidate: XJRuntimeState = host.store.clone_state(host.state)
	var g: Gameplay = Gameplay.new(); g.setup(candidate, host.store.catalog)
	var station: Dictionary = host.store.catalog.rows("station_defs").filter(func(row: Dictionary) -> bool: return row.sector_id == "sector_echo")[0]
	place(candidate, g, station.station_anchor_id); candidate.ship().pos_x -= 2000.0
	g.dispose()
	if not await activate(candidate): return false
	connect_warnings(); return true
func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null; await frames(5); await get_tree().create_timer(0.25).timeout
	var result: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "routes": routes_completed, "directory": directory, "observations": observations}
	print("MOBILE_BELTS_WORLD_V28_FINAL_JSON ", JSON.stringify(result)); print("MOBILE_BELTS_WORLD_V28_RESULT ", result.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
