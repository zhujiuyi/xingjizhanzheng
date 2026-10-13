extends "natural_logistics_v54.gd"
## Paid transport refit and hired logistics support, actual demolition fire,
## extraction, certification and war preparation. No qualification fixtures.
var combat_earned: bool=false
var certified: bool=false
var war_ready: bool=false
var command_resume: bool=false

func _ready() -> void:
	for diagnostic: String in ["natural_command_v55","natural_logistics_v54","natural_rescue_v53","natural_scout_v51","natural_recovery_v45","natural_growth_v45"]:
		get_tree().set_meta("xj_"+diagnostic+"_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func local_module(id: String) -> RefCounted:
	for equipment: RefCounted in host.gameplay.equipped(host.state.ship()):
		if equipment.module_def_id==id:return host.state.find("item_instance_state","item_instance_id",equipment.item_instance_id)
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	for item: RefCounted in host.state.rows("item_instance_state"):
		if item.item_def_id==id and item.policy_id=="normal_owned" and item.container_id==warehouse:return item
	return null

func operation(action: String) -> bool:
	var row: RefCounted=host.gameplay.operations.instance("op_demolition")
	await command("operation_action",row.operation_id,1,action+":"+str(row.generation))
	return check(host.gameplay.last_error.is_empty(),"ordinary demolition action "+action+" "+host.gameplay.last_error)

func clear_for_warp(target: String, thrust_action: String="forward") -> bool:
	if bool(host.navigation_context(target).get("warp_ready",false)):return true
	await command("nav_stop");host.ui.show_page("")
	if not check(host._keyboard_control_allowed(),"normal flight input remains available during extraction"):return false
	var started: int=tick();var origin_position: Vector3=host.gameplay.position(host.state.ship())
	Input.action_press(thrust_action);Input.action_press("boost")
	while tick()-started<int(host.gameplay.rule("simulation_hz")*240):
		await frames(12);record_distance()
		if host.state.ship().status==T.ShipStatus.DESTROYED:break
		if bool(host.navigation_context(target).get("warp_ready",false)):break
	Input.action_release(thrust_action);Input.action_release("boost");await frames(2)
	var escaped: bool=bool(host.navigation_context(target).get("warp_ready",false))
	mark("normal-powered-disengagement")
	print("NATURAL_DISENGAGEMENT ",JSON.stringify({"distance_m":origin_position.distance_to(host.gameplay.position(host.state.ship())),"navigation":host.navigation_context(target)}))
	return check(escaped,"ordinary thrust and engine cycles leave pursuit range before warp")

func drive_demolition() -> bool:
	if host.gameplay.operations.instance("op_demolition").phase!="accepted":
		if not await operation("accept"):return false
	if host.state.ship().status==T.ShipStatus.DOCKED:await command("undock")
	host.ui.show_page("")
	var started: int=tick();var last: String=""
	while failures.is_empty() and tick()-started<int(host.gameplay.rule("simulation_hz")*900):
		await frames(12);record_distance()
		if not check_alive():return false
		var row: RefCounted=host.gameplay.operations.instance("op_demolition")
		var key: String=row.phase+":"+str(row.completed_units)
		if key!=last:last=key;mark("normal-demolition:"+key)
		if row.phase in ["failed","withdrawn"]:check(false,"normal demolition failed "+row.phase);return false
		if row.phase=="ready":
			if not check(row.completed_units==2,"real weapons destroy both required installations"):return false
			# Extraction does not automatically recall a fighting companion.
			# Give the same explicit retreat order available to the player.
			if host.gameplay.hired.active()!=null and host.gameplay.hired.active().phase=="deployed":
				var reason: String=host.gameplay.hired.order_reason("retreat")
				if not check(reason.is_empty(),"support can receive ordinary retreat "+reason):return false
				await command("hire_action","retreat",1,host.gameplay.hired.token())
				if not check(host.gameplay.hired.active()==null or host.gameplay.hired.active().phase!="deployed","support starts actual withdrawal before player warp"):return false
			if not await clear_for_warp(host.gameplay.operations.definition(row.operation_id).station_id):return false
			check(host.gameplay.tactics.remaining("tac_sector_echo_group")>0,"physical extraction remains possible without killing every hostile")
			if not await reach_station(host.gameplay.operations.definition(row.operation_id).station_id):return false
			return await operation("claim")
		if host.busy or host.travel.active() or host.local_navigation.warp_active():continue
		if row.phase=="accepted" and host.gameplay.operations.action_reason(row.operation_id,"start").is_empty():
			if not await operation("start"):return false
			continue
		if row.phase=="active" and row.completed_units<2:
			for npc: RefCounted in host.state.rows("npc_state"):
				if npc.alive and host.gameplay.operations.handles(npc.spawn_id) and host._combat_target_valid(npc.npc_instance_id):
					if host.auto_fire_target!=npc.npc_instance_id:await command("combat_engage",npc.npc_instance_id)
					break
			continue
		if row.phase=="active" and host.gameplay.operations.action_reason(row.operation_id,"exit").is_empty():
			if not await operation("exit"):return false
		elif not host.local_navigation.active():await command("operation_nav",row.operation_id,1,str(row.generation))
	check(false,"normal demolition exceeded bounded play window");return false

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_COMMAND_V55_DIRECTORY").replace("\\","/")
	command_resume=not OS.get_environment("XJ_NATURAL_COMMAND_PARTIAL_ORIGIN").is_empty()
	var proof_path: String=OS.get_environment("XJ_NATURAL_COMMAND_PARTIAL_ORIGIN" if command_resume else "XJ_NATURAL_LOGISTICS_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-command-v55/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof_path.is_absolute_path() and proof_path.contains("/jiaoben/logs/v55-command-partial-" if command_resume else "/jiaoben/logs/v54-logistics-origin-") and not proof_path.contains(".."),"fresh normally earned commander scope"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof_path));source_path=str(origin.database)
	if not check(origin.result==("EARNED_CHECKPOINT" if command_resume else "PASS") and source_path.contains("/jiaoben/tmp/natural-command-v55/" if command_resume else "/jiaoben/tmp/natural-logistics-v54/") and not source_path.contains("..") and FileAccess.get_sha256(source_path)==origin.database_sha256 and FileAccess.get_sha256(origin.source_report)==origin.source_report_sha256,"earned source matches bound report and declared completion status"):await finish();return
	if not check(DirAccess.copy_absolute(source_path,directory.path_join("progress.db"))==OK,"copy earned industrial career"):await finish();return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens commander continuation"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if ((entry.slot_id==origin.slot_id and entry.current_snapshot_id==origin.snapshot_id) if command_resume else (entry.slot_kind=="manual" and int(entry.slot_index)==int(origin.manual_slot))):slot=entry;break
	if not check(not slot.is_empty(),"earned logistics checkpoint exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle();initial_credit=host.state.player().credit
	if not check(initial_credit==int(origin.credit) and host.gameplay.honors.progress("honor_faction_deepforge_logistics")==6,"earned freight and money retained"):await finish();return
	check(Engine.physics_ticks_per_second==60 and int(host.gameplay.rule("simulation_hz"))==60,"commander replay retains production60Hz physics")
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	if command_resume:
		check(FileAccess.get_sha256(origin.source_log)==origin.source_log_sha256,"original stopped-run log is unchanged")
		check(host.gameplay.operations.instance("op_demolition").phase=="accepted" and host.gameplay.operations.instance("op_demolition").completed_units==0,"earlier earned checkpoint does not invent unsaved demolition progress")
		check(host.gameplay.hired.active()!=null and host.gameplay.hired.active().profile_id=="hire_support","paid support lease survives the real auto-save")
		for module: String in ["module_scanner_beacon_i","module_shield_lattice_i","module_thermal_sunline_i"]:
			check(local_module(module)!=null,"original locally paid refit retained "+module)
		if not failures.is_empty():await finish();return
	else:
		for pair: Array in [["module_scanner_beacon_i","utility:1"],["module_shield_lattice_i","utility:2"],["module_thermal_sunline_i","weapon:0"]]:
			var item: RefCounted=local_module(pair[0])
			if item==null:await command("buy_item",pair[0]);item=local_module(pair[0])
			if not check(item!=null,"ordinary market buys locally accessible equipment "+str(pair[0])):await finish();return
			await command("fit_module",item.item_instance_id,1,pair[1]);await command("set_module_enabled",item.item_instance_id,1,"on")
			if not check(host.state.find("equipment_state","item_instance_id",item.item_instance_id)!=null,"normal legal transport refit "+str(pair[0])):await finish();return
		if not await reach_station("station_echo_depot"):await finish();return
		await command("hire_action","hire_support",1,host.gameplay.hired.token())
		if not check(host.gameplay.hired.active()!=null and host.gameplay.hired.active().profile_id=="hire_support","actual income pays support lease and deposit"):await finish();return
	if not await drive_demolition():await finish();return
	var task: String="honor_faction_deepforge_combat"
	combat_earned=check(host.gameplay.honors.progress(task)==2,"actual complete demolition earns combat examination")
	var started: int=tick()
	while host.gameplay.hired.active()!=null and not host.gameplay.hired.order_reason("dismiss").is_empty() and tick()-started<int(host.gameplay.rule("simulation_hz")*120):await frames(12)
	if host.gameplay.hired.active()!=null:await command("hire_action","dismiss",1,host.gameplay.hired.token())
	if not check(host.gameplay.hired.active()==null,"paid support returns through real dismissal or lease settlement"):await finish();return
	if not await reach_station("station_forge_01"):await finish();return
	await command("growth_claim",task,1,host.gameplay.growth.grant_token(task))
	grant_earned=check(host.state.find("growth_grant_receipt_state","task_id",task)!=null,"earned combat proof receives once-only funds")
	await command("honor_action","faction_deepforge",1,"certify:assessing")
	certified=check(host.gameplay.honors.instance("faction_deepforge").phase=="certified","all four normally earned proofs certify commander")
	if not certified:await finish();return
	var required: int=int(host.gameplay.civilizations.rank_requirement("faction_deepforge",5).required_reputation)
	var missing_rep: int=maxi(0,required-host.gameplay.growth.reputation("faction_deepforge"))
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	if missing_rep>0:
		var donation: Dictionary=host.gameplay.definition("civilization_donation_defs","donation_id","donate_forge_material_structural_stock")
		var batches: int=ceili(float(missing_rep)/float(donation.reputation_per_batch))
		var units: int=maxi(0,batches*int(donation.units_per_batch)-host.gameplay.inventory.count(warehouse,donation.item_id,true))
		if units>0:await command("buy_item",donation.item_id,units)
		await command("donate_civilization",donation.donation_id,batches)
	var supplies: int=maxi(0,int(host.gameplay.frontier.balance.supply_units)-host.gameplay.inventory.count(warehouse,host.gameplay.frontier.balance.material_id,true))
	if supplies>0:await command("buy_item",host.gameplay.frontier.balance.material_id,supplies)
	war_ready=check(host.gameplay.civilizations.war_reason("war_forge_01").is_empty(),"normal rank qualification and paid supplies permit first war")
	mark("normal-command-certified-and-war-ready")
	host.ui.show_page("pause");await settle();await command("save","2",1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==2:saved=entry;break
	if not check(not saved.is_empty(),"commander checkpoint saves"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG reload at commander checkpoint")
	check(FileAccess.get_sha256(source_path)==origin.database_sha256,"industrial source stays unchanged")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	Input.action_release("forward");Input.action_release("back");Input.action_release("boost")
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"combat_earned":combat_earned,"certified":certified,"war_ready":war_ready,"resumed":command_resume,"origin":origin,"initial_credit":initial_credit,"final_credit":credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"scope":"normal refit, hired support, actual demolition and commander certification; no progression fixtures"}
	print("NATURAL_COMMAND_V55_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_COMMAND_V55_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
