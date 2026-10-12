-- Owned hulls, finite crew careers and physical auxiliary sorties.

CREATE TABLE frozen_fleet_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    max_owned_companions INTEGER NOT NULL CHECK(max_owned_companions BETWEEN 1 AND 4),
    max_recruited_crew INTEGER NOT NULL CHECK(max_recruited_crew BETWEEN 1 AND 16),
    required_unlock_id TEXT NOT NULL,
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
    history_limit INTEGER NOT NULL CHECK(history_limit BETWEEN 16 AND 512),
    PRIMARY KEY (content_snapshot_id, singleton),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_fleet_balance_defs_insert_guard BEFORE INSERT ON frozen_fleet_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_fleet_balance_defs_update_guard BEFORE UPDATE ON frozen_fleet_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_fleet_balance_defs_delete_guard BEFORE DELETE ON frozen_fleet_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_crew_profession_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profession_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    duty_kind TEXT NOT NULL CHECK(duty_kind IN('pilot','gunner','engineer','scout')),
    hire_fee_credit INTEGER NOT NULL CHECK(hire_fee_credit>0),
    salary_credit INTEGER NOT NULL CHECK(salary_credit>0),
    effect_stat TEXT NOT NULL CHECK(effect_stat IN('turn_rad_s','cooling_hu_s','remote_repair_multiplier','scan_strength')),
    effect_mode TEXT NOT NULL CHECK(effect_mode IN('ratio','flat')),
    contribution_kind TEXT NOT NULL CHECK(contribution_kind IN('distance','damage','repair','survey')),
    contribution_per_xp REAL NOT NULL CHECK(contribution_per_xp>0),
    description TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, profession_id),
    UNIQUE (content_snapshot_id, duty_kind),
    UNIQUE (content_snapshot_id, effect_stat),
    UNIQUE (content_snapshot_id, contribution_kind)
) STRICT;
CREATE TRIGGER frozen_crew_profession_defs_insert_guard BEFORE INSERT ON frozen_crew_profession_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_crew_profession_defs_update_guard BEFORE UPDATE ON frozen_crew_profession_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_crew_profession_defs_delete_guard BEFORE DELETE ON frozen_crew_profession_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_crew_rank_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profession_id TEXT NOT NULL,
    rank INTEGER NOT NULL CHECK(rank BETWEEN 1 AND 3),
    experience_required INTEGER NOT NULL CHECK(experience_required>=0),
    effect_value REAL NOT NULL CHECK(effect_value>0),
    salary_multiplier REAL NOT NULL CHECK(salary_multiplier>=1),
    UNIQUE (content_snapshot_id, profession_id,experience_required),
    PRIMARY KEY (content_snapshot_id, profession_id, rank),
    FOREIGN KEY (content_snapshot_id, profession_id) REFERENCES frozen_crew_profession_defs (content_snapshot_id, profession_id)
) STRICT;
CREATE TRIGGER frozen_crew_rank_defs_insert_guard BEFORE INSERT ON frozen_crew_rank_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_crew_rank_defs_update_guard BEFORE UPDATE ON frozen_crew_rank_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_crew_rank_defs_delete_guard BEFORE DELETE ON frozen_crew_rank_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_crew_profile_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profile_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    profession_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, profile_id),
    UNIQUE (content_snapshot_id, display_name),
    FOREIGN KEY (content_snapshot_id, profession_id) REFERENCES frozen_crew_profession_defs (content_snapshot_id, profession_id)
) STRICT;
CREATE TRIGGER frozen_crew_profile_defs_insert_guard BEFORE INSERT ON frozen_crew_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_crew_profile_defs_update_guard BEFORE UPDATE ON frozen_crew_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_crew_profile_defs_delete_guard BEFORE DELETE ON frozen_crew_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_fleet_hull_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    spawn_id TEXT NOT NULL,
    crew_slots INTEGER NOT NULL CHECK(crew_slots BETWEEN 1 AND 4),
    PRIMARY KEY (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    UNIQUE (content_snapshot_id, spawn_id)
) STRICT;
CREATE TRIGGER frozen_fleet_hull_defs_insert_guard BEFORE INSERT ON frozen_fleet_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_fleet_hull_defs_update_guard BEFORE UPDATE ON frozen_fleet_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_fleet_hull_defs_delete_guard BEFORE DELETE ON frozen_fleet_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_auxiliary_drone_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    role_kind TEXT NOT NULL CHECK(role_kind IN('repair','recon')),
    drone_count INTEGER NOT NULL CHECK(drone_count BETWEEN 1 AND 3),
    speed_mps REAL NOT NULL CHECK(speed_mps>0),
    acceleration_mps2 REAL NOT NULL CHECK(acceleration_mps2>0),
    turn_rad_s REAL NOT NULL CHECK(turn_rad_s>0),
    work_range_m REAL NOT NULL CHECK(work_range_m>0),
    sortie_timeout_s REAL NOT NULL CHECK(sortie_timeout_s>0),
    return_radius_m REAL NOT NULL CHECK(return_radius_m>0),
    hull_hp REAL NOT NULL CHECK(hull_hp>0),
    restore_amount REAL NOT NULL CHECK(restore_amount>=0),
    sensor_range_m REAL NOT NULL CHECK(sensor_range_m>=0),
    observe_cycle_s REAL NOT NULL CHECK(observe_cycle_s>0),
    observation_ttl_s REAL NOT NULL CHECK(observation_ttl_s>observe_cycle_s),
    consumable_item_id TEXT,
    consumable_per_sortie INTEGER NOT NULL CHECK(consumable_per_sortie>=0),
    material_id TEXT NOT NULL,
    material_per_unit INTEGER NOT NULL CHECK(material_per_unit>0),
    credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit>0),
    CHECK((consumable_item_id IS NULL AND consumable_per_sortie=0) OR (consumable_item_id IS NOT NULL AND consumable_per_sortie>0)),
    CHECK((role_kind='repair' AND restore_amount>0 AND sensor_range_m=0) OR (role_kind='recon' AND restore_amount=0 AND sensor_range_m>0)),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, consumable_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id),
    FOREIGN KEY (content_snapshot_id, material_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_auxiliary_drone_defs_insert_guard BEFORE INSERT ON frozen_auxiliary_drone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_auxiliary_drone_defs_update_guard BEFORE UPDATE ON frozen_auxiliary_drone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_auxiliary_drone_defs_delete_guard BEFORE DELETE ON frozen_auxiliary_drone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_ship_auxiliary_permissions (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    role_kind TEXT NOT NULL CHECK(role_kind IN('repair','recon')),
    max_installed INTEGER NOT NULL CHECK(max_installed BETWEEN 1 AND 2),
    PRIMARY KEY (content_snapshot_id, ship_id, role_kind),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_ship_auxiliary_permissions_insert_guard BEFORE INSERT ON frozen_ship_auxiliary_permissions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_auxiliary_permissions_update_guard BEFORE UPDATE ON frozen_ship_auxiliary_permissions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_auxiliary_permissions_delete_guard BEFORE DELETE ON frozen_ship_auxiliary_permissions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE crew_member_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,profile_id TEXT NOT NULL,
phase TEXT NOT NULL DEFAULT 'available' CHECK(phase IN('available','hired','injured','resting')),
station_id TEXT,generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),
experience INTEGER NOT NULL DEFAULT 0 CHECK(experience>=0),contribution_total REAL NOT NULL DEFAULT 0 CHECK(contribution_total>=0),contribution_remainder REAL NOT NULL DEFAULT 0 CHECK(contribution_remainder>=0),
loyalty INTEGER NOT NULL CHECK(loyalty BETWEEN 0 AND 100),
salary_elapsed_s REAL NOT NULL DEFAULT 0 CHECK(salary_elapsed_s>=0),salary_period_credit INTEGER NOT NULL DEFAULT 0 CHECK(salary_period_credit>=0),
arrears_credit INTEGER NOT NULL DEFAULT 0 CHECK(arrears_credit>=0),unpaid_periods INTEGER NOT NULL DEFAULT 0 CHECK(unpaid_periods>=0),
recovery_remaining_s REAL NOT NULL DEFAULT 0 CHECK(recovery_remaining_s>=0),revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),
hire_paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(hire_paid_credit>=0),salary_paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(salary_paid_credit>=0),
treatment_paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(treatment_paid_credit>=0),rest_paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(rest_paid_credit>=0),salary_periods INTEGER NOT NULL DEFAULT 0 CHECK(salary_periods>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,profile_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,profile_id) REFERENCES frozen_crew_profile_defs(content_snapshot_id,profile_id),FOREIGN KEY(content_snapshot_id,station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id)) STRICT;

