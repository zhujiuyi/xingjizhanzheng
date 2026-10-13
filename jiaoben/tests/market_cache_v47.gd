extends "owned_fleet_v40.gd"
## Exact state comparison against the pinned pre-optimization economy source.
## Timer/quantity boundary and modifier scalars are declared numerical fixtures.
class Rates extends RefCounted:
	var g: RefCounted
	var frontier_rate: float=1.0
	var project_rate: float=1.0
	var calls: int=0
	func restock_rate(_station: String) -> float:calls+=1;return frontier_rate
	func factor(_station: String,_kind: String) -> float:calls+=1;return project_rate
class StableIds extends "res://runtime/gameplay.gd":
	# A declared identity clock fixture, preserving production allocation order.
	func id(prefix: String) -> String:
		_serial+=1;return "%s_%s_%d_fixture_%d" % [prefix,state.world_id,state.snapshot.meta.simulation_tick,_serial]
func _ready() -> void:
	get_tree().set_meta("xj_market_cache_v47_diagnostic",true);run.call_deferred()
func run() -> void:
	directory=OS.get_environment("XJ_MARKET_CACHE_V47_DIRECTORY").replace("\\","/")
	var reference: String=OS.get_environment("XJ_MARKET_CACHE_V47_REFERENCE").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/market-cache-v47/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and reference.is_absolute_path() and reference.contains("/jiaoben/tmp/performance-v47/economy-reference-") and not reference.contains("..") and FileAccess.get_sha256(reference)=="078571ee36cd41ba700e998229d0479dd39f80baefe14b3880a42f76a2972574", "fresh market fixture and pinned original economy source"):await finish();return
	store=Store.new(directory.path_join("progress.db"));if not check(store.open(),"market store opens"):await finish();return
	state=store.new_world("市场数值一致性",4701);if not check(state!=null,"market world starts"):await finish();return
	var left: XJRuntimeState=store.clone_state(state);var right: XJRuntimeState=store.clone_state(state)
	var old_game: Gameplay=Gameplay.new();old_game.setup(left,store.catalog)
	var new_game: Gameplay=Gameplay.new();new_game.setup(right,store.catalog)
	old_game.frontier=Rates.new();old_game.projects=Rates.new();new_game.frontier=Rates.new();new_game.projects=Rates.new()
	var baseline: RefCounted=(load(reference) as Script).new(old_game)
	var sig=preload("snapshot_signature.gd")
	check(sig.runtime(left)==sig.runtime(right),"both worlds start with identical108 groups and RNG")
	var dt: float=1.0/new_game.rule("simulation_hz")
	for scenario: int in range(3):
		old_game.frontier.frontier_rate=0.37 if scenario==2 else 1.125
		new_game.frontier.frontier_rate=old_game.frontier.frontier_rate
		old_game.projects.project_rate=1.7 if scenario==2 else 0.8
		new_game.projects.project_rate=old_game.projects.project_rate
		if scenario==1:
			for table: String in ["shop_stock_state","shop_ship_stock_state"]:
				var source_rows: Array=left.rows(table);var target_rows: Array=right.rows(table)
				for i: int in range(0,source_rows.size(),23):
					source_rows[i].refresh_remaining_s=0.001;target_rows[i].refresh_remaining_s=0.001
					source_rows[i].quantity=0;target_rows[i].quantity=0
		for step: int in range(4):
			old_game.frontier.calls=0;old_game.projects.calls=0;new_game.frontier.calls=0;new_game.projects.calls=0
			baseline.tick(dt);new_game.economy.tick(dt)
			check(sig.runtime(left)==sig.runtime(right),"all108 groups exactly match original arithmetic scenario%d step%d" % [scenario,step])
			check(new_game.frontier.calls<=new_game.rows("station_defs").size() and new_game.projects.calls==new_game.frontier.calls and old_game.frontier.calls>new_game.frontier.calls,"station modifiers read once without omitting any market timer")
	var first: Dictionary=new_game.economy._stock_def("module_engine_vector_i")
	var expected: Dictionary=first.duplicate(true);first["target_units"]=-1
	check(new_game.economy._stock_def("module_engine_vector_i")==expected,"returned shop definition remains an independent mutable copy")
	var legacy: XJCatalog=XJCatalog.new();check(legacy.open("res://data/catalog_scenarios_v22.db"),"frozen prior catalogue opens")
	new_game.catalog=legacy
	check(new_game.economy._stock_def("module_aux_repair_i").is_empty(),"catalogue replacement cannot retain newly introduced goods")
	new_game.catalog=store.catalog
	check(not new_game.economy._stock_def("module_aux_repair_i").is_empty(),"restoring current catalogue invalidates the lookup again")
	legacy.close();baseline.set("g",null);baseline=null;old_game.dispose();new_game.dispose()
	await spawn_equivalence()
	await finish()
