-- Reviewed schema4 adapter: complete additive encounters and salvage definitions.
-- 首版数值及 B 内容 catalog；不包含 progress 状态或 Godot 运行逻辑。
PRAGMA foreign_keys = ON;

CREATE TABLE catalog_meta (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    pack_id TEXT NOT NULL,
    content_version TEXT NOT NULL,
    ruleset_version TEXT NOT NULL,
    schema_version INTEGER NOT NULL CHECK (schema_version > 0),
    source_document TEXT NOT NULL,
    hash_algorithm TEXT NOT NULL,
    content_hash TEXT NOT NULL
) STRICT;

CREATE TABLE rule_parameters (
    parameter_id TEXT PRIMARY KEY,
    value_integer INTEGER,
    value_real REAL,
    unit TEXT NOT NULL,
    CHECK ((value_integer IS NULL) <> (value_real IS NULL))
) STRICT;

CREATE TABLE currency_defs (
    currency_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    unit TEXT NOT NULL
) STRICT;

CREATE TABLE damage_types (
    damage_type TEXT PRIMARY KEY CHECK (damage_type IN ('kinetic', 'thermal', 'pulse'))
) STRICT;
CREATE TABLE defense_layers (
    layer_id TEXT PRIMARY KEY CHECK (layer_id IN ('shield', 'armor', 'hull')),
    layer_order INTEGER NOT NULL UNIQUE CHECK (layer_order BETWEEN 0 AND 2)
) STRICT;
CREATE TABLE slot_types (
    slot_type TEXT PRIMARY KEY CHECK (slot_type IN ('weapon', 'work', 'utility', 'structure'))
) STRICT;

CREATE TABLE ship_defs (
    ship_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    dry_mass_kg REAL NOT NULL CHECK (dry_mass_kg > 0),
    max_installed_mass_kg REAL NOT NULL CHECK (max_installed_mass_kg >= 0),
    max_payload_mass_kg REAL NOT NULL CHECK (max_payload_mass_kg >= 0),
    max_speed_mps REAL NOT NULL CHECK (max_speed_mps > 0),
    acceleration_mps2 REAL NOT NULL CHECK (acceleration_mps2 > 0),
    turn_rad_s REAL NOT NULL CHECK (turn_rad_s > 0),
    shield_max REAL NOT NULL CHECK (shield_max >= 0),
    armor_max REAL NOT NULL CHECK (armor_max >= 0),
    hull_max REAL NOT NULL CHECK (hull_max > 0),
    energy_max REAL NOT NULL CHECK (energy_max > 0),
    recharge_eu_s REAL NOT NULL CHECK (recharge_eu_s >= 0),
    heat_max REAL NOT NULL CHECK (heat_max > 0),
    cooling_hu_s REAL NOT NULL CHECK (cooling_hu_s >= 0),
    shield_recharge_hp_s REAL NOT NULL CHECK (shield_recharge_hp_s >= 0),
    cargo_l INTEGER NOT NULL CHECK (cargo_l >= 0),
    mineral_cargo_l INTEGER NOT NULL CHECK (mineral_cargo_l >= 0),
    power_capacity REAL NOT NULL CHECK (power_capacity > 0),
    cpu_capacity REAL NOT NULL CHECK (cpu_capacity > 0),
    scan_strength REAL NOT NULL CHECK (scan_strength > 0),
    mining_multiplier REAL NOT NULL CHECK (mining_multiplier > 0),
    base_ask_credit INTEGER NOT NULL CHECK (base_ask_credit >= 0),
    base_bid_credit INTEGER NOT NULL CHECK (base_bid_credit >= 0),
    CHECK (base_ask_credit > base_bid_credit)
) STRICT;

CREATE TABLE ship_slot_capacity (
    ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
    slot_type TEXT NOT NULL REFERENCES slot_types(slot_type),
    slot_count INTEGER NOT NULL CHECK (slot_count >= 0),
    PRIMARY KEY (ship_id, slot_type)
) STRICT;
CREATE TABLE ship_slot_defs (
    ship_id TEXT NOT NULL,
    slot_type TEXT NOT NULL,
    slot_index INTEGER NOT NULL CHECK (slot_index >= 0),
    PRIMARY KEY (ship_id, slot_type, slot_index),
    FOREIGN KEY (ship_id, slot_type) REFERENCES ship_slot_capacity(ship_id, slot_type)
) STRICT;
CREATE TABLE ship_resistances (
    ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
    layer_id TEXT NOT NULL REFERENCES defense_layers(layer_id),
    damage_type TEXT NOT NULL REFERENCES damage_types(damage_type),
    resistance REAL NOT NULL CHECK (resistance BETWEEN 0 AND 1),
    PRIMARY KEY (ship_id, layer_id, damage_type)
) STRICT;

