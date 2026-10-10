-- Format10 -> 11: frozen resource quality and sector activity; no existing state changes.

CREATE TABLE frozen_resource_grade_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    node_id TEXT NOT NULL,
    grade_level INTEGER NOT NULL CHECK(grade_level BETWEEN 1 AND 3),
    display_name TEXT NOT NULL,
    yield_multiplier_bp INTEGER NOT NULL CHECK(yield_multiplier_bp BETWEEN 10000 AND 12000),
    PRIMARY KEY (content_snapshot_id, node_id),
    FOREIGN KEY (content_snapshot_id, node_id) REFERENCES frozen_resource_node_defs (content_snapshot_id, node_id)
) STRICT;
CREATE TRIGGER frozen_resource_grade_defs_insert_guard BEFORE INSERT ON frozen_resource_grade_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_resource_grade_defs_update_guard BEFORE UPDATE ON frozen_resource_grade_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_resource_grade_defs_delete_guard BEFORE DELETE ON frozen_resource_grade_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_sector_activity_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    sector_id TEXT NOT NULL,
    resource_role TEXT NOT NULL,
    environment_hint TEXT NOT NULL,
    logistics_role TEXT NOT NULL,
    event_hint TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id)
) STRICT;
CREATE TRIGGER frozen_sector_activity_defs_insert_guard BEFORE INSERT ON frozen_sector_activity_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_sector_activity_defs_update_guard BEFORE UPDATE ON frozen_sector_activity_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_sector_activity_defs_delete_guard BEFORE DELETE ON frozen_sector_activity_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE database_meta_format11 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=11)
) STRICT;
INSERT INTO database_meta_format11 SELECT singleton,application_id,11 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format11 RENAME TO database_meta;
PRAGMA user_version=11;
