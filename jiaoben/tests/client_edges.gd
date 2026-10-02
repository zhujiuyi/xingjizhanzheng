extends SceneTree
## Real Main lifecycle acceptance. Test-owned DB; failures terminate promptly.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []
var host: EdgeMain
var watchdog: SceneTreeTimer

class EdgeMain extends Main:
	var reject_stage: bool = false
	func _stage_candidate(candidate: XJRuntimeState, definitions: XJCatalog) -> bool:
		if reject_stage:
			last_error = "injected candidate construction failure"
			return false
		return super._stage_candidate(candidate, definitions)

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures.append(label)
		_finish()
	return value

func _initialize() -> void:
	watchdog = create_timer(30.0)
	watchdog.timeout.connect(_watchdog)
	call_deferred("_run")

func _watchdog() -> void:
	print("CLIENT_EDGES_RESULT FAIL watchdog timeout")
	quit(1)

func _wait_writer() -> bool:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	return check(not host.busy, "client writer drains within bounded wait")

func _run() -> void:
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/client-edges.db")
	DirAccess.remove_absolute(path)
	host = EdgeMain.new()
	host.progress_database_path = path
	root.add_child(host)
	await process_frame
	if not check(host.services_ready, "main boots with isolated data service"): return
	if not check(abs(float(host.preferences.mouse_sensitivity) - 0.002) < 0.00000001, "new profile mouse preference is 0.002 rad/pixel"): return
	await host._command("new_world", "生命周期独立验收", 1, "")
	if not check(host.state != null and host.world != null, "main prepares and activates initial world before commit"): return
	host.ui.show_page("pause")
	await process_frame
	if not check(host.store.save(host.state, "manual", 0), "initial stable manual endpoint"): return
	var slot: Dictionary = {}
	for row in host.store.list_slots():
		if row.slot_kind == "manual" and row.slot_index == 0: slot = row
	if not check(not slot.is_empty(), "manual selection exists"): return
	var old_state = host.state
	var old_world = host.world
	var old_catalog = host.store.catalog
	var old_epoch: int = old_state.epoch
	host.reject_stage = true
	await host._command("load", slot.slot_id, slot.generation, slot.current_snapshot_id)
	if not check(host.state == old_state and host.world == old_world and host.store.catalog == old_catalog and host.state.epoch == old_epoch, "main load prepare failure keeps old scene/context"): return
	if not check(host.staged_world == null and host.staged_gameplay == null, "main releases failed staging"): return
	if not check(host.store.save(host.state, "manual", 0), "main old world can save after load prepare failure"): return
	var count_before: int = int(host.store._records("SELECT count(*) AS n FROM world")[0].n)
	await host._command("new_world", "应回滚的新档", 1, "")
	if not check(host.state == old_state and host.world == old_world and host.store.active_state == old_state, "main new-world prepare failure preserves active scene"): return
	if not check(int(host.store._records("SELECT count(*) AS n FROM world")[0].n) == count_before and host.store.save(host.state), "main failed new-world leaves no records and old world savable"): return
	host.reject_stage = false
	host.gameplay.combat_remaining_s = float(host.store.catalog.rule("combat_exit_delay_s"))
	host._request_save("manual", 3)
	var manual_request: Dictionary = host.deferred_save.duplicate(true)
	host._queue_autosave()
	if not check(host.deferred_save == manual_request and manual_request.kind == "manual" and manual_request.index == 3, "deferred manual request survives competing autosave"): return
	var tick: int = host.state.snapshot.meta.simulation_tick
	var combat: float = host.gameplay.combat_remaining_s
	host._process(float(host.store.catalog.rule("save_wait_prompt_s")) + 0.1)
	await physics_frame
	await physics_frame
	if not check(host.state.snapshot.meta.simulation_tick == tick and host.gameplay.combat_remaining_s == combat, "pause freezes world time and combat while save waits"): return
	if not check(host.save_wait_elapsed >= float(host.store.catalog.rule("save_wait_prompt_s")) and host.ui.operation_message.contains("放弃"), "save wait prompt uses real UI time while paused"): return
	host._command("cancel_save", "", 1, "")
	if not check(host.deferred_save.is_empty(), "cancel waiting save clears only pending intent"): return
	host.gameplay.combat_remaining_s = 0.0
	host.fire_held = true
	host.observing = true
	var release := InputEventAction.new()
	release.action = "fire"; release.pressed = false
	host._input(release)
	if not check(not host.fire_held, "UI-consumed mouse release still clears held firing"): return
	release.action = "observe"
	host._input(release)
	if not check(not host.observing and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "observation release clears capture while UI blocks input"): return
	host._command("preference", "mouse_sensitivity", 1, "1.0")
	host.ui.show_page("settings")
	await process_frame
	if not check(float(host.store.preferences().mouse_sensitivity) == 1.0, "opening settings preserves explicit existing sensitivity"): return
	host._command("preference", "mouse_sensitivity", 1, "0.002")
	host.ui.show_page("pause")
	# Infrastructure placement only: remote rescue itself uses actual gameplay.
	var remote = host.store.clone_state(host.state)
	remote.ship().sector_id = "sector_echo"
	remote.ship().status = T.ShipStatus.FLYING
	remote.ship().has_station_id = false
	remote.ship().station_id = ""
	remote.player().has_docked_station_id = false
	remote.player().docked_station_id = ""
	for container in remote.rows("container_state"):
		if container.ship_instance_id == remote.ship().ship_instance_id: container.sector_id = "sector_echo"
	if not check(host._stage_candidate(remote, host.store.catalog), "remote scene fixture builds from real catalog"): return
	host._activate(remote)
	host.ui.show_page("pause")
	var remote_world_id: int = host.world.get_instance_id()
	if not check(host.state.current_sector() == "sector_echo" and not host.world.targets.has("station_anchor_port"), "fixture is a distinct remote station/gate world"): return
	host.gameplay.damage_ship(Vector3.ONE * 1000000.0)
	if not check(host.state.ship().status == T.ShipStatus.DESTROYED and host._save_block_reason().contains("先申请救援"), "destroyed ship defers SaveEligibility to rescue"): return
	host._business_action("request_rescue", "", 1, "")
	if not await _wait_writer(): return
	host.ui.show_page("pause")
	if not check(host.state.current_sector() == "sector_anchor" and host.state.ship().status == T.ShipStatus.DOCKED, "actual rescue returns live controlled ship to anchor station"): return
	if not check(host.world.get_instance_id() != remote_world_id and host.world.targets.has("station_anchor_port"), "rescue rebuilds complete world rather than only player model"): return
	var correct_targets: bool = true
	for station in host.store.catalog.rows("station_defs"):
		correct_targets = correct_targets and (host.world.targets.has(station.station_id) == (station.sector_id == host.state.current_sector()))
	if not check(correct_targets, "rescued world's station targets belong only to destination sector"): return
	if not check(host.store.save(host.state, "manual", 1), "real rescued world commits relational snapshot"): return
	var preferences = host.store.preferences()
	if not check(abs(float(preferences.mouse_sensitivity) - 0.002) < 0.00000001, "current explicit mouse setting retained"): return
	host.ui.show_page("pause")
	var discard: Button = host.ui.body.find_child("QuitWithoutSave", true, false) as Button
	if not check(discard != null and not discard.disabled, "pause exposes explicit discard-and-exit choice"): return
	# A human cannot press a newly rendered choice in the exact stack that
	# created the preceding confirmation sound. Let these finite UI voices
	# complete before testing the quit command; no world-time advance occurs.
	var ui_voice_duration: float = 0.0
	for voice: Node in host.presentation.voices:
		if is_instance_valid(voice) and voice.get("bus") == "UI" and voice.get("stream") != null:
			ui_voice_duration = maxf(ui_voice_duration, float(voice.get("stream").get_length()))
	await create_timer(minf(1.0, ui_voice_duration + 0.05)).timeout
	var endpoints: Array[Dictionary] = host.store.list_slots()
	host.deferred_save = {"kind": "manual", "index": 4, "after": "quit"}
	discard.pressed.emit()
	if not check(host.deferred_save.is_empty() and host.store.list_slots() == endpoints, "discard choice exits without publishing pending save"): return
	_finish()

func _finish() -> void:
	if watchdog != null and watchdog.timeout.is_connected(_watchdog): watchdog.timeout.disconnect(_watchdog)
	watchdog = null
	if is_instance_valid(host): host.free()
	print("CLIENT_EDGES_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
