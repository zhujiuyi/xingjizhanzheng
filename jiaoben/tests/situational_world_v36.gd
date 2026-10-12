extends "tactics_world_v29.gd"
## Real Main/AI/UI/audio. Qualification, assets and initial encounter poses are
## declared fixtures. Timers, hostile preparation/jam and input run normally.
var physical_cues: Array[String]=[]
var audio_played: bool=false
var pause_checked: bool=false

func _ready() -> void:
	get_tree().set_meta("xj_situational_world_v36_diagnostic",true)
	get_tree().create_timer(420.0).timeout.connect(func():check(false,"situational native watchdog");finish())
	run.call_deferred()

func record_cue(cue: Dictionary) -> void:
	if not physical_cues.has(str(cue.cue_id)):physical_cues.append(str(cue.cue_id))
	for voice: Variant in host.presentation.voices:
		if is_instance_valid(voice) and voice is AudioStreamPlayer and voice.bus=="UI" and voice.playing:audio_played=true

func wait_cue(id: String) -> bool:
	host.set_process(true);host.set_physics_process(true)
	var deadline: int=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		if host.gameplay.situational.cues().any(func(row: Dictionary):return row.cue_id==id):break
		await frames(1)
	host.set_process(false);host.set_physics_process(false);host.ui.tick(1.0);await frames(3)
	var present: bool=host.gameplay.situational.cues().any(func(row: Dictionary):return row.cue_id==id)
	if present and not physical_cues.has(id):physical_cues.append(id)
	return present

func prerequisite_fixture(g: Gameplay, id: String) -> bool:
	for pre: Dictionary in g.rows("mission_prerequisites"):
		if pre.mission_id!=id or g.missions.completed(pre.prerequisite_mission_id):continue
		var parent: String=pre.prerequisite_mission_id
		if not prerequisite_fixture(g,parent):return false
		var def: Dictionary=g.definition("mission_defs","mission_id",parent)
		var station: Dictionary=g.definition("station_defs","station_id",def.accept_station_id)
		place(g.state,g,station.station_anchor_id,station.station_id);g.tactics.tick(0.0)
		if not check(g.act("accept_mission",parent).phase==T.ActionPhase.APPLIED,"fixture prerequisite accepts through actual business "+parent):return false
		var mission: RefCounted=g.missions.active()
		# Explicit prerequisite-progress fixtures, not physical tutorial completion.
		for obj: Dictionary in g.missions.objectives(parent):
			if obj.objective_kind=="deliver":
				g.inventory.grant(g.inventory.hold(g.state.ship(),T.ContainerKind.CARGO),obj.target_item_id,int(obj.required_count),"mission_bound" if def.mission_kind=="tutorial" else "normal_owned",mission.mission_instance_id if def.mission_kind=="tutorial" else "")
				continue
			g.missions.progress(mission,int(obj.objective_index)).progress_units=int(obj.required_count)
			if obj.objective_kind=="collect":
				mission.collected_units+=int(obj.required_count)
				var proof: D.MissionCollectEventStateDto=D.MissionCollectEventStateDto.new()
				proof.event_id=g.id("fixture_collect");proof.mission_instance_id=mission.mission_instance_id;proof.item_def_id=obj.target_item_id;proof.quantity=int(obj.required_count);proof.event_tick=g.state.snapshot.meta.simulation_tick;g.state.add("mission_collect_event_state",proof)
		station=g.definition("station_defs","station_id",def.turnin_station_id)
		place(g.state,g,station.station_anchor_id,station.station_id)
		if not check(g.act("deliver_mission",mission.mission_instance_id).phase==T.ActionPhase.APPLIED,"fixture material custody and reward receipt settle normally "+parent):return false
	return true

