#!/usr/bin/env python3
"""Reproducible desktop export. Temporary builds/logs stay in jiaoben."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CODE = ROOT / 'code'

def run(command: list[str], log: Path, env: dict[str, str] | None = None,
        timeout: int | None = None) -> str:
    with log.open('w') as output:
        result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                                env=env, timeout=timeout)
    text = log.read_text(errors='replace')
    if result.returncode or re.search(r'^(SCRIPT ERROR|ERROR):', text, re.M):
        raise RuntimeError(f'Command failed; inspect {log}')
    return text

def sha(path: Path) -> str:
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()

def verify_exported_encounters(executable: Path, build_id: str, logs: Path) -> dict:
    # The explicit release entry loads the external acceptance Node while
    # res:// stays in the executable's exported PCK, never the source project.
    script = (ROOT / 'jiaoben/tests/encounter_mission_v12.gd').resolve()
    test_folder = (ROOT / 'jiaoben/tmp/release-encounters' / str(uuid.uuid4())).resolve()
    test_folder.mkdir(parents=True)
    stdout_log = (logs / f'{build_id}-mac-encounter-mission.log').resolve()
    engine_log = (logs / f'{build_id}-mac-encounter-mission-engine.log').resolve()
    environment = os.environ.copy()
    environment.pop('XJ_TEST_DATABASE', None)
    environment.pop('XJ_ENCOUNTER_V12_LEGACY', None)
    environment['XJ_ENCOUNTER_V12_SCRIPT'] = str(script)
    environment['XJ_ENCOUNTER_V12_OUTPUT'] = str(test_folder)
    command = [str(executable.resolve()), '--audio-driver', 'CoreAudio',
               '--log-file', str(engine_log), '--', '--xj-verify-encounters']
    text = run(command, stdout_log, environment, timeout=420)
    if not engine_log.is_file():
        raise RuntimeError(f'Actual exported encounter engine log is absent: {engine_log}')
    diagnostic = re.compile(r'^(?:\s*(?:SCRIPT ERROR|ERROR|WARNING):|.*[Ll]eak(?:ed|ing)?\b|.*Resource still in use)', re.M)
    for label, content in (('stdout', text), ('engine', engine_log.read_text(errors='replace'))):
        if diagnostic.search(content):
            raise RuntimeError(f'Actual exported encounter {label} has diagnostics; inspect {stdout_log} and {engine_log}')
    results = re.findall(r'^ENCOUNTER_MISSION_V12_FINAL_JSON (.+)$', text, re.M)
    if len(results) != 1:
        raise RuntimeError(f'Actual exported encounter final JSON is absent or repeated: {stdout_log}')
    try:
        result = json.loads(results[0])
    except json.JSONDecodeError as error:
        raise RuntimeError(f'Actual exported encounter final JSON is invalid: {stdout_log}') from error
    if (not isinstance(result, dict) or result.get('result') != 'PASS'
            or type(result.get('checks')) is not int or result['checks'] <= 0
            or type(result.get('failures')) is not int or result['failures'] != 0
            or result.get('failure_labels') != []
            or type(result.get('captures')) is not int or result['captures'] <= 0
            or not isinstance(result.get('directory'), str)
            or Path(result['directory']).resolve() != test_folder):
        raise RuntimeError(f'Actual exported encounter acceptance did not pass completely: {stdout_log}')
    marker = re.search(r'^ENCOUNTER_MISSION_V12_RESULT PASS checks=(\d+) failures=0 captures=(\d+)$', text, re.M)
    if not marker or (int(marker[1]), int(marker[2])) != (result['checks'], result['captures']):
        raise RuntimeError(f'Actual exported encounter PASS marker disagrees with final JSON: {stdout_log}')
    captures = []
    for capture in sorted(test_folder.glob('*.png')):
        if not capture.is_file() or capture.resolve().parent != test_folder or capture.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
            raise RuntimeError(f'Actual exported encounter capture is invalid: {capture}')
        captures.append({'name': capture.stem, 'path': str(capture), 'sha256': sha(capture)})
    if len(captures) != result['captures']:
        raise RuntimeError(f'Actual exported encounter capture count disagrees with final JSON: {test_folder}')
    return {'result': 'PASS', 'checks': result['checks'], 'failures': 0, 'failure_labels': [],
            'scope': 'explicit release entry loads an external acceptance Node against the actual exported Mac PCK: task navigation, mainline entry, encounter groups, salvage and one-time SQLite rewards; isolated fresh world, no legacy archive requested',
            'executable': str(executable.resolve()), 'acceptance_script': str(script),
            'entry_point': '--xj-verify-encounters',
            'acceptance_script_sha256': sha(script), 'audio_driver': 'CoreAudio',
            'legacy_archive_requested': False,
            'stdout_log': str(stdout_log), 'stdout_log_sha256': sha(stdout_log),
            'engine_log': str(engine_log), 'engine_log_sha256': sha(engine_log),
            'engine_diagnostics': 0, 'capture_folder': str(test_folder),
            'capture_count': len(captures), 'captures': captures}

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['all', 'mac', 'windows'], default='all')
    parser.add_argument('--publish', action='store_true', help='copy checked packages into ignored code/dist/<build-id>')
    args = parser.parse_args()
    source_revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())
    version = re.search(r'^config/version="([^"]+)"$', (CODE / 'project.godot').read_text(), re.M)
    if version is None: raise RuntimeError('Client version is absent')
    build_id = version[1] + '-' + source_revision[:8] + '-' + time.strftime('%Y%m%d-%H%M%S')
    staging = ROOT / 'jiaoben/tmp/delivery' / build_id
    staging.mkdir(parents=True)
    logs = ROOT / 'jiaoben/logs'
    logs.mkdir(exist_ok=True)
    manifest = json.loads((CODE / 'assets/manifest.json').read_text())
    raw_paths: dict[str, str] = {}
    presentation_packs = []
    for manifest_path in (CODE / 'assets/manifest.json', CODE / 'assets/placeholders/manifest.json',
                          CODE / 'assets/interface_v2/manifest.json', CODE / 'assets/hangar_v2/manifest.json',
                          CODE / 'assets/interface_v3/manifest.json', CODE / 'assets/navigation_v3/manifest.json',
                          CODE / 'assets/ship_v3/manifest.json', CODE / 'assets/station_v3/manifest.json',
                          CODE / 'data/local_navigation_v1_manifest.json', CODE / 'assets/business_v11/manifest.json'):
        pack = json.loads(manifest_path.read_text())
        for resource in pack['resources']:
            resource_path = resource.get('resource_path', resource.get('path', ''))
            if not resource_path.startswith('res://') or '..' in Path(resource_path[6:]).parts:
                raise RuntimeError(f'Invalid runtime resource: {resource_path}')
            path = CODE / resource_path[6:]
            if sha(path) != resource['sha256']:
                raise RuntimeError(f'Formal asset hash differs: {path}')
            if resource_path in raw_paths and raw_paths[resource_path] != resource['sha256']:
                raise RuntimeError(f'Conflicting pack identity: {resource_path}')
            raw_paths[resource_path] = resource['sha256']
        if manifest_path.parent.name not in ('assets', 'placeholders'):
            presentation_packs.append({'asset_version': pack['asset_version'],
                                       'manifest_path': str(manifest_path.relative_to(CODE)),
                                       'manifest_sha256': sha(manifest_path), 'resource_count': len(pack['resources'])})
    with sqlite3.connect(f'file:{CODE / "data/catalog.db"}?mode=ro', uri=True) as catalog:
        catalog.row_factory = sqlite3.Row
        if catalog.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise RuntimeError('Content database integrity failed')
        content = dict(catalog.execute('SELECT * FROM catalog_meta').fetchone())
    evidence = {'build_id': build_id, 'source_revision': source_revision, 'source_dirty': dirty,
                'content': content, 'asset_version': manifest['asset_version'],
                'asset_manifest_sha256': manifest['manifest_sha256'], 'presentation_packs': presentation_packs,
                'raw_resource_count': len(raw_paths), 'verification': {}, 'archives': {}}
    for platform in (['mac', 'windows'] if args.platform == 'all' else [args.platform]):
        folder = staging / platform
        folder.mkdir()
        output = folder / ('星际战舰.app' if platform == 'mac' else 'XingjiZhanjian.exe')
        text = run(['sh', 'jiaoben/run_godot.sh', '--headless', '--editor', '--path', 'code',
                    '--export-release', 'macOS' if platform == 'mac' else 'Windows', str(output)],
                   logs / f'{build_id}-{platform}-export.log')
        if not re.search(rf'^XJ_RAW_ASSET_EXPORT sources={len(raw_paths)}$', text, re.M):
            raise RuntimeError('Expected formal raw asset export evidence is absent')
        licenses = folder / '第三方许可'
        licenses.mkdir()
        for source in (CODE / 'third_party').glob('GODOT_*'):
            shutil.copy2(source, licenses / source.name)
        shutil.copy2(CODE / 'addons/godot-sqlite/LICENSE.md', licenses / 'godot-sqlite-LICENSE.md')
        for source, label in [('LICENSE-OFL.txt', 'NotoSansCJKsc-OFL.txt'), ('FONT_COPYRIGHT.txt', 'NotoSansCJKsc-COPYRIGHT.txt')]:
            shutil.copy2(CODE / 'assets/interface_v3' / source, licenses / label)
        (licenses / 'SQLite.txt').write_text('SQLite is in the public domain. https://sqlite.org/copyright.html\n')
        manual = ROOT / 'doc/28-客户端使用与交付说明.md'
        if manual.exists(): shutil.copy2(manual, folder / '使用说明.md')
        if platform == 'mac':
            run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(output)],
                logs / f'{build_id}-mac-signature.log')
            test_folder = ROOT / 'jiaoben/tmp/release-health' / str(uuid.uuid4())
            test_folder.mkdir(parents=True)
            env = os.environ.copy()
            env['XJ_TEST_DATABASE'] = str(test_folder / 'progress.db')
            text = run([str(output / 'Contents/MacOS/星际战舰'), '--headless',
                        '--log-file', str(logs / f'{build_id}-mac-database-engine.log'), '--', '--xj-verify-store'],
                       logs / f'{build_id}-mac-database.log', env)
            if not re.search(r'STORE_RELEASE_RESULT PASS checks=6 failures=0', text):
                raise RuntimeError('Exported app database diagnostic did not pass')
            if 'PRESENTATION_RELEASE_RESULT PASS' not in text:
                raise RuntimeError('Exported presentation package diagnostic did not pass')
            visual_folder = ROOT / 'jiaoben/tmp/release-presentation' / str(uuid.uuid4())
            visual_folder.mkdir(parents=True)
            env['XJ_TEST_DATABASE'] = str(visual_folder / 'progress.db')
            text = run([str(output / 'Contents/MacOS/星际战舰'), '--audio-driver', 'CoreAudio',
                        '--log-file', str(logs / f'{build_id}-mac-presentation-engine.log'),
                        '--', '--xj-verify-presentation'], logs / f'{build_id}-mac-presentation.log', env)
            if not re.search(r'PRESENTATION_CLIENT_RESULT PASS checks=90 failures=0', text):
                raise RuntimeError('Actual exported presentation lifecycle did not pass')
            if re.search(r'^(WARNING:|.*Leaked instance:|.*Resource still in use)', text, re.M):
                raise RuntimeError('Actual exported presentation exited with diagnostics')
            capture_names = ('title', 'map', 'archive', 'station', 'npc', 'flight', 'approach', 'warp', 'arrival', 'resources', 'save-wait', 'attitude-level', 'business-goods', 'business-hulls')
            captures = []
            for name in capture_names:
                capture = visual_folder / f'release-{name}.png'
                if not capture.is_file() or capture.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
                    raise RuntimeError(f'Actual release capture is absent or invalid: {name}')
                captures.append({'name': name, 'sha256': sha(capture)})
            evidence['verification']['mac_presentation'] = {
                'result': 'actual release Metal/CoreAudio Chinese font, archive cards, radar, celestial bearing, selected line, station F qualification, hangar/NPC, lifecycle, departure, cockpit visibility recovery without flight mutation and SQLite save, graphical star chart with frozen spatial topology, directed door connections, search/risk selection, one selected-sector detail panel, exact mineral node readouts, clipped zoom/center/full-map views and unchanged runtime/SQLite snapshots, actual equipment, local warp source commit/exterior arrival/physical selection/validated docking, interpolated render poses, visible pointer, disabled right mouse and left-drag/release preserving accepted warp, canonical resource_state qualification, distant reserve intelligence, actual finite last-unit mining and inventory output, mineral countdown and paused clock, top flight tools, full-height overview, side-by-side ship and equipment row, one compact real deferred-save notice and cancellation preserving its paid mining cycle, bounded ship leveling, explicit roll, upright recovery view and finite vertical headings, shared business lists with item/hull portraits and final operation column, authoritative taxed unit/total quotes and stock, same-row quantity updates, disabled purchasing with readable prices, all station business pages and station restoration without economic or physical mutation PASS',
                'capture_folder': str(visual_folder), 'checks': 90, 'captures': captures}
            evidence['verification']['mac'] = 'actual exported app: resource hashes/new/save/reopen/resume PASS; ad-hoc signature PASS'
            evidence['verification']['mac_encounter_mission'] = verify_exported_encounters(
                output / 'Contents/MacOS/星际战舰', build_id, logs)
            archive = staging / '星际战舰-macOS.zip'
            run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(folder), str(archive)],
                logs / f'{build_id}-mac-archive.log')
        else:
            if not list(folder.glob('*.pck')) or not list(folder.glob('*.dll')):
                raise RuntimeError('Windows runtime PCK or SQLite DLL absent')
            if output.read_bytes()[:2] != b'MZ': raise RuntimeError('Windows PE header absent')
            evidence['verification']['windows'] = 'x64 release export and runtime components PASS; native Windows execution not available on this Mac'
            archive = staging / '星际战舰-Windows-x64.zip'
            with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
                for source in sorted(folder.rglob('*')):
                    if source.is_file(): bundle.write(source, source.relative_to(staging))
        evidence['archives'][archive.name] = sha(archive)
        print(platform, 'export checked:', output)
    (staging / 'build-manifest.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
    (staging / 'SHA256SUMS.txt').write_text(''.join(f'{digest}  {name}\n' for name,digest in evidence['archives'].items()))
    if args.publish:
        destination = CODE / 'dist' / build_id
        if destination.exists(): raise RuntimeError(f'Refusing to overwrite {destination}')
        shutil.copytree(staging, destination)
        print('Deliverables:', destination)
    else: print('Checked staging:', staging)

if __name__ == '__main__':
    main()