CREATE TABLE item_defs (
    item_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    item_type TEXT NOT NULL CHECK (item_type IN ('ore', 'material', 'component', 'ammo', 'consumable', 'module')),
    unit_mass_kg REAL NOT NULL CHECK (unit_mass_kg >= 0),
    unit_volume_l INTEGER NOT NULL CHECK (unit_volume_l > 0),
    stackable INTEGER NOT NULL CHECK (stackable IN (0, 1)),
    base_ask_credit INTEGER NOT NULL CHECK (base_ask_credit >= 0),
    base_bid_credit INTEGER NOT NULL CHECK (base_bid_credit >= 0),
    CHECK (base_ask_credit > base_bid_credit),
    CHECK (item_type <> 'module' OR stackable = 0)
) STRICT;
CREATE TABLE module_defs (
    module_id TEXT PRIMARY KEY REFERENCES item_defs(item_id),
    slot_type TEXT NOT NULL REFERENCES slot_types(slot_type),
    power_pu REAL NOT NULL CHECK (power_pu >= 0),
    cpu_cu REAL NOT NULL CHECK (cpu_cu >= 0),
    cycle_s REAL NOT NULL CHECK (cycle_s >= 0),
    range_m REAL NOT NULL CHECK (range_m >= 0),
    energy_eu REAL NOT NULL CHECK (energy_eu >= 0),
    heat_hu REAL NOT NULL CHECK (heat_hu >= 0),
    max_per_ship INTEGER CHECK (max_per_ship IS NULL OR max_per_ship > 0),
    UNIQUE (module_id, slot_type),
    CHECK (cycle_s > 0 OR (energy_eu = 0 AND heat_hu = 0))
) STRICT;
CREATE TABLE weapon_defs (
    module_id TEXT PRIMARY KEY REFERENCES module_defs(module_id),
    damage_type TEXT NOT NULL REFERENCES damage_types(damage_type),
    raw_damage REAL NOT NULL CHECK (raw_damage > 0),
    projectile_speed_mps REAL CHECK (projectile_speed_mps IS NULL OR projectile_speed_mps > 0),
    ammo_item_id TEXT REFERENCES item_defs(item_id),
    ammo_per_cycle INTEGER NOT NULL CHECK (ammo_per_cycle >= 0),
    CHECK ((ammo_item_id IS NULL AND ammo_per_cycle = 0) OR (ammo_item_id IS NOT NULL AND ammo_per_cycle > 0))
) STRICT;
CREATE TABLE repair_defs (
    module_id TEXT PRIMARY KEY REFERENCES module_defs(module_id),
    layer_id TEXT NOT NULL REFERENCES defense_layers(layer_id),
    restore_amount REAL NOT NULL CHECK (restore_amount > 0),
    consumable_item_id TEXT REFERENCES item_defs(item_id),
    consumable_per_cycle INTEGER NOT NULL CHECK (consumable_per_cycle >= 0),
    CHECK ((consumable_item_id IS NULL AND consumable_per_cycle = 0) OR (consumable_item_id IS NOT NULL AND consumable_per_cycle > 0))
) STRICT;
CREATE TABLE stat_defs (
    stat_id TEXT PRIMARY KEY,
    unit TEXT NOT NULL
) STRICT;
CREATE TABLE module_stat_modifiers (
    module_id TEXT NOT NULL REFERENCES module_defs(module_id),
    stat_id TEXT NOT NULL REFERENCES stat_defs(stat_id),
    operation TEXT NOT NULL CHECK (operation IN ('add', 'multiply')),
    amount REAL NOT NULL,
    PRIMARY KEY (module_id, stat_id),
    CHECK (operation <> 'multiply' OR amount > 0)
) STRICT;
CREATE TABLE module_resistance_modifiers (
    module_id TEXT NOT NULL REFERENCES module_defs(module_id),
    layer_id TEXT NOT NULL REFERENCES defense_layers(layer_id),
    damage_type TEXT NOT NULL REFERENCES damage_types(damage_type),
    delta REAL NOT NULL CHECK (delta BETWEEN -1 AND 1),
    PRIMARY KEY (module_id, layer_id, damage_type)
) STRICT;
CREATE TABLE mining_defs (
    module_id TEXT PRIMARY KEY REFERENCES module_defs(module_id),
    base_yield_units INTEGER NOT NULL CHECK (base_yield_units > 0)
) STRICT;
CREATE TABLE mining_compatibility (
    module_id TEXT NOT NULL REFERENCES mining_defs(module_id),
    item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    PRIMARY KEY (module_id, item_id)
) STRICT;

CREATE TABLE ship_loadout_defs (
    loadout_id TEXT PRIMARY KEY,
    ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
    display_name TEXT NOT NULL,
    UNIQUE (loadout_id, ship_id)
) STRICT;
CREATE TABLE ship_loadout_items (
    loadout_id TEXT NOT NULL,
    ship_id TEXT NOT NULL,
    slot_type TEXT NOT NULL,
    slot_index INTEGER NOT NULL,
    module_id TEXT NOT NULL,
    PRIMARY KEY (loadout_id, slot_type, slot_index),
    FOREIGN KEY (loadout_id, ship_id) REFERENCES ship_loadout_defs(loadout_id, ship_id),
    FOREIGN KEY (ship_id, slot_type, slot_index) REFERENCES ship_slot_defs(ship_id, slot_type, slot_index),
    FOREIGN KEY (module_id, slot_type) REFERENCES module_defs(module_id, slot_type)
) STRICT;
CREATE INDEX loadout_items_module_idx ON ship_loadout_items(module_id);

CREATE TABLE risk_zone_defs (
    risk_zone_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    npc_level_min INTEGER NOT NULL CHECK (npc_level_min > 0),
    npc_level_max INTEGER NOT NULL CHECK (npc_level_max >= npc_level_min)
) STRICT;
CREATE TABLE npc_archetype_defs (
    archetype_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    base_shield INTEGER NOT NULL CHECK (base_shield >= 0),
    base_armor INTEGER NOT NULL CHECK (base_armor >= 0),
    base_hull INTEGER NOT NULL CHECK (base_hull > 0),
    base_raw_dps REAL NOT NULL CHECK (base_raw_dps > 0),
    damage_type TEXT NOT NULL REFERENCES damage_types(damage_type),
    speed_mps REAL NOT NULL CHECK (speed_mps > 0),
    range_m REAL NOT NULL CHECK (range_m > 0),
    base_reward_credit INTEGER NOT NULL CHECK (base_reward_credit >= 0)
) STRICT;
CREATE TABLE npc_level_defs (
    level INTEGER PRIMARY KEY CHECK (level > 0),
    hp_basis_points INTEGER NOT NULL CHECK (hp_basis_points > 0),
    dps_basis_points INTEGER NOT NULL CHECK (dps_basis_points > 0),
    reward_basis_points INTEGER NOT NULL CHECK (reward_basis_points > 0)
) STRICT;
CREATE TABLE npc_defs (
    npc_id TEXT PRIMARY KEY,
    archetype_id TEXT NOT NULL REFERENCES npc_archetype_defs(archetype_id),
    level INTEGER NOT NULL CHECK (level > 0),
    risk_zone_id TEXT NOT NULL REFERENCES risk_zone_defs(risk_zone_id),
    FOREIGN KEY (level) REFERENCES npc_level_defs(level)
) STRICT;
CREATE TABLE npc_resistances (
    archetype_id TEXT NOT NULL REFERENCES npc_archetype_defs(archetype_id),
    layer_id TEXT NOT NULL REFERENCES defense_layers(layer_id),
    damage_type TEXT NOT NULL REFERENCES damage_types(damage_type),
    resistance REAL NOT NULL CHECK (resistance BETWEEN 0 AND 1),
    PRIMARY KEY (archetype_id, layer_id, damage_type)
) STRICT;

