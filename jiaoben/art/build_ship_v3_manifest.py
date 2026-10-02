"""Register original industrial models separately from the frozen world identity."""
from pathlib import Path
import hashlib,json,struct
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'code/assets/ship_v3'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def stats(path):
 data=path.read_bytes();length,kind=struct.unpack_from('<II',data,12)
 assert kind==0x4e4f534a
 gltf=json.loads(data[20:20+length]);triangles=surfaces=0
 for mesh in gltf['meshes']:
  for primitive in mesh['primitives']:
   assert primitive.get('mode',4)==4
   triangles+=gltf['accessors'][primitive['indices']]['count']//3;surfaces+=1
 return {'triangles':triangles,'mesh_surfaces':surfaces,'materials':len(gltf['materials'])}
resources=[]
for path in sorted(ART.iterdir()):
 if path.suffix not in {'.glb','.gdshader'}:continue
 row={'resource_path':'res://'+str(path.relative_to(ROOT/'code')),'sha256':digest(path),'size_bytes':path.stat().st_size}
 if path.suffix=='.glb':row.update(stats(path));row['ship_def_id']=path.stem
 resources.append(row)
sources=[{'path':str(p.relative_to(ROOT)),'sha256':digest(p),'size_bytes':p.stat().st_size} for p in sorted((ART/'source').glob('*.blend'))]
manifest={'format_version':1,'asset_version':'ship-v3-industrial',
 'scope':'Nine existing player classes plus existing Silent NPC visual; presentation only, immutable art-full-v1 wrappers remain physics and anchors authority.',
 'authoring':{'tool':'Blender 4.5.14 LTS','source_script':'jiaoben/art/build_ships_v3.py','origin':'Project-authored original geometry and shader. No third-party model, extracted mesh or copied texture.',
  'design_references':[{'url':'https://www.eveonline.com/news/view/iconic-ships-reimagined-the-minmatar-rupture','use':'Official written discussion of negative spaces, exposed framing, spaced armor and human-scale windows; images were unavailable to this agent, not claimed as visually verified.'}],
  'texture_provenance':'External texture dependency is independently registered in assets/interface_v2/manifest.json; not bundled a second time.'},
 'runtime_adapter':'res://runtime/visuals/industrial_visual_factory.gd','surface_script':'res://runtime/surface_style.gd',
 'geometry_contract':'res://assets/models/geometry.json',
 'material_policy':{'metal_roughness_range':[.65,.90],'large_surface_emission':False,'lighting_independent':'Final spatial PBR shader, physical authored roughness; no screen-space painted shine','mapping':'Object-space triplanar microtexture; derivative bump only, no vertex displacement'},
 'external_dependencies':[{'resource_path':'res://assets/interface_v2/metal_albedo.png','sha256':digest(ROOT/'code/assets/interface_v2/metal_albedo.png')}],
 'resources':resources,'source_assets':sources,
 'qa':{'status':'Final geometry/material contracts and isolated native previews passed; exported-client and integrated UI review owned by root.',
  'test_script':'jiaoben/art/test_ship_v3.gd','preview_script':'jiaoben/art/preview_ship_v3.gd','runtime_assertions':410,'failed_assertions':0,'checked_backends':['headless','Metal Forward+ / CoreAudio'],
  'resolution_px':[1600,1000],'native_ship_captures':12,'native_hangar_captures':3,
  'performance_boundary':'TIME_PROCESS samples are CPU/frame-loop observations, affected by window focus and scheduling; not GPU timings or a 60fps certificate. Material surfaces are merged; Godot importer auto-LOD is enabled but no hand-authored LOD is provided.',
  'preserved_frozen_world_art_resources':79,'preserved_hangar_resources':11,'preserved_catalog_file_sha256':'38f9d73575a17a578884e335d1b19ee4833e490cbbd2047b2953c69dd367e25b'}}
(ART/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('SHIP_V3_MANIFEST',len(resources),'runtime resources',sum(row.get('triangles',0) for row in resources),'triangles',digest(ART/'manifest.json'))
