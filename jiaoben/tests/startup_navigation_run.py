"""Native real-title-button startup/resume regression, source or fixed PCK.

No --headless route. --legacy-v61 stages a temporary copy under the old fixed
suffix; it never edits the original v61 test or mounts a source project in PCK.
"""
from pathlib import Path
from contextlib import closing
import argparse
import hashlib
import importlib.util
import json
import mmap
import os
import re
import shutil
import sqlite3
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
DIAGNOSTIC = re.compile(r"^(?:\s*(?:SCRIPT ERROR|ERROR|WARNING):|.*[Ll]eak(?:ed|ing)?\b|.*Resource still in use)", re.M)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def source_identity():
    paths = sorted((ROOT / "code/runtime").rglob("*.gd"))
    paths += sorted((ROOT / "code/assets").rglob("manifest.json"))
    paths += sorted((ROOT / "code/assets").rglob("*.gdshader"))
    paths += [ROOT / "code/project.godot", ROOT / "code/data/catalog.db"]
    return {path.relative_to(ROOT).as_posix(): sha(path) for path in paths}


def closed_profile_origin(requested):
    if ".." in requested.parts:
        raise RuntimeError("Profile copy must be an explicit closed path without parent traversal")
    path = requested.resolve(strict=True)
    try:
        path.relative_to((ROOT / "jiaoben/tmp").resolve())
    except ValueError as exc:
        raise RuntimeError("Only an already-closed copy inside this workspace's jiaoben/tmp is allowed") from exc
    if not path.is_file():
        raise RuntimeError("Profile copy must be a regular closed SQLite file")
    sidecars = [Path(str(path) + suffix) for suffix in ("-journal", "-wal", "-shm")]
    if any(candidate.exists() for candidate in sidecars):
        raise RuntimeError("Profile copy has SQLite sidecars; close/recover a separate copy before this runner")
    before = sha(path)
    with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)) as database:
        database.execute("PRAGMA query_only=ON")
        check = database.execute("PRAGMA quick_check").fetchall()
        if check != [("ok",)]:
            raise RuntimeError(f"Closed-copy SQLite quick_check failed: {check}")
        selection = database.execute("SELECT world_id FROM profile_resume WHERE profile_id='local-profile'").fetchall()
        if len(selection) != 1 or not selection[0][0]:
            raise RuntimeError("Closed copy has no unique normal Continue resume pointer")
        version = database.execute("PRAGMA user_version").fetchone()[0]
    if sha(path) != before:
        raise RuntimeError("Input changed during read-only closed-copy inspection")
    return {"path": str(path), "sha256": before, "quick_check": "ok", "user_version": version,
            "resume_world_id": selection[0][0], "mode": "verified already-closed workspace tmp copy; original personal database is not accepted"}


