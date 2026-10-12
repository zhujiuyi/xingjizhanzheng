extends RefCounted
signal warning_changed(message: String)
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var balance: Dictionary = {}
var managed_spawns: Dictionary = {}
var managed_resources: Dictionary = {}
var announced: Dictionary = {}

func _init(game: RefCounted) -> void:
	g = game
	if not supported(): return
	balance = g.rows("exploration_balance_defs")[0]
	for row: Dictionary in g.rows("exploration_actor_defs"): managed_spawns[row.spawn_id] = row
	for row: Dictionary in g.rows("exploration_resource_defs"): managed_resources[row.node_id] = row

func supported() -> bool: return g != null and g.catalog.table_names.has("exploration_event_defs")

static func initial_instances(catalog: XJCatalog, seed: int) -> Array[D.ExplorationInstanceStateDto]:
	var result: Array[D.ExplorationInstanceStateDto] = []
	if not catalog.table_names.has("exploration_event_defs"): return result
	for definition: Dictionary in catalog.rows("exploration_event_defs"):
		var row: D.ExplorationInstanceStateDto = D.ExplorationInstanceStateDto.new()
		row.event_id = definition.event_id
		row.variant_seed = (str(seed) + ":" + row.event_id).sha256_text().substr(0, 8).hex_to_int()
		assign_variant(row, catalog)
		result.append(row)
	return result

static func assign_variant(row: D.ExplorationInstanceStateDto, catalog: XJCatalog) -> void:
	var variants: Array[Dictionary] = []
	for definition: Dictionary in catalog.rows("exploration_variant_defs"):
		if definition.event_id == row.event_id: variants.append(definition)
	variants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.variant_index) < int(b.variant_index))
	row.variant_id = variants[row.variant_seed % variants.size()].variant_id

func instance(event_id: String) -> D.ExplorationInstanceStateDto:
	return g.state.find("exploration_instance_state", "event_id", event_id)
func definition(event_id: String) -> Dictionary: return g.definition("exploration_event_defs", "event_id", event_id)
func variant(row: D.ExplorationInstanceStateDto) -> Dictionary: return g.definition("exploration_variant_defs", "variant_id", row.variant_id)
func actor_member(npc_id: String) -> D.ExplorationActorStateDto: return g.state.find("exploration_actor_state", "npc_instance_id", npc_id)
func friendly(npc_id: String) -> bool:
	var member: D.ExplorationActorStateDto = actor_member(npc_id)
	return member != null and member.actor_role == "escort"
func escort_hull(npc_id: String) -> String:
	var member: D.ExplorationActorStateDto = actor_member(npc_id)
	if member == null or member.actor_role != "escort": return ""
	var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", npc_id)
	return str(managed_spawns.get(npc.spawn_id, {}).get("hull_id", "")) if npc != null else ""

func perk(kind: String) -> float:
	if not supported(): return 1.0
	for row: D.ExplorationResearchStateDto in g.state.rows("exploration_research_state"):
		var project: Dictionary = g.definition("exploration_research_defs", "research_id", row.research_id)
		if project.perk_kind == kind and g.unlocked(project.reward_unlock_id): return float(project.multiplier)
	return 1.0

func _scan_range() -> float:
	var scan_range: float = g.rule("basic_scan_range_m")
	for equipment: D.EquipmentStateDto in g.equipped(g.state.ship()):
		if g.ship_roles.supported():
			var item: RefCounted = g.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
			if item == null or item.durability <= 0.0: continue
		if equipment.enabled and equipment.module_def_id.begins_with("module_scanner_"): scan_range = maxf(scan_range, float(g.definition("module_defs", "module_id", equipment.module_def_id).range_m))
	return scan_range

