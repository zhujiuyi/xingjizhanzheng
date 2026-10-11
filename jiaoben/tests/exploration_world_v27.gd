extends "civilization_world_v24.gd"
## Physical transport movement, accepted NPC hits, actual cover and environment effects.
var escort_id: String = ""
var escort_hits: int = 0
var escort_moved_m: float = 0.0

func _ready() -> void:
	get_tree().set_meta("xj_exploration_world_v27_diagnostic", true)
	get_tree().create_timer(360.0).timeout.connect(func(): check(false, "exploration native watchdog"); finish())
	run.call_deferred()

func qualify(event_id: String, hull_id: String = "battleship_forge_ironwall") -> bool:
	var candidate: XJRuntimeState = host.store.clone_state(host.state)
	var business: Gameplay = Gameplay.new(); business.setup(candidate, host.store.catalog)
	for unlock: Dictionary in host.store.catalog.rows("unlock_defs"): business.grant_unlock(unlock.unlock_id)
	var hull: D.ShipStateDto = business.inventory.create_ship(hull_id, "station_anchor_port")
	candidate.player().controlled_ship_id = hull.ship_instance_id; candidate.player().credit = 1000000
	if hull_id == "miner_anvil":
		var home: Dictionary = business.definition("station_defs", "station_id", "station_anchor_port")
		place(candidate, business, home.station_anchor_id, home.station_id)
		var module_id: String = ""
		for compatible: Dictionary in business.rows("mining_compatibility"):
			if compatible.item_id == "ore_ferrosilicate": module_id = compatible.module_id; break
		var item: String = business.inventory.grant(business.inventory.warehouse(home.station_id), module_id, 1)[0]
		check(business.act("fit_module", item, 1, "work").phase == T.ActionPhase.APPLIED, "explicit qualified miner receives a legal compatible mining head")
	var event: D.ExplorationInstanceStateDto = business.exploration.instance(event_id)
	event.variant_id = event_id + "_v1" # Named easier variant is an explicit test precondition.
	var spec: Dictionary = business.exploration.definition(event_id)
	place(candidate, business, spec.entry_anchor_id)
	candidate.ship().pos_x -= 500.0
	business.inventory.grant(business.inventory.hold(hull, T.ContainerKind.CARGO), "material_structural_stock", 40)
	business.dispose()
	return await activate(candidate)

