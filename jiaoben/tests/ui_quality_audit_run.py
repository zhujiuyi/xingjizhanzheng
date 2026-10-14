"""Serial UI audit with fresh test-owned SQLite and strict dual logs.

Run from the repository root: py jiaoben/tests/ui_quality_audit_run.py --label before
Use --label after --strict-layout for the corrected critical viewport boundaries.
Source uses a thin launcher; release 0.33.1.0 uses only its fixed diagnostic flag.
Neither route opens a personal save database.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
DIAGNOSTIC = re.compile(r"^(?:\s*(?:SCRIPT ERROR|ERROR|WARNING):|.*[Ll]eak(?:ed|ing)?\b|.*Resource still in use)", re.M)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def ui_source_snapshot():
    files = [ROOT / "code/runtime/ui.gd", ROOT / "code/runtime/ui_theme.gd"]
    files += sorted((ROOT / "code/runtime/ui").rglob("*.gd"))
    return {path.relative_to(ROOT).as_posix(): sha(path) for path in files}


def inspect_release_binary(executable):
    sys.path.insert(0, str(ROOT / "jiaoben"))
    from build_client import inspect_windows_binary_version
    result = inspect_windows_binary_version(executable, "0.33.1.0")
    if result.get("result") != "PASS":
        raise RuntimeError("Release diagnostics require verified Windows file/product version 0.33.1.0")
    return result


def write_source_launcher(directory, script):
    launcher = directory / "launcher.gd"
    launcher.write_text("extends SceneTree\nfunc _initialize() -> void:\n\tcall_deferred(\"_start\")\n"
                        "func _start() -> void:\n"
                        f"\tvar source := load({json.dumps(script.as_posix(), ensure_ascii=False)}) as Script\n"
                        "\tif source == null or not source.can_instantiate():\n\t\tquit(1)\n\t\treturn\n"
                        "\troot.add_child(source.new())\n", encoding="utf-8", newline="\n")
    return launcher


def run(args):
    binary = (args.executable or args.engine).resolve()
    if not binary.is_file():
        raise RuntimeError(f"Diagnostic executable does not exist: {binary}")
    release_identity = inspect_release_binary(binary) if args.executable else None
    run_id = str(uuid.uuid4())
    directory = ROOT / "jiaoben/tmp/ui-quality-audit" / run_id
    directory.mkdir(parents=True, exist_ok=False)
    script = ROOT / "jiaoben/tests/ui_quality_audit.gd"
    script_sha = sha(script)
    ui_source_sha = ui_source_snapshot()
    stem = f"ui-quality-{args.label}-{'headless' if args.headless else 'native'}-{run_id}"
    output = ROOT / "jiaoben/logs" / f"{stem}.log"
    engine_log = ROOT / "jiaoben/logs" / f"{stem}-engine.log"
    report = ROOT / "jiaoben/logs" / f"{stem}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    # Fixed source entry plus scoped DB is the only supported launch contract.
    env.pop("XJ_TEST_DATABASE", None)
    env["XJ_UI_QUALITY_AUDIT_DIRECTORY"] = directory.as_posix()
    env["XJ_UI_QUALITY_AUDIT_SCRIPT"] = script.as_posix()
    env["XJ_UI_QUALITY_AUDIT_LABEL"] = args.label
    env["XJ_UI_QUALITY_AUDIT_STRICT_LAYOUT"] = "1" if args.strict_layout else "0"
    command = [str(binary), "--audio-driver", "WASAPI"] + (["--headless"] if args.headless else [])
    if args.executable:
        command += ["--log-file", engine_log.as_posix(), "--", "--xj-verify-ui-quality-v61"]
    else:
        launcher = write_source_launcher(directory, script)
        command += ["--path", (ROOT / "code").as_posix(), "--script", launcher.as_posix(), "--log-file", engine_log.as_posix()]
    record = {"label": args.label, "mode": ("release-" if args.executable else "source-") + ("headless" if args.headless else "native"),
              "engine": str(binary), "engine_sha256": sha(binary), "script": str(script),
              "script_sha256": script_sha, "directory": str(directory), "stdout": str(output),
              "ui_source_sha256": ui_source_sha,
              "engine_log": str(engine_log), "source_revision": subprocess.check_output(
                  ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_dirty": bool(subprocess.check_output(["git", "status", "--porcelain", "--", "code"], cwd=ROOT)),
              "catalog_sha256": sha(ROOT / "code/data/catalog.db"), "strict_layout": args.strict_layout,
              "release_identity": release_identity, "command": command,
              "pck_sha256": sha(binary.with_suffix(".pck")) if args.executable and binary.with_suffix(".pck").is_file() else None}
    started = time.monotonic()
    print(f"START {stem}", flush=True)
    with output.open("wb") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        try:
            record["exit_code"] = process.wait(timeout=600)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            record["exit_code"] = process.returncode
            record["timed_out"] = True
    text = output.read_text(encoding="utf-8", errors="replace")
    engine = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
    record.update({"seconds": round(time.monotonic() - started, 2), "stdout_sha256": sha(output),
                   "engine_sha256_log": sha(engine_log) if engine_log.exists() else None,
                   "script_changed_during_run": sha(script) != script_sha,
                   "diagnostics": [line for line in (text + engine).splitlines() if DIAGNOSTIC.search(line)]})
    ui_source_end = ui_source_snapshot()
    record["ui_source_sha256_after"] = ui_source_end
    record["ui_source_changed_during_run"] = ui_source_end != ui_source_sha
    record["ui_source_changed_files"] = sorted(path for path in ui_source_sha.keys() | ui_source_end.keys()
                                                if ui_source_sha.get(path) != ui_source_end.get(path))
    result_path = directory / "result.json"
    if result_path.exists():
        record["result_path"] = str(result_path)
        record["result_sha256"] = sha(result_path)
        full = json.loads(result_path.read_text(encoding="utf-8"))
        record["summary"] = {key: value for key, value in full.items() if key not in ("observations", "findings")}
        record["findings"] = full["findings"]
        record["observations_count"] = len(full["observations"])
    captures = sorted(directory.glob("*.png"))
    record["captures"] = [{"path": str(path), "sha256": sha(path)} for path in captures]
    report.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"REPORT {report}", flush=True)
    assert record["exit_code"] == 0 and engine_log.exists(), f"Audit engine failed: {output}"
    assert not record["script_changed_during_run"], "Audit script changed during execution"
    assert not record["ui_source_changed_during_run"], f"UI source changed during execution: {record['ui_source_changed_files']}"
    assert not record["diagnostics"], f"Strict dual-log diagnostics: {record['diagnostics'][:8]}"
    assert re.search(r"^UI_QUALITY_AUDIT_RESULT PASS checks=\d+ failures=0", text, re.M), "Complete successful endpoint missing"
    assert result_path.exists() and record["summary"]["result"] == "PASS" and record["summary"]["failures"] == 0
    assert not re.search(r"^FAIL(?:\s|$)", text, re.M), "Nested assertion failed"
    expected_pages = set(record["summary"]["pages"])
    assert len(expected_pages) == 29, "Update explicit page inventory when XJUI changes"
    for size in ((1440, 900), (1024, 648), (1920, 1080)):
        observed = {entry["page"] for entry in full["observations"] if tuple(entry["native_size"]) == size}
        assert expected_pages.issubset(observed), f"Missing pages at {size}: {expected_pages - observed}"
    assert len(captures) == (0 if args.headless else record["observations_count"])
    print(f"UI_QUALITY_AUDIT_ACCEPTANCE PASS pages={len(expected_pages)} captures={len(captures)} findings={len(record['findings'])} {report}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", choices=("before", "after"), required=True)
    parser.add_argument("--engine", type=Path, default=Path("D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe"))
    parser.add_argument("--executable", type=Path, help="Actual Windows 0.33.1.0 client; fixed v61 diagnostic only")
    parser.add_argument("--headless", action="store_true", help="Structure only; no screenshot acceptance")
    parser.add_argument("--strict-layout", action="store_true", help="Fail critical frame viewport overflow")
    args = parser.parse_args()
    import msvcrt
    lock_path = ROOT / "jiaoben/tmp/feature-audit.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+b") as lock:
        lock.seek(0)
        lock.write(b"0")
        lock.flush()
        lock.seek(0)
        msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            run(args)
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


if __name__ == "__main__":
    main()
