extends Node3D
## Local host authority; UI and scenes only submit intent/read typed state.
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
var progress_database_path: String = "user://database/progress.db"
var store: XJGameStore
var state: XJRuntimeState
var gameplay: RefCounted
var world: XJSector
var staged_world: XJSector
var staged_gameplay: RefCounted
var camera: XJCameraRig
var ui: XJUI
var travel: XJTravel
var busy: bool = false
var services_ready: bool = false
var observing: bool = false
var fire_held: bool = false
var last_destroyed_ship: String = ""
var pending_damage: Dictionary = {}
var deferred_save: Dictionary = {}
var autosave_elapsed: float = 0.0
var auto_slot: int = 0
var brake_hold: Dictionary = {}
var preferences: Dictionary = {}
var presentation: XJPresentation
var last_error: String = ""
var save_wait_elapsed: float = 0.0
var previous_page: String = "title"
var weapon_errors: Dictionary = {}
var flight_look := XJFlightLook.new()
var pointer_mode: bool = false
var hangar: XJStationHangar
var presentation_stage: String = ""

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--xj-verify-store"):
		var diagnostic := preload("res://runtime/data/diagnostic.gd")
		get_tree().quit(0 if diagnostic.run(OS.get_environment("XJ_TEST_DATABASE"), arguments.has("--xj-verify-upgrade")) else 1)
		return
	if arguments.has("--xj-validation-profile") or arguments.has("--xj-verify-presentation"):
		var validation_path := OS.get_environment("XJ_TEST_DATABASE").replace("\\", "/")
		if not validation_path.is_absolute_path() or validation_path.contains("..") or not validation_path.contains("/jiaoben/tmp/"):
			push_error("Validation profile requires an absolute jiaoben/tmp database path")
			get_tree().quit(2)
			return
		progress_database_path = validation_path
		if arguments.has("--xj-verify-presentation") and FileAccess.file_exists(validation_path):
			push_error("Presentation diagnostic requires a fresh test database")
			get_tree().quit(2)
			return
	last_error = XJPresentationResources.validate()
	if not last_error.is_empty():
		push_error(last_error)
		get_tree().quit(2)
		return
	_install_input()
	get_tree().auto_accept_quit = false
	get_window().focus_exited.connect(_release_observation)
	ui = XJUI.new()
	add_child(ui)
	ui.requested.connect(_command)
	camera = XJCameraRig.new()
	add_child(camera)
	store = XJGameStore.new(progress_database_path)
	store.status_changed.connect(_store_status)
	if not store.open():
		last_error = store.last_error
		ui.notify("航行档案初始化失败；已有进度保留。详情已写入运行日志。", true)
		push_error(last_error)
		return
	Engine.physics_ticks_per_second = int(store.catalog.rule("simulation_hz"))
	preferences = store.preferences()
	_apply_preferences()
	# Prepare every presentation dependency before publishing a new/load world.
	# It is a hidden exhibition; gameplay state and catalog balance are untouched.
	hangar = XJStationHangar.new()
	hangar.name = "StationExhibition"
	hangar.configure("shuttle_swift", store.catalog)
	add_child(hangar)
	hangar.hide()
	hangar.process_mode = Node.PROCESS_MODE_DISABLED
	if hangar.get_camera() == null:
		last_error = "空间站表现资源初始化失败"
		ui.notify(last_error, true)
		push_error(last_error)
		return
	camera.camera.make_current()
	ui.show_title(store.list_slots())
	services_ready = true
	if arguments.has("--xj-verify-presentation"):
		var diagnostic := preload("res://runtime/presentation_diagnostic.gd")
		var verified: bool = await diagnostic.run(self, progress_database_path.get_base_dir())
		get_tree().quit(0 if verified else 1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui):
		_command("quit", "", 1, "")

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if gameplay != null and gameplay.has_method("dispose"):
		gameplay.call("dispose")
	if staged_gameplay != null and staged_gameplay.has_method("dispose"):
		staged_gameplay.call("dispose")
	if store != null:
		store.close()

