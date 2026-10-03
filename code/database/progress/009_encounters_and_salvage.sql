-- Format5 -> 6. Additive combat sites, fixed station salvage outcomes and
-- immutable content-upgrade lineage. Earlier migrations/definitions are retained.

CREATE TABLE frozen_encounter_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    encounter_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    anchor_id TEXT NOT NULL,
    reveal_range_m REAL NOT NULL CHECK(reveal_range_m>0 AND reveal_range_m<1e100),
    respawn_seconds REAL NOT NULL CHECK(respawn_seconds>0 AND respawn_seconds<1e100),
    warp_arrival_m REAL NOT NULL CHECK(warp_arrival_m>0 AND warp_arrival_m<reveal_range_m),
    required_unlock_id TEXT NOT NULL,
    PRIMARY KEY(content_snapshot_id,encounter_id),
    UNIQUE(content_snapshot_id,sector_id),
    UNIQUE(content_snapshot_id,anchor_id),
    FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_runtime_defs(content_snapshot_id,sector_id),
    FOREIGN KEY(content_snapshot_id,anchor_id,sector_id) REFERENCES frozen_anchor_defs(content_snapshot_id,anchor_id,sector_id),
    FOREIGN KEY(content_snapshot_id,required_unlock_id) REFERENCES frozen_unlock_defs(content_snapshot_id,unlock_id)
) STRICT;
CREATE TABLE frozen_encounter_members (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    encounter_id TEXT NOT NULL,
    spawn_id TEXT NOT NULL,
    member_index INTEGER NOT NULL CHECK(member_index>=0),
    PRIMARY KEY(content_snapshot_id,encounter_id,spawn_id),
    UNIQUE(content_snapshot_id,spawn_id),
    UNIQUE(content_snapshot_id,encounter_id,member_index),
    FOREIGN KEY(content_snapshot_id,encounter_id) REFERENCES frozen_encounter_defs(content_snapshot_id,encounter_id),
    FOREIGN KEY(content_snapshot_id,spawn_id) REFERENCES frozen_npc_spawn_defs(content_snapshot_id,spawn_id)
) STRICT;
CREATE TABLE frozen_salvage_package_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    package_def_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    volume_m3 REAL NOT NULL CHECK(volume_m3>0 AND volume_m3<1e100),
    mass_kg REAL NOT NULL CHECK(mass_kg>0 AND mass_kg<1e100),
    PRIMARY KEY(content_snapshot_id,package_def_id)
) STRICT;
CREATE TABLE frozen_salvage_reward_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    reward_id TEXT NOT NULL,
    package_def_id TEXT NOT NULL,
    weight INTEGER NOT NULL CHECK(weight>0 AND weight<=4294967295),
    credit_units INTEGER NOT NULL CHECK(credit_units>=0),
    item_def_id TEXT,
    quantity INTEGER NOT NULL CHECK(quantity>=0),
    PRIMARY KEY(content_snapshot_id,reward_id),
    UNIQUE(content_snapshot_id,reward_id,package_def_id),
    CHECK((item_def_id IS NULL AND quantity=0) OR (item_def_id IS NOT NULL AND quantity>0)),
    CHECK(credit_units>0 OR item_def_id IS NOT NULL),
    FOREIGN KEY(content_snapshot_id,package_def_id) REFERENCES frozen_salvage_package_defs(content_snapshot_id,package_def_id),
    FOREIGN KEY(content_snapshot_id,item_def_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)
) STRICT;
CREATE TABLE frozen_npc_salvage_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    npc_def_id TEXT NOT NULL,
    package_def_id TEXT NOT NULL,
    PRIMARY KEY(content_snapshot_id,npc_def_id),
    FOREIGN KEY(content_snapshot_id,npc_def_id) REFERENCES frozen_npc_defs(content_snapshot_id,npc_id),
    FOREIGN KEY(content_snapshot_id,package_def_id) REFERENCES frozen_salvage_package_defs(content_snapshot_id,package_def_id)
) STRICT;
CREATE TRIGGER frozen_encounter_defs_insert_guard BEFORE INSERT ON frozen_encounter_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_encounter_defs_update_guard BEFORE UPDATE ON frozen_encounter_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_encounter_defs_delete_guard BEFORE DELETE ON frozen_encounter_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_encounter_members_insert_guard BEFORE INSERT ON frozen_encounter_members
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_encounter_members_update_guard BEFORE UPDATE ON frozen_encounter_members
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_encounter_members_delete_guard BEFORE DELETE ON frozen_encounter_members
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_salvage_package_defs_insert_guard BEFORE INSERT ON frozen_salvage_package_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_salvage_package_defs_update_guard BEFORE UPDATE ON frozen_salvage_package_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_salvage_package_defs_delete_guard BEFORE DELETE ON frozen_salvage_package_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_salvage_reward_defs_insert_guard BEFORE INSERT ON frozen_salvage_reward_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_salvage_reward_defs_update_guard BEFORE UPDATE ON frozen_salvage_reward_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_salvage_reward_defs_delete_guard BEFORE DELETE ON frozen_salvage_reward_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_salvage_defs_insert_guard BEFORE INSERT ON frozen_npc_salvage_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_salvage_defs_update_guard BEFORE UPDATE ON frozen_npc_salvage_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_salvage_defs_delete_guard BEFORE DELETE ON frozen_npc_salvage_defs
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'frozen content is immutable'); END;

