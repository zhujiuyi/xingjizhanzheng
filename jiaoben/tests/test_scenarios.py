"""Independent rules, frozen-history and hostile snapshot checks for S24/S27/S28."""
from pathlib import Path
import hashlib, sqlite3, subprocess, sys, unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
from scenario_catalog import EXTENSIONS

class ScenarioSql(unittest.TestCase):
 def setUp(self):
  self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
  self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db)
  self.initial,self.content=p.new_world(self.db,self.source)
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'scenarios','world-a',self.content,100)
  p.copy_state(self.db,self.initial,'scenarios','world-a',self.content)
  self.ctx=p.context('scenarios','world-a',self.content)
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='scenarios'")
 def test_new_world_complete_and_empty_of_free_results(self):
  self.assertEqual(len(p.STATE_TABLES),114);self.assertEqual(self.db.execute('PRAGMA user_version').fetchone(),(p.FORMAT_VERSION,))
  for table,count in [('trial_state',3),('blockade_state',3),('blockade_node_state',12),('telemetry_timing_state',1),('trial_result_state',0),('blockade_result_state',0),('tactical_award_state',0),('activity_total_state',0)]:
   self.assertEqual(self.db.execute('SELECT count(*) FROM '+table+" WHERE snapshot_id='scenarios'").fetchone(),(count,))
  self.seal()
 def test_old_155_definitions_and_four_views_unchanged(self):
  from fleet_catalog import EXTENSIONS as FLEET_EXTENSIONS
  archive=ROOT/'code/data/catalog_campaign_v21.db'
  self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(),'bd691ebb7c2c75e409d71b7c19f5e6e4c9a8b49c0993901d482d29f690bc9612')
  old=sqlite3.connect(archive.as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  for table, in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name!='catalog_meta'"):
   with self.subTest(table=table):
    self.assertEqual(old.execute('SELECT sql FROM sqlite_schema WHERE name=?',(table,)).fetchone(),self.source.execute('SELECT sql FROM sqlite_schema WHERE name=?',(table,)).fetchone())
    columns=list(old.execute('PRAGMA table_info("'+table+'")'));keys=[i for i,r in enumerate(columns) if r[5]]
    before={tuple(row[i] for i in keys):row for row in old.execute('SELECT * FROM "'+table+'"')}
    for row in self.source.execute('SELECT * FROM "'+table+'"'):
     key=tuple(row[i] for i in keys)
     if key in before:self.assertEqual(before.pop(key),row)
     elif table in FLEET_EXTENSIONS and str(row[[r[1] for r in columns].index(FLEET_EXTENSIONS[table][0])]).startswith(FLEET_EXTENSIONS[table][1]):pass
     else:
      self.assertIn(table,EXTENSIONS)
      self.assertTrue(str(key[0]).startswith(('trial_','blockade_')),key)
    self.assertFalse(before)
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.source.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
 def test_published_migrations_and_adapters_byte_exact(self):
  for name in subprocess.check_output(['git','ls-tree','-r','--name-only','3b68352','code/database/progress'],cwd=ROOT,text=True).splitlines():
   if not name.endswith('.sql'):continue
   path=ROOT/name
   self.assertEqual(path.read_bytes(),subprocess.check_output(['git','show','3b68352:'+path.relative_to(ROOT).as_posix()],cwd=ROOT),path.name)
 def test_unpaid_trial_generation_rejected(self):
  self.db.execute("UPDATE trial_state SET generation=1,phase='accepted' WHERE snapshot_id='scenarios' AND trial_id='trial_precision'")
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_invented_title_rejected(self):
  p.insert(self.db,'tactical_award_state',{**self.ctx,'award_id':'award_precision','earned_tick':1})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'award|result'):self.seal()
 def test_unbacked_cargo_rejected(self):
  self.db.execute("UPDATE blockade_state SET cargo_units=1 WHERE snapshot_id='scenarios' AND blockade_id='blockade_echo'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'blockade|cargo'):self.seal()
 def test_missing_node_generation_rejected(self):
  self.db.execute("UPDATE blockade_node_state SET generation=1 WHERE snapshot_id='scenarios' AND blockade_id='blockade_echo'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'generation'):self.seal()
 def test_unknown_reason_and_menu_names_cannot_store_arbitrary_text(self):
  with self.assertRaises(sqlite3.IntegrityError):
   p.insert(self.db,'activity_total_state',{**self.ctx,'activity_kind':'mission','outcome':'failed','reason_code':'unrelated private text','occurrences':1,'elapsed_s':0})
  with self.assertRaises(sqlite3.IntegrityError):
   p.insert(self.db,'telemetry_menu_state',{**self.ctx,'page_id':'C:/unrelated/path'})
 def test_finished_history_requires_lifetime_totals(self):
  p.insert(self.db,'activity_record_state',{**self.ctx,'record_id':'test','activity_kind':'mission','object_id':'fixture','phase':'finished','outcome':'withdrawn','reason_code':'manual','started_tick':1,'finished_tick':100,'elapsed_s':1})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'lifetime'):self.seal()
 def test_measurement_future_ticks_rejected(self):
  p.insert(self.db,'activity_record_state',{**self.ctx,'record_id':'test','activity_kind':'mission','object_id':'fixture','phase':'active','started_tick':101})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'activity time'):self.seal()
 def test_sealed_new_state_is_immutable(self):
  self.seal()
  for table,column in [('trial_state','generation'),('blockade_state','loaded_units'),('blockade_node_state','generation'),('telemetry_timing_state','navigation_wait_s')]:
   with self.subTest(table=table),self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):
    self.db.execute(f"UPDATE {table} SET {column}={column}+1 WHERE snapshot_id='scenarios'")

if __name__=='__main__':unittest.main()
