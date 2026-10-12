extends "roles_upgrade_fixture_v32.gd"
## Real v0.28 PCK creates paid rental, old observations, jobs and partial study.
## Money/access/arrival poses and damaged condition are explicit preconditions.
func finish() -> void:
	if g!=null and state!=null and failures.is_empty():
		if check(g.get("situational")!=null and g.get("projects")==null,"actual v0.28 precedes campaign projects and summaries"):
			check(apply("hire_action","hire_support",1,g.hired.token()),"actual old package pays support contract and deposit")
			g.situational.observe()
			var location: Dictionary=g.definition("resource_node_locations","node_id","node_echo_ferrosilicate")
			place(location.anchor_id);g.hired.follow_arrival();g.situational.observe()
			check(state.rows("resource_intel_state").size()>0 and state.rows("demand_intel_state").size()>0,"actual old sensor and station services retain both observation groups")
			var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port")
			place(home.station_anchor_id,home.station_id);g.hired.follow_arrival();g.hired.actor(g.hired.active()).armor-=10.0
			check(store.save(state,"manual",2),"old72-group paid world and observations seal "+store.last_error)
	await super.finish()
