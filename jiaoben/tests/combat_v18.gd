extends Node
## Real Main, isolated SQLite, catalog fittings and swept damage. Grants,
## unlocks, isolated arena positions and durable target HP are explicit fixtures.
## They do not claim natural purchasing, progression or long-term balance.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Validation = preload("res://runtime/data/validation.gd")
const Codec = preload("res://runtime/data/codec.gd")
const State = preload("res://runtime/state.gd")
const Space = preload("res://runtime/space_coordinates.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var hits: Array[Dictionary] = []
var database_path: String
var drone_item_id: String
var enemy: D.NpcStateDto
var enemy_node: Node3D
var base := Vector3(70000.0, 40000.0, 70000.0)
var root: Window:
	get: return get_tree().root

func _ready() -> void:
	get_tree().set_meta("xj_combat_v18_diagnostic", true)
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
	return ok

func _hit(target: String, raw: Vector3, point: Vector3, owner: String) -> void:
	hits.append({"target": target, "raw": raw, "point": point, "owner": owner})

func _frames(count: int = 2) -> void:
	for index: int in count: await get_tree().process_frame

func _wait_writer() -> bool:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return check(not host.busy, "real Main's asynchronous save writer finishes before the next command")

func _target_evidence(label: String) -> void:
	var entry: Dictionary = host.world.targets.get(enemy.npc_instance_id, {}) if enemy != null else {}
	var node: Variant = entry.get("node")
	var node_valid: bool = node is Node3D and is_instance_valid(node)
	var distance: float = host.world.target_distance(enemy.npc_instance_id) if node_valid else -1.0
	var installed: D.EquipmentStateDto = host.state.find("equipment_state", "item_instance_id", drone_item_id)
	var module: Dictionary = host.store.catalog.one("module_defs", "module_id", installed.module_def_id) if installed != null else {}
	print("COMBAT_V18_TARGET_EVIDENCE " + JSON.stringify({"label": label, "ship_id": host.state.ship().ship_instance_id, "ship_status": T.ShipStatus.keys()[int(host.state.ship().status)], "ship_sector": host.state.ship().sector_id, "player_docked": host.state.player().has_docked_station_id, "busy": host.busy, "travel_active": host.travel.active(), "warp_active": host.local_navigation.warp_active(), "target_id": enemy.npc_instance_id if enemy != null else "", "target_kind": entry.get("kind", ""), "target_node_valid": node_valid, "target_alive": enemy != null and enemy.alive, "target_sector": enemy.sector_id if enemy != null else "", "distance_m": distance, "sensor_m": float(host.store.catalog.rule("target_marker_detection_range_m")), "contact_visible": host.world.contact_visible(entry, distance) if node_valid else false, "enemy_valid": host._enemy_target_valid(enemy.npc_instance_id) if enemy != null else false, "bay_control_range_m": module.get("range_m", 0.0), "bay_enabled": installed.enabled if installed != null else false, "bay_cooldown_s": installed.cooldown_remaining_s if installed != null else -1.0, "pending_count": host.world.projectiles.drones.size(), "geometry_los": host.world.line_of_sight(host.world.flight.global_position, node.global_position, host.world.flight.get_rid(), enemy.npc_instance_id) if node_valid and enemy != null else false, "gameplay_error": host.gameplay.last_error}))

func _run() -> void:
	var directory: String = OS.get_environment("XJ_COMBAT_V18_DIRECTORY").replace("\\", "/")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/combat-v18/%d" % Time.get_ticks_usec()).replace("\\", "/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/") and not directory.contains(".."), "test SQLite is scoped to tmp"): await _finish(); return
	DirAccess.make_dir_recursive_absolute(directory)
	database_path = directory.path_join("progress.db")
	if not check(not FileAccess.file_exists(database_path), "test refuses an existing progress database"): await _finish(); return
	host = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	host.set_process(false); host.set_physics_process(false)
	await _frames()
	if not check(host.services_ready, "real Main initializes assets and isolated SQLite"): await _finish(); return
	await host._command("new_world", "武器与无人机独立验收", 1, "")
	await _frames()
	if not check(host.state != null and host.store.catalog.table_names.has("weapon_behavior_defs"), "fresh world uses the new frozen combat catalog"): await _finish(); return
	for unlock: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.grant_unlock(str(unlock.unlock_id))
	await _fitting_checks()
	var flight_ready: bool = await _prepare_drone_ship()
	await _physical_weapon_checks()
	if flight_ready:
		await _drone_checks()
		await _pending_preview_checks()
		await _persistence_check()
	await _finish()

func _fitting_checks() -> void:
	var inventory: RefCounted = host.gameplay.inventory
	var warehouse: String = inventory.warehouse("station_anchor_port")
	var allowed_drone: Array[String] = ["cruiser_horizon", "battleship_bastion", "support_weaver"]
	for row: Dictionary in host.store.catalog.rows("ship_defs"):
		var ship: D.ShipStateDto = inventory.create_ship(str(row.ship_id), "station_anchor_port")
		var switched: D.ActionResultDto = host.gameplay.act("switch_ship", ship.ship_instance_id)
		check(switched.phase == T.ActionPhase.APPLIED, "same-station switch uses real normal-owned hull " + str(row.ship_id))
		var drone_ids: Array = inventory.grant(warehouse, "module_drone_swarm_i", 1)
		var drone: String = str(drone_ids[0])
		var before: String = host.state.find("item_instance_state", "item_instance_id", drone).container_id
		var result: D.ActionResultDto = host.gameplay.act("fit_module", drone, 1, "weapon:0")
		var expected: bool = allowed_drone.has(str(row.ship_id))
		check((result.phase == T.ActionPhase.APPLIED) == expected, "actual drone fitting obeys hull permission " + str(row.ship_id))
		if expected:
			check(host.gameplay.act("unfit_module", drone).phase == T.ActionPhase.APPLIED, "allowed drone unfit preserves the original item " + str(row.ship_id))
		else:
			check(host.state.find("item_instance_state", "item_instance_id", drone).container_id == before and host.state.find("equipment_state", "item_instance_id", drone) == null, "rejected drone fitting leaves assets untouched " + str(row.ship_id))
		var medium_allowed: bool = str(row.ship_id) in ["destroyer_raptor", "cruiser_horizon", "battleship_bastion"]
		check(host.gameplay.weapon_fit_reason(ship, "module_kinetic_lance_i").is_empty() == medium_allowed, "medium rail permissions distinguish hull classes " + str(row.ship_id))
		check(host.gameplay.weapon_fit_reason(ship, "module_kinetic_siege_i").is_empty() == (str(row.ship_id) == "battleship_bastion"), "heavy rail permission is battleship-only " + str(row.ship_id))
	var support: D.ShipStateDto = inventory.create_ship("support_weaver", "station_anchor_port")
	host.gameplay.act("switch_ship", support.ship_instance_id)
	var first: Array = inventory.grant(warehouse, "module_drone_swarm_i", 1)
	var second: Array = inventory.grant(warehouse, "module_drone_swarm_ii", 1)
	check(host.gameplay.act("fit_module", str(first[0]), 1, "weapon:0").phase == T.ActionPhase.APPLIED, "first drone tier fits on support hull")
	check(not host.gameplay.weapon_fit_reason(support, "module_drone_swarm_ii").is_empty(), "family installation limit counts different drone tiers together")
	var fitting: D.ActionResultDto = host.gameplay.act("fit_module", str(second[0]), 1, "weapon:1")
	check(fitting.phase == T.ActionPhase.REJECTED and host.state.find("equipment_state", "item_instance_id", str(second[0])) == null, "second drone tier cannot bypass the family limit")
	var validator := Validation.new()
	check(validator.validate(host.state, host.store.catalog), "real fitted state passes full relational-state validation")
	var fitted: D.EquipmentStateDto = host.state.find("equipment_state", "item_instance_id", str(first[0]))
	var container: D.ContainerStateDto = host.state.find("container_state", "container_id", fitted.slot_container_id)
	var old_index: int = container.slot_index
	container.slot_index = 99
	check(not validator.validate(host.state, host.store.catalog), "full-state validation rejects a hull's nonexistent hardpoint")
	container.slot_index = old_index
	check(validator.validate(host.state, host.store.catalog), "restoring the legitimate slot restores full validation")
	host.gameplay.act("unfit_module", str(first[0]))

func _prepare_drone_ship() -> bool:
	var inventory: RefCounted = host.gameplay.inventory
	var ship: D.ShipStateDto = inventory.create_ship("support_weaver", "station_anchor_port")
	await host._command("switch_ship", ship.ship_instance_id, 1, "")
	if not await _wait_writer() or not check(host.state.ship() == ship and host.world.flight.record.ship_instance_id == ship.ship_instance_id, "real Main switches and projects the declared support hull"): return false
	var warehouse: String = inventory.warehouse("station_anchor_port")
	var ids: Array = inventory.grant(warehouse, "module_drone_swarm_i", 1)
	drone_item_id = str(ids[0])
	if not check(host.gameplay.act("fit_module", drone_item_id, 1, "weapon:0").phase == T.ActionPhase.APPLIED, "real support hull accepts one attack drone bay"): return false
	await host._command("undock", "", 1, "")
	if not await _wait_writer() or not check(host.state.ship().status == T.ShipStatus.FLYING and not host.state.player().has_docked_station_id, "real undock command enters flight before positioning any target"): return false
	await _frames()
	host.world.projectiles.set_paused(false)
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	await _preview_place(base, str(spawn.anchor_id))
	enemy = D.NpcStateDto.new()
	enemy.npc_instance_id = "combat-v18-durable-target"
	enemy.spawn_id = "spawn_anchor_tutorial_scout"
	enemy.sector_id = host.state.current_sector()
	enemy.alive = true
	# Durable target HP is a runtime-only physical-test precondition, never saved.
	enemy.shield = 10000.0; enemy.armor = 10000.0; enemy.hull = 10000.0
	enemy.behavior_phase = T.NpcPhase.PATROL
	enemy.pos_x = base.x; enemy.pos_y = base.y; enemy.pos_z = base.z - 650.0
	host.state.add("npc_state", enemy)
	if Space.supported(host.store.catalog):
		if not check(Space.assign(host.state, "npc", enemy.npc_instance_id, Space.site_for_anchor(host.store.catalog, str(spawn.anchor_id))), "explicit target keeps its frozen spawn site"): return false
	if not check(host.world.sync_entities(), "production sector projects the explicit isolated target"): return false
	enemy_node = host.world.targets[enemy.npc_instance_id].node
	host.world.projectiles.hit.connect(_hit)
	host.ui._select_target(enemy.npc_instance_id)
	await get_tree().physics_frame; await get_tree().physics_frame
	_target_evidence("prepared")
	return check(host._enemy_target_valid(enemy.npc_instance_id), "explicit target satisfies actual detection and enemy validity")

func _physical_weapon_checks() -> void:
	var shots: XJProjectiles = host.world.projectiles
	var origin: Vector3 = base + Vector3(6000, 0, 0)
	var body := StaticBody3D.new()
	body.collision_layer = 3
	body.set_meta("entity_id", "combat-v18-sweep-target")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3.ONE * 20.0
	collision.shape = shape; body.add_child(collision); host.world.add_child(body)
	body.global_position = origin + Vector3.RIGHT * 200.0
	await get_tree().physics_frame; await get_tree().physics_frame
	for module: Dictionary in host.store.catalog.rows("weapon_defs"):
		var profile: Dictionary = host.gameplay.weapon_profile(str(module.module_id))
		if str(profile.fire_mode) == "drone": continue
		var before: int = hits.size()
		var damage := Vector3.ZERO; damage[host.gameplay.damage_index(str(module.damage_type))] = float(module.raw_damage)
		shots.fire(host.state.ship().ship_instance_id, host.world.flight.get_rid(), origin, Vector3.RIGHT, float(profile.projectile_speed_mps), 500.0, damage, profile)
		if str(profile.fire_mode) == "projectile":
			check(hits.size() == before and shots.active.size() == 1, "projectile pays for a real flight before impact " + str(module.module_id))
			shots.simulate(1.0)
		else: check(shots.active.is_empty(), "ray weapon resolves without creating a flying projectile " + str(module.module_id))
		check(hits.size() == before + 1 and hits[-1].target == "combat-v18-sweep-target" and hits[-1].raw == damage, "actual collision delivers the weapon's single full damage vector " + str(module.module_id))
		shots.simulate(1.0)
		check(hits.size() == before + 1 and shots.active.is_empty(), "spent projectile cannot settle a second hit " + str(module.module_id))
	var count: int = hits.size()
	shots.fire("fixture-owner", RID(), origin, Vector3.LEFT, 1200.0, 40.0, Vector3.ONE, {"family_id": "kinetic", "fire_mode": "projectile"})
	shots.set_paused(true)
	var pose: Vector3 = shots.active[0].position
	shots.simulate(2.0)
	check(shots.active[0].position == pose and shots.has_pending(), "pause freezes real projectile position and preserves pending attacks")
	shots.set_paused(false); shots.simulate(2.0)
	check(shots.active.is_empty() and hits.size() == count, "unobstructed shot expires at its actual range without damage")
	body.queue_free()
	await get_tree().physics_frame; await get_tree().physics_frame

func _reset_sortie() -> void:
	var equipment: D.EquipmentStateDto = host.state.find("equipment_state", "item_instance_id", drone_item_id)
	equipment.enabled = true; equipment.cooldown_remaining_s = 0.0; equipment.active_remaining_s = 0.0; equipment.cycle_paid = false
	host.state.ship().energy = float(host.gameplay.metrics(host.state.ship()).energy_max)
	host.state.ship().heat = 0.0; host.state.ship().overheated = false
	enemy.alive = true; enemy.shield = 10000.0; enemy.armor = 10000.0; enemy.hull = 10000.0
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", enemy.spawn_id)
	await _preview_place(base, str(spawn.anchor_id))
	if not check(host.world.targets.has(enemy.npc_instance_id), "sortie reset projects the target in its declared spawn site"): return
	enemy_node = host.world.targets[enemy.npc_instance_id].node
	enemy_node.global_position = base + Vector3(0, 0, -650)
	enemy.pos_x = enemy_node.global_position.x; enemy.pos_y = enemy_node.global_position.y; enemy.pos_z = enemy_node.global_position.z
	host.auto_fire_target = enemy.npc_instance_id
	host.world.projectiles.set_paused(false)
	await get_tree().physics_frame; await get_tree().physics_frame

func _drain_sortie() -> void:
	for index: int in range(1500):
		if not host.world.projectiles.has_pending(): break
		host.world.projectiles.simulate(1.0 / 60.0)
		host._flush_damage()
		if index % 100 == 0: await get_tree().process_frame
	check(not host.world.projectiles.has_pending(), "finite sortie and independently fired bullets eventually reach a stable boundary")

func _drone_checks() -> void:
	var equipment: D.EquipmentStateDto = host.state.find("equipment_state", "item_instance_id", drone_item_id)
	var module: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment.module_def_id)
	var weapon: Dictionary = host.store.catalog.one("weapon_defs", "module_id", equipment.module_def_id)
	var definition: Dictionary = host.store.catalog.one("drone_defs", "module_id", equipment.module_def_id)
	await _reset_sortie()
	var before: int = hits.size()
	var shield: float = enemy.shield
	var energy: float = host.state.ship().energy
	_target_evidence("sortie-before-dispatch")
	host._tick_auto_fire()
	_target_evidence("sortie-after-dispatch")
	if not check(host.world.projectiles.drones.size() == int(definition.drone_count) and host.world.projectiles.active.is_empty(), "Main dispatches actual drone entities and no fake launch hit"): return
	check(enemy.shield == shield and hits.size() == before, "drone launch does not instantly damage the enemy")
	check(is_equal_approx(host.state.ship().energy, energy - float(module.energy_eu)) and is_equal_approx(host.state.ship().heat, float(module.heat_hu)), "drone sortie pays its real module energy and heat exactly once")
	check(not host._travel_stable() and host._save_block_reason() == "无人机出击或回收", "sortie blocks gate, local warp and stable persistence")
	equipment.cooldown_remaining_s = 0.0
	var paid_energy: float = host.state.ship().energy
	host._fire_weapons(true, enemy.npc_instance_id)
	check(is_equal_approx(host.state.ship().energy, paid_energy) and host.world.projectiles.drones.size() == int(definition.drone_count), "unreturned bay cannot pay again or launch duplicate drones even after cooldown")
	host.world.projectiles.set_paused(true)
	var first_pose: Vector3 = host.world.projectiles.drones[0].position
	host.world.projectiles.simulate(1.0)
	check(host.world.projectiles.drones[0].position == first_pose, "pause freezes drone flight and its sortie clocks")
	host.world.projectiles.set_paused(false)
	await _drain_sortie()
	var raw_total := Vector3.ZERO
	var target_hits: int = 0
	for index: int in range(before, hits.size()):
		if hits[index].target == enemy.npc_instance_id: raw_total += hits[index].raw; target_hits += 1
	check(target_hits == int(definition.drone_count) and is_equal_approx(raw_total.x, float(weapon.raw_damage)), "each drone fires one physical bullet and total paid damage is divided exactly once")
	check(enemy.shield < shield, "actual drone bullets settle authoritative NPC defenses")
	await _reset_sortie()
	host._tick_auto_fire()
	before = hits.size()
	for index: int in range(800):
		host.world.projectiles.simulate(1.0 / 60.0)
		if not host.world.projectiles.active.is_empty(): break
	check(not host.world.projectiles.active.is_empty(), "actual drone gun emits an independent in-flight projectile")
	var bullets: int = host.world.projectiles.active.size()
	host.world.projectiles.recall_drones()
	check(host.world.projectiles.active.size() == bullets and host.world.projectiles.has_pending(), "recall preserves already paid airborne bullets and the save barrier")
	await _drain_sortie()
	check(hits.size() > before, "already emitted drone bullets still settle their physical collision after recall")
	await _reset_sortie()
	# All-direction launch is tested against an enemy behind the mother ship.
	enemy_node.global_position = base + Vector3(0, 0, 650)
	await get_tree().physics_frame; await get_tree().physics_frame
	host._tick_auto_fire()
	check(host.world.projectiles.drones.size() == int(definition.drone_count), "drone automatic fire behind the ship bypasses the old global fixed-gun cone")
	before = hits.size()
	host.world.projectiles.recall_drones()
	await _drain_sortie()
	check(hits.size() == before, "recall disarms unfired drones without creating phantom damage")
	await _reset_sortie()
	host._tick_auto_fire()
	before = hits.size()
	equipment.enabled = false
	await _drain_sortie()
	check(hits.size() == before, "disabling the actual bay recalls its still-unfired drones")
	await _reset_sortie()
	host._tick_auto_fire()
	before = hits.size()
	enemy_node.global_position = base + Vector3(0, 0, -float(module.range_m) - 100)
	await _drain_sortie()
	check(hits.size() == before, "target beyond the bay's control range aborts an unpaid future hit")
	await _reset_sortie()
	host._tick_auto_fire()
	before = hits.size()
	host._request_save("manual", 1, "return_title")
	check(host._exit_save_pending() and host.world.projectiles.drones.all(func(drone: RefCounted) -> bool: return drone.returning), "exit save keeps pending entities but immediately disarms and recalls drones")
	host.deferred_save = {}; host.ui.set_operation_status("idle", "")
	await _drain_sortie()
	check(hits.size() == before, "exit recall never resolves a deleted sortie as a hit")

