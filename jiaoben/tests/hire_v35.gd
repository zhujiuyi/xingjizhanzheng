extends "frontier_v34.gd"
## Funds, unlocked routes, owned hulls, poses and strategy-time boundaries are
## explicit fixtures. Physical movement, fire, LOS and GUI use native suites.
var roles_checked: Array[String]=[]
func _ready() -> void:
	get_tree().set_meta("xj_hire_v35_diagnostic",true)
	get_tree().create_timer(600.0).timeout.connect(func():print("HIRE_V35_RESULT FAIL watchdog");get_tree().quit(2))
	_run.call_deferred()
func lease(action: String,focus_id: String="") -> bool:
	var accepted: bool=apply("hire_action",action,1,g.hired.token()+("|"+focus_id if not focus_id.is_empty() else ""))
	if not accepted:print("HIRE_ACTION_REASON ",action," ",g.last_error)
	return accepted
func preserve(index: int,label: String) -> bool:
	var signature: String=full_signature(state)
	if not check(store.save(state,"manual",index),label+" seals all current typed groups "+store.last_error):return false
	var slot: String=saved_slot(index);g.dispose();g=null;state=store.load(slot)
	if not check(state!=null,label+" reopens "+store.last_error):return false
	check(full_signature(state)==signature,label+" retains every typed state and world RNG")
	g=Gameplay.new();g.setup(state,store.catalog);return true
func home_with_companion() -> void:
	var home: Dictionary=g.definition("station_defs","station_id","station_anchor_port")
	place(home.station_anchor_id,home.station_id);g.hired.follow_arrival()
