-- Format3 -> 4: menu current-world identity is separate from a world's snapshot.
CREATE TABLE profile_resume (
 profile_id TEXT PRIMARY KEY REFERENCES profile(profile_id) ON DELETE CASCADE,
 world_id TEXT NOT NULL,
 activated_utc TEXT NOT NULL,
 FOREIGN KEY(world_id,profile_id) REFERENCES world(world_id,profile_id)
) STRICT;
-- Older formats did not retain a cross-world activation timestamp. Explicit
-- migration fallback chooses the latest persisted resume endpoint per profile.
INSERT INTO profile_resume(profile_id,world_id,activated_utc)
 SELECT p.profile_id,
 (SELECT r.world_id FROM runtime_session r JOIN world w ON w.world_id=r.world_id
  JOIN save_snapshot s ON s.snapshot_id=r.resume_snapshot_id
  WHERE w.profile_id=p.profile_id ORDER BY s.saved_utc DESC,s.rowid DESC LIMIT 1),
 strftime('%Y-%m-%dT%H:%M:%SZ','now')
 FROM profile p WHERE EXISTS(SELECT 1 FROM runtime_session r JOIN world w ON w.world_id=r.world_id
 WHERE w.profile_id=p.profile_id AND r.resume_snapshot_id IS NOT NULL);
CREATE TABLE database_meta_format4 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=4)
) STRICT;
INSERT INTO database_meta_format4 SELECT singleton,application_id,4 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format4 RENAME TO database_meta;
PRAGMA user_version=4;
