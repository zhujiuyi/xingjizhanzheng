class_name XJGameplay
extends RefCounted
## Single authority for business rules. Movement and ray/projectile hits belong to world.gd.
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Inventory = preload("res://runtime/gameplay/inventory.gd")
const Economy = preload("res://runtime/gameplay/economy.gd")
const Missions = preload("res://runtime/gameplay/missions.gd")
const Work = preload("res://runtime/gameplay/work.gd")
const Encounters = preload("res://runtime/gameplay/encounters.gd")
const Civilizations = preload("res://runtime/gameplay/civilizations.gd")
const Industry = preload("res://runtime/gameplay/industry.gd")
const ResourceIntel = preload("res://runtime/gameplay/resource_intel.gd")
const Exploration = preload("res://runtime/gameplay/exploration.gd")
const MobileBelts = preload("res://runtime/gameplay/mobile_belts.gd")
const Tactics = preload("res://runtime/gameplay/tactics.gd")
const Specializations = preload("res://runtime/gameplay/specializations.gd")
const FittingAnalysis = preload("res://runtime/gameplay/fitting_analysis.gd")
const ShipRoles = preload("res://runtime/gameplay/ship_roles.gd")
const Frontier = preload("res://runtime/gameplay/frontier.gd")
const Projects = preload("res://runtime/gameplay/projects.gd")
const Expeditions = preload("res://runtime/gameplay/expeditions.gd")
const Telemetry = preload("res://runtime/gameplay/telemetry.gd")
const Situational = preload("res://runtime/gameplay/situational.gd")
const Hired = preload("res://runtime/gameplay/hire.gd")
const Honors = preload("res://runtime/gameplay/honors.gd")
const Consignments = preload("res://runtime/gameplay/consignments.gd")
const ResourceBudget = preload("res://runtime/gameplay/resource_budget.gd")
const Operations = preload("res://runtime/gameplay/operations.gd")
const DroneControl = preload("res://runtime/gameplay/drone_control.gd")
const Space = preload("res://runtime/space_coordinates.gd")
var state: XJRuntimeState
var catalog: XJCatalog
var inventory: RefCounted
var economy: RefCounted
var missions: RefCounted
var work: RefCounted
var encounters: RefCounted
var civilizations: RefCounted
var industry: RefCounted
var resource_intel: RefCounted
var exploration: RefCounted
var mobile_belts: RefCounted
var tactics: RefCounted
var specializations: RefCounted
var fitting_analysis: RefCounted
var ship_roles: RefCounted
var frontier: RefCounted
var projects: RefCounted
var expeditions: RefCounted
var telemetry: RefCounted
var situational: RefCounted
var hired: RefCounted
var honors: RefCounted
var consignments: RefCounted
var operations: RefCounted
var drone_control: RefCounted
var events: Array[D.EventDto] = []
var pending_autosave_request_id: String = ""
var status_text: String = ""
var last_error: String = ""
var spatial_validator: Callable
var combat_remaining_s: float = 0.0
var _pending_repairs: Array[Dictionary] = []
var _serial: int = 0
var _definition_cache: Dictionary = {}
var _index_cache: Dictionary = {}
var _rules: Dictionary = {}
var _regeneration_modifiers_present: bool = false
var _step_accumulator: float = 0.0
var _active_payload: RefCounted
var _active_action: D.CommandEnvelopeDto

func setup(world_state: XJRuntimeState, definitions: XJCatalog, preview: bool = false) -> void:
	if inventory != null: dispose()
	state = world_state
	catalog = definitions
	_definition_cache.clear(); _index_cache.clear(); _rules.clear()
	for row in rows("rule_parameters"):
		_rules[row.parameter_id] = row.value_integer if row.value_integer != null else row.value_real
	_regeneration_modifiers_present=false
	for modifier in rows("module_stat_modifiers"):
		if modifier.stat_id in ["shield_max","energy_max","recharge_eu_s","cooling_hu_s","shield_recharge_hp_s"]:_regeneration_modifiers_present=true
	inventory = Inventory.new(self)
	economy = Economy.new(self)
	missions = Missions.new(self)
	work = Work.new(self)
	encounters = Encounters.new(self)
	civilizations = Civilizations.new(self)
	industry = Industry.new(self)
	resource_intel = ResourceIntel.new(self)
	exploration = Exploration.new(self)
	mobile_belts = MobileBelts.new(self)
	tactics = Tactics.new(self)
	drone_control = DroneControl.new(self)
	operations = Operations.new(self)
	specializations = Specializations.new(self)
	fitting_analysis = FittingAnalysis.new(self)
	ship_roles = ShipRoles.new(self)
	consignments = Consignments.new(self)
	honors = Honors.new(self)
	frontier = Frontier.new(self)
	hired = Hired.new(self)
	situational = Situational.new(self)
	projects = Projects.new(self)
	expeditions = Expeditions.new(self)
	telemetry = Telemetry.new(self)
	if preview: return
	# Older snapshots could retain capacity from a disabled passive module.
	# Normalize only the live candidate; sealed historical snapshots stay intact.
	for ship: D.ShipStateDto in state.rows("ship_state"):
		var limits: Dictionary = metrics(ship)
		for layer: String in ["armor", "shield", "hull", "energy"]:
			ship.set(layer, minf(ship.get(layer), float(limits[layer + "_max"])))
	missions.refresh()
	work.ensure_tutorial_supplies()
	_sync_spawns()
	drone_control.sync()

func set_spatial_validator(callback: Callable) -> void:
	spatial_validator = callback

func id(prefix: String) -> String:
	_serial += 1
	return "%s_%s_%d_%d_%d" % [prefix, state.world_id, state.snapshot.meta.simulation_tick, Time.get_ticks_usec(), _serial]

func rows(table: String) -> Array[Dictionary]:
	if not _definition_cache.has(table): _definition_cache[table] = catalog.rows(table)
	return _definition_cache[table]

func definition(table: String, key: String, value: Variant) -> Dictionary:
	# Logical authored anchors resolve through the current saved AU route.
	if table == "anchor_defs" and key == "anchor_id" and mobile_belts != null: value = mobile_belts.resolve(str(value))
	var index_id: String = table + ":" + key
	if not _index_cache.has(index_id):
		var index: Dictionary = {}
		for row in rows(table): index[row[key]] = row
		_index_cache[index_id] = index
	return _index_cache[index_id].get(value, {})

func rule(key: String) -> float:
	var result: Variant = _rules.get(key)
	return float(result) if result != null else 0.0

func unlocked(unlock_id: String) -> bool:
	return state.find("unlock_state", "unlock_id", unlock_id) != null

func grant_unlock(unlock_id: String) -> void:
	if unlocked(unlock_id): return
	var row: D.UnlockStateDto = D.UnlockStateDto.new()
	row.player_id = state.player().player_id
	row.unlock_id = unlock_id
	row.acquired_tick = state.snapshot.meta.simulation_tick
	state.add("unlock_state", row)
	for endpoint in rows("gate_endpoint_defs"):
		if endpoint.required_unlock_id == unlock_id:
			var gate: RefCounted = state.find("gate_state","connection_id",endpoint.connection_id)
			if gate != null: gate.enabled = true

