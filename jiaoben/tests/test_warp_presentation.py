#!/usr/bin/env python3
"""Presentation v3 closure and immutable v0.15.0 gameplay/publication bytes.

This is a read-only check. It never rebuilds a DB or derives the historical
expected bytes from the working tree, current HEAD, or a regenerated manifest.
"""
from __future__ import annotations

from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import sqlite3
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
CODE = ROOT / "code"
BASELINE = "9877c798df8dc4c776ef317796760a5a8341d4e6"
FX_DB = CODE / "data/warp_presentation_v3.db"
FX_SQL = CODE / "database/warp_presentation_v3.sql"
FX_MANIFEST = CODE / "data/warp_presentation_v3_manifest.json"


@lru_cache(maxsize=None)
def baseline_bytes(path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{BASELINE}:{path}"], cwd=ROOT)


def baseline_paths(directory: str) -> list[str]:
    output = subprocess.check_output(
        ["git", "ls-tree", "-r", "--name-only", BASELINE, "--", directory],
        cwd=ROOT,
    )
    return output.decode("utf-8").splitlines()


def database_contents(db: sqlite3.Connection) -> tuple:
    schema = tuple(db.execute(
        "SELECT type,name,tbl_name,sql FROM sqlite_master "
        "WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name"
    ))
    metadata = tuple(db.execute("SELECT * FROM warp_presentation_meta ORDER BY singleton"))
    values = tuple(db.execute("SELECT * FROM warp_visual_parameters ORDER BY parameter_id"))
    return schema, metadata, values


class WarpPresentation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Missing baseline history must fail explicitly, rather than silently
        # skip the preservation test or change its historical reference.
        revision = subprocess.check_output(
            ["git", "rev-parse", "--verify", f"{BASELINE}^{{commit}}"], cwd=ROOT,
        ).decode("ascii").strip()
        if revision != BASELINE:
            raise RuntimeError("Published v0.15.0 baseline Git identity is unavailable")
        cls.db = sqlite3.connect(FX_DB.as_uri() + "?mode=ro", uri=True)
        cls.db.execute("PRAGMA query_only=ON")
        cls.parameters = dict(cls.db.execute("SELECT parameter_id,value_real FROM warp_visual_parameters"))
        cls.expected = sqlite3.connect(":memory:")
        cls.expected.executescript(FX_SQL.read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls):
        cls.db.close()
        cls.expected.close()

    def test_published_gameplay_databases_and_manifests_are_byte_preserved(self):
        for path in (
            "code/data/catalog.db",
            "code/data/navigation_v3.db",
            "code/data/local_navigation_v1.db",
            "code/data/local_navigation_v2.db",
            "code/data/local_navigation_v1_manifest.json",
            "code/data/local_navigation_v2_manifest.json",
            "code/assets/manifest.json",
            "code/assets/legacy_art_full_v1/manifest.json",
        ):
            with self.subTest(path=path):
                current = ROOT / ('code/data/catalog_space_v7.db' if path == 'code/data/catalog.db' else path)
                self.assertEqual(current.read_bytes(), baseline_bytes(path), path)

    def test_published_catalog_navigation_and_progress_sql_are_byte_preserved(self):
        paths = [path for path in baseline_paths("code/database") if path.endswith(".sql")]
        self.assertIn("code/database/catalog_schema.sql", paths)
        self.assertIn("code/database/catalog_seed.sql", paths)
        self.assertIn("code/database/space_v7.sql", paths)
        migrations = [path for path in paths if PurePosixPath(path).name[:3].isdigit()]
        self.assertEqual({PurePosixPath(path).name[:3] for path in migrations},
                         {f"{version:03}" for version in range(1, 12)})
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual((ROOT / path).read_bytes(), baseline_bytes(path), path)
        # Civilization data is an explicit additive extension. All earlier
        # migration, adapter and navigation source bytes remain protected.
        actual = {path.relative_to(ROOT).as_posix() for path in (CODE / "database").rglob("*.sql")}
        self.assertEqual(actual, set(paths) | {"code/database/warp_presentation_v3.sql", "code/database/civilization_schema.sql", "code/database/civilization_seed.sql", "code/database/progress/012_civilizations.sql", "code/database/progress/catalog_adapter_v0_8.sql"})

    def test_independent_presentation_database_identity_and_integrity(self):
        self.assertEqual(self.db.execute("PRAGMA integrity_check").fetchall(), [("ok",)])
        self.assertEqual(self.db.execute("PRAGMA foreign_key_check").fetchall(), [])
        self.assertEqual(self.db.execute("PRAGMA application_id").fetchone()[0], 1481262680)
        self.assertEqual(self.db.execute("PRAGMA user_version").fetchone()[0], 3)
        self.assertEqual(self.db.execute("SELECT * FROM warp_presentation_meta").fetchall(),
                         [(1, "warp-presentation-v3")])
        tables = {row[0] for row in self.db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        self.assertEqual(tables, {"warp_presentation_meta", "warp_visual_parameters"})

    def test_formal_database_matches_formal_sql_without_rebuild(self):
        self.assertEqual(database_contents(self.db), database_contents(self.expected))

    def test_parameters_are_finite_and_cover_blur_stream_mask_and_departure(self):
        self.assertEqual(len(self.parameters), 21)
        for name, value in self.parameters.items():
            with self.subTest(parameter=name):
                self.assertTrue(name.startswith("warp_fx_"), name)
                self.assertTrue(math.isfinite(value), name)
                if name == "warp_fx_center_clear_ratio":
                    self.assertEqual(value, 0, "Background inside the hull rectangle must also blur")
                else:
                    self.assertGreater(value, 0, name)
        self.assertGreater(self.parameters["warp_fx_blur_radius_px"], 0)
        self.assertGreater(self.parameters["warp_fx_blur_lod"], 0)
        self.assertGreater(self.parameters["warp_fx_departure_duration_s"], 0)
        self.assertGreater(self.parameters["warp_fx_departure_distance_ship_lengths"], 0)
        self.assertGreaterEqual(self.parameters["warp_fx_mask_resolution_scale"], .25)
        self.assertLessEqual(self.parameters["warp_fx_mask_resolution_scale"], 1)
        self.assertGreaterEqual(self.parameters["warp_fx_mask_padding_ratio"], 1)
        for name in ("warp_fx_warmup_strength", "warp_fx_streak_alpha", "warp_fx_warmup_speed_ratio"):
            self.assertLessEqual(self.parameters[name], 1, name)
        count = self.parameters["warp_fx_streak_count"]
        self.assertEqual(count, math.floor(count))
        self.assertGreaterEqual(count, 8)
        self.assertLessEqual(count, 256)

    def test_departure_finishes_during_every_legal_strategic_route(self):
        nav = sqlite3.connect((CODE / "data/local_navigation_v2.db").as_uri() + "?mode=ro", uri=True)
        try:
            duration = nav.execute(
                "SELECT value_real FROM navigation_parameters WHERE parameter_id='min_warp_travel_s'"
            ).fetchone()[0]
            self.assertLess(self.parameters["warp_fx_departure_duration_s"], duration)
        finally:
            nav.close()

    def test_visual_sql_rejects_invalid_identity_and_negative_or_missing_values(self):
        for statement in (
            "INSERT INTO warp_presentation_meta VALUES (2,'warp-presentation-v3')",
            "UPDATE warp_presentation_meta SET rule_version='local-navigation-v2'",
            "UPDATE warp_visual_parameters SET value_real=-1 WHERE parameter_id='warp_fx_blur_radius_px'",
            "UPDATE warp_visual_parameters SET value_real=NULL WHERE parameter_id='warp_fx_blur_radius_px'",
        ):
            with self.subTest(statement=statement), self.assertRaises(sqlite3.IntegrityError):
                self.expected.execute(statement)
            self.expected.rollback()

    def test_manifest_is_unique_safe_and_matches_actual_raw_resource_bytes(self):
        manifest = json.loads(FX_MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["asset_version"], "warp-presentation-v3")
        resources = manifest["resources"]
        paths = {entry["path"] for entry in resources}
        self.assertEqual(len(paths), len(resources))
        self.assertTrue({
            "res://data/warp_presentation_v3.db",
            "res://data/local_navigation_v2.db",
            "res://runtime/warp_presentation_rules.gd",
            "res://runtime/ui/warp_visual.gd",
            "res://runtime/ui/warp_environment.gdshader",
        }.issubset(paths))
        for entry in resources:
            path = entry["path"]
            with self.subTest(resource=path):
                self.assertTrue(path.startswith("res://"))
                relative = PurePosixPath(path.removeprefix("res://"))
                self.assertFalse(relative.is_absolute())
                self.assertNotIn("..", relative.parts)
                source = (CODE / relative).resolve()
                self.assertTrue(source.is_relative_to(CODE.resolve()))
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), entry["sha256"])
                if path == "res://data/local_navigation_v2.db":
                    self.assertEqual(entry["role"], "immutable_gameplay_navigation")
                    self.assertEqual(source.read_bytes(), baseline_bytes("code/data/local_navigation_v2.db"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
