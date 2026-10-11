extends RefCounted
## Objective authority. Physical generators use NPC HP; cargo is part of real capacity.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var structures: Dictionary = {}
signal warning_changed(message: String)

func _init(game: RefCounted) -> void:
	g = game
	if supported():
		for spec: Dictionary in g.rows("operation_structure_defs"): structures[spec.spawn_id] = spec
func supported() -> bool: return g != null and g.catalog.table_names.has("operation_defs")
static func initial_rows(catalog: XJCatalog) -> Array[D.OperationStateDto]:
	var result: Array[D.OperationStateDto] = []
	if catalog.table_names.has("operation_defs"):
		for spec: Dictionary in catalog.rows("operation_defs"):
			var row: D.OperationStateDto = D.OperationStateDto.new(); row.operation_id = spec.operation_id; result.append(row)
	return result
func instance(id: String) -> D.OperationStateDto: return g.state.find("operation_state", "operation_id", id)
func definition(id: String) -> Dictionary: return g.definition("operation_defs", "operation_id", id)
func handles(spawn_id: String) -> bool: return structures.has(spawn_id)
func structure_active(npc: D.NpcStateDto) -> bool:
	if not handles(npc.spawn_id): return false
	var row: D.OperationStateDto = instance(structures[npc.spawn_id].operation_id)
	return row != null and row.phase == "active" and row.generation == npc.generation
func _at(row: D.OperationStateDto, exit_point: bool = false) -> bool:
	var spec: Dictionary = definition(row.operation_id)
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", spec.exit_anchor_id if exit_point else spec.entry_anchor_id)
	return g.state.ship().status == T.ShipStatus.FLYING and g.same_anchor_site(g.state.ship(), anchor) and g.anchor_distance(g.state.ship(), anchor) <= float(spec.interaction_radius_m)
func _site(row: D.OperationStateDto) -> bool:
	return g.same_anchor_site(g.state.ship(), g.definition("anchor_defs", "anchor_id", definition(row.operation_id).entry_anchor_id))
func cargo(ship_id: String) -> Dictionary:
	var mass: float = 0.0; var volume: float = 0.0
	if supported():
		for row: D.OperationStateDto in g.state.rows("operation_state"):
			if not row.has_payload_ship_id or row.payload_ship_id != ship_id: continue
			var spec: Dictionary = definition(row.operation_id)
			mass += row.cargo_units * float(spec.cargo_mass_kg); volume += row.cargo_units * float(spec.cargo_volume_l)
	return {"mass": mass, "volume": volume}
func load_capacity(id: String) -> int:
	var spec: Dictionary = definition(id)
	if spec.is_empty() or spec.operation_kind != "breakthrough": return 0
	var limits: Dictionary = g.metrics(g.state.ship())
	return maxi(0, mini(int(spec.target_units), mini(int(floor(maxf(0.0, limits.cargo_capacity_l - limits.cargo_used_l) / float(spec.cargo_volume_l))), int(floor(maxf(0.0, limits.max_payload_mass_kg - limits.payload_mass_kg) / float(spec.cargo_mass_kg))))))
func action_reason(id: String, action: String) -> String:
	var row: D.OperationStateDto = instance(id); var spec: Dictionary = definition(id)
	if row == null or spec.is_empty(): return "行动不存在"
	if not g.unlocked(spec.required_unlock_id): return "需要远域航路许可"
	match action:
		"accept":
			if row.phase not in ["available", "claimed", "failed", "withdrawn"]: return "行动已接取或成果尚未交付"
			if row.cooldown_remaining_s > 0.0: return "行动整备剩余 %.0f 秒" % row.cooldown_remaining_s
			if g.station() != spec.station_id or g.state.ship().status != T.ShipStatus.DOCKED: return "需要在任务签发站接取"
		"start":
			if row.phase != "accepted": return "需要先在签发站接取"
			if not _at(row): return "需要实际抵达行动起点 %.0f 米内" % spec.interaction_radius_m
			if spec.operation_kind == "breakthrough" and load_capacity(id) < 1: return "至少需要 %.0f 升货舱及 %.0f 千克载荷空余" % [spec.cargo_volume_l, spec.cargo_mass_kg]
		"exit":
			if row.phase != "active": return "当前没有进行中的行动"
			if not _at(row, true): return "需要实际抵达撤离点 %.0f 米内" % spec.interaction_radius_m
		"withdraw":
			if row.phase not in ["accepted", "active"]: return "当前没有可撤回的行动"
		"jettison":
			if row.phase != "active" or row.cargo_units <= 0: return "当前没有突破物资"
			if not _site(row) or g.state.ship().status != T.ShipStatus.FLYING: return "需要在行动空域飞行"
		"claim":
			if row.phase != "ready" or row.completed_units <= 0: return "没有可交付成果"
			if g.station() != spec.station_id or g.state.ship().status != T.ShipStatus.DOCKED: return "需要返回任务签发站交付"
		_: return "未知行动指令"
	return ""
