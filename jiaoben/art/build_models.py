"""Original procedural hard-surface art. Run in Blender 4.5 background.

No EVE meshes/textures are downloaded or extracted. Fixed model dimensions
and hardpoints are asset structure; this script defines no gameplay balance.
"""
from pathlib import Path
from math import sin, cos, pi
import bpy
import bmesh
import json
import random
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'code/assets/models'
TMP = ROOT / 'jiaoben/tmp/art'
OUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
for block in list(bpy.data.materials): bpy.data.materials.remove(block)

PALETTES = {
 'council': ((.42,.52,.62),(.10,.19,.29),(.20,.67,1.0)),
 'deepforge': ((.38,.27,.18),(.13,.16,.18),(1.0,.43,.12)),
 'roaming': ((.19,.23,.27),(.09,.11,.14),(1.0,.68,.18)),
 'silent': ((.035,.055,.07),(.01,.02,.025),(.10,1.0,.82)),
}
MATS={}
for faction,(primary,dark,glow) in PALETTES.items():
 for role,color,metal,rough,emission in [('hull',primary,.82,.32,0),('dark',dark,.75,.55,0),('trim',tuple(min(1,c*1.5) for c in primary),.9,.25,0),('glow',glow,.25,.3,3.2),('glass',tuple(c*.22 for c in glow),.9,.12,.35)]:
  mat=bpy.data.materials.new(f'{faction}_{role}'); mat.use_nodes=True
  p=mat.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
  p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
  p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
  MATS[(faction,role)]=mat

current=None; faction='council'; serial=0
def add_mesh(name,verts,faces,role='hull',bevel=0):
 global serial
 serial+=1; mesh=bpy.data.meshes.new(f'{name}_{serial}'); mesh.from_pydata(verts,[],faces);mesh.update()
 # Closed faceted primitives must have outward normals before bevel/weighted normals.
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
 bm.to_mesh(mesh);bm.free();mesh.update()
 obj=bpy.data.objects.new(mesh.name,mesh); current.objects.link(obj);obj.data.materials.append(MATS[(faction,role)])
 if bevel:
  mod=obj.modifiers.new('Machined_edges','BEVEL');mod.width=bevel;mod.segments=2
  mod=obj.modifiers.new('Panel_normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 return obj

def box(name,size,pos=(0,0,0),role='hull',bevel=.08):
 x,y,z=(a/2 for a in size);px,py,pz=pos
 verts=[(px+a*x,py+b*y,pz+c*z) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 return add_mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],role,bevel)

def cylinder(name,radius,length,pos=(0,0,0),role='hull',axis='Y',segments=16,radius2=None):
 radius2=radius if radius2 is None else radius2;verts=[]
 for end,r in [(-length/2,radius),(length/2,radius2)]:
  for i in range(segments):
   a=2*pi*i/segments;v=(r*cos(a),end,r*sin(a)) if axis=='Y' else (r*cos(a),r*sin(a),end)
   verts.append(tuple(v[j]+pos[j] for j in range(3)))
 faces=[tuple(reversed(range(segments))),tuple(range(segments,2*segments))]
 faces += [(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)]
 return add_mesh(name,verts,faces,role, min(radius*.08,.16))

def ring(name,radius,tube,pos=(0,0,0),role='hull',axis='Z',segments=64):
 verts=[];sides=6
 for i in range(segments):
  a=i*2*pi/segments
  for j in range(sides):
   b=j*2*pi/sides;r=radius+tube*cos(b)
   v=(r*cos(a),r*sin(a),tube*sin(b)) if axis=='Z' else (r*cos(a),tube*sin(b),r*sin(a))
   verts.append(tuple(v[k]+pos[k] for k in range(3)))
 faces=[]
 for i in range(segments):
  for j in range(sides): faces.append((i*sides+j,((i+1)%segments)*sides+j,((i+1)%segments)*sides+(j+1)%sides,i*sides+(j+1)%sides))
 return add_mesh(name,verts,faces,role)

def hull(length,width,height,offset=(0,0,0),role='hull'):
 sections=[(-.5,.40,.45),(-.37,.95,.86),(-.14,1,1),(.15,.84,.87),(.35,.52,.61),(.5,.10,.20)]
 cross=[(-1,-.55),(-.68,-1),(.68,-1),(1,-.55),(1,.55),(.68,1),(-.68,1),(-1,.55)]
 verts=[]
 for y,w,h in sections:
  for x,z in cross: verts.append((x*width*w/2+offset[0],y*length+offset[1],z*height*h/2+offset[2]))
 faces=[tuple(reversed(range(8))),tuple(range(40,48))]
 for i in range(5):
  for j in range(8):faces.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
 return add_mesh('Faceted_pressure_hull',verts,faces,role,min(width*.015,.22))

