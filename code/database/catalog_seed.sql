-- 数值量值来源：doc/15-数值系统与平衡基线.md，v0.2-baseline。
-- B 内容来源：doc/19 与 doc/20，v0.3-devready。
-- SQL 是可复现构建输入；运行时权威是构建得到的 catalog.db。
-- 教学赠船/借船及附带设备均继承保护策略；此处仅定义，不实现进度。

INSERT INTO catalog_meta (singleton, pack_id, content_version, ruleset_version, schema_version, source_document, hash_algorithm, content_hash) VALUES
    (1, 'catalog_defs', 'v0.3-devready', 'devready_v0_3', 2, 'doc/15-数值系统与平衡基线.md;doc/19-首版任务星区与经济内容规格.md;doc/20-资源表现与界面实施规格.md', 'catalog_hash_v1', 'pending_build');

INSERT INTO rule_parameters (parameter_id, value_integer, value_real, unit) VALUES
    ('simulation_hz', 60, NULL, 'Hz'),
    ('resistance_cap', NULL, 0.75, 'ratio'),
    ('overheat_warning_ratio', NULL, 0.8, 'ratio'),
    ('overheat_unlock_ratio', NULL, 0.5, 'ratio'),
    ('shield_recharge_delay_s', NULL, 10, 's'),
    ('basic_scan_range_m', NULL, 500, 'm'),
    ('basic_scan_cycle_s', NULL, 1, 's'),
    ('scan_threshold', NULL, 300, 'progress'),
    ('tutorial_scan_threshold', NULL, 80, 'progress'),
    ('basic_scan_energy_eu_s', NULL, 2, 'EU/s'),
    ('basic_scan_heat_hu_s', NULL, 1, 'HU/s'),
    ('basic_scan_priority', 45, NULL, 'priority'),
    ('scan_difficulty_common', NULL, 1, 'multiplier'),
    ('scan_difficulty_hidden', NULL, 2, 'multiplier'),
    ('scan_difficulty_advanced', NULL, 4, 'multiplier'),
    ('scan_proximity_floor', NULL, 0.25, 'ratio'),
    ('scan_proximity_intercept', NULL, 1.75, 'ratio'),
    ('scan_proximity_distance_slope', NULL, 1.5, 'ratio'),
    ('trade_fee_ratio', NULL, 0.02, 'ratio'),
    ('max_buy_discount_ratio', NULL, 0.05, 'ratio'),
    ('max_sell_bonus_ratio', NULL, 0.05, 'ratio'),
    ('recycle_input_return_ratio', NULL, 0.5, 'ratio'),
    ('recycle_service_fee_credit', 100, NULL, 'credit'),
    ('gate_entry_radius_m', NULL, 120, 'm'),
    ('gate_max_entry_speed_mps', NULL, 20, 'm/s'),
    ('npc_basis_point_denominator', 10000, NULL, 'bp'),
    ('npc_hp_bp_per_level', 2000, NULL, 'bp'),
    ('npc_dps_bp_per_level', 1200, NULL, 'bp'),
    ('npc_reward_bp_per_level', 3500, NULL, 'bp'),
    ('basic_propulsion_energy_eu', NULL, 0, 'EU'),
    ('basic_brake_energy_eu', NULL, 0, 'EU'),
    ('brake_acceleration_multiplier', NULL, 1.4, 'multiplier'),
    ('strafe_acceleration_multiplier', NULL, 0.6, 'multiplier'),
    ('reverse_acceleration_multiplier', NULL, 0.5, 'multiplier'),
    ('scan_interference_floor', NULL, 1, 'multiplier'),
    ('module_durability_max', 100, NULL, 'durability'),
    ('standard_quality_multiplier', NULL, 1, 'multiplier'),
    ('combat_exit_delay_s', NULL, 15, 's'),
    ('save_wait_prompt_s', NULL, 10, 'real_s'),
    ('autosave_interval_s', NULL, 120, 'world_s'),
    ('wreck_cargo_recovery_ratio', NULL, 0.5, 'ratio'),
    ('dock_radius_m', NULL, 600, 'm'),
    ('dock_max_speed_mps', NULL, 20, 'm/s'),
    ('wreck_pickup_radius_m', NULL, 100, 'm');

INSERT INTO currency_defs (currency_id, display_name, unit) VALUES
    ('currency_route_credit', '航路信用点', 'credit');

INSERT INTO damage_types (damage_type) VALUES
    ('kinetic'),
    ('thermal'),
    ('pulse');

INSERT INTO defense_layers (layer_id, layer_order) VALUES
    ('shield', 0),
    ('armor', 1),
    ('hull', 2);

INSERT INTO slot_types (slot_type) VALUES
    ('weapon'),
    ('work'),
    ('utility'),
    ('structure');

INSERT INTO ship_defs (ship_id, display_name, dry_mass_kg, max_installed_mass_kg, max_payload_mass_kg, max_speed_mps, acceleration_mps2, turn_rad_s, shield_max, armor_max, hull_max, energy_max, recharge_eu_s, heat_max, cooling_hu_s, shield_recharge_hp_s, cargo_l, mineral_cargo_l, power_capacity, cpu_capacity, scan_strength, mining_multiplier, base_ask_credit, base_bid_credit) VALUES
    ('shuttle_swift', '雨燕级穿梭器', 55000, 5000, 5000, 300, 35, 1.5, 120, 80, 160, 160, 7, 80, 8, 1.5, 12000, 0, 100, 80, 8, 1, 4500, 1800),
    ('frigate_lantern', '提灯级探索护卫舰', 140000, 9000, 18000, 220, 20, 1, 220, 140, 260, 300, 12, 110, 10, 2.5, 40000, 0, 180, 140, 20, 1, 18000, 7200),
    ('frigate_kestrel', '游隼级战斗护卫舰', 180000, 16000, 8000, 240, 24, 1.1, 300, 220, 320, 360, 14, 140, 12, 3, 16000, 0, 210, 130, 8, 1, 24000, 9600),
    ('miner_anvil', '铁砧级采矿舰', 650000, 30000, 120000, 120, 8, 0.45, 420, 520, 650, 500, 18, 200, 16, 3.5, 50000, 300000, 300, 180, 10, 1.5, 30000, 12000);

INSERT INTO ship_slot_capacity (ship_id, slot_type, slot_count) VALUES
    ('shuttle_swift', 'weapon', 1),
    ('shuttle_swift', 'work', 0),
    ('shuttle_swift', 'utility', 2),
    ('shuttle_swift', 'structure', 1),
    ('frigate_lantern', 'weapon', 1),
    ('frigate_lantern', 'work', 1),
    ('frigate_lantern', 'utility', 3),
    ('frigate_lantern', 'structure', 1),
    ('frigate_kestrel', 'weapon', 2),
    ('frigate_kestrel', 'work', 0),
    ('frigate_kestrel', 'utility', 3),
    ('frigate_kestrel', 'structure', 2),
    ('miner_anvil', 'weapon', 1),
    ('miner_anvil', 'work', 2),
    ('miner_anvil', 'utility', 3),
    ('miner_anvil', 'structure', 2);

WITH RECURSIVE indices(ship_id, slot_type, slot_index, slot_count) AS (
 SELECT ship_id, slot_type, 0, slot_count FROM ship_slot_capacity WHERE slot_count > 0
 UNION ALL SELECT ship_id, slot_type, slot_index + 1, slot_count FROM indices WHERE slot_index + 1 < slot_count
)
INSERT INTO ship_slot_defs SELECT ship_id, slot_type, slot_index FROM indices;

