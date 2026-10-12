-- Typed, finite local observations. No remote resource refresh.

CREATE TABLE frozen_situational_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    observation_interval_s REAL NOT NULL CHECK(observation_interval_s>0),
    resource_fresh_s REAL NOT NULL CHECK(resource_fresh_s>0),
    demand_fresh_s REAL NOT NULL CHECK(demand_fresh_s>0),
    extraction_warning_s REAL NOT NULL CHECK(extraction_warning_s>0),
    cue_sound_cooldown_s REAL NOT NULL CHECK(cue_sound_cooldown_s>0),
    max_flight_cues INTEGER NOT NULL CHECK(max_flight_cues BETWEEN 1 AND 4),
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_situational_balance_defs_insert_guard BEFORE INSERT ON frozen_situational_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_situational_balance_defs_update_guard BEFORE UPDATE ON frozen_situational_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_situational_balance_defs_delete_guard BEFORE DELETE ON frozen_situational_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_situational_cue_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    cue_id TEXT NOT NULL,
    title TEXT NOT NULL,
    icon_page TEXT NOT NULL,
    sound_id TEXT NOT NULL,
    priority INTEGER NOT NULL CHECK(priority>=0),
    severity TEXT NOT NULL CHECK(severity IN('warning','danger','info')),
    PRIMARY KEY (content_snapshot_id, cue_id)
) STRICT;
CREATE TRIGGER frozen_situational_cue_defs_insert_guard BEFORE INSERT ON frozen_situational_cue_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_situational_cue_defs_update_guard BEFORE UPDATE ON frozen_situational_cue_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_situational_cue_defs_delete_guard BEFORE DELETE ON frozen_situational_cue_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE resource_intel_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,node_id TEXT NOT NULL,sector_id TEXT NOT NULL,site_id TEXT NOT NULL,
 observed_tick INTEGER NOT NULL CHECK(observed_tick>=0),remaining_units INTEGER NOT NULL CHECK(remaining_units>=0),
 respawn_remaining_s REAL NOT NULL CHECK(respawn_remaining_s>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,node_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,node_id) REFERENCES frozen_resource_node_defs(content_snapshot_id,node_id),
 FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id)) STRICT;

CREATE TRIGGER resource_intel_state_insert_immutable BEFORE INSERT ON resource_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER resource_intel_state_update_immutable BEFORE UPDATE ON resource_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER resource_intel_state_delete_immutable BEFORE DELETE ON resource_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE demand_intel_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,demand_id TEXT NOT NULL,observed_tick INTEGER NOT NULL CHECK(observed_tick>=0),
 generation INTEGER NOT NULL CHECK(generation>=1),phase TEXT NOT NULL CHECK(phase IN('active','cooldown')),
 remaining_units INTEGER NOT NULL CHECK(remaining_units>=0),phase_remaining_s REAL NOT NULL CHECK(phase_remaining_s>=0),
 unit_credit INTEGER NOT NULL CHECK(unit_credit>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,demand_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,demand_id) REFERENCES frozen_station_demand_defs(content_snapshot_id,demand_id)) STRICT;

CREATE TRIGGER demand_intel_state_insert_immutable BEFORE INSERT ON demand_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER demand_intel_state_update_immutable BEFORE UPDATE ON demand_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER demand_intel_state_delete_immutable BEFORE DELETE ON demand_intel_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER situational_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM frozen_situational_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (EXISTS(SELECT 1 FROM resource_intel_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM demand_intel_state WHERE snapshot_id=NEW.snapshot_id)) THEN RAISE(ABORT,'observations under legacy rules') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM resource_intel_state i JOIN frozen_resource_node_defs n USING(content_snapshot_id,node_id)
 JOIN frozen_site_defs site USING(content_snapshot_id,site_id) WHERE i.snapshot_id=NEW.snapshot_id AND
 (i.observed_tick>NEW.simulation_tick OR i.sector_id<>n.sector_id OR site.sector_id<>i.sector_id OR i.remaining_units>n.capacity_units OR i.respawn_remaining_s>n.respawn_s)) THEN RAISE(ABORT,'invalid resource observation') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM demand_intel_state i JOIN frozen_station_demand_defs d USING(content_snapshot_id,demand_id)
 WHERE i.snapshot_id=NEW.snapshot_id AND (i.observed_tick>NEW.simulation_tick OR i.remaining_units>d.required_units OR
 i.unit_credit<>d.unit_reward_credit OR i.phase_remaining_s>CASE WHEN i.phase='active' THEN d.duration_s ELSE d.cooldown_s END)) THEN RAISE(ABORT,'invalid demand observation') END;
END;
CREATE TABLE database_meta_format21(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=21)) STRICT;
INSERT INTO database_meta_format21 SELECT singleton,application_id,21 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format21 RENAME TO database_meta;PRAGMA user_version=21;
