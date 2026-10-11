extends "roles_upgrade_fixture_v32.gd"
## Actual v0.25 PCK: retain paid orders/study/cargo, one old victory and one
## active old campaign. Standing and authority arrival poses are declared fixtures.
func finish() -> void:
	if OS.get_environment("XJ_HIRE_UPGRADE_FIXTURE")=="1":
		await finish_hire_fixture()
		return
	if g!=null and state!=null and failures.is_empty():
		if check(g.get("honors")!=null and g.get("frontier")==null,"actual v0.25 package has commander rules and no frontier stage"):
			var helper: Node=(load(get_script().resource_path.get_base_dir().path_join("honors_v33.gd")) as Script).new();helper.g=g;helper.state=state;helper.store=store
			helper.hull("transport_caravan");helper.fit("module_scanner_beacon_i","utility:0");helper.qualified_faction("faction_route_council")
			helper.apply("honor_action","faction_route_council",1,"register:unregistered");helper.complete_event("exp_mirror_relic");helper.complete_event("exp_echo_rescue");helper.freight(6);helper.demolition();helper.at_capital("faction_route_council")
			helper.apply("honor_action","faction_route_council",1,"certify:assessing")
			check(helper.failures.is_empty(),"old package earns its actual commander qualification")
			check(apply("start_war","war_council_01"),"actual old package accepts its original conquest")
			var war: RefCounted=g.civilizations.active_war();var spec: Dictionary=g.definition("civilization_war_defs","war_id",war.war_id)
			helper.place(spec.capture_anchor_id)
			for npc: RefCounted in state.rows("npc_state").duplicate():
				if npc.alive and not g.civilizations.friendly(npc.npc_instance_id) and g.same_anchor_site(npc,g.definition("anchor_defs","anchor_id",spec.capture_anchor_id)):g.damage_npc(npc.npc_instance_id,Vector3(100000,0,0))
			g.civilizations.tick(float(spec.capture_duration_s)+0.1)
			check(war.status=="won" and g.civilizations.owner(spec.target_sector_id)=="faction_route_council","actual old-rule conquest has its real territory and reward")
			var freight: RefCounted=g.get("consignments");var f: RefCounted=freight.instance("freight_anchor_echo");freight.tick(float(f.cooldown_remaining_s))
			helper.at_station("station_anchor_port");check(apply("consignment_action",f.contract_id,2,"dispatch:"+str(f.generation)),"actual old package escrows two new in-flight cargo batches")
			helper.at_capital("faction_route_council");check(apply("start_war","war_council_02"),"actual old package retains a second ongoing campaign")
			check(store.save(state,"manual",2),"old victory activity orders research and paid cargo seal "+store.last_error)
			helper.g=null;helper.state=null;helper.store=null;helper.free()
	await super.finish()

func finish_hire_fixture() -> void:
	if g!=null and state!=null and failures.is_empty():
		if check(g.get("frontier")!=null and g.get("hired")==null,"actual v0.26 package has frontier rules and no hired companion state"):
			var helper: Node=(load(get_script().resource_path.get_base_dir().path_join("frontier_v34.gd")) as Script).new();helper.g=g;helper.state=state;helper.store=store
			helper.hull("transport_caravan");helper.fit("module_scanner_beacon_i","utility:0");helper.qualified_faction("faction_route_council")
			helper.apply("honor_action","faction_route_council",1,"register:unregistered");helper.complete_event("exp_mirror_relic");helper.complete_event("exp_echo_rescue");helper.freight(6);helper.demolition();helper.at_capital("faction_route_council")
			helper.apply("honor_action","faction_route_council",1,"certify:assessing")
			check(helper.prepare("war_council_01"),"old package pays and prepares its real first frontier campaign")
			helper.capture("war_council_01")
			check(g.frontier.campaign("war_council_01").phase=="completed","actual v0.26 reconstruction has durable sovereignty")
			var freight: RefCounted=g.consignments;var f: RefCounted=freight.instance("freight_anchor_echo");freight.tick(float(f.cooldown_remaining_s));helper.at_station("station_anchor_port")
			check(apply("consignment_action",f.contract_id,2,"dispatch:"+str(f.generation)),"actual v0.26 retains two paid in-flight cargo batches")
			helper.at_capital("faction_route_council");helper.materials(g.inventory.warehouse(g.station()),int(g.frontier.balance.supply_units))
			check(apply("start_war","war_council_02"),"actual v0.26 escrows supplies for its second ongoing frontier campaign")
			var spec: Dictionary=g.frontier.definition("war_council_02");helper.place(spec.scout_anchor_id);helper.cold()
			check(helper.frontier("survey","war_council_02"),"old package pays reconnaissance before the upgrade")
			helper.tick(g.frontier.campaign("war_council_02").survey_remaining_s+0.1)
			check(g.frontier.campaign("war_council_02").phase=="escorting" and state.rows("frontier_actor_state").size()==3,"actual old escort has its convoy and two ambushers")
			helper.at_capital("faction_route_council")
			# Retain an additional truly running paid job after the preparation work.
			var recipe: Dictionary={}
			for entry: Dictionary in g.rows("recipe_defs"):
				if entry.output_item_id=="module_engine_vector_i":recipe=entry;break
			var warehouse: String=g.inventory.warehouse(g.station())
			for input: Dictionary in g.rows("recipe_inputs"):
				if input.recipe_id==recipe.recipe_id:g.inventory.grant(warehouse,input.item_id,int(input.quantity))
			check(apply("manufacture",recipe.recipe_id,1),"actual v0.26 leaves a freshly paid job with unspent work time")
			check(helper.failures.is_empty(),"v0.26 fixture prerequisites have no nested failure")
			check(store.save(state,"manual",2),"actual v0.26 frontier convoy orders research and cargo seal together "+store.last_error)
			helper.g=null;helper.state=null;helper.store=null;helper.free()
	await super.finish()
