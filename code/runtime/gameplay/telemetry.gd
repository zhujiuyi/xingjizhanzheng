extends RefCounted
## Offline aggregate game measurements. No positions, raw inputs or OS data.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
var g: RefCounted
const COUNTERS: Array[String]=["mined_units","kills","damage_dealt","damage_taken","weapon_cycles","drone_losses"]
func _init(game: RefCounted) -> void:g=game
func supported() -> bool:return g!=null and g.catalog.table_names.has("campaign_balance_defs")
func totals() -> RefCounted:return g.state.rows("telemetry_total_state")[0] if supported() else null
func latest() -> RefCounted:
	var result: RefCounted=null
	for row: RefCounted in g.state.rows("flight_record_state"):
		if result==null or row.sequence>result.sequence:result=row
	return result
func wallet() -> void:
	if not supported():return
	var total: RefCounted=totals();var current: int=g.state.player().credit;var delta: int=current-total.wallet_last
	total.wallet_last=current
	if delta==0:return
	if delta>0:total.income_credit+=delta
	else:total.spent_credit-=delta
	var row: RefCounted=latest()
	if row==null:return
	var field: String=("flight_" if row.phase=="active" else "return_")+("income" if delta>0 else "spent")
	row.set(field,int(row.get(field))+absi(delta));row.credit_last=current
func begin(partial: bool=false) -> void:
	if not supported():return
	wallet()
	var previous: RefCounted=latest()
	if previous!=null and previous.phase=="active":return
	var total: RefCounted=totals();var row: RefCounted=D.FlightRecordStateDto.new()
	row.record_id=g.id("flight");row.sequence=total.next_sequence;total.next_sequence+=1;total.outings+=1
	row.ship_def_id=g.state.ship().ship_def_id;row.phase="active";row.partial_baseline=partial
	row.started_tick=g.state.snapshot.meta.simulation_tick;row.credit_start=g.state.player().credit;row.credit_last=row.credit_start
	g.state.add("flight_record_state",row)
	var records: Array=g.state.rows("flight_record_state").duplicate()
	records.sort_custom(func(a: RefCounted,b: RefCounted)->bool:return a.sequence<b.sequence)
	var maximum: int=int(g.rows("campaign_balance_defs")[0].report_limit)
	while records.size()>maximum:g.state.remove("flight_record_state",records.pop_front())
func finish(lost: bool=false) -> void:
	if not supported():return
	wallet()
	var row: RefCounted=latest()
	if row==null or row.phase!="active":return
	row.phase="lost" if lost else "docked";row.finished_tick=g.state.snapshot.meta.simulation_tick
	if lost:totals().lost_outings+=1
func stat(key: String,amount: float=1.0) -> void:
	if not supported() or key not in COUNTERS or not is_finite(amount) or amount<=0.0:return
	var row: RefCounted=latest()
	if (row==null or row.phase!="active") and g.state.ship().status==T.ShipStatus.FLYING:begin(true);row=latest()
	var total: RefCounted=totals()
	if key in ["damage_dealt","damage_taken"]:
		total.set(key,float(total.get(key))+amount)
		if row!=null and row.phase=="active":row.set(key,float(row.get(key))+amount)
	else:
		total.set(key,int(total.get(key))+int(amount))
		if row!=null and row.phase=="active":row.set(key,int(row.get(key))+int(amount))
func activity() -> void:
	if not supported():return
	var row: RefCounted=latest()
	if row!=null:row.activity_count+=1
func tick(delta: float,transit: bool=false) -> void:
	if not supported():return
	wallet()
	var row: RefCounted=latest()
	if g.state.ship().status==T.ShipStatus.FLYING and (row==null or row.phase!="active"):begin(true);row=latest()
	if row==null or row.phase!="active":return
	if g.state.ship().status==T.ShipStatus.DESTROYED:finish(true);return
	if g.state.ship().status==T.ShipStatus.DOCKED:finish();return
	row.elapsed_s+=delta;totals().elapsed_s+=delta
	if g.in_combat():row.combat_s+=delta;totals().combat_s+=delta
	if transit:row.transit_s+=delta;totals().transit_s+=delta
func export_rows() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not supported():return result
	for row: RefCounted in g.state.rows("flight_record_state"):
		var view: Dictionary={"sequence":row.sequence,"hull":g.definition("ship_defs","ship_id",row.ship_def_id).display_name,"status":row.phase,"partial_baseline":row.partial_baseline}
		for key: String in ["elapsed_s","combat_s","transit_s","flight_income","flight_spent","return_income","return_spent","mined_units","kills","damage_dealt","damage_taken","weapon_cycles","drone_losses","activity_count"]:view[key]=row.get(key)
		result.append(view)
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.sequence>b.sequence)
	return result
