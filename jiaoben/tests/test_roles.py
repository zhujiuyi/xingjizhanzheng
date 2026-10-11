from catalog_review import without_frontier_extensions
"""Independent SQL guards for paid roles, custody, integer finance and history."""
from pathlib import Path
import sqlite3,sys,unittest
from unittest import mock
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
import roles_catalog

class RoleDefinitions(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.db.close)
 def test_all_132_old_schemas_rows_and_views_are_exact(self):
  old=sqlite3.connect((ROOT/'code/data/catalog_fitting_v15.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  self.assertEqual(p.adapter_hash(old),'67062a01b5fac2779b385d27d1bb9988bb49a93dbbc9db01567ff7fea9571409')
  for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
   self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(),self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
   self.assertEqual(set(old.execute(f'SELECT * FROM "{table}"')),without_frontier_extensions(self.db,table,set(self.db.execute(f'SELECT * FROM "{table}"'))),table)
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
 def test_existing_hulls_gain_reviewed_capabilities_without_new_hull_inflation(self):
  roles_catalog.validate(self.db)
  self.assertEqual(self.db.execute('SELECT count(*) FROM ship_defs').fetchone(),(18,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM module_defs').fetchone(),(42,))
  self.assertEqual(self.db.execute('SELECT sum(remote_repair_allowed) FROM ship_role_capability_defs').fetchone(),(2,))
 def test_020_failure_rolls_back_format16_and_all_schema_objects(self):
  db=p.connect();self.addCleanup(db.close)
  with mock.patch.object(p,'MIGRATIONS',p.MIGRATIONS[:19]),mock.patch.object(p,'FORMAT_VERSION',16):p.apply_migrations(db)
  before=db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall()
  with self.assertRaises(sqlite3.OperationalError):p.apply_migrations(db,fault_after=20)
  self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(16,))
  self.assertEqual(before,db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall())
  p.apply_migrations(db);self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(p.FORMAT_VERSION,))

class RoleSealing(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
  cls.db=p.connect();p.apply_migrations(cls.db);cls.initial,cls.content=p.new_world(cls.db,cls.source)
 @classmethod
 def tearDownClass(cls):cls.db.close();cls.source.close()
 def setUp(self):
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'role-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'role-candidate','world-a',self.content)
  self.ctx=p.context('role-candidate','world-a',self.content);self.id='freight_anchor_echo'
  self.d=p.rows(self.source,'consignment_defs','contract_id=?',(self.id,))[0]
 def tearDown(self):self.db.rollback()
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='role-candidate'")
 def normal_ship(self,hull='transport_caravan'):
  spec=p.rows(self.source,'ship_defs','ship_id=?',(hull,))[0]
  ship=p.rows(self.db,'ship_state',"snapshot_id='role-candidate'")[0].copy()
  ship.update(ship_instance_id='role-ship',ship_def_id=hull,policy_id='normal_owned',**{k:spec[k+'_max'] for k in ['shield','armor','hull','energy']})
  p.insert(self.db,'ship_state',ship)
  template=p.rows(self.db,'container_state',"snapshot_id='role-candidate' AND kind='cargo'")[0]
  for kind in ['cargo']+(['mineral'] if spec['mineral_cargo_l'] else []):
   row=template.copy();row.update(container_id='role-'+kind,ship_instance_id='role-ship',kind=kind)
   if row['ship_def_id'] is not None:row['ship_def_id']=hull
   p.insert(self.db,'container_state',row)
  for slot in p.rows(self.source,'ship_slot_defs','ship_id=?',(hull,)):
   row=template.copy();row.update(container_id=f"role-{slot['slot_type']}-{slot['slot_index']}",kind='slot',ship_instance_id='role-ship',ship_def_id=hull,slot_type=slot['slot_type'],slot_index=slot['slot_index'])
   p.insert(self.db,'container_state',row)
  site=p.rows(self.db,'spatial_state',"snapshot_id='role-candidate' AND entity_kind='ship'")[0]['site_id']
  p.insert(self.db,'spatial_state',{**self.ctx,'entity_kind':'ship','entity_id':'role-ship','site_id':site})
  return spec
 def state(self,**values):
  self.db.execute('UPDATE consignment_state SET '+','.join(k+'=?' for k in values)+" WHERE snapshot_id='role-candidate' AND contract_id=?",(*values.values(),self.id))
 def receipt(self,kind,units,generation=1,paid=0,refunded=0,reward=0,id=None):
  count=self.db.execute("SELECT count(*) FROM consignment_receipt_state WHERE snapshot_id='role-candidate'").fetchone()[0]
  p.insert(self.db,'consignment_receipt_state',{**self.ctx,'receipt_id':id or f'freight-{count}','contract_id':self.id,'generation':generation,'action_kind':kind,'units':units,'paid_credit':paid,'refunded_credit':refunded,'reward_credit':reward})
 def dispatch(self,units=1,hull='transport_caravan'):
  spec=self.normal_ship(hull);paid=self.d['fee_credit']+units*self.d['deposit_per_unit']
  self.state(phase='active',payload_ship_id='role-ship',accepted_units=units,cargo_units=units,remaining_s=self.d['deadline_s'],paid_credit_total=paid)
  self.receipt('dispatch',units,paid=paid)
  return spec
 def test_valid_entrusted_load_is_sealable_and_immutable(self):
  self.dispatch();self.seal()
  with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.state(cargo_units=0)
 def test_missing_freight_record_cannot_seal(self):
  self.db.execute("DELETE FROM consignment_state WHERE snapshot_id='role-candidate' AND contract_id=?",(self.id,))
  with self.assertRaisesRegex(sqlite3.IntegrityError,'coverage'):self.seal()
 def test_free_unreceipted_cargo_cannot_seal(self):
  self.dispatch();self.db.execute("DELETE FROM consignment_receipt_state WHERE snapshot_id='role-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'conservation'):self.seal()
 def test_deposit_and_dispatch_fee_are_required(self):
  self.dispatch();self.db.execute("UPDATE consignment_receipt_state SET paid_credit=paid_credit-1 WHERE snapshot_id='role-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'payment'):self.seal()
 def test_reward_and_refund_cannot_exceed_real_deliveries(self):
  self.dispatch(2);self.receipt('deliver',2);self.receipt('claim',2,refunded=2*self.d['deposit_per_unit']+1,reward=2*self.d['reward_per_unit'])
  self.state(phase='claimed',payload_ship_id=None,cargo_units=0,delivered_units=2,remaining_s=0,cooldown_remaining_s=self.d['cooldown_s'],refunded_credit_total=2*self.d['deposit_per_unit']+1,reward_credit_total=2*self.d['reward_per_unit'])
  with self.assertRaisesRegex(sqlite3.IntegrityError,'payment'):self.seal()
 def test_repeat_claim_has_a_unique_round_key(self):
  self.dispatch();self.receipt('deliver',1);self.receipt('claim',1,refunded=self.d['deposit_per_unit'],reward=self.d['reward_per_unit'])
  with self.assertRaises(sqlite3.IntegrityError):self.receipt('claim',1,refunded=self.d['deposit_per_unit'],reward=self.d['reward_per_unit'])
 def test_real_hold_counts_ordinary_items_and_entrusted_load_together(self):
  spec=self.dispatch(24)
  item=p.rows(self.source,'item_defs','stackable=1 AND unit_volume_l>0 ORDER BY unit_mass_kg/unit_volume_l LIMIT 1')[0]
  units=int((spec['cargo_l']-24*self.d['unit_volume_l'])/item['unit_volume_l'])+1
  p.insert(self.db,'inventory_stack_state',{**self.ctx,'stack_id':'overflow','container_id':'role-cargo','item_def_id':item['item_id'],'quantity':units,'origin_kind':'normal','policy_id':'normal_owned'})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'hold'):self.seal()
 def test_shared_mass_counts_ore_hold_and_entrusted_load(self):
  spec=self.dispatch(1,'miner_anvil')
  item=p.rows(self.source,'item_defs',"item_type='ore' ORDER BY unit_mass_kg/unit_volume_l DESC LIMIT 1")[0]
  units=int((spec['max_payload_mass_kg']-self.d['unit_mass_kg'])/item['unit_mass_kg'])+1
  self.assertLessEqual(units*item['unit_volume_l'],spec['mineral_cargo_l'])
  p.insert(self.db,'inventory_stack_state',{**self.ctx,'stack_id':'mass-overflow','container_id':'role-mineral','item_def_id':item['item_id'],'quantity':units,'origin_kind':'normal','policy_id':'normal_owned'})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'mass budget'):self.seal()
 def test_protected_or_unowned_carriers_cannot_seal(self):
  self.dispatch();self.db.execute("UPDATE ship_state SET policy_id='tutorial_protected' WHERE snapshot_id='role-candidate' AND ship_instance_id='role-ship'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'cargo invalid'):self.seal()
 def test_nonpersisted_self_repair_is_still_blocked_by_the_original_guard(self):
  self.normal_ship('support_weaver')
  item=p.rows(self.db,'item_instance_state',"snapshot_id='role-candidate'")[0].copy()
  recipe=p.rows(self.source,'recipe_defs',"output_item_id='module_shield_lattice_i'")[0]['recipe_id']
  item.update(item_instance_id='unpersisted-repair',item_def_id='module_shield_lattice_i',container_id='role-utility-0',policy_id='normal_owned',origin_kind='purchase',salvage_recipe_id=recipe)
  p.insert(self.db,'item_instance_state',item)
  p.insert(self.db,'equipment_state',{**self.ctx,'slot_container_id':'role-utility-0','item_instance_id':'unpersisted-repair','module_def_id':'module_shield_lattice_i','cooldown_remaining_s':1.,'active_remaining_s':1.,'cycle_paid':1,'enabled':1})
  with self.assertRaisesRegex(sqlite3.IntegrityError,'unfinished interaction'):self.seal()

if __name__=='__main__':unittest.main()