INSERT INTO ship_resistances (ship_id, layer_id, damage_type, resistance) VALUES
    ('shuttle_swift', 'shield', 'kinetic', 0.2),
    ('shuttle_swift', 'shield', 'thermal', 0.1),
    ('shuttle_swift', 'shield', 'pulse', 0),
    ('shuttle_swift', 'armor', 'kinetic', 0.15),
    ('shuttle_swift', 'armor', 'thermal', 0.15),
    ('shuttle_swift', 'armor', 'pulse', 0.05),
    ('shuttle_swift', 'hull', 'kinetic', 0.05),
    ('shuttle_swift', 'hull', 'thermal', 0.05),
    ('shuttle_swift', 'hull', 'pulse', 0.05),
    ('frigate_lantern', 'shield', 'kinetic', 0.2),
    ('frigate_lantern', 'shield', 'thermal', 0.1),
    ('frigate_lantern', 'shield', 'pulse', 0),
    ('frigate_lantern', 'armor', 'kinetic', 0.15),
    ('frigate_lantern', 'armor', 'thermal', 0.15),
    ('frigate_lantern', 'armor', 'pulse', 0.05),
    ('frigate_lantern', 'hull', 'kinetic', 0.05),
    ('frigate_lantern', 'hull', 'thermal', 0.05),
    ('frigate_lantern', 'hull', 'pulse', 0.05),
    ('frigate_kestrel', 'shield', 'kinetic', 0.2),
    ('frigate_kestrel', 'shield', 'thermal', 0.1),
    ('frigate_kestrel', 'shield', 'pulse', 0),
    ('frigate_kestrel', 'armor', 'kinetic', 0.15),
    ('frigate_kestrel', 'armor', 'thermal', 0.15),
    ('frigate_kestrel', 'armor', 'pulse', 0.05),
    ('frigate_kestrel', 'hull', 'kinetic', 0.05),
    ('frigate_kestrel', 'hull', 'thermal', 0.05),
    ('frigate_kestrel', 'hull', 'pulse', 0.05),
    ('miner_anvil', 'shield', 'kinetic', 0.2),
    ('miner_anvil', 'shield', 'thermal', 0.1),
    ('miner_anvil', 'shield', 'pulse', 0),
    ('miner_anvil', 'armor', 'kinetic', 0.15),
    ('miner_anvil', 'armor', 'thermal', 0.15),
    ('miner_anvil', 'armor', 'pulse', 0.05),
    ('miner_anvil', 'hull', 'kinetic', 0.05),
    ('miner_anvil', 'hull', 'thermal', 0.05),
    ('miner_anvil', 'hull', 'pulse', 0.05);

INSERT INTO item_defs (item_id, display_name, item_type, unit_mass_kg, unit_volume_l, stackable, base_ask_credit, base_bid_credit) VALUES
    ('ore_ferrosilicate', '铁硅矿', 'ore', 40, 100, 1, 20, 8),
    ('ore_conductive_crystal', '导能晶体', 'ore', 15, 50, 1, 50, 20),
    ('material_dense_alloy', '高密合金', 'material', 20, 20, 1, 600, 220),
    ('component_relic', '遗构元件', 'component', 2, 10, 1, 300, 100),
    ('ammo_kinetic_slug_i', '基础动能弹', 'ammo', 0.15, 1, 1, 3, 1),
    ('repair_kit_i', '基础维修包', 'consumable', 1, 10, 1, 220, 80),
    ('material_structural_stock', '结构料', 'material', 4, 10, 1, 45, 15),
    ('material_conductive_medium', '导能介质', 'material', 1, 5, 1, 100, 40),
    ('component_weapon_frame', '武器框架', 'component', 80, 400, 1, 1600, 640),
    ('component_power_cell', '储能组件', 'component', 5, 20, 1, 400, 160),
    ('component_fire_control', '标准火控部件', 'component', 1, 10, 1, 250, 100),
    ('component_scan_frame', '扫描框架', 'component', 10, 100, 1, 850, 340),
    ('component_industry_control', '作业控制部件', 'component', 2, 10, 1, 450, 180),
    ('component_projection_control', '投射控制部件', 'component', 2, 10, 1, 400, 160),
    ('component_sensor_core', '基础传感核心', 'component', 1, 10, 1, 350, 140),
    ('component_pulse_ring', '基础脉冲环', 'component', 3, 20, 1, 950, 380),
    ('component_thruster_cluster', '基础推进集群', 'component', 50, 200, 1, 1100, 440),
    ('component_repair_mesh', '基础维修网格', 'component', 2, 10, 1, 350, 140),
    ('material_pressure_stock', '通用承压材', 'material', 15, 10, 1, 300, 120),
    ('material_feather_alloy', '通用轻翎合金', 'material', 5, 20, 1, 300, 120),
    ('component_thermal_focus', '基础热束聚焦件', 'component', 2, 20, 1, 1300, 520),
    ('module_kinetic_needle_i', '针锋动能炮 I', 'module', 500, 600, 0, 2800, 840),
    ('module_thermal_sunline_i', '曜线热束器 I', 'module', 650, 800, 0, 4800, 1440),
    ('module_pulse_breakwater_i', '破浪脉冲器 I', 'module', 700, 850, 0, 4200, 1260),
    ('module_shield_lattice_i', '格网护盾组件 I', 'module', 450, 500, 0, 2400, 720),
    ('module_armor_pressure_i', '承压护板 I', 'module', 2400, 2400, 0, 2600, 780),
    ('module_armor_feather_i', '轻翎护板 I', 'module', 600, 1000, 0, 2200, 660),
    ('module_engine_vector_i', '矢量姿态引擎 I', 'module', 400, 600, 0, 2600, 780),
    ('module_scanner_beacon_i', '远标扫描阵列 I', 'module', 300, 800, 0, 2200, 660),
    ('module_industry_sift_i', '筛光采集头 I', 'module', 1200, 1600, 0, 3000, 900),
    ('module_support_patch_i', '缝桥维修投射器 I', 'module', 1000, 1200, 0, 2800, 840);

INSERT INTO module_defs (module_id, slot_type, power_pu, cpu_cu, cycle_s, range_m, energy_eu, heat_hu, max_per_ship) VALUES
    ('module_kinetic_needle_i', 'weapon', 30, 18, 1.2, 900, 4, 6, NULL),
    ('module_thermal_sunline_i', 'weapon', 45, 30, 0.5, 700, 10, 8, 1),
    ('module_pulse_breakwater_i', 'weapon', 40, 28, 2.4, 600, 24, 16, 1),
    ('module_shield_lattice_i', 'utility', 35, 20, 3, 0, 24, 9, 1),
    ('module_armor_pressure_i', 'structure', 6, 8, 0, 0, 0, 0, 1),
    ('module_armor_feather_i', 'structure', 4, 10, 0, 0, 0, 0, 1),
    ('module_engine_vector_i', 'utility', 35, 24, 1, 0, 2, 2, 1),
    ('module_scanner_beacon_i', 'utility', 40, 45, 1, 3000, 6, 2, 1),
    ('module_industry_sift_i', 'work', 55, 30, 4, 180, 10, 10, NULL),
    ('module_support_patch_i', 'work', 40, 32, 5, 250, 18, 12, 1);

INSERT INTO module_activation_priority (module_id, priority) VALUES
    ('module_kinetic_needle_i', 30),
    ('module_thermal_sunline_i', 30),
    ('module_pulse_breakwater_i', 30),
    ('module_shield_lattice_i', 20),
    ('module_engine_vector_i', 10),
    ('module_scanner_beacon_i', 40),
    ('module_industry_sift_i', 50),
    ('module_support_patch_i', 20);

INSERT INTO weapon_defs (module_id, damage_type, raw_damage, projectile_speed_mps, ammo_item_id, ammo_per_cycle) VALUES
    ('module_kinetic_needle_i', 'kinetic', 34, 1200, 'ammo_kinetic_slug_i', 1),
    ('module_thermal_sunline_i', 'thermal', 28, NULL, NULL, 0),
    ('module_pulse_breakwater_i', 'pulse', 72, NULL, NULL, 0);

INSERT INTO repair_defs (module_id, layer_id, restore_amount, consumable_item_id, consumable_per_cycle) VALUES
    ('module_shield_lattice_i', 'shield', 50, NULL, 0),
    ('module_support_patch_i', 'armor', 60, 'repair_kit_i', 1);

INSERT INTO stat_defs (stat_id, unit) VALUES
    ('armor_max', 'HP'),
    ('max_speed_mps', 'm/s'),
    ('acceleration_mps2', 'm/s2'),
    ('turn_rad_s', 'rad/s'),
    ('scan_strength', 'progress/s');

INSERT INTO module_stat_modifiers (module_id, stat_id, operation, amount) VALUES
    ('module_armor_pressure_i', 'armor_max', 'add', 180),
    ('module_armor_feather_i', 'armor_max', 'add', 85),
    ('module_engine_vector_i', 'max_speed_mps', 'multiply', 1.1),
    ('module_engine_vector_i', 'acceleration_mps2', 'multiply', 1.2),
    ('module_engine_vector_i', 'turn_rad_s', 'multiply', 1.2),
    ('module_scanner_beacon_i', 'scan_strength', 'add', 15);