func station() -> String:
	return state.player().docked_station_id if state.player().has_docked_station_id else ""

func spatial_site(kind: String, entity_id: String) -> String:
	return Space.site_for_entity(state, kind, entity_id) if Space.supported(catalog) else ""

func assign_anchor_site(kind: String, entity_id: String, anchor_id: String) -> bool:
	if not Space.supported(catalog): return true
	if mobile_belts != null: anchor_id = mobile_belts.resolve(anchor_id)
	return Space.assign(state, kind, entity_id, Space.site_for_anchor(catalog, anchor_id))

func same_anchor_site(row: RefCounted, anchor: Dictionary) -> bool:
	if row == null or anchor.is_empty(): return false
	if str(row.get("sector_id")) != str(anchor.get("sector_id", "")): return false
	return Space.same_site(state, catalog, Space.row_kind(row), Space.row_id(row), str(anchor.anchor_id))

func same_entity_site(kind_a: String, row_a: RefCounted, kind_b: String, row_b: RefCounted) -> bool:
	if row_a == null or row_b == null or str(row_a.get("sector_id")) != str(row_b.get("sector_id")): return false
	if not Space.supported(catalog): return true
	var a: String = spatial_site(kind_a, Space.row_id(row_a))
	return not a.is_empty() and a == spatial_site(kind_b, Space.row_id(row_b))

func anchor_distance(row: RefCounted, anchor: Dictionary) -> float:
	return Space.anchor_distance(state, catalog, row, anchor)

func entity_distance(kind_a: String, row_a: RefCounted, kind_b: String, row_b: RefCounted) -> float:
	return Space.entity_distance(state, catalog, kind_a, row_a, kind_b, row_b)

func remove_npc(row: D.NpcStateDto) -> void:
	for support: RefCounted in state.rows("remote_support_state").duplicate():
		if support.target_npc_id==row.npc_instance_id:ship_roles.stop_support(support.item_instance_id)
	if row == null: return
	if tactics != null: tactics.retired(row.npc_instance_id)
	Space.remove(state, "npc", row.npc_instance_id)
	state.remove("npc_state", row)

func allowed_service(service: String) -> bool:
	if station().is_empty(): return fail("需要先停靠站点")
	var station_def: Dictionary = definition("station_defs", "station_id", station())
	var anchor: Dictionary = definition("anchor_defs", "anchor_id", str(station_def.get("station_anchor_id", "")))
	if Space.supported(catalog) and (state.ship().status != T.ShipStatus.DOCKED or not same_anchor_site(state.ship(), anchor)): return fail("舰船不在此站点的空间位置")
	for row in rows("station_service_defs"):
		if row.station_id == station() and row.service_id == service:
			return true if unlocked(row.required_unlock_id) else fail("站点服务尚未解锁")
	return fail("此站点不提供服务")

func fail(reason: String) -> bool:
	last_error = reason
	return false

