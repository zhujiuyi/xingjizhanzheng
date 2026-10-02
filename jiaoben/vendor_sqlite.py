"""Copy the verified upstream desktop subset; retain its MIT license."""
from pathlib import Path
import hashlib
import shutil
from verify_toolchain_downloads import verify

ROOT = Path(__file__).resolve().parents[1]
verify("sqlite")
source = ROOT / "jiaoben/tmp/sqlite-unpack/addons/godot-sqlite"
target = ROOT / "code/addons/godot-sqlite"
if target.exists():
    raise SystemExit("Existing vendor directory preserved; review before replacement")
target.mkdir(parents=True)
for path in source.iterdir():
    if path.is_file() and path.name != "gdsqlite.gdextension":
        shutil.copy2(path, target / path.name)
(target / "bin").mkdir()
for path in (source / "bin").iterdir():
    if ".macos." in path.name or ".windows." in path.name and ".x86_64." in path.name:
        if path.is_dir():
            shutil.copytree(path, target / "bin" / path.name, symlinks=True)
        else:
            shutil.copy2(path, target / "bin" / path.name)
(target / "gdsqlite.gdextension").write_text('''; Desktop-only library selection from upstream v4.9. Binaries are unchanged.
[configuration]
entry_symbol = "sqlite_library_init"
compatibility_minimum = "4.7"

[libraries]
macos.debug = "res://addons/godot-sqlite/bin/libgdsqlite.macos.template_debug.framework"
macos.release = "res://addons/godot-sqlite/bin/libgdsqlite.macos.template_release.framework"
windows.debug.x86_64 = "res://addons/godot-sqlite/bin/libgdsqlite.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/godot-sqlite/bin/libgdsqlite.windows.template_release.x86_64.dll"
''', encoding="utf-8")
records = []
for path in sorted(target.rglob("*")):
    if path.is_file():
        records.append(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.relative_to(ROOT / "code").as_posix())
notices = ROOT / "code/third_party"
notices.mkdir(exist_ok=True)
(notices / "godot-sqlite-v4.9.sha256").write_text("\n".join(records) + "\n", encoding="utf-8")
print(f"Vendored {len(records)} verified-source files to {target}")
