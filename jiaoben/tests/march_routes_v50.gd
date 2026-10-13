extends "honors_v33.gd"
## Exhaustive strategy-state matrix. Standing, funds, equipment, qualification
## sources and coarse strategy clock are fixtures, not natural/native evidence.
var routes_checked: Array[String]=[]
var passages: int=0

func _ready() -> void:
	get_tree().set_meta("xj_march_routes_v50_diagnostic",true)
	get_tree().create_timer(900.0).timeout.connect(func():check(false,"route matrix watchdog");finish())
	_run.call_deferred()

func advance_route(war_id: String,wanted: String) -> bool:
	for index: int in range(4800):
		var row: RefCounted=g.march.state_for(war_id)
		if row.phase==wanted:return true
		if row.phase in ["failed","cancelled"]:return false
		# Isolated strategy boundary: movement clocks, gate expiry and campaign
		# coupling run, without claiming full-world economy or physical combat.
		state.snapshot.meta.simulation_tick+=15
		g.march.tick(0.25);g.civilizations.tick(0.25);g._tick_gate_lifetimes(0.25)
		if index%80==0:await get_tree().process_frame
	return false

func _run() -> void:
	directory=OS.get_environment("XJ_MARCH_ROUTES_V50_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/march-routes-v50/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh route matrix scope"):await finish();return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"matrix Store opens "+store.last_error):await finish();return
	state=store.new_world("三文明行军路线矩阵",5001)
	if not check(state!=null,"matrix world created"):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=1000000;g.missions.refresh();g._sync_spawns();hull("transport_caravan");fit("module_scanner_beacon_i","utility:0")
	var faction_index: int=0
	for faction: Dictionary in g.rows("civilization_defs"):
		qualified_faction(faction.faction_id)
		check(apply("honor_action",faction.faction_id,1,"register:unregistered"),"register actual matrix qualification "+str(faction.faction_id))
		complete_event("exp_mirror_relic");complete_event("exp_echo_rescue");freight(6);demolition();at_capital(faction.faction_id)
		check(apply("honor_action",faction.faction_id,1,"certify:assessing"),"certify recorded sources "+str(faction.faction_id))
		for spec: Dictionary in g.rows("civilization_war_defs"):
			if spec.faction_id!=faction.faction_id:continue
			var warehouse: String=g.inventory.warehouse(g.station());var amount: int=int(g.frontier.balance.supply_units)
			g.inventory.grant(warehouse,g.frontier.balance.material_id,amount)
			if not check(apply("start_war",spec.war_id),"start route "+str(spec.war_id)+" "+g.last_error):await finish();return
			var row: RefCounted=g.march.state_for(spec.war_id);var expected: Array[String]=[];var ids: Array[String]=[]
			for leg: Dictionary in g.march.route(row):expected.append(str(leg.endpoint_id))
			for member: RefCounted in g.march.members(row,true):ids.append(member.npc_instance_id)
			if not check(await advance_route(spec.war_id,"arrived"),"continuous outbound route "+str(spec.war_id)):await finish();return
			check(row.sector_id==spec.target_sector_id and row.transferred_supply_units==amount,"actual authored destination and supply handoff "+str(spec.war_id))
			for id: String in ids:
				var actual: Array[String]=[]
				for event: RefCounted in state.rows("march_journal_state"):
					if event.war_id==spec.war_id and event.attempt==row.attempt and event.event_kind=="gate" and event.npc_instance_id==id:actual.append(event.endpoint_id)
				check(actual==expected,"original member crosses complete authored route "+str(spec.war_id));passages+=actual.size()
			check(apply("fleet_command","retreat"),"withdraw route "+str(spec.war_id))
			if not check(await advance_route(spec.war_id,"returned"),"continuous reverse route "+str(spec.war_id)):await finish();return
			check(row.sector_id==faction.capital_sector_id and row.completed_legs==0 and row.returned_supply_units==0 and g.civilizations.active_war()==null,"delivered supplies are not refunded on return "+str(spec.war_id))
			routes_checked.append(spec.war_id)
			print("MARCH_ROUTES_PROGRESS ",routes_checked.size()," / 24 ",spec.war_id)
		check(store.save(state,"manual",faction_index),"faction matrix outcome seals "+store.last_error)
		faction_index+=1
	check(routes_checked.size()==24 and faction_index==3,"all24 routes and three civilizations completed")
	await finish()

func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":XJRuntimeState.TABLES.size(),"routes":routes_checked,"passages":passages,"scope":"qualified strategy fixtures; actual route states and gate constraints with declared coarse clock; not natural or native physics evidence"}
	print("MARCH_ROUTES_V50_FINAL_JSON ",JSON.stringify(summary));print("MARCH_ROUTES_V50_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
