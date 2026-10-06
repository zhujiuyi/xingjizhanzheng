"""Serial source/actual-PCK acceptance for the v18 combat and lighting upgrade."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
CASES = {
    "combat": ("combat_v18.gd", "XJ_COMBAT_V18", "combat-v18", "COMBAT_V18", "combat"),
    "lighting": ("lighting_effects_v18.gd", "XJ_LIGHTING_V18", "lighting-effects-v18", "LIGHTING_EFFECTS_V18", "lighting"),
    "weapon-ui": ("weapon_ui_v18.gd", "XJ_WEAPON_UI_V18", "weapon-ui-v18", "WEAPON_UI_V18", "weapon-ui"),
    "upgrade": ("combat_upgrade_v18.gd", "XJ_UPGRADE_V18", "combat-upgrade-v18", "COMBAT_UPGRADE_V18", "upgrade"),
    "mission-display": ("mission_display_v19.gd", "XJ_MISSION_DISPLAY_V19", "mission-display-v19", "MISSION_DISPLAY_V19", "--xj-verify-mission-display-v19"),
}
DIAGNOSTIC = re.compile(r"^(?:\s*(?:SCRIPT ERROR|ERROR|WARNING):|.*[Ll]eak(?:ed|ing)?\b|.*Resource still in use)", re.M)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def activate(process):
    command = (f"$targetProcessId={process.pid}; $deadline=[DateTime]::UtcNow.AddSeconds(15); "
               "do { $target=Get-Process -Id $targetProcessId -ErrorAction SilentlyContinue; "
               "if ($target -and $target.MainWindowHandle -ne 0) { break }; Start-Sleep -Milliseconds 200 "
               "} while ([DateTime]::UtcNow -lt $deadline); "
               "$shell=New-Object -ComObject WScript.Shell; Write-Output ('WINDOW_ACTIVATE '+$shell.AppActivate($targetProcessId))")
    result = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", command],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
    print(result.stdout.decode("utf-8", errors="replace").strip(), flush=True)


def run_suite():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--only", nargs="+", choices=CASES, default=["combat", "lighting", "weapon-ui", "upgrade"])
    parser.add_argument("--executable", type=Path, help="Actual Windows release EXE, without a source project path")
    parser.add_argument("--engine", type=Path, default=Path("D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe"))
    parser.add_argument("--legacy", type=Path, help="Closed format6 test database under jiaoben/tmp; never personal data")
    args = parser.parse_args()
    mode = ("release" if args.executable else "source") + ("-native" if args.native else "-headless")
    run_id = str(uuid.uuid4())
    records = []
    report_path = ROOT / f"jiaoben/logs/v18-{mode}-{run_id}.json"
    if args.executable:
        binary = args.executable.resolve()
        identity = {"executable": str(binary), "exe_sha256": sha(binary), "pck_sha256": sha(binary.with_suffix(".pck"))}
    else:
        binary = args.engine.resolve()
        identity = {"engine": str(binary), "catalog_sha256": sha(ROOT / "code/data/catalog.db")}
    for name in args.only:
        script, prefix, folder, marker, flag = CASES[name]
        directory = ROOT / "jiaoben/tmp" / folder / str(uuid.uuid4())
        directory.mkdir(parents=True)
        test = ROOT / "jiaoben/tests" / script
        env = os.environ.copy()
        env.pop("XJ_TEST_DATABASE", None)
        env[prefix + "_SCRIPT"] = test.as_posix()
        env[prefix + "_DIRECTORY"] = directory.as_posix()
        if name == "upgrade":
            assert args.legacy and args.legacy.is_file(), "Pass --legacy pointing to a closed test-owned format6 fixture"
            legacy = args.legacy.resolve()
            assert legacy.is_relative_to(ROOT / "jiaoben/tmp")
            env["XJ_UPGRADE_V18_LEGACY_SOURCE"] = legacy.as_posix()
        stem = f"v18-{mode}-{name}-{run_id}"
        output = ROOT / f"jiaoben/logs/{stem}.log"
        engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
        command = [str(binary), "--audio-driver", "WASAPI", "--log-file", engine_log.as_posix()]
        if not args.native:
            command += ["--headless"]
        if args.executable:
            command += ["--", flag if flag.startswith("--") else f"--xj-verify-{flag}-v18"]
        else:
            launcher = directory / "launcher.gd"
            launcher.write_text("extends SceneTree\nfunc _initialize() -> void:\n\tcall_deferred(\"_start\")\n"
                                "func _start() -> void:\n"
                                f"\tvar source := load({json.dumps(test.as_posix(), ensure_ascii=False)}) as Script\n"
                                "\tif source == null or not source.can_instantiate():\n\t\tquit(1)\n\t\treturn\n"
                                "\troot.add_child(source.new())\n", encoding="utf-8", newline="\n")
            command += ["--path", (ROOT / "code").as_posix(), "--script", launcher.as_posix()]
        print(f"START {mode} {name}", flush=True)
        started = time.monotonic()
        with output.open("wb") as stream:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
            if args.native:
                activate(process)
            try:
                code = process.wait(timeout=600)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
                raise
        text = output.read_text(encoding="utf-8", errors="replace")
        engine = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
        finals = re.findall(rf"^{marker}_FINAL_JSON (.+)$", text, re.M)
        captures = sorted(directory.glob("*.png"))
        record = {"case": name, "exit_code": code, "seconds": round(time.monotonic() - started, 2),
                  "directory": str(directory), "script_sha256": sha(test), "stdout": str(output), "engine_log": str(engine_log),
                  "stdout_sha256": sha(output), "engine_sha256": sha(engine_log) if engine_log.exists() else None,
                  "captures": [{"path": str(path), "sha256": sha(path)} for path in captures],
                  "diagnostics": [line for line in (text + engine).splitlines() if DIAGNOSTIC.search(line)]}
        if finals:
            assert len(finals) == 1
            record["summary"] = json.loads(finals[0])
        elif (directory / "result.json").exists():
            raw_summary = json.loads((directory / "result.json").read_text(encoding="utf-8"))
            record["raw_summary"] = raw_summary
            failures = raw_summary.get("failures", [])
            record["summary"] = {**raw_summary, "result": "PASS" if failures == [] else "FAIL",
                                 "failures": len(failures), "failure_labels": failures}
        records.append(record)
        report_path.write_text(json.dumps({"mode": mode, "identity": identity, "cases": records}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        assert code == 0 and engine_log.exists(), f"{name} process failed: {output}"
        assert re.search(rf"^{marker}(?:_RESULT)? PASS.*failures=0", text, re.M), f"{name} incomplete/failed result: {output}"
        assert not record["diagnostics"], f"{name} diagnostics: {record['diagnostics'][:5]}"
        if "summary" in record:
            assert record["summary"]["result"] == "PASS" and record["summary"]["failures"] == 0
        assert all(path.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n" for path in captures)
        print(f"PASS {mode} {name}: {len(captures)} screenshots; {record['seconds']} s", flush=True)
    print(f"V18_ACCEPTANCE PASS {report_path}", flush=True)


def main():
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
            run_suite()
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


if __name__ == "__main__":
    main()
