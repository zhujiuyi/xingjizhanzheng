"""Generate the reviewed format3 signal/lifetime extension, preserving format2."""
from pathlib import Path
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog
from generate_frozen_schema import frozen_table_sql

directory = ROOT / "code/database/progress"
source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
try:
    source.execute("PRAGMA foreign_keys=ON")
    build_catalog.validate_database(source)
    adapter = ["-- Reviewed format3 adapter, with signal unlock rewards.\nPRAGMA foreign_keys=ON;"]
    adapter.extend(source.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?", (table,)).fetchone()[0] + ";" for table in sorted(build_catalog.CONTENT_TABLES))
    adapter.extend(sql + ";" for sql in build_catalog.content_views(source).values())
    (directory / "catalog_adapter_v0_4_r2.sql").write_text("\n\n".join(adapter) + "\n")
    sql = "-- Format2 -> 3: additive signal rewards and remaining world-time lifetime.\n"
    sql += frozen_table_sql(source, "signal_unlock_rewards")
    sql += """ALTER TABLE gate_state ADD COLUMN lifetime_remaining_s REAL CHECK(lifetime_remaining_s IS NULL OR lifetime_remaining_s>=0);
CREATE TRIGGER gate_lifetime_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM gate_state g
 JOIN frozen_connection_defs c ON c.content_snapshot_id=g.content_snapshot_id AND c.connection_id=g.connection_id
 JOIN frozen_gate_class_defs d ON d.content_snapshot_id=c.content_snapshot_id AND d.gate_class_id=c.gate_class_id
 WHERE g.snapshot_id=NEW.snapshot_id AND g.lifetime_remaining_s IS NOT NULL
 AND (d.lifetime_s IS NULL OR g.lifetime_remaining_s>d.lifetime_s))
 THEN RAISE(ABORT,'gate lifetime over frozen definition') END;
END;
CREATE TABLE database_meta_format3 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=3)
) STRICT;
INSERT INTO database_meta_format3 SELECT singleton,application_id,3 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format3 RENAME TO database_meta;
PRAGMA user_version=3;
"""
    (directory / "006_signal_and_gate_lifetime.sql").write_text(sql)
    print("Format3 adapter",len(build_catalog.CONTENT_TABLES),"tables; new signal table and lifetime")
finally:
    source.close()
