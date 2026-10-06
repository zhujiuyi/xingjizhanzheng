extends Node
## Production Main/UI with fresh tmp SQLite. Hulls, weapons and unlocks below
## are explicit fixtures, not natural purchases or a personal save migration.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var host: Main
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var directory: String
var station_id: String
var ships: Dictionary = {}
var items: Dictionary = {}
var events: Array[Dictionary] = []
var old_fps: int
var root: Window:
	get: return get_tree().root
var process_frame: Signal:
	get: return get_tree().process_frame

func _ready() -> void:
	# The exported client and source thin launcher instantiate this same Node.
	# The nested production Main must not redispatch its diagnostic flag.
	get_tree().set_meta("xj_weapon_ui_v18_diagnostic", true)
	get_tree().create_timer(240.0).timeout.connect(func(): print("WEAPON_UI_V18_RESULT FAIL watchdog"); get_tree().quit(1))
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func command(action: String, target: String = "", extra: String = "") -> void:
	host._command(action, target, 1, extra)
	await frames(4)
	var deadline: int = Time.get_ticks_msec() + 5000
	while host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not host.busy, "production SQLite writer settles " + action)

func show(page: String) -> void:
	if page == "market": host.ui.market_filter = "buy"
	host.ui.show_page(page)
	await frames(4)
	host.ui.tick(1.0)
	await frames(3)

