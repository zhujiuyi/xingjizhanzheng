extends SceneTree
## Actual Main / fresh SQLite business UI regression. Funding and unlocks are
## explicit isolated preconditions. Assets and prices remain the formal catalog
## and production services; no personal archive or duplicate balance authority.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var database_path: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var old_fps: int
var station_id: String
var stack_item_id: String
var module_item_id: String
var purchased_module_id: String
var normal_ship_id: String
var normal_ship_def: String
var requested_events: Array[Dictionary] = []

func _initialize() -> void:
	create_timer(240.0).timeout.connect(func(): print("BUSINESS_LIST_V11_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for frame: int in range(count): await process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "real SQLite writer settles")

func start_host() -> void:
	host = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	host.set_process(false); host.set_physics_process(false)
	await frames()
	check(host.services_ready, "Main opens formal read-only catalog and isolated SQLite")
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): requested_events.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames()
	await create_timer(0.25).timeout

func show_page(page: String, filter: String = "") -> void:
	if not filter.is_empty(): host.ui.market_filter = filter
	host.ui.show_page(page)
	await frames(4)
	host.ui.tick(1.0)
	await frames(3)

func lists_below(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node.has_meta("business_list") and bool(node.get_meta("business_list")): result.append(node)
	for child: Node in node.get_children(): result.append_array(lists_below(child))
	return result

func buttons_below(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button: result.append(child)
		result.append_array(buttons_below(child))
	return result

func business_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if host.ui.page == "warehouse":
		var warehouse_panel: Control = host.ui.get("warehouse_panel") as Control
		if is_instance_valid(warehouse_panel):
			var warehouse_refs: Dictionary = warehouse_panel.get("refs")
			for key: String in ["ship_rows", "station_rows"]:
				for row: Dictionary in warehouse_refs.get(key, []): result.append(row)
		return result
	for list_node: Node in lists_below(host.ui.body):
		var values: Variant = list_node.get("rows")
		if values is Array:
			for row: Dictionary in values: result.append(row)
	return result

func row_for(id: String) -> Dictionary:
	for row: Dictionary in business_rows():
		var control: Node = row.get("row")
		if control != null and str(control.get_meta("row_id", "")) == id: return row
	return {}

func action_button(action: String, target: String = "", extra: String = "", require_enabled: bool = true) -> Button:
	for button: Button in buttons_below(host.ui.body):
		if str(button.get_meta("action", "")) != action: continue
		if not target.is_empty() and str(button.get_meta("target", "")) != target: continue
		if not extra.is_empty() and str(button.get_meta("extra", "")) != extra: continue
		if not require_enabled or not button.disabled: return button
	return null

func viewport_rect() -> Rect2:
	return Rect2(Vector2.ZERO, host.ui.root.size)

func scroll_ancestors(control: Control) -> Array[ScrollContainer]:
	var result: Array[ScrollContainer] = []
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer: result.append(node)
		node = node.get_parent()
	return result

func reveal(control: Control) -> void:
	# Both axes can be nested: first expose the list action column, then its
	# actual row inside the page. Production follow-focus is checked separately.
	for scroll: ScrollContainer in scroll_ancestors(control):
		scroll.ensure_control_visible(control)
	await frames(4)

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
		print("BUSINESS_LIST_V11_GUI_TIMEOUT " + JSON.stringify({"action": expected_action, "page": host.ui.page, "rect": str(button.get_global_rect()), "focus": root.has_focus(), "hover": str(host.get_viewport().gui_get_hovered_control()), "pointer": str(button.get_global_mouse_position())}))
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
	return check(int(emitted["count"]) == 1 and matched, "one actual GUI click emits one production command " + expected_action)

func prepare_native_focus() -> bool:
	if DisplayServer.get_name() == "headless": return true
	root.grab_focus()
	var deadline: int = Time.get_ticks_msec() + 30000
	while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
	return check(root.has_focus(), "native business pages use actual window focus")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4); await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/business-list-v11/native")
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "native business capture " + label)
	captures += 1

func _run() -> void:
	old_fps = Engine.max_fps; Engine.max_fps = 144
	root.size = Vector2i(1440, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_size = root.size
	database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/business-list-v11-%d.db" % Time.get_ticks_usec())
	await start_host()
	if not host.services_ready: await finish(); return
	await host._command("new_world", "业务列表独立验收", 1, "")
	if not check(host.state != null and host.state.player().has_docked_station_id, "real new world starts legally docked at its formal station"): await finish(); return
	station_id = host.state.player().docked_station_id
	if not await prepare_native_focus(): await finish(); return
	await choose_business_fixture()
	await quote_checks()
	await protected_asset_checks()
	await purchase_and_move_checks()
	await fitting_checks()
	await page_layout_checks()
	await persistence_checks()
	await finish()

func choose_business_fixture() -> void:
	var economy: RefCounted = host.gameplay.get("economy")
	var best_stack: int = 9223372036854775807
	var best_ship: int = 9223372036854775807
	for stock: D.ShopStockStateDto in host.state.rows("shop_stock_state"):
		if stock.station_id != station_id or stock.quantity < 2: continue
		var def: Dictionary = host.ui._stock_definition(stock.item_def_id)
		var item: Dictionary = host.store.catalog.one("item_defs", "item_id", stock.item_def_id)
		if not bool(def.get("allow_buy", false)) or not bool(item.get("stackable", false)): continue
		var price: int = int(economy.call("quote", stock.item_def_id, 1, false))
		if price > 0 and price < best_stack:
			best_stack = price; stack_item_id = stock.item_def_id
	for stock: D.ShopShipStockStateDto in host.state.rows("shop_ship_stock_state"):
		if stock.station_id != station_id or stock.quantity <= 0: continue
		var has_weapon: bool = false
		for slot: Dictionary in host.store.catalog.rows("ship_slot_defs"):
			if str(slot.ship_id) == stock.ship_def_id and str(slot.slot_type) == "weapon": has_weapon = true
		var price: int = int(economy.call("quote_ship", stock.ship_def_id, false))
		if has_weapon and price > 0 and price < best_ship: best_ship = price; normal_ship_def = stock.ship_def_id
	check(not stack_item_id.is_empty() and not normal_ship_def.is_empty(), "fixture selects real affordable stack goods and a locally sold weapon-capable hull")
	if stack_item_id.is_empty() or normal_ship_def.is_empty(): return
	# Unlock and funding are transparent fixture preparation. Stock quantities,
	# policies, asset identifiers, and all price definitions remain unmodified.
	host.gameplay.call("grant_unlock", str(host.ui._stock_definition(stack_item_id).required_unlock_id))
	var role: Dictionary = host.store.catalog.one("ship_role_defs", "ship_id", normal_ship_def)
	host.gameplay.call("grant_unlock", str(role.get("required_unlock_id", "")))
	host.state.player().credit += best_ship * 10 + best_stack * 10
	print("BUSINESS_LIST_V11_FIXTURE station=%s stack=%s hull=%s funding=explicit-catalog-derived unlocks=explicit" % [station_id, stack_item_id, normal_ship_def])

func quote_amount(label: Label) -> int:
	return int(label.get_meta("quote_amount", -1)) if label != null else -1

func quote_checks() -> void:
	if stack_item_id.is_empty(): return
	await show_page("market", "buy")
	var row: Dictionary = row_for(stack_item_id)
	if not check(not row.is_empty(), "market list contains the selected formal item row"): return
	var economy: RefCounted = host.gameplay.get("economy")
	check(quote_amount(row.unit_price) == int(economy.call("quote", stack_item_id, 1, false)) and quote_amount(row.total) == int(economy.call("quote", stack_item_id, 1, false)), "one-unit price and total use real reputation/tax quote")
	host.ui.quantity_input.value = 2
	await frames(3)
	check(quote_amount(row.unit_price) == int(economy.call("quote", stack_item_id, 1, false)) and quote_amount(row.total) == int(economy.call("quote", stack_item_id, 2, false)) and "2" in str(row.quantity.text), "SpinBox changes actual quantity and rounded total without rebuilding an invented price")
	var stock: D.ShopStockStateDto = economy.call("_stock", stack_item_id)
	var button: Button = action_button("buy_item", stack_item_id, "", false)
	host.ui.quantity_input.value = stock.quantity + 1
	await frames(3)
	check(button != null and button.disabled and not str(row.status.text).is_empty(), "quantity exceeding real inventory disables purchase with a visible row reason")
	host.ui.quantity_input.value = 1
	var credit: int = host.state.player().credit
	host.state.player().credit = 0; host.ui._update_quotes()
	check(button != null and button.disabled and "信用点" in str(row.status.text), "insufficient funding is an explicit row reason")
	host.state.player().credit = credit; host.ui._update_quotes()
	check(button != null and not button.disabled, "restored legitimate quantity and funding restore the action")
	await show_page("market", "ships")
	row = row_for(normal_ship_def)
	if not check(not row.is_empty(), "market displays a distinct hull list row"): return
	host.ui.quantity_input.value = 2; await frames(3)
	check(str(row.unit.text) == "艘" and "1" in str(row.quantity.text) and quote_amount(row.total) == int(economy.call("quote_ship", normal_ship_def, false)), "hull uses actual one-vessel unit and fixed quantity despite shared item SpinBox")
	host.ui.quantity_input.value = 1

func protected_asset_checks() -> void:
	await show_page("warehouse")
	var protected_rows: int = 0
	var maintained: bool = true
	for row: Dictionary in business_rows():
		var id: String = str(row.row.get_meta("row_id", ""))
		var item: RefCounted = host.state.find("item_instance_state", "item_instance_id", id)
		var stack: RefCounted = host.state.find("inventory_stack_state", "stack_id", id)
		var entity: RefCounted = item if item != null else stack
		if entity == null or str(entity.get("policy_id")) == "normal_owned": continue
		protected_rows += 1
		for button: Button in buttons_below(row.row):
			if str(button.get_meta("action", "")) in ["move_item", "move_stack", "sell_item", "recycle"]: maintained = button.disabled and maintained
		maintained = not str(row.status.text).is_empty() and maintained
	check(protected_rows > 0 and maintained, "initial guaranteed assets retain visible policy restrictions and no enabled transfer/trade action")
	await show_page("fitting")
	var protected_equipment: int = 0
	maintained = true
	for button: Button in buttons_below(host.ui.body):
		if str(button.get_meta("action", "")) != "unfit_module": continue
		var item: RefCounted = host.state.find("item_instance_state", "item_instance_id", str(button.get_meta("target", "")))
		if item != null and str(item.get("policy_id")) != "normal_owned": protected_equipment += 1; maintained = button.disabled and maintained
	check(protected_equipment > 0 and maintained, "protected installed equipment cannot be unmounted through the redesigned operation column")
	await show_page("ships")
	var unavailable_loan: Button = action_button("claim_loan", "", "", false)
	check(unavailable_loan != null and unavailable_loan.disabled, "fresh loan row preserves mission/unlock prerequisites rather than enabling a visual-only action")

func purchase_and_move_checks() -> void:
	if stack_item_id.is_empty() or normal_ship_def.is_empty(): return
	var inventory: RefCounted = host.gameplay.get("inventory")
	var economy: RefCounted = host.gameplay.get("economy")
	var warehouse: String = str(inventory.call("warehouse", station_id))
	await show_page("market", "ships")
	var hull_price: int = int(economy.call("quote_ship", normal_ship_def, false))
	var credit: int = host.state.player().credit
	var previous_ship_ids: Dictionary = {}
	for ship: D.ShipStateDto in host.state.rows("ship_state"): previous_ship_ids[ship.ship_instance_id] = true
	if not await actual_click(action_button("buy_ship", normal_ship_def), "buy_ship", normal_ship_def): return
	for ship: D.ShipStateDto in host.state.rows("ship_state"):
		if not previous_ship_ids.has(ship.ship_instance_id) and ship.ship_def_id == normal_ship_def: normal_ship_id = ship.ship_instance_id
	check(not normal_ship_id.is_empty() and host.state.player().credit == credit - hull_price, "real hull purchase creates a normal owned ship and debits its exact quote")
	await show_page("ships")
	if not await actual_click(action_button("switch_ship", normal_ship_id), "switch_ship", normal_ship_id): return
	check(host.state.ship().ship_instance_id == normal_ship_id and host.state.ship().policy_id == "normal_owned", "actual fleet row switches to the legitimately purchased normal vessel")
	await show_page("market", "buy")
	host.ui.quantity_input.value = 1; await frames()
	var before_quantity: int = int(inventory.call("count", warehouse, stack_item_id, true))
	var item_price: int = int(economy.call("quote", stack_item_id, 1, false))
	credit = host.state.player().credit
	var before_stock: int = int(economy.call("_stock", stack_item_id).quantity)
	if not await actual_click(action_button("buy_item", stack_item_id), "buy_item", stack_item_id): return
	check(host.state.player().credit == credit - item_price and int(inventory.call("count", warehouse, stack_item_id, true)) == before_quantity + 1 and int(economy.call("_stock", stack_item_id).quantity) == before_stock - 1, "real item GUI purchase debits exact credit and transfers one unit from shop to warehouse")
	await show_page("warehouse")
	var stack: D.InventoryStackStateDto
	for candidate: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"):
		if candidate.item_def_id == stack_item_id and candidate.container_id == warehouse and candidate.policy_id == "normal_owned": stack = candidate; break
	if not check(stack != null, "purchase produces a legal warehouse stack"): return
	var row: Dictionary = row_for(stack.stack_id)
	check(not row.is_empty() and str(stack.quantity) in str(row.quantity.text) and bool(row.current_station) and str(row.location.text).contains("当前"), "warehouse row displays actual stack quantity and current station location")
	check(host.ui.quantity_input == null and row.get("amount") is SpinBox, "warehouse quantity is owned by this row rather than the detached global toolbar")
	if not row.is_empty() and row.get("amount") is SpinBox: row.amount.value = 1
	var cargo: String = str(inventory.call("hold", host.state.ship(), T.ContainerKind.CARGO))
	var before_cargo: int = int(inventory.call("count", cargo, stack_item_id, true))
	if not await actual_click(action_button("move_stack", stack.stack_id, cargo), "move_stack", stack.stack_id): return
	check(int(inventory.call("count", warehouse, stack_item_id, true)) == before_quantity and int(inventory.call("count", cargo, stack_item_id, true)) == before_cargo + 1, "actual warehouse action transfers the selected unit into the current vessel")
	await show_page("market", "sell")
	var sale_stack: D.InventoryStackStateDto
	for candidate: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"):
		if candidate.item_def_id == stack_item_id and candidate.container_id == cargo and candidate.policy_id == "normal_owned": sale_stack = candidate; break
	if not check(sale_stack != null, "normal current cargo remains visible to local sell list"): return
	row = row_for(sale_stack.stack_id)
	check(not row.is_empty() and quote_amount(row.unit_price) == int(economy.call("quote", stack_item_id, 1, true)) and quote_amount(row.total) == int(economy.call("quote", stack_item_id, 1, true)), "sell row displays actual net unit quote and selected total")

func fitting_checks() -> void:
	if normal_ship_id.is_empty(): return
	var economy: RefCounted = host.gameplay.get("economy")
	var best: int = 9223372036854775807
	var slot_target: String
	for stock: D.ShopStockStateDto in host.state.rows("shop_stock_state"):
		if stock.station_id != station_id or stock.quantity <= 0: continue
		var mod: Dictionary = host.store.catalog.one("module_full_defs", "module_id", stock.item_def_id)
		if mod.is_empty() or str(mod.slot_type) != "weapon": continue
		var metrics: Dictionary = host.gameplay.call("metrics", host.state.ship())
		if float(mod.power_pu) > float(metrics.power_capacity) or float(mod.cpu_cu) > float(metrics.cpu_capacity) or float(mod.mass_kg) > float(metrics.max_installed_mass_kg): continue
		var price: int = int(economy.call("quote", stock.item_def_id, 1, false))
		if price > 0 and price < best: best = price; module_item_id = stock.item_def_id
	if not check(not module_item_id.is_empty(), "fitting fixture selects a real local weapon within the purchased hull's resource limits"): return
	host.gameplay.call("grant_unlock", str(host.ui._stock_definition(module_item_id).required_unlock_id))
	var tech: Dictionary = host.store.catalog.one("module_tech_defs", "module_id", module_item_id)
	host.gameplay.call("grant_unlock", str(tech.get("required_unlock_id", "")))
	await show_page("market", "buy")
	host.ui.quantity_input.value = 1; await frames()
	var old_ids: Dictionary = {}
	for item: D.ItemInstanceStateDto in host.state.rows("item_instance_state"): old_ids[item.item_instance_id] = true
	if not await actual_click(action_button("buy_item", module_item_id), "buy_item", module_item_id): return
	for item: D.ItemInstanceStateDto in host.state.rows("item_instance_state"):
		if item.item_def_id == module_item_id and not old_ids.has(item.item_instance_id): purchased_module_id = item.item_instance_id
	if not check(not purchased_module_id.is_empty(), "production purchase creates an individual legal module instance"): return
	await show_page("fitting")
	var fit_button: Button = action_button("fit_module", purchased_module_id)
	if fit_button != null: slot_target = str(fit_button.get_meta("extra", ""))
	if not await actual_click(fit_button, "fit_module", purchased_module_id): return
	var mounted: D.EquipmentStateDto = host.state.find("equipment_state", "item_instance_id", purchased_module_id)
	check(mounted != null and host.state.find("item_instance_state", "item_instance_id", purchased_module_id).policy_id == "normal_owned", "actual fitting row mounts normal equipment without weakening protected-asset rules")
	await show_page("fitting")
	if not await actual_click(action_button("unfit_module", purchased_module_id), "unfit_module", purchased_module_id): return
	check(host.state.find("equipment_state", "item_instance_id", purchased_module_id) == null and host.state.find("item_instance_state", "item_instance_id", purchased_module_id).container_id == host.ui._warehouse_id(), "actual unfit action returns the same legal instance to the current station warehouse")
	await show_page("fitting")
	if not await actual_click(action_button("fit_module", purchased_module_id, slot_target), "fit_module", purchased_module_id): return
	check(host.state.find("equipment_state", "item_instance_id", purchased_module_id) != null, "remount remains a real production action for subsequent SQLite recovery")

func label_text_fits(label: Label) -> bool:
	if label == null or label.text.is_empty(): return false
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return label.size.y + 0.5 >= font.get_height(font_size) * maxi(1, label.get_line_count())

func page_layout_checks() -> void:
	var variants: Array[Dictionary] = [
		{"page": "market", "filter": "buy", "name": "market-goods"},
		{"page": "market", "filter": "ships", "name": "market-hulls"},
		{"page": "market", "filter": "sell", "name": "market-sell"},
		{"page": "ships", "filter": "", "name": "fleet-loans"},
		{"page": "warehouse", "filter": "", "name": "warehouse"},
		{"page": "fitting", "filter": "", "name": "fitting"},
		{"page": "industry", "filter": "", "name": "industry"},
		{"page": "research", "filter": "", "name": "research-facilities"},
		{"page": "missions", "filter": "", "name": "missions"}]
	var layouts: Array[Dictionary] = []
	for size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]: layouts.append({"size": size, "scale": scale})
	layouts.append({"size": Vector2i(1920, 1080), "scale": 1.0})
	for layout: Dictionary in layouts:
		root.size = layout.size; root.content_scale_size = Vector2i(Vector2(layout.size) / float(layout.scale))
		await frames(4)
		var suffix: String = "%dx%d-%d" % [layout.size.x, layout.size.y, int(float(layout.scale) * 100)]
		for variant: Dictionary in variants:
			await show_page(str(variant.page), str(variant.filter))
			var label: String = str(variant.name) + " " + suffix
			if str(variant.page) == "warehouse":
				await warehouse_layout_checks(label, layout.size == Vector2i(1440, 900) and float(layout.scale) == 1.0, suffix)
				continue
			var list_nodes: Array[Node] = lists_below(host.ui.body)
			var rows: Array[Dictionary] = business_rows()
			if not check(not list_nodes.is_empty() and not rows.is_empty(), "business page uses populated list sections " + label): continue
			if not viewport_rect().encloses(host.ui.panel.get_global_rect()):
				print("BUSINESS_LIST_V11_OVERFLOW ",label," viewport=",viewport_rect()," panel=",host.ui.panel.get_global_rect()," panel_min=",host.ui.panel.get_combined_minimum_size()," body_min=",host.ui.body.get_combined_minimum_size())
				for list_node: Node in list_nodes:
					print("BUSINESS_LIST_V11_MIN list=",list_node.get_combined_minimum_size()," tools=",list_node.scroll_tools.get_combined_minimum_size()," horizontal=",list_node.horizontal_scroll.get_combined_minimum_size()," heading=",list_node.heading.get_combined_minimum_size())
			check(viewport_rect().encloses(host.ui.panel.get_global_rect()) and viewport_rect().encloses(host.ui.page_scroll.get_global_rect()), "page shell stays within the logical viewport " + label)
			var valid_cells: bool = true
			var images: bool = true
			var readable: bool = true
			var column_order: bool = true
			var all_actions_last: bool = true
			for row: Dictionary in rows:
				for field: String in ["row", "image", "name", "description", "unit", "quantity", "unit_price", "total", "status", "actions"]:
					valid_cells = is_instance_valid(row.get(field)) and valid_cells
				if not valid_cells: continue
				var id: String = str(row.row.get_meta("row_id", ""))
				valid_cells = bool(row.row.get_meta("business_row", false)) and not id.is_empty() and valid_cells
				images = row.image.texture != null and row.image.texture.get_width() > 0 and row.image.texture.get_height() > 0 and images
				for field: String in ["name", "description", "unit", "quantity", "unit_price", "total", "status"]:
					readable = label_text_fits(row[field]) and readable
				var previous_x: float = -INF
				for field: String in ["image", "name", "unit", "quantity", "unit_price", "total", "status", "actions"]:
					var cell: Control = row[field]
					column_order = cell.global_position.x >= previous_x - 0.5 and column_order
					previous_x = cell.global_position.x
				for button: Button in buttons_below(row.row): all_actions_last = row.actions.is_ancestor_of(button) and all_actions_last
			check(valid_cells and images, "every real list row has identity, content columns and a nonempty portrait " + label)
			check(readable, "actual font line heights fit every full row description and numeric/status label " + label)
			check(column_order and all_actions_last, "columns preserve image/name/unit/quantity/unit-price/total/status/actions order " + label)
			var tail: Dictionary = rows[-1]
			var last_buttons: Array[Button] = buttons_below(tail.actions)
			var last_control: Control = last_buttons[-1] if not last_buttons.is_empty() else tail.status
			await reveal(last_control)
			check(visible_control(last_control), "horizontal and vertical scroll reach the last row and operation column " + label)
			if not last_buttons.is_empty():
				var focus_button: Button
				for button: Button in buttons_below(host.ui.body):
					if not button.disabled and button.focus_mode == Control.FOCUS_ALL: focus_button = button
				if focus_button != null:
					# Start a genuine focus entry; re-grabbing an already focused
					# button does not emit focus_entered after fixture scroll reset.
					host.get_viewport().gui_release_focus()
					for scroll: ScrollContainer in scroll_ancestors(focus_button): scroll.scroll_vertical = 0; scroll.scroll_horizontal = 0
					await frames(3)
					focus_button.grab_focus(); await frames(4)
					if not visible_control(focus_button):
						print("BUSINESS_LIST_V11_FOCUS ",label," button=",focus_button.text," rect=",focus_button.get_global_rect()," viewport=",viewport_rect()," owner=",host.get_viewport().gui_get_focus_owner())
						for scroll: ScrollContainer in scroll_ancestors(focus_button):
							print("BUSINESS_LIST_V11_FOCUS_SCROLL ",scroll.name," rect=",scroll.get_global_rect()," offsets=",Vector2(scroll.scroll_horizontal,scroll.scroll_vertical)," range=",Vector2(scroll.get_h_scroll_bar().max_value,scroll.get_v_scroll_bar().max_value))
					check(host.get_viewport().gui_get_focus_owner() == focus_button and visible_control(focus_button), "production focus-follow exposes a keyboard-focused business control " + label)
					focus_button.release_focus()
			if layout.size == Vector2i(1440, 900) and float(layout.scale) == 1.0:
				host.ui.page_scroll.scroll_vertical = 0
				for list_node: Node in list_nodes:
					var scroll := list_node.find_child("BusinessHorizontalScroll", true, false) as ScrollContainer
					if scroll != null: scroll.scroll_horizontal = 0
				await capture(str(variant.name) + "-" + suffix)
			elif str(variant.name) == "market-hulls" and float(layout.scale) == 2.0:
				await reveal(last_control)
				await capture("market-hulls-actions-" + suffix)

func warehouse_layout_checks(label: String, take_capture: bool, suffix: String) -> void:
	var warehouse_panel: Control = host.ui.get("warehouse_panel") as Control
	if not check(is_instance_valid(warehouse_panel) and bool(warehouse_panel.get_meta("warehouse_panel", false)), "warehouse uses its real dedicated dual-list component " + label): return
	var data: Dictionary = warehouse_panel.get("refs")
	var left: ScrollContainer = data.get("ship_scroll") as ScrollContainer
	var right: ScrollContainer = data.get("station_scroll") as ScrollContainer
	if not check(left != null and right != null and left != right and lists_below(host.ui.body).is_empty(), "warehouse has independent cargo/station scrolls without false BusinessList identity " + label): return
	check(viewport_rect().encloses(host.ui.panel.get_global_rect()) and host.ui.panel.get_global_rect().encloses(left.get_global_rect()) and host.ui.panel.get_global_rect().encloses(right.get_global_rect()), "warehouse shell and both scrolls fit logical viewport " + label)
	var valid: bool = true
	var readable: bool = true
	var images: bool = true
	var operations: bool = true
	for row: Dictionary in business_rows():
		valid = bool(row.row.get_meta("warehouse_row", false)) and str(row.row.get_meta("row_id", "")) == str(row.id) and valid
		images = row.image.texture != null and row.image.texture.get_width() > 0 and row.image.texture.get_height() > 0 and images
		for field: String in ["name", "quantity", "location", "status"]: readable = label_text_fits(row[field]) and readable
		if bool(row.remote):
			operations = row.get("amount") == null and row.get("button") == null and operations
		else:
			operations = row.get("amount") is SpinBox and row.get("button") is Button and operations
			if row.get("button") is Button: operations = row.row.is_ancestor_of(row.button) and row.row.is_ancestor_of(row.amount) and operations
	check(valid and images, "warehouse real asset rows retain identity and nonempty portraits " + label)
	check(readable, "warehouse quantity/location/restriction labels fit actual font height " + label)
	check(operations and host.ui.quantity_input == null, "warehouse operations and quantity remain in their own rows " + label)
	for key: String in ["ship_rows", "station_rows"]:
		var values: Array = data.get(key, [])
		if values.is_empty(): continue
		var tail: Dictionary = values[-1]
		var control: Control = tail.get("button") as Control
		if control == null: control = tail.location
		var other: ScrollContainer = right if key == "ship_rows" else left
		var other_offset: int = other.scroll_vertical
		await reveal(control)
		check(visible_control(control) and other.scroll_vertical == other_offset, "warehouse independent scroll exposes tail and operation " + key + " " + label)
	var focus_button: Button
	for button: Button in buttons_below(warehouse_panel):
		if not button.disabled and button.focus_mode == Control.FOCUS_ALL: focus_button = button
	if focus_button != null:
		host.get_viewport().gui_release_focus(); left.scroll_vertical = 0; right.scroll_vertical = 0
		await frames(3); focus_button.grab_focus(); await frames(4)
		check(host.get_viewport().gui_get_focus_owner() == focus_button and visible_control(focus_button), "warehouse keyboard focus exposes current row transfer " + label)
		focus_button.release_focus()
	if take_capture:
		left.scroll_vertical = 0; right.scroll_vertical = 0; host.ui.page_scroll.scroll_vertical = 0
		await capture("warehouse-" + suffix)

func persistence_checks() -> void:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var cargo: String = str(inventory.call("hold", host.state.ship(), T.ContainerKind.CARGO))
	var expected_credit: int = host.state.player().credit
	var expected_units: int = int(inventory.call("count", cargo, stack_item_id, true))
	var expected_equipment: bool = not purchased_module_id.is_empty() and host.state.find("equipment_state", "item_instance_id", purchased_module_id) != null
	await host._request_save("manual", 0)
	await wait_writer()
	var params: Array = [host.state.world_id]
	var credits: Array[Dictionary] = host.store._records("SELECT p.credit FROM save_slot l JOIN save_snapshot s ON s.snapshot_id=l.current_snapshot_id JOIN player_state p ON p.snapshot_id=s.snapshot_id WHERE l.world_id=? AND l.slot_kind='manual' AND l.slot_index=0 AND s.status='sealed'", params)
	var units: Array[Dictionary] = host.store._records("SELECT COALESCE(SUM(i.quantity),0) AS quantity FROM save_slot l JOIN inventory_stack_state i ON i.snapshot_id=l.current_snapshot_id WHERE l.world_id=? AND l.slot_kind='manual' AND l.slot_index=0 AND i.container_id=? AND i.item_def_id=? AND i.policy_id='normal_owned'", [host.state.world_id, cargo, stack_item_id])
	check(credits.size() == 1 and int(credits[0].credit) == expected_credit and units.size() == 1 and int(units[0].quantity) == expected_units, "sealed SQLite independently stores the GUI-derived credit and cargo quantity")
	if not purchased_module_id.is_empty():
		var fitted: Array[Dictionary] = host.store._records("SELECT e.item_instance_id FROM save_slot l JOIN equipment_state e ON e.snapshot_id=l.current_snapshot_id WHERE l.world_id=? AND l.slot_kind='manual' AND l.slot_index=0 AND e.item_instance_id=?", [host.state.world_id, purchased_module_id])
		check(fitted.size() == (1 if expected_equipment else 0), "sealed SQLite records the real module fitting state")
	await release_host()
	await start_host()
	await host._command("continue", "", 1, "")
	await wait_writer()
	if not check(host.state != null, "a separate Main reopens the actual independent archive"): return
	inventory = host.gameplay.get("inventory")
	check(host.state.player().credit == expected_credit and host.state.ship().ship_instance_id == normal_ship_id and int(inventory.call("count", cargo, stack_item_id, true)) == expected_units, "reopened SQLite restores exact GUI credit, purchased hull and transferred cargo")
	check((host.state.find("equipment_state", "item_instance_id", purchased_module_id) != null) == expected_equipment, "reopened SQLite restores actual equipped module instance")
	await show_page("warehouse")
	check(not business_rows().is_empty() and is_instance_valid(host.ui.get("warehouse_panel")), "dual warehouse lists rebuild from reopened database state")

func finish() -> void:
	await release_host()
	Engine.max_fps = old_fps
	print("BUSINESS_LIST_V11_RESULT %s checks=%d captures=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, captures, failures.size()])
	quit(0 if failures.is_empty() else 1)
