class_name XJCivilizations
extends RefCounted
signal status_changed(message: String)
## Authoritative membership, procurement permissions, donations and war outcomes.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var _war_spawns: Dictionary = {}

func _init(game: RefCounted) -> void:
	g = game
	if supported():
		for member: Dictionary in g.rows("civilization_war_members"):
			_war_spawns[str(member.spawn_id)] = member

func supported() -> bool:
	return g != null and g.catalog.table_names.has("civilization_defs")

func membership() -> D.CivilizationStateDto:
	return g.state.find("civilization_state", "player_id", g.state.player().player_id) as D.CivilizationStateDto

func allegiance() -> String:
	var row: D.CivilizationStateDto = membership()
	return row.faction_id if row != null and row.has_faction_id else ""

func faction_name(faction: String) -> String:
	if faction.is_empty(): return "中立"
	return str(g.definition("faction_defs", "faction_id", faction).get("display_name", faction))

func owner(sector_id: String) -> String:
	var row: D.TerritoryStateDto = g.state.find("territory_state", "sector_id", sector_id)
	return row.faction_id if row != null and row.has_faction_id else ""

func rank(faction: String) -> Dictionary:
	var best: Dictionary = {}
	if not supported(): return best
	var reputation: int = g.economy.reputation(faction)
	for entry: Dictionary in g.rows("civilization_rank_defs"):
		if entry.faction_id == faction and int(entry.required_reputation) <= reputation and (best.is_empty() or int(entry.rank_level) > int(best.rank_level)):
			best = entry
	return best

func rank_requirement(faction: String, level: int) -> Dictionary:
	for entry: Dictionary in g.rows("civilization_rank_defs"):
		if entry.faction_id == faction and int(entry.rank_level) == level: return entry
	return {}

func capital_reason(faction: String) -> String:
	var definition: Dictionary = g.definition("civilization_defs", "faction_id", faction)
	if definition.is_empty(): return "文明不存在"
	if g.state.ship().status != T.ShipStatus.DOCKED or g.station() != str(definition.capital_station_id):
		return "需前往核心站 · " + str(g.definition("station_defs", "station_id", definition.capital_station_id).display_name)
	return ""

func join_reason(faction: String) -> String:
	if not supported(): return "当前世界尚未升级文明规则"
	if allegiance() == faction: return "已效忠此文明"
	var reason: String = capital_reason(faction)
	if not reason.is_empty(): return reason
	if active_war() != null: return "先完成或撤出当前战争"
	var member: D.CivilizationStateDto = membership()
	if member == null: return "文明身份状态缺失"
	if member.switch_cooldown_remaining_s > 0: return "改换效忠冷却 · %d 秒" % ceili(member.switch_cooldown_remaining_s)
	for step: Dictionary in g.rows("civilization_join_missions"):
		if step.faction_id == faction and not g.missions.completed(step.mission_id): return "先完成三步核心站入籍任务"
	if not allegiance().is_empty() and g.state.player().credit < int(g.rule("civilization_switch_fee")): return "改换效忠的行政费用不足"
	return ""

func join(faction: String) -> bool:
	var reason: String = join_reason(faction)
	if not reason.is_empty(): return g.fail(reason)
	if not g.allowed_service("mission_board"): return false
	var member: D.CivilizationStateDto = membership()
	var switching: bool = member.has_faction_id
	if switching: g.state.player().credit -= int(g.rule("civilization_switch_fee"))
	member.has_faction_id = true
	member.faction_id = faction
	member.joined_tick = g.state.snapshot.meta.simulation_tick
	member.switch_cooldown_remaining_s = g.rule("civilization_switch_cooldown_s") if switching else 0.0
	return true

func donation_reason(id: String, batches: int) -> String:
	var definition: Dictionary = g.definition("civilization_donation_defs", "donation_id", id)
	if definition.is_empty(): return "捐献项目不存在"
	if allegiance() != definition.faction_id: return "先完成入籍并效忠此文明"
	var reason: String = capital_reason(definition.faction_id)
	if not reason.is_empty(): return reason
	if batches < 1 or batches > int(g.rule("civilization_max_donation_batches")): return "单次捐献批数超出限制"
	var warehouse: String = ""
	for container: D.ContainerStateDto in g.state.rows("container_state"):
		if container.kind == T.ContainerKind.STATION and container.station_id == g.station() and container.owner_player_id == g.state.player().player_id:
			warehouse = container.container_id
			break
	if g.inventory.count(warehouse, definition.item_id, true) < int(definition.units_per_batch) * batches: return "核心站仓库中的普通自有材料不足"
	return ""

