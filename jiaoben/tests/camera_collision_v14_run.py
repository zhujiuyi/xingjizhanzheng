#!/usr/bin/env python3
"""Serialize real Main collision checks and enforce independent strict evidence."""
from pathlib import Path
import argparse
import fcntl
import json
import os
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--baseline", action="store_true", help="Require a reproduced test failure; never a release PASS")
    args = parser.parse_args()
    run_id = str(uuid.uuid4())
    directory = ROOT / "jiaoben/tmp/camera-collision-v14" / run_id
    directory.mkdir(parents=True)
    stem = "camera-collision-v14-" + ("native" if args.native else "headless")
    if args.baseline:
        stem += "-baseline"
    log = ROOT / "jiaoben/logs" / f"{stem}-{run_id}.log"
    engine_log = log.with_name(log.stem + "-engine.log")
    summary_path = log.with_suffix(".json")
    lock = ROOT / "jiaoben/tmp/feature-audit.lock"
    with lock.open("a") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SystemExit("Another Godot acceptance owns the shared lock") from error
        command = ["sh", "jiaoben/run_godot.sh"]
        if not args.native:
            command.append("--headless")
        command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log),
                    "--path", "code", "--script", "../jiaoben/tests/camera_collision_v14.gd"]
        environment = os.environ.copy()
        environment["XJ_CAMERA_V14_DIR"] = str(directory)
        try:
            result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=270)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            if isinstance(output, bytes):
                output = output.decode("utf-8", errors="replace")
            log.write_text(output, encoding="utf-8")
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL watchdog") from error
        log.write_text(result.stdout, encoding="utf-8")
        print(result.stdout)
        summaries = [line.removeprefix("CAMERA_COLLISION_V14_FINAL_JSON ")
                     for line in result.stdout.splitlines()
                     if line.startswith("CAMERA_COLLISION_V14_FINAL_JSON ")]
        if len(summaries) != 1 or not engine_log.exists():
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL missing unique structured result or engine log")
        summary = json.loads(summaries[0])
        summary.update({"output_log": str(log), "engine_log": str(engine_log), "baseline": args.baseline})
        summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        all_logs = result.stdout + engine_log.read_text(encoding="utf-8")
        if any(marker in all_logs for marker in ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")):
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL strict engine diagnostics; see " + str(engine_log))
        if summary["geometry_cases"] != 264:
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL incomplete geometry matrix")
        cadence = summary.get("render_cadence", [])
        expected_cadence = [(case, fps) for case in ("station-face", "gate-face") for fps in (30, 60, 144)]
        if [(item["case"], item["requested_max_fps"]) for item in cadence] != expected_cadence:
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL incomplete actual frame-cadence evidence")
        if any(item["samples"] != 20 or item["process_frame_advances"] < 20 for item in cadence):
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL incomplete actual process-frame sampling")
        if any(not item["physics_interpolation"] or len(item.get("moving_origin_samples", [])) != 3 for item in cadence):
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL missing actual interpolated moving-origin evidence")
        front_geometry = summary.get("front_geometry", [])
        if len(front_geometry) != 18 or len({item["ship"] for item in front_geometry}) != 9:
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL incomplete nine-hull FRONT collision evidence")
        recovery = summary.get("distance_recovery", [])
        if [item["fps_delta_model"] for item in recovery] != [30, 60, 144]:
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL incomplete safe short-arm distance recovery evidence")
        if any(not item["initial_sphere_safe"] or not item["direct_shortcut_blocked"] or len(item["steps"]) != 24 for item in recovery):
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL invalid blocked-shortcut recovery fixture")
        if args.baseline:
            if result.returncode != 1 or summary["result"] != "FAIL" or summary["failures"] < 1:
                raise SystemExit("CAMERA_COLLISION_V14_BASELINE FAIL no defect reproduced")
            print("CAMERA_COLLISION_V14_BASELINE REPRODUCED", summary_path)
            return
        if result.returncode != 0 or summary["result"] != "PASS" or summary["failures"] != 0:
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL actual endpoint; see " + str(summary_path))
        if len(summary["captures"]) != (4 if args.native else 0):
            raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL incomplete native capture evidence")
        for name in summary["captures"]:
            if not Path(name).is_file():
                raise SystemExit("CAMERA_COLLISION_V14_GUARD FAIL missing rendered capture")
        print("CAMERA_COLLISION_V14_GUARD PASS", summary_path)


if __name__ == "__main__":
    main()