INSERT INTO module_resistance_modifiers (module_id, layer_id, damage_type, delta) VALUES
    ('module_armor_pressure_i', 'armor', 'kinetic', 0.08),
    ('module_armor_pressure_i', 'armor', 'thermal', 0.04),
    ('module_armor_pressure_i', 'armor', 'pulse', -0.02),
    ('module_armor_feather_i', 'armor', 'kinetic', 0.02),
    ('module_armor_feather_i', 'armor', 'thermal', 0.02),
    ('module_armor_feather_i', 'armor', 'pulse', 0.02);

INSERT INTO mining_defs (module_id, base_yield_units) VALUES
    ('module_industry_sift_i', 8);

INSERT INTO mining_compatibility (module_id, item_id) VALUES
    ('module_industry_sift_i', 'ore_ferrosilicate'),
    ('module_industry_sift_i', 'ore_conductive_crystal');

INSERT INTO module_exclusion_groups (group_id, max_installed) VALUES
    ('engine', 1),
    ('scanner', 1),
    ('shield', 1),
    ('armor_upgrade', 1),
    ('support', 1);

INSERT INTO module_group_members (module_id, group_id) VALUES
    ('module_engine_vector_i', 'engine'),
    ('module_scanner_beacon_i', 'scanner'),
    ('module_shield_lattice_i', 'shield'),
    ('module_armor_pressure_i', 'armor_upgrade'),
    ('module_armor_feather_i', 'armor_upgrade'),
    ('module_support_patch_i', 'support');

INSERT INTO ship_loadout_defs (loadout_id, ship_id, display_name) VALUES
    ('loadout_shuttle_swift', 'shuttle_swift', '首轮默认配装：雨燕级穿梭器'),
    ('loadout_frigate_lantern', 'frigate_lantern', '首轮默认配装：提灯级探索护卫舰'),
    ('loadout_frigate_kestrel', 'frigate_kestrel', '首轮默认配装：游隼级战斗护卫舰'),
    ('loadout_miner_anvil', 'miner_anvil', '首轮默认配装：铁砧级采矿舰');

INSERT INTO ship_loadout_items (loadout_id, ship_id, slot_type, slot_index, module_id) VALUES
    ('loadout_shuttle_swift', 'shuttle_swift', 'weapon', 0, 'module_kinetic_needle_i'),
    ('loadout_shuttle_swift', 'shuttle_swift', 'utility', 0, 'module_engine_vector_i'),
    ('loadout_frigate_lantern', 'frigate_lantern', 'weapon', 0, 'module_kinetic_needle_i'),
    ('loadout_frigate_lantern', 'frigate_lantern', 'utility', 0, 'module_scanner_beacon_i'),
    ('loadout_frigate_lantern', 'frigate_lantern', 'utility', 1, 'module_engine_vector_i'),
    ('loadout_frigate_lantern', 'frigate_lantern', 'utility', 2, 'module_shield_lattice_i'),
    ('loadout_frigate_kestrel', 'frigate_kestrel', 'weapon', 0, 'module_kinetic_needle_i'),
    ('loadout_frigate_kestrel', 'frigate_kestrel', 'weapon', 1, 'module_kinetic_needle_i'),
    ('loadout_frigate_kestrel', 'frigate_kestrel', 'utility', 0, 'module_engine_vector_i'),
    ('loadout_frigate_kestrel', 'frigate_kestrel', 'utility', 1, 'module_shield_lattice_i'),
    ('loadout_miner_anvil', 'miner_anvil', 'weapon', 0, 'module_kinetic_needle_i'),
    ('loadout_miner_anvil', 'miner_anvil', 'work', 0, 'module_industry_sift_i'),
    ('loadout_miner_anvil', 'miner_anvil', 'work', 1, 'module_industry_sift_i'),
    ('loadout_miner_anvil', 'miner_anvil', 'utility', 0, 'module_scanner_beacon_i'),
    ('loadout_miner_anvil', 'miner_anvil', 'utility', 1, 'module_engine_vector_i'),
    ('loadout_miner_anvil', 'miner_anvil', 'utility', 2, 'module_shield_lattice_i');

INSERT INTO risk_zone_defs (risk_zone_id, display_name, npc_level_min, npc_level_max) VALUES
    ('risk_high', '高安全区', 1, 5),
    ('risk_medium', '中安全区', 3, 8),
    ('risk_low', '低安全区', 6, 12);

INSERT INTO npc_archetype_defs (archetype_id, display_name, base_shield, base_armor, base_hull, base_raw_dps, damage_type, speed_mps, range_m, base_reward_credit) VALUES
    ('npc_scout_light', '轻型侦察者', 60, 80, 100, 8, 'kinetic', 180, 550, 80),
    ('npc_raider_medium', '中型掠袭者', 160, 180, 220, 16, 'kinetic', 150, 700, 150),
    ('npc_guardian_heavy', '重型守卫', 320, 380, 420, 24, 'pulse', 90, 900, 300);

WITH RECURSIVE levels(level) AS (SELECT 1 UNION ALL SELECT level + 1 FROM levels WHERE level < (SELECT MAX(npc_level_max) FROM risk_zone_defs))
INSERT INTO npc_level_defs SELECT level,
 (SELECT value_integer FROM rule_parameters WHERE parameter_id='npc_basis_point_denominator') + (SELECT value_integer FROM rule_parameters WHERE parameter_id='npc_hp_bp_per_level')*(level-1),
 (SELECT value_integer FROM rule_parameters WHERE parameter_id='npc_basis_point_denominator') + (SELECT value_integer FROM rule_parameters WHERE parameter_id='npc_dps_bp_per_level')*(level-1),
 (SELECT value_integer FROM rule_parameters WHERE parameter_id='npc_basis_point_denominator') + (SELECT value_integer FROM rule_parameters WHERE parameter_id='npc_reward_bp_per_level')*(level-1) FROM levels;

INSERT INTO npc_defs (npc_id, archetype_id, level, risk_zone_id) VALUES
    ('npc_scout_light_l1', 'npc_scout_light', 1, 'risk_high'),
    ('npc_raider_medium_l3', 'npc_raider_medium', 3, 'risk_medium'),
    ('npc_guardian_heavy_l6', 'npc_guardian_heavy', 6, 'risk_low');

INSERT INTO npc_resistances (archetype_id, layer_id, damage_type, resistance) VALUES
    ('npc_scout_light', 'shield', 'kinetic', 0.2),
    ('npc_scout_light', 'shield', 'thermal', 0.1),
    ('npc_scout_light', 'shield', 'pulse', 0),
    ('npc_scout_light', 'armor', 'kinetic', 0.15),
    ('npc_scout_light', 'armor', 'thermal', 0.15),
    ('npc_scout_light', 'armor', 'pulse', 0.05),
    ('npc_scout_light', 'hull', 'kinetic', 0.05),
    ('npc_scout_light', 'hull', 'thermal', 0.05),
    ('npc_scout_light', 'hull', 'pulse', 0.05),
    ('npc_raider_medium', 'shield', 'kinetic', 0.2),
    ('npc_raider_medium', 'shield', 'thermal', 0.1),
    ('npc_raider_medium', 'shield', 'pulse', 0),
    ('npc_raider_medium', 'armor', 'kinetic', 0.15),
    ('npc_raider_medium', 'armor', 'thermal', 0.15),
    ('npc_raider_medium', 'armor', 'pulse', 0.05),
    ('npc_raider_medium', 'hull', 'kinetic', 0.05),
    ('npc_raider_medium', 'hull', 'thermal', 0.05),
    ('npc_raider_medium', 'hull', 'pulse', 0.05),
    ('npc_guardian_heavy', 'shield', 'kinetic', 0.2),
    ('npc_guardian_heavy', 'shield', 'thermal', 0.1),
    ('npc_guardian_heavy', 'shield', 'pulse', 0),
    ('npc_guardian_heavy', 'armor', 'kinetic', 0.15),
    ('npc_guardian_heavy', 'armor', 'thermal', 0.15),
    ('npc_guardian_heavy', 'armor', 'pulse', 0.05),
    ('npc_guardian_heavy', 'hull', 'kinetic', 0.05),
    ('npc_guardian_heavy', 'hull', 'thermal', 0.05),
    ('npc_guardian_heavy', 'hull', 'pulse', 0.05);