func donate(id: String, batches: int) -> bool:
	var reason: String = donation_reason(id, batches)
	if not reason.is_empty(): return g.fail(reason)
	if not g.allowed_service("warehouse"): return false
	var definition: Dictionary = g.definition("civilization_donation_defs", "donation_id", id)
	if not g.inventory.consume(g.inventory.warehouse(g.station()), definition.item_id, int(definition.units_per_batch) * batches, true): return g.fail("捐献材料扣除失败")
	_add_reputation(definition.faction_id, int(definition.reputation_per_batch) * batches)
	return true

func permission_reason(faction: String, required_rank: int) -> String:
	if allegiance() != faction: return "需效忠 " + faction_name(faction)
	var required: Dictionary = rank_requirement(faction, required_rank)
	if required.is_empty(): return "爵位规则缺失"
	if int(rank(faction).get("rank_level", 0)) < required_rank:
		return "需 " + str(required.display_name) + " · 声望 %d" % int(required.required_reputation)
	return ""

func hull_reason(ship_id: String) -> String:
	if not supported(): return ""
	var definition: Dictionary = g.definition("civilization_hull_defs", "ship_id", ship_id)
	if definition.is_empty(): return ""
	var reason: String = permission_reason(definition.faction_id, int(definition.required_rank))
	if not reason.is_empty(): return reason
	if not g.unlocked(definition.required_unlock_id): return "需完成该舰型的文明技术研究"
	return ""

func research_reason(research_id: String) -> String:
	if not supported(): return ""
	var definition: Dictionary = g.definition("civilization_technology_defs", "research_id", research_id)
	if definition.is_empty(): return ""
	return permission_reason(definition.faction_id, int(definition.required_rank))

func active_war() -> D.WarCampaignStateDto:
	for row: D.WarCampaignStateDto in g.state.rows("war_campaign_state"):
		if row.status in ["assembling", "fighting", "occupying"]: return row
	return null

func war_reason(war_id: String) -> String:
	var definition: Dictionary = g.definition("civilization_war_defs", "war_id", war_id)
	if definition.is_empty(): return "战争委托不存在"
	var reason: String = permission_reason(definition.faction_id, int(definition.required_rank))
	if not reason.is_empty(): return reason
	reason = capital_reason(definition.faction_id)
	if not reason.is_empty(): return reason
	if active_war() != null: return "已有进行中的舰队战争"
	reason=g.honors.war_reason(str(definition.faction_id))
	if not reason.is_empty():return reason
	var policy: Dictionary = g.definition("sector_sovereignty_defs", "sector_id", definition.target_sector_id)
	if policy.is_empty() or not bool(policy.conquerable) or not owner(definition.target_sector_id).is_empty(): return "目标已非可争夺的中立星系"
	if g.missions.has_pending_loans(): return "先归还待清理的任务借船"
	return g.frontier.quote_reason(war_id)

