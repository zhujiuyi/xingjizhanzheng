extends Node
## Normal Main requests and engine physics only. No asset, unlock, pose,
## damage, mission-event, experience or simulation-clock fixtures.
## Headless command replay establishes reachability, not human enjoyment.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
const Codec = preload("res://runtime/data/codec.gd")
const SnapshotSignature=preload("snapshot_signature.gd")
class ObservedMain extends "res://runtime/main.gd":
	var loaded_rows: String=""
	func _prepare_loaded(candidate: XJRuntimeState) -> bool:
		loaded_rows=preload("snapshot_signature.gd").runtime(candidate)
		return super._prepare_loaded(candidate)
var host: Main
var directory: String
var checks: int = 0
var failures: Array[String] = []
var completed: Array[String] = []
var actions: Array[Dictionary] = []
var milestones: Array[Dictionary] = []
var finishing: bool = false
var start_msec: int
var initial_credit: int
var earned_credit: int = 0
var spent_credit: int = 0
var last_objective: String = ""
var last_progress_tick: int = 0
var last_progress: int = -1
var moved_m: float = 0.0
var previous_position: Vector3
var previous_site: String = ""
var previous_ship: String = ""
var verification_only: bool=false

func _ready() -> void:
	get_tree().set_meta("xj_natural_growth_v45_diagnostic", true)
	start_msec = Time.get_ticks_msec()
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
	return ok

func frames(count: int = 2) -> void:
	for frame: int in range(count): await get_tree().process_frame

func settle() -> void:
	while is_instance_valid(host) and host.busy: await get_tree().process_frame
	await frames()

func tick() -> int:
	return int(host.state.snapshot.meta.simulation_tick)

func mark(label: String) -> void:
	var record: Dictionary = {"label":label, "tick":tick(), "credit":host.state.player().credit,
		"sector":host.state.current_sector(), "ship":host.state.ship().ship_def_id,
		"wall_s":(Time.get_ticks_msec()-start_msec)/1000.0}
	milestones.append(record)
	print("NATURAL_MILESTONE ", JSON.stringify(record))

func command(action: String, target: String = "", quantity: int = 1, extra: String = "") -> void:
	await settle()
	var credit: int = host.state.player().credit
	actions.append({"action":action,"target":target,"quantity":quantity,"extra":extra,"tick":tick()})
	await host._command(action,target,quantity,extra)
	await settle()
	var difference: int = host.state.player().credit-credit
	if difference > 0: earned_credit += difference
	else: spent_credit -= difference

func record_distance() -> void:
	var site: String = XJSpaceCoordinates.current_site(host.state)
	var ship: String = host.state.ship().ship_instance_id
	var position: Vector3 = host.gameplay.position(host.state.ship())
	if site==previous_site and ship==previous_ship and not host.local_navigation.warp_active() and not host.travel.active():
		moved_m += position.distance_to(previous_position)
	previous_site=site;previous_ship=ship;previous_position=position

func navigate(info: Dictionary) -> void:
	if host.travel.active() or host.local_navigation.active(): return
	var waypoint: String = str(info.get("waypoint_id",""))
	if not host.world.targets.has(waypoint):
		check(false,"normal guidance has a rendered waypoint: "+JSON.stringify(info));return
	var interaction: Dictionary = host.interaction_context(waypoint)
	if str(info.get("waypoint_kind",""))=="gate" and bool(interaction.get("ready",false)):
		await command("interact_target",waypoint)
	elif str(info.get("objective_kind","")) in ["dock","turnin","deliver"] and str(info.get("waypoint_kind",""))=="station":
		await command("nav_dock",waypoint)
	else:
		await command("mission_travel",str(info.mission_id))

