extends SceneTree
## Fresh Main/SQLite production-path regression. Ordinary owned mining fixtures
## use catalog-authored equipment and explicit DTO progression/placement; they
## do not claim natural tutorial completion or change the frozen catalog.
const Main = preload("res://runtime/main.gd")
const ResourceStatus = preload("res://runtime/resource_status.gd")
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var database_path: String
var node_id: String = "node_echo_conductive"
var step_s: float = 0.0
var original_physics_hz: int
var original_max_fps: int

func _initialize() -> void:
	create_timer(150.0).timeout.connect(func(): print("MINING_RESOURCES_V8_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 2) -> void:
	for frame: int in range(count): await process_frame

func start_host() -> void:
	host = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	# Suppress only automatic host callbacks; actual colliders remain registered.
	host.set_process(false)
	host.set_physics_process(false)
	await frames()
	check(host.services_ready, "real Main opens a fresh isolated SQLite and validated assets")

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames()
	await create_timer(0.25).timeout

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "actual Main SQLite writer completes its requested stable capture")

func step() -> void:
	await physics_frame
	host._physics_process(step_s)
	host.camera.step(step_s)
	host.ui.tick(step_s)

func resource(id: String = "") -> D.ResourceStateDto:
	return host.state.find("resource_state", "node_id", node_id if id.is_empty() else id) as D.ResourceStateDto

func info(id: String = "") -> Dictionary:
	return ResourceStatus.inspect(host.state, host.store.catalog, node_id if id.is_empty() else id)

func context(id: String = "") -> Dictionary:
	return host.interaction_context(node_id if id.is_empty() else id)

func snapshots() -> int:
	return int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)

func mining_equipment() -> Array[D.EquipmentStateDto]:
	var result: Array[D.EquipmentStateDto] = []
	for equipment: D.EquipmentStateDto in host.gameplay.call("equipped", host.state.ship()):
		if not host.store.catalog.one("mining_defs", "module_id", equipment.module_def_id).is_empty(): result.append(equipment)
	return result

func cargo_units(item_id: String) -> int:
	var inventory: RefCounted = host.gameplay.get("inventory")
	return int(inventory.call("count", inventory.call("hold", host.state.ship(), T.ContainerKind.MINERAL), item_id, false)) + int(inventory.call("count", inventory.call("hold", host.state.ship(), T.ContainerKind.CARGO), item_id, false))

func place(point: Vector3) -> void:
	host.world.flight.global_transform = Transform3D(Basis.IDENTITY, point)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FOLLOW)
	host.camera.step(0.0)

func place_at_mine() -> void:
	var target: Node3D = host.world.targets[node_id].node
	var range_m: float = 0.0
	for equipment: D.EquipmentStateDto in mining_equipment():
		range_m = maxf(range_m, float(host.store.catalog.one("module_defs", "module_id", equipment.module_def_id).range_m))
	place(target.global_position + Vector3.UP * range_m * 0.75)
	host.ui._select_target(node_id)
	host.ui.tick(0.0)

func prepare_native_input() -> bool:
	if DisplayServer.get_name() == "headless": return true
	root.grab_focus()
	host.get_viewport().warp_mouse(Vector2(root.size) * 0.5)
	await frames(4)
	await RenderingServer.frame_post_draw
	if not root.has_focus():
		print("MINING_RESOURCES_V8_NATIVE_FOCUS_REQUIRED raise the game window within 30 seconds")
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
	host.get_viewport().warp_mouse(Vector2(root.size) * 0.5)
	await frames(4)
	return check(root.has_focus() and host._keyboard_control_allowed() and not host.ui.ui_input_blocked(), "native F test has real window focus and unobstructed OS pointer")

func press_f() -> void:
	var event := InputEventAction.new()
	event.action = "interact"; event.pressed = true
	host._unhandled_input(event)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/mining-resources-v8/native")
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "native resource information capture " + label)
	captures += 1

func _run() -> void:
	original_physics_hz = Engine.physics_ticks_per_second
	original_max_fps = Engine.max_fps
	Engine.max_fps = 144
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/mining-resources-v8-%d.db" % Time.get_ticks_usec())
	await start_host()
	if not host.services_ready: await finish(); return
	await host._command("new_world", "资源状态与有限采矿独立验收", 1, "")
	if not check(host.state != null, "create actual new world through Main and SQLite"): await finish(); return
	Engine.physics_ticks_per_second = int(host.store.catalog.rule("simulation_hz"))
	step_s = 1.0 / float(Engine.physics_ticks_per_second)
	initial_status_checks()
	if not await prepare_owned_miner(): await finish(); return
	await interaction_and_cycle_checks()
	if not host.gameplay.get("work").mining_target.is_empty(): host._command("stop_mining", "", 1, "")
	await full_hold_checks()
	await depletion_checks()
	await save_restart_countdown_checks()
	if OS.get_environment("XJ_MINING_V8_SCOPE") != "core": await resource_ui_checks()
	else: print("SKIP resource UI only in explicit mining-only scope")
	await tutorial_supply_checks()
	await ordinary_quota_checks()
	await finish()

func initial_status_checks() -> void:
	check(XJRuntimeState.TABLES.has("resource_state") and not XJRuntimeState.TABLES.has("resource_node_state"), "typed resource_state is the sole runtime resource table")
	var fields: Array[String] = ["node_id", "item_id", "item_name", "remaining_units", "capacity_units", "respawn_remaining_s", "respawn_interval_s", "depleted", "available"]
	for definition: Dictionary in host.store.catalog.rows("resource_node_defs"):
		var status: Dictionary = info(str(definition.node_id))
		var complete: bool = true
		for field: String in fields: complete = complete and status.has(field)
		check(complete and str(status.get("node_id", "")) == str(definition.node_id) and str(status.get("item_id", "")) == str(definition.item_id), "shared status identifies every actual initialized resource: " + str(definition.node_id))
		check(int(status.get("remaining_units", -1)) == int(definition.capacity_units) and int(status.get("capacity_units", -1)) == int(definition.capacity_units) and is_equal_approx(float(status.get("respawn_interval_s", -1.0)), float(definition.respawn_s)) and bool(status.get("available", false)) and not bool(status.get("depleted", true)), "fresh resource uses catalog capacity and regeneration without a false depletion: " + str(definition.node_id))
	check(not bool(info("missing-resource-v8-fixture").get("available", true)), "unknown resource ID cannot become an invented available pool")
	var original: D.ResourceStateDto = resource()
	host.state.remove("resource_state", original)
	check(not bool(info().get("available", true)), "missing typed resource row is unavailable rather than replaced with default stock")
	host.state.add("resource_state", original)
	check(info().get("available", false) and host.state.last_error.is_empty(), "restored real row is available without querying a nonexistent state table")

