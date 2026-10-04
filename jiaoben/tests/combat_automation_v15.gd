extends Node
## Real Main/SQLite/physics/Viewport. Positions, hull purchase substitutes, unlocks
## and explicit damage endpoints are test preconditions, not natural campaign play.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var directory: String
var database_path: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var rendered_flight_captures: int = 0
var combinations: int = 0
var large_hull_ticks: int = 0
var global_z_cases: int = 0
var step_s: float
var original_hz: int
var original_fps: int
var weapon_ids: Array[String] = []
var enemies: Array[String] = []
var home: Vector3
var shot_events: Array[Dictionary] = []
var requested: Array[Dictionary] = []
var root: Window:
	get: return get_tree().root

func _ready() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	check(not host.busy, "real writer completes")

func sync() -> void:
	check(host.world.sync_entities(), "actual world synchronizes current authoritative records")
	host._sync_presentation_stage()
	host.camera.step(0.0); host.ui.tick(1.0)
	await frames()
	flight_render_check("synchronized flight")

func step(count: int = 1) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
		host._physics_process(step_s)
		# Presentation normally drains the real event list; root's render callback
		# is frozen for deterministic sampling, so capture then consume exactly once.
		for event: D.EventDto in host.gameplay.get("events"):
			if event.kind == T.EventKind.WEAPON_FIRED:
				shot_events.append({"item_id": event.module_instance_id, "tick": event.simulation_tick})
		if host.presentation != null: host.presentation.consume(step_s)
		host._sync_presentation_stage()
		host.camera.step(step_s); host.ui.tick(step_s)

func flight_render_check(label: String) -> void:
	if host.state == null or host.state.ship().status != T.ShipStatus.FLYING: return
	check(host.presentation_stage == "flight" and host.world.is_visible_in_tree() and not host.hangar.is_visible_in_tree() and host.camera.camera.current and host.get_viewport().get_camera_3d() == host.camera.camera, "production stage renders the flight world with its current camera " + label)
	if host.camera.mode != T.CameraMode.FRONT:
		check(is_instance_valid(host.world.flight.visual) and host.world.flight.visual.is_visible_in_tree() and visible_ship_mesh_count(host.world.flight.visual) > 0, "production non-front flight presents the actual ship model " + label)

func visible_ship_mesh_count(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).is_visible_in_tree() else 0
	for child: Node in node.get_children(): count += visible_ship_mesh_count(child)
	return count

func shot_count(id: String = "") -> int:
	var count: int = 0
	for event: Dictionary in shot_events:
		if id.is_empty() or str(event.item_id) == id: count += 1
	return count

func command(action: String, target: String = "", quantity: int = 1, extra: String = "") -> void:
	host._command(action, target, quantity, extra)
	await frames(); await wait_writer()

func combat_hotkey() -> void:
	# Dispatch paired real action events through Viewport/Main input routing.
	# No direct option assignment or command shortcut replaces the global Z path.
	for down: bool in [true, false]:
		var event := InputEventAction.new(); event.action = "combat_toggle"; event.pressed = down
		host.get_viewport().push_input(event, true)
		await frames(1)

func set_options(fire: bool, orbit: bool, seek: bool) -> void:
	for key: String in ["fire", "orbit", "seek"]:
		var value: bool = fire if key == "fire" else orbit if key == "orbit" else seek
		host._command("set_combat_option", key, 1, "on" if value else "off")
	await frames(); host.ui.tick(1.0)

func options() -> Dictionary:
	return host.combat_automation.options

func target_id() -> String:
	return host.combat_automation.target_id

func equipment(id: String) -> D.EquipmentStateDto:
	return host.state.find("equipment_state", "item_instance_id", id) as D.EquipmentStateDto

func item(id: String) -> D.ItemInstanceStateDto:
	return host.state.find("item_instance_state", "item_instance_id", id) as D.ItemInstanceStateDto

func npc(id: String) -> D.NpcStateDto:
	return host.state.find("npc_state", "npc_instance_id", id) as D.NpcStateDto

func place(point: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var flight: XJFlight = host.world.flight
	flight.global_transform = Transform3D(basis, point); flight.velocity = Vector3.ZERO
	flight.write_back(); flight.get_global_transform_interpolated(); flight.reset_physics_interpolation()
	host.camera.bind(flight, host.store.catalog, T.CameraMode.FOLLOW); host.camera.step(0.0)

func position_enemy(id: String, point: Vector3) -> void:
	var row: D.NpcStateDto = npc(id)
	row.pos_x = point.x; row.pos_y = point.y; row.pos_z = point.z
	row.vel_x = 0.0; row.vel_y = 0.0; row.vel_z = 0.0
	row.behavior_phase = T.NpcPhase.PATROL
	row.wait_remaining_s = 0.0; row.cooldown_remaining_s = 0.0
	var body: CharacterBody3D = host.world.npcs[id]
	body.global_position = point; body.velocity = Vector3.ZERO
	body.get_global_transform_interpolated(); body.reset_physics_interpolation()

func reset_case(distance: float = 400.0) -> void:
	await set_options(false, false, false)
	host._command("nav_stop", "", 1, "")
	host.world.projectiles.clear(); host.pending_damage.clear(); shot_events.clear()
	host.deferred_save = {}; host.gameplay.set("combat_remaining_s", 0.0)
	host.ui.set_operation_status("idle", ""); host.ui.show_page("")
	place(home + Vector3(0.0, 0.0, distance))
	position_enemy(enemies[0], home)
	position_enemy(enemies[1], home + Vector3(450.0, 100.0, -700.0))
	for id: String in enemies:
		var row: D.NpcStateDto = npc(id)
		var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", row.spawn_id)
		var definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", str(spawn.npc_id))
		# Restore damaged-but-alive bodies only to the formal caps between scenarios.
		# Death scenarios run last and are never reversed or written over.
		row.shield = float(definition.shield_max); row.armor = float(definition.armor_max); row.hull = float(definition.hull_max)
	for id: String in weapon_ids:
		var fitted: D.EquipmentStateDto = equipment(id)
		fitted.enabled = true; fitted.cooldown_remaining_s = 0.0
		fitted.active_remaining_s = 0.0; fitted.cycle_paid = false
		item(id).durability = 1.0
	var metrics: Dictionary = host.gameplay.call("metrics", host.state.ship())
	host.state.ship().energy = float(metrics.energy_max); host.state.ship().heat = 0.0; host.state.ship().overheated = false
	host.state.ship().shield = float(metrics.shield_max); host.state.ship().armor = float(metrics.armor_max); host.state.ship().hull = float(metrics.hull_max)
	host.world.flight.metrics = metrics
	host.ui._select_target(enemies[0])
	# The existing explicit targeting command is used to create the shared lock;
	# turning fire off retains the lock, permitting genuinely independent orbit.
	if not host.auto_fire_target.is_empty(): host._command("combat_toggle", host.auto_fire_target, 1, "")
	host._command("combat_toggle", enemies[0], 1, "")
	await set_options(false, false, false)
	await sync()
	check(target_id() == enemies[0], "explicit combat command establishes a lock independently of fire")

func boot() -> bool:
	host = Main.new(); host.progress_database_path = database_path
	root.add_child(host); host.set_process(false); host.set_physics_process(false)
	await frames()
	if not check(host.services_ready, "Main initializes formal assets and isolated fresh SQLite"): return false
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): requested.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))
	return true

