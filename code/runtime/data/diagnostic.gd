class_name XJDataDiagnostic
extends RefCounted
## Fixed CLI acceptance, not a script loader. Main explicitly opts in and quits.
const Store = preload("res://runtime/data/store.gd")

static func run(test_path: String, upgrade: bool = false) -> bool:
	var evidence: Dictionary = {"checks": 0, "failures": 0}
	var visual_error := XJPresentationResources.validate()
	print("PRESENTATION_RELEASE_RESULT ", "PASS" if visual_error.is_empty() else "FAIL " + visual_error)
	if not visual_error.is_empty(): return false
	test_path = test_path.replace("\\", "/")
	if not test_path.is_absolute_path() or test_path.contains("..") or not test_path.contains("/jiaoben/tmp/"):
		_check(evidence, false, "diagnostic requires absolute jiaoben/tmp test database")
		_finish(evidence)
		return false
	if not upgrade and FileAccess.file_exists(test_path):
		_check(evidence, false, "fresh diagnostic preserves an existing database; choose another test path")
		_finish(evidence)
		return false
	var store: Store = Store.new(test_path)
	_check(evidence, store.open(), "release Store.open and every original asset hash " + store.last_error)
	if int(evidence.failures) == 0:
		if upgrade:
			_check(evidence, store._records("SELECT format_version FROM database_meta")[0].format_version == 8, "release old database upgrade reaches format8")
		var state: XJRuntimeState = store.new_world("独立客户端验收", 42)
		_check(evidence, state != null, "release relational initial snapshot " + store.last_error)
		if state != null:
			var expected_credit: int = state.player().credit - 7
			state.player().credit = expected_credit
			_check(evidence, store.save(state, "manual", 0), "release complete snapshot COMMIT " + store.last_error)
			var world: String = state.world_id
			store.close()
			_check(evidence, store.open(), "release reopen physical progress " + store.last_error)
			if int(evidence.failures) == 0:
				var loaded: XJRuntimeState = store.resume()
				_check(evidence, loaded != null and loaded.world_id == world and loaded.player().credit == expected_credit, "release resume restores durable endpoint " + store.last_error)
				_check(evidence, store._asset_version == "art-full-v2", "release canonical formal asset version")
	store.close()
	_finish(evidence)
	return int(evidence.failures) == 0

static func _check(evidence: Dictionary, value: bool, label: String) -> void:
	evidence.checks += 1
	if not value: evidence.failures += 1
	print(("PASS " if value else "FAIL ") + label)

static func _finish(evidence: Dictionary) -> void:
	print("STORE_RELEASE_RESULT ", "PASS" if int(evidence.failures) == 0 else "FAIL", " checks=", evidence.checks, " failures=", evidence.failures)
