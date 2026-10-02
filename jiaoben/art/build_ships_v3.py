"""Original industrial hulls. Geometry envelope and wrapper anchors remain art-full-v1.
Blender 4.5: first -- prototypes, then full family after native visual review.
"""
from pathlib import Path
import bpy,bmesh,math,json,sys
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'code/assets/ship_v3'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'source').mkdir(exist_ok=True)
(OUT/'source/.gdignore').write_text('')
GEO=json.loads((ROOT/'code/assets/models/geometry.json').read_text())
SHIPS=['shuttle_swift','frigate_lantern','frigate_kestrel','miner_anvil','destroyer_raptor','cruiser_horizon','battleship_bastion','transport_caravan','support_weaver','enemy_silent']
bpy.context.preferences.filepaths.save_version=0
M={};SERIAL=0
def reset(faction):
 global M,SERIAL
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True);SERIAL=0
 paint={'council':(.12,.17,.18),'deepforge':(.25,.19,.095),'roaming':(.16,.17,.12),'silent':(.11,.15,.14)}[faction]
 M={}
 for role,color,metal,rough,emission in [
  ('hull',(.235,.26,.27),.62,.77,0),('dark',(.043,.049,.052),.30,.86,0),
  ('trim',(.31,.325,.32),.75,.72,0),('paint',paint,.18,.84,0),
  ('secondary',(.145,.163,.168),.48,.82,0),
  ('ceramic',(.085,.083,.073),.08,.84,0),('warning',(.40,.30,.10),.15,.67,0),
  ('glass',(.018,.033,.038),.58,.23,0),('window',(.37,.32,.21),.0,.5,.48),
  ('glow',(.34,.30,.23),.05,.6,.60),('lamp',(.27,.36,.38),.0,.52,.35),
 ]:
  mat=bpy.data.materials.new('v3_'+faction+'_'+role);mat.use_nodes=True
  p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
  M[role]=mat
def b(v):return Vector((v[0],-v[2],v[1]))
def finish(o,name,role,bevel=0):
 global SERIAL
 SERIAL+=1;o.name=f'{name}_{SERIAL}';o.data.materials.append(M[role])
 # Final shared chamfer/weighted normals are applied after material merge in
 # export(). Per-object live modifiers would repeatedly evaluate all existing
 # plates during each following Blender primitive operation.
 return o
def box(name,size,pos,role='hull',bevel=.04):
 bpy.ops.mesh.primitive_cube_add(size=1,location=b(pos));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,role,min(bevel,min(size)*.22))
def mesh(name,verts,faces,role='hull',bevel=.04):
 data=bpy.data.meshes.new(name);data.from_pydata([b(v) for v in verts],[],faces);data.update()
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
 bm.to_mesh(data);bm.free();data.update()
 o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
 return finish(o,name,role,bevel)
def loft(name,sections,role='hull',bevel=.06):
 # Sections: z,width,height,center_y,center_x. Chamfered pressure/armor profile.
 verts=[]
 for z,w,h,y,x in sections:
  verts.extend([(x-w/2,y-h*.31,z),(x-w*.34,y-h/2,z),(x+w*.34,y-h/2,z),(x+w/2,y-h*.31,z),(x+w/2,y+h*.29,z),(x+w*.33,y+h/2,z),(x-w*.33,y+h/2,z),(x-w/2,y+h*.29,z)])
 faces=[tuple(range(7,-1,-1)),tuple(range((len(sections)-1)*8,len(sections)*8))]
 for i in range(len(sections)-1):
  for j in range(8):faces.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
 return mesh(name,verts,faces,role,bevel)
def profile(section):
 z,w,h,y,x=section
 return [Vector(v) for v in [(x-w/2,y-h*.31,z),(x-w*.34,y-h/2,z),(x+w*.34,y-h/2,z),(x+w/2,y-h*.31,z),(x+w/2,y+h*.29,z),(x+w*.33,y+h/2,z),(x-w*.33,y+h/2,z),(x-w/2,y+h*.29,z)]]
def armour_tile(name,corners,normal,role='hull',depth=.07):
 # Separate solid plates expose the dark pressure core through actual gaps.
 verts=[tuple(p-normal*depth) for p in corners]+[tuple(p) for p in corners]
 tile=mesh(name,verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],role,min(.025,depth*.25))
 # A single machined chamfer is sufficient at plate scale; avoid tessellating
 # hundreds of tiny plates into rounded plastic-looking edges.
 for modifier in tile.modifiers:
  if modifier.type=='BEVEL':modifier.segments=1
 return tile
