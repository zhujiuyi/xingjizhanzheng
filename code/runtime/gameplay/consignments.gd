extends RefCounted
## Entrusted goods occupy the real ordinary hold and shared payload mass.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
signal warning_changed(message: String)
func _init(game: RefCounted) -> void: g = game
func supported() -> bool: return g != null and g.catalog.table_names.has("consignment_defs")
static func initial_rows(catalog: XJCatalog) -> Array[D.ConsignmentStateDto]:
	var result: Array[D.ConsignmentStateDto] = []
	if catalog.table_names.has("consignment_defs"):
		for spec: Dictionary in catalog.rows("consignment_defs"):
			var row: D.ConsignmentStateDto = D.ConsignmentStateDto.new(); row.contract_id = spec.contract_id; result.append(row)
	return result
func instance(id: String) -> RefCounted: return g.state.find("consignment_state","contract_id",id)
func definition(id: String) -> Dictionary: return g.definition("consignment_defs","contract_id",id)
func cargo(ship_id: String) -> Dictionary:
	var mass: float = 0.0; var volume: float = 0.0
	if supported():
		for row: RefCounted in g.state.rows("consignment_state"):
			if not row.has_payload_ship_id or row.payload_ship_id != ship_id: continue
			var spec: Dictionary = definition(row.contract_id)
			mass += row.cargo_units * float(spec.unit_mass_kg); volume += row.cargo_units * float(spec.unit_volume_l)
	return {"mass":mass,"volume":volume}
func available(id: String) -> int:
	var spec: Dictionary = definition(id)
	if spec.is_empty(): return 0
	var m: Dictionary = g.metrics(g.state.ship())
	return maxi(0,mini(int(spec.max_units),mini(int(floor(maxf(0.0,m.cargo_capacity_l-m.cargo_used_l)/float(spec.unit_volume_l))),int(floor(maxf(0.0,m.max_payload_mass_kg-m.payload_mass_kg)/float(spec.unit_mass_kg))))))
func _route(id: String,quantity: int) -> Array[Dictionary]:
	var spec: Dictionary = definition(id)
	var destination: Dictionary = g.definition("station_defs","station_id",spec.destination_station_id)
	return g.missions._route(g.state.current_sector(),destination.sector_id,true,float(g.metrics(g.state.ship()).total_mass_kg)+quantity*float(spec.unit_mass_kg))
func travel_reserve(id: String,quantity: int) -> int:
	var amount: int = 0
	for endpoint: Dictionary in _route(id,quantity): amount += int(g.definition("effective_connection_defs","connection_id",endpoint.connection_id).fee_credit)
	return amount
func action_reason(id: String,action: String,quantity: int = 1) -> String:
	var row: RefCounted = instance(id); var spec: Dictionary = definition(id)
	if not supported() or row == null or spec.is_empty(): return "承运合同不存在"
	if action == "dispatch":
		if row.phase != "idle": return "此航线仍在执行或整备"
		if not g.unlocked(spec.required_unlock_id): return "取得完整星域航路许可后开放"
		if not g.state.player().has_docked_station_id or g.station() != spec.origin_station_id: return "前往签发站装载"
		if g.state.ship().policy_id != "normal_owned": return "承运需要普通自有舰船"
		if quantity < 1 or quantity > int(spec.max_units) or quantity > available(id): return "所选批数超出货舱或共享载荷余量"
		var destination: Dictionary = g.definition("station_defs","station_id",spec.destination_station_id)
		if g.state.current_sector() != destination.sector_id and _route(id,quantity).is_empty(): return "装载后没有已解锁且可通行的航路"
		if g.state.player().credit < int(spec.fee_credit)+quantity*int(spec.deposit_per_unit)+travel_reserve(id,quantity): return "信用点不足，需保留押金、手续费和航门通行费"
		return ""
	if action == "deliver":
		if row.phase != "active" or row.cargo_units <= 0: return "没有可交付的在途货物"
		if not row.has_payload_ship_id or row.payload_ship_id != g.state.ship().ship_instance_id: return "驾驶实际承运舰前往交付"
		return "" if g.state.player().has_docked_station_id and g.station() == spec.destination_station_id else "停靠目的站后交付"
	if action == "withdraw": return "" if row.phase == "active" else "没有可中止的在途合同"
	if action == "claim": return "" if row.phase == "ready" and g.state.player().has_docked_station_id else "成果待结算后，在空间站领取"
	return "未知承运操作"
func _receipt(row: RefCounted,kind: String,units: int,paid: int = 0,refunded: int = 0,reward: int = 0) -> D.ConsignmentReceiptStateDto:
	var receipt: D.ConsignmentReceiptStateDto = D.ConsignmentReceiptStateDto.new()
	receipt.receipt_id = g.id("freight"); receipt.contract_id = row.contract_id; receipt.generation = row.generation
	receipt.action_kind = kind; receipt.units = units; receipt.paid_credit = paid; receipt.refunded_credit = refunded; receipt.reward_credit = reward
	g.state.add("consignment_receipt_state",receipt)
	row.paid_credit_total += paid; row.refunded_credit_total += refunded; row.reward_credit_total += reward
	return receipt