CREATE TRIGGER crew_member_state_insert_immutable BEFORE INSERT ON crew_member_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_member_state_update_immutable BEFORE UPDATE ON crew_member_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_member_state_delete_immutable BEFORE DELETE ON crew_member_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_member_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM crew_member_state WHERE snapshot_id=NEW.snapshot_id AND (abs(contribution_total)>=1e100 OR abs(contribution_remainder)>=1e100 OR abs(salary_elapsed_s)>=1e100 OR abs(recovery_remaining_s)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite fleet scalar'); END;

CREATE TABLE crew_assignment_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,profile_id TEXT NOT NULL,ship_instance_id TEXT NOT NULL,profession_id TEXT NOT NULL,assigned_tick INTEGER NOT NULL CHECK(assigned_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,profile_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,profile_id) REFERENCES crew_member_state(snapshot_id,world_id,content_snapshot_id,profile_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),FOREIGN KEY(content_snapshot_id,profession_id) REFERENCES frozen_crew_profession_defs(content_snapshot_id,profession_id)) STRICT;

CREATE TRIGGER crew_assignment_state_insert_immutable BEFORE INSERT ON crew_assignment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_assignment_state_update_immutable BEFORE UPDATE ON crew_assignment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_assignment_state_delete_immutable BEFORE DELETE ON crew_assignment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE fleet_deployment_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,ship_instance_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),actor_generation INTEGER NOT NULL CHECK(actor_generation>=generation),
phase TEXT NOT NULL CHECK(phase IN('deployed','retreating','returning','docked','lost')),
npc_instance_id TEXT,origin_station_id TEXT NOT NULL,return_station_id TEXT,sector_id TEXT NOT NULL,site_id TEXT NOT NULL,
order_kind TEXT NOT NULL DEFAULT 'regroup' CHECK(order_kind IN('advance','regroup','focus','retreat')),focus_target_id TEXT,
order_revision INTEGER NOT NULL DEFAULT 0 CHECK(order_revision>=0),
goal_x REAL NOT NULL,goal_y REAL NOT NULL,goal_z REAL NOT NULL,
retreat_origin_x REAL NOT NULL DEFAULT 0,retreat_origin_y REAL NOT NULL DEFAULT 0,retreat_origin_z REAL NOT NULL DEFAULT 0,
retreat_remaining_s REAL NOT NULL DEFAULT 0 CHECK(retreat_remaining_s>=0),return_remaining_s REAL NOT NULL DEFAULT 0 CHECK(return_remaining_s>=0),
deploy_paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(deploy_paid_credit>=0),created_tick INTEGER NOT NULL CHECK(created_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0),
end_reason TEXT NOT NULL DEFAULT '' CHECK(end_reason IN('','recovered','withdrawn','destroyed','player_destroyed','crew_unavailable')),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(content_snapshot_id,origin_station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id),FOREIGN KEY(content_snapshot_id,return_station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id),FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id)) STRICT;

