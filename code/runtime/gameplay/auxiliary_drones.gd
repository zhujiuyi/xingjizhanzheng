extends RefCounted
## Paid, finite auxiliary sorties. All effects require live physical context.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
const Space=preload("res://runtime/space_coordinates.gd")
var g: RefCounted
var spatial_active: bool=true
var prepare: Callable
var publish: Callable
var discard: Callable
var target_query: Callable
var sight_query: Callable

func _init(host: RefCounted) -> void:g=host
func supported() -> bool:return g!=null and g.catalog.table_names.has("auxiliary_drone_defs")
func fit_reason(ship: RefCounted,module_id: String,ignore: String="") -> String:
	if not supported():return ""
	var definition: Dictionary=g.definition("auxiliary_drone_defs","module_id",module_id)
	if definition.is_empty():return ""
	var permission: Dictionary={}
	for row: Dictionary in g.rows("ship_auxiliary_permissions"):
		if row.ship_id==ship.ship_def_id and row.role_kind==definition.role_kind:permission=row;break
	if permission.is_empty():return "该舰种不能搭载此类辅助无人机"
	var count: int=0
	for equipment: RefCounted in g.equipped(ship):
		if equipment.item_instance_id!=ignore and spec(equipment.item_instance_id).get("role_kind","")==definition.role_kind:count+=1
	return "同类辅助机库已达舰种上限" if count>=int(permission.max_installed) else ""
func spec(item_id: String) -> Dictionary:
	var item: RefCounted=g.state.find("item_instance_state","item_instance_id",item_id)
	return g.definition("auxiliary_drone_defs","module_id",item.item_def_id) if supported() and item!=null else {}
func bay(item_id: String) -> RefCounted:return g.state.find("auxiliary_bay_state","item_instance_id",item_id)
func owner(item_id: String) -> RefCounted:
	var equipment: RefCounted=g.state.find("equipment_state","item_instance_id",item_id)
	var container: RefCounted=g.state.find("container_state","container_id",equipment.slot_container_id) if equipment!=null else null
	return g.state.find("ship_state","ship_instance_id",container.ship_instance_id) if container!=null and container.has_ship_instance_id else null
func sync() -> void:
	if not supported():return
	for item: RefCounted in g.state.rows("item_instance_state"):
		var definition: Dictionary=spec(item.item_instance_id)
		if definition.is_empty() or bay(item.item_instance_id)!=null:continue
		var row:=D.AuxiliaryBayStateDto.new();row.item_instance_id=item.item_instance_id;row.stock_units=int(definition.drone_count);row.command_kind="follow";g.state.add("auxiliary_bay_state",row)
func token(item_id: String) -> String:
	var row: RefCounted=bay(item_id)
	return "%s:%s:%d:%d" % [g.state.world_id,g.state.session_id,g.state.epoch,row.revision] if row!=null else ""
func query(id: String) -> Dictionary:return target_query.call(id) if target_query.is_valid() else {}
func target(id: String) -> RefCounted:
	if id==g.state.ship().ship_instance_id:return g.state.ship()
	return g.state.find("npc_state","npc_instance_id",id)
func repair_layer(id: String) -> String:
	var row: RefCounted=target(id)
	if row==null:return ""
	var limits: Dictionary=g.metrics(row) if id==g.state.ship().ship_instance_id else g.npc_metrics(row)
	for layer: String in ["armor","hull"]:
		if float(row.get(layer))<float(limits[layer+"_max"]):return layer
	return ""
