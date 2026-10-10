extends Node
## Real authoritative services and fresh SQLite. Named poses and test supplies
## are explicit preconditions; real rendered NPC combat is tested separately.
const Store = preload("res://runtime/data/store.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Validation = preload("res://runtime/data/validation.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var store: Store
var state: XJRuntimeState
var g: Gameplay
var directory: String
var checks: int = 0
var failures: Array[String] = []

func _ready() -> void:
	get_tree().set_meta("xj_civilizations_v24_diagnostic", true)
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func action(kind: String, target: String = "", quantity: int = 1, extra: String = "") -> bool:
	var result: D.ActionResultDto = g.act(kind, target, quantity, extra)
	if result.phase != T.ActionPhase.APPLIED: print("ACTION_REASON ", kind, " ", g.last_error)
	if result.phase == T.ActionPhase.APPLIED and kind == "manufacture" and g.get("industry") != null and g.get("industry").supported():
		var queue: RefCounted = g.get("industry")
		var job: RefCounted = queue.jobs(g.station())[-1]
		check(job.status in ["queued", "running"], "authorized hull manufacturing enters paid queue")
		queue.tick(job.remaining_s)
		return action("claim_industry", job.job_id)
	return result.phase == T.ActionPhase.APPLIED

func place(anchor_id: String, station_id: String = "") -> void:
	var anchor: Dictionary = store.catalog.one("anchor_defs", "anchor_id", anchor_id)
	var ship: D.ShipStateDto = state.ship()
	ship.sector_id = anchor.sector_id
	ship.pos_x = anchor.x_m; ship.pos_y = anchor.y_m; ship.pos_z = anchor.z_m
	ship.vel_x = 0; ship.vel_y = 0; ship.vel_z = 0
	ship.status = T.ShipStatus.FLYING if station_id.is_empty() else T.ShipStatus.DOCKED
	ship.has_station_id = not station_id.is_empty(); ship.station_id = station_id
	state.player().has_docked_station_id = not station_id.is_empty(); state.player().docked_station_id = station_id
	for container: D.ContainerStateDto in state.rows("container_state"):
		if container.has_ship_instance_id and container.ship_instance_id == ship.ship_instance_id: container.sector_id = ship.sector_id
	check(g.assign_anchor_site("ship", ship.ship_instance_id, anchor_id), "fixture assigns authored site " + anchor_id)
	if not station_id.is_empty(): g.inventory.warehouse(station_id)

func capital(faction: String) -> void:
	var definition: Dictionary = store.catalog.one("civilization_defs", "faction_id", faction)
	var station: Dictionary = store.catalog.one("station_defs", "station_id", definition.capital_station_id)
	place(station.station_anchor_id, station.station_id)

func fingerprint() -> Dictionary:
	var result: Dictionary = {"credit": state.player().credit, "allegiance": g.civilizations.allegiance()}
	for table: String in ["inventory_stack_state", "ship_state", "reputation_state", "unlock_state", "territory_state", "war_campaign_state", "war_fleet_state"]:
		var values: Array = []
		for row: RefCounted in state.rows(table): values.append(Codec.new().encode_row(table, row))
		result[table] = values
	return result

func admission(faction: String) -> void:
	capital(faction)
	check(not action("join_civilization", faction), "admission rejects skipping the three real missions " + faction)
	for entry: Dictionary in store.catalog.rows("civilization_join_missions"):
		if entry.faction_id != faction: continue
		capital(faction)
		var before_rep: int = g.economy.reputation(faction)
		check(action("accept_mission", entry.mission_id), "accept real admission step " + str(entry.step_index))
		var objective: Dictionary = store.catalog.one("mission_objective_defs", "mission_id", entry.mission_id)
		match str(objective.objective_kind):
			"deliver":
				g.inventory.grant(g.inventory.hold(state.ship(), T.ContainerKind.CARGO), objective.target_item_id, int(objective.required_count))
			"scan_signal":
				var signal_def: Dictionary = store.catalog.one("signal_defs", "signal_id", objective.target_signal_id)
				place(signal_def.anchor_id)
				check(action("start_scan", signal_def.signal_id), "real paid scan starts at the correct admission site")
				for step: int in range(2400):
					g.tick(0.1)
					if g.work.scan_target.is_empty(): break
				check(g.work.scan_target.is_empty(), "real scanner completes admission objective")
				capital(faction)
			"destroy_spawn":
				var npc: D.NpcStateDto = state.find("npc_state", "spawn_id", objective.target_spawn_id)
				check(npc != null and npc.alive, "admission creates its actual scoped NPC")
				if npc != null:
					var spawn: Dictionary = store.catalog.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
					place(spawn.anchor_id)
					g.damage_npc(npc.npc_instance_id, Vector3(100000, 100000, 100000))
					check(not npc.alive, "production damage records admission defender defeat")
				capital(faction)
		check(action("deliver_mission", entry.mission_id), "claim real admission step " + str(entry.step_index))
		check(g.missions.completed(entry.mission_id) and g.economy.reputation(faction) == before_rep + 80, "admission rewards once and records completion")
		var before: Dictionary = fingerprint()
		check(not action("deliver_mission", entry.mission_id) and fingerprint() == before, "duplicate admission claim changes no assets or reputation")

func develop(faction: String) -> void:
	capital(faction)
	if g.civilizations.membership().switch_cooldown_remaining_s > 0: g.civilizations.tick(601.0)
	var previous_ships: int = state.rows("ship_state").size()
	var fee: int = 0 if g.civilizations.allegiance().is_empty() else int(g.rule("civilization_switch_fee"))
	var before_credit: int = state.player().credit
	check(action("join_civilization", faction), "single active allegiance established " + faction)
	check(g.civilizations.allegiance() == faction and state.player().credit == before_credit - fee and state.rows("ship_state").size() == previous_ships, "allegiance changes only identity and disclosed fee")
	var warehouse: String = g.inventory.warehouse(g.station())
	var donation: Dictionary = {}
	for row: Dictionary in store.catalog.rows("civilization_donation_defs"):
		if row.faction_id == faction and row.item_id == "ore_ferrosilicate": donation = row; break
	var before: Dictionary = fingerprint()
	check(not action("donate_civilization", donation.donation_id, 51) and fingerprint() == before, "oversized donation is rejected without payment")
	var owned: int = g.inventory.count(warehouse, donation.item_id, true)
	check(not action("donate_civilization", donation.donation_id) and g.inventory.count(warehouse, donation.item_id, true) == owned, "missing donation materials are not fabricated")
	g.inventory.grant(warehouse, donation.item_id, 50000)
	var reputation: int = g.economy.reputation(faction)
	check(action("donate_civilization", donation.donation_id, 16), "donation consumes real normal warehouse material")
	check(g.inventory.count(warehouse, donation.item_id, true) == owned + 48400 and g.economy.reputation(faction) == reputation + 160, "exact ore payment and exact reputation award")
	check(int(g.civilizations.rank(faction).rank_level) == 2, "mission plus donation reaches first exclusive hull title")
	for i: int in range(8): check(action("donate_civilization", donation.donation_id, 50), "material-backed reputation progression batch " + str(i))
	check(int(g.civilizations.rank(faction).rank_level) >= 6, "material-backed progression reaches advanced hull title")
	for hull: Dictionary in store.catalog.rows("civilization_hull_defs"):
		if hull.faction_id != faction: continue
		var ship_id: String = hull.ship_id
		var before_unlock: Dictionary = fingerprint()
		check(not action("buy_ship", ship_id) and not action("manufacture", "hull_recipe_" + ship_id) and fingerprint() == before_unlock, "both procurement paths require civilization technology " + ship_id)
		var research: String = "research_" + ship_id
		for input: Dictionary in store.catalog.rows("research_inputs"):
			if input.research_id == research: g.inventory.grant(warehouse, input.item_id, int(input.quantity))
		check(action("research", research), "real civilization design research " + ship_id)
		var count: int = state.rows("ship_state").size()
		check(action("buy_ship", ship_id) and state.rows("ship_state").size() == count + 1, "authorized purchase creates one owned exclusive hull")
		var recipe: String = "hull_recipe_" + ship_id
		for input: Dictionary in store.catalog.rows("hull_recipe_inputs"):
			if input.hull_recipe_id == recipe: g.inventory.grant(warehouse, input.item_id, int(input.quantity))
		check(action("manufacture", recipe) and state.rows("ship_state").size() == count + 2, "authorized manufacture consumes recipe and creates one owned hull")

func campaign() -> void:
	var civ: RefCounted = g.civilizations
	var faction: String = civ.allegiance()
	capital(faction)
	var definition: Dictionary = {}
	for row: Dictionary in store.catalog.rows("civilization_war_defs"):
		if row.faction_id == faction: definition = row; break
	check(action("start_war", definition.war_id), "eligible noble accepts one neutral-system war")
	var war: D.WarCampaignStateDto = civ.active_war()
	check(war != null and civ.living_fleet(war, "ally").size() == 3 and civ.living_fleet(war, "defender").size() == 4, "seven real typed NPC participants are created")
	var before: Dictionary = fingerprint()
	check(not action("start_war", definition.war_id) and not action("join_civilization", "faction_route_council") and fingerprint() == before, "active war blocks double dispatch and allegiance switch")
	check(Validation.new().validate(state, store.catalog), "active assembly snapshot has full legal fleet and territory closure")
	check(store.save(state, "manual", 1), "assembly and actual fleet save to SQLite " + store.last_error)
	if g != null: g.dispose()
	state = store.load("snapshot:" + state.snapshot.meta.snapshot_id)
	if not check(state != null, "assembly state can reopen from sealed SQLite " + store.last_error): return
	g = Gameplay.new(); g.setup(state, store.catalog); civ = g.civilizations; war = civ.active_war()
	check(war != null and state.rows("war_fleet_state").size() == 7, "war fleet identities survive reopen")
	place(definition.capture_anchor_id)
	check(action("fleet_command", "regroup") and war.fleet_order == "regroup", "real fleet regroup order is accepted")
	var ally: D.NpcStateDto = civ.living_fleet(war, "ally")[0]
	check(not action("fleet_command", "focus", 1, ally.npc_instance_id), "friendly focus fire is rejected")
	var defender: D.NpcStateDto = civ.living_fleet(war, "defender")[0]
	check(action("fleet_command", "focus", 1, defender.npc_instance_id) and war.focus_target_id == defender.npc_instance_id, "real hostile focus target is bound")
	civ.tick(31.0)
	check(civ.owner(definition.target_sector_id).is_empty() and war.status == "fighting", "occupation cannot complete while defenders survive")
	var anchor: Dictionary = store.catalog.one("anchor_defs", "anchor_id", definition.capture_anchor_id)
	for npc: D.NpcStateDto in state.rows("npc_state").duplicate():
		if npc.alive and not civ.friendly(npc.npc_instance_id) and g.same_anchor_site(npc, anchor): g.damage_npc(npc.npc_instance_id, Vector3(1e6, 1e6, 1e6))
	state.ship().pos_x += float(definition.capture_radius_m) + 100.0
	civ.tick(40.0)
	check(civ.owner(definition.target_sector_id).is_empty(), "cleared battlefield still requires player presence at capture point")
	place(definition.capture_anchor_id)
	civ.tick(15.0)
	check(war.status == "occupying" and war.capture_remaining_s > 0, "occupation requires continuous elapsed world time")
	g.combat_remaining_s = 0
	var remaining: float = war.capture_remaining_s
	check(store.save(state, "manual", 3), "partially completed occupation saves its actual timer " + store.last_error)
	g.dispose()
	state = store.load("snapshot:" + state.snapshot.meta.snapshot_id)
	if not check(state != null, "occupation timer and surviving fleet reopen " + store.last_error): return
	g = Gameplay.new(); g.setup(state, store.catalog); civ = g.civilizations; war = civ.active_war()
	check(war != null and is_equal_approx(war.capture_remaining_s, remaining) and civ.living_fleet(war, "ally").size() == 3, "reopen cannot skip occupation time or duplicate surviving allies")
	var credit: int = state.player().credit
	var reputation: int = g.economy.reputation(faction)
	civ.tick(16.0)
	check(war.status == "won" and civ.owner(definition.target_sector_id) == faction and war.rewards_claimed, "victory transfers actual neutral sovereignty exactly once")
	check(state.player().credit == credit + int(definition.reward_credit) and g.economy.reputation(faction) == reputation + int(definition.reward_reputation), "victory pays exactly the configured rewards")
	var won: Dictionary = fingerprint()
	civ.tick(120.0)
	check(fingerprint() == won and state.rows("war_fleet_state").is_empty(), "finished war cannot pay again and retires its fleet")
	capital(faction)
	check(not action("start_war", definition.war_id), "occupied system cannot be conquered repeatedly")
	g.combat_remaining_s = 0
	check(store.save(state, "manual", 2), "captured sovereignty saves " + store.last_error)
	g.dispose()
	state = store.load("snapshot:" + state.snapshot.meta.snapshot_id)
	if not check(state != null, "victory and territory reopen " + store.last_error): return
	g = Gameplay.new(); g.setup(state, store.catalog)
	check(g.civilizations.owner(definition.target_sector_id) == faction and g.state.find("war_campaign_state", "war_id", definition.war_id).rewards_claimed, "reopened victory keeps sovereignty and reward receipt")
	capital(faction)
	var other: Dictionary = {}
	for entry: Dictionary in store.catalog.rows("civilization_war_defs"):
		if entry.faction_id == faction and entry.target_sector_id != definition.target_sector_id: other = entry; break
	check(action("start_war", other.war_id), "another eligible neutral expedition can begin")
	var treasury: int = state.player().credit
	check(action("fleet_command", "retreat"), "player can withdraw from a real active campaign")
	check(g.civilizations.active_war() == null and state.rows("war_fleet_state").is_empty() and g.civilizations.owner(other.target_sector_id).is_empty() and state.player().credit == treasury, "withdrawal retires its fleet without sovereignty or victory payment")
	check(action("start_war", other.war_id), "a withdrawn objective supports a clean new attempt")
	place(other.capture_anchor_id)
	war = g.civilizations.active_war()
	for lost_ally: D.NpcStateDto in g.civilizations.living_fleet(war, "ally"):
		g.damage_npc(lost_ally.npc_instance_id, Vector3(1e6, 1e6, 1e6))
	g.civilizations.tick(0.1)
	check(war.status == "failed" and not war.rewards_claimed and state.rows("war_fleet_state").is_empty() and g.civilizations.owner(other.target_sector_id).is_empty(), "loss of the actual allied fleet fails the war and cleans all participants")
	check(state.player().credit == treasury, "defeat cannot award conquest credits")

func _run() -> void:
	directory = OS.get_environment("XJ_CIVILIZATIONS_V24_DIRECTORY").replace("\\", "/")
	if not directory.is_absolute_path() or not directory.contains("/jiaoben/tmp/civilizations-v24/") or directory.contains("..") or FileAccess.file_exists(directory.path_join("progress.db")):
		check(false, "fresh scoped test database required"); _finish(); return
	store = Store.new(directory.path_join("progress.db"))
	if not check(store.open(), "current migrated store opens " + store.last_error): _finish(); return
	state = store.new_world("文明业务独立验收", 7421)
	if not check(state != null, "real 54-system initial world " + store.last_error): _finish(); return
	g = Gameplay.new(); g.setup(state, store.catalog)
	var original: Dictionary = store.catalog.one("ship_defs", "ship_id", "shuttle_swift")
	var copy: Dictionary = store.catalog.one("ship_defs", "ship_id", "shuttle_swift")
	copy.display_name = "mutated test copy"
	check(store.catalog.one("ship_defs", "ship_id", "shuttle_swift") == original, "indexed catalogue returns isolated records without exposing frozen definitions")
	check(store.catalog.one("npc_level_defs", "level", 7) == store.catalog.one("npc_level_defs", "level", 7.0), "indexed catalogue preserves numeric Variant equality")
	g.set_spatial_validator(func(_from: Vector3, _to: Vector3, _target: String): return true)
	check(store.catalog.rows("sector_defs").size() == 54 and state.rows("territory_state").size() == 54 and g.civilizations.allegiance().is_empty(), "new player begins neutral in complete 54-system authority")
	# Test resources and public technology enable isolated service verification.
	state.player().credit = 100000000
	for id: String in ["unlock_open_routes", "unlock_basic_industry", "unlock_tech_ii", "unlock_tech_iii", "unlock_exploration_equipment", "unlock_combat_equipment"]: g.grant_unlock(id)
	var ship: D.ShipStateDto = g.inventory.create_ship("frigate_lantern", "station_anchor_port", "normal_owned", "loadout_frigate_lantern")
	check(ship != null, "fixture supplies an ordinary scanner-equipped ship")
	state.player().controlled_ship_id = ship.ship_instance_id
	for faction: String in ["faction_route_council", "faction_deepforge", "faction_roaming_alliance"]:
		admission(faction)
		if g.missions.active() != null: _finish(); return
		develop(faction)
	check(state.rows("ship_state").size() == 20, "all eighteen purchased/manufactured exclusive hulls survive switching civilizations")
	capital("faction_route_council")
	var before: Dictionary = fingerprint()
	check(not action("buy_ship", "cruiser_council_sentinel") and not action("manufacture", "hull_recipe_cruiser_council_sentinel") and fingerprint() == before, "leaving civilization revokes both procurement paths while retaining hulls and knowledge")
	campaign()
	_finish()

func _finish() -> void:
	if g != null: g.dispose(); g = null
	if store != null: store.close(); store = null
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": 0, "directory": directory, "scope": "real-business-SQLite; explicit test supplies and poses; rendered battle verified separately"}
	print("CIVILIZATIONS_V24_FINAL_JSON ", JSON.stringify(summary))
	print("CIVILIZATIONS_V24_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