func execute(id: String, action: String, generation: String) -> bool:
	var row: D.OperationStateDto = instance(id)
	if row == null or str(row.generation) != generation: return g.fail("行动代次已变化，请重新打开界面")
	var reason: String = action_reason(id, action)
	if not reason.is_empty(): return g.fail(reason)
	var spec: Dictionary = definition(id)
	match action:
		"accept":
			row.generation += 1; row.phase = "accepted"; row.remaining_s = 0.0
			row.loaded_units = 0; row.cargo_units = 0; row.completed_units = 0; row.lost_units = 0; row.jettisoned_units = 0
			row.exposure_remaining_s = 0.0; row.damage_debt_hp = 0.0; row.has_payload_ship_id = false; row.payload_ship_id = ""
			for spawn_id: String in structures:
				if structures[spawn_id].operation_id != id: continue
				var previous: RefCounted = g.state.find("npc_state", "spawn_id", spawn_id)
				if previous != null: g.remove_npc(previous)
		"start":
			if spec.operation_kind == "demolition":
				for spawn_id: String in structures:
					if structures[spawn_id].operation_id == id: _spawn(row, spawn_id)
			else:
				row.loaded_units = load_capacity(id); row.cargo_units = row.loaded_units
				row.payload_ship_id = g.state.ship().ship_instance_id; row.has_payload_ship_id = true
			row.phase = "active"; row.remaining_s = float(spec.duration_s)
			warning_changed.emit("行动计时开始 · " + status_text(id))
		"exit": _finish(row, true)
		"withdraw": _finish(row, false)
		"jettison":
			row.cargo_units -= 1; row.jettisoned_units += 1
			warning_changed.emit("主动抛弃突破物资 × 1 · 剩余 %d / %d，成果按送达数量结算" % [row.cargo_units, spec.target_units])
		"claim":
			var credit: int = row.completed_units * int(spec.credit_per_unit)
			g.state.player().credit += credit; row.paid_credit_total += credit; row.rewarded_units_total += row.completed_units; row.phase = "claimed"
			var station: Dictionary = g.definition("station_defs", "station_id", spec.station_id)
			var reputation: RefCounted = g.state.find("reputation_state", "faction_id", station.faction_id)
			if reputation != null: reputation.reputation += row.completed_units * int(spec.reputation_per_unit)
			g.specializations.operation_claimed(row)
			warning_changed.emit("行动成果已交付 · %d / %d · %d 信用点" % [row.completed_units, spec.target_units, credit])
	g.request_autosave()
	return true
func _spawn(row: D.OperationStateDto, spawn_id: String) -> void:
	var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", spawn_id)
	var stats: Dictionary = g.definition("npc_full_defs", "npc_id", spawn.npc_id)
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", spawn.anchor_id)
	var npc: D.NpcStateDto = D.NpcStateDto.new()
	npc.npc_instance_id = g.id("operation_structure"); npc.spawn_id = spawn_id; npc.sector_id = spawn.sector_id; npc.generation = row.generation; npc.alive = true
	npc.shield = stats.shield_max; npc.armor = stats.armor_max; npc.hull = stats.hull_max
	npc.pos_x = anchor.x_m; npc.pos_y = anchor.y_m; npc.pos_z = anchor.z_m
	g.state.add("npc_state", npc); g.assign_anchor_site("npc", npc.npc_instance_id, spawn.anchor_id)
func destroyed(npc: D.NpcStateDto) -> void:
	if not handles(npc.spawn_id): return
	var row: D.OperationStateDto = instance(structures[npc.spawn_id].operation_id)
	if row == null or row.phase != "active" or npc.generation != row.generation: return
	row.completed_units += 1
	warning_changed.emit("干扰装置已拆除 · %d / %d · 可以继续作战或带现有成果撤离" % [row.completed_units, definition(row.operation_id).target_units])