func act(action: String, target: String = "", quantity: int = 1, extra: String = "") -> D.ActionResultDto:
	last_error = ""
	var command: D.CommandEnvelopeDto = D.CommandEnvelopeDto.new()
	command.action_id = id("action")
	command.session.world_id = state.world_id
	command.session.session_id = state.session_id
	command.session.epoch = state.epoch
	command.actor_player_id = state.player().player_id
	command.target_entity_id = target
	command.requested_tick = state.snapshot.meta.simulation_tick
	var names: Array[String] = ["thrust","fire","start_scan","stop_scan","start_mining","stop_mining","dock","undock","switch_ship","move_stack","move_item","fit_module","unfit_module","buy_item","sell_item","buy_ship","sell_ship","repair","manufacture","recycle","accept_mission","abandon_mission","deliver_mission","claim_loan","handoff_loan","request_rescue","start_travel","cancel_travel","save_request","load_request","set_camera","set_module_enabled","request_engine_cycle","research","build_base","recover_resource","pickup_wreck","open_salvage","move_salvage"]
	command.action_kind = names.find(action) if names.has(action) else T.ActionKind.MANUFACTURE
	var civilization_actions: Array[String] = ["join_civilization", "donate_civilization", "start_war", "fleet_command"]
	if civilization_actions.has(action): command.action_kind = T.ActionKind.JOIN_CIVILIZATION + civilization_actions.find(action)
	var industry_actions: Array[String] = ["claim_industry", "cancel_industry", "deliver_demand"]
	if industry_actions.has(action): command.action_kind = T.ActionKind.CLAIM_INDUSTRY + industry_actions.find(action)
	if action == "exploration_action": command.action_kind = T.ActionKind.EXPLORATION_ACTION
	if action == "exploration_research": command.action_kind = T.ActionKind.EXPLORATION_RESEARCH
	if action == "specialization_donate": command.action_kind = T.ActionKind.SPECIALIZATION_DONATE
	if action == "specialization_research": command.action_kind = T.ActionKind.SPECIALIZATION_RESEARCH
	if action == "replace_fit": command.action_kind = T.ActionKind.REPLACE_FIT
	if action == "remote_support": command.action_kind = T.ActionKind.REMOTE_SUPPORT
	if action == "stop_remote_support": command.action_kind = T.ActionKind.STOP_REMOTE_SUPPORT
	if action == "consignment_action": command.action_kind = T.ActionKind.CONSIGNMENT_ACTION
	if action == "honor_action": command.action_kind = T.ActionKind.HONOR_ACTION
	if action == "frontier_action":command.action_kind=T.ActionKind.FRONTIER_ACTION
	if action == "hire_action":command.action_kind=T.ActionKind.HIRE_ACTION
	if action == "construction_action":command.action_kind=T.ActionKind.CONSTRUCTION_ACTION
	if action == "expedition_action":command.action_kind=T.ActionKind.EXPEDITION_ACTION
	if action == "operation_action": command.action_kind = T.ActionKind.OPERATION_ACTION
	if action == "drone_command": command.action_kind = T.ActionKind.DRONE_COMMAND
	if action == "drone_replenish": command.action_kind = T.ActionKind.DRONE_REPLENISH
	_active_action = command
	_active_payload = _request_for(action, target, quantity, extra)
	var ok: bool = false
	if quantity <= 0 or (_rules.has("business_quantity_limit") and quantity > int(_rules.business_quantity_limit)):
		fail("数量超出合法范围")
	else:
		match action:
			"construction_action":
				var parts: PackedStringArray=extra.split("|",true,2)
				ok=projects.execute(target,parts[0],quantity,parts[1],parts[2]) if parts.size()==3 else fail("工程请求格式无效")
			"expedition_action":
				var parts: PackedStringArray=extra.split("|",true,2)
				ok=expeditions.execute(target,parts[0],parts[1],parts[2]) if parts.size()==3 else fail("远征请求格式无效")
			"dock": ok = _dock(target)
			"undock": ok = _undock()
			"switch_ship": ok = _switch(target)
			"buy_item": ok = economy.buy_item(target, quantity, extra)
			"sell_item": ok = economy.sell_item(target, quantity)
			"buy_ship": ok = economy.buy_ship(target)
			"sell_ship": ok = economy.sell_ship(target)
			"move_stack": ok = inventory.move_stack(target, quantity, extra)
			"move_item": ok = inventory.move_item(target, extra)
			"fit_module": ok = inventory.fit(target, quantity - 1, extra)
			"unfit_module": ok = inventory.unfit(target)
			"repair": ok = economy.repair(target)
			"manufacture": ok = economy.manufacture(target, quantity)
			"recycle": ok = economy.recycle(target)
			"research": ok = economy.research(target)
			"build_base": ok = economy.build_base(target)
			"accept_mission": ok = missions.accept(target)
			"abandon_mission": ok = missions.abandon(target)
			"deliver_mission": ok = missions.claim(target)
			"claim_loan": ok = missions.loan(target)
			"handoff_loan": ok = missions.return_loan(target)
			"request_rescue": ok = missions.rescue()
			"start_scan": ok = work.start_scan(target)
			"stop_scan": work.stop_scan(); ok = true
			"start_mining": ok = work.start_mining(target)
			"stop_mining": work.stop_mining(); ok = true
			"recover_resource": ok = work.recover_resource(target, quantity)
			"pickup_wreck": ok = inventory.pickup_wreck(target)
			"open_salvage": ok = encounters.open_package(target)
			"move_salvage": ok = encounters.move_package(target, extra)
			"join_civilization": ok = civilizations.join(target)
			"donate_civilization": ok = civilizations.donate(target, quantity)
			"start_war": ok = civilizations.start_war(target)
			"fleet_command": ok = civilizations.command(target, extra)
			"claim_industry": ok = industry.claim(target)
			"cancel_industry": ok = industry.cancel(target)
			"deliver_demand": ok = industry.deliver(target, quantity, extra)
			"specialization_donate": ok = specializations.donate(quantity)
			"remote_support": ok = ship_roles.start_support(target,extra)
			"stop_remote_support": ok = ship_roles.stop_support(target,false)
			"honor_action":
				var honor_parts: PackedStringArray=extra.split(":")
				ok=honors.execute(target,honor_parts[0],honor_parts[1]) if honor_parts.size()==2 else fail("考核请求缺少操作与阶段")
			"frontier_action":
				var frontier_parts: PackedStringArray=extra.split(":",true,1)
				ok=frontier.execute(target,frontier_parts[0],quantity,frontier_parts[1]) if frontier_parts.size()==2 else fail("边疆请求缺少操作与阶段")
			"hire_action":
				var hire_parts: PackedStringArray=extra.split("|",true,1)
				ok=hired.execute(target,hire_parts[0],hire_parts[1] if hire_parts.size()==2 else "") if quantity==1 else fail("僚舰合同一次只能操作一份")
			"consignment_action":
				var freight_parts: PackedStringArray = extra.split(":")
				ok = consignments.execute(target,freight_parts[0],quantity,freight_parts[1]) if freight_parts.size()==2 else fail("承运请求缺少操作与代次")
			"specialization_research": ok = specializations.research(target,quantity,extra)
			"replace_fit":
				var replace_parts: PackedStringArray=extra.split("|")
				ok=inventory.replace_fit(target,replace_parts[0],replace_parts[1]) if replace_parts.size()==2 else fail("替换请求缺少槽位和原设备")
			"operation_action":
				var parts: PackedStringArray = extra.split(":")
				ok = operations.execute(target,parts[0],parts[1]) if parts.size() == 2 else fail("行动请求缺少动作与代次")
			"exploration_action":
				var parts: PackedStringArray = extra.split(":")
				ok = exploration.execute(target, parts[0], parts[1]) if parts.size() == 2 else fail("探索请求缺少动作与代次")
			"exploration_research": ok = exploration.research(target)
			"drone_command": ok = drone_control.command(extra, target)
			"drone_replenish": ok = drone_control.replenish(target, quantity, extra)
			"set_module_enabled": ok = _set_enabled(target, extra != "off")
			"request_engine_cycle": ok = _engine_cycle()
			_: fail("不支持的动作：" + action)
	var result: D.ActionResultDto = D.ActionResultDto.new()
	result.action_id = command.action_id
	result.session = command.session
	result.action_kind = command.action_kind
	result.phase = T.ActionPhase.APPLIED if ok else T.ActionPhase.REJECTED
	result.reject_code = T.RejectCode.NONE if ok else T.RejectCode.INVALID_STATE
	result.display_reason_key = "操作成功" if ok else last_error
	result.applied_tick = state.snapshot.meta.simulation_tick
	if ok and action not in ["request_engine_cycle","start_scan","stop_scan","start_mining","stop_mining"]:
		result.autosave_request_id = "autosave_" + command.action_id
	var receipt: D.ActionReceiptStateDto = D.ActionReceiptStateDto.new()
	receipt.action_id = command.action_id
	receipt.actor_player_id = command.actor_player_id
	receipt.source_epoch = state.epoch
	receipt.action_kind = action
	receipt.result_code = "applied" if ok else "rejected"
	state.add("action_receipt_state", receipt)
	if ok:
		state.ship().state_version += 1
		missions.refresh()
		if action in ["accept_mission", "abandon_mission", "deliver_mission", "claim_loan", "handoff_loan", "request_rescue"]: _sync_spawns()
		if action != "open_salvage": status_text = "操作完成：" + action
	else: status_text = last_error
	telemetry.wallet()
	return result

func _dock(station_id: String) -> bool:
	var def: Dictionary = definition("station_defs", "station_id", station_id)
	var ship: D.ShipStateDto = state.ship()
	if def.is_empty() or def.sector_id != ship.sector_id: return fail("站点不在当前星区")
	if ship.status != T.ShipStatus.FLYING or in_combat(): return fail("当前不能停靠")
	var anchor: Dictionary = definition("anchor_defs", "anchor_id", def.station_anchor_id)
	if not same_anchor_site(ship, anchor): return fail("需要先跃迁至站点所在地点")
	if anchor_distance(ship, anchor) > rule("dock_radius_m") or velocity(ship).length() > rule("dock_max_speed_mps"): return fail("需进入停靠范围并减速")
	work.stop_scan(); work.stop_mining()
	ship.status = T.ShipStatus.DOCKED
	ship_roles.stop_support()
	ship.has_station_id = true; ship.station_id = station_id
	ship.vel_x = 0; ship.vel_y = 0; ship.vel_z = 0
	state.player().has_docked_station_id = true; state.player().docked_station_id = station_id
	inventory.warehouse(station_id)
	if economy.base_factor("warehouse") > 1: inventory.unload(ship,station_id)
	var m: Dictionary = metrics(ship)
	ship.shield = m.shield_max; ship.energy = m.energy_max; ship.heat = 0; ship.overheated = false
	record_event("dock", station_id, 1)
	missions.cleanup_pending_loans()
	return true

