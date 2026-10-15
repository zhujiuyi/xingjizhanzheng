extends Node
## Real Main / SQLite / Viewport. Grants, source damage and endpoint placement
## are explicit isolated fixtures. All capacities, policies and assets use the
## production catalog/services; no personal archive is read or written.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Codec = preload("res://runtime/data/codec.gd")
var host: Main
var directory: String
var database_path: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var layouts: int = 0
var gui_transfers: int = 0
var restarts: int = 0
var old_fps: int
var station_id: String
var warehouse: String
var cargo: String
var mineral: String
var controlled_ship_id: String
var parked_ship_id: String
var parked_stack_id: String
var stack_a: String
var stack_b: String
var cargo_stack: String
var mineral_stack: String
var protected_stack: String
var bound_stack: String
var module_id: String
var salvage_id: String
var remote_stations: Array[String] = []
var remote_ids: Array[String] = []
var requested: Array[Dictionary] = []
var root: Window:
	get: return get_tree().root

func _ready() -> void:
	get_tree().create_timer(360.0).timeout.connect(func(): print("WAREHOUSE_TRANSFER_V16_RESULT FAIL watchdog"); get_tree().quit(1))
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func wait_writer(action: String = "GUI transfer") -> bool:
	if not check(is_instance_valid(host), "warehouse wait retains its actual Main " + action): return false
	var started: int = Time.get_ticks_msec()
	var deadline: int = started + 30000
	# Yield real scene frames to Main's asynchronous loading coroutine without
	# resuming simulation or reading Store while its serial worker owns it.
	while is_instance_valid(host) and (host.busy or host.loading_job != null or (host.ui != null and host.ui.loading_suspended) or host.process_mode == Node.PROCESS_MODE_DISABLED) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var complete: bool = is_instance_valid(host) and not host.busy and host.loading_job == null and host.ui != null and not host.ui.loading_suspended and host.process_mode != Node.PROCESS_MODE_DISABLED
	if is_instance_valid(host):
		print("WAREHOUSE_TRANSFER_V16_WAIT " + JSON.stringify({"action": action, "elapsed_ms": Time.get_ticks_msec() - started, "limit_ms": 30000, "busy": host.busy, "loading_job": host.loading_job != null, "loading_suspended": host.ui.loading_suspended if host.ui != null else true, "complete": complete}))
	return check(complete, "actual SQLite writer and loading activation settle within 30 seconds " + action)

func boot() -> bool:
	host = Main.new(); host.progress_database_path = database_path
	root.add_child(host)
	host.set_process(false); host.set_physics_process(false)
	await frames(4)
	if not check(host.services_ready, "real Main opens formal catalog and scoped SQLite"): return false
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): requested.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		var deadline: int = Time.get_ticks_msec() + 30000
		while not root.has_focus() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		if not check(root.has_focus(), "native warehouse has real window focus"): return false
	return true

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(3); await get_tree().create_timer(0.25).timeout

func command(action: String, target: String = "", quantity: int = 1, extra: String = "") -> bool:
	host._command(action, target, quantity, extra)
	await frames(2)
	return await wait_writer(action)

func show() -> void:
	host.ui.show_page("warehouse")
	await frames(5); host.ui.tick(1.0); await frames(3)

func panel() -> Control:
	return host.ui.get("warehouse_panel") as Control

func refs() -> Dictionary:
	var view: Control = panel()
	return view.get("refs") as Dictionary if is_instance_valid(view) else {}

