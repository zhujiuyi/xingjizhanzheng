-- One paid companion contract; definitions freeze with each world.
CREATE TABLE hire_balance_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 max_companions INTEGER NOT NULL CHECK(max_companions=1),
 formation_m REAL NOT NULL CHECK(formation_m>0),
 communication_m REAL NOT NULL CHECK(communication_m>formation_m),
 warp_ready_m REAL NOT NULL CHECK(warp_ready_m>=formation_m AND warp_ready_m<communication_m),
 retreat_distance_m REAL NOT NULL CHECK(retreat_distance_m>warp_ready_m),
 retreat_charge_s REAL NOT NULL CHECK(retreat_charge_s>0),
 return_s REAL NOT NULL CHECK(return_s>0),
 warning_s REAL NOT NULL CHECK(warning_s>0),
 support_range_m REAL NOT NULL CHECK(support_range_m>formation_m),
 support_cycle_s REAL NOT NULL CHECK(support_cycle_s>0),
 support_shield REAL NOT NULL CHECK(support_shield>0),
 support_armor REAL NOT NULL CHECK(support_armor>0)
) STRICT;
CREATE TABLE hire_profile_defs (
 profile_id TEXT PRIMARY KEY,
 display_name TEXT NOT NULL,
 role_id TEXT NOT NULL CHECK(role_id IN('escort','support')),
 hull_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
 spawn_id TEXT NOT NULL UNIQUE REFERENCES npc_spawn_defs(spawn_id),
 hire_fee_credit INTEGER NOT NULL CHECK(hire_fee_credit>0),
 deposit_credit INTEGER NOT NULL CHECK(deposit_credit>0),
 lease_s REAL NOT NULL CHECK(lease_s>0),
 support_cycles INTEGER NOT NULL CHECK(support_cycles>=0),
 CHECK((role_id='escort' AND support_cycles=0) OR (role_id='support' AND support_cycles>0))
) STRICT;