func _finish(row: D.OperationStateDto, reached_exit: bool) -> void:
	var spec: Dictionary = definition(row.operation_id)
	if spec.operation_kind == "breakthrough":
		row.completed_units = row.cargo_units if reached_exit else 0
		if not reached_exit: row.lost_units += row.cargo_units
	row.cargo_units = 0; row.has_payload_ship_id = false; row.payload_ship_id = ""
	row.exposure_remaining_s = 0.0; row.damage_debt_hp = 0.0; row.remaining_s = 0.0
	row.cooldown_remaining_s = float(spec.cooldown_s)
	row.phase = "ready" if row.completed_units > 0 else "failed" if reached_exit else "withdrawn"
	warning_changed.emit(("完整成功" if row.completed_units == int(spec.target_units) else "部分成功" if row.completed_units > 0 else "行动结束 · 无送达成果") + " · " + status_text(row.operation_id))
func boosted() -> void:
	if not supported(): return
	for row: D.OperationStateDto in g.state.rows("operation_state"):
		if row.phase != "active" or row.cargo_units <= 0 or row.payload_ship_id != g.state.ship().ship_instance_id: continue
		if row.exposure_remaining_s <= 0.0: warning_changed.emit("推进加速使突破物资暴露 · 暴露期间累计受击可损失货物，停用加速后逐步解除")
		row.exposure_remaining_s = float(definition(row.operation_id).exposure_duration_s)
func damaged(amount: float) -> void:
	if not supported() or amount <= 0.0: return
	for row: D.OperationStateDto in g.state.rows("operation_state"):
		if row.phase != "active" or row.cargo_units <= 0 or row.payload_ship_id != g.state.ship().ship_instance_id: continue
		if g.state.ship().hull <= 0.0: _finish(row, false); continue
		if row.exposure_remaining_s <= 0.0: continue
		var threshold: float = float(definition(row.operation_id).loss_damage_hp)
		row.damage_debt_hp += amount
		while row.damage_debt_hp >= threshold and row.cargo_units > 0:
			row.damage_debt_hp -= threshold; row.cargo_units -= 1; row.lost_units += 1
			warning_changed.emit("暴露货物受损 × 1 · 剩余 %d / %d" % [row.cargo_units, definition(row.operation_id).target_units])
		if row.cargo_units == 0: row.damage_debt_hp = 0.0
func detection_range() -> float:
	var radius: float = 0.0
	if supported():
		for row: D.OperationStateDto in g.state.rows("operation_state"):
			if row.phase == "active" and row.cargo_units > 0 and row.exposure_remaining_s > 0.0 and _site(row): radius = maxf(radius, float(definition(row.operation_id).exposure_detection_m))
	return radius
func thrust_ratio(ship_id: String) -> float:
	if not supported() or ship_id != g.state.ship().ship_instance_id: return 1.0
	var ratio: float = 1.0
	for npc: D.NpcStateDto in g.state.rows("npc_state"):
		if not npc.alive or not handles(npc.spawn_id): continue
		var spec: Dictionary = structures[npc.spawn_id]; var row: D.OperationStateDto = instance(spec.operation_id)
		if row.phase == "active" and row.generation == npc.generation and g.same_entity_site("ship",g.state.ship(),"npc",npc) and g.entity_distance("ship",g.state.ship(),"npc",npc) <= float(spec.field_radius_m): ratio = minf(ratio, float(spec.thrust_ratio))
	return ratio
func tick(delta: float) -> void:
	if not supported(): return
	for row: D.OperationStateDto in g.state.rows("operation_state"):
		row.cooldown_remaining_s = maxf(0.0, row.cooldown_remaining_s - delta)
		if row.phase != "active": continue
		if g.state.ship().status != T.ShipStatus.FLYING or not _site(row): _finish(row, false); continue
		row.remaining_s = maxf(0.0, row.remaining_s - delta)
		var previous: float = row.exposure_remaining_s
		row.exposure_remaining_s = maxf(0.0, row.exposure_remaining_s - delta)
		if previous > 0.0 and row.exposure_remaining_s == 0.0:
			row.damage_debt_hp = 0.0; warning_changed.emit("突破物资暴露已解除")
		if row.remaining_s == 0.0: _finish(row, false)
