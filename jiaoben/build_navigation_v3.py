#!/usr/bin/env python3
"""Build independently versioned, read-only navigation definitions and provenance."""
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
CODE = ROOT / 'code'
DB = CODE / 'data/navigation_v3.db'
SQL = CODE / 'database/navigation_v3.sql'
if DB.exists(): DB.unlink()  # Generated presentation catalog; never a progress database.
with sqlite3.connect(DB) as conn:
    conn.executescript(SQL.read_text(encoding='utf-8'))
    assert conn.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    assert conn.execute('SELECT COUNT(*) FROM celestial_visual_defs').fetchone()[0] == 10
    with sqlite3.connect(f'file:{CODE / "data/catalog.db"}?mode=ro', uri=True) as core:
        sectors = {row[0] for row in core.execute('SELECT sector_id FROM sector_defs')}
    assert {row[0] for row in conn.execute('SELECT sector_id FROM celestial_visual_defs')} == sectors
resources = []
for relative, role in [('data/navigation_v3.db', 'readonly_navigation_definitions'), ('assets/navigation_v3/planet.gdshader', 'original_planet_surface_shader'), ('assets/navigation_v3/planet_surface.png', 'original_generated_planet_albedo'), ('assets/navigation_v3/space_panorama.png', 'original_generated_space_panorama')]:
    resources.append({'path': 'res://' + relative, 'sha256': hashlib.sha256((CODE / relative).read_bytes()).hexdigest(), 'role': role,
                      'source': 'Original project image, built-in image_gen, no image references; sources.json' if relative.endswith('.png') else 'project authored; no third party art'})
manifest = {'asset_version': 'navigation-v3', 'scope': 'presentation only; scenic planets are nonphysical navigation bearings; local contact visibility remains core SQLite rules', 'resources': resources}
(CODE / 'assets/navigation_v3/manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('navigation-v3: ten scenic celestial definitions, three radar scales, four runtime resources')