func start_war(war_id: String) -> bool:
	var reason: String = war_reason(war_id)
	if not reason.is_empty(): return g.fail(reason)
	if not g.allowed_service("mission_board"): return false
	if not g.frontier.pay_begin(war_id):return false
	var definition: Dictionary = g.definition("civilization_war_defs", "war_id", war_id)
	var campaign: D.WarCampaignStateDto = g.state.find("war_campaign_state", "war_id", war_id)
	if campaign == null:
		campaign = D.WarCampaignStateDto.new()
		campaign.war_id = war_id
		campaign.player_id = g.state.player().player_id
		g.state.add("war_campaign_state", campaign)
	else:
		campaign.attempt += 1
	_clear_fleet(war_id)
	campaign.status = "assembling"
	campaign.fleet_order = "advance"
	campaign.focus_target_id = ""
	campaign.capture_remaining_s = float(definition.capture_duration_s)
	campaign.started_tick = g.state.snapshot.meta.simulation_tick
	campaign.finished_tick = 0
	campaign.rewards_claimed = false
	for entry: Dictionary in g.rows("civilization_war_members"):
		if entry.war_id != war_id: continue
		var spawn: Dictionary = g.definition("npc_spawn_defs", "spawn_id", entry.spawn_id)
		var npc_def: Dictionary = g.definition("npc_full_defs", "npc_id", spawn.npc_id)
		var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", spawn.anchor_id)
		var npc: D.NpcStateDto = D.NpcStateDto.new()
		npc.npc_instance_id = g.id("fleet")
		npc.spawn_id = entry.spawn_id
		npc.sector_id = spawn.sector_id
		npc.generation = campaign.attempt
		npc.alive = true
		npc.shield = npc_def.shield_max; npc.armor = npc_def.armor_max; npc.hull = npc_def.hull_max
		npc.pos_x = anchor.x_m; npc.pos_y = anchor.y_m; npc.pos_z = anchor.z_m
		g.state.add("npc_state", npc)
		g.assign_anchor_site("npc", npc.npc_instance_id, anchor.anchor_id)
		var fleet: D.WarFleetStateDto = D.WarFleetStateDto.new()
		fleet.npc_instance_id = npc.npc_instance_id; fleet.war_id = war_id; fleet.side = entry.side
		g.state.add("war_fleet_state", fleet)
	g.frontier.begin(campaign)
	return true

func handles_spawn(spawn_id: String) -> bool:
	return _war_spawns.has(spawn_id)

func fleet_member(npc_id: String) -> D.WarFleetStateDto:
	return g.state.find("war_fleet_state", "npc_instance_id", npc_id) as D.WarFleetStateDto

func friendly(npc_id: String) -> bool:
	if g.scenarios!=null and g.scenarios.friendly(npc_id):return true
	if g.drone_control != null:
		var owner: String = g.drone_control.owner(npc_id)
		if not owner.is_empty(): return owner == g.state.ship().ship_instance_id or friendly(owner)
	if g.exploration != null and g.exploration.friendly(npc_id): return true
	if g.frontier!=null and g.frontier.friendly(npc_id):return true
	if g.hired!=null and g.hired.friendly(npc_id):return true
	var member: D.WarFleetStateDto = fleet_member(npc_id)
	return member != null and member.side == "ally"

func escort_hull(npc_id: String) -> String:
	if g.scenarios!=null:
		var scenario_model: String=g.scenarios.model(npc_id)
		if not scenario_model.is_empty():return scenario_model
	if g.hired!=null:
		var companion: String=g.hired.model(npc_id)
		if not companion.is_empty():return companion
	if g.frontier!=null:
		var model: String=g.frontier.model(npc_id)
		if not model.is_empty():return model
	if g.exploration != null:
		var event_hull: String = g.exploration.escort_hull(npc_id)
		if not event_hull.is_empty(): return event_hull
	var member: D.WarFleetStateDto = fleet_member(npc_id)
	if member == null or member.side != "ally": return ""
	var definition: Dictionary = g.definition("civilization_war_defs", "war_id", member.war_id)
	for hull: Dictionary in g.rows("civilization_hull_defs"):
		if hull.faction_id == definition.faction_id and int(hull.required_rank) == 2: return hull.ship_id
	return ""

func hostile_to(attacker_id: String, target_id: String) -> bool:
	var attacker_friendly: bool = attacker_id == g.state.ship().ship_instance_id or friendly(attacker_id)
	var target_friendly: bool = target_id == g.state.ship().ship_instance_id or friendly(target_id)
	return attacker_friendly != target_friendly

func command(order: String, target_id: String = "") -> bool:
	var campaign: D.WarCampaignStateDto = active_war()
	if campaign == null: return g.fail("没有进行中的舰队战争")
	if order == "retreat":
		_finish(campaign, "cancelled")
		return true
	if order not in ["advance", "focus", "regroup"]: return g.fail("未知舰队指令")
	if order == "focus":
		var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", target_id)
		if npc == null or not npc.alive or friendly(target_id) or not g.same_entity_site("ship", g.state.ship(), "npc", npc): return g.fail("选择战区内存活的敌舰后集火")
		var war_def: Dictionary = g.definition("civilization_war_defs", "war_id", campaign.war_id)
		var battle_anchor: Dictionary = g.definition("anchor_defs", "anchor_id", war_def.capture_anchor_id)
		if not g.same_anchor_site(npc, battle_anchor): return g.fail("集火目标必须位于本次战役空域")
	campaign.fleet_order = order
	campaign.focus_target_id = target_id if order == "focus" else ""
	return true

