extends SceneTree
## Real Main staging/physics with a test-owned SQLite DB and null-model factory.
## The synthetic NPC is only an in-memory rendering fixture; it is never saved.
const Main = preload("res://runtime/main.gd")
const FailureFactory = preload("res://../jiaoben/tests/failure_factory.gd")
const RealFactory = preload("res://runtime/visuals/industrial_visual_factory.gd")
const D = preload("res://contracts/contract_dtos.gd")
var host: FailureMain
var checks: int = 0
var failures: Array[String] = []
var finishing: bool = false

class FailureMain extends Main:
	var inject_npc_stage: bool = false
	var last_stage_result: bool = true
	var injection_count: int = 0
	func _stage_candidate(candidate: XJRuntimeState, definitions: XJCatalog) -> bool:
		if inject_npc_stage:
			get_tree().node_added.connect(_watch_stage_node)
		last_stage_result = super._stage_candidate(candidate, definitions)
		if inject_npc_stage:
			get_tree().node_added.disconnect(_watch_stage_node)
		return last_stage_result
	func _watch_stage_node(node: Node) -> void:
		if node is XJSector:
			node.child_entered_tree.connect(_inject_stage_factory.bind(node))
	func _inject_stage_factory(child: Node, sector: XJSector) -> void:
		# This runs after build initializes factory and before rebuild_player/sync.
		if not child is XJProjectiles: return
		var npc: D.NpcStateDto = fixture_npc(sector)
		if npc == null: return
		sector.state.add("npc_state", npc)
		sector.factory = FailureFactory
		injection_count += 1
	func fixture_npc(sector: XJSector) -> D.NpcStateDto:
		for spawn: Dictionary in sector.catalog.rows("npc_spawn_defs"):
			if spawn.sector_id != sector.state.current_sector(): continue
			var definition: Dictionary = sector.catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
			var anchor: Dictionary = sector.catalog.one("anchor_defs", "anchor_id", spawn.anchor_id)
			var npc := D.NpcStateDto.new()
			npc.npc_instance_id = "render-failure-fixture"
			npc.spawn_id = str(spawn.spawn_id); npc.sector_id = str(spawn.sector_id)
			npc.alive = true
			npc.shield = float(definition.shield_max); npc.armor = float(definition.armor_max); npc.hull = float(definition.hull_max)
			npc.pos_x = float(anchor.x_m); npc.pos_y = float(anchor.y_m); npc.pos_z = float(anchor.z_m)
			return npc
		return null

