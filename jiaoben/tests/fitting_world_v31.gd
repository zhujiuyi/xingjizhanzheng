extends "tactics_world_v29.gd"
## Real UI research, readonly projected replacement and physical tuned beam range.
var range_item: String=""
var burst_item: String=""
func _ready() -> void:
	get_tree().set_meta("xj_fitting_world_v31_diagnostic",true)
	get_tree().create_timer(540.0).timeout.connect(func():check(false,"native fitting watchdog");finish())
	run.call_deferred()
func enter_number(spin: SpinBox,value: String) -> void:
	var line: LineEdit=spin.get_line_edit();await click(line,"focus numeric analysis/research input");line.select_all()
	for character: String in value:
		var event: InputEventKey=InputEventKey.new();event.unicode=character.unicode_at(0);event.pressed=true;root.push_input(event,true)
	await key(KEY_ENTER);await frames(3)
func pick(option: OptionButton,value: String) -> void:
	var index: int=-1
	for i: int in range(option.item_count):
		if str(option.get_item_metadata(i))==value:index=i;break
	if check(index>=0,"actual dropdown contains requested item/slot"):await choose(option,index)
func fixture() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	for unlock: Dictionary in business.rows("unlock_defs"):
		if not str(unlock.unlock_id).begins_with("unlock_spec_"):business.grant_unlock(unlock.unlock_id)
	business._sync_spawns()
	var home: Dictionary=business.definition("station_defs","station_id","station_anchor_port")
	var hull: RefCounted=business.inventory.create_ship("cruiser_horizon",home.station_id)
	candidate.player().controlled_ship_id=hull.ship_instance_id;candidate.player().credit=1000000;place(candidate,business,home.station_anchor_id,home.station_id)
	var warehouse: String=business.inventory.warehouse(home.station_id)
	business.inventory.grant(warehouse,"material_structural_stock",1000)
	var ray: String=business.inventory.grant(warehouse,"module_thermal_sunline_iii",1)[0]
	check(business.act("fit_module",ray,1,"weapon:1").phase==T.ActionPhase.APPLIED,"native qualified hull fits actual legal beam")
	range_item=business.inventory.grant(warehouse,"module_spec_range",1)[0];burst_item=business.inventory.grant(warehouse,"module_spec_burst",1)[0]
	for row: RefCounted in candidate.rows("npc_tactic_state"):
		if business.tactics.definition(row.npc_instance_id).tactic_kind=="siege":role_actor=row.npc_instance_id;break
	business.dispose();return await activate(candidate)
func combat_pose() -> bool:
	var candidate: XJRuntimeState=host.store.clone_state(host.state);var business: Gameplay=Gameplay.new();business.setup(candidate,host.store.catalog)
	var npc: RefCounted=candidate.find("npc_state","npc_instance_id",role_actor)
	for row: RefCounted in candidate.rows("npc_tactic_state"):
		var other: RefCounted=candidate.find("npc_state","npc_instance_id",row.npc_instance_id)
		if row.npc_instance_id==role_actor:continue
		other.alive=false;other.hull=0;other.shield=0;other.armor=0;other.behavior_phase=T.NpcPhase.DEAD;row.has_target_entity_id=false;row.target_entity_id="";row.remaining_s=0;row.cooldown_remaining_s=0;row.phase="ready"
	for site: RefCounted in candidate.rows("tactical_site_state"):site.respawn_remaining_s=business.definition("tactical_site_defs","site_id",site.site_id).respawn_s
	place(candidate,business,business.definition("npc_spawn_defs","spawn_id",npc.spawn_id).anchor_id)
	candidate.ship().pos_z-=2300.0
	var rotation: Quaternion=Basis.looking_at(business.position(candidate.ship()).direction_to(business.position(npc)),Vector3.UP).get_rotation_quaternion()
	candidate.ship().quat_x=rotation.x;candidate.ship().quat_y=rotation.y;candidate.ship().quat_z=rotation.z;candidate.ship().quat_w=rotation.w
	business.dispose();return await activate(candidate)