CREATE TRIGGER fleet_deployment_state_insert_immutable BEFORE INSERT ON fleet_deployment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER fleet_deployment_state_update_immutable BEFORE UPDATE ON fleet_deployment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER fleet_deployment_state_delete_immutable BEFORE DELETE ON fleet_deployment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER fleet_deployment_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM fleet_deployment_state WHERE snapshot_id=NEW.snapshot_id AND (abs(goal_x)>=1e100 OR abs(goal_y)>=1e100 OR abs(goal_z)>=1e100 OR abs(retreat_origin_x)>=1e100 OR abs(retreat_origin_y)>=1e100 OR abs(retreat_origin_z)>=1e100 OR abs(retreat_remaining_s)>=1e100 OR abs(return_remaining_s)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite fleet scalar'); END;

CREATE TABLE fleet_receipt_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,source_token TEXT NOT NULL,ship_instance_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),
event_kind TEXT NOT NULL CHECK(event_kind IN('deploy','return','loss')),paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,source_token),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id)) STRICT;

CREATE TRIGGER fleet_receipt_state_insert_immutable BEFORE INSERT ON fleet_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER fleet_receipt_state_update_immutable BEFORE UPDATE ON fleet_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER fleet_receipt_state_delete_immutable BEFORE DELETE ON fleet_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE crew_receipt_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,source_token TEXT NOT NULL,profile_id TEXT NOT NULL,event_kind TEXT NOT NULL CHECK(event_kind IN('hire','dismiss','salary','arrears','injury','treatment','rest')),
paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0),revision INTEGER NOT NULL CHECK(revision>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,source_token),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,profile_id) REFERENCES crew_member_state(snapshot_id,world_id,content_snapshot_id,profile_id)) STRICT;

CREATE TRIGGER crew_receipt_state_insert_immutable BEFORE INSERT ON crew_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_receipt_state_update_immutable BEFORE UPDATE ON crew_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_receipt_state_delete_immutable BEFORE DELETE ON crew_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE fleet_total_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,singleton INTEGER NOT NULL CHECK(singleton=1),deployments INTEGER NOT NULL DEFAULT 0 CHECK(deployments>=0),returns INTEGER NOT NULL DEFAULT 0 CHECK(returns>=0),losses INTEGER NOT NULL DEFAULT 0 CHECK(losses>=0),paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),damage_dealt REAL NOT NULL DEFAULT 0 CHECK(damage_dealt>=0),damage_taken REAL NOT NULL DEFAULT 0 CHECK(damage_taken>=0),provided_repair_hp REAL NOT NULL DEFAULT 0 CHECK(provided_repair_hp>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,singleton),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER fleet_total_state_insert_immutable BEFORE INSERT ON fleet_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER fleet_total_state_update_immutable BEFORE UPDATE ON fleet_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER fleet_total_state_delete_immutable BEFORE DELETE ON fleet_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER fleet_total_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM fleet_total_state WHERE snapshot_id=NEW.snapshot_id AND (abs(damage_dealt)>=1e100 OR abs(damage_taken)>=1e100 OR abs(provided_repair_hp)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite fleet scalar'); END;

CREATE TABLE auxiliary_bay_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,item_instance_id TEXT NOT NULL,
stock_units INTEGER NOT NULL CHECK(stock_units>=0),deployed_units INTEGER NOT NULL DEFAULT 0 CHECK(deployed_units>=0),
lost_units INTEGER NOT NULL DEFAULT 0 CHECK(lost_units>=0),replenished_units INTEGER NOT NULL DEFAULT 0 CHECK(replenished_units>=0),
paid_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit_total>=0),material_units_total INTEGER NOT NULL DEFAULT 0 CHECK(material_units_total>=0),
command_kind TEXT NOT NULL DEFAULT 'follow' CHECK(command_kind IN('follow','recall')),
revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),sorties INTEGER NOT NULL DEFAULT 0 CHECK(sorties>=0),
energy_paid_total REAL NOT NULL DEFAULT 0 CHECK(energy_paid_total>=0),heat_paid_total REAL NOT NULL DEFAULT 0 CHECK(heat_paid_total>=0),consumable_paid_units INTEGER NOT NULL DEFAULT 0 CHECK(consumable_paid_units>=0),
repaired_hp REAL NOT NULL DEFAULT 0 CHECK(repaired_hp>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id) REFERENCES item_instance_state(snapshot_id,world_id,content_snapshot_id,item_instance_id)) STRICT;

