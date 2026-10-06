class_name XJLocalNavigationRules
extends RefCounted
## This fixed v1 extension is separate from a world's immutable frozen catalog.
const VERSION: String = "local-navigation-v1"
const PARAMETERS: Array[String] = ["warmup_s", "alignment_tolerance_rad", "warp_speed_mps", "min_warp_distance_m", "approach_speed_fraction", "orbit_speed_fraction", "steering_response_s", "orbit_radial_response_s", "arrival_tolerance_m", "arrival_speed_mps", "collision_margin_m"]
const KINDS: Array[String] = ["station", "gate", "resource", "signal", "marker", "npc", "wreck"]
var path: String = "res://data/local_navigation_v1.db"
var version: int = 1
var last_error: String = ""
var loaded: bool = false
var parameters: Dictionary = {}
var targets: Dictionary = {}

func load_rules(use_strategic_sites: bool = false) -> bool:
	version = 2 if use_strategic_sites else 1
	path = "res://data/local_navigation_v%d.db" % version
	loaded = false
	parameters.clear()
	targets.clear()
	last_error = ""
	if not FileAccess.file_exists(path): return _fail("导航规则数据库缺失")
	var db: Object = ClassDB.instantiate("SQLite")
	if db == null: return _fail("导航规则数据库组件不可用")
	db.path = path
	db.read_only = true
	db.verbosity_level = 0
	if not db.open_db(): return _fail("导航规则数据库无法打开")
	var valid: bool = db.query("PRAGMA integrity_check") and db.query_result.size() == 1 and str(db.query_result[0].values()[0]) == "ok"
	if valid: valid = db.query("PRAGMA application_id") and int(db.query_result[0].values()[0]) == 1481526350
	if valid: valid = db.query("PRAGMA user_version") and int(db.query_result[0].values()[0]) == version
	if valid: valid = db.query("SELECT rule_version FROM local_navigation_meta") and db.query_result.size() == 1 and str(db.query_result[0].rule_version) == "local-navigation-v%d" % version
	if valid:
		valid = db.query("SELECT parameter_id,value_real FROM navigation_parameters")
		if valid:
			for row: Dictionary in db.query_result:
				var value: float = float(row.value_real)
				if not is_finite(value) or value <= 0: valid = false; break
				parameters[str(row.parameter_id)] = value
	if valid:
		var gameplay_keys: Array[String] = []
		for key: String in parameters:
			if not key.begins_with("warp_fx_"): gameplay_keys.append(key)
		valid = gameplay_keys.size() == PARAMETERS.size() + (1 if version == 2 else 0)
		if version == 2 and not parameters.has("min_warp_travel_s"): valid = false
		for key: String in PARAMETERS:
			if not parameters.has(key): valid = false
		if valid: valid = float(parameters.approach_speed_fraction) <= 1.0 and float(parameters.orbit_speed_fraction) <= 1.0 and float(parameters.alignment_tolerance_rad) < PI
	if valid:
		valid = db.query("SELECT * FROM navigation_target_rules")
		if valid:
			for row: Dictionary in db.query_result:
				if not is_finite(float(row.approach_arrival_m)) or not is_finite(float(row.orbit_radius_m)) or float(row.approach_arrival_m) <= 0 or float(row.orbit_radius_m) <= float(row.approach_arrival_m): valid = false; break
				if row.warp_arrival_m != null and (not is_finite(float(row.warp_arrival_m)) or float(row.warp_arrival_m) <= 0): valid = false; break
				targets[str(row.target_kind)] = row.duplicate(true)
	if valid:
		valid = targets.size() == KINDS.size()
		for kind: String in KINDS:
			if not targets.has(kind): valid = false
	db.close_db()
	if not valid: return _fail("导航规则数据库版本、完整性或数值无效")
	loaded = true
	return true

func value(key: String) -> float:
	# The controller only requests validated schema keys. No numeric fallback.
	assert(loaded and parameters.has(key), "Missing validated local-navigation parameter: " + key)
	return float(parameters[key])

func target(kind: String) -> Dictionary:
	return targets[kind].duplicate(true) if loaded and targets.has(kind) else {}

func _fail(message: String) -> bool:
	last_error = message
	parameters.clear()
	targets.clear()
	loaded = false
	return false