func run() -> void:
	directory=OS.get_environment("XJ_FITTING_WORLD_V31_DIRECTORY").replace("\\","/")
	if not check(DisplayServer.get_name()!="headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/fitting-world-v31/") and not FileAccess.file_exists(directory.path_join("progress.db")),"native fitting uses fresh scoped world and real renderer"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900)
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(5)
	await host._command("new_world","配装与专精原生",1,"");await settle();host.set_process(false);host.set_physics_process(false)
	if not await fixture():await finish();return
	await show("fitting");await click(host.ui.body.find_child("FittingAnalysisEntry",true,false),"actual fitting opens analysis")
	check(host.ui.page=="fitting_analysis" and host.ui.body.find_child("FittingResults",true,false)!=null,"actual analysis report exists")
	check(host.ui.body.find_child("FittingKeyValues",true,false)!=null and not host.ui.body.find_child("FittingDetailedValues",true,false).visible,"analysis leads with a compact numerical table and collapsed details")
	await capture("fitting-current-budget")
	var readonly: String=state_signature()
	await click(host.ui.body.find_child("FittingDetailsToggle",true,false),"native disclosure opens numerical details")
	var detail: Control=host.ui.body.find_child("FittingDetailedValues",true,false)
	var concise: bool=detail.visible
	for value: Label in detail.find_children("*","Label",true,false):concise=concise and value.text.length()<100 and not value.text.contains("\n")
	check(concise,"expanded details use short numerical rows instead of paragraphs")
	await click(host.ui.body.find_child("FittingDetailsToggle",true,false),"native disclosure restores concise summary")
	check(not detail.visible and state_signature()==readonly,"viewing details preserves the entire world")
	var before: String=state_signature()
	await pick(host.ui.body.find_child("FittingCandidate",true,false),range_item)
	await pick(host.ui.body.find_child("FittingSlot",true,false),"utility:0")
	await click(host.ui.body.find_child("FittingCalculate",true,false),"calculate locked projected specialization")
	check(state_signature()==before and host.ui.body.find_child("FittingApply",true,false).disabled,"locked preview remains readonly and cannot install")
	await show("research")
	await enter_number(host.ui.body.find_child("SpecializationQuantity",true,false),"10")
	var credit: int=host.state.player().credit
	await click(host.ui.body.find_child("SpecializationDonate",true,false),"real material analysis donation")
	check(host.gameplay.specializations.available()==10 and host.state.player().credit==credit-2000,"native donation creates paid finite analysis")
	await enter_number(host.ui.body.find_child("SpecializationQuantity",true,false),"3")
	await click(host.ui.body.find_child("SpecializationInvest_spec_range",true,false),"native partial range research")
	check(host.state.find("specialization_research_state","research_id","spec_range").invested_points==3 and not host.gameplay.unlocked("unlock_spec_range"),"native partial research preserves unfinished project")
	await capture("fitting-partial-research")
	await enter_number(host.ui.body.find_child("SpecializationQuantity",true,false),"7")
	await click(host.ui.body.find_child("SpecializationInvest_spec_range",true,false),"native complete accumulated range design")
	check(host.gameplay.unlocked("unlock_spec_range") and host.gameplay.specializations.available()==0,"native research completion unlocks real equipment permission")
	await show("fitting_analysis")
	await pick(host.ui.body.find_child("FittingCandidate",true,false),range_item)
	await pick(host.ui.body.find_child("FittingSlot",true,false),"utility:0")
	before=state_signature()
	await click(host.ui.body.find_child("FittingCalculate",true,false),"compare unlocked real replacement")
	check(state_signature()==before and not host.ui.body.find_child("FittingApply",true,false).disabled,"legal projected fit shows actionable comparison without economic mutation")
	await capture("fitting-range-comparison")
	await click(host.ui.body.find_child("FittingApply",true,false),"apply validated specialization from comparison")
	check(host.state.find("equipment_state","item_instance_id",range_item)!=null,"native atomic action installs selected control")
	await show("ships");await click(host.ui.body.find_child("ShipRolesEntry",true,false),"open eighteen hull role matrix")
	var rows: int=0
	for node: Node in host.ui.body.find_children("*","",true,false):
		if node.has_meta("asset_kind") and node.get_meta("asset_kind")=="ship":rows+=1
	check(rows==18,"actual role matrix renders all eighteen hulls with native rows")
	await capture("fitting-eighteen-roles")
	if not await combat_pose():await finish();return
	var health: float=hp(role_actor);await fire_at(role_actor)
	check(hp(role_actor)<health,"physical tuned beam reaches beyond original module range")
	observations.append({"kind":"range","distance_m":host.world.flight.position.distance_to(host.world.npcs[role_actor].position),"base_range_m":host.store.catalog.one("module_defs","module_id","module_thermal_sunline_iii").range_m,"actual_range_m":host.gameplay.specializations.weapon_spec(host.state.find("equipment_state","module_def_id","module_thermal_sunline_iii"),host.state.ship()).range_m,"damage":health-hp(role_actor)})
	await capture("fitting-tuned-physical-range")
	await flight_layout_checks()
	root.size=Vector2i(1280,720);root.content_scale_factor=2.0;await show("fitting_analysis")
	var calculate: Button=host.ui.body.find_child("FittingCalculate",true,false)
	await click(calculate,"compact high-scale analysis control")
	check(Rect2(Vector2.ZERO,host.ui.root.size).encloses(calculate.get_global_rect()),"high-scale calculation button remains reachable")
	await capture("fitting-1280-200")
	await finish()
