extends RefCounted
## Frozen definitions own limits and costs. Offline world time advances escrowed jobs.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var balance: Dictionary = {}
func _init(gameplay: RefCounted) -> void:
	g = gameplay
	if g.catalog.table_names.has("industry_balance_defs"): balance = g.rows("industry_balance_defs")[0]

func supported() -> bool: return not balance.is_empty()

func jobs(station_id: String = "") -> Array[D.IndustryJobStateDto]:
	var result: Array[D.IndustryJobStateDto] = []
	for job: D.IndustryJobStateDto in g.state.rows("industry_job_state"):
		if job.player_id == g.state.player().player_id and (station_id.is_empty() or job.station_id == station_id) and job.status not in ["claimed", "cancelled"]: result.append(job)
	result.sort_custom(func(a: D.IndustryJobStateDto, b: D.IndustryJobStateDto) -> bool: return a.queue_sequence < b.queue_sequence)
	return result

func start_reason(blueprint_id: String, batches: int) -> String:
	if not supported(): return "当前世界使用即时制造规则"
	if not g.allowed_service("manufacture"): return g.last_error
	if batches < 1 or batches > int(balance.max_batches): return "每份订单限 1–%d 批" % int(balance.max_batches)
	if jobs(g.station()).size() >= int(balance.queue_limit): return "本站制造队列已满，请领取成品或取消订单"
	var spec: Dictionary = g.definition("industry_recipe_defs", "blueprint_id", blueprint_id)
	if spec.is_empty(): return "制造蓝图不存在"
	if spec.hull_recipe_id != null:
		var hull: Dictionary = g.definition("hull_recipe_defs", "hull_recipe_id", spec.hull_recipe_id)
		var reason: String = g.civilizations.hull_reason(hull.ship_id)
		if not reason.is_empty(): return reason
		if not g.unlocked(hull.required_unlock_id): return "舰体蓝图未掌握"
		if g.economy._ship_stock(hull.ship_id) == null: return "本站没有对应船坞"
	else:
		var available: bool = false
		for access: Dictionary in g.rows("recipe_access_defs"):
			if access.recipe_id == spec.recipe_id and access.station_id == g.station() and g.unlocked(access.required_unlock_id): available = true
		if not available: return "本站设施或蓝图尚不可用"
	if not g.economy._can_inputs(inputs(blueprint_id, batches)): return g.last_error
	if g.state.player().credit < g.economy.quote_manufacture(blueprint_id, batches): return "服务费不足"
	return ""

func inputs(blueprint_id: String, batches: int) -> Dictionary:
	var spec: Dictionary = g.definition("industry_recipe_defs", "blueprint_id", blueprint_id)
	if spec.is_empty(): return {}
	return g.economy._inputs("recipe_inputs", "recipe_id", spec.recipe_id, batches) if spec.recipe_id != null else g.economy._inputs("hull_recipe_inputs", "hull_recipe_id", spec.hull_recipe_id, batches)

func duration(blueprint_id: String, batches: int) -> float:
	var spec: Dictionary = g.definition("industry_recipe_defs", "blueprint_id", blueprint_id)
	return float(spec.get("duration_per_batch_s", 0.0)) * batches / g.economy.base_factor("industry")

func start(blueprint_id: String, batches: int) -> bool:
	var reason: String = start_reason(blueprint_id, batches)
	if not reason.is_empty(): return g.fail(reason)
	var materials: Dictionary = inputs(blueprint_id, batches)
	var job: D.IndustryJobStateDto = D.IndustryJobStateDto.new()
	job.job_id = g.id("industry")
	job.player_id = g.state.player().player_id; job.station_id = g.station(); job.blueprint_id = blueprint_id; job.batches = batches
	job.paid_credit = g.economy.quote_manufacture(blueprint_id, batches)
	job.duration_s = duration(blueprint_id, batches); job.remaining_s = job.duration_s
	job.created_tick = g.state.snapshot.meta.simulation_tick; job.queue_sequence = 1
	for existing: D.IndustryJobStateDto in g.state.rows("industry_job_state"): job.queue_sequence = maxi(job.queue_sequence, existing.queue_sequence + 1)
	g.economy._consume_inputs(materials); g.state.player().credit -= job.paid_credit
	g.state.add("industry_job_state", job)
	for item_id: String in materials:
		var escrow: D.IndustryInputStateDto = D.IndustryInputStateDto.new()
		escrow.job_id = job.job_id; escrow.item_id = item_id; escrow.quantity = materials[item_id]
		g.state.add("industry_input_state", escrow)
	_promote(job.station_id)
	return true