func run() -> void:
	directory=OS.get_environment("XJ_SITUATIONAL_WORLD_V36_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/situational-world-v36/") and not FileAccess.file_exists(directory.path_join("progress.db")),"native fresh scoped world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	if not check(host.services_ready,"actual client initializes situational rules"):await finish();return
	await host._command("new_world","情报与状态原生验收",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await qualify("interceptor",true):await finish();return
	host.preferences.vfx_intensity=0.0;host._apply_preferences()
	host.gameplay.situational.cue_started.connect(record_cue)
	host.ui.show_page("")
	check(await wait_cue("charge"),"real hostile AI enters preparation and produces a typed warning")
	check(host.ui.flight_cues.visible and host.ui.flight_cues.tooltip_text.contains("拉开距离"),"persistent icon/text offers the real counter at zero effects")
	await capture("feedback-charge-zero-fx")
	check(await wait_cue("jam"),"real prepared hostile applies propulsion interference")
	check(host.gameplay.tactics.thrust_ratio(host.state.ship().ship_instance_id)<1.0 and host.ui.flight_cues.tooltip_text.contains("推进受扰"),"warning matches an actual movement modifier")
	check(audio_played,"typed zero-FX warning reaches a playing UI audio consumer")
	await capture("feedback-jam-zero-fx")
	for layout: Dictionary in [{"size":Vector2i(3440,1188),"scale":1.0},{"size":Vector2i(1280,720),"scale":2.0}]:
		root.size=layout.size;root.content_scale_factor=1.0;root.content_scale_size=Vector2i(Vector2(layout.size)/layout.scale)
		await frames(6);host.ui.tick(1.0);host.ui._responsive();await frames(5)
		var strip: Control=host.ui.flight_cues;var bounds: Rect2=Rect2(Vector2.ZERO,host.ui.root.size)
		check(host.ui.root.size.is_equal_approx(Vector2(layout.size)/layout.scale),"exact physical size and UI scale")
		check(strip.visible and bounds.encloses(strip.get_global_rect()),"status strip remains inside the full viewport")
		check(not strip.get_global_rect().intersects(host.ui.flight_dock.get_global_rect()) and not strip.get_global_rect().intersects(host.ui.target_panel.get_global_rect()),"persistent warnings preserve equipment and target controls")
		check((strip.get("list") as VBoxContainer).get_child_count()==1 if layout.scale==2.0 else (strip.get("list") as VBoxContainer).get_child_count()<=3,"small canvas condenses persistent statuses")
		await capture("feedback-layout-%d" % int(layout.scale*100))
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900);await frames(5)
	await key(KEY_ESCAPE)
	check(host.ui.page=="pause","actual Escape opens the pause page")
	var tick: int=host.state.snapshot.meta.simulation_tick
	await run_for(1.0)
	pause_checked=host.state.snapshot.meta.simulation_tick==tick
	check(pause_checked,"actual paused process freezes gameplay and observation age")
	await key(KEY_ESCAPE)
	# Build a legal unarmed contract fixture, then use real mission and UI actions.
	var candidate: XJRuntimeState=host.store.clone_state(host.state)
	var g: Gameplay=Gameplay.new();g.setup(candidate,host.store.catalog)
	var mission: Dictionary=g.definition("mission_defs","mission_id","contract_mining_iron")
	if not prerequisite_fixture(g,mission.mission_id):g.dispose();await finish();return
	if not check(not mission.is_empty(),"authored mining contract offers a real device-dependent objective"):g.dispose();await finish();return
	var ship: RefCounted=g.inventory.create_ship("frigate_kestrel",mission.accept_station_id)
	candidate.player().controlled_ship_id=ship.ship_instance_id
	var station: Dictionary=g.definition("station_defs","station_id",mission.accept_station_id)
	place(candidate,g,station.station_anchor_id,station.station_id);g.tactics.tick(0.0)
	check(g.act("accept_mission",mission.mission_id).phase==T.ActionPhase.APPLIED,"actual station authority accepts the mining contract")
	g.situational.observe();g.dispose()
	if not await activate(candidate):await finish();return
	await show("missions")
	check(host.ui._mission_list_description(mission,host.gameplay.missions.active()).contains("当前步骤"),"mission shows current step and actual counts")
	check(host.ui._mission_list_description(mission,host.gameplay.missions.active()).contains("缺少"),"bare hull has a concise missing-device explanation")
	await capture("mission-current-step-and-gap")
	var guide: Button=host.ui.body.find_child("MissionEquipmentGuide",true,false)
	if await click(guide,"guarded current mission fitting guide"):check(host.ui.page=="fitting","device guidance opens the actual fitting page")
	await show("map")
	host.ui.resource_chart.select_sector(station.sector_id);await frames(5)
	var demand: Dictionary={}
	for def: Dictionary in host.store.catalog.rows("station_demand_defs"):
		if def.station_id==station.station_id:demand=def;break
	if not check(not demand.is_empty(),"contract station has authored industrial demand"):await finish();return
	var label: Label=host.ui.map_details.find_child("DemandIntel_"+str(demand.demand_id),true,false)
	check(label!=null and label.text.contains("本站报价"),"star map demand is linked to a live docked station quote")
	await capture("galaxy-demand-and-route")
	var button: Button=host.ui.map_details.find_child("DemandTravel_"+str(demand.demand_id),true,false)
	var old_callback: Callable=button.get_signal_connection_list("pressed")[0].callable
	if await click(button,"station industrial demand entry"):check(host.ui.page=="industry","current demand opens the shared industrial service")
	await show("map");host.ui.resource_chart.select_sector("sector_mirror");await frames(5)
	old_callback.call()
	check(host.ui.page=="map","removed demand callback cannot open a different page or navigate")
	await host._command("undock","",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	await show("map");host.ui.resource_chart.select_sector(station.sector_id);await frames(5)
	button=host.ui.map_details.find_child("DemandTravel_"+str(demand.demand_id),true,false)
	if await click(button,"actual demand station navigation"):
		check(host.source_goal.get("demand","")==demand.demand_id,"demand navigation binds its stable authority identity")
		check(bool(host.navigation_context(station.station_id).get("active",false)),"demand route creates a real local navigation intent")
	await capture("demand-real-navigation")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"physical_cues":physical_cues.size(),"audio_played":audio_played,"pause_checked":pause_checked}
	print("SITUATIONAL_WORLD_V36_FINAL_JSON ",JSON.stringify(summary));print("SITUATIONAL_WORLD_V36_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
