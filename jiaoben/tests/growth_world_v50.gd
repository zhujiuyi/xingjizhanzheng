extends "owned_fleet_world_v40.gd"
## Declared qualification fixture; actual goal selection, map/service buttons,
## stale callbacks and flight navigation use the real native input endpoints.
var selections: int=0
var maps: int=0
var services: int=0
var navigation_started: bool=false

func _ready() -> void:
	get_tree().set_meta("xj_growth_world_v50_diagnostic",true)
	get_tree().create_timer(360.0).timeout.connect(func():check(false,"growth navigation watchdog");finish())
	run.call_deferred()

func select_goal(id: String) -> bool:
	await show("civilizations")
	var values: Array[Dictionary]=host.gameplay.growth.stages(faction);var index: int=-1
	for i: int in range(values.size()):
		if values[i].stage_id==id:index=i;break
	if not check(index>=0,"goal exists in actual dropdown "+id):return false
	await choose(host.ui.body.find_child("GrowthStage",true,false),index);await settle()
	var goal: RefCounted=host.state.find("growth_goal_state","player_id",host.state.player().player_id)
	var ok: bool=check(goal!=null and goal.stage_id==id,"real dropdown selects persistent goal "+id)
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
	var before_browsing: String=preload("snapshot_signature.gd").runtime(host.state)
	var all_statuses: bool=true
	for stage: Dictionary in host.gameplay.growth.stages(faction):
		for path: Dictionary in host.gameplay.growth.activities(stage.stage_id):
			all_statuses=all_statuses and not host.gameplay.growth.activity_status(path).is_empty()
	check(all_statuses,"every actual growth path explains its current availability")
	check(preload("snapshot_signature.gd").runtime(host.state)==before_browsing,"browsing growth availability preserves every state group and RNG")
	var credit: int=host.state.player().credit
	for suffix: String in ["register","command","research2","hull2","rank5"]:
		var id: String=faction+"_"+suffix
		if not await select_goal(id):await finish();return
		var paths: Array[Dictionary]=host.gameplay.growth.activities(id);var index: int=int(paths[0].activity_index)
		var expected_page: String=host.gameplay.growth.service_page(id,index)
		if not await click(host.ui.body.find_child("Growth_growth_open",true,false),"opens actual goal service "+suffix):await finish();return
		await frames(5)
		if check(host.ui.page==expected_page,"goal uses correct canonical service "+suffix):services+=1
		await show("civilizations")
		var expected: Dictionary=host.gameplay.growth.guidance(id,index)
		if not await click(host.ui.body.find_child("Growth_growth_map",true,false),"locates actual goal route "+suffix):await finish();return
		await frames(5)
		if check(host.ui.page=="map" and host.ui.resource_chart.selected_sector==str(expected.sector_id),"map selection matches authoritative activity location "+suffix):maps+=1
	check(host.state.player().credit==credit,"planning and opening services do not spend or grant money")
	await capture("growth-map-selection")
	if not await select_goal(faction+"_register"):await finish();return
	var old_button: Button=host.ui.body.find_child("Growth_growth_open",true,false)
	var stale: Callable=old_button.get_signal_connection_list("pressed")[0].callable
	if not await select_goal(faction+"_hull2"):await finish();return
	stale.call();await frames(3)
	check(host.ui.page=="civilizations" and host.gameplay.growth.selected(faction).stage_id==faction+"_hull2","old goal callback cannot open another current service")
	await capture("growth-selected-goal")
	await host._command("undock","",1,"");await settle()
	if not await select_goal(faction+"_register"):await finish();return
	var info: Dictionary=host.gameplay.growth.guidance(faction+"_register",0)
	if not await click(host.ui.body.find_child("Growth_growth_navigate",true,false),"flies toward the actual selected goal"):await finish();return
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
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"selections":selections,"maps":maps,"services":services,"navigation_started":navigation_started}
	print("GROWTH_WORLD_V50_FINAL_JSON ",JSON.stringify(summary));print("GROWTH_WORLD_V50_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
