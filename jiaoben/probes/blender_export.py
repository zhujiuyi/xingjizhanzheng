"""Blender-only disposable GLB pipeline check; invoke with --background --factory-startup."""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[2]
destination = root / "jiaoben/tmp/godot-sqlite-probe/art-pipeline.glb"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 0))
obj = bpy.context.object
obj.name = "PipelineFixture"
obj.scale = (1.0, 0.4, 2.0)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for name, location in (("Nose", (0, 2, 0)), ("Up", (0, 0, 1)), ("Right", (1, 0, 0))):
    marker = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(marker)
    marker.location = location
bpy.ops.export_scene.gltf(filepath=str(destination), export_format="GLB", export_yup=True)
print("BLENDER_GLB_PASS", destination)
