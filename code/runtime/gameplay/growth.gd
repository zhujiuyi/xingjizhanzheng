extends RefCounted
## Guidance reads existing authorities. Only an explicit, proven one-time claim
## changes credits/reputation; observing milestones never grants assets.
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
var g: RefCounted
func _init(game: RefCounted) -> void:g=game
func supported() -> bool:return g!=null and g.catalog.table_names.has("growth_stage_defs")

func stages(faction: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not supported():return result
	for stage: Dictionary in g.rows("growth_stage_defs"):
		if stage.faction_id==null or stage.faction_id==faction:result.append(stage)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return int(a.sort_order)<int(b.sort_order) if int(a.sort_order)!=int(b.sort_order) else str(a.stage_id)<str(b.stage_id))
	return result

func reputation(faction: String) -> int:
	var row: RefCounted=g.state.find("reputation_state","faction_id",faction)
	return row.reputation if row!=null else 0

func progress(stage: Dictionary) -> Dictionary:
	var current: int=0;var target: int=int(stage.target_count);var complete: bool=false;var note: String=""
	match str(stage.criterion_kind):
		"membership":current=1 if g.civilizations.allegiance()==stage.reference_id else 0;complete=current==1
		"rank":
			var rank: Dictionary=g.civilizations.rank_requirement(stage.reference_id,target)
			target=int(rank.required_reputation);current=reputation(stage.reference_id);complete=current>=target
			note="声望差 %d" % maxi(0,target-current)
		"registration":
			var row: RefCounted=g.honors.instance(stage.reference_id)
			current=1 if row!=null and row.phase!="unregistered" else 0;complete=current==1
			note=g.honors.registration_reason(stage.reference_id) if not complete else "后续行动已开始计入考核"
		"honors":
			var row: RefCounted=g.honors.instance(stage.reference_id)
			current=g.honors.completed(stage.reference_id);target=g.honors.tasks(stage.reference_id).size();complete=row!=null and row.phase=="certified"
			note="需回核心站认证" if current==target and not complete else "先登记，再完成四类行动"
		"research":
			var research: Dictionary=g.definition("research_defs","research_id",stage.reference_id)
			current=1 if g.unlocked(research.reward_unlock_id) else 0;complete=current==1
			note="研究费 %d · 当前 %d" % [int(research.required_credit),g.state.player().credit]
		"owned_hull":
			for ship: RefCounted in g.state.rows("ship_state"):
				if ship.ship_def_id==stage.reference_id and ship.policy_id=="normal_owned" and ship.status not in [T.ShipStatus.DESTROYED,T.ShipStatus.RETURNED]:current+=1
			complete=current>=target
			var hull: Dictionary=g.definition("ship_defs","ship_id",stage.reference_id)
			var recipe: Dictionary=g.definition("hull_recipe_defs","ship_id",stage.reference_id)
			note="参考裸舰 %d · 基础制造费 %d" % [int(hull.base_ask_credit),int(recipe.get("service_fee_credit",0))]
		"war":
			var war: RefCounted=g.state.find("war_campaign_state","war_id",stage.reference_id)
			current=1 if war!=null and war.status=="won" else 0
			for receipt: RefCounted in g.state.rows("frontier_campaign_receipt_state"):
				if receipt.war_id==stage.reference_id and receipt.event_kind=="capture":current=1
			complete=current==1
			note=g.civilizations.war_reason(stage.reference_id) if not complete and g.civilizations.active_war()==null else "完成准备、行军、战斗和重建"
		"expedition":
			var route_state: RefCounted=g.state.find("expedition_route_state","route_id",stage.reference_id)
			current=route_state.completed_runs if route_state!=null else 0
			complete=current>=target
		"project":
			var project: RefCounted=g.state.find("construction_state","project_id",stage.reference_id)
			current=1 if project!=null and project.phase=="completed" else 0;complete=current==1
	return {"current":current,"target":target,"complete":complete,"note":note}

func selected(faction: String) -> Dictionary:
	var goal: RefCounted=g.state.find("growth_goal_state","player_id",g.state.player().player_id)
	if goal!=null and goal.has_stage_id:
		var stage: Dictionary=g.definition("growth_stage_defs","stage_id",goal.stage_id)
		if not stage.is_empty() and (stage.faction_id==null or stage.faction_id==faction):return stage
	var choices: Array[Dictionary]=stages(faction)
	for stage: Dictionary in choices:
		if not bool(progress(stage).complete):return stage
	return choices[-1] if not choices.is_empty() else {}

func select(stage_id: String) -> bool:
	if not supported():return g.fail("当前世界尚未升级成长指引")
	var stage: Dictionary=g.definition("growth_stage_defs","stage_id",stage_id)
	if stage.is_empty():return g.fail("成长目标不存在")
	var row: RefCounted=g.state.find("growth_goal_state","player_id",g.state.player().player_id)
	if row==null:row=D.GrowthGoalStateDto.new();row.player_id=g.state.player().player_id;g.state.add("growth_goal_state",row)
	row.has_stage_id=true;row.stage_id=stage_id;row.has_faction_id=stage.faction_id!=null;row.faction_id=str(stage.faction_id) if row.has_faction_id else ""
	row.revision+=1;row.selected_tick=g.state.snapshot.meta.simulation_tick;g.request_autosave();return true

func activities(stage_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for activity: Dictionary in g.rows("growth_activity_defs"):
		if activity.stage_id==stage_id:result.append(activity)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return int(a.activity_index)<int(b.activity_index))
	return result

func activity(stage_id: String,index: int) -> Dictionary:
	for row: Dictionary in activities(stage_id):
		if int(row.activity_index)==index:return row
	return {}