func prepare_owned_miner() -> bool:
	# Explicit cross-stage setup: generate a normal hull/holds using the actual
	# inventory constructor, then catalog-authored module DTOs. No mission reward,
	# paid purchase or natural tutorial completion is being claimed here.
	var ship: D.ShipStateDto = create_owned_miner("station_echo_depot")
	ship.status = T.ShipStatus.FLYING; ship.has_station_id = false; ship.station_id = ""
	host.state.player().controlled_ship_id = ship.ship_instance_id
	host.state.player().has_docked_station_id = false; host.state.player().docked_station_id = ""
	var visited := host.state.find("sector_state", "sector_id", ship.sector_id) as D.SectorStateDto
	visited.visited = true
	var location: Dictionary = host.store.catalog.one("resource_node_locations", "node_id", node_id)
	host.gameplay.call("grant_unlock", str(location.required_unlock_id))
	if not check(host._stage_candidate(host.state, host.store.catalog), "real Main staging builds the catalog-equipped owned miner in the resource sector"): return false
	host._activate(host.state)
	host.ui.show_page(""); host._sync_presentation_stage(); host._sync_mouse_mode()
	place_at_mine()
	await step()
	check(host.state.ship().ship_def_id == "miner_anvil" and host.state.ship().policy_id == "normal_owned" and mining_equipment().size() == 2 and host.world.targets.has(node_id), "fixture uses an ordinary owned dual-head miner and actual mining target, independent of loan quota")
	return await prepare_native_input()

func create_owned_miner(station_id: String) -> D.ShipStateDto:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var ship := inventory.call("create_ship", "miner_anvil", station_id) as D.ShipStateDto
	for fit: Dictionary in host.store.catalog.rows("ship_loadout_items"):
		if str(fit.loadout_id) != "loadout_miner_anvil": continue
		var slot := inventory.call("slot", ship, str(fit.slot_type), int(fit.slot_index)) as D.ContainerStateDto
		var ids: Array = inventory.call("grant", slot.container_id, str(fit.module_id), 1)
		var equipment := D.EquipmentStateDto.new()
		equipment.slot_container_id = slot.container_id; equipment.item_instance_id = str(ids[0])
		equipment.module_def_id = str(fit.module_id); equipment.enabled = true
		host.state.add("equipment_state", equipment)
	return ship

func interaction_and_cycle_checks() -> void:
	place_at_mine()
	var preview: Dictionary = context()
	check(bool(preview.ready) and str(preview.action) == "start_mining" and bool(preview.in_range) and resource().remaining_units > 0, "actual Main resource preview is ready at a stocked compatible mining node")
	var remaining: int = resource().remaining_units
	var item_id: String = str(info().item_id)
	var inventory_before: int = cargo_units(item_id)
	press_f()
	check(host.gameplay.get("work").mining_target == node_id and resource().remaining_units == remaining and cargo_units(item_id) == inventory_before, "actual F begins mining without inventing immediate inventory or consuming stock before a paid cycle")
	await step()
	check(host.gameplay.get("work").mining_cycles.size() == mining_equipment().size() and not host.gameplay.call("save_eligible"), "actual fixed tick pays independent mining head cycles and blocks unstable capture")
	var tick: int = host.state.snapshot.meta.simulation_tick
	var cycles: Dictionary = host.gameplay.get("work").mining_cycles.duplicate(true)
	host.ui.show_page("pause")
	for paused_tick: int in range(4): await step()
	check(host.state.snapshot.meta.simulation_tick == tick and host.gameplay.get("work").mining_cycles == cycles and resource().remaining_units == remaining and cargo_units(item_id) == inventory_before, "Main pause freezes paid mining periods, world time, pool and inventory")
	host.ui.show_page("")
	var captured_before: int = snapshots()
	host._request_save("manual", 0)
	check(not host.deferred_save.is_empty() and not host.busy and snapshots() == captured_before, "actual save request waits for the live mining operation without advancing its slot")
	var maximum_steps: int = 0
	var nominal_yield: int = 0
	for equipment: D.EquipmentStateDto in mining_equipment():
		var module: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment.module_def_id)
		var mining: Dictionary = host.store.catalog.one("mining_defs", "module_id", equipment.module_def_id)
		maximum_steps = maxi(maximum_steps, int(ceil(float(module.cycle_s) / step_s)) + 2)
		nominal_yield += int(floor(float(mining.base_yield_units) * float(host.store.catalog.one("ship_defs", "ship_id", host.state.ship().ship_def_id).mining_multiplier)))
	var advanced: int = 0
	while cargo_units(item_id) == inventory_before and advanced < maximum_steps:
		await step(); advanced += 1
	var gained: int = cargo_units(item_id) - inventory_before
	check(gained == nominal_yield and resource().remaining_units == remaining - gained and gained > 0, "real dual-head completion subtracts exactly its frozen catalog yield and adds the same integer units")
	check(gained < remaining and resource().respawn_remaining_s == 0.0 and bool(info().available), "partially mined normal resource remains finite and does not begin regeneration early")
	host._command("stop_mining", "", 1, "")
	await step(); await wait_writer()
	check(host.deferred_save.is_empty() and snapshots() > captured_before and host.gameplay.get("work").mining_target.is_empty(), "actual stop reaches the stable deferred-save boundary and persists the completed mining result")

