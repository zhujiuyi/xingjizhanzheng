extends "exploration_v27.gd"
## Qualified equipment and direct arrival poses verify authority; native suite verifies actual rays/AI.
func _ready() -> void:
	get_tree().set_meta("xj_tactics_v29_diagnostic", true)
	get_tree().create_timer(360.0).timeout.connect(func(): print("TACTICS_V29_RESULT FAIL watchdog"); get_tree().quit(2))
	_run.call_deferred()
func actor(kind: String) -> RefCounted:
	for row: RefCounted in state.rows("npc_tactic_state"):
		if g.tactics.definition(row.npc_instance_id).tactic_kind == kind: return state.find("npc_state", "npc_instance_id", row.npc_instance_id)
	return null
func near(npc: RefCounted) -> void:
	var anchor: String = g.definition("npc_spawn_defs", "spawn_id", npc.spawn_id).anchor_id
	place(anchor); state.ship().pos_x += 100.0
func run_ability(npc: RefCounted, target: String, seconds: float, visible: bool = true) -> Dictionary:
	var result: Dictionary = {}
	var left: float = seconds
	while left > 0.00001:
		var delta: float = minf(0.1,left); g.begin_step(delta)
		var cycle: Dictionary = g.tactics.step(npc.npc_instance_id,target,visible,delta)
		if not cycle.is_empty(): result = cycle
		g.tactics.tick(delta); left -= delta
	return result
func full_fingerprint(include_receipts: bool = true) -> String:
	var result: Dictionary = {}
	for table: String in XJRuntimeState.TABLES:
		if not include_receipts and table == "action_receipt_state": continue
		var rows: Array = []
		for row: RefCounted in state.rows(table): rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return JSON.stringify(a)<JSON.stringify(b))
		result[table] = rows
	return JSON.stringify(result)
func _run() -> void:
	directory = OS.get_environment("XJ_TACTICS_V29_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/tactics-v29/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "fresh scoped doctrine world"): get_tree().quit(2); return
	store = Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format14 opens " + store.last_error): get_tree().quit(1); return
	state = store.new_world("四类战术与无人机",2901); g = Gameplay.new(); g.setup(state,store.catalog)
	check(state.rows("tactical_site_state").size()==(9 if store.catalog.table_names.has("campaign_balance_defs") else 3) and state.rows("tactical_site_state").filter(func(r: RefCounted):return not r.site_id.begins_with("tac_exp_theme_")).size()==3 and state.rows("npc_tactic_state").is_empty(),"three original sites and explicit locked theme sites never spawn free enemies")
	for unlock: Dictionary in g.rows("unlock_defs"): g.grant_unlock(unlock.unlock_id)
	g.tactics.sync()
	check(state.rows("npc_tactic_state").size()==9,"three mixed sites create nine real doctrine actors")
	state.player().credit = 1000000
	var home: Dictionary = g.definition("station_defs","station_id","station_anchor_port")
	var ship: RefCounted = g.inventory.create_ship("cruiser_horizon",home.station_id); state.player().controlled_ship_id = ship.ship_instance_id
	place(home.station_anchor_id,home.station_id)
	_support(); _jam(); _siege(); _carrier()
	_player_drones(home)
	g.tick(float(g.definition("module_defs","module_id","module_drone_swarm_i").cycle_s) + g.rule("combat_exit_delay_s") + 0.1)
	g.missions.refresh(); g._sync_spawns(); g.tactics.sync()
	var validation: Validation = Validation.new()
	check(validation.validate(state,store.catalog),"all fifty-two typed groups validate " + validation.last_error)
	if not check(store.save(state,"manual",0),"full paid replacement/ability world seals " + store.last_error): await finish(); return
	var before: String = full_fingerprint()
	var slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind=="manual":slot=row;break
	g.dispose();g=null;state=store.load(slot.slot_id);g=Gameplay.new();g.setup(state,store.catalog)
	check(full_fingerprint()==before,"all fifty-two groups restore without loss reset or free replenishment")
	if not OS.get_environment("XJ_TACTICS_LEGACY_DATABASE").is_empty():legacy_tactics()
	await finish()
func prior_fingerprint(value: XJRuntimeState) -> String:
	var result: Dictionary = {}
	var tactical_npcs: Array[String] = []
	for npc: RefCounted in value.rows("npc_state"):
		if npc.spawn_id.begins_with("tac_"):tactical_npcs.append(npc.npc_instance_id)
	for table: String in XJRuntimeState.TABLES:
		if table in ["tactical_site_state","npc_tactic_state","ship_tactical_effect_state","drone_bay_state"]:continue
		var rows: Array = []
		for row: RefCounted in value.rows(table):
			if table=="npc_state" and row.npc_instance_id in tactical_npcs:continue
			if table=="spatial_state" and row.entity_kind=="npc" and row.entity_id in tactical_npcs:continue
			rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b))
		result[table]=rows
	return JSON.stringify(result)
