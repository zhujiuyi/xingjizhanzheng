#!/usr/bin/env python3
"""Rebuild the reviewed numeric and B content catalog; no Godot gameplay."""
from __future__ import annotations

import argparse
import hashlib
import math
import os
from pathlib import Path
import sqlite3
import struct
import tempfile
from civilization_catalog import COLUMNS as CIVILIZATION_COLUMNS, TABLES as CIVILIZATION_TABLES, validate as validate_civilizations
from industry_catalog import COLUMNS as INDUSTRY_COLUMNS, TABLES as INDUSTRY_TABLES, validate as validate_industry
from resource_intel_catalog import COLUMNS as RESOURCE_INTEL_COLUMNS, TABLES as RESOURCE_INTEL_TABLES, validate as validate_resource_intel

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "code/data/catalog.db"
SCHEMA = ROOT / "code/database/catalog_schema.sql"
SEED = ROOT / "code/database/catalog_seed.sql"
SPACE = ROOT / "code/database/space_v7.sql"
CIVILIZATION_SCHEMA = ROOT / "code/database/civilization_schema.sql"
CIVILIZATION_SEED = ROOT / "code/database/civilization_seed.sql"
INDUSTRY_SCHEMA = ROOT / "code/database/industry_schema.sql"
INDUSTRY_SEED = ROOT / "code/database/industry_seed.sql"
RESOURCE_INTEL_SCHEMA = ROOT / "code/database/resource_intel_schema.sql"
RESOURCE_INTEL_SEED = ROOT / "code/database/resource_intel_seed.sql"
HASH_ALGORITHM = "catalog_hash_v1"
CONTENT_VIEWS = ("effective_connection_defs", "module_full_defs", "npc_full_defs", "mission_summary_defs")
# Explicit table registry; column order and PK order come from the reviewed DDL.
CONTENT_TABLES = (
    "catalog_meta",
    "rule_parameters",
    "currency_defs",
    "damage_types",
    "defense_layers",
    "slot_types",
    "ship_defs",
    "ship_slot_capacity",
    "ship_slot_defs",
    "ship_resistances",
    "item_defs",
    "module_defs",
    "weapon_defs",
    "repair_defs",
    "stat_defs",
    "module_stat_modifiers",
    "module_resistance_modifiers",
    "mining_defs",
    "mining_compatibility",
    "ship_loadout_defs",
    "ship_loadout_items",
    "risk_zone_defs",
    "npc_archetype_defs",
    "npc_level_defs",
    "npc_defs",
    "npc_resistances",
    "module_exclusion_groups",
    "module_group_members",
    "module_activation_priority",
    "resource_node_defs",
    "combat_benchmark_defs",
    "system_defs",
    "sector_defs",
    "gate_class_defs",
    "connection_defs",
    "recipe_defs",
    "recipe_inputs",
    "recycle_outputs",
    "module_salvage_recipe_defs",
    "asset_policy_defs",
    "starting_profile_defs",
    "starting_inventory",
    "tutorial_step_defs",
    "starting_ships",
    "loadout_supply_defs",
    "npc_loot_defs",
    "faction_defs",
    "unlock_defs",
    "sector_runtime_defs",
    "anchor_defs",
    "station_defs",
    "service_defs",
    "station_service_defs",
    "station_stock_defs",
    "station_ship_stock_defs",
    "recipe_access_defs",
    "gate_endpoint_defs",
    "signal_defs",
    "resource_node_locations",
    "npc_behavior_defs",
    "npc_spawn_defs",
    "npc_patrol_points",
    "mission_instance_states",
    "mission_defs",
    "mission_prerequisites",
    "loan_service_defs",
    "mission_objective_defs",
    "mission_reward_defs",
    "mission_unlock_rewards",
    "mission_state_transitions",
    "starting_inventory_policy_defs",
    "camera_profile_defs",
    "presentation_defs",
    "ship_role_defs",
    "module_tech_defs",
    "research_defs",
    "research_inputs",
    "research_prerequisites",
    "hull_recipe_defs",
    "hull_recipe_inputs",
    "base_module_defs",
    "base_module_inputs",
    "mission_reputation_rewards",
    "signal_unlock_rewards",
    "encounter_defs",
    "encounter_members",
    "salvage_package_defs",
    "salvage_reward_defs",
    "npc_salvage_defs",
    "weapon_behavior_defs",
    "ship_weapon_permissions",
    "drone_defs",
    "system_lighting_defs",
    "site_defs",
    "anchor_site_defs",
    "celestial_defs",
)


