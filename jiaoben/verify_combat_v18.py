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
    "operations": ("operations_v30.gd", "XJ_OPERATIONS_V30", "operations-v30", "OPERATIONS_V30", "--xj-verify-operations-v30"),
    "operations-world": ("operations_world_v30.gd", "XJ_OPERATIONS_WORLD_V30", "operations-world-v30", "OPERATIONS_WORLD_V30", "--xj-verify-operations-world-v30"),
    "tactics-world": ("tactics_world_v29.gd", "XJ_TACTICS_WORLD_V29", "tactics-world-v29", "TACTICS_WORLD_V29", "--xj-verify-tactics-world-v29"),
    "tactics": ("tactics_v29.gd", "XJ_TACTICS_V29", "tactics-v29", "TACTICS_V29", "--xj-verify-tactics-v29"),
    "mobile-belts-world": ("mobile_belts_world_v28.gd", "XJ_MOBILE_BELTS_WORLD_V28", "mobile-belts-world-v28", "MOBILE_BELTS_WORLD_V28", "--xj-verify-mobile-belts-world-v28"),
    "mobile-belts": ("mobile_belts_v28.gd", "XJ_MOBILE_BELTS_V28", "mobile-belts-v28", "MOBILE_BELTS_V28", "--xj-verify-mobile-belts-v28"),
    "exploration-world": ("exploration_world_v27.gd", "XJ_EXPLORATION_WORLD_V27", "exploration-world-v27", "EXPLORATION_WORLD_V27", "--xj-verify-exploration-world-v27"),
    "exploration": ("exploration_v27.gd", "XJ_EXPLORATION_V27", "exploration-v27", "EXPLORATION_V27", "--xj-verify-exploration-v27"),
    "resource-intel-world": ("resource_intel_world_v26.gd", "XJ_RESOURCE_INTEL_WORLD_V26", "resource-intel-world-v26", "RESOURCE_INTEL_WORLD_V26", "--xj-verify-resource-intel-world-v26"),
    "resource-intel": ("resource_intel_v26.gd", "XJ_RESOURCE_INTEL_V26", "resource-intel-v26", "RESOURCE_INTEL_V26", "--xj-verify-resource-intel-v26"),
    "row-quantity": ("row_quantity_v17.gd", "XJ_ROW_QUANTITY_V17", "row-quantity-v17", "ROW_QUANTITY_V17", "--xj-verify-row-quantities"),
    "industry": ("industry_v25.gd", "XJ_INDUSTRY_V25", "industry-v25", "INDUSTRY", "--xj-verify-industry-v25"),
    "industry-world": ("industry_world_v25.gd", "XJ_INDUSTRY_WORLD_V25", "industry-world-v25", "INDUSTRY_WORLD_V25", "--xj-verify-industry-world-v25"),
    "civilization-world": ("civilization_world_v24.gd", "XJ_CIVILIZATION_WORLD_V24", "civilization-world-v24", "CIVILIZATION_WORLD_V24", "--xj-verify-civilization-world-v24"),
    "civilization-upgrade": ("civilization_upgrade_v24.gd", "XJ_CIVILIZATION_UPGRADE_V24", "civilization-upgrade-v24", "CIVILIZATION_UPGRADE_V24", "--xj-verify-civilization-upgrade-v24"),
    "civilizations": ("civilizations_v24.gd", "XJ_CIVILIZATIONS_V24", "civilizations-v24", "CIVILIZATIONS_V24", "--xj-verify-civilizations-v24"),
    "combat": ("combat_v18.gd", "XJ_COMBAT_V18", "combat-v18", "COMBAT_V18", "combat"),
    "lighting": ("lighting_effects_v18.gd", "XJ_LIGHTING_V18", "lighting-effects-v18", "LIGHTING_EFFECTS_V18", "lighting"),
    "weapon-ui": ("weapon_ui_v18.gd", "XJ_WEAPON_UI_V18", "weapon-ui-v18", "WEAPON_UI_V18", "weapon-ui"),
    "upgrade": ("combat_upgrade_v18.gd", "XJ_UPGRADE_V18", "combat-upgrade-v18", "COMBAT_UPGRADE_V18", "upgrade"),
    "mission-display": ("mission_display_v19.gd", "XJ_MISSION_DISPLAY_V19", "mission-display-v19", "MISSION_DISPLAY_V19", "--xj-verify-mission-display-v19"),
    "warp-visual": ("warp_visual_v20.gd", "XJ_WARP_VISUAL_V20", "warp-visual-v20", "WARP_VISUAL_V20", "--xj-verify-warp-visual-v20"),
    "warp-scene": ("warp_scene_v21.gd", "XJ_WARP_SCENE_V21", "warp-scene-v21", "WARP_SCENE_V21", "--xj-verify-warp-scene-v21"),
    "service-navigation": ("service_navigation_v22.gd", "XJ_SERVICE_NAVIGATION_V22", "service-navigation-v22", "SERVICE_NAVIGATION_V22", "--xj-verify-service-navigation-v22"),
    "spatial-business": ("spatial_business_v20.gd", "XJ_SPATIAL_BUSINESS_V20", "spatial-business-v20", "SPATIAL_BUSINESS_V20", "--xj-verify-spatial-business-v20"),
    "space-upgrade": ("space_upgrade_v20.gd", "XJ_SPACE_UPGRADE_V20", "space-upgrade-v20", "SPACE_UPGRADE_V20", "--xj-verify-space-upgrade-v20"),
    "spatial-navigation": ("spatial_navigation_v20.gd", "XJ_SPATIAL_NAVIGATION_V20", "spatial-navigation-v20", "SPATIAL_NAVIGATION_V20", "--xj-verify-spatial-navigation-v20"),
    "base-store": ("runtime/data/diagnostic.gd", "XJ_BASE_STORE_V20", "release-health-v20", "STORE_RELEASE", "--xj-verify-store"),
    "base-presentation": ("runtime/presentation_diagnostic.gd", "XJ_BASE_PRESENTATION_V20", "release-presentation-v20", "PRESENTATION_CLIENT", "--xj-verify-presentation"),
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
        builtin = name in ("base-store", "base-presentation")
        test = ROOT / ("code" if builtin else "jiaoben/tests") / script
        env = os.environ.copy()
        env.pop("XJ_TEST_DATABASE", None)
        if builtin:
            env["XJ_TEST_DATABASE"] = (directory / "progress.db").as_posix()
        else:
            env[prefix + "_SCRIPT"] = test.as_posix()
            env[prefix + "_DIRECTORY"] = directory.as_posix()
        if name in ("upgrade", "civilization-upgrade"):
            assert args.legacy and args.legacy.is_file(), "Pass --legacy pointing to a closed test-owned format6 fixture"
            legacy = args.legacy.resolve()
            assert legacy.is_relative_to(ROOT / "jiaoben/tmp")
            env[prefix + "_LEGACY_SOURCE"] = legacy.as_posix()
        stem = f"v18-{mode}-{name}-{run_id}"
        output = ROOT / f"jiaoben/logs/{stem}.log"
        engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
        command = [str(binary), "--audio-driver", "WASAPI", "--log-file", engine_log.as_posix()]
        if not args.native or name == "base-store":
            command += ["--headless"]
        if args.executable:
            command += ["--", flag if flag.startswith("--") else f"--xj-verify-{flag}-v18"]
        elif builtin:
            command += ["--path", (ROOT / "code").as_posix(), "--", flag]
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
            if args.native and name != "base-store":
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
        elif builtin:
            endpoint = re.search(rf"^{marker}_RESULT (PASS|FAIL) checks=(\d+) failures=(\d+)", text, re.M)
            if endpoint:
                record["summary"] = {"result": endpoint[1], "checks": int(endpoint[2]), "failures": int(endpoint[3])}
        records.append(record)
        report_path.write_text(json.dumps({"mode": mode, "identity": identity, "cases": records}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        assert code == 0 and engine_log.exists(), f"{name} process failed: {output}"
        assert re.search(rf"^{marker}(?:_RESULT)? PASS.*failures=0", text, re.M), f"{name} incomplete/failed result: {output}"
        assert not record["diagnostics"], f"{name} diagnostics: {record['diagnostics'][:5]}"
        if "summary" in record:
            assert record["summary"]["result"] == "PASS" and record["summary"]["failures"] == 0
        assert all(path.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n" for path in captures)
        if builtin:
            assert record["summary"]["checks"] >= (6 if name == "base-store" else 110)
            assert len(captures) == (0 if name == "base-store" else 17)
        if name in ("civilizations", "civilization-upgrade"):
            assert record["summary"]["checks"] >= (200 if name == "civilizations" else 25) and len(captures) == 0
        if name == "civilization-world":
            assert args.native and record["summary"]["checks"] >= 90 and len(captures) == 12
            battle = [entry for entry in record["summary"]["observations"] if entry["kind"] == "battle"]
            assert len(battle) == 1 and battle[0]["status"] == "won" and battle[0]["ally_impacts"] > 0 and battle[0]["seconds"] >= 30
        if name == "industry-world":
            assert args.native and record["summary"]["checks"] >= 35 and len(captures) == 7
            assert record["summary"]["native_helper_sha256"] == sha(ROOT / "jiaoben/tests/civilization_world_v24.gd")
        if name == "industry":
            assert record["summary"]["checks"] >= 80 and len(captures) == 0
        if name == "exploration":
            assert record["summary"]["checks"] >= 249 and record["summary"]["cases"] == 18 and len(captures) == 0
            if os.environ.get("XJ_EXPLORATION_LEGACY_DATABASE"):
                assert record["summary"]["legacy_checked"] and record["summary"]["checks"] >= 260
        if name == "mobile-belts":
            assert record["summary"]["checks"] >= 150 and record["summary"]["cases"] == 6 and len(captures) == 0
            if os.environ.get("XJ_MOBILE_BELTS_LEGACY_DATABASE"):
                assert record["summary"]["legacy_checked"] and record["summary"]["checks"] >= 170
        if name == "tactics":
            assert record["summary"]["checks"] >= 46 and len(captures) == 0
            if os.environ.get("XJ_TACTICS_LEGACY_DATABASE"):
                assert record["summary"]["legacy_checked"] and record["summary"]["checks"] >= 60
        if name == "operations":
            assert record["summary"]["checks"] >= (55 if os.environ.get("XJ_OPERATIONS_LEGACY_DATABASE") else 44) and len(captures) == 0
        if name == "operations-world":
            assert args.native and record["summary"]["checks"] >= 77 and len(captures) == 8
            voyage = next(row for row in record["summary"]["observations"] if row["kind"] == "breakthrough")
            assert voyage["moved_m"] > 4800 and voyage["exit_distance_m"] <= 180 and voyage["seconds"] > 20 and voyage["hp_lost"] > 0 and voyage["enemies_alive"] == 3
            exposure = next(row for row in record["summary"]["observations"] if row["kind"] == "exposure")
            assert exposure["lost"] > 0
        if name == "tactics-world":
            assert args.native and record["summary"]["checks"] >= 101 and len(captures) == 12
            evasion = next(row for row in record["summary"]["observations"] if row["kind"] == "evasion")
            assert evasion["distance_m"] > 50 and evasion["shield"] == evasion["maximum_shield"] and evasion["armor"] == evasion["maximum_armor"]
        if name == "mobile-belts-world":
            assert args.native and record["summary"]["checks"] >= 110 and record["summary"]["routes"] == 3 and len(captures) == 7
            routes = [row for row in record["summary"]["observations"] if row["kind"] == "route"]
            assert [row["index"] for row in routes] == [0, 1, 2] and all(row["from"] != row["to"] for row in routes)
            assert all(row["ore"] > 0 for row in routes) and all(a["ore"] < b["ore"] for a, b in zip(routes, routes[1:]))
        if name == "exploration-world":
            assert args.native and record["summary"]["checks"] >= 80 and len(captures) == 8
            escort = next(row for row in record["summary"]["observations"] if row["kind"] == "escort")
            assert escort["hits"] > 0 and escort["moved_m"] > 4000 and escort["outcome"] == "full"
        if name == "resource-intel":
            assert record["summary"]["checks"] >= 190 and len(captures) == 0
            if os.environ.get("XJ_RESOURCE_INTEL_LEGACY_DATABASE"):
                assert record["summary"]["legacy_checked"] and record["summary"]["checks"] >= 200
        if name == "resource-intel-world":
            assert args.native and record["summary"]["checks"] >= 56 and len(captures) == 6
        if name == "row-quantity":
            summary = record["summary"]
            assert summary["checks"] >= 5000 and summary["gui_transactions"] >= 16
            assert summary["invalid_cases"] >= 5 and summary["stale_rejections"] >= 7 and summary["layouts"] == 4 and summary["restarts"] == 1
            assert len(captures) == (6 if args.native else 0)
        if name == "service-navigation":
            summary = record["summary"]
            assert summary["native"] == args.native and summary["checks"] >= 120
            assert Path(summary["directory"]).resolve() == directory.resolve()
            assert Path(summary["database_path"]).resolve() == (directory / "progress.db").resolve()
            assert (directory / "progress.db").is_file() and len(captures) == (11 if args.native else 0)
            windows = [item for item in summary["observations"] if item["kind"] == "window"]
            assert {item["label"] for item in windows} == {
                f"{width}x{height}-{scale}" for width, height in ((1280, 720), (1440, 900), (3440, 1370)) for scale in (100, 200)
            }
            assert len(windows) == 6 and len([item for item in summary["observations"] if item["kind"] == "row"]) == 72
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