func _process(delta: float) -> void:
	if ui != null:
		if not previous_page.is_empty() and ui.page.is_empty(): _center_steering()
		previous_page = ui.page
	_sync_mouse_mode()
	_sync_presentation_stage()
	if not deferred_save.is_empty():
		save_wait_elapsed += delta
		if save_wait_elapsed >= float(store.catalog.rule("save_wait_prompt_s")):
			ui.set_operation_status("save", "保存仍在等待：继续航行、取消保存，或在暂停菜单放弃未保存进度退出", true)
	if world != null:
		var stopped := _paused() or busy
		if presentation != null:
			presentation.process_mode = Node.PROCESS_MODE_DISABLED if stopped else Node.PROCESS_MODE_INHERIT
			presentation.set_paused(stopped)
			if not stopped:
				presentation.consume(delta)
	if ui != null:
		ui.tick(delta)
	if camera != null:
		if state == null or state.ship().status != Types.ShipStatus.DOCKED:
			camera.step(delta)

func _physics_process(delta: float) -> void:
	if state == null or world == null or busy or _paused():
		return
	if not world.sync_entities():
		ui.show_page("pause")
		ui.notify(world.last_error, true)
		return
	var ship := state.ship()
	if ship.ship_instance_id != world.flight.record.ship_instance_id:
		if not world.rebuild_player():
			ui.show_page("pause")
			ui.notify(world.last_error, true)
			return
		camera.bind(world.flight, store.catalog, state.player().camera_mode)
	gameplay.call("begin_step", delta)
	world.flight.metrics = gameplay.call("metrics", ship)
	_read_flight_input(delta)
	gameplay.call("activate_repairs")
	if fire_held and Input.is_action_pressed("fire") and not ui.input_blocked() and ship.status == Types.ShipStatus.FLYING:
		_fire_weapons()
	world.flight.blocked = travel.active() if travel != null else false
	world.flight.simulate(delta)
	world.simulate_npcs(delta)
	world.projectiles.simulate(delta)
	_flush_damage()
	gameplay.call("finish_step", delta)
	_check_objectives(delta)
	if not str(gameplay.call("take_autosave_request")).is_empty():
		_queue_autosave()
		if busy:
			return
	if travel != null and travel.active():
		travel.tick(delta)
		return
	if ship.status == Types.ShipStatus.DESTROYED:
		if last_destroyed_ship != ship.ship_instance_id:
			last_destroyed_ship = ship.ship_instance_id
			ui.notify("舰船已毁，按 Esc 使用救援返回空间站。", true)
	if not deferred_save.is_empty() and _save_block_reason().is_empty():
		var request: Dictionary = deferred_save
		deferred_save = {}
		_save_now(str(request.kind), int(request.index), str(request.get("after", "")))
		return
	autosave_elapsed += delta
	if autosave_elapsed >= float(store.catalog.rule("autosave_interval_s")) and deferred_save.is_empty():
		autosave_elapsed = 0.0
		_queue_autosave()

func _paused() -> bool:
	return ui.menu_open or ui.page in ["pause", "settings", "title"]

