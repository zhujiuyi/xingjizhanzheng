extends RefCounted
## Staged operations and coarse strategic events. Physical movement stays in pilots.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Rng = preload("res://runtime/rng.gd")
var g: RefCounted
var balance: Dictionary={}
var _spawns: Dictionary={}
signal warning_changed(message: String)

func _init(game: RefCounted) -> void:
	g=game
	if not supported():return
	balance=g.rows("frontier_balance_defs")[0]
	for actor: Dictionary in g.rows("frontier_actor_defs"):_spawns[str(actor.spawn_id)]=actor
	for beacon: Dictionary in g.rows("frontier_beacon_defs"):_spawns[str(beacon.spawn_id)]={"spawn_id":beacon.spawn_id,"war_id":null,"sector_id":beacon.sector_id,"actor_role":"beacon","hull_id":beacon.hull_id}
func supported() -> bool:return g!=null and g.catalog.table_names.has("frontier_campaign_defs")
func campaign(id: String) -> RefCounted:return g.state.find("frontier_campaign_state","war_id",id)
func territory(id: String) -> RefCounted:return g.state.find("frontier_territory_state","sector_id",id)
func director() -> RefCounted:return g.state.rows("frontier_director_state")[0] if supported() else null
func actor(id: String) -> RefCounted:return g.state.find("frontier_actor_state","npc_instance_id",id)
func definition(id: String) -> Dictionary:return g.definition("frontier_campaign_defs","war_id",id)
func handles_spawn(id: String) -> bool:return supported() and _spawns.has(id)
func is_structure(id: String) -> bool:return handles_spawn(id) and str(_spawns[id].actor_role) in ["structure","beacon"]
func owns_campaign(war: RefCounted) -> bool:
	if not supported() or war==null:return false
	var row: RefCounted=campaign(war.war_id)
	return row!=null and row.attempt==war.attempt and row.legacy_attempt!=war.attempt and row.phase not in ["idle","legacy"]
func friendly(id: String) -> bool:
	if not supported():return false
	var a: RefCounted=actor(id)
	if a==null or a.actor_role not in ["convoy","beacon"]:return false
	if a.has_war_id:
		var war: RefCounted=g.state.find("war_campaign_state","war_id",a.war_id)
		var spec: Dictionary=g.definition("civilization_war_defs","war_id",a.war_id)
		return war!=null and war.attempt==a.generation and war.status in ["assembling","fighting","occupying"] and spec.faction_id==g.civilizations.allegiance()
	var row: RefCounted=territory(a.sector_id)
	return row!=null and row.phase=="defending" and row.crisis_generation==a.generation and g.civilizations.owner(a.sector_id)==g.civilizations.allegiance()
func model(id: String) -> String:
	var a: RefCounted=actor(id)
	if a==null:return ""
	var n: RefCounted=g.state.find("npc_state","npc_instance_id",id)
	var spec: Dictionary=_spawns.get(str(n.spawn_id),{}) if n!=null else {}
	return str(spec.hull_id) if spec.get("hull_id")!=null else ""

static func initial_rows(catalog: XJCatalog,state: XJRuntimeState) -> Dictionary:
	var result: Dictionary={"frontier_campaign_state":[],"frontier_territory_state":[],"frontier_journal_state":[],"frontier_director_state":[]}
	if not catalog.table_names.has("frontier_campaign_defs"):return result
	var limits: Dictionary=catalog.rows("frontier_balance_defs")[0]
	for spec: Dictionary in catalog.rows("frontier_campaign_defs"):
		var row: RefCounted=D.FrontierCampaignStateDto.new();row.war_id=spec.war_id
		var war: RefCounted=state.find("war_campaign_state","war_id",spec.war_id)
		if war!=null:
			row.attempt=war.attempt;row.legacy_attempt=war.attempt
			row.phase="legacy" if war.status in ["assembling","fighting","occupying"] else "completed" if war.status=="won" else war.status
		result.frontier_campaign_state.append(row)
	for spec: Dictionary in catalog.rows("frontier_governance_defs"):
		var row: RefCounted=D.FrontierTerritoryStateDto.new();row.sector_id=spec.sector_id
		var owner: RefCounted=state.find("territory_state","sector_id",spec.sector_id)
		if owner!=null and owner.has_faction_id:
			row.phase="controlled";row.revision=1;row.reserve_units=int(limits.reserve_max_units)
			for war: RefCounted in state.rows("war_campaign_state"):
				var w: Dictionary=catalog.one("civilization_war_defs","war_id",war.war_id)
				if war.status!="won" or w.target_sector_id!=spec.sector_id or w.faction_id!=owner.faction_id:continue
				var receipt: RefCounted=D.FrontierJournalStateDto.new();receipt.source_token="import:"+spec.sector_id;receipt.sector_id=spec.sector_id;receipt.revision=1;receipt.event_kind="import"
				receipt.has_faction_id=true;receipt.faction_id=owner.faction_id;receipt.has_war_id=true;receipt.war_id=war.war_id;receipt.attempt=war.attempt;receipt.event_tick=state.snapshot.meta.simulation_tick
				result.frontier_journal_state.append(receipt);break
		result.frontier_territory_state.append(row)
	var d: RefCounted=D.FrontierDirectorStateDto.new();d.player_id=state.player().player_id;d.next_event_s=float(limits.crisis_max_s);result.frontier_director_state.append(d)
	return result

