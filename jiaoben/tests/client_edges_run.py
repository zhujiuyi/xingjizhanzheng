#!/usr/bin/env python3
"""Bound native lifecycle test, killing the process on script errors/timeouts."""
from pathlib import Path
import re
import subprocess
ROOT = Path(__file__).resolve().parents[2]
command = ["sh", "jiaoben/run_godot.sh", "--headless", "--path", "code", "--script", "../jiaoben/tests/client_edges.gd"]
result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
log = ROOT / "jiaoben/logs/client-edges.log"
log.write_text(result.stdout, encoding="utf-8")
print(result.stdout)
# Main logs a deliberately rejected staging callback. Other errors fail QA.
errors = re.findall(r"^ERROR: (.*)$", result.stdout, re.M)
assert result.returncode == 0 and "CLIENT_EDGES_RESULT PASS" in result.stdout and "SCRIPT ERROR:" not in result.stdout
assert all(error.startswith("STAGING_FAILED") for error in errors), errors
print("CLIENT_EDGES_GUARD PASS", log)
