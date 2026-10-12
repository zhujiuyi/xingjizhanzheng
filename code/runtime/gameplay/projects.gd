extends RefCounted
## Real station escrow, permanent stage progress, and current-owner benefits.
signal changed(message: String)
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
var g: RefCounted
func _init(game: RefCounted) -> void:g=game
func supported() -> bool:return g!=null and g.catalog.table_names.has("construction_project_defs")
func instance(id: String) -> RefCounted:return g.state.find("construction_state","project_id",id)
func definition(id: String) -> Dictionary:return g.definition("construction_project_defs","project_id",id)
func stage(id: String,index: int) -> Dictionary:
	for row: Dictionary in g.rows("construction_stage_defs"):
		if row.project_id==id and int(row.stage_index)==index:return row
	return {}
func owned(id: String) -> bool:
	var def: Dictionary=definition(id)
	return not def.is_empty() and not g.civilizations.allegiance().is_empty() and g.civilizations.owner(def.sector_id)==g.civilizations.allegiance()
func token(id: String) -> String:
	var row: RefCounted=instance(id)
	return str(row.revision) if row!=null else ""
func evidence(id: String) -> int:
	var count: int=0
	for row: RefCounted in g.state.rows("construction_evidence_state"):
		if row.project_id==id:count+=row.units
	return count
