"""Independent definition preservation and SQL rejection for owned/auxiliary rules."""
from pathlib import Path
import hashlib,json,sqlite3,subprocess,sys,unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'jiaoben'))
import progress_fixture as p
import fleet_catalog
import march_catalog

class FleetDefinitions(unittest.TestCase):
    def setUp(self):
        self.db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.db.close)
    def test_reviewed_scope_and_definition_closure(self):
        fleet_catalog.validate(self.db)
        self.assertEqual(self.db.execute('SELECT schema_version,content_version,ruleset_version FROM catalog_meta').fetchone(),(23,'v0.24-march','singleplayer_march_v1'))
        self.assertEqual(len(p.STATE_TABLES),114)
        self.assertEqual(self.db.execute('SELECT count(*) FROM auxiliary_drone_defs').fetchone(),(4,))
    def test_every_old_definition_schema_row_and_view_preserved(self):
        archive=ROOT/'code/data/catalog_scenarios_v22.db'
        self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(),'2b7a0a06c7f5435d609ca32de8d1caebc037be497193d53dad69002390d3c08b')
        old=sqlite3.connect(archive.as_uri()+'?mode=ro',uri=True);self.addCleanup(old.close)
        tables={r[0] for r in old.execute("SELECT name FROM sqlite_schema WHERE type='table'")}
        current={r[0] for r in self.db.execute("SELECT name FROM sqlite_schema WHERE type='table'")}
        self.assertEqual(current,tables|set(fleet_catalog.TABLES)|set(march_catalog.TABLES))
        for table in tables-{'catalog_meta'}:
            columns=old.execute(f'PRAGMA table_info("{table}")').fetchall()
            self.assertEqual(columns,self.db.execute(f'PRAGMA table_info("{table}")').fetchall(),table)
            before=set(old.execute(f'SELECT * FROM "{table}"'));after=set(self.db.execute(f'SELECT * FROM "{table}"'))
            self.assertLessEqual(before,after,table)
            extra=after-before
            if table not in fleet_catalog.EXTENSIONS:self.assertFalse(extra,table)
            else:
                column,prefix=fleet_catalog.EXTENSIONS[table];index=[r[1] for r in columns].index(column)
                self.assertTrue(all(str(row[index]).startswith(prefix) for row in extra),table)
        self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(),self.db.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())
    def test_all_published_migrations_and_adapters_keep_real_v030_bytes(self):
        ref='f27717f3a41f2e361278d078e28fba0d3aaebbf6'
        names=subprocess.check_output(['git','ls-tree','-r','--name-only',ref,'code/database/progress'],cwd=ROOT,text=True).splitlines()
        sql=[name for name in names if name.endswith('.sql')];self.assertEqual(len(sql),48)
        for name in sql:self.assertEqual((ROOT/name).read_bytes(),subprocess.check_output(['git','show',ref+':'+name],cwd=ROOT),name)
    def test_both_auxiliary_roles_have_real_work_slots(self):
        for ship,role,maximum in self.db.execute('SELECT * FROM ship_auxiliary_permissions'):
            slots=self.db.execute("SELECT count(*) FROM ship_slot_defs WHERE ship_id=? AND slot_type='work'",(ship,)).fetchone()[0]
            self.assertGreaterEqual(slots,maximum,(ship,role))
            for power,cpu in self.db.execute('SELECT m.power_pu,m.cpu_cu FROM module_defs m JOIN auxiliary_drone_defs a USING(module_id) WHERE a.role_kind=?',(role,)):
                limits=self.db.execute('SELECT power_capacity,cpu_capacity FROM ship_defs WHERE ship_id=?',(ship,)).fetchone()
                self.assertLessEqual(power,limits[0]);self.assertLessEqual(cpu,limits[1])
    def test_auxiliary_art_has_exact_catalogue_mapping(self):
        manifest=json.loads((ROOT/'code/assets/fleet_v1/manifest.json').read_text(encoding='utf-8'))
        mappings={(r['kind'],r['id']) for r in manifest['entries']}
        expected={('item',r[0]) for r in self.db.execute('SELECT module_id FROM auxiliary_drone_defs')}
        expected|={('blueprint',r[0]) for r in self.db.execute('SELECT recipe_id FROM recipe_defs WHERE output_item_id IN(SELECT module_id FROM auxiliary_drone_defs)')}
        self.assertEqual(mappings,expected)
        for row in manifest['resources']:
            path=ROOT/'code'/row['resource_path'].removeprefix('res://');self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),row['sha256'])

