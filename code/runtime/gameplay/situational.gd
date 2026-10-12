extends RefCounted
## Local measurements are persisted; UI reads never discover or refresh distant data.
signal cue_started(cue: Dictionary)
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Space = preload("res://runtime/space_coordinates.gd")
const ResourceStatus = preload("res://runtime/resource_status.gd")
var g: RefCounted
var balance: Dictionary = {}
var spatial_active: bool = true
var _elapsed: float = 0.0
var _previous: Dictionary = {}
var _sound_remaining: float = 0.0

func _init(game: RefCounted) -> void:
	g = game
	if supported(): balance = g.rows("situational_balance_defs")[0]

func supported() -> bool:
	return g != null and g.catalog.table_names.has("situational_balance_defs")

func _tick() -> int: return g.state.snapshot.meta.simulation_tick
func age(tick: int) -> float: return maxf(0.0, float(_tick() - tick) / g.rule("simulation_hz"))

func _can_observe(node_id: String) -> bool:
	if not spatial_active or g.state.ship().status != T.ShipStatus.FLYING or not g.exploration.resource_visible(node_id): return false
	var location: Dictionary = g.definition("resource_node_locations", "node_id", node_id)
	if location.is_empty() or not g.unlocked(location.required_unlock_id): return false
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", location.anchor_id)
	if anchor.is_empty() or not g.same_anchor_site(g.state.ship(), anchor) or g.anchor_distance(g.state.ship(), anchor)>g.exploration._scan_range():return false
	return not g.spatial_validator.is_valid() or bool(g.spatial_validator.call(g.position(g.state.ship()),g.anchor_position(anchor),node_id))

func observe() -> void:
	if not supported(): return
	for node: Dictionary in g.rows("resource_node_defs"):
		if not _can_observe(node.node_id): continue
		var live: RefCounted = g.state.find("resource_state", "node_id", node.node_id)
		var row: RefCounted = g.state.find("resource_intel_state", "node_id", node.node_id)
		if row == null:
			row = D.ResourceIntelStateDto.new(); row.node_id = node.node_id; g.state.add("resource_intel_state", row)
		row.sector_id = node.sector_id; row.site_id = Space.current_site(g.state); row.observed_tick = _tick()
		row.remaining_units = live.remaining_units; row.respawn_remaining_s = live.respawn_remaining_s
	if g.state.ship().status != T.ShipStatus.DOCKED: return
	for spec: Dictionary in g.rows("station_demand_defs"):
		if spec.station_id != g.station(): continue
		var live: RefCounted = g.state.find("station_demand_state", "demand_id", spec.demand_id)
		if live == null: continue
		var row: RefCounted = g.state.find("demand_intel_state", "demand_id", spec.demand_id)
		if row == null:
			row = D.DemandIntelStateDto.new(); row.demand_id = spec.demand_id; g.state.add("demand_intel_state", row)
		row.observed_tick = _tick(); row.generation = live.generation; row.phase = live.status
		row.remaining_units = live.remaining_units; row.phase_remaining_s = live.phase_remaining_s; row.unit_credit = spec.unit_reward_credit

func resource_reading(node_id: String) -> Dictionary:
	if not supported(): return {}
	if _can_observe(node_id):
		var result: Dictionary = ResourceStatus.inspect(g.state, g.catalog, node_id)
		result.merge({"known":true, "live":true, "age_s":0.0, "fresh":true}, true)
		return result
	var row: RefCounted = g.state.find("resource_intel_state", "node_id", node_id)
	if row == null: return {"known":false, "live":false}
	var node: Dictionary = g.definition("resource_node_defs", "node_id", node_id)
	return {"known":true,"live":false,"available":true,"remaining_units":row.remaining_units,"capacity_units":node.capacity_units,
		"observed_tick":row.observed_tick,"site_id":row.site_id,"age_s":age(row.observed_tick),"fresh":age(row.observed_tick)<=float(balance.resource_fresh_s)}

func resource_text(node_id: String) -> String:
	var info: Dictionary = resource_reading(node_id)
	if not bool(info.get("known",false)): return "未测量 · 到矿点附近更新"
	if info.live: return ResourceStatus.summary(info) + " · 现场测量"
	return "上次 %d 单位 · %s前 · %s" % [info.remaining_units,ResourceStatus.countdown(info.age_s),"参考" if info.fresh else "已过期，需复测"]

