"""Measurement FK/immutability and totals; never use any user progress file."""
from pathlib import Path
import sqlite3,subprocess,sys,unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p

class MetricSql(unittest.TestCase):
 def setUp(self):
  self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
  self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db)
  self.initial,self.cid=p.new_world(self.db,self.source)
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON');p.begin_snapshot(self.db,'metric','world-a',self.cid,10);p.copy_state(self.db,self.initial,'metric','world-a',self.cid)
  self.ctx=p.context('metric','world-a',self.cid)
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='metric'")
 def outing(self):
  hull=self.source.execute('SELECT ship_id FROM ship_defs LIMIT 1').fetchone()[0]
  p.insert(self.db,'flight_record_state',{**self.ctx,'record_id':'report','sequence':1,'ship_def_id':hull,'phase':'docked','partial_baseline':1,'started_tick':1,'finished_tick':2,'credit_start':5000,'credit_last':5000})
  self.db.execute("UPDATE telemetry_total_state SET next_sequence=2 WHERE snapshot_id='metric'")
 def material(self,total=5,used=5,returned=2):
  p.insert(self.db,'telemetry_material_state',{**self.ctx,'item_id':'material_structural_stock','used_units':total,'returned_units':returned})
  p.insert(self.db,'flight_material_state',{**self.ctx,'record_id':'report','item_id':'material_structural_stock','used_units':used,'returned_units':returned})
 def test_001_025_published_bytes_unchanged(self):
  for path in (ROOT/'code/database/progress').glob('*.sql'):
   if path.name.startswith('026_'):continue
   self.assertEqual(path.read_bytes(),subprocess.check_output(['git','show','2097713:'+path.relative_to(ROOT).as_posix()],cwd=ROOT),path.name)
 def test_empty_new_measurements_and_latest_format(self):
  self.assertEqual(self.db.execute('PRAGMA user_version').fetchone(),(23,));self.assertEqual(len(p.STATE_TABLES),87)
  for table in ['flight_material_state','telemetry_material_state','flight_repair_state','telemetry_repair_state']:self.assertEqual(self.db.execute('SELECT count(*) FROM '+table).fetchone(),(0,))
  self.seal()
 def test_realistic_investment_refund_and_repair_summary_seals(self):
  self.outing();self.material()
  p.insert(self.db,'telemetry_repair_state',{**self.ctx,'repair_kind':'station','restored_hp':20.0})
  p.insert(self.db,'flight_repair_state',{**self.ctx,'record_id':'report','repair_kind':'station','restored_hp':20.0});self.seal()
 def test_report_material_cannot_exceed_lifetime_total(self):
  self.outing();self.material(total=4)
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_report_repair_cannot_exceed_lifetime_total(self):
  self.outing();p.insert(self.db,'telemetry_repair_state',{**self.ctx,'repair_kind':'self','restored_hp':10.0});p.insert(self.db,'flight_repair_state',{**self.ctx,'record_id':'report','repair_kind':'self','restored_hp':11.0})
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_repair_kind_is_bounded(self):
  with self.assertRaises(sqlite3.IntegrityError):p.insert(self.db,'telemetry_repair_state',{**self.ctx,'repair_kind':'fabricated','restored_hp':10.0})
 def test_retained_repairs_together_cannot_exceed_lifetime_total(self):
  self.outing()
  hull=self.source.execute('SELECT ship_id FROM ship_defs LIMIT 1').fetchone()[0]
  p.insert(self.db,'flight_record_state',{**self.ctx,'record_id':'report2','sequence':2,'ship_def_id':hull,'phase':'docked','partial_baseline':1,'started_tick':2,'finished_tick':3,'credit_start':5000,'credit_last':5000})
  self.db.execute("UPDATE telemetry_total_state SET next_sequence=3 WHERE snapshot_id='metric'")
  p.insert(self.db,'telemetry_repair_state',{**self.ctx,'repair_kind':'self','restored_hp':10.0})
  for report in ['report','report2']:p.insert(self.db,'flight_repair_state',{**self.ctx,'record_id':report,'repair_kind':'self','restored_hp':6.0})
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_orphan_report_detail_is_visible_to_foreign_key_validation(self):
  p.insert(self.db,'telemetry_material_state',{**self.ctx,'item_id':'material_structural_stock','used_units':5})
  p.insert(self.db,'flight_material_state',{**self.ctx,'record_id':'missing','item_id':'material_structural_stock','used_units':5})
  self.assertTrue(self.db.execute('PRAGMA foreign_key_check').fetchall())
 def test_sealed_measurements_are_immutable(self):
  self.outing();self.material();self.seal()
  for table in ['flight_material_state','telemetry_material_state']:
   with self.subTest(table=table),self.assertRaises(sqlite3.IntegrityError):self.db.execute(f"UPDATE {table} SET used_units=used_units+1 WHERE snapshot_id='metric'")

if __name__=='__main__':unittest.main()