func full_hold_checks() -> void:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var item_id: String = str(info().item_id)
	var existing: Dictionary = {}
	for stack: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"): existing[stack.stack_id] = stack.quantity
	var metrics: Dictionary = host.gameplay.call("metrics", host.state.ship())
	var definition: Dictionary = host.store.catalog.one("item_defs", "item_id", item_id)
	var requested: int = int(floor(float(metrics.cargo_capacity_l + metrics.mineral_capacity_l) / float(definition.unit_volume_l))) + 1
	# Fill only legal free space: every fixture unit is constrained by the actual
	# common payload limit and separate cargo/mineral volume calculation.
	for kind: T.ContainerKind in [T.ContainerKind.MINERAL, T.ContainerKind.CARGO]:
		var hold: String = inventory.call("hold", host.state.ship(), kind)
		var quantity: int = inventory.call("room", hold, item_id, requested)
		if quantity > 0: inventory.call("grant", hold, item_id, quantity)
	var count_before: int = cargo_units(item_id)
	var remaining: int = resource().remaining_units
	check(int(host.gameplay.get("work").call("_output_limit", item_id, 1).count) == 0 and not context().ready and not str(context().reason).is_empty(), "actual full receiving volume or shared payload denies mining interaction without a false depleted pool")
	host._command("start_mining", node_id, 1, "")
	var cycles: int = 0
	for equipment: D.EquipmentStateDto in mining_equipment(): cycles = maxi(cycles, int(ceil(float(host.store.catalog.one("module_defs", "module_id", equipment.module_def_id).cycle_s) / step_s)) + 2)
	for fixed_tick: int in range(cycles): await step()
	host._command("stop_mining", "", 1, "")
	check(resource().remaining_units == remaining and cargo_units(item_id) == count_before and bool(info().available), "mining into a full legal hold never subtracts ore, creates units or reports the stocked node depleted")
	for stack: D.InventoryStackStateDto in host.state.rows("inventory_stack_state").duplicate():
		if existing.has(stack.stack_id): stack.quantity = int(existing[stack.stack_id])
		else: host.state.remove("inventory_stack_state", stack)
	check(context().ready and int(host.gameplay.get("work").call("_output_limit", item_id, 1).count) == 1, "restoring the test cargo capacity restores the same stocked node's real interaction")

func depletion_checks() -> void:
	var heads: Array[D.EquipmentStateDto] = mining_equipment()
	# Artificial near-exhaustion DTO fixture, within its true frozen capacity.
	# Actual Main mining—not this setup—must consume the final integer units.
	resource().remaining_units = 1; resource().respawn_remaining_s = 0.0
	var last_units: int = resource().remaining_units
	var item_id: String = str(info().item_id)
	var before: int = cargo_units(item_id)
	host.ui.requested.emit("interact_target", node_id, 1, "")
	check(host.gameplay.get("work").mining_target == node_id and context().ready, "actual selected-target interaction accepts a genuine nonzero near-empty resource")
	var limit: int = int(ceil(float(host.store.catalog.one("module_defs", "module_id", heads[0].module_def_id).cycle_s) / step_s)) + 3
	var advanced: int = 0
	while resource().remaining_units > 0 and advanced < limit: await step(); advanced += 1
	var definition: Dictionary = host.store.catalog.one("resource_node_defs", "node_id", node_id)
	check(resource().remaining_units == 0 and cargo_units(item_id) - before == last_units and host.gameplay.get("work").mining_target.is_empty(), "real final mining cycle grants only the remaining units and stops both heads exactly at depletion")
	var cycles_cleared: bool = true
	for equipment: D.EquipmentStateDto in mining_equipment():
		cycles_cleared = cycles_cleared and equipment.active_remaining_s == 0.0 and not equipment.cycle_paid
	check(cycles_cleared and host.gameplay.call("save_eligible"), "last-unit depletion clears all mining paid periods immediately without an extra cleanup tick")
	var snapshots_before: int = snapshots()
	host._request_save("manual", 3); await wait_writer()
	var sealed: Array[Dictionary] = host.store._records("SELECT r.remaining_units,r.respawn_remaining_s FROM save_slot s JOIN resource_state r ON r.snapshot_id=s.current_snapshot_id WHERE s.world_id=? AND s.slot_kind='manual' AND s.slot_index=3 AND r.node_id=?", [host.state.world_id, node_id])
	check(host.deferred_save.is_empty() and snapshots() > snapshots_before and sealed.size() == 1 and int(sealed[0].remaining_units) == 0 and is_equal_approx(float(sealed[0].respawn_remaining_s), resource().respawn_remaining_s), "actual SQLite immediately seals the last-unit mining result without waiting for natural cycle cleanup")
	check(absf(resource().respawn_remaining_s - (float(definition.respawn_s) - step_s)) < step_s * 0.01 and bool(info().available) and bool(info().depleted), "real depletion remains known and starts the catalog regeneration interval, including that fixed tick's elapsed world time")
	check(not context().ready and str(context().reason).contains("耗尽"), "actual depleted resource gives an explicit interaction refusal")
	var result := host.gameplay.call("act", "start_mining", node_id) as D.ActionResultDto
	check(result.phase == T.ActionPhase.REJECTED and host.gameplay.get("work").mining_target.is_empty() and resource().remaining_units == 0, "business start_mining independently rejects exhausted stock without relying on its UI preview")
	host._command("start_mining", node_id, 1, "")
	check(host.gameplay.get("work").mining_target.is_empty() and not str(host.gameplay.get("last_error")).is_empty(), "actual Main mining command cannot bypass the depleted business state")

