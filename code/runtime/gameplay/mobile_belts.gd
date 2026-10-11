extends RefCounted
## AU placement and finite dispersion are world state, never renderer-only offsets.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var owner_by_anchor: Dictionary = {}
var routes: Dictionary = {}
var mapping: Dictionary = {}
var stages: Array[Dictionary] = []

func _init(game: RefCounted) -> void:
	g = game
	if not supported(): return
	for route: Dictionary in g.rows("exploration_belt_route_defs"):
		if not routes.has(route.event_id): routes[route.event_id] = []
		routes[route.event_id].append(route)
	for event: String in routes: routes[event].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.route_index) < int(b.route_index))
	for link: Dictionary in g.rows("exploration_belt_anchor_defs"):
		var route: Dictionary = g.definition("exploration_belt_route_defs", "route_id", link.route_id)
		owner_by_anchor[link.base_anchor_id] = route.event_id
		mapping[link.route_id + ":" + link.base_anchor_id] = link.anchor_id
	stages = g.rows("exploration_belt_stage_defs").duplicate()
	stages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.stage_index) < int(b.stage_index))

func supported() -> bool: return g != null and g.catalog.table_names.has("exploration_belt_route_defs")
func instance(event_id: String) -> D.ExplorationBeltStateDto: return g.state.find("exploration_belt_state", "event_id", event_id)

static func initial_rows(catalog: XJCatalog, state: XJRuntimeState) -> Array[D.ExplorationBeltStateDto]:
	var rows: Array[D.ExplorationBeltStateDto] = []
	if not catalog.table_names.has("exploration_belt_route_defs"): return rows
	for route: Dictionary in catalog.rows("exploration_belt_route_defs"):
		if int(route.route_index) != 0: continue
		var row: D.ExplorationBeltStateDto = D.ExplorationBeltStateDto.new()
		row.event_id = route.event_id; row.route_id = route.route_id
		var event: RefCounted = state.find("exploration_instance_state", "event_id", row.event_id)
		var variant: Dictionary = catalog.one("exploration_variant_defs", "variant_id", event.variant_id)
		row.initial_units = int(variant.mineral_units)
		if event.phase == "mineral":
			row.start_elapsed_s = event.elapsed_s
			for node: Dictionary in catalog.rows("exploration_resource_defs"):
				if node.event_id == row.event_id and node.choice_id == event.choice_id: row.initial_units = state.find("resource_state", "node_id", node.node_id).remaining_units
		rows.append(row)
	return rows

static func resolved_anchor(catalog: XJCatalog, state: XJRuntimeState, anchor_id: String) -> String:
	if not catalog.table_names.has("exploration_belt_anchor_defs"): return anchor_id
	for link: Dictionary in catalog.rows("exploration_belt_anchor_defs"):
		if link.base_anchor_id != anchor_id: continue
		for row: RefCounted in state.rows("exploration_belt_state"):
			if row.route_id == link.route_id: return str(link.anchor_id)
	return anchor_id

func resolve(anchor_id: String) -> String:
	if not owner_by_anchor.has(anchor_id): return anchor_id
	var row: D.ExplorationBeltStateDto = instance(owner_by_anchor[anchor_id])
	return str(mapping.get(row.route_id + ":" + anchor_id, anchor_id)) if row != null else anchor_id

func begin(event: RefCounted) -> void:
	var row: D.ExplorationBeltStateDto = instance(event.event_id)
	if row == null: return
	row.stage_index = 0; row.warning_stage_index = 0; row.start_elapsed_s = 0.0
	row.initial_units = int(g.exploration.variant(event).mineral_units)

func can_renew(event_id: String) -> bool:
	if not routes.has(event_id): return true
	for route: Dictionary in routes[event_id]:
		var anchor: Dictionary = g.catalog.one("anchor_defs", "anchor_id", route.entry_anchor_id)
		if g.same_anchor_site(g.state.ship(), anchor): return false
	return true

func renew(event: RefCounted) -> void:
	var row: D.ExplorationBeltStateDto = instance(event.event_id)
	if row == null: return
	var route: Dictionary = g.definition("exploration_belt_route_defs", "route_id", row.route_id)
	var choices: Array = routes[event.event_id]
	row.route_id = choices[(int(route.route_index) + 1) % choices.size()].route_id
	begin(event)

func _threshold(event: RefCounted, row: RefCounted, stage: Dictionary) -> float:
	return row.start_elapsed_s + (float(g.exploration.variant(event).duration_s) - row.start_elapsed_s) * float(stage.threshold_bp) / 10000.0

func tick(event: RefCounted, local: bool) -> void:
	var row: D.ExplorationBeltStateDto = instance(event.event_id)
	if row == null or event.phase != "mineral": return
	for stage: Dictionary in stages:
		var threshold: float = _threshold(event, row, stage)
		if int(stage.stage_index) > row.warning_stage_index and event.elapsed_s >= threshold - float(stage.warning_lead_s):
			row.warning_stage_index = int(stage.stage_index)
			if local: g.exploration.warning_changed.emit("矿带即将%s：未采矿量上限降至%d%%，已入舱矿物保留。" % [str(stage.display_name), int(stage.remaining_cap_bp) / 100])
		if event.elapsed_s < threshold or int(stage.stage_index) <= row.stage_index: continue
		row.stage_index = int(stage.stage_index)
		var cap: int = int(floor(float(row.initial_units) * float(stage.remaining_cap_bp) / 10000.0))
		for node: Dictionary in g.rows("exploration_resource_defs"):
			if node.event_id != event.event_id: continue
			var resource: RefCounted = g.state.find("resource_state", "node_id", node.node_id)
			resource.remaining_units = mini(resource.remaining_units, cap)
			if resource.remaining_units <= 0 and g.work.mining_target == node.node_id: g.work.stop_mining()
		g.request_autosave()

func detail(event_id: String) -> String:
	var row: D.ExplorationBeltStateDto = instance(event_id)
	if row == null: return ""
	var event: RefCounted = g.exploration.instance(event_id)
	var route: Dictionary = g.definition("exploration_belt_route_defs", "route_id", row.route_id)
	var text: String = "矿带位置 · " + str(route.display_name) + "；本轮结束并离场后，冷却完成将迁往另一处AU地点。"
	if event.phase == "ready": text += "\n先交付本轮成果，迁移冷却随后开始。"
	if event.phase in ["claimed", "failed", "withdrawn"]: text += "\n迁移冷却剩余 %.0f 秒；需驶离该矿带的全部候选局部空间。" % ceil(event.cooldown_remaining_s)
	if event.phase != "mineral": return text
	var cap_bp: int = 10000 if row.stage_index == 0 else int(g.definition("exploration_belt_stage_defs", "stage_index", row.stage_index).remaining_cap_bp)
	text += "\n散逸阶段 %d/3 · 本轮未采矿量上限 %d；已采成果不扣除。" % [row.stage_index, int(floor(float(row.initial_units) * float(cap_bp) / 10000.0))]
	for stage: Dictionary in stages:
		if int(stage.stage_index) <= row.stage_index: continue
		var seconds: float = maxf(0.0, _threshold(event, row, stage) - event.elapsed_s)
		text += "\n%s%s：%.0f秒后矿量上限降至%d%%。" % ["预警 · " if seconds <= float(stage.warning_lead_s) else "下一阶段 · ", str(stage.display_name), ceil(seconds), int(stage.remaining_cap_bp) / 100]
		break
	return text
