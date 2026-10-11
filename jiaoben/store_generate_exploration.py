"""Append normalized format12 event state and the reviewed schema10 adapter."""
from pathlib import Path
import sqlite3
from exploration_catalog import TABLES
from generate_frozen_schema import frozen_table_sql
import build_catalog

ROOT = Path(__file__).resolve().parents[1]
PROGRESS = ROOT / "code/database/progress"
STATES = {
 "exploration_instance_state": """event_id TEXT NOT NULL, generation INTEGER NOT NULL CHECK(generation>0),
 variant_id TEXT NOT NULL, variant_seed INTEGER NOT NULL CHECK(variant_seed>=0),
 phase TEXT NOT NULL CHECK(phase IN ('clue','surveyed','rescue','relic','mineral','extracting','ready','claimed','failed','withdrawn')),
 choice_id TEXT NOT NULL, operation_kind TEXT NOT NULL, operation_remaining_s REAL NOT NULL CHECK(operation_remaining_s>=0 AND operation_remaining_s<1e100),
 elapsed_s REAL NOT NULL CHECK(elapsed_s>=0 AND elapsed_s<1e100), cooldown_remaining_s REAL NOT NULL CHECK(cooldown_remaining_s>=0 AND cooldown_remaining_s<1e100),
 evidence_units INTEGER NOT NULL CHECK(evidence_units>=0), stabilized INTEGER NOT NULL CHECK(stabilized IN (0,1)),
 hazard_clock_s REAL NOT NULL CHECK(hazard_clock_s>=0 AND hazard_clock_s<1e100),
 outcome TEXT NOT NULL CHECK(outcome IN ('','full','partial','failed')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,event_id),
 UNIQUE(snapshot_id,world_id,content_snapshot_id,event_id,generation),
 FOREIGN KEY(content_snapshot_id,event_id) REFERENCES frozen_exploration_event_defs(content_snapshot_id,event_id),
 FOREIGN KEY(content_snapshot_id,variant_id,event_id) REFERENCES frozen_exploration_variant_defs(content_snapshot_id,variant_id,event_id)""",
 "exploration_actor_state": """npc_instance_id TEXT NOT NULL,event_id TEXT NOT NULL,generation INTEGER NOT NULL,
 actor_role TEXT NOT NULL CHECK(actor_role IN ('escort','enemy')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,event_id,generation) REFERENCES exploration_instance_state(snapshot_id,world_id,content_snapshot_id,event_id,generation)""",
 "exploration_claim_state": """player_id TEXT NOT NULL,event_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>0),variant_id TEXT NOT NULL,
 outcome TEXT NOT NULL CHECK(outcome IN ('full','partial')),
 credit_units INTEGER NOT NULL CHECK(credit_units>=0),insight_units INTEGER NOT NULL CHECK(insight_units>0),reputation_units INTEGER NOT NULL CHECK(reputation_units>=0),
 demand_id TEXT, demand_generation INTEGER NOT NULL CHECK(demand_generation>=0),claimed_tick INTEGER NOT NULL CHECK(claimed_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,event_id,generation),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,variant_id,event_id) REFERENCES frozen_exploration_variant_defs(content_snapshot_id,variant_id,event_id),
 FOREIGN KEY(content_snapshot_id,demand_id) REFERENCES frozen_station_demand_defs(content_snapshot_id,demand_id)""",
 "exploration_progress_state": """player_id TEXT NOT NULL,insight_available INTEGER NOT NULL CHECK(insight_available>=0),insight_earned INTEGER NOT NULL CHECK(insight_earned>=insight_available),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id)""",
 "exploration_research_state": """player_id TEXT NOT NULL,research_id TEXT NOT NULL,spent_insight INTEGER NOT NULL CHECK(spent_insight>0),paid_credit INTEGER NOT NULL CHECK(paid_credit>=0),completed_tick INTEGER NOT NULL CHECK(completed_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,research_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,research_id) REFERENCES frozen_exploration_research_defs(content_snapshot_id,research_id)""",
}
SEAL = """
CREATE TRIGGER exploration_context_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM exploration_instance_state WHERE snapshot_id=NEW.snapshot_id)<>
 (SELECT count(*) FROM frozen_exploration_event_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'exploration instance coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_exploration_event_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (SELECT count(*) FROM exploration_progress_state WHERE snapshot_id=NEW.snapshot_id)<>1
 THEN RAISE(ABORT,'exploration progress coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_instance_state s JOIN frozen_exploration_event_defs e USING(content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v USING(content_snapshot_id,variant_id,event_id)
 JOIN frozen_exploration_balance_defs b USING(content_snapshot_id)
 WHERE s.snapshot_id=NEW.snapshot_id AND (s.cooldown_remaining_s>e.cooldown_s OR s.hazard_clock_s>=b.hazard_period_s OR
 s.operation_remaining_s>max(v.survey_duration_s,v.work_duration_s) OR
 s.operation_kind NOT IN ('','survey','rescue','recover','stabilize','deepen') OR
 (s.operation_kind='' AND s.operation_remaining_s<>0) OR
 (s.phase IN ('ready','claimed') AND s.outcome NOT IN ('full','partial')) OR
 (e.event_kind='relic' AND s.evidence_units>v.relic_layers)))
 THEN RAISE(ABORT,'exploration timer or evidence outside frozen limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_actor_state a JOIN npc_state n USING(snapshot_id,world_id,content_snapshot_id,npc_instance_id)
 WHERE a.snapshot_id=NEW.snapshot_id AND (n.generation<>a.generation OR NOT EXISTS(SELECT 1 FROM frozen_exploration_actor_defs d
 WHERE d.content_snapshot_id=a.content_snapshot_id AND d.event_id=a.event_id AND d.actor_role=a.actor_role AND d.spawn_id=n.spawn_id)))
 THEN RAISE(ABORT,'exploration actor identity mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_claim_state c JOIN exploration_instance_state s USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v ON v.content_snapshot_id=c.content_snapshot_id AND v.variant_id=c.variant_id AND v.event_id=c.event_id
 WHERE c.snapshot_id=NEW.snapshot_id AND (c.generation>s.generation OR c.claimed_tick>NEW.simulation_tick OR
 (c.generation=s.generation AND (c.variant_id<>s.variant_id OR s.phase<>'claimed' OR c.outcome<>s.outcome)) OR
 c.credit_units<>CASE WHEN c.outcome='full' THEN v.full_credit ELSE v.partial_credit END OR
 c.reputation_units<>CASE WHEN c.outcome='full' THEN v.reputation_units ELSE 0 END OR
 c.insight_units>v.insight_units OR (c.outcome='full' AND c.insight_units<>v.insight_units)))
 THEN RAISE(ABORT,'exploration reward exceeds frozen receipt limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_instance_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.phase='claimed' AND
 NOT EXISTS(SELECT 1 FROM exploration_claim_state c WHERE c.snapshot_id=s.snapshot_id AND c.event_id=s.event_id AND c.generation=s.generation))
 THEN RAISE(ABORT,'exploration result lacks claim receipt') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_progress_state p WHERE p.snapshot_id=NEW.snapshot_id AND (
 p.insight_earned<>coalesce((SELECT sum(c.insight_units) FROM exploration_claim_state c WHERE c.snapshot_id=p.snapshot_id AND c.player_id=p.player_id),0) OR
 p.insight_available<>p.insight_earned-coalesce((SELECT sum(r.spent_insight) FROM exploration_research_state r WHERE r.snapshot_id=p.snapshot_id AND r.player_id=p.player_id),0)))
 THEN RAISE(ABORT,'exploration insight ledger mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_research_state r JOIN frozen_exploration_research_defs d USING(content_snapshot_id,research_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.spent_insight<>d.required_insight OR r.paid_credit<>d.required_credit OR r.completed_tick>NEW.simulation_tick OR
 NOT EXISTS(SELECT 1 FROM unlock_state u WHERE u.snapshot_id=r.snapshot_id AND u.player_id=r.player_id AND u.unlock_id=d.reward_unlock_id)))
 THEN RAISE(ABORT,'exploration research payment or knowledge mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM resource_state r JOIN frozen_exploration_resource_defs d USING(content_snapshot_id,node_id)
 JOIN exploration_instance_state s USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v USING(content_snapshot_id,variant_id,event_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.respawn_remaining_s<>0 OR r.remaining_units>v.mineral_units OR
 ((s.phase<>'mineral' OR s.choice_id<>d.choice_id) AND r.remaining_units<>0)))
 THEN RAISE(ABORT,'inactive exploration mineral regenerated') END;
END;
CREATE TABLE database_meta_format12 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=12)
) STRICT;
INSERT INTO database_meta_format12 SELECT singleton,application_id,12 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format12 RENAME TO database_meta;
PRAGMA user_version=12;
"""


