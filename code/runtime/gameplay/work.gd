extends RefCounted
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g:RefCounted
var scan_target:String=""
var scan_progress:float=0
var scan_remaining:float=0
var scan_paid:bool=false
var scan_equipment:String=""
var scan_rate:float=0
var mining_target:String=""
var mining_cycles:Dictionary={}
func _init(gameplay:RefCounted)->void:g=gameplay
func busy()->bool:return not scan_target.is_empty() or not mining_target.is_empty()
func stop_scan()->void:
	if not scan_target.is_empty():g.event(T.EventKind.SCAN_ENDED,g.state.ship().ship_instance_id,scan_target)
	if not scan_equipment.is_empty():
		var e:RefCounted=g.state.find("equipment_state","item_instance_id",scan_equipment)
		if e!=null:e.active_remaining_s=0;e.cycle_paid=false
	scan_target="";scan_progress=0;scan_remaining=0;scan_paid=false;scan_equipment=""
func stop_mining()->void:
	if not mining_target.is_empty():g.event(T.EventKind.MINING_ENDED,g.state.ship().ship_instance_id,mining_target)
	for item_id in mining_cycles:
		var e:RefCounted=g.state.find("equipment_state","item_instance_id",item_id)
		if e!=null:e.active_remaining_s=0;e.cycle_paid=false
	mining_target="";mining_cycles.clear()
func disable_equipment(item_id:String)->void:
	if scan_equipment==item_id:stop_scan()
	if mining_cycles.has(item_id):
		mining_cycles.erase(item_id)
		var equipment:RefCounted=g.state.find("equipment_state","item_instance_id",item_id)
		if equipment!=null:equipment.active_remaining_s=0;equipment.cycle_paid=false
	# Other enabled heads may continue their independently paid cycles.
	if not mining_target.is_empty():
		var any_enabled:bool=false
		for equipment in g.equipped(g.state.ship()):
			if equipment.enabled and not g.definition("mining_defs","module_id",equipment.module_def_id).is_empty():any_enabled=true
		if not any_enabled:stop_mining()
func _distance(anchor:Dictionary)->float:return g.anchor_distance(g.state.ship(),anchor)
func _los(anchor:Dictionary,target:String)->bool:
	if not g.same_anchor_site(g.state.ship(),anchor):return false
	return g.spatial_validator.call(g.position(g.state.ship()),g.anchor_position(anchor),target) if g.spatial_validator.is_valid() else true
func start_scan(signal_id:String)->bool:
	var def:Dictionary=g.definition("signal_defs","signal_id",signal_id)
	if def.is_empty() or not g.unlocked(def.required_unlock_id) or g.state.ship().status!=T.ShipStatus.FLYING:return g.fail("信号尚未开放或不能扫描")
	if def.occurrence_mode=="mission_scoped" and g.missions.active_for_target("scan_signal",signal_id)==null:return g.fail("此信号需要当前合同")
	if def.occurrence_mode=="fixed" and g.state.find("discovery_state","signal_id",signal_id)!=null:return g.fail("此固定信号已经完成测绘")
	var anchor:Dictionary=g.definition("anchor_defs","anchor_id",def.anchor_id)
	if anchor.sector_id!=g.state.current_sector():return g.fail("信号不在当前星区")
	if not g.same_anchor_site(g.state.ship(),anchor):return g.fail("需要先跃迁至信号所在地点")
	stop_scan();scan_target=signal_id
	for e in g.equipped(g.state.ship()):
		if e.module_def_id.begins_with("module_scanner_") and e.enabled:scan_equipment=e.item_instance_id;break
	g.event(T.EventKind.SCAN_STARTED,g.state.ship().ship_instance_id,signal_id)
	return true