func _unhandled_input(event: InputEvent) -> void:
	if state == null or busy:
		return
	if event.is_action_pressed("menu"):
		var next_page := "pause" if ui.page.is_empty() or ui.page == "station" else _home_page()
		if ui.page == "settings": next_page = "pause"
		ui.show_page(next_page)
		_release_observation()
		world.flight.clear_intent()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map"):
		ui.show_page(_home_page() if ui.page == "map" else "map")
	elif event.is_action_pressed("missions"):
		ui.show_page(_home_page() if ui.page == "missions" else "missions")
	elif event.is_action_pressed("quick_save"):
		_request_save("quick", 0)
	elif event.is_action_pressed("quick_load"):
		for slot in store.list_slots():
			if slot.world_id == state.world_id and slot.slot_kind == "quick":
				_command("load", slot.slot_id, slot.generation, slot.current_snapshot_id)
				break
	if event.is_action_pressed("pointer") and not event.is_echo() and ui.page.is_empty():
		pointer_mode = not pointer_mode
		flight_look.clear()
		fire_held = false
		_sync_mouse_mode()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if not ui.keyboard_blocked(): _command("interact", "", 1, "")
		return
	if ui.input_blocked():
		return
	if event.is_action_pressed("camera"):
		camera.cycle_mode()
		state.player().camera_mode = camera.mode
	elif event.is_action_pressed("target"):
		ui.select_next()
	elif event.is_action_pressed("fire"):
		fire_held = not pointer_mode and not observing
	elif event.is_action_released("fire"):
		fire_held = false
	elif event.is_action_pressed("observe"):
		observing = true
		flight_look.clear()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_released("observe"):
		_release_observation()
	elif event is InputEventMouseMotion and observing:
		camera.observe(event.screen_relative, float(preferences.get("mouse_sensitivity", 0.0)))
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not pointer_mode:
		flight_look.add_motion(event.screen_relative, float(preferences.get("mouse_sensitivity", 0.0)))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.scroll_zoom(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.scroll_zoom(1)

func _input(event: InputEvent) -> void:
	# Releases must be observed even when a Control consumes the mouse event.
	if event.is_action_released("fire"):
		fire_held = false
		weapon_errors.clear()
	if event.is_action_released("observe") and observing:
		_release_observation()

func _read_flight_input(delta: float = 0.0) -> void:
	world.flight.clear_intent()
	if ui.input_blocked() or state.ship().status != Types.ShipStatus.FLYING or travel.active():
		fire_held = false
		flight_look.clear()
		return
	var intent := world.flight.intent
	intent.thrust_x = Input.get_axis("left", "right")
	intent.thrust_y = Input.get_axis("down", "up")
	intent.thrust_z = Input.get_axis("back", "forward")
	intent.roll_request = Input.get_axis("roll_left", "roll_right")
	intent.brake_requested = Input.is_action_pressed("brake")
	intent.engine_cycle_requested = Input.is_action_pressed("boost")
	if not observing and not pointer_mode and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var tick_delta := delta if delta > 0.0 else 1.0 / float(Engine.physics_ticks_per_second)
		var turn_request := flight_look.consume(float(world.flight.metrics.turn_radps), tick_delta)
		intent.yaw_request = turn_request.x
		intent.pitch_request = turn_request.y
	if intent.engine_cycle_requested:
		for equipment: Dtos.EquipmentStateDto in state.rows("equipment_state"):
			var slot := state.find("container_state", "container_id", equipment.slot_container_id) as Dtos.ContainerStateDto
			var definition: Dictionary = store.catalog.one("module_defs", "module_id", equipment.module_def_id)
			var item := state.find("item_instance_state", "item_instance_id", equipment.item_instance_id) as Dtos.ItemInstanceStateDto
			if slot != null and slot.ship_instance_id == state.ship().ship_instance_id and equipment.module_def_id.begins_with("module_engine_") and equipment.enabled and item != null and item.durability > 0.0 and equipment.cooldown_remaining_s <= 0.0 and not state.ship().overheated and state.ship().energy >= float(definition.energy_eu) and state.ship().heat + float(definition.heat_hu) <= float(world.flight.metrics.heat_max):
				gameplay.call("act", "request_engine_cycle", "", 1, "")
				break

func _fire_weapons() -> void:
	if travel.active():
		return
	var target_node: Node3D
	if world.targets.has(ui.target_id):
		target_node = world.targets[ui.target_id].node
	for equipment: Dtos.EquipmentStateDto in state.rows("equipment_state"):
		var slot := state.find("container_state", "container_id", equipment.slot_container_id) as Dtos.ContainerStateDto
		if slot == null or slot.ship_instance_id != state.ship().ship_instance_id or slot.slot_type != Types.SlotType.WEAPON:
			continue
		if equipment.cooldown_remaining_s > 0.0:
			continue
		if not equipment.enabled:
			continue
		var origin := world.flight.muzzle(slot.slot_index)
		var direction := -origin.basis.z
		if is_instance_valid(target_node):
			var target_direction := origin.origin.direction_to(target_node.global_position)
			if direction.angle_to(target_direction) <= float(store.catalog.rule("player_weapon_fire_cone_half_angle_rad")):
				direction = target_direction
		var cycle: Dictionary = gameplay.call("consume_weapon_cycle", equipment.item_instance_id)
		if cycle.is_empty():
			var reason: String = str(gameplay.get("last_error"))
			if weapon_errors.get(equipment.item_instance_id, "") != reason:
				ui.notify(reason, true)
				weapon_errors[equipment.item_instance_id] = reason
			continue
		weapon_errors.erase(equipment.item_instance_id)
		world.projectiles.fire(state.ship().ship_instance_id, world.flight.get_rid(), origin.origin, direction, float(cycle.speed) if cycle.get("speed") != null else 0.0, float(cycle.get("range", 0.0)), cycle.get("damage_vector", Vector3.ZERO))

func _weapon_hit(target_id: String, damage: Vector3, point: Vector3, owner_id: String) -> void:
	if target_id == state.ship().ship_instance_id and owner_id != target_id:
		if presentation != null: presentation.hit(target_id, state.ship().shield > 0.0, point)
		pending_damage[target_id] = (pending_damage.get(target_id, Vector3.ZERO) as Vector3) + damage
	elif owner_id == state.ship().ship_instance_id and state.find("npc_state", "npc_instance_id", target_id) != null:
		var npc := state.find("npc_state", "npc_instance_id", target_id) as Dtos.NpcStateDto
		if presentation != null: presentation.hit(target_id, npc.shield > 0.0, point)
		pending_damage[target_id] = (pending_damage.get(target_id, Vector3.ZERO) as Vector3) + damage
	# point is a render position, never a persistence identity.
	if point.is_finite():
		pass

func _flush_damage() -> void:
	for id in pending_damage:
		var raw: Vector3 = pending_damage[id]
		if id == state.ship().ship_instance_id:
			gameplay.call("damage_ship", raw)
		else:
			gameplay.call("damage_npc", id, raw)
			gameplay.call("record_event", "weapon_hit", id, 1)
			ui.notify("命中敌舰 · %.0f" % (raw.x + raw.y + raw.z))
	pending_damage.clear()

func interaction_context(target_id: String = "") -> Dictionary:
	var context = preload("res://runtime/interaction_context.gd")
	if target_id.is_empty(): return context.choose(world, state, store.catalog, gameplay, ui.target_id)
	return context.inspect(world, state, store.catalog, gameplay, target_id)

func _interact(target_id: String = "") -> void:
	if state == null or world == null or travel == null:
		ui.notify("当前没有可交互的舰船。", true)
		return
	if travel.active():
		if not target_id.is_empty():
			ui.notify("虫洞传送正在进行，F 可取消充能。", true)
		elif not travel.cancel():
			ui.notify("跃迁进度正在提交，暂时不能取消。", true)
		return
	# F may choose a nearby eligible object; a mouse command never changes its target.
	var candidate: Dictionary = interaction_context(target_id)
	if not candidate.ready:
		ui.notify(str(candidate.reason), true)
		return
	ui.target_id = str(candidate.target_id)
	if candidate.action == "travel":
		gameplay.call("stop_interactions")
		if not _save_block_reason().is_empty():
			ui.notify("脱离交战并等待设备周期结束后，才能通过虫洞。", true)
			return
		travel.begin(str(candidate.target_id))
	else:
		_command(str(candidate.action), str(candidate.target_id), 1, "")

func _command(action: String, target: String, quantity: int, extra: String) -> void:
	if busy:
		ui.notify("存档操作正在完成，请稍候。")
		return
	match action:
		"interact", "interact_target": _interact(target)
		"new_world":
			if not services_ready:
				ui.notify("存档服务未就绪，无法新建远征。", true)
				return
			busy = true
			ui.set_operation_status("load", "正在建立远征")
			ui.notify("正在建立远征")
			await get_tree().process_frame
			var created := store.new_world(target.strip_edges() if not target.strip_edges().is_empty() else "断航远征", int(Time.get_unix_time_from_system()), _prepare_loaded)
			if created != null:
				_activate(created)
				ui.notify("远征已建立，选择航路与委托开始教学。")
			else:
				_discard_staged()
				ui.notify("新建世界失败，已有档案保留。", true)
				push_error(store.last_error + " " + last_error)
			busy = false
			ui.set_operation_status("idle", "")
		"load":
			busy = true
			ui.set_operation_status("load", "正在验证存档并准备星系")
			ui.notify("验证存档并准备星系")
			await get_tree().process_frame
			var loaded := store.load(target, extra, quantity, _prepare_loaded)
			if loaded != null:
				_activate(loaded)
				ui.notify("存档已读取。")
			else:
				_discard_staged()
				ui.notify("读档失败，当前世界与原档案保留。", true)
				push_error(store.last_error)
			busy = false
			ui.set_operation_status("idle", "")
		"continue":
			busy = true
			ui.set_operation_status("load", "正在恢复上次航行")
			await get_tree().process_frame
			var resumed := store.resume(_prepare_loaded)
			if resumed != null:
				_activate(resumed)
			else:
				_discard_staged()
				ui.notify("恢复航行失败，原档案保留。", true)
				push_error(store.last_error)
			busy = false
			ui.set_operation_status("idle", "")
		"save": _request_save(extra, int(target))
		"cancel_save":
			deferred_save = {}
			ui.set_operation_status("idle", "")
			ui.notify("已取消等待中的保存请求。")
		"quit_without_save":
			deferred_save = {}
			get_tree().quit()
		"hangar_focus":
			if hangar != null and state != null and state.ship().status == Types.ShipStatus.DOCKED:
				hangar.focus_service(target)
		"quit", "return_title":
			if state == null:
				if action == "quit": get_tree().quit()
				return
			_request_save("auto", auto_slot, action)
		"preference":
			var value: Variant = extra if target == "quality_mode" else float(extra)
			if store.set_preference(target, value):
				preferences = store.preferences()
				_apply_preferences()
		_: _business_action(action, target, quantity, extra)

func _business_action(action: String, target: String, quantity: int, extra: String) -> void:
	if state == null or travel.active():
		ui.notify("当前无法执行此操作。", true)
		return
	var previous_ship := state.ship().ship_instance_id
	var actor: RefCounted = gameplay
	var rescue_candidate: XJRuntimeState
	if action == "request_rescue":
		# A rescue may cross sectors. Prepare its complete candidate before publishing.
		rescue_candidate = store.clone_state(state)
		actor = preload("res://runtime/gameplay.gd").new()
		actor.call("setup", rescue_candidate, store.catalog)
	var result: Dtos.ActionResultDto = actor.call("act", action, target, quantity, extra)
	var feedback: String = str(actor.get("status_text")) if result.phase == Types.ActionPhase.APPLIED else str(actor.get("last_error"))
	if rescue_candidate != null:
		actor.call("dispose")
		if result.phase == Types.ActionPhase.APPLIED:
			if not _stage_candidate(rescue_candidate, store.catalog):
				ui.notify("救援目的地暂时无法准备，保留原世界。", true)
				return
			_activate(rescue_candidate)
	if result.phase == Types.ActionPhase.APPLIED:
		if presentation != null: presentation.ui_result(true)
		ui.notify(feedback)
		if state.ship().ship_instance_id != previous_ship and world.flight.record.ship_instance_id != state.ship().ship_instance_id:
			if world.rebuild_player():
				camera.bind(world.flight, store.catalog, state.player().camera_mode)
			else:
				ui.show_page("pause")
				ui.notify(world.last_error, true)
				return
		if action in ["dock", "undock", "switch_ship", "request_rescue"]:
			if world.flight.record.ship_instance_id == state.ship().ship_instance_id:
				world.flight.bind(state.ship(), store.catalog)
			ui.show_page("station" if state.player().has_docked_station_id else "")
		if not result.autosave_request_id.is_empty():
			_queue_autosave()
		ui.refresh_page()
	else:
		if presentation != null: presentation.ui_result(false)
		ui.notify(feedback, true)

func _stage_candidate(candidate: XJRuntimeState, definitions: XJCatalog) -> bool:
	_discard_staged()
	var source := load("res://runtime/gameplay.gd") as Script
	if source == null:
		last_error = "玩法模块加载失败"
		return false
	staged_gameplay = source.new()
	staged_gameplay.call("setup", candidate, definitions)
	staged_world = XJSector.new()
	staged_world.visible = false
	add_child(staged_world)
	if not staged_world.build(candidate, definitions, staged_gameplay):
		last_error = staged_world.last_error
		_discard_staged()
		return false
	return true

func _prepare_loaded(candidate: XJRuntimeState) -> bool:
	return _stage_candidate(candidate, store.staging_catalog)

func _prepare_travel(candidate: XJRuntimeState) -> bool:
	return _stage_candidate(candidate, store.catalog)

func _record_arrival(candidate: XJRuntimeState, connection_id: String) -> void:
	var source := load("res://runtime/gameplay.gd") as Script
	var business: RefCounted = source.new()
	business.call("setup", candidate, store.catalog)
	business.call("record_event", "transit_connection", connection_id, 1)
	if business.has_method("dispose"):
		business.call("dispose")

func _activate(candidate: XJRuntimeState) -> void:
	# All fallible construction happened in staging before the durable boundary.
	if world != null:
		remove_child(world)
		world.queue_free()
	if gameplay != null and gameplay.has_method("dispose"):
		gameplay.call("dispose")
	state = candidate
	world = staged_world
	gameplay = staged_gameplay
	staged_world = null
	staged_gameplay = null
	world.visible = true
	last_destroyed_ship = ""
	presentation = XJPresentation.new()
	world.add_child(presentation)
	presentation.setup(world, gameplay, store.catalog, float(preferences.get("vfx_intensity", 1.0)))
	world.projectiles.hit.connect(_weapon_hit)
	gameplay.call("set_spatial_validator", _spatial_valid)
	travel = XJTravel.new()
	travel.setup(state, store, _prepare_travel, _record_arrival, _travel_stable)
	travel.changed.connect(_travel_changed)
	camera.bind(world.flight, store.catalog, state.player().camera_mode)
	ui.slots = store.list_slots()
	ui.bind(state, store.catalog, gameplay, world, camera)
	presentation_stage = ""
	deferred_save = {}
	brake_hold.clear()
	pending_damage.clear()
	autosave_elapsed = 0.0
	_release_observation()
	_center_steering()
	_sync_presentation_stage()

func _discard_staged() -> void:
	if is_instance_valid(staged_world):
		remove_child(staged_world)
		staged_world.queue_free()
	if staged_gameplay != null and staged_gameplay.has_method("dispose"):
		staged_gameplay.call("dispose")
	staged_world = null
	staged_gameplay = null

func _travel_changed(next_phase: int, message: String) -> void:
	ui.set_operation_status("travel" if travel.active() else "idle", message if travel.active() else "", next_phase == Types.TravelPhase.PREPARING)
	if next_phase == Types.TravelPhase.PREPARING and presentation != null:
		presentation.jump(true)
	ui.notify(message, next_phase == Types.TravelPhase.FAILED)
	if next_phase == Types.TravelPhase.COMMITTED:
		var destination := travel.ready_candidate
		_activate(destination)
		presentation.jump(false)
		ui.notify(message)
	elif next_phase == Types.TravelPhase.FAILED:
		_discard_staged()

func _spatial_valid(from: Vector3, to: Vector3, target: String) -> bool:
	return world.line_of_sight(from, to, world.flight.get_rid(), target)

func _travel_stable() -> bool:
	return world.projectiles.active.is_empty() and bool(gameplay.call("save_eligible"))

func _check_objectives(delta: float) -> void:
	var ship := state.ship()
	if ship.status != Types.ShipStatus.FLYING:
		return
	for mission: Dtos.MissionStateDto in state.rows("mission_state"):
		if mission.status not in ["active", "ready", "ready_to_deliver"]:
			continue
		for definition in store.catalog.rows("mission_objective_defs"):
			if definition.mission_id != mission.mission_def_id or definition.target_anchor_id == null:
				continue
			var anchor: Dictionary = store.catalog.one("anchor_defs", "anchor_id", definition.target_anchor_id)
			if anchor.sector_id != state.current_sector():
				continue
			var in_radius := world.flight.position.distance_to(world.anchor_position(anchor.anchor_id)) <= float(anchor.interaction_radius_m)
			var key := "%s:%d" % [mission.mission_instance_id, definition.objective_index]
			if definition.objective_kind == "reach_anchor" and in_radius:
				gameplay.call("record_event", "reach_anchor", anchor.anchor_id, 1)
			elif definition.objective_kind == "brake_at_anchor":
				if in_radius and world.flight.velocity.length() <= float(definition.max_speed_mps):
					brake_hold[key] = float(brake_hold.get(key, 0.0)) + delta
					if float(brake_hold[key]) >= float(definition.hold_s):
						gameplay.call("record_event", "brake_at_anchor", anchor.anchor_id, 1)
				else:
					brake_hold[key] = 0.0

func _save_block_reason() -> String:
	if state != null and state.ship().status == Types.ShipStatus.DESTROYED: return "舰船已毁，先申请救援"
	if travel != null and travel.active(): return "虫洞传送"
	if world != null and not world.projectiles.active.is_empty(): return "在途弹丸"
	if gameplay != null and not bool(gameplay.call("save_eligible")): return "交战或设备周期"
	return ""

func _request_save(kind: String, index: int, after: String = "") -> void:
	if state == null:
		return
	# Automatic snapshots can merge; they never replace a chosen manual slot or exit.
	if not deferred_save.is_empty() and kind == "auto" and after.is_empty() and (deferred_save.kind != "auto" or not str(deferred_save.get("after", "")).is_empty()):
		return
	var reason := _save_block_reason()
	if not reason.is_empty():
		deferred_save = {"kind": kind, "index": index, "after": after}
		save_wait_elapsed = 0.0
		ui.set_operation_status("save", "等待%s结束后保存；暂停时请先继续航行" % reason, true)
		ui.notify("保存等待：%s。继续航行到稳定边界后保存；原存档保留。" % reason)
		return
	_save_now(kind, index, after)

func _queue_autosave() -> void:
	_request_save("auto", auto_slot)
	auto_slot = (auto_slot + 1) % 3

func _save_now(kind: String, index: int, after: String = "") -> void:
	if busy:
		return
	busy = true
	ui.set_operation_status("save", "正在保存航行进度")
	ui.notify("正在保存航行进度")
	await get_tree().process_frame
	if store.save(state, kind, index):
		if presentation != null and after.is_empty(): presentation.ui_result(true)
		ui.slots = store.list_slots()
		ui.notify("已保存 · " + {"manual": "手动", "auto": "自动", "quick": "快速"}[kind] + " " + str(index + 1))
		if after == "quit":
			get_tree().quit()
		elif after == "return_title":
			remove_child(world)
			world.queue_free()
			world = null
			state = null
			if gameplay != null and gameplay.has_method("dispose"):
				gameplay.call("dispose")
			gameplay = null
			presentation = null
			camera.ship = null
			ui.state = null
			ui.sector = null
			ui.show_title(store.list_slots())
	else:
		ui.notify("保存失败，当前世界与最后成功档保留。", true)
		push_error(store.last_error)
	busy = false
	ui.set_operation_status("idle", "")

func _store_status(_phase: String, message: String) -> void:
	# Storage diagnostics belong in logs. Product feedback uses operation states.
	if not message.is_empty():
		print("Database operation: ", _phase)

func _apply_preferences() -> void:
	ui.preferences = preferences.duplicate(true)
	if preferences.has("master_volume"):
		AudioServer.set_bus_volume_db(0, linear_to_db(float(preferences.master_volume)))
	var quality: String = str(preferences.get("quality_mode", "high"))
	RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X if quality == "high" else RenderingServer.VIEWPORT_MSAA_DISABLED)
	if presentation != null:
		presentation.intensity = float(preferences.get("vfx_intensity", 1.0))

