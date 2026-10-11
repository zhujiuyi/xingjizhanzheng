"""Generate only additive 016 and v0.12. Historical SQL remains byte-for-byte intact."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from mobile_belts_catalog import TABLES
import build_catalog

ROOT = Path(__file__).resolve().parents[1]
PROGRESS = ROOT/'code/database/progress'
STATE = '''CREATE TABLE exploration_belt_state (
 snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
 event_id TEXT NOT NULL,route_id TEXT NOT NULL,
 stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 0 AND 3),
 warning_stage_index INTEGER NOT NULL CHECK(warning_stage_index BETWEEN 0 AND 3),
 start_elapsed_s REAL NOT NULL CHECK(start_elapsed_s>=0 AND start_elapsed_s<1e100),
 initial_units INTEGER NOT NULL CHECK(initial_units>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,event_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,event_id) REFERENCES exploration_instance_state(snapshot_id,world_id,content_snapshot_id,event_id),
 FOREIGN KEY(content_snapshot_id,route_id,event_id) REFERENCES frozen_exploration_belt_route_defs(content_snapshot_id,route_id,event_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;'''
SEAL = '''CREATE TRIGGER mobile_belt_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM exploration_belt_state WHERE snapshot_id=NEW.snapshot_id)<>
 (SELECT count(DISTINCT event_id) FROM frozen_exploration_belt_route_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'mobile belt coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_belt_state b JOIN exploration_instance_state e USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v ON v.content_snapshot_id=e.content_snapshot_id AND v.variant_id=e.variant_id
 WHERE b.snapshot_id=NEW.snapshot_id AND (b.initial_units>v.mineral_units OR (e.phase='mineral' AND b.start_elapsed_s>=v.duration_s)))
 THEN RAISE(ABORT,'mobile belt window or initial stock exceeds frozen limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_belt_state b JOIN exploration_instance_state e USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v ON v.content_snapshot_id=e.content_snapshot_id AND v.variant_id=e.variant_id
 WHERE b.snapshot_id=NEW.snapshot_id AND (b.warning_stage_index<b.stage_index OR (e.phase='mineral' AND b.stage_index<>
 coalesce((SELECT max(s.stage_index) FROM frozen_exploration_belt_stage_defs s WHERE s.content_snapshot_id=b.content_snapshot_id
 AND e.elapsed_s>=b.start_elapsed_s+(v.duration_s-b.start_elapsed_s)*s.threshold_bp/10000.0),0))))
 THEN RAISE(ABORT,'mobile belt stage differs from saved window') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_belt_state b JOIN exploration_instance_state e USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_resource_defs d USING(content_snapshot_id,event_id) JOIN resource_state r USING(snapshot_id,world_id,content_snapshot_id,node_id)
 LEFT JOIN frozen_exploration_belt_stage_defs s ON s.content_snapshot_id=b.content_snapshot_id AND s.stage_index=b.stage_index
 WHERE b.snapshot_id=NEW.snapshot_id AND e.phase='mineral' AND r.remaining_units>CAST(b.initial_units*coalesce(s.remaining_cap_bp,10000)/10000 AS INTEGER))
 THEN RAISE(ABORT,'dispersed mineral cannot regenerate') END;
END;
CREATE TABLE database_meta_format13 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=13)
) STRICT;
INSERT INTO database_meta_format13 SELECT singleton,application_id,13 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format13 RENAME TO database_meta;
PRAGMA user_version=13;
'''


def main():
    db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
    db.execute('PRAGMA foreign_keys=ON'); build_catalog.validate_database(db)
    assert db.execute('SELECT schema_version FROM catalog_meta').fetchone()[0]==11
    adapter=['-- Reviewed schema11 mobile-mineral adapter.\nPRAGMA foreign_keys=ON;']
    adapter += [db.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?",(t,)).fetchone()[0]+';' for t in sorted(build_catalog.CONTENT_TABLES)]
    adapter += [s+';' for s in build_catalog.content_views(db).values()]
    (PROGRESS/'catalog_adapter_v0_12.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n')
    parts=['-- Format12 -> 13: persistent AU route, finite staged dispersion and old-world grace.\n']
    parts += [frozen_table_sql(db,t) for t in TABLES]
    parts.append(STATE)
    for action,row in (('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')):
        guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={row}.snapshot_id AND status='sealed')"
        if action=='UPDATE': guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
        parts.append(f"CREATE TRIGGER exploration_belt_state_{action.lower()}_immutable BEFORE {action} ON exploration_belt_state WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
    # Replace only the former exact-spawn clause; keep all previous spatial guards.
    old=(PROGRESS/'011_space_locations.sql').read_text(encoding='utf-8')
    trigger=old.split('CREATE TRIGGER spatial_context_seal_validation',1)[1].split('\nEND;',1)[0]
    original="p.entity_kind='npc' AND p.site_id<>a.site_id)"
    replacement="""p.entity_kind='npc' AND p.site_id<>coalesce((SELECT mapped.site_id FROM exploration_belt_state b
 JOIN frozen_exploration_belt_anchor_defs m ON m.content_snapshot_id=b.content_snapshot_id AND m.route_id=b.route_id AND m.base_anchor_id=d.anchor_id
 JOIN frozen_anchor_site_defs mapped ON mapped.content_snapshot_id=m.content_snapshot_id AND mapped.anchor_id=m.anchor_id
 WHERE b.snapshot_id=n.snapshot_id),a.site_id))"""
    assert trigger.count(original)==1
    parts.append('DROP TRIGGER spatial_context_seal_validation;\nCREATE TRIGGER spatial_context_seal_validation'+trigger.replace(original,replacement)+'\nEND;')
    parts.append(SEAL)
    (PROGRESS/'016_mobile_belts.sql').write_text('\n\n'.join(parts),encoding='utf-8',newline='\n')
    db.close();print('MOBILE_BELTS_SCHEMA PASS three frozen definitions, one typed state and format13')


if __name__=='__main__': main()
