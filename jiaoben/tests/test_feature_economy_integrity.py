"""Definition reachability checks for the full economy and the echo ore repair.

Build an isolated catalog directly from the authoritative SQL. These are static
capability checks; actual actions and persistence are covered by the Godot audit.
"""
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog
from test_balance import Catalog, D


class FeatureEconomyIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix="feature-economy-", dir=ROOT / "jiaoben/tmp")
        cls.path = Path(cls.scratch.name) / "catalog.db"
        build_catalog.build_catalog(cls.path)
        cls.catalog = Catalog(cls.path)
        cls.db = cls.catalog.connection

    @classmethod
    def tearDownClass(cls):
        cls.db.close()
        cls.scratch.cleanup()

    def rows(self, table):
        return self.catalog.rows(table)

    def test_every_item_has_a_gameplay_consumer_beyond_resale(self):
        used = set()
        for table, column in (
            ("module_defs", "module_id"), ("recipe_inputs", "item_id"),
            ("hull_recipe_inputs", "item_id"), ("research_inputs", "item_id"),
            ("base_module_inputs", "item_id"), ("mission_objective_defs", "target_item_id"),
            ("weapon_defs", "ammo_item_id"), ("repair_defs", "consumable_item_id"),
        ):
            used.update(row[column] for row in self.rows(table) if row[column])
        self.assertEqual({row["item_id"] for row in self.rows("item_defs")} - used, set())

    def test_every_defined_module_is_purchasable_craftable_and_fittable(self):
        stocked = {row["item_id"] for row in self.rows("station_stock_defs")
                   if row["allow_buy"] and (row["initial_units"] > 0 or
                   row["target_units"] > 0 and row["restock_units_per_refresh"] > 0)}
        outputs = {row["output_item_id"] for row in self.rows("recipe_defs")}
        slots = {(row["ship_id"], row["slot_type"]) for row in self.rows("ship_slot_defs")}
        for module in self.rows("module_full_defs"):
            with self.subTest(module=module["module_id"]):
                self.assertIn(module["module_id"], stocked)
                self.assertIn(module["module_id"], outputs)
                self.assertTrue(any((ship["ship_id"], module["slot_type"]) in slots
                    and module["power_pu"] <= ship["power_capacity"]
                    and module["cpu_cu"] <= ship["cpu_capacity"]
                    and module["mass_kg"] <= ship["max_installed_mass_kg"]
                    for ship in self.rows("ship_defs")))

    def test_all_recipes_have_a_station_with_actual_industry_service(self):
        providers = {row["station_id"] for row in self.rows("station_service_defs")
                     if row["service_id"] == "manufacture"}
        accessible = {row["recipe_id"] for row in self.rows("recipe_access_defs")
                      if row["station_id"] in providers}
        self.assertEqual({row["recipe_id"] for row in self.rows("recipe_defs")} - accessible, set())
        yards = {row["ship_id"] for row in self.rows("station_ship_stock_defs")
                 if row["station_id"] in providers}
        self.assertEqual({row["ship_id"] for row in self.rows("hull_recipe_defs")} - yards, set())

    def test_research_factions_have_real_industry_providers_and_materials(self):
        stations = {row["station_id"]: row for row in self.rows("station_defs")}
        providers = {stations[row["station_id"]]["faction_id"]
                     for row in self.rows("station_service_defs") if row["service_id"] == "manufacture"}
        self.assertTrue({row["station_faction_id"] for row in self.rows("research_defs")} <= providers)
        stocked = {row["item_id"] for row in self.rows("station_stock_defs")
                   if row["allow_buy"] and row["target_units"] > 0 and row["restock_units_per_refresh"] > 0}
        required = set()
        for table in ("recipe_inputs", "hull_recipe_inputs", "research_inputs", "base_module_inputs"):
            required.update(row["item_id"] for row in self.rows(table))
        self.assertTrue(required <= stocked)

    def test_echo_ore_has_live_industrial_output_and_keeps_original_recipe(self):
        recipes = {row["recipe_id"]: row for row in self.rows("recipe_defs")}
        inputs = {(row["recipe_id"], row["item_id"]): row["quantity"] for row in self.rows("recipe_inputs")}
        alternate = recipes["recipe_sensor_core_echo"]
        self.assertEqual(alternate["output_item_id"], "component_sensor_core")
        self.assertEqual(alternate["output_quantity"], 1)
        self.assertEqual(inputs["recipe_sensor_core_echo", "ore_echo_silica"], 3)
        self.assertEqual(inputs["recipe_sensor_core_echo", "material_structural_stock"], 1)
        self.assertEqual(inputs["recipe_sensor_core_basic", "material_conductive_medium"], 2)
        self.assertEqual(inputs["recipe_sensor_core_basic", "material_structural_stock"], 1)
        services = {(row["station_id"], row["service_id"]): row for row in self.rows("station_service_defs")}
        for access in self.rows("recipe_access_defs"):
            if access["recipe_id"] == alternate["recipe_id"]:
                self.assertIn((access["station_id"], "manufacture"), services)
                self.assertEqual(access["required_unlock_id"], services[access["station_id"], "manufacture"]["required_unlock_id"])

    def test_new_recipe_does_not_reduce_cheapest_cost_or_create_arbitrage(self):
        potential = self.catalog.potentials()
        factor = max(D(row["effect_multiplier"]) for row in self.rows("base_module_defs") if row["service_kind"] == "industry")
        _, sell = self.catalog.trade_coefficients()
        def cost(recipe_id):
            recipe = self.catalog.recipes[recipe_id]
            return (D(recipe["service_fee_credit"]) / factor +
                    sum(potential[item] * quantity for item, quantity in self.catalog.inputs[recipe_id].items())) / recipe["output_quantity"]
        self.assertGreaterEqual(cost("recipe_sensor_core_echo"), cost("recipe_sensor_core_basic"))
        self.assertGreater(cost("recipe_sensor_core_echo"),
                           D(self.catalog.items["component_sensor_core"]["base_bid_credit"]) * sell)
        for recipe in self.catalog.recipes.values():
            self.assertGreaterEqual(cost(recipe["recipe_id"]),
                                    potential[recipe["output_item_id"]])

    def test_integer_recipe_witness_chooses_price_independently_of_order(self):
        candidate = Catalog(self.path)
        try:
            # The expensive alternate must not change the old cheapest route,
            # even when it appears first in the definition query.
            ordinary = candidate.craft_procurement("module_scanner_beacon_i", 1)
            candidate.by_output["component_sensor_core"].reverse()
            self.assertEqual(candidate.craft_procurement("module_scanner_beacon_i", 1), ordinary)
            # A cheaper explicit hypothetical branch must win and retain only
            # its own surplus ledger. This mutation is local to the reference
            # model; no catalog or production prices are changed.
            candidate.items["ore_echo_silica"]["base_ask_credit"] = 1
            candidate.recipes["recipe_sensor_core_echo"]["service_fee_credit"] = 0
            price, surplus = candidate.craft_procurement("component_sensor_core", 1)
            expected_price, expected_surplus = candidate.craft_procurement("material_structural_stock", 1)
            expected_price += candidate.buy("ore_echo_silica", 3)
            self.assertEqual(price, expected_price)
            self.assertEqual(surplus, expected_surplus)
            self.assertNotIn("material_conductive_medium", +surplus)
        finally:
            candidate.connection.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
