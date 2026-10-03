extends SceneTree
## Explicit asset/unlock fixtures test device permission and persistent effects, not progression.
const Store = preload("res://runtime/data/store.gd")
const G = preload("res://runtime/gameplay.gd")
const UI = preload("res://runtime/ui.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL ", label)

func applied(g: G, action: String, target: String = "", extra: String = "") -> bool:
	return g.act(action, target, 1, extra).phase == T.ActionPhase.APPLIED

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/module-activation-audit.db")
	DirAccess.remove_absolute(path)
	var store: Store = Store.new(path)
	if not store.open(): check(false, store.last_error); quit(1); return
	var state: XJRuntimeState = store.new_world("模块许可审核夹具", 42)
	var g: G = G.new(); g.setup(state, store.catalog)
	for row in g.rows("unlock_defs"): g.grant_unlock(row.unlock_id)
	var ship: D.ShipStateDto = g.inventory.create_ship("battleship_bastion", "station_anchor_port", "normal_owned")
	state.player().controlled_ship_id = ship.ship_instance_id
	var warehouse: String = g.inventory.warehouse("station_anchor_port")
	for module in g.rows("module_defs"):
		var id: String = g.inventory.grant(warehouse, module.module_id, 1)[0]
		check(applied(g, "fit_module", id, str(module.slot_type) + ":0"), "install " + module.module_id)
		var before: Dictionary = g.metrics(ship)
		ship.armor = before.armor_max
		check(applied(g, "set_module_enabled", id, "off"), "disable " + module.module_id)
		var off: Dictionary = g.metrics(ship)
		check(off.power_used == before.power_used and off.cpu_used == before.cpu_used and off.total_mass_kg == before.total_mass_kg, "disabled installation retains budgets and mass " + module.module_id)
		var base: Dictionary = g.definition("ship_defs", "ship_id", ship.ship_def_id)
		check(is_equal_approx(off.armor_max, base.armor_max) and is_equal_approx(off.scan_strength, base.scan_strength), "disabled module contributes no capacity or scanner bonus " + module.module_id)
		var baseline: Vector3 = Vector3.ZERO
		for resistance in g.rows("ship_resistances"):
			if resistance.ship_id == ship.ship_def_id and resistance.layer_id == "armor": baseline[g.damage_index(resistance.damage_type)] = resistance.resistance
		check(off.resistances.armor.is_equal_approx(baseline) and ship.armor <= off.armor_max, "disabled module contributes no armor resistance or excess HP " + module.module_id)
		var retained_armor: float = ship.armor
		check(applied(g, "set_module_enabled", id, "on") and ship.armor == retained_armor, "reenabling does not heal " + module.module_id)
		check(applied(g, "set_module_enabled", id, "off"), "disable before durable save " + module.module_id)
		check(store.save(state, "manual", 0), "save disabled " + module.module_id + " " + store.last_error)
		var world: String = state.world_id
		g.dispose(); store.close()
		store = Store.new(path); check(store.open(), "reopen SQLite")
		state = store.load(Store._slot_id(world, "manual", 0))
		if state == null: check(false, store.last_error); store.close(); quit(1); return
		g = G.new(); g.setup(state, store.catalog); ship = state.ship()
		check(not state.find("equipment_state", "item_instance_id", id).enabled and is_equal_approx(g.metrics(ship).armor_max, base.armor_max), "disabled effects survive reopen " + module.module_id)
		check(applied(g, "unfit_module", id), "unfit " + module.module_id)
	var ui: UI = UI.new(); root.add_child(ui)
	ui.state = state; ui.catalog = store.catalog; ui.gameplay = g
	var metrics: Dictionary = g.metrics(ship)
	ship.heat = metrics.heat_max * (store.catalog.rule("overheat_warning_ratio") - 0.01)
	ui._update_instrument(ship, metrics)
	check(not ui.heat_label.text.contains("预警"), "below database heat warning threshold")
	ship.heat = metrics.heat_max * store.catalog.rule("overheat_warning_ratio")
	ui._update_instrument(ship, metrics)
	check(ui.heat_label.text.contains("预警") and not ship.overheated, "threshold warning separate from overheat lock")
	ship.overheated = true; ui._update_instrument(ship, metrics)
	check(ui.heat_label.text.contains("锁定"), "locked device status distinct from warning")
	ui.queue_free(); await process_frame; await process_frame
	g.dispose(); store.close()
	print("MODULE_ACTIVATION_AUDIT_RESULT ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
