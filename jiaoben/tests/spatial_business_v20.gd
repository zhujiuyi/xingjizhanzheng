extends Node
## Real Store, frozen catalog, typed state and production gameplay services.
## Named placements and unlocks are isolated preconditions. Physics LOS,
## rendering, natural progression and travel COMMIT belong to other suites.
const Store = preload("res://runtime/data/store.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Travel = preload("res://runtime/travel.gd")
const Space = preload("res://runtime/space_coordinates.gd")
const Codec = preload("res://runtime/data/codec.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var store: Store
var base: XJRuntimeState
var state: XJRuntimeState
var g: Gameplay
var directory: String = ""
var checks: int = 0
var failures: Array[String] = []

func _ready() -> void:
	get_tree().set_meta("xj_spatial_business_v20_diagnostic", true)
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func action(kind: String, target: String = "", quantity: int = 1) -> bool:
	return g.act(kind, target, quantity).phase == T.ActionPhase.APPLIED

func fresh(unlocks: bool = false) -> void:
	if g != null: g.dispose()
	state = store.clone_state(base)
	g = Gameplay.new()
	g.setup(state, store.catalog)
	if unlocks:
		for definition: Dictionary in store.catalog.rows("unlock_defs"): g.grant_unlock(str(definition.unlock_id))
		g._sync_spawns()

func foreign_site(anchor_id: String) -> String:
	var anchor: Dictionary = store.catalog.one("anchor_defs", "anchor_id", anchor_id)
	var target_site: String = Space.site_for_anchor(store.catalog, anchor_id)
	for site: Dictionary in store.catalog.rows("site_defs"):
		if str(site.sector_id) == str(anchor.sector_id) and str(site.site_id) != target_site: return str(site.site_id)
	return ""

func place(anchor_id: String, site_override: String = "") -> void:
	var anchor: Dictionary = store.catalog.one("anchor_defs", "anchor_id", anchor_id)
	var ship: D.ShipStateDto = state.ship()
	ship.sector_id = str(anchor.sector_id)
	ship.status = T.ShipStatus.FLYING; ship.has_station_id = false; ship.station_id = ""
	ship.pos_x = float(anchor.x_m); ship.pos_y = float(anchor.y_m); ship.pos_z = float(anchor.z_m)
	ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	state.player().has_docked_station_id = false; state.player().docked_station_id = ""
	for container: D.ContainerStateDto in state.rows("container_state"):
		if container.ship_instance_id == ship.ship_instance_id: container.sector_id = ship.sector_id
	var site: String = site_override if not site_override.is_empty() else Space.site_for_anchor(store.catalog, anchor_id)
	check(Space.assign(state, "ship", ship.ship_instance_id, site), "fixture explicitly assigns named site " + site)

func fingerprint() -> Dictionary:
	return {"credit": state.player().credit, "ship": Codec.new().encode_row("ship_state", state.ship()), "rng": Codec.new().encode_row("rng_state", state.rows("rng_state")[0]), "items": state.rows("item_instance_state").size(), "stacks": state.rows("inventory_stack_state").size(), "loans": state.rows("loan_state").size(), "packages": state.rows("salvage_package_state").size()}

func context_keys(candidate: XJRuntimeState) -> Array[String]:
	var result: Array[String] = []
	for context: D.SpatialStateDto in candidate.rows("spatial_state"): result.append("%s/%s/%s" % [context.entity_kind, context.entity_id, context.site_id])
	result.sort()
	return result

func lifecycle() -> void:
	fresh()
	var station: Dictionary = store.catalog.one("station_defs", "station_id", "station_anchor_port")
	var anchor_id: String = str(station.station_anchor_id)
	var site: String = Space.site_for_anchor(store.catalog, anchor_id)
	check(Space.current_site(state) == site, "real new-world builder persists the initial parked ship's station site")
	var parked: D.ShipStateDto = g.inventory.create_ship("frigate_kestrel", "station_anchor_port")
	if not check(parked != null and Space.site_for_entity(state, "ship", parked.ship_instance_id) == site, "real ship factory assigns the authored station site before creating holds"): return
	check(g.same_anchor_site(parked, store.catalog.one("anchor_defs", "anchor_id", anchor_id)), "factory-created parked ship belongs to the station's site")
	check(action("switch_ship", parked.ship_instance_id) and Space.current_site(state) == site, "legal parked-ship switch retains its own explicit context")
	check(action("undock") and Space.current_site(state) == Space.site_for_anchor(store.catalog, str(station.undock_anchor_id)), "real undock publishes the defined departure site")
	place(anchor_id, foreign_site(anchor_id))
	var before: Dictionary = fingerprint()
	check(not action("dock", "station_anchor_port") and fingerprint() == before, "same encoded station XYZ from a different site cannot dock or change assets")
	place(anchor_id)
	check(action("dock", "station_anchor_port"), "actual same-site stationary docking remains legal")
	var other: D.ShipStateDto = g.inventory.create_ship("shuttle_swift", "station_anchor_port")
	Space.assign(state, "ship", other.ship_instance_id, foreign_site(anchor_id))
	check(not action("switch_ship", other.ship_instance_id) and state.ship() == parked, "matching station ID cannot switch into a ship whose spatial context is elsewhere")
	Space.assign(state, "ship", other.ship_instance_id, site)
	g.inventory.retire(other)
	check(other.status == T.ShipStatus.RETURNED and Space.site_for_entity(state, "ship", other.ship_instance_id) == site, "retired ship history preserves its original spatial binding")
	check(g.inventory.wreck(state.current_sector(), g.position(state.ship())).is_empty(), "new spatial worlds refuse wreck creation without an explicit source site")
	var empty_wreck: String = g.inventory.wreck(state.current_sector(), g.position(state.ship()), site)
	check(not empty_wreck.is_empty() and Space.site_for_entity(state, "wreck", empty_wreck) == site, "real wreck factory assigns the supplied source site")
	g.inventory.remove_empty_wreck(empty_wreck)
	check(state.find("container_state", "container_id", empty_wreck) == null and Space.site_for_entity(state, "wreck", empty_wreck).is_empty(), "empty wreck deletion removes its spatial row as well")

func work_and_objectives() -> void:
	fresh(true)
	var signal_def: Dictionary = store.catalog.one("signal_defs", "signal_id", "signal_anchor_gate_calibration")
	place(str(signal_def.anchor_id), foreign_site(str(signal_def.anchor_id)))
	var before: Dictionary = fingerprint()
	check(not action("start_scan", str(signal_def.signal_id)) and not g.work.busy() and fingerprint() == before, "same XYZ from another site cannot start a scan or pay a cycle")
	place(str(signal_def.anchor_id))
	check(action("start_scan", str(signal_def.signal_id)), "same-site real scanner can start after its actual unlock")
	var scan_energy: float = state.ship().energy
	Space.assign(state, "ship", state.ship().ship_instance_id, foreign_site(str(signal_def.anchor_id)))
	g.work.tick(1.0)
	check(not g.work.busy() and is_equal_approx(state.ship().energy, scan_energy), "site change interrupts an unpaid scan before consuming energy")
	var miner: D.ShipStateDto = g.inventory.create_ship("miner_anvil", "station_anchor_port", "normal_owned", "loadout_miner_anvil")
	state.player().controlled_ship_id = miner.ship_instance_id
	var location: Dictionary = store.catalog.one("resource_node_locations", "node_id", "node_echo_ferrosilicate")
	place(str(location.anchor_id), foreign_site(str(location.anchor_id)))
	var node: D.ResourceStateDto = state.find("resource_state", "node_id", "node_echo_ferrosilicate")
	var units: int = node.remaining_units
	before = fingerprint()
	check(not action("start_mining", "node_echo_ferrosilicate") and node.remaining_units == units and fingerprint() == before, "same XYZ from another site cannot start mining or spend resources")
	place(str(location.anchor_id))
	check(action("start_mining", "node_echo_ferrosilicate"), "real compatible same-site mining equipment remains eligible")
	Space.assign(state, "ship", miner.ship_instance_id, foreign_site(str(location.anchor_id)))
	g.work.tick(1.0)
	check(not g.work.busy() and node.remaining_units == units, "site change stops mining before its first extraction")
	var component: Dictionary = store.catalog.one("resource_node_locations", "node_id", "node_anchor_special")
	place(str(component.anchor_id), foreign_site(str(component.anchor_id)))
	before = fingerprint()
	var component_state: D.ResourceStateDto = state.find("resource_state", "node_id", "node_anchor_special")
	var component_units: int = component_state.remaining_units
	check(not action("recover_resource", "node_anchor_special") and component_state.remaining_units == component_units and fingerprint() == before, "same XYZ from another site cannot recover a component")
	place(str(component.anchor_id))
	check(action("recover_resource", "node_anchor_special") and component_state.remaining_units < component_units, "nearby same-site component recovery still grants real inventory")
	fresh()
	check(action("accept_mission", "tutorial_flight") and action("undock"), "real initial tutorial supplies ordered objective records")
	var mission: D.MissionStateDto = g.missions.active()
	var objective: D.MissionObjectiveStateDto = g.missions.progress(mission, 1)
	place("anchor_anchor_flight_forward", foreign_site("anchor_anchor_flight_forward"))
	g.record_event("reach_anchor", "anchor_anchor_flight_forward")
	check(objective.progress_units == 0, "a same-XYZ anchor event from another site cannot advance a reach objective")
	place("anchor_anchor_flight_forward")
	g.record_event("reach_anchor", "anchor_anchor_flight_forward")
	check(objective.progress_units == 1, "an actual same-site anchor event advances the ordered reach objective")

func npc_and_salvage() -> void:
	fresh(true)
	var npc: D.NpcStateDto = state.find("npc_state", "spawn_id", "spawn_anchor_patrol_leader")
	if not check(npc != null and npc.alive, "actual unlocked ambient spawn provides a live NPC"): return
	var spawn: Dictionary = store.catalog.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
	var site: String = Space.site_for_anchor(store.catalog, str(spawn.anchor_id))
	check(Space.site_for_entity(state, "npc", npc.npc_instance_id) == site, "spawn context follows the frozen spawn anchor")
	place(str(spawn.anchor_id), foreign_site(str(spawn.anchor_id)))
	var npc_before: Dictionary = Codec.new().encode_row("npc_state", npc)
	var before: Dictionary = fingerprint()
	check(is_zero_approx(g.damage_npc(npc.npc_instance_id, Vector3.ONE * 100000.0)) and Codec.new().encode_row("npc_state", npc) == npc_before and fingerprint() == before, "same XYZ from another site cannot damage an NPC, pay a bounty or draw salvage RNG")
	npc.behavior_phase = T.NpcPhase.ATTACK
	check(not g.in_combat(), "a distant site's attack phase cannot block local interactions")
	place(str(spawn.anchor_id))
	check(g.in_combat(), "the same actual attack phase counts as local combat on its own site")
	check(g.damage_npc(npc.npc_instance_id, Vector3.ONE * 100000.0) > 0.0 and not npc.alive, "same-site real damage destroys the NPC")
	check(Space.site_for_entity(state, "npc", npc.npc_instance_id) == site, "dead NPC history retains its site binding")
	var package: D.SalvagePackageStateDto
	for candidate: D.SalvagePackageStateDto in state.rows("salvage_package_state"):
		if candidate.source_npc_instance_id == npc.npc_instance_id: package = candidate; break
	if not check(package != null, "real destruction creates one sealed pre-drawn salvage package"): return
	var wreck: D.ContainerStateDto = state.find("container_state", "container_id", package.host_container_id)
	check(wreck != null and Space.site_for_entity(state, "wreck", wreck.container_id) == site, "physical wreck inherits the destroyed NPC's source site")
	place(str(spawn.anchor_id), foreign_site(str(spawn.anchor_id)))
	before = fingerprint()
	check(not action("pickup_wreck", wreck.container_id) and package.host_container_id == wreck.container_id and fingerprint() == before, "same XYZ from another site cannot pick up the original sealed wreck")
	place(str(spawn.anchor_id))
	check(action("pickup_wreck", wreck.container_id) and package.host_container_id == g.inventory.hold(state.ship(), T.ContainerKind.CARGO), "same-site real salvage transfers the original package into cargo")
	check(state.find("container_state", "container_id", wreck.container_id) == null and Space.site_for_entity(state, "wreck", wreck.container_id).is_empty(), "consuming the emptied wreck clears the spatial binding without deleting its package")
	var old_id: String = npc.npc_instance_id
	g.remove_npc(npc)
	check(state.find("npc_state", "npc_instance_id", old_id) == null and Space.site_for_entity(state, "npc", old_id).is_empty(), "actual NPC row removal clears the old generation's context")

func gate_eligibility() -> void:
	fresh(true)
	var endpoint: Dictionary = {}
	for candidate: Dictionary in store.catalog.rows("gate_endpoint_defs"):
		if str(candidate.origin_sector_id) == "sector_anchor": endpoint = candidate; break
	if not check(not endpoint.is_empty(), "formal Anchor sector has an authored gate endpoint"): return
	place(str(endpoint.entry_anchor_id), foreign_site(str(endpoint.entry_anchor_id)))
	var travel: Travel = Travel.new()
	travel.setup(state, store, func(_candidate: XJRuntimeState): return false, Callable())
	var before: Dictionary = fingerprint()
	check(not travel.begin(str(endpoint.endpoint_id)) and fingerprint() == before, "matching gate XYZ from another site cannot begin preparation or pay a transfer")
	place(str(endpoint.entry_anchor_id))
	check(travel.begin(str(endpoint.endpoint_id)) and travel.active() and travel.cancel(), "real same-site gate preparation remains eligible and can cancel before either durable endpoint")

func _run() -> void:
	var script_path: String = OS.get_environment("XJ_SPATIAL_BUSINESS_V20_SCRIPT").replace("\\", "/")
	var prefix: String = script_path.get_base_dir().get_base_dir().path_join("tmp/spatial-business-v20") if not script_path.is_empty() else ProjectSettings.globalize_path("res://../jiaoben/tmp/spatial-business-v20").replace("\\", "/")
	directory = OS.get_environment("XJ_SPATIAL_BUSINESS_V20_DIRECTORY").replace("\\", "/")
	if directory.is_empty(): directory = prefix.path_join(Store.new_id("run").trim_prefix("run_"))
	if not check(directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == prefix and directory.begins_with(prefix + "/") and not FileAccess.file_exists(directory.path_join("progress.db")), "business suite only opens a fresh direct child of its test-owned tmp scope"): finish(); return
	DirAccess.make_dir_recursive_absolute(directory)
	store = Store.new(directory.path_join("progress.db"))
	if not check(store.open(), "real Store opens formal catalog and isolated SQLite: " + store.last_error): finish(); return
	if not check(Space.supported(store.catalog), "formal catalog supports explicit two-level spatial contexts"): finish(); return
	base = store.new_world("空间业务独立验收", 41)
	if not check(base != null, "real Store freezes and seals a fresh spatial world: " + store.last_error): finish(); return
	print("SPATIAL_BUSINESS_V20_FIXTURE fresh-frozen-store declared-unlocks-and-named-site-placements no-personal-save no-physics-LOS no-natural-progression-claim")
	lifecycle()
	work_and_objectives()
	npc_and_salvage()
	gate_eligibility()
	check(store.save(state, "manual", 0), "typed spatial state seals through the actual SQLite writer: " + store.last_error)
	check(store._records("PRAGMA integrity_check")[0].values()[0] == "ok" and store._records("PRAGMA foreign_key_check").is_empty(), "spatial snapshot retains physical and relational database integrity")
	var expected_contexts: Array[String] = context_keys(state)
	var slots: Array[Dictionary] = store._records("SELECT slot_id,current_snapshot_id,generation FROM save_slot WHERE world_id=? AND slot_kind='manual' AND slot_index=0", [state.world_id])
	if check(slots.size() == 1, "real manual slot points at the sealed spatial snapshot"):
		g.dispose(); g = null
		store.close()
		if check(store.open(), "closed SQLite reopens through the actual Store"):
			var loaded: XJRuntimeState = store.load(str(slots[0].slot_id), str(slots[0].current_snapshot_id), int(slots[0].generation))
			check(loaded != null and context_keys(loaded) == expected_contexts, "SQLite reopen preserves each ship and NPC identity's exact site context")
	finish()

func finish() -> void:
	if g != null: g.dispose(); g = null
	if store != null: store.close()
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": 0, "directory": directory, "fixture": "fresh-store-frozen-catalog-named-site-placement-and-unlocks-business-only"}
	if not directory.is_empty() and DirAccess.dir_exists_absolute(directory):
		var output: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
		if output != null: output.store_string(JSON.stringify(summary, "\t") + "\n"); output.close()
	print("SPATIAL_BUSINESS_V20_FINAL_JSON " + JSON.stringify(summary))
	print("SPATIAL_BUSINESS_V20_RESULT %s checks=%d failures=%d captures=0" % [summary.result, checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
