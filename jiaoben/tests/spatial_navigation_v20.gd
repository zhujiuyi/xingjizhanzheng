extends Node
## Real Main/navigation/SQLite and physics sites. No personal progress is opened.
const Main = preload("res://runtime/main.gd")
const Space = preload("res://runtime/space_coordinates.gd")
const T = preload("res://contracts/contract_types.gd")
class UnavailableEnemyFactory extends RefCounted:
	static func enemy_scene(_archetype: String) -> CharacterBody3D:
		return null
var host: Main
var directory: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func _ready() -> void:
	get_tree().set_meta("xj_spatial_navigation_v20_diagnostic", true)
	_run.call_deferred()

func _run() -> void:
	directory = OS.get_environment("XJ_SPATIAL_NAVIGATION_V20_DIRECTORY").replace("\\", "/")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/spatial-navigation-v20/" + XJGameStore.new_id("run"))
	if not directory.is_absolute_path() or not directory.contains("/jiaoben/tmp/spatial-navigation-v20/") or directory.contains("..") or FileAccess.file_exists(directory.path_join("progress.db")):
		check(false, "fresh test-owned directory required"); await finish(); return
	DirAccess.make_dir_recursive_absolute(directory)
	host = Main.new()
	host.progress_database_path = directory.path_join("progress.db")
	add_child(host)
	await frames()
	if not check(host.services_ready, "real Main services ready"): await finish(); return
	await host._command("new_world", "空间导航验证", 1, "")
	await frames()
	if not check(host.state != null, "new world committed"): await finish(); return
	host.set_physics_process(false)
	host.set_process(false)
	host._business_action("undock", "", 1, "")
	await frames()
	check(host.state.ship().status == T.ShipStatus.FLYING, "real undock retains station site")
	check(host.local_navigation.rules.version == 2, "new frozen world selects v2 rules")
	check(host.local_navigation.rules.value("min_warp_distance_m") == 150000.0, "minimum actual trip is 150 km")
	check(XJSpaceUnits.distance(650.0) == "650 m" and XJSpaceUnits.distance(150000.0) == "150 km" and XJSpaceUnits.distance(XJSpaceUnits.METRES_PER_AU) == "1.00 AU", "distance formatting uses actual m/km/AU")
	check(XJSpaceUnits.distance(XJSpaceUnits.METRES_PER_AU * 0.0009).ends_with("km") and XJSpaceUnits.distance(INF) == "—", "small AU and unknown distances never become zero AU")
	var station_id: String = "station_anchor"
	for row: Dictionary in host.store.catalog.rows("station_defs"):
		if row.sector_id == host.state.current_sector(): station_id = str(row.station_id); break
	var station_entry: Dictionary = host.world.targets[station_id]
	var station_anchor: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", station_entry.anchor_id)
	var station_site: String = Space.current_site(host.state)
	place(host.world.anchor_position(station_entry.anchor_id) + Vector3(0, 0, 510), station_site)
	await frames()
	var near: Dictionary = host.local_navigation.inspect(station_id)
	check(not near.warp_ready and float(near.warp_distance_m) < 20.0 and near.approach_ready, "centre distance cannot authorize ten-metre station warp")
	var minimum: float = host.local_navigation.rules.value("min_warp_distance_m")
	place(host.world.anchor_position(station_entry.anchor_id) + Vector3(0, 0, minimum + 499), station_site)
	await frames()
	check(not host.local_navigation.inspect(station_id).warp_ready, "actual landing trip just below threshold refused")
	place(host.world.anchor_position(station_entry.anchor_id) + Vector3(0, 0, minimum + 500), station_site)
	await frames()
	check(host.local_navigation.inspect(station_id).warp_ready, "exact threshold is inclusive")
	place(host.world.anchor_position(station_entry.anchor_id) + Vector3(0, 0, 650), station_site)
	await frames()
	var remote: String = ""
	for id: String in host.world.targets:
		if host.world.targets[id].kind == "resource" and not host.world.target_is_local(id): remote = id; break
	if not check(not remote.is_empty(), "formal sector has remote resource site"): await finish(); return
	var context: Dictionary = host.local_navigation.inspect(remote)
	check(context.warp_ready and context.remote_site and context.distance_m > XJSpaceUnits.METRES_PER_AU * 0.001, "formal route has real astronomical distance and legal warp")
	check(not host.world.targets[remote].node.visible and host.world.targets[remote].node.collision_layer == 0, "remote resource has no local mesh or collision")
	check(not host.interaction_context(remote).ready, "remote projected coordinate cannot permit local interaction")
	check(not host.local_navigation.inspect(remote).orbit_ready, "remote orbit requires arrival")
	var start: Vector3 = host.world.flight.position
	var before_slots: Array = host.store.list_slots()
	if not check(host._navigation_command("warp", remote), "production command commits origin before accepting warp"): await finish(); return
	check(host.local_navigation.phase == "warmup" and host.world.flight.position == start and host.store.list_slots().size() >= before_slots.size(), "warmup remains at saved origin")
	var cooldowns: Array[float] = []
	for equipment in host.state.rows("equipment_state"): cooldowns.append(equipment.cooldown_remaining_s)
	var paid_energy: float = host.state.ship().energy
	host._request_engine_cycle()
	var after_cooldowns: Array[float] = []
	for equipment in host.state.rows("equipment_state"): after_cooldowns.append(equipment.cooldown_remaining_s)
	check(cooldowns == after_cooldowns and host.state.ship().energy == paid_energy, "boost cannot charge a conflicting engine cycle during warp")
	await advance_to_travel()
	check(host.local_navigation.phase == "travel" and host.local_navigation.travel_duration_s >= 3.0, "real travel duration is at least three seconds")
	var frozen_elapsed: float = host.local_navigation.travel_elapsed_s
	host.ui.show_page("pause")
	host._physics_process(1.0)
	host._process(1.0)
	check(host.local_navigation.travel_elapsed_s == frozen_elapsed and host.world.flight.position == start, "pause freezes route and physical ship")
	host.ui.show_page("")
	host._physics_process(0.4)
	host._process(0.4)
	check(host.world.flight.position == start and not host.world.strategic_render_position.is_empty(), "strategic travel advances scalars while local physics retains precision")
	check(float(host.navigation_context(remote).display_speed_mps) > 1000000000.0, "HUD reads actual strategic speed")
	if DisplayServer.get_name() != "headless":
		await capture("route-travel")
	host.local_navigation.stop()
	await frames()
	check(Space.current_site(host.state) == station_site and host.world.flight.position == start and host.world.flight.velocity == Vector3.ZERO and host.world.strategic_render_position.is_empty(), "cancel restores durable departure site and zero velocity")
	check(host.world.targets[station_id].node.collision_layer != 0 and host.world.targets[remote].node.collision_layer == 0, "cancel restores site collision ownership")
	check(host._navigation_command("warp", remote), "occupied-origin recovery uses another real route")
	await advance_to_travel()
	var obstruction := StaticBody3D.new()
	obstruction.collision_layer = 1
	var obstacle_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 100.0
	obstacle_shape.shape = sphere
	obstruction.add_child(obstacle_shape)
	host.world.add_child(obstruction)
	obstruction.position = start
	await frames(4)
	host.local_navigation.stop()
	check(Space.current_site(host.state) == station_site and host.world.flight.position.distance_to(start) > 100.0 and host.world.flight.position.distance_to(start) < 600.0, "occupied departure searches nearby clear local space without using another site's encoded destination")
	obstruction.queue_free()
	await frames(4)
	place(start, station_site)
	# A prospective site can fail construction after context/pose preparation.
	# The real controller must recover all authorities to the durable departure.
	for unlock: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.call("grant_unlock", unlock.unlock_id)
	host.gameplay.call("_sync_spawns")
	host.world.sync_entities()
	await frames()
	var encounter: String = ""
	for id: String in host.world.targets:
		if host.world.targets[id].kind == "encounter" and not host.world.target_is_local(id): encounter = id; break
	check(not encounter.is_empty(), "formal remote encounter exists for construction-failure fixture")
	if not encounter.is_empty():
		check(host._navigation_command("warp", encounter), "failed-site test uses production saved navigation command")
		await advance_to_travel()
		var original_factory: Script = host.world.factory
		host.world.factory = UnavailableEnemyFactory
		await complete_route()
		host.world.factory = original_factory
		host.world.sync_entities()
		check(host.local_navigation.phase == "failed" and Space.current_site(host.state) == station_site and host.world.flight.position == start, "destination construction failure restores departure site and pose")
		check(host.world.collision_site_id == station_site and host.world.targets[station_id].node.visible and host.world.targets[station_id].node.collision_layer != 0, "failed construction restores visibility and collision ownership")
	check(host._navigation_command("warp", remote), "restart same formal route")
	await advance_to_travel()
	await complete_route()
	check(host.local_navigation.phase == "arrived" and host.world.target_is_local(remote), "formal route changes physical site only after arrival clearance")
	check(host.world.flight.position.distance_to(host.world.targets[remote].node.position) < 181.0 and host.world.flight.position.length() < 20000.0, "arrival preserves metre precision without AU Vector3")
	check(host.world.targets[remote].node.visible and host.world.targets[remote].node.collision_layer != 0 and not host.world.targets[station_id].node.visible, "only arrival site meshes and colliders active")
	await frames()
	check(host._navigation_command("dock", station_id), "remote dock command starts saved warp-to-station chain")
	await advance_to_travel()
	await complete_route()
	for index: int in range(300):
		if not host.local_navigation.active(): break
		host._physics_process(1.0 / 60.0)
		if index % 20 == 0: await frames(2)
	await frames(6)
	check(host.state.ship().status == T.ShipStatus.DOCKED and Space.current_site(host.state) == station_site, "remote dock chain ends in real business docking")
	check(host.store.save(host.state, "manual", 4), "new spatial snapshot commits to SQLite")
	var slot_id: String = ""
	for slot: Dictionary in host.store.list_slots():
		if slot.slot_kind == "manual" and int(slot.slot_index) == 4: slot_id = slot.slot_id
	var loaded: XJRuntimeState = host.store.load(slot_id)
	check(loaded != null and Space.current_site(loaded) == station_site and loaded.ship().status == T.ShipStatus.DOCKED, "SQLite reopen retains site and exact docked state")
	await finish()

