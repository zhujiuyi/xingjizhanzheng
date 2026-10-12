"""Exploration definition closure, deterministic instances and SQL failure boundaries."""
import hashlib
from pathlib import Path
import sqlite3
import sys
import unittest
from catalog_review import without_later_extensions
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog
import progress_fixture as p


class ExplorationData(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
        cls.source.execute("PRAGMA foreign_keys=ON")

    @classmethod
    def tearDownClass(cls):
        cls.source.close()

    def test_six_structures_eighteen_variants_and_real_choices(self):
        build_catalog.validate_database(self.source)
        events = [e for e in p.rows(self.source, "exploration_event_defs") if not e["event_id"].startswith("exp_theme_")]
        self.assertEqual(len(events), 6)
        self.assertEqual({e["event_kind"] for e in events}, {"rescue", "relic", "mineral"})
        self.assertEqual({e["environment_kind"] for e in events}, {"fragments", "em", "solar"})
        self.assertEqual(len({e["sector_id"] for e in events}), 3)
        for event in events:
            variants = p.rows(self.source, "exploration_variant_defs", "event_id=?", (event["event_id"],))
            self.assertEqual({v["variant_index"] for v in variants}, {1, 2, 3})
            self.assertEqual(len({(v["duration_s"], v["enemy_count"], v["repair_units"], v["full_credit"]) for v in variants}), 3)

    def test_upgrade_appends_reviewed_names_and_preserves_all_old_values(self):
        old = sqlite3.connect((ROOT / "code/data/catalog_resource_v10.db").as_uri() + "?mode=ro", uri=True)
        self.addCleanup(old.close)
        self.assertEqual(p.adapter_hash(old), "343a339385e647658e747f8c0cb4da1ee042a4f2a33af594e2f7bac1e9ae1854")
        extensions = {"anchor_defs", "anchor_site_defs", "site_defs", "resource_node_defs", "resource_node_locations", "resource_grade_defs", "npc_defs", "npc_archetype_defs", "npc_behavior_defs", "npc_resistances", "npc_spawn_defs", "npc_patrol_points", "unlock_defs"}
        for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
            self.assertEqual(old.execute(f'PRAGMA table_info("{table}")').fetchall(), self.source.execute(f'PRAGMA table_info("{table}")').fetchall(), table)
            before = set(old.execute(f'SELECT * FROM "{table}"'))
            after = set(self.source.execute(f'SELECT * FROM "{table}"'))
            self.assertLessEqual(before, after, table)
            after = without_later_extensions(self.source, table, after)
            if table not in extensions:
                self.assertEqual(before, after, table)
            else:
                key = next(i for i, row in enumerate(old.execute(f'PRAGMA table_info("{table}")')) if row[5] == 1)
                self.assertTrue(all(row[key].startswith(("exp_", "belt_", "tac_", "op_")) for row in after - before), table)
        self.assertEqual(old.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall(), self.source.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name").fetchall())

    def test_managed_actors_have_no_free_bounty_or_respawn(self):
        rows = self.source.execute("SELECT s.occurrence_mode,s.respawn_s,s.bounty_enabled,s.loot_enabled FROM exploration_actor_defs e JOIN npc_spawn_defs s USING(spawn_id) WHERE e.event_id NOT LIKE 'exp_theme_%'").fetchall()
        self.assertEqual(len(rows), 20)
        self.assertTrue(all(row == ("mission_scoped", None, 0, 0) for row in rows))

    def test_migration015_failure_retains_format11_then_retries(self):
        db = p.connect(); self.addCleanup(db.close)
        with mock.patch.object(p, "MIGRATIONS", p.MIGRATIONS[:14]), mock.patch.object(p, "FORMAT_VERSION", 11):
            p.apply_migrations(db)
        p.insert(db, "profile", {"profile_id": "retained", "display_name": "旧资料", "created_utc": p.utc_now()})
        before = db.execute("SELECT type,name,sql FROM sqlite_schema ORDER BY type,name").fetchall()
        with self.assertRaises(sqlite3.OperationalError):
            p.apply_migrations(db, fault_after=15)
        self.assertEqual(before, db.execute("SELECT type,name,sql FROM sqlite_schema ORDER BY type,name").fetchall())
        self.assertEqual(db.execute("SELECT format_version FROM database_meta").fetchone(), (11,))
        p.apply_migrations(db)
        self.assertEqual(db.execute("SELECT format_version FROM database_meta").fetchone(), (p.FORMAT_VERSION,))
        self.assertEqual(db.execute("SELECT display_name FROM profile WHERE profile_id='retained'").fetchone(), ("旧资料",))


class ExplorationSealing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
        cls.db = p.connect(); p.apply_migrations(cls.db)
        cls.initial, cls.content = p.new_world(cls.db, cls.source)

    @classmethod
    def tearDownClass(cls):
        cls.db.close(); cls.source.close()

    def setUp(self):
        self.db.execute("BEGIN IMMEDIATE"); self.db.execute("PRAGMA defer_foreign_keys=ON")
        p.begin_snapshot(self.db, "explore-candidate", "world-a", self.content, 2)
        p.copy_state(self.db, self.initial, "explore-candidate", "world-a", self.content)
        self.ctx = p.context("explore-candidate", "world-a", self.content)
        self.event = p.rows(self.db, "exploration_instance_state", "snapshot_id=?", ("explore-candidate",))[0]
        self.variant = p.rows(self.source, "exploration_variant_defs", "variant_id=?", (self.event["variant_id"],))[0]

    def tearDown(self):
        self.db.rollback()

    def seal(self):
        self.db.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id='explore-candidate'")

    def claim(self):
        v = self.variant
        p.insert(self.db, "exploration_claim_state", {**self.ctx, "player_id": "player-local", "event_id": self.event["event_id"], "generation": 1, "variant_id": v["variant_id"], "outcome": "full", "credit_units": v["full_credit"], "insight_units": v["insight_units"], "reputation_units": v["reputation_units"], "demand_id": None, "demand_generation": 0, "claimed_tick": 2})
        self.db.execute("UPDATE exploration_instance_state SET phase='claimed',outcome='full' WHERE snapshot_id='explore-candidate' AND event_id=?", (self.event["event_id"],))
        self.db.execute("UPDATE exploration_progress_state SET insight_available=?,insight_earned=? WHERE snapshot_id='explore-candidate'", (v["insight_units"], v["insight_units"]))

    def test_seed_is_fixed_without_world_rng_draws(self):
        seed = self.db.execute("SELECT seed FROM world WHERE world_id='world-a'").fetchone()[0]
        for event in p.rows(self.db, "exploration_instance_state", "snapshot_id=?", (self.initial,)):
            expected = int(hashlib.sha256(f"{seed}:{event['event_id']}".encode()).hexdigest()[:8], 16)
            self.assertEqual(event["variant_seed"], expected)
            variants = p.rows(self.source, "exploration_variant_defs", "event_id=? ORDER BY variant_index", (event["event_id"],))
            self.assertEqual(event["variant_id"], variants[expected % 3]["variant_id"])
        self.assertEqual(self.db.execute("SELECT insight_available,insight_earned FROM exploration_progress_state WHERE snapshot_id=?", (self.initial,)).fetchone(), (0, 0))
        self.assertEqual(self.db.execute("SELECT sum(remaining_units) FROM resource_state WHERE snapshot_id=? AND node_id IN (SELECT node_id FROM frozen_exploration_resource_defs WHERE content_snapshot_id=?)", (self.initial, self.content)).fetchone(), (0,))

    def test_missing_event_cannot_seal(self):
        self.db.execute("DELETE FROM exploration_instance_state WHERE snapshot_id='explore-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "coverage"):
            self.seal()

    def test_hazard_clock_cannot_exceed_cycle(self):
        self.db.execute("UPDATE exploration_instance_state SET hazard_clock_s=1e9 WHERE snapshot_id='explore-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "frozen limits"):
            self.seal()

    def test_ended_event_requires_outcome(self):
        self.db.execute("UPDATE exploration_instance_state SET phase='ready' WHERE snapshot_id='explore-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "frozen limits"):
            self.seal()

    def test_inactive_temporary_ore_cannot_regenerate(self):
        self.db.execute("UPDATE resource_state SET remaining_units=1 WHERE snapshot_id='explore-candidate' AND node_id IN (SELECT node_id FROM frozen_exploration_resource_defs WHERE content_snapshot_id=?)", (self.content,))
        with self.assertRaisesRegex(sqlite3.IntegrityError, "mineral regenerated"):
            self.seal()

    def test_claim_cannot_forge_credit(self):
        self.claim(); self.db.execute("UPDATE exploration_claim_state SET credit_units=credit_units+1 WHERE snapshot_id='explore-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "receipt limits"):
            self.seal()

    def test_current_claim_cannot_change_the_generated_variant(self):
        self.claim()
        alternative = p.rows(self.source, "exploration_variant_defs", "event_id=? AND variant_id<>?", (self.event["event_id"], self.variant["variant_id"]))[0]
        self.db.execute("UPDATE exploration_claim_state SET variant_id=?,credit_units=?,insight_units=?,reputation_units=? WHERE snapshot_id='explore-candidate'", (alternative["variant_id"], alternative["full_credit"], alternative["insight_units"], alternative["reputation_units"]))
        self.db.execute("UPDATE exploration_progress_state SET insight_available=?,insight_earned=? WHERE snapshot_id='explore-candidate'", (alternative["insight_units"], alternative["insight_units"]))
        with self.assertRaisesRegex(sqlite3.IntegrityError, "receipt limits"):
            self.seal()

    def test_matching_ledger_cannot_forge_excess_evidence(self):
        self.claim(); self.db.execute("UPDATE exploration_claim_state SET insight_units=999 WHERE snapshot_id='explore-candidate'")
        self.db.execute("UPDATE exploration_progress_state SET insight_available=999,insight_earned=999 WHERE snapshot_id='explore-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "receipt limits"):
            self.seal()

    def test_unreceipted_knowledge_points_cannot_seal(self):
        self.db.execute("UPDATE exploration_progress_state SET insight_available=20,insight_earned=20 WHERE snapshot_id='explore-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "ledger mismatch"):
            self.seal()

    def test_claim_phase_needs_receipt(self):
        self.db.execute("UPDATE exploration_instance_state SET phase='claimed',outcome='full' WHERE snapshot_id='explore-candidate'")
        with self.assertRaisesRegex(sqlite3.IntegrityError, "claim receipt"):
            self.seal()

    def test_valid_result_is_sealed_and_immutable(self):
        self.claim(); self.seal()
        for table in ("exploration_instance_state", "exploration_claim_state", "exploration_progress_state"):
            with self.assertRaisesRegex(sqlite3.IntegrityError, "immutable"):
                self.db.execute(f"DELETE FROM {table} WHERE snapshot_id='explore-candidate'")


if __name__ == "__main__":
    unittest.main()
