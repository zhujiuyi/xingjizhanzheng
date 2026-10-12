extends "civilization_world_v24.gd"
## Real window entry, source navigation and readonly UI. Supplies/unlocks are explicit fixtures.
func _ready() -> void:
	get_tree().set_meta("xj_resource_intel_world_v26_diagnostic", true)
	get_tree().create_timer(180.0).timeout.connect(func(): check(false, "source native watchdog"); finish())
	run.call_deferred()

func run() -> void:
	directory = OS.get_environment("XJ_RESOURCE_INTEL_WORLD_V26_DIRECTORY").replace("\\", "/")
	if not check(DisplayServer.get_name() != "headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/resource-intel-world-v26/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "native sources require fresh scoped data"):
		await finish(); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900)
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db"); root.add_child(host)
	await frames(5)
	if not check(host.services_ready, "actual Main starts resource rules"): await finish(); return
	await host._command("new_world", "物资来源原生验收", 1, ""); await settle()
	if not check(host.state != null, "actual client creates source-intelligence world"): await finish(); return
	host.set_process(false); host.set_physics_process(false)
	for def: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.grant_unlock(def.unlock_id)
	await show("industry")
	var before: String = state_signature()
	var source_button: Button
	for quote: Dictionary in host.ui.quotes:
		if quote.action == "manufacture": source_button = host.ui.body.find_child("RecipeSources_" + str(quote.target), true, false); break
	if not await click(source_button, "open actual recipe material sources"): await finish(); return
	check(host.ui.page == "sources" and host.ui.body.find_child("SourceItem", true, false) != null, "recipe opens real source picker")
	check(state_signature() == before, "opening sources writes no assets progress or RNG")
	await capture("sources-from-recipe")
	var search: LineEdit = host.ui.body.find_child("SourceSearch", true, false)
	await click(search, "search real material name")
	search.select_all()
	var name: String = host.store.catalog.one("item_defs", "item_id", "ore_ferrosilicate").display_name
	for character: String in name:
		var input: InputEventKey = InputEventKey.new(); input.unicode = character.unicode_at(0); input.pressed = true; root.push_input(input, true)
	await key(KEY_ENTER)
	check(host.ui.source_item_id == "ore_ferrosilicate", "actual keyboard search selects ore by database name")
	check(state_signature() == before, "source search preserves all authoritative state")
	var node: Dictionary = {}
	await click(host.ui.body.find_child("SourceFilter_采矿", true, false), "filter real extraction sources")
	for row: Dictionary in host.gameplay.resource_intel.sources("ore_ferrosilicate"):
		if row.kind == "采矿" and int(row.hops) == 1 and row.route_open: node = host.store.catalog.one("resource_node_defs", "node_id", row.id); break
	if not check(not node.is_empty(), "authored ore point is reachable through one actual gate"): await finish(); return
	var key_name: String = "node:" + str(node.node_id)
	var suffix: String = key_name.validate_node_name()
	var go: Button = host.ui.body.find_child("SourceTravel_" + suffix, true, false)
	check(go != null and go.disabled, "docked ship sees explicit departure prerequisite")
	await capture("sources-ore")
	await click(host.ui.body.find_child("SourceMap_" + suffix, true, false), "locate actual source on star chart")
	check(host.ui.page == "map" and host.ui.resource_chart.selected_sector == node.sector_id, "source map resolves correct actual sector")
	check(host.ui.resource_chart.information.text.contains("定位：") and host.ui.resource_chart.information.text.contains("活动："), "actual star chart explains sector roles")
	check(state_signature() == before, "star-chart source inspection is readonly")
	await capture("sources-map")
	await click(host.ui.body.find_child("MapResourceSources", true, false), "reopen sources through star chart")
	check(host.ui.page == "sources", "map supports sources without another station menu entry")
	await click(host.ui.body.find_child("SourceFilter_采矿", true, false), "retain extraction navigation scope")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(3440, 1370)]:
		root.size = size; root.content_scale_factor = 2.0 if size.x == 1280 else 1.0
		await show("sources")
		var map_button: Button = host.ui.body.find_child("SourceMap_" + suffix, true, false)
		await reveal(map_button)
		check(Rect2(Vector2.ZERO, host.ui.root.size).encloses(map_button.get_global_rect()), "source operation reachable at " + str(size))
		var selector: OptionButton = host.ui.panel.find_child("PageSelector", true, false)
		check(str(selector.get_item_metadata(selector.selected)) == "map", "source detail retains star-chart navigation context " + str(size))
		await capture("sources-" + str(size.x))
	root.size = Vector2i(1440, 900); root.content_scale_factor = 1.0
	await host._command("undock", "", 1, ""); await settle()
	check(host.state.ship().status == T.ShipStatus.FLYING, "actual departure before navigation")
	await show("sources")
	go = host.ui.body.find_child("SourceTravel_" + suffix, true, false)
	var info: Dictionary = host.gameplay.resource_intel.guidance(key_name, "ore_ferrosilicate")
	if not await click(go, "navigate to real local ore source"): await finish(); return
	check(host.local_navigation.active() and host.local_navigation.target_id == info.waypoint_id and host.source_goal.key == key_name, "source request navigates to actual next-hop gate")
	var amount: int = host.state.find("resource_state", "node_id", node.node_id).remaining_units
	host.set_process(true); host.set_physics_process(true)
	var observation_boundary_seen: bool=false
	var deadline: int = Time.get_ticks_msec() + 35000
	while host.local_navigation.active() and Time.get_ticks_msec() < deadline:
		await frames(2)
		if host.local_navigation.warp_active() and not host.gameplay.situational.spatial_active:observation_boundary_seen=true
	check(not host.local_navigation.active() and host.ui.target_id == info.waypoint_id, "real navigation reaches the selected transit gate")
	host.get_viewport().warp_mouse(root.get_visible_rect().get_center())
	print("SOURCE_INPUT_CONTEXT ",JSON.stringify({"focus":root.has_focus(),"busy":host.busy,"page":host.ui.page,"keyboard_blocked":host.ui.keyboard_blocked(),"travel":host.travel.active(),"warp":host.local_navigation.warp_active()}))
	await key(KEY_F)
	deadline = Time.get_ticks_msec() + 50000
	var location: Dictionary = host.store.catalog.one("resource_node_locations", "node_id", node.node_id)
	while Time.get_ticks_msec() < deadline:
		if host.state.current_sector() == node.sector_id and host.gameplay.same_anchor_site(host.state.ship(), host.store.catalog.one("anchor_defs", "anchor_id", location.anchor_id)) and not host.local_navigation.active(): break
		await frames(2)
		if (host.local_navigation.warp_active() or host.travel.active()) and not host.gameplay.situational.spatial_active:observation_boundary_seen=true
	host.set_process(false); host.set_physics_process(false)
	check(host.state.current_sector() == node.sector_id, "actual F input crosses the planned star-system gate")
	check(host.gameplay.same_anchor_site(host.state.ship(), host.store.catalog.one("anchor_defs", "anchor_id", location.anchor_id)), "actual warp arrives in source's declared AU site")
	check(observation_boundary_seen,"actual strategic navigation suspends local resource observation")
	check(host.state.find("resource_state", "node_id", node.node_id).remaining_units == amount and host.gameplay.work.mining_target.is_empty(), "source arrival neither fabricates nor auto-mines goods")
	await capture("sources-arrived")
	await show("sources")
	var old_panel: Node = host.ui.body.find_child("SourceItem", true, false).get_parent().get_parent()
	var requests: Array = []
	var observer: Callable = func(action: String, target: String, quantity: int, extra: String): requests.append([action, target, quantity, extra])
	host.ui.requested.connect(observer)
	host.ui.show_page("map")
	old_panel.call("_request", "source_travel", key_name, "ore_ferrosilicate")
	check(requests.is_empty(), "obsolete source panel cannot send navigation in regenerated context")
	host.ui.requested.disconnect(observer)
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(5); await get_tree().create_timer(0.25).timeout
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory}
	print("RESOURCE_INTEL_WORLD_V26_FINAL_JSON ", JSON.stringify(summary))
	print("RESOURCE_INTEL_WORLD_V26_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