func place(position: Vector3, site_id: String) -> void:
	Space.assign(host.state, "ship", host.state.ship().ship_instance_id, site_id)
	host.world.strategic_render_position = {}
	host.world.flight.position = position
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.refresh_site()
	host.world.sync_entities()
	host.world.flight.reset_physics_interpolation()

func advance_to_travel() -> void:
	for index: int in range(2400):
		if host.local_navigation.phase != "warmup": break
		host._physics_process(1.0 / 60.0)
		if index % 30 == 0: await frames(2)
	await frames(3)

func complete_route() -> void:
	for index: int in range(100):
		if host.local_navigation.phase not in ["travel", "arrival_check"]: break
		host._physics_process(0.5 if host.local_navigation.phase == "travel" else 1.0 / 60.0)
		host._process(0.016)
		await frames(2)
	await frames(5)

func capture(label: String) -> void:
	host._process(0.05)
	await frames(4)
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	check(picture != null and not picture.is_empty() and picture.save_png(directory.path_join(label + ".png")) == OK, "native screenshot " + label)
	captures += 1

func finish() -> void:
	var result := {"schema": 1, "checks": checks, "passed": checks - failures.size(), "result": "PASS" if failures.is_empty() else "FAIL", "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory, "renderer": str(RenderingServer.get_current_rendering_method()), "display": DisplayServer.get_name()}
	FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("SPATIAL_NAVIGATION_V20_FINAL_JSON " + JSON.stringify(result))
	print("SPATIAL_NAVIGATION_V20_RESULT %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	if is_instance_valid(host):
		host.set_process(false); host.set_physics_process(false)
		if host.gameplay != null: host.gameplay.call("dispose")
		if host.store != null: host.store.close()
		host.queue_free()
	await frames(5)
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
