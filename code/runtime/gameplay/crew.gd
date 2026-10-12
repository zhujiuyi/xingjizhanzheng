extends RefCounted
## Finite crew careers. All rates, costs and effects use frozen definitions.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
var g: RefCounted
var balance: Dictionary={}
signal changed(message: String)

func _init(host: RefCounted) -> void:
	g=host
	if supported():balance=g.rows("fleet_balance_defs")[0]
func supported() -> bool:return g!=null and g.catalog.table_names.has("crew_profile_defs")
func member(id: String) -> RefCounted:return g.state.find("crew_member_state","profile_id",id) if supported() else null
func profile(id: String) -> Dictionary:return g.definition("crew_profile_defs","profile_id",id) if supported() else {}
func profession(id: String) -> Dictionary:
	var p: Dictionary=profile(id)
	return g.definition("crew_profession_defs","profession_id",p.profession_id) if not p.is_empty() else {}
func assignment(id: String) -> RefCounted:return g.state.find("crew_assignment_state","profile_id",id) if supported() else null
func rank_for(row: RefCounted) -> Dictionary:
	var selected: Dictionary={};var job: Dictionary=profession(row.profile_id)
	for rank: Dictionary in g.rows("crew_rank_defs"):
		if rank.profession_id==job.profession_id and row.experience>=int(rank.experience_required) and (selected.is_empty() or int(rank.rank)>int(selected.rank)):selected=rank
	return selected
func salary(row: RefCounted) -> int:return int(ceil(float(profession(row.profile_id).salary_credit)*float(rank_for(row).salary_multiplier)))
func ready(row: RefCounted) -> bool:return row!=null and row.phase=="hired" and row.loyalty>=int(balance.loyalty_ready_min) and row.unpaid_periods<int(balance.arrears_period_limit)
func assigned(ship_id: String) -> Array:
	return g.state.rows("crew_assignment_state").filter(func(a: RefCounted):return a.ship_instance_id==ship_id) if supported() else []
func pilot(ship_id: String) -> RefCounted:
	for a: RefCounted in assigned(ship_id):
		if profession(a.profile_id).duty_kind=="pilot" and ready(member(a.profile_id)):return member(a.profile_id)
	return null
func effect(ship_id: String,stat: String) -> float:
	var result: float=0.0
	for a: RefCounted in assigned(ship_id):
		var row: RefCounted=member(a.profile_id);var job: Dictionary=profession(a.profile_id)
		if ready(row) and job.effect_stat==stat:result+=float(rank_for(row).effect_value)*float(row.loyalty)/100.0
	return result
func token(id: String) -> String:
	var row: RefCounted=member(id);var a: RefCounted=assignment(id)
	return "%d:%d:%s:%s" % [row.generation,row.revision,row.phase,a.ship_instance_id if a!=null else ""] if row!=null else ""
func local(row: RefCounted) -> bool:
	if row==null or g.station().is_empty() or g.state.ship().status!=T.ShipStatus.DOCKED:return false
	var a: RefCounted=assignment(row.profile_id)
	if a!=null:
		var ship: RefCounted=g.state.find("ship_state","ship_instance_id",a.ship_instance_id)
		return ship!=null and ship.status==T.ShipStatus.DOCKED and ship.has_station_id and ship.station_id==g.station()
	return row.phase=="available" or (row.has_station_id and row.station_id==g.station())
