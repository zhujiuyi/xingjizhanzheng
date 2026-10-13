"""Generate draft 029 and v0.24 adapter; all released SQL stays byte-identical."""
from pathlib import Path
import hashlib
import re
import sqlite3
from generate_frozen_schema import frozen_table_sql
from sync_contract_state_dtos import split_columns, class_name
from march_catalog import TABLES
from march_state_spec import STATES
import store_generate_scenarios as registry

ROOT = Path(__file__).resolve().parents[1]


def main():
    progress = ROOT / 'code/database/progress'
    historical = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in progress.glob('*.sql')
                  if p.name not in {'029_march.sql', 'catalog_adapter_v0_24.sql'}}
    with sqlite3.connect((ROOT / 'jiaoben/tmp/march-candidate.db').as_uri() + '?mode=ro', uri=True) as db:
        parts = ['-- Persistent original NPC members, real gate legs and conservative supply handoff.']
        for table in TABLES:
            parts.append(frozen_table_sql(db, table))
        for table, (key, columns, foreign) in STATES.items():
            parts.append(f'CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,' + foreign + ') STRICT;')
            for action, context in [('INSERT', 'NEW'), ('UPDATE', 'OLD'), ('DELETE', 'OLD')]:
                guard = f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={context}.snapshot_id AND status='sealed')"
                if action == 'UPDATE':
                    guard += " OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
                parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
            scalars = [re.match(r'(\w+)\s+REAL\b', c).group(1) for c in split_columns(columns) if re.match(r'(\w+)\s+REAL\b', c)]
            if scalars:
                invalid = ' OR '.join(f'abs({c})>=1e100' for c in scalars)
                parts.append(f"CREATE TRIGGER {table}_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM {table} WHERE snapshot_id=NEW.snapshot_id AND ({invalid})) BEGIN SELECT RAISE(ABORT,'nonfinite march scalar'); END;")
        legacy = ' OR '.join(f'EXISTS(SELECT 1 FROM {t} WHERE snapshot_id=NEW.snapshot_id)' for t in STATES)
        parts.append(f"CREATE TRIGGER march_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_march_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND ({legacy}) BEGIN SELECT RAISE(ABORT,'march state under legacy rules'); END;")
        parts.append((ROOT / 'code/database/march_state_validation.sql').read_text(encoding='utf-8'))
        with sqlite3.connect(':memory:') as prior:
            for file in sorted(progress.glob('[0-9][0-9][0-9]_*.sql')):
                if int(file.name[:3]) <= 28:
                    prior.executescript(file.read_text(encoding='utf-8'))
            spatial = [(name, sql) for name, sql in prior.execute("SELECT name,sql FROM sqlite_schema WHERE type='trigger'") if 'NPC site differs from frozen spawn' in sql]
            assert len(spatial) == 1
            name, statement = spatial[0]
            needle = ' AND p.site_id<>coalesce('
            assert statement.count(needle) == 1
            binding = " AND NOT EXISTS(SELECT 1 FROM march_member_state m JOIN march_state march ON march.snapshot_id=m.snapshot_id AND march.war_id=m.war_id AND march.attempt=m.attempt JOIN war_campaign_state war ON war.snapshot_id=m.snapshot_id AND war.war_id=m.war_id AND war.attempt=m.attempt JOIN war_fleet_state fleet ON fleet.snapshot_id=m.snapshot_id AND fleet.npc_instance_id=m.npc_instance_id AND fleet.war_id=m.war_id JOIN frozen_civilization_war_members member ON member.content_snapshot_id=m.content_snapshot_id AND member.war_id=m.war_id AND member.spawn_id=m.spawn_id WHERE m.snapshot_id=n.snapshot_id AND m.npc_instance_id=n.npc_instance_id AND m.spawn_id=n.spawn_id AND m.sector_id=n.sector_id AND m.site_id=p.site_id AND n.generation=m.attempt AND fleet.side='ally' AND member.side='ally')"
            parts.append('DROP TRIGGER ' + name + ';\n' + statement.replace(needle, binding + needle) + ';')
            meta = prior.execute("SELECT sql FROM sqlite_schema WHERE name='database_meta'").fetchone()[0]
            updated = meta.replace('CHECK(format_version=25)', 'CHECK(format_version=26)')
            assert updated != meta, meta
            updated = updated.replace('CREATE TABLE "database_meta"', 'CREATE TABLE database_meta_format26').replace('CREATE TABLE database_meta(', 'CREATE TABLE database_meta_format26(')
            assert 'database_meta_format26' in updated
            parts.append(updated + ';\nINSERT INTO database_meta_format26 SELECT singleton,application_id,26 FROM database_meta;\nDROP TABLE database_meta;ALTER TABLE database_meta_format26 RENAME TO database_meta;PRAGMA user_version=26;')
        (progress / '029_march.sql').write_text('\n\n'.join(parts) + '\n', encoding='utf-8', newline='\n')
        adapter = ['-- Reviewed schema23 march/growth adapter.\nPRAGMA foreign_keys=ON;']
        for kind in ['table', 'view']:
            adapter.extend(row[0] + ';' for row in db.execute("SELECT sql FROM sqlite_schema WHERE type=? AND name NOT LIKE 'sqlite_%' ORDER BY name", (kind,)))
        (progress / 'catalog_adapter_v0_24.sql').write_text('\n\n'.join(adapter) + '\n', encoding='utf-8', newline='\n')
    registry.STATES = STATES
    registry.append_dtos()
    path = ROOT / 'code/contracts/contract_dtos.gd'
    text = path.read_text(encoding='utf-8')
    for table, (_, columns, _) in STATES.items():
        pattern = re.compile(r'(class ' + class_name(table) + r' extends RefCounted:\n)(.*?)(?=\nclass |\Z)', re.S)
        match = pattern.search(text)
        assert match, table
        body = ''
        for column in split_columns(columns):
            info = re.match(r'(\w+)\s+(TEXT|INTEGER|REAL)\b(.*)', column, re.S)
            if not info:
                continue
            field, kind, rest = info.groups()
            typ, default = {'TEXT': ('String', '""'), 'INTEGER': ('int', '0'), 'REAL': ('float', '0.0')}[kind]
            if kind == 'INTEGER' and re.search(r'CHECK\(' + field + r' IN\(0,1\)\)', rest):
                typ, default = 'bool', 'false'
            if 'NOT NULL' not in rest:
                body += f'\tvar has_{field}: bool = false\n'
            body += f'\tvar {field}: {typ} = {default}\n'
        text = text[:match.start(2)] + body + text[match.end(2):]
    path.write_text(text, encoding='utf-8', newline='\n')
    for name, digest in historical.items():
        assert hashlib.sha256((progress / name).read_bytes()).hexdigest() == digest, name
    print('Generated draft 029 / schema23 adapter and typed march/growth groups; released SQL unchanged')


if __name__ == '__main__':
    main()
