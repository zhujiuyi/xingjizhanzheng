extends "roles_world_v32.gd"
## Real native registration, source navigation, certification and dispatch.
## Funds, standing, activity variants and authority endpoint poses are fixtures;
## physical four-gate haul, rescue movement and combat have their own suites.
var faction: String="faction_route_council"
var real_actions: int=0
func _ready() -> void:
	get_tree().set_meta("xj_honors_world_v33_diagnostic",true)
	get_tree().create_timer(360.0).timeout.connect(func():check(false,"native commander watchdog");finish())
	run.call_deferred()
func standing_fixture() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state)
	var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):business.grant_unlock(unlock.unlock_id)
	candidate.player().credit=1000000
	var member: RefCounted=business.civilizations.membership();member.has_faction_id=true;member.faction_id=faction
	candidate.find("reputation_state","faction_id",faction).reputation=2600
	var station: Dictionary=business.definition("station_defs","station_id",business.definition("civilization_defs","faction_id",faction).capital_station_id)
	var ship: RefCounted=business.inventory.create_ship("transport_caravan",station.station_id)
	candidate.player().controlled_ship_id=ship.ship_instance_id;place(candidate,business,station.station_anchor_id,station.station_id)
	business.dispose();return await activate(candidate)
func actual_settlement_fixture() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state)
	var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var helper: Node=(load(get_script().resource_path.get_base_dir().path_join("honors_v33.gd")) as Script).new()
	helper.g=business;helper.state=candidate;helper.store=host.store
	helper.fit("module_scanner_beacon_i","utility:0")
	helper.complete_event("exp_mirror_relic");helper.complete_event("exp_echo_rescue");helper.freight(6);helper.demolition()
	helper.at_capital(faction);helper.step(business.combat_remaining_s+0.2)
	var valid: bool=check(helper.failures.is_empty() and business.honors.completed(faction)==4,"native certification fixture earns all four actual settled abilities")
	helper.g=null;helper.state=null;helper.store=null;helper.free();business.dispose()
	return await activate(candidate) if valid else false
