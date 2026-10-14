"""Deterministic original ship modelling primitives, run inside Blender 4.5 LTS.

Design coordinates are fractions of the existing width / height / length.
Godot forward is -Z. This file contains presentation geometry, no balance data.
"""
from pathlib import Path
import bpy, bmesh, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree


class Hull:
    def __init__(self, ship_id, geometry, faction):
        self.ship_id, self.geo, self.faction = ship_id, geometry, faction
        self.dim = Vector((geometry['width_m'], geometry['height_m'], geometry['length_m']))
        self.serial = 0
        self.structural_meshes = []
        self.mount_connections = {}
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
        palettes = {
            'council': ((.21,.235,.25), (.56,.51,.38), (.055,.10,.11)),
            'forge': ((.14,.155,.17), (.34,.29,.22), (.18,.025,.012)),
            'roaming': ((.20,.175,.14), (.38,.32,.24), (.065,.095,.04)),
            'silent': ((.115,.13,.145), (.31,.34,.36), (.09,.16,.18)),
        }
        hull, trim, paint = palettes[faction]
        self.materials = {}
        for role, color, metal, rough, emit in [
            ('hull',hull,.86,.36,0), ('trim',trim,.94,.28,0),
            ('paint',paint,0,.55,0), ('dark',(.034,.042,.05),.48,.73,0),
            ('secondary',tuple(v*.65 for v in hull),.80,.47,0),
            ('ceramic',(.027,.033,.038),0,.84,0),
            ('glass',(.014,.03,.041),0,.13,0),
            ('window',(.60,.68,.65) if faction=='council' else (.72,.42,.17),0,.5,.7),
            ('glow',(.18,.48,.62) if faction!='forge' else (.70,.36,.13),0,.5,1.8),
            ('warning',(.50,.32,.055),0,.58,0),
        ]:
            mat=bpy.data.materials.new(f'v4_{faction}_{role}'); mat.use_nodes=True
            p=mat.node_tree.nodes.get('Principled BSDF')
            p.inputs['Base Color'].default_value=(*color,1)
            p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
            p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emit
            self.materials[role]=mat

    def point(self, p):
        x,y,z=(float(p[i])*self.dim[i] for i in range(3))
        return Vector((x,-z,y))

    def mesh(self, name, vertices, faces, role='hull', smooth=False):
        data=bpy.data.meshes.new(name)
        data.from_pydata([self.point(p) for p in vertices],[],faces);data.update()
        bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
        bm.to_mesh(data);bm.free()
        for face in data.polygons:face.use_smooth=smooth
        self.serial+=1
        obj=bpy.data.objects.new(f'{name}_{self.serial:03}',data)
        bpy.context.collection.objects.link(obj);obj.data.materials.append(self.materials[role])
        return obj

    def loft(self,name,sections,role='hull',roundness=.28,smooth=False):
        """Closed octagonal loft; sections=(z, width, height, center_y, center_x)."""
        verts=[]
        for z,w,h,y,x in sections:
            r=roundness
            verts.extend([(x-w*.5,y-h*(.5-r),z),(x-w*(.5-r),y-h*.5,z),
                          (x+w*(.5-r),y-h*.5,z),(x+w*.5,y-h*(.5-r),z),
                          (x+w*.5,y+h*(.5-r),z),(x+w*(.5-r),y+h*.5,z),
                          (x-w*(.5-r),y+h*.5,z),(x-w*.5,y+h*(.5-r),z)])
        faces=[tuple(range(7,-1,-1)),tuple(range((len(sections)-1)*8,len(sections)*8))]
        for k in range(len(sections)-1):
            for j in range(8):faces.append((k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j))
        obj = self.mesh(name,verts,faces,role,smooth)
        envelope = (sections[-1][0]-sections[0][0])*max(s[1] for s in sections)*max(s[2] for s in sections)
        if envelope > .004 and role in ['hull','secondary','dark','paint']:
            self.structural_meshes.append(obj)
        if role in ['hull','paint','secondary'] and sections[-1][0]-sections[0][0] > .26 and max(s[1] for s in sections) > .13:
            self.shell_panels(name, sections, roundness, role)
        return obj

    def shell_panels(self,name,sections,roundness,role):
        """Sparse inset service panels following the hull, not a tiled grid.

        The large primary shell remains readable; only selected regions receive
        seams, fasteners and subordinate panels. All detail is actual geometry.
        """
        z0,z1=sections[0][0],sections[-1][0]
        def section(t):
            z=z0+(z1-z0)*t
            for i in range(len(sections)-1):
                a,b=sections[i:i+2]
                if a[0] <= z <= b[0]:
                    f=(z-a[0])/max(b[0]-a[0],1e-8)
                    return [a[k]*(1-f)+b[k]*f for k in range(5)]
            return sections[-1]
        def surface(t,u,face):
            z,w,h,y,x=section(t);r=roundness
            shape=[(-.5,-(.5-r)),(-(.5-r),-.5),((.5-r),-.5),(.5,-(.5-r)),(.5,.5-r),(.5-r,.5),(-(.5-r),.5),(-.5,.5-r)]
            a,b=shape[face],shape[(face+1)%8]
            return Vector((x+w*(a[0]*(1-u)+b[0]*u),y+h*(a[1]*(1-u)+b[1]*u),z))
        for face in [3,5,7]:
            for k,(start,end) in enumerate([(.16,.36),(.44,.63),(.73,.88)]):
                u0=.14 if k%2==0 else .31;u1=.77 if k%2==0 else .85
                ps=[surface(t,u,face) for t,u in [(start,u0),(start,u1),(end,u1),(end,u0)]]
                center=sum(ps,Vector())/4
                pa,pb,pc=[Vector(tuple(p[j]*self.dim[j] for j in range(3))) for p in ps[:3]]
                normal=(pb-pa).cross(pc-pa).normalized()
                # Offset in metres, then convert back to design coordinates.
                offset=Vector(tuple(normal[j]*min(.10,self.dim.z*.0006)/self.dim[j] for j in range(3)))
                if face==3 and offset.x<0 or face==7 and offset.x>0 or face==5 and offset.y<0:offset=-offset
                frame=[p+offset*.4 for p in ps]+[p+offset for p in ps]
                self.mesh('Recessed_service_seam',frame,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'dark')
                inset=[center+(p-center)*.94+offset*1.05 for p in ps]
                points=[p-offset*.2 for p in inset]+inset
                panel_role = 'secondary' if (k+face)%3 else role
                self.mesh('Shaped_maintenance_plate',points,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],panel_role)
                for corner in [0,2]:
                    p=center+(inset[corner]-center)*.82
                    self.beam('Flush_plate_fastener',p,p+offset*.8,min(.0007,.07/self.dim.x),'trim',segments=6)

    def curved(self,name,sections,role='hull',steps=4):
        """Catmull-Rom sections: broad continuous contour, not tiled barrels."""
        refined=[]
        for i in range(len(sections)-1):
            p0=sections[max(0,i-1)];p1=sections[i];p2=sections[i+1];p3=sections[min(len(sections)-1,i+2)]
            for j in range(steps):
                t=j/steps
                p=[(p1[k]*2+(p2[k]-p0[k])*t+(p0[k]*2-p1[k]*5+p2[k]*4-p3[k])*t*t+(-p0[k]+p1[k]*3-p2[k]*3+p3[k])*t*t*t)*.5 for k in range(5)]
                p[1]=max(.004,p[1]);p[2]=max(.004,p[2]);refined.append(tuple(p))
        refined.append(tuple(sections[-1]))
        return self.loft(name,refined,role,.32,True)

    def block(self,name,size,pos,role='hull'):
        x,y,z=pos;w,h,l=size
        return self.loft(name,[(z-l/2,w,h,y,x),(z+l/2,w,h,y,x)],role,.15)

    def wing(self,name,polygon,y,thickness,role='hull',slope=0):
        """Extruded planform, supports concave arrow/crescent contours."""
        n=len(polygon)
        vertices=[(x,y+slope*abs(x)+sy*thickness*.5,z) for sy in [-1,1] for x,z in polygon]
        faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return self.mesh(name,vertices,faces,role)

    def fin(self,name,polygon,x,thickness,role='paint'):
        """Vertical shaped plate: polygon contains (y,z)."""
        n=len(polygon)
        verts=[(x+side*thickness*.5,y,z) for side in [-1,1] for y,z in polygon]
        faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return self.mesh(name,verts,faces,role)

    def beam(self,name,a,b,radius=.008,role='dark',radius_end=None,segments=12):
        pa,pb=self.point(a),self.point(b);axis=pb-pa
        if axis.length<1e-5:return None
        bpy.ops.mesh.primitive_cone_add(vertices=segments,radius1=radius*self.dim.x,
            radius2=(radius if radius_end is None else radius_end)*self.dim.x,depth=axis.length,location=(pa+pb)*.5)
        obj=bpy.context.object;obj.name=f'{name}_{self.serial:03}';self.serial+=1
        obj.rotation_euler=axis.to_track_quat('Z','Y').to_euler()
        obj.data.materials.append(self.materials[role])
        for p in obj.data.polygons:p.use_smooth=len(p.vertices)==4
        return obj

    def ring(self,name,pos,rx,ry,depth=.012,role='trim',segments=40,axis='z'):
        x,y,z=pos;verts=[]
        for offset,scale in [(-depth/2,1),(depth/2,1),(depth/2,.78),(-depth/2,.78)]:
            for i in range(segments):
                a=i*math.tau/segments
                if axis=='y':verts.append((x+math.cos(a)*rx*scale,y+offset,z+math.sin(a)*ry*scale))
                else:verts.append((x+math.cos(a)*rx*scale,y+math.sin(a)*ry*scale,z+offset))
        faces=[]
        for k in range(4):
            for i in range(segments):faces.append((k*segments+i,k*segments+(i+1)%segments,((k+1)%4)*segments+(i+1)%segments,((k+1)%4)*segments+i))
        return self.mesh(name,verts,faces,role,True)

    def engine(self,x,y=0,z=.46,r=.07,length=.16):
        # All ships retain the old fixed FX anchor at x=+/-.18, y=0, z=.46.
        self.loft('Engine_cowl',[(z-length,r*1.45,r*2*self.dim.x/self.dim.y,y,x),(z-.035,r*2.1,r*2.1*self.dim.x/self.dim.y,y,x),(z-.008,r*1.9,r*1.9*self.dim.x/self.dim.y,y,x)],'secondary',.30,True)
        ry=r*self.dim.x/self.dim.y
        self.ring('Recessed_nozzle_lip',(x,y,z-.007),r,ry,.012,'trim',32)
        self.beam('Dark_nozzle_well',(x,y,z-.032),(x,y,z-.019),r*.76,'ceramic',segments=32)
        self.beam('Hot_thruster_core',(x,y,z-.018),(x,y,z-.016),r*.45,'glow',segments=32)
        for i in range(8):
            a=i*math.tau/8
            self.beam('Nozzle_radial_vane',(x+math.cos(a)*r*.52,y+math.sin(a)*ry*.52,z-.014),(x+math.cos(a)*r*.83,y+math.sin(a)*ry*.83,z-.010),r*.022,'dark',segments=6)

    def radiator(self,x,y,z,width=.13,length=.14,rows=7):
        self.block('Radiator_sink',(width,.025,length),(x,y,z),'dark')
        for j in range(rows):self.block('Graphite_cooling_fin',(width,.04,.004),(x,y+.02,z-length/2+(j+.5)*length/rows),'ceramic')

    def windows(self,x,y,z,count=7,spacing=.016,side=False):
        # Deliberately sparse, metrically small crew windows establish scale.
        h=min(.012,.26/self.dim.y);w=min(.009,.40/self.dim.x);d=.0014
        for i in range(count):
            p=(x,y,z+(i-(count-1)/2)*spacing) if side else (x+(i-(count-1)/2)*spacing,y,z)
            self.block('Crew_window',(d,h,w) if side else (w,h,d),p,'window')

    def truss(self,a,b,width=.025,bays=5):
        va,vb=Vector(a),Vector(b)
        off=Vector((0,width,0))
        self.beam('Exposed_chord',va+off,vb+off,.005,'trim')
        self.beam('Exposed_chord',va-off,vb-off,.005,'dark')
        for i in range(bays):
            p=va.lerp(vb,i/bays);q=va.lerp(vb,(i+1)/bays)
            self.beam('Diagonal_web',p+(off if i%2==0 else -off),q+(-off if i%2==0 else off),.003,'secondary',segments=6)

    def armament(self):
        # Mount positions come from the immutable authored geometry, never a
        # second weapon layout or balance table. Tubes stop at the true muzzle.
        bpy.context.view_layer.update()
        depsgraph=bpy.context.evaluated_depsgraph_get()
        supports=[(obj,BVHTree.FromObject(obj,depsgraph)) for obj in self.structural_meshes]
        if not supports: raise ValueError(f'{self.ship_id}: no structural hull for real mount supports')
        for name,p in self.geo['hardpoints'].items():
            if not name.startswith('weapon_'):continue
            x,y,z=(p[i]/self.dim[i] for i in range(3))
            self.loft('Recessed_weapon_bastion',[(z+.002,.016,.025,y,x),(z+.033,.032,.042,y-.006,x),(z+.065,.024,.030,y-.018,x)],'dark')
            self.beam('Armored_gun_sleeve',(x,y,z+.033),(x,y,z+.006),.006,'secondary',radius_end=.0045)
            self.beam('Weapon_muzzle',(x,y,z+.006),(x,y,z),.0038,'trim')
            # Connect the bastion to the central keel visibly, keeping the
            # real muzzle free. No change to physics hardpoint transforms.
            attachment = (0,0,-.10) if self.ship_id == 'frigate_kestrel' else (x*.35,y-.09,z+.15)
            if self.ship_id == 'support_council_choir': attachment = (-.27 if x < 0 else .27,.01,-.28)
            # A guessed centre may lie in this ship's deliberate negative
            # space. Project onto an actual primary-hull triangle, then embed
            # the support slightly inside it. Never leave a floating gun pod.
            desired=self.point(attachment)
            nearest=[]
            for obj,tree in supports:
                point,normal,index,distance=tree.find_nearest(desired)
                if point is not None: nearest.append((distance,point,normal,obj.name))
            distance,point,normal,support_name=min(nearest,key=lambda item:item[0])
            embedded=point-normal*min(self.dim)*.012
            attachment=(embedded.x/self.dim.x,embedded.z/self.dim.y,-embedded.y/self.dim.z)
            self.mount_connections[name]={'structural_mesh':support_name,'attachment_m':[embedded.x,embedded.z,-embedded.y],'surface_m':[point.x,point.z,-point.y],'muzzle_m':list(p)}
            self.truss((x,y-.018,z+.046),attachment,.008,3)

    def finish(self,out):
        out=Path(out);out.mkdir(parents=True,exist_ok=True)
        (out/'source').mkdir(exist_ok=True);(out/'source/.gdignore').write_text('',encoding='utf-8')
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
        limit=Vector((self.dim.x,self.dim.z,self.dim.y))*.505
        for obj in objects:
            for v in obj.data.vertices:
                if any(abs(v.co[i])>limit[i] for i in range(3)):
                    raise ValueError(f'{self.ship_id}: {obj.name} leaves retained physics envelope: {tuple(v.co)} / {tuple(limit)}')
        groups={}
        for obj in objects:groups.setdefault(obj.data.materials[0].name,[]).append(obj)
        for name,parts in groups.items():
            bpy.ops.object.select_all(action='DESELECT')
            for obj in parts:obj.select_set(True)
            bpy.context.view_layer.objects.active=parts[0]
            if len(parts)>1:bpy.ops.object.join()
            obj=bpy.context.object;obj.name=name
            if not any(name.endswith('_'+v) for v in ['window','glow','glass']):
                modifier=obj.modifiers.new('Small_machined_edge','BEVEL');modifier.width=min(.20,self.dim.z*.0007);modifier.segments=2;modifier.affect='EDGES'
                modifier.limit_method='ANGLE';modifier.angle_limit=math.radians(25)
                bpy.ops.object.modifier_apply(modifier=modifier.name)
                normals=obj.modifiers.new('Area_weighted_normals','WEIGHTED_NORMAL');normals.keep_sharp=True;normals.weight=35
                bpy.ops.object.modifier_apply(modifier=normals.name)
            obj['original_design']='ship-v4';obj['ship_def_id']=self.ship_id
        bpy.ops.object.select_all(action='SELECT')
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(out/'source'/f'{self.ship_id}.blend'))
        bpy.ops.export_scene.gltf(filepath=str(out/f'{self.ship_id}.glb'),export_format='GLB',export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
        triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
        return {'triangles':triangles,'surfaces':len(groups),'design':'ship-v4','axis':'Y_up_negative_Z_front','mount_connections':self.mount_connections}
