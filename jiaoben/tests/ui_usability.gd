extends SceneTree
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Space = preload("res://runtime/space_coordinates.gd")
var checks: int = 0
var failures: Array[String] = []
var emitted: Array[Dictionary] = []
func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("_run")
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result
func button_text(ui: Node, prefix: String) -> Button:
	for node: Node in descendants(ui):
		if node is Button and node.text.begins_with(prefix): return node
	return null
func business_rows(ui: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in descendants(ui.body):
		if bool(node.get_meta("business_list", false)):
			for row: Dictionary in node.get("rows"): result.append(row)
	return result
func meta_button(parent: Node, key: String, value: String) -> Button:
	for node: Node in descendants(parent):
		if node is Button and str(node.get_meta(key, "")) == value: return node
	return null
func mission_rows(ui: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in business_rows(ui):
		if bool(row.row.get_meta("mission_row", false)): result.append(row)
	return result
func mission_filter_button(ui: Node, dimension: String, value: String) -> Button:
	for node: Node in descendants(ui.body):
		if node is Button and str(node.get_meta("mission_filter_dimension", "")) == dimension and str(node.get_meta("mission_filter_value", "")) == value: return node
	return null
func place_ui_anchor(host: Node, anchor_id: String) -> void:
	# Presentation fixture preparation explicitly names its source anchor/site.
	# Neither these tests nor gameplay infer a site from an encoded XYZ value.
	var anchor: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", anchor_id)
	var ship: D.ShipStateDto = host.state.ship()
	ship.sector_id = str(anchor.sector_id); ship.status = T.ShipStatus.FLYING
	ship.has_station_id = false; ship.station_id = ""
	ship.pos_x = float(anchor.x_m); ship.pos_y = float(anchor.y_m); ship.pos_z = float(anchor.z_m)
	ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	host.state.player().has_docked_station_id = false; host.state.player().docked_station_id = ""
	for container: D.ContainerStateDto in host.state.rows("container_state"):
		if container.ship_instance_id == ship.ship_instance_id: container.sector_id = ship.sector_id
	if Space.supported(host.store.catalog): check(Space.assign(host.state, "ship", ship.ship_instance_id, Space.site_for_anchor(host.store.catalog, anchor_id)), "UI fixture assigns the named ship site " + anchor_id)
	host.world.flight.global_position = Vector3(ship.pos_x, ship.pos_y, ship.pos_z)
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.world.flight.reset_physics_interpolation()
	host.world.refresh_site()
	host.camera.bind(host.world.flight, host.store.catalog, host.state.player().camera_mode)
	host.camera.step(0.0)
func overview_ids_match(ui: Node, expected: Array[String]) -> bool:
	var actual: Array[String] = []
	for id: String in ui.overview.filtered_ids: actual.append(id)
	actual.sort()
	var wanted: Array[String] = expected.duplicate()
	wanted.sort()
	return actual == wanted
func _run() -> void:
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/ui-usability.db")
	DirAccess.remove_absolute(path)
	var host: Node = Main.new()
	host.progress_database_path = path
	root.add_child(host)
	await process_frame
	await host._command("new_world", "界面功能验收", 1, "")
	check(host.state != null, "actual client/new world available")
	if host.state == null: quit(1); return
	host.busy = true
	var ui: Node = host.ui
	ui.requested.disconnect(host._command)
	ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): emitted.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))
	var before: Dictionary = host.store.preferences().duplicate(true)
	ui.show_page("settings")
	await process_frame
	var slider: HSlider = ui.root.find_child("Preference_mouse_sensitivity", true, false)
	check(slider != null and is_equal_approx(slider.value, float(before.mouse_sensitivity)), "settings use persisted sensitivity")
	check(emitted.is_empty(), "opening settings emits no preference write")
	check(before == host.store.preferences(), "opening settings preserves SQL preferences")
	check(slider.min_value <= 0.002 and slider.max_value >= 0.002 and slider.max_value < 0.1, "sensitivity slider has realistic range")
	var font: Font = ui.theme.default_font
	var supported: bool = true
	for character: String in "星际战舰采矿护盾任务装甲保存取消": supported = supported and font.has_char(character.unicode_at(0))
	check(supported, "system fallback contains required Chinese glyphs")
	ui.show_page("market")
	await process_frame
	var quantity_limit: int = int(host.store.catalog.rule("business_quantity_limit"))
	var quantity_controls: bool = not ui.quotes.is_empty() and ui.quantity_input == null and ui.body.find_child("OperationQuantity", true, false) == null
	for quote: Dictionary in ui.quotes:
		quantity_controls = quantity_controls and quote.get("amount") is SpinBox and int(quote.amount.max_value) == quantity_limit and quote.row.is_ancestor_of(quote.amount)
	check(quantity_controls, "each market row owns its catalog-bounded quantity control without a global toolbar")
	if not quantity_controls: host.free(); quit(1); return
	for quote: Dictionary in ui.quotes: quote.amount.value = 5
	for quote: Dictionary in ui.quotes:
		var price: int = host.gameplay.economy.quote(quote.id, 5, false)
		var unit_price: int = host.gameplay.economy.quote(quote.id, 1, false)
		check(quote.total_label.text == str(price) and int(quote.total_label.get_meta("quote_amount", -1)) == price and quote.quantity_label.text == "5", "item total and quantity columns show actual taxed/reputation quote " + quote.id)
		check(quote.unit_label.text == str(unit_price) and int(quote.unit_label.get_meta("quote_amount", -1)) == unit_price, "item unit-price column preserves independent integer tax rounding " + quote.id)
		check(quote.total_label.tooltip_text.contains("%d 信用点；本行数量 5" % price) and quote.unit_label.tooltip_text == "每单位含税价格", "item quote tooltips explain numeric-column units and this row's actual quantity " + quote.id)
		check(quote.status_label.text.begins_with("站点库存 %d" % int(quote.maximum)) and quote.status_label.tooltip_text == quote.status_label.text, "item status column retains actual stock and complete eligibility reason " + quote.id)
	var echo_quote: Dictionary = {}
	var iron_quote: Dictionary = {}
	for quote: Dictionary in ui.quotes:
		if quote.id == "ore_echo_silica": echo_quote = quote
		if quote.id == "ore_ferrosilicate": iron_quote = quote
	check(not echo_quote.is_empty() and echo_quote.button.disabled and echo_quote.status_label.text.contains("需解锁"), "locked unique ore has a real disabled action and visible unlock reason")
	check(not iron_quote.is_empty() and not iron_quote.button.disabled and iron_quote.status_label.text.ends_with("可成交"), "affordable unlocked ore has an enabled action and correct status")
	var ship_filter: Button = button_text(ui.body, "购买船体")
	check(ship_filter != null, "ship-market filter is available through its real control")
	if ship_filter != null: ship_filter.pressed.emit()
	for quote: Dictionary in ui.quotes:
		var price: int = host.gameplay.economy.quote_ship(quote.id)
		check(quote.kind == "ship" and quote.get("amount") == null and quote.quantity_label.visible and quote.quantity_label.text == "1" and quote.total_label.text == str(price) and quote.unit_label.text == str(price), "ship columns quote exactly one real hull without a batch selector " + quote.id)
		check(quote.total_label.tooltip_text.contains("%d 信用点；本行数量 1" % price) and not bool(quote.button.get_meta("uses_quantity", true)), "ship tooltip and command keep fixed quantity one " + quote.id)
	ui.show_page("fitting")
	var enabled: Button = button_text(ui, "关闭设备")
	check(enabled != null, "enabled equipment offers off action")
	if enabled != null:
		emitted.clear(); enabled.pressed.emit()
		check(emitted.size() == 1 and emitted[0].action == "set_module_enabled" and emitted[0].extra == "off" and emitted[0].quantity == 1, "toggle sends off and fixed instance quantity")
	ui.show_page("ships")
	var technical: bool = false
	for node: Node in descendants(ui.body):
		if node is Label or node is Button: technical = technical or node.text.contains("normal_owned") or node.text.contains("loan_") or node.text.contains("shuttle_")
	check(not technical, "ship and loan names have no raw IDs or policies")
	ui.mission_filter = "all"; ui.mission_status_filter = "all"; ui.mission_location_filter = "local"; ui.show_page("missions")
	var first_rows: Array[Dictionary] = mission_rows(ui)
	check(not first_rows.is_empty() and first_rows[0].id == "tutorial_flight" and first_rows[0].name.text == "新手教学 1 · 出航准备" and first_rows[0].status.text == "可接取", "new player first real mission row is available T0 tutorial")
	if not first_rows.is_empty():
		var accept: Button = meta_button(first_rows[0].actions, "action", "accept_mission")
		check(accept != null and not accept.disabled and str(accept.get_meta("target", "")) == "tutorial_flight", "first tutorial row has an enabled action for the actual T0 definition")
	ui.mission_location_filter = "all"; ui.show_page("missions")
	var cards: Array[Dictionary] = mission_rows(ui)
	check(cards.size() == 6, "all missions use the current business-list rows with six entries per full page")
	check(button_text(ui, "下一页") != null and not button_text(ui, "下一页").disabled, "full forty mission list has pagination")
	var expected_missions: Dictionary = {}
	for definition: Dictionary in host.store.catalog.rows("mission_defs"): expected_missions[str(definition.mission_id)] = definition
	var seen_missions: Dictionary = {}
	var page_count: int = ceili(float(expected_missions.size()) / 6.0)
	for index: int in range(page_count):
		var current_rows: Array[Dictionary] = mission_rows(ui)
		check(current_rows.size() == mini(6, expected_missions.size() - index * 6), "mission page has its exact expected row count " + str(index + 1))
		for row: Dictionary in current_rows:
			var id: String = str(row.id)
			check(expected_missions.has(id) and not seen_missions.has(id) and str(row.row.get_meta("mission_kind", "")) == str(expected_missions[id].mission_kind), "pagination retains one real categorized mission " + id)
			seen_missions[id] = true
		var next: Button = button_text(ui.body, "下一页")
		var previous: Button = button_text(ui.body, "上一页")
		check(next != null and previous != null and next.disabled == (index == page_count - 1) and previous.disabled == (index == 0), "mission pagination boundaries match the current page " + str(index + 1))
		if index < page_count - 1 and next != null:
			next.pressed.emit()
			check(ui.mission_page == index + 1, "real next-page control advances exactly once")
	check(seen_missions.size() == expected_missions.size(), "every actual mission appears exactly once across all pages")
	for kind: String in ["tutorial", "story", "contract"]:
		var filter: Button = mission_filter_button(ui, "type", kind)
		check(filter != null, "mission category has a real filter control " + kind)
		if filter == null: continue
		filter.pressed.emit()
		var filtered: Array[Dictionary] = mission_rows(ui)
		var total: int = 0
		for definition: Dictionary in expected_missions.values():
			if str(definition.mission_kind) == kind: total += 1
		var matching: bool = filtered.size() == mini(6, total) and ui.mission_page == 0
		for row: Dictionary in filtered: matching = matching and str(row.row.get_meta("mission_kind", "")) == kind
		check(matching, "category filter resets pagination and shows only actual matching rows " + kind)
	var all_types: Button = mission_filter_button(ui, "type", "all")
	if all_types != null: all_types.pressed.emit()
	var available_filter: Button = mission_filter_button(ui, "status", "available")
	if available_filter != null: available_filter.pressed.emit()
	var available_rows: Array[Dictionary] = mission_rows(ui)
	check(available_filter != null and available_rows.size() == 1 and available_rows[0].id == "tutorial_flight" and available_rows[0].status.text == "可接取", "available filter excludes all locked initial missions")
	var active_filter: Button = mission_filter_button(ui, "status", "active")
	if active_filter != null: active_filter.pressed.emit()
	check(active_filter != null and mission_rows(ui).is_empty(), "active filter does not invent an attempt before mission acceptance")
	var local_filter: Button = mission_filter_button(ui, "location", "local")
	if local_filter != null: local_filter.pressed.emit()
	check(ui.mission_filter == "all" and ui.mission_status_filter == "active" and ui.mission_location_filter == "local", "location filter preserves the independent type and status choices")
	var all_statuses: Button = mission_filter_button(ui, "status", "all")
	if all_statuses != null: all_statuses.pressed.emit()
	check(ui.mission_location_filter == "local" and not mission_rows(ui).is_empty() and mission_rows(ui)[0].id == "tutorial_flight", "status reset preserves the location and restores the legal first tutorial")
	var kinds: Dictionary = {}
	for definition: Dictionary in host.store.catalog.rows("mission_objective_defs"):
		kinds[definition.objective_kind] = true
		var description: String = ui._objective_description(definition)
		check(not description.contains("target_") and not description.contains("spawn_") and not description.contains("anchor_") and description != "完成指定目标", "real objective kind translated " + str(definition.objective_kind))
	check(kinds.has("collect") and kinds.has("deliver") and kinds.has("destroy_spawn"), "actual collect/deliver/destroy objective kinds covered")
	check(ui._anchor_name("anchor_anchor_flight_forward") == "前进航路标" and ui._anchor_name("anchor_anchor_flight_turn") == "转向航路标", "T0 markers have useful names")
	var inventory_rows: Array = host.state.rows("container_state")
	for container: D.ContainerStateDto in inventory_rows:
		if container.kind == T.ContainerKind.SLOT: check(not ui._local_container(container.container_id), "installed slot excluded from warehouse")
	# Use the actual undock transition before checking the flight-only HUD.
	host._business_action("undock", "", 1, "")
	ui.show_page("")
	ui.tick(1.0)
	check(ui.health.text.contains("护盾") and ui.top.text.contains("雨燕"), "HUD refresh displays actual typed ship metrics")
	ui._refresh_targets()
	var stable: Dictionary = ui.target_buttons.duplicate()
	ui._refresh_targets()
	var reused: bool = true
	for id: String in stable: reused = reused and ui.target_buttons.get(id) == stable[id]
	check(reused and not stable.is_empty(), "target refresh reuses existing controls")
	var all_contacts: Array[String] = []
	var contact_names: Dictionary = {}
	var navigation_contacts: Array[String] = []
	for entry: Dictionary in ui.overview.entry_rows:
		all_contacts.append(str(entry.id)); contact_names[str(entry.id)] = str(entry.title)
		if str(entry.kind) not in ["npc", "wreck", "encounter"]: navigation_contacts.append(str(entry.id))
	ui.overview.sort_buttons.name.pressed.emit()
	var ascending: bool = ui.overview.sort_key == "name" and ui.overview.sort_ascending
	var last_name: String = ""
	for id: String in ui.overview.filtered_ids:
		ascending = ascending and last_name <= str(contact_names[id]); last_name = str(contact_names[id])
	check(ascending and overview_ids_match(ui, all_contacts), "real overview name-sort control preserves all contacts in ascending order")
	ui.overview.sort_buttons.name.pressed.emit()
	var descending: bool = not ui.overview.sort_ascending
	var first_name: bool = true
	for id: String in ui.overview.filtered_ids:
		descending = descending and (first_name or last_name >= str(contact_names[id])); last_name = str(contact_names[id]); first_name = false
	check(descending and overview_ids_match(ui, all_contacts), "repeated name-sort control reverses order without losing contacts")
	ui.overview.filter_buttons.navigation.pressed.emit()
	check(not navigation_contacts.is_empty() and overview_ids_match(ui, navigation_contacts), "real navigation filter retains exactly the current non-combat contacts")
	ui.overview.filter_buttons.all.pressed.emit()
	ui.set_operation_status("save", "等待扫描结束后保存", true)
	await process_frame
	check(ui.operation_bar.visible and ui.operation_cancel.visible, "save waiting exposes independent cancellation")
	emitted.clear(); ui.operation_cancel.pressed.emit()
	check(emitted.size() == 1 and emitted[0].action == "cancel_save", "save cancel emits supported intent")
	ui.show_page("pause")
	var discard: Button = button_text(ui, "放弃未保存进度并退出")
	check(discard != null and not discard.disabled, "explicit discard-and-exit available")
	emitted.clear(); discard.pressed.emit()
	check(emitted.size() == 1 and emitted[0].action == "quit_without_save", "discard exit has explicit distinct action")
	# Stop the queued host command; direct signal callback is deferred by Main.
	host.process_mode = Node.PROCESS_MODE_DISABLED
	ui.notify("操作完成：undock")
	check(ui.toast.text == "已出港", "player success text hides action enum")
	ui.notify("正在向 SQLite 提交世界快照")
	check(not ui.toast.text.contains("SQLite"), "save status has player language")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for scale: float in [1.0, 2.0]:
			root.size = size
			root.content_scale_size = Vector2i(Vector2(size) / scale)
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			await process_frame
			ui.set_operation_status("save", "等待当前扫描周期结束后保存；可继续航行或取消保存", true)
			for key: String in ["station", "ships", "warehouse", "fitting", "market", "industry", "missions", "research", "map", "pause", "settings"]:
				ui.show_page(key)
				await process_frame
				await process_frame
				var close: Button = ui.panel.find_child("PanelClose", true, false)
				var viewport: Rect2 = Rect2(Vector2.ZERO, ui.root.size)
				var header: Control = ui.station_layer.find_child("UndockButton", true, false) if key == "station" else close
				check(header != null and viewport.encloses(header.get_global_rect()) and ui.page_scroll.size.y >= 40, "page header/scroll reachable %s %s x%.0f" % [key, str(size), scale])
			check(Rect2(Vector2.ZERO, ui.root.size).encloses(ui.operation_cancel.get_global_rect()), "waiting cancel reachable %s x%.0f" % [str(size), scale])
	ui.set_operation_status("idle", "")
	ui.show_page("")
	var npc: D.NpcStateDto = D.NpcStateDto.new()
	npc.npc_instance_id = "ui_health_fixture"
	npc.alive = true
	var spawn: Dictionary = {}
	for definition: Dictionary in host.store.catalog.rows("npc_spawn_defs"):
		if str(definition.sector_id) == host.state.current_sector(): spawn = definition; break
	check(not spawn.is_empty(), "NPC bar fixture uses a real spawn definition in the current sector")
	if spawn.is_empty(): host.queue_free(); await process_frame; quit(1); return
	npc.spawn_id = str(spawn.spawn_id)
	npc.sector_id = host.state.current_sector()
	place_ui_anchor(host, str(spawn.anchor_id))
	var npc_point: Vector3 = host.world.flight.global_position + Vector3(0, 0, -100)
	npc.pos_x = npc_point.x; npc.pos_y = npc_point.y; npc.pos_z = npc_point.z
	var npc_definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
	npc.shield = float(npc_definition.shield_max) * 0.5
	npc.armor = float(npc_definition.armor_max)
	npc.hull = float(npc_definition.hull_max)
	var npc_added: bool = host.state.add("npc_state", npc)
	if Space.supported(host.store.catalog): check(npc_added and Space.assign(host.state, "npc", npc.npc_instance_id, Space.site_for_anchor(host.store.catalog, str(spawn.anchor_id))), "NPC presentation fixture keeps its actual frozen spawn site")
	check(npc_added and host.world.sync_entities(), "production entity sync creates the fixture's actual visible NPC target")
	if Space.supported(host.store.catalog): check(Space.site_for_entity(host.state, "npc", npc.npc_instance_id) == Space.current_site(host.state), "nearby NPC and player fixtures share the actual spawn site")
	ui._refresh_targets()
	var npc_button: Button = ui.target_buttons.get(npc.npc_instance_id)
	check(npc_button != null, "the real nearby NPC has a selectable overview control")
	if npc_button != null: npc_button.pressed.emit()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	await process_frame
	ui.tick(1.0)
	await process_frame
	await process_frame
	check(ui.target_id == npc.npc_instance_id and ui.npc_detail.is_visible_in_tree(), "selected NPC remains a real detected target with visible defense readout")
	for index: int in range(3):
		var key: String = ["shield", "armor", "hull"][index]
		var maximum: float = float(npc_definition[key + "_max"])
		var current: float = float(npc.get(key))
		check(is_equal_approx(ui.npc_bars[index].bar.max_value, maximum) and is_equal_approx(ui.npc_bars[index].bar.value, current) and ui.npc_bars[index].label.tooltip_text.ends_with("%.0f/%.0f" % [current, maximum]), "selected NPC bar and complete tooltip use actual " + key + " values")
	var combat_contacts: Array[String] = []
	for entry: Dictionary in ui.overview.entry_rows:
		if str(entry.kind) in ["npc", "wreck", "encounter"]: combat_contacts.append(str(entry.id))
	ui.overview.filter_buttons.combat.pressed.emit()
	check(combat_contacts.has(npc.npc_instance_id) and overview_ids_match(ui, combat_contacts), "real combat filter includes the detected NPC and excludes all navigation contacts")
	ui.overview.filter_buttons.all.pressed.emit()
	# The scan readout is a second presentation fixture at its actual signal
	# site, after the NPC defense checks; the two sites are astronomically apart.
	var signal_def: Dictionary = host.store.catalog.one("signal_defs", "signal_id", "signal_anchor_gate_calibration")
	place_ui_anchor(host, str(signal_def.anchor_id))
	check(host.world.sync_entities(), "scan fixture refreshes the actual signal-site entities")
	host.gameplay.work.scan_target = str(signal_def.signal_id)
	host.gameplay.work.scan_progress = 30.0
	host.gameplay.work.scan_remaining = 1.5
	ui._refresh_targets()
	ui.tick(1.0)
	await process_frame
	await process_frame
	check(ui.work_box.visible and ui.work_progress.value > 0 and ui.work_label.text.contains("1.5"), "scan displays actual completion and cycle remainder")
	check(Rect2(Vector2.ZERO, ui.root.size).encloses(ui.work_stop.get_global_rect()) and not ui.work_stop.get_global_rect().intersects(ui.toast.get_global_rect()), "200 percent active work stop is visible and clear of notification")
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		root.warp_mouse(ui.target_panel.get_global_rect().get_center())
		for frame: int in range(6): await process_frame
		check(ui.input_blocked(), "native hovering target panel blocks flight input")
		if not ui.input_blocked(): print("POINTER_DEBUG rect=", ui.target_panel.get_global_rect(), " mouse=", ui.target_panel.get_global_mouse_position(), " visible=", ui.target_panel.is_visible_in_tree())
	else:
		print("SKIP native pointer warp under headless display; native rerun required")
	host.queue_free()
	await process_frame
	print("UI_USABILITY_RESULT %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