func prepare() -> bool:
	await command("new_world", "独立自动战斗验收")
	if not check(host.state != null, "real Store creates a fresh frozen-catalog world"): return false
	Engine.physics_ticks_per_second = int(host.store.catalog.rule("simulation_hz")); step_s = 1.0 / float(Engine.physics_ticks_per_second)
	var inventory: RefCounted = host.gameplay.get("inventory")
	# Granting a hull and two legal modules is an explicit equipment precondition.
	# Fitting/switch/undock permissions, slots, budgets and weapon payments are real.
	host.gameplay.call("grant_unlock", "unlock_combat_equipment")
	var ship: D.ShipStateDto = inventory.call("create_ship", "frigate_kestrel", "station_anchor_port")
	await command("switch_ship", ship.ship_instance_id)
	check(host.state.ship() == ship, "real same-station ship switch chooses test-owned normal hull")
	var hold: String = inventory.call("hold", ship, T.ContainerKind.CARGO)
	for module_id: String in ["module_kinetic_needle_i", "module_pulse_breakwater_i"]:
		var ids: Array = inventory.call("grant", hold, module_id, 1)
		if not check(ids.size() == 1, "grant legal module precondition " + module_id): return false
		var result: D.ActionResultDto = host.gameplay.call("act", "fit_module", str(ids[0]), 1, "weapon:%d" % weapon_ids.size())
		if not check(result.phase == T.ActionPhase.APPLIED, "real fitting validates typed slot and ship budgets " + module_id + " " + str(host.gameplay.get("last_error"))): return false
		weapon_ids.append(str(ids[0]))
	inventory.call("grant", hold, "ammo_kinetic_slug_i", 100)
	host.gameplay.call("grant_unlock", "unlock_combat_contracts")
	# Zero elapsed time does not execute a gameplay fixed step. Invoke the real
	# spawn projection after the explicit unlock, as the encounter suite does.
	host.gameplay.call("_sync_spawns")
	await command("undock")
	if not check(host.state.ship().status == T.ShipStatus.FLYING, "actual undock enters controllable flight"): return false
	await sync()
	for spawn_id: String in ["spawn_anchor_patrol_leader", "spawn_anchor_patrol_escort"]:
		var row: D.NpcStateDto = host.state.find("npc_state", "spawn_id", spawn_id) as D.NpcStateDto
		if not check(row != null and row.alive, "real encounter spawn exists " + spawn_id): return false
		enemies.append(row.npc_instance_id)
	home = host.world.npcs[enemies[0]].global_position
	root.grab_focus()
	if DisplayServer.get_name() != "headless":
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		if not check(root.has_focus(), "native window has actual OS focus"): return false
	await reset_case()
	return true

func _run() -> void:
	print("COMBAT_AUTOMATION_V15_REVISION range-buffer-and-large-hull")
	original_hz = Engine.physics_ticks_per_second; original_fps = Engine.max_fps; Engine.max_fps = 144
	root.size = Vector2i(1440, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_size = root.size
	directory = OS.get_environment("XJ_AUTOMATION_V15_DIRECTORY").replace("\\", "/")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/combat-automation-v15/%d" % Time.get_ticks_usec())
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/") and not directory.contains(".."), "validation directory is scoped to tmp"): await finish(); return
	DirAccess.make_dir_recursive_absolute(directory); database_path = directory.path_join("progress.db")
	if not check(not FileAccess.file_exists(database_path), "automation test refuses an existing SQLite"): await finish(); return
	if not await boot() or not await prepare(): await finish(); return
	await option_matrix()
	await weapon_checks()
	await movement_checks()
	await navigation_boundary_checks()
	await input_and_transition_checks()
	await layout_checks()
	await seeking_checks()
	await persistence_checks()
	await big_hull_range_checks()
	await finish()

func option_matrix() -> void:
	for mask: int in range(8):
		await reset_case()
		var fire: bool = (mask & 1) != 0
		var orbit: bool = (mask & 2) != 0
		var seek: bool = (mask & 4) != 0
		for key: String in ["fire", "orbit", "seek"]:
			var enabled: bool = fire if key == "fire" else orbit if key == "orbit" else seek
			if enabled:
				var button: CheckBox = host.ui.equipment_bar.combat_option_buttons[key]
				await actual_click(button, "combination %d %s" % [mask, key])
				button.release_focus()
		check(options() == {"fire": fire, "orbit": orbit, "seek": seek}, "independent options accept combination %d" % mask)
		var before: int = shot_count()
		await step()
		check(target_id() == enemies[0], "accepted target remains stable in combination %d" % mask)
		check(shot_count() - before == (2 if fire else 0), "both ready real weapons fire iff fire option in combination %d" % mask)
		check(host.local_navigation.active() == orbit and (not orbit or host.local_navigation.mode == "orbit"), "in-range movement follows independent orbit option in combination %d" % mask)
		check((not host.auto_fire_target.is_empty()) == fire, "actual fire target follows fire independently of shared lock in combination %d" % mask)
		var context: Dictionary = host.navigation_context(enemies[0])
		check(context.get("combat_options", {}) == options() and str(context.get("combat_target_id", "")) == target_id(), "HUD provider exposes real option and target state in combination %d" % mask)
		combinations += 1

func weapon_checks() -> void:
	await reset_case()
	await set_options(true, false, false)
	var kinetic: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment(weapon_ids[0]).module_def_id)
	var pulse: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment(weapon_ids[1]).module_def_id)
	check(float(kinetic.range_m) > float(pulse.range_m) and float(kinetic.cycle_s) < float(pulse.cycle_s), "two installed formal weapons differ in range and cycle")
	var energy: float = host.state.ship().energy
	var ammo_before: int = ammo_count()
	await step()
	var after_first: float = host.state.ship().energy
	var expected: float = minf(float(host.world.flight.metrics.energy_max), energy + float(host.world.flight.metrics.energy_recharge) * step_s) - float(kinetic.energy_eu) - float(pulse.energy_eu)
	check(is_equal_approx(after_first, expected), "real automatic first volley pays exact energy for both weapons")
	check(ammo_count() == ammo_before - 1, "automatic kinetic cycle consumes exactly one real cargo ammunition")
	check(is_equal_approx(equipment(weapon_ids[0]).cooldown_remaining_s, float(kinetic.cycle_s)) and is_equal_approx(equipment(weapon_ids[1]).cooldown_remaining_s, float(pulse.cycle_s)), "each weapon starts its own frozen-catalog cooldown")
	await step()
	check(shot_count(weapon_ids[0]) == 1 and shot_count(weapon_ids[1]) == 1, "consecutive frame cannot repurchase a cooling weapon cycle")
	var wait_ticks: int = int(ceil(float(kinetic.cycle_s) / step_s)) + 2
	await step(wait_ticks)
	check(shot_count(weapon_ids[0]) >= 2 and shot_count(weapon_ids[1]) == 1, "short-cooldown weapon repeats while long-cooldown weapon still waits")
	await step(wait_ticks)
	check(shot_count(weapon_ids[0]) >= 3 and shot_count(weapon_ids[1]) >= 2, "long-cooldown weapon independently repeats once its own cycle expires")
	for id: String in weapon_ids:
		var definition: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment(id).module_def_id)
		var previous_tick: int = -100000
		for event: Dictionary in shot_events:
			if str(event.item_id) != id: continue
			check((int(event.tick) - previous_tick) * step_s + 0.0001 >= float(definition.cycle_s), "real fired events never beat own cooldown for " + id)
			previous_tick = int(event.tick)
	await reset_case((float(kinetic.range_m) + float(pulse.range_m)) * 0.5)
	await set_options(true, false, false); await step()
	check(shot_count(weapon_ids[0]) == 1 and shot_count(weapon_ids[1]) == 0, "mixed-range fire uses long weapon only when short weapon is out of range")
	for scenario: String in ["disabled", "broken", "no_ammo", "no_energy", "overheat", "out_of_cone", "blocked"]:
		await reset_case()
		await set_options(true, false, false)
		var fitted: D.EquipmentStateDto = equipment(weapon_ids[0])
		var hold: String = host.gameplay.get("inventory").call("hold", host.state.ship(), T.ContainerKind.CARGO)
		var lost_ammo: int = 0
		var blocker: StaticBody3D
		match scenario:
			"disabled": host.gameplay.call("act", "set_module_enabled", weapon_ids[0], 1, "off")
			"broken": item(weapon_ids[0]).durability = 0.0
			"no_ammo":
				lost_ammo = ammo_count()
				host.gameplay.get("inventory").call("consume", hold, "ammo_kinetic_slug_i", lost_ammo, false)
			"no_energy": host.state.ship().energy = 0.0
			"overheat":
				host.state.ship().heat = float(host.world.flight.metrics.heat_max)
				host.state.ship().overheated = true
			"out_of_cone": place(host.world.flight.global_position, Basis(Vector3.UP, PI))
			"blocked":
				blocker = StaticBody3D.new(); blocker.collision_layer = 65
				var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
				shape.size = Vector3(200.0, 200.0, 25.0); collision.shape = shape; blocker.add_child(collision)
				host.world.add_child(blocker); blocker.global_position = home + Vector3(0.0, 0.0, 200.0)
		await get_tree().physics_frame; await get_tree().physics_frame
		var before_ammo: int = ammo_count()
		await step()
		check(shot_count(weapon_ids[0]) == 0 and ammo_count() == before_ammo, "automatic weapon respects real " + scenario + " qualification without charging ammunition")
		if scenario in ["disabled", "broken", "no_ammo"]: check(shot_count(weapon_ids[1]) == 1, "other ready weapon remains independent of kinetic " + scenario)
		if scenario in ["no_energy", "overheat", "out_of_cone", "blocked"]: check(shot_count(weapon_ids[1]) == 0, "common " + scenario + " qualification prevents both weapons")
		if lost_ammo > 0: host.gameplay.get("inventory").call("grant", hold, "ammo_kinetic_slug_i", lost_ammo)
		if blocker != null:
			blocker.queue_free(); await frames(); await get_tree().physics_frame
	await reset_case()
	# A valid module installed on another ship cannot be activated by this ship.
	var foreign_item: String = ""
	for fitted: D.EquipmentStateDto in host.state.rows("equipment_state"):
		var slot: D.ContainerStateDto = host.state.find("container_state", "container_id", fitted.slot_container_id) as D.ContainerStateDto
		if slot.ship_instance_id != host.state.ship().ship_instance_id and slot.slot_type == T.SlotType.WEAPON:
			foreign_item = fitted.item_instance_id; break
	await set_options(true, false, false); await step()
	check(not foreign_item.is_empty() and shot_count(foreign_item) == 0, "automatic fire never activates a parked ship's installed weapon")

