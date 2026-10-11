#!/usr/bin/env python3
"""DDL and reference SQL fault injection; does not test Godot, rendering or IO power loss."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog
import progress_fixture as p


class ProgressTests(unittest.TestCase):
    def setUp(self):
        self.source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
        self.db = p.connect()
        self.addCleanup(self.source.close)
        self.addCleanup(self.db.close)
        p.apply_migrations(self.db)
        self.initial, self.content = p.new_world(self.db, self.source)

    def candidate(self, name="candidate", sequence=2):
        self.db.execute("BEGIN IMMEDIATE")
        self.db.execute("PRAGMA defer_foreign_keys=ON")
        p.begin_snapshot(self.db, name, "world-a", self.content, sequence)
        p.copy_state(self.db, self.initial, name, "world-a", self.content)
        return p.context(name, "world-a", self.content)

    def pointer(self):
        return self.db.execute("SELECT current_snapshot_id,generation FROM save_slot WHERE slot_id='auto-world-a'").fetchone()

    def accept_fixture_mission(self, ctx, mission_def_id="tutorial_flight"):
        definition = p.rows(self.db, "frozen_mission_defs", "content_snapshot_id=? AND mission_id=?", (self.content, mission_def_id))[0]
        mission = {**ctx, "mission_instance_id": "attempt-flight-1", "player_id": "player-local",
                   "mission_def_id": definition["mission_id"], "attempt_number": 1, "status": "active",
                   "deadline_remaining_s": definition["deadline_s"], "cooldown_remaining_s": 0.,
                   "collected_units": 0, "delivered_units": 0, "reward_claimed": 0}
        p.insert(self.db, "mission_state", mission)
        return mission

    def spatial_npc(self, ctx, instance="npc-spatial-fixture", alive=0, phase="dead"):
        """Declared authored spawn precondition, never inferred from XYZ."""
        spawn = p.rows(self.db, "frozen_npc_spawn_defs", "content_snapshot_id=? AND occurrence_mode='ambient'", (self.content,))[0]
        definition = p.rows(self.source, "npc_full_defs", "npc_id=?", (spawn["npc_id"],))[0]
        anchor = p.rows(self.db, "frozen_anchor_defs", "content_snapshot_id=? AND anchor_id=?", (self.content, spawn["anchor_id"]))[0]
        site = p.rows(self.db, "frozen_anchor_site_defs", "content_snapshot_id=? AND anchor_id=?", (self.content, spawn["anchor_id"]))[0]["site_id"]
        row = {**ctx, "npc_instance_id": instance, "spawn_id": spawn["spawn_id"], "sector_id": spawn["sector_id"],
               "generation": 0, "alive": alive, "shield": definition["shield_max"] if alive else 0.,
               "armor": definition["armor_max"] if alive else 0., "hull": definition["hull_max"] if alive else 0.,
               "pos_x": anchor["x_m"], "pos_y": anchor["y_m"], "pos_z": anchor["z_m"],
               "quat_x": 0., "quat_y": 0., "quat_z": 0., "quat_w": 1., "vel_x": 0., "vel_y": 0., "vel_z": 0.,
               "angular_x": 0., "angular_y": 0., "angular_z": 0., "behavior_phase": phase,
               "wait_remaining_s": 0., "patrol_point_index": 0, "cooldown_remaining_s": 0.,
               "respawn_remaining_s": 0., "bounty_claimed": 0, "loot_claimed": 0}
        p.insert(self.db, "npc_state", row)
        return row, site

    def test_spatial_context_required_for_live_and_historical_entities(self):
        for kind in ("controlled-ship", "returned-ship", "dead-npc", "wreck"):
            with self.subTest(entity=kind):
                ctx = self.candidate()
                if kind == "controlled-ship":
                    self.db.execute("DELETE FROM spatial_state WHERE snapshot_id='candidate' AND entity_kind='ship' AND entity_id='ship-guarantee'")
                elif kind == "returned-ship":
                    ship = p.rows(self.db, "ship_state", "snapshot_id='candidate' AND ship_instance_id='ship-guarantee'")[0]
                    ship.update(ship_instance_id="returned-history", status="returned", station_id=None, hull=0.)
                    p.insert(self.db, "ship_state", ship)
                elif kind == "dead-npc":
                    self.spatial_npc(ctx)
                else:
                    p.insert(self.db, "container_state", {**ctx, "container_id": "wreck-spatial-fixture", "owner_player_id": "player-local",
                        "kind": "wreck", "sector_id": "sector_anchor", "pos_x": 0., "pos_y": 0., "pos_z": 0.})
                with self.assertRaisesRegex(sqlite3.IntegrityError, "missing spatial context"):
                    p.validate_snapshot(self.db, "candidate")
                self.db.rollback()
                self.assertEqual(self.pointer(), (self.initial, 1))

    def test_spatial_context_rejects_wrong_sector_or_orphan_identity(self):
        for mode in ("wrong-sector", "orphan-ship", "wrong-entity-kind"):
            with self.subTest(mode=mode):
                ctx = self.candidate()
                if mode == "wrong-sector":
                    site = p.rows(self.db, "frozen_site_defs", "content_snapshot_id=? AND sector_id='sector_echo'", (self.content,))[0]["site_id"]
                    self.db.execute("UPDATE spatial_state SET site_id=? WHERE snapshot_id='candidate' AND entity_kind='ship'", (site,))
                elif mode == "orphan-ship":
                    site = p.rows(self.db, "spatial_state", "snapshot_id='candidate'")[0]["site_id"]
                    p.insert(self.db, "spatial_state", {**ctx, "entity_kind": "ship", "entity_id": "missing-ship", "site_id": site})
                else:
                    self.db.execute("UPDATE spatial_state SET entity_kind='wreck' WHERE snapshot_id='candidate' AND entity_kind='ship'")
                with self.assertRaisesRegex(sqlite3.IntegrityError, "orphan or wrong-sector spatial context"):
                    p.validate_snapshot(self.db, "candidate")
                self.db.rollback()
                self.assertEqual(self.pointer(), (self.initial, 1))

    def test_spatial_context_is_unique_and_sealed_rows_are_immutable(self):
        ctx = p.context(self.initial, "world-a", self.content)
        site = p.rows(self.db, "spatial_state", "snapshot_id=?", (self.initial,))[0]["site_id"]
        for sql in ("UPDATE spatial_state SET entity_id='changed-identity' WHERE snapshot_id=?",
                    "DELETE FROM spatial_state WHERE snapshot_id=?",
                    "INSERT INTO spatial_state SELECT snapshot_id,world_id,content_snapshot_id,'ship','new-identity',site_id FROM spatial_state WHERE snapshot_id=?"):
            with self.subTest(sql=sql), self.assertRaisesRegex(sqlite3.IntegrityError, "sealed snapshot is immutable"):
                self.db.execute(sql, (self.initial,))
        candidate = self.candidate()
        with self.assertRaises(sqlite3.IntegrityError):
            p.insert(self.db, "spatial_state", {**candidate, "entity_kind": "ship", "entity_id": "ship-guarantee", "site_id": site})
        self.db.rollback()
        self.assertEqual(p.rows(self.db, "spatial_state", "snapshot_id=?", (self.initial,)),
                         [{**ctx, "entity_kind": "ship", "entity_id": "ship-guarantee", "site_id": site}])

    def test_spatial_npc_must_stay_on_its_authored_spawn_site(self):
        ctx = self.candidate()
        npc, correct_site = self.spatial_npc(ctx)
        other_site = next(row["site_id"] for row in p.rows(self.db, "frozen_site_defs", "content_snapshot_id=? AND sector_id=?", (self.content, npc["sector_id"])) if row["site_id"] != correct_site)
        p.insert(self.db, "spatial_state", {**ctx, "entity_kind": "npc", "entity_id": npc["npc_instance_id"], "site_id": other_site})
        with self.assertRaises(sqlite3.IntegrityError):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()

    def test_docked_ship_context_must_match_its_station_site(self):
        self.candidate()
        other_site = next(row["site_id"] for row in p.rows(self.db, "frozen_site_defs", "content_snapshot_id=? AND sector_id='sector_anchor'", (self.content,)) if row["site_kind"] != "station")
        self.db.execute("UPDATE spatial_state SET site_id=? WHERE snapshot_id='candidate' AND entity_kind='ship'", (other_site,))
        with self.assertRaises(sqlite3.IntegrityError):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()

    def test_hostile_ai_on_a_different_site_does_not_block_local_save(self):
        ctx = self.candidate()
        npc, site = self.spatial_npc(ctx, alive=1, phase="acquire")
        p.insert(self.db, "spatial_state", {**ctx, "entity_kind": "npc", "entity_id": npc["npc_instance_id"], "site_id": site})
        ship_site = p.rows(self.db, "spatial_state", "snapshot_id='candidate' AND entity_kind='ship' AND entity_id='ship-guarantee'")[0]["site_id"]
        self.assertNotEqual(site, ship_site)
        p.validate_snapshot(self.db, "candidate")
        self.assertEqual(self.db.execute("SELECT status FROM save_snapshot WHERE snapshot_id='candidate'").fetchone(), ("sealed",))
        self.db.rollback()

    def test_full_catalog_reference_closure_and_fixed_view_hash(self):
        self.assertEqual(p.verify_frozen_content(self.db, self.content), build_catalog.logical_content_hash(self.source))
        names = {r[0] for r in self.db.execute("SELECT table_name FROM content_table_manifest")}
        self.assertEqual(names, set(build_catalog.CONTENT_TABLES))
        registered = {r[0] for r in self.db.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name LIKE '%_state'")}
        self.assertEqual(registered, set(p.STATE_TABLES))
        self.assertEqual({r["encounter_id"] for r in p.rows(self.db, "encounter_state", "snapshot_id=?", (self.initial,))},
                         {r["encounter_id"] for r in p.rows(self.source, "encounter_defs")})
        self.assertEqual({r[0] for r in self.db.execute("SELECT view_name FROM content_view_manifest")}, set(build_catalog.CONTENT_VIEWS))
        self.assertEqual(self.db.execute("PRAGMA foreign_key_check").fetchall(), [])
        self.assertEqual(self.db.execute("PRAGMA integrity_check").fetchall(), [("ok",)])
        # Independent official-sequence reference validates the stored fixture
        # initialization, then restores raw limbs without a second seed step.
        sys.path.insert(0, str(ROOT / "jiaoben/tests"))
        from test_rng_contract import ReferencePcg32, GOLDEN42_54
        rng = p.rows(self.db, "rng_state", "snapshot_id=?", (self.initial,))[0]
        limbs = tuple(rng[column] for column in ("state_hi", "state_lo", "increment_hi", "increment_lo"))
        reference = ReferencePcg32.restore_world(*limbs)
        self.assertEqual([reference.next_uint32() for _ in range(6)], GOLDEN42_54)

    def test_frozen_definition_and_manifest_are_immutable(self):
        for sql in ("UPDATE frozen_ship_defs SET max_speed_mps=max_speed_mps+1",
                    "DELETE FROM frozen_recipe_inputs", "UPDATE content_table_manifest SET row_count=0",
                    "UPDATE content_view_manifest SET reviewed_source_sql='SELECT 1'",
                    "UPDATE content_snapshot SET ruleset_version='wrong'",
                    "UPDATE frozen_encounter_defs SET respawn_seconds=respawn_seconds+1",
                    "DELETE FROM frozen_encounter_members",
                    "UPDATE frozen_salvage_package_defs SET mass_kg=mass_kg+1",
                    "DELETE FROM frozen_salvage_reward_defs", "DELETE FROM frozen_npc_salvage_defs",
                    "UPDATE frozen_site_defs SET x_m=x_m+1", "DELETE FROM frozen_anchor_site_defs",
                    "UPDATE frozen_celestial_defs SET radius_m=radius_m+1"):
            with self.subTest(sql=sql), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(sql)

    def test_current_catalog_numeric_change_does_not_mutate_old_save(self):
        changed = sqlite3.connect(":memory:")
        self.addCleanup(changed.close)
        self.source.backup(changed)
        old = self.db.execute("SELECT max_speed_mps FROM frozen_ship_defs WHERE content_snapshot_id=? AND ship_id='shuttle_swift'", (self.content,)).fetchone()[0]
        changed.execute("UPDATE ship_defs SET max_speed_mps=max_speed_mps+1 WHERE ship_id='shuttle_swift'")
        new_hash = build_catalog.logical_content_hash(changed)
        changed.execute("UPDATE catalog_meta SET content_hash=?", (new_hash,))
        changed.commit()
        _, other = p.new_world(self.db, changed, "world-b", "content-b")
        self.assertNotEqual(self.content, other)
        self.assertEqual(self.db.execute("SELECT max_speed_mps FROM frozen_ship_defs WHERE content_snapshot_id=? AND ship_id='shuttle_swift'", (self.content,)).fetchone()[0], old)
        self.assertEqual(self.db.execute("SELECT max_speed_mps FROM frozen_ship_defs WHERE content_snapshot_id=? AND ship_id='shuttle_swift'", (other,)).fetchone()[0], old + 1)
        p.load_slot(self.db, "auto-world-a", "new-session")

    def test_same_complete_compatibility_identity_reuses_full_copy(self):
        _, second = p.new_world(self.db, self.source, "world-b", "unused-copy-id")
        self.assertEqual(second, self.content)
        self.assertEqual(self.db.execute("SELECT count(*) FROM content_snapshot").fetchone()[0], 1)

    def test_same_catalog_different_compatibility_tuple_does_not_reuse(self):
        # Version labels here are fixture identities, not claims that future
        # rule code/adapters have been implemented.
        with mock.patch.object(p, "RULE_CODE_VERSION", "fixture-rule-v2"):
            _, rule_content = p.new_world(self.db, self.source, "world-rule", "content-rule")
            self.assertNotEqual(rule_content, self.content)
            before = self.db.execute("SELECT epoch FROM runtime_session WHERE world_id='world-a'").fetchone()
            with self.assertRaises(ValueError):
                p.load_slot(self.db, "auto-world-a", "cannot-load-old-rules")
            self.assertEqual(self.db.execute("SELECT epoch FROM runtime_session WHERE world_id='world-a'").fetchone(), before)
        with mock.patch.object(p, "ADAPTER_VERSION", "fixture-adapter-v2"):
            _, adapter_content = p.new_world(self.db, self.source, "world-adapter", "content-adapter")
            self.assertNotEqual(adapter_content, self.content)
        with tempfile.TemporaryDirectory(dir=ROOT / "jiaoben/tmp") as directory:
            manifest_path = Path(directory) / "manifest.json"
            for mode in ("version", "hash"):
                manifest = json.loads(p.ASSET_MANIFEST.read_text(encoding="utf-8"))
                manifest.pop("manifest_sha256")
                asset_version = p.ASSET_VERSION
                if mode == "version":
                    asset_version = manifest["asset_version"] = "fixture-assets-v2"
                else:
                    manifest["resources"].reverse()  # Same files, new canonical identity.
                manifest["manifest_sha256"] = hashlib.sha256(json.dumps(manifest, ensure_ascii=False,
                    sort_keys=True, separators=(",", ":")).encode()).hexdigest()
                manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
                with mock.patch.object(p, "ASSET_MANIFEST", manifest_path), mock.patch.object(p, "ASSET_VERSION", asset_version):
                    _, asset_content = p.new_world(self.db, self.source, "world-asset-" + mode, "content-asset-" + mode)
                self.assertNotEqual(asset_content, self.content)
        self.assertEqual(self.db.execute("SELECT count(DISTINCT content_hash),count(*) FROM content_snapshot").fetchone(), (1, 5))
        duplicate = p.rows(self.db, "content_snapshot", "content_snapshot_id=?", (self.content,))[0]
        duplicate.update(content_snapshot_id="duplicate-identity", status="building")
        with self.assertRaises(sqlite3.IntegrityError):
            p.insert(self.db, "content_snapshot", duplicate)

    def test_asset_manifest_is_canonical_identity_not_pretty_file_hash(self):
        manifest = json.loads(p.ASSET_MANIFEST.read_text(encoding="utf-8"))
        canonical = p.verify_asset_manifest()
        self.assertEqual(canonical, manifest["manifest_sha256"])
        self.assertNotEqual(canonical, hashlib.sha256(p.ASSET_MANIFEST.read_bytes()).hexdigest())
        self.assertEqual(self.db.execute("SELECT asset_manifest_sha256 FROM content_snapshot WHERE content_snapshot_id=?", (self.content,)).fetchone(), (canonical,))
        with tempfile.TemporaryDirectory(dir=ROOT / "jiaoben/tmp") as directory:
            path = Path(directory) / "reformatted.json"
            path.write_text(json.dumps(manifest, ensure_ascii=False, indent=6), encoding="utf-8")
            with mock.patch.object(p, "ASSET_MANIFEST", path):
                self.assertEqual(p.verify_asset_manifest(), canonical)

    def test_asset_manifest_self_hash_and_each_resource_file_are_checked(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "jiaoben/tmp") as directory:
            path = Path(directory) / "invalid.json"
            for mode in ("self", "resource"):
                manifest = json.loads(p.ASSET_MANIFEST.read_text(encoding="utf-8"))
                if mode == "self":
                    manifest["manifest_sha256"] = "0" * 64
                else:
                    manifest.pop("manifest_sha256")
                    manifest["resources"][0]["sha256"] = "0" * 64
                    manifest["manifest_sha256"] = hashlib.sha256(json.dumps(manifest, ensure_ascii=False,
                        sort_keys=True, separators=(",", ":")).encode()).hexdigest()
                path.write_text(json.dumps(manifest), encoding="utf-8")
                with self.subTest(mode=mode), mock.patch.object(p, "ASSET_MANIFEST", path), self.assertRaises(ValueError):
                    p.verify_asset_manifest()

    def test_migration_fault_rollback_and_checksums(self):
        for after in range(1, len(p.MIGRATIONS) + 1):
            database = p.connect()
            self.addCleanup(database.close)
            with self.subTest(after=after), self.assertRaises(sqlite3.OperationalError):
                p.apply_migrations(database, fault_after=after)
            self.assertEqual(database.execute("SELECT count(*) FROM sqlite_schema WHERE type='table'").fetchone()[0], 0)
        p.apply_migrations(self.db)  # Idempotent only when every reviewed checksum matches.
        self.db.execute("UPDATE migration_history SET sql_sha256=?", ("0" * 64,))
        with self.assertRaises(ValueError):
            p.apply_migrations(self.db)

    def test_format5_009_failure_preserves_prior_schema_and_retry(self):
        database = p.connect()
        self.addCleanup(database.close)
        pieces = ["BEGIN IMMEDIATE;"]
        # This historical format5 fixture stops before 009, independently of
        # how many later migrations the current release registers.
        for name in p.MIGRATIONS[:8]:
            path = p.PROGRESS_DIR / name
            pieces.append(path.read_text(encoding="utf-8"))
            pieces.append("INSERT INTO migration_history VALUES(" + repr(name) + "," +
                          repr(hashlib.sha256(path.read_bytes()).hexdigest()) + "," + repr(p.utc_now()) + ");")
        pieces.append("COMMIT;")
        database.executescript("\n".join(pieces))
        p.insert(database, "profile", {"profile_id": "format5-profile", "display_name": "保留旧资料", "created_utc": p.utc_now()})
        history = database.execute("SELECT * FROM migration_history ORDER BY migration_id").fetchall()
        prior_schema = database.execute("SELECT type,name,sql FROM sqlite_schema ORDER BY type,name").fetchall()
        self.assertEqual(database.execute("SELECT format_version FROM database_meta").fetchone(), (5,))
        with self.assertRaises(sqlite3.OperationalError):
            p.apply_migrations(database, fault_after=9)
        self.assertEqual(database.execute("SELECT type,name,sql FROM sqlite_schema ORDER BY type,name").fetchall(), prior_schema)
        self.assertEqual(database.execute("SELECT * FROM migration_history ORDER BY migration_id").fetchall(), history)
        self.assertEqual(database.execute("SELECT display_name FROM profile").fetchall(), [("保留旧资料",)])
        self.assertEqual(database.execute("PRAGMA user_version").fetchone(), (5,))
        p.apply_migrations(database)
        self.assertEqual(database.execute("SELECT format_version FROM database_meta").fetchone(), (p.FORMAT_VERSION,))
        self.assertEqual(database.execute("SELECT * FROM migration_history ORDER BY migration_id").fetchall()[:8], history)
        self.assertEqual({r[0] for r in database.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name LIKE '%_state'")}, set(p.STATE_TABLES))
        self.assertEqual(database.execute("PRAGMA foreign_key_check").fetchall(), [])

    def test_format6_010_failure_preserves_prior_schema_and_retry(self):
        database = p.connect()
        self.addCleanup(database.close)
        pieces = ["BEGIN IMMEDIATE;"]
        for name in p.MIGRATIONS[:9]:
            path = p.PROGRESS_DIR / name
            pieces.append(path.read_text(encoding="utf-8"))
            pieces.append("INSERT INTO migration_history VALUES(" + repr(name) + "," +
                          repr(hashlib.sha256(path.read_bytes()).hexdigest()) + "," + repr(p.utc_now()) + ");")
        pieces.append("COMMIT;")
        database.executescript("\n".join(pieces))
        p.insert(database, "profile", {"profile_id": "format6-profile", "display_name": "保留六版资料", "created_utc": p.utc_now()})
        history = database.execute("SELECT * FROM migration_history ORDER BY migration_id").fetchall()
        schema = database.execute("SELECT type,name,sql FROM sqlite_schema ORDER BY type,name").fetchall()
        self.assertEqual(database.execute("SELECT format_version FROM database_meta").fetchone(), (6,))
        with self.assertRaises(sqlite3.OperationalError):
            p.apply_migrations(database, fault_after=10)
        self.assertEqual(database.execute("SELECT type,name,sql FROM sqlite_schema ORDER BY type,name").fetchall(), schema)
        self.assertEqual(database.execute("SELECT * FROM migration_history ORDER BY migration_id").fetchall(), history)
        self.assertEqual(database.execute("SELECT display_name FROM profile").fetchall(), [("保留六版资料",)])
        self.assertEqual(database.execute("PRAGMA user_version").fetchone(), (6,))
        # Applying 010 by itself still produces its historical format7. The
        # current retry then adds 011/012/013 and must reach the current format without rewriting
        # the older migration's SQL, recorded checksum or result.
        with mock.patch.object(p, "MIGRATIONS", p.MIGRATIONS[:10]), mock.patch.object(p, "FORMAT_VERSION", 7):
            p.apply_migrations(database)
        self.assertEqual(database.execute("SELECT format_version FROM database_meta").fetchone(), (7,))
        self.assertEqual(database.execute("PRAGMA user_version").fetchone(), (7,))
        self.assertEqual(database.execute("SELECT count(*) FROM sqlite_schema WHERE name='spatial_state'").fetchone(), (0,))
        p.apply_migrations(database)
        self.assertEqual(database.execute("SELECT format_version FROM database_meta").fetchone(), (p.FORMAT_VERSION,))
        self.assertEqual(database.execute("SELECT * FROM migration_history ORDER BY migration_id").fetchall()[:9], history)
        self.assertEqual(database.execute("SELECT count(*) FROM sqlite_schema WHERE name='frozen_drone_defs'").fetchone(), (1,))
        self.assertEqual(database.execute("PRAGMA foreign_key_check").fetchall(), [])

    def test_old_fixed_adapter_hash_is_independent_of_current_registry(self):
        legacy = p.adapter_connection("frozen_catalog_v0_5")
        self.addCleanup(legacy.close)
        # The maintained SQL retains the exact pre-v0.6 seed before its explicit
        # rebalance section. Load it into the independently reviewed old DDL.
        historical_seed = build_catalog.SEED.read_text(encoding="utf-8").split("-- v0.6 combat rebalance:", 1)[0]
        legacy.executescript(historical_seed)
        logical = p.adapter_hash(legacy)
        legacy.execute("UPDATE catalog_meta SET content_hash=?", (logical,))
        legacy.commit()
        metadata = p.rows(legacy, "catalog_meta")[0]
        names = [row[0] for row in legacy.execute("SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name")]
        self.assertEqual(metadata["schema_version"], 4)
        self.assertEqual(len(names), 89)
        self.assertEqual(len(build_catalog.CONTENT_TABLES), 125)
        self.db.execute("BEGIN IMMEDIATE")
        self.db.execute("PRAGMA defer_foreign_keys=ON")
        cid = "historical-adapter-content"
        p.insert(self.db, "content_snapshot", {"content_snapshot_id": cid, "content_hash": logical,
                 "pack_id": metadata["pack_id"], "content_version": metadata["content_version"],
                 "catalog_schema_version": 4, "ruleset_version": metadata["ruleset_version"],
                 "rules_code_version": "singleplayer_full_v1", "asset_manifest_version": p.ASSET_VERSION,
                 "asset_manifest_sha256": p.verify_asset_manifest(), "frozen_adapter_version": "frozen_catalog_v0_5",
                 "created_utc": p.utc_now(), "status": "building"})
        for table in names:
            info = legacy.execute(f'PRAGMA table_info("{table}")').fetchall()
            signature = "|".join(f"{row[1]}:{row[2]}:{row[5]}" for row in info if not (table == "catalog_meta" and row[1] == "content_hash"))
            data = p.rows(legacy, table)
            for row in data:
                p.insert(self.db, "frozen_" + table, {"content_snapshot_id": cid, **row})
            p.insert(self.db, "content_table_manifest", {"content_snapshot_id": cid, "table_name": table,
                     "schema_signature": signature, "row_count": len(data)})
        for name, sql in legacy.execute("SELECT name,sql FROM sqlite_schema WHERE type='view'"):
            p.insert(self.db, "content_view_manifest", {"content_snapshot_id": cid, "view_name": name,
                     "reviewed_source_sql": sql, "sql_sha256": hashlib.sha256(sql.encode()).hexdigest()})
        self.assertEqual(p.verify_frozen_content(self.db, cid), logical)
        self.db.execute("UPDATE content_snapshot SET status='sealed' WHERE content_snapshot_id=?", (cid,))
        self.db.commit()
        with mock.patch.object(build_catalog, "CONTENT_TABLES", ("catalog_meta",)):
            self.assertEqual(p.verify_frozen_content(self.db, cid), logical)
        with self.assertRaisesRegex(ValueError, "Unsupported frozen adapter"):
            p.adapter_connection("unregistered-future-adapter")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE frozen_ship_defs SET max_speed_mps=max_speed_mps+1 WHERE content_snapshot_id=?", (cid,))

    def test_every_registered_state_group_copies_and_loads_complete_payload(self):
        package_def = p.rows(self.source, "salvage_package_defs")[0]
        reward = p.rows(self.source, "salvage_reward_defs", "package_def_id=?", (package_def["package_def_id"],))[0]
        station = p.rows(self.db, "player_state", "snapshot_id=?", (self.initial,))[0]["docked_station_id"]

        def add_new_state(database, snapshot):
            ctx = p.context(snapshot, "world-a", self.content)
            # The origin NPC is historical and may already have been retired.
            for status in ("sealed", "opened"):
                p.insert(database, "salvage_package_state", {**ctx, "package_id": "copy-" + status,
                    "package_def_id": package_def["package_def_id"], "source_npc_instance_id": "retired-" + status,
                    "source_generation": 3, "host_container_id": "warehouse" if status == "sealed" else None,
                    "reward_id": reward["reward_id"], "status": status,
                    "opened_station_id": station if status == "opened" else None, "opened_tick": 0})
            database.execute("UPDATE encounter_state SET generation=3,respawn_remaining_s=15.25 WHERE snapshot_id=?", (snapshot,))

        p.save_copy(self.db, self.initial, "all-groups", "auto-world-a", 1, mutate=add_new_state)
        p.save_copy(self.db, "all-groups", "copied-groups", "auto-world-a", 2)
        snapshot, payload = p.load_slot(self.db, "auto-world-a", "all-groups-loader")
        self.assertEqual(snapshot["snapshot_id"], "copied-groups")
        self.assertEqual(set(payload), set(p.STATE_TABLES))
        strip_context = lambda row: {key: value for key, value in row.items() if key not in ("snapshot_id", "world_id", "content_snapshot_id")}
        for table in p.STATE_TABLES:
            with self.subTest(table=table):
                expected = [strip_context(row) for row in p.rows(self.db, table, "snapshot_id=?", ("all-groups",))]
                actual = [strip_context(row) for row in payload[table]]
                self.assertEqual(sorted(expected, key=lambda row: json.dumps(row, sort_keys=True)),
                                 sorted(actual, key=lambda row: json.dumps(row, sort_keys=True)))
        self.assertEqual(len(payload["salvage_package_state"]), 2)
        self.assertTrue(all(row["generation"] == 3 and row["respawn_remaining_s"] == 15.25 for row in payload["encounter_state"]))
        for table, sql in (("encounter_state", "UPDATE encounter_state SET generation=4 WHERE snapshot_id='copied-groups'"),
                           ("salvage_package_state", "DELETE FROM salvage_package_state WHERE snapshot_id='copied-groups'")):
            with self.subTest(immutable=table), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(sql)

    def test_new_state_rejects_cross_pool_reward_duplicate_source_and_overlong_refresh(self):
        package_def = p.rows(self.source, "salvage_package_defs")[0]
        rewards = p.rows(self.source, "salvage_reward_defs")
        reward = next(row for row in rewards if row["package_def_id"] == package_def["package_def_id"])
        different = next(row for row in rewards if row["package_def_id"] != package_def["package_def_id"])
        ctx = self.candidate()
        package = {**ctx, "package_id": "package-a", "package_def_id": package_def["package_def_id"],
                   "source_npc_instance_id": "historical-origin", "source_generation": 1, "host_container_id": "warehouse",
                   "reward_id": reward["reward_id"], "status": "sealed", "opened_station_id": None, "opened_tick": 0}
        p.insert(self.db, "salvage_package_state", package)
        with self.assertRaises(sqlite3.IntegrityError):
            p.insert(self.db, "salvage_package_state", {**package, "package_id": "same-source-second-package"})
        self.db.execute("UPDATE salvage_package_state SET reward_id=? WHERE snapshot_id='candidate'", (different["reward_id"],))
        with self.assertRaisesRegex(ValueError, "FK"):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()
        self.candidate()
        definition = p.rows(self.source, "encounter_defs")[0]
        self.db.execute("UPDATE encounter_state SET respawn_remaining_s=? WHERE snapshot_id='candidate' AND encounter_id=?",
                        (definition["respawn_seconds"] + 1, definition["encounter_id"]))
        with self.assertRaisesRegex(sqlite3.IntegrityError, "refresh over frozen definition"):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()

    def test_invalid_quantities_and_quaternion_rejected(self):
        self.candidate()
        for sql in ("UPDATE inventory_stack_state SET quantity=-1 WHERE snapshot_id='candidate'",
                    "UPDATE inventory_stack_state SET quantity=0.5 WHERE snapshot_id='candidate'",
                    "UPDATE ship_state SET quat_w=0 WHERE snapshot_id='candidate'",
                    "UPDATE player_state SET credit=-1 WHERE snapshot_id='candidate'"):
            with self.subTest(sql=sql), self.assertRaises(sqlite3.IntegrityError):
                self.db.execute(sql)
        self.db.rollback()
        self.candidate()
        self.db.execute("UPDATE rng_state SET increment_lo=55 WHERE snapshot_id='candidate'")
        with self.assertRaisesRegex(ValueError, "RNG"):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()

    def test_cross_world_and_cross_snapshot_entity_references_rejected(self):
        p.new_world(self.db, self.source, "world-b", "unused-content")
        self.candidate()
        self.db.execute("UPDATE inventory_stack_state SET world_id='world-b' WHERE snapshot_id='candidate'")
        self.assertTrue(self.db.execute("PRAGMA foreign_key_check").fetchall())
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.commit()
        self.db.rollback()
        self.candidate()
        self.db.execute("UPDATE equipment_state SET snapshot_id='missing-snapshot' WHERE snapshot_id='candidate'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.commit()
        self.db.rollback()

    def test_cross_content_reference_rejected(self):
        changed = sqlite3.connect(":memory:")
        self.addCleanup(changed.close)
        self.source.backup(changed)
        changed.execute("UPDATE ship_defs SET max_speed_mps=max_speed_mps+1 WHERE ship_id='shuttle_swift'")
        changed.execute("UPDATE catalog_meta SET content_hash=?", (build_catalog.logical_content_hash(changed),))
        changed.commit()
        _, other = p.new_world(self.db, changed, "world-b", "content-b")
        self.candidate()
        self.db.execute("UPDATE ship_state SET content_snapshot_id=? WHERE snapshot_id='candidate'", (other,))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.commit()
        self.db.rollback()

    def test_slot_cannot_target_another_world_or_unsealed_snapshot(self):
        p.new_world(self.db, self.source, "world-b", "unused-content")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE save_slot SET current_snapshot_id='initial-world-b',generation=generation+1 WHERE slot_id='auto-world-a'")
        self.candidate()
        with self.assertRaises(sqlite3.IntegrityError):
            p.publish_slot(self.db, "candidate", "auto-world-a", 1)
        self.db.rollback()

    def test_incomplete_snapshot_cannot_seal(self):
        for table in ("player_state", "rng_state", "resource_state", "shop_stock_state", "gate_state", "sector_state", "encounter_state"):
            with self.subTest(missing=table):
                self.candidate()
                self.db.execute(f'DELETE FROM "{table}" WHERE snapshot_id=?', ("candidate",))
                with self.assertRaises((ValueError, sqlite3.IntegrityError)):
                    p.validate_snapshot(self.db, "candidate")
                self.db.rollback()

    def test_failure_at_each_save_phase_preserves_old_endpoint(self):
        original = self.pointer()
        for stage in ("state", "seal", "pointer"):
            with self.subTest(stage=stage), self.assertRaises(RuntimeError):
                p.save_copy(self.db, self.initial, "failed-" + stage, "auto-world-a", 1, fault=stage)
            self.assertEqual(self.pointer(), original)
            self.assertEqual(self.db.execute("SELECT count(*) FROM save_snapshot WHERE snapshot_id=?", ("failed-" + stage,)).fetchone()[0], 0)

    def test_atomic_success_and_immutable_snapshot(self):
        old_credit = self.db.execute("SELECT credit FROM player_state WHERE snapshot_id=?", (self.initial,)).fetchone()[0]
        def change(database, snapshot):
            database.execute("UPDATE player_state SET credit=credit+1 WHERE snapshot_id=?", (snapshot,))
        p.save_copy(self.db, self.initial, "saved", "auto-world-a", 1, mutate=change)
        self.assertEqual(self.pointer(), ("saved", 2))
        self.assertEqual(self.db.execute("SELECT credit FROM player_state WHERE snapshot_id='saved'").fetchone()[0], old_credit + 1)
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE player_state SET credit=0 WHERE snapshot_id='saved'")
        self.assertEqual(self.db.execute("SELECT credit FROM player_state WHERE snapshot_id=?", (self.initial,)).fetchone()[0], old_credit)

    def test_equipment_has_one_location_and_stack_cannot_hold_module(self):
        ctx = self.candidate()
        item = p.rows(self.db, "item_instance_state", "snapshot_id=?", ("candidate",))[0]
        self.db.execute("UPDATE item_instance_state SET container_id='warehouse' WHERE snapshot_id='candidate' AND item_instance_id=?", (item["item_instance_id"],))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.commit()
        self.db.rollback()
        ctx = self.candidate()
        with self.assertRaises(sqlite3.IntegrityError):
            p.insert(self.db, "inventory_stack_state", {**ctx, "container_id": "warehouse", "stack_id": "illegal-module-stack", "item_def_id": item["item_def_id"], "quantity": 1, "origin_kind": "normal", "policy_id": "normal_owned"})
        self.db.rollback()

    def test_action_and_collect_event_idempotency_is_snapshot_local(self):
        p.save_copy(self.db, self.initial, "manual-earlier", "manual-world-a", None, slot_kind="manual")
        ctx = self.candidate(sequence=3)
        mission = self.accept_fixture_mission(ctx)
        receipt = {**ctx, "action_id": "action-1", "actor_player_id": "player-local", "source_epoch": 1,
                   "action_kind": "collect", "result_code": "OK", "result_entity_id": mission["mission_instance_id"]}
        p.insert(self.db, "action_receipt_state", receipt)
        with self.assertRaises(sqlite3.IntegrityError):
            p.insert(self.db, "action_receipt_state", receipt)
        event = {**ctx, "event_id": "collect-1", "mission_instance_id": mission["mission_instance_id"], "item_def_id": "ore_ferrosilicate", "quantity": 1, "event_tick": 1}
        p.insert(self.db, "mission_collect_event_state", event)
        with self.assertRaises(sqlite3.IntegrityError):
            p.insert(self.db, "mission_collect_event_state", event)
        p.validate_snapshot(self.db, "candidate")
        p.publish_slot(self.db, "candidate", "auto-world-a", 1)
        self.db.commit()
        # An independent manual slot selects the old immutable snapshot, not future receipts.
        selected, payload = p.load_slot(self.db, "manual-world-a", "rollback-session")
        self.assertEqual(selected["snapshot_id"], "manual-earlier")
        self.assertEqual(payload["action_receipt_state"], [])
        self.assertEqual(payload["mission_collect_event_state"], [])

    def test_reward_claim_and_initialization_cannot_duplicate(self):
        with self.assertRaises(sqlite3.IntegrityError):
            p.insert(self.db, "world_initialization_grant", dict(world_id="world-a", grant_id="another-grant", initial_snapshot_id=self.initial))
        ctx = self.candidate()
        mission = self.accept_fixture_mission(ctx)
        self.db.execute("UPDATE mission_state SET status='completed',reward_claimed=1 WHERE snapshot_id='candidate' AND mission_instance_id=?", (mission["mission_instance_id"],))
        with self.assertRaises(sqlite3.IntegrityError):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()

    def test_payload_and_module_maxima_are_checked_before_publish(self):
        def overload(database, snapshot):
            ctx = p.context(snapshot, "world-a", self.content)
            p.insert(database, "inventory_stack_state", {**ctx, "container_id": "hold-cargo", "stack_id": "overloaded-test",
                "item_def_id": "ore_ferrosilicate", "quantity": 1000, "origin_kind": "normal", "policy_id": "normal_owned"})
        with self.assertRaises(ValueError):
            p.save_copy(self.db, self.initial, "overloaded", "auto-world-a", 1, mutate=overload)
        self.assertEqual(self.pointer(), (self.initial, 1))
        self.candidate()
        self.db.execute("UPDATE ship_state SET shield=shield+1 WHERE snapshot_id='candidate'")
        with self.assertRaises(ValueError):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()

    def test_contract_window_caps_are_persistent_constraints(self):
        ctx = self.candidate()
        definition = p.rows(self.db, "frozen_mission_defs", "content_snapshot_id=? AND mission_id='contract_mining_iron'", (self.content,))[0]
        cap = self.db.execute("SELECT value_integer FROM frozen_rule_parameters WHERE content_snapshot_id=? AND parameter_id='contract_max_accepts_per_window'", (self.content,)).fetchone()[0]
        p.insert(self.db, "mission_window_state", {**ctx, "player_id": "player-local", "mission_def_id": definition["mission_id"],
            "remaining_s": definition["repeat_window_s"], "window_index": 0, "accepted_window_count": cap+1, "completed_window_count": 0})
        with self.assertRaises(sqlite3.IntegrityError):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()

    def test_accept_and_settle_counts_can_cross_world_window(self):
        ctx = self.candidate()
        definition = p.rows(self.db, "frozen_mission_defs", "content_snapshot_id=? AND mission_id='contract_mining_iron'", (self.content,))[0]
        # Accepted at t=1799 in window 0; settled at t=2100 in window 1.
        # Current-window counters are independent: zero accepts, one settlement.
        p.insert(self.db, "mission_window_state", {**ctx, "player_id": "player-local", "mission_def_id": definition["mission_id"],
            "remaining_s": definition["repeat_window_s"]-300, "window_index": 1, "accepted_window_count": 0,
            "completed_window_count": 1, "last_accept_tick": 1799*self.source.execute("SELECT value_integer FROM rule_parameters WHERE parameter_id='simulation_hz'").fetchone()[0],
            "last_settle_tick": 2100*self.source.execute("SELECT value_integer FROM rule_parameters WHERE parameter_id='simulation_hz'").fetchone()[0]})
        p.validate_snapshot(self.db, "candidate")
        p.publish_slot(self.db, "candidate", "auto-world-a", 1)
        self.db.commit()
        saved = p.rows(self.db, "mission_window_state", "snapshot_id='candidate'")[0]
        self.assertEqual((saved["accepted_window_count"], saved["completed_window_count"]), (0, 1))

    def test_initial_offers_do_not_create_attempts_or_repeat_world_grants(self):
        self.assertEqual(p.rows(self.db, "mission_state", "snapshot_id=?", (self.initial,)), [])
        first = p.rows(self.db, "mission_availability_state", "snapshot_id=? AND mission_def_id='tutorial_flight'", (self.initial,))[0]
        self.assertEqual(first["status"], "available")
        initial_grant = self.db.execute("SELECT count(*) FROM world_initialization_grant").fetchone()[0]
        p.load_slot(self.db, "auto-world-a", "read-again")
        self.assertEqual(self.db.execute("SELECT count(*) FROM world_initialization_grant").fetchone()[0], initial_grant)

    def test_hostile_ai_acquire_blocks_save_before_first_attack(self):
        ctx = self.candidate()
        spawn = p.rows(self.db, "frozen_npc_spawn_defs", "content_snapshot_id=? AND occurrence_mode='ambient'", (self.content,))[0]
        npc = p.rows(self.source, "npc_full_defs", "npc_id=?", (spawn["npc_id"],))[0]
        anchor = p.rows(self.db, "frozen_anchor_defs", "content_snapshot_id=? AND anchor_id=?", (self.content, spawn["anchor_id"]))[0]
        site = p.rows(self.db, "frozen_anchor_site_defs", "content_snapshot_id=? AND anchor_id=?", (self.content, spawn["anchor_id"]))[0]["site_id"]
        p.insert(self.db, "npc_state", {**ctx, "npc_instance_id": "npc-test-acquire", "spawn_id": spawn["spawn_id"],
            "sector_id": spawn["sector_id"], "generation": 0, "alive": 1, "shield": npc["shield_max"], "armor": npc["armor_max"], "hull": npc["hull_max"],
            "pos_x": anchor["x_m"], "pos_y": anchor["y_m"], "pos_z": anchor["z_m"], "quat_x": 0., "quat_y": 0., "quat_z": 0., "quat_w": 1.,
            "vel_x": 0., "vel_y": 0., "vel_z": 0., "angular_x": 0., "angular_y": 0., "angular_z": 0.,
            "behavior_phase": "acquire", "wait_remaining_s": 0., "patrol_point_index": 0, "cooldown_remaining_s": 0.,
            "respawn_remaining_s": 0., "bounty_claimed": 0, "loot_claimed": 0})
        p.insert(self.db, "spatial_state", {**ctx, "entity_kind": "npc", "entity_id": "npc-test-acquire", "site_id": site})
        # The active AI is local to the explicitly placed flying player; an
        # attack phase in a different site must not masquerade as local combat.
        self.db.execute("UPDATE ship_state SET sector_id=?,station_id=NULL,status='flying',pos_x=?,pos_y=?,pos_z=? WHERE snapshot_id='candidate' AND ship_instance_id='ship-guarantee'", (spawn["sector_id"], anchor["x_m"], anchor["y_m"], anchor["z_m"]))
        self.db.execute("UPDATE player_state SET docked_station_id=NULL WHERE snapshot_id='candidate'")
        self.db.execute("UPDATE container_state SET sector_id=? WHERE snapshot_id='candidate' AND ship_instance_id='ship-guarantee'", (spawn["sector_id"],))
        self.db.execute("UPDATE spatial_state SET site_id=? WHERE snapshot_id='candidate' AND entity_kind='ship' AND entity_id='ship-guarantee'", (site,))
        with self.assertRaisesRegex(sqlite3.IntegrityError, "active hostile AI"):
            p.validate_snapshot(self.db, "candidate")
        self.db.rollback()

    def test_loan_generation_quota_is_shared_and_restored(self):
        def loan(database, snapshot):
            ctx = p.context(snapshot, "world-a", self.content)
            service = p.rows(database, "frozen_loan_service_defs", "content_snapshot_id=? AND loan_service_id='loan_contract_miner'", (self.content,))[0]
            definition = p.rows(database, "frozen_mission_defs", "content_snapshot_id=? AND mission_id=?", (self.content, service["required_mission_id"]))[0]
            p.insert(database, "mission_state", {**ctx, "mission_instance_id": "attempt-loan", "player_id": "player-local", "mission_def_id": definition["mission_id"],
                "attempt_number": 1, "status": "active", "deadline_remaining_s": definition["deadline_s"], "cooldown_remaining_s": 0., "collected_units": 1, "delivered_units": 0, "reward_claimed": 0})
            destroyed = p.rows(database, "ship_state", "snapshot_id=?", (snapshot,))[0]
            destroyed.update(ship_instance_id="old-loan-ship", ship_def_id="miner_anvil", station_id=None, status="destroyed", hull=0., policy_id=service["policy_id"])
            p.insert(database, "ship_state", destroyed)
            station = p.rows(database, "frozen_station_defs", "content_snapshot_id=? AND station_id=?", (self.content, service["station_id"]))[0]
            source_site = p.rows(database, "frozen_anchor_site_defs", "content_snapshot_id=? AND anchor_id=?", (self.content, station["station_anchor_id"]))[0]["site_id"]
            p.insert(database, "spatial_state", {**ctx, "entity_kind": "ship", "entity_id": "old-loan-ship", "site_id": source_site})
            p.insert(database, "loan_state", {**ctx, "loan_id": "loan-contract-1", "player_id": "player-local", "loan_service_id": service["loan_service_id"], "mission_instance_id": "attempt-loan",
                "status": "lost", "issuance_count": 1, "quota_remaining_units": service["operation_quota_units"]-1, "replacement_remaining_s": service["replacement_cooldown_s"]})
            p.insert(database, "loan_issue_state", {**ctx, "loan_id": "loan-contract-1", "issuance_index": 1, "ship_instance_id": "old-loan-ship", "status": "destroyed"})
        p.save_copy(self.db, self.initial, "lost-loan", "auto-world-a", 1, mutate=loan)
        _, payload = p.load_slot(self.db, "auto-world-a", "loan-load")
        quota = self.source.execute("SELECT operation_quota_units FROM loan_service_defs WHERE loan_service_id='loan_contract_miner'").fetchone()[0]
        self.assertEqual(payload["loan_state"][0]["quota_remaining_units"], quota-1)
        self.assertEqual(payload["loan_issue_state"][0]["status"], "destroyed")
        self.assertEqual(next(ship for ship in payload["ship_state"] if ship["ship_instance_id"] == "old-loan-ship")["hull"], 0)
        self.assertEqual((payload["mission_state"][0]["mission_instance_id"], payload["mission_state"][0]["status"]), ("attempt-loan", "active"))
        deadline = payload["mission_state"][0]["deadline_remaining_s"]
        required = self.source.execute("SELECT required_count FROM mission_objective_defs WHERE mission_id='contract_mining_iron' AND objective_kind='collect'").fetchone()[0]
        def ready_with_lost_ship(database, snapshot):
            # Data-only witness: objectives had completed before the ship loss.
            database.execute("UPDATE mission_state SET status='ready',collected_units=? WHERE snapshot_id=?", (required, snapshot))
        p.save_copy(self.db, "lost-loan", "ready-lost-loan", "auto-world-a", 2, mutate=ready_with_lost_ship)
        _, ready = p.load_slot(self.db, "auto-world-a", "ready-loan-load")
        self.assertEqual((ready["mission_state"][0]["mission_instance_id"], ready["mission_state"][0]["status"], ready["mission_state"][0]["deadline_remaining_s"]), ("attempt-loan", "ready", deadline))
        self.assertEqual((ready["loan_state"][0]["issuance_count"], ready["loan_state"][0]["quota_remaining_units"]), (1, quota-1))

    def test_active_engine_paid_remainder_restores_without_second_charge(self):
        def active_engine(database, snapshot):
            cost = database.execute("SELECT energy_eu FROM frozen_module_defs WHERE content_snapshot_id=? AND module_id='module_engine_vector_i'", (self.content,)).fetchone()[0]
            database.execute("UPDATE ship_state SET energy=energy-? WHERE snapshot_id=?", (cost, snapshot))
            database.execute("UPDATE equipment_state SET active_remaining_s=.5,cycle_paid=1 WHERE snapshot_id=? AND module_def_id='module_engine_vector_i'", (snapshot,))
        p.save_copy(self.db, self.initial, "engine-active", "auto-world-a", 1, mutate=active_engine)
        saved, payload = p.load_slot(self.db, "auto-world-a", "load-engine")
        engine = next(row for row in payload["equipment_state"] if row["module_def_id"] == "module_engine_vector_i")
        self.assertEqual((engine["active_remaining_s"], engine["cycle_paid"]), (.5, 1))
        before_energy = p.rows(self.db, "ship_state", "snapshot_id='engine-active'")[0]["energy"]
        self.assertEqual(payload["ship_state"][0]["energy"], before_energy)

    def test_scene_prepare_failure_keeps_epoch_and_previous_world_usable(self):
        original = p.rows(self.db, "runtime_session")[0]
        def fail(_snapshot, _payload):
            raise RuntimeError("Injected missing exit/asset during staging")
        with self.assertRaises(RuntimeError):
            p.load_slot(self.db, "auto-world-a", "failed-load", prepare=fail)
        self.assertEqual(p.rows(self.db, "runtime_session")[0], original)
        p.save_copy(self.db, self.initial, "still-savable", "auto-world-a", 1)

    def test_stale_ui_selection_does_not_load_a_replaced_slot(self):
        p.save_copy(self.db, self.initial, "new-target", "auto-world-a", 1)
        epoch = p.rows(self.db, "runtime_session")[0]["epoch"]
        with self.assertRaisesRegex(ValueError, "STALE_SELECTION"):
            p.load_slot(self.db, "auto-world-a", "load-stale", expected_snapshot=self.initial, expected_generation=1)
        self.assertEqual(p.rows(self.db, "runtime_session")[0]["epoch"], epoch)

    def test_old_epoch_writer_rejected_after_successful_load(self):
        self.candidate("queued-old")
        p.validate_snapshot(self.db, "queued-old")
        self.db.commit()  # Reference fixture for a delayed already-prepared callback.
        old_epoch = p.rows(self.db, "runtime_session")[0]["epoch"]
        p.load_slot(self.db, "auto-world-a", "new-load-session")
        self.assertEqual(p.rows(self.db, "runtime_session")[0]["epoch"], old_epoch + 1)
        with self.assertRaises(sqlite3.IntegrityError):
            p.publish_slot(self.db, "queued-old", "auto-world-a", 1)
        self.assertEqual(self.pointer(), (self.initial, 1))
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO save_snapshot SELECT 'stale-insert',world_id,content_snapshot_id,writer_session_id,writer_epoch,'stale-request',capture_sequence,saved_utc,simulation_tick,reason,transfer_id,'building' FROM save_snapshot WHERE snapshot_id='queued-old'")

    def test_old_capture_sequence_and_compare_swap_rejected(self):
        self.candidate("queued-older", sequence=2)
        p.validate_snapshot(self.db, "queued-older")
        self.db.commit()
        p.save_copy(self.db, self.initial, "newer", "auto-world-a", 1, sequence=3)
        with self.assertRaises(sqlite3.IntegrityError):
            p.publish_slot(self.db, "queued-older", "auto-world-a", 2)
        with self.assertRaises(ValueError):
            p.save_copy(self.db, "newer", "wrong-generation", "auto-world-a", 1, sequence=4)
        self.assertEqual(self.pointer(), ("newer", 2))

    def test_transition_endpoints_are_atomic_with_cost_and_position(self):
        original_credit = p.rows(self.db, "player_state", "snapshot_id=?", (self.initial,))[0]["credit"]
        self.db.execute("UPDATE runtime_session SET transfer_barrier_id='transfer-1' WHERE world_id='world-a'")
        def endpoint(database, snapshot, where):
            ctx = p.context(snapshot, "world-a", self.content)
            database.execute("DELETE FROM transfer_state WHERE snapshot_id=?", (snapshot,))
            p.insert(database, "transfer_state", {**ctx, "transfer_id": "transfer-1", "ship_instance_id": "ship-guarantee", "connection_id": "conn_anchor_echo", "endpoint": where})
            if where == "destination":
                door = p.rows(database, "frozen_gate_endpoint_defs", "content_snapshot_id=? AND connection_id=? AND origin_sector_id='sector_anchor'", (self.content, "conn_anchor_echo"))[0]
                exit_anchor = p.rows(database, "frozen_anchor_defs", "content_snapshot_id=? AND anchor_id=?", (self.content, door["exit_anchor_id"]))[0]
                exit_site = p.rows(database, "frozen_anchor_site_defs", "content_snapshot_id=? AND anchor_id=?", (self.content, door["exit_anchor_id"]))[0]["site_id"]
                database.execute("UPDATE player_state SET credit=credit-1,docked_station_id=NULL WHERE snapshot_id=?", (snapshot,))  # Test-only nonzero cost fault witness.
                database.execute("UPDATE ship_state SET sector_id='sector_echo',station_id=NULL,status='flying',pos_x=?,pos_y=?,pos_z=? WHERE snapshot_id=?", (exit_anchor["x_m"], exit_anchor["y_m"], exit_anchor["z_m"], snapshot))
                database.execute("UPDATE spatial_state SET site_id=? WHERE snapshot_id=? AND entity_kind='ship' AND entity_id='ship-guarantee'", (exit_site, snapshot))
                database.execute("UPDATE container_state SET sector_id='sector_echo' WHERE snapshot_id=? AND kind<>'station'", (snapshot,))
        p.save_copy(self.db, self.initial, "origin", "auto-world-a", 1, reason="travel_origin", transfer_id="transfer-1", mutate=lambda db, snap: endpoint(db, snap, "origin"))
        with self.assertRaises(RuntimeError):
            p.save_copy(self.db, "origin", "failed-destination", "auto-world-a", 2, reason="travel_destination", transfer_id="transfer-1", mutate=lambda db, snap: endpoint(db, snap, "destination"), fault="pointer")
        self.assertEqual(self.pointer(), ("origin", 2))
        self.assertEqual(p.rows(self.db, "player_state", "snapshot_id='origin'")[0]["credit"], original_credit)
        # Remove the origin receipt before inserting destination receipt with same transfer ID.
        def destination(database, snapshot):
            database.execute("DELETE FROM transfer_state WHERE snapshot_id=?", (snapshot,))
            endpoint(database, snapshot, "destination")
        p.save_copy(self.db, "origin", "destination", "auto-world-a", 2, reason="travel_destination", transfer_id="transfer-1", mutate=destination)
        self.assertEqual(self.pointer(), ("destination", 3))
        self.assertEqual(p.rows(self.db, "player_state", "snapshot_id='destination'")[0]["credit"], original_credit - 1)
        self.assertEqual(p.rows(self.db, "ship_state", "snapshot_id='destination'")[0]["sector_id"], "sector_echo")

    def test_backup_and_retention_preserve_slots_initial_and_loaded(self):
        p.save_copy(self.db, self.initial, "old-unreferenced", "auto-world-a", 1)
        p.save_copy(self.db, "old-unreferenced", "current", "auto-world-a", 2)
        with tempfile.TemporaryDirectory(prefix="progress-backup-", dir=ROOT / "jiaoben/tmp") as directory:
            backup = Path(directory) / "backup.db"
            p.backup(self.db, backup)
            restored = p.connect(backup)
            self.addCleanup(restored.close)
            self.assertEqual(restored.execute("PRAGMA integrity_check").fetchall(), [("ok",)])
            self.assertEqual(restored.execute("SELECT current_snapshot_id FROM save_slot").fetchone()[0], "current")
            p.verify_frozen_content(restored, self.content)
            restored.close()
        p.prune_unreferenced(self.db, keep_recent=1)
        self.assertEqual({row[0] for row in self.db.execute("SELECT snapshot_id FROM save_snapshot")}, {self.initial, "current"})
        self.assertEqual(self.db.execute("PRAGMA foreign_key_check").fetchall(), [])
        self.assertEqual(self.pointer(), ("current", 3))


if __name__ == "__main__":
    unittest.main(verbosity=2)
