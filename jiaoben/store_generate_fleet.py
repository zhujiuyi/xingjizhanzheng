"""Generate only additive 028 and the fixed fleet adapter; preserve 001-027."""
from pathlib import Path
import hashlib
import re
import sqlite3
from generate_frozen_schema import frozen_table_sql
from sync_contract_state_dtos import split_columns, class_name
from fleet_catalog import TABLES
from fleet_state_spec import STATES
import store_generate_scenarios as registry

ROOT = Path(__file__).resolve().parents[1]


def main():
    progress = ROOT / 'code/database/progress'
    historical = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in progress.iterdir()
                  if p.is_file() and ((p.name.startswith('catalog_adapter_') and p.name!='catalog_adapter_v0_23.sql') or re.match(r'0(?:0\d|1\d|2[0-7])_', p.name))}
    db = sqlite3.connect((ROOT / 'jiaoben/tmp/fleet-candidate.db').as_uri() + '?mode=ro', uri=True)
    parts = ['-- Owned hulls, finite crew careers and physical auxiliary sorties.']
    for table in TABLES:
        parts.append(frozen_table_sql(db, table))
    for table, (key, columns, foreign) in STATES.items():
        extra = ',' + foreign if foreign else ''
        parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE{extra}) STRICT;''')
        for action, context in [('INSERT', 'NEW'), ('UPDATE', 'OLD'), ('DELETE', 'OLD')]:
            guard = f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={context}.snapshot_id AND status='sealed')"
            if action == 'UPDATE':
                guard += " OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
        real_columns = [re.match(r'(\w+)\s+REAL\b', c).group(1) for c in split_columns(columns) if re.match(r'(\w+)\s+REAL\b', c)]
        if real_columns:
            invalid = ' OR '.join(f'abs({c})>=1e100' for c in real_columns)
            parts.append(f"CREATE TRIGGER {table}_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM {table} WHERE snapshot_id=NEW.snapshot_id AND ({invalid})) BEGIN SELECT RAISE(ABORT,'nonfinite fleet scalar'); END;")
    legacy = ' OR '.join(f'EXISTS(SELECT 1 FROM {t} WHERE snapshot_id=NEW.snapshot_id)' for t in STATES)
    parts.append(f"CREATE TRIGGER fleet_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_fleet_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND ({legacy}) BEGIN SELECT RAISE(ABORT,'fleet state under legacy rules'); END;")
    parts.extend([
        'CREATE UNIQUE INDEX crew_one_profession_per_hull ON crew_assignment_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id,profession_id);',
        'CREATE UNIQUE INDEX fleet_one_actor_per_hull ON fleet_deployment_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id) WHERE npc_instance_id IS NOT NULL;',
        (ROOT / 'code/database/fleet_state_validation.sql').read_text(encoding='utf-8'),
    ])
    # Reissue complete spatial/support guards with narrowly bound owned actors.
    # All historical statements remain immutable on disk.
    with sqlite3.connect(':memory:') as prior:
        for file in sorted(progress.glob('[0-9][0-9][0-9]_*.sql')):
            if int(file.name[:3]) <= 27:
                prior.executescript(file.read_text(encoding='utf-8'))
        matches = [(name, sql) for name, sql in prior.execute("SELECT name,sql FROM sqlite_schema WHERE type='trigger'")
                   if "NPC site differs from frozen spawn" in sql]
        assert len(matches) == 1
        name, spatial = matches[0]
        needle = ' AND p.site_id<>coalesce('
        assert spatial.count(needle) == 1
        owned = " AND NOT EXISTS(SELECT 1 FROM fleet_deployment_state f JOIN ship_state ship ON ship.snapshot_id=f.snapshot_id AND ship.ship_instance_id=f.ship_instance_id JOIN frozen_fleet_hull_defs hull ON hull.content_snapshot_id=ship.content_snapshot_id AND hull.ship_id=ship.ship_def_id WHERE f.snapshot_id=n.snapshot_id AND f.npc_instance_id=n.npc_instance_id AND f.npc_instance_id=f.ship_instance_id AND f.phase IN('deployed','retreating') AND ship.policy_id='normal_owned' AND ship.owner_player_id=(SELECT player_id FROM player_state WHERE snapshot_id=f.snapshot_id) AND hull.spawn_id=n.spawn_id AND f.sector_id=n.sector_id AND f.site_id=p.site_id)"
        parts.append('DROP TRIGGER ' + name + ';\n' + spatial.replace(needle, owned + needle) + ';')
        support = prior.execute("SELECT sql FROM sqlite_schema WHERE name='role_seal_validation'").fetchone()[0]
        needle = ' OR EXISTS(SELECT 1 FROM exploration_actor_state a WHERE a.snapshot_id=r.snapshot_id'
        assert support.count(needle) == 1
        owned = " OR EXISTS(SELECT 1 FROM fleet_deployment_state fleet JOIN ship_state owned ON owned.snapshot_id=fleet.snapshot_id AND owned.ship_instance_id=fleet.ship_instance_id JOIN frozen_fleet_hull_defs hull ON hull.content_snapshot_id=owned.content_snapshot_id AND hull.ship_id=owned.ship_def_id WHERE fleet.snapshot_id=r.snapshot_id AND fleet.npc_instance_id=r.target_npc_id AND fleet.phase IN('deployed','retreating') AND fleet.npc_instance_id=fleet.ship_instance_id AND owned.policy_id='normal_owned' AND hull.spawn_id=n.spawn_id AND owned.owner_player_id=(SELECT player_id FROM player_state WHERE snapshot_id=r.snapshot_id))"
        support = support.replace(needle, owned + needle)
        restoration = "d.restore_amount*i.quality_multiplier*(CASE r.layer_id WHEN 'shield' THEN c.remote_shield_multiplier ELSE c.remote_armor_multiplier END)"
        assert support.count(restoration) == 1
        bonus = "coalesce((SELECT quote.restore_multiplier FROM crew_support_quote_state quote WHERE quote.snapshot_id=r.snapshot_id AND quote.item_instance_id=r.item_instance_id),1)"
        support = support.replace(restoration, restoration + '*' + bonus)
        parts.append('DROP TRIGGER role_seal_validation;\n' + support + ';')
    parts.append('''CREATE TABLE database_meta_format25(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=25)) STRICT;
