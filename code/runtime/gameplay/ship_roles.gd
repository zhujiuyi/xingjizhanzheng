extends RefCounted
## Real capabilities of existing hulls. Definitions and paid channels live in SQL.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var balance: Dictionary = {}
var spatial_active: bool = true
signal warning_changed(message: String)

func _init(game: RefCounted) -> void:
	g = game
	if supported(): balance = g.rows("role_balance_defs")[0]
func supported() -> bool:
	return g != null and g.catalog.table_names.has("ship_role_capability_defs")
func capability(ship: RefCounted = null) -> Dictionary:
	return g.definition("ship_role_capability_defs","ship_id",(ship if ship != null else g.state.ship()).ship_def_id) if supported() else {}
func survey_rate(ship: RefCounted = null) -> float:
	if not supported(): return 1.0
	var hull: RefCounted = ship if ship != null else g.state.ship()
	return clampf(float(g.metrics(hull).scan_strength) * float(capability(hull).survey_multiplier) / float(balance.scan_reference_strength), float(balance.min_survey_rate), float(balance.max_survey_rate))
func sensor_multiplier() -> float:
	if not supported(): return 1.0
	for equipment: RefCounted in g.equipped(g.state.ship()):
		var item: RefCounted = g.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
		if equipment.enabled and equipment.module_def_id.begins_with("module_scanner_") and item != null and item.durability > 0.0: return float(capability().sensor_multiplier)
	return 1.0
func detection_range() -> float:
	return float(g.rule("target_marker_detection_range_m")) * sensor_multiplier()
func channel(item_id: String) -> RefCounted:
	return g.state.find("remote_support_state","item_instance_id",item_id)
func reserved(item_id: String) -> bool:
	return supported() and channel(item_id) != null
func support_range(equipment: RefCounted) -> float:
	return maxf(float(balance.remote_range_floor_m),float(g.definition("module_defs","module_id",equipment.module_def_id).range_m))*float(capability().remote_range_multiplier)
func target_limits(npc: RefCounted) -> Dictionary:
	var spawn: Dictionary = g.definition("npc_spawn_defs","spawn_id",npc.spawn_id)
	return g.definition("npc_full_defs","npc_id",spawn.npc_id)
func _equipment(item_id: String) -> RefCounted:
	var equipment: RefCounted = g.state.find("equipment_state","item_instance_id",item_id)
	return equipment if equipment != null and g.equipped(g.state.ship()).has(equipment) else null
func support_reason(item_id: String,target_id: String,check_full: bool = true) -> String:
	if not supported() or not bool(capability().remote_repair_allowed): return "当前舰型不支持远程维修"
	if not spatial_active or g.state.ship().status != T.ShipStatus.FLYING: return "需要在局部空间中出航作业"
	if g.state.ship().policy_id != "normal_owned": return "远程维修需要普通自有舰船"
	var equipment: RefCounted = _equipment(item_id)
	var item: RefCounted = g.state.find("item_instance_state","item_instance_id",item_id)
	if equipment == null or item == null or not equipment.enabled or item.durability <= 0.0 or item.policy_id != "normal_owned": return "维修设备不可用"
	var repair: Dictionary = g.definition("repair_defs","module_id",equipment.module_def_id)
	if repair.is_empty(): return "此设备不能维修"
	var npc: RefCounted = g.state.find("npc_state","npc_instance_id",target_id)
	if npc == null or not npc.alive or not g.civilizations.friendly(target_id): return "选择存活的友方舰船"
	if not g.same_entity_site("ship",g.state.ship(),"npc",npc): return "友舰不在同一局部空间"
	var range_m: float = support_range(equipment)
	if g.position(g.state.ship()).distance_to(g.position(npc)) > range_m: return "超出维修距离 · " + XJSpaceUnits.distance(range_m)
	if g.spatial_validator.is_valid() and not g.spatial_validator.call(g.position(g.state.ship()),g.position(npc),target_id): return "维修视线受阻"
	if check_full and float(npc.get(repair.layer_id)) >= float(target_limits(npc)[str(repair.layer_id)+"_max"]): return "目标" + ("护盾" if repair.layer_id == "shield" else "装甲") + "已满"
	return ""
func start_support(item_id: String,target_id: String) -> bool:
	var reason: String = support_reason(item_id,target_id)
	if not reason.is_empty(): return g.fail(reason)
	var equipment: RefCounted = _equipment(item_id)
	if equipment.cooldown_remaining_s > 0.0: return g.fail("维修设备仍在冷却")
	if channel(item_id) != null: return g.fail("先停止此设备的远程维修，再切换目标")
	var npc: RefCounted = g.state.find("npc_state","npc_instance_id",target_id)
	var row: D.RemoteSupportStateDto = D.RemoteSupportStateDto.new()
	row.item_instance_id = item_id; row.ship_instance_id = g.state.ship().ship_instance_id
	row.target_npc_id = target_id; row.target_generation = npc.generation
	row.layer_id = g.definition("repair_defs","module_id",equipment.module_def_id).layer_id
	g.state.add("remote_support_state",row)
	if not _pay(row): g.state.remove("remote_support_state",row); return false
	warning_changed.emit("远程维修 · " + ("护盾" if row.layer_id == "shield" else "装甲"))
	return true
