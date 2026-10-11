extends RefCounted
## Read-only quotes. Projected fits execute the real fit rules on a private clone.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Budget = preload("res://runtime/gameplay/resource_budget.gd")
const Codec = preload("res://runtime/data/codec.gd")
var g: RefCounted
func _init(game: RefCounted) -> void:g=game
func supported() -> bool:return g!=null and g.catalog.table_names.has("fitting_analysis_defs")
func config() -> Dictionary:return g.rows("fitting_analysis_defs")[0] if supported() else {}
func resistance(archetype: String,layer: String) -> Vector3:
	var result: Vector3=Vector3.ZERO
	for row: Dictionary in g.rows("npc_resistances"):
		if row.archetype_id==archetype and row.layer_id==layer:result[g.damage_index(row.damage_type)]=float(row.resistance)
	return result
func report(distance: float,archetype: String="",layer: String="shield") -> Dictionary:
	if not supported() or not is_finite(distance) or distance<0.0:return {"ok":false,"reason":"分析距离无效"}
	var ship: RefCounted=g.state.ship();var limits: Dictionary=g.metrics(ship);var policy: Dictionary=config()
	var descriptors: Array[Dictionary]=[];var ammunition: Dictionary={};var nominal: float=0.0;var energy_rate: float=0.0;var heat_rate: float=0.0;var ranges: Array[float]=[]
	var cargo: String=g.inventory.hold(ship,T.ContainerKind.CARGO)
	for equipment: RefCounted in g.equipped(ship):
		var spec: Dictionary=g.specializations.weapon_spec(equipment,ship)
		if spec.is_empty():continue
		var item: RefCounted=g.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
		var enabled: bool=equipment.enabled and item!=null and item.durability>0.0
		var pods: int=0;var stock: int=0;var mode: String=""
		var flight: float=0.0;var interval: float=float(spec.cycle_s);var raw: float=float(spec.raw_damage)
		if spec.fire_mode=="drone":
			stock=g.drone_control.stock(ship.ship_instance_id,equipment.item_instance_id)
			pods=mini(stock,int(spec.drone.drone_count));raw*=float(pods)/float(spec.drone.drone_count)
			var bay: RefCounted=g.drone_control.bay(equipment.item_instance_id)
			mode=bay.command_kind if bay!=null else "attack"
			enabled=enabled and pods>0 and mode=="attack"
			flight=maxf(0.0,distance-float(spec.drone.attack_range_m))/float(spec.drone.speed_mps)
			flight+=minf(distance,float(spec.drone.attack_range_m))/float(spec.drone.projectile_speed_mps)
			interval=maxf(interval,2.0*distance/float(spec.drone.speed_mps))
		else:flight=distance/float(spec.projectile_speed_mps) if float(spec.projectile_speed_mps)>0.0 else 0.0
		var ammo_id: String=str(spec.ammo_item_id) if spec.ammo_item_id!=null else ""
		if not ammo_id.is_empty() and not ammunition.has(ammo_id):ammunition[ammo_id]=g.inventory.count(cargo,ammo_id,false)
		var in_range: bool=distance<=float(spec.range_m)
		var vector: Vector3=Vector3.ZERO;vector[g.damage_index(spec.damage_type)]=raw
		var descriptor: Dictionary={"id":equipment.item_instance_id,"module":equipment.module_def_id,"enabled":enabled,"in_range":in_range,"spec":spec,"raw":raw,"vector":vector,"cooldown":0.0,"interval":interval,"flight_s":flight,"ammo":ammo_id,"shots":0,"pods":pods,"stock":stock,"mode":mode}
		descriptors.append(descriptor)
		if enabled:
			nominal+=raw/interval;energy_rate+=float(spec.energy_eu)/interval;heat_rate+=float(spec.heat_hu)/interval;ranges.append(float(spec.range_m))
	var resistance_vector: Vector3=resistance(archetype,layer)
	var simulated: D.ShipStateDto=D.ShipStateDto.new();simulated.energy=limits.energy_max
	var step: float=1.0/g.rule("simulation_hz");var time: float=0.0;var shots: Array[Dictionary]=[];var first_energy: float=-1.0;var first_heat: float=-1.0;var first_ammo: float=-1.0
	var minimum_energy: float=simulated.energy;var maximum_heat: float=0.0
	while time<float(policy.horizon_s)-step*0.25:
		Budget.advance(simulated,limits,step,g.rule("overheat_unlock_ratio"))
		for descriptor: Dictionary in descriptors:
			descriptor.cooldown=maxf(0.0,float(descriptor.cooldown)-step)
			if not descriptor.enabled or not descriptor.in_range or float(descriptor.cooldown)>0.0:continue
			var spec: Dictionary=descriptor.spec
			if not str(descriptor.ammo).is_empty() and int(ammunition[descriptor.ammo])<int(spec.ammo_per_cycle):
				if first_ammo<0.0:first_ammo=time
				continue
			var blocked: String=Budget.blocked(simulated.energy,simulated.heat,simulated.overheated,limits.heat_max,spec.energy_eu,spec.heat_hu)
			if not blocked.is_empty():
				if blocked=="能量不足" and first_energy<0.0:first_energy=time
				if blocked=="热量已达到限制":
					simulated.overheated=true
					if first_heat<0.0:first_heat=time
				continue
			simulated.energy-=float(spec.energy_eu);simulated.heat+=float(spec.heat_hu)
			if not str(descriptor.ammo).is_empty():ammunition[descriptor.ammo]-=int(spec.ammo_per_cycle)
			descriptor.cooldown=float(descriptor.interval);descriptor.shots+=1
			var effective: Vector3=(descriptor.vector as Vector3)*(Vector3.ONE-resistance_vector)
			shots.append({"fired":time,"arrived":time+float(descriptor.flight_s),"raw":descriptor.raw,"effective":effective.x+effective.y+effective.z})
		minimum_energy=minf(minimum_energy,simulated.energy);maximum_heat=maxf(maximum_heat,simulated.heat);time+=step
	var burst: float=0.0;var sustained: float=0.0;var total: float=0.0;var arrived: float=0.0;var arrival_burst: float=0.0
	for shot: Dictionary in shots:
		total+=float(shot.raw)
		if shot.fired<float(policy.burst_window_s):burst+=float(shot.raw)
		if shot.fired>=float(policy.sustained_window_s):sustained+=float(shot.raw)
		if shot.arrived<float(policy.horizon_s):arrived+=float(shot.effective)
		if shot.arrived<float(policy.burst_window_s):arrival_burst+=float(shot.effective)
	var weapons: Array[Dictionary]=[]
	for row: Dictionary in descriptors:
		weapons.append({"item_id":row.id,"module_id":row.module,"enabled":row.enabled,"in_range":row.in_range,"range_m":row.spec.range_m,"cone_rad":row.spec.fire_cone_half_angle_rad,"flight_s":row.flight_s,"cycle_s":row.interval,"damage":row.raw,"energy_eu":row.spec.energy_eu,"heat_hu":row.spec.heat_hu,"shots":row.shots,"pods":row.pods,"stock":row.stock,"mode":row.mode})
	return {"ok":true,"distance_m":distance,"archetype":archetype,"layer":layer,"resistance":resistance_vector,"metrics":limits,"nominal_dps":nominal,"burst_damage":burst,"sustained_dps":sustained/(float(policy.horizon_s)-float(policy.sustained_window_s)),"average_dps":total/float(policy.horizon_s),"conditional_dps":arrived/float(policy.horizon_s),"conditional_burst":arrival_burst,"energy_rate":energy_rate,"heat_rate":heat_rate,"first_energy_stall_s":first_energy,"first_heat_stall_s":first_heat,"first_ammo_stall_s":first_ammo,"minimum_energy":minimum_energy,"maximum_heat":maximum_heat,"energy_remaining":simulated.energy,"heat_remaining":simulated.heat,"ammunition_remaining":ammunition,"weapons":weapons,"ranges":ranges,"tuning":g.specializations.modifiers(ship),"burst_window_s":policy.burst_window_s,"horizon_s":policy.horizon_s,"sustained_span_s":float(policy.horizon_s)-float(policy.sustained_window_s)}
