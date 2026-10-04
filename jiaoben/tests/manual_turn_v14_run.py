#!/usr/bin/env python3
"""Serialize real Main turning checks, with a compact opposing-view reproducer."""
from pathlib import Path
import argparse
import fcntl
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Requires exclusive native Godot window")
    parser.add_argument("--baseline-only", action="store_true", help="Run only first-tick W+A/D against contrary retained observation")
    parser.add_argument("--expect-defect", action="store_true", help="Baseline only: require both contrary-view first ticks to reproduce the old Main overwrite")
    parser.add_argument("--audio-driver", choices=("Dummy", "CoreAudio"), default="CoreAudio")
    options = parser.parse_args()
    if options.expect_defect and not options.baseline_only:
        parser.error("--expect-defect requires --baseline-only")
    lock_path = ROOT / "jiaoben/tmp/feature-audit.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a") as engine_lock:
        try:
            fcntl.flock(engine_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SystemExit("Another feature audit owns the engine; wait for it to finish") from error
        stem = "manual-turn-v14-" + ("native" if options.native else "headless")
        if options.baseline_only:
            stem += "-baseline"
        if options.expect_defect:
            stem += "-old-defect"
        output_log = ROOT / f"jiaoben/logs/{stem}.log"
        engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
        output_log.parent.mkdir(parents=True, exist_ok=True)
        engine_log.unlink(missing_ok=True)
        command = ["sh", "jiaoben/run_godot.sh"]
        if not options.native:
            command.append("--headless")
        command += ["--audio-driver", options.audio_driver, "--log-file", str(engine_log),
                    "--path", "code", "--script", "../jiaoben/tests/manual_turn_v14.gd"]
        environment = os.environ.copy()
        environment["XJ_MANUAL_TURN_V14_SCOPE"] = "baseline" if options.baseline_only else "full"
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=270,
                                    env=environment)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            if isinstance(output, bytes):
                output = output.decode("utf-8", errors="replace")
            output_log.write_text(output, encoding="utf-8")
            raise SystemExit("MANUAL_TURN_V14_GUARD FAIL watchdog") from error
        output_log.write_text(result.stdout, encoding="utf-8")
        print(result.stdout)
        summaries = [line.removeprefix("MANUAL_TURN_V14_FINAL_JSON ")
                     for line in result.stdout.splitlines()
                     if line.startswith("MANUAL_TURN_V14_FINAL_JSON ")]
        if len(summaries) != 1:
            raise SystemExit("MANUAL_TURN_V14_GUARD FAIL missing/duplicated structured endpoint")
        summary = json.loads(summaries[0])
        (ROOT / f"jiaoben/logs/{stem}.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        all_logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
        if not engine_log.exists() or any(marker in all_logs for marker in
                                         ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")):
            raise SystemExit("MANUAL_TURN_V14_GUARD FAIL strict engine diagnostics; see " + str(engine_log))
        assert summary["baseline_cases"] == 2 and summary["baseline_only"] == options.baseline_only, summary
        assert summary["matrix_cases"] == (0 if options.baseline_only else 216), summary
        assert len(summary["fleet_ship_ids"]) == (0 if options.baseline_only else 9), summary
        if options.expect_defect:
            baseline = summary["samples"]
            assert result.returncode == 1 and summary["result"] == "FAIL" and summary["failures"] == 4, summary
            assert len(baseline) == 2 and {sample["action"] for sample in baseline} == {"yaw_left", "yaw_right"}, baseline
            for sample in baseline:
                sign_value = 1 if sample["action"] == "yaw_left" else -1
                assert sample["scope"] == "opposing_view_baseline", sample
                assert sample["world_yaw_request"] * sign_value < -0.99, sample
                assert sample["first_pose_error_rad"] > sample["budget_rad"] * 1.5, sample
            assert all(label.startswith(("baseline explicit A/D owns first W+A/D request",
                                         "baseline first physical tick turns in the requested direction"))
                       for label in summary["failure_labels"]), summary
            summary["verification"] = "REPRODUCED_OLD_MAIN_OPPOSING_FIRST_TICK"
            (ROOT / f"jiaoben/logs/{stem}.json").write_text(
                json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print("MANUAL_TURN_V14_GUARD REPRODUCED", output_log)
            return
        if result.returncode != 0 or summary["result"] != "PASS" or summary["failures"] != 0:
            raise SystemExit("MANUAL_TURN_V14_GUARD FAIL endpoint or exit; see " + str(output_log))
        print("MANUAL_TURN_V14_GUARD PASS", output_log)


if __name__ == "__main__":
    main()