func run() -> void:
	directory = OS.get_environment("XJ_EXPLORATION_WORLD_V27_DIRECTORY").replace("\\", "/")
	if not check(DisplayServer.get_name() != "headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/exploration-world-v27/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "real renderer and scoped fresh world"):
		await finish(); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900)
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db"); root.add_child(host); await frames(5)
	if not check(host.services_ready, "actual exploration client starts"): await finish(); return
	await host._command("new_world", "真实护送与环境", 1, ""); await settle()
	if not check(host.state != null, "actual event world creates"): await finish(); return
	host.set_process(false); host.set_physics_process(false)
	if not await qualify("exp_echo_rescue"): await finish(); return
	host.ui._select_target("explore:exp_echo_rescue"); host._process(0.0)
	check(host.local_navigation.inspect("explore:exp_echo_rescue").approach_ready, "new exploration target participates in real navigation rules")
	await click(host.ui.overview.action_buttons["nav_approach"], "actually approach an exploration signal")
	host.set_process(true); host.set_physics_process(true)
	var navigation_deadline: int = Time.get_ticks_msec() + 40000
	while host.local_navigation.active() and Time.get_ticks_msec() < navigation_deadline: await frames(2)
	check(not host.local_navigation.active() and host.world.target_distance("explore:exp_echo_rescue") < 200.0, "physical approach reaches the event instead of treating it as remote scenery")
	await settle(); host.set_process(false); host.set_physics_process(false)
	await key(KEY_F)
	check(host.ui.page == "exploration" and host.ui.exploration_selected == "exp_echo_rescue", "real F opens selected local exploration")
	await capture("exploration-clue")
	await click(host.ui.body.find_child("ExploreAction_survey", true, false), "pay actual exploration survey")
	var event: D.ExplorationInstanceStateDto = host.gameplay.exploration.instance("exp_echo_rescue")
	check(event.operation_kind == "survey", "native survey starts a paid persisted operation")
	host.set_process(true); host.set_physics_process(true)
	var deadline: int = Time.get_ticks_msec() + 25000
	while event.phase == "clue" and Time.get_ticks_msec() < deadline: await frames(2)
	await get_tree().physics_frame; await get_tree().physics_frame
	host.set_process(false); host.set_physics_process(false)
	check(event.phase == "surveyed", "real fixed-step survey completes")
	for member: D.ExplorationActorStateDto in host.state.rows("exploration_actor_state"):
		if member.event_id == event.event_id and member.actor_role == "escort": escort_id = member.npc_instance_id; break
	if not check(not escort_id.is_empty() and host.world.npcs.has(escort_id), "actual friendly transport model appears"): await finish(); return
	check(host.world.targets[escort_id].friendly and not host.gameplay.civilizations.hostile_to(host.state.ship().ship_instance_id, escort_id), "escort is a real protected friendly target")
	await capture("exploration-decision")
	var obstacle: Dictionary
	for row: Dictionary in host.store.catalog.rows("exploration_obstacle_defs"):
		if row.event_id == event.event_id: obstacle = row; break
	var center: Vector3 = host.world.anchor_position(obstacle.anchor_id)
	var from: Vector3 = center - Vector3(float(obstacle.radius_m) + 100.0, 0, 0)
	var to: Vector3 = center + Vector3(float(obstacle.radius_m) + 100.0, 0, 0)
	check(not host.world.line_of_sight(from, to, host.world.flight.get_rid(), ""), "actual debris collider blocks a real physics ray")
	host.world.projectiles.hit.connect(func(target_id: String, _damage: Vector3, _point: Vector3, _owner: String):
		if target_id == escort_id: escort_hits += 1)
	await click(host.ui.body.find_child("ExploreAction_rescue", true, false), "spend structure to repair and escort")
	check(event.phase == "rescue", "native rescue creates an actual escort objective")
	var escort: D.NpcStateDto = host.state.find("npc_state", "npc_instance_id", escort_id)
	var start: Vector3 = host.gameplay.position(escort)
	host.set_process(true); host.set_physics_process(true)
	deadline = Time.get_ticks_msec() + 25000
	while not event.stabilized and event.phase == "rescue" and Time.get_ticks_msec() < deadline: await frames(2)
	check(event.stabilized, "real paid repair finishes before transport movement")
	host.ui.show_page(""); host.ui._select_target(escort_id); host._process(0.0); await frames(5)
	var orbit: Button = host.ui.overview.action_buttons["nav_orbit"]
	await click(orbit, "actual friendly orbit follows the moving escort")
	deadline = Time.get_ticks_msec() + 100000
	while event.phase == "rescue" and Time.get_ticks_msec() < deadline:
		await frames(2)
		if host.state.find("npc_state", "npc_instance_id", escort_id) != null: escort_moved_m = maxf(escort_moved_m, host.gameplay.position(escort).distance_to(start))
	host.set_process(false); host.set_physics_process(false)
	check(event.phase == "ready" and event.outcome == "full", "actual transport movement and player escort reach the real exit")
	check(escort_moved_m > 4000.0 and escort_hits > 0, "real escort travels kilometres and receives physical enemy projectiles")
	observations.append({"kind": "escort", "moved_m": escort_moved_m, "hits": escort_hits, "phase": event.phase, "outcome": event.outcome})
	await capture("exploration-escort-exit")
	var candidate: XJRuntimeState = host.store.clone_state(host.state)
	var business: Gameplay = Gameplay.new(); business.setup(candidate, host.store.catalog)
	var station: Dictionary = host.store.catalog.one("station_defs", "station_id", business.exploration.definition(event.event_id).station_id)
	place(candidate, business, station.station_anchor_id, station.station_id)
	business.exploration.tick(0.1); business.dispose()
	if not await activate(candidate): await finish(); return
	host.ui.open_exploration(event.event_id); host._process(0.0); await frames(5)
	await click(host.ui.body.find_child("ExploreAction_claim", true, false), "settle actual earned escort outcome")
	check(host.state.rows("exploration_claim_state").size() == 1 and host.state.rows("exploration_progress_state")[0].insight_available > 0, "native claim commits unique real evidence and credit")
	await capture("exploration-claimed")
	await electromagnetic()
	await temporary_mineral()
	if not await qualify("exp_forge_relic"): await finish(); return
	var solar: D.ExplorationInstanceStateDto = host.gameplay.exploration.instance("exp_forge_relic")
	var balance: Dictionary = host.gameplay.exploration.balance
	solar.hazard_clock_s = float(balance.hazard_period_s) - float(balance.hazard_active_s) - 0.5
	host.ui.open_exploration(solar.event_id); host._process(0.0); await frames(5)
	var total_hp: float = host.state.ship().shield + host.state.ship().armor + host.state.ship().hull
	host.set_process(true); host.set_physics_process(true)
	await get_tree().create_timer(1.3).timeout
	host.set_process(false); host.set_physics_process(false)
	check(host.state.ship().shield + host.state.ship().armor + host.state.ship().hull < total_hp, "actual solar phase deals bounded thermal damage within radius")
	check(host.gameplay.exploration.environment().message.contains("热伤害"), "environment warning is readable independently of effects")
	await capture("exploration-solar-warning")
	root.size = Vector2i(1280, 720); root.content_scale_factor = 2.0
	await show("exploration")
	var map_button: Button = host.ui.body.find_child("ExploreMap", true, false)
	await reveal(map_button)
	check(Rect2(Vector2.ZERO, host.ui.root.size).encloses(map_button.get_global_rect()), "high-scale exploration navigation remains accessible")
	await capture("exploration-1280-200")
	check(host.store.save(host.state, "manual", 0), "actual environment clock and outcome persist to SQLite")
	await finish()

