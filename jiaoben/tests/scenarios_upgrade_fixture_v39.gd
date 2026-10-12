extends "roles_upgrade_fixture_v32.gd"
## Executed by the real v0.29 PCK through its fixed fitting diagnostic.
func finish() -> void:
	if g!=null and state!=null and failures.is_empty():
		if check(g.get("projects")!=null and g.get("scenarios")==null,"actual v0.29 campaign predates tactical scenarios"):
			var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port")
			place(home.station_anchor_id,home.station_id)
			var accepted: bool=false
			for def: Dictionary in g.rows("mission_defs"):
				if def.accept_station_id==home.station_id and g.missions.eligible(def):accepted=apply("accept_mission",def.mission_id);break
			check(accepted,"real old package accepts an unfinished mission")
			var event: Dictionary=g.exploration.definition("exp_echo_rescue");place(event.entry_anchor_id)
			check(apply("exploration_action",event.event_id,1,"survey:"+str(g.exploration.instance(event.event_id).generation)),"real old package pays an unfinished survey")
			g.tick(1.0/g.rule("simulation_hz"))
			check(not g.exploration.instance(event.event_id).operation_kind.is_empty(),"old paid survey retains remaining work")
			check(store.save(state,"manual",2),"actual old87-group progress seals with active mission and paid survey "+store.last_error)
	await super.finish()
