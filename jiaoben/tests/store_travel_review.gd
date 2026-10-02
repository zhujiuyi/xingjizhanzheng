extends SceneTree
## Independent travel-controller/SQL acceptance, without substituting 3D QA.
const Store = preload("res://runtime/data/store.gd")
const State = preload("res://runtime/state.gd")
const Travel = preload("res://runtime/travel.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []
class FaultStore extends Store:
	var fault_reason: String = ""
	func _checkpoint(point: String) -> bool:
		if point != "state" or fault_reason.is_empty(): return true
		return _records("SELECT reason FROM save_snapshot ORDER BY rowid DESC LIMIT 1")[0].reason != fault_reason
func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
func _initialize() -> void:
	for scenario in ["cancel", "origin_failure", "prepare_failure", "destination_failure", "success"]:
		var path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/store-travel-" + scenario + ".db")
		DirAccess.remove_absolute(path)
		var store: FaultStore = FaultStore.new(path)
		check(store.open(), scenario + " native store")
		var state: State = store.new_world("独立跨区事务审阅", 42)
		if state == null:
			check(false, scenario + " initial world " + store.last_error)
			store.close()
			continue
		var endpoint: Dictionary = {}
		var connection: Dictionary = {}
		for row in store.catalog.rows("gate_endpoint_defs"):
			var candidate: Dictionary = store.catalog.one("effective_connection_defs", "connection_id", row.connection_id)
			if candidate.fee_credit > 0 and candidate.energy_cost_eu > 0:
				endpoint = row
				connection = candidate
				break
		check(not endpoint.is_empty(), scenario + " nonzero-cost reviewed gate exists")
		if endpoint.is_empty():
			store.close()
			continue
		var ship = state.ship()
		ship.status = T.ShipStatus.FLYING
		ship.has_station_id = false
		ship.station_id = ""
		ship.sector_id = endpoint.origin_sector_id
		state.player().has_docked_station_id = false
		state.player().docked_station_id = ""
		var entry: Dictionary = store.catalog.one("anchor_defs", "anchor_id", endpoint.entry_anchor_id)
		ship.pos_x = entry.x_m; ship.pos_y = entry.y_m; ship.pos_z = entry.z_m
		for container in state.rows("container_state"):
			if container.ship_instance_id == ship.ship_instance_id: container.sector_id = ship.sector_id
		if state.find("unlock_state", "unlock_id", endpoint.required_unlock_id) == null:
			var unlock: D.UnlockStateDto = D.UnlockStateDto.new()
			unlock.player_id = state.player().player_id; unlock.unlock_id = endpoint.required_unlock_id
			state.add("unlock_state", unlock)
		state.find("gate_state", "connection_id", endpoint.connection_id).enabled = true
		check(store.save(state), scenario + " fixture stable pre-travel snapshot " + store.last_error)
		var old_id: String = state.snapshot.meta.snapshot_id
		var credit: int = state.player().credit
		var energy: float = ship.energy
		var origin_sector: String = ship.sector_id
		var travel: Travel = Travel.new()
		travel.setup(state, store, func(_candidate: State) -> bool: return scenario != "prepare_failure", Callable(), func() -> bool: return true)
		check(travel.begin(endpoint.endpoint_id), scenario + " legal charge " + travel.last_error)
		if scenario == "cancel":
			check(travel.cancel(), "cancel charge succeeds")
		else:
			store.fault_reason = "travel_origin" if scenario == "origin_failure" else ("travel_destination" if scenario == "destination_failure" else "")
			travel.tick(travel.remaining_s + 0.01)
		check(not travel.active(), scenario + " controller leaves active transition")
		if scenario != "success":
			check(state.current_sector() == origin_sector and state.player().credit == credit and state.ship().energy == energy, scenario + " original position/cost remain atomic")
			check(store._records("SELECT transfer_barrier_id FROM runtime_session")[0].transfer_barrier_id == null, scenario + " barrier released")
			var expected: String = old_id if scenario in ["cancel", "origin_failure"] else state.snapshot.meta.snapshot_id
			check(store.list_slots()[0].current_snapshot_id == expected, scenario + " durable origin endpoint retained")
			check(travel.ready_candidate == null, scenario + " failed candidate cannot activate")
		else:
			var arrived: State = travel.ready_candidate
			check(arrived != null and arrived.current_sector() == endpoint.target_sector_id, "successful destination state ready")
			check(arrived.player().credit == credit - int(connection.fee_credit) and arrived.ship().energy == energy - float(connection.energy_cost_eu), "cost deducted exactly once in destination")
			check(not store.save(state), "old origin callback rejected before SQL at stale capture sequence")
			var committed: String = arrived.snapshot.meta.snapshot_id
			travel.tick(1.0)
			check(arrived.snapshot.meta.snapshot_id == committed and arrived.player().credit == credit - int(connection.fee_credit), "completed transition cannot deduct again")
			store.close()
			check(store.open(), "destination database reopens")
			var resumed: State = store.resume()
			check(resumed != null and resumed.current_sector() == endpoint.target_sector_id and resumed.player().credit == arrived.player().credit, "restart restores full charged destination endpoint")
		store.close()
	print("STORE_TRAVEL_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