func quote(item_id: String,slot_ref: String,distance: float,archetype: String="",layer: String="shield") -> Dictionary:
	var rejected: Dictionary={"ok":false,"reason":"","current":report(distance,archetype,layer)}
	if not supported() or g.state.ship().status!=T.ShipStatus.DOCKED or g.state.ship().policy_id!="normal_owned":rejected.reason="需要停靠并驾驶普通自有舰船";return rejected
	var item: RefCounted=g.state.find("item_instance_state","item_instance_id",item_id)
	if item==null or item.owner_player_id!=g.state.player().player_id or item.policy_id!="normal_owned" or not g.inventory.accessible(item.container_id):rejected.reason="比较设备必须是当前站点或本舰的普通自有设备";return rejected
	var pieces: PackedStringArray=slot_ref.split(":")
	if pieces.size()!=2 or not pieces[1].is_valid_int():rejected.reason="槽位标识无效";return rejected
	var slot: RefCounted=g.inventory.slot(g.state.ship(),pieces[0],int(pieces[1]))
	if slot==null:rejected.reason="槽位不存在";return rejected
	var old: RefCounted=g.state.find("equipment_state","slot_container_id",slot.container_id)
	var old_id: String=old.item_instance_id if old!=null else ""
	if old_id==item_id:rejected.ok=true;rejected.reason="当前已安装此设备";rejected.preview=rejected.current;rejected.old_item_id=old_id;return rejected
	if g.state.find("equipment_state","item_instance_id",item_id)!=null:rejected.reason="设备已安装在其他槽位";return rejected
	if old!=null and g.state.find("item_instance_state","item_instance_id",old_id).policy_id!="normal_owned":rejected.reason="绑定设备不能被普通方案替换";return rejected
	var clone: XJRuntimeState=Codec.new().clone(g.state)
	var projected: RefCounted=g.get_script().new();projected.setup(clone,g.catalog,true)
	var removed: bool=old==null or projected.inventory.unfit(old_id)
	var fitted: bool=removed and projected.inventory.fit(item_id,0,slot_ref)
	if not fitted:rejected.reason=projected.last_error;projected.dispose();return rejected
	var preview: Dictionary=projected.fitting_analysis.report(distance,archetype,layer)
	projected.dispose()
	return {"ok":true,"reason":"","current":rejected.current,"preview":preview,"old_item_id":old_id,"item_id":item_id,"slot_ref":slot_ref}
