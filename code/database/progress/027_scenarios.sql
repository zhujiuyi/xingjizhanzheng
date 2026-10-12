-- Additive tactical scenarios and local activity measurement; historical SQL unchanged.

CREATE TABLE frozen_tactical_award_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    award_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, award_id)
) STRICT;
CREATE TRIGGER frozen_tactical_award_defs_insert_guard BEFORE INSERT ON frozen_tactical_award_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_tactical_award_defs_update_guard BEFORE UPDATE ON frozen_tactical_award_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_tactical_award_defs_delete_guard BEFORE DELETE ON frozen_tactical_award_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TRIGGER frozen_tactical_award_defs_immutable_insert BEFORE INSERT ON frozen_tactical_award_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_tactical_award_defs_immutable_update BEFORE UPDATE ON frozen_tactical_award_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_tactical_award_defs_immutable_delete BEFORE DELETE ON frozen_tactical_award_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TABLE frozen_trial_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    trial_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    objective_kind TEXT NOT NULL CHECK(objective_kind IN('precision','escort','support')),
    station_id TEXT NOT NULL,
    entry_anchor_id TEXT NOT NULL,
    exit_anchor_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    award_id TEXT NOT NULL,
    budget_credit INTEGER NOT NULL CHECK(budget_credit>0),
    fee_credit INTEGER NOT NULL CHECK(fee_credit>0),
    duration_s REAL NOT NULL CHECK(duration_s>0),
    interaction_radius_m REAL NOT NULL CHECK(interaction_radius_m>0),
    min_range_m REAL NOT NULL CHECK(min_range_m>=0),
    max_range_m REAL NOT NULL CHECK(max_range_m>min_range_m),
    target_hp REAL NOT NULL CHECK(target_hp>0),
    hazard_hp_s REAL NOT NULL CHECK(hazard_hp_s>=0),
    cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
    description TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, trial_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, entry_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, exit_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id),
    FOREIGN KEY (content_snapshot_id, award_id) REFERENCES frozen_tactical_award_defs (content_snapshot_id, award_id),
    UNIQUE (content_snapshot_id, award_id)
) STRICT;
CREATE TRIGGER frozen_trial_defs_insert_guard BEFORE INSERT ON frozen_trial_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_trial_defs_update_guard BEFORE UPDATE ON frozen_trial_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_trial_defs_delete_guard BEFORE DELETE ON frozen_trial_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TRIGGER frozen_trial_defs_immutable_insert BEFORE INSERT ON frozen_trial_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_trial_defs_immutable_update BEFORE UPDATE ON frozen_trial_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_trial_defs_immutable_delete BEFORE DELETE ON frozen_trial_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TABLE frozen_trial_hull_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    trial_id TEXT NOT NULL,
    ship_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, trial_id, ship_id),
    FOREIGN KEY (content_snapshot_id, trial_id) REFERENCES frozen_trial_defs (content_snapshot_id, trial_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_trial_hull_defs_insert_guard BEFORE INSERT ON frozen_trial_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_trial_hull_defs_update_guard BEFORE UPDATE ON frozen_trial_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_trial_hull_defs_delete_guard BEFORE DELETE ON frozen_trial_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TRIGGER frozen_trial_hull_defs_immutable_insert BEFORE INSERT ON frozen_trial_hull_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_trial_hull_defs_immutable_update BEFORE UPDATE ON frozen_trial_hull_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_trial_hull_defs_immutable_delete BEFORE DELETE ON frozen_trial_hull_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TABLE frozen_trial_actor_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    spawn_id TEXT NOT NULL,
    trial_id TEXT NOT NULL,
    actor_role TEXT NOT NULL CHECK(actor_role IN('target','escort','raider','patient')),
    model_ship_id TEXT,
    move_speed_mps REAL NOT NULL CHECK(move_speed_mps>=0),
    initial_armor_bp INTEGER NOT NULL CHECK(initial_armor_bp BETWEEN 1 AND 10000),
    PRIMARY KEY (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, trial_id) REFERENCES frozen_trial_defs (content_snapshot_id, trial_id),
    FOREIGN KEY (content_snapshot_id, model_ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_trial_actor_defs_insert_guard BEFORE INSERT ON frozen_trial_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_trial_actor_defs_update_guard BEFORE UPDATE ON frozen_trial_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_trial_actor_defs_delete_guard BEFORE DELETE ON frozen_trial_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TRIGGER frozen_trial_actor_defs_immutable_insert BEFORE INSERT ON frozen_trial_actor_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_trial_actor_defs_immutable_update BEFORE UPDATE ON frozen_trial_actor_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_trial_actor_defs_immutable_delete BEFORE DELETE ON frozen_trial_actor_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TABLE frozen_blockade_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    blockade_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    station_id TEXT NOT NULL,
    entry_anchor_id TEXT NOT NULL,
    exit_anchor_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    award_id TEXT NOT NULL,
    fee_credit INTEGER NOT NULL CHECK(fee_credit>0),
    duration_s REAL NOT NULL CHECK(duration_s>0),
    target_units INTEGER NOT NULL CHECK(target_units>0),
    cargo_mass_kg REAL NOT NULL CHECK(cargo_mass_kg>0),
    cargo_volume_l REAL NOT NULL CHECK(cargo_volume_l>0),
    interaction_radius_m REAL NOT NULL CHECK(interaction_radius_m>0),
    field_radius_m REAL NOT NULL CHECK(field_radius_m>interaction_radius_m),
    detection_radius_m REAL NOT NULL CHECK(detection_radius_m>interaction_radius_m),
    quiet_speed_mps REAL NOT NULL CHECK(quiet_speed_mps>0),
    survey_duration_s REAL NOT NULL CHECK(survey_duration_s>0),
    survey_count INTEGER NOT NULL CHECK(survey_count>0),
    bypass_window_s REAL NOT NULL CHECK(bypass_window_s>0),
    loss_damage_hp REAL NOT NULL CHECK(loss_damage_hp>0),
    credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit>0),
    reputation_per_unit INTEGER NOT NULL CHECK(reputation_per_unit>0),
    cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
    description TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, blockade_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, entry_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, exit_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id),
    FOREIGN KEY (content_snapshot_id, award_id) REFERENCES frozen_tactical_award_defs (content_snapshot_id, award_id),
    UNIQUE (content_snapshot_id, award_id)
) STRICT;
CREATE TRIGGER frozen_blockade_defs_insert_guard BEFORE INSERT ON frozen_blockade_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_blockade_defs_update_guard BEFORE UPDATE ON frozen_blockade_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_blockade_defs_delete_guard BEFORE DELETE ON frozen_blockade_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TRIGGER frozen_blockade_defs_immutable_insert BEFORE INSERT ON frozen_blockade_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_blockade_defs_immutable_update BEFORE UPDATE ON frozen_blockade_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_blockade_defs_immutable_delete BEFORE DELETE ON frozen_blockade_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TABLE frozen_blockade_node_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    blockade_id TEXT NOT NULL,
    node_index INTEGER NOT NULL CHECK(node_index>=0),
    node_kind TEXT NOT NULL CHECK(node_kind IN('survey','relay')),
    anchor_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, blockade_id, node_index),
    FOREIGN KEY (content_snapshot_id, blockade_id) REFERENCES frozen_blockade_defs (content_snapshot_id, blockade_id),
    FOREIGN KEY (content_snapshot_id, anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    UNIQUE (content_snapshot_id, anchor_id)
) STRICT;
CREATE TRIGGER frozen_blockade_node_defs_insert_guard BEFORE INSERT ON frozen_blockade_node_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_blockade_node_defs_update_guard BEFORE UPDATE ON frozen_blockade_node_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_blockade_node_defs_delete_guard BEFORE DELETE ON frozen_blockade_node_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TRIGGER frozen_blockade_node_defs_immutable_insert BEFORE INSERT ON frozen_blockade_node_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_blockade_node_defs_immutable_update BEFORE UPDATE ON frozen_blockade_node_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_blockade_node_defs_immutable_delete BEFORE DELETE ON frozen_blockade_node_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TABLE frozen_blockade_actor_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    spawn_id TEXT NOT NULL,
    blockade_id TEXT NOT NULL,
    actor_role TEXT NOT NULL CHECK(actor_role IN('relay','raider')),
    node_index INTEGER,
    FOREIGN KEY (content_snapshot_id, blockade_id,node_index) REFERENCES frozen_blockade_node_defs (content_snapshot_id, blockade_id,node_index),
    CHECK((actor_role='relay' AND node_index IS NOT NULL) OR (actor_role='raider' AND node_index IS NULL)),
    PRIMARY KEY (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, blockade_id) REFERENCES frozen_blockade_defs (content_snapshot_id, blockade_id)
) STRICT;
CREATE TRIGGER frozen_blockade_actor_defs_insert_guard BEFORE INSERT ON frozen_blockade_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_blockade_actor_defs_update_guard BEFORE UPDATE ON frozen_blockade_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_blockade_actor_defs_delete_guard BEFORE DELETE ON frozen_blockade_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TRIGGER frozen_blockade_actor_defs_immutable_insert BEFORE INSERT ON frozen_blockade_actor_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_blockade_actor_defs_immutable_update BEFORE UPDATE ON frozen_blockade_actor_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_blockade_actor_defs_immutable_delete BEFORE DELETE ON frozen_blockade_actor_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TABLE frozen_telemetry_policy_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    record_limit INTEGER NOT NULL CHECK(record_limit BETWEEN 32 AND 512),
    navigation_wait_speed_mps REAL NOT NULL CHECK(navigation_wait_speed_mps>=0),
    description TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_telemetry_policy_defs_insert_guard BEFORE INSERT ON frozen_telemetry_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_telemetry_policy_defs_update_guard BEFORE UPDATE ON frozen_telemetry_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_telemetry_policy_defs_delete_guard BEFORE DELETE ON frozen_telemetry_policy_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TRIGGER frozen_telemetry_policy_defs_immutable_insert BEFORE INSERT ON frozen_telemetry_policy_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_telemetry_policy_defs_immutable_update BEFORE UPDATE ON frozen_telemetry_policy_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TRIGGER frozen_telemetry_policy_defs_immutable_delete BEFORE DELETE ON frozen_telemetry_policy_defs WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;

