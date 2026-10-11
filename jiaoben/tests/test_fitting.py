"""Immutable old balance, equal installation budgets and research escrow invariants."""
from pathlib import Path
import sqlite3,sys,unittest
from unittest import mock
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
import fitting_catalog
class FittingDefinitions(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.db.close)
 def test_three_controls_have_equal_installed_budgets_and_one_exclusion(self):
  fitting_catalog.validate(self.db)
  self.assertEqual(len(set(self.db.execute("SELECT power_pu,cpu_cu,unit_mass_kg,base_ask_credit FROM module_defs JOIN item_defs ON item_id=module_id WHERE module_id LIKE 'module_spec_%'"))),1)
  self.assertEqual(self.db.execute("SELECT count(*) FROM weapon_defs WHERE module_id LIKE 'module_spec_%'").fetchone(),(0,))
 def test_all_127_prior_table_schemas_rows_and_views_preserved(self):
  old=sqlite3.connect((ROOT/'code/data/catalog_operations_v14.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  self.assertEqual(p.adapter_hash(old),'d46b84f07f8239e4a62cffe96e8467f44cc16553bf48fb46b9155e80869749b0')
  allowed={'unlock_defs':('unlock_id','unlock_spec_'),'item_defs':('item_id','module_spec_'),'module_defs':('module_id','module_spec_'),'module_tech_defs':('module_id','module_spec_'),'module_exclusion_groups':('group_id','spec_'),'module_group_members':('module_id','module_spec_'),'recipe_defs':('recipe_id','recipe_spec_'),'recipe_inputs':('recipe_id','recipe_spec_'),'recipe_access_defs':('recipe_id','recipe_spec_'),'module_salvage_recipe_defs':('module_id','module_spec_'),'recycle_outputs':('source_item_id','module_spec_'),'station_stock_defs':('item_id','module_spec_'),'industry_recipe_defs':('blueprint_id','recipe_spec_')}
  for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
   info=old.execute(f'PRAGMA table_info("{table}")').fetchall();self.assertEqual(info,self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
   before=set(old.execute(f'SELECT * FROM "{table}"'));after=set(self.db.execute(f'SELECT * FROM "{table}"'))
   self.assertLessEqual(before,after,table)
   if table not in allowed:self.assertEqual(before,after,table)
   else:
    column,prefix=allowed[table];index=next(i for i,r in enumerate(info) if r[1]==column)
    self.assertTrue(all(row[index].startswith(prefix) for row in after-before),table)
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
 def test_019_failure_preserves_format15_and_retries(self):
  db=p.connect();self.addCleanup(db.close)
  with mock.patch.object(p,'MIGRATIONS',p.MIGRATIONS[:18]),mock.patch.object(p,'FORMAT_VERSION',15):p.apply_migrations(db)
  before=db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall()
  with self.assertRaises(sqlite3.OperationalError):p.apply_migrations(db,fault_after=19)
  self.assertEqual(before,db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall())
  self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(15,))
  p.apply_migrations(db);self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(16,))
class FittingSealing(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
  cls.db=p.connect();p.apply_migrations(cls.db);cls.initial,cls.content=p.new_world(cls.db,cls.source)
 @classmethod
 def tearDownClass(cls):cls.db.close();cls.source.close()
 def setUp(self):
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'fit-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'fit-candidate','world-a',self.content)
  self.ctx=p.context('fit-candidate','world-a',self.content)
 def tearDown(self):self.db.rollback()
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='fit-candidate'")
 def donation(self,points=3):
  p.insert(self.db,'specialization_evidence_state',{**self.ctx,'player_id':'player-local','source_token':'donation-fixture','source_kind':'donation','source_def_id':'material_structural_stock','generation':0,'source_units':points,'awarded_points':points,'material_units':points*10,'paid_credit':points*200})
  self.db.execute("UPDATE specialization_progress_state SET earned_points=?,donated_points=? WHERE snapshot_id='fit-candidate'",(points,points))
 def test_missing_progress_is_rejected(self):
  self.db.execute("DELETE FROM specialization_progress_state WHERE snapshot_id='fit-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'coverage'):self.seal()
 def test_free_evidence_is_rejected(self):
  self.db.execute("UPDATE specialization_progress_state SET earned_points=1 WHERE snapshot_id='fit-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'conservation'):self.seal()
 def test_donation_missing_material_or_fee_is_rejected(self):
  self.donation();self.db.execute("UPDATE specialization_evidence_state SET paid_credit=0 WHERE snapshot_id='fit-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'source or payment'):self.seal()
 def test_partial_research_cannot_omit_its_payment(self):
  self.donation();self.db.execute("UPDATE specialization_progress_state SET spent_points=3 WHERE snapshot_id='fit-candidate'")
  p.insert(self.db,'specialization_research_state',{**self.ctx,'player_id':'player-local','research_id':'spec_burst','invested_points':3,'paid_credit':0,'completed':0,'completed_tick':0})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'research ledger'):self.seal()
 def test_partial_research_cannot_claim_completion(self):
  self.donation();self.db.execute("UPDATE specialization_progress_state SET spent_points=3 WHERE snapshot_id='fit-candidate'")
  p.insert(self.db,'specialization_research_state',{**self.ctx,'player_id':'player-local','research_id':'spec_burst','invested_points':3,'paid_credit':900,'completed':1,'completed_tick':2})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'research ledger'):self.seal()
 def test_valid_partial_research_and_frozen_coefficients_are_immutable(self):
  self.donation();self.db.execute("UPDATE specialization_progress_state SET spent_points=3 WHERE snapshot_id='fit-candidate'")
  p.insert(self.db,'specialization_research_state',{**self.ctx,'player_id':'player-local','research_id':'spec_burst','invested_points':3,'paid_credit':900,'completed':0,'completed_tick':0})
  self.seal()
  with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.db.execute("UPDATE specialization_research_state SET invested_points=4 WHERE snapshot_id='fit-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.db.execute("DELETE FROM frozen_weapon_tuning_defs WHERE content_snapshot_id=?",(self.content,))
 def test_fictitious_exploration_source_is_rejected(self):
  p.insert(self.db,'specialization_evidence_state',{**self.ctx,'player_id':'player-local','source_token':'exploration-fixture','source_kind':'exploration','source_def_id':'exp_echo_rescue','generation':1,'source_units':1,'awarded_points':2,'material_units':0,'paid_credit':0})
  self.db.execute("UPDATE specialization_progress_state SET earned_points=2 WHERE snapshot_id='fit-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'source or payment'):self.seal()
if __name__=='__main__':unittest.main()
