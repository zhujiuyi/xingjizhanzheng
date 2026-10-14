extends SceneTree
## Real UI/store/presentation lifecycle with independent progress; no production save edits.
## Logger API: https://docs.godotengine.org/en/stable/classes/class_logger.html
const Main = preload("res://runtime/main.gd")
const UI = preload("res://runtime/ui.gd")
const Presentation = preload("res://runtime/presentation.gd")
const Factory = preload("res://runtime/visuals/visual_factory.gd")
const Types = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []
var finished_voices: int = 0
var diagnostics: CaptureLogger

class CaptureLogger extends Logger:
	var mutex: Mutex = Mutex.new()
	var incidents: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		incidents.append("type=%d %s:%d %s %s %s" % [error_type, file, line, function, code, rationale])
		mutex.unlock()
	func records() -> Array[String]:
		mutex.lock()
		var copy: Array[String] = incidents.duplicate()
		mutex.unlock()
		return copy

func _initialize() -> void:
	diagnostics = CaptureLogger.new()
	OS.add_logger(diagnostics)
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func find_button(node: Node, text: String) -> Button:
	for child: Node in descendants(node):
		if child is Button and child.text == text: return child
	return null

func valid_nodes(nodes: Array) -> bool:
	for index: int in range(nodes.size()):
		var candidate: Variant = nodes[index]
		if not is_instance_valid(candidate): return false
	return true

func dead_effect(p: Node) -> void:
	var node := Node3D.new()
	p.add_child(node)
	p.effects.append(node)
	node.free()

func dead_voice(p: Node) -> void:
	var node := AudioStreamPlayer.new()
	p.add_child(node)
	p.voices.append(node)
	node.free()

func dead_gate(p: Node) -> void:
	var node := Node3D.new()
	p.add_child(node)
	p.gates.append(node)
	node.free()

func hover_page(ui: Node) -> void:
	var count: int = 0
	for candidate: Node in descendants(ui.station_layer if ui.page == "station" else ui.body):
		if candidate is Button and not candidate.disabled:
			candidate.mouse_entered.emit()
			candidate.mouse_exited.emit()
			candidate.mouse_entered.emit()
			count += 1
			if count == 3: break

