"""正式运行资源清单：原始bytes SHA + 去self的canonical JSON SHA。"""
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[2]
CODE = ROOT / "code"
ASSETS = CODE / "assets"
resources = []

def register(path, asset_id, **fields):
    resources.append({"asset_id": asset_id, "resource_path": "res://" + path.relative_to(CODE).as_posix(),
                      "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), **fields})

for path in sorted((ASSETS / "ships").glob("*.tscn")):
    register(path, "asset_ship_" + path.stem, ship_def_id=path.stem)
for path in sorted((ASSETS / "placeholders").glob("*.tscn")):
    register(path, "legacy_ship_" + path.stem)
for path in sorted((ASSETS / "objects").glob("*.tscn")):
    register(path, "asset_object_" + path.stem)
for path in sorted((ASSETS / "sectors").glob("*.tscn")):
    register(path, "scene_" + path.stem)
for path in sorted((ASSETS / "models").rglob("*.glb")):
    register(path, "model_" + path.stem)
register(ASSETS / "models/geometry.json", "asset_geometry_fleet")
for path in sorted((ASSETS / "audio").glob("*.wav")):
    register(path, "sound_" + path.stem)
for path in sorted((CODE / "runtime/visuals").rglob("*.gd")):
    register(path, "visual_code_" + path.stem)
for path in sorted((CODE / "runtime/visuals").rglob("*.gdshader")):
    register(path, "visual_shader_" + path.stem)

assert len({resource["asset_id"] for resource in resources}) == len(resources)
assert len({resource["resource_path"] for resource in resources}) == len(resources)
manifest = {"asset_version": "art-full-v1", "format_version": 1,
            "coordinate_system": "meters_Y_up_negative_Z_front", "resources": resources}
canonical = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
manifest["manifest_sha256"] = hashlib.sha256(canonical).hexdigest()
(ASSETS / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")

metrics = []
for path in sorted((ASSETS / "models").rglob("*.glb")):
    data = path.read_bytes()
    assert data[:4] == b"glTF" and struct.unpack_from("<I", data, 8)[0] == len(data)
    length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20+length])
    primitives = [primitive for mesh in gltf["meshes"] for primitive in mesh["primitives"]]
    triangles = sum(gltf["accessors"][primitive["indices"]]["count"] // 3 for primitive in primitives)
    metrics.append({"asset": path.stem, "triangles": triangles, "surfaces": len(primitives), "bytes": len(data)})
target = ROOT / "jiaoben/tmp/art/metrics.json"
target.write_text(json.dumps(metrics, indent=2) + "\n")
print("ART_MANIFEST_COMPLETE", len(resources), manifest["manifest_sha256"])
print("ART_METRICS", len(metrics), "models", max(item["triangles"] for item in metrics), "max triangles")
