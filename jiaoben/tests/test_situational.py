"""Historical definitions and durable observations, independently checked in SQLite."""
from pathlib import Path
import hashlib,sqlite3,subprocess,sys,unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p

class ObservationSql(unittest.TestCase):
 def setUp(self):
  self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
  self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db)
  self.initial,self.cid=p.new_world(self.db,self.source)
  self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
  p.begin_snapshot(self.db,'observation','world-a',self.cid,10)
  p.copy_state(self.db,self.initial,'observation','world-a',self.cid)
  self.ctx=p.context('observation','world-a',self.cid)
 def resource(self,**extra):
  node,sector,site,units=self.source.execute('SELECT n.node_id,n.sector_id,a.site_id,n.capacity_units FROM resource_node_defs n JOIN resource_node_locations l USING(node_id) JOIN anchor_site_defs a USING(anchor_id) WHERE n.node_id NOT LIKE ? LIMIT 1',('exp_%',)).fetchone()
  values={**self.ctx,'node_id':node,'sector_id':sector,'site_id':site,'observed_tick':1,'remaining_units':units,'respawn_remaining_s':0.0,**extra}
  p.insert(self.db,'resource_intel_state',values);return node
 def demand(self,**extra):
  key,price=self.source.execute('SELECT demand_id,unit_reward_credit FROM station_demand_defs LIMIT 1').fetchone()
  p.insert(self.db,'demand_intel_state',{**self.ctx,'demand_id':key,'observed_tick':1,'generation':1,'phase':'active','remaining_units':30,'phase_remaining_s':100.0,'unit_credit':price,**extra});return key
 def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='observation'")
 def test_archive_and_every_old_definition_remain_exact(self):
  archive=ROOT/'code/data/catalog_hire_v19.db'
  self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(),'57138c6bc5f67a748fb3c3a87948a811f26c036058e4ea5b3dcdcbc2064232d8')
  old=sqlite3.connect(archive.as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
  for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name!='catalog_meta'"):
   with self.subTest(table=table):
    self.assertEqual(old.execute('SELECT sql FROM sqlite_schema WHERE name=?',(table,)).fetchone(),self.source.execute('SELECT sql FROM sqlite_schema WHERE name=?',(table,)).fetchone())
    self.assertEqual(sorted(old.execute(f'SELECT * FROM "{table}"').fetchall(),key=repr),sorted(self.source.execute(f'SELECT * FROM "{table}"').fetchall(),key=repr))
  self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.source.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
 def test_all_historical_migrations_and_adapters_keep_published_bytes(self):
  for path in (ROOT/'code/database/progress').glob('*.sql'):
   if path.name.startswith('024_') or path.name=='catalog_adapter_v0_20.sql':continue
   published=subprocess.check_output(['git','show','52f91f0:'+path.relative_to(ROOT).as_posix()],cwd=ROOT)
   self.assertEqual(path.read_bytes(),published,path.name)
 def test_new_format_empty_observations_and_all_72_groups(self):
  self.assertEqual(self.db.execute('PRAGMA user_version').fetchone(),(21,))
  self.assertEqual(len(p.STATE_TABLES),72)
  self.assertEqual(self.db.execute('SELECT count(*) FROM resource_intel_state').fetchone(),(0,))
  self.assertEqual(self.db.execute('SELECT count(*) FROM demand_intel_state').fetchone(),(0,));self.seal()
 def test_previous_observation_survives_changed_live_resource(self):
  node=self.resource();self.demand()
  self.db.execute("UPDATE resource_state SET remaining_units=remaining_units-1 WHERE snapshot_id='observation' AND node_id=?",(node,))
  self.seal()
  self.assertEqual(self.db.execute("SELECT i.remaining_units-r.remaining_units FROM resource_intel_state i JOIN resource_state r USING(snapshot_id,node_id) WHERE i.snapshot_id='observation'").fetchone(),(1,))
 def test_future_observation_rejected(self):
  self.resource(observed_tick=11)
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_excess_resource_amount_rejected(self):
  self.resource(remaining_units=100000000)
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_manipulated_quote_rejected(self):
  self.demand(unit_credit=100000000)
  with self.assertRaises(sqlite3.IntegrityError):self.seal()
 def test_sealed_measurements_immutable(self):
  self.resource();self.demand();self.seal()
  for table in ['resource_intel_state','demand_intel_state']:
   with self.subTest(table=table),self.assertRaises(sqlite3.IntegrityError):self.db.execute(f"UPDATE {table} SET observed_tick=2 WHERE snapshot_id='observation'")

if __name__=='__main__':unittest.main()
