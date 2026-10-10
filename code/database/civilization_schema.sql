-- Civilization definitions are frozen with the world's authoritative catalog.
CREATE TABLE civilization_defs (
 faction_id TEXT PRIMARY KEY REFERENCES faction_defs(faction_id),
 capital_sector_id TEXT NOT NULL UNIQUE REFERENCES sector_defs(sector_id),
 capital_station_id TEXT NOT NULL UNIQUE REFERENCES station_defs(station_id),
 doctrine TEXT NOT NULL,
 color_hex TEXT NOT NULL CHECK(length(color_hex)=6)
) STRICT;
CREATE TABLE civilization_rank_defs (
 faction_id TEXT NOT NULL REFERENCES civilization_defs(faction_id),
 rank_level INTEGER NOT NULL CHECK(rank_level BETWEEN 0 AND 7),
 display_name TEXT NOT NULL,
 required_reputation INTEGER NOT NULL CHECK(required_reputation>=0),
 PRIMARY KEY(faction_id,rank_level), UNIQUE(faction_id,required_reputation)
) STRICT;
CREATE TABLE sector_sovereignty_defs (
 sector_id TEXT PRIMARY KEY REFERENCES sector_defs(sector_id),
 initial_faction_id TEXT REFERENCES civilization_defs(faction_id),
 conquerable INTEGER NOT NULL CHECK(conquerable IN (0,1)),
 chart_x REAL NOT NULL, chart_y REAL NOT NULL,
 CHECK(initial_faction_id IS NULL OR conquerable=0)
) STRICT;
CREATE TABLE civilization_join_missions (
 faction_id TEXT NOT NULL REFERENCES civilization_defs(faction_id),
 step_index INTEGER NOT NULL CHECK(step_index BETWEEN 1 AND 3),
 mission_id TEXT NOT NULL UNIQUE REFERENCES mission_defs(mission_id),
 PRIMARY KEY(faction_id,step_index)
) STRICT;
CREATE TABLE civilization_hull_defs (
 ship_id TEXT PRIMARY KEY REFERENCES ship_defs(ship_id),
 faction_id TEXT NOT NULL REFERENCES civilization_defs(faction_id),
 required_rank INTEGER NOT NULL,
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 base_ship_id TEXT NOT NULL REFERENCES ship_defs(ship_id),
 description TEXT NOT NULL,
 FOREIGN KEY(faction_id,required_rank) REFERENCES civilization_rank_defs(faction_id,rank_level)
) STRICT;
CREATE TABLE civilization_technology_defs (
 research_id TEXT PRIMARY KEY REFERENCES research_defs(research_id),
 faction_id TEXT NOT NULL REFERENCES civilization_defs(faction_id),
 required_rank INTEGER NOT NULL,
 FOREIGN KEY(faction_id,required_rank) REFERENCES civilization_rank_defs(faction_id,rank_level)
) STRICT;
CREATE TABLE civilization_donation_defs (
 donation_id TEXT PRIMARY KEY,
 faction_id TEXT NOT NULL REFERENCES civilization_defs(faction_id),
 item_id TEXT NOT NULL REFERENCES item_defs(item_id),
 units_per_batch INTEGER NOT NULL CHECK(units_per_batch>0),
 reputation_per_batch INTEGER NOT NULL CHECK(reputation_per_batch>0)
) STRICT;
CREATE TABLE civilization_war_defs (
 war_id TEXT PRIMARY KEY,
 faction_id TEXT NOT NULL REFERENCES civilization_defs(faction_id),
 target_sector_id TEXT NOT NULL REFERENCES sector_defs(sector_id),
 capture_anchor_id TEXT NOT NULL REFERENCES anchor_defs(anchor_id),
 required_rank INTEGER NOT NULL,
 capture_duration_s REAL NOT NULL CHECK(capture_duration_s>0),
 capture_radius_m REAL NOT NULL CHECK(capture_radius_m>0),
 reward_credit INTEGER NOT NULL CHECK(reward_credit>=0),
 reward_reputation INTEGER NOT NULL CHECK(reward_reputation>0),
 FOREIGN KEY(faction_id,required_rank) REFERENCES civilization_rank_defs(faction_id,rank_level),
 UNIQUE(faction_id,target_sector_id)
) STRICT;
CREATE TABLE civilization_war_members (
 war_id TEXT NOT NULL REFERENCES civilization_war_defs(war_id),
 spawn_id TEXT NOT NULL UNIQUE REFERENCES npc_spawn_defs(spawn_id),
 side TEXT NOT NULL CHECK(side IN ('ally','defender')),
 formation_index INTEGER NOT NULL CHECK(formation_index>=0),
 PRIMARY KEY(war_id,side,formation_index)
) STRICT;
