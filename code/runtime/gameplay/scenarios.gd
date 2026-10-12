extends RefCounted
## Limited-budget objectives and real corridor cargo share physical NPC authority.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
var g: RefCounted
var actor_definitions: Dictionary={}
var spatial_active: bool=true
signal changed(message: String)
func _init(game: RefCounted) -> void:
	g=game
	if not supported():return
	for def: Dictionary in g.rows("trial_actor_defs"):actor_definitions[def.spawn_id]={"kind":"trial","id":def.trial_id,"definition":def}
	for def: Dictionary in g.rows("blockade_actor_defs"):actor_definitions[def.spawn_id]={"kind":"blockade","id":def.blockade_id,"definition":def}
func supported() -> bool:return g!=null and g.catalog.table_names.has("trial_defs")
func instance(kind: String,id: String) -> RefCounted:return g.state.find("trial_state" if kind=="trial" else "blockade_state",kind+"_id",id)
func definition(kind: String,id: String) -> Dictionary:return g.definition("trial_defs" if kind=="trial" else "blockade_defs",kind+"_id",id)
func token(kind: String,id: String) -> String:
	var row: RefCounted=instance(kind,id)
	return str(row.generation) if row!=null else ""
func pending() -> Dictionary:
	if supported():
		for kind: String in ["trial","blockade"]:
			for row: RefCounted in g.state.rows(kind+"_state"):
				if row.phase in ["accepted","active","ready"]:return {"kind":kind,"id":row.get(kind+"_id"),"row":row}
	return {}
func _at(kind: String,id: String,anchor_id: String) -> bool:
	var anchor: Dictionary=g.definition("anchor_defs","anchor_id",anchor_id)
	return spatial_active and g.state.ship().status==T.ShipStatus.FLYING and g.same_anchor_site(g.state.ship(),anchor) and g.anchor_distance(g.state.ship(),anchor)<=float(definition(kind,id).interaction_radius_m)
func _same_site(kind: String,id: String) -> bool:return g.same_anchor_site(g.state.ship(),g.definition("anchor_defs","anchor_id",definition(kind,id).entry_anchor_id))
func budget(ship: RefCounted=null) -> int:
	var hull: RefCounted=g.state.ship() if ship==null else ship
	var amount: int=int(g.definition("ship_defs","ship_id",hull.ship_def_id).base_ask_credit)
	for gear: RefCounted in g.equipped(hull):amount+=int(g.definition("item_defs","item_id",gear.module_def_id).base_ask_credit)
	for gear: RefCounted in g.equipped(hull):
		var bay: RefCounted=g.state.find("drone_bay_state","item_instance_id",gear.item_instance_id)
		var rule: Dictionary=g.definition("drone_management_defs","module_id",gear.module_def_id)
		if bay!=null and not rule.is_empty():amount+=(bay.stock_units+bay.deployed_units)*(int(rule.credit_per_unit)+int(rule.material_per_unit)*int(g.definition("item_defs","item_id",rule.material_id).base_ask_credit))
	var supplies: Dictionary={}
	for rule: Dictionary in g.rows("weapon_defs"):
		if rule.ammo_item_id!=null:supplies[str(rule.ammo_item_id)]=true
	for rule: Dictionary in g.rows("repair_defs"):
		if rule.consumable_item_id!=null:supplies[str(rule.consumable_item_id)]=true
	for item: Dictionary in g.rows("item_defs"):
		if item.item_type in ["ammo","consumable"]:supplies[item.item_id]=true
	for container: RefCounted in g.state.rows("container_state"):
		if not container.has_ship_instance_id or container.ship_instance_id!=hull.ship_instance_id or container.kind==T.ContainerKind.SLOT:continue
		for stack: RefCounted in g.state.rows("inventory_stack_state"):
			if stack.container_id==container.container_id and supplies.has(stack.item_def_id):amount+=stack.quantity*int(g.definition("item_defs","item_id",stack.item_def_id).base_ask_credit)
		for item: RefCounted in g.state.rows("item_instance_state"):
			if item.container_id==container.container_id and supplies.has(item.item_def_id):amount+=int(g.definition("item_defs","item_id",item.item_def_id).base_ask_credit)
	return amount
func fingerprint(ship: RefCounted=null) -> String:
	var hull: RefCounted=g.state.ship() if ship==null else ship
	var pieces: Array[String]=[hull.ship_def_id]
	for gear: RefCounted in g.equipped(hull):pieces.append(gear.slot_container_id+":"+gear.item_instance_id+":"+gear.module_def_id)
	pieces.sort();return "|".join(pieces).sha256_text()