func save_restart_countdown_checks() -> void:
	var timer: float = resource().respawn_remaining_s
	var tick: int = host.state.snapshot.meta.simulation_tick
	var item_id: String = str(info().item_id)
	var units: int = cargo_units(item_id)
	host.ui.show_page("pause")
	for paused_tick: int in range(4): await step()
	check(resource().remaining_units == 0 and is_equal_approx(resource().respawn_remaining_s, timer) and host.state.snapshot.meta.simulation_tick == tick, "actual Main pause freezes exhausted-resource regeneration and simulation tick")
	host._request_save("manual", 1)
	await wait_writer()
	var sql: Array[Dictionary] = host.store._records("SELECT r.remaining_units,r.respawn_remaining_s FROM save_slot s JOIN resource_state r ON r.snapshot_id=s.current_snapshot_id WHERE s.world_id=? AND s.slot_kind='manual' AND s.slot_index=1 AND r.node_id=?", [host.state.world_id, node_id])
	check(sql.size() == 1 and int(sql[0].remaining_units) == 0 and is_equal_approx(float(sql[0].respawn_remaining_s), timer), "sealed SQLite stores the depleted amount and actual outstanding regeneration delay")
	await release_host(); await start_host()
	await host._command("continue", "", 1, ""); await wait_writer()
	host.ui.show_page(""); host._sync_presentation_stage(); host.ui._select_target(node_id)
	check(resource().remaining_units == 0 and is_equal_approx(resource().respawn_remaining_s, timer) and host.state.snapshot.meta.simulation_tick == tick and cargo_units(item_id) == units, "actual SQLite restart preserves ore, cargo and world countdown without offline regeneration")
	check(bool(info().available) and bool(info().depleted) and is_equal_approx(float(info().respawn_remaining_s), timer) and not context().ready, "restored shared status remains known and Main interaction agrees that the pool is still exhausted")
	# Explicit near-respawn DTO precondition avoids pretending to wait 1200 real
	# seconds; all four following reductions/respawn are actual Main fixed ticks.
	resource().respawn_remaining_s = step_s * 3.25
	await step()
	check(resource().remaining_units == 0 and absf(resource().respawn_remaining_s - step_s * 2.25) < step_s * 0.001, "actual next world tick reduces the pending resource timer by exactly the SQLite simulation step")
	timer = resource().respawn_remaining_s; tick = host.state.snapshot.meta.simulation_tick
	host.ui.show_page("pause")
	for paused_tick: int in range(3): await step()
	check(is_equal_approx(resource().respawn_remaining_s, timer) and host.state.snapshot.meta.simulation_tick == tick, "pause near regeneration cannot cross the replenishment boundary")
	host.ui.show_page("")
	await step(); await step()
	check(resource().remaining_units == 0 and resource().respawn_remaining_s > 0.0, "fractional positive regeneration time does not replenish early")
	await step()
	var capacity: int = int(host.store.catalog.one("resource_node_defs", "node_id", node_id).capacity_units)
	check(resource().remaining_units == capacity and resource().respawn_remaining_s == 0.0 and bool(info().available) and not bool(info().depleted) and context().ready, "actual elapsed regeneration refills exactly catalog capacity and restores mining interaction")

