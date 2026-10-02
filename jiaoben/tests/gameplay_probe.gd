extends SceneTree
const Gameplay = preload("res://runtime/gameplay.gd")
const Catalog = preload("res://runtime/data/catalog.gd")
const Store = preload("res://runtime/data/store.gd")
const Initial = preload("res://runtime/data/initial_state.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var failures:int=0
var checks:int=0
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func action(g:Gameplay,name:String,target:String="",quantity:int=1,extra:String="")->bool:
	var r:D.ActionResultDto=g.act(name,target,quantity,extra)
	if r.phase!=T.ActionPhase.APPLIED:print("REJECT ",name," ",r.display_reason_key)
	return r.phase==T.ActionPhase.APPLIED
func _initialize()->void:
	var dbpath:String=ProjectSettings.globalize_path("res://../jiaoben/tmp/gameplay-progress.db")
	DirAccess.remove_absolute(dbpath)
	var store:Store=Store.new(dbpath);expect(store.open(),"store open")
	var s:XJRuntimeState=store.new_world("gameplay-probe",42);expect(s!=null,"durable new world")
	var c:Catalog=store.catalog
	var g:Gameplay=Gameplay.new();g.setup(s,c)
	expect(g.metrics(s.ship()).power_used==65,"rain default budgets")
	expect(action(g,"accept_mission","tutorial_flight"),"T0 accept")
	var initial_undock:D.ActionResultDto=g.act("undock")
	expect(initial_undock.phase==T.ActionPhase.APPLIED and not initial_undock.autosave_request_id.is_empty(),"persistent action supplies autosave request")
	g.record_event("reach_anchor","anchor_anchor_flight_forward",1);g.record_event("brake_at_anchor","anchor_anchor_flight_forward",1);g.record_event("reach_anchor","anchor_anchor_flight_turn",1)
	s.ship().pos_x=0;s.ship().pos_y=0;s.ship().pos_z=0
	expect(action(g,"dock","station_anchor_port"),"dock")
	expect(action(g,"deliver_mission","tutorial_flight"),"T0 claim")
	expect(s.player().credit==5800,"exact T0 payout")
	expect(not action(g,"deliver_mission","tutorial_flight"),"no duplicate payout")
	expect(action(g,"accept_mission","tutorial_scan_gate"),"T1 accept")
	# Scan device uses basic installed-free calibration; real range and cycle are enforced.
	action(g,"undock");s.ship().pos_x=400;s.ship().pos_y=80;s.ship().pos_z=-1600
	expect(action(g,"start_scan","signal_anchor_gate_calibration"),"basic scan available")
	g.tick(11)
	expect(g.work.scan_target.is_empty(),"scan completed")
	expect(s.find("discovery_state","signal_id","signal_anchor_gate_calibration")!=null,"scan persisted discovery")
	expect(not g.take_autosave_request().is_empty(),"asynchronous scan supplies autosave request")
	s.ship().pos_x=0;s.ship().pos_y=0;s.ship().pos_z=0;action(g,"dock","station_anchor_port")
	expect(action(g,"deliver_mission","tutorial_scan_gate"),"T1 claim")
	expect(action(g,"accept_mission","tutorial_mining_delivery"),"T2 accept")
	expect(action(g,"claim_loan","loan_tutorial_miner"),"free miner loan")
	var loan:D.LoanStateDto=g.work._active_loan()
	var borrowed:String=s.ship().ship_instance_id
	expect(s.ship().ship_def_id=="miner_anvil","miner controlled")
	expect(not action(g,"sell_ship",borrowed),"bound loan not sellable")
	action(g,"undock");g.record_event("transit_connection","conn_anchor_echo",1)
	s.ship().sector_id="sector_echo";s.ship().pos_x=1000;s.ship().pos_y=0;s.ship().pos_z=-1800
	for h in s.rows("container_state"):
		if h.ship_instance_id==borrowed:h.sector_id="sector_echo"
	expect(action(g,"start_mining","node_echo_ferrosilicate"),"mining starts")
	g.tick(32);g.stop_interactions()
	expect(loan.quota_remaining_units==0,"tutorial quota respected")
	expect(g.missions.active().collected_units==150,"historical collected exact")
	s.ship().sector_id="sector_anchor";s.ship().pos_x=0;s.ship().pos_y=0;s.ship().pos_z=0
	for h in s.rows("container_state"):
		if h.ship_instance_id==borrowed:h.sector_id="sector_anchor"
	action(g,"dock","station_anchor_port")
	expect(action(g,"deliver_mission","tutorial_mining_delivery"),"T2 atomic goods/payout/return")
	expect(loan.status==T.LoanStatus.RETURNED,"loan returned")
	expect(s.player().credit==10500,"T0-T2 rewards exact")
	expect(store.save(s,"manual",0),"T2 state and loan return durable: "+store.last_error)
	expect(action(g,"accept_mission","tutorial_combat"),"T3 accept")
	expect(action(g,"claim_loan","loan_tutorial_kestrel"),"T3 loan")
	action(g,"undock")
	var gun:D.EquipmentStateDto=null
	for equipment in g.equipped(s.ship()):
		if not g.definition("weapon_defs","module_id",equipment.module_def_id).is_empty():gun=equipment;break
	g.combat_remaining_s=0
	expect(not g.consume_weapon_cycle(gun.item_instance_id).is_empty() and g.combat_remaining_s==g.rule("combat_exit_delay_s"),"paid shot starts combat even without hit")
	g.combat_remaining_s=0
	expect(g.consume_weapon_cycle(gun.item_instance_id).is_empty() and g.combat_remaining_s==0,"rejected cooldown shot does not start combat")
	g.mark_hostile_attempt()
	expect(not g.save_eligible(),"actual hostile NPC fire hook prevents premature save")
	var npc:D.NpcStateDto=s.find("npc_state","spawn_id","spawn_anchor_tutorial_scout")
	expect(npc!=null and npc.alive,"T3 live target generated")
	var before_bounty:int=s.player().credit
	g.damage_npc(npc.npc_instance_id,Vector3(99999,0,0))
	expect(s.player().credit==before_bounty,"tutorial target no bounty")
	expect(g.missions.progress(g.missions.active(),2).progress_units==1,"T3 death event independent of loot")
	g.tick(16);s.ship().pos_x=0;s.ship().pos_y=0;s.ship().pos_z=0
	expect(action(g,"dock","station_anchor_port"),"T3 safe return")
	expect(action(g,"deliver_mission","tutorial_combat"),"T3 claim and loan return")
	expect(action(g,"accept_mission","tutorial_exploration"),"T4 accept")
	expect(action(g,"claim_loan","loan_tutorial_lantern"),"T4 loan")
	action(g,"undock");s.ship().sector_id="sector_echo";s.ship().pos_x=-1600;s.ship().pos_y=400;s.ship().pos_z=-2400
	for h in s.rows("container_state"):
		if h.ship_instance_id==s.ship().ship_instance_id:h.sector_id="sector_echo"
	expect(action(g,"start_scan","signal_echo_common_survey"),"T4 contract-scoped signal")
	g.tick(11);s.ship().sector_id="sector_anchor";s.ship().pos_x=0;s.ship().pos_y=0;s.ship().pos_z=0
	for h in s.rows("container_state"):
		if h.ship_instance_id==s.ship().ship_instance_id:h.sector_id="sector_anchor"
	expect(action(g,"dock","station_anchor_port"),"T4 return")
	expect(action(g,"deliver_mission","tutorial_exploration"),"T4 payout")
	expect(s.player().credit==14500 and g.unlocked("unlock_open_routes"),"complete tutorial exact cash and full routes")
	expect(store.save(s,"manual",1),"T0-T4 complete state durable: "+store.last_error)
	expect(action(g,"manufacture","recipe_ammo",1),"manufacture basic ammo")
	var normal:String=g.inventory.warehouse("station_anchor_port")
	expect(g.inventory.count(normal,"ammo_kinetic_slug_i",true)>=100,"normal crafted ammo")
	# Full content relations and unlocks may be synthetically set only inside this fixture.
	s.player().credit=1000000
	expect(action(g,"buy_ship","frigate_lantern"),"permanent hull purchase")
	var purchased:D.ShipStateDto=null
	for sh in s.rows("ship_state"):
		if sh.policy_id=="normal_owned" and sh.ship_def_id=="frigate_lantern":purchased=sh
	expect(purchased!=null and g.equipped(purchased).is_empty(),"purchase creates bare hull")
	expect(action(g,"buy_item","module_kinetic_needle_i"),"module purchase")
	var bought:D.ItemInstanceStateDto=null
	for item in s.rows("item_instance_state"):
		if item.origin_kind==T.ItemOrigin.PURCHASE:bought=item
	expect(action(g,"switch_ship",purchased.ship_instance_id),"switch to permanent hull")
	expect(action(g,"fit_module",bought.item_instance_id,1,"weapon:0"),"fit normal module")
	expect(not action(g,"fit_module",bought.item_instance_id,1,"weapon:0"),"duplicate install rejected")
	expect(action(g,"unfit_module",bought.item_instance_id),"unfit keeps same instance")
	expect(action(g,"recycle",bought.item_instance_id),"NPC purchased frozen recipe recycle")
	expect(s.find("item_instance_state","item_instance_id",bought.item_instance_id)==null,"recycle invalidates once")
	var victim:D.ShipStateDto=D.ShipStateDto.new();victim.shield=50;victim.armor=50;victim.hull=100
	g.apply_damage(victim,Vector3(200,0,0),{"shield":Vector3(.5,0,0),"armor":Vector3(.2,0,0),"hull":Vector3(.1,0,0)})
	expect(is_equal_approx(victim.hull,66.25),"raw remainder recomputes each layer resistance")

	# All eight authored story chapters use real scanner cycles, local purchases and atomic deliveries.
	expect(action(g,"buy_item","module_scanner_beacon_i"),"buy scanner for owned explorer")
	var scanner:D.ItemInstanceStateDto=null
	for item in s.rows("item_instance_state"):
		if item.item_def_id=="module_scanner_beacon_i" and item.policy_id=="normal_owned":scanner=item
	expect(action(g,"fit_module",scanner.item_instance_id,1,"utility:0"),"fit explorer scanner")
	var regions:Array[String]=["mirror","forge","iron","helios","drift","mist","rift","silent"]
	for region in regions:
		var station_id:String="station_"+region+"_hub"
		s.ship().sector_id="sector_"+region;s.ship().status=T.ShipStatus.DOCKED;s.ship().has_station_id=true;s.ship().station_id=station_id;s.player().has_docked_station_id=true;s.player().docked_station_id=station_id
		for hold in s.rows("container_state"):
			if hold.ship_instance_id==s.ship().ship_instance_id:hold.sector_id=s.ship().sector_id
		expect(action(g,"accept_mission","story_"+region),region+" story accept")
		action(g,"undock")
		var anchor:Dictionary=c.one("anchor_defs","anchor_id","anchor_"+region+"_signal")
		s.ship().pos_x=anchor.x_m;s.ship().pos_y=anchor.y_m;s.ship().pos_z=anchor.z_m
		expect(action(g,"start_scan","signal_"+region+"_relic"),region+" scan anomaly")
		if region=="mirror":
			g.tick(.1)
			var scanner_state:D.EquipmentStateDto=s.find("equipment_state","item_instance_id",scanner.item_instance_id)
			expect(action(g,"set_module_enabled",scanner.item_instance_id,1,"off"),"stop scanner during paid cycle")
			expect(g.work.scan_target.is_empty() and not scanner_state.cycle_paid and scanner_state.cooldown_remaining_s>0,"disabled paid scan cancels without cooldown reset")
			g.tick(2)
			expect(s.find("discovery_state","signal_id","signal_mirror_relic")==null,"cancelled scanner produces no discovery")
			action(g,"set_module_enabled",scanner.item_instance_id,1,"on")
			action(g,"start_scan","signal_mirror_relic")
		g.tick(36)
		expect(g.unlocked("unlock_site_"+region),region+" extraction unlocked by real scan")
		s.ship().pos_x=0;s.ship().pos_y=0;s.ship().pos_z=0;action(g,"dock",station_id)
		var material:String=c.one("resource_node_defs","node_id","node_"+region+"_special").item_id
		expect(action(g,"buy_item",material,5),region+" sample alternative procurement")
		expect(action(g,"deliver_mission","story_"+region),region+" story atomic turnin")
		if region=="mirror":
			action(g,"buy_item","component_anchor_ceramic",4)
			expect(action(g,"research","research_tech_ii"),"research II with active verification and samples")
			expect(not action(g,"research","research_tech_ii"),"research cannot charge or unlock twice")
		if region=="forge":
			action(g,"buy_item","material_dense_alloy",10);action(g,"buy_item","component_power_cell",3)
			expect(action(g,"research","research_hulls"),"research advanced hulls")
			expect(action(g,"research","research_base"),"research personal station facilities")
			for base_id in ["base_repair","base_industry","base_navigation","base_warehouse"]:
				action(g,"buy_item","material_dense_alloy",10);action(g,"buy_item","component_power_cell",4)
				expect(action(g,"build_base",base_id),"build "+base_id)
				expect(not action(g,"build_base",base_id),"duplicate facility blocked")
			expect(g.economy.base_factor("industry")==1.02,"bounded industrial service improvement")
			action(g,"buy_item","module_kinetic_needle_i",1);action(g,"buy_item","component_relic",3);action(g,"buy_item","material_dense_alloy",2)
			expect(action(g,"manufacture","recipe_module_kinetic_needle_ii",1),"II chain produces normal module with actual ledger")
			var module_ii:D.ItemInstanceStateDto=null
			for item in s.rows("item_instance_state"):
				if item.item_def_id=="module_kinetic_needle_ii":module_ii=item
			expect(module_ii!=null and module_ii.has_manufacture_batch_id,"II provenance recorded")
			expect(action(g,"recycle",module_ii.item_instance_id),"manufactured II real input recycle")
		if region=="silent":
			action(g,"buy_item","component_relic_logic",10)
			expect(action(g,"research","research_tech_iii"),"research III final story and relic samples")
			action(g,"buy_item","module_kinetic_needle_ii",1);action(g,"buy_item","component_relic_logic",2);action(g,"buy_item","material_dense_alloy",5)
			expect(action(g,"manufacture","recipe_module_kinetic_needle_iii",1),"III production")
	expect(s.rows("base_module_state").size()==4,"all four bases in typed persistent state")
	expect(store.save(s,"manual",2),"all stories/research/bases/industrial provenance durable: "+store.last_error)
	var hole:D.GateStateDto=s.find("gate_state","connection_id","conn_wandering_mirror_mist")
	expect(hole.has_lifetime_remaining_s and hole.lifetime_remaining_s<1800,"discovered optional hole consumes world lifetime")
	g._tick_gate_lifetimes(hole.lifetime_remaining_s)
	expect(not hole.enabled,"finite optional hole closes without removing fixed return route")
	expect(store.save(s,"manual",3),"expired wandering lifetime durable: "+store.last_error)
	var slots:Array[Dictionary]=store.list_slots();var selected:Dictionary={}
	for candidate in slots:
		if candidate.slot_kind=="manual" and candidate.slot_index==3:selected=candidate
	g.dispose()
	var loaded:XJRuntimeState=store.load(selected.slot_id,selected.current_snapshot_id,selected.generation)
	expect(loaded!=null,"full singleplayer state reload: "+store.last_error)
	if loaded!=null:
		expect(loaded.rows("base_module_state").size()==4,"base facilities restored")
		expect(loaded.find("unlock_state","unlock_id","unlock_tech_iii")!=null,"permanent III knowledge restored")
		expect(not loaded.find("gate_state","connection_id","conn_wandering_mirror_mist").enabled,"expired optional gate restored")

	if loaded!=null:
		g.setup(loaded,store.catalog);s=loaded
		s.ship().sector_id="sector_anchor";s.ship().status=T.ShipStatus.DOCKED;s.ship().has_station_id=true;s.ship().station_id="station_anchor_port";s.player().has_docked_station_id=true;s.player().docked_station_id="station_anchor_port"
		for hold in s.rows("container_state"):
			if hold.ship_instance_id==s.ship().ship_instance_id:hold.sector_id="sector_anchor"
		expect(action(g,"accept_mission","contract_mining_iron"),"ordinary contract after full save/load")
		expect(action(g,"claim_loan","loan_contract_miner"),"ordinary bounded loan")
		action(g,"undock");s.ship().sector_id="sector_echo";s.ship().pos_x=1000;s.ship().pos_y=0;s.ship().pos_z=-1800
		for hold in s.rows("container_state"):
			if hold.ship_instance_id==s.ship().ship_instance_id:hold.sector_id="sector_echo"
		action(g,"start_mining","node_echo_ferrosilicate");g.tick(4.1);g.stop_interactions()
		var ordinary_loan:D.LoanStateDto=g.work._active_loan();var remaining:int=ordinary_loan.quota_remaining_units;var attempt_id:String=g.missions.active().mission_instance_id
		expect(remaining<600 and remaining>0,"ordinary paid quota consumed")
		g.damage_ship(Vector3(999999,0,0))
		expect(ordinary_loan.status==T.LoanStatus.LOST and not ordinary_loan.has_current_ship_id,"destroyed loan clears effective ship, keeps issue")
		expect(g.missions.active().mission_instance_id==attempt_id,"ship loss preserves active attempt")
		var before_ships:int=s.rows("ship_state").size()
		expect(action(g,"request_rescue"),"recovery switches to existing usable ship")
		expect(s.rows("ship_state").size()==before_ships,"no duplicate guarantee when ship available")
		g.tick(31)
		expect(action(g,"claim_loan","loan_contract_miner"),"same attempt loan replacement")
		expect(ordinary_loan.quota_remaining_units==remaining and ordinary_loan.issuance_count==2,"replacement preserves cumulative quota")
		expect(store.save(s,"manual",4),"loan replacement provenance durable: "+store.last_error)
		expect(action(g,"abandon_mission",attempt_id),"contract can abandon with safe cleanup")
		expect(not action(g,"accept_mission","contract_mining_iron"),"abandon cannot reset retry cooldown")
		_verify_wreck(g,s)
		expect(store.save(s,"manual",4),"abandoned state and bound cleanup durable: "+store.last_error)
	print("GAMEPLAY_PROBE checks=",checks," failures=",failures)
	g.dispose();store.close();quit(1 if failures else 0)

func _verify_wreck(g:Gameplay,s:XJRuntimeState)->void:
	# A separate normal hull keeps the live campaign fixture intact.
	var ship:D.ShipStateDto=g.inventory.create_ship("miner_anvil","station_anchor_port")
	var cargo:String=g.inventory.hold(ship,T.ContainerKind.CARGO)
	var mineral:String=g.inventory.hold(ship,T.ContainerKind.MINERAL)
	g.inventory.grant(cargo,"ore_ferrosilicate",1)
	g.inventory.grant(mineral,"ore_ferrosilicate",1)
	g.inventory.grant(cargo,"ammo_kinetic_slug_i",10,"tutorial_protected")
	var spare_ids:Array[String]=g.inventory.grant(cargo,"module_kinetic_needle_i",2)
	var slot:D.ContainerStateDto=g.inventory.slot(ship,"utility",0)
	var installed:Array[String]=g.inventory.grant(slot.container_id,"module_scanner_beacon_i",1)
	var equipment:D.EquipmentStateDto=D.EquipmentStateDto.new();equipment.slot_container_id=slot.container_id;equipment.item_instance_id=installed[0];equipment.module_def_id="module_scanner_beacon_i";equipment.enabled=true;s.add("equipment_state",equipment)
	ship.hull=0;ship.status=T.ShipStatus.DESTROYED;ship.has_station_id=false;ship.station_id="";g.inventory.ship_destroyed(ship)
	var recovered:int=0;var spare_count:int=0;var bound_count:int=0
	for container in s.rows("container_state"):
		if container.kind==T.ContainerKind.WRECK and container.sector_id==ship.sector_id:
			recovered+=g.inventory.count(container.container_id,"ore_ferrosilicate")
			bound_count+=g.inventory.count(container.container_id,"ammo_kinetic_slug_i",false)
	for item_id in spare_ids:
		if s.find("item_instance_state","item_instance_id",item_id)!=null:spare_count+=1
	expect(recovered==1,"two one-unit stacks across holds merge before floor salvage")
	expect(s.find("item_instance_state","item_instance_id",installed[0])==null,"installed normal module is destroyed with hull")
	expect(spare_count==1,"compatible loose modules use DB recovery ratio")
	expect(bound_count==0,"protected cargo never creates normal salvage")
