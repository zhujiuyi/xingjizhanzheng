from catalog_review import without_frontier_extensions
"""Independent SQL rejection cases for commander proofs and old-rule preservation."""
from pathlib import Path
import hashlib,sqlite3,subprocess,sys,unittest
from unittest import mock
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
import honors_catalog

class HonorDefinitions(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.db.close)
 def test_all_135_previous_definitions_and_views_are_exact(self):
  path=ROOT/'code/data/catalog_roles_v16.db'
  self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),'3f411d12d09b62db8b0122a12e89dca74d44b2c7d92c72fe8569b6b188f636df')
  old=sqlite3.connect(path.as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
   self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(),self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
   self.assertEqual(set(old.execute(f'SELECT * FROM "{table}"')),without_frontier_extensions(self.db,table,set(self.db.execute(f'SELECT * FROM "{table}"'))),table)
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
 def test_four_real_sources_for_each_of_three_civilizations(self):
  honors_catalog.validate(self.db)
  self.assertEqual(self.db.execute('SELECT count(*) FROM civilization_command_defs').fetchone(),(3,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM civilization_honor_task_defs').fetchone(),(12,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM civilization_honor_source_defs').fetchone(),(21,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM ship_defs').fetchone(),(18,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM module_defs').fetchone(),(42,))
 def test_021_fault_rolls_back_real_format17_schema(self):
  db=p.connect();self.addCleanup(db.close)
  with mock.patch.object(p,'MIGRATIONS',p.MIGRATIONS[:20]),mock.patch.object(p,'FORMAT_VERSION',17):p.apply_migrations(db)
  before=db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall()
  with self.assertRaises(sqlite3.OperationalError):p.apply_migrations(db,fault_after=21)
  self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(17,))
  self.assertEqual(before,db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall())
  p.apply_migrations(db)
  self.assertEqual(db.execute('PRAGMA user_version').fetchone(),(p.FORMAT_VERSION,))
 def test_old_migrations_and_adapters_remain_the_published_bytes(self):
  for path in sorted((ROOT/'code/database/progress').glob('*.sql')):
   if path.name.startswith(('021_','022_')) or path.name in ('catalog_adapter_v0_17.sql','catalog_adapter_v0_18.sql'):continue
   old=subprocess.check_output(['git','show','8bd08141459cbd8ab82607954aff621a83318ab8:'+path.relative_to(ROOT).as_posix()],cwd=ROOT)
   self.assertEqual(path.read_bytes(),old,path.name)
 def test_core_only_dto_generator_cannot_delete_expanded_groups(self):
  path=ROOT/'code/contracts/contract_dtos.gd';before=path.read_bytes()
  result=subprocess.run([sys.executable,str(ROOT/'jiaoben/sync_contract_state_dtos.py')],cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  self.assertNotEqual(result.returncode,0)
  self.assertIn(b'Core-only generator',result.stderr)
  self.assertEqual(path.read_bytes(),before)

class HonorSealing(unittest.TestCase):
 def setUp(self):
  self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
  self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db)
  self.initial,self.content=p.new_world(self.db,self.source)
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'honor-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'honor-candidate','world-a',self.content)
  self.ctx=p.context('honor-candidate','world-a',self.content)
  self.faction='faction_route_council';self.task='honor_'+self.faction+'_scout'
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='honor-candidate'")
 def command(self,**values):
  self.db.execute('UPDATE civilization_command_state SET '+','.join(k+'=?' for k in values)+" WHERE snapshot_id='honor-candidate' AND faction_id=?",(*values.values(),self.faction))
 def evidence(self,**values):
  row={**self.ctx,'source_token':'exploration:exp_mirror_relic:1','task_id':self.task,'source_kind':'exploration','source_def_id':'exp_mirror_relic','generation':1,'credited_units':1,'recorded_tick':0}
  row.update(values);p.insert(self.db,'civilization_honor_evidence_state',row)
 def test_initial_world_has_no_free_proofs_or_qualification(self):
  self.assertEqual(len(p.STATE_TABLES),68)
  self.assertEqual(self.db.execute("SELECT count(*),sum(paid_credit),sum(awarded_reputation) FROM civilization_command_state WHERE snapshot_id='honor-candidate' AND phase='unregistered'").fetchone(),(3,0,0))
  self.assertEqual(self.db.execute("SELECT count(*) FROM civilization_honor_evidence_state WHERE snapshot_id='honor-candidate'").fetchone(),(0,))
  self.seal()
 def test_missing_civilization_examination_cannot_seal(self):
  self.db.execute("DELETE FROM civilization_command_state WHERE snapshot_id='honor-candidate' AND faction_id=?",(self.faction,))
  with self.assertRaisesRegex(sqlite3.IntegrityError,'coverage'):self.seal()
 def test_certification_cannot_be_substituted_by_reputation(self):
  d=p.rows(self.source,'civilization_command_defs','faction_id=?',(self.faction,))[0]
  self.command(phase='certified',paid_credit=d['reward_credit'],awarded_reputation=d['reward_reputation'])
  with self.assertRaisesRegex(sqlite3.IntegrityError,'four abilities'):self.seal()
 def test_claim_requires_an_actual_complete_exploration_receipt(self):
  self.command(phase='assessing');self.evidence()
  with self.assertRaisesRegex(sqlite3.IntegrityError,'full settled'):self.seal()
 def test_wrong_task_cannot_use_an_unrelated_source(self):
  self.command(phase='assessing');self.evidence(task_id='honor_'+self.faction+'_combat')
  with self.assertRaisesRegex(sqlite3.IntegrityError,'not authorized'):self.seal()
 def test_proofs_before_registration_cannot_seal(self):
  self.db.execute("UPDATE save_snapshot SET simulation_tick=2 WHERE snapshot_id='honor-candidate'")
  self.command(phase='assessing',registered_tick=1);self.evidence()
  with self.assertRaisesRegex(sqlite3.IntegrityError,'precedes registration'):self.seal()
 def test_same_source_cannot_be_reused_for_another_civilization(self):
  self.command(phase='assessing');self.evidence()
  with self.assertRaises(sqlite3.IntegrityError):self.evidence(task_id='honor_faction_deepforge_scout')
 def test_progress_cannot_exceed_the_real_task(self):
  self.command(phase='assessing');self.evidence(credited_units=2)
  with self.assertRaisesRegex(sqlite3.IntegrityError,'exceeds'):self.seal()
 def test_incomplete_examination_cannot_pay(self):
  self.command(phase='assessing',paid_credit=1)
  with self.assertRaisesRegex(sqlite3.IntegrityError,'payment'):self.seal()
 def test_sealed_examination_cannot_be_rewritten(self):
  self.seal()
  with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.command(phase='assessing')

if __name__=='__main__':unittest.main()