func _run() -> void:
	directory=OS.get_environment("XJ_HIRE_V35_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/hire-v35/") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped companion contract world"):get_tree().quit(2);return
	store=Store.new(directory.path_join("progress.db"))
	if not check(store.open(),"format24 opens "+store.last_error):await finish();return
	check(int(store._records("PRAGMA user_version")[0].values()[0])==26 and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==26,"fresh real SQLite has consistent format26 metadata and user version")
	state=store.new_world("有限雇佣合同",3501)
	if not check(state!=null,"new hire world seals "+store.last_error):await finish();return
	g=Gameplay.new();g.setup(state,store.catalog)
	check(XJRuntimeState.TABLES.size()==114 and state.rows("hire_contract_state").is_empty() and state.rows("hire_receipt_state").is_empty(),"new world receives no free companion or monetary receipts")
	var before: String=full_signature(state);g.hired.hire_reason("hire_escort");g.hired.status_text();g.hired.token()
	check(full_signature(state)==before,"contract browsing changes no money, state or random stream")
	for unlock: Dictionary in g.rows("unlock_defs"):g.grant_unlock(unlock.unlock_id)
	state.player().credit=100000;g.missions.refresh();g._sync_spawns();hull("frigate_kestrel")
	var ship_count: int=state.rows("ship_state").size();var credit: int=state.player().credit;var old_token: String=g.hired.token()
	var spec: Dictionary=g.hired.profile("hire_escort")
	check(lease("hire_escort"),"real action hires the escort contract")
	var row: RefCounted=g.hired.active();var npc: RefCounted=g.hired.actor(row)
	if not check(row!=null and npc!=null,"paid contract has an actual NPC binding"):await finish();return
	roles_checked.append("escort")
	check(state.player().credit==credit-int(spec.hire_fee_credit)-int(spec.deposit_credit),"escort pays the exact frozen hire fee and deposit")
	check(state.rows("ship_state").size()==ship_count and g.civilizations.friendly(npc.npc_instance_id) and g.civilizations.escort_hull(npc.npc_instance_id)==spec.hull_id,"rental is a friendly NPC and creates no privately owned hull")
	credit=state.player().credit
	check(not apply("hire_action","hire_escort",1,old_token) and state.player().credit==credit,"stale vacant callback cannot hire or charge again")
	check(not lease("hire_support") and state.player().credit==credit,"one active contract blocks a second paid slot")
	check(lease("advance") and row.order_kind=="advance","advance is an authoritative companion command")
	check(not lease("focus",npc.npc_instance_id) and row.order_kind=="advance","focus refuses its own friendly companion")
	var enemy: RefCounted=null
	for candidate: RefCounted in state.rows("npc_state"):
		if candidate.alive and candidate.sector_id==state.current_sector() and not g.civilizations.friendly(candidate.npc_instance_id):enemy=candidate;break
	if not check(enemy!=null,"declared encounter fixture has an actual hostile actor"):await finish();return
	place(g.definition("npc_spawn_defs","spawn_id",enemy.spawn_id).anchor_id);g.hired.follow_arrival()
	check(lease("focus",enemy.npc_instance_id) and row.has_focus_target_id and row.focus_target_id==enemy.npc_instance_id,"focus accepts the actual local hostile generation")
	check(not g.hired.travel_reason().is_empty(),"a fighting companion must regroup before a strategic departure")
	check(lease("regroup") and not row.has_focus_target_id and g.hired.travel_reason().is_empty(),"regroup clears focus and permits a close ready formation")
	if not preserve(1,"paid escort and changed local site"):await finish();return
	row=g.hired.active();npc=g.hired.actor(row)
	check(row.profile_id=="hire_escort" and row.order_kind=="regroup","loaded contract retains its profile and order")
	# Damage and return poses are fixtures; native acceptance proves real hits.
	npc.armor-=20.0;npc.hull-=10.0;var expected_refund: int=int(float(row.deposit_paid_credit)*g.hired._condition(npc))
	home_with_companion();credit=state.player().credit;old_token=g.hired.token()
	check(lease("dismiss"),"actual station dismissal settles a damaged returned companion")
	check(row.phase=="returned" and row.refund_credit==expected_refund and state.player().credit==credit+expected_refund,"return deducts actual armor and hull damage from the deposit")
	check(g.hired.active()==null and not row.has_npc_instance_id and state.find("npc_state","npc_instance_id",npc.npc_instance_id)==null,"returned rental actor is removed from authoritative state")
	credit=state.player().credit
	check(not apply("hire_action","dismiss",1,old_token) and state.player().credit==credit,"old return callback cannot refund twice")
	check(lease("hire_support"),"second independently paid contract hires support")
	row=g.hired.active();roles_checked.append("support")
	place("anchor_anchor_undock");g.hired.follow_arrival()
	var metrics: Dictionary=g.metrics(state.ship());state.ship().shield=maxf(0.0,float(metrics.shield_max)-50.0)
	var shield: float=state.ship().shield;var cycles: int=row.support_cycles_remaining
	check(g.hired.repair_step(row)=="shield" and state.ship().shield==minf(float(metrics.shield_max),shield+float(g.hired.balance.support_shield)) and row.support_cycles_remaining==cycles-1,"support restores actual shield and consumes one finite prepaid supply")
	cycles=row.support_cycles_remaining
	check(g.hired.repair_step(row).is_empty() and row.support_cycles_remaining==cycles,"support cooldown prevents repeated immediate restoration")
	g.hired.tick(float(g.hired.balance.support_cycle_s));state.ship().shield=float(metrics.shield_max);state.ship().armor=maxf(0.0,float(metrics.armor_max)-30.0)
	check(g.hired.repair_step(row)=="armor","full shields allow the support ship to restore actual armor")
	row.support_cycles_remaining=0;g.hired.tick(float(g.hired.balance.support_cycle_s));shield=state.ship().shield;var armor: float=state.ship().armor
	check(g.hired.repair_step(row).is_empty() and state.ship().shield==shield and state.ship().armor==armor,"exhausted prepaid support never repairs for free")
	if not preserve(2,"partly used support supplies"):await finish();return
	row=g.hired.active();check(row.support_cycles_remaining==0,"spent support budget survives reload")
	var remaining: float=row.lease_remaining_s;g.hired.tick(0.0)
	check(row.lease_remaining_s==remaining,"zero simulation time cannot consume or refill the lease")
	row.lease_remaining_s=float(g.hired.balance.warning_s)+0.1;g.hired.tick(0.2)
	check(row.expiry_warned,"near-expiry warning is an authoritative one-time state")
	g.hired.tick(float(g.hired.balance.warning_s))
	check(row.phase=="retreating" and row.order_kind=="retreat","lease expiry starts a real retreat rather than a free extension")
	check(not g.hired.travel_reason().is_empty(),"strategic travel waits for companion disengagement")
	npc=g.hired.actor(row);var start: Vector3=g.position(npc)
	g.hired.retreat_step(row,float(g.hired.balance.retreat_charge_s))
	check(row.phase=="retreating" and row.retreat_remaining_s==float(g.hired.balance.retreat_charge_s),"retreat work does not advance without real distance")
	# Declared physical-distance boundary fixture, not movement evidence.
	npc.pos_x=start.x+float(g.hired.balance.retreat_distance_m)+1.0
	g.hired.retreat_step(row,float(g.hired.balance.retreat_charge_s)*0.5)
	if not preserve(3,"partial disengagement timer"):await finish();return
	row=g.hired.active();g.hired.retreat_step(row,float(g.hired.balance.retreat_charge_s))
	check(row.phase=="returning" and not row.has_npc_instance_id and row.return_remaining_s==float(g.hired.balance.return_s),"completed disengagement starts bounded strategic agency return")
	if not preserve(4,"strategic agency return"):await finish();return
	row=g.hired.active();credit=state.player().credit;g.hired.tick(float(g.hired.balance.return_s))
	check(row.phase=="returned" and state.player().credit==credit+row.refund_credit and g.hired.active()==null,"agency arrival refunds the finite deposit exactly once")
	credit=state.player().credit;g.hired.tick(float(g.hired.balance.return_s))
	check(state.player().credit==credit,"repeated world time cannot repay a completed lease")
	home_with_companion();check(lease("hire_escort"),"replacement escort requires a fresh paid contract")
	row=g.hired.active();npc=g.hired.actor(row);credit=state.player().credit
	g.damage_npc(npc.npc_instance_id,Vector3(1000000.0,0.0,0.0));g.hired.tick(0.1)
	check(row.phase=="lost" and row.refund_credit==0 and state.player().credit==credit,"fatal damage loses the deposit and grants no bounty or loot")
	step(g.combat_remaining_s+0.2)
	if not preserve(0,"settled companion history"):await finish();return
	check(state.rows("hire_contract_state").size()==3 and state.rows("hire_receipt_state").size()==6 and g.hired.active()==null,"each of three contracts retains one payment and one final outcome")
	if not OS.get_environment("XJ_HIRE_LEGACY_DATABASE").is_empty():legacy_hire()
	await finish()
