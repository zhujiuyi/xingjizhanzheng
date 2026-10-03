extends SceneTree
## Actual Main + fresh SQLite map regression. The 120/300-node fixtures replace
## only a detached chart's presentation model; they never enter runtime/SQLite.
## Native checks use actual window focus/OS pointer and Viewport GUI events.
## Hardware-originated OS clicks are a separate manual acceptance boundary.
const Main = preload("res://runtime/main.gd")
const Chart = preload("res://runtime/ui/star_chart.gd")
const Catalog = preload("res://runtime/data/catalog.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var chart: Control
var directory: String
var database_path: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var selected_events: Array[String] = []
var last_click_context: Dictionary = {}
var synthetic_counts: Array[int] = []
var finishing: bool = false

func _initialize() -> void:
	create_timer(280.0).timeout.connect(func(): print("STAR_CHART_V13_RESULT FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for frame: int in range(count): await process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 6000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "real SQLite writer settles")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# Put the actual OS pointer outside graph/control text before capturing.
	# mouse_exited clears node intelligence, and queued native tooltip windows
	# get their normal release frames instead of covering a rendered label.
	await move_pointer(Vector2(4, 4))
	await frames(4)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "native rendered capture " + label)
	captures += 1

func reveal(control: Control) -> void:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer: node.ensure_control_visible(control)
		node = node.get_parent()
	await frames(4)

func move_pointer(position: Vector2) -> void:
	if DisplayServer.get_name() != "headless": root.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position; motion.global_position = position
	root.push_input(motion, true)
	await frames(2)

func mouse(position: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button; event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	event.position = position; event.global_position = position
	root.push_input(event, true)

func click(position: Vector2) -> void:
	await move_pointer(position)
	var hovered: Control = root.gui_get_hovered_control()
	var focused: Control = root.gui_get_focus_owner()
	last_click_context = {"position": str(position), "hover_path": str(hovered.get_path()) if hovered != null else "", "hover_class": hovered.get_class() if hovered != null else "", "hover_name": str(hovered.name) if hovered != null else "", "focus_path": str(focused.get_path()) if focused != null else "", "actual_pointer": str(root.get_mouse_position()), "display_server": DisplayServer.get_name(), "window_focus": root.has_focus()}
	mouse(position, true); mouse(position, false)
	await frames(4)

func drag(from: Vector2, to: Vector2) -> void:
	await move_pointer(from)
	mouse(from, true)
	for index: int in range(1, 5):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, float(index) / 4.0)
		motion.global_position = motion.position
		motion.relative = (to - from) / 4.0
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame
	mouse(to, false)
	await frames(4)

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		root.push_input(event, true)
	await frames(3)

func descendants(node: Node, type: String = "Control") -> int:
	var result: int = 1 if node.is_class(type) else 0
	for child: Node in node.get_children(): result += descendants(child, type)
	return result

func control_tree(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if node is Control or node is Window:
		result.append({"path": str(node.get_path()), "class": node.get_class(), "id": node.get_instance_id(), "window": node.get_window().get_instance_id(), "owner": str(node.owner.get_path()) if node.owner != null else ""})
	for child: Node in node.get_children(): result.append_array(control_tree(child))
	return result

func engine_tooltip(node: Node) -> bool:
	# Native evidence identified this exact Godot-generated PopupPanel/Label
	# pair. Regular PopupMenu, named PopupPanel and scripted UI remain counted.
	if not node is PopupPanel or node.get_script() != null or not str(node.name).begins_with("@PopupPanel@"):
		return false
	var children: Array[Node] = node.get_children()
	return children.size() == 1 and children[0] is Label and children[0].get_script() == null and str(children[0].name).begins_with("@Label@") and children[0].get_window() == node

func owned_control_ids(node: Node) -> Array[int]:
	var result: Array[int] = []
	if engine_tooltip(node): return result
	if node is Control: result.append(node.get_instance_id())
	for child: Node in node.get_children(): result.append_array(owned_control_ids(child))
	result.sort()
	return result

func page_clip_rect() -> Rect2:
	var scroll: ScrollContainer = host.ui.page_scroll
	var clip: Rect2 = scroll.get_global_rect()
	if scroll.has_theme_stylebox("panel"):
		var style: StyleBox = scroll.get_theme_stylebox("panel")
		var margins: Vector2 = Vector2(style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP))
		clip.position += margins
		clip.size -= margins + Vector2(style.get_content_margin(SIDE_RIGHT), style.get_content_margin(SIDE_BOTTOM))
	var vertical: VScrollBar = scroll.get_v_scroll_bar()
	var horizontal: HScrollBar = scroll.get_h_scroll_bar()
	if vertical.is_visible_in_tree(): clip.size.x -= vertical.size.x
	if horizontal.is_visible_in_tree(): clip.size.y -= horizontal.size.y
	return clip.intersection(Rect2(Vector2.ZERO, host.ui.root.size))

func snapshots() -> int:
	return int(host.store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)

func chart_now() -> bool:
	chart = host.ui.resource_chart
	return check(is_instance_valid(chart) and chart.name == "StarChart", "actual Main map embeds production chart")

func show_map() -> void:
	host.ui.show_page("map")
	await frames(5); host.ui.tick(0.3); await frames(3)
	if not chart_now(): return
	chart.connect("sector_selected", func(id: String): selected_events.append(id))

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/star-chart-v13/%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	database_path = directory.path_join("progress.db")
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	host = Main.new(); host.progress_database_path = database_path
	root.add_child(host)
	host.set_process(false); host.set_physics_process(false)
	await frames()
	if not check(host.services_ready, "Main opens formal catalog and isolated fresh SQLite"): await finish(); return
	await host._command("new_world", "星图重塑独立验收", 1, "")
	await wait_writer()
	if not check(host.state != null, "new world comes from real Main and SQLite"): await finish(); return
	await host._command("undock", "", 1, "")
	await wait_writer()
	host._sync_presentation_stage()
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await process_frame
		check(root.has_focus(), "native map has actual OS window focus")
	await show_map()
	if not is_instance_valid(chart): await finish(); return
	await formal_model_checks()
	await selection_and_details_checks()
	await filter_checks()
	await input_checks()
	await route_checks()
	await live_gate_mass_checks()
	await layout_checks()
	await lifecycle_and_travel_checks()
	await synthetic_checks(120)
	await synthetic_checks(300)
	await finish()

func formal_model_checks() -> void:
	var sectors: Dictionary = chart.get("sectors")
	check(sectors.size() == host.store.catalog.rows("sector_defs").size(), "graph includes every actual frozen sector exactly once")
	var identities: Dictionary = {}
	for endpoint: Dictionary in host.store.catalog.rows("gate_endpoint_defs"): identities[str(endpoint.connection_id)] = true
	var links: Array = chart.get("links")
	check(links.size() == identities.size(), "graph has one visual edge per actual wormhole connection")
	var endpoints_valid: bool = true
	for link: Dictionary in links:
		var found: bool = false
		for endpoint: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
			if (str(endpoint.origin_sector_id) == str(link.origin) and str(endpoint.target_sector_id) == str(link.destination)) or (str(endpoint.target_sector_id) == str(link.origin) and str(endpoint.origin_sector_id) == str(link.destination)): found = true
		endpoints_valid = endpoints_valid and found and sectors.has(str(link.origin)) and sectors.has(str(link.destination))
	check(endpoints_valid, "every drawn edge is grounded in a real endpoint pair")
	check(str(chart.get("selected_sector")) == host.state.current_sector(), "map initially selects current sector")
	var diagram: Control = chart.get("diagram")
	await reveal(diagram)
	await frames()
	check((diagram.get("world_points") as Dictionary).size() == sectors.size(), "topology assigns a stable world-space point to each actual sector")
	var x_values: Dictionary = {}; var y_values: Dictionary = {}
	for point: Vector2 in (diagram.get("world_points") as Dictionary).values():
		x_values[roundi(point.x)] = true; y_values[roundi(point.y)] = true
	check(x_values.size() > 3 and y_values.size() > 3, "actual star chart spreads nodes in two dimensions beyond three risk columns")
	check(descendants(diagram) == 1 and descendants(chart) < 70, "drawn nodes avoid one-control-per-sector and detail-card proliferation")

func selected_details(id: String, label: String) -> void:
	check(str(chart.get("selected_sector")) == id, "graph selection identity " + label)
	var selected: Dictionary = (chart.get("sectors") as Dictionary).get(id, {})
	var information: Label = chart.get("information")
	check(information.text.contains(str(selected.get("title", ""))) and information.text.contains("势力：") and information.text.contains("资源："), "single information panel describes selected sector " + label)
	var actual_ids: Dictionary = {}
	for resource: Dictionary in host.store.catalog.rows("resource_node_defs"):
		if str(resource.sector_id) == id: actual_ids[str(resource.node_id)] = true
	var readouts_match: bool = host.ui.map_resource_readouts.size() == actual_ids.size()
	for row: Dictionary in host.ui.map_resource_readouts:
		readouts_match = readouts_match and str(row.sector_id) == id and actual_ids.has(str(row.node_id)) and is_instance_valid(row.label)
	check(readouts_match, "lower resource details contain only selected sector without unrelated systems " + label)
	var details: Node = host.ui.body.find_child("SelectedSectorDetails", true, false)
	check(details != null and str(details.get_meta("selected_sector", "")) == id, "one selected detail container tracks chart selection " + label)

func selection_and_details_checks() -> void:
	var current: String = host.state.current_sector()
	var before_ship: Transform3D = host.world.flight.global_transform
	var before_target: String = host.ui.target_id
	var before_snapshots: int = snapshots()
	var diagram: Control = chart.get("diagram")
	var foreign: String = ""
	for id: String in chart.get("sectors"):
		if id != current: foreign = id; break
	selected_details(current, "initial current")
	await reveal(diagram)
	diagram.call("center_on", foreign); await frames()
	var point: Vector2 = (diagram.get("points") as Dictionary).get(foreign, Vector2(-1000, -1000))
	var count: int = selected_events.size()
	await click(diagram.get_global_rect().position + point)
	selected_details(foreign, "actual canvas click")
	check(selected_events.size() == count + 1 and selected_events[-1] == foreign, "one viewport click selects exactly one sector")
	check(host.state.current_sector() == current and host.world.flight.global_transform.is_equal_approx(before_ship) and host.ui.target_id == before_target and snapshots() == before_snapshots, "map selection cannot travel, select a gameplay target, move ship or save")
	var labels: Dictionary = diagram.get("label_rects")
	if check(labels.has(foreign), "selected node exposes a visible readable name hit area"):
		var name_rect: Rect2 = labels[foreign]
		await click(diagram.get_global_rect().position + Vector2(name_rect.end.x - 4.0, name_rect.get_center().y))
		check(str(chart.get("selected_sector")) == foreign, "clicking outside node circle on its drawn name retains the named sector")
	chart.call("select_sector", "unknown-map-test-id")
	check(str(chart.get("selected_sector")) == foreign, "invalid sector cannot leave a dangling selected-detail identity")
	chart.call("select_sector", current); await frames()
	selected_details(current, "return to current")

func filter_checks() -> void:
	var before_snapshots: int = snapshots()
	var sectors: Dictionary = chart.get("sectors")
	var foreign: String = ""
	for id: String in sectors:
		if id != host.state.current_sector(): foreign = id; break
	var edges_before: String = JSON.stringify(chart.get("links"))
	var search: LineEdit = chart.get("search_box")
	search.text = str(sectors[foreign].title); search.text_changed.emit(search.text)
	await frames(3)
	var matched: Array[String] = []
	for id: String in sectors:
		if bool(chart.call("matches_filter", id)): matched.append(id)
	var navigator: OptionButton = chart.get("navigator")
	check(matched == [foreign] and not navigator.disabled and navigator.item_count == 1 and str(navigator.get_item_metadata(0)) == foreign, "actual catalog search and navigator identify exactly the matching sector")
	search.text_submitted.emit(search.text); await frames(4)
	selected_details(foreign, "search submission")
	var route_before: Dictionary = chart.call("route_status", foreign)
	var risk: OptionButton = chart.get("risk_filter")
	var different_risk: int = 2 if str(sectors[foreign].risk_zone_id) == "risk_high" else 1
	risk.select(different_risk); risk.item_selected.emit(different_risk); await frames(3)
	check(not bool(chart.call("matches_filter", foreign)) and str(chart.get("selected_sector")) == foreign and navigator.disabled, "filter can hide a search result while preserving the explicitly selected sector")
	selected_details(foreign, "selection outside active risk filter")
	var route_after: Dictionary = chart.call("route_status", foreign)
	check(JSON.stringify(route_before) == JSON.stringify(route_after) and JSON.stringify(chart.get("links")) == edges_before, "search/risk display filters cannot unlock a route or fabricate a shortcut")
	search.text = "unknown-star-chart-test"; search.text_changed.emit(search.text); await frames(3)
	check(navigator.disabled and str(chart.get("selected_sector")) == foreign, "zero matching sectors keep selected details and disable result navigation")
	search.text = ""; search.text_changed.emit("")
	risk.select(0); risk.item_selected.emit(0)
	chart.call("select_sector", host.state.current_sector()); await frames()
	check(navigator.item_count == sectors.size() and snapshots() == before_snapshots, "clearing actual filters restores all choices without any SQLite write")

func input_checks() -> void:
	var diagram: Control = chart.get("diagram")
	await reveal(diagram)
	diagram.call("fit_all"); await frames()
	var center: Vector2 = diagram.get_global_rect().get_center()
	await move_pointer(center)
	var hover: Control = root.gui_get_hovered_control()
	check(hover == diagram or (hover != null and diagram.is_ancestor_of(hover)), "real viewport hit test targets graph canvas")
	if DisplayServer.get_name() != "headless":
		check(root.has_focus() and diagram.get_global_rect().has_point(diagram.get_global_mouse_position()), "native graph uses actual OS cursor and focus")
	var zoom_before: float = float(diagram.get("zoom"))
	var scroll_before: int = host.ui.page_scroll.scroll_vertical
	var camera_mode: int = int(host.camera.mode)
	var point_before: Vector2 = (diagram.get("points") as Dictionary).get(str(chart.get("selected_sector")), Vector2.ZERO)
	mouse(center, true, MOUSE_BUTTON_WHEEL_UP)
	mouse(center, false, MOUSE_BUTTON_WHEEL_UP)
	await frames(3)
	check(float(diagram.get("zoom")) > zoom_before, "wheel over canvas zooms the star chart")
	check(host.ui.page_scroll.scroll_vertical == scroll_before and int(host.camera.mode) == camera_mode, "canvas wheel is consumed without outer-page scroll or flight camera changes")
	diagram.call("center_on", str(chart.get("selected_sector"))); await frames()
	center = diagram.get_global_rect().position + (diagram.get("points") as Dictionary)[str(chart.get("selected_sector"))]
	var pan_before: Vector2 = diagram.get("pan")
	var selected_before: String = str(chart.get("selected_sector"))
	var selection_count: int = selected_events.size()
	await drag(center, center + Vector2(66, 30))
	check(not (diagram.get("pan") as Vector2).is_equal_approx(pan_before), "left drag pans actual graph")
	check(str(chart.get("selected_sector")) == selected_before and selected_events.size() == selection_count, "drag release does not masquerade as a sector click")
	check(not host.observing and not host.pointer_drag_pressed and not host.fire_held and host.ui.keyboard_blocked() and not host._keyboard_control_allowed(), "graph consumes dragging and blocks flight observation/fire controls")
	diagram.grab_focus(); await frames(2)
	pan_before = diagram.get("pan")
	await key(KEY_RIGHT)
	check(not (diagram.get("pan") as Vector2).is_equal_approx(pan_before), "focused graph supports keyboard directional pan")
	zoom_before = float(diagram.get("zoom"))
	await key(KEY_MINUS)
	check(float(diagram.get("zoom")) < zoom_before, "focused graph supports keyboard zoom out")
	var search: LineEdit = chart.get("search_box")
	search.grab_focus(); await frames(2)
	pan_before = diagram.get("pan")
	await key(KEY_LEFT)
	check((diagram.get("pan") as Vector2).is_equal_approx(pan_before) and root.gui_get_focus_owner() == search, "search editing keys do not pan graph or steal text focus")
	var event := InputEventAction.new(); event.action = "fire"; event.pressed = true
	host._unhandled_input(event)
	check(not host.fire_held and int(host.camera.mode) == camera_mode, "Main's production guards prevent flight fire while map/search is open")
	search.text = ""; search.text_changed.emit("")
	diagram.call("fit_all"); await frames()
	check((diagram.get("points") as Dictionary).has(str(chart.get("selected_sector"))) and point_before.is_finite(), "fit action restores a finite selected node projection after pan and zoom")

func route_checks() -> void:
	for destination: String in chart.get("sectors"):
		var route: Array = chart.call("_route", host.state.current_sector(), destination)
		var directed: bool = true
		for index: int in range(1, route.size()):
			var found: bool = false
			for endpoint: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
				if str(endpoint.origin_sector_id) == str(route[index - 1]) and str(endpoint.target_sector_id) == str(route[index]): found = true
			directed = directed and found
		check(directed and (route.is_empty() or (str(route.front()) == host.state.current_sector() and str(route.back()) == destination)), "suggested route uses actual directed endpoints " + destination)
	var locked: Dictionary = {}
	for endpoint: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
		if str(endpoint.origin_sector_id) == host.state.current_sector() and host.state.find("unlock_state", "unlock_id", str(endpoint.required_unlock_id)) == null: locked = endpoint; break
	if check(not locked.is_empty(), "fresh world supplies an actual locked-route fixture"):
		chart.call("select_sector", str(locked.target_sector_id)); await frames()
		var information: Label = chart.get("information")
		check(information.text.contains("未解锁") or information.text.contains("权限") or information.text.contains("需解锁"), "selected locked route names its actual prerequisite instead of claiming passage")
		var locked_status: Dictionary = chart.call("route_status", str(locked.target_sector_id))
		check(not bool(locked_status.get("open", true)) and not (locked_status.get("blocked", []) as Array).is_empty(), "real route model exposes blocked permission independently of risk color")
		# Explicit isolated prerequisite for closed/lifetime/mass-state checks.
		host.gameplay.grant_unlock(str(locked.required_unlock_id))
		var gate: RefCounted = host.state.find("gate_state", "connection_id", str(locked.connection_id))
		if check(gate != null, "actual locked connection has persistent gate state"):
			var enabled: bool = bool(gate.get("enabled"))
			gate.set("enabled", false)
			chart.call("select_sector", str(locked.target_sector_id)); await frames()
			check(information.text.contains("关闭") or information.text.contains("不可通行"), "disabled gate is visible as a passage condition")
			gate.set("enabled", enabled)
			var has_lifetime: bool = bool(gate.get("has_lifetime_remaining_s"))
			var lifetime: float = float(gate.get("lifetime_remaining_s"))
			gate.set("has_lifetime_remaining_s", true); gate.set("lifetime_remaining_s", 0.0)
			chart.call("select_sector", str(locked.target_sector_id)); await frames()
			check(information.text.contains("寿命") and not bool((chart.call("route_status", str(locked.target_sector_id)) as Dictionary).get("open", true)), "expired actual gate cannot appear as an open route")
			gate.set("has_lifetime_remaining_s", has_lifetime); gate.set("lifetime_remaining_s", lifetime)
			var has_budget: bool = bool(gate.get("has_remaining_mass_budget_kg"))
			var budget: float = float(gate.get("remaining_mass_budget_kg"))
			gate.set("has_remaining_mass_budget_kg", true); gate.set("remaining_mass_budget_kg", 0.0)
			chart.call("select_sector", str(locked.target_sector_id)); await frames()
			check(information.text.contains("质量") and not bool((chart.call("route_status", str(locked.target_sector_id)) as Dictionary).get("open", true)), "exhausted actual gate mass budget blocks the loaded hull's route")
			gate.set("has_remaining_mass_budget_kg", has_budget); gate.set("remaining_mass_budget_kg", budget)
			host.state.remove("gate_state", gate)
			chart.call("select_sector", str(locked.target_sector_id)); await frames()
			check(information.text.contains("状态不可用"), "missing persistent gate state cannot be advertised as a valid passage")
			host.state.add("gate_state", gate)
	# A detached read-only catalog UI fixture removes the reverse endpoint.
	# This discriminates directed routing even when every formal gate is paired.
	var directed_catalog: RefCounted = Catalog.new()
	directed_catalog.set("_cache", host.store.catalog.get("_cache").duplicate(true))
	var one_way: Array[Dictionary] = []
	for endpoint: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
		if str(endpoint.origin_sector_id) == host.state.current_sector(): one_way.append(endpoint); break
	if not one_way.is_empty():
		(directed_catalog.get("_cache") as Dictionary)["gate_endpoint_defs"] = one_way
		var directed_chart: Control = Chart.new()
		directed_chart.visible = false
		root.add_child(directed_chart)
		directed_chart.call("configure", directed_catalog, host.state)
		var forward: Array = directed_chart.call("_route", str(one_way[0].origin_sector_id), str(one_way[0].target_sector_id))
		var reverse: Array = directed_chart.call("_route", str(one_way[0].target_sector_id), str(one_way[0].origin_sector_id))
		check(forward.size() == 2 and reverse.is_empty(), "detached one-way UI fixture forbids fabricated reverse travel")
		directed_chart.queue_free(); await frames()
	chart.call("select_sector", host.state.current_sector()); await frames()

func connection_status(connection_id: String) -> String:
	for link: Dictionary in chart.get("links"):
		if str(link.get("connection_id", "")) == connection_id: return str(link.get("status", ""))
	return "missing"

func resource_label_ids() -> Array[int]:
	var ids: Array[int] = []
	for readout: Dictionary in host.ui.map_resource_readouts:
		if is_instance_valid(readout.label): ids.append(readout.label.get_instance_id())
	return ids

func blocked_route_click(button: Button, cause: String) -> void:
	var previous_target: String = host.ui.target_id
	var previous_page: String = host.ui.page
	var previous_snapshots: int = snapshots()
	var previous_pose: Transform3D = host.world.flight.global_transform
	# Directly emitting a disabled Button's signal bypasses the widget guard;
	# the production callback still has to calculate a current legal route.
	button.pressed.emit()
	await frames(3)
	check(host.ui.target_id == previous_target and host.ui.page == previous_page and snapshots() == previous_snapshots and host.world.flight.global_transform.is_equal_approx(previous_pose), "disabled route signal cannot bypass fresh legality or change target/page/save " + cause)

func live_gate_mass_checks() -> void:
	var endpoint: Dictionary = {}
	for row: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
		if str(row.origin_sector_id) == host.state.current_sector() and host.state.find("unlock_state", "unlock_id", str(row.required_unlock_id)) != null:
			endpoint = row; break
	if not check(not endpoint.is_empty(), "live map fixture uses an actual currently unlocked outgoing endpoint"): return
	var gate: RefCounted = host.state.find("gate_state", "connection_id", str(endpoint.connection_id))
	if not check(gate != null, "live map fixture has actual persistent gate state"): return
	var original: Dictionary = {"enabled": gate.get("enabled"), "has_lifetime_remaining_s": gate.get("has_lifetime_remaining_s"), "lifetime_remaining_s": gate.get("lifetime_remaining_s"), "has_remaining_mass_budget_kg": gate.get("has_remaining_mass_budget_kg"), "remaining_mass_budget_kg": gate.get("remaining_mass_budget_kg")}
	var old_selection: String = str(chart.get("selected_sector"))
	gate.set("enabled", true); gate.set("has_lifetime_remaining_s", false); gate.set("has_remaining_mass_budget_kg", false)
	chart.call("select_sector", str(endpoint.target_sector_id))
	host.ui.tick(0.3); await frames(3)
	var route_button: Button = host.ui.map_route_button
	if not check(is_instance_valid(route_button) and not route_button.disabled and str(route_button.get_meta("map_route_destination", "")) == str(endpoint.target_sector_id), "foreign selected details expose one enabled destination-bound route action"):
		for field: String in original: gate.set(field, original[field])
		chart.call("select_sector", old_selection)
		return
	var route_button_id: int = route_button.get_instance_id()
	var detail_control_ids: Array[int] = owned_control_ids(host.ui.map_details)
	var diagram: Control = chart.get("diagram")
	var chart_id: int = chart.get_instance_id()
	var diagram_id: int = diagram.get_instance_id()
	var information: Label = chart.get("information")
	var information_id: int = information.get_instance_id()
	var chart_resource_id: int = (chart.get("resource_information") as Label).get_instance_id()
	var label_ids: Array[int] = resource_label_ids()
	var points: String = JSON.stringify(diagram.get("world_points"))
	var control_ids: Array[int] = owned_control_ids(chart)
	var controls: int = control_ids.size()
	var controls_before: Array[Dictionary] = control_tree(chart)
	var selection_count: int = selected_events.size()
	var snapshots_before: int = snapshots()
	var schema_before: String = JSON.stringify(host.store._records("SELECT type,name,sql FROM sqlite_schema ORDER BY type,name"))
	var frozen_hash: String = host.store.catalog.content_hash
	var stable_view: Callable = func() -> bool:
		var actual_control_ids: Array[int] = owned_control_ids(chart)
		var predicates: Dictionary = {"chart_binding": host.ui.resource_chart == chart, "chart_instance": chart.get_instance_id() == chart_id, "diagram_instance": (chart.get("diagram") as Control).get_instance_id() == diagram_id, "information_instance": information.get_instance_id() == information_id, "chart_resource_instance": (chart.get("resource_information") as Label).get_instance_id() == chart_resource_id, "resource_labels": resource_label_ids() == label_ids, "world_points": JSON.stringify(diagram.get("world_points")) == points, "owned_control_count": actual_control_ids.size() == controls, "owned_control_ids": actual_control_ids == control_ids, "detail_control_ids": owned_control_ids(host.ui.map_details) == detail_control_ids, "route_button_instance": host.ui.map_route_button == route_button and route_button.get_instance_id() == route_button_id, "selected_sector": str(chart.get("selected_sector")) == str(endpoint.target_sector_id), "selection_events": selected_events.size() == selection_count}
		var stable: bool = true
		for predicate: bool in predicates.values(): stable = stable and predicate
		if not stable:
			print("STAR_CHART_V13_ROUTE_CONTROL_DIAGNOSTIC " + JSON.stringify({"expected_route_button": route_button_id, "actual_route_button": route_button.get_instance_id(), "expected_detail_control_ids": detail_control_ids, "actual_detail_control_ids": owned_control_ids(host.ui.map_details), "actual_detail_tree": control_tree(host.ui.map_details)}))
			print("STAR_CHART_V13_STABILITY_DIAGNOSTIC " + JSON.stringify({"predicates": predicates, "expected": {"chart": chart_id, "diagram": diagram_id, "information": information_id, "chart_resource": chart_resource_id, "resource_labels": label_ids, "world_points": JSON.parse_string(points), "controls": controls, "control_ids": control_ids, "selection_events": selection_count, "selected_sector": str(endpoint.target_sector_id), "control_tree": controls_before}, "actual": {"chart": chart.get_instance_id(), "diagram": (chart.get("diagram") as Control).get_instance_id(), "information": information.get_instance_id(), "chart_resource": (chart.get("resource_information") as Label).get_instance_id(), "resource_labels": resource_label_ids(), "world_points": diagram.get("world_points"), "controls": actual_control_ids.size(), "control_ids": actual_control_ids, "all_controls_including_tooltips": descendants(chart), "selection_events": selected_events.size(), "selected_sector": str(chart.get("selected_sector")), "control_tree": control_tree(chart), "focus": str(root.gui_get_focus_owner()), "hover": str(root.gui_get_hovered_control())}}))
		return stable
	check(connection_status(str(endpoint.connection_id)) == "open" and bool((chart.call("route_status", str(endpoint.target_sector_id)) as Dictionary).get("open", false)), "live map starts from an open actual outgoing route")
	# Changes below are isolated read-only UI preconditions. The production UI
	# cadence must notice them without another select_sector or refresh_page.
	gate.set("enabled", false)
	host.ui.tick(0.3); await frames(3)
	check(connection_status(str(endpoint.connection_id)) == "closed" and information.text.contains("关闭") and not bool((chart.call("route_status", str(endpoint.target_sector_id)) as Dictionary).get("open", true)), "UI tick updates drawn edge and selected refusal when an actual gate closes")
	check(route_button.disabled and route_button.tooltip_text.contains("关闭"), "same foreign route action disables and explains the closed gate")
	await blocked_route_click(route_button, "closed gate")
	check(bool(stable_view.call()), "closing gate preserves layout, chart/detail/resource label instances and selection")
	gate.set("enabled", true); gate.set("has_lifetime_remaining_s", true); gate.set("lifetime_remaining_s", 0.0)
	host.ui.tick(0.3); await frames(3)
	check(connection_status(str(endpoint.connection_id)) == "closed" and information.text.contains("寿命") and not bool((chart.call("route_status", str(endpoint.target_sector_id)) as Dictionary).get("open", true)), "UI tick updates expiry refusal without reselecting the sector")
	check(route_button.disabled and route_button.tooltip_text.contains("寿命"), "same foreign route action disables and explains gate expiry")
	await blocked_route_click(route_button, "expired gate")
	check(bool(stable_view.call()), "expiring gate preserves layout and every existing selected-detail control")
	gate.set("has_lifetime_remaining_s", false); gate.set("has_remaining_mass_budget_kg", true)
	var mass_before: float = float(host.gameplay.metrics(host.state.ship()).total_mass_kg)
	gate.set("remaining_mass_budget_kg", maxf(0.0, mass_before - 0.5))
	host.ui.tick(0.3); await frames(3)
	check(connection_status(str(endpoint.connection_id)) != "open" and information.text.contains("质量") and not bool((chart.call("route_status", str(endpoint.target_sector_id)) as Dictionary).get("open", true)), "UI tick updates insufficient remaining mass quota using actual loaded hull mass")
	check(route_button.disabled and route_button.tooltip_text.contains("质量"), "same foreign route action disables and explains exhausted mass quota")
	await blocked_route_click(route_button, "insufficient quota")
	check(bool(stable_view.call()), "quota change preserves node layout and selection instead of rebuilding the page")
	var inventory: RefCounted = host.gameplay.get("inventory")
	var cargo: String = str(inventory.call("hold", host.state.ship(), T.ContainerKind.CARGO))
	var material: Dictionary = {}
	for definition: Dictionary in host.store.catalog.rows("item_defs"):
		if bool(definition.get("stackable", false)) and float(definition.get("unit_mass_kg", 0.0)) > 0.5 and int(inventory.call("room", cargo, str(definition.item_id), 1)) >= 1:
			material = definition; break
	if check(not cargo.is_empty() and not material.is_empty(), "live mass test finds one ordinary catalog unit within real cargo capacity"):
		var quantity_before: Dictionary = {}
		for stack: RefCounted in host.state.rows("inventory_stack_state"): quantity_before[str(stack.stack_id)] = int(stack.quantity)
		# A threshold between unloaded and one-unit-loaded mass discriminates
		# stale configure-time mass from the real telemetry passed by UI.tick.
		gate.set("remaining_mass_budget_kg", mass_before + float(material.unit_mass_kg) * 0.5)
		host.ui.tick(0.3); await frames(3)
		check(connection_status(str(endpoint.connection_id)) == "open" and not information.text.contains("质量额度不足"), "current mass below the isolated quota threshold displays an open edge")
		check(not route_button.disabled, "restored sufficient quota enables the existing destination route action")
		var granted: Array = inventory.call("grant", cargo, str(material.item_id), 1)
		var mass_after: float = float(host.gameplay.metrics(host.state.ship()).total_mass_kg)
		check(granted.size() == 1 and is_equal_approx(mass_after - mass_before, float(material.unit_mass_kg)), "production inventory grant changes actual hull metrics by one catalog unit")
		host.ui.tick(0.3); await frames(3)
		check(connection_status(str(endpoint.connection_id)) != "open" and information.text.contains("质量") and not bool((chart.call("route_status", str(endpoint.target_sector_id)) as Dictionary).get("open", true)), "UI tick replaces cached mass after cargo gain and updates edge plus selected blocking cause")
		check(route_button.disabled and route_button.tooltip_text.contains("质量"), "actual cargo gain disables the same route button with current mass refusal")
		await blocked_route_click(route_button, "cargo mass gain")
		check(bool(stable_view.call()), "cargo mass refresh preserves layout, selected identity and existing resource/detail labels")
		for stack: RefCounted in host.state.rows("inventory_stack_state").duplicate():
			if quantity_before.has(str(stack.stack_id)): stack.quantity = int(quantity_before[str(stack.stack_id)])
			elif granted.has(str(stack.stack_id)): host.state.remove("inventory_stack_state", stack)
		host.ui.tick(0.3); await frames(3)
		check(is_equal_approx(float(host.gameplay.metrics(host.state.ship()).total_mass_kg), mass_before) and connection_status(str(endpoint.connection_id)) == "open", "restoring the isolated cargo fixture reopens the same edge on the next UI tick")
		check(not route_button.disabled, "restoring actual cargo mass re-enables the original route button")
		check(bool(stable_view.call()), "restored mass still uses unchanged chart geometry and controls")
	for field: String in original: gate.set(field, original[field])
	host.ui.tick(0.3); await frames(3)
	check(snapshots() == snapshots_before and JSON.stringify(host.store._records("SELECT type,name,sql FROM sqlite_schema ORDER BY type,name")) == schema_before and host.store.catalog.content_hash == frozen_hash, "live route/gate/mass UI updates write no save snapshot, schema or frozen definitions")
	check(bool(stable_view.call()), "all restored live-gate preconditions preserve the original presentation objects")
	var fresh_path: Array = host.gameplay.missions._route(host.state.current_sector(), str(endpoint.target_sector_id), true)
	if check(not route_button.disabled and not fresh_path.is_empty(), "restored foreign destination has a current legal path for the final real GUI action"):
		var emitted: Dictionary = {"count": 0}
		var observer: Callable = func(): emitted["count"] = int(emitted["count"]) + 1
		route_button.pressed.connect(observer)
		await reveal(route_button)
		check(page_clip_rect().grow(0.5).encloses(route_button.get_global_rect()), "final foreign route action is visible inside the real page clip")
		var button_rect_before: Rect2 = route_button.get_global_rect()
		var click_page_before: String = host.ui.page
		var route_destination_before: String = host.ui.map_route_destination
		await click(route_button.get_global_rect().get_center())
		var predicates: Dictionary = {"one_signal": int(emitted["count"]) == 1, "flight_page": host.ui.page.is_empty(), "fresh_endpoint_target": host.ui.target_id == str(fresh_path[0].endpoint_id), "no_save": snapshots() == snapshots_before, "same_sector": host.state.current_sector() == str(endpoint.origin_sector_id)}
		var routed: bool = true
		for predicate: bool in predicates.values(): routed = routed and predicate
		if not check(routed, "one legal GUI click chooses the freshly calculated first actual door and returns to flight without travel/save"):
			print("STAR_CHART_V13_ROUTE_CLICK_DIAGNOSTIC " + JSON.stringify({"predicates": predicates, "emitted": int(emitted["count"]), "page_before": click_page_before, "page_after": host.ui.page, "target_id": host.ui.target_id, "expected_endpoint": str(fresh_path[0].endpoint_id), "snapshots_expected": snapshots_before, "snapshots_actual": snapshots(), "sector_expected": str(endpoint.origin_sector_id), "sector_actual": host.state.current_sector(), "route_destination_before": route_destination_before, "route_destination_after": host.ui.map_route_destination, "button_rect_before": str(button_rect_before), "button_rect_after": str(route_button.get_global_rect()), "button_disabled": route_button.disabled, "button_tooltip": route_button.tooltip_text, "clip": str(page_clip_rect()), "hover_at_click": last_click_context, "hover_after": str(root.gui_get_hovered_control()), "has_docked_station": host.state.player().has_docked_station_id, "door_present": host.world.targets.has(str(fresh_path[0].endpoint_id)), "door_available": bool(host.ui.call("_map_target_available", str(fresh_path[0].endpoint_id)))}))
		if is_instance_valid(route_button) and route_button.pressed.is_connected(observer): route_button.pressed.disconnect(observer)
		await show_map()
	chart.call("select_sector", old_selection); await frames()

func layout_checks() -> void:
	for window_size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = window_size; root.content_scale_size = Vector2i(Vector2(window_size) / scale)
			await frames(5)
			var diagram: Control = chart.get("diagram")
			diagram.call("fit_all"); await reveal(diagram); await frames()
			var label: String = "%dx%d-%d" % [window_size.x, window_size.y, int(scale * 100)]
			var viewport: Rect2 = Rect2(Vector2.ZERO, host.ui.root.size)
			var clip: Rect2 = page_clip_rect()
			var diagram_fits: bool = diagram.size.x > 250 and diagram.size.y >= 120 and clip.grow(0.5).encloses(diagram.get_global_rect())
			check(diagram_fits, "entire graph canvas fits actual page scroll clip after ordinary reveal " + label)
			if not diagram_fits: print("STAR_CHART_V13_CLIP_DIAGNOSTIC " + JSON.stringify({"layout": label, "target": "diagram", "rect": str(diagram.get_global_rect()), "clip": str(clip), "viewport": str(viewport), "scroll": host.ui.page_scroll.scroll_vertical}))
			check(diagram.get_global_rect().size.x <= clip.size.x + 0.5, "map canvas width fits actual scroll viewport excluding scrollbar " + label)
			var search: LineEdit = chart.get("search_box")
			var risk: OptionButton = chart.get("risk_filter")
			await reveal(search)
			check(page_clip_rect().grow(0.5).encloses(search.get_global_rect()) and search.size.x >= 100 and search.size.y >= 28, "search fits actual page scroll clip at UI scale " + label)
			await reveal(risk)
			check(page_clip_rect().grow(0.5).encloses(risk.get_global_rect()) and risk.size.y >= 28, "risk control fits actual page scroll clip at UI scale " + label)
			await reveal(diagram)
			await capture("map-" + label)
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	await frames(4)

func lifecycle_and_travel_checks() -> void:
	var old_chart_id: int = chart.get_instance_id()
	var current: String = host.state.current_sector()
	var remembered: String = ""
	for id: String in chart.get("sectors"):
		if id != current: remembered = id; break
	chart.call("select_sector", remembered)
	var search: LineEdit = chart.get("search_box")
	search.text = str((chart.get("sectors") as Dictionary)[remembered].title)
	search.text_changed.emit(search.text)
	var diagram: Control = chart.get("diagram")
	diagram.call("center_on", remembered); diagram.call("zoom_at", 1.3, diagram.size * 0.5)
	await frames()
	var remembered_zoom: float = float(diagram.get("zoom"))
	var remembered_search: String = search.text
	host.ui.show_page("missions"); await frames()
	await show_map()
	check(chart.get_instance_id() != old_chart_id and chart.get("state") == host.state and str(chart.get("selected_sector")) == remembered, "reopening map rebuilds current-world binding and preserves selected sector")
	check(is_equal_approx(float((chart.get("diagram") as Control).get("zoom")), remembered_zoom) and (chart.get("search_box") as LineEdit).text == remembered_search, "same-world map reopen preserves zoom and search view")
	var previous_world: String = host.state.world_id
	await host._command("new_world", "星图绑定第二独立世界", 1, "")
	await wait_writer()
	await show_map()
	check(host.state.world_id != previous_world and chart.get("state") == host.state and chart.get("catalog") == host.store.catalog and str(chart.get("selected_sector")) == host.state.current_sector() and (chart.get("search_box") as LineEdit).text.is_empty(), "new-world activation discards old chart state/catalog references and remembered filter")
	await host._command("undock", "", 1, ""); await wait_writer()
	var endpoint: Dictionary = {}
	for row: Dictionary in host.store.catalog.rows("gate_endpoint_defs"):
		if str(row.origin_sector_id) == host.state.current_sector(): endpoint = row; break
	if not check(not endpoint.is_empty(), "actual new world has a directed travel entrance"): return
	# Infrastructure preconditions only: explicit permission/funding and entrance
	# positioning do not claim natural campaign progression or flight to the gate.
	host.gameplay.grant_unlock(str(endpoint.required_unlock_id))
	host.state.player().credit = 100000
	var gate: RefCounted = host.state.find("gate_state", "connection_id", str(endpoint.connection_id))
	gate.set("enabled", true)
	var entry: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", str(endpoint.entry_anchor_id))
	host.state.ship().pos_x = float(entry.x_m); host.state.ship().pos_y = float(entry.y_m); host.state.ship().pos_z = float(entry.z_m)
	host.state.ship().energy = float(host.gameplay.metrics(host.state.ship()).energy_max)
	host.world.flight.bind(host.state.ship(), host.store.catalog)
	await show_map()
	var old_runtime: RefCounted = host.state
	check(host.travel.begin(str(endpoint.endpoint_id)), "actual permitted entrance starts production travel")
	host.travel.tick(float(host.travel.remaining_s) + 0.01)
	await wait_writer(); await frames(5)
	check(host.state != old_runtime and host.state.current_sector() == str(endpoint.target_sector_id) and host.state.snapshot.meta.reason == "travel_destination", "actual travel commits a fresh destination runtime and SQLite boundary")
	await show_map()
	check(chart.get("state") == host.state and str(chart.get("selected_sector")) == host.state.current_sector(), "map after actual travel binds destination instead of stale origin")
	selected_details(host.state.current_sector(), "actual travel destination")

func synthetic_checks(count: int) -> void:
	var before_rows: int = snapshots()
	var formal_count: int = host.store.catalog.rows("sector_defs").size()
	var fixture: Control = Chart.new()
	fixture.name = "UiOnlySyntheticStarChart"
	fixture.position = Vector2(24, 24); fixture.size = Vector2(1100, 720)
	host.ui.show_page("")
	host.ui.root.add_child(fixture)
	fixture.call("configure", host.store.catalog, host.state)
	await frames()
	var sectors: Dictionary = {}; var links: Array[Dictionary] = []
	for index: int in range(count):
		var id: String = "ui_only_%03d" % index
		sectors[id] = {"title": "界面夹具星系 %03d" % index, "risk_zone_id": ["risk_high", "risk_medium", "risk_low"][index % 3]}
		if index > 0: links.append({"origin": "ui_only_%03d" % (index - 1), "destination": id})
		if index > 11: links.append({"origin": "ui_only_%03d" % (index - 12), "destination": id})
	fixture.set("sectors", sectors); fixture.set("links", links); fixture.set("selected_sector", "ui_only_000")
	var diagram: Control = fixture.get("diagram")
	diagram.call("rebuild_layout"); diagram.call("fit_all"); await frames(5)
	var points: Dictionary = diagram.get("world_points")
	check(points.size() == count and descendants(diagram) == 1 and descendants(fixture) < 70, "%d UI-only nodes retain constant canvas/control count" % count)
	var x_values: Dictionary = {}; var y_values: Dictionary = {}; var finite: bool = true
	for point: Vector2 in points.values():
		x_values[roundi(point.x)] = true; y_values[roundi(point.y)] = true; finite = finite and point.is_finite()
	check(finite and x_values.size() > 8 and y_values.size() > 8, "%d UI-only topology has finite two-dimensional spatial layout" % count)
	var overview_labels: int = (diagram.get("label_ids") as Array).size()
	check(overview_labels < count, "%d overview reduces label density instead of printing every name" % count)
	var fit_zoom: float = float(diagram.get("zoom"))
	diagram.call("zoom_at", 5.0, diagram.size * 0.5); diagram.call("center_on", "ui_only_150" if count == 300 else "ui_only_060"); await frames(4)
	check(float(diagram.get("zoom")) > fit_zoom and (diagram.get("visible_ids") as Array).size() < count and not (diagram.get("visible_ids") as Array).is_empty(), "%d enlarged view culls offscreen nodes while preserving visible graph" % count)
	var search: LineEdit = fixture.get("search_box")
	search.text = "界面夹具星系 %03d" % (count - 1); search.text_changed.emit(search.text)
	await frames(3)
	var matched: int = 0
	for id: String in sectors:
		if bool(fixture.call("matches_filter", id)): matched += 1
	check(matched == 1, "%d graph search finds one named fixture without building detail cards" % count)
	search.text_submitted.emit(search.text); await frames(4)
	check(str(fixture.get("selected_sector")) == "ui_only_%03d" % (count - 1) and (diagram.get("visible_ids") as Array).has(str(fixture.get("selected_sector"))), "%d search submission selects and centers the matching graph node" % count)
	search.text = "no-ui-fixture-matches"; search.text_changed.emit(search.text); await frames(3)
	matched = 0
	for id: String in sectors:
		if bool(fixture.call("matches_filter", id)): matched += 1
	check(matched == 0, "%d no-result search does not invent a sector or a connection" % count)
	search.text = ""; search.text_changed.emit("")
	var risk: OptionButton = fixture.get("risk_filter")
	risk.select(1); risk.item_selected.emit(1); await frames()
	matched = 0
	for id: String in sectors:
		if bool(fixture.call("matches_filter", id)): matched += 1
	check(matched > 0 and matched < count and (fixture.get("links") as Array).size() == links.size(), "%d risk filter changes display scope without fabricating bypass edges" % count)
	await capture("ui-only-%d" % count)
	fixture.queue_free(); await frames(4)
	check(snapshots() == before_rows and host.store.catalog.rows("sector_defs").size() == formal_count, "%d UI-only fixture never reaches SQLite or formal definitions" % count)
	synthetic_counts.append(count)
	await show_map()

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null; chart = null
	await frames(4); await create_timer(0.25).timeout
	print("STAR_CHART_V13_FINAL_JSON " + JSON.stringify({"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "synthetic_node_counts": synthetic_counts, "directory": directory, "native_events": "OS focus/pointer plus Viewport GUI events; hardware OS clicks remain manual"}))
	print("STAR_CHART_V13_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
