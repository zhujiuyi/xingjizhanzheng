extends RefCounted
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var balance: Dictionary = {}
signal warning_changed(message: String)
func _init(game: RefCounted) -> void:
	g=game
	if supported():balance=g.rows("specialization_balance_defs")[0]
func supported() -> bool:return g!=null and g.catalog.table_names.has("weapon_tuning_defs")
func progress() -> D.SpecializationProgressStateDto:return g.state.find("specialization_progress_state","player_id",g.state.player().player_id)
func available() -> int:
	var row: RefCounted=progress()
	return row.earned_points-row.spent_points if row!=null else 0
func modifiers(ship: RefCounted) -> Dictionary:
	var result: Dictionary={"damage_ratio":1.0,"cycle_ratio":1.0,"range_ratio":1.0,"energy_ratio":1.0,"heat_ratio":1.0,"speed_ratio":1.0,"cone_ratio":1.0,"module_id":""}
	if not supported():return result
	for equipment: RefCounted in g.equipped(ship):
		if not equipment.enabled:continue
		var item: RefCounted=g.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
		if item==null or item.durability<=0.0:continue
		var tuning: Dictionary=g.definition("weapon_tuning_defs","module_id",equipment.module_def_id)
		if tuning.is_empty():continue
		for key: String in result:
			if key!="module_id":result[key]=1.0+(float(tuning[key])-1.0)*item.quality_multiplier
		result.module_id=equipment.module_def_id
		break
	return result
func weapon_spec(equipment: RefCounted,ship: RefCounted) -> Dictionary:
	var profile: Dictionary=g.weapon_profile(equipment.module_def_id)
	if profile.is_empty():return {}
	var spec: Dictionary=g.definition("module_defs","module_id",equipment.module_def_id).duplicate(true)
	spec.merge(profile,true)
	var weapon: Dictionary=g.definition("weapon_defs","module_id",equipment.module_def_id)
	var item: RefCounted=g.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
	spec["raw_damage"]=float(weapon.raw_damage)*(float(item.quality_multiplier) if item!=null else g.rule("standard_quality_multiplier"))
	spec["damage_type"]=str(weapon.damage_type);spec["ammo_item_id"]=weapon.ammo_item_id;spec["ammo_per_cycle"]=int(weapon.ammo_per_cycle)
	if profile.fire_mode=="drone":return spec
	var tuning: Dictionary=modifiers(ship)
	for pair: Array in [["raw_damage","damage_ratio"],["cycle_s","cycle_ratio"],["range_m","range_ratio"],["energy_eu","energy_ratio"],["heat_hu","heat_ratio"],["projectile_speed_mps","speed_ratio"],["fire_cone_half_angle_rad","cone_ratio"]]:spec[pair[0]]=float(spec[pair[0]])*float(tuning[pair[1]])
	return spec
func _award(kind: String,definition_id: String,generation: int,units: int,token: String) -> bool:
	if not supported() or units<=0 or g.state.find("specialization_evidence_state","source_token",token)!=null:return false
	var multiplier: int=int(balance.tactic_points if kind=="tactic" else balance.exploration_points if kind=="exploration" else balance.operation_points_per_unit)
	var row: D.SpecializationEvidenceStateDto=D.SpecializationEvidenceStateDto.new()
	row.player_id=g.state.player().player_id;row.source_token=token;row.source_kind=kind;row.source_def_id=definition_id;row.generation=generation;row.source_units=units;row.awarded_points=units*multiplier
	g.state.add("specialization_evidence_state",row);progress().earned_points+=row.awarded_points
	warning_changed.emit("取得火控分析证据 × %d · 可用 %d" % [row.awarded_points,available()])
	return true
func tactic_destroyed(npc: RefCounted) -> void:
	if not supported() or npc.alive or not g.tactics.handles(npc.spawn_id):return
	_award("tactic",npc.spawn_id,npc.generation,1,"tactic:"+npc.npc_instance_id)
func exploration_claimed(receipt: RefCounted) -> void:
	_award("exploration",receipt.event_id,receipt.generation,1,"exploration:"+receipt.event_id+":"+str(receipt.generation))
func operation_claimed(row: RefCounted) -> void:
	_award("operation",row.operation_id,row.generation,row.completed_units,"operation:"+row.operation_id+":"+str(row.generation))