func ammo_count() -> int:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var hold: String = inventory.call("hold", host.state.ship(), T.ContainerKind.CARGO)
	return int(inventory.call("count", hold, "ammo_kinetic_slug_i", false))

func movement_checks() -> void:
	await reset_case(1350.0)
	await set_options(false, true, true)
	var before: float = host.world.flight.global_position.distance_to(host.world.npcs[enemies[0]].global_position)
	await step(30)
	check(host.local_navigation.active() and host.local_navigation.mode == "approach" and host.local_navigation.target_id == enemies[0], "out-of-range seek obtains real approach before orbit")
	check(host.world.flight.global_position.distance_to(host.world.npcs[enemies[0]].global_position) < before and host.world.flight.velocity.length() > 0.0, "automatic range approach makes real bounded physical progress")
	check(shot_count() == 0 and host.auto_fire_target.is_empty(), "fire off remains movement only while approaching")
	var both_range: float = float(host.combat_automation.weapon_center_range())
	var both_plan: float = host.local_navigation.combat_distance_m
	var accepted_velocity: Vector3 = host.world.flight.velocity
	var switched_off: D.ActionResultDto = host.gameplay.call("act", "set_module_enabled", weapon_ids[1], 1, "off")
	check(switched_off.phase == T.ActionPhase.APPLIED, "real short-range weapon off command applies during pursuit")
	await step()
	range_diagnostic("short-off")
	var longer_range: float = float(host.combat_automation.weapon_center_range())
	var longer_plan: float = host.local_navigation.combat_distance_m
	check(longer_range > both_range and longer_plan > both_plan and longer_plan < longer_range and host.local_navigation.combat_managed and host.local_navigation.target_id == enemies[0] and target_id() == enemies[0], "disabled short-range weapon is excluded from actual buffered pursuit range without changing enemy")
	var acceleration_budget: float = float(host.world.flight.metrics.acceleration_mps2) * step_s * maxf(1.0, maxf(float(host.world.flight.metrics.strafe_multiplier), float(host.world.flight.metrics.reverse_multiplier)))
	check(host.world.flight.velocity.length() > 0.0 and host.world.flight.velocity.distance_to(accepted_velocity) <= acceleration_budget + 0.02, "range change keeps continuous physically bounded pursuit velocity")
	var long_definition: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment(weapon_ids[0]).module_def_id)
	equipment(weapon_ids[0]).cooldown_remaining_s = float(long_definition.cycle_s)
	await step()
	range_diagnostic("long-cooling")
	check(is_equal_approx(float(host.combat_automation.weapon_center_range()), longer_range) and is_equal_approx(host.local_navigation.combat_distance_m, longer_plan), "weapon cooling never makes pursuit stand-off oscillate")
	var switched_on: D.ActionResultDto = host.gameplay.call("act", "set_module_enabled", weapon_ids[1], 1, "on")
	check(switched_on.phase == T.ActionPhase.APPLIED, "real short-range weapon on command applies during pursuit")
	await step()
	range_diagnostic("short-on")
	check(is_equal_approx(float(host.combat_automation.weapon_center_range()), both_range) and is_equal_approx(host.local_navigation.combat_distance_m, both_plan), "reenabling the intact short-range weapon restores actual buffered pursuit range")
	var entered: bool = false
	for index: int in range(900):
		await step()
		if host.local_navigation.mode == "orbit" and host.local_navigation.active(): entered = true; break
	check(entered, "continuous actual physics approach transitions into orbit inside active weapon range")
	if entered:
		var initial: Vector3 = host.world.flight.global_position - host.world.npcs[enemies[0]].global_position
		await step(90)
		var radial: Vector3 = host.world.flight.global_position - host.world.npcs[enemies[0]].global_position
		check(radial.angle_to(initial) > 0.02 and host.local_navigation.mode == "orbit", "independent orbit advances around real moving enemy")
		check(shot_count() == 0, "orbit never implies firing when automatic battle is off")
		check(host.world.flight.velocity.length() <= float(host.world.flight.metrics.speed_mps) + 0.01, "orbit continues honoring equipped mass-adjusted speed cap")
	await reset_case()
	await set_options(true, true, false)
	await step(60)
	check(shot_count() >= 2 and host.local_navigation.mode == "orbit", "orbit keeps ship facing enemy sufficiently for genuine cone-qualified automatic shots")
	await reset_case(1200.0)
	await set_options(false, false, true)
	await step(30)
	check(host.local_navigation.mode == "approach" and shot_count() == 0, "seek alone approaches a far locked enemy without implying battle or orbit")
	place(home + Vector3(0.0, 0.0, 400.0)); position_enemy(enemies[0], home)
	await step()
	check(not host.local_navigation.active() and shot_count() == 0, "seek alone releases its movement after entering weapon range")