func activity_label(row: Dictionary) -> String:
	match str(row.activity_kind):
		"mission":
			var mission: Dictionary=g.definition("mission_summary_defs","mission_id",row.reference_id)
			var stage: Dictionary=g.definition("growth_stage_defs","stage_id",row.stage_id)
			if stage.criterion_kind=="rank":
				var gain: int=0
				for reward: Dictionary in g.rows("mission_reputation_rewards"):
					if reward.mission_id==row.reference_id and reward.faction_id==stage.faction_id:gain+=int(reward.reputation_delta)
				return "%s · +%d声望" % [mission.display_name,gain]
			return "%s · %d信用点" % [mission.display_name,int(mission.reward_credit)]
		"donation":
			var donation: Dictionary=g.definition("civilization_donation_defs","donation_id",row.reference_id)
			return "捐献%s × %d · +%d声望" % [g.definition("item_defs","item_id",donation.item_id).display_name,int(donation.units_per_batch),int(donation.reputation_per_batch)]
		"honor_register":return "登记指挥考核"
		"honor":return str(g.definition("civilization_honor_task_defs","task_id",row.reference_id).display_name)
		"research":return str(g.definition("research_defs","research_id",row.reference_id).display_name)
		"hull_recipe":return "制造 · "+str(g.definition("hull_recipe_defs","hull_recipe_id",row.reference_id).display_name)
		"war":return "前往核心站受领边疆战役"
		"expedition":return str(g.definition("expedition_route_defs","route_id",row.reference_id).display_name)
		"project":return str(g.definition("construction_project_defs","project_id",row.reference_id).display_name)
	return str(row.reference_id)

func service_page(stage_id: String,index: int) -> String:
	var row: Dictionary=activity(stage_id,index)
	match str(row.get("activity_kind","")):
		"mission":return "missions"
		"research":return "research"
		"hull_recipe":return "industry"
		"expedition":return "expeditions"
		"project":return "projects"
	return "civilizations"

func guidance(stage_id: String,index: int) -> Dictionary:
	var row: Dictionary=activity(stage_id,index)
	if row.is_empty():return {}
	if row.activity_kind=="honor":
		var sources: Array[Dictionary]=g.honors.sources(row.reference_id)
		if not sources.is_empty():
			var source: Dictionary=sources[0]
			if source.kind=="exploration":return g.exploration.guidance(source.id)
			if source.kind=="operation":return g.operations.guidance(source.id)
			if source.kind=="consignment":return g.consignments.guidance(source.id)
	var station: Dictionary=g.definition("station_defs","station_id",row.station_id)
	var location: Dictionary=g.missions._anchor_location(station.station_anchor_id,station.station_id,"station",activity_label(row))
	return g.missions._route_location(location,"")

func observe() -> void:
	if not supported():return
	var owned: int=0
	for ship: RefCounted in g.state.rows("ship_state"):
		if ship.policy_id=="normal_owned" and ship.status not in [T.ShipStatus.DESTROYED,T.ShipStatus.RETURNED]:owned+=1
	for stage: Dictionary in g.rows("growth_stage_defs"):
		if g.state.find("growth_milestone_state","stage_id",stage.stage_id)!=null or not bool(progress(stage).complete):continue
		var row: RefCounted=D.GrowthMilestoneStateDto.new();row.stage_id=stage.stage_id;row.observed_tick=g.state.snapshot.meta.simulation_tick
		row.credit_at_observation=g.state.player().credit;row.reputation_at_observation=reputation(str(stage.faction_id)) if stage.faction_id!=null else 0;row.owned_hulls_at_observation=owned
		g.state.add("growth_milestone_state",row)

func grant_token(task_id: String) -> String:return task_id+":"+g.catalog.content_hash+":"+str(g.honors.progress(task_id))

func grant_reason(task_id: String) -> String:
	if not supported():return "当前世界尚未升级整备款"
	var grant: Dictionary=g.definition("growth_grant_defs","task_id",task_id);var task: Dictionary=g.definition("civilization_honor_task_defs","task_id",task_id)
	if grant.is_empty() or task.is_empty():return "整备项目不存在"
	if g.state.find("growth_grant_receipt_state","task_id",task_id)!=null:return "已领取"
	if g.civilizations.allegiance()!=task.faction_id:return "需效忠对应文明"
	var reason: String=g.civilizations.capital_reason(task.faction_id)
	if not reason.is_empty():return reason
	if g.honors.progress(task_id)<int(task.required_units):return "先完成此项真实考核"
	return ""

func claim(task_id: String,expected: String) -> bool:
	if expected!=grant_token(task_id):return g.fail("整备项目已更新，请重新查看")
	var reason: String=grant_reason(task_id)
	if not reason.is_empty():return g.fail(reason)
	if not g.allowed_service("mission_board"):return false
	var grant: Dictionary=g.definition("growth_grant_defs","task_id",task_id);var task: Dictionary=g.definition("civilization_honor_task_defs","task_id",task_id)
	var row: RefCounted=D.GrowthGrantReceiptStateDto.new();row.task_id=task_id;row.faction_id=task.faction_id;row.paid_credit=int(grant.reward_credit);row.awarded_reputation=int(grant.reward_reputation);row.claimed_tick=g.state.snapshot.meta.simulation_tick
	g.state.add("growth_grant_receipt_state",row);g.state.player().credit+=row.paid_credit;g.civilizations._add_reputation(row.faction_id,row.awarded_reputation)
	g.status_text="整备款 · +%d信用点 / +%d声望" % [row.paid_credit,row.awarded_reputation]
	g.request_autosave();return true
