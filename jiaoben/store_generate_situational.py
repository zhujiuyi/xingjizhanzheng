"""Append format21 observations; never regenerate old migrations or adapters."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from situational_catalog import TABLES
ROOT=Path(__file__).resolve().parents[1]
STATES={
 'resource_intel_state':('''node_id TEXT NOT NULL,sector_id TEXT NOT NULL,site_id TEXT NOT NULL,
 observed_tick INTEGER NOT NULL CHECK(observed_tick>=0),remaining_units INTEGER NOT NULL CHECK(remaining_units>=0),
 respawn_remaining_s REAL NOT NULL CHECK(respawn_remaining_s>=0)''','node_id',
 '''FOREIGN KEY(content_snapshot_id,node_id) REFERENCES frozen_resource_node_defs(content_snapshot_id,node_id),
 FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id)'''),
 'demand_intel_state':('''demand_id TEXT NOT NULL,observed_tick INTEGER NOT NULL CHECK(observed_tick>=0),
 generation INTEGER NOT NULL CHECK(generation>=1),phase TEXT NOT NULL CHECK(phase IN('active','cooldown')),
 remaining_units INTEGER NOT NULL CHECK(remaining_units>=0),phase_remaining_s REAL NOT NULL CHECK(phase_remaining_s>=0),
 unit_credit INTEGER NOT NULL CHECK(unit_credit>=0)''','demand_id',
 '''FOREIGN KEY(content_snapshot_id,demand_id) REFERENCES frozen_station_demand_defs(content_snapshot_id,demand_id)'''),
}

def main():
    db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
    parts=['-- Typed, finite local observations. No remote resource refresh.']+[frozen_table_sql(db,t) for t in TABLES]
    for table,(columns,key,foreign) in STATES.items():
        parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,{foreign}) STRICT;''')
        for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
            guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
            if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
    parts.append('''CREATE TRIGGER situational_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM frozen_situational_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (EXISTS(SELECT 1 FROM resource_intel_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM demand_intel_state WHERE snapshot_id=NEW.snapshot_id)) THEN RAISE(ABORT,'observations under legacy rules') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM resource_intel_state i JOIN frozen_resource_node_defs n USING(content_snapshot_id,node_id)
 JOIN frozen_site_defs site USING(content_snapshot_id,site_id) WHERE i.snapshot_id=NEW.snapshot_id AND
 (i.observed_tick>NEW.simulation_tick OR i.sector_id<>n.sector_id OR site.sector_id<>i.sector_id OR i.remaining_units>n.capacity_units OR i.respawn_remaining_s>n.respawn_s)) THEN RAISE(ABORT,'invalid resource observation') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM demand_intel_state i JOIN frozen_station_demand_defs d USING(content_snapshot_id,demand_id)
 WHERE i.snapshot_id=NEW.snapshot_id AND (i.observed_tick>NEW.simulation_tick OR i.remaining_units>d.required_units OR
 i.unit_credit<>d.unit_reward_credit OR i.phase_remaining_s>CASE WHEN i.phase='active' THEN d.duration_s ELSE d.cooldown_s END)) THEN RAISE(ABORT,'invalid demand observation') END;
END;
CREATE TABLE database_meta_format21(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=21)) STRICT;
INSERT INTO database_meta_format21 SELECT singleton,application_id,21 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format21 RENAME TO database_meta;PRAGMA user_version=21;''')
    (ROOT/'code/database/progress/024_situational.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
    adapter=['-- Reviewed schema19 situational adapter.\nPRAGMA foreign_keys=ON;']
    for kind in ['table','view']:adapter += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type=? AND name NOT LIKE 'sqlite_%' ORDER BY name",(kind,))]
    (ROOT/'code/database/progress/catalog_adapter_v0_20.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n')
    db.close()

if __name__=='__main__':main()
