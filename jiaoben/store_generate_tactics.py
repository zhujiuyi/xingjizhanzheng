"""Append 017 and v0.13 only; immutable historical migrations/adapters are never regenerated."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from tactics_catalog import TABLES
import build_catalog
ROOT=Path(__file__).resolve().parents[1];P=ROOT/'code/database/progress'
STATES={
'tactical_site_state':'''site_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=0),respawn_remaining_s REAL NOT NULL CHECK(respawn_remaining_s>=0 AND respawn_remaining_s<1e100),cleared_cycles INTEGER NOT NULL CHECK(cleared_cycles>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,site_id),FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_tactical_site_defs(content_snapshot_id,site_id)''',
'npc_tactic_state':'''npc_instance_id TEXT NOT NULL,tactic_id TEXT NOT NULL,phase TEXT NOT NULL CHECK(phase IN ('ready','charging','active','cooldown')),
 remaining_s REAL NOT NULL CHECK(remaining_s>=0 AND remaining_s<1e100),cooldown_remaining_s REAL NOT NULL CHECK(cooldown_remaining_s>=0 AND cooldown_remaining_s<1e100),energy REAL NOT NULL CHECK(energy>=0 AND energy<1e100),
 target_entity_id TEXT,aim_x REAL NOT NULL CHECK(abs(aim_x)<1e100),aim_y REAL NOT NULL CHECK(abs(aim_y)<1e100),aim_z REAL NOT NULL CHECK(abs(aim_z)<1e100),charge_start_hp REAL NOT NULL CHECK(charge_start_hp>=0 AND charge_start_hp<1e100),
 drone_stock INTEGER NOT NULL CHECK(drone_stock>=0),deployed_drones INTEGER NOT NULL CHECK(deployed_drones>=0),lost_drones INTEGER NOT NULL CHECK(lost_drones>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(content_snapshot_id,tactic_id) REFERENCES frozen_npc_tactic_defs(content_snapshot_id,tactic_id)''',
'ship_tactical_effect_state':'''ship_instance_id TEXT NOT NULL,source_npc_id TEXT,
 jam_remaining_s REAL NOT NULL CHECK(jam_remaining_s>=0 AND jam_remaining_s<1e100),immunity_remaining_s REAL NOT NULL CHECK(immunity_remaining_s>=0 AND immunity_remaining_s<1e100),repeat_window_s REAL NOT NULL CHECK(repeat_window_s>=0 AND repeat_window_s<1e100),repeat_count INTEGER NOT NULL CHECK(repeat_count>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,source_npc_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id)''',
'drone_bay_state':'''item_instance_id TEXT NOT NULL,stock_units INTEGER NOT NULL CHECK(stock_units>=0),deployed_units INTEGER NOT NULL CHECK(deployed_units>=0),lost_units INTEGER NOT NULL CHECK(lost_units>=0),replenished_units INTEGER NOT NULL CHECK(replenished_units>=0),
 paid_credit_total INTEGER NOT NULL CHECK(paid_credit_total>=0),material_units_total INTEGER NOT NULL CHECK(material_units_total>=0),revision INTEGER NOT NULL CHECK(revision>=0),command_kind TEXT NOT NULL CHECK(command_kind IN ('attack','follow','recall')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id) REFERENCES item_instance_state(snapshot_id,world_id,content_snapshot_id,item_instance_id)''',
}
SEAL='''CREATE TRIGGER tactics_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM tactical_site_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_tactical_site_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'tactical site coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM tactical_site_state s JOIN frozen_tactical_site_defs d USING(content_snapshot_id,site_id) WHERE s.snapshot_id=NEW.snapshot_id AND s.respawn_remaining_s>d.respawn_s)
 THEN RAISE(ABORT,'tactical respawn exceeds frozen limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_tactic_state t JOIN npc_state n USING(snapshot_id,world_id,content_snapshot_id,npc_instance_id)
 JOIN frozen_npc_tactic_defs d USING(content_snapshot_id,tactic_id)
 WHERE t.snapshot_id=NEW.snapshot_id AND (NOT EXISTS(SELECT 1 FROM frozen_npc_tactic_bindings b WHERE b.content_snapshot_id=t.content_snapshot_id AND b.spawn_id=n.spawn_id AND b.tactic_id=t.tactic_id) OR
 t.energy>d.energy_max OR t.remaining_s>max(d.charge_s,d.duration_s) OR t.cooldown_remaining_s>d.cooldown_s OR t.drone_stock+t.lost_drones<>d.drone_reserve OR t.deployed_drones<>0 OR
 (t.target_entity_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ship_state s WHERE s.snapshot_id=t.snapshot_id AND s.ship_instance_id=t.target_entity_id) AND NOT EXISTS(SELECT 1 FROM npc_state s WHERE s.snapshot_id=t.snapshot_id AND s.npc_instance_id=t.target_entity_id))))
 THEN RAISE(ABORT,'invalid tactical actor context or limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_state n JOIN frozen_npc_tactic_bindings b USING(content_snapshot_id,spawn_id) WHERE n.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM npc_tactic_state t WHERE t.snapshot_id=n.snapshot_id AND t.npc_instance_id=n.npc_instance_id))
 THEN RAISE(ABORT,'tactical actor state missing') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_tactical_effect_state e JOIN frozen_tactical_balance_defs b USING(content_snapshot_id) WHERE e.snapshot_id=NEW.snapshot_id AND
 (e.jam_remaining_s>b.jam_max_duration_s OR e.immunity_remaining_s>b.jam_immunity_s OR e.repeat_window_s>b.jam_repeat_window_s OR e.repeat_count>b.jam_max_repeat OR (e.jam_remaining_s>0 AND e.source_npc_id IS NULL)))
 THEN RAISE(ABORT,'jam exceeds minimum-control policy') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM drone_bay_state b JOIN item_instance_state i USING(snapshot_id,world_id,content_snapshot_id,item_instance_id)
 JOIN frozen_drone_defs d ON d.content_snapshot_id=b.content_snapshot_id AND d.module_id=i.item_def_id
 JOIN frozen_drone_management_defs m ON m.content_snapshot_id=b.content_snapshot_id AND m.module_id=i.item_def_id
 WHERE b.snapshot_id=NEW.snapshot_id AND (b.deployed_units<>0 OR b.stock_units>d.drone_count OR b.stock_units<>d.drone_count-b.lost_units+b.replenished_units OR b.paid_credit_total<>b.replenished_units*m.credit_per_unit OR b.material_units_total<>b.replenished_units*m.material_per_unit OR (b.replenished_units>0 AND i.policy_id<>'normal_owned')))
 THEN RAISE(ABORT,'drone stock or replacement ledger mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM drone_bay_state b JOIN item_instance_state i USING(snapshot_id,world_id,content_snapshot_id,item_instance_id) WHERE b.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM frozen_drone_management_defs d WHERE d.content_snapshot_id=b.content_snapshot_id AND d.module_id=i.item_def_id)) OR
 EXISTS(SELECT 1 FROM item_instance_state i JOIN frozen_drone_management_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.module_id=i.item_def_id WHERE i.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM drone_bay_state b WHERE b.snapshot_id=i.snapshot_id AND b.item_instance_id=i.item_instance_id))
 THEN RAISE(ABORT,'drone bay identity or coverage incomplete') END;
END;
CREATE TABLE database_meta_format14(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=14)) STRICT;
INSERT INTO database_meta_format14 SELECT singleton,application_id,14 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format14 RENAME TO database_meta;
PRAGMA user_version=14;
'''
def main():
 db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);db.execute('PRAGMA foreign_keys=ON');build_catalog.validate_database(db)
 assert db.execute('SELECT schema_version FROM catalog_meta').fetchone()[0]==12
 adapter=['-- Reviewed schema12 tactics adapter.\nPRAGMA foreign_keys=ON;']+[db.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?",(t,)).fetchone()[0]+';' for t in sorted(build_catalog.CONTENT_TABLES)]+[s+';' for s in build_catalog.content_views(db).values()]
 (P/'catalog_adapter_v0_13.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n')
 pieces=['-- Format13 -> 14: doctrines, bounded propulsion interference and finite drone restoration.']+[frozen_table_sql(db,t) for t in TABLES]
 for table,columns in STATES.items():
  pieces.append(f'CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,\n{columns},\nFOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;')
  for action,row in (('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')):
   guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={row}.snapshot_id AND status='sealed')"
   if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
   pieces.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
 pieces.append(SEAL);(P/'017_tactics.sql').write_text('\n\n'.join(pieces),encoding='utf-8',newline='\n');db.close();print('TACTICS_SCHEMA PASS five frozen definitions, four state groups and format14')
if __name__=='__main__':main()