CREATE TABLE trial_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,trial_id TEXT NOT NULL,generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),
phase TEXT NOT NULL DEFAULT 'available' CHECK(phase IN('available','accepted','active','ready','completed','failed','withdrawn')),
ship_instance_id TEXT,reference_cost INTEGER NOT NULL DEFAULT 0 CHECK(reference_cost>=0),loadout_signature TEXT NOT NULL DEFAULT '',
remaining_s REAL NOT NULL DEFAULT 0 CHECK(remaining_s>=0),elapsed_s REAL NOT NULL DEFAULT 0 CHECK(elapsed_s>=0),effective_hp REAL NOT NULL DEFAULT 0 CHECK(effective_hp>=0),
paid_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit_total>=0),wins INTEGER NOT NULL DEFAULT 0 CHECK(wins>=0),
best_elapsed_s REAL NOT NULL DEFAULT 0 CHECK(best_elapsed_s>=0),best_cost INTEGER NOT NULL DEFAULT 0 CHECK(best_cost>=0),
cooldown_remaining_s REAL NOT NULL DEFAULT 0 CHECK(cooldown_remaining_s>=0),award_earned INTEGER NOT NULL DEFAULT 0 CHECK(award_earned IN(0,1)),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,trial_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,trial_id) REFERENCES frozen_trial_defs(content_snapshot_id,trial_id)) STRICT;

