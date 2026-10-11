"""Protect historical definitions, atomic upgrade and objective cargo/result boundaries."""
from pathlib import Path
import sqlite3
import sys
import unittest
from catalog_review import without_later_extensions
from unittest import mock
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
import operations_catalog

class OperationDefinitions(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.db.close)
 def test_preserve_every_v13_row_schema_and_view(self):
  old=sqlite3.connect((ROOT/'code/data/catalog_tactics_v13.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  self.assertEqual(p.adapter_hash(old),'597f1239d3ddf80697e2b1f9a519ac32d653ee72156a256fe578b2ecb8e5f09c')
  extend={'anchor_defs','anchor_site_defs','npc_archetype_defs','npc_resistances','npc_behavior_defs','npc_defs','npc_spawn_defs','npc_patrol_points'}
  for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
   self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(),self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
   before=set(old.execute(f'SELECT * FROM "{table}"'));after=set(self.db.execute(f'SELECT * FROM "{table}"'))
   self.assertLessEqual(before,after,table)
   after = without_later_extensions(self.db, table, after)
   if table not in extend:self.assertEqual(before,after,table)
   else:
    key=next(i for i,r in enumerate(old.execute(f'PRAGMA table_info("{table}")')) if r[5]==1)
    self.assertTrue(all(r[key].startswith('op_') for r in after-before),table)
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
  operations_catalog.validate(self.db)
 def test_018_failure_preserves_format14_and_retries(self):
  db=p.connect();self.addCleanup(db.close)
  with mock.patch.object(p,'MIGRATIONS',p.MIGRATIONS[:17]),mock.patch.object(p,'FORMAT_VERSION',14):p.apply_migrations(db)
  before=db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall()
  with self.assertRaises(sqlite3.OperationalError):p.apply_migrations(db,fault_after=18)
  self.assertEqual(before,db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall())
  self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(14,))
  p.apply_migrations(db);self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(p.FORMAT_VERSION,))

class OperationSealing(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
  cls.db=p.connect();p.apply_migrations(cls.db);cls.initial,cls.content=p.new_world(cls.db,cls.source)
 @classmethod
 def tearDownClass(cls):cls.db.close();cls.source.close()
 def setUp(self):
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'operation-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'operation-candidate','world-a',self.content)
 def tearDown(self):self.db.rollback()
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='operation-candidate'")
 def set_op(self, values, id='op_breakthrough'):
  self.db.execute('UPDATE operation_state SET '+','.join(k+'=?' for k in values)+" WHERE snapshot_id='operation-candidate' AND operation_id=?",(*values.values(),id))
 def cargo(self,units=1):
  self.db.execute("UPDATE ship_state SET status='flying',station_id=NULL WHERE snapshot_id='operation-candidate' AND ship_instance_id='ship-guarantee'")
  self.db.execute("UPDATE player_state SET docked_station_id=NULL WHERE snapshot_id='operation-candidate'")
  self.set_op(dict(generation=1,phase='active',remaining_s=200.,payload_ship_id='ship-guarantee',loaded_units=units,cargo_units=units))
 def test_missing_operation_cannot_seal(self):
  self.db.execute("DELETE FROM operation_state WHERE snapshot_id='operation-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'coverage'):self.seal()
 def test_active_cargo_requires_flying_ship(self):
  self.cargo();self.db.execute("UPDATE ship_state SET status='docked',station_id='station_anchor_port' WHERE snapshot_id='operation-candidate' AND ship_instance_id='ship-guarantee'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'flying owner'):self.seal()
 def test_cargo_cannot_be_lost_without_ledger(self):
  self.cargo();self.set_op(dict(cargo_units=0))
  with self.assertRaisesRegex(sqlite3.IntegrityError,'ledger invalid'):self.seal()
 def test_small_ship_cannot_seal_two_large_batches(self):
  self.cargo(2)
  with self.assertRaisesRegex(sqlite3.IntegrityError,'real hold|mass budget'):self.seal()
 def test_objective_and_ordinary_mass_share_one_budget(self):
  self.cargo()
  item=self.source.execute("SELECT item_id,unit_mass_kg,unit_volume_l FROM item_defs WHERE item_type='ore' ORDER BY unit_mass_kg/unit_volume_l DESC LIMIT 1").fetchone()
  qty=int(2100/item[1])+1
  p.insert(self.db,'inventory_stack_state',{**p.context('operation-candidate','world-a',self.content),'stack_id':'mass-fixture','container_id':'hold-cargo','item_def_id':item[0],'quantity':qty,'origin_kind':'normal','policy_id':'normal_owned'})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'mass budget'):self.seal()
 def test_reward_requires_matching_paid_ledger(self):
  self.set_op(dict(paid_credit_total=1800))
  with self.assertRaisesRegex(sqlite3.IntegrityError,'ledger invalid'):self.seal()
 def test_fake_demolition_progress_rejected(self):
  self.set_op(dict(generation=1,phase='ready',completed_units=1),'op_demolition')
  with self.assertRaisesRegex(sqlite3.IntegrityError,'actual structures'):self.seal()
 def test_current_state_and_definitions_remain_immutable(self):
  self.seal()
  with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.db.execute("UPDATE operation_state SET generation=1 WHERE snapshot_id='operation-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.db.execute("DELETE FROM frozen_operation_defs WHERE content_snapshot_id=?",(self.content,))
if __name__=='__main__':unittest.main()