CREATE TRIGGER auxiliary_bay_state_insert_immutable BEFORE INSERT ON auxiliary_bay_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER auxiliary_bay_state_update_immutable BEFORE UPDATE ON auxiliary_bay_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER auxiliary_bay_state_delete_immutable BEFORE DELETE ON auxiliary_bay_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER auxiliary_bay_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM auxiliary_bay_state WHERE snapshot_id=NEW.snapshot_id AND (abs(energy_paid_total)>=1e100 OR abs(heat_paid_total)>=1e100 OR abs(repaired_hp)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite fleet scalar'); END;

CREATE TABLE auxiliary_intel_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,owner_ship_id TEXT NOT NULL,module_id TEXT NOT NULL,
target_kind TEXT NOT NULL CHECK(target_kind IN('npc','resource','signal','marker')),target_id TEXT NOT NULL,
sector_id TEXT NOT NULL,site_id TEXT NOT NULL,target_generation INTEGER NOT NULL DEFAULT 0 CHECK(target_generation>=0),
observed_tick INTEGER NOT NULL CHECK(observed_tick>=0),pos_x REAL NOT NULL,pos_y REAL NOT NULL,pos_z REAL NOT NULL,
remaining_units INTEGER NOT NULL DEFAULT 0 CHECK(remaining_units>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,owner_ship_id,target_kind,target_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,owner_ship_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),FOREIGN KEY(content_snapshot_id,module_id) REFERENCES frozen_auxiliary_drone_defs(content_snapshot_id,module_id),FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id)) STRICT;

CREATE TRIGGER auxiliary_intel_state_insert_immutable BEFORE INSERT ON auxiliary_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER auxiliary_intel_state_update_immutable BEFORE UPDATE ON auxiliary_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER auxiliary_intel_state_delete_immutable BEFORE DELETE ON auxiliary_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER auxiliary_intel_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM auxiliary_intel_state WHERE snapshot_id=NEW.snapshot_id AND (abs(pos_x)>=1e100 OR abs(pos_y)>=1e100 OR abs(pos_z)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite fleet scalar'); END;

CREATE TABLE crew_support_quote_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,item_instance_id TEXT NOT NULL,profile_id TEXT NOT NULL,profession_id TEXT NOT NULL,
rank_at_payment INTEGER NOT NULL CHECK(rank_at_payment BETWEEN 1 AND 3),loyalty_at_payment INTEGER NOT NULL CHECK(loyalty_at_payment BETWEEN 0 AND 100),
restore_multiplier REAL NOT NULL CHECK(restore_multiplier>=1),paid_tick INTEGER NOT NULL CHECK(paid_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id) REFERENCES remote_support_state(snapshot_id,world_id,content_snapshot_id,item_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,profile_id) REFERENCES crew_member_state(snapshot_id,world_id,content_snapshot_id,profile_id),FOREIGN KEY(content_snapshot_id,profession_id,rank_at_payment) REFERENCES frozen_crew_rank_defs(content_snapshot_id,profession_id,rank)) STRICT;

CREATE TRIGGER crew_support_quote_state_insert_immutable BEFORE INSERT ON crew_support_quote_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_support_quote_state_update_immutable BEFORE UPDATE ON crew_support_quote_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_support_quote_state_delete_immutable BEFORE DELETE ON crew_support_quote_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER crew_support_quote_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM crew_support_quote_state WHERE snapshot_id=NEW.snapshot_id AND (abs(restore_multiplier)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite fleet scalar'); END;

CREATE TRIGGER fleet_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_fleet_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND (EXISTS(SELECT 1 FROM crew_member_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM crew_assignment_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM fleet_deployment_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM fleet_receipt_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM crew_receipt_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM fleet_total_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM auxiliary_bay_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM auxiliary_intel_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM crew_support_quote_state WHERE snapshot_id=NEW.snapshot_id)) BEGIN SELECT RAISE(ABORT,'fleet state under legacy rules'); END;

CREATE UNIQUE INDEX crew_one_profession_per_hull ON crew_assignment_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id,profession_id);

CREATE UNIQUE INDEX fleet_one_actor_per_hull ON fleet_deployment_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id) WHERE npc_instance_id IS NOT NULL;