CREATE TRIGGER trial_state_insert_immutable BEFORE INSERT ON trial_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER trial_state_update_immutable BEFORE UPDATE ON trial_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER trial_state_delete_immutable BEFORE DELETE ON trial_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE trial_result_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,trial_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),
outcome TEXT NOT NULL CHECK(outcome IN('completed','failed','withdrawn')),reason_code TEXT NOT NULL CHECK(reason_code IN('completed','partial','manual','timeout','ship_destroyed','target_lost','out_of_range','loadout_changed','departed','combat','environment','overheat','unknown','signal_lost','objective_failed')),
ship_def_id TEXT NOT NULL,reference_cost INTEGER NOT NULL CHECK(reference_cost>0),paid_credit INTEGER NOT NULL CHECK(paid_credit>0),
elapsed_s REAL NOT NULL CHECK(elapsed_s>=0),effective_hp REAL NOT NULL CHECK(effective_hp>=0),finished_tick INTEGER NOT NULL CHECK(finished_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,trial_id,generation),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,trial_id) REFERENCES frozen_trial_defs(content_snapshot_id,trial_id),FOREIGN KEY(content_snapshot_id,ship_def_id) REFERENCES frozen_ship_defs(content_snapshot_id,ship_id)) STRICT;

CREATE TRIGGER trial_result_state_insert_immutable BEFORE INSERT ON trial_result_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER trial_result_state_update_immutable BEFORE UPDATE ON trial_result_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER trial_result_state_delete_immutable BEFORE DELETE ON trial_result_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE scenario_actor_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,npc_instance_id TEXT NOT NULL,spawn_id TEXT NOT NULL,
scenario_kind TEXT NOT NULL CHECK(scenario_kind IN('trial','blockade')),scenario_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),
actor_role TEXT NOT NULL CHECK(actor_role IN('target','escort','patient','raider','relay')),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(content_snapshot_id,spawn_id) REFERENCES frozen_npc_spawn_defs(content_snapshot_id,spawn_id)) STRICT;

CREATE TRIGGER scenario_actor_state_insert_immutable BEFORE INSERT ON scenario_actor_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER scenario_actor_state_update_immutable BEFORE UPDATE ON scenario_actor_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER scenario_actor_state_delete_immutable BEFORE DELETE ON scenario_actor_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE tactical_award_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,award_id TEXT NOT NULL,selected INTEGER NOT NULL DEFAULT 0 CHECK(selected IN(0,1)),earned_tick INTEGER NOT NULL CHECK(earned_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,award_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,award_id) REFERENCES frozen_tactical_award_defs(content_snapshot_id,award_id)) STRICT;

CREATE TRIGGER tactical_award_state_insert_immutable BEFORE INSERT ON tactical_award_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER tactical_award_state_update_immutable BEFORE UPDATE ON tactical_award_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER tactical_award_state_delete_immutable BEFORE DELETE ON tactical_award_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE blockade_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,blockade_id TEXT NOT NULL,generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),
phase TEXT NOT NULL DEFAULT 'available' CHECK(phase IN('available','accepted','active','ready','claimed','failed','withdrawn')),
payload_ship_id TEXT,loaded_units INTEGER NOT NULL DEFAULT 0 CHECK(loaded_units>=0),cargo_units INTEGER NOT NULL DEFAULT 0 CHECK(cargo_units>=0),
completed_units INTEGER NOT NULL DEFAULT 0 CHECK(completed_units>=0),lost_units INTEGER NOT NULL DEFAULT 0 CHECK(lost_units>=0),jettisoned_units INTEGER NOT NULL DEFAULT 0 CHECK(jettisoned_units>=0),
remaining_s REAL NOT NULL DEFAULT 0 CHECK(remaining_s>=0),elapsed_s REAL NOT NULL DEFAULT 0 CHECK(elapsed_s>=0),
alerted INTEGER NOT NULL DEFAULT 0 CHECK(alerted IN(0,1)),bypass_remaining_s REAL NOT NULL DEFAULT 0 CHECK(bypass_remaining_s>=0),damage_debt_hp REAL NOT NULL DEFAULT 0 CHECK(damage_debt_hp>=0),
scan_node_index INTEGER,scan_remaining_s REAL NOT NULL DEFAULT 0 CHECK(scan_remaining_s>=0),
paid_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit_total>=0),reward_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit_total>=0),rewarded_units_total INTEGER NOT NULL DEFAULT 0 CHECK(rewarded_units_total>=0),
cooldown_remaining_s REAL NOT NULL DEFAULT 0 CHECK(cooldown_remaining_s>=0),award_earned INTEGER NOT NULL DEFAULT 0 CHECK(award_earned IN(0,1)),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,blockade_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,blockade_id) REFERENCES frozen_blockade_defs(content_snapshot_id,blockade_id),FOREIGN KEY(content_snapshot_id,blockade_id,scan_node_index) REFERENCES frozen_blockade_node_defs(content_snapshot_id,blockade_id,node_index)) STRICT;

CREATE TRIGGER blockade_state_insert_immutable BEFORE INSERT ON blockade_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER blockade_state_update_immutable BEFORE UPDATE ON blockade_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER blockade_state_delete_immutable BEFORE DELETE ON blockade_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE blockade_node_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,blockade_id TEXT NOT NULL,node_index INTEGER NOT NULL,generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN(0,1)),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,blockade_id,node_index),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,blockade_id,node_index) REFERENCES frozen_blockade_node_defs(content_snapshot_id,blockade_id,node_index)) STRICT;