func reason(id: String,action: String,ship_id: String="") -> String:
	if not supported():return "当前世界尚未升级船员规则"
	var row: RefCounted=member(id)
	if row==null:return "船员不存在"
	if not local(row):return "需在船员或指派舰船所在站办理"
	if not g.unlocked(str(balance.required_unlock_id)):return "完成航路教学后开放船员招募"
	if action=="hire":
		if row.phase!="available":return "该船员已经受雇"
		if g.state.rows("crew_member_state").filter(func(c: RefCounted):return c.phase!="available").size()>=int(balance.max_recruited_crew):return "船员名额已满"
		if g.state.player().credit<int(profession(id).hire_fee_credit):return "招募费不足"
	elif action=="dismiss":
		if row.phase!="hired" or assignment(id)!=null:return "先取消岗位指派；受伤船员需先恢复"
		if row.arrears_credit>0:return "结清欠薪后才能解雇"
	elif action=="assign":
		if not ready(row):return "船员尚未恢复、忠诚不足或欠薪过多"
		var ship: RefCounted=g.state.find("ship_state","ship_instance_id",ship_id)
		if ship==null or ship.policy_id!="normal_owned" or ship.status!=T.ShipStatus.DOCKED or not ship.has_station_id or ship.station_id!=g.station():return "选择当前站停靠的普通自有舰"
		var spec: Dictionary=g.definition("fleet_hull_defs","ship_id",ship.ship_def_id)
		if spec.is_empty():return "该舰没有可用船员岗位"
		var others: Array=assigned(ship_id).filter(func(a: RefCounted):return a.profile_id!=id)
		if others.size()>=int(spec.crew_slots):return "该舰船员岗位已满"
		if others.any(func(a: RefCounted):return a.profession_id==profile(id).profession_id):return "同一职业在一舰只能指派一人"
	elif action=="unassign":
		if assignment(id)==null:return "当前没有指派岗位"
	elif action=="arrears":
		if row.arrears_credit<=0:return "没有欠薪"
		if g.state.player().credit<row.arrears_credit:return "信用点不足以结清欠薪"
	elif action=="treat":
		if row.phase!="injured":return "该船员无需治疗"
		if g.state.player().credit<int(balance.injury_treatment_credit):return "治疗费不足"
	elif action=="rest":
		if row.phase!="hired" or assignment(id)!=null:return "取消岗位指派后安排休整"
		if row.arrears_credit>0:return "先结清欠薪"
		if row.loyalty>=int(balance.loyalty_initial):return "当前无需恢复忠诚度"
		if g.state.player().credit<int(balance.rest_credit):return "休整费不足"
	else:return "未知船员操作"
	return ""
func execute(id: String,action: String,expected: String,ship_id: String="") -> bool:
	if expected!=token(id):return g.fail("船员状态已变化，请刷新后操作")
	var blocked: String=reason(id,action,ship_id)
	if not blocked.is_empty():return g.fail(blocked)
	var row: RefCounted=member(id);var paid: int=0
	match action:
		"hire":
			paid=int(profession(id).hire_fee_credit);row.phase="hired";row.generation+=1;row.hire_paid_credit+=paid;row.has_station_id=true;row.station_id=g.station();row.salary_period_credit=salary(row)
		"dismiss":row.phase="available";row.has_station_id=false;row.station_id=""
		"assign":
			_remove_assignment(id)
			var a: RefCounted=D.CrewAssignmentStateDto.new();a.profile_id=id;a.profession_id=profile(id).profession_id;a.ship_instance_id=ship_id;a.assigned_tick=g.state.snapshot.meta.simulation_tick;g.state.add("crew_assignment_state",a)
			row.has_station_id=false;row.station_id=""
		"unassign":_remove_assignment(id);row.has_station_id=true;row.station_id=g.station()
		"arrears":
			paid=row.arrears_credit;row.salary_paid_credit+=paid;row.loyalty=mini(100,row.loyalty+row.unpaid_periods*int(balance.loyalty_paid_gain));row.arrears_credit=0;row.unpaid_periods=0
		"treat":paid=int(balance.injury_treatment_credit);row.treatment_paid_credit+=paid;row.recovery_remaining_s=0.0;row.phase="hired"
		"rest":paid=int(balance.rest_credit);row.rest_paid_credit+=paid;row.phase="resting";row.recovery_remaining_s=float(balance.rest_duration_s)
	g.state.player().credit-=paid;row.revision+=1
	if action not in ["assign","unassign"]:_receipt(row,"treatment" if action=="treat" else action,paid)
	changed.emit("船员岗位与费用已更新");g.request_autosave();return true
