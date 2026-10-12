extends RefCounted
## Staged routes consume real exploration receipts. No simulated victories.
signal changed(message: String)
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
var g: RefCounted
var balance: Dictionary={}
func _init(game: RefCounted) -> void:
	g=game
	if supported():balance=g.rows("campaign_balance_defs")[0]
func supported() -> bool:return g!=null and g.catalog.table_names.has("expedition_route_defs")
func director() -> RefCounted:return g.state.rows("campaign_director_state")[0] if supported() else null
func route(id: String) -> Dictionary:return g.definition("expedition_route_defs","route_id",id)
func active() -> RefCounted:
	for row: RefCounted in g.state.rows("expedition_run_state"):
		if row.phase in ["active","checkpoint","returning"]:return row
	return null
func instance(id: String) -> RefCounted:return g.state.find("expedition_run_state","run_id",id)
func stage(row: RefCounted) -> RefCounted:
	if row==null:return null
	for s: RefCounted in g.state.rows("expedition_stage_state"):
		if s.run_id==row.run_id and s.stage_index==row.stage_index:return s
	return null
func options(id: String,index: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for option: Dictionary in g.rows("expedition_option_defs"):
		if option.route_id==id and int(option.stage_index)==index:result.append(option)
	return result
func option(id: String,index: int,key: String) -> Dictionary:
	for choice: Dictionary in options(id,index):
		if choice.option_id==key:return choice
	return {}
func token(id: String) -> String:
	var row: RefCounted=instance(id)
	if row!=null:return "%s:%d:%s" % [row.phase,row.stage_index,str(row.withdraw_requested)]
	var state: RefCounted=g.state.find("expedition_route_state","route_id",id)
	return "%d:%d:%d:%s" % [director().generation,state.completed_runs,state.withdrawn_runs,str(state.cooldown_remaining_s>0)] if state!=null else ""
func _available(choice: Dictionary) -> String:
	if choice.is_empty():return "航线选项不存在"
	var event: RefCounted=g.exploration.instance(choice.event_id)
	if event==null:return "实际探索地点尚未准备"
	if event.phase!="clue":return "该地点已有活动或成果，先完成或等待下一轮线索"
	return ""
func reason(id: String,action: String,key: String="") -> String:
	if not supported():return "当前旧规则没有分段远征"
	var run: RefCounted=instance(id)
	if action=="start":
		var def: Dictionary=route(id);var cooldown: RefCounted=g.state.find("expedition_route_state","route_id",id)
		if def.is_empty() or cooldown==null:return "远征航线不存在"
		if active()!=null:return "已有正在进行的远征"
		if not g.unlocked(def.required_unlock_id):return "需先取得远域航路许可"
		if g.state.ship().status!=T.ShipStatus.DOCKED or g.station()!=str(def.origin_station_id):return "需到远征受领站准备出航"
		if cooldown.cooldown_remaining_s>0:return "该航线正在整备，可选择其他航线或参与工程"
		if g.state.player().credit<int(def.start_fee_credit):return "远征准备费不足"
		return _available(option(id,1,key))
	if run==null or run!=active():return "远征已经结束或不是当前远征"
	if action=="continue":
		if run.phase!="checkpoint" or run.stage_index>=3:return "需先到站结算当前段落"
		var current: RefCounted=stage(run)
		var event: Dictionary=g.exploration.definition(current.event_id)
		if g.state.ship().status!=T.ShipStatus.DOCKED or g.station()!=str(event.station_id):return "需在本段交付站选择继续深入"
		return _available(option(run.route_id,run.stage_index+1,key))
	if action=="withdraw":return "" if not run.withdraw_requested else "撤回指令已下达，前往撤离点或交付站"
	return "未知远征动作"
func _receipt(run: RefCounted,kind: String,paid: int=0,credit: int=0,insight: int=0) -> void:
	var receipt: RefCounted=D.ExpeditionReceiptStateDto.new()
	receipt.receipt_id=g.id("expedition_receipt");receipt.run_id=run.run_id;receipt.stage_index=run.stage_index;receipt.action_kind=kind
	receipt.paid_credit=paid;receipt.bonus_credit=credit;receipt.bonus_insight=insight;receipt.event_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("expedition_receipt_state",receipt)
func _choose(run: RefCounted,key: String) -> void:
	var choice: Dictionary=option(run.route_id,run.stage_index,key)
	var row: RefCounted=D.ExpeditionStageStateDto.new()
	row.run_id=run.run_id;row.stage_index=run.stage_index;row.option_id=key;row.event_id=choice.event_id
	row.event_generation=g.exploration.instance(choice.event_id).generation;g.state.add("expedition_stage_state",row)
	run.phase="active"
func execute(id: String,action: String,key: String,expected: String) -> bool:
	if expected!=token(id):return g.fail("航线轮换或远征阶段已变化，请刷新")
	var blocked: String=reason(id,action,key)
	if not blocked.is_empty():return g.fail(blocked)
	var run: RefCounted=instance(id)
	if action=="start":
		var def: Dictionary=route(id)
		run=D.ExpeditionRunStateDto.new();run.run_id=g.id("expedition");run.route_id=id;run.stage_index=1;run.phase="active"
		run.started_tick=g.state.snapshot.meta.simulation_tick;run.fee_paid_credit=int(def.start_fee_credit)
		run.focus_bonus_bp=int(balance.focus_bonus_bp) if director().focus_index==int(def.focus_index) else 10000
		g.state.player().credit-=run.fee_paid_credit;g.state.add("expedition_run_state",run);_choose(run,key);_receipt(run,"start",run.fee_paid_credit)
	elif action=="continue":run.stage_index+=1;_choose(run,key)
	else:
		run.withdraw_requested=true
		if run.phase=="checkpoint":_finish(run,"withdrawn")
		else:
			var current: RefCounted=stage(run);var event: RefCounted=g.exploration.instance(current.event_id)
			if event.phase in ["surveyed","rescue","relic","mineral"]:g.exploration.execute(event.event_id,"extract",str(event.generation))
			run.phase="returning"
			changed.emit("远征撤回 · 前往实际撤离点与交付站；已结算成果保留")
	g.request_autosave();return true
func exploration_claimed(claim: RefCounted) -> void:
	if not supported():return
	var run: RefCounted=active();var current: RefCounted=stage(run)
	if run==null or current==null or current.settled or current.event_id!=claim.event_id or current.event_generation!=claim.generation:return
	var choice: Dictionary=option(run.route_id,run.stage_index,current.option_id)
	var multiplier: float=float(run.focus_bonus_bp)/10000.0*(1.0 if claim.outcome=="full" else float(balance.partial_bonus_bp)/10000.0)
	current.outcome=claim.outcome;current.settled=true
	current.bonus_credit=int(floor(float(choice.bonus_credit)*multiplier));current.bonus_insight=int(floor(float(choice.bonus_insight)*multiplier))
	g.state.player().credit+=current.bonus_credit
	var progress: RefCounted=g.state.rows("exploration_progress_state")[0]
	progress.insight_available+=current.bonus_insight;progress.insight_earned+=current.bonus_insight
	run.bonus_credit_total+=current.bonus_credit;run.bonus_insight_total+=current.bonus_insight
	_receipt(run,"stage",0,current.bonus_credit,current.bonus_insight)
	if run.withdraw_requested:_finish(run,"withdrawn")
	elif run.stage_index==3:_finish(run,"completed")
	else:run.phase="checkpoint";changed.emit("本段成果已入账 · 可继续深入或结束远征")
func _finish(run: RefCounted,phase: String) -> void:
	if run.phase in ["completed","withdrawn","failed"]:return
	run.phase=phase;run.finished_tick=g.state.snapshot.meta.simulation_tick
	var route_state: RefCounted=g.state.find("expedition_route_state","route_id",run.route_id)
	route_state.cooldown_remaining_s=float(route(run.route_id).cooldown_s)
	if phase=="completed":route_state.completed_runs+=1
	elif phase=="withdrawn":route_state.withdrawn_runs+=1
	_receipt(run,{"completed":"complete","withdrawn":"withdraw","failed":"fail"}[phase])
	changed.emit("远征完成" if phase=="completed" else "远征已结束 · 已结算段落保留")
	g.request_autosave()
func guidance() -> Dictionary:
	var run: RefCounted=active();var current: RefCounted=stage(run)
	if run==null or current==null:return {}
	var event: RefCounted=g.exploration.instance(current.event_id)
	if run.phase=="checkpoint":
		return g.missions._route_location(g.missions._station_location(g.exploration.definition(current.event_id).station_id),"")
	if run.phase=="returning" and event.phase in ["clue","failed","withdrawn"]:
		return g.missions._route_location(g.missions._station_location(route(run.route_id).origin_station_id),"")
	return g.exploration.guidance(current.event_id)
func tick(delta: float) -> void:
	if not supported():return
	var d: RefCounted=director();d.remaining_s=maxf(0.0,d.remaining_s-delta)
	if d.remaining_s<=0.0:d.focus_index=(d.focus_index+1)%3;d.generation+=1;d.remaining_s=float(balance.director_period_s)
	for row: RefCounted in g.state.rows("expedition_route_state"):row.cooldown_remaining_s=maxf(0.0,row.cooldown_remaining_s-delta)
	var run: RefCounted=active()
	if run==null or run.phase=="checkpoint":return
	var current: RefCounted=stage(run);var event: RefCounted=g.exploration.instance(current.event_id)
	if g.state.ship().status==T.ShipStatus.DESTROYED or event==null or event.generation!=current.event_generation:_finish(run,"failed");return
	if run.phase=="returning" and event.phase in ["clue","failed","withdrawn"] and g.station()==str(route(run.route_id).origin_station_id):_finish(run,"withdrawn")
	elif run.phase=="active" and event.phase in ["failed","withdrawn"]:_finish(run,"failed")