CREATE TABLE module_exclusion_groups (
    group_id TEXT PRIMARY KEY,
    max_installed INTEGER NOT NULL CHECK (max_installed > 0)
) STRICT;
CREATE TABLE module_group_members (
    module_id TEXT NOT NULL REFERENCES module_defs(module_id),
    group_id TEXT NOT NULL REFERENCES module_exclusion_groups(group_id),
    PRIMARY KEY (module_id, group_id)
) STRICT;
CREATE TABLE module_activation_priority (
    module_id TEXT PRIMARY KEY REFERENCES module_defs(module_id),
    priority INTEGER NOT NULL CHECK (priority >= 0)
) STRICT;
CREATE TABLE resource_node_defs (
    node_id TEXT PRIMARY KEY,
    sector_id TEXT NOT NULL REFERENCES sector_defs(sector_id),
    item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    capacity_units INTEGER NOT NULL CHECK (capacity_units > 0),
    respawn_s REAL NOT NULL CHECK (respawn_s > 0)
) STRICT;

CREATE TABLE combat_benchmark_defs (
    benchmark_id TEXT PRIMARY KEY,
    loadout_id TEXT NOT NULL REFERENCES ship_loadout_defs(loadout_id),
    npc_id TEXT NOT NULL REFERENCES npc_defs(npc_id),
    player_can_win INTEGER NOT NULL CHECK (player_can_win IN (0, 1))
) STRICT;

CREATE TABLE system_defs (
    system_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL
) STRICT;
CREATE TABLE sector_defs (
    sector_id TEXT PRIMARY KEY,
    system_id TEXT NOT NULL REFERENCES system_defs(system_id),
    risk_zone_id TEXT NOT NULL REFERENCES risk_zone_defs(risk_zone_id)
) STRICT;
CREATE TABLE gate_class_defs (
    gate_class_id TEXT PRIMARY KEY,
    max_gross_mass_kg REAL NOT NULL CHECK (max_gross_mass_kg > 0),
    prepare_s REAL NOT NULL CHECK (prepare_s >= 0),
    cooldown_s REAL NOT NULL CHECK (cooldown_s >= 0),
    energy_cost_eu REAL NOT NULL CHECK (energy_cost_eu >= 0),
    fee_credit INTEGER NOT NULL CHECK (fee_credit >= 0),
    total_mass_budget_kg REAL CHECK (total_mass_budget_kg IS NULL OR total_mass_budget_kg > 0),
    lifetime_s REAL CHECK (lifetime_s IS NULL OR lifetime_s > 0)
) STRICT;
CREATE TABLE connection_defs (
    connection_id TEXT PRIMARY KEY,
    origin_sector_id TEXT NOT NULL REFERENCES sector_defs(sector_id),
    target_sector_id TEXT NOT NULL REFERENCES sector_defs(sector_id),
    bidirectional INTEGER NOT NULL CHECK (bidirectional IN (0, 1)),
    gate_class_id TEXT NOT NULL REFERENCES gate_class_defs(gate_class_id),
    energy_cost_override_eu REAL CHECK (energy_cost_override_eu IS NULL OR energy_cost_override_eu >= 0),
    fee_override_credit INTEGER CHECK (fee_override_credit IS NULL OR fee_override_credit >= 0),
    CHECK (origin_sector_id <> target_sector_id)
) STRICT;

CREATE TABLE recipe_defs (
    recipe_id TEXT PRIMARY KEY,
    output_item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    output_quantity INTEGER NOT NULL CHECK (output_quantity > 0),
    service_fee_credit INTEGER NOT NULL CHECK (service_fee_credit >= 0),
    duration_s REAL NOT NULL CHECK (duration_s >= 0)
) STRICT;
CREATE TABLE recipe_inputs (
    recipe_id TEXT NOT NULL REFERENCES recipe_defs(recipe_id),
    item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (recipe_id, item_id)
) STRICT;
CREATE TABLE recycle_outputs (
    source_item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    output_item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (source_item_id, output_item_id),
    CHECK (source_item_id <> output_item_id)
) STRICT;

-- NPC 采购实例冻结此标准拆解来源；制造实例保存其实际投入，不能临时挑配方。
CREATE TABLE module_salvage_recipe_defs (
    module_id TEXT PRIMARY KEY REFERENCES module_defs(module_id),
    recipe_id TEXT NOT NULL REFERENCES recipe_defs(recipe_id)
) STRICT;

