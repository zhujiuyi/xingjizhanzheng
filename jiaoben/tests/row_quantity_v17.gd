extends Node
## Real Main, production requests and fresh SQLite. Catalog-derived funding,
## unlocks, granted inputs and station placement are explicit test fixtures.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Codec = preload("res://runtime/data/codec.gd")
var host: Main
var directory: String
var database_path: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var layouts: int = 0
var gui_transactions: int = 0
var stale_rejections: int = 0
var invalid_cases: int = 0
var blur_quote_checks: int = 0
var restarts: int = 0
var old_fps: int
var station_id: String
var warehouse: String
var parked_ship_id: String
var requested_events: Array[Dictionary] = []
var root: Window:
	get: return get_tree().root
var process_frame: Signal:
	get: return get_tree().process_frame

func _ready() -> void:
	get_tree().create_timer(360.0).timeout.connect(func(): print("ROW_QUANTITY_V17_RESULT FAIL watchdog"); get_tree().quit(1))
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	check(not host.busy, "real SQLite writer settles")

func start_host() -> bool:
	host = Main.new(); host.progress_database_path = database_path
	root.add_child(host); host.set_process(false); host.set_physics_process(false)
	await frames(4)
	if not check(host.services_ready, "Main opens production catalog and fresh scoped SQLite"): return false
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): requested_events.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
		if not check(root.has_focus(), "native row actions have real window focus"): return false
	return true

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null; await frames(3); await get_tree().create_timer(0.25).timeout

func command(action: String, target: String = "", quantity: int = 1, extra: String = "") -> void:
	host._command(action, target, quantity, extra); await frames(4); await wait_writer()

func show_page(page: String = "market", filter: String = "") -> void:
	if not filter.is_empty(): host.ui.market_filter = filter
	host.ui.show_page(page); await frames(4); host.ui.tick(1.0); await frames(3)

func quote_for(id: String) -> Dictionary:
	for quote: Dictionary in host.ui.quotes:
		if str(quote.get("target", "")) == id: return quote
	return {}

func business_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var view: Node = host.ui.get("business_list_view") as Node
	if is_instance_valid(view):
		for row: Dictionary in view.get("rows"): result.append(row)
	return result

func entry_for(id: String) -> Dictionary:
	for row: Dictionary in business_rows():
		if str(row.row.get_meta("row_id", "")) == id: return row
	return {}

func stock(id: String) -> D.ShopStockStateDto:
	return host.gameplay.get("economy").call("_stock", id) as D.ShopStockStateDto

func count(id: String, source: String = "") -> int:
	return int(host.gameplay.get("inventory").call("count", warehouse if source.is_empty() else source, id, true))

func totals() -> Dictionary:
	var result: Dictionary = {}
	for table: String in ["player_state", "container_state", "ship_state", "inventory_stack_state", "item_instance_state", "equipment_state", "shop_stock_state", "shop_ship_stock_state", "station_economy_state", "production_state", "manufacture_input_state", "industry_job_state", "industry_input_state", "station_demand_state"]:
		if not XJRuntimeState.TABLES.has(table): continue
		var rows: Array[String] = []
		for record: RefCounted in host.state.rows(table): rows.append(JSON.stringify(Codec.new().encode_row(table, record)))
		rows.sort(); result[table] = rows
	return result

func scroll_ancestors(control: Control) -> Array[ScrollContainer]:
	var result: Array[ScrollContainer] = []
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer: result.append(node)
		node = node.get_parent()
	return result

func reveal(control: Control) -> void:
	for scroll: ScrollContainer in scroll_ancestors(control): scroll.ensure_control_visible(control)
	await frames(5)

func viewport_rect() -> Rect2:
	return Rect2(Vector2.ZERO, host.ui.root.size)

