"""Industrial escrow, immutable upgrades and bounded regional pricing."""
from pathlib import Path
import sqlite3
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog
import progress_fixture as p


class IndustryData(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
        cls.source.execute("PRAGMA foreign_keys=ON")

    @classmethod
    def tearDownClass(cls):
        cls.source.close()

    def test_existing_civilization_rules_are_exactly_preserved(self):
        old = sqlite3.connect((ROOT / "code/data/catalog_civilizations_v8.db").as_uri() + "?mode=ro", uri=True)
        self.addCleanup(old.close)
        self.assertEqual(p.adapter_hash(old), "85b7a7432b63f5100e38844396d9d9586083a9dd886dffd00333af305ef04e5c")
        for (name,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
            self.assertEqual(sorted(old.execute(f'SELECT * FROM "{name}"').fetchall(), key=repr), sorted(self.source.execute(f'SELECT * FROM "{name}"').fetchall(), key=repr), name)

    def test_all_blueprints_have_one_positive_duration_and_real_materials(self):
        build_catalog.validate_database(self.source)
        recipes = self.source.execute("SELECT count(*) FROM recipe_defs").fetchone()[0]
        hulls = self.source.execute("SELECT count(*) FROM hull_recipe_defs").fetchone()[0]
        self.assertEqual(self.source.execute("SELECT count(*) FROM industry_recipe_defs").fetchone()[0], recipes + hulls)
        self.assertEqual(self.source.execute("SELECT count(*) FROM industry_recipe_defs WHERE duration_per_batch_s<=0 OR ((recipe_id IS NULL)=(hull_recipe_id IS NULL))").fetchone()[0], 0)

    def test_maximum_supply_reward_is_below_discounted_minimum_purchase_price(self):
        bp = self.source.execute("SELECT price_min_bp FROM industry_balance_defs").fetchone()[0]
        discount = self.source.execute("SELECT value_real FROM rule_parameters WHERE parameter_id='max_buy_discount_ratio'").fetchone()[0]
        fee = self.source.execute("SELECT value_real FROM rule_parameters WHERE parameter_id='trade_fee_ratio'").fetchone()[0]
        for name, reward, ask in self.source.execute("SELECT d.demand_id,d.unit_reward_credit,i.base_ask_credit FROM station_demand_defs d JOIN item_defs i USING(item_id)"):
            self.assertLess(reward, ask * bp / 10000 * (1 - discount) * (1 + fee), name)


class IndustrySealing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
        cls.db = p.connect()
        p.apply_migrations(cls.db)
        cls.initial, cls.content = p.new_world(cls.db, cls.source)

    @classmethod
    def tearDownClass(cls):
        cls.db.close(); cls.source.close()

    def setUp(self):
        self.db.execute("BEGIN IMMEDIATE; ")
        self.db.execute("PRAGMA defer_foreign_keys=ON")
        p.begin_snapshot(self.db, "industry-candidate", "world-a", self.content, 2)
        p.copy_state(self.db, self.initial, "industry-candidate", "world-a", self.content)
        self.ctx = {"snapshot_id": "industry-candidate", "world_id": "world-a", "content_snapshot_id": self.content}
        self.player = self.db.execute("SELECT player_id FROM player_state WHERE snapshot_id=?", (self.initial,)).fetchone()[0]

    def tearDown(self):
        self.db.rollback()

    def seal(self):
        self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='industry-candidate'")

    def job(self, id_="job", status="running", sequence=1):
        blueprint, recipe, duration = self.db.execute("SELECT blueprint_id,recipe_id,duration_per_batch_s FROM frozen_industry_recipe_defs WHERE content_snapshot_id=? AND recipe_id IS NOT NULL LIMIT 1", (self.content,)).fetchone()
        station = self.db.execute("SELECT station_id FROM frozen_recipe_access_defs WHERE content_snapshot_id=? AND recipe_id=? LIMIT 1", (self.content, recipe)).fetchone()[0]
        p.insert(self.db, "industry_job_state", {**self.ctx, "job_id": id_, "player_id": self.player, "station_id": station, "blueprint_id": blueprint, "batches": 1, "status": status, "queue_sequence": sequence, "duration_s": duration, "remaining_s": duration if status not in ("ready", "claimed") else 0, "paid_credit": 1, "created_tick": 0, "finished_tick": 0})
        for item, quantity in self.db.execute("SELECT item_id,quantity FROM frozen_recipe_inputs WHERE content_snapshot_id=? AND recipe_id=?", (self.content, recipe)).fetchall():
            p.insert(self.db, "industry_input_state", {**self.ctx, "job_id": id_, "item_id": item, "quantity": quantity})

    def test_missing_regional_need_cannot_seal(self):
        self.db.execute("DELETE FROM station_demand_state WHERE snapshot_id='industry-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "coverage"):
            self.seal()

    def test_overlong_benefit_cannot_seal(self):
        self.db.execute("UPDATE station_demand_state SET benefit_remaining_s=1e9 WHERE snapshot_id='industry-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "frozen limits"):
            self.seal()

    def test_material_escrow_cannot_be_forged(self):
        self.job()
        self.db.execute("UPDATE industry_input_state SET quantity=quantity+1 WHERE snapshot_id='industry-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "escrow quantity"):
            self.seal()

    def test_material_escrow_cannot_be_omitted(self):
        self.job()
        self.db.execute("DELETE FROM industry_input_state WHERE snapshot_id='industry-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "escrow incomplete"):
            self.seal()

    def test_two_simultaneous_running_jobs_cannot_seal(self):
        self.job(); self.job("job2", sequence=2)
        with self.assertRaisesRegex(sqlite3.IntegrityError, "multiple active"):
            self.seal()

    def test_claimed_module_needs_a_production_receipt(self):
        self.job(status="claimed")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "production receipt"):
            self.seal()

    def test_valid_job_and_needs_seal_and_become_immutable(self):
        self.job(); self.seal()
        for table in ("industry_job_state", "industry_input_state", "station_demand_state"):
            with self.assertRaisesRegex(sqlite3.IntegrityError, "immutable"):
                self.db.execute(f"DELETE FROM {table} WHERE snapshot_id='industry-candidate'")


if __name__ == "__main__":
    unittest.main()