CREATE TABLE asset_policy_defs (
    policy_id TEXT PRIMARY KEY,
    may_sell INTEGER NOT NULL CHECK (may_sell IN (0, 1)),
    may_recycle INTEGER NOT NULL CHECK (may_recycle IN (0, 1)),
    inherit_to_attached INTEGER NOT NULL CHECK (inherit_to_attached IN (0, 1)),
    inherit_to_supplies INTEGER NOT NULL CHECK (inherit_to_supplies IN (0, 1))
) STRICT;
CREATE TABLE starting_profile_defs (
    profile_template_id TEXT PRIMARY KEY,
    currency_id TEXT NOT NULL REFERENCES currency_defs(currency_id),
    starting_credit INTEGER NOT NULL CHECK (starting_credit >= 0)
) STRICT;
CREATE TABLE starting_inventory (
    profile_template_id TEXT NOT NULL REFERENCES starting_profile_defs(profile_template_id),
    item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    PRIMARY KEY (profile_template_id, item_id)
) STRICT;
CREATE TABLE tutorial_step_defs (
    step_id TEXT PRIMARY KEY,
    stage_code TEXT NOT NULL UNIQUE,
    step_order INTEGER NOT NULL UNIQUE CHECK (step_order >= 0),
    prerequisite_step_id TEXT REFERENCES tutorial_step_defs(step_id),
    action_kind TEXT NOT NULL,
    reward_credit INTEGER NOT NULL CHECK (reward_credit >= 0),
    required_item_id TEXT REFERENCES item_defs(item_id),
    required_quantity INTEGER CHECK (required_quantity IS NULL OR required_quantity > 0),
    target_npc_id TEXT REFERENCES npc_defs(npc_id),
    CHECK ((required_item_id IS NULL) = (required_quantity IS NULL)),
    CHECK (prerequisite_step_id IS NULL OR prerequisite_step_id <> step_id)
) STRICT;
CREATE TABLE starting_ships (
    profile_template_id TEXT NOT NULL REFERENCES starting_profile_defs(profile_template_id),
    loadout_id TEXT NOT NULL REFERENCES ship_loadout_defs(loadout_id),
    grant_kind TEXT NOT NULL CHECK (grant_kind IN ('owned', 'loan', 'unlock')),
    policy_id TEXT NOT NULL REFERENCES asset_policy_defs(policy_id),
    available_at_step_id TEXT REFERENCES tutorial_step_defs(step_id),
    PRIMARY KEY (profile_template_id, loadout_id)
) STRICT;
CREATE TABLE loadout_supply_defs (
    loadout_id TEXT NOT NULL REFERENCES ship_loadout_defs(loadout_id),
    item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (loadout_id, item_id)
) STRICT;
CREATE TABLE npc_loot_defs (
    archetype_id TEXT NOT NULL REFERENCES npc_archetype_defs(archetype_id),
    item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (archetype_id, item_id)
) STRICT;

CREATE VIEW module_full_defs AS
SELECT m.*, i.display_name, i.unit_mass_kg AS mass_kg,
       i.unit_volume_l AS volume_l, i.base_ask_credit, i.base_bid_credit
FROM module_defs AS m JOIN item_defs AS i ON i.item_id = m.module_id;

CREATE VIEW effective_connection_defs AS
SELECT c.connection_id, c.origin_sector_id, c.target_sector_id, c.bidirectional,
       g.max_gross_mass_kg, g.prepare_s, g.cooldown_s,
       COALESCE(c.energy_cost_override_eu, g.energy_cost_eu) AS energy_cost_eu,
       COALESCE(c.fee_override_credit, g.fee_credit) AS fee_credit,
       g.total_mass_budget_kg
FROM connection_defs AS c JOIN gate_class_defs AS g USING (gate_class_id);

CREATE VIEW npc_full_defs AS
SELECT n.npc_id, n.level, n.risk_zone_id, a.*,
       (a.base_shield * l.hp_basis_points + b.value_integer - 1) / b.value_integer AS shield_max,
       (a.base_armor * l.hp_basis_points + b.value_integer - 1) / b.value_integer AS armor_max,
       (a.base_hull * l.hp_basis_points + b.value_integer - 1) / b.value_integer AS hull_max,
       a.base_raw_dps * l.dps_basis_points / b.value_integer AS raw_dps,
       (a.base_reward_credit * l.reward_basis_points + b.value_integer - 1) / b.value_integer AS reward_credit
FROM npc_defs AS n JOIN npc_archetype_defs AS a USING (archetype_id)
JOIN npc_level_defs AS l USING (level)
JOIN rule_parameters AS b ON b.parameter_id = 'npc_basis_point_denominator';

