"""Install only the verified Godot macOS/Windows x64 export templates."""
from pathlib import Path
import hashlib
from zipfile import ZipFile
from verify_toolchain_downloads import verify

ROOT = Path(__file__).resolve().parents[1]
verify("templates")
destination = Path.home() / "Library/Application Support/Godot/export_templates/4.7.2.stable"
destination.mkdir(parents=True, exist_ok=True)
with ZipFile(ROOT / "jiaoben/tmp/Godot_v4.7.2-stable_export_templates.tpz") as archive:
    chosen = [name for name in archive.namelist()
              if Path(name).name in ("macos.zip", "version.txt", "icudt_godot.dat")
              or "windows_" in name and "x86_64" in name]
    for name in chosen:
        data = archive.read(name)  # ZIP CRC validated in addition to full archive SHA-256.
        path = destination / Path(name).name
        if path.exists() and hashlib.sha256(path.read_bytes()).digest() != hashlib.sha256(data).digest():
            raise RuntimeError(f"Existing different template preserved: {path.name}")
        path.write_bytes(data)
        print(f"Installed {path.name}")
