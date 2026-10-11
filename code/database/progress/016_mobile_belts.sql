-- Format12 -> 13: persistent AU route, finite staged dispersion and old-world grace.


CREATE TABLE frozen_exploration_belt_route_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    route_id TEXT NOT NULL,
    event_id TEXT NOT NULL,
    route_index INTEGER NOT NULL CHECK(route_index BETWEEN 0 AND 2),
    display_name TEXT NOT NULL,
    entry_anchor_id TEXT NOT NULL,
    exit_anchor_id TEXT NOT NULL,
    UNIQUE (content_snapshot_id, event_id,route_index),
    UNIQUE (content_snapshot_id, route_id,event_id),
    PRIMARY KEY (content_snapshot_id, route_id),
    FOREIGN KEY (content_snapshot_id, event_id) REFERENCES frozen_exploration_event_defs (content_snapshot_id, event_id),
    FOREIGN KEY (content_snapshot_id, entry_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, exit_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id)
) STRICT;
CREATE TRIGGER frozen_exploration_belt_route_defs_insert_guard BEFORE INSERT ON frozen_exploration_belt_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_belt_route_defs_update_guard BEFORE UPDATE ON frozen_exploration_belt_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_belt_route_defs_delete_guard BEFORE DELETE ON frozen_exploration_belt_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_exploration_belt_anchor_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    route_id TEXT NOT NULL,
    base_anchor_id TEXT NOT NULL,
    anchor_id TEXT NOT NULL,
    UNIQUE (content_snapshot_id, route_id,anchor_id),
    PRIMARY KEY (content_snapshot_id, route_id, base_anchor_id),
    FOREIGN KEY (content_snapshot_id, route_id) REFERENCES frozen_exploration_belt_route_defs (content_snapshot_id, route_id),
    FOREIGN KEY (content_snapshot_id, base_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id)
) STRICT;
CREATE TRIGGER frozen_exploration_belt_anchor_defs_insert_guard BEFORE INSERT ON frozen_exploration_belt_anchor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_belt_anchor_defs_update_guard BEFORE UPDATE ON frozen_exploration_belt_anchor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_belt_anchor_defs_delete_guard BEFORE DELETE ON frozen_exploration_belt_anchor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_exploration_belt_stage_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 1 AND 3),
    threshold_bp INTEGER NOT NULL CHECK(threshold_bp>0 AND threshold_bp<10000),
    remaining_cap_bp INTEGER NOT NULL CHECK(remaining_cap_bp>0 AND remaining_cap_bp<10000),
    warning_lead_s REAL NOT NULL CHECK(warning_lead_s>0),
    display_name TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, stage_index),
    UNIQUE (content_snapshot_id, threshold_bp)
) STRICT;
CREATE TRIGGER frozen_exploration_belt_stage_defs_insert_guard BEFORE INSERT ON frozen_exploration_belt_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_belt_stage_defs_update_guard BEFORE UPDATE ON frozen_exploration_belt_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_belt_stage_defs_delete_guard BEFORE DELETE ON frozen_exploration_belt_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE exploration_belt_state (
 snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
 event_id TEXT NOT NULL,route_id TEXT NOT NULL,
 stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 0 AND 3),
 warning_stage_index INTEGER NOT NULL CHECK(warning_stage_index BETWEEN 0 AND 3),
 start_elapsed_s REAL NOT NULL CHECK(start_elapsed_s>=0 AND start_elapsed_s<1e100),
 initial_units INTEGER NOT NULL CHECK(initial_units>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,event_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,event_id) REFERENCES exploration_instance_state(snapshot_id,world_id,content_snapshot_id,event_id),
 FOREIGN KEY(content_snapshot_id,route_id,event_id) REFERENCES frozen_exploration_belt_route_defs(content_snapshot_id,route_id,event_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER exploration_belt_state_insert_immutable BEFORE INSERT ON exploration_belt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_belt_state_update_immutable BEFORE UPDATE ON exploration_belt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_belt_state_delete_immutable BEFORE DELETE ON exploration_belt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

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
  WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='npc' AND p.site_id<>coalesce((SELECT mapped.site_id FROM exploration_belt_state b
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

CREATE TRIGGER mobile_belt_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM exploration_belt_state WHERE snapshot_id=NEW.snapshot_id)<>
 (SELECT count(DISTINCT event_id) FROM frozen_exploration_belt_route_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'mobile belt coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_belt_state b JOIN exploration_instance_state e USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v ON v.content_snapshot_id=e.content_snapshot_id AND v.variant_id=e.variant_id
 WHERE b.snapshot_id=NEW.snapshot_id AND (b.initial_units>v.mineral_units OR (e.phase='mineral' AND b.start_elapsed_s>=v.duration_s)))
 THEN RAISE(ABORT,'mobile belt window or initial stock exceeds frozen limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_belt_state b JOIN exploration_instance_state e USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v ON v.content_snapshot_id=e.content_snapshot_id AND v.variant_id=e.variant_id
 WHERE b.snapshot_id=NEW.snapshot_id AND (b.warning_stage_index<b.stage_index OR (e.phase='mineral' AND b.stage_index<>
 coalesce((SELECT max(s.stage_index) FROM frozen_exploration_belt_stage_defs s WHERE s.content_snapshot_id=b.content_snapshot_id
 AND e.elapsed_s>=b.start_elapsed_s+(v.duration_s-b.start_elapsed_s)*s.threshold_bp/10000.0),0))))
 THEN RAISE(ABORT,'mobile belt stage differs from saved window') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_belt_state b JOIN exploration_instance_state e USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_resource_defs d USING(content_snapshot_id,event_id) JOIN resource_state r USING(snapshot_id,world_id,content_snapshot_id,node_id)
 LEFT JOIN frozen_exploration_belt_stage_defs s ON s.content_snapshot_id=b.content_snapshot_id AND s.stage_index=b.stage_index
 WHERE b.snapshot_id=NEW.snapshot_id AND e.phase='mineral' AND r.remaining_units>CAST(b.initial_units*coalesce(s.remaining_cap_bp,10000)/10000 AS INTEGER))
 THEN RAISE(ABORT,'dispersed mineral cannot regenerate') END;
END;
CREATE TABLE database_meta_format13 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=13)
) STRICT;
INSERT INTO database_meta_format13 SELECT singleton,application_id,13 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format13 RENAME TO database_meta;
PRAGMA user_version=13;