func _guard_signature() -> Dictionary:
	var rows: Dictionary = {}
	for table: String in State.TABLES:
		var encoded: Array[String] = []
		for row: RefCounted in host.state.rows(table): encoded.append(JSON.stringify(Codec.new().encode_row(table, row), "", true, true))
		encoded.sort()
		rows[table] = encoded
	return {"rows": rows, "snapshot": host.state.snapshot.meta.snapshot_id, "content": host.state.snapshot.content.content_snapshot_id, "save_count": int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)}

func _preview_place(point: Vector3, anchor_id: String, basis: Basis = Basis.IDENTITY) -> void:
	# A fixture explicitly adopts the selected station/gate/spawn context.
	# Local xyz alone cannot identify an astronomical location.
	if Space.supported(host.store.catalog):
		var site: String = Space.site_for_anchor(host.store.catalog, anchor_id)
		check(Space.assign(host.state, "ship", host.state.ship().ship_instance_id, site), "fixture player adopts explicit anchor site " + anchor_id)
	host.world.flight.global_transform = Transform3D(basis, point)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.get_global_transform_interpolated()
	host.world.flight.reset_physics_interpolation()
	host.world.refresh_site()
	check(host.world.sync_entities(), "fixture refreshes real scene visibility and NPC contexts " + anchor_id)
	await get_tree().physics_frame; await get_tree().physics_frame