func legacy_tactics() -> void:
	g.dispose();g=null;store.close();store=null
	var source: String = OS.get_environment("XJ_TACTICS_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/") and not source.contains("..") and FileAccess.file_exists(source),"real old client fixture is isolated"):return
	var path: String = directory.path_join("legacy.db")
	check(DirAccess.copy_absolute(source,path)==OK,"copy closed format13 client database")
	var faulty: FaultStore = FaultStore.new(path);faulty.failure="migration:017_tactics.sql";store=faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==13,"017 failure preserves exact old format13")
	faulty.failure="";if not check(store.open(),"retry installs format14"):return
	var slot: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind=="manual":slot=row;break
	state=store.load(slot.slot_id)
	if not check(state!=null and state.rows("industry_job_state").size()==4,"old PCK preserves running/queued orders and cancellation receipt"):return
	var before: String = prior_fingerprint(state)
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and prior_fingerprint(state)==before,"failed tactics branch preserves all forty-eight old state groups")
	faulty.failure="";state=store.upgrade_content(state)
	if not check(state!=null,"reviewed tactics branch succeeds "+store.last_error):return
	check(prior_fingerprint(state)==before,"old assets orders progress knowledge factions and RNG remain exact")
	check(state.rows("tactical_site_state").size()==3 and state.rows("drone_bay_state").size()==1,"new optional sites and existing usable bay initialize without replacing assets")
	g=Gameplay.new();g.setup(state,store.catalog)
	var bay: RefCounted = state.rows("drone_bay_state")[0]
	var item: RefCounted = state.find("item_instance_state","item_instance_id",bay.item_instance_id)
	var nominal: int = int(g.definition("drone_defs","module_id",item.item_def_id).drone_count)
	check(bay.stock_units==nominal and bay.lost_units==0 and bay.deployed_units==0,"old reusable bay retains its original full sortie")
	var home: Dictionary = g.definition("station_defs","station_id","station_anchor_port")
	place(home.station_anchor_id)
	var drone: RefCounted = g.drone_control.register(state.ship().ship_instance_id,item.item_instance_id,item.item_def_id,state.ship().ship_instance_id)
	check(drone!=null,"upgraded legal existing bay can launch")
	if drone!=null:g.drone_control.retire(drone.drone_id,true)
	place(home.station_anchor_id,home.station_id);g.missions.refresh();g._sync_spawns();g.tactics.sync()
	check(store.save(state,"manual",1),"upgraded bay loss and paid orders seal together "+store.last_error)
	var saved: Dictionary
	for row: Dictionary in store.list_slots():
		if row.slot_kind=="manual" and int(row.slot_index)==1:saved=row;break
	g.dispose();g=null;state=store.load(saved.slot_id);g=Gameplay.new();g.setup(state,store.catalog)
	bay=state.rows("drone_bay_state")[0]
	check(bay.stock_units==nominal-1 and bay.lost_units==1,"physical reopen of upgraded world cannot reset drone loss")
	g.dispose();g=null;state=store.load(slot.slot_id)
	check(prior_fingerprint(state)==before and state.rows("drone_bay_state").is_empty(),"original manual remains independently restorable")
	var count: int = int(store._records("SELECT count(*) n FROM save_snapshot")[0].n)
	state=store.upgrade_content(state)
	check(state!=null and int(store._records("SELECT count(*) n FROM save_snapshot")[0].n)==count,"repeat upgrade reuses existing reviewed branch")
func _support() -> void:
	var support: RefCounted = actor("support"); var victim: RefCounted = actor("siege")
	near(support)
	victim.pos_x = support.pos_x + 100.0; victim.pos_y = support.pos_y; victim.pos_z = support.pos_z
	var maximum: Dictionary = g.definition("npc_full_defs","npc_id",g.definition("npc_spawn_defs","spawn_id",victim.spawn_id).npc_id)
	victim.hull = float(maximum.hull_max) - 84.0
	var old_hp: float = victim.hull
	run_ability(support,victim.npc_instance_id,0.1)
	check(g.tactics.instance(support.npc_instance_id).energy < g.tactics.definition(support.npc_instance_id).energy_max,"support pays real finite capacitor")
	run_ability(support,victim.npc_instance_id,4.0)
	check(victim.hull>old_hp and victim.hull<=float(maximum.hull_max),"support actually repairs another NPC without exceeding maxima")
	var before: float = victim.hull
	run_ability(support,victim.npc_instance_id,2.0,false)
	check(victim.hull==before,"occlusion stops support repair")