func start_mining(node_id:String)->bool:
	var def:Dictionary=g.definition("resource_node_defs","node_id",node_id)
	var location:Dictionary=g.definition("resource_node_locations","node_id",node_id)
	if def.is_empty() or location.is_empty() or def.sector_id!=g.state.current_sector() or not g.unlocked(location.required_unlock_id) or g.state.ship().status!=T.ShipStatus.FLYING:return g.fail("矿点不可用")
	var item:Dictionary=g.definition("item_defs","item_id",def.item_id)
	if item.item_type!="ore":return g.fail("此组件节点应使用近距离回收")
	var anchor:Dictionary=g.definition("anchor_defs","anchor_id",location.anchor_id)
	if not g.same_anchor_site(g.state.ship(),anchor):return g.fail("需要先跃迁至矿点所在地点")
	if not _loan_target_allowed(node_id):return g.fail("教学借船仅可采集当前任务指定矿点")
	var compatible:bool=false
	for e in g.equipped(g.state.ship()):
		for c in g.rows("mining_compatibility"):
			if c.module_id==e.module_def_id and c.item_id==def.item_id and e.enabled:compatible=true
	if not compatible:return g.fail("未安装兼容的采集设备；特色原矿需要 II/III 采集头")
	ensure_tutorial_supply(node_id)
	var resource := XJResourceStatus.inspect(g.state, g.catalog, node_id)
	if not resource.available:return g.fail("资源状态不可用")
	if resource.depleted:return g.fail(XJResourceStatus.summary(resource))
	if available_resource_units(node_id)<=0:return g.fail(resource_limit_reason(node_id))
	if _output_limit(def.item_id, 1).count<=0:return g.fail("货舱已满或借船采集配额不足")
	stop_mining();mining_target=node_id;g.event(T.EventKind.MINING_STARTED,g.state.ship().ship_instance_id,node_id)
	return true

func ensure_tutorial_supply(node_id:String)->void:
	var reservation := XJResourceStatus.tutorial_reservation(g.state, g.catalog, node_id)
	if reservation.is_empty() or reservation.mission_instance_id.is_empty() or reservation.outstanding_units<=0:return
	var node:D.ResourceStateDto=g.state.find("resource_state","node_id",node_id)
	var def:Dictionary=g.definition("resource_node_defs","node_id",node_id)
	if node==null or def.is_empty():return
	var needed:int=mini(int(reservation.outstanding_units), int(def.capacity_units))
	# This is a finite sample reservation, not a full mineral-field respawn.
	if node.remaining_units<needed:
		node.remaining_units=needed;node.respawn_remaining_s=0.0
	for loan:D.LoanStateDto in g.state.rows("loan_state"):
		if loan.mission_instance_id!=reservation.mission_instance_id or loan.loan_service_id!=reservation.loan_service_id or loan.status!=T.LoanStatus.ACTIVE or not loan.has_quota_remaining_units:continue
		var service:Dictionary=g.definition("loan_service_defs","loan_service_id",loan.loan_service_id)
		loan.quota_remaining_units=mini(int(service.operation_quota_units), maxi(loan.quota_remaining_units, int(reservation.outstanding_units)))

func ensure_tutorial_supplies()->void:
	for node:D.ResourceStateDto in g.state.rows("resource_state"):ensure_tutorial_supply(node.node_id)

func available_resource_units(node_id:String)->int:
	var node:D.ResourceStateDto=g.state.find("resource_state","node_id",node_id)
	if node==null:return 0
	var reservation := XJResourceStatus.tutorial_reservation(g.state, g.catalog, node_id)
	if not _loan_target_allowed(node_id):return 0
	if reservation.is_empty():return node.remaining_units
	var loan:D.LoanStateDto=_active_loan()
	if loan!=null and loan.mission_instance_id==reservation.mission_instance_id and loan.loan_service_id==reservation.loan_service_id:
		return mini(node.remaining_units, int(reservation.outstanding_units))
	return maxi(0, node.remaining_units-int(reservation.outstanding_units))

func _loan_target_allowed(node_id:String)->bool:
	var loan:D.LoanStateDto=_active_loan()
	if loan==null:return true
	var service:Dictionary=g.definition("loan_service_defs","loan_service_id",loan.loan_service_id)
	if service.gathered_policy_id!="mission_bound":return true
	var reservation := XJResourceStatus.tutorial_reservation(g.state, g.catalog, node_id)
	return not reservation.is_empty() and reservation.mission_instance_id==loan.mission_instance_id and reservation.loan_service_id==loan.loan_service_id

func resource_limit_reason(node_id:String)->String:
	var reservation := XJResourceStatus.tutorial_reservation(g.state, g.catalog, node_id)
	var loan:D.LoanStateDto=_active_loan()
	if loan!=null and not reservation.is_empty() and loan.mission_instance_id==reservation.mission_instance_id and loan.loan_service_id==reservation.loan_service_id:
		return "任务样本已足够，请返航交付"
	return "剩余矿量为教学预留；请使用任务借船"

func _active_loan()->D.LoanStateDto:
	for row in g.state.rows("loan_state"):
		if row.status==T.LoanStatus.ACTIVE and row.current_ship_id==g.state.ship().ship_instance_id:return row
	return null
