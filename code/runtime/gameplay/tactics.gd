extends RefCounted
signal warning_changed(message: String)
signal feedback_changed(kind: String, message: String)

func _feedback(kind: String, message: String) -> void:
	warning_changed.emit(message)
	feedback_changed.emit(kind,message)
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var balance: Dictionary = {}
var bindings: Dictionary = {}
func _init(game: RefCounted) -> void:
	g = game
	if not supported(): return
	balance = g.rows("tactical_balance_defs")[0]
	for row: Dictionary in g.rows("npc_tactic_bindings"): bindings[row.spawn_id] = row
func supported() -> bool: return g != null and g.catalog.table_names.has("npc_tactic_defs")
func handles(spawn_id: String) -> bool: return bindings.has(spawn_id)
func instance(npc_id: String) -> D.NpcTacticStateDto: return g.state.find("npc_tactic_state", "npc_instance_id", npc_id)
func definition(npc_id: String) -> Dictionary:
	var row: RefCounted = instance(npc_id)
	return g.definition("npc_tactic_defs", "tactic_id", row.tactic_id) if row != null else {}
func model(npc_id: String) -> String: return str(definition(npc_id).get("model_ship_id", ""))
static func initial_sites(catalog: XJCatalog) -> Array[D.TacticalSiteStateDto]:
	var result: Array[D.TacticalSiteStateDto] = []
	if not catalog.table_names.has("tactical_site_defs"): return result
	for spec: Dictionary in catalog.rows("tactical_site_defs"):
		var row: D.TacticalSiteStateDto = D.TacticalSiteStateDto.new(); row.site_id = spec.site_id; result.append(row)
	return result
