extends Node
## Fresh fixtures exercise real services and SQLite. Supplied stock/unlocks are explicit test preconditions.
const Store = preload("res://runtime/data/store.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Validation = preload("res://runtime/data/validation.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
class FaultStore extends Store:
	var failure: String = ""
	func _checkpoint(point: String) -> bool: return point != failure
var store: Store
var state: XJRuntimeState
var g: Gameplay
var failures: Array[String] = []
var checks: int = 0
var directory: String

func _ready() -> void:
	get_tree().set_meta("xj_industry_v25_diagnostic", true)
	get_tree().create_timer(90.0).timeout.connect(func(): print("INDUSTRY_RESULT FAIL watchdog"); quit(2))
	_run.call_deferred()
func quit(code: int) -> void: get_tree().quit(code)
func check(condition: bool, text: String) -> bool:
	checks += 1
	print(("PASS " if condition else "FAIL ") + text)
	if not condition: failures.append(text)
	return condition
func act(kind: String, target: String = "", quantity: int = 1, extra: String = "") -> bool:
	return g.act(kind, target, quantity, extra).phase == T.ActionPhase.APPLIED
func fingerprint() -> Dictionary:
	var result: Dictionary = {"credit": state.player().credit}
	for table: String in ["inventory_stack_state", "item_instance_state", "industry_job_state", "industry_input_state", "station_demand_state", "production_state"]:
		var rows: Array = []
		for row: RefCounted in state.rows(table): rows.append(Codec.new().encode_row(table, row))
		result[table] = rows
	return result
func validate(label: String) -> void:
	var validator: Validation = Validation.new()
	check(validator.validate(state, store.catalog), label + ": " + validator.last_error)
func setup() -> void:
	g = Gameplay.new(); g.setup(state, store.catalog)
	for definition: Dictionary in store.catalog.rows("unlock_defs"): g.grant_unlock(definition.unlock_id)
	state.player().credit = 1000000

func _run() -> void:
	directory = OS.get_environment("XJ_INDUSTRY_V25_DIRECTORY").replace("\\", "/")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/industry-v25/" + str(Time.get_ticks_usec())).simplify_path()
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/industry-v25/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "business suite requires fresh scoped SQLite"): quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	store = Store.new(directory.path_join("progress.db"))
	if not check(store.open(), "open fresh format10 store: " + store.last_error): quit(1); return
	state = store.new_world("Industry fixtures", 2511)
	if not check(state != null, "create frozen industry world: " + store.last_error): store.close(); quit(1); return
	setup()
	check(g.industry.supported() and state.rows("station_demand_state").size() == store.catalog.rows("station_demand_defs").size(), "regional needs initialized from frozen definitions")
	var warehouse: String = g.inventory.warehouse(g.station())
	var blueprint: String = ""
	var output: String = ""
	for access: Dictionary in store.catalog.rows("recipe_access_defs"):
		if access.station_id != g.station(): continue
		var recipe: Dictionary = store.catalog.one("recipe_defs", "recipe_id", access.recipe_id)
		if not store.catalog.one("module_defs", "module_id", recipe.output_item_id).is_empty(): blueprint = access.recipe_id; output = recipe.output_item_id; break
	if not check(not blueprint.is_empty(), "fixture chooses a real local module blueprint"): g.dispose(); store.close(); quit(1); return
	var inputs: Dictionary = g.industry.inputs(blueprint, 1)
	for item_id: String in inputs: g.inventory.grant(warehouse, item_id, 100000)
	var start_count: int = g.inventory.count(warehouse, output, true)
	var credit: int = state.player().credit
	var fee: int = g.economy.quote_manufacture(blueprint, 1)
	check(act("manufacture", blueprint), "submit manufacturing through production action")
	var first: D.IndustryJobStateDto = g.industry.jobs(g.station())[0]
	check(first.status == "running" and first.paid_credit == fee and state.player().credit == credit - fee, "first job starts and exact fee is escrowed")
	check(g.inventory.count(warehouse, output, true) == start_count, "submission does not issue the output immediately")
	for item_id: String in inputs: check(g.inventory.count(warehouse, item_id, true) == 100000 - int(inputs[item_id]), "exact material escrow " + item_id)
	var before: Dictionary = fingerprint()
	check(not act("manufacture", blueprint, int(g.industry.balance.max_batches) + 1) and fingerprint() == before, "oversized order has no side effects")
	check(not act("claim_industry", first.job_id) and fingerprint() == before, "unfinished order cannot be claimed")
	for index: int in range(int(g.industry.balance.queue_limit) - 1): check(act("manufacture", blueprint), "queue additional order " + str(index))
	before = fingerprint()
	check(not act("manufacture", blueprint) and fingerprint() == before, "full queue rejects without consuming materials")
	var waiting: D.IndustryJobStateDto = g.industry.jobs(g.station())[-1]
	credit = state.player().credit
	var amounts: Dictionary = {}
	for item_id: String in inputs: amounts[item_id] = g.inventory.count(warehouse, item_id, true)
	check(act("cancel_industry", waiting.job_id), "cancel queued job")
	check(state.player().credit == credit + waiting.paid_credit, "queued cancellation refunds service fee")
	for item_id: String in inputs: check(g.inventory.count(warehouse, item_id, true) == int(amounts[item_id]) + int(inputs[item_id]), "queued cancellation refunds exact material " + item_id)
	before = fingerprint()
	check(not act("cancel_industry", waiting.job_id) and fingerprint() == before, "cancel cannot be replayed")
	g.industry.tick(first.duration_s * 0.5)
	check(first.remaining_s > 0 and first.remaining_s < first.duration_s, "world time advances partial production")
	check(store.save(state, "manual", 0), "save running job and regional timers: " + store.last_error)
	if OS.get_environment("XJ_INDUSTRY_FIXTURE_ONLY") == "1":
		if OS.get_environment("XJ_TACTICS_FIXTURE_BAY") == "1":
			var hull: RefCounted = g.inventory.create_ship("cruiser_horizon", g.station())
			state.player().controlled_ship_id = hull.ship_instance_id
			var bay: String = g.inventory.grant(g.inventory.warehouse(g.station()), "module_drone_swarm_ii", 1)[0]
			check(act("fit_module", bay, 1, "weapon"), "old tactics fixture legally installs an existing drone bay")
			check(store.save(state, "manual", 0), "old tactics fixture keeps paid orders and usable drone bay")
		print("INDUSTRY_FIXTURE_READY ", JSON.stringify({"database": store.path, "format": store._records("SELECT format_version FROM database_meta")[0].format_version, "content_hash": store.catalog.content_hash, "jobs": g.industry.jobs().size()}))
		g.dispose(); store.close(); quit(0); return
	var slot: String = ""
	for row: Dictionary in store.list_slots():
		if row.slot_kind == "manual" and int(row.slot_index) == 0: slot = row.slot_id
	var remaining: float = first.remaining_s
	g.dispose(); g = null
	state = store.load(slot)
	if not check(state != null, "reload paused production: " + store.last_error): store.close(); quit(1); return
	g = Gameplay.new(); g.setup(state, store.catalog)
	first = state.find("industry_job_state", "job_id", first.job_id)
	check(is_equal_approx(first.remaining_s, remaining), "load does not use real elapsed time or duplicate inputs")
	credit = state.player().credit
	amounts.clear()
	for item_id: String in inputs: amounts[item_id] = g.inventory.count(warehouse, item_id, true)
	check(act("cancel_industry", first.job_id), "cancel running job")
	check(state.player().credit == credit, "running cancellation keeps disclosed service fee")
	for item_id: String in inputs: check(g.inventory.count(warehouse, item_id, true) == int(amounts[item_id]) + int(floor(float(inputs[item_id]) * 0.8)), "running cancellation refunds disclosed rounded material " + item_id)
	var remaining_jobs: Array = g.industry.jobs(g.station())
	check(remaining_jobs[0].status == "running", "next queued job promoted after cancellation")
	var duration: float = 0.0
	for job: D.IndustryJobStateDto in remaining_jobs: duration += job.remaining_s
	g.industry.tick(duration + 1.0)
	for job: D.IndustryJobStateDto in remaining_jobs:
		check(job.status == "ready", "serial jobs complete with exact world-time budget")
		check(act("claim_industry", job.job_id), "claim completed module")
		before = fingerprint()
		check(not act("claim_industry", job.job_id) and fingerprint() == before, "completed output cannot be duplicated")
	check(g.inventory.count(warehouse, output, true) == start_count + remaining_jobs.size(), "one output batch per claimed job")
	for item: D.ItemInstanceStateDto in state.rows("item_instance_state"):
		if item.item_def_id != output or not item.has_manufacture_batch_id: continue
		check(not g.economy._inputs("recipe_inputs", "recipe_id", blueprint, 1).is_empty() and state.find("production_state", "production_id", item.manufacture_batch_id) != null, "manufactured module retains production and recycle provenance")
	var demand: Dictionary = g.industry.demands(g.station())[0]
	var need: D.StationDemandStateDto = demand.state
	g.inventory.grant(warehouse, demand.item_id, int(demand.required_units))
	before = fingerprint()
	check(not act("deliver_demand", demand.demand_id, 1, str(need.generation - 1)) and fingerprint() == before, "stale demand quote rejected atomically")
	credit = state.player().credit
	var material: int = g.inventory.count(warehouse, demand.item_id, true)
	check(act("deliver_demand", demand.demand_id, 10, str(need.generation)), "partial demand delivery")
	check(state.player().credit == credit + 10 * int(demand.unit_reward_credit) and g.inventory.count(warehouse, demand.item_id, true) == material - 10 and need.remaining_units == int(demand.required_units) - 10, "partial demand consumes real warehouse material and pays exact reward")
	var normal_fee: int = g.economy.quote_manufacture(blueprint, 1)
	check(act("deliver_demand", demand.demand_id, need.remaining_units, str(need.generation)), "complete regional supply cycle")
	check(need.status == "cooldown" and need.completed_cycles == 1 and g.industry.discount(g.station()) < 1.0 and g.economy.quote_manufacture(blueprint, 1) <= normal_fee, "completion grants a real bounded industry benefit")
	before = fingerprint()
	check(not act("deliver_demand", demand.demand_id, 1, str(need.generation)) and fingerprint() == before, "fulfilled demand cannot receive another payment")
	var generation: int = need.generation
	g.industry.tick(float(demand.cooldown_s) + 0.1)
	check(need.status == "active" and need.generation == generation + 1 and need.remaining_units == int(demand.required_units), "world-time cooldown renews a fresh demand generation")
	before = fingerprint()
	check(not act("deliver_demand", demand.demand_id, 1, str(generation)) and fingerprint() == before, "old generation cannot affect renewed demand")
	var stock: D.ShopStockStateDto = g.economy._stock(demand.item_id)
	if stock != null:
		var original: int = stock.quantity
		stock.quantity = 0
		var low: float = g.industry.price_factor(demand.item_id)
		stock.quantity = int(g.economy._stock_def(demand.item_id).hard_cap_units)
		var high: float = g.industry.price_factor(demand.item_id)
		check(low > high and low <= 1.15 and high >= 0.85, "NPC prices respond to inventory within frozen limits")
		stock.quantity = original
	_hulls_and_protection()
	validate("valid industry state after claim cancellation and delivery")
	check(store.save(state, "manual", 1), "persist receipts and completed cycle: " + store.last_error)
	var corrupted: XJRuntimeState = store.clone_state(state)
	corrupted.rows("industry_input_state")[0].quantity += 1
	var validator: Validation = Validation.new()
	check(not validator.validate(corrupted, store.catalog), "semantic validator rejects forged material escrow")
	corrupted = null
	g.dispose(); g = null; store.close(); store = null; state = null
	_upgrade()
	if not OS.get_environment("XJ_INDUSTRY_LEGACY_DATABASE").is_empty(): _real_legacy_upgrade()
	print("INDUSTRY_FINAL_JSON ", JSON.stringify({"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "directory": directory, "actual_legacy_verified": not OS.get_environment("XJ_INDUSTRY_LEGACY_DATABASE").is_empty()}))
	print("INDUSTRY_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size(), " directory=", directory)
	await get_tree().process_frame
	quit(0 if failures.is_empty() else 1)

func _hulls_and_protection() -> void:
	var warehouse: String = g.inventory.warehouse(g.station())
	var hull: Dictionary = {}
	for recipe: Dictionary in g.rows("hull_recipe_defs"):
		if g.economy._ship_stock(recipe.ship_id) != null and g.civilizations.hull_reason(recipe.ship_id).is_empty(): hull = recipe; break
	if check(not hull.is_empty(), "local public hull has a real construction route"):
		for id: String in g.industry.inputs(hull.hull_recipe_id, 1): g.inventory.grant(warehouse, id, 10000)
		var count: int = state.rows("ship_state").size()
		check(act("manufacture", hull.hull_recipe_id), "submit actual hull order")
		var job: D.IndustryJobStateDto = g.industry.jobs(g.station())[0]
		check(state.rows("ship_state").size() == count, "hull submission does not create an early ship")
		g.industry.tick(job.duration_s + 0.1)
		var station: String = g.station()
		check(act("undock"), "real undock for remote pickup rejection")
		var before: Dictionary = fingerprint()
		check(not act("claim_industry", job.job_id) and fingerprint() == before, "flying player cannot remotely claim finished hull")
		var station_def: Dictionary = g.definition("station_defs", "station_id", station)
		var dock_anchor: Dictionary = g.definition("anchor_defs", "anchor_id", station_def.station_anchor_id)
		# Explicit arrival pose: navigation is independently exercised in the native suite.
		state.ship().pos_x = dock_anchor.x_m; state.ship().pos_y = dock_anchor.y_m; state.ship().pos_z = dock_anchor.z_m
		check(act("dock", station), "return to actual construction station")
		check(act("claim_industry", job.job_id) and state.rows("ship_state").size() == count + 1, "pickup creates one legitimate bare hull at the original station")
		before = fingerprint()
		check(not act("claim_industry", job.job_id) and fingerprint() == before, "hull pickup cannot be replayed")
	var demand: Dictionary = g.industry.demands(g.station())[0]
	var material: String = demand.item_id
	var owned: int = g.inventory.count(warehouse, material, true)
	if owned > 0: g.inventory.consume(warehouse, material, owned, true)
	g.inventory.grant(warehouse, material, 100, state.ship().policy_id, "", "", T.ItemOrigin.GUARANTEE)
	var before: Dictionary = fingerprint()
	check(not act("deliver_demand", demand.demand_id, 1, str(demand.state.generation)) and fingerprint() == before, "protected supplies cannot be converted into demand rewards")
	g.inventory.grant(warehouse, material, owned)
	for recipe: Dictionary in g.rows("civilization_hull_defs"):
		before = fingerprint()
		var spec: Dictionary = g.definition("hull_recipe_defs", "ship_id", recipe.ship_id)
		if not spec.is_empty(): check(not act("manufacture", spec.hull_recipe_id) and fingerprint() == before, "neutral player cannot queue exclusive hull " + str(recipe.ship_id))

func _upgrade() -> void:
	for archive: String in ["res://data/catalog_space_v7.db","res://data/catalog_civilizations_v8.db"]:_upgrade_from(archive)
func _upgrade_from(archive: String) -> void:
	var legacy_path: String=directory.path_join(archive.get_file().get_basename()+".db")
	store = Store.new(legacy_path)
	store.catalog_path = archive
	if not check(store.open(), "create historical frozen civilization world"): return
	state = store.new_world("Legacy industry upgrade", 25)
	if not check(state != null, "legacy world created"): store.close(); return
	check(store.save(state, "manual", 0), "keep legacy manual slot")
	var old_credit: int = state.player().credit
	var old_ship: String = state.ship().ship_instance_id
	store.close()
	store = Store.new(legacy_path)
	if not check(store.open(), "new store opens legacy content without replacing it"): return
	var old_slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind == "manual": old_slot = row; break
	state = store.load(old_slot.slot_id)
	check(state != null and not store.catalog.table_names.has("industry_balance_defs"), "old manual retains its original frozen instant-manufacturing rules")
	var upgraded: XJRuntimeState = store.upgrade_content(state)
	if check(upgraded != null, "reviewed industry branch upgrade: " + store.last_error):
		check(upgraded.player().credit == old_credit and upgraded.ship().ship_instance_id == old_ship and upgraded.rows("industry_job_state").is_empty(), "upgrade preserves existing assets and invents no paid orders")
		if store.catalog.table_names.has("campaign_balance_defs"):
			check(upgraded.rows("exploration_belt_state").size()==4 and upgraded.rows("tactical_site_state").size()==9,"early upgrade initializes every belt and tactical site exactly once")
		check(upgraded.rows("station_demand_state").size() == store.catalog.rows("station_demand_defs").size(), "upgrade initializes only new region needs")
		check(store.upgrade_content(upgraded) == upgraded, "repeated upgrade reuses current rules")
	state = store.load(old_slot.slot_id)
	check(state != null and not store.catalog.table_names.has("industry_balance_defs") and state.player().credit == old_credit, "legacy manual is still independently restorable after branch upgrade")
	store.close(); store = null; state = null

func _real_legacy_upgrade() -> void:
	var source: String = OS.get_environment("XJ_INDUSTRY_LEGACY_DATABASE").replace("\\", "/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/") and not source.contains("..") and FileAccess.file_exists(source), "real legacy fixture stays in scoped tmp path"): return
	var copied: String = directory.path_join("actual-v016.db")
	if not check(DirAccess.copy_absolute(source, copied) == OK, "copy closed actual old EXE database without touching original"): return
	var faulty: FaultStore = FaultStore.new(copied)
	faulty.failure = "migration:013_industry.sql"
	store = faulty
	check(not store.open(), "interrupted actual format9 migration is rejected")
	check(int(store._records("SELECT format_version FROM database_meta")[0].format_version) == 9 and store._records("SELECT * FROM migration_history WHERE migration_id='013_industry.sql'").is_empty(), "failed migration rolls back metadata and checksum history")
	faulty.failure = ""
	if not check(store.open(), "retry migrates actual format9 database to format10: " + store.last_error): return
	check(FileAccess.file_exists(directory.path_join("migration-format9-backup.db")), "format upgrade creates a closed old-format backup")
	check(int(store._records("SELECT format_version FROM database_meta")[0].format_version) == 14, "actual legacy database reaches current format14")
	var slot: Dictionary
	for entry: Dictionary in store.list_slots():
		if entry.slot_kind == "manual": slot = entry; break
	state = store.load(slot.slot_id)
	if not check(state != null, "actual old manual loads with frozen historical rules: " + store.last_error): store.close(); return
	var credit: int = state.player().credit
	var ship: String = state.ship().ship_instance_id
	var previous_rng: Dictionary = Codec.new().encode_row("rng_state", state.rows("rng_state")[0])
	var count: int = store._records("SELECT count(*) AS n FROM content_snapshot")[0].n
	faulty.failure = "content_upgrade"
	check(store.upgrade_content(state) == null, "failed industry branch publication is rejected")
	check(store._records("SELECT count(*) AS n FROM content_snapshot")[0].n == count and store.active_state == state and state.player().credit == credit, "failed industry branch preserves old complete world and assets")
	faulty.failure = ""
	var upgraded: XJRuntimeState = store.upgrade_content(state)
	if check(upgraded != null, "actual v0.16 world branches to industrial rules: " + store.last_error):
		check(upgraded.player().credit == credit and upgraded.ship().ship_instance_id == ship and previous_rng == Codec.new().encode_row("rng_state", upgraded.rows("rng_state")[0]), "actual old assets and RNG survive new industrial branch")
	state = store.load(slot.slot_id)
	check(state != null and not store.catalog.table_names.has("industry_balance_defs") and state.player().credit == credit, "actual old manual remains recoverable after upgrade")
	store.close(); store = null; state = null
