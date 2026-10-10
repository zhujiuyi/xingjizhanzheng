"""Generate append-only format9 DDL and the reviewed civilization schema adapter."""
from pathlib import Path
import sqlite3
from civilization_catalog import TABLES
from generate_frozen_schema import frozen_table_sql
import build_catalog

ROOT = Path(__file__).resolve().parents[1]
PROGRESS = ROOT / 'code/database/progress'
STATE_COLUMNS = {
    'civilization_state': '''player_id TEXT NOT NULL,
 faction_id TEXT,
 joined_tick INTEGER NOT NULL CHECK(joined_tick>=0),
 switch_cooldown_remaining_s REAL NOT NULL CHECK(switch_cooldown_remaining_s>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id)''',
    'territory_state': '''sector_id TEXT NOT NULL,
 faction_id TEXT,
 captured_tick INTEGER NOT NULL CHECK(captured_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_sovereignty_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id)''',
    'war_campaign_state': '''war_id TEXT NOT NULL, player_id TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('assembling','fighting','occupying','won','failed','cancelled')),
 fleet_order TEXT NOT NULL CHECK(fleet_order IN ('advance','focus','regroup')),
 focus_target_id TEXT NOT NULL,
 capture_remaining_s REAL NOT NULL CHECK(capture_remaining_s>=0),
 attempt INTEGER NOT NULL CHECK(attempt>0), started_tick INTEGER NOT NULL CHECK(started_tick>=0),
 finished_tick INTEGER NOT NULL CHECK(finished_tick>=0), rewards_claimed INTEGER NOT NULL CHECK(rewards_claimed IN (0,1)),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,war_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_civilization_war_defs(content_snapshot_id,war_id),
 CHECK((status='won')=(rewards_claimed=1))''',
    'war_fleet_state': '''npc_instance_id TEXT NOT NULL, war_id TEXT NOT NULL,
 side TEXT NOT NULL CHECK(side IN ('ally','defender')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,war_id) REFERENCES war_campaign_state(snapshot_id,world_id,content_snapshot_id,war_id)''',
}
SEAL = '''
CREATE TRIGGER civilization_context_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_civilization_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND (
  (SELECT count(*) FROM civilization_state WHERE snapshot_id=NEW.snapshot_id)<>1 OR
  (SELECT count(*) FROM territory_state WHERE snapshot_id=NEW.snapshot_id)<>
   (SELECT count(*) FROM frozen_sector_sovereignty_defs WHERE content_snapshot_id=NEW.content_snapshot_id))
 THEN RAISE(ABORT,'civilization authority coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM territory_state t JOIN frozen_sector_sovereignty_defs p USING(content_snapshot_id,sector_id)
  WHERE t.snapshot_id=NEW.snapshot_id AND p.conquerable=0 AND t.faction_id IS NOT p.initial_faction_id)
 THEN RAISE(ABORT,'protected territory ownership changed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM territory_state t JOIN frozen_sector_sovereignty_defs p USING(content_snapshot_id,sector_id)
  WHERE t.snapshot_id=NEW.snapshot_id AND p.initial_faction_id IS NULL AND t.faction_id IS NOT NULL
  AND NOT EXISTS(SELECT 1 FROM war_campaign_state w JOIN frozen_civilization_war_defs d USING(content_snapshot_id,war_id)
   WHERE w.snapshot_id=t.snapshot_id AND w.status='won' AND d.target_sector_id=t.sector_id AND d.faction_id=t.faction_id))
 THEN RAISE(ABORT,'territory capture lacks a completed war') END;
 SELECT CASE WHEN (SELECT count(*) FROM war_campaign_state WHERE snapshot_id=NEW.snapshot_id AND status IN ('assembling','fighting','occupying'))>1
 THEN RAISE(ABORT,'multiple active wars') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_campaign_state w
  JOIN frozen_civilization_war_defs d USING(content_snapshot_id,war_id)
  JOIN civilization_state c ON c.snapshot_id=w.snapshot_id AND c.player_id=w.player_id
  JOIN territory_state t ON t.snapshot_id=w.snapshot_id AND t.sector_id=d.target_sector_id
  WHERE w.snapshot_id=NEW.snapshot_id AND (w.capture_remaining_s>d.capture_duration_s OR
   (w.status IN ('assembling','fighting','occupying') AND (c.faction_id IS NOT d.faction_id OR t.faction_id IS NOT NULL)) OR
   (w.status='won' AND t.faction_id IS NOT d.faction_id)))
 THEN RAISE(ABORT,'invalid war allegiance target or occupation') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_campaign_state w JOIN frozen_civilization_war_defs d USING(content_snapshot_id,war_id)
  JOIN frozen_civilization_rank_defs r ON r.content_snapshot_id=d.content_snapshot_id AND r.faction_id=d.faction_id AND r.rank_level=d.required_rank
  LEFT JOIN reputation_state p ON p.snapshot_id=w.snapshot_id AND p.player_id=w.player_id AND p.faction_id=d.faction_id
  WHERE w.snapshot_id=NEW.snapshot_id AND w.status IN ('assembling','fighting','occupying') AND coalesce(p.reputation,0)<r.required_reputation)
 THEN RAISE(ABORT,'war reputation rank insufficient') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_fleet_state f
  JOIN npc_state n ON n.snapshot_id=f.snapshot_id AND n.npc_instance_id=f.npc_instance_id
  WHERE f.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM frozen_civilization_war_members m
   WHERE m.content_snapshot_id=f.content_snapshot_id AND m.war_id=f.war_id AND m.spawn_id=n.spawn_id AND m.side=f.side))
 THEN RAISE(ABORT,'invalid war fleet identity') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_campaign_state w WHERE w.snapshot_id=NEW.snapshot_id
  AND w.status IN ('assembling','fighting','occupying') AND
   (SELECT count(*) FROM war_fleet_state f WHERE f.snapshot_id=w.snapshot_id AND f.war_id=w.war_id)<>
   (SELECT count(*) FROM frozen_civilization_war_members m WHERE m.content_snapshot_id=w.content_snapshot_id AND m.war_id=w.war_id))
 THEN RAISE(ABORT,'incomplete active war fleet') END;
END;
CREATE TABLE database_meta_format9 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=9)
) STRICT;
INSERT INTO database_meta_format9 SELECT singleton,application_id,9 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format9 RENAME TO database_meta;
PRAGMA user_version=9;
'''