def engines(length,width,height,count):
 for i in range(count):
  x=(i-(count-1)/2)*width*.24;r=min(width/(count+3)*.7,height*.23)
  cylinder('Engine_bell',r,length*.13,(x,-length*.39,0),'dark',radius2=r*.72)
  cylinder('Ceramic_nozzle',r*.72,length*.035,(x,-length*.466,0),'trim')
  cylinder('Reactor_core',r*.56,length*.004,(x,-length*.487,0),'glow')
  ring('Nozzle_rim',r*.75,r*.08,(x,-length*.46,0),'trim','Y',24)

def surface_details(length,width,height,industrial=False):
 rows=7 if length>100 else 5
 for sign in (-1,1):
  for i in range(rows):
   y=-length*.30+i*length*.09
   box('Armor_panel', (width*.145,length*.076,height*.13),(sign*width*.21,y,height*.29),'hull',min(.12,height*.025))
   box('Panel_inset',(width*.105,length*.054,height*.025),(sign*width*.21,y,height*.366),'dark',.025)
   if i%2==0:box('Status_bar',(width*.07,length*.012,height*.012),(sign*width*.21,y,height*.383),'glow',.005)
  for i in range(6):
   box('Radiator_fin',(width*.10,length*.011,height*.16),(sign*width*.25,-length*.29+i*length*.034,height*.19),'dark',.025)
 for i in range(8):
  box('Bridge_window',(width*.025,length*.045,height*.025),((i-3.5)*width*.027,length*.23,height*.285),'glass',.01)
 for sign in (-1,1):
  box('Longitudinal_trim',(width*.018,length*.42,height*.02),(sign*width*.28,-length*.04,height*.23),'trim',.015)
  box('Navigation_strip',(width*.012,length*.13,height*.014),(sign*width*.282,length*.10,height*.256),'glow',.003)
 if industrial:
  for i in range(5):
   for sign in (-1,1):
    box('Cargo_cell',(width*.26,length*.11,height*.37),(sign*width*.32,-length*.29+i*length*.135,-height*.10),'hull',.22)
    box('Cargo_latch',(width*.28,length*.012,height*.05),(sign*width*.32,-length*.29+i*length*.135,height*.105),'trim',.03)

SHIP_SPECS={
 'shuttle_swift':(18,10,6,'council','shuttle'),
 'frigate_lantern':(28,14,8,'council','explorer'),
 'frigate_kestrel':(30,18,9,'roaming','fighter'),
 'miner_anvil':(56,36,20,'deepforge','miner'),
 'destroyer_raptor':(70,30,18,'deepforge','destroyer'),
 'cruiser_horizon':(115,60,34,'council','cruiser'),
 'battleship_bastion':(220,110,65,'deepforge','battleship'),
 'transport_caravan':(145,75,48,'roaming','transport'),
 'support_weaver':(90,65,28,'council','support'),
 'enemy_silent':(30,28,20,'silent','silent'),
}

def new_collection(name,style):
 global current,faction
 faction=style;current=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(current)
 return current

def normalize_bounds(collection,length,width,height):
 objects=[o for o in collection.objects if o.type=='MESH']
 mins=[min(v.co[k] for o in objects for v in o.data.vertices) for k in range(3)]
 maxs=[max(v.co[k] for o in objects for v in o.data.vertices) for k in range(3)]
 target=[width,length,height];factors=[target[k]/(maxs[k]-mins[k]) for k in range(3)]
 center=[(maxs[k]+mins[k])/2 for k in range(3)]
 for obj in objects:
  for v in obj.data.vertices:
   v.co=tuple((v.co[k]-center[k])*factors[k] for k in range(3))

def consolidate(collection):
 # Keep four/five material meshes instead of hundreds of draw calls.
 groups={}
 for obj in list(collection.objects):
  if obj.type=='MESH':groups.setdefault(obj.data.materials[0].name,[]).append(obj)
 for name,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  for obj in objects:
   bpy.context.view_layer.objects.active=obj
   for mod in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.context.view_layer.objects.active=objects[0]
  bpy.ops.object.join();bpy.context.object.name=name

