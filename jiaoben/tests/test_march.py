"""Independent frozen-definition and SQLite boundary checks for march/growth."""
from pathlib import Path
from contextlib import closing
import hashlib
import sqlite3
import subprocess
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import march_catalog
import progress_fixture as p


class MarchDefinitions(unittest.TestCase):
    def setUp(self):
        self.db=sqlite3.connect(':memory:');self.addCleanup(self.db.close)
        with closing(sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)) as source:source.backup(self.db)

    def test_current_scope(self):
        march_catalog.validate(self.db)
        self.assertEqual(self.db.execute('SELECT schema_version,content_version,ruleset_version FROM catalog_meta').fetchone(),(23,'v0.24-march','singleplayer_march_v1'))
        self.assertEqual(len(p.STATE_TABLES),114)
        self.assertEqual(self.db.execute('SELECT count(*) FROM march_campaign_defs').fetchone(),(24,))

    def test_all_published_fleet_definitions_remain_exact(self):
        path=ROOT/'code/data/catalog_fleet_v23.db'
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),'d05d4868ddd38a496bf6a54bcb59995dce3f9c449db35d3c714bdffb52690e30')
        old=sqlite3.connect(path.as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
        tables={r[0] for r in old.execute("SELECT name FROM sqlite_schema WHERE type='table'")}
        current={r[0] for r in self.db.execute("SELECT name FROM sqlite_schema WHERE type='table'")}
        self.assertEqual(current,tables|set(march_catalog.TABLES))
        for table in tables-{'catalog_meta'}:
            self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(),self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
            self.assertEqual(set(old.execute(f'SELECT * FROM "{table}"')),set(self.db.execute(f'SELECT * FROM "{table}"')),table)
        self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())

    def test_all_fifty_released_sql_files_remain_exact(self):
        ref='ca8519283289d3178f9c225962585c1f56f431e8'
        paths=subprocess.check_output(['git','ls-tree','-r','--name-only',ref,'code/database/progress'],cwd=ROOT,text=True).splitlines()
        paths=[name for name in paths if name.endswith('.sql')];self.assertEqual(len(paths),50)
        for name in paths:self.assertEqual((ROOT/name).read_bytes(),subprocess.check_output(['git','show',ref+':'+name],cwd=ROOT),name)

    def test_missing_leg_is_rejected(self):
        self.db.execute("DELETE FROM march_route_defs WHERE war_id='war_council_01' AND leg_index=1")
        with self.assertRaisesRegex(ValueError,'continuous'):march_catalog.validate(self.db)

    def test_wrong_return_gate_is_rejected(self):
        self.db.execute("UPDATE march_route_defs SET reverse_endpoint_id=endpoint_id WHERE war_id='war_council_01' AND leg_index=0")
        with self.assertRaisesRegex(ValueError,'skip a gate'):march_catalog.validate(self.db)

    def test_carrier_cannot_exceed_cargo_capacity(self):
        self.db.execute("UPDATE ship_defs SET cargo_l=0 WHERE ship_id='cruiser_council_sentinel'")
        with self.assertRaisesRegex(ValueError,'cargo capacity'):march_catalog.validate(self.db)

    def test_gate_goal_must_fit_the_real_entry_radius(self):
        self.db.execute('UPDATE march_balance_defs SET gate_approach_m=200')
        with self.assertRaisesRegex(ValueError,'entry radius'):march_catalog.validate(self.db)

    def test_registration_precedes_qualification_and_funds_are_finite(self):
        for faction, in self.db.execute('SELECT faction_id FROM civilization_defs'):
            positions=dict(self.db.execute('SELECT criterion_kind,min(sort_order) FROM growth_stage_defs WHERE faction_id=? GROUP BY criterion_kind',(faction,)))
            self.assertLess(positions['registration'],positions['honors']);self.assertLess(positions['honors'],positions['war'])
            awards=self.db.execute('SELECT count(*),sum(g.reward_credit),sum(g.reward_reputation) FROM growth_grant_defs g JOIN civilization_honor_task_defs t USING(task_id) WHERE t.faction_id=?',(faction,)).fetchone()
            self.assertEqual(awards,(4,32000,1400))


class MarchSealing(unittest.TestCase):
    def setUp(self):
        self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
        self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db)
        self.initial,self.content=p.new_world(self.db,self.source)
        self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
        p.begin_snapshot(self.db,'march-candidate','world-a',self.content,2)
        p.copy_state(self.db,self.initial,'march-candidate','world-a',self.content)
        self.ctx=p.context('march-candidate','world-a',self.content)
        self.player=self.db.execute("SELECT player_id FROM player_state WHERE snapshot_id='march-candidate'").fetchone()[0]

    def tearDown(self):self.db.rollback()
    def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='march-candidate'")

    def test_initial_world_has_no_army_or_automatic_awards(self):
        self.assertEqual(self.db.execute('PRAGMA user_version').fetchone(),(26,))
        for table in ['march_state','march_member_state','growth_grant_receipt_state','growth_milestone_state']:
            self.assertEqual(self.db.execute(f'SELECT count(*) FROM {table}').fetchone(),(0,))
        self.seal()

    def test_unearned_grant_is_rejected_by_sql(self):
        p.insert(self.db,'growth_grant_receipt_state',{**self.ctx,'task_id':'honor_faction_route_council_scout','faction_id':'faction_route_council','paid_credit':8000,'awarded_reputation':350,'claimed_tick':0})
        with self.assertRaisesRegex(sqlite3.IntegrityError,'actual proof'):self.seal()

    def test_future_milestone_is_rejected_by_sql(self):
        p.insert(self.db,'growth_milestone_state',{**self.ctx,'stage_id':'faction_deepforge_join','observed_tick':99999,'credit_at_observation':0,'reputation_at_observation':0,'owned_hulls_at_observation':0})
        with self.assertRaisesRegex(sqlite3.IntegrityError,'future'):self.seal()

    def test_goal_cannot_claim_another_civilization_context(self):
        p.insert(self.db,'growth_goal_state',{**self.ctx,'player_id':self.player,'faction_id':'faction_deepforge','stage_id':'faction_route_council_join','revision':1,'selected_tick':0})
        with self.assertRaisesRegex(sqlite3.IntegrityError,'growth selection'):self.seal()

    def test_valid_goal_seals_and_then_is_immutable(self):
        p.insert(self.db,'growth_goal_state',{**self.ctx,'player_id':self.player,'faction_id':'faction_deepforge','stage_id':'faction_deepforge_join','revision':1,'selected_tick':0})
        self.seal()
        with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):
            self.db.execute("UPDATE growth_goal_state SET revision=2 WHERE snapshot_id='march-candidate'")


if __name__=='__main__':unittest.main()
