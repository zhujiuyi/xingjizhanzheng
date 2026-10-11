extends "roles_upgrade_fixture_v32.gd"
## Actual v0.25 PCK: retain paid orders/study/cargo, one old victory and one
## active old campaign. Standing and authority arrival poses are declared fixtures.
func finish() -> void:
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