func electromagnetic() -> void:
	if not await qualify("exp_mirror_relic"): return
	var event: D.ExplorationInstanceStateDto = host.gameplay.exploration.instance("exp_mirror_relic")
	host.preferences.vfx_intensity = 0.0; host._apply_preferences()
	host.ui.open_exploration(event.event_id); host._process(0.0); await frames(4)
	host.state.ship().shield = 0.0; host.state.ship().shield_delay_remaining_s = 0.0
	await click(host.ui.body.find_child("ExploreAction_survey", true, false), "survey inside an actual electromagnetic region")
	var remaining: float = event.operation_remaining_s
	var shield: float = host.state.ship().shield
	var clock: float = event.hazard_clock_s
	var recharge: float = float(host.gameplay.metrics(host.state.ship()).shield_recharge)
	host.set_process(true); host.set_physics_process(true)
	await get_tree().create_timer(1.2).timeout
	host.set_process(false); host.set_physics_process(false)
	var elapsed: float = event.hazard_clock_s - clock
	check(elapsed > 0.5 and is_equal_approx(remaining - event.operation_remaining_s, elapsed * float(host.gameplay.exploration.balance.em_scan_multiplier)), "actual Main scan work is slowed by the electromagnetic field")
	check(absf(host.state.ship().shield - shield - elapsed * recharge * float(host.gameplay.exploration.balance.em_shield_multiplier)) < 0.1, "actual Main shield recharge consumes the electromagnetic multiplier")
	check(host.ui.body.find_child("ExploreStatus", true, false).text.contains("电磁扰动"), "environment remains readable with visual intensity zero")
	await capture("exploration-electromagnetic")
	host.set_process(true); host.set_physics_process(true)
	var deadline: int = Time.get_ticks_msec() + 30000
	while event.phase == "clue" and Time.get_ticks_msec() < deadline: await frames(2)
	host.set_process(false); host.set_physics_process(false)
	check(event.phase == "surveyed", "real slower survey completes without skipping work")
	host.ui.open_exploration(event.event_id); host._process(0.0); await frames(5)
	var cargo: String = host.gameplay.inventory.hold(host.state.ship(), T.ContainerKind.CARGO)
	var structure: int = host.gameplay.inventory.count(cargo, "material_structural_stock", true)
	await click(host.ui.body.find_child("ExploreAction_stabilize", true, false), "pay real structure to stabilize electromagnetic risk")
	check(host.gameplay.inventory.count(cargo, "material_structural_stock", true) == structure - int(host.gameplay.exploration.variant(event).repair_units), "native stabilization consumes the displayed normal cargo material")
	check(event.operation_kind == "stabilize" and not host.gameplay.exploration.action_reason(event.event_id, "stabilize").is_empty(), "already paid stabilization rejects another payment")
	host.set_process(true); host.set_physics_process(true)
	deadline = Time.get_ticks_msec() + 20000
	while not event.stabilized and Time.get_ticks_msec() < deadline: await frames(2)
	host.set_process(false); host.set_physics_process(false)
	check(event.stabilized and is_equal_approx(float(host.gameplay.exploration.environment().scan), 1.0) and is_equal_approx(float(host.gameplay.exploration.environment().shield), 1.0), "paid stabilization restores real scan and shield rules")

