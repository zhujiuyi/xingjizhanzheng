extends "tactics_world_v29.gd"
## Imports a closed test-owned business fixture. Qualification, money, completed
## project and arrival poses are declared; inputs/actors/damage use real Main.
var project_visual_checked: bool=false
var physical_tactics: bool=false
var actual_damage: float=0.0
var exported: bool=false
func _ready() -> void:
	get_tree().set_meta("xj_campaign_world_v37_diagnostic",true)
	get_tree().create_timer(420.0).timeout.connect(func():check(false,"campaign native watchdog");finish())
	run.call_deferred()
func run() -> void:
	directory=OS.get_environment("XJ_CAMPAIGN_WORLD_V37_DIRECTORY").replace("\\","/")
	var source: String=OS.get_environment("XJ_CAMPAIGN_CORE_DATABASE").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/campaign-world-v37/") and not FileAccess.file_exists(directory.path_join("progress.db")),"native campaign uses fresh scoped directory"):await finish();return
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/campaign-v37/") and not source.contains("..") and FileAccess.file_exists(source),"closed business fixture is test-owned"):await finish();return
	check(DirAccess.copy_absolute(source,directory.path_join("progress.db"))==OK,"fixture copied without touching source")
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(6)
	if not check(host.services_ready,"actual campaign UI initializes"):await finish();return
	var slot: Dictionary={}
	for row: Dictionary in host.store.list_slots():
		if row.slot_kind=="manual" and int(row.slot_index)==3:slot=row;break
	if not check(not slot.is_empty(),"completed project fixture has durable manual endpoint"):await finish();return
	await host._command("load",slot.slot_id,int(slot.generation),slot.current_snapshot_id);await settle();host.set_process(false);host.set_physics_process(false)
	await show("industry")
	if await click(host.ui.body.find_child("IndustryProjects",true,false),"actual industrial project entry"):check(host.ui.page=="projects","shared industrial service opens project page")
	check(host.ui.body.find_child("ProjectStatus",true,false)!=null,"project progress has concise status control")
	await capture("campaign-project-completed")
	if await click(host.ui.body.find_child("ProjectSelect_project_frontier_02",true,false),"select another preserved project"):
		var paused: bool=host.gameplay.projects.instance("project_frontier_02").paused
		if await click(host.ui.body.find_child("ProjectPause",true,false),"pause unfinished construction"):
			check(host.gameplay.projects.instance("project_frontier_02").paused!=paused,"actual command changes only selected project's pause")
	await show("reports")
	var before: String=state_signature()
	if await click(host.ui.body.find_child("ReportExportCSV",true,false),"export measured CSV report"):
		await click(host.ui.body.find_child("ReportExportJSON",true,false),"export measured JSON report")
	check(state_signature()==before,"report export leaves game state and random stream unchanged")
	var report_dir: String=directory.path_join("reports");var json_found: bool=false;var csv_found: bool=false
	for file: String in DirAccess.get_files_at(report_dir):
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(report_dir.path_join(file))
		if file.ends_with(".csv"):csv_found=bytes.size()>3 and bytes[0]==239 and bytes[1]==187 and bytes[2]==191
		if file.ends_with(".json"):
			var payload: Variant=JSON.parse_string(bytes.get_string_from_utf8())
			json_found=payload is Dictionary and payload.format_version==1 and payload.reports is Array
			check(not bytes.get_string_from_utf8().contains("Users/") and not bytes.get_string_from_utf8().contains("user://"),"export contains game metrics without operating-system paths")
	exported=json_found and csv_found;check(exported,"both real exported files use expected UTF-8 and data envelope")
	await capture("campaign-reports")
	await host._command("undock","",1,"");await settle();host.set_process(false);host.set_physics_process(false);host._process(0.0);await frames(6)
	var station: Variant=host.world.targets.get("station_frontier_01",{}).get("node")
	var upgrades: Node=station.get_node_or_null("ProjectUpgrades") if is_instance_valid(station) else null
	project_visual_checked=upgrades!=null and int(upgrades.get_meta("completed_stages",0))==3 and upgrades.get_child_count()==3
	check(project_visual_checked,"completed construction creates three actual station attachments")
	await capture("campaign-station-upgrades")
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var g: Gameplay=Gameplay.new();g.setup(candidate,host.store.catalog)
	var mirror: Dictionary=g.definition("station_defs","station_id","station_mirror_hub")
	place(candidate,g,mirror.station_anchor_id,mirror.station_id);g.telemetry.finish()
	g.exploration.instance("exp_theme_frontier_01_relic").variant_id="exp_theme_frontier_01_relic_v3"
	g.dispose()
	if not await activate(candidate):await finish();return
	await show("missions")
	if await click(host.ui.body.find_child("MissionExpeditions",true,false),"actual mission-to-expedition entry"):check(host.ui.page=="expeditions","expedition uses one shared mission category")
	if await click(host.ui.body.find_child("ExpeditionStart_route_archive_archive",true,false),"accept actual named expedition"):
		check(host.gameplay.expeditions.active()!=null,"real route has accepted finite stage binding")
		await capture("campaign-expedition-accepted")
		if await click(host.ui.body.find_child("ExpeditionWithdraw",true,false),"withdraw an unstarted route at its actual origin"):
			await run_for(0.2);check(host.gameplay.expeditions.active()==null,"unstarted withdrawal finishes only at the real preparation station")
	# Stage a legal combat/sensor ship; the event itself must run normal actions.
	candidate=host.store.clone_state(host.state);g=Gameplay.new();g.setup(candidate,host.store.catalog)
	var hull: RefCounted=g.inventory.create_ship("battleship_bastion",mirror.station_id);candidate.player().controlled_ship_id=hull.ship_instance_id
	place(candidate,g,mirror.station_anchor_id,mirror.station_id)
	for pair: Array in [["module_thermal_sunline_iii","weapon:1"],["module_scanner_beacon_i","utility:0"]]:
		var item: String=g.inventory.grant(g.inventory.warehouse(mirror.station_id),pair[0],1)[0]
		check(g.act("fit_module",item,1,pair[1]).phase==T.ActionPhase.APPLIED,"native legal campaign loadout "+str(pair[0]))
	var event: RefCounted=g.exploration.instance("exp_theme_frontier_01_relic")
	g.exploration._clear_actors(event);event.generation+=1;event.phase="clue";event.variant_id="exp_theme_frontier_01_relic_v3";event.operation_kind="";event.operation_remaining_s=0;event.elapsed_s=0;event.evidence_units=0;event.stabilized=false;event.outcome=""
	place(candidate,g,g.exploration.definition(event.event_id).entry_anchor_id);hull.pos_z+=300;g.dispose()
	if not await activate(candidate):await finish();return
	host.ui.open_exploration(event.event_id);await frames(6)
	var survey: Button=host.ui.body.find_child("ExploreAction_survey",true,false)
	if not await click(survey,"actual campaign survey action"):await finish();return
	host.set_process(true);host.set_physics_process(true)
	var deadline: int=Time.get_ticks_msec()+45000
	while not host.gameplay.exploration.instance(event.event_id).operation_kind.is_empty() and Time.get_ticks_msec()<deadline:await frames(2)
	host.set_process(false);host.set_physics_process(false)
	check(not host.state.rows("exploration_actor_state").any(func(member: RefCounted):return member.event_id==event.event_id and member.actor_role=="enemy"),"survey alone does not create a premature combat encounter")
	host.ui.open_exploration(event.event_id);await frames(5)
	if not await click(host.ui.body.find_child("ExploreAction_deepen",true,false),"actual decision to enter the relic threat"):await finish();return
	host.set_process(true);host.set_physics_process(true)
	deadline=Time.get_ticks_msec()+30000
	while not host.gameplay.exploration.instance(event.event_id).operation_kind.is_empty() and Time.get_ticks_msec()<deadline:await frames(2)
	host.set_process(false);host.set_physics_process(false)
	var actors: Array[String]=[];var kinds: Array[String]=[]
	for member: RefCounted in host.state.rows("exploration_actor_state"):
		if member.event_id!=event.event_id or member.actor_role!="enemy":continue
		actors.append(member.npc_instance_id);kinds.append(host.gameplay.tactics.definition(member.npc_instance_id).tactic_kind)
	check(actors.size()==3 and "support" in kinds and "interceptor" in kinds and "siege" in kinds,"real deepen decision spawns exactly the three managed tactical roles")
	host.ui.show_page("");await run_for(2.0)
	physical_tactics=actors.any(func(id: String):return host.gameplay.tactics.instance(id).phase in ["charging","active","cooldown"])
	check(physical_tactics,"managed campaign roles execute actual AI preparation or effects")
	await capture("campaign-managed-tactics")
	if not actors.is_empty():
		var total: RefCounted=host.gameplay.telemetry.totals();var measured: float=total.damage_dealt
		await fire_at(actors[0]);actual_damage=total.damage_dealt-measured
		check(actual_damage>0.0,"real player ray records bounded actual damage contribution")
	for layout: Dictionary in [{"size":Vector2i(3440,1188),"scale":1.0},{"size":Vector2i(1280,720),"scale":2.0}]:
		root.size=layout.size;root.content_scale_factor=1.0;root.content_scale_size=Vector2i(Vector2(layout.size)/layout.scale)
		await show("projects");var select: Button=host.ui.body.find_child("ProjectSelect_project_frontier_01",true,false);await reveal(select)
		check(Rect2(Vector2.ZERO,host.ui.root.size).encloses(select.get_global_rect()),"project selectors remain reachable at exact layout "+str(layout.size))
		await capture("campaign-layout-"+str(int(layout.scale*100)))
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(6);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"project_visual":project_visual_checked,"physical_tactics":physical_tactics,"actual_damage":actual_damage,"exported":exported}
	print("CAMPAIGN_WORLD_V37_FINAL_JSON ",JSON.stringify(summary));print("CAMPAIGN_WORLD_V37_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
