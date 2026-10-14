extends Node
## Three real Store/Main failure boundaries. Only the staging rejection is injected.
const LoadingJob = preload("res://runtime/data/loading_job.gd")
const Store = preload("res://runtime/data/store.gd")
const ENV_PREFIX: String = "XJ_LOADING_FAILURE_V62"
const DIAGNOSTIC_META: String = "xj_loading_failure_v62_diagnostic"
const REJECTION: String = "loading-failure-v62 injected candidate construction failure"
const EXPECTED_DIAGNOSTICS: Array[Dictionary] = [
	{"message": "ERROR: Missing save slot", "count_per_log": 1},
	{"message": "ERROR: STAGING_FAILED loading-failure-v62 injected candidate construction failure", "count_per_log": 1},
]

class FailureMain extends "res://runtime/main.gd":
	var reject_next_preparation: bool = false
	var rejected_preparations: int = 0
	func _stage_candidate(candidate: XJRuntimeState, definitions: XJCatalog) -> bool:
		if reject_next_preparation:
			reject_next_preparation = false
			rejected_preparations += 1
			last_error = "loading-failure-v62 injected candidate construction failure"
			return false
		return super._stage_candidate(candidate, definitions)

var host: Node
var directory: String = ""
var checks: int = 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var request_count: int = 0
var started_us: int = 0
var finishing: bool = false
@onready var root: Window = get_tree().root

func _ready() -> void:
	get_tree().set_meta(DIAGNOSTIC_META, true)
	started_us = Time.get_ticks_usec()
	run.call_deferred()

func check(ok: bool, description: String) -> bool:
	checks += 1
	print(("PASS " if ok else "FAIL ") + description)
	if not ok: failures.append(description)
	return ok

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func wait_idle(description: String, timeout_s: float = 20.0) -> bool:
	var start: int = Time.get_ticks_usec()
	while is_instance_valid(host) and host.busy and Time.get_ticks_usec() - start < int(timeout_s * 1000000.0):
		await get_tree().process_frame
	return check(is_instance_valid(host) and not host.busy, description)

func database_identity(database: RefCounted) -> String:
	# Only called before starting a worker, or after it has joined/closed.
	var result: Dictionary = {}
	for table: String in ["world", "save_snapshot", "save_slot", "runtime_session", "content_snapshot", "world_initialization_grant"]:
		result[table] = database._records('SELECT * FROM "' + table + '" ORDER BY rowid')
	return JSON.stringify(result)

func recovered_world(expected_state: RefCounted, expected_world: Node, before: String) -> void:
	check(host.state == expected_state and host.world == expected_world and is_instance_valid(host.world), "failed loading retains the exact active state and world")
	check(host.store.active_state == expected_state and database_identity(host.store) == before, "failed loading preserves all durable worlds, snapshots, slots and sessions")
	check(not host.store.busy and host.store.phase == "FAILED" and host.store.staging_catalog == null, "failed Store returns its documented failed idle state without staging ownership")
	check(host.staged_world == null and host.staged_gameplay == null and host.loading_job == null and host.loading_overlay == null, "failed Main discards staging and releases the joined job and overlay")
	check(not host.ui.loading_suspended and host.ui.root.is_visible_in_tree() and host.can_process() and host.is_processing() and host.is_physics_processing(), "failed loading restores visible UI and both normal Main callbacks")

func complete_case(id: String, prior_checks: int, prior_failures: int) -> void:
	cases.append({"id": id, "passed": failures.size() == prior_failures, "checks": checks - prior_checks, "failures": failures.size() - prior_failures})

func missing_slot_case() -> bool:
	var prior_checks: int = checks
	var prior_failures: int = failures.size()
	var current_state: RefCounted = host.state
	var current_world: Node = host.world
	var before: String = database_identity(host.store)
	# The production branch emits exactly the first declared expected diagnostic.
	host.ui.requested.emit("load", "missing-loading-failure-v62-slot", 1, "")
	if not await wait_idle("missing-slot Main load finishes within twenty seconds"): return false
	await frames(3)
	check(host.store.last_error == "Missing save slot", "missing-slot failure retains the exact Store error")
	recovered_world(current_state, current_world, before)
	complete_case("missing_slot_preserves_world", prior_checks, prior_failures)
	return true

func prepare_rejection_case() -> bool:
	var prior_checks: int = checks
	var prior_failures: int = failures.size()
	host.ui.show_page("market")
	await frames(3)
	var row: Dictionary = {}
	for candidate: Dictionary in host.ui.quotes:
		if is_instance_valid(candidate.get("amount")) and is_instance_valid(candidate.get("button")) and is_instance_valid(candidate.get("total_label")):
			row = candidate
			break
	if not check(not row.is_empty(), "real market quantity and action callbacks exist before loading"): return false
	var edit: LineEdit = row.amount.get_line_edit()
	var previous_raw: String = edit.text
	var previous_total: String = row.total_label.text
	var previous_status: String = row.status_label.text
	var current_state: RefCounted = host.state
	var current_world: Node = host.world
	var before: String = database_identity(host.store)
	host.reject_next_preparation = true
	# Production _command/Store/worker/mailbox and cleanup are unchanged.
	host.ui.requested.emit("new_world", "loading-failure-v62 rejected world", 1, "")
	var requests_before_stale: int = request_count
	check(host.busy and host.ui.loading_suspended and host.process_mode == Node.PROCESS_MODE_DISABLED and not host.ui.root.visible, "real loading enters the exclusive Store handoff before stale signals")
	# Deliberately deliver old callbacks while their controls are hidden. These
	# signals cannot be delivered by ordinary pointer input behind the overlay.
	edit.text = "2"
	edit.text_changed.emit("2")
	edit.focus_exited.emit()
	row.button.pressed.emit()
	await frames(3)
	check(request_count == requests_before_stale, "old market button and editor callbacks submit no additional request while Store is handed off")
	check(row.total_label.text == previous_total and row.status_label.text == previous_status, "old market quote callbacks do not recompute while loading is suspended")
	if not await wait_idle("prepare-rejected Main new-world finishes within twenty seconds"): return false
	await frames(3)
	check(host.rejected_preparations == 1 and not host.reject_next_preparation and host.store.last_error == "STAGING_FAILED" and host.last_error == REJECTION, "one real mailbox preparation is rejected with the exact declared failure")
	recovered_world(current_state, current_world, before)
	# Restore only the deliberately altered hidden editor through its real signal.
	edit.text = previous_raw
	edit.text_changed.emit(previous_raw)
	complete_case("prepare_rejection_preserves_world_and_blocks_old_callbacks", prior_checks, prior_failures)
	return true