func quote_reason(id: String) -> String:
	if not supported():return ""
	if g.inventory.count(g.inventory.warehouse(g.station()),balance.material_id,true)<int(balance.supply_units):return "核心站仓库需普通结构料 × %d" % int(balance.supply_units)
	return ""
func pay_begin(id: String) -> bool:
	if not supported():return true
	var reason: String=quote_reason(id)
	if not reason.is_empty():return g.fail(reason)
	if not g.inventory.consume(g.inventory.warehouse(g.station()),balance.material_id,int(balance.supply_units),true):return g.fail("战役补给物资已变化")
	var war: RefCounted=g.state.find("war_campaign_state","war_id",id);var row: RefCounted=campaign(id)
	row.attempt=1 if war==null else war.attempt+1;row.phase="scouting";row.survey_paid=false;row.survey_remaining_s=0.0
	row.supplies_paid_units=int(balance.supply_units);row.supply_delivered=false;row.repair_paid_units=0;row.repair_remaining_s=0.0;row.hold_remaining_s=float(balance.hold_s);row.demolition_units=0
	_receipt(row,"register",0,int(balance.supply_units));return true
func begin(war: RefCounted) -> void:
	if not supported():return
	for npc: RefCounted in g.civilizations.living_fleet(war,"ally")+g.civilizations.living_fleet(war,"defender"):_dormant(npc)
	_trigger_demand(g.definition("civilization_defs","faction_id",g.civilizations.allegiance()).capital_station_id)
	warning_changed.emit("战役准备 · 前往边疆侦察；补给已在战区集结")
func _dormant(npc: RefCounted) -> void:
	npc.alive=false;npc.shield=0.0;npc.armor=0.0;npc.hull=0.0;npc.behavior_phase=T.NpcPhase.DEAD;npc.bounty_claimed=true
func _revive(npc: RefCounted) -> void:
	var spec: Dictionary=g.definition("npc_full_defs","npc_id",g.definition("npc_spawn_defs","spawn_id",npc.spawn_id).npc_id)
	npc.alive=true;npc.shield=spec.shield_max;npc.armor=spec.armor_max;npc.hull=spec.hull_max;npc.behavior_phase=T.NpcPhase.PATROL;npc.cooldown_remaining_s=0.0
func _receipt(row: RefCounted,kind: String,units: int=0,material: int=0,token: String="",credit: int=0,rep: int=0) -> void:
	var receipt: RefCounted=D.FrontierCampaignReceiptStateDto.new()
	receipt.source_token=token if not token.is_empty() else "%s:%d:%s" % [row.war_id,row.attempt,kind]
	if g.state.find("frontier_campaign_receipt_state","source_token",receipt.source_token)!=null:return
	receipt.war_id=row.war_id;receipt.attempt=row.attempt;receipt.event_kind=kind;receipt.units=units;receipt.material_units=material;receipt.reward_credit=credit;receipt.reward_reputation=rep;receipt.event_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("frontier_campaign_receipt_state",receipt)
func _spawn(spawn_id: String,war_id: String,generation: int) -> RefCounted:
	var spec: Dictionary=_spawns[spawn_id];var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",spawn_id);var at: Dictionary=g.definition("anchor_defs","anchor_id",spawn.anchor_id)
	var n: RefCounted=D.NpcStateDto.new();n.npc_instance_id=g.id("frontier_actor");n.spawn_id=spawn_id;n.sector_id=spawn.sector_id;n.generation=generation;n.pos_x=at.x_m;n.pos_y=at.y_m;n.pos_z=at.z_m
	_revive(n);g.state.add("npc_state",n);g.assign_anchor_site("npc",n.npc_instance_id,spawn.anchor_id)
	var a: RefCounted=D.FrontierActorStateDto.new();a.npc_instance_id=n.npc_instance_id;a.has_war_id=not war_id.is_empty();a.war_id=war_id;a.sector_id=spawn.sector_id;a.generation=generation;a.actor_role=spec.actor_role
	g.state.add("frontier_actor_state",a);return n
func _clear_actors(war_id: String,sector_id: String="") -> void:
	for a: RefCounted in g.state.rows("frontier_actor_state").duplicate():
		if (not war_id.is_empty() and a.war_id==war_id) or (war_id.is_empty() and not a.has_war_id and a.sector_id==sector_id):
			var n: RefCounted=g.state.find("npc_state","npc_instance_id",a.npc_instance_id);g.state.remove("frontier_actor_state",a)
			if n!=null:g.remove_npc(n)
