#!/usr/bin/env python3
"""Run real mission, encounter and salvage services against isolated SQLite."""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Root-coordinated exclusive Metal/CoreAudio window")
    parser.add_argument("--legacy", type=Path, help="Closed v0.8.4 format 5 fixture under jiaoben/tmp; never a personal archive")
    options = parser.parse_args()
    stem = "encounter-mission-v12-native" if options.native else "encounter-mission-v12-headless"
    engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
    output_log = ROOT / f"jiaoben/logs/{stem}.log"
    launcher = ROOT / "jiaoben/tmp/encounter-mission-v12/launcher.gd"
    launcher.parent.mkdir(parents=True, exist_ok=True)
    test_script = ROOT / "jiaoben/tests/encounter_mission_v12.gd"
    launcher.write_text(
        "extends SceneTree\n"
        "func _initialize() -> void:\n"
        "\tcall_deferred(\"_load_test\")\n"
        "func _load_test() -> void:\n"
        f"\tvar source := load({json.dumps(str(test_script))}) as Script\n"
        "\tif source == null:\n"
        "\t\tprinterr(\"ENCOUNTER_MISSION_V12_LAUNCHER FAIL test script unavailable\")\n"
        "\t\tquit(1)\n"
        "\t\treturn\n"
        "\tvar test: Node = source.new()\n"
        "\troot.add_child(test)\n",
        encoding="utf-8",
    )
    environment = os.environ.copy()
    if options.legacy:
        legacy = options.legacy.resolve()
        temporary = (ROOT / "jiaoben/tmp").resolve()
        if not legacy.is_relative_to(temporary) or not legacy.is_file():
            raise SystemExit("Legacy input must be an existing closed test-owned SQLite under jiaoben/tmp")
        environment["XJ_ENCOUNTER_V12_LEGACY"] = str(legacy)
    command = ["sh", "jiaoben/run_godot.sh"]
    if not options.native:
        command.append("--headless")
    command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log),
                "--path", "code", "--script", str(launcher)]
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=420,
                                env=environment)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        output_log.write_text(output, encoding="utf-8")
        raise SystemExit("ENCOUNTER_MISSION_V12_GUARD FAIL watchdog") from error
    output_log.write_text(result.stdout, encoding="utf-8")
    print(result.stdout)
    logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
    if result.returncode != 0 or "ENCOUNTER_MISSION_V12_RESULT PASS" not in result.stdout:
        raise SystemExit("ENCOUNTER_MISSION_V12_GUARD FAIL endpoint or exit: " + str(output_log))
    diagnostic = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:|.*[Ll]eaked.*|.*Resource still in use)", re.M)
    if diagnostic.search(logs):
        raise SystemExit("ENCOUNTER_MISSION_V12_GUARD FAIL strict engine diagnostics: " + str(engine_log))
    print("ENCOUNTER_MISSION_V12_GUARD PASS", output_log)


if __name__ == "__main__":
    main()
