extends "owned_fleet_world_v40.gd"
## Declared qualification fixture; actual current/preview goal, map/service buttons,
## stale callbacks and flight navigation use the real native input endpoints.
var selections: int=0
var maps: int=0
var services: int=0
var navigation_started: bool=false
var selected_prefix: String="GrowthPreview"
var advanced: bool=false
const GrowthCodec=preload("res://runtime/data/codec.gd")

func settle() -> void:
	var deadline: int=Time.get_ticks_msec()+60000
	while is_instance_valid(host) and host.busy and Time.get_ticks_msec()<deadline:await frames()
	if not check(is_instance_valid(host) and not host.busy,"growth Main action settles within the bounded asynchronous loading window"):return
	host._process(0.0);await frames()

func goal_signature() -> String:
	var result: Array[String]=[]
	for row: RefCounted in host.state.rows("growth_goal_state"):result.append(JSON.stringify(GrowthCodec.new().encode_row("growth_goal_state",row)))
	result.sort();return JSON.stringify(result)

func _ready() -> void:
	get_tree().set_meta("xj_growth_world_v50_diagnostic",true)
	get_tree().create_timer(360.0).timeout.connect(func():check(false,"growth navigation watchdog");finish())
	run.call_deferred()

func select_goal(id: String) -> bool:
	var definition: Dictionary=host.gameplay.definition("growth_stage_defs","stage_id",id)
	if not check(not definition.is_empty() and not bool(host.gameplay.growth.progress(definition).complete),"requested current/planned goal is actually incomplete "+id):return false
	host.ui.civilization_selected_faction=str(definition.faction_id) if definition.faction_id!=null else faction
	host.ui.set_meta("civilization_section","progress")
	await show("civilizations")
	var before: String=goal_signature()
	var recommendation: Dictionary=host.ui.civilization_panel.growth_panel.selected_stage
	if str(recommendation.get("stage_id",""))==id:
		selected_prefix="Growth";selections+=1
		return check(host.ui.body.find_child("GrowthCurrentStage",true,false).text==str(definition.display_name) and goal_signature()==before,"current recommendation uses actual progress without persisting a selected target")
	var routes: Control=host.ui.body.find_child("GrowthRoutes",true,false)
	if not check(routes!=null,"other incomplete routes are available behind the planning disclosure"):return false
	if not routes.is_visible_in_tree():
		if not await click(host.ui.body.find_child("GrowthRoutesToggle",true,false),"reveals optional goal planning"):return false
	var stage: Label=host.ui.body.find_child("GrowthStage",true,false) as Label
	if not check(stage!=null and stage.is_visible_in_tree() and stage.has_meta("route_count"),"planning shows one labelled goal rather than a full persistent dropdown"):return false
	var maximum: int=int(stage.get_meta("route_count"))
	for step: int in range(maximum):
		var previous: Button=host.ui.body.find_child("GrowthPreviewPrevious",true,false) as Button
		if previous.disabled:break
		if not await click(previous,"browses to the first planned goal"):return false
	var found: bool=false
	for step: int in range(maximum):
		stage=host.ui.body.find_child("GrowthStage",true,false) as Label
		if str(stage.get_meta("stage_id"))==id:found=true;break
		var next: Button=host.ui.body.find_child("GrowthPreviewNext",true,false) as Button
		if next.disabled:break
		if not await click(next,"browses the next actual planned goal"):return false
	selected_prefix="GrowthPreview"
	var current_label: Label=host.ui.body.find_child("GrowthCurrentStage",true,false) as Label
	var ok: bool=check(found and current_label!=null and current_label.text==str(recommendation.display_name) and goal_signature()==before,"native one-goal planning previews "+id+" without replacing the recommendation or writing growth_goal_state")
	if ok:selections+=1
	return ok