func _actor_for(war_id: String,kind: String,sector_id: String="") -> RefCounted:
	for a: RefCounted in g.state.rows("frontier_actor_state"):
		if a.actor_role==kind and ((not war_id.is_empty() and a.war_id==war_id) or (war_id.is_empty() and not a.has_war_id and a.sector_id==sector_id)):return g.state.find("npc_state","npc_instance_id",a.npc_instance_id)
	return null
func _at(anchor_id: String,radius: float) -> bool:
	var at: Dictionary=g.definition("anchor_defs","anchor_id",anchor_id)
	return g.state.ship().status==T.ShipStatus.FLYING and g.same_anchor_site(g.state.ship(),at) and g.anchor_distance(g.state.ship(),at)<=radius
func action_reason(id: String,action: String) -> String:
	if not supported():return "当前世界尚未升级边疆规则"
	var row: RefCounted=campaign(id)
	if row==null:return _governance_reason(id,action)
	var war: RefCounted=g.civilizations.active_war();var spec: Dictionary=definition(id);var w: Dictionary=g.definition("civilization_war_defs","war_id",id)
	if war==null or war.war_id!=id or not owns_campaign(war):return "此战役不在新版活动阶段"
	if action=="survey":
		if row.phase!="scouting" or row.survey_paid:return "侦察已开始或当前阶段不符"
		if not _at(spec.scout_anchor_id,float(balance.survey_radius_m)):return "实际接近侦察点后调查"
		if g.state.ship().energy<float(balance.survey_energy_eu) or g.state.ship().heat+float(balance.survey_heat_hu)>float(g.metrics(g.state.ship()).heat_max):return "侦察电容或热量余量不足"
		return ""
	if action=="repair":
		if row.phase!="rebuilding" or row.repair_paid_units>0:return "修复已投入或当前阶段不符"
		if not _at(w.capture_anchor_id,float(balance.repair_radius_m)):return "实际接近占领点后修复"
		if g.inventory.count(g.inventory.hold(g.state.ship(),T.ContainerKind.CARGO),balance.material_id,true)<int(balance.rebuild_units):return "当前普通货舱需结构料 × %d" % int(balance.rebuild_units)
		return ""
	return "未知战役操作"
func execute(id: String,action: String,quantity: int,expected: String) -> bool:
	var row: RefCounted=campaign(id)
	var current: String=str(row.attempt)+":"+str(row.phase) if row!=null else _governance_token(id)
	if expected!=current:return g.fail("边疆状态已变化，请重新查看")
	var reason: String=action_reason(id,action)
	if not reason.is_empty():return g.fail(reason)
	if row==null:return _governance_execute(id,action,quantity)
	if action=="survey":
		g.state.ship().energy-=float(balance.survey_energy_eu);g.state.ship().heat+=float(balance.survey_heat_hu)
		row.survey_paid=true;row.survey_remaining_s=float(balance.survey_s)/g.ship_roles.survey_rate()
	else:
		if not g.inventory.consume(g.inventory.hold(g.state.ship(),T.ContainerKind.CARGO),balance.material_id,int(balance.rebuild_units),true):return g.fail("修复材料已变化")
		row.repair_paid_units=int(balance.rebuild_units);row.repair_remaining_s=float(balance.rebuild_s);_receipt(row,"repair",0,int(balance.rebuild_units))
	g.request_autosave();return true