func demand_reading(demand_id: String) -> Dictionary:
	if not supported(): return {}
	var spec: Dictionary = g.definition("station_demand_defs","demand_id",demand_id)
	if spec.is_empty(): return {}
	var live: bool = g.state.ship().status == T.ShipStatus.DOCKED and g.station() == str(spec.station_id)
	var row: RefCounted = g.state.find("station_demand_state" if live else "demand_intel_state","demand_id",demand_id)
	if row == null: return {"known":false,"live":false}
	var elapsed: float = 0.0 if live else age(row.observed_tick)
	return {"known":true,"live":live,"generation":row.generation,"phase":row.status if live else row.phase,
		"remaining_units":row.remaining_units,"phase_remaining_s":maxf(0.0,row.phase_remaining_s-elapsed),
		"age_s":elapsed,"fresh":live or elapsed<=float(balance.demand_fresh_s),"unit_credit":spec.unit_reward_credit if live else row.unit_credit}

func demand_text(demand_id: String) -> String:
	var info: Dictionary = demand_reading(demand_id)
	if not bool(info.get("known",false)): return "未核实 · 到站更新需求"
	var stamp: String = "本站报价" if info.live else "%s前 · %s" % [ResourceStatus.countdown(info.age_s),"参考" if info.fresh and info.phase_remaining_s>0 else "已过期，到站核实"]
	if info.phase != "active": return "上次需求已结算 · " + stamp
	return "缺 %d 份 · %d信用点/份 · %s · %s" % [info.remaining_units,info.unit_credit,ResourceStatus.countdown(info.phase_remaining_s),stamp]

func equipment(kind: String, node_id: String = "") -> Dictionary:
	var result: Dictionary = {"missing":"", "page":"fitting", "note":""}
	if kind not in ["collect","mineral","destroy_spawn","scan_signal","survey"]: return result
	var usable: bool = false
	var disabled: bool = false
	var empty_bay: bool = false
	var target_node: Dictionary=g.definition("resource_node_defs","node_id",node_id)
	if kind in ["collect","mineral"] and not target_node.is_empty() and g.definition("item_defs","item_id",target_node.item_id).get("item_type","")!="ore":
		result.note="近距离回收 · 无需矿头";return result
	for e: RefCounted in g.equipped(g.state.ship()):
		var item: RefCounted = g.state.find("item_instance_state","item_instance_id",e.item_instance_id)
		if item == null or item.durability <= 0.0: continue
		var compatible: bool = false
		if kind in ["collect","mineral"]:
			var node: Dictionary = g.definition("resource_node_defs","node_id",node_id)
			for match_row: Dictionary in g.rows("mining_compatibility"):
				if match_row.module_id == e.module_def_id and (node.is_empty() or match_row.item_id == node.item_id): compatible = true
		elif kind == "destroy_spawn":
			compatible = not g.definition("weapon_defs","module_id",e.module_def_id).is_empty()
			if not g.definition("drone_defs","module_id",e.module_def_id).is_empty():
				var bay: RefCounted=g.drone_control.bay(e.item_instance_id)
				if bay!=null and bay.stock_units>0: compatible=true
				else: compatible=false;empty_bay=true
		else: compatible = e.module_def_id.begins_with("module_scanner_")
		if compatible:
			usable = usable or e.enabled; disabled = disabled or not e.enabled
	if kind in ["scan_signal","survey"]:
		result.note = "扫描设备已启用" if usable else "基础扫描可用 · 靠近目标"
	elif not usable:
		var title: String = "兼容采集头" if kind in ["collect","mineral"] else "武器或无人机舱"
		result.missing = ("需启用 " if disabled else "缺少 ") + title
		if empty_bay and not disabled: result.missing="无人机储备不足 · 到站补充或装载武器"
		result.note = result.missing
	return result

func mission_equipment(info: Dictionary) -> Dictionary:
	return equipment(str(info.get("objective_kind","")),str(info.get("target_id","")))

func exploration_equipment(event_id: String) -> Dictionary:
	var row: RefCounted=g.exploration.instance(event_id)
	if row==null: return {"missing":"","note":""}
	if row.phase=="mineral":
		for node_id: String in g.exploration.managed_resources:
			var spec: Dictionary=g.exploration.managed_resources[node_id]
			if spec.event_id==event_id and spec.choice_id==row.choice_id: return equipment("mineral",node_id)
	return equipment("survey") if row.phase=="clue" else {"missing":"","note":""}

func _cue(id: String, subject: String, detail: String) -> Dictionary:
	var result: Dictionary = g.definition("situational_cue_defs","cue_id",id).duplicate()
	result["key"] = id + ":" + subject; result["detail"] = detail
	return result

