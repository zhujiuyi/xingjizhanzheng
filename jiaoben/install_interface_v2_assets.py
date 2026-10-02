#!/usr/bin/env python3
"""Preserve selected raster/vector/shader bytes and build the presentation manifest."""
from __future__ import annotations

import hashlib
import argparse
import json
from pathlib import Path
import shutil
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "jiaoben/interface_v2_sources.json"
DESTINATION = ROOT / "code/assets/interface_v2"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_info(path: Path) -> dict:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG: {path}")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    return {"width": width, "height": height, "bit_depth": depth,
            "png_color_type": color, "alpha_channel": color in (4, 6)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--select-updated-source", action="store_true",
                        help="Replace this task's provisional source only when its hash is recorded in source_history.")
    args = parser.parse_args()
    config = json.loads(SOURCES.read_text(encoding="utf-8"))
    DESTINATION.mkdir(parents=True, exist_ok=True)
    resources = []
    for asset in config["assets"]:
        source = Path(asset["source_path"])
        resource_path = asset.get("resource_path", "res://assets/interface_v2/" + asset["filename"])
        destination = ROOT / "code" / resource_path.removeprefix("res://")
        if not source.is_file():
            raise FileNotFoundError(f"Original generated image is unavailable: {source}")
        source_hash = sha256(source)
        if destination.exists() and sha256(destination) != source_hash:
            old_hash = sha256(destination)
            reviewed_history = {entry["sha256"] for entry in asset.get("source_history", [])}
            if not args.select_updated_source or old_hash not in reviewed_history:
                raise ValueError(f"Refusing to replace an unrecorded selected asset: {destination}")
            backup = ROOT / "jiaoben/tmp/interface_v2_provisional" / (old_hash + ".png")
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                shutil.copy2(destination, backup)
            shutil.copy2(source, destination)
        if not destination.exists():
            shutil.copy2(source, destination)
        if sha256(destination) != source_hash:
            raise ValueError(f"Copy differs from generated original: {destination}")
        technical = dict(asset["technical"])
        if destination.suffix == ".png":
            technical.update(png_info(destination))
        elif destination.suffix == ".svg":
            vector = ET.fromstring(destination.read_text(encoding="utf-8"))
            technical.update({"width": int(vector.attrib["width"]), "height": int(vector.attrib["height"]),
                              "format": "SVG", "supports_transparency": True})
        elif destination.suffix == ".gdshader":
            if "shader_type canvas_item;" not in destination.read_text(encoding="utf-8"):
                raise ValueError("Unexpected UI shader type")
            technical["format"] = "Godot canvas_item shader"
        else:
            raise ValueError("Unregistered resource format")
        width, height = technical.get("width", 0), technical.get("height", 0)
        if technical["expected_layout"].startswith("square") and width != height:
            raise ValueError("Square image layout mismatch")
        if technical["expected_layout"] == "square_2x2":
            if width % 2 or height % 2:
                raise ValueError("Atlas dimensions must support four integer regions")
            half_w, half_h = width // 2, height // 2
            technical["atlas_regions"] = [
                {"id": region_id, "rect": [i % 2 * half_w, i // 2 * half_h, half_w, half_h]}
                for i, region_id in enumerate(technical["quadrant_ids"])
            ]
            technical["atlas_edit"] = "None: original image remains one file; UI uses AtlasTexture regions."
        if technical["expected_layout"] == "approximately_16_9":
            if abs(width / height - 16 / 9) > 0.002:
                raise ValueError("Title source is outside the accepted near-16:9 aspect tolerance")
            technical["aspect_note"] = "Original generated dimensions preserved; use UI cover scaling, no crop/resample file."
        resources.append({
            "id": asset["id"], "role": asset["role"],
            "path": resource_path,
            "sha256": source_hash, "size_bytes": destination.stat().st_size,
            "status": asset.get("status", "source_selected_context_review_pending"), "technical": technical,
            "source": {
                "kind": asset.get("source_kind", "generated"), "url_or_tool": asset.get("tool", config["tool"]),
                "model": asset.get("model", config["model"]), "created_at": config["created_at"],
                "original_generated_path": str(source), "original_sha256": source_hash,
                "prompt": asset["prompt"], "references": config["references_used"],
                "source_history": asset.get("source_history", []),
                "license_or_generation_note": asset.get("generation_note", config["generation_note"]),
                "license_note": asset.get("license_note", config["license_note"]),
                "terms_url": config["terms_url"] if destination.suffix == ".png" else "",
                "edits": asset.get("edit_history", []) + ["Byte-identical copy of selected tool output; no pixel edits by the install script."],
            },
            "verification": {
                "original_viewed_with_view_image": destination.suffix == ".png",
                "source_copy_sha256_matches": True,
                "png_layout_checks_passed": destination.suffix == ".png",
                "vector_layout_checks_passed": destination.suffix == ".svg",
                "native_scale_reviewed": False, "in_engine_reviewed": False,
                "tiling_reviewed": False, "approved_by": "",
                **asset.get("verification", {}),
            },
        })
    manifest = {
        "format_version": 1, "asset_version": config["asset_version"],
        "scope": "Current presentation pack independent of frozen gameplay; does not replace art-full-v1 or world content identity.",
        "art_direction": {
            "shape": "engineered rectangular panels and restrained character silhouettes",
            "palette": "carbon gray, cold blue, small muted amber accents",
            "material": "worn steel, practical fabric, natural skin",
            "lighting": "soft cold ambient with controlled highlights",
            "text_policy": "All functional text remains engine-native; no raster labels.",
        },
        "resources": resources,
    }
    canonical = json.dumps(manifest, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    manifest["manifest_sha256"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    path = DESTINATION / "manifest.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"manifest": str(path), "manifest_sha256": manifest["manifest_sha256"],
                      "assets": [{"id": r["id"], "width": r["technical"].get("width"),
                                  "height": r["technical"].get("height"), "sha256": r["sha256"]}
                                 for r in resources]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
