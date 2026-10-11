"""Build the three original fire-control marks; assets contain no balance data."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'code/assets/fitting_v1'
MARKS = {
    'burst': '<path d="M34 8 18 34h13l-3 22 18-29H33z"/>',
    'sustain': '<path d="M49 23a19 19 0 1 0 0 18M49 13v11H38" fill="none"/><path d="m23 33 6 6 13-15" fill="none"/>',
    'range': '<circle cx="32" cy="32" r="17" fill="none"/><path d="M32 7v15m0 20v15M7 32h15m20 0h15" fill="none"/><circle cx="32" cy="32" r="3"/>',
}

def build():
    DEST.mkdir(parents=True, exist_ok=True)
    resources, entries = [], []
    for key, mark in MARKS.items():
        path = DEST / (key + '.svg')
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="1" y="1" width="62" height="62" rx="8" fill="#101b25" stroke="#344e60"/><g fill="#c6a76d" stroke="#b8c6ce" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{mark}</g></svg>\n'
        path.write_text(svg, encoding='utf-8', newline='\n')
        ref = 'res://' + path.relative_to(ROOT / 'code').as_posix()
        resources.append({'resource_path': ref, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'source': 'Project-authored static SVG'})
        for kind, identifier in [('item', 'module_spec_' + key), ('blueprint', 'recipe_spec_' + key), ('research', 'spec_' + key)]:
            entries.append({'kind': kind, 'id': identifier, 'resource_path': ref})
    manifest = {'format_version': 1, 'asset_version': 'fitting-v1', 'entries': entries, 'resources': resources}
    (DEST / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('FITTING_ASSETS PASS resources=3 mappings=9')

if __name__ == '__main__':
    build()