func visible_control(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree() or not viewport_rect().encloses(control.get_global_rect()): return false
	for scroll: ScrollContainer in scroll_ancestors(control):
		if not scroll.get_global_rect().encloses(control.get_global_rect()): return false
	return true

func actual_click(button: Button, expected_action: String, expected_target: String = "") -> bool:
	if not check(button != null and not button.disabled, "legal action button exists " + expected_action): return false
	await reveal(button)
	var before_events: int = requested_events.size()
	var emitted: Dictionary = {"count": 0}
	var observer: Callable = func(): emitted["count"] = int(emitted["count"]) + 1
	button.pressed.connect(observer)
	var deadline: int = Time.get_ticks_msec() + 1500
	var ready: bool = false
	var stable: int = 0
	var previous: Rect2 = button.get_global_rect()
	while Time.get_ticks_msec() < deadline:
		if DisplayServer.get_name() != "headless" and not root.has_focus(): root.grab_focus()
		var center: Vector2 = button.get_global_rect().get_center()
		host.get_viewport().warp_mouse(center)
		var motion := InputEventMouseMotion.new()
		motion.position = center; motion.global_position = center
		host.get_viewport().push_input(motion, true)
		await process_frame
		var hover: Control = host.get_viewport().gui_get_hovered_control()
		var hover_ok: bool = hover != null and (hover == button or button.is_ancestor_of(hover))
		if DisplayServer.get_name() != "headless": hover_ok = hover_ok and root.has_focus() and button.get_global_rect().has_point(button.get_global_mouse_position())
		var current: Rect2 = button.get_global_rect()
		stable = stable + 1 if current.is_equal_approx(previous) and hover_ok and visible_control(button) else 0
		previous = current
		if stable >= 2: ready = true; break
	if not check(ready, "actual viewport GUI pointer/focus reaches action " + expected_action):
		print("ROW_QUANTITY_V17_GUI_TIMEOUT " + JSON.stringify({"action": expected_action, "page": host.ui.page, "rect": str(button.get_global_rect()), "focus": root.has_focus(), "hover": str(host.get_viewport().gui_get_hovered_control()), "pointer": str(button.get_global_mouse_position())}))
		button.pressed.disconnect(observer)
		return false
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		event.position = button.get_global_rect().get_center(); event.global_position = event.position
		host.get_viewport().push_input(event, true)
	await frames(4); await wait_writer()
	if is_instance_valid(button) and button.pressed.is_connected(observer): button.pressed.disconnect(observer)
	var matched: bool = requested_events.size() == before_events + 1
	if matched:
		var request: Dictionary = requested_events[-1]
		matched = str(request.action) == expected_action and (expected_target.is_empty() or str(request.target) == expected_target)
	var passed: bool = check(int(emitted["count"]) == 1 and matched, "one actual GUI click emits one production command " + expected_action)
	if passed: gui_transactions += 1
	return passed

func amount_for(id: String) -> SpinBox:
	return quote_for(id).get("amount") as SpinBox

func set_amount(id: String, quantity: int, dirty: bool = false) -> bool:
	var amount: SpinBox = amount_for(id)
	if not check(amount != null, "real independent amount editor exists " + id): return false
	if not dirty: amount.value = quantity; await frames(3); return true
	amount.value = 1; await reveal(amount)
	var edit: LineEdit = amount.get_line_edit(); edit.grab_focus(); await frames(3); edit.select_all()
	for index: int in range(str(quantity).length()):
		var character: String = str(quantity).substr(index, 1)
		for down: bool in [true, false]:
			var event := InputEventKey.new(); event.keycode = KEY_0 + int(character); event.physical_keycode = event.keycode
			event.unicode = character.unicode_at(0); event.pressed = down
			host.get_viewport().push_input(event, true); await frames(1)
	return check(host.get_viewport().gui_get_focus_owner() == edit and edit.text == str(quantity) and int(amount.value) != quantity, "GUI typed row quantity is genuinely unsubmitted " + id)

func execute(id: String, quantity: int, action: String, dirty: bool = false) -> bool:
	var quote: Dictionary = quote_for(id)
	if not check(not quote.is_empty(), "production business row exists " + id): return false
	if quote.get("amount") != null and not await set_amount(id, quantity, dirty): return false
	var before: int = requested_events.size()
	if not await actual_click(quote.get("button") as Button, action, str(quote.get("target", id))): return false
	return check(requested_events.size() == before + 1 and int(requested_events[-1].quantity) == quantity, "GUI transaction sends exact per-row amount " + id)

func prepare() -> bool:
	await command("new_world", "行内数量和紧凑仓储独立验收")
	if not check(host.state != null and host.state.player().has_docked_station_id, "fresh world starts legally at its formal station"): return false
	station_id = host.state.player().docked_station_id
	var inventory: RefCounted = host.gameplay.get("inventory")
	warehouse = str(inventory.call("warehouse", station_id))
	for unlock: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.call("grant_unlock", str(unlock.unlock_id))
	var funding: int = 0
	for definition: Dictionary in host.store.catalog.rows("ship_defs"): funding += int(host.gameplay.get("economy").call("quote_ship", str(definition.ship_id), false)) * 20
	host.state.player().credit += funding
	for definition: Dictionary in host.store.catalog.rows("item_defs"):
		if bool(definition.stackable): inventory.call("grant", warehouse, str(definition.item_id), 120)
	parked_ship_id = (inventory.call("create_ship", "miner_anvil", station_id) as D.ShipStateDto).ship_instance_id
	var cargo: String = str(inventory.call("hold", host.state.ship(), T.ContainerKind.CARGO))
	inventory.call("grant", cargo, "ore_ferrosilicate", 3)
	for station: Dictionary in host.store.catalog.rows("station_defs"):
		if str(station.station_id) == station_id: continue
		inventory.call("grant", str(inventory.call("warehouse", str(station.station_id))), "ore_ferrosilicate", 9); break
	print("ROW_QUANTITY_V17_FIXTURE funding=catalog-derived unlocks=all-explicit inputs=120-per-formal-stackable extra-hull=miner remote=one-real-warehouse")
	await show_page()
	return check(not quote_for("ore_ferrosilicate").is_empty() and not quote_for("ore_conductive_crystal").is_empty(), "formal market supplies independent ore/crystal rows")

func quote_amount(label: Label) -> int:
	return int(label.get_meta("quote_amount", -1)) if label != null else -1

func quote_checks() -> void:
	host.ui.quantity_value = 73
	await show_page("market", "buy")
	var ore: Dictionary = quote_for("ore_ferrosilicate")
	var crystal: Dictionary = quote_for("ore_conductive_crystal")
	if not check(ore.get("amount") is SpinBox and crystal.get("amount") is SpinBox and ore.amount != crystal.amount, "market rows own distinct editable quantities"): return
	check(host.ui.quantity_input == null and host.ui.body.find_child("OperationQuantity", true, false) == null, "market has no detached quantity toolbar")
	var before: Dictionary = totals()
	var node: Control = ore.row
	ore.amount.value = 2; crystal.amount.value = 3; await frames(3)
	var economy: RefCounted = host.gameplay.get("economy")
	for sample: Dictionary in [ore, crystal]:
		check(quote_amount(sample.unit_label) == int(economy.call("quote", str(sample.id), 1, false)) and quote_amount(sample.total_label) == int(economy.call("quote", str(sample.id), int(sample.amount.value), false)), "taxed unit and batch totals use separate real quotes " + str(sample.id))
	check(int(ore.amount.value) == 2 and int(crystal.amount.value) == 3 and host.ui.quantity_value == 73 and node == ore.row and totals() == before, "editing changes only that quote and keeps nodes, authority and unrelated global quantity")
	await reveal(crystal.amount)
	var line: LineEdit = crystal.amount.get_line_edit(); line.grab_focus(); await frames(3)
	var offsets: Array[Vector2i] = []
	for scroll: ScrollContainer in scroll_ancestors(line): offsets.append(Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical))
	crystal.amount.value = 4; await frames(3)
	var steady: bool = host.get_viewport().gui_get_focus_owner() == line
	var index: int = 0
	for scroll: ScrollContainer in scroll_ancestors(line): steady = steady and offsets[index] == Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical); index += 1
	check(steady and int(ore.amount.value) == 2 and host.ui.keyboard_blocked(), "quote edits preserve actual input focus, both scroll axes and keyboard flight isolation")
	host.get_viewport().gui_release_focus()

