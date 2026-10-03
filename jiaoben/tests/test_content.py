#!/usr/bin/env python3
"""Validate B catalog content and independent reference contract scenarios.

Reference state below lives only in tests; it is not Godot mission/economy code.
All game parameters come from catalog.db. Synthetic IDs/times are test inputs.
"""
from __future__ import annotations

from collections import Counter
from decimal import Decimal, ROUND_CEILING
import math
from pathlib import Path
import sqlite3
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog as builder

DB = ROOT / "code/data/catalog.db"


class Content:
    def __init__(self):
        self.db = sqlite3.connect(DB.as_uri() + "?mode=ro", uri=True)
        self.db.row_factory = sqlite3.Row
        self.rules = {row["parameter_id"]: row["value_integer"] if row["value_integer"] is not None
                      else row["value_real"] for row in self.rows("rule_parameters")}

    def rows(self, table):
        return [dict(row) for row in self.db.execute(f'SELECT * FROM "{table}"')]

    def index(self, table, key):
        return {row[key]: row for row in self.rows(table)}

    def copy(self):
        db = sqlite3.connect(":memory:")
        self.db.backup(db)
        db.execute("PRAGMA foreign_keys=ON")
        return db


class ContractReference:
    """Small independent ledger model for reward, receipt and loan counterexamples."""
    def __init__(self, content, mission_id):
        self.c = content
        self.mission = content.index("mission_defs", "mission_id")[mission_id]
        self.reward = content.index("mission_reward_defs", "mission_id")[mission_id]["reward_credit"]
        self.state = "available"
        self.sequence = 0
        self.attempt = None
        self.settled = set()
        self.receipts = set()
        self.collected = 0
        self.inventory = Counter()
        self.wreck = Counter()
        self.cash = 0
        self.last_settle = -math.inf
        self.last_failure = -math.inf
        self.accepted_windows = Counter()
        self.completed_windows = Counter()
        self.loan = None
        self.invalidated_loans = set()
        self.loan_generation = 0
        self.operation_units = 0
        self.collect_event_units = Counter()
        self.accepted_at_s = None
        self.deadline_remaining_s = None

    def loan_definition(self):
        return next(row for row in self.c.rows("loan_service_defs")
                    if row["required_mission_id"] == self.mission["mission_id"])

    def window(self, now):
        return math.floor(now / self.mission["repeat_window_s"]) if self.mission["repeatable"] else 0

    def accept(self, now, station):
        if self.state in ("active", "ready") or self.loan is not None:
            raise ValueError("active_contract_or_loan")
        if station != self.mission["accept_station_id"]:
            raise ValueError("wrong_station")
        if not self.mission["repeatable"] and self.settled:
            raise ValueError("already_completed")
        if self.mission["repeatable"] and now < self.last_failure + self.c.rules["contract_failure_retry_cooldown_s"]:
            raise ValueError("failure_cooldown")
        window = self.window(now)
        if self.mission["repeatable"] and (
            now < self.last_settle + self.mission["repeat_cooldown_s"] or
            self.completed_windows[window] >= self.mission["max_completions_per_window"] or
            self.accepted_windows[window] >= self.c.rules["contract_max_accepts_per_window"]
        ):
            raise ValueError("window_or_cooldown")
        self.sequence += 1
        self.attempt = (self.mission["mission_id"], self.sequence)
        self.state = "active"
        self.accepted_at_s = now
        self.deadline_remaining_s = self.mission["deadline_s"]
        self.accepted_windows[window] += 1
        self.collected = self.operation_units = 0
        return self.attempt

    def checkout(self):
        if self.state not in ("active", "ready") or self.loan is not None:
            raise ValueError("ineligible_loan")
        self.loan_generation += 1
        self.loan = (self.attempt, self.loan_generation)
        return self.loan

    def destroy_loan(self):
        if self.loan is None:
            raise ValueError("missing_loan")
        self.invalidated_loans.add(self.loan)
        self.loan = None
        # This reference's inventory represents cargo before handoff. Destruction
        # removes it; normal recovery exists once in a separate wreck, never a new ship.
        if self.loan_definition()["gathered_policy_id"] != "mission_bound":
            ratio = self.c.rules["wreck_cargo_recovery_ratio"]
            self.wreck.update({item: math.floor(quantity * ratio) for item, quantity in self.inventory.items()})
        self.inventory.clear()
        # Mission state, attempt, deadline, historical progress and ordinary quota remain.

    def replace_destroyed(self):
        if self.loan is not None:
            self.destroy_loan()
        return self.checkout()

    def mine(self, event_id, node_id, units):
        objective = next(row for row in self.c.rows("mission_objective_defs")
                         if row["mission_id"] == self.mission["mission_id"] and row["objective_kind"] == "collect")
        if self.state not in ("active", "ready") or node_id != objective["target_node_id"] or event_id in self.receipts:
            raise ValueError("invalid_receipt")
        loan = self.loan_definition()
        used = self.inventory[objective["target_item_id"]] if loan["gathered_policy_id"] == "mission_bound" else self.operation_units
        if self.loan is None or units <= 0 or used + units > loan["operation_quota_units"]:
            raise ValueError("quota_or_loan")
        self.receipts.add(event_id)
        self.operation_units += units
        allocated = min(units, max(0, objective["required_count"] - self.collected))
        self.collected += allocated
        if allocated:
            self.collect_event_units[event_id] = allocated
        self.inventory[objective["target_item_id"]] += units

    def ready(self):
        objectives = [row for row in self.c.rows("mission_objective_defs")
                      if row["mission_id"] == self.mission["mission_id"] and row["objective_kind"] == "collect"]
        if any(self.collected < row["required_count"] for row in objectives):
            raise ValueError("collect_not_met")
        self.state = "ready"

    def claim(self, now, station, safe_switch=True):
        if self.attempt in self.settled:
            return "already_applied"
        if self.state != "ready" or station != self.mission["turnin_station_id"]:
            raise ValueError("not_ready_or_wrong_station")
        if self.loan is not None and not safe_switch:
            raise ValueError("no_safe_switch")
        delivery = [row for row in self.c.rows("mission_objective_defs")
                    if row["mission_id"] == self.mission["mission_id"] and row["consume_item"]]
        if any(self.inventory[row["target_item_id"]] < row["required_count"] for row in delivery):
            raise ValueError("missing_delivery")
        # Candidate checks precede every mutation. Extra normal cargo remains in warehouse.
        for row in delivery:
            self.inventory[row["target_item_id"]] -= row["required_count"]
        if self.loan is not None:
            self.invalidated_loans.add(self.loan)
            self.loan = None
        self.cash += self.reward
        self.settled.add(self.attempt)
        self.completed_windows[self.window(now)] += 1
        self.last_settle = now
        self.state = "completed"
        return "applied"

    def fail(self, now):
        if self.mission["deadline_s"] is None or now < self.accepted_at_s + self.mission["deadline_s"]:
            raise ValueError("no_active_failure_condition")
        self.state = "failed"
        self.last_failure = now
        self.deadline_remaining_s = 0

    def abandon(self, now, station):
        if station != self.mission["turnin_station_id"]:
            raise ValueError("return_cleanup_required")
        self.return_failed_loan()
        if self.loan_definition()["gathered_policy_id"] == "mission_bound":
            self.inventory.clear()
        self.state = "abandoned"
        self.last_failure = now

    def return_failed_loan(self):
        if self.loan is not None:
            self.invalidated_loans.add(self.loan)
            self.loan = None


class ContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = Content()

    @classmethod
    def tearDownClass(cls):
        cls.c.db.close()

    def copy(self):
        db = self.c.copy()
        self.addCleanup(db.close)
        return db

    def test_full_registry_and_versioned_identity(self):
        db = self.copy()
        builder.validate_database(db)
        self.assertEqual(set(builder.CONTENT_COLUMNS), set(builder.CONTENT_TABLES))
        metadata = self.c.rows("catalog_meta")[0]
        self.assertEqual(metadata["content_version"], "v0.5-integrity")
        self.assertEqual(metadata["ruleset_version"], "singleplayer_v0_5")
        self.assertEqual(metadata["schema_version"], self.c.db.execute("PRAGMA user_version").fetchone()[0])
        self.assertEqual(metadata["content_hash"], builder.logical_content_hash(db))
        self.assertEqual(len(builder.content_views(db)), 4)

    def test_ten_runtime_sectors_and_closed_location_refs(self):
        runtime = self.c.index("sector_runtime_defs", "sector_id")
        self.assertEqual(len(runtime), 10)
        self.assertTrue({"sector_anchor", "sector_echo"} <= set(runtime))
        self.assertTrue(all(row["enabled"] and row["stage_code"] in {"B", "C", "D"} for row in runtime.values()))
        self.assertEqual(set(self.c.index("resource_node_defs", "node_id")), set(self.c.index("resource_node_locations", "node_id")))
        builder.validate_content_graph(self.copy())

    def test_sql_rejects_invalid_target_stock_and_typed_values(self):
        db = self.copy()
        cases = [
            "UPDATE station_stock_defs SET initial_units=-1",
            "UPDATE station_stock_defs SET target_units=hard_cap_units+1",
            "UPDATE mission_defs SET repeat_window_s=0 WHERE repeatable=1",
            "UPDATE mission_objective_defs SET target_item_id='ore_ferrosilicate' WHERE objective_kind='dock'",
            "UPDATE mission_objective_defs SET target_signal_id=NULL WHERE objective_kind='scan_signal'",
            "UPDATE loan_service_defs SET max_active_instances=2",
            "UPDATE loan_service_defs SET policy_id='unknown_policy'",
            "UPDATE npc_behavior_defs SET projectile_speed_mps=NULL WHERE fire_mode='projectile'",
            "UPDATE camera_profile_defs SET near_m=far_m",
            "UPDATE presentation_defs SET value_integer=1,value_real=2",
        ]
        before = builder.logical_content_hash(db)
        for sql in cases:
            with self.subTest(sql=sql):
                db.execute("SAVEPOINT invalid")
                with self.assertRaises(sqlite3.IntegrityError):
                    db.execute(sql)
                db.execute("ROLLBACK TO invalid")
                db.execute("RELEASE invalid")
        self.assertEqual(before, builder.logical_content_hash(db))

    def test_missing_return_endpoint_and_exit_retrigger_are_rejected(self):
        for sql in ("DELETE FROM gate_endpoint_defs WHERE endpoint_id='endpoint_echo_anchor'",
                    "UPDATE anchor_defs SET z_m=3000 WHERE anchor_id='anchor_echo_gate_exit'"):
            with self.subTest(sql=sql):
                db = self.copy()
                db.execute(sql)
                with self.assertRaises(ValueError):
                    builder.validate_content_graph(db)

    def test_npc_risk_and_safe_zone_overlap_are_rejected(self):
        for sql in ("UPDATE npc_spawn_defs SET npc_id='npc_guardian_heavy_l6' WHERE spawn_id='spawn_echo_raider'",
                    "UPDATE anchor_defs SET x_m=0,y_m=0,z_m=0 WHERE anchor_id='anchor_anchor_tutorial_scout'"):
            with self.subTest(sql=sql):
                db = self.copy()
                db.execute(sql)
                with self.assertRaises(ValueError):
                    builder.validate_content_graph(db)

    def test_prerequisite_and_unlock_cycles_are_rejected(self):
        cases = [
            "INSERT INTO mission_prerequisites VALUES('tutorial_flight','tutorial_exploration')",
            "UPDATE mission_defs SET required_unlock_id='unlock_lantern_purchase' WHERE mission_id='tutorial_exploration'",
            "UPDATE signal_defs SET required_unlock_id='unlock_anchor_echo_gate' WHERE signal_id='signal_anchor_gate_calibration'",
        ]
        for sql in cases:
            with self.subTest(sql=sql):
                db = self.copy()
                db.execute(sql)
                with self.assertRaises(ValueError):
                    builder.validate_content_graph(db)

    def test_tutorial_summary_reward_prerequisite_and_delivery_agree(self):
        rewards = self.c.index("mission_reward_defs", "mission_id")
        for step in self.c.rows("tutorial_step_defs"):
            self.assertEqual(rewards[step["step_id"]]["reward_credit"], step["reward_credit"])
            if step["required_item_id"]:
                deliveries = [row for row in self.c.rows("mission_objective_defs")
                              if row["mission_id"] == step["step_id"] and row["objective_kind"] == "deliver"]
                self.assertEqual([(row["target_item_id"], row["required_count"]) for row in deliveries],
                                 [(step["required_item_id"], step["required_quantity"])])

    def test_free_loans_and_bound_sample_do_not_require_market(self):
        policies = self.c.index("asset_policy_defs", "policy_id")
        for loan in self.c.rows("loan_service_defs"):
            self.assertEqual(loan["fee_credit"], 0)
            policy = policies[loan["policy_id"]]
            self.assertFalse(policy["may_sell"] or policy["may_recycle"])
            self.assertTrue(policy["inherit_to_attached"] and policy["inherit_to_supplies"])
        miner = self.c.index("loan_service_defs", "loan_service_id")["loan_tutorial_miner"]
        self.assertEqual(miner["gathered_policy_id"], "mission_bound")
        self.assertTrue(all(row["policy_id"] == "normal_owned" for row in self.c.rows("starting_inventory_policy_defs")))
        teaching = self.c.index("npc_spawn_defs", "spawn_id")["spawn_anchor_tutorial_scout"]
        self.assertFalse(teaching["bounty_enabled"] or teaching["loot_enabled"])

    def test_stock_catchup_clamps_to_target_and_not_wall_clock(self):
        for stock in self.c.rows("station_stock_defs"):
            quantity = max(0, stock["initial_units"] - stock["restock_units_per_refresh"])
            for elapsed_refreshes in (0, 1, 100):  # Synthetic simulation-time tick counts.
                added = min(max(0, stock["target_units"] - quantity), elapsed_refreshes * stock["restock_units_per_refresh"])
                final = quantity + added
                self.assertLessEqual(final, stock["target_units"])
                self.assertLessEqual(final, stock["hard_cap_units"])
                if elapsed_refreshes == 0:
                    self.assertEqual(final, quantity)
            sold_above_target = stock["hard_cap_units"]
            added = min(max(0, stock["target_units"] - sold_above_target), stock["restock_units_per_refresh"])
            self.assertEqual(added, 0)

    def test_buyback_has_stock_budget_and_quantity_bounds(self):
        items = self.c.index("item_defs", "item_id")
        stations = self.c.index("station_defs", "station_id")
        for stock in self.c.rows("station_stock_defs"):
            bid = items[stock["item_id"]]["base_bid_credit"]
            bound = min(stock["buyback_units_per_refresh"], stock["hard_cap_units"] - stock["initial_units"])
            if bid:
                bound = min(bound, stations[stock["station_id"]]["buyback_budget_credit"] // bid)
            self.assertGreaterEqual(bound, 0)
            self.assertLessEqual(stock["initial_units"] + bound, stock["hard_cap_units"])
            self.assertLessEqual(bound * bid, stations[stock["station_id"]]["buyback_budget_credit"])

    def test_bare_hull_buyback_loses_money_and_respects_capacity(self):
        fee = Decimal(str(self.c.rules["trade_fee_ratio"]))
        discount = Decimal(str(self.c.rules["max_buy_discount_ratio"]))
        bonus = Decimal(str(self.c.rules["max_sell_bonus_ratio"]))
        ships = self.c.index("ship_defs", "ship_id")
        stations = self.c.index("station_defs", "station_id")
        for stock in self.c.rows("station_ship_stock_defs"):
            ship = ships[stock["ship_id"]]
            cheapest_buy = Decimal(ship["base_ask_credit"]) * (1 - discount) * (1 + fee)
            greatest_sale = Decimal(ship["base_bid_credit"]) * (1 + bonus) * (1 - fee)
            self.assertGreater(cheapest_buy, greatest_sale)
            self.assertGreater(stock["hard_cap_units"] - stock["initial_units"], 0)
            self.assertGreaterEqual(stations[stock["station_id"]]["buyback_budget_credit"], ship["base_bid_credit"])

    def test_all_modules_have_market_and_recipe_routes_after_tutorial(self):
        modules = set(self.c.index("module_defs", "module_id"))
        market = {row["item_id"] for row in self.c.rows("station_stock_defs") if row["station_id"] == "station_anchor_port" and row["allow_buy"]}
        outputs = {row["output_item_id"] for row in self.c.rows("recipe_defs")}
        self.assertTrue({m for m in modules if m.endswith("_i")} <= market & outputs)
        self.assertTrue(modules <= outputs)
        self.assertEqual(set(self.c.index("recipe_defs", "recipe_id")), {row["recipe_id"] for row in self.c.rows("recipe_access_defs")})

    def test_permanent_lantern_and_industrial_ship_income_routes(self):
        fee = Decimal(str(self.c.rules["trade_fee_ratio"]))
        ships = self.c.index("ship_defs", "ship_id")
        items = self.c.index("item_defs", "item_id")
        starting = self.c.rows("starting_profile_defs")[0]["starting_credit"]
        starting += sum(row["reward_credit"] for row in self.c.rows("tutorial_step_defs"))
        reward = self.c.index("mission_reward_defs", "mission_id")["contract_mining_iron"]["reward_credit"]
        for ship_id in ("frigate_lantern", "miner_anvil"):
            loadout = next(row["loadout_id"] for row in self.c.rows("ship_loadout_defs") if row["ship_id"] == ship_id)
            quantities = Counter(row["module_id"] for row in self.c.rows("ship_loadout_items") if row["loadout_id"] == loadout)
            quantities.update({row["item_id"]: row["quantity"] for row in self.c.rows("loadout_supply_defs") if row["loadout_id"] == loadout})
            price = lambda ask, quantity: int((Decimal(ask) * quantity * (1 + fee)).to_integral_value(rounding=ROUND_CEILING))
            expense = price(ships[ship_id]["base_ask_credit"], 1) + sum(price(items[item]["base_ask_credit"], quantity) for item, quantity in quantities.items())
            count = math.ceil(max(0, expense - starting) / reward)
            self.assertLess(starting + (count - 1) * reward, expense)
            self.assertGreaterEqual(starting + count * reward, expense)
            stock = [row for row in self.c.rows("station_ship_stock_defs") if row["ship_id"] == ship_id]
            self.assertTrue(stock and stock[0]["initial_units"] > 0)
            print(f"Income witness {ship_id}: cost={expense}, tutorial_cash={starting}, mining_contracts={count}, cash_left={starting + count * reward - expense}")

    def test_wrong_station_missing_delivery_and_double_claim_are_atomic(self):
        ref = ContractReference(self.c, "contract_mining_iron")
        station = ref.mission["accept_station_id"]
        ref.accept(0, station)
        ref.checkout()
        quantity = next(row["required_count"] for row in self.c.rows("mission_objective_defs")
                        if row["mission_id"] == ref.mission["mission_id"] and row["objective_kind"] == "collect")
        ref.mine("receipt1", "node_echo_ferrosilicate", quantity)
        ref.ready()
        snapshot = (ref.cash, dict(ref.inventory), ref.loan)
        for wrong_station, safe_switch in (("station_echo_depot", True), (station, False)):
            with self.assertRaises(ValueError):
                ref.claim(1, wrong_station, safe_switch)
            self.assertEqual((ref.cash, dict(ref.inventory), ref.loan), snapshot)
        ref.inventory.clear()  # Player sold cargo: historical collect is not delivery.
        with self.assertRaises(ValueError):
            ref.claim(1, station)
        self.assertEqual(ref.cash, 0)
        ref.inventory["ore_ferrosilicate"] = quantity
        self.assertEqual(ref.claim(2, station), "applied")
        self.assertEqual(ref.claim(2, station), "already_applied")
        self.assertEqual(ref.cash, ref.reward)
        self.assertEqual(ref.inventory["ore_ferrosilicate"], 0)

    def test_collect_receipts_are_scoped_and_replacement_preserves_quota(self):
        ref = ContractReference(self.c, "contract_mining_iron")
        ref.accept(0, ref.mission["accept_station_id"])
        old = ref.checkout()
        ref.mine("receipt1", "node_echo_ferrosilicate", 300)
        for event_id, node in (("receipt1", "node_echo_ferrosilicate"), ("receipt2", "node_echo_conductive")):
            with self.assertRaises(ValueError):
                ref.mine(event_id, node, 1)
        new = ref.replace_destroyed()
        self.assertNotEqual(old, new)
        self.assertIn(old, ref.invalidated_loans)
        self.assertEqual(ref.operation_units, 300)
        self.assertEqual(ref.inventory["ore_ferrosilicate"], 0)
        self.assertEqual(ref.wreck["ore_ferrosilicate"], 150)
        with self.assertRaises(ValueError):
            ref.checkout()
        ref.mine("receipt2", "node_echo_ferrosilicate", 300)
        with self.assertRaises(ValueError):
            ref.mine("receipt3", "node_echo_ferrosilicate", 1)
        ref.inventory.update(ref.wreck)  # Explicit unique wreck retrieval.
        ref.wreck.clear()
        ref.ready()
        ref.claim(1, ref.mission["turnin_station_id"])
        self.assertEqual(ref.inventory["ore_ferrosilicate"], 150)  # Recovered normal surplus moved before return.
        self.assertIn(new, ref.invalidated_loans)
        self.assertIsNone(ref.loan)

    def test_repeat_cooldown_window_and_fail_retry_do_not_pay(self):
        ref = ContractReference(self.c, "contract_survey_echo")
        station = ref.mission["accept_station_id"]
        now = 0
        for _ in range(ref.mission["max_completions_per_window"]):
            ref.accept(now, station)
            ref.ready()
            ref.claim(now, station)
            with self.assertRaises(ValueError):
                ref.accept(now, station)
            now += ref.mission["repeat_cooldown_s"]
        with self.assertRaises(ValueError):
            ref.accept(now, station)
        ref.accept(ref.mission["repeat_window_s"], station)
        before = ref.cash
        expired = ref.mission["repeat_window_s"] + ref.mission["deadline_s"]
        ref.fail(expired)
        with self.assertRaises(ValueError):
            ref.accept(expired, station)
        ref.accept(expired + self.c.rules["contract_failure_retry_cooldown_s"], station)
        self.assertEqual(ref.cash, before)
        # An accepted contract may settle in the next world-time window.
        carry = ContractReference(self.c, "contract_survey_echo")
        boundary = carry.mission["repeat_window_s"]
        carry.accept(boundary - 1, station)
        carry.ready()
        carry.claim(boundary + 1, station)
        self.assertEqual(carry.accepted_windows[1], 0)
        self.assertEqual(carry.completed_windows[1], 1)
        self.assertEqual(carry.cash, carry.reward)

    def test_ship_loss_preserves_active_or_ready_attempt_and_deadline(self):
        for ready_before_loss in (False, True):
            with self.subTest(ready=ready_before_loss):
                ref = ContractReference(self.c, "contract_survey_echo")
                station = ref.mission["accept_station_id"]
                attempt = ref.accept(0, station)
                old = ref.checkout()
                if ready_before_loss:
                    ref.ready()
                state, deadline = ref.state, ref.deadline_remaining_s
                accepted = dict(ref.accepted_windows)
                ref.destroy_loan()
                self.assertEqual((ref.state, ref.attempt, ref.deadline_remaining_s), (state, attempt, deadline))
                self.assertEqual(dict(ref.accepted_windows), accepted)
                self.assertEqual(ref.last_failure, -math.inf)
                new = ref.replace_destroyed()
                self.assertNotEqual(new, old)
                self.assertEqual(ref.attempt, attempt)
                self.assertEqual(ref.state, state)
                self.assertEqual(ref.cash, 0)
                ref.ready()
                ref.claim(1, station)
                self.assertEqual(ref.cash, ref.reward)
        tutorial = ContractReference(self.c, "tutorial_mining_delivery")
        tutorial.accept(0, tutorial.mission["accept_station_id"])
        tutorial.checkout()
        tutorial.destroy_loan()
        with self.assertRaises(ValueError):
            tutorial.fail(100000)
        self.assertEqual(tutorial.state, "active")

    def test_tutorial_lost_samples_replenish_without_repeating_collect(self):
        ref = ContractReference(self.c, "tutorial_mining_delivery")
        station = ref.mission["accept_station_id"]
        attempt = ref.accept(0, station)
        ref.checkout()
        units = ref.loan_definition()["operation_quota_units"]
        ref.mine("original_samples", "node_echo_ferrosilicate", units)
        ref.ready()
        collect_proof = dict(ref.collect_event_units)
        ref.destroy_loan()
        self.assertEqual(ref.state, "ready")
        self.assertEqual(ref.collected, units)
        self.assertFalse(ref.wreck)
        with self.assertRaises(ValueError):
            ref.claim(1, station)
        ref.replace_destroyed()
        ref.mine("replacement_samples", "node_echo_ferrosilicate", units)
        self.assertEqual(ref.attempt, attempt)
        self.assertEqual(dict(ref.collect_event_units), collect_proof)
        self.assertEqual(ref.collected, units)
        with self.assertRaises(ValueError):
            ref.mine("too_many_samples", "node_echo_ferrosilicate", 1)
        ref.claim(2, station)
        self.assertEqual(ref.cash, ref.reward)
        self.assertEqual(ref.claim(3, station), "already_applied")

    def test_exhausted_normal_quota_keeps_delivery_recovery_and_abandon_limits(self):
        for recover_from_wreck in (True, False):
            with self.subTest(wreck=recover_from_wreck):
                ref = ContractReference(self.c, "contract_mining_iron")
                station = ref.mission["accept_station_id"]
                ref.accept(0, station)
                ref.checkout()
                quota = ref.loan_definition()["operation_quota_units"]
                ref.mine("quota_all", "node_echo_ferrosilicate", quota)
                ref.ready()
                ref.destroy_loan()
                ref.replace_destroyed()
                self.assertEqual(ref.operation_units, quota)
                with self.assertRaises(ValueError):
                    ref.mine("extra_after_replace", "node_echo_ferrosilicate", 1)
                required = next(row["required_count"] for row in self.c.rows("mission_objective_defs")
                                if row["mission_id"] == ref.mission["mission_id"] and row["objective_kind"] == "deliver")
                if recover_from_wreck:
                    ref.inventory.update(ref.wreck)
                    ref.wreck.clear()
                else:
                    ref.wreck.clear()  # Inaccessible/lost cargo; independent normal purchase witness.
                    ref.inventory["ore_ferrosilicate"] = required
                ref.claim(1, station)
                self.assertEqual(ref.cash, ref.reward)
        ref = ContractReference(self.c, "contract_mining_iron")
        station = ref.mission["accept_station_id"]
        first = ref.accept(0, station)
        ref.checkout()
        ref.abandon(1, station)
        with self.assertRaises(ValueError):
            ref.accept(1, station)
        second = ref.accept(1 + self.c.rules["contract_failure_retry_cooldown_s"], station)
        self.assertNotEqual(first, second)
        self.assertEqual(ref.accepted_windows[0], 2)
        self.assertEqual(ref.cash, 0)

    def test_tutorial_once_only_and_state_transition_guards(self):
        ref = ContractReference(self.c, "tutorial_flight")
        station = ref.mission["accept_station_id"]
        ref.accept(0, station)
        ref.ready()
        ref.claim(1, station)
        with self.assertRaises(ValueError):
            ref.accept(10000, station)
        transitions = {(row["from_state"], row["event_code"]): row for row in self.c.rows("mission_state_transitions")}
        self.assertNotIn(("completed", "claim"), transitions)
        self.assertEqual(transitions[("ready", "claim")]["guard_code"], "turnin_atomic")
        self.assertEqual(transitions[("completed", "repeat_wait")]["guard_code"], "repeatable")

    def test_npc_cycles_derive_damage_and_hit_checks_are_geometry(self):
        archetypes = self.c.index("npc_archetype_defs", "archetype_id")
        hz = self.c.rules["simulation_hz"]
        for behavior in self.c.rows("npc_behavior_defs"):
            self.assertTrue(math.isclose(behavior["attack_cycle_s"] * hz, round(behavior["attack_cycle_s"] * hz)))
            dps = archetypes[behavior["archetype_id"]]["base_raw_dps"]
            raw_per_attack = dps * behavior["attack_cycle_s"]
            self.assertTrue(math.isclose(raw_per_attack / behavior["attack_cycle_s"], dps))
            limit = math.cos(behavior["fire_cone_half_angle_rad"])
            self.assertGreater(1, limit)  # Forward target is eligible, perpendicular target is not.
            self.assertGreater(limit, 0)
            self.assertGreaterEqual(behavior["target_drop_range_m"], behavior["detection_range_m"])
        self.assertEqual(self.c.rules["npc_safe_zone_attack_enabled"], 0)
        self.assertEqual(self.c.rules["npc_return_healing_enabled"], 0)

    def test_camera_modes_and_presentation_budgets_are_complete(self):
        ships = self.c.index("ship_defs", "ship_id")
        for ship in ships:
            self.assertEqual({row["mode"] for row in self.c.rows("camera_profile_defs") if row["ship_id"] == ship}, {"follow", "front", "tactical"})
        params = {row["presentation_id"]: row["value_integer"] if row["value_integer"] is not None
                  else row["value_real"] for row in self.c.rows("presentation_defs")}
        self.assertLess(params["lod_near_m"], params["lod_mid_m"])
        self.assertLess(params["lod_mid_m"], params["lod_far_m"])
        self.assertLessEqual(params["engine_particles_mid"], params["engine_particles_near"])
        self.assertLessEqual(params["explosion_particles_mid"], params["explosion_particles_near"])
        self.assertGreaterEqual(params["fx_particle_budget_max"], params["explosion_particles_near"])

    def test_content_changes_affect_hash_without_balance_changes(self):
        for statement in (
            "UPDATE station_stock_defs SET target_units=target_units-1 WHERE initial_units>0",
            "UPDATE camera_profile_defs SET fov_deg=fov_deg+1",
            "UPDATE anchor_defs SET x_m=x_m+1 WHERE anchor_kind='signal'",
            "UPDATE mission_reward_defs SET reward_credit=reward_credit+1 WHERE mission_id='contract_mining_iron'",
        ):
            with self.subTest(statement=statement):
                db = self.copy()
                before = builder.logical_content_hash(db)
                balance = db.execute("SELECT * FROM ship_defs ORDER BY ship_id").fetchall()
                db.execute(statement)
                self.assertNotEqual(before, builder.logical_content_hash(db))
                self.assertEqual(balance, db.execute("SELECT * FROM ship_defs ORDER BY ship_id").fetchall())


if __name__ == "__main__":
    unittest.main(verbosity=2)