func _run() -> void:
	# Theme feedback must remain safe across first hover and page replacement.
	var standalone: Node = UI.new()
	root.add_child(standalone)
	await process_frame
	var first: Button = find_button(standalone.body, "建立新远征")
	check(first != null and not first.has_meta("hover_tween"), "fresh title button needs no animation metadata")
	if first == null: await finish(standalone); return
	first.mouse_entered.emit()
	var normal_surface: StyleBoxFlat = first.get_theme_stylebox("normal") as StyleBoxFlat
	var hover_surface: StyleBoxFlat = first.get_theme_stylebox("hover") as StyleBoxFlat
	first.mouse_exited.emit()
	check(normal_surface != null and hover_surface != null and normal_surface.bg_color != hover_surface.bg_color and normal_surface.get_minimum_size() == hover_surface.get_minimum_size() and first.modulate == Color.WHITE, "normal and hover theme states retain distinct color stable metrics and neutral text modulation")
	first.grab_focus()
	check(root.gui_get_focus_owner() == first, "old title control holds keyboard focus before page replacement")
	var stale_button: Variant = first
	standalone.show_page("settings")
	if is_instance_valid(stale_button): stale_button.mouse_entered.emit()
	await process_frame
	check(not is_instance_valid(stale_button), "replaced page destroys old hovered button")
	check(standalone.page == "settings" and (root.gui_get_focus_owner() == null or standalone.panel.is_ancestor_of(root.gui_get_focus_owner())), "page replacement releases old focus or transfers it into the current page")
	standalone.queue_free()
	await process_frame

	var path := ProjectSettings.globalize_path("res://../jiaoben/tmp/ui-lifecycle-v2.db")
	DirAccess.remove_absolute(path)
	var host: Node = Main.new()
	host.progress_database_path = path
	root.add_child(host)
	await process_frame
	check(host.services_ready, "actual client services available")
	await host._command("new_world", "界面生命周期验收", 1, "")
	check(host.state != null, "actual world created")
	if host.state == null: await finish(host); return
	await host._command("save", "0", 1, "manual")
	while host.busy: await process_frame
	var world_id: String = host.state.world_id
	var old_epoch: int = host.state.epoch
	var saved_credit: int = host.state.player().credit
	check(not host.store.list_slots().is_empty(), "successful sealed checkpoint exists before restart")
	host.busy = true
	for round_index: int in range(3):
		for page: String in ["station", "missions", "market", "fitting", "warehouse", "industry", "research", "map", "pause", "settings"]:
			host.ui.show_page(page)
			hover_page(host.ui)
		# Drain several rapid replacement/deferred focus operations together.
		await process_frame
		check(host.ui.page == "settings" and host.ui.body.is_inside_tree(), "rapid switch batch retains current body %d" % round_index)
	host.queue_free()
	await process_frame
	await process_frame

	# Restart through the real title's continue signal against the existing old save.
	host = Main.new()
	host.progress_database_path = path
	root.add_child(host)
	await process_frame
	var resume: Button = find_button(host.ui.body, "继续航行")
	check(resume != null and not resume.text.contains("最近"), "existing save offers short single-line continue button")
	if resume == null: await finish(host); return
	resume.mouse_entered.emit()
	resume.mouse_exited.emit()
	resume.pressed.emit()
	while host.busy: await process_frame
	check(host.state != null and host.state.world_id == world_id and host.state.epoch > old_epoch and host.state.player().credit == saved_credit, "continue restores prior sealed world with a fresh session epoch")
	if host.state == null: await finish(host); return
	var p: Node = host.presentation
	check(p != null, "loaded old save prepares current presentation")

	# A real short UI WAV must finish while the actual pause screen is active.
	host.ui.show_page("pause")
	await process_frame
	p.ui_result(true)
	var voice: Variant = p.voices.back()
	check(is_instance_valid(voice) and voice is AudioStreamPlayer and voice.stream != null, "real UI WAV player created during pause")
	var duration: float = float(voice.stream.get_length()) if is_instance_valid(voice) and voice.stream != null else 0.1
	if is_instance_valid(voice): voice.finished.connect(func(): finished_voices += 1)
	await create_timer(duration + 0.6).timeout
	await process_frame
	check(finished_voices == 1 and not is_instance_valid(voice), "paused UI WAV naturally finishes and frees its player")
	host.ui._back()
	for frame: int in range(3): await process_frame
	check(host.ui.page == "station" and valid_nodes(p.voices), "resume station prunes finished voice references")
	host.busy = true

	# Cover every presentation prune entry with already-freed typed-array elements.
	dead_effect(p); dead_voice(p)
	p.consume(0.0)
	check(valid_nodes(p.effects) and valid_nodes(p.voices), "consume prunes freed effects and voices")
	dead_effect(p)
	p._add(Node3D.new())
	check(valid_nodes(p.effects), "add effect prunes old dead effect before budget count")
	dead_effect(p)
	p.hit(host.state.ship().ship_instance_id, true, host.world.flight.global_position)
	check(valid_nodes(p.effects), "shield hit prunes dead effect before typed iteration")
	dead_voice(p); dead_gate(p)
	p.set_paused(true)
	check(valid_nodes(p.voices) and valid_nodes(p.gates), "pause prunes freed voices and gates before iteration")
	dead_voice(p)
	p.ui_result(false)
	check(valid_nodes(p.voices), "play UI result prunes dead voices before adding a new one")
	var expired_loop := AudioStreamPlayer3D.new()
	p.add_child(expired_loop)
	p.loops["lifecycle_expired"] = expired_loop
	expired_loop.free()
	p._stop_loop("lifecycle_expired")
	check(not p.loops.has("lifecycle_expired"), "stop loop accepts expired player reference")

	# A destroyed target may still be present during the next visual refresh.
	host.busy = false
	host._business_action("undock", "", 1, "")
	while host.busy: await process_frame
	host.busy = true
	var dead_target := Node3D.new()
	host.world.add_child(dead_target)
	host.world.targets["lifecycle_dead_target"] = {"id": "lifecycle_dead_target", "title": "销毁目标夹具", "kind": "npc", "node": dead_target, "anchor_id": ""}
	dead_target.free()
	check(p._node("lifecycle_dead_target") == null, "presentation ignores destroyed world target")
	host.ui._refresh_targets()
	# Drawing must run through CanvasItem's real draw signal, never a direct call.
	host.ui.marker_layer.queue_redraw()
	await process_frame
	await process_frame
	check(host.state.ship().status == Types.ShipStatus.FLYING and not host.ui.target_buttons.has("lifecycle_dead_target"), "flying UI skips freed target before sorting and Node3D cast")
	host.world.targets.erase("lifecycle_dead_target")

	var exit_probe: Node = Presentation.new()
	host.world.add_child(exit_probe)
	var active_voice := AudioStreamPlayer.new()
	active_voice.stream = Factory.sound("ui_confirm")
	exit_probe.add_child(active_voice)
	exit_probe.voices.append(active_voice)
	active_voice.play()
	dead_voice(exit_probe)
	exit_probe.queue_free()
	await process_frame
	check(not is_instance_valid(exit_probe), "exit prunes dead voice and stops active WAV cleanly")
	dead_voice(p)
	host.ui.show_page("missions")
	hover_page(host.ui)
	host.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(host), "host exits while hover/page callbacks and expired audio refs exist")
	await finish(null)

func finish(host: Variant) -> void:
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await process_frame
	# Dummy/CoreAudio release queued playback references on the next mix interval.
	# Headless frames alone can finish before that wall-clock interval elapses.
	await create_timer(0.25).timeout
	var incidents: Array[String] = diagnostics.records()
	check(incidents.is_empty(), "no captured engine/script/shader warnings or errors across lifecycle")
	OS.remove_logger(diagnostics)
	diagnostics = null
	for incident: String in incidents: print("CAPTURED_ENGINE_ERROR " + incident)
	print("UI_LIFECYCLE_V2_RESULT %s checks=%d failures=%d engine_diagnostics=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), incidents.size()])
	quit(0 if failures.is_empty() else 1)
