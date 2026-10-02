"""Register only new presentation resources, keeping the frozen world art untouched."""
from pathlib import Path
import hashlib,json,struct
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'code/assets/hangar_v2'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def glb_stats(p):
 data=p.read_bytes();length,kind=struct.unpack_from('<II',data,12)
 assert kind==0x4e4f534a
 doc=json.loads(data[20:20+length]);triangles=0;surfaces=0
 for mesh in doc.get('meshes',[]):
  for primitive in mesh.get('primitives',[]):
   assert primitive.get('mode',4)==4
   count=doc['accessors'][primitive.get('indices',primitive['attributes']['POSITION'])]['count']
   triangles+=count//3;surfaces+=1
 return {'triangles':triangles,'mesh_surfaces':surfaces,'nodes':len(doc.get('nodes',[])),'materials':len(doc.get('materials',[])),'animation':'rigid_pivots' if 'crew_' in p.name else 'runtime_transform'}
layout=json.loads((ART/'layout.json').read_text());layout['asset_version']='hangar-v2';(ART/'layout.json').write_text(json.dumps(layout,indent=2)+'\n')
runtime=[]
for p in sorted(ART.iterdir()):
 if p.suffix not in {'.glb','.gdshader'} and p.name!='layout.json':continue
 row={'resource_path':'res://'+str(p.relative_to(ROOT/'code')),'sha256':digest(p),'size_bytes':p.stat().st_size}
 if p.suffix=='.glb':row.update(glb_stats(p))
 runtime.append(row)
sources=[{'path':str(p.relative_to(ROOT)),'sha256':digest(p),'size_bytes':p.stat().st_size} for p in sorted((ART/'source').glob('*.blend'))]
manifest={'format_version':1,'asset_version':'hangar-v2','scope':'Independent presentation stage and runtime metal shaders; no world-state, balance, ship geometry or old art identity changes.',
 'authoring':{'tool':'Blender 4.5.14 LTS','source_script':'jiaoben/art/build_hangar_v2.py','origin':'Original authored geometry; no third-party meshes.','rights':'Project-authored models and shaders. External metal texture provenance belongs to assets/interface_v2/manifest.json.'},
 'runtime_script':'res://runtime/station_hangar.gd','surface_script':'res://runtime/surface_style.gd',
 'art_direction':{'shape':'beveled industrial panels, angled machinery, stylized human anatomy','palette':'steel blue/carbon grey with cyan navigation and amber safety details; profession uniforms navy/orange/white/olive','materials':'rough brushed metal, matte cloth and skin, dark functional terminal displays','lighting':'cold key and restrained warm fill, one shadow-casting light','camera':'diagonal 45-degree exhibition, private Environment and visual layer 20','motion':'low-amplitude head/arm motion, hovering service drone and exhibit, no simulated physics'},
 'technical':{'deck_bounds_m':[76,27,64],'crew_height_m_approx':2,'showcase_length_m':26,'showcase_only':True,'collision':'none','mesh_normal_source':'Blender bevel/weighted normals; smooth faces on anatomy','uv_policy':'Blender primitive UVs; metal uses object/triplanar mapping on original UV-less hulls','rig':'rigid pivot hierarchy HeadPivot/LeftArmPivot/RightArmPivot, not skinned','texture_dependency':'res://assets/interface_v2/metal_albedo.png','shadow_lights':1,'layer':20,'lod_policy':'Single small isolated exhibition stage, merged material surfaces; hidden stage processing disabled by host; no extra character LOD yet.'},
 'resources':runtime,'source_assets':sources,
 'qa':{'native_renderer':'Godot 4.7.2 Metal Forward+ / Apple M1 Pro','resolution_px':[1440,900],'test_script':'jiaoben/art/test_hangar_v2.gd','runtime_assertions':161,'failed_assertions':0,'preview_script':'jiaoben/art/preview_hangar_v2.gd','ship_preview_script':'jiaoben/art/preview_surface_v2.gd','status':'native isolated-stage visual checks passed; host UI and exported-client checks owned by integration','performance_monitor':'TIME_PROCESS: stage samples vary with focus/system scheduling; not a GPU timing or 60fps certification','draw_calls_final_observed':{'battle_overview':205,'miner_overview':205,'operations':72,'industry':137,'research':131,'supplies_repeat':128},'preserved_frozen_world_art_resources':79,'preserved_catalog_file_sha256':'38f9d73575a17a578884e335d1b19ee4833e490cbbd2047b2953c69dd367e25b'}}
(ART/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('HANGAR_MANIFEST',len(runtime),'runtime files',sum(r['triangles'] for r in runtime if 'triangles' in r),'triangles',digest(ART/'manifest.json'))