func close_waiting_prepare_case() -> bool:
	var prior_checks: int = checks
	var prior_failures: int = failures.size()
	var before: String = database_identity(host.store)
	var database_path: String = host.progress_database_path
	var database: RefCounted = host.store
	host.ui.loading_suspended = true
	root.gui_release_focus()
	host.ui.root.hide()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	var job: RefCounted = LoadingJob.new()
	host.loading_job = job
	var operation: Callable = database.new_world.bind("loading-failure-v62 close before prepare", 62, job.prepare)
	if not check(job.start(database, operation) == OK, "real Store worker starts for the pending-prepare teardown"): return false
	var request: Dictionary = {}
	var waiting_us: int = Time.get_ticks_usec()
	while request.is_empty() and job.thread.is_alive() and Time.get_ticks_usec() - waiting_us < 20000000:
		request = job.take_preparation()
		if request.is_empty(): await get_tree().process_frame
	if not check(not request.is_empty(), "real new-world transaction reaches a waiting mailbox preparation within twenty seconds"):
		job.shutdown()
		host.loading_job = null
		return false
	check(request.state != host.state and request.catalog != null, "pending preparation owns an unpublished candidate and frozen catalog")
	# Never accept the request. Real Main._exit_tree must cancel and signal the
	# waiter, join the worker, and only then close its sole Store connection.
	var closing_us: int = Time.get_ticks_usec()
	root.remove_child(host)
	var close_ms: float = float(Time.get_ticks_usec() - closing_us) / 1000.0
	check(close_ms < 2000.0 and not job.thread.is_started() and not job.thread.is_alive(), "Main teardown releases the pending prepare and joins without deadlock within two seconds")
	check(database.phase == "CLOSED" and not database.busy and database.staging_catalog == null and database._db == null, "real Main closes Store only after its worker has joined")
	host.free()
	host = null
	var reopened: RefCounted = Store.new(database_path)
	var opened: bool = reopened.open()
	check(opened, "closed scoped database reopens without a retained writer lock")
	if opened:
		check(database_identity(reopened) == before, "shutdown during prepare rolls back the unpublished new world and preserves all durable identity")
		reopened.close()
	observations.append({"event": "main_exit_while_waiting_prepare", "close_ms": close_ms, "worker_joined": not job.thread.is_started()})
	complete_case("close_while_prepare_joins_before_store_close", prior_checks, prior_failures)
	return true

func run() -> void:
	directory = OS.get_environment(ENV_PREFIX + "_DIRECTORY").replace("\\", "/")
	var script: String = str(get_script().resource_path).replace("\\", "/")
	var requested: String = OS.get_environment(ENV_PREFIX + "_SCRIPT").replace("\\", "/")
	var expected: String = script.get_base_dir().get_base_dir().path_join("tmp/loading-failure-v62")
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	if not check(DisplayServer.get_name() != "headless" and script.is_absolute_path() and script.ends_with("/jiaoben/tests/loading_failure_v62.gd") and not script.contains("..") and requested == script and directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == expected and pattern.search(directory.get_file()) != null and not FileAccess.file_exists(directory.path_join("progress.db")), "native fixed external test and fresh scoped UUID database required"):
		get_tree().quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_factor = 1.0
	host = FailureMain.new()
	host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host)
	await frames(3)
	if not check(host.services_ready and host.state == null, "real Main initializes its fresh title without personal data"):
		await finish()
		return
	host.ui.requested.connect(func(_action: String, _target: String, _quantity: int, _extra: String): request_count += 1)
	host.ui.requested.emit("new_world", "loading-failure-v62 preserved world", 1, "")
	if not await wait_idle("real baseline world is created within twenty seconds") or not check(host.state != null and host.world != null, "baseline has a real committed world"):
		await finish()
		return
	if not await missing_slot_case() or not await prepare_rejection_case():
		await finish()
		return
	await close_waiting_prepare_case()
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(5)
	check(cases.size() == 3 and Time.get_ticks_usec() - started_us < 60000000, "all three declared failure boundaries complete within sixty seconds")
	var result: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "cases": cases, "directory": directory, "native": DisplayServer.get_name() != "headless", "packed_runtime": not OS.has_feature("editor"), "expected_diagnostics": EXPECTED_DIAGNOSTICS, "observations": observations, "seconds": float(Time.get_ticks_usec() - started_us) / 1000000.0, "scope": "three fresh-database real Main/Store failure and teardown cases; only one prepare rejection injected; synthetic stale callback delivery; no personal database, balance or gameplay fixtures"}
	var file: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")
		file.close()
	print("LOADING_FAILURE_V62_RESULT ", result.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