func _trial_fit(id: String,bound: bool=false) -> String:
	var spec: Dictionary=definition("trial",id);var row: RefCounted=instance("trial",id);var ship: RefCounted=g.state.ship()
	if ship.policy_id!="normal_owned":return "挑战需要普通自有舰船"
	if not g.rows("trial_hull_defs").any(func(d: Dictionary):return d.trial_id==id and d.ship_id==ship.ship_def_id):return "舰型不符合本项挑战"
	if budget(ship)>int(spec.budget_credit):return "参考配装与作战耗材超过预算"
	for gear: RefCounted in g.equipped(ship):
		var item: RefCounted=g.state.find("item_instance_state","item_instance_id",gear.item_instance_id)
		if item==null or item.policy_id!="normal_owned":return "不能以保障或借用设备参加挑战"
	if bound and (not row.has_ship_instance_id or row.ship_instance_id!=ship.ship_instance_id or row.loadout_signature!=fingerprint(ship)):return "受领后舰船或装备已变化"
	if spec.objective_kind=="support":
		if not g.equipped(ship).any(func(e: RefCounted):return e.enabled and not g.definition("repair_defs","module_id",e.module_def_id).is_empty()):return "需要启用可用的远程维修设备"
	elif not g.equipped(ship).any(func(e: RefCounted):return e.enabled and not g.definition("weapon_defs","module_id",e.module_def_id).is_empty()):return "需要启用武器"
	return ""
func trial_reason(id: String,action: String) -> String:
	var row: RefCounted=instance("trial",id);var spec: Dictionary=definition("trial",id)
	if row==null or spec.is_empty():return "挑战不存在"
	if not g.unlocked(spec.required_unlock_id):return "需要远域航路许可"
	if action=="accept":
		if not pending().is_empty():return "先完成或撤回当前战术场景"
		if row.cooldown_remaining_s>0:return "挑战整备中"
		if g.state.ship().status!=T.ShipStatus.DOCKED or g.station()!=spec.station_id:return "需要在签发站受领"
		var blocked: String=_trial_fit(id)
		if not blocked.is_empty():return blocked
		return "" if g.state.player().credit>=int(spec.fee_credit) else "服务费不足"
	if action=="withdraw":return "" if row.phase in ["accepted","active","ready"] else "没有可撤回的挑战"
	var fit_reason: String=_trial_fit(id,true)
	if not fit_reason.is_empty():return fit_reason
	if action=="start":return "" if row.phase=="accepted" and _at("trial",id,spec.entry_anchor_id) else "需要驾驶受领舰实际抵达起点"
	if action=="claim":return "" if row.phase=="ready" and g.state.ship().status==T.ShipStatus.DOCKED and g.station()==spec.station_id else "需要返回签发站交付成绩"
	return "未知挑战动作"
func trial_action(id: String,action: String,expected: String) -> bool:
	if not supported() or expected!=token("trial",id):return g.fail("挑战代次已变化，请刷新")
	var reason: String=trial_reason(id,action)
	if not reason.is_empty():return g.fail(reason)
	var row: RefCounted=instance("trial",id);var spec: Dictionary=definition("trial",id)
	match action:
		"accept":
			row.generation+=1;row.phase="accepted";row.has_ship_instance_id=true;row.ship_instance_id=g.state.ship().ship_instance_id
			row.reference_cost=budget();row.loadout_signature=fingerprint();row.elapsed_s=0;row.remaining_s=0;row.effective_hp=0
			g.state.player().credit-=int(spec.fee_credit);row.paid_credit_total+=int(spec.fee_credit)
			g.journal.begin("trial",id+":"+str(row.generation))
		"start":
			row.phase="active";row.remaining_s=float(spec.duration_s)
			_spawn("trial",id,row.generation)
		"withdraw":_trial_finish(id,"withdrawn","manual")
		"claim":
			row.phase="completed";row.wins+=1
			if row.best_elapsed_s<=0 or row.elapsed_s<row.best_elapsed_s:row.best_elapsed_s=row.elapsed_s
			if row.best_cost<=0 or row.reference_cost<row.best_cost:row.best_cost=row.reference_cost
			_award(spec.award_id);row.award_earned=true;_trial_result(id,"completed","completed")
	g.request_autosave();changed.emit("挑战状态已更新");return true