func _at(row: D.ExplorationInstanceStateDto, exit_point: bool = false) -> bool:
	if g.state.ship().status != T.ShipStatus.FLYING: return false
	var event: Dictionary = definition(row.event_id)
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", event.exit_anchor_id if exit_point else event.entry_anchor_id)
	if not g.same_anchor_site(g.state.ship(), anchor) or g.anchor_distance(g.state.ship(), anchor) > float(balance.extraction_radius_m if exit_point else event.operation_range_m): return false
	if not exit_point and g.spatial_validator.is_valid() and not g.spatial_validator.call(g.position(g.state.ship()), g.anchor_position(anchor), "explore:" + row.event_id): return false
	if row.operation_kind in ["survey", "deepen"]:
		if g.anchor_distance(g.state.ship(), anchor) > _scan_range(): return false
	return true

func _site(row: D.ExplorationInstanceStateDto) -> bool:
	return g.same_anchor_site(g.state.ship(), g.definition("anchor_defs", "anchor_id", definition(row.event_id).entry_anchor_id))

func action_reason(event_id: String, action: String) -> String:
	var row: D.ExplorationInstanceStateDto = instance(event_id)
	if row == null or not supported(): return "事件不存在"
	var event: Dictionary = definition(event_id)
	if not g.unlocked(event.required_unlock_id): return "完成新手教学并取得远域航路许可后开放"
	if action == "claim":
		if row.phase != "ready" or row.outcome not in ["full", "partial"]: return "尚无可交付的事件成果"
		if g.station() != event.station_id or g.state.ship().status != T.ShipStatus.DOCKED: return "请到 " + str(g.definition("station_defs", "station_id", event.station_id).display_name) + " 交付成果"
		return ""
	if row.phase in ["claimed", "failed", "withdrawn", "ready"]: return "事件已结束，等待交付或下次线索"
	if action == "extract":
		return "" if row.phase in ["relic", "mineral", "rescue", "surveyed"] else "先调查线索再决定撤离"
	if not _at(row): return "需在事件地点的操作范围内，保持飞行状态"
	if not row.operation_kind.is_empty(): return "操作已投入，返回范围内可继续；不能重复支付"
	if action in ["survey", "deepen"] and g.anchor_distance(g.state.ship(), g.definition("anchor_defs", "anchor_id", event.entry_anchor_id)) > _scan_range(): return "超出当前扫描距离，靠近线索或启用扫描设备"
	if action == "rescue":
		for member: D.ExplorationActorStateDto in g.state.rows("exploration_actor_state"):
			if member.event_id == event_id and member.actor_role == "escort":
				var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", member.npc_instance_id)
				if npc == null or not npc.alive: return "运输舰已毁，无法修复护送"
	if action == "survey": return "" if row.phase == "clue" else "此轮线索已调查"
	if action in ["rescue", "recover"]: return "" if event.event_kind == "rescue" and row.phase == "surveyed" else "此阶段不能选择救援方案"
	if action == "stabilize": return "" if event.event_kind == "relic" and row.phase in ["surveyed", "relic"] and not row.stabilized else "风险源已稳定或当前不能操作"
	if action == "deepen": return "" if event.event_kind == "relic" and row.phase in ["surveyed", "relic"] and row.evidence_units < int(variant(row).relic_layers) else "档案已全部取证或当前不能深入"
	if action in ["safe", "rich"]: return "" if event.event_kind == "mineral" and row.phase == "surveyed" else "当前不能选择矿带"
	return "未知探索动作"

func execute(event_id: String, action: String, generation: String) -> bool:
	var row: D.ExplorationInstanceStateDto = instance(event_id)
	if row == null or generation != str(row.generation): return g.fail("事件代次已变化，请重新查看线索")
	var reason: String = action_reason(event_id, action)
	if not reason.is_empty(): return g.fail(reason)
	if action == "claim": return _claim(row)
	if action == "extract":
		row.operation_kind = ""; row.operation_remaining_s = 0; row.phase = "extracting"
		return true
	if action in ["safe", "rich"]:
		row.choice_id = action; row.phase = "mineral"; row.elapsed_s = 0.0
		g.mobile_belts.begin(row)
		for node_id: String in managed_resources:
			var spec: Dictionary = managed_resources[node_id]
			if spec.event_id == event_id:
				var resource: D.ResourceStateDto = g.state.find("resource_state", "node_id", node_id)
				resource.remaining_units = int(variant(row).mineral_units) if spec.choice_id == action else 0; resource.respawn_remaining_s = 0.0
		_spawn_enemies(row)
		return true
	return _start_operation(row, action)