func _gate_preview_evidence(endpoint_id: String, context: Dictionary, label: String) -> bool:
	var endpoint: Dictionary = host.store.catalog.one("gate_endpoint_defs", "endpoint_id", endpoint_id)
	var connection: Dictionary = host.store.catalog.one("effective_connection_defs", "connection_id", str(endpoint.connection_id))
	var gate: D.GateStateDto = host.state.find("gate_state", "connection_id", str(endpoint.connection_id))
	var cooldown: D.ShipGateCooldownStateDto = host.state.find("ship_gate_cooldown_state", "ship_instance_id", host.state.ship().ship_instance_id)
	var mass: float = float(host.gameplay.metrics(host.state.ship()).total_mass_kg)
	var node: Node3D = host.world.targets[endpoint_id].node
	var hostile: bool = false
	for npc: D.NpcStateDto in host.state.rows("npc_state"):
		if npc.alive and npc.behavior_phase in [T.NpcPhase.ACQUIRE, T.NpcPhase.PURSUE, T.NpcPhase.ATTACK, T.NpcPhase.DISENGAGE]: hostile = true
	var qualified: bool = host.state.ship().status == T.ShipStatus.FLYING and endpoint.origin_sector_id == host.state.current_sector() and host.state.find("unlock_state", "unlock_id", str(endpoint.required_unlock_id)) != null and gate != null and gate.enabled and (not gate.has_lifetime_remaining_s or gate.lifetime_remaining_s > 0.0) and (cooldown == null or cooldown.remaining_s <= 0.0) and mass <= float(connection.max_gross_mass_kg) and (not gate.has_remaining_mass_budget_kg or mass <= gate.remaining_mass_budget_kg) and host.state.ship().energy >= float(connection.energy_cost_eu) and host.state.player().credit >= int(connection.fee_credit) and bool(context.in_range) and float(context.speed_mps) <= float(context.max_speed_mps) and host.gameplay.save_eligible() and not hostile and str(node.get_meta("entity_id", "")) == endpoint_id
	print("COMBAT_V18_GATE_EVIDENCE " + JSON.stringify({"label": label, "context": context, "ship_id": host.state.ship().ship_instance_id, "ship_def": host.state.ship().ship_def_id, "ship_status": T.ShipStatus.keys()[int(host.state.ship().status)], "ship_sector": host.state.current_sector(), "endpoint": endpoint_id, "origin_sector": endpoint.origin_sector_id, "target_node_id": node.get_meta("entity_id", ""), "target_node_position": str(node.global_position), "required_unlock": endpoint.required_unlock_id, "unlocked": host.state.find("unlock_state", "unlock_id", str(endpoint.required_unlock_id)) != null, "gate_enabled": gate.enabled, "has_lifetime": gate.has_lifetime_remaining_s, "lifetime_s": gate.lifetime_remaining_s, "cooldown_s": cooldown.remaining_s if cooldown != null else 0.0, "gross_mass_kg": mass, "max_gross_mass_kg": connection.max_gross_mass_kg, "has_mass_budget": gate.has_remaining_mass_budget_kg, "mass_budget_kg": gate.remaining_mass_budget_kg, "energy": host.state.ship().energy, "energy_cost": connection.energy_cost_eu, "credit": host.state.player().credit, "fee_credit": connection.fee_credit, "save_eligible": host.gameplay.save_eligible(), "hostile_phase": hostile, "active_bullets": host.world.projectiles.active.size(), "returning_drones": host.world.projectiles.drones.size(), "qualified_except_pending": qualified}))
	return qualified