CREATE TRIGGER blockade_node_state_insert_immutable BEFORE INSERT ON blockade_node_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER blockade_node_state_update_immutable BEFORE UPDATE ON blockade_node_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER blockade_node_state_delete_immutable BEFORE DELETE ON blockade_node_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE blockade_result_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,blockade_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),
outcome TEXT NOT NULL CHECK(outcome IN('claimed','failed','withdrawn')),reason_code TEXT NOT NULL CHECK(reason_code IN('completed','partial','manual','timeout','ship_destroyed','target_lost','out_of_range','loadout_changed','departed','combat','environment','overheat','unknown','signal_lost','objective_failed')),
loaded_units INTEGER NOT NULL CHECK(loaded_units>=0),delivered_units INTEGER NOT NULL CHECK(delivered_units>=0),lost_units INTEGER NOT NULL CHECK(lost_units>=0),jettisoned_units INTEGER NOT NULL CHECK(jettisoned_units>=0),
paid_credit INTEGER NOT NULL CHECK(paid_credit>0),reward_credit INTEGER NOT NULL CHECK(reward_credit>=0),elapsed_s REAL NOT NULL CHECK(elapsed_s>=0),finished_tick INTEGER NOT NULL CHECK(finished_tick>=0),
CHECK(loaded_units=delivered_units+lost_units+jettisoned_units),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,blockade_id,generation),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,blockade_id) REFERENCES frozen_blockade_defs(content_snapshot_id,blockade_id)) STRICT;

CREATE TRIGGER blockade_result_state_insert_immutable BEFORE INSERT ON blockade_result_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER blockade_result_state_update_immutable BEFORE UPDATE ON blockade_result_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER blockade_result_state_delete_immutable BEFORE DELETE ON blockade_result_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE telemetry_source_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,item_id TEXT NOT NULL,source_kind TEXT NOT NULL CHECK(source_kind IN('mining','manufacture','mission','salvage','purchase')),units INTEGER NOT NULL CHECK(units>0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_id,source_kind),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,item_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)) STRICT;