func cues() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not supported() or not spatial_active or g.state.ship().status != T.ShipStatus.FLYING: return result
	for row: RefCounted in g.state.rows("npc_tactic_state"):
		var npc: RefCounted = g.state.find("npc_state","npc_instance_id",row.npc_instance_id)
		if row.phase != "charging" or npc == null or not npc.alive or not g.same_entity_site("npc",npc,"ship",g.state.ship()): continue
		var spec: Dictionary = g.tactics.definition(row.npc_instance_id)
		var counter: String = {"siege":"横移 / 遮挡 / 命中打断","interceptor":"拉开距离 / 压制来源","carrier":"压制母舰 / 拦截无人机","support":"优先压制支援舰"}.get(spec.tactic_kind,"")
		result.append(_cue("charge",row.npc_instance_id,"%s · %.1fs · %s" % [spec.display_name,row.remaining_s,counter]))
	for row: RefCounted in g.state.rows("ship_tactical_effect_state"):
		if row.ship_instance_id == g.state.ship().ship_instance_id and row.jam_remaining_s>0:
			result.append(_cue("jam",row.ship_instance_id,"%.1fs · 转向保留，压制来源解除" % row.jam_remaining_s))
	var disconnected: int = 0
	for row: RefCounted in g.drone_control.live.values():
		if row.owner_id == g.state.ship().ship_instance_id and row.communication_lost: disconnected += 1
	if disconnected>0: result.append(_cue("drone_link",g.state.ship().ship_instance_id,"%d架 · 正在自主返航" % disconnected))
	var hired: RefCounted = g.hired.active()
	if hired != null and hired.phase in ["deployed","retreating"]:
		var npc: RefCounted = g.state.find("npc_state","npc_instance_id",hired.npc_instance_id)
		if npc != null and (not g.same_entity_site("npc",npc,"ship",g.state.ship()) or g.position(npc).distance_to(g.position(g.state.ship()))>float(g.hired.balance.communication_m)):
			result.append(_cue("hire_link",hired.contract_id,"先接近僚舰归队 · 远程指令不可用"))
		elif hired.support_cooldown_s>0: result.append(_cue("support",hired.contract_id,"后勤维修冷却 %.1fs · 储备 %d 次" % [hired.support_cooldown_s,hired.support_cycles_remaining]))
	for row: RefCounted in g.state.rows("remote_support_state"):
		if row.ship_instance_id == g.state.ship().ship_instance_id and row.phase == "cycling": result.append(_cue("support",row.item_instance_id,"付费周期 %.1fs · 需保持距离与视线" % row.remaining_s))
	for table: String in ["operation_state","consignment_state"]:
		for row: RefCounted in g.state.rows(table):
			if row.phase == "active" and row.has_payload_ship_id and row.payload_ship_id==g.state.ship().ship_instance_id and row.exposure_remaining_s>0: result.append(_cue("cargo",table,"%.1fs · 有货损风险，停止增推减轻暴露" % row.exposure_remaining_s))
	for row: RefCounted in g.state.rows("exploration_instance_state"):
		if not g.exploration._site(row): continue
		if row.phase == "extracting": result.append(_cue("extraction",row.event_id,"前往撤离点 · 成果尚未交付"))
		var event: Dictionary = g.exploration.definition(row.event_id)
		if row.phase in ["surveyed","rescue","relic","mineral","extracting"]:
			var remaining: float = maxf(0.0,float(g.exploration.variant(row).duration_s)-row.elapsed_s)
			if remaining<=float(balance.extraction_warning_s): result.append(_cue("extraction",row.event_id+":deadline","窗口 %s · 可提前撤回保留部分成果" % ResourceStatus.countdown(remaining)))
	var environment: Dictionary = g.exploration.environment()
	var hazardous: bool=float(environment.scan)<1.0 or float(environment.shield)<1.0
	for row: RefCounted in g.state.rows("exploration_instance_state"):
		if not g.exploration._site(row) or row.phase not in ["surveyed","rescue","relic","mineral","extracting"]:continue
		var def: Dictionary=g.exploration.definition(row.event_id)
		if def.environment_kind=="solar" and g.exploration.hazard_phase(row) in ["warning","active"] and g.anchor_distance(g.state.ship(),g.definition("anchor_defs","anchor_id",def.entry_anchor_id))<=float(g.exploration.balance.hazard_radius_m):hazardous=true
	if hazardous: result.append(_cue("environment",Space.current_site(g.state),environment.message))
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.priority>b.priority if a.priority!=b.priority else str(a.key)<str(b.key))
	return result

func tick(delta: float) -> void:
	if not supported(): return
	_elapsed += delta; _sound_remaining = maxf(0.0,_sound_remaining-delta)
	if _elapsed >= float(balance.observation_interval_s): _elapsed = 0.0; observe()
	var list: Array[Dictionary] = cues()
	var current: Dictionary = {}
	for cue: Dictionary in list: current[cue.key] = cue
	if _sound_remaining<=0.0:
		for cue: Dictionary in list:
			if not _previous.has(cue.key):
				cue_started.emit(cue); _sound_remaining=float(balance.cue_sound_cooldown_s); break
	_previous=current
