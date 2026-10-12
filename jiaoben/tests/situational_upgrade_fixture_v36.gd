extends "roles_upgrade_fixture_v32.gd"
## Executed by the actual v0.27 PCK. Money and hull access are isolated fixtures;
## paid jobs, study and rental use the old authoritative action handlers.
func finish() -> void:
	if g!=null and state!=null and failures.is_empty():
		if check(g.get("hired")!=null and g.get("situational")==null,"actual v0.27 rental rules precede observational intelligence"):
			check(apply("hire_action","hire_support",1,g.hired.token()),"old package actually pays hire fee and deposit")
			var rental: RefCounted=g.hired.active()
			check(rental!=null and rental.profile_id=="hire_support","old rental actor and contract are authoritative")
			if rental!=null:
				g.hired.actor(rental).armor-=10.0 # Named condition fixture for preservation.
			check(store.save(state,"manual",2),"old70-group paid rental jobs and study seal "+store.last_error)
	await super.finish()
