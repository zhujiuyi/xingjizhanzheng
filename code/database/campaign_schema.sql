-- Long-form offline play. Values live only in this catalog, never in UI code.
CREATE TABLE campaign_balance_defs(
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 director_period_s REAL NOT NULL CHECK(director_period_s>0),
 focus_bonus_bp INTEGER NOT NULL CHECK(focus_bonus_bp BETWEEN 10000 AND 12000),
 partial_bonus_bp INTEGER NOT NULL CHECK(partial_bonus_bp BETWEEN 1 AND 10000),
 report_limit INTEGER NOT NULL CHECK(report_limit BETWEEN 10 AND 100)
) STRICT;
CREATE TABLE construction_project_defs(
 project_id TEXT PRIMARY KEY,display_name TEXT NOT NULL,
 sector_id TEXT NOT NULL REFERENCES sector_defs(sector_id),
 station_id TEXT NOT NULL UNIQUE REFERENCES station_defs(station_id),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 required_evidence_units INTEGER NOT NULL CHECK(required_evidence_units>0),
 description TEXT NOT NULL
) STRICT;
CREATE TABLE construction_stage_defs(
 project_id TEXT NOT NULL REFERENCES construction_project_defs(project_id),
 stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 1 AND 3),display_name TEXT NOT NULL,
 work_s REAL NOT NULL CHECK(work_s>0),fee_credit INTEGER NOT NULL CHECK(fee_credit>0),
 effect_kind TEXT NOT NULL CHECK(effect_kind IN('manufacture_fee','repair_fee','stock_refresh')),
 multiplier_bp INTEGER NOT NULL CHECK(multiplier_bp BETWEEN 8000 AND 12000),
 PRIMARY KEY(project_id,stage_index)
) STRICT;
CREATE TABLE construction_input_defs(
 project_id TEXT NOT NULL,stage_index INTEGER NOT NULL,item_id TEXT NOT NULL REFERENCES item_defs(item_id),
 delivery_station_id TEXT NOT NULL REFERENCES station_defs(station_id),required_units INTEGER NOT NULL CHECK(required_units>0),
 PRIMARY KEY(project_id,stage_index,item_id,delivery_station_id),
 FOREIGN KEY(project_id,stage_index) REFERENCES construction_stage_defs(project_id,stage_index)
) STRICT;
CREATE TABLE expedition_route_defs(
 route_id TEXT PRIMARY KEY,display_name TEXT NOT NULL,
 origin_station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 start_fee_credit INTEGER NOT NULL CHECK(start_fee_credit>0),cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
 focus_index INTEGER NOT NULL UNIQUE CHECK(focus_index BETWEEN 0 AND 2),description TEXT NOT NULL
) STRICT;
CREATE TABLE expedition_option_defs(
 route_id TEXT NOT NULL REFERENCES expedition_route_defs(route_id),stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 1 AND 3),
 option_id TEXT NOT NULL,event_id TEXT NOT NULL REFERENCES exploration_event_defs(event_id),
 bonus_credit INTEGER NOT NULL CHECK(bonus_credit>0),bonus_insight INTEGER NOT NULL CHECK(bonus_insight>0),
 PRIMARY KEY(route_id,stage_index,option_id),UNIQUE(route_id,event_id)
) STRICT;
CREATE TABLE campaign_event_defs(
 event_id TEXT PRIMARY KEY REFERENCES exploration_event_defs(event_id),
 project_id TEXT NOT NULL REFERENCES construction_project_defs(project_id),
 full_units INTEGER NOT NULL CHECK(full_units>0),partial_units INTEGER NOT NULL CHECK(partial_units>0 AND partial_units<=full_units)
) STRICT;
CREATE TABLE campaign_tactical_links(
 site_id TEXT PRIMARY KEY REFERENCES tactical_site_defs(site_id),
 event_id TEXT NOT NULL UNIQUE REFERENCES exploration_event_defs(event_id)
) STRICT;
