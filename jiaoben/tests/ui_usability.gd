extends SceneTree
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
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
	check(int(ui.quantity_input.max_value) == int(host.store.catalog.rule("business_quantity_limit")), "quantity upper bound comes from catalog")
	ui.quantity_input.value = 5
	for quote: Dictionary in ui.quotes:
		var price: int = host.gameplay.economy.quote(quote.id, 5, false)
		check(quote.label.text.contains(str(price) + " 信用点"), "item quote includes actual tax/reputation quantity " + quote.id)
	ui.market_filter = "ships"; ui.show_page("market")
	for quote: Dictionary in ui.quotes:
		check(quote.label.text.contains("数量 1") and quote.label.text.contains(str(host.gameplay.economy.quote_ship(quote.id)) + " 信用点"), "ship purchase always quotes one hull " + quote.id)
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
	ui.mission_filter = "local"; ui.show_page("missions")
	var first_card: VBoxContainer
	for node: Node in ui.body.get_children():
		if str(node.name).begins_with("MissionCard"):
			first_card = node
			break
	check(first_card != null and first_card.get_child(0).text == "出航准备", "new player first card is available T0 tutorial")
	ui.mission_filter = "all"; ui.show_page("missions")
	var cards: int = 0
	for node: Node in ui.body.get_children():
		if str(node.name).begins_with("MissionCard"): cards += 1
	check(cards <= 6 and cards > 0, "all missions are paginated into at most six cards")
	check(button_text(ui, "下一页") != null and not button_text(ui, "下一页").disabled, "full forty mission list has pagination")
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
	ui.show_page("")
	ui.tick(1.0)
	check(ui.health.text.contains("护盾") and ui.top.text.contains("雨燕"), "HUD refresh displays actual typed ship metrics")
	ui._refresh_targets()
	var stable: Dictionary = ui.target_buttons.duplicate()
	ui._refresh_targets()
	var reused: bool = true
	for id: String in stable: reused = reused and ui.target_buttons.get(id) == stable[id]
	check(reused and not stable.is_empty(), "target refresh reuses existing controls")
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
				check(close != null and viewport.encloses(close.get_global_rect()) and ui.page_scroll.size.y >= 40, "page header/scroll reachable %s %s x%.0f" % [key, str(size), scale])
			check(Rect2(Vector2.ZERO, ui.root.size).encloses(ui.operation_cancel.get_global_rect()), "waiting cancel reachable %s x%.0f" % [str(size), scale])
	ui.set_operation_status("idle", "")
	ui.show_page("")
	var npc: D.NpcStateDto = D.NpcStateDto.new()
	npc.npc_instance_id = "ui_health_fixture"
	npc.spawn_id = host.store.catalog.rows("npc_spawn_defs")[0].spawn_id
	npc.alive = true
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
	var npc_definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
	npc.shield = float(npc_definition.shield_max) * 0.5
	npc.armor = float(npc_definition.armor_max)
	npc.hull = float(npc_definition.hull_max)
	host.state.add("npc_state", npc)
	ui.target_id = npc.npc_instance_id
	host.gameplay.work.scan_target = "signal_anchor_gate_calibration"
	host.gameplay.work.scan_progress = 30.0
	host.gameplay.work.scan_remaining = 1.5
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	await process_frame
	ui.tick(1.0)
	await process_frame
	await process_frame
	check(ui.npc_detail.visible and is_equal_approx(ui.npc_bars[0].bar.max_value, float(npc_definition.shield_max)) and is_equal_approx(ui.npc_bars[0].bar.value, npc.shield), "selected NPC bars use actual three layer maxima")
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
