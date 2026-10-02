class_name XJNavigationCatalog
extends RefCounted
## Read-only presentation definitions, independently versioned from frozen saves.
static var _rows: Dictionary = {}
static var last_error: String = ""

static func rows(table: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _rows.is_empty() and not _load(): return result
	for row: Dictionary in _rows.get(table, []): result.append(row.duplicate(true))
	return result

static func _load() -> bool:
	var db: Object = ClassDB.instantiate("SQLite")
	if db == null: last_error = "导航数据库组件不可用"; return false
	db.path = "res://data/navigation_v3.db"
	db.read_only = true
	db.verbosity_level = 0
	if not db.open_db(): last_error = "导航定义数据库不可用"; return false
	var candidate: Dictionary = {}
	for table: String in ["navigation_meta", "radar_range_defs", "celestial_visual_defs"]:
		if not db.query('SELECT * FROM "' + table + '"'):
			last_error = "导航定义读取失败：" + table
			db.close_db()
			return false
		candidate[table] = db.query_result.duplicate(true)
	db.close_db()
	_rows = candidate
	last_error = ""
	return true