func members(site_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in bindings.values():
		if row.site_id == site_id: result.append(row)
	return result
func remaining(site_id: String) -> int:
	var count: int = 0
	for member: Dictionary in members(site_id):
		var npc: RefCounted = g.state.find("npc_state", "spawn_id", member.spawn_id)
		if npc != null and npc.alive: count += 1
	return count
func _spawn(member: Dictionary, generation: int) -> void:
	g.encounters._spawn(member, generation)
	var npc: RefCounted = g.state.find("npc_state", "spawn_id", member.spawn_id)
	register_existing(npc)

func register_existing(npc: RefCounted) -> void:
	if npc==null or not handles(npc.spawn_id) or instance(npc.npc_instance_id)!=null:return
	var member: Dictionary=bindings[npc.spawn_id]
	var spec: Dictionary = g.definition("npc_tactic_defs", "tactic_id", member.tactic_id)
	var row: D.NpcTacticStateDto = D.NpcTacticStateDto.new()
	row.npc_instance_id = npc.npc_instance_id; row.tactic_id = member.tactic_id; row.energy = float(spec.energy_max); row.drone_stock = int(spec.drone_reserve)
	g.state.add("npc_tactic_state", row)

func campaign_site(id: String) -> bool:
	return g.catalog.table_names.has("campaign_tactical_links") and not g.definition("campaign_tactical_links","site_id",id).is_empty()
func sync(delta: float = 0.0) -> void:
	if not supported(): return
	for spec: Dictionary in g.rows("tactical_site_defs"):
		var site: RefCounted = g.state.find("tactical_site_state", "site_id", spec.site_id)
		if not g.unlocked(spec.required_unlock_id): continue
		if campaign_site(spec.site_id):
			# Exploration alone owns spawning, outcomes and renewal. Tactical
			# registration must never create additional enemies or loot cycles.
			for member: Dictionary in members(spec.site_id):register_existing(g.state.find("npc_state","spawn_id",member.spawn_id))
			continue
		var any_existing: bool = false
		for member: Dictionary in members(spec.site_id):
			if g.state.find("npc_state", "spawn_id", member.spawn_id) != null: any_existing = true
		if not any_existing or remaining(spec.site_id) > 0:
			for member: Dictionary in members(spec.site_id):
				if g.state.find("npc_state", "spawn_id", member.spawn_id) == null: _spawn(member, site.generation)
			continue
		site.respawn_remaining_s = maxf(0.0, site.respawn_remaining_s - delta)
		if site.respawn_remaining_s > 0.0: continue
		site.generation += 1
		for member: Dictionary in members(spec.site_id):
			var previous: RefCounted = g.state.find("npc_state", "spawn_id", member.spawn_id)
			if previous != null: g.remove_npc(previous)
			_spawn(member, site.generation)
func retired(npc_id: String) -> void:
	var row: RefCounted = instance(npc_id)
	if row != null: g.state.remove("npc_tactic_state", row)
	for effect: RefCounted in g.state.rows("ship_tactical_effect_state"):
		if effect.source_npc_id == npc_id: effect.has_source_npc_id = false; effect.source_npc_id = ""; effect.jam_remaining_s = 0.0
	for actor: RefCounted in g.state.rows("npc_tactic_state"):
		if actor.target_entity_id == npc_id: _finish(actor)
func destroyed(npc: RefCounted) -> void:
	if not handles(npc.spawn_id): return
	var site_id: String = bindings[npc.spawn_id].site_id
	if remaining(site_id) == 0:
		var site: RefCounted = g.state.find("tactical_site_state", "site_id", site_id)
		site.respawn_remaining_s = g.definition("tactical_site_defs", "site_id", site_id).respawn_s; site.cleared_cycles += 1
	var row: RefCounted = instance(npc.npc_instance_id)
	if row != null: _finish(row)
	for actor: RefCounted in g.state.rows("npc_tactic_state"):
		if actor.target_entity_id == npc.npc_instance_id: _finish(actor)
	for effect: RefCounted in g.state.rows("ship_tactical_effect_state"):
		if effect.source_npc_id == npc.npc_instance_id: effect.has_source_npc_id = false; effect.source_npc_id = ""; effect.jam_remaining_s = 0.0
func tick(delta: float) -> void:
	if not supported(): return
	for row: RefCounted in g.state.rows("npc_tactic_state"):
		var spec: Dictionary = definition(row.npc_instance_id)
		row.energy = minf(float(spec.energy_max), row.energy + float(spec.recharge_eu_s) * delta)
		row.cooldown_remaining_s = maxf(0.0, row.cooldown_remaining_s - delta)
		if row.phase == "cooldown" and row.cooldown_remaining_s <= 0.0: row.phase = "ready"
		var npc: RefCounted = g.state.find("npc_state", "npc_instance_id", row.npc_instance_id)
		if row.phase in ["charging", "active"] and (not npc.alive or not g.same_entity_site("npc", npc, "ship", g.state.ship()) or g.state.ship().status != T.ShipStatus.FLYING): _finish(row)
	for effect: RefCounted in g.state.rows("ship_tactical_effect_state"):
		var previous_jam: float = effect.jam_remaining_s
		effect.jam_remaining_s = maxf(0.0, effect.jam_remaining_s - delta)
		effect.repeat_window_s = maxf(0.0, effect.repeat_window_s - delta)
		if effect.repeat_window_s == 0.0: effect.repeat_count = 0
		if effect.jam_remaining_s == 0.0: effect.immunity_remaining_s = maxf(0.0, effect.immunity_remaining_s - maxf(0.0, delta - previous_jam)); effect.has_source_npc_id = false; effect.source_npc_id = ""
		var ship: RefCounted = g.state.find("ship_state", "ship_instance_id", effect.ship_instance_id)
		var source: RefCounted = g.state.find("npc_state", "npc_instance_id", effect.source_npc_id)
		if ship == null or ship.status != T.ShipStatus.FLYING or (effect.has_source_npc_id and (source == null or not source.alive)):
			effect.jam_remaining_s = 0.0; effect.has_source_npc_id = false; effect.source_npc_id = ""
func thrust_ratio(ship_id: String) -> float:
	var effect: RefCounted = g.state.find("ship_tactical_effect_state", "ship_instance_id", ship_id)
	return float(balance.min_thrust_ratio) if effect != null and effect.jam_remaining_s > 0.0 else 1.0
func apply_jam(npc_id: String) -> bool:
	var ship: RefCounted = g.state.ship()
	var npc: RefCounted = g.state.find("npc_state", "npc_instance_id", npc_id)
	if npc == null or not npc.alive or definition(npc_id).get("tactic_kind", "") != "interceptor" or ship.status != T.ShipStatus.FLYING or not g.same_entity_site("ship", ship, "npc", npc): return false
	var effect: RefCounted = g.state.find("ship_tactical_effect_state", "ship_instance_id", ship.ship_instance_id)
	if effect == null:
		effect = D.ShipTacticalEffectStateDto.new(); effect.ship_instance_id = ship.ship_instance_id; g.state.add("ship_tactical_effect_state", effect)
	if effect.jam_remaining_s > 0.0 or effect.immunity_remaining_s > 0.0: return false
	effect.jam_remaining_s = minf(float(balance.jam_max_duration_s), float(definition(npc_id).duration_s)) * pow(float(balance.jam_repeat_multiplier), float(effect.repeat_count))
	effect.repeat_count = mini(int(balance.jam_max_repeat), effect.repeat_count + 1); effect.repeat_window_s = float(balance.jam_repeat_window_s); effect.immunity_remaining_s = float(balance.jam_immunity_s)
	effect.has_source_npc_id = true; effect.source_npc_id = npc_id
	_feedback("jam","推进受干扰 %.1f秒：转向和最低推进能力保留；击毁截击舰可立即解除。" % effect.jam_remaining_s)
	return true
func _finish(row: RefCounted) -> void:
	row.phase = "cooldown"; row.remaining_s = 0.0; row.cooldown_remaining_s = float(definition(row.npc_instance_id).cooldown_s); row.has_target_entity_id = false; row.target_entity_id = ""
func step(npc_id: String, target_id: String, visible: bool, delta: float) -> Dictionary:
	var row: RefCounted = instance(npc_id)
	var spec: Dictionary = definition(npc_id)
	var npc: RefCounted = g.state.find("npc_state", "npc_instance_id", npc_id)
	var target: RefCounted = g.state.ship() if target_id == g.state.ship().ship_instance_id else g.state.find("npc_state", "npc_instance_id", target_id)
	if target == null or not visible or g.position(npc).distance_to(g.position(target)) > float(spec.range_m):
		if row.phase in ["charging", "active"]: _finish(row)
		return {}
	if row.phase == "ready":
		if row.energy < float(spec.energy_cost): return {}
		row.energy -= float(spec.energy_cost); row.phase = "charging"; row.remaining_s = float(spec.charge_s); row.has_target_entity_id = true; row.target_entity_id = target_id
		row.aim_x = target.pos_x; row.aim_y = target.pos_y; row.aim_z = target.pos_z; row.charge_start_hp = npc.shield + npc.armor + npc.hull
		g.mark_hostile_attempt()
		_feedback("charging",str(spec.display_name) + "：" + str({"support":"正在准备维修同伴，优先压制支援舰。","interceptor":"短时干扰准备中，拉开距离或击毁来源。","siege":"蓄能齐射预告，机动、掩体或命中打断均可反制。","carrier":"即将投放无人机，压制母舰或射击无人机。"}[spec.tactic_kind]))
	if row.phase == "charging":
		if float(spec.interrupt_hp) > 0.0 and row.charge_start_hp - (npc.shield + npc.armor + npc.hull) >= float(spec.interrupt_hp):
			_finish(row); _feedback("interrupted","敌方蓄能已被打断。")
			return {}
		row.remaining_s = maxf(0.0, row.remaining_s - delta)
		if row.remaining_s > 0.0: return {}
		if spec.tactic_kind == "support": row.phase = "active"; row.remaining_s = float(spec.duration_s)
		elif spec.tactic_kind == "interceptor": apply_jam(npc_id); _finish(row); return {}
		else:
			var result: Dictionary = {"kind": spec.tactic_kind, "aim": Vector3(row.aim_x,row.aim_y,row.aim_z), "damage": Vector3(float(spec.strength),0,0), "module_id": str(spec.drone_module_id) if spec.drone_module_id != null else "", "range": float(spec.range_m), "speed": float(spec.projectile_speed_mps)}
			_finish(row); return result
	if row.phase == "active":
		var stats: Dictionary = g.definition("npc_full_defs", "npc_id", g.definition("npc_spawn_defs", "spawn_id", target.spawn_id).npc_id)
		var amount: float = float(spec.strength) * minf(delta, row.remaining_s)
		for layer: String in ["hull","armor","shield"]:
			var add: float = minf(amount, maxf(0.0, float(stats[layer + "_max"]) - float(target.get(layer))))
			target.set(layer, float(target.get(layer)) + add); amount -= add
		row.remaining_s = maxf(0.0, row.remaining_s - delta)
		if row.remaining_s <= 0.0: _finish(row)
	return {}
func status(npc_id: String) -> String:
	var row: RefCounted = instance(npc_id)
	if row == null: return ""
	var spec: Dictionary = definition(npc_id)
	return str(spec.display_name) + " · " + str({"ready":"能力就绪","charging":"准备/蓄能 %.1f秒" % row.remaining_s,"active":"维修中 %.1f秒" % row.remaining_s,"cooldown":"冷却 %.1f秒" % row.cooldown_remaining_s}[row.phase]) + (" · 机库余量%d" % row.drone_stock if spec.tactic_kind == "carrier" else "")
func waypoints(sector_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not supported(): return result
	for spec: Dictionary in g.rows("tactical_site_defs"):
		if campaign_site(spec.site_id):continue
		if spec.sector_id != sector_id or not g.unlocked(spec.required_unlock_id): continue
		var site: RefCounted = g.state.find("tactical_site_state", "site_id", spec.site_id)
		var level: int = 0
		for member: Dictionary in members(spec.site_id):
			var spawn: Dictionary = g.definition("npc_spawn_defs","spawn_id",member.spawn_id)
			level = maxi(level,int(g.definition("npc_full_defs","npc_id",spawn.npc_id).level))
		result.append({"id":"tactical:" + str(spec.site_id),"title":spec.display_name,"kind":"encounter","anchor_id":spec.anchor_id,"remaining_count":remaining(spec.site_id),"total_count":members(spec.site_id).size(),"respawn_remaining_s":site.respawn_remaining_s,"level":level,"mission_target":false,"reveal_range_m":spec.reveal_range_m,"warp_arrival_m":spec.warp_arrival_m,"tactical":true})
	return result
