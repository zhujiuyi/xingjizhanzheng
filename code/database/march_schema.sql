-- Strategic movement uses existing gates, sites, hulls and offline world time.
CREATE TABLE march_balance_defs(
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 assembly_s REAL NOT NULL CHECK(assembly_s>0),
 align_s REAL NOT NULL CHECK(align_s>0),
 warp_speed_au_s REAL NOT NULL CHECK(warp_speed_au_s>0),
 warp_min_s REAL NOT NULL CHECK(warp_min_s>0),
 warp_max_s REAL NOT NULL CHECK(warp_max_s>=warp_min_s),
 arrival_radius_m REAL NOT NULL CHECK(arrival_radius_m>0),
 clear_distance_m REAL NOT NULL CHECK(clear_distance_m>arrival_radius_m),
 formation_m REAL NOT NULL CHECK(formation_m>0),
 gate_exit_m REAL NOT NULL CHECK(gate_exit_m>0),
 max_blocked_s REAL NOT NULL CHECK(max_blocked_s>0),
 return_supply_ratio REAL NOT NULL CHECK(return_supply_ratio BETWEEN 0 AND 1),
 gate_transit_s REAL NOT NULL CHECK(gate_transit_s>0),
 history_limit INTEGER NOT NULL CHECK(history_limit>=32),
 gate_approach_m REAL NOT NULL CHECK(gate_approach_m>0),
 gate_stop_m REAL NOT NULL CHECK(gate_stop_m>0)
) STRICT;

CREATE TABLE march_campaign_defs(
 war_id TEXT PRIMARY KEY REFERENCES civilization_war_defs(war_id),
 origin_station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 destination_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 supply_carrier_spawn_id TEXT NOT NULL REFERENCES npc_spawn_defs(spawn_id),
 travel_hull_id TEXT NOT NULL REFERENCES ship_defs(ship_id)
) STRICT;

CREATE TABLE march_route_defs(
 war_id TEXT NOT NULL REFERENCES march_campaign_defs(war_id),
 leg_index INTEGER NOT NULL CHECK(leg_index>=0),
 endpoint_id TEXT NOT NULL REFERENCES gate_endpoint_defs(endpoint_id),
 reverse_endpoint_id TEXT NOT NULL REFERENCES gate_endpoint_defs(endpoint_id),
 PRIMARY KEY(war_id,leg_index)
) STRICT;

CREATE TABLE growth_stage_defs(
 stage_id TEXT PRIMARY KEY,
 faction_id TEXT REFERENCES civilization_defs(faction_id),
 sort_order INTEGER NOT NULL CHECK(sort_order>=0),
 display_name TEXT NOT NULL,
 criterion_kind TEXT NOT NULL CHECK(criterion_kind IN('membership','rank','registration','research','owned_hull','honors','war','expedition','project')),
 reference_id TEXT NOT NULL,
 target_count INTEGER NOT NULL CHECK(target_count>0),
 station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 outcome_label TEXT NOT NULL
) STRICT;

CREATE TABLE growth_activity_defs(
 stage_id TEXT NOT NULL REFERENCES growth_stage_defs(stage_id),
 activity_index INTEGER NOT NULL CHECK(activity_index>=0),
 activity_kind TEXT NOT NULL CHECK(activity_kind IN('mission','donation','research','honor_register','honor','hull_recipe','war','expedition','project')),
 reference_id TEXT NOT NULL,
 station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 PRIMARY KEY(stage_id,activity_index)
) STRICT;

CREATE TABLE growth_grant_defs(
 task_id TEXT PRIMARY KEY REFERENCES civilization_honor_task_defs(task_id),
 reward_credit INTEGER NOT NULL CHECK(reward_credit>0),
 reward_reputation INTEGER NOT NULL CHECK(reward_reputation>0),
 display_name TEXT NOT NULL
) STRICT;