def main():
    path = ROOT / 'jiaoben/tmp/catalog-civilizations-candidate.db'
    source = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
    source.execute('PRAGMA foreign_keys=ON')
    build_catalog.validate_database(source)
    assert source.execute('SELECT schema_version,content_version FROM catalog_meta').fetchone() == (7, 'v0.8-civilizations')
    adapter = ['-- Reviewed civilization schema7 adapter; never execute saved DDL.\nPRAGMA foreign_keys=ON;']
    adapter += [source.execute('SELECT sql FROM sqlite_schema WHERE type=? AND name=?', ('table', table)).fetchone()[0] + ';'
                for table in sorted(build_catalog.CONTENT_TABLES)]
    adapter += [sql + ';' for sql in build_catalog.content_views(source).values()]
    (PROGRESS / 'catalog_adapter_v0_8.sql').write_text('\n\n'.join(adapter) + '\n', encoding='utf-8', newline='\n')
    parts = ['-- Format8 -> 9: civilization authority, territory and real NPC war fleets.\n']
    parts += [frozen_table_sql(source, table) for table in TABLES]
    for table, columns in STATE_COLUMNS.items():
        parts.append(f'''CREATE TABLE {table} (
 snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
 {columns},
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;
''')
        for action, row in [('INSERT', 'NEW'), ('UPDATE', 'OLD'), ('DELETE', 'OLD')]:
            guard = f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={row}.snapshot_id AND status='sealed')"
            if action == 'UPDATE':
                guard += " OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table}\nWHEN {guard}\nBEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;\n")
    parts.append(SEAL)
    (PROGRESS / '012_civilizations.sql').write_text('\n'.join(parts), encoding='utf-8', newline='\n')
    source.close()
    print('CIVILIZATION_SCHEMA PASS schema7 adapter, format9, nine frozen definition tables, four typed state tables')


if __name__ == '__main__':
    main()
