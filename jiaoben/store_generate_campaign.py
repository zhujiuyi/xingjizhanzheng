"""Append campaign snapshots as format22; preserve all published SQL bytes."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from campaign_catalog import TABLES
from campaign_state_spec import STATES
ROOT=Path(__file__).resolve().parents[1]

SEAL='''CREATE TRIGGER campaign_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_input_state i JOIN frozen_construction_input_defs d USING(content_snapshot_id,project_id,stage_index,item_id,delivery_station_id)
 WHERE i.snapshot_id=NEW.snapshot_id AND (i.delivered_units>d.required_units OR i.delivered_units<>(SELECT coalesce(sum(r.units),0) FROM construction_receipt_state r WHERE r.snapshot_id=i.snapshot_id AND r.project_id=i.project_id AND r.stage_index=i.stage_index AND r.item_id=i.item_id AND r.station_id=i.delivery_station_id AND r.action_kind='deliver'))) THEN RAISE(ABORT,'construction delivery lacks finite receipts') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_state s JOIN frozen_construction_stage_defs d USING(content_snapshot_id,project_id,stage_index)
 WHERE s.snapshot_id=NEW.snapshot_id AND (s.work_remaining_s>d.work_s OR s.completed_tick>NEW.simulation_tick OR
 s.paid_credit_total<>(SELECT coalesce(sum(r.paid_credit),0) FROM construction_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.project_id=s.project_id) OR
 (s.phase='working' AND NOT EXISTS(SELECT 1 FROM construction_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.project_id=s.project_id AND r.stage_index=s.stage_index AND r.action_kind='start')) OR
 (s.phase='completed' AND (s.stage_index<>3 OR s.work_remaining_s<>0)) OR
 (s.phase='gathering' AND s.work_remaining_s<>0))) THEN RAISE(ABORT,'invalid construction phase or expense') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_receipt_state r JOIN frozen_construction_stage_defs d USING(content_snapshot_id,project_id,stage_index)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.event_tick>NEW.simulation_tick OR
 (r.action_kind='start' AND (r.units<>0 OR r.item_id IS NOT NULL OR r.paid_credit<>d.fee_credit)) OR
 (r.action_kind='deliver' AND (r.units<=0 OR r.item_id IS NULL OR r.paid_credit<>0 OR NOT EXISTS(SELECT 1 FROM frozen_construction_input_defs i WHERE i.content_snapshot_id=r.content_snapshot_id AND i.project_id=r.project_id AND i.stage_index=r.stage_index AND i.item_id=r.item_id AND i.delivery_station_id=r.station_id))))) THEN RAISE(ABORT,'invalid construction receipt') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_evidence_state e JOIN exploration_claim_state c USING(snapshot_id,world_id,content_snapshot_id,player_id,event_id,generation)
 JOIN frozen_campaign_event_defs d USING(content_snapshot_id,event_id) WHERE e.snapshot_id=NEW.snapshot_id AND (e.project_id<>d.project_id OR e.units<>CASE WHEN c.outcome='full' THEN d.full_units ELSE d.partial_units END)) THEN RAISE(ABORT,'construction evidence lacks actual exploration outcome') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_run_state r JOIN frozen_expedition_route_defs d USING(content_snapshot_id,route_id)
 JOIN frozen_campaign_balance_defs b USING(content_snapshot_id) WHERE r.snapshot_id=NEW.snapshot_id AND (
 r.fee_paid_credit<>d.start_fee_credit OR r.focus_bonus_bp NOT IN(10000,b.focus_bonus_bp) OR r.started_tick>NEW.simulation_tick OR r.finished_tick>NEW.simulation_tick OR
 (SELECT count(*) FROM expedition_stage_state s WHERE s.snapshot_id=r.snapshot_id AND s.run_id=r.run_id)<>r.stage_index OR
 (SELECT count(*) FROM expedition_receipt_state x WHERE x.snapshot_id=r.snapshot_id AND x.run_id=r.run_id AND x.action_kind='start')<>1 OR
 r.bonus_credit_total<>(SELECT coalesce(sum(s.bonus_credit),0) FROM expedition_stage_state s WHERE s.snapshot_id=r.snapshot_id AND s.run_id=r.run_id) OR
 r.bonus_insight_total<>(SELECT coalesce(sum(s.bonus_insight),0) FROM expedition_stage_state s WHERE s.snapshot_id=r.snapshot_id AND s.run_id=r.run_id) OR
 (r.phase IN('active','checkpoint','returning') AND r.finished_tick<>0) OR
 (r.phase IN('completed','withdrawn','failed') AND r.finished_tick<r.started_tick))) THEN RAISE(ABORT,'invalid expedition sequence or totals') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_stage_state s JOIN expedition_run_state r USING(snapshot_id,world_id,content_snapshot_id,run_id)
 LEFT JOIN frozen_expedition_option_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.route_id=r.route_id AND d.stage_index=s.stage_index AND d.option_id=s.option_id
 LEFT JOIN exploration_claim_state c ON c.snapshot_id=s.snapshot_id AND c.event_id=s.event_id AND c.generation=s.event_generation
 JOIN frozen_campaign_balance_defs b ON b.content_snapshot_id=s.content_snapshot_id
 WHERE s.snapshot_id=NEW.snapshot_id AND (d.option_id IS NULL OR d.event_id<>s.event_id OR s.stage_index>r.stage_index OR
 (s.settled=0 AND (s.bonus_credit<>0 OR s.bonus_insight<>0 OR s.outcome<>'')) OR
 (s.settled=1 AND (c.event_id IS NULL OR s.outcome<>c.outcome OR
 s.bonus_credit<>CAST(d.bonus_credit*r.focus_bonus_bp/10000.0*CASE WHEN c.outcome='full' THEN 1.0 ELSE b.partial_bonus_bp/10000.0 END AS INTEGER) OR
 s.bonus_insight<>CAST(d.bonus_insight*r.focus_bonus_bp/10000.0*CASE WHEN c.outcome='full' THEN 1.0 ELSE b.partial_bonus_bp/10000.0 END AS INTEGER))))) THEN RAISE(ABORT,'expedition stage lacks exact claimed result') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_receipt_state r JOIN frozen_construction_project_defs p USING(content_snapshot_id,project_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND r.action_kind='start' AND (r.station_id<>p.station_id OR
 EXISTS(SELECT 1 FROM frozen_construction_input_defs d LEFT JOIN construction_input_state i ON i.snapshot_id=r.snapshot_id AND i.project_id=d.project_id AND i.stage_index=d.stage_index AND i.item_id=d.item_id AND i.delivery_station_id=d.delivery_station_id
 WHERE d.content_snapshot_id=r.content_snapshot_id AND d.project_id=r.project_id AND d.stage_index=r.stage_index AND coalesce(i.delivered_units,0)<d.required_units) OR
 (r.stage_index=3 AND (SELECT coalesce(sum(e.units),0) FROM construction_evidence_state e WHERE e.snapshot_id=r.snapshot_id AND e.project_id=r.project_id)<p.required_evidence_units))) THEN RAISE(ABORT,'construction started without complete inputs or evidence') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_receipt_state x JOIN expedition_run_state r USING(snapshot_id,world_id,content_snapshot_id,run_id)
 LEFT JOIN expedition_stage_state s USING(snapshot_id,world_id,content_snapshot_id,run_id,stage_index)
 WHERE x.snapshot_id=NEW.snapshot_id AND (x.event_tick>NEW.simulation_tick OR
 (x.action_kind='start' AND (x.stage_index<>1 OR x.paid_credit<>r.fee_paid_credit OR x.bonus_credit<>0 OR x.bonus_insight<>0)) OR
 (x.action_kind='stage' AND (s.run_id IS NULL OR s.settled<>1 OR x.paid_credit<>0 OR x.bonus_credit<>s.bonus_credit OR x.bonus_insight<>s.bonus_insight)) OR
 (x.action_kind IN('withdraw','complete','fail') AND (x.paid_credit<>0 OR x.bonus_credit<>0 OR x.bonus_insight<>0 OR x.event_tick<>r.finished_tick OR x.stage_index<>r.stage_index OR
 x.action_kind<>CASE r.phase WHEN 'withdrawn' THEN 'withdraw' WHEN 'completed' THEN 'complete' WHEN 'failed' THEN 'fail' ELSE '' END)))) THEN RAISE(ABORT,'expedition receipt has no entitlement') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_stage_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.settled=1 AND
 (SELECT count(*) FROM expedition_receipt_state x WHERE x.snapshot_id=s.snapshot_id AND x.run_id=s.run_id AND x.stage_index=s.stage_index AND x.action_kind='stage')<>1) THEN RAISE(ABORT,'missing expedition stage payment') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_run_state r WHERE r.snapshot_id=NEW.snapshot_id AND
 (SELECT count(*) FROM expedition_receipt_state x WHERE x.snapshot_id=r.snapshot_id AND x.run_id=r.run_id AND x.action_kind IN('withdraw','complete','fail'))<>CASE WHEN r.phase IN('completed','withdrawn','failed') THEN 1 ELSE 0 END) THEN RAISE(ABORT,'missing or duplicate expedition outcome') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_campaign_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 ((SELECT count(*) FROM construction_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_construction_project_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM construction_input_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_construction_input_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM expedition_route_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_expedition_route_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM campaign_director_state WHERE snapshot_id=NEW.snapshot_id)<>1 OR (SELECT count(*) FROM telemetry_total_state WHERE snapshot_id=NEW.snapshot_id)<>1) THEN RAISE(ABORT,'campaign initial coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM flight_record_state r WHERE r.snapshot_id=NEW.snapshot_id AND
 (r.started_tick>NEW.simulation_tick OR r.finished_tick>NEW.simulation_tick OR r.combat_s>r.elapsed_s OR r.transit_s>r.elapsed_s OR
 r.credit_last<>r.credit_start+r.flight_income+r.return_income-r.flight_spent-r.return_spent OR
 (r.phase='active' AND r.finished_tick<>0) OR (r.phase<>'active' AND r.finished_tick<r.started_tick))) THEN RAISE(ABORT,'invalid measured outing summary') END;
 SELECT CASE WHEN (SELECT count(*) FROM flight_record_state WHERE snapshot_id=NEW.snapshot_id)>(SELECT report_limit FROM frozen_campaign_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN RAISE(ABORT,'outing reports exceed retention') END;
END;'''

def main():
 db=sqlite3.connect(':memory:');source=sqlite3.connect((ROOT/'code/data/catalog_situational_v20.db').as_uri()+'?mode=ro',uri=True);source.backup(db);source.close()
 for file in ['campaign_schema.sql','campaign_theme_seed.sql','campaign_seed.sql']:db.executescript((ROOT/'code/database'/file).read_text('utf-8'))
 parts=['-- Durable offline expeditions, construction and measured outing summaries.']+[frozen_table_sql(db,t) for t in TABLES]
 for table,(key,columns,foreign) in STATES.items():
  suffix=','+foreign if foreign else ''
  parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE{suffix}) STRICT;''')
  for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
   guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
   if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
   parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
 legacy=' OR '.join(f'EXISTS(SELECT 1 FROM {t} WHERE snapshot_id=NEW.snapshot_id)' for t in STATES)
 parts.append(f"CREATE TRIGGER campaign_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_campaign_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND ({legacy}) BEGIN SELECT RAISE(ABORT,'campaign state under legacy rules'); END;")
 parts.append("CREATE UNIQUE INDEX construction_stage_payment_once ON construction_receipt_state(snapshot_id,world_id,content_snapshot_id,project_id,stage_index) WHERE action_kind='start';")
 parts.append("CREATE UNIQUE INDEX expedition_one_active ON expedition_run_state(snapshot_id,world_id,content_snapshot_id) WHERE phase IN('active','checkpoint','returning');")
 parts.append("CREATE UNIQUE INDEX expedition_stage_receipt_once ON expedition_receipt_state(snapshot_id,world_id,content_snapshot_id,run_id,stage_index) WHERE action_kind='stage';")
 parts.append("CREATE UNIQUE INDEX flight_one_active ON flight_record_state(snapshot_id,world_id,content_snapshot_id) WHERE phase='active';")
 parts.append("CREATE UNIQUE INDEX expedition_start_once ON expedition_receipt_state(snapshot_id,world_id,content_snapshot_id,run_id) WHERE action_kind='start';")
 parts.append("CREATE UNIQUE INDEX expedition_terminal_once ON expedition_receipt_state(snapshot_id,world_id,content_snapshot_id,run_id) WHERE action_kind IN('withdraw','complete','fail');")
 parts.append("CREATE UNIQUE INDEX flight_sequence_unique ON flight_record_state(snapshot_id,world_id,content_snapshot_id,sequence);")
 prior=sqlite3.connect(':memory:')
 for path in sorted((ROOT/'code/database/progress').glob('*.sql')):
  if path.name[:3].isdigit() and int(path.name[:3])<=24:prior.executescript(path.read_text('utf-8'))
 trigger=prior.execute("SELECT sql FROM sqlite_schema WHERE type='trigger' AND name='exploration_context_seal_validation'").fetchone()[0]
 before="p.insight_earned<>coalesce((SELECT sum(c.insight_units) FROM exploration_claim_state c WHERE c.snapshot_id=p.snapshot_id AND c.player_id=p.player_id),0)"
 after=before+"+coalesce((SELECT sum(s.bonus_insight) FROM expedition_stage_state s WHERE s.snapshot_id=p.snapshot_id AND s.settled=1),0)"
 assert trigger.count(before)==1
 parts.append('DROP TRIGGER exploration_context_seal_validation;\n'+trigger.replace(before,after)+';')
 prior.close()
 parts.append(SEAL)
 parts.append('''CREATE TABLE database_meta_format22(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=22)) STRICT;
INSERT INTO database_meta_format22 SELECT singleton,application_id,22 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format22 RENAME TO database_meta;PRAGMA user_version=22;''')
 (ROOT/'code/database/progress/025_campaign.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
 adapter=['-- Reviewed schema20 offline campaign adapter.\nPRAGMA foreign_keys=ON;']
 for kind in ['table','view']:adapter += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type=? AND name NOT LIKE 'sqlite_%' ORDER BY name",(kind,))]
 (ROOT/'code/database/progress/catalog_adapter_v0_21.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n');db.close()

if __name__=='__main__':main()