func _initialize() -> void:
	var watchdog := create_timer(25.0)
	watchdog.timeout.connect(func(): print("PRESENTATION_FAILURES_RESULT FAIL watchdog timeout"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures.append(label)
		call_deferred("_finish")
	return value

func _slot(index: int) -> Dictionary:
	for row: Dictionary in host.store.list_slots():
		if row.slot_kind == "manual" and int(row.slot_index) == index: return row
	return {}

func _run() -> void:
	var path := ProjectSettings.globalize_path("res://../jiaoben/tmp/presentation-failures-%d.db" % Time.get_ticks_usec())
	host = FailureMain.new()
	host.progress_database_path = path
	root.add_child(host)
	await process_frame
	if not check(host.services_ready, "real Main boots with an isolated temporary database"): return
	await host._command("new_world", "表现失败独立验收", 1, "")
	if not check(host.state != null and is_instance_valid(host.world), "real new-world endpoint prepares an active scene"): return
	host.process_mode = Node.PROCESS_MODE_DISABLED
	host.ui.show_page("pause")
	if not check(host.store.save(host.state, "manual", 0), "stable baseline snapshot commits before injection"): return
	var saved := _slot(0)
	if not check(not saved.is_empty(), "baseline slot has an immutable snapshot selection"): return
	var original_flight: XJFlight = host.world.flight
	var original_record: D.ShipStateDto = original_flight.record
	FailureFactory.reject_player = true
	FailureFactory.reject_enemy = false
	host.world.factory = FailureFactory
	if not check(not host.world.rebuild_player(), "null player scene returns a construction failure"): return
	if not check(host.world.flight == original_flight and not original_flight.is_queued_for_deletion(), "failed replacement retains the old flight without scheduling deletion"): return
	await process_frame
	if not check(is_instance_valid(original_flight) and original_flight.is_inside_tree(), "old flight survives the actual deletion frame"): return
	# A visual record mismatch exercises Main's production rebuild branch without
	# changing the authoritative ship DTO or inserting invalid database records.
	var old_visual_record := D.ShipStateDto.new()
	old_visual_record.ship_instance_id = "prior-visual-only"
	original_flight.record = old_visual_record
	host.ui.show_page("")
	var tick: int = host.state.snapshot.meta.simulation_tick
	host._physics_process(1.0 / float(host.store.catalog.rule("simulation_hz")))
	if not check(host.ui.page == "pause" and host.ui.toast.text.contains("舰船资源不可用"), "Main pauses with the player construction failure reason"): return
	if not check(host.state.snapshot.meta.simulation_tick == tick and host.world.flight == original_flight, "failed player rebuild cannot advance simulation or replace the old flight"): return
	var calls: int = FailureFactory.player_calls
	host._physics_process(1.0)
	if not check(FailureFactory.player_calls == calls and host.state.snapshot.meta.simulation_tick == tick, "paused failure frame does not retry construction or simulate"): return
	original_flight.record = original_record
	host.world.factory = RealFactory
	if not check(host.world.rebuild_player(), "restoring the real factory prepares a player replacement"): return
	host.camera.bind(host.world.flight, host.store.catalog, host.state.player().camera_mode)
	await process_frame
	if not check(not is_instance_valid(original_flight) and is_instance_valid(host.world.flight), "successful replacement releases only the superseded flight"): return
	original_flight = null
	FailureFactory.reject_player = false
	FailureFactory.reject_enemy = true
	var npc := host.fixture_npc(host.world)
	if not check(npc != null and host.state.add("npc_state", npc), "temporary NPC uses actual frozen spawn, anchor and health definitions"): return
	host.world.factory = FailureFactory
	if not check(not host.world.sync_entities(), "null enemy scene propagates through sync_entities as false"): return
	if not check(not host.world.npcs.has(npc.npc_instance_id) and not host.world.targets.has(npc.npc_instance_id), "failed NPC visual publishes neither a body nor a target"): return
	host.ui.show_page("")
	tick = host.state.snapshot.meta.simulation_tick
	host._physics_process(1.0 / float(host.store.catalog.rule("simulation_hz")))
	if not check(host.ui.page == "pause" and host.ui.toast.text.contains("敌舰表现资源不可用"), "Main pauses with the NPC construction failure reason"): return
	if not check(host.state.snapshot.meta.simulation_tick == tick, "NPC construction failure occurs before begin_step advances time"): return
	host.world.factory = RealFactory
	if not check(host.world.sync_entities() and is_instance_valid(host.world.npcs.get(npc.npc_instance_id)), "restoring the real factory recovers the NPC body"): return
	# Remove the rendering-only row before any subsequent save/load operation.
	host.state.remove("npc_state", npc)
	host.world.npcs[npc.npc_instance_id].queue_free()
	host.world.npcs.erase(npc.npc_instance_id); host.world.targets.erase(npc.npc_instance_id)
	npc = null
	if not check(host.world.sync_entities(), "world is usable after removing the transient rendering fixture"): return
	var old_state: XJRuntimeState = host.state
	var old_world: XJSector = host.world
	var old_catalog: XJCatalog = host.store.catalog
	var old_epoch: int = old_state.epoch
	var session_before: Dictionary = host.store._records("SELECT session_id,epoch,loaded_snapshot_id,resume_snapshot_id,last_committed_sequence FROM runtime_session WHERE world_id=?", [old_state.world_id])[0]
	var snapshot_count: int = int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	host.inject_npc_stage = true
	# Invoke the real Store+Main prepare callback directly. Main's UI load command
	# intentionally push_error-logs a rejected load; this test keeps its strict
	# no-engine-error guard while testing the same transactional prepare endpoint.
	var rejected: XJRuntimeState = host.store.load(str(saved.slot_id), str(saved.current_snapshot_id), int(saved.generation), host._prepare_loaded)
	if not check(rejected == null and host.injection_count == 1, "load rejects the injected NPC scene failure"): return
	if not check(not host.last_stage_result and host.last_error.contains("敌舰表现资源不可用"), "actual sector build failure reaches Main staging return value"): return
	var session_after: Dictionary = host.store._records("SELECT session_id,epoch,loaded_snapshot_id,resume_snapshot_id,last_committed_sequence FROM runtime_session WHERE world_id=?", [old_state.world_id])[0]
	if not check(host.state == old_state and host.world == old_world and host.store.active_state == old_state and host.store.catalog == old_catalog and old_state.epoch == old_epoch and session_after == session_before, "failed staging preserves active world, catalog and durable session epoch"): return
	var after := _slot(0)
	if not check(after.current_snapshot_id == saved.current_snapshot_id and after.generation == saved.generation and int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == snapshot_count, "failed NPC staging commits no snapshot or slot replacement"): return
	if not check(host.staged_world == null and host.staged_gameplay == null, "Main disposes the failed candidate scene and gameplay service"): return
	if not check(host.store.save(host.state, "manual", 1), "unchanged old world remains savable after preparation rollback"): return
	host.inject_npc_stage = false
	var loaded: XJRuntimeState = host.store.load(str(saved.slot_id), str(saved.current_snapshot_id), int(saved.generation), host._prepare_loaded)
	if not check(loaded != null and host.last_stage_result, "real factory allows the same immutable slot to load successfully"): return
	host._activate(loaded)
	if not check(host.world != old_world and host.state == loaded and host.state.epoch > old_epoch and is_instance_valid(host.world.flight), "Main activates the recovered candidate after successful load CAS"): return
	if not check(host.store.save(host.state, "manual", 2), "recovered active scene still commits a relational snapshot"): return
	await _finish()

func _finish() -> void:
	if finishing: return
	finishing = true
	FailureFactory.reject_player = false; FailureFactory.reject_enemy = false
	if is_instance_valid(host): host.queue_free()
	host = null
	await process_frame
	await process_frame
	# Fixture-only wait for native audio ownership release, never a game delay.
	await create_timer(0.25).timeout
	print("PRESENTATION_FAILURES_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