func _trial_result(id: String,outcome: String,reason: String) -> void:
	var row: RefCounted=instance("trial",id);var spec: Dictionary=definition("trial",id)
	var ship: RefCounted=g.state.find("ship_state","ship_instance_id",row.ship_instance_id)
	var result: RefCounted=D.TrialResultStateDto.new();result.trial_id=id;result.generation=row.generation;result.outcome=outcome;result.reason_code=reason
	result.ship_def_id=ship.ship_def_id;result.reference_cost=row.reference_cost;result.paid_credit=int(spec.fee_credit);result.elapsed_s=row.elapsed_s;result.effective_hp=row.effective_hp;result.finished_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("trial_result_state",result);row.cooldown_remaining_s=float(spec.cooldown_s)
	g.journal.finish("trial",id+":"+str(row.generation),outcome,reason)
func _trial_finish(id: String,phase: String,reason: String) -> void:
	var row: RefCounted=instance("trial",id)
	if row.phase not in ["accepted","active","ready"]:return
	row.phase=phase;row.remaining_s=0;_clear("trial",id)
	if phase!="ready":_trial_result(id,phase,reason)
	changed.emit("挑战："+reason);g.request_autosave()
func _award(id: String) -> void:
	if g.state.find("tactical_award_state","award_id",id)!=null:return
	var row: RefCounted=D.TacticalAwardStateDto.new();row.award_id=id;row.earned_tick=g.state.snapshot.meta.simulation_tick;g.state.add("tactical_award_state",row)
func select_award(id: String) -> bool:
	if not id.is_empty() and g.state.find("tactical_award_state","award_id",id)==null:return g.fail("称号尚未取得")
	for row: RefCounted in g.state.rows("tactical_award_state"):row.selected=row.award_id==id
	g.request_autosave();return true
func title() -> String:
	for row: RefCounted in g.state.rows("tactical_award_state"):
		if row.selected:return str(g.definition("tactical_award_defs","award_id",row.award_id).display_name)
	return ""
func ship_locked(ship_id: String) -> bool:
	if not supported():return false
	for row: RefCounted in g.state.rows("trial_state"):
		if row.phase in ["accepted","active","ready"] and row.has_ship_instance_id and row.ship_instance_id==ship_id:return true
	for row: RefCounted in g.state.rows("blockade_state"):
		if row.phase=="active" and row.has_payload_ship_id and row.payload_ship_id==ship_id:return true
	return false
func navigation_reason() -> String:
	var current: Dictionary=pending()
	if current.is_empty() or current.row.phase!="active":return ""
	if current.kind=="trial":return "挑战进行中，先完成目标或撤回挑战"
	return "处于中继封锁范围：调查侧路、拆除中继或驶出封锁范围" if field_active(current.id) else ""
func hud_text() -> String:
	var current: Dictionary=pending()
	if current.is_empty():return ""
	var row: RefCounted=current.row;var spec: Dictionary=definition(current.kind,current.id)
	var line: String="前往入口 · 抵达后开始行动" if row.phase=="accepted" else "返回签发站交付成果" if row.phase=="ready" else ""
	if row.phase=="active":
		if current.kind=="blockade":line="货物 %d/%d · %s" % [row.cargo_units,row.loaded_units,"侧路通行中" if row.bypass_remaining_s>0 else "已警戒" if row.alerted else "保持低速或处理节点"]
		elif spec.objective_kind=="precision":line="有效伤害 %.0f/%.0f · 距离 %.1f–%.1f km" % [row.effective_hp,spec.target_hp,spec.min_range_m/1000.0,spec.max_range_m/1000.0]
		elif spec.objective_kind=="support":line="有效远修 %.0f/%.0f · 保护伤舰抵达出口" % [row.effective_hp,spec.target_hp]
		else:line="保护运输舰抵达出口 · 无需清场"
	return str(spec.display_name)+"\n"+line
func field_active(id: String) -> bool:
	var row: RefCounted=instance("blockade",id)
	if row==null or row.phase!="active" or row.bypass_remaining_s>0 or not spatial_active or not _same_site("blockade",id):return false
	var radius: float=float(definition("blockade",id).field_radius_m)
	for member: RefCounted in g.state.rows("scenario_actor_state"):
		if member.scenario_kind!="blockade" or member.scenario_id!=id or member.actor_role!="relay":continue
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",member.npc_instance_id)
		if npc!=null and npc.alive and g.position(g.state.ship()).distance_to(g.position(npc))<=radius:return true
	return false
