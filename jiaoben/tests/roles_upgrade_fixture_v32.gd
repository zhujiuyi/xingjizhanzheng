extends "fitting_v31.gd"
## Runs in the actual v0.23 PCK; retains real paid jobs and partial research.
func _ready() -> void:
	get_tree().set_meta("xj_fitting_v31_diagnostic",true)
	_run.call_deferred()
func _run() -> void:
	directory=OS.get_environment("XJ_FITTING_V31_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/fitting-v31/") and not FileAccess.file_exists(directory.path_join("progress.db")),"isolated actual-package legacy fixture"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"actual v0.23 store opens"):get_tree().quit(1);return
	state=store.new_world("v0.23角色升级夹具",3216)
	if not check(state!=null,"actual v0.23 world creates"):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	for unlock: Dictionary in g.rows("unlock_defs"):
		if not str(unlock.unlock_id).begins_with("unlock_spec_"):g.grant_unlock(unlock.unlock_id)
	g.missions.refresh();g._sync_spawns();state.player().credit=1000000
	var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port")
	var ship: RefCounted=g.inventory.create_ship("support_weaver",home.station_id)
	state.player().controlled_ship_id=ship.ship_instance_id;place(home.station_anchor_id,home.station_id)
	var warehouse: String=g.inventory.warehouse(home.station_id)
	g.inventory.grant(warehouse,"material_structural_stock",100)
	check(apply("specialization_donate","",5),"real materials and fee create old analysis points")
	check(apply("specialization_research","spec_sustain",3,"0"),"old paid partial research remains unfinished")
	for output: String in ["module_engine_vector_i","module_scanner_beacon_i","module_shield_lattice_i"]:
		var recipe: Dictionary={}
		for spec: Dictionary in g.rows("recipe_defs"):
			if spec.output_item_id==output:recipe=spec;break
		for input: Dictionary in g.rows("recipe_inputs"):
			if input.recipe_id==recipe.recipe_id:g.inventory.grant(warehouse,input.item_id,int(input.quantity))
		check(apply("manufacture",recipe.recipe_id,1),"actual paid old industrial order "+output)
	var third: RefCounted=state.rows("industry_job_state")[-1]
	check(apply("cancel_industry",third.job_id),"actual old queue cancellation retains its refund receipt")
	var bay: String=g.inventory.grant(warehouse,"module_drone_swarm_ii",1)[0]
	check(apply("fit_module",bay,1,"weapon:0"),"actual old qualified support installs a drone bay")
	check(store.save(state,"manual",1),"actual old paid world seals "+store.last_error)
	await finish()
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	print("ROLES_LEGACY_FIXTURE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
