#!/usr/bin/env python3
"""Serial full-feature audit; every engine run uses its own output and engine logs."""
from pathlib import Path
import argparse
import hashlib
import fcntl
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
DIAGNOSTIC = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:|.*[Ll]eaked.*|.*Resource still in use)", re.M)
CORE = [
    ("store-historical", "store_native.gd", []),
    ("store-current", "store_native.gd", ["--", "current"]),
    ("store-migration", "store_migration.gd", []),
    ("store-travel", "store_travel_review.gd", []),
    ("gameplay", "gameplay_probe.gd", []),
    ("full-catalog", "full_catalog_gameplay_probe.gd", []),
    ("client", "client_native.gd", []),
    ("combat", "combat_client.gd", []),
    ("ui", "ui_usability.gd", []),
    ("lifecycle", "ui_lifecycle_v2.gd", []),
    ("interaction", "interaction_v3.gd", []),
    ("navigation", "navigation_v3.gd", []),
    ("navigation-commands", "navigation_commands_v6.gd", []),
    ("navigation-geometry", "local_navigation_geometry_v6.gd", []),
    ("navigation-render", "navigation_render_poses_v7.gd", []),
    ("overview", "overview_commands_v7.gd", []),
    ("camera-pointer", "camera_pointer_v7.gd", []),
    ("attitude", "attitude_v10.gd", []),
    ("visibility", "flight_visibility_v4.gd", []),
    ("targets", "target_annotations_v5.gd", []),
    ("mining", "mining_resources_v8.gd", []),
    ("hud", "hud_layout_v9.gd", []),
    ("business", "business_list_v11.gd", []),
    ("scene", "scene_rendering_v7.gd", []),
]
NATIVE = [entry for entry in CORE if entry[0] in {
    "client", "combat", "ui", "lifecycle", "business", "navigation", "interaction",
}]


def prepare_catalog_fixture() -> None:
    fixture = ROOT / "jiaoben/tmp/audit-catalog-v090.db"
    expected = "c89a3b5f01f900c1be90550ba98805fe9b9c6049967eaf8def8aa0267c3a4492"
    if fixture.exists():
        data = fixture.read_bytes()
    else:
        data = subprocess.run(
            ["git", "show", "c2ac4ae5eb43dc9ab052f09ea5d2a72c542edf4c:code/data/catalog.db"],
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        ).stdout
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit("Historical audit fixture identity differs; preserve it and inspect before proceeding")
    if not fixture.exists():
        fixture.parent.mkdir(parents=True, exist_ok=True)
        fixture.write_bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Exclusive Metal/CoreAudio window")
    parser.add_argument("--only", nargs="+", help="Selected audit names")
    parser.add_argument("--merge", action="store_true", help="Replace selected results in this mode's existing summary")
    args = parser.parse_args()
    lock_path = ROOT / "jiaoben/tmp/feature-audit.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    audit_lock = lock_path.open("a")
    try:
        fcntl.flock(audit_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("Another feature audit owns the engine window; wait for it to finish")
    runs = NATIVE if args.native and not args.only else CORE
    # New supplemental probes are discovered only by these explicit safe names.
    for name, script in [("progression", "progression_audit.gd"),
                         ("economy", "economy_integrity_audit.gd"),
                         ("modules", "module_activation_audit.gd"),
                         ("echo-content", "echo_content_audit.gd"),
                         ("loan-cleanup", "loan_cleanup_audit.gd"),
                         ("legacy-capacity", "legacy_module_capacity_audit.gd")]:
        if not args.native and (ROOT / "jiaoben/tests" / script).exists():
            runs = [*runs, (name, script, [])]
    if args.only:
        known = {name for name, _, _ in runs}
        if set(args.only) - known:
            parser.error("Unknown audit names: " + ", ".join(sorted(set(args.only) - known)))
        runs = [entry for entry in runs if entry[0] in args.only]
    if any(name in {"echo-content", "legacy-capacity"} for name, _, _ in runs):
        prepare_catalog_fixture()
    mode = "native" if args.native else "headless"
    records = []
    for name, script, extra in runs:
        stem = f"audit-{name}-{mode}"
        engine_log = ROOT / "jiaoben/logs" / f"{stem}-engine.log"
        output_log = ROOT / "jiaoben/logs" / f"{stem}.log"
        engine_log.unlink(missing_ok=True)
        command = ["sh", "jiaoben/run_godot.sh"]
        if not args.native:
            command.append("--headless")
        command += ["--audio-driver", "CoreAudio", "--log-file", str(engine_log),
                    "--path", "code", "--script", f"../jiaoben/tests/{script}", *extra]
        print(f"RUN {name} ({mode})", flush=True)
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=420)
            output = result.stdout
            exit_code = result.returncode
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            if isinstance(output, bytes):
                output = output.decode("utf-8", errors="replace")
            exit_code = -1
        output_log.write_text(output, encoding="utf-8")
        combined = output + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
        endpoint = re.search(r"(?:\w+_RESULT (?:PASS|FAIL)|(?:GAMEPLAY_PROBE|FULL_CATALOG_GAMEPLAY_PROBE) checks=|(?:LOCAL_NAV_GEOMETRY|NAVIGATION_RENDER_POSES_V7|SCENE_RENDERING_V7|CAMERA_MOTION_V7) (?:PASS|FAIL))[^\n]*", output)
        diagnostics = DIAGNOSTIC.findall(combined)
        passed = exit_code == 0 and endpoint is not None and (
            "_RESULT PASS" in endpoint.group() or "failures=0" in endpoint.group()
        ) and not diagnostics
        record = dict(name=name, mode=mode, passed=passed, exit_code=exit_code,
                      endpoint=endpoint.group() if endpoint else "missing", diagnostics=diagnostics,
                      output=str(output_log), engine_log=str(engine_log))
        records.append(record)
        print(json.dumps(record, ensure_ascii=False), flush=True)
    summary = ROOT / "jiaoben/logs" / f"feature-audit-{mode}.json"
    if args.merge and summary.exists():
        previous = json.loads(summary.read_text(encoding="utf-8"))
        replaced = {record["name"] for record in records}
        records = [record for record in previous if record["name"] not in replaced] + records
    summary.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    passed = all(record["passed"] for record in records)
    print(f"FEATURE_AUDIT_RESULT {'PASS' if passed else 'FAIL'} suites={len(records)} summary={summary}")
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