func controlled_ship_lost() -> void:
	if not supported():return
	var id: String=g.state.ship().ship_instance_id
	for row: RefCounted in g.state.rows("trial_state"):
		if row.has_ship_instance_id and row.ship_instance_id==id and row.phase in ["accepted","active","ready"]:_trial_finish(row.trial_id,"failed","ship_destroyed")
func guidance(kind: String,id: String,node_index: int=-1) -> Dictionary:
	var row: RefCounted=instance(kind,id);var spec: Dictionary=definition(kind,id)
	if row==null or spec.is_empty():return {}
	if row.phase not in ["accepted","active"]:return g.missions._route_location(g.missions._station_location(spec.station_id),"")
	if kind=="trial" and row.phase=="active" and spec.objective_kind=="precision":
		for member: RefCounted in g.state.rows("scenario_actor_state"):
			if member.scenario_kind==kind and member.scenario_id==id and member.actor_role=="target":
				var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",member.spawn_id)
				return g.missions._route_location(g.missions._anchor_location(spawn.anchor_id,member.npc_instance_id,"npc",spec.display_name),"")
	var anchor: String=spec.entry_anchor_id
	var label: String="行动入口"
	if row.phase=="active" and (kind=="blockade" or spec.objective_kind!="precision"):anchor=spec.exit_anchor_id;label="行动出口"
	if kind=="blockade" and node_index>=0:
		var node: Dictionary=node_definition(id,node_index)
		if node.is_empty():return {}
		anchor=node.anchor_id;label="调查节点" if node.node_kind=="survey" else "封锁中继"
	var target: String="scenario:"+kind+":"+id+":"+anchor
	return g.missions._route_location(g.missions._anchor_location(anchor,target,"encounter",label),"")
