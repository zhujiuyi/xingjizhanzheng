class_name XJCatalog
extends RefCounted
## Immutable relational definitions. A store replaces this with the save's
## frozen definitions before exposing a loaded world to gameplay.
var last_error: String = ""
var _db: Object
var _cache: Dictionary = {}
var _indexes: Dictionary = {}
var table_names: Array[String] = []
var column_info: Dictionary = {}
var view_sql: Dictionary = {}
var content_hash: String = ""
const ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_4_r2.sql"
const ENCOUNTER_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_5.sql"
const COMBAT_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_6.sql"
const SPACE_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_7.sql"
const CIVILIZATION_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_8.sql"
const INDUSTRY_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_9.sql"
const RESOURCE_INTEL_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_10.sql"
const EXPLORATION_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_11.sql"
const MOBILE_BELTS_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_12.sql"
const TACTICS_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_13.sql"
const OPERATIONS_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_14.sql"
const FITTING_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_15.sql"
const HONOR_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_17.sql"
const ROLE_ADAPTER_PATH: String = "res://database/progress/catalog_adapter_v0_16.sql"
var adapter_path: String = ADAPTER_PATH

func open(path: String = "res://data/catalog.db") -> bool:
	close()
	_db = ClassDB.instantiate("SQLite")
	if _db == null:
		last_error = "SQLite extension unavailable"
		return false
	_db.path = path
	_db.read_only = true
	_db.foreign_keys = true
	_db.verbosity_level = 0
	if not _db.open_db():
		last_error = "Cannot open catalog: " + path
		return false
	if not refresh(): return false
	if int(rows("catalog_meta")[0].schema_version) <= 2: adapter_path = "res://database/progress/catalog_adapter_v0_3.sql"
	elif table_names.has("civilization_command_defs"): adapter_path = HONOR_ADAPTER_PATH
	elif table_names.has("ship_role_capability_defs"): adapter_path = ROLE_ADAPTER_PATH
	elif table_names.has("weapon_tuning_defs"): adapter_path = FITTING_ADAPTER_PATH
	elif table_names.has("operation_defs"): adapter_path = OPERATIONS_ADAPTER_PATH
	elif table_names.has("npc_tactic_defs"): adapter_path = TACTICS_ADAPTER_PATH
	elif table_names.has("exploration_belt_route_defs"): adapter_path = MOBILE_BELTS_ADAPTER_PATH
	elif table_names.has("exploration_event_defs"): adapter_path = EXPLORATION_ADAPTER_PATH
	elif table_names.has("resource_grade_defs"): adapter_path = RESOURCE_INTEL_ADAPTER_PATH
	elif table_names.has("industry_balance_defs"): adapter_path = INDUSTRY_ADAPTER_PATH
	elif table_names.has("civilization_defs"): adapter_path = CIVILIZATION_ADAPTER_PATH
	elif table_names.has("site_defs"): adapter_path = SPACE_ADAPTER_PATH
	elif table_names.has("weapon_behavior_defs"): adapter_path = COMBAT_ADAPTER_PATH
	elif table_names.has("encounter_defs"): adapter_path = ENCOUNTER_ADAPTER_PATH
	elif table_names.has("signal_unlock_rewards"): adapter_path = ADAPTER_PATH
	else: adapter_path = "res://database/progress/catalog_adapter_v0_4.sql"
	return true

func refresh() -> bool:
	_cache.clear()
	_indexes.clear()
	table_names.clear()
	column_info.clear()
	view_sql.clear()
	if not _query("PRAGMA integrity_check") or _db.query_result[0].values()[0] != "ok":
		last_error = "Catalog integrity check failed"
		return false
	if not _query("PRAGMA foreign_key_check") or not _db.query_result.is_empty():
		last_error = "Catalog foreign key closure failed"
		return false
	if not _query("SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name COLLATE BINARY"):
		return false
	for entry in _db.query_result:
		table_names.append(entry.name)
	for table in table_names:
		if not _query('PRAGMA table_info("' + table + '")'):
			return false
		column_info[table] = _db.query_result.duplicate(true)
		if not _query('SELECT * FROM "' + table + '"'):
			return false
		_cache[table] = _db.query_result.duplicate(true)
	if not _query("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name COLLATE BINARY"):
		return false
	for entry in _db.query_result:
		view_sql[entry.name] = entry.sql
	for view in view_sql:
		if not _query('SELECT * FROM "' + view + '"'):
			return false
		_cache[view] = _db.query_result.duplicate(true)
	var metadata: Array[Dictionary] = rows("catalog_meta")
	content_hash = str(metadata[0].content_hash) if not metadata.is_empty() else ""
	last_error = ""
	return true

