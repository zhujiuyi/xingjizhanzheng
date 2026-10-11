-- Reviewed horizontal research and fit analysis.

CREATE TABLE frozen_fitting_analysis_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    burst_window_s REAL NOT NULL CHECK(burst_window_s>0),
    sustained_window_s REAL NOT NULL CHECK(sustained_window_s>burst_window_s),
    horizon_s REAL NOT NULL CHECK(horizon_s>sustained_window_s),
    default_distance_m REAL NOT NULL CHECK(default_distance_m>=0),
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_fitting_analysis_defs_insert_guard BEFORE INSERT ON frozen_fitting_analysis_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_fitting_analysis_defs_update_guard BEFORE UPDATE ON frozen_fitting_analysis_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_fitting_analysis_defs_delete_guard BEFORE DELETE ON frozen_fitting_analysis_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_weapon_tuning_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    specialization_kind TEXT NOT NULL CHECK(specialization_kind IN ('burst','sustain','range')),
    damage_ratio REAL NOT NULL CHECK(damage_ratio>0),
    cycle_ratio REAL NOT NULL CHECK(cycle_ratio>0),
    range_ratio REAL NOT NULL CHECK(range_ratio>0),
    energy_ratio REAL NOT NULL CHECK(energy_ratio>0),
    heat_ratio REAL NOT NULL CHECK(heat_ratio>0),
    speed_ratio REAL NOT NULL CHECK(speed_ratio>0),
    cone_ratio REAL NOT NULL CHECK(cone_ratio>0),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_module_defs (content_snapshot_id, module_id),
    UNIQUE (content_snapshot_id, specialization_kind)
) STRICT;
CREATE TRIGGER frozen_weapon_tuning_defs_insert_guard BEFORE INSERT ON frozen_weapon_tuning_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_weapon_tuning_defs_update_guard BEFORE UPDATE ON frozen_weapon_tuning_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_weapon_tuning_defs_delete_guard BEFORE DELETE ON frozen_weapon_tuning_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_specialization_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    tactic_points INTEGER NOT NULL CHECK(tactic_points>0),
    exploration_points INTEGER NOT NULL CHECK(exploration_points>0),
    operation_points_per_unit INTEGER NOT NULL CHECK(operation_points_per_unit>0),
    donation_item_id TEXT NOT NULL,
    donation_units_per_point INTEGER NOT NULL CHECK(donation_units_per_point>0),
    donation_credit_per_point INTEGER NOT NULL CHECK(donation_credit_per_point>0),
    max_donation_points INTEGER NOT NULL CHECK(max_donation_points>0),
    PRIMARY KEY (content_snapshot_id, singleton),
    FOREIGN KEY (content_snapshot_id, donation_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_specialization_balance_defs_insert_guard BEFORE INSERT ON frozen_specialization_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_specialization_balance_defs_update_guard BEFORE UPDATE ON frozen_specialization_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_specialization_balance_defs_delete_guard BEFORE DELETE ON frozen_specialization_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_specialization_research_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    research_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    module_id TEXT NOT NULL,
    required_points INTEGER NOT NULL CHECK(required_points>0),
    credit_per_point INTEGER NOT NULL CHECK(credit_per_point>0),
    required_unlock_id TEXT NOT NULL,
    reward_unlock_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, research_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_weapon_tuning_defs (content_snapshot_id, module_id),
    UNIQUE (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id),
    FOREIGN KEY (content_snapshot_id, reward_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id),
    UNIQUE (content_snapshot_id, reward_unlock_id)
) STRICT;
CREATE TRIGGER frozen_specialization_research_defs_insert_guard BEFORE INSERT ON frozen_specialization_research_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_specialization_research_defs_update_guard BEFORE UPDATE ON frozen_specialization_research_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_specialization_research_defs_delete_guard BEFORE DELETE ON frozen_specialization_research_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_ship_role_guidance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    role_name TEXT NOT NULL,
    strength_text TEXT NOT NULL,
    tradeoff_text TEXT NOT NULL,
    recommended_targets TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_ship_role_guidance_defs_insert_guard BEFORE INSERT ON frozen_ship_role_guidance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_role_guidance_defs_update_guard BEFORE UPDATE ON frozen_ship_role_guidance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_role_guidance_defs_delete_guard BEFORE DELETE ON frozen_ship_role_guidance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE specialization_progress_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,player_id TEXT NOT NULL,earned_points INTEGER NOT NULL CHECK(earned_points>=0),spent_points INTEGER NOT NULL CHECK(spent_points>=0 AND spent_points<=earned_points),donated_points INTEGER NOT NULL CHECK(donated_points>=0 AND donated_points<=earned_points),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER specialization_progress_state_insert_immutable BEFORE INSERT ON specialization_progress_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER specialization_progress_state_update_immutable BEFORE UPDATE ON specialization_progress_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER specialization_progress_state_delete_immutable BEFORE DELETE ON specialization_progress_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE specialization_evidence_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,player_id TEXT NOT NULL,source_token TEXT NOT NULL,source_kind TEXT NOT NULL CHECK(source_kind IN ('tactic','exploration','operation','donation')),source_def_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=0),source_units INTEGER NOT NULL CHECK(source_units>0),awarded_points INTEGER NOT NULL CHECK(awarded_points>0),material_units INTEGER NOT NULL CHECK(material_units>=0),paid_credit INTEGER NOT NULL CHECK(paid_credit>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,source_token),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER specialization_evidence_state_insert_immutable BEFORE INSERT ON specialization_evidence_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER specialization_evidence_state_update_immutable BEFORE UPDATE ON specialization_evidence_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER specialization_evidence_state_delete_immutable BEFORE DELETE ON specialization_evidence_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE specialization_research_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,player_id TEXT NOT NULL,research_id TEXT NOT NULL,invested_points INTEGER NOT NULL CHECK(invested_points>0),paid_credit INTEGER NOT NULL CHECK(paid_credit>=0),completed INTEGER NOT NULL CHECK(completed IN (0,1)),completed_tick INTEGER NOT NULL CHECK(completed_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,research_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,research_id) REFERENCES frozen_specialization_research_defs(content_snapshot_id,research_id)) STRICT;

