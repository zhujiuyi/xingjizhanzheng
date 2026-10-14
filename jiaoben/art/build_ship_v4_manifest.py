"""Register only the additive original ship-v4 resources and source provenance."""
from pathlib import Path
import hashlib,json,struct

ROOT=Path(__file__).resolve().parents[2]
CODE=ROOT/'code'; ART=CODE/'assets/ship_v4'
EXPECTED={
 'shuttle_swift','frigate_lantern','frigate_kestrel','miner_anvil','destroyer_raptor',
 'cruiser_horizon','battleship_bastion','transport_caravan','support_weaver','enemy_silent',
 'cruiser_council_sentinel','battleship_council_aegis','support_council_choir',
 'destroyer_forge_hammer','cruiser_forge_citadel','battleship_forge_ironwall',
 'destroyer_roaming_spear','cruiser_roaming_kite','battleship_roaming_tempest',
}

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def stats(path):
    raw=path.read_bytes();length,kind=struct.unpack_from('<II',raw,12)
    assert kind==0x4e4f534a
    gltf=json.loads(raw[20:20+length]);triangles=0;surfaces=0
    for mesh in gltf['meshes']:
        for primitive in mesh['primitives']:
            assert primitive.get('mode',4)==4
            count=gltf['accessors'][primitive['indices']]['count'] if 'indices' in primitive else gltf['accessors'][primitive['attributes']['POSITION']]['count']
            triangles+=count//3;surfaces+=1
    assert surfaces<=10 and triangles<=65000,(path.name,triangles,surfaces)
    return {'triangles':triangles,'mesh_surfaces':surfaces,'materials':len(gltf['materials'])}

def main():
    assert {p.stem for p in ART.glob('*.glb')}==EXPECTED,'All nineteen actual hulls are required'
    resources=[]
    paths=list(sorted(ART.glob('*.glb')))+list(sorted((ART/'portraits').glob('*.png')))
    paths += [CODE/'runtime/rendering/ship_v4_factory.gd',CODE/'runtime/rendering/ship_v4_hangar.gd']
    for path in paths:
        row={'resource_path':'res://'+path.relative_to(CODE).as_posix(),'sha256':sha(path),'size_bytes':path.stat().st_size}
        if path.suffix=='.glb':row.update(stats(path));row['ship_def_id']=path.stem
        resources.append(row)
    sources=list(sorted((ART/'source').glob('*.blend')))+[ROOT/'jiaoben/art'/name for name in ['build_ships_v4.py','ship_v4_geometry.py','ship_v4_common.py','ship_v4_civilizations.py']]
    value={'format_version':1,'asset_version':'ship-v4-original',
       'scope':'Nineteen original replacement ship visuals: eighteen catalog ships and the Silent enemy. Original wrapper collision, gameplay identities, hardpoints, engine and camera anchors are unchanged.',
       'source_document':'doc/70-舰船造型重建.md','runtime_adapter':'res://runtime/rendering/ship_v4_factory.gd',
       'authoring':{'tool':'Blender 4.5.14 LTS 62c1db4208e8','source_script':'jiaoben/art/build_ships_v4.py',
           'origin':'Project-authored meshes. No EVE game model or texture is shipped.',
           'references':[{'url':'https://www.eveonline.com/news/view/iconic-ships-reimagined-the-minmatar-rupture','use':'Composition, structural negative space, functional hierarchy and crew scale.'}]},
       'geometry_contracts':['res://assets/models/geometry.json','res://assets/civilization_v1/geometry.json'],
       'material_adapter':'res://runtime/rendering/surface_materials.gd',
       'resources':resources,'source_assets':[{'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p),'size_bytes':p.stat().st_size} for p in sources],
       'validation':{'status':'Build identities only. Actual native and release acceptance is recorded separately after execution.','maximum_triangles_per_hull':65000,'maximum_material_surfaces_per_hull':10}}
    (ART/'manifest.json').write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('SHIP_V4_MANIFEST',len(resources),sha(ART/'manifest.json'))

if __name__=='__main__':main()