func _undock() -> bool:
	if station().is_empty(): return fail("当前没有停靠")
	var station_id: String = station()
	var def: Dictionary = definition("station_defs", "station_id", station_id)
	var anchor: Dictionary = definition("anchor_defs", "anchor_id", def.undock_anchor_id)
	var ship: D.ShipStateDto = state.ship()
	var station_anchor: Dictionary = definition("anchor_defs", "anchor_id", str(def.get("station_anchor_id", "")))
	if ship.status != T.ShipStatus.DOCKED or not same_anchor_site(ship, station_anchor): return fail("舰船不在当前停靠站点")
	if not assign_anchor_site("ship", ship.ship_instance_id, str(anchor.get("anchor_id", ""))): return fail("出港地点空间定义不可用")
	ship.status = T.ShipStatus.FLYING; ship.has_station_id = false; ship.station_id = ""
	ship.pos_x = anchor.x_m; ship.pos_y = anchor.y_m; ship.pos_z = anchor.z_m
	var rot: Quaternion = Quaternion(Vector3.UP, anchor.yaw_rad)
	ship.quat_x = rot.x; ship.quat_y = rot.y; ship.quat_z = rot.z; ship.quat_w = rot.w
	state.player().has_docked_station_id = false; state.player().docked_station_id = ""
	record_event("undock", station_id, 1)
	return true

func _switch(ship_id: String) -> bool:
	var candidate: D.ShipStateDto = state.find("ship_state", "ship_instance_id", ship_id)
	if station().is_empty() or candidate == null or candidate.status != T.ShipStatus.DOCKED or candidate.station_id != station() or candidate.owner_player_id != state.player().player_id: return fail("只能在同站点换船")
	var station_def: Dictionary = definition("station_defs", "station_id", station())
	var anchor: Dictionary = definition("anchor_defs", "anchor_id", str(station_def.get("station_anchor_id", "")))
	if not same_anchor_site(candidate, anchor): return fail("待切换舰船不在本站空间位置")
	work.stop_scan(); work.stop_mining()
	state.player().controlled_ship_id = ship_id
	return true

func equipped(ship: D.ShipStateDto) -> Array:
	var result: Array = []
	for equipment in state.rows("equipment_state"):
		var container: D.ContainerStateDto = state.find("container_state", "container_id", equipment.slot_container_id)
		if container != null and container.ship_instance_id == ship.ship_instance_id: result.append(equipment)
	result.sort_custom(func(a: RefCounted,b: RefCounted) -> bool:
		var ca: RefCounted = state.find("container_state", "container_id", a.slot_container_id)
		var cb: RefCounted = state.find("container_state", "container_id", b.slot_container_id)
		var pa: Dictionary = definition("module_activation_priority", "module_id", a.module_def_id)
		var pb: Dictionary = definition("module_activation_priority", "module_id", b.module_def_id)
		# Passive modules legally have no activation record. Keep them behind
		# activated modules without inventing a numeric priority in old catalogs.
		if pa.is_empty() != pb.is_empty(): return not pa.is_empty()
		if not pa.is_empty() and int(pa.priority) != int(pb.priority): return int(pa.priority) < int(pb.priority)
		return ca.slot_index < cb.slot_index if ca.slot_index != cb.slot_index else a.item_instance_id < b.item_instance_id)
	return result

func metrics(ship: D.ShipStateDto) -> Dictionary:
	var def: Dictionary = definition("ship_defs", "ship_id", ship.ship_def_id)
	var m: Dictionary = def.duplicate(true)
	m.speed_mps = def.max_speed_mps; m.turn_radps = def.turn_rad_s
	m.energy_recharge = def.recharge_eu_s; m.heat_cooling = def.cooling_hu_s; m.shield_recharge = def.shield_recharge_hp_s
	m.power_used = 0.0; m.cpu_used = 0.0; m.installed_mass_kg = 0.0; m.payload_mass_kg = 0.0
	m.cargo_used_l = 0; m.mineral_used_l = 0
	m.cargo_capacity_l = def.cargo_l; m.mineral_capacity_l = def.mineral_cargo_l
	var resist: Dictionary = {"shield":Vector3.ZERO,"armor":Vector3.ZERO,"hull":Vector3.ZERO}
	for row in rows("ship_resistances"):
		if row.ship_id == ship.ship_def_id: resist[row.layer_id][damage_index(row.damage_type)] = row.resistance
	for e in equipped(ship):
		var mod: Dictionary = definition("module_full_defs", "module_id", e.module_def_id)
		m.power_used += mod.power_pu; m.cpu_used += mod.cpu_cu; m.installed_mass_kg += mod.mass_kg
		var item: D.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", e.item_instance_id)
		if item == null or item.durability <= 0 or not e.enabled: continue
		for change in rows("module_stat_modifiers"):
			if change.module_id != e.module_def_id: continue
			if change.stat_id in ["max_speed_mps","acceleration_mps2","turn_rad_s"] and e.active_remaining_s <= 0: continue
			if change.operation == "add": m[change.stat_id] += change.amount * item.quality_multiplier
			else: m[change.stat_id] *= 1 + (change.amount - 1) * item.quality_multiplier
		for change in rows("module_resistance_modifiers"):
			if change.module_id == e.module_def_id: resist[change.layer_id][damage_index(change.damage_type)] += change.delta
	if specializations != null and specializations.supported():
		m.energy_recharge=m.recharge_eu_s; m.heat_cooling=m.cooling_hu_s; m.shield_recharge=m.shield_recharge_hp_s
	for container in state.rows("container_state"):
		if container.ship_instance_id != ship.ship_instance_id or container.kind == T.ContainerKind.SLOT: continue
		var totals: Dictionary = inventory.totals(container.container_id)
		m.payload_mass_kg += totals.mass
		if container.kind == T.ContainerKind.MINERAL: m.mineral_used_l += totals.volume
		elif container.kind == T.ContainerKind.CARGO: m.cargo_used_l += totals.volume
	m.total_mass_kg = def.dry_mass_kg + m.installed_mass_kg + m.payload_mass_kg
	var mass_factor: float = def.dry_mass_kg / m.total_mass_kg
	m.speed_mps = m.max_speed_mps * sqrt(mass_factor)
	m.acceleration_mps2 *= mass_factor
	m.turn_radps = m.turn_rad_s * sqrt(mass_factor)
	if tactics != null:
		var ratio: float = minf(tactics.thrust_ratio(ship.ship_instance_id),operations.thrust_ratio(ship.ship_instance_id) if operations != null else 1.0)
		m.speed_mps *= ratio; m.acceleration_mps2 *= ratio
	m.brake_multiplier = rule("brake_acceleration_multiplier")
	m.strafe_multiplier = rule("strafe_acceleration_multiplier")
	m.reverse_multiplier = rule("reverse_acceleration_multiplier")
	for layer in resist:
		var v: Vector3 = resist[layer]
		resist[layer] = v.clamp(Vector3.ZERO, Vector3.ONE * rule("resistance_cap"))
	m.resistances = resist
	return m

