extends Node
## Service/state rules with explicit supplies and arrival poses. Physical escort is tested separately.
const Store = preload("res://runtime/data/store.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Validation = preload("res://runtime/data/validation.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
class FaultStore extends Store:
	var failure: String = ""
	func _checkpoint(point: String) -> bool: return point != failure
var store: Store
var state: XJRuntimeState
var g: Gameplay
var directory: String
var checks: int = 0
var failures: Array[String] = []
var cases: int = 0

func _ready() -> void:
	get_tree().set_meta("xj_exploration_v27_diagnostic", true)
	get_tree().create_timer(360.0).timeout.connect(func(): print("EXPLORATION_V27_RESULT FAIL watchdog"); get_tree().quit(2))
	_run.call_deferred()
func check(value: bool, label: String) -> bool:
	checks += 1; print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value
func act(action: String, event: RefCounted) -> bool:
	var result: D.ActionResultDto = g.act("exploration_action", event.event_id, 1, action + ":" + str(event.generation))
	if result.phase != T.ActionPhase.APPLIED: print("ACTION_REASON ", action, " ", result.display_reason_key)
	return result.phase == T.ActionPhase.APPLIED
func fingerprint() -> String:
	return state_fingerprint(state)
func state_fingerprint(value: XJRuntimeState, prior_rules: bool = false) -> String:
	var values: Dictionary = {"credit": value.player().credit}
	for table: String in XJRuntimeState.TABLES:
		if table == "action_receipt_state": continue
		if prior_rules and table.begins_with("exploration_"): continue
		var rows: Array = []
		for row: RefCounted in value.rows(table):
			if prior_rules and table == "resource_state" and row.node_id.begins_with("exp_"): continue
			rows.append(Codec.new().encode_row(table, row))
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a) < JSON.stringify(b))
		values[table] = rows
	return JSON.stringify(values)
func place(anchor_id: String, station_id: String = "") -> void:
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", anchor_id)
	state.ship().sector_id = anchor.sector_id; state.ship().pos_x = anchor.x_m; state.ship().pos_y = anchor.y_m; state.ship().pos_z = anchor.z_m
	state.ship().vel_x = 0; state.ship().vel_y = 0; state.ship().vel_z = 0
	state.ship().status = T.ShipStatus.FLYING if station_id.is_empty() else T.ShipStatus.DOCKED
	state.ship().has_station_id = not station_id.is_empty(); state.ship().station_id = station_id
	state.player().has_docked_station_id = not station_id.is_empty(); state.player().docked_station_id = station_id
	for container: D.ContainerStateDto in state.rows("container_state"):
		if container.ship_instance_id == state.ship().ship_instance_id: container.sector_id = anchor.sector_id
	g.assign_anchor_site("ship", state.ship().ship_instance_id, anchor_id)
	state.find("sector_state", "sector_id", anchor.sector_id).visited = true
	if not station_id.is_empty(): g.inventory.warehouse(station_id)