func execute(id: String,action: String,quantity: int,expected_generation: String) -> bool:
	var row: RefCounted = instance(id)
	if row == null or str(row.generation) != expected_generation: return g.fail("承运合同已更新，请重新查看")
	var reason: String = action_reason(id,action,quantity)
	if not reason.is_empty(): return g.fail(reason)
	var spec: Dictionary = definition(id)
	match action:
		"dispatch":
			var paid: int = int(spec.fee_credit)+quantity*int(spec.deposit_per_unit)
			g.state.player().credit -= paid
			row.phase = "active"; row.accepted_units = quantity; row.cargo_units = quantity
			row.has_payload_ship_id = true; row.payload_ship_id = g.state.ship().ship_instance_id; row.remaining_s = spec.deadline_s
			_receipt(row,"dispatch",quantity,paid)
		"deliver":
			var units: int = row.cargo_units; row.delivered_units += units; row.cargo_units = 0
			_receipt(row,"deliver",units); _finish(row)
		"withdraw":
			var returned: bool = g.state.player().has_docked_station_id and g.station() == spec.origin_station_id and row.payload_ship_id == g.state.ship().ship_instance_id
			var units: int = row.cargo_units; row.cargo_units = 0
			if returned: row.returned_units += units; _receipt(row,"return",units)
			else: row.lost_units += units; _receipt(row,"loss",units)
			_finish(row)
		"claim":
			var refund: int = (row.delivered_units+row.returned_units)*int(spec.deposit_per_unit)
			var reward: int = row.delivered_units*int(spec.reward_per_unit)
			g.state.player().credit += refund+reward
			var receipt: RefCounted=_receipt(row,"claim",row.delivered_units,0,refund,reward)
			row.phase = "claimed"; row.cooldown_remaining_s = spec.cooldown_s
			g.honors.consignment_claimed(receipt)
	g.request_autosave()
	return true
func _finish(row: RefCounted) -> void:
	row.phase = "ready"; row.remaining_s = 0.0; row.exposure_remaining_s = 0.0; row.damage_debt_hp = 0.0
	row.has_payload_ship_id = false; row.payload_ship_id = ""
	warning_changed.emit("承运结束 · 送达%d / 损失%d / 退回%d" % [row.delivered_units,row.lost_units,row.returned_units])
func boosted() -> void:
	if not supported(): return
	for row: RefCounted in g.state.rows("consignment_state"):
		if row.phase == "active" and row.payload_ship_id == g.state.ship().ship_instance_id:
			row.exposure_remaining_s = g.rows("role_balance_defs")[0].freight_exposure_s
func on_damage(amount: float) -> void:
	if not supported() or amount <= 0.0: return
	var threshold: float = float(g.rows("role_balance_defs")[0].freight_loss_damage_hp)
	for row: RefCounted in g.state.rows("consignment_state"):
		if row.phase != "active" or row.payload_ship_id != g.state.ship().ship_instance_id or row.cargo_units <= 0: continue
		if g.state.ship().hull <= 0.0:
			var lost: int = row.cargo_units; row.cargo_units = 0; row.lost_units += lost; _receipt(row,"loss",lost); _finish(row); continue
		if row.exposure_remaining_s <= 0.0: continue
		row.damage_debt_hp += amount
		var lost: int = 0
		while row.damage_debt_hp >= threshold and row.cargo_units > 0:
			row.damage_debt_hp -= threshold; row.cargo_units -= 1; row.lost_units += 1; lost += 1
		if lost > 0: _receipt(row,"loss",lost); warning_changed.emit("暴露货物受损 × %d · 剩余 %d批" % [lost,row.cargo_units])
		if row.cargo_units == 0: _finish(row)
func tick(delta: float) -> void:
	if not supported(): return
	for row: RefCounted in g.state.rows("consignment_state"):
		if row.phase == "claimed":
			row.cooldown_remaining_s = maxf(0.0,row.cooldown_remaining_s-delta)
			if row.cooldown_remaining_s <= 0.0:
				row.phase = "idle"; row.generation += 1; row.accepted_units = 0; row.delivered_units = 0; row.lost_units = 0; row.returned_units = 0
		elif row.phase == "active":
			row.remaining_s = maxf(0.0,row.remaining_s-delta); row.exposure_remaining_s = maxf(0.0,row.exposure_remaining_s-delta)
			if row.exposure_remaining_s <= 0.0: row.damage_debt_hp = 0.0
			if row.remaining_s <= 0.0:
				var lost: int = row.cargo_units; row.cargo_units = 0; row.lost_units += lost; _receipt(row,"loss",lost); _finish(row)
func guidance(id: String) -> Dictionary:
	var row: RefCounted = instance(id); var spec: Dictionary = definition(id)
	if row == null or spec.is_empty(): return {}
	var station: Dictionary = g.definition("station_defs","station_id",spec.destination_station_id if row.phase == "active" else spec.origin_station_id)
	return g.missions._route_location(g.missions._anchor_location(station.station_anchor_id,station.station_id,"station",station.display_name),"")
func focused() -> RefCounted:
	if not supported():return null
	for row: RefCounted in g.state.rows("consignment_state"):
		if row.phase=="active" and row.payload_ship_id==g.state.ship().ship_instance_id:return row
	for row: RefCounted in g.state.rows("consignment_state"):
		if row.phase=="ready":return row
	return null
func hud_text(row: RefCounted) -> String:
	var spec: Dictionary=definition(row.contract_id)
	if row.phase=="ready":return "承运成果 · 送达%d / 损失%d批\n停靠空间站领取结算" % [row.delivered_units,row.lost_units]
	var station: Dictionary=g.definition("station_defs","station_id",spec.destination_station_id)
	return "承运 · 在途%d批 · 剩余%.0f秒\n目的站 · %s%s" % [row.cargo_units,row.remaining_s,station.display_name," · 货物暴露" if row.exposure_remaining_s>0.0 else ""]
