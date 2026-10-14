"""Native loading-failure regression; fixed errors, fresh DB, strict dual logs.

Source: py jiaoben/tests/loading_failure_run.py
PCK: add --executable <Windows 0.33.1.0 executable>, fixed v62 endpoint only.
The two expected error headers must occur exactly once in EACH independent log.
The test report cannot add messages to this whitelist.
"""
from pathlib import Path
import argparse
import importlib.util
import json
import mmap
import os
import re
import subprocess
import time
import uuid

from startup_navigation_run import ROOT, sha, source_identity

FLAG = "--xj-verify-loading-failure-v62"
ENV_PREFIX = "XJ_LOADING_FAILURE_V62"
TIMEOUT_SECONDS = 120
EXPECTED_ERRORS = (
    "ERROR: Missing save slot",
    "ERROR: STAGING_FAILED loading-failure-v62 injected candidate construction failure",
)
EXPECTED_CASES = {
    "missing_slot_preserves_world",
    "prepare_rejection_preserves_world_and_blocks_old_callbacks",
    "close_while_prepare_joins_before_store_close",
}
DIAGNOSTIC = re.compile(r"^(?:\s*(?:SCRIPT ERROR|ERROR|WARNING):|.*[Ll]eak(?:ed|ing)?\b|.*Resource still in use)")


def audit_log(content):
    counts = dict.fromkeys(EXPECTED_ERRORS, 0)
    unexpected = []
    for line in content.splitlines():
        if not DIAGNOSTIC.search(line):
            continue
        normalized = line.strip()
        if normalized in counts:
            counts[normalized] += 1
        else:
            unexpected.append(line)
    return {"expected_error_counts": counts, "unexpected_diagnostics": unexpected,
            "accepted": all(count == 1 for count in counts.values()) and not unexpected}


