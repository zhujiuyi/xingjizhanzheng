extends "honors_v33.gd"
## Funds, unlocks, membership, examination poses/variants and damage are explicit
## fixtures. Marching below uses full gameplay ticks with unloaded coarse motion;
## actual body movement, GUI and pause belong to the separate native suite.
const Signature=preload("snapshot_signature.gd")
var originals: Dictionary={}
var mixed_saved: bool=false
var gate_passages: int=0
var return_checked: bool=false
var loss_checked: bool=false
var growth_checked: bool=false
var last_phase: String=""

func _ready() -> void:
	get_tree().set_meta("xj_march_v49_diagnostic",true)
	get_tree().create_timer(900.0).timeout.connect(func():check(false,"march watchdog");finish())
	_run.call_deferred()

func retain(index: int,label: String) -> bool:
	if not check(store.save(state,"manual",index),label+" seals "+store.last_error):return false
	var expected: String=Signature.saved(store,state.snapshot.meta.snapshot_id)
	var slot: String=saved_slot(index)
	g.dispose();g=null;state=store.load(slot)
	if not check(state!=null,label+" loads "+store.last_error):return false
	check(Signature.runtime(state)==expected,label+" preserves every114 group including RNG")
	g=Gameplay.new();g.setup(state,store.catalog)
	return true

func restore(index: int) -> bool:
	var slot: String=saved_slot(index)
	g.dispose();g=null;state=store.load(slot)
	if not check(state!=null,"branch restores manual "+str(index)+" "+store.last_error):return false
	g=Gameplay.new();g.setup(state,store.catalog);last_phase=""
	return true

func advance_until(condition: Callable,seconds: float) -> bool:
	var dt: float=1.0/g.rule("simulation_hz")
	for index: int in range(ceili(seconds/dt)):
		if condition.call():return true
		g.tick(dt)
		var row: RefCounted=g.march.state_for("war_council_01")
		if row!=null:
			var phase: String="%s:%d:%d:%s" % [row.phase,row.completed_legs,row.direction,row.gate_actor_id]
			if phase!=last_phase:
				last_phase=phase;print("MARCH_MILESTONE ",JSON.stringify({"phase":row.phase,"leg":row.completed_legs,"direction":row.direction,"sector":row.sector_id,"actor":row.gate_actor_id}))
		if index%120==0:await get_tree().process_frame
	return bool(condition.call())

func mixed() -> bool:
	var contexts: Dictionary={}
	var row: RefCounted=g.march.state_for("war_council_01")
	if row==null:return false
	for m: RefCounted in g.march.members(row,true):contexts[m.sector_id]=true
	return contexts.size()>1

