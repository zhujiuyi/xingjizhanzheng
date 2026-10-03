extends SceneTree
const Store = preload("res://runtime/data/store.gd")
const State = preload("res://runtime/state.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Rng = preload("res://runtime/rng.gd")
var failures: Array[String] = []
var checks: int = 0
class FaultStore extends Store:
	var fault: String = ""
	func _checkpoint(point: String) -> bool:
		return point != fault

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func encoded_rows(state: State, table: String) -> Array[String]:
	var result: Array[String] = []
	var codec: Codec = Codec.new()
	for row: RefCounted in state.rows(table): result.append(JSON.stringify(codec.encode_row(table, row), "", true, true))
	result.sort()
	return result

func _initialize() -> void:
	var full: bool = OS.get_cmdline_user_args().has("current")
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/store-native-full.db" if full else "res://../jiaoben/tmp/store-native-b.db")
	DirAccess.remove_absolute(path)
	var store: FaultStore = FaultStore.new(path)
	if not full: store.catalog_path = ProjectSettings.globalize_path("res://../jiaoben/tests/store_fixtures/catalog-b-baseline.db")
	check(store.open(), "native store open " + store.last_error)
	if not failures.is_empty():
		quit(1)
		return
	var registered: Array[String] = []
	for entry: Dictionary in store._records("SELECT name FROM sqlite_schema WHERE type='table' AND name LIKE '%_state' ORDER BY name COLLATE BINARY"): registered.append(entry.name)
	var expected_registry: Array[String] = State.TABLES.duplicate()
	expected_registry.sort()
	check(registered == expected_registry, "actual migrated SQL state registry equals every runtime DTO group")
	var state: State = store.new_world("新档原生测试", 42)
	check(state != null, "native new world " + store.last_error)
	if state == null:
		store.close()
		quit(1)
		return
	check(state.player().credit == int(store.catalog.rows("starting_profile_defs")[0].starting_credit), "initial grant derived from DB")
	check(state.rows("mission_state").is_empty() and not state.rows("mission_availability_state").is_empty(), "offers separate from attempts")
	if full:
		check(state.rows("encounter_state").size() == store.catalog.rows("encounter_defs").size(), "fresh world includes every frozen combat site state")
	else:
		check(state.rows("encounter_state").is_empty() and state.rows("salvage_package_state").is_empty(), "historical frozen world gains no unrelated new content state")
	var cursor: Rng = Rng.new(state.rows("rng_state")[0])
	var official: Array[int] = [0xa15c02b7, 0x7b47f409, 0xba1d3330, 0x83d2f293, 0xbfa4784b, 0xcbed606e]
	var golden: bool = cursor.valid()
	for expected in official: golden = golden and cursor.next_uint32() == expected
	check(golden, "native PCG32 official 42/54 sequence")
	var prior_catalog = store.catalog
	var prior_worlds: int = int(store._records("SELECT count(*) AS n FROM world")[0].n)
	var rejected_new: State = store.new_world("场景失败新档", 97, func(candidate: State) -> bool:
		check(store.staging_catalog != null and store.staging_catalog.content_hash == candidate.snapshot.content.content_hash, "new world staging has complete verified content identity")
		return false)
	check(rejected_new == null and store.active_state == state and store.catalog == prior_catalog and store.staging_catalog == null, "failed new world retains old active world/catalog")
	check(int(store._records("SELECT count(*) AS n FROM world")[0].n) == prior_worlds, "failed new world rolls back all persistent world records")
	check(store.save(state), "old world remains savable after new scene failure")
	var codec: Codec = Codec.new()
	for table in State.TABLES:
		var sample: RefCounted = State.new_row(table)
		for property in Codec._properties(sample):
			var key: String = table + ":" + property
			if Codec.ENUMS.has(key): sample.set(property, Codec.ENUMS[key].size() - 1)
			else:
				match Codec._properties(sample)[property]:
					TYPE_BOOL: sample.set(property, true)
					TYPE_INT: sample.set(property, 123)
					TYPE_FLOAT: sample.set(property, 123.25)
					TYPE_STRING: sample.set(property, "字段_" + table)
		var encoded: Dictionary = codec.encode_row(table, sample)
		var decoded: RefCounted = codec.decode_row(table, encoded)
		check(decoded != null and codec.encode_row(table, decoded) == encoded, "every typed field roundtrip " + table)
	if full:
		# Historical source identities deliberately have no live NPC row: their
		# packages must survive retiring an old combat generation.
		var package_definition: Dictionary = store.catalog.rows("salvage_package_defs")[0]
		var reward: Dictionary = store.catalog.one("salvage_reward_defs", "package_def_id", package_definition.package_def_id)
		for opened: bool in [false, true]:
			var package: Dtos.SalvagePackageStateDto = Dtos.SalvagePackageStateDto.new()
			package.package_id = "native-opened-package" if opened else "native-sealed-package"
			package.package_def_id = package_definition.package_def_id
			package.source_npc_instance_id = "retired-native-npc-opened" if opened else "retired-native-npc-sealed"
			package.source_generation = 3
			package.reward_id = reward.reward_id
			package.status = "opened" if opened else "sealed"
			package.has_host_container_id = not opened
			package.host_container_id = "" if opened else "hold-cargo"
			package.has_opened_station_id = opened
			package.opened_station_id = state.player().docked_station_id if opened else ""
			package.opened_tick = state.snapshot.meta.simulation_tick if opened else 0
			check(state.add("salvage_package_state", package), "add valid independent " + package.status + " recovery package")
		var group: Dtos.EncounterStateDto = state.rows("encounter_state")[0]
		group.generation = 3
		group.respawn_remaining_s = float(store.catalog.one("encounter_defs", "encounter_id", group.encounter_id).respawn_seconds) / 4.0
		var facility: Dtos.BaseModuleStateDto = Dtos.BaseModuleStateDto.new()
		facility.player_id = state.player().player_id
		facility.base_instance_id = "native-test-facility"
		facility.base_module_id = store.catalog.rows("base_module_defs")[0].base_module_id
		facility.station_id = state.player().docked_station_id
		facility.enabled = true
		state.add("base_module_state", facility)
		var engine: Dtos.EquipmentStateDto = state.find("equipment_state", "module_def_id", "module_engine_vector_i")
		var instance: Dtos.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", engine.item_instance_id)
		var original_recipe: String = instance.salvage_recipe_id
		for definition_id in ["module_engine_vector_ii", "module_engine_vector_iii"]:
			var definition: Dictionary = store.catalog.one("module_defs", "module_id", definition_id)
			engine.module_def_id = definition_id
			instance.item_def_id = definition_id
			instance.salvage_recipe_id = store.catalog.one("recipe_defs", "output_item_id", definition_id).recipe_id
			engine.active_remaining_s = float(definition.cycle_s)
			engine.cooldown_remaining_s = float(definition.cycle_s)
			engine.cycle_paid = true
			check(store.save(state), "paid advanced engine cycle is durable " + definition_id + " " + store.last_error)
		engine.module_def_id = "module_engine_vector_i"
		instance.item_def_id = "module_engine_vector_i"
		instance.salvage_recipe_id = original_recipe
		engine.active_remaining_s = 0.0
		engine.cooldown_remaining_s = 0.0
		engine.cycle_paid = false
	var slot: Dictionary = store.list_slots()[0]
	state.player().credit -= 1
	check(store.save(state), "native complete snapshot COMMIT " + store.last_error)
	var saved_snapshot: String = state.snapshot.meta.snapshot_id
	var credit: int = state.player().credit
	for point in ["state", "seal", "pointer"]:
		store.fault = point
		var before: Dictionary = store.list_slots()[0]
		state.player().credit -= 1
		check(not store.save(state), "fault " + point + " rejected")
		check(store.list_slots()[0].current_snapshot_id == before.current_snapshot_id and store.list_slots()[0].generation == before.generation, "fault " + point + " preserves endpoint")
		state.player().credit += 1
	store.fault = ""
	var old: State = store.clone_state(state)
	var epoch: int = state.epoch
	var selected: Dictionary = store.list_slots()[0]
	var failed: State = store.load(selected.slot_id, selected.current_snapshot_id, selected.generation, func(_candidate: State) -> bool:
		check(store.staging_catalog != null and store.staging_catalog.content_hash == _candidate.snapshot.content.content_hash, "staging exposes candidate frozen definitions")
		return false)
	check(failed == null and store.active_state.epoch == epoch, "staging failure preserves old epoch")
	check(store.staging_catalog == null, "failed staging reference cleared")
	check(store.save(state), "old world savable after prepare failure")
	check(store.load(slot.slot_id, slot.current_snapshot_id, slot.generation) == null, "stale UI selection rejected")
	selected = store.list_slots()[0]
	store.close()
	check(store.open(), "reopen migrated store " + store.last_error)
	var loaded: State = store.load(selected.slot_id, selected.current_snapshot_id, selected.generation)
	check(loaded != null, "native load after reopen " + store.last_error)
	if loaded != null:
		check(loaded.player().credit == credit, "committed credit restored")
		check(loaded.rows("equipment_state").size() == old.rows("equipment_state").size(), "typed equipment restored")
		for table: String in State.TABLES:
			check(encoded_rows(loaded, table) == encoded_rows(old, table), "SQL reopen restores complete typed row payload " + table)
		var resumed_rng: Rng = Rng.new(loaded.rows("rng_state")[0])
		var reference_rng: Rng = Rng.new(old.rows("rng_state")[0])
		var sequence_matches: bool = true
		for _index in range(128): sequence_matches = sequence_matches and resumed_rng.next_uint32() == reference_rng.next_uint32()
		check(sequence_matches, "native RNG exact 128 outputs after SQL restore")
		check(loaded.rows("resource_state").size() == store.catalog.rows("resource_node_defs").size(), "all resources restored")
		if full: check(loaded.rows("base_module_state").size() == 1 and loaded.rows("base_module_state")[0].enabled, "relational facility restored")
		check(loaded.snapshot.meta.snapshot_id != saved_snapshot, "later success endpoint selected")
		check(not store.save(old), "old session writer rejected after load")
		var backup_path: String = path.get_base_dir().path_join("store-native-backup.db")
		check(store.backup(backup_path), "native Backup API " + store.last_error)
		check(store.prune(1), "retention preserves live references")
		check(store.save(loaded, "manual", 0), "new epoch manual save")
		var manual_id: String = loaded.snapshot.meta.snapshot_id
		var resumed: State = store.resume()
		check(resumed != null and resumed.snapshot.meta.snapshot_id == manual_id, "resume uses last legal endpoint including manual")
		check(store.set_preference("master_volume", 0.37), "preferences persist separately")
		check(not store.set_preference("master_volume", -1), "invalid preferences rollback")
		store.close()
		check(store.open() and abs(float(store.preferences().master_volume) - 0.37) < 0.000001, "preferences survive reopen")
		var second: State = store.new_world("第二世界", 73)
		check(second != null and second.world_id != loaded.world_id, "second world identity distinct")
		var first_again: State = store.load(selected.slot_id)
		check(first_again != null and first_again.world_id == loaded.world_id, "activate older world's selected endpoint")
		store.close()
		check(store.open(), "reopen after cross-world selection")
		var cross_resume: State = store.resume()
		check(cross_resume != null and cross_resume.world_id == loaded.world_id, "resume preserves activated world after reopen")
	store.close()
	print("STORE_NATIVE_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