func tick_campaign(delta: float,war: RefCounted) -> void:
	var row: RefCounted=campaign(war.war_id);var spec: Dictionary=definition(war.war_id);var w: Dictionary=g.definition("civilization_war_defs","war_id",war.war_id)
	if g.state.ship().status==T.ShipStatus.DESTROYED:_fail(war,"failed");return
	if row.phase=="scouting":
		if row.survey_paid and _at(spec.scout_anchor_id,float(balance.survey_radius_m)):
			row.survey_remaining_s=maxf(0.0,row.survey_remaining_s-delta)
			if row.survey_remaining_s<=0.0:
				_receipt(row,"survey",1);row.phase="escorting"
				for a: Dictionary in g.rows("frontier_actor_defs"):
					if a.war_id==war.war_id and a.actor_role in ["convoy","ambusher"]:_spawn(a.spawn_id,war.war_id,row.attempt)
				warning_changed.emit("补给舰已集结 · 护送并保护它抵达登陆点");g.request_autosave()
	elif row.phase=="escorting":
		var convoy: RefCounted=_actor_for(war.war_id,"convoy")
		if convoy==null or not convoy.alive:_fail(war,"failed");return
		var at: Dictionary=g.definition("anchor_defs","anchor_id",spec.convoy_exit_anchor_id)
		if g.same_anchor_site(convoy,at) and g.same_entity_site("ship",g.state.ship(),"npc",convoy) and g.position(convoy).distance_to(g.anchor_position(at))<=float(balance.arrival_radius_m):
			row.supply_delivered=true;_receipt(row,"supply",int(balance.supply_units));_clear_actors(war.war_id)
			for member: RefCounted in g.state.rows("war_fleet_state"):
				if member.war_id!=war.war_id:continue
				var npc: RefCounted=g.state.find("npc_state","npc_instance_id",member.npc_instance_id);_revive(npc)
				if member.side=="ally":
					# Reinforcements assemble with the physical escort. Reuse the
					# existing fleet spacing rather than an unrelated old spawn pose.
					var formation: Dictionary=g.definition("civilization_war_members","spawn_id",npc.spawn_id)
					var separation: float=g.rule("civilization_fleet_regroup_m")
					var ship: RefCounted=g.state.ship();var attitude: Basis=Basis(Quaternion(ship.quat_x,ship.quat_y,ship.quat_z,ship.quat_w))
					var position: Vector3=g.position(ship)+attitude*Vector3((float(formation.formation_index)-1.0)*separation*0.4,separation*0.1,separation)
					npc.pos_x=position.x;npc.pos_y=position.y;npc.pos_z=position.z
			row.phase=str(spec.battle_kind);war.status="fighting"
			for a: Dictionary in g.rows("frontier_actor_defs"):
				if a.war_id==war.war_id and a.actor_role=="structure":_spawn(a.spawn_id,war.war_id,row.attempt)
			warning_changed.emit("补给入场 · "+("守住登陆点与援军" if row.phase=="hold" else "拆除两座制压装置"));g.request_autosave()
	elif row.phase in ["hold","demolition"]:
		if g.civilizations.living_fleet(war,"ally").is_empty():_fail(war,"failed");return
		if row.phase=="hold":
			row.hold_remaining_s=maxf(0.0,row.hold_remaining_s-delta) if _at(w.capture_anchor_id,float(w.capture_radius_m)) else float(balance.hold_s)
			if row.hold_remaining_s<=0.0:_receipt(row,"hold",1);_rebuilding(war,row)
		elif row.demolition_units==int(spec.structure_count):_rebuilding(war,row)
	elif row.phase=="rebuilding" and row.repair_paid_units>0 and _at(w.capture_anchor_id,float(balance.repair_radius_m)):
		row.repair_remaining_s=maxf(0.0,row.repair_remaining_s-delta)
		if row.repair_remaining_s<=0.0:_capture(war,row)
func destroyed(npc: RefCounted) -> void:
	var a: RefCounted=actor(npc.npc_instance_id)
	if a==null or a.actor_role!="structure" or not a.has_war_id:return
	var row: RefCounted=campaign(a.war_id)
	if row==null or row.attempt!=a.generation or row.phase!="demolition":return
	var token: String="structure:"+npc.npc_instance_id
	if g.state.find("frontier_campaign_receipt_state","source_token",token)!=null:return
	row.demolition_units+=1;_receipt(row,"structure",1,0,token)
func _rebuilding(war: RefCounted,row: RefCounted) -> void:
	row.phase="rebuilding";war.status="occupying";_clear_actors(war.war_id)
	for member: RefCounted in g.state.rows("war_fleet_state"):
		if member.war_id==war.war_id:_dormant(g.state.find("npc_state","npc_instance_id",member.npc_instance_id))
	warning_changed.emit("战斗目标完成 · 携带结构料修复登陆设施后登记主权");g.request_autosave()
func _capture(war: RefCounted,row: RefCounted) -> void:
	var w: Dictionary=g.definition("civilization_war_defs","war_id",war.war_id);var control: RefCounted=g.state.find("territory_state","sector_id",w.target_sector_id);var governed: RefCounted=territory(w.target_sector_id)
	if control.has_faction_id:_fail(war,"failed");return
	var prior: bool=false
	for j: RefCounted in g.state.rows("frontier_journal_state"):
		if j.sector_id==w.target_sector_id and j.faction_id==w.faction_id and j.event_kind in ["capture","import"]:prior=true
	var credit: int=int(balance.recapture_credit if prior else w.reward_credit);var rep: int=int(balance.recapture_reputation if prior else w.reward_reputation)
	control.has_faction_id=true;control.faction_id=w.faction_id;control.captured_tick=g.state.snapshot.meta.simulation_tick
	governed.phase="controlled";governed.revision+=1;governed.reserve_units=int(balance.supply_units)
	_journal(governed,"capture",w.faction_id,war.war_id,war.attempt,0,"",credit,rep)
	_receipt(row,"capture",1,0,"",credit,rep);g.state.player().credit+=credit;g.civilizations._add_reputation(w.faction_id,rep)
	row.phase="completed";war.rewards_claimed=true;g.civilizations._finish(war,"won");_trigger_demand(g.definition("frontier_governance_defs","sector_id",governed.sector_id).station_id)
func _fail(war: RefCounted,status: String) -> void:
	var row: RefCounted=campaign(war.war_id);row.phase=status;row.survey_remaining_s=0.0;row.repair_remaining_s=0.0
	_receipt(row,status);_clear_actors(war.war_id);g.civilizations._finish(war,status)
