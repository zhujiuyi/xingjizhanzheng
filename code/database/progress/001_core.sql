-- Progress format 1: relational immutable complete snapshots, single offline writer.
-- All migrations execute in one BEGIN IMMEDIATE with foreign_keys enabled first.
CREATE TABLE database_meta (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
    format_version INTEGER NOT NULL CHECK(format_version=1)
) STRICT;
INSERT INTO database_meta VALUES(1,'xingjizhanjian',1);
CREATE TABLE migration_history (
    migration_id TEXT PRIMARY KEY,
    sql_sha256 TEXT NOT NULL CHECK(length(sql_sha256)=64),
    applied_utc TEXT NOT NULL
) STRICT;
-- Storage policy is engineering configuration, independent of gameplay balance.
CREATE TABLE storage_policy (
    slot_kind TEXT PRIMARY KEY CHECK(slot_kind IN ('manual','auto','quick')),
    slot_count INTEGER NOT NULL CHECK(slot_count>0)
) STRICT;
INSERT INTO storage_policy VALUES('manual',5),('auto',3),('quick',1);
CREATE TABLE content_snapshot (
    content_snapshot_id TEXT PRIMARY KEY,
    content_hash TEXT NOT NULL CHECK(length(content_hash)=64),
    pack_id TEXT NOT NULL,
    content_version TEXT NOT NULL,
    catalog_schema_version INTEGER NOT NULL CHECK(catalog_schema_version>0),
    ruleset_version TEXT NOT NULL,
    rules_code_version TEXT NOT NULL,
    asset_manifest_version TEXT NOT NULL,
    asset_manifest_sha256 TEXT NOT NULL CHECK(length(asset_manifest_sha256)=64),
    frozen_adapter_version TEXT NOT NULL,
    created_utc TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('building','sealed')),
    UNIQUE(content_hash,rules_code_version,asset_manifest_version,asset_manifest_sha256,frozen_adapter_version)
) STRICT;
CREATE TABLE content_table_manifest (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot ON DELETE CASCADE,
    table_name TEXT NOT NULL,
    schema_signature TEXT NOT NULL,
    row_count INTEGER NOT NULL CHECK(row_count>=0),
    PRIMARY KEY(content_snapshot_id,table_name)
) STRICT;
CREATE TABLE content_view_manifest (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot ON DELETE CASCADE,
    view_name TEXT NOT NULL,
    reviewed_source_sql TEXT NOT NULL,
    sql_sha256 TEXT NOT NULL CHECK(length(sql_sha256)=64),
    PRIMARY KEY(content_snapshot_id,view_name)
) STRICT;
CREATE TRIGGER content_sealed_update BEFORE UPDATE ON content_snapshot WHEN OLD.status='sealed'
BEGIN SELECT RAISE(ABORT,'sealed content metadata is immutable'); END;
CREATE TABLE profile (
    profile_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    created_utc TEXT NOT NULL
) STRICT;
CREATE TABLE profile_preference (
    profile_id TEXT PRIMARY KEY REFERENCES profile ON DELETE CASCADE,
    mouse_sensitivity REAL NOT NULL CHECK(mouse_sensitivity>0 AND mouse_sensitivity<1e100),
    master_volume REAL NOT NULL CHECK(master_volume BETWEEN 0 AND 1),
    vfx_intensity REAL NOT NULL CHECK(vfx_intensity BETWEEN 0 AND 1),
    quality_mode TEXT NOT NULL CHECK(quality_mode IN ('low','medium','high'))
) STRICT;
CREATE TABLE world (
    world_id TEXT PRIMARY KEY,
    profile_id TEXT NOT NULL REFERENCES profile,
    display_name TEXT NOT NULL,
    mode TEXT NOT NULL CHECK(mode='offline'),
    seed INTEGER NOT NULL,
    initial_content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot,
    created_utc TEXT NOT NULL,
    UNIQUE(world_id,profile_id)
) STRICT;
CREATE TABLE runtime_session (
    world_id TEXT PRIMARY KEY REFERENCES world ON DELETE CASCADE,
    session_id TEXT NOT NULL,
    epoch INTEGER NOT NULL CHECK(epoch>0),
    loaded_snapshot_id TEXT,
    resume_snapshot_id TEXT,
    transfer_barrier_id TEXT,
    last_committed_sequence INTEGER NOT NULL DEFAULT 0 CHECK(last_committed_sequence>=0),
    FOREIGN KEY(loaded_snapshot_id,world_id) REFERENCES save_snapshot(snapshot_id,world_id),
    FOREIGN KEY(resume_snapshot_id,world_id) REFERENCES save_snapshot(snapshot_id,world_id)
) STRICT;
CREATE TRIGGER session_epoch_monotonic BEFORE UPDATE ON runtime_session
WHEN NEW.epoch<OLD.epoch OR NEW.world_id<>OLD.world_id
 OR (NEW.epoch=OLD.epoch AND (NEW.session_id<>OLD.session_id OR NEW.loaded_snapshot_id IS NOT OLD.loaded_snapshot_id
 OR NEW.last_committed_sequence<OLD.last_committed_sequence))
