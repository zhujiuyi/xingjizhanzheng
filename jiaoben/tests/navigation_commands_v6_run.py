#!/usr/bin/env python3
"""Strict real-client navigation regression, fresh SQLite and serial Godot ownership.

Source defaults to headless; --native captures the actual renderer.
An exported executable uses only its registered fixed diagnostic, never --script.
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

from startup_navigation_run import ROOT, DIAGNOSTIC, sha, source_identity

FLAG = "--xj-verify-navigation-commands-v6"
ENV_PREFIX = "XJ_NAVIGATION_COMMANDS_V6"


def sources():
    identity = source_identity()
    identity.update({path.relative_to(ROOT).as_posix(): sha(path)
                     for path in sorted((ROOT / "code/contracts").rglob("*.gd"))})
    return identity


def run(args):
    binary = (args.executable or args.engine).resolve(strict=True)
    version = None
    if args.executable:
        args.native = True
        spec = importlib.util.spec_from_file_location("navigation_build_metadata", ROOT / "jiaoben/build_client.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        version = module.inspect_windows_binary_version(binary, args.expected_version)
        if version.get("result") != "PASS":
            raise RuntimeError("Client Windows version metadata did not match the declared version")
        pck = binary.with_suffix(".pck")
        if not pck.is_file():
            raise RuntimeError("Actual exported PCK is missing")
        with pck.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as packed:
            if packed.find(FLAG.encode("ascii")) < 0:
                raise RuntimeError("Client lacks the fixed navigation diagnostic; it was not launched")
    run_id = str(uuid.uuid4())
    directory = ROOT / "jiaoben/tmp/navigation-commands-v6" / run_id
    directory.mkdir(parents=True, exist_ok=False)
    script = ROOT / "jiaoben/tests/navigation_commands_v6.gd"
    dependencies = [script, Path(__file__).resolve(), ROOT / "jiaoben/tests/startup_navigation_run.py"]
    test_start = {str(path): sha(path) for path in dependencies}
    source_start = sources()
    mode = "pck-native" if args.executable else "source-native" if args.native else "source-headless"
    stem = f"navigation-commands-v6-{mode}-{run_id}"
    output = ROOT / "jiaoben/logs" / (stem + ".log")
    engine_log = output.with_name(stem + "-engine.log")
    report = output.with_suffix(".json")
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.pop("XJ_TEST_DATABASE", None)
    env.update({ENV_PREFIX + "_SCRIPT": script.as_posix(), ENV_PREFIX + "_DIRECTORY": directory.as_posix(),
                "XJ_NAV_TEST_SCOPE": "core" if args.navigation_only else "full"})
    audio = args.audio_driver or ("WASAPI" if os.name == "nt" and args.native else "Dummy")
    if os.name == "nt" and audio == "CoreAudio":
        raise RuntimeError("CoreAudio is not a Windows driver; choose WASAPI or Dummy")
    command = [str(binary), "--audio-driver", audio, "--log-file", engine_log.as_posix()]
    if not args.native:
        command.append("--headless")
    if args.executable:
        command += ["--", FLAG]
    else:
        launcher = directory / "launcher.gd"
        launcher.write_text("extends SceneTree\nfunc _initialize() -> void:\n\tcall_deferred(\"_start\")\nfunc _start() -> void:\n"
                            f"\tvar source: Script = load({json.dumps(script.as_posix(), ensure_ascii=False)})\n"
                            "\tif source == null or not source.can_instantiate():\n\t\tquit(2)\n\t\treturn\n\troot.add_child(source.new())\n",
                            encoding="utf-8", newline="\n")
        command += ["--path", (ROOT / "code").as_posix(), "--script", launcher.as_posix()]
    record = {"mode": mode, "run_id": run_id, "engine": str(binary), "engine_sha256": sha(binary),
              "windows_version": version, "pck_sha256": sha(binary.with_suffix(".pck")) if args.executable else None,
              "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_sha256": source_start, "test_sha256": test_start, "command": command,
              "directory": str(directory), "stdout": str(output), "engine_log": str(engine_log),
              "scope": "core" if args.navigation_only else "full", "timeout_seconds": args.timeout,
              "personal_database_used": False}
    print(f"START {stem}", flush=True)
    started = time.monotonic()
    with output.open("wb") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        record["pid"] = process.pid
        try:
            record["exit_code"] = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            record.update(exit_code=process.returncode, timed_out=True)
    stdout = output.read_text(encoding="utf-8", errors="replace")
    engine = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.is_file() else ""
    record.update(seconds=round(time.monotonic() - started, 3), stdout_sha256=sha(output),
                  engine_log_sha256=sha(engine_log) if engine_log.is_file() else None,
                  diagnostics={"stdout": DIAGNOSTIC.findall(stdout), "engine": DIAGNOSTIC.findall(engine)},
                  source_changed_during_run=sources() != source_start,
                  test_changed_during_run=any(not Path(path).is_file() or sha(Path(path)) != value for path, value in test_start.items()))
    result = directory / "result.json"
    if result.is_file():
        record.update(result_path=str(result), result_sha256=sha(result))
        try:
            record["summary"] = json.loads(result.read_text(encoding="utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            record["result_parse_error"] = str(exc)
    record["captures"] = [{"path": str(path), "sha256": sha(path)} for path in sorted(directory.glob("*.png"))]
    report.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"REPORT {report}", flush=True)
    assert record["exit_code"] == 0 and not record.get("timed_out") and engine_log.is_file(), f"Navigation engine failed: {output}"
    assert not any(record["diagnostics"].values()), f"Strict dual-log diagnostics: {record['diagnostics']}"
    assert not record["source_changed_during_run"] and not record["test_changed_during_run"], "Source/test identity changed during execution"
    assert re.search(r"^NAVIGATION_COMMANDS_V6_RESULT PASS checks=\d+ failures=0 captures=\d+$", stdout, re.M), "Successful complete endpoint missing"
    summary = record.get("summary", {})
    assert summary.get("result") == "PASS" and summary.get("failures") == 0 and not re.search(r"^FAIL(?:\s|$)", stdout, re.M), "Navigation assertions did not all pass"
    cases = summary.get("observations", [])
    assert any(row.get("case") == "legal_boundary_alignment" for row in cases), "Legal boundary alignment evidence missing"
    assert any(row.get("case") == "actual_site_transition" and row.get("origin_site") != row.get("destination_site") for row in cases), "Actual site transition evidence missing"
    if args.native:
        required = {"warp-arrived.png", "orbit.png"}
        if not args.navigation_only:
            required |= {f"layout-{width}x{height}-{scale}.png" for width, height in [(1440, 900), (1280, 720)] for scale in [100, 200]}
        assert required.issubset({Path(row["path"]).name for row in record["captures"]}), "Actual native navigation captures missing"
    else:
        assert summary.get("captures") == 0, "Headless run must not claim renderer evidence"
    if args.executable:
        assert summary.get("packed_runtime") is True, "Actual exported runtime evidence missing"
    print(f"NAVIGATION_COMMANDS_V6_GUARD PASS {report}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=Path("D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe"))
    parser.add_argument("--executable", type=Path, help="Actual Windows client with the registered fixed navigation diagnostic")
    parser.add_argument("--expected-version", default="0.37.1.0", help="Exact Windows binary version expected in --executable mode")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--audio-driver", choices=("Dummy", "WASAPI", "CoreAudio"))
    parser.add_argument("--navigation-only", action="store_true", help="Explicit partial core scope; full UI assertions and four layout captures are skipped")
    parser.add_argument("--timeout", type=float, default=600.0, help="Finite whole-suite bound; includes real site transitions and durable source/arrival saves")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("Timeout must be positive")
    import msvcrt
    lock_path = ROOT / "jiaoben/tmp/feature-audit.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+b") as lock:
        if lock.seek(0, os.SEEK_END) == 0:
            lock.write(b"0"); lock.flush()
        lock.seek(0)
        msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            run(args)
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


if __name__ == "__main__":
    main()
