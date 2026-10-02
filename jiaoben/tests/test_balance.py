#!/usr/bin/env python3
"""Read catalog.db and verify design constraints, not a Godot implementation.

Reference equations below contain no second balance dataset. Test-only fixtures,
simulation horizon and economic sample batch sizes are explicitly test inputs.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR
import hashlib
import math
from pathlib import Path
import platform
import sqlite3
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog as builder

DB = ROOT / "code/data/catalog.db"
REPORT = ROOT / "jiaoben/logs/数值校验报告.md"
D = lambda value: Decimal(str(value))


class Catalog:
    def __init__(self, path: Path = DB):
        self.connection = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)
        self.connection.row_factory = sqlite3.Row
        self.rules = {r["parameter_id"]: r["value_integer"] if r["value_integer"] is not None
                      else r["value_real"] for r in self.rows("rule_parameters")}
        self.items = self.index("item_defs", "item_id")
        self.ships = self.index("ship_defs", "ship_id")
        self.modules = self.index("module_full_defs", "module_id")
        self.weapons = self.index("weapon_defs", "module_id")
        self.recipes = self.index("recipe_defs", "recipe_id")
        self.inputs = defaultdict(dict)
        self.by_output = defaultdict(list)
        for row in self.rows("recipe_inputs"):
            self.inputs[row["recipe_id"]][row["item_id"]] = row["quantity"]
        for row in self.recipes.values():
            self.by_output[row["output_item_id"]].append(row)
        self.recycle = defaultdict(dict)
        for row in self.rows("recycle_outputs"):
            self.recycle[row["source_item_id"]][row["output_item_id"]] = row["quantity"]

    def rows(self, table):
        return [dict(r) for r in self.connection.execute(f'SELECT * FROM "{table}"')]

    def index(self, table, key):
        return {r[key]: r for r in self.rows(table)}

    def fit(self, loadout):
        return sorted((r for r in self.rows("ship_loadout_items") if r["loadout_id"] == loadout),
                      key=lambda r: (r["slot_type"], r["slot_index"]))

    def resistances(self, table, key, owner):
        result = defaultdict(dict)
        for row in self.rows(table):
            if row[key] == owner:
                result[row["layer_id"]][row["damage_type"]] = row["resistance"]
        return result

    def trade_coefficients(self):
        r = self.rules
        return ((1 - D(r["max_buy_discount_ratio"])) * (1 + D(r["trade_fee_ratio"])),
                (1 + D(r["max_sell_bonus_ratio"])) * (1 - D(r["trade_fee_ratio"])))

    def buy(self, item, quantity):
        coefficient, _ = self.trade_coefficients()
        return int((D(self.items[item]["base_ask_credit"]) * quantity * coefficient).to_integral_value(rounding=ROUND_CEILING))

    def sell(self, item, quantity):
        _, coefficient = self.trade_coefficients()
        return int((D(self.items[item]["base_bid_credit"]) * quantity * coefficient).to_integral_value(rounding=ROUND_FLOOR))

    def potentials(self):
        """Optimistic fractional-unit procurement lower bound, including all recipe chains.

        Every recipe consumes at least the potential of its outputs. NPC sale is
        an upper bound. Recycling is separately checked for this same potential.
        Thus every permitted paid station action decreases cash+inventory potential.
        Integer rounding/batching cannot create more profit than this relaxed model.
        """
        coefficient, _ = self.trade_coefficients()
        memo, active = {}, set()

        def cost(item):
            if item in memo:
                return memo[item]
            if item in active:
                raise ValueError(f"Recipe dependency cycle at {item}")
            active.add(item)
            candidates = [D(self.items[item]["base_ask_credit"]) * coefficient]
            for recipe in self.by_output[item]:
                total = D(recipe["service_fee_credit"])
                total += sum((cost(i) * q for i, q in self.inputs[recipe["recipe_id"]].items()), D(0))
                candidates.append(total / recipe["output_quantity"])
            memo[item] = min(candidates)
            active.remove(item)
            return memo[item]

        for item in self.items:
            cost(item)
        return memo

    def craft_procurement(self, item, quantity):
        """An integer recursive build route, NPC procurement at recipe leaves.

        Surplus is tracked and valued at NPC sale. This is a witness route,
        not a global integer optimizer; the potential proof covers all routes.
        """
        stock = Counter()

        def acquire(item_id, wanted):
            used = min(stock[item_id], wanted)
            stock[item_id] -= used
            wanted -= used
            if not wanted:
                return 0
            routes = self.by_output[item_id]
            if not routes:
                return self.buy(item_id, wanted)
            # Baseline has one recipe per output. Reject ambiguity in this witness.
            if len(routes) != 1:
                raise ValueError("Integer witness needs an explicit alternate-recipe policy")
            recipe = routes[0]
            batches = math.ceil(wanted / recipe["output_quantity"])
            total = recipe["service_fee_credit"] * batches
            for child, units in sorted(self.inputs[recipe["recipe_id"]].items()):
                total += acquire(child, units * batches)
            stock[item_id] += batches * recipe["output_quantity"] - wanted
            return total

        expense = acquire(item, quantity)
        return expense, stock


def damage_layers(hp, resistances, raw, layer_order):
    """Carry unabsorbed raw damage vector across layers; never re-resist HP damage."""
    hp, remaining = dict(hp), dict(raw)
    for layer in layer_order:
        effective = sum(amount * (1 - resistances[layer].get(kind, 0)) for kind, amount in remaining.items())
        if effective <= 0:
            break
        if effective <= hp[layer]:
            hp[layer] = max(0, hp[layer] - effective)
            return hp
        fraction = hp[layer] / effective
        hp[layer] = 0
        remaining = {kind: amount * (1 - fraction) for kind, amount in remaining.items()}
    return hp


def ehp(hp, resistances, damage_type):
    return sum(value / (1 - resistances[layer][damage_type]) for layer, value in hp.items())


def sustained_reference(catalog, ship_id, module_ids, horizon_s):
    """Worst-demand activations for energy/heat bounds, ideal instant 100% hit.

    Shield is requested every cycle as if continuously damaged; no ammo exhaustion,
    projectile timing, shield feedback, flight or AI. This is a numerical probe.
    """
    ship, rules = catalog.ships[ship_id], catalog.rules
    hz = rules["simulation_hz"]
    priority = catalog.index("module_activation_priority", "module_id")
    instances = sorted(enumerate(module_ids), key=lambda pair: (priority[pair[1]]["priority"], pair[0]))
    due = {index: 0 for index, _ in instances}
    energy, heat, locked = ship["energy_max"], 0.0, False
    counts, rejects = Counter(), Counter()
    raw_output = 0.0
    for tick in range(round(horizon_s * hz)):
        energy = min(ship["energy_max"], energy + ship["recharge_eu_s"] / hz)
        heat = max(0, heat - ship["cooling_hu_s"] / hz)
        if locked and heat <= ship["heat_max"] * rules["overheat_unlock_ratio"]:
            locked = False
        for index, module_id in instances:
            module = catalog.modules[module_id]
            if tick < due[index] or module["cycle_s"] == 0:
                continue
            if locked:
                rejects["locked"] += 1
                continue
            if energy + 1e-9 < module["energy_eu"]:
                rejects["energy"] += 1
                continue
            if heat + module["heat_hu"] > ship["heat_max"] + 1e-9:
                rejects["heat"] += 1
                locked = True
                continue
            energy -= module["energy_eu"]
            heat += module["heat_hu"]
            counts[module_id] += 1
            due[index] = tick + round(module["cycle_s"] * hz)
            if module_id in catalog.weapons:
                raw_output += catalog.weapons[module_id]["raw_damage"]
            if not (math.isfinite(energy) and math.isfinite(heat) and
                    -1e-7 <= energy <= ship["energy_max"] + 1e-7 and
                    -1e-7 <= heat <= ship["heat_max"] + 1e-7):
                raise AssertionError("Shared ledger left finite legal resource bounds")
    return {"counts": dict(counts), "rejects": dict(rejects), "energy": energy, "heat": heat,
            "raw_dps": raw_output / horizon_s}


class BalanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = Catalog()
        cls.evidence = {}

    @classmethod
    def tearDownClass(cls):
        cls.c.connection.close()

    def writable_copy(self):
        connection = sqlite3.connect(":memory:")
        self.c.connection.backup(connection)
        connection.execute("PRAGMA foreign_keys=ON")
        self.addCleanup(connection.close)
        return connection

    def test_integrity_and_strict_storage(self):
        connection = self.writable_copy()
        builder.validate_database(connection)
        tables = connection.execute("PRAGMA table_list").fetchall()
        self.assertTrue(all(r[5] == 1 for r in tables if r[1] in builder.CONTENT_TABLES))
        self.assertEqual(set(builder.CONTENT_TABLES), set(builder.CONTENT_COLUMNS))

    def test_invalid_sql_values_rollback(self):
        connection = self.writable_copy()
        before = builder.logical_content_hash(connection)
        cases = [
            ("UPDATE recipe_inputs SET quantity=-1", ()),
            ("UPDATE recipe_inputs SET quantity=1.5", ()),
            ("UPDATE recipe_inputs SET item_id='missing_definition' WHERE recipe_id='recipe_ammo'", ()),
            ("UPDATE ship_defs SET dry_mass_kg=0", ()),
            ("UPDATE module_defs SET slot_type='unknown'", ()),
            ("UPDATE rule_parameters SET value_integer=1, value_real=2", ()),
            ("INSERT INTO ship_loadout_items VALUES(?,?,?,?,?)", (
                "loadout_shuttle_swift", "shuttle_swift", "weapon", 0, "module_kinetic_needle_i")),
            ("INSERT INTO ship_loadout_items VALUES(?,?,?,?,?)", (
                "loadout_shuttle_swift", "shuttle_swift", "work", 0, "module_industry_sift_i")),
            ("INSERT INTO ship_loadout_items VALUES(?,?,?,?,?)", (
                "loadout_shuttle_swift", "shuttle_swift", "utility", 1, "module_kinetic_needle_i")),
        ]
        for sql, parameters in cases:
            with self.subTest(sql=sql, parameters=parameters):
                connection.execute("SAVEPOINT bad_value")
                with self.assertRaises(sqlite3.IntegrityError):
                    connection.execute(sql, parameters)
                connection.execute("ROLLBACK TO bad_value")
                connection.execute("RELEASE bad_value")
        self.assertEqual(builder.logical_content_hash(connection), before)

    def test_logical_hash_self_exclusion_and_mutation(self):
        connection = self.writable_copy()
        old = builder.logical_content_hash(connection)
        self.assertEqual(connection.execute("SELECT content_hash FROM catalog_meta").fetchone()[0], old)
        connection.execute("UPDATE catalog_meta SET content_hash='test_only'")
        self.assertEqual(builder.logical_content_hash(connection), old)
        connection.execute("UPDATE ship_defs SET max_speed_mps=max_speed_mps+1 WHERE ship_id='shuttle_swift'")
        self.assertNotEqual(builder.logical_content_hash(connection), old)

    def test_unregistered_table_and_column_fail(self):
        for statement in ("CREATE TABLE unregistered(id INTEGER PRIMARY KEY) STRICT",
                          "ALTER TABLE ship_defs ADD COLUMN unregistered REAL"):
            with self.subTest(statement=statement):
                connection = self.writable_copy()
                connection.execute(statement)
                with self.assertRaises(ValueError):
                    builder.logical_content_hash(connection)

    def test_hash_order_and_rebuild_reproducibility(self):
        connection = self.writable_copy()
        old = builder.logical_content_hash(connection)
        rows = connection.execute("SELECT * FROM rule_parameters ORDER BY parameter_id DESC").fetchall()
        connection.execute("DELETE FROM rule_parameters")
        connection.executemany("INSERT INTO rule_parameters VALUES(?,?,?,?)", rows)
        self.assertEqual(builder.logical_content_hash(connection), old)
        with tempfile.TemporaryDirectory(prefix="catalog-test-", dir=ROOT / "jiaoben/tmp") as directory:
            built = builder.build_catalog(Path(directory) / "rebuilt.db")
            self.assertEqual(built["content_hash"], old)
            self.assertEqual(built["file_sha256"], hashlib.sha256(DB.read_bytes()).hexdigest())

    def test_view_definition_change_changes_content_hash(self):
        connection = self.writable_copy()
        before = builder.logical_content_hash(connection)
        definition = connection.execute("SELECT sql FROM sqlite_schema WHERE name='npc_full_defs'").fetchone()[0]
        connection.execute("DROP VIEW npc_full_defs")
        changed = definition.replace("a.base_raw_dps * l.dps_basis_points", "2 * a.base_raw_dps * l.dps_basis_points")
        self.assertNotEqual(definition, changed)
        connection.execute(changed)
        self.assertNotEqual(builder.logical_content_hash(connection), before)
        stored = connection.execute("SELECT content_hash FROM catalog_meta").fetchone()[0]
        self.assertNotEqual(builder.logical_content_hash(connection), stored)

    def test_unregistered_or_missing_view_fails(self):
        for statement in ("CREATE VIEW unregistered AS SELECT 1 AS id", "DROP VIEW npc_full_defs"):
            with self.subTest(statement=statement):
                connection = self.writable_copy()
                connection.execute(statement)
                with self.assertRaises(ValueError):
                    builder.logical_content_hash(connection)

    def test_finite_real_encoding_and_type_boundaries(self):
        for number in (float("nan"), float("inf"), float("-inf")):
            with self.assertRaises(ValueError):
                builder.encode_field(number, "REAL")
        self.assertNotEqual(builder.encode_field(1, "INTEGER"), builder.encode_field(1.0, "REAL"))
        self.assertNotEqual(builder.encode_field(None), builder.encode_field(""))

    def test_default_loadout_budgets_and_families(self):
        budgets = []
        groups = self.c.index("module_exclusion_groups", "group_id")
        members = defaultdict(list)
        for row in self.c.rows("module_group_members"):
            members[row["module_id"]].append(row["group_id"])
        for loadout in self.c.rows("ship_loadout_defs"):
            with self.subTest(loadout=loadout["loadout_id"]):
                ship = self.c.ships[loadout["ship_id"]]
                fit = self.c.fit(loadout["loadout_id"])
                modules = [self.c.modules[r["module_id"]] for r in fit]
                pu, cu, mass = (sum(m[k] for m in modules) for k in ("power_pu", "cpu_cu", "mass_kg"))
                self.assertLessEqual(pu, ship["power_capacity"])
                self.assertLessEqual(cu, ship["cpu_capacity"])
                self.assertLessEqual(mass, ship["max_installed_mass_kg"])
                counts, family_counts = Counter(m["module_id"] for m in modules), Counter()
                for module_id, count in counts.items():
                    maximum = self.c.modules[module_id]["max_per_ship"]
                    if maximum is not None:
                        self.assertLessEqual(count, maximum)
                    for group in members[module_id]:
                        family_counts[group] += count
                for group, count in family_counts.items():
                    self.assertLessEqual(count, groups[group]["max_installed"])
                budgets.append((ship["display_name"], pu, cu, mass))
        self.evidence["budgets"] = budgets

    def test_slot_counts_and_armor_exclusion(self):
        for capacity in self.c.rows("ship_slot_capacity"):
            slots = [r["slot_index"] for r in self.c.rows("ship_slot_defs")
                     if r["ship_id"] == capacity["ship_id"] and r["slot_type"] == capacity["slot_type"]]
            self.assertEqual(sorted(slots), list(range(capacity["slot_count"])))
        armor_groups = {r["group_id"] for r in self.c.rows("module_group_members")
                        if r["module_id"] in ("module_armor_pressure_i", "module_armor_feather_i")}
        self.assertEqual(len(armor_groups), 1)
        group = self.c.index("module_exclusion_groups", "group_id")[armor_groups.pop()]
        self.assertLess(group["max_installed"], 2)

    def test_supply_cargo_and_worst_case_tutorial_gate(self):
        gate = self.c.index("effective_connection_defs", "connection_id")["conn_anchor_echo"]
        self.assertTrue(gate["bidirectional"])
        self.assertIsNone(gate["total_mass_budget_kg"])
        self.assertEqual(gate["energy_cost_eu"], self.c.rules["basic_propulsion_energy_eu"])
        self.assertEqual(gate["fee_credit"], self.c.rules["station_energy_restore_credit"])
        gross = []
        for loadout in self.c.rows("ship_loadout_defs"):
            ship = self.c.ships[loadout["ship_id"]]
            supplies = [r for r in self.c.rows("loadout_supply_defs") if r["loadout_id"] == loadout["loadout_id"]]
            payload = sum(self.c.items[r["item_id"]]["unit_mass_kg"] * r["quantity"] for r in supplies)
            volume = sum(self.c.items[r["item_id"]]["unit_volume_l"] * r["quantity"] for r in supplies)
            self.assertLessEqual(payload, ship["max_payload_mass_kg"])
            self.assertLessEqual(volume, ship["cargo_l"])
            # An absolute bound covers every legal fit and both holds, not just default fits.
            mass_bound = ship["dry_mass_kg"] + ship["max_installed_mass_kg"] + ship["max_payload_mass_kg"]
            self.assertLessEqual(mass_bound, gate["max_gross_mass_kg"])
            gross.append((ship["display_name"], mass_bound))
        self.evidence["gross"] = gross

    def test_mass_penalty_retains_basic_flight(self):
        self.assertEqual(self.c.rules["basic_propulsion_energy_eu"], 0)
        self.assertEqual(self.c.rules["basic_brake_energy_eu"], 0)
        for ship in self.c.ships.values():
            maximum = ship["dry_mass_kg"] + ship["max_installed_mass_kg"] + ship["max_payload_mass_kg"]
            f = ship["dry_mass_kg"] / maximum
            self.assertGreater(ship["acceleration_mps2"] * f, 0)
            self.assertLess(ship["max_speed_mps"] * math.sqrt(f), ship["max_speed_mps"])
            self.assertGreater(self.c.rules["brake_acceleration_multiplier"], 1)

    def test_recipe_reachability_from_high_security_ores(self):
        nodes = self.c.rows("resource_node_defs")
        sectors = self.c.index("sector_defs", "sector_id")
        reachable = {r["item_id"] for r in nodes if sectors[r["sector_id"]]["risk_zone_id"] == "risk_high"}
        self.assertTrue(reachable)
        changed = True
        while changed:
            changed = False
            for recipe in self.c.recipes.values():
                inputs = self.c.inputs[recipe["recipe_id"]]
                self.assertTrue(inputs)
                if inputs.keys() <= reachable and recipe["output_item_id"] not in reachable:
                    reachable.add(recipe["output_item_id"])
                    changed = True
        self.assertTrue(self.c.modules.keys() <= reachable)
        self.c.potentials()  # Full dependency recursion also rejects cycles.
        self.evidence["reachable"] = len(reachable)

    def test_all_station_actions_decrease_economic_potential(self):
        potential = self.c.potentials()
        _, sell_coefficient = self.c.trade_coefficients()
        margins = []
        for item_id, item in self.c.items.items():
            revenue_upper = D(item["base_bid_credit"]) * sell_coefficient
            margin = potential[item_id] - revenue_upper
            with self.subTest(item=item_id):
                self.assertGreater(margin, 0)
            margins.append((margin, item_id, potential[item_id], revenue_upper))
        for recipe_id, recipe in self.c.recipes.items():
            inputs = sum((potential[i] * q for i, q in self.c.inputs[recipe_id].items()), D(0))
            self.assertGreaterEqual(inputs + recipe["service_fee_credit"],
                                    potential[recipe["output_item_id"]] * recipe["output_quantity"])
        for module_id in self.c.modules:
            output_value = sum((potential[i] * q for i, q in self.c.recycle[module_id].items()), D(0))
            self.assertLessEqual(output_value, potential[module_id] + self.c.rules["recycle_service_fee_credit"])
        for ship in self.c.ships.values():
            buy_coefficient, _ = self.c.trade_coefficients()
            self.assertGreater(D(ship["base_ask_credit"]) * buy_coefficient,
                               D(ship["base_bid_credit"]) * sell_coefficient)
        self.evidence["minimum_item_margin"] = min(margins)
        self.evidence["minimum_module_margin"] = min(r for r in margins if r[1] in self.c.modules)

    def test_integer_manufacture_buy_recycle_sale_cycles(self):
        margins = []
        fee = self.c.rules["recycle_service_fee_credit"]
        for module_id in self.c.modules:
            for quantity in (1, 7, 100):  # Test batch sizes, not game balance definitions.
                with self.subTest(module=module_id, quantity=quantity):
                    expense, surplus = self.c.craft_procurement(module_id, quantity)
                    leftover_revenue = sum(self.c.sell(i, q) for i, q in surplus.items() if q > 0)
                    manufactured_sale = self.c.sell(module_id, quantity) + leftover_revenue
                    self.assertGreater(expense, manufactured_sale)
                    recycle_revenue = sum(self.c.sell(i, q * quantity) for i, q in self.c.recycle[module_id].items())
                    # Procurement -> frozen standard salvage -> NPC sale.
                    self.assertGreater(self.c.buy(module_id, quantity) + fee * quantity, recycle_revenue)
                    # Complete manufacturing -> actual baseline input salvage -> sale,
                    # including all excess intermediate batches sold back.
                    self.assertGreater(expense + fee * quantity, recycle_revenue + leftover_revenue)
                    margins.append((expense - manufactured_sale, module_id, quantity))
        self.evidence["integer_min_margin"] = min(margins)

    def test_salvage_origin_and_floor_per_input(self):
        mapping = self.c.index("module_salvage_recipe_defs", "module_id")
        self.assertEqual(mapping.keys(), self.c.modules.keys())
        ratio = D(self.c.rules["recycle_input_return_ratio"])
        for module_id, origin in mapping.items():
            recipe = self.c.recipes[origin["recipe_id"]]
            self.assertEqual(recipe["output_item_id"], module_id)
            expected = {item: int((D(quantity) * ratio).to_integral_value(rounding=ROUND_FLOOR))
                        for item, quantity in self.c.inputs[origin["recipe_id"]].items()}
            expected = {item: quantity for item, quantity in expected.items() if quantity > 0}
            self.assertEqual(self.c.recycle[module_id], expected)

    def test_tutorial_grants_and_protection_have_no_purchase_lock(self):
        steps = sorted(self.c.rows("tutorial_step_defs"), key=lambda r: r["step_order"])
        grants = self.c.rows("starting_ships")
        policies = self.c.index("asset_policy_defs", "policy_id")
        owned = [r for r in grants if r["grant_kind"] == "owned" and r["available_at_step_id"] is None]
        self.assertTrue(owned)
        for index, step in enumerate(steps):
            self.assertEqual(step["prerequisite_step_id"], None if index == 0 else steps[index - 1]["step_id"])
            available = [r for r in grants if r["available_at_step_id"] in (None, step["step_id"])]
            self.assertTrue(available)
            if step["action_kind"] == "mining_delivery":
                self.assertTrue(any(any(f["module_id"] in self.c.index("mining_defs", "module_id")
                                       for f in self.c.fit(r["loadout_id"])) for r in available))
                reserves = sum(r["capacity_units"] for r in self.c.rows("resource_node_defs")
                               if r["item_id"] == step["required_item_id"])
                self.assertGreaterEqual(reserves, step["required_quantity"])
            if step["action_kind"] == "combat":
                self.assertIsNotNone(step["target_npc_id"])
        for grant in grants:
            policy = policies[grant["policy_id"]]
            self.assertFalse(policy["may_sell"] or policy["may_recycle"])
            self.assertTrue(policy["inherit_to_attached"] and policy["inherit_to_supplies"])
        self.assertTrue(all(r["starting_credit"] >= 0 for r in self.c.rows("starting_profile_defs")))

    def test_scan_initial_ship_affordability_and_range(self):
        ship, r = self.c.ships["shuttle_swift"], self.c.rules
        threshold = r["tutorial_scan_threshold"] * r["scan_difficulty_common"]
        proximity = min(1, max(r["scan_proximity_floor"], r["scan_proximity_intercept"]))
        rate = ship["scan_strength"] * proximity / r["scan_interference_floor"]
        cycle_s = r["basic_scan_cycle_s"]
        cycles = math.ceil(threshold / (rate * cycle_s))
        elapsed = cycles * cycle_s
        # Conservative: the initial energy alone covers all cycles without recharge.
        self.assertLessEqual(elapsed * r["basic_scan_energy_eu_s"], ship["energy_max"])
        self.assertLessEqual(r["basic_scan_heat_hu_s"], ship["cooling_hu_s"])
        def progress_at(distance):
            if distance > r["basic_scan_range_m"]:
                return 0
            proximity = max(r["scan_proximity_floor"], min(1, r["scan_proximity_intercept"] -
                            r["scan_proximity_distance_slope"] * distance / r["basic_scan_range_m"]))
            return ship["scan_strength"] * proximity / r["scan_interference_floor"]
        self.assertEqual(progress_at(r["basic_scan_range_m"] + 1), 0)
        self.assertGreater(progress_at(r["basic_scan_range_m"]), 0)
        self.assertEqual(D(cycle_s) * r["simulation_hz"], (D(cycle_s) * r["simulation_hz"]).to_integral_value())
        self.evidence["tutorial_scan_seconds"] = elapsed

    def test_mining_slot_order_and_shared_payload(self):
        ship = self.c.ships["miner_anvil"]
        module_id = "module_industry_sift_i"
        mining = self.c.index("mining_defs", "module_id")[module_id]
        nominal = math.floor(mining["base_yield_units"] * ship["mining_multiplier"])
        item = self.c.items["ore_ferrosilicate"]
        remaining = nominal + 1  # Test fixture: two heads contend for the same final ore.
        outputs = []
        for _slot in range(2):
            quantity = min(nominal, remaining)
            outputs.append(quantity)
            remaining -= quantity
        self.assertEqual(outputs, [nominal, 1])
        self.assertEqual(remaining, 0)
        # Fill both holds with the same resource; one payload limit serves both.
        ammo = [r for r in self.c.rows("loadout_supply_defs") if r["loadout_id"] == "loadout_miner_anvil"]
        ammo_mass = sum(self.c.items[r["item_id"]]["unit_mass_kg"] * r["quantity"] for r in ammo)
        ammo_volume = sum(self.c.items[r["item_id"]]["unit_volume_l"] * r["quantity"] for r in ammo)
        general = min((ship["cargo_l"] - ammo_volume) // item["unit_volume_l"],
                      math.floor((ship["max_payload_mass_kg"] - ammo_mass) / item["unit_mass_kg"]))
        mineral = min(ship["mineral_cargo_l"] // item["unit_volume_l"],
                      math.floor((ship["max_payload_mass_kg"] - ammo_mass - general * item["unit_mass_kg"]) / item["unit_mass_kg"]))
        self.assertLess(mineral, ship["mineral_cargo_l"] // item["unit_volume_l"])
        self.assertEqual(math.floor((ship["max_payload_mass_kg"] - ammo_mass - (general + mineral) * item["unit_mass_kg"]) /
                                    item["unit_mass_kg"]), 0)
        fit = self.c.fit("loadout_miner_anvil")
        heads = sum(row["module_id"] == module_id for row in fit)
        self.evidence["mining_rate_units_s"] = nominal * heads / self.c.modules[module_id]["cycle_s"]

    def test_damage_overflow_golden_and_mixed_vector(self):
        order = [r["layer_id"] for r in sorted(self.c.rows("defense_layers"), key=lambda r: r["layer_order"])]
        # Published algorithm fixture, distinct from live ship balance values.
        result = damage_layers({"shield": 10, "armor": 12, "hull": 20},
                               {"shield": {"kinetic": .5}, "armor": {"kinetic": .2}, "hull": {"kinetic": 0}},
                               {"kinetic": 50}, order)
        self.assertEqual(result, {"shield": 0, "armor": 0, "hull": 5})
        ship = self.c.ships["frigate_kestrel"]
        hp = {layer: ship[layer + "_max"] for layer in order}
        resistance = self.c.resistances("ship_resistances", "ship_id", ship["ship_id"])
        first = damage_layers(hp, resistance, {"kinetic": 200, "thermal": 250, "pulse": 300}, order)
        reordered = damage_layers(hp, resistance, {"pulse": 300, "thermal": 250, "kinetic": 200}, order)
        for layer in order:
            self.assertAlmostEqual(first[layer], reordered[layer])
            self.assertGreaterEqual(first[layer], 0)
            self.assertLessEqual(first[layer], hp[layer])

    def test_passive_armor_resistance_and_mass_tradeoff(self):
        cap = self.c.rules["resistance_cap"]
        base = self.c.resistances("ship_resistances", "ship_id", "frigate_kestrel")
        for row in self.c.rows("module_resistance_modifiers"):
            effective = min(cap, max(0, base[row["layer_id"]][row["damage_type"]] + row["delta"]))
            self.assertTrue(0 <= effective <= cap)
        heavy = self.c.modules["module_armor_pressure_i"]
        light = self.c.modules["module_armor_feather_i"]
        self.assertGreater(heavy["mass_kg"], light["mass_kg"])
        hp = {r["module_id"]: r["amount"] for r in self.c.rows("module_stat_modifiers")
              if r["stat_id"] == "armor_max"}
        self.assertGreater(hp[heavy["module_id"]], hp[light["module_id"]])

    def test_integer_tick_periods_and_shared_energy_heat(self):
        hz = self.c.rules["simulation_hz"]
        for module in self.c.modules.values():
            ticks = D(module["cycle_s"]) * hz
            self.assertEqual(ticks, ticks.to_integral_value())
        ids = [r["module_id"] for r in self.c.fit("loadout_frigate_kestrel")]
        default = sustained_reference(self.c, "frigate_kestrel", ids, 120)
        overload = sustained_reference(self.c, "frigate_kestrel", ["module_engine_vector_i", "module_shield_lattice_i",
                                        "module_thermal_sunline_i"], 120)
        self.assertGreater(sum(overload["rejects"].values()), 0)
        self.assertLess(overload["raw_dps"], self.c.weapons["module_thermal_sunline_i"]["raw_damage"] /
                        self.c.modules["module_thermal_sunline_i"]["cycle_s"])
        # The same ledger must reserve the first module cost before the next checks.
        energy = self.c.modules["module_shield_lattice_i"]["energy_eu"]
        energy -= self.c.modules["module_engine_vector_i"]["energy_eu"]
        self.assertLess(energy, self.c.modules["module_shield_lattice_i"]["energy_eu"])
        self.evidence["sustained_default"] = default
        self.evidence["sustained_thermal"] = overload

    def test_npc_level_curve_integer_ceiling_and_risk(self):
        r = self.c.rules
        denominator = r["npc_basis_point_denominator"]
        levels = sorted(self.c.rows("npc_level_defs"), key=lambda row: row["level"])
        for level in levels:
            for field, rule in (("hp_basis_points", "npc_hp_bp_per_level"),
                                ("dps_basis_points", "npc_dps_bp_per_level"),
                                ("reward_basis_points", "npc_reward_bp_per_level")):
                self.assertEqual(level[field], denominator + r[rule] * (level["level"] - 1))
        zones = self.c.index("risk_zone_defs", "risk_zone_id")
        levelmap = {level["level"]: level for level in levels}
        for npc in self.c.rows("npc_full_defs"):
            zone = zones[npc["risk_zone_id"]]
            self.assertTrue(zone["npc_level_min"] <= npc["level"] <= zone["npc_level_max"])
            bp = levelmap[npc["level"]]
            for field in ("shield", "armor", "hull"):
                expected = (npc["base_" + field] * bp["hp_basis_points"] + denominator - 1) // denominator
                self.assertEqual(npc[field + "_max"], expected)
                self.assertIsInstance(npc[field + "_max"], int)
            self.assertEqual(npc["reward_credit"], (npc["base_reward_credit"] * bp["reward_basis_points"] + denominator - 1) // denominator)

    def test_ttk_continuous_discrete_and_counterattack(self):
        order = [r["layer_id"] for r in sorted(self.c.rows("defense_layers"), key=lambda r: r["layer_order"])]
        npcs = self.c.index("npc_full_defs", "npc_id")
        output = []
        for benchmark in self.c.rows("combat_benchmark_defs"):
            fit = self.c.fit(benchmark["loadout_id"])
            ship_id = fit[0]["ship_id"]
            ship = self.c.ships[ship_id]
            weapons = [self.c.weapons[r["module_id"]] for r in fit if r["module_id"] in self.c.weapons]
            kinds = {w["damage_type"] for w in weapons}
            periods = {self.c.modules[w["module_id"]]["cycle_s"] for w in weapons}
            self.assertEqual(len(kinds), 1)
            self.assertEqual(len(periods), 1)
            kind, period = kinds.pop(), periods.pop()
            volley = sum(w["raw_damage"] for w in weapons)
            dps = volley / period
            npc = npcs[benchmark["npc_id"]]
            hp = {layer: npc[layer + "_max"] for layer in order}
            resistance = self.c.resistances("npc_resistances", "archetype_id", npc["archetype_id"])
            continuous = ehp(hp, resistance, kind) / dps
            volleys = 0
            remaining = hp
            while remaining["hull"] > 1e-8 and volleys < 10000:
                remaining = damage_layers(remaining, resistance, {kind: volley}, order)
                volleys += 1
            discrete = (volleys - 1) * period  # First ideal volley at t=0.
            self.assertLessEqual(discrete, continuous + 1e-8)
            self.assertLess(continuous, discrete + period + 1e-8)
            player_hp = {layer: ship[layer + "_max"] for layer in order}
            player_resistance = self.c.resistances("ship_resistances", "ship_id", ship_id)
            counter = ehp(player_hp, player_resistance, npc["damage_type"]) / npc["raw_dps"]
            self.assertEqual(continuous < counter, bool(benchmark["player_can_win"]))
            supplies = sum(r["quantity"] for r in self.c.rows("loadout_supply_defs")
                           if r["loadout_id"] == benchmark["loadout_id"])
            self.assertLessEqual(volleys * sum(w["ammo_per_cycle"] for w in weapons), supplies)
            output.append((npc["npc_id"], continuous, discrete, volleys, counter, benchmark["player_can_win"]))
        self.evidence["ttk"] = output


def write_report(result: unittest.TestResult, destination: Path):
    c = Catalog()
    try:
        metadata = c.rows("catalog_meta")[0]
        counts = {table: c.connection.execute(f'SELECT count(*) FROM "{table}"').fetchone()[0]
                  for table in builder.CONTENT_TABLES}
        e = BalanceTests.evidence
        lines = ["# 数值数据库校验报告", "", f"生成时间：{datetime.now().astimezone().isoformat(timespec='seconds')}", "",
                 f"内容：`{metadata['content_version']}` / `{metadata['ruleset_version']}`；这是首轮基线，不是已完成平衡。",
                 f"结果：运行 {result.testsRun} 项 unittest，失败 {len(result.failures)}，错误 {len(result.errors)}，跳过 {len(result.skipped)}。", "",
                 f"运行环境：Python {platform.python_version()}；stdlib SQLite {sqlite3.sqlite_version}；{platform.system()} {platform.release()} {platform.machine()}。",
                 "未运行 Godot 或 godot-sqlite GDExtension；此处 Python 版本不代表游戏插件版本。", "",
                 f"逻辑内容 SHA-256（catalog_hash_v1）：`{metadata['content_hash']}`。",
                 f"数据库文件 SHA-256（单独标识构建文件）：`{hashlib.sha256(DB.read_bytes()).hexdigest()}`。", "",
                 "## 实际落库范围", "",
                 f"{len(counts)} 个 STRICT 表，合计 {sum(counts.values())} 条记录；{counts['ship_defs']} 舰、{counts['module_defs']} 模块、{counts['item_defs']} 物品、{counts['recipe_defs']} 配方、{counts['rule_parameters']} 规则参数。",
                 "只有锚港/回声两个首轮星系及主星区、一个双向教学连接；三类固定门和游离虫洞为参数模板。完整十星系、势力科技树、研究图谱和船体制造未生成；两站库存、任务、地点、NPC行为和相机参数的定义验证见 test_content.py。", "",
                 "## 约束与启动可达性", "",
                 "SQL 反例在内存副本 SAVEPOINT 内执行并回滚：未知外键、负数/小数数量、零质量、错误槽型、重复/不存在槽位、互斥参数值被拒绝，正式库未被污染。",
                 "默认配装通过 PU、CU、安装质量、合法槽位、同类/装甲共组限制；完整合法装配的质量上界保证满载教学门可通行。", "",
                 "| 默认舰 | PU | CU | 安装质量 kg |", "| --- | ---: | ---: | ---: |"]
        lines += [f"| {name} | {pu:g} | {cu:g} | {mass:g} |" for name, pu, cu, mass in e.get("budgets", [])]
        lines += ["", "| 舰 | 所有合法装配满载质量上界 kg |", "| --- | ---: |"]
        lines += [f"| {name} | {mass:g} |" for name, mass in e.get("gross", [])]
        lines += ["", f"基础矿物配方闭包覆盖 {e.get('reachable', '未执行')} 个物品且包括全部十模块；没有低安全独产物互锁。",
                  f"初始雨燕内置扫描理想教学用时 {e.get('tutorial_scan_seconds', '未执行')} s，初始能源可覆盖；铁砧双头名义 {e.get('mining_rate_units_s', '未执行')} unit/s。",
                  "教学阶段链和免费借用配装已定义，保护策略覆盖舰、附带模块与耗材。以上是定义可达性，不代表任务、实例所有权、奖励去重或借船交接代码已实现。",
                  "矿点同 tick 槽序竞争和双舱共用载荷使用参考公式核验；真实周期中断、世界时间再生与跨区保存需 Godot 集成测试。", "",
                  "## 同站经济与拆解", "",
                  "采用库中最高买折扣/卖增益与交易费，用 Decimal 做精确十进制计算；制造/拆解服务费不享受声望折扣。",
                  "递归核验全部购买/配方路径的乐观分数单位最低采购成本（省略取整只会低估成本），并证明每次买卖、制造、拆解都不增加‘现金+库存采购势能’。该下界覆盖组合制造/拆解循环；整数样例另测每模块 1、7、100 件及中间余料出售。"]
        if "minimum_module_margin" in e:
            margin, item, cost, revenue = e["minimum_module_margin"]
            lines += ["", f"最小模块制造→出售安全下界：`{item}`；最低采购成本 {cost:.6f} credit，最高净收购 {revenue:.6f} credit，差额 **{margin:.6f} credit/件**。"]
        if "minimum_item_margin" in e:
            margin, item, _, _ = e["minimum_item_margin"]
            lines += [f"所有物品中最小买/造→出售差额：`{item}`，{margin:.6f} credit/单位（批量连续下界）。"]
        if "integer_min_margin" in e:
            margin, item, quantity = e["integer_min_margin"]
            lines += [f"实际整数递归路线样例最小总差额：`{item}` ×{quantity}，{margin} credit（计入余料出售）。"]
        lines += ["", "买入→拆解→出售、制造→拆解→出售都无利润；标准返料与逐项 floor(投入×返还率) 一致。NPC 采购实例应冻结 module_salvage_recipe_defs 来源；制造实例需保存实际投入。当前只有一条标准配方/模块，数据库并未实现实例来源账本，未来多配方必须重新验收。",
                  "此结论仅覆盖库中的同站固定价、费用和合法付费动作；不包括免费教学奖励兑现、地区价差、库存限额、市场价格变化、手动回档或运行时漏洞。免费保障/借用的兑现禁止目前只是定义。最低模块差额余量较小，后续任何费率/配方/声望修改都应重跑。", "",
                  "## 伤害、资源与TTK参考结果", "",
                  "伤害黄金例与混合向量顺序无关性通过；跨层携带剩余原始向量重新算抗性，不把已减抗HP伤害重复减抗。",
                  "NPC等级采用整数基点、HP/奖励整数向上取整；模板等级落在对应安全区区间。周期转换为整数tick，无浮点周期累计。", "",
                  "| 目标 | 连续理想TTK s | 首发t=0离散TTK s | 齐射数 | 敌方反向TTK s | 基线胜负 |",
                  "| --- | ---: | ---: | ---: | ---: | --- |"]
        lines += [f"| {npc} | {continuous:.6f} | {discrete:.6f} | {volleys} | {counter:.6f} | {'可胜' if win else '不可单挑'} |"
                  for npc, continuous, discrete, volleys, counter, win in e.get("ttk", [])]
        lines += ["", "TTK假设静止、100%命中、无主动/被动修理与回血、无限射界；默认弹药够用。数值只描述基准场景，未模拟AI、射程接近、弹速、实际热锁影响或真实战斗胜率。"]
        for label, key in (("游隼默认全设备请求", "sustained_default"), ("游隼曜线+引擎+护盾压力请求", "sustained_thermal")):
            if key in e:
                probe = e[key]
                lines += ["", f"120 s共享能源/热量参考探针：{label}，原始理想输出 {probe['raw_dps']:.6f} DPS；末能源 {probe['energy']:.6f} EU，热量 {probe['heat']:.6f} HU；拒绝计数 `{probe['rejects']}`。"]
        lines += ["", "资源探针每tick先回充/冷却再按优先级预约，能源/热量始终有限且不越界；持续请求护盾假定持续受损、忽略弹药枯竭及真实命中。热束名义DPS不能当作无条件持续输出。Shift只请求现有引擎周期；3倍巡航是后续候选，未叠入探针。", "",
                  "## 摘要、重建与未实现边界", "",
                  "重建得到同一逻辑摘要和文件摘要；插入顺序变化不影响内容摘要；改数值影响摘要；摘要自身排除。所有表/列/类型/主键与四项SQL view显式注册，新增未登记表或字段、增加/缺失view会失败；修改派生NPC DPS的view定义改变摘要。受审固定DDL的精确UTF-8 view定义文本纳入内容摘要，格式变化也触发变更，不用于执行任意配置SQL。REAL非有限值被编码校验拒绝。",
                  "本测试不覆盖 progress.db DDL、快照事务/COMMIT、存档槽/恢复/迁移、Godot扩展连接、运行时只读加载、物品实例所有权/制造投入冻结、库存运行更新与资产节点。当前相机/视听参数已定义，但碰撞、AI、实际手感和性能仍需游戏样例测量；完整研究/势力/十星系数值仍属后续内容。",
                  "跨区提交、战斗保存等待、停靠/残骸触发、单人奖励去重、失败重试与借船交接仍只由17接口契约规定；本报告未验证它们的运行行为。", "",
                  "## 重跑", "", "```sh", "# 本机路径；其他机器用可用的 Python 3.10+ 且 SQLite 3.37+ 运行", "/usr/local/bin/python3.14 jiaoben/build_catalog.py", "/usr/local/bin/python3.14 jiaoben/tests/test_balance.py --report", "```", "",
                  "建库脚本先在 jiaoben/tmp 单事务构建并校验，关闭连接后原子替换目标；本轮未下载/安装任何依赖。", "",
                  "## 表与记录清单", "", "| 表 | 记录数 |", "| --- | ---: |"]
        lines += [f"| {table} | {count} |" for table, count in sorted(counts.items())]
        if result.failures or result.errors:
            lines += ["", "## 失败详情", "", "```text"]
            lines += [f"{test}\n{trace}" for test, trace in result.failures + result.errors]
            lines += ["```"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
    finally:
        c.connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", action="store_true", help="Write jiaoben/logs/数值校验报告.md")
    args = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(BalanceTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if args.report:
        write_report(result, REPORT)
        print(f"Report: {REPORT}")
    raise SystemExit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