func donate_reason(points: int) -> String:
	if not supported() or not g.allowed_service("manufacture"):return "需要停靠提供工业研究的空间站"
	if not g.unlocked(g.rows("specialization_research_defs")[0].required_unlock_id):return "需要远域航路许可"
	if points<=0 or points>int(balance.max_donation_points):return "分析批数超出单次范围"
	if g.state.player().credit<points*int(balance.donation_credit_per_point):return "分析服务费用不足"
	var warehouse: String=""
	for container: RefCounted in g.state.rows("container_state"):
		if container.kind==T.ContainerKind.STATION and container.station_id==g.station():warehouse=container.container_id;break
	if warehouse.is_empty():return "本站仓库尚未建立"
	if g.inventory.count(warehouse,balance.donation_item_id,true)<points*int(balance.donation_units_per_point):return "本站仓库普通自有结构料不足"
	return ""
func donate(points: int) -> bool:
	var reason: String=donate_reason(points)
	if not reason.is_empty():return g.fail(reason)
	var row: D.SpecializationEvidenceStateDto=D.SpecializationEvidenceStateDto.new()
	row.player_id=g.state.player().player_id;row.source_kind="donation";row.source_token=g.id("spec_donation");row.source_def_id=balance.donation_item_id;row.source_units=points;row.awarded_points=points
	row.material_units=points*int(balance.donation_units_per_point);row.paid_credit=points*int(balance.donation_credit_per_point)
	if not g.inventory.consume(g.inventory.warehouse(g.station()),balance.donation_item_id,row.material_units,true):return g.fail("分析材料已变化")
	g.state.player().credit-=row.paid_credit;progress().earned_points+=points;progress().donated_points+=points;g.state.add("specialization_evidence_state",row)
	warning_changed.emit("材料分析完成 · 分析证据 +%d" % points)
	return true
func description(module_id: String) -> String:
	if not supported():return ""
	var spec: Dictionary=g.definition("weapon_tuning_defs","module_id",module_id)
	if spec.is_empty():return ""
	return "火炮、激光与导弹火控；一舰限一项专精。伤害×%.2f，循环×%.2f，射程×%.2f，电容×%.2f，热量×%.2f，弹速×%.2f，射界×%.2f。无人机使用独立出击和通信规则。" % [spec.damage_ratio,spec.cycle_ratio,spec.range_ratio,spec.energy_ratio,spec.heat_ratio,spec.speed_ratio,spec.cone_ratio]
func research_reason(id: String,points: int) -> String:
	if not supported() or not g.allowed_service("manufacture"):return "需要停靠提供工业研究的空间站"
	var spec: Dictionary=g.definition("specialization_research_defs","research_id",id)
	if spec.is_empty() or not g.unlocked(spec.required_unlock_id):return "研究不存在或前置许可未解锁"
	if g.unlocked(spec.reward_unlock_id):return "该火控设计已解锁"
	var row: RefCounted=g.state.find("specialization_research_state","research_id",id)
	var remaining: int=int(spec.required_points)-(row.invested_points if row!=null else 0)
	if points<=0 or points>remaining or points>available():return "可用证据不足或投入超过剩余研究量"
	if g.state.player().credit<points*int(spec.credit_per_point):return "研究费用不足"
	return ""
func research(id: String,points: int,expected: String) -> bool:
	var row: D.SpecializationResearchStateDto=g.state.find("specialization_research_state","research_id",id)
	if expected!=str(row.invested_points if row!=null else 0):return g.fail("研究进度已变化，请重新查看")
	var reason: String=research_reason(id,points)
	if not reason.is_empty():return g.fail(reason)
	var spec: Dictionary=g.definition("specialization_research_defs","research_id",id)
	if row==null:
		row=D.SpecializationResearchStateDto.new();row.player_id=g.state.player().player_id;row.research_id=id;g.state.add("specialization_research_state",row)
	row.invested_points+=points;row.paid_credit+=points*int(spec.credit_per_point);progress().spent_points+=points;g.state.player().credit-=points*int(spec.credit_per_point)
	if row.invested_points==int(spec.required_points):row.completed=true;row.completed_tick=g.state.snapshot.meta.simulation_tick;g.grant_unlock(spec.reward_unlock_id)
	warning_changed.emit(("研究完成 · " if row.completed else "研究进度保存 · ")+str(spec.display_name)+" %d/%d" % [row.invested_points,spec.required_points])
	return true
