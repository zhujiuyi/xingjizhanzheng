"""Original exhibition hangar and four articulated service crew; Blender 4.5.
Only presentation geometry. No ship balance, collision or frozen asset changes.
"""
from pathlib import Path
import math, json
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'code/assets/hangar_v2'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'source').mkdir(exist_ok=True)
(OUT/'source/.gdignore').write_text('',encoding='utf-8')
bpy.context.preferences.filepaths.save_version=0
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def b(v):return Vector((v[0],-v[2],v[1]))
def material(name,color,metal=0,rough=.65,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
 p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
M={
 'metal':material('Hangar_Brushed_Metal',(.20,.26,.30),.72,.65),
 'dark':material('Hangar_Recess_Metal',(.042,.065,.078),.68,.8),
 'pale':material('Hangar_Trim_Metal',(.44,.54,.60),.72,.4),
 'yellow':material('Hangar_Safety_Amber',(.9,.49,.09),.35,.55),
 'cyan':material('Hangar_Light_Cyan',(.08,.66,.85),.2,.35,3),
 'warm':material('Hangar_Light_Warm',(.9,.58,.25),.1,.4,2),
 'screen':material('Crew_Screen_Blue',(.022,.20,.29),.15,.4,.65),
 'rubber':material('Crew_Boots',(.018,.024,.029),.05,.88),
 'skin':material('Crew_Warm_Skin',(.49,.31,.23),0,.74),
 'skin_light':material('Crew_Light_Skin',(.68,.47,.34),0,.7),
 'hair':material('Crew_Hair',(.028,.018,.014),0,.85),
 'grey_hair':material('Crew_Research_Grey_Hair',(.22,.25,.24),0,.88),
 'eyes':material('Crew_Eyes',(.64,.68,.67),0,.28),
 'blue':material('Crew_Operations_Navy',(.055,.14,.24),.12,.72),
 'orange':material('Crew_Industry_Orange',(.59,.20,.045),.05,.83),
 'white':material('Crew_Research_Coat',(.64,.73,.75),.02,.7),
 'green':material('Crew_Supply_Olive',(.17,.28,.21),.05,.83),
}
def finish(obj,name,mat,parent=None):
 obj.name=name;obj.data.materials.append(M[mat])
 if parent:
  world=obj.matrix_world.copy();obj.parent=parent;obj.matrix_world=world
 return obj
def box(name,size,pos,mat='metal',bevel=.05,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=b(pos));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Rounded_fabric_or_machined_edge','BEVEL');mod.width=min(bevel,min(size)*.22);mod.segments=2
  mod=o.modifiers.new('Weighted_normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 return finish(o,name,mat,parent)
def ball(name,size,pos,mat='metal',parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=b(pos));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 return finish(o,name,mat,parent)
def tailored_torso(role,suit):
 shoulder=.22 if role in ['operations','industry'] else .24
 waist=.17 if role in ['operations','industry'] else .19
 vertices=[b((x,y,z)) for y,w,d in [(1.0,waist,.13),(1.50,shoulder,.145)] for x,z in [(-w,-d),(w,-d),(w,d),(-w,d)]]
 data=bpy.data.meshes.new('Tailored_jacket_form');data.from_pydata(vertices,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]);data.update()
 obj=bpy.data.objects.new('Tailored_jacket_form',data);bpy.context.collection.objects.link(obj)
 modifier=obj.modifiers.new('Seamed_fabric_edges','BEVEL');modifier.width=.065;modifier.segments=3
 modifier=obj.modifiers.new('Soft_jacket_normals','WEIGHTED_NORMAL');modifier.keep_sharp=True
 return finish(obj,'Tailored_jacket_form',suit)
def rod(name,start,end,radius,mat='metal',parent=None,radius2=None):
 a=b(start);z=b(end);d=z-a
 bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=radius,radius2=radius if radius2 is None else radius2,depth=d.length,location=(a+z)/2)
 o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 for p in o.data.polygons:p.use_smooth=True
 return finish(o,name,mat,parent)
def pivot(name,pos):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=b(pos);return o
def text(name,body,size,pos,mat='pale',floor=False):
 c=bpy.data.curves.new(name,'FONT');c.body=body;c.size=size;c.extrude=.004;c.align_x='CENTER'
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.location=b(pos)
 if not floor:o.rotation_euler=(math.pi/2,0,0)
 o.data.materials.append(M[mat]);return o