func _jam() -> void:
	var npc: RefCounted = actor("interceptor"); near(npc)
	var speed: float = g.metrics(state.ship()).speed_mps; var turn: float = g.metrics(state.ship()).turn_radps
	run_ability(npc,state.ship().ship_instance_id,1.3)
	var effect: RefCounted = state.find("ship_tactical_effect_state","ship_instance_id",state.ship().ship_instance_id)
	check(effect!=null and effect.jam_remaining_s>0.0,"prepared interceptor applies bounded real propulsion interference")
	check(is_equal_approx(g.metrics(state.ship()).speed_mps,speed*float(g.tactics.balance.min_thrust_ratio)) and is_equal_approx(g.metrics(state.ship()).turn_radps,turn),"minimum thrust and unchanged turning preserve control")
	check(not g.tactics.apply_jam(npc.npc_instance_id),"ongoing interference cannot be indefinitely extended")
	g.tactics.tick(effect.jam_remaining_s)
	check(is_equal_approx(effect.immunity_remaining_s,float(g.tactics.balance.jam_immunity_s)) and not g.tactics.apply_jam(npc.npc_instance_id),"expiration starts a full immunity interval")
	g.tactics.tick(float(g.tactics.balance.jam_immunity_s))
	check(g.tactics.apply_jam(npc.npc_instance_id) and effect.jam_remaining_s<float(g.tactics.balance.jam_max_duration_s),"repeat application has diminishing duration")
	g.damage_npc(npc.npc_instance_id,Vector3(100000,100000,100000))
	check(effect.jam_remaining_s==0.0 and is_equal_approx(g.metrics(state.ship()).speed_mps,speed),"destroying source immediately releases propulsion")
func _siege() -> void:
	var npc: RefCounted = actor("siege"); near(npc)
	var aim: Vector3 = g.position(state.ship())
	run_ability(npc,state.ship().ship_instance_id,0.1)
	check(g.tactics.instance(npc.npc_instance_id).phase=="charging","siege begins an observable paid charge")
	state.ship().pos_x += 200.0
	var cycle: Dictionary = run_ability(npc,state.ship().ship_instance_id,4.0)
	check(not cycle.is_empty() and cycle.aim==aim and cycle.damage.x==float(g.tactics.definition(npc.npc_instance_id).strength),"charged fire keeps original aim and frozen volley strength")
	g.tactics.tick(float(g.tactics.definition(npc.npc_instance_id).cooldown_s));near(npc)
	run_ability(npc,state.ship().ship_instance_id,0.1)
	g.damage_npc(npc.npc_instance_id,Vector3(100,0,0))
	cycle=run_ability(npc,state.ship().ship_instance_id,0.1)
	check(cycle.is_empty() and g.tactics.instance(npc.npc_instance_id).phase=="cooldown","effective damage interrupts charged fire before a projectile")
func _carrier() -> void:
	var npc: RefCounted = actor("carrier");near(npc)
	var cycle: Dictionary = run_ability(npc,state.ship().ship_instance_id,1.6)
	check(not cycle.is_empty() and cycle.kind=="carrier","carrier produces a paid real drone-launch command")
	var spec: Dictionary = g.tactics.definition(npc.npc_instance_id)
	var module: String = spec.drone_module_id;var key: String = "npc_bay_"+npc.npc_instance_id
	var active: Array[RefCounted] = []
	for index: int in range(int(g.definition("drone_defs","module_id",module).drone_count)):
		var drone: RefCounted = g.drone_control.register(npc.npc_instance_id,key,module,state.ship().ship_instance_id)
		check(drone!=null,"NPC carrier registers a bounded live actor");active.append(drone)
	check(g.drone_control.register(npc.npc_instance_id,key,module,state.ship().ship_instance_id)==null,"NPC cannot exceed the sortie batch limit")
	check(not store.save(state,"manual",1),"outstanding NPC drones reject a sealed snapshot")
	var credit: int = state.player().credit
	check(g.drone_control.damage(active[0].drone_id,state.ship().ship_instance_id,Vector3(1000,0,0)),"hostile incoming damage is accepted for enemy drone")
	check(g.tactics.instance(npc.npc_instance_id).lost_drones==1 and state.player().credit==credit,"destroyed drone consumes finite reserve without independent bounty")
	for drone: RefCounted in active:g.drone_control.retire(drone.drone_id,false)
	check(g.tactics.instance(npc.npc_instance_id).deployed_drones==0,"surviving NPC drones recover without restoring destroyed reserve")
