-- Concrete roles for the existing fleet; earlier definitions stay frozen.
CREATE TABLE ship_role_capability_defs (
 ship_id TEXT PRIMARY KEY REFERENCES ship_defs(ship_id),
 survey_multiplier REAL NOT NULL CHECK(survey_multiplier>=1),
 sensor_multiplier REAL NOT NULL CHECK(sensor_multiplier>=1),
 remote_repair_allowed INTEGER NOT NULL CHECK(remote_repair_allowed IN (0,1)),
 remote_range_multiplier REAL NOT NULL CHECK(remote_range_multiplier>=1),
 remote_shield_multiplier REAL NOT NULL CHECK(remote_shield_multiplier>0),
 remote_armor_multiplier REAL NOT NULL CHECK(remote_armor_multiplier>0)
) STRICT;
CREATE TABLE role_balance_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 scan_reference_strength REAL NOT NULL CHECK(scan_reference_strength>0),
 min_survey_rate REAL NOT NULL CHECK(min_survey_rate>=1),
 max_survey_rate REAL NOT NULL CHECK(max_survey_rate>=min_survey_rate),
 remote_range_floor_m REAL NOT NULL CHECK(remote_range_floor_m>0),
 freight_exposure_s REAL NOT NULL CHECK(freight_exposure_s>0),
 freight_loss_damage_hp REAL NOT NULL CHECK(freight_loss_damage_hp>0)
) STRICT;
CREATE TABLE consignment_defs (
 contract_id TEXT PRIMARY KEY,display_name TEXT NOT NULL,
 origin_station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 destination_station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 max_units INTEGER NOT NULL CHECK(max_units>0),unit_volume_l REAL NOT NULL CHECK(unit_volume_l>0),
 unit_mass_kg REAL NOT NULL CHECK(unit_mass_kg>0),deposit_per_unit INTEGER NOT NULL CHECK(deposit_per_unit>0),
 fee_credit INTEGER NOT NULL CHECK(fee_credit>=0),reward_per_unit INTEGER NOT NULL CHECK(reward_per_unit>0),
 deadline_s REAL NOT NULL CHECK(deadline_s>0),cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
 CHECK(origin_station_id<>destination_station_id)
) STRICT;
