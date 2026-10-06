#!/usr/bin/env python3
"""Rebuild the fixed v1 local-navigation SQLite extension; never touch player saves."""
import hashlib
import json
from pathlib import Path
import sqlite3
import argparse

ROOT = Path(__file__).resolve().parents[1]
CODE = ROOT / 'code'
SQL = CODE / 'database/local_navigation_v1.sql'
DB = CODE / 'data/local_navigation_v1.db'
MANIFEST = CODE / 'data/local_navigation_v1_manifest.json'
SQLITE_APPLICATION_ID = 1481526350
PARAMETERS = {
    'warmup_s', 'alignment_tolerance_rad', 'warp_speed_mps', 'min_warp_distance_m',
    'approach_speed_fraction', 'orbit_speed_fraction', 'steering_response_s',
    'orbit_radial_response_s', 'arrival_tolerance_m', 'arrival_speed_mps',
    'collision_margin_m',
}


def build(version: int = 1) -> None:
    global SQL, DB, MANIFEST
    SQL = CODE / f'database/local_navigation_v{version}.sql'
    DB = CODE / f'data/local_navigation_v{version}.db'
    MANIFEST = CODE / f'data/local_navigation_v{version}_manifest.json'
    DB.parent.mkdir(parents=True, exist_ok=True)
    temporary = ROOT / f'jiaoben/tmp/local_navigation_v{version}.build.db'
    temporary.unlink(missing_ok=True)
    with sqlite3.connect(temporary) as db:
        db.executescript(SQL.read_text(encoding='utf-8'))
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert db.execute('PRAGMA application_id').fetchone()[0] == SQLITE_APPLICATION_ID
        assert db.execute('PRAGMA user_version').fetchone()[0] == version
        assert db.execute('SELECT rule_version FROM local_navigation_meta').fetchall() == [(f'local-navigation-v{version}',)]
        parameters = dict(db.execute('SELECT parameter_id,value_real FROM navigation_parameters'))
        required = PARAMETERS | {'min_warp_travel_s'} if version == 2 else PARAMETERS
        actual = {key for key in parameters if not key.startswith('warp_fx_')}
        assert actual == required and all(value > 0 for value in parameters.values())
        if version == 2:
            assert parameters['min_warp_distance_m'] == 150000
            assert parameters['warp_speed_mps'] == 149597870700 * 0.18
            assert parameters['min_warp_travel_s'] >= 3
        assert parameters['approach_speed_fraction'] <= 1 and parameters['orbit_speed_fraction'] <= 1
        types = {row[0] for row in db.execute('SELECT target_kind FROM navigation_target_rules')}
        assert types == {'station', 'gate', 'resource', 'signal', 'marker', 'npc', 'wreck'}
        with sqlite3.connect(f'file:{CODE / "data/catalog.db"}?mode=ro', uri=True) as core:
            dock_radius = core.execute("SELECT value_real FROM rule_parameters WHERE parameter_id='dock_radius_m'").fetchone()[0]
        station_arrival = db.execute("SELECT approach_arrival_m FROM navigation_target_rules WHERE target_kind='station'").fetchone()[0]
        assert station_arrival < dock_radius
        assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    DB.write_bytes(temporary.read_bytes())
    manifest = {
        'asset_version': f'local-navigation-v{version}',
        'scope': 'Independent gameplay navigation extension, fixed rule version v1; existing frozen core definitions and sealed ship state remain authoritative and unchanged.',
        'resources': [{'path': f'res://data/local_navigation_v{version}.db',
                       'sha256': hashlib.sha256(DB.read_bytes()).hexdigest(),
                       'role': 'readonly_local_gameplay_navigation_rules',
                       'source': f'Project authored SQL; code/database/local_navigation_v{version}.sql'}],
    }
    if version == 2:
        for relative in ('runtime/ui/warp_visual.gd', 'runtime/ui/warp_environment.gdshader',
                         'runtime/ui/window_space_strategic.gdshader', 'runtime/station_hangar.gd'):
            manifest['resources'].append({'path': 'res://' + relative,
                'sha256': hashlib.sha256((CODE / relative).read_bytes()).hexdigest(),
                'role': 'readonly_warp_presentation', 'source': 'Project authored code and shader'})
        manifest['scope'] = 'Fixed v2 strategic navigation; selected by frozen v0.7 world rules. v1 preserved for historical worlds.'
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'local-navigation-v{version}: SQLite rules and one-resource manifest built and checked')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--version', type=int, choices=(1, 2), default=1)
    build(parser.parse_args().version)
