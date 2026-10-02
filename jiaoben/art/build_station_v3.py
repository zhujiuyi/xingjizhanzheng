"""Original industrial ring station; run with the locked Blender background runtime.

Only presentation geometry is authored. World collision and interaction remain in the
immutable station_anchor.tscn wrapper. All generated coordinates fit its 440x230x440 box.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "code/assets/station_v3"
SOURCE = PACK / "source"
PREVIEW = ROOT / "jiaoben/tmp/station-v3"
TAU = math.tau


def material(name, color, metallic=.55, roughness=.74, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Specular IOR Level"].default_value = .25
    if emission:
        principled.inputs["Emission Color"].default_value = (*color, 1)
        principled.inputs["Emission Strength"].default_value = emission
    return mat


def finish(obj, name, mat, bevel=.65):
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Manufactured edge chamfer", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.affect = "EDGES"
        modifier = obj.modifiers.new("Weighted machined normals", "WEIGHTED_NORMAL")
        modifier.keep_sharp = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier="Manufactured edge chamfer")
        bpy.ops.object.modifier_apply(modifier="Weighted machined normals")
    return obj


def box(name, center, size, mat, bevel=.65, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = angle
    return finish(obj, name, mat, bevel)


def cylinder(name, center, radius, depth, mat, vertices=32, bevel=.5):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    return finish(bpy.context.object, name, mat, bevel)


def ring_piece(name, inner, outer, z, height, angle, span, mat, divisions=4, bevel=.45):
    vertices, faces = [], []
    for i in range(divisions + 1):
        a = angle - span / 2 + span * i / divisions
        for r, h in [(inner, z-height/2), (outer, z-height/2), (inner, z+height/2), (outer, z+height/2)]:
            vertices.append((math.cos(a)*r, math.sin(a)*r, h))
    for i in range(divisions):
        k, q = i*4, (i+1)*4
        faces.extend([(k,q,q+1,k+1), (k+2,k+3,q+3,q+2), (k,k+2,q+2,q), (k+1,q+1,q+3,k+3)])
    faces.extend([(0,1,3,2), (divisions*4,divisions*4+2,divisions*4+3,divisions*4+1)])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    # Recalculate mesh normals from topology before bevel/export.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return finish(obj, name, mat, bevel)


def beam(name, start, end, thickness, mat, bevel=.35):
    midpoint = (Vector(start) + Vector(end)) * .5
    direction = Vector(end) - Vector(start)
    obj = box(name, midpoint, (thickness, thickness, direction.length), mat, bevel)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def radial_box(name, angle, radius, z, radial_depth, width, height, mat, bevel=.65):
    return box(name, (math.cos(angle)*radius,math.sin(angle)*radius,z), (radial_depth,width,height), mat, bevel, angle)


def build():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mats = {
        "armor": material("Station_Armor_Steel", (.082,.099,.106), .62, .78),
        "panel": material("Station_Secondary_Plate", (.125,.14,.145), .56, .79),
        "dark": material("Station_Deep_Recess", (.003,.005,.006), .25, .88),
        "rail": material("Station_Exposed_Structure", (.047,.064,.074), .66, .7),
        "radiator": material("Station_Radiator_Carbon", (.028,.039,.045), .45, .84),
        "orange": material("Station_Safety_Coat", (.22,.105,.035), .18, .87),
        "blue": material("Station_Window_Glass", (.014,.21,.26), .14, .42, .85),
        "amber": material("Station_Guide_Lights", (.48,.275,.085), .1, .5, 1.3),
    }
    # Primary segmented habitation/service ring: separate armor tiers create deep seams.
    for i in range(24):
        a = TAU*i/24
        ring_piece(f"Ring structural keel {i:02}", 138,181,-5,40,a,TAU/24*.985,mats["dark"],bevel=.8)
        ring_piece(f"Ring upper armor {i:02}", 136,182,13,12,a,TAU/24*.91,mats["panel" if i%5==0 else "armor"])
        ring_piece(f"Ring underside armor {i:02}", 138,185,-21,10,a,TAU/24*.91,mats["armor"])
        # Individual sloped buttresses break a flat disc silhouette.
        radial_box(f"Ring outer service spine {i:02}",a,183,-3,10,9,28,mats["rail"],.9)
        if i % 3 == 1:
            ring_piece(f"Sparse habitation window {i:02}",181.1,182.5,6,1.65,a,TAU/24*.55,mats["blue"],bevel=.1)
        if i % 4 == 0:
            radial_box(f"Maintenance access panel {i:02}",a,160,20,25,13,1.5,mats["panel"],.3)
            radial_box(f"Safety marker {i:02}",a,174,21,6,1.5,1,mats["orange"],.1)
        ring_piece(f"Exterior rail {i:02}",183.6,185,23,1.5,a,TAU/24*.94,mats["rail"],bevel=.15)
        ring_piece(f"Top embedded service channel {i:02}",163,165,19.15,.45,a,TAU/24*.76,mats["dark"],bevel=.1)
        ring_piece(f"Top exposed conduit {i:02}",164,164.65,19.5,.55,a,TAU/24*.51,mats["rail"],bevel=.12)
        radial_box(f"Ring maintenance cabinet {i:02}",a+.05,146,21.7,8,10,4,mats["rail"],.5)
        if i%2==0:
            radial_box(f"Ring recessed vent bed {i:02}",a-.048,173,19.6,9,10,.8,mats["dark"],.15)
            for j in range(4):
                radial_box(f"Ring vent slat {i:02} {j}",a-.071+j*.015,173,20.3,8,1.15,.75,mats["radiator"],.1)
        radial_box(f"Ring inner structural joint {i:02}",a,138,-3,5,5,29,mats["rail"],.35)
    # Central plant/command shaft is mechanical instead of a plain reflective cylinder.
    cylinder("Core pressure vessel", (0,0,8), 32,175,mats["dark"],16,1)
    for z, radius, depth in [(-80,43,13),(-54,38,9),(-24,37,7),(28,39,8),(73,40,14),(98,29,15)]:
        cylinder("Core flange", (0,0,z),radius,depth,mats["armor"],32,.8)
    for i in range(12):
        a=TAU*i/12
        radial_box("Vertical reactor armor",a,31,4,8,12,132,mats["armor"],1.2)
        radial_box("Core raised utility line",a,36,1,3,3,112,mats["rail"],.4)
        radial_box("Command viewing strip",a,30,100,2,10,1.3,mats["blue"],.1)
    cylinder("Command roof",(0,0,109),24,5,mats["panel"],24,.5)
    # Eight genuine spoke/truss bridges leave open volumes rather than stacked solid discs.
    for i in range(8):
        a=TAU*i/8
        radial_box("Radial bridge housing",a,87,-1,104,12,18,mats["armor"],1.1)
        radial_box("Bridge cable bed",a,87,10,95,7,2,mats["dark"],.2)
        for lateral in [-8,8]:
            p0=Vector((math.cos(a)*40,math.sin(a)*40, -50))
            p1=Vector((math.cos(a)*137,math.sin(a)*137,-20))
            offset=Vector((-math.sin(a)*lateral,math.cos(a)*lateral,0))
            beam("Diagonal load truss",p0+offset,p1+offset,3.5,mats["rail"])
    # Secondary service hoop has lattice spacing and uneven utility packages, not another disc.
    for i in range(16):
        a=TAU*i/16
        ring_piece("Lower reactor utility hoop",90,97,-68,8,a,TAU/16*.96,mats["rail"],bevel=.35)
        if i%2==0:
            radial_box("Reactor service pod",a,98,-68,14,17,15,mats["armor"],.8)
            beam("Lower hoop bracing",(math.cos(a)*34,math.sin(a)*34,-78),(math.cos(a)*90,math.sin(a)*90,-68),2.5,mats["rail"])
    # Dock front is -Y in Blender => +Z in exported Godot. A recess remains behind a raised mouth.
    box("Dock spine",(0,-167,0),(66,69,48),mats["dark"],2)
    box("Dock upper armor",(0,-169,29),(74,76,14),mats["armor"],2)
    box("Dock lower apron",(0,-178,-28),(81,72,9),mats["panel"],1.2)
    for x in [-36,36]:
        box("Dock side cheek",(x,-173,-1),(14,69,48),mats["armor"],1.6)
        box("Dock inner amber edge",(x*.78,-205,-1),(1.3,1.6,29),mats["amber"],.15)
        box("Dock service gantry",(x*1.65,-162,0),(19,39,37),mats["armor"],1.4)
    # Layered portal frames convey depth; black inner wall deliberately stays non-emissive.
    for y in [-206,-194,-184]:
        box("Portal top rib",(0,y,21),(57,2.5,3),mats["rail"],.3)
        for x in [-27,27]:
            box("Portal side rib",(x,y,-1),(3,2.5,42),mats["rail"],.3)
    box("Dock inner dark end",(0,-167,-2),(50,3,35),mats["dark"],.3)
    box("Dock roof recessed machinery",(0,-173,37),(46,42,2),mats["dark"],.3)
    for j in range(9):
        box("Dock ventilation louver",(0,-190+j*4.2,39),(44,1.6,2.8),mats["radiator"],.2)
    for x in [-57,57]:
        box("Service gantry base",(x,-168,21),(8,14,7),mats["rail"],.6)
        beam("Dock service manipulator",(x,-169,23),(x*.73,-191,34),2.7,mats["rail"],.3)
        beam("Dock service arm",(x*.73,-191,34),(x*.46,-198,32),2.1,mats["rail"],.3)
        box("Dock gantry terminal",(x*.45,-199,30),(5,5,6),mats["orange"],.4)
    for x in [-17,17]:
        box("Dock approach guide",(x,-201,-22),(1,18,.55),mats["amber"],.1)
    # Refinery aft: pressure tanks, exposed junctions and finned heat rejection.
    box("Aft refinery block",(0,174,5),(79,66,64),mats["armor"],2.1)
    for x in [-28,0,28]:
        cylinder("Refinery pressure tank",(x,177,48),10,31,mats["rail"],24,.75)
        cylinder("Tank valve cap",(x,177,65),7,3,mats["orange"],24,.25)
    for x in [-59,59]:
        box("Refinery radiator back",(x,161,8),(38,55,4),mats["dark"],.5)
        for j in range(11):
            box("Radiator fin",(x,140+j*4.2,10),(37,1.7,5),mats["radiator"],.15)
    # Asymmetric logistics blocks on both sides, each with a different mass rhythm.
    box("Port cargo logistics",(-171,0,-7),(69,56,46),mats["armor"],1.6)
    for j in range(4):
        box("Cargo armored container",(-176,-18+j*12,-4),(39,9,30),mats["panel" if j==2 else "rail"],.7)
        box("Cargo security band",(-197,-18+j*12,-3),(1.5,7,21),mats["orange"],.2)
    box("Starboard habitat base",(169,10,9),(64,47,61),mats["armor"],1.4)
    for j in range(4):
        box("Habitat terraced plate",(169,6,42+j*5),(55-j*7,38-j*4,4),mats["panel"],.5)
    for y in [-1,10,21]:
        box("Habitat window sparse",(201,y,23),(1,6,1.2),mats["blue"],.1)
    # Sparse antenna/communication structure within the old upper collision envelope.
    beam("Comms angled spar",(14,3,82),(35,9,109),2,mats["rail"],.15)
    for j in range(3):
        box("Comms louver",(33,8,99+j*3.2),(13,2,1),mats["radiator"],.1)
    # Manufacturing wear is geometry/material driven; no baked lighting in albedo.
    for i in range(8):
        a=TAU*i/8+TAU/48
        radial_box("Ring inspection recess",a,177,21,6,9,1,mats["dark"],.15)
        for r in [143,178]:
            cylinder("Panel fastener",(math.cos(a)*r,math.sin(a)*r,20),.8,1,mats["rail"],8,.1)
    return mats


def merge():
    meshes=[obj for obj in bpy.context.scene.objects if obj.type=="MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes: obj.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name="Industrial_Ring_Station"
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    # Export a single mesh with shared surfaces, while retaining the same silhouette at distance.
    return obj


def geometry(obj):
    obj.data.calc_loop_triangles()
    verts=[obj.matrix_world@v.co for v in obj.data.vertices]
    low=[min(v[i] for v in verts) for i in range(3)]
    high=[max(v[i] for v in verts) for i in range(3)]
    # glTF uses Y up; Blender (x,y,z) exports as (x,z,-y).
    godot_min=[low[0],low[2],-high[1]]
    godot_max=[high[0],high[2],-low[1]]
    degenerate=sum(1 for tri in obj.data.loop_triangles if tri.area<1e-8)
    finite=all(math.isfinite(c) for v in verts for c in v)
    bounds=[godot_max[i]-godot_min[i] for i in range(3)]
    if not finite or degenerate or any(godot_min[i]<-lim or godot_max[i]>lim for i,lim in enumerate([220,115,220])):
        raise RuntimeError(f"Invalid station geometry: {godot_min}, {godot_max}, degenerates={degenerate}")
    return {"asset_version":"station-v3", "axis":"Y_up_positive_Z_dock", "visual_only":True,
            "old_wrapper":"res://assets/objects/station_anchor.tscn", "collision_policy":"immutable box remains 440x230x440; no collision authored by new GLB",
            "bounds_min_m":godot_min,"bounds_max_m":godot_max,"bounds_m":bounds,
            "triangles":len(obj.data.loop_triangles),"vertices":len(verts),"material_surfaces":len(obj.data.materials),
            "finite_coordinates":finite,"degenerate_triangles":degenerate,"runtime_pivot_m":[0,0,0]}


def preview():
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1440
    scene.render.resolution_y=1000
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.world.color=(.018,.023,.03)
    scene.world.use_nodes=True
    scene.world.node_tree.nodes.get("Background").inputs["Color"].default_value=(.12,.15,.18,1)
    scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value=.35
    scene.view_settings.view_transform="AgX"
    bpy.ops.object.camera_add(location=(440,-610,365))
    camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.lens=47
    scene.camera=camera
    for location, energy, color, size in [((160,-280,470),2200000,(1,.91,.8),260),((-360,-120,90),1700000,(.61,.73,.82),260),((80,340,290),2400000,(.91,.94,1),190)]:
        bpy.ops.object.light_add(type="AREA",location=location)
        light=bpy.context.object
        light.data.energy=energy
        light.data.color=color
        light.data.shape="DISK"
        light.data.size=size
        light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(PREVIEW/"station-three-quarter.png")
    bpy.ops.render.render(write_still=True)


def main():
    PACK.mkdir(parents=True,exist_ok=True)
    SOURCE.mkdir(parents=True,exist_ok=True)
    PREVIEW.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    (SOURCE/".gdignore").write_text("",encoding="utf-8")
    build()
    obj=merge()
    (PACK/"geometry.json").write_text(json.dumps(geometry(obj),ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"station_industrial.blend"))
    bpy.ops.export_scene.gltf(filepath=str(PACK/"station_industrial.glb"),export_format="GLB",use_selection=True,
                              export_yup=True,export_cameras=False,export_lights=False,export_animations=False)
    preview()
    print("STATION_V3_SOURCE_COMPLETE",flush=True)


if __name__=="__main__":main()
