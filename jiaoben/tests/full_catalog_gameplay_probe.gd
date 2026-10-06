extends SceneTree
## Run after gameplay_probe.gd: real completed research + frozen SQLite state.
## Fixture credits/materials/positions test rule coverage, not campaign earnings.
const G=preload("res://runtime/gameplay.gd")
const Store=preload("res://runtime/data/store.gd")
const D=preload("res://contracts/contract_dtos.gd")
const T=preload("res://contracts/contract_types.gd")
var checks:int=0
var failures:int=0
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func action(g:G,name:String,target:String="",quantity:int=1,extra:String="")->bool:
	var result:D.ActionResultDto=g.act(name,target,quantity,extra)
	if result.phase!=T.ActionPhase.APPLIED:print("REJECT ",name," ",target," ",result.display_reason_key)
	return result.phase==T.ActionPhase.APPLIED
func place(g:G,station_id:String)->void:
	var station:Dictionary=g.definition("station_defs","station_id",station_id)
	var anchor:Dictionary=g.definition("anchor_defs","anchor_id",station.station_anchor_id)
	var ship:D.ShipStateDto=g.state.ship()
	ship.sector_id=station.sector_id;ship.status=T.ShipStatus.DOCKED;ship.has_station_id=true;ship.station_id=station_id
	ship.pos_x=anchor.x_m;ship.pos_y=anchor.y_m;ship.pos_z=anchor.z_m;ship.vel_x=0;ship.vel_y=0;ship.vel_z=0
	g.state.player().has_docked_station_id=true;g.state.player().docked_station_id=station_id
	for container in g.state.rows("container_state"):
		if container.ship_instance_id==ship.ship_instance_id:container.sector_id=ship.sector_id
	expect(g.assign_anchor_site("ship",ship.ship_instance_id,str(anchor.anchor_id)),"fixture assigns station source site "+station_id)
	g.inventory.warehouse(station_id)
func place_anchor(g:G,anchor_id:String)->void:
	# An explicit named-anchor fixture; runtime never infers sites from pose.
	var anchor:Dictionary=g.definition("anchor_defs","anchor_id",anchor_id)
	var ship:D.ShipStateDto=g.state.ship()
	ship.sector_id=anchor.sector_id;ship.pos_x=anchor.x_m;ship.pos_y=anchor.y_m;ship.pos_z=anchor.z_m
	ship.vel_x=0;ship.vel_y=0;ship.vel_z=0;ship.status=T.ShipStatus.FLYING;ship.has_station_id=false;ship.station_id=""
	g.state.player().has_docked_station_id=false;g.state.player().docked_station_id=""
	for container in g.state.rows("container_state"):
		if container.ship_instance_id==ship.ship_instance_id:container.sector_id=ship.sector_id
	expect(g.assign_anchor_site("ship",ship.ship_instance_id,anchor_id),"fixture assigns named anchor site "+anchor_id)
func approach_station(g:G,station_id:String)->void:
	place_anchor(g,str(g.definition("station_defs","station_id",station_id).station_anchor_id))
func inputs(g:G,table:String,key:String,target:String)->void:
	for input in g.rows(table):
		if input[key]==target:g.inventory.grant(g.inventory.warehouse(g.station()),input.item_id,input.quantity)