func living_fleet(campaign: D.WarCampaignStateDto, side: String) -> Array[D.NpcStateDto]:
	var result: Array[D.NpcStateDto] = []
	for member: D.WarFleetStateDto in g.state.rows("war_fleet_state"):
		if member.war_id != campaign.war_id or member.side != side: continue
		var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", member.npc_instance_id)
		if npc != null and npc.alive: result.append(npc)
	return result

func tick(delta: float) -> void:
	if not supported(): return
	var member: D.CivilizationStateDto = membership()
	if member != null: member.switch_cooldown_remaining_s = maxf(0, member.switch_cooldown_remaining_s - delta)
	var campaign: D.WarCampaignStateDto = active_war()
	if campaign == null: return
	if g.frontier.owns_campaign(campaign):g.frontier.tick_campaign(delta,campaign);return
	var definition: Dictionary = g.definition("civilization_war_defs", "war_id", campaign.war_id)
	if g.state.ship().status == T.ShipStatus.DESTROYED or living_fleet(campaign, "ally").is_empty():
		_finish(campaign, "failed")
		return
	var anchor: Dictionary = g.definition("anchor_defs", "anchor_id", definition.capture_anchor_id)
	if g.state.ship().status != T.ShipStatus.FLYING or not g.same_anchor_site(g.state.ship(), anchor):
		campaign.status = "assembling"
		campaign.capture_remaining_s = float(definition.capture_duration_s)
		return
	var enemies: bool = not living_fleet(campaign, "defender").is_empty()
	for npc: D.NpcStateDto in g.state.rows("npc_state"):
		if npc.alive and not friendly(npc.npc_instance_id) and g.same_anchor_site(npc, anchor): enemies = true
	if enemies:
		campaign.status = "fighting"
		campaign.capture_remaining_s = float(definition.capture_duration_s)
		return
	campaign.status = "occupying"
	if g.anchor_distance(g.state.ship(), anchor) > float(definition.capture_radius_m):
		campaign.capture_remaining_s = float(definition.capture_duration_s)
		return
	campaign.capture_remaining_s = maxf(0, campaign.capture_remaining_s - delta)
	if campaign.capture_remaining_s <= 0:
		var control: D.TerritoryStateDto = g.state.find("territory_state", "sector_id", definition.target_sector_id)
		if control == null or control.has_faction_id:
			_finish(campaign, "failed")
			return
		control.has_faction_id = true; control.faction_id = definition.faction_id
		control.captured_tick = g.state.snapshot.meta.simulation_tick
		g.state.player().credit += int(definition.reward_credit)
		_add_reputation(definition.faction_id, int(definition.reward_reputation))
		campaign.rewards_claimed = true
		_finish(campaign, "won")

func _finish(campaign: D.WarCampaignStateDto, status: String) -> void:
	if status=="cancelled":g.frontier.cancelled(campaign)
	g.frontier.legacy_finished(campaign,status)
	campaign.status = status
	campaign.finished_tick = g.state.snapshot.meta.simulation_tick
	_clear_fleet(campaign.war_id)
	g.status_text = {"won": "舰队战役胜利 · 中立星系已归属当前文明", "failed": "舰队战役失败 · 可返回核心站重新整备", "cancelled": "舰队已撤退 · 星系主权未改变"}.get(status, status)
	status_changed.emit(str(g.status_text))
	g.request_autosave()

func _clear_fleet(war_id: String) -> void:
	for member: D.WarFleetStateDto in g.state.rows("war_fleet_state").duplicate():
		if member.war_id != war_id: continue
		var npc: D.NpcStateDto = g.state.find("npc_state", "npc_instance_id", member.npc_instance_id)
		g.state.remove("war_fleet_state", member)
		if npc != null: g.remove_npc(npc)

func _add_reputation(faction: String, amount: int) -> void:
	var row: D.ReputationStateDto = g.state.find("reputation_state", "faction_id", faction)
	if row == null:
		row = D.ReputationStateDto.new(); row.player_id = g.state.player().player_id; row.faction_id = faction
		g.state.add("reputation_state", row)
	row.reputation += amount