func lists_below(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node.has_meta("business_list"): found.append(node)
	for child: Node in node.get_children(): found.append_array(lists_below(child))
	return found

func row_for(id: String) -> Dictionary:
	for list: Node in lists_below(host.ui.body):
		for row: Dictionary in list.get("rows"):
			if str(row.id) == id: return row
	return {}

func buttons_below(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button: found.append(child)
		found.append_array(buttons_below(child))
	return found

func reveal(control: Control) -> void:
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await frames(4)

func tooltip_checks() -> void:
	for weapon: Dictionary in host.store.catalog.rows("weapon_defs"):
		var mid: String = str(weapon.module_id)
		var module: Dictionary = host.store.catalog.one("module_defs", "module_id", mid)
		var profile: Dictionary = host.store.catalog.one("weapon_behavior_defs", "module_id", mid)
		var text: String = host.ui._item_description(mid)
		var is_drone: bool = profile.fire_mode == "drone"
		check(text.contains("%.2f" % float(weapon.raw_damage)) and text.contains("周期 %.2f s" % float(module.cycle_s)) and text.contains("%.2f" % (float(weapon.raw_damage) / float(module.cycle_s))), "tooltip exact damage/cycle/DPS " + mid)
		check(text.contains(XJSpaceUnits.distance(float(module.range_m))) and text.contains("能量 %.2f EU" % float(module.energy_eu)) and text.contains("热量 %.2f HU" % float(module.heat_hu)), "tooltip frozen range/energy/heat " + mid)
		check(text.contains(host.ui._weapon_family_name(str(profile.family_id))) and text.contains(host.ui._weapon_size_name(int(profile.size_class))) and text.contains("已解锁"), "tooltip family/mount/actual technology " + mid)
		if is_drone:
			var drone: Dictionary = host.store.catalog.one("drone_defs", "module_id", mid)
			check(text.contains("控制范围") and text.contains("无人机 %d 架" % int(drone.drone_count)) and text.contains("每架攻击一次后回收") and text.contains("DPS 上界"), "drone tooltip bounded sortie and conservative DPS " + mid)
		elif weapon.projectile_speed_mps == null:
			check(text.contains("瞬时射线"), "ray tooltip does not claim projectile flight " + mid)
		else:
			check(text.contains("弹速 " + XJSpaceUnits.speed(float(weapon.projectile_speed_mps))), "projectile tooltip exact physical speed in the appropriate unit " + mid)
		if weapon.ammo_item_id != null: check(text.contains("×%d" % int(weapon.ammo_per_cycle)), "tooltip exact magazine charge " + mid)
	await show("market")
	for mid: String in ["module_kinetic_lance_i", "module_kinetic_siege_i", "module_drone_swarm_i"]:
		var row: Dictionary = row_for(mid)
		if check(not row.is_empty(), "new weapon has real market row " + mid):
			check(row.name.tooltip_text.contains(host.ui._item_description(mid)), "market name exposes complete weapon tooltip " + mid)
			check(not row.image.texture.resource_path.contains("generic/"), "new weapon portrait resolves its generated asset " + mid)

func fitting_matrix() -> void:
	for ship_id: String in ships:
		await command("switch_ship", str(ships[ship_id]))
		await show("fitting")
		var metrics: Dictionary = host.gameplay.call("metrics", host.state.ship())
		for mid: String in items:
			var item: D.ItemInstanceStateDto = host.state.find("item_instance_state", "item_instance_id", str(items[mid]))
			var rule_reason: String = str(host.gameplay.call("weapon_fit_reason", host.state.ship(), mid))
			var ui_reason: String = host.ui._fitting_reason(item, metrics)
			var row: Dictionary = row_for(item.item_instance_id)
			if not check(not row.is_empty(), "fitting exposes actual local module " + ship_id + "/" + mid): continue
			var install: Array[Button] = buttons_below(row.actions)
			check(not install.is_empty(), "fitting lists actual empty weapon slot " + ship_id + "/" + mid)
			check(ui_reason == rule_reason, "UI rejection agrees with authoritative family/size rule " + ship_id + "/" + mid)
			for button: Button in install:
				check(button.disabled == not rule_reason.is_empty(), "real install button permission " + ship_id + "/" + mid)
				if button.disabled: check(button.tooltip_text == rule_reason and row.status.text.contains(rule_reason), "disabled button and visible row preserve precise reason " + ship_id + "/" + mid)

func actual_fit_and_family_limit() -> void:
	await command("switch_ship", str(ships["cruiser_horizon"]))
	await show("fitting")
	var id: String = str(items["module_thermal_sunline_i"])
	var row: Dictionary = row_for(id)
	var available: Array[Button] = buttons_below(row.actions)
	if not check(not available.is_empty() and not available[0].disabled, "legal thermal install has real enabled button"): return
	var button: Button = available[0]
	await reveal(button)
	if DisplayServer.get_name() != "headless": root.grab_focus()
	var before: int = events.size()
	var center: Vector2 = button.get_global_rect().get_center()
	host.get_viewport().warp_mouse(center)
	var motion := InputEventMouseMotion.new()
	motion.position = center; motion.global_position = center
	host.get_viewport().push_input(motion, true)
	await frames(3)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT; click.pressed = pressed; click.position = center; click.global_position = center
		host.get_viewport().push_input(click, true)
	await frames(8)
	check(events.size() == before + 1 and str(events[-1].action) == "fit_module", "real viewport click sends one fitting request")
	check(host.state.find("equipment_state", "item_instance_id", id) != null, "production fitting installs the selected instance")
	await show("fitting")
	var another: D.ItemInstanceStateDto = host.state.find("item_instance_state", "item_instance_id", str(items["module_thermal_sunline_ii"]))
	var reason: String = host.ui._fitting_reason(another, host.gameplay.call("metrics", host.state.ship()))
	check(reason.contains("家族") and reason.contains("已满"), "cross-generation family cap shown instead of generic empty-slot reason")
	row = row_for(another.item_instance_id)
	for install: Button in buttons_below(row.actions): check(install.disabled and install.tooltip_text == reason, "all empty-slot buttons reject second thermal tier")
	await command("unfit_module", id)

func legacy_absence_fixture() -> void:
	# Table availability fixture verifies the old-schema UI route only. Actual
	# historical database migration is covered by the Store combat upgrade suite.
	var catalog: XJCatalog = host.store.catalog
	var names: Array[String] = catalog.table_names.duplicate()
	for table: String in ["weapon_behavior_defs", "ship_weapon_permissions", "drone_defs"]: catalog.table_names.erase(table)
	host.ui.definition_cache.clear()
	catalog.last_error = ""
	var weapon: String = host.ui._item_description("module_kinetic_needle_i")
	var ship: String = host.ui._ship_description("shuttle_swift")
	check(not weapon.contains("轻型") and ship.contains("原有槽位与预算"), "old-schema absence route preserves old weapon and hull rules")
	check(catalog.last_error.is_empty(), "old-schema UI never queries absent profile/permission/drone tables")
	catalog.table_names = names
	host.ui.definition_cache.clear()

func recycling_provenance_checks() -> void:
	var inventory: RefCounted = host.gameplay.get("inventory")
	var economy: RefCounted = host.gameplay.get("economy")
	var warehouse: String = str(inventory.call("warehouse", station_id))
	var mid: String = "module_kinetic_needle_ii"
	var recipe: Dictionary = host.store.catalog.one("module_salvage_recipe_defs", "module_id", mid)
	var current_inputs: Dictionary = {}
	for row: Dictionary in host.store.catalog.rows("recipe_inputs"):
		if row.recipe_id == recipe.recipe_id: current_inputs[str(row.item_id)] = int(row.quantity)
	# Audited pre-v0.6 standard recipe fixture. These are historical paid-input
	# rows on isolated instances, not another runtime balance configuration.
	var old_inputs: Dictionary = {"module_kinetic_needle_i": 1, "component_relic": 3, "material_dense_alloy": 2}
	var ratio: float = float(host.store.catalog.rule("recycle_input_return_ratio"))
	var material_ids: Array[String] = []
	for material: String in current_inputs: material_ids.append(material)
	for material: String in old_inputs:
		if not material_ids.has(material): material_ids.append(material)
	for kind: String in ["old_purchase", "old_manufacture", "new_purchase", "missing_manufacture_ledger"]:
		var origin: T.ItemOrigin = T.ItemOrigin.MANUFACTURE if kind in ["old_manufacture", "missing_manufacture_ledger"] else T.ItemOrigin.PURCHASE
		var granted: Array = inventory.call("grant", warehouse, mid, 1, "normal_owned", "", "", origin)
		var id: String = str(granted[0])
		var item: D.ItemInstanceStateDto = host.state.find("item_instance_state", "item_instance_id", id)
		var has_old_inputs: bool = kind in ["old_purchase", "old_manufacture"]
		if has_old_inputs:
			for material: String in old_inputs:
				var ledger: D.ManufactureInputStateDto = D.ManufactureInputStateDto.new()
				ledger.item_instance_id = id; ledger.input_item_id = material; ledger.input_quantity = int(old_inputs[material])
				host.state.add("manufacture_input_state", ledger)
		var expected_inputs: Dictionary = old_inputs if has_old_inputs else current_inputs
		var before: Dictionary = {}
		for material: String in material_ids: before[material] = int(inventory.call("count", warehouse, material, true))
		var credit: int = host.state.player().credit
		var reason: String = host.ui._recycle_reason(item)
		if kind == "missing_manufacture_ledger":
			check(reason.contains("追溯账本") and not bool(economy.call("recycle", id)), "manufactured instance without actual input ledger is rejected by UI and authority")
			check(host.state.find("item_instance_state", "item_instance_id", id) != null and host.state.player().credit == credit, "missing-ledger rejection preserves the device and money")
			inventory.call("erase_item", item)
			continue
		check(reason.is_empty(), "recycling UI accepts exact available provenance " + kind)
		check(host.ui._recycle_source_description(item).contains("历史标准投入" if kind == "old_purchase" else "实际制造投入" if kind == "old_manufacture" else "当前世界冻结"), "recycling tooltip identifies actual material source " + kind)
		check(bool(economy.call("recycle", id)), "production recycler consumes isolated instance " + kind)
		check(host.state.find("item_instance_state", "item_instance_id", id) == null and host.state.player().credit == credit - int(host.store.catalog.rule("recycle_service_fee_credit")), "recycling removes exactly one instance and pays defined fee " + kind)
		for material: String in material_ids:
			var after: int = int(inventory.call("count", warehouse, material, true))
			var returned: int = int(floor(float(expected_inputs.get(material, 0)) * ratio))
			check(after - int(before[material]) == returned, "recycling exact saved input delta " + kind + "/" + material)
		if has_old_inputs: check(int(inventory.call("count", warehouse, "component_fire_control", true)) == int(before.get("component_fire_control", 0)), "old paid provenance never adopts new fire-control component " + kind)
		for ledger: D.ManufactureInputStateDto in host.state.rows("manufacture_input_state"):
			check(ledger.item_instance_id != id, "recycled instance has no surviving input ledger " + kind)

func layouts() -> void:
	await command("switch_ship", str(ships["cruiser_horizon"]))
	for size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = size; root.content_scale_size = Vector2i(Vector2(size) / scale)
			await frames(4)
			for page: String in ["market", "fitting"]:
				await show(page)
				var label: String = "%s %dx%d-%d" % [page, size.x, size.y, int(scale * 100)]
				check(Rect2(Vector2.ZERO, host.ui.root.size).encloses(host.ui.panel.get_global_rect()), "weapon business panel fits viewport " + label)
				var id: String = "module_drone_swarm_i" if page == "market" else str(items["module_drone_swarm_i"])
				var row: Dictionary = row_for(id)
				if not check(not row.is_empty(), "drone row accessible at each layout " + label): continue
				await reveal(row.name)
				check(not row.image.texture.resource_path.contains("generic/") and row.name.text.contains("无人机"), "drone row retains identity and custom thumbnail " + label)
				if DisplayServer.get_name() != "headless":
					await process_frame
					var image: Image = host.get_viewport().get_texture().get_image()
					check(image.save_png(directory.path_join(label.replace(" ", "-") + ".png")) == OK, "native weapon UI screenshot " + label)
					captures += 1

func _run() -> void:
	old_fps = Engine.max_fps; Engine.max_fps = 120
	root.size = Vector2i(1440, 900); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_size = root.size
	var script_path: String = OS.get_environment("XJ_WEAPON_UI_V18_SCRIPT").replace("\\", "/")
	var prefix: String = script_path.get_base_dir().get_base_dir().path_join("tmp/weapon-ui-v18") if not script_path.is_empty() else ProjectSettings.globalize_path("res://../jiaoben/tmp/weapon-ui-v18").replace("\\", "/")
	directory = OS.get_environment("XJ_WEAPON_UI_V18_DIRECTORY").replace("\\", "/")
	if directory.is_empty():
		var scope: String = Crypto.new().generate_random_bytes(16).hex_encode()
		directory = prefix.path_join("%s-%s-%s-%s-%s" % [scope.substr(0, 8), scope.substr(8, 4), scope.substr(12, 4), scope.substr(16, 4), scope.substr(20, 12)])
	if not check(directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == prefix and directory.begins_with(prefix + "/"), "test directory is a direct scoped child of tmp/weapon-ui-v18"): await finish(); return
	DirAccess.make_dir_recursive_absolute(directory)
	if not check(not FileAccess.file_exists(directory.path_join("progress.db")), "weapon UI test refuses any existing progress database"): await finish(); return
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host); host.set_process(false); host.set_physics_process(false)
	await frames(4)
	if not check(host.services_ready, "Main opens formal catalog and isolated tmp SQLite"): await finish(); return
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): events.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))
	await command("new_world", "武器配装和说明独立验收")
	if not check(host.state != null, "new world has real typed state"): await finish(); return
	station_id = host.state.player().docked_station_id
	var inventory: RefCounted = host.gameplay.get("inventory")
	var warehouse: String = str(inventory.call("warehouse", station_id))
	for unlock: Dictionary in host.store.catalog.rows("unlock_defs"): host.gameplay.call("grant_unlock", str(unlock.unlock_id))
	for definition: Dictionary in host.store.catalog.rows("ship_defs"):
		var ship: D.ShipStateDto = inventory.call("create_ship", str(definition.ship_id), station_id)
		ships[str(definition.ship_id)] = ship.ship_instance_id
	for definition: Dictionary in host.store.catalog.rows("weapon_defs"):
		var granted: Array = inventory.call("grant", warehouse, str(definition.module_id), 1)
		items[str(definition.module_id)] = str(granted[0])
	print("WEAPON_UI_V18_FIXTURE all-unlocks=explicit nine-bare-hulls=production-create eighteen-weapons=production-grant no-personal-save")
	await tooltip_checks()
	await fitting_matrix()
	await actual_fit_and_family_limit()
	legacy_absence_fixture()
	recycling_provenance_checks()
	await layouts()
	await finish()

func finish() -> void:
	if is_instance_valid(host): host.queue_free()
	await frames(4)
	Engine.max_fps = old_fps
	var result: String = "PASS" if failures.is_empty() else "FAIL"
	print("WEAPON_UI_V18_FINAL_JSON " + JSON.stringify({"result": result, "checks": checks, "captures": captures, "failures": failures.size(), "failure_labels": failures, "directory": directory, "database_path": directory.path_join("progress.db"), "fixture": "fresh-production-main-explicit-hulls-weapons-and-unlocks"}))
	print("WEAPON_UI_V18_RESULT %s checks=%d captures=%d failures=%d" % [result, checks, captures, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
