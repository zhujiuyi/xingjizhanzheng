extends "ui_information_v63.gd"
## Explicit UI/retention boundary fixtures, never natural progression evidence.
const Units64 = preload("res://runtime/space_units.gd")
const TOTAL_FIELDS64: Array[String] = ["outings", "lost_outings", "mined_units", "income_credit", "spent_credit", "damage_dealt", "damage_taken"]
var completion_cases: Array[String] = []
var layout_sizes: Array[Dictionary] = []
var completion_observations: Array[Dictionary] = []
var largest_loadout_observations: Array[Dictionary] = []
var home_station64: String = ""

func _initialize() -> void:
	get_tree().set_meta("xj_ui_completion_v64_diagnostic", true)
	create_timer(600.0).timeout.connect(func(): check(false, "completion UI watchdog"); finish())
	_run.call_deferred()

func _run() -> void:
	directory = OS.get_environment("XJ_UI_COMPLETION_V64_DIRECTORY").replace("\\", "/")
	if not check(fresh_external_directory("ui_completion_v64.gd", "ui-completion-v64"), "fresh scoped v64 database required"): await finish(); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db"); root.add_child(host); await frames(8)
	if not check(host.services_ready and host.state == null, "real Main initializes without personal save"): await finish(); return
	await host._command("new_world", "界面遗留整改专项", 1, ""); await settle_writer("fresh completion world")
	label = "after"; await fixture() # Existing paid cruiser, legal switch and private funding fixture.
	label = "completion"
	host.set_process(false); host.set_physics_process(false)
	if not check(not owned_ship_id.is_empty() and host.state.ship().ship_instance_id == owned_ship_id and host.state.ship().policy_id == "normal_owned", "existing real paid owned cruiser fixture is controlled"): await finish(); return
	home_station64 = host.gameplay.station()
	host.ui.requested.connect(func(action: String, target: String, amount: int, extra: String): request_events.append({"action": action, "target": target, "quantity": amount, "extra": extra}))
	await research_empty_case64()
	await related_navigation_case64()
	await hud_keyboard_case64()
	await distance_case64()
	await return_to_station(home_station64, host.state.ship())
	await report_metrics_case64()
	await disclosure_case64()
	await responsive_transactions_case64()
	await finish()

func _research_panel64() -> Node:
	var list: Node = host.ui.body.find_child("ResearchList", true, false)
	return list.get_parent() if is_instance_valid(list) else null

func _research_empty64() -> bool:
	var panel: Node = _research_panel64()
	if not check(is_instance_valid(panel), "real classified research panel exists"): return false
	var empty: Control = host.ui.body.find_child("ResearchEmptyState", true, false) as Control
	var detail: Control = host.ui.body.find_child("ResearchDetailFrame", true, false) as Control
	var actions: Array[Button] = []
	if is_instance_valid(empty):
		for node: Node in descendants(empty):
			if node is Button and node.is_visible_in_tree() and not node.disabled: actions.append(node)
	var completed: int = 0
	for entry: Dictionary in panel.get("entries"):
		if str(entry.kind) == str(panel.get("category")) and bool(panel.call("_done", entry)): completed += 1
	return check(panel.get("rows").is_empty() and completed > 0 and is_instance_valid(empty) and host.ui.body.find_children("ResearchEmptyState", "PanelContainer", true, false).size() == 1 and host.ui.body.find_child("ResearchTableHeader", true, false) == null and is_instance_valid(detail) and not detail.is_visible_in_tree() and actions.size() == 1 and actions[0].name == "ResearchShowCompleted" and int(actions[0].get_meta("count", -1)) == completed, "completed-only category has no header or empty detail and exactly one real completed-history action")

func research_empty_case64() -> void:
	await show_interaction("research")
	if not await choose("ResearchTab_faction", "select actual faction category"): return
	var panel: Node = _research_panel64()
	if bool(panel.get("show_completed")): await choose("ResearchShowCompleted", "exclude completed faction projects")
	var authority: String = state_tables(["unlock_state", "base_module_state", "specialization_research_state", "exploration_research_state", "player_state", "rng_state"])
	if not _research_empty64(): return
	await inspect("completion-research-initial-1440x900", "research")
	if not await choose("ResearchShowCompleted", "restore real completed research from empty state"): return
	panel = _research_panel64()
	check(not panel.get("rows").is_empty() and host.ui.body.find_child("ResearchEmptyState", true, false) == null and host.ui.body.find_child("ResearchTableHeader", true, false) != null and host.ui.body.find_child("ResearchDetailFrame", true, false).is_visible_in_tree(), "empty-state action restores actual rows, header and selected detail")
	for row: Dictionary in panel.get("rows"): check(bool(panel.call("_done", row.entry)), "restored history contains genuinely completed definition " + str(row.entry.id))
	check(state_tables(["unlock_state", "base_module_state", "specialization_research_state", "exploration_research_state", "player_state", "rng_state"]) == authority, "research empty-state browsing preserves authority and RNG")
	completion_cases.append("research_empty")

