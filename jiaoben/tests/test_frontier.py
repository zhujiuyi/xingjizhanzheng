"""Independent frontier content preservation, migration and financial rejection."""
from pathlib import Path
import hashlib,sqlite3,subprocess,sys,unittest
from unittest import mock
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
import frontier_catalog

class FrontierDefinitions(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.db.close)
 def test_all_138_prior_schemas_and_rows_remain_with_only_whitelisted_additions(self):
  path=ROOT/'code/data/catalog_honors_v17.db'
  self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),'273ef70e03f602c68f8c9d1698260941b214559f77873e582cb09ccaaa0c1de2')
  old=sqlite3.connect(path.as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
   self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(),self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
   before=set(old.execute(f'SELECT * FROM "{table}"'));after=set(self.db.execute(f'SELECT * FROM "{table}"'))
   self.assertTrue(before<=after,table)
   if table not in frontier_catalog.EXTENSIONS:self.assertEqual(before,after,table)
   else:
    cols=[r[1] for r in old.execute(f'PRAGMA table_info("{table}")')];index=cols.index(frontier_catalog.EXTENSIONS[table][0])
    self.assertTrue(all(str(row[index]).startswith('frontier_') for row in after-before),table)
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
 def test_every_existing_war_and_only_eight_neutral_targets_are_covered(self):
  frontier_catalog.validate(self.db)
  self.assertEqual(self.db.execute('SELECT count(*) FROM frontier_campaign_defs').fetchone(),(24,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM frontier_governance_defs').fetchone(),(8,))
  self.assertEqual(self.db.execute('SELECT battle_kind,count(*) FROM frontier_campaign_defs GROUP BY battle_kind ORDER BY battle_kind').fetchall(),[('demolition',12),('hold',12)])
  self.assertEqual(self.db.execute('SELECT count(*) FROM ship_defs').fetchone(),(18,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM module_defs').fetchone(),(42,))
 def test_preparation_actors_cannot_produce_bounty_or_loot(self):
  self.assertEqual(self.db.execute("SELECT sum(s.bounty_enabled),sum(s.loot_enabled) FROM frontier_actor_defs a JOIN npc_spawn_defs s USING(spawn_id)").fetchone(),(0,0))
 def test_022_failure_rolls_back_format18_and_its_schema(self):
  db=p.connect();self.addCleanup(db.close)
  with mock.patch.object(p,'MIGRATIONS',p.MIGRATIONS[:21]),mock.patch.object(p,'FORMAT_VERSION',18):p.apply_migrations(db)
  before=db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall()
  with self.assertRaises(sqlite3.OperationalError):p.apply_migrations(db,fault_after=22)
  self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(18,))
  self.assertEqual(before,db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall())
  p.apply_migrations(db);self.assertEqual(db.execute('PRAGMA user_version').fetchone(),(19,))
 def test_all_published_migrations_and_adapters_preserve_v025_bytes(self):
  for path in sorted((ROOT/'code/database/progress').glob('*.sql')):
   if path.name.startswith('022_') or path.name=='catalog_adapter_v0_18.sql':continue
   original=subprocess.check_output(['git','show','622e5c1b7fc99974dfd6636a27fe2a2f45eb1bac:'+path.relative_to(ROOT).as_posix()],cwd=ROOT)
   self.assertEqual(path.read_bytes(),original,path.name)

class FrontierSealing(unittest.TestCase):
 def setUp(self):
  self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
  self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db)
  self.initial,self.content=p.new_world(self.db,self.source)
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'frontier-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'frontier-candidate','world-a',self.content)
  self.ctx=p.context('frontier-candidate','world-a',self.content)
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='frontier-candidate'")
 def test_initial_full_world_has_68_groups_without_free_governance_or_rewards(self):
  self.assertEqual(len(p.STATE_TABLES),68)
  self.assertEqual(self.db.execute("SELECT count(*) FROM frontier_campaign_state WHERE snapshot_id='frontier-candidate' AND phase='idle'").fetchone(),(24,))
  self.assertEqual(self.db.execute("SELECT count(*),sum(reserve_units) FROM frontier_territory_state WHERE snapshot_id='frontier-candidate' AND phase='neutral'").fetchone(),(8,0))
  self.seal()
 def test_missing_target_governance_cannot_seal(self):
  self.db.execute("DELETE FROM frontier_territory_state WHERE snapshot_id='frontier-candidate' AND sector_id='sector_frontier_01'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'coverage'):self.seal()
 def test_unreceipted_materials_cannot_start_paid_work(self):
  self.db.execute("UPDATE frontier_campaign_state SET supplies_paid_units=40 WHERE snapshot_id='frontier-candidate' AND war_id='war_council_01'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'conservation'):self.seal()
 def test_more_than_one_register_payment_is_rejected(self):
  row={**self.ctx,'source_token':'register-a','war_id':'war_council_01','attempt':1,'event_kind':'register','units':0,'material_units':40,'reward_credit':0,'reward_reputation':0,'event_tick':0}
  p.insert(self.db,'frontier_campaign_receipt_state',row)
  with self.assertRaises(sqlite3.IntegrityError):p.insert(self.db,'frontier_campaign_receipt_state',{**row,'source_token':'register-b'})
 def test_reserves_cannot_exceed_the_frozen_capacity(self):
  self.db.execute("UPDATE frontier_territory_state SET reserve_units=100000 WHERE snapshot_id='frontier-candidate' AND sector_id='sector_frontier_01'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'reserve'):self.seal()
 def test_governance_cannot_claim_control_without_real_sovereignty(self):
  self.db.execute("UPDATE frontier_territory_state SET phase='controlled' WHERE snapshot_id='frontier-candidate' AND sector_id='sector_frontier_01'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'governance'):self.seal()
 def test_unknown_or_skipped_owner_revision_cannot_seal(self):
  self.db.execute("UPDATE frontier_territory_state SET revision=2 WHERE snapshot_id='frontier-candidate' AND sector_id='sector_frontier_01'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'journal'):self.seal()
 def test_false_defense_reward_cannot_seal(self):
  row={**self.ctx,'source_token':'false-defense','sector_id':'sector_frontier_01','revision':0,'event_kind':'defense','faction_id':None,'war_id':None,'attempt':0,'crisis_generation':1,'supply_order_id':None,'units':0,'reward_credit':999999,'reward_reputation':40,'event_tick':0}
  p.insert(self.db,'frontier_journal_state',row)
  with self.assertRaisesRegex(sqlite3.IntegrityError,'reward'):self.seal()
 def test_director_cannot_name_a_nonexistent_warning(self):
  self.db.execute("UPDATE frontier_director_state SET active_sector_id='sector_frontier_01',active_faction_id='faction_route_council' WHERE snapshot_id='frontier-candidate'")
  with self.assertRaisesRegex(sqlite3.IntegrityError,'director'):self.seal()
 def test_sealed_progress_and_ownership_history_remain_immutable(self):
  self.seal()
  with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.db.execute("UPDATE frontier_territory_state SET revision=1 WHERE snapshot_id='frontier-candidate'")

if __name__=='__main__':unittest.main()
