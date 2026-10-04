class_name XJCombatAutomation
extends RefCounted
## Accepted flight-session orders. Catalog/SQLite still owns every combat limit.
const Types = preload("res://contracts/contract_types.gd")
signal changed
signal acquired(target: String)
var options: Dictionary = {"fire": false, "orbit": false, "seek": false}
var target_id: String = ""
var phase: String = "idle"
var status: String = "战斗自动化已关闭"
var host: Node
var _motion_owned: bool = false
var _signature: Array = []

func configure(owner: Node) -> void:
	host = owner
	_publish()

func reset(release_motion: bool = true) -> void:
	if release_motion: _release_motion()
	options = {"fire": false, "orbit": false, "seek": false}
	target_id = ""
	phase = "idle"
	status = "战斗自动化已关闭"
	_motion_owned = false
	_publish()

func lock_target(id: String) -> bool:
	if not host._enemy_target_valid(id): return false
	if target_id != id: _release_motion()
	target_id = id
	_publish()
	return true

func manual_selection(id: String) -> void:
	# Browsing other objects never steals a live combat lock. After a loss,
	# explicitly selecting an enemy can resume an accepted fire/orbit order.
	if not options.seek and (target_id.is_empty() or not host._enemy_target_valid(target_id)) and (options.fire or options.orbit):
		if lock_target(id): tick()

func set_option(key: String, enabled: bool) -> bool:
	if not options.has(key): return false
	options[key] = enabled
	if key == "seek" and enabled:
		_acquire_nearest()
	elif enabled and target_id.is_empty():
		lock_target(str(host.ui.target_id))
	if not options.orbit and not options.seek: _release_motion()
	if key == "orbit" and not enabled and _motion_owned and host.local_navigation.mode == "orbit": _release_motion()
	# Reconcile accepted orders without advancing simulation; checked controls
	# must not retain the previous closed/waiting status until a later frame.
	tick()
	return true

func relinquish_motion() -> void:
	options.orbit = false
	options.seek = false
	_release_motion()
	_publish()

func fire_target() -> String:
	return target_id if options.fire and host._combat_target_valid(target_id) else ""

func tick() -> void:
	if host.state == null or host.world == null: return
	if host.state.ship().status != Types.ShipStatus.FLYING:
		reset()
		return
	if not target_id.is_empty() and not host._enemy_target_valid(target_id):
		_release_motion()
		target_id = ""
	if options.seek and target_id.is_empty(): _acquire_nearest()
	if not options.fire and not options.orbit and not options.seek:
		phase = "idle"
		status = "战斗自动化已关闭"
		_publish()
		return
	if target_id.is_empty():
		phase = "waiting"
		status = "等待可探测敌舰" if options.seek else "请选择敌舰"
		_publish()
		return
	var reach: float = weapon_center_range()
	if reach <= 0.0:
		_release_motion()
		phase = "waiting"
		status = "已锁定敌舰 · 无可用武器"
		_publish()
		return
	var nav: XJLocalNavigation = host.local_navigation
	# The existing navigation tolerance keeps a planned orbit inside usable
	# range instead of repeatedly switching at its exact range boundary.
	var planned_reach: float = maxf(0.0, reach - nav.rules.value("arrival_tolerance_m"))
	var target: Node3D = host.world.targets[target_id].node
	var distance: float = host.world.flight.global_position.distance_to(target.global_position)
	var requested: String = ""
	if options.orbit or options.seek:
		if distance > reach:
			requested = "approach"
		elif options.orbit:
			requested = "orbit"
		elif _motion_owned and nav.active() and nav.mode == "approach" and nav.target_id == target_id:
			# Finish braking at the accepted DB stand-off instead of releasing
			# closing inertia as soon as the first weapon enters its range.
			requested = "approach"
	if not requested.is_empty():
		var same_order: bool = _motion_owned and nav.active() and nav.combat_managed and nav.mode == requested and nav.target_id == target_id and is_equal_approx(nav.combat_distance_m, planned_reach)
		if not same_order:
			if not nav.begin_combat(requested, target_id, planned_reach):
				phase = "waiting"
				status = nav.last_error
				_publish()
				return
			_motion_owned = true
			host.navigation_generation += 1
		phase = requested
		status = ("自动环绕 · " if requested == "orbit" else "自动接近 · ") + str(host.world.targets[target_id].title)
	else:
		if _motion_owned: _release_motion()
		phase = "hold"
		status = host._auto_fire_status(target_id) if options.fire else "已锁定敌舰 · 自动战斗关闭"
	_publish()

func hold_intent() -> void:
	# Track a locked enemy while holding range. Main remains the only owner of
	# the physics step; this method writes intent and never simulates Flight.
	if phase != "hold" or not options.seek or host.local_navigation.active() or not host._enemy_target_valid(target_id): return
	var body: XJFlight = host.world.flight
	var target: Node3D = host.world.targets[target_id].node
	var offset: Vector3 = target.global_position - body.global_position
	if offset.is_zero_approx(): return
	var local: Vector3 = body.global_basis.inverse() * offset.normalized()
	var response: float = float(body.metrics.turn_radps) * host.local_navigation.rules.value("steering_response_s")
	if response <= 0.0: return
	body.intent.yaw_request = clampf(atan2(-local.x, -local.z) / response, -1.0, 1.0)
	body.intent.pitch_request = clampf(atan2(local.y, Vector2(local.x, local.z).length()) / response, -1.0, 1.0)
	body.intent.brake_requested = true

func weapon_center_range() -> float:
	var reach: float = INF
	for equipment: RefCounted in host.gameplay.call("equipped", host.state.ship()):
		var slot: RefCounted = host.state.find("container_state", "container_id", equipment.slot_container_id)
		var item: RefCounted = host.state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
		var definition: Dictionary = host.store.catalog.one("module_defs", "module_id", equipment.module_def_id)
		if slot == null or int(slot.slot_type) != Types.SlotType.WEAPON or not equipment.enabled or item == null or item.durability <= 0.0: continue
		if host.store.catalog.one("weapon_defs", "module_id", equipment.module_def_id).is_empty(): continue
		var range_m: float = float(definition.get("range_m", 0.0))
		if range_m <= 0.0: continue
		var muzzle: Transform3D = host.world.flight.muzzle(slot.slot_index)
		# Triangle inequality keeps every real muzzle within its catalog range,
		# even during bounded alignment. Cooldown does not change this stand-off.
		reach = minf(reach, range_m - muzzle.origin.distance_to(host.world.flight.global_position))
	return maxf(0.0, reach) if is_finite(reach) else 0.0

func _acquire_nearest() -> void:
	var nearest: String = ""
	var distance: float = INF
	for id: String in host.world.targets:
		if not host._enemy_target_valid(id): continue
		var node: Node3D = host.world.targets[id].node
		var candidate: float = host.world.flight.global_position.distance_squared_to(node.global_position)
		if candidate < distance or (candidate == distance and (nearest.is_empty() or id < nearest)):
			nearest = id
			distance = candidate
	if nearest == target_id: return
	_release_motion()
	target_id = nearest
	if not nearest.is_empty(): acquired.emit(nearest)

func _release_motion() -> void:
	if _motion_owned and is_instance_valid(host) and host.local_navigation != null and host.local_navigation.combat_managed and host.local_navigation.active():
		host.local_navigation.release_to_manual(false)
	_motion_owned = false

func _publish() -> void:
	var signature: Array = [options.fire, options.orbit, options.seek, target_id, phase, status]
	if signature == _signature: return
	_signature = signature
	changed.emit()