func _output_limit(item_id:String,wanted:int)->Dictionary:
	var dest:String=g.inventory.hold(g.state.ship(),T.ContainerKind.MINERAL)
	if dest.is_empty() or g.inventory.room(dest,item_id,wanted)==0:dest=g.inventory.hold(g.state.ship(),T.ContainerKind.CARGO)
	var count:int=g.inventory.room(dest,item_id,wanted)
	var loan:D.LoanStateDto=_active_loan()
	if loan!=null and loan.has_quota_remaining_units:count=mini(count,loan.quota_remaining_units)
	return {"destination":dest,"count":count,"loan":loan}
func _grant_output(node_id:String,item_id:String,units:int,destination:String,loan:D.LoanStateDto)->void:
	var policy:String="normal_owned";var mission_id:String=""
	if loan!=null:
		var def:Dictionary=g.definition("loan_service_defs","loan_service_id",loan.loan_service_id)
		policy=def.gathered_policy_id
		mission_id=loan.mission_instance_id if policy=="mission_bound" else ""
		if loan.has_quota_remaining_units:loan.quota_remaining_units-=units
	# SQLite stack origins are exclusive: samples are mission_bound, while the
	# borrowed hull/equipment remain loan assets. Quota belongs to the loan DTO.
	g.inventory.grant(destination,item_id,units,policy,mission_id)
	g.record_event("collect",node_id,units)

func recover_resource(node_id:String,quantity:int)->bool:
	var def:Dictionary=g.definition("resource_node_defs","node_id",node_id)
	var location:Dictionary=g.definition("resource_node_locations","node_id",node_id)
	if def.is_empty() or location.is_empty() or not g.unlocked(location.required_unlock_id) or def.sector_id!=g.state.current_sector() or g.state.ship().status!=T.ShipStatus.FLYING:return g.fail("回收节点不可用")
	if g.definition("item_defs","item_id",def.item_id).item_type=="ore":return g.fail("原矿需要采集设备")
	var anchor:Dictionary=g.definition("anchor_defs","anchor_id",location.anchor_id)
	if not g.same_anchor_site(g.state.ship(),anchor):return g.fail("需要先跃迁至回收节点所在地点")
	if _distance(anchor)>anchor.interaction_radius_m or not _los(anchor,node_id):return g.fail("需要接近组件节点且视线无遮挡")
	var node:D.ResourceStateDto=g.state.find("resource_state","node_id",node_id)
	if node==null:return g.fail("资源状态不可用")
	var limits:Dictionary=_output_limit(def.item_id,mini(quantity,available_resource_units(node_id)))
	if limits.count<=0:return g.fail("节点耗尽、载荷不足或借船配额耗尽")
	node.remaining_units-=limits.count
	if node.remaining_units==0:node.respawn_remaining_s=def.respawn_s
	_grant_output(node_id,def.item_id,limits.count,limits.destination,limits.loan)
	return true

func _scan_tick(delta:float)->void:
	if scan_target.is_empty():return
	var def:Dictionary=g.definition("signal_defs","signal_id",scan_target)
	var anchor:Dictionary=g.definition("anchor_defs","anchor_id",def.anchor_id)
	var mod:Dictionary={};var e:D.EquipmentStateDto=null
	if not scan_equipment.is_empty():
		e=g.state.find("equipment_state","item_instance_id",scan_equipment)
		if e==null or not e.enabled:stop_scan();return
		mod=g.definition("module_defs","module_id",e.module_def_id)
	var range_m:float=g.rule("basic_scan_range_m") if mod.is_empty() else mod.range_m
	var cycle:float=g.rule("basic_scan_cycle_s") if mod.is_empty() else mod.cycle_s
	if not g.same_anchor_site(g.state.ship(),anchor) or _distance(anchor)>range_m or not _los(anchor,scan_target):
		stop_scan();g.status_text="扫描中断：距离或视线不满足";return
	if not scan_paid:
		if e!=null:
			if not g.pay_cycle(e):return
		else:
			var energy:float=g.rule("basic_scan_energy_eu_s")*cycle;var heat:float=g.rule("basic_scan_heat_hu_s")*cycle
			if g.state.ship().energy<energy or g.state.ship().overheated or g.state.ship().heat+heat>g.metrics(g.state.ship()).heat_max:return
			g.state.ship().energy-=energy;g.state.ship().heat+=heat
		scan_remaining=cycle;scan_paid=true
		var strength:float=g.metrics(g.state.ship()).scan_strength if e!=null else g.definition("ship_defs","ship_id",g.state.ship().ship_def_id).scan_strength
		var proximity:float=clampf(g.rule("scan_proximity_intercept")-g.rule("scan_proximity_distance_slope")*_distance(anchor)/range_m,g.rule("scan_proximity_floor"),1)
		scan_rate=strength*g.economy.base_factor("navigation")*proximity/maxf(g.rule("scan_interference_floor"),def.difficulty_multiplier)
	scan_remaining=maxf(0,scan_remaining-delta)
	if scan_remaining>0:return
	scan_progress+=scan_rate*cycle;scan_paid=false
	if scan_progress<def.threshold_progress:return
	var target:String=scan_target
	if def.occurrence_mode=="fixed" and g.state.find("discovery_state","signal_id",target)==null:
		var row:D.DiscoveryStateDto=D.DiscoveryStateDto.new();row.player_id=g.state.player().player_id;row.discovery_id=g.id("discovery");row.sector_id=anchor.sector_id;row.kind=T.DiscoveryKind.SIGNAL;row.has_signal_id=true;row.signal_id=target;row.discovered_tick=g.state.snapshot.meta.simulation_tick;g.state.add("discovery_state",row)
	for reward in g.rows("signal_unlock_rewards"):
		if reward.signal_id==target:g.grant_unlock(reward.unlock_id)
	g.record_event("scan_signal",target,1);stop_scan();g.request_autosave();g.status_text="信号解析完成"

