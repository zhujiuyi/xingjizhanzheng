"""Build original faction fittings over the existing industrial ship platforms."""
from pathlib import Path
import hashlib
import json
import sqlite3

ROOT = Path(__file__).resolve().parents[2]
CODE = ROOT / 'code'
PACK = CODE / 'assets/civilization_v1'


def main():
    source = sqlite3.connect((ROOT / 'jiaoben/tmp/catalog-civilizations-candidate.db').as_uri() + '?mode=ro', uri=True)
    source.row_factory = sqlite3.Row
    hulls = [dict(row) for row in source.execute('SELECT h.*,c.color_hex FROM civilization_hull_defs h JOIN civilization_defs c USING(faction_id)')]
    geometry = json.loads((CODE / 'assets/models/geometry.json').read_text(encoding='utf-8'))
    visual = {}
    extra_geometry = {}
    (PACK / 'hulls').mkdir(parents=True, exist_ok=True)
    (PACK / 'portraits').mkdir(exist_ok=True)
    for hull in hulls:
        id_, base = hull['ship_id'], hull['base_ship_id']
        original = (CODE / 'assets/ships' / (base + '.tscn')).read_text(encoding='utf-8')
        original = original.replace(f'metadata/ship_def_id = "{base}"', f'metadata/ship_def_id = "{id_}"')
        original = original.replace(f'metadata/asset_id = "asset_ship_{base}"', f'metadata/asset_id = "asset_ship_{id_}"')
        original = original.replace('metadata/asset_version = "art-full-v1"', 'metadata/asset_version = "civilization-v1"')
        (CODE / 'assets/ships' / (id_ + '.tscn')).write_text(original, encoding='utf-8', newline='\n')
        extra_geometry[id_] = geometry[base]
        color = tuple(int(hull['color_hex'][i:i + 2], 16) / 255 for i in (0, 2, 4))
        # Dimensions come from the published collision wrapper, never gameplay mass.
        import re
        dimensions = re.search(r'size = Vector3\(([^)]+)\)', original)[1]
        width, height, length = (float(value.strip()) for value in dimensions.split(','))
        if 'council' in id_:
            size, offset = (width * .08, height * .42, length * .24), (width * .39, height * .1, -length * .1)
        elif 'forge' in id_:
            size, offset = (width * .25, height * .14, length * .60), (width * .30, height * .28, length * .02)
        else:
            size, offset = (width * .10, height * .16, length * .45), (width * .35, height * .03, length * .20)
        vector = lambda values: 'Vector3(' + ', '.join(f'{value:.6g}' for value in values) + ')'
        scene = f'''[gd_scene load_steps=5 format=3]

[ext_resource type="PackedScene" path="res://assets/ship_v3/{base}.glb" id="base"]

[sub_resource type="StandardMaterial3D" id="paint"]
resource_name = "civilization_paint"
albedo_color = Color({color[0]:.6f}, {color[1]:.6f}, {color[2]:.6f}, 1)
metallic = 0.58
roughness = 0.68

[sub_resource type="BoxMesh" id="wing"]
material = SubResource("paint")
size = {vector(size)}

[sub_resource type="BoxMesh" id="stripe"]
material = SubResource("paint")
size = {vector((width * .09, height * .055, length * .38))}

[node name="CivilizationHull" type="Node3D"]
metadata/visual_asset_version = "civilization-v1"
metadata/ship_def_id = "{id_}"

[node name="Platform" parent="." instance=ExtResource("base")]

[node name="PortFitting" type="MeshInstance3D" parent="."]
position = {vector((-offset[0], offset[1], offset[2]))}
mesh = SubResource("wing")

[node name="StarboardFitting" type="MeshInstance3D" parent="."]
position = {vector(offset)}
mesh = SubResource("wing")

[node name="CivilizationStripe" type="MeshInstance3D" parent="."]
position = {vector((0, height * .30, -length * .08))}
mesh = SubResource("stripe")
'''
        (PACK / 'hulls' / (id_ + '.tscn')).write_text(scene, encoding='utf-8', newline='\n')
        visual[id_] = {'base_ship_id': base, 'color_hex': hull['color_hex'], 'model_path': f'res://assets/civilization_v1/hulls/{id_}.tscn',
                       'portrait_path': f'res://assets/civilization_v1/portraits/{id_}.png'}
    for sector, asset in source.execute("SELECT sector_id,scene_asset_id FROM sector_runtime_defs WHERE sector_id LIKE 'sector_council_%' OR sector_id LIKE 'sector_forge_%' OR sector_id LIKE 'sector_roaming_%' OR sector_id LIKE 'sector_frontier_%'"):
        (CODE / 'assets/sectors' / (sector + '.tscn')).write_text(
            f'[gd_scene format=3]\n\n[node name="SectorVisualRoot" type="Node3D"]\nmetadata/asset_id = "{asset}"\nmetadata/sector_id = "{sector}"\nmetadata/asset_version = "civilization-v1"\n', encoding='utf-8', newline='\n')
    for name, value in [('visuals.json', visual), ('geometry.json', extra_geometry)]:
        (PACK / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    paths = sorted([*PACK.rglob('*.tscn'), *PACK.glob('*.json'), *PACK.glob('portraits/*.png'),
                    *(CODE / 'assets/ships' / (hull['ship_id'] + '.tscn') for hull in hulls),
                    *(CODE / 'assets/sectors' / (row[0] + '.tscn') for row in source.execute("SELECT sector_id FROM sector_runtime_defs WHERE stage_code='D' AND sector_id IN (SELECT sector_id FROM sector_sovereignty_defs)")
                       if row[0] not in ['sector_mirror', 'sector_forge', 'sector_iron', 'sector_helios', 'sector_drift', 'sector_mist', 'sector_rift', 'sector_silent'])])
    resources = []
    for path in paths:
        if path.name == 'manifest.json': continue
        resources.append({'resource_path': 'res://' + path.relative_to(CODE).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    # The reviewed v0.7 bridge is used only for upgrading older frozen worlds.
    bridge = CODE / 'data/catalog_space_v7.db'
    resources.append({'resource_path': 'res://data/catalog_space_v7.db', 'sha256': hashlib.sha256(bridge.read_bytes()).hexdigest()})
    adapter = CODE / 'runtime/visuals/civilization_visual_factory.gd'
    resources.append({'resource_path': 'res://runtime/visuals/civilization_visual_factory.gd', 'sha256': hashlib.sha256(adapter.read_bytes()).hexdigest()})
    hangar = CODE / 'runtime/civilization_hangar.gd'
    resources.append({'resource_path': 'res://runtime/civilization_hangar.gd', 'sha256': hashlib.sha256(hangar.read_bytes()).hexdigest()})
    entries = []
    for hull in hulls:
        id_ = hull['ship_id']
        portrait = 'res://assets/civilization_v1/portraits/' + id_ + '.png'
        entries.extend([{'kind': 'ship', 'id': id_, 'resource_path': portrait},
                        {'kind': 'blueprint', 'id': 'hull_recipe_' + id_, 'resource_path': portrait},
                        {'kind': 'research', 'id': 'research_' + id_, 'resource_path': 'res://assets/business_v11/generic/research.svg'}])
    for row in source.execute("SELECT mission_id FROM mission_defs WHERE mission_id LIKE 'civ_%'"):
        entries.append({'kind': 'mission', 'id': row[0], 'resource_path': 'res://assets/business_v11/generic/mission.svg'})
    manifest = {'format_version': 1, 'asset_version': 'civilization-v1', 'entries': entries,
                'scope': 'Original faction fittings, nine distinct hull appearances, inherited collision contracts and 44 sector roots. Gameplay values remain in SQLite.',
                'resources': resources}
    (PACK / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    source.close()
    print(f'CIVILIZATION_ASSETS PASS hulls={len(hulls)} resources={len(resources)}')


if __name__ == '__main__':
    main()