def segmented_shell(name,sections,gap=.10):
 loft(name+'_pressure_core',[(z,w*.958,h*.954,y,x) for z,w,h,y,x in sections],'dark',gap*.15)
 for i in range(len(sections)-1):
  a,bp=sections[i:i+2];distance=bp[0]-a[0]
  if distance<=gap*2:continue
  av,bv=profile(a),profile(bp)
  pitch=max(1.1,min(6.0,(a[1]+bp[1])*.16))
  longitudinal=max(1,math.ceil(distance/pitch))
  for face in range(8):
   j=(face+1)%8;across=max(1,math.ceil(max((av[j]-av[face]).length,(bv[j]-bv[face]).length)/pitch))
   for zi in range(longitudinal):
    for ui in range(across):
     t0=(zi+gap*.5/distance*longitudinal)/longitudinal;t1=(zi+1-gap*.5/distance*longitudinal)/longitudinal
     u_gap=min(.07,gap/max((av[j]-av[face]).length,.01))
     u0=ui/across+u_gap*.5;u1=(ui+1)/across-u_gap*.5
     if u1<=u0:continue
     corners=[]
     for t,u in [(t0,u0),(t0,u1),(t1,u1),(t1,u0)]:corners.append(av[face].lerp(bv[face],t).lerp(av[j].lerp(bv[j],t),u))
     normal=(corners[1]-corners[0]).cross(corners[3]-corners[0]).normalized()
     mid=sum(corners,Vector())/4;center=Vector(((a[4]+bp[4])/2,(a[3]+bp[3])/2,mid.z))
     if normal.dot(mid-center)<0:normal=-normal
     role=['hull','hull','secondary','hull','trim','hull','secondary'][(face*3+zi+ui+i)%7]
     armour_tile(name+'_individual_armour',corners,normal,role,max(.065,gap*.45))
 # End bulkheads are recessed; no giant reflective cap substitutes for plate work.
 for index in [0,-1]:
  z,w,h,y,x=sections[index];loft(name+'_end_bulkhead',[(z-.015,w*.95,h*.95,y,x),(z+.015,w*.95,h*.95,y,x)],'secondary',.008)
def rod(name,a,z,r=.05,role='trim',r2=None,vertices=16):
 pa=b(a);pb=b(z);d=pb-pa
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(pa+pb)/2)
 o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 for p in o.data.polygons:p.use_smooth=True
 return finish(o,name,role)
def ring(name,x,y,z,outer,inner,role='trim'):
 # Hollow mechanical ring around longitudinal engine/tool axis.
 verts=[];faces=[];steps=24
 for zz,rr in [(z-.08,outer),(z+.08,outer),(z+.08,inner),(z-.08,inner)]:
  verts.extend([(x+math.cos(i*math.tau/steps)*rr,y+math.sin(i*math.tau/steps)*rr,zz) for i in range(steps)])
 for k in range(4):
  for i in range(steps):faces.append((k*steps+i,k*steps+(i+1)%steps,((k+1)%4)*steps+(i+1)%steps,((k+1)%4)*steps+i))
 return mesh(name,verts,faces,role,.012)
def engine(x,y,end,radius,length):
 # Authored nozzle ends exactly at the frozen FX anchor, not beyond it.
 y=0.0
 rod('Engine_outer_shell',(x,y,end-length),(x,y,end-.25),radius,'dark',radius*.87,32)
 for f in [.15,.45,.73]:ring('Engine_compression_band',x,y,end-length*(1-f),radius*1.045,radius*.88,'trim')
 ring('Nozzle_outer_lip',x,y,end-.07,radius*.89,radius*.66,'hull')
 rod('Recessed_nozzle',(x,y,end-.22),(x,y,end-.18),radius*.69,'ceramic',vertices=24)
 rod('Idle_thrust_core',(x,y,end-.20),(x,y,end-.16),radius*.26,'glow',vertices=24)
 for i in range(12):
  a=i*math.tau/12
  rod('Nozzle_cooling_spoke',(x+math.cos(a)*radius*.35,y+math.sin(a)*radius*.35,end-.15),(x+math.cos(a)*radius*.65,y+math.sin(a)*radius*.65,end-.10),max(.025,radius*.024),'dark',vertices=8)
def hatch(pos,size=.75,axis='top'):
 x,y,z=pos
 if axis=='top':
  box('Service_hatch_frame',(size,.10,size*1.45),(x,y,z),'dark',.025)
  box('Service_hatch_plate',(size*.88,.07,size*1.30),(x,y+.08,z),'trim',.025)
  rod('Hatch_handhold',(x-size*.18,y+.16,z),(x+size*.18,y+.16,z),.032,'dark')
 else:
  side=-1 if x<0 else 1
  box('Airlock_frame',(.10,size*1.75,size),(x,y,z),'dark',.025)
  box('Airlock_door',(.07,size*1.60,size*.86),(x+side*.07,y,z),'trim',.02)
  rod('Airlock_grip',(x+side*.15,y-.18,z),(x+side*.15,y+.18,z),.03,'dark')
def windows(x,y,z,count=5,spacing=.43,side=False):
 for i in range(count):
  if side:box('Crew_scale_window',(.045,.21,.26),(x,y,z+i*spacing),'window',.012)
  else:box('Crew_scale_window',(.26,.21,.045),(x+(i-(count-1)/2)*spacing,y,z),'window',.012)
def radiator(x,y,z,width,height,length,count=12):
 box('Radiator_backbone',(width*.25,height,length),(x,y,z),'dark',.025)
 for i in range(count):box('Graphite_radiator_fin',(width,height,.065),(x,y,z-length/2+i*length/(count-1)),'ceramic',.015)
def rib_bridge(x0,x1,y,z0,z1,step=1.8):
 for yy in [y-.45,y+.45]:rod('Longitudinal_truss',(x0,yy,z0),(x0,yy,z1),.10,'dark');rod('Longitudinal_truss',(x1,yy,z0),(x1,yy,z1),.10,'dark')
 n=max(1,int((z1-z0)/step))
 for i in range(n+1):
  z=z0+i*(z1-z0)/n;rod('Cross_rib',(x0,y,z),(x1,y,z),.10,'trim')
  if i<n:rod('Diagonal_truss',(x0,y-.45,z),(x1,y+.45,z+(z1-z0)/n),.065,'dark')