func stop_support(item_id: String = "",quiet: bool = true) -> bool:
	var changed: bool = false
	for row: RefCounted in g.state.rows("remote_support_state").duplicate():
		if not item_id.is_empty() and row.item_instance_id != item_id: continue
		_clear_payment(row)
		g.state.remove("remote_support_state",row); changed = true
	if changed and not quiet: warning_changed.emit("远程维修已停止 · 已支付周期不退还")
	return changed
func _clear_payment(row: RefCounted) -> void:
	var equipment: RefCounted = g.state.find("equipment_state","item_instance_id",row.item_instance_id)
	if equipment != null: equipment.active_remaining_s = 0.0; equipment.cycle_paid = false
	row.phase = "armed"; row.remaining_s = 0.0; row.paid_restore = 0.0
func _pay(row: RefCounted) -> bool:
	var equipment: RefCounted = _equipment(row.item_instance_id)
	var repair: Dictionary = g.definition("repair_defs","module_id",equipment.module_def_id)
	var hold: String = g.inventory.hold(g.state.ship(),T.ContainerKind.CARGO)
	if repair.consumable_item_id != null and g.inventory.count(hold,repair.consumable_item_id,true) < int(repair.consumable_per_cycle): return g.fail("普通维修耗材不足")
	if not g.pay_cycle(equipment): return false
	if repair.consumable_item_id != null: g.inventory.consume(hold,repair.consumable_item_id,int(repair.consumable_per_cycle),true)
	var item: RefCounted = g.state.find("item_instance_state","item_instance_id",row.item_instance_id)
	row.phase = "cycling"; row.remaining_s = float(g.definition("module_defs","module_id",equipment.module_def_id).cycle_s)
	row.paid_restore = float(repair.restore_amount) * item.quality_multiplier * float(capability()["remote_"+str(repair.layer_id)+"_multiplier"])
	equipment.cycle_paid = true
	return true
func tick(delta: float) -> void:
	if not supported(): return
	for row: RefCounted in g.state.rows("remote_support_state").duplicate():
		var npc: RefCounted = g.state.find("npc_state","npc_instance_id",row.target_npc_id)
		var equipment: RefCounted = _equipment(row.item_instance_id)
		var item: RefCounted = g.state.find("item_instance_state","item_instance_id",row.item_instance_id)
		if not spatial_active or g.state.ship().ship_instance_id != row.ship_instance_id or g.state.ship().status != T.ShipStatus.FLYING or npc == null or not npc.alive or npc.generation != row.target_generation or not g.civilizations.friendly(row.target_npc_id) or equipment == null or not equipment.enabled or item == null or item.durability <= 0.0:
			stop_support(row.item_instance_id); continue
		var reason: String = support_reason(row.item_instance_id,row.target_npc_id,false)
		if not reason.is_empty():
			if row.phase == "cycling": _clear_payment(row); warning_changed.emit("维修中断 · " + reason)
			continue
		var maximum: float = float(target_limits(npc)[row.layer_id+"_max"])
		if row.phase == "armed":
			if float(npc.get(row.layer_id)) >= maximum or equipment.cooldown_remaining_s > 0.0: continue
			if not _pay(row): continue
		row.remaining_s = maxf(0.0,row.remaining_s-delta)
		equipment.active_remaining_s = row.remaining_s
		if row.remaining_s > 0.0: continue
		var before: float=float(npc.get(row.layer_id))
		npc.set(row.layer_id,minf(maximum,before+row.paid_restore))
		g.telemetry.repair("provided",float(npc.get(row.layer_id))-before)
		_clear_payment(row)
func options(target_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not supported() or not bool(capability().remote_repair_allowed): return result
	for equipment: RefCounted in g.equipped(g.state.ship()):
		var repair: Dictionary = g.definition("repair_defs","module_id",equipment.module_def_id)
		if repair.is_empty(): continue
		var row: RefCounted = channel(equipment.item_instance_id)
		result.append({"item_id":equipment.item_instance_id,"layer_id":repair.layer_id,"active":row != null,"remaining_s":row.remaining_s if row != null else 0.0,"target_id":row.target_npc_id if row != null else "","reason":support_reason(equipment.item_instance_id,target_id),"range_m":support_range(equipment)})
	return result