func _pending_preview_checks() -> void:
	await _reset_sortie()
	host._tick_auto_fire()
	var shots: XJProjectiles = host.world.projectiles
	var definition: Dictionary = host.store.catalog.one("drone_defs", "module_id", "module_drone_swarm_i")
	if not check(shots.drones.size() == int(definition.drone_count), "preview fixture begins with the real paid drone wing"): return
	# Actual flight moves the wing outside its docking radius before recall.
	# Main callbacks remain disabled so later previews cannot race a simulation.
	for index: int in range(40): shots.simulate(1.0 / 60.0)
	shots.recall_drones()
	host.auto_fire_target = ""
	host.gameplay.combat_remaining_s = 0.0
	for equipment: D.EquipmentStateDto in host.gameplay.equipped(host.state.ship()):
		equipment.active_remaining_s = 0.0; equipment.cycle_paid = false
	if not check(shots.active.is_empty() and not shots.drones.is_empty() and shots.drones.all(func(drone: RefCounted) -> bool: return drone.returning) and host.gameplay.save_eligible(), "real returning drones alone remain pending after combat and paid-period fixture clocks end"): return
	var station_id: String = "station_anchor_port"
	var station: Dictionary = host.store.catalog.one("station_defs", "station_id", station_id)
	var station_point: Vector3 = host.world.anchor_position(str(station.station_anchor_id)) + Vector3.BACK * float(host.store.catalog.rule("dock_radius_m")) * 0.75
	await _preview_place(station_point, str(station.station_anchor_id))
	if not check(host.local_navigation._landing_clear(station_point), "station witness uses actual unobstructed hull geometry inside dock distance"): return
	var interaction: Dictionary = host.interaction_context(station_id)
	var navigation: Dictionary = host.navigation_context(station_id)
	check(bool(interaction.in_range) and float(interaction.speed_mps) <= float(interaction.max_speed_mps) and not bool(interaction.ready) and str(interaction.reason) == "等待无人机回收", "nearby stopped station interaction denies returning drones with the precise reason")
	check(not bool(navigation.dock_ready) and str(navigation.dock_reason) == "等待无人机回收", "actual automatic-dock preview agrees with the returning-drone barrier")
	var before: Dictionary = _guard_signature()
	host._business_action("dock", station_id, 1, "")
	check(_guard_signature() == before and host.state.ship().status == T.ShipStatus.FLYING, "real station authority rejects pending drones without changing any persistent state")
	check(not host._navigation_command("dock", station_id) and not host.local_navigation.active() and _guard_signature() == before, "real automatic-dock command cannot start or mutate the refused preview")
	# The support hull exceeds the small tutorial gate's one-million-kg limit.
	# Its actual five-million-kg Anchor/Mirror route legally carries this hull.
	var endpoint_id: String = "endpoint_anchor_mirror"
	var endpoint: Dictionary = host.store.catalog.one("gate_endpoint_defs", "endpoint_id", endpoint_id)
	var gate_node: Node3D = host.world.targets[endpoint_id].node
	var gate_point: Vector3 = host.world.anchor_position(str(endpoint.entry_anchor_id)) + gate_node.global_basis.z * float(host.store.catalog.rule("gate_entry_radius_m")) * 0.9
	await _preview_place(gate_point, str(endpoint.entry_anchor_id), gate_node.global_basis)
	if not check(host.local_navigation._landing_clear(gate_point), "gate witness uses actual clear hull geometry inside entry distance"): return
	interaction = host.interaction_context(endpoint_id)
	if not check(_gate_preview_evidence(endpoint_id, interaction, "returning-wing"), "gate fixture satisfies every real range, speed, mass, budget, unlock, cost and world-state requirement except returning drones"): return
	check(bool(interaction.in_range) and float(interaction.speed_mps) <= float(interaction.max_speed_mps) and not bool(interaction.ready) and str(interaction.reason) == "等待无人机回收", "stopped unlocked nearby gate preview rejects returning drones even with no flying bullets")
	before = _guard_signature()
	check(not host.travel.begin(endpoint_id) and not host.travel.active() and _guard_signature() == before, "real gate authority rejects pending drones without payment, transfer or SQL state")
	await _drain_sortie()
	interaction = host.interaction_context(endpoint_id)
	check(_gate_preview_evidence(endpoint_id, interaction, "recovered-wing") and bool(interaction.ready), "same legitimate gate becomes ready after only the transient drone barrier ends")
	await _preview_place(station_point, str(station.station_anchor_id))
	check(bool(host.interaction_context(station_id).ready) and bool(host.navigation_context(station_id).dock_ready), "same nearby station and automatic-dock previews become ready after recovery")
	# Restore the isolated player's pose for the persistence fixture's cleanup.
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", enemy.spawn_id)
	await _preview_place(base, str(spawn.anchor_id))