def warning(x,y,z,side=False):
 for i in range(4):
  o=box('Restricted_area_mark',(.055,.19,.24) if side else (.24,.035,.19),(x,y,z+i*.34),'warning',0)
  if not side:o.rotation_euler.z=.5
def stencil(body,pos,size=.27,side=False):
 curve=bpy.data.curves.new('Hull_serial','FONT');curve.body=body;curve.size=size;curve.extrude=.001
 o=bpy.data.objects.new('Hull_serial',curve);bpy.context.collection.objects.link(o);o.location=b(pos)
 # Default text lies in Blender XY / Godot XZ. Side plane is readable along X.
 if side:o.rotation_euler=(math.pi/2,0,math.pi/2)
 o.data.materials.append(M['trim']);return o
def common_small_details(length,width,height,bridge_z,include_hatch=True):
 # Same human-sized parts across classes make large hulls read as large ships.
 if include_hatch:hatch((0,height*.32,bridge_z),min(1.4,width*.10))
 for side in [-1,1]:
  for z in [length*.04,length*.13]:
   box('RCS_bank',(.25,.18,.64),(side*width*.26,height*.18,z),'dark',.025)
   for zz in [-.18,.18]:rod('RCS_nozzle',(side*width*.275,height*.18,z+zz),(side*width*.29,height*.18,z+zz),.055,'ceramic',vertices=12)

def shuttle():
 segmented_shell('Commuter_pressure_hull',[(-8.6,2.5,1.5,.15,0),(-6.1,4.2,2.5,.10,0),(-3.8,5.6,3.5,.0,0),(1.2,6.1,3.9,0,0),(4.4,5.0,3.2,0,0),(5.4,2.6,2.4,0,0)],.10)
 segmented_shell('Raised_pilot_module',[(-6.2,2.25,.8,1.8,-.25),(-4.6,2.65,1.0,1.95,-.25),(-2.2,2.5,1.15,2.02,-.25)],.055)
 loft('Forward_glazing',[(-6.27,1.8,.28,1.88,-.25),(-6.18,1.8,.28,1.90,-.25)],'glass',.012)
 windows(-1.57,2.03,-4.7,4,.38,True)
 engine(-1.8,0,8.28,1.17,3.8);engine(1.8,0,8.28,1.17,3.8)
 for side in [-1,1]:
  rod('Aft_engine_guard',(side*3.4,-.45,5.8),(side*3.4,-.45,8.98),.04,'trim')
  rod('Engine_feed_line',(side*2.8,.9,3.2),(side*2.8,.9,6.4),.07,'dark')
  box('Docking_skid',(.45,.35,5.2),(side*1.8,-2.825,1.5),'dark',.04)
  rod('Skid_piston',(side*1.8,-1.25,-.8),(side*1.8,-2.65,-.8),.11,'trim')
  rod('Skid_piston',(side*1.8,-1.25,3.2),(side*1.8,-2.65,3.2),.11,'trim')
  for z in [-3.3,-.8,1.7]:box('Side_segment_armour',(.33,1.50,2.1),(side*3.02,-.2,z),'paint',.06)
 radiator(4.64,.25,1.5,.65,1.65,4.3,18)
 segmented_shell('Port_maintenance_pod',[(-1.1,1.8,1.30,-.1,-4.0),(1.2,1.94,1.65,-.1,-4.0),(3.7,1.6,1.30,-.1,-4.0)],.06)
 hatch((-4.78,-.1,1.2),.62,'side');warning(-4.965,-.35,1.7,True)
 rod('Antenna_mast',(.75,2.02,.8),(.75,2.97,.8),.025,'dark');rod('Antenna_tip',(.52,2.97,.8),(.98,2.97,.8),.025,'trim')
 box('Nose_fender',(1.8,.22,.4),(0,-.15,-8.8),'dark',.035)
 box('Defensive_mount',(.65,.34,1.2),(0,1,-7.40),'dark',.05)
 rod('Defensive_muzzle',(0,1,-7.65),(0,1,-8.0),.10,'trim')
 warning(1.95,1.93,.3);stencil('SW / 18  //  C-07',(-1.5,2.0,1.3),.23)
 common_small_details(18,10,6,2.8)

