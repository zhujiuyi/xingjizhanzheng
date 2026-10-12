extends RefCounted
## Read-only source graph, current-hull routing and shared extraction estimates.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Status = preload("res://runtime/resource_status.gd")
var g: RefCounted
func _init(gameplay: RefCounted) -> void: g = gameplay

func _known(sector_id: String) -> bool:
	var row: D.SectorStateDto = g.state.find("sector_state", "sector_id", sector_id)
	return row != null and row.visited

func _unlock_reason(id: String) -> String:
	if id.is_empty() or g.unlocked(id): return ""
	return "需解锁 " + str(g.definition("unlock_defs", "unlock_id", id).get("display_name", id))

func _facility(station_id: String, service_id: String) -> Dictionary:
	for row: Dictionary in g.rows("station_service_defs"):
		if row.station_id == station_id and row.service_id == service_id: return {"present": true, "reason": _unlock_reason(row.required_unlock_id)}
	return {"present": false, "reason": "本站未提供此服务"}

func forecast(node_id: String) -> Dictionary:
	var info: Dictionary = Status.inspect(g.state, g.catalog, node_id)
	var node: Dictionary = g.definition("resource_node_defs", "node_id", node_id)
	var result: Dictionary = {"rate_per_min": 0.0, "room_units": 0, "fill_seconds": 0.0, "reason": "", "grade": str(info.get("grade_name", "")), "remaining_known": false}
	if node.is_empty(): result.reason = "资源地点不存在"; return result
	result.remaining_known = _known(node.sector_id)
	var observed: Dictionary = {}
	if g.situational != null and g.situational.supported():
		observed = g.situational.resource_reading(node_id)
		result.remaining_known = bool(observed.get("known",false)) and bool(observed.get("live",false))
	if g.definition("item_defs", "item_id", node.item_id).get("item_type", "") != "ore": result.reason = "组件使用近距离回收"; return result
	if not g.work._loan_target_allowed(node_id): result.reason = "教学借船仅可采集当前任务指定矿点"; return result
	var minimum_cycle: float = INF
	for equipment: D.EquipmentStateDto in g.equipped(g.state.ship()):
		if not equipment.enabled: continue
		var item: D.ItemInstanceStateDto = g.state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
		if item == null or item.durability <= 0: continue
		var compatible: bool = false
		for row: Dictionary in g.rows("mining_compatibility"):
			if row.module_id == equipment.module_def_id and row.item_id == node.item_id: compatible = true; break
		if not compatible: continue
		var module: Dictionary = g.definition("module_defs", "module_id", equipment.module_def_id)
		var units: int = Status.yield_per_cycle(g.catalog, node_id, g.state.ship().ship_def_id, equipment.module_def_id, g.exploration.mining_multiplier(node_id))
		if float(module.cycle_s) > 0.0:
			result.rate_per_min += float(units) / float(module.cycle_s) * 60.0
			minimum_cycle = minf(minimum_cycle, float(module.cycle_s))
	if result.rate_per_min <= 0: result.reason = "当前舰船未启用兼容矿头"; return result
	var available: int = g.work.available_resource_units(node_id) if result.remaining_known else int(node.capacity_units)
	var limits: Dictionary = g.work._output_limit(node.item_id, maxi(0, available))
	result.room_units = int(limits.count)
	if result.room_units <= 0:
		result.reason = "当前舱位/载重或教学配额不足" if available > 0 else "矿量耗尽或为教学预留"
	else: result.fill_seconds = maxf(minimum_cycle, float(result.room_units) / float(result.rate_per_min) * 60.0)
	return result

