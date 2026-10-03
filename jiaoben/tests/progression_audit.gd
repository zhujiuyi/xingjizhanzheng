extends SceneTree
## Fresh database progression without synthetic money, materials, unlocks or completions.
## Spatial relocation, validated T0 host events and T3 hit damage are explicit fixtures.
## Real Travel commits are used; this does not test 3D flight, AI, LOS or collisions.
const Gameplay = preload("res://runtime/gameplay.gd")
const Store = preload("res://runtime/data/store.gd")
const Travel = preload("res://runtime/travel.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: int = 0
var storage: Store
var game: Gameplay
var database_path: String
var completed_ids: Array[String] = []
var research_ids: Array[String] = []
var traversals: int = 0
var gate_spend: int = 0

func expect(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok

func action(kind: String, target: String = "", quantity: int = 1, extra: String = "") -> bool:
	var result: D.ActionResultDto = game.act(kind, target, quantity, extra)
	return expect(result.phase == T.ActionPhase.APPLIED, kind + " " + target + ": " + result.display_reason_key)

func rejected(kind: String, target: String) -> void:
	var credit: int = game.state.player().credit
	var knowledge: int = game.state.rows("unlock_state").size()
	var result: D.ActionResultDto = game.act(kind, target)
	expect(result.phase != T.ActionPhase.APPLIED, "reject " + kind + " " + target)
	expect(game.state.player().credit == credit and game.state.rows("unlock_state").size() == knowledge, "rejection preserves credit and knowledge " + target)

func position_at(anchor_id: String) -> bool:
	var anchor: Dictionary = game.definition("anchor_defs", "anchor_id", anchor_id)
	if not expect(not anchor.is_empty() and str(anchor.sector_id) == game.state.current_sector(), "position fixture stays in current sector " + anchor_id): return false
	var ship: D.ShipStateDto = game.state.ship()
	ship.pos_x = float(anchor.x_m); ship.pos_y = float(anchor.y_m); ship.pos_z = float(anchor.z_m)
	ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	return true

func fly() -> bool:
	return action("undock") if game.state.ship().status == T.ShipStatus.DOCKED else game.state.ship().status == T.ShipStatus.FLYING

func prepare_destination(_candidate: XJRuntimeState) -> bool:
	# Business-only staging. Main/sector construction is covered by the integration suite.
	return true

func record_arrival(candidate: XJRuntimeState, connection_id: String) -> void:
	var arrival: Gameplay = Gameplay.new()
	arrival.setup(candidate, storage.catalog)
	arrival.record_event("transit_connection", connection_id)
	arrival.dispose()

func stable() -> bool:
	return game.save_eligible()

func transit(endpoint_id: String) -> bool:
	if not fly(): return false
	var endpoint: Dictionary = game.definition("gate_endpoint_defs", "endpoint_id", endpoint_id)
	if not expect(not endpoint.is_empty(), "real endpoint exists " + endpoint_id): return false
	game.stop_interactions()
	var connection: Dictionary = game.definition("effective_connection_defs", "connection_id", str(endpoint.connection_id))
	var current_cooldown: D.ShipGateCooldownStateDto = game.state.find("ship_gate_cooldown_state", "ship_instance_id", game.state.ship().ship_instance_id)
	var wait_s: float = current_cooldown.remaining_s if current_cooldown != null else 0.0
	game.tick(maxf(wait_s, game.rule("combat_exit_delay_s")) + 1.0)
	if not position_at(str(endpoint.entry_anchor_id)): return false
	var transfer: Travel = Travel.new()
	transfer.setup(game.state, storage, prepare_destination, record_arrival, stable)
	var before_credit: int = game.state.player().credit
	if not expect(transfer.begin(endpoint_id), "unmodified gate eligibility " + endpoint_id + ": " + transfer.last_error): return false
	transfer.tick(float(connection.prepare_s) + 0.1)
	if not expect(transfer.phase == T.TravelPhase.COMMITTED and transfer.ready_candidate != null, "origin/destination SQLite commits " + endpoint_id + ": " + transfer.last_error): return false
	game.dispose()
	game = Gameplay.new()
	game.setup(transfer.ready_candidate, storage.catalog)
	expect(game.state.current_sector() == str(endpoint.target_sector_id), "actual gate arrival changes sector " + endpoint_id)
	expect(game.state.player().credit == before_credit - int(connection.fee_credit), "gate fee charged once " + endpoint_id)
	traversals += 1
	gate_spend += int(connection.fee_credit)
	return true

func travel_to(sector_id: String) -> bool:
	if sector_id == game.state.current_sector(): return true
	if not fly(): return false
	var route: Array[Dictionary] = game.missions._route(game.state.current_sector(), sector_id, true)
	if not expect(not route.is_empty(), "earned permissions provide route to " + sector_id): return false
	for endpoint: Dictionary in route:
		if not transit(str(endpoint.endpoint_id)): return false
	return true

func dock_at(station_id: String) -> bool:
	if game.station() == station_id: return true
	var station: Dictionary = game.definition("station_defs", "station_id", station_id)
	if not travel_to(str(station.sector_id)) or not fly(): return false
	game.stop_interactions()
	game.tick(game.rule("combat_exit_delay_s") + 1.0)
	return position_at(str(station.station_anchor_id)) and action("dock", station_id)

func scan(signal_id: String) -> bool:
	var signal_def: Dictionary = game.definition("signal_defs", "signal_id", signal_id)
	var anchor: Dictionary = game.definition("anchor_defs", "anchor_id", str(signal_def.anchor_id))
	if not travel_to(str(anchor.sector_id)) or not fly() or not position_at(str(anchor.anchor_id)): return false
	if not action("start_scan", signal_id): return false
	for _second: int in range(600):
		game.tick(1.0)
		if game.work.scan_target.is_empty(): break
	return expect(game.work.scan_target.is_empty(), "real paid scan cycles complete " + signal_id)

func mine(obj: Dictionary) -> bool:
	var location: Dictionary = game.definition("resource_node_locations", "node_id", str(obj.target_node_id))
	var anchor: Dictionary = game.definition("anchor_defs", "anchor_id", str(location.anchor_id))
	if not travel_to(str(anchor.sector_id)) or not fly() or not position_at(str(anchor.anchor_id)): return false
	if not action("start_mining", str(obj.target_node_id)): return false
	for _second: int in range(600):
		game.tick(1.0)
		if game.missions.progress(game.missions.active(), int(obj.objective_index)).progress_units >= int(obj.required_count): break
	game.stop_interactions()
	return expect(game.missions.progress(game.missions.active(), int(obj.objective_index)).progress_units == int(obj.required_count), "real mining supplies exact historical collection")

func complete_mission(mission_id: String) -> bool:
	var definition: Dictionary = game.definition("mission_defs", "mission_id", mission_id)
	if not dock_at(str(definition.accept_station_id)) or not action("accept_mission", mission_id): return false
	rejected("deliver_mission", mission_id)
	var instance_id: String = game.missions.active().mission_instance_id
	for obj: Dictionary in game.missions.objectives(mission_id):
		var current: D.MissionObjectiveStateDto = game.missions.progress(game.missions.active(), int(obj.objective_index))
		if current.progress_units >= int(obj.required_count): continue
		match str(obj.objective_kind):
			"undock":
				if not fly(): return false
			"loan_checkout":
				if not action("claim_loan", str(obj.target_loan_service_id)): return false
			"fit_validate":
				if not expect(current.progress_units == int(obj.required_count), "loan loadout satisfies actual fitting validation"): return false
			"reach_anchor", "brake_at_anchor":
				if not fly() or not position_at(str(obj.target_anchor_id)): return false
				game.tick(float(obj.hold_s))
				game.record_event(str(obj.objective_kind), str(obj.target_anchor_id))
			"transit_connection":
				var endpoint_id: String = str(game.missions.guidance().get("waypoint_id", ""))
				if not transit(endpoint_id): return false
			"scan_signal":
				if not scan(str(obj.target_signal_id)): return false
			"collect":
				if not mine(obj): return false
			"destroy_spawn":
				if not fly(): return false
				var enemy: D.NpcStateDto = game.state.find("npc_state", "spawn_id", str(obj.target_spawn_id))
				if not expect(enemy != null and enemy.alive, "task creates actual scoped enemy"): return false
				var prior: int = game.state.player().credit
				game.damage_npc(enemy.npc_instance_id, Vector3(999999.0, 0.0, 0.0))
				expect(not enemy.alive and game.state.player().credit == prior, "tutorial hit fixture records death without bounty")
			"dock":
				if not dock_at(str(obj.target_station_id)): return false
			"deliver":
				if not dock_at(str(obj.target_station_id)): return false
				if str(definition.mission_kind) != "tutorial":
					rejected("deliver_mission", mission_id)
					if not action("buy_item", str(obj.target_item_id), int(obj.required_count)): return false
			_:
				expect(false, "no orphan objective kind " + str(obj.objective_kind))
				return false
	if not dock_at(str(definition.turnin_station_id)): return false
	var credit_before: int = game.state.player().credit
	var expected_reward: int = int(game.definition("mission_reward_defs", "mission_id", mission_id).reward_credit)
	if not action("deliver_mission", instance_id): return false
	expect(game.missions.completed(mission_id) and game.missions.active() == null, "actual turn-in completes " + mission_id)
	expect(game.state.player().credit == credit_before + expected_reward, "exact atomic payout " + mission_id)
	for reward: Dictionary in game.rows("mission_unlock_rewards"):
		if str(reward.mission_id) == mission_id: expect(game.unlocked(str(reward.unlock_id)), "task reward grants " + str(reward.unlock_id))
	rejected("deliver_mission", instance_id)
	completed_ids.append(mission_id)
	return roundtrip(mission_id)

func roundtrip(label: String) -> bool:
	if not expect(storage.save(game.state, "manual", 0), "complete progression snapshot " + label + ": " + storage.last_error): return false
	var slot: Dictionary = {}
	for candidate: Dictionary in storage.list_slots():
		if str(candidate.slot_kind) == "manual" and int(candidate.slot_index) == 0: slot = candidate
	if not expect(not slot.is_empty(), "manual slot exists " + label): return false
	var credit: int = game.state.player().credit
	game.dispose(); storage.close()
	storage = Store.new(database_path)
	if not expect(storage.open(), "reopen independent SQLite " + label): return false
	var loaded: XJRuntimeState = storage.load(str(slot.slot_id), str(slot.current_snapshot_id), int(slot.generation))
	if not expect(loaded != null, "validated reload " + label + ": " + storage.last_error): return false
	game = Gameplay.new(); game.setup(loaded, storage.catalog)
	expect(game.state.player().credit == credit, "credit roundtrip " + label)
	for mission_id: String in completed_ids: expect(game.missions.completed(mission_id), "completion survives reopen " + mission_id)
	for research_id: String in research_ids:
		expect(game.unlocked(str(game.definition("research_defs", "research_id", research_id).reward_unlock_id)), "research survives reopen " + research_id)
	return true

func research_at_current_station(research_id: String) -> bool:
	var definition: Dictionary = game.definition("research_defs", "research_id", research_id)
	expect(game.missions.completed(str(definition.verification_mission_id)), "research verification earned by real mission " + research_id)
	expect(game.economy.reputation(str(definition.station_faction_id)) >= int(definition.required_reputation), "research reputation earned by task rewards " + research_id)
	for input: Dictionary in game.rows("research_inputs"):
		if str(input.research_id) == research_id:
			if not action("buy_item", str(input.item_id), int(input.quantity)): return false
	var credit: int = game.state.player().credit
	if not action("research", research_id): return false
	expect(game.state.player().credit == credit - int(definition.required_credit), "research fee charged exactly " + research_id)
	expect(game.unlocked(str(definition.reward_unlock_id)), "research action grants knowledge " + research_id)
	rejected("research", research_id)
	research_ids.append(research_id)
	return roundtrip(research_id)

func run_chain() -> bool:
	var tutorials: Array[Dictionary] = game.missions.chain("tutorial")
	var stories: Array[Dictionary] = game.missions.chain("story")
	expect(tutorials.size() == 5 and stories.size() == 8, "all authored tutorial and story modules are present")
	expect(not game.unlocked("unlock_anchor_echo_gate") and not game.unlocked("unlock_open_routes"), "new world has no campaign permissions")
	var locked: Dictionary = game.definition("gate_endpoint_defs", "endpoint_id", "endpoint_anchor_mirror")
	expect(not game.missions._gate_route_reason(locked, float(game.metrics(game.state.ship()).total_mass_kg)).is_empty(), "full route denied before teaching reward")
	for index: int in range(tutorials.size()):
		if index + 1 < tutorials.size():
			var next: Dictionary = tutorials[index + 1]
			expect(not game.missions.eligible(next), "next tutorial remains locked before actual predecessor reward")
		if not complete_mission(str(tutorials[index].mission_id)): return false
		if index == 0: expect(not game.unlocked("unlock_anchor_echo_gate"), "T0 does not prematurely unlock second system")
		if index == 1: expect(game.unlocked("unlock_anchor_echo_gate") and not game.unlocked("unlock_open_routes"), "T1 opens only two-system teaching route")
	expect(game.unlocked("unlock_open_routes"), "T4 reward opens full fixed network")
	for endpoint: Dictionary in game.rows("gate_endpoint_defs"):
		if str(endpoint.required_unlock_id) == "unlock_open_routes":
			expect(game.missions._gate_route_reason(endpoint, float(game.metrics(game.state.ship()).total_mass_kg)).is_empty(), "T4 permission connects authored system " + str(endpoint.endpoint_id))
	for index: int in range(stories.size()):
		var chapter: Dictionary = stories[index]
		if index + 1 < stories.size():
			var next: Dictionary = stories[index + 1]
			expect(not game.missions.eligible(next) and game.missions.missing_prerequisite(str(next.mission_id)) == str(chapter.mission_id), "next chapter tied to current actual completion")
		if not dock_at(str(chapter.accept_station_id)): return false
		for research: Dictionary in game.rows("research_defs"):
			if str(research.verification_mission_id) == str(chapter.mission_id): rejected("research", str(research.research_id))
		if not complete_mission(str(chapter.mission_id)): return false
		expect(game.missions.missing_prerequisite(str(chapter.mission_id)).is_empty(), "completed chapter closes prerequisites")
		for research: Dictionary in game.rows("research_defs"):
			if str(research.verification_mission_id) == str(chapter.mission_id):
				if not research_at_current_station(str(research.research_id)): return false
	expect(completed_ids.size() == 13 and research_ids.size() == 4, "all authored teaching/story/research branches reached through real business")
	expect(game.state.player().credit >= 0 and traversals > 0, "initial grant and actual task revenue fund chain without fixture money")
	return roundtrip("entire-campaign")

func _initialize() -> void:
	database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/progression-audit-%d.db" % Time.get_ticks_usec())
	storage = Store.new(database_path)
	if expect(storage.open(), "open isolated progression database"):
		var fresh: XJRuntimeState = storage.new_world("progression-audit", 1042026)
		if expect(fresh != null, "fresh durable world"):
			game = Gameplay.new(); game.setup(fresh, storage.catalog)
			var chain_ok: bool = run_chain()
			expect(chain_ok, "complete progression chain reaches terminal state")
			print("PROGRESSION_AUDIT credit=", game.state.player().credit, " traversals=", traversals, " gate_spend=", gate_spend, " missions=", completed_ids.size(), " research=", research_ids.size())
			game.dispose()
	storage.close()
	print("PROGRESSION_AUDIT_RESULT ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " database=", database_path)
	quit(1 if failures else 0)
