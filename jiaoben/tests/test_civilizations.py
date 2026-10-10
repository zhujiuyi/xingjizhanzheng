"""Civilization scope, progression, permissions and sealed-sovereignty contracts."""
from collections import Counter
from pathlib import Path
import sqlite3
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'jiaoben'))
import civilization_catalog
import progress_fixture as progress


class CivilizationContent(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.db = sqlite3.connect((ROOT / 'code/data/catalog.db').as_uri() + '?mode=ro', uri=True)
        cls.db.row_factory = sqlite3.Row
        cls.legacy = sqlite3.connect((ROOT / 'code/data/catalog_space_v7.db').as_uri() + '?mode=ro', uri=True)
        cls.legacy.row_factory = sqlite3.Row

    @classmethod
    def tearDownClass(cls):
        cls.db.close()
        cls.legacy.close()

    @classmethod
    def rows(cls, table):
        return [dict(row) for row in cls.db.execute('SELECT * FROM ' + table)]

    def test_three_twelve_system_civilizations_and_eighteen_neutral(self):
        owners = Counter(row['initial_faction_id'] for row in self.rows('sector_sovereignty_defs'))
        self.assertEqual(owners, {None: 18, 'faction_route_council': 12, 'faction_deepforge': 12, 'faction_roaming_alliance': 12})
        old = {row[0] for row in self.legacy.execute('SELECT sector_id FROM sector_defs')}
        for policy in self.rows('sector_sovereignty_defs'):
            if policy['sector_id'] in old:
                self.assertIsNone(policy['initial_faction_id'])
                self.assertEqual(policy['conquerable'], 0)
        self.assertEqual(sum(row['conquerable'] for row in self.rows('sector_sovereignty_defs')), 8)
        civilization_catalog.validate(self.db)

    def test_public_hulls_keep_every_old_physical_statistic(self):
        for old in self.legacy.execute('SELECT * FROM ship_defs'):
            current = self.db.execute('SELECT * FROM ship_defs WHERE ship_id=?', (old['ship_id'],)).fetchone()
            self.assertEqual(dict(old), dict(current))

    def test_nine_exclusive_hulls_against_all_weapon_families_and_sizes(self):
        expected = {
            'cruiser_council_sentinel': {'thermal': 2, 'drone': 2},
            'support_council_choir': {'thermal': 2, 'drone': 3},
            'battleship_council_aegis': {'thermal': 3, 'drone': 3, 'pulse': 2},
            'destroyer_forge_hammer': {'kinetic': 2, 'thermal': 1},
            'cruiser_forge_citadel': {'kinetic': 3, 'drone': 2},
            'battleship_forge_ironwall': {'kinetic': 3, 'pulse': 2, 'drone': 2},
            'destroyer_roaming_spear': {'pulse': 2, 'kinetic': 2},
            'cruiser_roaming_kite': {'pulse': 3, 'thermal': 2, 'drone': 2},
            'battleship_roaming_tempest': {'pulse': 3, 'kinetic': 2, 'drone': 2},
        }
        self.assertEqual(set(expected), {row['ship_id'] for row in self.rows('civilization_hull_defs')})
        permissions = {(r['ship_id'], r['family_id']): r for r in self.rows('ship_weapon_permissions')}
        for ship, families in expected.items():
            actual = {family: row['max_size'] for (id_, family), row in permissions.items() if id_ == ship}
            self.assertEqual(actual, families)
            for weapon in self.rows('weapon_behavior_defs'):
                permission = permissions.get((ship, weapon['family_id']))
                actual_allowed = permission is not None and weapon['size_class'] <= permission['max_size']
                expected_allowed = weapon['family_id'] in families and weapon['size_class'] <= families[weapon['family_id']]
                self.assertEqual(actual_allowed, expected_allowed, (ship, weapon['module_id']))

    def test_civilization_designs_have_measurably_different_strengths(self):
        ships = {r['ship_id']: r for r in self.rows('ship_defs')}
        self.assertGreater(ships['battleship_council_aegis']['shield_max'], ships['battleship_forge_ironwall']['shield_max'])
        self.assertGreater(ships['battleship_forge_ironwall']['armor_max'], ships['battleship_council_aegis']['armor_max'])
        self.assertGreater(ships['battleship_roaming_tempest']['max_speed_mps'], ships['battleship_forge_ironwall']['max_speed_mps'])
        self.assertGreater(ships['support_council_choir']['cpu_capacity'], ships['support_weaver']['cpu_capacity'])

    def test_admission_scan_cannot_be_consumed_before_its_mission(self):
        for row in self.rows('civilization_join_missions'):
            objectives = self.db.execute('SELECT * FROM mission_objective_defs WHERE mission_id=?', (row['mission_id'],)).fetchall()
            self.assertEqual(len(objectives), 1)
            objective = objectives[0]
            self.assertEqual(objective['objective_kind'], {1: 'deliver', 2: 'scan_signal', 3: 'destroy_spawn'}[row['step_index']])
            if row['step_index'] == 2:
                signal = self.db.execute('SELECT occurrence_mode FROM signal_defs WHERE signal_id=?', (objective['target_signal_id'],)).fetchone()
                self.assertEqual(signal[0], 'mission_scoped')

    def test_real_research_requires_its_admission_proof_and_common_science(self):
        admission = {(r['faction_id'], r['step_index']): r['mission_id'] for r in self.rows('civilization_join_missions')}
        research = {r['research_id']: r for r in self.rows('research_defs')}
        for definition in self.rows('civilization_technology_defs'):
            row = research[definition['research_id']]
            self.assertEqual(row['verification_mission_id'], admission[(definition['faction_id'], 3)])
            required = self.db.execute('SELECT required_reputation FROM civilization_rank_defs WHERE faction_id=? AND rank_level=?',
                                       (definition['faction_id'], definition['required_rank'])).fetchone()[0]
            self.assertEqual(row['required_reputation'], required)

    def test_war_participants_have_real_spawn_profiles_and_no_repeatable_loot(self):
        self.assertEqual(len(self.rows('civilization_war_defs')), 24)
        members = self.rows('civilization_war_members')
        self.assertEqual(len(members), 24 * 7)
        spawns = {r['spawn_id']: r for r in self.rows('npc_spawn_defs')}
        archetypes = {r['archetype_id']: r for r in self.rows('npc_archetype_defs')}
        npcs = {r['npc_id']: r for r in self.rows('npc_defs')}
        for war in self.rows('civilization_war_defs'):
            units = [r for r in members if r['war_id'] == war['war_id']]
            self.assertEqual(Counter(r['side'] for r in units), {'ally': 3, 'defender': 4})
            for member in units:
                spawn = spawns[member['spawn_id']]
                self.assertEqual((spawn['bounty_enabled'], spawn['loot_enabled'], spawn['respawn_s']), (0, 0, None))
                if member['side'] == 'ally':
                    damage = archetypes[npcs[spawn['npc_id']]['archetype_id']]['damage_type']
                    self.assertEqual(damage, {'faction_route_council': 'thermal', 'faction_deepforge': 'kinetic', 'faction_roaming_alliance': 'pulse'}[war['faction_id']])

    def test_all_exclusive_shipyards_have_a_full_mass_exit(self):
        ships = {r['ship_id']: r for r in self.rows('ship_defs')}
        ids = {r['ship_id'] for r in self.rows('civilization_hull_defs')}
        stations = {r['station_id']: r for r in self.rows('station_defs')}
        gates = {r['gate_class_id']: r for r in self.rows('gate_class_defs')}
        for row in self.rows('station_ship_stock_defs'):
            if row['ship_id'] not in ids:
                continue
            ship = ships[row['ship_id']]
            mass = ship['dry_mass_kg'] + ship['max_installed_mass_kg'] + ship['max_payload_mass_kg']
            sector = stations[row['station_id']]['sector_id']
            self.assertTrue(any(sector in (link['origin_sector_id'], link['target_sector_id']) and gates[link['gate_class_id']]['max_gross_mass_kg'] >= mass for link in self.rows('connection_defs')))


class CivilizationSealing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = sqlite3.connect((ROOT / 'code/data/catalog.db').as_uri() + '?mode=ro', uri=True)
        cls.db = progress.connect()
        progress.apply_migrations(cls.db)
        cls.initial, cls.content = progress.new_world(cls.db, cls.source)

    @classmethod
    def tearDownClass(cls):
        cls.db.close()
        cls.source.close()

    def setUp(self):
        self.db.execute('BEGIN IMMEDIATE')
        self.db.execute('PRAGMA defer_foreign_keys=ON')
        progress.begin_snapshot(self.db, 'civilization-candidate', 'world-a', self.content, 2)
        progress.copy_state(self.db, self.initial, 'civilization-candidate', 'world-a', self.content)

    def tearDown(self):
        self.db.rollback()

    def seal(self):
        self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='civilization-candidate'")

    def test_protected_home_cannot_change_owner(self):
        self.db.execute("UPDATE territory_state SET faction_id='faction_deepforge' WHERE snapshot_id='civilization-candidate' AND sector_id='sector_anchor'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'protected territory'):
            self.seal()

    def test_empty_allegiance_record_is_not_a_complete_snapshot(self):
        self.db.execute("DELETE FROM civilization_state WHERE snapshot_id='civilization-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'coverage'):
            self.seal()

    def test_neutral_capture_requires_completed_war_receipt(self):
        self.db.execute("UPDATE territory_state SET faction_id='faction_deepforge',captured_tick=1 WHERE snapshot_id='civilization-candidate' AND sector_id='sector_frontier_01'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'completed war'):
            self.seal()

    def test_sealed_territory_and_membership_are_immutable(self):
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'immutable'):
            self.db.execute('UPDATE civilization_state SET joined_tick=99 WHERE snapshot_id=?', (self.initial,))
        with self.assertRaisesRegex(sqlite3.IntegrityError, 'immutable'):
            self.db.execute('UPDATE territory_state SET captured_tick=99 WHERE snapshot_id=?', (self.initial,))


if __name__ == '__main__':
    unittest.main()
