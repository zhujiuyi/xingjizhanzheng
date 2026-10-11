-- Format13 -> 14: doctrines, bounded propulsion interference and finite drone restoration.

CREATE TABLE frozen_tactical_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    jam_max_duration_s REAL NOT NULL CHECK(jam_max_duration_s>0),
    jam_immunity_s REAL NOT NULL CHECK(jam_immunity_s>0),
    jam_repeat_window_s REAL NOT NULL CHECK(jam_repeat_window_s>0),
    jam_repeat_multiplier REAL NOT NULL CHECK(jam_repeat_multiplier>0 AND jam_repeat_multiplier<1),
    jam_max_repeat INTEGER NOT NULL CHECK(jam_max_repeat>0),
    min_thrust_ratio REAL NOT NULL CHECK(min_thrust_ratio>0 AND min_thrust_ratio<=1),
    drone_radius_m REAL NOT NULL CHECK(drone_radius_m>0),
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_tactical_balance_defs_insert_guard BEFORE INSERT ON frozen_tactical_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_tactical_balance_defs_update_guard BEFORE UPDATE ON frozen_tactical_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_tactical_balance_defs_delete_guard BEFORE DELETE ON frozen_tactical_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_npc_tactic_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    tactic_id TEXT NOT NULL,
    tactic_kind TEXT NOT NULL CHECK(tactic_kind IN ('support','interceptor','siege','carrier')),
    display_name TEXT NOT NULL,
    model_ship_id TEXT NOT NULL,
    charge_s REAL NOT NULL CHECK(charge_s>=0),
    duration_s REAL NOT NULL CHECK(duration_s>0),
    cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
    range_m REAL NOT NULL CHECK(range_m>0),
    strength REAL NOT NULL CHECK(strength>0),
    interrupt_hp REAL NOT NULL CHECK(interrupt_hp>=0),
    energy_max REAL NOT NULL CHECK(energy_max>0),
    recharge_eu_s REAL NOT NULL CHECK(recharge_eu_s>0),
    energy_cost REAL NOT NULL CHECK(energy_cost>0 AND energy_cost<=energy_max),
    projectile_speed_mps REAL NOT NULL CHECK(projectile_speed_mps>0),
    drone_module_id TEXT,
    drone_reserve INTEGER NOT NULL CHECK(drone_reserve>=0),
    CHECK((tactic_kind='carrier')=(drone_module_id IS NOT NULL)),
    CHECK((tactic_kind='carrier')=(drone_reserve>0)),
    PRIMARY KEY (content_snapshot_id, tactic_id),
    FOREIGN KEY (content_snapshot_id, model_ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, drone_module_id) REFERENCES frozen_drone_defs (content_snapshot_id, module_id)
) STRICT;
CREATE TRIGGER frozen_npc_tactic_defs_insert_guard BEFORE INSERT ON frozen_npc_tactic_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_tactic_defs_update_guard BEFORE UPDATE ON frozen_npc_tactic_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_tactic_defs_delete_guard BEFORE DELETE ON frozen_npc_tactic_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_tactical_site_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    site_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    anchor_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    respawn_s REAL NOT NULL CHECK(respawn_s>0),
    warp_arrival_m REAL NOT NULL CHECK(warp_arrival_m>0),
    reveal_range_m REAL NOT NULL CHECK(reveal_range_m>0),
    PRIMARY KEY (content_snapshot_id, site_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_tactical_site_defs_insert_guard BEFORE INSERT ON frozen_tactical_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_tactical_site_defs_update_guard BEFORE UPDATE ON frozen_tactical_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_tactical_site_defs_delete_guard BEFORE DELETE ON frozen_tactical_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_npc_tactic_bindings (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    spawn_id TEXT NOT NULL,
    tactic_id TEXT NOT NULL,
    site_id TEXT NOT NULL,
    member_index INTEGER NOT NULL CHECK(member_index>=0),
    UNIQUE (content_snapshot_id, site_id,member_index),
    PRIMARY KEY (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, tactic_id) REFERENCES frozen_npc_tactic_defs (content_snapshot_id, tactic_id),
    FOREIGN KEY (content_snapshot_id, site_id) REFERENCES frozen_tactical_site_defs (content_snapshot_id, site_id)
) STRICT;
CREATE TRIGGER frozen_npc_tactic_bindings_insert_guard BEFORE INSERT ON frozen_npc_tactic_bindings
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_tactic_bindings_update_guard BEFORE UPDATE ON frozen_npc_tactic_bindings
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_npc_tactic_bindings_delete_guard BEFORE DELETE ON frozen_npc_tactic_bindings
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_drone_management_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    hull_hp REAL NOT NULL CHECK(hull_hp>0),
    material_id TEXT NOT NULL,
    material_per_unit INTEGER NOT NULL CHECK(material_per_unit>0),
    credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit>0),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_drone_defs (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, material_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_drone_management_defs_insert_guard BEFORE INSERT ON frozen_drone_management_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_drone_management_defs_update_guard BEFORE UPDATE ON frozen_drone_management_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_drone_management_defs_delete_guard BEFORE DELETE ON frozen_drone_management_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE tactical_site_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
site_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=0),respawn_remaining_s REAL NOT NULL CHECK(respawn_remaining_s>=0 AND respawn_remaining_s<1e100),cleared_cycles INTEGER NOT NULL CHECK(cleared_cycles>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,site_id),FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_tactical_site_defs(content_snapshot_id,site_id),
FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER tactical_site_state_insert_immutable BEFORE INSERT ON tactical_site_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER tactical_site_state_update_immutable BEFORE UPDATE ON tactical_site_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER tactical_site_state_delete_immutable BEFORE DELETE ON tactical_site_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE npc_tactic_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
npc_instance_id TEXT NOT NULL,tactic_id TEXT NOT NULL,phase TEXT NOT NULL CHECK(phase IN ('ready','charging','active','cooldown')),
 remaining_s REAL NOT NULL CHECK(remaining_s>=0 AND remaining_s<1e100),cooldown_remaining_s REAL NOT NULL CHECK(cooldown_remaining_s>=0 AND cooldown_remaining_s<1e100),energy REAL NOT NULL CHECK(energy>=0 AND energy<1e100),
 target_entity_id TEXT,aim_x REAL NOT NULL CHECK(abs(aim_x)<1e100),aim_y REAL NOT NULL CHECK(abs(aim_y)<1e100),aim_z REAL NOT NULL CHECK(abs(aim_z)<1e100),charge_start_hp REAL NOT NULL CHECK(charge_start_hp>=0 AND charge_start_hp<1e100),
 drone_stock INTEGER NOT NULL CHECK(drone_stock>=0),deployed_drones INTEGER NOT NULL CHECK(deployed_drones>=0),lost_drones INTEGER NOT NULL CHECK(lost_drones>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(content_snapshot_id,tactic_id) REFERENCES frozen_npc_tactic_defs(content_snapshot_id,tactic_id),
FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER npc_tactic_state_insert_immutable BEFORE INSERT ON npc_tactic_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER npc_tactic_state_update_immutable BEFORE UPDATE ON npc_tactic_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER npc_tactic_state_delete_immutable BEFORE DELETE ON npc_tactic_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE ship_tactical_effect_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
ship_instance_id TEXT NOT NULL,source_npc_id TEXT,
 jam_remaining_s REAL NOT NULL CHECK(jam_remaining_s>=0 AND jam_remaining_s<1e100),immunity_remaining_s REAL NOT NULL CHECK(immunity_remaining_s>=0 AND immunity_remaining_s<1e100),repeat_window_s REAL NOT NULL CHECK(repeat_window_s>=0 AND repeat_window_s<1e100),repeat_count INTEGER NOT NULL CHECK(repeat_count>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,source_npc_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER ship_tactical_effect_state_insert_immutable BEFORE INSERT ON ship_tactical_effect_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER ship_tactical_effect_state_update_immutable BEFORE UPDATE ON ship_tactical_effect_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER ship_tactical_effect_state_delete_immutable BEFORE DELETE ON ship_tactical_effect_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE drone_bay_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
item_instance_id TEXT NOT NULL,stock_units INTEGER NOT NULL CHECK(stock_units>=0),deployed_units INTEGER NOT NULL CHECK(deployed_units>=0),lost_units INTEGER NOT NULL CHECK(lost_units>=0),replenished_units INTEGER NOT NULL CHECK(replenished_units>=0),
 paid_credit_total INTEGER NOT NULL CHECK(paid_credit_total>=0),material_units_total INTEGER NOT NULL CHECK(material_units_total>=0),revision INTEGER NOT NULL CHECK(revision>=0),command_kind TEXT NOT NULL CHECK(command_kind IN ('attack','follow','recall')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id) REFERENCES item_instance_state(snapshot_id,world_id,content_snapshot_id,item_instance_id),
FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER drone_bay_state_insert_immutable BEFORE INSERT ON drone_bay_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER drone_bay_state_update_immutable BEFORE UPDATE ON drone_bay_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER drone_bay_state_delete_immutable BEFORE DELETE ON drone_bay_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER tactics_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM tactical_site_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_tactical_site_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'tactical site coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM tactical_site_state s JOIN frozen_tactical_site_defs d USING(content_snapshot_id,site_id) WHERE s.snapshot_id=NEW.snapshot_id AND s.respawn_remaining_s>d.respawn_s)
 THEN RAISE(ABORT,'tactical respawn exceeds frozen limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_tactic_state t JOIN npc_state n USING(snapshot_id,world_id,content_snapshot_id,npc_instance_id)
 JOIN frozen_npc_tactic_defs d USING(content_snapshot_id,tactic_id)
 WHERE t.snapshot_id=NEW.snapshot_id AND (NOT EXISTS(SELECT 1 FROM frozen_npc_tactic_bindings b WHERE b.content_snapshot_id=t.content_snapshot_id AND b.spawn_id=n.spawn_id AND b.tactic_id=t.tactic_id) OR
 t.energy>d.energy_max OR t.remaining_s>max(d.charge_s,d.duration_s) OR t.cooldown_remaining_s>d.cooldown_s OR t.drone_stock+t.lost_drones<>d.drone_reserve OR t.deployed_drones<>0 OR
 (t.target_entity_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ship_state s WHERE s.snapshot_id=t.snapshot_id AND s.ship_instance_id=t.target_entity_id) AND NOT EXISTS(SELECT 1 FROM npc_state s WHERE s.snapshot_id=t.snapshot_id AND s.npc_instance_id=t.target_entity_id))))
 THEN RAISE(ABORT,'invalid tactical actor context or limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_state n JOIN frozen_npc_tactic_bindings b USING(content_snapshot_id,spawn_id) WHERE n.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM npc_tactic_state t WHERE t.snapshot_id=n.snapshot_id AND t.npc_instance_id=n.npc_instance_id))
 THEN RAISE(ABORT,'tactical actor state missing') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_tactical_effect_state e JOIN frozen_tactical_balance_defs b USING(content_snapshot_id) WHERE e.snapshot_id=NEW.snapshot_id AND
 (e.jam_remaining_s>b.jam_max_duration_s OR e.immunity_remaining_s>b.jam_immunity_s OR e.repeat_window_s>b.jam_repeat_window_s OR e.repeat_count>b.jam_max_repeat OR (e.jam_remaining_s>0 AND e.source_npc_id IS NULL)))
 THEN RAISE(ABORT,'jam exceeds minimum-control policy') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM drone_bay_state b JOIN item_instance_state i USING(snapshot_id,world_id,content_snapshot_id,item_instance_id)
 JOIN frozen_drone_defs d ON d.content_snapshot_id=b.content_snapshot_id AND d.module_id=i.item_def_id
 JOIN frozen_drone_management_defs m ON m.content_snapshot_id=b.content_snapshot_id AND m.module_id=i.item_def_id
 WHERE b.snapshot_id=NEW.snapshot_id AND (b.deployed_units<>0 OR b.stock_units>d.drone_count OR b.stock_units<>d.drone_count-b.lost_units+b.replenished_units OR b.paid_credit_total<>b.replenished_units*m.credit_per_unit OR b.material_units_total<>b.replenished_units*m.material_per_unit OR (b.replenished_units>0 AND i.policy_id<>'normal_owned')))
 THEN RAISE(ABORT,'drone stock or replacement ledger mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM drone_bay_state b JOIN item_instance_state i USING(snapshot_id,world_id,content_snapshot_id,item_instance_id) WHERE b.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM frozen_drone_management_defs d WHERE d.content_snapshot_id=b.content_snapshot_id AND d.module_id=i.item_def_id)) OR
 EXISTS(SELECT 1 FROM item_instance_state i JOIN frozen_drone_management_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.module_id=i.item_def_id WHERE i.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM drone_bay_state b WHERE b.snapshot_id=i.snapshot_id AND b.item_instance_id=i.item_instance_id))
 THEN RAISE(ABORT,'drone bay identity or coverage incomplete') END;
END;
CREATE TABLE database_meta_format14(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=14)) STRICT;
INSERT INTO database_meta_format14 SELECT singleton,application_id,14 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format14 RENAME TO database_meta;
PRAGMA user_version=14;