func rows(side: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Dictionary = refs()
	for key: String in ["ship_rows", "station_rows"]:
		if not side.is_empty() and side != key: continue
		for row: Dictionary in data.get(key, []): result.append(row)
	return result

func row_for(id: String) -> Dictionary:
	for row: Dictionary in rows():
		if str(row.get("id", "")) == id: return row
	return {}

func asset_state() -> Dictionary:
	var result: Dictionary = {}
	for table: String in ["container_state", "inventory_stack_state", "item_instance_state", "equipment_state", "salvage_package_state"]:
		var values: Array[String] = []
		for record: RefCounted in host.state.rows(table): values.append(JSON.stringify(Codec.new().encode_row(table, record)))
		values.sort(); result[table] = values
	return result

func totals_by_item() -> Dictionary:
	var result: Dictionary = {}
	for stack: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"):
		var key: String = stack.item_def_id + ":" + stack.policy_id + ":" + stack.bound_mission_instance_id
		result[key] = int(result.get(key, 0)) + stack.quantity
	for item: D.ItemInstanceStateDto in host.state.rows("item_instance_state"):
		result[item.item_instance_id] = [item.item_def_id, item.policy_id, item.durability, item.quality_multiplier, item.origin_kind, item.salvage_recipe_id]
	for package: D.SalvagePackageStateDto in host.state.rows("salvage_package_state"):
		result[package.package_id] = [package.package_def_id, package.source_npc_instance_id, package.source_generation, package.reward_id, package.status]
	return result

func stack(id: String) -> D.InventoryStackStateDto:
	return host.state.find("inventory_stack_state", "stack_id", id) as D.InventoryStackStateDto

func item(id: String) -> D.ItemInstanceStateDto:
	return host.state.find("item_instance_state", "item_instance_id", id) as D.ItemInstanceStateDto

func package(id: String) -> D.SalvagePackageStateDto:
	return host.state.find("salvage_package_state", "package_id", id) as D.SalvagePackageStateDto

func first_grant(container: String, id: String, count: int, policy: String = "normal_owned", mission: String = "") -> String:
	var created: Array = host.gameplay.get("inventory").call("grant", container, id, count, policy, mission)
	return str(created[0]) if not created.is_empty() else ""

func prepare() -> bool:
	if not await command("new_world", "双列表仓储独立验收"): return false
	if not check(host.state != null and host.state.player().has_docked_station_id, "fresh world legally starts at a formal station"): return false
	station_id = host.state.player().docked_station_id
	var inventory: RefCounted = host.gameplay.get("inventory")
	warehouse = str(inventory.call("warehouse", station_id))
	var normal: D.ShipStateDto = inventory.call("create_ship", "miner_anvil", station_id)
	controlled_ship_id = normal.ship_instance_id
	var parked: D.ShipStateDto = inventory.call("create_ship", "shuttle_swift", station_id)
	parked_ship_id = parked.ship_instance_id
	parked_stack_id = first_grant(str(inventory.call("hold", parked, T.ContainerKind.CARGO)), "component_relic_logic", 11)
	await command("switch_ship", controlled_ship_id)
	if not check(host.state.ship().ship_instance_id == controlled_ship_id, "actual switch command selects a legal owned miner"): return false
	cargo = str(inventory.call("hold", host.state.ship(), T.ContainerKind.CARGO))
	mineral = str(inventory.call("hold", host.state.ship(), T.ContainerKind.MINERAL))
	check(not cargo.is_empty() and not mineral.is_empty(), "formal miner has distinct cargo and mineral holds")
	# Many real kinds exercise scrolling. The grants are transparent inventory
	# preparation, rather than claims about earning or manufacturing these goods.
	for definition: Dictionary in host.store.catalog.rows("item_defs"):
		if bool(definition.stackable): first_grant(warehouse, str(definition.item_id), 19)
	stack_a = first_grant(warehouse, "ore_ferrosilicate", 13)
	stack_b = first_grant(warehouse, "ore_conductive_crystal", 9)
	cargo_stack = first_grant(cargo, "ammo_kinetic_slug_i", 12)
	mineral_stack = first_grant(mineral, "ore_ferrosilicate", 5)
	protected_stack = first_grant(cargo, "ammo_kinetic_slug_i", 7, "tutorial_protected")
	await command("accept_mission", "tutorial_flight")
	var mission_id: String
	for mission: D.MissionStateDto in host.state.rows("mission_state"):
		mission_id = mission.mission_instance_id; break
	if not mission_id.is_empty(): bound_stack = first_grant(cargo, "ore_ferrosilicate", 2, "mission_bound", mission_id)
	module_id = first_grant(warehouse, "module_kinetic_needle_i", 1)
	if not module_id.is_empty(): item(module_id).durability = 23.0
	for station: Dictionary in host.store.catalog.rows("station_defs"):
		if str(station.station_id) == station_id: continue
		remote_stations.append(str(station.station_id))
		var remote: String = str(inventory.call("warehouse", str(station.station_id)))
		remote_ids.append(first_grant(remote, "ore_ferrosilicate", 41))
		first_grant(remote, "component_relic_logic", 3)
		if remote_stations.size() == 2: break
	# Destroy a real initialized ambient source to obtain a frozen reward; its
	# endpoint is placed in this warehouse as an explicit transport precondition.
	var encounter_id: String
	for encounter: Dictionary in host.store.catalog.rows("encounter_defs"):
		if str(encounter.sector_id) == host.state.current_sector():
			encounter_id = str(encounter.encounter_id)
			host.gameplay.call("grant_unlock", str(encounter.required_unlock_id)); break
	# Gameplay.tick deliberately ignores nonpositive delta. Use its production
	# initialization entry, as the existing combat fixture does after unlocks.
	host.gameplay.call("_sync_spawns")
	for member: Dictionary in host.store.catalog.rows("encounter_members"):
		if str(member.encounter_id) != encounter_id: continue
		var npc: D.NpcStateDto = host.state.find("npc_state", "spawn_id", str(member.spawn_id)) as D.NpcStateDto
		var definition: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", str(member.spawn_id))
		var mapping: Dictionary = host.store.catalog.one("npc_salvage_defs", "npc_def_id", str(definition.npc_id))
		print("WAREHOUSE_TRANSFER_V16_PACKAGE_SOURCE " + JSON.stringify({"encounter_id": encounter_id, "spawn_id": str(member.spawn_id), "generated": npc != null, "npc_id": npc.npc_instance_id if npc != null else "", "hull": npc.hull if npc != null else -1.0, "package_def": str(mapping.get("package_def_id", "")), "module_id": module_id}))
		if not check(npc != null and npc.alive and not mapping.is_empty(), "official encounter member is initialized with actual package definition"): return false
		var source_id: String = npc.npc_instance_id
		var source_generation: int = npc.generation
		print("WAREHOUSE_TRANSFER_V16_DAMAGE_CONTEXT " + JSON.stringify({"ship_site": host.gameplay.spatial_site("ship", controlled_ship_id), "npc_site": host.gameplay.spatial_site("npc", source_id), "same_site": host.gameplay.same_entity_site("ship", host.state.ship(), "npc", npc), "source_anchor": definition.anchor_id, "fixture": "actual undock then explicit same-site source pose; not natural travel"}))
		# The combat service rejects damage across spatial sites. Keep the official
		# source at its authored site and move the actual flying fixture ship there.
		if not await command("undock"): return false
		if not check(host.state.ship().status == T.ShipStatus.FLYING, "real undock supplies legal flying source-damage precondition"): return false
		if not await place_ship_at_anchor(str(definition.anchor_id), Vector3(0.0, 0.0, 1000.0)): return false
		npc = host.state.find("npc_state", "npc_instance_id", source_id) as D.NpcStateDto
		if not check(npc != null and npc.alive and npc.spawn_id == str(member.spawn_id) and npc.generation == source_generation and host.gameplay.same_entity_site("ship", host.state.ship(), "npc", npc), "official unchanged source and flying ship share the authored combat site"): return false
		var applied: float = float(host.gameplay.call("damage_npc", npc.npc_instance_id, Vector3.ONE * 100000.0))
		print("WAREHOUSE_TRANSFER_V16_DAMAGE_RESULT " + JSON.stringify({"applied": applied, "source_id": source_id, "generation": source_generation, "alive": npc.alive, "hull": npc.hull, "ship_site": host.gameplay.spatial_site("ship", controlled_ship_id), "npc_site": host.gameplay.spatial_site("npc", source_id)}))
		if not check(applied > 0.0 and not npc.alive and is_zero_approx(npc.hull), "actual combat damage destroys the chosen package source"): return false
		for candidate: D.SalvagePackageStateDto in host.state.rows("salvage_package_state"):
			if candidate.source_npc_instance_id == npc.npc_instance_id:
				if not check(candidate.source_generation == source_generation and candidate.package_def_id == str(mapping.package_def_id) and candidate.status == "sealed", "actual damage seals the original source generation and mapped package definition"): return false
				salvage_id = candidate.package_id; candidate.host_container_id = warehouse
		print("WAREHOUSE_TRANSFER_V16_PACKAGE_RESULT " + JSON.stringify({"source_npc": npc.npc_instance_id, "source_hull": npc.hull, "module_id": module_id, "salvage_id": salvage_id, "packages": host.state.rows("salvage_package_state").size()}))
		break
	host.gameplay.call("tick", float(host.store.catalog.rule("combat_exit_delay_s")) + 0.2)
	await station_fixture(station_id)
	if not check(host.state.ship().status == T.ShipStatus.DOCKED and host.state.player().docked_station_id == station_id, "source fixture returns through real docking before warehouse transactions"): return false
	if not check(not module_id.is_empty() and not salvage_id.is_empty() and remote_stations.size() == 2, "fixture retains damaged real equipment, a real frozen salvage package and two remote warehouses"): return false
	print("WAREHOUSE_TRANSFER_V16_FIXTURE funding=none grants=explicit-catalog-services unlocks=explicit-encounter-eligibility hulls=explicit-created kill=real-same-site-aggregate-damage source-pose=explicit-anchor-site actual-undock-dock=true salvage-endpoint=explicit-placement station=" + station_id)
	await show()
	return check(not refs().is_empty(), "production warehouse exposes its real dual-list references")

func scrolls(control: Control) -> Array[ScrollContainer]:
	var result: Array[ScrollContainer] = []
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer: result.append(node)
		node = node.get_parent()
	return result

func reveal(control: Control) -> void:
	for scroll: ScrollContainer in scrolls(control): scroll.ensure_control_visible(control)
	await frames(5)

func visible(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree() or not Rect2(Vector2.ZERO, host.ui.root.size).encloses(control.get_global_rect()): return false
	for scroll: ScrollContainer in scrolls(control):
		if not scroll.get_global_rect().encloses(control.get_global_rect()): return false
	return true

func actual_click(button: Button, expected: Dictionary) -> bool:
	if not check(is_instance_valid(button) and not button.disabled, "legal row action exists " + str(expected.target)): return false
	await reveal(button)
	var before: int = requested.size()
	var initial_panel_id: int = panel().get_instance_id()
	var initial_row: Dictionary = row_for(str(expected.target))
	var initial_amount: SpinBox = initial_row.get("amount") as SpinBox
	var observed: Dictionary = {"count": 0}
	var listener: Callable = func(): observed.count = int(observed.count) + 1
	button.pressed.connect(listener)
	var deadline: int = Time.get_ticks_msec() + 2000
	var stable: int = 0
	var prior: Rect2 = button.get_global_rect()
	while Time.get_ticks_msec() < deadline:
		if DisplayServer.get_name() != "headless" and not root.has_focus(): root.grab_focus()
		var point: Vector2 = button.get_global_rect().get_center()
		host.get_viewport().warp_mouse(point)
		var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
		host.get_viewport().push_input(motion, true)
		await get_tree().process_frame
		var hover: Control = host.get_viewport().gui_get_hovered_control()
		var actual_hover: bool = hover != null and (hover == button or button.is_ancestor_of(hover))
		if DisplayServer.get_name() != "headless": actual_hover = actual_hover and root.has_focus() and button.get_global_rect().has_point(button.get_global_mouse_position())
		var current: Rect2 = button.get_global_rect()
		stable = stable + 1 if current.is_equal_approx(prior) and actual_hover and visible(button) else 0
		prior = current
		if stable >= 2: break
	if not check(stable >= 2, "actual pointer reaches visible row action " + str(expected.target)):
		button.pressed.disconnect(listener); return false
	var press_witness: Dictionary = {"expected": expected, "amount_value": initial_amount.value if is_instance_valid(initial_amount) else -1, "amount_text": initial_amount.get_line_edit().text if is_instance_valid(initial_amount) else "", "page": host.ui.page, "busy": host.busy, "panel_id": panel().get_instance_id(), "initial_panel_id": initial_panel_id, "button_disabled": button.disabled, "focus_owner": str(host.get_viewport().gui_get_focus_owner()), "button_rect": str(button.get_global_rect())}
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		event.position = button.get_global_rect().get_center(); event.global_position = event.position
		host.get_viewport().push_input(event, true)
	await frames(5)
	var settled: bool = await wait_writer(str(expected.action))
	if is_instance_valid(button) and button.pressed.is_connected(listener): button.pressed.disconnect(listener)
	if not settled: return false
	var matched: bool = requested.size() == before + 1
	if matched: matched = requested[-1] == expected
	if int(observed.count) != 1 or not matched:
		press_witness.merge({"pressed_callbacks": observed.count, "request_count_before": before, "request_count_after": requested.size(), "last_request": requested[-1] if not requested.is_empty() else {}, "after_page": host.ui.page, "after_busy": host.busy, "after_panel_id": panel().get_instance_id() if is_instance_valid(panel()) else -1})
		print("WAREHOUSE_TRANSFER_V16_CLICK_MISMATCH " + JSON.stringify(press_witness))
	if check(int(observed.count) == 1 and matched, "actual row click sends its own precise production request " + str(expected.target)):
		gui_transfers += 1; return true
	return false

func transfer(id: String, amount: int, destination: String, typed_text: bool = false) -> bool:
	var row: Dictionary = row_for(id)
	if not check(not row.is_empty(), "current asset has a production row " + id): return false
	var input: SpinBox = row.get("amount") as SpinBox
	if input != null:
		if typed_text:
			await reveal(input)
			var edit: LineEdit = input.get_line_edit()
			edit.grab_focus(); await frames(4)
			edit.select_all()
			for index: int in range(str(amount).length()):
				var character: String = str(amount).substr(index, 1)
				for down: bool in [true, false]:
					var event := InputEventKey.new(); event.keycode = KEY_0 + int(character); event.physical_keycode = event.keycode
					event.unicode = character.unicode_at(0); event.pressed = down
					host.get_viewport().push_input(event, true)
				await frames(1)
			print("WAREHOUSE_TRANSFER_V16_TYPED_WITNESS " + JSON.stringify({"id": id, "expected": amount, "value": input.value, "text": edit.text, "focus_owner": str(host.get_viewport().gui_get_focus_owner()), "panel_id": panel().get_instance_id(), "page": host.ui.page, "busy": host.busy}))
			if not check(host.get_viewport().gui_get_focus_owner() == edit and edit.text == str(amount) and int(input.value) != amount, "actual row keyboard entry remains dirty until transfer activation"): return false
		else: input.value = amount
	await frames(3)
	var action: String = "move_stack" if str(row.kind) == "stack" else "move_item" if str(row.kind) == "item" else "move_salvage"
	return await actual_click(row.get("button") as Button, {"action": action, "target": id, "quantity": amount, "extra": destination})

func list_checks() -> void:
	check(host.ui.quantity_input == null and host.ui.body.find_child("OperationQuantity", true, false) == null, "warehouse removes the detached global operation quantity")
	check(rows("ship_rows").size() >= 3 and rows("station_rows").size() > 20, "cargo and station inventory are distinct populated lists")
	check(row_for(parked_stack_id).is_empty(), "another parked vessel cargo never leaks into current cargo or station lists")
	var seen_remote: bool = false
	var stations_seen: Dictionary = {}
	for row: Dictionary in rows("station_rows"):
		var remote: bool = bool(row.get("remote", false))
		check(remote or not seen_remote, "every current-station asset precedes remote inventory " + str(row.id))
		seen_remote = seen_remote or remote
		check(str(row.row.get_meta("row_id", "")) == str(row.id) and str(row.row.get_meta("container_id", "")) == str(row.container_id), "row keeps exact authoritative asset and container identity " + str(row.id))
		if remote:
			stations_seen[str(row.station_id)] = true
			var station: Dictionary = host.store.catalog.one("station_defs", "station_id", str(row.station_id))
			check(str(row.location.text).contains(str(station.display_name)), "remote location column names its actual station " + str(row.id))
			if str(row.kind) == "stack": check(str(stack(str(row.id)).quantity) in str(row.quantity.text), "remote row displays exact saved holding quantity " + str(row.id))
			check(row.get("amount") == null and row.get("button") == null and not str(row.status.text).is_empty(), "remote asset is read-only with no quantity editor or action " + str(row.id))
			var tint: Color = row.row.modulate * row.row.self_modulate
			var muted: Color = row.name.get_theme_color("font_color") if row.get("name") is Label else row.location.get_theme_color("font_color")
			check(tint.a < 0.9 or maxf(tint.r, maxf(tint.g, tint.b)) < 0.85 or maxf(muted.r, maxf(muted.g, muted.b)) < 0.75, "remote row is visibly subdued " + str(row.id))
		else: check(bool(row.current_station) and str(row.station_id) == station_id and str(row.location.text).contains("当前"), "local location is explicitly current station " + str(row.id))
	check(stations_seen.size() == 2, "both remote station warehouses are visible")
	for id: String in [protected_stack, bound_stack]:
		if id.is_empty(): continue
		var row: Dictionary = row_for(id)
		check(not row.is_empty() and (row.get("button") == null or (row.button as Button).disabled) and not str(row.status.text).is_empty(), "restricted cargo remains visible with no legal transfer " + id)
	var mineral_row: Dictionary = row_for(mineral_stack)
	check(not mineral_row.is_empty() and str(mineral_row.location.text).contains("矿舱"), "left inventory labels mineral-hold contents explicitly")
	var equipment_row: Dictionary = row_for(module_id)
	check(not equipment_row.is_empty() and str(equipment_row.description.text).contains("23"), "damaged independent equipment retains actual durability description")

func movement_checks() -> void:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var before: Dictionary = totals_by_item()
	var row_a: Dictionary = row_for(stack_a)
	var row_b: Dictionary = row_for(stack_b)
	if not check(row_a.get("amount") is SpinBox and row_b.get("amount") is SpinBox, "each normal stack owns a separate operation SpinBox"): return
	host.ui.quantity_value = 7
	row_a.amount.value = 2; row_b.amount.value = 3; await frames(3)
	check(int(row_a.amount.value) == 2 and int(row_b.amount.value) == 3 and host.ui.quantity_value == 7, "editing one row never changes another row or global market quantity")
	var a_before: int = stack(stack_a).quantity
	var b_before: int = stack(stack_b).quantity
	var warehouse_ammo_before: int = int(inventory.call("count", warehouse, "ammo_kinetic_slug_i", true))
	# Keep a different committed value so entering "2" is genuinely dirty text
	# until focus loss/button activation applies this row's editor.
	row_a.amount.value = 1
	if await transfer(stack_a, 2, cargo, true):
		check(stack(stack_a).quantity == a_before - 2 and int(inventory.call("count", cargo, "ore_ferrosilicate", true)) == 2, "typed row quantity is applied before click and only that item moves")
		check(stack(stack_b).quantity == b_before and host.ui.quantity_value == 7, "first move leaves unrelated asset and market quantity unchanged")
		var restored_b: Dictionary = row_for(stack_b)
		check(not restored_b.is_empty() and int(restored_b.amount.value) == 3, "successful transfer refresh retains another row's independent pending amount")
	await show()
	if await transfer(stack_b, 3, cargo): check(stack(stack_b).quantity == b_before - 3 and int(inventory.call("count", cargo, "ore_conductive_crystal", true)) == 3, "second item transfers its own amount")
	await show()
	if await transfer(cargo_stack, 4, warehouse): check(stack(cargo_stack).quantity == 8 and int(inventory.call("count", warehouse, "ammo_kinetic_slug_i", true)) == warehouse_ammo_before + 4, "left cargo button unloads exactly its own quantity to current warehouse")
	await show()
	var old_row: Dictionary = row_for(mineral_stack)
	var old_button: WeakRef = weakref(old_row.button)
	if await transfer(mineral_stack, 5, warehouse): check(stack(mineral_stack) == null and row_for(mineral_stack).is_empty(), "full mineral-hold transfer removes its empty source row")
	var no_more: Dictionary = asset_state()
	var old_control: Button = old_button.get_ref() as Button
	if old_control != null: old_control.pressed.emit(); await frames(3)
	check(asset_state() == no_more, "stale removed row cannot transfer a different item")
	await show()
	for id: String in [module_id, salvage_id]:
		var row: Dictionary = row_for(id)
		var input: SpinBox = row.get("amount") as SpinBox
		check(input == null or (is_equal_approx(input.min_value, 1.0) and is_equal_approx(input.max_value, 1.0) and int(input.value) == 1), "individual equipment or sealed package uses fixed quantity one " + id)
		if input != null:
			input.value = 99
			check(int(input.value) == 1, "independent asset amount cannot exceed one " + id)
		if await transfer(id, 1, cargo):
			check((item(id).container_id if id == module_id else package(id).host_container_id) == cargo, "real independent asset enters current cargo " + id)
		await show()
		if await transfer(id, 1, warehouse): check((item(id).container_id if id == module_id else package(id).host_container_id) == warehouse, "same independent asset returns to current warehouse " + id)
		await show()
	check(totals_by_item() == before, "all GUI transfers conserve goods, protection, reward identity, durability and quality")
	host.ui.show_page("market"); await frames(4)
	check(host.ui.quantity_input == null and host.ui.quantity_value == 7 and not host.ui.quotes.is_empty() and int((host.ui.quotes[0].get("amount") as SpinBox).value) == 1, "market row quantity remains independent of warehouse and unused legacy quantity")
	await show()

func reject(action: String, target: String, amount: int, destination: String, label: String) -> void:
	var before: Dictionary = asset_state()
	var kind: String = "stack" if action == "move_stack" else "item" if action == "move_item" else "salvage"
	var quote: Dictionary = host.gameplay.get("inventory").call("quote_transfer", kind, target, amount, destination)
	check(not bool(quote.get("ok", false)) and not str(quote.get("reason", "")).is_empty(), "fresh production transfer qualification rejects " + label)
	# Main's warehouse boundary rechecks policy/service/source/destination. The
	# lower-level inventory move also serves legal mission migrations elsewhere.
	await command(action, target, amount, destination)
	check(asset_state() == before, "rejection preserves all exact inventory records " + label)

func rejection_checks() -> void:
	for id: String in remote_ids:
		await reject("move_stack", id, 1, cargo, "forged remote station source " + id)
	for id: String in [protected_stack, bound_stack]:
		if not id.is_empty(): await reject("move_stack", id, 1, warehouse, "restricted source " + id)
	await reject("move_stack", stack_a, 0, cargo, "zero quantity")
	await reject("move_stack", stack_a, -1, cargo, "negative quantity")
	await reject("move_stack", stack_a, stack(stack_a).quantity + 1, cargo, "quantity above source stock")
	await reject("move_stack", stack_a, 1, str(stack(remote_ids[0]).container_id), "forged remote station destination")
	await reject("move_stack", stack_a, 1, str(stack(parked_stack_id).container_id), "another parked vessel destination")
	var inventory: RefCounted = host.gameplay.get("inventory")
	var room: int = int(inventory.call("room", cargo, "ammo_kinetic_slug_i", 1000000))
	if check(room > 0, "volume fixture derives remaining capacity from real hull metrics"):
		first_grant(cargo, "ammo_kinetic_slug_i", room)
		await show()
		var row: Dictionary = row_for(stack_a)
		check(not row.is_empty() and row.get("button") != null and (row.button as Button).disabled and not str(row.status.text).is_empty(), "volume-full cargo disables its actual row action with reason")
		await reject("move_stack", stack_a, 1, cargo, "full cargo volume")
		check(bool(inventory.call("consume", cargo, "ammo_kinetic_slug_i", room)), "volume fixture releases exactly its explicit filler")
	var mass_room: int = int(inventory.call("room", mineral, "ore_pressure_steel", 1000000))
	if check(mass_room > 0, "mass fixture derives admissible ore units from actual payload and mineral capacity"):
		first_grant(mineral, "ore_pressure_steel", mass_room)
		var weapon_frame: String
		for candidate: D.InventoryStackStateDto in host.state.rows("inventory_stack_state"):
			if candidate.container_id == warehouse and candidate.item_def_id == "component_weapon_frame" and candidate.policy_id == "normal_owned": weapon_frame = candidate.stack_id; break
		await show()
		var row: Dictionary = row_for(weapon_frame)
		check(not row.is_empty() and row.get("button") != null and (row.button as Button).disabled and str(row.status.text).contains("载荷"), "shared payload-full hull disables warehouse loading with visible reason")
		await reject("move_stack", weapon_frame, 1, cargo, "full total payload across both holds")
		check(bool(inventory.call("consume", mineral, "ore_pressure_steel", mass_room)), "mass fixture releases exactly its explicit filler")
	await show()

func label_fits(label: Label) -> bool:
	if label == null or label.text.is_empty(): return false
	return label.size.y + 1.0 >= label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")) * maxi(1, label.get_line_count())

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4); await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if check(not image.is_empty() and image.save_png(directory.path_join(label + ".png")) == OK, "native warehouse capture " + label): captures += 1

func rect_values(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func surface_observation(suffix: String) -> void:
	var panes: Array[Dictionary] = []
	for column: Dictionary in refs().get("columns", []):
		var records: Array = rows("ship_rows" if column.scroll == refs().ship_scroll else "station_rows")
		var first: Dictionary = {}
		if not records.is_empty():
			for field: String in ["row", "name", "quantity", "amount", "button", "claim"]:
				var control: Control = records[0].get(field) as Control
				if is_instance_valid(control): first[field] = {"rect": rect_values(control.get_global_rect()), "minimum": [control.get_combined_minimum_size().x, control.get_combined_minimum_size().y]}
		panes.append({"frame": rect_values(column.column.get_global_rect()), "frame_minimum": [column.column.get_combined_minimum_size().x, column.column.get_combined_minimum_size().y], "scroll": rect_values(column.scroll.get_global_rect()), "heading": rect_values(column.heading.get_global_rect()), "header_visible": column.header_frame.is_visible_in_tree(), "vertical": column.scroll.scroll_vertical, "horizontal": column.scroll.scroll_horizontal, "first": first})
	print("WAREHOUSE_TRANSFER_V16_SURFACES " + JSON.stringify({"layout": suffix, "logical_root": rect_values(host.ui.root.get_global_rect()), "native_size": [root.size.x, root.size.y], "panel": rect_values(host.ui.panel.get_global_rect()), "page_scroll": rect_values(host.ui.page_scroll.get_global_rect()), "page_vertical": host.ui.page_scroll.scroll_vertical, "warehouse": rect_values(panel().get_global_rect()), "warehouse_minimum": [panel().get_combined_minimum_size().x, panel().get_combined_minimum_size().y], "stacked": panel().get_meta("stacked_panes", false), "shallow": panel().get_meta("shallow_stacked", false), "panes": panes}))

func layout_checks() -> void:
	for layout: Dictionary in [{"size": Vector2i(1440, 900), "scale": 1.0}, {"size": Vector2i(1280, 720), "scale": 1.0}, {"size": Vector2i(1440, 900), "scale": 2.0}, {"size": Vector2i(1280, 720), "scale": 2.0}]:
		root.size = layout.size; root.content_scale_size = Vector2i(Vector2(layout.size) / float(layout.scale))
		await show()
		var suffix: String = "%dx%d-%d" % [layout.size.x, layout.size.y, int(float(layout.scale) * 100)]
		var data: Dictionary = refs()
		var left: ScrollContainer = data.get("ship_scroll") as ScrollContainer
		var right: ScrollContainer = data.get("station_scroll") as ScrollContainer
		if not check(left != null and right != null and left != right, "two independently scrolling inventory surfaces " + suffix): continue
		surface_observation(suffix)
		check(host.ui.panel.get_global_rect().encloses(left.get_global_rect()) and host.ui.panel.get_global_rect().encloses(right.get_global_rect()) and Rect2(Vector2.ZERO, host.ui.root.size).encloses(host.ui.panel.get_global_rect()), "warehouse surfaces fit actual logical viewport " + suffix)
		check(host.ui.page_scroll.get_global_rect().encloses(left.get_global_rect()) and host.ui.page_scroll.get_global_rect().encloses(right.get_global_rect()), "both warehouse surfaces fit inside the actual outer scroll viewport " + suffix)
		var left_frame: Control = data.get("ship_column") as Control
		var right_frame: Control = data.get("station_column") as Control
		if bool(panel().get_meta("stacked_panes", false)):
			check(left_frame.get_global_rect().end.y <= right_frame.global_position.y + 1.0 and absf(left_frame.global_position.x - right_frame.global_position.x) <= 1.0 and absf(left_frame.size.x - right_frame.size.x) <= 1.0, "narrow warehouse keeps cargo above station in two full-width independent panes " + suffix)
		else:
			check(left_frame.global_position.x + left_frame.size.x <= right_frame.global_position.x + 1.0 and absf(left_frame.global_position.y - right_frame.global_position.y) <= 1.0, "wide warehouse keeps cargo on left and station inventory on right " + suffix)
		if host.ui.root.size.x <= 720:
			check(bool(panel().get_meta("stacked_panes", false)) and left.get_h_scroll_bar().max_value <= left.get_h_scroll_bar().page + 1.0 and right.get_h_scroll_bar().max_value <= right.get_h_scroll_bar().page + 1.0, "narrow warehouse exposes both inventories without horizontal scrolling " + suffix)
		for column: Dictionary in data.get("columns", []):
			var owner_rows: Array = data.ship_rows if column.scroll == left else data.station_rows
			var shallow: bool = bool(panel().get_meta("shallow_stacked", false))
			check(column.header_frame.is_visible_in_tree() == (not shallow), "only shallow stacked warehouse folds its repeated table header " + suffix)
			if shallow and not owner_rows.is_empty():
				check(visible(column.heading) and visible(owner_rows[0].row), "shallow warehouse keeps each caption and its complete first row visible " + suffix)
				for field: String in ["name", "quantity", "amount", "button", "claim"]:
					var control: Control = owner_rows[0].get(field) as Control
					if is_instance_valid(control): check(visible(control) and control.size.y + 1.0 >= control.get_combined_minimum_size().y, "shallow first-row field retains complete geometry and font minimum " + suffix + " " + field)
			for row: Dictionary in owner_rows:
				var actual_cells: Array[Control] = [row.image, row.names, row.location]
				actual_cells.append(row.amount if is_instance_valid(row.amount) else row.amount_placeholder)
				actual_cells.append(row.action_group if is_instance_valid(row.action_group) else row.action_placeholder)
				for index: int in range(actual_cells.size()):
					var header_cell: Control = column.header.get_child(index) as Control
					if shallow:
						check(absf(header_cell.custom_minimum_size.x - actual_cells[index].custom_minimum_size.x) <= 1.0 and actual_cells[index].size.x + 1.0 >= actual_cells[index].get_combined_minimum_size().x, "folded header retains the declared column widths while actual cells remain complete " + suffix + " " + str(row.id) + " " + str(index))
					else:
						var expected: Rect2 = header_cell.get_global_rect()
						var actual: Rect2 = actual_cells[index].get_global_rect()
						check(absf(expected.position.x - actual.position.x) <= 1.0 and absf(expected.size.x - actual.size.x) <= 1.0, "warehouse header and actual named column share one grid " + suffix + " " + str(row.id) + " " + str(index))
		for row: Dictionary in rows():
			check(label_fits(row.quantity) and label_fits(row.location) and (not (row.status as Control).is_visible_in_tree() or label_fits(row.status)), "quantity/location/restriction text remains readable " + suffix + " " + str(row.id))
			check(str(row.row.get_meta("row_id", "")) == str(row.id), "responsive layout retains asset row identity " + suffix + " " + str(row.id))
			var input: SpinBox = row.get("amount") as SpinBox
			if input != null: check(input.size.x >= input.get_combined_minimum_size().x - 0.5 and input.size.y >= input.get_combined_minimum_size().y - 0.5, "per-row amount editor fits " + suffix + " " + str(row.id))
		var right_offset: int = right.scroll_vertical
		var left_rows: Array[Dictionary] = rows("ship_rows")
		if not left_rows.is_empty():
			await reveal(left_rows[-1].quantity)
			check(visible(left_rows[-1].quantity) and right.scroll_vertical == right_offset, "cargo tail scroll never moves station list " + suffix)
		var left_offset: int = left.scroll_vertical
		var right_rows: Array[Dictionary] = rows("station_rows")
		await reveal(right_rows[-1].location)
		check(visible(right_rows[-1].location) and left.scroll_vertical == left_offset, "remote tail scroll never moves cargo list " + suffix)
		var action: Button = row_for(stack_a).get("button") as Button
		if action != null and not action.disabled:
			host.get_viewport().gui_release_focus(); left.scroll_vertical = 0; right.scroll_vertical = 0
			await frames(3); action.grab_focus(); await frames(4)
			if not visible(action):
				print("WAREHOUSE_TRANSFER_V16_FOCUS " + JSON.stringify({"layout": suffix, "rect": str(action.get_global_rect()), "focus": str(host.get_viewport().gui_get_focus_owner()), "viewport": str(host.ui.root.size)}))
				for scroll: ScrollContainer in scrolls(action): print("WAREHOUSE_TRANSFER_V16_FOCUS_SCROLL " + JSON.stringify({"name": str(scroll.name), "rect": str(scroll.get_global_rect()), "offset": scroll.scroll_vertical, "maximum": scroll.get_v_scroll_bar().max_value, "page": scroll.get_v_scroll_bar().page}))
			check(host.get_viewport().gui_get_focus_owner() == action and visible(action), "real row focus reveals its own operation " + suffix)
			action.release_focus()
		left.scroll_vertical = 0; right.scroll_vertical = 0; await frames(4)
		await capture("warehouse-dual-" + suffix)
		layouts += 1
	root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	await show(); await tooltip_checks()
	await remote_capture()

func remote_capture() -> void:
	if DisplayServer.get_name() == "headless": return
	var first_remote: Dictionary = {}
	var last_current: Dictionary = {}
	var remote_seen: bool = false
	var current_first: bool = true
	for row: Dictionary in rows("station_rows"):
		if bool(row.remote):
			remote_seen = true
			if first_remote.is_empty(): first_remote = row
		else:
			current_first = current_first and not remote_seen
			last_current = row
	if not check(not first_remote.is_empty() and current_first, "remote screenshot retains full current-first station inventory"): return
	var data: Dictionary = refs()
	var left: ScrollContainer = data.get("ship_scroll") as ScrollContainer
	left.scroll_vertical = 0
	await reveal(first_remote.row)
	# Move the real pointer away from the prior restriction tooltip so the
	# captured inventory boundary remains unobscured by a lingering popup.
	var point: Vector2 = left.get_global_rect().position + Vector2(4.0, -8.0)
	host.get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	host.get_viewport().push_input(motion, true)
	await frames(4)
	check(visible(first_remote.row) and visible(first_remote.location) and first_remote.get("amount") == null and first_remote.get("button") == null, "native remote screenshot exposes actual station name and grey read-only row")
	check(not last_current.is_empty() and visible(last_current.location) and left.scroll_vertical == 0, "native remote screenshot includes current-station tail and current vessel inventory")
	await capture("warehouse-remote-readonly")

func tooltip_label(node: Node, text: String) -> Label:
	if node is Label and node.is_visible_in_tree() and (node as Label).text == text: return node as Label
	for child: Node in node.get_children(true):
		var found: Label = tooltip_label(child, text)
		if found != null: return found
	return null

func tooltip_checks() -> void:
	if DisplayServer.get_name() == "headless": return
	var row: Dictionary = row_for(protected_stack)
	var witness: Control = row.get("button") as Control
	if witness == null: witness = row.get("status") as Control
	if not check(witness != null and not witness.tooltip_text.is_empty(), "restricted real row exposes its reason tooltip"): return
	root.gui_release_focus(); root.grab_focus()
	await frames(6)
	await reveal(witness)
	var deadline: int = Time.get_ticks_msec() + 10000
	var tooltip_wait_ms: int = maxi(100, ceili((float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)) + 0.25) * 1000.0))
	var stable_since: int = 0
	var stable: int = 0
	var received_stable: bool = false
	var hover_resets: int = 0
	var previous: Rect2 = witness.get_global_rect()
	var expected_text: String = witness.tooltip_text
	var label: Label = null
	var popup: Window = null
	while Time.get_ticks_msec() < deadline:
		var hover: Control = host.get_viewport().gui_get_hovered_control()
		var matching: bool = is_instance_valid(hover) and (hover == witness or witness.is_ancestor_of(hover))
		var rect: Rect2 = witness.get_global_rect()
		var hovering: bool = matching and root.has_focus() and visible(witness) and rect.is_equal_approx(previous) and rect.has_point(witness.get_global_mouse_position())
		if hovering:
			if stable == 0: stable_since = Time.get_ticks_msec()
			stable += 1
			var stable_ms: int = Time.get_ticks_msec() - stable_since
			if stable >= 3 and stable_ms >= 100: received_stable = true
			# Observe only after one continuous real hover window. Injecting
			# motion here would restart Godot's native tooltip timer.
			if stable >= 3 and stable_ms >= tooltip_wait_ms:
				label = tooltip_label(root, expected_text)
				popup = label.get_window() if label != null else null
				if label != null and popup is PopupPanel and popup.visible and popup.get_script() == null and str(popup.name).begins_with("@PopupPanel@"):
					break
		else:
			if stable > 0:
				hover_resets += 1
				print("WAREHOUSE_TRANSFER_V16_TOOLTIP_HOVER_RESET " + JSON.stringify({"target_rect": rect_values(rect), "hover": str(hover.get_path()) if is_instance_valid(hover) and hover.is_inside_tree() else "", "mouse": [witness.get_global_mouse_position().x, witness.get_global_mouse_position().y], "focus": root.has_focus(), "stable_ms": Time.get_ticks_msec() - stable_since}))
			stable = 0; stable_since = 0; label = null; popup = null
			if not root.has_focus(): root.grab_focus()
			var point: Vector2 = rect.get_center()
			host.get_viewport().warp_mouse(point)
			var event := InputEventMouseMotion.new()
			event.position = point; event.global_position = point; event.button_mask = 0; event.window_id = root.get_window_id()
			host.get_viewport().push_input(event, true); Input.flush_buffered_events()
		previous = rect
		await frames(1)
	check(received_stable, "real restricted control receives stable native pointer before tooltip delay")
	var actual_hover: Control = host.get_viewport().gui_get_hovered_control()
	print("WAREHOUSE_TRANSFER_V16_TOOLTIP " + JSON.stringify({"target": str(witness.get_path()), "target_rect": rect_values(witness.get_global_rect()), "expected_text": expected_text, "current_text": witness.tooltip_text, "hover": str(actual_hover.get_path()) if is_instance_valid(actual_hover) and actual_hover.is_inside_tree() else "", "mouse": [witness.get_global_mouse_position().x, witness.get_global_mouse_position().y], "focus": root.has_focus(), "page_vertical": host.ui.page_scroll.scroll_vertical, "stable_ms": Time.get_ticks_msec() - stable_since if stable > 0 else 0, "required_stable_ms": tooltip_wait_ms, "hover_resets": hover_resets, "label": label != null, "popup": str(popup.name) if popup != null else ""}))
	check(label != null and popup is PopupPanel and popup.visible and popup.get_script() == null and str(popup.name).begins_with("@PopupPanel@"), "real pointer hover opens builtin restriction tooltip")
	if label != null and popup != null:
		check(popup.size.x <= root.size.x and popup.size.y <= root.size.y and Rect2(Vector2.ZERO, Vector2(popup.size)).encloses(label.get_global_rect()), "restriction tooltip fits native window and popup")
	await capture("warehouse-restricted-tooltip")