func _set_enabled(item_id: String, enabled: bool) -> bool:
	var equipment: D.EquipmentStateDto = state.find("equipment_state", "item_instance_id", item_id)
	if equipment == null or not equipped(state.ship()).has(equipment): return fail("模块未在当前船安装")
	equipment.enabled = enabled
	if not enabled:
		work.disable_equipment(item_id)
		ship_roles.stop_support(item_id)
		for repair in _pending_repairs.duplicate():
			if repair.item_id==item_id:_pending_repairs.erase(repair)
		equipment.active_remaining_s=0;equipment.cycle_paid=false
		# Removing permission also removes capacity; enabling never heals damage.
		var limits: Dictionary = metrics(state.ship())
		state.ship().armor = minf(state.ship().armor, limits.armor_max)
		state.ship().shield = minf(state.ship().shield, limits.shield_max)
		state.ship().energy = minf(state.ship().energy, limits.energy_max)
	return true

func pay_cycle(equipment: D.EquipmentStateDto) -> bool:
	var ship: D.ShipStateDto = state.ship()
	var mod: Dictionary = specializations.weapon_spec(equipment,ship)
	if mod.is_empty(): mod=definition("module_defs", "module_id", equipment.module_def_id)
	var item: D.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
	if ship.status != T.ShipStatus.FLYING or not equipment.enabled or equipment.cooldown_remaining_s > 0 or item == null or item.durability <= 0: return fail("设备不可用或冷却中")
	var blocked: String=ResourceBudget.blocked(ship.energy,ship.heat,ship.overheated,metrics(ship).heat_max,mod.energy_eu,mod.heat_hu)
	if not blocked.is_empty():
		if blocked=="热量已达到限制":ship.overheated=true
		return fail(blocked)
	ship.energy -= mod.energy_eu; ship.heat += mod.heat_hu
	equipment.cooldown_remaining_s = mod.cycle_s
	equipment.active_remaining_s = mod.cycle_s
	equipment.cycle_paid = mod.cycle_s > 0
	return true

func weapon_profile(module_id: String) -> Dictionary:
	var weapon: Dictionary = definition("weapon_defs", "module_id", module_id)
	if weapon.is_empty(): return {}
	if catalog.table_names.has("weapon_behavior_defs"):
		var profile: Dictionary = definition("weapon_behavior_defs", "module_id", module_id).duplicate(true)
		if profile.is_empty(): return {}
		profile["projectile_speed_mps"] = 0.0 if weapon.projectile_speed_mps == null else float(weapon.projectile_speed_mps)
		if profile.fire_mode == "drone" and catalog.table_names.has("drone_defs"):
			profile["drone"] = definition("drone_defs", "module_id", module_id).duplicate(true)
		return profile
	# Historical frozen catalogs retain their own physical speed and firing cone.
	return {"module_id": module_id, "family_id": weapon.damage_type, "size_class": 1, "fire_mode": "ray" if weapon.projectile_speed_mps == null else "projectile", "projectile_speed_mps": 0.0 if weapon.projectile_speed_mps == null else float(weapon.projectile_speed_mps), "fire_cone_half_angle_rad": rule("player_weapon_fire_cone_half_angle_rad")}

func weapon_fit_reason(ship: D.ShipStateDto, module_id: String, ignore_item_id: String = "") -> String:
	if not catalog.table_names.has("ship_weapon_permissions"): return ""
	var weapon: Dictionary = definition("weapon_defs", "module_id", module_id)
	if weapon.is_empty(): return ""
	var profile: Dictionary = weapon_profile(module_id)
	if profile.is_empty(): return "缺少武器行为定义"
	var permission: Dictionary = {}
	for row in rows("ship_weapon_permissions"):
		if row.ship_id == ship.ship_def_id and row.family_id == profile.family_id:
			permission = row
			break
	if permission.is_empty(): return "此舰种不支持该武器家族"
	if int(profile.size_class) > int(permission.max_size): return "武器尺寸超过此舰种挂载上限"
	var installed: int = 0
	for equipment in equipped(ship):
		if equipment.item_instance_id == ignore_item_id: continue
		var other: Dictionary = weapon_profile(equipment.module_def_id)
		if not other.is_empty() and other.family_id == profile.family_id: installed += 1
	if installed >= int(permission.max_installed): return "此舰种该武器家族挂载数量已满"
	return ""

func consume_weapon_cycle(item_id: String) -> Dictionary:
	last_error = ""
	var e: D.EquipmentStateDto = state.find("equipment_state", "item_instance_id", item_id)
	if e == null or not equipped(state.ship()).has(e): return {}
	var weapon: Dictionary = definition("weapon_defs", "module_id", e.module_def_id)
	var mod: Dictionary = definition("module_defs", "module_id", e.module_def_id)
	if weapon.is_empty(): return {}
	var compatible: String = weapon_fit_reason(state.ship(), e.module_def_id, item_id)
	if not compatible.is_empty(): fail(compatible); return {}
	var profile: Dictionary = specializations.weapon_spec(e,state.ship())
	if profile.is_empty(): fail("缺少武器行为定义"); return {}
	if profile.fire_mode == "drone" and drone_control.supported() and drone_control.stock(state.ship().ship_instance_id, item_id) <= 0: fail("无人机舱已空，需在空间站补充"); return {}
	var hold: String = inventory.hold(state.ship(), T.ContainerKind.CARGO)
	if weapon.ammo_item_id != null and inventory.count(hold, weapon.ammo_item_id, false) < weapon.ammo_per_cycle:
		fail("弹药不足"); return {}
	if not pay_cycle(e): return {}
	if weapon.ammo_item_id != null: inventory.consume(hold, weapon.ammo_item_id, weapon.ammo_per_cycle, false)
	mark_hostile_attempt()
	var raw: Vector3 = Vector3.ZERO; raw[damage_index(weapon.damage_type)] = profile.raw_damage
	event(T.EventKind.WEAPON_FIRED, state.ship().ship_instance_id, "", item_id)
	telemetry.stat("weapon_cycles")
	return {"damage_vector":raw,"speed":profile.projectile_speed_mps,"range":profile.range_m,"cycle":profile.cycle_s,"damage_type":weapon.damage_type,"module_id":e.module_def_id,"profile":profile}

func mark_hostile_attempt() -> void:
	# A paid shot or an actual NPC fire attempt starts combat even when it misses.
	combat_remaining_s = rule("combat_exit_delay_s")

func _engine_cycle() -> bool:
	for e in equipped(state.ship()):
		if e.module_def_id.begins_with("module_engine_") and pay_cycle(e):
			e.active_remaining_s = definition("module_defs", "module_id", e.module_def_id).cycle_s
			operations.boosted()
			consignments.boosted()
			event(T.EventKind.ENGINE_ACTIVE, state.ship().ship_instance_id, "", e.item_instance_id)
			return true
	return fail("引擎循环不可用")

func tick(delta: float) -> void:
	# Headless/business convenience. The 3D host uses the same phases around input/fire.
	_step_accumulator += delta
	var step: float = 1.0 / rule("simulation_hz")
	while _step_accumulator >= step:
		_step_accumulator -= step
		begin_step(step)
		activate_repairs()
		finish_step(step)