def main():
    db = sqlite3.connect((ROOT / "jiaoben/tmp/catalog-exploration-candidate.db").as_uri() + "?mode=ro", uri=True)
    db.execute("PRAGMA foreign_keys=ON"); build_catalog.validate_database(db)
    assert db.execute("SELECT schema_version FROM catalog_meta").fetchone()[0] == 10
    adapter = ["-- Reviewed schema10 authored-exploration adapter.\nPRAGMA foreign_keys=ON;"]
    adapter += [db.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?", (t,)).fetchone()[0] + ";" for t in sorted(build_catalog.CONTENT_TABLES)]
    adapter += [s + ";" for s in build_catalog.content_views(db).values()]
    (PROGRESS / "catalog_adapter_v0_11.sql").write_text("\n\n".join(adapter) + "\n", encoding="utf-8", newline="\n")
    parts = ["-- Format11 -> 12: authored exploration, real actors and unique evidence/reward ledgers.\n"]
    parts += [frozen_table_sql(db, t) for t in TABLES]
    for table, columns in STATES.items():
        parts.append(f"CREATE TABLE {table} (\n snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,\n {columns},\n FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE\n) STRICT;\n")
        for action, row in (("INSERT", "NEW"), ("UPDATE", "OLD"), ("DELETE", "OLD")):
            guard = f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={row}.snapshot_id AND status='sealed')"
            if action == "UPDATE": guard += " OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table}\nWHEN {guard}\nBEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;\n")
    parts.append(SEAL)
    (PROGRESS / "015_exploration.sql").write_text("\n".join(parts), encoding="utf-8", newline="\n")
    db.close()
    print("EXPLORATION_SCHEMA PASS seven frozen definitions, five normalized states, fixed adapter and format12")


if __name__ == "__main__":
    main()