INSERT INTO system_defs (system_id, display_name) VALUES
    ('system_anchor', '锚港星系'),
    ('system_echo', '回声带星系');

INSERT INTO sector_defs (sector_id, system_id, risk_zone_id) VALUES
    ('sector_anchor', 'system_anchor', 'risk_high'),
    ('sector_echo', 'system_echo', 'risk_high');

INSERT INTO gate_class_defs (gate_class_id, max_gross_mass_kg, prepare_s, cooldown_s, energy_cost_eu, fee_credit, total_mass_budget_kg, lifetime_s) VALUES
    ('gate_basic', 1000000, 3, 8, 12, 20, NULL, NULL),
    ('gate_medium', 5000000, 5, 12, 20, 50, NULL, NULL),
    ('gate_heavy', 20000000, 8, 20, 40, 100, NULL, NULL),
    ('gate_wandering_candidate', 1000000, 4, 12, 15, 0, 5000000, 1800);

INSERT INTO connection_defs (connection_id, origin_sector_id, target_sector_id, bidirectional, gate_class_id, energy_cost_override_eu, fee_override_credit) VALUES
    ('conn_anchor_echo', 'sector_anchor', 'sector_echo', 1, 'gate_basic', 0, 0);

INSERT INTO resource_node_defs (node_id, sector_id, item_id, capacity_units, respawn_s) VALUES
    ('node_echo_ferrosilicate', 'sector_echo', 'ore_ferrosilicate', 3000, 1200),
    ('node_echo_conductive', 'sector_echo', 'ore_conductive_crystal', 600, 1200);

INSERT INTO recipe_defs (recipe_id, output_item_id, output_quantity, service_fee_credit, duration_s) VALUES
    ('recipe_structural', 'material_structural_stock', 4, 10, 0),
    ('recipe_conductive', 'material_conductive_medium', 3, 12, 0),
    ('recipe_dense', 'material_dense_alloy', 1, 40, 0),
    ('recipe_weapon_frame', 'component_weapon_frame', 1, 30, 0),
    ('recipe_power_cell', 'component_power_cell', 1, 20, 0),
    ('recipe_fire_control', 'component_fire_control', 1, 15, 0),
    ('recipe_scan_frame', 'component_scan_frame', 1, 20, 0),
    ('recipe_industry_control', 'component_industry_control', 1, 20, 0),
    ('recipe_projection_control', 'component_projection_control', 1, 20, 0),
    ('recipe_sensor_core_basic', 'component_sensor_core', 1, 20, 0),
    ('recipe_pulse_ring_basic', 'component_pulse_ring', 1, 60, 0),
    ('recipe_thruster_basic', 'component_thruster_cluster', 1, 50, 0),
    ('recipe_repair_mesh_basic', 'component_repair_mesh', 1, 30, 0),
    ('recipe_pressure_stock_basic', 'material_pressure_stock', 3, 40, 0),
    ('recipe_feather_alloy_basic', 'material_feather_alloy', 4, 80, 0),
    ('recipe_thermal_focus_basic', 'component_thermal_focus', 1, 80, 0),
    ('recipe_ammo', 'ammo_kinetic_slug_i', 100, 30, 0),
    ('recipe_repair_kit', 'repair_kit_i', 1, 10, 0),
    ('recipe_kinetic_needle_i', 'module_kinetic_needle_i', 1, 100, 0),
    ('recipe_thermal_sunline_i', 'module_thermal_sunline_i', 1, 150, 0),
    ('recipe_pulse_breakwater_i', 'module_pulse_breakwater_i', 1, 120, 0),
    ('recipe_shield_lattice_i', 'module_shield_lattice_i', 1, 80, 0),
    ('recipe_armor_pressure_i', 'module_armor_pressure_i', 1, 100, 0),
    ('recipe_armor_feather_i', 'module_armor_feather_i', 1, 100, 0),
    ('recipe_engine_vector_i', 'module_engine_vector_i', 1, 100, 0),
    ('recipe_scanner_beacon_i', 'module_scanner_beacon_i', 1, 100, 0),
    ('recipe_industry_sift_i', 'module_industry_sift_i', 1, 150, 0),
    ('recipe_support_patch_i', 'module_support_patch_i', 1, 150, 0);

INSERT INTO recipe_inputs (recipe_id, item_id, quantity) VALUES
    ('recipe_structural', 'ore_ferrosilicate', 5),
    ('recipe_conductive', 'ore_conductive_crystal', 4),
    ('recipe_dense', 'ore_ferrosilicate', 10),
    ('recipe_dense', 'ore_conductive_crystal', 3),
    ('recipe_weapon_frame', 'material_dense_alloy', 2),
    ('recipe_weapon_frame', 'material_structural_stock', 4),
    ('recipe_power_cell', 'material_conductive_medium', 2),
    ('recipe_power_cell', 'material_structural_stock', 2),
    ('recipe_fire_control', 'material_structural_stock', 2),
    ('recipe_fire_control', 'material_conductive_medium', 1),
    ('recipe_scan_frame', 'material_structural_stock', 3),
    ('recipe_scan_frame', 'material_dense_alloy', 1),
    ('recipe_industry_control', 'material_structural_stock', 3),
    ('recipe_industry_control', 'material_conductive_medium', 2),
    ('recipe_projection_control', 'material_structural_stock', 2),
    ('recipe_projection_control', 'material_conductive_medium', 2),
    ('recipe_sensor_core_basic', 'material_conductive_medium', 2),
    ('recipe_sensor_core_basic', 'material_structural_stock', 1),
    ('recipe_pulse_ring_basic', 'material_conductive_medium', 4),
    ('recipe_pulse_ring_basic', 'component_power_cell', 1),
    ('recipe_thruster_basic', 'material_structural_stock', 8),
    ('recipe_thruster_basic', 'component_power_cell', 1),
    ('recipe_repair_mesh_basic', 'material_structural_stock', 4),
    ('recipe_repair_mesh_basic', 'material_conductive_medium', 1),
    ('recipe_pressure_stock_basic', 'material_dense_alloy', 1),
    ('recipe_pressure_stock_basic', 'material_structural_stock', 4),
    ('recipe_feather_alloy_basic', 'material_dense_alloy', 1),
    ('recipe_feather_alloy_basic', 'material_structural_stock', 6),
    ('recipe_thermal_focus_basic', 'material_dense_alloy', 2),
    ('recipe_thermal_focus_basic', 'material_conductive_medium', 3),
    ('recipe_ammo', 'ore_ferrosilicate', 10),
    ('recipe_repair_kit', 'material_structural_stock', 2),
    ('recipe_repair_kit', 'material_conductive_medium', 1),
    ('recipe_kinetic_needle_i', 'component_weapon_frame', 1),
    ('recipe_kinetic_needle_i', 'component_power_cell', 1),
    ('recipe_kinetic_needle_i', 'component_fire_control', 1),
    ('recipe_thermal_sunline_i', 'component_weapon_frame', 1),
    ('recipe_thermal_sunline_i', 'component_thermal_focus', 1),
    ('recipe_thermal_sunline_i', 'material_conductive_medium', 2),
    ('recipe_pulse_breakwater_i', 'component_weapon_frame', 1),
    ('recipe_pulse_breakwater_i', 'component_pulse_ring', 1),
    ('recipe_pulse_breakwater_i', 'component_power_cell', 1),
    ('recipe_shield_lattice_i', 'component_pulse_ring', 1),
    ('recipe_shield_lattice_i', 'component_power_cell', 2),
    ('recipe_shield_lattice_i', 'material_structural_stock', 2),
    ('recipe_armor_pressure_i', 'material_pressure_stock', 4),
    ('recipe_armor_pressure_i', 'material_dense_alloy', 1),
    ('recipe_armor_pressure_i', 'component_repair_mesh', 1),
    ('recipe_armor_feather_i', 'material_feather_alloy', 3),
    ('recipe_armor_feather_i', 'material_structural_stock', 2),
    ('recipe_armor_feather_i', 'component_repair_mesh', 1),
    ('recipe_engine_vector_i', 'component_thruster_cluster', 1),
    ('recipe_engine_vector_i', 'material_structural_stock', 4),
    ('recipe_engine_vector_i', 'material_conductive_medium', 2),
    ('recipe_scanner_beacon_i', 'component_sensor_core', 2),
    ('recipe_scanner_beacon_i', 'material_conductive_medium', 2),
    ('recipe_scanner_beacon_i', 'component_scan_frame', 1),
    ('recipe_industry_sift_i', 'material_dense_alloy', 2),
    ('recipe_industry_sift_i', 'component_power_cell', 1),
    ('recipe_industry_sift_i', 'component_industry_control', 1),
    ('recipe_support_patch_i', 'component_repair_mesh', 2),
    ('recipe_support_patch_i', 'component_power_cell', 1),
    ('recipe_support_patch_i', 'component_projection_control', 1);

