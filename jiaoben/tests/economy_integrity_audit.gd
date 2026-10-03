extends SceneTree
## Capability audit against a fresh frozen catalog and isolated SQLite. Funding,
## known technology and station placement are explicit test prerequisites; this
## is not a natural-income, natural-travel or personal-save playthrough.
const Gameplay = preload("res://runtime/gameplay.gd")
const Store = preload("res://runtime/data/store.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []
var g: Gameplay
var store: Store
var state: XJRuntimeState
var database_path: String
var persisted_item_id: String
var persisted_ship_id: String

func expect(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func applied(name: String, target: String = "", quantity: int = 1, extra: String = "") -> bool:
	var result: D.ActionResultDto = g.act(name, target, quantity, extra)
	return result.phase == T.ActionPhase.APPLIED

func place(station_id: String) -> void:
	g.stop_interactions()
	var def: Dictionary = g.definition("station_defs", "station_id", station_id)
	var ship: D.ShipStateDto = state.ship()
	ship.status = T.ShipStatus.DOCKED
	ship.has_station_id = true; ship.station_id = station_id; ship.sector_id = def.sector_id
	ship.pos_x = 0; ship.pos_y = 0; ship.pos_z = 0
	ship.vel_x = 0; ship.vel_y = 0; ship.vel_z = 0
	state.player().has_docked_station_id = true; state.player().docked_station_id = station_id
	for container: D.ContainerStateDto in state.rows("container_state"):
		if container.ship_instance_id == ship.ship_instance_id: container.sector_id = def.sector_id
	g.inventory.warehouse(station_id)
	var budget: D.StationEconomyStateDto = state.find("station_economy_state", "station_id", station_id)
	budget.buyback_remaining_credit = int(def.buyback_budget_credit)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/economy-integrity-%d.db" % Time.get_ticks_usec())
	store = Store.new(database_path)
	if not expect(store.open(), "fresh isolated SQLite opens"): quit(1); return
	state = store.new_world("economy-integrity-audit", 8130)
	if not expect(state != null, "fresh world with real frozen catalog"): store.close(); quit(1); return
	g = Gameplay.new(); g.setup(state, store.catalog)
	state.player().credit = 20000000
	for definition: Dictionary in g.rows("unlock_defs"): g.grant_unlock(str(definition.unlock_id))
	_verify_protected_fit()
	_verify_all_ships()
	var carrier: D.ShipStateDto = g.inventory.create_ship("cruiser_horizon", "station_anchor_port")
	place("station_anchor_port")
	expect(applied("switch_ship", carrier.ship_instance_id), "explicit bare normal carrier fixture is controllable")
	persisted_ship_id = carrier.ship_instance_id
	_verify_all_modules()
	_verify_echo_production_chain()
	_verify_basic_recipe_procurement()
	place("station_anchor_port")
	expect(applied("buy_item", "module_armor_pressure_ii"), "retain actually purchased normal module for reopen")
	var preserved: D.ItemInstanceStateDto = state.rows("item_instance_state").back()
	persisted_item_id = preserved.item_instance_id
	expect(applied("fit_module", persisted_item_id, 1, "structure:0"), "ordinary retained module installs before SQLite save")
	var before_credit: int = state.player().credit
	expect(store.save(state, "manual", 0), "full economic endpoint seals: " + store.last_error)
	var selected: Dictionary = {}
	for slot: Dictionary in store.list_slots():
		if slot.slot_kind == "manual" and int(slot.slot_index) == 0: selected = slot
	g.dispose(); g = null; store.close()
	store = Store.new(database_path)
	expect(store.open(), "economic SQLite closes and reopens")
	if not selected.is_empty():
		state = store.load(str(selected.slot_id), str(selected.current_snapshot_id), int(selected.generation))
		if expect(state != null, "economic snapshot independently reloads: " + store.last_error):
			g = Gameplay.new(); g.setup(state, store.catalog)
			expect(state.player().credit == before_credit and state.player().controlled_ship_id == persisted_ship_id, "credit and controlled owned hull survive reopen")
			expect(state.find("equipment_state", "item_instance_id", persisted_item_id) != null, "installed instance survives reopen")
			expect(applied("unfit_module", persisted_item_id) and applied("sell_item", persisted_item_id), "reloaded installed equipment remains removable and tradeable")
			expect(store.save(state, "manual", 0), "reloaded removal and sale seal again: " + store.last_error)
	if g != null: g.dispose()
	store.close()
	print("ECONOMY_INTEGRITY_AUDIT_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size(), " database=", database_path)
	quit(0 if failures.is_empty() else 1)

func _verify_protected_fit() -> void:
	place("station_anchor_port")
	var warehouse: String = g.inventory.warehouse(g.station())
	var module_ids: Array[String] = g.inventory.grant(warehouse, "module_armor_pressure_i", 1)
	var item: D.ItemInstanceStateDto = state.find("item_instance_state", "item_instance_id", module_ids[0])
	var equipment_count: int = state.rows("equipment_state").size()
	expect(not applied("fit_module", item.item_instance_id, 1, "structure:0"), "protected guarantee hull refuses ordinary asset absorption")
	expect(item.policy_id == "normal_owned" and item.container_id == warehouse and state.rows("equipment_state").size() == equipment_count, "rejected protected fit preserves ownership, location and equipment registry")
	# Keep the original failing behavior from obscuring subsequent audit checks.
	if item.container_id != warehouse:
		var equipped: D.EquipmentStateDto = state.find("equipment_state", "item_instance_id", item.item_instance_id)
		if equipped != null: state.remove("equipment_state", equipped)
		item.container_id = warehouse; item.policy_id = "normal_owned"
	expect(applied("sell_item", item.item_instance_id), "rejected owned module remains tradeable")

func _verify_all_ships() -> void:
	for definition: Dictionary in g.rows("ship_defs"):
		var ship_id: String = str(definition.ship_id)
		var yard: Dictionary = {}
		for candidate: Dictionary in g.rows("station_ship_stock_defs"):
			if candidate.ship_id == ship_id: yard = candidate; break
		if not expect(not yard.is_empty(), "defined hull has an actual purchase yard: " + ship_id): continue
		place(str(yard.station_id))
		var previous: String = state.ship().ship_instance_id
		var quoted: int = g.economy.quote_ship(ship_id)
		var before_credit: int = state.player().credit
		var before_count: int = state.rows("ship_state").size()
		if not expect(applied("buy_ship", ship_id), "purchase actual defined hull: " + ship_id): continue
		var purchased: D.ShipStateDto = state.rows("ship_state").back()
		expect(state.rows("ship_state").size() == before_count + 1 and purchased.ship_def_id == ship_id and purchased.policy_id == "normal_owned" and g.equipped(purchased).is_empty() and state.player().credit == before_credit - quoted, "purchased bare owned hull and exact fee: " + ship_id)
		expect(applied("switch_ship", purchased.ship_instance_id), "purchased hull has a reachable control action: " + ship_id)
		var sale_credit: int = state.player().credit
		expect(not applied("sell_ship", purchased.ship_instance_id) and state.player().credit == sale_credit, "current hull sale rejects without mutation: " + ship_id)
		expect(applied("switch_ship", previous), "switch away before real hull sale: " + ship_id)
		var sale: int = g.economy.quote_ship(ship_id, true)
		expect(applied("sell_ship", purchased.ship_instance_id) and purchased.status == T.ShipStatus.RETURNED and state.player().credit == sale_credit + sale, "purchased hull can be sold with exact payout: " + ship_id)

func _verify_all_modules() -> void:
	for definition: Dictionary in g.rows("module_defs"):
		var module_id: String = str(definition.module_id)
		var source: Dictionary = {}
		for candidate: Dictionary in g.rows("station_stock_defs"):
			if candidate.item_id == module_id and bool(candidate.allow_buy) and int(candidate.initial_units) > 0: source = candidate; break
		if not expect(not source.is_empty(), "module has actual stocked procurement: " + module_id): continue
		place(str(source.station_id))
		var warehouse: String = g.inventory.warehouse(g.station())
		var before: int = g.inventory.count(warehouse, module_id)
		var credit: int = state.player().credit
		var price: int = g.economy.quote(module_id, 1)
		if not expect(applied("buy_item", module_id), "purchase module generation: " + module_id): continue
		var item: D.ItemInstanceStateDto = state.rows("item_instance_state").back()
		expect(item.item_def_id == module_id and item.policy_id == "normal_owned" and item.origin_kind == T.ItemOrigin.PURCHASE and not item.salvage_recipe_id.is_empty() and g.inventory.count(warehouse, module_id) == before + 1 and state.player().credit == credit - price, "purchased module has exact price and frozen provenance: " + module_id)
		if not expect(applied("fit_module", item.item_instance_id, 1, str(definition.slot_type) + ":0"), "install purchased module in real matching slot: " + module_id): continue
		expect(state.find("equipment_state", "item_instance_id", item.item_instance_id) != null, "installation creates persistent equipment relation: " + module_id)
		_verify_module_consumer(item)
		place(str(source.station_id))
		expect(applied("unfit_module", item.item_instance_id) and item.container_id == warehouse and item.policy_id == "normal_owned", "all generations have reversible ordinary installation: " + module_id)
		var counts: Dictionary = {}
		var expected: Dictionary = {}
		for input: Dictionary in g.rows("recipe_inputs"):
			if str(input.recipe_id) != item.salvage_recipe_id: continue
			counts[str(input.item_id)] = g.inventory.count(warehouse, str(input.item_id))
			expected[str(input.item_id)] = int(floor(float(input.quantity) * g.rule("recycle_input_return_ratio")))
		credit = state.player().credit
		expect(applied("recycle", item.item_instance_id) and state.find("item_instance_state", "item_instance_id", item.item_instance_id) == null and state.player().credit == credit - int(g.rule("recycle_service_fee_credit")), "real removal and recycle service fee: " + module_id)
		for input_id: String in counts:
			expect(g.inventory.count(warehouse, input_id) == int(counts[input_id]) + int(expected[input_id]), "exact frozen dismantle return: " + module_id + " / " + input_id)
		expect(applied("buy_item", module_id), "reacquire for actual module sale: " + module_id)
		var sale_item: D.ItemInstanceStateDto = state.rows("item_instance_state").back()
		credit = state.player().credit; price = g.economy.quote(module_id, 1, true)
		expect(applied("sell_item", sale_item.item_instance_id) and state.player().credit == credit + price and state.find("item_instance_state", "item_instance_id", sale_item.item_instance_id) == null, "all generations have actual trade sink: " + module_id)

func _verify_module_consumer(item: D.ItemInstanceStateDto) -> void:
	var module_id: String = item.item_def_id
	var weapon: Dictionary = g.definition("weapon_defs", "module_id", module_id)
	var repair: Dictionary = g.definition("repair_defs", "module_id", module_id)
	var modifiers: Array[Dictionary] = []
	for row: Dictionary in g.rows("module_stat_modifiers"):
		if row.module_id == module_id: modifiers.append(row)
	expect(not weapon.is_empty() or not repair.is_empty() or not modifiers.is_empty() or not g.definition("mining_defs", "module_id", module_id).is_empty(), "module has an implemented runtime consumer: " + module_id)
	if weapon.is_empty(): return
	var hold: String = g.inventory.hold(state.ship(), T.ContainerKind.CARGO)
	if weapon.ammo_item_id != null: g.inventory.grant(hold, str(weapon.ammo_item_id), int(weapon.ammo_per_cycle))
	expect(applied("undock"), "weapon generation launches with owned equipment: " + module_id)
	var before_energy: float = state.ship().energy
	var fire: Dictionary = g.consume_weapon_cycle(item.item_instance_id)
	var definition: Dictionary = g.definition("module_defs", "module_id", module_id)
	expect(not fire.is_empty() and is_equal_approx(float(fire.damage_vector[g.damage_index(str(weapon.damage_type))]), float(weapon.raw_damage) * item.quality_multiplier) and is_equal_approx(state.ship().energy, before_energy - float(definition.energy_eu)), "weapon generation produces real paid damage: " + module_id)
	expect(g.consume_weapon_cycle(item.item_instance_id).is_empty(), "weapon generation enforces cooldown: " + module_id)
	g.combat_remaining_s = 0
	var equipment: D.EquipmentStateDto = state.find("equipment_state", "item_instance_id", item.item_instance_id)
	equipment.active_remaining_s = 0; equipment.cycle_paid = false

func _verify_basic_recipe_procurement() -> void:
	# Reacquire through the real market every missing material in all base recipes.
	# This proves the advertised manufacturing input path without grant() fixtures.
	place("station_anchor_port")
	for recipe: Dictionary in g.rows("recipe_defs"):
		if not g.definition("module_defs", "module_id", str(recipe.output_item_id)).is_empty(): continue
		for input: Dictionary in g.rows("recipe_inputs"):
			if input.recipe_id != recipe.recipe_id: continue
			var missing: int = maxi(0, int(input.quantity) - g.inventory.count(g.inventory.warehouse(g.station()), str(input.item_id)))
			if missing > 0: expect(applied("buy_item", str(input.item_id), missing), "real market supplies manufacturing ingredient: " + str(recipe.recipe_id) + " / " + str(input.item_id))
		var before: int = g.inventory.count(g.inventory.warehouse(g.station()), str(recipe.output_item_id))
		var quoted: int = g.economy.quote_manufacture(str(recipe.recipe_id))
		var credit: int = state.player().credit
		expect(applied("manufacture", str(recipe.recipe_id)) and g.inventory.count(g.inventory.warehouse(g.station()), str(recipe.output_item_id)) == before + int(recipe.output_quantity) and state.player().credit == credit - quoted, "all base processing recipes have purchased-input production: " + str(recipe.recipe_id))

func _verify_echo_production_chain() -> void:
	place("station_anchor_port")
	var warehouse: String = g.inventory.warehouse(g.station())
	var recipe: Dictionary = g.definition("recipe_defs", "recipe_id", "recipe_sensor_core_echo")
	if not expect(not recipe.is_empty(), "regional echo ore has an actual industrial recipe"): return
	# Produce the exact two cores consumed by one scanner using real purchases.
	for input: Dictionary in g.rows("recipe_inputs"):
		if input.recipe_id == recipe.recipe_id:
			expect(applied("buy_item", str(input.item_id), int(input.quantity) * 2), "actual purchase supplies echo-to-core input: " + str(input.item_id))
	var ore_before: int = g.inventory.count(warehouse, "ore_echo_silica")
	var core_before: int = g.inventory.count(warehouse, "component_sensor_core")
	expect(applied("manufacture", str(recipe.recipe_id), 2), "manufacture two sensor cores from echo ore")
	expect(g.inventory.count(warehouse, "ore_echo_silica") == ore_before - 6 and g.inventory.count(warehouse, "component_sensor_core") == core_before + 2, "echo ore is actually consumed into scanner cores")
	for input: Dictionary in g.rows("recipe_inputs"):
		if input.recipe_id != "recipe_scanner_beacon_i" or input.item_id == "component_sensor_core": continue
		var missing: int = maxi(0, int(input.quantity) - g.inventory.count(warehouse, str(input.item_id)))
		if missing > 0: expect(applied("buy_item", str(input.item_id), missing), "actual purchase supplies scanner complement: " + str(input.item_id))
	expect(applied("manufacture", "recipe_scanner_beacon_i"), "new industrial output enters existing scanner manufacture")
	expect(g.inventory.count(warehouse, "component_sensor_core") == core_before, "scanner manufacture consumes the two produced cores")
	var scanner: D.ItemInstanceStateDto = state.rows("item_instance_state").back()
	expect(scanner.item_def_id == "module_scanner_beacon_i" and applied("fit_module", scanner.item_instance_id, 1, "utility:0"), "echo-derived manufactured scanner fits an owned hull")
	expect(g.metrics(state.ship()).scan_strength > float(g.definition("ship_defs", "ship_id", state.ship().ship_def_id).scan_strength), "echo-derived scanner has actual scan-strength effect")
	expect(applied("unfit_module", scanner.item_instance_id), "echo-derived scanner remains removable")