func resource_ui_checks() -> void:
	var overview: XJOverviewPanel = host.ui.overview
	var pool: D.ResourceStateDto = resource()
	var original_units: int = pool.remaining_units
	var original_timer: float = pool.respawn_remaining_s
	var sensor: float = float(host.store.catalog.rule("target_marker_detection_range_m"))
	var target: Node3D = host.world.targets[node_id].node
	place(target.global_position + Vector3(0, sensor * 0.5, sensor * 2.0))
	overview.filter_mode = "all"
	host.ui._select_target(node_id); host.ui.tick(1.0)
	check(host.world.flight.global_position.distance_to(target.global_position) > sensor and overview.target_buttons.has(node_id), "same-sector catalog resource remains in actual overview beyond enemy sensor range")
	var row: Dictionary = {}
	for candidate: Dictionary in overview.entry_rows:
		if str(candidate.id) == node_id: row = candidate
	check(not row.is_empty() and row.get("resource_info", {}) == info() and str(row.get("resource_summary", "")) == ResourceStatus.summary(info()), "actual overview row shares the authoritative typed resource information and formatter")
	var button: Button = overview.target_buttons[node_id]
	var readout: Label = button.get_node("ResourceState")
	check(readout.is_visible_in_tree() and readout.text == ResourceStatus.summary(info()) and button.tooltip_text.contains(readout.text), "actual resource row and full tooltip show the real remaining pool rather than only its mineral type")
	for window_size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = window_size; root.content_scale_size = Vector2i(Vector2(window_size) / scale)
			await frames(4)
			# Presentation-only DTO input, below the true frozen capacity. No save
			# or mining operation is performed while these visual inputs are active.
			pool.remaining_units = int(float(info().capacity_units) * 0.37); pool.respawn_remaining_s = 0.0
			host.ui.show_page(""); host.ui._select_target(node_id); host.ui.tick(1.0)
			await frames(4)
			var viewport := Rect2(Vector2.ZERO, host.ui.root.size)
			button = overview.target_buttons[node_id]; readout = button.get_node("ResourceState")
			check(overview.resource_detail.is_visible_in_tree() and overview.resource_label.text == ResourceStatus.summary(info()) and absf(overview.resource_bar.value - float(pool.remaining_units) / float(info().capacity_units) * 100.0) < 0.001, "selected resource card displays the exact state and derived percentage %s at %.0f%%" % [window_size, scale * 100])
			check(wrapped_glyphs_fit(overview.resource_label, overview.selection_card), "resource summary has unclipped visible glyph height inside the actual selected card %s at %.0f%%" % [window_size, scale * 100])
			check(not overview.interaction_label.text.is_empty() and wrapped_glyphs_fit(overview.interaction_label, overview.selection_card), "distant resource interaction reason has actual visible glyph height inside its card %s at %.0f%%" % [window_size, scale * 100])
			check(viewport.encloses(overview.get_global_rect()) and button.get_global_rect().encloses(readout.get_global_rect()) and not readout.get_global_rect().intersects(button.get_child(0).get_node("Name").get_global_rect()), "resource panel and two-part mineral row have valid non-overlapping bounds %s at %.0f%%" % [window_size, scale * 100])
			pool.remaining_units = 0; pool.respawn_remaining_s = float(info().respawn_interval_s) * 0.5
			host.ui.tick(1.0); await frames(3)
			check(overview.resource_label.text == ResourceStatus.summary(info()) and overview.resource_label.text.contains("耗尽") and overview.resource_label.text.contains("世界时间") and overview.resource_bar.value == 0.0 and overview.target_buttons[node_id].tooltip_text.contains(ResourceStatus.summary(info())), "depleted resource is clearly distinguished and includes its live countdown %s at %.0f%%" % [window_size, scale * 100])
			await capture("overview-%dx%d-%d" % [window_size.x, window_size.y, int(scale * 100)])
			host.ui.show_page("map"); host.ui.tick(1.0); await frames(4)
			var chart: Control = host.ui.resource_chart
			var map_label: Label = map_readout(node_id)
			var chart_label: Label = chart.get("resource_information")
			check(is_instance_valid(map_label) and map_label.text.contains(ResourceStatus.summary(info())) and chart_label.text.contains(ResourceStatus.summary(info())) and chart_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "actual star chart and sector resource card share the exhausted pool and countdown %s at %.0f%%" % [window_size, scale * 100])
			var label_instance: int = map_label.get_instance_id()
			pool.respawn_remaining_s -= 1.0
			host.ui.tick(1.0); await frames(3)
			check(map_readout(node_id).get_instance_id() == label_instance and map_label.text.contains(ResourceStatus.summary(info())) and chart_label.text.contains(ResourceStatus.summary(info())), "map refresh updates existing labels from changed world state without rebuilding the page %s at %.0f%%" % [window_size, scale * 100])
			host.ui.page_scroll.ensure_control_visible(chart_label)
			await frames(4)
			await capture("map-%dx%d-%d" % [window_size.x, window_size.y, int(scale * 100)])
	var foreign_id: String = ""
	var foreign_sector: String = ""
	for definition: Dictionary in host.store.catalog.rows("resource_node_defs"):
		var visit := host.state.find("sector_state", "sector_id", str(definition.sector_id)) as D.SectorStateDto
		if str(definition.sector_id) != host.state.current_sector() and visit != null and not visit.visited:
			foreign_id = str(definition.node_id); foreign_sector = str(definition.sector_id); break
	check(not foreign_id.is_empty(), "fresh fixture retains an unvisited external resource sector for intelligence boundaries")
	if not foreign_id.is_empty():
		var chart: Control = host.ui.resource_chart
		chart.call("select_sector", foreign_sector); host.ui.tick(1.0)
		var label: Label = map_readout(foreign_id)
		var chart_label: Label = chart.get("resource_information")
		check(label.text.contains("实时矿量未知") and chart_label.text.contains("实时矿量未知") and not label.text.contains(ResourceStatus.summary(info(foreign_id))) and not chart_label.text.contains(ResourceStatus.summary(info(foreign_id))), "unvisited map sector exposes known output types but does not leak exact live stock")
		var visited := host.state.find("sector_state", "sector_id", foreign_sector) as D.SectorStateDto
		visited.visited = true
		host.ui.tick(1.0)
		check(label.text.contains(ResourceStatus.summary(info(foreign_id))) and chart_label.text.contains(ResourceStatus.summary(info(foreign_id))), "explicit visited-state fixture allows the real persisted mineral intelligence")
		visited.visited = false
	pool.remaining_units = original_units; pool.respawn_remaining_s = original_timer
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	host.ui.show_page(""); host.ui._select_target(node_id); host.ui.tick(1.0)
	await frames(3)

func map_readout(id: String) -> Label:
	for readout: Dictionary in host.ui.map_resource_readouts:
		if str(readout.node_id) == id: return readout.label as Label
	return null

func wrapped_glyphs_fit(label: Label, parent: Control) -> bool:
	var line_height: float = label.get_theme_font("font").get_height(label.get_theme_font_size("font_size"))
	var visible_lines: int = label.get_line_count()
	if label.max_lines_visible > 0: visible_lines = mini(visible_lines, label.max_lines_visible)
	var glyph_rect := Rect2(label.get_global_rect().position, Vector2(label.size.x, line_height * maxi(1, visible_lines)))
	return label.is_visible_in_tree() and not label.clip_text and label.size.y + 0.01 >= glyph_rect.size.y and parent.get_global_rect().encloses(glyph_rect) and Rect2(Vector2.ZERO, host.ui.root.size).encloses(glyph_rect)

func relocate_sector_fixture(sector_id: String) -> bool:
	# Artificial travel precondition only. Rebuild through Main's actual staging
	# and activation; this is not a claim that the wormhole animation was played.
	var ship: D.ShipStateDto = host.state.ship()
	ship.sector_id = sector_id; ship.status = T.ShipStatus.FLYING
	ship.has_station_id = false; ship.station_id = ""
	ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	host.state.player().has_docked_station_id = false; host.state.player().docked_station_id = ""
	for container: D.ContainerStateDto in host.state.rows("container_state"):
		if container.ship_instance_id == ship.ship_instance_id: container.sector_id = sector_id
	var visited := host.state.find("sector_state", "sector_id", sector_id) as D.SectorStateDto
	visited.visited = true
	if not check(host._stage_candidate(host.state, host.store.catalog), "actual Main prepares explicit mining fixture sector " + sector_id): return false
	host._activate(host.state)
	host.ui.show_page(""); host._sync_presentation_stage(); host._sync_mouse_mode()
	return true

func bound_samples(mission_id: String, item_id: String) -> int:
	var total: int = 0
	for stack: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"):
		if stack.policy_id == "mission_bound" and stack.bound_mission_instance_id == mission_id and stack.item_def_id == item_id:
			total += stack.quantity
	return total

func nominal_cycle_yield() -> int:
	var total: int = 0
	var multiplier: float = float(host.store.catalog.one("ship_defs", "ship_id", host.state.ship().ship_def_id).mining_multiplier)
	for equipment: D.EquipmentStateDto in mining_equipment():
		total += int(floor(float(host.store.catalog.one("mining_defs", "module_id", equipment.module_def_id).base_yield_units) * multiplier))
	return total

