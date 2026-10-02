extends Node
## Technical probe only. Copies and temporary databases stay under the probe user directory.

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func scalar(db: Object, key: String) -> Variant:
	var rows: Array = db.query_result
	return null if rows.is_empty() else rows[0].get(key)

func _ready() -> void:
	var catalog = ClassDB.instantiate("SQLite")
	if catalog == null:
		check(false, "SQLite extension registered")
		get_tree().quit(1)
		return
	catalog.path = "res://data/catalog.db"
	catalog.read_only = true
	catalog.foreign_keys = true
	catalog.verbosity_level = 0
	check(catalog.open_db(), "catalog read-only open")
	check(catalog.query("SELECT sqlite_version() AS version"), "runtime version query")
	print("SQLITE_RUNTIME ", catalog.query_result)
	check(catalog.query("SELECT content_version, content_hash FROM catalog_meta"), "catalog metadata")
	print("CATALOG ", catalog.query_result)
	check(catalog.query("SELECT count(*) AS n FROM ship_defs"), "catalog numeric query")
	check(scalar(catalog, "n") == 4, "four baseline ships")
	check(not catalog.query("UPDATE ship_defs SET hull_max=hull_max+1"), "catalog refuses mutation")
	check(catalog.query("PRAGMA integrity_check"), "catalog integrity query")
	check(scalar(catalog, "integrity_check") == "ok", "catalog integrity ok")
	catalog.close_db()

	var db = ClassDB.instantiate("SQLite")
	var db_path := "user://technical-probe.db"
	if FileAccess.file_exists(db_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(db_path))
	db.path = db_path
	db.foreign_keys = true
	db.verbosity_level = 0
	check(db.open_db(), "writable user database")
	check(db.query("PRAGMA journal_mode=DELETE; PRAGMA synchronous=EXTRA;"), "durability pragmas")
	check(db.query("CREATE TABLE parent(id INTEGER PRIMARY KEY) STRICT; CREATE TABLE child(id INTEGER PRIMARY KEY, parent_id INTEGER NOT NULL REFERENCES parent(id), value INTEGER NOT NULL CHECK(value>=0)) STRICT;"), "STRICT and foreign key DDL")
	check(not db.query("INSERT INTO child VALUES(1,99,1)"), "foreign key rejected")
	check(db.query("BEGIN IMMEDIATE; INSERT INTO parent VALUES(1);"), "transaction start")
	check(db.query_with_bindings("INSERT INTO child VALUES(?,?,?)", [1,1,42]), "parameter binding")
	check(db.query("ROLLBACK"), "transaction rollback")
	check(db.query("SELECT count(*) AS n FROM parent"), "rollback read")
	check(scalar(db, "n") == 0, "rollback leaves no partial rows")
	check(db.query("BEGIN IMMEDIATE; INSERT INTO parent VALUES(1); INSERT INTO child VALUES(1,1,42); COMMIT;"), "commit")
	check(db.close_db(), "close persisted connection")
	check(db.open_db(), "reopen persisted connection")
	check(db.query("SELECT value FROM child WHERE id=1"), "reopen query")
	check(scalar(db, "value") == 42, "committed value survives reopen")
	check(db.query("PRAGMA foreign_key_check"), "foreign key check")
	check(db.query_result.is_empty(), "no foreign key violations")
	var backup := ProjectSettings.globalize_path("user://technical-probe-backup.db")
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	check(db.backup_to(backup), "SQLite backup API")
	db.close_db()
	print("PROBE_RESULT ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
