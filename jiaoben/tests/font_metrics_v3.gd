extends Node
## Measures whether adding the Medium weight changes text metrics.
## Layout depends on this: a bolder weight must not re-flow headings or tables.
## Read-only: loads font resources, writes a JSON report, touches no database.

const REGULAR := "res://assets/interface_v3/NotoSansCJKsc-Regular.otf"
const MEDIUM := "res://assets/interface_v3/NotoSansCJKsc-Medium.otf"
const SIZES: Array[int] = [11, 13, 15, 20, 28]
# Measured 2026-10-14: CJK advances are weight-independent, Latin/digit advances
# grow slightly with weight. Keep the two groups apart so the assertion states
# the measured truth instead of a convenient one.
const CJK_SAMPLES: Array[String] = [
	"星际战舰",
	"舰船配装",
	"未安装",
	"航路重建进度 · 主线剧情",
]
const LATIN_SAMPLES: Array[String] = [
	"815800",
	"0.019 AU",
	"ABCdef 0123",
	"锚港主站 / 远际级巡洋舰 / 815800 信用点",
]
# Widest measured growth is 4 px ("ABCdef 0123" at 28 px); allow headroom but
# fail loudly if a future font swap makes weight change the layout meaningfully.
const LATIN_DELTA_LIMIT: float = 6.0

var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var report_path: String = ""

func _ready() -> void:
	report_path = OS.get_environment("XJ_FONT_METRICS_REPORT")
	var regular: FontFile = load(REGULAR)
	var medium: FontFile = load(MEDIUM)
	check(regular != null, "Regular font resource loads")
	check(medium != null, "Medium font resource loads")
	if regular == null or medium == null:
		_finish()
		return
	check(regular != medium, "Medium is a distinct font resource, not an alias of Regular")
	check(str(regular.resource_path) == REGULAR, "Regular resource path is the shipped asset")
	check(str(medium.resource_path) == MEDIUM, "Medium resource path is the shipped asset")
	for size: int in SIZES:
		check(regular.get_height(size) > 0.0 and medium.get_height(size) > 0.0, "both weights report a line height at %d px" % size)
		var same_height: bool = is_equal_approx(regular.get_height(size), medium.get_height(size))
		check(same_height, "line height matches between weights at %d px" % size)
		observations.append({
			"size": size,
			"regular_height": regular.get_height(size),
			"medium_height": medium.get_height(size),
			"regular_ascent": regular.get_ascent(size),
			"medium_ascent": medium.get_ascent(size),
			"regular_descent": regular.get_descent(size),
			"medium_descent": medium.get_descent(size),
		})
		for sample: String in CJK_SAMPLES:
			var cjk: Dictionary = measure(regular, medium, sample, size)
			check(cjk.same, "CJK advance width is weight-independent: %d px '%s'" % [size, sample])
			observations.append({"kind": "cjk", "size": size, "sample": sample, "regular_width": cjk.regular, "medium_width": cjk.medium})
		for sample: String in LATIN_SAMPLES:
			var latin: Dictionary = measure(regular, medium, sample, size)
			var delta: float = latin.medium - latin.regular
			check(delta >= 0.0 and delta <= LATIN_DELTA_LIMIT,
				"Latin/digit growth stays within %.0f px: %d px '%s' grew %+.1f px" % [LATIN_DELTA_LIMIT, size, sample, delta])
			observations.append({"kind": "latin", "size": size, "sample": sample, "regular_width": latin.regular, "medium_width": latin.medium, "delta": delta})
	_check_glyph_coverage(regular, MEDIUM)
	_check_glyph_coverage(medium, MEDIUM)
	_finish()

func measure(regular: FontFile, medium: FontFile, sample: String, size: int) -> Dictionary:
	var left: Vector2 = regular.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var right: Vector2 = medium.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	return {"regular": left.x, "medium": right.x, "same": is_equal_approx(left.x, right.x) and is_equal_approx(left.y, right.y)}

func _check_glyph_coverage(font: FontFile, path: String) -> void:
	# The shipped font must carry every character the UI is allowed to use.
	# U+25B8, U+25B0 and U+2715 are known absent and must stay out of UI strings.
	for allowed: String in ["←", "×", "…", "·", "—"]:
		check(font.has_char(allowed.unicode_at(0)), "%s carries %s for UI use" % [path.get_file(), _codepoint(allowed)])
	for banned: String in ["▸", "▰", "✕"]:
		check(not font.has_char(banned.unicode_at(0)), "%s keeps known-missing %s out of reach" % [path.get_file(), _codepoint(banned)])

func _codepoint(value: String) -> String:
	return "U+%04X" % value.unicode_at(0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	var summary: Dictionary = {
		"result": "PASS" if failures.is_empty() else "FAIL",
		"checks": checks,
		"failures": failures.size(),
		"failure_labels": failures,
		"observations": observations,
	}
	var text: String = JSON.stringify(summary, "  ", false)
	print("FONT_METRICS ", summary.result, " checks=", checks, " failures=", failures.size())
	for failure: String in failures:
		print("FONT_METRICS_FAILURE ", failure)
	if not report_path.is_empty():
		var handle: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		if handle != null:
			handle.store_string(text)
			handle.close()
	get_tree().quit(0 if failures.is_empty() else 1)