func cancelled(war: RefCounted) -> void:
	if owns_campaign(war):
		var row: RefCounted=campaign(war.war_id);row.phase="cancelled";row.survey_remaining_s=0.0;row.repair_remaining_s=0.0;_receipt(row,"cancelled");_clear_actors(war.war_id)
func legacy_finished(war: RefCounted,status: String) -> void:
	if not supported():return
	var row: RefCounted=campaign(war.war_id)
	if row==null or row.legacy_attempt!=war.attempt:return
	row.phase="completed" if status=="won" else status
	if status!="won":return
	var spec: Dictionary=g.definition("civilization_war_defs","war_id",war.war_id);var governed: RefCounted=territory(spec.target_sector_id)
	if governed.revision>0:return
	governed.phase="controlled";governed.revision=1;governed.reserve_units=int(balance.reserve_max_units)
	_journal(governed,"import",spec.faction_id,war.war_id,war.attempt)
func _journal(row: RefCounted,kind: String,faction: String,war_id: String="",attempt: int=0,units: int=0,order_id: String="",credit: int=0,rep: int=0) -> void:
	var j: RefCounted=D.FrontierJournalStateDto.new();j.source_token=g.id("frontier_journal");j.sector_id=row.sector_id;j.revision=row.revision;j.event_kind=kind
	j.has_faction_id=not faction.is_empty();j.faction_id=faction;j.has_war_id=not war_id.is_empty();j.war_id=war_id;j.attempt=attempt;j.crisis_generation=row.crisis_generation
	j.has_supply_order_id=not order_id.is_empty();j.supply_order_id=order_id;j.units=units;j.reward_credit=credit;j.reward_reputation=rep;j.event_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("frontier_journal_state",j)
func _governance_token(id: String) -> String:
	var row: RefCounted=territory(id)
	return "%d:%d:%s:%d" % [row.revision,row.crisis_generation,row.phase,row.reserve_units] if row!=null else ""
func _local_container(id: String) -> String:
	var spec: Dictionary=g.definition("frontier_governance_defs","sector_id",id)
	if g.station()==spec.get("station_id",""):return g.inventory.warehouse(g.station())
	if _at(spec.get("defense_anchor_id",""),float(balance.repair_radius_m)):return g.inventory.hold(g.state.ship(),T.ContainerKind.CARGO)
	return ""
func pressure_units(faction: String) -> int:
	var count: int=0
	for row: RefCounted in g.state.rows("frontier_territory_state"):
		if g.civilizations.owner(row.sector_id)==faction:count+=1
	return mini(int(balance.reserve_max_units),int(balance.crisis_supply_base_units)+maxi(0,count-1)*int(balance.crisis_supply_per_extra_territory))
func _governance_reason(id: String,action: String) -> String:
	var row: RefCounted=territory(id)
	if row==null:return "此星系不属于可治理边疆"
	var owner: String=g.civilizations.owner(id)
	if owner.is_empty() or owner!=g.civilizations.allegiance():return "需要效忠当前管辖文明"
	var spec: Dictionary=g.definition("frontier_governance_defs","sector_id",id)
	match action:
		"defend":
			if row.phase!="warning":return "当前没有等待响应的边疆预警"
			if g.civilizations.active_war()!=null:return "先完成或撤出进行中的远征"
			if not _at(spec.defense_anchor_id,float(balance.escort_radius_m)):return "实际抵达边疆防守点后部署"
		"secure":
			if row.phase!="warning" or row.reserve_units<pressure_units(owner):return "当前预警需要更多驻防补给"
		"supply":
			if _local_container(id).is_empty():return "停靠当地站点或实际接近防守点后交付"
			if row.reserve_units>=int(balance.reserve_max_units):return "驻防补给已满"
		"dispatch":
			var reason: String=g.civilizations.capital_reason(owner)
			if not reason.is_empty():return reason
			if row.reserve_units>=int(balance.reserve_max_units):return "驻防补给已满"
			var count: int=0
			for order: RefCounted in g.state.rows("frontier_supply_order_state"):
				if order.sector_id==id and order.phase=="inflight":count+=1
			if count>=int(balance.max_supply_orders):return "此边疆已有足够的在途补给订单"
			if g.state.player().credit<int(balance.dispatch_fee_credit):return "战略运输费用不足"
		_:return "未知治理操作"
	return ""
func quantity_reason(id: String,action: String,quantity: int) -> String:
	if action not in ["supply","dispatch"]:return ""
	var row: RefCounted=territory(id)
	var incoming: int=0
	for order: RefCounted in g.state.rows("frontier_supply_order_state"):
		if order.sector_id==id and order.phase=="inflight" and order.faction_id==g.civilizations.owner(id):incoming+=order.units
	if row==null or quantity<1 or quantity>int(balance.reserve_max_units)-row.reserve_units-incoming:return "补给批数超出扣除在途订单后的空余容量"
	var container: String=g.inventory.warehouse(g.station()) if action=="dispatch" else _local_container(id)
	if container.is_empty() or g.inventory.count(container,balance.material_id,true)<quantity:return "交接地点的普通自有结构料不足"
	return ""
