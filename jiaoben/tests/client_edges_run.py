#!/usr/bin/env python3
"""Bound native lifecycle test, killing the process on script errors/timeouts."""
from pathlib import Path
import argparse
import re
import subprocess
ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description="Native lifecycle assertions and strict exit guard")
parser.add_argument("--audio-driver", choices=("CoreAudio", "Dummy"), help="Mac native audio or headless Dummy; defaults to Godot's headless driver")
test_options = parser.parse_args()
log_stem = "client-edges-coreaudio" if test_options.audio_driver == "CoreAudio" else "client-edges"
command = ["sh", "jiaoben/run_godot.sh", "--headless"]
if test_options.audio_driver:
    command += ["--audio-driver", test_options.audio_driver]
if test_options.audio_driver == "CoreAudio":
    # Preserve the actual backend identity in the native validation evidence.
    command += ["--verbose"]
command += ["--log-file", str(ROOT / f"jiaoben/tmp/{log_stem}-godot.log"), "--path", "code", "--script", "../jiaoben/tests/client_edges.gd"]
result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
log = ROOT / f"jiaoben/logs/{log_stem}.log"
log.write_text(result.stdout, encoding="utf-8")
print(result.stdout)
# Only the two deliberate staging rejections are expected. Teardown warnings
# and leaked resources remain failures, even if all functional assertions pass.
errors = re.findall(r"^ERROR: (.*)$", result.stdout, re.M)
assert result.returncode == 0 and "CLIENT_EDGES_RESULT PASS" in result.stdout and "SCRIPT ERROR:" not in result.stdout
assert errors == ["STAGING_FAILED", "STAGING_FAILED injected candidate construction failure"], errors
assert "WARNING:" not in result.stdout and "leaked at exit" not in result.stdout, result.stdout
print("CLIENT_EDGES_GUARD PASS", log)