def miner():
 segmented_shell('Refinery_main_pressure_hull',[(-18,6.8,6,-1.7,0),(-12,10,8,-1.0,0),(0,11.2,9,-1.0,0),(10,11.2,9.2,-1.0,0),(18,5.6,6,-1.5,0),(22,4.4,5,-1.5,0)],.25)
 segmented_shell('Offset_control_bridge',[(4.0,5.7,2.4,5.4,5.0),(7.0,7,4.2,5.5,5.0),(13,6,4.0,5.5,5.0)],.16)
 windows(3.9,6.05,3.87,6,.55);windows(8.56,6.15,7,9,.56,True)
 for side in [-1,1]:
  engine(side*6.48,0,25.76,2.35,7.4)
  rib_bridge(side*7.8,side*17.8,-1.2,-23,17,4.0)
  box('Dock_frame_outrigger',(.42,.44,3.3),(side*17.79,-1.2,-26.35),'trim',.05)
  rod('Dock_frame_forward_connection',(side*17.79,-1.2,-24.8),(side*17.79,-1.2,-22.9),.12,'dark')
  rod('Tool_articulated_arm',(side*8.8,-2,-10),(side*12.4,-3,-14.2),.55,'dark')
  rod('Tool_arm_hydraulic',(side*9.3,-1.4,-10),(side*12.7,-2.4,-14.2),.17,'trim')
  rod('Mining_head_body',(side*13,-3,-13.8),(side*13,-3,-16.8),1.0,'hull',.73,24)
  ring('Tool_focus_assembly',side*13,-3,-16.88,.78,.47,'trim')
  rod('Tool_emitter',(side*13,-3,-16.98),(side*13,-3,-17.0),.43,'ceramic',vertices=24)
  warning(side*14,-2.9,-15.3,True)
  for y in [-4.0,-3.2,-2.4]:rod('Coolant_pipeline',(side*6.6,y,-5),(side*6.6,y,15),.13,'trim')
 # Asymmetric processing equipment: exposed port pressure vessels, enclosed starboard mill.
 for x,y,z,r,length in [(-12.1,.7,16,2.3,23),(-15.7,.2,12.0,1.65,18),(-10.6,4.1,13.0,1.55,15)]:
  rod('Pressure_separator_tank',(x,y,z-length),(x,y,z),r,'hull',r,32)
  for q in [.08,.32,.65,.9]:ring('Tank_reinforcement',x,y,z-length*(1-q),r*1.07,r*.95,'dark')
  rod('Tank_valve_pipe',(x,y+r,z-1),(x,y+r+.65,z-1),.12,'trim')
 segmented_shell('Starboard_mill_case',[(-9,8.8,5.6,.2,12),(0,10.8,6.8,.2,12),(14,10.1,6.2,.2,12)],.20)
 for z in [-6,-1,4,9]:
  hatch((12,3.73,z),1.1);box('Mill_access_plate',(.14,4.5,3.9),(17.6,.2,z),'paint',.05)
  for zz in [-1.2,0,1.2]:rod('Mill_heat_pipe',(17.8,-1.4,z+zz),(17.8,1.7,z+zz),.095,'trim')
 radiator(-5.5,6.0,2.0,3.1,2.4,11.0,24)
 box('Power_keel',(5.0,2.3,20),(0,-8.85,4),'dark',.12)
 for z in [-5,0,5,10]:rod('Keel_strut',(-2,-5,z),(-2,-8,z),.28,'trim');rod('Keel_strut',(2,-5,z),(2,-8,z),.28,'trim')
 rod('Bridge_antenna',(5,7.6,10),(5,9.97,10),.025,'dark');rod('Antenna_crossarm',(4.3,9.97,10),(5.7,9.97,10),.025,'trim')
 for side in [-1,1]:
  rod('Aft_service_rail',(side*9.8,-4,21),(side*9.8,-4,27.95),.05,'trim')
  box('Assembly_id_plate',(.07,.55,2.2),(side*17.95,1.8,2),'trim',.012)
  warning(side*17.96,.6,3,True)
 stencil('ANV 56 / INDUSTRIAL',(-2,3.61,3.8),.58)
 rod('Forward_defensive_pedestal',(0,1.0,-15),(0,5.0,-22.2),.28,'trim')
 box('Forward_defensive_housing',(1.4,.8,1.8),(0,5,-23.6),'dark',.09)
 rod('Defensive_muzzle',(0,5,-24.3),(0,5,-25),.20,'trim')
 hatch((5.0,7.68,11),1.2)
 common_small_details(56,36,20,12,False)

def contract_weapons(sid,scale=1):
 for key,p in GEO[sid]['hardpoints'].items():
  if not key.startswith('weapon_'):continue
  x,y,z=p
  box('Weapon_recessed_mount',(scale*1.4,scale*.75,scale*2.1),(x,y-.15*scale,z+2.1*scale),'dark',.06)
  rod('Weapon_barrel_breech',(x,y,z+2.4*scale),(x,y,z+.25*scale),scale*.20,'secondary',vertices=16)
  ring('Weapon_muzzle_vent',x,y,z+.09,scale*.21,scale*.13,'trim')
  rod('Weapon_aperture',(x,y,z+.015),(x,y,z),scale*.12,'ceramic',vertices=16)
  back=10.2 if sid=='cruiser_horizon' else 6.2
  drop=3.5 if sid=='cruiser_horizon' else 2.0
  rod('Weapon_load_bearing_spine',(x,y-scale*.6,z+1.8*scale),(x,y-scale*.6,z+back*scale),scale*.18,'dark')
  rod('Weapon_pedestal',(x,y-scale*drop,z+back*scale),(x,y-scale*.6,z+back*scale),scale*.22,'trim')
  for k in range(3):box('Weapon_recoil_cooling',(.10*scale,.65*scale,.09*scale),(x+.65*scale,y,z+(k+.7)*scale),'trim',.01)

def service_strip(x,y,z,count=5,step=2.2):
 for i in range(count):
  hatch((x,y,z+i*step),.70)
  if i%2==0:warning(x+1.05,y+.10,z+i*step)

def coupling(x,y,z,r,length):
 y=0.0
 rod('Reactor_feed_trunk',(x*.40,y,z-length),(x,y,z),r,'dark',vertices=16)
 rod('Engine_suspension',(x*.65,y+r*2,z-length*.6),(x,y+r*.9,z),r*.4,'trim')

