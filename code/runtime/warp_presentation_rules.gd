class_name XJWarpPresentationRules
extends RefCounted
## Independently versioned presentation, never changes frozen gameplay rules.
const PATH: String = "res://data/warp_presentation_v3.db"
const VERSION: String = "warp-presentation-v3"
const KEYS: Array[String] = ["warp_fx_fade_in_s", "warp_fx_fade_out_s", "warp_fx_warmup_strength", "warp_fx_blur_radius_px", "warp_fx_blur_lod", "warp_fx_fov_add_deg", "warp_fx_mask_padding_ratio", "warp_fx_mask_feather_px", "warp_fx_center_clear_ratio", "warp_fx_streak_count", "warp_fx_streak_radius_ship_lengths", "warp_fx_streak_length_ship_lengths", "warp_fx_streak_extent_ship_lengths", "warp_fx_streak_speed_ship_lengths_s", "warp_fx_streak_width_ship_lengths", "warp_fx_streak_alpha", "warp_fx_warmup_speed_ratio", "warp_fx_reference_height_px", "warp_fx_departure_duration_s", "warp_fx_departure_distance_ship_lengths", "warp_fx_mask_resolution_scale"]
var parameters: Dictionary = {}
var last_error: String = ""

func load_rules() -> bool:
	parameters.clear()
	last_error = ""
	var db: Object = ClassDB.instantiate("SQLite")
	if db == null or not FileAccess.file_exists(PATH): return _fail("跃迁表现数据库缺失")
	db.path = PATH
	db.read_only = true
	db.verbosity_level = 0
	if not db.open_db(): return _fail("跃迁表现数据库无法打开")
	var valid: bool = db.query("PRAGMA integrity_check") and db.query_result.size() == 1 and str(db.query_result[0].values()[0]) == "ok"
	if valid: valid = db.query("PRAGMA application_id") and int(db.query_result[0].values()[0]) == 1481262680
	if valid: valid = db.query("PRAGMA user_version") and int(db.query_result[0].values()[0]) == 3
	if valid: valid = db.query("SELECT rule_version FROM warp_presentation_meta") and db.query_result.size() == 1 and str(db.query_result[0].rule_version) == VERSION
	if valid:
		valid = db.query("SELECT parameter_id,value_real FROM warp_visual_parameters")
		if valid:
			for row: Dictionary in db.query_result:
				var value: float = float(row.value_real)
				if not is_finite(value) or value < 0.0: valid = false; break
				parameters[str(row.parameter_id)] = value
	db.close_db()
	if valid:
		valid = parameters.size() == KEYS.size()
		for key: String in KEYS:
			if not parameters.has(key) or (float(parameters[key]) <= 0.0 and key != "warp_fx_center_clear_ratio"): valid = false
	if not valid: return _fail("跃迁表现数据库版本、完整性或参数无效")
	return true

func _fail(reason: String) -> bool:
	last_error = reason
	parameters.clear()
	return false
