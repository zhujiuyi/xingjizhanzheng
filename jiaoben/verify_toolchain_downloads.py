"""Verify downloaded official packages; never install or execute a package."""
from pathlib import Path
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "jiaoben/tmp"


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify(name):
    if name == "blender":
        filename = "blender-4.5.14-macos-arm64.dmg"
        records = [line.split() for line in (TMP / "blender-4.5.14.sha256").read_text().splitlines()]
        expected = next(row[0] for row in records if row[-1].lstrip("*") == filename)
    else:
        metadata = "sqlite-release.json" if name == "sqlite" else "godot-release.json"
        asset_name = {"godot": "Godot_v4.7.2-stable_macos.universal.zip",
                      "templates": "Godot_v4.7.2-stable_export_templates.tpz",
                      "sqlite": "addons.zip"}[name]
        filename = "godot-sqlite-v4.9-addons.zip" if name == "sqlite" else asset_name
        release = json.loads((TMP / metadata).read_text(encoding="utf-8"))
        asset = next(item for item in release["assets"] if item["name"] == asset_name)
        algorithm, expected = asset["digest"].split(":", 1)
        assert algorithm == "sha256"
        assert (TMP / filename).stat().st_size == asset["size"], "Size mismatch"
    actual = digest(TMP / filename)
    if actual != expected:
        raise ValueError(f"Checksum mismatch: {filename}")
    print(f"VERIFIED {filename} sha256={actual}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="+", choices=("godot", "templates", "sqlite", "blender"))
    for package in parser.parse_args().packages:
        verify(package)
