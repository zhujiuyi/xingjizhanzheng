extends "natural_recovery_v45.gd"
## Continues the accepted normally earned v0.31 world. No wealth, unlock,
## membership, pose, damage, objective or clock injection is permitted.
var membership_earned: bool=false
var examination_registered: bool=false
var normal_loadout: bool=false
var before_origin: String=""

func _ready() -> void:
	get_tree().set_meta("xj_natural_mid_v50_diagnostic",true)
	get_tree().set_meta("xj_natural_recovery_v45_diagnostic",true)
	get_tree().set_meta("xj_natural_growth_v45_diagnostic",true)
	start_msec=Time.get_ticks_msec();run.call_deferred()

func owned_item(module_id: String) -> RefCounted:
	for item: RefCounted in host.state.rows("item_instance_state"):
		if item.item_def_id==module_id and item.policy_id=="normal_owned":return item
	return null

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_MID_V50_DIRECTORY").replace("\\","/")
	var proof: String=OS.get_environment("XJ_NATURAL_MID_ORIGIN").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-mid-v50/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")) and proof.is_absolute_path() and proof.contains("/jiaoben/logs/v45-natural-origin-") and not proof.contains(".."),"fresh midgame replay and bounded normal-origin proof"):await finish();return
	origin=JSON.parse_string(FileAccess.get_file_as_string(proof));var source: String=str(origin.database)
	if not check(origin.result=="PASS" and origin.completed.size()==8 and source.contains("/jiaoben/tmp/natural-growth-v45/") and not source.contains("..") and FileAccess.get_sha256(source)==origin.database_sha256,"normal eight-mission source retains its proven bytes"):await finish();return
	check(DirAccess.copy_absolute(source,directory.path_join("progress.db"))==OK,"copy earned progress without changing its source")
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"normal Main opens midgame copy"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==0:slot=entry;break
	if not check(not slot.is_empty(),"normal origin manual slot exists"):await finish();return
	initial_credit=int(host.store._records("SELECT credit FROM player_state WHERE snapshot_id=?",[slot.current_snapshot_id])[0].credit)
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);await settle()
	if not check(host.gameplay.march.supported() and host.gameplay.growth.supported() and host.state.player().credit==initial_credit,"ordinary load upgrades safely without free funding"):await finish();return
	previous_position=host.gameplay.position(host.state.ship());previous_site=XJSpaceCoordinates.current_site(host.state);previous_ship=host.state.ship().ship_instance_id
	mark("midgame-earned-origin")
	if not await reach_station("station_forge_01"):await finish();return
	mark("first-capital-arrival")
	await command("buy_item","ore_ferrosilicate",150)
	if not check(host.gameplay.inventory.count(host.gameplay.inventory.warehouse(host.gameplay.station()),"ore_ferrosilicate",true)>=150,"ordinary market supplies citizenship material"):await finish();return
	if not await drive_mission("civ_join_forge_1"):await finish();return
	if not await drive_mission("civ_join_forge_2"):await finish();return
	var scanner: RefCounted=owned_item("module_scanner_beacon_i")
	if not check(scanner!=null,"previously earned scanner remains owned"):await finish();return
	await command("unfit_module",scanner.item_instance_id)
	await command("buy_item","module_kinetic_needle_i")
	var weapon: RefCounted=owned_item("module_kinetic_needle_i")
	if not check(weapon!=null,"ordinary earnings buy the combat refit"):await finish();return
	await command("fit_module",weapon.item_instance_id,1,"weapon:0");await command("set_module_enabled",weapon.item_instance_id,1,"on")
	var ammo: Dictionary=host.gameplay.definition("weapon_defs","module_id","module_kinetic_needle_i")
	await command("buy_item",str(ammo.ammo_item_id),200,host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO))
	normal_loadout=check(host.state.find("equipment_state","item_instance_id",weapon.item_instance_id)!=null and host.gameplay.inventory.count(host.gameplay.inventory.hold(host.state.ship(),T.ContainerKind.CARGO),str(ammo.ammo_item_id),true)>=200,"normal refit fits actual slots budgets and loaded ammunition")
	if not normal_loadout:await finish();return
	mark("paid-combat-refit")
	if not await drive_mission("civ_join_forge_3"):await finish();return
	await command("join_civilization","faction_deepforge")
	membership_earned=check(host.gameplay.civilizations.allegiance()=="faction_deepforge","three real admission missions earn single allegiance")
	if not membership_earned:await finish();return
	mark("citizenship-earned")
	await command("honor_action","faction_deepforge",1,"register:unregistered")
	examination_registered=check(host.gameplay.honors.instance("faction_deepforge").phase=="assessing","earned rank permits actual commander registration")
	check(host.state.rows("growth_grant_receipt_state").is_empty(),"uncompleted examinations award no outfitting money")
	mark("commander-training-open")
	host.ui.show_page("pause");await settle();await command("save","1",1,"manual")
	var saved: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==1:saved=entry;break
	if not check(not saved.is_empty(),"normal midgame milestone has a manual save"):await finish();return
	var expected: String=SnapshotSignature.saved(host.store,saved.current_snapshot_id)
	await host._command("load",saved.slot_id,saved.generation,saved.current_snapshot_id);host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==expected,"all114 groups and RNG survive normal midgame reload before UI updates")
	check(FileAccess.get_sha256(source)==origin.database_sha256,"original earned source remains unchanged")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(5);await get_tree().create_timer(0.25).timeout
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"completed":completed,"initial_credit":initial_credit,"final_credit":credit,"command_income":earned_credit,"command_spending":spent_credit,"physical_distance_m":moved_m,"actions":actions,"milestones":milestones,"membership_earned":membership_earned,"examination_registered":examination_registered,"normal_loadout":normal_loadout,"scope":"normally earned source, actual Main actions and physics; no progression or clock fixtures; commander exam and later growth continue in the next replay segment"}
	print("NATURAL_MID_V50_FINAL_JSON ",JSON.stringify(summary));print("NATURAL_MID_V50_RESULT ",summary.result," checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
