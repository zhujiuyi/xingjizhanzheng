#!/usr/bin/env python3
"""Run real combat option/targeting/weapon/UI checks using fresh scoped SQLite."""
from pathlib import Path
import argparse
import fcntl
import hashlib
import json
import os
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Exclusive root-coordinated Metal/CoreAudio window")
    options = parser.parse_args()
    stem = "combat-automation-v15-native" if options.native else "combat-automation-v15-headless"
    directory = ROOT / "jiaoben/tmp/combat-automation-v15" / str(uuid.uuid4())
    directory.mkdir(parents=True)
    output_log = ROOT / f"jiaoben/logs/{stem}.log"
    engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
    output_log.parent.mkdir(parents=True, exist_ok=True)
    launcher = directory / "launcher.gd"
    launcher.write_text(
        "extends SceneTree\n"
        "func _initialize() -> void:\n"
        "\tcall_deferred(\"_load_test\")\n"
        "func _load_test() -> void:\n"
        f"\tvar source := load({json.dumps(str(ROOT / 'jiaoben/tests/combat_automation_v15.gd'))}) as Script\n"
        "\tif source == null:\n"
        "\t\tprinterr(\"COMBAT_AUTOMATION_V15_LAUNCHER FAIL script unavailable\")\n"
        "\t\tquit(1)\n"
        "\t\treturn\n"
        "\troot.add_child(source.new())\n",
        encoding="utf-8",
    )
    environment = os.environ.copy()
    environment["XJ_AUTOMATION_V15_DIRECTORY"] = str(directory)
    engine_log.unlink(missing_ok=True)
    lock_path = ROOT / "jiaoben/tmp/feature-audit.lock"
    with lock_path.open("a") as engine_lock:
        try:
            fcntl.flock(engine_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SystemExit("Another audit owns the engine; wait for its completion") from error
        command = ["sh", "jiaoben/run_godot.sh"]
        if not options.native:
            command.append("--headless")
        command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log), "--path", "code", "--script", str(launcher)]
        try:
            result = subprocess.run(command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=420)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            if isinstance(output, bytes):
                output = output.decode("utf-8", errors="replace")
            output_log.write_text(output, encoding="utf-8")
            raise SystemExit("COMBAT_AUTOMATION_V15_GUARD FAIL watchdog") from error
        output_log.write_text(result.stdout, encoding="utf-8")
        print(result.stdout)
        combined = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
        records = [line.removeprefix("COMBAT_AUTOMATION_V15_FINAL_JSON ") for line in result.stdout.splitlines()
                   if line.startswith("COMBAT_AUTOMATION_V15_FINAL_JSON ")]
        assert result.returncode == 0 and "COMBAT_AUTOMATION_V15_RESULT PASS" in result.stdout, output_log
        assert engine_log.exists() and len(records) == 1, "missing engine log or unique result"
        summary = json.loads(records[0])
        assert summary["result"] == "PASS" and summary["failures"] == 0 and summary["toggle_combinations"] == 8, summary
        assert summary["revision"] == "range-buffer-and-large-hull" and summary["large_hull_ticks"] == 25, summary
        assert summary["global_z_cases"] == 2, summary
        assert summary["rendered_flight_captures"] == summary["captures"] if options.native else summary["rendered_flight_captures"] == 0, summary
        assert Path(summary["database_path"]).resolve() == (directory / "progress.db").resolve(), summary
        assert not re.search(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:|.*[Ll]eaked.*|.*Resource still in use)", combined, re.M), engine_log
        images = sorted(directory.glob("*.png"))
        assert len(images) == summary["captures"] and (len(images) >= 5 if options.native else len(images) == 0), summary
        summary["capture_sha256"] = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in images}
        (ROOT / f"jiaoben/logs/{stem}.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("COMBAT_AUTOMATION_V15_GUARD PASS", output_log)


if __name__ == "__main__":
    main()