-- B 内容：稳定位置/任务/库存/AI；仅声明内容，不执行任意脚本。
CREATE TABLE faction_defs (
    faction_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL
) STRICT;
CREATE TABLE unlock_defs (
    unlock_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    initially_unlocked INTEGER NOT NULL CHECK (initially_unlocked IN (0, 1))
) STRICT;
CREATE TABLE sector_runtime_defs (
    sector_id TEXT PRIMARY KEY REFERENCES sector_defs(sector_id),
    scene_asset_id TEXT NOT NULL UNIQUE,
    enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
    stage_code TEXT NOT NULL CHECK (stage_code IN ('A', 'B', 'C', 'D')),
    bounds_radius_m REAL NOT NULL CHECK (bounds_radius_m > 0)
) STRICT;
CREATE TABLE anchor_defs (
    anchor_id TEXT PRIMARY KEY,
    sector_id TEXT NOT NULL REFERENCES sector_runtime_defs(sector_id),
    anchor_kind TEXT NOT NULL CHECK (anchor_kind IN ('station', 'undock', 'gate_entry', 'gate_exit', 'resource', 'signal', 'flight_marker', 'npc_spawn', 'patrol')),
    x_m REAL NOT NULL,
    y_m REAL NOT NULL,
    z_m REAL NOT NULL,
    yaw_rad REAL NOT NULL,
    interaction_radius_m REAL NOT NULL CHECK (interaction_radius_m > 0),
    safe_radius_m REAL NOT NULL CHECK (safe_radius_m >= 0),
    UNIQUE (anchor_id, sector_id)
) STRICT;
CREATE TABLE station_defs (
    station_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    sector_id TEXT NOT NULL REFERENCES sector_runtime_defs(sector_id),
    faction_id TEXT NOT NULL REFERENCES faction_defs(faction_id),
    station_anchor_id TEXT NOT NULL UNIQUE,
    undock_anchor_id TEXT NOT NULL UNIQUE,
    stock_refresh_s REAL NOT NULL CHECK (stock_refresh_s > 0),
    buyback_budget_credit INTEGER NOT NULL CHECK (buyback_budget_credit >= 0),
    FOREIGN KEY (station_anchor_id, sector_id) REFERENCES anchor_defs(anchor_id, sector_id),
    FOREIGN KEY (undock_anchor_id, sector_id) REFERENCES anchor_defs(anchor_id, sector_id)
) STRICT;
CREATE TABLE service_defs (
    service_id TEXT PRIMARY KEY CHECK (service_id IN ('warehouse', 'repair', 'recharge', 'trade', 'ship_purchase', 'fitting', 'manufacture', 'recycle', 'mission_board', 'loan')),
    display_name TEXT NOT NULL
) STRICT;
CREATE TABLE station_service_defs (
    station_id TEXT NOT NULL REFERENCES station_defs(station_id),
    service_id TEXT NOT NULL REFERENCES service_defs(service_id),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    PRIMARY KEY (station_id, service_id)
) STRICT;
CREATE TABLE station_stock_defs (
    station_id TEXT NOT NULL REFERENCES station_defs(station_id),
    item_id TEXT NOT NULL REFERENCES item_defs(item_id),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    initial_units INTEGER NOT NULL CHECK (initial_units >= 0),
    target_units INTEGER NOT NULL CHECK (target_units >= 0),
    hard_cap_units INTEGER NOT NULL CHECK (hard_cap_units >= target_units AND hard_cap_units >= initial_units),
    restock_units_per_refresh INTEGER NOT NULL CHECK (restock_units_per_refresh >= 0),
    buyback_units_per_refresh INTEGER NOT NULL CHECK (buyback_units_per_refresh >= 0),
    allow_buy INTEGER NOT NULL CHECK (allow_buy IN (0, 1)),
    allow_sell INTEGER NOT NULL CHECK (allow_sell IN (0, 1)),
    PRIMARY KEY (station_id, item_id)
) STRICT;
CREATE TABLE station_ship_stock_defs (
    station_id TEXT NOT NULL REFERENCES station_defs(station_id),
    ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    initial_units INTEGER NOT NULL CHECK (initial_units >= 0),
    target_units INTEGER NOT NULL CHECK (target_units >= 0),
    hard_cap_units INTEGER NOT NULL CHECK (hard_cap_units >= target_units AND hard_cap_units >= initial_units),
    restock_units_per_refresh INTEGER NOT NULL CHECK (restock_units_per_refresh >= 0),
    PRIMARY KEY (station_id, ship_id)
) STRICT;
CREATE TABLE recipe_access_defs (
    recipe_id TEXT NOT NULL REFERENCES recipe_defs(recipe_id),
    station_id TEXT NOT NULL REFERENCES station_defs(station_id),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    PRIMARY KEY (recipe_id, station_id)
) STRICT;
CREATE TABLE gate_endpoint_defs (
    endpoint_id TEXT PRIMARY KEY,
    connection_id TEXT NOT NULL REFERENCES connection_defs(connection_id),
    origin_sector_id TEXT NOT NULL REFERENCES sector_runtime_defs(sector_id),
    target_sector_id TEXT NOT NULL REFERENCES sector_runtime_defs(sector_id),
    entry_anchor_id TEXT NOT NULL UNIQUE,
    exit_anchor_id TEXT NOT NULL UNIQUE,
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    UNIQUE (connection_id, origin_sector_id),
    FOREIGN KEY (entry_anchor_id, origin_sector_id) REFERENCES anchor_defs(anchor_id, sector_id),
    FOREIGN KEY (exit_anchor_id, target_sector_id) REFERENCES anchor_defs(anchor_id, sector_id),
    CHECK (origin_sector_id <> target_sector_id)
) STRICT;
CREATE TABLE signal_defs (
    signal_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    anchor_id TEXT NOT NULL UNIQUE REFERENCES anchor_defs(anchor_id),
    difficulty_multiplier REAL NOT NULL CHECK (difficulty_multiplier >= 1),
    threshold_progress REAL NOT NULL CHECK (threshold_progress > 0),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    occurrence_mode TEXT NOT NULL CHECK (occurrence_mode IN ('fixed', 'mission_scoped')),
    line_of_sight_required INTEGER NOT NULL CHECK (line_of_sight_required IN (0, 1))
) STRICT;
CREATE TABLE resource_node_locations (
    node_id TEXT PRIMARY KEY REFERENCES resource_node_defs(node_id),
    sector_id TEXT NOT NULL REFERENCES sector_runtime_defs(sector_id),
    anchor_id TEXT NOT NULL UNIQUE,
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    FOREIGN KEY (anchor_id, sector_id) REFERENCES anchor_defs(anchor_id, sector_id)
) STRICT;
CREATE TABLE npc_behavior_defs (
    behavior_id TEXT PRIMARY KEY,
    archetype_id TEXT NOT NULL UNIQUE REFERENCES npc_archetype_defs(archetype_id),
    detection_range_m REAL NOT NULL CHECK (detection_range_m > 0),
    target_drop_range_m REAL NOT NULL CHECK (target_drop_range_m >= detection_range_m),
    leash_radius_m REAL NOT NULL CHECK (leash_radius_m > 0),
    preferred_range_ratio REAL NOT NULL CHECK (preferred_range_ratio BETWEEN 0 AND 1),
    los_loss_timeout_s REAL NOT NULL CHECK (los_loss_timeout_s > 0),
    reaction_s REAL NOT NULL CHECK (reaction_s >= 0),
    return_radius_m REAL NOT NULL CHECK (return_radius_m > 0),
    patrol_wait_s REAL NOT NULL CHECK (patrol_wait_s >= 0),
    acceleration_mps2 REAL NOT NULL CHECK (acceleration_mps2 > 0),
    turn_rad_s REAL NOT NULL CHECK (turn_rad_s > 0),
    attack_cycle_s REAL NOT NULL CHECK (attack_cycle_s > 0),
    fire_cone_half_angle_rad REAL NOT NULL CHECK (fire_cone_half_angle_rad > 0 AND fire_cone_half_angle_rad <= 3.141592653589793),
    fire_mode TEXT NOT NULL CHECK (fire_mode IN ('projectile', 'ray')),
    projectile_speed_mps REAL,
    CHECK ((fire_mode = 'projectile' AND projectile_speed_mps IS NOT NULL AND projectile_speed_mps > 0) OR (fire_mode = 'ray' AND projectile_speed_mps IS NULL))
) STRICT;
CREATE TABLE npc_spawn_defs (
    spawn_id TEXT PRIMARY KEY,
    npc_id TEXT NOT NULL REFERENCES npc_defs(npc_id),
    sector_id TEXT NOT NULL REFERENCES sector_runtime_defs(sector_id),
    anchor_id TEXT NOT NULL UNIQUE,
    behavior_id TEXT NOT NULL REFERENCES npc_behavior_defs(behavior_id),
    occurrence_mode TEXT NOT NULL CHECK (occurrence_mode IN ('ambient', 'mission_scoped')),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    respawn_s REAL CHECK (respawn_s IS NULL OR respawn_s > 0),
    bounty_enabled INTEGER NOT NULL CHECK (bounty_enabled IN (0, 1)),
    loot_enabled INTEGER NOT NULL CHECK (loot_enabled IN (0, 1)),
    FOREIGN KEY (anchor_id, sector_id) REFERENCES anchor_defs(anchor_id, sector_id),
    CHECK ((occurrence_mode = 'ambient' AND respawn_s IS NOT NULL) OR (occurrence_mode = 'mission_scoped' AND respawn_s IS NULL))
) STRICT;
CREATE TABLE npc_patrol_points (
    spawn_id TEXT NOT NULL REFERENCES npc_spawn_defs(spawn_id),
    point_index INTEGER NOT NULL CHECK (point_index >= 0),
    anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
    PRIMARY KEY (spawn_id, point_index)
) STRICT;
CREATE TABLE mission_instance_states (
    state_id TEXT PRIMARY KEY CHECK (state_id IN ('locked', 'available', 'active', 'ready', 'completed', 'cooldown', 'failed', 'abandoned')),
    is_terminal INTEGER NOT NULL CHECK (is_terminal IN (0, 1))
) STRICT;
CREATE TABLE mission_defs (
    mission_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    mission_kind TEXT NOT NULL CHECK (mission_kind IN ('tutorial', 'contract', 'story')),
    tutorial_step_id TEXT UNIQUE REFERENCES tutorial_step_defs(step_id),
    accept_station_id TEXT NOT NULL REFERENCES station_defs(station_id),
    turnin_station_id TEXT NOT NULL REFERENCES station_defs(station_id),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    repeatable INTEGER NOT NULL CHECK (repeatable IN (0, 1)),
    repeat_cooldown_s REAL NOT NULL CHECK (repeat_cooldown_s >= 0),
    repeat_window_s REAL NOT NULL CHECK (repeat_window_s >= 0),
    max_completions_per_window INTEGER NOT NULL CHECK (max_completions_per_window > 0),
    max_active_instances INTEGER NOT NULL CHECK (max_active_instances = 1),
    deadline_s REAL CHECK (deadline_s IS NULL OR deadline_s > 0),
    reset_objectives_on_retry INTEGER NOT NULL CHECK (reset_objectives_on_retry = 1),
    CHECK ((mission_kind = 'tutorial' AND tutorial_step_id IS NOT NULL AND repeatable = 0) OR (mission_kind = 'contract' AND tutorial_step_id IS NULL AND repeatable = 1) OR (mission_kind = 'story' AND tutorial_step_id IS NULL AND repeatable = 0) OR (mission_kind = 'story' AND tutorial_step_id IS NULL AND repeatable = 0)),
    CHECK ((repeatable = 0 AND repeat_cooldown_s = 0 AND repeat_window_s = 0 AND max_completions_per_window = 1) OR (repeatable = 1 AND repeat_window_s > 0 AND repeat_cooldown_s > 0))
) STRICT;
CREATE TABLE mission_prerequisites (
    mission_id TEXT NOT NULL REFERENCES mission_defs(mission_id),
    prerequisite_mission_id TEXT NOT NULL REFERENCES mission_defs(mission_id),
    PRIMARY KEY (mission_id, prerequisite_mission_id),
    CHECK (mission_id <> prerequisite_mission_id)
) STRICT;
CREATE TABLE loan_service_defs (
    loan_service_id TEXT PRIMARY KEY,
    station_id TEXT NOT NULL REFERENCES station_defs(station_id),
    return_station_id TEXT NOT NULL REFERENCES station_defs(station_id),
    loadout_id TEXT NOT NULL REFERENCES ship_loadout_defs(loadout_id),
    policy_id TEXT NOT NULL REFERENCES asset_policy_defs(policy_id),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    required_mission_id TEXT NOT NULL REFERENCES mission_defs(mission_id),
    fee_credit INTEGER NOT NULL CHECK (fee_credit >= 0),
    max_active_instances INTEGER NOT NULL CHECK (max_active_instances = 1),
    replace_destroyed INTEGER NOT NULL CHECK (replace_destroyed IN (0, 1)),
    replacement_cooldown_s REAL NOT NULL CHECK (replacement_cooldown_s >= 0),
    operation_quota_units INTEGER CHECK (operation_quota_units IS NULL OR operation_quota_units > 0),
    gathered_policy_id TEXT NOT NULL REFERENCES asset_policy_defs(policy_id),
    requires_safe_switch INTEGER NOT NULL CHECK (requires_safe_switch = 1),
    remove_bound_on_return INTEGER NOT NULL CHECK (remove_bound_on_return = 1)
) STRICT;
CREATE TABLE mission_objective_defs (
    mission_id TEXT NOT NULL REFERENCES mission_defs(mission_id),
    objective_index INTEGER NOT NULL CHECK (objective_index >= 0),
    objective_kind TEXT NOT NULL CHECK (objective_kind IN ('undock', 'reach_anchor', 'brake_at_anchor', 'dock', 'scan_signal', 'transit_connection', 'collect', 'deliver', 'destroy_spawn', 'fit_validate', 'loan_checkout')),
    required_count INTEGER NOT NULL CHECK (required_count > 0),
    target_anchor_id TEXT REFERENCES anchor_defs(anchor_id),
    target_station_id TEXT REFERENCES station_defs(station_id),
    target_signal_id TEXT REFERENCES signal_defs(signal_id),
    target_node_id TEXT REFERENCES resource_node_defs(node_id),
    target_spawn_id TEXT REFERENCES npc_spawn_defs(spawn_id),
    target_connection_id TEXT REFERENCES connection_defs(connection_id),
    target_item_id TEXT REFERENCES item_defs(item_id),
    target_loan_service_id TEXT REFERENCES loan_service_defs(loan_service_id),
    max_speed_mps REAL CHECK (max_speed_mps IS NULL OR max_speed_mps >= 0),
    hold_s REAL NOT NULL CHECK (hold_s >= 0),
    consume_item INTEGER NOT NULL CHECK (consume_item IN (0, 1)),
    PRIMARY KEY (mission_id, objective_index),
    CHECK ((objective_kind = 'deliver' AND consume_item = 1) OR (objective_kind <> 'deliver' AND consume_item = 0)),
    CHECK (objective_kind NOT IN ('collect', 'deliver') OR target_item_id IS NOT NULL),
    CHECK (objective_kind <> 'collect' OR target_node_id IS NOT NULL),
    CHECK (objective_kind NOT IN ('dock', 'undock', 'deliver') OR target_station_id IS NOT NULL),
    CHECK (objective_kind NOT IN ('reach_anchor', 'brake_at_anchor') OR target_anchor_id IS NOT NULL),
    CHECK (objective_kind <> 'brake_at_anchor' OR (max_speed_mps IS NOT NULL AND hold_s > 0)),
    CHECK (objective_kind <> 'scan_signal' OR target_signal_id IS NOT NULL),
    CHECK (objective_kind <> 'transit_connection' OR target_connection_id IS NOT NULL),
    CHECK (objective_kind <> 'destroy_spawn' OR target_spawn_id IS NOT NULL),
    CHECK (objective_kind NOT IN ('fit_validate', 'loan_checkout') OR target_loan_service_id IS NOT NULL)
    ,CHECK ((target_anchor_id IS NOT NULL) + (target_station_id IS NOT NULL) +
            (target_signal_id IS NOT NULL) + (target_node_id IS NOT NULL) +
            (target_spawn_id IS NOT NULL) + (target_connection_id IS NOT NULL) +
            (target_item_id IS NOT NULL) + (target_loan_service_id IS NOT NULL) =
            CASE WHEN objective_kind IN ('collect', 'deliver') THEN 2 ELSE 1 END)
) STRICT;

