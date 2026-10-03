"""Read-only SQL/DTO/asset structure checks. No gameplay or save runtime claim."""
from pathlib import Path
from contextlib import closing
import hashlib
import json
import re
import sqlite3
import unittest

ROOT = Path(__file__).resolve().parents[2]


def split_sql_columns(body):
    parts, start, depth, quoted = [], 0, 0, False
    for index, char in enumerate(body):
        if char == "'":
            quoted = not quoted
        if not quoted:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            elif char == "," and depth == 0:
                parts.append(body[start:index])
                start = index + 1
    parts.append(body[start:])
    return parts


class ContractAssetTests(unittest.TestCase):
    def test_every_progress_state_column_and_array_has_dto(self):
        # Inspect the actual migrated schema, including ALTER TABLE additions;
        # parsing just 001 silently misses registered state introduced later.
        db = sqlite3.connect(":memory:")
        self.addCleanup(db.close)
        for path in sorted((ROOT / "code/database/progress").glob("[0-9][0-9][0-9]_*.sql")):
            db.executescript(path.read_text())
        gd = (ROOT / "code/contracts/contract_dtos.gd").read_text()
        state_gd = (ROOT / "code/runtime/state.gd").read_text()
        registry = re.search(r"const TABLES: Array\[String\] = \[(.*?)\]", state_gd, re.S)
        self.assertIsNotNone(registry)
        registered = set(re.findall(r'"(\w+_state)"', registry[1]))
        classes = dict(re.findall(r"class (\w+) extends RefCounted:\n(.*?)(?=\nclass |\n##|\Z)", gd, re.S))
        common = {"snapshot_id", "world_id", "content_snapshot_id"}
        tables = {name for name, in db.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name LIKE '%_state'")}
        self.assertEqual(tables, registered)
        for table in tables:
            classname = "".join(word.capitalize() for word in table.split("_")) + "Dto"
            self.assertIn(classname, classes, table)
            fields = set(re.findall(r"var (\w+):", classes[classname]))
            for _, column, _, not_null, _, primary_key in db.execute(f'PRAGMA table_info("{table}")'):
                if column in common:
                    continue
                self.assertIn(column, fields, f"{table}.{column}")
                if not not_null and not primary_key:
                    self.assertIn("has_" + column, fields, f"nullable {table}.{column}")
            self.assertIn(f"var {table}_rows: Array[{classname}]", gd, table)

    def test_manifest_hashes_and_all_catalog_mounts(self):
        directory = ROOT / "code/assets/placeholders"
        manifest = json.loads((directory / "manifest.json").read_text())
        expected_hash = manifest.pop("manifest_sha256")
        raw = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), expected_hash)
        with closing(sqlite3.connect(f"file:{ROOT / 'code/data/catalog.db'}?mode=ro", uri=True)) as db:
            for entry in manifest["resources"]:
                path = ROOT / "code" / entry["resource_path"].removeprefix("res://")
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), entry["sha256"])
                scene = path.read_text()
                actual = set(re.findall(r'\[node name="(\w+)" type="Marker3D" parent="Hardpoints"\]', scene))
                expected = {f"{slot}_{index}" for slot, index in db.execute(
                    "SELECT slot_type,slot_index FROM ship_slot_defs WHERE ship_id=?", (entry["ship_def_id"],))}
                self.assertEqual(actual, expected, entry["ship_def_id"])

    def test_contract_has_no_runtime_or_balance_source(self):
        for path in (ROOT / "code/contracts").glob("*.gd"):
            source = path.read_text()
            self.assertNotRegex(source, r"(?m)^\s*func\s+(_process|_physics_process|_ready)\b")
            self.assertNotRegex(source, r"(?m)^\s*var\s+\w+\s*:\s*(Node|Resource|RID|Callable)\b")
            self.assertNotIn("SQLite.new", source)


if __name__ == "__main__":
    unittest.main()
