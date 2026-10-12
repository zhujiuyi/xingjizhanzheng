extends "exploration_v27.gd"
## Explicit funds/hull/equipment fixtures; actual fits, payment cycles and all 56 groups.
func _ready() -> void:
	if OS.get_environment("XJ_SCENARIOS_UPGRADE_FIXTURE")=="1":
		var fixture: Node=(load(get_script().resource_path.get_base_dir().path_join("scenarios_upgrade_fixture_v39.gd")) as Script).new()
		get_tree().root.add_child(fixture);return
	if OS.get_environment("XJ_CAMPAIGN_UPGRADE_FIXTURE")=="1":
		var fixture: Node=(load(get_script().resource_path.get_base_dir().path_join("campaign_upgrade_fixture_v37.gd")) as Script).new()
		get_tree().root.add_child(fixture);return
	if OS.get_environment("XJ_SITUATIONAL_UPGRADE_FIXTURE")=="1":
		var fixture_path: String=get_script().resource_path.get_base_dir().path_join("situational_upgrade_fixture_v36.gd")
		var fixture: Node=(load(fixture_path) as Script).new();get_tree().root.add_child(fixture)
		return
	if OS.get_environment("XJ_FRONTIER_UPGRADE_FIXTURE")=="1":
		var fixture_path: String=get_script().resource_path.get_base_dir().path_join("frontier_upgrade_fixture_v34.gd")
		var fixture: Node=(load(fixture_path) as Script).new();get_tree().root.add_child(fixture)
		return
	if OS.get_environment("XJ_HONOR_UPGRADE_FIXTURE")=="1":
		var fixture_path: String=get_script().resource_path.get_base_dir().path_join("honors_upgrade_fixture_v33.gd")
		var fixture: Node=(load(fixture_path) as Script).new();get_tree().root.add_child(fixture)
		return
	if OS.get_environment("XJ_ROLE_UPGRADE_FIXTURE")=="1":
		# The release CLI still enters its fixed reviewed test Node and UUID
		# directory; this opt-in delegate only prepares an older paid world.
		var fixture_path: String=get_script().resource_path.get_base_dir().path_join("roles_upgrade_fixture_v32.gd")
		var fixture: Node=(load(fixture_path) as Script).new();get_tree().root.add_child(fixture)
		return
	get_tree().set_meta("xj_fitting_v31_diagnostic",true)
	get_tree().create_timer(420.0).timeout.connect(func():print("FITTING_V31_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
const CAMPAIGN_STATE_ADDITIONS: Array[String]=["construction_state","construction_input_state","construction_receipt_state","construction_evidence_state","expedition_route_state","expedition_run_state","expedition_stage_state","expedition_receipt_state","campaign_director_state","flight_record_state","telemetry_total_state","flight_material_state","telemetry_material_state","flight_repair_state","telemetry_repair_state","trial_state","trial_result_state","scenario_actor_state","tactical_award_state","blockade_state","blockade_node_state","blockade_result_state","telemetry_source_state","activity_record_state","telemetry_menu_state","telemetry_timing_state","activity_total_state"]
func campaign_added_row(table: String,row: RefCounted) -> bool:
	if table in ["exploration_instance_state","exploration_belt_state"]:return str(row.event_id).begins_with("exp_theme_")
	if table=="resource_state":return str(row.node_id).begins_with("exp_theme_")
	if table=="tactical_site_state":return str(row.site_id).begins_with("tac_exp_theme_")
	return false
func full_signature(value: XJRuntimeState,receipts: bool=true) -> String:
	var data: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		if not receipts and table=="action_receipt_state":continue
		var rows: Array=[]
		for row: RefCounted in value.rows(table):rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func apply(action: String,target: String="",quantity: int=1,extra: String="") -> bool:return g.act(action,target,quantity,extra).phase==T.ActionPhase.APPLIED
func _run() -> void:
	directory=OS.get_environment("XJ_FITTING_V31_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/fitting-v31/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh isolated fit/research world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format16 opens "+store.last_error):get_tree().quit(1);return
	state=store.new_world("配装比较与火控研究",3101)
	if not check(state!=null,"new research ledger seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(g.specializations.available()==0 and state.rows("specialization_progress_state").size()==1,"new player gains no free research")
	for unlock: Dictionary in g.rows("unlock_defs"):
		if not str(unlock.unlock_id).begins_with("unlock_spec_"):g.grant_unlock(unlock.unlock_id)
	g.missions.refresh();g._sync_spawns()
	state.player().credit=1000000
	var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port")
	var ship: RefCounted=g.inventory.create_ship("battleship_bastion",home.station_id);state.player().controlled_ship_id=ship.ship_instance_id;place(home.station_anchor_id,home.station_id)
	var warehouse: String=g.inventory.warehouse(home.station_id)
	g.inventory.grant(warehouse,"material_structural_stock",1000)
	_research(home)
	var weapon: String="module_kinetic_siege_iii"
	for index: int in range(4):
		var id: String=g.inventory.grant(warehouse,weapon if index<3 else "module_thermal_sunline_iii",1)[0]
		check(apply("fit_module",id,1,"weapon:"+str(index)),"real fitting installs stress weapon")
	var ammunition: Dictionary=g.definition("weapon_defs","module_id",weapon)
	if ammunition.ammo_item_id!=null:g.inventory.grant(g.inventory.hold(ship,T.ContainerKind.CARGO),ammunition.ammo_item_id,10000)
	var controls: Dictionary={}
	for kind: String in ["burst","sustain","range"]:controls[kind]=g.inventory.grant(warehouse,"module_spec_"+kind,1)[0]
	var before: String=full_signature(state)
	var base: Dictionary=g.fitting_analysis.report(1000.0,"tac_siege","shield")
	check(base.ok and base.weapons.size()==4 and base.nominal_dps>0,"actual fitted weapons generate resource report")
	check(full_signature(state)==before,"report does not mutate assets receipts RNG or time")
	var quotes: Dictionary={}
	for kind: String in controls:
		quotes[kind]=g.fitting_analysis.quote(controls[kind],"utility:0",1000.0,"tac_siege","shield")
		check(quotes[kind].ok,"legal specialization quote "+kind+" "+str(quotes[kind].get("reason","")))
	check(full_signature(state)==before,"three projected real fits leave all 56 groups unchanged")
	check(quotes.burst.preview.nominal_dps>base.nominal_dps and quotes.burst.preview.weapons[0].range_m<base.weapons[0].range_m and quotes.burst.preview.energy_rate>base.energy_rate and quotes.burst.preview.heat_rate>base.heat_rate,"burst pays range capacitor and heat costs")
	check(quotes.sustain.preview.energy_rate<base.energy_rate and quotes.sustain.preview.heat_rate<base.heat_rate and quotes.sustain.preview.nominal_dps<base.nominal_dps,"steady fire trades peak output for endurance")
	check(quotes.range.preview.weapons[0].range_m>base.weapons[0].range_m and quotes.range.preview.weapons[0].cone_rad<base.weapons[0].cone_rad and quotes.range.preview.nominal_dps<base.nominal_dps,"range trades firing arc and output")
	check(apply("replace_fit",controls.burst,1,"utility:0|"),"atomic application fills empty utility slot")
	var unchanged: String=full_signature(state,false)
	check(not apply("replace_fit",controls.range,1,"utility:0|") and full_signature(state,false)==unchanged,"stale old-slot identity cannot alter source assets")
	check(not apply("fit_module",controls.sustain,1,"utility:1"),"mutually exclusive controls cannot stack")
	check(apply("replace_fit",controls.sustain,1,"utility:0|"+str(controls.burst)),"occupied slot atomically replaces old normal equipment")
	check(state.find("item_instance_state","item_instance_id",controls.burst).container_id==warehouse,"old equipment returns to original station warehouse")
	_measure_resources(home)
	check(apply("replace_fit",controls.burst,1,"utility:0|"+str(controls.sustain)),"burst profile uses the same legal installation budget")
	check(g.fitting_analysis.report(1000.0).first_heat_stall_s>=0.0,"burst stress profile actually reaches a heat constraint")
	_measure_resources(home)
	_ammo_and_range(home)
	_sources(home)
	place(home.station_anchor_id,home.station_id)
	var validation: Validation=Validation.new();check(validation.validate(state,store.catalog),"all 56 groups validate "+validation.last_error)
	if check(store.save(state,"manual",0),"fit/research/evidence ledger seals "+store.last_error):
		var saved: String=full_signature(state);var slot: Dictionary
		for candidate: Dictionary in store.list_slots():
			if candidate.slot_kind=="manual" and int(candidate.slot_index)==0:slot=candidate;break
		g.dispose();g=null;state=store.load(slot.slot_id);g=Gameplay.new();g.setup(state,store.catalog)
		check(full_signature(state)==saved,"all 56 groups restore exactly")
	if not OS.get_environment("XJ_FITTING_LEGACY_DATABASE").is_empty():_legacy_fitting()
	await finish()
func _research(home: Dictionary) -> void:
	var credit: int=state.player().credit;var warehouse: String=g.inventory.warehouse(home.station_id);var materials: int=g.inventory.count(warehouse,"material_structural_stock",true)
	check(apply("specialization_donate","",3),"ordinary materials and fee create analysis points")
	check(g.specializations.available()==3 and state.player().credit==credit-600 and g.inventory.count(warehouse,"material_structural_stock",true)==materials-30,"donation deducts exact warehouse stock and credit")
	check(apply("specialization_research","spec_burst",3,"0"),"partial research consumes finite evidence")
	check(g.specializations.available()==0 and state.find("specialization_research_state","research_id","spec_burst").invested_points==3 and not g.unlocked("unlock_spec_burst"),"partial project has no premature unlock")
	check(store.save(state,"manual",1),"partial research persists "+store.last_error)
	var saved: String=full_signature(state);var slot: Dictionary
	for candidate: Dictionary in store.list_slots():
		if candidate.slot_kind=="manual" and int(candidate.slot_index)==1:slot=candidate;break
	g.dispose();g=null;state=store.load(slot.slot_id);g=Gameplay.new();g.setup(state,store.catalog)
	check(full_signature(state)==saved,"paid partial research and material provenance restore")
	check(apply("specialization_donate","",7),"alternate material source continues project")
	var before: String=full_signature(state,false)
	check(not apply("specialization_research","spec_burst",7,"0") and full_signature(state,false)==before,"stale research progress does not charge twice")
	check(apply("specialization_research","spec_burst",7,"3") and g.unlocked("unlock_spec_burst"),"accumulated project unlocks real design")
	check(not apply("specialization_research","spec_burst",1,"10"),"finished project cannot be purchased twice")
	for kind: String in ["sustain","range"]:
		check(apply("specialization_donate","",10) and apply("specialization_research","spec_"+kind,10,"0"),"independent horizontal design "+kind)
func _measure_resources(home: Dictionary) -> void:
	var forecast: Dictionary=g.fitting_analysis.report(1000.0)
	var initial: XJRuntimeState=Codec.new().clone(state)
	place(home.undock_anchor_id)
	var ship: RefCounted=state.ship();var limits: Dictionary=g.metrics(ship);ship.energy=limits.energy_max;ship.heat=0;ship.overheated=false
	for equipment: RefCounted in g.equipped(ship):equipment.cooldown_remaining_s=0;equipment.active_remaining_s=0;equipment.cycle_paid=false
	var actual: Dictionary={};var burst: float=0.0;var heat_stalls: int=0;var energy_stalls: int=0
	var dt: float=1.0/g.rule("simulation_hz");var steps: int=int(round(float(g.fitting_analysis.config().horizon_s)/dt))
	for frame: int in range(steps):
		g.begin_step(dt)
		for equipment: RefCounted in g.equipped(ship):
			if equipment.cooldown_remaining_s>0 or g.definition("weapon_defs","module_id",equipment.module_def_id).is_empty():continue
			var cycle: Dictionary=g.consume_weapon_cycle(equipment.item_instance_id)
			if cycle.is_empty():
				if g.last_error=="热量已达到限制":heat_stalls+=1
				if g.last_error=="能量不足":energy_stalls+=1
				continue
			actual[equipment.item_instance_id]=int(actual.get(equipment.item_instance_id,0))+1
			if frame*dt<float(g.fitting_analysis.config().burst_window_s):burst+=(cycle.damage_vector as Vector3).x+(cycle.damage_vector as Vector3).y+(cycle.damage_vector as Vector3).z
	for row: Dictionary in forecast.weapons:check(int(actual.get(row.item_id,0))==int(row.shots),"forecast paid cycles equal actual live resource execution")
	check(absf(ship.energy-float(forecast.energy_remaining))<0.0001 and absf(ship.heat-float(forecast.heat_remaining))<0.0001 and absf(burst-float(forecast.burst_damage))<0.0001,"forecast end capacitor heat and burst equal real cycle arithmetic")
	check((heat_stalls>0)==(float(forecast.first_heat_stall_s)>=0.0) and (energy_stalls>0)==(float(forecast.first_energy_stall_s)>=0.0),"resource-limit warnings correspond to actual failures")
	g.dispose();g=null;state=initial;g=Gameplay.new();g.setup(state,store.catalog);place(home.station_anchor_id,home.station_id)
func _ammo_and_range(home: Dictionary) -> void:
	var hold: String=g.inventory.hold(state.ship(),T.ContainerKind.CARGO)
	for stack: RefCounted in state.rows("inventory_stack_state").duplicate():
		if stack.container_id==hold and g.definition("item_defs","item_id",stack.item_def_id).item_type=="ammo":g.state.remove("inventory_stack_state",stack)
	var report: Dictionary=g.fitting_analysis.report(1000.0)
	check(report.first_ammo_stall_s==0.0 and report.weapons.all(func(row: Dictionary)->bool:return row.shots==0 if g.definition("weapon_defs","module_id",row.module_id).ammo_item_id!=null else row.shots>0),"empty ammunition stops only ammunition weapons while beams continue under real resources")
	var far: Dictionary=g.fitting_analysis.report(1000000.0)
	check(far.conditional_dps==0.0 and far.weapons.all(func(row: Dictionary)->bool:return not row.in_range),"out-of-range target is not assigned fictitious damage")
	var before: String=full_signature(state);g.specializations.donate_reason(1);g.specializations.research_reason("spec_burst",1)
	check(full_signature(state)==before,"research quotes cannot create warehouse inventory or ledger rows")
	place(home.station_anchor_id,home.station_id)
func _sources(home: Dictionary) -> void:
	g.tactics.sync()
	var npc: RefCounted=null
	for actor: RefCounted in state.rows("npc_state"):
		if g.tactics.handles(actor.spawn_id):npc=actor;break
	if npc==null:check(false,"real tactical source exists");return
	var spawn: Dictionary=g.definition("npc_spawn_defs","spawn_id",npc.spawn_id);place(spawn.anchor_id)
	var earned: int=g.specializations.progress().earned_points
	g.damage_npc(npc.npc_instance_id,Vector3(100000,0,0))
	check(g.specializations.progress().earned_points==earned+int(g.specializations.balance.tactic_points),"actual tactical destruction grants an alternative evidence source")
	g.specializations.tactic_destroyed(npc)
	check(g.specializations.progress().earned_points==earned+int(g.specializations.balance.tactic_points),"same destruction cannot repeat analysis reward")
	for event: Dictionary in g.rows("exploration_event_defs"):
		if event.event_kind!="relic":continue
		var row: RefCounted=g.exploration.instance(event.event_id);var spec: Dictionary={}
		for variant: Dictionary in g.rows("exploration_variant_defs"):
			if variant.event_id==event.event_id and int(variant.variant_index)==2:spec=variant;break
		reset_case(row,spec);check(act("survey",row),"alternative exploration starts a real paid survey")
		advance(float(spec.survey_duration_s)/float(g.exploration.balance.em_scan_multiplier)+0.2)
		_relic(row,spec)
		var destination: Dictionary=g.definition("station_defs","station_id",event.station_id);place(destination.station_anchor_id,destination.station_id)
		earned=g.specializations.progress().earned_points
		check(act("claim",row) and g.specializations.progress().earned_points==earned+int(g.specializations.balance.exploration_points),"actual partial exploration claim yields independent specialization evidence")
		break
	var operation: RefCounted=g.operations.instance("op_demolition");var op: Dictionary=g.operations.definition(operation.operation_id);var station: Dictionary=g.definition("station_defs","station_id",op.station_id)
	place(station.station_anchor_id,station.station_id)
	check(apply("operation_action",op.operation_id,1,"accept:"+str(operation.generation)),"alternative objective starts at its actual station")
	place(op.entry_anchor_id);check(apply("operation_action",op.operation_id,1,"start:"+str(operation.generation)),"alternative demolition creates actual targets")
	for target: RefCounted in state.rows("npc_state"):
		if g.operations.handles(target.spawn_id):g.damage_npc(target.npc_instance_id,Vector3(100000,0,0))
	check(apply("operation_action",op.operation_id,1,"withdraw:"+str(operation.generation)),"actual demolished targets resolve without clearing fleet")
	place(station.station_anchor_id,station.station_id);earned=g.specializations.progress().earned_points
	check(apply("operation_action",op.operation_id,1,"claim:"+str(operation.generation)) and g.specializations.progress().earned_points==earned+int(op.target_units)*int(g.specializations.balance.operation_points_per_unit),"actual objective delivery yields a third earned evidence path")
	place(home.station_anchor_id,home.station_id)
func previous_signature(value: XJRuntimeState) -> String:
	var data: Dictionary={}
	# Format15 contained these 53 groups. Later services legitimately initialize
	# their own tables; every original asset/receipt/RNG group remains exact.
	for table: String in XJRuntimeState.TABLES.slice(0,53):
		if table in CAMPAIGN_STATE_ADDITIONS:continue
		if table.begins_with("specialization_"):continue
		var rows: Array=[]
		for row: RefCounted in value.rows(table):
			if campaign_added_row(table,row):continue
			if table=="shop_stock_state" and str(row.item_def_id).begins_with("module_spec_"):continue
			rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func _legacy_fitting() -> void:
	g.dispose();g=null;store.close();store=null
	var source: String=OS.get_environment("XJ_FITTING_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/") and not source.contains("..") and FileAccess.file_exists(source),"actual previous package database stays scoped"):return
	var path: String=directory.path_join("legacy.db");check(DirAccess.copy_absolute(source,path)==OK,"copy closed actual format15 world")
	var faulty: FaultStore=FaultStore.new(path);faulty.failure="migration:019_fitting.sql";store=faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==15,"019 failure rolls back previous format15")
	faulty.failure="";if not check(store.open(),"retry reaches format16"):return
	var slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind=="manual":slot=row;break
	state=store.load(slot.slot_id)
	if not check(state!=null and state.rows("industry_job_state").size()==4 and state.rows("drone_bay_state").size()>0,"old paid orders and installed bay restore before content upgrade"):return
	var before: String=previous_signature(state)
	faulty.failure="content_upgrade";check(store.upgrade_content(state)==null and previous_signature(state)==before,"failed fitting branch preserves all 53 prior groups")
	faulty.failure="";state=store.upgrade_content(state)
	if not check(state!=null,"reviewed fitting branch succeeds "+store.last_error):return
	check(previous_signature(state)==before and state.rows("specialization_progress_state")[0].earned_points==0,"prior assets jobs knowledge allegiance and RNG preserved without retroactive free analysis")
	check(state.rows("shop_stock_state").any(func(row: RefCounted)->bool:return row.item_def_id=="module_spec_range"),"new trade stock appears without replacing original prices or inventories")
	check(store.upgrade_content(state)==state,"fitting upgrade is idempotent")
	state=store.load(slot.slot_id);check(state!=null and state.rows("specialization_progress_state").is_empty() and not store.catalog.table_names.has("weapon_tuning_defs"),"original manual retains its independent frozen operation rules")
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory}
	print("FITTING_V31_FINAL_JSON ",JSON.stringify(summary));print("FITTING_V31_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