func related_navigation_case64() -> void:
	var before: String = resources()
	await show_interaction("reports")
	var empty: Control = host.ui.body.find_child("ReportEmptyState", true, false) as Control
	check(host.gameplay.telemetry.export_rows().is_empty() and empty != null and empty.is_visible_in_tree(), "fresh non-flying world has one explicit report empty state")
	_metrics64("fresh report empty state")
	if await choose("ReportEmptyAction", "follow real report empty-state next step"):
		check(host.ui.page == "station" and host.state.ship().status == T.ShipStatus.DOCKED and resources() == before, "report empty-state action reaches hangar without auto-undocking or changing funds")
	for pair: Array in [["ships", "ship_roles"], ["fitting", "fitting_analysis"], ["missions", "operations"], ["industry", "projects"], ["market", "sources"], ["map", "exploration"], ["civilizations", "research"], ["pause", "reports"]]:
		await show_interaction(str(pair[0]))
		if not await actual_related(str(pair[1]), "completion related " + str(pair[0])): continue
		var back: Button = host.ui.panel.find_child("PanelClose", true, false) as Button
		if await actual_click(back, "return to actual related source " + str(pair[0])): check(host.ui.page == str(pair[0]), "related return preserves actual source " + str(pair[0]))
	await show_interaction("missions")
	var menu: MenuButton = host.ui.panel.find_child("RelatedNavigation", true, false) as MenuButton
	if not check(menu != null, "related keyboard navigation menu exists"): return
	var reached: bool = false
	for step: int in range(60):
		if root.gui_get_focus_owner() == menu: reached = true; break
		await native_key(KEY_TAB)
	check(reached, "page Tab chain actually reaches related navigation")
	if reached:
		await native_key(KEY_ENTER)
		var popup: PopupMenu = menu.get_popup()
		check(popup.visible, "pure keyboard Enter opens related menu")
		var wanted: int = -1
		for index: int in range(popup.item_count):
			if str(popup.get_item_metadata(index)) == "operations": wanted = index
		for step: int in range(popup.item_count + 1):
			if popup.get_focused_item() == wanted: break
			await native_key(KEY_DOWN, popup)
		check(wanted >= 0 and popup.get_focused_item() == wanted, "pure keyboard reaches actual operations item")
		if wanted >= 0: await native_key(KEY_ENTER, popup)
		check(host.ui.page == "operations", "pure keyboard related navigation reaches operations")
	await show_interaction("missions")
	menu = host.ui.panel.find_child("RelatedNavigation", true, false) as MenuButton
	var callbacks: Array = menu.get_popup().get_signal_connection_list("id_pressed")
	if not check(not callbacks.is_empty(), "real related menu callback can be retained for stale probe"): return
	var old_callback: Callable = callbacks[0].callable
	menu.reparent(root, false); menu.hide()
	var count: int = request_events.size()
	old_callback.call(0); await frames(3)
	check(host.ui.page == "missions" and request_events.size() == count and resources() == before, "hidden detached related menu callback cannot navigate or mutate authority")
	await show_interaction("ships"); old_callback.call(0); await frames(3)
	check(host.ui.page == "ships" and request_events.size() == count and resources() == before, "previous page related callback is rejected after page generation changes")
	menu.queue_free(); await frames(2)
	await host._command("undock", "", 1, ""); await settle_writer("real owned cruiser undock")
	check(host.state.ship().status == T.ShipStatus.FLYING, "completion flight starts through actual undock")
	host._process(0.0)
	for page_name: String in ["missions", "fitting_analysis", "map", "pause"]:
		await show_interaction(page_name)
		var flight_menu: MenuButton = host.ui.panel.find_child("RelatedNavigation", true, false) as MenuButton
		var ids: Array[String] = []
		if flight_menu != null:
			for index: int in range(flight_menu.get_popup().item_count): ids.append(str(flight_menu.get_popup().get_item_metadata(index)))
		for blocked: String in ["market", "industry", "research"]: check(blocked not in ids, "flight related menu omits dock-only destination " + page_name + " " + blocked)
		if DroneAvailability63.equipped(host.gameplay).is_empty(): check("drones" not in ids, "unmounted cruiser has no flight drone related command " + page_name)
	completion_cases.append("related_navigation")

func _focus_hud64(target: Control) -> bool:
	if not check(is_instance_valid(target) and target.is_visible_in_tree(), "HUD keyboard target is actually visible"): return false
	var entries: Array[Control] = host.ui.hud_focus.controls(host.ui)
	for step: int in range(entries.size() + 1):
		if root.gui_get_focus_owner() == target: return true
		await native_key(KEY_TAB)
	return check(false, "HUD Tab traversal reaches actual target " + str(target.name))