func _remove_assignment(id: String) -> void:
	var a: RefCounted=assignment(id)
	if a!=null:g.state.remove("crew_assignment_state",a)
func _receipt(row: RefCounted,kind: String,paid: int) -> void:
	var entry: RefCounted=D.CrewReceiptStateDto.new();entry.source_token="%s:%d:%d" % [row.profile_id,row.generation,row.revision];entry.profile_id=row.profile_id;entry.event_kind=kind;entry.paid_credit=paid;entry.revision=row.revision;entry.event_tick=g.state.snapshot.meta.simulation_tick;g.state.add("crew_receipt_state",entry)
	while g.state.rows("crew_receipt_state").size()>int(balance.history_limit):g.state.remove("crew_receipt_state",g.state.rows("crew_receipt_state")[0])
func contribute(ship_id: String,kind: String,amount: float) -> void:
	if not supported() or not is_finite(amount) or amount<=0:return
	for a: RefCounted in assigned(ship_id):
		var row: RefCounted=member(a.profile_id);var job: Dictionary=profession(a.profile_id)
		if not ready(row) or job.contribution_kind!=kind or row.experience>=int(balance.experience_cap):continue
		var previous: int=row.experience;var unit: float=float(job.contribution_per_xp)
		row.contribution_total=minf(float(balance.experience_cap)*unit,row.contribution_total+amount)
		row.experience=mini(int(balance.experience_cap),int(floor(row.contribution_total/unit)))
		row.contribution_remainder=row.contribution_total-float(row.experience)*unit
		if row.experience!=previous:row.revision+=1
func ship_lost(ship_id: String,station_id: String) -> void:
	for a: RefCounted in assigned(ship_id).duplicate():
		var row: RefCounted=member(a.profile_id);_remove_assignment(row.profile_id);row.phase="injured";row.recovery_remaining_s=float(balance.injury_recovery_s);row.loyalty=maxi(0,row.loyalty-int(balance.loyalty_casualty_loss));row.has_station_id=true;row.station_id=station_id;row.revision+=1;_receipt(row,"injury",0)
	changed.emit("船员已获救；需休整或到站治疗")
func tick(delta: float) -> void:
	if not supported() or not is_finite(delta) or delta<=0:return
	for row: RefCounted in g.state.rows("crew_member_state"):
		if row.phase in ["injured","resting"]:
			row.recovery_remaining_s=maxf(0.0,row.recovery_remaining_s-delta)
			if row.recovery_remaining_s<=0:
				if row.phase=="resting":row.loyalty=maxi(row.loyalty,int(balance.loyalty_initial))
				row.phase="hired";row.revision+=1;changed.emit("船员休整完成")
			continue
		var a: RefCounted=assignment(row.profile_id)
		if row.phase!="hired" or a==null:continue
		var ship: RefCounted=g.state.find("ship_state","ship_instance_id",a.ship_instance_id)
		if ship==null or ship.status!=T.ShipStatus.FLYING:continue
		row.salary_elapsed_s+=delta
		while row.salary_elapsed_s>=float(balance.salary_period_s):
			row.salary_elapsed_s-=float(balance.salary_period_s);row.salary_periods+=1
			var due: int=row.salary_period_credit
			if g.state.player().credit>=due:
				g.state.player().credit-=due;row.salary_paid_credit+=due;row.loyalty=mini(100,row.loyalty+int(balance.loyalty_paid_gain))
			else:
				if row.unpaid_periods<int(balance.arrears_period_limit):row.arrears_credit+=due;row.unpaid_periods+=1
				row.loyalty=maxi(0,row.loyalty-int(balance.loyalty_unpaid_loss));due=0;changed.emit("船员欠薪 · 可返港结清，忠诚度已下降")
			row.salary_period_credit=salary(row);row.revision+=1;_receipt(row,"salary",due);g.request_autosave()
