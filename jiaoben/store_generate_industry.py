"""Generate only the new reviewed adapter and append-only format10 migration."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from industry_catalog import TABLES
import build_catalog

ROOT = Path(__file__).resolve().parents[1]
PROGRESS = ROOT / "code/database/progress"
STATES = {
    "industry_job_state": """job_id TEXT NOT NULL, player_id TEXT NOT NULL, station_id TEXT NOT NULL,
 blueprint_id TEXT NOT NULL, batches INTEGER NOT NULL CHECK(batches>0),
 status TEXT NOT NULL CHECK(status IN ('queued','running','ready','claimed','cancelled')),
 queue_sequence INTEGER NOT NULL CHECK(queue_sequence>0),
 duration_s REAL NOT NULL CHECK(duration_s>0 AND duration_s<1e100),
 remaining_s REAL NOT NULL CHECK(remaining_s>=0 AND remaining_s<=duration_s),
 paid_credit INTEGER NOT NULL CHECK(paid_credit>=0),
 created_tick INTEGER NOT NULL CHECK(created_tick>=0), finished_tick INTEGER NOT NULL CHECK(finished_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,job_id),
 UNIQUE(snapshot_id,world_id,content_snapshot_id,queue_sequence),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id),
 FOREIGN KEY(content_snapshot_id,blueprint_id) REFERENCES frozen_industry_recipe_defs(content_snapshot_id,blueprint_id),
 CHECK(status NOT IN ('ready','claimed') OR remaining_s=0)""",
    "industry_input_state": """job_id TEXT NOT NULL, item_id TEXT NOT NULL, quantity INTEGER NOT NULL CHECK(quantity>0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,job_id,item_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,job_id) REFERENCES industry_job_state(snapshot_id,world_id,content_snapshot_id,job_id),
 FOREIGN KEY(content_snapshot_id,item_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)""",
    "station_demand_state": """demand_id TEXT NOT NULL, generation INTEGER NOT NULL CHECK(generation>0),
 status TEXT NOT NULL CHECK(status IN ('active','cooldown')),
 remaining_units INTEGER NOT NULL CHECK(remaining_units>=0),
 phase_remaining_s REAL NOT NULL CHECK(phase_remaining_s>=0 AND phase_remaining_s<1e100),
 benefit_remaining_s REAL NOT NULL CHECK(benefit_remaining_s>=0 AND benefit_remaining_s<1e100),
 completed_cycles INTEGER NOT NULL CHECK(completed_cycles>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,demand_id),
 FOREIGN KEY(content_snapshot_id,demand_id) REFERENCES frozen_station_demand_defs(content_snapshot_id,demand_id)""",
}

SEAL = """
CREATE TRIGGER industry_context_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM station_demand_state WHERE snapshot_id=NEW.snapshot_id)<>
  (SELECT count(*) FROM frozen_station_demand_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'regional needs coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM station_demand_state s JOIN frozen_station_demand_defs d USING(content_snapshot_id,demand_id)
  WHERE s.snapshot_id=NEW.snapshot_id AND (s.remaining_units>d.required_units OR
  s.phase_remaining_s>CASE WHEN s.status='active' THEN d.duration_s ELSE d.cooldown_s END OR
  s.benefit_remaining_s>(SELECT demand_benefit_duration_s FROM frozen_industry_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id)))
 THEN RAISE(ABORT,'regional need outside frozen limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM industry_job_state j JOIN frozen_industry_balance_defs b USING(content_snapshot_id)
  WHERE j.snapshot_id=NEW.snapshot_id AND j.batches>b.max_batches)
 THEN RAISE(ABORT,'industrial batches outside frozen limits') END;
 SELECT CASE WHEN EXISTS(SELECT station_id FROM industry_job_state WHERE snapshot_id=NEW.snapshot_id AND status IN ('queued','running','ready')
  GROUP BY station_id HAVING count(*)>(SELECT queue_limit FROM frozen_industry_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id))
 THEN RAISE(ABORT,'industrial queue overflow') END;
 SELECT CASE WHEN EXISTS(SELECT station_id FROM industry_job_state WHERE snapshot_id=NEW.snapshot_id AND status='running' GROUP BY station_id HAVING count(*)>1)
 THEN RAISE(ABORT,'multiple active industrial jobs at one station') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM industry_input_state e JOIN industry_job_state j USING(snapshot_id,world_id,content_snapshot_id,job_id)
  JOIN frozen_industry_recipe_defs b USING(content_snapshot_id,blueprint_id) WHERE e.snapshot_id=NEW.snapshot_id AND e.quantity<>
  j.batches*coalesce((SELECT quantity FROM frozen_recipe_inputs r WHERE r.content_snapshot_id=b.content_snapshot_id AND r.recipe_id=b.recipe_id AND r.item_id=e.item_id),
  (SELECT quantity FROM frozen_hull_recipe_inputs r WHERE r.content_snapshot_id=b.content_snapshot_id AND r.hull_recipe_id=b.hull_recipe_id AND r.item_id=e.item_id),0))
 THEN RAISE(ABORT,'industrial escrow quantity differs from frozen recipe') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM industry_job_state j JOIN frozen_industry_recipe_defs b USING(content_snapshot_id,blueprint_id)
  JOIN frozen_recipe_inputs r ON r.content_snapshot_id=b.content_snapshot_id AND r.recipe_id=b.recipe_id
  WHERE j.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM industry_input_state e WHERE e.snapshot_id=j.snapshot_id AND e.job_id=j.job_id AND e.item_id=r.item_id))
  OR EXISTS(SELECT 1 FROM industry_job_state j JOIN frozen_industry_recipe_defs b USING(content_snapshot_id,blueprint_id)
  JOIN frozen_hull_recipe_inputs r ON r.content_snapshot_id=b.content_snapshot_id AND r.hull_recipe_id=b.hull_recipe_id
  WHERE j.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM industry_input_state e WHERE e.snapshot_id=j.snapshot_id AND e.job_id=j.job_id AND e.item_id=r.item_id))
 THEN RAISE(ABORT,'industrial escrow incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM industry_job_state j JOIN frozen_industry_recipe_defs b USING(content_snapshot_id,blueprint_id)
  WHERE j.snapshot_id=NEW.snapshot_id AND j.status='claimed' AND b.recipe_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM production_state p WHERE p.snapshot_id=j.snapshot_id AND p.production_id=j.job_id AND p.recipe_id=b.recipe_id AND p.batches=j.batches AND p.station_id=j.station_id AND p.output_claimed=1))
 THEN RAISE(ABORT,'industrial output lacks a unique production receipt') END;
