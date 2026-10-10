"""Definition coverage, real quality effects and frozen/legacy identity constraints."""
from pathlib import Path
import sqlite3
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog
import progress_fixture as p


class ResourceIntelligence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.db = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
        cls.db.execute("PRAGMA foreign_keys=ON")

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    def test_every_node_and_sector_has_one_real_definition(self):
        build_catalog.validate_database(self.db)
        self.assertEqual(self.db.execute("SELECT count(*) FROM resource_grade_defs").fetchone(), self.db.execute("SELECT count(*) FROM resource_node_defs").fetchone())
        self.assertEqual(self.db.execute("SELECT count(*) FROM sector_activity_defs").fetchone(), (54,))
        self.assertEqual(set(build_catalog.CONTENT_COLUMNS), set(build_catalog.CONTENT_TABLES))

    def test_original_corridor_and_components_keep_exact_yield(self):
        self.assertEqual(self.db.execute("SELECT count(*) FROM resource_grade_defs g JOIN resource_node_defs n USING(node_id) JOIN sector_sovereignty_defs p USING(sector_id) WHERE p.initial_faction_id IS NULL AND p.conquerable=0 AND g.yield_multiplier_bp<>10000").fetchone()[0], 0)
        self.assertEqual(self.db.execute("SELECT count(*) FROM resource_grade_defs g JOIN resource_node_defs n USING(node_id) JOIN item_defs i ON i.item_id=n.item_id WHERE i.item_type<>'ore' AND g.yield_multiplier_bp<>10000").fetchone()[0], 0)

    def test_higher_grade_has_noncosmetic_bounded_yield(self):
        levels = self.db.execute("SELECT DISTINCT grade_level,yield_multiplier_bp FROM resource_grade_defs ORDER BY grade_level").fetchall()
        self.assertEqual(levels, [(1, 10000), (2, 11000), (3, 12000)])

    def test_industrial_rules_are_preserved_without_a_second_balance_set(self):
        old = sqlite3.connect((ROOT / "code/data/catalog_industry_v9.db").as_uri() + "?mode=ro", uri=True)
        self.addCleanup(old.close)
        self.assertEqual(p.adapter_hash(old), "c4556c55c79de72dc0e461a2484f71df9250963bea68b516d36ddc6267979852")
        for (table,) in old.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name<>'catalog_meta'"):
            self.assertEqual(sorted(old.execute(f'SELECT * FROM "{table}"').fetchall(), key=repr), sorted(self.db.execute(f'SELECT * FROM "{table}"').fetchall(), key=repr), table)

    def test_invalid_yield_and_missing_sector_are_rejected(self):
        db = sqlite3.connect(":memory:")
        self.addCleanup(db.close); self.db.backup(db); db.execute("PRAGMA foreign_keys=ON")
        with self.assertRaises(sqlite3.IntegrityError):
            db.execute("UPDATE resource_grade_defs SET yield_multiplier_bp=999999")
        db.rollback()
        db.execute("DELETE FROM sector_activity_defs WHERE sector_id='sector_anchor'")
        with self.assertRaisesRegex(ValueError, "Incomplete resource intelligence"):
            build_catalog.validate_database(db)

    def test_new_definitions_are_frozen_and_cannot_mutate_a_sealed_world(self):
        db = p.connect(); self.addCleanup(db.close)
        p.apply_migrations(db)
        initial, content = p.new_world(db, self.db)
        self.assertEqual(db.execute("SELECT format_version FROM database_meta").fetchone(), (11,))
        for table in ("resource_grade_defs", "sector_activity_defs"):
            self.assertGreater(db.execute(f"SELECT count(*) FROM frozen_{table} WHERE content_snapshot_id=?", (content,)).fetchone()[0], 0)
            with self.assertRaisesRegex(sqlite3.IntegrityError, "immutable"):
                db.execute(f"DELETE FROM frozen_{table} WHERE content_snapshot_id=?", (content,))


if __name__ == "__main__":
    unittest.main()
