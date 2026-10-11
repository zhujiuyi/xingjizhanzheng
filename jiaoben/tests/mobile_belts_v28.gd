extends "exploration_v27.gd"
## Explicit equipment/arrival/near-phase fixtures; actual input and movement live in native suite.
var warning_count: int = 0
func _ready() -> void:
	get_tree().set_meta("xj_mobile_belts_v28_diagnostic", true)
	get_tree().create_timer(360.0).timeout.connect(func(): print("MOBILE_BELTS_V28_RESULT FAIL watchdog"); get_tree().quit(2))
	_run.call_deferred()
func connect_warnings() -> void:
	g.exploration.warning_changed.connect(func(message: String):
		if message.begins_with("矿带"): warning_count += 1)
func complete_fingerprint(value: XJRuntimeState, prior: bool = false) -> String:
	var result: Dictionary = {}
	for table: String in XJRuntimeState.TABLES:
		if prior and table == "exploration_belt_state": continue
		var rows: Array = []
		for row: RefCounted in value.rows(table): rows.append(Codec.new().encode_row(table, row))
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a) < JSON.stringify(b))
		result[table] = rows
	return JSON.stringify(result)
func cargo_units(item_id: String) -> int:
	return g.inventory.count(g.inventory.hold(state.ship(), T.ContainerKind.MINERAL), item_id, true) + g.inventory.count(g.inventory.hold(state.ship(), T.ContainerKind.CARGO), item_id, true)
func save_reload(slot_index: int) -> bool:
	g.missions.refresh(); g._sync_spawns()
	if not check(store.save(state, "manual", slot_index), "actual route/dispersion snapshot seals " + store.last_error): return false
	var before: String = complete_fingerprint(state)
	var slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind == "manual" and int(row.slot_index) == slot_index: slot = row; break
	g.dispose(); state = store.load(slot.slot_id); g = Gameplay.new(); g.setup(state, store.catalog); connect_warnings()
	return check(complete_fingerprint(state) == before, "all forty-eight state groups restore exactly")