INSERT INTO module_salvage_recipe_defs (module_id, recipe_id)
SELECT m.module_id, r.recipe_id FROM module_defs AS m
JOIN recipe_defs AS r ON r.output_item_id = m.module_id;

INSERT INTO recycle_outputs (source_item_id, output_item_id, quantity) VALUES
    ('module_thermal_sunline_i', 'material_conductive_medium', 1),
    ('module_shield_lattice_i', 'component_power_cell', 1),
    ('module_shield_lattice_i', 'material_structural_stock', 1),
    ('module_armor_pressure_i', 'material_pressure_stock', 2),
    ('module_armor_feather_i', 'material_feather_alloy', 1),
    ('module_armor_feather_i', 'material_structural_stock', 1),
    ('module_engine_vector_i', 'material_structural_stock', 2),
    ('module_engine_vector_i', 'material_conductive_medium', 1),
    ('module_scanner_beacon_i', 'component_sensor_core', 1),
    ('module_scanner_beacon_i', 'material_conductive_medium', 1),
    ('module_industry_sift_i', 'material_dense_alloy', 1),
    ('module_support_patch_i', 'component_repair_mesh', 1);

INSERT INTO asset_policy_defs (policy_id, may_sell, may_recycle, inherit_to_attached, inherit_to_supplies) VALUES
    ('normal_owned', 1, 1, 0, 0),
    ('tutorial_protected', 0, 0, 1, 1);

INSERT INTO starting_profile_defs (profile_template_id, currency_id, starting_credit) VALUES
    ('profile_tutorial', 'currency_route_credit', 5000);

INSERT INTO starting_inventory (profile_template_id, item_id, quantity) VALUES
    ('profile_tutorial', 'ore_ferrosilicate', 200),
    ('profile_tutorial', 'ore_conductive_crystal', 80),
    ('profile_tutorial', 'material_dense_alloy', 5),
    ('profile_tutorial', 'component_relic', 0);

INSERT INTO tutorial_step_defs (step_id, stage_code, step_order, prerequisite_step_id, action_kind, reward_credit, required_item_id, required_quantity, target_npc_id) VALUES
    ('tutorial_flight', 'T0', 0, NULL, 'flight', 800, NULL, NULL, NULL),
    ('tutorial_scan_gate', 'T1', 1, 'tutorial_flight', 'basic_scan', 1200, NULL, NULL, NULL),
    ('tutorial_mining_delivery', 'T2', 2, 'tutorial_scan_gate', 'mining_delivery', 3500, 'ore_ferrosilicate', 150, NULL),
    ('tutorial_combat', 'T3', 3, 'tutorial_mining_delivery', 'combat', 2000, NULL, NULL, 'npc_scout_light_l1'),
    ('tutorial_exploration', 'T4', 4, 'tutorial_combat', 'independent_exploration', 2000, NULL, NULL, NULL);

INSERT INTO starting_ships (profile_template_id, loadout_id, grant_kind, policy_id, available_at_step_id) VALUES
    ('profile_tutorial', 'loadout_shuttle_swift', 'owned', 'tutorial_protected', NULL),
    ('profile_tutorial', 'loadout_miner_anvil', 'loan', 'tutorial_protected', 'tutorial_mining_delivery'),
    ('profile_tutorial', 'loadout_frigate_kestrel', 'loan', 'tutorial_protected', 'tutorial_combat'),
    ('profile_tutorial', 'loadout_frigate_lantern', 'loan', 'tutorial_protected', 'tutorial_exploration');

INSERT INTO loadout_supply_defs (loadout_id, item_id, quantity) VALUES
    ('loadout_shuttle_swift', 'ammo_kinetic_slug_i', 120),
    ('loadout_frigate_lantern', 'ammo_kinetic_slug_i', 120),
    ('loadout_frigate_kestrel', 'ammo_kinetic_slug_i', 240),
    ('loadout_miner_anvil', 'ammo_kinetic_slug_i', 120);

INSERT INTO npc_loot_defs (archetype_id, item_id, quantity) VALUES
    ('npc_scout_light', 'ore_ferrosilicate', 5),
    ('npc_raider_medium', 'ore_ferrosilicate', 15),
    ('npc_raider_medium', 'ore_conductive_crystal', 3),
    ('npc_guardian_heavy', 'material_dense_alloy', 1),
    ('npc_guardian_heavy', 'component_relic', 1);

INSERT INTO rule_parameters (parameter_id, value_integer, value_real, unit) VALUES
    ('cruise_speed_multiplier', NULL, 3, 'multiplier'),
    ('cruise_energy_eu_s', NULL, 4, 'EU/s'),
    ('cruise_heat_hu_s', NULL, 3, 'HU/s'),
    ('station_armor_credit_per_hp', 1, NULL, 'credit/HP'),
    ('station_hull_credit_per_hp', 2, NULL, 'credit/HP'),
    ('station_hull_hp_per_structural_unit', 100, NULL, 'HP/unit'),
    ('station_module_credit_per_durability', 1, NULL, 'credit/point'),
    ('station_shield_restore_credit', 0, NULL, 'credit'),
    ('station_energy_restore_credit', 0, NULL, 'credit'),
    ('station_stock_refresh_s', NULL, 300, 's');

INSERT INTO combat_benchmark_defs (benchmark_id, loadout_id, npc_id, player_can_win) VALUES
    ('benchmark_raider_l3', 'loadout_frigate_kestrel', 'npc_raider_medium_l3', 1),
    ('benchmark_guardian_l6', 'loadout_frigate_kestrel', 'npc_guardian_heavy_l6', 0);

-- 以下为 B 内容包，不改 v0.2-baseline 的船/模块/物价/伤害量值。
INSERT INTO faction_defs VALUES
 ('faction_route_council','航路议会'), ('faction_deepforge','深铸联合体'),
 ('faction_roaming_alliance','游弋同盟'), ('faction_silent_relics','静默遗构');
INSERT INTO unlock_defs VALUES
 ('unlock_basic_services','基础站点与市场',1),
 ('unlock_tutorial_scan','教学扫描',0),
 ('unlock_anchor_echo_gate','锚港—回声门校准',0),
 ('unlock_mining_loan','采矿教学借船',0),
 ('unlock_miner_purchase','铁砧购买',0),
 ('unlock_mining_equipment','基础工业装备',0),
 ('unlock_combat_loan','战斗教学借船',0),
 ('unlock_contracts_mining','普通采矿合同',0),
 ('unlock_basic_industry','基础加工制造',0),
 ('unlock_kestrel_purchase','游隼购买',0),
 ('unlock_combat_equipment','常规战斗装备',0),
 ('unlock_combat_contracts','普通战斗合同',0),
 ('unlock_exploration_loan','探索教学借船',0),
 ('unlock_lantern_purchase','提灯购买',0),
 ('unlock_exploration_equipment','探索与支援装备',0),
 ('unlock_exploration_contracts','普通探索合同',0);
INSERT INTO sector_runtime_defs VALUES
 ('sector_anchor','scene_sector_anchor',1,'B',10000),
 ('sector_echo','scene_sector_echo',1,'B',10000);

