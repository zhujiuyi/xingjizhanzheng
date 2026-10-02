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
		check(trial.open(), "retry native format1 to5 migration " + trial.last_error)
		check(trial._records("SELECT format_version FROM database_meta")[0].format_version == 5 and trial._records("SELECT count(*) AS n FROM migration_history")[0].n == 8, "eight exact migrations registered")
		check(trial._records("PRAGMA integrity_check")[0].values()[0] == "ok" and trial._records("PRAGMA foreign_key_check").is_empty(), "upgraded physical and FK integrity")
		var recovered: State = trial.load(selected.slot_id, selected.current_snapshot_id, selected.generation)
		check(recovered != null and recovered.player().credit == 4987 and trial.catalog.table_names.size() == 73, "legacy frozen content and credit restored")
		check(recovered != null and recovered.snapshot.content.asset_manifest_version == "placeholder-b-v1", "legacy asset version remains explicit and verified")
		check(recovered != null and trial.save(recovered), "migrated session can commit complete current state")
		check(FileAccess.file_exists(directory.path_join("migration-format1-backup.db")), "pre-upgrade native backup published")
		trial.close()
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