func range_diagnostic(label: String) -> void:
	var modules: Array[Dictionary] = []
	for id: String in weapon_ids:
		var record: D.EquipmentStateDto = equipment(id)
		modules.append({"item_id": id, "enabled": record.enabled, "durability": item(id).durability, "cooldown": record.cooldown_remaining_s})
	var nav: XJLocalNavigation = host.local_navigation
	print("COMBAT_AUTOMATION_V15_RANGE ", JSON.stringify({"label": label, "actual_reach": host.combat_automation.weapon_center_range(), "options": options(), "lock": target_id(), "controller_phase": host.combat_automation.phase, "navigation": {"active": nav.active(), "mode": nav.mode, "phase": nav.phase, "target": nav.target_id, "managed": nav.combat_managed, "cap": nav.combat_distance_m, "last_error": nav.last_error}, "modules": modules, "last_error": str(host.gameplay.get("last_error"))}))

func navigation_boundary_checks() -> void:
	await reset_case()
	var nav: XJLocalNavigation = host.local_navigation
	check(nav.begin("orbit", enemies[0]) and not nav.combat_managed, "ordinary orbit remains an independently accepted navigation command")
	var accepted: Dictionary = {"mode": nav.mode, "phase": nav.phase, "id": nav.target_id, "velocity": host.world.flight.velocity}
	for cap: float in [-1.0, 0.0, NAN, INF, 8.0]:
		check(not nav.begin_combat("orbit", enemies[0], cap), "combat movement rejects invalid or colliding weapon distance " + str(cap))
		check(nav.mode == accepted.mode and nav.phase == accepted.phase and nav.target_id == accepted.id and host.world.flight.velocity.is_equal_approx(accepted.velocity) and not nav.combat_managed, "rejected combat movement preserves prior ordinary order " + str(cap))
	for specification: Dictionary in [{"mode": "warp", "id": enemies[0]}, {"mode": "orbit", "id": "station_anchor_port"}, {"mode": "approach", "id": "not-a-world-target"}]:
		check(not nav.begin_combat(str(specification.mode), str(specification.id), 500.0) and nav.mode == accepted.mode and nav.target_id == accepted.id and not nav.combat_managed, "combat movement rejects wrong target or mode without taking ownership " + str(specification))
	var continuous: Vector3 = Vector3(10.0, 0.0, -20.0)
	host.world.flight.velocity = continuous; host.world.flight.write_back()
	check(nav.begin_combat("approach", enemies[0], 450.0) and nav.combat_managed and nav.mode == "approach" and host.world.flight.velocity.is_equal_approx(continuous), "validated combat approach replaces ordinary navigation with continuous velocity")
	var combat_cap: float = nav.combat_distance_m
	check(not nav.begin_combat("orbit", enemies[0], 8.0) and nav.combat_managed and nav.mode == "approach" and is_equal_approx(nav.combat_distance_m, combat_cap) and host.world.flight.velocity.is_equal_approx(continuous), "invalid replacement preserves prior combat cap and velocity")
	check(nav.begin_combat("orbit", enemies[0], 500.0) and nav.combat_managed and nav.mode == "orbit" and host.world.flight.velocity.is_equal_approx(continuous), "validated combat orbit replaces its own approach without resetting motion")
	check(nav.begin_combat("orbit", enemies[0], 460.0) and nav.combat_managed and nav.combat_distance_m <= 460.0 and host.world.flight.velocity.is_equal_approx(continuous), "same combat target accepts a revised safe weapon range continuously")
	nav.stop()
	check(not nav.combat_managed and nav.combat_distance_m == 0.0, "stop clears combat-specific range ownership")
	check(nav.begin_combat("orbit", enemies[0], 500.0) and nav.combat_managed and nav.combat_distance_m > 0.0, "actual NPC combat orbit accepts safe range and records one motion owner")
	nav.release_to_manual(false)
	check(not nav.active() and not nav.combat_managed and nav.combat_distance_m == 0.0, "manual release clears combat-specific navigation state")
	check(nav.begin("orbit", enemies[0]) and not nav.combat_managed and nav.combat_distance_m == 0.0, "later ordinary orbit never inherits prior combat heading or range")
	var start_forward: Vector3 = -host.world.flight.global_basis.z
	await step(45)
	check((-host.world.flight.global_basis.z).angle_to(start_forward) > 0.05 and not nav.combat_managed, "ordinary orbit preserves tangent-facing steering behavior")
	nav.stop()

