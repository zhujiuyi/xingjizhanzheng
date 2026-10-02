#!/usr/bin/env python3
"""Developer-only generator for reviewed, fixed frozen DDL; never run from saved SQL.

Reads the validated development catalog and emits normalized tables with a
content_snapshot_id prefix on every PK/UNIQUE/FK. Output is reviewed and shipped
as migration SQL. Runtime only binds values into that fixed DDL.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "jiaoben"))
import build_catalog as catalog_builder

PROGRESS_DIR = ROOT / "code/database/progress"
OUTPUT = PROGRESS_DIR / "002_frozen_catalog.sql"


def split_clauses(body: str) -> list[str]:
    clauses, start, depth, quoted = [], 0, 0, False
    for index, character in enumerate(body):
        if character == "'":
            quoted = not quoted
        elif not quoted:
            depth += (character == "(") - (character == ")")
            if character == "," and depth == 0:
                clauses.append(body[start:index].strip())
                start = index + 1
    clauses.append(body[start:].strip())
    if depth or quoted:
        raise ValueError("Unbalanced catalog DDL")
    return clauses


def frozen_table_sql(connection: sqlite3.Connection, table: str) -> str:
    ddl = connection.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?", (table,)).fetchone()[0]
    match = re.fullmatch(r"CREATE TABLE\s+\w+\s*\((.*)\)\s*STRICT", ddl, re.S | re.I)
    if not match:
        raise ValueError(f"Unreviewed CREATE TABLE form: {table}")
    info = connection.execute(f'PRAGMA table_info("{table}")').fetchall()
    pk = [r[1] for r in sorted(info, key=lambda r: r[5]) if r[5]]
    result = ["content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE"]
    extra = []
    for clause in split_clauses(match[1]):
        if re.match(r"PRIMARY KEY\s*\(", clause, re.I):
            continue
        if re.match(r"UNIQUE\s*\(", clause, re.I):
            result.append(re.sub(r"UNIQUE\s*\(", "UNIQUE (content_snapshot_id, ", clause, count=1, flags=re.I))
            continue
        if re.match(r"FOREIGN KEY\s*\(", clause, re.I):
            clause = re.sub(r"FOREIGN KEY\s*\(", "FOREIGN KEY (content_snapshot_id, ", clause, count=1, flags=re.I)
            clause = re.sub(r"REFERENCES\s+(\w+)\s*\(", r"REFERENCES frozen_\1 (content_snapshot_id, ", clause, flags=re.I)
            result.append(clause)
            continue
        if clause.upper().startswith("CHECK"):
            result.append(clause)
            continue
        column = clause.split()[0]
        inline_fk = re.search(r"\s+REFERENCES\s+(\w+)\s*\((\w+)\)", clause, re.I)
        if inline_fk:
            extra.append(f"FOREIGN KEY (content_snapshot_id, {column}) REFERENCES frozen_{inline_fk[1]} (content_snapshot_id, {inline_fk[2]})")
            clause = clause[:inline_fk.start()] + clause[inline_fk.end():]
        clause = re.sub(r"\s+PRIMARY KEY\b", "", clause, flags=re.I)
        if re.search(r"\s+UNIQUE\b", clause, re.I):
            clause = re.sub(r"\s+UNIQUE\b", "", clause, flags=re.I)
            extra.append(f"UNIQUE (content_snapshot_id, {column})")
        if column in pk and "NOT NULL" not in clause.upper():
            clause = re.sub(r"^(\w+\s+\w+)", r"\1 NOT NULL", clause)
        result.append(clause)
    result += ["PRIMARY KEY (content_snapshot_id, " + ", ".join(pk) + ")"] + extra
    output = f"CREATE TABLE frozen_{table} (\n    " + ",\n    ".join(result) + "\n) STRICT;\n"
    for action, when in (("INSERT", "NEW"), ("UPDATE", "OLD"), ("DELETE", "OLD")):
        guard = f"EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id={when}.content_snapshot_id AND status='sealed')"
        if action == "UPDATE":
            guard += " OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')"
        output += f"""CREATE TRIGGER frozen_{table}_{action.lower()}_guard BEFORE {action} ON frozen_{table}
WHEN {guard}
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;\n"""
    return output


def generate(output: Path = OUTPUT) -> dict[str, object]:
    source = ROOT / "code/data/catalog.db"
    connection = sqlite3.connect(source.as_uri() + "?mode=ro", uri=True)
    try:
        connection.execute("PRAGMA foreign_keys=ON")
        catalog_builder.validate_database(connection)
        logical_hash = catalog_builder.logical_content_hash(connection)
        stored = connection.execute("SELECT content_hash FROM catalog_meta").fetchone()[0]
        if stored != logical_hash:
            raise ValueError("Source catalog content hash mismatch")
        pieces = ["-- Generated from reviewed catalog DDL, not from save-provided SQL.\n",
                  "-- Regenerate, review and commit together with catalog schema changes.\n",
                  "-- Numeric-only seed updates do not change this fixed migration.\n"]
        for table in sorted(catalog_builder.CONTENT_TABLES):
            pieces.append(frozen_table_sql(connection, table))
        text = "\n".join(pieces)
        output.write_text(text, encoding="utf-8")
        if output == OUTPUT:
            # Fixed version adapter preserves schema/view semantics for this format.
            adapter = PROGRESS_DIR / "catalog_adapter_v0_3.sql"
            adapter_parts = ["-- Fixed reviewed verification adapter; never execute DDL from progress rows.\nPRAGMA foreign_keys=ON;"]
            adapter_parts += [connection.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name=?", (table,)).fetchone()[0] + ";"
                              for table in sorted(catalog_builder.CONTENT_TABLES)]
            adapter_parts += [sql + ";" for sql in catalog_builder.content_views(connection).values()]
            adapter.write_text("\n\n".join(adapter_parts) + "\n", encoding="utf-8")
            core = (PROGRESS_DIR / "001_core.sql").read_text(encoding="utf-8")
            names = re.findall(r"CREATE TABLE (\w+_state)\s*\(", core)
            guards = ["-- Generated, reviewed guards for every snapshot state table.\n"]
            for table in names:
                for action, row in (("INSERT", "NEW"), ("UPDATE", "OLD"), ("DELETE", "OLD")):
                    condition = f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={row}.snapshot_id AND status='sealed')"
                    if action == "UPDATE":
                        condition += " OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
                    guards.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table}\nWHEN {condition}\nBEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;\n")
            for table in ("content_table_manifest", "content_view_manifest"):
                for action, row in (("INSERT", "NEW"), ("UPDATE", "OLD"), ("DELETE", "OLD")):
                    condition = f"EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id={row}.content_snapshot_id AND status='sealed')"
                    if action == "UPDATE":
                        condition += " OR EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')"
                    guards.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table}\nWHEN {condition}\nBEGIN SELECT RAISE(ABORT,'sealed manifest is immutable'); END;\n")
            (PROGRESS_DIR / "004_immutability.sql").write_text("\n".join(guards), encoding="utf-8")
        return {"tables": len(catalog_builder.CONTENT_TABLES), "source_hash": logical_hash,
                "ddl_hash": hashlib.sha256(text.encode()).hexdigest()}
    finally:
        connection.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    print(generate(parser.parse_args().output))