func _player_drones(home: Dictionary) -> void:
	place(home.station_anchor_id,home.station_id)
	var warehouse: String = g.inventory.warehouse(home.station_id)
	var item: String = g.inventory.grant(warehouse,"module_drone_swarm_i",1)[0]
	check(g.act("fit_module",item,1,"weapon").phase==T.ActionPhase.APPLIED,"qualified compatible hull legally installs drone bay")
	check(g.drone_control.register(state.ship().ship_instance_id,item,"module_drone_swarm_i","")==null,"docked bay cannot launch")
	var target: RefCounted = actor("siege");near(target)
	check(g.act("drone_command","",1,"follow").phase==T.ActionPhase.APPLIED,"follow command applies through real action service")
	var paid: Dictionary = g.consume_weapon_cycle(item)
	check(not paid.is_empty(),"actual sortie pays frozen energy and heat")
	var own: Array[RefCounted] = []
	for index: int in range(2):own.append(g.drone_control.register(state.ship().ship_instance_id,item,"module_drone_swarm_i",state.ship().ship_instance_id))
	check(own[0]!=null and own[0].command_kind=="follow" and g.drone_control.bay(item).deployed_units==2,"following actors share actual stock and paid shot")
	check(not g.drone_control.damage(own[0].drone_id,state.ship().ship_instance_id,Vector3(1000,0,0)),"friendly fire cannot destroy own drone")
	check(g.act("drone_command",target.npc_instance_id,1,"attack").phase==T.ActionPhase.APPLIED and own[0].target_id==target.npc_instance_id,"attack retargets the existing paid actors")
	check(g.drone_control.damage(own[0].drone_id,target.npc_instance_id,Vector3(1000,0,0)),"enemy fire produces real player-drone loss")
	check(g.drone_control.bay(item).stock_units==1 and g.drone_control.bay(item).lost_units==1,"loss is persisted once in bay stock")
	check(not store.save(state,"manual",1),"outstanding friendly drones also reject sealed save")
	check(g.act("drone_command","",1,"recall").phase==T.ActionPhase.APPLIED and own[1].returning,"recall disarms unfired attack")
	g.drone_control.retire(own[1].drone_id,false)
	check(g.drone_control.bay(item).stock_units==1,"recovery keeps surviving stock and does not recreate destroyed unit")
	var row: RefCounted = g.drone_control.bay(item)
	check(g.act("drone_replenish",item,1,str(row.revision)).phase!=T.ActionPhase.APPLIED,"flying ship cannot buy drone replacement")
	place(home.station_anchor_id,home.station_id)
	g.inventory.grant(warehouse,"material_structural_stock",50)
	g.inventory.grant(warehouse,"material_structural_stock",10,"tutorial_protected")
	var before: String = full_fingerprint(false)
	check(g.act("drone_replenish",item,1,"0").phase!=T.ActionPhase.APPLIED and full_fingerprint(false)==before,"old stock revision rejects without spending")
	var credit: int = state.player().credit
	var materials: int = g.inventory.count(warehouse,"material_structural_stock",true)
	var spec: Dictionary = g.definition("drone_management_defs","module_id","module_drone_swarm_i")
	var revision: String = str(row.revision)
	check(g.act("drone_replenish",item,1,revision).phase==T.ActionPhase.APPLIED,"station consumes real materials and fee for missing drone")
	check(row.stock_units==2 and state.player().credit==credit-int(spec.credit_per_unit) and g.inventory.count(warehouse,"material_structural_stock",true)==materials-int(spec.material_per_unit),"exact paid replacement restores only the missing quantity")
	before=full_fingerprint(false)
	check(g.act("drone_replenish",item,1,revision).phase!=T.ActionPhase.APPLIED and full_fingerprint(false)==before,"replacement cannot be replayed")
	check(row.paid_credit_total==int(spec.credit_per_unit) and row.material_units_total==int(spec.material_per_unit),"stock restoration retains a real cost ledger")
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	var summary: Dictionary = {"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"legacy_checked":not OS.get_environment("XJ_TACTICS_LEGACY_DATABASE").is_empty()}
	print("TACTICS_V29_FINAL_JSON ",JSON.stringify(summary));print("TACTICS_V29_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
