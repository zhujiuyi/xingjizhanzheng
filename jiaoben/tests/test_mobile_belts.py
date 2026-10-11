"""Actual route closure, immutable old rows and strict persisted dispersion/spatial limits."""
import math
from pathlib import Path
import sqlite3
import sys
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import build_catalog
import progress_fixture as p


class MobileDefinitions(unittest.TestCase):
    def setUp(self):
        self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
        self.addCleanup(self.db.close);self.db.execute('PRAGMA foreign_keys=ON')

    def test_three_distinct_au_spaces_per_event_have_complete_geometry(self):
        build_catalog.validate_database(self.db)
        for (event,) in self.db.execute("SELECT event_id FROM exploration_event_defs WHERE event_kind='mineral'"):
            sites=self.db.execute('SELECT s.x_m,s.y_m,s.z_m FROM exploration_belt_route_defs r JOIN anchor_site_defs a ON a.anchor_id=r.entry_anchor_id JOIN site_defs s USING(site_id) WHERE r.event_id=? ORDER BY route_index',(event,)).fetchall()
            self.assertEqual(len(sites),3)
            self.assertTrue(all(math.dist(a,b)>1e10 for i,a in enumerate(sites) for b in sites[i+1:]))

    def test_all_old_117_tables_keep_schema_values_and_derived_views(self):
        old=sqlite3.connect((ROOT/'code/data/catalog_exploration_v11.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
        self.assertEqual(p.adapter_hash(old),'9de35ad2ff0d3a20410c2b46202a6f01e81e651f2e6302247603df87fd38b8ff')
        for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
            self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(),self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
            before=set(old.execute(f'SELECT * FROM "{table}"'));after=set(self.db.execute(f'SELECT * FROM "{table}"'))
            self.assertLessEqual(before,after,table)
            if table not in ('anchor_defs','anchor_site_defs','site_defs','npc_archetype_defs','npc_behavior_defs','npc_resistances','npc_defs','npc_spawn_defs','npc_patrol_points'):self.assertEqual(before,after,table)
            else:
                key=next(i for i,r in enumerate(old.execute(f'PRAGMA table_info("{table}")')) if r[5]==1)
                self.assertTrue(all(r[key].startswith(('belt_','tac_','op_')) for r in after-before),table)
        self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())

    def test_016_failure_retains_complete_format12_schema_then_retries(self):
        db=p.connect();self.addCleanup(db.close)
        with mock.patch.object(p,'MIGRATIONS',p.MIGRATIONS[:15]),mock.patch.object(p,'FORMAT_VERSION',12):p.apply_migrations(db)
        before=db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall()
        with self.assertRaises(sqlite3.OperationalError):p.apply_migrations(db,fault_after=16)
        self.assertEqual(before,db.execute('SELECT type,name,sql FROM sqlite_schema ORDER BY type,name').fetchall())
        self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(12,))
        p.apply_migrations(db)
        self.assertEqual(db.execute('SELECT format_version FROM database_meta').fetchone(),(p.FORMAT_VERSION,))


