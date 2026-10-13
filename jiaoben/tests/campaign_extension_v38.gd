extends "campaign_v37.gd"
## Named variants, money, initial HP deficits and arrival poses are fixtures.
## Fees, all three stage claims, real mining cycles, refunds and SQL are real APIs.
var routes_completed: int=0
var mineral_cycles: int=0
func _ready() -> void:
	get_tree().set_meta("xj_campaign_extension_v38_diagnostic",true)
	get_tree().create_timer(600.0).timeout.connect(func():print("CAMPAIGN_EXTENSION_V38_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func _run() -> void:
	directory=OS.get_environment("XJ_CAMPAIGN_EXTENSION_V38_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/campaign-extension-v38/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped route and metric world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format23 append opens "+store.last_error):await finish();return
	state=store.new_world("完整路线与实耗",3801)
	if not check(state!=null,"new87-group world seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==114 and state.rows("telemetry_material_state").is_empty() and state.rows("telemetry_repair_state").is_empty(),"no invented historic material or repair measurements")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=1000000;g.missions.refresh();g._sync_spawns();hull("transport_caravan");fit("module_scanner_beacon_i","utility:0");at_station("station_mirror_hub")
	check(expedition("route_relief","start","relief"),"complete-route fixture pays normal preparation")
	var run: RefCounted=g.expeditions.active()
	complete_event("exp_theme_frontier_01_rescue")
	check(run.phase=="checkpoint" and run.stage_index==1,"first actual full segment banks at its real station")
	check(expedition(run.run_id,"continue","relief"),"normal checkpoint accepts second segment")
	complete_event("exp_theme_frontier_02_rescue")
	check(run.phase=="checkpoint" and run.stage_index==2,"second actual full segment banks independently")
	check(expedition(run.run_id,"continue","archive"),"normal checkpoint accepts deepest segment")
	complete_event("exp_theme_frontier_03_relic")
	check(run.phase=="completed" and run.stage_index==3 and g.expeditions.active()==null,"third actual claim completes the whole expedition")
	check(g.state.find("expedition_route_state","route_id","route_relief").completed_runs==1,"route completion counter records exactly one full run")
	var payments: int=0;var final_count: int=0
	for receipt: RefCounted in state.rows("expedition_receipt_state"):
		if receipt.run_id!=run.run_id:continue
		if receipt.action_kind=="stage":payments+=1
		if receipt.action_kind=="complete":final_count+=1
	check(payments==3 and final_count==1,"three finite segment payments and one terminal outcome only")
	routes_completed=1
	if not preserve(1,"completed full three-stage route"):await finish();return
	# Execute all three real locations of both newly authored mobile belts using
	# the maintained extraction/decay/renewal suite (explicit arrival fixtures).
	hull("miner_anvil")
	var helper: Node=(load(get_script().resource_path.get_base_dir().path_join("mobile_belts_v28.gd")) as Script).new()
	helper.g=g;helper.state=state;helper.store=store;helper.directory=directory
	helper.connect_warnings()
	for event_id: String in ["exp_theme_frontier_02_mineral","exp_theme_frontier_03_mineral"]:
		for index: int in range(3):
			await helper.cycle(event_id,index)
			g=helper.g;state=helper.state;store=helper.store;mineral_cycles+=1
			if not helper.failures.is_empty():break
	check(helper.failures.is_empty() and helper.cases==6,"both theme belts execute all three AU locations without nested failures")
	helper.g=null;helper.state=null;helper.store=null;helper.free()
	if not preserve(2,"six theme mineral routes and accumulated ore"):await finish();return
	hull("frigate_kestrel");at_station("station_anchor_port")
	check(apply("undock"),"real undock starts a measured outing")
	var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port")
	var warehouse: String=g.inventory.warehouse(home.station_id)
	place(home.station_anchor_id,home.station_id);g.telemetry.finish()
	var ship: RefCounted=state.ship();var limits: Dictionary=g.metrics(ship)
	ship.armor=float(limits.armor_max)-12;ship.hull=float(limits.hull_max)-8
	g.inventory.grant(warehouse,"material_structural_stock",100)
	check(apply("repair"),"real station repair consumes fee and structural units")
	check(is_equal_approx(float(state.find("telemetry_repair_state","repair_kind","station").restored_hp),20.0),"repair measures actual missing HP rather than module maximum")
	var consumed: RefCounted=state.find("telemetry_material_state","item_id","material_structural_stock")
	if not check(consumed!=null and consumed.used_units>0,"real repair consumption creates material measurement"):await finish();return
	var before: int=consumed.used_units
	check(g.inventory.consume(warehouse,"material_structural_stock",5,true),"ordinary actual resource use succeeds")
	check(consumed.used_units==before+5,"actual removed units contribute once")
	before=consumed.used_units
	check(g.inventory.consume(warehouse,"material_structural_stock",1,true,"",false) and consumed.used_units==before,"delivered/transferred resources can remain separate from production cost")
	check(not g.inventory.consume(warehouse,"material_structural_stock",100000,true) and consumed.used_units==before,"failed resource request creates no fake cost")
	check(not g.inventory.consume(warehouse,"material_structural_stock",-1,true) and consumed.used_units==before,"negative resource request is rejected without recording cost")
	var blueprint: Dictionary={}
	for def: Dictionary in g.rows("industry_recipe_defs"):
		if def.recipe_id=="recipe_engine_vector_i":blueprint=def;break
	if blueprint.is_empty():
		for recipe: Dictionary in g.rows("recipe_defs"):
			if recipe.output_item_id=="module_engine_vector_i":blueprint=g.definition("industry_recipe_defs","blueprint_id",recipe.recipe_id);break
	if not check(not blueprint.is_empty(),"actual accessible recipe supplies refund measurement"):await finish();return
	for item: String in g.industry.inputs(blueprint.blueprint_id,1):g.inventory.grant(warehouse,item,int(g.industry.inputs(blueprint.blueprint_id,1)[item])*2)
	check(apply("manufacture",blueprint.blueprint_id,1) and apply("manufacture",blueprint.blueprint_id,1),"real queue escrows two independent material batches")
	var job: RefCounted=state.rows("industry_job_state")[-1]
	check(apply("cancel_industry",job.job_id),"actual queued cancellation returns the valid input ledger")
	var refund_seen: bool=false
	for row: RefCounted in state.rows("telemetry_material_state"):
		if row.returned_units>0:refund_seen=true
	check(refund_seen,"actual material refund is visible separately from initial investment")
	hull("support_weaver")
	var patch: String=fit("module_support_patch_i","work:0")
	var cargo: String=g.inventory.hold(state.ship(),T.ContainerKind.CARGO)
	g.inventory.grant(cargo,"repair_kit_i",2)
	check(apply("undock"),"self repair starts from an actual undock")
	state.ship().armor=float(g.metrics(state.ship()).armor_max)-7.0
	step(float(g.definition("module_defs","module_id","module_support_patch_i").cycle_s)+0.2)
	var self_repair: RefCounted=state.find("telemetry_repair_state","repair_kind","self")
	check(not patch.is_empty() and self_repair!=null and is_equal_approx(float(self_repair.restored_hp),7.0),"self repair measures the actual seven HP deficit rather than sixty nominal HP")
	var signature: String=full_signature(state);var reports: Array[Dictionary]=g.telemetry.export_rows()
	var lifetime: Dictionary=g.telemetry.export_total()
	check(not reports.is_empty() and reports[0].has("materials_used") and reports[0].has("materials_returned") and reports[0].has("repair_hp"),"export envelope contains measured typed detail")
	check(not lifetime.materials_used.is_empty() and not lifetime.materials_returned.is_empty() and lifetime.repair_hp.station==20.0 and lifetime.repair_hp.self==7.0,"lifetime export retains measured input refunds and effective repair")
	check(full_signature(state)==signature,"report materialization changes no state or RNG")
	if not preserve(3,"material refunds and measured repair"):await finish();return
	# Real command boundaries test bounded history and child-row cleanup.
	for index: int in range(int(g.rows("campaign_balance_defs")[0].report_limit)+1):
		at_station(home.station_id);apply("undock");place(home.station_anchor_id)
		check(apply("dock",home.station_id),"actual subsequent docking finalizes outing "+str(index))
	check(state.rows("flight_record_state").size()<=int(g.rows("campaign_balance_defs")[0].report_limit),"retained outing count obeys catalog policy")
	var retained: Dictionary=g.telemetry.export_total()
	check(retained.materials_used==lifetime.materials_used and retained.materials_returned==lifetime.materials_returned and retained.repair_hp==lifetime.repair_hp,"pruning outing history does not remove cumulative measurements from export")
	if not preserve(3,"pruned report child rows and lifetime totals"):await finish();return
	await finish()
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"groups":XJRuntimeState.TABLES.size(),"routes_completed":routes_completed,"mineral_cycles":mineral_cycles}
	print("CAMPAIGN_EXTENSION_V38_FINAL_JSON ",JSON.stringify(summary));print("CAMPAIGN_EXTENSION_V38_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