CREATE INDEX anchors_sector_idx ON anchor_defs(sector_id);
CREATE INDEX mission_objectives_node_idx ON mission_objective_defs(target_node_id);
CREATE INDEX mission_objectives_spawn_idx ON mission_objective_defs(target_spawn_id);
CREATE INDEX mission_prerequisite_idx ON mission_prerequisites(prerequisite_mission_id);
CREATE TABLE mission_reward_defs (
    mission_id TEXT PRIMARY KEY REFERENCES mission_defs(mission_id),
    currency_id TEXT NOT NULL REFERENCES currency_defs(currency_id),
    reward_credit INTEGER NOT NULL CHECK (reward_credit >= 0)
) STRICT;
CREATE TABLE mission_unlock_rewards (
    mission_id TEXT NOT NULL REFERENCES mission_defs(mission_id),
    unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    PRIMARY KEY (mission_id, unlock_id)
) STRICT;
CREATE TABLE mission_state_transitions (
    from_state TEXT NOT NULL REFERENCES mission_instance_states(state_id),
    event_code TEXT NOT NULL CHECK (event_code IN ('prerequisites_met', 'accept', 'objectives_met', 'claim', 'fail', 'abandon', 'retry', 'repeat_wait', 'cooldown_elapsed')),
    to_state TEXT NOT NULL REFERENCES mission_instance_states(state_id),
    guard_code TEXT NOT NULL CHECK (guard_code IN ('prerequisites', 'eligible', 'all_objectives', 'turnin_atomic', 'active_failure', 'cleanup_loan', 'retry_eligible', 'repeatable', 'repeat_budget')),
    PRIMARY KEY (from_state, event_code),
    CHECK (from_state <> to_state)
) STRICT;
CREATE TABLE starting_inventory_policy_defs (
    profile_template_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    policy_id TEXT NOT NULL REFERENCES asset_policy_defs(policy_id),
    PRIMARY KEY (profile_template_id, item_id),
    FOREIGN KEY (profile_template_id, item_id) REFERENCES starting_inventory(profile_template_id, item_id)
) STRICT;
CREATE TABLE camera_profile_defs (
    profile_id TEXT PRIMARY KEY,
    ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
    mode TEXT NOT NULL CHECK (mode IN ('follow', 'front', 'tactical')),
    fov_deg REAL NOT NULL CHECK (fov_deg > 0 AND fov_deg < 180),
    distance_m REAL NOT NULL CHECK (distance_m >= 0),
    height_m REAL NOT NULL CHECK (height_m >= 0),
    look_ahead_m REAL NOT NULL CHECK (look_ahead_m >= 0),
    near_m REAL NOT NULL CHECK (near_m > 0),
    far_m REAL NOT NULL CHECK (far_m > near_m),
    zoom_min_m REAL NOT NULL CHECK (zoom_min_m >= 0),
    zoom_max_m REAL NOT NULL CHECK (zoom_max_m >= zoom_min_m),
    position_smooth_s REAL NOT NULL CHECK (position_smooth_s >= 0),
    rotation_smooth_s REAL NOT NULL CHECK (rotation_smooth_s >= 0),
    collision_margin_m REAL NOT NULL CHECK (collision_margin_m >= 0),
    UNIQUE (ship_id, mode)
) STRICT;
CREATE TABLE presentation_defs (
    presentation_id TEXT PRIMARY KEY,
    value_integer INTEGER,
    value_real REAL,
    unit TEXT NOT NULL,
    CHECK ((value_integer IS NULL) <> (value_real IS NULL))
) STRICT;

