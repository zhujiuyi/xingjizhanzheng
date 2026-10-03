extends SceneTree
## Native migration acceptance. All databases are test-owned under jiaoben/tmp.
const Store = preload("res://runtime/data/store.gd")
const State = preload("res://runtime/state.gd")
var checks: int = 0
var failures: Array[String] = []

class LegacyStore extends Store:
	func _migrate() -> bool:
		if not _q("BEGIN IMMEDIATE; PRAGMA defer_foreign_keys=ON;"): return false
		for name in Store.MIGRATIONS.slice(0, 4):
			var source: String = "res://database/progress/" + name
			if not _q(FileAccess.get_file_as_string(source)) or not _insert("migration_history", {"migration_id": name, "sql_sha256": FileAccess.get_sha256(source), "applied_utc": Store._utc()}): return _rollback()
		return _q("COMMIT")
	func _validate_registered_schema() -> bool:
		return true # Historical format deliberately contains only the original 31 groups.
	func _insert(table: String, values: Dictionary) -> bool:
		var legacy: Dictionary = values.duplicate()
		if table == "gate_state": legacy.erase("lifetime_remaining_s")
		return super._insert(table, legacy)
	func _set_profile_world(_world: String) -> bool:
		return true # Added only by migration 007.
	func _verify_assets(_manifest_path: String = Store.ASSET_PATH) -> bool:
		return super._verify_assets("res://assets/placeholders/manifest.json")

class FaultStore extends Store:
	var fault: String = ""
	func _checkpoint(point: String) -> bool:
		return point != fault

