-- Additive, fixed AU routes and staged mineral dispersion. Previous definitions remain frozen.
CREATE TABLE exploration_belt_route_defs (
 route_id TEXT PRIMARY KEY,event_id TEXT NOT NULL REFERENCES exploration_event_defs(event_id),
 route_index INTEGER NOT NULL CHECK(route_index BETWEEN 0 AND 2),
 display_name TEXT NOT NULL,entry_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 exit_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 UNIQUE(event_id,route_index),UNIQUE(route_id,event_id)
) STRICT;
CREATE TABLE exploration_belt_anchor_defs (
 route_id TEXT NOT NULL REFERENCES exploration_belt_route_defs(route_id),
 base_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 PRIMARY KEY(route_id,base_anchor_id),UNIQUE(route_id,anchor_id)
) STRICT;
CREATE TABLE exploration_belt_stage_defs (
 stage_index INTEGER PRIMARY KEY CHECK(stage_index BETWEEN 1 AND 3),
 threshold_bp INTEGER NOT NULL UNIQUE CHECK(threshold_bp>0 AND threshold_bp<10000),
 remaining_cap_bp INTEGER NOT NULL CHECK(remaining_cap_bp>0 AND remaining_cap_bp<10000),
 warning_lead_s REAL NOT NULL CHECK(warning_lead_s>0),display_name TEXT NOT NULL
) STRICT;
