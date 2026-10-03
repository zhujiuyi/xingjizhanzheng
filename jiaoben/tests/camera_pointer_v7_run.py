#!/usr/bin/env python3
"""Run new pointer/keyboard/camera contract with fresh SQLite and strict logs."""
from pathlib import Path
import argparse
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--native", action="store_true", help="Requires exclusive native Godot window ownership")
parser.add_argument("--components-only", action="store_true", help="Run camera/keyboard components while Main is being integrated")
options = parser.parse_args()
stem = "camera-pointer-v7-native" if options.native else "camera-pointer-v7-headless"
if options.components_only:
    stem += "-components"
engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
command = ["sh", "jiaoben/run_godot.sh"]
if not options.native:
    command.append("--headless")
command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log),
            "--path", "code", "--script", "../jiaoben/tests/camera_pointer_v7.gd"]
try:
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=150,
                            env={**os.environ, "XJ_CAMERA_V7_SCOPE": "components" if options.components_only else "full"})
except subprocess.TimeoutExpired as error:
    output = error.stdout or b""
    if isinstance(output, bytes):
        output = output.decode("utf-8", errors="replace")
    (ROOT / f"jiaoben/logs/{stem}.log").write_text(output, encoding="utf-8")
    raise SystemExit("CAMERA_POINTER_V7_GUARD FAIL watchdog") from error
log = ROOT / f"jiaoben/logs/{stem}.log"
log.write_text(result.stdout, encoding="utf-8")
print(result.stdout)
all_logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
assert result.returncode == 0 and "CAMERA_POINTER_V7_RESULT PASS" in result.stdout, result.stdout
assert not any(marker in all_logs for marker in ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")), all_logs
print("CAMERA_POINTER_V7_GUARD PASS", log)