func tutorial_supply_checks() -> void:
	await release_host()
	database_path = database_path.trim_suffix(".db") + "-tutorial.db"
	node_id = "node_echo_ferrosilicate"
	await start_host()
	if not host.services_ready: return
	await host._command("new_world", "教学有限样本保护独立验收", 1, "")
	if not check(host.state != null, "fresh second SQLite world isolates tutorial protection from ordinary mining"): return
	var definition: Dictionary = host.store.catalog.one("resource_node_defs", "node_id", node_id)
	resource().remaining_units = 0; resource().respawn_remaining_s = float(definition.respawn_s)
	host.gameplay.get("work").call("ensure_tutorial_supplies")
	check(resource().remaining_units == 0 and is_equal_approx(resource().respawn_remaining_s, float(definition.respawn_s)), "unaccepted tutorial does not refill an exhausted shared pool")
	# Legal T0/T1 prerequisite DTO input: accept real missions, set only their
	# bounded non-collect objective progress, then use actual atomic turn-ins for
	# one-time completion, receipts, unlocks and rewards. No natural flight/scan
	# traversal is claimed by this prerequisite setup.
	for prerequisite: String in ["tutorial_flight", "tutorial_scan_gate"]:
		host._command("accept_mission", prerequisite, 1, ""); await wait_writer()
		var prerequisite_mission := host.gameplay.get("missions").call("resolve", prerequisite) as D.MissionStateDto
		if not check(prerequisite_mission != null, "actual mission acceptance creates prerequisite " + prerequisite): return
		for objective: Dictionary in host.store.catalog.rows("mission_objective_defs"):
			if str(objective.mission_id) != prerequisite: continue
			var progress := host.gameplay.get("missions").call("progress", prerequisite_mission, int(objective.objective_index)) as D.MissionObjectiveStateDto
			progress.progress_units = int(objective.required_count)
		host.gameplay.get("missions").call("refresh")
		host._command("deliver_mission", prerequisite, 1, ""); await wait_writer()
		check(prerequisite_mission.reward_claimed and prerequisite_mission.status == "completed", "actual atomic turn-in seals the artificial prerequisite exactly once: " + prerequisite)
	var delivery: Dictionary = {}
	for objective: Dictionary in host.store.catalog.rows("mission_objective_defs"):
		if str(objective.mission_id) == "tutorial_mining_delivery" and str(objective.objective_kind) == "deliver": delivery = objective; break
	if not check(not delivery.is_empty(), "tutorial protection derives finite required samples from the frozen delivery objective"): return
	var required: int = int(delivery.required_count)
	var item_id: String = str(delivery.target_item_id)
	host._command("accept_mission", "tutorial_mining_delivery", 1, ""); await wait_writer()
	var first := host.gameplay.get("missions").call("active") as D.MissionStateDto
	check(first != null and first.mission_def_id == "tutorial_mining_delivery" and resource().remaining_units == required and resource().remaining_units < int(definition.capacity_units) and resource().respawn_remaining_s == 0.0, "real T2 acceptance supplies only its missing finite samples from an exhausted pool, not a full mineral field")
	check(int(ResourceStatus.tutorial_reservation(host.state, host.store.catalog, node_id).get("outstanding_units", 0)) == required and int(info().reserved_units) == required, "shared status exposes the actual finite tutorial reservation")
	var first_attempt: String = first.mission_instance_id
	host._command("abandon_mission", first_attempt, 1, ""); await wait_writer()
	check(first.status == "abandoned" and resource().remaining_units == required and int(ResourceStatus.tutorial_reservation(host.state, host.store.catalog, node_id).get("outstanding_units", 0)) == required, "real abandonment retains finite protection without turning reserved samples into a public commodity")
	var owned: D.ShipStateDto = create_owned_miner("station_anchor_port")
	host._command("switch_ship", owned.ship_instance_id, 1, ""); await wait_writer()
	if not await relocate_sector_fixture("sector_echo"): return
	place_at_mine(); await step()
	var units_before: int = cargo_units(item_id)
	var result := host.gameplay.call("act", "start_mining", node_id) as D.ActionResultDto
	check(result.phase == T.ActionPhase.REJECTED and not context().ready and host.gameplay.get("work").mining_target.is_empty() and resource().remaining_units == required and cargo_units(item_id) == units_before, "ordinary owned miner cannot extract an abandoned tutorial's reserved units as tradable ore")
	if not await relocate_sector_fixture("sector_anchor"): return
	place((host.world.targets["station_anchor_port"].node as Node3D).global_position)
	host._command("dock", "station_anchor_port", 1, ""); await wait_writer()
	host._command("accept_mission", "tutorial_mining_delivery", 1, ""); await wait_writer()
	var mission := host.gameplay.get("missions").call("active") as D.MissionStateDto
	check(mission != null and mission.mission_instance_id != first_attempt and resource().remaining_units == required and int(info().reserved_units) == required, "actual tutorial reacceptance retains the finite pool and creates a distinct legitimate attempt")
	host._command("claim_loan", "loan_tutorial_miner", 1, ""); await wait_writer()
	var loan := host.gameplay.get("work").call("_active_loan") as D.LoanStateDto
	if not check(loan != null and loan.mission_instance_id == mission.mission_instance_id and loan.quota_remaining_units == required, "actual tutorial loan issues only the frozen operation quota to its active attempt"): return
	if not await relocate_sector_fixture("sector_echo"): return
	host.gameplay.call("record_event", "transit_connection", "conn_anchor_echo", 1)
	var wrong_id: String = "node_echo_conductive"
	var wrong_units: int = resource(wrong_id).remaining_units
	var quota: int = loan.quota_remaining_units
	var wrong := host.gameplay.call("act", "start_mining", wrong_id) as D.ActionResultDto
	check(wrong.phase == T.ActionPhase.REJECTED and resource(wrong_id).remaining_units == wrong_units and loan.quota_remaining_units == quota and host.gameplay.get("work").mining_target.is_empty(), "bound tutorial loan rejects the wrong compatible mineral node without consuming its stock or quota")
	place_at_mine()
	host.ui.requested.emit("interact_target", node_id, 1, "")
	if not check(host.gameplay.get("work").mining_target == node_id and context().ready, "real Main accepts actual tutorial loan mining at its stocked reserved target"): return
	var cycle_steps: int = int(ceil(float(host.store.catalog.one("module_defs", "module_id", mining_equipment()[0].module_def_id).cycle_s) / step_s)) + 3
	var advanced: int = 0
	while bound_samples(mission.mission_instance_id, item_id) == 0 and advanced < cycle_steps: await step(); advanced += 1
	host._command("stop_mining", "", 1, "")
	var held: int = bound_samples(mission.mission_instance_id, item_id)
	check(held == nominal_cycle_yield() and held > 0 and held < required and resource().remaining_units == required - held and loan.quota_remaining_units == required - held, "real tutorial cycles subtract the same finite pool and quota and create only bounded mission samples")
	var origins_valid: bool = true
	var transfer_stack: D.InventoryStackStateDto
	for sample: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"):
		if sample.policy_id != "mission_bound" or sample.bound_mission_instance_id != mission.mission_instance_id or sample.item_def_id != item_id: continue
		origins_valid = origins_valid and sample.origin_kind == T.StackOrigin.MISSION_BOUND and sample.has_bound_mission_instance_id and not sample.has_loan_id and sample.loan_id.is_empty()
		transfer_stack = sample
	check(origins_valid and transfer_stack != null, "actual tutorial sample stacks use the exclusive mission-bound database origin without an incompatible loan binding")
	if transfer_stack == null: return
	var return_history: int = mission.collected_units
	if not await relocate_sector_fixture("sector_anchor"): return
	place((host.world.targets["station_anchor_port"].node as Node3D).global_position)
	host._command("dock", "station_anchor_port", 1, ""); await wait_writer()
	var warehouse: String = host.gameplay.get("inventory").call("warehouse", "station_anchor_port")
	var transfer_units: int = transfer_stack.quantity
	host._command("move_stack", transfer_stack.stack_id, transfer_units, warehouse); await wait_writer()
	check(int(host.gameplay.get("inventory").call("count", warehouse, item_id, false, mission.mission_instance_id)) == transfer_units and bound_samples(mission.mission_instance_id, item_id) == held, "actual docked transfer moves existing bound samples to the station without converting their policy or quantity")
	host._command("handoff_loan", loan.loan_id, 1, ""); await wait_writer()
	check(loan.status == T.LoanStatus.RETURNED and bound_samples(mission.mission_instance_id, item_id) == 0 and int(host.gameplay.get("inventory").call("count", warehouse, item_id, false, mission.mission_instance_id)) == 0 and mission.collected_units == return_history, "actual loan return cleans mission-bound samples in both warehouse and former ship while retaining historical collection")
	host._command("claim_loan", "loan_tutorial_miner", 1, ""); await wait_writer()
	loan = host.gameplay.get("work").call("_active_loan") as D.LoanStateDto
	if not check(loan != null and loan.quota_remaining_units == required and resource().remaining_units == required and int(info().reserved_units) == required, "actual reloan supplies the missing finite physical samples and bounded quota after cleanup"): return
	if not await relocate_sector_fixture("sector_echo"): return
	place_at_mine(); host.ui.requested.emit("interact_target", node_id, 1, "")
	advanced = 0
	while bound_samples(mission.mission_instance_id, item_id) == 0 and advanced < cycle_steps: await step(); advanced += 1
	host._command("stop_mining", "", 1, "")
	held = bound_samples(mission.mission_instance_id, item_id)
	if not check(held == nominal_cycle_yield() and held > 0 and resource().remaining_units == required - held and loan.quota_remaining_units == required - held, "real reissued loan can mine its missing samples while continuing the same task proof"): return
	var historical: int = mission.collected_units
	var lost: int = maxi(1, int(floor(float(held) * 0.5)))
	var left_to_remove: int = lost
	# Explicit sample-loss DTO input, preserving original collect proofs. This is
	# a loss/recovery fixture, not a claim to have flown a ship-destruction sequence.
	for stack: D.InventoryStackStateDto in host.state.rows("inventory_stack_state").duplicate():
		if stack.policy_id != "mission_bound" or stack.bound_mission_instance_id != mission.mission_instance_id or stack.item_def_id != item_id: continue
		var removed: int = mini(stack.quantity, left_to_remove)
		stack.quantity -= removed; left_to_remove -= removed
		if stack.quantity == 0: host.state.remove("inventory_stack_state", stack)
		if left_to_remove == 0: break
	var expected_held: int = held - lost
	var outstanding: int = required - expected_held
	var mission_id: String = mission.mission_instance_id
	var loan_id: String = loan.loan_id
	host._request_save("manual", 2); await wait_writer()
	check(bound_samples(mission_id, item_id) == expected_held and mission.collected_units == historical and not mission.reward_claimed, "real saved loss fixture keeps historical collection distinct from missing physical samples")
	await release_host(); await start_host()
	await host._command("continue", "", 1, ""); await wait_writer()
	mission = host.state.find("mission_state", "mission_instance_id", mission_id) as D.MissionStateDto
	loan = host.state.find("loan_state", "loan_id", loan_id) as D.LoanStateDto
	check(mission != null and loan != null and mission.collected_units == historical and bound_samples(mission_id, item_id) == expected_held and resource().remaining_units == outstanding and loan.quota_remaining_units == outstanding and resource().respawn_remaining_s == 0.0, "actual SQLite restart recovers only lost tutorial sample shortfall and bounded quota in the same attempt")
	place_at_mine()
	host.ui.requested.emit("interact_target", node_id, 1, "")
	advanced = 0
	var maximum: int = int(ceil(float(outstanding) / float(nominal_cycle_yield()))) * cycle_steps + 3
	while bound_samples(mission_id, item_id) < required and advanced < maximum: await step(); advanced += 1
	host._command("stop_mining", "", 1, "")
	var proofs: int = 0
	for proof: D.MissionCollectEventStateDto in host.state.rows("mission_collect_event_state"):
		if proof.mission_instance_id == mission_id: proofs += proof.quantity
	var inventory: RefCounted = host.gameplay.get("inventory")
	var mineral: String = inventory.call("hold", host.state.ship(), T.ContainerKind.MINERAL)
	check(bound_samples(mission_id, item_id) == required and mission.collected_units == required and proofs == required and loan.quota_remaining_units == 0 and int(inventory.call("count", mineral, item_id, true)) == 0, "real recovery mining ends at exact bound delivery units without duplicating historical proof or creating tradable ore")
	var samples_before: int = bound_samples(mission_id, item_id)
	host._command("start_mining", node_id, 1, "")
	check(host.gameplay.get("work").mining_target.is_empty() and bound_samples(mission_id, item_id) == samples_before and loan.quota_remaining_units == 0, "fulfilled sample quota cannot be mined again for additional tutorial assets")
	await capture("tutorial-bound-samples")
	if not await relocate_sector_fixture("sector_anchor"): return
	place((host.world.targets["station_anchor_port"].node as Node3D).global_position)
	host._command("dock", "station_anchor_port", 1, ""); await wait_writer()
	check(host.state.ship().status == T.ShipStatus.DOCKED and mission.status == "ready", "actual Main docking satisfies the tutorial's return objective before delivery")
	var credit: int = host.state.player().credit
	var reward: int = int(host.store.catalog.one("mission_reward_defs", "mission_id", mission.mission_def_id).reward_credit)
	host._command("deliver_mission", mission_id, 1, ""); await wait_writer()
	check(mission.reward_claimed and mission.status == "completed" and host.state.player().credit == credit + reward and loan.status == T.LoanStatus.RETURNED and bound_samples(mission_id, item_id) == 0 and ResourceStatus.tutorial_reservation(host.state, host.store.catalog, node_id).is_empty(), "actual atomic delivery consumes finite samples, returns the loan, rewards once and releases tutorial protection")
	credit = host.state.player().credit
	host._command("deliver_mission", mission_id, 1, "")
	var claims: int = 0
	for claim: D.MissionClaimStateDto in host.state.rows("mission_claim_state"):
		if claim.mission_instance_id == mission_id: claims += 1
	check(host.state.player().credit == credit and claims == 1 and int(info().reserved_units) == 0, "repeated completed tutorial delivery cannot duplicate payout or recreate a reserve")