func _mining_tick(delta:float)->void:
	if mining_target.is_empty():return
	var def:Dictionary=g.definition("resource_node_defs","node_id",mining_target)
	var location:Dictionary=g.definition("resource_node_locations","node_id",mining_target)
	var anchor:Dictionary=g.definition("anchor_defs","anchor_id",location.anchor_id)
	var node:D.ResourceStateDto=g.state.find("resource_state","node_id",mining_target)
	if node==null or node.remaining_units<=0 or not g.same_anchor_site(g.state.ship(),anchor):stop_mining();return
	if available_resource_units(mining_target)<=0:
		g.status_text="采矿结束：任务样本已足够或剩余矿量为教学预留";stop_mining();return
	for e in g.equipped(g.state.ship()):
		var mining:Dictionary=g.definition("mining_defs","module_id",e.module_def_id)
		if mining.is_empty():continue
		if not e.enabled:
			mining_cycles.erase(e.item_instance_id);e.active_remaining_s=0;e.cycle_paid=false;continue
		var compatible:bool=false
		for c in g.rows("mining_compatibility"):
			if c.module_id==e.module_def_id and c.item_id==def.item_id:compatible=true
		if not compatible:continue
		if _output_limit(def.item_id, mini(1, available_resource_units(mining_target))).count<=0:
			g.status_text="采矿结束：样本已足够、货舱已满或借船配额不足";stop_mining();return
		var mod:Dictionary=g.definition("module_defs","module_id",e.module_def_id)
		if _distance(anchor)>mod.range_m or not _los(anchor,mining_target):
			mining_cycles.erase(e.item_instance_id);e.active_remaining_s=0;e.cycle_paid=false;continue
		if not mining_cycles.has(e.item_instance_id):
			if not g.pay_cycle(e):continue
			mining_cycles[e.item_instance_id]=mod.cycle_s
		mining_cycles[e.item_instance_id]=maxf(0,mining_cycles[e.item_instance_id]-delta)
		if mining_cycles[e.item_instance_id]>0:continue
		mining_cycles.erase(e.item_instance_id)
		# This head completed its paid cycle before it leaves the active map. In
		# particular, the final unit must not retain an unfinished saved operation.
		e.active_remaining_s=0.0;e.cycle_paid=false
		var amount:int=XJResourceStatus.yield_per_cycle(g.catalog,mining_target,g.state.ship().ship_def_id,e.module_def_id,g.exploration.mining_multiplier(mining_target))
		var limits:Dictionary=_output_limit(def.item_id,mini(amount,available_resource_units(mining_target)))
		if limits.count<=0:
			g.status_text="采矿结束：货舱已满或借船配额不足";stop_mining();return
		node.remaining_units-=limits.count
		_grant_output(mining_target,def.item_id,limits.count,limits.destination,limits.loan)
		g.exploration.on_collect(mining_target, limits.count)
		if node.remaining_units==0:
			node.respawn_remaining_s=0.0 if g.exploration.managed_resources.has(mining_target) else def.respawn_s
			stop_mining();return
func tick(delta:float)->void:
	if g.state.ship().status!=T.ShipStatus.FLYING:stop_scan();stop_mining();return
	_scan_tick(delta);_mining_tick(delta)