func hud_keyboard_case64() -> void:
	await show_interaction(""); host._process(0.0); await frames(5)
	var overview: Node = host.ui.overview
	if not check(overview.filtered_ids.size() > 1, "real flight supplies multiple target candidates"): return
	var before_target: String = host.ui.target_id
	await native_key(KEY_TAB)
	check(not host.ui.target_id.is_empty() and host.ui.target_id != before_target and not host.ui.hud_focus.active, "normal Tab retains target cycling outside HUD mode")
	var station: Button = overview.target_buttons.get(home_station64) as Button
	if not await actual_click(station, "select real local station before keyboard navigation"): return
	await native_key(KEY_F6)
	if not check(host.ui.hud_focus.active and is_instance_valid(root.gui_get_focus_owner()) and not host._keyboard_control_allowed(), "F6 enters actual HUD focus and blocks flight polling"): return
	var focus: Control = root.gui_get_focus_owner()
	var target: String = host.ui.target_id
	await native_key(KEY_TAB)
	check(root.gui_get_focus_owner() != focus and host.ui.target_id == target, "HUD Tab traverses controls without cycling targets")
	focus = root.gui_get_focus_owner(); await native_key(KEY_RIGHT)
	check(root.gui_get_focus_owner() != focus and host.ui.hud_focus.active, "HUD arrow traverses controls")
	await native_key(KEY_LEFT)
	check(root.gui_get_focus_owner() == focus, "reverse HUD arrow returns to prior control")
	var pose: Transform3D = host.world.flight.global_transform
	var camera_mode: int = host.state.player().camera_mode
	var options: Dictionary = host.combat_automation.options.duplicate()
	var slots_before: String = JSON.stringify(host.store.list_slots())
	var count: int = request_events.size()
	for key: Key in [KEY_W, KEY_V, KEY_Z, KEY_M, KEY_J, KEY_F5, KEY_F9]: await native_key(key)
	check(host.ui.page.is_empty() and host.ui.hud_focus.active and not host._keyboard_control_allowed() and host.state.player().camera_mode == camera_mode and host.combat_automation.options == options and host.world.flight.global_transform.is_equal_approx(pose) and JSON.stringify(host.store.list_slots()) == slots_before and request_events.size() == count, "HUD focus suppresses movement camera combat page and save shortcuts")
	var approach: Button = overview.action_buttons.get("nav_approach") as Button
	if await _focus_hud64(approach):
		var generation: int = host.navigation_generation
		await native_key(KEY_ENTER); await settle_writer("keyboard HUD approach")
		check(host.navigation_generation == generation + 1 and host.local_navigation.target_id == home_station64 and host.local_navigation.active(), "HUD Enter submits actual Main navigation while raw flight keys stay blocked")
		host._process(0.0); await frames(3)
		if await _focus_hud64(overview.action_buttons.get("nav_stop") as Control):
			await native_key(KEY_ENTER); await frames(3)
			check(not host.local_navigation.active() and host.local_navigation.phase == "cancelled" and host.local_navigation.target_id.is_empty() and host.world.flight.velocity.is_zero_approx(), "HUD Enter stop actually cancels accepted navigation and zeroes physical motion")
	var fire: Control = host.ui.equipment_bar.combat_option_buttons.get("fire") as Control
	if await _focus_hud64(fire):
		var original: bool = bool(host.combat_automation.options.fire)
		await native_key(KEY_ENTER)
		check(bool(host.combat_automation.options.fire) != original and host.ui.hud_focus.active and not host._keyboard_control_allowed(), "HUD Enter toggles actual Main combat option")
		await native_key(KEY_ENTER)
		check(bool(host.combat_automation.options.fire) == original and host.combat_automation.options == options, "second HUD Enter restores original combat option")
	var radar: bool = host.ui.radar_expanded
	if await _focus_hud64(host.ui.radar_button):
		await native_key(KEY_ENTER); check(host.ui.radar_expanded != radar, "HUD Enter reaches rendered radar toggle")
		await native_key(KEY_ENTER); check(host.ui.radar_expanded == radar, "radar keyboard action restores original view")
	await native_key(KEY_ESCAPE)
	check(not host.ui.hud_focus.active and host.ui.page.is_empty() and host.state.ship().status == T.ShipStatus.FLYING and host._keyboard_control_allowed(), "Esc exits HUD focus and resumes flight without opening pause")
	await inspect("completion-hud-keyboard-1440x900", "")
	completion_cases.append("hud_keyboard")

func distance_case64() -> void:
	var overview: Node = host.ui.overview
	var before: String = state_tables(["player_state", "ship_state", "rng_state"])
	var sampled: int = 0
	for record: Dictionary in overview.entry_rows:
		var button: Button = overview.target_buttons.get(str(record.id)) as Button
		if button == null or not button.visible: continue
		var cell: Control = button.find_child("DistanceCell", true, false) as Control
		var number: Label = cell.get_node("Distance") as Label if cell != null else null
		var unit: Label = cell.get_node("DistanceUnit") as Label if cell != null else null
		var formatted: PackedStringArray = Units64.distance(float(record.distance_m)).split(" ")
		check(cell != null and number != null and unit != null and float(cell.get_meta("distance_metres", -1.0)) == float(record.distance_m) and number.text == formatted[0] and unit.text == (formatted[1] if formatted.size() > 1 else "") and number.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and unit.get_theme_font_size("font_size") < number.get_theme_font_size("font_size"), "distance separates numeric/unit text without changing actual metres " + str(record.id))
		if cell != null and number != null and unit != null: check(number.get_global_rect().end.x <= unit.get_global_rect().position.x + 1.0, "distance numeric and unit glyph columns do not overlap " + str(record.id))
		sampled += 1
	check(sampled >= 2, "distance rendering samples actual live contacts")
	for ascending: bool in [false, true]:
		if bool(overview.sort_ascending) != ascending: await actual_click(overview.sort_buttons.distance, "toggle real distance sort")
		var previous: float = -INF if ascending else INF
		for id: String in overview.filtered_ids:
			var metres: float = 0.0
			for record: Dictionary in overview.entry_rows:
				if str(record.id) == id: metres = float(record.distance_m); break
			check(metres >= previous if ascending else metres <= previous, "real contact order remains numeric metres " + str(ascending) + " " + id)
			previous = metres
	check(state_tables(["player_state", "ship_state", "rng_state"]) == before, "distance rendering and sort preserve world authority")
	completion_cases.append("distance")

func _metrics64(message: String) -> bool:
	var metrics: Node = host.ui.body.find_child("ReportMetrics", true, false)
	if not check(metrics != null and metrics.get_child_count() == 5, "exactly five real metric cards " + message): return false
	var total: RefCounted = host.gameplay.telemetry.totals()
	for field: String in TOTAL_FIELDS64:
		var value: Label = metrics.find_child("ReportTotal_" + field, true, false) as Label
		var expected: String = "%.0f" % float(total.get(field)) if field in ["damage_dealt", "damage_taken"] else str(int(total.get(field)))
		check(value != null and value.text == expected and str(value.get_meta("telemetry_field", "")) == field and value.get_meta("metric_value") == total.get(field), "metric card reads actual cumulative DTO " + field + " " + message)
	return true