func drive_mission(id: String, loan: String = "") -> bool:
	await command("accept_mission",id)
	if not check(host.gameplay.missions.active()!=null and host.gameplay.missions.active().mission_def_id==id,"normal acceptance "+id): return false
	var instance_id: String=host.gameplay.missions.active().mission_instance_id
	if not loan.is_empty():
		await command("claim_loan",loan)
		if not check(host.state.ship().policy_id=="tutorial_protected","normal contract loan "+loan):return false
	host.ui.show_page("")
	last_objective="";last_progress=-1;last_progress_tick=tick()
	var mission_start: int=tick()
	while failures.is_empty():
		await frames(12)
		record_distance()
		if not check_alive():return false
		var mission: RefCounted=host.state.find("mission_state","mission_instance_id",instance_id)
		if mission!=null and mission.status=="completed":
			completed.append(id);mark("completed:"+id);return true
		if tick()-mission_start>int(host.store.catalog.rule("simulation_hz")*1800.0) or Time.get_ticks_msec()-start_msec>2100000:
			check(false,"normal mission exceeded 30 minutes: "+id);return false
		if host.busy or host.travel.active():continue
		var info: Dictionary=host.gameplay.missions.guidance(id)
		if info.is_empty():check(false,"active mission lacks guidance "+id);return false
		var objective: String=str(info.get("objective_index",-1))+":"+str(info.get("objective_kind",""))+":"+str(info.get("target_id",""))
		var progress: int=int(info.get("progress_units",0))
		if objective!=last_objective or progress!=last_progress:
			last_objective=objective;last_progress=progress;last_progress_tick=tick()
			mark(id+":"+objective+":"+str(progress))
		# A diagnostic has no teleport/reveal shortcut. A real dead end must fail
		# with its navigation/work/interaction reason and retained progress DB.
		if tick()-last_progress_tick>int(host.store.catalog.rule("simulation_hz")*600.0):
			print("NATURAL_STUCK ",JSON.stringify({"guidance":info,"navigation":host.navigation_context(str(info.waypoint_id)),"interaction":host.interaction_context(str(info.waypoint_id)),"work":host.gameplay.last_error,"page":host.ui.page}))
			check(false,"no objective progress for 10 simulated minutes "+objective);return false
		var kind: String=str(info.objective_kind)
		if kind!="collect" and not host.gameplay.work.mining_target.is_empty():await command("stop_mining")
		if host.state.ship().status==T.ShipStatus.DOCKED:
			if kind=="loan_checkout":
				var definition: Dictionary=host.gameplay.missions.objectives(id)[int(info.objective_index)]
				await command("claim_loan",str(definition.target_loan_service_id))
			elif kind in ["turnin","deliver"]:await command("deliver_mission",id)
			else:await command("undock")
			host.ui.show_page("")
			continue
		if kind=="destroy_spawn":
			var target: String=""
			for npc: RefCounted in host.state.rows("npc_state"):
				if npc.spawn_id==str(info.get("spawn_id","")) and npc.alive and host._combat_target_valid(npc.npc_instance_id):target=npc.npc_instance_id;break
			if not target.is_empty():
				if host.auto_fire_target!=target:await command("combat_engage",target)
				continue
		if kind in ["scan_signal","collect"] and str(info.waypoint_id)==str(info.target_id):
			var interaction: Dictionary=host.interaction_context(str(info.target_id))
			var working: bool=host.gameplay.work.scan_target==str(info.target_id) or host.gameplay.work.mining_target==str(info.target_id)
			if working:continue
			if bool(interaction.get("ready",false)):
				await command("interact_target",str(info.target_id));continue
		if kind=="brake_at_anchor" and host.local_navigation.phase=="arrived":continue
		await navigate(info)
	return false

func check_alive() -> bool:
	if host.state.ship().status==T.ShipStatus.DESTROYED:
		check(false,"natural teaching ship destroyed; recovery needs inspection");return false
	return true

func signature() -> String:
	return SnapshotSignature.runtime(host.state)

func verify_checkpoint(source: String) -> void:
	verification_only=true
	var digest: String=OS.get_environment("XJ_NATURAL_GROWTH_V45_CHECKPOINT_SHA256")
	if not check(source.is_absolute_path() and source.contains("/jiaoben/tmp/natural-growth-v45/") and not source.contains("..") and digest.length()==64 and FileAccess.get_sha256(source)==digest,"closed earned checkpoint matches supplied test hash"):await finish();return
	if not check(DirAccess.copy_absolute(source,directory.path_join("progress.db"))==OK,"copy checkpoint without changing original"):await finish();return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"checkpoint Main opens"):await finish();return
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==0:slot=entry;break
	if not check(not slot.is_empty(),"original manual slot exists"):await finish();return
	var saved: String=SnapshotSignature.saved(host.store,slot.current_snapshot_id)
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id);host.ui.show_page("pause");await settle()
	if not check(host.state!=null,"normal checkpoint load activates world"):await finish();return
	check(str(host.get("loaded_rows"))==saved,"all108 durable groups and RNG match before presentation callbacks")
	var after: Dictionary=JSON.parse_string(signature());var original: Dictionary=JSON.parse_string(saved);var changed: Array[String]=[]
	for table: String in original:
		if JSON.stringify(original[table])!=JSON.stringify(after[table]):changed.append(table)
	print("NATURAL_AFTER_PRESENTATION_CHANGED ",JSON.stringify(changed))
	check(changed.all(func(table: String):return table in ["telemetry_menu_state","telemetry_timing_state"]),"only real presentation metrics may accrue after activation")
	for row: RefCounted in host.state.rows("mission_state"):
		if row.status=="completed" and row.reward_claimed:completed.append(row.mission_def_id)
	check(completed.size()==8,"five tutorials and three ordinary contracts remain completed")
	check(host.state.ship().policy_id=="normal_owned" and host.state.ship().ship_def_id=="shuttle_swift","ordinary earned controlled hull remains")
	check(host.gameplay.equipped(host.state.ship()).size()==2,"both paid fitted modules remain")
	check(host.gameplay.crew.assignment("crew_pilot_1")!=null and host.gameplay.crew.member("crew_pilot_1").hire_paid_credit>0,"paid crew and actual assignment remain")
	initial_credit=host.state.player().credit;check(initial_credit==12104,"recorded earned checkpoint balance remains12104")
	check(FileAccess.get_sha256(source)==digest,"original natural checkpoint remains unchanged")
	await finish()