func place_ship_at_anchor(anchor_id: String, offset: Vector3 = Vector3.ZERO) -> bool:
	var anchor: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", anchor_id)
	if not check(not anchor.is_empty() and host.state.ship().status == T.ShipStatus.FLYING, "explicit placement has a real anchor and legal flying ship " + anchor_id): return false
	var ship: D.ShipStateDto = host.state.ship()
	ship.sector_id = str(anchor.sector_id)
	ship.pos_x = float(anchor.x_m) + offset.x; ship.pos_y = float(anchor.y_m) + offset.y; ship.pos_z = float(anchor.z_m) + offset.z
	ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	for container: D.ContainerStateDto in host.state.rows("container_state"):
		if container.ship_instance_id == ship.ship_instance_id: container.sector_id = ship.sector_id
	if not check(host.gameplay.assign_anchor_site("ship", ship.ship_instance_id, anchor_id), "explicit placement retains authoritative anchor site " + anchor_id): return false
	if not check(host._stage_candidate(host.state, host.store.catalog), "Main stages explicit anchor-site fixture " + anchor_id): return false
	host._activate(host.state)
	host.set_process(false); host.set_physics_process(false)
	var flight: XJFlight = host.world.flight
	flight.global_position = host.world.anchor_position(anchor_id) + offset; flight.velocity = Vector3.ZERO
	flight.write_back(); flight.get_global_transform_interpolated(); flight.reset_physics_interpolation()
	await frames(3)
	return check(host.gameplay.same_anchor_site(host.state.ship(), anchor) and host.state.ship().status == T.ShipStatus.FLYING, "staged fixture keeps scene and authoritative flying site consistent " + anchor_id)

