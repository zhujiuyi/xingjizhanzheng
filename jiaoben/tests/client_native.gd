extends SceneTree
const Main = preload("res://runtime/main.gd")
const Types = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var database_path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/client-native.db")
	DirAccess.remove_absolute(database_path)
	var host := Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	await process_frame
	check(host.services_ready, "real client starts with database service " + host.last_error)
	if not host.services_ready:
		quit(1)
		return
	await host._command("new_world", "完整客户端原生验收", 1, "")
	check(host.state != null and host.world != null, "new world assembles scene and typed state")
	if host.state == null:
		quit(1)
		return
	check(host.world.flight.get_node_or_null("CollisionShape3D") != null, "formal ship collision exists")
	check(host.world.targets.size() > 0, "station gates signals projected from database anchors")
	for page in ["station", "ships", "warehouse", "fitting", "market", "industry", "missions", "research", "map", "pause"]:
		host.ui.show_page(page)
		await process_frame
		check(host.ui.page == page and host.ui.body.get_child_count() > 0, "page " + page + " constructs actual controls")
	host.ui.show_page("pause")
	var tick: int = host.state.snapshot.meta.simulation_tick
	await physics_frame
	await physics_frame
	check(host.state.snapshot.meta.simulation_tick == tick, "pause freezes simulation time")
	host._business_action("accept_mission", "tutorial_flight", 1, "")
	while host.busy: await process_frame
	host._business_action("undock", "", 1, "")
	while host.busy: await process_frame
	check(host.state.ship().status == Types.ShipStatus.FLYING, "station undock authoritative action")
	host.ui.show_page("pause")
	var flight := host.world.flight
	flight.metrics = host.gameplay.metrics(host.state.ship())
	flight.record.energy = 0.0
	flight.intent.thrust_z = 1.0
	var initial := flight.position
	for frame in range(60): flight.simulate(1.0 / 60.0)
	check(flight.position.distance_to(initial) > 1.0 and flight.velocity.length() > 0.0, "zero capacitor still supports basic propulsion")
	flight.intent.thrust_z = 0.0
	flight.intent.brake_requested = true
	for frame in range(180): flight.simulate(1.0 / 60.0)
	check(flight.velocity.length() < 0.01, "basic brake stops moving ship")
	var quaternion_before := flight.quaternion
	host.camera.observe(Vector2(200.0, 50.0), 0.002)
	host.camera.step(1.0 / 60.0)
	check(flight.quaternion.is_equal_approx(quaternion_before), "free camera observation cannot rotate ship")
	var position_before := flight.position
	check(host.store.save(host.state, "manual", 0), "real world snapshot commits " + host.store.last_error)
	var slot: Dictionary = {}
	for row in host.store.list_slots():
		if row.slot_kind == "manual" and row.slot_index == 0:
			slot = row
			break
	var previous_epoch: int = host.state.epoch
	await host._command("load", slot.slot_id, slot.generation, slot.current_snapshot_id)
	check(host.state.epoch > previous_epoch and host.world.flight.position.is_equal_approx(position_before), "load stages and swaps full world at new epoch")
	# Infrastructure travel test positions a legitimate ship at each configured
	# entrance; gameplay progression itself is tested independently without grants.
	for unlock in host.store.catalog.rows("unlock_defs"):
		host.gameplay.grant_unlock(unlock.unlock_id)
	host.state.player().credit = 100000
	var visited: Dictionary = {host.state.current_sector(): true}
	for endpoint in host.store.catalog.rows("gate_endpoint_defs"):
		if endpoint.origin_sector_id != "sector_anchor" or endpoint.target_sector_id != "sector_echo": continue
		var gate: RefCounted = host.state.find("gate_state", "connection_id", endpoint.connection_id)
		gate.enabled = true
		var entry: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", endpoint.entry_anchor_id)
		host.state.ship().pos_x = entry.x_m
		host.state.ship().pos_y = entry.y_m
		host.state.ship().pos_z = entry.z_m
		host.state.ship().energy = host.gameplay.metrics(host.state.ship()).energy_max
		host.world.flight.bind(host.state.ship(), host.store.catalog)
		var origin: String = host.state.current_sector()
		check(host.travel.begin(endpoint.endpoint_id), "legal entrance starts charge " + host.travel.last_error)
		host.travel.tick(float(host.travel.remaining_s) + 0.01)
		check(host.state.current_sector() == endpoint.target_sector_id and host.state.current_sector() != origin, "destination COMMIT activates actual new scene")
		check(host.state.snapshot.meta.reason == "travel_destination", "arrival snapshot is durable destination boundary")
		var transfer: RefCounted = host.state.rows("transfer_state")[-1]
		check(transfer.endpoint == Types.TransferEndpoint.DESTINATION, "transfer receipt and arrival state share destination snapshot")
		check(host.world.targets.size() > 0, "new sector builds station ore gates and signals")
		visited[host.state.current_sector()] = true
		break
	for sector_def in host.store.catalog.rows("sector_defs"):
		var candidate: RefCounted = host.store.clone_state(host.state)
		candidate.ship().sector_id = sector_def.sector_id
		for container in candidate.rows("container_state"):
			if container.ship_instance_id == candidate.ship().ship_instance_id: container.sector_id = sector_def.sector_id
		check(host._stage_candidate(candidate, host.store.catalog), "configured full-content sector assembles " + sector_def.sector_id)
		host._discard_staged()
	host.queue_free()
	await process_frame
	print("CLIENT_NATIVE_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
