extends "fitting_v31.gd"
## Explicit qualification/wealth/gear/pose fixtures; actual actions, ticks and SQL.
var budgets: Array[Dictionary]=[]
var ships: Dictionary={}
var ally_id: String=""
var patch_id: String=""
var legacy_checked: bool=false
func _ready() -> void:
	get_tree().set_meta("xj_roles_v32_diagnostic",true)
	get_tree().create_timer(480.0).timeout.connect(func():print("ROLES_V32_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func step(seconds: float) -> void:
	var dt: float=1.0/g.rule("simulation_hz")
	for _i: int in range(int(ceil(seconds/dt))):g.tick(dt)
func saved_slot(index: int) -> String:
	for row: Dictionary in store.list_slots():
		if row.world_id==state.world_id and row.slot_kind=="manual" and int(row.slot_index)==index:return row.slot_id
	return ""
func hull(id: String) -> RefCounted:
	var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port")
	g.ship_roles.stop_support()
	place(home.station_anchor_id,home.station_id) # Park the preceding declared fixture.
	var ship: RefCounted=g.inventory.create_ship(id,home.station_id)
	state.player().controlled_ship_id=ship.ship_instance_id;place(home.station_anchor_id,home.station_id)
	ships[id]=ship
	return ship
func fit(module_id: String,slot_ref: String) -> String:
	var id: String=g.inventory.grant(g.inventory.warehouse(g.station()),module_id,1)[0]
	check(apply("fit_module",id,1,slot_ref),"real legal role fitting "+module_id)
	return id
func cold() -> void:
	var m: Dictionary=g.metrics(state.ship())
	for layer: String in ["shield","armor","hull","energy"]:state.ship().set(layer,m[layer+"_max"])
	state.ship().heat=0.0;state.ship().overheated=false
func base_cost(ship: RefCounted) -> int:
	var cost: int=int(g.definition("ship_defs","ship_id",ship.ship_def_id).base_ask_credit)
	for e: RefCounted in g.equipped(ship):cost+=int(g.definition("item_defs","item_id",e.module_def_id).base_ask_credit)
	for container: RefCounted in state.rows("container_state"):
		if not container.has_ship_instance_id or container.ship_instance_id!=ship.ship_instance_id or container.kind==T.ContainerKind.SLOT:continue
		for stack: RefCounted in state.rows("inventory_stack_state"):
			if stack.container_id==container.container_id:cost+=stack.quantity*int(g.definition("item_defs","item_id",stack.item_def_id).base_ask_credit)
	return cost
func rescue_fixture() -> RefCounted:
	for spec: Dictionary in g.rows("exploration_variant_defs"):
		var event: Dictionary=g.exploration.definition(spec.event_id)
		if event.event_kind!="rescue" or event.environment_kind=="solar":continue
		var row: RefCounted=g.exploration.instance(event.event_id)
		reset_case(row,spec);check(act("survey",row),"real survey reveals the friendly rescue actor")
		step(float(spec.survey_duration_s)/float(g.exploration.balance.em_scan_multiplier)+0.2)
		for actor: RefCounted in state.rows("exploration_actor_state"):
			if actor.event_id==event.event_id and actor.actor_role=="escort":ally_id=actor.npc_instance_id;return row
	return null
func _run() -> void:
	directory=OS.get_environment("XJ_ROLES_V32_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/roles-v32/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh isolated role world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format17 opens "+store.last_error):get_tree().quit(1);return
	state=store.new_world("真实舰种能力与承运",3201)
	if not check(state!=null,"all role coverage seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==83 and state.rows("consignment_state").size()==2 and state.rows("remote_support_state").is_empty(),"retained role groups and new empty authority initialize without free freight or repair")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	g.missions.refresh();g._sync_spawns();state.player().credit=1000000
	_scouting()
	var support: RefCounted=hull("support_weaver")
	fit("module_shield_lattice_i","utility:0");patch_id=fit("module_support_patch_i","work:0")
	var cargo: String=g.inventory.hold(support,T.ContainerKind.CARGO)
	g.inventory.grant(cargo,"repair_kit_i",20)
	check(base_cost(support)<=225000,"support equipment and consumables fit the common 225000 reference budget")
	budgets.append({"role":"support","hull":support.ship_def_id,"cost":base_cost(support),"cap":225000})
	if not check(rescue_fixture()!=null and not ally_id.is_empty(),"actual friendly escort exists"):await finish();return
	_support_matrix()
	state.player().controlled_ship_id=support.ship_instance_id
	var target: RefCounted=state.find("npc_state","npc_instance_id",ally_id)
	place(g.definition("npc_spawn_defs","spawn_id",target.spawn_id).anchor_id);cold()
	if not _support_cycles(support,target):await finish();return
	if g==null or state==null:await finish();return
	_freight()
	var before: String=full_signature(state)
	var saved: bool=store.save(state,"manual",3)
	check(saved,"all role, escrow and receipt groups save "+store.last_error)
	var slot_id: String=saved_slot(3)
	g.dispose();g=null;state=store.load(slot_id)
	check(state!=null,"all role groups reopen "+store.last_error)
	if state!=null:check(full_signature(state)==before,"full fifty-nine-group restore preserves finances cargo and abilities")
	if not OS.get_environment("XJ_ROLES_LEGACY_DATABASE").is_empty():legacy_roles()
	await finish()
func _scouting() -> void:
	var times: Dictionary={}
	for id: String in ["frigate_lantern","frigate_kestrel"]:
		var ship: RefCounted=hull(id);var scanner: String=fit("module_scanner_beacon_i","utility:0")
		var variant: Dictionary={}
		for v: Dictionary in g.rows("exploration_variant_defs"):
			var event: Dictionary=g.exploration.definition(v.event_id)
			if event.event_kind=="rescue" and event.environment_kind!="solar":variant=v;break
		var row: RefCounted=g.exploration.instance(variant.event_id);reset_case(row,variant)
		var rate: float=g.ship_roles.survey_rate();var energy: float=ship.energy
		check(act("survey",row),"qualified ship pays real role-based survey "+id)
		check(is_equal_approx(row.operation_remaining_s,float(variant.survey_duration_s)/rate) and ship.energy<energy,"hull and scanner strength affect paid duration and resource cost "+id)
		times[id]=row.operation_remaining_s
		check(base_cost(ship)<=40000,"survey loadout and mandatory materials fit common 40000 reference budget "+id)
		budgets.append({"role":"survey","hull":id,"cost":base_cost(ship),"cap":40000,"seconds":row.operation_remaining_s})
		step(float(variant.survey_duration_s)/float(g.exploration.balance.em_scan_multiplier)+0.2)
		check(row.phase=="surveyed","actual survey completes "+id)
		var original: float=g.ship_roles.detection_range()
		check(is_equal_approx(original,g.rule("target_marker_detection_range_m")*(1.5 if id=="frigate_lantern" else 1.0)),"real sensor policy consumes hull role "+id)
		check(apply("set_module_enabled",scanner,1,"off") and is_equal_approx(g.ship_roles.detection_range(),g.rule("target_marker_detection_range_m")),"disabled scanner cannot grant remote contacts "+id)
	check(float(times.frigate_lantern)<float(times.frigate_kestrel),"scout completes the identical survey faster at the same budget cap")
func _support_matrix() -> void:
	var target: RefCounted=state.find("npc_state","npc_instance_id",ally_id)
	var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",target.spawn_id)
	for spec: Dictionary in g.rows("ship_role_capability_defs"):
		var ship: RefCounted=hull(spec.ship_id);var item: String=fit("module_shield_lattice_i","utility:0")
		place(spawn.anchor_id);state.ship().pos_z+=150.0;cold();target.shield=0.0
		var before: float=ship.energy
		var accepted: bool=apply("remote_support",item,1,ally_id)
		check(accepted==bool(spec.remote_repair_allowed),"actual remote repair obeys hull permission "+spec.ship_id)
		if accepted:check(ship.energy<before and g.ship_roles.channel(item)!=null,"allowed hull pays and binds a real cycle "+spec.ship_id);g.ship_roles.stop_support(item)
		else:check(ship.energy==before and g.ship_roles.channel(item)==null,"rejected hull spends no repair energy "+spec.ship_id)
func _support_cycles(support: RefCounted,target: RefCounted) -> bool:
	var cap: Dictionary=g.ship_roles.target_limits(target);target.armor=maxf(0.0,float(cap.armor_max)-120.0)
	var cargo: String=g.inventory.hold(support,T.ContainerKind.CARGO)
	var kits: int=g.inventory.count(cargo,"repair_kit_i",true);var health: float=target.armor
	check(apply("remote_support",patch_id,1,ally_id),"actual support action starts armor work")
	check(g.inventory.count(cargo,"repair_kit_i",true)==kits-1 and target.armor==health,"one ordinary kit is paid before healing, not on click display")
	step(2.0)
	check(target.armor==health and g.ship_roles.channel(patch_id).remaining_s>0.0,"unfinished paid cycle has no early heal")
	var before: String=full_signature(state);var saved: bool=store.save(state,"manual",1)
	if not check(saved,"partial paid support cycle seals "+store.last_error):return false
	var slot_id: String=saved_slot(1)
	g.dispose();g=null;state=store.load(slot_id)
	if not check(state!=null,"partial support loads "+store.last_error):return false
	g=Gameplay.new();g.setup(state,store.catalog);support=state.ship();target=state.find("npc_state","npc_instance_id",ally_id)
	check(full_signature(state)==before,"reopening preserves paid cycle, target generation and all assets")
	# Stop on the completion tick: a continuous channel may legitimately pay
	# for the next cycle on the following tick.
	var remaining_ticks: int=int(ceil(float(g.definition("module_defs","module_id","module_support_patch_i").cycle_s)*g.rule("simulation_hz")))+2
	while target.armor==health and remaining_ticks>0:
		step(1.0/g.rule("simulation_hz"));remaining_ticks-=1
	check(target.armor>health and target.armor<=float(cap.armor_max) and g.inventory.count(cargo,"repair_kit_i",true)==kits-1,"restored cycle heals once without charging another kit")
	g.ship_roles.stop_support()
	var after: float=target.armor;step(5.1)
	check(target.armor==after,"stopped remote channel has no deferred duplicate heal")
	var enemy: RefCounted=null
	for npc: RefCounted in state.rows("npc_state"):
		if npc.alive and not g.civilizations.friendly(npc.npc_instance_id):enemy=npc;break
	check(enemy!=null and not apply("remote_support",patch_id,1,enemy.npc_instance_id),"remote repair cannot target an enemy")
	target.armor=maxf(0.0,float(cap.armor_max)-100.0);cold();step(5.1)
	check(apply("remote_support",patch_id,1,ally_id),"new paid armor cycle starts after a stop")
	var paid: int=g.inventory.count(cargo,"repair_kit_i",true);after=target.armor
	state.ship().pos_x+=2000.0;step(0.1)
	check(target.armor==after and g.ship_roles.channel(patch_id).phase=="armed","out-of-range cycle cancels without remote healing")
	check(g.inventory.count(cargo,"repair_kit_i",true)==paid,"interrupted paid work does not refund consumables")
	g.ship_roles.stop_support();state.ship().pos_x-=2000.0
	return true
func _freight() -> void:
	var id: String="freight_anchor_echo";var d: Dictionary=g.consignments.definition(id)
	for hull_id: String in ["transport_caravan","miner_anvil"]:
		var ship: RefCounted=hull(hull_id)
		var amount: int=g.consignments.available(id)
		var cost: int=base_cost(ship)+amount*int(d.deposit_per_unit)+int(d.fee_credit)+g.consignments.travel_reserve(id,amount)
		check(cost<=110000,"hull and freight working capital fit common 110000 budget "+hull_id)
		budgets.append({"role":"freight","hull":hull_id,"cost":cost,"cap":110000,"units":amount})
	check(g.consignments.available(id)==1,"mineral hold cannot carry ordinary entrusted freight")
	state.player().controlled_ship_id=ships.transport_caravan.ship_instance_id
	var home: Dictionary=g.definition("station_defs","station_id",d.origin_station_id);place(home.station_anchor_id,home.station_id)
	check(g.consignments.available(id)==24,"real freighter capacity carries the full order in one trip")
	var row: RefCounted=g.consignments.instance(id);var credit: int=state.player().credit;var mass: float=g.metrics(state.ship()).total_mass_kg
	check(apply("consignment_action",id,24,"dispatch:"+str(row.generation)),"real dispatch accepts legal loaded-hull route")
	check(row.cargo_units==24 and state.player().credit==credit-24*int(d.deposit_per_unit)-int(d.fee_credit),"dispatch escrows exact deposit and nonrefundable fee")
	check(is_equal_approx(g.metrics(state.ship()).total_mass_kg,mass+24*float(d.unit_mass_kg)) and g.metrics(state.ship()).cargo_used_l>=24*float(d.unit_volume_l),"entrusted freight consumes actual gross mass and ordinary hold")
	check(not apply("consignment_action",id,1,"dispatch:"+str(row.generation)),"active freight cannot be loaded twice")
	check(not apply("consignment_action",id,1,"deliver:"+str(row.generation)),"source station cannot fake destination delivery")
	g.consignments.boosted();place(home.undock_anchor_id)
	var lost_before: int=row.lost_units
	g.damage_ship(Vector3(600,0,0))
	check(row.lost_units>lost_before and row.cargo_units+row.lost_units==24,"actual exposed damage loses finite cargo with conservation")
	var destination: Dictionary=g.definition("station_defs","station_id",d.destination_station_id);place(destination.station_anchor_id,destination.station_id)
	var delivered: int=row.cargo_units
	check(apply("consignment_action",id,1,"deliver:"+str(row.generation)) and row.phase=="ready" and row.cargo_units==0,"physical destination check converts remaining goods into delivery receipts")
	credit=state.player().credit
	check(apply("consignment_action",id,1,"claim:"+str(row.generation)) and state.player().credit==credit+delivered*(int(d.deposit_per_unit)+int(d.reward_per_unit)),"one claim returns only intact deposits and delivered rewards")
	check(not apply("consignment_action",id,1,"claim:"+str(row.generation)),"freight reward cannot be claimed twice")
	var old_generation: int=row.generation
	g.consignments.tick(float(d.cooldown_s))
	check(row.phase=="idle" and row.generation==old_generation+1 and row.accepted_units==0,"real cooldown starts a new quoted freight generation")
	place(home.station_anchor_id,home.station_id);credit=state.player().credit
	check(apply("consignment_action",id,1,"dispatch:"+str(row.generation)),"smaller voluntary shipment remains available")
	check(apply("consignment_action",id,1,"withdraw:"+str(row.generation)) and row.returned_units==1 and row.lost_units==0,"return at source preserves the intact deposit")
	check(apply("consignment_action",id,1,"claim:"+str(row.generation)) and state.player().credit==credit-int(d.fee_credit),"source return refunds the deposit once, retaining the fee")
	g.consignments.tick(float(d.cooldown_s));credit=state.player().credit
	check(apply("consignment_action",id,1,"dispatch:"+str(row.generation)),"third round starts without reusing old receipts")
	var timer: float=row.remaining_s;g.consignments.tick(0.0)
	check(row.remaining_s==timer,"zero world time does not expire cargo")
	g.consignments.tick(float(d.deadline_s)+1.0)
	check(row.phase=="ready" and row.cargo_units==0 and row.lost_units==1 and not row.has_payload_ship_id,"deadline removes remaining entrusted goods with a loss receipt")
	check(apply("consignment_action",id,1,"claim:"+str(row.generation)) and state.player().credit==credit-int(d.deposit_per_unit)-int(d.fee_credit),"lost shipment cannot refund its deposit or create rewards")
func prior_role_signature(value: XJRuntimeState) -> String:
	var data: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		if table in ["remote_support_state","consignment_state","consignment_receipt_state","civilization_command_state","civilization_honor_evidence_state"] or table.begins_with("frontier_"):continue
		var values: Array=[]
		for row: RefCounted in value.rows(table):values.append(Codec.new().encode_row(table,row))
		values.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b));data[table]=values
	return JSON.stringify(data)
func legacy_roles() -> void:
	if g!=null:g.dispose();g=null
	store.close();store=null
	var source: String=OS.get_environment("XJ_ROLES_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.file_exists(source),"closed actual v0.23 paid fixture stays scoped"):return
	var path: String=directory.path_join("legacy.db")
	check(DirAccess.copy_absolute(source,path)==OK,"copy actual old world without touching its source")
	var faulty: FaultStore=FaultStore.new(path);faulty.failure="migration:020_roles.sql";store=faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==16,"020 failure preserves real format16")
	faulty.failure="";if not check(store.open(),"role migration retries to format17"):return
	var slot: Dictionary={}
	for row: Dictionary in store.list_slots():
		if row.slot_kind=="manual":slot=row;break
	state=store.load(slot.slot_id)
	if not check(state!=null and state.find("specialization_research_state","research_id","spec_sustain").invested_points==3,"old partial research and real paid jobs restore"):return
	check(state.rows("industry_job_state").size()==3 and state.rows("drone_bay_state").size()>0,"legacy paid queues cancellation and installed bay exist")
	var before: String=prior_role_signature(state)
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and prior_role_signature(state)==before,"failed role branch preserves all fifty-six old groups")
	faulty.failure="";state=store.upgrade_content(state)
	if not check(state!=null,"reviewed role branch succeeds "+store.last_error):return
	check(prior_role_signature(state)==before,"upgraded assets orders research allegiance clock and RNG are unchanged")
	check(state.rows("consignment_state").size()==2 and state.rows("remote_support_state").is_empty() and state.rows("consignment_receipt_state").is_empty(),"upgrade seeds only empty role contracts without free goods")
	check(store.upgrade_content(state)==state,"role upgrade is idempotent")
	state=store.load(slot.slot_id)
	check(state!=null and not store.catalog.table_names.has("ship_role_capability_defs") and state.rows("consignment_state").is_empty() and prior_role_signature(state)==before,"original manual retains exact independent v0.23 content and progress")
	legacy_checked=true
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"budgets":budgets,"directory":directory,"legacy_checked":legacy_checked}
	print("ROLES_V32_FINAL_JSON ",JSON.stringify(summary));print("ROLES_V32_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