CREATE TRIGGER fleet_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM frozen_fleet_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
BEGIN
 SELECT CASE WHEN
 (SELECT count(*) FROM crew_member_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_crew_profile_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM fleet_total_state WHERE snapshot_id=NEW.snapshot_id)<>1 OR
 (SELECT count(*) FROM crew_member_state WHERE snapshot_id=NEW.snapshot_id AND phase<>'available')>(SELECT max_recruited_crew FROM frozen_fleet_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM fleet_deployment_state WHERE snapshot_id=NEW.snapshot_id AND phase IN('deployed','retreating','returning'))>(SELECT max_owned_companions FROM frozen_fleet_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'fleet roster coverage or capacity invalid') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_member_state c JOIN frozen_crew_profile_defs p USING(content_snapshot_id,profile_id)
 JOIN frozen_crew_profession_defs j USING(content_snapshot_id,profession_id) JOIN frozen_fleet_balance_defs b USING(content_snapshot_id)
 WHERE c.snapshot_id=NEW.snapshot_id AND
 (c.hire_paid_credit<>c.generation*j.hire_fee_credit OR c.experience>b.experience_cap OR
 c.contribution_total>b.experience_cap*j.contribution_per_xp OR c.experience<>min(b.experience_cap,CAST(c.contribution_total/j.contribution_per_xp AS INTEGER)) OR
 abs(c.contribution_remainder-(c.contribution_total-c.experience*j.contribution_per_xp))>0.00001 OR
 c.salary_elapsed_s>=b.salary_period_s OR c.unpaid_periods>b.arrears_period_limit OR
 (c.generation>0 AND NOT EXISTS(SELECT 1 FROM frozen_crew_rank_defs r WHERE r.content_snapshot_id=c.content_snapshot_id AND r.profession_id=p.profession_id AND c.salary_period_credit=CAST(j.salary_credit*r.salary_multiplier+0.999999 AS INTEGER))) OR
 c.salary_paid_credit+c.arrears_credit>c.salary_periods*(SELECT max(CAST(j.salary_credit*r.salary_multiplier+0.999999 AS INTEGER)) FROM frozen_crew_rank_defs r WHERE r.content_snapshot_id=c.content_snapshot_id AND r.profession_id=p.profession_id) OR
 c.arrears_credit>c.unpaid_periods*(SELECT max(CAST(j.salary_credit*r.salary_multiplier+0.999999 AS INTEGER)) FROM frozen_crew_rank_defs r WHERE r.content_snapshot_id=c.content_snapshot_id AND r.profession_id=p.profession_id) OR
 c.salary_periods*b.salary_period_s>NEW.simulation_tick/(SELECT coalesce(value_real,value_integer) FROM frozen_rule_parameters WHERE content_snapshot_id=c.content_snapshot_id AND parameter_id='simulation_hz')+0.00001 OR
 c.treatment_paid_credit%b.injury_treatment_credit<>0 OR c.rest_paid_credit%b.rest_credit<>0 OR
 (c.phase<>'available' AND c.generation=0) OR
 (c.generation=0 AND (c.experience<>0 OR c.contribution_total<>0 OR c.loyalty<>b.loyalty_initial OR c.salary_paid_credit<>0 OR c.salary_periods<>0 OR c.arrears_credit<>0 OR c.rest_paid_credit<>0 OR c.treatment_paid_credit<>0)) OR
 (c.phase IN('injured','resting') AND (c.recovery_remaining_s<=0 OR c.recovery_remaining_s>CASE c.phase WHEN 'injured' THEN b.injury_recovery_s ELSE b.rest_duration_s END OR c.station_id IS NULL)) OR
 (c.phase NOT IN('injured','resting') AND c.recovery_remaining_s<>0) OR
 (c.phase='available' AND c.station_id IS NOT NULL) OR
 (c.phase<>'available' AND c.station_id IS NULL AND NOT EXISTS(SELECT 1 FROM crew_assignment_state a WHERE a.snapshot_id=c.snapshot_id AND a.profile_id=c.profile_id))))
 THEN RAISE(ABORT,'crew career payment timing or recovery invalid') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_assignment_state a JOIN crew_member_state c USING(snapshot_id,world_id,content_snapshot_id,profile_id)
 JOIN frozen_crew_profile_defs p USING(content_snapshot_id,profile_id) JOIN ship_state s USING(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
 JOIN frozen_fleet_hull_defs h ON h.content_snapshot_id=s.content_snapshot_id AND h.ship_id=s.ship_def_id
 WHERE a.snapshot_id=NEW.snapshot_id AND (c.phase<>'hired' OR c.station_id IS NOT NULL OR a.profession_id<>p.profession_id OR
 s.policy_id<>'normal_owned' OR s.status NOT IN('docked','flying') OR a.assigned_tick>NEW.simulation_tick OR
 (SELECT count(*) FROM crew_assignment_state other WHERE other.snapshot_id=a.snapshot_id AND other.ship_instance_id=a.ship_instance_id)>h.crew_slots))
 THEN RAISE(ABORT,'crew assignment owner profession or capacity invalid') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_support_quote_state q JOIN crew_member_state member USING(snapshot_id,world_id,content_snapshot_id,profile_id)
 JOIN frozen_crew_profile_defs profile USING(content_snapshot_id,profile_id)
 JOIN frozen_crew_profession_defs profession ON profession.content_snapshot_id=q.content_snapshot_id AND profession.profession_id=q.profession_id
 JOIN frozen_crew_rank_defs rank ON rank.content_snapshot_id=q.content_snapshot_id AND rank.profession_id=q.profession_id AND rank.rank=q.rank_at_payment
 JOIN frozen_fleet_balance_defs balance USING(content_snapshot_id)
 JOIN remote_support_state support USING(snapshot_id,world_id,content_snapshot_id,item_instance_id)
 WHERE q.snapshot_id=NEW.snapshot_id AND (support.phase<>'cycling' OR profession.effect_stat<>'remote_repair_multiplier' OR profile.profession_id<>q.profession_id OR
 member.experience<rank.experience_required OR q.loyalty_at_payment<balance.loyalty_ready_min OR q.paid_tick>NEW.simulation_tick OR
 abs(q.restore_multiplier-(1+rank.effect_value*q.loyalty_at_payment/100.0))>0.000001 OR NOT EXISTS(SELECT 1 FROM crew_assignment_state assignment
 WHERE assignment.snapshot_id=q.snapshot_id AND assignment.profile_id=q.profile_id AND assignment.profession_id=q.profession_id AND assignment.ship_instance_id=support.ship_instance_id)))
 THEN RAISE(ABORT,'crew repair quote differs from paid engineering duty') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM fleet_deployment_state f JOIN ship_state s USING(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
 JOIN frozen_ship_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.ship_id=s.ship_def_id
 JOIN frozen_fleet_balance_defs b USING(content_snapshot_id)
 WHERE f.snapshot_id=NEW.snapshot_id AND (s.policy_id<>'normal_owned' OR
 f.deploy_paid_credit<>f.generation*(b.deploy_fee_credit+CAST((d.base_ask_credit*b.deploy_hull_fee_bp+9999)/10000 AS INTEGER)) OR
 f.created_tick>NEW.simulation_tick OR f.finished_tick>NEW.simulation_tick OR f.retreat_remaining_s>b.retreat_charge_s OR f.return_remaining_s>b.return_s OR
 (f.phase='deployed' AND NOT EXISTS(SELECT 1 FROM crew_assignment_state assignment JOIN crew_member_state member USING(snapshot_id,world_id,content_snapshot_id,profile_id)
 JOIN frozen_crew_profession_defs profession USING(content_snapshot_id,profession_id)
 WHERE assignment.snapshot_id=f.snapshot_id AND assignment.ship_instance_id=f.ship_instance_id AND profession.duty_kind='pilot' AND member.phase='hired' AND member.loyalty>=b.loyalty_ready_min AND member.unpaid_periods<b.arrears_period_limit)) OR
 (f.phase IN('deployed','retreating') AND (f.npc_instance_id IS NULL OR f.npc_instance_id<>f.ship_instance_id OR s.status<>'flying' OR s.hull<=0 OR
 s.ship_instance_id=(SELECT controlled_ship_id FROM player_state WHERE snapshot_id=f.snapshot_id))) OR
 (f.phase NOT IN('deployed','retreating') AND f.npc_instance_id IS NOT NULL) OR
 (f.phase='returning' AND (s.status<>'flying' OR f.return_station_id IS NULL OR f.return_remaining_s<=0 OR
 NOT EXISTS(SELECT 1 FROM frozen_station_defs station WHERE station.content_snapshot_id=f.content_snapshot_id AND station.station_id=f.return_station_id AND station.sector_id=f.sector_id))) OR
 (f.phase<>'returning' AND f.return_remaining_s<>0) OR (f.phase<>'retreating' AND f.retreat_remaining_s<>0) OR
 (f.phase='lost' AND (s.status<>'destroyed' OR s.hull<>0)) OR
 (f.phase IN('docked','lost') AND (f.finished_tick<f.created_tick OR f.end_reason='')) OR
 (f.order_kind='focus' AND (f.focus_target_id IS NULL OR NOT EXISTS(SELECT 1 FROM npc_state target WHERE target.snapshot_id=f.snapshot_id AND target.npc_instance_id=f.focus_target_id AND target.alive=1 AND target.sector_id=f.sector_id) OR
 EXISTS(SELECT 1 FROM fleet_deployment_state ally WHERE ally.snapshot_id=f.snapshot_id AND ally.npc_instance_id=f.focus_target_id))) OR
 (f.order_kind<>'focus' AND f.focus_target_id IS NOT NULL)))
 THEN RAISE(ABORT,'owned deployment payment lifecycle or command invalid') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM fleet_deployment_state f JOIN ship_state s USING(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
 LEFT JOIN npc_state n ON n.snapshot_id=f.snapshot_id AND n.npc_instance_id=f.npc_instance_id
 LEFT JOIN frozen_fleet_hull_defs h ON h.content_snapshot_id=s.content_snapshot_id AND h.ship_id=s.ship_def_id
 LEFT JOIN spatial_state p ON p.snapshot_id=f.snapshot_id AND p.entity_kind='ship' AND p.entity_id=f.ship_instance_id
 LEFT JOIN spatial_state q ON q.snapshot_id=f.snapshot_id AND q.entity_kind='npc' AND q.entity_id=f.npc_instance_id
 WHERE f.snapshot_id=NEW.snapshot_id AND f.phase IN('deployed','retreating') AND
 (n.npc_instance_id IS NULL OR n.alive<>1 OR n.generation<>f.actor_generation OR n.spawn_id IS NOT h.spawn_id OR
 s.owner_player_id<>(SELECT player_id FROM player_state WHERE snapshot_id=f.snapshot_id) OR
 n.sector_id<>f.sector_id OR s.sector_id<>f.sector_id OR p.site_id IS NOT f.site_id OR q.site_id IS NOT f.site_id OR
 abs(n.shield-s.shield)>0.00001 OR abs(n.armor-s.armor)>0.00001 OR abs(n.hull-s.hull)>0.00001 OR
 abs(n.pos_x-s.pos_x)>0.00001 OR abs(n.pos_y-s.pos_y)>0.00001 OR abs(n.pos_z-s.pos_z)>0.00001 OR
 abs(n.quat_x-s.quat_x)>0.00001 OR abs(n.quat_y-s.quat_y)>0.00001 OR abs(n.quat_z-s.quat_z)>0.00001 OR abs(n.quat_w-s.quat_w)>0.00001 OR
 abs(n.vel_x-s.vel_x)>0.00001 OR abs(n.vel_y-s.vel_y)>0.00001 OR abs(n.vel_z-s.vel_z)>0.00001))
 THEN RAISE(ABORT,'owned actor does not match its real hull') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_state n JOIN frozen_fleet_hull_defs h USING(content_snapshot_id,spawn_id)
 WHERE n.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM fleet_deployment_state f WHERE f.snapshot_id=n.snapshot_id AND f.npc_instance_id=n.npc_instance_id AND f.phase IN('deployed','retreating')))
 THEN RAISE(ABORT,'unbound owned-fleet actor') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM auxiliary_bay_state a JOIN item_instance_state i USING(snapshot_id,world_id,content_snapshot_id,item_instance_id)
 LEFT JOIN frozen_auxiliary_drone_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.module_id=i.item_def_id
 JOIN frozen_module_defs m ON m.content_snapshot_id=i.content_snapshot_id AND m.module_id=i.item_def_id
 WHERE a.snapshot_id=NEW.snapshot_id AND (d.module_id IS NULL OR a.stock_units>d.drone_count OR
 a.stock_units+a.lost_units<>d.drone_count+a.replenished_units OR a.deployed_units<>0 OR
 a.paid_credit_total<>a.replenished_units*d.credit_per_unit OR a.material_units_total<>a.replenished_units*d.material_per_unit OR
 abs(a.energy_paid_total-a.sorties*m.energy_eu)>0.00001 OR abs(a.heat_paid_total-a.sorties*m.heat_hu)>0.00001 OR a.consumable_paid_units<>a.sorties*d.consumable_per_sortie OR
 (d.role_kind='recon' AND a.repaired_hp<>0))) THEN RAISE(ABORT,'auxiliary stock cost or outstanding sortie invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM item_instance_state i JOIN frozen_auxiliary_drone_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.module_id=i.item_def_id
 WHERE i.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM auxiliary_bay_state a WHERE a.snapshot_id=i.snapshot_id AND a.item_instance_id=i.item_instance_id)) THEN RAISE(ABORT,'auxiliary bay stock is missing') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM equipment_state e JOIN container_state c ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
 JOIN ship_state s ON s.snapshot_id=c.snapshot_id AND s.ship_instance_id=c.ship_instance_id
 JOIN frozen_auxiliary_drone_defs d ON d.content_snapshot_id=e.content_snapshot_id AND d.module_id=e.module_def_id
 LEFT JOIN frozen_ship_auxiliary_permissions p ON p.content_snapshot_id=s.content_snapshot_id AND p.ship_id=s.ship_def_id AND p.role_kind=d.role_kind
 WHERE e.snapshot_id=NEW.snapshot_id AND (p.ship_id IS NULL OR
 (SELECT count(*) FROM equipment_state other JOIN container_state oc ON oc.snapshot_id=other.snapshot_id AND oc.container_id=other.slot_container_id
 JOIN frozen_auxiliary_drone_defs od ON od.content_snapshot_id=other.content_snapshot_id AND od.module_id=other.module_def_id
 WHERE other.snapshot_id=e.snapshot_id AND oc.ship_instance_id=s.ship_instance_id AND od.role_kind=d.role_kind)>p.max_installed))
 THEN RAISE(ABORT,'auxiliary role exceeds hull permission') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM auxiliary_intel_state i JOIN frozen_auxiliary_drone_defs d USING(content_snapshot_id,module_id)
 JOIN frozen_site_defs site USING(content_snapshot_id,site_id)
 WHERE i.snapshot_id=NEW.snapshot_id AND (d.role_kind<>'recon' OR site.sector_id<>i.sector_id OR i.observed_tick>NEW.simulation_tick)) THEN RAISE(ABORT,'auxiliary observation role location or time invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_receipt_state r JOIN crew_member_state c USING(snapshot_id,world_id,content_snapshot_id,profile_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.event_tick>NEW.simulation_tick OR r.revision>c.revision)) OR
 EXISTS(SELECT 1 FROM fleet_receipt_state r WHERE r.snapshot_id=NEW.snapshot_id AND r.event_tick>NEW.simulation_tick)
 THEN RAISE(ABORT,'crew/fleet receipt precedes its action') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_fleet_balance_defs b WHERE b.content_snapshot_id=NEW.content_snapshot_id AND
 ((SELECT count(*) FROM crew_receipt_state WHERE snapshot_id=NEW.snapshot_id)>b.history_limit OR
 (SELECT count(*) FROM fleet_receipt_state WHERE snapshot_id=NEW.snapshot_id)>b.history_limit OR
 (SELECT count(*) FROM auxiliary_intel_state WHERE snapshot_id=NEW.snapshot_id)>b.history_limit))
 THEN RAISE(ABORT,'fleet history exceeds retention limit') END;