func market_checks() -> void:
	await show_page("market", "buy")
	await set_amount("ore_conductive_crystal", 3)
	var before_units: int = count("ore_ferrosilicate")
	var before_stock: int = stock("ore_ferrosilicate").quantity
	var before_credit: int = host.state.player().credit
	var cost: int = int(host.gameplay.get("economy").call("quote", "ore_ferrosilicate", 2, false))
	if await execute("ore_ferrosilicate", 2, "buy_item", true):
		check(count("ore_ferrosilicate") == before_units + 2 and stock("ore_ferrosilicate").quantity == before_stock - 2 and host.state.player().credit == before_credit - cost, "actual dirty-text purchase pays exact rounded tax quote and transfers exactly two units")
		check(amount_for("ore_conductive_crystal") != null and int(amount_for("ore_conductive_crystal").value) == 3 and host.ui.quantity_value == 73, "success refresh preserves unrelated crystal amount and unused global quantity")
	before_units = count("ore_conductive_crystal"); before_stock = stock("ore_conductive_crystal").quantity; before_credit = host.state.player().credit
	cost = int(host.gameplay.get("economy").call("quote", "ore_conductive_crystal", 3, false))
	if await execute("ore_conductive_crystal", 3, "buy_item"):
		check(count("ore_conductive_crystal") == before_units + 3 and stock("ore_conductive_crystal").quantity == before_stock - 3 and host.state.player().credit == before_credit - cost, "second market row trades its own independent quantity")
	before_units = count("module_kinetic_needle_i"); before_credit = host.state.player().credit; before_stock = stock("module_kinetic_needle_i").quantity
	cost = int(host.gameplay.get("economy").call("quote", "module_kinetic_needle_i", 2, false))
	if await execute("module_kinetic_needle_i", 2, "buy_item"):
		check(count("module_kinetic_needle_i") == before_units + 2 and stock("module_kinetic_needle_i").quantity == before_stock - 2 and host.state.player().credit == before_credit - cost, "equipment purchase creates two real instances and pays bulk price")
	await show_page("market", "ships")
	var hull: Dictionary = quote_for("shuttle_swift")
	check(not hull.is_empty() and hull.get("amount") == null and str(hull.quantity_label.text) == "1", "individual hull purchase displays fixed one without batch control")
	var hull_before: int = host.state.rows("ship_state").size(); before_credit = host.state.player().credit
	cost = int(host.gameplay.get("economy").call("quote_ship", "shuttle_swift", false))
	if await execute("shuttle_swift", 1, "buy_ship"):
		check(host.state.rows("ship_state").size() == hull_before + 1 and host.state.player().credit == before_credit - cost, "actual hull purchase remains exactly one despite unrelated row/global amounts")
	await show_page("market", "sell")
	var sell_stack: String
	var sell_item: String
	for stack_row: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"):
		if stack_row.container_id == warehouse and stack_row.item_def_id == "ore_ferrosilicate" and stack_row.policy_id == "normal_owned": sell_stack = stack_row.stack_id; break
	for item_row: D.ItemInstanceStateDto in host.state.rows("item_instance_state"):
		if item_row.container_id == warehouse and item_row.item_def_id == "module_kinetic_needle_i" and item_row.policy_id == "normal_owned": sell_item = item_row.item_instance_id; break
	before_units = count("ore_ferrosilicate"); before_credit = host.state.player().credit; before_stock = stock("ore_ferrosilicate").quantity
	cost = int(host.gameplay.get("economy").call("quote", "ore_ferrosilicate", 4, true))
	if await execute(sell_stack, 4, "sell_item", true):
		check(count("ore_ferrosilicate") == before_units - 4 and stock("ore_ferrosilicate").quantity == before_stock + 4 and host.state.player().credit == before_credit + cost, "stack sale credits exact rounded proceeds and removes four units")
	var selling: Dictionary = quote_for(sell_item)
	check(not selling.is_empty() and selling.get("amount") == null and str(selling.quantity_label.text) == "1", "instance equipment sale is fixed one")
	before_units = count("module_kinetic_needle_i"); before_credit = host.state.player().credit
	cost = int(host.gameplay.get("economy").call("quote", "module_kinetic_needle_i", 1, true))
	if await execute(sell_item, 1, "sell_item"):
		check(host.state.find("item_instance_state", "item_instance_id", sell_item) == null and count("module_kinetic_needle_i") == before_units - 1 and host.state.player().credit == before_credit + cost, "instance sale removes only selected equipment and pays one-unit proceeds")

func recipe_inputs(id: String, hull: bool = false) -> Dictionary:
	return host.gameplay.get("economy").call("_inputs", "hull_recipe_inputs" if hull else "recipe_inputs", "hull_recipe_id" if hull else "recipe_id", id, 1) as Dictionary

func manufacture_check(id: String, batches: int, hull: bool = false, dirty: bool = false) -> void:
	var definition: Dictionary = host.store.catalog.one("hull_recipe_defs" if hull else "recipe_defs", "hull_recipe_id" if hull else "recipe_id", id)
	var inputs: Dictionary = recipe_inputs(id, hull)
	for material: String in inputs:
		var required: int = int(inputs[material]) * batches
		if count(material) < required: host.gameplay.get("inventory").call("grant", warehouse, material, required - count(material))
	host.ui._update_quotes()
	var before_inputs: Dictionary = {}
	for material: String in inputs: before_inputs[material] = count(material)
	var credit: int = host.state.player().credit
	var cost: int = int(host.gameplay.get("economy").call("quote_manufacture", id, batches))
	var before_output: int = host.state.rows("ship_state").size() if hull else count(str(definition.output_item_id))
	if not await execute(id, batches, "manufacture", dirty): return
	if host.gameplay.get("industry") != null and host.gameplay.get("industry").supported():
		var service: RefCounted = host.gameplay.get("industry")
		var job: RefCounted = service.jobs(station_id)[-1]
		check((host.state.rows("ship_state").size() if hull else count(str(definition.output_item_id))) == before_output, "queued manufacturing does not create premature output " + id)
		service.tick(job.duration_s)
		host.ui.refresh_page(); await frames(4)
		if not await actual_click(host.ui.body.find_child("IndustryClaim_" + job.job_id, true, false), "claim_industry", job.job_id): return
	for material: String in inputs: check(count(material) == int(before_inputs[material]) - int(inputs[material]) * batches, "actual manufacturing consumes precise batch input " + id + " " + material)
	check(host.state.player().credit == credit - cost, "manufacturing pays exact independently rounded batch fee " + id)
	if hull:
		check(host.state.rows("ship_state").size() == before_output + batches, "hull construction creates real independently identified batch count")
	else:
		check(count(str(definition.output_item_id)) == before_output + int(definition.output_quantity) * batches, "manufacturing claims exact formal output count " + id)

