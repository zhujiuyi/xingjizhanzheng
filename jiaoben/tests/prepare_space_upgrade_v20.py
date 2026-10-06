#!/usr/bin/env python3
"""Prepare one exact released catalog fixture; never writes player archives."""
from pathlib import Path
import hashlib
import sqlite3
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "jiaoben/tmp/audit-catalog-v0141.db"
SHA256 = "b0f212d5afb09279d6d2e906cbf0a4f675c252f682a10a0a5a39270d035067d8"


def prepare_catalog_fixture() -> Path:
    data = FIXTURE.read_bytes() if FIXTURE.exists() else subprocess.run(
        ["git", "show", "b54c3176:code/data/catalog.db"], cwd=ROOT,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    ).stdout
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError("Historical space-upgrade fixture differs; preserve it and inspect")
    if not FIXTURE.exists():
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_bytes(data)
    connection = sqlite3.connect(FIXTURE.as_uri() + "?mode=ro", uri=True)
    try:
        assert connection.execute("PRAGMA integrity_check").fetchall() == [("ok",)]
        assert connection.execute("SELECT schema_version,content_version FROM catalog_meta").fetchone() == (5, "v0.6-combat")
    finally:
        connection.close()
    return FIXTURE


if __name__ == "__main__":
    print(f"SPACE_UPGRADE_V20_CATALOG {prepare_catalog_fixture()} sha256={SHA256}")
