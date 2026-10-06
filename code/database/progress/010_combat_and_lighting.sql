-- Format6 -> 7: frozen weapon/hull/drone/lighting rules and sealed fit permissions.
CREATE TABLE frozen_weapon_behavior_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    family_id TEXT NOT NULL CHECK (family_id IN ('kinetic','thermal','pulse','drone')),
    size_class INTEGER NOT NULL CHECK (size_class BETWEEN 1 AND 3),
    fire_mode TEXT NOT NULL CHECK (fire_mode IN ('ray','projectile','drone')),
    fire_cone_half_angle_rad REAL NOT NULL CHECK (fire_cone_half_angle_rad > 0 AND fire_cone_half_angle_rad <= 3.141592653589793),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_weapon_defs (content_snapshot_id, module_id)
) STRICT;
CREATE TRIGGER frozen_weapon_behavior_defs_insert_guard BEFORE INSERT ON frozen_weapon_behavior_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_weapon_behavior_defs_update_guard BEFORE UPDATE ON frozen_weapon_behavior_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_weapon_behavior_defs_delete_guard BEFORE DELETE ON frozen_weapon_behavior_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_ship_weapon_permissions (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    family_id TEXT NOT NULL CHECK (family_id IN ('kinetic','thermal','pulse','drone')),
    max_size INTEGER NOT NULL CHECK (max_size BETWEEN 1 AND 3),
    max_installed INTEGER NOT NULL CHECK (max_installed > 0),
    PRIMARY KEY (content_snapshot_id, ship_id, family_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_ship_weapon_permissions_insert_guard BEFORE INSERT ON frozen_ship_weapon_permissions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_weapon_permissions_update_guard BEFORE UPDATE ON frozen_ship_weapon_permissions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_weapon_permissions_delete_guard BEFORE DELETE ON frozen_ship_weapon_permissions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_drone_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    module_id TEXT NOT NULL,
    drone_count INTEGER NOT NULL CHECK (drone_count BETWEEN 1 AND 3),
    speed_mps REAL NOT NULL CHECK (speed_mps > 0),
    acceleration_mps2 REAL NOT NULL CHECK (acceleration_mps2 > 0),
    turn_rad_s REAL NOT NULL CHECK (turn_rad_s > 0),
    attack_range_m REAL NOT NULL CHECK (attack_range_m > 0),
    projectile_speed_mps REAL NOT NULL CHECK (projectile_speed_mps > 0),
    sortie_timeout_s REAL NOT NULL CHECK (sortie_timeout_s > 0),
    return_radius_m REAL NOT NULL CHECK (return_radius_m > 0),
    PRIMARY KEY (content_snapshot_id, module_id),
    FOREIGN KEY (content_snapshot_id, module_id) REFERENCES frozen_weapon_defs (content_snapshot_id, module_id)
) STRICT;
CREATE TRIGGER frozen_drone_defs_insert_guard BEFORE INSERT ON frozen_drone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_drone_defs_update_guard BEFORE UPDATE ON frozen_drone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_drone_defs_delete_guard BEFORE DELETE ON frozen_drone_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_system_lighting_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    system_id TEXT NOT NULL,
    star_x_m REAL NOT NULL,
    star_y_m REAL NOT NULL,
    star_z_m REAL NOT NULL,
    light_r REAL NOT NULL CHECK (light_r BETWEEN 0 AND 1),
    light_g REAL NOT NULL CHECK (light_g BETWEEN 0 AND 1),
    light_b REAL NOT NULL CHECK (light_b BETWEEN 0 AND 1),
    energy REAL NOT NULL CHECK (energy > 0),
    ambient_energy REAL NOT NULL CHECK (ambient_energy >= 0 AND ambient_energy < energy),
    shadow_distance_m REAL NOT NULL CHECK (shadow_distance_m > 0),
    CHECK (star_x_m*star_x_m + star_y_m*star_y_m + star_z_m*star_z_m > 0),
    PRIMARY KEY (content_snapshot_id, system_id),
    FOREIGN KEY (content_snapshot_id, system_id) REFERENCES frozen_system_defs (content_snapshot_id, system_id)
) STRICT;
CREATE TRIGGER frozen_system_lighting_defs_insert_guard BEFORE INSERT ON frozen_system_lighting_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_system_lighting_defs_update_guard BEFORE UPDATE ON frozen_system_lighting_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_system_lighting_defs_delete_guard BEFORE DELETE ON frozen_system_lighting_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TRIGGER combat_equipment_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed'
 AND EXISTS(SELECT 1 FROM content_snapshot c WHERE c.content_snapshot_id=NEW.content_snapshot_id AND c.catalog_schema_version>=5)
BEGIN
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM equipment_state e
  JOIN container_state c ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
  JOIN ship_state s ON s.snapshot_id=c.snapshot_id AND s.ship_instance_id=c.ship_instance_id
  JOIN frozen_module_defs m ON m.content_snapshot_id=e.content_snapshot_id AND m.module_id=e.module_def_id
  WHERE e.snapshot_id=NEW.snapshot_id AND
   (c.slot_type<>m.slot_type
    OR NOT EXISTS(SELECT 1 FROM frozen_ship_slot_defs slot
       WHERE slot.content_snapshot_id=e.content_snapshot_id AND slot.ship_id=s.ship_def_id
        AND slot.slot_type=m.slot_type AND slot.slot_index=c.slot_index)))
 THEN RAISE(ABORT,'equipment slot incompatible with frozen hull') END;
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM equipment_state e
  JOIN container_state c ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
  JOIN ship_state s ON s.snapshot_id=c.snapshot_id AND s.ship_instance_id=c.ship_instance_id
  JOIN frozen_weapon_defs w ON w.content_snapshot_id=e.content_snapshot_id AND w.module_id=e.module_def_id
  LEFT JOIN frozen_weapon_behavior_defs b ON b.content_snapshot_id=w.content_snapshot_id AND b.module_id=w.module_id
  LEFT JOIN frozen_ship_weapon_permissions p ON p.content_snapshot_id=b.content_snapshot_id AND p.ship_id=s.ship_def_id AND p.family_id=b.family_id
  WHERE e.snapshot_id=NEW.snapshot_id AND (b.module_id IS NULL OR p.ship_id IS NULL OR b.size_class>p.max_size))
 THEN RAISE(ABORT,'weapon incompatible with frozen hull') END;
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM equipment_state e
  JOIN container_state c ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
  JOIN ship_state s ON s.snapshot_id=c.snapshot_id AND s.ship_instance_id=c.ship_instance_id
  JOIN frozen_weapon_behavior_defs b ON b.content_snapshot_id=e.content_snapshot_id AND b.module_id=e.module_def_id
  JOIN frozen_ship_weapon_permissions p ON p.content_snapshot_id=b.content_snapshot_id AND p.ship_id=s.ship_def_id AND p.family_id=b.family_id
  WHERE e.snapshot_id=NEW.snapshot_id
  GROUP BY s.ship_instance_id,b.family_id,p.max_installed HAVING count(*)>p.max_installed)
 THEN RAISE(ABORT,'weapon family limit exceeded in frozen hull') END;
END;
CREATE TABLE database_meta_format7 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=7)
) STRICT;
INSERT INTO database_meta_format7 SELECT singleton,application_id,7 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format7 RENAME TO database_meta;
PRAGMA user_version=7;