CREATE TRIGGER specialization_research_state_insert_immutable BEFORE INSERT ON specialization_research_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER specialization_research_state_update_immutable BEFORE UPDATE ON specialization_research_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER specialization_research_state_delete_immutable BEFORE DELETE ON specialization_research_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER specialization_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM specialization_progress_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_specialization_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN RAISE(ABORT,'specialization coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM specialization_progress_state p WHERE p.snapshot_id=NEW.snapshot_id AND
 (p.earned_points<>COALESCE((SELECT sum(e.awarded_points) FROM specialization_evidence_state e WHERE e.snapshot_id=p.snapshot_id AND e.player_id=p.player_id),0) OR
 p.spent_points<>COALESCE((SELECT sum(r.invested_points) FROM specialization_research_state r WHERE r.snapshot_id=p.snapshot_id AND r.player_id=p.player_id),0) OR
 p.donated_points<>COALESCE((SELECT sum(e.awarded_points) FROM specialization_evidence_state e WHERE e.snapshot_id=p.snapshot_id AND e.player_id=p.player_id AND e.source_kind='donation'),0))) THEN RAISE(ABORT,'specialization evidence conservation failed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM specialization_research_state r JOIN frozen_specialization_research_defs d USING(content_snapshot_id,research_id) WHERE r.snapshot_id=NEW.snapshot_id AND
 (r.invested_points>d.required_points OR r.paid_credit<>r.invested_points*d.credit_per_point OR r.completed<>(r.invested_points=d.required_points) OR (r.completed=0 AND r.completed_tick<>0) OR
 (r.completed=1 AND NOT EXISTS(SELECT 1 FROM unlock_state u WHERE u.snapshot_id=r.snapshot_id AND u.player_id=r.player_id AND u.unlock_id=d.reward_unlock_id)))) THEN RAISE(ABORT,'specialization research ledger invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM specialization_evidence_state e JOIN frozen_specialization_balance_defs b USING(content_snapshot_id) WHERE e.snapshot_id=NEW.snapshot_id AND
 ((e.source_kind='donation' AND (e.source_def_id<>b.donation_item_id OR e.source_units>b.max_donation_points OR e.awarded_points<>e.source_units OR e.material_units<>e.source_units*b.donation_units_per_point OR e.paid_credit<>e.source_units*b.donation_credit_per_point)) OR
 (e.source_kind<>'donation' AND (e.material_units<>0 OR e.paid_credit<>0)) OR
 (e.source_kind='tactic' AND (e.source_units<>1 OR e.awarded_points<>b.tactic_points OR NOT EXISTS(SELECT 1 FROM frozen_npc_tactic_bindings n WHERE n.content_snapshot_id=e.content_snapshot_id AND n.spawn_id=e.source_def_id))) OR
 (e.source_kind='exploration' AND (e.source_units<>1 OR e.awarded_points<>b.exploration_points OR NOT EXISTS(SELECT 1 FROM exploration_claim_state c WHERE c.snapshot_id=e.snapshot_id AND c.player_id=e.player_id AND c.event_id=e.source_def_id AND c.generation=e.generation))) OR
 (e.source_kind='operation' AND (e.awarded_points<>e.source_units*b.operation_points_per_unit OR NOT EXISTS(SELECT 1 FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=e.snapshot_id AND o.operation_id=e.source_def_id AND o.generation>=e.generation AND e.source_units<=d.target_units))))) THEN RAISE(ABORT,'specialization source or payment invalid') END;
END;
CREATE TABLE database_meta_format16(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=16)) STRICT;
INSERT INTO database_meta_format16 SELECT singleton,application_id,16 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format16 RENAME TO database_meta;
PRAGMA user_version=16;
