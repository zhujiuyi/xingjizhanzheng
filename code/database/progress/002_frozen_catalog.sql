-- Generated from reviewed catalog DDL, not from save-provided SQL.

-- Regenerate, review and commit together with catalog schema changes.

-- Numeric-only seed updates do not change this fixed migration.

CREATE TABLE frozen_anchor_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    anchor_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    anchor_kind TEXT NOT NULL CHECK (anchor_kind IN ('station', 'undock', 'gate_entry', 'gate_exit', 'resource', 'signal', 'flight_marker', 'npc_spawn', 'patrol')),
    x_m REAL NOT NULL,
    y_m REAL NOT NULL,
    z_m REAL NOT NULL,
    yaw_rad REAL NOT NULL,
    interaction_radius_m REAL NOT NULL CHECK (interaction_radius_m > 0),
    safe_radius_m REAL NOT NULL CHECK (safe_radius_m >= 0),
    UNIQUE (content_snapshot_id, anchor_id, sector_id),
    PRIMARY KEY (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_runtime_defs (content_snapshot_id, sector_id)
) STRICT;
CREATE TRIGGER frozen_anchor_defs_insert_guard BEFORE INSERT ON frozen_anchor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_anchor_defs_update_guard BEFORE UPDATE ON frozen_anchor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_anchor_defs_delete_guard BEFORE DELETE ON frozen_anchor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_asset_policy_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    policy_id TEXT NOT NULL,
    may_sell INTEGER NOT NULL CHECK (may_sell IN (0, 1)),
    may_recycle INTEGER NOT NULL CHECK (may_recycle IN (0, 1)),
    inherit_to_attached INTEGER NOT NULL CHECK (inherit_to_attached IN (0, 1)),
    inherit_to_supplies INTEGER NOT NULL CHECK (inherit_to_supplies IN (0, 1)),
    PRIMARY KEY (content_snapshot_id, policy_id)
) STRICT;
CREATE TRIGGER frozen_asset_policy_defs_insert_guard BEFORE INSERT ON frozen_asset_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_asset_policy_defs_update_guard BEFORE UPDATE ON frozen_asset_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_asset_policy_defs_delete_guard BEFORE DELETE ON frozen_asset_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_camera_profile_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profile_id TEXT NOT NULL,
    ship_id TEXT NOT NULL,
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
    UNIQUE (content_snapshot_id, ship_id, mode),
    PRIMARY KEY (content_snapshot_id, profile_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_camera_profile_defs_insert_guard BEFORE INSERT ON frozen_camera_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_camera_profile_defs_update_guard BEFORE UPDATE ON frozen_camera_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_camera_profile_defs_delete_guard BEFORE DELETE ON frozen_camera_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_catalog_meta (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK (singleton = 1),
    pack_id TEXT NOT NULL,
    content_version TEXT NOT NULL,
    ruleset_version TEXT NOT NULL,
    schema_version INTEGER NOT NULL CHECK (schema_version > 0),
    source_document TEXT NOT NULL,
    hash_algorithm TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_catalog_meta_insert_guard BEFORE INSERT ON frozen_catalog_meta
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_catalog_meta_update_guard BEFORE UPDATE ON frozen_catalog_meta
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_catalog_meta_delete_guard BEFORE DELETE ON frozen_catalog_meta
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_combat_benchmark_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    benchmark_id TEXT NOT NULL,
    loadout_id TEXT NOT NULL,
    npc_id TEXT NOT NULL,
    player_can_win INTEGER NOT NULL CHECK (player_can_win IN (0, 1)),
    PRIMARY KEY (content_snapshot_id, benchmark_id),
    FOREIGN KEY (content_snapshot_id, loadout_id) REFERENCES frozen_ship_loadout_defs (content_snapshot_id, loadout_id),
    FOREIGN KEY (content_snapshot_id, npc_id) REFERENCES frozen_npc_defs (content_snapshot_id, npc_id)
) STRICT;
CREATE TRIGGER frozen_combat_benchmark_defs_insert_guard BEFORE INSERT ON frozen_combat_benchmark_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_combat_benchmark_defs_update_guard BEFORE UPDATE ON frozen_combat_benchmark_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_combat_benchmark_defs_delete_guard BEFORE DELETE ON frozen_combat_benchmark_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_connection_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    connection_id TEXT NOT NULL,
    origin_sector_id TEXT NOT NULL,
    target_sector_id TEXT NOT NULL,
    bidirectional INTEGER NOT NULL CHECK (bidirectional IN (0, 1)),
    gate_class_id TEXT NOT NULL,
    energy_cost_override_eu REAL CHECK (energy_cost_override_eu IS NULL OR energy_cost_override_eu >= 0),
    fee_override_credit INTEGER CHECK (fee_override_credit IS NULL OR fee_override_credit >= 0),
    CHECK (origin_sector_id <> target_sector_id),
    PRIMARY KEY (content_snapshot_id, connection_id),
    FOREIGN KEY (content_snapshot_id, origin_sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, target_sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, gate_class_id) REFERENCES frozen_gate_class_defs (content_snapshot_id, gate_class_id)
) STRICT;
CREATE TRIGGER frozen_connection_defs_insert_guard BEFORE INSERT ON frozen_connection_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_connection_defs_update_guard BEFORE UPDATE ON frozen_connection_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_connection_defs_delete_guard BEFORE DELETE ON frozen_connection_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_currency_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    currency_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    unit TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, currency_id)
) STRICT;
CREATE TRIGGER frozen_currency_defs_insert_guard BEFORE INSERT ON frozen_currency_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_currency_defs_update_guard BEFORE UPDATE ON frozen_currency_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_currency_defs_delete_guard BEFORE DELETE ON frozen_currency_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_damage_types (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    damage_type TEXT NOT NULL CHECK (damage_type IN ('kinetic', 'thermal', 'pulse')),
    PRIMARY KEY (content_snapshot_id, damage_type)
) STRICT;
CREATE TRIGGER frozen_damage_types_insert_guard BEFORE INSERT ON frozen_damage_types
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_damage_types_update_guard BEFORE UPDATE ON frozen_damage_types
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_damage_types_delete_guard BEFORE DELETE ON frozen_damage_types
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_defense_layers (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    layer_id TEXT NOT NULL CHECK (layer_id IN ('shield', 'armor', 'hull')),
    layer_order INTEGER NOT NULL CHECK (layer_order BETWEEN 0 AND 2),
    PRIMARY KEY (content_snapshot_id, layer_id),
    UNIQUE (content_snapshot_id, layer_order)
) STRICT;
CREATE TRIGGER frozen_defense_layers_insert_guard BEFORE INSERT ON frozen_defense_layers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_defense_layers_update_guard BEFORE UPDATE ON frozen_defense_layers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_defense_layers_delete_guard BEFORE DELETE ON frozen_defense_layers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_faction_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    faction_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, faction_id)
) STRICT;
CREATE TRIGGER frozen_faction_defs_insert_guard BEFORE INSERT ON frozen_faction_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_faction_defs_update_guard BEFORE UPDATE ON frozen_faction_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_faction_defs_delete_guard BEFORE DELETE ON frozen_faction_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_gate_class_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    gate_class_id TEXT NOT NULL,
    max_gross_mass_kg REAL NOT NULL CHECK (max_gross_mass_kg > 0),
    prepare_s REAL NOT NULL CHECK (prepare_s >= 0),
    cooldown_s REAL NOT NULL CHECK (cooldown_s >= 0),
    energy_cost_eu REAL NOT NULL CHECK (energy_cost_eu >= 0),
    fee_credit INTEGER NOT NULL CHECK (fee_credit >= 0),
    total_mass_budget_kg REAL CHECK (total_mass_budget_kg IS NULL OR total_mass_budget_kg > 0),
    lifetime_s REAL CHECK (lifetime_s IS NULL OR lifetime_s > 0),
    PRIMARY KEY (content_snapshot_id, gate_class_id)
) STRICT;
CREATE TRIGGER frozen_gate_class_defs_insert_guard BEFORE INSERT ON frozen_gate_class_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_gate_class_defs_update_guard BEFORE UPDATE ON frozen_gate_class_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_gate_class_defs_delete_guard BEFORE DELETE ON frozen_gate_class_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_gate_endpoint_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    endpoint_id TEXT NOT NULL,
    connection_id TEXT NOT NULL,
    origin_sector_id TEXT NOT NULL,
    target_sector_id TEXT NOT NULL,
    entry_anchor_id TEXT NOT NULL,
    exit_anchor_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    UNIQUE (content_snapshot_id, connection_id, origin_sector_id),
    FOREIGN KEY (content_snapshot_id, entry_anchor_id, origin_sector_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id, sector_id),
    FOREIGN KEY (content_snapshot_id, exit_anchor_id, target_sector_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id, sector_id),
    CHECK (origin_sector_id <> target_sector_id),
    PRIMARY KEY (content_snapshot_id, endpoint_id),
    FOREIGN KEY (content_snapshot_id, connection_id) REFERENCES frozen_connection_defs (content_snapshot_id, connection_id),
    FOREIGN KEY (content_snapshot_id, origin_sector_id) REFERENCES frozen_sector_runtime_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, target_sector_id) REFERENCES frozen_sector_runtime_defs (content_snapshot_id, sector_id),
    UNIQUE (content_snapshot_id, entry_anchor_id),
    UNIQUE (content_snapshot_id, exit_anchor_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_gate_endpoint_defs_insert_guard BEFORE INSERT ON frozen_gate_endpoint_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_gate_endpoint_defs_update_guard BEFORE UPDATE ON frozen_gate_endpoint_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_gate_endpoint_defs_delete_guard BEFORE DELETE ON frozen_gate_endpoint_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_item_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    item_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    item_type TEXT NOT NULL CHECK (item_type IN ('ore', 'material', 'component', 'ammo', 'consumable', 'module')),
    unit_mass_kg REAL NOT NULL CHECK (unit_mass_kg >= 0),
    unit_volume_l INTEGER NOT NULL CHECK (unit_volume_l > 0),
    stackable INTEGER NOT NULL CHECK (stackable IN (0, 1)),
    base_ask_credit INTEGER NOT NULL CHECK (base_ask_credit >= 0),
    base_bid_credit INTEGER NOT NULL CHECK (base_bid_credit >= 0),
    CHECK (base_ask_credit > base_bid_credit),
    CHECK (item_type <> 'module' OR stackable = 0),
    PRIMARY KEY (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_item_defs_insert_guard BEFORE INSERT ON frozen_item_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_item_defs_update_guard BEFORE UPDATE ON frozen_item_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_item_defs_delete_guard BEFORE DELETE ON frozen_item_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_loadout_supply_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    loadout_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (content_snapshot_id, loadout_id, item_id),
    FOREIGN KEY (content_snapshot_id, loadout_id) REFERENCES frozen_ship_loadout_defs (content_snapshot_id, loadout_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_loadout_supply_defs_insert_guard BEFORE INSERT ON frozen_loadout_supply_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_loadout_supply_defs_update_guard BEFORE UPDATE ON frozen_loadout_supply_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_loadout_supply_defs_delete_guard BEFORE DELETE ON frozen_loadout_supply_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_loan_service_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    loan_service_id TEXT NOT NULL,
    station_id TEXT NOT NULL,
    return_station_id TEXT NOT NULL,
    loadout_id TEXT NOT NULL,
    policy_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    required_mission_id TEXT NOT NULL,
    fee_credit INTEGER NOT NULL CHECK (fee_credit >= 0),
    max_active_instances INTEGER NOT NULL CHECK (max_active_instances = 1),
    replace_destroyed INTEGER NOT NULL CHECK (replace_destroyed IN (0, 1)),
    replacement_cooldown_s REAL NOT NULL CHECK (replacement_cooldown_s >= 0),
    operation_quota_units INTEGER CHECK (operation_quota_units IS NULL OR operation_quota_units > 0),
    gathered_policy_id TEXT NOT NULL,
    requires_safe_switch INTEGER NOT NULL CHECK (requires_safe_switch = 1),
    remove_bound_on_return INTEGER NOT NULL CHECK (remove_bound_on_return = 1),
    PRIMARY KEY (content_snapshot_id, loan_service_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, return_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, loadout_id) REFERENCES frozen_ship_loadout_defs (content_snapshot_id, loadout_id),
    FOREIGN KEY (content_snapshot_id, policy_id) REFERENCES frozen_asset_policy_defs (content_snapshot_id, policy_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id),
    FOREIGN KEY (content_snapshot_id, required_mission_id) REFERENCES frozen_mission_defs (content_snapshot_id, mission_id),
    FOREIGN KEY (content_snapshot_id, gathered_policy_id) REFERENCES frozen_asset_policy_defs (content_snapshot_id, policy_id)
) STRICT;
CREATE TRIGGER frozen_loan_service_defs_insert_guard BEFORE INSERT ON frozen_loan_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_loan_service_defs_update_guard BEFORE UPDATE ON frozen_loan_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_loan_service_defs_delete_guard BEFORE DELETE ON frozen_loan_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mining_compatibility (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, module_id, item_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_mining_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_mining_compatibility_insert_guard BEFORE INSERT ON frozen_mining_compatibility
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mining_compatibility_update_guard BEFORE UPDATE ON frozen_mining_compatibility
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mining_compatibility_delete_guard BEFORE DELETE ON frozen_mining_compatibility
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mining_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    base_yield_units INTEGER NOT NULL CHECK (base_yield_units > 0),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id)
) STRICT;
CREATE TRIGGER frozen_mining_defs_insert_guard BEFORE INSERT ON frozen_mining_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mining_defs_update_guard BEFORE UPDATE ON frozen_mining_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mining_defs_delete_guard BEFORE DELETE ON frozen_mining_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mission_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    mission_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    mission_kind TEXT NOT NULL CHECK (mission_kind IN ('tutorial', 'contract')),
    tutorial_step_id TEXT,
    accept_station_id TEXT NOT NULL,
    turnin_station_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    repeatable INTEGER NOT NULL CHECK (repeatable IN (0, 1)),
    repeat_cooldown_s REAL NOT NULL CHECK (repeat_cooldown_s >= 0),
    repeat_window_s REAL NOT NULL CHECK (repeat_window_s >= 0),
    max_completions_per_window INTEGER NOT NULL CHECK (max_completions_per_window > 0),
    max_active_instances INTEGER NOT NULL CHECK (max_active_instances = 1),
    deadline_s REAL CHECK (deadline_s IS NULL OR deadline_s > 0),
    reset_objectives_on_retry INTEGER NOT NULL CHECK (reset_objectives_on_retry = 1),
    CHECK ((mission_kind = 'tutorial' AND tutorial_step_id IS NOT NULL AND repeatable = 0) OR (mission_kind = 'contract' AND tutorial_step_id IS NULL AND repeatable = 1)),
    CHECK ((repeatable = 0 AND repeat_cooldown_s = 0 AND repeat_window_s = 0 AND max_completions_per_window = 1) OR (repeatable = 1 AND repeat_window_s > 0 AND repeat_cooldown_s > 0)),
    PRIMARY KEY (content_snapshot_id, mission_id),
    FOREIGN KEY (content_snapshot_id, tutorial_step_id) REFERENCES frozen_tutorial_step_defs (content_snapshot_id, step_id),
    UNIQUE (content_snapshot_id, tutorial_step_id),
    FOREIGN KEY (content_snapshot_id, accept_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, turnin_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_mission_defs_insert_guard BEFORE INSERT ON frozen_mission_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_defs_update_guard BEFORE UPDATE ON frozen_mission_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_defs_delete_guard BEFORE DELETE ON frozen_mission_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mission_instance_states (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    state_id TEXT NOT NULL CHECK (state_id IN ('locked', 'available', 'active', 'ready', 'completed', 'cooldown', 'failed', 'abandoned')),
    is_terminal INTEGER NOT NULL CHECK (is_terminal IN (0, 1)),
    PRIMARY KEY (content_snapshot_id, state_id)
) STRICT;
CREATE TRIGGER frozen_mission_instance_states_insert_guard BEFORE INSERT ON frozen_mission_instance_states
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_instance_states_update_guard BEFORE UPDATE ON frozen_mission_instance_states
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_instance_states_delete_guard BEFORE DELETE ON frozen_mission_instance_states
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mission_objective_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    mission_id TEXT NOT NULL,
    objective_index INTEGER NOT NULL CHECK (objective_index >= 0),
    objective_kind TEXT NOT NULL CHECK (objective_kind IN ('undock', 'reach_anchor', 'brake_at_anchor', 'dock', 'scan_signal', 'transit_connection', 'collect', 'deliver', 'destroy_spawn', 'fit_validate', 'loan_checkout')),
    required_count INTEGER NOT NULL CHECK (required_count > 0),
    target_anchor_id TEXT,
    target_station_id TEXT,
    target_signal_id TEXT,
    target_node_id TEXT,
    target_spawn_id TEXT,
    target_connection_id TEXT,
    target_item_id TEXT,
    target_loan_service_id TEXT,
    max_speed_mps REAL CHECK (max_speed_mps IS NULL OR max_speed_mps >= 0),
    hold_s REAL NOT NULL CHECK (hold_s >= 0),
    consume_item INTEGER NOT NULL CHECK (consume_item IN (0, 1)),
    CHECK ((objective_kind = 'deliver' AND consume_item = 1) OR (objective_kind <> 'deliver' AND consume_item = 0)),
    CHECK (objective_kind NOT IN ('collect', 'deliver') OR target_item_id IS NOT NULL),
    CHECK (objective_kind <> 'collect' OR target_node_id IS NOT NULL),
    CHECK (objective_kind NOT IN ('dock', 'undock', 'deliver') OR target_station_id IS NOT NULL),
    CHECK (objective_kind NOT IN ('reach_anchor', 'brake_at_anchor') OR target_anchor_id IS NOT NULL),
    CHECK (objective_kind <> 'brake_at_anchor' OR (max_speed_mps IS NOT NULL AND hold_s > 0)),
    CHECK (objective_kind <> 'scan_signal' OR target_signal_id IS NOT NULL),
    CHECK (objective_kind <> 'transit_connection' OR target_connection_id IS NOT NULL),
    CHECK (objective_kind <> 'destroy_spawn' OR target_spawn_id IS NOT NULL),
    CHECK (objective_kind NOT IN ('fit_validate', 'loan_checkout') OR target_loan_service_id IS NOT NULL),
    CHECK ((target_anchor_id IS NOT NULL) + (target_station_id IS NOT NULL) +
            (target_signal_id IS NOT NULL) + (target_node_id IS NOT NULL) +
            (target_spawn_id IS NOT NULL) + (target_connection_id IS NOT NULL) +
            (target_item_id IS NOT NULL) + (target_loan_service_id IS NOT NULL) =
            CASE WHEN objective_kind IN ('collect', 'deliver') THEN 2 ELSE 1 END),
    PRIMARY KEY (content_snapshot_id, mission_id, objective_index),
    FOREIGN KEY (content_snapshot_id, mission_id) REFERENCES frozen_mission_defs (content_snapshot_id, mission_id),
    FOREIGN KEY (content_snapshot_id, target_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, target_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, target_signal_id) REFERENCES frozen_signal_defs (content_snapshot_id, signal_id),
    FOREIGN KEY (content_snapshot_id, target_node_id) REFERENCES frozen_resource_node_defs (content_snapshot_id, node_id),
    FOREIGN KEY (content_snapshot_id, target_spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, target_connection_id) REFERENCES frozen_connection_defs (content_snapshot_id, connection_id),
    FOREIGN KEY (content_snapshot_id, target_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id),
    FOREIGN KEY (content_snapshot_id, target_loan_service_id) REFERENCES frozen_loan_service_defs (content_snapshot_id, loan_service_id)
) STRICT;
CREATE TRIGGER frozen_mission_objective_defs_insert_guard BEFORE INSERT ON frozen_mission_objective_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_objective_defs_update_guard BEFORE UPDATE ON frozen_mission_objective_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_objective_defs_delete_guard BEFORE DELETE ON frozen_mission_objective_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mission_prerequisites (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    mission_id TEXT NOT NULL,
    prerequisite_mission_id TEXT NOT NULL,
    CHECK (mission_id <> prerequisite_mission_id),
    PRIMARY KEY (content_snapshot_id, mission_id, prerequisite_mission_id),
    FOREIGN KEY (content_snapshot_id, mission_id) REFERENCES frozen_mission_defs (content_snapshot_id, mission_id),
    FOREIGN KEY (content_snapshot_id, prerequisite_mission_id) REFERENCES frozen_mission_defs (content_snapshot_id, mission_id)
) STRICT;
CREATE TRIGGER frozen_mission_prerequisites_insert_guard BEFORE INSERT ON frozen_mission_prerequisites
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_prerequisites_update_guard BEFORE UPDATE ON frozen_mission_prerequisites
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_prerequisites_delete_guard BEFORE DELETE ON frozen_mission_prerequisites
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mission_reward_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    mission_id TEXT NOT NULL,
    currency_id TEXT NOT NULL,
    reward_credit INTEGER NOT NULL CHECK (reward_credit >= 0),
    PRIMARY KEY (content_snapshot_id, mission_id),
    FOREIGN KEY (content_snapshot_id, mission_id) REFERENCES frozen_mission_defs (content_snapshot_id, mission_id),
    FOREIGN KEY (content_snapshot_id, currency_id) REFERENCES frozen_currency_defs (content_snapshot_id, currency_id)
) STRICT;
CREATE TRIGGER frozen_mission_reward_defs_insert_guard BEFORE INSERT ON frozen_mission_reward_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_reward_defs_update_guard BEFORE UPDATE ON frozen_mission_reward_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_reward_defs_delete_guard BEFORE DELETE ON frozen_mission_reward_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mission_state_transitions (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    from_state TEXT NOT NULL,
    event_code TEXT NOT NULL CHECK (event_code IN ('prerequisites_met', 'accept', 'objectives_met', 'claim', 'fail', 'abandon', 'retry', 'repeat_wait', 'cooldown_elapsed')),
    to_state TEXT NOT NULL,
    guard_code TEXT NOT NULL CHECK (guard_code IN ('prerequisites', 'eligible', 'all_objectives', 'turnin_atomic', 'active_failure', 'cleanup_loan', 'retry_eligible', 'repeatable', 'repeat_budget')),
    CHECK (from_state <> to_state),
    PRIMARY KEY (content_snapshot_id, from_state, event_code),
    FOREIGN KEY (content_snapshot_id, from_state) REFERENCES frozen_mission_instance_states (content_snapshot_id, state_id),
    FOREIGN KEY (content_snapshot_id, to_state) REFERENCES frozen_mission_instance_states (content_snapshot_id, state_id)
) STRICT;
CREATE TRIGGER frozen_mission_state_transitions_insert_guard BEFORE INSERT ON frozen_mission_state_transitions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_state_transitions_update_guard BEFORE UPDATE ON frozen_mission_state_transitions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_state_transitions_delete_guard BEFORE DELETE ON frozen_mission_state_transitions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_mission_unlock_rewards (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    mission_id TEXT NOT NULL,
    unlock_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, mission_id, unlock_id),
    FOREIGN KEY (content_snapshot_id, mission_id) REFERENCES frozen_mission_defs (content_snapshot_id, mission_id),
    FOREIGN KEY (content_snapshot_id, unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_mission_unlock_rewards_insert_guard BEFORE INSERT ON frozen_mission_unlock_rewards
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_unlock_rewards_update_guard BEFORE UPDATE ON frozen_mission_unlock_rewards
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_mission_unlock_rewards_delete_guard BEFORE DELETE ON frozen_mission_unlock_rewards
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_module_activation_priority (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    priority INTEGER NOT NULL CHECK (priority >= 0),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id)
) STRICT;
CREATE TRIGGER frozen_module_activation_priority_insert_guard BEFORE INSERT ON frozen_module_activation_priority
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_activation_priority_update_guard BEFORE UPDATE ON frozen_module_activation_priority
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_activation_priority_delete_guard BEFORE DELETE ON frozen_module_activation_priority
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_module_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    slot_type TEXT NOT NULL,
    power_pu REAL NOT NULL CHECK (power_pu >= 0),
    cpu_cu REAL NOT NULL CHECK (cpu_cu >= 0),
    cycle_s REAL NOT NULL CHECK (cycle_s >= 0),
    range_m REAL NOT NULL CHECK (range_m >= 0),
    energy_eu REAL NOT NULL CHECK (energy_eu >= 0),
    heat_hu REAL NOT NULL CHECK (heat_hu >= 0),
    max_per_ship INTEGER CHECK (max_per_ship IS NULL OR max_per_ship > 0),
    UNIQUE (content_snapshot_id, module_id, slot_type),
    CHECK (cycle_s > 0 OR (energy_eu = 0 AND heat_hu = 0)),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id),
    FOREIGN KEY (content_snapshot_id, slot_type) REFERENCES frozen_slot_types (content_snapshot_id, slot_type)
) STRICT;
CREATE TRIGGER frozen_module_defs_insert_guard BEFORE INSERT ON frozen_module_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_defs_update_guard BEFORE UPDATE ON frozen_module_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_defs_delete_guard BEFORE DELETE ON frozen_module_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_module_exclusion_groups (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    group_id TEXT NOT NULL,
    max_installed INTEGER NOT NULL CHECK (max_installed > 0),
    PRIMARY KEY (content_snapshot_id, group_id)
) STRICT;
CREATE TRIGGER frozen_module_exclusion_groups_insert_guard BEFORE INSERT ON frozen_module_exclusion_groups
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_exclusion_groups_update_guard BEFORE UPDATE ON frozen_module_exclusion_groups
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_exclusion_groups_delete_guard BEFORE DELETE ON frozen_module_exclusion_groups
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_module_group_members (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    group_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, module_id, group_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, group_id) REFERENCES frozen_module_exclusion_groups (content_snapshot_id, group_id)
) STRICT;
CREATE TRIGGER frozen_module_group_members_insert_guard BEFORE INSERT ON frozen_module_group_members
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_group_members_update_guard BEFORE UPDATE ON frozen_module_group_members
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_group_members_delete_guard BEFORE DELETE ON frozen_module_group_members
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_module_resistance_modifiers (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    layer_id TEXT NOT NULL,
    damage_type TEXT NOT NULL,
    delta REAL NOT NULL CHECK (delta BETWEEN -1 AND 1),
    PRIMARY KEY (content_snapshot_id, module_id, layer_id, damage_type),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, layer_id) REFERENCES frozen_defense_layers (content_snapshot_id, layer_id),
    FOREIGN KEY (content_snapshot_id, damage_type) REFERENCES frozen_damage_types (content_snapshot_id, damage_type)
) STRICT;
CREATE TRIGGER frozen_module_resistance_modifiers_insert_guard BEFORE INSERT ON frozen_module_resistance_modifiers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_resistance_modifiers_update_guard BEFORE UPDATE ON frozen_module_resistance_modifiers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_resistance_modifiers_delete_guard BEFORE DELETE ON frozen_module_resistance_modifiers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_module_salvage_recipe_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    recipe_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, recipe_id) REFERENCES frozen_recipe_defs (content_snapshot_id, recipe_id)
) STRICT;
CREATE TRIGGER frozen_module_salvage_recipe_defs_insert_guard BEFORE INSERT ON frozen_module_salvage_recipe_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_salvage_recipe_defs_update_guard BEFORE UPDATE ON frozen_module_salvage_recipe_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_salvage_recipe_defs_delete_guard BEFORE DELETE ON frozen_module_salvage_recipe_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_module_stat_modifiers (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    stat_id TEXT NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('add', 'multiply')),
    amount REAL NOT NULL,
    CHECK (operation <> 'multiply' OR amount > 0),
    PRIMARY KEY (content_snapshot_id, module_id, stat_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, stat_id) REFERENCES frozen_stat_defs (content_snapshot_id, stat_id)
) STRICT;
CREATE TRIGGER frozen_module_stat_modifiers_insert_guard BEFORE INSERT ON frozen_module_stat_modifiers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_stat_modifiers_update_guard BEFORE UPDATE ON frozen_module_stat_modifiers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_module_stat_modifiers_delete_guard BEFORE DELETE ON frozen_module_stat_modifiers
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_npc_archetype_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    archetype_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    base_shield INTEGER NOT NULL CHECK (base_shield >= 0),
    base_armor INTEGER NOT NULL CHECK (base_armor >= 0),
    base_hull INTEGER NOT NULL CHECK (base_hull > 0),
    base_raw_dps REAL NOT NULL CHECK (base_raw_dps > 0),
    damage_type TEXT NOT NULL,
    speed_mps REAL NOT NULL CHECK (speed_mps > 0),
    range_m REAL NOT NULL CHECK (range_m > 0),
    base_reward_credit INTEGER NOT NULL CHECK (base_reward_credit >= 0),
    PRIMARY KEY (content_snapshot_id, archetype_id),
    FOREIGN KEY (content_snapshot_id, damage_type) REFERENCES frozen_damage_types (content_snapshot_id, damage_type)
) STRICT;
CREATE TRIGGER frozen_npc_archetype_defs_insert_guard BEFORE INSERT ON frozen_npc_archetype_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_archetype_defs_update_guard BEFORE UPDATE ON frozen_npc_archetype_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_archetype_defs_delete_guard BEFORE DELETE ON frozen_npc_archetype_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_npc_behavior_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    behavior_id TEXT NOT NULL,
    archetype_id TEXT NOT NULL,
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
    CHECK ((fire_mode = 'projectile' AND projectile_speed_mps IS NOT NULL AND projectile_speed_mps > 0) OR (fire_mode = 'ray' AND projectile_speed_mps IS NULL)),
    PRIMARY KEY (content_snapshot_id, behavior_id),
    FOREIGN KEY (content_snapshot_id, archetype_id) REFERENCES frozen_npc_archetype_defs (content_snapshot_id, archetype_id),
    UNIQUE (content_snapshot_id, archetype_id)
) STRICT;
CREATE TRIGGER frozen_npc_behavior_defs_insert_guard BEFORE INSERT ON frozen_npc_behavior_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_behavior_defs_update_guard BEFORE UPDATE ON frozen_npc_behavior_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_behavior_defs_delete_guard BEFORE DELETE ON frozen_npc_behavior_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_npc_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    npc_id TEXT NOT NULL,
    archetype_id TEXT NOT NULL,
    level INTEGER NOT NULL CHECK (level > 0),
    risk_zone_id TEXT NOT NULL,
    FOREIGN KEY (content_snapshot_id, level) REFERENCES frozen_npc_level_defs (content_snapshot_id, level),
    PRIMARY KEY (content_snapshot_id, npc_id),
    FOREIGN KEY (content_snapshot_id, archetype_id) REFERENCES frozen_npc_archetype_defs (content_snapshot_id, archetype_id),
    FOREIGN KEY (content_snapshot_id, risk_zone_id) REFERENCES frozen_risk_zone_defs (content_snapshot_id, risk_zone_id)
) STRICT;
CREATE TRIGGER frozen_npc_defs_insert_guard BEFORE INSERT ON frozen_npc_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_defs_update_guard BEFORE UPDATE ON frozen_npc_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_defs_delete_guard BEFORE DELETE ON frozen_npc_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_npc_level_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    level INTEGER NOT NULL CHECK (level > 0),
    hp_basis_points INTEGER NOT NULL CHECK (hp_basis_points > 0),
    dps_basis_points INTEGER NOT NULL CHECK (dps_basis_points > 0),
    reward_basis_points INTEGER NOT NULL CHECK (reward_basis_points > 0),
    PRIMARY KEY (content_snapshot_id, level)
) STRICT;
CREATE TRIGGER frozen_npc_level_defs_insert_guard BEFORE INSERT ON frozen_npc_level_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_level_defs_update_guard BEFORE UPDATE ON frozen_npc_level_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_level_defs_delete_guard BEFORE DELETE ON frozen_npc_level_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_npc_loot_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    archetype_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (content_snapshot_id, archetype_id, item_id),
    FOREIGN KEY (content_snapshot_id, archetype_id) REFERENCES frozen_npc_archetype_defs (content_snapshot_id, archetype_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_npc_loot_defs_insert_guard BEFORE INSERT ON frozen_npc_loot_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_loot_defs_update_guard BEFORE UPDATE ON frozen_npc_loot_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_loot_defs_delete_guard BEFORE DELETE ON frozen_npc_loot_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_npc_patrol_points (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    spawn_id TEXT NOT NULL,
    point_index INTEGER NOT NULL CHECK (point_index >= 0),
    anchor_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, spawn_id, point_index),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id)
) STRICT;
CREATE TRIGGER frozen_npc_patrol_points_insert_guard BEFORE INSERT ON frozen_npc_patrol_points
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_patrol_points_update_guard BEFORE UPDATE ON frozen_npc_patrol_points
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_patrol_points_delete_guard BEFORE DELETE ON frozen_npc_patrol_points
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_npc_resistances (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    archetype_id TEXT NOT NULL,
    layer_id TEXT NOT NULL,
    damage_type TEXT NOT NULL,
    resistance REAL NOT NULL CHECK (resistance BETWEEN 0 AND 1),
    PRIMARY KEY (content_snapshot_id, archetype_id, layer_id, damage_type),
    FOREIGN KEY (content_snapshot_id, archetype_id) REFERENCES frozen_npc_archetype_defs (content_snapshot_id, archetype_id),
    FOREIGN KEY (content_snapshot_id, layer_id) REFERENCES frozen_defense_layers (content_snapshot_id, layer_id),
    FOREIGN KEY (content_snapshot_id, damage_type) REFERENCES frozen_damage_types (content_snapshot_id, damage_type)
) STRICT;
CREATE TRIGGER frozen_npc_resistances_insert_guard BEFORE INSERT ON frozen_npc_resistances
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_resistances_update_guard BEFORE UPDATE ON frozen_npc_resistances
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_resistances_delete_guard BEFORE DELETE ON frozen_npc_resistances
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_npc_spawn_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    spawn_id TEXT NOT NULL,
    npc_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    anchor_id TEXT NOT NULL,
    behavior_id TEXT NOT NULL,
    occurrence_mode TEXT NOT NULL CHECK (occurrence_mode IN ('ambient', 'mission_scoped')),
    required_unlock_id TEXT NOT NULL,
    respawn_s REAL CHECK (respawn_s IS NULL OR respawn_s > 0),
    bounty_enabled INTEGER NOT NULL CHECK (bounty_enabled IN (0, 1)),
    loot_enabled INTEGER NOT NULL CHECK (loot_enabled IN (0, 1)),
    FOREIGN KEY (content_snapshot_id, anchor_id, sector_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id, sector_id),
    CHECK ((occurrence_mode = 'ambient' AND respawn_s IS NOT NULL) OR (occurrence_mode = 'mission_scoped' AND respawn_s IS NULL)),
    PRIMARY KEY (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, npc_id) REFERENCES frozen_npc_defs (content_snapshot_id, npc_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_runtime_defs (content_snapshot_id, sector_id),
    UNIQUE (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, behavior_id) REFERENCES frozen_npc_behavior_defs (content_snapshot_id, behavior_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_npc_spawn_defs_insert_guard BEFORE INSERT ON frozen_npc_spawn_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_spawn_defs_update_guard BEFORE UPDATE ON frozen_npc_spawn_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_spawn_defs_delete_guard BEFORE DELETE ON frozen_npc_spawn_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_presentation_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    presentation_id TEXT NOT NULL,
    value_integer INTEGER,
    value_real REAL,
    unit TEXT NOT NULL,
    CHECK ((value_integer IS NULL) <> (value_real IS NULL)),
    PRIMARY KEY (content_snapshot_id, presentation_id)
) STRICT;
CREATE TRIGGER frozen_presentation_defs_insert_guard BEFORE INSERT ON frozen_presentation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_presentation_defs_update_guard BEFORE UPDATE ON frozen_presentation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_presentation_defs_delete_guard BEFORE DELETE ON frozen_presentation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_recipe_access_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    recipe_id TEXT NOT NULL,
    station_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, recipe_id, station_id),
    FOREIGN KEY (content_snapshot_id, recipe_id) REFERENCES frozen_recipe_defs (content_snapshot_id, recipe_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_recipe_access_defs_insert_guard BEFORE INSERT ON frozen_recipe_access_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_recipe_access_defs_update_guard BEFORE UPDATE ON frozen_recipe_access_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_recipe_access_defs_delete_guard BEFORE DELETE ON frozen_recipe_access_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_recipe_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    recipe_id TEXT NOT NULL,
    output_item_id TEXT NOT NULL,
    output_quantity INTEGER NOT NULL CHECK (output_quantity > 0),
    service_fee_credit INTEGER NOT NULL CHECK (service_fee_credit >= 0),
    duration_s REAL NOT NULL CHECK (duration_s >= 0),
    PRIMARY KEY (content_snapshot_id, recipe_id),
    FOREIGN KEY (content_snapshot_id, output_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_recipe_defs_insert_guard BEFORE INSERT ON frozen_recipe_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_recipe_defs_update_guard BEFORE UPDATE ON frozen_recipe_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_recipe_defs_delete_guard BEFORE DELETE ON frozen_recipe_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_recipe_inputs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    recipe_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (content_snapshot_id, recipe_id, item_id),
    FOREIGN KEY (content_snapshot_id, recipe_id) REFERENCES frozen_recipe_defs (content_snapshot_id, recipe_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_recipe_inputs_insert_guard BEFORE INSERT ON frozen_recipe_inputs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_recipe_inputs_update_guard BEFORE UPDATE ON frozen_recipe_inputs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_recipe_inputs_delete_guard BEFORE DELETE ON frozen_recipe_inputs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_recycle_outputs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    source_item_id TEXT NOT NULL,
    output_item_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    CHECK (source_item_id <> output_item_id),
    PRIMARY KEY (content_snapshot_id, source_item_id, output_item_id),
    FOREIGN KEY (content_snapshot_id, source_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id),
    FOREIGN KEY (content_snapshot_id, output_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_recycle_outputs_insert_guard BEFORE INSERT ON frozen_recycle_outputs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_recycle_outputs_update_guard BEFORE UPDATE ON frozen_recycle_outputs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_recycle_outputs_delete_guard BEFORE DELETE ON frozen_recycle_outputs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_repair_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    layer_id TEXT NOT NULL,
    restore_amount REAL NOT NULL CHECK (restore_amount > 0),
    consumable_item_id TEXT,
    consumable_per_cycle INTEGER NOT NULL CHECK (consumable_per_cycle >= 0),
    CHECK ((consumable_item_id IS NULL AND consumable_per_cycle = 0) OR (consumable_item_id IS NOT NULL AND consumable_per_cycle > 0)),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, layer_id) REFERENCES frozen_defense_layers (content_snapshot_id, layer_id),
    FOREIGN KEY (content_snapshot_id, consumable_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_repair_defs_insert_guard BEFORE INSERT ON frozen_repair_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_repair_defs_update_guard BEFORE UPDATE ON frozen_repair_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_repair_defs_delete_guard BEFORE DELETE ON frozen_repair_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_resource_node_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    node_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    capacity_units INTEGER NOT NULL CHECK (capacity_units > 0),
    respawn_s REAL NOT NULL CHECK (respawn_s > 0),
    PRIMARY KEY (content_snapshot_id, node_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_resource_node_defs_insert_guard BEFORE INSERT ON frozen_resource_node_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_resource_node_defs_update_guard BEFORE UPDATE ON frozen_resource_node_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_resource_node_defs_delete_guard BEFORE DELETE ON frozen_resource_node_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_resource_node_locations (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    node_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    anchor_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    FOREIGN KEY (content_snapshot_id, anchor_id, sector_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id, sector_id),
    PRIMARY KEY (content_snapshot_id, node_id),
    FOREIGN KEY (content_snapshot_id, node_id) REFERENCES frozen_resource_node_defs (content_snapshot_id, node_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_runtime_defs (content_snapshot_id, sector_id),
    UNIQUE (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_resource_node_locations_insert_guard BEFORE INSERT ON frozen_resource_node_locations
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_resource_node_locations_update_guard BEFORE UPDATE ON frozen_resource_node_locations
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_resource_node_locations_delete_guard BEFORE DELETE ON frozen_resource_node_locations
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_risk_zone_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    risk_zone_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    npc_level_min INTEGER NOT NULL CHECK (npc_level_min > 0),
    npc_level_max INTEGER NOT NULL CHECK (npc_level_max >= npc_level_min),
    PRIMARY KEY (content_snapshot_id, risk_zone_id)
) STRICT;
CREATE TRIGGER frozen_risk_zone_defs_insert_guard BEFORE INSERT ON frozen_risk_zone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_risk_zone_defs_update_guard BEFORE UPDATE ON frozen_risk_zone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_risk_zone_defs_delete_guard BEFORE DELETE ON frozen_risk_zone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_rule_parameters (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    parameter_id TEXT NOT NULL,
    value_integer INTEGER,
    value_real REAL,
    unit TEXT NOT NULL,
    CHECK ((value_integer IS NULL) <> (value_real IS NULL)),
    PRIMARY KEY (content_snapshot_id, parameter_id)
) STRICT;
CREATE TRIGGER frozen_rule_parameters_insert_guard BEFORE INSERT ON frozen_rule_parameters
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_rule_parameters_update_guard BEFORE UPDATE ON frozen_rule_parameters
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_rule_parameters_delete_guard BEFORE DELETE ON frozen_rule_parameters
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_sector_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    sector_id TEXT NOT NULL,
    system_id TEXT NOT NULL,
    risk_zone_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, system_id) REFERENCES frozen_system_defs (content_snapshot_id, system_id),
    FOREIGN KEY (content_snapshot_id, risk_zone_id) REFERENCES frozen_risk_zone_defs (content_snapshot_id, risk_zone_id)
) STRICT;
CREATE TRIGGER frozen_sector_defs_insert_guard BEFORE INSERT ON frozen_sector_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_sector_defs_update_guard BEFORE UPDATE ON frozen_sector_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_sector_defs_delete_guard BEFORE DELETE ON frozen_sector_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_sector_runtime_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    sector_id TEXT NOT NULL,
    scene_asset_id TEXT NOT NULL,
    enabled INTEGER NOT NULL CHECK (enabled IN (0, 1)),
    stage_code TEXT NOT NULL CHECK (stage_code IN ('A', 'B', 'C', 'D')),
    bounds_radius_m REAL NOT NULL CHECK (bounds_radius_m > 0),
    PRIMARY KEY (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    UNIQUE (content_snapshot_id, scene_asset_id)
) STRICT;
CREATE TRIGGER frozen_sector_runtime_defs_insert_guard BEFORE INSERT ON frozen_sector_runtime_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_sector_runtime_defs_update_guard BEFORE UPDATE ON frozen_sector_runtime_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_sector_runtime_defs_delete_guard BEFORE DELETE ON frozen_sector_runtime_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_service_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    service_id TEXT NOT NULL CHECK (service_id IN ('warehouse', 'repair', 'recharge', 'trade', 'ship_purchase', 'fitting', 'manufacture', 'recycle', 'mission_board', 'loan')),
    display_name TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, service_id)
) STRICT;
CREATE TRIGGER frozen_service_defs_insert_guard BEFORE INSERT ON frozen_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_service_defs_update_guard BEFORE UPDATE ON frozen_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_service_defs_delete_guard BEFORE DELETE ON frozen_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_ship_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
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
    CHECK (base_ask_credit > base_bid_credit),
    PRIMARY KEY (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_ship_defs_insert_guard BEFORE INSERT ON frozen_ship_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_defs_update_guard BEFORE UPDATE ON frozen_ship_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_defs_delete_guard BEFORE DELETE ON frozen_ship_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_ship_loadout_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    loadout_id TEXT NOT NULL,
    ship_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    UNIQUE (content_snapshot_id, loadout_id, ship_id),
    PRIMARY KEY (content_snapshot_id, loadout_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_ship_loadout_defs_insert_guard BEFORE INSERT ON frozen_ship_loadout_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_loadout_defs_update_guard BEFORE UPDATE ON frozen_ship_loadout_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_loadout_defs_delete_guard BEFORE DELETE ON frozen_ship_loadout_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_ship_loadout_items (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    loadout_id TEXT NOT NULL,
    ship_id TEXT NOT NULL,
    slot_type TEXT NOT NULL,
    slot_index INTEGER NOT NULL,
    module_id TEXT NOT NULL,
    FOREIGN KEY (content_snapshot_id, loadout_id, ship_id) REFERENCES frozen_ship_loadout_defs (content_snapshot_id, loadout_id, ship_id),
    FOREIGN KEY (content_snapshot_id, ship_id, slot_type, slot_index) REFERENCES frozen_ship_slot_defs (content_snapshot_id, ship_id, slot_type, slot_index),
    FOREIGN KEY (content_snapshot_id, module_id, slot_type) REFERENCES frozen_module_defs (content_snapshot_id, module_id, slot_type),
    PRIMARY KEY (content_snapshot_id, loadout_id, slot_type, slot_index)
) STRICT;
CREATE TRIGGER frozen_ship_loadout_items_insert_guard BEFORE INSERT ON frozen_ship_loadout_items
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_loadout_items_update_guard BEFORE UPDATE ON frozen_ship_loadout_items
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_loadout_items_delete_guard BEFORE DELETE ON frozen_ship_loadout_items
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_ship_resistances (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    layer_id TEXT NOT NULL,
    damage_type TEXT NOT NULL,
    resistance REAL NOT NULL CHECK (resistance BETWEEN 0 AND 1),
    PRIMARY KEY (content_snapshot_id, ship_id, layer_id, damage_type),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, layer_id) REFERENCES frozen_defense_layers (content_snapshot_id, layer_id),
    FOREIGN KEY (content_snapshot_id, damage_type) REFERENCES frozen_damage_types (content_snapshot_id, damage_type)
) STRICT;
CREATE TRIGGER frozen_ship_resistances_insert_guard BEFORE INSERT ON frozen_ship_resistances
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_resistances_update_guard BEFORE UPDATE ON frozen_ship_resistances
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_resistances_delete_guard BEFORE DELETE ON frozen_ship_resistances
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_ship_slot_capacity (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    slot_type TEXT NOT NULL,
    slot_count INTEGER NOT NULL CHECK (slot_count >= 0),
    PRIMARY KEY (content_snapshot_id, ship_id, slot_type),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, slot_type) REFERENCES frozen_slot_types (content_snapshot_id, slot_type)
) STRICT;
CREATE TRIGGER frozen_ship_slot_capacity_insert_guard BEFORE INSERT ON frozen_ship_slot_capacity
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_slot_capacity_update_guard BEFORE UPDATE ON frozen_ship_slot_capacity
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_slot_capacity_delete_guard BEFORE DELETE ON frozen_ship_slot_capacity
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_ship_slot_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    slot_type TEXT NOT NULL,
    slot_index INTEGER NOT NULL CHECK (slot_index >= 0),
    FOREIGN KEY (content_snapshot_id, ship_id, slot_type) REFERENCES frozen_ship_slot_capacity (content_snapshot_id, ship_id, slot_type),
    PRIMARY KEY (content_snapshot_id, ship_id, slot_type, slot_index)
) STRICT;
CREATE TRIGGER frozen_ship_slot_defs_insert_guard BEFORE INSERT ON frozen_ship_slot_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_slot_defs_update_guard BEFORE UPDATE ON frozen_ship_slot_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_slot_defs_delete_guard BEFORE DELETE ON frozen_ship_slot_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_signal_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    signal_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    anchor_id TEXT NOT NULL,
    difficulty_multiplier REAL NOT NULL CHECK (difficulty_multiplier >= 1),
    threshold_progress REAL NOT NULL CHECK (threshold_progress > 0),
    required_unlock_id TEXT NOT NULL,
    occurrence_mode TEXT NOT NULL CHECK (occurrence_mode IN ('fixed', 'mission_scoped')),
    line_of_sight_required INTEGER NOT NULL CHECK (line_of_sight_required IN (0, 1)),
    PRIMARY KEY (content_snapshot_id, signal_id),
    FOREIGN KEY (content_snapshot_id, anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    UNIQUE (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_signal_defs_insert_guard BEFORE INSERT ON frozen_signal_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_signal_defs_update_guard BEFORE UPDATE ON frozen_signal_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_signal_defs_delete_guard BEFORE DELETE ON frozen_signal_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_slot_types (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    slot_type TEXT NOT NULL CHECK (slot_type IN ('weapon', 'work', 'utility', 'structure')),
    PRIMARY KEY (content_snapshot_id, slot_type)
) STRICT;
CREATE TRIGGER frozen_slot_types_insert_guard BEFORE INSERT ON frozen_slot_types
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_slot_types_update_guard BEFORE UPDATE ON frozen_slot_types
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_slot_types_delete_guard BEFORE DELETE ON frozen_slot_types
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_starting_inventory (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profile_template_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    PRIMARY KEY (content_snapshot_id, profile_template_id, item_id),
    FOREIGN KEY (content_snapshot_id, profile_template_id) REFERENCES frozen_starting_profile_defs (content_snapshot_id, profile_template_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_starting_inventory_insert_guard BEFORE INSERT ON frozen_starting_inventory
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_starting_inventory_update_guard BEFORE UPDATE ON frozen_starting_inventory
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_starting_inventory_delete_guard BEFORE DELETE ON frozen_starting_inventory
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_starting_inventory_policy_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profile_template_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    policy_id TEXT NOT NULL,
    FOREIGN KEY (content_snapshot_id, profile_template_id, item_id) REFERENCES frozen_starting_inventory (content_snapshot_id, profile_template_id, item_id),
    PRIMARY KEY (content_snapshot_id, profile_template_id, item_id),
    FOREIGN KEY (content_snapshot_id, policy_id) REFERENCES frozen_asset_policy_defs (content_snapshot_id, policy_id)
) STRICT;
CREATE TRIGGER frozen_starting_inventory_policy_defs_insert_guard BEFORE INSERT ON frozen_starting_inventory_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_starting_inventory_policy_defs_update_guard BEFORE UPDATE ON frozen_starting_inventory_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_starting_inventory_policy_defs_delete_guard BEFORE DELETE ON frozen_starting_inventory_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_starting_profile_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profile_template_id TEXT NOT NULL,
    currency_id TEXT NOT NULL,
    starting_credit INTEGER NOT NULL CHECK (starting_credit >= 0),
    PRIMARY KEY (content_snapshot_id, profile_template_id),
    FOREIGN KEY (content_snapshot_id, currency_id) REFERENCES frozen_currency_defs (content_snapshot_id, currency_id)
) STRICT;
CREATE TRIGGER frozen_starting_profile_defs_insert_guard BEFORE INSERT ON frozen_starting_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_starting_profile_defs_update_guard BEFORE UPDATE ON frozen_starting_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_starting_profile_defs_delete_guard BEFORE DELETE ON frozen_starting_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_starting_ships (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profile_template_id TEXT NOT NULL,
    loadout_id TEXT NOT NULL,
    grant_kind TEXT NOT NULL CHECK (grant_kind IN ('owned', 'loan', 'unlock')),
    policy_id TEXT NOT NULL,
    available_at_step_id TEXT,
    PRIMARY KEY (content_snapshot_id, profile_template_id, loadout_id),
    FOREIGN KEY (content_snapshot_id, profile_template_id) REFERENCES frozen_starting_profile_defs (content_snapshot_id, profile_template_id),
    FOREIGN KEY (content_snapshot_id, loadout_id) REFERENCES frozen_ship_loadout_defs (content_snapshot_id, loadout_id),
    FOREIGN KEY (content_snapshot_id, policy_id) REFERENCES frozen_asset_policy_defs (content_snapshot_id, policy_id),
    FOREIGN KEY (content_snapshot_id, available_at_step_id) REFERENCES frozen_tutorial_step_defs (content_snapshot_id, step_id)
) STRICT;
CREATE TRIGGER frozen_starting_ships_insert_guard BEFORE INSERT ON frozen_starting_ships
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_starting_ships_update_guard BEFORE UPDATE ON frozen_starting_ships
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_starting_ships_delete_guard BEFORE DELETE ON frozen_starting_ships
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_stat_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    stat_id TEXT NOT NULL,
    unit TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, stat_id)
) STRICT;
CREATE TRIGGER frozen_stat_defs_insert_guard BEFORE INSERT ON frozen_stat_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_stat_defs_update_guard BEFORE UPDATE ON frozen_stat_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_stat_defs_delete_guard BEFORE DELETE ON frozen_stat_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_station_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    station_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    faction_id TEXT NOT NULL,
    station_anchor_id TEXT NOT NULL,
    undock_anchor_id TEXT NOT NULL,
    stock_refresh_s REAL NOT NULL CHECK (stock_refresh_s > 0),
    buyback_budget_credit INTEGER NOT NULL CHECK (buyback_budget_credit >= 0),
    FOREIGN KEY (content_snapshot_id, station_anchor_id, sector_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id, sector_id),
    FOREIGN KEY (content_snapshot_id, undock_anchor_id, sector_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id, sector_id),
    PRIMARY KEY (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_runtime_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_faction_defs (content_snapshot_id, faction_id),
    UNIQUE (content_snapshot_id, station_anchor_id),
    UNIQUE (content_snapshot_id, undock_anchor_id)
) STRICT;
CREATE TRIGGER frozen_station_defs_insert_guard BEFORE INSERT ON frozen_station_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_station_defs_update_guard BEFORE UPDATE ON frozen_station_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_station_defs_delete_guard BEFORE DELETE ON frozen_station_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_station_service_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    station_id TEXT NOT NULL,
    service_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, station_id, service_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, service_id) REFERENCES frozen_service_defs (content_snapshot_id, service_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_station_service_defs_insert_guard BEFORE INSERT ON frozen_station_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_station_service_defs_update_guard BEFORE UPDATE ON frozen_station_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_station_service_defs_delete_guard BEFORE DELETE ON frozen_station_service_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_station_ship_stock_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    station_id TEXT NOT NULL,
    ship_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    initial_units INTEGER NOT NULL CHECK (initial_units >= 0),
    target_units INTEGER NOT NULL CHECK (target_units >= 0),
    hard_cap_units INTEGER NOT NULL CHECK (hard_cap_units >= target_units AND hard_cap_units >= initial_units),
    restock_units_per_refresh INTEGER NOT NULL CHECK (restock_units_per_refresh >= 0),
    PRIMARY KEY (content_snapshot_id, station_id, ship_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_station_ship_stock_defs_insert_guard BEFORE INSERT ON frozen_station_ship_stock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_station_ship_stock_defs_update_guard BEFORE UPDATE ON frozen_station_ship_stock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_station_ship_stock_defs_delete_guard BEFORE DELETE ON frozen_station_ship_stock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_station_stock_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    station_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    initial_units INTEGER NOT NULL CHECK (initial_units >= 0),
    target_units INTEGER NOT NULL CHECK (target_units >= 0),
    hard_cap_units INTEGER NOT NULL CHECK (hard_cap_units >= target_units AND hard_cap_units >= initial_units),
    restock_units_per_refresh INTEGER NOT NULL CHECK (restock_units_per_refresh >= 0),
    buyback_units_per_refresh INTEGER NOT NULL CHECK (buyback_units_per_refresh >= 0),
    allow_buy INTEGER NOT NULL CHECK (allow_buy IN (0, 1)),
    allow_sell INTEGER NOT NULL CHECK (allow_sell IN (0, 1)),
    PRIMARY KEY (content_snapshot_id, station_id, item_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_station_stock_defs_insert_guard BEFORE INSERT ON frozen_station_stock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_station_stock_defs_update_guard BEFORE UPDATE ON frozen_station_stock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_station_stock_defs_delete_guard BEFORE DELETE ON frozen_station_stock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_system_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    system_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, system_id)
) STRICT;
CREATE TRIGGER frozen_system_defs_insert_guard BEFORE INSERT ON frozen_system_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_system_defs_update_guard BEFORE UPDATE ON frozen_system_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_system_defs_delete_guard BEFORE DELETE ON frozen_system_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_tutorial_step_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    step_id TEXT NOT NULL,
    stage_code TEXT NOT NULL,
    step_order INTEGER NOT NULL CHECK (step_order >= 0),
    prerequisite_step_id TEXT,
    action_kind TEXT NOT NULL,
    reward_credit INTEGER NOT NULL CHECK (reward_credit >= 0),
    required_item_id TEXT,
    required_quantity INTEGER CHECK (required_quantity IS NULL OR required_quantity > 0),
    target_npc_id TEXT,
    CHECK ((required_item_id IS NULL) = (required_quantity IS NULL)),
    CHECK (prerequisite_step_id IS NULL OR prerequisite_step_id <> step_id),
    PRIMARY KEY (content_snapshot_id, step_id),
    UNIQUE (content_snapshot_id, stage_code),
    UNIQUE (content_snapshot_id, step_order),
    FOREIGN KEY (content_snapshot_id, prerequisite_step_id) REFERENCES frozen_tutorial_step_defs (content_snapshot_id, step_id),
    FOREIGN KEY (content_snapshot_id, required_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id),
    FOREIGN KEY (content_snapshot_id, target_npc_id) REFERENCES frozen_npc_defs (content_snapshot_id, npc_id)
) STRICT;
CREATE TRIGGER frozen_tutorial_step_defs_insert_guard BEFORE INSERT ON frozen_tutorial_step_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_tutorial_step_defs_update_guard BEFORE UPDATE ON frozen_tutorial_step_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_tutorial_step_defs_delete_guard BEFORE DELETE ON frozen_tutorial_step_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_unlock_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    unlock_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    initially_unlocked INTEGER NOT NULL CHECK (initially_unlocked IN (0, 1)),
    PRIMARY KEY (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_unlock_defs_insert_guard BEFORE INSERT ON frozen_unlock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_unlock_defs_update_guard BEFORE UPDATE ON frozen_unlock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_unlock_defs_delete_guard BEFORE DELETE ON frozen_unlock_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_weapon_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    damage_type TEXT NOT NULL,
    raw_damage REAL NOT NULL CHECK (raw_damage > 0),
    projectile_speed_mps REAL CHECK (projectile_speed_mps IS NULL OR projectile_speed_mps > 0),
    ammo_item_id TEXT,
    ammo_per_cycle INTEGER NOT NULL CHECK (ammo_per_cycle >= 0),
    CHECK ((ammo_item_id IS NULL AND ammo_per_cycle = 0) OR (ammo_item_id IS NOT NULL AND ammo_per_cycle > 0)),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, damage_type) REFERENCES frozen_damage_types (content_snapshot_id, damage_type),
    FOREIGN KEY (content_snapshot_id, ammo_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_weapon_defs_insert_guard BEFORE INSERT ON frozen_weapon_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_weapon_defs_update_guard BEFORE UPDATE ON frozen_weapon_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_weapon_defs_delete_guard BEFORE DELETE ON frozen_weapon_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
