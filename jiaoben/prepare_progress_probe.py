"""Prepare a disposable copy of formal progress SQL and a generated SQL fixture.

Run prepare_godot_probe.py first. This never touches a real player database.
"""
from pathlib import Path
import shutil
import sqlite3
import uuid
import progress_fixture as fixture

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "jiaoben/tmp/godot-sqlite-probe"
if not (DEST / "project.godot").exists():
    raise SystemExit("Run jiaoben/prepare_godot_probe.py first")
sql_dir = DEST / "progress_sql"
sql_dir.mkdir(exist_ok=True)
for name in fixture.MIGRATIONS:
    shutil.copy2(fixture.PROGRESS_DIR / name, sql_dir / name)
shutil.copy2(ROOT / "jiaoben/probes/godot_sqlite/progress_probe.gd", DEST / "progress_probe.gd")
temporary = DEST / "data" / ("progress-fixture-" + uuid.uuid4().hex + ".db")
source = sqlite3.connect((ROOT / "code/data/catalog.db").as_uri() + "?mode=ro", uri=True)
database = fixture.connect(temporary)
try:
    fixture.apply_migrations(database)
    fixture.new_world(database, source)
finally:
    source.close()
    database.close()
temporary.replace(DEST / "data/progress-fixture.db")
print("Prepared native progress probe; temporary state only:", DEST)