func station_fixture(destination: String) -> void:
	# Explicit endpoint placement tests rebind lifecycle; this is not a claim of
	# naturally completing travel. Docking itself still uses the real command.
	var station: Dictionary = host.store.catalog.one("station_defs", "station_id", destination)
	var ship: D.ShipStateDto = host.state.ship()
	ship.status = T.ShipStatus.FLYING
	ship.has_station_id = false; ship.station_id = ""; ship.vel_x = 0.0; ship.vel_y = 0.0; ship.vel_z = 0.0
	host.state.player().has_docked_station_id = false; host.state.player().docked_station_id = ""
	if not await place_ship_at_anchor(str(station.station_anchor_id)): return
	await command("dock", destination)
	check(host.state.player().docked_station_id == destination and host.state.player().has_docked_station_id, "actual docking accepts station fixture " + destination)
	await show()

func lifecycle_checks() -> void:
	var before: Dictionary = totals_by_item()
	var old_panel: WeakRef = weakref(panel())
	await command("switch_ship", parked_ship_id); await show()
	check(row_for(parked_stack_id).get("container_id", "") == str(stack(parked_stack_id).container_id) and row_for(protected_stack).is_empty(), "switching ships rebinds left cargo to the newly controlled vessel")
	check(old_panel.get_ref() == null or (old_panel.get_ref() as Node).is_queued_for_deletion(), "switching ship releases old warehouse panel references")
	await command("switch_ship", controlled_ship_id); await show()
	old_panel = weakref(panel())
	await station_fixture(remote_stations[0])
	var local_row: Dictionary = row_for(remote_ids[0])
	check(not local_row.is_empty() and not bool(local_row.remote) and bool(local_row.current_station) and local_row.get("button") != null, "formerly remote warehouse becomes actionable only after actual docking there")
	var previous: Dictionary = row_for(stack_a)
	check(not previous.is_empty() and bool(previous.remote) and previous.get("button") == null, "departed station stock becomes grey read-only inventory")
	check(old_panel.get_ref() == null or (old_panel.get_ref() as Node).is_queued_for_deletion(), "station change releases old warehouse references")
	await station_fixture(station_id)
	check(totals_by_item() == before, "ship and station switches preserve all goods and frozen package rewards")