func _run() -> void:
	directory=OS.get_environment("XJ_MARCH_V49_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/march-v49/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh isolated march world"):await finish();return
	store=FaultStore.new(directory.path_join("progress.db"))
	if not check(store.open(),"format26 opens "+store.last_error):await finish();return
	state=store.new_world("行军与成长专项",4901)
	if not check(state!=null,"current world seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(g.march.supported() and g.growth.supported() and XJRuntimeState.TABLES.size()==114,"new rules and all114 groups are active")
	check(g.rows("march_campaign_defs").size()==24 and g.rows("growth_stage_defs").size()==41,"all24 war itineraries and41 growth stages exist")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=1000000;g.missions.refresh();g._sync_spawns();hull("transport_caravan");fit("module_scanner_beacon_i","utility:0")
	var faction: String="faction_route_council";qualified_faction(faction)
	var scout_task: String=str(task(faction,"scout").task_id)
	var rescue_task: String=str(task(faction,"rescue").task_id)
	var stale: String=g.growth.grant_token(scout_task);var before: int=state.player().credit
	check(not apply("growth_claim",scout_task,1,stale) and state.player().credit==before,"unearned outfitting claim changes no funds")
	check(apply("honor_action",faction,1,"register:unregistered"),"actual commander registration")
	complete_event("exp_mirror_relic");complete_event("exp_echo_rescue");freight(6);demolition();at_capital(faction)
	check(apply("honor_action",faction,1,"certify:assessing"),"four paid/settled examination sources certify")
	check(not apply("growth_claim",scout_task,1,stale),"stale progress token is rejected")
	var grant: Dictionary=g.definition("growth_grant_defs","task_id",scout_task)
	before=state.player().credit;var rep: int=g.growth.reputation(faction)
	check(not apply("growth_claim",scout_task,2,g.growth.grant_token(scout_task)),"grant rejects a batch quantity")
	check(apply("growth_claim",scout_task,1,g.growth.grant_token(scout_task)),"earned grant is claimed through actual action")
	check(state.player().credit==before+int(grant.reward_credit) and g.growth.reputation(faction)==rep+int(grant.reward_reputation),"grant pays exactly the frozen cash and reputation")
	before=state.player().credit
	check(not apply("growth_claim",scout_task,1,g.growth.grant_token(scout_task)) and state.player().credit==before,"grant cannot be claimed twice")
	if not retain(1,"earned grant checkpoint"):await finish();return
	var original: String=Signature.runtime(state)
	var candidate: XJRuntimeState=store.clone_state(state);var actor: RefCounted=Gameplay.new();actor.setup(candidate,store.catalog)
	check(actor.act("growth_claim",rescue_task,1,actor.growth.grant_token(rescue_task)).phase==T.ActionPhase.APPLIED,"second grant prepares on detached state")
	actor.dispose();actor=null;(store as FaultStore).failure="pointer"
	check(not store.save(candidate,"auto",0),"pointer failure rolls back staged grant")
	(store as FaultStore).failure=""
	check(Signature.runtime(state)==original,"failed grant leaves live funds proof and milestones unchanged")
	candidate=null
	if not restore(1):await finish();return
	check(state.find("growth_grant_receipt_state","task_id",rescue_task)==null,"failed grant was not published in the saved world")
	check(apply("growth_claim",rescue_task,1,g.growth.grant_token(rescue_task)),"failed grant can be retried once")
	check(apply("growth_select",faction+"_register"),"explicit growth selection is saved state")
	growth_checked=await retain(1,"growth selection and retry")
	if not growth_checked:await finish();return
	var warehouse: String=g.inventory.warehouse(g.station())
	var supplies: int=int(g.frontier.balance.supply_units)
	g.inventory.grant(warehouse,g.frontier.balance.material_id,supplies)
	var stocked: int=g.inventory.count(warehouse,g.frontier.balance.material_id,true)
	check(apply("start_war","war_council_01"),"capital accepts funded new war")
	var march: RefCounted=g.march.state_for("war_council_01")
	if not check(march!=null and march.phase=="assembling","new war creates persistent march"):await finish();return
	check(g.inventory.count(warehouse,g.frontier.balance.material_id,true)==stocked-supplies,"war escrows exactly one supply manifest")
	for m: RefCounted in g.march.members(march,true):
		var npc: RefCounted=state.find("npc_state","npc_instance_id",m.npc_instance_id)
		check(npc.sector_id=="sector_council_01" and npc.alive,"original ally starts at actual capital")
		originals[npc.npc_instance_id]={"generation":npc.generation,"shield":npc.shield,"armor":npc.armor,"hull":npc.hull}
	var target: String=str(originals.keys()[1])
	check(g.damage_npc(target,Vector3(20,0,0))>0,"declared damage fixture uses actual resistance pipeline")
	var damaged: RefCounted=state.find("npc_state","npc_instance_id",target);originals[target].shield=damaged.shield
	if not retain(0,"funded original actors"):await finish();return
	var spec: Dictionary=g.frontier.definition("war_council_01")
	place(spec.scout_anchor_id);cold()
	check(apply("frontier_action","war_council_01",1,"survey:"+g.frontier.expected_token("war_council_01")),"player can pay and scout while fleet is still travelling")
	check(await advance_until(func():return g.frontier.campaign("war_council_01").survey_remaining_s<=0.0,90.0),"parallel reconnaissance completes")
	check(g.frontier.campaign("war_council_01").phase=="scouting" and g.march.active(g.march.state_for("war_council_01")),"completed preparation waits for actual fleet arrival")
	at_capital(faction)
	check(await advance_until(mixed,300.0),"gate queue creates a real intermediate split between two systems")
	if not mixed():await finish();return
	mixed_saved=await retain(2,"mixed gate queue")
	check(mixed(),"mixed queue survives a complete save/load")
	check(await advance_until(func():return g.march.state_for("war_council_01").phase=="arrived",600.0),"original fleet reaches the destination through its full route")
	march=g.march.state_for("war_council_01")
	check(g.frontier.campaign("war_council_01").phase=="escorting","precompleted survey advances after arrival without repeating the survey")
	for id: String in originals:
		var npc: RefCounted=state.find("npc_state","npc_instance_id",id)
		check(npc!=null and npc.generation==originals[id].generation and npc.shield==originals[id].shield and npc.armor==originals[id].armor and npc.hull==originals[id].hull,"original identity and damage survive route "+id)
		var actual: Array[String]=[];var expected: Array[String]=[]
		for event: RefCounted in state.rows("march_journal_state"):
			if event.war_id==march.war_id and event.attempt==march.attempt and event.event_kind=="gate" and event.npc_instance_id==id:actual.append(event.endpoint_id)
		for leg: Dictionary in g.march.route(march):expected.append(str(leg.endpoint_id))
		check(actual==expected,"each original member crosses each actual gate in order")
		gate_passages+=actual.size()
	check(march.transferred_supply_units==supplies and march.returned_supply_units==0 and march.lost_supply_units==0,"supplies reach the real destination once")
	if not retain(3,"arrived fleet and paid preparation"):await finish();return
	if not restore(0):await finish();return
	check(await advance_until(mixed,300.0),"second branch reaches a partial queue")
	check(apply("fleet_command","retreat"),"partial gate queue accepts withdrawal")
	check(g.march.state_for("war_council_01").retreat_requested,"partial queue reunites before reversing")
	check(await advance_until(func():return g.march.state_for("war_council_01").direction==-1 and mixed(),300.0),"return also queues original ships individually")
	if not retain(2,"mixed return queue"):await finish();return
	check(await advance_until(func():return g.civilizations.active_war()==null,600.0),"withdrawal physically traverses the return itinerary")
	march=g.march.state_for("war_council_01")
	var refunded: int=floori(supplies*float(g.march.balance.return_supply_ratio))
	return_checked=check(march.phase=="returned" and march.completed_legs==0 and march.sector_id=="sector_council_01" and march.returned_supply_units==refunded and march.lost_supply_units==supplies-refunded,"return ends at capital with only the authorised unused-supply refund")
	check(g.inventory.count(g.inventory.warehouse("station_council_01"),g.frontier.balance.material_id,true)==stocked-supplies+refunded,"return deposits actual remaining material once")
	check(state.rows("march_member_state").is_empty(),"finished march releases actor bindings before roster removal")
	if not retain(4,"completed withdrawal"):await finish();return
	if not restore(0):await finish();return
	march=g.march.state_for("war_council_01")
	var carrier: RefCounted=null
	for m: RefCounted in g.march.members(march):
		if m.cargo_units>0:carrier=state.find("npc_state","npc_instance_id",m.npc_instance_id)
	check(carrier!=null and g.damage_npc(carrier.npc_instance_id,Vector3(1000000,0,0))>0,"declared lethal fixture destroys the original supply carrier")
	loss_checked=check(g.civilizations.active_war()==null and march.phase=="failed" and march.lost_supply_units==supplies and march.returned_supply_units==0,"carrier loss fails without refund or replacement")
	check(state.rows("march_member_state").is_empty(),"loss leaves no orphan march actor references")
	if not retain(4,"carrier-loss outcome"):await finish();return
	await finish()

func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"groups":XJRuntimeState.TABLES.size(),"directory":directory,"mixed_saved":mixed_saved,"gate_passages":gate_passages,"return_checked":return_checked,"loss_checked":loss_checked,"growth_checked":growth_checked,"scope":"explicit funds/qualification/poses/variants/damage fixtures; actual business, SQL and full gameplay ticks; unloaded macro movement, not native body or natural-growth evidence"}
	print("MARCH_V49_FINAL_JSON ",JSON.stringify(summary));print("MARCH_V49_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
