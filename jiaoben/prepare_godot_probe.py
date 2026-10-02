"""Prepare a disposable Godot project from reviewed probes and current formal assets."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "jiaoben/tmp/godot-sqlite-probe"
SOURCE = ROOT / "jiaoben/probes/godot_sqlite"
DEST.mkdir(parents=True, exist_ok=True)
for name in ("sqlite_probe.gd", "probe.tscn", "render_probe.gd", "render_probe.tscn", "pipeline_probe.gd"):
    shutil.copy2(SOURCE / name, DEST / name)
(DEST / "data").mkdir(exist_ok=True)
shutil.copy2(ROOT / "code/data/catalog.db", DEST / "data/catalog.db")
subprocess.run(["ditto", str(ROOT / "code/addons"), str(DEST / "addons")], check=True)

# Godot's platform user directory is redirected using a dedicated symlink;
# all disposable state physically remains inside jiaoben/tmp.
userdata = ROOT / "jiaoben/tmp/godot-probe-userdata"
userdata.mkdir(exist_ok=True)
link = Path.home() / "Library/Application Support/Godot/app_userdata/XingjiDatabaseProbe"
link.parent.mkdir(parents=True, exist_ok=True)
if link.is_symlink():
    if link.resolve() != userdata.resolve():
        raise RuntimeError("Existing probe symlink has a different destination")
elif link.exists():
    raise RuntimeError("Existing user directory is preserved; choose a new probe name")
else:
    link.symlink_to(userdata, target_is_directory=True)

(DEST / "project.godot").write_text('''config_version=5

[application]
config/name="XingjiDatabaseProbe"
run/main_scene="res://probe.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")

[rendering]
renderer/rendering_method="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
textures/vram_compression/import_s3tc_bptc=true

[debug]
file_logging/enable_file_logging=false
''', encoding="utf-8")

(DEST / "export_presets.cfg").write_text('''[preset.0]
name="macOS Probe"
platform="macOS"
runnable=true
export_filter="all_resources"
include_filter="*.db,*.sql,addons/godot-sqlite/LICENSE.md"
exclude_filter=""
export_path="../probe-export/mac/XingjiDatabaseProbe.app"

[preset.0.options]
application/bundle_identifier="local.xingjizhanjian.databaseprobe"
application/short_version="0.3"
application/version="0.3"
codesign/codesign=3
codesign/identity="-"
codesign/entitlements/disable_library_validation=true
notarization/notarization=0

[preset.1]
name="Windows Probe"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.db,*.sql,addons/godot-sqlite/LICENSE.md"
exclude_filter=""
export_path="../probe-export/windows/XingjiDatabaseProbe.exe"

[preset.1.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
codesign/enable=false
application/product_name="XingjiDatabaseProbe"
application/file_version="0.3.0.0"
application/product_version="0.3.0.0"
''', encoding="utf-8")
print(DEST)