func run() -> void:
	directory=OS.get_environment("XJ_NATURAL_GROWTH_V45_DIRECTORY").replace("\\","/")
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/natural-growth-v45/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")),"fresh scoped natural world"):await finish();return
	var checkpoint: String=OS.get_environment("XJ_NATURAL_GROWTH_V45_CHECKPOINT_SOURCE").replace("\\","/")
	if not checkpoint.is_empty():await verify_checkpoint(checkpoint);return
	host=ObservedMain.new();host.progress_database_path=directory.path_join("progress.db");get_tree().root.add_child(host);await frames(4)
	if not check(host.services_ready,"real Main services ready"):await finish();return
	await host._command("new_world","无注入自然成长",1,"");await settle()
	if not check(host.state!=null and host.world!=null,"normal new-world command"):await finish();return
	initial_credit=host.state.player().credit
	check(host.state.rows("crew_member_state").all(func(c: RefCounted):return c.phase=="available" and c.experience==0),"no hired crew or invented experience")
	mark("fresh-world")
	for id: String in ["tutorial_flight","tutorial_scan_gate","tutorial_mining_delivery","tutorial_combat","tutorial_exploration"]:
		if not await drive_mission(id):await finish();return
	for contract: Dictionary in [{"id":"contract_mining_iron","loan":"loan_contract_miner"},{"id":"contract_survey_echo","loan":"loan_contract_lantern"},{"id":"contract_patrol_echo","loan":"loan_contract_kestrel"}]:
		if not await drive_mission(contract.id,contract.loan):await finish();return
	await command("buy_ship","shuttle_swift")
	var owned: RefCounted
	for ship: RefCounted in host.state.rows("ship_state"):
		if ship.ship_def_id=="shuttle_swift" and ship.policy_id=="normal_owned":owned=ship
	if not check(owned!=null,"earned income buys an ordinary owned hull"):await finish();return
	await command("switch_ship",owned.ship_instance_id)
	var before: Dictionary=host.gameplay.metrics(host.state.ship())
	for module: String in ["module_engine_vector_i","module_scanner_beacon_i"]:
		await command("buy_item",module)
		var item: RefCounted
		for candidate: RefCounted in host.state.rows("item_instance_state"):
			if candidate.item_def_id==module and candidate.policy_id=="normal_owned":item=candidate
		if not check(item!=null,"normal purchase "+module):await finish();return
		await command("fit_module",item.item_instance_id,1,"utility:0" if module.contains("engine") else "utility:1")
		await command("set_module_enabled",item.item_instance_id,1,"on")
	check(host.gameplay.metrics(host.state.ship()).scan_strength>float(before.scan_strength),"paid scanner meaningfully changes owned hull metrics")
	await command("crew_action","crew_pilot_1",1,"hire|"+host.gameplay.crew.token("crew_pilot_1"))
	await command("crew_action","crew_pilot_1",1,"assign|"+host.gameplay.crew.token("crew_pilot_1")+"|"+owned.ship_instance_id)
	check(host.gameplay.crew.assignment("crew_pilot_1")!=null,"naturally funded crew assigned to actual purchased ship")
	mark("earned-hull-refit-and-crew")
	# Freeze through the actual pause page, preserving all simulation rows.
	host.ui.show_page("pause");await settle()
	await command("save","0",1,"manual")
	var slot: Dictionary={}
	for entry: Dictionary in host.store.list_slots():
		if entry.slot_kind=="manual" and int(entry.slot_index)==0:slot=entry;break
	if not check(not slot.is_empty(),"natural world has an ordinary manual save"):await finish();return
	var before_save: String=SnapshotSignature.saved(host.store,slot.current_snapshot_id)
	await host._command("load",slot.slot_id,slot.generation,slot.current_snapshot_id)
	host.ui.show_page("pause");await settle()
	check(str(host.get("loaded_rows"))==before_save,"natural assets, tasks, crew and RNG survive complete108-group load before presentation updates")
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	var credit: int=host.state.player().credit if is_instance_valid(host) and host.state!=null else 0
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"directory":directory,"completed":completed,"initial_credit":initial_credit,"final_credit":credit,"earned_credit":earned_credit,"command_spending":spent_credit,"physical_distance_m":moved_m,"milestones":milestones,"actions":actions,"verification_only":verification_only,"scope":"normal Main command replay; no human enjoyment claim"}
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(6)
	print("NATURAL_GROWTH_V45_FINAL_JSON ",JSON.stringify(summary))
	print("NATURAL_GROWTH_V45_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