func _initialize()->void:
	var original:String=ProjectSettings.globalize_path("res://../jiaoben/tmp/gameplay-progress.db")
	var scratch:String=ProjectSettings.globalize_path("res://../jiaoben/tmp/full-catalog-progress.db")
	DirAccess.remove_absolute(scratch)
	expect(DirAccess.copy_absolute(original,scratch)==OK,"clone closed test database without changing prerequisite fixture")
	var store:Store=Store.new(scratch)
	expect(store.open(),"real prior campaign store opens")
	var selected:Dictionary={}
	for candidate in store.list_slots():
		if candidate.slot_kind=="manual" and candidate.slot_index==4:selected=candidate
	expect(not selected.is_empty(),"completed gameplay fixture exists")
	if selected.is_empty():store.close();quit(1);return
	var state:XJRuntimeState=store.load(selected.slot_id,selected.current_snapshot_id,selected.generation)
	expect(state!=null,"full frozen campaign reload")
	if state==null:store.close();quit(1);return
	var g:G=G.new();g.setup(state,store.catalog)
	expect(g.unlocked(g.definition("research_defs","research_id","research_tech_iii").reward_unlock_id) and g.unlocked(g.definition("research_defs","research_id","research_hulls").reward_unlock_id),"actual earlier research preserved")
	state.player().credit=2000000
	place(g,"station_anchor_port")
	# All generations travel through actual access checks, consumption and provenance.
	for module in g.rows("module_defs"):
		var recipe:Dictionary={}
		for candidate in g.rows("recipe_defs"):
			if candidate.output_item_id==module.module_id:recipe=candidate;break
		inputs(g,"recipe_inputs","recipe_id",recipe.recipe_id)
		var before:int=g.inventory.count(g.inventory.warehouse(g.station()),module.module_id)
		var quoted:int=g.economy.quote_manufacture(recipe.recipe_id)
		var credit:int=state.player().credit
		expect(action(g,"manufacture",recipe.recipe_id),"manufacture "+module.module_id)
		expect(g.inventory.count(g.inventory.warehouse(g.station()),module.module_id)==before+1 and state.player().credit==credit-quoted,"exact output/fee "+module.module_id)
		var produced:D.ItemInstanceStateDto=null
		for item in state.rows("item_instance_state"):
			if item.item_def_id==module.module_id and item.has_manufacture_batch_id and item.container_id==g.inventory.warehouse(g.station()):produced=item
		expect(produced!=null and state.find("manufacture_input_state","item_instance_id",produced.item_instance_id)!=null,"real per-instance ledger "+module.module_id)
	var industrial:D.ShipStateDto=null
	for hull in g.rows("hull_recipe_defs"):
		var station_id:String=""
		for shipyard in g.rows("station_ship_stock_defs"):
			if shipyard.ship_id==hull.ship_id:station_id=shipyard.station_id;break
		place(g,station_id)
		inputs(g,"hull_recipe_inputs","hull_recipe_id",hull.hull_recipe_id)
		var before:int=state.rows("ship_state").size()
		expect(action(g,"manufacture",hull.hull_recipe_id),"manufacture hull "+hull.ship_id)
		var created:D.ShipStateDto=state.rows("ship_state").back()
		expect(state.rows("ship_state").size()==before+1 and created.ship_def_id==hull.ship_id and g.equipped(created).is_empty(),"bare hull output "+hull.ship_id)
		var expected:int=0;var actual:int=0
		for slot in g.rows("ship_slot_defs"):
			if slot.ship_id==hull.ship_id:expected+=1
		for container in state.rows("container_state"):
			if container.ship_instance_id==created.ship_instance_id and container.kind==T.ContainerKind.SLOT:actual+=1
		expect(actual==expected,"complete empty slot registry "+hull.ship_id)
		if hull.ship_id=="miner_anvil":industrial=created
	place(g,"station_anchor_port")
	expect(action(g,"switch_ship",industrial.ship_instance_id),"use crafted permanent industrial hull")
	var head:D.ItemInstanceStateDto=null
	for item in state.rows("item_instance_state"):
		if item.item_def_id=="module_industry_sift_ii" and item.container_id==g.inventory.warehouse(g.station()):head=item
	expect(action(g,"fit_module",head.item_instance_id,1,"work:0"),"install actual manufactured II head")
	expect(action(g,"undock"),"industrial launch")
	var node:Dictionary=g.definition("resource_node_defs","node_id","node_forge_special")
	var location:Dictionary=g.definition("resource_node_locations","node_id",node.node_id)
	var anchor:Dictionary=g.definition("anchor_defs","anchor_id",location.anchor_id)
	place_anchor(g,str(anchor.anchor_id))
	var resource:D.ResourceStateDto=state.find("resource_state","node_id",node.node_id)
	var units:int=resource.remaining_units
	expect(action(g,"start_mining",node.node_id),"II mines discovered specialty ore")
	g.tick(.1)
	var energy:float=state.ship().energy
	expect(action(g,"set_module_enabled",head.item_instance_id,1,"off"),"disable paid mining cycle")
	expect(resource.remaining_units==units and g.work.mining_target.is_empty() and state.ship().energy==energy,"cancel pays no refund and gives no ore")
	g.tick(5);action(g,"set_module_enabled",head.item_instance_id,1,"on");action(g,"start_mining",node.node_id);g.tick(4.1);g.stop_interactions()
	expect(resource.remaining_units<units,"II paid cycle extracts finite regional ore")
	var component:Dictionary=g.definition("resource_node_defs","node_id","node_mist_special")
	anchor=g.definition("anchor_defs","anchor_id",g.definition("resource_node_locations","node_id",component.node_id).anchor_id)
	place_anchor(g,str(anchor.anchor_id))
	units=state.find("resource_state","node_id",component.node_id).remaining_units
	expect(action(g,"recover_resource",component.node_id,3),"discovered non-ore component recovery")
	expect(state.find("resource_state","node_id",component.node_id).remaining_units==units-3,"finite component output")
	var wreck:String=g.inventory.wreck(state.current_sector(),g.position(state.ship()),g.spatial_site("ship",state.ship().ship_instance_id))
	g.inventory.grant(wreck,"component_relic",3)
	expect(action(g,"pickup_wreck",wreck),"real nearby wreck pickup")
	expect(g.inventory.count(wreck,"component_relic")==0,"pickup consumes source")
	g.stop_interactions()
	place(g,"station_anchor_port")
	var repair_item:D.ItemInstanceStateDto=null
	for item in state.rows("item_instance_state"):
		if item.item_def_id=="module_support_patch_i" and item.container_id==g.inventory.warehouse(g.station()):repair_item=item
	expect(action(g,"fit_module",repair_item.item_instance_id,1,"work:1"),"install real manufactured armor repair module")
	action(g,"undock")
	var cargo:String=g.inventory.hold(state.ship(),T.ContainerKind.CARGO)
	g.inventory.grant(cargo,"repair_kit_i",3)
	var repair:Dictionary=g.definition("repair_defs","module_id",repair_item.item_def_id)
	var cycle:float=g.definition("module_defs","module_id",repair_item.item_def_id).cycle_s
	state.ship().armor=g.metrics(state.ship()).armor_max-repair.restore_amount
	var damaged:float=state.ship().armor
	g.tick(.1)
	expect(state.ship().armor==damaged and not g.save_eligible(),"repair pays now but produces no immediate HP")
	g.tick(cycle-1)
	expect(state.ship().armor==damaged,"repair HP waits for complete DB cycle")
	g.tick(1.1)
	expect(state.ship().armor==g.metrics(state.ship()).armor_max,"completed repair applies to surviving ship")
	expect(g.inventory.count(cargo,"repair_kit_i",false)==2,"completion does not pay redundant second cycle")
	state.ship().armor=damaged;g.tick(.1)
	var equipment:D.EquipmentStateDto=state.find("equipment_state","item_instance_id",repair_item.item_instance_id)
	expect(action(g,"set_module_enabled",repair_item.item_instance_id,1,"off"),"disable paid repair")
	expect(equipment.cooldown_remaining_s>0 and not equipment.cycle_paid,"disabled repair retains cooldown and forfeits reservation")
	g.tick(cycle+1)
	expect(state.ship().armor==damaged and g.inventory.count(cargo,"repair_kit_i",false)==1,"disabled repair never produces HP or refunded kit")
	place(g,"station_anchor_port")
	var scanner:D.ItemInstanceStateDto=null
	for item in state.rows("item_instance_state"):
		if item.item_def_id=="module_scanner_beacon_iii" and item.container_id==g.inventory.warehouse(g.station()):scanner=item
	expect(action(g,"fit_module",scanner.item_instance_id,1,"utility:0"),"III scanner on permanent industrial hull")
	for region in ["mirror","forge","iron","helios","drift","mist","rift","silent"]:
		var station_id:String="station_"+region+"_hub"
		place(g,station_id)
		expect(action(g,"accept_mission","contract_"+region+"_survey"),region+" repeated survey accept")
		action(g,"undock")
		anchor=g.definition("anchor_defs","anchor_id","anchor_"+region+"_contract_signal")
		place_anchor(g,str(anchor.anchor_id))
		expect(action(g,"start_scan","signal_"+region+"_contract"),region+" current-attempt signal")
		g.tick(40)
		approach_station(g,station_id)
		expect(action(g,"dock",station_id) and action(g,"deliver_mission","contract_"+region+"_survey"),region+" actual survey settlement")
		expect(action(g,"accept_mission","contract_"+region+"_combat"),region+" combat contract accept")
		action(g,"undock")
		var npc:D.NpcStateDto=state.find("npc_state","spawn_id","spawn_"+region+"_sentinel")
		place_anchor(g,str(g.definition("npc_spawn_defs","spawn_id",npc.spawn_id).anchor_id))
		g.damage_npc(npc.npc_instance_id,Vector3(999999,0,0));g.tick(16)
		approach_station(g,station_id)
		expect(action(g,"dock",station_id) and action(g,"deliver_mission","contract_"+region+"_combat"),region+" actual kill settlement")
		expect(action(g,"accept_mission","contract_"+region+"_delivery"),region+" material contract accept")
		var objective:Dictionary=g.missions.objectives("contract_"+region+"_delivery")[0]
		var warehouse:String=g.inventory.warehouse(station_id)
		expect(action(g,"buy_item",objective.target_item_id,objective.required_count),region+" legal sample purchase")
		var before:int=g.inventory.count(warehouse,objective.target_item_id)
		expect(action(g,"deliver_mission","contract_"+region+"_delivery") and g.inventory.count(warehouse,objective.target_item_id)==before-objective.required_count,region+" deliver consumes physical cargo once")
	# The initial three contracts use bounded, protected teaching-service ships.
	place(g,"station_anchor_port")
	expect(action(g,"accept_mission","contract_mining_iron") and action(g,"claim_loan","loan_contract_miner"),"normal mining contract and bounded loan")
	action(g,"undock")
	anchor=g.definition("anchor_defs","anchor_id",g.definition("resource_node_locations","node_id","node_echo_ferrosilicate").anchor_id)
	place_anchor(g,str(anchor.anchor_id))
	action(g,"start_mining","node_echo_ferrosilicate");g.tick(56);g.stop_interactions()
	var ordinary_loan:D.LoanStateDto=g.work._active_loan()
	expect(g.missions.active().collected_units==300 and ordinary_loan.quota_remaining_units<600,"normal contract requires actual collect and spends finite quota")
	approach_station(g,"station_anchor_port")
	expect(action(g,"dock","station_anchor_port") and action(g,"deliver_mission","contract_mining_iron"),"ordinary mining physical delivery")
	expect(ordinary_loan.status==T.LoanStatus.RETURNED,"settlement returns bound hull but retains ordinary excess cargo")
	expect(action(g,"accept_mission","contract_survey_echo") and action(g,"claim_loan","loan_contract_lantern"),"normal survey and loan")
	action(g,"undock")
	anchor=g.definition("anchor_defs","anchor_id",g.definition("signal_defs","signal_id","signal_echo_contract_survey").anchor_id)
	place_anchor(g,str(anchor.anchor_id))
	expect(action(g,"start_scan","signal_echo_contract_survey"),"normal loaned survey actual scanner")
	g.tick(20)
	approach_station(g,"station_anchor_port")
	expect(action(g,"dock","station_anchor_port") and action(g,"deliver_mission","contract_survey_echo"),"ordinary survey return settlement")
	expect(action(g,"accept_mission","contract_patrol_echo") and action(g,"claim_loan","loan_contract_kestrel"),"normal patrol and protected combat loan")
	action(g,"undock")
	var patrol:D.NpcStateDto=state.find("npc_state","spawn_id","spawn_echo_contract_scout")
	place_anchor(g,str(g.definition("npc_spawn_defs","spawn_id",patrol.spawn_id).anchor_id))
	g.damage_npc(patrol.npc_instance_id,Vector3(999999,0,0));g.tick(16)
	approach_station(g,"station_anchor_port")
	expect(action(g,"dock","station_anchor_port") and action(g,"deliver_mission","contract_patrol_echo"),"ordinary patrol kill and return settlement")
	expect(store.save(state,"manual",4),"all factories and regional output durable: "+store.last_error)
	g.dispose();store.close()
	print("FULL_CATALOG_GAMEPLAY_PROBE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
