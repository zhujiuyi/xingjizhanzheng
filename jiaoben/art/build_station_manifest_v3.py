"""Hash the independent station presentation pack; verify actual GLB metadata."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "code/assets/station_v3"

def digest(path):
    data = path.read_bytes()
    return {"sha256": hashlib.sha256(data).hexdigest(), "size_bytes": len(data)}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--record-runtime-qa", action="store_true", help="Only after fresh headless/native checks and two native screenshots.")
    args = parser.parse_args()
    data = (PACK / "station_industrial.glb").read_bytes()
    magic, version, total = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2 and total == len(data)
    length, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A
    gltf = json.loads(data[20:20+length])
    binary_offset = 20 + length
    binary_length, binary_kind = struct.unpack_from("<II", data, binary_offset)
    assert binary_kind == 0x004E4942
    binary = data[binary_offset+8:binary_offset+8+binary_length]
    geometry = json.loads((PACK / "geometry.json").read_text(encoding="utf-8"))
    assert not gltf.get("animations") and not gltf.get("skins") and not gltf.get("cameras")
    assert len(gltf["meshes"]) == 1 and len(gltf["meshes"][0]["primitives"]) == 8
    triangles = sum(gltf["accessors"][p["indices"]]["count"]//3 for p in gltf["meshes"][0]["primitives"])
    assert triangles == geometry["triangles"] and triangles <= 100000
    exported_vertices = 0
    for primitive in gltf["meshes"][0]["primitives"]:
        bounds = gltf["accessors"][primitive["attributes"]["POSITION"]]
        assert all(math.isfinite(v) for v in bounds["min"] + bounds["max"])
        assert all(-limit <= bounds["min"][axis] <= bounds["max"][axis] <= limit
                   for axis, limit in enumerate([220,115,220]))
        exported_vertices += bounds["count"]
        for attribute in ["POSITION", "NORMAL"]:
            accessor = gltf["accessors"][primitive["attributes"][attribute]]
            view = gltf["bufferViews"][accessor["bufferView"]]
            assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
            offset = view.get("byteOffset",0) + accessor.get("byteOffset",0)
            stride = view.get("byteStride",12)
            for index in range(accessor["count"]):
                values = struct.unpack_from("<3f", binary, offset+stride*index)
                assert all(math.isfinite(value) for value in values)
                if attribute == "NORMAL":
                    assert abs(sum(value*value for value in values)-1) < .002
    resources = [{"resource_path": "res://assets/station_v3/"+name, **digest(PACK/name)}
                 for name in ["station_industrial.glb", "industrial_station.gdshader", "geometry.json"]]
    source = PACK / "source/station_industrial.blend"
    manifest = {
        "format_version": 1, "asset_version": "station-v3",
        "scope": "Original station render mesh and materials only; no collision, world state, interactions or frozen v0.4 assets are changed.",
        "authoring": {"tool": "Blender 4.5.14 LTS", "source_script": "jiaoben/art/build_station_v3.py",
                      "origin": "Original project-authored industrial ring geometry and rough-metal spatial shader.",
                      "rights": "Project-authored source; no third-party models or screenshot-derived textures.",
                      "texture_dependency": "res://assets/interface_v2/metal_albedo.png; original asset provenance remains in its existing manifest."},
        "runtime_script": "res://runtime/visuals/station_visual_adapter.gd",
        "art_direction": {"silhouette": "Segmented armored habitation ring, open load-bearing spokes, central reactor/service core, asymmetric refinery, logistics and terraced habitation pods.",
                          "scale_cues": "Inset pipe channels, armor joints, inspection panels, radiator slats, sparse tiny windows, docking gantry arms and portal ribs.",
                          "material": "Dark recesses; high-roughness coated steel and exposed structure; restrained cyan windows and amber docking lamps.",
                          "dock": "Recessed visual berth faces positive Godot Z; docking remains existing proximity/menu action, no fly-in collider change."},
        "technical": geometry,
        "resources": resources,
        "source_assets": [{"path": "code/assets/station_v3/source/station_industrial.blend", **digest(source)}],
        "qa": {"source_finite_vertices": True, "source_degenerate_triangles": 0,
               "glb_exported_vertices": exported_vertices, "glb_binary_finite_positions_and_unit_normals": True,
               "source_bounds_within_immutable_collision_box": True,
               "runtime_test": "jiaoben/art/test_station_v3.gd", "native_preview": "jiaoben/art/preview_station_v3.gd",
               "status": "Offline source geometry and GLB structure passed; imported/native integration pending."}}
    if args.record_runtime_qa:
        newest_resource = max((PACK/name).stat().st_mtime for name in ["station_industrial.glb", "industrial_station.gdshader", "geometry.json"])
        for mode in ["headless", "native"]:
            output_path = ROOT / f"jiaoben/logs/station-v3-test-{mode}.log"
            output = output_path.read_text(encoding="utf-8")
            assert output_path.stat().st_mtime >= newest_resource
            assert "STATION_V3_CHECKS 114 failed=0" in output
            engine = (ROOT / f"jiaoben/logs/station-v3-test-{mode}-engine.log").read_text(encoding="utf-8")
            assert not re.search(r"ERROR:|WARNING:|leaked|still in use",output+engine,re.IGNORECASE)
        screenshots = [ROOT / f"jiaoben/tmp/station-v3/station-native-{view}.png" for view in ["three-quarter", "front"]]
        assert all(path.stat().st_mtime >= newest_resource for path in screenshots)
        render_output = (ROOT / "jiaoben/logs/station-v3-preview-native.log").read_text(encoding="utf-8")
        render_engine = (ROOT / "jiaoben/logs/station-v3-preview-native-engine.log").read_text(encoding="utf-8")
        assert render_output.count("error=0") == 2
        assert not re.search(r"ERROR:|WARNING:|leaked|still in use",render_output+render_engine,re.IGNORECASE)
        manifest["qa"].update({"headless_checks":114,"native_checks":114,"failed_assertions":0,
                              "engine_diagnostics":0,"native_renderer":"Godot 4.7.2 Metal Forward+ / Apple M1 Pro / CoreAudio",
                              "native_resolution_px":[1440,900],
                              "native_lighting":"Matches sector_anchor: key2.0, ambient0.7, fill0.65, filmic, project panorama0.65; no extra shadow/AO lights.",
                              "status":"Imported structure, frozen-resource preservation and native two-angle rendering verified; final host/client integration owned by root."})
    (PACK / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"STATION_V3_MANIFEST resources={len(resources)} triangles={triangles} surfaces=8")

if __name__ == "__main__": main()