CREATE TABLE encounter_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    encounter_id TEXT NOT NULL,
    generation INTEGER NOT NULL CHECK(generation>=0),
    respawn_remaining_s REAL NOT NULL CHECK(respawn_remaining_s>=0 AND respawn_remaining_s<1e100),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,encounter_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,encounter_id) REFERENCES frozen_encounter_defs(content_snapshot_id,encounter_id)
) STRICT;
CREATE TABLE salvage_package_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    package_id TEXT NOT NULL,
    package_def_id TEXT NOT NULL,
    source_npc_instance_id TEXT NOT NULL CHECK(length(source_npc_instance_id)>0),
    source_generation INTEGER NOT NULL CHECK(source_generation>=0),
    host_container_id TEXT,
    reward_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('sealed','opened')),
    opened_station_id TEXT,
    opened_tick INTEGER NOT NULL CHECK(opened_tick>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,package_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,source_npc_instance_id,source_generation),
    CHECK((status='sealed' AND host_container_id IS NOT NULL AND opened_station_id IS NULL AND opened_tick=0)
       OR (status='opened' AND host_container_id IS NULL AND opened_station_id IS NOT NULL)),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,package_def_id) REFERENCES frozen_salvage_package_defs(content_snapshot_id,package_def_id),
    FOREIGN KEY(content_snapshot_id,reward_id,package_def_id) REFERENCES frozen_salvage_reward_defs(content_snapshot_id,reward_id,package_def_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,host_container_id) REFERENCES container_state(snapshot_id,world_id,content_snapshot_id,container_id),
    FOREIGN KEY(content_snapshot_id,opened_station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id)
) STRICT;
-- Source NPC IDs are immutable provenance, not references to live/dead rows:
-- a later group generation may retire the old NPC while an unopened package
-- and already-opened reward record must remain valid.
CREATE TRIGGER encounter_state_insert_immutable BEFORE INSERT ON encounter_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot state is immutable'); END;
CREATE TRIGGER encounter_state_update_immutable BEFORE UPDATE ON encounter_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot state is immutable'); END;
CREATE TRIGGER encounter_state_delete_immutable BEFORE DELETE ON encounter_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot state is immutable'); END;
CREATE TRIGGER salvage_package_state_insert_immutable BEFORE INSERT ON salvage_package_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot state is immutable'); END;
CREATE TRIGGER salvage_package_state_update_immutable BEFORE UPDATE ON salvage_package_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot state is immutable'); END;
CREATE TRIGGER salvage_package_state_delete_immutable BEFORE DELETE ON salvage_package_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot state is immutable'); END;