func persistence_checks() -> void:
	var world: String = host.state.world_id
	var expected: Dictionary = asset_state()
	var old_panel: WeakRef = weakref(panel())
	await command("save", "2", 1, "manual")
	var sealed: Array[Dictionary] = host.store._records("SELECT l.slot_id,l.generation,l.current_snapshot_id FROM save_slot l JOIN save_snapshot s ON s.snapshot_id=l.current_snapshot_id WHERE l.world_id=? AND l.slot_kind='manual' AND l.slot_index=2 AND s.status='sealed'", [world])
	if not check(sealed.size() == 1, "manual warehouse checkpoint is actually sealed in SQLite"): return
	var slot: Dictionary = sealed[0]
	if not await command("load", str(slot.slot_id), int(slot.generation), str(slot.current_snapshot_id)): return
	await show()
	if not check(host.state != null and host.state.world_id == world, "manual checkpoint loads the requested real world"): return
	check(asset_state() == expected, "manual checkpoint reload restores exact inventory and package provenance")
	check(old_panel.get_ref() == null or (old_panel.get_ref() as Node).is_queued_for_deletion(), "manual reload clears old panel references")
	# Keep one old presentation surface alive outside the production page to
	# replay an already queued signal after reloading the same asset IDs. This
	# is a lifecycle witness, not a second authority or a live UI feature.
	var stale_view: Control = panel()
	stale_view.get_parent().remove_child(stale_view); add_child(stale_view); stale_view.hide()
	if not await command("load", str(slot.slot_id), int(slot.generation), str(slot.current_snapshot_id)):
		stale_view.queue_free(); return
	await show()
	var before_requests: int = requested.size()
	stale_view.emit_signal("transfer_requested", "stack", stack_a, 1, cargo)
	await frames(4)
	check(requested.size() == before_requests and asset_state() == expected, "queued old-view signal cannot move a same-ID asset after same-world reload")
	stale_view.queue_free(); await frames(3)
	await release_host()
	if not await boot(): return
	if not await command("load", str(slot.slot_id), int(slot.generation), str(slot.current_snapshot_id)): return
	await show()
	if not check(host.state != null and host.state.world_id == world, "separate Main reopens the requested sealed world"): return
	restarts += 1
	check(asset_state() == expected and host.state.ship().ship_instance_id == controlled_ship_id, "separate Main SQLite restart restores controlled cargo and all station goods exactly")
	check(not row_for(remote_ids[0]).is_empty() and bool(row_for(remote_ids[0]).remote), "reopened inventory still shows remote stock as read-only")
	old_panel = weakref(panel())
	var prior_state: RefCounted = host.state
	var prior_panel_id: int = panel().get_instance_id()
	var prior_view: Control = panel()
	var previous_ids: Array[String] = []
	var previous_stacks: Dictionary = {}
	for row: Dictionary in rows():
		previous_ids.append(str(row.id))
		if str(row.kind) == "stack": previous_stacks[str(row.id)] = stack(str(row.id))
	prior_view.get_parent().remove_child(prior_view); add_child(prior_view); prior_view.hide()
	if not await command("new_world", "仓储世界引用隔离验收"):
		prior_view.queue_free(); return
	await show()
	check(host.state.world_id != world and host.state != prior_state and panel().get_instance_id() != prior_panel_id, "new world replaces warehouse world, authority and active view")
	var new_destination: String = str(host.gameplay.get("inventory").call("hold", host.state.ship(), T.ContainerKind.CARGO))
	var reusable_id: String
	for id: String in previous_ids:
		if id.begins_with("starting-") and stack(id) != null: reusable_id = id; break
	var new_quote: Dictionary = host.gameplay.get("inventory").call("quote_transfer", "stack", reusable_id, 1, new_destination)
	check(bool(new_quote.get("ok", false)), "reused initial ID and destination form a legitimate request in the new authority")
	var new_before: Dictionary = asset_state()
	before_requests = requested.size()
	prior_view.emit_signal("transfer_requested", "stack", reusable_id, 1, new_destination)
	await frames(4)
	check(not reusable_id.is_empty() and requested.size() == before_requests and asset_state() == new_before, "old-world callback cannot move a reused starting asset ID in the new world")
	prior_view.queue_free(); await frames(3)
	check(old_panel.get_ref() == null, "old world warehouse view releases after the isolated pending-signal witness")
	for id: String in previous_ids:
		var row: Dictionary = row_for(id)
		if id.begins_with("starting-"):
			# Initial-state IDs are intentionally scoped by world and reused in
			# every new expedition. Verify fresh records and formal starting amounts.
			var fresh: D.InventoryStackStateDto = stack(id)
			var expected_quantity: int = -1
			if fresh != null:
				for initial: Dictionary in host.store.catalog.rows("starting_inventory"):
					if str(initial.item_id) == fresh.item_def_id: expected_quantity = int(initial.quantity); break
			check(fresh != null and fresh != previous_stacks.get(id) and not row.is_empty() and fresh.quantity == expected_quantity and str(fresh.quantity) in str(row.quantity.text), "new world rebinds reused initial asset ID to fresh formal starting quantity " + id)
		else: check(row.is_empty(), "new world never retains prior generated warehouse row " + id)