func _governance_execute(id: String,action: String,quantity: int) -> bool:
	var reason: String=quantity_reason(id,action,quantity)
	if not reason.is_empty():return g.fail(reason)
	var row: RefCounted=territory(id);var owner: String=g.civilizations.owner(id)
	match action:
		"defend":
			row.phase="defending";row.warning_remaining_s=0.0;row.defense_remaining_s=float(balance.defense_s);row.hold_remaining_s=float(balance.hold_s)
			var beacon: Dictionary=g.definition("frontier_governance_defs","sector_id",id);_spawn(beacon.beacon_spawn_id,"",row.crisis_generation)
			for spec: Dictionary in g.rows("frontier_actor_defs"):
				if spec.sector_id==id and spec.actor_role=="raider":_spawn(spec.spawn_id,"",row.crisis_generation)
			warning_changed.emit("边疆防守 · 守住信标与范围 %.0f 秒" % float(balance.hold_s))
		"secure":_resolve_crisis(row,false)
		"supply", "dispatch":
			var container: String=g.inventory.warehouse(g.station()) if action=="dispatch" else _local_container(id)
			if not g.inventory.consume(container,balance.material_id,quantity,true):return g.fail("普通补给物资已变化")
			if action=="supply":
				row.reserve_units+=quantity;_journal(row,"supply",owner,"",0,quantity)
				if row.phase in ["warning","defending"] and row.reserve_units>=pressure_units(owner):_resolve_crisis(row,false)
			else:
				var order: RefCounted=D.FrontierSupplyOrderStateDto.new();order.order_id=g.id("frontier_supply");order.sector_id=id;order.faction_id=owner;order.units=quantity;order.paid_credit=int(balance.dispatch_fee_credit);order.remaining_s=float(balance.dispatch_s);order.created_tick=g.state.snapshot.meta.simulation_tick
				g.state.player().credit-=order.paid_credit;g.state.add("frontier_supply_order_state",order)
				warning_changed.emit("战略补给已发出 · %d份 / %.0f秒" % [quantity,order.remaining_s])
	g.request_autosave();return true
func tick(delta: float) -> void:
	if not supported() or delta<=0.0:return
	for order: RefCounted in g.state.rows("frontier_supply_order_state"):
		if order.phase!="inflight":continue
		order.remaining_s=maxf(0.0,order.remaining_s-delta)
		if order.remaining_s>0.0:continue
		order.finished_tick=g.state.snapshot.meta.simulation_tick
		var row: RefCounted=territory(order.sector_id)
		if row==null or g.civilizations.owner(order.sector_id)!=order.faction_id:order.phase="lost";continue
		var units: int=mini(order.units,int(balance.reserve_max_units)-row.reserve_units);row.reserve_units+=units;order.phase="delivered"
		_journal(row,"supply",order.faction_id,"",0,units,order.order_id)
		if row.phase in ["warning","defending"] and row.reserve_units>=pressure_units(order.faction_id):_resolve_crisis(row,false)
		g.request_autosave()
	var d: RefCounted=director()
	if d.has_active_sector_id:
		var row: RefCounted=territory(d.active_sector_id)
		if g.civilizations.owner(row.sector_id)!=d.active_faction_id:
			_loss(row);return
		if g.civilizations.allegiance()!=d.active_faction_id:
			_clear_actors("",row.sector_id);row.phase="controlled";row.warning_remaining_s=0.0;row.defense_remaining_s=0.0;row.hold_remaining_s=0.0;_reset_director();return
		if row.phase=="warning":
			row.warning_remaining_s=maxf(0.0,row.warning_remaining_s-delta)
			if row.warning_remaining_s<=0.0:_loss(row)
		elif row.phase=="defending":
			var beacon: RefCounted=_actor_for("","beacon",row.sector_id)
			row.defense_remaining_s=maxf(0.0,row.defense_remaining_s-delta)
			if beacon==null or not beacon.alive or row.defense_remaining_s<=0.0:_loss(row);return
			var spec: Dictionary=g.definition("frontier_governance_defs","sector_id",row.sector_id)
			row.hold_remaining_s=maxf(0.0,row.hold_remaining_s-delta) if _at(spec.defense_anchor_id,float(balance.escort_radius_m)) else float(balance.hold_s)
			if row.hold_remaining_s<=0.0:_resolve_crisis(row,true)
		return
	var eligible: Array[RefCounted]=[]
	for row: RefCounted in g.state.rows("frontier_territory_state"):
		if row.phase=="controlled" and not g.civilizations.allegiance().is_empty() and g.civilizations.owner(row.sector_id)==g.civilizations.allegiance():eligible.append(row)
	if eligible.is_empty() or g.civilizations.active_war()!=null:return
	d.next_event_s=maxf(0.0,d.next_event_s-delta)
	if d.next_event_s<=0.0:
		eligible.sort_custom(func(a: RefCounted,b: RefCounted)->bool:return a.sector_id<b.sector_id)
		var rng: RefCounted=Rng.new(g.state.rows("rng_state")[0]);var row: RefCounted=eligible[rng.bounded(eligible.size())]
		row.phase="warning";row.crisis_generation+=1;row.warning_remaining_s=float(balance.warning_s)
		d.has_active_sector_id=true;d.active_sector_id=row.sector_id;d.has_active_faction_id=true;d.active_faction_id=g.civilizations.owner(row.sector_id)
		_journal(row,"warning",d.active_faction_id);_trigger_demand(g.definition("frontier_governance_defs","sector_id",row.sector_id).station_id)
		warning_changed.emit("边疆预警 · %s · %.0f秒内补给或到场防守" % [g.missions._sector_title(row.sector_id),row.warning_remaining_s]);g.request_autosave()