def export(name,merge=False,rigid_groups=False):
 bpy.ops.object.select_all(action='DESELECT')
 for obj in list(bpy.context.scene.objects):
  if obj.type in ['MESH','FONT']:
   bpy.context.view_layer.objects.active=obj;obj.select_set(True)
   if obj.type=='FONT':bpy.ops.object.convert(target='MESH');obj=bpy.context.view_layer.objects.active
   for modifier in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
   obj.select_set(False)
 if merge or rigid_groups:
  groups={}
  for obj in bpy.context.scene.objects:
   if obj.type=='MESH' and obj.data.materials:
    key=(obj.parent.name if obj.parent and rigid_groups else '',obj.data.materials[0].name)
    groups.setdefault(key,[]).append(obj)
  for (parent_name,mat_name),objects in groups.items():
   for obj in objects:obj.select_set(True)
   bpy.context.view_layer.objects.active=objects[0]
   if len(objects)>1:bpy.ops.object.join()
   bpy.context.object.name=(parent_name+'_' if parent_name else '')+mat_name
   bpy.ops.object.select_all(action='DESELECT')
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False)
 print('HANGAR_ASSET',name,'objects',len(bpy.context.scene.objects),'faces',sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'))

reset()
# Open camera-facing cutaway; front/right foreground walls are deliberately absent.
box('Foundation',(76,1.2,64),(0,-.7,0),'dark')
for x in range(-32,33,8):
 for z in range(-28,29,8):box('Deck_panel',(7.87,.22,7.87),(x,-.05,z),'metal',.04)
for x in [-14,14]:
 box('Repair_track',(1.1,.28,56),(x,.15,-2),'dark')
 box('Track_edge_light',(.07,.04,56),(x+.54,.33,-2),'cyan',0)
 for z in range(-26,25,4):box('Track_stop',(.7,.24,.42),(x,.42,z),'pale')
box('Elevated_dock_plinth',(30,.9,34),(0,.45,-5),'dark',.18)
box('Dock_top_inlay',(28,.12,32),(0,.94,-5),'metal',.08)
for side in [-1,1]:
 box('Dock_outline',(.16,.05,31),(side*14.2,1.03,-5),'cyan',0)
 for z in range(-18,10,2):
  o=box('Warning_chevron',(1.25,.06,.4),(side*13.1,1.04,z),'yellow',0);o.rotation_euler.z=-.65
text('Deck_stencil','DOCK 07',2.3,(0,.995,9),'pale',True)
text('Deck_limits','STAND CLEAR  /  AUTHORIZED CREW',.55,(0,.18,23),'yellow',True)
for z in [-27,-13,1,15]:
 box('Left_wall_rib',(1.6,27,1.5),(-36,13,z),'dark',.1)
 box('Left_wall_panel',(.65,23,11.8),(-36.8,12,z),'metal',.12)
 box('Wall_vertical_light',(.1,13,.15),(-35,12,z),'cyan',0)
 box('Left_maintenance_window',(.4,3.6,7),(-35.9,6,z),'dark',.08)
 for n in range(6):box('Vent_slats',(.14,.12,5.8),(-35.63,4.8+n*.43,z),'pale',0)
# Back pressure bulkhead frames a real star-window opening.
for x in [-29,29]:box('Back_bulkhead_side',(18,27,1.8),(x,13,-33),'metal',.15)
box('Back_bulkhead_bottom',(40,7,1.8),(0,3,-33),'metal',.1)
box('Back_bulkhead_top',(76,4.3,2.2),(0,26,-33),'dark',.15)
for x in [-20.5,20.5]:box('Viewport_vertical_frame',(.55,18,1),(x,16,-31.8),'pale',.07)
for y in [7.2,24.8]:box('Viewport_horizontal_frame',(41.5,.6,1),(0,y,-31.8),'pale',.07)
for x in [-35,35]:
 for z in [-29,-15]:box('Structural_pylon',(1.7,26,1.7),(x,13,z),'dark',.12)
for z in [-27,-12,2]:
 box('Ceiling_crossbeam',(72,1.4,1.3),(0,26,z),'dark',.08)
 for x in [-27,-9,9,27]:box('Overhead_light',(7,.16,.36),(x,25.15,z),'warm',.02)
text('Port_header','ANCHOR  //  SERVICE BAY 07',1.15,(0,26,-31.6),'cyan')
# Overhead crane, cable and suspended fork stay away from the ship silhouette.
box('Crane_rail',(54,1,1.2),(-4,24,-10),'yellow')
box('Crane_trolley',(3.5,1.8,3),(-17,23,-10),'dark')
rod('Crane_cable',(-17,22,-10),(-17,12,-10),.08,'pale')
box('Crane_spreader',(5,.45,1.4),(-17,12,-10),'yellow')
for x in [-19,-15]:rod('Fork', (x,12,-10),(x,10,-10),.15,'pale')
# Service desks in the near walkway make humanoid detail visible in normal framing.
POSITIONS={'operations':(-18,14),'industry':(-6,18),'research':(8,17),'supplies':(21,12)}
for role,(x,z) in POSITIONS.items():
 box(role+'_desk',(3.8,1.1,1.65),(x,.58,z-1.0),'dark',.1)
 box(role+'_desk_top',(4,.2,1.85),(x,1.2,z-1.0),'metal',.05)
 box(role+'_terminal_base',(.9,.18,.75),(x+.8,1.35,z-1),'pale')
 o=box(role+'_monitor',(.9,.55,.08),(x+.8,1.65,z-1.1),'screen',.03);o.rotation_euler.x=-.22
 box(role+'_service_strip',(3.6,.05,.12),(x,1.35,z-.12),'cyan' if role in ['operations','research'] else 'warm',0)
 text(role+'_sign',role.upper(),.35,(x,1.0,z-.13),'pale')
for x,z in [(-28,17),(-29,21),(29,-20),(29,-24),(24,19)]:
 box('Cargo_crate',(2.1,1.7,1.8),(x,.85,z),'metal',.08)
 for dx in [-.82,.82]:box('Crate_bands',(.12,1.75,1.84),(x+dx,.86,z),'dark',.02)
 box('Crate_ID_plate',(.75,.38,.035),(x,.98,z+.92),'yellow',.02)
export('hangar_environment',True)

def human(role):
 reset();suit={'operations':'blue','industry':'orange','research':'white','supplies':'green'}[role]
 skin='skin_light' if role=='research' else 'skin'
 box('Pelvis',(.41,.23,.29),(0,.9,0),suit,.08)
 tailored_torso(role,suit)
 box('Suit_front_panel',(.27,.38,.027),(0,1.26,.14),'dark' if role=='industry' else suit,.035)
 box('Collar',(.25,.055,.30),(0,1.52,0),'pale',.015)
 rod('Neck',(0,1.48,0),(0,1.65,0),.072,skin)
 head=pivot('HeadPivot',(0,1.76,0))
 ball('Head',(.116 if role in ['operations','industry'] else .124,.158,.106),(0,1.77,0),skin,head)
 hair='grey_hair' if role=='research' else 'hair'
 ball('Hair_back',(.122,.11,.089),(0,1.851,-.026),hair,head)
 for x in [-.123,.123]:ball('Ear',(.02,.042,.021),(x,1.77,0),skin,head)
 ball('Nose',(.020,.039,.032),(0,1.757,.108),skin,head)
 box('Mouth',(.053,.009,.012),(0,1.709,.105),'hair',.003,head)
 for x in [-.044,.044]:
  ball('Eye_white',(.023,.013,.012),(x,1.803,.09),'eyes',head)
  ball('Eye_pupil',(.008,.009,.006),(x,1.803,.103),'hair',head)
  box('Eyebrow',(.051,.010,.014),(x,1.824,.106),'hair',.003,head)
 for side in [-1,1]:
  x=side*.115
  rod('Upper_leg',(x,.90,0),(x*1.35,.51,.035),.095,suit,radius2=.076)
  ball('Knee_pad',(.072,.085,.048),(x*1.35,.51,.09),'dark')
  rod('Lower_leg',(x*1.35,.51,.035),(x*1.43,.14,.01),.075,suit,radius2=.058)
  box('Boot',(.19,.15,.31),(x*1.43,.075,.072),'rubber',.045)
  shoulder=(side*.24,1.46,0);elbow=(side*.38,1.19,.09 if role!='industry' else .19)
  hand=(side*.26,1.16,.34) if role in ['operations','supplies'] else (side*.39,1.05,.33)
  arm=pivot('LeftArmPivot' if side<0 else 'RightArmPivot',shoulder)
  ball('Shoulder_seam',(.083,.092,.083),shoulder,suit,arm)
  rod('Upper_arm',shoulder,elbow,.08,suit,arm,radius2=.065)
  ball('Elbow',(.056,.055,.056),elbow,suit,arm)
  rod('Forearm',elbow,hand,.065,suit,arm,radius2=.05)
  box('Gloved_hand',(.10,.13,.105),hand,'dark' if role=='industry' else skin,.025,arm)
  for finger in range(3):
   box('Finger',(.022,.052,.06),(hand[0]+(finger-1)*.028,hand[1]-.06,hand[2]+.01),'rubber' if role=='industry' else skin,.005,arm)
 box('Belt',(.43,.067,.32),(0,.973,0),'rubber',.018)
 box('Belt_buckle',(.083,.06,.035),(0,.974,.178),'pale',.01)
 box('Crew_badge',(.085,.08,.035),(-.105,1.41,.171),'cyan' if role in ['operations','research'] else 'yellow',.009)
 if role=='operations':
  ball('Tied_hair',(.08,.085,.095),(0,1.78,-.16),'hair',head)
  box('Epaulet_left',(.12,.025,.25),(-.19,1.505,0),'pale',.015)
  box('Epaulet_right',(.12,.025,.25),(.19,1.505,0),'pale',.015)
  box('Station_cap',(.25,.065,.25),(0,1.915,-.015),'blue',.03,head)
  box('Cap_peak',(.27,.02,.12),(0,1.895,.11),'dark',.008,head)
  o=box('Command_tablet',(.44,.24,.025),(0,1.16,.41),'screen',.025);o.rotation_euler.x=-.45
 elif role=='industry':
  ball('Hardhat_shell',(.155,.086,.14),(0,1.925,0),'yellow',head)
  box('Hardhat_brim',(.33,.028,.31),(0,1.895,.015),'yellow',.02,head)
  box('Safety_goggles',(.26,.06,.04),(0,1.80,.115),'screen',.02,head)
  for x in [-.14,.14]:box('Harness_strap',(.065,.48,.04),(x,1.25,.186),'yellow',.009)
  rod('Held_service_wrench',(.40,.97,.37),(.40,1.23,.37),.025,'pale')
  box('Wrench_open_end',(.13,.10,.045),(.4,1.27,.37),'pale',.012)
 elif role=='research':
  for x in [-.11,.11]:
   rod('Grey_sideburn',(x,1.82,.03),(x,1.72,.08),.023,'grey_hair',head)
   rod('Cheek_crease',(x,1.724,.099),(x*.8,1.704,.119),.003,'hair',head)
  for x in [-.16,.16]:box('Coat_tails',(.18,.32,.30),(x,.91,-.015),'white',.025)
  for x in [-.044,.044]:box('Optics_frame',(.079,.055,.029),(x,1.803,.114),'pale',.012,head)
  rod('Optics_bridge',(-.01,1.80,.17),(.01,1.80,.17),.009,'dark',head)
  box('Research_notepad',(.36,.06,.28),(.16,1.10,.35),'screen',.022)
  for y in [1.03,1.16,1.29]:box('Lab_closure',(.02,.02,.03),(0,y,.18),'dark',.004)
 else:
  box('Cargo_vest',(.40,.40,.07),(0,1.27,.184),'green',.03)
  for x in [-.12,.12]:box('Vest_pocket',(.15,.13,.04),(x,1.18,.232),'dark',.018)
  box('Supply_cap',(.26,.055,.25),(0,1.920,-.01),'green',.022,head)
  box('Carried_case',(.55,.28,.24),(0,1.13,.43),'yellow',.025)
  for x in [-.17,.17]:box('Case_strap',(.045,.28,.245),(x,1.13,.43),'dark',.006)
 export('crew_'+role,rigid_groups=True)
for role in POSITIONS:human(role)
reset()
box('Drone_hull',(.8,.35,.9),(0,0,0),'metal',.09)
box('Drone_sensor',(.27,.16,.10),(0,.07,.46),'screen',.02)
for x in [-.52,.52]:
 box('Drone_drive',(.2,.32,.6),(x,0,0),'dark',.06)
 ball('Drone_glow',(.11,.055,.15),(x,-.16,0),'cyan')
export('service_drone',True)
(OUT/'layout.json').write_text(json.dumps({'asset_version':'hangar-v2','units':'exhibition_metres','exhibition_only':True,'world_offset_y':15000,'camera_position':[36,26,36],'camera_target':[0,5,-2],'camera_fov_deg':49,'showcase_position':[0,7,-5],'showcase_length_m':26,'showcase_yaw_deg':170,'crew_positions':{k:[v[0],0,v[1]+.7] for k,v in POSITIONS.items()}},indent=2),encoding='utf-8')