func run() -> void:
	directory=OS.get_environment("XJ_HONORS_WORLD_V33_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/honors-world-v33/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped native commander world"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_factor=1.0;root.content_scale_size=root.size
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","文明考核原生",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	host.ui.civilization_selected_faction=faction;await show("civilizations")
	check(host.ui.body.find_child("CommanderRegister",true,false).disabled,"new neutral player cannot register another civilization's examination")
	await reveal(host.ui.body.find_child("CommanderExaminationStatus",true,false));await capture("honors-neutral")
	if not await standing_fixture():await finish();return
	host.ui.civilization_selected_faction=faction;await show("civilizations")
	var button: Button=host.ui.body.find_child("CommanderRegister",true,false)
	await click(button,"native registers at the actual allegiance capital");real_actions+=1
	check(host.gameplay.honors.instance(faction).phase=="assessing","actual registration reaches authoritative commander state")
	check(host.ui.body.find_child("CommanderCertify",true,false).disabled,"incomplete real proofs keep certification disabled")
	await reveal(host.ui.body.find_child("CommanderExaminationStatus",true,false));await capture("honors-registered")
	var choices: OptionButton=host.ui.body.find_child("CommanderSource_scout",true,false)
	check(choices.item_count==2,"scouting offers both authored relic sources")
	await choose(choices,1)
	var locate: Button=host.ui.body.find_child("CommanderLocate_scout",true,false)
	var stale: Callable=locate.get_signal_connection_list("pressed")[0].callable
	var before: String=state_signature()
	await click(locate,"native locates its chosen real examination source");real_actions+=1
	check(host.ui.page=="map" and host.ui.resource_chart.selected_sector=="sector_mirror","source choice opens the selected relic's real star chart")
	check(state_signature()==before,"examination source browsing creates no economic or saved-state mutation")
	await capture("honors-source-map")
	await show("civilizations");before=state_signature();stale.call();await frames(3)
	check(host.ui.page=="civilizations" and state_signature()==before,"old source callbacks cannot navigate after their page context changes")
	if not await actual_settlement_fixture():await finish();return
	await show("civilizations")
	check(host.ui.body.find_child("CommanderExaminationStatus",true,false).text.contains("4 / 4"),"four short rows show all real examination requirements complete")
	await reveal(host.ui.body.find_child("CommanderExaminationStatus",true,false));await capture("honors-four-abilities")
	button=host.ui.body.find_child("CommanderCertify",true,false)
	stale=button.get_signal_connection_list("pressed")[0].callable
	var credit: int=host.state.player().credit;var rep: int=host.gameplay.economy.reputation(faction)
	await click(button,"native certifies completed abilities at the real core station");real_actions+=1
	var spec: Dictionary=host.gameplay.honors.definition(faction)
	check(host.gameplay.honors.instance(faction).phase=="certified" and host.state.player().credit==credit+int(spec.reward_credit) and host.gameplay.economy.reputation(faction)==rep+int(spec.reward_reputation),"native certification pays exact finite rewards")
	check(host.ui.body.find_child("CommanderRegister",true,false).disabled and host.ui.body.find_child("CommanderCertify",true,false).disabled,"both completed examination actions remain disabled")
	check(host.gameplay.honors.instance("faction_deepforge").phase=="unregistered" and host.gameplay.honors.instance("faction_roaming_alliance").phase=="unregistered","one civilization's examination does not certify the other civilizations")
	before=state_signature();stale.call();await frames(3)
	check(state_signature()==before,"old certification callback cannot pay twice")
	var war_id: String=""
	for war: Dictionary in host.gameplay.rows("civilization_war_defs"):
		if war.faction_id==faction:war_id=war.war_id;break
	button=host.ui.body.find_child("CivilizationWar_"+war_id,true,false)
	await click(button,"native qualified commander accepts a real fleet campaign");real_actions+=1
	var campaign: RefCounted=host.gameplay.civilizations.active_war()
	check(campaign!=null and host.gameplay.civilizations.living_fleet(campaign,"ally").size()==3 and host.gameplay.civilizations.living_fleet(campaign,"defender").size()==4,"native dispatch creates the actual seven campaign actors")
	await reveal(host.ui.body.find_child("CivilizationWarStatus",true,false));await capture("honors-qualified-dispatch")
	for layout: Dictionary in [{"size":Vector2i(3440,1188),"scale":1.0,"tag":"ultrawide"},{"size":Vector2i(1280,720),"scale":2.0,"tag":"compact-200"}]:
		root.size=layout.size;root.content_scale_factor=1.0;root.content_scale_size=Vector2i(Vector2(layout.size)/float(layout.scale));await frames(5);await show("civilizations")
		check(host.ui.root.size.is_equal_approx(Vector2(root.content_scale_size)),"native commander layout uses the exact physical-to-logical size "+str(layout.tag))
		for kind: String in ["scout","logistics","rescue","combat"]:
			var control: Control=host.ui.body.find_child("CommanderNavigate_"+kind,true,false)
			await reveal(control);await frames(3)
			check(Rect2(Vector2.ZERO,host.ui.root.size).encloses(control.get_global_rect()),"real examination action remains within the client "+kind+" "+str(layout.tag))
			var label: Label=host.ui.body.find_child("CommanderProgress_"+kind,true,false)
			var requirement: Dictionary={}
			for task: Dictionary in host.gameplay.honors.tasks(faction):
				if task.task_kind==kind:requirement=task;break
			check(label.text.contains("%d / %d" % [requirement.required_units,requirement.required_units]),"compact numerical progress reflects actual requirement "+kind+" "+str(layout.tag))
		await capture("honors-"+str(layout.tag))
	await finish()
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"real_actions":real_actions,"directory":directory}
	print("HONORS_WORLD_V33_FINAL_JSON ",JSON.stringify(summary));print("HONORS_WORLD_V33_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
