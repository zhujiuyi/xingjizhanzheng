"""Verify/copy the checked-in historical B test catalog; never uses user saves."""
from pathlib import Path
import shutil
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / "jiaoben/tests/store_fixtures/catalog-b-baseline.db"
with sqlite3.connect(source.as_uri() + "?mode=ro", uri=True) as connection:
    assert connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    assert not connection.execute("PRAGMA foreign_key_check").fetchall()
    assert connection.execute("SELECT content_hash FROM catalog_meta").fetchone()[0] == "a91984499698ef653026bbfeef36ba22b752d457dd3d880f11098f85ebc2b617"
output = ROOT / "jiaoben/tmp/catalog-b-baseline.db"
shutil.copyfile(source, output)
print("Verified B test catalog:", output)