def run(args):
    binary = (args.executable or args.engine).resolve()
    if not binary.is_file():
        raise RuntimeError(f"Engine/client not found: {binary}")
    if args.legacy_v61 and not args.executable:
        raise RuntimeError("--legacy-v61 requires the actual old executable")
    flag = "--xj-verify-ui-consistency-v61" if args.legacy_v61 else "--xj-verify-startup-navigation-v62"
    version = None
    if args.executable:
        spec = importlib.util.spec_from_file_location("startup_build_metadata", ROOT / "jiaoben/build_client.py")
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        version = module.inspect_windows_binary_version(binary, "0.33.0.0" if args.legacy_v61 else "0.36.0.0")
        if version.get("result") != "PASS":
            raise RuntimeError("Native Windows version metadata could not be verified")
        pck = binary.with_suffix(".pck")
        if not pck.is_file():
            raise RuntimeError("Actual external PCK missing")
        with pck.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as packed:
            if packed.find(flag.encode()) < 0:
                raise RuntimeError(f"Client lacks its fixed diagnostic {flag}; game was not launched")
    run_id = str(uuid.uuid4())
    original = ROOT / "jiaoben/tests/startup_navigation_v62.gd"
    script = original
    prefix = "XJ_STARTUP_NAVIGATION_V62"
    directory = ROOT / "jiaoben/tmp/startup-navigation-v62" / run_id
    if args.legacy_v61:
        staged = ROOT / "jiaoben/tmp/startup-old-package" / run_id / "jiaoben"
        script = staged / "tests/ui_interaction_consistency.gd"
        script.parent.mkdir(parents=True, exist_ok=False)
        source = original.read_text(encoding="utf-8")
        replacements = {"XJ_STARTUP_NAVIGATION_V62\"": "XJ_UI_CONSISTENCY_V61\"",
                        "startup_navigation_v62.gd\"": "ui_interaction_consistency.gd\"",
                        "startup-navigation-v62\"": "ui-interaction\"",
                        "xj_startup_navigation_v62_diagnostic\"": "xj_ui_consistency_v61_diagnostic\""}
        for before, after in replacements.items():
            if source.count(before) != 1:
                raise RuntimeError(f"Legacy adaptation requires one exact contract constant: {before}")
            source = source.replace(before, after)
        script.write_text(source, encoding="utf-8", newline="\n")
        prefix = "XJ_UI_CONSISTENCY_V61"
        directory = staged / "tmp/ui-interaction" / run_id
    directory.mkdir(parents=True, exist_ok=False)
    profile_origin = closed_profile_origin(args.profile_copy) if args.profile_copy else None
    if profile_origin:
        seed = directory / "seed.db"
        shutil.copyfile(Path(profile_origin["path"]), seed)
        if sha(seed) != profile_origin["sha256"]:
            raise RuntimeError("Scoped seed does not match its closed-copy origin")
        (directory / "seed-origin.json").write_text(json.dumps(profile_origin, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    stem = f"startup-navigation-{'old-pck' if args.legacy_v61 else 'pck' if args.executable else 'source'}-{run_id}"
    output = ROOT / "jiaoben/logs" / f"{stem}.log"
    engine_log = output.with_name(stem + "-engine.log")
    report = output.with_suffix(".json")
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy(); env.pop("XJ_TEST_DATABASE", None)
    env[prefix + "_SCRIPT"] = script.as_posix(); env[prefix + "_DIRECTORY"] = directory.as_posix()
    env[prefix + "_PROFILE_NEW_FIRST"] = "1" if args.profile_new_first else "0"
    env.pop(prefix + "_PROFILE_SEED_SHA256", None)
    if profile_origin:
        env[prefix + "_PROFILE_SEED_SHA256"] = profile_origin["sha256"]
    env["XJ_STARTUP_NAVIGATION_MAX_FRAME_MS"] = str(args.max_frame_ms)
    command = [str(binary), "--audio-driver", "WASAPI", "--log-file", engine_log.as_posix()]
    if args.executable:
        command += ["--", flag]
    else:
        launcher = directory / "launcher.gd"
        launcher.write_text("extends SceneTree\nfunc _initialize() -> void:\n\tcall_deferred(\"_start\")\nfunc _start() -> void:\n"
                            f"\tvar source: Script = load({json.dumps(script.as_posix(), ensure_ascii=False)})\n"
                            "\tif source == null or not source.can_instantiate():\n\t\tquit(2)\n\t\treturn\n\troot.add_child(source.new())\n",
                            encoding="utf-8", newline="\n")
        command += ["--path", (ROOT / "code").as_posix(), "--script", launcher.as_posix()]
    initial_sources = source_identity()
    record = {"mode": "legacy-fixed-v61-native" if args.legacy_v61 else "release-native" if args.executable else "source-native",
              "engine": str(binary), "engine_sha256": sha(binary), "windows_version": version, "command": command,
              "script": str(script), "script_sha256": sha(script), "original_test_sha256": sha(original),
              "directory": str(directory), "stdout": str(output), "engine_log": str(engine_log),
              "source_sha256": initial_sources, "timeout_s": args.timeout, "max_frame_budget_ms": args.max_frame_ms,
              "profile_origin": profile_origin,
              "profile_new_first": args.profile_new_first,
              "pck_sha256": sha(binary.with_suffix(".pck")) if args.executable else None}
    print(f"START {stem}", flush=True)
    started = time.monotonic()
    with output.open("wb") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        record["pid"] = process.pid
        try:
            record["exit_code"] = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()
            record.update(exit_code=process.returncode, timed_out=True)
    stdout = output.read_text(encoding="utf-8", errors="replace")
    engine = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
    record.update(seconds=round(time.monotonic() - started, 3),
                  diagnostics=[line for line in (stdout + engine).splitlines() if DIAGNOSTIC.search(line)],
                  source_changed_during_run=source_identity() != initial_sources,
                  test_changed_during_run=sha(script) != record["script_sha256"] or sha(original) != record["original_test_sha256"],
                  stdout_sha256=sha(output), engine_log_sha256=sha(engine_log) if engine_log.exists() else None,
                  phases=re.findall(r"^STARTUP_NAVIGATION_PHASE (.+)$", stdout, re.M),
                  last_heartbeat=next((line for line in reversed(stdout.splitlines()) if line.startswith("STARTUP_NAVIGATION_HEARTBEAT ")), None))
    if profile_origin:
        record["profile_origin_unchanged"] = sha(Path(profile_origin["path"])) == profile_origin["sha256"]
        record["profile_seed_unchanged"] = sha(directory / "seed.db") == profile_origin["sha256"]
    result = directory / "result.json"
    if result.is_file():
        record.update(result_path=str(result), result_sha256=sha(result), summary=json.loads(result.read_text(encoding="utf-8")))
    record["captures"] = [{"path": str(path), "sha256": sha(path)} for path in sorted(directory.glob("*.png"))]
    report.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"REPORT {report}", flush=True)
    assert record["exit_code"] == 0 and not record.get("timed_out") and engine_log.exists(), f"Native startup failed or froze: {output}"
    assert not record["diagnostics"], f"Strict dual-log diagnostics: {record['diagnostics'][:8]}"
    assert not record["source_changed_during_run"] and not record["test_changed_during_run"], "Source/test identity changed during execution"
    assert not profile_origin or (record["profile_origin_unchanged"] and record["profile_seed_unchanged"]), "Closed-copy input or immutable scoped seed was modified"
    assert re.search(r"^STARTUP_NAVIGATION_V62_RESULT PASS checks=\d+ failures=0", stdout, re.M), "Complete successful endpoint missing"
    assert result.is_file() and record["summary"]["result"] == "PASS" and not re.search(r"^FAIL(?:\s|$)", stdout, re.M)
    expected_actions = ["continue", "return_title", "new_world"] if profile_origin and not args.profile_new_first else ["new_world", "return_title", "continue"]
    assert [row["action"] for row in record["summary"]["requests"]] == expected_actions, "Actual GUI request sequence differs"
    assert record["summary"].get("profile_new_first") is args.profile_new_first, "Diagnostic direct-New option differs from the runner contract"
    assert {"title-fresh.png", "title-saved.png", "new_world_running.png", "continued_world_running.png"}.issubset({Path(row["path"]).name for row in record["captures"]}), "Native fresh/saved title and both loaded scenes required"
    print(f"STARTUP_NAVIGATION_ACCEPTANCE PASS {report}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=Path("D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe"))
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--legacy-v61", action="store_true", help="Temporary staged script using the old client's existing fixed v61 endpoint")
    parser.add_argument("--profile-copy", type=Path, help="Already-closed SQLite copy under this workspace's jiaoben/tmp; Continue is tested before New")
    parser.add_argument("--profile-new-first", action="store_true", help="With --profile-copy, test direct New before any old-world Continue, then return to title and resume the new world")
    parser.add_argument("--timeout", type=float, default=180.0, help="External process wall-clock bound in seconds")
    parser.add_argument("--max-frame-ms", type=float, default=1000.0, help="Declared UI responsiveness budget, including click-to-completion synchronous loading frames")
    args = parser.parse_args()
    if args.profile_new_first and not args.profile_copy:
        parser.error("--profile-new-first requires --profile-copy")
    if args.timeout <= 0 or args.max_frame_ms <= 0:
        parser.error("Timeout and frame budget must be positive")
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