def export_collection(collection,path):
 path.parent.mkdir(parents=True,exist_ok=True)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in collection.objects:obj.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_apply=True,export_cameras=False,export_lights=False)
 print('ORIGINAL_GLB_EXPORTED',path,flush=True)

geometry={}
for sid,(length,width,height,style,role) in SHIP_SPECS.items():
 col=new_collection(sid,style)
 hull(length*.93,width*.55,height*.75)
 engines(length,width,height,2 if role in ('shuttle','explorer','fighter','silent') else 4)
 surface_details(length,width,height,role in ('miner','transport'))
 if role in ('shuttle','fighter','destroyer','cruiser'):
  for sign in (-1,1):
   hull(length*.44,width*.23,height*.25,(sign*width*.35,-length*.10,-height*.14),'dark')
   box('Swept_wing',(width*.42,length*.21,height*.08),(sign*width*.24,-length*.14,-height*.06),'hull',.16)
   cylinder('Weapon_barrel',height*.035,length*.16,(sign*width*.28,length*.24,height*.16),'dark',segments=12)
   cylinder('Weapon_tip',height*.06,length*.025,(sign*width*.28,length*.315,height*.16),'trim',segments=12)
 if role=='explorer':
  cylinder('Sensor_mast',width*.026,height*.34,(0,-length*.05,height*.32),'trim','Z',12)
  ring('Sensor_aperture',width*.24,width*.018,(0,-length*.02,height*.40),'trim','Y',32)
  for sign in(-1,1):box('Scan_array',(width*.10,length*.35,height*.07),(sign*width*.40,length*.04,height*.04),'glass',.06)
 if role=='miner':
  for sign in(-1,1):
   box('Industrial_beam',(width*.10,length*.70,height*.09),(sign*width*.43,length*.03,-height*.20),'trim',.15)
   cylinder('Excavator_head',height*.12,length*.10,(sign*width*.43,length*.35,-height*.20),'dark',segments=16,radius2=height*.06)
   cylinder('Excavator_lens',height*.065,length*.006,(sign*width*.43,length*.40,-height*.20),'glow',segments=16)
 if role=='battleship':
  hull(length*.73,width*.80,height*.25,(0,-length*.04,-height*.13),'dark')
  for y in(-.22,-.04,.14,.29):
   for sign in(-1,1):
    cylinder('Heavy_turret',height*.09,height*.09,(sign*width*.25,y*length,height*.30),'dark','Z',16)
    for x in(-1,1):cylinder('Heavy_gun',height*.025,length*.11,(sign*width*.25+x*width*.022,y*length+length*.075,height*.345),'trim',segments=12)
  box('Command_tower',(width*.16,length*.23,height*.30),(0,-length*.15,height*.30),'hull',.7)
 if role=='transport':
  for sign in(-1,1):box('Carrier_spine',(width*.035,length*.90,height*.045),(sign*width*.45,0,height*.15),'trim',.1)
  box('Offset_bridge',(width*.17,length*.18,height*.18),(-width*.20,length*.25,height*.30),'hull',.2)
 if role=='support':
  for sign in(-1,1):
   hull(length*.73,width*.18,height*.36,(sign*width*.38,-length*.05,0),'hull')
   ring('Relay_array',height*.30,width*.012,(sign*width*.39,length*.05,height*.10),'glow','Y',32)
  box('Transfer_bridge',(width*.80,length*.07,height*.07),(0,-length*.16,0),'trim',.1)
 if role=='silent':
  for sign in(-1,1):
   hull(length*.60,width*.22,height*.62,(sign*width*.35,-length*.06,0),'dark')
   box('Ancient_lattice',(width*.025,length*.57,height*.028),(sign*width*.28,0,height*.27),'glow',.008)
  ring('Void_core',height*.27,height*.026,(0,length*.10,height*.02),'glow','Y',32)
 normalize_bounds(col,length,width,height);consolidate(col)
 for obj in col.objects:obj['asset_id']='asset_ship_'+sid;obj['geometry_version']='art-full-v1'
 export_collection(col,OUT/'ships'/f'{sid}.glb')
 geometry[sid]={'length_m':length,'width_m':width,'height_m':height,'collision_box_m':[width,height,length],'faction_style':style,'axis':'Y_up_negative_Z_front'}