END;


DROP TRIGGER spatial_context_seal_validation;
CREATE TRIGGER spatial_context_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM spatial_state p JOIN frozen_site_defs d USING(content_snapshot_id,site_id)
  WHERE p.snapshot_id=NEW.snapshot_id AND NOT (
   (p.entity_kind='ship' AND EXISTS(SELECT 1 FROM ship_state s WHERE s.snapshot_id=p.snapshot_id AND s.ship_instance_id=p.entity_id AND s.sector_id=d.sector_id)) OR
   (p.entity_kind='npc' AND EXISTS(SELECT 1 FROM npc_state n WHERE n.snapshot_id=p.snapshot_id AND n.npc_instance_id=p.entity_id AND n.sector_id=d.sector_id)) OR
   (p.entity_kind='wreck' AND EXISTS(SELECT 1 FROM container_state c WHERE c.snapshot_id=p.snapshot_id AND c.container_id=p.entity_id AND c.kind='wreck' AND c.sector_id=d.sector_id))))
 THEN RAISE(ABORT,'orphan or wrong-sector spatial context') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_site_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND (
  EXISTS(SELECT 1 FROM ship_state s WHERE s.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM spatial_state p WHERE p.snapshot_id=s.snapshot_id AND p.entity_kind='ship' AND p.entity_id=s.ship_instance_id)) OR
  EXISTS(SELECT 1 FROM npc_state n WHERE n.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM spatial_state p WHERE p.snapshot_id=n.snapshot_id AND p.entity_kind='npc' AND p.entity_id=n.npc_instance_id)) OR
  EXISTS(SELECT 1 FROM container_state c WHERE c.snapshot_id=NEW.snapshot_id AND c.kind='wreck' AND NOT EXISTS(SELECT 1 FROM spatial_state p WHERE p.snapshot_id=c.snapshot_id AND p.entity_kind='wreck' AND p.entity_id=c.container_id)))
 THEN RAISE(ABORT,'missing spatial context') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM spatial_state p JOIN npc_state n ON n.snapshot_id=p.snapshot_id AND n.npc_instance_id=p.entity_id
  JOIN frozen_npc_spawn_defs d ON d.content_snapshot_id=n.content_snapshot_id AND d.spawn_id=n.spawn_id
  JOIN frozen_anchor_site_defs a ON a.content_snapshot_id=d.content_snapshot_id AND a.anchor_id=d.anchor_id
  WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='npc' AND NOT EXISTS(SELECT 1 FROM hire_contract_state h JOIN frozen_hire_profile_defs profile USING(content_snapshot_id,profile_id)
 WHERE h.snapshot_id=n.snapshot_id AND h.npc_instance_id=n.npc_instance_id AND h.phase IN('deployed','retreating') AND profile.spawn_id=n.spawn_id
 AND h.player_id=(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id) AND h.sector_id=n.sector_id AND h.site_id=p.site_id) AND NOT EXISTS(SELECT 1 FROM fleet_deployment_state f JOIN ship_state ship ON ship.snapshot_id=f.snapshot_id AND ship.ship_instance_id=f.ship_instance_id JOIN frozen_fleet_hull_defs hull ON hull.content_snapshot_id=ship.content_snapshot_id AND hull.ship_id=ship.ship_def_id WHERE f.snapshot_id=n.snapshot_id AND f.npc_instance_id=n.npc_instance_id AND f.npc_instance_id=f.ship_instance_id AND f.phase IN('deployed','retreating') AND ship.policy_id='normal_owned' AND ship.owner_player_id=(SELECT player_id FROM player_state WHERE snapshot_id=f.snapshot_id) AND hull.spawn_id=n.spawn_id AND f.sector_id=n.sector_id AND f.site_id=p.site_id) AND p.site_id<>coalesce((SELECT mapped.site_id FROM exploration_belt_state b
 JOIN frozen_exploration_belt_anchor_defs m ON m.content_snapshot_id=b.content_snapshot_id AND m.route_id=b.route_id AND m.base_anchor_id=d.anchor_id
 JOIN frozen_anchor_site_defs mapped ON mapped.content_snapshot_id=m.content_snapshot_id AND mapped.anchor_id=m.anchor_id
 WHERE b.snapshot_id=n.snapshot_id),a.site_id))
 THEN RAISE(ABORT,'NPC site differs from frozen spawn') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM spatial_state p JOIN ship_state s ON s.snapshot_id=p.snapshot_id AND s.ship_instance_id=p.entity_id
  JOIN frozen_station_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.station_id=s.station_id
  JOIN frozen_anchor_site_defs a ON a.content_snapshot_id=d.content_snapshot_id AND a.anchor_id=d.station_anchor_id
  WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='ship' AND s.status='docked' AND p.site_id<>a.site_id)
 THEN RAISE(ABORT,'docked ship site differs from frozen station') END;
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
 AND h.player_id=(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id)) OR EXISTS(SELECT 1 FROM scenario_actor_state a JOIN trial_state s ON s.snapshot_id=a.snapshot_id AND s.trial_id=a.scenario_id WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND a.scenario_kind='trial' AND a.actor_role IN('escort','patient') AND a.generation=s.generation AND s.phase='active') OR EXISTS(SELECT 1 FROM fleet_deployment_state fleet JOIN ship_state owned ON owned.snapshot_id=fleet.snapshot_id AND owned.ship_instance_id=fleet.ship_instance_id JOIN frozen_fleet_hull_defs hull ON hull.content_snapshot_id=owned.content_snapshot_id AND hull.ship_id=owned.ship_def_id WHERE fleet.snapshot_id=r.snapshot_id AND fleet.npc_instance_id=r.target_npc_id AND fleet.phase IN('deployed','retreating') AND fleet.npc_instance_id=fleet.ship_instance_id AND owned.policy_id='normal_owned' AND hull.spawn_id=n.spawn_id AND owned.owner_player_id=(SELECT player_id FROM player_state WHERE snapshot_id=r.snapshot_id)) OR EXISTS(SELECT 1 FROM exploration_actor_state a WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND a.actor_role='escort') OR EXISTS(SELECT 1 FROM war_fleet_state f WHERE f.snapshot_id=r.snapshot_id AND f.npc_instance_id=r.target_npc_id AND f.side='ally') OR EXISTS(SELECT 1 FROM frontier_actor_state a JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
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
 abs(e.active_remaining_s-r.remaining_s)>0.000001 OR abs(r.paid_restore-d.restore_amount*i.quality_multiplier*(CASE r.layer_id WHEN 'shield' THEN c.remote_shield_multiplier ELSE c.remote_armor_multiplier END)*coalesce((SELECT quote.restore_multiplier FROM crew_support_quote_state quote WHERE quote.snapshot_id=r.snapshot_id AND quote.item_instance_id=r.item_instance_id),1))>0.000001)))) THEN RAISE(ABORT,'remote support binding or paid cycle invalid') END;
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

CREATE TABLE database_meta_format25(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=25)) STRICT;
INSERT INTO database_meta_format25 SELECT singleton,application_id,25 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format25 RENAME TO database_meta;PRAGMA user_version=25;