func industry_checks() -> void:
	await show_page("industry")
	check(host.ui.quantity_input == null and host.ui.body.find_child("OperationQuantity", true, false) == null, "industry has no detached operation quantity")
	await set_amount("recipe_conductive", 3); await set_amount("recipe_structural", 2)
	check(int(amount_for("recipe_structural").value) == 2 and int(amount_for("recipe_conductive").value) == 3, "two recipes retain independent batch counts")
	await manufacture_check("recipe_structural", 2, false, true)
	check(amount_for("recipe_conductive") != null and int(amount_for("recipe_conductive").value) == 3, "manufacturing refresh preserves another recipe batch count")
	await manufacture_check("recipe_conductive", 3)
	await manufacture_check("hull_recipe_shuttle_swift", 2, true, true)
	await manufacture_check("recipe_kinetic_needle_i", 2)
	var manufactured: String
	for item_row: D.ItemInstanceStateDto in host.state.rows("item_instance_state"):
		if item_row.container_id == warehouse and item_row.origin_kind == T.ItemOrigin.MANUFACTURE and item_row.item_def_id == "module_kinetic_needle_i": manufactured = item_row.item_instance_id; break
	var recycle: Dictionary = quote_for(manufactured)
	if not check(not recycle.is_empty() and recycle.get("amount") == null and str(recycle.quantity_label.text) == "1", "recycling retains fixed one real instance"): return
	var before_returns: Dictionary = {}; var expected_returns: Dictionary = {}
	for ledger: D.ManufactureInputStateDto in host.state.rows("manufacture_input_state"):
		if ledger.item_instance_id != manufactured: continue
		before_returns[ledger.input_item_id] = count(ledger.input_item_id)
		expected_returns[ledger.input_item_id] = int(floor(ledger.input_quantity * float(host.store.catalog.rule("recycle_input_return_ratio"))))
	var credit: int = host.state.player().credit
	if await execute(manufactured, 1, "recycle"):
		check(host.state.find("item_instance_state", "item_instance_id", manufactured) == null and host.state.player().credit == credit - int(host.store.catalog.rule("recycle_service_fee_credit")), "actual recycle consumes only selected manufactured instance and precise fee")
		for material: String in expected_returns: check(count(material) == int(before_returns[material]) + int(expected_returns[material]), "recycle follows real frozen input ledger " + material)
func reject_quote(quote: Dictionary, label: String) -> bool:
	var before: Dictionary = totals()
	var events: int = requested_events.size()
	host.ui.call("_business_submit", quote); await frames(4)
	return check(totals() == before and requested_events.size() == events, "UI rejects without assets, money or request mutation: " + label)

func keyboard_character(character: String) -> void:
	var keycode: int = KEY_MINUS if character == "-" else KEY_PERIOD if character == "." else KEY_0 + int(character)
	for down: bool in [true, false]:
		var event := InputEventKey.new(); event.keycode = keycode; event.physical_keycode = keycode
		event.unicode = character.unicode_at(0); event.pressed = down
		host.get_viewport().push_input(event, true); await frames(1)

func invalid_amount_check(invalid: String) -> bool:
	var quote: Dictionary = quote_for("ore_ferrosilicate")
	var amount: SpinBox = quote.get("amount") as SpinBox
	var button: Button = quote.get("button") as Button
	if not check(is_instance_valid(amount) and is_instance_valid(button), "invalid amount fixture obtains fresh row references " + JSON.stringify(invalid)): return false
	amount.value = 1; await reveal(amount)
	var edit: LineEdit = amount.get_line_edit()
	if DisplayServer.get_name() != "headless": root.grab_focus()
	edit.grab_focus(); await frames(5)
	if not check(host.get_viewport().gui_get_focus_owner() == edit and (DisplayServer.get_name() == "headless" or root.has_focus()), "invalid amount fixture holds real editor focus " + JSON.stringify(invalid)): return false
	edit.select_all()
	for down: bool in [true, false]:
		var event := InputEventKey.new(); event.keycode = KEY_BACKSPACE; event.physical_keycode = KEY_BACKSPACE; event.pressed = down
		host.get_viewport().push_input(event, true); await frames(1)
	for index: int in range(invalid.length()): await keyboard_character(invalid.substr(index, 1))
	await frames(3)
	var raw: String = edit.text
	var parsed: int = int(host.ui.call("_business_row_quantity", quote))
	var context_ok: bool = bool(host.ui.call("_business_context_valid", quote))
	var witness: Dictionary = {"requested_text": invalid, "actual_text": raw, "value": amount.value, "parsed_quantity": parsed, "disabled": button.disabled, "focus_owner": str(host.get_viewport().gui_get_focus_owner()), "context_valid": context_ok, "generation": host.ui.get("business_generation"), "page": host.ui.page, "panel_id": host.ui.panel.get_instance_id(), "request_count": requested_events.size()}
	print("ROW_QUANTITY_V17_INVALID_PRECONDITION " + JSON.stringify(witness))
	# The empty/native case must remain actually empty while focused. A stale
	# disabled quote alone cannot prove invalid input if SpinBox has reformatted
	# its line to a legitimate prior value on native focus loss.
	if not check(raw == invalid and parsed == 0 and context_ok and button.disabled and host.get_viewport().gui_get_focus_owner() == edit, "actual paired keyboard creates stable invalid dirty quantity " + JSON.stringify(invalid)): return false
	var before: Dictionary = totals(); var events: int = requested_events.size()
	button.pressed.emit()
	await frames(4)
	var live: bool = is_instance_valid(amount) and is_instance_valid(button) and is_instance_valid(edit)
	witness.merge({"request_count_after": requested_events.size(), "row_still_live": live, "actual_text_after": edit.text if live else "<freed>", "assets_unchanged": totals() == before})
	print("ROW_QUANTITY_V17_INVALID_RESULT " + JSON.stringify(witness))
	if not check(live and totals() == before and requested_events.size() == events, "actual row signal refuses invalid dirty quantity without trade " + JSON.stringify(invalid)): return false
	invalid_cases += 1
	return true

