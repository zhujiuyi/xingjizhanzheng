extends RefCounted
## Game-only provenance and clocks. Presentation time never advances the world.
const D=preload("res://contracts/contract_dtos.gd")
var g: RefCounted
var last_page: String=""
const KINDS: Array[String]=["mission","exploration","operation","trial","blockade","ship_loss"]
const OUTCOMES: Array[String]=["completed","partial","failed","withdrawn","destroyed"]
const REASONS: Array[String]=["completed","partial","manual","timeout","ship_destroyed","target_lost","out_of_range","loadout_changed","departed","combat","environment","overheat","unknown","signal_lost","objective_failed"]
const PAGES: Array[String]=["station","ships","warehouse","fitting","market","industry","salvage","research","missions","map","pause","settings","civilizations","frontier","hire","consignments","ship_roles","fitting_analysis","sources","operations","drones","exploration","projects","expeditions","reports","trials","blockades"]
static func reason_label(reason: String) -> String:
	return {"completed":"完整完成","partial":"部分完成","manual":"主动撤回","timeout":"超过时限","ship_destroyed":"舰船损毁","target_lost":"目标损失","out_of_range":"离开有效范围","loadout_changed":"舰船或配装变化","departed":"离开行动空域","combat":"战斗致命伤害","environment":"环境致命伤害","overheat":"过热","signal_lost":"信号失联","objective_failed":"未达到目标","unknown":"来源未知"}.get(reason,"来源未知")
static func activity_label(kind: String) -> String:
	return {"mission":"任务","exploration":"探索","operation":"战术行动","trial":"配装挑战","blockade":"封锁航路","ship_loss":"舰船损毁"}.get(kind,kind)
func activity_name(kind: String,id: String) -> String:
	var key: String=id.get_slice(":",0)
	if kind=="ship_loss":return str(g.definition("ship_defs","ship_id",key).get("display_name",key))
	if kind=="mission":
		var mission: RefCounted=g.state.find("mission_state","mission_instance_id",id)
		return str(g.definition("mission_defs","mission_id",mission.mission_def_id).get("display_name","任务")) if mission!=null else "任务"
	var table: String={"exploration":"exploration_event_defs","operation":"operation_defs","trial":"trial_defs","blockade":"blockade_defs"}.get(kind,"")
	var column: String={"exploration":"event_id","operation":"operation_id","trial":"trial_id","blockade":"blockade_id"}.get(kind,"")
	return str(g.definition(table,column,key).get("display_name",activity_label(kind)))
func _init(game: RefCounted) -> void:g=game
func supported() -> bool:return g!=null and g.catalog.table_names.has("telemetry_policy_defs")
func source(item_id: String,units: int,kind: String) -> void:
	if not supported() or units<=0 or kind not in ["mining","manufacture","mission","salvage","purchase"] or g.definition("item_defs","item_id",item_id).is_empty():return
	for row: RefCounted in g.state.rows("telemetry_source_state"):
		if row.item_id==item_id and row.source_kind==kind:row.units+=units;return
	var row: RefCounted=D.TelemetrySourceStateDto.new();row.item_id=item_id;row.source_kind=kind;row.units=units;g.state.add("telemetry_source_state",row)
func active(kind: String,id: String) -> RefCounted:
	for row: RefCounted in g.state.rows("activity_record_state"):
		if row.activity_kind==kind and row.object_id==id and row.phase=="active":return row
	return null
func begin(kind: String,id: String,partial: bool=false) -> void:
	if not supported() or kind not in KINDS or id.is_empty() or active(kind,id)!=null:return
	var row: RefCounted=D.ActivityRecordStateDto.new()
	row.record_id=g.id("activity");row.activity_kind=kind;row.object_id=id;row.phase="active";row.partial_baseline=partial;row.started_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("activity_record_state",row)
func finish(kind: String,id: String,outcome: String,reason: String) -> void:
	if not supported() or kind not in KINDS or outcome not in OUTCOMES:return
	var row: RefCounted=active(kind,id)
	# New actions and reviewed upgrades create baselines explicitly. A repeated
	# completion after recent-history pruning must never recreate a result.
	if row==null:return
	row.phase="finished";row.outcome=outcome;row.reason_code=reason if reason in REASONS else "unknown"
	row.finished_tick=g.state.snapshot.meta.simulation_tick;row.elapsed_s=float(row.finished_tick-row.started_tick)/g.rule("simulation_hz")
	var total: RefCounted=null
	for candidate: RefCounted in g.state.rows("activity_total_state"):
		if candidate.activity_kind==kind and candidate.outcome==outcome and candidate.reason_code==row.reason_code:total=candidate;break
	if total==null:
		total=D.ActivityTotalStateDto.new();total.activity_kind=kind;total.outcome=outcome;total.reason_code=row.reason_code;g.state.add("activity_total_state",total)
	total.occurrences+=1;total.elapsed_s+=row.elapsed_s
	var finished: Array=g.state.rows("activity_record_state").filter(func(r: RefCounted):return r.phase=="finished")
	finished.sort_custom(func(a: RefCounted,b: RefCounted):return a.finished_tick<b.finished_tick or (a.finished_tick==b.finished_tick and a.record_id<b.record_id))
	while finished.size()>int(g.rows("telemetry_policy_defs")[0].record_limit):g.state.remove("activity_record_state",finished.pop_front())
func presentation(delta: float,page: String,focused: bool,navigation_wait: bool) -> void:
	if not supported() or not focused or not is_finite(delta) or delta<=0.0:return
	if navigation_wait:g.state.rows("telemetry_timing_state")[0].navigation_wait_s+=delta
	if page not in PAGES:last_page="";return
	var row: RefCounted=g.state.find("telemetry_menu_state","page_id",page)
	if row==null:row=D.TelemetryMenuStateDto.new();row.page_id=page;g.state.add("telemetry_menu_state",row)
	if page!=last_page:row.visits+=1
	row.duration_s+=delta;last_page=page
func export_data() -> Dictionary:
	var result: Dictionary={"sources":[],"activities":[],"activity_totals":[],"menus":[],"navigation_wait_s":0.0}
	if not supported():return result
	for row: RefCounted in g.state.rows("telemetry_source_state"):result.sources.append({"item_id":row.item_id,"source":row.source_kind,"units":row.units})
	for row: RefCounted in g.state.rows("activity_record_state"):
		var elapsed: float=float(g.state.snapshot.meta.simulation_tick-row.started_tick)/g.rule("simulation_hz") if row.phase=="active" else row.elapsed_s
		result.activities.append({"kind":row.activity_kind,"object_id":row.object_id,"phase":row.phase,"outcome":row.outcome,"reason":row.reason_code,"elapsed_s":elapsed,"partial_baseline":row.partial_baseline})
	for row: RefCounted in g.state.rows("activity_total_state"):result.activity_totals.append({"kind":row.activity_kind,"outcome":row.outcome,"reason":row.reason_code,"count":row.occurrences,"elapsed_s":row.elapsed_s})
	for row: RefCounted in g.state.rows("telemetry_menu_state"):result.menus.append({"page":row.page_id,"duration_s":row.duration_s,"visits":row.visits})
	result.navigation_wait_s=g.state.rows("telemetry_timing_state")[0].navigation_wait_s
	return result