func spawn_equivalence() -> void:
	var path: String=OS.get_environment("XJ_MARKET_CACHE_V47_SPAWN_REFERENCE").replace("\\","/")
	if not check(path.is_absolute_path() and path.contains("/jiaoben/tmp/performance-v47/gameplay-reference.gd") and not path.contains("..") and FileAccess.get_sha256(path)=="239cbc7675a912565b1853b59e7fa93df4da8119a3874ce83efcb28ad9695c9f","pinned prior spawn algorithm (class declaration removed for co-loading)"):return
	var before: XJRuntimeState=store.clone_state(state);var after: XJRuntimeState=store.clone_state(state)
	var stable_reference: GDScript=GDScript.new()
	stable_reference.source_code="extends "+JSON.stringify(path)+"\nfunc id(prefix: String) -> String:\n\t_serial+=1;return \"%s_%s_%d_fixture_%d\" % [prefix,state.world_id,state.snapshot.meta.simulation_tick,_serial]\n"
	if not check(stable_reference.reload()==OK,"reference uses the same declared identity clock"):return
	var prior: RefCounted=stable_reference.new();prior.setup(before,store.catalog)
	var current: Gameplay=StableIds.new();current.setup(after,store.catalog)
	compare_spawns(before,after,"initial ordinary and managed NPC identities and RNG match")
	for business: RefCounted in [prior,current]:
		for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
		business.missions.refresh()
	prior._sync_spawns(0.0);current._sync_spawns(0.0)
	compare_spawns(before,after,"new unlocks still create exactly the original ordinary and managed actors")
	for business: RefCounted in [prior,current]:
		var mission: RefCounted=preload("res://contracts/contract_dtos.gd").MissionStateDto.new()
		mission.mission_instance_id="cache-combat-fixture";mission.player_id=business.state.player().player_id;mission.mission_def_id="tutorial_combat";mission.status="active";mission.attempt_number=1;business.state.add("mission_state",mission)
		for objective: Dictionary in business.missions.objectives("tutorial_combat"):
			var progress: RefCounted=preload("res://contracts/contract_dtos.gd").MissionObjectiveStateDto.new()
			progress.mission_instance_id=mission.mission_instance_id;progress.mission_def_id=mission.mission_def_id;progress.objective_index=objective.objective_index;business.state.add("mission_objective_state",progress)
	prior._sync_spawns(0.0);current._sync_spawns(0.0)
	compare_spawns(before,after,"mission-scoped activation keeps actor generation and RNG exact")
	for business: RefCounted in [prior,current]:
		business.exploration.managed_spawns["spawn_echo_raider"]=true
		for npc: RefCounted in business.state.rows("npc_state"):
			if npc.spawn_id=="spawn_echo_patrol_escort":npc.alive=false;npc.hull=0; npc.respawn_remaining_s=0.001
	prior._sync_spawns(0.01);current._sync_spawns(0.01)
	compare_spawns(before,after,"dynamic exploration ownership and finite respawn clocks stay live")
	for business: RefCounted in [prior,current]:
		business.exploration.managed_spawns.erase("spawn_echo_raider")
		business.state.find("mission_state","mission_instance_id","cache-combat-fixture").status="abandoned"
	prior._sync_spawns(0.01);current._sync_spawns(0.01)
	compare_spawns(before,after,"abandonment retires original mission actors without duplicating assets")
	current.setup(after,store.catalog);prior.setup(before,store.catalog)
	compare_spawns(before,after,"new setup rebuilds derived spawn ownership with exact persisted state")
	prior.dispose();current.dispose()
func compare_spawns(before: XJRuntimeState,after: XJRuntimeState,label: String) -> void:
	var sig=preload("snapshot_signature.gd");var left: String=sig.runtime(before);var right: String=sig.runtime(after)
	if left!=right:
		var output:=FileAccess.open(directory.path_join("spawn-diff-%d.json" % checks),FileAccess.WRITE)
		output.store_string(JSON.stringify({"label":label,"before":JSON.parse_string(left),"after":JSON.parse_string(right)}));output.close()
	check(left==right,label)
func finish() -> void:
	if store!=null:store.close();store=null
	state=null
	var result: String="PASS" if failures.is_empty() else "FAIL"
	print("MARKET_CACHE_V47_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":108}))
	print("MARKET_CACHE_V47_RESULT ",result," checks=",checks," failures=",failures.size());await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
