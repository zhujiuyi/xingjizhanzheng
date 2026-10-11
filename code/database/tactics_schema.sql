CREATE TABLE tactical_balance_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),jam_max_duration_s REAL NOT NULL CHECK(jam_max_duration_s>0),
 jam_immunity_s REAL NOT NULL CHECK(jam_immunity_s>0),jam_repeat_window_s REAL NOT NULL CHECK(jam_repeat_window_s>0),
 jam_repeat_multiplier REAL NOT NULL CHECK(jam_repeat_multiplier>0 AND jam_repeat_multiplier<1),
 jam_max_repeat INTEGER NOT NULL CHECK(jam_max_repeat>0),min_thrust_ratio REAL NOT NULL CHECK(min_thrust_ratio>0 AND min_thrust_ratio<=1),
 drone_radius_m REAL NOT NULL CHECK(drone_radius_m>0)
) STRICT;
CREATE TABLE npc_tactic_defs (
 tactic_id TEXT PRIMARY KEY,tactic_kind TEXT NOT NULL CHECK(tactic_kind IN ('support','interceptor','siege','carrier')),
 display_name TEXT NOT NULL,model_ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
 charge_s REAL NOT NULL CHECK(charge_s>=0),duration_s REAL NOT NULL CHECK(duration_s>0),
 cooldown_s REAL NOT NULL CHECK(cooldown_s>0),range_m REAL NOT NULL CHECK(range_m>0),
 strength REAL NOT NULL CHECK(strength>0),interrupt_hp REAL NOT NULL CHECK(interrupt_hp>=0),
 energy_max REAL NOT NULL CHECK(energy_max>0),recharge_eu_s REAL NOT NULL CHECK(recharge_eu_s>0),energy_cost REAL NOT NULL CHECK(energy_cost>0 AND energy_cost<=energy_max),
 projectile_speed_mps REAL NOT NULL CHECK(projectile_speed_mps>0),
 drone_module_id TEXT REFERENCES drone_defs(module_id),drone_reserve INTEGER NOT NULL CHECK(drone_reserve>=0),
 CHECK((tactic_kind='carrier')=(drone_module_id IS NOT NULL)),CHECK((tactic_kind='carrier')=(drone_reserve>0))
) STRICT;
CREATE TABLE tactical_site_defs (
 site_id TEXT PRIMARY KEY,sector_id TEXT NOT NULL REFERENCES sector_defs(sector_id),display_name TEXT NOT NULL,
 anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 respawn_s REAL NOT NULL CHECK(respawn_s>0),warp_arrival_m REAL NOT NULL CHECK(warp_arrival_m>0),reveal_range_m REAL NOT NULL CHECK(reveal_range_m>0)
) STRICT;
CREATE TABLE npc_tactic_bindings (
 spawn_id TEXT PRIMARY KEY REFERENCES npc_spawn_defs(spawn_id),tactic_id TEXT NOT NULL REFERENCES npc_tactic_defs(tactic_id),
 site_id TEXT NOT NULL REFERENCES tactical_site_defs(site_id),member_index INTEGER NOT NULL CHECK(member_index>=0),UNIQUE(site_id,member_index)
) STRICT;
CREATE TABLE drone_management_defs (
 module_id TEXT PRIMARY KEY REFERENCES drone_defs(module_id),hull_hp REAL NOT NULL CHECK(hull_hp>0),
 material_id TEXT NOT NULL REFERENCES item_defs(item_id),material_per_unit INTEGER NOT NULL CHECK(material_per_unit>0),
 credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit>0)
) STRICT;
