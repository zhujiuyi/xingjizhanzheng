-- Tactical challenges and contested corridors. All gameplay values are frozen.
CREATE TABLE tactical_award_defs(
 award_id TEXT PRIMARY KEY,display_name TEXT NOT NULL,description TEXT NOT NULL
) STRICT;
CREATE TABLE trial_defs(
 trial_id TEXT PRIMARY KEY,display_name TEXT NOT NULL,
 objective_kind TEXT NOT NULL CHECK(objective_kind IN('precision','escort','support')),
 station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 entry_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),exit_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 award_id TEXT NOT NULL UNIQUE REFERENCES tactical_award_defs(award_id),
 budget_credit INTEGER NOT NULL CHECK(budget_credit>0),fee_credit INTEGER NOT NULL CHECK(fee_credit>0),
 duration_s REAL NOT NULL CHECK(duration_s>0),interaction_radius_m REAL NOT NULL CHECK(interaction_radius_m>0),
 min_range_m REAL NOT NULL CHECK(min_range_m>=0),max_range_m REAL NOT NULL CHECK(max_range_m>min_range_m),
 target_hp REAL NOT NULL CHECK(target_hp>0),hazard_hp_s REAL NOT NULL CHECK(hazard_hp_s>=0),
 cooldown_s REAL NOT NULL CHECK(cooldown_s>0),description TEXT NOT NULL
) STRICT;
CREATE TABLE trial_hull_defs(
 trial_id TEXT NOT NULL REFERENCES trial_defs(trial_id),ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
 PRIMARY KEY(trial_id,ship_id)
) STRICT;
CREATE TABLE trial_actor_defs(
 spawn_id TEXT PRIMARY KEY REFERENCES npc_spawn_defs(spawn_id),trial_id TEXT NOT NULL REFERENCES trial_defs(trial_id),
 actor_role TEXT NOT NULL CHECK(actor_role IN('target','escort','raider','patient')),
 model_ship_id TEXT REFERENCES ship_defs(ship_id),move_speed_mps REAL NOT NULL CHECK(move_speed_mps>=0),
 initial_armor_bp INTEGER NOT NULL CHECK(initial_armor_bp BETWEEN 1 AND 10000)
) STRICT;
CREATE TABLE blockade_defs(
 blockade_id TEXT PRIMARY KEY,display_name TEXT NOT NULL,
 station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 entry_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),exit_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),award_id TEXT NOT NULL UNIQUE REFERENCES tactical_award_defs(award_id),
 fee_credit INTEGER NOT NULL CHECK(fee_credit>0),duration_s REAL NOT NULL CHECK(duration_s>0),
 target_units INTEGER NOT NULL CHECK(target_units>0),cargo_mass_kg REAL NOT NULL CHECK(cargo_mass_kg>0),cargo_volume_l REAL NOT NULL CHECK(cargo_volume_l>0),
 interaction_radius_m REAL NOT NULL CHECK(interaction_radius_m>0),field_radius_m REAL NOT NULL CHECK(field_radius_m>interaction_radius_m),
 detection_radius_m REAL NOT NULL CHECK(detection_radius_m>interaction_radius_m),quiet_speed_mps REAL NOT NULL CHECK(quiet_speed_mps>0),
 survey_duration_s REAL NOT NULL CHECK(survey_duration_s>0),survey_count INTEGER NOT NULL CHECK(survey_count>0),
 bypass_window_s REAL NOT NULL CHECK(bypass_window_s>0),loss_damage_hp REAL NOT NULL CHECK(loss_damage_hp>0),
 credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit>0),reputation_per_unit INTEGER NOT NULL CHECK(reputation_per_unit>0),
 cooldown_s REAL NOT NULL CHECK(cooldown_s>0),description TEXT NOT NULL
) STRICT;
CREATE TABLE blockade_node_defs(
 blockade_id TEXT NOT NULL REFERENCES blockade_defs(blockade_id),node_index INTEGER NOT NULL CHECK(node_index>=0),
 node_kind TEXT NOT NULL CHECK(node_kind IN('survey','relay')),anchor_id TEXT NOT NULL UNIQUE REFERENCES anchor_defs(anchor_id),
 PRIMARY KEY(blockade_id,node_index)
) STRICT;
CREATE TABLE blockade_actor_defs(
 spawn_id TEXT PRIMARY KEY REFERENCES npc_spawn_defs(spawn_id),blockade_id TEXT NOT NULL REFERENCES blockade_defs(blockade_id),
 actor_role TEXT NOT NULL CHECK(actor_role IN('relay','raider')),node_index INTEGER,
 FOREIGN KEY(blockade_id,node_index) REFERENCES blockade_node_defs(blockade_id,node_index),
 CHECK((actor_role='relay' AND node_index IS NOT NULL) OR (actor_role='raider' AND node_index IS NULL))
) STRICT;
CREATE TABLE telemetry_policy_defs(
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),record_limit INTEGER NOT NULL CHECK(record_limit BETWEEN 32 AND 512),
 navigation_wait_speed_mps REAL NOT NULL CHECK(navigation_wait_speed_mps>=0),
 description TEXT NOT NULL
) STRICT;