class FleetSealing(unittest.TestCase):
    def setUp(self):
        self.source=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True);self.addCleanup(self.source.close)
        self.db=p.connect();self.addCleanup(self.db.close);p.apply_migrations(self.db);self.initial,self.content=p.new_world(self.db,self.source)
        self.db.execute('BEGIN IMMEDIATE');self.db.execute('PRAGMA defer_foreign_keys=ON');p.begin_snapshot(self.db,'fleet-candidate','world-a',self.content,2);p.copy_state(self.db,self.initial,'fleet-candidate','world-a',self.content);self.ctx=p.context('fleet-candidate','world-a',self.content)
    def tearDown(self):self.db.rollback()
    def seal(self):self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='fleet-candidate'")
    def bay(self,**fields):
        module='module_aux_repair_i'
        columns=[r[1] for r in self.source.execute('PRAGMA table_info(auxiliary_drone_defs)')]
        rule=dict(zip(columns,self.source.execute('SELECT * FROM auxiliary_drone_defs WHERE module_id=?',(module,)).fetchone()))
        maximum=self.source.execute("SELECT value_real FROM rule_parameters WHERE parameter_id='module_durability_max'").fetchone()[0]
        if maximum is None:maximum=self.source.execute("SELECT value_integer FROM rule_parameters WHERE parameter_id='module_durability_max'").fetchone()[0]
        recipe=self.source.execute('SELECT recipe_id FROM module_salvage_recipe_defs WHERE module_id=?',(module,)).fetchone()[0]
        p.insert(self.db,'item_instance_state',{**self.ctx,'item_instance_id':'aux-item','item_def_id':module,'owner_player_id':'player-local','container_id':'warehouse','policy_id':'normal_owned','origin_kind':'purchase','salvage_recipe_id':recipe,'durability':maximum,'quality_multiplier':1.0})
        p.insert(self.db,'auxiliary_bay_state',{**self.ctx,'item_instance_id':'aux-item','stock_units':rule['drone_count'],'command_kind':'follow',**fields})
        return rule
    def test_initial_crew_are_available_without_free_progress(self):
        self.assertEqual(self.db.execute('PRAGMA user_version').fetchone(),(26,))
        self.assertEqual(self.db.execute("SELECT count(*) FROM crew_member_state WHERE snapshot_id=? AND phase='available' AND experience=0 AND hire_paid_credit=0",(self.initial,)).fetchone(),(8,))
        self.assertEqual(self.db.execute('SELECT deployments,losses,paid_credit FROM fleet_total_state WHERE snapshot_id=?',(self.initial,)).fetchone(),(0,0,0))
        self.assertEqual(self.db.execute('SELECT count(*) FROM fleet_deployment_state').fetchone(),(0,))
    def test_unpaid_sortie_cannot_seal(self):
        self.bay(sorties=1)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'auxiliary stock cost'):self.seal()
    def test_outstanding_auxiliary_entity_cannot_seal(self):
        self.bay(deployed_units=1)
        with self.assertRaisesRegex(sqlite3.IntegrityError,'outstanding sortie'):self.seal()
    def test_effective_repair_cannot_exceed_paid_capacity(self):
        rule=self.bay();module=self.source.execute('SELECT energy_eu,heat_hu FROM module_defs WHERE module_id=?',(rule['module_id'],)).fetchone()
        self.db.execute("UPDATE auxiliary_bay_state SET sorties=1,energy_paid_total=?,heat_paid_total=?,consumable_paid_units=?,repaired_hp=? WHERE item_instance_id='aux-item'",(*module,rule['consumable_per_sortie'],rule['drone_count']*rule['restore_amount']+1))
        with self.assertRaisesRegex(sqlite3.IntegrityError,'auxiliary stock cost'):self.seal()
    def test_invented_initial_crew_experience_is_rejected(self):
        self.db.execute("UPDATE crew_member_state SET experience=1 WHERE snapshot_id='fleet-candidate' AND profile_id='crew_pilot_1'")
        with self.assertRaisesRegex(sqlite3.IntegrityError,'crew'):self.seal()