func _run() -> void:
	old_fps = Engine.max_fps; Engine.max_fps = 144
	root.size = Vector2i(1440, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_size = root.size
	directory = OS.get_environment("XJ_WAREHOUSE_V16_DIRECTORY").replace("\\", "/")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../jiaoben/tmp/warehouse-transfer-v16/%d" % Time.get_ticks_usec())
	if not check(directory.is_absolute_path() and directory.contains("/jiaoben/tmp/") and not directory.contains(".."), "test directory is scoped to tmp"): await finish(); return
	DirAccess.make_dir_recursive_absolute(directory); database_path = directory.path_join("progress.db")
	if not check(not FileAccess.file_exists(database_path), "test refuses an existing progress database"): await finish(); return
	if not await boot() or not await prepare(): await finish(); return
	list_checks()
	await movement_checks()
	await rejection_checks()
	await layout_checks()
	await lifecycle_checks()
	await persistence_checks()
	await finish()

func finish() -> void:
	await release_host(); Engine.max_fps = old_fps
	var result: String = "PASS" if failures.is_empty() else "FAIL"
	print("WAREHOUSE_TRANSFER_V16_FINAL_JSON " + JSON.stringify({"result": result, "revision": "dual-list-row-quantity-remote-readonly", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "layouts": layouts, "gui_transfers": gui_transfers, "remote_stations": remote_stations.size(), "restarts": restarts, "database_path": database_path}))
	print("WAREHOUSE_TRANSFER_V16_RESULT %s checks=%d captures=%d failures=%d" % [result, checks, captures, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
