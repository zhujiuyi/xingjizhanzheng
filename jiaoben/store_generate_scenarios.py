"""Append only 027/schema21 adapter and the new DTO/registry declarations."""
from pathlib import Path
import re,sqlite3
from generate_frozen_schema import frozen_table_sql
from sync_contract_state_dtos import split_columns,class_name
from scenario_catalog import TABLES
from scenario_state_spec import STATES
ROOT=Path(__file__).resolve().parents[1]

SEAL="""CREATE TRIGGER scenario_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_state s WHERE s.snapshot_id=NEW.snapshot_id AND ((s.phase='available')<>(s.generation=0) OR (SELECT count(*) FROM trial_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.trial_id=s.trial_id)<>s.generation-CASE WHEN s.phase IN('accepted','active','ready') THEN 1 ELSE 0 END OR (s.phase IN('accepted','active','ready') AND (s.ship_instance_id IS NULL OR length(s.loadout_signature)<>64 OR NOT EXISTS(SELECT 1 FROM ship_state h JOIN frozen_trial_hull_defs a ON a.content_snapshot_id=h.content_snapshot_id AND a.ship_id=h.ship_def_id WHERE h.snapshot_id=s.snapshot_id AND h.ship_instance_id=s.ship_instance_id AND h.policy_id='normal_owned' AND a.trial_id=s.trial_id))) OR s.award_earned<>EXISTS(SELECT 1 FROM tactical_award_state a JOIN frozen_trial_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.trial_id=s.trial_id WHERE a.snapshot_id=s.snapshot_id AND a.award_id=d.award_id))) THEN RAISE(ABORT,'trial generation binding or award incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_state s WHERE s.snapshot_id=NEW.snapshot_id AND ((s.phase='available')<>(s.generation=0) OR (SELECT count(*) FROM blockade_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.blockade_id=s.blockade_id)<>s.generation-CASE WHEN s.phase IN('accepted','active','ready') THEN 1 ELSE 0 END OR (s.phase='active' AND (s.payload_ship_id IS NULL OR NOT EXISTS(SELECT 1 FROM ship_state h WHERE h.snapshot_id=s.snapshot_id AND h.ship_instance_id=s.payload_ship_id AND h.policy_id='normal_owned' AND h.status='flying'))) OR (s.phase<>'active' AND (s.payload_ship_id IS NOT NULL OR s.cargo_units<>0 OR s.scan_node_index IS NOT NULL OR s.scan_remaining_s<>0)) OR s.award_earned<>EXISTS(SELECT 1 FROM tactical_award_state a JOIN frozen_blockade_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.blockade_id=s.blockade_id WHERE a.snapshot_id=s.snapshot_id AND a.award_id=d.award_id))) THEN RAISE(ABORT,'blockade generation payload or award incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_result_state r JOIN trial_state s USING(snapshot_id,world_id,content_snapshot_id,trial_id) WHERE r.snapshot_id=NEW.snapshot_id AND (r.generation>s.generation OR NOT EXISTS(SELECT 1 FROM frozen_trial_hull_defs a WHERE a.content_snapshot_id=r.content_snapshot_id AND a.trial_id=r.trial_id AND a.ship_id=r.ship_def_id))) THEN RAISE(ABORT,'trial result hull or generation invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_result_state r JOIN blockade_state s USING(snapshot_id,world_id,content_snapshot_id,blockade_id) WHERE r.snapshot_id=NEW.snapshot_id AND r.generation>s.generation) THEN RAISE(ABORT,'blockade result generation invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_state s JOIN frozen_trial_defs d USING(content_snapshot_id,trial_id) WHERE s.snapshot_id=NEW.snapshot_id AND (s.reference_cost>d.budget_credit OR s.remaining_s>d.duration_s OR s.cooldown_remaining_s>d.cooldown_s OR s.paid_credit_total<>s.generation*d.fee_credit OR s.wins<>(SELECT count(*) FROM trial_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.trial_id=s.trial_id AND r.outcome='completed'))) THEN RAISE(ABORT,'invalid trial budget fee or result count') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_result_state r JOIN frozen_trial_defs d USING(content_snapshot_id,trial_id) WHERE r.snapshot_id=NEW.snapshot_id AND (r.reference_cost>d.budget_credit OR r.paid_credit<>d.fee_credit OR r.finished_tick>NEW.simulation_tick OR r.elapsed_s>d.duration_s+1 OR (r.outcome='completed' AND d.objective_kind IN('precision','support') AND r.effective_hp<d.target_hp))) THEN RAISE(ABORT,'trial result differs from accepted rules') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_state s JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE s.snapshot_id=NEW.snapshot_id AND (s.loaded_units>d.target_units OR s.loaded_units<>s.cargo_units+s.completed_units+s.lost_units+s.jettisoned_units OR s.remaining_s>d.duration_s OR s.bypass_remaining_s>d.bypass_window_s OR s.cooldown_remaining_s>d.cooldown_s OR s.paid_credit_total<>s.generation*d.fee_credit OR s.reward_credit_total<>(SELECT coalesce(sum(r.reward_credit),0) FROM blockade_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.blockade_id=s.blockade_id) OR s.rewarded_units_total<>(SELECT coalesce(sum(r.delivered_units),0) FROM blockade_result_state r WHERE r.snapshot_id=s.snapshot_id AND r.blockade_id=s.blockade_id))) THEN RAISE(ABORT,'invalid blockade cargo fee or rewards') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_result_state r JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE r.snapshot_id=NEW.snapshot_id AND (r.loaded_units>d.target_units OR r.paid_credit<>d.fee_credit OR r.reward_credit<>r.delivered_units*d.credit_per_unit OR r.finished_tick>NEW.simulation_tick OR (r.outcome<>'claimed' AND r.delivered_units<>0))) THEN RAISE(ABORT,'blockade settlement lacks actual delivery') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_node_state n JOIN blockade_state s USING(snapshot_id,world_id,content_snapshot_id,blockade_id) WHERE n.snapshot_id=NEW.snapshot_id AND n.generation<>s.generation) THEN RAISE(ABORT,'stale blockade node generation') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM activity_record_state r WHERE r.snapshot_id=NEW.snapshot_id AND (r.started_tick>NEW.simulation_tick OR r.finished_tick>NEW.simulation_tick OR (r.phase='active' AND (r.outcome<>'' OR r.reason_code<>'' OR r.finished_tick<>0)) OR (r.phase='finished' AND (r.outcome='' OR r.finished_tick<r.started_tick)))) THEN RAISE(ABORT,'invalid activity time or outcome') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM activity_record_state r LEFT JOIN activity_total_state t USING(snapshot_id,world_id,content_snapshot_id,activity_kind,outcome,reason_code) WHERE r.snapshot_id=NEW.snapshot_id AND r.phase='finished' AND t.activity_kind IS NULL) THEN RAISE(ABORT,'activity result lacks lifetime measurement') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM activity_total_state t WHERE t.snapshot_id=NEW.snapshot_id AND (t.occurrences<(SELECT count(*) FROM activity_record_state r WHERE r.snapshot_id=t.snapshot_id AND r.phase='finished' AND r.activity_kind=t.activity_kind AND r.outcome=t.outcome AND r.reason_code=t.reason_code) OR t.elapsed_s+0.00001<(SELECT coalesce(sum(r.elapsed_s),0) FROM activity_record_state r WHERE r.snapshot_id=t.snapshot_id AND r.phase='finished' AND r.activity_kind=t.activity_kind AND r.outcome=t.outcome AND r.reason_code=t.reason_code))) THEN RAISE(ABORT,'activity totals below retained results') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_telemetry_policy_defs p WHERE p.content_snapshot_id=NEW.content_snapshot_id AND ((SELECT count(*) FROM activity_record_state r WHERE r.snapshot_id=NEW.snapshot_id AND r.phase='finished')>p.record_limit OR (SELECT count(*) FROM telemetry_timing_state t WHERE t.snapshot_id=NEW.snapshot_id)<>1)) THEN RAISE(ABORT,'invalid bounded activity history or timing singleton') END;
END;"""