BEGIN SELECT RAISE(ABORT,'session epoch must advance'); END;
CREATE TABLE save_snapshot (
    snapshot_id TEXT PRIMARY KEY,
    world_id TEXT NOT NULL REFERENCES world ON DELETE CASCADE,
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot,
    writer_session_id TEXT NOT NULL,
    writer_epoch INTEGER NOT NULL CHECK(writer_epoch>0),
    save_request_id TEXT NOT NULL,
    capture_sequence INTEGER NOT NULL CHECK(capture_sequence>0),
    saved_utc TEXT NOT NULL,
    simulation_tick INTEGER NOT NULL CHECK(simulation_tick>=0),
    reason TEXT NOT NULL CHECK(reason IN ('initial','manual','auto','quick','exit','travel_origin','travel_destination','migration')),
    transfer_id TEXT,
    status TEXT NOT NULL CHECK(status IN ('building','sealed')),
    UNIQUE(snapshot_id,world_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id),
    UNIQUE(world_id,writer_session_id,writer_epoch,save_request_id),
    CHECK((reason IN ('travel_origin','travel_destination'))=(transfer_id IS NOT NULL))
) STRICT;
CREATE TRIGGER snapshot_insert_guard BEFORE INSERT ON save_snapshot
WHEN NEW.status<>'building' OR NOT EXISTS(SELECT 1 FROM runtime_session
 WHERE world_id=NEW.world_id AND session_id=NEW.writer_session_id AND epoch=NEW.writer_epoch
 AND (transfer_barrier_id IS NULL OR transfer_barrier_id=NEW.transfer_id))
 OR NOT EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'stale session, transfer barrier or unsealed content'); END;
CREATE TRIGGER snapshot_update_guard BEFORE UPDATE ON save_snapshot WHEN OLD.status='sealed'
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;
CREATE TABLE snapshot_lineage (
    child_snapshot_id TEXT PRIMARY KEY REFERENCES save_snapshot ON DELETE CASCADE,
    parent_snapshot_id TEXT REFERENCES save_snapshot ON DELETE SET NULL,
    CHECK(child_snapshot_id<>parent_snapshot_id)
) STRICT;
CREATE TRIGGER lineage_world_guard BEFORE INSERT ON snapshot_lineage
WHEN NEW.parent_snapshot_id IS NOT NULL AND
 (SELECT world_id FROM save_snapshot WHERE snapshot_id=NEW.parent_snapshot_id)<>
 (SELECT world_id FROM save_snapshot WHERE snapshot_id=NEW.child_snapshot_id)
BEGIN SELECT RAISE(ABORT,'cross-world lineage'); END;
CREATE TABLE save_slot (
    slot_id TEXT PRIMARY KEY,
    profile_id TEXT NOT NULL,
    world_id TEXT NOT NULL,
    slot_kind TEXT NOT NULL CHECK(slot_kind IN ('manual','auto','quick')),
    slot_index INTEGER NOT NULL CHECK(slot_index>=0),
    label TEXT NOT NULL,
    current_snapshot_id TEXT NOT NULL,
    content_snapshot_id TEXT NOT NULL,
    writer_session_id TEXT NOT NULL,
    writer_epoch INTEGER NOT NULL CHECK(writer_epoch>0),
    generation INTEGER NOT NULL CHECK(generation>0),
    updated_utc TEXT NOT NULL,
    UNIQUE(profile_id,world_id,slot_kind,slot_index),
    FOREIGN KEY(world_id,profile_id) REFERENCES world(world_id,profile_id),
    FOREIGN KEY(current_snapshot_id,world_id,content_snapshot_id)
      REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id)
) STRICT;
CREATE TABLE world_initialization_grant (
    world_id TEXT PRIMARY KEY REFERENCES world ON DELETE CASCADE,
    grant_id TEXT NOT NULL UNIQUE,
    initial_snapshot_id TEXT NOT NULL,
    FOREIGN KEY(initial_snapshot_id,world_id) REFERENCES save_snapshot(snapshot_id,world_id)
) STRICT;
CREATE TRIGGER slot_insert_guard BEFORE INSERT ON save_slot
WHEN NEW.slot_index>=(SELECT slot_count FROM storage_policy WHERE slot_kind=NEW.slot_kind)
 OR NOT EXISTS(SELECT 1 FROM runtime_session WHERE world_id=NEW.world_id AND session_id=NEW.writer_session_id AND epoch=NEW.writer_epoch)
 OR NOT EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.current_snapshot_id AND status='sealed'
 AND writer_session_id=NEW.writer_session_id AND writer_epoch=NEW.writer_epoch
 AND capture_sequence>(SELECT last_committed_sequence FROM runtime_session WHERE world_id=NEW.world_id))
