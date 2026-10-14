"""Blender: --background --python jiaoben/art/build_ships_v4.py -- --ships id,id.

New original hull pack. Immutable wrappers retain physics, camera and mounts.
"""
from pathlib import Path
import sys,json,hashlib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
from ship_v4_geometry import Hull
from ship_v4_common import BUILDERS as COMMON

GEO=json.loads((ROOT/'code/assets/models/geometry.json').read_text(encoding='utf-8'))
GEO.update(json.loads((ROOT/'code/assets/civilization_v1/geometry.json').read_text(encoding='utf-8')))
BUILDERS=dict(COMMON)
try:
    from ship_v4_civilizations import BUILDERS as CIVILIZATIONS
    BUILDERS.update(CIVILIZATIONS)
except ImportError:
    pass
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
selected=args[args.index('--ships')+1].split(',') if '--ships' in args else sorted(BUILDERS)
OUT=ROOT/'code/assets/ship_v4'
manifest_path=OUT/'geometry-report.json'
records=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
for ship_id in selected:
    faction=('silent' if ship_id=='enemy_silent' else 'forge' if 'forge' in ship_id or ship_id in ['miner_anvil','destroyer_raptor','battleship_bastion'] else 'roaming' if 'roaming' in ship_id or ship_id in ['transport_caravan','frigate_kestrel'] else 'council')
    d=Hull(ship_id,GEO[ship_id],faction)
    BUILDERS[ship_id](d)
    # The original muzzle/engine anchor locations remain visibly integrated.
    d.armament()
    for side in [-1,1]:
        d.wing('Aft_engine_load_yoke',[(0,.23),(side*.21,.285),(side*.23,.35),(0,.32)],-.055,.08,'secondary')
        d.engine(side*.18,r=.065 if GEO[ship_id]['length_m']<60 else .075)
    row=d.finish(OUT)
    row.update({'faction':faction,'geometry_source':'assets/civilization_v1/geometry.json' if ship_id not in COMMON else 'assets/models/geometry.json','collision_box_m':GEO[ship_id]['collision_box_m'],'glb_sha256':hashlib.sha256((OUT/f'{ship_id}.glb').read_bytes()).hexdigest()})
    records[ship_id]=row
    manifest_path.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('SHIP_V4',ship_id,row,flush=True)