func _release_observation() -> void:
	observing = false
	fire_held = false
	flight_look.clear()
	if camera != null: camera.reset_observation()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if world != null: world.flight.clear_intent()

func _home_page() -> String:
	return "station" if state != null and state.ship().status == Types.ShipStatus.DOCKED else ""

func _sync_mouse_mode() -> void:
	var flight_active := state != null and world != null and ui != null and ui.page.is_empty() and state.ship().status == Types.ShipStatus.FLYING and not busy and get_window().has_focus()
	var desired := Input.MOUSE_MODE_CAPTURED if flight_active and (observing or not pointer_mode) else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != desired:
		flight_look.clear()
		Input.mouse_mode = desired

func _sync_presentation_stage() -> void:
	if state == null or world == null:
		if hangar != null:
			hangar.hide()
			hangar.process_mode = Node.PROCESS_MODE_DISABLED
		presentation_stage = ""
		return
	var docked := state.ship().status == Types.ShipStatus.DOCKED
	if docked:
		if hangar.ship_def_id != state.ship().ship_def_id:
			hangar.change_ship(state.ship().ship_def_id)
		if presentation_stage != "hangar": hangar.focus_service("")
		world.hide()
		hangar.show()
		hangar.process_mode = Node.PROCESS_MODE_DISABLED if _paused() or busy else Node.PROCESS_MODE_INHERIT
		hangar.get_camera().make_current()
		presentation_stage = "hangar"
	else:
		if hangar != null:
			hangar.hide()
			hangar.process_mode = Node.PROCESS_MODE_DISABLED
		if presentation_stage == "hangar": camera.snapped = false
		world.show()
		camera.camera.make_current()
		presentation_stage = "flight"

func _center_steering() -> void:
	if state != null and ui != null and ui.page.is_empty() and state.ship().status == Types.ShipStatus.FLYING:
		fire_held = false
		weapon_errors.clear()
		world.flight.clear_intent()
		flight_look.clear()
		pointer_mode = false
		if camera != null: camera.reset_observation()
		_sync_mouse_mode()

func _install_input() -> void:
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "up": KEY_SPACE, "down": KEY_C, "roll_left": KEY_Q, "roll_right": KEY_E, "brake": KEY_X, "boost": KEY_SHIFT, "interact": KEY_F, "target": KEY_TAB, "camera": KEY_V, "map": KEY_M, "missions": KEY_J, "menu": KEY_ESCAPE, "quick_save": KEY_F5, "quick_load": KEY_F9, "pointer": KEY_ALT}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	for action in ["fire", "observe"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, event)
