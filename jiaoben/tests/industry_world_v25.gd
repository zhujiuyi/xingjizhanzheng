extends "civilization_world_v24.gd"
## Reuse native pointer/capture helpers; execute only the industrial scenario below.
var blueprint: String = ""
var output: String = ""

func _ready() -> void:
	get_tree().set_meta("xj_industry_world_v25_diagnostic", true)
	get_tree().create_timer(180.0).timeout.connect(func(): check(false, "industry native watchdog"); finish())
	run.call_deferred()

func recipe_row() -> Dictionary:
	for row: Dictionary in host.ui.quotes:
		if row.action == "manufacture" and row.target == blueprint: return row
	return {}

func run() -> void:
	directory = OS.get_environment("XJ_INDUSTRY_WORLD_V25_DIRECTORY").replace("\\", "/")
	if not check(DisplayServer.get_name() != "headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/industry-world-v25/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "native industry requires fresh scoped SQLite and a real renderer"):
		await finish(); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900)
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host)
	await frames(5)
	if not check(host.services_ready, "native Main starts actual game resources"): await finish(); return
	await host._command("new_world", "工业与补给原生验收", 1, "")
	await settle()
	if not check(host.state != null, "native Main creates frozen industry world"): await finish(); return
	host.set_process(false); host.set_physics_process(false)
	var g: Gameplay = host.gameplay
	for def: Dictionary in host.store.catalog.rows("unlock_defs"): g.grant_unlock(def.unlock_id)
	host.state.player().credit = 1000000
	var warehouse: String = g.inventory.warehouse(g.station())
	for access: Dictionary in host.store.catalog.rows("recipe_access_defs"):
		if access.station_id != g.station(): continue
		var recipe: Dictionary = host.store.catalog.one("recipe_defs", "recipe_id", access.recipe_id)
		if not host.store.catalog.one("module_defs", "module_id", recipe.output_item_id).is_empty(): blueprint = access.recipe_id; output = recipe.output_item_id; break
	if not check(not blueprint.is_empty(), "native fixture has a real local blueprint"): await finish(); return
	for id: String in g.industry.inputs(blueprint, 1): g.inventory.grant(warehouse, id, 10000)
	await show("industry")
	var row: Dictionary = recipe_row()
	check(not row.is_empty() and row.description_label.text.contains("加工用时"), "actual recipe explains duration and delayed pickup")
	await capture("industry-before")
	var initial_count: int = g.inventory.count(warehouse, output, true)
	await click(row.button, "submit actual manufacturing order")
	var jobs: Array = g.industry.jobs(g.station())
	if not check(jobs.size() == 1 and jobs[0].status == "running" and g.inventory.count(warehouse, output, true) == initial_count, "native click queues paid manufacturing instead of granting output"):
		await finish(); return
	var job: D.IndustryJobStateDto = jobs[0]
	await show("industry")
	var claim: Button = host.ui.body.find_child("IndustryClaim_" + job.job_id, true, false)
	check(claim != null and claim.disabled, "actual unfinished pickup button is disabled")
	await reveal(claim)
	await capture("industry-running")
	# Test the real Main fixed-step integration for a short interval. Long timer
	# boundaries use the same production timer service without simulating unrelated star systems.
	var before: float = job.remaining_s
	for frame: int in range(12): host._physics_process(1.0 / float(g.rule("simulation_hz")))
	check(job.remaining_s < before, "real Main physics advances queued work")
	g.industry.tick(job.remaining_s + 0.1)
	await get_tree().create_timer(0.3).timeout
	check(not claim.disabled and job.status == "ready", "live panel enables pickup without replacing its control")
	await reveal(claim)
	await capture("industry-ready")
	var stale: Node = claim.get_parent().get_parent().get_parent()
	var requests: Array = []
	var observer: Callable = func(action: String, target: String, quantity: int, extra: String): requests.append([action, target, quantity, extra])
	host.ui.requested.connect(observer)
	host.ui.refresh_page()
	stale.call("_request", "claim_industry", job.job_id, 1, "")
	check(requests.is_empty() and job.status == "ready", "stale industrial panel cannot request assets after page regeneration")
	await frames(4)
	claim = host.ui.body.find_child("IndustryClaim_" + job.job_id, true, false)
	host.ui.requested.disconnect(observer)
	await click(claim, "claim actual finished product")
	check(job.status == "claimed" and g.inventory.count(warehouse, output, true) > initial_count, "native pickup grants real manufactured module exactly once")
	await show("industry")
	await click(recipe_row().button, "submit cancellation fixture")
	jobs = g.industry.jobs(g.station())
	if not check(jobs.size() == 1, "second native order exists"): await finish(); return
	job = jobs[0]
	await click(host.ui.body.find_child("IndustryCancel_" + job.job_id, true, false), "cancel actual running order")
	check(job.status == "cancelled" and g.industry.jobs(g.station()).is_empty(), "native cancellation settles and removes active order")
	host.ui.page_scroll.scroll_vertical = 0
	await capture("industry-cancelled")
	var demand: Dictionary = g.industry.demands(g.station())[0]
	g.inventory.grant(warehouse, demand.item_id, int(demand.required_units))
	await show("industry")
	var quantity: SpinBox = host.ui.body.find_child("DemandQuantity_" + str(demand.demand_id), true, false)
	var line: LineEdit = quantity.get_line_edit()
	var demand_panel: Node = quantity.get_parent().get_parent().get_parent()
	requests.clear(); host.ui.requested.connect(observer)
	for invalid: String in ["0", "-1", "1.5", "NaN", "999999"]:
		line.text = invalid
		demand_panel.call("_deliver_request", str(demand.demand_id), quantity, str(demand.state.generation))
		check(requests.is_empty(), "invalid demand quantity cannot dispatch " + invalid)
	line.text = "1"
	demand_panel.call("_request", "deliver_demand", str(demand.demand_id), 1, str(demand.state.generation - 1))
	check(requests.is_empty(), "obsolete demand quote cannot dispatch from a still-live panel")
	host.ui.requested.disconnect(observer)
	await click(line, "focus demand quantity")
	line.select_all()
	for character: String in str(demand.required_units):
		var input: InputEventKey = InputEventKey.new(); input.unicode = character.unicode_at(0); input.pressed = true
		root.push_input(input, true)
	await key(KEY_ENTER)
	await get_tree().create_timer(0.3).timeout
	var credit: int = host.state.player().credit
	await click(host.ui.body.find_child("DemandDeliver_" + str(demand.demand_id), true, false), "deliver full real regional need")
	check(demand.state.status == "cooldown" and demand.state.completed_cycles == 1 and host.state.player().credit == credit + int(demand.required_units) * int(demand.unit_reward_credit), "native quantity delivery consumes actual material and pays one cycle")
	await capture("industry-demand-completed")
	root.size = Vector2i(1280, 720); root.content_scale_factor = 2.0
	await show("industry")
	await click(recipe_row().button, "compact high-scale manufacturing")
	job = g.industry.jobs(g.station())[0]
	await show("industry")
	var cancel: Button = host.ui.body.find_child("IndustryCancel_" + job.job_id, true, false)
	await reveal(cancel)
	check(Rect2(Vector2.ZERO, host.ui.root.size).encloses(cancel.get_global_rect()), "compact 200-percent queue action is reachable")
	await capture("industry-1280-200")
	await click(cancel, "compact actual cancellation")
	root.size = Vector2i(3440, 1370); root.content_scale_factor = 1.0
	await show("industry")
	await capture("industry-ultrawide")
	var viewport: Rect2 = root.get_visible_rect()
	var transform: Transform2D = root.get_final_transform()
	var physical: Vector2 = Vector2(DisplayServer.window_get_size(root.get_window_id()))
	check((transform * viewport.position).length() <= 2.5 and (transform * viewport.end).distance_to(physical) <= 3.0, "ultrawide canvas covers the complete physical client area")
	check(host.store.save(host.state, "manual", 0), "native industrial receipts save to SQLite")
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(5)
	await get_tree().create_timer(0.25).timeout
	var helper: String = get_script().resource_path.get_base_dir().path_join("civilization_world_v24.gd")
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory, "native_helper_sha256": FileAccess.get_sha256(helper)}
	print("INDUSTRY_WORLD_V25_FINAL_JSON ", JSON.stringify(summary))
	print("INDUSTRY_WORLD_V25_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
