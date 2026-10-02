#!/usr/bin/env python3
"""Bound the isolated Main model-failure probe and reject all engine diagnostics."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
engine_log = ROOT / "jiaoben/tmp/presentation-failures-engine.log"
output_log = ROOT / "jiaoben/logs/presentation-failures.log"
command = ["sh", "jiaoben/run_godot.sh", "--headless", "--audio-driver", "CoreAudio",
           "--log-file", str(engine_log), "--path", "code", "--script",
           "../jiaoben/tests/presentation_failures.gd"]
result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True, timeout=30)
output_log.write_text(result.stdout, encoding="utf-8")
print(result.stdout)
assert result.returncode == 0 and "PRESENTATION_FAILURES_RESULT PASS" in result.stdout
diagnostics = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
assert not any(marker in diagnostics for marker in ("SCRIPT ERROR:", "ERROR:", "WARNING:",
               "leaked at exit", "Leaked instance:", "Resource still in use")), diagnostics
print("PRESENTATION_FAILURES_GUARD PASS", output_log)