# Original orbital station: a vertical core, three habitation rings and docks.
col=new_collection('station_anchor','council')
cylinder('Station_core',48,230,(0,0,0),'dark','Z',32)
for height,radius in[(-70,120),(0,210),(70,145)]:
 ring('Habitation_ring',radius,10,(0,0,height),'hull','Z',96)
 ring('Window_ribbon',radius+1,2,(0,0,height+7),'glow','Z',96)
 for i in range(8):
  a=2*pi*i/8;spoke=box('Radial_truss',(radius*.9,10,14),(radius*.52,0,height),'dark',.8)
  for vertex in spoke.data.vertices:
   x,y,z=vertex.co;vertex.co=(x*cos(a)-y*sin(a),x*sin(a)+y*cos(a),z)
for i in range(12):
 a=2*pi*i/12
 cylinder('Docking_tower',13,95,(190*cos(a),190*sin(a),-10),'hull','Z',12)
 box('Dock_beacon',(7,7,3),(190*cos(a),190*sin(a),40),'glow',.3)
consolidate(col);export_collection(col,OUT/'structures/station_anchor.glb')

# Anchored gate frame; aperture lies in XZ in Blender, XY in Godot.
col=new_collection('gate_anchor','council')
for y in(-8,8):
 ring('Anchor_ring',92,4,(0,y,0),'trim','Y',80)
 ring('Field_coil',84,1.5,(0,y,0),'glow','Y',80)
for i in range(12):
 a=2*pi*i/12;x,z=96*cos(a),96*sin(a)
 box('Gate_coil_housing',(13,28,13),(x,0,z),'hull',1)
 box('Gate_relay',(5,30,5),(x,0,z),'glow',.3)
consolidate(col);export_collection(col,OUT/'structures/gate_anchor.glb')

ORE_SPECS=[('ore_iron','deepforge',False,(.45,.32,.18)),
 ('ore_crystal','council',True,(.1,.65,1.0)),
 ('ore_echo_silica','council',True,(.35,.22,1.0)),
 ('ore_mirror_crystal','council',True,(.65,1.0,.9)),
 ('ore_corrosion_titanium','deepforge',False,(.8,.26,.13)),
 ('ore_pressure_steel','deepforge',False,(.25,.5,.65)),
 ('ore_solar_core','deepforge',True,(1.0,.3,.07)),
 ('ore_phase_stone','silent',True,(.55,.16,1.0))]
for oid,style,is_crystal,vein_color in ORE_SPECS:
 col=new_collection(oid,style);rnd=random.Random(oid)
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=22)
 obj=bpy.context.object
 for oldcol in list(obj.users_collection):oldcol.objects.unlink(obj)
 col.objects.link(obj);obj.name='Asteroid_matrix';obj.data.materials.append(MATS[(style,'dark')])
 for v in obj.data.vertices:v.co *= rnd.uniform(.78,1.18);v.co.z*=.72
 custom=MATS[(style,'glow' if is_crystal else 'trim')].copy();custom.name=f'{oid}_vein'
 bsdf=custom.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(*vein_color,1)
 if is_crystal:bsdf.inputs['Emission Color'].default_value=(*vein_color,1)
 for i in range(18):
  a=rnd.random()*2*pi;b=rnd.uniform(-1,1);r=21
  pos=(r*cos(a)*(1-b*b)**.5,r*sin(a)*(1-b*b)**.5,r*b*.75)
  if is_crystal:detail=cylinder('Crystal_vein',rnd.uniform(.8,2.2),rnd.uniform(5,11),pos,'glow','Z',5,radius2=.08)
  else:detail=box('Metallic_vein',(rnd.uniform(3,7),rnd.uniform(1,3),rnd.uniform(1,3)),pos,'trim',.2)
  detail.data.materials[0]=custom
 consolidate(col);export_collection(col,OUT/f'environment/{oid}.glb')

col=new_collection('wreck','deepforge')
hull(23,16,7,role='dark')
for i in range(12):
 rnd=random.Random(41+i);box('Broken_panel',(rnd.uniform(1,5),rnd.uniform(1,4),.2),(rnd.uniform(-8,8),rnd.uniform(-10,10),rnd.uniform(-2,3)),'hull',.06)
for sign in(-1,1):cylinder('Damaged_engine',1.5,4,(sign*5,-7,0),'dark')
consolidate(col);export_collection(col,OUT/'environment/wreck.glb')

(OUT/'geometry.json').write_text(json.dumps(geometry,indent=2)+'\n')
# Editable master file keeps all assets in named collections at origin;
# isolate one collection for editing/exporting rather than viewing all at once.
(ROOT/'code/assets/source').mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'code/assets/source/original_fleet.blend'))
print('ART_BUILD_COMPLETE',len(SHIP_SPECS),'ships + station/gate/ores/wreck',flush=True)