func rejection_checks() -> void:
	await show_page("market", "buy")
	var ore: Dictionary = quote_for("ore_ferrosilicate")
	ore.amount.value = stock("ore_ferrosilicate").quantity + 1; await frames(3)
	check((ore.button as Button).disabled and str(ore.status_label.text).contains("库存"), "excess row quantity disables purchase with true stock reason")
	if not await reject_quote(ore, "stock insufficient"): return
	ore.amount.value = 1; var credit: int = host.state.player().credit
	host.state.player().credit = 0; host.ui._update_quotes(); await frames(3)
	check((ore.button as Button).disabled and str(ore.status_label.text).contains("信用点"), "zero funds disables actual quote")
	if not await reject_quote(ore, "funds insufficient"): return
	host.state.player().credit = credit; host.ui._update_quotes()
	# A dirty input must be re-qualified at click; a previously enabled amount
	# never bypasses actual funds merely because its old quote was acceptable.
	var previous: Dictionary = totals(); var events: int = requested_events.size()
	ore.amount.get_line_edit().text = str(stock("ore_ferrosilicate").quantity + 1)
	host.ui.call("_business_submit", ore); await frames(3)
	check(totals() == previous and requested_events.size() == events and (ore.button as Button).disabled, "dirty quantity exceeding stock is applied and freshly refused without trade")
	ore.amount.value = 1; host.ui._update_quotes()
	for invalid: String in ["", "0", "-1", "2.5", str(int(host.store.catalog.rule("business_quantity_limit")) + 1)]:
		if not await invalid_amount_check(invalid): return
	# Each rejected signal retains its original focused row; acquire the current
	# references anew rather than assuming a failed witness could never refresh.
	ore = quote_for("ore_ferrosilicate")
	if not check(is_instance_valid(ore.get("amount")), "invalid cases retain a live business row"): return
	ore.amount.get_line_edit().text = "1"; ore.amount.apply(); host.ui._update_quotes()
	host.get_viewport().gui_release_focus()
	# Capacity remains production-side: alternate cargo destination has an
	# actual finite hull volume. UI market still buys into its existing warehouse.
	var inventory: RefCounted = host.gameplay.get("inventory")
	var cargo: String = str(inventory.call("hold", host.state.ship(), T.ContainerKind.CARGO))
	var room: int = int(inventory.call("room", cargo, "ammo_kinetic_slug_i", 1000000))
	if room > 0: inventory.call("grant", cargo, "ammo_kinetic_slug_i", room)
	previous = totals()
	await command("buy_item", "ammo_kinetic_slug_i", 1, cargo)
	check(totals() == previous, "production trade rejects finite full cargo destination and leaves all assets unchanged")
	if room > 0: inventory.call("consume", cargo, "ammo_kinetic_slug_i", room)
	await show_page("market", "sell")
	var restricted: int = 0
	for quote: Dictionary in host.ui.quotes:
		var item: D.ItemInstanceStateDto = host.state.find("item_instance_state", "item_instance_id", str(quote.target)) as D.ItemInstanceStateDto
		var stack: D.InventoryStackStateDto = host.state.find("inventory_stack_state", "stack_id", str(quote.target)) as D.InventoryStackStateDto
		if (item != null and item.policy_id != "normal_owned") or (stack != null and stack.policy_id != "normal_owned"):
			restricted += 1; check((quote.button as Button).disabled and not str(quote.status_label.text).is_empty(), "protected asset has no eligible row sale " + str(quote.id)); await reject_quote(quote, "protected sale")
	check(restricted > 0, "normal initial guaranteed inventory remains visible under row quantities")
	await show_page("industry")
	var recipe: Dictionary = quote_for("recipe_structural")
	var stackable: Array[D.InventoryStackStateDto] = []
	for row: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"):
		if row.container_id == warehouse and row.item_def_id == "ore_ferrosilicate" and row.policy_id == "normal_owned": stackable.append(row)
	var original: Dictionary = {}
	for row: D.InventoryStackStateDto in stackable: original[row.stack_id] = row.quantity; row.quantity = 0
	host.ui._update_quotes()
	check((recipe.button as Button).disabled and str(recipe.status_label.text).contains("材料"), "missing actual inputs disables only its manufacturing row")
	await reject_quote(recipe, "materials insufficient")
	for row: D.InventoryStackStateDto in stackable: row.quantity = int(original[row.stack_id])
	host.ui._update_quotes()

