extends "owned_fleet_world_v40.gd"
## Qualification/loadout/wealth are inherited declared fixtures. All subsequent
## motion is the real Main physics loop; GUI uses the existing native input path.
const MarchSignature=preload("snapshot_signature.gd")
var native_moved_m: float=0.0
var departed: bool=false
var gate_ready_checked: bool=false
var gate_hidden_checked: bool=false
var gate_restore_checked: bool=false
var grant_ui_checked: bool=false
var march_pause_checked: bool=false
var war_id: String="war_council_01"
var frame_metrics: RefCounted=preload("frame_metrics.gd").new()

func _process(delta: float) -> void:
	frame_metrics.observe(host,delta)

func _ready() -> void:
	get_tree().set_meta("xj_march_world_v49_diagnostic",true)
	get_tree().create_timer(900.0).timeout.connect(func():check(false,"march native watchdog");finish())
	run.call_deferred()

func row() -> RefCounted:return host.gameplay.march.state_for(war_id)

func live_until(condition: Callable,seconds: float) -> bool:
	host.set_process(true);host.set_physics_process(true)
	var deadline: int=Time.get_ticks_msec()+ceili(seconds*1000.0)
	while Time.get_ticks_msec()<deadline:
		if bool(condition.call()):return true
		await get_tree().physics_frame
	return bool(condition.call())

