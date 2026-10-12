#!/usr/bin/env python3
"""Repeatable SQL fixture/reference harness; not a Godot SaveService.

No production progress.db is created. CLI writes only jiaoben/tmp. All gameplay
definition values are read from catalog.db or its frozen relational copy.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import sqlite3
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog

PROGRESS_DIR = ROOT / "code/database/progress"
MIGRATIONS = ("001_core.sql", "002_frozen_catalog.sql", "003_seal_validation.sql", "004_immutability.sql", "005_singleplayer_expansion.sql", "006_signal_and_gate_lifetime.sql", "007_profile_resume.sql", "008_paid_engine_family.sql", "009_encounters_and_salvage.sql", "010_combat_and_lighting.sql", "011_space_locations.sql", "012_civilizations.sql", "013_industry.sql", "014_resource_intel.sql", "015_exploration.sql", "016_mobile_belts.sql", "017_tactics.sql", "018_operations.sql", "019_fitting.sql", "020_roles.sql", "021_honors.sql", "022_frontier.sql", "023_hire.sql", "024_situational.sql", "025_campaign.sql")
FORMAT_VERSION = 22
ADAPTER = PROGRESS_DIR / "catalog_adapter_v0_21.sql"
ADAPTER_VERSION = "frozen_catalog_v0_21"
REVIEWED_ADAPTERS = {
    "frozen_catalog_v0_3": PROGRESS_DIR / "catalog_adapter_v0_3.sql",
    "frozen_catalog_v0_4": PROGRESS_DIR / "catalog_adapter_v0_4.sql",
    "frozen_catalog_v0_4_r2": PROGRESS_DIR / "catalog_adapter_v0_4_r2.sql",
    "frozen_catalog_v0_5": PROGRESS_DIR / "catalog_adapter_v0_5.sql",
    "frozen_catalog_v0_6": PROGRESS_DIR / "catalog_adapter_v0_6.sql",
    "frozen_catalog_v0_7": PROGRESS_DIR / "catalog_adapter_v0_7.sql",
    "frozen_catalog_v0_8": PROGRESS_DIR / "catalog_adapter_v0_8.sql",
    "frozen_catalog_v0_9": PROGRESS_DIR / "catalog_adapter_v0_9.sql",
    "frozen_catalog_v0_10": PROGRESS_DIR / "catalog_adapter_v0_10.sql",
    "frozen_catalog_v0_11": PROGRESS_DIR / "catalog_adapter_v0_11.sql",
    "frozen_catalog_v0_12": PROGRESS_DIR / "catalog_adapter_v0_12.sql",
    "frozen_catalog_v0_13": PROGRESS_DIR / "catalog_adapter_v0_13.sql",
    "frozen_catalog_v0_14": PROGRESS_DIR / "catalog_adapter_v0_14.sql",
    "frozen_catalog_v0_15": PROGRESS_DIR / "catalog_adapter_v0_15.sql",
    "frozen_catalog_v0_16": PROGRESS_DIR / "catalog_adapter_v0_16.sql",
    "frozen_catalog_v0_17": PROGRESS_DIR / "catalog_adapter_v0_17.sql",
    "frozen_catalog_v0_18": PROGRESS_DIR / "catalog_adapter_v0_18.sql",
    "frozen_catalog_v0_19": PROGRESS_DIR / "catalog_adapter_v0_19.sql",
    "frozen_catalog_v0_20": PROGRESS_DIR / "catalog_adapter_v0_20.sql",
    "frozen_catalog_v0_21": ADAPTER,
}
RULE_CODE_VERSION = "singleplayer_campaign_v1"
ASSET_VERSION = "placeholder-b-v1"
ASSET_MANIFEST = ROOT / "code/assets/placeholders/manifest.json"
STATE_TABLES = (
    "player_state", "ship_state", "container_state", "item_instance_state", "equipment_state",
    "inventory_stack_state", "mission_state", "mission_objective_state", "mission_window_state",
    "mission_collect_event_state", "mission_claim_state",
    "mission_availability_state",
    "loan_state", "loan_asset_state", "loan_issue_state", "manufacture_input_state",
    "discovery_state", "unlock_state", "reputation_state", "resource_state", "gate_state",
    "ship_gate_cooldown_state", "sector_state", "station_economy_state", "shop_stock_state",
    "shop_ship_stock_state", "npc_state", "production_state", "rng_state", "action_receipt_state", "transfer_state", "base_module_state",
    "encounter_state", "salvage_package_state", "spatial_state",
    "civilization_state", "territory_state", "war_campaign_state", "war_fleet_state",
    "industry_job_state", "industry_input_state", "station_demand_state",
    "exploration_instance_state", "exploration_actor_state", "exploration_claim_state",
    "exploration_progress_state", "exploration_research_state",
    "exploration_belt_state",
    "specialization_progress_state", "specialization_evidence_state", "specialization_research_state",
    "remote_support_state", "consignment_state", "consignment_receipt_state",
    "civilization_command_state", "civilization_honor_evidence_state",
    "frontier_campaign_state", "frontier_actor_state", "frontier_campaign_receipt_state", "frontier_territory_state", "frontier_journal_state", "frontier_supply_order_state", "frontier_director_state",
    "hire_contract_state", "hire_receipt_state", "resource_intel_state", "demand_intel_state", "construction_state", "construction_input_state", "construction_receipt_state", "construction_evidence_state", "expedition_route_state", "expedition_run_state", "expedition_stage_state", "expedition_receipt_state", "campaign_director_state", "flight_record_state", "telemetry_total_state",
    "operation_state",
    "tactical_site_state", "npc_tactic_state", "ship_tactical_effect_state", "drone_bay_state",
)


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def connect(path=":memory:"):
    connection = sqlite3.connect(path, isolation_level=None)
    connection.execute("PRAGMA foreign_keys=ON")
    connection.execute("PRAGMA journal_mode=DELETE")
    connection.execute("PRAGMA synchronous=EXTRA")
    connection.execute("PRAGMA busy_timeout=2000")
    return connection


def apply_migrations(connection, fault_after=None):
    applied = []
    if connection.execute("SELECT count(*) FROM sqlite_schema WHERE type='table'").fetchone()[0]:
        identity = connection.execute("SELECT application_id,format_version FROM database_meta").fetchone()
        if not identity or identity[0] != "xingjizhanjian" or identity[1] not in range(1, FORMAT_VERSION + 1):
            raise ValueError("Unsupported progress identity/format; preserve source and require explicit migration")
        history = dict(connection.execute("SELECT migration_id,sql_sha256 FROM migration_history"))
        applied = sorted(history)
        if tuple(applied) != MIGRATIONS[:len(applied)]:
            raise ValueError("Unknown or noncontiguous migration history")
        if len(applied) != identity[1] + 3:
            raise ValueError("Migration history and progress format disagree")
        for name in applied:
            expected = hashlib.sha256((PROGRESS_DIR / name).read_bytes()).hexdigest()
            if history[name] != expected:
                raise ValueError(f"Migration checksum mismatch: {name}")
        if len(applied) == len(MIGRATIONS):
            if identity[1] != FORMAT_VERSION or connection.execute("PRAGMA user_version").fetchone()[0] != FORMAT_VERSION:
                raise ValueError("Migration history and progress format disagree")
            return
    # executescript can implicitly commit an existing transaction: exactly one
    # combined script starts BEGIN, no nested executescript during freeze/save.
    pieces = ["BEGIN IMMEDIATE;"]
    for index, name in enumerate(MIGRATIONS, 1):
        if name in applied:
            continue
        text = (PROGRESS_DIR / name).read_text(encoding="utf-8")
        pieces.append(text)
        checksum = hashlib.sha256(text.encode()).hexdigest()
        pieces.append("INSERT INTO migration_history VALUES(" + repr(name) + "," + repr(checksum) + "," + repr(utc_now()) + ");")
        if index == fault_after:
            pieces.append("SELECT missing_migration_fault();")
    pieces.append(f"PRAGMA user_version={FORMAT_VERSION};")
    try:
        connection.executescript("\n".join(pieces))
        connection.commit()
    except BaseException:
        connection.rollback()
        raise


def insert(connection, table, values):
    columns = ",".join('"' + name + '"' for name in values)
    marks = ",".join("?" for _ in values)
    connection.execute(f'INSERT INTO "{table}" ({columns}) VALUES ({marks})', tuple(values.values()))


def rows(connection, table, where="", parameters=()):
    cursor = connection.execute(f'SELECT * FROM "{table}"' + (" WHERE " + where if where else ""), parameters)
    names = [column[0] for column in cursor.description]
    return [dict(zip(names, row, strict=True)) for row in cursor]


def adapter_connection(version=None):
    # Select only checked-in reviewed DDL. The current override supports the
    # compatibility-tuple fault fixtures without accepting save-provided SQL.
    path = ADAPTER if version in (None, ADAPTER_VERSION) else REVIEWED_ADAPTERS.get(version)
    if path is None:
        raise ValueError("Unsupported frozen adapter")
    connection = connect()
    connection.executescript(path.read_text(encoding="utf-8"))
    return connection


def adapter_hash(connection):
    """catalog_hash_v1 using this fixed adapter's table/view registry, not current catalog.

    The archive is reviewed source, never SQL read from a saved manifest. This
    function deliberately keeps old adapter verification independent of a new
    release's build_catalog.CONTENT_TABLES registry.
    """
    names = [r[0] for r in connection.execute("SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name COLLATE BINARY")]
    digest = hashlib.sha256()
    encode = build_catalog.encode_field
    digest.update(encode("catalog_hash_v1"))
    for table in names:
        columns = [(r[1], r[2], r[5]) for r in connection.execute(f'PRAGMA table_info("{table}")')
                   if not (table == "catalog_meta" and r[1] == "content_hash")]
        digest.update(b"B" + encode(table))
        digest.update(encode(len(columns), "INTEGER"))
        for name, sql_type, pk in columns:
            digest.update(b"C" + encode(name) + encode(sql_type) + encode(pk, "INTEGER"))
        keys = [c[0] for c in sorted(columns, key=lambda c: c[2]) if c[2]]
        ordering = ",".join('"' + key + '" COLLATE BINARY' for key in keys)
        selection = ",".join('"' + c[0] + '"' for c in columns)
        values = connection.execute(f'SELECT {selection} FROM "{table}" ORDER BY {ordering}').fetchall()
        digest.update(encode(len(values), "INTEGER"))
        for row in values:
            digest.update(b"R")
            for value, (_, sql_type, _) in zip(row, columns, strict=True):
                digest.update(encode(value, sql_type))
    for name, sql in connection.execute("SELECT name,sql FROM sqlite_schema WHERE type='view' ORDER BY name COLLATE BINARY"):
        digest.update(b"V" + encode(name) + encode(sql))
    return digest.hexdigest()


def verify_frozen_content(connection, content_id):
    meta = connection.execute("SELECT content_hash,frozen_adapter_version FROM content_snapshot WHERE content_snapshot_id=?", (content_id,)).fetchone()
    if not meta or (meta[1] != ADAPTER_VERSION and meta[1] not in REVIEWED_ADAPTERS):
        raise ValueError("Unsupported frozen adapter")
    adapter = adapter_connection(meta[1])
    try:
        names = [r[0] for r in adapter.execute("SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name")]
        manifest = {r["table_name"]: r for r in rows(connection, "content_table_manifest", "content_snapshot_id=?", (content_id,))}
        if set(names) != set(manifest):
            raise ValueError("Frozen table manifest is not a full registered closure")
        adapter.execute("BEGIN")
        adapter.execute("PRAGMA defer_foreign_keys=ON")
        for table in names:
            info = adapter.execute(f'PRAGMA table_info("{table}")').fetchall()
            signature = "|".join(f"{r[1]}:{r[2]}:{r[5]}" for r in info
                                 if not(table == "catalog_meta" and r[1] == "content_hash"))
            if manifest[table]["schema_signature"] != signature:
                raise ValueError(f"Frozen schema signature mismatch {table}")
            columns = [r[1] for r in info]
            selection = ",".join('"' + column + '"' for column in columns)
            values = connection.execute(f'SELECT {selection} FROM "frozen_{table}" WHERE content_snapshot_id=?', (content_id,)).fetchall()
            if len(values) != manifest[table]["row_count"]:
                raise ValueError(f"Frozen row count mismatch {table}")
            adapter.executemany(f'INSERT INTO "{table}" VALUES(' + ",".join("?" for _ in columns) + ")", values)
        views = {r["view_name"]: r for r in rows(connection, "content_view_manifest", "content_snapshot_id=?", (content_id,))}
        reviewed_views = dict(adapter.execute("SELECT name,sql FROM sqlite_schema WHERE type='view'"))
        if set(views) != set(reviewed_views):
            raise ValueError("Frozen view manifest mismatch")
        for name, definition in reviewed_views.items():
            if views[name]["reviewed_source_sql"] != definition or views[name]["sql_sha256"] != hashlib.sha256(definition.encode()).hexdigest():
                raise ValueError(f"Fixed reviewed view version mismatch {name}")
        adapter.commit()
        if adapter.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("Frozen definition reference closure broken")
        actual = adapter_hash(adapter)
        if actual != meta[0]:
            raise ValueError("Frozen logical content hash mismatch")
        return actual
    finally:
        adapter.close()


def verify_asset_manifest():
    """Verify canonical logical manifest identity plus each original resource file.

    Pretty JSON file bytes are not asset_manifest_sha256. The self hash is
    excluded and the remaining JSON is encoded exactly as doc20 specifies.
    This verifies source assets; it does not instantiate Godot scenes.
    """
    manifest = json.loads(ASSET_MANIFEST.read_text(encoding="utf-8"))
    expected = manifest.pop("manifest_sha256", None)
    canonical = json.dumps(manifest, ensure_ascii=False, sort_keys=True,
                           separators=(",", ":"), allow_nan=False).encode("utf-8")
    actual = hashlib.sha256(canonical).hexdigest()
    if expected != actual or manifest.get("asset_version") != ASSET_VERSION:
        raise ValueError("Asset manifest canonical identity/version mismatch")
    resources = manifest.get("resources")
    if not isinstance(resources, list) or not resources:
        raise ValueError("Asset manifest requires resource entries")
    seen_ids, seen_paths = set(), set()
    for entry in resources:
        asset_id, resource_path = entry["asset_id"], entry["resource_path"]
        if asset_id in seen_ids or resource_path in seen_paths or not resource_path.startswith("res://"):
            raise ValueError("Duplicate or invalid asset manifest resource")
        seen_ids.add(asset_id)
        seen_paths.add(resource_path)
        path = (ROOT / "code" / resource_path.removeprefix("res://")).resolve()
        if not path.is_relative_to(ROOT / "code") or not path.is_file():
            raise ValueError("Missing/outside-project asset resource")
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError("Asset resource file hash mismatch")
    return actual


def freeze_catalog(connection, source, content_id):
    """Called inside the new-world/explicit-content-migration transaction."""
    source.execute("PRAGMA foreign_keys=ON")
    build_catalog.validate_database(source)
    logical = build_catalog.logical_content_hash(source)
    metadata = rows(source, "catalog_meta")[0]
    if metadata["content_hash"] != logical:
        raise ValueError("Source catalog hash mismatch")
    asset_hash = verify_asset_manifest()
    identity = (logical, RULE_CODE_VERSION, ASSET_VERSION, asset_hash, ADAPTER_VERSION)
    existing = connection.execute("SELECT content_snapshot_id FROM content_snapshot WHERE content_hash=? AND rules_code_version=? AND asset_manifest_version=? AND asset_manifest_sha256=? AND frozen_adapter_version=?", identity).fetchone()
    if existing:
        verify_frozen_content(connection, existing[0])
        return existing[0]
    connection.execute("PRAGMA defer_foreign_keys=ON")
    insert(connection, "content_snapshot", dict(content_snapshot_id=content_id, content_hash=logical,
           pack_id=metadata["pack_id"], content_version=metadata["content_version"],
           catalog_schema_version=metadata["schema_version"], ruleset_version=metadata["ruleset_version"],
           rules_code_version=RULE_CODE_VERSION, asset_manifest_version=ASSET_VERSION,
           asset_manifest_sha256=asset_hash,
           frozen_adapter_version=ADAPTER_VERSION, created_utc=utc_now(), status="building"))
    for table in sorted(build_catalog.CONTENT_TABLES):
        data = rows(source, table)
        for row in data:
            insert(connection, "frozen_" + table, {"content_snapshot_id": content_id, **row})
        insert(connection, "content_table_manifest", dict(content_snapshot_id=content_id, table_name=table,
               schema_signature=build_catalog.CONTENT_COLUMNS[table], row_count=len(data)))
    for name, definition in build_catalog.content_views(source).items():
        insert(connection, "content_view_manifest", dict(content_snapshot_id=content_id, view_name=name,
               reviewed_source_sql=definition, sql_sha256=hashlib.sha256(definition.encode()).hexdigest()))
    verify_frozen_content(connection, content_id)
    connection.execute("UPDATE content_snapshot SET status='sealed' WHERE content_snapshot_id=?", (content_id,))
    return content_id


def context(snapshot, world, content):
    return dict(snapshot_id=snapshot, world_id=world, content_snapshot_id=content)


def initial_state(connection, snapshot, world, content):
    """Minimal data-only initial fixture: derives grants and stock from the DB."""
    ctx = context(snapshot, world, content)
    frozen = lambda table: rows(connection, "frozen_" + table, "content_snapshot_id=?", (content,))
    rule = {r["parameter_id"]: r["value_integer"] if r["value_integer"] is not None else r["value_real"] for r in frozen("rule_parameters")}
    profile = frozen("starting_profile_defs")[0]
    grant = next(r for r in frozen("starting_ships") if r["grant_kind"] == "owned")
    loadout = next(r for r in frozen("ship_loadout_defs") if r["loadout_id"] == grant["loadout_id"])
    ship = next(r for r in frozen("ship_defs") if r["ship_id"] == loadout["ship_id"])
    station = next(r for r in frozen("station_defs") if r["sector_id"] == "sector_anchor")
    ship_id, player_id = "ship-guarantee", "player-local"
    insert(connection, "player_state", {**ctx, "player_id": player_id, "controlled_ship_id": ship_id,
        "currency_id": profile["currency_id"], "credit": profile["starting_credit"], "camera_mode": "follow", "docked_station_id": station["station_id"]})
    insert(connection, "ship_state", {**ctx, "ship_instance_id": ship_id, "owner_player_id": player_id,
        "ship_def_id": ship["ship_id"], "sector_id": station["sector_id"], "station_id": station["station_id"], "status": "docked",
        "pos_x": 0., "pos_y": 0., "pos_z": 0., "quat_x": 0., "quat_y": 0., "quat_z": 0., "quat_w": 1.,
        "vel_x": 0., "vel_y": 0., "vel_z": 0., "angular_x": 0., "angular_y": 0., "angular_z": 0.,
        "shield": ship["shield_max"], "armor": ship["armor_max"], "hull": ship["hull_max"], "energy": ship["energy_max"], "heat": 0.,
        "overheated": 0, "shield_delay_remaining_s": 0., "state_version": 0, "policy_id": grant["policy_id"]})
    site = next(r["site_id"] for r in frozen("anchor_site_defs") if r["anchor_id"] == station["station_anchor_id"])
    insert(connection, "spatial_state", {**ctx, "entity_kind": "ship", "entity_id": ship_id, "site_id": site})
    base_container = {**ctx, "owner_player_id": player_id, "sector_id": station["sector_id"]}
    insert(connection, "container_state", {**base_container, "container_id": "hold-cargo", "kind": "cargo", "ship_instance_id": ship_id, "ship_def_id": ship["ship_id"]})
    insert(connection, "container_state", {**base_container, "container_id": "warehouse", "kind": "station", "station_id": station["station_id"]})
    salvage = {r["module_id"]: r["recipe_id"] for r in frozen("module_salvage_recipe_defs")}
    for index, fit in enumerate(r for r in frozen("ship_loadout_items") if r["loadout_id"] == loadout["loadout_id"]):
        container, item = f"slot-{index}", f"module-guarantee-{index}"
        insert(connection, "container_state", {**base_container, "container_id": container, "kind": "slot", "ship_instance_id": ship_id,
              "ship_def_id": ship["ship_id"], "slot_type": fit["slot_type"], "slot_index": fit["slot_index"]})
        insert(connection, "item_instance_state", {**ctx, "item_instance_id": item, "item_def_id": fit["module_id"], "owner_player_id": player_id,
              "container_id": container, "policy_id": grant["policy_id"], "origin_kind": "guarantee", "salvage_recipe_id": salvage[fit["module_id"]],
              "durability": rule["module_durability_max"], "quality_multiplier": rule["standard_quality_multiplier"]})
        insert(connection, "equipment_state", {**ctx, "slot_container_id": container, "item_instance_id": item, "module_def_id": fit["module_id"], "cooldown_remaining_s": 0., "active_remaining_s": 0., "cycle_paid": 0, "enabled": 0})
    for index, supply in enumerate(r for r in frozen("loadout_supply_defs") if r["loadout_id"] == loadout["loadout_id"]):
        insert(connection, "inventory_stack_state", {**ctx, "container_id": "hold-cargo", "stack_id": f"protected-supply-{index}", "item_def_id": supply["item_id"], "quantity": supply["quantity"], "origin_kind": "guarantee", "policy_id": grant["policy_id"]})
    starting_policies = {(r["profile_template_id"], r["item_id"]): r["policy_id"] for r in frozen("starting_inventory_policy_defs")}
    for index, inventory in enumerate(frozen("starting_inventory")):
        if inventory["quantity"]:
            insert(connection, "inventory_stack_state", {**ctx, "container_id": "warehouse", "stack_id": f"starting-{index}", "item_def_id": inventory["item_id"], "quantity": inventory["quantity"], "origin_kind": "normal", "policy_id": starting_policies[(inventory["profile_template_id"], inventory["item_id"])]})
    initially_unlocked = {u["unlock_id"] for u in frozen("unlock_defs") if u["initially_unlocked"]}
    prerequisites = {prerequisite["mission_id"] for prerequisite in frozen("mission_prerequisites")}
    for mission in frozen("mission_defs"):
        eligible = mission["required_unlock_id"] in initially_unlocked and mission["mission_id"] not in prerequisites
        insert(connection, "mission_availability_state", {**ctx, "player_id": player_id, "mission_def_id": mission["mission_id"], "status": "available" if eligible else "locked"})
    for unlock in frozen("unlock_defs"):
        if unlock["initially_unlocked"]:
            insert(connection, "unlock_state", {**ctx, "player_id": player_id, "unlock_id": unlock["unlock_id"], "acquired_tick": 0})
    managed_nodes = {r["node_id"] for r in frozen("exploration_resource_defs")}
    for node in frozen("resource_node_defs"):
        insert(connection, "resource_state", {**ctx, "node_id": node["node_id"], "remaining_units": 0 if node["node_id"] in managed_nodes else node["capacity_units"], "respawn_remaining_s": 0.})
    for connection_def in frozen("connection_defs"):
        gate = next(g for g in frozen("gate_class_defs") if g["gate_class_id"] == connection_def["gate_class_id"])
        insert(connection, "gate_state", {**ctx, "connection_id": connection_def["connection_id"], "enabled": 1, "remaining_mass_budget_kg": gate["total_mass_budget_kg"], "lifetime_remaining_s": gate["lifetime_s"]})
    for sector in frozen("sector_defs"):
        insert(connection, "sector_state", {**ctx, "sector_id": sector["sector_id"], "visited": int(sector["sector_id"] == station["sector_id"]), "generation_counter": 0})
    for encounter in frozen("encounter_defs"):
        insert(connection, "encounter_state", {**ctx, "encounter_id": encounter["encounter_id"], "generation": 0, "respawn_remaining_s": 0.})
    items = {r["item_id"]: r for r in frozen("item_defs")}
    ships = {r["ship_id"]: r for r in frozen("ship_defs")}
    stations = {r["station_id"]: r for r in frozen("station_defs")}
    for definition in frozen("station_stock_defs"):
        item = items[definition["item_id"]]
        insert(connection, "shop_stock_state", {**ctx, "station_id": definition["station_id"], "item_def_id": definition["item_id"], "quantity": definition["initial_units"],
              "buyback_remaining_units": definition["buyback_units_per_refresh"], "ask_credit": item["base_ask_credit"], "bid_credit": item["base_bid_credit"], "refresh_remaining_s": stations[definition["station_id"]]["stock_refresh_s"]})
    for definition in frozen("station_ship_stock_defs"):
        ship = ships[definition["ship_id"]]
        insert(connection, "shop_ship_stock_state", {**ctx, "station_id": definition["station_id"], "ship_def_id": definition["ship_id"], "quantity": definition["initial_units"], "ask_credit": ship["base_ask_credit"], "bid_credit": ship["base_bid_credit"], "refresh_remaining_s": stations[definition["station_id"]]["stock_refresh_s"]})
    for station in stations.values():
        insert(connection, "station_economy_state", {**ctx, "station_id": station["station_id"], "buyback_remaining_credit": station["buyback_budget_credit"], "refresh_remaining_s": station["stock_refresh_s"]})
    if frozen("civilization_defs"):
        insert(connection, "civilization_state", {**ctx, "player_id": player_id, "faction_id": None, "joined_tick": 0, "switch_cooldown_remaining_s": 0.0})
        for policy in frozen("sector_sovereignty_defs"):
            insert(connection, "territory_state", {**ctx, "sector_id": policy["sector_id"], "faction_id": policy["initial_faction_id"], "captured_tick": 0})
    for demand in frozen("station_demand_defs"):
        insert(connection, "station_demand_state", {**ctx, "demand_id": demand["demand_id"], "generation": 1, "status": "active", "remaining_units": demand["required_units"], "phase_remaining_s": demand["duration_s"], "benefit_remaining_s": 0.0, "completed_cycles": 0})
    # PCG32 standard initialization (doc21 §3.1): two discarded steps, no
    # gameplay draws. 54 and the multiplier are fixed algorithm constants.
    seed = connection.execute("SELECT seed FROM world WHERE world_id=?", (world,)).fetchone()[0]
    events = frozen("exploration_event_defs")
    for event in events:
        variant_seed = int(hashlib.sha256(f"{seed}:{event['event_id']}".encode()).hexdigest()[:8], 16)
        variants = sorted((r for r in frozen("exploration_variant_defs") if r["event_id"] == event["event_id"]), key=lambda r: r["variant_index"])
        insert(connection, "exploration_instance_state", {**ctx, "event_id": event["event_id"], "generation": 1, "variant_id": variants[variant_seed % len(variants)]["variant_id"], "variant_seed": variant_seed, "phase": "clue", "choice_id": "", "operation_kind": "", "operation_remaining_s": 0.0, "elapsed_s": 0.0, "cooldown_remaining_s": 0.0, "evidence_units": 0, "stabilized": 0, "hazard_clock_s": 0.0, "outcome": ""})
    if events:
        insert(connection, "exploration_progress_state", {**ctx, "player_id": player_id, "insight_available": 0, "insight_earned": 0})
    for route in frozen("exploration_belt_route_defs"):
        if route["route_index"] != 0:
            continue
        event = rows(connection, "exploration_instance_state", "snapshot_id=? AND event_id=?", (snapshot, route["event_id"]))[0]
        variant = next(r for r in frozen("exploration_variant_defs") if r["variant_id"] == event["variant_id"])
        insert(connection, "exploration_belt_state", {**ctx, "event_id": route["event_id"], "route_id": route["route_id"], "stage_index": 0, "warning_stage_index": 0, "start_elapsed_s": 0.0, "initial_units": variant["mineral_units"]})
    if frozen("weapon_tuning_defs"):
        insert(connection,"specialization_progress_state",{**ctx,"player_id":player_id,"earned_points":0,"spent_points":0,"donated_points":0})
    for spec in frozen("frontier_campaign_defs"):
        insert(connection,"frontier_campaign_state",{**ctx,"war_id":spec["war_id"]})
    for spec in frozen("frontier_governance_defs"):
        insert(connection,"frontier_territory_state",{**ctx,"sector_id":spec["sector_id"]})
    if frozen("frontier_balance_defs"):
        insert(connection,"frontier_director_state",{**ctx,"player_id":player_id,"next_event_s":frozen("frontier_balance_defs")[0]["crisis_max_s"]})
    if frozen("campaign_balance_defs"):
        for project in frozen("construction_project_defs"):
            insert(connection,"construction_state",{**ctx,"project_id":project["project_id"],"stage_index":1,"phase":"gathering"})
        for spec in frozen("construction_input_defs"):
            insert(connection,"construction_input_state",{**ctx,"project_id":spec["project_id"],"stage_index":spec["stage_index"],"item_id":spec["item_id"],"delivery_station_id":spec["delivery_station_id"]})
        for route in frozen("expedition_route_defs"):
            insert(connection,"expedition_route_state",{**ctx,"route_id":route["route_id"]})
        index=int(hashlib.sha256(f"{seed}:campaign".encode()).hexdigest()[:8],16)%3
        insert(connection,"campaign_director_state",{**ctx,"singleton":1,"focus_index":index,"generation":1,"remaining_s":frozen("campaign_balance_defs")[0]["director_period_s"]})
        credit=connection.execute('SELECT credit FROM player_state WHERE snapshot_id=?',(snapshot,)).fetchone()[0]
        insert(connection,"telemetry_total_state",{**ctx,"singleton":1,"next_sequence":1,"wallet_last":credit})
    for spec in frozen("civilization_command_defs"):
        insert(connection,"civilization_command_state",{**ctx,"player_id":player_id,"faction_id":spec["faction_id"]})
    for spec in frozen("consignment_defs"):
        insert(connection,"consignment_state",{**ctx,"contract_id":spec["contract_id"]})
    for operation in frozen("operation_defs"):
        insert(connection, "operation_state", {**ctx,"operation_id":operation["operation_id"],"generation":0,"phase":"available","remaining_s":0.0,"cooldown_remaining_s":0.0,"payload_ship_id":None,"loaded_units":0,"cargo_units":0,"completed_units":0,"lost_units":0,"jettisoned_units":0,"exposure_remaining_s":0.0,"damage_debt_hp":0.0,"rewarded_units_total":0,"paid_credit_total":0})
    for site in frozen("tactical_site_defs"):
        insert(connection, "tactical_site_state", {**ctx, "site_id": site["site_id"], "generation": 0, "respawn_remaining_s": 0.0, "cleared_cycles": 0})
    drones = {r["module_id"]: r for r in frozen("drone_management_defs")}
    counts = {r["module_id"]: r["drone_count"] for r in frozen("drone_defs")}
    for item in rows(connection, "item_instance_state", "snapshot_id=?", (snapshot,)):
        if item["item_def_id"] in drones:
            insert(connection, "drone_bay_state", {**ctx, "item_instance_id": item["item_instance_id"], "stock_units": counts[item["item_def_id"]], "deployed_units": 0, "lost_units": 0, "replenished_units": 0, "paid_credit_total": 0, "material_units_total": 0, "revision": 0, "command_kind": "attack"})
    mask64 = (1 << 64) - 1
    increment = (54 << 1) | 1
    state = ((increment + (seed & mask64)) * 6364136223846793005 + increment) & mask64
    insert(connection, "rng_state", {**ctx, "stream_id": "world", "algorithm": "pcg32_v1", "state_hi": state >> 32, "state_lo": state & ((1 << 32) - 1), "increment_hi": 0, "increment_lo": increment})


def begin_snapshot(connection, snapshot, world, content, sequence, reason="manual", transfer_id=None):
    session = rows(connection, "runtime_session", "world_id=?", (world,))[0]
    insert(connection, "save_snapshot", dict(snapshot_id=snapshot, world_id=world, content_snapshot_id=content,
           writer_session_id=session["session_id"], writer_epoch=session["epoch"], save_request_id="save-" + snapshot,
           capture_sequence=sequence, saved_utc=utc_now(), simulation_tick=sequence,
           reason=reason, transfer_id=transfer_id, status="building"))


def copy_state(connection, old, new, world, content):
    for table in STATE_TABLES:
        for row in rows(connection, table, "snapshot_id=?", (old,)):
            row.update(context(new, world, content))
            insert(connection, table, row)
    insert(connection, "snapshot_lineage", dict(child_snapshot_id=new, parent_snapshot_id=old))


def validate_snapshot(connection, snapshot):
    for table in STATE_TABLES:
        info = connection.execute(f'PRAGMA table_info("{table}")').fetchall()
        real_columns = [row[1] for row in info if row[2] == "REAL"]
        for row in rows(connection, table, "snapshot_id=?", (snapshot,)):
            if any(row[name] is not None and not math.isfinite(row[name]) for name in real_columns):
                raise ValueError(f"Non-finite state in {table}")
    if connection.execute("PRAGMA foreign_key_check").fetchall():
        raise ValueError("State FK validation failed")
    rng = rows(connection, "rng_state", "snapshot_id=?", (snapshot,))
    if len(rng) != 1 or (rng[0]["stream_id"], rng[0]["algorithm"], rng[0]["increment_hi"], rng[0]["increment_lo"]) != ("world", "pcg32_v1", 0, 109):
        raise ValueError("Invalid B world RNG stream/algorithm/increment")
    validate_ship_aggregates(connection, snapshot)
    # AI/projectile/scene/interaction eligibility belongs to the runtime adapter.
    connection.execute("UPDATE save_snapshot SET status='sealed' WHERE snapshot_id=? AND status='building'", (snapshot,))


def validate_ship_aggregates(connection, snapshot):
    content = connection.execute("SELECT content_snapshot_id FROM save_snapshot WHERE snapshot_id=?", (snapshot,)).fetchone()[0]
    frozen = lambda table: rows(connection, "frozen_" + table, "content_snapshot_id=?", (content,))
    definitions = {r["ship_id"]: r for r in frozen("ship_defs")}
    modules = {r["module_id"]: r for r in frozen("module_defs")}
    items = {r["item_id"]: r for r in frozen("item_defs")}
    groups = {r["group_id"]: r for r in frozen("module_exclusion_groups")}
    members = defaultdict(list)
    for row in frozen("module_group_members"):
        members[row["module_id"]].append(row["group_id"])
    instances = {r["item_instance_id"]: r for r in rows(connection, "item_instance_state", "snapshot_id=?", (snapshot,))}
    containers = {r["container_id"]: r for r in rows(connection, "container_state", "snapshot_id=?", (snapshot,))}
    equipment = rows(connection, "equipment_state", "snapshot_id=?", (snapshot,))
    stacks = rows(connection, "inventory_stack_state", "snapshot_id=?", (snapshot,))
    for ship in rows(connection, "ship_state", "snapshot_id=?", (snapshot,)):
        definition = definitions[ship["ship_def_id"]]
        installed = [instances[e["item_instance_id"]] for e in equipment
                     if containers[e["slot_container_id"]]["ship_instance_id"] == ship["ship_instance_id"]]
        counts = Counter(item["item_def_id"] for item in installed)
        family = Counter()
        for module_id, count in counts.items():
            maximum = modules[module_id]["max_per_ship"]
            if maximum is not None and count > maximum:
                raise ValueError("Module same-type installation limit exceeded")
            for group in members[module_id]:
                family[group] += count
        if any(count > groups[group]["max_installed"] for group, count in family.items()):
            raise ValueError("Module exclusion group exceeded")
        if sum(modules[i["item_def_id"]]["power_pu"] for i in installed) > definition["power_capacity"] or sum(modules[i["item_def_id"]]["cpu_cu"] for i in installed) > definition["cpu_capacity"]:
            raise ValueError("Installed power/CPU budget exceeded")
        if sum(items[i["item_def_id"]]["unit_mass_kg"] for i in installed) > definition["max_installed_mass_kg"]:
            raise ValueError("Installed mass exceeded")
        if any(item["owner_player_id"] != ship["owner_player_id"] for item in installed):
            raise ValueError("Installed module owner differs from ship owner")
        added_hp = defaultdict(float)
        for row in frozen("module_stat_modifiers"):
            if row["operation"] == "add":
                added_hp[row["stat_id"]] += row["amount"] * counts[row["module_id"]]
        for layer in ("shield", "armor", "hull", "energy", "heat"):
            maximum = definition[layer + "_max"] + added_hp[layer + "_max"]
            if ship[layer] > maximum + 1e-7:
                raise ValueError(f"Ship {layer} exceeds fitted maximum")
        package_defs = {r["package_def_id"]: r for r in frozen("salvage_package_defs")}
        packages = rows(connection, "salvage_package_state", "snapshot_id=? AND status='sealed'", (snapshot,))
        payload_mass = 0.0
        for container in containers.values():
            if container["ship_instance_id"] != ship["ship_instance_id"] or container["kind"] not in ("cargo", "mineral"):
                continue
            cargo = [(i["item_def_id"], 1) for i in instances.values() if i["container_id"] == container["container_id"]]
            cargo += [(stack["item_def_id"], stack["quantity"]) for stack in stacks if stack["container_id"] == container["container_id"]]
            if container["kind"] == "mineral" and any(items[item]["item_type"] != "ore" for item, _ in cargo):
                raise ValueError("Non-ore in mineral hold")
            held_packages = [package_defs[p["package_def_id"]] for p in packages if p["host_container_id"] == container["container_id"]]
            if held_packages and container["kind"] != "cargo":
                raise ValueError("Recovery package outside ordinary cargo hold")
            volume = sum(items[item]["unit_volume_l"] * quantity for item, quantity in cargo)
            volume += sum(package["volume_m3"] * 1000 for package in held_packages)
            capacity = definition["cargo_l"] if container["kind"] == "cargo" else definition["mineral_cargo_l"]
            if volume > capacity:
                raise ValueError("Cargo volume exceeded")
            payload_mass += sum(items[item]["unit_mass_kg"] * quantity for item, quantity in cargo)
            payload_mass += sum(package["mass_kg"] for package in held_packages)
        if payload_mass > definition["max_payload_mass_kg"] + 1e-7:
            raise ValueError("Shared cargo/mineral payload mass exceeded")


def publish_slot(connection, snapshot, slot, expected_generation=None, slot_kind="auto", slot_index=0):
    save = rows(connection, "save_snapshot", "snapshot_id=?", (snapshot,))[0]
    world = rows(connection, "world", "world_id=?", (save["world_id"],))[0]
    values = dict(profile_id=world["profile_id"], world_id=world["world_id"], current_snapshot_id=snapshot,
                  content_snapshot_id=save["content_snapshot_id"], writer_session_id=save["writer_session_id"],
                  writer_epoch=save["writer_epoch"], updated_utc=utc_now())
    if expected_generation is None:
        insert(connection, "save_slot", {"slot_id": slot, **values, "slot_kind": slot_kind, "slot_index": slot_index, "label": "fixture", "generation": 1})
    else:
        result = connection.execute("UPDATE save_slot SET current_snapshot_id=?,content_snapshot_id=?,writer_session_id=?,writer_epoch=?,generation=generation+1,updated_utc=? WHERE slot_id=? AND world_id=? AND generation=?",
            (snapshot, save["content_snapshot_id"], save["writer_session_id"], save["writer_epoch"], utc_now(), slot, world["world_id"], expected_generation))
        if result.rowcount != 1:
            raise ValueError("Save slot compare-and-swap conflict")
    connection.execute("UPDATE runtime_session SET last_committed_sequence=?,resume_snapshot_id=? WHERE world_id=?", (save["capture_sequence"], snapshot, save["world_id"]))


def new_world(connection, source, world="world-a", content="content-a", profile="profile-a"):
    connection.execute("BEGIN IMMEDIATE")
    try:
        content = freeze_catalog(connection, source, content)
        if not connection.execute("SELECT 1 FROM profile WHERE profile_id=?", (profile,)).fetchone():
            insert(connection, "profile", dict(profile_id=profile, display_name=profile, created_utc=utc_now()))
        insert(connection, "world", dict(world_id=world, profile_id=profile, display_name=world, mode="offline", seed=42, initial_content_snapshot_id=content, created_utc=utc_now()))
        insert(connection, "runtime_session", dict(world_id=world, session_id="session-" + world, epoch=1))
        snapshot = "initial-" + world
        begin_snapshot(connection, snapshot, world, content, 1, "initial")
        initial_state(connection, snapshot, world, content)
        validate_snapshot(connection, snapshot)
        publish_slot(connection, snapshot, "auto-" + world)
        insert(connection, "world_initialization_grant", dict(world_id=world, grant_id="grant-" + world, initial_snapshot_id=snapshot))
        connection.commit()
        return snapshot, content
    except BaseException:
        connection.rollback()
        raise


def save_copy(connection, source_snapshot, new_snapshot, slot, expected_generation, mutate=None, fault=None,
              reason="manual", transfer_id=None, sequence=None, slot_kind="auto", slot_index=0):
    parent = rows(connection, "save_snapshot", "snapshot_id=?", (source_snapshot,))[0]
    session = rows(connection, "runtime_session", "world_id=?", (parent["world_id"],))[0]
    connection.execute("BEGIN IMMEDIATE")
    connection.execute("PRAGMA defer_foreign_keys=ON")
    try:
        begin_snapshot(connection, new_snapshot, parent["world_id"], parent["content_snapshot_id"],
                       sequence if sequence is not None else session["last_committed_sequence"] + 1, reason, transfer_id)
        copy_state(connection, source_snapshot, new_snapshot, parent["world_id"], parent["content_snapshot_id"])
        if mutate:
            mutate(connection, new_snapshot)
        if fault == "state":
            raise RuntimeError("Injected state write failure")
        validate_snapshot(connection, new_snapshot)
        if fault == "seal":
            raise RuntimeError("Injected failure after seal")
        publish_slot(connection, new_snapshot, slot, expected_generation, slot_kind, slot_index)
        if fault == "pointer":
            raise RuntimeError("Injected failure after pointer update, before COMMIT")
        connection.commit()
    except BaseException:
        connection.rollback()
        raise


def load_slot(connection, slot, session_id, prepare=None, expected_snapshot=None, expected_generation=None):
    # Real SaveService establishes its queue/world barrier before this reference
    # harness. Capture the selected pointer once; staging does not hold SQL locks.
    connection.execute("BEGIN")
    try:
        selected = rows(connection, "save_slot", "slot_id=?", (slot,))[0]
        if expected_snapshot is not None and selected["current_snapshot_id"] != expected_snapshot:
            raise ValueError("STALE_SELECTION snapshot changed")
        if expected_generation is not None and selected["generation"] != expected_generation:
            raise ValueError("STALE_SELECTION slot generation changed")
        active = rows(connection, "runtime_session", "world_id=?", (selected["world_id"],))[0]
        snapshot = rows(connection, "save_snapshot", "snapshot_id=?", (selected["current_snapshot_id"],))[0]
        verify_frozen_content(connection, selected["content_snapshot_id"])
        compatibility = rows(connection, "content_snapshot", "content_snapshot_id=?", (selected["content_snapshot_id"],))[0]
        if compatibility["rules_code_version"] != RULE_CODE_VERSION or compatibility["asset_manifest_version"] != ASSET_VERSION or compatibility["asset_manifest_sha256"] != verify_asset_manifest():
            raise ValueError("Rules/asset compatibility mismatch; preserve save without fallback")
        payload = {table: rows(connection, table, "snapshot_id=?", (snapshot["snapshot_id"],)) for table in STATE_TABLES}
        connection.commit()
    except BaseException:
        connection.rollback()
        raise
    if prepare:
        prepare(snapshot, payload)  # Any scene/asset failure leaves epoch unchanged.
    connection.execute("BEGIN IMMEDIATE")
    try:
        changed = connection.execute("UPDATE runtime_session SET session_id=?,epoch=epoch+1,loaded_snapshot_id=?,resume_snapshot_id=?,transfer_barrier_id=NULL,last_committed_sequence=0 WHERE world_id=? AND session_id=? AND epoch=?",
                           (session_id, snapshot["snapshot_id"], snapshot["snapshot_id"], selected["world_id"], active["session_id"], active["epoch"]))
        if changed.rowcount != 1:
            raise ValueError("Session CAS changed while staging")
        connection.commit()
        # Godot must do a prevalidated, non-failing in-memory world/context swap
        # before releasing the barrier. No scene code is implemented here.
        return snapshot, payload
    except BaseException:
        connection.rollback()
        raise


def backup(connection, destination):
    if connection.in_transaction:
        raise ValueError("Backup only after writer transaction finishes")
    destination = Path(destination)
    temporary = destination.with_suffix(destination.suffix + ".partial")
    target = sqlite3.connect(temporary)
    try:
        connection.backup(target)
        if target.execute("PRAGMA integrity_check").fetchall() != [("ok",)] or target.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("Backup validation failed")
        for (content_id,) in target.execute("SELECT content_snapshot_id FROM content_snapshot WHERE status='sealed'"):
            verify_frozen_content(target, content_id)
        target.close()
        temporary.replace(destination)
    finally:
        target.close()
        temporary.unlink(missing_ok=True)


def prune_unreferenced(connection, keep_recent):
    if keep_recent < 1:
        raise ValueError("Keep at least one recent successful snapshot")
    connection.execute("BEGIN IMMEDIATE")
    try:
        worlds = [r[0] for r in connection.execute("SELECT world_id FROM world")]
        for world in worlds:
            newest = [r[0] for r in connection.execute("SELECT snapshot_id FROM save_snapshot WHERE world_id=? AND status='sealed' ORDER BY rowid DESC LIMIT ?", (world, keep_recent))]
            protected = set(newest)
            protected.update(r[0] for r in connection.execute("SELECT current_snapshot_id FROM save_slot WHERE world_id=?", (world,)))
            protected.update(r[0] for r in connection.execute("SELECT initial_snapshot_id FROM world_initialization_grant WHERE world_id=?", (world,)))
            protected.update(r[0] for r in connection.execute("SELECT loaded_snapshot_id FROM runtime_session WHERE world_id=? AND loaded_snapshot_id IS NOT NULL", (world,)))
            protected.update(r[0] for r in connection.execute("SELECT resume_snapshot_id FROM runtime_session WHERE world_id=? AND resume_snapshot_id IS NOT NULL", (world,)))
            protected.update(r[0] for r in connection.execute("SELECT source_snapshot_id FROM content_upgrade_record WHERE world_id=? UNION SELECT upgraded_snapshot_id FROM content_upgrade_record WHERE world_id=?", (world, world)))
            for snapshot, in connection.execute("SELECT snapshot_id FROM save_snapshot WHERE world_id=?", (world,)).fetchall():
                if snapshot not in protected:
                    connection.execute("DELETE FROM save_snapshot WHERE snapshot_id=?", (snapshot,))
        connection.commit()
    except BaseException:
        connection.rollback()
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "jiaoben/tmp/progress-fixture.db")
    output = parser.parse_args().output.resolve()
    if not output.is_relative_to(ROOT / "jiaoben/tmp"):
        raise SystemExit("Fixture output must be inside jiaoben/tmp")
    if output.exists():
        raise SystemExit("Fixture already exists; choose another path to preserve it")
    source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
    connection = connect(output)
    try:
        apply_migrations(connection)
        snapshot, content = new_world(connection, source)
        print(f"Fixture: {output}; initial snapshot: {snapshot}; frozen content: {content}")
        print(f"Integrity: {connection.execute('PRAGMA integrity_check').fetchone()[0]}")
    finally:
        source.close()
        connection.close()
