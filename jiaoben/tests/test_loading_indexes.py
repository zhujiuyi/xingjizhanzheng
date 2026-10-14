"""SQL-only loading-index upgrade and rollback checks; no personal database."""
from contextlib import closing
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import progress_fixture as p

RELEASE_REF = "c71aa7d42e9035cd81897ea73b2bb23d1d2de897"
INDEXES = {
    "shop_stock_content_fk": ("shop_stock_state", "item_def_id"),
    "shop_ship_stock_content_fk": ("shop_ship_stock_state", "ship_def_id"),
}


def data_digest(database, *, include_metadata=False):
    digest = hashlib.sha256()
    for table, in database.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"):
        if not include_metadata and table in {"database_meta", "migration_history"}:
            continue
        digest.update(table.encode())
        for row in database.execute(f'SELECT * FROM "{table}" ORDER BY rowid'):
            digest.update(json.dumps(row, ensure_ascii=False, separators=(",", ":")).encode())
    return digest.hexdigest()


def schema(database):
    return database.execute("SELECT type,name,tbl_name,sql FROM sqlite_schema ORDER BY type,name").fetchall()


class LoadingIndexes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.legacy = p.connect()
        # Freeze the already-released format26 separately from the new registry.
        with mock.patch.object(p, "MIGRATIONS", p.MIGRATIONS[:29]), mock.patch.object(p, "FORMAT_VERSION", 26):
            p.apply_migrations(cls.legacy)
        with closing(sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)) as source:
            p.new_world(cls.legacy, source)

    @classmethod
    def tearDownClass(cls):
        cls.legacy.close()

    def setUp(self):
        self.db = p.connect()
        self.addCleanup(self.db.close)
        self.legacy.backup(self.db)

    def test_format26_upgrade_preserves_all_game_data_and_prior_schema(self):
        before_data = data_digest(self.db)
        before_history = self.db.execute("SELECT * FROM migration_history ORDER BY migration_id").fetchall()
        before_schema = [row for row in schema(self.db) if row[1] != "database_meta"]
        self.assertEqual(self.db.execute("PRAGMA user_version").fetchone(), (26,))
        self.assertGreater(self.db.execute("SELECT count(*) FROM shop_stock_state").fetchone()[0], 0)
        p.apply_migrations(self.db)
        self.assertEqual(self.db.execute("SELECT format_version FROM database_meta").fetchone(), (27,))
        self.assertEqual(self.db.execute("PRAGMA user_version").fetchone(), (27,))
        self.assertEqual(data_digest(self.db), before_data)
        history = self.db.execute("SELECT * FROM migration_history ORDER BY migration_id").fetchall()
        self.assertEqual(history[:-1], before_history)
        self.assertEqual(history[-1][0], "030_loading_indexes.sql")
        self.assertEqual(history[-1][1], hashlib.sha256((p.PROGRESS_DIR / history[-1][0]).read_bytes()).hexdigest())
        self.assertEqual([row for row in schema(self.db) if row[1] != "database_meta" and row[1] not in INDEXES], before_schema)
        self.assertEqual(self.db.execute("PRAGMA foreign_key_check").fetchall(), [])
        self.assertEqual(self.db.execute("PRAGMA integrity_check").fetchall(), [("ok",)])

    def test_both_parent_fk_lookups_change_from_scan_to_exact_search(self):
        for table, key in INDEXES.values():
            plan = self.db.execute(f'EXPLAIN QUERY PLAN SELECT rowid FROM "{table}" WHERE content_snapshot_id=? AND station_id=? AND "{key}"=?', ("new-content", "station", "definition")).fetchall()
            self.assertTrue(any("SCAN " in row[3] for row in plan), plan)
        p.apply_migrations(self.db)
        for index, (table, key) in INDEXES.items():
            with self.subTest(table=table):
                plan = self.db.execute(f'EXPLAIN QUERY PLAN SELECT rowid FROM "{table}" WHERE content_snapshot_id=? AND station_id=? AND "{key}"=?', ("new-content", "station", "definition")).fetchall()
                self.assertTrue(any("SEARCH " in row[3] and index in row[3] for row in plan), plan)
                self.assertFalse(any("SCAN " in row[3] for row in plan), plan)
                self.assertEqual([row[2] for row in self.db.execute(f'PRAGMA index_info("{index}")')], ["content_snapshot_id", "station_id", key])

    def test_failed_format27_upgrade_rolls_back_indexes_metadata_and_history(self):
        before_schema = schema(self.db)
        before_data = data_digest(self.db, include_metadata=True)
        with self.assertRaises(sqlite3.OperationalError):
            p.apply_migrations(self.db, fault_after=30)
        self.assertEqual(schema(self.db), before_schema)
        self.assertEqual(data_digest(self.db, include_metadata=True), before_data)
        self.assertEqual(self.db.execute("PRAGMA user_version").fetchone(), (26,))
        p.apply_migrations(self.db)
        self.assertEqual(self.db.execute("PRAGMA user_version").fetchone(), (27,))

    def test_current_fresh_schema_and_repeat_upgrade_are_idempotent(self):
        with closing(p.connect()) as fresh:
            p.apply_migrations(fresh)
            self.assertEqual(fresh.execute("PRAGMA user_version").fetchone(), (27,))
            self.assertEqual({row[0] for row in fresh.execute("SELECT name FROM sqlite_schema WHERE type='index' AND name IN ('shop_stock_content_fk','shop_ship_stock_content_fk')")}, set(INDEXES))
        p.apply_migrations(self.db)
        before_schema = schema(self.db)
        before_data = data_digest(self.db, include_metadata=True)
        p.apply_migrations(self.db)
        self.assertEqual(schema(self.db), before_schema)
        self.assertEqual(data_digest(self.db, include_metadata=True), before_data)

    def test_all_released_sql_and_catalog_bytes_remain_unchanged(self):
        names = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", RELEASE_REF, "code/database/progress"], cwd=ROOT, text=True).splitlines()
        sql = [name for name in names if name.endswith(".sql")]
        self.assertEqual(len(sql), 52)
        for name in sql:
            with self.subTest(path=name):
                self.assertEqual((ROOT / name).read_bytes(), subprocess.check_output(["git", "show", RELEASE_REF + ":" + name], cwd=ROOT))
        self.assertEqual(hashlib.sha256((ROOT / "code/data/catalog.db").read_bytes()).hexdigest(), "a633d847b0f490064f5dcdab4bca998be85adc0b0753ac6f352585ebd0d77198")


if __name__ == "__main__":
    unittest.main()