func _run() -> void:
	directory = OS.get_environment("XJ_MOBILE_BELTS_V28_DIRECTORY").replace("\\", "/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/mobile-belts-v28/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "fresh scoped route fixture"): get_tree().quit(2); return
	store = Store.new(directory.path_join("progress.db"))
	if not check(store.open(), "format13 and all reviewed adapters open " + store.last_error): get_tree().quit(1); return
	state = store.new_world("移动矿带矩阵", 2801); g = Gameplay.new(); g.setup(state, store.catalog); connect_warnings()
	check(state.rows("exploration_belt_state").size() == 2, "both belts initialize without goods or extra RNG draws")
	for unlock: Dictionary in g.rows("unlock_defs"): g.grant_unlock(unlock.unlock_id)
	state.player().credit = 1000000
	var miner: RefCounted = g.inventory.create_ship("miner_anvil", g.station()); state.player().controlled_ship_id = miner.ship_instance_id
	for belt: RefCounted in state.rows("exploration_belt_state"):
		for route_index: int in range(3): await cycle(belt.event_id, route_index)
	check(cases == 6, "both events execute all three actual frozen routes")
	if not OS.get_environment("XJ_MOBILE_BELTS_LEGACY_DATABASE").is_empty(): legacy_mobile()
	await finish()
func cycle(event_id: String, route_index: int) -> void:
	var event: RefCounted = g.exploration.instance(event_id)
	var belt: RefCounted = g.mobile_belts.instance(event_id)
	var route: Dictionary = g.definition("exploration_belt_route_defs", "route_id", belt.route_id)
	check(int(route.route_index) == route_index and event.phase == "clue", "normal renewal selects next actual route " + str(route_index))
	var rule: Dictionary = g.exploration.definition(event_id)
	var spec: Dictionary = g.exploration.variant(event)
	var station: Dictionary = g.definition("station_defs", "station_id", rule.station_id)
	place(station.station_anchor_id, station.station_id)
	for equipment: RefCounted in g.equipped(state.ship()).duplicate(): g.act("unfit_module", equipment.item_instance_id)
	var choice: String = "rich" if route_index == 1 else "safe"
	var node_id: String = event_id + "_" + choice
	var ore: String = g.definition("resource_node_defs", "node_id", node_id).item_id
	var module_id: String = ""
	for compatible: Dictionary in g.rows("mining_compatibility"):
		if compatible.item_id == ore: module_id = compatible.module_id; break
	var item: String = g.inventory.grant(g.inventory.warehouse(g.station()), module_id, 1)[0]
	check(g.act("fit_module", item, 1, "work").phase == T.ActionPhase.APPLIED, "legally fit route-specific mining head")
	place(rule.entry_anchor_id)
	state.ship().energy = float(g.metrics(state.ship()).energy_max); state.ship().heat = 0.0; state.ship().overheated = false
	check(g.exploration.guidance(event_id).site_id == g.definition("anchor_site_defs", "anchor_id", route.entry_anchor_id).site_id, "guidance resolves current AU route")
	check(act("survey", event), "pay survey on current route")
	advance(float(spec.survey_duration_s) + 0.2)
	check(act(choice, event), "open selected finite route mineral stock")
	for member: RefCounted in state.rows("exploration_actor_state"):
		if member.event_id == event_id: check(g.spatial_site("npc", member.npc_instance_id) == g.spatial_site("ship", state.ship().ship_instance_id), "real actor state occupies current route")
	place(g.definition("resource_node_locations", "node_id", node_id).anchor_id)
	check(g.act("start_mining", node_id).phase == T.ActionPhase.APPLIED, "actual extraction resolves mapped mineral anchor")
	while event.evidence_units <= 0: advance(0.2)
	g.work.stop_mining()
	var mined: int = cargo_units(ore)
	var evidence: int = event.evidence_units
	var stock: int = state.find("resource_state", "node_id", node_id).remaining_units
	var rng: String = JSON.stringify(Codec.new().encode_row("rng_state", state.rows("rng_state")[0]))
	var first: Dictionary = g.definition("exploration_belt_stage_defs", "stage_index", 1)
	event.elapsed_s = float(spec.duration_s) * float(first.threshold_bp) / 10000.0 - float(first.warning_lead_s) - 0.05
	var warnings: int = warning_count
	advance(0.1)
	check(warning_count == warnings + 1 and g.mobile_belts.detail(event_id).contains("预警"), "pre-stage warning appears before any stock loss")
	check(state.find("resource_state", "node_id", node_id).remaining_units == stock, "warning alone does not remove mineral")
	for stage: Dictionary in g.rows("exploration_belt_stage_defs"):
		event.elapsed_s = float(spec.duration_s) * float(stage.threshold_bp) / 10000.0 - 0.05
		advance(0.1)
		var cap: int = int(floor(float(belt.initial_units) * float(stage.remaining_cap_bp) / 10000.0))
		stock = mini(stock, cap)
		check(belt.stage_index == int(stage.stage_index) and state.find("resource_state", "node_id", node_id).remaining_units == stock, "real finite stock disperses at stage " + str(stage.stage_index))
		check(cargo_units(ore) == mined and event.evidence_units == evidence, "dispersion preserves actual cargo and collected evidence")
		if int(stage.stage_index) == 1:
			if not save_reload(0): return
			event = g.exploration.instance(event_id); belt = g.mobile_belts.instance(event_id)
			warnings = warning_count; advance(0.1)
			check(warning_count == warnings, "load does not replay delivered warning or refill stock")
	check(act("extract", event), "withdraw with existing ore")
	place(rule.exit_anchor_id); advance(0.1)
	check(event.phase == "ready" and event.outcome == "partial" and state.find("resource_state", "node_id", node_id).remaining_units == 0, "route-specific exit preserves partial success and closes stock")
	place(station.station_anchor_id, station.station_id); check(act("claim", event), "actual station settles one result per route generation")
	var generation: int = event.generation
	var old_route: String = belt.route_id
	var claims: int = state.rows("exploration_claim_state").size()
	event.cooldown_remaining_s = 0.1; place(rule.entry_anchor_id); advance(0.2)
	check(event.generation == generation and belt.route_id == old_route, "remaining at any candidate local space prevents surprise renewal")
	place(station.station_anchor_id, station.station_id)
	var position: Vector3 = g.position(state.ship())
	advance(0.2)
	check(event.generation == generation + 1 and belt.route_id != old_route and g.position(state.ship()) == position, "normal renewal migrates the event without moving player")
	check(cargo_units(ore) == mined and state.rows("exploration_claim_state").size() == claims and JSON.stringify(Codec.new().encode_row("rng_state", state.rows("rng_state")[0])) == rng, "migration preserves mined assets historical claims and world RNG")
	var validator: Validation = Validation.new()
	check(validator.validate(state, store.catalog), "complete mobile world validates " + validator.last_error)
	cases += 1
func legacy_mobile() -> void:
	g.dispose(); g = null; store.close(); store = null
	var source: String = OS.get_environment("XJ_MOBILE_BELTS_LEGACY_DATABASE").replace("\\", "/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/") and not source.contains(".."), "old active-mineral fixture is isolated"): return
	var path: String = directory.path_join("legacy.db")
	check(DirAccess.copy_absolute(source, path) == OK, "copy closed actual v0.19 PCK database")
	var faulty: FaultStore = FaultStore.new(path); faulty.failure = "migration:016_mobile_belts.sql"; store = faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version) == 12, "016 failure rolls back to actual format12")
	faulty.failure = ""; if not check(store.open(), "retry installs format13"): return
	var slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind == "manual": slot = row; break
	state = store.load(slot.slot_id)
	var before: String = complete_fingerprint(state, true)
	var old: RefCounted = state.find("exploration_instance_state", "event_id", "exp_echo_mineral")
	var elapsed: float = old.elapsed_s
	var stock: int = state.find("resource_state", "node_id", "exp_echo_mineral_safe").remaining_units
	check(old.phase == "mineral" and stock > 0 and old.evidence_units > 0, "actual old package supplied active window real ore and evidence")
	faulty.failure = "content_upgrade"
	check(store.upgrade_content(state) == null and complete_fingerprint(state, true) == before, "failed route branch preserves all forty-seven old groups")
	faulty.failure = ""
	state = store.upgrade_content(state)
	if not check(state != null, "reviewed active-world upgrade succeeds " + store.last_error): return
	check(complete_fingerprint(state, true) == before, "upgrade preserves all old assets stock progress receipts and RNG")
	g = Gameplay.new(); g.setup(state, store.catalog); connect_warnings()
	var belt: RefCounted = g.mobile_belts.instance("exp_echo_mineral")
	check(belt.start_elapsed_s == elapsed and belt.initial_units == stock and belt.stage_index == 0 and g.definition("exploration_belt_route_defs", "route_id", belt.route_id).route_index == 0, "old active belt gets original location and a fresh remaining-time decay schedule")
	var upgraded: String = complete_fingerprint(state)
	old = g.exploration.instance("exp_echo_mineral")
	var stage: Dictionary = g.definition("exploration_belt_stage_defs", "stage_index", 1)
	old.elapsed_s = elapsed + (float(g.exploration.variant(old).duration_s) - elapsed) * float(stage.threshold_bp) / 10000.0 - 0.05
	advance(0.1)
	check(belt.stage_index == 1 and state.find("resource_state", "node_id", "exp_echo_mineral_safe").remaining_units == int(floor(float(stock) * float(stage.remaining_cap_bp) / 10000.0)), "upgraded old stock begins dispersing only on its new schedule")
	check(save_reload(1), "upgraded grace and stage survive physical SQLite reopen")
	g.dispose(); g = null
	state = store.load(slot.slot_id)
	check(complete_fingerprint(state, true) == before and state.rows("exploration_belt_state").is_empty(), "original manual slot remains independent")
	var snapshots: int = int(store._records("SELECT count(*) n FROM save_snapshot")[0].n)
	state = store.upgrade_content(state)
	check(complete_fingerprint(state) == upgraded and int(store._records("SELECT count(*) n FROM save_snapshot")[0].n) == snapshots, "repeated upgrade reuses the exact original route branch")
func finish() -> void:
	if g != null: g.dispose(); g = null
	if store != null: store.close(); store = null
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "cases": cases, "legacy_checked": not OS.get_environment("XJ_MOBILE_BELTS_LEGACY_DATABASE").is_empty(), "directory": directory}
	print("MOBILE_BELTS_V28_FINAL_JSON ", JSON.stringify(summary)); print("MOBILE_BELTS_V28_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	await get_tree().process_frame; get_tree().quit(0 if failures.is_empty() else 1)