func advance(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.00001:
		var step: float = minf(0.1, remaining)
		g.begin_step(step); g.work.tick(step); g.exploration.tick(step)
		remaining -= step
func reset_case(row: D.ExplorationInstanceStateDto, variant: Dictionary) -> void:
	g.exploration._clear_actors(row)
	row.generation += 1; row.variant_id = variant.variant_id; row.phase = "clue"; row.choice_id = ""; row.operation_kind = ""; row.operation_remaining_s = 0; row.elapsed_s = 0; row.cooldown_remaining_s = 0; row.evidence_units = 0; row.stabilized = false; row.hazard_clock_s = 0; row.outcome = ""
	for id: String in g.exploration.managed_resources:
		if g.exploration.managed_resources[id].event_id == row.event_id: state.find("resource_state", "node_id", id).remaining_units = 0
	var event: Dictionary = g.exploration.definition(row.event_id)
	place(event.entry_anchor_id)
	var m: Dictionary = g.metrics(state.ship())
	for layer: String in ["shield", "armor", "hull", "energy"]: state.ship().set(layer, m[layer + "_max"])
	state.ship().heat = 0; state.ship().overheated = false
	g.inventory.grant(g.inventory.hold(state.ship(), T.ContainerKind.CARGO), "material_structural_stock", 30)

func _run() -> void:
	directory = OS.get_environment("XJ_EXPLORATION_V27_DIRECTORY").replace("\\", "/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/exploration-v27/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "fresh scoped exploration database"): get_tree().quit(2); return
	store = Store.new(directory.path_join("progress.db"))
	if not check(store.open(), "format12 opens " + store.last_error): get_tree().quit(1); return
	state = store.new_world("Exploration matrix", 2701)
	if not check(state != null, "frozen six-structure world creates " + store.last_error): store.close(); get_tree().quit(1); return
	g = Gameplay.new(); g.setup(state, store.catalog)
	check(state.rows("exploration_instance_state").size() == 6 and state.rows("exploration_actor_state").is_empty(), "six clues initialize without free actors or goods")
	if OS.get_environment("XJ_EXPLORATION_FIXTURE_ONLY") == "1":
		_legacy_mineral_fixture()
		return
	for unlock: Dictionary in g.rows("unlock_defs"): g.grant_unlock(unlock.unlock_id)
	state.player().credit = 1000000
	var station: String = g.station()
	var battle: D.ShipStateDto = g.inventory.create_ship("battleship_forge_ironwall", station)
	var miner: D.ShipStateDto = g.inventory.create_ship("miner_anvil", station)
	for variant: Dictionary in g.rows("exploration_variant_defs"):
		var row: D.ExplorationInstanceStateDto = g.exploration.instance(variant.event_id)
		var event: Dictionary = g.exploration.definition(row.event_id)
		var hull: D.ShipStateDto = miner if event.event_kind == "mineral" else battle
		state.player().controlled_ship_id = hull.ship_instance_id
		reset_case(row, variant)
		cases += 1
		var before: String = fingerprint()
		check(g.act("exploration_action", row.event_id, 1, "survey:" + str(row.generation - 1)).phase != T.ActionPhase.APPLIED and fingerprint() == before, "stale generation rejects without assets " + str(variant.variant_id))
		var energy: float = hull.energy
		check(act("survey", row) and hull.energy < energy, "real paid survey " + str(variant.variant_id))
		advance(float(variant.survey_duration_s) / float(g.exploration.balance.em_scan_multiplier) + 0.2)
		check(row.phase == "surveyed" and row.operation_kind.is_empty(), "survey reveals fixed variant " + str(variant.variant_id))
		if event.event_kind == "rescue": _rescue(row, variant)
		elif event.event_kind == "relic": _relic(row, variant)
		else: _mineral(row, variant)
		var destination: Dictionary = g.definition("station_defs", "station_id", event.station_id)
		place(destination.station_anchor_id, destination.station_id)
		advance(0.1)
		if row.phase == "ready":
			var demand: RefCounted
			for need: Dictionary in g.rows("station_demand_defs"):
				if need.station_id == event.station_id:
					demand = state.find("station_demand_state", "demand_id", need.demand_id)
					# Declared prior partial-delivery fixture; event must not erase it.
					demand.remaining_units = int(need.required_units) - 1
					break
			var pending_units: int = demand.remaining_units if demand != null else 0
			var credit: int = state.player().credit
			var points: int = state.rows("exploration_progress_state")[0].insight_available
			check(act("claim", row), "claim frozen event result " + str(variant.variant_id))
			check(state.player().credit > credit and state.rows("exploration_progress_state")[0].insight_available > points, "reward has actual credit and cumulative evidence")
			before = fingerprint()
			check(not act("claim", row) and fingerprint() == before, "event reward cannot duplicate")
			var receipt: RefCounted = state.rows("exploration_claim_state")[-1]
			check(receipt.has_demand_id and receipt.demand_generation > 0, "event settlement triggers a real station supply generation")
			check(demand != null and demand.remaining_units == pending_units, "event-driven demand keeps previously delivered material")
		var validation: Validation = Validation.new()
		check(validation.validate(state, store.catalog), "all typed event actors resources and ledgers validate: " + validation.last_error)
	var home: Dictionary = g.definition("station_defs", "station_id", "station_anchor_port")
	place(home.station_anchor_id, home.station_id)
	for project: Dictionary in g.rows("exploration_research_defs"):
		var points: int = state.rows("exploration_progress_state")[0].insight_available
		var result: RefCounted = g.act("exploration_research", project.research_id)
		check(result.phase == T.ActionPhase.APPLIED, "cumulative event evidence buys actual research " + str(project.research_id))
		check(state.rows("exploration_progress_state")[0].insight_available == points - int(project.required_insight) and is_equal_approx(g.exploration.perk(project.perk_kind), float(project.multiplier)), "paid research has real numeric consumer")
		var before: String = fingerprint()
		check(g.act("exploration_research", project.research_id).phase != T.ActionPhase.APPLIED and fingerprint() == before, "research cannot spend or grant twice")
	check(cases == 18, "all eighteen authored variants executed")
	_persist_operation()
	# This service fixture advances only selected domains; Main normally refreshes
	# the derived contract windows in finish_step before any snapshot.
	g.missions.refresh()
	g._sync_spawns()
	check(store.save(state, "manual", 0), "complete event and research world seals " + store.last_error)
	var before: String = fingerprint()
	var slot: Dictionary
	for value: Dictionary in store.list_slots():
		if value.slot_kind == "manual" and int(value.slot_index) == 0: slot = value; break
	g.dispose(); g = null
	state = store.load(slot.slot_id); g = Gameplay.new(); g.setup(state, store.catalog)
	if fingerprint() != before:
		var previous: Dictionary = JSON.parse_string(before)
		var restored: Dictionary = JSON.parse_string(fingerprint())
		for table: String in previous:
			if previous[table] != restored[table]: print("EXPLORATION_ROUNDTRIP_DIFF ", table, " before=", JSON.stringify(previous[table]), " after=", JSON.stringify(restored[table]))
	check(fingerprint() == before, "actual frozen SQLite restores variants outcomes claims evidence and knowledge")
	g.dispose(); g = null; store.close(); store = null; state = null
	if not OS.get_environment("XJ_EXPLORATION_LEGACY_DATABASE").is_empty(): legacy()
	await finish()

func _legacy_mineral_fixture() -> void:
	# Uses only v0.19 APIs so the actual old PCK can create this fixture.
	for unlock: Dictionary in g.rows("unlock_defs"): g.grant_unlock(unlock.unlock_id)
	state.player().credit = 1000000
	var miner: D.ShipStateDto = g.inventory.create_ship("miner_anvil", g.station())
	state.player().controlled_ship_id = miner.ship_instance_id
	var module_id: String = ""
	for compatible: Dictionary in g.rows("mining_compatibility"):
		if compatible.item_id == "ore_ferrosilicate": module_id = compatible.module_id; break
	var item: String = g.inventory.grant(g.inventory.warehouse(g.station()), module_id, 1)[0]
	check(g.act("fit_module", item, 1, "work").phase == T.ActionPhase.APPLIED, "old fixture installs legal mining head")
	var event: RefCounted = g.exploration.instance("exp_echo_mineral")
	place(g.exploration.definition(event.event_id).entry_anchor_id)
	check(act("survey", event), "old fixture pays actual survey")
	advance(float(g.exploration.variant(event).survey_duration_s) + 0.2)
	check(act("safe", event), "old fixture opens real mineral stock")
	var node_id: String = "exp_echo_mineral_safe"
	place(g.definition("resource_node_locations", "node_id", node_id).anchor_id)
	check(g.act("start_mining", node_id).phase == T.ActionPhase.APPLIED, "old fixture starts actual extraction")
	while event.evidence_units <= 0: advance(0.2)
	g.work.stop_mining()
	event.elapsed_s = float(g.exploration.variant(event).duration_s) * 0.5
	g.missions.refresh(); g._sync_spawns()
	check(store.save(state, "manual", 0), "old fixture saves active mineral window and real cargo")
	var summary: Dictionary = {"database": store.path, "format": int(store._records("SELECT format_version FROM database_meta")[0].format_version), "content_hash": store.catalog.content_hash, "event_id": event.event_id, "evidence": event.evidence_units, "elapsed": event.elapsed_s, "remaining_units": state.find("resource_state", "node_id", node_id).remaining_units}
	print("EXPLORATION_FIXTURE_READY ", JSON.stringify(summary))
	g.dispose(); g = null; store.close(); store = null; get_tree().quit(0 if failures.is_empty() else 1)

func _persist_operation() -> void:
	var row: D.ExplorationInstanceStateDto = g.exploration.instance("exp_mirror_relic")
	var spec: Dictionary = g.definition("exploration_variant_defs", "variant_id", "exp_mirror_relic_v1")
	reset_case(row, spec)
	var energy: float = state.ship().energy
	g.spatial_validator = func(_from: Vector3, _to: Vector3, _target: String) -> bool: return false
	check(not act("survey", row) and state.ship().energy == energy, "occluded clue rejects before charging the investigation")
	g.spatial_validator = Callable()
	check(act("survey", row), "begin a persisted paid investigation")
	advance(1.2)
	var remaining: float = row.operation_remaining_s
	energy = state.ship().energy
	var seed: int = row.variant_seed
	check(store.save(state, "manual", 1), "save inside paid exploration work " + store.last_error)
	var slot: Dictionary
	for value: Dictionary in store.list_slots():
		if value.slot_kind == "manual" and int(value.slot_index) == 1: slot = value; break
	g.dispose(); g = null
	state = store.load(slot.slot_id); g = Gameplay.new(); g.setup(state, store.catalog)
	row = g.exploration.instance("exp_mirror_relic")
	check(row.operation_kind == "survey" and is_equal_approx(row.operation_remaining_s, remaining) and row.variant_seed == seed and is_equal_approx(state.ship().energy, energy), "reopen restores the paid work energy and fixed variant without another payment")
	var entry: String = g.exploration.definition(row.event_id).entry_anchor_id
	state.ship().pos_x += float(g.exploration.definition(row.event_id).operation_range_m) * 3.0
	advance(1.0)
	check(is_equal_approx(row.operation_remaining_s, remaining), "leaving range pauses already paid investigation")
	place(entry); advance(remaining / float(g.exploration.balance.em_scan_multiplier) + 0.2)
	check(row.phase == "surveyed", "returned investigation continues from its saved remainder")
	check(act("extract", row), "withdraw without fabricated evidence")
	place(g.exploration.definition(row.event_id).exit_anchor_id); advance(0.1)
	check(row.phase == "failed" and row.outcome == "failed", "empty withdrawal earns no evidence or credits")
	var home: Dictionary = g.definition("station_defs", "station_id", "station_anchor_port")
	place(home.station_anchor_id, home.station_id)
	var generation: int = row.generation
	var receipts: int = state.rows("exploration_claim_state").size()
	row.cooldown_remaining_s = 0.1; advance(0.2)
	check(row.generation == generation + 1 and row.phase == "clue" and row.variant_seed != seed and state.rows("exploration_claim_state").size() == receipts, "normal expired clue renews deterministically while historical reward receipts remain")

func legacy() -> void:
	var source: String = OS.get_environment("XJ_EXPLORATION_LEGACY_DATABASE").replace("\\", "/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/") and not source.contains("..") and FileAccess.file_exists(source), "actual format11 fixture is scoped and closed"): return
	var path: String = directory.path_join("legacy.db")
	if not check(DirAccess.copy_absolute(source, path) == OK, "copy old Windows PCK database without editing source"): return
	var faulty: FaultStore = FaultStore.new(path); faulty.failure = "migration:015_exploration.sql"; store = faulty
	check(not store.open(), "injected exploration schema migration fails")
	check(int(store._records("SELECT format_version FROM database_meta")[0].format_version) == 11, "failed migration preserves actual format11")
	faulty.failure = ""
	if not check(store.open(), "migration retries to format12"): return
	var slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind == "manual": slot = row; break
	state = store.load(slot.slot_id)
	if not check(state != null and not store.catalog.table_names.has("exploration_event_defs"), "old frozen world loads independently under current runtime"): return
	var before: String = state_fingerprint(state, true)
	check(state.rows("industry_job_state").size() == 4, "actual old client retains three paid jobs and one cancellation receipt")
	faulty.failure = "content_upgrade"
	check(store.upgrade_content(state) == null and state_fingerprint(state, true) == before, "failed exploration branch preserves assets paid durations knowledge territory and RNG")
	faulty.failure = ""
	var next: XJRuntimeState = store.upgrade_content(state)
	if not check(next != null, "reviewed exploration upgrade succeeds after rollback " + store.last_error): return
	check(state_fingerprint(next, true) == before, "all forty-two old state groups and existing resources preserve exact rows")
	check(next.rows("exploration_instance_state").size() == 6 and next.rows("exploration_actor_state").is_empty() and next.rows("exploration_claim_state").is_empty() and next.rows("exploration_progress_state")[0].insight_available == 0, "upgrade adds six deterministic unpaid clues without ships rewards or knowledge")
	var generation: int = int(store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	check(store.upgrade_content(state) == null, "superseded old session cannot issue another upgrade")
	state = store.load(slot.slot_id)
	var again: XJRuntimeState = store.upgrade_content(state)
	check(again != null and state_fingerprint(again) == state_fingerprint(next) and int(store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == generation, "repeated upgrade reuses the exact branch and receipts")
	state = store.load(slot.slot_id)
	check(state != null and state_fingerprint(state, true) == before and state.rows("exploration_instance_state").is_empty(), "old manual slot remains independently restorable")
	store.close(); store = null; state = null

func _rescue(row: RefCounted, spec: Dictionary) -> void:
	var escort: D.NpcStateDto
	for member: D.ExplorationActorStateDto in state.rows("exploration_actor_state"):
		if member.event_id == row.event_id and member.actor_role == "escort": escort = state.find("npc_state", "npc_instance_id", member.npc_instance_id); break
	if not check(escort != null and escort.alive, "survey creates actual damaged transport"): return
	var old_hull: float = escort.hull
	if int(spec.variant_index) == 2:
		check(act("recover", row), "choose cargo recovery instead of escort")
		advance(float(spec.work_duration_s) + 0.2)
		check(row.phase == "extracting" and row.evidence_units == 1, "real recovered cargo supports partial extraction")
	else:
		check(act("rescue", row), "spend normal cargo structure on real transport repair")
		advance(float(spec.work_duration_s) + 0.2)
		check(row.stabilized and escort.hull > old_hull, "repair restores actual escort hull")
		if int(spec.variant_index) == 3:
			g.damage_npc(escort.npc_instance_id, Vector3(100000, 100000, 100000)); advance(0.1)
			check(row.phase == "failed", "destroyed escort cannot produce a rescue victory")
			return
	var exit_: Dictionary = g.definition("anchor_defs", "anchor_id", g.exploration.definition(row.event_id).exit_anchor_id)
	# This arrival pose verifies authority only; native suite verifies real movement and hits.
	escort.pos_x = exit_.x_m; escort.pos_y = exit_.y_m; escort.pos_z = exit_.z_m
	place(exit_.anchor_id); advance(0.1)
	check(row.phase == "ready", "escort or recovered cargo resolves only at physical extraction location")

func _relic(row: RefCounted, spec: Dictionary) -> void:
	if int(spec.variant_index) == 1:
		check(act("stabilize", row), "invest real structural material into risk source")
		advance(float(spec.work_duration_s) + 0.2); check(row.stabilized, "risk stabilization persists")
	var layers: int = 3 if int(spec.variant_index) == 1 else 1 if int(spec.variant_index) == 2 else 2
	for layer: int in range(layers):
		check(act("deepen", row), "paid deeper relic layer " + str(layer))
		advance(float(spec.work_duration_s) / float(g.exploration.balance.em_scan_multiplier) + 0.2)
	check(row.evidence_units == layers, "completed layers retain accumulated evidence")
	if int(spec.variant_index) == 3:
		row.elapsed_s = float(spec.duration_s); advance(0.1)
		check(row.phase == "ready" and row.outcome == "partial", "deadline preserves completed evidence without a full victory")
	else:
		check(act("extract", row), "choose to leave with completed evidence")
		place(g.exploration.definition(row.event_id).exit_anchor_id); advance(0.1)
		check(row.phase == "ready", "relic extraction requires authored point")

func _mineral(row: RefCounted, spec: Dictionary) -> void:
	var choice: String = "rich" if int(spec.variant_index) == 2 else "safe"
	check(act(choice, row), "open selected temporary mineral choice " + choice)
	var node_id: String = ""
	for id: String in g.exploration.managed_resources:
		if g.exploration.managed_resources[id].event_id == row.event_id and g.exploration.managed_resources[id].choice_id == choice: node_id = id; break
	var node: Dictionary = g.definition("resource_node_defs", "node_id", node_id)
	var source: Dictionary = g.definition("resource_node_locations", "node_id", node_id)
	place(source.anchor_id)
	# Qualified equipment fixture is installed through the real inventory service at a dock.
	var station: Dictionary = g.definition("station_defs", "station_id", g.exploration.definition(row.event_id).station_id)
	place(station.station_anchor_id, station.station_id)
	for equipment: D.EquipmentStateDto in g.equipped(state.ship()).duplicate():
		check(g.act("unfit_module", equipment.item_instance_id).phase == T.ActionPhase.APPLIED, "legitimate docked removal before mining-role fixture")
	var module_id: String = ""
	for row_: Dictionary in g.rows("mining_compatibility"):
		if row_.item_id == node.item_id: module_id = row_.module_id; break
	var item: String = g.inventory.grant(g.inventory.warehouse(g.station()), module_id, 1)[0]
	check(g.act("fit_module", item, 1, "work").phase == T.ActionPhase.APPLIED, "install actually compatible mining head")
	place(source.anchor_id)
	if int(spec.variant_index) == 3:
		# Declared last-unit fixture exercises actual equipment depletion and cleanup.
		state.find("resource_state", "node_id", node_id).remaining_units = 1
	check(g.act("start_mining", node_id).phase == T.ActionPhase.APPLIED, "real temporary mining starts")
	var deadline: float = row.elapsed_s + float(spec.duration_s)
	var target: int = 1 if int(spec.variant_index) == 3 else int(spec.mineral_quota)
	while row.evidence_units < target and row.phase == "mineral" and row.elapsed_s < deadline: advance(0.2)
	g.work.stop_mining()
	check(row.evidence_units >= target, "real paid output advances the mineral evidence counter")
	if int(spec.variant_index) == 3:
		check(state.find("resource_state", "node_id", node_id).remaining_units == 0 and state.find("resource_state", "node_id", node_id).respawn_remaining_s == 0.0 and g.work.mining_target.is_empty(), "depleted temporary node stops paid work without ordinary regeneration")
		check(XJResourceStatus.summary(XJResourceStatus.inspect(state, store.catalog, node_id)).contains("本轮不再生"), "temporary depletion does not promise an ordinary respawn")
	check(act("extract", row), "leave temporary belt with actual goods")
	place(g.exploration.definition(row.event_id).exit_anchor_id); advance(0.1)
	check(row.phase == "ready" and not g.exploration.resource_visible(node_id) and state.find("resource_state", "node_id", node_id).remaining_units == 0, "finished temporary ore disappears without normal regeneration")

func finish() -> void:
	if g != null: g.dispose(); g = null
	if store != null: store.close(); store = null
	state = null
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "cases": cases, "directory": directory, "legacy_checked": not OS.get_environment("XJ_EXPLORATION_LEGACY_DATABASE").is_empty()}
	print("EXPLORATION_V27_FINAL_JSON ", JSON.stringify(summary)); print("EXPLORATION_V27_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	await get_tree().process_frame; get_tree().quit(0 if failures.is_empty() else 1)
