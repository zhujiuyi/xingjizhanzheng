extends VBoxContainer
## Live job and regional needs board. Timers update without replacing focused controls.
const D = preload("res://contracts/contract_dtos.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
const Interaction = preload("res://runtime/ui/ui_interaction.gd")
var u: Node
var mode: String = ""
var rows: Array[Dictionary] = []
var elapsed: float = 0.0
var signature: String = ""
var view_context: Dictionary = {}

func setup(ui: Node, panel_mode: String) -> void:
	u = ui; mode = panel_mode
	view_context = {"state": u.state, "world": u.state.world_id, "session": u.state.session_id, "epoch": u.state.epoch, "station": u.state.player().docked_station_id, "ship": u.state.ship().ship_instance_id, "generation": u.business_generation}
	add_theme_constant_override("separation", UISkin.SECTION_GAP)
	_build()

func _label(parent: Node, text: String, size: int = 14) -> Label:
	var label: Label = Label.new()
	label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", UISkin.MUTED if size <= 13 else UISkin.TEXT)
	parent.add_child(label)
	return label

func _signature() -> String:
	if mode == "jobs":
		var ids: PackedStringArray = []
		for job: D.IndustryJobStateDto in u.gameplay.industry.jobs(): ids.append(job.job_id)
		return "|".join(ids)
	var ids: PackedStringArray = []
	for row: Dictionary in u.gameplay.industry.demands(u.state.player().docked_station_id): ids.append(row.demand_id + ":" + str(row.state.generation))
	return "|".join(ids)

func _build() -> void:
	var view: Dictionary=u.capture_local_view(self)
	for child: Node in get_children(): remove_child(child); child.queue_free()
	rows.clear(); signature = _signature()
	if mode == "jobs":
		_label(self, "制造订单 · 全部空间站", UISkin.SIZE_SECTION)
		_label(self, "每站同时加工一份，订单与待领成品合计最多 %d 份。暂停与退出不推进；成品需回原站领取。" % int(u.gameplay.industry.balance.queue_limit), 13)
		var jobs: Array = u.gameplay.industry.jobs()
		if jobs.is_empty(): _label(self, "尚无订单。在下方配方行填写批数并提交生产。")
		for job: D.IndustryJobStateDto in jobs:
			var card: VBoxContainer = VBoxContainer.new(); add_child(card)
			var spec: Dictionary = u.catalog.one("industry_recipe_defs", "blueprint_id", job.blueprint_id)
			var output: String = u._item_name(str(u.catalog.one("recipe_defs", "recipe_id", spec.recipe_id).get("output_item_id", ""))) if spec.recipe_id != null else u._ship_name(str(u.catalog.one("hull_recipe_defs", "hull_recipe_id", spec.hull_recipe_id).get("ship_id", "")))
			_label(card, "%s · %s × %d 批" % [u._station_name(job.station_id), output, job.batches])
			var status: Label = _label(card, "")
			status.add_theme_color_override("font_color", UISkin.ICE)
			var actions: HFlowContainer = HFlowContainer.new(); card.add_child(actions)
			var claim: Button = u._button(actions, "领取成品", func(): _request("claim_industry", job.job_id))
			claim.name = "IndustryClaim_" + job.job_id
			var cancel: Button = u._button(actions, "取消订单", func(): _request("cancel_industry", job.job_id))
			cancel.name = "IndustryCancel_" + job.job_id
			UISkin.apply_button(cancel, "danger")
			cancel.tooltip_text = "等待开工：退还全部材料与服务费。已开工：材料按 %d%% 向下取整返还，服务费不退。" % int(u.gameplay.industry.balance.running_refund_bp / 100)
			rows.append({"job": job, "label": status, "claim": claim, "cancel": cancel})
	else:
		_label(self, "本站区域需求", UISkin.SIZE_SECTION)
		_label(self, "只交付本站仓库的普通自有材料；按实际交付数量支付信用点，完成全部缺额后获得声望与限时工业优惠。", 13)
		for row: Dictionary in u.gameplay.industry.demands(u.state.player().docked_station_id):
			var card: VBoxContainer = VBoxContainer.new(); add_child(card)
			_label(card, str(row.display_name) + " · " + u._item_name(row.item_id))
			_label(card, str(row.reason), 13)
			var status: Label = _label(card, "")
			status.add_theme_color_override("font_color", UISkin.ICE)
			var actions: HFlowContainer = HFlowContainer.new(); card.add_child(actions)
			var amount: SpinBox = SpinBox.new()
			amount.min_value = 1; amount.max_value = int(row.required_units); amount.step = 1; amount.value = 1
			amount.rounded = true
			amount.custom_minimum_size.x = 110; actions.add_child(amount)
			amount.name = "DemandQuantity_" + str(row.demand_id)
			var generation: String = str(row.state.generation)
			var deliver: Button = u._button(actions, "交付材料", func(): _deliver_request(str(row.demand_id), amount, generation))
			deliver.name = "DemandDeliver_" + str(row.demand_id)
			rows.append({"demand": row, "label": status, "amount": amount, "deliver": deliver})
			var source_item: String = row.item_id
			u._button(actions, "物资来源", func():
				if _current(): u.open_sources(source_item))
			Interaction.watch_integer(amount,_update)
		if rows.is_empty(): _label(self, "本站暂无工业材料需求。")
	_update();u.finish_local_rebuild(self,view)

func _process(delta: float) -> void:
	if not _current(): return
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0.0
	if signature != _signature(): _build()
	else: _update()

func _update() -> void:
	if not _current(): return
	for row: Dictionary in rows:
		if mode == "jobs":
			var job: D.IndustryJobStateDto = row.job
			var local: bool = job.station_id == u.state.player().docked_station_id
			row.label.text = "%s · 剩余 %.0f 秒 · 已付服务费 %d 信用点%s" % [str({"queued": "等待开工", "running": "生产中", "ready": "成品待领"}.get(job.status, job.status)), ceil(job.remaining_s), job.paid_credit, "" if local else " · 需回原站"]
			Interaction.action_state(row.claim,"需回原站领取成品。" if not local else "订单尚未完成。" if job.status!="ready" else "")
			Interaction.action_state(row.cancel,"需回原站取消订单。" if not local else "当前订单阶段不能取消。" if job.status not in ["queued","running"] else "","等待开工退还材料与服务费；已开工按 %d%% 返还材料，服务费不退。" % int(u.gameplay.industry.balance.running_refund_bp/100))
		else:
			var def: Dictionary = row.demand
			var state: D.StationDemandStateDto = def.state
			var stock: int = u.gameplay.inventory.count(u._warehouse_id(), def.item_id, true)
			row.label.text = "%s · 缺额 %d · 本站持有 %d · 每单位 %d 信用点\n%s %.0f 秒%s" % ["征集中" if state.status == "active" else "补给整理中", state.remaining_units, stock, int(def.unit_reward_credit), "本轮剩余" if state.status == "active" else "下一轮开放", ceil(state.phase_remaining_s), " · 工业优惠剩余 %.0f 秒" % ceil(state.benefit_remaining_s) if state.benefit_remaining_s > 0 else ""]
			var reason: String = u._service_reason("warehouse")
			var quantity: int = u._business_row_quantity({"amount": row.amount})
			if reason.is_empty():
				if state.status!="active" or state.phase_remaining_s<=0.0:reason="本轮征集已结束，等待下一轮开放。"
				elif quantity<=0:reason="请输入范围内的整数数量。"
				elif quantity>state.remaining_units:reason="所选数量超过本轮实际缺额。"
				elif quantity>stock:reason="本站仓库普通自有材料不足。"
			Interaction.action_state(row.deliver,reason,"交付实收 %d 信用点；本轮完成声望 +%d。" % [quantity*int(def.unit_reward_credit),int(def.reward_reputation)] if reason.is_empty() else "")

func _current() -> bool:
	if is_queued_for_deletion() or not is_inside_tree() or not is_instance_valid(u) or u.state == null or u.gameplay == null or u.page != "industry": return false
	if not is_instance_valid(u.body) or not u.body.is_ancestor_of(self) or u.business_generation != view_context.generation: return false
	return u.state == view_context.state and u.state.world_id == view_context.world and u.state.session_id == view_context.session and u.state.epoch == view_context.epoch and u.state.player().docked_station_id == view_context.station and u.state.ship().ship_instance_id == view_context.ship

func _deliver_request(demand_id: String, amount: SpinBox, generation: String) -> void:
	if not _current() or not is_instance_valid(amount): return
	var quantity: int = u._business_row_quantity({"amount": amount})
	if quantity <= 0: _update(); return
	amount.apply()
	_request("deliver_demand", demand_id, quantity, generation)

func _request(action: String, target: String, quantity: int = 1, extra: String = "") -> void:
	if not _current(): return
	if action == "deliver_demand":
		var demand: D.StationDemandStateDto = u.state.find("station_demand_state", "demand_id", target)
		if demand == null or extra != str(demand.generation) or demand.status != "active" or demand.phase_remaining_s <= 0.0: return
	else:
		var job: D.IndustryJobStateDto = u.state.find("industry_job_state", "job_id", target)
		if job == null or (action == "claim_industry" and job.status != "ready") or (action == "cancel_industry" and job.status not in ["queued", "running"]): return
	u._retain_business_quantities()
	u.requested.emit(action, target, quantity, extra)
