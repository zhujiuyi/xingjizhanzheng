extends SceneTree
## External probe against exported PCK/app. Never writes the production profile.
const Store = preload("res://runtime/data/store.gd")
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var test_path: String = OS.get_environment("XJ_TEST_DATABASE") if arguments.is_empty() else arguments[0]
	if not test_path.is_absolute_path() or not test_path.contains("/jiaoben/tmp/"):
		push_error("Pass absolute jiaoben/tmp progress path using XJ_TEST_DATABASE or --")
		quit(1)
		return
	var upgrade: bool = arguments.size() > 1 and arguments[1] == "upgrade"
	if not upgrade: DirAccess.remove_absolute(test_path)
	var store: Store = Store.new(test_path)
	check(store.open(), "release Store.open and every original asset hash " + store.last_error)
	if upgrade: check(store._records("SELECT format_version FROM database_meta")[0].format_version == 5, "release legacy database upgrade preserves source and reaches format5")
	if failures.is_empty():
		var state = store.new_world("独立客户端验收", 42)
		check(state != null, "release relational initial snapshot " + store.last_error)
		if state != null:
			var expected_credit: int = state.player().credit - 7
			state.player().credit = expected_credit
			check(store.save(state, "manual", 0), "release complete snapshot COMMIT " + store.last_error)
			var world: String = state.world_id
			store.close()
			check(store.open(), "release reopen physical progress")
			var loaded = store.resume()
			check(loaded != null and loaded.world_id == world and loaded.player().credit == expected_credit, "release resume restores durable endpoint " + store.last_error)
			check(store._asset_version == "art-full-v2", "release canonical formal asset version")
	store.close()
	print("STORE_RELEASE_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