BEGIN SELECT RAISE(ABORT,'slot needs complete snapshot from active writer'); END;
CREATE TRIGGER slot_update_guard BEFORE UPDATE ON save_slot
WHEN NEW.world_id<>OLD.world_id OR NEW.profile_id<>OLD.profile_id OR NEW.generation<>OLD.generation+1
 OR NEW.slot_kind<>OLD.slot_kind OR NEW.slot_index<>OLD.slot_index
 OR NOT EXISTS(SELECT 1 FROM runtime_session WHERE world_id=NEW.world_id AND session_id=NEW.writer_session_id AND epoch=NEW.writer_epoch)
 OR NOT EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.current_snapshot_id AND status='sealed'
 AND writer_session_id=NEW.writer_session_id AND writer_epoch=NEW.writer_epoch
 AND capture_sequence>(SELECT last_committed_sequence FROM runtime_session WHERE world_id=NEW.world_id))
BEGIN SELECT RAISE(ABORT,'stale slot writer or generation'); END;

CREATE TABLE player_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    player_id TEXT NOT NULL, controlled_ship_id TEXT NOT NULL,
    currency_id TEXT NOT NULL, credit INTEGER NOT NULL CHECK(credit>=0),
    camera_mode TEXT NOT NULL CHECK(camera_mode IN ('follow','front','tactical')),
    docked_station_id TEXT,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,currency_id) REFERENCES frozen_currency_defs(content_snapshot_id,currency_id),
    FOREIGN KEY(content_snapshot_id,docked_station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,controlled_ship_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id) DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE TABLE ship_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    ship_instance_id TEXT NOT NULL, owner_player_id TEXT NOT NULL,
    ship_def_id TEXT NOT NULL, sector_id TEXT NOT NULL, station_id TEXT,
    status TEXT NOT NULL CHECK(status IN ('flying','docked','destroyed','returned')),
    pos_x REAL NOT NULL CHECK(abs(pos_x)<1e100), pos_y REAL NOT NULL CHECK(abs(pos_y)<1e100), pos_z REAL NOT NULL CHECK(abs(pos_z)<1e100),
    quat_x REAL NOT NULL, quat_y REAL NOT NULL, quat_z REAL NOT NULL, quat_w REAL NOT NULL,
    vel_x REAL NOT NULL CHECK(abs(vel_x)<1e100), vel_y REAL NOT NULL CHECK(abs(vel_y)<1e100), vel_z REAL NOT NULL CHECK(abs(vel_z)<1e100),
    angular_x REAL NOT NULL CHECK(abs(angular_x)<1e100), angular_y REAL NOT NULL CHECK(abs(angular_y)<1e100), angular_z REAL NOT NULL CHECK(abs(angular_z)<1e100),
    shield REAL NOT NULL CHECK(shield>=0 AND shield<1e100), armor REAL NOT NULL CHECK(armor>=0 AND armor<1e100),
    hull REAL NOT NULL CHECK(hull>=0 AND hull<1e100), energy REAL NOT NULL CHECK(energy>=0 AND energy<1e100), heat REAL NOT NULL CHECK(heat>=0 AND heat<1e100),
    overheated INTEGER NOT NULL CHECK(overheated IN (0,1)), shield_delay_remaining_s REAL NOT NULL CHECK(shield_delay_remaining_s>=0),
    state_version INTEGER NOT NULL CHECK(state_version>=0),
    policy_id TEXT NOT NULL,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,ship_instance_id,ship_def_id),
    CHECK(abs(quat_x*quat_x+quat_y*quat_y+quat_z*quat_z+quat_w*quat_w-1)<0.00001),
    CHECK((status='docked')=(station_id IS NOT NULL)),
    CHECK(status<>'destroyed' OR hull=0),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,owner_player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id) DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(content_snapshot_id,ship_def_id) REFERENCES frozen_ship_defs(content_snapshot_id,ship_id),
    FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),
    FOREIGN KEY(content_snapshot_id,station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id),
    FOREIGN KEY(content_snapshot_id,policy_id) REFERENCES frozen_asset_policy_defs(content_snapshot_id,policy_id)
) STRICT;
CREATE TABLE container_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    container_id TEXT NOT NULL, owner_player_id TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('station','cargo','mineral','slot','wreck')),
    ship_instance_id TEXT, ship_def_id TEXT, station_id TEXT, sector_id TEXT NOT NULL,
    slot_type TEXT, slot_index INTEGER,
    pos_x REAL, pos_y REAL, pos_z REAL,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,container_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,ship_instance_id,slot_type,slot_index),
    CHECK((kind IN ('cargo','mineral','slot'))=(ship_instance_id IS NOT NULL)),
    CHECK((ship_instance_id IS NULL)=(ship_def_id IS NULL)),
    CHECK((kind='station')=(station_id IS NOT NULL)),
    CHECK((kind='slot')=(slot_type IS NOT NULL)),
    CHECK((slot_type IS NULL)=(slot_index IS NULL)),
    CHECK((kind='wreck')=(pos_x IS NOT NULL)),
    CHECK((kind='wreck')=(pos_y IS NOT NULL)),
    CHECK((kind='wreck')=(pos_z IS NOT NULL)),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,owner_player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id) DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id,ship_def_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id,ship_def_id),
    FOREIGN KEY(content_snapshot_id,ship_def_id,slot_type,slot_index) REFERENCES frozen_ship_slot_defs(content_snapshot_id,ship_id,slot_type,slot_index),
    FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),
    FOREIGN KEY(content_snapshot_id,station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id)
) STRICT;
CREATE UNIQUE INDEX ship_hold_unique ON container_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id,kind)
WHERE kind IN ('cargo','mineral');
CREATE UNIQUE INDEX station_warehouse_unique ON container_state(snapshot_id,world_id,content_snapshot_id,owner_player_id,station_id)
WHERE kind='station';
CREATE TABLE item_instance_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    item_instance_id TEXT NOT NULL, item_def_id TEXT NOT NULL, owner_player_id TEXT NOT NULL,
    container_id TEXT NOT NULL, policy_id TEXT NOT NULL,
    origin_kind TEXT NOT NULL CHECK(origin_kind IN ('guarantee','loan','purchase','manufacture','loot')),
    salvage_recipe_id TEXT NOT NULL, durability REAL NOT NULL CHECK(durability>=0 AND durability<1e100),
    quality_multiplier REAL NOT NULL CHECK(quality_multiplier>0 AND quality_multiplier<1e100),
    manufacture_batch_id TEXT,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,item_instance_id,container_id,item_def_id),
    CHECK((origin_kind='manufacture')=(manufacture_batch_id IS NOT NULL)),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,container_id) REFERENCES container_state(snapshot_id,world_id,content_snapshot_id,container_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,owner_player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,item_def_id) REFERENCES frozen_module_defs(content_snapshot_id,module_id),
    FOREIGN KEY(content_snapshot_id,salvage_recipe_id) REFERENCES frozen_recipe_defs(content_snapshot_id,recipe_id),
    FOREIGN KEY(content_snapshot_id,policy_id) REFERENCES frozen_asset_policy_defs(content_snapshot_id,policy_id)
) STRICT;
CREATE TABLE equipment_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    slot_container_id TEXT NOT NULL, item_instance_id TEXT NOT NULL, module_def_id TEXT NOT NULL,
    cooldown_remaining_s REAL NOT NULL CHECK(cooldown_remaining_s>=0 AND cooldown_remaining_s<1e100),
    active_remaining_s REAL NOT NULL CHECK(active_remaining_s>=0 AND active_remaining_s<1e100),
    cycle_paid INTEGER NOT NULL CHECK(cycle_paid IN (0,1)),
    enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,slot_container_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,item_instance_id),
    CHECK((active_remaining_s>0)=(cycle_paid=1)),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id,slot_container_id,module_def_id)
      REFERENCES item_instance_state(snapshot_id,world_id,content_snapshot_id,item_instance_id,container_id,item_def_id)
) STRICT;
CREATE TRIGGER equipment_slot_guard BEFORE INSERT ON equipment_state
WHEN NOT EXISTS(SELECT 1 FROM container_state c JOIN frozen_module_defs m
 ON m.content_snapshot_id=c.content_snapshot_id AND m.module_id=NEW.module_def_id AND m.slot_type=c.slot_type
 WHERE c.snapshot_id=NEW.snapshot_id AND c.world_id=NEW.world_id AND c.content_snapshot_id=NEW.content_snapshot_id
 AND c.container_id=NEW.slot_container_id AND c.kind='slot')