func report_metrics_case64() -> void:
	var total: RefCounted = host.gameplay.telemetry.totals()
	var original: Dictionary = {}
	for field: String in TOTAL_FIELDS64: original[field] = total.get(field); total.set(field, 0)
	await show_interaction("reports"); _metrics64("explicit zero presentation fixture")
	var samples: Dictionary = {"outings": 500, "lost_outings": 30, "mined_units": 12345, "income_credit": 987654, "spent_credit": 87654, "damage_dealt": 123.75, "damage_taken": 45.25}
	for field: String in TOTAL_FIELDS64: total.set(field, samples[field])
	host.ui.tick(0.0); await create_timer(0.3).timeout; await frames(3)
	_metrics64("explicit nonzero DTO presentation fixture")
	for field: String in TOTAL_FIELDS64: total.set(field, original[field])
	# Actual service retention, with declared zero-duration telemetry lifecycle
	# fixtures. No balance/report_limit changes and no natural voyage claim.
	var maximum: int = int(host.gameplay.rows("campaign_balance_defs")[0].report_limit)
	if not check(maximum > 0 and maximum <= 100, "finite catalog report retention boundary is suitable for bounded fixture"): return
	for index: int in range(maximum + 2): host.gameplay.telemetry.begin(); host.gameplay.telemetry.finish()
	await show_interaction("reports"); _metrics64("after actual service history pruning")
	check(host.gameplay.telemetry.export_rows().size() == maximum and int(host.gameplay.telemetry.totals().outings) > maximum, "actual report retention prunes history while cumulative outings remain larger")
	completion_observations.append({"case": "report_retention", "limit": maximum, "retained": host.gameplay.telemetry.export_rows().size(), "outings": host.gameplay.telemetry.totals().outings, "temporary_fields_restored": true})
	await inspect("completion-report-metrics-1440x900", "reports")
	completion_cases.append("report_metrics")

func _disclosure64(button: Button, expanded: bool, count: int = -1) -> bool:
	return check(button != null and button.toggle_mode and bool(button.get_meta("ui_disclosure", false)) and bool(button.get_meta("expanded", not expanded)) == expanded and button.button_pressed == expanded and int(button.get_meta("count", -2)) == count and button.text.begins_with("v " if expanded else "> ") and button.focus_mode == Control.FOCUS_ALL and not button.tooltip_text.is_empty(), "disclosure has shared native state arrow count and focus " + (str(button.name) if button != null else "missing"))

func disclosure_case64() -> void:
	await show_interaction("research")
	var unlocks: Button = button_named("ResearchUnlocks")
	_disclosure64(unlocks, bool(unlocks.get_meta("expanded", false)), host.state.rows("unlock_state").size())
	if not bool(unlocks.get_meta("expanded", false)): await choose("ResearchUnlocks", "open qualification disclosure")
	check(host.ui.body.find_child("ResearchQualifications", true, false).is_visible_in_tree(), "qualification disclosure exposes actual history")
	unlocks.grab_focus(); await native_key(KEY_SPACE)
	_disclosure64(unlocks, false, host.state.rows("unlock_state").size())
	check(root.gui_get_focus_owner() == unlocks and not host.ui.body.find_child("ResearchQualifications", true, false).is_visible_in_tree(), "keyboard collapse retains qualification toggle focus")
	host.ui.civilization_selected_faction = "faction_route_council"; host.ui.set_meta("civilization_section", "progress")
	await show_interaction("civilizations")
	var growth: RefCounted = host.ui.civilization_panel.growth_panel
	var routes: Button = button_named("GrowthRoutesToggle")
	if not check(routes != null, "real incomplete alternatives expose growth disclosure"): return
	var alternatives: int = 0
	for goal: Dictionary in growth.goals:
		if str(goal.stage_id) != str(growth.selected_stage.get("stage_id", "")) and not bool(host.gameplay.growth.progress(goal).complete): alternatives += 1
	_disclosure64(routes, false, alternatives)
	await choose("GrowthRoutesToggle", "open actual growth alternatives")
	routes = button_named("GrowthRoutesToggle"); _disclosure64(routes, true, alternatives)
	check(root.gui_get_focus_owner() == routes, "rebuilt growth disclosure restores exact semantic keyboard focus")
	var next: Button = button_named("GrowthPreviewNext")
	var old_callbacks: Array = next.get_signal_connection_list("pressed")
	var old: Callable = old_callbacks[0].callable if not old_callbacks.is_empty() else Callable()
	routes.grab_focus(); await native_key(KEY_ENTER); await frames(6)
	routes = button_named("GrowthRoutesToggle"); _disclosure64(routes, false, alternatives)
	var preview: String = growth.preview_stage_id
	if old.is_valid(): old.call(); await frames(2)
	check(root.gui_get_focus_owner() == routes and not host.ui.body.find_child("GrowthRoutes", true, false).is_visible_in_tree() and growth.preview_stage_id == preview, "growth keyboard collapse restores focus and rejects removed detail callback")
	var member: RefCounted = host.gameplay.civilizations.membership()
	var membership: Dictionary = {"has_faction": member.has_faction_id, "id": member.faction_id}
	member.has_faction_id = true; member.faction_id = "faction_route_council"
	await create_timer(0.3).timeout; host.ui.tick(0.0); await frames(6)
	var history: Button = button_named("GrowthHistoryToggle")
	if check(history != null, "declared membership boundary exposes genuinely completed growth history"):
		var complete: int = 0
		for goal: Dictionary in growth.goals:
			if bool(host.gameplay.growth.progress(goal).complete): complete += 1
		_disclosure64(history, false, complete)
		await choose("GrowthHistoryToggle", "open completed growth records")
		history = button_named("GrowthHistoryToggle"); _disclosure64(history, true, complete)
		await choose("GrowthHistoryToggle", "close completed growth records")
	member.has_faction_id = bool(membership.has_faction); member.faction_id = str(membership.id)
	await show_interaction("reports")
	for name: String in ["ReportHistoryToggle", "ReportStatisticsToggle"]:
		var toggle: Button = button_named(name)
		if not check(toggle != null, "real report disclosure exists " + name): continue
		var count: int = host.gameplay.telemetry.export_rows().size() - 1 if name == "ReportHistoryToggle" else -1
		_disclosure64(toggle, false, count)
		await choose(name, "open actual report disclosure " + name); _disclosure64(toggle, true, count)
		await choose(name, "close actual report disclosure " + name); _disclosure64(toggle, false, count)
	var list: Node = host.ui.body.find_child("ReportList", true, false)
	var latest: String = str(host.gameplay.telemetry.latest().sequence)
	check(str(list.get("selected_id")) == latest, "collapsing report history leaves latest actual flight selected")
	await show_interaction("fitting_analysis")
	for pair: Array in [["FittingConditionsToggle", "FittingDistance"], ["FittingDetailsToggle", "FittingDetailedValues"]]:
		var toggle: Button = button_named(str(pair[0]))
		_disclosure64(toggle, false)
		await choose(str(pair[0]), "open actual fitting disclosure"); _disclosure64(toggle, true)
		check(host.ui.body.find_child(str(pair[1]), true, false).is_visible_in_tree(), "actual fitting content becomes reachable " + str(pair[1]))
		toggle.grab_focus(); await native_key(KEY_SPACE); _disclosure64(toggle, false)
		check(root.gui_get_focus_owner() == toggle and not host.ui.body.find_child(str(pair[1]), true, false).is_visible_in_tree(), "fitting keyboard collapse retains focus and hides actual content")
	await show_interaction("pause")
	for pair: Array in [["FlightHelpToggle", "FlightControlHelp"], ["ArchiveDetailsToggle", "ArchiveDetails"]]:
		var toggle: Button = button_named(str(pair[0]))
		var count: int = host.ui.slots.size() if str(pair[0]) == "ArchiveDetailsToggle" else -1
		_disclosure64(toggle, false, count)
		toggle.grab_focus(); await native_key(KEY_ENTER); await frames(4)
		_disclosure64(toggle, true, count)
		check(host.ui.body.find_child(str(pair[1]), true, false).is_visible_in_tree(), "pause disclosure reveals actual content by keyboard " + str(pair[1]))
		await native_key(KEY_SPACE); await frames(4)
		_disclosure64(toggle, false, count)
		check(root.gui_get_focus_owner() == toggle and not host.ui.body.find_child(str(pair[1]), true, false).is_visible_in_tree(), "pause disclosure collapses without losing keyboard focus " + str(pair[1]))
	await save_cards_case64()
	completion_cases.append("disclosure")

