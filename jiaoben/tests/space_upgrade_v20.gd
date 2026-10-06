extends Node
## Real Store/SQLite and exact released schema5 catalog in one fresh tmp child.
## Progress, asset quality, damage and NPC deaths are explicit test preparation;
## these checks do not claim a natural campaign or use a personal archive.
const Store = preload("res://runtime/data/store.gd")
const Catalog = preload("res://runtime/data/catalog.gd")
const State = preload("res://runtime/state.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Space = preload("res://runtime/space_coordinates.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const LEGACY_SHA256: String = "b0f212d5afb09279d6d2e906cbf0a4f675c252f682a10a0a5a39270d035067d8"
const LEGACY_CONTENT_HASH: String = "532d3d3f098c15ca312fcace9593951091cfe0ebf51c9c499bbb5194bb94529d"
var checks: int = 0
var failures: Array[String] = []
var directory: String = ""
var database_path: String = ""
var legacy_catalog: String = ""
var store: FaultStore
var game: Gameplay
var source_snapshot: String = ""
var source_content: String = ""
var source_hash: String = ""
var source_slot: Dictionary = {}
var source_tables: Array[String] = []
var original_state: Dictionary = {}
var original_manual: Array[String] = []
var original_frozen: Dictionary = {}
var old_snapshot_ids: Array[String] = []
var original_sealed: Dictionary = {}
var upgraded_snapshot: String = ""
var upgraded_content: String = ""
var upgraded_hash: String = ""
var backup_sha256: String = ""
var expected_sites: Dictionary = {}
var distant_history: Dictionary = {}

class FaultStore extends Store:
	var fault: String = ""
	func _checkpoint(point: String) -> bool:
		return point != fault

func _ready() -> void:
	get_tree().set_meta("xj_space_upgrade_v20_diagnostic", true)
	get_tree().create_timer(240.0).timeout.connect(func(): check(false, "watchdog"); finish())
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

func state_values(state: State, include_spatial: bool = true) -> Dictionary:
	var values: Dictionary = {}
	for table: String in State.TABLES:
		if table == "spatial_state" and not include_spatial: continue
		var encoded: Array[Dictionary] = []
		for row: RefCounted in state.rows(table): encoded.append(Codec.new().encode_row(table, row))
		values[table] = canonical(encoded)
	return values

func pointers() -> Dictionary:
	var values: Dictionary = {}
	for table: String in ["save_slot", "runtime_session", "profile_resume", "content_upgrade_record", "snapshot_lineage"]:
		values[table] = canonical(store._records("SELECT * FROM " + table))
	for table: String in ["save_snapshot", "content_snapshot", "spatial_state", "content_table_manifest", "content_view_manifest"]:
		values[table] = int(store._records("SELECT count(*) AS n FROM " + table)[0].n)
	return values

func manual_slots() -> Array[String]:
	return canonical(store._records("SELECT * FROM save_slot WHERE slot_kind='manual'"))

func frozen_values() -> Dictionary:
	var result: Dictionary = {}
	for table: String in source_tables:
		result[table] = canonical(store._records('SELECT * FROM "frozen_' + table + '" WHERE content_snapshot_id=?', [source_content]))
	for table: String in ["content_snapshot", "content_table_manifest", "content_view_manifest"]:
		result[table] = canonical(store._records('SELECT * FROM "' + table + '" WHERE content_snapshot_id=?', [source_content]))
	return result

func sealed_values() -> Dictionary:
	var result: Dictionary = {}
	for table: String in State.TABLES + ["save_snapshot"]:
		var records: Array[Dictionary] = []
		for id: String in old_snapshot_ids: records.append_array(store._records('SELECT * FROM "' + table + '" WHERE snapshot_id=?', [id]))
		result[table] = canonical(records)
	return result

func witness(path: String) -> Object:
	if not FileAccess.file_exists(path) or not path.begins_with(directory + "/"): return null
	var db: Object = ClassDB.instantiate("SQLite")
	db.path = path; db.read_only = false; db.foreign_keys = true; db.verbosity_level = 0
	if not db.open_db(): return null
	if not db.query("PRAGMA query_only=ON"):
		db.close_db()
		return null
	return db

func verify_backup(snapshot: String, content: String) -> String:
	var path: String = directory.path_join("content-upgrade-%s-%s-backup.db" % [store.active_state.world_id, snapshot])
	if not check(FileAccess.file_exists(path), "closed source-specific backup exists"): return ""
	var db: Object = witness(path)
	if not check(db != null, "backup opens independently with read-only SQL in scoped tmp"): return ""
	db.query("PRAGMA integrity_check")
	check(db.query_result.size() == 1 and db.query_result[0].values()[0] == "ok", "backup has SQLite physical integrity")
	db.query("PRAGMA foreign_key_check")
	check(db.query_result.is_empty(), "backup has relational reference closure")
	db.query_with_bindings("SELECT status,content_snapshot_id FROM save_snapshot WHERE snapshot_id=?", [snapshot])
	check(db.query_result.size() == 1 and db.query_result[0].status == "sealed" and db.query_result[0].content_snapshot_id == content, "backup retains exact sealed pre-space source")
	for table: String in State.TABLES:
		if table == "spatial_state": continue
		db.query_with_bindings('SELECT * FROM "' + table + '" WHERE snapshot_id=?', [snapshot])
		check(canonical(db.query_result.duplicate(true)) == canonical(store._records('SELECT * FROM "' + table + '" WHERE snapshot_id=?', [snapshot])), "backup retains every old sealed table " + table)
	db.close_db()
	return FileAccess.get_sha256(path)

func transport_failure(native: Object, reconstructed: Catalog, label: String) -> Catalog:
	check(false, label)
	if native != null: native.close_db()
	if reconstructed != null: reconstructed.close()
	return null

func transport_legacy_catalog() -> Catalog:
	# Test-only transport for both source and exported PCK. The external fixed-
	# hash fixture uses SQLite's native VFS under query_only. Its values enter a
	# memory Catalog built only from the shipped reviewed v0_6 adapter, exactly
	# as open_frozen does. No source-provided DDL executes and no runtime fallback
	# is installed in Catalog, Store or the SQLite addon.
	if not check(FileAccess.file_exists(legacy_catalog) and FileAccess.get_sha256(legacy_catalog) == LEGACY_SHA256, "native transport starts with exact immutable released fixture"): return null
	var native: Object = ClassDB.instantiate("SQLite")
	native.path = legacy_catalog; native.read_only = false; native.foreign_keys = true; native.verbosity_level = 0
	if not check(native.open_db(), "test-only native SQLite opens existing external catalog"): return null
	if not native.query("PRAGMA query_only=ON"): return transport_failure(native, null, "native source query_only cannot be enabled")
	if not native.query("PRAGMA query_only") or native.query_result.size() != 1 or int(native.query_result[0].values()[0]) != 1:
		return transport_failure(native, null, "external source must be query_only before reading")
	check(true, "native source connection confirms query_only read protection")
	if not native.query("PRAGMA integrity_check") or native.query_result.size() != 1 or native.query_result[0].values()[0] != "ok":
		return transport_failure(native, null, "native source physical integrity failed")
	if not native.query("PRAGMA foreign_key_check") or not native.query_result.is_empty():
		return transport_failure(native, null, "native source foreign-key integrity failed")
	var reconstructed: Catalog = Catalog.new()
	reconstructed.adapter_path = Catalog.COMBAT_ADAPTER_PATH
	var memory: Object = ClassDB.instantiate("SQLite")
	memory.path = ":memory:"; memory.read_only = false; memory.foreign_keys = true; memory.verbosity_level = 0
	reconstructed.set("_db", memory)
	if not memory.open_db() or not memory.query(FileAccess.get_file_as_string(reconstructed.adapter_path)):
		return transport_failure(native, reconstructed, "shipped reviewed v0_6 memory adapter cannot open")
	memory.query("SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name COLLATE BINARY")
	var expected_tables: Array = memory.query_result.duplicate(true)
	if not native.query("SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name COLLATE BINARY") or native.query_result != expected_tables:
		return transport_failure(native, reconstructed, "old catalog has an unreviewed table registry")
	if not memory.query("BEGIN; PRAGMA defer_foreign_keys=ON;"):
		return transport_failure(native, reconstructed, "memory reconstruction transaction cannot begin")
	for entry: Dictionary in expected_tables:
		var table: String = str(entry.name)
		memory.query('PRAGMA table_info("' + table + '")')
		var columns: Array = memory.query_result.duplicate(true)
		if not native.query('PRAGMA table_info("' + table + '")') or Catalog.schema_signature(native.query_result, table) != Catalog.schema_signature(columns, table):
			return transport_failure(native, reconstructed, "old source schema differs from reviewed adapter: " + table)
		var selection: Array[String] = []
		var marks: Array[String] = []
		for column: Dictionary in columns:
			selection.append('"' + str(column.name) + '"'); marks.append("?")
		if not native.query('SELECT ' + ','.join(selection) + ' FROM "' + table + '"'):
			return transport_failure(native, reconstructed, "old source values cannot be read: " + table)
		for record: Dictionary in native.query_result.duplicate(true):
			var values: Array = []
			for column: Dictionary in columns: values.append(record[column.name])
			if not memory.query_with_bindings('INSERT INTO "' + table + '" VALUES (' + ','.join(marks) + ')', values):
				return transport_failure(native, reconstructed, "old value cannot enter reviewed memory schema: " + table)
	if not memory.query("COMMIT") or not reconstructed.refresh() or not reconstructed.verify_reviewed():
		return transport_failure(native, reconstructed, "reconstructed old Catalog fails production schema/hash verification: " + reconstructed.last_error)
	if not native.query("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name COLLATE BINARY"):
		return transport_failure(native, reconstructed, "old source view registry cannot be read")
	var source_views: Dictionary = {}
	for view: Dictionary in native.query_result: source_views[str(view.name)] = str(view.sql)
	if source_views != reconstructed.view_sql or reconstructed.content_hash != LEGACY_CONTENT_HASH:
		return transport_failure(native, reconstructed, "reconstructed Catalog differs from exact old view/content identity")
	native.close_db(); native = null
	check(FileAccess.get_sha256(legacy_catalog) == LEGACY_SHA256, "read-only native transport leaves every source byte unchanged")
	check(reconstructed.table_names.size() == 93 and int(reconstructed.rows("catalog_meta")[0].schema_version) == 5 and reconstructed.content_hash == LEGACY_CONTENT_HASH,
		"memory Catalog confirms full released schema5 registry and exact logical hash")
	return reconstructed

func prepare_world() -> bool:
	store = FaultStore.new(database_path)
	if not check(store.open(), "current real Store opens a fresh isolated progress schema: " + store.last_error): return false
	var reconstructed: Catalog = transport_legacy_catalog()
	if reconstructed == null: return false
	var current: Catalog = store.catalog
	store.set("_source", reconstructed)
	store.catalog = reconstructed
	current.close()
	check(store.catalog == reconstructed and store._source == reconstructed and not Space.supported(store.catalog), "only test preparation selects the verified old source for real Store operations")
	var previous: State = store.new_world("空间升级独立历史规则夹具", 20261006)
	if not check(previous != null, "actual Store freezes released content and seals initial world: " + store.last_error): return false
	check(not Space.supported(store.catalog) and previous.rows("spatial_state").is_empty(), "legacy world has no new sites or generated contexts")
	game = Gameplay.new(); game.setup(previous, store.catalog)
	for unlock: Dictionary in store.catalog.rows("unlock_defs"): game.grant_unlock(str(unlock.unlock_id))
	game._sync_spawns()
	if not check(game.act("accept_mission", "tutorial_flight").phase == T.ActionPhase.APPLIED, "legacy production service accepts a real tutorial attempt"): return false
	for objective: Dictionary in store.catalog.rows("mission_objective_defs"):
		if objective.mission_id != "tutorial_flight": continue
		var target: String = str(objective.target_anchor_id) if objective.target_anchor_id != null else str(objective.target_station_id)
		game.record_event(str(objective.objective_kind), target, int(objective.required_count))
	if not check(game.act("deliver_mission", "tutorial_flight").phase == T.ActionPhase.APPLIED, "explicit old objective events settle through real reward/claim receipt"): return false
	if not check(game.act("accept_mission", "tutorial_scan_gate").phase == T.ActionPhase.APPLIED, "legacy production service starts another active mission"): return false
	var mission: RefCounted = game.get("missions").call("active")
	var objectives: Array = game.get("missions").call("objectives", "tutorial_scan_gate")
	game.record_event("scan_signal", str(objectives[0].target_signal_id), 1)
	check(mission != null and mission.status == "active", "active attempt retains real partial objective progress")
	var inventory: RefCounted = game.get("inventory")
	var docked: D.ShipStateDto = inventory.call("create_ship", "cruiser_horizon", "station_anchor_port")
	var remote_station: Dictionary = store.catalog.one("station_defs", "sector_id", "sector_echo")
	var distant: D.ShipStateDto = inventory.call("create_ship", "transport_caravan", str(remote_station.station_id))
	if distant == null: return check(false, "foreign owned ship is created")
	var moving: D.ShipStateDto = inventory.call("create_ship", "frigate_lantern", "station_anchor_port")
	moving.status = T.ShipStatus.FLYING; moving.has_station_id = false; moving.station_id = ""
	moving.pos_x = 2380.0; moving.pos_y = 35.0; moving.pos_z = -2420.0
	moving.vel_x = 12.0; moving.vel_y = -4.0; moving.vel_z = -7.0
	check(docked != null and distant != null and moving != null, "fixture owns docked, remote and independently flying hulls")
	# A legal old world can have distant inactive hull history after rescue. The
	# loss goes through production damage/recovery with an empty owned cargo hold
	# so no unreachable far wreck remains. Retirement is explicit test history.
	var controlled_before_loss: String = previous.player().controlled_ship_id
	var lost: D.ShipStateDto = inventory.call("create_ship", "frigate_kestrel", "station_anchor_port")
	lost.status = T.ShipStatus.FLYING; lost.has_station_id = false; lost.station_id = ""
	lost.pos_x = 300000.0; lost.pos_y = -40000.0; lost.pos_z = 230000.0
	previous.player().controlled_ship_id = lost.ship_instance_id
	previous.player().has_docked_station_id = false; previous.player().docked_station_id = ""
	game.damage_ship(Vector3.ONE * 1000000.0)
	check(lost.status == T.ShipStatus.DESTROYED and lost.pos_x == 300000.0 and lost.pos_y == -40000.0 and lost.pos_z == 230000.0,
		"real legacy damage preserves distant destroyed hull coordinates")
	var far_wrecks: int = 0
	for container: D.ContainerStateDto in previous.rows("container_state"):
		if container.kind == T.ContainerKind.WRECK and Vector3(container.pos_x, container.pos_y, container.pos_z).length() > 150000.0: far_wrecks += 1
	check(far_wrecks == 0, "production empty-hold loss leaves no inaccessible far-field cargo wreck")
	if not check(game.act("request_rescue").phase == T.ActionPhase.APPLIED and previous.player().controlled_ship_id == controlled_before_loss,
		"production rescue returns control to the owned station recovery hull"): return false
	distant_history[lost.ship_instance_id] = {"status": T.ShipStatus.DESTROYED, "x": lost.pos_x, "y": lost.pos_y, "z": lost.pos_z}
	var returned: D.ShipStateDto = inventory.call("create_ship", "miner_anvil", "station_anchor_port")
	returned.status = T.ShipStatus.FLYING; returned.has_station_id = false; returned.station_id = ""
	returned.pos_x = -320000.0; returned.pos_y = 80000.0; returned.pos_z = -190000.0
	inventory.call("retire", returned)
	check(returned.status == T.ShipStatus.RETURNED and returned.pos_x == -320000.0 and returned.pos_y == 80000.0 and returned.pos_z == -190000.0,
		"production retirement preserves explicit distant inactive hull history")
	distant_history[returned.ship_instance_id] = {"status": T.ShipStatus.RETURNED, "x": returned.pos_x, "y": returned.pos_y, "z": returned.pos_z}
	var warehouse: String = str(inventory.call("warehouse", "station_anchor_port"))
	var items: Array = inventory.call("grant", warehouse, "module_kinetic_needle_ii", 1)
	var item: D.ItemInstanceStateDto = previous.find("item_instance_state", "item_instance_id", str(items[0]))
	item.quality_multiplier = 1.125; item.durability = 43.0
	inventory.call("grant", warehouse, "ore_ferrosilicate", 27)
	previous.player().credit += 12345
	previous.ship().shield = 0.0; previous.ship().armor = 17.0; previous.ship().hull = 23.0; previous.ship().energy = 9.0
	for resource: D.ResourceStateDto in previous.rows("resource_state"):
		resource.remaining_units = maxi(0, resource.remaining_units - 3)
	for reputation: D.ReputationStateDto in previous.rows("reputation_state"): reputation.reputation = 37
	var visited: D.SectorStateDto = previous.find("sector_state", "sector_id", "sector_echo")
	visited.visited = true
	var npc: D.NpcStateDto = previous.find("npc_state", "spawn_id", "spawn_anchor_patrol_leader")
	if not check(npc != null and npc.alive, "real old content spawned an unlocked ambient fleet"): return false
	game.damage_npc(npc.npc_instance_id, Vector3.ONE * 1000000.0)
	check(not npc.alive and previous.rows("salvage_package_state").size() > 0, "explicit test damage creates real uniquely seeded NPC recovery package")
	var manual_wreck: String = str(inventory.call("wreck", "sector_echo", Vector3(1090, 35, -1810)))
	inventory.call("grant", manual_wreck, "ore_ferrosilicate", 11)
	check(previous.rows("container_state").filter(func(row: RefCounted): return row.kind == T.ContainerKind.WRECK).size() >= 2, "fixture retains generated and standalone wreck cargo")
	if not check(store.save(previous, "manual", 0), "real Store seals prepared old state into manual recovery slot: " + store.last_error): return false
	source_snapshot = previous.snapshot.meta.snapshot_id; source_content = previous.snapshot.content.content_snapshot_id; source_hash = previous.snapshot.content.content_hash
	source_slot = store._records("SELECT * FROM save_slot WHERE world_id=? AND slot_kind='manual' AND slot_index=0", [previous.world_id])[0]
	source_tables = store.catalog.table_names.duplicate()
	original_state = state_values(previous, false)
	original_manual = manual_slots(); original_frozen = frozen_values()
	for row: Dictionary in store._records("SELECT snapshot_id FROM save_snapshot WHERE status='sealed'"): old_snapshot_ids.append(str(row.snapshot_id))
	original_sealed = sealed_values()
	game.dispose(); game = null; store.close(); store = FaultStore.new(database_path)
	if not check(store.open(), "current spatial Store independently opens the closed old-rule archive: " + store.last_error): return false
	var old: State = store.resume()
	if not check(old != null and not Space.supported(store.catalog) and old.snapshot.meta.snapshot_id == source_snapshot, "resume chooses sealed old rules before explicit content upgrade"): return false
	check(state_values(old, false) == original_state, "close and resume preserve every prepared nonspatial field")
	check(int(store._records("SELECT format_version FROM database_meta")[0].format_version) == 8, "current progress schema registers reviewed format8")
	return true

func migration_expectations(previous: State) -> void:
	for ship: D.ShipStateDto in previous.rows("ship_state"):
		var site: String
		if ship.has_station_id:
			var station: Dictionary = store._source.one("station_defs", "station_id", ship.station_id)
			site = Space.site_for_anchor(store._source, str(station.station_anchor_id))
		else: site = Space.infer_legacy_site(store._source, ship.sector_id, Vector3(ship.pos_x, ship.pos_y, ship.pos_z))
		expected_sites["ship:" + ship.ship_instance_id] = site
	for npc: D.NpcStateDto in previous.rows("npc_state"):
		var spawn: Dictionary = store._source.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
		expected_sites["npc:" + npc.npc_instance_id] = Space.site_for_anchor(store._source, str(spawn.anchor_id))
	for container: D.ContainerStateDto in previous.rows("container_state"):
		if container.kind != T.ContainerKind.WRECK: continue
		var site: String = ""
		for package: D.SalvagePackageStateDto in previous.rows("salvage_package_state"):
			if package.has_host_container_id and package.host_container_id == container.container_id:
				site = str(expected_sites.get("npc:" + package.source_npc_instance_id, ""))
		if site.is_empty(): site = Space.infer_legacy_site(store._source, container.sector_id, Vector3(container.pos_x, container.pos_y, container.pos_z))
		expected_sites["wreck:" + container.container_id] = site

func rejection_checks(previous: State) -> void:
	var before: Dictionary = pointers()
	var live: Dictionary = state_values(previous)
	var rejected: State = store.upgrade_content(previous, func(_candidate: State) -> bool: return false)
	check(rejected == null and store.active_state == previous and store.catalog.content_hash == source_hash and not store.busy, "staging failure preserves old authority and releases writer")
	check(pointers() == before and state_values(previous) == live, "staging failure rolls back contexts, branches, snapshots and pointers")
	store.fault = "content_upgrade"
	rejected = store.upgrade_content(previous)
	store.fault = ""
	check(rejected == null and store.active_state == previous and store.catalog.content_hash == source_hash and not store.busy, "post-publication checkpoint failure preserves old authority")
	check(pointers() == before and state_values(previous) == live, "post-publication rollback removes all provisional contexts and durable changes")
	check(frozen_values() == original_frozen and sealed_values() == original_sealed and manual_slots() == original_manual, "both transaction failures leave all frozen/manual/sealed history intact")
	# Fault injection mutates only a test-owned read cache; no catalog bytes or
	# production data files are written, and the original cache is restored.
	var cache: Dictionary = store._source.get("_cache")
	for entry: Array in [["ship_defs", "max_speed_mps"], ["anchor_defs", "x_m"], ["rule_parameters", "value_integer"]]:
		var table: String = str(entry[0]); var field: String = str(entry[1])
		var original: Array = cache[table].duplicate(true)
		cache[table][0][field] = float(cache[table][0][field]) + 1.0 if field != "value_integer" else int(cache[table][0][field]) + 1
		rejected = store.upgrade_content(previous)
		cache[table] = original
		check(rejected == null and store.last_error.contains("protected"), "nonspatial protected definition mutation is refused " + table + "." + field)
		check(pointers() == before and state_values(previous) == live and store.catalog.content_hash == source_hash, "protected-definition refusal cannot change old live or durable state " + table)

func commit_checks(previous: State) -> bool:
	var upgraded: State = store.upgrade_content(previous)
	if not check(upgraded != null, "reviewed spatial upgrade commits after failure retries: " + store.last_error): return false
	upgraded_snapshot = upgraded.snapshot.meta.snapshot_id; upgraded_content = upgraded.snapshot.content.content_snapshot_id; upgraded_hash = upgraded.snapshot.content.content_hash
	check(upgraded.world_id == previous.world_id and upgraded_content != source_content and upgraded_hash != source_hash, "upgrade adds a frozen spatial branch while preserving world identity")
	check(upgraded.snapshot.content.frozen_adapter_version == "frozen_catalog_v0_7" and upgraded.snapshot.content.rules_code_version == "singleplayer_space_v3", "new branch records exact reviewed adapter and code rules")
	check(Space.supported(store.catalog) and store.catalog.rows("site_defs").size() == 79 and store.catalog.rows("anchor_site_defs").size() == 160 and store.catalog.rows("celestial_defs").size() == 20, "new branch reads complete astronomical sites and celestial bodies")
	var now: Dictionary = state_values(upgraded, false)
	for table: String in State.TABLES:
		if table == "spatial_state": continue
		check(now[table] == original_state[table], "space upgrade preserves every exact nonspatial DTO field " + table)
	check(upgraded.rows("spatial_state").size() == expected_sites.size(), "one context exists for every ship, NPC and wreck with no extras")
	for context: D.SpatialStateDto in upgraded.rows("spatial_state"):
		var key: String = context.entity_kind + ":" + context.entity_id
		check(expected_sites.has(key) and str(expected_sites[key]) == context.site_id and not context.site_id.is_empty(), "context maps explicit old source correctly " + key)
	for id: String in distant_history:
		var archived: D.ShipStateDto = upgraded.find("ship_state", "ship_instance_id", id)
		var prior: Dictionary = distant_history[id]
		check(archived != null and archived.status == int(prior.status) and archived.pos_x == float(prior.x) and archived.pos_y == float(prior.y) and archived.pos_z == float(prior.z),
			"successful upgrade preserves inactive distant status and every original coordinate " + id)
		var contexts: int = 0
		for context: D.SpatialStateDto in upgraded.rows("spatial_state"):
			if context.entity_kind == "ship" and context.entity_id == id: contexts += 1
		check(contexts == 1 and not Space.site_for_entity(upgraded, "ship", id).is_empty(), "inactive distant history receives one unique reviewed site without clamping " + id)
	check(manual_slots() == original_manual and frozen_values() == original_frozen and sealed_values() == original_sealed, "committed spatial upgrade preserves all original manual/frozen/sealed records")
	var receipt: Array[Dictionary] = store._records("SELECT * FROM content_upgrade_record WHERE source_snapshot_id=?", [source_snapshot])
	check(receipt.size() == 1 and receipt[0].upgrade_kind == "strategic_space_v1" and receipt[0].upgraded_snapshot_id == upgraded_snapshot, "single exact-source receipt identifies spatial migration")
	check(store._records("SELECT parent_snapshot_id FROM snapshot_lineage WHERE child_snapshot_id=?", [upgraded_snapshot])[0].parent_snapshot_id == source_snapshot, "spatial branch lineage names original sealed source")
	backup_sha256 = verify_backup(source_snapshot, source_content)
	var before: Dictionary = pointers()
	check(store.upgrade_content(upgraded) == upgraded and pointers() == before, "current branch repeat is an exact idempotent no-op")
	var backup: String = directory.path_join("content-upgrade-%s-%s-backup.db" % [upgraded.world_id, source_snapshot])
	check(FileAccess.get_sha256(backup) == backup_sha256, "idempotent repeat cannot replace complete old backup")
	return true

func reopen_checks() -> bool:
	store.close(); store = FaultStore.new(database_path)
	if not check(store.open(), "completed archive fully closes and reopens independently: " + store.last_error): return false
	var resumed: State = store.resume()
	check(resumed != null and resumed.snapshot.meta.snapshot_id == upgraded_snapshot and resumed.snapshot.content.content_hash == upgraded_hash and Space.current_site(resumed) != "", "resume restores exact new spatial branch and current site")
	var prior: State = store.load(str(source_slot.slot_id), source_snapshot, int(source_slot.generation))
	if not check(prior != null and prior.snapshot.content.content_hash == source_hash and not Space.supported(store.catalog), "old manual independently reopens with its original frozen schema5"): return false
	check(state_values(prior, false) == original_state and prior.rows("spatial_state").is_empty(), "old manual retains all pre-space fields and has no silent contexts")
	var before: Dictionary = pointers()
	var replay: State = store.upgrade_content(prior)
	check(replay != null and replay.snapshot.meta.snapshot_id == upgraded_snapshot and replay.snapshot.content.content_hash == upgraded_hash, "same historical manual reuses already committed spatial branch")
	var after: Dictionary = pointers()
	for table: String in ["save_snapshot", "content_snapshot", "spatial_state", "content_upgrade_record", "snapshot_lineage"]:
		check(after[table] == before[table], "historical replay creates no duplicate durable rows " + table)
	return true

func out_of_bounds_checks() -> void:
	var prior: State = store.load(str(source_slot.slot_id), source_snapshot, int(source_slot.generation))
	if not check(prior != null, "old manual recovers for far-space refusal fixture"): return
	var ship: D.ShipStateDto = prior.ship()
	ship.status = T.ShipStatus.FLYING; ship.has_station_id = false; ship.station_id = ""
	prior.player().has_docked_station_id = false; prior.player().docked_station_id = ""
	ship.pos_x = 300000.0; ship.pos_y = 100.0; ship.pos_z = 0.0
	ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	if not check(store.save(prior, "auto", 2), "old rules seal legal historic flight beyond new local-radius boundary: " + store.last_error): return
	var far_snapshot: String = prior.snapshot.meta.snapshot_id
	var before: Dictionary = pointers()
	var live: Dictionary = state_values(prior)
	var rejected: State = store.upgrade_content(prior)
	check(rejected == null and not store.last_error.is_empty() and store.active_state == prior and store.catalog.content_hash == source_hash, "far old-space position refuses upgrade with old authority preserved")
	check(pointers() == before and state_values(prior) == live and prior.ship().pos_x == 300000.0, "far-space rejection never clamps pose or publishes partial migration")
	check(FileAccess.file_exists(directory.path_join("content-upgrade-%s-%s-backup.db" % [prior.world_id, far_snapshot])), "refused far-space migration still retains its complete source backup")
	var recovered: State = store.load("snapshot:" + far_snapshot)
	check(recovered != null and recovered.ship().pos_x == 300000.0 and not Space.supported(store.catalog), "refused old far-space snapshot independently reopens unchanged")
	check(manual_slots() == original_manual and frozen_values() == original_frozen and sealed_values() == original_sealed, "far-space refusal cannot alter original manual or sealed historical rows")

func _run() -> void:
	var script: String = OS.get_environment("XJ_SPACE_UPGRADE_V20_SCRIPT").replace("\\", "/")
	var tmp: String = (script.get_base_dir().get_base_dir().path_join("tmp") if not script.is_empty() else ProjectSettings.globalize_path("res://../jiaoben/tmp").replace("\\", "/")).simplify_path()
	var prefix: String = tmp.path_join("space-upgrade-v20")
	directory = OS.get_environment("XJ_SPACE_UPGRADE_V20_DIRECTORY").replace("\\", "/")
	if directory.is_empty(): directory = prefix.path_join(Store.new_id("run"))
	legacy_catalog = OS.get_environment("XJ_SPACE_UPGRADE_V20_LEGACY_CATALOG").replace("\\", "/")
	if legacy_catalog.is_empty(): legacy_catalog = tmp.path_join("audit-catalog-v0141.db")
	if not check(directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == prefix, "fresh output stays in one scoped tmp/space-upgrade-v20 child"): finish(); return
	if not check(legacy_catalog.is_absolute_path() and legacy_catalog.begins_with(tmp + "/") and not legacy_catalog.contains("..") and FileAccess.file_exists(legacy_catalog), "exact old catalog is existing project tmp fixture"): finish(); return
	if not check(FileAccess.get_sha256(legacy_catalog) == LEGACY_SHA256, "old fixture matches released b54c3176 catalog bytes"): finish(); return
	database_path = directory.path_join("progress.db")
	if not check(not FileAccess.file_exists(database_path), "refuse any existing progress destination"): finish(); return
	if not check(DirAccess.make_dir_recursive_absolute(directory) == OK, "create fresh isolated test directory"): finish(); return
	if not prepare_world(): finish(); return
	var previous: State = store.active_state
	migration_expectations(previous)
	rejection_checks(previous)
	if not commit_checks(previous): finish(); return
	if not reopen_checks(): finish(); return
	out_of_bounds_checks()
	check(store._records("PRAGMA integrity_check")[0].values()[0] == "ok" and store._records("PRAGMA foreign_key_check").is_empty(), "all failed, committed and reopened branches retain SQLite integrity")
	finish()

func finish() -> void:
	if game != null: game.dispose(); game = null
	if store != null: store.close(); store = null
	if not legacy_catalog.is_empty() and FileAccess.file_exists(legacy_catalog): check(FileAccess.get_sha256(legacy_catalog) == LEGACY_SHA256, "source released catalog bytes remain unchanged")
	var result: String = "PASS" if failures.is_empty() else "FAIL"
	print("SPACE_UPGRADE_V20_FINAL_JSON " + JSON.stringify({"result": result, "checks": checks, "failures": failures.size(), "failure_labels": failures, "database_path": database_path, "legacy_catalog": legacy_catalog, "legacy_catalog_sha256": LEGACY_SHA256, "source_snapshot": source_snapshot, "old_content_hash": source_hash, "upgraded_snapshot": upgraded_snapshot, "new_content_hash": upgraded_hash, "backup_sha256": backup_sha256, "catalog_transport": "native-query-only-values-to-reviewed-v06-memory-catalog", "fixture": "production-Store-fresh-archive-exact-released-schema5-catalog-explicit-asset-progress-preparation"}))
	print("SPACE_UPGRADE_V20_RESULT %s checks=%d failures=%d" % [result, checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
