extends Node
## Real source graph, paid extraction and frozen SQLite; poses/supplies are explicit fixtures.
const Store = preload("res://runtime/data/store.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Codec = preload("res://runtime/data/codec.gd")
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

func _ready() -> void:
	get_tree().set_meta("xj_resource_intel_v26_diagnostic", true)
	get_tree().create_timer(180.0).timeout.connect(func(): print("RESOURCE_INTEL_V26_RESULT FAIL watchdog"); get_tree().quit(2))
	_run.call_deferred()
func check(value: bool, label: String) -> bool:
	checks += 1; print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value
func act(kind: String, target: String = "", quantity: int = 1, extra: String = "") -> bool:
	var result: D.ActionResultDto = g.act(kind, target, quantity, extra)
	if result.phase != T.ActionPhase.APPLIED: print("ACTION_REASON ", kind, ": ", result.display_reason_key)
	return result.phase == T.ActionPhase.APPLIED
func fingerprint(value: XJRuntimeState) -> String:
	var data: Dictionary = {}
	for table: String in XJRuntimeState.TABLES:
		var rows: Array = []
		for row: RefCounted in value.rows(table): rows.append(Codec.new().encode_row(table, row))
		data[table] = rows
	return JSON.stringify(data)

func _run() -> void:
	directory = OS.get_environment("XJ_RESOURCE_INTEL_V26_DIRECTORY").replace("\\", "/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/resource-intel-v26/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "fresh scoped database"): get_tree().quit(2); return
	store = Store.new(directory.path_join("progress.db"))
	if not check(store.open(), "open format11 store: " + store.last_error): get_tree().quit(1); return
	state = store.new_world("Resource intelligence", 2601)
	if not check(state != null, "create frozen resource world: " + store.last_error): store.close(); get_tree().quit(1); return
	g = Gameplay.new(); g.setup(state, store.catalog)
	var before: String = fingerprint(state)
	var sources: Array = g.resource_intel.sources("ore_ferrosilicate")
	check(not sources.is_empty(), "real basic ore has public sources")
	var kinds: Dictionary = {}
	var remote_unknown: bool = false
	for row: Dictionary in sources:
		kinds[row.kind] = true
		if not row.known and (row.kind == "采购" or row.kind == "采矿"): remote_unknown = remote_unknown or str(row.detail).contains("未知")
		check(not g.resource_intel.guidance(row.key, "ore_ferrosilicate").is_empty(), "source identity resolves real location " + str(row.key))
	check(kinds.has("采矿") and kinds.has("采购"), "sources distinguish extraction from actual allowed sales")
	check(remote_unknown, "unvisited sectors mask dynamic reserve and stock")
	check(g.resource_intel.guidance("node:not-real", "ore_ferrosilicate").is_empty(), "forged source identity rejected")
	check(fingerprint(state) == before, "querying and routing changes no authoritative state or RNG")
	var unsupported: int = 0
	for access: Dictionary in g.rows("recipe_access_defs"):
		if g.resource_intel._facility(access.station_id, "manufacture").present: continue
		unsupported += 1
		var output: String = g.definition("recipe_defs", "recipe_id", access.recipe_id).output_item_id
		var advertised: bool = false
		for source: Dictionary in g.resource_intel.sources(output):
			if source.key == "craft:" + str(access.station_id) + ":" + str(access.recipe_id): advertised = true
		check(not advertised, "historical access row without a factory is not an executable source " + str(access.recipe_id))
	check(unsupported > 0, "fixture exercises actual historical missing-service rows")
	for def: Dictionary in store.catalog.rows("unlock_defs"): g.grant_unlock(def.unlock_id)
	var miner: D.ShipStateDto = g.inventory.create_ship("miner_anvil", g.station())
	check(act("switch_ship", miner.ship_instance_id), "legitimate current miner fixture")
	var grade: Dictionary = {}
	for row: Dictionary in store.catalog.rows("resource_grade_defs"):
		if int(row.yield_multiplier_bp) > 10000 and store.catalog.one("resource_node_defs", "node_id", row.node_id).item_id == "ore_ferrosilicate": grade = row; break
	if not check(not grade.is_empty(), "real high-grade ore exists"): await finish(); return
	var mining: Dictionary = {}
	for row: Dictionary in store.catalog.rows("mining_compatibility"):
		if row.item_id == "ore_ferrosilicate": mining = store.catalog.one("mining_defs", "module_id", row.module_id); break
	var id: String = g.inventory.grant(g.inventory.warehouse(g.station()), mining.module_id, 1)[0]
	check(act("fit_module", id, 1, "work"), "install actual compatible mining head")
	check(act("undock"), "real undock before mining")
	var node: Dictionary = store.catalog.one("resource_node_defs", "node_id", grade.node_id)
	var location: Dictionary = store.catalog.one("resource_node_locations", "node_id", node.node_id)
	var anchor: Dictionary = store.catalog.one("anchor_defs", "anchor_id", location.anchor_id)
	state.ship().sector_id = node.sector_id
	state.ship().pos_x = anchor.x_m; state.ship().pos_y = anchor.y_m; state.ship().pos_z = anchor.z_m
	for container: D.ContainerStateDto in state.rows("container_state"):
		if container.ship_instance_id == state.ship().ship_instance_id: container.sector_id = node.sector_id
	g.assign_anchor_site("ship", state.ship().ship_instance_id, anchor.anchor_id)
	state.find("sector_state", "sector_id", node.sector_id).visited = true
	var forecast: Dictionary = g.resource_intel.forecast(node.node_id)
	var actual: int = XJResourceStatus.yield_per_cycle(store.catalog, node.node_id, miner.ship_def_id, mining.module_id)
	var old_yield: int = int(floor(float(mining.base_yield_units) * float(store.catalog.one("ship_defs", "ship_id", miner.ship_def_id).mining_multiplier)))
	check(actual > old_yield and float(forecast.rate_per_min) > 0 and forecast.room_units > 0, "grade improves real extraction and forecast uses equipped head")
	check(is_equal_approx(float(forecast.rate_per_min), float(actual) / float(store.catalog.one("module_defs", "module_id", mining.module_id).cycle_s) * 60.0), "theoretical rate equals shared actual cycle yield")
	var resource: D.ResourceStateDto = state.find("resource_state", "node_id", node.node_id)
	var remaining: int = resource.remaining_units
	check(act("start_mining", node.node_id), "real mining command starts at authored site")
	g.work.tick(float(store.catalog.one("module_defs", "module_id", mining.module_id).cycle_s) + 0.1)
	g.work.stop_mining()
	check(resource.remaining_units == remaining - actual, "paid cycle subtracts actual grade-adjusted finite ore")
	var total: int = 0
	for container: D.ContainerStateDto in state.rows("container_state"):
		if container.ship_instance_id == miner.ship_instance_id: total += g.inventory.count(container.container_id, node.item_id, true)
	check(total == actual, "same paid cycle grants exact real output")
	var equipment: D.EquipmentStateDto = state.find("equipment_state", "item_instance_id", id)
	equipment.enabled = false
	check(float(g.resource_intel.forecast(node.node_id).rate_per_min) == 0, "disabled head contributes no forecast output")
	equipment.enabled = true
	var closed: Dictionary = {}
	for gate: D.GateStateDto in state.rows("gate_state"): closed[gate.connection_id] = gate.enabled; gate.enabled = false
	var blocked: bool = false
	for row: Dictionary in g.resource_intel.sources("ore_ferrosilicate"):
		if row.sector_id != state.current_sector() and not row.route_open: blocked = true
	check(blocked, "closed gates cannot be advertised as an open route")
	for gate: D.GateStateDto in state.rows("gate_state"): gate.enabled = closed[gate.connection_id]
	check(store.save(state, "manual", 0), "grade output and unchanged frozen definitions save: " + store.last_error)
	g.dispose(); g = null; store.close(); store = null; state = null
	if not OS.get_environment("XJ_RESOURCE_INTEL_LEGACY_DATABASE").is_empty(): legacy()
	await finish()

func legacy() -> void:
	var source: String = OS.get_environment("XJ_RESOURCE_INTEL_LEGACY_DATABASE").replace("\\", "/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/") and not source.contains(".."), "legacy fixture is test-owned"): return
	var path: String = directory.path_join("legacy.db")
	if not check(DirAccess.copy_absolute(source, path) == OK, "copy closed actual old client database"): return
	var faulty: FaultStore = FaultStore.new(path); faulty.failure = "migration:014_resource_intel.sql"; store = faulty
	check(not store.open(), "injected format11 failure rejects migration")
	check(int(store._records("SELECT format_version FROM database_meta")[0].format_version) == 10, "format10 remains after migration rollback")
	faulty.failure = ""
	if not check(store.open(), "retry reaches format11"): return
	var slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind == "manual": slot = row; break
	state = store.load(slot.slot_id)
	if not check(state != null, "old frozen rules restore after schema migration"): return
	var old: String = fingerprint(state)
	check(not state.rows("industry_job_state").is_empty(), "actual old fixture contains paid running and queued jobs")
	faulty.failure = "content_upgrade"
	check(store.upgrade_content(state) == null and fingerprint(state) == old, "failed resource branch preserves every asset order and RNG")
	faulty.failure = ""
	var next: XJRuntimeState = store.upgrade_content(state)
	check(next != null and fingerprint(next) == old and store.catalog.table_names.has("resource_grade_defs"), "resource branch preserves full state including paid order durations")
	state = store.load(slot.slot_id)
	check(state != null and fingerprint(state) == old and not store.catalog.table_names.has("resource_grade_defs"), "old manual remains independently restorable")
	store.close(); store = null; state = null

func finish() -> void:
	if g != null: g.dispose(); g = null
	if store != null: store.close(); store = null
	state = null
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "directory": directory, "legacy_checked": not OS.get_environment("XJ_RESOURCE_INTEL_LEGACY_DATABASE").is_empty()}
	print("RESOURCE_INTEL_V26_FINAL_JSON ", JSON.stringify(summary))
	print("RESOURCE_INTEL_V26_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
