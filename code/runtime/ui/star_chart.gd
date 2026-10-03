class_name XJStarChart
extends VBoxContainer
## A schematic of actual frozen wormhole connections, never a teleport command.
signal sector_selected(sector_id: String)
const UISkin = preload("res://runtime/ui_theme.gd")
const ResourceStatus = preload("res://runtime/resource_status.gd")
var catalog: XJCatalog
var state: XJRuntimeState
var selected_sector: String = ""
var sectors: Dictionary = {}
var links: Array[Dictionary] = []
var diagram: ChartDrawing
var information: Label
var resource_information: Label
var _resource_nodes: Array[Dictionary] = []

class ChartDrawing extends Control:
	var chart: XJStarChart
	var points: Dictionary = {}
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 300)
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)
	func _draw() -> void:
		if chart == null: return
		points.clear()
		var groups: Array[String] = ["risk_high", "risk_medium", "risk_low"]
		for column: int in range(groups.size()):
			var members: Array[String] = []
			for id: String in chart.sectors:
				if chart.sectors[id].risk_zone_id == groups[column]: members.append(id)
			members.sort()
			var x: float = size.x * (float(column) + 0.5) / 3.0
			var color: Color = chart._risk_color(groups[column])
			draw_line(Vector2(x, 28), Vector2(x, size.y - 18), Color(color, 0.08), 50)
			var heading: String = ["高安全区", "中安全区", "低安全区"][column]
			draw_string(UISkin.font(), Vector2(x - 35, 20), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
			for index: int in range(members.size()):
				points[members[index]] = Vector2(x, 45 + (size.y - 90) * (index + 0.5) / members.size())
		for link: Dictionary in chart.links:
			if not points.has(link.origin) or not points.has(link.destination): continue
			var highlighted: bool = link.origin == chart.selected_sector or link.destination == chart.selected_sector
			draw_line(points[link.origin], points[link.destination], Color(UISkin.AMBER, 0.55) if highlighted else Color(UISkin.MUTED, 0.22), 1.4 if highlighted else 1.0, true)
		for id: String in points:
			var point: Vector2 = points[id]
			var color: Color = chart._risk_color(str(chart.sectors[id].risk_zone_id))
			draw_circle(point, 7, color)
			if id == chart.selected_sector: draw_arc(point, 12, 0, TAU, 32, UISkin.AMBER, 1.5, true)
			if chart.state != null and id == chart.state.current_sector():
				draw_arc(point, 17, 0, TAU, 32, UISkin.TEXT, 1.2, true)
			draw_string(UISkin.font(), point + Vector2(14, 5), str(chart.sectors[id].title), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UISkin.TEXT)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for id: String in points:
				if event.position.distance_to(points[id]) <= 22:
					chart.select_sector(id)
					accept_event()
					return

func _ready() -> void:
	name = "StarChart"
	add_theme_constant_override("separation", 10)
	diagram = ChartDrawing.new()
	diagram.chart = self
	diagram.name = "WormholeTopology"
	add_child(diagram)
	information = Label.new()
	information.name = "SectorIntelligence"
	information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.add_theme_font_size_override("font_size", 13)
	information.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(information)
	resource_information = Label.new()
	resource_information.name = "ResourceIntelligence"
	resource_information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_information.add_theme_font_size_override("font_size", 13)
	resource_information.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(resource_information)
	_update_information()

func configure(definitions: XJCatalog, runtime: XJRuntimeState) -> void:
	catalog = definitions
	state = runtime
	sectors.clear()
	links.clear()
	for row: Dictionary in catalog.rows("sector_defs"):
		var system: Dictionary = catalog.one("system_defs", "system_id", row.system_id)
		sectors[str(row.sector_id)] = {"title": str(system.get("display_name", row.sector_id)), "risk_zone_id": str(row.risk_zone_id)}
	var seen: Dictionary = {}
	for endpoint: Dictionary in catalog.rows("gate_endpoint_defs"):
		var identity: String = str(endpoint.connection_id)
		if seen.has(identity): continue
		seen[identity] = true
		links.append({"origin": str(endpoint.origin_sector_id), "destination": str(endpoint.target_sector_id)})
	selected_sector = state.current_sector()
	_update_information()
	if is_instance_valid(diagram): diagram.queue_redraw()

func select_sector(id: String) -> void:
	if not sectors.has(id): return
	selected_sector = id
	_update_information()
	if is_instance_valid(diagram): diagram.queue_redraw()
	sector_selected.emit(id)

func _risk_color(id: String) -> Color:
	return {"risk_high": Color("80b9c8"), "risk_medium": UISkin.AMBER, "risk_low": Color("dc8779")}.get(id, UISkin.MUTED)

func _update_information() -> void:
	if not is_instance_valid(information) or catalog == null or not sectors.has(selected_sector): return
	var row: Dictionary = sectors[selected_sector]
	var risk: Dictionary = catalog.one("risk_zone_defs", "risk_zone_id", row.risk_zone_id)
	var station_names: Array[String] = []
	var factions: Array[String] = []
	for station: Dictionary in catalog.rows("station_defs"):
		if station.sector_id != selected_sector: continue
		station_names.append(str(station.display_name))
		var faction: Dictionary = catalog.one("faction_defs", "faction_id", station.faction_id)
		var title: String = str(faction.get("display_name", "未知势力"))
		if not factions.has(title): factions.append(title)
	var resources: Array[String] = []
	_resource_nodes.clear()
	for location: Dictionary in catalog.rows("resource_node_locations"):
		var anchor: Dictionary = catalog.one("anchor_defs", "anchor_id", location.anchor_id)
		if anchor.get("sector_id", "") != selected_sector: continue
		var node: Dictionary = catalog.one("resource_node_defs", "node_id", location.node_id)
		var item: Dictionary = catalog.one("item_defs", "item_id", node.get("item_id", ""))
		var title: String = str(item.get("display_name", "未知资源"))
		if not resources.has(title): resources.append(title)
		_resource_nodes.append({"node_id": str(location.node_id), "title": title})
	var route: Array[String] = _route(state.current_sector(), selected_sector)
	var names: Array[String] = []
	for id: String in route: names.append(str(sectors[id].title))
	information.text = "%s  ·  %s  ·  NPC 等级 %d–%d\n势力：%s  /  空间站：%s\n资源：%s\n%s\n示意图按安全区排列；星系间仍需实际进入虫洞门并满足权限。" % [row.title, risk.get("display_name", "未知安全区"), int(risk.get("npc_level_min", 0)), int(risk.get("npc_level_max", 0)), "、".join(factions), "、".join(station_names), "、".join(resources), "当前位置" if selected_sector == state.current_sector() else ("虫洞路线：" + " → ".join(names) if not route.is_empty() else "暂无虫洞连接路线")]
	refresh_resource_status()

func refresh_resource_status() -> void:
	if not is_instance_valid(resource_information) or state == null or catalog == null: return
	var visit: RefCounted = state.find("sector_state", "sector_id", selected_sector)
	var known: bool = selected_sector == state.current_sector() or (visit != null and visit.visited)
	var lines: Array[String] = ["矿点情报 · 世界时间"]
	for entry: Dictionary in _resource_nodes:
		var status: String = "尚未到访 · 实时矿量未知"
		if known:
			var info: Dictionary = ResourceStatus.inspect(state, catalog, str(entry.node_id))
			status = ResourceStatus.summary(info)
			if bool(info.get("available", false)) and int(info.get("capacity_units", 0)) > 0:
				status += " · %.0f%%" % (float(info.remaining_units) / float(info.capacity_units) * 100.0)
		lines.append(str(entry.title) + "：" + status)
	if _resource_nodes.is_empty(): lines.append("未记录矿点")
	var text: String = "\n".join(lines)
	if resource_information.text != text:
		resource_information.text = text
		resource_information.tooltip_text = text + "\n未到访星区只显示已知产出；矿量与再生时间以当前世界SQLite状态为准。暂停与退出不推进。"

func _route(origin: String, destination: String) -> Array[String]:
	var queue: Array[String] = [origin]
	var predecessors: Dictionary = {origin: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == destination: break
		for link: Dictionary in links:
			var other: String = str(link.destination) if link.origin == current else str(link.origin) if link.destination == current else ""
			if other.is_empty() or predecessors.has(other): continue
			predecessors[other] = current
			queue.append(other)
	var result: Array[String] = []
	if not predecessors.has(destination): return result
	var step: String = destination
	while not step.is_empty():
		result.push_front(step)
		step = str(predecessors[step])
	return result
