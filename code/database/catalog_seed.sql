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

-- Complete singleplayer catalog v0.4; original four-ship numeric baseline retained.
INSERT INTO unlock_defs VALUES ('unlock_open_routes','完整星域航路许可',0);
INSERT INTO mission_unlock_rewards VALUES ('tutorial_exploration','unlock_open_routes');
INSERT INTO unlock_defs VALUES ('unlock_tech_ii','专业代际 II',0);
INSERT INTO unlock_defs VALUES ('unlock_tech_iii','遗构代际 III',0);
INSERT INTO unlock_defs VALUES ('unlock_hulls_advanced','高级舰体工艺',0);
INSERT INTO unlock_defs VALUES ('unlock_base_services','个人站点设施',0);
INSERT INTO ship_defs VALUES ('destroyer_raptor','矛隼级驱逐舰',420000,40000,18000,190,15,0.7,500,400,600,650,24,240,20,4,30000,0,360,240,12,1,60000,18000);
INSERT INTO ship_slot_capacity VALUES ('destroyer_raptor','weapon',3);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','weapon',0);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','weapon',1);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','weapon',2);
INSERT INTO ship_slot_capacity VALUES ('destroyer_raptor','work',0);
INSERT INTO ship_slot_capacity VALUES ('destroyer_raptor','utility',4);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','utility',0);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','utility',1);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','utility',2);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','utility',3);
INSERT INTO ship_slot_capacity VALUES ('destroyer_raptor','structure',2);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','structure',0);
INSERT INTO ship_slot_defs VALUES ('destroyer_raptor','structure',1);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','shield','kinetic',0.2);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','shield','thermal',0.1);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','shield','pulse',0.0);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','armor','kinetic',0.15);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','armor','thermal',0.15);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','armor','pulse',0.05);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','hull','kinetic',0.05);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','hull','thermal',0.05);
INSERT INTO ship_resistances VALUES ('destroyer_raptor','hull','pulse',0.05);
INSERT INTO ship_role_defs VALUES ('destroyer_raptor','destroyer','faction_deepforge','unlock_hulls_advanced');
INSERT INTO ship_loadout_defs VALUES ('loadout_destroyer_raptor','destroyer_raptor','矛隼级驱逐舰标准配装');
INSERT INTO ship_loadout_items VALUES ('loadout_destroyer_raptor','destroyer_raptor','weapon',0,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_destroyer_raptor','destroyer_raptor','weapon',1,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_destroyer_raptor','destroyer_raptor','weapon',2,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_destroyer_raptor','destroyer_raptor','utility',0,'module_engine_vector_i');
INSERT INTO ship_loadout_items VALUES ('loadout_destroyer_raptor','destroyer_raptor','utility',1,'module_shield_lattice_i');
INSERT INTO ship_loadout_items VALUES ('loadout_destroyer_raptor','destroyer_raptor','utility',2,'module_scanner_beacon_i');
INSERT INTO loadout_supply_defs VALUES ('loadout_destroyer_raptor','ammo_kinetic_slug_i',360);
INSERT INTO camera_profile_defs VALUES ('camera_destroyer_raptor_follow','destroyer_raptor','follow',65,140,45,25,0.2,16000,84.0,350.0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_destroyer_raptor_front','destroyer_raptor','front',75,0,0,0,0.2,16000,0.0,0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_destroyer_raptor_tactical','destroyer_raptor','tactical',55,220,280,0,0.2,16000,165.0,440,0.18,0.12,0.5);
INSERT INTO ship_defs VALUES ('cruiser_horizon','远际级巡洋舰',1800000,100000,150000,145,9,0.4,1200,950,1400,1100,45,400,34,8,150000,0,650,420,30,1.25,180000,54000);
INSERT INTO ship_slot_capacity VALUES ('cruiser_horizon','weapon',3);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','weapon',0);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','weapon',1);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','weapon',2);
INSERT INTO ship_slot_capacity VALUES ('cruiser_horizon','work',2);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','work',0);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','work',1);
INSERT INTO ship_slot_capacity VALUES ('cruiser_horizon','utility',5);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','utility',0);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','utility',1);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','utility',2);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','utility',3);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','utility',4);
INSERT INTO ship_slot_capacity VALUES ('cruiser_horizon','structure',3);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','structure',0);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','structure',1);
INSERT INTO ship_slot_defs VALUES ('cruiser_horizon','structure',2);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','shield','kinetic',0.2);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','shield','thermal',0.1);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','shield','pulse',0.0);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','armor','kinetic',0.15);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','armor','thermal',0.15);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','armor','pulse',0.05);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','hull','kinetic',0.05);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','hull','thermal',0.05);
INSERT INTO ship_resistances VALUES ('cruiser_horizon','hull','pulse',0.05);
INSERT INTO ship_role_defs VALUES ('cruiser_horizon','cruiser','faction_route_council','unlock_hulls_advanced');
INSERT INTO ship_loadout_defs VALUES ('loadout_cruiser_horizon','cruiser_horizon','远际级巡洋舰标准配装');
INSERT INTO ship_loadout_items VALUES ('loadout_cruiser_horizon','cruiser_horizon','weapon',0,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_cruiser_horizon','cruiser_horizon','weapon',1,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_cruiser_horizon','cruiser_horizon','weapon',2,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_cruiser_horizon','cruiser_horizon','utility',0,'module_engine_vector_i');
INSERT INTO ship_loadout_items VALUES ('loadout_cruiser_horizon','cruiser_horizon','utility',1,'module_shield_lattice_i');
INSERT INTO ship_loadout_items VALUES ('loadout_cruiser_horizon','cruiser_horizon','utility',2,'module_scanner_beacon_i');
INSERT INTO ship_loadout_items VALUES ('loadout_cruiser_horizon','cruiser_horizon','work',0,'module_industry_sift_i');
INSERT INTO loadout_supply_defs VALUES ('loadout_cruiser_horizon','ammo_kinetic_slug_i',360);
INSERT INTO camera_profile_defs VALUES ('camera_cruiser_horizon_follow','cruiser_horizon','follow',65,140,45,25,0.2,16000,84.0,350.0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_cruiser_horizon_front','cruiser_horizon','front',75,0,0,0,0.2,16000,0.0,0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_cruiser_horizon_tactical','cruiser_horizon','tactical',55,220,280,0,0.2,16000,165.0,440,0.18,0.12,0.5);
INSERT INTO ship_defs VALUES ('battleship_bastion','磐垒级战列舰',8000000,300000,800000,80,4,0.18,3200,4000,4800,2200,90,800,65,16,350000,0,1100,700,20,1,700000,210000);
INSERT INTO ship_slot_capacity VALUES ('battleship_bastion','weapon',6);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','weapon',0);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','weapon',1);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','weapon',2);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','weapon',3);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','weapon',4);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','weapon',5);
INSERT INTO ship_slot_capacity VALUES ('battleship_bastion','work',1);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','work',0);
INSERT INTO ship_slot_capacity VALUES ('battleship_bastion','utility',6);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','utility',0);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','utility',1);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','utility',2);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','utility',3);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','utility',4);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','utility',5);
INSERT INTO ship_slot_capacity VALUES ('battleship_bastion','structure',4);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','structure',0);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','structure',1);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','structure',2);
INSERT INTO ship_slot_defs VALUES ('battleship_bastion','structure',3);
INSERT INTO ship_resistances VALUES ('battleship_bastion','shield','kinetic',0.2);
INSERT INTO ship_resistances VALUES ('battleship_bastion','shield','thermal',0.1);
INSERT INTO ship_resistances VALUES ('battleship_bastion','shield','pulse',0.0);
INSERT INTO ship_resistances VALUES ('battleship_bastion','armor','kinetic',0.15);
INSERT INTO ship_resistances VALUES ('battleship_bastion','armor','thermal',0.15);
INSERT INTO ship_resistances VALUES ('battleship_bastion','armor','pulse',0.05);
INSERT INTO ship_resistances VALUES ('battleship_bastion','hull','kinetic',0.05);
INSERT INTO ship_resistances VALUES ('battleship_bastion','hull','thermal',0.05);
INSERT INTO ship_resistances VALUES ('battleship_bastion','hull','pulse',0.05);
INSERT INTO ship_role_defs VALUES ('battleship_bastion','battleship','faction_deepforge','unlock_hulls_advanced');
INSERT INTO ship_loadout_defs VALUES ('loadout_battleship_bastion','battleship_bastion','磐垒级战列舰标准配装');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','weapon',0,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','weapon',1,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','weapon',2,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','weapon',3,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','weapon',4,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','weapon',5,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','utility',0,'module_engine_vector_i');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','utility',1,'module_shield_lattice_i');
INSERT INTO ship_loadout_items VALUES ('loadout_battleship_bastion','battleship_bastion','utility',2,'module_scanner_beacon_i');
INSERT INTO loadout_supply_defs VALUES ('loadout_battleship_bastion','ammo_kinetic_slug_i',720);
INSERT INTO camera_profile_defs VALUES ('camera_battleship_bastion_follow','battleship_bastion','follow',65,200,45,25,0.2,16000,120.0,500.0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_battleship_bastion_front','battleship_bastion','front',75,0,0,0,0.2,16000,0.0,0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_battleship_bastion_tactical','battleship_bastion','tactical',55,300,280,0,0.2,16000,225.0,600,0.18,0.12,0.5);
INSERT INTO ship_defs VALUES ('transport_caravan','长旅级运输舰',1200000,70000,1200000,130,7,0.3,650,550,1100,750,24,280,20,5,1600000,0,350,260,14,1,85000,25500);
INSERT INTO ship_slot_capacity VALUES ('transport_caravan','weapon',1);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','weapon',0);
INSERT INTO ship_slot_capacity VALUES ('transport_caravan','work',1);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','work',0);
INSERT INTO ship_slot_capacity VALUES ('transport_caravan','utility',4);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','utility',0);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','utility',1);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','utility',2);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','utility',3);
INSERT INTO ship_slot_capacity VALUES ('transport_caravan','structure',3);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','structure',0);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','structure',1);
INSERT INTO ship_slot_defs VALUES ('transport_caravan','structure',2);
INSERT INTO ship_resistances VALUES ('transport_caravan','shield','kinetic',0.2);
INSERT INTO ship_resistances VALUES ('transport_caravan','shield','thermal',0.1);
INSERT INTO ship_resistances VALUES ('transport_caravan','shield','pulse',0.0);
INSERT INTO ship_resistances VALUES ('transport_caravan','armor','kinetic',0.15);
INSERT INTO ship_resistances VALUES ('transport_caravan','armor','thermal',0.15);
INSERT INTO ship_resistances VALUES ('transport_caravan','armor','pulse',0.05);
INSERT INTO ship_resistances VALUES ('transport_caravan','hull','kinetic',0.05);
INSERT INTO ship_resistances VALUES ('transport_caravan','hull','thermal',0.05);
INSERT INTO ship_resistances VALUES ('transport_caravan','hull','pulse',0.05);
INSERT INTO ship_role_defs VALUES ('transport_caravan','transport','faction_roaming_alliance','unlock_hulls_advanced');
INSERT INTO ship_loadout_defs VALUES ('loadout_transport_caravan','transport_caravan','长旅级运输舰标准配装');
INSERT INTO ship_loadout_items VALUES ('loadout_transport_caravan','transport_caravan','weapon',0,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_transport_caravan','transport_caravan','utility',0,'module_engine_vector_i');
INSERT INTO ship_loadout_items VALUES ('loadout_transport_caravan','transport_caravan','utility',1,'module_shield_lattice_i');
INSERT INTO ship_loadout_items VALUES ('loadout_transport_caravan','transport_caravan','utility',2,'module_scanner_beacon_i');
INSERT INTO loadout_supply_defs VALUES ('loadout_transport_caravan','ammo_kinetic_slug_i',120);
INSERT INTO camera_profile_defs VALUES ('camera_transport_caravan_follow','transport_caravan','follow',65,140,45,25,0.2,16000,84.0,350.0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_transport_caravan_front','transport_caravan','front',75,0,0,0,0.2,16000,0.0,0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_transport_caravan_tactical','transport_caravan','tactical',55,220,280,0,0.2,16000,165.0,440,0.18,0.12,0.5);
INSERT INTO ship_defs VALUES ('support_weaver','织桥级支援舰',1600000,90000,130000,150,10,0.5,1300,850,1200,1800,65,500,45,9,200000,0,650,480,26,1,160000,48000);
INSERT INTO ship_slot_capacity VALUES ('support_weaver','weapon',2);
INSERT INTO ship_slot_defs VALUES ('support_weaver','weapon',0);
INSERT INTO ship_slot_defs VALUES ('support_weaver','weapon',1);
INSERT INTO ship_slot_capacity VALUES ('support_weaver','work',3);
INSERT INTO ship_slot_defs VALUES ('support_weaver','work',0);
INSERT INTO ship_slot_defs VALUES ('support_weaver','work',1);
INSERT INTO ship_slot_defs VALUES ('support_weaver','work',2);
INSERT INTO ship_slot_capacity VALUES ('support_weaver','utility',5);
INSERT INTO ship_slot_defs VALUES ('support_weaver','utility',0);
INSERT INTO ship_slot_defs VALUES ('support_weaver','utility',1);
INSERT INTO ship_slot_defs VALUES ('support_weaver','utility',2);
INSERT INTO ship_slot_defs VALUES ('support_weaver','utility',3);
INSERT INTO ship_slot_defs VALUES ('support_weaver','utility',4);
INSERT INTO ship_slot_capacity VALUES ('support_weaver','structure',3);
INSERT INTO ship_slot_defs VALUES ('support_weaver','structure',0);
INSERT INTO ship_slot_defs VALUES ('support_weaver','structure',1);
INSERT INTO ship_slot_defs VALUES ('support_weaver','structure',2);
INSERT INTO ship_resistances VALUES ('support_weaver','shield','kinetic',0.2);
INSERT INTO ship_resistances VALUES ('support_weaver','shield','thermal',0.1);
INSERT INTO ship_resistances VALUES ('support_weaver','shield','pulse',0.0);
INSERT INTO ship_resistances VALUES ('support_weaver','armor','kinetic',0.15);
INSERT INTO ship_resistances VALUES ('support_weaver','armor','thermal',0.15);
INSERT INTO ship_resistances VALUES ('support_weaver','armor','pulse',0.05);
INSERT INTO ship_resistances VALUES ('support_weaver','hull','kinetic',0.05);
INSERT INTO ship_resistances VALUES ('support_weaver','hull','thermal',0.05);
INSERT INTO ship_resistances VALUES ('support_weaver','hull','pulse',0.05);
INSERT INTO ship_role_defs VALUES ('support_weaver','support','faction_route_council','unlock_hulls_advanced');
INSERT INTO ship_loadout_defs VALUES ('loadout_support_weaver','support_weaver','织桥级支援舰标准配装');
INSERT INTO ship_loadout_items VALUES ('loadout_support_weaver','support_weaver','weapon',0,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_support_weaver','support_weaver','weapon',1,'module_kinetic_needle_i');
INSERT INTO ship_loadout_items VALUES ('loadout_support_weaver','support_weaver','utility',0,'module_engine_vector_i');
INSERT INTO ship_loadout_items VALUES ('loadout_support_weaver','support_weaver','utility',1,'module_shield_lattice_i');
INSERT INTO ship_loadout_items VALUES ('loadout_support_weaver','support_weaver','utility',2,'module_scanner_beacon_i');
INSERT INTO ship_loadout_items VALUES ('loadout_support_weaver','support_weaver','work',0,'module_support_patch_i');
INSERT INTO loadout_supply_defs VALUES ('loadout_support_weaver','ammo_kinetic_slug_i',240);
INSERT INTO loadout_supply_defs VALUES ('loadout_support_weaver','repair_kit_i',20);
INSERT INTO camera_profile_defs VALUES ('camera_support_weaver_follow','support_weaver','follow',65,140,45,25,0.2,16000,84.0,350.0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_support_weaver_front','support_weaver','front',75,0,0,0,0.2,16000,0.0,0,0.18,0.12,0.5);
INSERT INTO camera_profile_defs VALUES ('camera_support_weaver_tactical','support_weaver','tactical',55,220,280,0,0.2,16000,165.0,440,0.18,0.12,0.5);
INSERT INTO ship_role_defs VALUES ('shuttle_swift','shuttle','faction_route_council','unlock_basic_services');
INSERT INTO ship_role_defs VALUES ('frigate_lantern','explorer','faction_route_council','unlock_lantern_purchase');
INSERT INTO ship_role_defs VALUES ('frigate_kestrel','combat_frigate','faction_roaming_alliance','unlock_kestrel_purchase');
INSERT INTO ship_role_defs VALUES ('miner_anvil','miner','faction_deepforge','unlock_miner_purchase');
INSERT INTO item_defs VALUES ('component_anchor_ceramic','锚稳陶芯','component',2,10,1,500,150);
INSERT INTO item_defs VALUES ('ore_echo_silica','声纹硅矿','ore',20,80,1,80,24);
INSERT INTO item_defs VALUES ('ore_mirror_crystal','镜相晶矿','ore',30,80,1,120,36);
INSERT INTO item_defs VALUES ('ore_corrosion_titanium','耐蚀碳钛矿','ore',45,100,1,150,45);
INSERT INTO item_defs VALUES ('ore_pressure_steel','承压晶钢矿','ore',70,100,1,180,54);
INSERT INTO item_defs VALUES ('ore_solar_core','曜核晶矿','ore',25,60,1,250,75);
INSERT INTO item_defs VALUES ('component_mist_fiber','雾络纤维','component',1,10,1,600,180);
INSERT INTO item_defs VALUES ('ore_phase_stone','裂相石','ore',35,70,1,300,90);
INSERT INTO item_defs VALUES ('component_relic_logic','遗构逻辑片','component',1,5,1,1800,500);
INSERT INTO module_tech_defs VALUES ('module_kinetic_needle_i','faction_deepforge',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_kinetic_needle_ii','针锋动能炮 II','module',575.0,750,0,8400,1680);
INSERT INTO module_defs VALUES ('module_kinetic_needle_ii','weapon',37.5,22.5,1.2,945.0,5.0,7.5,NULL);
INSERT INTO module_tech_defs VALUES ('module_kinetic_needle_ii','faction_deepforge',2,'unlock_tech_ii');
INSERT INTO weapon_defs VALUES ('module_kinetic_needle_ii','kinetic',45.900000000000006,1200.0,'ammo_kinetic_slug_i',1);
INSERT INTO module_activation_priority VALUES ('module_kinetic_needle_ii',30);
INSERT INTO recipe_defs VALUES ('recipe_module_kinetic_needle_ii','module_kinetic_needle_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_kinetic_needle_ii','module_kinetic_needle_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_kinetic_needle_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_kinetic_needle_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_kinetic_needle_ii','recipe_module_kinetic_needle_ii');
INSERT INTO recycle_outputs VALUES ('module_kinetic_needle_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_kinetic_needle_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_kinetic_needle_iii','针锋动能炮 III','module',675.0,900,0,19600,2520);
INSERT INTO module_defs VALUES ('module_kinetic_needle_iii','weapon',45.0,27.0,1.2,1035.0,6.4,9.600000000000001,NULL);
INSERT INTO module_tech_defs VALUES ('module_kinetic_needle_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO weapon_defs VALUES ('module_kinetic_needle_iii','kinetic',56.099999999999994,1200.0,'ammo_kinetic_slug_i',1);
INSERT INTO module_activation_priority VALUES ('module_kinetic_needle_iii',30);
INSERT INTO recipe_defs VALUES ('recipe_module_kinetic_needle_iii','module_kinetic_needle_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_kinetic_needle_iii','module_kinetic_needle_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_kinetic_needle_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_kinetic_needle_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_kinetic_needle_iii','recipe_module_kinetic_needle_iii');
INSERT INTO recycle_outputs VALUES ('module_kinetic_needle_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_kinetic_needle_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_thermal_sunline_i','faction_route_council',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_thermal_sunline_ii','曜线热束器 II','module',747.5,1000,0,14400,2880);
INSERT INTO module_defs VALUES ('module_thermal_sunline_ii','weapon',56.25,37.5,0.5,735.0,12.5,10.0,1);
INSERT INTO module_tech_defs VALUES ('module_thermal_sunline_ii','faction_route_council',2,'unlock_tech_ii');
INSERT INTO weapon_defs VALUES ('module_thermal_sunline_ii','thermal',37.800000000000004,NULL,NULL,0);
INSERT INTO module_activation_priority VALUES ('module_thermal_sunline_ii',30);
INSERT INTO recipe_defs VALUES ('recipe_module_thermal_sunline_ii','module_thermal_sunline_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_thermal_sunline_ii','module_thermal_sunline_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_thermal_sunline_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_thermal_sunline_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_thermal_sunline_ii','recipe_module_thermal_sunline_ii');
INSERT INTO recycle_outputs VALUES ('module_thermal_sunline_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_thermal_sunline_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_thermal_sunline_iii','曜线热束器 III','module',877.5,1200,0,33600,4320);
INSERT INTO module_defs VALUES ('module_thermal_sunline_iii','weapon',67.5,45.0,0.5,804.9999999999999,16.0,12.8,1);
INSERT INTO module_tech_defs VALUES ('module_thermal_sunline_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO weapon_defs VALUES ('module_thermal_sunline_iii','thermal',46.199999999999996,NULL,NULL,0);
INSERT INTO module_activation_priority VALUES ('module_thermal_sunline_iii',30);
INSERT INTO recipe_defs VALUES ('recipe_module_thermal_sunline_iii','module_thermal_sunline_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_thermal_sunline_iii','module_thermal_sunline_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_thermal_sunline_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_thermal_sunline_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_thermal_sunline_iii','recipe_module_thermal_sunline_iii');
INSERT INTO recycle_outputs VALUES ('module_thermal_sunline_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_thermal_sunline_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_pulse_breakwater_i','faction_route_council',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_pulse_breakwater_ii','破浪脉冲器 II','module',805.0,1062,0,12600,2520);
INSERT INTO module_defs VALUES ('module_pulse_breakwater_ii','weapon',50.0,35.0,2.4,630.0,30.0,20.0,1);
INSERT INTO module_tech_defs VALUES ('module_pulse_breakwater_ii','faction_route_council',2,'unlock_tech_ii');
INSERT INTO weapon_defs VALUES ('module_pulse_breakwater_ii','pulse',97.2,NULL,NULL,0);
INSERT INTO module_activation_priority VALUES ('module_pulse_breakwater_ii',30);
INSERT INTO recipe_defs VALUES ('recipe_module_pulse_breakwater_ii','module_pulse_breakwater_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_pulse_breakwater_ii','module_pulse_breakwater_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_pulse_breakwater_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_pulse_breakwater_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_pulse_breakwater_ii','recipe_module_pulse_breakwater_ii');
INSERT INTO recycle_outputs VALUES ('module_pulse_breakwater_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_pulse_breakwater_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_pulse_breakwater_iii','破浪脉冲器 III','module',945.0,1275,0,29400,3780);
INSERT INTO module_defs VALUES ('module_pulse_breakwater_iii','weapon',60.0,42.0,2.4,690.0,38.400000000000006,25.6,1);
INSERT INTO module_tech_defs VALUES ('module_pulse_breakwater_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO weapon_defs VALUES ('module_pulse_breakwater_iii','pulse',118.8,NULL,NULL,0);
INSERT INTO module_activation_priority VALUES ('module_pulse_breakwater_iii',30);
INSERT INTO recipe_defs VALUES ('recipe_module_pulse_breakwater_iii','module_pulse_breakwater_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_pulse_breakwater_iii','module_pulse_breakwater_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_pulse_breakwater_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_pulse_breakwater_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_pulse_breakwater_iii','recipe_module_pulse_breakwater_iii');
INSERT INTO recycle_outputs VALUES ('module_pulse_breakwater_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_pulse_breakwater_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_shield_lattice_i','faction_route_council',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_shield_lattice_ii','格网护盾组件 II','module',517.5,625,0,7200,1440);
INSERT INTO module_defs VALUES ('module_shield_lattice_ii','utility',43.75,25.0,3.0,0.0,30.0,11.25,1);
INSERT INTO module_tech_defs VALUES ('module_shield_lattice_ii','faction_route_council',2,'unlock_tech_ii');
INSERT INTO repair_defs VALUES ('module_shield_lattice_ii','shield',67.5,NULL,0);
INSERT INTO module_group_members VALUES ('module_shield_lattice_ii','shield');
INSERT INTO module_activation_priority VALUES ('module_shield_lattice_ii',20);
INSERT INTO recipe_defs VALUES ('recipe_module_shield_lattice_ii','module_shield_lattice_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_shield_lattice_ii','module_shield_lattice_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_shield_lattice_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_shield_lattice_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_shield_lattice_ii','recipe_module_shield_lattice_ii');
INSERT INTO recycle_outputs VALUES ('module_shield_lattice_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_shield_lattice_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_shield_lattice_iii','格网护盾组件 III','module',607.5,750,0,16800,2160);
INSERT INTO module_defs VALUES ('module_shield_lattice_iii','utility',52.5,30.0,3.0,0.0,38.400000000000006,14.4,1);
INSERT INTO module_tech_defs VALUES ('module_shield_lattice_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO repair_defs VALUES ('module_shield_lattice_iii','shield',82.5,NULL,0);
INSERT INTO module_group_members VALUES ('module_shield_lattice_iii','shield');
INSERT INTO module_activation_priority VALUES ('module_shield_lattice_iii',20);
INSERT INTO recipe_defs VALUES ('recipe_module_shield_lattice_iii','module_shield_lattice_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_shield_lattice_iii','module_shield_lattice_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_shield_lattice_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_shield_lattice_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_shield_lattice_iii','recipe_module_shield_lattice_iii');
INSERT INTO recycle_outputs VALUES ('module_shield_lattice_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_shield_lattice_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_armor_pressure_i','faction_deepforge',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_armor_pressure_ii','承压护板 II','module',2760.0,3000,0,7800,1560);
INSERT INTO module_defs VALUES ('module_armor_pressure_ii','structure',7.5,10.0,0.0,0.0,0.0,0.0,1);
INSERT INTO module_tech_defs VALUES ('module_armor_pressure_ii','faction_deepforge',2,'unlock_tech_ii');
INSERT INTO module_stat_modifiers VALUES ('module_armor_pressure_ii','armor_max','add',243.00000000000003);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_pressure_ii','armor','kinetic',0.08);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_pressure_ii','armor','thermal',0.04);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_pressure_ii','armor','pulse',-0.02);
INSERT INTO module_group_members VALUES ('module_armor_pressure_ii','armor_upgrade');
INSERT INTO recipe_defs VALUES ('recipe_module_armor_pressure_ii','module_armor_pressure_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_pressure_ii','module_armor_pressure_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_pressure_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_pressure_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_armor_pressure_ii','recipe_module_armor_pressure_ii');
INSERT INTO recycle_outputs VALUES ('module_armor_pressure_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_armor_pressure_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_armor_pressure_iii','承压护板 III','module',3240.0,3600,0,18200,2340);
INSERT INTO module_defs VALUES ('module_armor_pressure_iii','structure',9.0,12.0,0.0,0.0,0.0,0.0,1);
INSERT INTO module_tech_defs VALUES ('module_armor_pressure_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO module_stat_modifiers VALUES ('module_armor_pressure_iii','armor_max','add',297.0);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_pressure_iii','armor','kinetic',0.08);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_pressure_iii','armor','thermal',0.04);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_pressure_iii','armor','pulse',-0.02);
INSERT INTO module_group_members VALUES ('module_armor_pressure_iii','armor_upgrade');
INSERT INTO recipe_defs VALUES ('recipe_module_armor_pressure_iii','module_armor_pressure_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_pressure_iii','module_armor_pressure_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_pressure_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_pressure_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_armor_pressure_iii','recipe_module_armor_pressure_iii');
INSERT INTO recycle_outputs VALUES ('module_armor_pressure_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_armor_pressure_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_armor_feather_i','faction_roaming_alliance',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_armor_feather_ii','轻翎护板 II','module',690.0,1250,0,6600,1320);
INSERT INTO module_defs VALUES ('module_armor_feather_ii','structure',5.0,12.5,0.0,0.0,0.0,0.0,1);
INSERT INTO module_tech_defs VALUES ('module_armor_feather_ii','faction_roaming_alliance',2,'unlock_tech_ii');
INSERT INTO module_stat_modifiers VALUES ('module_armor_feather_ii','armor_max','add',114.75000000000001);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_feather_ii','armor','kinetic',0.02);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_feather_ii','armor','thermal',0.02);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_feather_ii','armor','pulse',0.02);
INSERT INTO module_group_members VALUES ('module_armor_feather_ii','armor_upgrade');
INSERT INTO recipe_defs VALUES ('recipe_module_armor_feather_ii','module_armor_feather_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_feather_ii','module_armor_feather_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_feather_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_feather_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_armor_feather_ii','recipe_module_armor_feather_ii');
INSERT INTO recycle_outputs VALUES ('module_armor_feather_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_armor_feather_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_armor_feather_iii','轻翎护板 III','module',810.0,1500,0,15400,1980);
INSERT INTO module_defs VALUES ('module_armor_feather_iii','structure',6.0,15.0,0.0,0.0,0.0,0.0,1);
INSERT INTO module_tech_defs VALUES ('module_armor_feather_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO module_stat_modifiers VALUES ('module_armor_feather_iii','armor_max','add',140.25);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_feather_iii','armor','kinetic',0.02);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_feather_iii','armor','thermal',0.02);
INSERT INTO module_resistance_modifiers VALUES ('module_armor_feather_iii','armor','pulse',0.02);
INSERT INTO module_group_members VALUES ('module_armor_feather_iii','armor_upgrade');
INSERT INTO recipe_defs VALUES ('recipe_module_armor_feather_iii','module_armor_feather_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_feather_iii','module_armor_feather_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_feather_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_armor_feather_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_armor_feather_iii','recipe_module_armor_feather_iii');
INSERT INTO recycle_outputs VALUES ('module_armor_feather_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_armor_feather_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_engine_vector_i','faction_roaming_alliance',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_engine_vector_ii','矢量姿态引擎 II','module',460.0,750,0,7800,1560);
INSERT INTO module_defs VALUES ('module_engine_vector_ii','utility',43.75,30.0,1.0,0.0,2.5,2.5,1);
INSERT INTO module_tech_defs VALUES ('module_engine_vector_ii','faction_roaming_alliance',2,'unlock_tech_ii');
INSERT INTO module_stat_modifiers VALUES ('module_engine_vector_ii','max_speed_mps','multiply',1.11);
INSERT INTO module_stat_modifiers VALUES ('module_engine_vector_ii','acceleration_mps2','multiply',1.22);
INSERT INTO module_stat_modifiers VALUES ('module_engine_vector_ii','turn_rad_s','multiply',1.22);
INSERT INTO module_group_members VALUES ('module_engine_vector_ii','engine');
INSERT INTO module_activation_priority VALUES ('module_engine_vector_ii',10);
INSERT INTO recipe_defs VALUES ('recipe_module_engine_vector_ii','module_engine_vector_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_engine_vector_ii','module_engine_vector_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_engine_vector_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_engine_vector_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_engine_vector_ii','recipe_module_engine_vector_ii');
INSERT INTO recycle_outputs VALUES ('module_engine_vector_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_engine_vector_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_engine_vector_iii','矢量姿态引擎 III','module',540.0,900,0,18200,2340);
INSERT INTO module_defs VALUES ('module_engine_vector_iii','utility',52.5,36.0,1.0,0.0,3.2,3.2,1);
INSERT INTO module_tech_defs VALUES ('module_engine_vector_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO module_stat_modifiers VALUES ('module_engine_vector_iii','max_speed_mps','multiply',1.125);
INSERT INTO module_stat_modifiers VALUES ('module_engine_vector_iii','acceleration_mps2','multiply',1.25);
INSERT INTO module_stat_modifiers VALUES ('module_engine_vector_iii','turn_rad_s','multiply',1.25);
INSERT INTO module_group_members VALUES ('module_engine_vector_iii','engine');
INSERT INTO module_activation_priority VALUES ('module_engine_vector_iii',10);
INSERT INTO recipe_defs VALUES ('recipe_module_engine_vector_iii','module_engine_vector_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_engine_vector_iii','module_engine_vector_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_engine_vector_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_engine_vector_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_engine_vector_iii','recipe_module_engine_vector_iii');
INSERT INTO recycle_outputs VALUES ('module_engine_vector_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_engine_vector_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_scanner_beacon_i','faction_route_council',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_scanner_beacon_ii','远标扫描阵列 II','module',345.0,1000,0,6600,1320);
INSERT INTO module_defs VALUES ('module_scanner_beacon_ii','utility',50.0,56.25,1.0,3150.0,7.5,2.5,1);
INSERT INTO module_tech_defs VALUES ('module_scanner_beacon_ii','faction_route_council',2,'unlock_tech_ii');
INSERT INTO module_stat_modifiers VALUES ('module_scanner_beacon_ii','scan_strength','add',20.25);
INSERT INTO module_group_members VALUES ('module_scanner_beacon_ii','scanner');
INSERT INTO module_activation_priority VALUES ('module_scanner_beacon_ii',40);
INSERT INTO recipe_defs VALUES ('recipe_module_scanner_beacon_ii','module_scanner_beacon_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_scanner_beacon_ii','module_scanner_beacon_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_scanner_beacon_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_scanner_beacon_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_scanner_beacon_ii','recipe_module_scanner_beacon_ii');
INSERT INTO recycle_outputs VALUES ('module_scanner_beacon_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_scanner_beacon_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_scanner_beacon_iii','远标扫描阵列 III','module',405.0,1200,0,15400,1980);
INSERT INTO module_defs VALUES ('module_scanner_beacon_iii','utility',60.0,67.5,1.0,3449.9999999999995,9.600000000000001,3.2,1);
INSERT INTO module_tech_defs VALUES ('module_scanner_beacon_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO module_stat_modifiers VALUES ('module_scanner_beacon_iii','scan_strength','add',24.75);
INSERT INTO module_group_members VALUES ('module_scanner_beacon_iii','scanner');
INSERT INTO module_activation_priority VALUES ('module_scanner_beacon_iii',40);
INSERT INTO recipe_defs VALUES ('recipe_module_scanner_beacon_iii','module_scanner_beacon_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_scanner_beacon_iii','module_scanner_beacon_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_scanner_beacon_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_scanner_beacon_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_scanner_beacon_iii','recipe_module_scanner_beacon_iii');
INSERT INTO recycle_outputs VALUES ('module_scanner_beacon_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_scanner_beacon_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_industry_sift_i','faction_deepforge',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_industry_sift_ii','筛光采集头 II','module',1380.0,2000,0,9000,1800);
INSERT INTO module_defs VALUES ('module_industry_sift_ii','work',68.75,37.5,4.0,189.0,12.5,12.5,NULL);
INSERT INTO module_tech_defs VALUES ('module_industry_sift_ii','faction_deepforge',2,'unlock_tech_ii');
INSERT INTO mining_defs VALUES ('module_industry_sift_ii',10);
INSERT INTO module_activation_priority VALUES ('module_industry_sift_ii',50);
INSERT INTO mining_compatibility VALUES ('module_industry_sift_ii','ore_ferrosilicate');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_ii','ore_conductive_crystal');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_ii','ore_echo_silica');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_ii','ore_mirror_crystal');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_ii','ore_corrosion_titanium');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_ii','ore_pressure_steel');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_ii','ore_solar_core');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_ii','ore_phase_stone');
INSERT INTO recipe_defs VALUES ('recipe_module_industry_sift_ii','module_industry_sift_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_industry_sift_ii','module_industry_sift_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_industry_sift_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_industry_sift_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_industry_sift_ii','recipe_module_industry_sift_ii');
INSERT INTO recycle_outputs VALUES ('module_industry_sift_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_industry_sift_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_industry_sift_iii','筛光采集头 III','module',1620.0,2400,0,21000,2700);
INSERT INTO module_defs VALUES ('module_industry_sift_iii','work',82.5,45.0,4.0,206.99999999999997,16.0,16.0,NULL);
INSERT INTO module_tech_defs VALUES ('module_industry_sift_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO mining_defs VALUES ('module_industry_sift_iii',13);
INSERT INTO module_activation_priority VALUES ('module_industry_sift_iii',50);
INSERT INTO mining_compatibility VALUES ('module_industry_sift_iii','ore_ferrosilicate');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_iii','ore_conductive_crystal');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_iii','ore_echo_silica');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_iii','ore_mirror_crystal');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_iii','ore_corrosion_titanium');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_iii','ore_pressure_steel');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_iii','ore_solar_core');
INSERT INTO mining_compatibility VALUES ('module_industry_sift_iii','ore_phase_stone');
INSERT INTO recipe_defs VALUES ('recipe_module_industry_sift_iii','module_industry_sift_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_industry_sift_iii','module_industry_sift_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_industry_sift_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_industry_sift_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_industry_sift_iii','recipe_module_industry_sift_iii');
INSERT INTO recycle_outputs VALUES ('module_industry_sift_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_industry_sift_iii','material_dense_alloy',2);
INSERT INTO module_tech_defs VALUES ('module_support_patch_i','faction_roaming_alliance',1,'unlock_basic_services');
INSERT INTO item_defs VALUES ('module_support_patch_ii','缝桥维修投射器 II','module',1150.0,1500,0,8400,1680);
INSERT INTO module_defs VALUES ('module_support_patch_ii','work',50.0,40.0,5.0,262.5,22.5,15.0,1);
INSERT INTO module_tech_defs VALUES ('module_support_patch_ii','faction_roaming_alliance',2,'unlock_tech_ii');
INSERT INTO repair_defs VALUES ('module_support_patch_ii','armor',81.0,'repair_kit_i',1);
INSERT INTO module_group_members VALUES ('module_support_patch_ii','support');
INSERT INTO module_activation_priority VALUES ('module_support_patch_ii',20);
INSERT INTO recipe_defs VALUES ('recipe_module_support_patch_ii','module_support_patch_ii',1,400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_support_patch_ii','module_support_patch_i',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_support_patch_ii','component_relic',3);
INSERT INTO recipe_inputs VALUES ('recipe_module_support_patch_ii','material_dense_alloy',2);
INSERT INTO module_salvage_recipe_defs VALUES ('module_support_patch_ii','recipe_module_support_patch_ii');
INSERT INTO recycle_outputs VALUES ('module_support_patch_ii','component_relic',1);
INSERT INTO recycle_outputs VALUES ('module_support_patch_ii','material_dense_alloy',1);
INSERT INTO item_defs VALUES ('module_support_patch_iii','缝桥维修投射器 III','module',1350.0,1800,0,19600,2520);
INSERT INTO module_defs VALUES ('module_support_patch_iii','work',60.0,48.0,5.0,287.5,28.8,19.200000000000003,1);
INSERT INTO module_tech_defs VALUES ('module_support_patch_iii','faction_silent_relics',3,'unlock_tech_iii');
INSERT INTO repair_defs VALUES ('module_support_patch_iii','armor',99.0,'repair_kit_i',1);
INSERT INTO module_group_members VALUES ('module_support_patch_iii','support');
INSERT INTO module_activation_priority VALUES ('module_support_patch_iii',20);
INSERT INTO recipe_defs VALUES ('recipe_module_support_patch_iii','module_support_patch_iii',1,1400,0);
INSERT INTO recipe_inputs VALUES ('recipe_module_support_patch_iii','module_support_patch_ii',1);
INSERT INTO recipe_inputs VALUES ('recipe_module_support_patch_iii','component_relic_logic',2);
INSERT INTO recipe_inputs VALUES ('recipe_module_support_patch_iii','material_dense_alloy',5);
INSERT INTO module_salvage_recipe_defs VALUES ('module_support_patch_iii','recipe_module_support_patch_iii');
INSERT INTO recycle_outputs VALUES ('module_support_patch_iii','component_relic_logic',1);
INSERT INTO recycle_outputs VALUES ('module_support_patch_iii','material_dense_alloy',2);
INSERT INTO system_defs VALUES ('system_mirror','镜湖星系');
INSERT INTO sector_defs VALUES ('sector_mirror','system_mirror','risk_high');
INSERT INTO sector_runtime_defs VALUES ('sector_mirror','scene_sector_mirror',1,'C',15000);
INSERT INTO anchor_defs VALUES ('anchor_mirror_station','sector_mirror','station',0,0,0,0,600,1000);
INSERT INTO anchor_defs VALUES ('anchor_mirror_undock','sector_mirror','undock',0,0,-650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_mirror_resource','sector_mirror','resource',1800,200,-2200,0,180,150);
INSERT INTO anchor_defs VALUES ('anchor_mirror_signal','sector_mirror','signal',-2400,250,-2600,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_mirror_enemy','sector_mirror','npc_spawn',6800,400,-6000,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_mirror_patrol0','sector_mirror','patrol',6500,400,-5800,0,40,0);
INSERT INTO anchor_defs VALUES ('anchor_mirror_patrol1','sector_mirror','patrol',7100,400,-6200,0,40,0);
INSERT INTO station_defs VALUES ('station_mirror_hub','镜湖工业港','sector_mirror','faction_route_council','anchor_mirror_station','anchor_mirror_undock',300,150000);
INSERT INTO station_service_defs VALUES ('station_mirror_hub','warehouse','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','repair','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','recharge','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','trade','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','ship_purchase','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','fitting','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','manufacture','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','recycle','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','mission_board','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mirror_hub','loan','unlock_open_routes');
INSERT INTO resource_node_defs VALUES ('node_mirror_special','sector_mirror','ore_mirror_crystal',2400,1200);
INSERT INTO resource_node_locations VALUES ('node_mirror_special','sector_mirror','anchor_mirror_resource','unlock_open_routes');
INSERT INTO signal_defs VALUES ('signal_mirror_relic','镜湖异常遗迹','anchor_mirror_signal',2,300,'unlock_open_routes','fixed',1);
INSERT INTO npc_defs VALUES ('npc_mirror_sentinel','npc_raider_medium',4,'risk_high');
INSERT INTO npc_spawn_defs VALUES ('spawn_mirror_sentinel','npc_mirror_sentinel','sector_mirror','anchor_mirror_enemy','behavior_raider','ambient','unlock_open_routes',600,1,1);
INSERT INTO npc_patrol_points VALUES ('spawn_mirror_sentinel',0,'anchor_mirror_patrol0');
INSERT INTO npc_patrol_points VALUES ('spawn_mirror_sentinel',1,'anchor_mirror_patrol1');
INSERT INTO system_defs VALUES ('system_forge','熔脊星系');
INSERT INTO sector_defs VALUES ('sector_forge','system_forge','risk_medium');
INSERT INTO sector_runtime_defs VALUES ('sector_forge','scene_sector_forge',1,'C',15000);
INSERT INTO anchor_defs VALUES ('anchor_forge_station','sector_forge','station',0,0,0,0,600,1000);
INSERT INTO anchor_defs VALUES ('anchor_forge_undock','sector_forge','undock',0,0,-650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_forge_resource','sector_forge','resource',1800,200,-2200,0,180,150);
INSERT INTO anchor_defs VALUES ('anchor_forge_signal','sector_forge','signal',-2400,250,-2600,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_forge_enemy','sector_forge','npc_spawn',6800,400,-6000,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_forge_patrol0','sector_forge','patrol',6500,400,-5800,0,40,0);
INSERT INTO anchor_defs VALUES ('anchor_forge_patrol1','sector_forge','patrol',7100,400,-6200,0,40,0);
INSERT INTO station_defs VALUES ('station_forge_hub','熔脊工业港','sector_forge','faction_deepforge','anchor_forge_station','anchor_forge_undock',300,150000);
INSERT INTO station_service_defs VALUES ('station_forge_hub','warehouse','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','repair','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','recharge','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','trade','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','ship_purchase','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','fitting','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','manufacture','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','recycle','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','mission_board','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_forge_hub','loan','unlock_open_routes');
INSERT INTO resource_node_defs VALUES ('node_forge_special','sector_forge','ore_corrosion_titanium',2400,1200);
INSERT INTO resource_node_locations VALUES ('node_forge_special','sector_forge','anchor_forge_resource','unlock_open_routes');
INSERT INTO signal_defs VALUES ('signal_forge_relic','熔脊异常遗迹','anchor_forge_signal',2,300,'unlock_open_routes','fixed',1);
INSERT INTO npc_defs VALUES ('npc_forge_sentinel','npc_raider_medium',5,'risk_medium');
INSERT INTO npc_spawn_defs VALUES ('spawn_forge_sentinel','npc_forge_sentinel','sector_forge','anchor_forge_enemy','behavior_raider','ambient','unlock_open_routes',600,1,1);
INSERT INTO npc_patrol_points VALUES ('spawn_forge_sentinel',0,'anchor_forge_patrol0');
INSERT INTO npc_patrol_points VALUES ('spawn_forge_sentinel',1,'anchor_forge_patrol1');
INSERT INTO system_defs VALUES ('system_iron','铁环星系');
INSERT INTO sector_defs VALUES ('sector_iron','system_iron','risk_medium');
INSERT INTO sector_runtime_defs VALUES ('sector_iron','scene_sector_iron',1,'C',15000);
INSERT INTO anchor_defs VALUES ('anchor_iron_station','sector_iron','station',0,0,0,0,600,1000);
INSERT INTO anchor_defs VALUES ('anchor_iron_undock','sector_iron','undock',0,0,-650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_iron_resource','sector_iron','resource',1800,200,-2200,0,180,150);
INSERT INTO anchor_defs VALUES ('anchor_iron_signal','sector_iron','signal',-2400,250,-2600,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_iron_enemy','sector_iron','npc_spawn',6800,400,-6000,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_iron_patrol0','sector_iron','patrol',6500,400,-5800,0,40,0);
INSERT INTO anchor_defs VALUES ('anchor_iron_patrol1','sector_iron','patrol',7100,400,-6200,0,40,0);
INSERT INTO station_defs VALUES ('station_iron_hub','铁环工业港','sector_iron','faction_deepforge','anchor_iron_station','anchor_iron_undock',300,150000);
INSERT INTO station_service_defs VALUES ('station_iron_hub','warehouse','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','repair','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','recharge','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','trade','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','ship_purchase','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','fitting','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','manufacture','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','recycle','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','mission_board','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_iron_hub','loan','unlock_open_routes');
INSERT INTO resource_node_defs VALUES ('node_iron_special','sector_iron','ore_pressure_steel',2400,1200);
INSERT INTO resource_node_locations VALUES ('node_iron_special','sector_iron','anchor_iron_resource','unlock_open_routes');
INSERT INTO signal_defs VALUES ('signal_iron_relic','铁环异常遗迹','anchor_iron_signal',2,300,'unlock_open_routes','fixed',1);
INSERT INTO npc_defs VALUES ('npc_iron_sentinel','npc_raider_medium',7,'risk_medium');
INSERT INTO npc_spawn_defs VALUES ('spawn_iron_sentinel','npc_iron_sentinel','sector_iron','anchor_iron_enemy','behavior_raider','ambient','unlock_open_routes',600,1,1);
INSERT INTO npc_patrol_points VALUES ('spawn_iron_sentinel',0,'anchor_iron_patrol0');
INSERT INTO npc_patrol_points VALUES ('spawn_iron_sentinel',1,'anchor_iron_patrol1');
INSERT INTO system_defs VALUES ('system_helios','曜炉星系');
INSERT INTO sector_defs VALUES ('sector_helios','system_helios','risk_low');
INSERT INTO sector_runtime_defs VALUES ('sector_helios','scene_sector_helios',1,'D',15000);
INSERT INTO anchor_defs VALUES ('anchor_helios_station','sector_helios','station',0,0,0,0,600,1000);
INSERT INTO anchor_defs VALUES ('anchor_helios_undock','sector_helios','undock',0,0,-650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_helios_resource','sector_helios','resource',1800,200,-2200,0,180,150);
INSERT INTO anchor_defs VALUES ('anchor_helios_signal','sector_helios','signal',-2400,250,-2600,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_helios_enemy','sector_helios','npc_spawn',6800,400,-6000,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_helios_patrol0','sector_helios','patrol',6500,400,-5800,0,40,0);
INSERT INTO anchor_defs VALUES ('anchor_helios_patrol1','sector_helios','patrol',7100,400,-6200,0,40,0);
INSERT INTO station_defs VALUES ('station_helios_hub','曜炉工业港','sector_helios','faction_deepforge','anchor_helios_station','anchor_helios_undock',300,200000);
INSERT INTO station_service_defs VALUES ('station_helios_hub','warehouse','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','repair','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','recharge','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','trade','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','ship_purchase','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','fitting','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','manufacture','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','recycle','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','mission_board','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_helios_hub','loan','unlock_open_routes');
INSERT INTO resource_node_defs VALUES ('node_helios_special','sector_helios','ore_solar_core',1000,1200);
INSERT INTO resource_node_locations VALUES ('node_helios_special','sector_helios','anchor_helios_resource','unlock_open_routes');
INSERT INTO signal_defs VALUES ('signal_helios_relic','曜炉异常遗迹','anchor_helios_signal',4,300,'unlock_open_routes','fixed',1);
INSERT INTO npc_defs VALUES ('npc_helios_sentinel','npc_guardian_heavy',10,'risk_low');
INSERT INTO npc_spawn_defs VALUES ('spawn_helios_sentinel','npc_helios_sentinel','sector_helios','anchor_helios_enemy','behavior_guardian','ambient','unlock_open_routes',600,1,1);
INSERT INTO npc_patrol_points VALUES ('spawn_helios_sentinel',0,'anchor_helios_patrol0');
INSERT INTO npc_patrol_points VALUES ('spawn_helios_sentinel',1,'anchor_helios_patrol1');
INSERT INTO system_defs VALUES ('system_drift','游弋渡星系');
INSERT INTO sector_defs VALUES ('sector_drift','system_drift','risk_medium');
INSERT INTO sector_runtime_defs VALUES ('sector_drift','scene_sector_drift',1,'C',15000);
INSERT INTO anchor_defs VALUES ('anchor_drift_station','sector_drift','station',0,0,0,0,600,1000);
INSERT INTO anchor_defs VALUES ('anchor_drift_undock','sector_drift','undock',0,0,-650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_drift_resource','sector_drift','resource',1800,200,-2200,0,180,150);
INSERT INTO anchor_defs VALUES ('anchor_drift_signal','sector_drift','signal',-2400,250,-2600,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_drift_enemy','sector_drift','npc_spawn',6800,400,-6000,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_drift_patrol0','sector_drift','patrol',6500,400,-5800,0,40,0);
INSERT INTO anchor_defs VALUES ('anchor_drift_patrol1','sector_drift','patrol',7100,400,-6200,0,40,0);
INSERT INTO station_defs VALUES ('station_drift_hub','游弋渡工业港','sector_drift','faction_roaming_alliance','anchor_drift_station','anchor_drift_undock',300,150000);
INSERT INTO station_service_defs VALUES ('station_drift_hub','warehouse','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','repair','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','recharge','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','trade','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','ship_purchase','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','fitting','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','manufacture','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','recycle','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','mission_board','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_drift_hub','loan','unlock_open_routes');
INSERT INTO resource_node_defs VALUES ('node_drift_special','sector_drift','material_feather_alloy',2400,1200);
INSERT INTO resource_node_locations VALUES ('node_drift_special','sector_drift','anchor_drift_resource','unlock_open_routes');
INSERT INTO signal_defs VALUES ('signal_drift_relic','游弋渡异常遗迹','anchor_drift_signal',2,300,'unlock_open_routes','fixed',1);
INSERT INTO npc_defs VALUES ('npc_drift_sentinel','npc_raider_medium',5,'risk_medium');
INSERT INTO npc_spawn_defs VALUES ('spawn_drift_sentinel','npc_drift_sentinel','sector_drift','anchor_drift_enemy','behavior_raider','ambient','unlock_open_routes',600,1,1);
INSERT INTO npc_patrol_points VALUES ('spawn_drift_sentinel',0,'anchor_drift_patrol0');
INSERT INTO npc_patrol_points VALUES ('spawn_drift_sentinel',1,'anchor_drift_patrol1');
INSERT INTO system_defs VALUES ('system_mist','雾帆星系');
INSERT INTO sector_defs VALUES ('sector_mist','system_mist','risk_low');
INSERT INTO sector_runtime_defs VALUES ('sector_mist','scene_sector_mist',1,'D',15000);
INSERT INTO anchor_defs VALUES ('anchor_mist_station','sector_mist','station',0,0,0,0,600,1000);
INSERT INTO anchor_defs VALUES ('anchor_mist_undock','sector_mist','undock',0,0,-650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_mist_resource','sector_mist','resource',1800,200,-2200,0,180,150);
INSERT INTO anchor_defs VALUES ('anchor_mist_signal','sector_mist','signal',-2400,250,-2600,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_mist_enemy','sector_mist','npc_spawn',6800,400,-6000,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_mist_patrol0','sector_mist','patrol',6500,400,-5800,0,40,0);
INSERT INTO anchor_defs VALUES ('anchor_mist_patrol1','sector_mist','patrol',7100,400,-6200,0,40,0);
INSERT INTO station_defs VALUES ('station_mist_hub','雾帆工业港','sector_mist','faction_roaming_alliance','anchor_mist_station','anchor_mist_undock',300,200000);
INSERT INTO station_service_defs VALUES ('station_mist_hub','warehouse','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','repair','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','recharge','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','trade','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','ship_purchase','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','fitting','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','manufacture','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','recycle','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','mission_board','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_mist_hub','loan','unlock_open_routes');
INSERT INTO resource_node_defs VALUES ('node_mist_special','sector_mist','component_mist_fiber',1000,1200);
INSERT INTO resource_node_locations VALUES ('node_mist_special','sector_mist','anchor_mist_resource','unlock_open_routes');
INSERT INTO signal_defs VALUES ('signal_mist_relic','雾帆异常遗迹','anchor_mist_signal',4,300,'unlock_open_routes','fixed',1);
INSERT INTO npc_defs VALUES ('npc_mist_sentinel','npc_guardian_heavy',8,'risk_low');
INSERT INTO npc_spawn_defs VALUES ('spawn_mist_sentinel','npc_mist_sentinel','sector_mist','anchor_mist_enemy','behavior_guardian','ambient','unlock_open_routes',600,1,1);
INSERT INTO npc_patrol_points VALUES ('spawn_mist_sentinel',0,'anchor_mist_patrol0');
INSERT INTO npc_patrol_points VALUES ('spawn_mist_sentinel',1,'anchor_mist_patrol1');
INSERT INTO system_defs VALUES ('system_rift','断弦星系');
INSERT INTO sector_defs VALUES ('sector_rift','system_rift','risk_low');
INSERT INTO sector_runtime_defs VALUES ('sector_rift','scene_sector_rift',1,'D',15000);
INSERT INTO anchor_defs VALUES ('anchor_rift_station','sector_rift','station',0,0,0,0,600,1000);
INSERT INTO anchor_defs VALUES ('anchor_rift_undock','sector_rift','undock',0,0,-650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_rift_resource','sector_rift','resource',1800,200,-2200,0,180,150);
INSERT INTO anchor_defs VALUES ('anchor_rift_signal','sector_rift','signal',-2400,250,-2600,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_rift_enemy','sector_rift','npc_spawn',6800,400,-6000,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_rift_patrol0','sector_rift','patrol',6500,400,-5800,0,40,0);
INSERT INTO anchor_defs VALUES ('anchor_rift_patrol1','sector_rift','patrol',7100,400,-6200,0,40,0);
INSERT INTO station_defs VALUES ('station_rift_hub','断弦工业港','sector_rift','faction_roaming_alliance','anchor_rift_station','anchor_rift_undock',300,200000);
INSERT INTO station_service_defs VALUES ('station_rift_hub','warehouse','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','repair','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','recharge','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','trade','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','ship_purchase','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','fitting','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','manufacture','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','recycle','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','mission_board','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_rift_hub','loan','unlock_open_routes');
INSERT INTO resource_node_defs VALUES ('node_rift_special','sector_rift','ore_phase_stone',1000,1200);
INSERT INTO resource_node_locations VALUES ('node_rift_special','sector_rift','anchor_rift_resource','unlock_open_routes');
INSERT INTO signal_defs VALUES ('signal_rift_relic','断弦异常遗迹','anchor_rift_signal',4,300,'unlock_open_routes','fixed',1);
INSERT INTO npc_defs VALUES ('npc_rift_sentinel','npc_guardian_heavy',10,'risk_low');
INSERT INTO npc_spawn_defs VALUES ('spawn_rift_sentinel','npc_rift_sentinel','sector_rift','anchor_rift_enemy','behavior_guardian','ambient','unlock_open_routes',600,1,1);
INSERT INTO npc_patrol_points VALUES ('spawn_rift_sentinel',0,'anchor_rift_patrol0');
INSERT INTO npc_patrol_points VALUES ('spawn_rift_sentinel',1,'anchor_rift_patrol1');
INSERT INTO system_defs VALUES ('system_silent','静默渊星系');
INSERT INTO sector_defs VALUES ('sector_silent','system_silent','risk_low');
INSERT INTO sector_runtime_defs VALUES ('sector_silent','scene_sector_silent',1,'D',15000);
INSERT INTO anchor_defs VALUES ('anchor_silent_station','sector_silent','station',0,0,0,0,600,1000);
INSERT INTO anchor_defs VALUES ('anchor_silent_undock','sector_silent','undock',0,0,-650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_silent_resource','sector_silent','resource',1800,200,-2200,0,180,150);
INSERT INTO anchor_defs VALUES ('anchor_silent_signal','sector_silent','signal',-2400,250,-2600,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_silent_enemy','sector_silent','npc_spawn',6800,400,-6000,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_silent_patrol0','sector_silent','patrol',6500,400,-5800,0,40,0);
INSERT INTO anchor_defs VALUES ('anchor_silent_patrol1','sector_silent','patrol',7100,400,-6200,0,40,0);
INSERT INTO station_defs VALUES ('station_silent_hub','静默渊工业港','sector_silent','faction_silent_relics','anchor_silent_station','anchor_silent_undock',300,200000);
INSERT INTO station_service_defs VALUES ('station_silent_hub','warehouse','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','repair','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','recharge','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','trade','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','ship_purchase','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','fitting','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','manufacture','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','recycle','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','mission_board','unlock_open_routes');
INSERT INTO station_service_defs VALUES ('station_silent_hub','loan','unlock_open_routes');
INSERT INTO resource_node_defs VALUES ('node_silent_special','sector_silent','component_relic_logic',1000,1200);
INSERT INTO resource_node_locations VALUES ('node_silent_special','sector_silent','anchor_silent_resource','unlock_open_routes');
INSERT INTO signal_defs VALUES ('signal_silent_relic','静默渊异常遗迹','anchor_silent_signal',4,300,'unlock_open_routes','fixed',1);
INSERT INTO npc_defs VALUES ('npc_silent_sentinel','npc_guardian_heavy',12,'risk_low');
INSERT INTO npc_spawn_defs VALUES ('spawn_silent_sentinel','npc_silent_sentinel','sector_silent','anchor_silent_enemy','behavior_guardian','ambient','unlock_open_routes',600,1,1);
INSERT INTO npc_patrol_points VALUES ('spawn_silent_sentinel',0,'anchor_silent_patrol0');
INSERT INTO npc_patrol_points VALUES ('spawn_silent_sentinel',1,'anchor_silent_patrol1');
INSERT INTO anchor_defs VALUES ('anchor_anchor_special','sector_anchor','resource',-1800,100,-2000,0,180,150);
INSERT INTO resource_node_defs VALUES ('node_anchor_special','sector_anchor','component_anchor_ceramic',600,1200);
INSERT INTO resource_node_locations VALUES ('node_anchor_special','sector_anchor','anchor_anchor_special','unlock_open_routes');
INSERT INTO anchor_defs VALUES ('anchor_echo_silica','sector_echo','resource',-1500,0,-2600,0,180,150);
INSERT INTO resource_node_defs VALUES ('node_echo_silica','sector_echo','ore_echo_silica',1200,1200);
INSERT INTO resource_node_locations VALUES ('node_echo_silica','sector_echo','anchor_echo_silica','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_anchor_mirror','sector_anchor','sector_mirror',1,'gate_medium',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_anchor_mirror','sector_anchor','gate_entry',-4200,0,4200,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_anchor_mirror_exit','sector_anchor','gate_exit',-4200,0,3850,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_mirror_anchor','sector_mirror','gate_entry',-4200,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_mirror_anchor_exit','sector_mirror','gate_exit',-4200,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_anchor_mirror','conn_anchor_mirror','sector_anchor','sector_mirror','anchor_gate_anchor_mirror','anchor_gate_mirror_anchor_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_mirror_anchor','conn_anchor_mirror','sector_mirror','sector_anchor','anchor_gate_mirror_anchor','anchor_gate_anchor_mirror_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_echo_forge','sector_echo','sector_forge',1,'gate_medium',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_echo_forge','sector_echo','gate_entry',-4200,0,4200,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_echo_forge_exit','sector_echo','gate_exit',-4200,0,3850,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_forge_echo','sector_forge','gate_entry',-4200,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_forge_echo_exit','sector_forge','gate_exit',-4200,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_echo_forge','conn_echo_forge','sector_echo','sector_forge','anchor_gate_echo_forge','anchor_gate_forge_echo_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_forge_echo','conn_echo_forge','sector_forge','sector_echo','anchor_gate_forge_echo','anchor_gate_echo_forge_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_mirror_drift','sector_mirror','sector_drift',1,'gate_medium',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_mirror_drift','sector_mirror','gate_entry',-2400,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_mirror_drift_exit','sector_mirror','gate_exit',-2400,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_drift_mirror','sector_drift','gate_entry',-4200,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_drift_mirror_exit','sector_drift','gate_exit',-4200,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_mirror_drift','conn_mirror_drift','sector_mirror','sector_drift','anchor_gate_mirror_drift','anchor_gate_drift_mirror_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_drift_mirror','conn_mirror_drift','sector_drift','sector_mirror','anchor_gate_drift_mirror','anchor_gate_mirror_drift_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_forge_iron','sector_forge','sector_iron',1,'gate_heavy',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_forge_iron','sector_forge','gate_entry',-2400,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_forge_iron_exit','sector_forge','gate_exit',-2400,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_iron_forge','sector_iron','gate_entry',-4200,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_iron_forge_exit','sector_iron','gate_exit',-4200,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_forge_iron','conn_forge_iron','sector_forge','sector_iron','anchor_gate_forge_iron','anchor_gate_iron_forge_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_iron_forge','conn_forge_iron','sector_iron','sector_forge','anchor_gate_iron_forge','anchor_gate_forge_iron_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_iron_helios','sector_iron','sector_helios',1,'gate_heavy',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_iron_helios','sector_iron','gate_entry',-2400,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_iron_helios_exit','sector_iron','gate_exit',-2400,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_helios_iron','sector_helios','gate_entry',-4200,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_helios_iron_exit','sector_helios','gate_exit',-4200,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_iron_helios','conn_iron_helios','sector_iron','sector_helios','anchor_gate_iron_helios','anchor_gate_helios_iron_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_helios_iron','conn_iron_helios','sector_helios','sector_iron','anchor_gate_helios_iron','anchor_gate_iron_helios_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_drift_mist','sector_drift','sector_mist',1,'gate_medium',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_drift_mist','sector_drift','gate_entry',-2400,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_drift_mist_exit','sector_drift','gate_exit',-2400,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_mist_drift','sector_mist','gate_entry',-4200,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_mist_drift_exit','sector_mist','gate_exit',-4200,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_drift_mist','conn_drift_mist','sector_drift','sector_mist','anchor_gate_drift_mist','anchor_gate_mist_drift_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_mist_drift','conn_drift_mist','sector_mist','sector_drift','anchor_gate_mist_drift','anchor_gate_drift_mist_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_forge_drift','sector_forge','sector_drift',1,'gate_medium',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_forge_drift','sector_forge','gate_entry',-600,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_forge_drift_exit','sector_forge','gate_exit',-600,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_drift_forge','sector_drift','gate_entry',-600,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_drift_forge_exit','sector_drift','gate_exit',-600,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_forge_drift','conn_forge_drift','sector_forge','sector_drift','anchor_gate_forge_drift','anchor_gate_drift_forge_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_drift_forge','conn_forge_drift','sector_drift','sector_forge','anchor_gate_drift_forge','anchor_gate_forge_drift_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_mist_rift','sector_mist','sector_rift',1,'gate_basic',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_mist_rift','sector_mist','gate_entry',-2400,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_mist_rift_exit','sector_mist','gate_exit',-2400,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_rift_mist','sector_rift','gate_entry',-4200,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_rift_mist_exit','sector_rift','gate_exit',-4200,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_mist_rift','conn_mist_rift','sector_mist','sector_rift','anchor_gate_mist_rift','anchor_gate_rift_mist_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_rift_mist','conn_mist_rift','sector_rift','sector_mist','anchor_gate_rift_mist','anchor_gate_mist_rift_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_rift_silent','sector_rift','sector_silent',1,'gate_medium',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_rift_silent','sector_rift','gate_entry',-2400,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_rift_silent_exit','sector_rift','gate_exit',-2400,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_silent_rift','sector_silent','gate_entry',-4200,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_silent_rift_exit','sector_silent','gate_exit',-4200,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_rift_silent','conn_rift_silent','sector_rift','sector_silent','anchor_gate_rift_silent','anchor_gate_silent_rift_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_silent_rift','conn_rift_silent','sector_silent','sector_rift','anchor_gate_silent_rift','anchor_gate_rift_silent_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_helios_silent','sector_helios','sector_silent',1,'gate_heavy',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_helios_silent','sector_helios','gate_entry',-2400,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_helios_silent_exit','sector_helios','gate_exit',-2400,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_silent_helios','sector_silent','gate_entry',-2400,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_silent_helios_exit','sector_silent','gate_exit',-2400,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_helios_silent','conn_helios_silent','sector_helios','sector_silent','anchor_gate_helios_silent','anchor_gate_silent_helios_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_silent_helios','conn_helios_silent','sector_silent','sector_helios','anchor_gate_silent_helios','anchor_gate_helios_silent_exit','unlock_open_routes');
INSERT INTO connection_defs VALUES ('conn_mirror_iron','sector_mirror','sector_iron',1,'gate_medium',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_gate_mirror_iron','sector_mirror','gate_entry',-600,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_mirror_iron_exit','sector_mirror','gate_exit',-600,0,2650,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_gate_iron_mirror','sector_iron','gate_entry',-600,0,3000,3.141592653589793,120,500);
INSERT INTO anchor_defs VALUES ('anchor_gate_iron_mirror_exit','sector_iron','gate_exit',-600,0,2650,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_mirror_iron','conn_mirror_iron','sector_mirror','sector_iron','anchor_gate_mirror_iron','anchor_gate_iron_mirror_exit','unlock_open_routes');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_iron_mirror','conn_mirror_iron','sector_iron','sector_mirror','anchor_gate_iron_mirror','anchor_gate_mirror_iron_exit','unlock_open_routes');
INSERT INTO mission_defs VALUES ('story_mirror','镜湖航路重建','story',NULL,'station_mirror_hub','station_mirror_hub','unlock_open_routes',0,0,0,1,1,NULL,1);
INSERT INTO mission_prerequisites VALUES ('story_mirror','tutorial_exploration');
INSERT INTO mission_reward_defs VALUES ('story_mirror','currency_route_credit',9200);
INSERT INTO mission_reputation_rewards VALUES ('story_mirror','faction_route_council',100);
INSERT INTO mission_objective_defs VALUES ('story_mirror',0,'scan_signal',1,NULL,NULL,'signal_mirror_relic',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_objective_defs VALUES ('story_mirror',1,'deliver',5,NULL,'station_mirror_hub',NULL,NULL,NULL,NULL,'ore_mirror_crystal',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('contract_mirror_survey','镜湖异常测绘','contract',NULL,'station_mirror_hub','station_mirror_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_mirror_survey','currency_route_credit',4600);
INSERT INTO mission_reputation_rewards VALUES ('contract_mirror_survey','faction_route_council',50);
INSERT INTO anchor_defs VALUES ('anchor_mirror_contract_signal','sector_mirror','signal',-3300,100,-2600,0,50,0);
INSERT INTO signal_defs VALUES ('signal_mirror_contract','镜湖合同信号','anchor_mirror_contract_signal',2,300,'unlock_open_routes','mission_scoped',1);
INSERT INTO mission_objective_defs VALUES ('contract_mirror_survey',0,'scan_signal',1,NULL,NULL,'signal_mirror_contract',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_mirror_combat','镜湖安全清理','contract',NULL,'station_mirror_hub','station_mirror_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_mirror_combat','currency_route_credit',5900);
INSERT INTO mission_reputation_rewards VALUES ('contract_mirror_combat','faction_route_council',50);
INSERT INTO mission_objective_defs VALUES ('contract_mirror_combat',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_mirror_sentinel',NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_mirror_delivery','镜湖地区物资','contract',NULL,'station_mirror_hub','station_mirror_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_mirror_delivery','currency_route_credit',6000);
INSERT INTO mission_reputation_rewards VALUES ('contract_mirror_delivery','faction_route_council',50);
INSERT INTO mission_objective_defs VALUES ('contract_mirror_delivery',0,'deliver',40,NULL,'station_mirror_hub',NULL,NULL,NULL,NULL,'ore_mirror_crystal',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('story_forge','熔脊航路重建','story',NULL,'station_forge_hub','station_forge_hub','unlock_open_routes',0,0,0,1,1,NULL,1);
INSERT INTO mission_prerequisites VALUES ('story_forge','story_mirror');
INSERT INTO mission_reward_defs VALUES ('story_forge','currency_route_credit',10000);
INSERT INTO mission_reputation_rewards VALUES ('story_forge','faction_deepforge',100);
INSERT INTO mission_objective_defs VALUES ('story_forge',0,'scan_signal',1,NULL,NULL,'signal_forge_relic',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_objective_defs VALUES ('story_forge',1,'deliver',5,NULL,'station_forge_hub',NULL,NULL,NULL,NULL,'ore_corrosion_titanium',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('contract_forge_survey','熔脊异常测绘','contract',NULL,'station_forge_hub','station_forge_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_forge_survey','currency_route_credit',5000);
INSERT INTO mission_reputation_rewards VALUES ('contract_forge_survey','faction_deepforge',50);
INSERT INTO anchor_defs VALUES ('anchor_forge_contract_signal','sector_forge','signal',-3300,100,-2600,0,50,0);
INSERT INTO signal_defs VALUES ('signal_forge_contract','熔脊合同信号','anchor_forge_contract_signal',2,300,'unlock_open_routes','mission_scoped',1);
INSERT INTO mission_objective_defs VALUES ('contract_forge_survey',0,'scan_signal',1,NULL,NULL,'signal_forge_contract',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_forge_combat','熔脊安全清理','contract',NULL,'station_forge_hub','station_forge_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_forge_combat','currency_route_credit',6500);
INSERT INTO mission_reputation_rewards VALUES ('contract_forge_combat','faction_deepforge',50);
INSERT INTO mission_objective_defs VALUES ('contract_forge_combat',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_forge_sentinel',NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_forge_delivery','熔脊地区物资','contract',NULL,'station_forge_hub','station_forge_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_forge_delivery','currency_route_credit',6500);
INSERT INTO mission_reputation_rewards VALUES ('contract_forge_delivery','faction_deepforge',50);
INSERT INTO mission_objective_defs VALUES ('contract_forge_delivery',0,'deliver',40,NULL,'station_forge_hub',NULL,NULL,NULL,NULL,'ore_corrosion_titanium',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('story_iron','铁环航路重建','story',NULL,'station_iron_hub','station_iron_hub','unlock_open_routes',0,0,0,1,1,NULL,1);
INSERT INTO mission_prerequisites VALUES ('story_iron','story_forge');
INSERT INTO mission_reward_defs VALUES ('story_iron','currency_route_credit',11600);
INSERT INTO mission_reputation_rewards VALUES ('story_iron','faction_deepforge',100);
INSERT INTO mission_objective_defs VALUES ('story_iron',0,'scan_signal',1,NULL,NULL,'signal_iron_relic',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_objective_defs VALUES ('story_iron',1,'deliver',5,NULL,'station_iron_hub',NULL,NULL,NULL,NULL,'ore_pressure_steel',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('contract_iron_survey','铁环异常测绘','contract',NULL,'station_iron_hub','station_iron_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_iron_survey','currency_route_credit',5800);
INSERT INTO mission_reputation_rewards VALUES ('contract_iron_survey','faction_deepforge',50);
INSERT INTO anchor_defs VALUES ('anchor_iron_contract_signal','sector_iron','signal',-3300,100,-2600,0,50,0);
INSERT INTO signal_defs VALUES ('signal_iron_contract','铁环合同信号','anchor_iron_contract_signal',2,300,'unlock_open_routes','mission_scoped',1);
INSERT INTO mission_objective_defs VALUES ('contract_iron_survey',0,'scan_signal',1,NULL,NULL,'signal_iron_contract',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_iron_combat','铁环安全清理','contract',NULL,'station_iron_hub','station_iron_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_iron_combat','currency_route_credit',7700);
INSERT INTO mission_reputation_rewards VALUES ('contract_iron_combat','faction_deepforge',50);
INSERT INTO mission_objective_defs VALUES ('contract_iron_combat',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_iron_sentinel',NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_iron_delivery','铁环地区物资','contract',NULL,'station_iron_hub','station_iron_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_iron_delivery','currency_route_credit',7500);
INSERT INTO mission_reputation_rewards VALUES ('contract_iron_delivery','faction_deepforge',50);
INSERT INTO mission_objective_defs VALUES ('contract_iron_delivery',0,'deliver',40,NULL,'station_iron_hub',NULL,NULL,NULL,NULL,'ore_pressure_steel',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('story_helios','曜炉航路重建','story',NULL,'station_helios_hub','station_helios_hub','unlock_open_routes',0,0,0,1,1,NULL,1);
INSERT INTO mission_prerequisites VALUES ('story_helios','story_iron');
INSERT INTO mission_reward_defs VALUES ('story_helios','currency_route_credit',14000);
INSERT INTO mission_reputation_rewards VALUES ('story_helios','faction_deepforge',100);
INSERT INTO mission_objective_defs VALUES ('story_helios',0,'scan_signal',1,NULL,NULL,'signal_helios_relic',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_objective_defs VALUES ('story_helios',1,'deliver',5,NULL,'station_helios_hub',NULL,NULL,NULL,NULL,'ore_solar_core',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('contract_helios_survey','曜炉异常测绘','contract',NULL,'station_helios_hub','station_helios_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_helios_survey','currency_route_credit',7000);
INSERT INTO mission_reputation_rewards VALUES ('contract_helios_survey','faction_deepforge',50);
INSERT INTO anchor_defs VALUES ('anchor_helios_contract_signal','sector_helios','signal',-3300,100,-2600,0,50,0);
INSERT INTO signal_defs VALUES ('signal_helios_contract','曜炉合同信号','anchor_helios_contract_signal',4,300,'unlock_open_routes','mission_scoped',1);
INSERT INTO mission_objective_defs VALUES ('contract_helios_survey',0,'scan_signal',1,NULL,NULL,'signal_helios_contract',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_helios_combat','曜炉安全清理','contract',NULL,'station_helios_hub','station_helios_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_helios_combat','currency_route_credit',9500);
INSERT INTO mission_reputation_rewards VALUES ('contract_helios_combat','faction_deepforge',50);
INSERT INTO mission_objective_defs VALUES ('contract_helios_combat',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_helios_sentinel',NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_helios_delivery','曜炉地区物资','contract',NULL,'station_helios_hub','station_helios_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_helios_delivery','currency_route_credit',9000);
INSERT INTO mission_reputation_rewards VALUES ('contract_helios_delivery','faction_deepforge',50);
INSERT INTO mission_objective_defs VALUES ('contract_helios_delivery',0,'deliver',40,NULL,'station_helios_hub',NULL,NULL,NULL,NULL,'ore_solar_core',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('story_drift','游弋渡航路重建','story',NULL,'station_drift_hub','station_drift_hub','unlock_open_routes',0,0,0,1,1,NULL,1);
INSERT INTO mission_prerequisites VALUES ('story_drift','story_helios');
INSERT INTO mission_reward_defs VALUES ('story_drift','currency_route_credit',10000);
INSERT INTO mission_reputation_rewards VALUES ('story_drift','faction_roaming_alliance',100);
INSERT INTO mission_objective_defs VALUES ('story_drift',0,'scan_signal',1,NULL,NULL,'signal_drift_relic',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_objective_defs VALUES ('story_drift',1,'deliver',5,NULL,'station_drift_hub',NULL,NULL,NULL,NULL,'material_feather_alloy',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('contract_drift_survey','游弋渡异常测绘','contract',NULL,'station_drift_hub','station_drift_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_drift_survey','currency_route_credit',5000);
INSERT INTO mission_reputation_rewards VALUES ('contract_drift_survey','faction_roaming_alliance',50);
INSERT INTO anchor_defs VALUES ('anchor_drift_contract_signal','sector_drift','signal',-3300,100,-2600,0,50,0);
INSERT INTO signal_defs VALUES ('signal_drift_contract','游弋渡合同信号','anchor_drift_contract_signal',2,300,'unlock_open_routes','mission_scoped',1);
INSERT INTO mission_objective_defs VALUES ('contract_drift_survey',0,'scan_signal',1,NULL,NULL,'signal_drift_contract',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_drift_combat','游弋渡安全清理','contract',NULL,'station_drift_hub','station_drift_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_drift_combat','currency_route_credit',6500);
INSERT INTO mission_reputation_rewards VALUES ('contract_drift_combat','faction_roaming_alliance',50);
INSERT INTO mission_objective_defs VALUES ('contract_drift_combat',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_drift_sentinel',NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_drift_delivery','游弋渡地区物资','contract',NULL,'station_drift_hub','station_drift_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_drift_delivery','currency_route_credit',6500);
INSERT INTO mission_reputation_rewards VALUES ('contract_drift_delivery','faction_roaming_alliance',50);
INSERT INTO mission_objective_defs VALUES ('contract_drift_delivery',0,'deliver',40,NULL,'station_drift_hub',NULL,NULL,NULL,NULL,'material_feather_alloy',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('story_mist','雾帆航路重建','story',NULL,'station_mist_hub','station_mist_hub','unlock_open_routes',0,0,0,1,1,NULL,1);
INSERT INTO mission_prerequisites VALUES ('story_mist','story_drift');
INSERT INTO mission_reward_defs VALUES ('story_mist','currency_route_credit',12400);
INSERT INTO mission_reputation_rewards VALUES ('story_mist','faction_roaming_alliance',100);
INSERT INTO mission_objective_defs VALUES ('story_mist',0,'scan_signal',1,NULL,NULL,'signal_mist_relic',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_objective_defs VALUES ('story_mist',1,'deliver',5,NULL,'station_mist_hub',NULL,NULL,NULL,NULL,'component_mist_fiber',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('contract_mist_survey','雾帆异常测绘','contract',NULL,'station_mist_hub','station_mist_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_mist_survey','currency_route_credit',6200);
INSERT INTO mission_reputation_rewards VALUES ('contract_mist_survey','faction_roaming_alliance',50);
INSERT INTO anchor_defs VALUES ('anchor_mist_contract_signal','sector_mist','signal',-3300,100,-2600,0,50,0);
INSERT INTO signal_defs VALUES ('signal_mist_contract','雾帆合同信号','anchor_mist_contract_signal',4,300,'unlock_open_routes','mission_scoped',1);
INSERT INTO mission_objective_defs VALUES ('contract_mist_survey',0,'scan_signal',1,NULL,NULL,'signal_mist_contract',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_mist_combat','雾帆安全清理','contract',NULL,'station_mist_hub','station_mist_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_mist_combat','currency_route_credit',8300);
INSERT INTO mission_reputation_rewards VALUES ('contract_mist_combat','faction_roaming_alliance',50);
INSERT INTO mission_objective_defs VALUES ('contract_mist_combat',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_mist_sentinel',NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_mist_delivery','雾帆地区物资','contract',NULL,'station_mist_hub','station_mist_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_mist_delivery','currency_route_credit',8000);
INSERT INTO mission_reputation_rewards VALUES ('contract_mist_delivery','faction_roaming_alliance',50);
INSERT INTO mission_objective_defs VALUES ('contract_mist_delivery',0,'deliver',40,NULL,'station_mist_hub',NULL,NULL,NULL,NULL,'component_mist_fiber',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('story_rift','断弦航路重建','story',NULL,'station_rift_hub','station_rift_hub','unlock_open_routes',0,0,0,1,1,NULL,1);
INSERT INTO mission_prerequisites VALUES ('story_rift','story_mist');
INSERT INTO mission_reward_defs VALUES ('story_rift','currency_route_credit',14000);
INSERT INTO mission_reputation_rewards VALUES ('story_rift','faction_roaming_alliance',100);
INSERT INTO mission_objective_defs VALUES ('story_rift',0,'scan_signal',1,NULL,NULL,'signal_rift_relic',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_objective_defs VALUES ('story_rift',1,'deliver',5,NULL,'station_rift_hub',NULL,NULL,NULL,NULL,'ore_phase_stone',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('contract_rift_survey','断弦异常测绘','contract',NULL,'station_rift_hub','station_rift_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_rift_survey','currency_route_credit',7000);
INSERT INTO mission_reputation_rewards VALUES ('contract_rift_survey','faction_roaming_alliance',50);
INSERT INTO anchor_defs VALUES ('anchor_rift_contract_signal','sector_rift','signal',-3300,100,-2600,0,50,0);
INSERT INTO signal_defs VALUES ('signal_rift_contract','断弦合同信号','anchor_rift_contract_signal',4,300,'unlock_open_routes','mission_scoped',1);
INSERT INTO mission_objective_defs VALUES ('contract_rift_survey',0,'scan_signal',1,NULL,NULL,'signal_rift_contract',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_rift_combat','断弦安全清理','contract',NULL,'station_rift_hub','station_rift_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_rift_combat','currency_route_credit',9500);
INSERT INTO mission_reputation_rewards VALUES ('contract_rift_combat','faction_roaming_alliance',50);
INSERT INTO mission_objective_defs VALUES ('contract_rift_combat',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_rift_sentinel',NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_rift_delivery','断弦地区物资','contract',NULL,'station_rift_hub','station_rift_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_rift_delivery','currency_route_credit',9000);
INSERT INTO mission_reputation_rewards VALUES ('contract_rift_delivery','faction_roaming_alliance',50);
INSERT INTO mission_objective_defs VALUES ('contract_rift_delivery',0,'deliver',40,NULL,'station_rift_hub',NULL,NULL,NULL,NULL,'ore_phase_stone',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('story_silent','静默渊航路重建','story',NULL,'station_silent_hub','station_silent_hub','unlock_open_routes',0,0,0,1,1,NULL,1);
INSERT INTO mission_prerequisites VALUES ('story_silent','story_rift');
INSERT INTO mission_reward_defs VALUES ('story_silent','currency_route_credit',15600);
INSERT INTO mission_reputation_rewards VALUES ('story_silent','faction_silent_relics',100);
INSERT INTO mission_objective_defs VALUES ('story_silent',0,'scan_signal',1,NULL,NULL,'signal_silent_relic',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_objective_defs VALUES ('story_silent',1,'deliver',5,NULL,'station_silent_hub',NULL,NULL,NULL,NULL,'component_relic_logic',NULL,NULL,0,1);
INSERT INTO mission_defs VALUES ('contract_silent_survey','静默渊异常测绘','contract',NULL,'station_silent_hub','station_silent_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_silent_survey','currency_route_credit',7800);
INSERT INTO mission_reputation_rewards VALUES ('contract_silent_survey','faction_silent_relics',50);
INSERT INTO anchor_defs VALUES ('anchor_silent_contract_signal','sector_silent','signal',-3300,100,-2600,0,50,0);
INSERT INTO signal_defs VALUES ('signal_silent_contract','静默渊合同信号','anchor_silent_contract_signal',4,300,'unlock_open_routes','mission_scoped',1);
INSERT INTO mission_objective_defs VALUES ('contract_silent_survey',0,'scan_signal',1,NULL,NULL,'signal_silent_contract',NULL,NULL,NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_silent_combat','静默渊安全清理','contract',NULL,'station_silent_hub','station_silent_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_silent_combat','currency_route_credit',10700);
INSERT INTO mission_reputation_rewards VALUES ('contract_silent_combat','faction_silent_relics',50);
INSERT INTO mission_objective_defs VALUES ('contract_silent_combat',0,'destroy_spawn',1,NULL,NULL,NULL,NULL,'spawn_silent_sentinel',NULL,NULL,NULL,NULL,0,0);
INSERT INTO mission_defs VALUES ('contract_silent_delivery','静默渊地区物资','contract',NULL,'station_silent_hub','station_silent_hub','unlock_open_routes',1,300,1800,3,1,1800,1);
INSERT INTO mission_reward_defs VALUES ('contract_silent_delivery','currency_route_credit',10000);
INSERT INTO mission_reputation_rewards VALUES ('contract_silent_delivery','faction_silent_relics',50);
INSERT INTO mission_objective_defs VALUES ('contract_silent_delivery',0,'deliver',40,NULL,'station_silent_hub',NULL,NULL,NULL,NULL,'component_relic_logic',NULL,NULL,0,1);
INSERT INTO research_defs VALUES ('research_tech_ii','专业模块试验','faction_route_council',100,6000,'unlock_tech_ii','story_mirror');
INSERT INTO research_inputs VALUES ('research_tech_ii','component_anchor_ceramic',4);
INSERT INTO research_prerequisites VALUES ('research_tech_ii','unlock_open_routes');
INSERT INTO research_defs VALUES ('research_hulls','大型舰体工艺','faction_deepforge',100,10000,'unlock_hulls_advanced','story_forge');
INSERT INTO research_inputs VALUES ('research_hulls','material_dense_alloy',10);
INSERT INTO research_prerequisites VALUES ('research_hulls','unlock_open_routes');
INSERT INTO research_defs VALUES ('research_base','个人港口许可','faction_deepforge',100,3000,'unlock_base_services','story_forge');
INSERT INTO research_inputs VALUES ('research_base','component_power_cell',3);
INSERT INTO research_prerequisites VALUES ('research_base','unlock_open_routes');
INSERT INTO research_defs VALUES ('research_tech_iii','遗构适配解析','faction_silent_relics',100,25000,'unlock_tech_iii','story_silent');
INSERT INTO research_inputs VALUES ('research_tech_iii','component_relic_logic',10);
INSERT INTO research_prerequisites VALUES ('research_tech_iii','unlock_tech_ii');
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_shuttle_swift','雨燕级穿梭器裸舰制造','shuttle_swift','unlock_basic_services',1980);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_shuttle_swift','material_structural_stock',20);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_shuttle_swift','component_thruster_cluster',1);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_shuttle_swift','component_power_cell',2);
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_frigate_lantern','提灯级探索护卫舰裸舰制造','frigate_lantern','unlock_lantern_purchase',7920);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_frigate_lantern','material_structural_stock',28);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_frigate_lantern','component_thruster_cluster',1);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_frigate_lantern','component_power_cell',3);
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_frigate_kestrel','游隼级战斗护卫舰裸舰制造','frigate_kestrel','unlock_kestrel_purchase',10560);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_frigate_kestrel','material_structural_stock',36);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_frigate_kestrel','component_thruster_cluster',1);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_frigate_kestrel','component_power_cell',3);
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_miner_anvil','铁砧级采矿舰裸舰制造','miner_anvil','unlock_miner_purchase',13200);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_miner_anvil','material_structural_stock',130);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_miner_anvil','component_thruster_cluster',2);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_miner_anvil','component_power_cell',5);
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_destroyer_raptor','矛隼级驱逐舰裸舰制造','destroyer_raptor','unlock_hulls_advanced',19800);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_destroyer_raptor','material_structural_stock',84);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_destroyer_raptor','component_thruster_cluster',1);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_destroyer_raptor','component_power_cell',6);
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_cruiser_horizon','远际级巡洋舰裸舰制造','cruiser_horizon','unlock_hulls_advanced',59400);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_cruiser_horizon','material_structural_stock',360);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_cruiser_horizon','component_thruster_cluster',6);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_cruiser_horizon','component_power_cell',11);
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_battleship_bastion','磐垒级战列舰裸舰制造','battleship_bastion','unlock_hulls_advanced',231000);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_battleship_bastion','material_structural_stock',1600);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_battleship_bastion','component_thruster_cluster',26);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_battleship_bastion','component_power_cell',22);
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_transport_caravan','长旅级运输舰裸舰制造','transport_caravan','unlock_hulls_advanced',28050);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_transport_caravan','material_structural_stock',240);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_transport_caravan','component_thruster_cluster',4);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_transport_caravan','component_power_cell',7);
INSERT INTO hull_recipe_defs VALUES ('hull_recipe_support_weaver','织桥级支援舰裸舰制造','support_weaver','unlock_hulls_advanced',52800);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_support_weaver','material_structural_stock',320);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_support_weaver','component_thruster_cluster',5);
INSERT INTO hull_recipe_inputs VALUES ('hull_recipe_support_weaver','component_power_cell',18);
INSERT INTO base_module_defs VALUES ('base_repair','维修坞','unlock_base_services',5000,'repair',1.1);
INSERT INTO base_module_inputs VALUES ('base_repair','material_dense_alloy',10);
INSERT INTO base_module_inputs VALUES ('base_repair','component_power_cell',4);
INSERT INTO base_module_defs VALUES ('base_industry','工业检测台','unlock_base_services',8000,'industry',1.1);
INSERT INTO base_module_inputs VALUES ('base_industry','material_dense_alloy',10);
INSERT INTO base_module_inputs VALUES ('base_industry','component_power_cell',4);
INSERT INTO base_module_defs VALUES ('base_navigation','航路资料站','unlock_base_services',4000,'navigation',1.1);
INSERT INTO base_module_inputs VALUES ('base_navigation','material_dense_alloy',10);
INSERT INTO base_module_inputs VALUES ('base_navigation','component_power_cell',4);
INSERT INTO base_module_defs VALUES ('base_warehouse','货运收集站','unlock_base_services',4000,'warehouse',1.1);
INSERT INTO base_module_inputs VALUES ('base_warehouse','material_dense_alloy',10);
INSERT INTO base_module_inputs VALUES ('base_warehouse','component_power_cell',4);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_anchor_port','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_anchor_port','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_anchor_port','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_anchor_port','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_anchor_port','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_anchor_port','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_anchor_port','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_anchor_port','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_echo_depot','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_echo_depot','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_echo_depot','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_echo_depot','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_echo_depot','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_echo_depot','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_echo_depot','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_echo_depot','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ore_ferrosilicate','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ore_conductive_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ammo_kinetic_slug_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','repair_kit_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','material_structural_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_kinetic_needle_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mirror_hub','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_structural','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_conductive','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_dense','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_weapon_frame','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_power_cell','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_fire_control','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scan_frame','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_control','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_projection_control','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_sensor_core_basic','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_ring_basic','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thruster_basic','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_mesh_basic','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pressure_stock_basic','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_feather_alloy_basic','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_focus_basic','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_ammo','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_kit','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_kinetic_needle_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_sunline_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_breakwater_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_shield_lattice_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_pressure_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_feather_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_engine_vector_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scanner_beacon_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_sift_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_support_patch_i','station_mirror_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_mirror_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_mirror_hub','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_mirror_hub','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_mirror_hub','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_mirror_hub','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_mirror_hub','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_mirror_hub','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ore_ferrosilicate','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ore_conductive_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ammo_kinetic_slug_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','repair_kit_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','material_structural_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_kinetic_needle_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_forge_hub','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_structural','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_conductive','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_dense','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_weapon_frame','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_power_cell','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_fire_control','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scan_frame','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_control','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_projection_control','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_sensor_core_basic','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_ring_basic','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thruster_basic','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_mesh_basic','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pressure_stock_basic','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_feather_alloy_basic','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_focus_basic','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_ammo','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_kit','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_kinetic_needle_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_sunline_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_breakwater_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_shield_lattice_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_pressure_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_feather_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_engine_vector_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scanner_beacon_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_sift_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_support_patch_i','station_forge_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_forge_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_forge_hub','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_forge_hub','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_forge_hub','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_forge_hub','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_forge_hub','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_forge_hub','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ore_ferrosilicate','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ore_conductive_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ammo_kinetic_slug_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','repair_kit_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','material_structural_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_kinetic_needle_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_iron_hub','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_structural','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_conductive','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_dense','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_weapon_frame','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_power_cell','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_fire_control','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scan_frame','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_control','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_projection_control','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_sensor_core_basic','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_ring_basic','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thruster_basic','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_mesh_basic','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pressure_stock_basic','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_feather_alloy_basic','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_focus_basic','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_ammo','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_kit','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_kinetic_needle_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_sunline_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_breakwater_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_shield_lattice_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_pressure_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_feather_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_engine_vector_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scanner_beacon_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_sift_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_support_patch_i','station_iron_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_iron_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_iron_hub','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_iron_hub','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_iron_hub','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_iron_hub','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_iron_hub','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_iron_hub','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ore_ferrosilicate','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ore_conductive_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ammo_kinetic_slug_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','repair_kit_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','material_structural_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_kinetic_needle_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_helios_hub','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_structural','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_conductive','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_dense','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_weapon_frame','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_power_cell','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_fire_control','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scan_frame','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_control','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_projection_control','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_sensor_core_basic','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_ring_basic','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thruster_basic','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_mesh_basic','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pressure_stock_basic','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_feather_alloy_basic','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_focus_basic','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_ammo','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_kit','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_kinetic_needle_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_sunline_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_breakwater_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_shield_lattice_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_pressure_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_feather_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_engine_vector_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scanner_beacon_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_sift_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_support_patch_i','station_helios_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_helios_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_helios_hub','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_helios_hub','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_helios_hub','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_helios_hub','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_helios_hub','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_helios_hub','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ore_ferrosilicate','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ore_conductive_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ammo_kinetic_slug_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','repair_kit_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','material_structural_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_kinetic_needle_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_drift_hub','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_structural','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_conductive','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_dense','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_weapon_frame','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_power_cell','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_fire_control','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scan_frame','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_control','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_projection_control','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_sensor_core_basic','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_ring_basic','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thruster_basic','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_mesh_basic','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pressure_stock_basic','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_feather_alloy_basic','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_focus_basic','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_ammo','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_kit','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_kinetic_needle_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_sunline_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_breakwater_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_shield_lattice_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_pressure_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_feather_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_engine_vector_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scanner_beacon_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_sift_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_support_patch_i','station_drift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_drift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_drift_hub','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_drift_hub','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_drift_hub','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_drift_hub','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_drift_hub','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_drift_hub','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ore_ferrosilicate','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ore_conductive_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ammo_kinetic_slug_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','repair_kit_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','material_structural_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_kinetic_needle_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_mist_hub','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_structural','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_conductive','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_dense','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_weapon_frame','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_power_cell','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_fire_control','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scan_frame','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_control','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_projection_control','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_sensor_core_basic','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_ring_basic','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thruster_basic','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_mesh_basic','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pressure_stock_basic','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_feather_alloy_basic','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_focus_basic','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_ammo','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_kit','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_kinetic_needle_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_sunline_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_breakwater_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_shield_lattice_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_pressure_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_feather_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_engine_vector_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scanner_beacon_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_sift_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_support_patch_i','station_mist_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_mist_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_mist_hub','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_mist_hub','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_mist_hub','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_mist_hub','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_mist_hub','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_mist_hub','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ore_ferrosilicate','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ore_conductive_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ammo_kinetic_slug_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','repair_kit_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','material_structural_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_kinetic_needle_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_rift_hub','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_structural','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_conductive','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_dense','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_weapon_frame','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_power_cell','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_fire_control','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scan_frame','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_control','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_projection_control','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_sensor_core_basic','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_ring_basic','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thruster_basic','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_mesh_basic','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pressure_stock_basic','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_feather_alloy_basic','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_focus_basic','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_ammo','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_kit','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_kinetic_needle_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_sunline_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_breakwater_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_shield_lattice_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_pressure_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_feather_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_engine_vector_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scanner_beacon_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_sift_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_support_patch_i','station_rift_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_rift_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_rift_hub','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_rift_hub','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_rift_hub','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_rift_hub','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_rift_hub','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_rift_hub','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ore_ferrosilicate','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ore_conductive_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','material_dense_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_relic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ammo_kinetic_slug_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','repair_kit_i','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','material_structural_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','material_conductive_medium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_weapon_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_power_cell','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_fire_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_scan_frame','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_industry_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_projection_control','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_sensor_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_pulse_ring','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_thruster_cluster','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_repair_mesh','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','material_pressure_stock','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','material_feather_alloy','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_thermal_focus','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_kinetic_needle_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_thermal_sunline_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_pulse_breakwater_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_shield_lattice_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_armor_pressure_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_armor_feather_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_engine_vector_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_scanner_beacon_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_industry_sift_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_support_patch_i','unlock_open_routes',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_anchor_ceramic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ore_echo_silica','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ore_mirror_crystal','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ore_corrosion_titanium','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ore_pressure_steel','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ore_solar_core','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_mist_fiber','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','ore_phase_stone','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','component_relic_logic','unlock_open_routes',1000,1000,3000,250,2000,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_kinetic_needle_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_kinetic_needle_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_thermal_sunline_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_thermal_sunline_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_pulse_breakwater_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_pulse_breakwater_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_shield_lattice_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_shield_lattice_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_armor_pressure_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_armor_pressure_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_armor_feather_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_armor_feather_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_engine_vector_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_engine_vector_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_scanner_beacon_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_scanner_beacon_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_industry_sift_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_industry_sift_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_support_patch_ii','unlock_tech_ii',10,10,30,2,20,1,1);
INSERT INTO station_stock_defs VALUES ('station_silent_hub','module_support_patch_iii','unlock_tech_iii',10,10,30,2,20,1,1);
INSERT INTO recipe_access_defs VALUES ('recipe_structural','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_conductive','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_dense','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_weapon_frame','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_power_cell','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_fire_control','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scan_frame','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_control','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_projection_control','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_sensor_core_basic','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_ring_basic','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thruster_basic','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_mesh_basic','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pressure_stock_basic','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_feather_alloy_basic','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_focus_basic','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_ammo','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_repair_kit','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_kinetic_needle_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_thermal_sunline_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_pulse_breakwater_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_shield_lattice_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_pressure_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_armor_feather_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_engine_vector_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_scanner_beacon_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_industry_sift_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_support_patch_i','station_silent_hub','unlock_open_routes');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_kinetic_needle_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_thermal_sunline_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_pulse_breakwater_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_shield_lattice_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_pressure_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_armor_feather_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_engine_vector_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_scanner_beacon_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_industry_sift_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_ii','station_silent_hub','unlock_tech_ii');
INSERT INTO recipe_access_defs VALUES ('recipe_module_support_patch_iii','station_silent_hub','unlock_tech_iii');
INSERT INTO station_ship_stock_defs VALUES ('station_silent_hub','destroyer_raptor','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_silent_hub','cruiser_horizon','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_silent_hub','battleship_bastion','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_silent_hub','transport_caravan','unlock_hulls_advanced',2,2,4,1);
INSERT INTO station_ship_stock_defs VALUES ('station_silent_hub','support_weaver','unlock_hulls_advanced',2,2,4,1);
INSERT INTO mission_reputation_rewards VALUES ('tutorial_flight','faction_route_council',20);
INSERT INTO mission_reputation_rewards VALUES ('tutorial_scan_gate','faction_route_council',20);
INSERT INTO mission_reputation_rewards VALUES ('tutorial_mining_delivery','faction_route_council',20);
INSERT INTO mission_reputation_rewards VALUES ('tutorial_combat','faction_route_council',20);
INSERT INTO mission_reputation_rewards VALUES ('tutorial_exploration','faction_route_council',20);
INSERT INTO mission_reputation_rewards VALUES ('contract_mining_iron','faction_route_council',25);
INSERT INTO mission_reputation_rewards VALUES ('contract_survey_echo','faction_route_council',25);
INSERT INTO mission_reputation_rewards VALUES ('contract_patrol_echo','faction_route_council',25);
UPDATE catalog_meta SET content_version='v0.4-singleplayer',ruleset_version='singleplayer_v0_4',schema_version=3,source_document=source_document||';doc/23-完整单人版交付范围与实现清单.md';

-- Presentation-only defaults required by the original asset effects.
INSERT INTO presentation_defs VALUES ('fx_beam_width_m',NULL,0.32,'m');
INSERT INTO presentation_defs VALUES ('fx_beam_lifetime_s',NULL,0.12,'s');
INSERT INTO presentation_defs VALUES ('fx_explosion_lifetime_s',NULL,1.1,'s');
INSERT INTO presentation_defs VALUES ('fx_shield_lifetime_s',NULL,0.35,'s');
INSERT INTO presentation_defs VALUES ('fx_explosion_radius_ship_multiplier',NULL,0.65,'ratio');
INSERT INTO presentation_defs VALUES ('fx_wormhole_intensity',NULL,2.2,'emission');
INSERT INTO presentation_defs VALUES ('fx_engine_emission',NULL,3.0,'emission');
DELETE FROM station_ship_stock_defs WHERE ship_id='battleship_bastion' AND station_id NOT IN ('station_forge_hub','station_iron_hub','station_helios_hub','station_silent_hub');
DELETE FROM station_ship_stock_defs WHERE station_id='station_echo_depot' AND ship_id IN ('cruiser_horizon','support_weaver');
UPDATE station_defs SET buyback_budget_credit=300000 WHERE station_id IN ('station_forge_hub','station_iron_hub','station_helios_hub','station_silent_hub');

-- Scanned anomaly sites unlock finite local extraction; purchases remain an alternate source.
INSERT INTO unlock_defs VALUES ('unlock_site_mirror','已解析mirror异常',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_mirror_relic','unlock_site_mirror');
UPDATE resource_node_locations SET required_unlock_id='unlock_site_mirror' WHERE node_id='node_mirror_special';
INSERT INTO unlock_defs VALUES ('unlock_site_forge','已解析forge异常',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_forge_relic','unlock_site_forge');
UPDATE resource_node_locations SET required_unlock_id='unlock_site_forge' WHERE node_id='node_forge_special';
INSERT INTO unlock_defs VALUES ('unlock_site_iron','已解析iron异常',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_iron_relic','unlock_site_iron');
UPDATE resource_node_locations SET required_unlock_id='unlock_site_iron' WHERE node_id='node_iron_special';
INSERT INTO unlock_defs VALUES ('unlock_site_helios','已解析helios异常',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_helios_relic','unlock_site_helios');
UPDATE resource_node_locations SET required_unlock_id='unlock_site_helios' WHERE node_id='node_helios_special';
INSERT INTO unlock_defs VALUES ('unlock_site_drift','已解析drift异常',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_drift_relic','unlock_site_drift');
UPDATE resource_node_locations SET required_unlock_id='unlock_site_drift' WHERE node_id='node_drift_special';
INSERT INTO unlock_defs VALUES ('unlock_site_mist','已解析mist异常',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_mist_relic','unlock_site_mist');
UPDATE resource_node_locations SET required_unlock_id='unlock_site_mist' WHERE node_id='node_mist_special';
INSERT INTO unlock_defs VALUES ('unlock_site_rift','已解析rift异常',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_rift_relic','unlock_site_rift');
UPDATE resource_node_locations SET required_unlock_id='unlock_site_rift' WHERE node_id='node_rift_special';
INSERT INTO unlock_defs VALUES ('unlock_site_silent','已解析silent异常',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_silent_relic','unlock_site_silent');
UPDATE resource_node_locations SET required_unlock_id='unlock_site_silent' WHERE node_id='node_silent_special';
INSERT INTO unlock_defs VALUES ('unlock_wandering_mirror_mist','镜湖—雾帆游离虫洞发现',0);
INSERT INTO signal_unlock_rewards VALUES ('signal_mirror_relic','unlock_wandering_mirror_mist');
INSERT INTO connection_defs VALUES ('conn_wandering_mirror_mist','sector_mirror','sector_mist',1,'gate_wandering_candidate',NULL,NULL);
INSERT INTO anchor_defs VALUES ('anchor_wandering_mirror','sector_mirror','gate_entry',-5500,800,2200,3.141592653589793,120,400);
INSERT INTO anchor_defs VALUES ('anchor_wandering_mirror_exit','sector_mirror','gate_exit',-5500,800,1850,0,50,0);
INSERT INTO anchor_defs VALUES ('anchor_wandering_mist','sector_mist','gate_entry',-5500,800,2200,3.141592653589793,120,400);
INSERT INTO anchor_defs VALUES ('anchor_wandering_mist_exit','sector_mist','gate_exit',-5500,800,1850,0,50,0);
INSERT INTO gate_endpoint_defs VALUES ('endpoint_wandering_mirror_mist','conn_wandering_mirror_mist','sector_mirror','sector_mist','anchor_wandering_mirror','anchor_wandering_mist_exit','unlock_wandering_mirror_mist');
INSERT INTO gate_endpoint_defs VALUES ('endpoint_wandering_mist_mirror','conn_wandering_mirror_mist','sector_mist','sector_mirror','anchor_wandering_mist','anchor_wandering_mirror_exit','unlock_wandering_mirror_mist');
INSERT INTO presentation_defs VALUES ('fx_engine_particle_lifetime_s',NULL,0.6,'s');
INSERT INTO rule_parameters VALUES ('business_quantity_limit',10000,NULL,'unit');

-- The industry facility gives a bounded 2% fee reduction; 10% creates a chain arbitrage.
UPDATE base_module_defs SET effect_multiplier=1.02 WHERE base_module_id='base_industry';
-- Docked observation camera is outside the original station hull.
INSERT INTO presentation_defs VALUES ('station_camera_distance_m',NULL,500,'m');
INSERT INTO presentation_defs VALUES ('station_camera_height_m',NULL,220,'m');
INSERT INTO presentation_defs VALUES ('station_camera_fov_deg',NULL,60,'deg');
INSERT INTO rule_parameters VALUES ('reputation_discount_full_at',1000,NULL,'reputation');
-- Shared effects/camera defaults: presentation only, consumed by the rendering host.
INSERT INTO presentation_defs VALUES ('projectile_radius_m',NULL,0.25,'m');
INSERT INTO presentation_defs VALUES ('projectile_initial_trail_m',NULL,8,'m');
INSERT INTO presentation_defs VALUES ('projectile_trail_m',NULL,18,'m');
INSERT INTO presentation_defs VALUES ('ray_fade_s',NULL,0.15,'s');
INSERT INTO presentation_defs VALUES ('projectile_emission',NULL,4,'emission');
INSERT INTO presentation_defs VALUES ('camera_orbit_pitch_limit_rad',NULL,1.2,'rad');
INSERT INTO presentation_defs VALUES ('camera_zoom_scroll_factor',NULL,1.1,'ratio');
-- Regional advanced shipyards reflect originating faction technology.
-- Silent exchange imports the heavy human hull; it is not a relic player hull blueprint.
DELETE FROM station_ship_stock_defs
WHERE ship_id IN (SELECT ship_id FROM ship_role_defs WHERE required_unlock_id='unlock_hulls_advanced')
AND NOT EXISTS(SELECT 1 FROM station_defs s JOIN ship_role_defs r ON r.ship_id=station_ship_stock_defs.ship_id
WHERE s.station_id=station_ship_stock_defs.station_id AND s.faction_id=r.faction_id)
AND NOT(ship_id='battleship_bastion' AND station_id='station_silent_hub');
-- Relic III products require completed research and production or the relic exchange, not universal ordinary stores.
UPDATE station_stock_defs SET allow_buy=0 WHERE item_id LIKE '%_iii' AND station_id<>'station_silent_hub';

-- Schema4 additive encounter and salvage content. Earlier rows stay byte-equivalent.
INSERT INTO npc_defs VALUES
('npc_encounter_scout_l2_high','npc_scout_light',2,'risk_high'),
('npc_encounter_scout_l1_high','npc_scout_light',1,'risk_high'),
('npc_encounter_scout_l3_medium','npc_scout_light',3,'risk_medium'),
('npc_encounter_scout_l4_medium','npc_scout_light',4,'risk_medium'),
('npc_encounter_scout_l6_low','npc_scout_light',6,'risk_low'),
('npc_encounter_scout_l8_low','npc_scout_light',8,'risk_low');
INSERT INTO anchor_defs VALUES
('anchor_anchor_patrol_leader','sector_anchor','npc_spawn',6800.0,400.0,-6000.0,0.0,50.0,0.0),
('anchor_anchor_patrol_leader_patrol','sector_anchor','patrol',6900.0,400.0,-5850.0,0.0,50.0,0.0),
('anchor_anchor_patrol_escort','sector_anchor','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_anchor_patrol_escort_patrol','sector_anchor','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0),
('anchor_echo_patrol_escort','sector_echo','npc_spawn',5400.0,400.0,-4500.0,0.0,50.0,0.0),
('anchor_echo_patrol_escort_patrol','sector_echo','patrol',5500.0,400.0,-4350.0,0.0,50.0,0.0),
('anchor_mirror_patrol_escort','sector_mirror','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_mirror_patrol_escort_patrol','sector_mirror','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0),
('anchor_forge_patrol_escort','sector_forge','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_forge_patrol_escort_patrol','sector_forge','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0),
('anchor_iron_patrol_escort','sector_iron','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_iron_patrol_escort_patrol','sector_iron','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0),
('anchor_helios_patrol_escort','sector_helios','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_helios_patrol_escort_patrol','sector_helios','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0),
('anchor_drift_patrol_escort','sector_drift','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_drift_patrol_escort_patrol','sector_drift','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0),
('anchor_mist_patrol_escort','sector_mist','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_mist_patrol_escort_patrol','sector_mist','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0),
('anchor_rift_patrol_escort','sector_rift','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_rift_patrol_escort_patrol','sector_rift','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0),
('anchor_silent_patrol_escort','sector_silent','npc_spawn',7000.0,500.0,-6000.0,0.0,50.0,0.0),
('anchor_silent_patrol_escort_patrol','sector_silent','patrol',7100.0,500.0,-5850.0,0.0,50.0,0.0);
INSERT INTO npc_spawn_defs VALUES
('spawn_anchor_patrol_leader','npc_encounter_scout_l2_high','sector_anchor','anchor_anchor_patrol_leader','behavior_scout','ambient','unlock_combat_contracts',600.0,1,1),
('spawn_anchor_patrol_escort','npc_encounter_scout_l1_high','sector_anchor','anchor_anchor_patrol_escort','behavior_scout','ambient','unlock_combat_contracts',600.0,1,1),
('spawn_echo_patrol_escort','npc_encounter_scout_l2_high','sector_echo','anchor_echo_patrol_escort','behavior_scout','ambient','unlock_exploration_contracts',600.0,1,1),
('spawn_mirror_patrol_escort','npc_encounter_scout_l2_high','sector_mirror','anchor_mirror_patrol_escort','behavior_scout','ambient','unlock_open_routes',600.0,1,1),
('spawn_forge_patrol_escort','npc_encounter_scout_l3_medium','sector_forge','anchor_forge_patrol_escort','behavior_scout','ambient','unlock_open_routes',600.0,1,1),
('spawn_iron_patrol_escort','npc_encounter_scout_l4_medium','sector_iron','anchor_iron_patrol_escort','behavior_scout','ambient','unlock_open_routes',600.0,1,1),
('spawn_helios_patrol_escort','npc_encounter_scout_l6_low','sector_helios','anchor_helios_patrol_escort','behavior_scout','ambient','unlock_open_routes',600.0,1,1),
('spawn_drift_patrol_escort','npc_encounter_scout_l3_medium','sector_drift','anchor_drift_patrol_escort','behavior_scout','ambient','unlock_open_routes',600.0,1,1),
('spawn_mist_patrol_escort','npc_encounter_scout_l6_low','sector_mist','anchor_mist_patrol_escort','behavior_scout','ambient','unlock_open_routes',600.0,1,1),
('spawn_rift_patrol_escort','npc_encounter_scout_l6_low','sector_rift','anchor_rift_patrol_escort','behavior_scout','ambient','unlock_open_routes',600.0,1,1),
('spawn_silent_patrol_escort','npc_encounter_scout_l8_low','sector_silent','anchor_silent_patrol_escort','behavior_scout','ambient','unlock_open_routes',600.0,1,1);
INSERT INTO npc_patrol_points VALUES
('spawn_anchor_patrol_leader',0,'anchor_anchor_patrol_leader_patrol'),
('spawn_anchor_patrol_escort',0,'anchor_anchor_patrol_escort_patrol'),
('spawn_echo_patrol_escort',0,'anchor_echo_patrol_escort_patrol'),
('spawn_mirror_patrol_escort',0,'anchor_mirror_patrol_escort_patrol'),
('spawn_forge_patrol_escort',0,'anchor_forge_patrol_escort_patrol'),
('spawn_iron_patrol_escort',0,'anchor_iron_patrol_escort_patrol'),
('spawn_helios_patrol_escort',0,'anchor_helios_patrol_escort_patrol'),
('spawn_drift_patrol_escort',0,'anchor_drift_patrol_escort_patrol'),
('spawn_mist_patrol_escort',0,'anchor_mist_patrol_escort_patrol'),
('spawn_rift_patrol_escort',0,'anchor_rift_patrol_escort_patrol'),
('spawn_silent_patrol_escort',0,'anchor_silent_patrol_escort_patrol');
INSERT INTO encounter_defs VALUES
('encounter_anchor_patrol','sector_anchor','锚港星系 · 侦察小队','anchor_anchor_patrol_leader',3000.0,600.0,1250.0,'unlock_combat_contracts'),
('encounter_echo_patrol','sector_echo','回声带星系 · 侦察小队','anchor_echo_raider',3000.0,600.0,1550.0,'unlock_exploration_contracts'),
('encounter_mirror_patrol','sector_mirror','镜湖星系 · 侦察小队','anchor_mirror_enemy',3000.0,600.0,1550.0,'unlock_open_routes'),
('encounter_forge_patrol','sector_forge','熔脊星系 · 掠袭团','anchor_forge_enemy',3000.0,600.0,1550.0,'unlock_open_routes'),
('encounter_iron_patrol','sector_iron','铁环星系 · 掠袭团','anchor_iron_enemy',3000.0,600.0,1550.0,'unlock_open_routes'),
('encounter_helios_patrol','sector_helios','曜炉星系 · 遗构警戒群','anchor_helios_enemy',3000.0,600.0,1850.0,'unlock_open_routes'),
('encounter_drift_patrol','sector_drift','游弋渡星系 · 掠袭团','anchor_drift_enemy',3000.0,600.0,1550.0,'unlock_open_routes'),
('encounter_mist_patrol','sector_mist','雾帆星系 · 遗构警戒群','anchor_mist_enemy',3000.0,600.0,1850.0,'unlock_open_routes'),
('encounter_rift_patrol','sector_rift','断弦星系 · 遗构警戒群','anchor_rift_enemy',3000.0,600.0,1850.0,'unlock_open_routes'),
('encounter_silent_patrol','sector_silent','静默渊星系 · 遗构警戒群','anchor_silent_enemy',3000.0,600.0,1850.0,'unlock_open_routes');
INSERT INTO encounter_members VALUES
('encounter_anchor_patrol','spawn_anchor_patrol_leader',0),
('encounter_anchor_patrol','spawn_anchor_patrol_escort',1),
('encounter_echo_patrol','spawn_echo_raider',0),
('encounter_echo_patrol','spawn_echo_patrol_escort',1),
('encounter_mirror_patrol','spawn_mirror_sentinel',0),
('encounter_mirror_patrol','spawn_mirror_patrol_escort',1),
('encounter_forge_patrol','spawn_forge_sentinel',0),
('encounter_forge_patrol','spawn_forge_patrol_escort',1),
('encounter_iron_patrol','spawn_iron_sentinel',0),
('encounter_iron_patrol','spawn_iron_patrol_escort',1),
('encounter_helios_patrol','spawn_helios_sentinel',0),
('encounter_helios_patrol','spawn_helios_patrol_escort',1),
('encounter_drift_patrol','spawn_drift_sentinel',0),
('encounter_drift_patrol','spawn_drift_patrol_escort',1),
('encounter_mist_patrol','spawn_mist_sentinel',0),
('encounter_mist_patrol','spawn_mist_patrol_escort',1),
('encounter_rift_patrol','spawn_rift_sentinel',0),
('encounter_rift_patrol','spawn_rift_patrol_escort',1),
('encounter_silent_patrol','spawn_silent_sentinel',0),
('encounter_silent_patrol','spawn_silent_patrol_escort',1);
INSERT INTO salvage_package_defs VALUES
('package_scout_salvage','轻型舰回收包',0.05,10.0),
('package_raider_salvage','掠袭舰回收包',0.12,30.0),
('package_guardian_salvage','重装舰回收包',0.3,80.0);
INSERT INTO salvage_reward_defs VALUES
('salvage_scout_credit','package_scout_salvage',55,25,NULL,0),
('salvage_scout_ore','package_scout_salvage',42,0,'ore_ferrosilicate',5),
('salvage_scout_module','package_scout_salvage',3,0,'module_kinetic_needle_i',1),
('salvage_raider_credit','package_raider_salvage',55,80,NULL,0),
('salvage_raider_ore','package_raider_salvage',30,0,'ore_ferrosilicate',20),
('salvage_raider_crystal','package_raider_salvage',10,0,'ore_conductive_crystal',10),
('salvage_raider_module','package_raider_salvage',5,0,'module_kinetic_needle_i',1),
('salvage_guardian_credit','package_guardian_salvage',35,250,NULL,0),
('salvage_guardian_alloy','package_guardian_salvage',35,0,'material_dense_alloy',1),
('salvage_guardian_relic','package_guardian_salvage',25,0,'component_relic',1),
('salvage_guardian_module','package_guardian_salvage',5,0,'module_pulse_breakwater_i',1);
INSERT INTO npc_salvage_defs VALUES
('npc_drift_sentinel','package_raider_salvage'),
('npc_encounter_scout_l1_high','package_scout_salvage'),
('npc_encounter_scout_l2_high','package_scout_salvage'),
('npc_encounter_scout_l3_medium','package_scout_salvage'),
('npc_encounter_scout_l4_medium','package_scout_salvage'),
('npc_encounter_scout_l6_low','package_scout_salvage'),
('npc_encounter_scout_l8_low','package_scout_salvage'),
('npc_forge_sentinel','package_raider_salvage'),
('npc_helios_sentinel','package_guardian_salvage'),
('npc_iron_sentinel','package_raider_salvage'),
('npc_mirror_sentinel','package_raider_salvage'),
('npc_mist_sentinel','package_guardian_salvage'),
('npc_raider_medium_l3_high','package_raider_salvage'),
('npc_rift_sentinel','package_guardian_salvage'),
('npc_silent_sentinel','package_guardian_salvage');
UPDATE catalog_meta SET content_version='v0.5-encounters',ruleset_version='singleplayer_v0_5',schema_version=4,source_document=source_document||';doc/38-任务导航主线与战斗打捞.md';

-- Additive industrial use for the existing regional ore. The old sensor recipe
-- stays unchanged; this alternative has a higher minimum acquisition cost and
-- uses only station services that are actually present.
INSERT INTO recipe_defs VALUES ('recipe_sensor_core_echo','component_sensor_core',1,20,0);
INSERT INTO recipe_inputs VALUES
('recipe_sensor_core_echo','ore_echo_silica',3),
('recipe_sensor_core_echo','material_structural_stock',1);
INSERT INTO recipe_access_defs
SELECT 'recipe_sensor_core_echo',station_id,required_unlock_id
FROM station_service_defs WHERE service_id='manufacture';
UPDATE catalog_meta SET content_version='v0.5-integrity',source_document=source_document||';doc/39-功能完整性审核与测试.md';