func begin_step(delta: float) -> void:
	state.snapshot.meta.simulation_tick += 1
	combat_remaining_s = maxf(0, combat_remaining_s - delta)
	for repair in _pending_repairs:repair.remaining_s=maxf(0,repair.remaining_s-delta)
	for ship in state.rows("ship_state"):
		if ship.status in [T.ShipStatus.DESTROYED,T.ShipStatus.RETURNED]: continue
		# Dock/create already restore these values. Parked hulls need no mass/fitting scan.
		if not _regeneration_modifiers_present and ship.status==T.ShipStatus.DOCKED and not ship.overheated and ship.heat==0 and ship.shield_delay_remaining_s==0:
			var def:Dictionary=definition("ship_defs","ship_id",ship.ship_def_id)
			if ship.energy==def.energy_max and ship.shield==def.shield_max:continue
		var m: Dictionary = metrics(ship)
		ResourceBudget.advance(ship,m,delta,rule("overheat_unlock_ratio"))
		ship.shield_delay_remaining_s = maxf(0, ship.shield_delay_remaining_s - delta)
		if ship.shield_delay_remaining_s == 0: ship.shield = minf(m.shield_max, ship.shield + m.shield_recharge * delta * (float(exploration.environment().shield) if ship.ship_instance_id == state.ship().ship_instance_id else 1.0))
	for e in state.rows("equipment_state"):
		e.cooldown_remaining_s = maxf(0, e.cooldown_remaining_s - delta)
		e.active_remaining_s = maxf(0, e.active_remaining_s - delta)
		e.cycle_paid = e.active_remaining_s > 0
	for cooldown in state.rows("ship_gate_cooldown_state"): cooldown.remaining_s = maxf(0, cooldown.remaining_s - delta)

func activate_repairs() -> void:
	_tick_repairs()

func finish_step(delta: float) -> void:
	# Must run after engine/repair/weapon activation and aggregated hits.
	for repair in _pending_repairs.duplicate():
		var item:D.ItemInstanceStateDto=state.find("item_instance_state","item_instance_id",repair.item_id)
		if state.ship().ship_instance_id!=repair.ship_id or state.ship().status!=T.ShipStatus.FLYING or item==null:
			_pending_repairs.erase(repair);continue
		if repair.remaining_s>0:continue
		var m:Dictionary=metrics(state.ship())
		state.ship().set(repair.layer,minf(m[repair.layer+"_max"],state.ship().get(repair.layer)+repair.amount))
		_pending_repairs.erase(repair)
	missions.tick(delta)
	work.tick(delta)
	civilizations.tick(delta)
	frontier.tick(delta)
	economy.tick(delta)
	industry.tick(delta)
	exploration.tick(delta)
	tactics.tick(delta)
	operations.tick(delta)
	ship_roles.tick(delta)
	hired.tick(delta)
	consignments.tick(delta)
	drone_control.sync()
	_tick_resources(delta)
	_sync_spawns(delta)
	_tick_gate_lifetimes(delta)
	situational.tick(delta)
	projects.tick(delta)
	expeditions.tick(delta)
	telemetry.tick(delta,not situational.spatial_active)

func _tick_repairs() -> void:
	if state.ship().status != T.ShipStatus.FLYING: return
	for e in equipped(state.ship()):
		var repair: Dictionary = definition("repair_defs", "module_id", e.module_def_id)
		if repair.is_empty() or not e.enabled or e.cooldown_remaining_s > 0: continue
		if ship_roles.reserved(e.item_instance_id): continue
		var pending:bool=false
		for cycle in _pending_repairs:
			if cycle.item_id==e.item_instance_id:pending=true;break
		if pending:continue
		var m: Dictionary = metrics(state.ship())
		if state.ship().get(repair.layer_id) >= m[repair.layer_id + "_max"]: continue
		var hold: String = inventory.hold(state.ship(), T.ContainerKind.CARGO)
		if repair.consumable_item_id != null and inventory.count(hold, repair.consumable_item_id, false) < repair.consumable_per_cycle: continue
		if not pay_cycle(e): continue
		if repair.consumable_item_id != null: inventory.consume(hold, repair.consumable_item_id, repair.consumable_per_cycle, false)
		_pending_repairs.append({"ship_id":state.ship().ship_instance_id,"item_id":e.item_instance_id,"layer":repair.layer_id,"amount":repair.restore_amount,"remaining_s":definition("module_defs","module_id",e.module_def_id).cycle_s})

func _tick_resources(delta: float) -> void:
	for node in state.rows("resource_state"):
		if exploration.managed_resources.has(node.node_id): continue
		if node.remaining_units > 0: continue
		node.respawn_remaining_s = maxf(0, node.respawn_remaining_s - delta)
		if node.respawn_remaining_s == 0: node.remaining_units = definition("resource_node_defs", "node_id", node.node_id).capacity_units

func record_event(kind: String, target: String, quantity: int = 1) -> void:
	missions.record(kind,target,quantity)
	if kind=="undock":telemetry.begin()
	elif kind=="dock":telemetry.finish()
	elif kind=="collect":telemetry.stat("mined_units",float(quantity))

func damage_index(kind: String) -> int:
	return ["kinetic","thermal","pulse"].find(kind)

func apply_damage(victim: RefCounted, raw: Vector3, resist: Dictionary) -> float:
	var total: float = 0.0
	for layer in ["shield","armor","hull"]:
		var effective: Vector3 = raw * (Vector3.ONE - resist[layer])
		var amount: float = effective.x + effective.y + effective.z
		if amount <= 0: break
		var available: float = victim.get(layer)
		var used: float = minf(available, amount)
		victim.set(layer, maxf(0, available - used)); total += used
		if amount <= available: break
		raw *= 1.0 - used / amount
	return total

func damage_contribution(victim: RefCounted,raw: Vector3,resist: Dictionary,credited: Vector3) -> float:
	# Same linear layer allocation as apply_damage, without changing combat.
	var total: float=0.0
	credited=credited.max(Vector3.ZERO).min(raw)
	for layer: String in ["shield","armor","hull"]:
		var effective: Vector3=raw*(Vector3.ONE-resist[layer])
		var contribution: Vector3=credited*(Vector3.ONE-resist[layer])
		var amount: float=effective.x+effective.y+effective.z
		if amount<=0.0:break
		var used: float=minf(float(victim.get(layer)),amount)
		total+=used*(contribution.x+contribution.y+contribution.z)/amount
		if amount<=float(victim.get(layer)):break
		var remainder: float=1.0-used/amount;raw*=remainder;credited*=remainder
	return total

