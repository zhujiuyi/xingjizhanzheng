#!/usr/bin/env python3
"""Actual Main/SQLite HUD layout regression with independent strict logs."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--native", action="store_true", help="Root-coordinated exclusive native window")
parser.add_argument("--wide", action="store_true", help="Also verify 1920x1080 at 100 percent")
options = parser.parse_args()
stem = "hud-layout-v9-native" if options.native else "hud-layout-v9-headless"
if options.wide:
    stem += "-wide"
engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
command = ["sh", "jiaoben/run_godot.sh"]
if not options.native:
    command.append("--headless")
command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log),
            "--path", "code", "--script", "../jiaoben/tests/hud_layout_v9.gd"]
try:
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=270,
                            env={**os.environ, "XJ_HUD_V9_WIDE": "1" if options.wide else "0"})
except subprocess.TimeoutExpired as error:
    output = error.stdout or b""
    if isinstance(output, bytes):
        output = output.decode("utf-8", errors="replace")
    (ROOT / f"jiaoben/logs/{stem}.log").write_text(output, encoding="utf-8")
    raise SystemExit("HUD_LAYOUT_V9_GUARD FAIL watchdog") from error
log = ROOT / f"jiaoben/logs/{stem}.log"
log.write_text(result.stdout, encoding="utf-8")
print(result.stdout)
all_logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
assert result.returncode == 0 and "HUD_LAYOUT_V9_RESULT PASS" in result.stdout, result.stdout
assert not any(marker in all_logs for marker in ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")), all_logs
print("HUD_LAYOUT_V9_GUARD PASS", log)
