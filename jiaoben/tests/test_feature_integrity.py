"""Independent catalogue, resource and command graph integrity checks.

These checks inspect the shipped SQLite catalogue read-only. They deliberately
do not emulate Gameplay or claim to replace the real Main/SQLite probes.
"""

from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CODE = ROOT / "code"
LEGACY_VISUAL_BYTES = {
    "res://runtime/visuals/visual_effects.gd": "res://assets/legacy_art_full_v1/visual_effects.gd.txt",
    "res://runtime/visuals/visual_effect_node.gd": "res://assets/legacy_art_full_v1/visual_effect_node.gd.txt",
}


def manifest_resource_path(data: dict, resource_path: str) -> Path:
    """Resolve fixed V1 byte archives without loading them as GDScript."""
    checked = LEGACY_VISUAL_BYTES.get(resource_path, resource_path) if data.get("asset_version") == "art-full-v1" else resource_path
    return CODE / checked.removeprefix("res://")


def manifest_canonical_hash(data: dict) -> str:
    canonical = {key: value for key, value in data.items() if key != "manifest_sha256"}
    return hashlib.sha256(json.dumps(canonical, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode("utf-8")).hexdigest()


def strings(source: str) -> set[str]:
    return set(re.findall(r'"([^"\n]+)"', source))


def function(source: str, name: str) -> str:
    match = re.search(rf"(?m)^func {re.escape(name)}\(", source)
    if match is None:
        raise AssertionError(f"Missing function {name}")
    next_function = re.search(r"(?m)^func ", source[match.end() :])
    end = match.end() + next_function.start() if next_function else len(source)
    return source[match.start() : end]


class FeatureIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.db = sqlite3.connect(f"file:{CODE / 'data/catalog.db'}?mode=ro", uri=True)
        cls.db.row_factory = sqlite3.Row
        cls.runtime = {
            path.relative_to(CODE).as_posix(): path.read_text(encoding="utf-8")
            for path in (CODE / "runtime").rglob("*.gd")
        }

    @classmethod
    def tearDownClass(cls) -> None:
        cls.db.close()

    def rows(self, table: str) -> list[sqlite3.Row]:
        return list(self.db.execute(f"SELECT * FROM {table}"))

    def ids(self, table: str, column: str) -> set[str]:
        return {row[column] for row in self.rows(table) if row[column] is not None}

    def test_sqlite_integrity(self) -> None:
        self.assertEqual([row[0] for row in self.db.execute("PRAGMA integrity_check")], ["ok"])

    def test_all_foreign_keys_resolve(self) -> None:
        self.assertEqual(list(self.db.execute("PRAGMA foreign_key_check")), [])

    def test_every_item_has_obtainable_source(self) -> None:
        # Start with actual sources, then close the recipe graph. An isolated
        # cycle of recipes cannot certify that either item is obtainable.
        reachable: set[str] = set()
        for table, column in (
            ("starting_inventory", "item_id"),
            ("loadout_supply_defs", "item_id"),
            ("resource_node_defs", "item_id"),
            ("npc_loot_defs", "item_id"),
            ("salvage_reward_defs", "item_def_id"),
            ("ship_loadout_items", "module_id"),
        ):
            reachable |= self.ids(table, column)
        reachable |= {
            row["item_id"]
            for row in self.rows("station_stock_defs")
            if row["allow_buy"] and (row["initial_units"] > 0 or row["restock_units_per_refresh"] > 0)
        }
        inputs: dict[str, set[str]] = {}
        for row in self.rows("recipe_inputs"):
            inputs.setdefault(row["recipe_id"], set()).add(row["item_id"])
        access = self.ids("recipe_access_defs", "recipe_id")
        changed = True
        while changed:
            before = len(reachable)
            for recipe in self.rows("recipe_defs"):
                if recipe["recipe_id"] in access and inputs.get(recipe["recipe_id"], set()) <= reachable:
                    reachable.add(recipe["output_item_id"])
            changed = len(reachable) != before
        self.assertEqual(self.ids("item_defs", "item_id") - reachable, set())

    def test_every_item_has_use_or_market_sink(self) -> None:
        consumers = self.ids("module_defs", "module_id")
        for table, column in (
            ("recipe_inputs", "item_id"),
            ("hull_recipe_inputs", "item_id"),
            ("research_inputs", "item_id"),
            ("base_module_inputs", "item_id"),
            ("weapon_defs", "ammo_item_id"),
            ("repair_defs", "consumable_item_id"),
            ("mission_objective_defs", "target_item_id"),
        ):
            consumers |= self.ids(table, column)
        consumers |= {
            row["item_id"] for row in self.rows("station_stock_defs")
            if row["allow_sell"] and row["buyback_units_per_refresh"] > 0
        }
        self.assertEqual(self.ids("item_defs", "item_id") - consumers, set())

    def test_every_module_has_operational_effect(self) -> None:
        operational: set[str] = set()
        for table in ("weapon_defs", "repair_defs", "mining_defs", "module_stat_modifiers", "module_resistance_modifiers"):
            operational |= self.ids(table, "module_id")
        self.assertEqual(self.ids("module_defs", "module_id"), operational)

    def test_every_module_can_fit_at_least_one_real_hull(self) -> None:
        ships = {row["ship_id"]: row for row in self.rows("ship_defs")}
        slots = {(row["ship_id"], row["slot_type"]) for row in self.rows("ship_slot_defs")}
        items = {row["item_id"]: row for row in self.rows("item_defs")}
        for module in self.rows("module_defs"):
            with self.subTest(module=module["module_id"]):
                candidates = [ship for ship in ships.values()
                    if (ship["ship_id"], module["slot_type"]) in slots
                    and ship["power_capacity"] >= module["power_pu"]
                    and ship["cpu_capacity"] >= module["cpu_cu"]
                    and ship["max_installed_mass_kg"] >= items[module["module_id"]]["unit_mass_kg"]]
                self.assertTrue(candidates, "No hull admits even this module alone")

    def test_all_module_recipes_have_access_and_traceable_output(self) -> None:
        recipes = {row["recipe_id"]: row for row in self.rows("recipe_defs")}
        access = self.ids("recipe_access_defs", "recipe_id")
        origins = {row["module_id"]: row["recipe_id"] for row in self.rows("module_salvage_recipe_defs")}
        self.assertEqual(set(origins), self.ids("module_defs", "module_id"))
        for module_id, recipe_id in origins.items():
            with self.subTest(module=module_id):
                self.assertEqual(recipes[recipe_id]["output_item_id"], module_id)
                self.assertIn(recipe_id, access)

    def test_all_recipes_have_inputs_and_station_access(self) -> None:
        self.assertEqual(self.ids("recipe_defs", "recipe_id"), self.ids("recipe_inputs", "recipe_id"))
        self.assertEqual(self.ids("recipe_defs", "recipe_id"), self.ids("recipe_access_defs", "recipe_id"))

    def test_echo_silica_has_manufacturing_use(self) -> None:
        # Doc 12/13 promise that this unique ore becomes a sensor material.
        # A market buyback alone cannot certify its promised industrial use.
        recipes = list(self.db.execute("""
            SELECT r.recipe_id FROM recipe_defs AS r
            JOIN recipe_inputs AS i USING (recipe_id)
            WHERE i.item_id = 'ore_echo_silica' AND i.quantity > 0
              AND r.output_item_id = 'component_sensor_core' AND r.output_quantity > 0
        """))
        self.assertTrue(recipes, "Echo silica has no sensor-core manufacturing consumer")

    def test_every_recipe_has_reachable_manufacturing_station(self) -> None:
        # Graph reachability is checked separately from service and recipe rows:
        # an access row in a non-manufacturing port is not a usable recipe.
        sectors = {"sector_anchor"}
        finite_gates = {row["gate_class_id"] for row in self.rows("gate_class_defs")
                        if row["lifetime_s"] is not None}
        changed = True
        while changed:
            before = len(sectors)
            for link in self.rows("connection_defs"):
                if link["gate_class_id"] in finite_gates:
                    continue
                if link["origin_sector_id"] in sectors:
                    sectors.add(link["target_sector_id"])
                if link["bidirectional"] and link["target_sector_id"] in sectors:
                    sectors.add(link["origin_sector_id"])
            changed = len(sectors) != before
        stations = {row["station_id"] for row in self.rows("station_defs") if row["sector_id"] in sectors}
        factories = {row["station_id"] for row in self.rows("station_service_defs")
                     if row["service_id"] == "manufacture" and row["station_id"] in stations}
        usable_recipes = {row["recipe_id"] for row in self.rows("recipe_access_defs")
                          if row["station_id"] in factories}
        self.assertEqual(self.ids("recipe_defs", "recipe_id") - usable_recipes, set())

    def test_every_hull_has_manufacturing_market_and_geometry(self) -> None:
        hulls = self.ids("ship_defs", "ship_id")
        self.assertEqual(hulls, self.ids("hull_recipe_defs", "ship_id"))
        self.assertEqual(hulls, self.ids("station_ship_stock_defs", "ship_id"))
        self.assertEqual(self.ids("hull_recipe_defs", "hull_recipe_id"), self.ids("hull_recipe_inputs", "hull_recipe_id"))
        for hull in hulls:
            with self.subTest(hull=hull):
                self.assertTrue((CODE / "assets/ships" / f"{hull}.tscn").is_file())

    def test_resources_have_real_location_and_mining_compatibility(self) -> None:
        self.assertEqual(self.ids("resource_node_defs", "node_id"), self.ids("resource_node_locations", "node_id"))
        types = {row["item_id"]: row["item_type"] for row in self.rows("item_defs")}
        compatible = self.ids("mining_compatibility", "item_id")
        for node in self.rows("resource_node_defs"):
            if types[node["item_id"]] == "ore":
                with self.subTest(node=node["node_id"]):
                    self.assertIn(node["item_id"], compatible)

    def test_facilities_have_effect_consumers(self) -> None:
        # Each of these is an explicit completed facility promised by doc 23.
        expected = {"repair", "industry", "navigation", "warehouse"}
        self.assertEqual({row["service_kind"] for row in self.rows("base_module_defs")}, expected)
        runtime = "\n".join(self.runtime.values())
        for kind in expected:
            with self.subTest(service=kind):
                self.assertRegex(runtime, rf'base_factor\("{kind}"\)')
        self.assertEqual(self.ids("base_module_defs", "base_module_id"), self.ids("base_module_inputs", "base_module_id"))

    def test_all_connections_have_both_endpoints(self) -> None:
        endpoints = self.rows("gate_endpoint_defs")
        for connection in self.rows("connection_defs"):
            with self.subTest(connection=connection["connection_id"]):
                pairs = {(row["origin_sector_id"], row["target_sector_id"])
                         for row in endpoints if row["connection_id"] == connection["connection_id"]}
                self.assertIn((connection["origin_sector_id"], connection["target_sector_id"]), pairs)
                if connection["bidirectional"]:
                    self.assertIn((connection["target_sector_id"], connection["origin_sector_id"]), pairs)

    def test_all_salvage_packages_have_spawn_and_reward_consumers(self) -> None:
        packages = self.ids("salvage_package_defs", "package_def_id")
        self.assertEqual(packages, self.ids("npc_salvage_defs", "package_def_id"))
        self.assertEqual(packages, self.ids("salvage_reward_defs", "package_def_id"))
        for package in packages:
            with self.subTest(package=package):
                self.assertGreater(sum(row["weight"] for row in self.rows("salvage_reward_defs") if row["package_def_id"] == package), 0)

    def test_business_portraits_cover_catalogue_identifiers(self) -> None:
        manifest = json.loads((CODE / "assets/business_v11/manifest.json").read_text(encoding="utf-8"))
        mappings = {(row["kind"], row["id"]) for row in manifest["entries"]}
        for table, column, kind in (
            ("ship_defs", "ship_id", "ship"), ("item_defs", "item_id", "item"),
            ("mission_defs", "mission_id", "mission"), ("research_defs", "research_id", "research"),
            ("base_module_defs", "base_module_id", "facility"), ("recipe_defs", "recipe_id", "blueprint"),
            ("hull_recipe_defs", "hull_recipe_id", "blueprint"),
        ):
            with self.subTest(table=table):
                self.assertEqual({(kind, value) for value in self.ids(table, column)} - mappings, set())

    def test_manifest_assets_exist_with_matching_digests(self) -> None:
        checked = 0
        for path in (CODE / "assets").rglob("manifest.json"):
            data = json.loads(path.read_text(encoding="utf-8"))
            if "manifest_sha256" in data:
                with self.subTest(manifest=path.relative_to(CODE).as_posix(), canonical=True):
                    self.assertEqual(manifest_canonical_hash(data), data["manifest_sha256"])
            for asset in data.get("resources", []):
                resource_path = asset.get("resource_path", asset.get("path", ""))
                with self.subTest(manifest=path.relative_to(CODE).as_posix(), asset=resource_path):
                    self.assertTrue(resource_path.startswith("res://"))
                    self.assertNotIn("..", Path(resource_path.removeprefix("res://")).parts)
                    resource = manifest_resource_path(data, resource_path)
                    if data.get("asset_version") == "art-full-v1" and resource_path in LEGACY_VISUAL_BYTES:
                        self.assertEqual(resource.suffix, ".txt", "V1 bytes are inert archives")
                        self.assertNotIn(resource.relative_to(CODE).as_posix(), self.runtime)
                    self.assertTrue(resource.is_file())
                    self.assertEqual(hashlib.sha256(resource.read_bytes()).hexdigest(), asset["sha256"])
                    checked += 1
        self.assertGreater(checked, 100)

    def test_literal_runtime_scene_resource_references_exist(self) -> None:
        # Dynamic ship/object factories are covered above and by manifest tests.
        sources = dict(self.runtime)
        sources.update({path.relative_to(CODE).as_posix(): path.read_text(encoding="utf-8") for path in (CODE / "assets").rglob("*.tscn")})
        for source, text in sources.items():
            for reference in re.findall(r'"(res://[^"\n]+\.(?:gd|tscn|gdshader|png|svg|glb|otf|wav))"', text):
                with self.subTest(source=source, reference=reference):
                    self.assertTrue((CODE / reference.removeprefix("res://")).is_file())

    def test_all_runtime_modules_reachable_from_main(self) -> None:
        # GDScript references include both explicit preloads and globally
        # registered class_name types. This is a dependency lint, not evidence
        # that every function executes during a particular playthrough.
        classes: dict[str, str] = {}
        for path, source in self.runtime.items():
            declaration = re.search(r"(?m)^class_name (\w+)", source)
            if declaration:
                classes[declaration[1]] = path
        graph: dict[str, set[str]] = {}
        for path, source in self.runtime.items():
            dependencies = set(re.findall(r'"res://([^"\n]+\.gd)"', source))
            dependencies |= {target for name, target in classes.items()
                             if re.search(r"\b" + re.escape(name) + r"\b", source)}
            graph[path] = dependencies & self.runtime.keys()
        reached = {"runtime/main.gd"}
        pending = list(reached)
        while pending:
            for dependency in graph[pending.pop()] - reached:
                reached.add(dependency)
                pending.append(dependency)
        self.assertEqual(self.runtime.keys() - reached, set())

    def test_every_implemented_business_action_has_player_entrypoint(self) -> None:
        act = function(self.runtime["runtime/gameplay.gd"], "act")
        actions = set(re.findall(r'(?m)^\s*"([a-z_]+)":', act))
        # Host input/interaction/GUI are independent producers. Exclude the
        # Gameplay definitions themselves so dispatch names cannot prove reachability.
        producers = "\n".join(self.runtime[name] for name in self.runtime
                              if name.startswith("runtime/ui") or name in ("runtime/main.gd", "runtime/interaction_context.gd"))
        self.assertEqual(actions - strings(producers), set())

    def test_every_static_gui_action_resolves_to_host_or_gameplay(self) -> None:
        host = function(self.runtime["runtime/main.gd"], "_command")
        act = function(self.runtime["runtime/gameplay.gd"], "act")
        handlers: set[str] = set()
        for source in (host, act):
            for branch in re.findall(r'(?m)^\s*("[a-z_]+"(?:,\s*"[a-z_]+")*):', source):
                handlers |= strings(branch)
        ui = self.runtime["runtime/ui.gd"]
        direct = set(re.findall(r'requested\.emit\("([a-z_]+)"', ui))
        direct |= set(re.findall(r'_command\([^\n]*?,\s*"([a-z_]+)"(?:,|\))', ui))
        self.assertEqual(direct - handlers, set())


if __name__ == "__main__":
    unittest.main(verbosity=2)