func inputs(id: String,index: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for def: Dictionary in g.rows("construction_input_defs"):
		if def.project_id==id and int(def.stage_index)==index:result.append(def)
	return result
func delivered(def: Dictionary) -> RefCounted:
	for row: RefCounted in g.state.rows("construction_input_state"):
		if row.project_id==def.project_id and row.stage_index==int(def.stage_index) and row.item_id==def.item_id and row.delivery_station_id==def.delivery_station_id:return row
	return null
func sources() -> Array[String]:
	var result: Array[String]=[g.inventory.warehouse(g.station())]
	var cargo: String=g.inventory.hold(g.state.ship(),T.ContainerKind.CARGO)
	var mineral: String=g.inventory.hold(g.state.ship(),T.ContainerKind.MINERAL)
	if not cargo.is_empty():result.append(cargo)
	if not mineral.is_empty():result.append(mineral)
	return result
func _input(id: String,item_id: String) -> Dictionary:
	var row: RefCounted=instance(id)
	if row==null:return {}
	for def: Dictionary in inputs(id,row.stage_index):
		if def.item_id==item_id and def.delivery_station_id==g.station():return def
	return {}
func reason(id: String,action: String,quantity: int=1,item_id: String="") -> String:
	var row: RefCounted=instance(id);var def: Dictionary=definition(id)
	if row==null or def.is_empty():return "工程不存在"
	if row.phase=="completed":return "工程已完成"
	if not g.unlocked(def.required_unlock_id):return "需先取得远域航路许可"
	if action in ["pause","resume"]:return "" if row.paused!=(action=="pause") else "工程状态已更新"
	if not owned(id):return "需效忠当前主权文明；失守时投入保留，收复后可继续"
	if row.paused:return "工程已暂停，先恢复施工"
	if g.state.ship().status!=T.ShipStatus.DOCKED:return "需实际停靠交付站或工程站"
	if action=="deliver":
		if row.phase!="gathering":return "本阶段已投入施工"
		var input: Dictionary=_input(id,item_id)
		if input.is_empty():return "当前站不接收本阶段的这项物资"
		var record: RefCounted=delivered(input)
		if record==null or quantity<=0 or quantity>int(input.required_units)-record.delivered_units:return "交付数量超出实际缺口"
		var available: int=0
		for source: String in sources():available+=g.inventory.count(source,item_id,true)
		return "" if available>=quantity else "本站仓库及当前舰普通自有物资不足"
	if action=="start":
		if row.phase!="gathering" or g.station()!=str(def.station_id):return "需在工程站开始当前阶段"
		for input: Dictionary in inputs(id,row.stage_index):
			if delivered(input)==null or delivered(input).delivered_units<int(input.required_units):return "各集货站仍有材料缺口"
		if row.stage_index==3 and evidence(id)<int(def.required_evidence_units):return "需要同星系探索的完整或部分成果"
		if g.state.player().credit<int(stage(id,row.stage_index).fee_credit):return "施工服务费不足"
		return ""
	return "未知工程动作"
func _receipt(id: String,action: String,item_id: String,units: int,fee: int) -> void:
	var row: RefCounted=instance(id);var r: RefCounted=D.ConstructionReceiptStateDto.new()
	r.receipt_id=g.id("construction");r.project_id=id;r.stage_index=row.stage_index;r.action_kind=action;r.station_id=g.station()
	r.has_item_id=not item_id.is_empty();r.item_id=item_id;r.units=units;r.paid_credit=fee;r.event_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("construction_receipt_state",r)
func execute(id: String,action: String,quantity: int,item_id: String,expected: String) -> bool:
	if expected!=token(id):return g.fail("工程阶段或材料余量已变化，请刷新")
	var blocked: String=reason(id,action,quantity,item_id)
	if not blocked.is_empty():return g.fail(blocked)
	var row: RefCounted=instance(id)
	if action in ["pause","resume"]:row.paused=action=="pause"
	elif action=="deliver":
		var remaining: int=quantity
		for source: String in sources():
			var take: int=mini(remaining,g.inventory.count(source,item_id,true))
			if take>0:g.inventory.consume(source,item_id,take,true);remaining-=take
		delivered(_input(id,item_id)).delivered_units+=quantity
		_receipt(id,"deliver",item_id,quantity,0)
	elif action=="start":
		var spec: Dictionary=stage(id,row.stage_index)
		g.state.player().credit-=int(spec.fee_credit);row.paid_credit_total+=int(spec.fee_credit)
		row.phase="working";row.work_remaining_s=float(spec.work_s);_receipt(id,"start","",0,int(spec.fee_credit))
	row.revision+=1;g.request_autosave();return true
func exploration_claimed(claim: RefCounted) -> void:
	if not supported():return
	var binding: Dictionary=g.definition("campaign_event_defs","event_id",claim.event_id)
	if binding.is_empty():return
	for row: RefCounted in g.state.rows("construction_evidence_state"):
		if row.project_id==binding.project_id and row.event_id==claim.event_id and row.generation==claim.generation:return
	var evidence_row: RefCounted=D.ConstructionEvidenceStateDto.new()
	evidence_row.project_id=binding.project_id;evidence_row.player_id=claim.player_id;evidence_row.event_id=claim.event_id;evidence_row.generation=claim.generation
	evidence_row.units=int(binding.full_units if claim.outcome=="full" else binding.partial_units)
	g.state.add("construction_evidence_state",evidence_row)
func factor(station_id: String,kind: String) -> float:
	if not supported():return 1.0
	var def: Dictionary=g.definition("construction_project_defs","station_id",station_id)
	if def.is_empty() or not owned(def.project_id):return 1.0
	var row: RefCounted=instance(def.project_id);var value: float=1.0
	if row==null:return value
	for spec: Dictionary in g.rows("construction_stage_defs"):
		if spec.project_id==def.project_id and spec.effect_kind==kind and (row.phase=="completed" or int(spec.stage_index)<row.stage_index):value*=float(spec.multiplier_bp)/10000.0
	return value
func tick(delta: float) -> void:
	if not supported():return
	for row: RefCounted in g.state.rows("construction_state"):
		if row.phase!="working" or row.paused or not owned(row.project_id):continue
		row.work_remaining_s=maxf(0.0,row.work_remaining_s-delta)
		if row.work_remaining_s>0.0:continue
		if row.stage_index==3:row.phase="completed";row.completed_tick=g.state.snapshot.meta.simulation_tick
		else:row.stage_index+=1;row.phase="gathering"
		row.revision+=1;changed.emit("工程阶段完成 · "+str(definition(row.project_id).display_name));g.request_autosave()
