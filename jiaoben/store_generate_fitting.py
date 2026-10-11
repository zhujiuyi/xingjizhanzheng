"""Add format16 research ledgers and a fixed v0.15 adapter; preserve 001–018."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from fitting_catalog import TABLES
ROOT=Path(__file__).resolve().parents[1]
def main():
 db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
 parts=['-- Reviewed horizontal research and fit analysis.']+[frozen_table_sql(db,t) for t in TABLES]
 states={
 'specialization_progress_state':("player_id TEXT NOT NULL,earned_points INTEGER NOT NULL CHECK(earned_points>=0),spent_points INTEGER NOT NULL CHECK(spent_points>=0 AND spent_points<=earned_points),donated_points INTEGER NOT NULL CHECK(donated_points>=0 AND donated_points<=earned_points)",'player_id',''),
 'specialization_evidence_state':("player_id TEXT NOT NULL,source_token TEXT NOT NULL,source_kind TEXT NOT NULL CHECK(source_kind IN ('tactic','exploration','operation','donation')),source_def_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=0),source_units INTEGER NOT NULL CHECK(source_units>0),awarded_points INTEGER NOT NULL CHECK(awarded_points>0),material_units INTEGER NOT NULL CHECK(material_units>=0),paid_credit INTEGER NOT NULL CHECK(paid_credit>=0)",'player_id,source_token',''),
 'specialization_research_state':("player_id TEXT NOT NULL,research_id TEXT NOT NULL,invested_points INTEGER NOT NULL CHECK(invested_points>0),paid_credit INTEGER NOT NULL CHECK(paid_credit>=0),completed INTEGER NOT NULL CHECK(completed IN (0,1)),completed_tick INTEGER NOT NULL CHECK(completed_tick>=0)",'player_id,research_id',',FOREIGN KEY(content_snapshot_id,research_id) REFERENCES frozen_specialization_research_defs(content_snapshot_id,research_id)'),
 }
 for table,(cols,pk,extra) in states.items():
  parts.append(f'CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{cols},PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{pk}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE{extra}) STRICT;')
  for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
   guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
   if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
   parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
 parts.append('''CREATE TRIGGER specialization_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM specialization_progress_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_specialization_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN RAISE(ABORT,'specialization coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM specialization_progress_state p WHERE p.snapshot_id=NEW.snapshot_id AND
 (p.earned_points<>COALESCE((SELECT sum(e.awarded_points) FROM specialization_evidence_state e WHERE e.snapshot_id=p.snapshot_id AND e.player_id=p.player_id),0) OR
 p.spent_points<>COALESCE((SELECT sum(r.invested_points) FROM specialization_research_state r WHERE r.snapshot_id=p.snapshot_id AND r.player_id=p.player_id),0) OR
 p.donated_points<>COALESCE((SELECT sum(e.awarded_points) FROM specialization_evidence_state e WHERE e.snapshot_id=p.snapshot_id AND e.player_id=p.player_id AND e.source_kind='donation'),0))) THEN RAISE(ABORT,'specialization evidence conservation failed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM specialization_research_state r JOIN frozen_specialization_research_defs d USING(content_snapshot_id,research_id) WHERE r.snapshot_id=NEW.snapshot_id AND
 (r.invested_points>d.required_points OR r.paid_credit<>r.invested_points*d.credit_per_point OR r.completed<>(r.invested_points=d.required_points) OR (r.completed=0 AND r.completed_tick<>0) OR
 (r.completed=1 AND NOT EXISTS(SELECT 1 FROM unlock_state u WHERE u.snapshot_id=r.snapshot_id AND u.player_id=r.player_id AND u.unlock_id=d.reward_unlock_id)))) THEN RAISE(ABORT,'specialization research ledger invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM specialization_evidence_state e JOIN frozen_specialization_balance_defs b USING(content_snapshot_id) WHERE e.snapshot_id=NEW.snapshot_id AND
 ((e.source_kind='donation' AND (e.source_def_id<>b.donation_item_id OR e.source_units>b.max_donation_points OR e.awarded_points<>e.source_units OR e.material_units<>e.source_units*b.donation_units_per_point OR e.paid_credit<>e.source_units*b.donation_credit_per_point)) OR
 (e.source_kind<>'donation' AND (e.material_units<>0 OR e.paid_credit<>0)) OR
 (e.source_kind='tactic' AND (e.source_units<>1 OR e.awarded_points<>b.tactic_points OR NOT EXISTS(SELECT 1 FROM frozen_npc_tactic_bindings n WHERE n.content_snapshot_id=e.content_snapshot_id AND n.spawn_id=e.source_def_id))) OR
 (e.source_kind='exploration' AND (e.source_units<>1 OR e.awarded_points<>b.exploration_points OR NOT EXISTS(SELECT 1 FROM exploration_claim_state c WHERE c.snapshot_id=e.snapshot_id AND c.player_id=e.player_id AND c.event_id=e.source_def_id AND c.generation=e.generation))) OR
 (e.source_kind='operation' AND (e.awarded_points<>e.source_units*b.operation_points_per_unit OR NOT EXISTS(SELECT 1 FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=e.snapshot_id AND o.operation_id=e.source_def_id AND o.generation>=e.generation AND e.source_units<=d.target_units))))) THEN RAISE(ABORT,'specialization source or payment invalid') END;
END;
CREATE TABLE database_meta_format16(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=16)) STRICT;
INSERT INTO database_meta_format16 SELECT singleton,application_id,16 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format16 RENAME TO database_meta;
PRAGMA user_version=16;''')
 (ROOT/'code/database/progress/019_fitting.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
 adapters=['-- Reviewed schema14 fitting adapter.\nPRAGMA foreign_keys=ON;']
 adapters += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
 adapters += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type='view' ORDER BY name")]
 (ROOT/'code/database/progress/catalog_adapter_v0_15.sql').write_text('\n\n'.join(adapters)+'\n',encoding='utf-8',newline='\n');db.close()
if __name__=='__main__':main()