CREATE VIEW mission_summary_defs AS
SELECT m.*, r.currency_id, r.reward_credit
FROM mission_defs AS m JOIN mission_reward_defs AS r USING (mission_id);


-- Complete offline singleplayer definitions. Additive reviewed schema v3.
CREATE TABLE ship_role_defs (
 ship_id TEXT PRIMARY KEY REFERENCES ship_defs(ship_id), class_id TEXT NOT NULL,
 faction_id TEXT NOT NULL REFERENCES faction_defs(faction_id), required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id)
) STRICT;
CREATE TABLE module_tech_defs (
 module_id TEXT PRIMARY KEY REFERENCES module_defs(module_id), faction_id TEXT NOT NULL REFERENCES faction_defs(faction_id),
 tech_level INTEGER NOT NULL CHECK(tech_level BETWEEN 1 AND 3), required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id)
) STRICT;
CREATE TABLE research_defs (
 research_id TEXT PRIMARY KEY, display_name TEXT NOT NULL, station_faction_id TEXT NOT NULL REFERENCES faction_defs(faction_id),
 required_reputation INTEGER NOT NULL CHECK(required_reputation>=0), required_credit INTEGER NOT NULL CHECK(required_credit>=0),
 reward_unlock_id TEXT NOT NULL UNIQUE REFERENCES unlock_defs(unlock_id), verification_mission_id TEXT REFERENCES mission_defs(mission_id)
) STRICT;
CREATE TABLE research_inputs (
 research_id TEXT NOT NULL REFERENCES research_defs(research_id), item_id TEXT NOT NULL REFERENCES item_defs(item_id),
 quantity INTEGER NOT NULL CHECK(quantity>0), PRIMARY KEY(research_id,item_id)
) STRICT;
CREATE TABLE research_prerequisites (
 research_id TEXT NOT NULL REFERENCES research_defs(research_id), unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id), PRIMARY KEY(research_id,unlock_id)
) STRICT;
CREATE TABLE hull_recipe_defs (
 hull_recipe_id TEXT PRIMARY KEY, display_name TEXT NOT NULL, ship_id TEXT NOT NULL UNIQUE REFERENCES ship_defs(ship_id),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id), service_fee_credit INTEGER NOT NULL CHECK(service_fee_credit>=0)
) STRICT;
CREATE TABLE hull_recipe_inputs (
 hull_recipe_id TEXT NOT NULL REFERENCES hull_recipe_defs(hull_recipe_id), item_id TEXT NOT NULL REFERENCES item_defs(item_id),
 quantity INTEGER NOT NULL CHECK(quantity>0), PRIMARY KEY(hull_recipe_id,item_id)
) STRICT;
CREATE TABLE base_module_defs (
 base_module_id TEXT PRIMARY KEY, display_name TEXT NOT NULL, required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 service_fee_credit INTEGER NOT NULL CHECK(service_fee_credit>=0), service_kind TEXT NOT NULL CHECK(service_kind IN ('repair','industry','navigation','warehouse')),
 effect_multiplier REAL NOT NULL CHECK(effect_multiplier>=1 AND effect_multiplier<=2)
) STRICT;
CREATE TABLE base_module_inputs (
 base_module_id TEXT NOT NULL REFERENCES base_module_defs(base_module_id), item_id TEXT NOT NULL REFERENCES item_defs(item_id),
 quantity INTEGER NOT NULL CHECK(quantity>0), PRIMARY KEY(base_module_id,item_id)
) STRICT;
CREATE TABLE mission_reputation_rewards (
 mission_id TEXT NOT NULL REFERENCES mission_defs(mission_id), faction_id TEXT NOT NULL REFERENCES faction_defs(faction_id), reputation_delta INTEGER NOT NULL CHECK(reputation_delta BETWEEN 0 AND 1000),
 PRIMARY KEY(mission_id,faction_id)
) STRICT;