func blur_quote_sync_checks() -> void:
	await show_page("market", "buy")
	var quote: Dictionary = quote_for("ore_ferrosilicate")
	var amount: SpinBox = quote.get("amount") as SpinBox
	var other: SpinBox = amount_for("ore_conductive_crystal")
	if not check(is_instance_valid(amount) and is_instance_valid(other) and amount != other, "blur quote fixture has two distinct live row inputs"): return
	amount.value = 1; await reveal(amount)
	var edit: LineEdit = amount.get_line_edit()
	if DisplayServer.get_name() != "headless": root.grab_focus()
	edit.grab_focus(); await frames(5)
	if not check(host.get_viewport().gui_get_focus_owner() == edit and (DisplayServer.get_name() == "headless" or root.has_focus()), "blur quote fixture holds actual input focus"): return
	var before: Dictionary = totals(); var requests_before: int = requested_events.size()
	edit.select_all()
	for down: bool in [true, false]:
		var event := InputEventKey.new(); event.keycode = KEY_BACKSPACE; event.physical_keycode = KEY_BACKSPACE; event.pressed = down
		host.get_viewport().push_input(event, true); await frames(1)
	await frames(3)
	var button: Button = quote.get("button") as Button
	var raw_before: String = edit.text
	print("ROW_QUANTITY_V17_BLUR_PRECONDITION " + JSON.stringify({"raw": raw_before, "value": amount.value, "parsed": host.ui.call("_business_row_quantity", quote), "disabled": button.disabled, "focus_owner": str(host.get_viewport().gui_get_focus_owner()), "request_count": requested_events.size(), "context_valid": host.ui.call("_business_context_valid", quote)}))
	if not check(raw_before.is_empty() and int(host.ui.call("_business_row_quantity", quote)) == 0 and button.disabled and host.get_viewport().gui_get_focus_owner() == edit, "blur fixture starts with real empty dirty input and rejected quote"): return
	# No quote update is called here: this checks the native SpinBox focus-exit
	# normalization against the production signal wiring as the player sees it.
	other.get_line_edit().grab_focus(); await frames(2)
	if not check(is_instance_valid(amount) and is_instance_valid(edit) and is_instance_valid(button), "focus-only change keeps original business controls alive"): return
	var raw_after: String = edit.text
	var parsed_after: int = int(host.ui.call("_business_row_quantity", quote))
	var normalized: bool = parsed_after > 0
	var expected_price: int = int(host.gameplay.get("economy").call("quote", "ore_ferrosilicate", parsed_after, false)) if normalized else 0
	var legitimate: bool = normalized and stock("ore_ferrosilicate").quantity >= parsed_after and host.state.player().credit >= expected_price and host.ui._service_reason("trade").is_empty()
	var synchronized: bool = (not button.disabled) == legitimate and quote_amount(quote.total_label) == expected_price and str(quote.quantity_label.text) == (str(parsed_after) if normalized else "—")
	if normalized: synchronized = synchronized and not str(quote.status_label.text).contains("请输入")
	else: synchronized = synchronized and str(quote.status_label.text).contains("请输入")
	print("ROW_QUANTITY_V17_BLUR_RESULT " + JSON.stringify({"raw_before": raw_before, "raw_after": raw_after, "value": amount.value, "parsed": parsed_after, "disabled": button.disabled, "status": quote.status_label.text, "quote_amount": quote_amount(quote.total_label), "expected_price": expected_price, "expected_allowed": legitimate, "focus_owner": str(host.get_viewport().gui_get_focus_owner()), "context_valid": host.ui.call("_business_context_valid", quote), "request_count_before": requests_before, "request_count_after": requested_events.size(), "assets_unchanged": totals() == before}))
	check(host.get_viewport().gui_get_focus_owner() == other.get_line_edit() and requested_events.size() == requests_before and totals() == before, "moving to another quantity input performs no trade or authority mutation")
	if check(synchronized, "focus-exit quote and eligibility match actual restored or still-invalid row text"): blur_quote_checks += 1
	host.get_viewport().gui_release_focus()

func station_fixture(destination: String) -> void:
	var station: Dictionary = host.store.catalog.one("station_defs", "station_id", destination)
	var ship: D.ShipStateDto = host.state.ship()
	ship.sector_id = str(station.sector_id); ship.status = T.ShipStatus.FLYING
	ship.has_station_id = false; ship.station_id = ""; ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	host.state.player().has_docked_station_id = false; host.state.player().docked_station_id = ""
	for container: D.ContainerStateDto in host.state.rows("container_state"):
		if container.ship_instance_id == ship.ship_instance_id: container.sector_id = ship.sector_id
	var anchor: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", station.station_anchor_id)
	ship.pos_x = anchor.x_m; ship.pos_y = anchor.y_m; ship.pos_z = anchor.z_m
	check(host.gameplay.assign_anchor_site("ship", ship.ship_instance_id, station.station_anchor_id), "alternate station fixture sets its actual strategic site")
	if not check(host._stage_candidate(host.state, host.store.catalog), "Main stages alternate formal station fixture"): return
	host._activate(host.state)
	var flight: XJFlight = host.world.flight
	flight.global_position = host.world.anchor_position(str(station.station_anchor_id)); flight.velocity = Vector3.ZERO
	flight.write_back(); flight.get_global_transform_interpolated(); flight.reset_physics_interpolation()
	await command("dock", destination)
	check(host.state.player().docked_station_id == destination, "actual docking binds target station")

func stale_check(old_quote: Dictionary, label: String) -> void:
	var before: Dictionary = totals(); var events: int = requested_events.size()
	host.ui.call("_business_submit", old_quote); await frames(3)
	if check(before == totals() and requested_events.size() == events, "queued old-row callback rejected after " + label): stale_rejections += 1