def run(args):
    binary = (args.executable or args.engine).resolve()
    if not binary.is_file():
        raise RuntimeError(f"Engine/client not found: {binary}")
    version = None
    if args.executable:
        spec = importlib.util.spec_from_file_location("failure_build_metadata", ROOT / "jiaoben/build_client.py")
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        version = module.inspect_windows_binary_version(binary, "0.33.1.0")
        if version.get("result") != "PASS":
            raise RuntimeError("Windows version metadata did not verify 0.33.1.0")
        pck = binary.with_suffix(".pck")
        if not pck.is_file():
            raise RuntimeError("Actual external client PCK is missing")
        with pck.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as packed:
            if packed.find(FLAG.encode("ascii")) < 0:
                raise RuntimeError("Client lacks the fixed loading-failure-v62 diagnostic; it was not launched")
    run_id = str(uuid.uuid4())
    directory = ROOT / "jiaoben/tmp/loading-failure-v62" / run_id
    directory.mkdir(parents=True, exist_ok=False)
    script = ROOT / "jiaoben/tests/loading_failure_v62.gd"
    if not script.is_file():
        raise RuntimeError(f"Fixed diagnostic test is missing: {script}")
    dependencies = [script, Path(__file__).resolve(), ROOT / "jiaoben/tests/startup_navigation_run.py"]
    inherited = ROOT / "jiaoben/tests/startup_navigation_v62.gd"
    if inherited.is_file(): dependencies.append(inherited)
    test_start = {str(path): sha(path) for path in dependencies}
    source_start = source_identity()
    stem = f"loading-failure-{'release' if args.executable else 'source'}-native-{run_id}"
    output = ROOT / "jiaoben/logs" / (stem + ".log")
    engine_log = output.with_name(stem + "-engine.log")
    report = output.with_suffix(".json")
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy(); env.pop("XJ_TEST_DATABASE", None)
    env[ENV_PREFIX + "_SCRIPT"] = script.as_posix()
    env[ENV_PREFIX + "_DIRECTORY"] = directory.as_posix()
    command = [str(binary), "--audio-driver", "WASAPI", "--log-file", engine_log.as_posix()]
    if args.executable:
        command += ["--", FLAG]
    else:
        launcher = directory / "launcher.gd"
        launcher.write_text("extends SceneTree\nfunc _initialize() -> void:\n\tcall_deferred(\"_start\")\nfunc _start() -> void:\n"
                            f"\tvar source: Script = load({json.dumps(script.as_posix(), ensure_ascii=False)})\n"
                            "\tif source == null or not source.can_instantiate():\n\t\tquit(2)\n\t\treturn\n\troot.add_child(source.new())\n",
                            encoding="utf-8", newline="\n")
        command += ["--path", (ROOT / "code").as_posix(), "--script", launcher.as_posix()]
    record = {"mode": "release-native" if args.executable else "source-native", "engine": str(binary),
              "engine_sha256": sha(binary), "windows_version": version, "command": command,
              "pck_sha256": sha(binary.with_suffix(".pck")) if args.executable else None,
              "source_sha256": source_start, "test_sha256": test_start,
              "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "directory": str(directory), "stdout": str(output), "engine_log": str(engine_log),
              "timeout_seconds": TIMEOUT_SECONDS, "fixed_expected_errors_per_log": list(EXPECTED_ERRORS)}
    print(f"START {stem}", flush=True)
    started = time.monotonic()
    with output.open("wb") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        record["pid"] = process.pid
        try:
            record["exit_code"] = process.wait(timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()
            record.update(exit_code=process.returncode, timed_out=True)
    stdout = output.read_text(encoding="utf-8", errors="replace")
    engine = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
    record.update(seconds=round(time.monotonic() - started, 3), stdout_sha256=sha(output),
                  engine_log_sha256=sha(engine_log) if engine_log.exists() else None,
                  log_audits={"stdout": audit_log(stdout), "engine": audit_log(engine)},
                  source_changed_during_run=source_identity() != source_start,
                  test_changed_during_run=any(not Path(path).is_file() or sha(Path(path)) != value for path, value in test_start.items()))
    result_path = directory / "result.json"
    if result_path.is_file():
        record["result_path"] = str(result_path); record["result_sha256"] = sha(result_path)
        try:
            record["summary"] = json.loads(result_path.read_text(encoding="utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            record["result_parse_error"] = str(exc)
    record["captures"] = [{"path": str(path), "sha256": sha(path)} for path in sorted(directory.glob("*.png"))]
    report.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"REPORT {report}", flush=True)
    assert record["exit_code"] == 0 and not record.get("timed_out") and engine_log.is_file(), f"Loading failure engine did not complete: {output}"
    assert all(value["accepted"] for value in record["log_audits"].values()), f"Strict fixed dual-log policy rejected diagnostics: {record['log_audits']}"
    assert not record["source_changed_during_run"] and not record["test_changed_during_run"], "Source or test identity changed during execution"
    assert re.search(r"^LOADING_FAILURE_V62_RESULT PASS checks=\d+ failures=0(?:\s|$)", stdout, re.M), "Successful fixed endpoint missing"
    assert not re.search(r"^FAIL(?:\s|$)", stdout, re.M), "Nested assertion failed"
    summary = record.get("summary", {})
    assert summary.get("result") == "PASS" and type(summary.get("checks")) is int and summary["checks"] > 0
    assert type(summary.get("failures")) is int and summary["failures"] == 0 and summary.get("failure_labels") == []
    assert Path(summary.get("directory", "")).resolve() == directory.resolve(), "Result points outside its fresh scoped database"
    cases = summary.get("cases", [])
    assert isinstance(cases, list) and len(cases) == 3 and all(isinstance(case, dict) for case in cases), "All three failure-recovery cases are required"
    assert {case.get("id") for case in cases} == EXPECTED_CASES, "The fixed three failure-recovery routes must all complete"
    assert all(case.get("passed") is True and type(case.get("checks")) is int and case["checks"] > 0
               and type(case.get("failures")) is int and case["failures"] == 0 for case in cases), "Every fixed case must complete actual checks without failure"
    assert summary.get("expected_diagnostics") == [{"message": message, "count_per_log": 1} for message in EXPECTED_ERRORS], "Report diagnostic evidence differs from the fixed runner policy"
    if args.executable:
        assert summary.get("packed_runtime"), "Actual PCK runtime was not confirmed"
    print(f"LOADING_FAILURE_ACCEPTANCE PASS checks={summary['checks']} {report}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=Path("D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe"))
    parser.add_argument("--executable", type=Path, help="Actual Windows 0.33.1.0 client with the fixed v62 endpoint")
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