func temporary_mineral() -> void:
	if not await qualify("exp_echo_mineral", "miner_anvil"): return
	var event: D.ExplorationInstanceStateDto = host.gameplay.exploration.instance("exp_echo_mineral")
	var node_id: String = ""
	for id: String in host.gameplay.exploration.managed_resources:
		if host.gameplay.exploration.managed_resources[id].event_id == event.event_id and host.gameplay.exploration.managed_resources[id].choice_id == "safe": node_id = id; break
	check(not host.world.targets.has(node_id), "inactive temporary ore is absent from the actual world")
	host.ui.open_exploration(event.event_id); host._process(0.0); await frames(4)
	await click(host.ui.body.find_child("ExploreAction_survey", true, false), "survey the actual temporary mineral belt")
	host.set_process(true); host.set_physics_process(true)
	var deadline: int = Time.get_ticks_msec() + 22000
	while event.phase == "clue" and Time.get_ticks_msec() < deadline: await frames(2)
	host.set_process(false); host.set_physics_process(false)
	check(event.phase == "surveyed", "actual mineral clue reveals safe and rich choices")
	host.ui.open_exploration(event.event_id); host._process(0.0); await frames(5)
	await click(host.ui.body.find_child("ExploreAction_safe", true, false), "open selected safe mineral node")
	host.set_process(true); host.set_physics_process(true)
	await get_tree().physics_frame; await get_tree().physics_frame
	host.set_process(false); host.set_physics_process(false); host._process(0.0); await frames(4)
	check(host.world.targets.has(node_id) and host.world.targets[node_id].node is StaticBody3D, "paid choice creates a real target and mineral collider")
	host.ui.show_page(""); host.ui._select_target(node_id); host._process(0.0); await frames(4)
	await click(host.ui.overview.action_buttons["nav_approach"], "actually approach the temporary mineral body")
	host.set_process(true); host.set_physics_process(true)
	deadline = Time.get_ticks_msec() + 60000
	while host.local_navigation.active() and Time.get_ticks_msec() < deadline: await frames(2)
	check(not host.local_navigation.active(), "real local navigation reaches the temporary mineral")
	host._process(0.0); await key(KEY_F)
	check(host.gameplay.work.mining_target == node_id, "actual F starts compatible paid mining at the real node")
	deadline = Time.get_ticks_msec() + 20000
	while event.evidence_units <= 0 and event.phase == "mineral" and Time.get_ticks_msec() < deadline: await frames(2)
	host.set_process(false); host.set_physics_process(false)
	check(event.evidence_units > 0, "actual Main equipment cycle produces real ore and evidence")
	var resource: Dictionary = host.store.catalog.one("resource_node_defs", "node_id", node_id)
	var collected: int = 0
	for kind: int in [T.ContainerKind.MINERAL, T.ContainerKind.CARGO]: collected += host.gameplay.inventory.count(host.gameplay.inventory.hold(host.state.ship(), kind), resource.item_id, true)
	check(collected > 0 and host.state.find("resource_state", "node_id", node_id).remaining_units < int(host.gameplay.exploration.variant(event).mineral_units), "native mining transfers finite node units into actual owned mineral hold or cargo")
	await capture("exploration-temporary-mining")
	# Declared near-deadline fixture checks expiry cleanup under the real Main tick.
	event.elapsed_s = float(host.gameplay.exploration.variant(event).duration_s) - 0.2
	host.set_process(true); host.set_physics_process(true); await get_tree().create_timer(0.8).timeout
	host.set_process(false); host.set_physics_process(false); host._process(0.0); await frames(4)
	check(event.phase == "ready" and event.outcome == "partial" and not host.world.targets.has(node_id) and host.gameplay.work.mining_target.is_empty(), "expiry removes actual mineral geometry and paid mining while retaining partial evidence")

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(5); await get_tree().create_timer(0.25).timeout
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory, "observations": observations}
	print("EXPLORATION_WORLD_V27_FINAL_JSON ", JSON.stringify(summary)); print("EXPLORATION_WORLD_V27_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