func input_and_transition_checks() -> void:
	await reset_case(); await set_options(true, true, true); await step()
	host._command("nav_stop", "", 1, "")
	check(not bool(options().orbit) and not bool(options().seek) and bool(options().fire), "explicit stop clears automatic motion choices while preserving independent battle")
	await step(3)
	check(not host.local_navigation.active() and target_id() == enemies[0], "automatic movement cannot steal control back after stop")
	host.ui._select_target(enemies[1])
	var original_shots: int = shot_count()
	await combat_hotkey()
	check(not bool(options().fire) and host.auto_fire_target.is_empty() and target_id() == enemies[0] and host.ui.target_id == enemies[1], "global Z stops the canonical fire order while browsing another enemy without switching its lock")
	await step(3)
	check(shot_count() == original_shots and target_id() == enemies[0] and not (host.ui.equipment_bar.combat_option_buttons.fire as CheckBox).button_pressed, "global Z stop emits no new weapon cycle and immediately unchecks automatic battle")
	global_z_cases += 1
	await reset_case(); await set_options(true, true, true); await step()
	Input.action_press("yaw_right"); await step(); Input.action_release("yaw_right")
	check(not bool(options().orbit) and not bool(options().seek) and bool(options().fire) and not host.local_navigation.active(), "real manual steering takes motion ownership and leaves fire independent")
	await reset_case(); await set_options(true, true, true); await step()
	host._command("nav_approach", "station_anchor_port", 1, "")
	check(not bool(options().orbit) and not bool(options().seek) and bool(options().fire) and host.local_navigation.target_id == "station_anchor_port", "explicit ordinary navigation replaces automatic motion without replacing fire lock")
	host._command("nav_stop", "", 1, "")
	await reset_case(); await set_options(false, true, true)
	host._command("combat_engage", enemies[0], 1, "")
	check(options() == {"fire": true, "orbit": true, "seek": true} and target_id() == enemies[0], "explicit engage preserves checked orbit and seek while enabling battle for its target")
	await step()
	check(host.local_navigation.mode == "orbit" and host.local_navigation.combat_managed and shot_count() == 2, "engage continues checked in-range orbit and real automatic volley on the next authoritative step")
	await reset_case(); await set_options(true, true, true)
	host.ui.show_page("pause")
	var tick: int = host.state.snapshot.meta.simulation_tick
	var fire_count: int = shot_count()
	var pose: Transform3D = host.world.flight.global_transform
	await step(3)
	check(host.state.snapshot.meta.simulation_tick == tick and shot_count() == fire_count and host.world.flight.global_transform.is_equal_approx(pose), "pause freezes actual automatic cycles and movement")
	host.ui.show_page(""); await sync()
	await step()
	check(shot_count() > fire_count, "accepted automatic battle resumes after actual pause closes")
	var editor := LineEdit.new(); host.ui.root.add_child(editor); editor.grab_focus(); await frames()
	check(host.ui.keyboard_blocked(), "real text editor owns keyboard focus")
	var before_options: Dictionary = options().duplicate()
	host._command("set_combat_option", "seek", 1, "off")
	check(options() == before_options, "text input focus prevents new automatic option configuration")
	editor.release_focus(); editor.queue_free(); await frames()
	Input.action_press("fire"); host.fire_held = true
	root.focus_exited.emit()
	check(not host.fire_held and bool(options().fire), "window focus loss releases held control without changing accepted automatic fire policy")
	Input.action_release("fire")
	await reset_case(); await set_options(true, true, true)
	host.gameplay.call("mark_hostile_attempt")
	var snapshots: int = int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	host._request_save("quick", 0, "return_title")
	check(host._exit_save_pending() and options() == {"fire": false, "orbit": false, "seek": false} and target_id().is_empty(), "exit-save wait clears all automatic modes and target before stabilization")
	for key: String in ["fire", "orbit", "seek"]:
		var button: CheckBox = host.ui.equipment_bar.combat_option_buttons[key]
		check(button.disabled and not button.button_pressed, "exit-save boundary disables canonical unchecked checkbox before any retry " + key)
	host._command("set_combat_option", "seek", 1, "on")
	check(not bool(options().seek), "pending exit save rejects new automatic options")
	var rejected_seek: CheckBox = host.ui.equipment_bar.combat_option_buttons.seek
	check(rejected_seek.disabled and not rejected_seek.button_pressed, "rejected exit-wait command redisplays accepted off state rather than a phantom check")
	await step(3)
	check(shot_count() == 0 and not host.local_navigation.active() and int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n) == snapshots, "exit-save wait advances genuine existing business without new combat cycles or premature commit")
	host._command("cancel_save", "", 1, "")
	check(not host._exit_save_pending() and target_id().is_empty(), "canceling exit wait restores controls without silently restarting combat")
	for key: String in ["fire", "orbit", "seek"]:
		check(not (host.ui.equipment_bar.combat_option_buttons[key] as CheckBox).disabled, "canceling exit wait immediately restores actual checkbox control " + key)
	await reset_case(); await set_options(true, true, true)
	# This ordinary save intentionally retains legacy waiting semantics; it is not
	# an exit barrier and cannot be mistaken for an already committed snapshot.
	host.gameplay.call("mark_hostile_attempt"); host._request_save("manual", 1)
	check(not host.deferred_save.is_empty() and bool(options().fire) and bool(options().orbit) and bool(options().seek), "ordinary save retains accepted modes while honestly waiting for stable gameplay")
	host._command("cancel_save", "", 1, "")
	check(host.deferred_save.is_empty() and options() == {"fire": true, "orbit": true, "seek": true}, "ordinary save cancellation preserves existing accepted combat options")
	await reset_case(); await set_options(true, true, true); await step()
	host._request_save("manual", 1)
	check(not host.deferred_save.is_empty() and host.local_navigation.combat_managed, "ordinary save genuinely waits during an accepted automatic orbit and paid weapons")
	await sync()
	var paid_cooldowns: Dictionary = {}
	for id: String in weapon_ids: paid_cooldowns[id] = equipment(id).cooldown_remaining_s
	var paid_ammo: int = ammo_count()
	for key: String in ["fire", "orbit", "seek"]:
		var button: CheckBox = host.ui.equipment_bar.combat_option_buttons[key]
		check(not button.disabled and button.button_pressed, "ordinary save wait keeps checked combat option cancellable " + key)
		if await actual_click(button, "ordinary save wait off " + key):
			check(not bool(options()[key]) and not button.button_pressed, "ordinary save-wait GUI off displays canonical controller state " + key)
		button.release_focus()
	check(options() == {"fire": false, "orbit": false, "seek": false} and host.auto_fire_target.is_empty() and not host.local_navigation.active(), "three real off clicks stop future battle and automatic motion while ordinary save still waits honestly")
	for id: String in weapon_ids: check(is_equal_approx(equipment(id).cooldown_remaining_s, float(paid_cooldowns[id])), "ordinary save-wait control does not erase already paid weapon cycle " + id)
	check(ammo_count() == paid_ammo and not host.deferred_save.is_empty(), "ordinary save-wait controls neither undo paid ammunition nor fake save completion")
	host._command("cancel_save", "", 1, "")
	await reset_case()
	for id: String in weapon_ids:
		equipment(id).cooldown_remaining_s = 0.0; equipment(id).active_remaining_s = 0.0; equipment(id).cycle_paid = false
	host.world.projectiles.clear(); host.gameplay.set("combat_remaining_s", 0.0)
	await set_options(true, false, true)
	host._command("nav_warp", "station_anchor_port", 1, "")
	check(host.local_navigation.warp_active(), "real stable far station command starts local warp")
	check(options() == {"fire": false, "orbit": false, "seek": false} and target_id().is_empty(), "accepted warp clears automatic choices and lock")
	host._command("set_combat_option", "seek", 1, "on")
	check(not bool(options().seek), "warp rejects new seek instead of mixing motion owners")
	host._command("nav_stop", "", 1, "")

