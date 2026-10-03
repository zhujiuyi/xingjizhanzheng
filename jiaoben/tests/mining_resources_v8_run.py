#!/usr/bin/env python3
"""Execute fresh Main mining/resource regressions with isolated strict logs."""
from pathlib import Path
import argparse
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--native", action="store_true", help="Requires root's exclusive native window coordination")
parser.add_argument("--core", action="store_true", help="Explicit finite mining/persistence checks without UI assertions")
options = parser.parse_args()
stem = "mining-resources-v8-native" if options.native else "mining-resources-v8-headless"
if options.core:
    stem += "-core"
engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
command = ["sh", "jiaoben/run_godot.sh"]
if not options.native:
    command.append("--headless")
command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log),
            "--path", "code", "--script", "../jiaoben/tests/mining_resources_v8.gd"]
try:
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=180,
                            env={**os.environ, "XJ_MINING_V8_SCOPE": "core" if options.core else "full"})
except subprocess.TimeoutExpired as error:
    output = error.stdout or b""
    if isinstance(output, bytes):
        output = output.decode("utf-8", errors="replace")
    (ROOT / f"jiaoben/logs/{stem}.log").write_text(output, encoding="utf-8")
    raise SystemExit("MINING_RESOURCES_V8_GUARD FAIL watchdog") from error
log = ROOT / f"jiaoben/logs/{stem}.log"
log.write_text(result.stdout, encoding="utf-8")
print(result.stdout)
all_logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
assert result.returncode == 0 and "MINING_RESOURCES_V8_RESULT PASS" in result.stdout, result.stdout
assert not any(marker in all_logs for marker in ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")), all_logs
print("MINING_RESOURCES_V8_GUARD PASS", log)
