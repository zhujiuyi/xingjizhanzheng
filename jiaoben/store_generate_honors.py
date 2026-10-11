"""Append format18 commander proofs; 001-020 and historical adapters stay fixed."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from honors_catalog import TABLES

ROOT=Path(__file__).resolve().parents[1]
STATES={
 'civilization_command_state':('''player_id TEXT NOT NULL,faction_id TEXT NOT NULL,
 phase TEXT NOT NULL DEFAULT 'unregistered' CHECK(phase IN ('unregistered','assessing','certified')),
 registered_tick INTEGER NOT NULL DEFAULT 0 CHECK(registered_tick>=0),certified_tick INTEGER NOT NULL DEFAULT 0 CHECK(certified_tick>=0),
 paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),awarded_reputation INTEGER NOT NULL DEFAULT 0 CHECK(awarded_reputation>=0),
 legacy_war_id TEXT,legacy_attempt INTEGER NOT NULL DEFAULT 0 CHECK(legacy_attempt>=0),
 CHECK((legacy_war_id IS NULL AND legacy_attempt=0) OR (legacy_war_id IS NOT NULL AND legacy_attempt>0))''','faction_id',
 '''FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_command_defs(content_snapshot_id,faction_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,legacy_war_id) REFERENCES war_campaign_state(snapshot_id,world_id,content_snapshot_id,war_id)'''),
 'civilization_honor_evidence_state':('''source_token TEXT NOT NULL,task_id TEXT NOT NULL,
 source_kind TEXT NOT NULL CHECK(source_kind IN ('exploration','consignment','operation')),source_def_id TEXT NOT NULL,
 generation INTEGER NOT NULL CHECK(generation>0),credited_units INTEGER NOT NULL CHECK(credited_units>0),recorded_tick INTEGER NOT NULL CHECK(recorded_tick>=0)''','source_token',
 '''FOREIGN KEY(content_snapshot_id,task_id) REFERENCES frozen_civilization_honor_task_defs(content_snapshot_id,task_id)'''),
}

SEAL='''CREATE TRIGGER honor_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM civilization_command_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_civilization_command_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN RAISE(ABORT,'commander coverage incomplete') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM frozen_civilization_command_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND EXISTS(SELECT 1 FROM civilization_honor_evidence_state WHERE snapshot_id=NEW.snapshot_id) THEN RAISE(ABORT,'honor evidence under legacy rules') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM civilization_command_state c JOIN frozen_civilization_command_defs d USING(content_snapshot_id,faction_id)
 WHERE c.snapshot_id=NEW.snapshot_id AND (c.registered_tick>NEW.simulation_tick OR c.certified_tick>NEW.simulation_tick OR
 (c.phase='unregistered' AND (c.registered_tick<>0 OR c.certified_tick<>0 OR c.paid_credit<>0 OR c.awarded_reputation<>0)) OR
 (c.phase='assessing' AND (c.certified_tick<>0 OR c.paid_credit<>0 OR c.awarded_reputation<>0)) OR
 (c.phase='certified' AND (c.certified_tick<c.registered_tick OR c.paid_credit<>d.reward_credit OR c.awarded_reputation<>d.reward_reputation)) OR
 (c.legacy_war_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM frozen_civilization_war_defs w WHERE w.content_snapshot_id=c.content_snapshot_id AND w.war_id=c.legacy_war_id AND w.faction_id=c.faction_id)))) THEN RAISE(ABORT,'invalid commander certification payment or time') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM civilization_honor_evidence_state e JOIN frozen_civilization_honor_task_defs t USING(content_snapshot_id,task_id)
 JOIN civilization_command_state c ON c.snapshot_id=e.snapshot_id AND c.faction_id=t.faction_id
 WHERE e.snapshot_id=NEW.snapshot_id AND (c.phase='unregistered' OR e.recorded_tick<c.registered_tick OR e.recorded_tick>NEW.simulation_tick)) THEN RAISE(ABORT,'honor evidence precedes registration') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM civilization_honor_evidence_state e JOIN frozen_civilization_honor_task_defs t USING(content_snapshot_id,task_id)
 WHERE e.snapshot_id=NEW.snapshot_id GROUP BY e.task_id HAVING sum(e.credited_units)>max(t.required_units)) THEN RAISE(ABORT,'honor progress exceeds examination requirement') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM civilization_honor_evidence_state e JOIN frozen_civilization_honor_task_defs t USING(content_snapshot_id,task_id)
 WHERE e.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM frozen_civilization_honor_source_defs s
 WHERE s.content_snapshot_id=e.content_snapshot_id AND s.task_id=e.task_id AND
 ((e.source_kind='exploration' AND s.event_id=e.source_def_id) OR (e.source_kind='consignment' AND s.contract_id=e.source_def_id) OR (e.source_kind='operation' AND s.operation_id=e.source_def_id)))) THEN RAISE(ABORT,'honor source not authorized for this task') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM civilization_honor_evidence_state e JOIN frozen_civilization_honor_task_defs t USING(content_snapshot_id,task_id)
 WHERE e.snapshot_id=NEW.snapshot_id AND e.source_kind='exploration' AND
 (t.task_kind NOT IN ('scout','rescue') OR e.credited_units<>1 OR e.source_token<>'exploration:'||e.source_def_id||':'||e.generation OR
 NOT EXISTS(SELECT 1 FROM exploration_claim_state r JOIN frozen_exploration_event_defs d USING(content_snapshot_id,event_id)
 WHERE r.snapshot_id=e.snapshot_id AND r.event_id=e.source_def_id AND r.generation=e.generation AND r.outcome='full' AND r.claimed_tick=e.recorded_tick
 AND d.event_kind=CASE WHEN t.task_kind='scout' THEN 'relic' ELSE 'rescue' END))) THEN RAISE(ABORT,'honor exploration requires a full settled outcome') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM civilization_honor_evidence_state e JOIN frozen_civilization_honor_task_defs t USING(content_snapshot_id,task_id)
 WHERE e.snapshot_id=NEW.snapshot_id AND e.source_kind='operation' AND
 (t.task_kind<>'combat' OR e.source_token<>'operation:'||e.source_def_id||':'||e.generation OR
 NOT EXISTS(SELECT 1 FROM specialization_evidence_state r JOIN frozen_operation_defs d ON d.content_snapshot_id=r.content_snapshot_id AND d.operation_id=r.source_def_id
 WHERE r.snapshot_id=e.snapshot_id AND r.source_token=e.source_token AND r.source_kind='operation' AND r.source_def_id=e.source_def_id AND r.generation=e.generation
 AND d.operation_kind='demolition' AND r.source_units=d.target_units AND e.credited_units<=r.source_units))) THEN RAISE(ABORT,'honor combat requires a complete settled demolition') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM civilization_honor_evidence_state e JOIN frozen_civilization_honor_task_defs t USING(content_snapshot_id,task_id)
 WHERE e.snapshot_id=NEW.snapshot_id AND e.source_kind='consignment' AND
 (t.task_kind<>'logistics' OR NOT EXISTS(SELECT 1 FROM consignment_receipt_state r JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id)
 WHERE r.snapshot_id=e.snapshot_id AND 'consignment:'||r.receipt_id=e.source_token AND r.contract_id=e.source_def_id AND r.generation=e.generation
 AND r.action_kind='claim' AND r.units>=e.credited_units AND r.reward_credit=r.units*d.reward_per_unit))) THEN RAISE(ABORT,'honor logistics requires actual settled deliveries') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM civilization_command_state c JOIN frozen_civilization_honor_task_defs t USING(content_snapshot_id,faction_id)
 WHERE c.snapshot_id=NEW.snapshot_id AND c.phase='certified' AND COALESCE((SELECT sum(e.credited_units) FROM civilization_honor_evidence_state e WHERE e.snapshot_id=c.snapshot_id AND e.task_id=t.task_id),0)<>t.required_units) THEN RAISE(ABORT,'commander certification requires all four abilities') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_campaign_state w JOIN frozen_civilization_war_defs d USING(content_snapshot_id,war_id)
 JOIN civilization_command_state c ON c.snapshot_id=w.snapshot_id AND c.faction_id=d.faction_id
 WHERE w.snapshot_id=NEW.snapshot_id AND w.status IN ('assembling','fighting','occupying') AND c.phase<>'certified'
 AND NOT(c.legacy_war_id IS NOT NULL AND c.legacy_war_id=w.war_id AND c.legacy_attempt=w.attempt)) THEN RAISE(ABORT,'new war requires commander qualification') END;
END;'''

def main():
    db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
    parts=['-- Reviewed civilization ability examination and durable proof sources.']+[frozen_table_sql(db,t) for t in TABLES]
    for table,(columns,key,foreign) in STATES.items():
        parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,{foreign}) STRICT;''')
        for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
            guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
            if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
    parts.append(SEAL)
    parts.append('''CREATE TABLE database_meta_format18(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=18)) STRICT;
INSERT INTO database_meta_format18 SELECT singleton,application_id,18 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format18 RENAME TO database_meta;
PRAGMA user_version=18;''')
    (ROOT/'code/database/progress/021_honors.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
    adapter=['-- Reviewed schema16 honor adapter.\nPRAGMA foreign_keys=ON;']
    for kind in ['table','view']:
        adapter += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type=? AND name NOT LIKE 'sqlite_%' ORDER BY name",(kind,))]
    (ROOT/'code/database/progress/catalog_adapter_v0_17.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n')
    db.close()

if __name__=='__main__':main()