func seeking_checks() -> void:
	await reset_case()
	await set_options(false, false, true); await step()
	check(target_id() == enemies[0] and host.ui.target_id == enemies[0], "seek locks actual nearest live hostile and syncs selected UI")
	host.ui._select_target("station_anchor_port"); await step()
	check(target_id() == enemies[0] and host.auto_fire_target.is_empty(), "inspecting non-hostile station never changes seek's hostile lock or enables fire")
	position_enemy(enemies[1], host.world.flight.global_position + Vector3(80.0, 0.0, -180.0))
	await step()
	check(target_id() == enemies[0], "accepted target remains locked when another enemy becomes closer")
	await set_options(false, false, false)
	host.ui._select_target(enemies[1])
	await step()
	check(target_id() == enemies[0], "ordinary manual inspection does not replace combat lock")
	host._command("combat_toggle", enemies[1], 1, "")
	check(target_id() == enemies[1] and bool(options().fire), "explicit manual combat switch chooses the requested live hostile")
	await set_options(false, false, false)
	# Lose current target by leaving the validated detection radius; seek off must
	# clear it without silently locking another still-in-range enemy.
	position_enemy(enemies[1], home + Vector3(0.0, 0.0, -float(host.store.catalog.rule("target_marker_detection_range_m")) * 2.0))
	await step()
	check(target_id().is_empty(), "seek off clears out-of-detection lock without retargeting")
	position_enemy(enemies[1], home + Vector3(0.0, 0.0, -800.0))
	# Equal-distance targets use real geometry. Repeating a cleared acquisition
	# must be deterministic, while either valid tied identity is acceptable.
	position_enemy(enemies[0], home + Vector3(-250.0, 0.0, 0.0))
	position_enemy(enemies[1], home + Vector3(250.0, 0.0, 0.0))
	await set_options(false, false, true); await step()
	var tied: String = target_id()
	check(enemies.has(tied), "equal-distance seek acquires one actual hostile")
	await set_options(false, false, false)
	position_enemy(tied, home + Vector3(0.0, 0.0, -float(host.store.catalog.rule("target_marker_detection_range_m")) * 2.0))
	await step()
	position_enemy(enemies[0], home + Vector3(-250.0, 0.0, 0.0))
	position_enemy(enemies[1], home + Vector3(250.0, 0.0, 0.0))
	await set_options(false, false, true); await step()
	check(target_id() == tied, "equal-distance reacquisition stays deterministic")
	await set_options(false, false, false)
	position_enemy(enemies[0], home)
	position_enemy(enemies[1], home + Vector3(0.0, 0.0, -800.0))
	if target_id() != enemies[0]:
		host._command("combat_toggle", enemies[0], 1, "")
		await set_options(false, false, false)
	await set_options(false, false, true); await step()
	check(target_id() == enemies[0], "enabling seek reacquires nearest eligible hostile after detection loss")
	await set_options(false, false, false)
	for id: String in weapon_ids: host.gameplay.call("act", "set_module_enabled", id, 1, "off")
	place(home + Vector3(0.0, 0.0, 1200.0))
	await set_options(false, false, true); await step(3)
	check(target_id() == enemies[0] and not host.local_navigation.active() and shot_count() == 0, "no active usable weapon still permits seek lock but cannot invent range pursuit")
	for id: String in weapon_ids: host.gameplay.call("act", "set_module_enabled", id, 1, "on")
	place(home + Vector3(0.0, 0.0, 400.0)); position_enemy(enemies[0], home)
	await set_options(false, false, true); await step()
	var previous: String = target_id()
	host.gameplay.call("damage_npc", previous, Vector3.ONE * 100000.0)
	await sync(); await step()
	check(not npc(previous).alive and target_id() == enemies[1] and host.ui.target_id == enemies[1], "real death removes old enemy and seek locks remaining hostile without a new user command")
	await set_options(false, false, false)
	host.gameplay.call("damage_npc", enemies[1], Vector3.ONE * 100000.0)
	await sync(); await step()
	check(target_id().is_empty() and not host.local_navigation.active(), "seek off clears killed lock without hunting a replacement")
	await set_options(false, false, true); await step(3)
	check(target_id().is_empty() and bool(options().seek) and not host.local_navigation.active() and shot_count() == 0, "no live hostile leaves seek honestly waiting and never locks station gate resource beacon or corpse")
	check(host.world.targets.has("station_anchor_port") and host.world.targets.has("group:encounter_anchor_patrol"), "non-hostile world choices remain present in empty-hostile seek witness")
	await set_options(true, false, false)
	check(bool(options().fire) and target_id().is_empty() and host.auto_fire_target.is_empty() and (host.ui.equipment_bar.combat_option_buttons.fire as CheckBox).button_pressed, "no-hostile witness has canonical battle checked while effective firing target is empty")
	await combat_hotkey()
	check(not bool(options().fire) and target_id().is_empty() and host.auto_fire_target.is_empty() and not (host.ui.equipment_bar.combat_option_buttons.fire as CheckBox).button_pressed, "global Z clears checked battle with no detectable hostile rather than leaving a phantom order")
	await step()
	check(shot_count() == 0 and not bool(options().fire), "empty-target global Z stop remains off on the next authoritative step")
	global_z_cases += 1