CREATE TABLE signal_unlock_rewards (
 signal_id TEXT NOT NULL REFERENCES signal_defs(signal_id), unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 PRIMARY KEY(signal_id,unlock_id)
) STRICT;

-- Schema4 additive combat sites and station salvage. Existing definitions are unchanged.
CREATE TABLE encounter_defs (
    encounter_id TEXT PRIMARY KEY,
    sector_id TEXT NOT NULL UNIQUE REFERENCES sector_runtime_defs(sector_id),
    display_name TEXT NOT NULL,
    anchor_id TEXT NOT NULL UNIQUE,
    reveal_range_m REAL NOT NULL CHECK(reveal_range_m > 0 AND reveal_range_m < 1e100),
    respawn_seconds REAL NOT NULL CHECK(respawn_seconds > 0 AND respawn_seconds < 1e100),
    warp_arrival_m REAL NOT NULL CHECK(warp_arrival_m > 0 AND warp_arrival_m < reveal_range_m),
    required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
    FOREIGN KEY(anchor_id,sector_id) REFERENCES anchor_defs(anchor_id,sector_id)
) STRICT;
CREATE TABLE encounter_members (
    encounter_id TEXT NOT NULL REFERENCES encounter_defs(encounter_id),
    spawn_id TEXT NOT NULL UNIQUE REFERENCES npc_spawn_defs(spawn_id),
    member_index INTEGER NOT NULL CHECK(member_index >= 0),
    PRIMARY KEY(encounter_id,spawn_id),
    UNIQUE(encounter_id,member_index)
) STRICT;
CREATE TABLE salvage_package_defs (
    package_def_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    volume_m3 REAL NOT NULL CHECK(volume_m3 > 0 AND volume_m3 < 1e100),
    mass_kg REAL NOT NULL CHECK(mass_kg > 0 AND mass_kg < 1e100)
) STRICT;
CREATE TABLE salvage_reward_defs (
    reward_id TEXT PRIMARY KEY,
    package_def_id TEXT NOT NULL REFERENCES salvage_package_defs(package_def_id),
    weight INTEGER NOT NULL CHECK(weight > 0 AND weight <= 4294967295),
    credit_units INTEGER NOT NULL CHECK(credit_units >= 0),
    item_def_id TEXT REFERENCES item_defs(item_id),
    quantity INTEGER NOT NULL CHECK(quantity >= 0),
    UNIQUE(reward_id,package_def_id),
    CHECK((item_def_id IS NULL AND quantity=0) OR (item_def_id IS NOT NULL AND quantity>0)),
    CHECK(credit_units>0 OR item_def_id IS NOT NULL)
) STRICT;
CREATE TABLE npc_salvage_defs (
    npc_def_id TEXT PRIMARY KEY REFERENCES npc_defs(npc_id),
    package_def_id TEXT NOT NULL REFERENCES salvage_package_defs(package_def_id)
) STRICT;