INSERT INTO anchor_defs VALUES
 ('anchor_anchor_station','sector_anchor','station',0,0,0,0,600,1000),
 ('anchor_anchor_undock','sector_anchor','undock',0,0,-650,0,50,0),
 ('anchor_anchor_flight_forward','sector_anchor','flight_marker',0,0,-1400,0,80,0),
 ('anchor_anchor_flight_turn','sector_anchor','flight_marker',800,100,-1400,0,80,0),
 ('anchor_anchor_beacon','sector_anchor','signal',400,80,-1600,0,50,0),
 ('anchor_anchor_gate_entry','sector_anchor','gate_entry',0,0,-3200,0,120,800),
 ('anchor_anchor_gate_exit','sector_anchor','gate_exit',0,0,-2900,3.141592653589793,50,0),
 ('anchor_anchor_tutorial_scout','sector_anchor','npc_spawn',2400,0,-2400,0,50,0),
 ('anchor_anchor_tutorial_patrol_0','sector_anchor','patrol',2300,0,-2500,0,40,0),
 ('anchor_anchor_tutorial_patrol_1','sector_anchor','patrol',2500,0,-2300,0,40,0),
 ('anchor_echo_station','sector_echo','station',0,0,0,0,600,1000),
 ('anchor_echo_undock','sector_echo','undock',0,0,-650,0,50,0),
 ('anchor_echo_gate_entry','sector_echo','gate_entry',0,0,3000,3.141592653589793,120,800),
 ('anchor_echo_gate_exit','sector_echo','gate_exit',0,0,2700,0,50,0),
 ('anchor_echo_ferrosilicate','sector_echo','resource',1000,0,-1800,0,180,300),
 ('anchor_echo_conductive','sector_echo','resource',-800,100,-1700,0,180,300),
 ('anchor_echo_common_survey','sector_echo','signal',-1600,400,-2400,0,50,0),
 ('anchor_echo_contract_survey','sector_echo','signal',-2400,200,-1700,0,50,0),
 ('anchor_echo_contract_scout','sector_echo','npc_spawn',3400,0,-3200,0,50,0),
 ('anchor_echo_contract_patrol_0','sector_echo','patrol',3200,0,-3200,0,40,0),
 ('anchor_echo_contract_patrol_1','sector_echo','patrol',3600,0,-3400,0,40,0),
 ('anchor_echo_raider','sector_echo','npc_spawn',5200,300,-4500,0,50,0),
 ('anchor_echo_raider_patrol_0','sector_echo','patrol',4900,300,-4400,0,40,0),
 ('anchor_echo_raider_patrol_1','sector_echo','patrol',5400,300,-4800,0,40,0);
INSERT INTO station_defs VALUES
 ('station_anchor_port','锚港主站','sector_anchor','faction_route_council','anchor_anchor_station','anchor_anchor_undock',300,100000),
 ('station_echo_depot','回声补给站','sector_echo','faction_route_council','anchor_echo_station','anchor_echo_undock',300,40000);
INSERT INTO service_defs VALUES
 ('warehouse','本地仓库'),('repair','装甲结构维修'),('recharge','护盾电容补充'),
 ('trade','物品交易'),('ship_purchase','裸舰购买'),('fitting','停靠配装'),
 ('manufacture','加工制造'),('recycle','正常模块拆解'),('mission_board','任务合同'),('loan','教学与合同借船');
INSERT INTO station_service_defs VALUES
 ('station_anchor_port','warehouse','unlock_basic_services'),
 ('station_anchor_port','repair','unlock_basic_services'),
 ('station_anchor_port','recharge','unlock_basic_services'),
 ('station_anchor_port','trade','unlock_basic_services'),
 ('station_anchor_port','ship_purchase','unlock_basic_services'),
 ('station_anchor_port','fitting','unlock_basic_services'),
 ('station_anchor_port','manufacture','unlock_basic_industry'),
 ('station_anchor_port','recycle','unlock_basic_industry'),
 ('station_anchor_port','mission_board','unlock_basic_services'),
 ('station_anchor_port','loan','unlock_basic_services'),
 ('station_echo_depot','warehouse','unlock_basic_services'),
 ('station_echo_depot','repair','unlock_basic_services'),
 ('station_echo_depot','recharge','unlock_basic_services'),
 ('station_echo_depot','trade','unlock_basic_services'),
 ('station_echo_depot','fitting','unlock_basic_services');

-- 同价交易；库存定义单位是整数件，NPC 收购也受当期预算和上限限制。
INSERT INTO station_stock_defs VALUES
 ('station_anchor_port','ore_ferrosilicate','unlock_basic_services',2000,2000,4000,500,1500,1,1),
 ('station_anchor_port','ore_conductive_crystal','unlock_basic_services',600,600,1200,150,400,1,1),
 ('station_anchor_port','material_dense_alloy','unlock_basic_services',60,60,120,15,40,1,1),
 ('station_anchor_port','component_relic','unlock_exploration_equipment',10,10,30,5,10,1,1),
 ('station_anchor_port','ammo_kinetic_slug_i','unlock_basic_services',3000,3000,6000,600,1200,1,1),
 ('station_anchor_port','repair_kit_i','unlock_basic_services',40,40,80,10,20,1,1),
 ('station_anchor_port','material_structural_stock','unlock_basic_services',200,200,400,50,100,1,1),
 ('station_anchor_port','material_conductive_medium','unlock_basic_services',100,100,200,25,50,1,1),
 ('station_anchor_port','component_weapon_frame','unlock_basic_industry',20,20,40,5,10,1,1),
 ('station_anchor_port','component_power_cell','unlock_basic_industry',40,40,80,10,20,1,1),
 ('station_anchor_port','component_fire_control','unlock_basic_industry',20,20,40,5,10,1,1),
 ('station_anchor_port','component_scan_frame','unlock_basic_industry',20,20,40,5,10,1,1),
 ('station_anchor_port','component_industry_control','unlock_basic_industry',20,20,40,5,10,1,1),
 ('station_anchor_port','component_projection_control','unlock_basic_industry',20,20,40,5,10,1,1),
 ('station_anchor_port','component_sensor_core','unlock_basic_industry',30,30,60,10,15,1,1),
 ('station_anchor_port','component_pulse_ring','unlock_basic_industry',20,20,40,5,10,1,1),
 ('station_anchor_port','component_thruster_cluster','unlock_basic_industry',20,20,40,5,10,1,1),
 ('station_anchor_port','component_repair_mesh','unlock_basic_industry',30,30,60,10,15,1,1),
 ('station_anchor_port','material_pressure_stock','unlock_basic_industry',80,80,160,20,40,1,1),
 ('station_anchor_port','material_feather_alloy','unlock_basic_industry',80,80,160,20,40,1,1),
 ('station_anchor_port','component_thermal_focus','unlock_basic_industry',20,20,40,5,10,1,1),
 ('station_anchor_port','module_kinetic_needle_i','unlock_basic_services',8,8,16,2,4,1,1),
 ('station_anchor_port','module_engine_vector_i','unlock_basic_services',8,8,16,2,4,1,1),
 ('station_anchor_port','module_shield_lattice_i','unlock_mining_equipment',8,8,16,2,4,1,1),
 ('station_anchor_port','module_industry_sift_i','unlock_mining_equipment',8,8,16,2,4,1,1),
 ('station_anchor_port','module_armor_pressure_i','unlock_combat_equipment',4,4,8,1,2,1,1),
 ('station_anchor_port','module_pulse_breakwater_i','unlock_combat_equipment',4,4,8,1,2,1,1),
 ('station_anchor_port','module_thermal_sunline_i','unlock_combat_equipment',4,4,8,1,2,1,1),
 ('station_anchor_port','module_scanner_beacon_i','unlock_exploration_equipment',8,8,16,2,4,1,1),
 ('station_anchor_port','module_armor_feather_i','unlock_exploration_equipment',4,4,8,1,2,1,1),
 ('station_anchor_port','module_support_patch_i','unlock_exploration_equipment',4,4,8,1,2,1,1),
 ('station_echo_depot','ore_ferrosilicate','unlock_basic_services',500,500,3000,125,1500,1,1),
 ('station_echo_depot','ore_conductive_crystal','unlock_basic_services',200,200,1000,50,400,1,1),
 ('station_echo_depot','ammo_kinetic_slug_i','unlock_basic_services',1000,1000,3000,250,800,1,1),
 ('station_echo_depot','repair_kit_i','unlock_basic_services',15,15,40,5,10,1,1),
 ('station_echo_depot','material_structural_stock','unlock_basic_services',50,50,200,20,50,1,1),
 ('station_echo_depot','module_kinetic_needle_i','unlock_basic_services',2,2,6,1,2,1,1);
INSERT INTO station_ship_stock_defs VALUES
 ('station_anchor_port','shuttle_swift','unlock_basic_services',1,2,3,1),
 ('station_anchor_port','miner_anvil','unlock_miner_purchase',1,2,3,1),
 ('station_anchor_port','frigate_kestrel','unlock_kestrel_purchase',1,2,3,1),
 ('station_anchor_port','frigate_lantern','unlock_lantern_purchase',1,2,3,1);
