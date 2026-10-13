extends "natural_growth_v45.gd"
## Continues a hash-verified, normally earned world. Voluntarily enters a
## public combat site in an unarmed ordinary hull; NPC damage is unmodified.
var origin: Dictionary
var destroyed_id: String=""
var naturally_lost: bool=false
var rescued: bool=false
var paid_replacement: bool=false

func _ready() -> void:
	get_tree().set_meta("xj_natural_recovery_v45_diagnostic",true)
	get_tree().set_meta("xj_natural_growth_v45_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func goto_target(id: String, docking: bool=false) -> bool:
	var start_tick: int=tick()
	var next_report: int=Time.get_ticks_msec()+15000
	while tick()-start_tick<int(host.store.catalog.rule("simulation_hz")*600.0):
		await frames(12);record_distance()
		if Time.get_ticks_msec()>=next_report:
			next_report=Time.get_ticks_msec()+15000
			var evidence: Dictionary={"target":id,"tick":tick(),"busy":host.busy,"page":host.ui.page,"sector":host.state.current_sector(),"status":host.state.ship().status,"position":str(host.gameplay.position(host.state.ship())),"hull":host.state.ship().hull,"shield":host.state.ship().shield}
			if not host.busy and not host.travel.active():
				evidence.navigation=host.navigation_context(id);evidence.combat=host.gameplay.in_combat();evidence.party=host.gameplay.hired.travel_reason()
				if evidence.combat:
					evidence.engaged=[]
					for npc: RefCounted in host.state.rows("npc_state"):
						if npc.alive and host.gameplay.same_entity_site("ship",host.state.ship(),"npc",npc) and npc.behavior_phase in [T.NpcPhase.ACQUIRE,T.NpcPhase.PURSUE,T.NpcPhase.ATTACK,T.NpcPhase.DISENGAGE]:
							evidence.engaged.append({"spawn":npc.spawn_id,"phase":npc.behavior_phase,"distance":host.gameplay.position(npc).distance_to(host.gameplay.position(host.state.ship()))})
			print("NATURAL_NAVIGATION ",JSON.stringify(evidence))
		if host.state.ship().status==T.ShipStatus.DESTROYED:return true
		if docking and host.state.ship().status==T.ShipStatus.DOCKED:return host.gameplay.station()==id
		if host.busy or host.travel.active() or host.local_navigation.active():continue
		if not host.world.targets.has(id):check(false,"public target missing "+id);return false
		if not docking and host.local_navigation.target_id==id and host.local_navigation.mode=="approach" and host.local_navigation.phase=="arrived":return true
		var context: Dictionary=host.navigation_context(id)
		await command("nav_dock" if docking else "nav_warp" if context.warp_ready else "nav_approach",id)
	check(false,"normal navigation timed out "+id);return false

func cross_echo() -> bool:
	if host.state.current_sector()=="sector_echo":return true
	if not check(host.state.current_sector()=="sector_anchor","ordinary route starts at anchor"):return false
	if host.state.ship().status==T.ShipStatus.DOCKED:await command("undock")
	if not await goto_target("endpoint_anchor_echo"):return false
	await command("interact_target","endpoint_anchor_echo")
	while host.travel.active() or host.busy:await frames(2)
	return check(host.state.current_sector()=="sector_echo","ordinary wormhole crossing reaches echo")

func reach_station(id: String) -> bool:
	if host.state.ship().status==T.ShipStatus.DOCKED and host.gameplay.station()==id:return true
	if host.state.ship().status==T.ShipStatus.DOCKED:await command("undock")
	var destination: String=str(host.gameplay.definition("station_defs","station_id",id).sector_id)
	while host.state.current_sector()!=destination:
		var route: Array[Dictionary]=host.gameplay.missions._route(host.state.current_sector(),destination,true)
		if not check(not route.is_empty(),"public unlocked route to recovery or procurement station"):return false
		var gate: String=str(route[0].endpoint_id)
		if not await goto_target(gate):return false
		await command("interact_target",gate)
		while host.travel.active() or host.busy:await frames(2)
	return await goto_target(id,true)

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_RECOVERY_V45_DIRECTORY").replace("\\","/")
	var proof: String=OS.get_environment("XJ_NATURAL_RECOVERY_V45_PROVENANCE").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-recovery-v45/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof.is_absolute_path() and proof.contains("/jiaoben/logs/v45-natural-origin-") and not proof.contains(".."),"fresh recovery destination and scoped natural origin proof"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof))
	var source: String=str(origin.get("database",""))
	if not check(origin.get("result","")=="PASS" and origin.get("completed",[]).size()==8 and source.is_absolute_path() and source.contains("/jiaoben/tmp/natural-growth-v45/") and not source.contains("..") and FileAccess.get_sha256(source)==origin.database_sha256,"original world was earned by successful eight-mission replay"):await finish();return
	if not check(DirAccess.copy_absolute(source,directory.path_join("progress.db"))==OK,"copy earned checkpoint without modifying its original"):await finish();return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal recovery Main opens existing world"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==0:slot=entry;break
	if not check(not slot.is_empty(),"earned manual checkpoint exists"):await finish();return
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle()
	initial_credit=host.state.player().credit;destroyed_id=host.state.ship().ship_instance_id
	if not check(host.state.ship().policy_id=="normal_owned" and host.gameplay.crew.assignment("crew_pilot_1")!=null,"ordinary purchased hull and paid assigned crew survive original load"):await finish();return
	mark("earned-origin-loaded")
	if not await cross_echo():await finish();return
	var sites: Array[Dictionary]=host.gameplay.encounters.waypoints("sector_echo")
	var target: String=""
	for site: Dictionary in sites:
		if int(site.remaining_count)>0:target=str(site.id);break
	if not check(not target.is_empty(),"unlocked public combat site exists"):await finish();return
	if not await goto_target(target):await finish();return
	var start_tick: int=tick()
	while host.state.ship().status!=T.ShipStatus.DESTROYED and tick()-start_tick<int(host.store.catalog.rule("simulation_hz")*360.0):
		await frames(12);record_distance()
		if host.busy or host.local_navigation.active():continue
		for npc: RefCounted in host.state.rows("npc_state"):
			if npc.alive and host._enemy_target_valid(npc.npc_instance_id):await command("nav_approach",npc.npc_instance_id);break
	naturally_lost=check(host.state.ship().ship_instance_id==destroyed_id and host.state.ship().status==T.ShipStatus.DESTROYED,"real enemy fire destroys the normally purchased unarmed hull")
	if not naturally_lost:await finish();return
	check(host.gameplay.crew.member("crew_pilot_1").phase=="injured" and host.gameplay.crew.assignment("crew_pilot_1")==null,"actual hull loss rescues injured crew and releases the old position")
	mark("natural-hull-loss")
	while host.world.projectiles.has_pending() or not host.pending_damage.is_empty():await frames(12)
	var money: int=host.state.player().credit
	await command("request_rescue")
	rescued=check(host.state.ship().status==T.ShipStatus.DOCKED and host.state.ship().ship_instance_id!=destroyed_id and host.state.player().credit==money,"normal rescue returns to station without compensating the original paid asset")
	check(host.state.find("ship_state","ship_instance_id",destroyed_id).status==T.ShipStatus.DESTROYED,"destroyed original asset remains lost after rescue")
	if not rescued:await finish();return
	var member: RefCounted=host.gameplay.crew.member("crew_pilot_1")
	var station: String=member.station_id
	host.ui.fleet_section="crew";host.ui.show_page("ships");await frames(4)
	var panel: Node=host.ui.body.find_child("CrewPanel",true,false)
	var station_name: String=str(host.gameplay.definition("station_defs","station_id",station).display_name)
	check(panel!=null and panel.readouts.any(func(readout: Dictionary):return readout.id=="crew_pilot_1" and readout.label.text.contains(station_name)),"injured crew panel clearly names the actual recovery station")
	host.ui.show_page("")
	if host.gameplay.station()!=station:
		if not await cross_echo() or not await goto_target(station,true):await finish();return
	var treatment: int=int(host.gameplay.crew.balance.injury_treatment_credit);money=host.state.player().credit
	await command("crew_action","crew_pilot_1",1,"treat|"+host.gameplay.crew.token("crew_pilot_1"))
	check(host.gameplay.crew.member("crew_pilot_1").phase=="hired" and host.state.player().credit==money-treatment,"earned remaining funds pay actual local crew treatment")
	# The Echo depot does not sell shuttles. Use the real market's home source,
	# then physically bring the paid hull back to the rescued crew's station.
	if host.gameplay.economy.quote_ship("shuttle_swift")<=0:
		if not await reach_station("station_anchor_port"):await finish();return
	var price: int=host.gameplay.economy.quote_ship("shuttle_swift");money=host.state.player().credit
	await command("buy_ship","shuttle_swift")
	var replacement: RefCounted
	for ship: RefCounted in host.state.rows("ship_state"):
		if ship.policy_id=="normal_owned" and ship.status==T.ShipStatus.DOCKED and ship.ship_instance_id!=destroyed_id:replacement=ship
	paid_replacement=check(replacement!=null and host.state.player().credit==money-price,"earned reserve buys a real replacement at the normal station quote")
	if not paid_replacement:await finish();return
	await command("switch_ship",replacement.ship_instance_id)
	await command("buy_item","module_engine_vector_i")
	var engine: RefCounted
	for item: RefCounted in host.state.rows("item_instance_state"):
		if item.policy_id=="normal_owned" and item.item_def_id=="module_engine_vector_i":engine=item
	if not check(engine!=null,"replacement propulsion is purchased rather than restored for free"):await finish();return
	await command("fit_module",engine.item_instance_id,1,"utility:0")
	await command("set_module_enabled",engine.item_instance_id,1,"on")
	if not await reach_station(station):await finish();return
	await command("crew_action","crew_pilot_1",1,"assign|"+host.gameplay.crew.token("crew_pilot_1")+"|"+replacement.ship_instance_id)
	check(host.gameplay.crew.assignment("crew_pilot_1")!=null and host.gameplay.crew.assignment("crew_pilot_1").ship_instance_id==replacement.ship_instance_id,"recovered paid pilot can serve the replacement hull")
	mark("paid-recovery-ready")
	host.ui.show_page("pause");await command("save","1",1,"manual")
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==1:slot=entry;break
	var before: String=SnapshotSignature.saved(host.store,slot.current_snapshot_id)
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==before,"natural failure and paid recovery reopen all authoritative groups and RNG before presentation updates")
	check(FileAccess.get_sha256(source)==origin.database_sha256,"original normally earned checkpoint remains byte-identical")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(6)
	var result: String="PASS" if failures.is_empty() else "FAIL"
	print("NATURAL_RECOVERY_V45_FINAL_JSON ",JSON.stringify({"result":result,"checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"origin":origin,"milestones":milestones,"actions":actions,"initial_credit":initial_credit,"final_credit":credit,"naturally_lost":naturally_lost,"rescued":rescued,"paid_replacement":paid_replacement,"physical_distance_m":moved_m}))
	print("NATURAL_RECOVERY_V45_RESULT ",result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
