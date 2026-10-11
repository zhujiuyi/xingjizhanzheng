-- Objective operations use the existing physical NPC damage authority.
CREATE TABLE operation_defs (
 operation_id TEXT PRIMARY KEY, display_name TEXT NOT NULL, operation_kind TEXT NOT NULL CHECK(operation_kind IN ('demolition','breakthrough')),
 station_id TEXT NOT NULL REFERENCES station_defs(station_id), tactical_site_id TEXT NOT NULL REFERENCES tactical_site_defs(site_id),
 entry_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id), exit_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id), duration_s REAL NOT NULL CHECK(duration_s>0), cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
 interaction_radius_m REAL NOT NULL CHECK(interaction_radius_m>0), target_units INTEGER NOT NULL CHECK(target_units>0),
 cargo_volume_l REAL NOT NULL CHECK(cargo_volume_l>=0), cargo_mass_kg REAL NOT NULL CHECK(cargo_mass_kg>=0),
 exposure_duration_s REAL NOT NULL CHECK(exposure_duration_s>0), loss_damage_hp REAL NOT NULL CHECK(loss_damage_hp>0), exposure_detection_m REAL NOT NULL CHECK(exposure_detection_m>0),
 credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit>0), reputation_per_unit INTEGER NOT NULL CHECK(reputation_per_unit>0),
 CHECK((operation_kind='demolition' AND cargo_volume_l=0 AND cargo_mass_kg=0) OR (operation_kind='breakthrough' AND cargo_volume_l>0 AND cargo_mass_kg>0))
) STRICT;
CREATE TABLE operation_structure_defs (
 spawn_id TEXT PRIMARY KEY REFERENCES npc_spawn_defs(spawn_id), operation_id TEXT NOT NULL REFERENCES operation_defs(operation_id),
 field_radius_m REAL NOT NULL CHECK(field_radius_m>0), thrust_ratio REAL NOT NULL CHECK(thrust_ratio>=0.65 AND thrust_ratio<=1)
) STRICT;