func _caption64(caption: String) -> Button:
	for node: Node in descendants(host.ui.body):
		if node is Button and node.text == caption: return node as Button
	return null

func _manual_slot64() -> Dictionary:
	for slot: Dictionary in host.store.list_slots():
		if str(slot.world_id) == host.state.world_id and str(slot.slot_kind) == "manual" and int(slot.slot_index) == 4: return slot
	return {}

func save_cards_case64() -> void:
	await choose("ArchiveDetailsToggle", "show actual manual save cards")
	var save: Button = _caption64("保存至手动槽 5")
	if not check(save != null, "actual empty manual slot exposes save action"): return
	var old_save: Callable = save.get_signal_connection_list("pressed")[0].callable
	if not await actual_click(save, "save private world into manual slot five"): return
	await settle_writer("actual manual save card refresh"); await frames(6)
	var first: Dictionary = _manual_slot64()
	if not check(not first.is_empty() and _caption64("读取 手动槽 5") != null, "saving an empty slot immediately exposes its actual new read action"): return
	var toggle: Button = button_named("ArchiveDetailsToggle")
	_disclosure64(toggle, true, host.store.list_slots().size())
	save = _caption64("保存至手动槽 5")
	check(root.gui_get_focus_owner() == save, "local save-card rebuild preserves the initiating keyboard focus")
	var requests: int = request_events.size()
	if old_save.is_valid(): old_save.call(); await frames(2)
	check(request_events.size() == requests, "removed save card cannot replay a hidden old save request")
	var old_load: Callable = _caption64("读取 手动槽 5").get_signal_connection_list("pressed")[0].callable
	if not await actual_click(save, "overwrite the actual manual slot from its refreshed card"): return
	await settle_writer("actual manual overwrite refresh"); await frames(6)
	var latest: Dictionary = _manual_slot64()
	check(int(latest.get("generation",0)) > int(first.get("generation",0)) and str(latest.get("current_snapshot_id","")) != str(first.get("current_snapshot_id","")), "overwrite advances the real saved generation and snapshot")
	_disclosure64(button_named("ArchiveDetailsToggle"), true, host.store.list_slots().size())
	requests = request_events.size()
	if old_load.is_valid(): old_load.call(); await frames(2)
	check(request_events.size() == requests, "removed old-generation read card cannot submit a stale request")
	if not await actual_click(_caption64("读取 手动槽 5"), "read the current generation from the updated save card"): return
	await settle_writer("actual refreshed manual read"); await frames(6)
	host.set_process(false); host.set_physics_process(false)
	check(host.ui.page == "station" and host.state.snapshot.meta.snapshot_id == str(latest.current_snapshot_id), "refreshed read action loads the latest saved snapshot through Main")

func _reachable64(control: Control, message: String) -> bool:
	if not check(is_instance_valid(control) and control.is_visible_in_tree(), "visible critical control " + message): return false
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await frames(4)
	var bounds: Rect2 = Rect2(Vector2.ZERO, host.ui.root.size)
	var clip: Array = clip_info(control, bounds).visible_rect
	var visible: Rect2 = Rect2(Vector2(clip[0], clip[1]), Vector2(clip[2], clip[3]))
	return check(bounds.grow(1.0).encloses(control.get_global_rect()) and visible.grow(1.0).encloses(control.get_global_rect()), "whole critical control is reachable after vertical reveal " + message)

func _units64(item_id: String) -> int:
	var result: int = 0
	for row: RefCounted in host.state.rows("inventory_stack_state"):
		if row.item_def_id == item_id: result += int(row.quantity)
	for row: RefCounted in host.state.rows("item_instance_state"):
		if row.item_def_id == item_id: result += 1
	return result