func ordinary_quota_checks() -> void:
	var definition: Dictionary = host.store.catalog.one("mission_defs", "mission_id", "contract_mining_iron")
	var service: Dictionary = {}
	for candidate: Dictionary in host.store.catalog.rows("loan_service_defs"):
		if str(candidate.required_mission_id) == str(definition.mission_id): service = candidate; break
	if service.is_empty(): check(false, "ordinary contract fixture resolves the actual loan service"); return
	if host.state.ship().status != T.ShipStatus.DOCKED or host.state.ship().station_id != str(definition.accept_station_id):
		var station: Dictionary = host.store.catalog.one("station_defs", "station_id", str(definition.accept_station_id))
		if not await relocate_sector_fixture(str(station.sector_id)): return
		place((host.world.targets[str(definition.accept_station_id)].node as Node3D).global_position)
		host._command("dock", str(definition.accept_station_id), 1, ""); await wait_writer()
	host._command("accept_mission", str(definition.mission_id), 1, ""); await wait_writer()
	host._command("claim_loan", str(service.loan_service_id), 1, ""); await wait_writer()
	var mission := host.gameplay.get("missions").call("active") as D.MissionStateDto
	var loan := host.gameplay.get("work").call("_active_loan") as D.LoanStateDto
	if not check(mission != null and loan != null and mission.mission_def_id == str(definition.mission_id) and loan.mission_instance_id == mission.mission_instance_id and loan.quota_remaining_units == int(service.operation_quota_units), "actual ordinary contract acceptance and loan start with the catalog's attempt quota"): return
	var loan_id: String = loan.loan_id
	var issuance: int = loan.issuance_count
	# Explicit legal exhausted-quota DTO fixture. No 600-unit mining traversal,
	# synthetic mining receipt or collection ledger is claimed by this setup.
	loan.quota_remaining_units = 0
	host._command("handoff_loan", loan_id, 1, ""); await wait_writer()
	host._command("claim_loan", str(service.loan_service_id), 1, ""); await wait_writer()
	var reissued := host.gameplay.get("work").call("_active_loan") as D.LoanStateDto
	var issues: int = 0
	for issue: D.LoanIssueStateDto in host.state.rows("loan_issue_state"):
		if issue.loan_id == loan_id: issues += 1
	check(reissued != null and reissued.loan_id == loan_id and reissued.mission_instance_id == mission.mission_instance_id and reissued.quota_remaining_units == 0 and reissued.issuance_count == issuance + 1 and issues == reissued.issuance_count, "actual ordinary return and reloan retain the exhausted attempt quota and append issuance history to the same loan")
	var count_before: int = snapshots()
	host._request_save("manual", 4); await wait_writer()
	var rows: Array[Dictionary] = host.store._records("SELECT l.loan_id,l.quota_remaining_units,l.issuance_count FROM save_slot s JOIN loan_state l ON l.snapshot_id=s.current_snapshot_id WHERE s.world_id=? AND s.slot_kind='manual' AND s.slot_index=4 AND l.mission_instance_id=? AND l.loan_service_id=?", [host.state.world_id, mission.mission_instance_id, str(service.loan_service_id)])
	check(host.deferred_save.is_empty() and snapshots() > count_before and rows.size() == 1 and str(rows[0].loan_id) == loan_id and int(rows[0].quota_remaining_units) == 0 and int(rows[0].issuance_count) == issuance + 1, "actual SQLite seals exactly one same-attempt ordinary loan with unchanged exhausted quota after reissue")

func finish() -> void:
	for action: StringName in InputMap.get_actions(): Input.action_release(action)
	await release_host()
	Engine.physics_ticks_per_second = original_physics_hz
	Engine.max_fps = original_max_fps
	print("MINING_RESOURCES_V8_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
