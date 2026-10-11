#!/usr/bin/env python3
"""Verify physical system distances, local fleet geometry and frozen DB closure."""
from __future__ import annotations

import math
from pathlib import Path
import sqlite3
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog as builder

AU_M = 149597870700.0


class SpaceCatalog(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.db = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
        cls.db.execute("PRAGMA foreign_keys=ON")
        cls.db.row_factory = sqlite3.Row
        cls.anchors = cls.index("anchor_defs", "anchor_id")
        cls.sites = cls.index("site_defs", "site_id")
        cls.mapping = {row["anchor_id"]: row["site_id"] for row in cls.rows("anchor_site_defs")}
        cls.baseline = sqlite3.connect(":memory:")
        cls.baseline.row_factory = sqlite3.Row
        cls.baseline.executescript(builder.SCHEMA.read_text(encoding="utf-8") + "\n" + builder.SEED.read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls):
        cls.db.close()
        cls.baseline.close()

    @classmethod
    def rows(cls, table):
        return [dict(row) for row in cls.db.execute(f'SELECT * FROM "{table}"')]

    @classmethod
    def index(cls, table, key):
        return {row[key]: row for row in cls.rows(table)}

    @staticmethod
    def point(row):
        return tuple(row[axis + "_m"] for axis in "xyz")

    def copy(self):
        result = sqlite3.connect(":memory:")
        self.db.backup(result)
        result.execute("PRAGMA foreign_keys=ON")
        return result

    def test_reviewed_metadata_and_content_identity(self):
        row = self.rows("catalog_meta")[0]
        self.assertEqual((row["schema_version"], row["content_version"], row["ruleset_version"]),
                         (18, "v0.19-hire", "singleplayer_hire_v1"))
        self.assertEqual(builder.logical_content_hash(self.db), row["content_hash"])
        source = self.copy()
        try:
            builder.validate_database(source)
        finally:
            source.close()

    def test_every_existing_anchor_is_preserved_and_mapped_once(self):
        self.assertEqual(set(self.anchors), set(self.mapping))
        self.assertEqual(len(self.mapping), self.db.execute("SELECT count(*) FROM anchor_site_defs").fetchone()[0])
        old = {row["anchor_id"]: dict(row) for row in self.baseline.execute("SELECT * FROM anchor_defs")}
        self.assertEqual(old, {key: self.anchors[key] for key in old})

    def test_local_mechanics_have_not_been_scaled_with_astronomical_distances(self):
        for table in ("module_defs", "npc_behavior_defs", "npc_archetype_defs", "drone_defs", "rule_parameters", "camera_profile_defs"):
            before = [tuple(row) for row in self.baseline.execute(f'SELECT * FROM "{table}" ORDER BY 1')]
            after = [tuple(row) for row in self.db.execute(f'SELECT * FROM "{table}" ORDER BY 1')]
            # New civilization definitions extend the catalogue; every prior
            # record retains exactly the old local physical/gameplay values.
            columns = self.baseline.execute(f'PRAGMA table_info("{table}")').fetchall()
            keys = [index for index, column in enumerate(columns) if column['pk']]
            old_ids = {tuple(row[index] for index in keys) for row in before}
            retained = [row for row in after if tuple(row[index] for index in keys) in old_ids]
            self.assertEqual(before, retained, table)

    def test_site_reference_sector_and_radius_are_closed(self):
        self.assertEqual(set(self.mapping.values()), set(self.sites))
        for aid, sid in self.mapping.items():
            anchor, site = self.anchors[aid], self.sites[sid]
            self.assertEqual(anchor["sector_id"], site["sector_id"])
            pivot = tuple(site["pivot_" + axis + "_m"] for axis in "xyz")
            self.assertLess(math.dist(self.point(anchor), pivot), site["local_radius_m"])
            self.assertEqual(site["local_radius_m"], 150000.0)

    def test_each_system_has_all_five_site_roles(self):
        for sector in self.rows("sector_defs"):
            roles = {site["site_kind"] for site in self.sites.values() if site["sector_id"] == sector["sector_id"]}
            self.assertEqual(roles, {"station", "gate", "resource", "signal", "encounter"})

    def test_each_system_has_real_astronomical_separation(self):
        for sector in self.rows("sector_defs"):
            points = [self.point(site) for site in self.sites.values() if site["sector_id"] == sector["sector_id"]]
            distances = [math.dist(a, b) for index, a in enumerate(points) for b in points[index + 1:]]
            self.assertGreaterEqual(min(distances), AU_M * .01)
            self.assertGreaterEqual(max(distances), AU_M * .5)
            self.assertLess(max(distances), AU_M * 20)

    def test_system_layouts_are_not_translated_copies(self):
        layouts = set()
        for sector in self.rows("sector_defs"):
            sites = [site for site in self.sites.values() if site["sector_id"] == sector["sector_id"]]
            center = self.point(next(site for site in sites if site["site_kind"] == "station"))
            layout = tuple(sorted((site["site_kind"], round(math.dist(center, self.point(site)) / AU_M, 6)) for site in sites))
            self.assertNotIn(layout, layouts)
            layouts.add(layout)

    def test_station_undock_and_basic_flight_stay_in_one_site(self):
        for station in self.rows("station_defs"):
            site = self.mapping[station["station_anchor_id"]]
            self.assertEqual(site, self.mapping[station["undock_anchor_id"]])
            for anchor in self.anchors.values():
                if anchor["sector_id"] == station["sector_id"] and anchor["anchor_kind"] == "flight_marker":
                    self.assertEqual(site, self.mapping[anchor["anchor_id"]])

    def test_gate_return_exit_is_in_its_physical_entry_site(self):
        endpoints = self.rows("gate_endpoint_defs")
        for endpoint in endpoints:
            reverse = next(row for row in endpoints if row["connection_id"] == endpoint["connection_id"] and row["origin_sector_id"] == endpoint["target_sector_id"])
            self.assertEqual(self.mapping[endpoint["entry_anchor_id"]], self.mapping[reverse["exit_anchor_id"]])
            self.assertLess(math.dist(self.point(self.anchors[endpoint["entry_anchor_id"]]), self.point(self.anchors[reverse["exit_anchor_id"]])), 1000)

    def test_npc_patrol_and_encounter_fleets_do_not_cross_sites(self):
        spawns = self.index("npc_spawn_defs", "spawn_id")
        encounters = self.index("encounter_defs", "encounter_id")
        for point in self.rows("npc_patrol_points"):
            self.assertEqual(self.mapping[point["anchor_id"]], self.mapping[spawns[point["spawn_id"]]["anchor_id"]])
        for member in self.rows("encounter_members"):
            self.assertEqual(self.mapping[spawns[member["spawn_id"]]["anchor_id"]], self.mapping[encounters[member["encounter_id"]]["anchor_id"]])

    def test_real_celestial_radii_and_playable_orbits(self):
        for sector in self.rows("sector_defs"):
            bodies = [body for body in self.rows("celestial_defs") if body["sector_id"] == sector["sector_id"]]
            self.assertEqual(sum(body["celestial_kind"] == "star" for body in bodies), 1)
            self.assertGreaterEqual(sum(body["celestial_kind"] == "planet" for body in bodies), 1)
            for body in bodies:
                self.assertGreater(body["radius_m"], 1e6)
                for site in self.sites.values():
                    if site["sector_id"] != sector["sector_id"]:
                        continue
                    self.assertGreater(math.dist(self.point(body), self.point(site)), body["radius_m"] + site["local_radius_m"])

    def test_all_legacy_planets_have_real_counterparts(self):
        source = sqlite3.connect((ROOT / "code/data/navigation_v3.db").as_uri() + "?mode=ro", uri=True)
        try:
            old = {row[0] for row in source.execute("SELECT celestial_id FROM celestial_visual_defs")}
            new = {body["celestial_id"] for body in self.rows("celestial_defs") if body["celestial_kind"] == "planet"}
            self.assertTrue(old <= new)
            self.assertEqual(len(new), 54)
        finally:
            source.close()

    def test_reviewed_adapter_has_exact_schema_and_logical_identity(self):
        source = sqlite3.connect(":memory:")
        try:
            source.executescript((ROOT / "code/database/progress/catalog_adapter_v0_19.sql").read_text(encoding="utf-8"))
            for table in builder.CONTENT_TABLES:
                expected = self.db.execute(f'PRAGMA table_info("{table}")').fetchall()
                actual = source.execute(f'PRAGMA table_info("{table}")').fetchall()
                self.assertEqual([tuple(row) for row in actual], [tuple(row) for row in expected])
            self.assertEqual(builder.content_views(source), builder.content_views(self.db))
        finally:
            source.close()

    def test_missing_anchor_mapping_is_rejected(self):
        source = self.copy()
        try:
            source.execute("DELETE FROM anchor_site_defs WHERE anchor_id='anchor_anchor_undock'")
            with self.assertRaisesRegex(ValueError, "Every anchor"):
                builder.validate_space_content(source)
        finally:
            source.close()

    def test_cross_system_site_assignment_is_rejected(self):
        source = self.copy()
        try:
            source.execute("UPDATE anchor_site_defs SET site_id='site_echo_station' WHERE anchor_id='anchor_anchor_undock'")
            with self.assertRaisesRegex(ValueError, "sector mismatch"):
                builder.validate_space_content(source)
        finally:
            source.close()

    def test_copied_tiny_physical_site_is_rejected(self):
        source = self.copy()
        try:
            source.execute("UPDATE site_defs SET x_m=(SELECT x_m FROM site_defs WHERE site_id='site_anchor_station')+1000,y_m=(SELECT y_m FROM site_defs WHERE site_id='site_anchor_station'),z_m=(SELECT z_m FROM site_defs WHERE site_id='site_anchor_station') WHERE site_id='site_anchor_beacon'")
            with self.assertRaisesRegex(ValueError, "still too close"):
                builder.validate_space_content(source)
        finally:
            source.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