class MobileSealing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
        cls.db=p.connect();p.apply_migrations(cls.db);cls.initial,cls.content=p.new_world(cls.db,cls.source)

    @classmethod
    def tearDownClass(cls):cls.db.close();cls.source.close()

    def setUp(self):
        self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON')
        p.begin_snapshot(self.db,'belt-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'belt-candidate','world-a',self.content)
        self.ctx=p.context('belt-candidate','world-a',self.content)
        self.belt=p.rows(self.db,'exploration_belt_state',"snapshot_id='belt-candidate'")[0]
        self.event=p.rows(self.db,'exploration_instance_state',"snapshot_id='belt-candidate' AND event_id=?",(self.belt['event_id'],))[0]
        self.variant=p.rows(self.source,'exploration_variant_defs','variant_id=?',(self.event['variant_id'],))[0]
        self.node=p.rows(self.source,'exploration_resource_defs',"event_id=? AND choice_id='safe'",(self.event['event_id'],))[0]['node_id']

    def tearDown(self):self.db.rollback()

    def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='belt-candidate'")

    def activate(self,stage=0):
        elapsed=0.0;cap=self.belt['initial_units']
        if stage:
            definition=p.rows(self.source,'exploration_belt_stage_defs','stage_index=?',(stage,))[0]
            elapsed=self.variant['duration_s']*definition['threshold_bp']/10000
            cap=cap*definition['remaining_cap_bp']//10000
        self.db.execute("UPDATE exploration_instance_state SET phase='mineral',choice_id='safe',elapsed_s=? WHERE snapshot_id='belt-candidate' AND event_id=?",(elapsed,self.event['event_id']))
        self.db.execute("UPDATE exploration_belt_state SET stage_index=?,warning_stage_index=? WHERE snapshot_id='belt-candidate' AND event_id=?",(stage,stage,self.event['event_id']))
        self.db.execute("UPDATE resource_state SET remaining_units=? WHERE snapshot_id='belt-candidate' AND node_id=?",(cap,self.node))
        return cap

    def actor(self,site_index):
        event=self.event['event_id'];route_id=f'belt_{event}_r1'
        self.db.execute("UPDATE exploration_belt_state SET route_id=? WHERE snapshot_id='belt-candidate' AND event_id=?",(route_id,event))
        spec=p.rows(self.source,'exploration_actor_defs',"event_id=? AND actor_role='enemy'",(event,))[0]
        spawn=p.rows(self.source,'npc_spawn_defs','spawn_id=?',(spec['spawn_id'],))[0]
        stats=p.rows(self.source,'npc_full_defs','npc_id=?',(spawn['npc_id'],))[0]
        anchor=self.source.execute('SELECT d.* FROM exploration_belt_anchor_defs m JOIN anchor_defs d ON d.anchor_id=m.anchor_id WHERE m.route_id=? AND m.base_anchor_id=?',(route_id,spawn['anchor_id'])).fetchone()
        p.insert(self.db,'npc_state',{**self.ctx,'npc_instance_id':'route-npc','spawn_id':spawn['spawn_id'],'sector_id':spawn['sector_id'],'generation':self.event['generation'],'alive':1,'shield':stats['shield_max'],'armor':stats['armor_max'],'hull':stats['hull_max'],'pos_x':anchor[3],'pos_y':anchor[4],'pos_z':anchor[5],'quat_x':0.,'quat_y':0.,'quat_z':0.,'quat_w':1.,'vel_x':0.,'vel_y':0.,'vel_z':0.,'angular_x':0.,'angular_y':0.,'angular_z':0.,'behavior_phase':'patrol','wait_remaining_s':0.,'patrol_point_index':0,'cooldown_remaining_s':0.,'respawn_remaining_s':0.,'bounty_claimed':0,'loot_claimed':0})
        p.insert(self.db,'exploration_actor_state',{**self.ctx,'npc_instance_id':'route-npc','event_id':event,'generation':self.event['generation'],'actor_role':'enemy'})
        site=self.source.execute('SELECT a.site_id FROM exploration_belt_route_defs r JOIN anchor_site_defs a ON a.anchor_id=r.entry_anchor_id WHERE r.event_id=? AND r.route_index=?',(event,site_index)).fetchone()[0]
        p.insert(self.db,'spatial_state',{**self.ctx,'entity_kind':'npc','entity_id':'route-npc','site_id':site})

    def test_missing_route_state_cannot_seal(self):
        self.db.execute("DELETE FROM exploration_belt_state WHERE snapshot_id='belt-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'coverage'):self.seal()

    def test_dispersion_cap_cannot_be_refilled_after_load(self):
        self.activate(1);self.db.execute("UPDATE resource_state SET remaining_units=remaining_units+1 WHERE snapshot_id='belt-candidate' AND node_id=?",(self.node,))
        with self.assertRaisesRegex(sqlite3.IntegrityError,'cannot regenerate'):self.seal()

    def test_stage_cannot_be_rewound_while_time_is_preserved(self):
        self.activate(2);self.db.execute("UPDATE exploration_belt_state SET stage_index=0 WHERE snapshot_id='belt-candidate' AND event_id=?",(self.event['event_id'],))
        with self.assertRaisesRegex(sqlite3.IntegrityError,'saved window'):self.seal()

    def test_upgraded_grace_starts_after_existing_elapsed_time(self):
        self.activate()
        elapsed=self.variant['duration_s']*0.6
        self.db.execute("UPDATE exploration_instance_state SET elapsed_s=? WHERE snapshot_id='belt-candidate' AND event_id=?",(elapsed,self.event['event_id']))
        self.db.execute("UPDATE exploration_belt_state SET start_elapsed_s=? WHERE snapshot_id='belt-candidate' AND event_id=?",(elapsed,self.event['event_id']))
        self.seal()

    def test_correct_mapped_actor_site_seals(self):
        self.actor(1);self.seal()

    def test_other_route_actor_site_is_rejected(self):
        self.actor(2)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'NPC site differs'):self.seal()

    def test_valid_disperse_state_becomes_immutable(self):
        self.activate(3);self.seal()
        with self.assertRaisesRegex(sqlite3.IntegrityError,'immutable'):self.db.execute("DELETE FROM exploration_belt_state WHERE snapshot_id='belt-candidate'")


if __name__=='__main__':unittest.main()
