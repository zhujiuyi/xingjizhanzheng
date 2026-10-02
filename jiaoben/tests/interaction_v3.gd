extends SceneTree
## Real Main + frozen SQLite rules; fixture DB stays below jiaoben/tmp.
const Main = preload("res://runtime/main.gd")
const Context = preload("res://runtime/interaction_context.gd")
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
var host: Main
var checks := 0
var failures: Array[String] = []
var watchdog: SceneTreeTimer
var finishing := false

func _initialize() -> void:
	watchdog = create_timer(35.0)
	watchdog.timeout.connect(func(): print("INTERACTION_V3 FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
		call_deferred("_finish")
	return ok

func context(target: String) -> Dictionary:
	return Context.inspect(host.world, host.state, host.store.catalog, host.gameplay, target)

func place(point: Vector3, speed: float = 0.0) -> void:
	host.world.flight.global_position = point
	host.world.flight.velocity = Vector3.RIGHT * speed
	host.world.flight.write_back()

func press_f() -> void:
	var input := InputEventAction.new()
	input.action = "interact"; input.pressed = true
	host._unhandled_input(input)

func wait_writer() -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	return check(not host.busy, "real Main writer drains before subsequent interaction")

func _run() -> void:
	host = Main.new()
	var db := ProjectSettings.globalize_path("res://../jiaoben/tmp/interaction-v3-%d.db" % Time.get_ticks_usec())
	host.progress_database_path = db
	root.add_child(host)
	await process_frame
	if not check(host.services_ready, "Main boots isolated store"): return
	await host._command("new_world", "交互资格独立验收", 1, "")
	if not check(host.state != null and host.world != null, "new world has real target nodes and frozen definitions"): return
	# Deterministic fixture placement: no unrequested simulation/autosave runs.
	host.process_mode = Node.PROCESS_MODE_DISABLED
	var station_id := "station_anchor_port"
	var station: Node3D = host.world.targets[station_id].node
	var dock_radius := float(host.store.catalog.rule("dock_radius_m"))
	var dock_speed := float(host.store.catalog.rule("dock_max_speed_mps"))
	if not check(not context(station_id).ready and context(station_id).reason.contains("出港"), "docked state is explicit and cannot redock"): return
	host._command("undock", "", 1, "")
	if not await wait_writer(): return
	if not check(host.state.ship().status == T.ShipStatus.FLYING, "actual undock permits interaction"): return
	host.ui.show_page("")
	place(station.global_position + Vector3.RIGHT * (dock_radius + 1))
	if not check(not context(station_id).ready and not context(station_id).in_range, "station outside authoritative range is rejected"): return
	place(station.global_position + Vector3.RIGHT * dock_radius, dock_speed)
	var preview := context(station_id)
	if not check(preview.ready and preview.range_m == dock_radius and preview.max_speed_mps == dock_speed, "inclusive docking distance/speed boundary uses SQLite rules"): return
	place(station.global_position, dock_speed + 1)
	if not check(not context(station_id).ready and context(station_id).reason.contains("制动"), "over-speed shows braking qualification reason"): return
	host.ui.target_id = station_id
	press_f()
	if not check(host.state.ship().status == T.ShipStatus.FLYING and host.ui.toast.text.contains("制动"), "F cannot bypass docking speed and gives same feedback"): return
	place(station.global_position)
	host.gameplay.combat_remaining_s = float(host.store.catalog.rule("combat_exit_delay_s"))
	if not check(not context(station_id).ready and context(station_id).reason.contains("交战"), "combat denies station interaction"): return
	host.gameplay.combat_remaining_s = 0.0
	# Move only the live node, proving HUD distances are not a stale catalog copy.
	var original_position := station.global_position
	station.global_position += Vector3.RIGHT * (dock_radius + 1)
	if not check(not context(station_id).ready and context(station_id).distance_m > dock_radius, "qualification measures actual world target position"): return
	station.global_position = original_position
	var gate_id := ""
	var gate_definition: Dictionary = {}
	for row: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
		if row.origin_sector_id == host.state.current_sector():
			gate_id = row.endpoint_id; gate_definition = row; break
	if not check(not gate_id.is_empty() and host.world.targets.has(gate_id), "real current-sector gate endpoint exists"): return
	host.ui.target_id = gate_id
	var selected := Context.choose(host.world, host.state, host.store.catalog, host.gameplay, gate_id)
	if not check(selected.target_id == station_id and selected.ready, "selected remote target falls back to nearest eligible station"): return
	host.ui.requested.emit("interact_target", gate_id, 1, "")
	if not check(host.state.ship().status == T.ShipStatus.FLYING and not host.travel.active(), "explicit mouse target never silently docks at fallback station"): return
	press_f()
	if not check(host.state.ship().status == T.ShipStatus.DOCKED and host.ui.target_id == station_id, "F executes nearby candidate and selects that actual target"): return
	if not await wait_writer(): return
	host._command("undock", "", 1, "")
	if not await wait_writer(): return
	host.ui.show_page("")
	place(station.global_position)
	host.ui.target_id = station_id
	host.ui.requested.emit("interact_target", station_id, 1, "")
	if not check(host.state.ship().status == T.ShipStatus.DOCKED, "mouse button uses same station command and qualification"): return
	if not await wait_writer(): return
	host._command("undock", "", 1, "")
	if not await wait_writer(): return
	host.ui.show_page("")
	if not check(not host.ui.keyboard_blocked(), "flight keyboard guard permits contextual shortcuts"): return
	host.ui.show_page("pause")
	if not check(host.ui.keyboard_blocked(), "pause menu still blocks keyboard interaction"): return
	host.ui.show_page("")
	if DisplayServer.get_name() != "headless":
		# Human pointer mode: real OS mouse position, not a mocked hit test.
		var prior_pointer: bool = host.pointer_mode
		host.pointer_mode = true
		host._sync_mouse_mode()
		await process_frame
		var prior_mouse := host.ui.root.get_global_mouse_position()
		Input.warp_mouse(host.ui.target_panel.get_global_rect().get_center())
		await process_frame
		await process_frame
		if not check(host.ui.target_panel.get_global_rect().has_point(host.ui.root.get_global_mouse_position()) and host.ui.input_blocked() and not host.ui.keyboard_blocked(), "real pointer over target HUD blocks flight mouse but permits F keyboard"): return
		place(station.global_position)
		host.ui.target_id = station_id
		press_f()
		if not check(host.state.ship().status == T.ShipStatus.DOCKED, "F docks while OS pointer hovers the displayed context button panel"): return
		if not await wait_writer(): return
		host._command("undock", "", 1, "")
		if not await wait_writer(): return
		host.ui.show_page("")
		Input.warp_mouse(prior_mouse)
		host.pointer_mode = prior_pointer
		host._sync_mouse_mode()
	var gate: Node3D = host.world.targets[gate_id].node
	var gate_radius := float(host.store.catalog.rule("gate_entry_radius_m"))
	var gate_speed := float(host.store.catalog.rule("gate_max_entry_speed_mps"))
	place(gate.global_position)
	if not check(not context(gate_id).ready and context(gate_id).reason.contains("权限"), "locked gate gives explicit permission reason"): return
	host.gameplay.grant_unlock(gate_definition.required_unlock_id)
	place(gate.global_position + Vector3.RIGHT * (gate_radius + 1))
	if not check(not context(gate_id).ready and not context(gate_id).in_range, "gate outside entry radius is rejected"): return
	place(gate.global_position + Vector3.RIGHT * gate_radius, gate_speed)
	if not check(context(gate_id).ready, "gate inclusive distance/speed boundary is usable"): return
	place(gate.global_position, gate_speed + 1)
	if not check(not context(gate_id).ready and context(gate_id).max_speed_mps == gate_speed, "gate speed uses its current SQLite qualification"): return
	place(gate.global_position)
	var cooldown := D.ShipGateCooldownStateDto.new()
	cooldown.ship_instance_id = host.state.ship().ship_instance_id
	cooldown.remaining_s = float(host.store.catalog.one("effective_connection_defs", "connection_id", gate_definition.connection_id).cooldown_s)
	host.state.add("ship_gate_cooldown_state", cooldown)
	if not check(not context(gate_id).ready and context(gate_id).cooldown_s == cooldown.remaining_s and context(gate_id).reason.contains("冷却"), "gate cooldown value and refusal reason are visible"): return
	cooldown.remaining_s = 0.0
	var budget: RefCounted = host.state.find("gate_state", "connection_id", gate_definition.connection_id)
	budget.enabled = false
	if not check(not context(gate_id).ready and context(gate_id).reason.contains("关闭"), "disabled gate is not a valid candidate"): return
	budget.enabled = true
	budget.has_remaining_mass_budget_kg = true; budget.remaining_mass_budget_kg = 0.0
	if not check(not context(gate_id).ready and context(gate_id).reason.contains("质量"), "gate mass budget is checked without mutating it"): return
	budget.has_remaining_mass_budget_kg = false
	host.gameplay.combat_remaining_s = float(host.store.catalog.rule("combat_exit_delay_s"))
	host.ui.target_id = gate_id
	host.ui.requested.emit("interact_target", gate_id, 1, "")
	if not check(not host.travel.active() and host.ui.toast.text.contains("交战"), "button cannot start gate transfer during combat"): return
	host.gameplay.combat_remaining_s = 0.0
	var credit_before: int = host.state.player().credit
	var energy_before: float = host.state.ship().energy
	host.ui.target_id = gate_id
	press_f()
	if not check(host.travel.phase == T.TravelPhase.PREPARING, "F begins actual gate charge for qualified selected endpoint"): return
	if not check(host.state.player().credit == credit_before and host.state.ship().energy == energy_before, "interaction preview and gate charge do not charge travel costs early"): return
	if not check(host.ui.interaction_button.visible and not host.ui.interaction_button.disabled and host.ui.interaction_button.text.contains("取消虫洞充能"), "actual PREPARING event immediately replaces enter button with F cancel"): return
	press_f()
	if not check(host.travel.phase == T.TravelPhase.CANCELLED, "second F cancels charging through same Main path"): return
	if not check(host.ui.interaction_button.text.contains("进入虫洞") and not host.ui.interaction_button.disabled, "cancel event immediately restores ordinary entry action"): return
	press_f()
	if not check(host.travel.phase == T.TravelPhase.PREPARING, "qualified entry can start another charge after cancellation"): return
	host.ui.interaction_button.pressed.emit()
	if not check(host.travel.phase == T.TravelPhase.CANCELLED and host.ui.interaction_button.text.contains("进入虫洞"), "mouse cancel button invokes same empty-target Main interaction as F"): return
	host.travel.phase = T.TravelPhase.DESTINATION_SAVING
	host._travel_changed(int(host.travel.phase), "提交阶段独立验证")
	if not check(host.ui.interaction_button.disabled and host.ui.interaction_button.text.contains("处理中"), "destination commit phase immediately disables cancel presentation"): return
	host.ui.interaction_button.pressed.emit()
	if not check(host.travel.phase == T.TravelPhase.DESTINATION_SAVING, "disabled phase callback cannot cancel destination commit even if signal is emitted"): return
	press_f()
	if not check(host.travel.phase == T.TravelPhase.DESTINATION_SAVING and host.ui.toast.text.contains("不能取消"), "F cannot cancel committed-endpoint work and shows refusal"): return
	host.travel.phase = T.TravelPhase.IDLE
	host._travel_changed(int(host.travel.phase), "")
	var wreck := D.ContainerStateDto.new()
	wreck.container_id = "test_interaction_wreck"
	wreck.kind = T.ContainerKind.WRECK; wreck.owner_player_id = host.state.player().player_id
	wreck.sector_id = host.state.current_sector()
	wreck.has_pos_x = true; wreck.has_pos_y = true; wreck.has_pos_z = true
	wreck.pos_x = gate.global_position.x; wreck.pos_y = gate.global_position.y; wreck.pos_z = gate.global_position.z
	host.state.add("container_state", wreck)
	host.gameplay.inventory.grant(wreck.container_id, "ore_ferrosilicate", 1)
	host.world.sync_entities()
	if not check(context(wreck.container_id).ready, "owned nonempty wreck with room is a candidate"): return
	var wreck_range := float(host.store.catalog.rule("wreck_pickup_radius_m"))
	place(gate.global_position + Vector3.RIGHT * (wreck_range + 1))
	if not check(not context(wreck.container_id).ready and context(wreck.container_id).range_m == wreck_range, "wreck range is independently governed by SQLite"): return
	place(gate.global_position + Vector3.RIGHT * wreck_range)
	if not check(context(wreck.container_id).ready, "wreck pickup boundary is inclusive"): return
	place(gate.global_position)
	if not check(Context.choose(host.world, host.state, host.store.catalog, host.gameplay, wreck.container_id).target_id == wreck.container_id, "eligible selected wreck wins over overlapping eligible gate"): return
	host.ui.requested.emit("interact_target", wreck.container_id, 1, "")
	if not check(not context(wreck.container_id).ready and context(wreck.container_id).reason.contains("为空"), "actual mouse pickup empties wreck and prevents repeated empty action"): return
	if not await wait_writer(): return
	var remote := Node3D.new()
	host.world.add_child(remote)
	remote.global_position = host.world.flight.global_position
	host.world.targets["test_planet"] = {"id": "test_planet", "title": "远景天体", "kind": "planet", "node": remote, "anchor_id": "", "navigation_only": true}
	if not check(context("test_planet").target_id.is_empty() and Context.choose(host.world, host.state, host.store.catalog, host.gameplay, "test_planet").target_id == gate_id, "navigation-only planet never becomes F interaction despite zero distance"): return
	var dead := Node3D.new()
	host.world.add_child(dead)
	host.world.targets["test_freed_target"] = {"id": "test_freed_target", "title": "已释放目标", "kind": "station", "node": dead, "anchor_id": ""}
	dead.free()
	if not check(context("test_freed_target").target_id.is_empty(), "destroyed target Variant is validated before any Node3D cast"): return
	if not check(Context.choose(host.world, host.state, host.store.catalog, host.gameplay, "test_freed_target").target_id == gate_id, "destroyed selected target safely falls back to live candidate"): return
	host.ui.target_id = gate_id
	host.busy = true
	press_f()
	if not check(not host.travel.active(), "F respects Main writer barrier without starting a new command"): return
	host.ui.requested.emit("interact_target", gate_id, 1, "")
	if not check(not host.travel.active() and host.ui.toast.text.contains("稍候"), "mouse interaction shows writer-barrier feedback without bypass"): return
	host.busy = false
	await _finish()

func _finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null
	# Test teardown: let native audio finish releasing queued voices; no game delay.
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	print("INTERACTION_V3_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