func flight_layout_checks() -> void:
	for layout: Dictionary in [{"size":Vector2i(1440,900),"scale":1.0},{"size":Vector2i(3440,1188),"scale":1.0},{"size":Vector2i(1280,720),"scale":2.0}]:
		root.size=layout.size;root.content_scale_factor=layout.scale;host.ui.show_page("");await frames(6);host.ui.tick(1.0);await frames(4)
		var ui: XJUI=host.ui;var bounds: Rect2=Rect2(Vector2.ZERO,ui.root.size)
		var center: Rect2=Rect2(ui.root.size*0.5-Vector2(40,30),Vector2(80,60))
		var label: String="%dx%d-%d" % [layout.size.x,layout.size.y,int(layout.scale*100)]
		var panels: Array[Control]=[ui.flight_header,ui.navigation,ui.navigation_frame,ui.hud_left.get_parent(),ui.target_panel,ui.flight_dock]
		for panel: Control in panels:
			check(panel.is_visible_in_tree() and bounds.encloses(panel.get_global_rect()) and not panel.get_global_rect().intersects(center),"clean HUD panel is bounded and preserves the ship "+panel.name+" "+label)
		check(not ui.navigation_frame.get_global_rect().intersects(ui.hud_left.get_parent().get_global_rect()) and not ui.target_panel.get_global_rect().intersects(ui.flight_dock.get_global_rect()),"navigation/task and overview/dock remain separate "+label)
		check(ui.dial.is_visible_in_tree() and not ui.navigation_hud.radar_frame.is_visible_in_tree(),"circular speed instrument stays visible and radar defaults collapsed "+label)
		if layout.scale==1.0:check(ui.flight_dock.size.x<=940.5 and ui.target_panel.size.y<=430.5,"wide screen dock and overview have bounded footprints "+label)
		await capture("clean-flight-"+label)
		var before: String=state_signature()
		await click(ui.radar_button,"native rail expands radar "+label)
		check(ui.navigation_hud.radar_frame.is_visible_in_tree() and not ui.hud_left.get_parent().is_visible_in_tree() and bounds.encloses(ui.navigation_hud.radar_frame.get_global_rect()) and not ui.navigation_hud.radar_frame.get_global_rect().intersects(ui.flight_dock.get_global_rect()),"radar drawer fits and temporarily replaces the task card "+label)
		await capture("clean-radar-"+label)
		await click(ui.radar_button,"native rail restores task card "+label)
		check(not ui.navigation_hud.radar_frame.is_visible_in_tree() and ui.hud_left.get_parent().is_visible_in_tree() and state_signature()==before,"presentation toggles preserve the complete world "+label)
func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"captures":captures,"directory":directory,"observations":observations}
	print("FITTING_WORLD_V31_FINAL_JSON ",JSON.stringify(summary));print("FITTING_WORLD_V31_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