func sources(item_id: String) -> Array[Dictionary]:
	var item: Dictionary = g.definition("item_defs", "item_id", item_id)
	var result: Array[Dictionary] = []
	if item.is_empty(): return result
	for node: Dictionary in g.rows("resource_node_defs"):
		if node.item_id != item_id: continue
		if not g.exploration.resource_visible(node.node_id): continue
		var location: Dictionary = g.definition("resource_node_locations", "node_id", node.node_id)
		if location.is_empty(): continue
		var extraction: Dictionary = forecast(node.node_id)
		var reason: String = _unlock_reason(location.required_unlock_id)
		if reason.is_empty(): reason = str(extraction.reason)
		var known: bool = _known(node.sector_id)
		var info: Dictionary = Status.inspect(g.state, g.catalog, node.node_id)
		var detail: String = (Status.summary(info) if known else "矿量与再生未知 · " + str(info.grade_name))
		if g.situational != null and g.situational.supported():
			detail = g.situational.resource_text(node.node_id)
			known = bool(g.situational.resource_reading(node.node_id).get("known",false))
		if float(extraction.rate_per_min) > 0: detail += "\n当前配装理论 %.1f 单位/分钟；下一舱可装 %d，约 %.0f 秒。电容、热量、距离与视线另行校验。" % [extraction.rate_per_min, extraction.room_units, ceil(extraction.fill_seconds)]
		result.append({"key": "node:" + str(node.node_id), "kind": "采矿" if item.item_type == "ore" else "组件回收", "id": node.node_id, "item_id": item_id, "sector_id": node.sector_id, "anchor_id": location.anchor_id, "target_id": node.node_id, "target_kind": "resource", "title": str(item.display_name) + " · " + str(extraction.grade), "reason": reason, "detail": detail, "known": known})
	for stock: Dictionary in g.rows("station_stock_defs"):
		if stock.item_id != item_id or not stock.allow_buy: continue
		var station: Dictionary = g.definition("station_defs", "station_id", stock.station_id)
		var facility: Dictionary = _facility(stock.station_id, "trade")
		if not facility.present: continue
		var reason: String = _unlock_reason(stock.required_unlock_id)
		if reason.is_empty(): reason = str(facility.reason)
		var known: bool = _known(station.sector_id)
		if g.situational != null and g.situational.supported(): known = str(stock.station_id)==g.station()
		var amount: int = -1
		if known:
			for row: D.ShopStockStateDto in g.state.rows("shop_stock_state"):
				if row.station_id == stock.station_id and row.item_def_id == item_id: amount = row.quantity; break
		if amount == 0 and reason.is_empty(): reason = "库存已售罄，等待站点补货"
		result.append({"key": "market:" + str(stock.station_id), "kind": "采购", "id": stock.station_id, "item_id": item_id, "sector_id": station.sector_id, "anchor_id": station.station_anchor_id, "target_id": station.station_id, "target_kind": "station", "title": str(station.display_name), "reason": reason, "detail": ("当前库存 %d" % amount if amount >= 0 else "当前库存未知") + " · 基准价 %d 信用点，实际报价在站点成交时确认。" % int(item.base_ask_credit), "known": known})
	for recipe: Dictionary in g.rows("recipe_defs"):
		if recipe.output_item_id != item_id: continue
		var materials: PackedStringArray = []
		for input: Dictionary in g.rows("recipe_inputs"):
			if input.recipe_id == recipe.recipe_id: materials.append("%s × %d" % [g.definition("item_defs", "item_id", input.item_id).display_name, int(input.quantity)])
		for access: Dictionary in g.rows("recipe_access_defs"):
			if access.recipe_id != recipe.recipe_id: continue
			var station: Dictionary = g.definition("station_defs", "station_id", access.station_id)
			var facility: Dictionary = _facility(access.station_id, "manufacture")
			if not facility.present: continue
			var reason: String = _unlock_reason(access.required_unlock_id)
			if reason.is_empty(): reason = str(facility.reason)
			result.append({"key": "craft:" + str(access.station_id) + ":" + str(recipe.recipe_id), "kind": "加工制造", "id": recipe.recipe_id, "item_id": item_id, "sector_id": station.sector_id, "anchor_id": station.station_anchor_id, "target_id": station.station_id, "target_kind": "station", "title": str(station.display_name), "reason": reason, "detail": "每批产出 %d；投入：%s。可继续查询这些投入的来源。" % [int(recipe.output_quantity), "、".join(materials)], "known": _known(station.sector_id)})
	_salvage_sources(item_id, result)
	var routes: Dictionary = {}
	for row: Dictionary in result:
		if not routes.has(row.sector_id): routes[row.sector_id] = g.missions._route_location({"sector_id": row.sector_id}, "")
		row.route = routes[row.sector_id]
		row.hops = maxi(0, row.route.route_sectors.size() - 1)
		row.route_open = str(row.route.route_reason).is_empty()
		row.distance = g.anchor_distance(g.state.ship(), g.definition("anchor_defs", "anchor_id", row.anchor_id)) if row.sector_id == g.state.current_sector() else INF
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.route_open != b.route_open: return a.route_open
		if a.hops != b.hops: return a.hops < b.hops
		if a.distance != b.distance: return a.distance < b.distance
		return str(a.key) < str(b.key))
	return result

func _salvage_sources(item_id: String, result: Array[Dictionary]) -> void:
	if not g.catalog.table_names.has("salvage_reward_defs"): return
	var package_ids: Dictionary = {}
	for reward: Dictionary in g.rows("salvage_reward_defs"):
		if reward.item_def_id == item_id: package_ids[reward.package_def_id] = true
	var seen: Dictionary = {}
	for spawn: Dictionary in g.rows("npc_spawn_defs"):
		if spawn.occurrence_mode != "ambient" or not spawn.loot_enabled: continue
		var mapping: Dictionary = g.definition("npc_salvage_defs", "npc_def_id", spawn.npc_id)
		if mapping.is_empty() or not package_ids.has(mapping.package_def_id): continue
		var group: String = g.encounters.group_for_spawn(spawn.spawn_id)
		if group.is_empty() or seen.has(group): continue
		seen[group] = true
		var encounter: Dictionary = g.definition("encounter_defs", "encounter_id", group)
		var anchor: String = str(encounter.get("anchor_id", spawn.anchor_id))
		result.append({"key": "salvage:" + group, "kind": "战斗打捞", "id": group, "item_id": item_id, "sector_id": spawn.sector_id, "anchor_id": anchor, "target_id": "group:" + group, "target_kind": "encounter", "title": str(encounter.get("display_name", "敌舰群")), "reason": "", "detail": "击毁敌舰并回收密封包，返回空间站鉴定。该物资是随机载荷之一，并非保证掉落；结果在生成时固定。", "known": _known(spawn.sector_id)})

func guidance(key: String, item_id: String) -> Dictionary:
	for row: Dictionary in sources(item_id):
		if row.key != key: continue
		var location: Dictionary = g.missions._anchor_location(row.anchor_id, row.target_id, row.target_kind, row.title)
		location["required_page"] = "market" if row.kind == "采购" else "industry" if row.kind == "加工制造" else ""
		location["source_key"] = key; location["item_id"] = item_id; location["eligibility_reason"] = row.reason
		return g.missions._route_location(location, "")
	return {}

func ingredients(blueprint_id: String) -> Array[Dictionary]:
	var hull: Dictionary = g.definition("hull_recipe_defs", "hull_recipe_id", blueprint_id)
	var table: String = "hull_recipe_inputs" if not hull.is_empty() else "recipe_inputs"
	var key: String = "hull_recipe_id" if not hull.is_empty() else "recipe_id"
	var result: Array[Dictionary] = []
	for row: Dictionary in g.rows(table):
		if row[key] == blueprint_id: result.append(row)
	return result
