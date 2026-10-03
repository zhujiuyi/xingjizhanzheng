extends SceneTree
## Reproduce the historical writer's all-installed-module capacity allowance
## while keeping its real transaction, FK checks, seal triggers and CAS publish.
## The old source catalog is the closed tmp audit fixture, never a personal save.
const Store = preload("res://runtime/data/store.gd")
const G = preload("res://runtime/gameplay.gd")
const Validator = preload("res://runtime/data/validation.gd")
const Catalog = preload("res://runtime/data/catalog.gd")
const State = preload("res://runtime/state.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []

class LegacyFixtureStore extends Store:
	# This copy of the normal row writer changes only validation's explicitly
	# named legacy-capacity option. It constructs old behavior through the real
	# sealing path; it does not drop triggers or edit sealed snapshots.
	func _write_snapshot(snapshot: State) -> bool:
		var validator: Validator = Validator.new()
		var definitions: Catalog = staging_catalog if staging_catalog != null else _source if snapshot.snapshot.meta.reason == "initial" else catalog
		if not validator.validate(snapshot, definitions, true): return _fail(validator.last_error)
		var values: Dictionary = _plain_object(snapshot.snapshot.meta)
		values.erase("has_transfer_id")
		if not snapshot.snapshot.meta.has_transfer_id: values.transfer_id = null
		values.status = "building"
		if not _insert("save_snapshot", values): return false
		for table: String in State.TABLES:
			for row: RefCounted in snapshot.rows(table):
				var encoded: Dictionary = _codec.encode_row(table, row)
				if encoded.is_empty(): return _fail(_codec.last_error)
				encoded.snapshot_id = snapshot.snapshot.meta.snapshot_id
				encoded.world_id = snapshot.world_id
				encoded.content_snapshot_id = snapshot.snapshot.content.content_snapshot_id
				if not _insert(table, encoded): return false
		if not _checkpoint("state"): return _fail("Injected failure after state rows")
		if not _q("PRAGMA foreign_key_check") or not _db.query_result.is_empty(): return _fail("Snapshot reference closure failed")
		if not _q("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id=?", [snapshot.snapshot.meta.snapshot_id]): return false
		if not _checkpoint("seal"): return _fail("Injected failure after seal")
		return true

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func applied(g: G, action: String, target: String = "", extra: String = "") -> bool:
	return g.act(action, target, 1, extra).phase == T.ActionPhase.APPLIED

func selected(store: Store) -> Dictionary:
	for slot: Dictionary in store.list_slots():
		if slot.slot_kind == "manual" and int(slot.slot_index) == 0: return slot
	return {}

func sealed_armor(store: Store, snapshot_id: String, ship_id: String) -> float:
	var rows: Array[Dictionary] = store._records("SELECT h.armor FROM ship_state h JOIN save_snapshot s USING(snapshot_id) WHERE h.snapshot_id=? AND h.ship_instance_id=? AND s.status='sealed'", [snapshot_id, ship_id])
	return float(rows[0].armor) if not rows.is_empty() else -1.0

func finish(store: Store = null, g: G = null) -> void:
	if g != null: g.dispose()
	if store != null: store.close()
	print("LEGACY_MODULE_CAPACITY_AUDIT_RESULT %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var old_catalog: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/audit-catalog-v090.db")
	if not check(FileAccess.file_exists(old_catalog), "closed pre-integrity catalog fixture exists"): finish(); return
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/legacy-capacity-%d.db" % Time.get_ticks_usec())
	var legacy: LegacyFixtureStore = LegacyFixtureStore.new(path)
	legacy.catalog_path = old_catalog
	if not check(legacy.open(), "test-only historical writer opens isolated SQLite"): finish(legacy); return
	var state: State = legacy.new_world("legacy-disabled-module-capacity", 8801)
	if not check(state != null, "historical frozen content creates real initial seal"): finish(legacy); return
	var g: G = G.new(); g.setup(state, legacy.catalog)
	check(str(g.rows("catalog_meta")[0].content_version) == "v0.5-encounters", "fixture has actual old content identity")
	for unlock: Dictionary in g.rows("unlock_defs"): g.grant_unlock(str(unlock.unlock_id))
	state.player().credit = 100000
	var owned: D.ShipStateDto = g.inventory.create_ship("cruiser_horizon", "station_anchor_port")
	check(applied(g, "switch_ship", owned.ship_instance_id), "historical controlled owned hull prepared")
	var warehouse: String = g.inventory.warehouse(g.station())
	var item_id: String = g.inventory.grant(warehouse, "module_armor_pressure_i", 1)[0]
	check(applied(g, "fit_module", item_id, "structure:0"), "ordinary armor module installs through real rules")
	var base: float = float(g.definition("ship_defs", "ship_id", owned.ship_def_id).armor_max)
	var prior_max: float = float(g.metrics(owned).armor_max)
	owned.armor = prior_max
	var equipment: D.EquipmentStateDto = state.find("equipment_state", "item_instance_id", item_id)
	equipment.enabled = false # Reproduce the old switch's retained-HP behavior.
	var parked: D.ShipStateDto = g.inventory.create_ship("cruiser_horizon", "station_anchor_port")
	check(applied(g, "switch_ship", parked.ship_instance_id), "historical parked-hull fixture selected")
	var broken_id: String = g.inventory.grant(warehouse, "module_armor_pressure_i", 1)[0]
	check(applied(g, "fit_module", broken_id, "structure:0"), "historical second armor module installs")
	parked.armor = float(g.metrics(parked).armor_max)
	var broken: D.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", broken_id)
	broken.durability = 0
	check(applied(g, "switch_ship", owned.ship_instance_id), "disabled hull controls while damaged-module hull remains parked")
	var validation: Validator = Validator.new()
	check(not validation.validate(state, legacy.catalog), "current validator rejects historical excess before normalization")
	check(validation.validate(state, legacy.catalog, true), "explicit historical allowance matches former valid capacity")
	if not check(legacy.save(state, "manual", 0), "historical row writer seals through intact FK/immutability/CAS: " + legacy.last_error): finish(legacy, g); return
	var old_slot: Dictionary = selected(legacy)
	var old_snapshot: String = str(old_slot.current_snapshot_id)
	var owned_id: String = owned.ship_instance_id
	var parked_id: String = parked.ship_instance_id
	check(is_equal_approx(sealed_armor(legacy, old_snapshot, owned_id), prior_max) and is_equal_approx(sealed_armor(legacy, old_snapshot, parked_id), prior_max), "old sealed SQL stores both genuine historical HP values")
	g.dispose(); legacy.close()
	var store: Store = Store.new(path)
	if not check(store.open(), "normal current Store independently reopens history"): finish(store); return
	state = store.load(str(old_slot.slot_id), old_snapshot, int(old_slot.generation))
	if not check(state != null, "normal old-content load accepts previously valid disabled-module state: " + store.last_error): finish(store); return
	check(is_equal_approx(state.ship().armor, prior_max), "load decodes the historical value before gameplay normalization")
	g = G.new(); g.setup(state, store.catalog)
	owned = state.find("ship_state", "ship_instance_id", owned_id)
	parked = state.find("ship_state", "ship_instance_id", parked_id)
	check(is_equal_approx(owned.armor, base) and is_equal_approx(parked.armor, base), "setup normalizes both controlled disabled and parked broken-module hulls")
	check(is_equal_approx(sealed_armor(store, old_snapshot, owned_id), prior_max) and is_equal_approx(sealed_armor(store, old_snapshot, parked_id), prior_max), "runtime normalization preserves old immutable SQL snapshots")
	check(validation.validate(state, store.catalog), "normalized live state satisfies current strict capacity")
	g.dispose(); g = null
	state = store.upgrade_content(state)
	if not check(state != null, "reviewed content upgrade seals normalized history: " + store.last_error): finish(store); return
	g = G.new(); g.setup(state, store.catalog)
	check(str(g.rows("catalog_meta")[0].content_version) == "v0.5-integrity", "upgrade moves history to current integrity content")
	owned = state.ship()
	var before_slot: Dictionary = selected(store)
	var before_sequence: int = state.capture_sequence
	var before_endpoint: String = state.snapshot.meta.snapshot_id
	owned.armor = float(g.metrics(owned).armor_max) + 1.0
	check(not store.save(state, "manual", 0), "normal save refuses above-effective-max HP: " + store.last_error)
	check(selected(store) == before_slot and state.capture_sequence == before_sequence and state.snapshot.meta.snapshot_id == before_endpoint, "rejected invalid save preserves slot generation and live endpoint")
	owned.armor = float(g.metrics(owned).armor_max)
	var item: D.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", item_id)
	item.quality_multiplier = 1.5 # Explicit isolated non-standard asset-quality fixture.
	var retained: float = owned.armor
	check(applied(g, "set_module_enabled", item_id, "on") and owned.armor == retained, "enabling quality-modified module preserves damaged absolute HP")
	var bonus: float = 0.0
	for modifier: Dictionary in g.rows("module_stat_modifiers"):
		if modifier.module_id == item.item_def_id and modifier.stat_id == "armor_max" and modifier.operation == "add": bonus += float(modifier.amount)
	var effective: float = base + bonus * item.quality_multiplier
	check(is_equal_approx(float(g.metrics(owned).armor_max), effective), "real runtime capacity applies actual instance quality")
	check(applied(g, "repair") and is_equal_approx(owned.armor, effective), "actual paid station repair fills the quality-derived capacity")
	check(validation.validate(state, store.catalog) and store.save(state, "manual", 0), "strict writer accepts actual quality-derived maximum")
	var latest: Dictionary = selected(store)
	check(is_equal_approx(sealed_armor(store, str(latest.current_snapshot_id), owned_id), effective), "quality-derived HP is actually sealed")
	check(is_equal_approx(sealed_armor(store, old_snapshot, owned_id), prior_max), "all later commits preserve the original old HP seal")
	g.dispose(); store.close()
	store = Store.new(path)
	if check(store.open(), "quality-derived state independently reopens"):
		state = store.load(str(latest.slot_id), str(latest.current_snapshot_id), int(latest.generation))
		if check(state != null, "current-content strict load accepts legal quality-derived HP: " + store.last_error):
			g = G.new(); g.setup(state, store.catalog)
			item = state.find("item_instance_state", "item_instance_id", item_id)
			check(is_equal_approx(item.quality_multiplier, 1.5) and is_equal_approx(state.ship().armor, effective), "quality and HP survive current strict reload and setup")
		else: g = null
	else: g = null
	finish(store, g)