func _local_job(job_id: String) -> D.IndustryJobStateDto:
	var job: D.IndustryJobStateDto = g.state.find("industry_job_state", "job_id", job_id)
	if not supported() or job == null or job.player_id != g.state.player().player_id: g.fail("订单不存在或不属于当前玩家"); return null
	if not g.state.player().has_docked_station_id or job.station_id != g.station() or g.state.ship().status != T.ShipStatus.DOCKED: g.fail("请到订单所在空间站办理"); return null
	return job

func claim(job_id: String) -> bool:
	var job: D.IndustryJobStateDto = _local_job(job_id)
	if job == null: return false
	if job.status != "ready": return g.fail("订单尚未完成或已领取")
	var spec: Dictionary = g.definition("industry_recipe_defs", "blueprint_id", job.blueprint_id)
	if spec.hull_recipe_id != null:
		var hull: Dictionary = g.definition("hull_recipe_defs", "hull_recipe_id", spec.hull_recipe_id)
		for index: int in range(job.batches): g.inventory.create_ship(hull.ship_id, job.station_id)
	else:
		var recipe: Dictionary = g.definition("recipe_defs", "recipe_id", spec.recipe_id)
		var batch: D.ProductionStateDto = D.ProductionStateDto.new()
		batch.production_id = job.job_id; batch.player_id = job.player_id; batch.recipe_id = spec.recipe_id; batch.station_id = job.station_id; batch.batches = job.batches; batch.output_claimed = true
		g.state.add("production_state", batch)
		var count: int = int(recipe.output_quantity) * job.batches
		var ids: Array[String] = g.inventory.grant(g.inventory.warehouse(job.station_id), recipe.output_item_id, count, "normal_owned", "", "", T.ItemOrigin.MANUFACTURE, recipe.recipe_id)
		if not g.definition("module_defs", "module_id", recipe.output_item_id).is_empty():
			for id: String in ids:
				var item: D.ItemInstanceStateDto = g.state.find("item_instance_state", "item_instance_id", id)
				item.has_manufacture_batch_id = true; item.manufacture_batch_id = job.job_id
				for escrow: D.IndustryInputStateDto in g.state.rows("industry_input_state"):
					if escrow.job_id != job.job_id: continue
					var ledger: D.ManufactureInputStateDto = D.ManufactureInputStateDto.new()
					ledger.item_instance_id = id; ledger.input_item_id = escrow.item_id; ledger.input_quantity = int(escrow.quantity / count)
					g.state.add("manufacture_input_state", ledger)
	job.status = "claimed"
	return true

func cancel(job_id: String) -> bool:
	var job: D.IndustryJobStateDto = _local_job(job_id)
	if job == null: return false
	if job.status not in ["queued", "running"]: return g.fail("仅等待或生产中的订单可以取消")
	var bp: int = 10000 if job.status == "queued" else int(balance.running_refund_bp)
	for escrow: D.IndustryInputStateDto in g.state.rows("industry_input_state"):
		if escrow.job_id != job_id: continue
		var returned: int = int(floor(float(escrow.quantity) * bp / 10000.0))
		if returned > 0: g.inventory.grant(g.inventory.warehouse(job.station_id), escrow.item_id, returned)
	if job.status == "queued": g.state.player().credit += job.paid_credit
	job.status = "cancelled"; job.finished_tick = g.state.snapshot.meta.simulation_tick
	_promote(job.station_id)
	return true

func _promote(station_id: String) -> void:
	var waiting: Array[D.IndustryJobStateDto] = jobs(station_id)
	for job: D.IndustryJobStateDto in waiting:
		if job.status == "running": return
	for job: D.IndustryJobStateDto in waiting:
		if job.status == "queued": job.status = "running"; return

func discount(station_id: String) -> float:
	if not supported(): return 1.0
	for state: D.StationDemandStateDto in g.state.rows("station_demand_state"):
		if state.benefit_remaining_s <= 0: continue
		if g.definition("station_demand_defs", "demand_id", state.demand_id).station_id == station_id: return (1.0 - float(balance.demand_industry_discount_bp) / 10000.0)*g.frontier.station_factor(station_id,"industry")
	return g.frontier.station_factor(station_id,"industry")