func prior_hire_signature(value: XJRuntimeState) -> String:
	var data: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		if table in CAMPAIGN_STATE_ADDITIONS:continue
		if table in ["hire_contract_state","hire_receipt_state"]:continue
		var rows: Array=[]
		for row: RefCounted in value.rows(table):
			if not campaign_added_row(table,row):rows.append(Codec.new().encode_row(table,row))
		rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return JSON.stringify(a)<JSON.stringify(b));data[table]=rows
	return JSON.stringify(data)
func legacy_hire() -> void:
	if g!=null:g.dispose();g=null
	store.close();store=null
	var source: String=OS.get_environment("XJ_HIRE_LEGACY_DATABASE").replace("\\","/")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/fitting-v31/") and not source.contains("..") and FileAccess.file_exists(source),"real v0.26 upgrade source is closed and test-owned"):return
	var source_hash: String=FileAccess.get_sha256(source);var path: String=directory.path_join("legacy.db")
	check(DirAccess.copy_absolute(source,path)==OK,"copy real paid v0.26 progress without modifying source")
	var faulty: FaultStore=FaultStore.new(path);faulty.failure="migration:023_hire.sql";store=faulty
	check(not store.open() and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==19,"023 failure preserves actual old format19")
	check(FileAccess.file_exists(directory.path_join("migration-format19-backup.db")),"format24 migration first creates the actual old database backup")
	faulty.failure=""
	if not check(store.open(),"migration retries to format24 "+store.last_error):return
	check(int(store._records("PRAGMA user_version")[0].values()[0])==26 and int(store._records("SELECT format_version FROM database_meta")[0].format_version)==26,"actual migrated database has consistent format26 version markers")
	var slot: Dictionary={}
	for entry: Dictionary in store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==2:slot=entry;break
	if not check(not slot.is_empty(),"real old fixture retains its chosen original manual slot"):return
	state=store.load(slot.slot_id)
	if not check(state!=null,"actual old war orders research and custody load "+store.last_error):return
	check(state.rows("frontier_actor_state").size()==3 and state.find("frontier_campaign_state","war_id","war_council_02").phase=="escorting" and state.find("frontier_campaign_state","war_id","war_council_01").phase=="completed","old package has completed reconstruction plus its live paid escort")
	check(state.find("consignment_state","contract_id","freight_anchor_echo").cargo_units==2 and state.rows("industry_job_state").size()>=3,"actual old paid freight and manufacturing remain")
	var before: String=prior_hire_signature(state);var slots: String=JSON.stringify(store.list_slots());var count: int=int(store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)
	faulty.failure="content_upgrade"
	check(store.upgrade_content(state)==null and prior_hire_signature(state)==before,"failed hire branch preserves all sixty-eight old groups")
	check(JSON.stringify(store.list_slots())==slots and int(store._records("SELECT count(*) AS n FROM save_snapshot")[0].n)==count,"failed content branch rolls back snapshot and resume pointer")
	faulty.failure="";state=store.upgrade_content(state)
	if not check(state!=null,"reviewed v0.26 hire upgrade succeeds "+store.last_error):return
	check(prior_hire_signature(state)==before,"all old assets missions paid work actors clocks history and RNG survive exactly")
	check(state.rows("hire_contract_state").is_empty() and state.rows("hire_receipt_state").is_empty(),"upgrade grants no free rented actor fee deposit or supplies")
	check(store.upgrade_content(state)==state,"hire content upgrade is idempotent")
	g=Gameplay.new();g.setup(state,store.catalog)
	check(g.hired.supported() and g.frontier.campaign("war_council_02").phase=="escorting","new rental service coexists with the existing staged campaign")
	check(apply("fleet_command","regroup"),"existing paid campaign keeps its original fleet command authority")
	if not preserve(3,"upgraded real v0.26 world"):return
	g.dispose();g=null;state=store.load(slot.slot_id)
	check(state!=null and not store.catalog.table_names.has("hire_profile_defs") and state.rows("hire_contract_state").is_empty() and prior_hire_signature(state)==before,"original manual snapshot retains its exact independent v0.26 rules and progress")
	check(FileAccess.get_sha256(source)==source_hash,"all upgrade and rollback checks leave the real old fixture bytes unchanged")
	legacy_checked=true
func finish() -> void:
	if g!=null:g.dispose();g=null
	if store!=null:store.close();store=null
	state=null
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"roles":roles_checked,"groups":XJRuntimeState.TABLES.size(),"legacy_checked":legacy_checked}
	print("HIRE_V35_FINAL_JSON ",JSON.stringify(summary));print("HIRE_V35_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	await get_tree().process_frame;get_tree().quit(0 if failures.is_empty() else 1)
