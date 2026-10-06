extends Node
## Actual Store/SQLite migration on a copied, closed v0.13 test archive.
## Explicit old-catalog fixtures exercise provenance, damage and fit rejection.
## Never opens user:// or writes the supplied legacy source.
const Store = preload("res://runtime/data/store.gd")
const State = preload("res://runtime/state.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []
var directory: String
var database_path: String
var legacy_source: String
var input_hash: String
var store: FaultStore
var game: Gameplay
var source_slot: Dictionary
var source_snapshot: String
var source_content: String
var source_hash: String
var source_tables: Array[String] = []
var original_manual: Array[String] = []
var historic_manual: Array[String] = []
var historic_frozen: Dictionary = {}
var historic_payload: Dictionary = {}
var historic_snapshots: Array[String] = []
var old_state: Dictionary = {}
var old_standard: Dictionary = {}
var purchased_id: String
var manufactured_id: String
var thermal_id: String
var fixture_ship_id: String
var upgraded_snapshot: String
var upgraded_content: String
var upgraded_hash: String
var backup_hash: String

class FaultStore extends Store:
	var fault: String = ""
	func _checkpoint(point: String) -> bool:
		return point != fault

func _ready() -> void:
	get_tree().set_meta("xj_upgrade_v18_diagnostic", true)
	get_tree().create_timer(240.0).timeout.connect(func(): print("COMBAT_UPGRADE_V18_RESULT FAIL watchdog"); get_tree().quit(1))
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func canonical(rows: Array) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in rows: result.append(JSON.stringify(row, "", true, true))
	result.sort()
	return result

func state_rows(state: State) -> Dictionary:
	var result: Dictionary = {}
	for table: String in State.TABLES:
		var values: Array[Dictionary] = []
		for row: RefCounted in state.rows(table): values.append(Codec.new().encode_row(table, row))
		result[table] = canonical(values)
	return result

func manual_slots() -> Array[String]:
	return canonical(store._records("SELECT * FROM save_slot WHERE slot_kind='manual' ORDER BY slot_id"))

func endpoints() -> Dictionary:
	var values: Dictionary = {}
	for table: String in ["save_slot", "runtime_session", "profile_resume", "content_upgrade_record", "snapshot_lineage"]:
		values[table] = canonical(store._records("SELECT * FROM " + table))
	for table: String in ["save_snapshot", "content_snapshot", "manufacture_input_state"]:
		values[table + "_count"] = int(store._records("SELECT count(*) AS n FROM " + table)[0].n)
	return values

func frozen_values(content_id: String, tables: Array[String]) -> Dictionary:
	var values: Dictionary = {}
	for table: String in tables:
		values[table] = canonical(store._records('SELECT * FROM "frozen_' + table + '" WHERE content_snapshot_id=?', [content_id]))
	values["metadata"] = canonical(store._records("SELECT * FROM content_snapshot WHERE content_snapshot_id=?", [content_id]))
	values["table_manifest"] = canonical(store._records("SELECT * FROM content_table_manifest WHERE content_snapshot_id=?", [content_id]))
	values["view_manifest"] = canonical(store._records("SELECT * FROM content_view_manifest WHERE content_snapshot_id=?", [content_id]))
	return values

func sealed_values(ids: Array[String]) -> Dictionary:
	var values: Dictionary = {}
	for table: String in State.TABLES + ["save_snapshot"]:
		var rows: Array[Dictionary] = []
		for id: String in ids: rows.append_array(store._records('SELECT * FROM "' + table + '" WHERE snapshot_id=?', [id]))
		values[table] = canonical(rows)
	return values

func read_only(path: String) -> Object:
	if not FileAccess.file_exists(path): return null
	var witness: Object = ClassDB.instantiate("SQLite")
	witness.path = path
	# External paths in Release use the native SQLite VFS. Only test-owned
	# existing copies may open that mode, followed immediately by query_only.
	# The original legacy source is accessed only by read-only FileAccess/copy.
	witness.read_only = not path.begins_with(directory + "/")
	witness.foreign_keys = true; witness.verbosity_level = 0
	if not witness.open_db(): return null
	witness.query("PRAGMA query_only=ON")
	return witness

func backup_check(path: String, snapshot: String = "", content: String = "", expected_format: int = 0) -> void:
	if not check(FileAccess.file_exists(path), "closed native backup exists " + path.get_file()): return
	var witness: Object = read_only(path)
	if not check(witness != null, "backup independently opens read-only " + path.get_file()): return
	witness.query("PRAGMA integrity_check")
	check(witness.query_result.size() == 1 and witness.query_result[0].values()[0] == "ok", "backup SQLite physical integrity " + path.get_file())
	witness.query("PRAGMA foreign_key_check")
	check(witness.query_result.is_empty(), "backup relational integrity " + path.get_file())
	if expected_format > 0:
		witness.query("SELECT format_version FROM database_meta")
		check(int(witness.query_result[0].format_version) == expected_format, "pre-schema backup retains exact old format")
	if not snapshot.is_empty():
		witness.query_with_bindings("SELECT status,content_snapshot_id FROM save_snapshot WHERE snapshot_id=?", [snapshot])
		check(witness.query_result.size() == 1 and witness.query_result[0].status == "sealed" and witness.query_result[0].content_snapshot_id == content, "content backup contains exact sealed old source")
	witness.close_db()

func prepare_legacy_fixture(state: State) -> bool:
	game = Gameplay.new(); game.setup(state, store.catalog)
	var station: String = "station_anchor_port"
	var inventory: RefCounted = game.get("inventory")
	var economy: RefCounted = game.get("economy")
	var ship: D.ShipStateDto = inventory.call("create_ship", "cruiser_horizon", station)
	fixture_ship_id = ship.ship_instance_id
	state.player().controlled_ship_id = ship.ship_instance_id
	state.player().has_docked_station_id = true; state.player().docked_station_id = station
	for unlock: Dictionary in store.catalog.rows("unlock_defs"): game.grant_unlock(str(unlock.unlock_id))
	var warehouse: String = str(inventory.call("warehouse", station))
	var purchased: Array = inventory.call("grant", warehouse, "module_kinetic_needle_ii", 1)
	purchased_id = str(purchased[0])
	var item: D.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", purchased_id)
	item.quality_multiplier = 0.93; item.durability = 61.0
	var recipe: String = str(store.catalog.one("module_salvage_recipe_defs", "module_id", item.item_def_id).recipe_id)
	for input: Dictionary in store.catalog.rows("recipe_inputs"):
		if input.recipe_id != recipe: continue
		old_standard[str(input.item_id)] = int(input.quantity)
		inventory.call("grant", warehouse, str(input.item_id), int(input.quantity))
	state.player().credit += int(economy.call("quote_manufacture", recipe, 1)) * 3
	if not check(bool(economy.call("manufacture", recipe, 1)), "old-catalog real manufacture creates an actual paid batch and material ledger"): return false
	for candidate: D.ItemInstanceStateDto in state.rows("item_instance_state"):
		if candidate.item_def_id == item.item_def_id and candidate.origin_kind == T.ItemOrigin.MANUFACTURE: manufactured_id = candidate.item_instance_id
	if not check(not manufactured_id.is_empty(), "manufactured fixture has correct origin and production batch"): return false
	var manufactured: D.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", manufactured_id)
	manufactured.quality_multiplier = 1.07; manufactured.durability = 54.0
	var thermal: Array = inventory.call("grant", warehouse, "module_thermal_sunline_i", 1)
	thermal_id = str(thermal[0])
	if not check(bool(inventory.call("fit", thermal_id, 0, "weapon:0")) and bool(inventory.call("fit", purchased_id, 1, "weapon:1")), "old rules legally fit mixed families on ordinary cruiser"): return false
	var equipment: D.EquipmentStateDto = state.find("equipment_state", "item_instance_id", thermal_id)
	# Capture the largest legally sealable old cooldown. Current upgraded light
	# cycles are longer, so migration must retain this remaining absolute time.
	equipment.cooldown_remaining_s = float(store.catalog.one("module_defs", "module_id", "module_thermal_sunline_i").cycle_s)
	equipment.active_remaining_s = 0.0; equipment.cycle_paid = false
	ship.shield *= 0.47; ship.armor *= 0.63; ship.hull *= 0.71; ship.energy *= 0.42
	game.get("missions").call("refresh"); game.call("_sync_spawns")
	var limit: int = int(store._records("SELECT slot_count FROM storage_policy WHERE slot_kind='manual'")[0].slot_count)
	var free: int = -1
	for index: int in range(limit):
		if store._records("SELECT slot_id FROM save_slot WHERE world_id=? AND slot_kind='manual' AND slot_index=?", [state.world_id, index]).is_empty(): free = index; break
	if not check(free >= 0, "legacy test archive retains an unused manual slot for isolated fixture"): return false
	if not check(store.save(state, "manual", free), "actual legacy definitions legally seal the prepared old-state manual endpoint: " + store.last_error): return false
	source_slot = store._records("SELECT * FROM save_slot WHERE world_id=? AND slot_kind='manual' AND slot_index=?", [state.world_id, free])[0].duplicate(true)
	source_snapshot = state.snapshot.meta.snapshot_id; source_content = state.snapshot.content.content_snapshot_id; source_hash = state.snapshot.content.content_hash
	source_tables = store.catalog.table_names.duplicate()
	old_state = state_rows(state)
	historic_manual = manual_slots()
	historic_frozen = frozen_values(source_content, source_tables)
	for row: Dictionary in store._records("SELECT snapshot_id FROM save_snapshot WHERE status='sealed'"): historic_snapshots.append(str(row.snapshot_id))
	historic_payload = sealed_values(historic_snapshots)
	for before: String in original_manual: check(historic_manual.has(before), "fixture preparation preserves each existing original manual slot")
	print("COMBAT_UPGRADE_V18_FIXTURE real-closed-v013-copy ordinary-cruiser=explicit old-purchase=production-grant old-manufacture=real-paid-batch cooldown=old-ddl-boundary damage=explicit no-personal-save")
	return true

func failure_checks(previous: State) -> void:
	var before: Dictionary = endpoints()
	var before_live: Dictionary = state_rows(previous)
	var before_catalog: String = store.catalog.content_hash
	var rejected: State = store.upgrade_content(previous, func(_candidate: State) -> bool: return false)
	check(rejected == null and store.active_state == previous and store.catalog.content_hash == before_catalog and not store.busy, "staging rejection preserves old live state and catalog authority")
	check(endpoints() == before and state_rows(previous) == before_live, "staging rejection rolls back all slots, resume pointers, branches and typed state")
	store.fault = "content_upgrade"
	rejected = store.upgrade_content(previous)
	check(rejected == null and store.active_state == previous and store.catalog.content_hash == before_catalog and not store.busy, "post-publication transaction fault preserves old live authority and releases writer")
	check(endpoints() == before and state_rows(previous) == before_live, "actual transaction rollback removes provisional frozen content, snapshots, ledger rows and pointers")
	check(frozen_values(source_content, source_tables) == historic_frozen and sealed_values(historic_snapshots) == historic_payload, "both failures preserve every sealed old row and frozen value")
	store.fault = ""

func success_checks(previous: State) -> State:
	var upgraded: State = store.upgrade_content(previous)
	if not check(upgraded != null, "reviewed combat upgrade commits successfully after rollback retries: " + store.last_error): return null
	upgraded_snapshot = upgraded.snapshot.meta.snapshot_id; upgraded_content = upgraded.snapshot.content.content_snapshot_id; upgraded_hash = upgraded.snapshot.content.content_hash
	check(upgraded.world_id == previous.world_id and upgraded_content != source_content and upgraded_hash != source_hash, "new frozen content branch preserves world identity")
	check(int(store.catalog.rows("catalog_meta")[0].schema_version) == 5 and store.catalog.rows("weapon_defs").size() == 18 and store.catalog.rows("system_lighting_defs").size() == 10, "new branch actually exposes schema5 combat, drones and stellar lighting")
	var now: Dictionary = state_rows(upgraded)
	for table: String in State.TABLES:
		if table in ["equipment_state", "manufacture_input_state", "shop_stock_state", "shop_ship_stock_state"]: continue
		check(now[table] == old_state[table], "upgrade preserves every unchanged typed state table " + table)
	for prior_text: String in old_state["manufacture_input_state"]: check(now["manufacture_input_state"].has(prior_text), "existing real manufacturing input ledger remains exactly unchanged")
	check(now["shop_ship_stock_state"] == old_state["shop_ship_stock_state"], "existing hull market prices, inventories and refresh timers remain exactly unchanged")
	for item: D.ItemInstanceStateDto in upgraded.rows("item_instance_state"):
		var actual: Dictionary = {}
		for ledger: D.ManufactureInputStateDto in upgraded.rows("manufacture_input_state"):
			if ledger.item_instance_id == item.item_instance_id: actual[str(ledger.input_item_id)] = int(ledger.input_quantity)
		if item.item_instance_id in [purchased_id, manufactured_id]: check(actual == old_standard, "historical purchased and manufactured equipment retain the old material inputs " + item.item_instance_id)
	check(not old_standard.has("component_fire_control"), "old real needle-II fixture predates new fire-control material")
	for prior_text: String in old_state["equipment_state"]:
		var prior: Dictionary = JSON.parse_string(prior_text)
		var equipment: D.EquipmentStateDto = upgraded.find("equipment_state", "item_instance_id", str(prior.item_instance_id))
		# JSON parses every numeric field as float, including serialized BOOL
		# integers. Decode through the production DTO codec before constructing
		# the expected row; exact typed equality still covers every field.
		var expected_row: D.EquipmentStateDto = Codec.new().decode_row("equipment_state", prior) as D.EquipmentStateDto
		if not check(expected_row != null and equipment != null, "source and upgraded equipment decode into the same declared DTO"): continue
		var cycle: float = float(store.catalog.one("module_defs", "module_id", str(prior.module_def_id)).cycle_s)
		expected_row.cooldown_remaining_s = minf(expected_row.cooldown_remaining_s, cycle)
		expected_row.active_remaining_s = minf(expected_row.active_remaining_s, cycle)
		var expected: Dictionary = Codec.new().encode_row("equipment_state", expected_row)
		var actual: Dictionary = Codec.new().encode_row("equipment_state", equipment)
		var witness: Dictionary = {}
		for field: String in expected:
			witness[field] = {"parsed_value": prior[field], "parsed_type": type_string(typeof(prior[field])), "expected_value": expected[field], "expected_type": type_string(typeof(expected[field])), "actual_value": actual[field], "actual_type": type_string(typeof(actual[field]))}
		print("COMBAT_UPGRADE_V18_EQUIPMENT_TYPE_WITNESS " + JSON.stringify({"item_instance_id": equipment.item_instance_id, "fields": witness, "exact_typed_equal": actual == expected}))
		check(actual == expected, "cooldown and active duration clamp without altering equipment identity or switches")
	for prior_text: String in old_state["shop_stock_state"]:
		var prior: Dictionary = JSON.parse_string(prior_text)
		var stock: D.ShopStockStateDto
		for row: D.ShopStockStateDto in upgraded.rows("shop_stock_state"):
			if row.station_id == prior.station_id and row.item_def_id == prior.item_def_id: stock = row; break
		var definition: Dictionary = store.catalog.one("item_defs", "item_id", str(prior.item_def_id))
		check(stock != null and stock.quantity == int(prior.quantity) and stock.buyback_remaining_units == int(prior.buyback_remaining_units) and is_equal_approx(stock.refresh_remaining_s, float(prior.refresh_remaining_s)) and stock.ask_credit == int(definition.base_ask_credit) and stock.bid_credit == int(definition.base_bid_credit), "old market inventory/timer remain while exact quotes adopt new definitions " + str(prior.item_def_id))
	var added: int = upgraded.rows("shop_stock_state").size() - old_state["shop_stock_state"].size()
	check(added == 9 * store.catalog.rows("station_defs").size(), "nine new modules append real initial inventories at all ten stations")
	for definition: Dictionary in store.catalog.rows("station_stock_defs"):
		if not str(definition.item_id).begins_with("module_kinetic_lance_") and not str(definition.item_id).begins_with("module_kinetic_siege_") and not str(definition.item_id).begins_with("module_drone_swarm_"): continue
		var stock: D.ShopStockStateDto
		for row: D.ShopStockStateDto in upgraded.rows("shop_stock_state"):
			if row.station_id == definition.station_id and row.item_def_id == definition.item_id: stock = row; break
		check(stock != null and stock.quantity == int(definition.initial_units), "new weapon initial stock follows authoritative SQL " + str(definition.station_id) + "/" + str(definition.item_id))
	check(manual_slots() == historic_manual and frozen_values(source_content, source_tables) == historic_frozen and sealed_values(historic_snapshots) == historic_payload, "successful upgrade preserves all old manual pointers and all sealed state/frozen rows")
	var receipt: Array[Dictionary] = store._records("SELECT * FROM content_upgrade_record WHERE world_id=? AND source_snapshot_id=?", [previous.world_id, source_snapshot])
	check(receipt.size() == 1 and receipt[0].upgrade_kind == "combat_rebalance_v1" and receipt[0].upgraded_snapshot_id == upgraded_snapshot, "one exact source receipt identifies the reviewed combat branch")
	var lineage: Array[Dictionary] = store._records("SELECT parent_snapshot_id FROM snapshot_lineage WHERE child_snapshot_id=?", [upgraded_snapshot])
	check(lineage.size() == 1 and lineage[0].parent_snapshot_id == source_snapshot, "new branch links to its real sealed old source")
	var auto: Array[Dictionary] = store._records("SELECT current_snapshot_id,content_snapshot_id FROM save_slot WHERE world_id=? AND slot_kind='auto' AND slot_index=0", [previous.world_id])
	check(auto.size() == 1 and auto[0].current_snapshot_id == upgraded_snapshot and auto[0].content_snapshot_id == upgraded_content, "automatic slot atomically selects the upgraded state and definitions")
	var path: String = directory.path_join("content-upgrade-%s-%s-backup.db" % [previous.world_id, source_snapshot])
	backup_check(path, source_snapshot, source_content)
	backup_hash = FileAccess.get_sha256(path)
	var before: Dictionary = endpoints()
	check(store.upgrade_content(upgraded) == upgraded and endpoints() == before and FileAccess.get_sha256(path) == backup_hash, "repeating on current branch creates no receipt, snapshot or backup replacement")
	return upgraded

func reopen_and_replay() -> State:
	if game != null: game.dispose(); game = null
	store.close(); store = FaultStore.new(database_path)
	if not check(store.open(), "upgraded archive independently reopens from disk: " + store.last_error): return null
	var resumed: State = store.resume()
	check(resumed != null and resumed.snapshot.meta.snapshot_id == upgraded_snapshot and resumed.snapshot.content.content_hash == upgraded_hash, "resume after complete close restores the exact committed combat branch")
	var before: Dictionary = endpoints()
	var recovered: State = store.load(str(source_slot.slot_id), source_snapshot, int(source_slot.generation))
	if not check(recovered != null and recovered.snapshot.content.content_hash == source_hash and not store.catalog.table_names.has("weapon_behavior_defs"), "old manual endpoint still independently loads its own schema4 frozen rules"): return null
	check(state_rows(recovered) == old_state, "old manual restores every pre-upgrade state including old quotes and original ledgers")
	var after_load: Dictionary = endpoints()
	var reused: State = store.upgrade_content(recovered)
	check(reused != null and reused.snapshot.meta.snapshot_id == upgraded_snapshot and reused.snapshot.content.content_hash == upgraded_hash, "same historical manual source reuses its existing reviewed branch")
	check(endpoints()["save_snapshot_count"] == before["save_snapshot_count"] and endpoints()["content_snapshot_count"] == before["content_snapshot_count"] and endpoints()["content_upgrade_record"] == after_load["content_upgrade_record"], "historical replay creates no extra frozen branch, snapshot or receipt")
	check(manual_slots() == historic_manual and frozen_values(source_content, source_tables) == historic_frozen and sealed_values(historic_snapshots) == historic_payload, "close, recovery and replay preserve all immutable historical rows")
	return reused

func incompatible_fit_rejection() -> void:
	var recovered: State = store.load(str(source_slot.slot_id), source_snapshot, int(source_slot.generation))
	if not check(recovered != null, "recover old manual to prepare legal old cross-tier battery"): return
	game = Gameplay.new(); game.setup(recovered, store.catalog)
	var inventory: RefCounted = game.get("inventory")
	var warehouse: String = str(inventory.call("warehouse", "station_anchor_port"))
	var granted: Array = inventory.call("grant", warehouse, "module_thermal_sunline_ii", 1)
	var id: String = str(granted[0])
	if not check(bool(inventory.call("fit", id, 2, "weapon:2")), "old schema legally accepts thermal I and II on separate cruiser slots"): return
	if not check(store.save(recovered, "auto", 2), "old rules seal the incompatible-family fixture as a separate old endpoint: " + store.last_error): return
	var rejected_snapshot: String = recovered.snapshot.meta.snapshot_id
	var before: Dictionary = endpoints()
	var live: Dictionary = state_rows(recovered)
	var rejected: State = store.upgrade_content(recovered)
	check(rejected == null and store.last_error.contains("配装") and store.active_state == recovered and store.catalog.content_hash == source_hash, "new cross-tier family limit refuses upgrade with explicit old-archive guidance")
	check(endpoints() == before and state_rows(recovered) == live and recovered.find("equipment_state", "item_instance_id", id) != null, "incompatible upgrade preserves pointers, equipment, money and all live typed state")
	check(manual_slots() == historic_manual and frozen_values(source_content, source_tables) == historic_frozen and sealed_values(historic_snapshots) == historic_payload, "incompatible rejection cannot alter old manual slots or sealed history")
	var reloaded: State = store.load("snapshot:" + rejected_snapshot)
	check(reloaded != null and reloaded.find("equipment_state", "item_instance_id", id) != null, "refused old branch remains independently readable with both thermal devices")
	if reloaded == null: return
	game.dispose(); game = Gameplay.new(); game.setup(reloaded, store.catalog)
	check(bool(game.get("inventory").call("unfit", id)), "player can legally resolve the old family conflict by unloading one device")
	if check(store.save(reloaded, "auto", 2), "adjusted old branch saves before retry"):
		var adjusted: State = store.upgrade_content(reloaded)
		check(adjusted != null and adjusted.find("item_instance_state", "item_instance_id", id) != null and adjusted.find("equipment_state", "item_instance_id", id) == null, "retry after legal adjustment succeeds without deleting the unloaded device")
	check(manual_slots() == historic_manual, "conflict resolution still preserves every original and fixture manual endpoint")

func quality_capacity_reopen_checks() -> void:
	# This exercises the real new-rule save/load validator. Both modules are
	# production-granted and fitted on an ordinary hull; quality is an explicit
	# isolated instance fixture, not a replacement module definition.
	if game != null: game.dispose(); game = null
	var current: State = store.active_state
	if not check(current != null and store.catalog.table_names.has("weapon_behavior_defs"), "quality regression starts on a real upgraded schema5 branch"): return
	game = Gameplay.new(); game.setup(current, store.catalog)
	var inventory: RefCounted = game.get("inventory")
	var warehouse: String = str(inventory.call("warehouse", "station_anchor_port"))
	var armor_ids: Array = inventory.call("grant", warehouse, "module_armor_pressure_i", 1)
	var shield_ids: Array = inventory.call("grant", warehouse, "module_shield_lattice_i", 1)
	var armor_id: String = str(armor_ids[0])
	var shield_id: String = str(shield_ids[0])
	var armor: D.ItemInstanceStateDto = current.find("item_instance_state", "item_instance_id", armor_id)
	var shield: D.ItemInstanceStateDto = current.find("item_instance_state", "item_instance_id", shield_id)
	armor.quality_multiplier = 1.25; armor.durability = 72.0
	shield.quality_multiplier = 1.35; shield.durability = 68.0
	if not check(bool(inventory.call("fit", armor_id, 0, "structure:0")) and bool(inventory.call("fit", shield_id, 0, "utility:0")), "real ordinary cruiser legally installs high-quality armor and shield modules"): return
	var metrics: Dictionary = game.metrics(current.ship())
	var standard_armor_limit: float = float(store.catalog.one("ship_defs", "ship_id", current.ship().ship_def_id).armor_max)
	for modifier: Dictionary in store.catalog.rows("module_stat_modifiers"):
		if modifier.module_id == "module_armor_pressure_i" and modifier.stat_id == "armor_max" and modifier.operation == "add": standard_armor_limit += float(modifier.amount)
	current.ship().armor = float(metrics.armor_max) - 0.25
	current.ship().shield = float(metrics.shield_max) - 0.25
	var expected_armor: float = current.ship().armor
	var expected_shield: float = current.ship().shield
	check(expected_armor > standard_armor_limit, "saved legal HP exceeds the old quality-one validator limit and reproduces the rejected-reopen boundary")
	if not check(store.save(current, "auto", 1), "real SQLite seals legal HP near the quality-aware maximum: " + store.last_error): return
	game.dispose(); game = null; store.close(); store = FaultStore.new(database_path)
	if not check(store.open(), "quality-aware save independently reopens after complete Store close: " + store.last_error): return
	var loaded: State = store.resume()
	if not check(loaded != null, "schema5 resume validates real quality-scaled HP instead of the legacy quality-one path: " + store.last_error): return
	armor = loaded.find("item_instance_state", "item_instance_id", armor_id)
	shield = loaded.find("item_instance_state", "item_instance_id", shield_id)
	check(armor != null and shield != null and armor.quality_multiplier == 1.25 and shield.quality_multiplier == 1.35 and armor.durability == 72.0 and shield.durability == 68.0, "SQLite reopen preserves both actual module qualities and durability exactly")
	check(loaded.ship().armor == expected_armor and loaded.ship().shield == expected_shield, "SQLite reopen preserves exact near-maximum armor and shield HP without healing or clipping")
	game = Gameplay.new(); game.setup(loaded, store.catalog)
	var disabled: D.ActionResultDto = game.act("set_module_enabled", armor_id, 1, "off")
	check(disabled.phase == T.ActionPhase.APPLIED, "production equipment command disables the high-quality passive armor module")
	var disabled_metrics: Dictionary = game.metrics(loaded.ship())
	var disabled_armor: float = loaded.ship().armor
	check(disabled_armor == float(disabled_metrics.armor_max) and disabled_armor < expected_armor, "disabling removes the entire quality-scaled armor capacity and clamps existing HP")
	var before: Dictionary = endpoints()
	loaded.ship().armor = float(disabled_metrics.armor_max) + 0.25
	check(not store.save(loaded, "auto", 1) and endpoints() == before, "new-schema authority rejects virtual armor from a disabled module and leaves durable endpoints unchanged")
	loaded.ship().armor = disabled_armor
	if not check(store.save(loaded, "auto", 1), "valid disabled-module state seals with the lowered actual capacity"): return
	game.dispose(); game = null; store.close(); store = FaultStore.new(database_path)
	if not check(store.open(), "disabled high-quality module archive independently reopens"): return
	loaded = store.resume()
	if not check(loaded != null, "disabled-module state resumes under the new schema5 validator"): return
	var equipment: D.EquipmentStateDto = loaded.find("equipment_state", "item_instance_id", armor_id)
	armor = loaded.find("item_instance_state", "item_instance_id", armor_id)
	check(equipment != null and not equipment.enabled and armor != null and armor.quality_multiplier == 1.25 and loaded.ship().armor == disabled_armor and loaded.ship().shield == expected_shield, "reopen preserves disabled state, quality and lowered HP without retaining virtual passive capacity")
	check(manual_slots() == historic_manual and frozen_values(source_content, source_tables) == historic_frozen, "new quality regressions cannot modify historical manual recovery or frozen definitions")

func _run() -> void:
	var script: String = OS.get_environment("XJ_UPGRADE_V18_SCRIPT").replace("\\", "/")
	var tmp: String = script.get_base_dir().get_base_dir().path_join("tmp") if not script.is_empty() else ProjectSettings.globalize_path("res://../jiaoben/tmp").replace("\\", "/")
	var prefix: String = tmp.path_join("combat-upgrade-v18")
	directory = OS.get_environment("XJ_UPGRADE_V18_DIRECTORY").replace("\\", "/")
	legacy_source = OS.get_environment("XJ_UPGRADE_V18_LEGACY_SOURCE").replace("\\", "/")
	if not check(directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == prefix, "migration output is one fresh scoped tmp/combat-upgrade-v18 child"): finish(); return
	if not check(legacy_source.is_absolute_path() and legacy_source.begins_with(tmp + "/") and not legacy_source.contains("..") and FileAccess.file_exists(legacy_source), "supplied closed legacy source is an existing project-owned tmp archive"): finish(); return
	database_path = directory.path_join("progress.db")
	if not check(not FileAccess.file_exists(database_path), "migration test refuses to open an existing destination archive"): finish(); return
	input_hash = FileAccess.get_sha256(legacy_source)
	if not check(DirAccess.make_dir_recursive_absolute(directory) == OK and DirAccess.copy_absolute(legacy_source, database_path) == OK, "copy the closed test archive before any writable Store open"): finish(); return
	var witness: Object = read_only(database_path)
	if not check(witness != null, "copied legacy archive independently opens with read-only SQL before schema migration"): finish(); return
	witness.query("SELECT format_version FROM database_meta")
	check(int(witness.query_result[0].format_version) == 6, "input is the real released format6 archive")
	witness.query("SELECT * FROM save_slot WHERE slot_kind='manual'")
	original_manual = canonical(witness.query_result.duplicate(true))
	witness.query("SELECT snapshot_id,world_id,content_snapshot_id,status,simulation_tick FROM save_snapshot WHERE status='sealed' ORDER BY snapshot_id")
	var original_headers: Array[String] = canonical(witness.query_result.duplicate(true))
	witness.query("SELECT content_snapshot_id,content_hash,frozen_adapter_version FROM content_snapshot WHERE status='sealed' ORDER BY content_snapshot_id")
	var original_content: Array[String] = canonical(witness.query_result.duplicate(true))
	witness.close_db()
	store = FaultStore.new(database_path)
	if not check(store.open(), "current Store opens copied real archive and executes reviewed schema migration: " + store.last_error): finish(); return
	check(int(store._records("SELECT format_version FROM database_meta")[0].format_version) == 7 and int(store._records("PRAGMA user_version")[0].values()[0]) == 7, "format6 upgrades to format7 with matching SQLite user_version")
	check(int(store._records("SELECT count(*) AS n FROM migration_history")[0].n) == 10, "ten reviewed migration entries are registered")
	backup_check(directory.path_join("migration-format6-backup.db"), "", "", 6)
	check(canonical(store._records("SELECT snapshot_id,world_id,content_snapshot_id,status,simulation_tick FROM save_snapshot WHERE status='sealed' ORDER BY snapshot_id")) == original_headers and canonical(store._records("SELECT content_snapshot_id,content_hash,frozen_adapter_version FROM content_snapshot WHERE status='sealed' ORDER BY content_snapshot_id")) == original_content and manual_slots() == original_manual, "schema upgrade preserves all old sealed identities and original manual slots")
	var previous: State = store.resume()
	if not check(previous != null, "copied released world resumes its actual old frozen content: " + store.last_error): finish(); return
	if not check(int(store.catalog.rows("catalog_meta")[0].schema_version) == 4 and not store.catalog.table_names.has("weapon_behavior_defs"), "resume retains schema4 rules before explicit combat upgrade"): finish(); return
	if not prepare_legacy_fixture(previous): finish(); return
	failure_checks(previous)
	if success_checks(previous) == null: finish(); return
	if reopen_and_replay() == null: finish(); return
	incompatible_fit_rejection()
	quality_capacity_reopen_checks()
	check(store._records("PRAGMA integrity_check")[0].values()[0] == "ok" and store._records("PRAGMA foreign_key_check").is_empty(), "successful, failed and recovered branches retain SQLite physical and relational integrity")
	finish()

func finish() -> void:
	if game != null: game.dispose(); game = null
	if store != null: store.close(); store = null
	if not input_hash.is_empty(): check(FileAccess.get_sha256(legacy_source) == input_hash, "original supplied test archive bytes remain unchanged")
	var result: String = "PASS" if failures.is_empty() else "FAIL"
	print("COMBAT_UPGRADE_V18_FINAL_JSON " + JSON.stringify({"result": result, "checks": checks, "failures": failures.size(), "failure_labels": failures, "database_path": database_path, "legacy_source": legacy_source, "legacy_source_sha256": input_hash, "source_snapshot": source_snapshot, "old_content_hash": source_hash, "upgraded_snapshot": upgraded_snapshot, "new_content_hash": upgraded_hash, "backup_sha256": backup_hash, "fixture": "real-closed-v013-test-archive-copy-with-explicit-old-rule-preparation"}))
	print("COMBAT_UPGRADE_V18_RESULT %s checks=%d failures=%d" % [result, checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