def lantern():
 segmented_shell('Survey_pressure_hull',[(-9.5,2.8,2.1,0,0),(-5,4.8,3.8,-.2,0),(2,5.1,4,-.2,0),(7.0,3.8,3.4,-.2,0),(9.3,2.3,2.4,-.2,0)],.12)
 segmented_shell('Survey_control_house',[(1.5,3.3,1.4,2.0,-.3),(4.8,3.8,1.6,2.3,-.3),(6.8,3.0,1.4,2.2,-.3)],.07)
 windows(-.3,2.48,1.40,6,.38)
 for side in [-1,1]:
  segmented_shell('Forward_sensor_boom',[(-12.8,1.25,1.3,-.9,side*4.5),(-7,1.7,1.8,-.8,side*4.3),(4,1.4,1.5,-.9,side*4.3)],.085)
  rib_bridge(side*2.4,side*4.3,-.8,-6,3,2.0)
  box('Folded_sensor_array',(.22,2.4,3.2),(side*6.84,.5,-3),'secondary',.045)
  rod('Sensor_joint',(side*4.3,.2,-3),(side*6.5,.3,-3),.16,'dark')
  for z in [-4.1,-3.5,-2.9,-2.3]:rod('Sensor_trace',(side*6.99,-.55,z),(side*6.99,1.55,z),.012,'trim',vertices=8)
  engine(side*2.52,-.45,12.88,1.18,4.4);coupling(side*2.52,-.45,8.5,.17,2.2)
  radiator(side*3.5,-.9,5.8,1.05,1.3,3,12)
 box('Survey_navigation_keel',(1.5,.45,8),(0,-3.77,-.5),'dark',.03)
 rod('Keel_suspension',(0,-1.7,-3),(0,-3.5,-3),.13,'trim')
 rod('Keel_suspension',(0,-1.7,2),(0,-3.5,2),.13,'trim')
 rod('Top_antenna',(.45,3.2,4),(.45,3.95,4),.045,'dark')
 box('Fore_navigation_prow',(1.2,.35,1.7),(0,-.5,-13.13),'dark',.02)
 rod('Fore_probe_mast',(0,-.5,-12.4),(0,-.5,-9.1),.11,'dark')
 service_strip(0,1.93,-3,2,1.6);contract_weapons('frigate_lantern',.55)
 common_small_details(28,14,8,4,False)

def kestrel():
 segmented_shell('Combat_central_citadel',[(-10.7,2.8,3.0,-.2,0),(-6,6.4,5.4,-.1,0),(1,7.2,6,-.1,0),(6,5.7,4.8,-.2,0),(9.5,2.8,3.4,-.1,0)],.14)
 segmented_shell('Low_offset_bridge',[(-2,2.5,1.1,3.15,1.2),(1.8,3.3,1.5,3.25,1.2),(3.5,2.7,1.25,3.15,1.2)],.09)
 windows(1.2,3.33,-2.1,4,.41)
 for side in [-1,1]:
  segmented_shell('Armoured_gun_outrigger',[(-10.8,3.5,3.2,.1,side*6),(-5,4.0,4.0,0,side*6),(3,4.0,4,-.1,side*6),(6.8,2.7,2.8,-.1,side*5.5)],.15)
  rib_bridge(side*3.5,side*6,-.8,-4,4,2.5)
  box('Ammo_armour_magazine',(1.7,1.5,3.2),(side*7.8,-.5,-4),'paint',.06)
  radiator(side*7.6,-.65,2.1,2.7,1.8,3.5,17)
  engine(side*3.24,-.6,13.8,1.43,4.8);coupling(side*3.24,-.6,9.0,.22,3.0)
  rod('Outer_impact_rail',(side*8.88,-1.8,-8.5),(side*8.88,-1.8,4.8),.11,'trim')
  hatch((side*8.1,.2,-.4),.80,'side')
 box('Central_keel_skid',(2.2,.6,11),(0,-4.19,.6),'dark',.08)
 rod('Keel_suspension',(0,-2.2,-3),(0,-3.9,-3),.2,'trim');rod('Keel_suspension',(0,-2.2,4),(0,-3.9,4),.2,'trim')
 box('Battering_prow',(2.0,.42,3.9),(0,-.2,-13.03),'secondary',.08)
 rod('Prow_connection',(0,-.2,-11.2),(0,-.2,-10.3),.16,'dark')
 rod('IFF_blade',(-.9,2.85,3),(-.9,4.45,3),.045,'dark')
 contract_weapons('frigate_kestrel',.85);service_strip(0,2.98,-4,2,1.8)
 common_small_details(30,18,9,2,False)

