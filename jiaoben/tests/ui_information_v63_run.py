"""Run scoped information hierarchy checks with a real window and strict logs.

Source: py jiaoben/tests/ui_information_v63_run.py
PCK: add --executable <verified Windows 0.34.0.0 EXE>.
Both routes use a fresh UUID and the same shared engine lock.
"""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import time
import uuid

from ui_quality_audit_run import (
    ROOT, DIAGNOSTIC, sha, ui_source_snapshot, inspect_release_binary, write_source_launcher,
)


def run(args):
    binary = (args.executable or args.engine).resolve()
    if not binary.is_file():
        raise RuntimeError(f"Diagnostic executable does not exist: {binary}")
    release_identity = inspect_release_binary(binary) if args.executable else None
    run_id = str(uuid.uuid4())
    directory = ROOT / "jiaoben/tmp/ui-information-v63" / run_id
    directory.mkdir(parents=True, exist_ok=False)
    script = ROOT / "jiaoben/tests/ui_information_v63.gd"
    tests = (script, ROOT / "jiaoben/tests/ui_interaction_consistency.gd", ROOT / "jiaoben/tests/ui_quality_audit.gd")
    source_start = ui_source_snapshot()
    test_start = {path.as_posix(): sha(path) for path in tests}
    stem = f"ui-information-v63-{'release' if args.executable else 'source'}-{'headless' if args.headless else 'native'}-{run_id}"
    output = ROOT / "jiaoben/logs" / f"{stem}.log"
    engine_log = output.with_name(f"{stem}-engine.log")
    report = output.with_suffix(".json")
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.pop("XJ_TEST_DATABASE", None)
    env["XJ_UI_INFORMATION_V63_DIRECTORY"] = directory.as_posix()
    env["XJ_UI_INFORMATION_V63_SCRIPT"] = script.as_posix()
    command = [str(binary), "--audio-driver", "WASAPI"] + (["--headless"] if args.headless else [])
    if args.executable:
        command += ["--log-file", engine_log.as_posix(), "--", "--xj-verify-ui-information-v63"]
    else:
        launcher = write_source_launcher(directory, script)
        command += ["--path", (ROOT / "code").as_posix(), "--script", launcher.as_posix(), "--log-file", engine_log.as_posix()]
    record = {
        "mode": ("release-" if args.executable else "source-") + ("headless" if args.headless else "native"),
        "engine": str(binary), "engine_sha256": sha(binary), "release_identity": release_identity,
        "pck_sha256": sha(binary.with_suffix(".pck")) if args.executable and binary.with_suffix(".pck").is_file() else None,
        "directory": str(directory), "script": str(script), "test_sha256": test_start,
        "ui_source_sha256": source_start, "stdout": str(output), "engine_log": str(engine_log),
        "command": command, "source_revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "catalog_sha256": sha(ROOT / "code/data/catalog.db"),
    }
    print(f"START {stem}", flush=True)
    started = time.monotonic()
    with output.open("wb") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        try:
            record["exit_code"] = process.wait(timeout=480)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()
            record.update(exit_code=process.returncode, timed_out=True)
    text = output.read_text(encoding="utf-8", errors="replace")
    engine_text = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
    record.update({
        "seconds": round(time.monotonic() - started, 2), "stdout_sha256": sha(output),
        "engine_log_sha256": sha(engine_log) if engine_log.exists() else None,
        "diagnostics": [line for line in (text + engine_text).splitlines() if DIAGNOSTIC.search(line)],
        "test_changed_during_run": any(sha(Path(path)) != value for path, value in test_start.items()),
        "ui_source_changed_during_run": ui_source_snapshot() != source_start,
    })
    result_path = directory / "result.json"
    if result_path.exists():
        record["result_path"] = str(result_path)
        record["result_sha256"] = sha(result_path)
        record["summary"] = json.loads(result_path.read_text(encoding="utf-8"))
    captures = sorted(directory.glob("*.png"))
    record["captures"] = [{"path": str(path), "sha256": sha(path)} for path in captures]
    report.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"REPORT {report}", flush=True)
    assert record["exit_code"] == 0 and engine_log.exists(), f"Information UI engine failed: {output}"
    assert not record["test_changed_during_run"] and not record["ui_source_changed_during_run"], "Tests/UI changed during run"
    assert not record["diagnostics"], f"Strict dual-log diagnostics: {record['diagnostics'][:8]}"
    assert re.search(r"^UI_INFORMATION_V63_RESULT PASS checks=\d+ failures=0", text, re.M), "Complete successful endpoint missing"
    assert result_path.exists() and record["summary"]["result"] == "PASS" and record["summary"]["failures"] == 0
    assert len(record["summary"]["capability_matrix"]) == 18 and len(record["summary"]["actual_hulls"]) == 3
    assert len(record["summary"]["phase_observations"]) == 3 and record["summary"]["interaction_checks"] > 0
    assert len(captures) == (0 if args.headless else record["summary"]["captures"])
    if not args.headless:
        assert record["summary"]["native"] and len(captures) > 0, "Native window evidence missing"
    assert not re.search(r"^FAIL(?:\s|$)", text, re.M), "Nested assertion failed"
    print(f"UI_INFORMATION_V63_ACCEPTANCE PASS checks={record['summary']['checks']} {report}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=Path("D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe"))
    parser.add_argument("--executable", type=Path, help="Actual Windows 0.34.0.0 PCK; fixed v63 flag only")
    parser.add_argument("--headless", action="store_true", help="Dispatch/structure only; not native-window acceptance")
    args = parser.parse_args()
    import msvcrt
    lock_path = ROOT / "jiaoben/tmp/feature-audit.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+b") as lock:
        lock.seek(0); lock.write(b"0"); lock.flush(); lock.seek(0)
        msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            run(args)
        finally:
            lock.seek(0); msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


if __name__ == "__main__":
    main()