func _reset_director() -> void:
	var d: RefCounted=director();d.has_active_sector_id=false;d.active_sector_id="";d.has_active_faction_id=false;d.active_faction_id=""
	var rng: RefCounted=Rng.new(g.state.rows("rng_state")[0]);var width: int=int(balance.crisis_max_s)-int(balance.crisis_min_s)
	d.next_event_s=float(balance.crisis_min_s)+float(rng.bounded(width+1))
func _resolve_crisis(row: RefCounted,combat: bool) -> void:
	var owner: String=g.civilizations.owner(row.sector_id)
	var units: int=0 if combat else pressure_units(owner)
	if row.reserve_units<units:return
	row.reserve_units-=units;row.phase="controlled";row.warning_remaining_s=0.0;row.defense_remaining_s=0.0;row.hold_remaining_s=0.0
	var credit: int=int(balance.defense_credit) if combat else 0;var rep: int=int(balance.defense_reputation) if combat else 0
	_journal(row,"defense",owner,"",0,units,"",credit,rep);g.state.player().credit+=credit;g.civilizations._add_reputation(owner,rep)
	_clear_actors("",row.sector_id);_reset_director();warning_changed.emit("边疆防守成功" if combat else "驻防补给已保障 · 主权保持");g.request_autosave()
func _loss(row: RefCounted) -> void:
	var control: RefCounted=g.state.find("territory_state","sector_id",row.sector_id)
	control.has_faction_id=false;control.faction_id="";control.captured_tick=0
	row.phase="neutral";row.revision+=1;row.reserve_units=0;row.warning_remaining_s=0.0;row.defense_remaining_s=0.0;row.hold_remaining_s=0.0
	for order: RefCounted in g.state.rows("frontier_supply_order_state"):
		if order.sector_id==row.sector_id and order.phase=="inflight":order.phase="lost";order.remaining_s=0.0;order.finished_tick=g.state.snapshot.meta.simulation_tick
	_journal(row,"loss","");_clear_actors("",row.sector_id);_reset_director();warning_changed.emit("边疆失守 · 星系回到中立，可重新整备收复");g.request_autosave()
func station_factor(station_id: String,kind: String) -> float:
	if not supported():return 1.0
	var spec: Dictionary=g.definition("frontier_governance_defs","station_id",station_id)
	if spec.is_empty():return 1.0
	var row: RefCounted=territory(spec.sector_id)
	if row==null or row.phase!="controlled" or g.civilizations.allegiance().is_empty() or g.civilizations.owner(spec.sector_id)!=g.civilizations.allegiance():return 1.0
	return float(balance.repair_fee_ratio if kind=="repair" else balance.industry_fee_ratio)
func controlled(sector_id: String) -> bool:
	if not supported() or g.civilizations.allegiance().is_empty():return false
	var row: RefCounted=territory(sector_id)
	return row!=null and row.phase=="controlled" and g.civilizations.owner(sector_id)==g.civilizations.allegiance()
func hostile_detection_ratio(sector_id: String) -> float:
	return float(balance.hostile_detection_ratio) if controlled(sector_id) else 1.0
func restock_rate(station_id: String) -> float:
	if not supported():return 1.0
	var spec: Dictionary=g.definition("frontier_governance_defs","station_id",station_id)
	return float(balance.restock_rate) if not spec.is_empty() and controlled(str(spec.sector_id)) else 1.0
func _trigger_demand(station_id: String) -> void:
	if not g.catalog.table_names.has("station_demand_defs"):return
	for spec: Dictionary in g.rows("station_demand_defs"):
		if spec.station_id!=station_id:continue
		var row: RefCounted=g.state.find("station_demand_state","demand_id",spec.demand_id)
		if row==null:continue
		if row.status=="cooldown":row.status="active";row.generation+=1;row.remaining_units=int(spec.required_units)
		row.phase_remaining_s=float(spec.duration_s)
