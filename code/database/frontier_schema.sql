-- Staged frontier operations and reversible governance; prior definitions stay fixed.
CREATE TABLE frontier_balance_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 material_id TEXT NOT NULL REFERENCES item_defs(item_id),supply_units INTEGER NOT NULL CHECK(supply_units>0),rebuild_units INTEGER NOT NULL CHECK(rebuild_units>0),
 survey_s REAL NOT NULL CHECK(survey_s>0),survey_energy_eu REAL NOT NULL CHECK(survey_energy_eu>0),survey_heat_hu REAL NOT NULL CHECK(survey_heat_hu>=0),
 survey_radius_m REAL NOT NULL CHECK(survey_radius_m>0),escort_radius_m REAL NOT NULL CHECK(escort_radius_m>0),arrival_radius_m REAL NOT NULL CHECK(arrival_radius_m>0),
 hold_s REAL NOT NULL CHECK(hold_s>0),rebuild_s REAL NOT NULL CHECK(rebuild_s>0),repair_radius_m REAL NOT NULL CHECK(repair_radius_m>0),
 warning_s REAL NOT NULL CHECK(warning_s>0),defense_s REAL NOT NULL CHECK(defense_s>0),crisis_min_s REAL NOT NULL CHECK(crisis_min_s>warning_s),crisis_max_s REAL NOT NULL CHECK(crisis_max_s>=crisis_min_s),
 reserve_max_units INTEGER NOT NULL CHECK(reserve_max_units>0),crisis_supply_base_units INTEGER NOT NULL CHECK(crisis_supply_base_units>0),crisis_supply_per_extra_territory INTEGER NOT NULL CHECK(crisis_supply_per_extra_territory>=0),
 dispatch_s REAL NOT NULL CHECK(dispatch_s>0),dispatch_fee_credit INTEGER NOT NULL CHECK(dispatch_fee_credit>=0),max_supply_orders INTEGER NOT NULL CHECK(max_supply_orders>0),
 repair_fee_ratio REAL NOT NULL CHECK(repair_fee_ratio>0 AND repair_fee_ratio<=1),industry_fee_ratio REAL NOT NULL CHECK(industry_fee_ratio>0 AND industry_fee_ratio<=1),
 recapture_credit INTEGER NOT NULL CHECK(recapture_credit>=0),recapture_reputation INTEGER NOT NULL CHECK(recapture_reputation>=0),defense_credit INTEGER NOT NULL CHECK(defense_credit>=0),defense_reputation INTEGER NOT NULL CHECK(defense_reputation>=0),
 hostile_detection_ratio REAL NOT NULL CHECK(hostile_detection_ratio>0 AND hostile_detection_ratio<=1),restock_rate REAL NOT NULL CHECK(restock_rate>=1)
) STRICT;
CREATE TABLE frontier_campaign_defs (
 war_id TEXT PRIMARY KEY REFERENCES civilization_war_defs(war_id),
 scout_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),convoy_start_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),convoy_exit_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 battle_kind TEXT NOT NULL CHECK(battle_kind IN ('hold','demolition')),convoy_spawn_id TEXT NOT NULL UNIQUE REFERENCES npc_spawn_defs(spawn_id),
 structure_count INTEGER NOT NULL CHECK(structure_count IN (0,2)),CHECK((battle_kind='hold' AND structure_count=0) OR (battle_kind='demolition' AND structure_count=2))
) STRICT;
CREATE TABLE frontier_actor_defs (
 spawn_id TEXT PRIMARY KEY REFERENCES npc_spawn_defs(spawn_id),war_id TEXT REFERENCES frontier_campaign_defs(war_id),sector_id TEXT NOT NULL REFERENCES sector_defs(sector_id),
 actor_role TEXT NOT NULL CHECK(actor_role IN ('convoy','ambusher','structure','raider')),slot_index INTEGER NOT NULL CHECK(slot_index>=0),
 hull_id TEXT REFERENCES ship_defs(ship_id),
 CHECK((actor_role='raider' AND war_id IS NULL) OR (actor_role<>'raider' AND war_id IS NOT NULL)),
 CHECK((actor_role='convoy' AND hull_id IS NOT NULL) OR (actor_role<>'convoy' AND hull_id IS NULL))
) STRICT;
CREATE TABLE frontier_governance_defs (
 sector_id TEXT PRIMARY KEY REFERENCES sector_sovereignty_defs(sector_id),station_id TEXT NOT NULL UNIQUE REFERENCES station_defs(station_id),
 defense_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),beacon_spawn_id TEXT NOT NULL UNIQUE REFERENCES npc_spawn_defs(spawn_id)
) STRICT;
CREATE TABLE frontier_beacon_defs (
 spawn_id TEXT PRIMARY KEY REFERENCES npc_spawn_defs(spawn_id),sector_id TEXT NOT NULL UNIQUE REFERENCES frontier_governance_defs(sector_id),hull_id TEXT NOT NULL REFERENCES ship_defs(ship_id)
) STRICT;