func rows(table: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _cache.has(table):
		last_error = "Unknown definition table: " + table
		return result
	for row in _cache[table]:
		result.append(row.duplicate(true))
	return result

func one(table: String, key: String, value: Variant) -> Dictionary:
	if not _cache.has(table):
		last_error = "Unknown definition table: " + table
		return {}
	# Definitions are immutable after refresh. Copy only the matching record,
	# rather than duplicating thousands of anchors for every frame's lookup.
	if value is String or value is StringName:
		var index_id: String = table + ":" + key
		if not _indexes.has(index_id):
			var index: Dictionary = {}
			for row: Dictionary in _cache[table]:
				var candidate: Variant = row.get(key)
				if candidate is String or candidate is StringName:
					if not index.has(str(candidate)): index[str(candidate)] = row
			_indexes[index_id] = index
		var found: Variant = _indexes[index_id].get(str(value))
		return found.duplicate(true) if found is Dictionary else {}
	# Preserve Variant equality for numeric/null/non-string lookups.
	for row: Dictionary in _cache[table]:
		if row.get(key) == value: return row.duplicate(true)
	return {}

func rule(parameter_id: String) -> Variant:
	var definition: Dictionary = one("rule_parameters", "parameter_id", parameter_id)
	if definition.is_empty():
		last_error = "Missing rule: " + parameter_id
		return null
	return definition.value_integer if definition.value_integer != null else definition.value_real

func close() -> void:
	if _db != null:
		_db.close_db()
		_db = null
	_cache.clear()
	_indexes.clear()

func _query(sql: String, bindings: Array = []) -> bool:
	if not _db.query_with_bindings(sql, bindings):
		last_error = str(_db.error_message)
		return false
	return true

func verify_reviewed() -> bool:
	var reference: Object = ClassDB.instantiate("SQLite")
	reference.path = ":memory:"
	reference.foreign_keys = true
	reference.verbosity_level = 0
	if not reference.open_db() or not reference.query(FileAccess.get_file_as_string(adapter_path)):
		last_error = "Cannot load reviewed catalog adapter"
		return false
	reference.query("SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name COLLATE BINARY")
	var expected: Array[String] = []
	for entry in reference.query_result: expected.append(entry.name)
	if expected != table_names:
		last_error = "Unregistered/missing catalog table"
		reference.close_db()
		return false
	for table in expected:
		reference.query('PRAGMA table_info("' + table + '")')
		if schema_signature(reference.query_result, table) != schema_signature(column_info[table], table):
			last_error = "Unregistered column/type/key: " + table
			reference.close_db()
			return false
	reference.query("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name COLLATE BINARY")
	var reviewed_views: Dictionary = {}
	for entry in reference.query_result: reviewed_views[entry.name] = entry.sql
	reference.close_db()
	if reviewed_views != view_sql:
		last_error = "Unregistered/changed derived view"
		return false
	var actual: String = logical_hash()
	if actual.is_empty() or actual != content_hash:
		last_error = "catalog_hash_v1 mismatch"
		return false
	return true

func logical_hash() -> String:
	var digest: HashingContext = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(encode_field("catalog_hash_v1"))
	for table in table_names:
		var columns: Array = []
		for column in column_info[table]:
			if table != "catalog_meta" or column.name != "content_hash": columns.append(column)
		digest.update("B".to_ascii_buffer())
		digest.update(encode_field(table))
		digest.update(encode_field(columns.size(), "INTEGER"))
		var selection: Array[String] = []
		var keys: Array = []
		for column in columns:
			digest.update("C".to_ascii_buffer())
			digest.update(encode_field(column.name))
			digest.update(encode_field(column.type))
			digest.update(encode_field(column.pk, "INTEGER"))
			selection.append('"' + str(column.name) + '"')
			if column.pk > 0: keys.append(column)
		keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pk < b.pk)
		var ordering: Array[String] = []
		for key in keys: ordering.append('"' + str(key.name) + '" COLLATE BINARY')
		if not _query('SELECT ' + ','.join(selection) + ' FROM "' + table + '" ORDER BY ' + ','.join(ordering)):
			return ""
		var records: Array = _db.query_result.duplicate(true)
		digest.update(encode_field(records.size(), "INTEGER"))
		for record in records:
			digest.update("R".to_ascii_buffer())
			for column in columns:
				var encoded: PackedByteArray = encode_field(record[column.name], column.type)
				if encoded.is_empty():
					last_error = "Invalid hash value in " + table
					return ""
				digest.update(encoded)
	for name in view_sql:
		digest.update("V".to_ascii_buffer())
		digest.update(encode_field(name))
		digest.update(encode_field(view_sql[name]))
	return digest.finish().hex_encode()

