class_name XJTravel
extends RefCounted
## Origin and destination are separate durable boundaries, under one barrier.
signal changed(phase: int, message: String)
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
var phase: Types.TravelPhase = Types.TravelPhase.IDLE
var last_error: String = ""
var remaining_s: float = 0.0
var endpoint: Dictionary = {}
var connection: Dictionary = {}
var transfer_id: String = ""
var state: XJRuntimeState
var store: XJGameStore
var catalog: XJCatalog
var ready_candidate: XJRuntimeState
var prepare: Callable
var record_arrival: Callable
var stable: Callable

func setup(runtime: XJRuntimeState, storage: XJGameStore, builder: Callable, arrival: Callable, stability: Callable = Callable()) -> void:
	state = runtime
	store = storage
	catalog = storage.catalog
	prepare = builder
	record_arrival = arrival
	stable = stability
	phase = Types.TravelPhase.IDLE
	ready_candidate = null

func begin(endpoint_id: String) -> bool:
	if active():
		return _fail("虫洞传送正在进行")
	endpoint = catalog.one("gate_endpoint_defs", "endpoint_id", endpoint_id)
	if endpoint.is_empty() or endpoint.origin_sector_id != state.current_sector():
		return _fail("当前星系没有此虫洞入口")
	connection = catalog.one("effective_connection_defs", "connection_id", endpoint.connection_id)
	if connection.is_empty() or not _eligible():
		return false
	transfer_id = XJGameStore.new_id("transfer")
	remaining_s = float(connection.prepare_s)
	phase = Types.TravelPhase.PREPARING
	changed.emit(int(phase), "虫洞充能 · %.1f 秒；F 可取消" % remaining_s)
	return true

func active() -> bool:
	return phase in [Types.TravelPhase.PREPARING, Types.TravelPhase.ACQUIRING_BARRIER, Types.TravelPhase.ORIGIN_SAVING, Types.TravelPhase.DESTINATION_LOADING, Types.TravelPhase.DESTINATION_SAVING]

func cancel() -> bool:
	if phase != Types.TravelPhase.PREPARING:
		return false
	phase = Types.TravelPhase.CANCELLED
	changed.emit(int(phase), "已取消虫洞充能")
	return true

func tick(delta: float) -> void:
	if phase != Types.TravelPhase.PREPARING:
		return
	if not _eligible():
		return
	remaining_s = maxf(0.0, remaining_s - delta)
	if remaining_s <= 0.0:
		_commit()

func _eligible() -> bool:
	if stable.is_valid() and stable.call() != true:
		return _fail("虫洞充能中断：请先脱离交战并等待设备周期结束")
	var ship := state.ship()
	if ship.status != Types.ShipStatus.FLYING:
		return _fail("出港后才能通过虫洞")
	var anchor: Dictionary = catalog.one("anchor_defs", "anchor_id", endpoint.entry_anchor_id)
	var point := Vector3(ship.pos_x, ship.pos_y, ship.pos_z)
	if point.distance_to(Vector3(anchor.x_m, anchor.y_m, anchor.z_m)) > float(catalog.rule("gate_entry_radius_m")):
		return _fail("靠近虫洞入口后再传送")
	if Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length() > float(catalog.rule("gate_max_entry_speed_mps")):
		return _fail("虫洞入口速度过高，按 X 制动")
	if state.find("unlock_state", "unlock_id", endpoint.required_unlock_id) == null:
		return _fail("航门权限未解锁，完成对应任务")
	var gate := state.find("gate_state", "connection_id", connection.connection_id) as Dtos.GateStateDto
	if gate == null:
		return _fail("航门状态不可用")
	if gate.has_lifetime_remaining_s and gate.lifetime_remaining_s <= 0.0:
		return _fail("虫洞寿命已耗尽")
	if not gate.enabled:
		return _fail("航门处于关闭状态")
	var cooldown := state.find("ship_gate_cooldown_state", "ship_instance_id", ship.ship_instance_id) as Dtos.ShipGateCooldownStateDto
	if cooldown != null and cooldown.remaining_s > 0.0:
		return _fail("舰船航门冷却尚未结束")
	var mass := _mass(ship)
	if mass > float(connection.max_gross_mass_kg) or (gate.has_remaining_mass_budget_kg and mass > gate.remaining_mass_budget_kg):
		return _fail("总质量超过航门额度，卸货或换用较小舰船")
	if ship.energy < float(connection.energy_cost_eu) or state.player().credit < int(connection.fee_credit):
		return _fail("航门费用或电容不足")
	for npc: Dtos.NpcStateDto in state.rows("npc_state"):
		if npc.alive and npc.behavior_phase in [Types.NpcPhase.ACQUIRE, Types.NpcPhase.PURSUE, Types.NpcPhase.ATTACK, Types.NpcPhase.DISENGAGE]:
			return _fail("仍处于交战，先脱离敌舰")
	return true