def raptor():
 segmented_shell('Destroyer_longitudinal_citadel',[(-29,3.5,4,-.8,0),(-21,9.0,7,-.8,0),(-8,11,9,-.8,0),(9,10.5,8.8,-.8,0),(19,7.8,7,-1,0),(25,4,4,-1,0)],.24)
 segmented_shell('Raised_aft_command_tower',[(7.5,6,2.4,4.9,-1.8),(12,7,4.5,5.4,-1.8),(18,6.2,4.6,5.4,-1.8)],.16)
 windows(-2,5.5,7.35,9,.45);windows(1.85,6,11,9,.48,True)
 for side in [-1,1]:
  segmented_shell('Forward_weapon_battery',[(-24,5.6,3.9,2.25,side*7.2),(-15,6.8,4.7,1.7,side*7.8),(-5,5.3,3.8,.8,side*8.3)],.20)
  rib_bridge(side*4.6,side*8.0,-.3,-19,-5,3.1)
  radiator(side*10.5,-.1,5.5,5.6,4.6,15,35)
  engine(side*5.4,-1,32.2,2.8,10.4);coupling(side*5.4,-1,22,.45,5.4)
  box('Lateral_service_rail',(.25,.36,19),(side*14.8,-1.0,4.0),'dark',.03)
  rod('Radiator_frame',(side*8.0,-.4,-4),(side*14.8,-1,-4),.22,'trim')
  hatch((side*6.0,-.3,0),1.3,'side')
 segmented_shell('Forward_sensor_keel',[(-34.8,1.0,1.0,-1.9,0),(-25,2.8,2.0,-2.8,0),(-11,3.2,2.6,-4.9,0)],.14)
 box('Belly_power_carrier',(4.1,1.5,23),(0,-8.2,2),'dark',.10)
 for z in [-7,0,7,12]:rod('Keel_angled_strut',(2,-3,z),(2,-7.4,z),.25,'trim')
 rod('Array_antenna',(-2.2,7.8,13),(-2.2,8.95,13),.045,'dark')
 contract_weapons('destroyer_raptor',1.45);service_strip(0,3.8,-6,6,2.0)
 common_small_details(70,30,18,12,False)

def horizon():
 segmented_shell('Cruiser_center_spine',[(-48,7,6,-3,0),(-29,14,11,-2,0),(-8,15,14,-2,0),(14,12,12,-2,0),(32,7.2,7,-2,0),(42,4.4,5,-2,0)],.35)
 for side in [-1,1]:
  x=-19 if side<0 else 20
  sections=[(-40,7,7,-1,x),(-30,13,12,-1,x),(-8,14.4,14,-1,x),(18,13,13,-1,x),(34,7,8,-1,x)] if side<0 else [(-29,7,6,-2,x),(-20,16,13,-2,x),(6,17,14,-2,x),(25,10,9,-2,x),(31,6,6,-2,x)]
  segmented_shell('Offset_cruiser_pod',sections,.30)
  rib_bridge(side*6,side*19,-5,-19,18,6.0)
  radiator(side*26.6,-.5,10,6.5,9,20,34)
  engine(side*10.8,-2,52.9,4.2,16.5);coupling(side*10.8,-2,36.5,.65,8.0)
  for z in [-20,-8,4,16]:hatch((x,6.12 if side<0 else 5.13,z),1.2)
 segmented_shell('Cruiser_raised_bridge',[(7,6,3,10,7),(14,8,6,10,7),(24,8.6,6.2,10,7),(28,5.5,4,10,7)],.20)
 windows(6.8,10.5,6.8,12,.49);windows(11.45,10.8,14,14,.51,True)
 rod('Bridge_forward_truss',(7,3,10),(7,8.3,10),.60,'trim');rod('Bridge_aft_truss',(7,3,24),(7,8.3,24),.60,'trim')
 rod('Cruiser_tower_array',(7,13.2,20),(7,16.95,20),.045,'dark')
 box('Navigation_keel',(4,1.0,19),(0,-16.4,7),'dark',.08)
 for z in [0,7,14]:rod('Navigation_keel_mount',(0,-8,z),(0,-16,z),.25,'trim')
 box('Cruiser_front_ranging_probe',(1.5,1.2,7.2),(0,-3,-53.7),'dark',.08)
 rod('Cruiser_ranging_probe_support',(0,-3,-50.3),(0,-3,-47.0),.30,'trim')
 contract_weapons('cruiser_horizon',2.0)
 service_strip(0,5.05,-17,8,3.0);common_small_details(115,60,34,20,False)

def bastion():
 segmented_shell('Battleship_primary_spine',[(-86,12,14,-6,0),(-61,33,28,-3,0),(-18,38,31,-3,0),(27,34,29,-3,0),(64,18,19,-5,0),(84,10,12,-5,0)],.65)
 for side in [-1,1]:
  # Three separated armoured compartments and exposed service corridors.
  for z0,z1,x,w,h in [(-80,-40,side*32,25,21),(-34,18,side*35,28,27),(25,62,side*30,23,24)]:
   segmented_shell('Battleship_spaced_armour',[ (z0,w*.73,h*.82,-2,x),(z0+9,w,h,-2,x),(z1-6,w,h,-2,x),(z1,w*.76,h*.85,-2,x)],.55)
   rib_bridge(side*16,x,-8,z0+8,z1-5,8.0)
   for z in range(int(z0+11),int(z1-8),7):hatch((x,-2+h/2+.14,z),1.3)
  radiator(side*47,-4,31,15,18,31,48)
  rod('External_armour_rail',(side*54.8,-8,-37),(side*54.8,-8,54),.17,'dark')
  engine(side*19.8,-6,101.2,8.2,25);coupling(side*19.8,-6,77.0,1.4,17)
  for y in [-10,-7,-4]:rod('Main_reactor_coolant',(side*11,y,27),(side*11,y,73),.45,'trim')
 segmented_shell('Offset_battleship_superstructure',[(16,10,5,17,-10),(28,15,10,20,-10),(45,16,11,20,-10),(57,11,9,20,-10)],.32)
 for y in [18.5,20.2,21.9]:windows(-10,y,15.8,18,.48);windows(-1.85,y,29,26,.50,True)
 rod('Tower_pylon',(-10,26,41),(-10,32.45,41),.05,'dark')
 box('Battleship_power_keel',(12,4.0,68),(0,-30.4,7),'dark',.18)
 for z in [-19,0,19,38]:rod('Keel_support',(-4,-16,z),(-4,-28.5,z),.8,'trim');rod('Keel_support',(4,-16,z),(4,-28.5,z),.8,'trim')
 segmented_shell('Armoured_forward_ram',[(-109.7,3.0,3.5,-8,0),(-91,6,7,-9,0),(-76,9,10,-9,0)],.30)
 for x in [-21,0,21]:service_strip(x,13.0,-24,9,5.0)
 contract_weapons('battleship_bastion',3.8);common_small_details(220,110,65,40,False)