func _start_operation(row: D.ExplorationInstanceStateDto, action: String) -> bool:
	var spec: Dictionary = variant(row)
	var duration: float = float(spec.survey_duration_s if action == "survey" else spec.work_duration_s)
	var role_survey: bool = g.ship_roles.supported() and action in ["survey","deepen"]
	if role_survey: duration /= g.ship_roles.survey_rate()
	if action in ["rescue", "stabilize"]:
		var cargo: String = g.inventory.hold(g.state.ship(), T.ContainerKind.CARGO)
		if g.inventory.count(cargo, "material_structural_stock", true) < int(spec.repair_units): return g.fail("当前货舱缺少普通自有结构料 × %d" % int(spec.repair_units))
		if not g.inventory.consume(cargo, "material_structural_stock", int(spec.repair_units), true): return g.fail("结构料投入失败")
	else:
		var ratio: float = maxf(1.0, float(g.metrics(g.state.ship()).scan_strength) / float(g.definition("ship_defs", "ship_id", g.state.ship().ship_def_id).scan_strength))
		if role_survey: ratio = 1.0
		var energy: float = g.rule("basic_scan_energy_eu_s") * duration / ratio
		var heat: float = g.rule("basic_scan_heat_hu_s") * duration / ratio
		if g.state.ship().energy < energy or g.state.ship().overheated or g.state.ship().heat + heat > float(g.metrics(g.state.ship()).heat_max): return g.fail("电容不足或热量过高，无法支付调查周期")
		g.state.ship().energy -= energy; g.state.ship().heat += heat
	row.operation_kind = action; row.operation_remaining_s = duration
	if action=="survey":g.journal.begin("exploration",row.event_id+":"+str(row.generation))
	if action == "rescue": row.phase = "rescue"; row.choice_id = "rescue"; _spawn_enemies(row)
	elif action == "recover": row.choice_id = "recover"; _spawn_enemies(row)
	elif action in ["stabilize", "deepen"]: row.phase = "relic"; _spawn_enemies(row)
	return true

func _spawn(row: D.ExplorationInstanceStateDto, spec: Dictionary) -> void:
	for member: D.ExplorationActorStateDto in g.state.rows("exploration_actor_state"):
		if member.event_id != row.event_id or member.generation != row.generation: continue
		var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", member.npc_instance_id)
		if npc != null and npc.spawn_id == spec.spawn_id: return
	var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", spec.spawn_id)
	var stats: Dictionary = g.definition("npc_full_defs", "npc_id", spawn.npc_id)
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", spawn.anchor_id)
	var npc: D.NpcStateDto = D.NpcStateDto.new()
	npc.npc_instance_id = g.id("explore_actor"); npc.spawn_id = spawn.spawn_id; npc.sector_id = spawn.sector_id; npc.generation = row.generation; npc.alive = true
	npc.shield = stats.shield_max; npc.armor = stats.armor_max; npc.hull = float(stats.hull_max) * (float(balance.transport_initial_hull_ratio) if spec.actor_role == "escort" else 1.0)
	npc.pos_x = anchor.x_m; npc.pos_y = anchor.y_m; npc.pos_z = anchor.z_m
	g.state.add("npc_state", npc); g.assign_anchor_site("npc", npc.npc_instance_id, spawn.anchor_id)
	var member: D.ExplorationActorStateDto = D.ExplorationActorStateDto.new()
	member.npc_instance_id = npc.npc_instance_id; member.event_id = row.event_id; member.generation = row.generation; member.actor_role = spec.actor_role
	g.state.add("exploration_actor_state", member)
	g.tactics.register_existing(npc)