BEGIN SELECT RAISE(ABORT,'equipment needs matching slot location'); END;
CREATE TABLE inventory_stack_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    container_id TEXT NOT NULL, stack_id TEXT NOT NULL, item_def_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity>0),
    policy_id TEXT NOT NULL,
    origin_kind TEXT NOT NULL CHECK(origin_kind IN ('normal','guarantee','loan','mission_bound')),
    bound_mission_instance_id TEXT,
    loan_id TEXT,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,stack_id),
    CHECK((origin_kind='mission_bound')=(bound_mission_instance_id IS NOT NULL)),
    CHECK((origin_kind='loan')=(loan_id IS NOT NULL)),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,container_id) REFERENCES container_state(snapshot_id,world_id,content_snapshot_id,container_id),
    FOREIGN KEY(content_snapshot_id,item_def_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id),
    FOREIGN KEY(content_snapshot_id,policy_id) REFERENCES frozen_asset_policy_defs(content_snapshot_id,policy_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,loan_id) REFERENCES loan_state(snapshot_id,world_id,content_snapshot_id,loan_id) DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,bound_mission_instance_id) REFERENCES mission_state(snapshot_id,world_id,content_snapshot_id,mission_instance_id) DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE TRIGGER stack_storage_guard BEFORE INSERT ON inventory_stack_state