def main():
 db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
 assert db.execute('SELECT schema_version FROM catalog_meta').fetchone()==(21,)
 parts=['-- Additive tactical scenarios and local activity measurement; historical SQL unchanged.']
 for table in TABLES:
  parts.append(frozen_table_sql(db,table))
  parts.append(f"CREATE TRIGGER frozen_{table}_immutable_insert BEFORE INSERT ON frozen_{table} WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;")
  for action in ['UPDATE','DELETE']:
   parts.append(f"CREATE TRIGGER frozen_{table}_immutable_{action.lower()} BEFORE {action} ON frozen_{table} WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed content is immutable'); END;")
 for table,(key,columns,foreign) in STATES.items():
  extra=','+foreign if foreign else ''
  parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE{extra}) STRICT;''')
  for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
   guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
   if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
   parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
 legacy=' OR '.join(f'EXISTS(SELECT 1 FROM {t} WHERE snapshot_id=NEW.snapshot_id)' for t in STATES)
 parts.append(f"CREATE TRIGGER scenario_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_trial_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND ({legacy}) BEGIN SELECT RAISE(ABORT,'scenario state under legacy rules'); END;")
 parts.append('CREATE UNIQUE INDEX tactical_award_one_selected ON tactical_award_state(snapshot_id,world_id,content_snapshot_id) WHERE selected=1;')
 parts.append("CREATE UNIQUE INDEX activity_one_open_object ON activity_record_state(snapshot_id,world_id,content_snapshot_id,activity_kind,object_id) WHERE phase='active';")
 # Reissue complete existing guards, adding only the new finite cargo and
 # strongly bound friendly trial actors. Do not rewrite published migrations.
 with sqlite3.connect(':memory:') as prior:
  for historical in sorted((ROOT/'code/database/progress').glob('[0-9][0-9][0-9]_*.sql')):
   if int(historical.name[:3])<=26:prior.executescript(historical.read_text(encoding='utf-8'))
  capacity=prior.execute("SELECT sql FROM sqlite_schema WHERE name='role_payload_validation'").fetchone()[0]
  for old_column,new_column in [('unit_volume_l','cargo_volume_l'),('unit_mass_kg','cargo_mass_kg')]:
   needle=f'(COALESCE((SELECT sum(h.cargo_units*d.{old_column})'
   assert capacity.count(needle)==1
   extra=f'(COALESCE((SELECT sum(b.cargo_units*d.{new_column}) FROM blockade_state b JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE b.snapshot_id=s.snapshot_id AND b.payload_ship_id=s.ship_instance_id),0)+COALESCE((SELECT sum(h.cargo_units*d.{old_column})'
   capacity=capacity.replace(needle,extra)
  parts.append('DROP TRIGGER role_payload_validation;\n'+capacity+';')
  support=prior.execute("SELECT sql FROM sqlite_schema WHERE name='role_seal_validation'").fetchone()[0]
  needle=' OR EXISTS(SELECT 1 FROM exploration_actor_state a WHERE a.snapshot_id=r.snapshot_id'
  assert support.count(needle)==1
  extra=" OR EXISTS(SELECT 1 FROM scenario_actor_state a JOIN trial_state s ON s.snapshot_id=a.snapshot_id AND s.trial_id=a.scenario_id WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND a.scenario_kind='trial' AND a.actor_role IN('escort','patient') AND a.generation=s.generation AND s.phase='active')"+needle
  parts.append('DROP TRIGGER role_seal_validation;\n'+support.replace(needle,extra)+';')
 parts.append(SEAL)
 parts.append('''CREATE TRIGGER scenario_context_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
 BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM trial_state WHERE snapshot_id=NEW.snapshot_id AND phase IN('accepted','active','ready'))+(SELECT count(*) FROM blockade_state WHERE snapshot_id=NEW.snapshot_id AND phase IN('accepted','active','ready'))>1 THEN RAISE(ABORT,'multiple tactical scenarios accepted') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM scenario_actor_state a WHERE a.snapshot_id=NEW.snapshot_id AND
 ((a.scenario_kind='trial' AND NOT EXISTS(SELECT 1 FROM trial_state s JOIN frozen_trial_actor_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.trial_id=s.trial_id JOIN npc_state n ON n.snapshot_id=s.snapshot_id AND n.npc_instance_id=a.npc_instance_id WHERE s.snapshot_id=a.snapshot_id AND s.trial_id=a.scenario_id AND s.phase='active' AND s.generation=a.generation AND d.spawn_id=a.spawn_id AND d.actor_role=a.actor_role AND n.spawn_id=a.spawn_id AND n.generation=a.generation)) OR
 (a.scenario_kind='blockade' AND NOT EXISTS(SELECT 1 FROM blockade_state s JOIN frozen_blockade_actor_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.blockade_id=s.blockade_id JOIN npc_state n ON n.snapshot_id=s.snapshot_id AND n.npc_instance_id=a.npc_instance_id WHERE s.snapshot_id=a.snapshot_id AND s.blockade_id=a.scenario_id AND s.phase='active' AND s.generation=a.generation AND d.spawn_id=a.spawn_id AND d.actor_role=a.actor_role AND n.spawn_id=a.spawn_id AND n.generation=a.generation)))) THEN RAISE(ABORT,'managed scenario actor context invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM trial_state s JOIN frozen_trial_actor_defs d USING(content_snapshot_id,trial_id) WHERE s.snapshot_id=NEW.snapshot_id AND s.phase='active' AND (SELECT count(*) FROM scenario_actor_state a WHERE a.snapshot_id=s.snapshot_id AND a.scenario_kind='trial' AND a.scenario_id=s.trial_id AND a.generation=s.generation AND a.spawn_id=d.spawn_id)<>1) THEN RAISE(ABORT,'active trial actor coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM blockade_state s JOIN frozen_blockade_actor_defs d USING(content_snapshot_id,blockade_id) WHERE s.snapshot_id=NEW.snapshot_id AND s.phase='active' AND (SELECT count(*) FROM scenario_actor_state a WHERE a.snapshot_id=s.snapshot_id AND a.scenario_kind='blockade' AND a.scenario_id=s.blockade_id AND a.generation=s.generation AND a.spawn_id=d.spawn_id)<>1) THEN RAISE(ABORT,'active blockade actor coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM tactical_award_state a WHERE a.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM trial_result_state r JOIN frozen_trial_defs d USING(content_snapshot_id,trial_id) WHERE r.snapshot_id=a.snapshot_id AND d.award_id=a.award_id AND r.outcome='completed') AND NOT EXISTS(SELECT 1 FROM blockade_result_state r JOIN frozen_blockade_defs d USING(content_snapshot_id,blockade_id) WHERE r.snapshot_id=a.snapshot_id AND d.award_id=a.award_id AND r.outcome='claimed' AND r.delivered_units=d.target_units)) THEN RAISE(ABORT,'tactical award lacks full result') END;
 END;''')
 parts.append("""CREATE TABLE database_meta_format24(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=24)) STRICT;
INSERT INTO database_meta_format24 SELECT singleton,application_id,24 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format24 RENAME TO database_meta;PRAGMA user_version=24;""")
 (ROOT/'code/database/progress/027_scenarios.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
 adapter=['-- Reviewed schema21 scenario adapter.\nPRAGMA foreign_keys=ON;']
 for kind in ['table','view']:adapter.extend(r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type=? AND name NOT LIKE 'sqlite_%' ORDER BY name",(kind,)))
 (ROOT/'code/database/progress/catalog_adapter_v0_22.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n')
 db.close()
 append_dtos()

def append_dtos():
 p=ROOT/'code/contracts/contract_dtos.gd';text=p.read_text(encoding='utf-8');declarations=[]
 for table,(_,columns,_) in STATES.items():
  cls=class_name(table)
  if f'class {cls} extends RefCounted:' in text:continue
  lines=[f'class {cls} extends RefCounted:']
  for column in split_columns(columns):
   m=re.match(r'(\w+)\s+(TEXT|INTEGER|REAL)\b(.*)',column,re.S)
   if not m:continue
   name,kind,rest=m.groups()
   if 'NOT NULL' not in rest:lines.append(f'\tvar has_{name}: bool = false')
   typ,default={'TEXT':('String','""'),'INTEGER':('int','0'),'REAL':('float','0.0')}[kind]
   if kind=='INTEGER' and re.search(r'CHECK\('+name+r' IN\(0,1\)\)',rest):typ,default='bool','false'
   lines.append(f'\tvar {name}: {typ} = {default}')
  declarations.append('\n'.join(lines)+'\n')
 text=text.replace('class WorldSnapshotDto extends RefCounted:','\n'.join(declarations)+'\nclass WorldSnapshotDto extends RefCounted:',1)
 for table in STATES:
  field=f'\tvar {table}_rows: Array[{class_name(table)}] = []'
  if field not in text:text=text.replace('class WorldSnapshotDto extends RefCounted:\n','class WorldSnapshotDto extends RefCounted:\n'+field+'\n',1)
 p.write_text(text,encoding='utf-8',newline='\n')
 p=ROOT/'code/runtime/state.gd';text=p.read_text(encoding='utf-8')
 table_start=text.index('= [',text.index('const TABLES'))+3
 table_end=text.index(']',table_start)
 for table in STATES:
  if '"'+table+'"' not in text[table_start:table_end]:text=text[:table_end]+', "'+table+'"'+text[table_end:];table_end=text.index(']',table_start)
 marker='\tmatch table:\n';assert marker in text
 for table in STATES:
  case=f'\t\t"{table}": return Dtos.{class_name(table)}.new()\n'
  if case not in text:text=text.replace(marker,marker+case,1)
 p.write_text(text,encoding='utf-8',newline='\n')

if __name__=='__main__':main()