# Reviewed column/type/primary-key registry. Schema drift requires explicit registration.
CONTENT_COLUMNS = {
    'site_defs': 'site_id:TEXT:1|sector_id:TEXT:0|display_name:TEXT:0|site_kind:TEXT:0|x_m:REAL:0|y_m:REAL:0|z_m:REAL:0|pivot_x_m:REAL:0|pivot_y_m:REAL:0|pivot_z_m:REAL:0|local_radius_m:REAL:0',
    'anchor_site_defs': 'anchor_id:TEXT:1|site_id:TEXT:0',
    'celestial_defs': 'celestial_id:TEXT:1|sector_id:TEXT:0|display_name:TEXT:0|celestial_kind:TEXT:0|x_m:REAL:0|y_m:REAL:0|z_m:REAL:0|radius_m:REAL:0',
    'weapon_behavior_defs': 'module_id:TEXT:1|family_id:TEXT:0|size_class:INTEGER:0|fire_mode:TEXT:0|fire_cone_half_angle_rad:REAL:0',
    'ship_weapon_permissions': 'ship_id:TEXT:1|family_id:TEXT:2|max_size:INTEGER:0|max_installed:INTEGER:0',
    'drone_defs': 'module_id:TEXT:1|drone_count:INTEGER:0|speed_mps:REAL:0|acceleration_mps2:REAL:0|turn_rad_s:REAL:0|attack_range_m:REAL:0|projectile_speed_mps:REAL:0|sortie_timeout_s:REAL:0|return_radius_m:REAL:0',
    'system_lighting_defs': 'system_id:TEXT:1|star_x_m:REAL:0|star_y_m:REAL:0|star_z_m:REAL:0|light_r:REAL:0|light_g:REAL:0|light_b:REAL:0|energy:REAL:0|ambient_energy:REAL:0|shadow_distance_m:REAL:0',
    'encounter_defs': 'encounter_id:TEXT:1|sector_id:TEXT:0|display_name:TEXT:0|anchor_id:TEXT:0|reveal_range_m:REAL:0|respawn_seconds:REAL:0|warp_arrival_m:REAL:0|required_unlock_id:TEXT:0',
    'encounter_members': 'encounter_id:TEXT:1|spawn_id:TEXT:2|member_index:INTEGER:0',
    'salvage_package_defs': 'package_def_id:TEXT:1|display_name:TEXT:0|volume_m3:REAL:0|mass_kg:REAL:0',
    'salvage_reward_defs': 'reward_id:TEXT:1|package_def_id:TEXT:0|weight:INTEGER:0|credit_units:INTEGER:0|item_def_id:TEXT:0|quantity:INTEGER:0',
    'npc_salvage_defs': 'npc_def_id:TEXT:1|package_def_id:TEXT:0',
    'signal_unlock_rewards': 'signal_id:TEXT:1|unlock_id:TEXT:2',
    'ship_role_defs': 'ship_id:TEXT:1|class_id:TEXT:0|faction_id:TEXT:0|required_unlock_id:TEXT:0',
    'module_tech_defs': 'module_id:TEXT:1|faction_id:TEXT:0|tech_level:INTEGER:0|required_unlock_id:TEXT:0',
    'research_defs': 'research_id:TEXT:1|display_name:TEXT:0|station_faction_id:TEXT:0|required_reputation:INTEGER:0|required_credit:INTEGER:0|reward_unlock_id:TEXT:0|verification_mission_id:TEXT:0',
    'research_inputs': 'research_id:TEXT:1|item_id:TEXT:2|quantity:INTEGER:0',
    'research_prerequisites': 'research_id:TEXT:1|unlock_id:TEXT:2',
    'hull_recipe_defs': 'hull_recipe_id:TEXT:1|display_name:TEXT:0|ship_id:TEXT:0|required_unlock_id:TEXT:0|service_fee_credit:INTEGER:0',
    'hull_recipe_inputs': 'hull_recipe_id:TEXT:1|item_id:TEXT:2|quantity:INTEGER:0',
    'base_module_defs': 'base_module_id:TEXT:1|display_name:TEXT:0|required_unlock_id:TEXT:0|service_fee_credit:INTEGER:0|service_kind:TEXT:0|effect_multiplier:REAL:0',
    'base_module_inputs': 'base_module_id:TEXT:1|item_id:TEXT:2|quantity:INTEGER:0',
    'mission_reputation_rewards': 'mission_id:TEXT:1|faction_id:TEXT:2|reputation_delta:INTEGER:0',

    'faction_defs': 'faction_id:TEXT:1|display_name:TEXT:0',
    'unlock_defs': 'unlock_id:TEXT:1|display_name:TEXT:0|initially_unlocked:INTEGER:0',
    'sector_runtime_defs': 'sector_id:TEXT:1|scene_asset_id:TEXT:0|enabled:INTEGER:0|stage_code:TEXT:0|bounds_radius_m:REAL:0',
    'anchor_defs': 'anchor_id:TEXT:1|sector_id:TEXT:0|anchor_kind:TEXT:0|x_m:REAL:0|y_m:REAL:0|z_m:REAL:0|yaw_rad:REAL:0|interaction_radius_m:REAL:0|safe_radius_m:REAL:0',
    'station_defs': 'station_id:TEXT:1|display_name:TEXT:0|sector_id:TEXT:0|faction_id:TEXT:0|station_anchor_id:TEXT:0|undock_anchor_id:TEXT:0|stock_refresh_s:REAL:0|buyback_budget_credit:INTEGER:0',
    'service_defs': 'service_id:TEXT:1|display_name:TEXT:0',
    'station_service_defs': 'station_id:TEXT:1|service_id:TEXT:2|required_unlock_id:TEXT:0',
    'station_stock_defs': 'station_id:TEXT:1|item_id:TEXT:2|required_unlock_id:TEXT:0|initial_units:INTEGER:0|target_units:INTEGER:0|hard_cap_units:INTEGER:0|restock_units_per_refresh:INTEGER:0|buyback_units_per_refresh:INTEGER:0|allow_buy:INTEGER:0|allow_sell:INTEGER:0',
    'station_ship_stock_defs': 'station_id:TEXT:1|ship_id:TEXT:2|required_unlock_id:TEXT:0|initial_units:INTEGER:0|target_units:INTEGER:0|hard_cap_units:INTEGER:0|restock_units_per_refresh:INTEGER:0',
    'recipe_access_defs': 'recipe_id:TEXT:1|station_id:TEXT:2|required_unlock_id:TEXT:0',
    'gate_endpoint_defs': 'endpoint_id:TEXT:1|connection_id:TEXT:0|origin_sector_id:TEXT:0|target_sector_id:TEXT:0|entry_anchor_id:TEXT:0|exit_anchor_id:TEXT:0|required_unlock_id:TEXT:0',
    'signal_defs': 'signal_id:TEXT:1|display_name:TEXT:0|anchor_id:TEXT:0|difficulty_multiplier:REAL:0|threshold_progress:REAL:0|required_unlock_id:TEXT:0|occurrence_mode:TEXT:0|line_of_sight_required:INTEGER:0',
    'resource_node_locations': 'node_id:TEXT:1|sector_id:TEXT:0|anchor_id:TEXT:0|required_unlock_id:TEXT:0',
    'npc_behavior_defs': 'behavior_id:TEXT:1|archetype_id:TEXT:0|detection_range_m:REAL:0|target_drop_range_m:REAL:0|leash_radius_m:REAL:0|preferred_range_ratio:REAL:0|los_loss_timeout_s:REAL:0|reaction_s:REAL:0|return_radius_m:REAL:0|patrol_wait_s:REAL:0|acceleration_mps2:REAL:0|turn_rad_s:REAL:0|attack_cycle_s:REAL:0|fire_cone_half_angle_rad:REAL:0|fire_mode:TEXT:0|projectile_speed_mps:REAL:0',
    'npc_spawn_defs': 'spawn_id:TEXT:1|npc_id:TEXT:0|sector_id:TEXT:0|anchor_id:TEXT:0|behavior_id:TEXT:0|occurrence_mode:TEXT:0|required_unlock_id:TEXT:0|respawn_s:REAL:0|bounty_enabled:INTEGER:0|loot_enabled:INTEGER:0',
    'npc_patrol_points': 'spawn_id:TEXT:1|point_index:INTEGER:2|anchor_id:TEXT:0',
    'mission_instance_states': 'state_id:TEXT:1|is_terminal:INTEGER:0',
    'mission_defs': 'mission_id:TEXT:1|display_name:TEXT:0|mission_kind:TEXT:0|tutorial_step_id:TEXT:0|accept_station_id:TEXT:0|turnin_station_id:TEXT:0|required_unlock_id:TEXT:0|repeatable:INTEGER:0|repeat_cooldown_s:REAL:0|repeat_window_s:REAL:0|max_completions_per_window:INTEGER:0|max_active_instances:INTEGER:0|deadline_s:REAL:0|reset_objectives_on_retry:INTEGER:0',
    'mission_prerequisites': 'mission_id:TEXT:1|prerequisite_mission_id:TEXT:2',
    'loan_service_defs': 'loan_service_id:TEXT:1|station_id:TEXT:0|return_station_id:TEXT:0|loadout_id:TEXT:0|policy_id:TEXT:0|required_unlock_id:TEXT:0|required_mission_id:TEXT:0|fee_credit:INTEGER:0|max_active_instances:INTEGER:0|replace_destroyed:INTEGER:0|replacement_cooldown_s:REAL:0|operation_quota_units:INTEGER:0|gathered_policy_id:TEXT:0|requires_safe_switch:INTEGER:0|remove_bound_on_return:INTEGER:0',
    'mission_objective_defs': 'mission_id:TEXT:1|objective_index:INTEGER:2|objective_kind:TEXT:0|required_count:INTEGER:0|target_anchor_id:TEXT:0|target_station_id:TEXT:0|target_signal_id:TEXT:0|target_node_id:TEXT:0|target_spawn_id:TEXT:0|target_connection_id:TEXT:0|target_item_id:TEXT:0|target_loan_service_id:TEXT:0|max_speed_mps:REAL:0|hold_s:REAL:0|consume_item:INTEGER:0',
    'mission_reward_defs': 'mission_id:TEXT:1|currency_id:TEXT:0|reward_credit:INTEGER:0',
    'mission_unlock_rewards': 'mission_id:TEXT:1|unlock_id:TEXT:2',
    'mission_state_transitions': 'from_state:TEXT:1|event_code:TEXT:2|to_state:TEXT:0|guard_code:TEXT:0',
    'starting_inventory_policy_defs': 'profile_template_id:TEXT:1|item_id:TEXT:2|policy_id:TEXT:0',
    'camera_profile_defs': 'profile_id:TEXT:1|ship_id:TEXT:0|mode:TEXT:0|fov_deg:REAL:0|distance_m:REAL:0|height_m:REAL:0|look_ahead_m:REAL:0|near_m:REAL:0|far_m:REAL:0|zoom_min_m:REAL:0|zoom_max_m:REAL:0|position_smooth_s:REAL:0|rotation_smooth_s:REAL:0|collision_margin_m:REAL:0',
    'presentation_defs': 'presentation_id:TEXT:1|value_integer:INTEGER:0|value_real:REAL:0|unit:TEXT:0',
    'module_salvage_recipe_defs': 'module_id:TEXT:1|recipe_id:TEXT:0',
    'asset_policy_defs': 'policy_id:TEXT:1|may_sell:INTEGER:0|may_recycle:INTEGER:0|inherit_to_attached:INTEGER:0|inherit_to_supplies:INTEGER:0',
    'catalog_meta': 'singleton:INTEGER:1|pack_id:TEXT:0|content_version:TEXT:0|ruleset_version:TEXT:0|schema_version:INTEGER:0|source_document:TEXT:0|hash_algorithm:TEXT:0',
    'combat_benchmark_defs': 'benchmark_id:TEXT:1|loadout_id:TEXT:0|npc_id:TEXT:0|player_can_win:INTEGER:0',
    'connection_defs': 'connection_id:TEXT:1|origin_sector_id:TEXT:0|target_sector_id:TEXT:0|bidirectional:INTEGER:0|gate_class_id:TEXT:0|energy_cost_override_eu:REAL:0|fee_override_credit:INTEGER:0',
    'currency_defs': 'currency_id:TEXT:1|display_name:TEXT:0|unit:TEXT:0',
    'damage_types': 'damage_type:TEXT:1',
    'defense_layers': 'layer_id:TEXT:1|layer_order:INTEGER:0',
    'gate_class_defs': 'gate_class_id:TEXT:1|max_gross_mass_kg:REAL:0|prepare_s:REAL:0|cooldown_s:REAL:0|energy_cost_eu:REAL:0|fee_credit:INTEGER:0|total_mass_budget_kg:REAL:0|lifetime_s:REAL:0',
    'item_defs': 'item_id:TEXT:1|display_name:TEXT:0|item_type:TEXT:0|unit_mass_kg:REAL:0|unit_volume_l:INTEGER:0|stackable:INTEGER:0|base_ask_credit:INTEGER:0|base_bid_credit:INTEGER:0',
    'loadout_supply_defs': 'loadout_id:TEXT:1|item_id:TEXT:2|quantity:INTEGER:0',
    'mining_compatibility': 'module_id:TEXT:1|item_id:TEXT:2',
    'mining_defs': 'module_id:TEXT:1|base_yield_units:INTEGER:0',
    'module_activation_priority': 'module_id:TEXT:1|priority:INTEGER:0',
    'module_defs': 'module_id:TEXT:1|slot_type:TEXT:0|power_pu:REAL:0|cpu_cu:REAL:0|cycle_s:REAL:0|range_m:REAL:0|energy_eu:REAL:0|heat_hu:REAL:0|max_per_ship:INTEGER:0',
    'module_exclusion_groups': 'group_id:TEXT:1|max_installed:INTEGER:0',
    'module_group_members': 'module_id:TEXT:1|group_id:TEXT:2',
    'module_resistance_modifiers': 'module_id:TEXT:1|layer_id:TEXT:2|damage_type:TEXT:3|delta:REAL:0',
    'module_stat_modifiers': 'module_id:TEXT:1|stat_id:TEXT:2|operation:TEXT:0|amount:REAL:0',
    'npc_archetype_defs': 'archetype_id:TEXT:1|display_name:TEXT:0|base_shield:INTEGER:0|base_armor:INTEGER:0|base_hull:INTEGER:0|base_raw_dps:REAL:0|damage_type:TEXT:0|speed_mps:REAL:0|range_m:REAL:0|base_reward_credit:INTEGER:0',
    'npc_defs': 'npc_id:TEXT:1|archetype_id:TEXT:0|level:INTEGER:0|risk_zone_id:TEXT:0',
    'npc_level_defs': 'level:INTEGER:1|hp_basis_points:INTEGER:0|dps_basis_points:INTEGER:0|reward_basis_points:INTEGER:0',
    'npc_loot_defs': 'archetype_id:TEXT:1|item_id:TEXT:2|quantity:INTEGER:0',
    'npc_resistances': 'archetype_id:TEXT:1|layer_id:TEXT:2|damage_type:TEXT:3|resistance:REAL:0',
    'recipe_defs': 'recipe_id:TEXT:1|output_item_id:TEXT:0|output_quantity:INTEGER:0|service_fee_credit:INTEGER:0|duration_s:REAL:0',
    'recipe_inputs': 'recipe_id:TEXT:1|item_id:TEXT:2|quantity:INTEGER:0',
    'recycle_outputs': 'source_item_id:TEXT:1|output_item_id:TEXT:2|quantity:INTEGER:0',
    'repair_defs': 'module_id:TEXT:1|layer_id:TEXT:0|restore_amount:REAL:0|consumable_item_id:TEXT:0|consumable_per_cycle:INTEGER:0',
    'resource_node_defs': 'node_id:TEXT:1|sector_id:TEXT:0|item_id:TEXT:0|capacity_units:INTEGER:0|respawn_s:REAL:0',
    'risk_zone_defs': 'risk_zone_id:TEXT:1|display_name:TEXT:0|npc_level_min:INTEGER:0|npc_level_max:INTEGER:0',
    'rule_parameters': 'parameter_id:TEXT:1|value_integer:INTEGER:0|value_real:REAL:0|unit:TEXT:0',
    'sector_defs': 'sector_id:TEXT:1|system_id:TEXT:0|risk_zone_id:TEXT:0',
    'ship_defs': 'ship_id:TEXT:1|display_name:TEXT:0|dry_mass_kg:REAL:0|max_installed_mass_kg:REAL:0|max_payload_mass_kg:REAL:0|max_speed_mps:REAL:0|acceleration_mps2:REAL:0|turn_rad_s:REAL:0|shield_max:REAL:0|armor_max:REAL:0|hull_max:REAL:0|energy_max:REAL:0|recharge_eu_s:REAL:0|heat_max:REAL:0|cooling_hu_s:REAL:0|shield_recharge_hp_s:REAL:0|cargo_l:INTEGER:0|mineral_cargo_l:INTEGER:0|power_capacity:REAL:0|cpu_capacity:REAL:0|scan_strength:REAL:0|mining_multiplier:REAL:0|base_ask_credit:INTEGER:0|base_bid_credit:INTEGER:0',
    'ship_loadout_defs': 'loadout_id:TEXT:1|ship_id:TEXT:0|display_name:TEXT:0',
    'ship_loadout_items': 'loadout_id:TEXT:1|ship_id:TEXT:0|slot_type:TEXT:2|slot_index:INTEGER:3|module_id:TEXT:0',
    'ship_resistances': 'ship_id:TEXT:1|layer_id:TEXT:2|damage_type:TEXT:3|resistance:REAL:0',
    'ship_slot_capacity': 'ship_id:TEXT:1|slot_type:TEXT:2|slot_count:INTEGER:0',
    'ship_slot_defs': 'ship_id:TEXT:1|slot_type:TEXT:2|slot_index:INTEGER:3',
    'slot_types': 'slot_type:TEXT:1',
    'starting_inventory': 'profile_template_id:TEXT:1|item_id:TEXT:2|quantity:INTEGER:0',
    'starting_profile_defs': 'profile_template_id:TEXT:1|currency_id:TEXT:0|starting_credit:INTEGER:0',
    'starting_ships': 'profile_template_id:TEXT:1|loadout_id:TEXT:2|grant_kind:TEXT:0|policy_id:TEXT:0|available_at_step_id:TEXT:0',
    'stat_defs': 'stat_id:TEXT:1|unit:TEXT:0',
    'system_defs': 'system_id:TEXT:1|display_name:TEXT:0',
    'tutorial_step_defs': 'step_id:TEXT:1|stage_code:TEXT:0|step_order:INTEGER:0|prerequisite_step_id:TEXT:0|action_kind:TEXT:0|reward_credit:INTEGER:0|required_item_id:TEXT:0|required_quantity:INTEGER:0|target_npc_id:TEXT:0',
    'weapon_defs': 'module_id:TEXT:1|damage_type:TEXT:0|raw_damage:REAL:0|projectile_speed_mps:REAL:0|ammo_item_id:TEXT:0|ammo_per_cycle:INTEGER:0',
}