func reason(item_id: String,target_id: String,expected: String) -> String:
	var definition: Dictionary=spec(item_id);var row: RefCounted=bay(item_id);var hull: RefCounted=owner(item_id)
	if definition.is_empty() or row==null or hull==null:return "选择已装载的辅助无人机库"
	if expected!=token(item_id):return "机库状态已变化，请刷新"
	if not spatial_active or g.state.ship().status!=T.ShipStatus.FLYING or not prepare.is_valid() or not publish.is_valid():return "需要在局部空间出航作业"
	if hull.policy_id!="normal_owned" or not g.drone_control.module_live(hull.ship_instance_id,item_id):return "普通自有机库未启用或已损坏"
	if hull!=g.state.ship():
		var deployment: RefCounted=g.owned_fleet.row(hull.ship_instance_id)
		if deployment==null or deployment.phase!="deployed" or not g.owned_fleet.connected(deployment):return "母舰未部署、正在撤退或已失联"
	if row.stock_units<=0:return "辅助无人机已耗尽，返站补充"
	if row.deployed_units>0:return "先回收该机库已出击的无人机"
	var destination: Dictionary=query(target_id)
	if destination.is_empty() or destination.site_id!=Space.current_site(g.state):return "选择同一局部空间中的目标；不能跨AU出击"
	var module: Dictionary=g.definition("module_defs","module_id",definition.module_id)
	if g.position(hull).distance_to(destination.position)>float(module.range_m):return "目标超出辅助无人机通信范围"
	if definition.role_kind=="repair":
		var patient: RefCounted=target(target_id)
		if patient==null or (target_id!=g.state.ship().ship_instance_id and (not patient.alive or not g.civilizations.friendly(target_id))):return "选择主舰或存活友舰"
		if repair_layer(target_id).is_empty():return "目标装甲与结构已满"
	var equipment: RefCounted=g.state.find("equipment_state","item_instance_id",item_id)
	if equipment.cooldown_remaining_s>0:return "辅助机库仍在冷却"
	var budget: String=preload("res://runtime/gameplay/resource_budget.gd").blocked(hull.energy,hull.heat,hull.overheated,float(g.metrics(hull).heat_max),float(module.energy_eu),float(module.heat_hu))
	if not budget.is_empty():return budget
	if definition.consumable_item_id!=null and g.inventory.count(g.inventory.hold(hull,T.ContainerKind.CARGO),definition.consumable_item_id,true)<int(definition.consumable_per_sortie):return "母舰货舱的普通维修耗材不足"
	return ""
func launch(item_id: String,target_id: String,expected: String) -> bool:
	var blocked: String=reason(item_id,target_id,expected)
	if not blocked.is_empty():return g.fail(blocked)
	var staged: Array=prepare.call(item_id,target_id)
	if staged.is_empty():return g.fail("无法准备实体出击，资源保留")
	var hull: RefCounted=owner(item_id);var definition: Dictionary=spec(item_id);var equipment: RefCounted=g.state.find("equipment_state","item_instance_id",item_id)
	if not g.pay_cycle(equipment,hull):discard.call(staged);return false
	if definition.consumable_item_id!=null:g.inventory.consume(g.inventory.hold(hull,T.ContainerKind.CARGO),definition.consumable_item_id,int(definition.consumable_per_sortie),true)
	var row: RefCounted=bay(item_id);var module: Dictionary=g.definition("module_defs","module_id",definition.module_id)
	row.sorties+=1;row.revision+=1;row.command_kind="follow";row.energy_paid_total+=float(module.energy_eu);row.heat_paid_total+=float(module.heat_hu);row.consumable_paid_units+=int(definition.consumable_per_sortie)
	publish.call(staged);g.status_text="维修无人机出击" if definition.role_kind=="repair" else "侦察无人机出击";g.request_autosave();return true