func damage_npc(instance_id: String, raw_vector: Vector3,credited_raw: Vector3=Vector3.ZERO) -> float:
	var npc: D.NpcStateDto = state.find("npc_state", "npc_instance_id", instance_id)
	if npc == null or not npc.alive or not raw_vector.is_finite() : return 0.0
	if operations.handles(npc.spawn_id) and not operations.structure_active(npc): return 0.0
	if Space.supported(catalog) and not same_entity_site("ship", state.ship(), "npc", npc): return 0.0
	var spawn: Dictionary = definition("npc_spawn_defs", "spawn_id", npc.spawn_id)
	var def: Dictionary = definition("npc_full_defs", "npc_id", spawn.npc_id)
	var resist: Dictionary = {"shield":Vector3.ZERO,"armor":Vector3.ZERO,"hull":Vector3.ZERO}
	for r in rows("npc_resistances"):
		if r.archetype_id == def.archetype_id: resist[r.layer_id][damage_index(r.damage_type)] = r.resistance
	var contribution: float=damage_contribution(npc,raw_vector.max(Vector3.ZERO),resist,credited_raw)
	var amount: float = apply_damage(npc, raw_vector.max(Vector3.ZERO), resist)
	telemetry.stat("damage_dealt",contribution)
	mark_hostile_attempt()
	if npc.hull <= 0:
		if contribution>0.0:telemetry.stat("kills")
		npc.alive = false; npc.behavior_phase = T.NpcPhase.DEAD
		tactics.destroyed(npc)
		operations.destroyed(npc)
		frontier.destroyed(npc)
		npc.respawn_remaining_s = float(spawn.respawn_s) if spawn.respawn_s != null else 0.0
		if spawn.bounty_enabled and not npc.bounty_claimed: state.player().credit += def.reward_credit; npc.bounty_claimed = true
		var packaged: bool = encounters.on_destroy(npc)
		if spawn.loot_enabled and not npc.loot_claimed and not packaged:
			var wreck: String = inventory.wreck(npc.sector_id, position(npc), spatial_site("npc", npc.npc_instance_id))
			for loot in rows("npc_loot_defs"):
				if loot.archetype_id == def.archetype_id: inventory.grant(wreck, loot.item_id, loot.quantity, "normal_owned")
			npc.loot_claimed = true
		if packaged: npc.loot_claimed = true
		specializations.tactic_destroyed(npc)
		for support: RefCounted in state.rows("remote_support_state").duplicate():
			if support.target_npc_id == instance_id: ship_roles.stop_support(support.item_instance_id)
		record_event("destroy_spawn", npc.spawn_id, 1)
		event(T.EventKind.SHIP_DESTROYED, instance_id, "")
		request_autosave()
	return amount

func damage_ship(raw_vector: Vector3) -> float:
	var ship: D.ShipStateDto = state.ship()
	if ship.status != T.ShipStatus.FLYING or not raw_vector.is_finite(): return 0
	var amount: float = apply_damage(ship, raw_vector.max(Vector3.ZERO), metrics(ship).resistances)
	telemetry.stat("damage_taken",amount)
	operations.damaged(amount)
	consignments.on_damage(amount)
	ship.shield_delay_remaining_s = rule("shield_recharge_delay_s")
	mark_hostile_attempt()
	ship.state_version += 1
	if ship.hull <= 0:
		ship.status = T.ShipStatus.DESTROYED
		telemetry.finish(true)
		hired.controlled_ship_lost()
		ship_roles.stop_support()
		work.stop_scan(); work.stop_mining()
		inventory.ship_destroyed(ship)
		missions.ship_destroyed(ship)
		event(T.EventKind.SHIP_DESTROYED, ship.ship_instance_id, "")
	return amount

func _sync_spawns(delta: float = 0.0) -> void:
	encounters.tick(delta)
	tactics.sync(delta)
	for spawn in rows("npc_spawn_defs"):
		if tactics.handles(spawn.spawn_id) or operations.handles(spawn.spawn_id): continue
		if exploration.managed_spawns.has(spawn.spawn_id): continue
		if civilizations.handles_spawn(spawn.spawn_id): continue
		if frontier.handles_spawn(spawn.spawn_id):continue
		if hired.handles_spawn(spawn.spawn_id):continue
		if encounters.handles(spawn.spawn_id): continue
		if not unlocked(spawn.required_unlock_id): continue
		var mission: D.MissionStateDto = missions.active_for_target("destroy_spawn", spawn.spawn_id)
		if spawn.occurrence_mode == "mission_scoped" and mission == null:
			for retired in state.rows("npc_state").duplicate():
				if retired.spawn_id == spawn.spawn_id: remove_npc(retired)
			continue
		var existing: D.NpcStateDto = state.find("npc_state", "spawn_id", spawn.spawn_id)
		if existing != null:
			if spawn.occurrence_mode == "mission_scoped" and existing.mission_instance_id != mission.mission_instance_id:
				remove_npc(existing)
				existing = null
		if existing != null:
			if existing.alive: continue
			if spawn.occurrence_mode == "mission_scoped":
				if existing.mission_instance_id == mission.mission_instance_id: continue
				remove_npc(existing)
			else:
				existing.respawn_remaining_s = maxf(0, existing.respawn_remaining_s - delta)
				if spawn.respawn_s == null or existing.respawn_remaining_s > 0: continue
				remove_npc(existing)
		var row: D.NpcStateDto = D.NpcStateDto.new()
		var def: Dictionary = definition("npc_full_defs", "npc_id", spawn.npc_id)
		var anchor: Dictionary = definition("anchor_defs", "anchor_id", spawn.anchor_id)
		row.npc_instance_id = id("npc"); row.spawn_id = spawn.spawn_id; row.sector_id = spawn.sector_id
		row.generation = existing.generation + 1 if existing != null else 0
		row.has_mission_instance_id = mission != null and spawn.occurrence_mode == "mission_scoped"
		row.mission_instance_id = mission.mission_instance_id if row.has_mission_instance_id else ""
		row.alive = true; row.shield = def.shield_max; row.armor = def.armor_max; row.hull = def.hull_max
		row.pos_x = anchor.x_m; row.pos_y = anchor.y_m; row.pos_z = anchor.z_m; row.behavior_phase = T.NpcPhase.PATROL
		state.add("npc_state", row)
		assign_anchor_site("npc", row.npc_instance_id, str(anchor.anchor_id))

func in_combat() -> bool:
	if combat_remaining_s > 0: return true
	for npc in state.rows("npc_state"):
		if same_entity_site("ship", state.ship(), "npc", npc) and npc.alive and npc.behavior_phase in [T.NpcPhase.ACQUIRE,T.NpcPhase.PURSUE,T.NpcPhase.ATTACK,T.NpcPhase.DISENGAGE]: return true
	return false

func save_blocked() -> bool:
	if drone_control != null and not drone_control.live.is_empty(): return true
	for row: RefCounted in state.rows("drone_bay_state"):
		if row.deployed_units > 0: return true
	for row: RefCounted in state.rows("npc_tactic_state"):
		if row.deployed_drones > 0: return true
	if in_combat() or work.busy() or not _pending_repairs.is_empty(): return true
	for e in state.rows("equipment_state"):
		if e.active_remaining_s <= 0: continue
		if ship_roles.reserved(e.item_instance_id): continue # The paid target/cycle is durable.
		var engine: bool = false
		for member in rows("module_group_members"):
			if member.module_id == e.module_def_id and member.group_id == "engine": engine = true
		if not engine: return true
	return false

func event(kind: T.EventKind, source_id: String, target_id: String, module_id: String = "") -> D.EventDto:
	var e: D.EventDto = D.EventDto.new()
	e.event_id = id("event"); e.session.world_id = state.world_id; e.session.session_id = state.session_id; e.session.epoch = state.epoch
	e.simulation_tick = state.snapshot.meta.simulation_tick; e.kind = kind; e.source_entity_id = source_id; e.target_entity_id = target_id; e.module_instance_id = module_id
	events.append(e)
	if events.size() > 256: events.pop_front()
	return e

