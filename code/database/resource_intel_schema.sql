-- Resource quality and sector roles are authoritative frozen definitions.
CREATE TABLE resource_grade_defs (
 node_id TEXT PRIMARY KEY REFERENCES resource_node_defs(node_id),
 grade_level INTEGER NOT NULL CHECK(grade_level BETWEEN 1 AND 3),
 display_name TEXT NOT NULL,
 yield_multiplier_bp INTEGER NOT NULL CHECK(yield_multiplier_bp BETWEEN 10000 AND 12000)
) STRICT;
CREATE TABLE sector_activity_defs (
 sector_id TEXT PRIMARY KEY REFERENCES sector_defs(sector_id),
 resource_role TEXT NOT NULL,
 environment_hint TEXT NOT NULL,
 logistics_role TEXT NOT NULL,
 event_hint TEXT NOT NULL
) STRICT;