INSERT INTO recipe_access_defs
SELECT recipe_id, 'station_anchor_port', CASE
 WHEN output_item_id IN ('module_scanner_beacon_i','module_armor_feather_i','module_support_patch_i') THEN 'unlock_exploration_equipment'
 WHEN output_item_id IN ('module_thermal_sunline_i','module_pulse_breakwater_i','module_armor_pressure_i') THEN 'unlock_combat_equipment'
 ELSE 'unlock_basic_industry' END FROM recipe_defs;
INSERT INTO gate_endpoint_defs VALUES
 ('endpoint_anchor_echo','conn_anchor_echo','sector_anchor','sector_echo','anchor_anchor_gate_entry','anchor_echo_gate_exit','unlock_anchor_echo_gate'),
 ('endpoint_echo_anchor','conn_anchor_echo','sector_echo','sector_anchor','anchor_echo_gate_entry','anchor_anchor_gate_exit','unlock_anchor_echo_gate');
INSERT INTO signal_defs VALUES
 ('signal_anchor_gate_calibration','航门校准航标','anchor_anchor_beacon',1,80,'unlock_tutorial_scan','fixed',1),
 ('signal_echo_common_survey','回声普通航路信号','anchor_echo_common_survey',1,300,'unlock_exploration_loan','mission_scoped',1),
 ('signal_echo_contract_survey','回声合同测绘信号','anchor_echo_contract_survey',1,300,'unlock_exploration_contracts','mission_scoped',1);
INSERT INTO resource_node_locations VALUES
 ('node_echo_ferrosilicate','sector_echo','anchor_echo_ferrosilicate','unlock_anchor_echo_gate'),
 ('node_echo_conductive','sector_echo','anchor_echo_conductive','unlock_anchor_echo_gate');
INSERT INTO npc_behavior_defs VALUES
 ('behavior_scout','npc_scout_light',800,1200,1000,0.7,4,0.6,40,2,20,1,1,0.20943951023931956,'projectile',1200),
 ('behavior_raider','npc_raider_medium',1100,1600,2200,0.75,5,0.4,50,1,14,0.6,1.2,0.17453292519943295,'projectile',1000),
 ('behavior_guardian','npc_guardian_heavy',1400,1900,2400,0.8,6,1,60,3,8,0.35,1.5,0.2617993877991494,'ray',NULL);
INSERT INTO npc_defs VALUES
 ('npc_scout_light_l2_high','npc_scout_light',2,'risk_high'),
 ('npc_raider_medium_l3_high','npc_raider_medium',3,'risk_high');
INSERT INTO npc_spawn_defs VALUES
 ('spawn_anchor_tutorial_scout','npc_scout_light_l1','sector_anchor','anchor_anchor_tutorial_scout','behavior_scout','mission_scoped','unlock_combat_loan',NULL,0,0),
 ('spawn_echo_contract_scout','npc_scout_light_l2_high','sector_echo','anchor_echo_contract_scout','behavior_scout','mission_scoped','unlock_combat_contracts',NULL,1,1),
 ('spawn_echo_raider','npc_raider_medium_l3_high','sector_echo','anchor_echo_raider','behavior_raider','ambient','unlock_exploration_contracts',600,1,1);
INSERT INTO npc_patrol_points VALUES
 ('spawn_anchor_tutorial_scout',0,'anchor_anchor_tutorial_patrol_0'),
 ('spawn_anchor_tutorial_scout',1,'anchor_anchor_tutorial_patrol_1'),
 ('spawn_echo_contract_scout',0,'anchor_echo_contract_patrol_0'),
 ('spawn_echo_contract_scout',1,'anchor_echo_contract_patrol_1'),
 ('spawn_echo_raider',0,'anchor_echo_raider_patrol_0'),
 ('spawn_echo_raider',1,'anchor_echo_raider_patrol_1');
INSERT INTO mission_instance_states VALUES
 ('locked',0),('available',0),('active',0),('ready',0),('completed',1),('cooldown',0),('failed',1),('abandoned',1);
INSERT INTO mission_defs VALUES
 ('tutorial_flight','T0 出航准备','tutorial','tutorial_flight','station_anchor_port','station_anchor_port','unlock_basic_services',0,0,0,1,1,NULL,1),
 ('tutorial_scan_gate','T1 航标识别','tutorial','tutorial_scan_gate','station_anchor_port','station_anchor_port','unlock_tutorial_scan',0,0,0,1,1,NULL,1),
 ('tutorial_mining_delivery','T2 资源试采','tutorial','tutorial_mining_delivery','station_anchor_port','station_anchor_port','unlock_mining_loan',0,0,0,1,1,NULL,1),
 ('tutorial_combat','T3 配装与战斗','tutorial','tutorial_combat','station_anchor_port','station_anchor_port','unlock_combat_loan',0,0,0,1,1,NULL,1),
 ('tutorial_exploration','T4 独立探索','tutorial','tutorial_exploration','station_anchor_port','station_anchor_port','unlock_exploration_loan',0,0,0,1,1,NULL,1),
 ('contract_mining_iron','回声铁硅采集合同','contract',NULL,'station_anchor_port','station_anchor_port','unlock_contracts_mining',1,300,1800,3,1,1800,1),
 ('contract_survey_echo','回声航路测绘合同','contract',NULL,'station_anchor_port','station_anchor_port','unlock_exploration_contracts',1,300,1800,3,1,1800,1),
 ('contract_patrol_echo','回声威胁清理合同','contract',NULL,'station_anchor_port','station_anchor_port','unlock_combat_contracts',1,300,1800,3,1,1800,1);
INSERT INTO mission_prerequisites VALUES
 ('tutorial_scan_gate','tutorial_flight'),('tutorial_mining_delivery','tutorial_scan_gate'),
 ('tutorial_combat','tutorial_mining_delivery'),('tutorial_exploration','tutorial_combat'),
 ('contract_mining_iron','tutorial_mining_delivery'),('contract_survey_echo','tutorial_exploration'),
 ('contract_patrol_echo','tutorial_combat');
INSERT INTO asset_policy_defs VALUES ('mission_bound',0,0,0,0);
INSERT INTO loan_service_defs VALUES
 ('loan_tutorial_miner','station_anchor_port','station_anchor_port','loadout_miner_anvil','tutorial_protected','unlock_mining_loan','tutorial_mining_delivery',0,1,1,0,150,'mission_bound',1,1),
 ('loan_tutorial_kestrel','station_anchor_port','station_anchor_port','loadout_frigate_kestrel','tutorial_protected','unlock_combat_loan','tutorial_combat',0,1,1,0,NULL,'normal_owned',1,1),
 ('loan_tutorial_lantern','station_anchor_port','station_anchor_port','loadout_frigate_lantern','tutorial_protected','unlock_exploration_loan','tutorial_exploration',0,1,1,0,NULL,'normal_owned',1,1),
 ('loan_contract_miner','station_anchor_port','station_anchor_port','loadout_miner_anvil','tutorial_protected','unlock_contracts_mining','contract_mining_iron',0,1,1,30,600,'normal_owned',1,1),
 ('loan_contract_kestrel','station_anchor_port','station_anchor_port','loadout_frigate_kestrel','tutorial_protected','unlock_combat_contracts','contract_patrol_echo',0,1,1,30,NULL,'normal_owned',1,1),
 ('loan_contract_lantern','station_anchor_port','station_anchor_port','loadout_frigate_lantern','tutorial_protected','unlock_exploration_contracts','contract_survey_echo',0,1,1,30,NULL,'normal_owned',1,1);