def cargo_frame(x,y,z,width,height,length,role='paint'):
 segmented_shell('Intermodal_cargo_pressure_box',[(z-length/2,width*.92,height*.93,y,x),(z-length/2+.7,width,height,y,x),(z+length/2-.7,width,height,y,x),(z+length/2,width*.92,height*.93,y,x)],.28)
 for yy in [y-height/2-.18,y+height/2+.18]:
  for xx in [x-width/2-.18,x+width/2+.18]:rod('Container_corner_casting',(xx,yy,z-length/2),(xx,yy,z+length/2),.13,'trim')
 for zz in [z-length/2+.9,z+length/2-.9]:
  box('Cargo_lock_strap',(width+.6,.22,.35),(x,y+height/2+.26,zz),'dark',.02)
 box('Container_number_patch',(.06,1.1,2.4),(x+width/2+.025,y,z),'paint',.015)

def caravan():
 segmented_shell('Freighter_narrow_pressure_spine',[(-62,4,6,-3,0),(-42,8,9,-2,0),(28,9,10,-2,0),(48,5,7,-3,0)],.32)
 # Cargo dimensions, deck levels, and voids differ from the mining refinery.
 for side in [-1,1]:
  rib_bridge(side*5,side*33.5,-5,-49,44,10)
  if side<0:
   for z in [-34,-3,28]:cargo_frame(-22,-2,z,18,18,26)
   for z in [-25,9]:cargo_frame(-20,15,z,15,14,29)
  else:
   for z in [-30,12]:
    for x in [16,28]:
     rod('Bulk_gas_transport',(x,-1,z-15),(x,-1,z+15),5.3,'secondary',vertices=32)
     for q in [-13,-4,5,13]:ring('Gas_tank_cradle',x,-1,z+q,5.6,5.1,'dark')
   cargo_frame(21,13,28,18,12,24)
  engine(side*13.5,-2,66.7,6.3,18.5);coupling(side*13.5,-2,48.5,.85,12)
  rod('Freighter_outer_safety_rail',(side*37.25,-9,-47),(side*37.25,-9,44),.14,'trim')
  rod('Cargo_detachable_crossbeam',(side*7,-7,-44),(side*37.25,-7,-44),.14,'dark')
 segmented_shell('Freighter_aft_control_bridge',[(33,5,3,16,9),(38,8,5,16,9),(45,8,5,16,9)],.20)
 windows(9,16.4,32.8,11,.5);rod('Freighter_bridge_suspension',(9,4,39),(9,13.5,39),.6,'trim')
 rod('Cargo_alignment_mast',(9,18.6,41),(9,23.8,41),.06,'dark')
 box('Freighter_docking_keel',(6,2.5,30),(0,-22.73,7),'dark',.12)
 for z in [-6,7,20]:rod('Docking_keel_strut',(0,-7,z),(0,-21,z),.45,'trim')
 box('Freighter_fore_ranging_probe',(2,1.2,8),(0,-3,-68.4),'dark',.05)
 rod('Freighter_probe_support',(0,-3,-64.6),(0,-3,-61.0),.28,'trim')
 rod('Freighter_defence_pylon',(0,1.7,-46.63),(0,9.6,-46.63),.40,'dark')
 contract_weapons('transport_caravan',1.6);service_strip(0,3.16,-34,9,4.3)
 common_small_details(145,75,48,40,False)

def weaver():
 segmented_shell('Maintenance_pressure_spine',[(-31,6,5,-1,0),(-21,11,10,-1,0),(3,13,12,-1,0),(21,8.5,9,-1,0),(31,5,5,-1,0)],.30)
 for side in [-1,1]:
  segmented_shell('Outboard_service_laboratory',[(-20,8,6,-3,side*21),(-13,12,10,-3,side*21),(8,12,10,-3,side*21),(21,8,7,-3,side*21)],.25)
  rib_bridge(side*6.2,side*21,-5,-10,15,5)
  for z in [-11,-4,3,10]:box('Laboratory_ceramic_patch',(6,.12,3.3),(side*21,2.13,z),'ceramic',.025);hatch((side*24,-1,z),1.2,'side')
  rod('Repair_articulated_boom',(side*21,-4,-17),(side*15.6,-4.2,-23.4),.7,'trim')
  rod('Repair_field_projector',(side*15.6,-4.2,-23.1),(side*15.6,-4.2,-25.1),.65,'secondary',vertices=24)
  ring('Repair_projector_tip',side*15.6,-4.2,-25.13,.68,.40,'trim')
  radiator(side*28.4,-2,9,7.6,6.0,12,27)
  engine(side*11.7,-1,41.4,3.5,11.4);coupling(side*11.7,-1,30.5,.6,7)
  rod('Support_forward_weapon_boom',(side*4.5,1,-21),(side*11.7,3,-25.18),.42,'dark')
  rod('Support_boom_hydraulic',(side*4.0,2,-20),(side*11.7,5.0,-25.18),.16,'trim')
 segmented_shell('Support_bridge',[(2,4,2.3,8,0),(9,6,4,8,0),(16,5.5,3.8,8,0)],.14)
 windows(0,8.5,1.82,10,.49);rod('Service_radio',(1.5,10,13),(1.5,13.95,13),.05,'dark')
 rod('Center_repair_bus',(0,-4,-19),(0,-4.2,-25.15),.65,'dark');ring('Center_service_tip',0,-4.2,-25.13,.68,.40,'trim')
 rod('Service_crane_column',(-5,3,4),(-5,7.5,4),.38,'trim');rod('Service_crane_jib',(-5,7.5,4),(-16,7.5,-3),.27,'trim');rod('Crane_cable',(-16,7.3,-3),(-16,1,-3),.035,'dark')
 box('Support_recovery_keel',(3.8,1.2,23),(0,-13.3,5),'dark',.08)
 for z in [-4,4,12]:rod('Recovery_keel_mount',(0,-6,z),(0,-12.7,z),.25,'trim')
 box('Service_forward_alignment_probe',(2.0,.7,7),(0,-1,-41.35),'dark',.04)
 rod('Service_alignment_mast',(0,-1,-38.1),(0,-1,-30.5),.30,'dark')
 contract_weapons('support_weaver',1.6);service_strip(0,5.14,-10,6,2.5)
 common_small_details(90,65,28,11,False)