func lifecycle_checks() -> void:
	await show_page("market", "buy")
	await set_amount("ore_ferrosilicate", 5)
	var stale: Dictionary = quote_for("ore_ferrosilicate")
	host.ui.refresh_page(); await frames(5)
	await stale_check(stale, "same-page refresh")
	check(amount_for("ore_ferrosilicate") != null and int(amount_for("ore_ferrosilicate").value) == 5, "fresh same-context row remembers committed quantity")
	stale = quote_for("ore_ferrosilicate")
	await show_page("industry"); await stale_check(stale, "page switch")
	await show_page("market", "buy"); stale = quote_for("ore_ferrosilicate")
	host.ui.show_page(""); await frames(4); await stale_check(stale, "panel close")
	await show_page("market", "buy"); stale = quote_for("ore_ferrosilicate")
	var controlled: String = host.state.ship().ship_instance_id
	await command("switch_ship", parked_ship_id); await show_page("market", "buy")
	await stale_check(stale, "controlled-ship switch")
	check(int(amount_for("ore_ferrosilicate").value) == 1, "new ship context starts with fresh per-row quantity")
	await command("switch_ship", controlled); await show_page("industry")
	stale = quote_for("recipe_structural")
	var missing_station: String
	for station: Dictionary in host.store.catalog.rows("station_defs"):
		var present: bool = false
		for service: Dictionary in host.store.catalog.rows("station_service_defs"):
			if str(service.station_id) == str(station.station_id) and str(service.service_id) == "manufacture": present = true
		if not present and str(station.station_id) != station_id: missing_station = str(station.station_id); break
	if check(not missing_station.is_empty(), "formal station without industrial service exists"):
		await station_fixture(missing_station); await show_page("industry")
		await stale_check(stale, "station switch")
		check(host.ui.quotes.is_empty() and host.ui.quantity_input == null, "station without manufacture has no false row operation")
		var before: Dictionary = totals(); await command("manufacture", "recipe_structural", 2)
		check(totals() == before, "absent station service refuses real manufacturing without asset mutation")
		await station_fixture(station_id)
	await show_page("market", "buy")
	await command("save", "3", 1, "manual")
	var sealed: Array[Dictionary] = host.store._records("SELECT l.slot_id,l.generation,l.current_snapshot_id FROM save_slot l JOIN save_snapshot s ON s.snapshot_id=l.current_snapshot_id WHERE l.world_id=? AND l.slot_kind='manual' AND l.slot_index=3 AND s.status='sealed'", [host.state.world_id])
	if not check(sealed.size() == 1, "row-quantity checkpoint is actually sealed in SQLite"): return
	var slot: Dictionary = sealed[0]; var expected: Dictionary = totals(); var world: String = host.state.world_id
	stale = quote_for("ore_ferrosilicate")
	await command("load", str(slot.slot_id), int(slot.generation), str(slot.current_snapshot_id)); await show_page("market", "buy")
	await stale_check(stale, "same-world snapshot load")
	check(totals() == expected and int(amount_for("ore_ferrosilicate").value) == 1, "load preserves exact authoritative assets and discards prior presentation quantity")
	await release_host()
	if not await start_host(): return
	await command("load", str(slot.slot_id), int(slot.generation), str(slot.current_snapshot_id)); await show_page("market", "buy")
	restarts += 1
	check(host.state.world_id == world and totals() == expected, "independent Main SQLite restart restores exact GUI-derived money, inventory and production")
	stale = quote_for("ore_ferrosilicate")
	await command("new_world", "行内数量旧世界回调隔离"); await show_page("market", "buy")
	await stale_check(stale, "new world with reused formal item IDs")
	check(host.state.world_id != world and int(amount_for("ore_ferrosilicate").value) == 1, "new authority cannot inherit old row or global amount")
func label_fits(label: Label) -> bool:
	if label == null: return false
	if not label.is_visible_in_tree(): return true
	return label.size.y + 1.0 >= label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")) * maxi(1, label.get_line_count())

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4); await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if check(not image.is_empty() and image.save_png(directory.path_join(label + ".png")) == OK, "native row quantity capture " + label): captures += 1

func warehouse_layout(suffix: String) -> void:
	var panel: Control = host.ui.get("warehouse_panel") as Control
	if not check(is_instance_valid(panel), "real dual warehouse exists " + suffix): return
	var refs: Dictionary = panel.get("refs")
	for key: String in ["ship_rows", "station_rows"]:
		var remote_seen: bool = false
		for row: Dictionary in refs.get(key, []):
			var band: Rect2 = row.row.get_global_rect()
			var max_top: float = -INF; var min_bottom: float = INF
			for field: String in ["image", "name", "quantity", "location", "amount", "button"]:
				var control: Control = row.get(field) as Control
				if control == null: continue
				var rect: Rect2 = control.get_global_rect()
				max_top = maxf(max_top, rect.position.y); min_bottom = minf(min_bottom, rect.end.y)
				check(band.encloses(rect), "warehouse inline column remains in its exact asset row " + suffix + " " + str(row.id) + " " + field)
			check(min_bottom > max_top and band.size.y <= 58.0, "portrait/name/holding/location/quantity/button share a compact horizontal band " + suffix + " " + str(row.id))
			for field: String in ["name", "quantity", "location"]: check(label_fits(row[field]), "warehouse inline label font fits " + suffix + " " + str(row.id) + " " + field)
			if bool(row.remote):
				remote_seen = true
				var tint: Color = row.row.modulate * row.row.self_modulate
				check(row.get("amount") == null and row.get("button") == null and maxf(tint.r, maxf(tint.g, tint.b)) < 0.85, "remote warehouse is grey and has no live transfer action " + suffix)
			else:
				check(not remote_seen, "all current-station goods precede remote rows " + suffix)
				var button: Button = row.get("button") as Button
				check(button != null and button.size.x <= 132.0 and button.size.y <= 36.0 and (button.size_flags_horizontal & Control.SIZE_EXPAND) == 0, "warehouse transfer button has small intrinsic size " + suffix)
		var values: Array = refs.get(key, [])
		if values.is_empty(): continue
		var tail: Dictionary = values[-1]
		var target: Control = tail.get("button") as Control
		if target == null: target = tail.location
		await reveal(target)
		check(visible_control(target), "warehouse scrolling reaches compact tail source/action " + suffix + " " + key)
		var focus: SpinBox
		for candidate: Dictionary in values:
			var editor: SpinBox = candidate.get("amount") as SpinBox
			if editor != null and editor.editable: focus = editor; break
		if focus != null:
			host.get_viewport().gui_release_focus(); focus.get_line_edit().grab_focus(); await frames(4)
			if not visible_control(focus):
				print("ROW_QUANTITY_V17_WAREHOUSE_FOCUS " + JSON.stringify({"layout": suffix, "side": key, "row_id": focus.get_meta("row_id", ""), "rect": str(focus.get_global_rect()), "line_rect": str(focus.get_line_edit().get_global_rect()), "owner": str(host.get_viewport().gui_get_focus_owner())}))
				for scroll: ScrollContainer in scroll_ancestors(focus): print("ROW_QUANTITY_V17_WAREHOUSE_FOCUS_SCROLL " + JSON.stringify({"name": str(scroll.name), "rect": str(scroll.get_global_rect()), "x": scroll.scroll_horizontal, "y": scroll.scroll_vertical}))
			check(host.get_viewport().gui_get_focus_owner() == focus.get_line_edit() and visible_control(focus), "warehouse editable amount focus reveals full inline control through both axes " + suffix + " " + key)
			host.get_viewport().gui_release_focus()

