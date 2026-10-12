extends "roles_upgrade_fixture_v32.gd"
## Runs only through the actual v0.30 PCK's existing fitting endpoint.
## No references to v0.31 DTOs or services may enter this old-client fixture.
func finish() -> void:
	if g!=null and state!=null and failures.is_empty():
		if check(g.get("scenarios")!=null and g.get("crew")==null,"actual v0.30 package has scenarios and predates crew"):
			var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port");place(home.station_anchor_id,home.station_id)
			var accepted: bool=false
			for def: Dictionary in g.rows("mission_defs"):
				if def.accept_station_id==home.station_id and g.missions.eligible(def):accepted=apply("accept_mission",def.mission_id);break
			check(accepted,"real old client accepts an unfinished mission")
			check(apply("hire_action","hire_escort",1,g.hired.token()),"real old client signs a paid escort contract")
			var trial: Dictionary=g.scenarios.definition("trial","trial_support");var station: Dictionary=g.definition("station_defs","station_id",trial.station_id)
			place(station.station_anchor_id,station.station_id);g.hired.follow_arrival()
			var patch: String=g.inventory.grant(g.inventory.warehouse(station.station_id),"module_support_patch_i",1)[0]
			var fitted: bool=apply("fit_module",patch,1,"work:0")
			if not fitted:print("LEGACY_FIT_REASON ",g.last_error)
			check(fitted,"old client fits actual remote repair before challenge binding")
			check(apply("trial_action",trial.trial_id,1,"accept|"+g.scenarios.token("trial",trial.trial_id)),"old client freezes an unfinished paid challenge binding")
			var event: Dictionary=g.exploration.definition("exp_echo_rescue");place(event.entry_anchor_id);g.hired.follow_arrival()
			check(apply("exploration_action",event.event_id,1,"survey:"+str(g.exploration.instance(event.event_id).generation)),"old client starts a paid unfinished survey")
			g.tick(1.0/g.rule("simulation_hz"))
			check(not g.exploration.instance(event.event_id).operation_kind.is_empty(),"actual old survey retains paid work")
			check(store.save(state,"manual",2),"actual99-group world seals with jobs mission lease challenge and survey "+store.last_error)
	await super.finish()
