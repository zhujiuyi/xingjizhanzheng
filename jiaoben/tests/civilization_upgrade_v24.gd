extends Node
const Store = preload("res://runtime/data/store.gd")
const Codec = preload("res://runtime/data/codec.gd")
class FaultStore extends Store:
	var failure: String = ""
	func _checkpoint(point: String) -> bool: return point != failure
var checks: int = 0
var failures: Array[String] = []
var directory: String
var store: FaultStore

func _ready() -> void:
	get_tree().set_meta("xj_civilization_upgrade_v24_diagnostic", true)
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func assets(state: XJRuntimeState) -> String:
	var result: Dictionary = {}
	for table: String in ["player_state", "ship_state", "container_state", "item_instance_state", "equipment_state", "inventory_stack_state", "mission_state", "mission_objective_state", "mission_claim_state", "loan_state", "loan_asset_state", "loan_issue_state", "manufacture_input_state", "rng_state", "spatial_state"]:
		var values: Array = []
		for row: RefCounted in state.rows(table): values.append(Codec.new().encode_row(table, row))
		result[table] = values
	return JSON.stringify(result)

func pointers() -> Array[Dictionary]:
	return store._records("SELECT slot_id,current_snapshot_id,generation FROM save_slot ORDER BY slot_id", [])

func _run() -> void:
	directory = OS.get_environment("XJ_CIVILIZATION_UPGRADE_V24_DIRECTORY").replace("\\", "/")
	var source: String = OS.get_environment("XJ_CIVILIZATION_UPGRADE_V24_LEGACY_SOURCE").replace("\\", "/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/civilization-upgrade-v24/") and not directory.contains("..") and source.is_absolute_path() and source.contains("/jiaoben/tmp/") and not source.contains("..") and FileAccess.file_exists(source), "fixture paths stay inside test-owned directories"):
		_finish(); return
	var path: String = directory.path_join("progress.db")
	if not check(not FileAccess.file_exists(path), "upgrade uses a fresh independent database copy"):
		_finish(); return
	var source_hash: String = FileAccess.get_sha256(source)
	var input: FileAccess = FileAccess.open(source, FileAccess.READ)
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	output.store_buffer(input.get_buffer(input.get_length())); output.close(); input.close()
	store = FaultStore.new(path)
	store.failure = "migration:012_civilizations.sql"
	check(not store.open(), "interrupted format9 migration is rejected")
	check(int(store._records("SELECT format_version FROM database_meta", [])[0].format_version) == 8 and store._records("SELECT name FROM sqlite_schema WHERE name='civilization_state'", []).is_empty(), "failed migration preserves format8 and rolls back all new schema")
	check(FileAccess.file_exists(directory.path_join("migration-format8-backup.db")), "closed validated format8 backup exists before migration")
	store.close(); store = FaultStore.new(path)
	if not check(store.open(), "retry upgrades format8 to format9 " + store.last_error): _finish(); return
	check(int(store._records("SELECT format_version FROM database_meta", [])[0].format_version) == 10, "actual SQLite format10 is installed")
	var old: XJRuntimeState = store.resume()
	if not check(old != null, "old frozen world loads after format migration " + store.last_error): _finish(); return
	check(store.catalog.rows("sector_defs").size() == 10 and old.rows("civilization_state").is_empty(), "schema migration does not silently replace the old world rules")
	var before_assets: String = assets(old)
	var before_pointers: Array[Dictionary] = pointers()
	var manual: Array[Dictionary] = store._records("SELECT slot_id,current_snapshot_id,generation FROM save_slot WHERE slot_kind='manual' ORDER BY slot_id", [])
	var old_content: String = old.snapshot.content.content_snapshot_id
	store.failure = "content_upgrade"
	check(store.upgrade_content(old) == null, "interrupted civilization branch rolls back")
	check(pointers() == before_pointers and assets(old) == before_assets and store.catalog.rows("sector_defs").size() == 10, "failed branch preserves slots assets RNG and active old rules")
	check(store._records("SELECT * FROM content_upgrade_record", []).is_empty(), "failed branch leaves no false upgrade receipt")
	var backups: PackedStringArray = DirAccess.get_files_at(directory)
	check(Array(backups).any(func(name: String): return name.begins_with("content-upgrade-") and name.ends_with("-backup.db")), "content branch has a validated closed backup")
	store.failure = ""
	var upgraded: XJRuntimeState = store.upgrade_content(old)
	if not check(upgraded != null, "reviewed civilization branch succeeds " + store.last_error): _finish(); return
	check(assets(upgraded) == before_assets, "all ships cargo equipment mission progress and exact RNG survive upgrade")
	check(store.catalog.rows("sector_defs").size() == 54 and upgraded.rows("sector_state").size() == 54 and upgraded.rows("territory_state").size() == 54, "new branch initializes all 54 real systems")
	check(upgraded.rows("civilization_state").size() == 1 and not upgraded.rows("civilization_state")[0].has_faction_id, "old player enters the new civilization system without forced allegiance")
	check(upgraded.snapshot.content.content_snapshot_id != old_content and store._records("SELECT slot_id,current_snapshot_id,generation FROM save_slot WHERE slot_kind='manual' ORDER BY slot_id", []) == manual, "new content identity leaves old manual slots and generations exact")
	check(store._records("SELECT count(*) AS n FROM content_upgrade_record", [])[0].n == 1, "one durable reviewed upgrade receipt")
	var upgraded_id: String = upgraded.snapshot.meta.snapshot_id
	store.close(); store = FaultStore.new(path)
	check(store.open(), "upgraded SQLite reopens cleanly")
	var resumed: XJRuntimeState = store.resume()
	check(resumed != null and resumed.snapshot.meta.snapshot_id == upgraded_id and store.catalog.rows("sector_defs").size() == 54 and assets(resumed) == before_assets, "resume restores the expanded branch with intact assets")
	if not manual.is_empty():
		var legacy: XJRuntimeState = store.load(str(manual[0].slot_id), str(manual[0].current_snapshot_id), int(manual[0].generation))
		check(legacy != null and store.catalog.rows("sector_defs").size() == 10 and legacy.rows("civilization_state").is_empty(), "original manual save still restores its original ten-system rules")
		var again: XJRuntimeState = store.upgrade_content(legacy)
		check(again != null and again.snapshot.meta.snapshot_id == upgraded_id and store._records("SELECT count(*) AS n FROM content_upgrade_record", [])[0].n == 1, "revisiting the same legacy save reuses its reviewed branch without duplicate grants")
	check(FileAccess.get_sha256(source) == source_hash, "source legacy fixture bytes are unchanged")
	check(store._records("PRAGMA foreign_key_check", []).is_empty() and str(store._records("PRAGMA integrity_check", [])[0].values()[0]) == "ok", "final database integrity and all cross-content foreign keys remain valid")
	_finish()

func _finish() -> void:
	if store != null: store.close(); store = null
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": 0, "directory": directory}
	print("CIVILIZATION_UPGRADE_V24_FINAL_JSON ", JSON.stringify(summary))
	print("CIVILIZATION_UPGRADE_V24_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