func _spawn_enemies(row: D.ExplorationInstanceStateDto) -> void:
	for spec: Dictionary in managed_spawns.values():
		if spec.event_id == row.event_id and spec.actor_role == "enemy" and int(spec.slot_index) < int(variant(row).enemy_count): _spawn(row, spec)

func _complete_operation(row: D.ExplorationInstanceStateDto) -> void:
	var action: String = row.operation_kind
	if action == "recover":
		var cargo: String = g.inventory.hold(g.state.ship(), T.ContainerKind.CARGO)
		var spec: Dictionary = variant(row)
		if g.inventory.room(cargo, spec.recovery_item_id, int(spec.recovery_units)) < int(spec.recovery_units):
			g.status_text = "货舱不足，回收已暂停；整理后可继续"; return
		g.inventory.grant(cargo, spec.recovery_item_id, int(spec.recovery_units))
		g.journal.source(spec.recovery_item_id,int(spec.recovery_units),"salvage")
		row.evidence_units = 1; row.phase = "extracting"
	elif action == "survey":
		row.phase = "surveyed"
		for spec: Dictionary in managed_spawns.values():
			if spec.event_id == row.event_id and spec.actor_role == "escort": _spawn(row, spec)
	elif action in ["rescue", "stabilize"]:
		row.stabilized = true
		if action == "rescue":
			for member: D.ExplorationActorStateDto in g.state.rows("exploration_actor_state"):
				if member.event_id == row.event_id and member.actor_role == "escort":
					var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", member.npc_instance_id)
					if npc != null and npc.alive:
						var stats: Dictionary = g.definition("npc_full_defs", "npc_id", g.definition("npc_spawn_defs", "spawn_id", npc.spawn_id).npc_id)
						npc.hull = stats.hull_max; npc.armor = stats.armor_max; npc.shield = stats.shield_max
	elif action == "deepen": row.evidence_units += 1
	row.operation_kind = ""; row.operation_remaining_s = 0.0
	g.request_autosave()

func resource_visible(node_id: String) -> bool:
	if not managed_resources.has(node_id): return true
	var spec: Dictionary = managed_resources[node_id]
	var row: D.ExplorationInstanceStateDto = instance(spec.event_id)
	return row != null and row.phase == "mineral" and row.choice_id == spec.choice_id

func on_collect(node_id: String, units: int) -> void:
	if not managed_resources.has(node_id): return
	var row: D.ExplorationInstanceStateDto = instance(managed_resources[node_id].event_id)
	if row != null and row.phase == "mineral": row.evidence_units += units

func mining_multiplier(node_id: String) -> float:
	return perk("mining") if managed_resources.has(node_id) else 1.0

func guidance(event_id: String) -> Dictionary:
	var row: D.ExplorationInstanceStateDto = instance(event_id)
	if row == null: return {}
	var event: Dictionary = definition(event_id)
	if row.phase == "ready":
		var station: Dictionary = g.definition("station_defs", "station_id", event.station_id)
		var location: Dictionary = g.missions._anchor_location(station.station_anchor_id, station.station_id, "station", station.display_name)
		location.required_page = "exploration"
		return g.missions._route_location(location, "")
	var exit_point: bool = row.phase == "extracting" or (row.phase == "rescue" and row.stabilized)
	var id: String = ("explore_exit:" if exit_point else "explore:") + event_id
	var location: Dictionary = g.missions._anchor_location(event.exit_anchor_id if exit_point else event.entry_anchor_id, id, "exploration_exit" if exit_point else "exploration", "撤离点 · " + str(event.display_name) if exit_point else str(event.display_name))
	return g.missions._route_location(location, "")

