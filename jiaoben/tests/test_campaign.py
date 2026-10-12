"""Independent SQL entitlement and legacy-preservation checks for the batch."""
from pathlib import Path
import hashlib,sqlite3,subprocess,sys,unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
from campaign_catalog import EXTENSIONS

class CampaignSql(unittest.TestCase):
 def setUp(self):
  self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
  self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db)
  self.initial,self.content=p.new_world(self.db,self.source)
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'campaign','world-a',self.content,10);p.copy_state(self.db,self.initial,'campaign','world-a',self.content)
  self.ctx=p.context('campaign','world-a',self.content)
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='campaign'")
 def test_original_147_table_rows_and_views_preserved(self):
  path=ROOT/'code/data/catalog_situational_v20.db'
  self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),'42579bc81283505e92b11f117f6ffd62e7709c8a3a8f96df0005584281fd387a')
  old=sqlite3.connect(path.as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  for table, in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name!='catalog_meta'"):
   with self.subTest(table=table):
    self.assertEqual(old.execute('SELECT sql FROM sqlite_schema WHERE name=?',(table,)).fetchone(),self.source.execute('SELECT sql FROM sqlite_schema WHERE name=?',(table,)).fetchone())
    keys=[r[1] for r in old.execute('PRAGMA table_info("'+table+'")') if r[5]]
    columns=[r[1] for r in old.execute('PRAGMA table_info("'+table+'")')]
    before={tuple(r[columns.index(k)] for k in keys):r for r in old.execute('SELECT * FROM "'+table+'"')}
    for row in self.source.execute('SELECT * FROM "'+table+'"'):
     key=tuple(row[columns.index(k)] for k in keys)
     if key in before:self.assertEqual(before.pop(key),row)
     else:self.assertIn(table,EXTENSIONS);self.assertTrue(str(key[0]).startswith(('exp_theme_','tac_exp_theme_')))
    self.assertFalse(before)
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.source.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
 def test_published_001_024_and_adapters_are_byte_exact(self):
  for path in (ROOT/'code/database/progress').glob('*.sql'):
   if path.name.startswith(('025_','026_')) or path.name=='catalog_adapter_v0_21.sql':continue
   self.assertEqual(path.read_bytes(),subprocess.check_output(['git','show','f357712:'+path.relative_to(ROOT).as_posix()],cwd=ROOT),path.name)
 def test_new_initial_world_has_no_free_outcomes(self):
  self.assertEqual(self.db.execute('PRAGMA user_version').fetchone(),(23,));self.assertEqual(len(p.STATE_TABLES),87)
  for table in ['expedition_run_state','expedition_receipt_state','construction_receipt_state','construction_evidence_state','flight_record_state']:
   self.assertEqual(self.db.execute('SELECT count(*) FROM '+table).fetchone(),(0,))
  self.seal()
 def test_forged_material_delivery_total_rejected(self):
  self.db.execute("UPDATE construction_input_state SET delivered_units=1 WHERE snapshot_id='campaign' AND project_id='project_frontier_01' AND stage_index=1")
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_unpaid_work_rejected(self):
  self.db.execute("UPDATE construction_state SET phase='working',work_remaining_s=20 WHERE snapshot_id='campaign' AND project_id='project_frontier_01'")
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_paid_work_still_requires_all_finite_materials(self):
  p.insert(self.db,'construction_receipt_state',{**self.ctx,'receipt_id':'fixture','project_id':'project_frontier_01','stage_index':1,'action_kind':'start','station_id':'station_frontier_01','item_id':None,'units':0,'paid_credit':1000,'event_tick':1})
  self.db.execute("UPDATE construction_state SET phase='working',work_remaining_s=20,paid_credit_total=1000 WHERE snapshot_id='campaign' AND project_id='project_frontier_01'")
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_invented_wallet_summary_rejected(self):
  hull=self.source.execute('SELECT ship_id FROM ship_defs LIMIT 1').fetchone()[0]
  p.insert(self.db,'flight_record_state',{**self.ctx,'record_id':'fixture','sequence':1,'ship_def_id':hull,'phase':'active','partial_baseline':1,'started_tick':1,'credit_start':5000,'credit_last':6000})
  self.db.execute("UPDATE telemetry_total_state SET next_sequence=2 WHERE snapshot_id='campaign'")
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_sealed_project_inputs_and_rotations_are_immutable(self):
  self.seal()
  for table,column in [('construction_state','revision'),('construction_input_state','delivered_units'),('campaign_director_state','generation'),('telemetry_total_state','next_sequence')]:
   with self.subTest(table=table),self.assertRaises(sqlite3.IntegrityError):self.db.execute(f"UPDATE {table} SET {column}={column}+1 WHERE snapshot_id='campaign'")

if __name__=='__main__':unittest.main()