func visible(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree() or not Rect2(Vector2.ZERO, host.ui.root.size).encloses(control.get_global_rect()): return false
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer and not (ancestor as ScrollContainer).get_global_rect().encloses(control.get_global_rect()): return false
		ancestor = ancestor.get_parent()
	return true

func actual_click(button: Button, label: String) -> bool:
	if not check(button != null and not button.disabled and visible(button), "real visible enabled checkbox " + label): return false
	var pressed: Dictionary = {"count": 0}
	var observer: Callable = func(): pressed.count = int(pressed.count) + 1
	button.pressed.connect(observer)
	var ready: bool = false
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 3000
	var prior: Rect2 = button.get_global_rect()
	while Time.get_ticks_msec() < deadline:
		if DisplayServer.get_name() != "headless" and not root.has_focus(): root.grab_focus()
		var point: Vector2 = button.get_global_rect().get_center()
		host.get_viewport().warp_mouse(point)
		var event := InputEventMouseMotion.new(); event.position = point; event.global_position = point
		host.get_viewport().push_input(event, true)
		await get_tree().process_frame
		var hover: Control = host.get_viewport().gui_get_hovered_control()
		var over: bool = hover != null and (hover == button or button.is_ancestor_of(hover))
		if DisplayServer.get_name() != "headless": over = over and root.has_focus() and button.get_global_rect().has_point(button.get_global_mouse_position())
		stable = stable + 1 if over and visible(button) and prior.is_equal_approx(button.get_global_rect()) else 0
		prior = button.get_global_rect()
		if stable >= 2: ready = true; break
	if check(ready, "actual pointer reaches checkbox " + label):
		for down: bool in [true, false]:
			var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = down
			click.position = button.get_global_rect().get_center(); click.global_position = click.position
			host.get_viewport().push_input(click, true)
		await frames(3)
	button.pressed.disconnect(observer)
	return check(pressed.count == 1, "real GUI click activates checkbox once " + label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# Freeze the automatic callback, not the production lifecycle. Every picture
	# follows one actual Main simulation tick and the real flight-stage handoff.
	await step()
	await frames(4); await RenderingServer.frame_post_draw
	flight_render_check("native capture " + label)
	if host.state.ship().status == T.ShipStatus.FLYING and host.camera.mode != T.CameraMode.FRONT:
		var point: Vector3 = host.world.flight.get_global_transform_interpolated().origin
		check(not host.camera.camera.is_position_behind(point) and Rect2(Vector2.ZERO, host.get_viewport().get_visible_rect().size).has_point(host.camera.camera.unproject_position(point)), "native ship model is framed inside the active flight camera " + label)
		rendered_flight_captures += 1
	var image: Image = root.get_texture().get_image()
	if check(not image.is_empty() and image.save_png(directory.path_join(label + ".png")) == OK, "native automation HUD capture " + label): captures += 1

func layout_checks() -> void:
	await reset_case()
	for layout: Dictionary in [{"size": Vector2i(1440, 900), "scale": 1.0}, {"size": Vector2i(1280, 720), "scale": 1.0}, {"size": Vector2i(1440, 900), "scale": 2.0}, {"size": Vector2i(1280, 720), "scale": 2.0}]:
		root.size = layout.size; root.content_scale_size = Vector2i(Vector2(layout.size) / float(layout.scale))
		host._sync_presentation_stage()
		host.ui.tick(1.0); await frames(5)
		var label: String = "%dx%d-%d" % [root.size.x, root.size.y, int(float(layout.scale) * 100.0)]
		var boxes: Array[Rect2] = []
		for key: String in ["fire", "orbit", "seek"]:
			var button: CheckBox = host.ui.equipment_bar.combat_option_buttons[key]
			check(visible(button) and host.ui.equipment_bar.get_global_rect().encloses(button.get_global_rect()), "automation checkbox remains inside device HUD " + key + " " + label)
			var font: Font = button.get_theme_font("font")
			var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			var icon: Texture2D = button.get_theme_icon("checked")
			check(button.text in ["自动战斗", "自动环绕", "自动索敌"] and button.size.x >= text_width + icon.get_width() + button.get_theme_constant("h_separation"), "full readable four-character checkbox label fits " + key + " " + label)
			for prior: Rect2 in boxes: check(not prior.intersects(button.get_global_rect()), "automation options do not overlap " + label)
			boxes.append(button.get_global_rect())
			var before: bool = bool(options()[key]); var count: int = requested.size()
			if await actual_click(button, key + " " + label):
				check(bool(options()[key]) != before and button.button_pressed == bool(options()[key]), "actual checkbox request changes only accepted controller state " + key + " " + label)
				check(requested.size() == count + 1 and str(requested[-1].action) == "set_combat_option" and str(requested[-1].target) == key, "checkbox emits one actual typed command " + key + " " + label)
				check(not host.pointer_drag_pressed and not host.pointer_pick_pending and not host.observing, "checkbox mouse input never leaks into scene observation " + key + " " + label)
			button.release_focus()
		# This also runs in headless: checkbox snapshots must describe an actually
		# accepted physics state instead of unprocessed queued UI requests.
		await step()
		check(str(host.combat_automation.status) != "战斗自动化已关闭" and host.ui.equipment_bar.combat_status_label.text == str(host.combat_automation.status), "checked layout options display accepted live combat status " + label)
		await capture("combat-options-" + label)
		await set_options(false, false, false)
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	host.ui.tick(1.0); await frames(4)
	# The preceding real orbit captures legitimately leave inertia. Establish an
	# explicit stationary keyboard witness before asserting Space adds no thrust.
	host.world.flight.velocity = Vector3.ZERO; host.world.flight.write_back()
	var first: CheckBox = host.ui.equipment_bar.combat_option_buttons.fire
	first.grab_focus(); await frames()
	var before_options: bool = bool(options().fire)
	var pose: Transform3D = host.world.flight.global_transform
	var key_press := InputEventKey.new(); key_press.keycode = KEY_SPACE; key_press.physical_keycode = KEY_SPACE; key_press.pressed = true
	host.get_viewport().push_input(key_press, true)
	await frames(3); await step()
	check(host.world.flight.intent.thrust_y == 0.0 and host.world.flight.global_position.is_equal_approx(pose.origin), "held keyboard Space on focused checkbox produces no upward thrust")
	var key_release := InputEventKey.new(); key_release.keycode = KEY_SPACE; key_release.physical_keycode = KEY_SPACE; key_release.pressed = false
	host.get_viewport().push_input(key_release, true)
	await frames(3)
	check(bool(options().fire) != before_options, "keyboard Space actually toggles focused checkbox")
	first.release_focus()
	await tooltip_checks()

func tooltip_checks() -> void:
	if DisplayServer.get_name() == "headless": return
	var seek: CheckBox = host.ui.equipment_bar.combat_option_buttons.seek
	var point: Vector2 = seek.get_global_rect().get_center()
	host.get_viewport().warp_mouse(point)
	var event := InputEventMouseMotion.new(); event.position = point; event.global_position = point; event.button_mask = Input.get_mouse_button_mask()
	host.get_viewport().push_input(event, true)
	var before_hover: Control = host.get_viewport().gui_get_hovered_control()
	print("COMBAT_AUTOMATION_V15_TOOLTIP_BEFORE ", JSON.stringify({"hover_path": str(before_hover.get_path()) if before_hover != null else "", "button_hovered": seek.is_hovered(), "control_mouse": str(seek.get_global_mouse_position()), "focus": root.has_focus(), "pressed_mask": int(Input.get_mouse_button_mask()), "rect": str(seek.get_global_rect()), "tooltip_text": seek.tooltip_text}))
	await get_tree().create_timer(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)) + 0.2).timeout
	await frames(4)
	var label: Label = find_tooltip_label(root, seek.tooltip_text)
	var popup: Window = label.get_window() if label != null else null
	var hover: Control = host.get_viewport().gui_get_hovered_control()
	var hovering: bool = hover != null and (hover == seek or seek.is_ancestor_of(hover))
	print("COMBAT_AUTOMATION_V15_TOOLTIP ", JSON.stringify({"rect": str(seek.get_global_rect()), "requested_point": str(point), "viewport_mouse": str(host.get_viewport().get_mouse_position()), "control_mouse": str(seek.get_global_mouse_position()), "os_mouse": str(DisplayServer.mouse_get_position()), "root_position": str(root.position), "root_size": str(root.size), "logical_size": str(root.content_scale_size), "focus": root.has_focus(), "hover_path": str(hover.get_path()) if hover != null else "", "button_hovered": seek.is_hovered(), "pressed_mask": int(Input.get_mouse_button_mask()), "tooltip_text": seek.tooltip_text, "popups": tooltip_popup_records(root)}))
	check(root.has_focus() and hovering and seek.get_global_rect().has_point(seek.get_global_mouse_position()) and Input.get_mouse_button_mask() == 0, "native seek tooltip witness has real OS focus, pointer hover and no held mouse button")
	# Godot's built-in tooltip window is an internal child. Match its actual
	# visible Label text and PopupPanel identity; do not emit hover or fabricate it.
	if not check(label != null and popup is PopupPanel and popup.visible and popup.get_script() == null and str(popup.name).begins_with("@PopupPanel@"), "native seek hover creates real built-in tooltip popup"): return
	check(popup.size.x <= root.size.x and popup.size.y <= root.size.y and Rect2(Vector2.ZERO, Vector2(popup.size)).encloses(label.get_global_rect()), "native automatic seek tooltip text fits its popup and the actual window")
	check(label.text.contains("敌") and label.text == seek.tooltip_text, "native seek tooltip renders the configured hostile target policy")
	var font: Font = label.get_theme_font("font")
	for line: String in label.text.split("\n"):
		check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x + 1.0, "native tooltip line fits its rendered label")
	await capture("combat-seek-tooltip")

func find_tooltip_label(node: Node, text: String) -> Label:
	if node is Label and node.is_visible_in_tree() and (node as Label).text == text: return node as Label
	for child: Node in node.get_children(true):
		var found: Label = find_tooltip_label(child, text)
		if found != null: return found
	return null

func tooltip_popup_records(node: Node) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if node is PopupPanel:
		var popup: PopupPanel = node as PopupPanel
		var texts: Array[String] = []
		for child: Node in popup.get_children(true):
			if child is Label: texts.append((child as Label).text)
		records.append({"name": str(popup.name), "path": str(popup.get_path()), "visible": popup.visible, "position": str(popup.position), "size": str(popup.size), "text": texts})
	for child: Node in node.get_children(true): records.append_array(tooltip_popup_records(child))
	return records

