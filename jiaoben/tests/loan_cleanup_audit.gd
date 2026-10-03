extends SceneTree
## Uses a closed gameplay_probe business fixture copied to a unique scratch DB.
## Positions, hit damage and the expiry's remaining second are explicit fixtures.
## Real loan/ordinary purchase/salvage/Travel/dock/save/load actions remain authoritative.
const G = preload("res://runtime/gameplay.gd")
const Store = preload("res://runtime/data/store.gd")
const Travel = preload("res://runtime/travel.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: int = 0
var g: G
var store: Store
var scratch: String

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1; push_error(label)
	return ok

func action(kind: String, target: String = "", quantity: int = 1, extra: String = "") -> bool:
	var result: D.ActionResultDto = g.act(kind, target, quantity, extra)
	return expect(result.phase == T.ActionPhase.APPLIED, kind + " " + target + ": " + result.display_reason_key)

func rejected(kind: String, target: String) -> void:
	var result: D.ActionResultDto = g.act(kind, target)
	expect(result.phase != T.ActionPhase.APPLIED, "pending/loan restriction " + kind + " " + target)

func at_anchor(anchor_id: String) -> void:
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", anchor_id)
	expect(str(anchor.sector_id) == g.state.current_sector(), "spatial fixture stays in current sector")
	g.state.ship().pos_x = float(anchor.x_m); g.state.ship().pos_y = float(anchor.y_m); g.state.ship().pos_z = float(anchor.z_m)
	g.state.ship().vel_x = 0.0; g.state.ship().vel_y = 0.0; g.state.ship().vel_z = 0.0

func prepare(_state: XJRuntimeState) -> bool: return true

func arrived(state: XJRuntimeState, connection_id: String) -> void:
	var business: G = G.new(); business.setup(state, store.catalog)
	business.record_event("transit_connection", connection_id); business.dispose()

func cross(endpoint_id: String) -> bool:
	if g.state.ship().status == T.ShipStatus.DOCKED and not action("undock"): return false
	var endpoint: Dictionary = g.definition("gate_endpoint_defs", "endpoint_id", endpoint_id)
	var cooldown: D.ShipGateCooldownStateDto = g.state.find("ship_gate_cooldown_state", "ship_instance_id", g.state.ship().ship_instance_id)
	g.tick(maxf(cooldown.remaining_s if cooldown != null else 0.0, g.rule("combat_exit_delay_s")) + 1.0)
	at_anchor(str(endpoint.entry_anchor_id))
	var travel: Travel = Travel.new(); travel.setup(g.state, store, prepare, arrived)
	if not expect(travel.begin(endpoint_id), "real gate before/after cleanup: " + travel.last_error): return false
	travel.tick(float(travel.connection.prepare_s) + 0.1)
	if not expect(travel.ready_candidate != null, "durable gate arrival: " + travel.last_error): return false
	g.dispose(); g = G.new(); g.setup(travel.ready_candidate, store.catalog)
	return true

func dock(station_id: String) -> bool:
	if g.station() == station_id: return true
	var station: Dictionary = g.definition("station_defs", "station_id", station_id)
	g.tick(g.rule("combat_exit_delay_s") + 1.0)
	at_anchor(str(station.station_anchor_id))
	return action("dock", station_id)

func reopen(label: String) -> bool:
	if not expect(store.save(g.state, "manual", 0), "save " + label + ": " + store.last_error): return false
	var selected: Dictionary = {}
	for row: Dictionary in store.list_slots():
		if str(row.slot_kind) == "manual" and int(row.slot_index) == 0: selected = row
	g.dispose(); store.close(); store = Store.new(scratch)
	if not expect(store.open(), "reopen " + label): return false
	var loaded: XJRuntimeState = store.load(str(selected.slot_id), str(selected.current_snapshot_id), int(selected.generation))
	if not expect(loaded != null, "load " + label + ": " + store.last_error): return false
	g = G.new(); g.setup(loaded, store.catalog)
	return true

func episode(mission_id: String, service_id: String, expiry: bool) -> bool:
	if g.state.current_sector() == "sector_echo" and not cross("endpoint_echo_anchor"): return false
	if not dock("station_anchor_port"): return false
	g.tick(g.rule("contract_failure_retry_cooldown_s") + 1.0)
	if not action("accept_mission", mission_id) or not action("claim_loan", service_id): return false
	var loan: D.LoanStateDto = g.work._active_loan()
	var loan_id: String = loan.loan_id
	var ship_id: String = g.state.ship().ship_instance_id
	var attempt: String = g.missions.active().mission_instance_id
	var cargo: String = g.inventory.hold(g.state.ship(), T.ContainerKind.CARGO)
	if not action("buy_item", "ore_ferrosilicate", 3, cargo): return false
	rejected("sell_ship", ship_id)
	var equipment: D.EquipmentStateDto = g.equipped(g.state.ship())[0]
	var protected_item: String = equipment.item_instance_id
	var equipment_slot: D.ContainerStateDto = g.state.find("container_state", "container_id", equipment.slot_container_id)
	var fit_target: String = str(g.definition("module_defs", "module_id", equipment.module_def_id).slot_type) + ":" + str(equipment_slot.slot_index)
	if not action("unfit_module", protected_item): return false
	rejected("sell_item", protected_item); rejected("recycle", protected_item)
	expect(g.state.find("item_instance_state", "item_instance_id", protected_item).policy_id != "normal_owned", "unfit preserves loan binding")
	if not action("fit_module", protected_item, 1, fit_target): return false
	if not cross("endpoint_anchor_echo"): return false
	loan = g.state.find("loan_state", "loan_id", loan_id)
	var enemy: D.NpcStateDto
	for npc: D.NpcStateDto in g.state.rows("npc_state"):
		if npc.alive and npc.sector_id == "sector_echo" and g.encounters.handles(npc.spawn_id): enemy = npc; break
	if not expect(enemy != null, "actual encounter can create ordinary package"): return false
	g.damage_npc(enemy.npc_instance_id, Vector3(999999.0, 0.0, 0.0))
	var package: D.SalvagePackageStateDto
	for row: D.SalvagePackageStateDto in g.state.rows("salvage_package_state"):
		if row.source_npc_instance_id == enemy.npc_instance_id: package = row; break
	if not expect(package != null, "actual death freezes package reward"): return false
	g.state.ship().pos_x = enemy.pos_x; g.state.ship().pos_y = enemy.pos_y; g.state.ship().pos_z = enemy.pos_z
	if not action("pickup_wreck", package.host_container_id): return false
	var package_id: String = package.package_id
	var reward_id: String = package.reward_id
	expect(package.host_container_id == cargo, "ordinary sealed package aboard protected loan hull")
	var units: int = g.inventory.count(cargo, "ore_ferrosilicate", true)
	var quota: int = loan.quota_remaining_units
	var position: Vector3 = g.position(g.state.ship())
	g.tick(g.rule("combat_exit_delay_s") + 1.0)
	if expiry:
		g.missions.active().deadline_remaining_s = 1.0
		g.tick(2.0)
	else:
		if not action("abandon_mission", attempt): return false
	var ended: D.MissionStateDto = g.state.find("mission_state", "mission_instance_id", attempt)
	expect(ended.status == ("failed" if expiry else "abandoned") and not ended.reward_claimed, "termination records final attempt without rewards")
	expect(g.state.ship().ship_instance_id == ship_id and g.state.ship().status == T.ShipStatus.FLYING and g.state.current_sector() == "sector_echo" and not g.state.player().has_docked_station_id, "termination never teleports or replaces flying hull")
	expect(g.position(g.state.ship()).is_equal_approx(position), "termination preserves spatial location")
	expect(g.inventory.count(cargo, "ore_ferrosilicate", true) == units and package.host_container_id == cargo, "termination preserves ordinary cargo and package")
	expect(loan.quota_remaining_units == quota and g.missions.has_pending_loans(), "termination keeps bounded pending loan")
	rejected("deliver_mission", attempt); rejected("accept_mission", "contract_survey_echo"); rejected("claim_loan", service_id)
	expect(loan.quota_remaining_units == quota, "rejected loan issue does not restore gathering quota")
	if not reopen("pending " + mission_id): return false
	loan = g.state.find("loan_state", "loan_id", loan_id)
	package = g.state.find("salvage_package_state", "package_id", package_id)
	expect(g.missions.has_pending_loans() and loan.current_ship_id == ship_id and package.reward_id == reward_id, "pending loan/cargo/reward survive SQLite reopen")
	var warehouse: String = g.inventory.warehouse("station_echo_depot")
	var previous_units: int = g.inventory.count(warehouse, "ore_ferrosilicate", true)
	if not dock("station_echo_depot"): return false
	expect(not g.missions.has_pending_loans() and loan.status == T.LoanStatus.RETURNED and not loan.has_current_ship_id, "legal dock finalizes pending loan")
	expect(g.state.find("item_instance_state", "item_instance_id", protected_item) == null, "return invalidates protected equipment rather than turning it into merchandise")
	expect(g.state.ship().ship_instance_id != ship_id and g.state.ship().status == T.ShipStatus.DOCKED and g.station() == "station_echo_depot", "dock restores local usable ship without changing station")
	expect(g.inventory.count(warehouse, "ore_ferrosilicate", true) == previous_units + units, "ordinary cargo unloaded once to actual arrival station")
	expect(package.host_container_id == warehouse and package.reward_id == reward_id and package.status == "sealed", "original sealed package unloaded without losing or rerolling reward")
	if not reopen("returned " + mission_id): return false
	expect(g.state.find("loan_state", "loan_id", loan_id).status == T.LoanStatus.RETURNED and g.state.find("salvage_package_state", "package_id", package_id).host_container_id == warehouse, "returned loan and ordinary package persist")
	return true

func parked_loan_episode() -> bool:
	if not cross("endpoint_echo_anchor") or not dock("station_anchor_port"): return false
	var owned_id: String = ""
	for ship: D.ShipStateDto in g.state.rows("ship_state"):
		if ship.status == T.ShipStatus.DOCKED and ship.station_id == "station_anchor_port" and ship.policy_id == "normal_owned": owned_id = ship.ship_instance_id; break
	if not expect(not owned_id.is_empty(), "fixture has actual owned ship for remote parked-loan case"): return false
	if not action("accept_mission", "contract_survey_echo") or not action("claim_loan", "loan_contract_lantern"): return false
	var loan: D.LoanStateDto = g.work._active_loan()
	var loan_id: String = loan.loan_id
	var attempt: String = g.missions.active().mission_instance_id
	var cargo: String = g.inventory.hold(g.state.ship(), T.ContainerKind.CARGO)
	if not action("buy_item", "ore_ferrosilicate", 3, cargo) or not action("switch_ship", owned_id): return false
	if not cross("endpoint_anchor_echo"): return false
	if not action("abandon_mission", attempt): return false
	var origin_warehouse: String = g.inventory.warehouse("station_anchor_port")
	var local_warehouse: String = g.inventory.warehouse("station_echo_depot")
	var origin_before: int = g.inventory.count(origin_warehouse, "ore_ferrosilicate", true)
	var local_before: int = g.inventory.count(local_warehouse, "ore_ferrosilicate", true)
	if not dock("station_echo_depot"): return false
	loan = g.state.find("loan_state", "loan_id", loan_id)
	expect(loan.status == T.LoanStatus.RETURNED and g.state.ship().ship_instance_id == owned_id, "remote loan cleanup retains controlled owned hull")
	expect(g.inventory.count(origin_warehouse, "ore_ferrosilicate", true) == origin_before + 3, "parked loan unloads to its actual origin station")
	expect(g.inventory.count(local_warehouse, "ore_ferrosilicate", true) == local_before, "remote cleanup cannot teleport goods to current station")
	return reopen("remote parked-loan cleanup")

func _initialize() -> void:
	var source: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/gameplay-progress.db")
	scratch = ProjectSettings.globalize_path("res://../jiaoben/tmp/loan-cleanup-audit-%d.db" % Time.get_ticks_usec())
	if expect(FileAccess.file_exists(source) and DirAccess.copy_absolute(source, scratch) == OK, "copy closed gameplay business fixture"):
		store = Store.new(scratch)
		if expect(store.open(), "open isolated loan cleanup database"):
			var state: XJRuntimeState = store.resume()
			if expect(state != null, "resume valid frozen gameplay fixture"):
				g = G.new(); g.setup(state, store.catalog)
				var ok: bool = episode("contract_mining_iron", "loan_contract_miner", false)
				if ok: ok = episode("contract_patrol_echo", "loan_contract_kestrel", true)
				if ok: ok = parked_loan_episode()
				expect(ok, "flight abandonment, expiry and remote parked-loan cleanup complete safely")
				g.dispose()
			store.close()
	print("LOAN_CLEANUP_AUDIT_RESULT ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