CREATE TRIGGER telemetry_source_state_insert_immutable BEFORE INSERT ON telemetry_source_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER telemetry_source_state_update_immutable BEFORE UPDATE ON telemetry_source_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER telemetry_source_state_delete_immutable BEFORE DELETE ON telemetry_source_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE activity_record_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,record_id TEXT NOT NULL,activity_kind TEXT NOT NULL CHECK(activity_kind IN('mission','exploration','operation','trial','blockade','ship_loss')),
object_id TEXT NOT NULL,phase TEXT NOT NULL CHECK(phase IN('active','finished')),outcome TEXT NOT NULL DEFAULT '' CHECK(outcome IN('','completed','partial','failed','withdrawn','destroyed')),
reason_code TEXT NOT NULL CHECK(reason_code IN('','completed','partial','manual','timeout','ship_destroyed','target_lost','out_of_range','loadout_changed','departed','combat','environment','overheat','unknown','signal_lost','objective_failed')) DEFAULT '',partial_baseline INTEGER NOT NULL DEFAULT 0 CHECK(partial_baseline IN(0,1)),
started_tick INTEGER NOT NULL CHECK(started_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0),elapsed_s REAL NOT NULL DEFAULT 0 CHECK(elapsed_s>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,record_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER activity_record_state_insert_immutable BEFORE INSERT ON activity_record_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER activity_record_state_update_immutable BEFORE UPDATE ON activity_record_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER activity_record_state_delete_immutable BEFORE DELETE ON activity_record_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE telemetry_menu_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,page_id TEXT NOT NULL CHECK(page_id IN('station','ships','warehouse','fitting','market','industry','salvage','research','missions','map','pause','settings','civilizations','frontier','hire','consignments','ship_roles','fitting_analysis','sources','operations','drones','exploration','projects','expeditions','reports','trials','blockades')),duration_s REAL NOT NULL DEFAULT 0 CHECK(duration_s>=0),visits INTEGER NOT NULL DEFAULT 0 CHECK(visits>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,page_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER telemetry_menu_state_insert_immutable BEFORE INSERT ON telemetry_menu_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER telemetry_menu_state_update_immutable BEFORE UPDATE ON telemetry_menu_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER telemetry_menu_state_delete_immutable BEFORE DELETE ON telemetry_menu_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE telemetry_timing_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,singleton INTEGER NOT NULL CHECK(singleton=1),navigation_wait_s REAL NOT NULL DEFAULT 0 CHECK(navigation_wait_s>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,singleton),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER telemetry_timing_state_insert_immutable BEFORE INSERT ON telemetry_timing_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER telemetry_timing_state_update_immutable BEFORE UPDATE ON telemetry_timing_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER telemetry_timing_state_delete_immutable BEFORE DELETE ON telemetry_timing_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE activity_total_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,activity_kind TEXT NOT NULL CHECK(activity_kind IN('mission','exploration','operation','trial','blockade','ship_loss')),
outcome TEXT NOT NULL CHECK(outcome IN('completed','partial','failed','withdrawn','destroyed')),reason_code TEXT NOT NULL CHECK(reason_code IN('completed','partial','manual','timeout','ship_destroyed','target_lost','out_of_range','loadout_changed','departed','combat','environment','overheat','unknown','signal_lost','objective_failed')),
occurrences INTEGER NOT NULL CHECK(occurrences>0),elapsed_s REAL NOT NULL CHECK(elapsed_s>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,activity_kind,outcome,reason_code),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER activity_total_state_insert_immutable BEFORE INSERT ON activity_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER activity_total_state_update_immutable BEFORE UPDATE ON activity_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER activity_total_state_delete_immutable BEFORE DELETE ON activity_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER scenario_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_trial_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND (EXISTS(SELECT 1 FROM trial_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM trial_result_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM scenario_actor_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM tactical_award_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM blockade_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM blockade_node_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM blockade_result_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM telemetry_source_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM activity_record_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM telemetry_menu_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM telemetry_timing_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM activity_total_state WHERE snapshot_id=NEW.snapshot_id)) BEGIN SELECT RAISE(ABORT,'scenario state under legacy rules'); END;

CREATE UNIQUE INDEX tactical_award_one_selected ON tactical_award_state(snapshot_id,world_id,content_snapshot_id) WHERE selected=1;

CREATE UNIQUE INDEX activity_one_open_object ON activity_record_state(snapshot_id,world_id,content_snapshot_id,activity_kind,object_id) WHERE phase='active';

DROP TRIGGER role_payload_validation;
CREATE TRIGGER role_payload_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM frozen_role_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_state s JOIN frozen_ship_defs sd ON sd.content_snapshot_id=s.content_snapshot_id AND sd.ship_id=s.ship_def_id WHERE s.snapshot_id=NEW.snapshot_id AND
 (COALESCE((SELECT sum(b.cargo_units*d.cargo_volume_l) FROM blockade_state b JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE b.snapshot_id=s.snapshot_id AND b.payload_ship_id=s.ship_instance_id),0)+COALESCE((SELECT sum(h.cargo_units*d.unit_volume_l) FROM consignment_state h JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) WHERE h.snapshot_id=s.snapshot_id AND h.payload_ship_id=s.ship_instance_id),0)+COALESCE((SELECT sum(o.cargo_units*d.cargo_volume_l) FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=s.snapshot_id AND o.payload_ship_id=s.ship_instance_id),0)+
 COALESCE((SELECT sum(i.quantity*d.unit_volume_l) FROM inventory_stack_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)+
 COALESCE((SELECT sum(d.unit_volume_l) FROM item_instance_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)+
 COALESCE((SELECT sum(d.volume_m3*1000) FROM salvage_package_state p JOIN container_state c ON c.snapshot_id=p.snapshot_id AND c.container_id=p.host_container_id JOIN frozen_salvage_package_defs d USING(content_snapshot_id,package_def_id) WHERE p.snapshot_id=s.snapshot_id AND p.status='sealed' AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)>sd.cargo_l))
 THEN RAISE(ABORT,'consignment combined cargo exceeds real hold') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_state s JOIN frozen_ship_defs sd ON sd.content_snapshot_id=s.content_snapshot_id AND sd.ship_id=s.ship_def_id WHERE s.snapshot_id=NEW.snapshot_id AND
 (COALESCE((SELECT sum(b.cargo_units*d.cargo_mass_kg) FROM blockade_state b JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE b.snapshot_id=s.snapshot_id AND b.payload_ship_id=s.ship_instance_id),0)+COALESCE((SELECT sum(h.cargo_units*d.unit_mass_kg) FROM consignment_state h JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) WHERE h.snapshot_id=s.snapshot_id AND h.payload_ship_id=s.ship_instance_id),0)+COALESCE((SELECT sum(o.cargo_units*d.cargo_mass_kg) FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=s.snapshot_id AND o.payload_ship_id=s.ship_instance_id),0)+
 COALESCE((SELECT sum(i.quantity*d.unit_mass_kg) FROM inventory_stack_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind IN ('cargo','mineral')),0)+
 COALESCE((SELECT sum(d.unit_mass_kg) FROM item_instance_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind IN ('cargo','mineral')),0)+
 COALESCE((SELECT sum(d.mass_kg) FROM salvage_package_state p JOIN container_state c ON c.snapshot_id=p.snapshot_id AND c.container_id=p.host_container_id JOIN frozen_salvage_package_defs d ON d.content_snapshot_id=p.content_snapshot_id AND d.package_def_id=p.package_def_id WHERE p.snapshot_id=s.snapshot_id AND p.status='sealed' AND c.ship_instance_id=s.ship_instance_id),0)>sd.max_payload_mass_kg))
 THEN RAISE(ABORT,'consignment combined cargo exceeds shared mass budget') END;
END;

DROP TRIGGER role_seal_validation;
CREATE TRIGGER role_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM consignment_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_consignment_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN RAISE(ABORT,'consignment coverage incomplete') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM frozen_role_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (EXISTS(SELECT 1 FROM remote_support_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM consignment_receipt_state WHERE snapshot_id=NEW.snapshot_id)) THEN RAISE(ABORT,'role state under legacy definitions') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM remote_support_state r
 JOIN ship_state s ON s.snapshot_id=r.snapshot_id AND s.ship_instance_id=r.ship_instance_id
 JOIN frozen_ship_role_capability_defs c ON c.content_snapshot_id=r.content_snapshot_id AND c.ship_id=s.ship_def_id
 JOIN item_instance_state i ON i.snapshot_id=r.snapshot_id AND i.item_instance_id=r.item_instance_id
 LEFT JOIN equipment_state e ON e.snapshot_id=r.snapshot_id AND e.item_instance_id=r.item_instance_id
 LEFT JOIN frozen_repair_defs d ON d.content_snapshot_id=r.content_snapshot_id AND d.module_id=e.module_def_id
 LEFT JOIN frozen_module_defs m ON m.content_snapshot_id=r.content_snapshot_id AND m.module_id=e.module_def_id
 JOIN npc_state n ON n.snapshot_id=r.snapshot_id AND n.npc_instance_id=r.target_npc_id
 WHERE r.snapshot_id=NEW.snapshot_id AND
 (c.remote_repair_allowed<>1 OR s.policy_id<>'normal_owned' OR i.policy_id<>'normal_owned' OR s.status<>'flying' OR
 s.ship_instance_id<>(SELECT controlled_ship_id FROM player_state WHERE snapshot_id=r.snapshot_id) OR
 i.durability<=0 OR e.item_instance_id IS NULL OR e.enabled<>1 OR d.module_id IS NULL OR r.layer_id<>d.layer_id OR
 NOT EXISTS(SELECT 1 FROM container_state x WHERE x.snapshot_id=r.snapshot_id AND x.container_id=e.slot_container_id AND x.ship_instance_id=s.ship_instance_id) OR
 n.alive<>1 OR n.generation<>r.target_generation OR
 NOT (EXISTS(SELECT 1 FROM hire_contract_state h JOIN frozen_hire_profile_defs profile USING(content_snapshot_id,profile_id)
 WHERE h.snapshot_id=r.snapshot_id AND h.npc_instance_id=r.target_npc_id AND h.phase IN('deployed','retreating') AND profile.spawn_id=n.spawn_id
 AND h.player_id=(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id)) OR EXISTS(SELECT 1 FROM scenario_actor_state a JOIN trial_state s ON s.snapshot_id=a.snapshot_id AND s.trial_id=a.scenario_id WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND a.scenario_kind='trial' AND a.actor_role IN('escort','patient') AND a.generation=s.generation AND s.phase='active') OR EXISTS(SELECT 1 FROM exploration_actor_state a WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND a.actor_role='escort') OR EXISTS(SELECT 1 FROM war_fleet_state f WHERE f.snapshot_id=r.snapshot_id AND f.npc_instance_id=r.target_npc_id AND f.side='ally') OR EXISTS(SELECT 1 FROM frontier_actor_state a JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
 JOIN civilization_state identity ON identity.snapshot_id=a.snapshot_id
 LEFT JOIN war_campaign_state w ON w.snapshot_id=a.snapshot_id AND w.war_id=a.war_id
 LEFT JOIN frozen_civilization_war_defs d ON d.content_snapshot_id=a.content_snapshot_id AND d.war_id=a.war_id
 LEFT JOIN frontier_territory_state f ON f.snapshot_id=a.snapshot_id AND f.sector_id=a.sector_id
 LEFT JOIN territory_state t ON t.snapshot_id=a.snapshot_id AND t.sector_id=a.sector_id
 WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND
 ((a.actor_role='convoy' AND w.status IN ('assembling','fighting','occupying') AND w.attempt=a.generation AND identity.faction_id IS d.faction_id) OR
 (a.actor_role='beacon' AND a.war_id IS NULL AND f.phase='defending' AND f.crisis_generation=a.generation AND identity.faction_id IS t.faction_id)))) OR
 (r.phase='armed' AND (r.remaining_s<>0 OR r.paid_restore<>0)) OR
 (r.phase='cycling' AND (r.remaining_s<=0 OR r.remaining_s>m.cycle_s+0.000001 OR e.cycle_paid<>1 OR
 abs(e.active_remaining_s-r.remaining_s)>0.000001 OR abs(r.paid_restore-d.restore_amount*i.quality_multiplier*(CASE r.layer_id WHEN 'shield' THEN c.remote_shield_multiplier ELSE c.remote_armor_multiplier END))>0.000001)))) THEN RAISE(ABORT,'remote support binding or paid cycle invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM consignment_state s JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) JOIN frozen_role_balance_defs b USING(content_snapshot_id) WHERE s.snapshot_id=NEW.snapshot_id AND
 (s.accepted_units>d.max_units OR s.accepted_units<>s.cargo_units+s.delivered_units+s.lost_units+s.returned_units OR
 s.remaining_s>d.deadline_s OR s.cooldown_remaining_s>d.cooldown_s OR s.exposure_remaining_s>b.freight_exposure_s OR s.damage_debt_hp>=b.freight_loss_damage_hp OR
 (s.phase='idle' AND (s.accepted_units<>0 OR s.payload_ship_id IS NOT NULL OR s.remaining_s<>0 OR s.cooldown_remaining_s<>0)) OR
 (s.phase='active' AND (s.cargo_units<=0 OR s.payload_ship_id IS NULL OR s.remaining_s<=0 OR s.cooldown_remaining_s<>0 OR NOT EXISTS(SELECT 1 FROM ship_state h JOIN player_state p USING(snapshot_id,world_id,content_snapshot_id) WHERE h.snapshot_id=s.snapshot_id AND h.ship_instance_id=s.payload_ship_id AND h.owner_player_id=p.player_id AND h.policy_id='normal_owned' AND h.status IN ('flying','docked')))) OR
 (s.phase IN ('ready','claimed') AND (s.accepted_units<=0 OR s.cargo_units<>0 OR s.payload_ship_id IS NOT NULL OR s.remaining_s<>0 OR s.exposure_remaining_s<>0 OR s.damage_debt_hp<>0)) OR
 (s.phase<>'claimed' AND s.cooldown_remaining_s<>0) OR
 (s.exposure_remaining_s=0 AND s.damage_debt_hp<>0) OR
 (s.phase='claimed')<>EXISTS(SELECT 1 FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='claim'))) THEN RAISE(ABORT,'consignment phase or cargo invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM consignment_receipt_state r JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) JOIN consignment_state s USING(snapshot_id,world_id,content_snapshot_id,contract_id) WHERE r.snapshot_id=NEW.snapshot_id AND
 (r.generation>s.generation OR (r.action_kind<>'claim' AND r.units<=0) OR
 (r.action_kind='dispatch' AND (r.units>d.max_units OR r.paid_credit<>d.fee_credit+r.units*d.deposit_per_unit OR r.refunded_credit<>0 OR r.reward_credit<>0)) OR
 (r.action_kind IN ('deliver','loss','return') AND (r.paid_credit<>0 OR r.refunded_credit<>0 OR r.reward_credit<>0)) OR
 (r.action_kind='claim' AND (r.paid_credit<>0 OR
 r.units<>COALESCE((SELECT sum(x.units) FROM consignment_receipt_state x WHERE x.snapshot_id=r.snapshot_id AND x.contract_id=r.contract_id AND x.generation=r.generation AND x.action_kind='deliver'),0) OR
 r.reward_credit<>r.units*d.reward_per_unit OR
 r.refunded_credit<>d.deposit_per_unit*COALESCE((SELECT sum(x.units) FROM consignment_receipt_state x WHERE x.snapshot_id=r.snapshot_id AND x.contract_id=r.contract_id AND x.generation=r.generation AND x.action_kind IN ('deliver','return')),0))))) THEN RAISE(ABORT,'consignment receipt payment invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM consignment_state s WHERE s.snapshot_id=NEW.snapshot_id AND
 (s.accepted_units<>COALESCE((SELECT sum(r.units) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='dispatch'),0) OR
 s.delivered_units<>COALESCE((SELECT sum(r.units) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='deliver'),0) OR
 s.lost_units<>COALESCE((SELECT sum(r.units) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='loss'),0) OR
 s.returned_units<>COALESCE((SELECT sum(r.units) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='return'),0) OR
 s.paid_credit_total<>COALESCE((SELECT sum(r.paid_credit) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id),0) OR
 s.refunded_credit_total<>COALESCE((SELECT sum(r.refunded_credit) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id),0) OR
 s.reward_credit_total<>COALESCE((SELECT sum(r.reward_credit) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id),0))) THEN RAISE(ABORT,'consignment ledger conservation failed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM consignment_receipt_state r JOIN consignment_state s USING(snapshot_id,world_id,content_snapshot_id,contract_id) WHERE r.snapshot_id=NEW.snapshot_id AND r.generation<s.generation GROUP BY r.contract_id,r.generation HAVING
 sum(CASE WHEN r.action_kind='dispatch' THEN r.units ELSE 0 END)<>sum(CASE WHEN r.action_kind IN ('deliver','loss','return') THEN r.units ELSE 0 END) OR sum(r.action_kind='claim')<>1) THEN RAISE(ABORT,'past consignment round incomplete') END;
