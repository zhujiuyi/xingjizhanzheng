extends SceneTree
## Actual Store/SQLite additive-content regression. All paths are test-owned.
const Store = preload("res://runtime/data/store.gd")
const State = preload("res://runtime/state.gd")
const Codec = preload("res://runtime/data/codec.gd")
const RECIPE: String = "recipe_sensor_core_echo"
var checks: int = 0
var failures: Array[String] = []
var directory: String = ""

class FaultStore extends Store:
	var fault: String = ""
	func _checkpoint(point: String) -> bool:
		return point != fault

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func finish() -> void:
	print("ECHO_CONTENT_AUDIT_RESULT %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func canonical(rows: Array) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in rows: result.append(JSON.stringify(row, "", true, true))
	result.sort()
	return result

func state_rows(state: State) -> Dictionary:
	var result: Dictionary = {}
	var codec: Codec = Codec.new()
	for table: String in State.TABLES:
		var encoded: Array[Dictionary] = []
		for row: RefCounted in state.rows(table): encoded.append(codec.encode_row(table, row))
		result[table] = canonical(encoded)
	return result

func manual_slots(store: Store) -> Array[String]:
	return canonical(store._records("SELECT * FROM save_slot WHERE slot_kind='manual' ORDER BY slot_id"))

func all_slots(store: Store) -> Array[String]:
	return canonical(store._records("SELECT * FROM save_slot ORDER BY slot_id"))

func transaction_counts(store: Store) -> Dictionary:
	var result: Dictionary = {}
	for table: String in ["save_snapshot", "content_snapshot", "content_upgrade_record", "snapshot_lineage"]:
		result[table] = int(store._records("SELECT count(*) AS n FROM " + table)[0].n)
	return result

func definitions(store: Store) -> Dictionary:
	var result: Dictionary = {}
	for table: String in store.catalog.table_names:
		result[table] = store.catalog.rows(table).duplicate(true)
	return result

func frozen_rows(store: Store, content_id: String, tables: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for table: String in tables:
		result[table] = canonical(store._records('SELECT * FROM "frozen_' + table + '" WHERE content_snapshot_id=?', [content_id]))
	return result

func backup_check(backup_path: String, source_snapshot: String, source_content: String) -> void:
	if not check(FileAccess.file_exists(backup_path), "exact source-specific native backup exists"): return
	var witness: Object = ClassDB.instantiate("SQLite")
	witness.path = backup_path
	witness.read_only = true
	witness.verbosity_level = 0
	if not check(witness.open_db(), "closed backup independently opens read-only"):
		witness = null
		return
	witness.query("PRAGMA integrity_check")
	check(witness.query_result.size() == 1 and witness.query_result[0].values()[0] == "ok", "closed backup has SQLite physical integrity")
	witness.query("PRAGMA foreign_key_check")
	check(witness.query_result.is_empty(), "closed backup has no foreign key violations")
	witness.query_with_bindings("SELECT status,content_snapshot_id FROM save_snapshot WHERE snapshot_id=?", [source_snapshot])
	check(witness.query_result.size() == 1 and str(witness.query_result[0].status) == "sealed" and str(witness.query_result[0].content_snapshot_id) == source_content, "closed backup contains exact sealed source and original frozen content")
	witness.close_db()
	witness = null

func _initialize() -> void:
	_run()

func _run() -> void:
	var fixture: String = OS.get_environment("XJ_ECHO_CATALOG_FIXTURE")
	if fixture.is_empty(): fixture = ProjectSettings.globalize_path("res://../jiaoben/tmp/audit-catalog-v090.db").simplify_path()
	if not check(fixture.is_absolute_path() and fixture.contains("/jiaoben/tmp/") and not fixture.contains("..") and FileAccess.file_exists(fixture), "pre-change v0.9 catalogue fixture exists in test-only directory"):
		finish(); return
	var fixture_hash: String = FileAccess.get_sha256(fixture)
	directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/echo-content-audit/" + Store.new_id("run"))
	if not check(DirAccess.make_dir_recursive_absolute(directory) == OK, "unique test-only directory is available"):
		finish(); return
	var db_path: String = directory.path_join("progress.db")
	var legacy: FaultStore = FaultStore.new(db_path)
	legacy.catalog_path = fixture
	if not check(legacy.open(), "actual Store accepts the original reviewed v0.9 catalogue: " + legacy.last_error):
		legacy.close(); finish(); return
	check(legacy.catalog.table_names.has("encounter_defs") and legacy.catalog.one("recipe_defs", "recipe_id", RECIPE).is_empty(), "fixture already contains combat sites but has no future echo recipe")
	var original: State = legacy.new_world("声纹内容独立升级审计", 90413)
	if not check(original != null, "original rules create a real independently frozen SQLite world: " + legacy.last_error):
		legacy.close(); finish(); return
	check(int(legacy._records("SELECT format_version FROM database_meta")[0].format_version) == 6, "fixture world uses current format 6 without historical schema reconstruction")
	if not check(legacy.save(original, "manual", 0), "original world creates a real manual recovery slot"):
		legacy.close(); finish(); return
	var slot: Dictionary = legacy._records("SELECT * FROM save_slot WHERE slot_kind='manual' AND slot_index=0")[0].duplicate(true)
	var source_snapshot: String = str(slot.current_snapshot_id)
	var source_content: String = str(slot.content_snapshot_id)
	var original_hash: String = original.snapshot.content.content_hash
	var original_state: Dictionary = state_rows(original)
	var original_definitions: Dictionary = definitions(legacy)
	var old_tables: Array[String] = legacy.catalog.table_names.duplicate()
	var original_frozen: Dictionary = frozen_rows(legacy, source_content, old_tables)
	var original_views: Dictionary = legacy.catalog.view_sql.duplicate(true)
	var original_manual: Array[String] = manual_slots(legacy)
	legacy.close()

	legacy = FaultStore.new(db_path)
	if not check(legacy.open(), "archive reopens against current source catalogue: " + legacy.last_error):
		legacy.close(); finish(); return
	var current_source_has_recipe: bool = not legacy.catalog.one("recipe_defs", "recipe_id", RECIPE).is_empty()
	if not check(current_source_has_recipe, "current source contains the reviewed additive echo recipe"):
		legacy.close(); finish(); return
	var previous: State = legacy.load(str(slot.slot_id), source_snapshot, int(slot.generation))
	if not check(previous != null, "old manual slot loads before any content upgrade: " + legacy.last_error):
		legacy.close(); finish(); return
	check(previous.snapshot.content.content_hash == original_hash and legacy.catalog.one("recipe_defs", "recipe_id", RECIPE).is_empty(), "loading old manual preserves original frozen rules")
	check(state_rows(previous) == original_state, "all original typed state rows survive close and manual load")
	var before_slots: Array[String] = all_slots(legacy)
	var before_counts: Dictionary = transaction_counts(legacy)
	var before_resume: Array[String] = canonical(legacy._records("SELECT * FROM runtime_session ORDER BY world_id"))
	var refused: State = legacy.upgrade_content(previous, func(_candidate: State) -> bool: return false)
	check(refused == null and legacy.active_state == previous and legacy.catalog.one("recipe_defs", "recipe_id", RECIPE).is_empty(), "candidate preparation rejection retains original live authority and catalogue")
	check(transaction_counts(legacy) == before_counts and all_slots(legacy) == before_slots and canonical(legacy._records("SELECT * FROM runtime_session ORDER BY world_id")) == before_resume, "preparation rejection rolls back every snapshot, content, slot and resume endpoint")
	legacy.fault = "content_upgrade"
	refused = legacy.upgrade_content(previous)
	check(refused == null and legacy.active_state == previous and not legacy.busy, "injected post-publication failure rejects upgrade and releases writer")
	check(transaction_counts(legacy) == before_counts and all_slots(legacy) == before_slots and canonical(legacy._records("SELECT * FROM runtime_session ORDER BY world_id")) == before_resume, "injected content_upgrade failure rolls back all durable endpoints and receipts")
	check(frozen_rows(legacy, source_content, old_tables) == original_frozen and legacy.catalog.one("recipe_defs", "recipe_id", RECIPE).is_empty(), "both rejected attempts leave original frozen values untouched")
	legacy.fault = ""
	var upgraded: State = legacy.upgrade_content(previous)
	if not check(upgraded != null, "real additive upgrade commits a distinct frozen content branch: " + legacy.last_error):
		legacy.close(); finish(); return
	var upgraded_snapshot: String = upgraded.snapshot.meta.snapshot_id
	var upgraded_hash: String = upgraded.snapshot.content.content_hash
	var upgraded_content: String = upgraded.snapshot.content.content_snapshot_id
	check(upgraded.world_id == previous.world_id and upgraded_content != source_content and upgraded_hash != original_hash, "upgrade retains world identity and changes only reviewed content identity")
	check(state_rows(upgraded) == original_state, "all existing gameplay, inventory, encounter and reward state stays equal")
	check(not legacy.catalog.one("recipe_defs", "recipe_id", RECIPE).is_empty(), "upgraded automatic branch exposes the echo recipe")
	var preserved: bool = true
	for table: String in old_tables:
		if table == "catalog_meta": continue
		for row: Dictionary in original_definitions[table]:
			preserved = preserved and legacy.catalog.rows(table).has(row)
	check(preserved and legacy.catalog.view_sql == original_views, "every prior definition and derived view is equal inside upgraded catalogue")
	check(frozen_rows(legacy, source_content, old_tables) == original_frozen, "every persisted original frozen value including metadata remains equal")
	check(manual_slots(legacy) == original_manual, "successful upgrade preserves every original manual recovery endpoint")
	var automatic: Array[Dictionary] = legacy._records("SELECT current_snapshot_id,content_snapshot_id FROM save_slot WHERE slot_kind='auto' AND slot_index=0")
	check(automatic.size() == 1 and str(automatic[0].current_snapshot_id) == upgraded_snapshot and str(automatic[0].content_snapshot_id) == upgraded_content, "automatic slot durably selects upgraded snapshot and content")
	var lineage: Array[Dictionary] = legacy._records("SELECT parent_snapshot_id FROM snapshot_lineage WHERE child_snapshot_id=?", [upgraded_snapshot])
	check(lineage.size() == 1 and str(lineage[0].parent_snapshot_id) == source_snapshot, "upgraded snapshot points to the exact historical manual source")
	check(int(legacy._records("SELECT count(*) AS n FROM content_upgrade_record")[0].n) == 1, "failed attempts leave no receipt and successful upgrade records once")
	var backup_path: String = directory.path_join("content-upgrade-%s-%s-backup.db" % [previous.world_id, source_snapshot])
	backup_check(backup_path, source_snapshot, source_content)
	var backup_hash: String = FileAccess.get_sha256(backup_path)
	var counts_after: Dictionary = transaction_counts(legacy)
	var repeated: State = legacy.upgrade_content(upgraded)
	check(repeated == upgraded and transaction_counts(legacy) == counts_after and FileAccess.get_sha256(backup_path) == backup_hash, "repeating upgrade on current branch creates no snapshot, receipt or backup replacement")
	legacy.close()

	legacy = FaultStore.new(db_path)
	if not check(legacy.open(), "upgraded database independently reopens"):
		legacy.close(); finish(); return
	var resumed: State = legacy.resume()
	check(resumed != null and resumed.snapshot.meta.snapshot_id == upgraded_snapshot and resumed.snapshot.content.content_hash == upgraded_hash and not legacy.catalog.one("recipe_defs", "recipe_id", RECIPE).is_empty(), "resume after complete close selects saved upgraded recipe branch")
	var recovered: State = legacy.load(str(slot.slot_id), source_snapshot, int(slot.generation))
	check(recovered != null and recovered.snapshot.content.content_hash == original_hash and legacy.catalog.one("recipe_defs", "recipe_id", RECIPE).is_empty(), "old manual still independently recovers its original recipe set")
	if recovered != null:
		check(state_rows(recovered) == original_state and frozen_rows(legacy, source_content, old_tables) == original_frozen, "old manual restores original state and byte-equivalent frozen row values")
		var reused: State = legacy.upgrade_content(recovered)
		check(reused != null and reused.snapshot.meta.snapshot_id == upgraded_snapshot and transaction_counts(legacy) == counts_after, "same historical source reuses its existing upgrade branch without a duplicate receipt")
	check(manual_slots(legacy) == original_manual and FileAccess.get_sha256(backup_path) == backup_hash, "historical recovery and replay preserve manual endpoints and backup bytes")
	check(legacy._records("PRAGMA integrity_check")[0].values()[0] == "ok" and legacy._records("PRAGMA foreign_key_check").is_empty(), "both sealed branches retain SQLite physical and relational integrity")
	legacy.close()
	check(FileAccess.get_sha256(fixture) == fixture_hash, "audit never changes its pre-change catalogue fixture")
	print("ECHO_CONTENT_AUDIT_DATABASE " + db_path)
	finish()
