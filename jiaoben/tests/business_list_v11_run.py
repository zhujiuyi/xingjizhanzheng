#!/usr/bin/env python3
"""Real business lists, GUI actions, responsive scrolling and scoped SQLite."""
from pathlib import Path
import argparse
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Exclusive native Metal/CoreAudio window")
    options = parser.parse_args()
    stem = "business-list-v11-native" if options.native else "business-list-v11-headless"
    engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
    output_log = ROOT / f"jiaoben/logs/{stem}.log"
    command = ["sh", "jiaoben/run_godot.sh"]
    if not options.native:
        command.append("--headless")
    command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log),
                "--path", "code", "--script", "../jiaoben/tests/business_list_v11.gd"]
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=270,
                                env=os.environ.copy())
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        output_log.write_text(output, encoding="utf-8")
        raise SystemExit("BUSINESS_LIST_V11_GUARD FAIL watchdog") from error
    output_log.write_text(result.stdout, encoding="utf-8")
    print(result.stdout)
    logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
    if result.returncode != 0 or "BUSINESS_LIST_V11_RESULT PASS" not in result.stdout:
        raise SystemExit("BUSINESS_LIST_V11_GUARD FAIL endpoint or exit: " + str(output_log))
    diagnostic = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:|.*[Ll]eaked.*|.*Resource still in use)", re.M)
    if diagnostic.search(logs):
        raise SystemExit("BUSINESS_LIST_V11_GUARD FAIL strict engine diagnostics: " + str(engine_log))
    print("BUSINESS_LIST_V11_GUARD PASS", output_log)


if __name__ == "__main__":
    main()