func _mass(ship: Dtos.ShipStateDto) -> float:
	var result: float = float(catalog.one("ship_defs", "ship_id", ship.ship_def_id).dry_mass_kg)
	var containers: Array[String] = []
	for row: Dtos.ContainerStateDto in state.rows("container_state"):
		if row.ship_instance_id == ship.ship_instance_id:
			containers.append(row.container_id)
	for item: Dtos.ItemInstanceStateDto in state.rows("item_instance_state"):
		if containers.has(item.container_id):
			result += float(catalog.one("item_defs", "item_id", item.item_def_id).unit_mass_kg)
	for stack: Dtos.InventoryStackStateDto in state.rows("inventory_stack_state"):
		if containers.has(stack.container_id):
			result += float(catalog.one("item_defs", "item_id", stack.item_def_id).unit_mass_kg) * stack.quantity
	for package: Dtos.SalvagePackageStateDto in state.rows("salvage_package_state"):
		if package.status == "sealed" and package.has_host_container_id and containers.has(package.host_container_id):
			result += float(catalog.one("salvage_package_defs", "package_def_id", package.package_def_id).mass_kg)
	return result

func _commit() -> void:
	if not _eligible():
		return
	phase = Types.TravelPhase.ACQUIRING_BARRIER
	changed.emit(int(phase), "准备跃迁，请稍候")
	if not store.set_transfer_barrier(state, transfer_id):
		_fail("跃迁暂时无法准备，舰船保留在起点")
		return
	var origin := Dtos.TransferStateDto.new()
	origin.transfer_id = transfer_id
	origin.ship_instance_id = state.ship().ship_instance_id
	origin.connection_id = connection.connection_id
	origin.endpoint = Types.TransferEndpoint.ORIGIN
	state.add("transfer_state", origin)
	phase = Types.TravelPhase.ORIGIN_SAVING
	changed.emit(int(phase), "正在保存出发地进度")
	if not store.save_endpoint(state, "travel_origin", transfer_id):
		state.remove("transfer_state", origin)
		store.set_transfer_barrier(state, "")
		_fail("出发存档失败，舰船保留在起点")
		return
	var candidate := store.clone_state(state)
	var ship := candidate.ship()
	var anchor: Dictionary = catalog.one("anchor_defs", "anchor_id", endpoint.exit_anchor_id)
	ship.sector_id = endpoint.target_sector_id
	ship.pos_x = float(anchor.x_m)
	ship.pos_y = float(anchor.y_m)
	ship.pos_z = float(anchor.z_m)
	ship.vel_x = 0.0
	ship.vel_y = 0.0
	ship.vel_z = 0.0
	var attitude := Quaternion(Vector3.UP, float(anchor.yaw_rad))
	ship.quat_x = attitude.x
	ship.quat_y = attitude.y
	ship.quat_z = attitude.z
	ship.quat_w = attitude.w
	ship.energy -= float(connection.energy_cost_eu)
	candidate.player().credit -= int(connection.fee_credit)
	for container: Dtos.ContainerStateDto in candidate.rows("container_state"):
		if container.ship_instance_id == ship.ship_instance_id:
			container.sector_id = ship.sector_id
	var cooldown := candidate.find("ship_gate_cooldown_state", "ship_instance_id", ship.ship_instance_id) as Dtos.ShipGateCooldownStateDto
	if cooldown == null:
		cooldown = Dtos.ShipGateCooldownStateDto.new()
		cooldown.ship_instance_id = ship.ship_instance_id
		candidate.add("ship_gate_cooldown_state", cooldown)
	cooldown.remaining_s = float(connection.cooldown_s)
	var gate := candidate.find("gate_state", "connection_id", connection.connection_id) as Dtos.GateStateDto
	if gate.has_remaining_mass_budget_kg:
		gate.remaining_mass_budget_kg -= _mass(state.ship())
	var visited := candidate.find("sector_state", "sector_id", ship.sector_id) as Dtos.SectorStateDto
	if visited != null:
		visited.visited = true
	var destination := candidate.find("transfer_state", "transfer_id", transfer_id) as Dtos.TransferStateDto
	destination.endpoint = Types.TransferEndpoint.DESTINATION
	if record_arrival.is_valid():
		record_arrival.call(candidate, connection.connection_id)
	phase = Types.TravelPhase.DESTINATION_LOADING
	changed.emit(int(phase), "准备目的星系")
	if not prepare.is_valid() or prepare.call(candidate) != true:
		store.set_transfer_barrier(state, "")
		_fail("目的星系无法加载，原星系与出发存档保留")
		return
	phase = Types.TravelPhase.DESTINATION_SAVING
	changed.emit(int(phase), "正在保存到达地进度")
	if not store.save_endpoint(candidate, "travel_destination", transfer_id):
		store.set_transfer_barrier(state, "")
		_fail("目的地存档失败，保留出发恢复点")
		return
	store.set_transfer_barrier(candidate, "")
	ready_candidate = candidate
	phase = Types.TravelPhase.COMMITTED
	changed.emit(int(phase), "目的地存档已提交，抵达新星系")

func _fail(message: String) -> bool:
	last_error = message
	phase = Types.TravelPhase.FAILED
	changed.emit(int(phase), message)
	return false