func _persistence_check() -> void:
	# Remove the deliberately durable target before saving any state fixture.
	host.state.remove("npc_state", enemy)
	Space.remove(host.state, "npc", enemy.npc_instance_id)
	host.world.sync_entities()
	host.pending_damage.clear()
	host.gameplay.combat_remaining_s = 0.0
	for equipment: D.EquipmentStateDto in host.state.rows("equipment_state"):
		equipment.cooldown_remaining_s = 0.0; equipment.active_remaining_s = 0.0; equipment.cycle_paid = false
	check(host._travel_stable(), "finished and cleaned physical fixture permits a true stable snapshot")
	var validator := Validation.new()
	check(validator.validate(host.state, host.store.catalog), "restored production-size state validates before SQLite save")
	check(host.store.save(host.state, "manual", 0), "actual SQLite seals the support hull and real drone bay after recovery")
	var selections: Array[Dictionary] = host.store.list_slots().filter(func(slot: Dictionary) -> bool: return slot.slot_kind == "manual" and int(slot.slot_index) == 0)
	if not check(not selections.is_empty(), "saved manual slot is actually published"): return
	var loaded: XJRuntimeState = host.store.load(str(selections[0].slot_id))
	check(loaded != null and loaded.find("equipment_state", "item_instance_id", drone_item_id) != null, "real frozen SQLite reload preserves the installed drone bay")

func _finish() -> void:
	if host != null:
		host.queue_free()
		await _frames()
	print("COMBAT_V18_FINAL_JSON " + JSON.stringify({"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "database_path": database_path, "failure_labels": failures}))
	print("COMBAT_V18_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
