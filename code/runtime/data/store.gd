class_name XJGameStore
extends RefCounted
## One paused, bounded serial writer. Only COMMIT is durable success.
signal status_changed(phase: String, message: String)
const State = preload("res://runtime/state.gd")
const Catalog = preload("res://runtime/data/catalog.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Initial = preload("res://runtime/data/initial_state.gd")
const Validation = preload("res://runtime/data/validation.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const Types = preload("res://contracts/contract_types.gd")
const MIGRATIONS: Array[String] = ["001_core.sql", "002_frozen_catalog.sql", "003_seal_validation.sql", "004_immutability.sql", "005_singleplayer_expansion.sql", "006_signal_and_gate_lifetime.sql", "007_profile_resume.sql", "008_paid_engine_family.sql", "009_encounters_and_salvage.sql", "010_combat_and_lighting.sql", "011_space_locations.sql"]
const RULE_CODE_VERSION: String = "singleplayer_full_v1"
const ADAPTER_VERSION: String = "frozen_catalog_v0_4_r2"
const ADAPTERS: Dictionary = {"frozen_catalog_v0_3": "res://database/progress/catalog_adapter_v0_3.sql", "frozen_catalog_v0_4": "res://database/progress/catalog_adapter_v0_4.sql", "frozen_catalog_v0_4_r2": "res://database/progress/catalog_adapter_v0_4_r2.sql", "frozen_catalog_v0_5": "res://database/progress/catalog_adapter_v0_5.sql", "frozen_catalog_v0_6": "res://database/progress/catalog_adapter_v0_6.sql", "frozen_catalog_v0_7": "res://database/progress/catalog_adapter_v0_7.sql"}
const ASSET_PATH: String = "res://assets/manifest.json"
const ASSET_MANIFESTS: Dictionary = {"art-full-v2": ASSET_PATH, "art-full-v1": "res://assets/legacy_art_full_v1/manifest.json", "placeholder-b-v1": "res://assets/placeholders/manifest.json"}
const LEGACY_VISUAL_BYTES: Dictionary = {"res://runtime/visuals/visual_effects.gd": "res://assets/legacy_art_full_v1/visual_effects.gd.txt", "res://runtime/visuals/visual_effect_node.gd": "res://assets/legacy_art_full_v1/visual_effect_node.gd.txt"}
var path: String = "user://database/progress.db"
var catalog_path: String = "res://data/catalog.db"
var catalog: Catalog
var last_error: String = ""
var phase: String = "CLOSED"
var busy: bool = false
var active_state: State
var staging_catalog: Catalog
var _db: Object
var _source: Catalog
var _codec: Codec = Codec.new()
var _asset_hash: String = ""
var _asset_version: String = ""

func _init(database_path: String = "user://database/progress.db") -> void:
	path = database_path

func open() -> bool:
	close()
	last_error = ""
	_source = Catalog.new()
	if not _source.open(catalog_path) or not _source.verify_reviewed():
		return _fail(_source.last_error)
	if not _verify_assets(): return false
	catalog = _source
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return _fail("Cannot create progress directory")
	_db = ClassDB.instantiate("SQLite")
	_db.path = path
	_db.foreign_keys = true
	_db.verbosity_level = 0
	if not _db.open_db(): return _fail("Progress open failed")
	if not _q("PRAGMA journal_mode=DELETE; PRAGMA synchronous=EXTRA; PRAGMA busy_timeout=2000;"): return false
	if not _migrate(): return false
	if not _validate_registered_schema(): return false
	if not _q("PRAGMA integrity_check") or _db.query_result[0].values()[0] != "ok": return _fail("Progress integrity check failed")
	if not _q("PRAGMA foreign_key_check") or not _db.query_result.is_empty(): return _fail("Progress FK check failed")
	_set_phase("READY")
	return true

func close() -> void:
	if _db != null:
		_db.close_db()
		_db = null
	if catalog != null and catalog != _source: catalog.close()
	if _source != null: _source.close()
	active_state = null
	staging_catalog = null
	busy = false
	phase = "CLOSED"

func new_world(name: String, seed: int, prepare: Callable = Callable()) -> State:
	if not _begin_operation("CREATING"): return null
	if not _q("BEGIN IMMEDIATE; PRAGMA defer_foreign_keys=ON;"):
		_end_operation(false)
		return null
	var content_id: String = _freeze()
	if content_id.is_empty():
		_rollback()
		return null
	var state: State = Initial.new().create(_source, seed)
	state.world_id = new_id("world")
	state.session_id = new_id("session")
	state.epoch = 1
	state.capture_sequence = 1
	var profile_id: String = "local-profile"
	if _records("SELECT * FROM profile WHERE profile_id=?", [profile_id]).is_empty():
		if not _insert("profile", {"profile_id": profile_id, "display_name": "本地玩家", "created_utc": _utc()}):
			_rollback()
			return null
	if not _insert("world", {"world_id": state.world_id, "profile_id": profile_id, "display_name": name, "mode": "offline", "seed": seed, "initial_content_snapshot_id": content_id, "created_utc": _utc()}) or not _insert("runtime_session", {"world_id": state.world_id, "session_id": state.session_id, "epoch": 1}):
		_rollback()
		return null
	_copy_content(state, _records("SELECT * FROM content_snapshot WHERE content_snapshot_id=?", [content_id])[0])
	_prepare_meta(state, "initial", "")
	var frozen: Catalog = Catalog.new()
	if not _verify_frozen(content_id, frozen):
		frozen.close()
		_rollback()
		return null
	staging_catalog = frozen
	if prepare.is_valid() and prepare.call(state) != true:
		staging_catalog = null
		frozen.close()
		_rollback("STAGING_FAILED")
		return null
	if not _write_snapshot(state) or not _publish(state, "auto", 0, 0) or not _insert("world_initialization_grant", {"world_id": state.world_id, "grant_id": new_id("grant"), "initial_snapshot_id": state.snapshot.meta.snapshot_id}) or not _q("COMMIT"):
		staging_catalog = null
		frozen.close()
		_rollback()
		return null
	catalog = frozen
	staging_catalog = null
	active_state = state
	_end_operation(true)
	return state

func save(state: State, slot_kind: String = "auto", slot_index: int = 0) -> bool:
	return _save(state, slot_kind, slot_index, slot_kind, "")

func save_endpoint(state: State, reason: String, transfer_id: String, slot_kind: String = "auto", slot_index: int = 0) -> bool:
	if reason not in ["travel_origin", "travel_destination"] or transfer_id.is_empty(): return _fail("Invalid transfer endpoint")
	return _save(state, slot_kind, slot_index, reason, transfer_id)

func clone_state(state: State) -> State:
	return _codec.clone(state)

func set_transfer_barrier(state: State, transfer_id: String) -> bool:
	if busy or not _active_context(state): return _fail("STALE_EPOCH or BUSY")
	var value: Variant = null if transfer_id.is_empty() else transfer_id
	return _q("UPDATE runtime_session SET transfer_barrier_id=? WHERE world_id=? AND session_id=? AND epoch=?", [value, state.world_id, state.session_id, state.epoch]) and _changes() == 1

func _save(state: State, slot_kind: String, slot_index: int, reason: String, transfer_id: String) -> bool:
	if not _active_context(state): return _fail("STALE_EPOCH or WRONG_WORLD or STALE_SEQUENCE")
	if not _begin_operation("SAVING"): return false
	var candidate: State = clone_state(state)
	if candidate == null:
		_end_operation(false)
		return _fail(_codec.last_error)
	var slot_id: String = _slot_id(state.world_id, slot_kind, slot_index)
	var selected: Array[Dictionary] = _records("SELECT generation FROM save_slot WHERE slot_id=?", [slot_id])
	var generation: int = 0 if selected.is_empty() else int(selected[0].generation)
	candidate.capture_sequence += 1
	var parent_id: String = candidate.snapshot.meta.snapshot_id
	_prepare_meta(candidate, reason, transfer_id)
	if not _q("BEGIN IMMEDIATE; PRAGMA defer_foreign_keys=ON;"):
		_end_operation(false)
		return false
	if not _write_snapshot(candidate): return _rollback()
	if not parent_id.is_empty() and not _insert("snapshot_lineage", {"child_snapshot_id": candidate.snapshot.meta.snapshot_id, "parent_snapshot_id": parent_id}): return _rollback()
	if not _publish(candidate, slot_kind, slot_index, generation): return _rollback()
	if not _checkpoint("pointer"): return _rollback("Injected failure after slot pointer")
	if not _q("COMMIT"): return _rollback()
	state.capture_sequence = candidate.capture_sequence
	state.snapshot.meta = candidate.snapshot.meta
	active_state = state
	_end_operation(true)
	return true

func load(slot_id: String, expected_snapshot: String = "", expected_generation: int = -1, prepare: Callable = Callable()) -> State:
	if not _begin_operation("LOADING"): return null
	if not _q("BEGIN"):
		_end_operation(false)
		return null
	var selection: Array[Dictionary]
	if slot_id.begins_with("snapshot:"):
		selection = _records("SELECT snapshot_id AS current_snapshot_id,world_id,content_snapshot_id,0 AS generation FROM save_snapshot WHERE snapshot_id=? AND status='sealed'", [slot_id.trim_prefix("snapshot:")])
	else:
		selection = _records("SELECT * FROM save_slot WHERE slot_id=?", [slot_id])
	if selection.is_empty():
		_rollback("Missing save slot")
		return null
	var slot: Dictionary = selection[0]
	if (not expected_snapshot.is_empty() and slot.current_snapshot_id != expected_snapshot) or (expected_generation >= 0 and slot.generation != expected_generation):
		_rollback("STALE_SELECTION")
		return null
	var old: Dictionary = _records("SELECT * FROM runtime_session WHERE world_id=?", [slot.world_id])[0]
	var metadata: Dictionary = _records("SELECT * FROM content_snapshot WHERE content_snapshot_id=?", [slot.content_snapshot_id])[0]
	var frozen: Catalog = Catalog.new()
	if not _verify_frozen(slot.content_snapshot_id, frozen) or not ASSET_MANIFESTS.has(metadata.asset_manifest_version) or not _verify_assets(ASSET_MANIFESTS.get(metadata.asset_manifest_version, "")) or metadata.rules_code_version != _rule_version(frozen) or metadata.asset_manifest_version != _asset_version or metadata.asset_manifest_sha256 != _asset_hash:
		frozen.close()
		_rollback("CONTENT_OR_ASSET_MISMATCH: " + last_error)
		return null
	var saves: Array[Dictionary] = _records("SELECT * FROM save_snapshot WHERE snapshot_id=? AND status='sealed'", [slot.current_snapshot_id])
	if saves.is_empty():
		_rollback("Unsealed/missing snapshot")
		return null
	var state: State = State.new()
	state.world_id = slot.world_id
	state.session_id = new_id("session")
	state.epoch = int(old.epoch) + 1
	state.capture_sequence = 0
	_copy_content(state, metadata)
	_fill_object(state.snapshot.meta, saves[0])
	for table in State.TABLES:
		var sql_rows: Array[Dictionary] = _records('SELECT * FROM "' + table + '" WHERE snapshot_id=?', [slot.current_snapshot_id])
		for values in sql_rows:
			var row: RefCounted = _codec.decode_row(table, values)
			if row == null or not state.add(table, row):
				frozen.close()
				_rollback("DTO mapping failed: " + _codec.last_error)
				return null
	var validator: Validation = Validation.new()
	var legacy_capacity: bool = not frozen.table_names.has("weapon_behavior_defs") and str(metadata.content_version) != "v0.5-integrity"
	if not validator.validate(state, frozen, legacy_capacity) or not _q("COMMIT"):
		frozen.close()
		_rollback(validator.last_error)
		return null
	# No transaction is held while root prepares a staging scene. The caller
	# freezes simulation/requests before selection and keeps old world alive.
	staging_catalog = frozen
	if prepare.is_valid() and prepare.call(state) != true:
		staging_catalog = null
		frozen.close()
		_fail("STAGING_FAILED")
		_end_operation(false)
		return null
	if not _q("BEGIN IMMEDIATE") or not _q("UPDATE runtime_session SET session_id=?,epoch=epoch+1,loaded_snapshot_id=?,resume_snapshot_id=?,transfer_barrier_id=NULL,last_committed_sequence=0 WHERE world_id=? AND session_id=? AND epoch=?", [state.session_id, slot.current_snapshot_id, slot.current_snapshot_id, slot.world_id, old.session_id, old.epoch]) or _changes() != 1 or not _set_profile_world(state.world_id) or not _q("COMMIT"):
		staging_catalog = null
		frozen.close()
		_rollback("Session CAS failed")
		return null
	if catalog != null and catalog != _source: catalog.close()
	catalog = frozen
	staging_catalog = null
	active_state = state
	_end_operation(true)
	return state

func list_slots() -> Array[Dictionary]:
	return _records("SELECT s.*,w.display_name AS world_name FROM save_slot s JOIN world w USING(world_id) ORDER BY s.updated_utc DESC,s.slot_id") if _db != null else []

func upgrade_content(state: State, prepare: Callable = Callable()) -> State:
	# A reviewed additive content branch never edits frozen definitions or sealed
	# state. Existing manual slots and a closed backup remain recoverable.
	if not _active_context(state):
		_fail("STALE_EPOCH while upgrading content")
		return null
	var has_encounters: bool = catalog.table_names.has("encounter_defs")
	var has_echo_recipe: bool = not catalog.one("recipe_defs", "recipe_id", "recipe_sensor_core_echo").is_empty()
	var source_has_echo_recipe: bool = not _source.one("recipe_defs", "recipe_id", "recipe_sensor_core_echo").is_empty()
	var spatial_upgrade: bool = _source.table_names.has("site_defs")
	var rebalance: bool = _source.table_names.has("weapon_behavior_defs") and int(catalog.rows("catalog_meta")[0].schema_version) < 5
	if spatial_upgrade:
		if catalog.content_hash == _source.content_hash: return state
		if not _reviewed_space_upgrade(catalog, _source): return null
	elif _source.table_names.has("weapon_behavior_defs"):
		if catalog.content_hash == _source.content_hash: return state
		if not _reviewed_combat_upgrade(catalog, _source): return null
	else:
		if has_encounters and (has_echo_recipe or not source_has_echo_recipe): return state
		if not _source.table_names.has("encounter_defs") or not _additive_content(catalog, _source): return null
	var existing_upgrade: Array[Dictionary] = _records("SELECT r.upgraded_snapshot_id FROM content_upgrade_record r JOIN content_snapshot c ON c.content_snapshot_id=r.new_content_id WHERE r.world_id=? AND r.source_snapshot_id=? AND c.content_hash=?", [state.world_id, state.snapshot.meta.snapshot_id, _source.content_hash])
	if not existing_upgrade.is_empty(): return self.load("snapshot:" + str(existing_upgrade[0].upgraded_snapshot_id), "", -1, prepare)
	var destination: String = ProjectSettings.globalize_path(path).get_base_dir().path_join("content-upgrade-%s-%s-backup.db" % [state.world_id, state.snapshot.meta.snapshot_id])
	if not backup(destination): return null
	if not _begin_operation("UPGRADING"): return null
	var candidate: State = clone_state(state)
	if candidate == null:
		_end_operation(false)
		return null
	if not _q("BEGIN IMMEDIATE; PRAGMA defer_foreign_keys=ON;"):
		_end_operation(false)
		return null
	var content_id: String = _freeze()
	if content_id.is_empty():
		_rollback()
		return null
	var source_snapshot: String = state.snapshot.meta.snapshot_id
	var old_content: String = state.snapshot.content.content_snapshot_id
	_copy_content(candidate, _records("SELECT * FROM content_snapshot WHERE content_snapshot_id=?", [content_id])[0])
	if spatial_upgrade and not _spatial_candidate(candidate):
		_rollback("空间规则升级未通过；原存档与备份已保留。" + last_error)
		return null
	if rebalance and not _rebalance_candidate(candidate):
		_rollback("新版规则配装检查未通过；旧档保留，请调整配装后重试。" + last_error)
		return null
	for definition in _source.rows("encounter_defs"):
		if candidate.find("encounter_state", "encounter_id", definition.encounter_id) == null:
			var encounter: Dtos.EncounterStateDto = Dtos.EncounterStateDto.new()
			encounter.encounter_id = definition.encounter_id
			var living: bool = false
			for member in _source.rows("encounter_members"):
				if member.encounter_id != definition.encounter_id: continue
				var npc: RefCounted = candidate.find("npc_state", "spawn_id", member.spawn_id)
				if npc != null:
					encounter.generation = maxi(encounter.generation, npc.generation)
					living = living or npc.alive
					encounter.respawn_remaining_s = maxf(encounter.respawn_remaining_s, npc.respawn_remaining_s)
			if living: encounter.respawn_remaining_s = 0.0
			candidate.add("encounter_state", encounter)
	if rebalance or spatial_upgrade:
		var validator: Validation = Validation.new()
		if not validator.validate(candidate, _source):
			_rollback("新版配装不兼容，已保留旧档；请调整后重试。" + validator.last_error)
			return null
	candidate.capture_sequence += 1
	_prepare_meta(candidate, "migration", "")
	var frozen: Catalog = Catalog.new()
	if not _verify_frozen(content_id, frozen):
		frozen.close(); _rollback(); return null
	staging_catalog = frozen
	if prepare.is_valid() and prepare.call(candidate) != true:
		staging_catalog = null; frozen.close(); _rollback("CONTENT_UPGRADE_STAGING_FAILED"); return null
	var selection: Array[Dictionary] = _records("SELECT generation FROM save_slot WHERE slot_id=?", [_slot_id(state.world_id, "auto", 0)])
	var generation: int = 0 if selection.is_empty() else int(selection[0].generation)
	if not _write_snapshot(candidate) or not _insert("snapshot_lineage", {"child_snapshot_id": candidate.snapshot.meta.snapshot_id, "parent_snapshot_id": source_snapshot}) or not _insert("content_upgrade_record", {"world_id": state.world_id, "source_snapshot_id": source_snapshot, "upgraded_snapshot_id": candidate.snapshot.meta.snapshot_id, "old_content_id": old_content, "new_content_id": content_id, "upgrade_kind": "strategic_space_v1" if spatial_upgrade else "combat_rebalance_v1" if rebalance else "additive_encounters_v1", "created_utc": _utc()}) or not _publish(candidate, "auto", 0, generation) or not _checkpoint("content_upgrade") or not _q("COMMIT"):
		staging_catalog = null; frozen.close(); _rollback("CONTENT_UPGRADE_FAILED: " + last_error); return null
	if catalog != _source: catalog.close()
	catalog = frozen; staging_catalog = null; active_state = candidate
	_end_operation(true)
	return candidate

func _reviewed_space_upgrade(previous: Catalog, next: Catalog) -> bool:
	var before: Dictionary = previous.rows("catalog_meta")[0]
	var after: Dictionary = next.rows("catalog_meta")[0]
	if before.pack_id != after.pack_id or int(before.schema_version) not in [3, 4, 5] or int(after.schema_version) != 6 or after.content_version != "v0.7-space" or after.ruleset_version != "singleplayer_space_v3":
		return _fail("Unreviewed spatial rules upgrade; original world preserved")
	if int(before.schema_version) < 5: return _reviewed_combat_upgrade(previous, next, true)
	for table: String in previous.table_names:
		if table == "catalog_meta": continue
		if not next.table_names.has(table) or Catalog.schema_signature(previous.column_info[table], table) != Catalog.schema_signature(next.column_info[table], table): return _fail("Spatial upgrade changes previous schema: " + table)
		var keys: Array[String] = []
		for column: Dictionary in previous.column_info[table]:
			if int(column.pk) > 0: keys.append(str(column.name))
		var index: Dictionary = {}
		for entry: Dictionary in next.rows(table): index[_content_key(entry, keys)] = entry
		if previous.rows(table).size() != index.size(): return _fail("Spatial upgrade changes definition count: " + table)
		for entry: Dictionary in previous.rows(table):
			var key: String = _content_key(entry, keys)
			if not index.has(key) or entry != index[key]: return _fail("Spatial upgrade changes protected definition: " + table)
	for view: String in previous.view_sql:
		if not next.view_sql.has(view) or next.view_sql[view] != previous.view_sql[view]: return _fail("Spatial upgrade changes reviewed derived view: " + view)
	return true

func _spatial_candidate(candidate: State) -> bool:
	# Old encoded local coordinates remain exact. Only an explicit site context
	# is added; no credit, equipment, cargo, progress or random stream is changed.
	var space: Script = preload("res://runtime/space_coordinates.gd")
	for ship in candidate.rows("ship_state"):
		var site: String = ""
		if ship.has_station_id:
			var station: Dictionary = _source.one("station_defs", "station_id", ship.station_id)
			site = space.site_for_anchor(_source, str(station.get("station_anchor_id", "")))
		else: site = space.infer_legacy_site(_source, ship.sector_id, Vector3(ship.pos_x, ship.pos_y, ship.pos_z))
		if site.is_empty(): return _fail("Cannot map existing ship to a reviewed site")
		# Retired/destroyed hulls are immutable history, never physical actors.
		# Their distant original pose must not permanently prevent world upgrade.
		if ship.status in [Types.ShipStatus.FLYING, Types.ShipStatus.DOCKED] and not _legacy_within_site(ship, site): return false
		space.assign(candidate, "ship", ship.ship_instance_id, site)
	for npc in candidate.rows("npc_state"):
		var spawn: Dictionary = _source.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
		var site: String = space.site_for_anchor(_source, str(spawn.get("anchor_id", "")))
		if site.is_empty(): return _fail("Cannot map existing NPC to a reviewed site")
		if not _legacy_within_site(npc, site): return false
		space.assign(candidate, "npc", npc.npc_instance_id, site)
	for container in candidate.rows("container_state"):
		if container.kind != Types.ContainerKind.WRECK: continue
		var site: String = space.infer_legacy_site(_source, container.sector_id, Vector3(container.pos_x, container.pos_y, container.pos_z))
		if site.is_empty(): return _fail("Cannot map existing wreck to a reviewed site")
		if not _legacy_within_site(container, site): return false
		space.assign(candidate, "wreck", container.container_id, site)
	return true

func _legacy_within_site(row: RefCounted, site_id: String) -> bool:
	var site: Dictionary = _source.one("site_defs", "site_id", site_id)
	var offset := Vector3(row.pos_x, row.pos_y, row.pos_z) - Vector3(site.pivot_x_m, site.pivot_y_m, site.pivot_z_m)
	if offset.length() > float(site.local_radius_m): return _fail("旧档位置超出新版局部空间；请在旧规则中返航后重试。原位置未被移动。")
	return true

func _reviewed_combat_upgrade(previous: Catalog, next: Catalog, including_space: bool = false) -> bool:
	var before: Dictionary = previous.rows("catalog_meta")[0]
	var after: Dictionary = next.rows("catalog_meta")[0]
	var destination_reviewed: bool = int(after.schema_version) == 6 and after.content_version == "v0.7-space" and after.ruleset_version == "singleplayer_space_v3" if including_space else int(after.schema_version) == 5 and after.content_version == "v0.6-combat" and after.ruleset_version == "singleplayer_combat_v2"
	if before.pack_id != after.pack_id or int(before.schema_version) not in [3, 4] or not destination_reviewed:
		return _fail("Unreviewed combat rules upgrade; original world preserved")
	# Only reviewed combat/economic columns may change. Identity, ownership,
	# spatial content, physics budgets and every existing definition remain.
	var mutable: Dictionary = {
		"item_defs": ["base_ask_credit", "base_bid_credit"],
		"module_defs": ["cycle_s", "range_m", "energy_eu", "heat_hu"],
		"weapon_defs": ["raw_damage", "projectile_speed_mps"],
		"npc_behavior_defs": ["fire_mode", "projectile_speed_mps"],
		"ship_loadout_items": ["module_id"], "loadout_supply_defs": ["quantity"],
		"recipe_defs": ["service_fee_credit"], "recipe_inputs": ["quantity"],
		"recycle_outputs": ["quantity"]}
	var extensible: Array[String] = ["item_defs", "module_defs", "weapon_defs", "module_activation_priority", "recipe_defs", "recipe_inputs", "recycle_outputs", "module_salvage_recipe_defs", "station_stock_defs", "recipe_access_defs", "presentation_defs", "module_tech_defs", "npc_defs", "anchor_defs", "npc_spawn_defs", "npc_patrol_points"]
	for table: String in previous.table_names:
		if table == "catalog_meta": continue
		if not next.table_names.has(table) or Catalog.schema_signature(previous.column_info[table], table) != Catalog.schema_signature(next.column_info[table], table):
			return _fail("Combat upgrade changes unreviewed schema: " + table)
		var keys: Array[String] = []
		for column: Dictionary in previous.column_info[table]:
			if int(column.pk) > 0: keys.append(str(column.name))
		var index: Dictionary = {}
		for entry: Dictionary in next.rows(table): index[_content_key(entry, keys)] = entry
		if previous.rows(table).size() != next.rows(table).size() and not extensible.has(table):
			return _fail("Combat upgrade appends unreviewed rules: " + table)
		for entry: Dictionary in previous.rows(table):
			var key: String = _content_key(entry, keys)
			if not index.has(key): return _fail("Combat upgrade removes existing definition: " + table + ":" + key)
			for field: String in entry:
				if entry[field] != index[key][field] and field not in mutable.get(table, []):
					return _fail("Combat upgrade changes protected definition: " + table + ":" + field)
	for view: String in previous.view_sql:
		if not next.view_sql.has(view) or next.view_sql[view] != previous.view_sql[view]:
			return _fail("Combat upgrade changes reviewed derived view: " + view)
	return true

func _rebalance_candidate(candidate: State) -> bool:
	# Materialize the old standard provenance for purchased/looted equipment.
	# Genuine manufactured ledgers remain untouched. Changing a recipe must not
	# turn an existing item into newly invented recycling materials.
	for item: Dtos.ItemInstanceStateDto in candidate.rows("item_instance_state"):
		var recorded: bool = false
		for ledger: Dtos.ManufactureInputStateDto in candidate.rows("manufacture_input_state"):
			if ledger.item_instance_id == item.item_instance_id: recorded = true; break
		if recorded or item.salvage_recipe_id.is_empty(): continue
		for ingredient: Dictionary in catalog.rows("recipe_inputs"):
			if ingredient.recipe_id != item.salvage_recipe_id: continue
			var ledger: Dtos.ManufactureInputStateDto = Dtos.ManufactureInputStateDto.new()
			ledger.item_instance_id = item.item_instance_id
			ledger.input_item_id = ingredient.item_id
			ledger.input_quantity = int(ingredient.quantity)
			candidate.add("manufacture_input_state", ledger)
	# Reprice station inventories, not player assets. Existing stock and consumed
	# buyback allowance remain bounded; newly introduced goods receive seed stock.
	for definition: Dictionary in _source.rows("station_stock_defs"):
		var stock: Dtos.ShopStockStateDto
		for row: Dtos.ShopStockStateDto in candidate.rows("shop_stock_state"):
			if row.station_id == definition.station_id and row.item_def_id == definition.item_id:
				stock = row; break
		if stock == null:
			stock = Dtos.ShopStockStateDto.new()
			stock.station_id = definition.station_id; stock.item_def_id = definition.item_id
			stock.quantity = int(definition.initial_units)
			stock.buyback_remaining_units = int(definition.buyback_units_per_refresh)
			stock.refresh_remaining_s = float(_source.one("station_defs", "station_id", definition.station_id).stock_refresh_s)
			candidate.add("shop_stock_state", stock)
		stock.quantity = mini(stock.quantity, int(definition.hard_cap_units))
		stock.buyback_remaining_units = mini(stock.buyback_remaining_units, int(definition.buyback_units_per_refresh))
		var item: Dictionary = _source.one("item_defs", "item_id", definition.item_id)
		stock.ask_credit = int(item.base_ask_credit); stock.bid_credit = int(item.base_bid_credit)
		stock.refresh_remaining_s = minf(stock.refresh_remaining_s, float(_source.one("station_defs", "station_id", definition.station_id).stock_refresh_s))
	for stock: Dtos.ShopShipStockStateDto in candidate.rows("shop_ship_stock_state"):
		var definition: Dictionary = _source.one("ship_defs", "ship_id", stock.ship_def_id)
		stock.ask_credit = int(definition.base_ask_credit); stock.bid_credit = int(definition.base_bid_credit)
		stock.refresh_remaining_s = minf(stock.refresh_remaining_s, float(_source.one("station_defs", "station_id", stock.station_id).stock_refresh_s))
	for equipment: Dtos.EquipmentStateDto in candidate.rows("equipment_state"):
		var module: Dictionary = _source.one("module_defs", "module_id", equipment.module_def_id)
		equipment.cooldown_remaining_s = minf(equipment.cooldown_remaining_s, float(module.cycle_s))
		equipment.active_remaining_s = minf(equipment.active_remaining_s, float(module.cycle_s))
	# Preserve paid history, qualities, durability, IDs, progress, money and RNG.
	# Never refill a damaged ship when maximums or active modifiers change.
	var game: RefCounted = load("res://runtime/gameplay.gd").new()
	# Metrics require only read-only definitions and inventory totals. Full setup
	# refreshes missions/supplies/spawns and must not run inside this transform.
	game.set("state", candidate)
	game.set("catalog", _source)
	var rules: Dictionary = {}
	for rule: Dictionary in _source.rows("rule_parameters"):
		rules[rule.parameter_id] = rule.value_integer if rule.value_integer != null else rule.value_real
	game.set("_rules", rules)
	game.set("inventory", load("res://runtime/gameplay/inventory.gd").new(game))
	for ship: Dtos.ShipStateDto in candidate.rows("ship_state"):
		var metrics: Dictionary = game.call("metrics", ship)
		for field: String in ["shield", "armor", "hull", "energy", "heat"]:
			ship.set(field, minf(float(ship.get(field)), float(metrics[field + "_max"])))
	game.call("dispose")
	return true

func _additive_content(previous: Catalog, next: Catalog) -> bool:
	var before_meta: Dictionary = previous.rows("catalog_meta")[0]
	var after_meta: Dictionary = next.rows("catalog_meta")[0]
	if before_meta.pack_id != after_meta.pack_id or after_meta.content_version not in ["v0.5-encounters", "v0.5-integrity"]: return _fail("Unreviewed additive content upgrade")
	var extensible: Array[String] = ["npc_defs", "anchor_defs", "npc_spawn_defs", "npc_patrol_points", "recipe_defs", "recipe_inputs", "recipe_access_defs"]
	for table in previous.table_names:
		if table == "catalog_meta": continue
		if not next.table_names.has(table) or Catalog.schema_signature(previous.column_info[table], table) != Catalog.schema_signature(next.column_info[table], table): return _fail("Content upgrade changes existing schema: " + table)
		var keys: Array[String] = []
		for column in previous.column_info[table]:
			if int(column.pk) > 0: keys.append(str(column.name))
		var index: Dictionary = {}
		for entry in next.rows(table): index[_content_key(entry, keys)] = entry
		if next.rows(table).size() != previous.rows(table).size() and not extensible.has(table): return _fail("Content upgrade appends unreviewed existing rules: " + table)
		for entry in previous.rows(table):
			var key: String = _content_key(entry, keys)
			if not index.has(key) or index[key] != entry: return _fail("Content upgrade changes existing definition: " + table + ":" + key)
		if table in ["recipe_defs", "recipe_inputs", "recipe_access_defs"]:
			var prior_keys: Dictionary = {}
			for entry in previous.rows(table): prior_keys[_content_key(entry, keys)] = true
			for entry in next.rows(table):
				if not prior_keys.has(_content_key(entry, keys)) and str(entry.recipe_id) != "recipe_sensor_core_echo": return _fail("Content upgrade appends unreviewed recipe: " + table)
	for name in previous.view_sql:
		if not next.view_sql.has(name) or next.view_sql[name] != previous.view_sql[name]: return _fail("Content upgrade changes existing derived view: " + str(name))
	return true

static func _content_key(entry: Dictionary, keys: Array[String]) -> String:
	var result: String = ""
	var fields: Array = keys if not keys.is_empty() else entry.keys()
	for key in fields:
		var value: String = str(entry[key])
		result += "%d:%s" % [value.length(), value]
	return result

func resume(prepare: Callable = Callable()) -> State:
	if busy or _db == null:
		_fail("Store is busy/closed")
		return null
	var selection: Array[Dictionary] = _records("SELECT r.resume_snapshot_id FROM profile_resume p JOIN runtime_session r ON r.world_id=p.world_id JOIN save_snapshot s ON s.snapshot_id=r.resume_snapshot_id WHERE p.profile_id='local-profile' AND s.status='sealed'")
	if selection.is_empty():
		_fail("No resume snapshot")
		return null
	return self.load("snapshot:" + str(selection[0].resume_snapshot_id), "", -1, prepare)

func preferences() -> Dictionary:
	if _db == null: return {}
	var stored: Array[Dictionary] = _records("SELECT * FROM profile_preference WHERE profile_id='local-profile'")
	return stored[0] if not stored.is_empty() else {"profile_id": "local-profile", "mouse_sensitivity": 0.002, "master_volume": 1.0, "vfx_intensity": 1.0, "quality_mode": "medium"}

func set_preference(field: String, value: Variant) -> bool:
	if busy or field not in ["mouse_sensitivity", "master_volume", "vfx_intensity", "quality_mode"]: return _fail("Invalid/busy preference update")
	if field == "quality_mode":
		if value not in ["low", "medium", "high"]: return _fail("Invalid quality mode")
	elif (not value is int and not value is float) or not is_finite(float(value)): return _fail("Invalid preference number")
	elif field == "mouse_sensitivity" and (float(value) <= 0.0 or float(value) >= 1e100): return _fail("Invalid mouse sensitivity")
	elif field in ["master_volume", "vfx_intensity"] and (float(value) < 0.0 or float(value) > 1.0): return _fail("Preference outside [0,1]")
	var defaults: Dictionary = preferences()
	if not _q("BEGIN IMMEDIATE"): return false
	if _records("SELECT profile_id FROM profile WHERE profile_id='local-profile'").is_empty():
		if not _insert("profile", {"profile_id": "local-profile", "display_name": "本地玩家", "created_utc": _utc()}): return _rollback()
	if not _q("INSERT OR IGNORE INTO profile_preference VALUES(?,?,?,?,?)", ["local-profile", defaults.mouse_sensitivity, defaults.master_volume, defaults.vfx_intensity, defaults.quality_mode]) or not _q('UPDATE profile_preference SET "' + field + '"=? WHERE profile_id=?', [value, "local-profile"]) or not _q("COMMIT"): return _rollback()
	last_error = ""
	return true

func backup(destination: String = "") -> bool:
	if busy or _db == null: return _fail("Backup writer is busy/closed")
	last_error = ""
	if destination.is_empty(): destination = ProjectSettings.globalize_path(path).get_base_dir().path_join("backup-latest.db")
	var temporary: String = destination + ".partial.db"
	DirAccess.remove_absolute(temporary)
	if not _db.backup_to(temporary): return _fail("SQLite backup failed")
	if not FileAccess.file_exists(temporary): return _fail("SQLite backup target not published")
	var copy: Object = ClassDB.instantiate("SQLite")
	copy.path = temporary
	# A filesystem backup uses SQLite's native filesystem VFS. The addon's
	# read_only option selects Godot's packed-resource VFS, which is needed for
	# res:// catalogs but can reject external paths in exported applications.
	# query_only prohibits writes during validation; the closed backup exists
	# before opening, so validation cannot silently create an empty replacement.
	copy.read_only = false
	copy.foreign_keys = true
	copy.verbosity_level = 0
	var valid: bool = copy.open_db() and copy.query("PRAGMA query_only=ON") and copy.query("PRAGMA integrity_check") and copy.query_result[0].values()[0] == "ok" and copy.query("PRAGMA foreign_key_check") and copy.query_result.is_empty()
	if valid:
		copy.query("SELECT content_snapshot_id,content_hash,frozen_adapter_version FROM content_snapshot WHERE status='sealed'")
		for metadata in copy.query_result.duplicate(true):
			var verifier: Catalog = Catalog.new()
			if not ADAPTERS.has(metadata.frozen_adapter_version) or not verifier.open_frozen(copy, metadata.content_snapshot_id, ADAPTERS[metadata.frozen_adapter_version]) or verifier.content_hash != metadata.content_hash:
				valid = false
			verifier.close()
			if not valid: break
	copy.close_db()
	if not valid:
		DirAccess.remove_absolute(temporary)
		return _fail("Backup validation failed")
	if DirAccess.rename_absolute(temporary, destination) != OK: return _fail("Backup atomic publication failed")
	return true

func prune(keep_recent: int = 3) -> bool:
	if busy or keep_recent < 1: return _fail("Invalid retention request")
	if not _q("BEGIN IMMEDIATE"): return false
	for world in _records("SELECT world_id FROM world"):
		var protected: Array[String] = []
		for row in _records("SELECT current_snapshot_id AS id FROM save_slot WHERE world_id=? UNION SELECT initial_snapshot_id FROM world_initialization_grant WHERE world_id=? UNION SELECT loaded_snapshot_id FROM runtime_session WHERE world_id=? UNION SELECT resume_snapshot_id FROM runtime_session WHERE world_id=?", [world.world_id, world.world_id, world.world_id, world.world_id]):
			if row.id != null: protected.append(row.id)
		for row in _records("SELECT snapshot_id FROM save_snapshot WHERE world_id=? AND status='sealed' ORDER BY rowid DESC LIMIT ?", [world.world_id, keep_recent]): protected.append(row.snapshot_id)
		for row in _records("SELECT source_snapshot_id AS id FROM content_upgrade_record WHERE world_id=? UNION SELECT upgraded_snapshot_id FROM content_upgrade_record WHERE world_id=?", [world.world_id, world.world_id]): protected.append(row.id)
		for row in _records("SELECT snapshot_id FROM save_snapshot WHERE world_id=?", [world.world_id]):
			if not protected.has(row.snapshot_id) and not _q("DELETE FROM save_snapshot WHERE snapshot_id=?", [row.snapshot_id]): return _rollback()
	return _q("COMMIT")

func _migrate() -> bool:
	var existing: Array[Dictionary] = _records("SELECT name FROM sqlite_schema WHERE type='table'")
	if not existing.is_empty():
		var meta: Array[Dictionary] = _records("SELECT application_id,format_version FROM database_meta")
		if meta.is_empty() or meta[0].application_id != "xingjizhanjian" or meta[0].format_version not in [1,2,3,4,5,6,7,8]: return _fail("Unsupported progress format; preserved")
		var applied_count: int = int(meta[0].format_version) + 3
		if int(_records("SELECT count(*) AS n FROM migration_history")[0].n) != applied_count: return _fail("Migration history/format mismatch; preserved")
		for name in MIGRATIONS.slice(0, applied_count):
			var records: Array[Dictionary] = _records("SELECT sql_sha256 FROM migration_history WHERE migration_id=?", [name])
			if records.is_empty() or records[0].sql_sha256 != FileAccess.get_sha256("res://database/progress/" + name): return _fail("Migration checksum mismatch; preserved: " + name)
		if applied_count < MIGRATIONS.size():
			if not self.backup(ProjectSettings.globalize_path(path).get_base_dir().path_join("migration-format%d-backup.db" % meta[0].format_version)): return false
			if not _q("BEGIN IMMEDIATE; PRAGMA defer_foreign_keys=ON;"): return false
			for name in MIGRATIONS.slice(applied_count):
				var source_path: String = "res://database/progress/" + name
				if not _q(FileAccess.get_file_as_string(source_path)) or not _insert("migration_history", {"migration_id": name, "sql_sha256": FileAccess.get_sha256(source_path), "applied_utc": _utc()}) or not _checkpoint("migration:" + name): return _rollback("Migration interrupted: " + name)
			if not _q("COMMIT"): return _rollback()
		return true
	if not _q("BEGIN IMMEDIATE; PRAGMA defer_foreign_keys=ON;"): return false
	for name in MIGRATIONS:
		var source_path: String = "res://database/progress/" + name
		if not _q(FileAccess.get_file_as_string(source_path)) or not _insert("migration_history", {"migration_id": name, "sql_sha256": FileAccess.get_sha256(source_path), "applied_utc": _utc()}) or not _checkpoint("migration:" + name): return _rollback("Migration interrupted: " + name)
	return _q("PRAGMA user_version=8; COMMIT;")

func _freeze() -> String:
	var hash_value: String = _source.logical_hash()
	if hash_value != _source.content_hash or not _verify_assets(): return ""
	var rule_version: String = _rule_version(_source)
	var adapter_version: String = _adapter_version(_source)
	var existing: Array[Dictionary] = _records("SELECT content_snapshot_id FROM content_snapshot WHERE content_hash=? AND rules_code_version=? AND asset_manifest_version=? AND asset_manifest_sha256=? AND frozen_adapter_version=? AND status='sealed'", [hash_value, rule_version, _asset_version, _asset_hash, adapter_version])
	if not existing.is_empty():
		var checked: Catalog = Catalog.new()
		if not _verify_frozen(existing[0].content_snapshot_id, checked): return ""
		checked.close()
		return existing[0].content_snapshot_id
	var metadata: Dictionary = _source.rows("catalog_meta")[0]
	var content_id: String = new_id("content")
	if not _insert("content_snapshot", {"content_snapshot_id": content_id, "content_hash": hash_value, "pack_id": metadata.pack_id, "content_version": metadata.content_version, "catalog_schema_version": metadata.schema_version, "ruleset_version": metadata.ruleset_version, "rules_code_version": rule_version, "asset_manifest_version": _asset_version, "asset_manifest_sha256": _asset_hash, "frozen_adapter_version": adapter_version, "created_utc": _utc(), "status": "building"}): return ""
	for table in _source.table_names:
		var data: Array[Dictionary] = _source.rows(table)
		for record in data:
			var copied: Dictionary = record.duplicate(true)
			copied["content_snapshot_id"] = content_id
			if not _insert("frozen_" + table, copied): return ""
		if not _insert("content_table_manifest", {"content_snapshot_id": content_id, "table_name": table, "schema_signature": Catalog.schema_signature(_source.column_info[table], table), "row_count": data.size()}): return ""
	for name in _source.view_sql:
		var text: String = _source.view_sql[name]
		if not _insert("content_view_manifest", {"content_snapshot_id": content_id, "view_name": name, "reviewed_source_sql": text, "sql_sha256": text.sha256_text()}): return ""
	var checked: Catalog = Catalog.new()
	if not _verify_frozen(content_id, checked): return ""
	checked.close()
	if not _q("UPDATE content_snapshot SET status='sealed' WHERE content_snapshot_id=?", [content_id]): return ""
	return content_id

func _verify_frozen(content_id: String, result: Catalog) -> bool:
	var metadata: Array[Dictionary] = _records("SELECT * FROM content_snapshot WHERE content_snapshot_id=?", [content_id])
	if metadata.is_empty() or not ADAPTERS.has(metadata[0].frozen_adapter_version): return _fail("Unsupported frozen adapter")
	if not result.open_frozen(_db, content_id, ADAPTERS[metadata[0].frozen_adapter_version]): return _fail(result.last_error)
	if result.content_hash != metadata[0].content_hash: return _fail("Frozen content identity mismatch")
	var manifest: Array[Dictionary] = _records("SELECT * FROM content_table_manifest WHERE content_snapshot_id=? ORDER BY table_name COLLATE BINARY", [content_id])
	if manifest.size() != result.table_names.size(): return _fail("Frozen table registry mismatch")
	for index in range(manifest.size()):
		var entry: Dictionary = manifest[index]
		if entry.table_name != result.table_names[index] or entry.schema_signature != Catalog.schema_signature(result.column_info[entry.table_name], entry.table_name) or entry.row_count != result.rows(entry.table_name).size(): return _fail("Frozen table manifest mismatch")
	var views: Array[Dictionary] = _records("SELECT * FROM content_view_manifest WHERE content_snapshot_id=?", [content_id])
	if views.size() != result.view_sql.size(): return _fail("Frozen view registry mismatch")
	for entry in views:
		if not result.view_sql.has(entry.view_name) or entry.reviewed_source_sql != result.view_sql[entry.view_name] or entry.sql_sha256 != str(entry.reviewed_source_sql).sha256_text(): return _fail("Frozen view version mismatch")
	return true

func _write_snapshot(state: State) -> bool:
	var validator: Validation = Validation.new()
	var definitions: Catalog = staging_catalog if staging_catalog != null else _source if state.snapshot.meta.reason == "initial" else catalog
	if not validator.validate(state, definitions): return _fail(validator.last_error)
	var values: Dictionary = _plain_object(state.snapshot.meta)
	values.erase("has_transfer_id")
	if not state.snapshot.meta.has_transfer_id: values.transfer_id = null
	values.status = "building"
	if not _insert("save_snapshot", values): return false
	for table in State.TABLES:
		for row in state.rows(table):
			var encoded: Dictionary = _codec.encode_row(table, row)
			if encoded.is_empty(): return _fail(_codec.last_error)
			encoded.snapshot_id = state.snapshot.meta.snapshot_id
			encoded.world_id = state.world_id
			encoded.content_snapshot_id = state.snapshot.content.content_snapshot_id
			if not _insert(table, encoded): return false
	if not _checkpoint("state"): return _fail("Injected failure after state rows")
	if not _q("PRAGMA foreign_key_check") or not _db.query_result.is_empty(): return _fail("Snapshot reference closure failed")
	if not _q("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id=?", [state.snapshot.meta.snapshot_id]): return false
	if not _checkpoint("seal"): return _fail("Injected failure after seal")
	return true

func _publish(state: State, slot_kind: String, slot_index: int, generation: int) -> bool:
	var meta: Dtos.SnapshotMetaDto = state.snapshot.meta
	var profile_id: String = _records("SELECT profile_id FROM world WHERE world_id=?", [state.world_id])[0].profile_id
	var slot_id: String = _slot_id(state.world_id, slot_kind, slot_index)
	if generation == 0:
		if not _insert("save_slot", {"slot_id": slot_id, "profile_id": profile_id, "world_id": state.world_id, "slot_kind": slot_kind, "slot_index": slot_index, "label": slot_kind, "current_snapshot_id": meta.snapshot_id, "content_snapshot_id": meta.content_snapshot_id, "writer_session_id": state.session_id, "writer_epoch": state.epoch, "generation": 1, "updated_utc": meta.saved_utc}): return false
	else:
		if not _q("UPDATE save_slot SET current_snapshot_id=?,content_snapshot_id=?,writer_session_id=?,writer_epoch=?,generation=generation+1,updated_utc=? WHERE slot_id=? AND world_id=? AND generation=?", [meta.snapshot_id, meta.content_snapshot_id, state.session_id, state.epoch, meta.saved_utc, slot_id, state.world_id, generation]) or _changes() != 1: return _fail("Save slot CAS conflict")
	return _q("UPDATE runtime_session SET last_committed_sequence=?,resume_snapshot_id=? WHERE world_id=? AND session_id=? AND epoch=?", [meta.capture_sequence, meta.snapshot_id, state.world_id, state.session_id, state.epoch]) and _changes() == 1 and _set_profile_world(state.world_id)

func _prepare_meta(state: State, reason: String, transfer_id: String) -> void:
	var tick: int = state.snapshot.meta.simulation_tick
	state.snapshot.meta = Dtos.SnapshotMetaDto.new()
	var meta: Dtos.SnapshotMetaDto = state.snapshot.meta
	meta.snapshot_id = new_id("snapshot")
	meta.world_id = state.world_id
	meta.content_snapshot_id = state.snapshot.content.content_snapshot_id
	meta.writer_session_id = state.session_id
	meta.writer_epoch = state.epoch
	meta.save_request_id = new_id("save")
	meta.capture_sequence = state.capture_sequence
	meta.saved_utc = _utc()
	meta.simulation_tick = tick
	meta.reason = reason
	meta.has_transfer_id = not transfer_id.is_empty()
	meta.transfer_id = transfer_id

func _copy_content(state: State, record: Dictionary) -> void:
	_fill_object(state.snapshot.content, record)

func _fill_object(object: RefCounted, record: Dictionary) -> void:
	var properties: Dictionary = Codec._properties(object)
	for column in record:
		if not properties.has(column): continue
		if properties.has("has_" + column): object.set("has_" + column, record[column] != null)
		if record[column] != null: object.set(column, record[column])

func _plain_object(object: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for key in Codec._properties(object): result[key] = object.get(key)
	return result

func _verify_assets(manifest_path: String = ASSET_PATH) -> bool:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not value is Dictionary or not value.has("manifest_sha256"): return _fail("Asset manifest missing")
	var manifest: Dictionary = value
	var expected: String = manifest.manifest_sha256
	manifest.erase("manifest_sha256")
	# Godot JSON parses every JSON number as float; this schema declares the
	# format_version field INTEGER. Restore its declared type before canonical
	# encoding (1.0 would differ from Python's authoritative integer 1).
	if not manifest.has("format_version") or float(manifest.format_version) != floor(float(manifest.format_version)): return _fail("Invalid asset manifest format")
	manifest.format_version = int(manifest.format_version)
	var actual: String = JSON.stringify(manifest, "", true, true).sha256_text()
	if actual != expected: return _fail("Canonical asset manifest mismatch")
	var seen: Dictionary = {}
	for entry in manifest.resources:
		var resource_path: String = entry.resource_path
		# V1's original code bytes remain archival data, never executable scripts.
		# Current visual code belongs to V2; unchanged V1 model/audio paths stay live.
		var checked_path: String = str(LEGACY_VISUAL_BYTES.get(resource_path, resource_path)) if str(manifest.asset_version) == "art-full-v1" else resource_path
		if not resource_path.begins_with("res://") or resource_path.contains("..") or seen.has(resource_path) or not FileAccess.file_exists(checked_path) or FileAccess.get_sha256(checked_path) != entry.sha256: return _fail("Asset resource path/hash mismatch: " + resource_path)
		seen[resource_path] = true
	_asset_hash = actual
	_asset_version = manifest.asset_version
	return true

func _active_context(state: State) -> bool:
	if state == null or active_state == null or state.world_id != active_state.world_id or state.session_id != active_state.session_id or state.epoch != active_state.epoch: return false
	var current: Array[Dictionary] = _records("SELECT session_id,epoch,last_committed_sequence FROM runtime_session WHERE world_id=?", [state.world_id])
	return not current.is_empty() and current[0].session_id == state.session_id and current[0].epoch == state.epoch and int(current[0].last_committed_sequence) == state.capture_sequence

func _insert(table: String, values: Dictionary) -> bool:
	var columns: Array[String] = []
	var marks: Array[String] = []
	var bindings: Array = []
	for column in values:
		columns.append('"' + str(column) + '"')
		marks.append("?")
		bindings.append(values[column])
	return _q('INSERT INTO "' + table + '" (' + ','.join(columns) + ') VALUES (' + ','.join(marks) + ')', bindings)

func _records(sql: String, bindings: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _q(sql, bindings): return result
	for row in _db.query_result: result.append(row.duplicate(true))
	return result

func _q(sql: String, bindings: Array = []) -> bool:
	if _db == null or not _db.query_with_bindings(sql, bindings):
		return _fail(str(_db.error_message) if _db != null else "Store is closed")
	return true

func _changes() -> int:
	var result: Array[Dictionary] = _records("SELECT changes() AS n")
	return int(result[0].n) if not result.is_empty() else 0

func _rollback(message: String = "") -> bool:
	var saved_error: String = message if not message.is_empty() else last_error
	_db.query("ROLLBACK")
	last_error = saved_error
	_end_operation(false)
	return false

func _begin_operation(value: String) -> bool:
	if _db == null or busy: return _fail("Store is closed/BUSY")
	last_error = ""
	busy = true
	_set_phase(value)
	return true

func _end_operation(success: bool) -> void:
	busy = false
	_set_phase("READY" if success else "FAILED")

func _set_phase(value: String) -> void:
	phase = value
	status_changed.emit(phase, last_error)

func _fail(message: String) -> bool:
	last_error = message
	return false

func _checkpoint(_point: String) -> bool:
	return true

static func new_id(prefix: String = "id") -> String:
	return prefix + "-" + Crypto.new().generate_random_bytes(16).hex_encode()

static func _slot_id(world: String, kind: String, index: int) -> String:
	return "%s:%s:%d" % [world, kind, index]

static func _utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

static func _rule_version(definitions: Catalog) -> String:
	if definitions.table_names.has("site_defs"): return "singleplayer_space_v3"
	if definitions.table_names.has("weapon_behavior_defs"): return "singleplayer_combat_v2"
	return "singleplayer_b_v1" if int(definitions.rows("catalog_meta")[0].schema_version) <= 2 else RULE_CODE_VERSION

static func _adapter_version(definitions: Catalog) -> String:
	if definitions.table_names.has("site_defs"): return "frozen_catalog_v0_7"
	if int(definitions.rows("catalog_meta")[0].schema_version) <= 2: return "frozen_catalog_v0_3"
	if definitions.table_names.has("weapon_behavior_defs"): return "frozen_catalog_v0_6"
	if definitions.table_names.has("encounter_defs"): return "frozen_catalog_v0_5"
	return ADAPTER_VERSION if definitions.table_names.has("signal_unlock_rewards") else "frozen_catalog_v0_4"

func _validate_registered_schema() -> bool:
	var actual: Array[String] = []
	for entry in _records("SELECT name FROM sqlite_schema WHERE type='table' AND name LIKE '%_state' ORDER BY name COLLATE BINARY"):
		actual.append(entry.name)
	var expected: Array[String] = State.TABLES.duplicate()
	expected.sort()
	if actual != expected: return _fail("Unregistered/missing progress state table")
	for table in expected:
		var sql_columns: Array[String] = []
		for column in _records('PRAGMA table_info("' + table + '")'):
			if column.name not in ["snapshot_id", "world_id", "content_snapshot_id"]: sql_columns.append(column.name)
		var encoded: Dictionary = _codec.encode_row(table, State.new_row(table))
		var dto_columns: Array[String] = []
		for key in encoded: dto_columns.append(key)
		sql_columns.sort()
		dto_columns.sort()
		if sql_columns != dto_columns: return _fail("Progress SQL/DTO column mismatch: " + table)
	return true

func _set_profile_world(world: String) -> bool:
	return _q("INSERT INTO profile_resume(profile_id,world_id,activated_utc) SELECT profile_id,world_id,? FROM world WHERE world_id=? ON CONFLICT(profile_id) DO UPDATE SET world_id=excluded.world_id,activated_utc=excluded.activated_utc", [_utc(), world])
