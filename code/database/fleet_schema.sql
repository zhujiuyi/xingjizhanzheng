-- Player-owned fleet and finite crew careers. Runtime values come from SQLite.
CREATE TABLE fleet_balance_defs(
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 max_owned_companions INTEGER NOT NULL CHECK(max_owned_companions BETWEEN 1 AND 4),
 max_recruited_crew INTEGER NOT NULL CHECK(max_recruited_crew BETWEEN 1 AND 16),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 communication_m REAL NOT NULL CHECK(communication_m>0),
 formation_m REAL NOT NULL CHECK(formation_m>0 AND formation_m<communication_m),
 warp_ready_m REAL NOT NULL CHECK(warp_ready_m>=formation_m AND warp_ready_m<communication_m),
 retreat_distance_m REAL NOT NULL CHECK(retreat_distance_m>0),
 retreat_charge_s REAL NOT NULL CHECK(retreat_charge_s>0),
 return_s REAL NOT NULL CHECK(return_s>0),
 deploy_fee_credit INTEGER NOT NULL CHECK(deploy_fee_credit>0),
 deploy_hull_fee_bp INTEGER NOT NULL CHECK(deploy_hull_fee_bp BETWEEN 0 AND 10000),
 salary_period_s REAL NOT NULL CHECK(salary_period_s>0),
 loyalty_initial INTEGER NOT NULL CHECK(loyalty_initial BETWEEN 1 AND 100),
 loyalty_paid_gain INTEGER NOT NULL CHECK(loyalty_paid_gain>0),
 loyalty_unpaid_loss INTEGER NOT NULL CHECK(loyalty_unpaid_loss>0),
 loyalty_casualty_loss INTEGER NOT NULL CHECK(loyalty_casualty_loss>0),
 loyalty_ready_min INTEGER NOT NULL CHECK(loyalty_ready_min BETWEEN 1 AND loyalty_initial),
 arrears_period_limit INTEGER NOT NULL CHECK(arrears_period_limit BETWEEN 1 AND 12),
 injury_recovery_s REAL NOT NULL CHECK(injury_recovery_s>0),
 injury_treatment_credit INTEGER NOT NULL CHECK(injury_treatment_credit>0),
 rest_duration_s REAL NOT NULL CHECK(rest_duration_s>0),
 rest_credit INTEGER NOT NULL CHECK(rest_credit>0),
 experience_cap INTEGER NOT NULL CHECK(experience_cap>0),
 history_limit INTEGER NOT NULL CHECK(history_limit BETWEEN 16 AND 512)
) STRICT;

CREATE TABLE crew_profession_defs(
 profession_id TEXT PRIMARY KEY,
 display_name TEXT NOT NULL,
 duty_kind TEXT NOT NULL UNIQUE CHECK(duty_kind IN('pilot','gunner','engineer','scout')),
 hire_fee_credit INTEGER NOT NULL CHECK(hire_fee_credit>0),
 salary_credit INTEGER NOT NULL CHECK(salary_credit>0),
 effect_stat TEXT NOT NULL UNIQUE CHECK(effect_stat IN('turn_rad_s','cooling_hu_s','remote_repair_multiplier','scan_strength')),
 effect_mode TEXT NOT NULL CHECK(effect_mode IN('ratio','flat')),
 contribution_kind TEXT NOT NULL UNIQUE CHECK(contribution_kind IN('distance','damage','repair','survey')),
 contribution_per_xp REAL NOT NULL CHECK(contribution_per_xp>0),
 description TEXT NOT NULL
) STRICT;

CREATE TABLE crew_rank_defs(
 profession_id TEXT NOT NULL REFERENCES crew_profession_defs(profession_id),
 rank INTEGER NOT NULL CHECK(rank BETWEEN 1 AND 3),
 experience_required INTEGER NOT NULL CHECK(experience_required>=0),
 effect_value REAL NOT NULL CHECK(effect_value>0),
 salary_multiplier REAL NOT NULL CHECK(salary_multiplier>=1),
 PRIMARY KEY(profession_id,rank),UNIQUE(profession_id,experience_required)
) STRICT;

CREATE TABLE crew_profile_defs(
 profile_id TEXT PRIMARY KEY,
 display_name TEXT NOT NULL UNIQUE,
 profession_id TEXT NOT NULL REFERENCES crew_profession_defs(profession_id)
) STRICT;

CREATE TABLE fleet_hull_defs(
 ship_id TEXT PRIMARY KEY REFERENCES ship_defs(ship_id),
 spawn_id TEXT NOT NULL UNIQUE REFERENCES npc_spawn_defs(spawn_id),
 crew_slots INTEGER NOT NULL CHECK(crew_slots BETWEEN 1 AND 4)
) STRICT;

CREATE TABLE auxiliary_drone_defs(
 module_id TEXT PRIMARY KEY REFERENCES module_defs(module_id),
 role_kind TEXT NOT NULL CHECK(role_kind IN('repair','recon')),
 drone_count INTEGER NOT NULL CHECK(drone_count BETWEEN 1 AND 3),
 speed_mps REAL NOT NULL CHECK(speed_mps>0),acceleration_mps2 REAL NOT NULL CHECK(acceleration_mps2>0),
 turn_rad_s REAL NOT NULL CHECK(turn_rad_s>0),work_range_m REAL NOT NULL CHECK(work_range_m>0),
 sortie_timeout_s REAL NOT NULL CHECK(sortie_timeout_s>0),return_radius_m REAL NOT NULL CHECK(return_radius_m>0),
 hull_hp REAL NOT NULL CHECK(hull_hp>0),restore_amount REAL NOT NULL CHECK(restore_amount>=0),
 sensor_range_m REAL NOT NULL CHECK(sensor_range_m>=0),observe_cycle_s REAL NOT NULL CHECK(observe_cycle_s>0),observation_ttl_s REAL NOT NULL CHECK(observation_ttl_s>observe_cycle_s),
 consumable_item_id TEXT REFERENCES item_defs(item_id),consumable_per_sortie INTEGER NOT NULL CHECK(consumable_per_sortie>=0),
 material_id TEXT NOT NULL REFERENCES item_defs(item_id),material_per_unit INTEGER NOT NULL CHECK(material_per_unit>0),
 credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit>0),
 CHECK((consumable_item_id IS NULL AND consumable_per_sortie=0) OR (consumable_item_id IS NOT NULL AND consumable_per_sortie>0)),
 CHECK((role_kind='repair' AND restore_amount>0 AND sensor_range_m=0) OR (role_kind='recon' AND restore_amount=0 AND sensor_range_m>0))
) STRICT;

CREATE TABLE ship_auxiliary_permissions(
 ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
 role_kind TEXT NOT NULL CHECK(role_kind IN('repair','recon')),
 max_installed INTEGER NOT NULL CHECK(max_installed BETWEEN 1 AND 2),
 PRIMARY KEY(ship_id,role_kind)
) STRICT;