func status_text(event_id: String) -> String:
	var row: D.ExplorationInstanceStateDto = instance(event_id)
	if row == null: return ""
	var event: Dictionary = definition(event_id)
	var spec: Dictionary = variant(row)
	var text: String = str({"clue": "远距线索 · 到场调查", "surveyed": "已调查 · 选择行动", "rescue": "修复/护送运输舰", "relic": "遗迹取证", "mineral": "临时矿带活动中", "extracting": "带成果前往撤离点", "ready": "成果待交付", "claimed": "本轮已结算", "failed": "本轮失败", "withdrawn": "已撤回"}.get(row.phase, row.phase))
	if row.phase != "clue": text += " · " + str(spec.display_name)
	if row.phase in ["surveyed", "rescue", "relic", "mineral", "extracting"]: text += "\n窗口剩余 %.0f 秒 · 已取得证据/矿量 %d" % [ceil(maxf(0.0, float(spec.duration_s) - row.elapsed_s)), row.evidence_units]
	if not row.operation_kind.is_empty(): text += "\n%s · 剩余工作 %.1f 秒%s" % [str({"survey": "调查", "rescue": "修复", "recover": "回收", "stabilize": "稳定风险源", "deepen": "深入取证"}.get(row.operation_kind, row.operation_kind)), row.operation_remaining_s, " · 离开操作范围已暂停" if not _at(row) else ""]
	if event.environment_kind != "fragments" and _site(row): text += "\n" + str(environment().message)
	var belt: String = g.mobile_belts.detail(event_id)
	if not belt.is_empty(): text += "\n" + belt
	return text

func hazard_phase(row: D.ExplorationInstanceStateDto) -> String:
	var phase: float = fmod(row.hazard_clock_s, float(balance.hazard_period_s))
	if phase >= float(balance.hazard_period_s) - float(balance.hazard_active_s): return "active"
	if phase >= float(balance.hazard_period_s) - float(balance.hazard_active_s) - float(balance.hazard_warning_s): return "warning"
	return "quiet"

func environment() -> Dictionary:
	var result: Dictionary = {"scan": 1.0, "shield": 1.0, "message": ""}
	if not supported() or g.state.ship().status != T.ShipStatus.FLYING: return result
	for row: D.ExplorationInstanceStateDto in g.state.rows("exploration_instance_state"):
		if not _site(row): continue
		var event: Dictionary = definition(row.event_id)
		var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", event.entry_anchor_id)
		if g.anchor_distance(g.state.ship(), anchor) > float(balance.hazard_radius_m): continue
		if event.environment_kind == "em":
			result.scan = 1.0 if row.stabilized else float(balance.em_scan_multiplier)
			result.shield = 1.0 if row.stabilized else float(balance.em_shield_multiplier)
			result.message = "电磁扰动 · 扫描与护盾恢复受抑制" if not row.stabilized else "风险源已稳定"
		elif event.environment_kind == "solar": result.message = "恒星喷流 · " + str({"quiet": "等待窗口", "warning": "即将爆发，请避开中心", "active": "危险范围内持续热伤害"}[hazard_phase(row)])
	return result

func _finish(row: D.ExplorationInstanceStateDto, outcome: String, reason: String="completed") -> void:
	row.operation_kind = ""; row.operation_remaining_s = 0.0; row.outcome = outcome
	row.phase = "ready" if outcome in ["full", "partial"] else "failed"
	g.journal.finish("exploration",row.event_id+":"+str(row.generation),"completed" if outcome=="full" else outcome,reason if reason!="completed" else "completed" if outcome=="full" else "partial" if outcome=="partial" else "objective_failed")
	row.cooldown_remaining_s = definition(row.event_id).cooldown_s
	for node_id: String in managed_resources:
		if managed_resources[node_id].event_id == row.event_id:
			if g.work.mining_target == node_id: g.work.stop_mining()
			var resource: D.ResourceStateDto = g.state.find("resource_state", "node_id", node_id)
			resource.remaining_units = 0; resource.respawn_remaining_s = 0.0
	g.request_autosave()

func _clear_actors(row: D.ExplorationInstanceStateDto) -> void:
	for member: D.ExplorationActorStateDto in g.state.rows("exploration_actor_state").duplicate():
		if member.event_id != row.event_id: continue
		g.state.remove("exploration_actor_state", member)
		var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", member.npc_instance_id)
		if npc != null: g.remove_npc(npc)