func focused_id() -> String:
	if not supported():return ""
	var war: RefCounted=g.civilizations.active_war()
	if owns_campaign(war):return war.war_id
	var d: RefCounted=director()
	return d.active_sector_id if d.has_active_sector_id else ""
func expected_token(id: String) -> String:
	var row: RefCounted=campaign(id)
	return "%d:%s" % [row.attempt,row.phase] if row!=null else _governance_token(id)
func status_text(id: String) -> String:
	var row: RefCounted=campaign(id)
	if row!=null:
		match row.phase:
			"scouting":return "侦察 · 剩余 %.1f秒" % row.survey_remaining_s if row.survey_paid else "侦察 · 抵达目标后调查"
			"escorting":
				var convoy: RefCounted=_actor_for(id,"convoy");return "护送补给 · %s" % ("护盾 %.0f / 装甲 %.0f / 结构 %.0f" % [convoy.shield,convoy.armor,convoy.hull] if convoy!=null else "集结中")
			"hold":return "守住登陆点 · %.1f秒 · 友军 %d / 3" % [row.hold_remaining_s,g.civilizations.living_fleet(g.civilizations.active_war(),"ally").size()]
			"demolition":return "拆除制压装置 · %d / %d" % [row.demolition_units,definition(id).structure_count]
			"rebuilding":return "登陆设施修复 · 剩余 %.1f秒" % row.repair_remaining_s if row.repair_paid_units>0 else "登陆设施修复 · 需结构料 × %d" % int(balance.rebuild_units)
			"legacy":return "旧战役 · 保留原流程"
			"completed":return "战役完成 · 主权及奖励已登记"
			_:return {"idle":"尚未受领","failed":"战役失败 · 可整备重试","cancelled":"战役已撤退"}.get(row.phase,row.phase)
	var governed: RefCounted=territory(id)
	if governed==null:return ""
	return "边疆预警 · %.0f秒 · 补给 %d / %d" % [governed.warning_remaining_s,governed.reserve_units,pressure_units(g.civilizations.owner(id))] if governed.phase=="warning" else "边疆防守 · 信标 %.1f秒 / 截止 %.1f秒" % [governed.hold_remaining_s,governed.defense_remaining_s] if governed.phase=="defending" else "驻防补给 · %d / %d" % [governed.reserve_units,balance.reserve_max_units] if governed.phase=="controlled" else "中立边疆 · 可争夺"
func guidance(id: String) -> Dictionary:
	var row: RefCounted=campaign(id);var anchor_id: String="";var title: String=status_text(id)
	if row!=null:
		var spec: Dictionary=definition(id);var war: Dictionary=g.definition("civilization_war_defs","war_id",id)
		anchor_id=spec.scout_anchor_id if row.phase=="scouting" else spec.convoy_start_anchor_id if row.phase=="escorting" else war.capture_anchor_id
		if row.phase=="escorting":
			var convoy: RefCounted=_actor_for(id,"convoy")
			if convoy!=null and g.same_entity_site("ship",g.state.ship(),"npc",convoy):
				var location: Dictionary=g.missions._anchor_location(anchor_id,convoy.npc_instance_id,"npc",title)
				return g.missions._route_location(location,"")
	else:
		var spec: Dictionary=g.definition("frontier_governance_defs","sector_id",id)
		if spec.is_empty():return {}
		var governed: RefCounted=territory(id)
		if governed.phase in ["neutral","controlled"]:
			var station: Dictionary=g.definition("station_defs","station_id",spec.station_id)
			return g.missions._route_location(g.missions._anchor_location(station.station_anchor_id,station.station_id,"station",title),"")
		anchor_id=spec.defense_anchor_id
	var location: Dictionary=g.missions._anchor_location(anchor_id,"frontier:"+id,"encounter",title)
	return g.missions._route_location(location,"")
func waypoints(sector_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[];var id: String=focused_id()
	if id.is_empty():return result
	var row: RefCounted=campaign(id);var anchor_id: String=""
	if row!=null:
		var spec: Dictionary=definition(id);anchor_id=spec.scout_anchor_id if row.phase=="scouting" else spec.convoy_start_anchor_id if row.phase=="escorting" else g.definition("civilization_war_defs","war_id",id).capture_anchor_id
	else:anchor_id=g.definition("frontier_governance_defs","sector_id",id).defense_anchor_id
	var at: Dictionary=g.definition("anchor_defs","anchor_id",anchor_id)
	if at.sector_id!=sector_id:return result
	result.append({"id":"frontier:"+id,"kind":"encounter","anchor_id":anchor_id,"title":status_text(id),"remaining_count":0,"total_count":0,"respawn_remaining_s":0.0,"level":0,"mission_target":true,"reveal_range_m":float(balance.survey_radius_m),"warp_arrival_m":float(balance.survey_radius_m),"frontier_id":id})
	return result