func persistence_checks() -> void:
	await set_options(false, false, false)
	host._command("nav_stop", "", 1, ""); host.world.projectiles.clear(); host.pending_damage.clear()
	host.gameplay.call("stop_interactions"); host.gameplay.call("tick", float(host.store.catalog.rule("combat_exit_delay_s")) + 1.0)
	for fitted: D.EquipmentStateDto in host.gameplay.call("equipped", host.state.ship()):
		fitted.cooldown_remaining_s = 0.0; fitted.active_remaining_s = 0.0; fitted.cycle_paid = false
	check(host._save_block_reason().is_empty(), "real stable authority permits explicit SQLite save")
	await command("save", "2", 1, "manual")
	var slots: Array[Dictionary] = host.store.list_slots()
	var slot: Dictionary = {}
	for candidate: Dictionary in slots:
		if str(candidate.slot_kind) == "manual" and int(candidate.slot_index) == 2: slot = candidate
	if not check(not slot.is_empty(), "real manual slot committed the legitimate test world"): return
	await set_options(false, false, true)
	var old_world: int = host.world.get_instance_id()
	await command("load", str(slot.slot_id), int(slot.generation), str(slot.current_snapshot_id))
	check(host.world.get_instance_id() != old_world and options() == {"fire": false, "orbit": false, "seek": false} and target_id().is_empty(), "actual load replaces scene and clears transient combat options and stale lock")
	var ship_id: String = host.state.ship().ship_instance_id
	host.queue_free(); host = null; await frames(4); await get_tree().create_timer(0.25).timeout
	if not await boot(): return
	await command("continue")
	check(host.state.ship().ship_instance_id == ship_id and options() == {"fire": false, "orbit": false, "seek": false} and target_id().is_empty(), "SQLite close and reopen preserves assets but never resurrects transient automation")
	await set_options(false, false, true)
	var station: Dictionary = host.store.catalog.one("station_defs", "station_id", "station_anchor_port")
	place(host.world.anchor_position(str(station.station_anchor_id)))
	host.gameplay.call("tick", float(host.store.catalog.rule("combat_exit_delay_s")) + 1.0)
	await command("dock", "station_anchor_port")
	check(host.state.ship().status == T.ShipStatus.DOCKED and options() == {"fire": false, "orbit": false, "seek": false} and target_id().is_empty(), "actual station docking clears all flight automation and lock")
	await command("set_combat_option", "seek", 1, "on")
	check(not bool(options().seek), "docked state rejects automatic flight configuration")
	var previous_world_id: String = host.state.world_id
	await command("new_world", "第二独立世界替换验收")
	check(host.state.world_id != previous_world_id and options() == {"fire": false, "orbit": false, "seek": false} and target_id().is_empty(), "actual new-world replacement initializes all modes off without carrying prior identities")

func big_hull_range_checks() -> void:
	# This fresh second world establishes a declared large-hull fitting fixture;
	# no prior enemy is revived, no personal world is replaced, and formal asset
	# muzzles/colliders are kept intact.
	var inventory: RefCounted = host.gameplay.get("inventory")
	host.gameplay.call("grant_unlock", "unlock_combat_equipment")
	var ship: D.ShipStateDto = inventory.call("create_ship", "battleship_bastion", "station_anchor_port")
	await command("switch_ship", ship.ship_instance_id)
	if not check(host.state.ship() == ship, "real same-station switch accepts the declared large-hull fixture"): return
	var hold: String = inventory.call("hold", ship, T.ContainerKind.CARGO)
	var ids: Array = inventory.call("grant", hold, "module_pulse_breakwater_i", 1)
	if not check(ids.size() == 1, "large-hull short-range module grant precondition"): return
	var result: D.ActionResultDto = host.gameplay.call("act", "fit_module", str(ids[0]), 1, "weapon:0")
	if not check(result.phase == T.ActionPhase.APPLIED, "real large-hull fitting validates actual slot and budgets"): return
	host.gameplay.call("grant_unlock", "unlock_combat_contracts"); host.gameplay.call("_sync_spawns")
	await command("undock"); await sync()
	var leader: D.NpcStateDto = host.state.find("npc_state", "spawn_id", "spawn_anchor_patrol_leader") as D.NpcStateDto
	if not check(leader != null and leader.alive and host.world.npcs.has(leader.npc_instance_id), "large-hull witness uses a newly generated formal live encounter member"): return
	var enemy: CharacterBody3D = host.world.npcs[leader.npc_instance_id]
	var metrics: Dictionary = host.gameplay.call("metrics", ship); host.world.flight.metrics = metrics
	var center_reach: float = float(host.combat_automation.weapon_center_range())
	var module: Dictionary = host.store.catalog.one("module_defs", "module_id", "module_pulse_breakwater_i")
	var muzzle: Transform3D = host.world.flight.muzzle(0)
	check(center_reach > 0.0 and center_reach < float(module.range_m) and muzzle.origin.distance_to(host.world.flight.global_position) > 0.0, "large-hull center range accounts for an actual offset formal muzzle")
	place(enemy.global_position + Vector3(0.0, 0.0, center_reach - 0.1))
	# A legal reaction-phase precondition isolates the 25-tick control response;
	# its countdown is the formal scout reaction duration, not a frozen AI mock.
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", leader.spawn_id)
	var behavior: Dictionary = host.store.catalog.one("npc_behavior_defs", "behavior_id", str(spawn.behavior_id))
	leader.behavior_phase = T.NpcPhase.ACQUIRE; leader.wait_remaining_s = float(behavior.reaction_s)
	host.world.flight.velocity = Vector3.RIGHT * float(metrics.speed_mps) * 0.5
	host.world.flight.write_back()
	host.ui._select_target(leader.npc_instance_id)
	await set_options(false, true, true)
	var tick_before: int = host.state.snapshot.meta.simulation_tick
	var phases: Array[String] = []
	for index: int in range(25):
		await step()
		large_hull_ticks += 1
		phases.append(str(host.combat_automation.phase))
		check(host.world.flight.global_position.is_finite() and host.world.flight.velocity.is_finite() and host.world.flight.global_basis.is_finite(), "large-hull buffered orbit remains finite at tick %d" % index)
		check(host.world.flight.velocity.length() <= float(host.world.flight.metrics.speed_mps) + 0.01, "large-hull buffered orbit honors actual speed cap at tick %d" % index)
	var planned: float = host.local_navigation.combat_distance_m
	check(target_id() == leader.npc_instance_id and host.local_navigation.combat_managed and planned > 0.0 and planned < center_reach, "large-hull orbit stays on its real enemy with an inward safety plan")
	check(not phases.has("approach") and phases.count("orbit") == 25, "large-hull short-range orbit does not chatter into approach during the 25-tick edge witness")
	check(host.state.snapshot.meta.simulation_tick - tick_before == 25 and shot_count(str(ids[0])) == 0, "large-hull witness executes one simulation step per tick and never enables fire")
	print("COMBAT_AUTOMATION_V15_LARGE_HULL ", JSON.stringify({"ship": ship.ship_def_id, "actual_center_range_m": center_reach, "navigation_cap_m": planned, "phases": phases, "ticks": 25, "fixture": "new world, granted legal hull and module, positioned at range edge, formal acquisition reaction"}))

func finish() -> void:
	for action: String in InputMap.get_actions(): Input.action_release(action)
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(4); await get_tree().create_timer(0.25).timeout
	Engine.physics_ticks_per_second = original_hz; Engine.max_fps = original_fps
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "revision": "range-buffer-and-large-hull", "checks": checks, "failures": failures.size(), "captures": captures, "rendered_flight_captures": rendered_flight_captures, "toggle_combinations": combinations, "large_hull_ticks": large_hull_ticks, "global_z_cases": global_z_cases, "database_path": database_path, "native": DisplayServer.get_name() != "headless", "fixture_boundary": "Formal equipment and encounter NPCs; explicit grants, unlocks, positions and damage endpoints; no personal database or natural campaign claim"}
	print("COMBAT_AUTOMATION_V15_FINAL_JSON ", JSON.stringify(summary))
	print("COMBAT_AUTOMATION_V15_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