static func encode_field(value: Variant, sql_type: String = "TEXT") -> PackedByteArray:
	var tag: String = "N"
	var payload: PackedByteArray = []
	if value != null:
		match sql_type:
			"TEXT":
				if not value is String: return []
				tag = "T"
				payload = value.to_utf8_buffer()
			"INTEGER":
				if not value is int: return []
				tag = "I"
				payload = str(value).to_ascii_buffer()
			"REAL":
				if not is_finite(float(value)): return []
				tag = "F"
				var number: StreamPeerBuffer = StreamPeerBuffer.new()
				number.big_endian = true
				number.put_double(float(value))
				payload = number.data_array.hex_encode().to_ascii_buffer()
			_: return []
	var length: StreamPeerBuffer = StreamPeerBuffer.new()
	length.big_endian = true
	length.put_64(payload.size())
	var result: PackedByteArray = tag.to_ascii_buffer()
	result.append_array(length.data_array)
	result.append_array(payload)
	return result

static func schema_signature(columns: Array, table: String) -> String:
	var parts: Array[String] = []
	for column in columns:
		if table != "catalog_meta" or column.name != "content_hash":
			parts.append("%s:%s:%d" % [column.name, column.type, column.pk])
	return "|".join(parts)

func open_frozen(progress: Object, content_id: String, reviewed_adapter: String = ADAPTER_PATH) -> bool:
	close()
	adapter_path = reviewed_adapter
	_db = ClassDB.instantiate("SQLite")
	_db.path = ":memory:"
	_db.foreign_keys = true
	_db.verbosity_level = 0
	if not _db.open_db() or not _db.query(FileAccess.get_file_as_string(adapter_path)):
		last_error = "Frozen adapter open failed"
		return false
	_db.query("SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name COLLATE BINARY")
	var names: Array = _db.query_result.duplicate(true)
	if not _db.query("BEGIN; PRAGMA defer_foreign_keys=ON;"):
		return false
	for entry in names:
		var table: String = entry.name
		_db.query('PRAGMA table_info("' + table + '")')
		var columns: Array = _db.query_result.duplicate(true)
		var selection: Array[String] = []
		var marks: Array[String] = []
		for column in columns:
			selection.append('"' + str(column.name) + '"')
			marks.append("?")
		if not progress.query_with_bindings('SELECT ' + ','.join(selection) + ' FROM "frozen_' + table + '" WHERE content_snapshot_id=?', [content_id]):
			last_error = str(progress.error_message)
			_db.query("ROLLBACK")
			return false
		for record in progress.query_result.duplicate(true):
			var values: Array = []
			for column in columns: values.append(record[column.name])
			if not _query('INSERT INTO "' + table + '" VALUES (' + ','.join(marks) + ')', values):
				_db.query("ROLLBACK")
				return false
	if not _query("COMMIT"):
		_db.query("ROLLBACK")
		return false
	return refresh() and verify_reviewed()
