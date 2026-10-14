extends VBoxContainer
## Sources are derived from the loaded world's database; this view writes no game state.
const T = preload("res://contracts/contract_types.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
var u: Node
var context: Dictionary
var items: Array[Dictionary] = []

func setup(ui: Node) -> void:
	u = ui
	context = {"state": u.state, "world": u.state.world_id, "session": u.state.session_id, "epoch": u.state.epoch, "generation": u.business_generation, "ship": u.state.ship().ship_instance_id}
	add_theme_constant_override("separation", UISkin.GAP)
	var toolbar: HFlowContainer = HFlowContainer.new(); add_child(toolbar)
	var search: LineEdit = LineEdit.new()
	search.name = "SourceSearch"; search.placeholder_text = "输入物资名称，按 Enter 搜索"; search.text = u.source_search
	search.custom_minimum_size = Vector2(220, 34); toolbar.add_child(search)
	search.text_submitted.connect(func(value: String):
		if not _current(): return
		u.source_search = value.strip_edges(); u.source_page = 0; u.show_page("sources"))
	var picker: OptionButton = OptionButton.new()
	picker.name = "SourceItem"; picker.custom_minimum_size = Vector2(210, 34); toolbar.add_child(picker)
	for item: Dictionary in u.catalog.rows("item_defs"):
		if not u.source_search.is_empty() and not str(item.display_name).contains(u.source_search) and not str(item.item_id).contains(u.source_search): continue
		items.append(item)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.display_name).naturalnocasecmp_to(str(b.display_name)) < 0)
	var selected: int = -1
	for index: int in range(items.size()):
		picker.add_item(items[index].display_name)
		picker.set_item_metadata(index, items[index].item_id)
		if items[index].item_id == u.source_item_id: selected = index
	if selected < 0 and not items.is_empty(): selected = 0; u.source_item_id = items[0].item_id
	if selected >= 0: picker.select(selected)
	picker.item_selected.connect(func(index: int):
		if not _current(): return
		u.source_item_id = str(items[index].item_id); u.source_page = 0; u.show_page("sources"))
	u._button(toolbar, "刷新当前航路", func():
		if _current(): u.show_page("sources"))
	u._button(toolbar, "返回", func():
		if _current(): u._back())
	u._text_to(self, "公开来源按当前船体与航门状态规划；未知区域不显示精确矿量或库存。前往只导航到下一跳/本地地点，过门按 F 确认；抵达后自行交易、采集或交战。", 13).add_theme_color_override("font_color", UISkin.MUTED)
	var types: HFlowContainer = HFlowContainer.new(); add_child(types)
	for kind: String in ["全部", "采矿", "组件回收", "采购", "加工制造", "战斗打捞"]:
		var button: Button = u._button(types, kind, func():
			if _current(): u.source_filter = kind; u.source_page = 0; u.show_page("sources"))
		button.name = "SourceFilter_" + kind
		button.toggle_mode = true; button.button_pressed = u.source_filter == kind
		button.custom_minimum_size = Vector2(0, 32); button.add_theme_font_size_override("font_size", 13)
		UISkin.apply_button(button, "filter", true, u.source_filter == kind)
	if items.is_empty(): u._text_to(self, "没有符合名称的物资。", 14); return
	var all: Array = u.gameplay.resource_intel.sources(u.source_item_id)
	var rows: Array[Dictionary] = []
	for row: Dictionary in all:
		if u.source_filter == "全部" or row.kind == u.source_filter: rows.append(row)
	var pages: int = maxi(1, ceili(float(rows.size()) / 8.0))
	u.source_page = clampi(u.source_page, 0, pages - 1)
	var pager: HFlowContainer = HFlowContainer.new(); add_child(pager)
	var previous: Button = u._button(pager, "上一页", func():
		if _current(): u.source_page -= 1; u.show_page("sources"))
	previous.disabled = u.source_page <= 0
	u._text_to(pager, "%d 个来源 · %d / %d 页" % [rows.size(), u.source_page + 1, pages], 14)
	var next: Button = u._button(pager, "下一页", func():
		if _current(): u.source_page += 1; u.show_page("sources"))
	next.disabled = u.source_page + 1 >= pages
	if rows.is_empty(): u._text_to(self, "未记录符合条件的公开来源；可切换类别，或查看科研与剧情前置。", 14)
	for index: int in range(u.source_page * 8, mini(rows.size(), (u.source_page + 1) * 8)):
		_source_row(rows[index])