END;

CREATE TRIGGER scenario_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_state s WHERE s.snapshot_id=NEW.snapshot_id AND ((s.phase='available')<>(s.generation=0) OR (SELECT count(*) FROM trial_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.trial_id=s.trial_id)<>s.generation-CASE WHEN s.phase IN('accepted','active','ready') THEN 1 ELSE 0 END OR (s.phase IN('accepted','active','ready') AND (s.ship_instance_id IS NULL OR length(s.loadout_signature)<>64 OR NOT EXISTS(SELECT 1 FROM ship_state h JOIN frozen_trial_hull_defs a ON a.content_snapshot_id=h.content_snapshot_id AND a.ship_id=h.ship_def_id WHERE h.snapshot_id=s.snapshot_id AND h.ship_instance_id=s.ship_instance_id AND h.policy_id='normal_owned' AND a.trial_id=s.trial_id))) OR s.award_earned<>EXISTS(SELECT 1 FROM tactical_award_state a JOIN frozen_trial_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.trial_id=s.trial_id WHERE a.snapshot_id=s.snapshot_id AND a.award_id=d.award_id))) THEN RAISE(ABORT,'trial generation binding or award incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_state s WHERE s.snapshot_id=NEW.snapshot_id AND ((s.phase='available')<>(s.generation=0) OR (SELECT count(*) FROM blockade_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.blockade_id=s.blockade_id)<>s.generation-CASE WHEN s.phase IN('accepted','active','ready') THEN 1 ELSE 0 END OR (s.phase='active' AND (s.payload_ship_id IS NULL OR NOT EXISTS(SELECT 1 FROM ship_state h WHERE h.snapshot_id=s.snapshot_id AND h.ship_instance_id=s.payload_ship_id AND h.policy_id='normal_owned' AND h.status='flying'))) OR (s.phase<>'active' AND (s.payload_ship_id IS NOT NULL OR s.cargo_units<>0 OR s.scan_node_index IS NOT NULL OR s.scan_remaining_s<>0)) OR s.award_earned<>EXISTS(SELECT 1 FROM tactical_award_state a JOIN frozen_blockade_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.blockade_id=s.blockade_id WHERE a.snapshot_id=s.snapshot_id AND a.award_id=d.award_id))) THEN RAISE(ABORT,'blockade generation payload or award incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_result_state r JOIN trial_state s USING(snapshot_id,world_id,content_snapshot_id,trial_id) WHERE r.snapshot_id=NEW.snapshot_id AND (r.generation>s.generation OR NOT EXISTS(SELECT 1 FROM frozen_trial_hull_defs a WHERE a.content_snapshot_id=r.content_snapshot_id AND a.trial_id=r.trial_id AND a.ship_id=r.ship_def_id))) THEN RAISE(ABORT,'trial result hull or generation invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_result_state r JOIN blockade_state s USING(snapshot_id,world_id,content_snapshot_id,blockade_id) WHERE r.snapshot_id=NEW.snapshot_id AND r.generation>s.generation) THEN RAISE(ABORT,'blockade result generation invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_state s JOIN frozen_trial_defs d USING(content_snapshot_id,trial_id) WHERE s.snapshot_id=NEW.snapshot_id AND (s.reference_cost>d.budget_credit OR s.remaining_s>d.duration_s OR s.cooldown_remaining_s>d.cooldown_s OR s.paid_credit_total<>s.generation*d.fee_credit OR s.wins<>(SELECT count(*) FROM trial_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.trial_id=s.trial_id AND r.outcome='completed'))) THEN RAISE(ABORT,'invalid trial budget fee or result count') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_result_state r JOIN frozen_trial_defs d USING(content_snapshot_id,trial_id) WHERE r.snapshot_id=NEW.snapshot_id AND (r.reference_cost>d.budget_credit OR r.paid_credit<>d.fee_credit OR r.finished_tick>NEW.simulation_tick OR r.elapsed_s>d.duration_s+1 OR (r.outcome='completed' AND d.objective_kind IN('precision','support') AND r.effective_hp<d.target_hp))) THEN RAISE(ABORT,'trial result differs from accepted rules') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_state s JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE s.snapshot_id=NEW.snapshot_id AND (s.loaded_units>d.target_units OR s.loaded_units<>s.cargo_units+s.completed_units+s.lost_units+s.jettisoned_units OR s.remaining_s>d.duration_s OR s.bypass_remaining_s>d.bypass_window_s OR s.cooldown_remaining_s>d.cooldown_s OR s.paid_credit_total<>s.generation*d.fee_credit OR s.reward_credit_total<>(SELECT coalesce(sum(r.reward_credit),0) FROM blockade_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.blockade_id=s.blockade_id) OR s.rewarded_units_total<>(SELECT coalesce(sum(r.delivered_units),0) FROM blockade_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.blockade_id=s.blockade_id))) THEN RAISE(ABORT,'invalid blockade cargo fee or rewards') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_result_state r JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE r.snapshot_id=NEW.snapshot_id AND (r.loaded_units>d.target_units OR r.paid_credit<>d.fee_credit OR r.reward_credit<>r.delivered_units*d.credit_per_unit OR r.finished_tick>NEW.simulation_tick OR (r.outcome<>'claimed' AND r.delivered_units<>0))) THEN RAISE(ABORT,'blockade settlement lacks actual delivery') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_node_state n JOIN blockade_state s USING(snapshot_id,world_id,content_snapshot_id,blockade_id) WHERE n.snapshot_id=NEW.snapshot_id AND n.generation<>s.generation) THEN RAISE(ABORT,'stale blockade node generation') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM activity_record_state r WHERE r.snapshot_id=NEW.snapshot_id AND (r.started_tick>NEW.simulation_tick OR r.finished_tick>NEW.simulation_tick OR (r.phase='active' AND (r.outcome<>'' OR r.reason_code<>'' OR r.finished_tick<>0)) OR (r.phase='finished' AND (r.outcome='' OR r.finished_tick<r.started_tick)))) THEN RAISE(ABORT,'invalid activity time or outcome') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM activity_record_state r LEFT JOIN activity_total_state t USING(snapshot_id,world_id,content_snapshot_id,activity_kind,outcome,reason_code) WHERE r.snapshot_id=NEW.snapshot_id AND r.phase='finished' AND t.activity_kind IS NULL) THEN RAISE(ABORT,'activity result lacks lifetime measurement') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM activity_total_state t WHERE t.snapshot_id=NEW.snapshot_id AND (t.occurrences<(SELECT count(*) FROM activity_record_state r WHERE r.snapshot_id=t.snapshot_id AND r.phase='finished' AND r.activity_kind=t.activity_kind AND r.outcome=t.outcome AND r.reason_code=t.reason_code) OR t.elapsed_s+0.00001<(SELECT coalesce(sum(r.elapsed_s),0) FROM activity_record_state r WHERE r.snapshot_id=t.snapshot_id AND r.phase='finished' AND r.activity_kind=t.activity_kind AND r.outcome=t.outcome AND r.reason_code=t.reason_code))) THEN RAISE(ABORT,'activity totals below retained results') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_telemetry_policy_defs p WHERE p.content_snapshot_id=NEW.content_snapshot_id AND ((SELECT count(*) FROM activity_record_state r WHERE r.snapshot_id=NEW.snapshot_id AND r.phase='finished')>p.record_limit OR (SELECT count(*) FROM telemetry_timing_state t WHERE t.snapshot_id=NEW.snapshot_id)<>1)) THEN RAISE(ABORT,'invalid bounded activity history or timing singleton') END;
END;

