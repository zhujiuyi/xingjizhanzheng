-- Add objective operations; old frozen definitions and manual saves remain immutable.

CREATE TABLE frozen_operation_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    operation_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    operation_kind TEXT NOT NULL CHECK(operation_kind IN ('demolition','breakthrough')),
    station_id TEXT NOT NULL,
    tactical_site_id TEXT NOT NULL,
    entry_anchor_id TEXT NOT NULL,
    exit_anchor_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    duration_s REAL NOT NULL CHECK(duration_s>0),
    cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
    interaction_radius_m REAL NOT NULL CHECK(interaction_radius_m>0),
    target_units INTEGER NOT NULL CHECK(target_units>0),
    cargo_volume_l REAL NOT NULL CHECK(cargo_volume_l>=0),
    cargo_mass_kg REAL NOT NULL CHECK(cargo_mass_kg>=0),
    exposure_duration_s REAL NOT NULL CHECK(exposure_duration_s>0),
    loss_damage_hp REAL NOT NULL CHECK(loss_damage_hp>0),
    exposure_detection_m REAL NOT NULL CHECK(exposure_detection_m>0),
    credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit>0),
    reputation_per_unit INTEGER NOT NULL CHECK(reputation_per_unit>0),
    CHECK((operation_kind='demolition' AND cargo_volume_l=0 AND cargo_mass_kg=0) OR (operation_kind='breakthrough' AND cargo_volume_l>0 AND cargo_mass_kg>0)),
    PRIMARY KEY (content_snapshot_id, operation_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, tactical_site_id) REFERENCES frozen_tactical_site_defs (content_snapshot_id, site_id),
    FOREIGN KEY (content_snapshot_id, entry_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, exit_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_operation_defs_insert_guard BEFORE INSERT ON frozen_operation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_operation_defs_update_guard BEFORE UPDATE ON frozen_operation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_operation_defs_delete_guard BEFORE DELETE ON frozen_operation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_operation_structure_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    spawn_id TEXT NOT NULL,
    operation_id TEXT NOT NULL,
    field_radius_m REAL NOT NULL CHECK(field_radius_m>0),
    thrust_ratio REAL NOT NULL CHECK(thrust_ratio>=0.65 AND thrust_ratio<=1),
    PRIMARY KEY (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, operation_id) REFERENCES frozen_operation_defs (content_snapshot_id, operation_id)
) STRICT;
CREATE TRIGGER frozen_operation_structure_defs_insert_guard BEFORE INSERT ON frozen_operation_structure_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_operation_structure_defs_update_guard BEFORE UPDATE ON frozen_operation_structure_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_operation_structure_defs_delete_guard BEFORE DELETE ON frozen_operation_structure_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE operation_state (
 snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
 operation_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=0),
 phase TEXT NOT NULL CHECK(phase IN ('available','accepted','active','ready','claimed','failed','withdrawn')),
 remaining_s REAL NOT NULL CHECK(remaining_s>=0 AND remaining_s<1e100),cooldown_remaining_s REAL NOT NULL CHECK(cooldown_remaining_s>=0 AND cooldown_remaining_s<1e100),
 payload_ship_id TEXT,loaded_units INTEGER NOT NULL CHECK(loaded_units>=0),cargo_units INTEGER NOT NULL CHECK(cargo_units>=0),completed_units INTEGER NOT NULL CHECK(completed_units>=0),
 lost_units INTEGER NOT NULL CHECK(lost_units>=0),jettisoned_units INTEGER NOT NULL CHECK(jettisoned_units>=0),
 exposure_remaining_s REAL NOT NULL CHECK(exposure_remaining_s>=0 AND exposure_remaining_s<1e100),damage_debt_hp REAL NOT NULL CHECK(damage_debt_hp>=0 AND damage_debt_hp<1e100),
 rewarded_units_total INTEGER NOT NULL CHECK(rewarded_units_total>=0),paid_credit_total INTEGER NOT NULL CHECK(paid_credit_total>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,operation_id),
 FOREIGN KEY(content_snapshot_id,operation_id) REFERENCES frozen_operation_defs(content_snapshot_id,operation_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,payload_ship_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER operation_state_insert_immutable BEFORE INSERT ON operation_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER operation_state_update_immutable BEFORE UPDATE ON operation_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER operation_state_delete_immutable BEFORE DELETE ON operation_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER operation_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM operation_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_operation_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'operation coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=NEW.snapshot_id AND
 (o.remaining_s>d.duration_s OR o.cooldown_remaining_s>d.cooldown_s OR o.exposure_remaining_s>d.exposure_duration_s OR o.damage_debt_hp>=d.loss_damage_hp OR
 o.loaded_units>d.target_units OR o.completed_units>d.target_units OR o.paid_credit_total<>o.rewarded_units_total*d.credit_per_unit OR
 (d.operation_kind='demolition' AND (o.loaded_units+o.cargo_units+o.lost_units+o.jettisoned_units<>0 OR o.payload_ship_id IS NOT NULL)) OR
 (d.operation_kind='breakthrough' AND (o.loaded_units<>o.cargo_units+o.completed_units+o.lost_units+o.jettisoned_units OR (o.cargo_units>0 AND (o.payload_ship_id IS NULL OR o.phase<>'active')))) OR
 (o.phase='ready' AND o.completed_units=0))) THEN RAISE(ABORT,'operation limits or reward ledger invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM operation_state o JOIN ship_state s ON s.snapshot_id=o.snapshot_id AND s.ship_instance_id=o.payload_ship_id WHERE o.snapshot_id=NEW.snapshot_id AND o.cargo_units>0 AND s.status<>'flying')
 THEN RAISE(ABORT,'operation cargo requires live flying owner') END;
 -- Cargo is an objective ledger, but still consumes the real ship hold and mass budget.
 SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_state s JOIN frozen_ship_defs sd ON sd.content_snapshot_id=s.content_snapshot_id AND sd.ship_id=s.ship_def_id WHERE s.snapshot_id=NEW.snapshot_id AND
 (COALESCE((SELECT sum(o.cargo_units*d.cargo_volume_l) FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=s.snapshot_id AND o.payload_ship_id=s.ship_instance_id),0)+
 COALESCE((SELECT sum(i.quantity*d.unit_volume_l) FROM inventory_stack_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)+
 COALESCE((SELECT sum(d.unit_volume_l) FROM item_instance_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)+
 COALESCE((SELECT sum(d.volume_m3*1000) FROM salvage_package_state p JOIN container_state c ON c.snapshot_id=p.snapshot_id AND c.container_id=p.host_container_id JOIN frozen_salvage_package_defs d USING(content_snapshot_id,package_def_id) WHERE p.snapshot_id=s.snapshot_id AND p.status='sealed' AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)>sd.cargo_l))
 THEN RAISE(ABORT,'operation cargo exceeds real hold') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=NEW.snapshot_id AND d.operation_kind='demolition' AND o.phase IN ('active','ready','claimed') AND
 ((SELECT count(*) FROM frozen_operation_structure_defs f JOIN npc_state n ON n.snapshot_id=o.snapshot_id AND n.content_snapshot_id=f.content_snapshot_id AND n.spawn_id=f.spawn_id AND n.generation=o.generation WHERE f.content_snapshot_id=o.content_snapshot_id AND f.operation_id=o.operation_id)<>d.target_units OR
 (SELECT count(*) FROM frozen_operation_structure_defs f JOIN npc_state n ON n.snapshot_id=o.snapshot_id AND n.content_snapshot_id=f.content_snapshot_id AND n.spawn_id=f.spawn_id AND n.generation=o.generation WHERE f.content_snapshot_id=o.content_snapshot_id AND f.operation_id=o.operation_id AND n.alive=0)<>o.completed_units))
 THEN RAISE(ABORT,'demolition progress differs from actual structures') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_state s JOIN frozen_ship_defs sd ON sd.content_snapshot_id=s.content_snapshot_id AND sd.ship_id=s.ship_def_id WHERE s.snapshot_id=NEW.snapshot_id AND
 (COALESCE((SELECT sum(o.cargo_units*d.cargo_mass_kg) FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=s.snapshot_id AND o.payload_ship_id=s.ship_instance_id),0)+
 COALESCE((SELECT sum(i.quantity*d.unit_mass_kg) FROM inventory_stack_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind IN ('cargo','mineral')),0)+
 COALESCE((SELECT sum(d.unit_mass_kg) FROM item_instance_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind IN ('cargo','mineral')),0)+
 COALESCE((SELECT sum(d.mass_kg) FROM salvage_package_state p JOIN container_state c ON c.snapshot_id=p.snapshot_id AND c.container_id=p.host_container_id JOIN frozen_salvage_package_defs d ON d.content_snapshot_id=p.content_snapshot_id AND d.package_def_id=p.package_def_id WHERE p.snapshot_id=s.snapshot_id AND p.status='sealed' AND c.ship_instance_id=s.ship_instance_id),0)>sd.max_payload_mass_kg))
 THEN RAISE(ABORT,'operation cargo exceeds shared mass budget') END;
END;
CREATE TABLE database_meta_format15(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=15)) STRICT;
INSERT INTO database_meta_format15 SELECT singleton,application_id,15 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format15 RENAME TO database_meta;
PRAGMA user_version=15;
