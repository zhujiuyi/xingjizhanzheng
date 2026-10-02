extends SceneTree
## Native SQL compatibility probe, not SaveService or scene-loading behavior.

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func _initialize() -> void:
	var db = ClassDB.instantiate("SQLite")
	if db == null:
		check(false, "SQLite registered")
		quit(1)
		return
	db.path = "user://progress-ddl-%s.db" % Time.get_ticks_usec()
	db.foreign_keys = true
	db.verbosity_level = 0
	check(db.open_db(), "native progress writable open")
	check(db.query("PRAGMA journal_mode=DELETE; PRAGMA synchronous=EXTRA; BEGIN IMMEDIATE;"), "native progress begin")
	for name in ["001_core.sql", "002_frozen_catalog.sql", "003_seal_validation.sql", "004_immutability.sql"]:
		check(db.query(FileAccess.get_file_as_string("res://progress_sql/" + name)), "native migration " + name)
	if failures.is_empty():
		check(db.query("COMMIT"), "native progress schema commit")
	else:
		db.query("ROLLBACK")
	check(db.query("PRAGMA integrity_check") and db.query_result[0]["integrity_check"] == "ok", "native progress schema integrity")
	check(db.query("PRAGMA foreign_key_check") and db.query_result.is_empty(), "native progress schema foreign keys")
	db.close_db()

	var fixture = ClassDB.instantiate("SQLite")
	fixture.path = "res://data/progress-fixture.db"
	fixture.read_only = true
	fixture.foreign_keys = true
	fixture.verbosity_level = 0
	check(fixture.open_db(), "native reference fixture open")
	check(fixture.query("PRAGMA integrity_check") and fixture.query_result[0]["integrity_check"] == "ok", "native reference fixture integrity")
	check(fixture.query("PRAGMA foreign_key_check") and fixture.query_result.is_empty(), "native reference fixture foreign keys")
	check(fixture.query("SELECT count(*) AS n FROM save_slot sl JOIN save_snapshot s ON s.snapshot_id=sl.current_snapshot_id AND s.world_id=sl.world_id WHERE s.status='sealed'") and fixture.query_result[0]["n"] > 0, "native sealed slot read")
	check(fixture.query("SELECT c.content_hash, f.content_version FROM content_snapshot c JOIN frozen_catalog_meta f USING(content_snapshot_id) WHERE c.status='sealed'") and not fixture.query_result.is_empty(), "native frozen catalog read")
	print("FROZEN_CATALOG ", fixture.query_result)
	fixture.close_db()
	print("PROGRESS_NATIVE_RESULT ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
