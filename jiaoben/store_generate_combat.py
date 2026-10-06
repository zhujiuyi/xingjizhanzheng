"""Generate the reviewed format7 combat extension; historical migrations stay fixed."""
from pathlib import Path
import sqlite3
import build_catalog
from generate_frozen_schema import frozen_table_sql

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "code/database/progress"
NEW_TABLES = ("weapon_behavior_defs", "ship_weapon_permissions", "drone_defs", "system_lighting_defs")

SEAL = """
CREATE TRIGGER combat_equipment_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed'
 AND EXISTS(SELECT 1 FROM content_snapshot c WHERE c.content_snapshot_id=NEW.content_snapshot_id AND c.catalog_schema_version>=5)
BEGIN
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM equipment_state e
  JOIN container_state c ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
  JOIN ship_state s ON s.snapshot_id=c.snapshot_id AND s.ship_instance_id=c.ship_instance_id
  JOIN frozen_module_defs m ON m.content_snapshot_id=e.content_snapshot_id AND m.module_id=e.module_def_id
  WHERE e.snapshot_id=NEW.snapshot_id AND
   (c.slot_type<>m.slot_type
    OR NOT EXISTS(SELECT 1 FROM frozen_ship_slot_defs slot
       WHERE slot.content_snapshot_id=e.content_snapshot_id AND slot.ship_id=s.ship_def_id
        AND slot.slot_type=m.slot_type AND slot.slot_index=c.slot_index)))
 THEN RAISE(ABORT,'equipment slot incompatible with frozen hull') END;
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM equipment_state e
  JOIN container_state c ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
  JOIN ship_state s ON s.snapshot_id=c.snapshot_id AND s.ship_instance_id=c.ship_instance_id
  JOIN frozen_weapon_defs w ON w.content_snapshot_id=e.content_snapshot_id AND w.module_id=e.module_def_id
  LEFT JOIN frozen_weapon_behavior_defs b ON b.content_snapshot_id=w.content_snapshot_id AND b.module_id=w.module_id
  LEFT JOIN frozen_ship_weapon_permissions p ON p.content_snapshot_id=b.content_snapshot_id AND p.ship_id=s.ship_def_id AND p.family_id=b.family_id
  WHERE e.snapshot_id=NEW.snapshot_id AND (b.module_id IS NULL OR p.ship_id IS NULL OR b.size_class>p.max_size))
 THEN RAISE(ABORT,'weapon incompatible with frozen hull') END;
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM equipment_state e
  JOIN container_state c ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
  JOIN ship_state s ON s.snapshot_id=c.snapshot_id AND s.ship_instance_id=c.ship_instance_id
  JOIN frozen_weapon_behavior_defs b ON b.content_snapshot_id=e.content_snapshot_id AND b.module_id=e.module_def_id
  JOIN frozen_ship_weapon_permissions p ON p.content_snapshot_id=b.content_snapshot_id AND p.ship_id=s.ship_def_id AND p.family_id=b.family_id
  WHERE e.snapshot_id=NEW.snapshot_id
  GROUP BY s.ship_instance_id,b.family_id,p.max_installed HAVING count(*)>p.max_installed)
 THEN RAISE(ABORT,'weapon family limit exceeded in frozen hull') END;
END;
CREATE TABLE database_meta_format7 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=7)
) STRICT;
INSERT INTO database_meta_format7 SELECT singleton,application_id,7 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format7 RENAME TO database_meta;
PRAGMA user_version=7;
"""


def main():
    source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
    try:
        source.execute("PRAGMA foreign_keys=ON")
        build_catalog.validate_database(source)
        assert source.execute("SELECT schema_version,content_version FROM catalog_meta").fetchone() == (5, "v0.6-combat")
        adapter = ["-- Reviewed combat schema5 adapter. Never execute save-provided DDL.\nPRAGMA foreign_keys=ON;"]
        adapter += [source.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?", (table,)).fetchone()[0] + ";"
                    for table in sorted(build_catalog.CONTENT_TABLES)]
        adapter += [sql + ";" for sql in build_catalog.content_views(source).values()]
        (DIRECTORY / "catalog_adapter_v0_6.sql").write_text("\n\n".join(adapter) + "\n", encoding="utf-8", newline="\n")
        migration = "-- Format6 -> 7: frozen weapon/hull/drone/lighting rules and sealed fit permissions.\n"
        migration += "\n".join(frozen_table_sql(source, table) for table in NEW_TABLES)
        migration += SEAL
        (DIRECTORY / "010_combat_and_lighting.sql").write_text(migration, encoding="utf-8", newline="\n")
        print(f"Combat adapter: {len(build_catalog.CONTENT_TABLES)} tables; format7 adds four immutable frozen tables")
    finally:
        source.close()


if __name__ == "__main__":
    main()