CREATE TRIGGER scenario_context_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
 BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM trial_state WHERE snapshot_id=NEW.snapshot_id AND phase IN('accepted','active','ready'))+(SELECT count(*) FROM blockade_state WHERE snapshot_id=NEW.snapshot_id AND phase IN('accepted','active','ready'))>1 THEN RAISE(ABORT,'multiple tactical scenarios accepted') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM scenario_actor_state a WHERE a.snapshot_id=NEW.snapshot_id AND
 ((a.scenario_kind='trial' AND NOT EXISTS(SELECT 1 FROM trial_state s JOIN frozen_trial_actor_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.trial_id=s.trial_id JOIN npc_state n ON n.snapshot_id=s.snapshot_id AND n.npc_instance_id=a.npc_instance_id WHERE s.snapshot_id=a.snapshot_id AND s.trial_id=a.scenario_id AND s.phase='active' AND s.generation=a.generation AND d.spawn_id=a.spawn_id AND d.actor_role=a.actor_role AND n.spawn_id=a.spawn_id AND n.generation=a.generation)) OR
 (a.scenario_kind='blockade' AND NOT EXISTS(SELECT 1 FROM blockade_state s JOIN frozen_blockade_actor_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.blockade_id=s.blockade_id JOIN npc_state n ON n.snapshot_id=s.snapshot_id AND n.npc_instance_id=a.npc_instance_id WHERE s.snapshot_id=a.snapshot_id AND s.blockade_id=a.scenario_id AND s.phase='active' AND s.generation=a.generation AND d.spawn_id=a.spawn_id AND d.actor_role=a.actor_role AND n.spawn_id=a.spawn_id AND n.generation=a.generation)))) THEN RAISE(ABORT,'managed scenario actor context invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_state s JOIN frozen_trial_actor_defs d USING(content_snapshot_id,trial_id) WHERE s.snapshot_id=NEW.snapshot_id AND s.phase='active' AND (SELECT count(*) FROM scenario_actor_state a WHERE a.snapshot_id=s.snapshot_id AND a.scenario_kind='trial' AND a.scenario_id=s.trial_id AND a.generation=s.generation AND a.spawn_id=d.spawn_id)<>1) THEN RAISE(ABORT,'active trial actor coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_state s JOIN frozen_blockade_actor_defs d USING(content_snapshot_id,blockade_id) WHERE s.snapshot_id=NEW.snapshot_id AND s.phase='active' AND (SELECT count(*) FROM scenario_actor_state a WHERE a.snapshot_id=s.snapshot_id AND a.scenario_kind='blockade' AND a.scenario_id=s.blockade_id AND a.generation=s.generation AND a.spawn_id=d.spawn_id)<>1) THEN RAISE(ABORT,'active blockade actor coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM tactical_award_state a WHERE a.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM trial_result_state r JOIN frozen_trial_defs d USING(content_snapshot_id,trial_id) WHERE r.snapshot_id=a.snapshot_id AND d.award_id=a.award_id AND r.outcome='completed') AND NOT EXISTS(SELECT 1 FROM blockade_result_state r JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE r.snapshot_id=a.snapshot_id AND d.award_id=a.award_id AND r.outcome='claimed' AND r.delivered_units=d.target_units)) THEN RAISE(ABORT,'tactical award lacks full result') END;
 END;

CREATE TABLE database_meta_format24(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=24)) STRICT;
INSERT INTO database_meta_format24 SELECT singleton,application_id,24 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format24 RENAME TO database_meta;PRAGMA user_version=24;