func run() -> void:
	directory=OS.get_environment("XJ_GROWTH_WORLD_V50_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/growth-world-v50/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh native growth navigation scope"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=AtomicHost.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","成长入口联合验证",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await qualified_frontier():await finish();return
	host.ui.civilization_selected_faction=faction
	host.ui.set_meta("civilization_section","progress")
	await show("civilizations")
	var current: Dictionary=host.ui.civilization_panel.growth_panel.selected_stage
	if not check(not current.is_empty() and not bool(host.gameplay.growth.progress(current).complete),"qualified real world displays the first incomplete recommended criterion"):await finish();return
	check(host.ui.body.find_child("GrowthCurrentStage",true,false).text==str(current.display_name),"current label describes the authoritative recommendation")
	# Complete the known owned-hull boundary with an actual paid Main action,
	# rather than changing milestone/goal rows to force the next UI stage.
	if not check(current.criterion_kind=="owned_hull","declared qualified fixture reaches its unowned civilization hull criterion"):await finish();return
	var old_goal: String=goal_signature();var wallet: int=host.state.player().credit
	var price: int=host.gameplay.economy.quote_ship(str(current.reference_id))
	var hull_count: int=host.state.rows("ship_state").size()
	var stocks: Array=host.state.rows("shop_ship_stock_state").filter(func(row: RefCounted):return row.station_id==host.gameplay.station() and row.ship_def_id==current.reference_id)
	if not check(price>0 and stocks.size()==1 and stocks[0].quantity>0 and host.gameplay.civilizations.hull_reason(str(current.reference_id)).is_empty(),"actual current hull has catalog stock and true civilization purchase permission"):await finish();return
	var stock_before: int=stocks[0].quantity
	await host._command("buy_ship",str(current.reference_id),1,"");await settle()
	check(host.state.player().credit==wallet-price and host.state.rows("ship_state").size()==hull_count+1 and bool(host.gameplay.growth.progress(current).complete),"actual exact-price purchase supplies the real owned hull and completes its criterion")
	check(stocks[0].quantity==stock_before-1 and host.state.rows("ship_state").any(func(row: RefCounted):return row.ship_def_id==current.reference_id and row.policy_id=="normal_owned" and row.owner_player_id==host.state.player().player_id),"purchase consumes one actual stock unit and creates a normal player-owned hull")
	await get_tree().create_timer(0.3).timeout;host.ui.tick(0.0);await frames(5)
	var next_current: Dictionary=host.ui.civilization_panel.growth_panel.selected_stage
	advanced=check(not next_current.is_empty() and str(next_current.stage_id)!=str(current.stage_id) and not bool(host.gameplay.growth.progress(next_current).complete) and goal_signature()==old_goal,"completed actual ownership automatically advances displayed recommendation without selecting/persisting a future goal")
	var before_browsing: String=preload("snapshot_signature.gd").runtime(host.state)
	var all_statuses: bool=true
	for stage: Dictionary in host.gameplay.growth.stages(faction):
		for path: Dictionary in host.gameplay.growth.activities(stage.stage_id):
			all_statuses=all_statuses and not host.gameplay.growth.activity_status(path).is_empty()
	check(all_statuses,"every actual growth path explains its current availability")
	check(preload("snapshot_signature.gd").runtime(host.state)==before_browsing,"browsing growth availability preserves every state group and RNG")
	var credit: int=host.state.player().credit
	var planning_faction: String=""
	for definition: Dictionary in host.store.catalog.rows("civilization_defs"):
		if str(definition.faction_id)!=faction:planning_faction=str(definition.faction_id);break
	if not check(not planning_faction.is_empty(),"another actual civilization supplies uncompleted planning branches without changing allegiance"):await finish();return
	for suffix: String in ["join","register","command","hull2","war"]:
		var id: String=planning_faction+"_"+suffix
		if not await select_goal(id):await finish();return
		var paths: Array[Dictionary]=host.gameplay.growth.activities(id);var index: int=int(paths[0].activity_index)
		var expected_page: String=host.gameplay.growth.service_page(id,index)
		if not await click(host.ui.body.find_child(selected_prefix+"_growth_open",true,false),"opens actual current/planned goal service "+suffix):await finish();return
		await frames(5)
		if check(host.ui.page==expected_page,"goal uses correct canonical service "+suffix):services+=1
		if suffix in ["register","command","war"]:check(str(host.ui.get_meta("civilization_section","progress"))==("campaign" if suffix=="war" else "command"),"actual growth deep link selects the appropriate civilization category "+suffix)
		if not await select_goal(id):await finish();return
		var expected: Dictionary=host.gameplay.growth.guidance(id,index)
		if not await click(host.ui.body.find_child(selected_prefix+"_growth_map",true,false),"locates actual goal route "+suffix):await finish();return
		await frames(5)
		if check(host.ui.page=="map" and host.ui.resource_chart.selected_sector==str(expected.sector_id),"map selection matches authoritative activity location "+suffix):maps+=1
	check(host.state.player().credit==credit,"planning and opening services do not spend or grant money")
	await capture("growth-map-selection")
	if not await select_goal(planning_faction+"_register"):await finish();return
	var old_button: Button=host.ui.body.find_child(selected_prefix+"_growth_open",true,false)
	var stale: Callable=old_button.get_signal_connection_list("pressed")[0].callable
	if not await select_goal(planning_faction+"_hull2"):await finish();return
	old_goal=goal_signature()
	stale.call();await frames(3)
	check(host.ui.page=="civilizations" and str(host.ui.body.find_child("GrowthStage",true,false).get_meta("stage_id"))==planning_faction+"_hull2" and goal_signature()==old_goal,"old goal callback cannot open another current service or persist a former preview")
	await capture("growth-selected-goal")
	await host._command("undock","",1,"");await settle()
	if not await select_goal(faction+"_war"):await finish();return
	var info: Dictionary=host.gameplay.growth.guidance(faction+"_war",0)
	if not await click(host.ui.body.find_child(selected_prefix+"_growth_navigate",true,false),"flies toward the actual current/planned goal"):await finish();return
	navigation_started=check(host.ui.page=="" and host.local_navigation.target_id==str(info.waypoint_id) and host.local_navigation.mode=="approach","goal button starts ordinary local navigation")
	await capture("growth-flight-navigation")
	await host._command("frontier_map","war_council_01",1,host.gameplay.frontier.expected_token("war_council_01"));await frames(4)
	check(host.ui.page=="map" and host.ui.resource_chart.selected_sector=="sector_frontier_01","frontier locating uses the same valid star-chart interface")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"selections":selections,"maps":maps,"services":services,"navigation_started":navigation_started,"automatic_advance":advanced,"fixture":"existing qualified frontier fixture; exact-price real owned-hull purchase completes current criterion; other civilization previews never change allegiance or growth_goal_state"}
	print("GROWTH_WORLD_V50_FINAL_JSON ",JSON.stringify(summary));print("GROWTH_WORLD_V50_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
