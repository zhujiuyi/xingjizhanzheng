class_name XJInitialState
extends RefCounted
const State = preload("res://runtime/state.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Rng = preload("res://runtime/rng.gd")
var codec: Codec = Codec.new()
var result: State

func create(catalog: XJCatalog, seed_value: int) -> State:
	result = State.new()
	var profile: Dictionary = catalog.rows("starting_profile_defs")[0]
	var grant: Dictionary = catalog.one("starting_ships", "grant_kind", "owned")
	var loadout: Dictionary = catalog.one("ship_loadout_defs", "loadout_id", grant.loadout_id)
	var definition: Dictionary = catalog.one("ship_defs", "ship_id", loadout.ship_id)
	var station: Dictionary = catalog.one("station_defs", "sector_id", "sector_anchor")
	var anchor: Dictionary = catalog.one("anchor_defs", "anchor_id", station.station_anchor_id)
	var ship_id: String = "ship-guarantee"
	var player_id: String = "player-local"
	_add("player_state", {"player_id": player_id, "controlled_ship_id": ship_id, "currency_id": profile.currency_id, "credit": profile.starting_credit, "camera_mode": "follow", "docked_station_id": station.station_id})
	_add("ship_state", {"ship_instance_id": ship_id, "owner_player_id": player_id, "ship_def_id": definition.ship_id, "sector_id": station.sector_id, "station_id": station.station_id, "status": "docked", "pos_x": anchor.x_m, "pos_y": anchor.y_m, "pos_z": anchor.z_m, "shield": definition.shield_max, "armor": definition.armor_max, "hull": definition.hull_max, "energy": definition.energy_max, "policy_id": grant.policy_id})
	if catalog.table_names.has("site_defs"):
		_add("spatial_state", {"entity_kind": "ship", "entity_id": ship_id, "site_id": catalog.one("anchor_site_defs", "anchor_id", anchor.anchor_id).site_id})
	_add("container_state", {"container_id": "hold-cargo", "owner_player_id": player_id, "kind": "cargo", "ship_instance_id": ship_id, "ship_def_id": definition.ship_id, "sector_id": station.sector_id})
	_add("container_state", {"container_id": "warehouse", "owner_player_id": player_id, "kind": "station", "station_id": station.station_id, "sector_id": station.sector_id})
	if int(definition.mineral_cargo_l) > 0:
		_add("container_state", {"container_id": "hold-mineral", "owner_player_id": player_id, "kind": "mineral", "ship_instance_id": ship_id, "ship_def_id": definition.ship_id, "sector_id": station.sector_id})
	for slot in catalog.rows("ship_slot_defs"):
		if slot.ship_id != definition.ship_id: continue
		_add("container_state", {"container_id": "slot-%s-%d" % [slot.slot_type, slot.slot_index], "owner_player_id": player_id, "kind": "slot", "ship_instance_id": ship_id, "ship_def_id": definition.ship_id, "sector_id": station.sector_id, "slot_type": slot.slot_type, "slot_index": slot.slot_index})
	var index: int = 0
	for fit in catalog.rows("ship_loadout_items"):
		if fit.loadout_id != loadout.loadout_id: continue
		var container: String = "slot-%s-%d" % [fit.slot_type, fit.slot_index]
		var item: String = "module-guarantee-%d" % index
		_add("item_instance_state", {"item_instance_id": item, "item_def_id": fit.module_id, "owner_player_id": player_id, "container_id": container, "policy_id": grant.policy_id, "origin_kind": "guarantee", "salvage_recipe_id": catalog.one("module_salvage_recipe_defs", "module_id", fit.module_id).recipe_id, "durability": catalog.rule("module_durability_max"), "quality_multiplier": catalog.rule("standard_quality_multiplier")})
		_add("equipment_state", {"slot_container_id": container, "item_instance_id": item, "module_def_id": fit.module_id, "enabled": true})
		index += 1
	index = 0
	for supply in catalog.rows("loadout_supply_defs"):
		if supply.loadout_id != loadout.loadout_id: continue
		_add("inventory_stack_state", {"container_id": "hold-cargo", "stack_id": "protected-supply-%d" % index, "item_def_id": supply.item_id, "quantity": supply.quantity, "origin_kind": "guarantee", "policy_id": grant.policy_id})
		index += 1
	index = 0
	for inventory in catalog.rows("starting_inventory"):
		if inventory.quantity <= 0: continue
		var policy: String = ""
		for row in catalog.rows("starting_inventory_policy_defs"):
			if row.profile_template_id == inventory.profile_template_id and row.item_id == inventory.item_id: policy = row.policy_id
		_add("inventory_stack_state", {"container_id": "warehouse", "stack_id": "starting-%d" % index, "item_def_id": inventory.item_id, "quantity": inventory.quantity, "origin_kind": "normal", "policy_id": policy})
		index += 1
	var unlocked: Array[String] = []
	for unlock in catalog.rows("unlock_defs"):
		if unlock.initially_unlocked:
			unlocked.append(unlock.unlock_id)
			_add("unlock_state", {"player_id": player_id, "unlock_id": unlock.unlock_id})
	var prerequisites: Array[String] = []
	for prerequisite in catalog.rows("mission_prerequisites"): prerequisites.append(prerequisite.mission_id)
	for mission in catalog.rows("mission_defs"):
		var available: bool = unlocked.has(mission.required_unlock_id) and not prerequisites.has(mission.mission_id)
		_add("mission_availability_state", {"player_id": player_id, "mission_def_id": mission.mission_id, "status": "available" if available else "locked"})
	for faction in catalog.rows("faction_defs"):
		_add("reputation_state", {"player_id": player_id, "faction_id": faction.faction_id, "reputation": 0})
	for node in catalog.rows("resource_node_defs"):
		_add("resource_state", {"node_id": node.node_id, "remaining_units": node.capacity_units})
	for connection in catalog.rows("connection_defs"):
		var gate: Dictionary = catalog.one("gate_class_defs", "gate_class_id", connection.gate_class_id)
		_add("gate_state", {"connection_id": connection.connection_id, "enabled": 1, "remaining_mass_budget_kg": gate.total_mass_budget_kg, "lifetime_remaining_s": gate.lifetime_s})
	for sector in catalog.rows("sector_defs"):
		_add("sector_state", {"sector_id": sector.sector_id, "visited": 1 if sector.sector_id == station.sector_id else 0})
	if catalog.table_names.has("civilization_defs"):
		_add("civilization_state", {"player_id": player_id, "faction_id": null})
		for policy: Dictionary in catalog.rows("sector_sovereignty_defs"):
			_add("territory_state", {"sector_id": policy.sector_id, "faction_id": policy.initial_faction_id})
	if catalog.table_names.has("encounter_defs"):
		for encounter in catalog.rows("encounter_defs"):
			_add("encounter_state", {"encounter_id": encounter.encounter_id})
	for stock in catalog.rows("station_stock_defs"):
		var item: Dictionary = catalog.one("item_defs", "item_id", stock.item_id)
		_add("shop_stock_state", {"station_id": stock.station_id, "item_def_id": stock.item_id, "quantity": stock.initial_units, "buyback_remaining_units": stock.buyback_units_per_refresh, "ask_credit": item.base_ask_credit, "bid_credit": item.base_bid_credit, "refresh_remaining_s": catalog.one("station_defs", "station_id", stock.station_id).stock_refresh_s})
	for stock in catalog.rows("station_ship_stock_defs"):
		var ship: Dictionary = catalog.one("ship_defs", "ship_id", stock.ship_id)
		_add("shop_ship_stock_state", {"station_id": stock.station_id, "ship_def_id": stock.ship_id, "quantity": stock.initial_units, "ask_credit": ship.base_ask_credit, "bid_credit": ship.base_bid_credit, "refresh_remaining_s": catalog.one("station_defs", "station_id", stock.station_id).stock_refresh_s})
	for source in catalog.rows("station_defs"):
		_add("station_economy_state", {"station_id": source.station_id, "buyback_remaining_credit": source.buyback_budget_credit, "refresh_remaining_s": source.stock_refresh_s})
	var rng: Rng = Rng.new()
	if catalog.table_names.has("station_demand_defs"):
		for demand: Dictionary in catalog.rows("station_demand_defs"):
			_add("station_demand_state", {"demand_id": demand.demand_id, "remaining_units": demand.required_units, "phase_remaining_s": demand.duration_s})
	rng.initialize(seed_value)
	result.add("rng_state", rng.row)
	if catalog.table_names.has("exploration_event_defs"):
		var explorer: Script = preload("res://runtime/gameplay/exploration.gd")
		for row: RefCounted in explorer.initial_instances(catalog, seed_value): result.add("exploration_instance_state", row)
		_add("exploration_progress_state", {"player_id": player_id})
		for node: Dictionary in catalog.rows("exploration_resource_defs"):
			result.find("resource_state", "node_id", node.node_id).remaining_units = 0
	for row: RefCounted in preload("res://runtime/gameplay/mobile_belts.gd").initial_rows(catalog, result): result.add("exploration_belt_state", row)
	for row: RefCounted in preload("res://runtime/gameplay/tactics.gd").initial_sites(catalog): result.add("tactical_site_state", row)
	for row: RefCounted in preload("res://runtime/gameplay/drone_control.gd").initial_bays(catalog, result): result.add("drone_bay_state", row)
	for row: RefCounted in preload("res://runtime/gameplay/operations.gd").initial_rows(catalog): result.add("operation_state", row)
	for row: RefCounted in preload("res://runtime/gameplay/consignments.gd").initial_rows(catalog): result.add("consignment_state",row)
	if catalog.table_names.has("weapon_tuning_defs"): _add("specialization_progress_state", {"player_id":player_id})
	for row: RefCounted in preload("res://runtime/gameplay/honors.gd").initial_rows(catalog,result):result.add("civilization_command_state",row)
	var frontier_rows: Dictionary=preload("res://runtime/gameplay/frontier.gd").initial_rows(catalog,result)
	for table: String in frontier_rows:
		for row: RefCounted in frontier_rows[table]:result.add(table,row)
	var campaign_rows: Dictionary=preload("res://runtime/data/campaign_initial.gd").rows(catalog,result,seed_value)
	for table: String in campaign_rows:
		for row: RefCounted in campaign_rows[table]:result.add(table,row)
	return result

func _add(table: String, values: Dictionary) -> void:
	var row: RefCounted = codec.decode_row(table, values)
	if row != null: result.add(table, row)