INSERT INTO mission_objective_defs
(mission_id,objective_index,objective_kind,required_count,target_anchor_id,target_station_id,target_signal_id,target_node_id,target_spawn_id,target_connection_id,target_item_id,target_loan_service_id,max_speed_mps,hold_s,consume_item) VALUES
 ('tutorial_flight',0,'undock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_flight',1,'reach_anchor',1,'anchor_anchor_flight_forward',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_flight',2,'brake_at_anchor',1,'anchor_anchor_flight_forward',NULL,NULL,NULL,NULL,NULL,NULL,NULL,20,2,0),
 ('tutorial_flight',3,'reach_anchor',1,'anchor_anchor_flight_turn',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_flight',4,'dock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_scan_gate',0,'scan_signal',1,NULL,NULL,'signal_anchor_gate_calibration',NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_scan_gate',1,'dock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_mining_delivery',0,'loan_checkout',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'loan_tutorial_miner',NULL,0,0),
 ('tutorial_mining_delivery',1,'transit_connection',1,NULL,NULL,NULL,NULL,NULL,'conn_anchor_echo',NULL,NULL,NULL,0,0),
 ('tutorial_mining_delivery',2,'collect',150,NULL,NULL,NULL,'node_echo_ferrosilicate',NULL,NULL,'ore_ferrosilicate',NULL,NULL,0,0),
 ('tutorial_mining_delivery',3,'dock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_mining_delivery',4,'deliver',150,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,'ore_ferrosilicate',NULL,NULL,0,1),
 ('tutorial_combat',0,'loan_checkout',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'loan_tutorial_kestrel',NULL,0,0),
 ('tutorial_combat',1,'fit_validate',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'loan_tutorial_kestrel',NULL,0,0),
 ('tutorial_combat',2,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_anchor_tutorial_scout',NULL,NULL,NULL,NULL,0,0),
 ('tutorial_combat',3,'dock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_exploration',0,'loan_checkout',1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'loan_tutorial_lantern',NULL,0,0),
 ('tutorial_exploration',1,'scan_signal',1,NULL,NULL,'signal_echo_common_survey',NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('tutorial_exploration',2,'dock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('contract_mining_iron',0,'collect',300,NULL,NULL,NULL,'node_echo_ferrosilicate',NULL,NULL,'ore_ferrosilicate',NULL,NULL,0,0),
 ('contract_mining_iron',1,'dock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('contract_mining_iron',2,'deliver',300,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,'ore_ferrosilicate',NULL,NULL,0,1),
 ('contract_survey_echo',0,'scan_signal',1,NULL,NULL,'signal_echo_contract_survey',NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('contract_survey_echo',1,'dock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0),
 ('contract_patrol_echo',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_echo_contract_scout',NULL,NULL,NULL,NULL,0,0),
 ('contract_patrol_echo',1,'dock',1,NULL,'station_anchor_port',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_reward_defs
 SELECT step_id,'currency_route_credit',reward_credit FROM tutorial_step_defs;
INSERT INTO mission_reward_defs VALUES
 ('contract_mining_iron','currency_route_credit',3000),
 ('contract_survey_echo','currency_route_credit',2000),
 ('contract_patrol_echo','currency_route_credit',2500);
INSERT INTO mission_unlock_rewards VALUES
 ('tutorial_flight','unlock_tutorial_scan'),
 ('tutorial_scan_gate','unlock_anchor_echo_gate'),('tutorial_scan_gate','unlock_mining_loan'),
 ('tutorial_mining_delivery','unlock_miner_purchase'),('tutorial_mining_delivery','unlock_mining_equipment'),
 ('tutorial_mining_delivery','unlock_combat_loan'),('tutorial_mining_delivery','unlock_contracts_mining'),
 ('tutorial_mining_delivery','unlock_basic_industry'),
 ('tutorial_combat','unlock_kestrel_purchase'),('tutorial_combat','unlock_combat_equipment'),
 ('tutorial_combat','unlock_combat_contracts'),('tutorial_combat','unlock_exploration_loan'),
 ('tutorial_exploration','unlock_lantern_purchase'),('tutorial_exploration','unlock_exploration_equipment'),
 ('tutorial_exploration','unlock_exploration_contracts');
INSERT INTO mission_state_transitions VALUES
 ('locked','prerequisites_met','available','prerequisites'),
 ('available','accept','active','eligible'),
 ('active','objectives_met','ready','all_objectives'),
 ('ready','claim','completed','turnin_atomic'),
 ('active','fail','failed','active_failure'),('ready','fail','failed','active_failure'),
 ('active','abandon','abandoned','cleanup_loan'),('ready','abandon','abandoned','cleanup_loan'),
 ('failed','retry','available','retry_eligible'),('abandoned','retry','available','retry_eligible'),
 ('completed','repeat_wait','cooldown','repeatable'),
 ('cooldown','cooldown_elapsed','available','repeat_budget');
INSERT INTO starting_inventory_policy_defs
 SELECT profile_template_id,item_id,'normal_owned' FROM starting_inventory;

INSERT INTO rule_parameters VALUES
 ('mission_global_active_contract_limit',1,NULL,'contract'),
 ('mission_global_active_total_limit',1,NULL,'mission'),
 ('loan_global_active_limit',1,NULL,'loan'),
 ('loan_supply_topup_at_return',0,NULL,'boolean'),
 ('npc_safe_zone_attack_enabled',0,NULL,'boolean'),
 ('npc_return_healing_enabled',0,NULL,'boolean'),
 ('player_weapon_fire_cone_half_angle_rad',NULL,0.5235987755982988,'rad'),
 ('target_marker_detection_range_m',NULL,6000,'m'),
 ('mission_expiry_warning_s',NULL,120,'world_s'),
 ('contract_failure_retry_cooldown_s',NULL,60,'world_s');
INSERT INTO rule_parameters VALUES ('contract_max_accepts_per_window',3,NULL,'attempt');

INSERT INTO camera_profile_defs VALUES
 ('camera_swift_follow','shuttle_swift','follow',65,55,14,12,0.2,12000,33,137.5,0.18,0.12,0.5),
 ('camera_swift_front','shuttle_swift','front',75,0,0,0,0.2,12000,0,0,0.18,0.12,0.5),
 ('camera_swift_tactical','shuttle_swift','tactical',55,90,110,0,0.2,12000,67.5,180,0.18,0.12,0.5),
 ('camera_lantern_follow','frigate_lantern','follow',65,75,18,18,0.2,12000,45,187.5,0.18,0.12,0.5),
 ('camera_lantern_front','frigate_lantern','front',75,0,0,0,0.2,12000,0,0,0.18,0.12,0.5),
 ('camera_lantern_tactical','frigate_lantern','tactical',55,120,150,0,0.2,12000,90,240,0.18,0.12,0.5),
 ('camera_kestrel_follow','frigate_kestrel','follow',65,80,20,18,0.2,12000,48,200,0.18,0.12,0.5),
 ('camera_kestrel_front','frigate_kestrel','front',75,0,0,0,0.2,12000,0,0,0.18,0.12,0.5),
 ('camera_kestrel_tactical','frigate_kestrel','tactical',55,130,160,0,0.2,12000,97.5,260,0.18,0.12,0.5),
 ('camera_anvil_follow','miner_anvil','follow',65,140,34,25,0.2,12000,84,350,0.18,0.12,0.5),
 ('camera_anvil_front','miner_anvil','front',75,0,0,0,0.2,12000,0,0,0.18,0.12,0.5),
 ('camera_anvil_tactical','miner_anvil','tactical',55,210,260,0,0.2,12000,157.5,420,0.18,0.12,0.5);
INSERT INTO presentation_defs VALUES
 ('render_target_fps',60,NULL,'fps'),('render_reference_width_px',1920,NULL,'px'),('render_reference_height_px',1080,NULL,'px'),
 ('lod_near_m',NULL,300,'m'),('lod_mid_m',NULL,1000,'m'),('lod_far_m',NULL,3000,'m'),
 ('engine_particles_near',64,NULL,'particles'),('engine_particles_mid',24,NULL,'particles'),
 ('explosion_particles_near',192,NULL,'particles'),('explosion_particles_mid',48,NULL,'particles'),
 ('trail_particles_near',16,NULL,'particles'),('trail_particles_mid',8,NULL,'particles'),
 ('fx_active_instances_max',64,NULL,'instances'),('fx_particle_budget_max',4096,NULL,'particles'),
 ('fx_dynamic_lights_max',4,NULL,'lights'),('fx_shield_hits_per_ship_max',2,NULL,'instances'),
 ('audio_master_db',NULL,-6,'dB'),('audio_music_db',NULL,-18,'dB'),('audio_sfx_db',NULL,-9,'dB'),('audio_ui_db',NULL,-6,'dB'),
 ('audio_voice_limit',24,NULL,'voices'),('hud_target_markers_max',24,NULL,'markers'),('hud_offscreen_markers_max',8,NULL,'markers');
