extends SceneTree
## Actual immutable physics wrappers: nine ships at 500 m around every station.
## This fixture never saves its altered ship definitions or touches player progress.
const Store = preload("res://runtime/data/store.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Sector = preload("res://runtime/sector.gd")
const Navigation = preload("res://runtime/local_navigation.gd")
const RuleBook = preload("res://runtime/local_navigation_rules.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): print("LOCAL_NAV_GEOMETRY FAIL timeout"); quit(1))
	call_deferred("_run")
func check(value: bool, title: String) -> void:
	checks += 1
	if not value: failures.append(title); print("FAIL ", title)
func _run() -> void:
	var rulebook: RuleBook = RuleBook.new()
	check(rulebook.load_rules(), "real SQLite v1 rules load")
	if not rulebook.loaded: quit(1); return
	var invalid: RuleBook = RuleBook.new()
	invalid.path = "res://data/nonexistent_local_navigation_test.db"
	check(not invalid.load_rules() and not invalid.loaded and not invalid.last_error.is_empty(), "missing rules explicitly disable feature")
	var store: Store = Store.new(ProjectSettings.globalize_path("res://../jiaoben/tmp/local-navigation-geometry-%d.db" % Time.get_ticks_usec()))
	check(store.open(), "isolated actual Store opens")
	var state: XJRuntimeState = store.new_world("站外落点碰撞夹具", 16)
	check(state != null, "fresh sealed world initialized")
	if state == null: store.close(); quit(1); return
	state.ship().status = T.ShipStatus.FLYING
	state.ship().has_station_id = false
	state.ship().station_id = ""
	state.player().has_docked_station_id = false
	state.player().docked_station_id = ""
	var radius: float = float(rulebook.target("station").warp_arrival_m)
	for station: Dictionary in store.catalog.rows("station_defs"):
		state.ship().sector_id = station.sector_id
		for ship: Dictionary in store.catalog.rows("ship_defs"):
			state.ship().ship_def_id = ship.ship_id
			state.ship().pos_x = 0.0; state.ship().pos_y = 0.0; state.ship().pos_z = -2000.0
			var business: Gameplay = Gameplay.new()
			business.setup(state, store.catalog)
			var world: Sector = Sector.new()
			root.add_child(world)
			check(world.build(state, store.catalog, business), "actual world model/collider builds " + str(station.station_id) + "/" + str(ship.ship_id))
			await physics_frame
			await process_frame
			var controller: Navigation = Navigation.new()
			check(controller.configure(world, state, store.catalog, business), "controller reads fixed v1 rules " + str(ship.ship_id))
			var target: Node3D = world.targets[station.station_id].node
			for x: int in [-1, 0, 1]:
				for y: int in [-1, 0, 1]:
					for z: int in [-1, 0, 1]:
						if x == 0 and y == 0 and z == 0: continue
						var direction: Vector3 = Vector3(x, y, z).normalized()
						var point: Vector3 = target.global_position + direction * radius
						world.flight.quaternion = Quaternion.from_euler(Vector3(0.31, 0.67, -0.22))
						check(controller._landing_clear(point), "safe full-3D station arrival " + str(station.station_id) + "/" + str(ship.ship_id) + "/" + str(direction))
			check(controller.inspect(str(station.station_id)).warp_ready, "station warp available through actual target inspection")
			controller.begin("warp", str(station.station_id))
			var initial_attitude: Quaternion = world.flight.quaternion
			controller.tick(1.0 / 60.0)
			check(initial_attitude.angle_to(world.flight.quaternion) <= float(world.flight.metrics.turn_radps) / 60.0 + 0.0001 and world.flight.global_position.is_equal_approx(controller.origin), "warmup respects ship turn rate and does not move")
			controller.tick(rulebook.value("warmup_s") + PI / float(world.flight.metrics.turn_radps))
			controller.tick(1.0)
			check(controller.phase == "arrived" and state.ship().status == T.ShipStatus.FLYING and not state.player().has_docked_station_id, "warp arrival stops outside without docking")
			check(is_equal_approx(world.flight.global_position.distance_to(target.global_position), radius) and world.flight.velocity.is_zero_approx(), "warp arrival is exact safe station radius and zero velocity")
			world.flight.global_position = controller.origin
			world.flight.write_back()
			controller.begin("warp", str(station.station_id))
			controller.tick(rulebook.value("warmup_s") + PI / float(world.flight.metrics.turn_radps))
			world.flight.global_position = target.global_position
			world.flight.velocity = Vector3(10.0, 0.0, 0.0)
			world.flight.write_back()
			controller.cancel()
			check(not controller.active() and controller._landing_clear(world.flight.global_position) and world.flight.global_position.is_equal_approx(controller.origin) and world.flight.velocity.is_zero_approx(), "cancel inside station returns to a live-tested clear sample")
			world.free()
			business.dispose()
			await physics_frame
	store.close()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	print("LOCAL_NAV_GEOMETRY ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
