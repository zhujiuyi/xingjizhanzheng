-- Horizontal fire-control choices, research evidence and honest analysis windows.
CREATE TABLE fitting_analysis_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),burst_window_s REAL NOT NULL CHECK(burst_window_s>0),
 sustained_window_s REAL NOT NULL CHECK(sustained_window_s>burst_window_s),horizon_s REAL NOT NULL CHECK(horizon_s>sustained_window_s),
 default_distance_m REAL NOT NULL CHECK(default_distance_m>=0)
) STRICT;
CREATE TABLE weapon_tuning_defs (
 module_id TEXT PRIMARY KEY REFERENCES module_defs(module_id),specialization_kind TEXT NOT NULL UNIQUE CHECK(specialization_kind IN ('burst','sustain','range')),
 damage_ratio REAL NOT NULL CHECK(damage_ratio>0),cycle_ratio REAL NOT NULL CHECK(cycle_ratio>0),range_ratio REAL NOT NULL CHECK(range_ratio>0),
 energy_ratio REAL NOT NULL CHECK(energy_ratio>0),heat_ratio REAL NOT NULL CHECK(heat_ratio>0),speed_ratio REAL NOT NULL CHECK(speed_ratio>0),cone_ratio REAL NOT NULL CHECK(cone_ratio>0)
) STRICT;
CREATE TABLE specialization_balance_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),tactic_points INTEGER NOT NULL CHECK(tactic_points>0),exploration_points INTEGER NOT NULL CHECK(exploration_points>0),operation_points_per_unit INTEGER NOT NULL CHECK(operation_points_per_unit>0),
 donation_item_id TEXT NOT NULL REFERENCES item_defs(item_id),donation_units_per_point INTEGER NOT NULL CHECK(donation_units_per_point>0),donation_credit_per_point INTEGER NOT NULL CHECK(donation_credit_per_point>0),max_donation_points INTEGER NOT NULL CHECK(max_donation_points>0)
) STRICT;
CREATE TABLE specialization_research_defs (
 research_id TEXT PRIMARY KEY,display_name TEXT NOT NULL,module_id TEXT NOT NULL UNIQUE REFERENCES weapon_tuning_defs(module_id),
 required_points INTEGER NOT NULL CHECK(required_points>0),credit_per_point INTEGER NOT NULL CHECK(credit_per_point>0),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),reward_unlock_id TEXT NOT NULL UNIQUE REFERENCES unlock_defs(unlock_id)
) STRICT;
CREATE TABLE ship_role_guidance_defs (
 ship_id TEXT PRIMARY KEY REFERENCES ship_defs(ship_id),role_name TEXT NOT NULL,strength_text TEXT NOT NULL,tradeoff_text TEXT NOT NULL,recommended_targets TEXT NOT NULL
) STRICT;
