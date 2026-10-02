#!/usr/bin/env python3
"""Bound the isolated native Main interaction test and reject engine diagnostics."""
from pathlib import Path
import argparse
import subprocess

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description="Interaction eligibility, real Main inputs and strict exit guard")
parser.add_argument("--audio-driver", choices=("Dummy", "CoreAudio"))
parser.add_argument("--native", action="store_true", help="Use macOS Metal window with CoreAudio unless overridden")
options = parser.parse_args()
audio_driver = options.audio_driver or ("CoreAudio" if options.native else "Dummy")
stem = "interaction-v3-native" if options.native else ("interaction-v3-coreaudio" if audio_driver == "CoreAudio" else "interaction-v3")
command = ["sh", "jiaoben/run_godot.sh"]
if not options.native:
    command.append("--headless")
command += ["--audio-driver", audio_driver,
           "--log-file", str(ROOT / f"jiaoben/tmp/{stem}-engine.log"),
           "--path", "code", "--script", "../jiaoben/tests/interaction_v3.gd"]
result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True, timeout=45)
log = ROOT / f"jiaoben/logs/{stem}.log"
log.write_text(result.stdout, encoding="utf-8")
print(result.stdout)
assert result.returncode == 0 and "INTERACTION_V3_RESULT PASS" in result.stdout
assert not any(marker in result.stdout for marker in ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")), result.stdout
print("INTERACTION_V3_GUARD PASS", log)
