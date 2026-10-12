extends "scenarios_v39.gd"
## Real acquisition and outcome consumers, with explicit wealth, arrival and
## one production-time boundary. No unrelated user information is read.
func _ready() -> void:
	get_tree().set_meta("xj_measurements_v39_diagnostic",true)
	get_tree().create_timer(420).timeout.connect(func():print("MEASUREMENTS_V39_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func units(item: String,source: String) -> int:
	for row: RefCounted in state.rows("telemetry_source_state"):
		if row.item_id==item and row.source_kind==source:return row.units
	return 0
func _run() -> void:
	directory=OS.get_environment("XJ_MEASUREMENTS_V39_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/measurements-v39/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh isolated actual measurement consumers"):await finish();return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"measurement store opens "+store.last_error):await finish();return
	state=store.new_world("实际产出与结果记录",3939)
	if not check(state!=null,"new99-group measurement world seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=1000000;g.telemetry.wallet()
	hull("miner_anvil");fit("module_industry_sift_i","work:0");at_station("station_anchor_port")
	var warehouse: String=g.inventory.warehouse(g.station())
	check(apply("buy_item","ore_ferrosilicate",2,warehouse) and units("ore_ferrosilicate","purchase")==2,"actual purchase reports precisely the acquired units")
	var recipe: Dictionary={}
	for candidate: Dictionary in g.rows("recipe_defs"):
		if candidate.output_item_id=="module_engine_vector_i":recipe=candidate;break
	if not check(not recipe.is_empty(),"manufacturing test uses an actual current blueprint"):await finish();return
	for input: Dictionary in g.rows("recipe_inputs"):
		if input.recipe_id==recipe.recipe_id:g.inventory.grant(warehouse,input.item_id,int(input.quantity))
	check(apply("manufacture",recipe.recipe_id,1),"normal industrial action escrows the required materials")
	var job: RefCounted=g.industry.jobs(g.station())[0]
	var work: float=job.remaining_s;state.snapshot.meta.simulation_tick+=int(ceil(work*g.rule("simulation_hz")));g.industry.tick(work)
	check(job.status=="ready" and units(recipe.output_item_id,"manufacture")==0,"finishing work without claiming produces no acquired-item measurement")
	check(apply("claim_industry",job.job_id) and units(recipe.output_item_id,"manufacture")==int(recipe.output_quantity),"actual one-time claim reports produced items")
	var produced: int=units(recipe.output_item_id,"manufacture")
	check(not apply("claim_industry",job.job_id) and units(recipe.output_item_id,"manufacture")==produced,"duplicate manufacture claim cannot duplicate its measurement")
	var mining_node: String=""
	for node: Dictionary in g.rows("resource_node_defs"):
		if node.sector_id=="sector_echo" and node.item_id=="ore_ferrosilicate" and not g.exploration.managed_resources.has(node.node_id):mining_node=node.node_id;break
	if not check(not mining_node.is_empty(),"mining test resolves an actual ordinary nearby source"):await finish();return
	var location: Dictionary=g.definition("resource_node_locations","node_id",mining_node);place(location.anchor_id)
	check(apply("start_mining",mining_node),"normal compatible mining starts at the actual node")
	step(float(g.definition("module_defs","module_id","module_industry_sift_i").cycle_s)+0.1);g.work.stop_mining()
	check(units("ore_ferrosilicate","mining")>0,"completed paid mining records actual ordinary ore output")
	var recovered: bool=false
	for node: Dictionary in g.rows("resource_node_defs"):
		if g.definition("item_defs","item_id",node.item_id).item_type=="ore" or g.exploration.managed_resources.has(node.node_id):continue
		var source: Dictionary=g.definition("resource_node_locations","node_id",node.node_id)
		place(source.anchor_id);var before: int=units(node.item_id,"salvage")
		if apply("recover_resource",node.node_id,1):
			check(units(node.item_id,"salvage")==before+1 and units(node.item_id,"mining")==0,"recovering a component is classified as salvage rather than ore mining")
			recovered=true;break
	check(recovered,"at least one real ordinary component source was recovered")
	at_station("station_anchor_port");warehouse=g.inventory.warehouse(g.station())
	var signature: String=JSON.stringify(g.journal.export_data().sources)
	var moved: bool=false
	for stack: RefCounted in state.rows("inventory_stack_state"):
		if stack.item_def_id=="ore_ferrosilicate" and stack.policy_id=="normal_owned" and stack.container_id==g.inventory.hold(state.ship(),T.ContainerKind.MINERAL):
			moved=apply("move_stack",stack.stack_id,1,warehouse);break
	check(moved,"normal mineral hold to station transfer succeeds")
	check(JSON.stringify(g.journal.export_data().sources)==signature,"ordinary storage movement does not invent another acquisition")
	var accepted: bool=false
	for def: Dictionary in g.rows("mission_defs"):
		if def.accept_station_id==g.station() and g.missions.eligible(def):accepted=apply("accept_mission",def.mission_id);break
	if not check(accepted,"real mission acceptance creates an activity baseline"):await finish();return
	var mission: RefCounted=g.missions.active();var start: int=state.snapshot.meta.simulation_tick
	step(0.5);check(apply("abandon_mission",mission.mission_instance_id),"actual explicit abandonment ends the attempt")
	var outcome: RefCounted=null
	for record: RefCounted in state.rows("activity_record_state"):
		if record.object_id==mission.mission_instance_id:outcome=record
	check(outcome!=null and outcome.phase=="finished" and outcome.reason_code=="manual" and outcome.outcome=="withdrawn" and is_equal_approx(outcome.elapsed_s,float(state.snapshot.meta.simulation_tick-start)/g.rule("simulation_hz")),"mission duration uses logical ticks and reports the actual manual outcome")
	hull("frigate_kestrel");fit("module_thermal_sunline_i","weapon:0");at_station("station_anchor_port")
	var base: int=g.scenarios.budget();var bound: String=g.scenarios.fingerprint()
	check(apply("hire_action","hire_escort",1,g.hired.token()),"ordinary paid escort contract can be created")
	var companion: RefCounted=g.hired.active();var reference: int=int(g.definition("ship_defs","ship_id",g.hired.profile(companion.profile_id).hull_id).base_ask_credit)
	check(g.scenarios.budget()==base+reference and g.scenarios.fingerprint()!=bound and not g.scenarios.trial_reason("trial_precision","accept").is_empty(),"challenge counts companion hull value and binds its actual contract")
	check(apply("hire_action","dismiss",1,g.hired.token()) and g.scenarios.budget()==base,"settling the real escort removes its capability from the challenge budget")
	if not preserve(1,"real acquisition and outcome sources"):await finish();return
	place("trial_precision_entry");g.damage_ship(Vector3(100000,0,0),"environment")
	check(state.rows("activity_record_state").any(func(r: RefCounted):return r.activity_kind=="ship_loss" and r.outcome=="destroyed" and r.reason_code=="environment"),"actual fatal environmental damage records its known source")
	check(apply("request_rescue"),"normal rescue recovers from the actual ship loss")
	if not preserve(2,"actual death reason and normal rescue"):await finish();return
	await finish()
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":XJRuntimeState.TABLES.size()}
	print("MEASUREMENTS_V39_FINAL_JSON ",JSON.stringify(summary));print("MEASUREMENTS_V39_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