CONTENT_TABLES += CIVILIZATION_TABLES
CONTENT_COLUMNS.update(CIVILIZATION_COLUMNS)
CONTENT_TABLES += INDUSTRY_TABLES
CONTENT_COLUMNS.update(INDUSTRY_COLUMNS)
CONTENT_TABLES += RESOURCE_INTEL_TABLES
CONTENT_COLUMNS.update(RESOURCE_INTEL_COLUMNS)


def identifier(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def encode_field(value: object, sql_type: str = "TEXT") -> bytes:
    if value is None:
        tag, payload = b"N", b""
    elif sql_type == "INTEGER":
        if not isinstance(value, int):
            raise ValueError(f"Expected INTEGER, got {type(value).__name__}")
        tag, payload = b"I", str(value).encode("ascii")
    elif sql_type == "REAL":
        number = float(value)
        if not math.isfinite(number):
            raise ValueError("Non-finite REAL cannot enter catalog_hash_v1")
        tag, payload = b"F", struct.pack(">d", number).hex().encode("ascii")
    elif sql_type == "TEXT":
        if not isinstance(value, str):
            raise ValueError(f"Expected TEXT, got {type(value).__name__}")
        tag, payload = b"T", value.encode("utf-8")
    else:
        raise ValueError(f"Unsupported catalog type {sql_type}")
    return tag + len(payload).to_bytes(8, "big") + payload


def content_registry(connection: sqlite3.Connection) -> dict[str, list[tuple[str, str, int]]]:
    actual = {
        row[0] for row in connection.execute(
            "SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        )
    }
    if actual != set(CONTENT_TABLES):
        raise ValueError(f"Unregistered/missing tables: {actual ^ set(CONTENT_TABLES)}")
    registry = {}
    for table in sorted(CONTENT_TABLES):
        info = connection.execute(f"PRAGMA table_info({identifier(table)})").fetchall()
        columns = [(row[1], row[2], row[5]) for row in info]
        if table == "catalog_meta":
            columns = [column for column in columns if column[0] != "content_hash"]
        signature = "|".join(f"{name}:{sql_type}:{pk}" for name, sql_type, pk in columns)
        if signature != CONTENT_COLUMNS.get(table):
            raise ValueError(f"Unregistered column/type/primary-key change in {table}")
        if not columns or not any(column[2] for column in columns):
            raise ValueError(f"Missing columns or primary key in {table}")
        registry[table] = columns
    return registry


def logical_content_hash(connection: sqlite3.Connection) -> str:
    digest = hashlib.sha256()
    digest.update(encode_field(HASH_ALGORITHM))
    for table, columns in content_registry(connection).items():
        digest.update(b"B" + encode_field(table))
        digest.update(encode_field(len(columns), "INTEGER"))
        for name, sql_type, pk_order in columns:
            digest.update(b"C" + encode_field(name) + encode_field(sql_type))
            digest.update(encode_field(pk_order, "INTEGER"))
        names = ", ".join(identifier(column[0]) for column in columns)
        keys = sorted((column for column in columns if column[2]), key=lambda column: column[2])
        ordering = ", ".join(identifier(column[0]) + " COLLATE BINARY" for column in keys)
        rows = connection.execute(f"SELECT {names} FROM {identifier(table)} ORDER BY {ordering}").fetchall()
        digest.update(encode_field(len(rows), "INTEGER"))
        for row in rows:
            digest.update(b"R")
            for value, (_, sql_type, _) in zip(row, columns, strict=True):
                digest.update(encode_field(value, sql_type))
    # Fixed reviewed SQL views derive gameplay values; their exact UTF-8 DDL is content.
    for name, definition in content_views(connection).items():
        digest.update(b"V" + encode_field(name) + encode_field(definition))
    return digest.hexdigest()


def content_views(connection: sqlite3.Connection) -> dict[str, str]:
    views = dict(connection.execute("SELECT name, sql FROM sqlite_schema WHERE type='view' ORDER BY name COLLATE BINARY"))
    if set(views) != set(CONTENT_VIEWS):
        raise ValueError(f"Unregistered/missing views: {set(views) ^ set(CONTENT_VIEWS)}")
    if any(not definition for definition in views.values()):
        raise ValueError("Missing SQL view definition")
    return views


def validate_database(connection: sqlite3.Connection) -> None:
    if connection.execute("PRAGMA foreign_keys").fetchone()[0] != 1:
        raise ValueError("Foreign keys are not enabled")
    violations = connection.execute("PRAGMA foreign_key_check").fetchall()
    if violations:
        raise ValueError(f"Foreign-key violations: {violations}")
    if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
        raise ValueError("SQLite integrity_check failed")
    content_views(connection)
    for table, columns in content_registry(connection).items():
        names = ", ".join(identifier(column[0]) for column in columns)
        for row in connection.execute(f"SELECT {names} FROM {identifier(table)}"):
            for value, (_, sql_type, _) in zip(row, columns, strict=True):
                encode_field(value, sql_type)
    validate_content_graph(connection)


def validate_content_graph(connection: sqlite3.Connection) -> None:
    """Reject semantic cross-table errors SQL FKs alone cannot express."""
    def rows(table: str) -> list[dict[str, object]]:
        cursor = connection.execute(f"SELECT * FROM {identifier(table)}")
        names = [column[0] for column in cursor.description]
        return [dict(zip(names, row, strict=True)) for row in cursor]

    def indexed(table: str, key: str) -> dict[str, dict[str, object]]:
        return {row[key]: row for row in rows(table)}

    def require(condition: bool, message: str) -> None:
        if not condition:
            raise ValueError(message)

    anchors = indexed("anchor_defs", "anchor_id")
    sectors = indexed("sector_runtime_defs", "sector_id")
    stations = indexed("station_defs", "station_id")
    connections = indexed("connection_defs", "connection_id")
    nodes = indexed("resource_node_defs", "node_id")
    locations = indexed("resource_node_locations", "node_id")
    signals = indexed("signal_defs", "signal_id")
    npcs = indexed("npc_defs", "npc_id")
    behaviors = indexed("npc_behavior_defs", "behavior_id")
    spawns = indexed("npc_spawn_defs", "spawn_id")
    missions = indexed("mission_defs", "mission_id")
    loans = indexed("loan_service_defs", "loan_service_id")
    sector_risks = indexed("sector_defs", "sector_id")
    rewards = indexed("mission_reward_defs", "mission_id")
    steps = indexed("tutorial_step_defs", "step_id")
    policies = indexed("asset_policy_defs", "policy_id")
    for anchor in anchors.values():
        radius = sectors[anchor["sector_id"]]["bounds_radius_m"]
        require(sum(anchor[key] ** 2 for key in ("x_m", "y_m", "z_m")) < radius ** 2,
                f"Anchor outside playable sector: {anchor['anchor_id']}")
    for station in stations.values():
        require(anchors[station["station_anchor_id"]]["anchor_kind"] == "station" and
                anchors[station["undock_anchor_id"]]["anchor_kind"] == "undock",
                f"Invalid station anchor kind: {station['station_id']}")
    endpoints = rows("gate_endpoint_defs")
    for connection_def in connections.values():
        matching = [row for row in endpoints if row["connection_id"] == connection_def["connection_id"]]
        expected = {(connection_def["origin_sector_id"], connection_def["target_sector_id"])}
        if connection_def["bidirectional"]:
            expected.add((connection_def["target_sector_id"], connection_def["origin_sector_id"]))
        require({(row["origin_sector_id"], row["target_sector_id"]) for row in matching} == expected,
                f"Missing/wrong gate endpoints: {connection_def['connection_id']}")
    for endpoint in endpoints:
        require(anchors[endpoint["entry_anchor_id"]]["anchor_kind"] == "gate_entry" and
                anchors[endpoint["exit_anchor_id"]]["anchor_kind"] == "gate_exit",
                f"Wrong gate anchor kind: {endpoint['endpoint_id']}")
        # Destination is separated from its own interaction gate, preventing auto retrigger.
        reverse = next((row for row in endpoints if row["connection_id"] == endpoint["connection_id"] and
                        row["origin_sector_id"] == endpoint["target_sector_id"]), None)
        if reverse:
            exit_anchor, entry = anchors[endpoint["exit_anchor_id"]], anchors[reverse["entry_anchor_id"]]
            distance = math.sqrt(sum((exit_anchor[key] - entry[key]) ** 2 for key in ("x_m", "y_m", "z_m")))
            require(distance > entry["interaction_radius_m"], f"Gate exit retrigger: {endpoint['endpoint_id']}")
    require(set(nodes) == set(locations), "Resource location closure incomplete")
    for node_id, location in locations.items():
        require(nodes[node_id]["sector_id"] == location["sector_id"] and
                anchors[location["anchor_id"]]["anchor_kind"] == "resource", f"Resource location mismatch: {node_id}")
    for signal in signals.values():
        require(anchors[signal["anchor_id"]]["anchor_kind"] == "signal", f"Invalid signal anchor: {signal['signal_id']}")
    patrols = rows("npc_patrol_points")
    for spawn in spawns.values():
        npc, behavior, home = npcs[spawn["npc_id"]], behaviors[spawn["behavior_id"]], anchors[spawn["anchor_id"]]
        require(npc["archetype_id"] == behavior["archetype_id"] and
                npc["risk_zone_id"] == sector_risks[spawn["sector_id"]]["risk_zone_id"] and
                home["anchor_kind"] == "npc_spawn", f"NPC archetype/risk/anchor mismatch: {spawn['spawn_id']}")
        points = sorted((point for point in patrols if point["spawn_id"] == spawn["spawn_id"]), key=lambda row: row["point_index"])
        require([point["point_index"] for point in points] == list(range(len(points))) and len(points) > 0,
                f"Missing/non-contiguous NPC patrol: {spawn['spawn_id']}")
        for point in points:
            target = anchors[point["anchor_id"]]
            require(target["sector_id"] == spawn["sector_id"] and target["anchor_kind"] == "patrol" and
                    sum((home[key] - target[key]) ** 2 for key in ("x_m", "y_m", "z_m")) <= behavior["leash_radius_m"] ** 2,
                    f"Invalid NPC patrol location: {spawn['spawn_id']}")
        for safe in anchors.values():
            if safe["sector_id"] == spawn["sector_id"] and safe["safe_radius_m"] > 0:
                distance = math.sqrt(sum((home[key] - safe[key]) ** 2 for key in ("x_m", "y_m", "z_m")))
                require(distance - behavior["leash_radius_m"] > safe["safe_radius_m"],
                        f"NPC leash overlaps safe area: {spawn['spawn_id']} / {safe['anchor_id']}")
    # Sites aggregate real spawn instances; no virtual enemy receives damage or loot.
    encounters = indexed("encounter_defs", "encounter_id")
    members = rows("encounter_members")
    require({site["sector_id"] for site in encounters.values()} == set(sector_risks),
            "Every playable system requires one combat site")
    require({member["spawn_id"] for member in members} ==
            {spawn_id for spawn_id, spawn in spawns.items() if spawn["occurrence_mode"] == "ambient"},
            "Ambient spawn/site membership closure incomplete")
    for encounter_id, site in encounters.items():
        site_members = sorted((m for m in members if m["encounter_id"] == encounter_id),
                              key=lambda m: m["member_index"])
        require([m["member_index"] for m in site_members] == list(range(len(site_members))) and len(site_members) > 0,
                f"Missing/non-contiguous encounter members: {encounter_id}")
        center = anchors[site["anchor_id"]]
        require(center["anchor_kind"] == "npc_spawn", f"Wrong encounter anchor kind: {encounter_id}")
        for member in site_members:
            spawn = spawns[member["spawn_id"]]
            require(spawn["sector_id"] == site["sector_id"] and spawn["occurrence_mode"] == "ambient" and
                    spawn["required_unlock_id"] == site["required_unlock_id"] and
                    spawn["respawn_s"] == site["respawn_seconds"],
                    f"Encounter member sector/unlock/refresh mismatch: {member['spawn_id']}")
            home = anchors[spawn["anchor_id"]]
            offset = math.sqrt(sum((home[key]-center[key])**2 for key in ("x_m", "y_m", "z_m")))
            require(site["warp_arrival_m"] > behaviors[spawn["behavior_id"]]["detection_range_m"] + offset,
                    f"Encounter warp arrival enters immediate acquisition range: {encounter_id}")
    packages = indexed("salvage_package_defs", "package_def_id")
    salvage_rewards = rows("salvage_reward_defs")
    for package_id, package in packages.items():
        package_rewards = [r for r in salvage_rewards if r["package_def_id"] == package_id]
        require(0 < sum(r["weight"] for r in package_rewards) <= 4294967295,
                f"Invalid salvage weight budget: {package_id}")
        require(float(package["volume_m3"])*1000 == int(float(package["volume_m3"])*1000),
                f"Salvage volume must convert exactly to cargo litres: {package_id}")
        for reward in package_rewards:
            if reward["item_def_id"] is not None and reward["item_def_id"] in indexed("module_defs", "module_id"):
                require(reward["item_def_id"] in indexed("module_salvage_recipe_defs", "module_id"),
                        f"Salvage equipment lacks frozen recycling provenance: {reward['reward_id']}")
    salvage_npcs = {r["npc_def_id"] for r in rows("npc_salvage_defs")}
    require(salvage_npcs == {spawn["npc_id"] for spawn in spawns.values() if spawn["occurrence_mode"] == "ambient"},
            "Every ambient NPC definition requires a salvage package and mission-only NPCs must be excluded")
    require({r["station_id"] for r in rows("station_service_defs") if r["service_id"] == "warehouse"} == set(stations),
            "Salvage recovery must be available at every station")
    require(set(missions) == set(rewards), "Every mission requires exactly one reward definition")
    prerequisites = rows("mission_prerequisites")
    objectives = rows("mission_objective_defs")
    for mission_id, mission in missions.items():
        indices = sorted(row["objective_index"] for row in objectives if row["mission_id"] == mission_id)
        require(indices == list(range(len(indices))) and len(indices) > 0, f"Missing/non-contiguous mission objectives: {mission_id}")
        if mission["tutorial_step_id"]:
            step = steps[mission["tutorial_step_id"]]
            require(rewards[mission_id]["reward_credit"] == step["reward_credit"], f"Tutorial reward drift: {mission_id}")
            expected = {step["prerequisite_step_id"]} if step["prerequisite_step_id"] else set()
            require({row["prerequisite_mission_id"] for row in prerequisites if row["mission_id"] == mission_id} == expected,
                    f"Tutorial prerequisite drift: {mission_id}")
    for loan in loans.values():
        policy = policies[loan["policy_id"]]
        require(not policy["may_sell"] and not policy["may_recycle"] and policy["inherit_to_attached"] and policy["inherit_to_supplies"],
                f"Unprotected loan assets: {loan['loan_service_id']}")
        require(loan["station_id"] == missions[loan["required_mission_id"]]["accept_station_id"] and
                loan["return_station_id"] == missions[loan["required_mission_id"]]["turnin_station_id"],
                f"Loan station mismatch: {loan['loan_service_id']}")
    # Reachability closes both prerequisites and unlock dependencies, including objective targets.
    unlocked = {row["unlock_id"] for row in rows("unlock_defs") if row["initially_unlocked"]}
    completed: set[str] = set()
    unlock_rewards = rows("mission_unlock_rewards")
    while True:
        previous_count = len(completed)
        for mission_id, mission in missions.items():
            if mission_id in completed or mission["required_unlock_id"] not in unlocked:
                continue
            required = {row["prerequisite_mission_id"] for row in prerequisites if row["mission_id"] == mission_id}
            if not required <= completed:
                continue
            target_unlocks = set()
            for objective in (row for row in objectives if row["mission_id"] == mission_id):
                for column, index in (("target_signal_id", signals), ("target_spawn_id", spawns),
                                      ("target_node_id", locations), ("target_loan_service_id", loans)):
                    if objective[column]:
                        target_unlocks.add(index[objective[column]]["required_unlock_id"])
                if objective["target_connection_id"]:
                    target_unlocks.update(row["required_unlock_id"] for row in endpoints
                                          if row["connection_id"] == objective["target_connection_id"])
            target_unlocks.update(loan["required_unlock_id"] for loan in loans.values() if loan["required_mission_id"] == mission_id)
            if not target_unlocks <= unlocked:
                continue
            completed.add(mission_id)
            unlocked.update(row["unlock_id"] for row in unlock_rewards if row["mission_id"] == mission_id)
        if len(completed) == previous_count:
            break
    require(completed == set(missions), f"Mission prerequisite/unlock cycle or unreachable target: {set(missions) - completed}")
    validate_combat_content(connection)
    validate_space_content(connection)
    validate_civilizations(connection)
    validate_industry(connection)
    validate_resource_intel(connection)


def validate_space_content(connection: sqlite3.Connection) -> None:
    """Verify astronomical/local separation and complete frozen location closure."""
    def rows(table: str) -> list[dict[str, object]]:
        cursor = connection.execute(f'SELECT * FROM "{table}"')
        columns = [column[0] for column in cursor.description]
        return [dict(zip(columns, row, strict=True)) for row in cursor]

    def require(valid: bool, message: str) -> None:
        if not valid:
            raise ValueError(message)
    sites = {row["site_id"]: row for row in rows("site_defs")}
    anchors = {row["anchor_id"]: row for row in rows("anchor_defs")}
    mapping = {row["anchor_id"]: row["site_id"] for row in rows("anchor_site_defs")}
    require(set(mapping) == set(anchors), "Every anchor must have exactly one astronomical site")
    require(set(mapping.values()) == set(sites), "An astronomical site cannot be empty or unreferenced")
    for aid, sid in mapping.items():
        anchor, site = anchors[aid], sites[sid]
        require(anchor["sector_id"] == site["sector_id"], f"Anchor/site sector mismatch: {aid}")
        require(math.dist((anchor["x_m"], anchor["y_m"], anchor["z_m"]),
                          (site["pivot_x_m"], site["pivot_y_m"], site["pivot_z_m"])) < site["local_radius_m"],
                f"Local anchor outside site radius: {aid}")
    for station in rows("station_defs"):
        require(mapping[station["station_anchor_id"]] == mapping[station["undock_anchor_id"]],
                f"Undock changes astronomical site: {station['station_id']}")
        for anchor in anchors.values():
            if anchor["sector_id"] == station["sector_id"] and anchor["anchor_kind"] == "flight_marker":
                require(mapping[anchor["anchor_id"]] == mapping[station["station_anchor_id"]],
                        "Basic flight tutorial must remain inside its station site")
    endpoints = rows("gate_endpoint_defs")
    for endpoint in endpoints:
        inverse = next(row for row in endpoints if row["connection_id"] == endpoint["connection_id"] and
                       row["origin_sector_id"] == endpoint["target_sector_id"] and row["target_sector_id"] == endpoint["origin_sector_id"])
        require(mapping[endpoint["entry_anchor_id"]] == mapping[inverse["exit_anchor_id"]],
                f"Gate entry/return exit split into different sites: {endpoint['endpoint_id']}")
    spawns = {row["spawn_id"]: row for row in rows("npc_spawn_defs")}
    for point in rows("npc_patrol_points"):
        require(mapping[point["anchor_id"]] == mapping[spawns[point["spawn_id"]]["anchor_id"]],
                f"NPC patrol crosses astronomical sites: {point['spawn_id']}")
    encounters = {row["encounter_id"]: row for row in rows("encounter_defs")}
    for member in rows("encounter_members"):
        require(mapping[spawns[member["spawn_id"]]["anchor_id"]] == mapping[encounters[member["encounter_id"]]["anchor_id"]],
                f"Encounter fleet must share one local site: {member['encounter_id']}")
    celestial = rows("celestial_defs")
    for sector in rows("sector_defs"):
        sid = sector["sector_id"]
        local_sites = [row for row in sites.values() if row["sector_id"] == sid]
        require(len(local_sites) >= 5, f"System lacks differentiated locations: {sid}")
        distances = [math.dist((a["x_m"], a["y_m"], a["z_m"]), (b["x_m"], b["y_m"], b["z_m"]))
                     for index, a in enumerate(local_sites) for b in local_sites[index+1:]]
        require(min(distances) >= 0.01 * 149597870700.0, f"Astronomical sites still too close: {sid}")
        require(max(distances) >= 0.5 * 149597870700.0, f"System still lacks an astronomical span: {sid}")
        bodies = [row for row in celestial if row["sector_id"] == sid]
        require(sum(row["celestial_kind"] == "star" for row in bodies) == 1, f"System needs one authoritative star: {sid}")
        require(any(row["celestial_kind"] == "planet" for row in bodies), f"System lacks a real planetary backdrop: {sid}")
        for body in bodies:
            for site in local_sites:
                distance = math.dist((body["x_m"], body["y_m"], body["z_m"]), (site["x_m"], site["y_m"], site["z_m"]))
                require(distance > body["radius_m"] + site["local_radius_m"], f"Playable site inside celestial body: {site['site_id']}")


def validate_combat_content(connection: sqlite3.Connection) -> None:
    """Check authoritative profiles, fitting and procurement before publication."""
    from collections import Counter, defaultdict
    from decimal import Decimal

    def records(table: str) -> list[dict[str, object]]:
        cursor = connection.execute(f"SELECT * FROM {identifier(table)}")
        columns = [column[0] for column in cursor.description]
        return [dict(zip(columns, row, strict=True)) for row in cursor]

    def indexed(table: str, key: str) -> dict[str, dict[str, object]]:
        return {row[key]: row for row in records(table)}

    def require(condition: bool, message: str) -> None:
        if not condition:
            raise ValueError(message)

    ships = indexed("ship_defs", "ship_id")
    items = indexed("item_defs", "item_id")
    modules = indexed("module_defs", "module_id")
    weapons = indexed("weapon_defs", "module_id")
    profiles = indexed("weapon_behavior_defs", "module_id")
    tech = indexed("module_tech_defs", "module_id")
    drones = indexed("drone_defs", "module_id")
    slots = {(row["ship_id"], row["slot_type"], row["slot_index"]) for row in records("ship_slot_defs")}
    capacities = {(row["ship_id"], row["slot_type"]): row["slot_count"] for row in records("ship_slot_capacity")}
    permissions = {(row["ship_id"], row["family_id"]): row for row in records("ship_weapon_permissions")}
    require(set(profiles) == set(weapons), "Weapon behavior profile closure incomplete")
    require(set(drones) == {mid for mid, row in profiles.items() if row["fire_mode"] == "drone"},
            "Drone definition/profile closure incomplete")
    for (ship_id, family), permission in permissions.items():
        require(permission["max_installed"] <= capacities[(ship_id, "weapon")],
                f"Weapon permission exceeds physical slots: {ship_id}/{family}")
    families: dict[str, list[str]] = defaultdict(list)
    for module_id, profile in profiles.items():
        require(modules[module_id]["slot_type"] == "weapon", f"Weapon in non-weapon slot: {module_id}")
        expected_mode = "ray" if profile["family_id"] == "thermal" else "drone" if profile["family_id"] == "drone" else "projectile"
        require(profile["fire_mode"] == expected_mode, f"Weapon delivery mode mismatch: {module_id}")
        weapon = weapons[module_id]
        require((weapon["projectile_speed_mps"] is not None and weapon["projectile_speed_mps"] > 0) if expected_mode == "projectile" else weapon["projectile_speed_mps"] is None,
                f"Weapon speed/delivery mode mismatch: {module_id}")
        compatible = [ship_id for ship_id in ships if (ship_id, profile["family_id"]) in permissions and
                      profile["size_class"] <= permissions[(ship_id, profile["family_id"])]["max_size"]]
        require(bool(compatible), f"No compatible hull for weapon: {module_id}")
        require(any(modules[module_id]["power_pu"] <= ships[ship_id]["power_capacity"] and
                    modules[module_id]["cpu_cu"] <= ships[ship_id]["cpu_capacity"] and
                    items[module_id]["unit_mass_kg"] <= ships[ship_id]["max_installed_mass_kg"] for ship_id in compatible),
                f"Compatible hulls cannot afford weapon installation: {module_id}")
        families[module_id.rsplit("_", 1)[0]].append(module_id)
        if expected_mode == "drone":
            drone = drones[module_id]
            require(drone["attack_range_m"] < modules[module_id]["range_m"] and
                    drone["return_radius_m"] < drone["attack_range_m"], f"Invalid drone engagement geometry: {module_id}")
            require(drone["sortie_timeout_s"] > 2 * modules[module_id]["range_m"] / drone["speed_mps"],
                    f"Drone cannot return within sortie timeout: {module_id}")
    for family, members in families.items():
        ordered = sorted(members, key=lambda mid: tech[mid]["tech_level"])
        require([tech[mid]["tech_level"] for mid in ordered] == [1, 2, 3], f"Weapon generation closure incomplete: {family}")
        require(len({(profiles[mid]["family_id"], profiles[mid]["size_class"]) for mid in members}) == 1,
                f"Weapon generation changes family or mount size: {family}")
        for previous, current in zip(ordered, ordered[1:]):
            require(weapons[current]["raw_damage"] / modules[current]["cycle_s"] >
                    weapons[previous]["raw_damage"] / modules[previous]["cycle_s"] and
                    modules[current]["range_m"] > modules[previous]["range_m"] and
                    items[current]["base_ask_credit"] > items[previous]["base_ask_credit"],
                    f"Weapon generation fails damage/range/cost progression: {family}")
    for loadout in records("ship_loadout_defs"):
        ship = ships[loadout["ship_id"]]
        fitted = [row for row in records("ship_loadout_items") if row["loadout_id"] == loadout["loadout_id"]]
        counts = Counter(row["module_id"] for row in fitted)
        family_counts: Counter[str] = Counter()
        for row in fitted:
            module_id = row["module_id"]
            require((ship["ship_id"], row["slot_type"], row["slot_index"]) in slots and
                    row["slot_type"] == modules[module_id]["slot_type"], f"Invalid default slot: {loadout['loadout_id']}")
            maximum = modules[module_id]["max_per_ship"]
            require(maximum is None or counts[module_id] <= maximum, f"Default module count exceeded: {module_id}")
            if module_id in profiles:
                profile = profiles[module_id]
                permission = permissions.get((ship["ship_id"], profile["family_id"]))
                require(permission is not None and profile["size_class"] <= permission["max_size"],
                        f"Default weapon incompatible: {loadout['loadout_id']}/{module_id}")
                family_counts[profile["family_id"]] += 1
        for family, count in family_counts.items():
            require(count <= permissions[(ship["ship_id"], family)]["max_installed"], f"Default family count exceeded: {loadout['loadout_id']}/{family}")
        for field, capacity in (("power_pu", "power_capacity"), ("cpu_cu", "cpu_capacity")):
            require(sum(modules[row["module_id"]][field] for row in fitted) <= ship[capacity], f"Default fitting budget exceeded: {loadout['loadout_id']}/{field}")
        require(sum(items[row["module_id"]]["unit_mass_kg"] for row in fitted) <= ship["max_installed_mass_kg"],
                f"Default installation mass exceeded: {loadout['loadout_id']}")
    require(set(indexed("system_lighting_defs", "system_id")) == set(indexed("system_defs", "system_id")),
            "System lighting closure incomplete")
    # Optimistic fractional procurement includes the best station discount and
    # best existing industry facility. Integer batches and rounding cost more.
    dec = lambda value: Decimal(str(value))
    rules = {row["parameter_id"]: row["value_integer"] if row["value_integer"] is not None else row["value_real"] for row in records("rule_parameters")}
    buy = (1 - dec(rules["max_buy_discount_ratio"])) * (1 + dec(rules["trade_fee_ratio"]))
    sell = (1 + dec(rules["max_sell_bonus_ratio"])) * (1 - dec(rules["trade_fee_ratio"]))
    facility = max((dec(row["effect_multiplier"]) for row in records("base_module_defs") if row["service_kind"] == "industry"), default=Decimal(1))
    recipes = indexed("recipe_defs", "recipe_id")
    inputs: dict[str, dict[str, int]] = defaultdict(dict)
    by_output: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in records("recipe_inputs"):
        inputs[row["recipe_id"]][row["item_id"]] = row["quantity"]
    for recipe in recipes.values():
        require(bool(inputs[recipe["recipe_id"]]), f"Recipe lacks real material inputs: {recipe['recipe_id']}")
        by_output[recipe["output_item_id"]].append(recipe)
    minimum: dict[str, Decimal] = {}
    visiting: set[str] = set()
    def cost(item_id: str) -> Decimal:
        if item_id in minimum:
            return minimum[item_id]
        require(item_id not in visiting, f"Recipe dependency cycle: {item_id}")
        visiting.add(item_id)
        candidates = [dec(items[item_id]["base_ask_credit"]) * buy]
        for recipe in by_output[item_id]:
            candidates.append((dec(recipe["service_fee_credit"]) / facility +
                               sum((cost(mid) * quantity for mid, quantity in inputs[recipe["recipe_id"]].items()), Decimal(0))) / recipe["output_quantity"])
        minimum[item_id] = min(candidates)
        visiting.remove(item_id)
        return minimum[item_id]
    stocked = {row["item_id"] for row in records("station_stock_defs") if row["allow_buy"] and row["target_units"] > 0}
    for item_id, item in items.items():
        require(dec(item["base_bid_credit"]) * sell < cost(item_id), f"Recursive manufacture/sale arbitrage: {item_id}")
    salvage = indexed("module_salvage_recipe_defs", "module_id")
    recycle: dict[str, dict[str, int]] = defaultdict(dict)
    for row in records("recycle_outputs"):
        recycle[row["source_item_id"]][row["output_item_id"]] = row["quantity"]
    require(set(salvage) == set(modules), "Module recycling provenance closure incomplete")
    for module_id, origin in salvage.items():
        expected = {mid: math.floor(quantity * rules["recycle_input_return_ratio"]) for mid, quantity in inputs[origin["recipe_id"]].items()}
        require(recycle[module_id] == {mid: quantity for mid, quantity in expected.items() if quantity > 0},
                f"Module recycling differs from frozen input provenance: {module_id}")
        returned = sum((cost(mid) * quantity for mid, quantity in recycle[module_id].items()), Decimal(0))
        require(returned <= cost(module_id) + dec(rules["recycle_service_fee_credit"]), f"Recycling procurement arbitrage: {module_id}")
    for module_id in weapons:
        require(module_id in stocked and bool(by_output[module_id]), f"Weapon lacks procurement/manufacture route: {module_id}")


def build_catalog(output: Path = DEFAULT_OUTPUT) -> dict[str, object]:
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary_dir = ROOT / "jiaoben/tmp"
    temporary_dir.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix="catalog-build-", suffix=".db", dir=temporary_dir)
    os.close(descriptor)
    temporary = Path(temporary_name)
    connection = sqlite3.connect(temporary)
    try:
        connection.execute("PRAGMA foreign_keys=ON")
        connection.execute("PRAGMA journal_mode=DELETE")
        connection.execute("PRAGMA synchronous=EXTRA")
        # One explicit transaction: schema, seed, checks and logical hash.
        source = "BEGIN IMMEDIATE;\n" + "\n".join(path.read_text(encoding="utf-8") for path in (SCHEMA, SEED, SPACE, CIVILIZATION_SCHEMA, CIVILIZATION_SEED, INDUSTRY_SCHEMA, INDUSTRY_SEED, RESOURCE_INTEL_SCHEMA, RESOURCE_INTEL_SEED))
        connection.executescript(source)
        validate_database(connection)
        content_hash = logical_content_hash(connection)
        connection.execute("UPDATE catalog_meta SET content_hash=? WHERE singleton=1", (content_hash,))
        schema_version = connection.execute("SELECT schema_version FROM catalog_meta WHERE singleton=1").fetchone()[0]
        connection.execute(f"PRAGMA user_version={schema_version}")
        connection.commit()
        metadata = connection.execute("SELECT content_version, ruleset_version FROM catalog_meta").fetchone()
        counts = {table: connection.execute(f"SELECT count(*) FROM {identifier(table)}").fetchone()[0] for table in CONTENT_TABLES}
        connection.close()
        os.replace(temporary, output)
        return {
            "output": str(output), "content_version": metadata[0], "ruleset_version": metadata[1],
            "sqlite_version": sqlite3.sqlite_version, "content_hash": content_hash,
            "file_sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "counts": counts,
        }
    except BaseException:
        if connection:
            try:
                connection.rollback()
                connection.close()
            except sqlite3.Error:
                pass
        raise
    finally:
        temporary.unlink(missing_ok=True)
        Path(str(temporary) + "-journal").unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()
    result = build_catalog(arguments.output)
    print(f"Built: {result['output']}")
    print(f"Content: {result['content_version']} / {result['ruleset_version']}")
    print(f"SQLite stdlib: {result['sqlite_version']}")
    print(f"Logical SHA-256: {result['content_hash']}")
    print(f"File SHA-256: {result['file_sha256']}")
    print(f"Tables: {len(result['counts'])}; ships: {result['counts']['ship_defs']}; modules: {result['counts']['module_defs']}; recipes: {result['counts']['recipe_defs']}")


if __name__ == "__main__":
    main()
