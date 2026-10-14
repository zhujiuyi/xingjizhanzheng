"""Register additive presentation resources without rewriting signed legacy packs."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
CODE = ROOT / "code"
PACKS = {
    "materials_v1": [
        "runtime/surface_style.gd",
        "runtime/rendering/surface_materials.gd",
        "runtime/rendering/surface_meshes.gd",
        "runtime/rendering/material_hangar.gd",
        "assets/materials_v1/surface.gdshader",
        "assets/materials_v1/micro_surface.png",
        "assets/materials_v1/rock_strata.png",
        "assets/materials_v1/hangar_reflection.gdshader",
        "assets/materials_v1/hangar_reflection.res",
    ],
    "effects_v1": [
        "runtime/rendering/realistic_effects.gd",
        "assets/effects_v1/energy.gdshader",
        "assets/effects_v1/particle.gdshader",
        "assets/effects_v1/shield_contact.gdshader",
        "assets/effects_v1/aperture.gdshader",
    ],
}

def main():
    for name, paths in PACKS.items():
        resources = []
        for relative in paths:
            source = CODE / relative
            data = source.read_bytes()
            resources.append({"path": "res://" + relative, "sha256": hashlib.sha256(data).hexdigest(), "size_bytes": len(data)})
        manifest = {"format_version": 1, "asset_version": name.replace("_", "-"),
                    "scope": "Presentation-only adapter, local material response and visual meshes. No gameplay balance, collision, hardpoints, database or legacy asset identity changes.",
                    "source_document": "doc/69-交互一致性与材质表现优化.md", "resources": resources}
        output = CODE / "assets" / name / "manifest.json"
        output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(name, len(resources), hashlib.sha256(output.read_bytes()).hexdigest())

if __name__ == "__main__":
    main()