func largest_loadout_case64(layout_name: String) -> void:
	# Pure display records using the production ui._update_module_bar schema.
	# No equipment/container DTO is created and no synthetic ID is submitted.
	var grouped: Dictionary = {}
	for slot: Dictionary in host.gameplay.rows("ship_slot_defs"):
		var id: String = str(slot.ship_id)
		if not grouped.has(id): grouped[id] = []
		grouped[id].append(slot)
	var hull_id: String = ""
	for id: String in grouped:
		if hull_id.is_empty() or grouped[id].size() > grouped[hull_id].size(): hull_id = id
	var slots: Array = grouped.get(hull_id, [])
	if not check(slots.size() == 17, "actual catalog maximum has seventeen slots " + layout_name): return
	var kinds: Array[String] = ["weapon", "work", "utility", "structure"]
	var modules: Dictionary = {}
	for definition: Dictionary in host.gameplay.rows("module_defs"):
		var kind: String = str(definition.slot_type)
		if not modules.has(kind) or str(definition.module_id).begins_with("module_engine_"): modules[kind] = definition
	var records: Array[Dictionary] = []
	for slot: Dictionary in slots:
		var kind: String = str(slot.slot_type)
		if not check(modules.has(kind) and kind in kinds, "catalog module exists for display slot type " + kind): return
		var module: Dictionary = modules[kind]
		var type: int = kinds.find(kind)
		var cycle: float = float(module.get("cycle_s", 0.0))
		var display_id: String = "display17_" + kind + "_" + str(slot.slot_index)
		records.append({"id":display_id, "slot_id":display_id, "module_id":str(module.module_id), "title":host.ui._item_name(str(module.module_id)), "slot_type":type, "slot_title":["武器","作业","通用","结构"][type], "slot_short":["武","作","通","构"][type], "slot_index":int(slot.slot_index), "enabled":true, "cooldown_remaining_s":cycle, "active_remaining_s":0.0, "cycle_s":cycle, "energy_eu":float(module.get("energy_eu",0.0)), "heat_hu":float(module.get("heat_hu",0.0)), "durability":host.gameplay.rule("module_durability_max"), "state_label":"冷却 %.1f s" % cycle if cycle > 0.0 else "持续启用", "ready":cycle <= 0.0})
	var empty_slots: Array[Dictionary] = []
	var metrics: Dictionary = host.gameplay.metrics(host.state.ship())
	var resources_view: Dictionary = {"energy":host.state.ship().energy, "energy_max":metrics.energy_max, "heat_ratio":host.state.ship().heat / maxf(float(metrics.heat_max),1.0), "engine_ready":false, "engine_reason":"纯显示夹具不提交设备命令。", "empty_slots":empty_slots}
	var authority: String = resources() + state_tables(["rng_state","telemetry_total_state","flight_record_state"])
	var stored: String = JSON.stringify(host.store.list_slots())
	var requests: int = request_events.size()
	var bar: XJEquipmentBar = host.ui.equipment_bar as XJEquipmentBar
	var original_records: Array = bar.module_records.duplicate(true)
	var original_slots: Array = bar.slot_records.duplicate(true)
	var visibility: Dictionary = {"panel":host.ui.panel.visible, "dock":host.ui.flight_dock.visible, "bar":bar.visible, "instrument":host.ui.instrument.visible}
	host.ui.panel.hide(); host.ui.flight_dock.show(); host.ui.instrument.show(); bar.show()
	var fixture_label := Label.new()
	fixture_label.text = "17槽纯显示夹具 · 非实际装配"
	fixture_label.position = Vector2(16,16)
	fixture_label.add_theme_color_override("font_color",AuditTheme.TEXT)
	host.ui.root.add_child(fixture_label)
	bar.call("refresh", records, resources_view, true)
	host.ui._responsive(); await frames(8)
	var row: HFlowContainer = bar.find_child("EquipmentRow",true,false) as HFlowContainer
	var bounds: Rect2 = Rect2(Vector2.ZERO,host.ui.root.size)
	var all_fit: bool = row != null and bar.module_buttons.size() == slots.size()
	var tile_rects: Array[Dictionary] = []
	var rows_y: Array[float] = []
	var bottom: float = row.global_position.y if row != null else 0.0
	for record: Dictionary in records:
		var tile: Control = bar.module_buttons.get(str(record.id)) as Control
		var fits: bool = is_instance_valid(tile) and tile.is_visible_in_tree() and row != null and row.get_global_rect().grow(1.0).encloses(tile.get_global_rect()) and bar.get_global_rect().grow(1.0).encloses(tile.get_global_rect()) and bounds.grow(1.0).encloses(tile.get_global_rect())
		all_fit = all_fit and fits
		check(fits, "actual seventeen-slot tile fully fits Root and flow " + str(record.id) + " " + layout_name)
		if not is_instance_valid(tile): continue
		var rect: Rect2 = tile.get_global_rect()
		var labels: Dictionary = bar.module_labels.get(str(record.id), {})
		var title: Label = labels.get("title") as Label
		var status: Label = labels.get("status") as Label
		var title_rect: Array[float] = []
		var status_rect: Array[float] = []
		var status_width: float = 0.0
		var labels_fit: bool = is_instance_valid(title) and is_instance_valid(status)
		if labels_fit:
			title_rect = rectangle(title.get_global_rect())
			status_rect = rectangle(status.get_global_rect())
			labels_fit = title.is_visible_in_tree() and rect.grow(1.0).encloses(title.get_global_rect()) and bounds.grow(1.0).encloses(title.get_global_rect())
			check(labels_fit, "actual slot title remains inside its Button and Root " + str(record.id) + " " + layout_name)
			check(status.visible == (not status.text.is_empty()), "only actual nonempty module state displays a status label " + str(record.id) + " " + layout_name)
			if not status.text.is_empty():
				status_width = status.get_theme_font("font").get_string_size(status.text,HORIZONTAL_ALIGNMENT_LEFT,-1,status.get_theme_font_size("font_size")).x
				var separate: bool = not status.get_global_rect().intersects(title.get_global_rect())
				var status_fits: bool = status.is_visible_in_tree() and status_width <= status.size.x + 1.0 and rect.grow(1.0).encloses(status.get_global_rect()) and bounds.grow(1.0).encloses(status.get_global_rect())
				check(separate, "actual module state never overlaps slot title " + str(record.id) + " " + layout_name)
				check(status_fits, "actual module state glyph width and rectangle fit Button and Root " + str(record.id) + " " + layout_name)
				labels_fit = labels_fit and separate and status_fits
		var full_state: bool = tile.tooltip_text.contains(str(record.state_label))
		check(full_state, "module tooltip retains complete original state and seconds " + str(record.id) + " " + layout_name)
		var ring: Control = bar.module_progress.get(str(record.id)) as Control
		var ring_values: bool = is_instance_valid(ring) and is_equal_approx(float(ring.get("value")),float(record.cooldown_remaining_s)) and is_equal_approx(float(ring.get("max_value")),maxf(float(record.cycle_s),0.001)) and ring.visible == (float(record.cooldown_remaining_s) > 0.0)
		check(ring_values, "actual module ring retains catalog cycle and full remaining seconds " + str(record.id) + " " + layout_name)
		all_fit = all_fit and labels_fit and full_state and ring_values
		for previous: Dictionary in tile_rects:
			var prior: Array = previous.rect
			var overlap: bool = Rect2(Vector2(prior[0],prior[1]),Vector2(prior[2],prior[3])).grow(-0.5).intersects(rect.grow(-0.5))
			all_fit = all_fit and not overlap
			check(not overlap, "real equipment flow tiles do not overlap " + str(record.id) + " " + str(previous.id) + " " + layout_name)
		var known_y: bool = false
		for y: float in rows_y:
			if absf(y-rect.position.y) <= 1.0: known_y = true
		if not known_y: rows_y.append(rect.position.y)
		bottom = maxf(bottom,rect.end.y)
		tile_rects.append({"id":record.id, "module_id":record.module_id, "slot_type":record.slot_type, "slot_index":record.slot_index, "rect":rectangle(rect), "minimum":[tile.get_combined_minimum_size().x,tile.get_combined_minimum_size().y], "visible":tile.is_visible_in_tree(), "fits":fits, "title_rect":title_rect, "status_rect":status_rect, "status_text":status.text if is_instance_valid(status) else "", "status_text_width":status_width, "labels_fit":labels_fit, "original_state":record.state_label, "tooltip_retains_state":full_state, "ring_values_match":ring_values})
	var actual_height: float = bottom - row.global_position.y if row != null else INF
	if row != null:
		all_fit = all_fit and row.get_combined_minimum_size().x <= row.size.x + 1.0 and actual_height <= row.size.y + 1.0 and bounds.grow(1.0).encloses(row.get_global_rect())
		check(actual_height <= row.size.y + 1.0, "actual full equipment flow height %.0f fits %.0f in %d rendered rows " % [actual_height,row.size.y,rows_y.size()] + layout_name)
	if bar.engine_button.is_visible_in_tree():
		var engine_fits: bool = row != null and row.get_global_rect().grow(1.0).encloses(bar.engine_button.get_global_rect()) and bounds.grow(1.0).encloses(bar.engine_button.get_global_rect())
		all_fit = all_fit and engine_fits
		check(engine_fits,"additional real engine control fits full-loadout flow " + layout_name)
	for node: Node in descendants(bar):
		if node is HScrollBar and node.is_visible_in_tree(): all_fit = false
	check(all_fit, "all seventeen actually rendered module tiles fit without horizontal scrolling " + layout_name)
	var screenshot: String = ""
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		screenshot = directory.path_join("completion-display-largest-"+layout_name+".png")
		check(image.get_size() == root.size and image.save_png(screenshot) == OK, "native pure-display seventeen-slot boundary screenshot " + layout_name)
		captures += 1
	largest_loadout_observations.append({"display_fixture":true, "hull_id":hull_id, "slot_count":slots.size(), "native":[root.size.x,root.size.y], "logical":[host.ui.root.size.x,host.ui.root.size.y], "tile_rects":tile_rects, "row_rect":rectangle(row.get_global_rect()) if row != null else [], "rendered_rows":rows_y.size(), "actual_flow_height":actual_height, "all_visible_fits":all_fit, "screenshot":screenshot, "scope":"catalog slots/modules in the production EquipmentBar; no authoritative equipment or save mutation, no legal full-loadout claim"})
	fixture_label.queue_free()
	host.ui._update_module_bar(host.state.ship(),host.gameplay.metrics(host.state.ship()))
	host.ui.panel.visible = bool(visibility.panel); host.ui.flight_dock.visible = bool(visibility.dock); bar.visible = bool(visibility.bar); host.ui.instrument.visible = bool(visibility.instrument)
	await frames(4)
	check(bar.module_records == original_records and bar.slot_records == original_slots and resources() + state_tables(["rng_state","telemetry_total_state","flight_record_state"]) == authority and JSON.stringify(host.store.list_slots()) == stored and request_events.size() == requests, "display boundary restores original component resources and leaves authority saves and commands untouched " + layout_name)

