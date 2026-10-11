"""Doctrine closure, legacy preservation and authoritative deployment/replacement limits."""
from pathlib import Path
import sqlite3
import sys
import unittest
from catalog_review import without_later_extensions
from unittest import mock
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import build_catalog
import progress_fixture as p
class TacticDefinitions(unittest.TestCase):
    def setUp(self):
        self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.db.execute('PRAGMA foreign_keys=ON');self.addCleanup(self.db.close)
    def test_all_four_doctrines_have_real_models_and_actual_mixed_sites(self):
        build_catalog.validate_database(self.db)
        self.assertEqual({r[0] for r in self.db.execute('SELECT tactic_kind FROM npc_tactic_defs')},{'support','interceptor','siege','carrier'})
        self.assertEqual(self.db.execute('SELECT count(*) FROM tactical_site_defs').fetchone(),(3,))
        self.assertEqual(self.db.execute('SELECT count(*) FROM npc_tactic_bindings').fetchone(),(9,))
    def test_previous_120_tables_keep_every_old_row_and_schema(self):
        old=sqlite3.connect((ROOT/'code/data/catalog_mobile_v12.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
        self.assertEqual(p.adapter_hash(old),'450ca2a4b020e01d97b2e433b7f682114be3f871d6756146d2794c3791b07f9c')
        extend={'anchor_defs','anchor_site_defs','site_defs','npc_archetype_defs','npc_resistances','npc_behavior_defs','npc_defs','npc_spawn_defs','npc_patrol_points'}
        for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
            self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(),self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
            before=set(old.execute(f'SELECT * FROM "{table}"'));after=set(self.db.execute(f'SELECT * FROM "{table}"'))
            self.assertLessEqual(before,after,table)
            after = without_later_extensions(self.db, table, after)
            if table not in extend:self.assertEqual(before,after,table)
            else:
                key=next(i for i,r in enumerate(old.execute(f'PRAGMA table_info("{table}")')) if r[5]==1)
                self.assertTrue(all(r[key].startswith(('tac_','op_')) for r in after-before),table)
        self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
    def test_017_failure_retains_exact_format13_schema(self):
        db=p.connect();self.addCleanup(db.close)
        with mock.patch.object(p,'MIGRATIONS',p.MIGRATIONS[:16]),mock.patch.object(p,'FORMAT_VERSION',13):p.apply_migrations(db)
        before=db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall()
        with self.assertRaises(sqlite3.OperationalError):p.apply_migrations(db,fault_after=17)
        self.assertEqual(before,db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall())
        self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(13,))
        p.apply_migrations(db);self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(p.FORMAT_VERSION,))
class TacticSealing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
        cls.db=p.connect();p.apply_migrations(cls.db);cls.initial,cls.content=p.new_world(cls.db,cls.source)
    @classmethod
    def tearDownClass(cls):cls.db.close();cls.source.close()
    def setUp(self):
        self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
        p.begin_snapshot(self.db,'tactic-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'tactic-candidate','world-a',self.content)
        self.ctx=p.context('tactic-candidate','world-a',self.content)
    def tearDown(self):self.db.rollback()
    def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='tactic-candidate'")
    def bay(self):
        module='module_drone_swarm_i';salvage=self.source.execute('SELECT recipe_id FROM module_salvage_recipe_defs WHERE module_id=?',(module,)).fetchone()[0]
        p.insert(self.db,'item_instance_state',{**self.ctx,'item_instance_id':'bay-fixture','item_def_id':module,'owner_player_id':'player-local','container_id':'warehouse','policy_id':'normal_owned','origin_kind':'purchase','salvage_recipe_id':salvage,'durability':100.,'quality_multiplier':1.})
        p.insert(self.db,'drone_bay_state',{**self.ctx,'item_instance_id':'bay-fixture','stock_units':2,'deployed_units':0,'lost_units':0,'replenished_units':0,'paid_credit_total':0,'material_units_total':0,'revision':0,'command_kind':'attack'})
    def test_missing_tactical_site_state_cannot_seal(self):
        self.db.execute("DELETE FROM tactical_site_state WHERE snapshot_id='tactic-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'coverage'):self.seal()
    def test_outstanding_drone_cannot_be_recreated_by_snapshot(self):
        self.bay();self.db.execute("UPDATE drone_bay_state SET deployed_units=1 WHERE snapshot_id='tactic-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'ledger mismatch'):self.seal()
    def test_destroyed_drone_cannot_be_silently_refilled(self):
        self.bay();self.db.execute("UPDATE drone_bay_state SET lost_units=1 WHERE snapshot_id='tactic-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'ledger mismatch'):self.seal()
    def test_replenishment_cannot_omit_payment_receipt(self):
        self.bay();self.db.execute("UPDATE drone_bay_state SET lost_units=1,replenished_units=1 WHERE snapshot_id='tactic-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'ledger mismatch'):self.seal()
    def test_bay_cannot_exceed_capacity_even_with_matching_ledger(self):
        self.bay();self.db.execute("UPDATE drone_bay_state SET stock_units=3,replenished_units=1,paid_credit_total=150,material_units_total=2 WHERE snapshot_id='tactic-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'ledger mismatch'):self.seal()
    def test_missing_bay_state_cannot_seal(self):
        self.bay();self.db.execute("DELETE FROM drone_bay_state WHERE snapshot_id='tactic-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'coverage'):self.seal()
    def test_valid_paid_replacement_becomes_immutable(self):
        self.bay();self.db.execute("UPDATE drone_bay_state SET lost_units=1,replenished_units=1,paid_credit_total=150,material_units_total=2,revision=2 WHERE snapshot_id='tactic-candidate'")
        self.seal()
        with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.db.execute("DELETE FROM drone_bay_state WHERE snapshot_id='tactic-candidate'")
    def test_jam_cannot_remove_control_beyond_frozen_limit(self):
        p.insert(self.db,'ship_tactical_effect_state',{**self.ctx,'ship_instance_id':'ship-guarantee','source_npc_id':None,'jam_remaining_s':999.,'immunity_remaining_s':6.,'repeat_window_s':20.,'repeat_count':1})
        with self.assertRaisesRegex(sqlite3.IntegrityError,'minimum-control'):self.seal()
if __name__=='__main__':unittest.main()