CREATE TABLE content_upgrade_record (
    world_id TEXT NOT NULL REFERENCES world(world_id),
    source_snapshot_id TEXT NOT NULL,
    upgraded_snapshot_id TEXT NOT NULL,
    old_content_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id),
    new_content_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id),
    upgrade_kind TEXT NOT NULL CHECK(length(upgrade_kind)>0),
    created_utc TEXT NOT NULL,
    PRIMARY KEY(world_id,source_snapshot_id,new_content_id),
    UNIQUE(upgraded_snapshot_id),
    CHECK(source_snapshot_id<>upgraded_snapshot_id AND old_content_id<>new_content_id),
    FOREIGN KEY(source_snapshot_id,world_id,old_content_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE RESTRICT,
    FOREIGN KEY(upgraded_snapshot_id,world_id,new_content_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE RESTRICT
) STRICT;
CREATE TRIGGER content_upgrade_insert_guard BEFORE INSERT ON content_upgrade_record
WHEN NOT EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.source_snapshot_id AND status='sealed')
 OR NOT EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.upgraded_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'content upgrade requires two sealed endpoints'); END;
CREATE TRIGGER content_upgrade_update_guard BEFORE UPDATE ON content_upgrade_record
BEGIN SELECT RAISE(ABORT,'content upgrade provenance is immutable'); END;
CREATE TRIGGER content_upgrade_delete_guard BEFORE DELETE ON content_upgrade_record
BEGIN SELECT RAISE(ABORT,'content upgrade provenance is retained'); END;

CREATE TRIGGER encounter_salvage_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_encounter_defs d WHERE d.content_snapshot_id=NEW.content_snapshot_id
  AND NOT EXISTS(SELECT 1 FROM encounter_state e WHERE e.snapshot_id=NEW.snapshot_id AND e.encounter_id=d.encounter_id))
  THEN RAISE(ABORT,'encounter state incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM encounter_state e JOIN frozen_encounter_defs d
  ON d.content_snapshot_id=e.content_snapshot_id AND d.encounter_id=e.encounter_id
  WHERE e.snapshot_id=NEW.snapshot_id AND e.respawn_remaining_s>d.respawn_seconds)
  THEN RAISE(ABORT,'encounter refresh over frozen definition') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM encounter_state e JOIN frozen_encounter_members m
  ON m.content_snapshot_id=e.content_snapshot_id AND m.encounter_id=e.encounter_id
  JOIN npc_state n ON n.snapshot_id=e.snapshot_id AND n.world_id=e.world_id AND n.content_snapshot_id=e.content_snapshot_id AND n.spawn_id=m.spawn_id
  WHERE e.snapshot_id=NEW.snapshot_id AND e.respawn_remaining_s>0 AND n.alive=1)
  THEN RAISE(ABORT,'encounter refresh cannot run while members are alive') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM salvage_package_state p JOIN container_state c
  ON c.snapshot_id=p.snapshot_id AND c.world_id=p.world_id AND c.content_snapshot_id=p.content_snapshot_id AND c.container_id=p.host_container_id
  WHERE p.snapshot_id=NEW.snapshot_id AND (c.kind NOT IN ('station','cargo','wreck') OR NOT EXISTS
   (SELECT 1 FROM player_state owner WHERE owner.snapshot_id=p.snapshot_id AND owner.player_id=c.owner_player_id)))
  THEN RAISE(ABORT,'salvage package host kind or ownership mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM salvage_package_state p WHERE p.snapshot_id=NEW.snapshot_id AND p.opened_tick>NEW.simulation_tick)
  THEN RAISE(ABORT,'salvage package opened in future tick') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM salvage_package_state p WHERE p.snapshot_id=NEW.snapshot_id AND p.status='opened'
  AND NOT EXISTS(SELECT 1 FROM frozen_station_service_defs s WHERE s.content_snapshot_id=p.content_snapshot_id
   AND s.station_id=p.opened_station_id AND s.service_id='warehouse'))
  THEN RAISE(ABORT,'salvage opening station lacks recovery service') END;
END;

CREATE TABLE database_meta_format6 (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
    format_version INTEGER NOT NULL CHECK(format_version=6)
) STRICT;
INSERT INTO database_meta_format6 SELECT singleton,application_id,6 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format6 RENAME TO database_meta;
PRAGMA user_version=6;