WHEN NOT EXISTS(SELECT 1 FROM frozen_item_defs WHERE content_snapshot_id=NEW.content_snapshot_id AND item_id=NEW.item_def_id AND stackable=1)
 OR EXISTS(SELECT 1 FROM container_state WHERE snapshot_id=NEW.snapshot_id AND container_id=NEW.container_id AND kind='slot')
BEGIN SELECT RAISE(ABORT,'stackable item requires cargo/station/wreck container'); END;
CREATE TABLE mission_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    mission_instance_id TEXT NOT NULL, player_id TEXT NOT NULL, mission_def_id TEXT NOT NULL,
    attempt_number INTEGER NOT NULL CHECK(attempt_number>0),
    status TEXT NOT NULL,
    deadline_remaining_s REAL CHECK(deadline_remaining_s IS NULL OR deadline_remaining_s>=0),
    cooldown_remaining_s REAL NOT NULL CHECK(cooldown_remaining_s>=0),
    collected_units INTEGER NOT NULL CHECK(collected_units>=0),
    delivered_units INTEGER NOT NULL CHECK(delivered_units>=0),
    reward_claimed INTEGER NOT NULL CHECK(reward_claimed IN (0,1)),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,mission_instance_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,player_id,mission_def_id,attempt_number),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,mission_instance_id,mission_def_id),
    CHECK(status<>'completed' OR reward_claimed=1),
    CHECK(status IN ('active','ready','completed','cooldown','failed','abandoned')),
    CHECK(reward_claimed=0 OR status IN ('completed','cooldown')),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,mission_def_id) REFERENCES frozen_mission_defs(content_snapshot_id,mission_id),
    FOREIGN KEY(content_snapshot_id,status) REFERENCES frozen_mission_instance_states(content_snapshot_id,state_id)
) STRICT;
CREATE TABLE mission_availability_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    player_id TEXT NOT NULL, mission_def_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('locked','available','busy','cooldown','finished')),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,mission_def_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,mission_def_id) REFERENCES frozen_mission_defs(content_snapshot_id,mission_id)
) STRICT;
CREATE UNIQUE INDEX mission_one_active_attempt ON mission_state(snapshot_id,world_id,content_snapshot_id) WHERE status IN ('active','ready');
CREATE TABLE mission_collect_event_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    event_id TEXT NOT NULL, mission_instance_id TEXT NOT NULL, item_def_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity>0), event_tick INTEGER NOT NULL CHECK(event_tick>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,event_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,mission_instance_id) REFERENCES mission_state(snapshot_id,world_id,content_snapshot_id,mission_instance_id),
    FOREIGN KEY(content_snapshot_id,item_def_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)
) STRICT;
CREATE TABLE mission_claim_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    mission_instance_id TEXT NOT NULL, action_id TEXT NOT NULL,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,mission_instance_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,action_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,mission_instance_id) REFERENCES mission_state(snapshot_id,world_id,content_snapshot_id,mission_instance_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,action_id) REFERENCES action_receipt_state(snapshot_id,world_id,content_snapshot_id,action_id) DEFERRABLE INITIALLY DEFERRED
) STRICT;
CREATE TABLE loan_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    loan_id TEXT NOT NULL, player_id TEXT NOT NULL, loan_service_id TEXT NOT NULL, mission_instance_id TEXT NOT NULL, current_ship_id TEXT,
    status TEXT NOT NULL CHECK(status IN ('available','active','handoff_pending','lost','returned')),
    issuance_count INTEGER NOT NULL CHECK(issuance_count>=0),
    quota_remaining_units INTEGER CHECK(quota_remaining_units IS NULL OR quota_remaining_units>=0),
    replacement_remaining_s REAL NOT NULL CHECK(replacement_remaining_s>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,loan_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,player_id,loan_service_id,mission_instance_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,current_ship_id),
    CHECK((status IN ('active','handoff_pending'))=(current_ship_id IS NOT NULL)),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,loan_service_id) REFERENCES frozen_loan_service_defs(content_snapshot_id,loan_service_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,mission_instance_id) REFERENCES mission_state(snapshot_id,world_id,content_snapshot_id,mission_instance_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,current_ship_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
) STRICT;
CREATE UNIQUE INDEX loan_one_active_contract ON loan_state(snapshot_id,world_id,content_snapshot_id) WHERE status IN ('active','handoff_pending');
CREATE TABLE loan_asset_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    loan_id TEXT NOT NULL, item_instance_id TEXT NOT NULL,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,loan_id) REFERENCES loan_state(snapshot_id,world_id,content_snapshot_id,loan_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id) REFERENCES item_instance_state(snapshot_id,world_id,content_snapshot_id,item_instance_id)
) STRICT;
CREATE TABLE loan_issue_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    loan_id TEXT NOT NULL, issuance_index INTEGER NOT NULL CHECK(issuance_index>0), ship_instance_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('active','destroyed','returned')),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,loan_id,issuance_index),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,loan_id) REFERENCES loan_state(snapshot_id,world_id,content_snapshot_id,loan_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
) STRICT;
CREATE UNIQUE INDEX loan_one_active_issue ON loan_issue_state(snapshot_id,world_id,content_snapshot_id,loan_id) WHERE status='active';
CREATE TABLE manufacture_input_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    item_instance_id TEXT NOT NULL, input_item_id TEXT NOT NULL, input_quantity INTEGER NOT NULL CHECK(input_quantity>0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id,input_item_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id) REFERENCES item_instance_state(snapshot_id,world_id,content_snapshot_id,item_instance_id),
    FOREIGN KEY(content_snapshot_id,input_item_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)
) STRICT;
CREATE TABLE discovery_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    player_id TEXT NOT NULL, discovery_id TEXT NOT NULL, sector_id TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('signal','gate','resource')),
    signal_id TEXT, connection_id TEXT, node_id TEXT,
    discovered_tick INTEGER NOT NULL CHECK(discovered_tick>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,discovery_id),
    CHECK((kind='signal')=(signal_id IS NOT NULL)),
    CHECK((kind='gate')=(connection_id IS NOT NULL)),
    CHECK((kind='resource')=(node_id IS NOT NULL)),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),
    FOREIGN KEY(content_snapshot_id,signal_id) REFERENCES frozen_signal_defs(content_snapshot_id,signal_id),
    FOREIGN KEY(content_snapshot_id,connection_id) REFERENCES frozen_connection_defs(content_snapshot_id,connection_id),
    FOREIGN KEY(content_snapshot_id,node_id) REFERENCES frozen_resource_node_defs(content_snapshot_id,node_id)
) STRICT;
CREATE TABLE mission_objective_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    mission_instance_id TEXT NOT NULL, mission_def_id TEXT NOT NULL, objective_index INTEGER NOT NULL,
    progress_units INTEGER NOT NULL CHECK(progress_units>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,mission_instance_id,objective_index),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,mission_instance_id,mission_def_id) REFERENCES mission_state(snapshot_id,world_id,content_snapshot_id,mission_instance_id,mission_def_id),
    FOREIGN KEY(content_snapshot_id,mission_def_id,objective_index) REFERENCES frozen_mission_objective_defs(content_snapshot_id,mission_id,objective_index)
) STRICT;
CREATE TABLE mission_window_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    player_id TEXT NOT NULL, mission_def_id TEXT NOT NULL, remaining_s REAL NOT NULL CHECK(remaining_s>=0),
    window_index INTEGER NOT NULL CHECK(window_index>=0),
    accepted_window_count INTEGER NOT NULL CHECK(accepted_window_count>=0),
    completed_window_count INTEGER NOT NULL CHECK(completed_window_count>=0),
    last_accept_tick INTEGER CHECK(last_accept_tick IS NULL OR last_accept_tick>=0),
    last_failure_tick INTEGER CHECK(last_failure_tick IS NULL OR last_failure_tick>=0),
    last_settle_tick INTEGER CHECK(last_settle_tick IS NULL OR last_settle_tick>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,mission_def_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,mission_def_id) REFERENCES frozen_mission_defs(content_snapshot_id,mission_id)
) STRICT;
CREATE TABLE unlock_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    player_id TEXT NOT NULL, unlock_id TEXT NOT NULL, acquired_tick INTEGER NOT NULL CHECK(acquired_tick>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,unlock_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,unlock_id) REFERENCES frozen_unlock_defs(content_snapshot_id,unlock_id)
) STRICT;
CREATE TABLE reputation_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    player_id TEXT NOT NULL, faction_id TEXT NOT NULL, reputation INTEGER NOT NULL,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,faction_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_faction_defs(content_snapshot_id,faction_id)
) STRICT;
CREATE TABLE shop_stock_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    station_id TEXT NOT NULL, item_def_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity>=0), buyback_remaining_units INTEGER NOT NULL CHECK(buyback_remaining_units>=0),
    ask_credit INTEGER NOT NULL CHECK(ask_credit>=0), bid_credit INTEGER NOT NULL CHECK(bid_credit>=0),
    refresh_remaining_s REAL NOT NULL CHECK(refresh_remaining_s>=0 AND refresh_remaining_s<1e100),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,station_id,item_def_id),
    CHECK(ask_credit>bid_credit),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,station_id,item_def_id) REFERENCES frozen_station_stock_defs(content_snapshot_id,station_id,item_id)
) STRICT;
CREATE TABLE shop_ship_stock_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    station_id TEXT NOT NULL, ship_def_id TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity>=0), ask_credit INTEGER NOT NULL CHECK(ask_credit>=0), bid_credit INTEGER NOT NULL CHECK(bid_credit>=0),
    refresh_remaining_s REAL NOT NULL CHECK(refresh_remaining_s>=0 AND refresh_remaining_s<1e100),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,station_id,ship_def_id),
    CHECK(ask_credit>bid_credit),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,station_id,ship_def_id) REFERENCES frozen_station_ship_stock_defs(content_snapshot_id,station_id,ship_id)
) STRICT;
CREATE TABLE station_economy_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    station_id TEXT NOT NULL, buyback_remaining_credit INTEGER NOT NULL CHECK(buyback_remaining_credit>=0),
    refresh_remaining_s REAL NOT NULL CHECK(refresh_remaining_s>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,station_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id)
) STRICT;
CREATE TABLE sector_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    sector_id TEXT NOT NULL, visited INTEGER NOT NULL CHECK(visited IN (0,1)), generation_counter INTEGER NOT NULL CHECK(generation_counter>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,sector_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id)
) STRICT;
CREATE TABLE npc_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    npc_instance_id TEXT NOT NULL, spawn_id TEXT NOT NULL, sector_id TEXT NOT NULL,
    generation INTEGER NOT NULL CHECK(generation>=0), mission_instance_id TEXT,
    alive INTEGER NOT NULL CHECK(alive IN (0,1)), shield REAL NOT NULL CHECK(shield>=0 AND shield<1e100),
    armor REAL NOT NULL CHECK(armor>=0 AND armor<1e100), hull REAL NOT NULL CHECK(hull>=0 AND hull<1e100),
    pos_x REAL NOT NULL, pos_y REAL NOT NULL, pos_z REAL NOT NULL,
    quat_x REAL NOT NULL, quat_y REAL NOT NULL, quat_z REAL NOT NULL, quat_w REAL NOT NULL,
    vel_x REAL NOT NULL, vel_y REAL NOT NULL, vel_z REAL NOT NULL,
    angular_x REAL NOT NULL, angular_y REAL NOT NULL, angular_z REAL NOT NULL,
    behavior_phase TEXT NOT NULL CHECK(behavior_phase IN ('idle','patrol','acquire','pursue','attack','disengage','return','dead')),
    wait_remaining_s REAL NOT NULL CHECK(wait_remaining_s>=0),
    patrol_point_index INTEGER NOT NULL CHECK(patrol_point_index>=0), cooldown_remaining_s REAL NOT NULL CHECK(cooldown_remaining_s>=0),
    respawn_remaining_s REAL NOT NULL CHECK(respawn_remaining_s>=0), bounty_claimed INTEGER NOT NULL CHECK(bounty_claimed IN (0,1)), loot_claimed INTEGER NOT NULL CHECK(loot_claimed IN (0,1)),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
    UNIQUE(snapshot_id,world_id,content_snapshot_id,spawn_id,generation),
    CHECK(alive=0 OR hull>0),
    CHECK((behavior_phase='dead')=(alive=0)),
    CHECK(alive=1 OR hull=0),
    CHECK(abs(quat_x*quat_x+quat_y*quat_y+quat_z*quat_z+quat_w*quat_w-1)<0.00001),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,spawn_id) REFERENCES frozen_npc_spawn_defs(content_snapshot_id,spawn_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,mission_instance_id) REFERENCES mission_state(snapshot_id,world_id,content_snapshot_id,mission_instance_id),
    FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id)
) STRICT;
CREATE TABLE production_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    production_id TEXT NOT NULL, player_id TEXT NOT NULL, recipe_id TEXT NOT NULL, station_id TEXT NOT NULL,
    batches INTEGER NOT NULL CHECK(batches>0), output_claimed INTEGER NOT NULL CHECK(output_claimed IN (0,1)),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,production_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
    FOREIGN KEY(content_snapshot_id,recipe_id,station_id) REFERENCES frozen_recipe_access_defs(content_snapshot_id,recipe_id,station_id)
) STRICT;
CREATE TABLE resource_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    node_id TEXT NOT NULL, remaining_units INTEGER NOT NULL CHECK(remaining_units>=0),
    respawn_remaining_s REAL NOT NULL CHECK(respawn_remaining_s>=0 AND respawn_remaining_s<1e100),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,node_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,node_id) REFERENCES frozen_resource_node_defs(content_snapshot_id,node_id)
) STRICT;
CREATE TABLE gate_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    connection_id TEXT NOT NULL, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
    remaining_mass_budget_kg REAL CHECK(remaining_mass_budget_kg IS NULL OR remaining_mass_budget_kg>=0),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,connection_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,connection_id) REFERENCES frozen_connection_defs(content_snapshot_id,connection_id)
) STRICT;
CREATE TABLE ship_gate_cooldown_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    ship_instance_id TEXT NOT NULL, remaining_s REAL NOT NULL CHECK(remaining_s>=0 AND remaining_s<1e100),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
) STRICT;
CREATE TABLE rng_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    stream_id TEXT NOT NULL, algorithm TEXT NOT NULL CHECK(algorithm='pcg32_v1'),
    state_hi INTEGER NOT NULL CHECK(state_hi BETWEEN 0 AND 4294967295), state_lo INTEGER NOT NULL CHECK(state_lo BETWEEN 0 AND 4294967295),
    increment_hi INTEGER NOT NULL CHECK(increment_hi BETWEEN 0 AND 4294967295), increment_lo INTEGER NOT NULL CHECK(increment_lo BETWEEN 0 AND 4294967295 AND increment_lo%2=1),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,stream_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;
CREATE TABLE action_receipt_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    action_id TEXT NOT NULL, actor_player_id TEXT NOT NULL, source_epoch INTEGER NOT NULL CHECK(source_epoch>0),
    action_kind TEXT NOT NULL, result_code TEXT NOT NULL, result_entity_id TEXT,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,action_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,actor_player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id)
) STRICT;
CREATE TABLE transfer_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    transfer_id TEXT NOT NULL, ship_instance_id TEXT NOT NULL, connection_id TEXT NOT NULL,
    endpoint TEXT NOT NULL CHECK(endpoint IN ('origin','destination')),
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,transfer_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
    FOREIGN KEY(content_snapshot_id,connection_id) REFERENCES frozen_connection_defs(content_snapshot_id,connection_id)
) STRICT;
