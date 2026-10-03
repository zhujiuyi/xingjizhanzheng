#!/usr/bin/env python3
"""Run isolated real-client navigation/overview checks with strict diagnostics."""
from pathlib import Path
import argparse
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--native", action="store_true", help="Requires exclusive Godot Metal window ownership")
parser.add_argument("--audio-driver", choices=("Dummy", "CoreAudio"))
parser.add_argument("--navigation-only", action="store_true", help="Only Main navigation checks while UI work remains in progress")
options = parser.parse_args()
audio = options.audio_driver or "CoreAudio"
stem = "navigation-commands-v6-native" if options.native else "navigation-commands-v6-headless"
if options.navigation_only:
    stem += "-core"
engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
command = ["sh", "jiaoben/run_godot.sh"]
if not options.native:
    command.append("--headless")
command += ["--audio-driver", audio, "--log-file", str(engine_log),
            "--path", "code", "--script", "../jiaoben/tests/navigation_commands_v6.gd"]
try:
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=180,
                            env={**os.environ, "XJ_NAV_TEST_SCOPE": "core" if options.navigation_only else "full"})
except subprocess.TimeoutExpired as error:
    output = error.stdout or b""
    if isinstance(output, bytes):
        output = output.decode("utf-8", errors="replace")
    (ROOT / f"jiaoben/logs/{stem}.log").write_text(output, encoding="utf-8")
    raise SystemExit("NAVIGATION_COMMANDS_V6_GUARD FAIL watchdog") from error
log = ROOT / f"jiaoben/logs/{stem}.log"
log.write_text(result.stdout, encoding="utf-8")
print(result.stdout)
diagnostics = ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")
all_logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
assert result.returncode == 0 and "NAVIGATION_COMMANDS_V6_RESULT PASS" in result.stdout, result.stdout
assert not any(marker in all_logs for marker in diagnostics), all_logs
print("NAVIGATION_COMMANDS_V6_GUARD PASS", log)