func _claim(row: D.ExplorationInstanceStateDto) -> bool:
	for receipt: D.ExplorationClaimStateDto in g.state.rows("exploration_claim_state"):
		if receipt.event_id == row.event_id and receipt.generation == row.generation: return g.fail("本轮成果已结算")
	var spec: Dictionary = variant(row)
	var event: Dictionary = definition(row.event_id)
	var receipt: D.ExplorationClaimStateDto = D.ExplorationClaimStateDto.new()
	receipt.player_id = g.state.player().player_id; receipt.event_id = row.event_id; receipt.generation = row.generation; receipt.variant_id = row.variant_id; receipt.outcome = row.outcome
	receipt.credit_units = int(spec.full_credit if row.outcome == "full" else spec.partial_credit)
	var target: int = int(spec.mineral_quota if event.event_kind == "mineral" else spec.relic_layers)
	receipt.insight_units = int(spec.insight_units) if row.outcome == "full" else maxi(1, int(floor(float(spec.insight_units) * minf(1.0, float(row.evidence_units) / float(target)))))
	receipt.reputation_units = int(spec.reputation_units) if row.outcome == "full" else 0
	receipt.claimed_tick = g.state.snapshot.meta.simulation_tick
	var progress: D.ExplorationProgressStateDto = g.state.find("exploration_progress_state", "player_id", receipt.player_id)
	progress.insight_available += receipt.insight_units; progress.insight_earned += receipt.insight_units
	g.state.player().credit += receipt.credit_units
	var faction: String = g.definition("station_defs", "station_id", event.station_id).faction_id
	var rep: D.ReputationStateDto = g.state.find("reputation_state", "faction_id", faction)
	if rep != null: rep.reputation += receipt.reputation_units
	for need: Dictionary in g.rows("station_demand_defs"):
		if need.station_id != event.station_id: continue
		var demand: D.StationDemandStateDto = g.state.find("station_demand_state", "demand_id", need.demand_id)
		if demand.status == "cooldown": demand.status = "active"; demand.remaining_units = need.required_units; demand.generation += 1
		demand.phase_remaining_s = need.duration_s
		receipt.has_demand_id = true; receipt.demand_id = need.demand_id; receipt.demand_generation = demand.generation
		break
	g.state.add("exploration_claim_state", receipt); row.phase = "claimed"
	g.specializations.exploration_claimed(receipt)
	g.honors.exploration_claimed(receipt)
	g.projects.exploration_claimed(receipt)
	g.expeditions.exploration_claimed(receipt)
	g.telemetry.activity()
	return true

func research(research_id: String) -> bool:
	if not supported() or not g.allowed_service("manufacture"): return g.fail("请停靠有工业实验设施的空间站")
	var spec: Dictionary = g.definition("exploration_research_defs", "research_id", research_id)
	if spec.is_empty() or g.state.find("exploration_research_state", "research_id", research_id) != null: return g.fail("研究不存在或已完成")
	var progress: D.ExplorationProgressStateDto = g.state.find("exploration_progress_state", "player_id", g.state.player().player_id)
	if progress.insight_available < int(spec.required_insight) or g.state.player().credit < int(spec.required_credit): return g.fail("探索证据或研究费用不足")
	progress.insight_available -= int(spec.required_insight); g.state.player().credit -= int(spec.required_credit)
	g.grant_unlock(spec.reward_unlock_id)
	var receipt: D.ExplorationResearchStateDto = D.ExplorationResearchStateDto.new()
	receipt.player_id = g.state.player().player_id; receipt.research_id = research_id; receipt.spent_insight = spec.required_insight; receipt.paid_credit = spec.required_credit; receipt.completed_tick = g.state.snapshot.meta.simulation_tick
	g.state.add("exploration_research_state", receipt)
	return true

