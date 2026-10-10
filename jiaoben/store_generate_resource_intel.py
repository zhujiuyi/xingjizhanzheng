"""Append format11 fixed definitions without changing old migrations or runtime rows."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from resource_intel_catalog import TABLES
import build_catalog

ROOT = Path(__file__).resolve().parents[1]
PROGRESS = ROOT / "code/database/progress"


def main():
    path = ROOT / "jiaoben/tmp/catalog-resource-intel-candidate.db"
    db = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
    db.execute("PRAGMA foreign_keys=ON")
    build_catalog.validate_database(db)
    assert db.execute("SELECT schema_version FROM catalog_meta").fetchone()[0] == 9
    adapter = ["-- Reviewed schema9 resource-intelligence adapter.\nPRAGMA foreign_keys=ON;"]
    adapter += [db.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?", (t,)).fetchone()[0] + ";" for t in sorted(build_catalog.CONTENT_TABLES)]
    adapter += [sql + ";" for sql in build_catalog.content_views(db).values()]
    (PROGRESS / "catalog_adapter_v0_10.sql").write_text("\n\n".join(adapter) + "\n", encoding="utf-8", newline="\n")
    parts = ["-- Format10 -> 11: frozen resource quality and sector activity; no existing state changes.\n"]
    parts += [frozen_table_sql(db, t) for t in TABLES]
    parts.append("""
CREATE TABLE database_meta_format11 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=11)
) STRICT;
INSERT INTO database_meta_format11 SELECT singleton,application_id,11 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format11 RENAME TO database_meta;
PRAGMA user_version=11;
""")
    (PROGRESS / "014_resource_intel.sql").write_text("\n".join(parts), encoding="utf-8", newline="\n")
    db.close()
    print("RESOURCE_INTEL_SCHEMA PASS schema9 adapter, format11, two frozen definition tables")


if __name__ == "__main__":
    main()
