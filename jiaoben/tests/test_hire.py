"""Independent companion catalog preservation, SQL bindings and financial limits."""
from pathlib import Path
import hashlib,sqlite3,subprocess,sys,unittest
from unittest import mock
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
import hire_catalog
from catalog_review import without_campaign_extensions

class HireDefinitions(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.db.close)
 def test_v026_archive_and_all_143_prior_definitions_preserved(self):
  path=ROOT/'code/data/catalog_frontier_v18.db'
  self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),'db5998ecda6535c4fc0930bba6fc38d737a13e88f5313759a21dc0caebaba850')
  old=sqlite3.connect(path.as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
   self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(),self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
   before=set(old.execute(f'SELECT * FROM "{table}"'));after=set(self.db.execute(f'SELECT * FROM "{table}"'));self.assertTrue(before<=after,table)
   after=without_campaign_extensions(self.db,table,after)
   if table in hire_catalog.EXTENSIONS:self.assertTrue(all(str(row[0]).startswith('hire_') for row in after-before),table)
   else:self.assertEqual(before,after,table)
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
 def test_both_roles_have_finite_paid_contracts_and_no_bounties_or_loot(self):
  hire_catalog.validate(self.db)
  self.assertEqual(self.db.execute('SELECT count(*) FROM hire_profile_defs').fetchone(),(2,))
  self.assertEqual(self.db.execute('SELECT sum(s.bounty_enabled),sum(s.loot_enabled) FROM hire_profile_defs h JOIN npc_spawn_defs s USING(spawn_id)').fetchone(),(0,0))
  self.assertEqual(self.db.execute('SELECT count(*) FROM ship_defs').fetchone(),(18,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM module_defs').fetchone(),(46,))
 def test_every_published_sql_and_adapter_keeps_v026_bytes(self):
  for name in subprocess.check_output(['git','ls-tree','-r','--name-only','6e2323e625f542415f3cf959c2ebbf70602fbc3a','code/database/progress'],cwd=ROOT,text=True).splitlines():
   if not name.endswith('.sql'):continue
   path=ROOT/name
   original=subprocess.check_output(['git','show','6e2323e625f542415f3cf959c2ebbf70602fbc3a:'+path.relative_to(ROOT).as_posix()],cwd=ROOT)
   self.assertEqual(path.read_bytes(),original,path.name)
 def test_023_failure_rolls_back_format19_and_entire_schema(self):
  db=p.connect();self.addCleanup(db.close)
  with mock.patch.object(p,'MIGRATIONS',p.MIGRATIONS[:22]),mock.patch.object(p,'FORMAT_VERSION',19):p.apply_migrations(db)
  before=db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall()
  with self.assertRaises(sqlite3.OperationalError):p.apply_migrations(db,fault_after=23)
  self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(19,))
  self.assertEqual(before,db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall())
  p.apply_migrations(db);self.assertEqual(db.execute('PRAGMA user_version').fetchone(),(p.FORMAT_VERSION,))

class HireSealing(unittest.TestCase):
 def setUp(self):
  self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
  self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db)
  self.initial,self.content=p.new_world(self.db,self.source)
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'hire-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'hire-candidate','world-a',self.content)
  self.ctx=p.context('hire-candidate','world-a',self.content)
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='hire-candidate'")
 def companion(self,id_='contract-a',profile='hire_escort',sector='sector_anchor',site=None):
  spec=dict(zip([r[1] for r in self.source.execute('PRAGMA table_info(hire_profile_defs)')],self.source.execute('SELECT * FROM hire_profile_defs WHERE profile_id=?',(profile,)).fetchone()))
  if site is None:site=self.source.execute('SELECT a.site_id FROM station_defs s JOIN anchor_site_defs a ON a.anchor_id=s.station_anchor_id WHERE s.sector_id=? LIMIT 1',(sector,)).fetchone()[0]
  npc='actor-'+id_
  actor={**self.ctx,'npc_instance_id':npc,'spawn_id':spec['spawn_id'],'sector_id':sector,'generation':1,'mission_instance_id':None,'alive':1,'shield':1.0,'armor':1.0,'hull':1.0,'behavior_phase':'patrol','patrol_point_index':0,'bounty_claimed':1,'loot_claimed':1,'quat_w':1.0}
  actor.update({key:0.0 for key in ['pos_x','pos_y','pos_z','quat_x','quat_y','quat_z','vel_x','vel_y','vel_z','angular_x','angular_y','angular_z','wait_remaining_s','cooldown_remaining_s','respawn_remaining_s']})
  p.insert(self.db,'npc_state',actor)
  p.insert(self.db,'spatial_state',{**self.ctx,'entity_kind':'npc','entity_id':npc,'site_id':site})
  owner=self.db.execute("SELECT player_id FROM player_state WHERE snapshot_id='hire-candidate'").fetchone()[0]
  p.insert(self.db,'hire_contract_state',{**self.ctx,'contract_id':id_,'player_id':owner,'profile_id':profile,'origin_station_id':'station_anchor_port','phase':'deployed','npc_instance_id':npc,'sector_id':sector,'site_id':site,'order_kind':'regroup','lease_remaining_s':spec['lease_s'],'fee_paid_credit':spec['hire_fee_credit'],'deposit_paid_credit':spec['deposit_credit'],'support_cycles_remaining':spec['support_cycles'],'created_tick':0})
  p.insert(self.db,'hire_receipt_state',{**self.ctx,'source_token':id_+':hire','contract_id':id_,'event_kind':'hire','paid_credit':spec['hire_fee_credit']+spec['deposit_credit'],'event_tick':0})
  return npc
 def test_initial_world_has_70_groups_and_no_free_companions(self):
  self.assertEqual(len(p.STATE_TABLES),114)
  self.assertEqual(self.db.execute("SELECT count(*) FROM hire_contract_state WHERE snapshot_id=?",(self.initial,)).fetchone(),(0,))
  self.assertEqual(self.db.execute("SELECT count(*) FROM npc_state WHERE snapshot_id=? AND spawn_id LIKE 'hire_%'",(self.initial,)).fetchone(),(0,))
  self.seal()
 def test_valid_bound_companion_can_use_a_different_real_sector_and_site(self):
  self.companion(sector='sector_mirror');self.seal()
 def test_missing_hire_payment_is_rejected(self):
  self.companion();self.db.execute("DELETE FROM hire_receipt_state WHERE snapshot_id='hire-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'settlement'):self.seal()
 def test_short_payment_cannot_seal(self):
  self.companion();self.db.execute("UPDATE hire_receipt_state SET paid_credit=1 WHERE snapshot_id='hire-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'payment'):self.seal()
 def test_two_active_contracts_are_rejected(self):
  self.companion();self.companion('contract-b','hire_support')
  with self.assertRaisesRegex(sqlite3.IntegrityError,'too many'):self.seal()
 def test_wrong_npc_generation_cannot_receive_mobile_exception(self):
  npc=self.companion();self.db.execute("UPDATE npc_state SET generation=2 WHERE snapshot_id='hire-candidate' AND npc_instance_id=?",(npc,))
  with self.assertRaisesRegex(sqlite3.IntegrityError,'binding'):self.seal()
 def test_wrong_profile_spawn_cannot_receive_mobile_exception(self):
  npc=self.companion();self.db.execute("UPDATE npc_state SET spawn_id='hire_support_spawn' WHERE snapshot_id='hire-candidate' AND npc_instance_id=?",(npc,))
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_ordinary_npc_cannot_claim_a_hire_contract(self):
  npc=self.companion(sector='sector_mirror');other=self.source.execute("SELECT spawn_id FROM npc_spawn_defs WHERE spawn_id NOT LIKE 'hire_%' LIMIT 1").fetchone()[0]
  self.db.execute("UPDATE npc_state SET spawn_id=? WHERE snapshot_id='hire-candidate' AND npc_instance_id=?",(other,npc))
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_unbacked_refund_is_rejected(self):
  self.companion();self.db.execute("UPDATE hire_contract_state SET phase='returned',npc_instance_id=NULL,lease_remaining_s=0,refund_credit=3000 WHERE snapshot_id='hire-candidate'")
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_duplicate_return_or_loss_receipts_are_rejected(self):
  self.companion()
  p.insert(self.db,'hire_receipt_state',{**self.ctx,'source_token':'return-a','contract_id':'contract-a','event_kind':'return','event_tick':0})
  with self.assertRaises(sqlite3.IntegrityError):p.insert(self.db,'hire_receipt_state',{**self.ctx,'source_token':'loss-a','contract_id':'contract-a','event_kind':'loss','event_tick':0})
 def test_support_budget_cannot_be_inflated(self):
  self.companion(profile='hire_support');self.db.execute("UPDATE hire_contract_state SET support_cycles_remaining=100000 WHERE snapshot_id='hire-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'binding'):self.seal()

if __name__=='__main__':unittest.main()