class Format5Store extends Store:
	# The reviewed prefix constructs a real closed pre-009 schema. It uses the
	# checked-in B catalog, so this regression does not depend on a local release.
	func _migrate() -> bool:
		if not _q("BEGIN IMMEDIATE; PRAGMA defer_foreign_keys=ON;"): return false
		for name in Store.MIGRATIONS.slice(0, 8):
			var source: String = "res://database/progress/" + name
			if not _q(FileAccess.get_file_as_string(source)) or not _insert("migration_history", {"migration_id": name, "sql_sha256": FileAccess.get_sha256(source), "applied_utc": Store._utc()}): return _rollback()
		return _q("COMMIT")
	func _validate_registered_schema() -> bool:
		var actual: Array[String] = []
		for entry: Dictionary in _records("SELECT name FROM sqlite_schema WHERE type='table' AND name LIKE '%_state' ORDER BY name COLLATE BINARY"): actual.append(entry.name)
		var expected: Array[String] = State.TABLES.duplicate()
		expected.erase("encounter_state"); expected.erase("salvage_package_state"); expected.sort()
		return actual == expected
	func _verify_assets(_manifest_path: String = Store.ASSET_PATH) -> bool:
		return super._verify_assets("res://assets/placeholders/manifest.json")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func _initialize() -> void:
	var directory: String = ProjectSettings.globalize_path("res://../jiaoben/tmp")
	var legacy_path: String = directory.path_join("store-legacy-format1.db")
	DirAccess.remove_absolute(legacy_path)
	var legacy: LegacyStore = LegacyStore.new(legacy_path)
	legacy.catalog_path = ProjectSettings.globalize_path("res://../jiaoben/tests/store_fixtures/catalog-b-baseline.db")
	check(legacy.open(), "native historical format1 creation " + legacy.last_error)
	if not failures.is_empty():
		quit(1)
		return
	var original: State = legacy.new_world("历史版本世界", 42)
	check(original != null, "native legacy world freeze and seal " + legacy.last_error)
	if original == null:
		legacy.close()
		quit(1)
		return
	original.player().credit -= 13
	check(legacy.save(original, "manual", 0), "native legacy manual endpoint")
	var selected: Dictionary = legacy._records("SELECT * FROM save_slot WHERE slot_kind='manual'")[0]
	check(legacy._records("SELECT format_version FROM database_meta")[0].format_version == 1, "legacy format before upgrade")
	check(legacy._records("SELECT count(*) AS n FROM save_snapshot")[0].n == 2, "legacy sealed snapshots retained")
	legacy.close()
	for name in Store.MIGRATIONS.slice(4):
		var trial_path: String = directory.path_join("store-migration-" + name + ".db")
		DirAccess.remove_absolute(trial_path)
		check(DirAccess.copy_absolute(legacy_path, trial_path) == OK, "copy closed legacy for " + name)
		var trial: FaultStore = FaultStore.new(trial_path)
		trial.fault = "migration:" + name
		check(not trial.open(), "upgrade failure injected after " + name)
		check(trial._records("SELECT format_version FROM database_meta")[0].format_version == 1 and trial._records("SELECT count(*) AS n FROM migration_history")[0].n == 4, "upgrade rollback retains complete prior schema " + name)
		check(trial._records("SELECT current_snapshot_id FROM save_slot WHERE slot_id=?", [selected.slot_id])[0].current_snapshot_id == selected.current_snapshot_id and trial._records("PRAGMA foreign_key_check").is_empty(), "upgrade rollback retains endpoint/FK " + name)
		trial.close()
		trial.fault = ""
		check(trial.open(), "retry native format1 to6 migration " + trial.last_error)
		check(trial._records("SELECT format_version FROM database_meta")[0].format_version == 6 and trial._records("SELECT count(*) AS n FROM migration_history")[0].n == Store.MIGRATIONS.size(), "every reviewed migration registered through format6")
		check(trial._records("PRAGMA integrity_check")[0].values()[0] == "ok" and trial._records("PRAGMA foreign_key_check").is_empty(), "upgraded physical and FK integrity")
		var recovered: State = trial.load(selected.slot_id, selected.current_snapshot_id, selected.generation)
		check(recovered != null and recovered.player().credit == 4987 and trial.catalog.table_names.size() == 73, "legacy frozen content and credit restored")
		check(recovered != null and recovered.snapshot.content.asset_manifest_version == "placeholder-b-v1", "legacy asset version remains explicit and verified")
		check(recovered != null and trial.save(recovered), "migrated session can commit complete current state")
		check(FileAccess.file_exists(directory.path_join("migration-format1-backup.db")), "pre-upgrade native backup published")
		trial.close()
	var format5_path: String = directory.path_join("store-legacy-format5.db")
	DirAccess.remove_absolute(format5_path)
	var format5: Format5Store = Format5Store.new(format5_path)
	format5.catalog_path = ProjectSettings.globalize_path("res://../jiaoben/tests/store_fixtures/catalog-b-baseline.db")
	check(format5.open(), "construct actual pre-009 format5 schema " + format5.last_error)
	var format5_state: State = format5.new_world("格式5历史世界", 42) if format5._db != null and not format5.busy and format5.phase == "READY" else null
	check(format5_state != null, "seal pre-009 format5 historical state " + format5.last_error)
	if format5_state != null:
		format5_state.player().credit -= 23
		check(format5.save(format5_state, "manual", 0), "format5 historical manual endpoint")
		var format5_slot: Dictionary = format5._records("SELECT * FROM save_slot WHERE slot_kind='manual'")[0]
		var format5_history: Array[Dictionary] = format5._records("SELECT * FROM migration_history ORDER BY migration_id")
		var format5_snapshot_count: int = int(format5._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
		check(int(format5._records("SELECT format_version FROM database_meta")[0].format_version) == 5, "fixture closes with format5 identity")
		format5.close()
		var interrupted: FaultStore = FaultStore.new(format5_path)
		interrupted.fault = "migration:009_encounters_and_salvage.sql"
		check(not interrupted.open(), "format5 to6 interrupted after reviewed 009")
		check(int(interrupted._records("SELECT format_version FROM database_meta")[0].format_version) == 5 and interrupted._records("SELECT * FROM migration_history ORDER BY migration_id") == format5_history, "009 rollback retains format5 and exact prior migration hashes")
		check(interrupted._records("SELECT name FROM sqlite_schema WHERE name IN ('frozen_encounter_defs','encounter_state','salvage_package_state','content_upgrade_record')").is_empty(), "009 rollback leaves no partial new content or state tables")
		check(int(interrupted._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == format5_snapshot_count and interrupted._records("SELECT current_snapshot_id FROM save_slot WHERE slot_id=?", [format5_slot.slot_id])[0].current_snapshot_id == format5_slot.current_snapshot_id, "009 rollback retains old sealed snapshots and manual endpoint")
		interrupted.close(); interrupted.fault = ""
		check(interrupted.open(), "retry real format5 to6 migration " + interrupted.last_error)
		check(int(interrupted._records("SELECT format_version FROM database_meta")[0].format_version) == 6 and interrupted._records("SELECT * FROM migration_history ORDER BY migration_id").slice(0, 8) == format5_history, "format6 appends 009 without altering old eight migration records")
		var format5_loaded: State = interrupted.load(format5_slot.slot_id, format5_slot.current_snapshot_id, format5_slot.generation)
		check(format5_loaded != null and format5_loaded.player().credit == 4977 and format5_loaded.rows("encounter_state").is_empty(), "format6 loads historical frozen closure without adding content or grants")
		check(format5_loaded != null and interrupted.save(format5_loaded), "recovered format5 world commits under complete current schema")
		check(interrupted._records("PRAGMA foreign_key_check").is_empty(), "format5 recovery reference closure valid")
		check(FileAccess.file_exists(directory.path_join("migration-format5-backup.db")), "pre-009 closed backup published")
		interrupted.close()
	else:
		format5.close()
	var corrupt_path: String = directory.path_join("store-migration-checksum.db")
	DirAccess.remove_absolute(corrupt_path)
	DirAccess.copy_absolute(legacy_path, corrupt_path)
	var tamper: Object = ClassDB.instantiate("SQLite")
	tamper.path = corrupt_path
	tamper.verbosity_level = 0
	check(tamper.open_db() and tamper.query("UPDATE migration_history SET sql_sha256='" + "0".repeat(64) + "' WHERE migration_id='001_core.sql'"), "prepare checksum mismatch fixture")
	tamper.close_db()
	var refused: Store = Store.new(corrupt_path)
	check(not refused.open() and refused.last_error.contains("checksum mismatch"), "changed historical migration rejected")
	check(refused._records("SELECT format_version FROM database_meta")[0].format_version == 1 and refused._records("SELECT count(*) AS n FROM save_snapshot")[0].n == 2, "checksum rejection preserves prior data")
	refused.close()
	print("STORE_MIGRATION_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
