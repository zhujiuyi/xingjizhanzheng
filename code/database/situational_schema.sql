-- World-time observations and readable flight feedback. Existing balance is unchanged.
CREATE TABLE situational_balance_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 observation_interval_s REAL NOT NULL CHECK(observation_interval_s>0),
 resource_fresh_s REAL NOT NULL CHECK(resource_fresh_s>0),
 demand_fresh_s REAL NOT NULL CHECK(demand_fresh_s>0),
 extraction_warning_s REAL NOT NULL CHECK(extraction_warning_s>0),
 cue_sound_cooldown_s REAL NOT NULL CHECK(cue_sound_cooldown_s>0),
 max_flight_cues INTEGER NOT NULL CHECK(max_flight_cues BETWEEN 1 AND 4)
) STRICT;
CREATE TABLE situational_cue_defs (
 cue_id TEXT PRIMARY KEY,
 title TEXT NOT NULL,
 icon_page TEXT NOT NULL,
 sound_id TEXT NOT NULL,
 priority INTEGER NOT NULL CHECK(priority>=0),
 severity TEXT NOT NULL CHECK(severity IN('warning','danger','info'))
) STRICT;
