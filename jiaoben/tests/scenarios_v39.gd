extends "campaign_v37.gd"
## Explicit wealth, gear, arrivals and hit vectors; native suite owns physical proof.
var v42_fleet_rules: bool=false
func _ready() -> void:
	get_tree().set_meta("xj_scenarios_v39_diagnostic",true)
	get_tree().create_timer(600).timeout.connect(func():print("SCENARIOS_V39_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func scenario(kind: String,id: String,action: String,index: int=-1) -> bool:
	var extra: String=action+"|"+g.scenarios.token(kind,id)+("|"+str(index) if index>=0 else "")
	var ok: bool=apply(kind+"_action",id,1,extra)
	if not ok:print("SCENARIO_REASON ",g.last_error)
	return ok
func _run() -> void:
	directory=OS.get_environment("XJ_SCENARIOS_V39_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/scenarios-v39/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh isolated scenario world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format24 and reviewed adapter open "+store.last_error):await finish();return
	v42_fleet_rules=store.catalog.table_names.has("fleet_balance_defs")
	state=store.new_world("战术与行为记录",3901)
	if not check(state!=null,"new active-rules world seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==(114 if store.catalog.table_names.has("march_balance_defs") else 108 if v42_fleet_rules else 99) and state.rows("trial_state").size()==3 and state.rows("blockade_state").size()==3 and state.rows("blockade_node_state").size()==12 and (not v42_fleet_rules or (state.rows("crew_member_state").size()==8 and state.rows("fleet_total_state").size()==1)),"all tactical definitions and current ABI have unique initial state")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=1000000;g.telemetry.wallet()
	hull("frigate_kestrel");fit("module_kinetic_needle_ii","weapon:0");at_station("station_anchor_port")
	check(scenario("trial","trial_precision","accept"),"actual budget acceptance pays normal fee")
	var credit: int=state.player().credit;var stamp: String=full_signature(state,false)
	check(not apply("trial_action","trial_precision",1,"accept|0") and state.player().credit==credit and full_signature(state,false)==stamp,"stale trial acceptance neither charges nor mutates")
	place("trial_precision_entry");check(scenario("trial","trial_precision","start"),"actual arrival starts managed target")
	var member: RefCounted=state.rows("scenario_actor_state")[0];var npc: RefCounted=state.find("npc_state","npc_instance_id",member.npc_instance_id)
	g.damage_npc(npc.npc_instance_id,Vector3(5,0,0),Vector3(5,0,0))
	check(g.scenarios.instance("trial","trial_precision").effective_hp==0,"out-of-window actual damage gives no challenge credit")
	state.ship().pos_x=npc.pos_x;state.ship().pos_y=npc.pos_y;state.ship().pos_z=npc.pos_z+1200
	g.damage_npc(npc.npc_instance_id,Vector3(10000,0,0),Vector3(10000,0,0))
	check(g.scenarios.instance("trial","trial_precision").phase=="ready","bounded actual attributed damage completes precision objective")
	at_station("station_anchor_port");check(scenario("trial","trial_precision","claim"),"real station claims one horizontal award")
	check(state.rows("tactical_award_state").size()==1 and state.rows("trial_result_state").size()==1,"one result and one award retained")
	check(not scenario("trial","trial_precision","claim"),"completed trial cannot replay claim")
	if not preserve(1,"precision and activity outcomes"):await finish();return
	hull("transport_caravan");fit("module_scanner_beacon_i","utility:0");at_station("station_echo_depot")
	check(scenario("blockade","blockade_echo","accept"),"real blockade order pays fee")
	place("blockade_echo_entry");check(scenario("blockade","blockade_echo","start"),"actual entrance loads bounded task cargo")
	var block: RefCounted=g.scenarios.instance("blockade","blockade_echo")
	check(block.loaded_units==12 and g.scenarios.cargo(state.ship().ship_instance_id).volume==720,"task cargo contributes its real volume")
	check(g.scenarios.guidance("blockade","blockade_echo").waypoint_id.ends_with("blockade_echo_survey_0"),"new corridor guidance begins at the first safe survey node")
	if not preserve(2,"active finite blockade cargo"):await finish();return
	block=g.scenarios.instance("blockade","blockade_echo")
	for index: int in [0,1]:
		place(g.scenarios.node_definition("blockade_echo",index).anchor_id)
		state.ship().energy=float(g.metrics(state.ship()).energy_max);state.ship().heat=0;state.ship().overheated=false
		check(scenario("blockade","blockade_echo","survey",index),"actual scanner pays node survey "+str(index))
		step(20)
		check(g.scenarios._node("blockade_echo",index).completed,"actual node completes within paid cycle")
	check(block.bypass_remaining_s>0,"two independent surveys open a finite route window")
	check(g.scenarios.guidance("blockade","blockade_echo").waypoint_id.ends_with("blockade_echo_exit"),"opened survey route guides directly to the actual exit")
	check(g.scenarios.node_label("blockade_echo",2)=="封锁中继 1" and g.scenarios.node_label("blockade_echo",3)=="封锁中继 2","relay numbering is readable independently from survey numbering")
	place("blockade_echo_exit");check(scenario("blockade","blockade_echo","exit"),"physical exit banks actual cargo")
	at_station("station_echo_depot");check(scenario("blockade","blockade_echo","claim"),"real signing station pays actual delivered units")
	check(state.rows("blockade_result_state").size()==1 and state.rows("tactical_award_state").size()==2,"full delivery awards once")
	stamp=full_signature(state,false);check(not scenario("blockade","blockade_echo","claim") and full_signature(state,false)==stamp,"blockade reward cannot be replayed")
	var world_tick: int=state.snapshot.meta.simulation_tick;var rng: String=JSON.stringify(Codec.new().encode_row("rng_state",state.rows("rng_state")[0]))
	g.journal.presentation(2,"reports",true,false)
	check(state.snapshot.meta.simulation_tick==world_tick and JSON.stringify(Codec.new().encode_row("rng_state",state.rows("rng_state")[0]))==rng,"focused menu measurement advances neither world nor RNG")
	check(state.find("telemetry_menu_state","page_id","reports").duration_s==2,"presentation duration is independently measured")
	stamp=full_signature(state);var exported: Dictionary=g.journal.export_data();check(full_signature(state)==stamp and not exported.activities.is_empty(),"activity export is pure and contains actual outcomes")
	if not preserve(3,"all99 tactical and measurement groups"):await finish();return
	await scenario_edges()
	await finish()
func managed(id: String,role: String) -> RefCounted:
	for member: RefCounted in state.rows("scenario_actor_state"):
		if member.scenario_id==id and member.actor_role==role:return state.find("npc_state","npc_instance_id",member.npc_instance_id)
	return null
func scenario_edges() -> void:
	# Arrival, cooldown boundaries and funds are explicit fixtures. Completion,
	# fees, remote repair, damage and settlement still use production actions.
	hull("frigate_kestrel");fit("module_kinetic_needle_ii","weapon:0");at_station("station_echo_depot")
	check(scenario("trial","trial_escort","accept"),"escort accepts an explicitly allowed ordinary hull")
	place("trial_escort_entry");check(scenario("trial","trial_escort","start"),"escort creates one friendly convoy and actual raiders")
	var convoy: RefCounted=managed("trial_escort","escort")
	check(convoy!=null and g.civilizations.friendly(convoy.npc_instance_id),"managed convoy is available to normal friend recognition")
	g.damage_npc(convoy.npc_instance_id,Vector3(100000,0,0))
	check(g.scenarios.instance("trial","trial_escort").phase=="failed" and state.rows("scenario_actor_state").is_empty(),"actual convoy loss records failure and cleans managed actors")
	g.scenarios.instance("trial","trial_escort").cooldown_remaining_s=0
	at_station("station_echo_depot");check(scenario("trial","trial_escort","accept"),"failed escort may retry after declared cooldown boundary")
	place("trial_escort_entry");check(scenario("trial","trial_escort","start"),"retry starts a new actor generation")
	convoy=managed("trial_escort","escort");var exit: Dictionary=g.definition("anchor_defs","anchor_id","trial_escort_exit")
	convoy.pos_x=exit.x_m;convoy.pos_y=exit.y_m;convoy.pos_z=exit.z_m;step(0.1)
	check(g.scenarios.instance("trial","trial_escort").phase=="ready","declared convoy arrival is consumed by the real escort completion rule")
	at_station("station_echo_depot");check(scenario("trial","trial_escort","claim"),"escort success records one new result and title")
	hull("support_weaver");var patch: String=fit("module_support_patch_i","work:0")
	g.inventory.grant(g.inventory.hold(state.ship(),T.ContainerKind.CARGO),"repair_kit_i",8)
	at_station("station_mirror_hub");check(scenario("trial","trial_support","accept"),"support budget includes normal repair consumables")
	place("trial_support_entry");check(scenario("trial","trial_support","start"),"support starts a moving damaged friendly target")
	var patient: RefCounted=managed("trial_support","patient")
	if not check(patient!=null,"support target exists after actual start"):return
	check(apply("remote_support",patch,1,patient.npc_instance_id),"normal remote repair pays a real consumable cycle")
	step(18)
	var support: RefCounted=g.scenarios.instance("trial","trial_support")
	check(support.effective_hp>=float(g.scenarios.definition("trial","trial_support").target_hp),"only effective production remote repair meets the support quota")
	check(g.inventory.count(g.inventory.hold(state.ship(),T.ContainerKind.CARGO),"repair_kit_i",true)<8,"support attempt consumes actual finite kits")
	exit=g.definition("anchor_defs","anchor_id","trial_support_exit");patient.pos_x=exit.x_m;patient.pos_y=exit.y_m;patient.pos_z=exit.z_m;step(0.1)
	check(support.phase=="ready" and state.rows("remote_support_state").is_empty(),"arrived patient and measured repair complete together and release the channel")
	at_station("station_mirror_hub");check(scenario("trial","trial_support","claim"),"support result and title settle through the real station")
	check(apply("select_tactical_award","award_support") and g.scenarios.title()==g.definition("tactical_award_defs","award_id","award_support").display_name,"earned title can be selected through the normal action")
	if not preserve(1,"all three trial outcomes and selected title"):return
	hull("transport_caravan");fit("module_kinetic_needle_ii","weapon:0");at_station("station_mirror_hub")
	check(scenario("blockade","blockade_mirror","accept"),"second corridor signs a distinct paid order")
	place("blockade_mirror_entry");check(scenario("blockade","blockade_mirror","start"),"second corridor loads its own real cargo")
	var block: RefCounted=g.scenarios.instance("blockade","blockade_mirror");var relay: RefCounted=managed("blockade_mirror","relay")
	state.ship().pos_x=relay.pos_x;state.ship().pos_y=relay.pos_y;state.ship().pos_z=relay.pos_z+1200;state.ship().vel_z=100;step(0.1)
	check(block.alerted and g.scenarios.field_active("blockade_mirror") and not g.scenarios.navigation_reason().is_empty(),"real relay range and loud motion activate bounded blockade")
	state.ship().vel_z=0;g.damage_ship(Vector3(180,0,0))
	check(block.lost_units>0 and block.cargo_units>0,"actual combat damage creates finite cargo loss while retaining partial success")
	check(scenario("blockade","blockade_mirror","jettison") and block.jettisoned_units==1,"normal jettison removes exactly one finite unit")
	for member: RefCounted in state.rows("scenario_actor_state").duplicate():
		if member.scenario_id=="blockade_mirror" and member.actor_role=="relay":g.damage_npc(member.npc_instance_id,Vector3(100000,0,0),Vector3(100000,0,0))
	check(g.scenarios.relays_open("blockade_mirror") and not g.scenarios.field_active("blockade_mirror") and g.scenarios.navigation_reason().is_empty(),"actual destruction of both relays removes their field and navigation denial")
	var remaining: int=block.cargo_units;g.damage_ship(Vector3(20,0,0));check(block.cargo_units==remaining,"destroyed relays no longer impose special cargo loss")
	place("blockade_mirror_exit");check(scenario("blockade","blockade_mirror","exit"),"partial physical exit banks only surviving cargo")
	at_station("station_mirror_hub");var credit: int=state.player().credit
	check(scenario("blockade","blockade_mirror","claim") and state.player().credit==credit+remaining*int(g.scenarios.definition("blockade","blockade_mirror").credit_per_unit),"partial station reward matches actual remaining units")
	check(state.find("tactical_award_state","award_id","award_blockade_mirror")==null,"partial result cannot earn a full-delivery title")
	if not preserve(2,"partial relay-route result and cargo conservation"):return
	var records: int=state.rows("activity_record_state").size();var limit: int=int(g.rows("telemetry_policy_defs")[0].record_limit)
	for index: int in range(limit+3):
		g.journal.begin("operation","bounded-fixture:"+str(index));g.journal.finish("operation","bounded-fixture:"+str(index),"withdrawn","manual")
	check(state.rows("activity_record_state").filter(func(r: RefCounted):return r.phase=="finished").size()==limit,"retained finished history is bounded without trimming active work")
	var totals: String=JSON.stringify(g.journal.export_data().activity_totals)
	g.journal.finish("operation","bounded-fixture:0","withdrawn","manual")
	check(JSON.stringify(g.journal.export_data().activity_totals)==totals,"duplicate callback after history pruning cannot inflate lifetime totals")
	var count: int=state.rows("telemetry_source_state").size();g.inventory.grant(g.inventory.warehouse(g.station()),"ore_ferrosilicate",1)
	check(state.rows("telemetry_source_state").size()==count,"generic fixture grants are never reported as production")
	var menu: RefCounted=state.find("telemetry_menu_state","page_id","reports");var duration: float=menu.duration_s
	g.journal.presentation(10,"reports",false,true);check(menu.duration_s==duration,"unfocused windows do not accumulate menu time")
	g.journal.presentation(1,"reports",true,true);check(state.rows("telemetry_timing_state")[0].navigation_wait_s==1,"navigation waiting uses its independent presentation clock")
	check(records>0 and state.rows("activity_total_state").size()>0,"actual trial and corridor outcomes feed cumulative local measurement")
	if not preserve(3,"bounded recent history and retained lifetime totals"):return
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":XJRuntimeState.TABLES.size(),"fleet_rules":v42_fleet_rules}
	print("SCENARIOS_V39_FINAL_JSON ",JSON.stringify(summary));print("SCENARIOS_V39_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