INSERT INTO database_meta_format25 SELECT singleton,application_id,25 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format25 RENAME TO database_meta;PRAGMA user_version=25;''')
    (progress / '028_owned_fleet.sql').write_text('\n\n'.join(parts) + '\n', encoding='utf-8', newline='\n')
    adapter = ['-- Reviewed schema22 owned fleet and auxiliary adapter.\nPRAGMA foreign_keys=ON;']
    for kind in ['table', 'view']:
        adapter.extend(r[0] + ';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type=? AND name NOT LIKE 'sqlite_%' ORDER BY name", (kind,)))
    (progress / 'catalog_adapter_v0_23.sql').write_text('\n\n'.join(adapter) + '\n', encoding='utf-8', newline='\n')
    db.close()
    registry.STATES = STATES
    registry.append_dtos()
    # Previously authored DTO classes may gain fields while this unpublished
    # migration is being completed; touch only the eight new class blocks.
    path = ROOT / 'code/contracts/contract_dtos.gd'
    text = path.read_text(encoding='utf-8')
    for table, (_, columns, _) in STATES.items():
        name = class_name(table)
        pattern = re.compile(r'(class ' + name + r' extends RefCounted:\n)(.*?)(?=\nclass |\Z)', re.S)
        match = pattern.search(text)
        assert match, name
        body = match.group(2)
        for column in split_columns(columns):
            info = re.match(r'(\w+)\s+(TEXT|INTEGER|REAL)\b(.*)', column, re.S)
            if not info:
                continue
            field, kind, rest = info.groups()
            if not re.search(r'\bvar ' + field + r':', body):
                typ, default = {'TEXT': ('String', '""'), 'INTEGER': ('int', '0'), 'REAL': ('float', '0.0')}[kind]
                if 'NOT NULL' not in rest:
                    body += f'\tvar has_{field}: bool = false\n'
                body += f'\tvar {field}: {typ} = {default}\n'
        text = text[:match.start(2)] + body + text[match.end(2):]
    path.write_text(text, encoding='utf-8', newline='\n')
    for name, digest in historical.items():
        assert hashlib.sha256((progress / name).read_bytes()).hexdigest() == digest, name
    print('Generated 028 / schema22 adapter / owned fleet DTO groups; historical files unchanged')


if __name__ == '__main__':
    main()
