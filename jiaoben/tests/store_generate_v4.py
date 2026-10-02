"""Developer-only reviewed format-2 extension generator; never consumes saved SQL.

Preserves the original four format-1 migrations and the v0_3 verification adapter.
"""
from pathlib import Path
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog
from generate_frozen_schema import frozen_table_sql

directory = ROOT / "code/database/progress"
source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
baseline = sqlite3.connect(":memory:")
baseline.executescript((directory / "catalog_adapter_v0_3.sql").read_text())
try:
    source.execute("PRAGMA foreign_keys=ON")
    build_catalog.validate_database(source)
    old_tables = {row[0] for row in baseline.execute("SELECT name FROM sqlite_schema WHERE type='table'")}
    # The format2 adapter is immutable after its independent acceptance. New
    # signal rewards belong to the separate format3/r2 migration and adapter.
    registered = set(build_catalog.CONTENT_TABLES) - {"signal_unlock_rewards"}
    new_tables = registered - old_tables
    adapter = ["-- Reviewed format-2 adapter, including v0.4 definitions and exact views.\nPRAGMA foreign_keys=ON;"]
    adapter.extend(source.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?", (name,)).fetchone()[0] + ";" for name in sorted(registered))
    adapter.extend(sql + ";" for sql in build_catalog.content_views(source).values())
    (directory / "catalog_adapter_v0_4.sql").write_text("\n\n".join(adapter) + "\n")
    pieces = ["-- Format 1 -> 2; all DDL/copy/checks execute in one deferred-FK transaction.\n-- Original four migration checksums remain unchanged.\n"]
    for table in sorted(new_tables):
        pieces.append(frozen_table_sql(source, table))
    # Same columns/keys; the current reviewed CHECK additionally permits story.
    expanded = frozen_table_sql(source, "mission_defs")
    table_sql, guards = expanded.split("CREATE TRIGGER", 1)
    pieces += ["DROP TRIGGER snapshot_seal_validation;\n",
               table_sql.replace("CREATE TABLE frozen_mission_defs (", "CREATE TABLE frozen_mission_defs_rebuild (", 1),
               "CREATE TEMP TABLE migration_mission_rows AS SELECT * FROM frozen_mission_defs;\nDROP TABLE frozen_mission_defs;\nALTER TABLE frozen_mission_defs_rebuild RENAME TO frozen_mission_defs;\nINSERT INTO frozen_mission_defs SELECT * FROM migration_mission_rows;\nDROP TABLE migration_mission_rows;\n",
               "CREATE TRIGGER" + guards,
               (directory / "003_seal_validation.sql").read_text()]
    pieces.append("""CREATE TABLE base_module_state (
 snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
 player_id TEXT NOT NULL, base_instance_id TEXT NOT NULL, base_module_id TEXT NOT NULL,
 station_id TEXT NOT NULL, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,base_instance_id),
 UNIQUE(snapshot_id,world_id,content_snapshot_id,player_id,base_module_id,station_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,base_module_id) REFERENCES frozen_base_module_defs(content_snapshot_id,base_module_id),
 FOREIGN KEY(content_snapshot_id,station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id)
) STRICT;
""")
    for action, row in (("INSERT", "NEW"), ("UPDATE", "OLD"), ("DELETE", "OLD")):
        condition = f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={row}.snapshot_id AND status='sealed')"
        if action == "UPDATE":
            condition += " OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
        pieces.append(f"CREATE TRIGGER base_module_state_{action.lower()}_immutable BEFORE {action} ON base_module_state\nWHEN {condition}\nBEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;\n")
    pieces.append("""CREATE TABLE database_meta_format2 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=2)
) STRICT;
INSERT INTO database_meta_format2 SELECT singleton,application_id,2 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format2 RENAME TO database_meta;
PRAGMA user_version=2;
""")
    (directory / "005_singleplayer_expansion.sql").write_text("\n".join(pieces))
    print("Reviewed extension:", len(new_tables), "new frozen tables; format2; adapter tables", len(build_catalog.CONTENT_TABLES))
finally:
    source.close()
    baseline.close()
