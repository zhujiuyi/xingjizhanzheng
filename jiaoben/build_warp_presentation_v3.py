"""Build presentation-only warp SQLite and exact raw-resource manifest."""
from pathlib import Path
import hashlib
import json
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
CODE = ROOT / 'code'


def build():
    temporary = ROOT / 'jiaoben/tmp/warp-presentation-v3.build.db'
    temporary.unlink(missing_ok=True)
    with sqlite3.connect(temporary) as db:
        db.executescript((CODE / 'database/warp_presentation_v3.sql').read_text(encoding='utf-8'))
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert db.execute('PRAGMA foreign_key_check').fetchall() == []
        assert db.execute('PRAGMA user_version').fetchone()[0] == 3
        params = dict(db.execute('SELECT * FROM warp_visual_parameters'))
        assert len(params) == 21 and all(value >= 0 for value in params.values())
        assert params['warp_fx_center_clear_ratio'] == 0
    (CODE / 'data/warp_presentation_v3.db').write_bytes(temporary.read_bytes())
    resources = []
    for relative in ('data/local_navigation_v2.db', 'data/warp_presentation_v3.db',
                     'runtime/warp_presentation_rules.gd', 'runtime/ui/warp_visual.gd',
                     'runtime/ui/warp_environment.gdshader', 'runtime/ui/window_space_strategic.gdshader',
                     'runtime/station_hangar.gd'):
        resources.append({'path': 'res://' + relative,
            'sha256': hashlib.sha256((CODE / relative).read_bytes()).hexdigest(),
            'role': 'immutable_gameplay_navigation' if relative == 'data/local_navigation_v2.db' else 'readonly_warp_and_celestial_presentation',
            'source': 'Project authored SQL and renderer'})
    manifest = {'asset_version': 'warp-presentation-v3',
        'scope': 'Presentation-only fixes; previously published navigation databases and frozen worlds unchanged.',
        'resources': resources}
    (CODE / 'data/warp_presentation_v3_manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('warp-presentation-v3: SQLite and manifest PASS')


if __name__ == '__main__':
    build()
