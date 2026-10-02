-- Format2 -> 3: additive signal rewards and remaining world-time lifetime.
CREATE TABLE frozen_signal_unlock_rewards (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    signal_id TEXT NOT NULL,
    unlock_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, signal_id, unlock_id),
    FOREIGN KEY (content_snapshot_id, signal_id) REFERENCES frozen_signal_defs (content_snapshot_id, signal_id),
    FOREIGN KEY (content_snapshot_id, unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_signal_unlock_rewards_insert_guard BEFORE INSERT ON frozen_signal_unlock_rewards
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_signal_unlock_rewards_update_guard BEFORE UPDATE ON frozen_signal_unlock_rewards
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_signal_unlock_rewards_delete_guard BEFORE DELETE ON frozen_signal_unlock_rewards
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
ALTER TABLE gate_state ADD COLUMN lifetime_remaining_s REAL CHECK(lifetime_remaining_s IS NULL OR lifetime_remaining_s>=0);
CREATE TRIGGER gate_lifetime_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM gate_state g
 JOIN frozen_connection_defs c ON c.content_snapshot_id=g.content_snapshot_id AND c.connection_id=g.connection_id
 JOIN frozen_gate_class_defs d ON d.content_snapshot_id=c.content_snapshot_id AND d.gate_class_id=c.gate_class_id
 WHERE g.snapshot_id=NEW.snapshot_id AND g.lifetime_remaining_s IS NOT NULL
 AND (d.lifetime_s IS NULL OR g.lifetime_remaining_s>d.lifetime_s))
 THEN RAISE(ABORT,'gate lifetime over frozen definition') END;
END;
CREATE TABLE database_meta_format3 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=3)
) STRICT;
INSERT INTO database_meta_format3 SELECT singleton,application_id,3 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format3 RENAME TO database_meta;
PRAGMA user_version=3;
