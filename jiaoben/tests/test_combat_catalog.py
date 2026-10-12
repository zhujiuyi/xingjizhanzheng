"""Build reviewed combat SQL in tmp and verify compatibility and rejection paths."""
from collections import Counter
from decimal import Decimal
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog as builder
from test_balance import Catalog


class CombatCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="combat-catalog-", dir=ROOT / "jiaoben/tmp")
        cls.path = Path(cls.temporary.name) / "catalog.db"
        cls.build = builder.build_catalog(cls.path)
        cls.catalog = Catalog(cls.path)

    @classmethod
    def tearDownClass(cls):
        cls.catalog.connection.close()
        cls.temporary.cleanup()

    def rows(self, table):
        return self.catalog.rows(table)

    def mutated(self, sql, parameters=()):
        connection = sqlite3.connect(":memory:")
        self.catalog.connection.backup(connection)
        connection.execute("PRAGMA foreign_keys=ON")
        connection.execute(sql, parameters)
        return connection

    def test_version_and_content_closure(self):
        meta = self.rows("catalog_meta")[0]
        self.assertEqual((meta["schema_version"], meta["content_version"], meta["ruleset_version"]),
                         (20, "v0.21-campaign", "singleplayer_campaign_v1"))
        self.assertEqual(len(self.rows("module_defs")), 42)
        self.assertEqual(len(self.rows("weapon_defs")), 18)
        self.assertEqual(len(self.rows("drone_defs")), 3)
        self.assertEqual(len(self.rows("system_lighting_defs")), 54)
        self.assertEqual(set(builder.CONTENT_COLUMNS), set(builder.CONTENT_TABLES))
        self.assertEqual(builder.logical_content_hash(self.catalog.connection), meta["content_hash"])

    def test_all_nine_hulls_against_all_eighteen_weapons(self):
        roles = self.catalog.index("ship_role_defs", "ship_id")
        profiles = self.catalog.index("weapon_behavior_defs", "module_id")
        permissions = {(r["ship_id"], r["family_id"]): r for r in self.rows("ship_weapon_permissions")}
        exclusive = {row['ship_id'] for row in self.rows('civilization_hull_defs')}
        roles = {id_: role for id_, role in roles.items() if id_ not in exclusive}
        self.assertEqual(len(roles), 9)
        medium = {"destroyer", "cruiser", "battleship"}
        drone_hulls = {"cruiser", "battleship", "support"}
        for ship_id, role in roles.items():
            for module_id, profile in profiles.items():
                with self.subTest(ship=ship_id, weapon=module_id):
                    permission = permissions.get((ship_id, profile["family_id"]))
                    actual = permission is not None and profile["size_class"] <= permission["max_size"]
                    if profile["family_id"] == "drone":
                        expected = role["class_id"] in drone_hulls
                    elif profile["size_class"] == 3:
                        expected = role["class_id"] == "battleship"
                    elif profile["size_class"] == 2:
                        expected = role["class_id"] in medium
                    else:
                        expected = True
                    self.assertEqual(actual, expected)
        self.assertTrue(all(r["max_installed"] == 1 for r in permissions.values()
                            if r["family_id"] in {"thermal", "pulse", "drone"} and r['ship_id'] not in exclusive))

    def test_default_batteries_express_hull_roles(self):
        expected = {
            "destroyer_raptor": Counter({"module_kinetic_lance_i": 2, "module_kinetic_needle_i": 1}),
            "cruiser_horizon": Counter({"module_kinetic_lance_i": 2, "module_drone_swarm_i": 1}),
            "battleship_bastion": Counter({"module_kinetic_siege_i": 4, "module_kinetic_needle_i": 1, "module_drone_swarm_i": 1}),
            "support_weaver": Counter({"module_kinetic_needle_i": 1, "module_drone_swarm_i": 1}),
        }
        for ship_id, battery in expected.items():
            actual = Counter(r["module_id"] for r in self.rows("ship_loadout_items")
                             if r["ship_id"] == ship_id and r["slot_type"] == "weapon")
            self.assertEqual(actual, battery)
        # Tutorial damage and resource budgets remain the established baseline.
        needle = self.catalog.modules["module_kinetic_needle_i"]
        self.assertEqual((self.catalog.weapons[needle["module_id"]]["raw_damage"], needle["cycle_s"], needle["range_m"]),
                         (34, 1.2, 900))

    def test_drone_damage_is_single_sortie_budget_and_can_return(self):
        for drone in self.rows("drone_defs"):
            mid = drone["module_id"]
            module, weapon = self.catalog.modules[mid], self.catalog.weapons[mid]
            damage_per_drone = weapon["raw_damage"] / drone["drone_count"]
            self.assertAlmostEqual(damage_per_drone * drone["drone_count"], weapon["raw_damage"])
            self.assertLess(drone["attack_range_m"], module["range_m"])
            self.assertGreater(drone["sortie_timeout_s"], module["cycle_s"])
            self.assertGreater(drone["sortie_timeout_s"], 2 * module["range_m"] / drone["speed_mps"])
            self.assertIsNone(weapon["projectile_speed_mps"])
            self.assertIsNone(weapon["ammo_item_id"])

    def test_recursive_procurement_and_recycling_never_generate_profit(self):
        potential = self.catalog.potentials()
        _, sell = self.catalog.trade_coefficients()
        for module_id in self.catalog.weapons:
            with self.subTest(weapon=module_id):
                item = self.catalog.items[module_id]
                self.assertGreater(potential[module_id], Decimal(item["base_bid_credit"]) * sell)
                revenue = sum(potential[item] * quantity for item, quantity in self.catalog.recycle[module_id].items())
                self.assertLess(revenue, potential[module_id] + Decimal(self.catalog.rules["recycle_service_fee_credit"]))

    def test_semantic_builder_rejects_missing_profile(self):
        connection = self.mutated("DELETE FROM weapon_behavior_defs WHERE module_id=?", ("module_kinetic_lance_i",))
        with connection, self.assertRaisesRegex(ValueError, "profile closure"):
            builder.validate_combat_content(connection)
        connection.close()

    def test_semantic_builder_rejects_incompatible_default_battery(self):
        connection = self.mutated("UPDATE ship_loadout_items SET module_id='module_kinetic_siege_i' WHERE loadout_id='loadout_shuttle_swift' AND slot_type='weapon'")
        with connection, self.assertRaisesRegex(ValueError, "Default weapon incompatible"):
            builder.validate_combat_content(connection)
        connection.close()

    def test_semantic_builder_rejects_flat_technology_ladder(self):
        connection = self.mutated("UPDATE module_defs SET range_m=900 WHERE module_id='module_kinetic_needle_iii'")
        with connection, self.assertRaisesRegex(ValueError, "progression"):
            builder.validate_combat_content(connection)
        connection.close()

    def test_semantic_builder_rejects_profitable_buyback(self):
        connection = self.mutated("UPDATE item_defs SET base_bid_credit=base_ask_credit-1 WHERE item_id='module_kinetic_siege_i'")
        with connection, self.assertRaisesRegex(ValueError, "arbitrage"):
            builder.validate_combat_content(connection)
        connection.close()

    def test_semantic_builder_rejects_default_budget_overflow(self):
        connection = self.mutated("UPDATE module_defs SET cpu_cu=500 WHERE module_id='module_kinetic_lance_i'")
        with connection, self.assertRaisesRegex(ValueError, "budget exceeded"):
            builder.validate_combat_content(connection)
        connection.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