func price_factor(item_id: String) -> float:
	if not supported(): return 1.0
	var stock: D.ShopStockStateDto = g.economy._stock(item_id)
	var spec: Dictionary = g.economy._stock_def(item_id)
	if stock == null or spec.is_empty() or int(spec.target_units) <= 0: return 1.0
	var pressure: float = 1.0 - float(stock.quantity) / float(spec.target_units)
	return clampf(1.0 + pressure * float(balance.pressure_bp) / 10000.0, float(balance.price_min_bp) / 10000.0, float(balance.price_max_bp) / 10000.0)

func demands(station_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not supported(): return result
	for state: D.StationDemandStateDto in g.state.rows("station_demand_state"):
		var spec: Dictionary = g.definition("station_demand_defs", "demand_id", state.demand_id)
		if not station_id.is_empty() and spec.station_id != station_id: continue
		var row: Dictionary = spec.duplicate()
		row.state = state
		result.append(row)
	return result

func deliver(demand_id: String, quantity: int, generation: String) -> bool:
	if not supported() or not g.allowed_service("warehouse"): return g.fail("请停靠到需求站点交付")
	var spec: Dictionary = g.definition("station_demand_defs", "demand_id", demand_id)
	var state: D.StationDemandStateDto = g.state.find("station_demand_state", "demand_id", demand_id)
	if spec.is_empty() or state == null or spec.station_id != g.station(): return g.fail("需求不在本站")
	if generation != str(state.generation) or state.status != "active" or state.phase_remaining_s <= 0: return g.fail("本轮需求已变化，请刷新报价")
	if quantity < 1 or quantity > state.remaining_units: return g.fail("交付数量超过本轮缺额")
	var warehouse: String = g.inventory.warehouse(g.station())
	if g.inventory.count(warehouse, spec.item_id, true) < quantity: return g.fail("本站仓库缺少普通自有物资")
	if not g.inventory.consume(warehouse, spec.item_id, quantity, true): return g.fail("交付扣料失败")
	state.remaining_units -= quantity
	g.state.player().credit += quantity * int(spec.unit_reward_credit)
	if state.remaining_units == 0:
		state.status = "cooldown"; state.phase_remaining_s = spec.cooldown_s; state.completed_cycles += 1
		state.benefit_remaining_s = balance.demand_benefit_duration_s
		var faction: String = g.definition("station_defs", "station_id", spec.station_id).faction_id
		var rep: D.ReputationStateDto = g.state.find("reputation_state", "faction_id", faction)
		if rep != null: rep.reputation += int(spec.reward_reputation)
	return true

func tick(delta: float) -> void:
	if not supported() or delta <= 0.0 or not is_finite(delta): return
	var station_ids: Dictionary = {}
	for job: D.IndustryJobStateDto in jobs(): station_ids[job.station_id] = true
	for station_id: String in station_ids:
		var budget: float = delta
		_promote(station_id)
		for job: D.IndustryJobStateDto in jobs(station_id):
			if job.status == "ready": continue
			if job.status == "queued": job.status = "running"
			var spent: float = minf(budget, job.remaining_s)
			job.remaining_s = maxf(0.0, job.remaining_s - spent); budget -= spent
			if job.remaining_s > 0.0: break
			job.status = "ready"; job.finished_tick = g.state.snapshot.meta.simulation_tick
			g.status_text = "制造完成，请到原站领取成品"
			g.request_autosave()
			if budget <= 0.0: break
		_promote(station_id)
	for state: D.StationDemandStateDto in g.state.rows("station_demand_state"):
		state.benefit_remaining_s = maxf(0.0, state.benefit_remaining_s - delta)
		var spec: Dictionary = g.definition("station_demand_defs", "demand_id", state.demand_id)
		var budget: float = delta
		while budget >= state.phase_remaining_s:
			budget -= state.phase_remaining_s
			if state.status == "active":
				state.status = "cooldown"; state.phase_remaining_s = spec.cooldown_s
			else:
				state.status = "active"; state.phase_remaining_s = spec.duration_s; state.remaining_units = spec.required_units; state.generation += 1
				var cycles: int = int(budget / (float(spec.duration_s) + float(spec.cooldown_s)))
				if cycles > 0: state.generation += cycles; budget -= cycles * (float(spec.duration_s) + float(spec.cooldown_s))
		state.phase_remaining_s -= budget