func waypoints(sector_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not supported():return result
	for kind: String in ["trial","blockade"]:
		for spec: Dictionary in g.rows(kind+"_defs"):
			var id: String=spec.get(kind+"_id");var row: RefCounted=instance(kind,id);var entry: Dictionary=g.definition("anchor_defs","anchor_id",spec.entry_anchor_id)
			if entry.sector_id!=sector_id or row.phase not in ["accepted","active"]:continue
			var anchors: Array[String]=[spec.entry_anchor_id]
			if row.phase=="active":anchors.append(spec.exit_anchor_id)
			if kind=="blockade" and row.phase=="active":
				for node: Dictionary in g.rows("blockade_node_defs"):
					if node.blockade_id==id:anchors.append(str(node.anchor_id))
			for anchor: String in anchors:
				result.append({"id":"scenario:"+kind+":"+id+":"+anchor,"title":spec.display_name+(" · 入口" if anchor==spec.entry_anchor_id else " · 出口" if anchor==spec.exit_anchor_id else " · 节点"),"kind":"encounter","anchor_id":anchor,"remaining_count":0,"total_count":0,"respawn_remaining_s":0.0,"level":0,"mission_target":true,"reveal_range_m":spec.interaction_radius_m,"warp_arrival_m":spec.interaction_radius_m})
	return result
func handles(spawn_id: String) -> bool:return actor_definitions.has(spawn_id)
func actor(npc_id: String) -> RefCounted:return g.state.find("scenario_actor_state","npc_instance_id",npc_id)
func friendly(npc_id: String) -> bool:
	var member: RefCounted=actor(npc_id)
	return member!=null and member.actor_role in ["escort","patient"]
func model(npc_id: String) -> String:
	var member: RefCounted=actor(npc_id)
	if member==null:return ""
	var def: Dictionary=actor_definitions[member.spawn_id].definition
	return str(def.model_ship_id) if member.scenario_kind=="trial" and def.model_ship_id!=null else ""
func _spawn(kind: String,id: String,generation: int) -> void:
	_clear(kind,id)
	for spawn_id: String in actor_definitions:
		var binding: Dictionary=actor_definitions[spawn_id]
		if binding.kind!=kind or binding.id!=id:continue
		var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",spawn_id);var stats: Dictionary=g.definition("npc_full_defs","npc_id",spawn.npc_id)
		var anchor: Dictionary=g.definition("anchor_defs","anchor_id",spawn.anchor_id);var npc: RefCounted=D.NpcStateDto.new()
		npc.npc_instance_id=g.id("scenario_actor");npc.spawn_id=spawn_id;npc.sector_id=spawn.sector_id;npc.generation=generation;npc.alive=true
		npc.shield=float(stats.shield_max);npc.armor=float(stats.armor_max);npc.hull=float(stats.hull_max)
		if kind=="trial":
			npc.armor*=float(binding.definition.initial_armor_bp)/10000.0
			if binding.definition.actor_role=="patient":npc.shield=0
		npc.pos_x=anchor.x_m;npc.pos_y=anchor.y_m;npc.pos_z=anchor.z_m
		g.state.add("npc_state",npc);g.assign_anchor_site("npc",npc.npc_instance_id,spawn.anchor_id)
		var member: RefCounted=D.ScenarioActorStateDto.new();member.npc_instance_id=npc.npc_instance_id;member.spawn_id=spawn_id;member.scenario_kind=kind;member.scenario_id=id;member.generation=generation;member.actor_role=binding.definition.actor_role
		g.state.add("scenario_actor_state",member)
func _clear(kind: String,id: String) -> void:
	for member: RefCounted in g.state.rows("scenario_actor_state").duplicate():
		if member.scenario_kind!=kind or member.scenario_id!=id:continue
		var npc: RefCounted=g.state.find("npc_state","npc_instance_id",member.npc_instance_id)
		for support: RefCounted in g.state.rows("remote_support_state").duplicate():
			if support.target_npc_id==member.npc_instance_id:g.ship_roles.stop_support(support.item_instance_id)
		g.state.remove("scenario_actor_state",member)
		if npc!=null:g.remove_npc(npc)
func contributed(npc_id: String,amount: float) -> void:
	var member: RefCounted=actor(npc_id)
	if member==null or member.scenario_kind!="trial" or member.actor_role!="target" or amount<=0:return
	var row: RefCounted=instance("trial",member.scenario_id);var spec: Dictionary=definition("trial",member.scenario_id)
	if row.phase!="active" or not _trial_fit(member.scenario_id,true).is_empty():return
	var npc: RefCounted=g.state.find("npc_state","npc_instance_id",npc_id);var distance: float=g.position(g.state.ship()).distance_to(g.position(npc))
	if distance<float(spec.min_range_m) or distance>float(spec.max_range_m):return
	row.effective_hp+=amount
	if row.effective_hp>=float(spec.target_hp):_trial_finish(member.scenario_id,"ready","completed")
func repaired(npc_id: String,amount: float) -> void:
	var member: RefCounted=actor(npc_id)
	if member==null or member.scenario_kind!="trial" or member.actor_role!="patient" or amount<=0:return
	var row: RefCounted=instance("trial",member.scenario_id)
	if row.phase=="active" and _trial_fit(member.scenario_id,true).is_empty():row.effective_hp+=amount
func destroyed(npc_id: String) -> void:
	var member: RefCounted=actor(npc_id)
	if member==null:return
	if member.scenario_kind=="trial" and member.actor_role in ["target","escort","patient"]:_trial_finish(member.scenario_id,"failed","target_lost")
	elif member.scenario_kind=="blockade" and member.actor_role=="relay":
		var binding: Dictionary=actor_definitions[member.spawn_id].definition
		var node: RefCounted=_node(member.scenario_id,int(binding.node_index))
		if node!=null:node.completed=true;changed.emit("封锁中继已拆除")
func tick(delta: float) -> void:
	if not supported():return
	for row: RefCounted in g.state.rows("trial_state"):
		row.cooldown_remaining_s=maxf(0,row.cooldown_remaining_s-delta)
		if row.phase!="active":continue
		if g.state.ship().status==T.ShipStatus.DESTROYED:_trial_finish(row.trial_id,"failed","ship_destroyed");continue
		if not spatial_active or not _same_site("trial",row.trial_id):_trial_finish(row.trial_id,"withdrawn","departed");continue
		if not _trial_fit(row.trial_id,true).is_empty():_trial_finish(row.trial_id,"failed","loadout_changed");continue
		row.remaining_s=maxf(0,row.remaining_s-delta);row.elapsed_s+=delta
		var spec: Dictionary=definition("trial",row.trial_id)
		for member: RefCounted in g.state.rows("scenario_actor_state").duplicate():
			if member.scenario_kind!="trial" or member.scenario_id!=row.trial_id or member.actor_role not in ["escort","patient"]:continue
			var npc: RefCounted=g.state.find("npc_state","npc_instance_id",member.npc_instance_id)
			if npc==null or not npc.alive:continue
			if member.actor_role=="patient" and float(spec.hazard_hp_s)>0:g.damage_npc(npc.npc_instance_id,Vector3(float(spec.hazard_hp_s)*delta,0,0))
			if row.phase!="active":break
			var exit: Dictionary=g.definition("anchor_defs","anchor_id",spec.exit_anchor_id)
			if g.position(npc).distance_to(Vector3(exit.x_m,exit.y_m,exit.z_m))<=float(spec.interaction_radius_m):_trial_finish(row.trial_id,"ready" if spec.objective_kind=="escort" or row.effective_hp>=float(spec.target_hp) else "failed","completed" if spec.objective_kind=="escort" or row.effective_hp>=float(spec.target_hp) else "objective_failed");break
		if row.phase=="active" and row.remaining_s<=0:_trial_finish(row.trial_id,"failed","timeout")
	_tick_blockades(delta)

func _node(id: String,index: int) -> RefCounted:
	for row: RefCounted in g.state.rows("blockade_node_state"):
		if row.blockade_id==id and row.node_index==index:return row
	return null
func node_definition(id: String,index: int) -> Dictionary:
	for row: Dictionary in g.rows("blockade_node_defs"):
		if row.blockade_id==id and int(row.node_index)==index:return row
	return {}
func relays_open(id: String) -> bool:
	for def: Dictionary in g.rows("blockade_node_defs"):
		if def.blockade_id==id and def.node_kind=="relay" and not _node(id,int(def.node_index)).completed:return false
	return true
func cargo(ship_id: String) -> Dictionary:
	var mass: float=0;var volume: float=0
	if supported():
		for row: RefCounted in g.state.rows("blockade_state"):
			if row.has_payload_ship_id and row.payload_ship_id==ship_id:
				var spec: Dictionary=definition("blockade",row.blockade_id)
				mass+=row.cargo_units*float(spec.cargo_mass_kg);volume+=row.cargo_units*float(spec.cargo_volume_l)
	return {"mass":mass,"volume":volume}
func load_capacity(id: String) -> int:
	var spec: Dictionary=definition("blockade",id);var limits: Dictionary=g.metrics(g.state.ship())
	return maxi(0,mini(int(spec.target_units),mini(int(floor(maxf(0,limits.cargo_capacity_l-limits.cargo_used_l)/float(spec.cargo_volume_l))),int(floor(maxf(0,limits.max_payload_mass_kg-limits.payload_mass_kg)/float(spec.cargo_mass_kg))))))
func _scanner() -> RefCounted:
	for gear: RefCounted in g.equipped(g.state.ship()):
		var item: RefCounted=g.state.find("item_instance_state","item_instance_id",gear.item_instance_id)
		if gear.enabled and gear.module_def_id.begins_with("module_scanner_") and item!=null and item.durability>0:return gear
	return null
func blockade_reason(id: String,action: String,index: int=-1) -> String:
	var row: RefCounted=instance("blockade",id);var spec: Dictionary=definition("blockade",id)
	if row==null or spec.is_empty():return "封锁航路不存在"
	if not g.unlocked(spec.required_unlock_id):return "需要远域航路许可"
	if action=="accept":
		if not pending().is_empty():return "先完成或撤回当前战术场景"
		if row.cooldown_remaining_s>0:return "航路整备中"
		if g.state.ship().status!=T.ShipStatus.DOCKED or g.station()!=spec.station_id:return "需要在签发站受领"
		if g.state.ship().policy_id!="normal_owned":return "需要普通自有舰船"
		return "" if g.state.player().credit>=int(spec.fee_credit) else "服务费不足"
	if action=="withdraw":return "" if row.phase in ["accepted","active"] else "没有可撤回的封锁行动"
	if action=="claim":return "" if row.phase=="ready" and g.state.ship().status==T.ShipStatus.DOCKED and g.station()==spec.station_id else "需返回签发站交付实际送达货物"
	if action=="start":
		if row.phase!="accepted" or not _at("blockade",id,spec.entry_anchor_id):return "需实际抵达入口"
		return "" if load_capacity(id)>0 else "货舱或载荷空余不足"
	if row.phase!="active" or not row.has_payload_ship_id or row.payload_ship_id!=g.state.ship().ship_instance_id or not spatial_active or not _same_site("blockade",id):return "需驾驶本次承运舰留在行动空域"
	if action=="exit":return "" if _at("blockade",id,spec.exit_anchor_id) else "需实际抵达航路出口"
	if action=="jettison":return "" if row.cargo_units>0 else "没有可抛弃货物"
	if action=="survey":
		var node: Dictionary=node_definition(id,index)
		if node.is_empty() or node.node_kind!="survey" or _node(id,index).completed:return "调查节点不可用"
		if row.has_scan_node_index:return "先完成当前调查"
		if not _at("blockade",id,node.anchor_id):return "需抵达调查节点范围内"
		if _scanner()==null:return "需要启用兼容扫描设备"
		return ""
	return "未知封锁动作"
func blockade_action(id: String,action: String,expected: String,index: int=-1) -> bool:
	if not supported() or expected!=token("blockade",id):return g.fail("封锁代次已变化，请刷新")
	var reason: String=blockade_reason(id,action,index)
	if not reason.is_empty():return g.fail(reason)
	var row: RefCounted=instance("blockade",id);var spec: Dictionary=definition("blockade",id)
	match action:
		"accept":
			row.generation+=1;row.phase="accepted";row.loaded_units=0;row.cargo_units=0;row.completed_units=0;row.lost_units=0;row.jettisoned_units=0
			row.elapsed_s=0;row.remaining_s=0;row.alerted=false;row.bypass_remaining_s=0;row.damage_debt_hp=0;row.has_payload_ship_id=false;row.payload_ship_id="";row.has_scan_node_index=false;row.scan_node_index=0;row.scan_remaining_s=0
			g.state.player().credit-=int(spec.fee_credit);row.paid_credit_total+=int(spec.fee_credit)
			for node: RefCounted in g.state.rows("blockade_node_state"):
				if node.blockade_id==id:node.generation=row.generation;node.completed=false
			g.journal.begin("blockade",id+":"+str(row.generation))
		"start":
			row.loaded_units=load_capacity(id);row.cargo_units=row.loaded_units;row.has_payload_ship_id=true;row.payload_ship_id=g.state.ship().ship_instance_id
			row.phase="active";row.remaining_s=float(spec.duration_s);_spawn("blockade",id,row.generation)
		"survey":
			var scanner: RefCounted=_scanner()
			if scanner.cooldown_remaining_s>0 or not g.pay_cycle(scanner):return g.fail("扫描设备尚未就绪或能量/热量不足")
			row.has_scan_node_index=true;row.scan_node_index=index;row.scan_remaining_s=float(spec.survey_duration_s)/g.ship_roles.survey_rate()
		"jettison":row.cargo_units-=1;row.jettisoned_units+=1
		"withdraw":_blockade_finish(id,false,"manual")
		"exit":_blockade_finish(id,true,"completed")
		"claim":
			var credit: int=row.completed_units*int(spec.credit_per_unit);g.state.player().credit+=credit;row.reward_credit_total+=credit;row.rewarded_units_total+=row.completed_units
			var station: Dictionary=g.definition("station_defs","station_id",spec.station_id);var rep: RefCounted=g.state.find("reputation_state","faction_id",station.faction_id)
			if rep!=null:rep.reputation+=row.completed_units*int(spec.reputation_per_unit)
			row.phase="claimed"
			if row.completed_units==int(spec.target_units):_award(spec.award_id);row.award_earned=true
			_blockade_result(id,"claimed","completed" if row.completed_units==int(spec.target_units) else "partial",credit)
	g.request_autosave();changed.emit("封锁航路状态已更新");return true
func _blockade_result(id: String,outcome: String,reason: String,reward: int=0) -> void:
	var row: RefCounted=instance("blockade",id);var spec: Dictionary=definition("blockade",id);var result: RefCounted=D.BlockadeResultStateDto.new()
	result.blockade_id=id;result.generation=row.generation;result.outcome=outcome;result.reason_code=reason;result.loaded_units=row.loaded_units
	result.delivered_units=row.completed_units if outcome=="claimed" else 0;result.lost_units=row.lost_units;result.jettisoned_units=row.jettisoned_units
	result.paid_credit=int(spec.fee_credit);result.reward_credit=reward;result.elapsed_s=row.elapsed_s;result.finished_tick=g.state.snapshot.meta.simulation_tick;g.state.add("blockade_result_state",result)
	g.journal.finish("blockade",id+":"+str(row.generation),"completed" if outcome=="claimed" and reason=="completed" else "partial" if outcome=="claimed" else outcome,reason)
func _blockade_finish(id: String,reached: bool,reason: String) -> void:
	var row: RefCounted=instance("blockade",id)
	if row.phase not in ["accepted","active"]:return
	if reached:row.completed_units=row.cargo_units
	else:row.lost_units+=row.cargo_units
	row.cargo_units=0;row.has_payload_ship_id=false;row.payload_ship_id="";row.has_scan_node_index=false;row.scan_node_index=0;row.scan_remaining_s=0;row.remaining_s=0
	row.phase="ready" if row.completed_units>0 else "withdrawn" if reason=="manual" else "failed"
	row.cooldown_remaining_s=float(definition("blockade",id).cooldown_s);_clear("blockade",id)
	if row.phase!="ready":_blockade_result(id,row.phase,reason)
	changed.emit("封锁行动："+reason);g.request_autosave()
func damaged(amount: float) -> void:
	if not supported() or amount<=0:return
	for row: RefCounted in g.state.rows("blockade_state"):
		if row.phase!="active" or not row.has_payload_ship_id or row.payload_ship_id!=g.state.ship().ship_instance_id:continue
		if g.state.ship().hull<=0:_blockade_finish(row.blockade_id,false,"ship_destroyed");continue
		if not row.alerted or not field_active(row.blockade_id):continue
		row.damage_debt_hp+=amount;var threshold: float=float(definition("blockade",row.blockade_id).loss_damage_hp)
		while row.damage_debt_hp>=threshold and row.cargo_units>0:row.damage_debt_hp-=threshold;row.cargo_units-=1;row.lost_units+=1
func _tick_blockades(delta: float) -> void:
	for row: RefCounted in g.state.rows("blockade_state"):
		row.cooldown_remaining_s=maxf(0,row.cooldown_remaining_s-delta)
		if row.phase!="active":continue
		if not spatial_active or not _same_site("blockade",row.blockade_id):_blockade_finish(row.blockade_id,false,"departed");continue
		if g.state.ship().status!=T.ShipStatus.FLYING or row.payload_ship_id!=g.state.ship().ship_instance_id:_blockade_finish(row.blockade_id,false,"ship_destroyed");continue
		var spec: Dictionary=definition("blockade",row.blockade_id);row.remaining_s=maxf(0,row.remaining_s-delta);row.elapsed_s+=delta;row.bypass_remaining_s=maxf(0,row.bypass_remaining_s-delta)
		if row.has_scan_node_index:
			var node: Dictionary=node_definition(row.blockade_id,row.scan_node_index)
			if not _at("blockade",row.blockade_id,node.anchor_id) or _scanner()==null:row.has_scan_node_index=false;row.scan_node_index=0;row.scan_remaining_s=0
			else:
				row.scan_remaining_s=maxf(0,row.scan_remaining_s-delta)
				if row.scan_remaining_s<=0:
					_node(row.blockade_id,row.scan_node_index).completed=true;row.has_scan_node_index=false;row.scan_node_index=0
					var completed: int=0
					for def: Dictionary in g.rows("blockade_node_defs"):
						if def.blockade_id==row.blockade_id and def.node_kind=="survey" and _node(row.blockade_id,int(def.node_index)).completed:completed+=1
					if completed>=int(spec.survey_count):row.bypass_remaining_s=float(spec.bypass_window_s);changed.emit("侧路通行窗口已开启")
		if not row.alerted and not relays_open(row.blockade_id) and row.bypass_remaining_s<=0:
			var ship: RefCounted=g.state.ship();var speed: float=Vector3(ship.vel_x,ship.vel_y,ship.vel_z).length()
			var loud: bool=speed>float(spec.quiet_speed_mps) or g.equipped(ship).any(func(e: RefCounted):return e.active_remaining_s>0 and not g.definition("weapon_defs","module_id",e.module_def_id).is_empty())
			if loud:
				for member: RefCounted in g.state.rows("scenario_actor_state"):
					if member.scenario_kind!="blockade" or member.scenario_id!=row.blockade_id or member.actor_role!="relay":continue
					var npc: RefCounted=g.state.find("npc_state","npc_instance_id",member.npc_instance_id)
					if npc==null or not npc.alive or g.position(ship).distance_to(g.position(npc))>float(spec.detection_radius_m):continue
					if g.spatial_validator.is_valid() and not g.spatial_validator.call(g.position(ship),g.position(npc),npc.npc_instance_id):continue
					row.alerted=true;changed.emit("封锁警戒已触发 · 受击可能损失任务货物");break
		if row.remaining_s<=0:_blockade_finish(row.blockade_id,false,"timeout")