func run() -> void:
	directory=OS.get_environment("XJ_MARCH_WORLD_V49_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/march-world-v49/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh native march scope"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=AtomicHost.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","行军与成长原生联合验证",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await qualified_frontier():await finish();return
	host.ui.civilization_selected_faction=faction;await show("civilizations")
	check(host.ui.body.find_child("GrowthPanel",true,false)!=null,"growth uses the civilization service and compact goal panel")
	var button: Button=host.ui.body.find_child("GrowthGrant_scout",true,false)
	if not check(is_instance_valid(button) and not button.disabled,"earned grant has an actual enabled UI action"):await finish();return
	var before: String=MarchSignature.runtime(host.state);var slots: String=JSON.stringify(host.store.list_slots())
	host.reject_stage=true;await click(button,"grant staging failure")
	check(host.last_error.contains("Declared native staging fault") and MarchSignature.runtime(host.state)==before and JSON.stringify(host.store.list_slots())==slots,"failed staging publishes no grant or progress");host.reject_stage=false
	var original_store: RefCounted=host.store;var faulty: ObservedFaultStore=ObservedFaultStore.new(directory.path_join("progress.db"))
	check(faulty.open(),"native grant fault writer opens");faulty.active_state=host.state;faulty.reject_point="pointer";host.store=faulty
	await click(button,"grant SQL commit failure")
	check(faulty.rejected_writes==1 and MarchSignature.runtime(host.state)==before and JSON.stringify(host.store.list_slots())==slots,"actual SQL failure publishes no grant or changed slots")
	host.store=original_store;faulty.close();faulty=null
	var stale: Callable=button.get_signal_connection_list("pressed")[0].callable
	var credit: int=host.state.player().credit;var task_id: String=""
	for task: Dictionary in host.gameplay.honors.tasks(faction):
		if task.task_kind=="scout":task_id=task.task_id
	var grant: Dictionary=host.gameplay.definition("growth_grant_defs","task_id",task_id)
	await click(button,"claims earned outfitting funds");await settle()
	grant_ui_checked=check(host.state.player().credit==credit+int(grant.reward_credit) and host.state.find("growth_grant_receipt_state","task_id",task_id)!=null,"native claim commits one real award")
	before=MarchSignature.runtime(host.state);stale.call();await frames(2)
	check(MarchSignature.runtime(host.state)==before,"replaced-world grant callback cannot pay again")
	for layout: Dictionary in [{"size":Vector2i(1440,900),"scale":1.0,"tag":"standard"},{"size":Vector2i(3440,1188),"scale":1.0,"tag":"wide"},{"size":Vector2i(1280,720),"scale":2.0,"tag":"compact-200"}]:
		root.size=layout.size;root.content_scale_size=Vector2i(Vector2(layout.size)/float(layout.scale));await frames(5);await show("civilizations")
		for name: String in ["GrowthStage","GrowthActivity","Growth_growth_map","Growth_growth_navigate","Growth_growth_open"]:
			var control: Control=host.ui.body.find_child(name,true,false);await reveal(control)
			check(is_instance_valid(control) and control.size.x>30 and control.size.y>20 and Rect2(Vector2.ZERO,host.ui.root.size).encloses(control.get_global_rect()),"growth control remains accessible "+name+" "+str(layout.tag))
		await capture("growth-"+str(layout.tag))
	root.size=Vector2i(1440,900);root.content_scale_size=root.size;await frames(5);await show("civilizations")
	button=host.ui.body.find_child("CivilizationWar_"+war_id,true,false)
	if not await click(button,"starts actual funded march through civilization UI"):await finish();return
	if not check(row()!=null and row().phase=="assembling","native war starts at capital assembly"):await finish();return
	var ids: Array[String]=[];var origins: Dictionary={}
	for m: RefCounted in host.gameplay.march.members(row(),true):
		ids.append(m.npc_instance_id);origins[m.npc_instance_id]=host.gameplay.position(host.state.find("npc_state","npc_instance_id",m.npc_instance_id))
	await host._command("undock","",1,"");await settle();host.ui.show_page("")
	if not check(await live_until(func():return row().phase=="site_align" and host.world.npcs.has(ids[0]),30.0),"original allied bodies are visible at departure"):await finish();return
	check(await live_until(func():return host.world.npcs.has(ids[0]) and host.world.npcs[ids[0]].position.distance_to(origins[ids[0]])>200.0,25.0),"real original body flies clear of capital")
	if host.world.npcs.has(ids[0]):native_moved_m=host.world.npcs[ids[0]].position.distance_to(origins[ids[0]])
	await capture("march-capital-motion")
	host.ui.show_page("pause");await frames(2)
	var paused_tick: int=host.state.snapshot.meta.simulation_tick;var remaining: float=row().phase_remaining_s
	var poses: Dictionary={}
	for id: String in ids:poses[id]=host.gameplay.position(host.state.find("npc_state","npc_instance_id",id))
	await get_tree().create_timer(1.2).timeout
	var still: bool=host.state.snapshot.meta.simulation_tick==paused_tick and row().phase_remaining_s==remaining
	for id: String in ids:still=still and poses[id]==host.gameplay.position(host.state.find("npc_state","npc_instance_id",id))
	march_pause_checked=check(still,"actual pause freezes march clocks and physical poses")
	host.ui.show_page("")
	if not check(await live_until(func():return row().phase=="site_warp",30.0),"fleet enters actual intra-system transit"):await finish();return
	await frames(3);departed=true
	for id: String in ids:departed=departed and not host.world.npcs.has(id)
	check(departed,"departing ships leave the source scene before destination arrival")
	var endpoint: Dictionary=host.gameplay.march._endpoint(row());var endpoint_id: String=endpoint.endpoint_id
	await host._command("nav_warp",endpoint_id,1,"")
	if not check(await live_until(func():return not host.local_navigation.warp_active() and XJSpaceCoordinates.current_site(host.state)==XJSpaceCoordinates.site_for_anchor(host.store.catalog,endpoint.entry_anchor_id),90.0),"captain follows using actual AU navigation"):await finish();return
	if not check(await live_until(func():return row().phase=="gate_prepare" and row().has_gate_actor_id and host.world.npcs.has(row().gate_actor_id),90.0),"native scene loads the approaching gate queue"):await finish();return
	var actor_id: String=row().gate_actor_id;var last_distance: float=INF;var last_speed: float=INF
	var entry: Dictionary=host.gameplay.definition("anchor_defs","anchor_id",endpoint.entry_anchor_id)
	var deadline: int=Time.get_ticks_msec()+90000
	while row().phase!="gate_transit" and Time.get_ticks_msec()<deadline:
		if row().has_gate_actor_id:actor_id=row().gate_actor_id
		if host.world.npcs.has(actor_id):
			var body: CharacterBody3D=host.world.npcs[actor_id]
			last_distance=body.position.distance_to(host.gameplay.anchor_position(entry));last_speed=body.velocity.length()
		await get_tree().physics_frame
	gate_ready_checked=check(row().phase=="gate_transit" and last_distance<=host.gameplay.rule("gate_entry_radius_m")+1.0 and last_speed<=host.gameplay.rule("gate_max_entry_speed_mps")+1.0,"actual body slows into the real gate radius before crossing")
	if not gate_ready_checked:await finish();return
	await frames(3);gate_hidden_checked=check(not host.world.npcs.has(actor_id),"only the crossing body leaves the native source scene")
	await capture("march-gate-queue")
	host.ui.show_page("pause");await frames(2)
	var saved_phase: String=row().phase;var saved_actor: String=row().gate_actor_id;var saved_remaining: float=row().phase_remaining_s
	await host._command("save","4",1,"manual");await frames(15)
	var saved: Dictionary={}
	for slot: Dictionary in host.store.list_slots():
		if slot.slot_kind=="manual" and int(slot.slot_index)==4:saved=slot;break
	if not check(not saved.is_empty(),"real client saves a paused partial crossing"):await finish();return
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await frames(2)
	gate_restore_checked=check(row().phase==saved_phase and row().gate_actor_id==saved_actor and is_equal_approx(row().phase_remaining_s,saved_remaining) and not host.world.npcs.has(saved_actor),"actual load restores gate identity timer and hidden state")
	await capture("march-restored-pause")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var performance: Dictionary=frame_metrics.report()
	check(performance.native and int(performance.samples)>60,"passive native performance samples cover real active march frames")
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"captures":captures,"native_moved_m":native_moved_m,"departed":departed,"gate_ready_checked":gate_ready_checked,"gate_hidden_checked":gate_hidden_checked,"gate_restore_checked":gate_restore_checked,"grant_ui_checked":grant_ui_checked,"pause_checked":march_pause_checked,"performance":performance,"scope":"qualification/wealth/loadout fixture; actual GUI, Main physics, one visible gate and full save/load; complete itinerary separately covered by macro suite"}
	print("MARCH_WORLD_V49_FINAL_JSON ",JSON.stringify(summary));print("MARCH_WORLD_V49_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