def silent():
 # Uncrewed ceramic/graphite articulated relic: a void through the center,
 # off-axis ribbed chassis and compact apertures rather than luminous wings.
 for side in [-1,1]:
  segmented_shell('Relic_split_chassis',[(-12,3.5,3.8,1.0,side*6.7),(-6,6.8,7,1.2,side*7.8),(5,5.5,6.3,.8,side*7.3),(11,3.2,3.7,.8,side*5.8)],.18)
  for z in [-7,-3,1,5]:
   rod('Relic_diagonal_rib',(side*3.2,-3,z),(side*13.8,-1,z+1.8),.13,'secondary')
   box('Relic_ceramic_spline',(1.4,4.8,2.5),(side*10.9,.5,z),'ceramic',.07)
  radiator(side*12.2,-2,3,3.1,3.8,8,17)
  engine(side*5.04,-.5,13.8,1.65,5)
  rod('Relic_lower_claw',(side*7,-2,-8),(side*4.8,-9.8,-13),.13,'trim')
  rod('Relic_upper_sensor',(side*7,4,3),(side*4.4,9.8,6),.13,'secondary')
 for z in [-4,1,6]:rod('Relic_cross_lattice',(-6,-3,z),(6,-3,z),.20,'dark')
 ring('Relic_recessed_processor',0,-3,4.5,2.5,1.8,'ceramic')
 rod('Relic_navigation_needle',(0,-3,2),(0,-3,-14.8),.06,'dark')
 contract_weapons('enemy_silent',.90)

BUILDERS={'shuttle_swift':shuttle,'frigate_lantern':lantern,'frigate_kestrel':kestrel,'miner_anvil':miner,'destroyer_raptor':raptor,'cruiser_horizon':horizon,'battleship_bastion':bastion,'transport_caravan':caravan,'support_weaver':weaver,'enemy_silent':silent}

def export(ship_id):
 for obj in list(bpy.context.scene.objects):
  if obj.type in ['MESH','FONT']:
   bpy.context.view_layer.objects.active=obj;obj.select_set(True)
   if obj.type=='FONT':bpy.ops.object.convert(target='MESH');obj=bpy.context.view_layer.objects.active
   # Apply shared machined-edge modifiers after merging material groups. This
   # avoids reevaluating thousands of independent objects per plate modifier.
   obj.modifiers.clear()
   obj.select_set(False)
 # Check the visual envelope; never clamp/crush faces to force a passing box.
 dims=GEO[ship_id];limit=Vector((dims['width_m']/2,dims['length_m']/2,dims['height_m']/2))
 for obj in bpy.context.scene.objects:
  if obj.type!='MESH':continue
  for v in obj.data.vertices:
   point=obj.matrix_world@v.co
   assert all(abs(point[i])<=limit[i]+.025 for i in range(3)),f'{ship_id}: {obj.name} outside visual envelope {list(point)}'
 groups={}
 for obj in bpy.context.scene.objects:
  if obj.type=='MESH':groups.setdefault(obj.data.materials[0].name,[]).append(obj)
 for name,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  if len(objects)>1:bpy.ops.object.join()
  bpy.context.object.name=name
  merged=bpy.context.object
  bevel=merged.modifiers.new('Machined_chamfer','BEVEL');bevel.width=.024;bevel.segments=1
  normals=merged.modifiers.new('Weighted_surface_normals','WEIGHTED_NORMAL');normals.keep_sharp=True
  for modifier in list(merged.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/(ship_id+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(ship_id+'.glb')),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
 triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
 print('INDUSTRIAL_HULL',ship_id,'surfaces',len(groups),'triangles',triangles)

requested=['shuttle_swift','miner_anvil']
if '--all' in sys.argv:requested=SHIPS
if '--ship' in sys.argv:requested=[sys.argv[sys.argv.index('--ship')+1]]
if '--ships' in sys.argv:requested=sys.argv[sys.argv.index('--ships')+1].split(',')
for sid in requested:
 reset(GEO[sid]['faction_style'])
 BUILDERS[sid]()
 export(sid)