func position(row: RefCounted) -> Vector3:
	return Vector3(row.pos_x,row.pos_y,row.pos_z)
func velocity(row: RefCounted) -> Vector3:
	return Vector3(row.vel_x,row.vel_y,row.vel_z)
func anchor_position(row: Dictionary) -> Vector3:
	return Vector3(row.x_m,row.y_m,row.z_m)

func save_eligible() -> bool:
	return not save_blocked()
func stop_interactions() -> void:
	work.stop_scan(); work.stop_mining()
	ship_roles.stop_support()
func mission_view() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for def in rows("mission_defs"):
		if def.accept_station_id != station() and not station().is_empty(): continue
		var availability: RefCounted = state.find("mission_availability_state", "mission_def_id", def.mission_id)
		var mission: RefCounted = missions.resolve(def.mission_id)
		var entry: Dictionary = def.duplicate(true)
		entry.status = mission.status if mission != null else availability.status
		entry.instance_id = mission.mission_instance_id if mission != null else ""
		entry.objectives = []
		for objective in missions.objectives(def.mission_id):
			var value: Dictionary = objective.duplicate(true)
			value.progress = missions.progress(mission,objective.objective_index).progress_units if mission != null else 0
			entry.objectives.append(value)
		entry.reward = definition("mission_reward_defs","mission_id",def.mission_id).reward_credit
		rows.append(entry)
	return rows

func dispose() -> void:
	# Explicitly break parent/service references when a world is replaced.
	for service in [inventory,economy,missions,work,encounters,civilizations,industry,resource_intel,exploration,mobile_belts,tactics,drone_control,operations,specializations,fitting_analysis,ship_roles,consignments,honors,frontier,hired,situational,projects,expeditions,telemetry]:
		if service != null: service.g = null
	specializations = null; fitting_analysis = null
	ship_roles = null; consignments = null; honors = null; frontier = null; hired = null; situational = null; projects = null; expeditions = null; telemetry = null
	operations = null
	inventory = null; economy = null; missions = null; work = null; encounters = null; civilizations = null; industry = null; resource_intel = null; exploration = null; mobile_belts = null
	tactics = null; drone_control = null
	pending_autosave_request_id=""; events.clear(); _pending_repairs.clear(); _definition_cache.clear(); _index_cache.clear(); _rules.clear()
	_active_action = null; _active_payload = null; state = null; catalog = null; spatial_validator = Callable()


func _tick_gate_lifetimes(delta: float) -> void:
	for gate in state.rows("gate_state"):
		if not gate.get("has_lifetime_remaining_s") or not gate.enabled: continue
		var discovered: bool = false
		for endpoint in rows("gate_endpoint_defs"):
			if endpoint.connection_id == gate.connection_id and unlocked(endpoint.required_unlock_id): discovered = true
		if not discovered: continue
		gate.lifetime_remaining_s = maxf(0, gate.lifetime_remaining_s - delta)
		if gate.lifetime_remaining_s == 0: gate.enabled = false

func _request_for(action: String, target: String, quantity: int, extra: String) -> RefCounted:
	# UI convenience is converted into reviewed typed requests, never SQL or a JSON protocol.
	if action in ["drone_command", "drone_replenish"]:
		var request: D.DroneCommandRequestDto = D.DroneCommandRequestDto.new()
		request.action = action; request.target_id = target; request.quantity = quantity; request.order_kind = extra if action == "drone_command" else ""; request.quote_revision = extra if action == "drone_replenish" else ""
		return request
	if action in ["join_civilization", "donate_civilization", "start_war", "fleet_command"]:
		var request: D.CivilizationRequestDto = D.CivilizationRequestDto.new()
		request.action = action; request.target_id = target; request.quantity = quantity; request.extra = extra
		return request
	if action in ["buy_item","sell_item"]:
		var request: D.TradeRequestDto = D.TradeRequestDto.new()
		request.station_id = station(); request.item_def_id = target; request.quantity = quantity
		request.destination_container_id = extra
		var item: RefCounted = state.find("item_instance_state","item_instance_id",target)
		var stack: RefCounted = state.find("inventory_stack_state","stack_id",target)
		if item != null: request.has_item_instance_id = true; request.item_instance_id = target; request.item_def_id = item.item_def_id
		if stack != null: request.has_stack_id = true; request.stack_id = target; request.item_def_id = stack.item_def_id
		request.quoted_unit_credit = economy.quote(request.item_def_id,1,action=="sell_item")
		return request
	if action in ["manufacture","recycle","research","build_base"]:
		var request: D.RecipeRequestDto = D.RecipeRequestDto.new()
		request.station_id=station(); request.recipe_id=target; request.batches=quantity
		request.source_container_id=inventory.warehouse(station()) if not station().is_empty() else ""
		request.destination_container_id=request.source_container_id
		if action=="recycle":request.item_instance_ids.append(target)
		return request
	if action in ["accept_mission","abandon_mission","deliver_mission"]:
		var request: D.MissionRequestDto = D.MissionRequestDto.new()
		request.station_id=station(); request.mission_def_id=target
		var mission: RefCounted = missions.resolve(target)
		if mission!=null:request.has_mission_instance_id=true;request.mission_instance_id=mission.mission_instance_id;request.mission_def_id=mission.mission_def_id
		return request
	if action in ["claim_loan","handoff_loan"]:
		var request: D.LoanRequestDto = D.LoanRequestDto.new()
		request.station_id=station();request.loan_service_id=target
		var loan: RefCounted = state.find("loan_state","loan_id",target)
		if loan!=null:request.loan_id=target;request.loan_service_id=loan.loan_service_id
		return request
	if action in ["fit_module","unfit_module"]:
		var request: D.FittingRequestDto = D.FittingRequestDto.new()
		request.ship_instance_id=state.ship().ship_instance_id;request.item_instance_id=target
		var parts: PackedStringArray = extra.split(":")
		if parts.size()==2:request.slot_type=["weapon","work","utility","structure"].find(parts[0]);request.slot_index=int(parts[1])
		return request
	if action in ["move_stack","move_item"]:
		var request: D.InventoryMoveDto = D.InventoryMoveDto.new()
		request.destination_container_id=extra;request.quantity=quantity
		if action=="move_stack":request.has_stack_id=true;request.stack_id=target
		else:request.has_item_instance_id=true;request.item_instance_id=target
		return request
	if action in ["switch_ship","buy_ship","sell_ship","repair","request_rescue","dock","undock"]:
		var request: D.ShipServiceRequestDto = D.ShipServiceRequestDto.new()
		request.station_id=station();request.ship_instance_id=state.ship().ship_instance_id;request.ship_def_id=target
		return request
	var request: D.TargetRequestDto = D.TargetRequestDto.new()
	request.target_entity_id=target
	return request


func request_autosave() -> void:
	if pending_autosave_request_id.is_empty(): pending_autosave_request_id = id("autosave")

func take_autosave_request() -> String:
	var request: String = pending_autosave_request_id
	pending_autosave_request_id = ""
	return request