func tick(delta: float) -> void:
	if not supported() or delta <= 0.0: return
	for row: D.ExplorationInstanceStateDto in g.state.rows("exploration_instance_state"):
		var event: Dictionary = definition(row.event_id)
		var spec: Dictionary = variant(row)
		var local: bool = _site(row) and g.state.ship().status == T.ShipStatus.FLYING
		if local:
			row.hazard_clock_s = fmod(row.hazard_clock_s + delta, float(balance.hazard_period_s))
			var phase: String = hazard_phase(row)
			var token: String = row.event_id + ":" + str(row.generation)
			if event.environment_kind == "solar" and announced.get(token, "") != phase:
				announced[token] = phase
				if phase in ["warning", "active"]: warning_changed.emit("恒星喷流预警：离开事件中心 %d 米可避开；稳定风险源可减轻影响。" % int(balance.hazard_radius_m))
			if event.environment_kind == "solar" and phase == "active":
				var center: Dictionary = g.definition("anchor_defs", "anchor_id", event.entry_anchor_id)
				var damage: float = float(balance.solar_damage_hp_s) * delta * (float(balance.stabilized_multiplier) if row.stabilized else 1.0)
				if g.anchor_distance(g.state.ship(), center) <= float(balance.hazard_radius_m): g.damage_ship(Vector3(0, damage * perk("mitigation"), 0),"environment")
				for member: D.ExplorationActorStateDto in g.state.rows("exploration_actor_state"):
					if member.event_id != row.event_id: continue
					var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", member.npc_instance_id)
					if npc != null and npc.alive and g.position(npc).distance_to(g.anchor_position(center)) <= float(balance.hazard_radius_m): g.damage_npc(npc.npc_instance_id, Vector3(0, damage, 0))
		if row.phase in ["claimed", "failed", "withdrawn"]:
			row.cooldown_remaining_s = maxf(0, row.cooldown_remaining_s - delta)
			if not local: _clear_actors(row)
			if row.cooldown_remaining_s <= 0.0 and not local and g.mobile_belts.can_renew(row.event_id):
				row.generation += 1; row.variant_seed = (str(row.variant_seed) + ":" + str(row.generation)).sha256_text().substr(0, 8).hex_to_int()
				assign_variant(row, g.catalog); row.phase = "clue"; row.choice_id = ""; row.evidence_units = 0; row.elapsed_s = 0; row.stabilized = false; row.hazard_clock_s = 0; row.outcome = ""
				g.mobile_belts.renew(row)
			continue
		if row.phase == "ready":
			if not local: _clear_actors(row)
			continue
		if row.phase != "clue": row.elapsed_s += delta
		g.mobile_belts.tick(row, local)
		if g.state.ship().status == T.ShipStatus.DESTROYED and row.phase != "clue":
			_finish(row, "partial" if row.evidence_units > 0 else "failed","ship_destroyed"); continue
		if row.elapsed_s >= float(spec.duration_s):
			_finish(row, "partial" if row.evidence_units > 0 else "failed","timeout"); continue
		if not row.operation_kind.is_empty() and _at(row):
			var rate: float = perk("scan") * float(environment().scan) if row.operation_kind in ["survey", "deepen"] else 1.0
			row.operation_remaining_s = maxf(0.0, row.operation_remaining_s - delta * rate)
			if row.operation_remaining_s <= 0.0: _complete_operation(row)
		if row.phase == "rescue" and row.stabilized:
			for member: D.ExplorationActorStateDto in g.state.rows("exploration_actor_state"):
				if member.event_id != row.event_id or member.actor_role != "escort": continue
				var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", member.npc_instance_id)
				if npc == null or not npc.alive: _finish(row, "failed","target_lost"); break
				var exit_point: Dictionary = g.definition("anchor_defs", "anchor_id", event.exit_anchor_id)
				if local and g.position(npc).distance_to(g.anchor_position(exit_point)) <= float(balance.extraction_radius_m) and g.position(npc).distance_to(g.position(g.state.ship())) <= float(balance.escort_follow_m):
					row.evidence_units = int(spec.relic_layers); _finish(row, "full"); break
		if row.phase == "extracting" and _at(row, true):
			var target: int = int(spec.mineral_quota if event.event_kind == "mineral" else spec.relic_layers)
			_finish(row, "full" if row.evidence_units >= target else "partial" if row.evidence_units > 0 else "failed")
