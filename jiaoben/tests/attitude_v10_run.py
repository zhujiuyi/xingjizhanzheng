#!/usr/bin/env python3
"""Run real Main attitude recovery and scoped SQLite checks with strict logs."""
from pathlib import Path
import argparse
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Requires exclusive native Godot window ownership")
    options = parser.parse_args()
    stem = "attitude-v10-native" if options.native else "attitude-v10-headless"
    engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
    output_log = ROOT / f"jiaoben/logs/{stem}.log"
    command = ["sh", "jiaoben/run_godot.sh"]
    if not options.native:
        command.append("--headless")
    command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log),
                "--path", "code", "--script", "../jiaoben/tests/attitude_v10.gd"]
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=150,
                                env=os.environ.copy())
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        output_log.write_text(output, encoding="utf-8")
        raise SystemExit("ATTITUDE_V10_GUARD FAIL watchdog") from error
    output_log.write_text(result.stdout, encoding="utf-8")
    print(result.stdout)
    all_logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
    if result.returncode != 0 or "ATTITUDE_V10_RESULT PASS" not in result.stdout:
        raise SystemExit("ATTITUDE_V10_GUARD FAIL endpoint or process exit; see " + str(output_log))
    markers = ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")
    if any(marker in all_logs for marker in markers):
        raise SystemExit("ATTITUDE_V10_GUARD FAIL strict engine diagnostics; see " + str(engine_log))
    print("ATTITUDE_V10_GUARD PASS", output_log)


if __name__ == "__main__":
    main()