func repair(drone: RefCounted) -> float:
	if drone==null or drone.role_kind!="repair" or drone.fired or drone.returning or not g.drone_control.live.has(drone.drone_id):return 0.0
	if not spatial_active or not g.drone_control.module_live(drone.owner_id,drone.module_instance_id):return 0.0
	var info: Dictionary=query(drone.target_id);var definition: Dictionary=spec(drone.module_instance_id)
	var hull: RefCounted=owner(drone.module_instance_id)
	if hull==null or g.position(hull).distance_to(g.position(drone))>float(g.definition("module_defs","module_id",definition.module_id).range_m):return 0.0
	if info.is_empty() or info.generation!=drone.target_generation or info.site_id!=drone.site_id or not sight_query.is_valid() or not sight_query.call(drone.drone_id,drone.target_id,float(definition.work_range_m)):return 0.0
	if drone.target_id!=g.state.ship().ship_instance_id and not g.civilizations.friendly(drone.target_id):return 0.0
	drone.fired=true
	var layer: String=repair_layer(drone.target_id)
	if layer.is_empty():return 0.0
	var patient: RefCounted=target(drone.target_id);var limits: Dictionary=g.metrics(patient) if drone.target_id==g.state.ship().ship_instance_id else g.npc_metrics(patient)
	var item: RefCounted=g.state.find("item_instance_state","item_instance_id",drone.module_instance_id)
	var restored: float=minf(float(limits[layer+"_max"])-float(patient.get(layer)),float(definition.restore_amount)*item.quality_multiplier)
	patient.set(layer,float(patient.get(layer))+restored);bay(drone.module_instance_id).repaired_hp+=restored
	if g.owned_fleet.friendly(drone.target_id):g.owned_fleet.sync_health(drone.target_id)
	g.telemetry.repair("provided" if drone.target_id!=g.state.ship().ship_instance_id else "received",restored);g.crew.contribute(drone.owner_id,"repair",restored)
	if drone.owner_id!=g.state.ship().ship_instance_id:g.owned_fleet.total().provided_repair_hp+=restored
	return restored
func observe(drone: RefCounted,target_id: String) -> void:
	var info: Dictionary=query(target_id);var definition: Dictionary=spec(drone.module_instance_id)
	if info.is_empty() or info.get("synthetic",false) or info.kind not in ["npc","resource","signal","marker"] or info.site_id!=drone.site_id or not live_detects(drone,target_id):return
	var record: RefCounted=null
	for existing: RefCounted in g.state.rows("auxiliary_intel_state"):
		if existing.owner_ship_id==drone.owner_id and existing.target_kind==info.kind and existing.target_id==target_id:record=existing;break
	if record==null:record=D.AuxiliaryIntelStateDto.new();record.owner_ship_id=drone.owner_id;record.target_kind=info.kind;record.target_id=target_id;g.state.add("auxiliary_intel_state",record)
	record.module_id=definition.module_id;record.observed_label=str(info.title).left(96);record.sector_id=drone.sector_id;record.site_id=drone.site_id;record.target_generation=info.generation;record.observed_tick=g.state.snapshot.meta.simulation_tick
	record.pos_x=info.position.x;record.pos_y=info.position.y;record.pos_z=info.position.z;record.remaining_units=info.remaining_units
	while g.state.rows("auxiliary_intel_state").size()>int(g.rows("fleet_balance_defs")[0].history_limit):g.state.remove("auxiliary_intel_state",g.state.rows("auxiliary_intel_state")[0])
func live_detects(drone: RefCounted,target_id: String) -> bool:
	if drone.role_kind!="recon" or drone.returning or drone.command_kind!="recon" or not spatial_active or drone.site_id!=Space.current_site(g.state) or not g.drone_control.module_live(drone.owner_id,drone.module_instance_id):return false
	var hull: RefCounted=owner(drone.module_instance_id);var definition: Dictionary=spec(drone.module_instance_id)
	if hull==null or g.position(hull).distance_to(g.position(drone))>float(g.definition("module_defs","module_id",definition.module_id).range_m):return false
	return sight_query.is_valid() and sight_query.call(drone.drone_id,target_id,float(definition.sensor_range_m))
func detected(target_id: String) -> bool:
	for drone: RefCounted in g.drone_control.live.values():
		if live_detects(drone,target_id):return true
	return false
func age(record: RefCounted) -> float:return float(g.state.snapshot.meta.simulation_tick-record.observed_tick)/float(g.rule("simulation_hz"))
func current(record: RefCounted) -> bool:
	return record.sector_id==g.state.current_sector() and record.site_id==Space.current_site(g.state) and age(record)<float(g.definition("auxiliary_drone_defs","module_id",record.module_id).observation_ttl_s)