func status_text(id: String) -> String:
	var row: D.OperationStateDto = instance(id); var spec: Dictionary = definition(id)
	if row == null: return ""
	var state_label: String = str({"available":"可接取","accepted":"前往起点","active":"行动中","ready":"返回签发站交付","claimed":"已交付","failed":"未完成","withdrawn":"已撤回"}[row.phase])
	var progress: int = row.cargo_units if row.phase == "active" and spec.operation_kind == "breakthrough" else row.completed_units
	var field: float = thrust_ratio(g.state.ship().ship_instance_id) if row.phase == "active" and spec.operation_kind == "demolition" else 1.0
	return "%s · %s · %d / %d%s%s%s" % [spec.display_name,state_label,progress,spec.target_units," · 剩余 %.0f 秒" % row.remaining_s if row.phase == "active" else ""," · 货物暴露 %.1f 秒" % row.exposure_remaining_s if row.exposure_remaining_s > 0.0 else ""," · 装置干扰：推进 %.0f%%" % (field*100.0) if field < 1.0 else ""]
func focused() -> D.OperationStateDto:
	if not supported(): return null
	for phase: String in ["active","accepted","ready"]:
		for row: D.OperationStateDto in g.state.rows("operation_state"):
			if row.phase == phase: return row
	return null
func hud_text() -> String:
	var row: D.OperationStateDto = focused()
	if row == null: return ""
	var spec: Dictionary = definition(row.operation_id)
	var title: String = "物资突破" if spec.operation_kind == "breakthrough" else "拆除干扰源"
	if row.phase == "accepted": return title + " · 前往起点\n抵达后在行动页开始"
	if row.phase == "ready": return title + " · 成果%d/%d\n返回签发站交付" % [row.completed_units,spec.target_units]
	var first: String = "%s · %d/%d · %.0f秒" % [title,row.cargo_units if spec.operation_kind == "breakthrough" else row.completed_units,spec.target_units,row.remaining_s]
	if spec.operation_kind == "breakthrough": return first + ("\n货物暴露%.0f秒 · 损伤%.0f/%.0f" % [row.exposure_remaining_s,row.damage_debt_hp,spec.loss_damage_hp] if row.exposure_remaining_s > 0.0 else "\n未暴露 · 已损%d · 已抛%d" % [row.lost_units,row.jettisoned_units])
	var field: float = thrust_ratio(g.state.ship().ship_instance_id)
	return first + ("\n装置干扰 · 推进%.0f%%" % (field*100.0) if field < 1.0 else "\n可带已完成成果撤回")
func guidance(id: String) -> Dictionary:
	var row: D.OperationStateDto = instance(id); var spec: Dictionary = definition(id)
	if row == null: return {}
	if row.phase in ["available","ready","claimed","failed","withdrawn"]: return g.missions._route_location(g.missions._station_location(spec.station_id), "")
	var exit_point: bool = row.phase == "active"
	var anchor: String = spec.exit_anchor_id if exit_point else spec.entry_anchor_id
	return g.missions._route_location(g.missions._anchor_location(anchor,"operation:"+id+(":exit" if exit_point else ":entry"),"encounter","撤离点" if exit_point else "行动起点"), "")
func waypoints(sector_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not supported(): return result
	for spec: Dictionary in g.rows("operation_defs"):
		var row: D.OperationStateDto = instance(spec.operation_id)
		var entry: Dictionary = g.definition("anchor_defs","anchor_id",spec.entry_anchor_id)
		if entry.sector_id != sector_id or row.phase not in ["accepted","active"]: continue
		for exit_point: bool in [false, true]:
			if exit_point and row.phase != "active": continue
			result.append({"id":"operation:"+str(spec.operation_id)+(":exit" if exit_point else ":entry"),"title":("撤离点 · " if exit_point else "行动起点 · ")+str(spec.display_name),"kind":"encounter","anchor_id":spec.exit_anchor_id if exit_point else spec.entry_anchor_id,"remaining_count":0,"total_count":0,"respawn_remaining_s":0.0,"level":0,"mission_target":true,"reveal_range_m":float(spec.interaction_radius_m),"warp_arrival_m":float(spec.interaction_radius_m),"operation_id":spec.operation_id})
	return result