func _source_row(row: Dictionary) -> void:
	var frame: PanelContainer = u._frame(self, "SourceCard_" + str(row.key).validate_node_name())
	frame.add_theme_stylebox_override("panel", UISkin.panel_style())
	var card: VBoxContainer = VBoxContainer.new(); card.add_theme_constant_override("separation", UISkin.GAP); frame.add_child(card)
	var title: Label = u._text_to(card, "%s · %s · %s" % [row.kind, u._sector_name(row.sector_id), row.title], 16)
	title.name = "SourceTitle_" + str(row.key).validate_node_name()
	if u.catalog.table_names.has("sector_activity_defs"):
		var activity: Dictionary = u.catalog.one("sector_activity_defs", "sector_id", row.sector_id)
		u._text_to(card, str(activity.get("environment_hint", "")) + " · " + str(activity.get("logistics_role", "")), 13).add_theme_color_override("font_color", UISkin.MUTED)
	u._text_to(card, str(row.detail), 13).add_theme_color_override("font_color", UISkin.MUTED)
	var route: PackedStringArray = []
	for id: String in row.route.route_sectors: route.append(u._sector_name(id))
	var distance: String = XJSpaceUnits.distance(float(row.distance)) if is_finite(float(row.distance)) else "%d 跳" % int(row.hops)
	var reason: String = str(row.route.route_reason)
	if not str(row.reason).is_empty(): reason += ("；" if not reason.is_empty() else "") + str(row.reason)
	u._text_to(card, "航路：%s · %s%s" % [" → ".join(route), distance, "\n条件：" + reason if not reason.is_empty() else ""], 13).add_theme_color_override("font_color", UISkin.AMBER if not reason.is_empty() else UISkin.ICE)
	var actions: HFlowContainer = HFlowContainer.new(); card.add_child(actions)
	var map_button: Button = u._button(actions, "星图定位", func(): _request("source_map", row.key, row.item_id))
	map_button.name = "SourceMap_" + str(row.key).validate_node_name()
	var go: Button = u._button(actions, "前往地点" if int(row.hops) == 0 else "前往下一航门", func(): _request("source_travel", row.key, row.item_id))
	go.name = "SourceTravel_" + str(row.key).validate_node_name()
	go.disabled = not bool(row.route_open) or u.state.ship().status != T.ShipStatus.FLYING
	go.tooltip_text = "请先出港；可从飞行星图重新打开物资来源。" if u.state.ship().status != T.ShipStatus.FLYING else str(row.route.route_reason) if not row.route_open else "导航只改变航行指令，不自动支付、采集或发放物资。"
	if row.kind == "加工制造":
		for input: Dictionary in u.gameplay.resource_intel.ingredients(row.id):
			u._button(actions, "查 " + u._item_name(input.item_id), func():
				if _current(): u.source_item_id = input.item_id; u.source_search = ""; u.source_page = 0; u.show_page("sources"))

func _current() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(u) or u.page != "sources" or u.state == null: return false
	return u.body.is_ancestor_of(self) and u.state == context.state and u.state.world_id == context.world and u.state.session_id == context.session and u.state.epoch == context.epoch and u.state.ship().ship_instance_id == context.ship and u.business_generation == context.generation

func _request(action: String, key: String, item_id: String) -> void:
	if _current(): u.requested.emit(action, key, 1, item_id)