func layout_checks() -> void:
	for layout: Dictionary in [{"size": Vector2i(1440, 900), "scale": 1.0}, {"size": Vector2i(1280, 720), "scale": 1.0}, {"size": Vector2i(1440, 900), "scale": 2.0}, {"size": Vector2i(1280, 720), "scale": 2.0}]:
		root.size = layout.size; root.content_scale_size = Vector2i(Vector2(layout.size) / float(layout.scale))
		var suffix: String = "%dx%d-%d" % [layout.size.x, layout.size.y, int(float(layout.scale) * 100)]
		for page: String in ["market", "industry", "warehouse"]:
			await show_page(page, "buy" if page == "market" else "")
			check(viewport_rect().encloses(host.ui.panel.get_global_rect()), "page shell fits actual logical viewport " + page + " " + suffix)
			check(host.ui.quantity_input == null and host.ui.body.find_child("OperationQuantity", true, false) == null, "page never shows detached global quantity " + page + " " + suffix)
			if page == "warehouse": await warehouse_layout(suffix)
			else:
				for entry: Dictionary in business_rows():
					var amount: SpinBox = entry.get("amount") as SpinBox
					for field: String in ["name", "description", "unit", "quantity", "unit_price", "total", "status"]: check(label_fits(entry[field]), "business row text fits " + page + " " + suffix + " " + str(entry.row.get_meta("row_id")) + " " + field)
					if amount != null: check(entry.row.is_ancestor_of(amount) and amount.size.y >= amount.get_combined_minimum_size().y - 0.5, "quantity belongs to the exact business row " + page + " " + suffix)
				var target: SpinBox = amount_for("ore_ferrosilicate" if page == "market" else "recipe_structural")
				if target != null:
					host.get_viewport().gui_release_focus(); target.get_line_edit().grab_focus(); await frames(4)
					if not visible_control(target):
						print("ROW_QUANTITY_V17_BUSINESS_FOCUS " + JSON.stringify({"page":page,"layout":suffix,"row_id":target.get_meta("row_id",""),"rect":str(target.get_global_rect()),"line_rect":str(target.get_line_edit().get_global_rect()),"owner":str(host.get_viewport().gui_get_focus_owner()),"keyboard_blocked":host.ui.keyboard_blocked()}))
						for scroll: ScrollContainer in scroll_ancestors(target):print("ROW_QUANTITY_V17_BUSINESS_FOCUS_SCROLL " + JSON.stringify({"name":str(scroll.name),"rect":str(scroll.get_global_rect()),"x":scroll.scroll_horizontal,"y":scroll.scroll_vertical,"follow_focus":scroll.follow_focus}))
					check(visible_control(target) and host.ui.keyboard_blocked(), "real row focus reveals quantity with horizontal scroll and blocks ship input " + page + " " + suffix)
					host.get_viewport().gui_release_focus()
			if (layout.size == Vector2i(1440, 900) and float(layout.scale) == 1.0) or (layout.size == Vector2i(1280, 720) and float(layout.scale) == 2.0):
				if float(layout.scale) == 1.0: host.ui.page_scroll.scroll_vertical = 0
				# At 200%, preserve the real row-focus scroll rather than capturing
				# a tall heading with the actionable inventory below the viewport.
				await frames(4)
				if float(layout.scale) == 2.0 and page in ["market", "industry"]:
					var capture_amount: SpinBox = amount_for("ore_ferrosilicate" if page == "market" else "recipe_structural")
					check(capture_amount != null and visible_control(capture_amount), "compact capture preserves actually visible row amount " + page + " " + suffix)
				await capture(page + "-inline-" + suffix)
		layouts += 1
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	await show_page("market", "buy")
	# Horizontal and vertical position must survive an actual successful trade,
	# just as independent row amounts survive the result-driven page refresh.
	var quote: Dictionary = quote_for("ore_conductive_crystal")
	await set_amount("ore_conductive_crystal", 2); await reveal(quote.button)
	var before_vertical: int = host.ui.page_scroll.scroll_vertical
	var view: Node = host.ui.get("business_list_view") as Node
	var before_horizontal: int = int(view.get("horizontal_scroll").scroll_horizontal)
	if await execute("ore_conductive_crystal", 2, "buy_item"):
		var next_view: Node = host.ui.get("business_list_view") as Node
		check(host.ui.page_scroll.scroll_vertical == before_vertical and int(next_view.get("horizontal_scroll").scroll_horizontal) == before_horizontal, "actual successful trade refresh preserves existing two-axis list position")

func _run() -> void:
	old_fps = Engine.max_fps; Engine.max_fps = 144
	root.size = Vector2i(1440, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_size = root.size
	directory = OS.get_environment("XJ_ROW_QUANTITY_V17_DIRECTORY").replace("\\", "/")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/row-quantity-v17/%d" % Time.get_ticks_usec())
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/") and not directory.contains(".."), "test directory is scoped to tmp"): await finish(); return
	DirAccess.make_dir_recursive_absolute(directory); database_path = directory.path_join("progress.db")
	if not check(not FileAccess.file_exists(database_path), "test refuses any existing progress database"): await finish(); return
	if not await start_host() or not await prepare(): await finish(); return
	await quote_checks()
	await market_checks()
	await industry_checks()
	await rejection_checks()
	await blur_quote_sync_checks()
	await layout_checks()
	await lifecycle_checks()
	await finish()

func finish() -> void:
	await release_host(); Engine.max_fps = old_fps
	var result: String = "PASS" if failures.is_empty() else "FAIL"
	print("ROW_QUANTITY_V17_FINAL_JSON " + JSON.stringify({"result": result, "revision": "inline-warehouse-independent-business-amounts", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "layouts": layouts, "gui_transactions": gui_transactions, "stale_rejections": stale_rejections, "invalid_cases": invalid_cases, "blur_quote_checks": blur_quote_checks, "restarts": restarts, "database_path": database_path}))
	print("ROW_QUANTITY_V17_RESULT %s checks=%d captures=%d failures=%d" % [result, checks, captures, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
