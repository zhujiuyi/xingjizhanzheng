#!/usr/bin/env python3
"""Validate compact service icons and build their independent raw-resource pack.

Run ``py jiaoben/build_service_navigation.py`` after editing the registry/icons.
Use ``--check`` to verify without changing the manifest. Neither mode rewrites
source artwork, old manifests, databases or SQL.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CODE = ROOT / "code"
REGISTRY = CODE / "runtime/ui/service_navigation.gd"
ICON_DIR = CODE / "assets/interface_v3/services"
MANIFEST = CODE / "assets/service_navigation_v3/manifest.json"
SVG_NAMESPACE = "http://www.w3.org/2000/svg"
SVG_ELEMENTS = {"svg", "g", "path", "circle", "ellipse", "rect", "line", "polyline", "polygon"}
SVG_ATTRIBUTES = {
    "width", "height", "viewBox", "fill", "stroke", "stroke-width",
    "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "opacity",
    "fill-opacity", "stroke-opacity", "d", "cx", "cy", "r", "rx", "ry",
    "x", "y", "x1", "x2", "y1", "y2", "points", "transform",
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_source(path: Path, maximum: int) -> tuple[bytes, str]:
    data = path.read_bytes()
    if len(data) > maximum or data.startswith(b"\xef\xbb\xbf") or b"\r" in data or not data.endswith(b"\n"):
        raise ValueError(f"Source must be bounded UTF-8 without BOM and use LF/final newline: {path.relative_to(ROOT)}")
    return data, data.decode("utf-8", errors="strict")


def validate_svg(path: Path) -> bytes:
    data, source = read_source(path, 16_384)
    if re.search(r"<!DOCTYPE|<!ENTITY|<\?", source, re.IGNORECASE):
        raise ValueError(f"SVG declarations/entities are forbidden: {path.name}")
    root = ET.fromstring(source)
    if root.tag != f"{{{SVG_NAMESPACE}}}svg" or root.attrib.get("width") != "24" or root.attrib.get("height") != "24":
        raise ValueError(f"SVG must have an SVG namespace and 24x24 dimensions: {path.name}")
    values = [float(value) for value in root.attrib.get("viewBox", "").split()]
    if len(values) != 4 or not all(math.isfinite(value) for value in values) or values != [0, 0, 24, 24]:
        raise ValueError(f"SVG must have a finite 0 0 24 24 viewBox: {path.name}")
    geometry = 0
    for element in root.iter():
        tag = element.tag.removeprefix(f"{{{SVG_NAMESPACE}}}")
        if element.tag != f"{{{SVG_NAMESPACE}}}{tag}" or tag not in SVG_ELEMENTS:
            raise ValueError(f"SVG element is not static geometry: {path.name}: {tag}")
        if tag not in {"svg", "g"}:
            geometry += 1
        if element.text and element.text.strip():
            raise ValueError(f"SVG text must use engine-native captions: {path.name}")
        for name, value in element.attrib.items():
            if name not in SVG_ATTRIBUTES or re.search(r"url\s*\(|(?:https?|data|javascript):|[<>]", value, re.IGNORECASE):
                raise ValueError(f"SVG attribute/external reference is forbidden: {path.name}: {name}")
    if not geometry:
        raise ValueError(f"SVG has no function geometry: {path.name}")
    return data


def manifest_bytes() -> bytes:
    registry_data, source = read_source(REGISTRY, 131_072)
    records = re.findall(
        r'\{"id": "([a-z_]+)", "label": "([^"]+)", "icon": "(res://assets/interface_v3/services/[a-z_]+\.svg)"\}',
        source,
    )
    observe = re.findall(r'^const OBSERVE_ICON: String = "(res://assets/interface_v3/services/[a-z_]+\.svg)"$', source, re.MULTILINE)
    extras = re.findall(
        r'^\t"([a-z_]+)": "(res://assets/interface_v3/services/[a-z_]+\.svg)",$',
        source,
        re.MULTILINE,
    )
    if len(records) != 12 or len({record[0] for record in records}) != 12 or len(observe) != 1:
        raise ValueError("Registry must define twelve unique pages and one ship observation icon")
    if len(extras) != 3 or len({extra[0] for extra in extras}) != 3:
        raise ValueError("Registry must define three unique flight-rail marks outside the service list")
    paths = [record[2] for record in records] + observe + [extra[1] for extra in extras]
    if len(set(paths)) != 16 or set(paths) != {"res://" + path.relative_to(CODE).as_posix() for path in ICON_DIR.glob("*.svg")}:
        raise ValueError("Registry references must match the exact set of sixteen service SVGs")
    resources = []
    for index, resource_path in enumerate(paths):
        path = CODE / resource_path.removeprefix("res://")
        data = validate_svg(path)
        if index < len(records):
            asset_id: str = "service_" + records[index][0] + "_icon"
            role: str = "function_navigation_icon"
        elif index == len(records):
            asset_id = "service_observe_ship_icon"
            role = "hangar_observation_icon"
        else:
            asset_id = "flight_" + extras[index - len(records) - 1][0] + "_icon"
            role = "flight_rail_icon"
        resources.append({
            "asset_id": asset_id,
            "resource_path": resource_path,
            "sha256": digest(data),
            "size_bytes": len(data),
            "role": role,
            "source": "Project-authored static SVG geometry; no third-party artwork.",
        })
    resources.append({
        "asset_id": "service_navigation_registry",
        "resource_path": "res://runtime/ui/service_navigation.gd",
        "sha256": digest(registry_data),
        "size_bytes": len(registry_data),
        "role": "shared_order_captions_and_icons",
        "source": "Project-authored presentation registry; no gameplay or persistent state.",
    })
    manifest = {
        "format_version": 1,
        "asset_version": "service-navigation-v3",
        "scope": "Presentation-only compact function navigation; frozen assets, SQL, catalog and player state unchanged.",
        "authoring_script": "jiaoben/build_service_navigation.py",
        "svg_contract": {"size_px": [24, 24], "utf8_without_bom": True, "line_endings": "LF", "static_geometry_only": True, "external_references": False},
        "resources": resources,
    }
    return (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def build(check: bool = False, report: Path | None = None) -> dict:
    expected = manifest_bytes()  # Validate every source before any output write.
    previous = MANIFEST.read_bytes() if MANIFEST.exists() else None
    if check and previous != expected:
        raise ValueError("Service navigation manifest is missing or differs; run the builder")
    changed = previous != expected
    if changed and not check:
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        MANIFEST.write_bytes(expected)
    result = {"status": "PASS", "asset_version": "service-navigation-v3", "resources": 17, "svg_icons": 16,
              "manifest_changed": changed, "manifest_sha256": digest(expected),
              "registry_sha256": digest(REGISTRY.read_bytes()), "utf8_lf": True, "svg_static_xml_24x24": True,
              "verification_scope": "Static source validation; Godot import/render and actual-PCK verification are separate."}
    if report is not None:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify canonical manifest bytes without writing it")
    parser.add_argument("--report", type=Path, help="optional static QA JSON path")
    arguments = parser.parse_args()
    try:
        result = build(arguments.check, arguments.report)
    except (OSError, UnicodeError, ValueError, ET.ParseError) as error:
        parser.exit(1, f"SERVICE_NAVIGATION_ASSETS FAIL: {error}\n")
    print(f"SERVICE_NAVIGATION_ASSETS PASS resources={result['resources']} svg_icons={result['svg_icons']} changed={str(result['manifest_changed']).lower()} sha256={result['manifest_sha256']}")