func responsive_transactions_case64() -> void:
	for layout: Dictionary in [{"name":"1440x900", "native":Vector2i(1440,900), "logical":Vector2i(1440,900)}, {"name":"1024x648", "native":Vector2i(1024,648), "logical":Vector2i(1024,648)}, {"name":"1920x1080", "native":Vector2i(1920,1080), "logical":Vector2i(1920,1080)}, {"name":"1280x720-200pct", "native":Vector2i(1280,720), "logical":Vector2i(640,360)}]:
		root.size = layout.native; root.content_scale_size = layout.logical; await frames(8)
		host.ui._responsive(); await frames(4)
		check(host.ui.root.size.is_equal_approx(Vector2(layout.logical)), "actual native/logical completion layout " + str(layout.name))
		layout_sizes.append({"name": layout.name, "native": [root.size.x,root.size.y], "logical": [host.ui.root.size.x,host.ui.root.size.y]})
		await show_interaction("reports"); _metrics64(str(layout.name))
		for field: String in TOTAL_FIELDS64: await _reachable64(host.ui.body.find_child("ReportTotal_" + field, true, false), "metric " + field + " " + str(layout.name))
		await inspect("completion-reports-" + str(layout.name), "reports")
		await show_interaction("research"); await choose("ResearchTab_faction", "responsive faction category")
		var panel: Node = _research_panel64()
		if bool(panel.get("show_completed")): await choose("ResearchShowCompleted", "responsive completed-only empty state")
		_research_empty64(); await _reachable64(button_named("ResearchShowCompleted"), "empty-state history action " + str(layout.name))
		await inspect("completion-research-empty-" + str(layout.name), "research")
		host.ui.market_filter = "buy"; await show_interaction("market")
		var selected: Dictionary = {}
		var lowest: int = 9223372036854775807
		for row: Dictionary in host.ui.quotes:
			if str(row.kind) != "item" or bool(row.get("selling", false)) or not is_instance_valid(row.get("amount")) or int(row.get("maximum",0)) < 2: continue
			var candidate_price: int = int(host.gameplay.economy.quote(str(row.id), 2, false))
			if candidate_price > 0 and candidate_price < lowest and not row.button.disabled: selected = row; lowest = candidate_price
		if not check(not selected.is_empty(), "responsive actual funded stock row exists " + str(layout.name)): continue
		for control: Control in [selected.name_label, selected.amount, selected.total_label, selected.button]: await _reachable64(control, "market " + str(control.name) + " " + str(layout.name))
		await dirty_number(selected.amount, "0"); await frames(4)
		check(selected.button.disabled and selected.status_label.get_theme_color("font_color").is_equal_approx(AuditTheme.WARN), "single invalid edit immediately marks blocked quote amber " + str(layout.name))
		await dirty_number(selected.amount, "2"); await frames(4)
		check(not selected.button.disabled and selected.status_label.get_theme_color("font_color").is_equal_approx(AuditTheme.MUTED), "single valid edit immediately restores available quote color " + str(layout.name))
		selected.row.grab_focus(); await native_key(KEY_ENTER); await frames(4)
		var full_name: Label = selected.row.find_child("BusinessDetailTitle", true, false) as Label
		check(is_instance_valid(full_name) and full_name.is_visible_in_tree() and full_name.text == selected.name_label.text and full_name.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "keyboard-opened transaction detail retains complete object name " + str(layout.name))
		await _reachable64(full_name, "complete transaction detail name " + str(layout.name))
		await native_key(KEY_ENTER); await frames(4)
		var price: int = int(host.gameplay.economy.quote(str(selected.id), 2, false))
		check(int(selected.total_label.get_meta("quote_amount", -1)) == price and selected.total_label.text == str(price), "compact market preserves complete actual total quote " + str(layout.name))
		var list: Node = host.ui.business_list_view
		var bar: HScrollBar = list.horizontal_scroll.get_h_scroll_bar()
		check(bar.max_value <= bar.page + 1.0 and not bar.is_visible_in_tree(), "critical market columns need no horizontal scroll " + str(layout.name))
		await inspect("completion-market-" + str(layout.name), "market")
		var item_id: String = str(selected.id)
		var before_credit: int = host.state.player().credit
		var before_units: int = _units64(item_id)
		if await actual_click(selected.button, "responsive real purchase " + str(layout.name)):
			await settle_writer("responsive actual purchase")
			check(host.state.player().credit == before_credit - price and _units64(item_id) == before_units + 2, "actual responsive purchase bills and delivers exact visible two units " + str(layout.name))
		host.ui.industry_tab = "manufacture"; await show_interaction("industry")
		var recipe: Dictionary = {}
		for row: Dictionary in host.ui.quotes:
			if str(row.kind) == "recipe" and is_instance_valid(row.get("amount")): recipe = row; break
		if check(not recipe.is_empty(), "responsive real industry quantity row exists " + str(layout.name)):
			for control: Control in [recipe.name_label, recipe.amount, recipe.total_label, recipe.button]: await _reachable64(control, "industry " + str(control.name) + " " + str(layout.name))
			bar = host.ui.business_list_view.horizontal_scroll.get_h_scroll_bar()
			check(bar.max_value <= bar.page + 1.0 and not bar.is_visible_in_tree(), "critical industry columns need no horizontal scroll " + str(layout.name))
		await inspect("completion-industry-" + str(layout.name), "industry")
		await largest_loadout_case64(str(layout.name))
	completion_cases.append("responsive_transactions")

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null; await frames(6)
	var result: Dictionary = {"result":"PASS" if failures.is_empty() else "FAIL", "checks":checks, "failures":failures.size(), "failure_labels":failures, "captures":captures, "native":DisplayServer.get_name() != "headless", "packed_runtime":not OS.has_feature("editor"), "directory":directory, "completion_cases":completion_cases, "layout_sizes":layout_sizes, "largest_loadout_observations":largest_loadout_observations, "observations":observations, "completion_observations":completion_observations, "findings":findings, "interaction_checks":interaction_checks, "fixtures":["fresh UUID private Main database", "existing funded/unlocked local inventory and actual paid owned cruiser fixture", "actual undock and dock with declared station-return position", "temporary seven-field DTO display fixtures restored before real transactions", "actual telemetry begin/finish retention boundary with zero-duration reports, not normal voyages", "temporary membership completion boundary restored before transactions", "catalog seventeen-slot production EquipmentBar display fixture in four sizes; no equipment DTO or save changes and no legal full-fit claim", "real pointer and native keyboard input; hidden callback probes"], "scope":"v64 UI completion, keyboard and responsive transaction evidence; not natural growth, active combat, balance or performance acceptance"}
	var file: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t") + "\n"); file.close()
	print("UI_COMPLETION_V64_RESULT ", result.result, " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