END;
CREATE TABLE database_meta_format10 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=10)
) STRICT;
INSERT INTO database_meta_format10 SELECT singleton,application_id,10 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format10 RENAME TO database_meta;
PRAGMA user_version=10;
"""


def main():
    path = ROOT / "jiaoben/tmp/catalog-industry-candidate.db"
    source = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
    source.execute("PRAGMA foreign_keys=ON")
    build_catalog.validate_database(source)
    assert source.execute("SELECT schema_version,content_version FROM catalog_meta").fetchone() == (8, "v0.9-industry")
    adapter = ["-- Reviewed industry schema8 adapter; never execute saved DDL.\nPRAGMA foreign_keys=ON;"]
    adapter += [source.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?", (table,)).fetchone()[0] + ";" for table in sorted(build_catalog.CONTENT_TABLES)]
    adapter += [sql + ";" for sql in build_catalog.content_views(source).values()]
    (PROGRESS / "catalog_adapter_v0_9.sql").write_text("\n\n".join(adapter) + "\n", encoding="utf-8", newline="\n")
    parts = ["-- Format9 -> 10: offline job escrow, regional demands and immutable definitions.\n"]
    parts += [frozen_table_sql(source, table) for table in TABLES]
    for table, columns in STATES.items():
        parts.append(f"CREATE TABLE {table} (\n snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,\n {columns},\n FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE\n) STRICT;\n")
        for action, row in (("INSERT", "NEW"), ("UPDATE", "OLD"), ("DELETE", "OLD")):
            guard = f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={row}.snapshot_id AND status='sealed')"
            if action == "UPDATE":
                guard += " OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table}\nWHEN {guard}\nBEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;\n")
    parts.append(SEAL)
    (PROGRESS / "013_industry.sql").write_text("\n".join(parts), encoding="utf-8", newline="\n")
    source.close()
    print("INDUSTRY_SCHEMA PASS three definitions, three states, schema8 adapter, format10 migration")


if __name__ == "__main__":
    main()
