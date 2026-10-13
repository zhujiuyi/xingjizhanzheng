"""Serial source/actual-PCK acceptance for the v18 combat and lighting upgrade."""
from pathlib import Path
import argparse
import hashlib
import json
import mmap
import os
import re
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
CASES = {
    "natural-expedition": ("natural_campaign_v58.gd", "XJ_NATURAL_CAMPAIGN_V58", "natural-campaign-v58", "NATURAL_CAMPAIGN_V58", "--xj-verify-natural-campaign-v58"),
    "natural-project": ("natural_campaign_v58.gd", "XJ_NATURAL_CAMPAIGN_V58", "natural-campaign-v58", "NATURAL_CAMPAIGN_V58", "--xj-verify-natural-campaign-v58"),
    "natural-hull": ("natural_hull_v57.gd", "XJ_NATURAL_HULL_V57", "natural-hull-v57", "NATURAL_HULL_V57", "--xj-verify-natural-hull-v57"),
    "natural-war": ("natural_war_v56.gd", "XJ_NATURAL_WAR_V56", "natural-war-v56", "NATURAL_WAR_V56", "--xj-verify-natural-war-v56"),
    "natural-command": ("natural_command_v55.gd", "XJ_NATURAL_COMMAND_V55", "natural-command-v55", "NATURAL_COMMAND_V55", "--xj-verify-natural-command-v55"),
    "natural-logistics": ("natural_logistics_v54.gd", "XJ_NATURAL_LOGISTICS_V54", "natural-logistics-v54", "NATURAL_LOGISTICS_V54", "--xj-verify-natural-logistics-v54"),
    "natural-rescue": ("natural_rescue_v53.gd", "XJ_NATURAL_RESCUE_V53", "natural-rescue-v53", "NATURAL_RESCUE_V53", "--xj-verify-natural-rescue-v53"),
    "natural-research": ("natural_research_v52.gd", "XJ_NATURAL_RESEARCH_V52", "natural-research-v52", "NATURAL_RESEARCH_V52", "--xj-verify-natural-research-v52"),
    "natural-scout": ("natural_scout_v51.gd", "XJ_NATURAL_SCOUT_V51", "natural-scout-v51", "NATURAL_SCOUT_V51", "--xj-verify-natural-scout-v51"),
    "natural-rank": ("natural_rank_v50.gd", "XJ_NATURAL_RANK_V50", "natural-rank-v50", "NATURAL_RANK_V50", "--xj-verify-natural-rank-v50"),
    "growth-world": ("growth_world_v50.gd", "XJ_GROWTH_WORLD_V50", "growth-world-v50", "GROWTH_WORLD_V50", "--xj-verify-growth-world-v50"),
    "natural-mid": ("natural_mid_v50.gd", "XJ_NATURAL_MID_V50", "natural-mid-v50", "NATURAL_MID_V50", "--xj-verify-natural-mid-v50"),
    "march-routes": ("march_routes_v50.gd", "XJ_MARCH_ROUTES_V50", "march-routes-v50", "MARCH_ROUTES_V50", "--xj-verify-march-routes-v50"),
    "march-upgrade": ("march_upgrade_v49.gd", "XJ_MARCH_UPGRADE_V49", "march-upgrade-v49", "MARCH_UPGRADE_V49", "--xj-verify-march-upgrade-v49"),
    "march-world": ("march_world_v49.gd", "XJ_MARCH_WORLD_V49", "march-world-v49", "MARCH_WORLD_V49", "--xj-verify-march-world-v49"),
    "march": ("march_v49.gd", "XJ_MARCH_V49", "march-v49", "MARCH_V49", "--xj-verify-march-v49"),
    "retention": ("retention_v48.gd", "XJ_RETENTION_V48", "retention-v48", "RETENTION_V48", "--xj-verify-retention-v48"),
    "market-cache": ("market_cache_v47.gd", "XJ_MARKET_CACHE_V47", "market-cache-v47", "MARKET_CACHE_V47", "--xj-verify-market-cache-v47"),
    "natural-checkpoint": ("natural_growth_v45.gd", "XJ_NATURAL_GROWTH_V45", "natural-growth-v45", "NATURAL_GROWTH_V45", "--xj-verify-natural-growth-v45"),
    "natural-recovery": ("natural_recovery_v45.gd", "XJ_NATURAL_RECOVERY_V45", "natural-recovery-v45", "NATURAL_RECOVERY_V45", "--xj-verify-natural-recovery-v45"),
    "legacy-boundary": ("legacy_chain_v44.gd", "XJ_LEGACY_CHAIN_V44", "legacy-chain-v44", "LEGACY_CHAIN_V44", "--xj-verify-legacy-chain-v44"),
    "legacy-early": ("legacy_chain_v44.gd", "XJ_LEGACY_CHAIN_V44", "legacy-chain-v44", "LEGACY_CHAIN_V44", "--xj-verify-legacy-chain-v44"),
    "natural-growth": ("natural_growth_v45.gd", "XJ_NATURAL_GROWTH_V45", "natural-growth-v45", "NATURAL_GROWTH_V45", "--xj-verify-natural-growth-v45"),
    "legacy-chain": ("legacy_chain_v44.gd", "XJ_LEGACY_CHAIN_V44", "legacy-chain-v44", "LEGACY_CHAIN_V44", "--xj-verify-legacy-chain-v44"),
    "owned-combat-world": ("owned_combat_world_v43.gd", "XJ_OWNED_COMBAT_WORLD_V43", "owned-combat-world-v43", "OWNED_COMBAT_WORLD_V43", "--xj-verify-owned-combat-world-v43"),
    "auxiliary-boundaries": ("auxiliary_boundaries_v43.gd", "XJ_AUXILIARY_BOUNDARIES_V43", "auxiliary-boundaries-v43", "AUXILIARY_BOUNDARIES_V43", "--xj-verify-auxiliary-boundaries-v43"),
    "fleet-integration": ("fleet_integration_v42.gd", "XJ_FLEET_INTEGRATION_V42", "fleet-integration-v42", "FLEET_INTEGRATION_V42", "--xj-verify-fleet-integration-v42"),
    "fleet-upgrade": ("fleet_upgrade_v42.gd", "XJ_FLEET_UPGRADE_V42", "fleet-upgrade-v42", "FLEET_UPGRADE_V42", "--xj-verify-fleet-upgrade-v42"),
    "auxiliary-world": ("auxiliary_world_v41.gd", "XJ_AUXILIARY_WORLD_V41", "auxiliary-world-v41", "AUXILIARY_WORLD_V41", "--xj-verify-auxiliary-world-v41"),
    "owned-fleet": ("owned_fleet_v40.gd", "XJ_OWNED_FLEET_V40", "owned-fleet-v40", "OWNED_FLEET_V40", "--xj-verify-owned-fleet-v40"),
    "owned-fleet-travel": ("owned_fleet_travel_v40.gd", "XJ_OWNED_FLEET_TRAVEL_V40", "owned-fleet-travel-v40", "OWNED_FLEET_TRAVEL_V40", "--xj-verify-owned-fleet-travel-v40"),
    "owned-fleet-world": ("owned_fleet_world_v40.gd", "XJ_OWNED_FLEET_WORLD_V40", "owned-fleet-world-v40", "OWNED_FLEET_WORLD_V40", "--xj-verify-owned-fleet-world-v40"),
    "measurements": ("measurements_v39.gd", "XJ_MEASUREMENTS_V39", "measurements-v39", "MEASUREMENTS_V39", "--xj-verify-measurements-v39"),
    "blockades-world": ("blockades_world_v39.gd", "XJ_BLOCKADES_WORLD_V39", "blockades-world-v39", "BLOCKADES_WORLD_V39", "--xj-verify-blockades-world-v39"),
    "scenarios-upgrade": ("scenarios_upgrade_v39.gd", "XJ_SCENARIOS_UPGRADE_V39", "scenarios-upgrade-v39", "SCENARIOS_V39", "--xj-verify-scenarios-upgrade-v39"),
    "scenarios-world": ("scenarios_world_v39.gd", "XJ_SCENARIOS_WORLD_V39", "scenarios-world-v39", "SCENARIOS_WORLD_V39", "--xj-verify-scenarios-world-v39"),
    "scenarios": ("scenarios_v39.gd", "XJ_SCENARIOS_V39", "scenarios-v39", "SCENARIOS_V39", "--xj-verify-scenarios-v39"),
    "campaign-extension": ("campaign_extension_v38.gd", "XJ_CAMPAIGN_EXTENSION_V38", "campaign-extension-v38", "CAMPAIGN_EXTENSION_V38", "--xj-verify-campaign-extension-v38"),
    "campaign-world": ("campaign_world_v37.gd", "XJ_CAMPAIGN_WORLD_V37", "campaign-world-v37", "CAMPAIGN_WORLD_V37", "--xj-verify-campaign-world-v37"),
    "campaign-upgrade": ("campaign_v37.gd", "XJ_CAMPAIGN_V37", "campaign-v37", "CAMPAIGN_V37", "--xj-verify-campaign-v37"),
    "campaign": ("campaign_v37.gd", "XJ_CAMPAIGN_V37", "campaign-v37", "CAMPAIGN_V37", "--xj-verify-campaign-v37"),
    "situational": ("situational_v36.gd", "XJ_SITUATIONAL_V36", "situational-v36", "SITUATIONAL_V36", "--xj-verify-situational-v36"),
    "situational-world": ("situational_world_v36.gd", "XJ_SITUATIONAL_WORLD_V36", "situational-world-v36", "SITUATIONAL_WORLD_V36", "--xj-verify-situational-world-v36"),
    "hire": ("hire_v35.gd", "XJ_HIRE_V35", "hire-v35", "HIRE_V35", "--xj-verify-hire-v35"),
    "hire-world": ("hire_world_v35.gd", "XJ_HIRE_WORLD_V35", "hire-world-v35", "HIRE_WORLD_V35", "--xj-verify-hire-world-v35"),
    "hire-travel-world": ("hire_travel_world_v35.gd", "XJ_HIRE_TRAVEL_WORLD_V35", "hire-travel-world-v35", "HIRE_TRAVEL_WORLD_V35", "--xj-verify-hire-travel-world-v35"),
    "frontier": ("frontier_v34.gd", "XJ_FRONTIER_V34", "frontier-v34", "FRONTIER_V34", "--xj-verify-frontier-v34"),
    "frontier-governance-world": ("frontier_governance_world_v34.gd", "XJ_FRONTIER_GOVERNANCE_WORLD_V34", "frontier-governance-world-v34", "FRONTIER_GOVERNANCE_WORLD_V34", "--xj-verify-frontier-governance-world-v34"),
    "frontier-world": ("frontier_world_v34.gd", "XJ_FRONTIER_WORLD_V34", "frontier-world-v34", "FRONTIER_WORLD_V34", "--xj-verify-frontier-world-v34"),
    "frontier-demolition-world": ("frontier_world_v34.gd", "XJ_FRONTIER_WORLD_V34", "frontier-world-v34", "FRONTIER_WORLD_V34", "--xj-verify-frontier-world-v34"),
    "honors": ("honors_v33.gd", "XJ_HONORS_V33", "honors-v33", "HONORS_V33", "--xj-verify-honors-v33"),
    "honors-world": ("honors_world_v33.gd", "XJ_HONORS_WORLD_V33", "honors-world-v33", "HONORS_WORLD_V33", "--xj-verify-honors-world-v33"),
    "roles": ("roles_v32.gd", "XJ_ROLES_V32", "roles-v32", "ROLES_V32", "--xj-verify-roles-v32"),
    "roles-world": ("roles_world_v32.gd", "XJ_ROLES_WORLD_V32", "roles-world-v32", "ROLES_WORLD_V32", "--xj-verify-roles-world-v32"),
    "fitting": ("fitting_v31.gd", "XJ_FITTING_V31", "fitting-v31", "FITTING_V31", "--xj-verify-fitting-v31"),
    "fitting-world": ("fitting_world_v31.gd", "XJ_FITTING_WORLD_V31", "fitting-world-v31", "FITTING_WORLD_V31", "--xj-verify-fitting-world-v31"),
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


def require_supported_diagnostics(binary, names):
    """Read PE metadata before launching flags absent from older clients."""
    if not set(names).intersection({"march", "march-world", "march-upgrade", "march-routes", "natural-mid", "natural-rank", "natural-scout", "natural-research", "natural-rescue", "natural-logistics", "natural-command", "natural-war", "natural-hull", "natural-expedition", "natural-project", "growth-world", "owned-fleet", "owned-fleet-travel", "owned-fleet-world", "auxiliary-world", "fleet-integration", "fleet-upgrade", "owned-combat-world", "auxiliary-boundaries", "legacy-chain", "legacy-early", "legacy-boundary", "natural-growth", "natural-recovery", "natural-checkpoint", "market-cache", "retention"}):
        return
    env = os.environ.copy()
    env["XJ_DIAGNOSTIC_VERSION_FILE"] = str(binary)
    version = subprocess.check_output(
        ["powershell", "-NoProfile", "-NonInteractive", "-Command",
         "(Get-Item -LiteralPath $env:XJ_DIAGNOSTIC_VERSION_FILE).VersionInfo.FileVersion"],
        env=env, text=True, encoding="utf-8").strip()
    numbers = [int(value) for value in re.findall(r"\d+", version)[:4]]
    minimum = (0, 32, 0, 0) if set(names).intersection({'march','march-world','march-upgrade','march-routes','natural-mid','natural-rank','natural-scout','natural-research','natural-rescue','natural-logistics','natural-command','natural-war','natural-hull','natural-expedition','natural-project','growth-world'}) else (0, 31, 0, 0)
    if len(numbers) < 3 or tuple((numbers + [0] * 4)[:4]) < minimum:
        raise RuntimeError(f"这些诊断需要 {'.'.join(map(str,minimum))} 及以上客户端，当前为 {version or '未知'}；未启动游戏。旧包升级须使用其原有固定入口。")
    # Development candidates can share a version while adding fixed endpoints.
    # Refuse an absent flag before an older candidate can fall through to the
    # ordinary user-data startup path.
    with binary.with_suffix('.pck').open('rb') as stream:
        with mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as packed:
            for name in names:
                flag = CASES[name][4]
                if flag.startswith('--') and packed.find(flag.encode('utf-8')) < 0:
                    raise RuntimeError(f'客户端包没有固定诊断入口 {flag}；未启动游戏。')


def activate(process, ready_output=None):
    if ready_output is not None:
        # The built-in presentation endpoint announces when the real native
        # window is ready. Activating a transient startup window can report
        # success while the endpoint still has no focus after initialization.
        deadline = time.monotonic() + 45
        marker = "PRESENTATION_NATIVE_FOCUS awaiting active test window"
        while process.poll() is None and time.monotonic() < deadline:
            if marker in ready_output.read_text(encoding="utf-8", errors="replace"):
                print("WINDOW_READY presentation input endpoint", flush=True)
                break
            time.sleep(0.1)
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
    parser.add_argument("--replay-fps", type=int, choices=[20, 30, 60], default=60,
                        help="Headless normal-play render cadence; production 60 Hz physics is unchanged")
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
        require_supported_diagnostics(binary, args.only)
        identity = {"executable": str(binary), "exe_sha256": sha(binary), "pck_sha256": sha(binary.with_suffix(".pck"))}
    else:
        binary = args.engine.resolve()
        identity = {"engine": str(binary), "catalog_sha256": sha(ROOT / "code/data/catalog.db"),
                    "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                    "code_dirty": bool(subprocess.check_output(["git", "status", "--porcelain", "--", "code"], cwd=ROOT))}
    for name in args.only:
        script, prefix, folder, marker, flag = CASES[name]
        directory = ROOT / "jiaoben/tmp" / folder / str(uuid.uuid4())
        directory.mkdir(parents=True)
        builtin = name in ("base-store", "base-presentation")
        test = ROOT / ("code" if builtin else "jiaoben/tests") / script
        script_at_start = sha(test)
        env = os.environ.copy()
        if name in ("natural-expedition", "natural-project"):
            env["XJ_NATURAL_CAMPAIGN_V58_MODE"] = "expedition" if name == "natural-expedition" else "project"
        if name in ("frontier-world", "frontier-demolition-world"):
            env["XJ_FRONTIER_BATTLE_KIND"] = "demolition" if name == "frontier-demolition-world" else "hold"
        env.pop("XJ_TEST_DATABASE", None)
        if builtin:
            env["XJ_TEST_DATABASE"] = (directory / "progress.db").as_posix()
        else:
            env[prefix + "_SCRIPT"] = test.as_posix()
            env[prefix + "_DIRECTORY"] = directory.as_posix()
        if name != "natural-checkpoint":
            env.pop("XJ_NATURAL_GROWTH_V45_CHECKPOINT_SOURCE", None)
            env.pop("XJ_NATURAL_GROWTH_V45_CHECKPOINT_SHA256", None)
        if name == "campaign-upgrade":
            env["XJ_CAMPAIGN_UPGRADE_ONLY"] = "1"
        if name in ("upgrade", "civilization-upgrade"):
            assert args.legacy and args.legacy.is_file(), "Pass --legacy pointing to a closed test-owned format6 fixture"
            legacy = args.legacy.resolve()
            assert legacy.is_relative_to(ROOT / "jiaoben/tmp")
            env[prefix + "_LEGACY_SOURCE"] = legacy.as_posix()
        stem = f"v18-{mode}-{name}-{run_id}"
        output = ROOT / f"jiaoben/logs/{stem}.log"
        engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
        command = [str(binary), "--audio-driver", "WASAPI", "--log-file", engine_log.as_posix()]
        if name in ("natural-growth","natural-recovery","natural-mid","natural-rank","natural-scout","natural-research","natural-rescue","natural-logistics","natural-command","natural-war","natural-hull","natural-expedition","natural-project") and not args.native:
            # Replay all production physics ticks at fixed frame cadence. Only
            # simulated time describes pacing; wall time is execution cost.
            command += ["--fixed-fps", str(args.replay_fps), "--disable-vsync"]
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
                activate(process, output if name == "base-presentation" else None)
            try:
                # Allow the role world's existing 900s watchdog to finish its
                # real multi-gate freight trip and emit a definitive result.
                code = process.wait(timeout=7200 if name in ("natural-expedition","natural-project") else 3600 if name in ("natural-logistics","natural-command","natural-war","natural-hull","natural-expedition","natural-project") else 2400 if name in ("natural-growth","natural-mid","natural-rank","natural-scout","natural-research","natural-rescue","natural-logistics","natural-command","natural-war","natural-hull","natural-expedition","natural-project") else 1200 if name in ("legacy-chain","legacy-early","legacy-boundary","natural-recovery") else 960 if name in ("roles-world","blockades-world") else 660 if name == "hire-world" else 600)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
                raise
        text = output.read_text(encoding="utf-8", errors="replace")
        engine = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
        finals = re.findall(rf"^{marker}_FINAL_JSON (.+)$", text, re.M)
        captures = sorted(directory.glob("*.png"))
        record = {"case": name, "exit_code": code, "seconds": round(time.monotonic() - started, 2),
                  "directory": str(directory), "script_sha256": script_at_start, "script_changed_during_run": sha(test) != script_at_start, "stdout": str(output), "engine_log": str(engine_log),
                  "stdout_sha256": sha(output), "engine_sha256": sha(engine_log) if engine_log.exists() else None,
                  "captures": [{"path": str(path), "sha256": sha(path)} for path in captures],
                  "diagnostics": [line for line in (text + engine).splitlines() if DIAGNOSTIC.search(line)]}
        if "--fixed-fps" in command:
            record["replay_render_fps"] = args.replay_fps
            record["production_physics_hz"] = 60
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
        assert not record["script_changed_during_run"], f"{name} script changed during execution; result requires review"
        assert re.search(rf"^{marker}(?:_RESULT)? PASS.*failures=0", text, re.M), f"{name} incomplete/failed result: {output}"
        assert not re.search(r"^FAIL(?:\s|$)", text, re.M), f"{name} contains a failed nested assertion: {output}"
        assert not record["diagnostics"], f"{name} diagnostics: {record['diagnostics'][:5]}"
        if "summary" in record:
            assert record["summary"]["result"] == "PASS" and record["summary"]["failures"] == 0
        if name == "market-cache":
            assert record["summary"]["checks"] >= 30 and record["summary"]["groups"] == 114
        if name == "march":
            summary = record['summary']
            assert summary['checks'] >= 50 and summary['groups'] == 114 and not captures
            assert summary['mixed_saved'] and summary['gate_passages'] >= 6
            assert summary['return_checked'] and summary['loss_checked'] and summary['growth_checked']
        if name == 'march-world':
            summary = record['summary']
            assert args.native and summary['checks'] >= 25 and len(captures) == 6
            assert summary['native_moved_m'] >= 200 and summary['departed'] and summary['pause_checked']
            assert summary['gate_ready_checked'] and summary['gate_hidden_checked'] and summary['gate_restore_checked'] and summary['grant_ui_checked']
        if name == 'march-upgrade':
            assert record['summary']['checks'] >= 20 and record['summary']['groups'] == 114 and not captures
        if name == 'march-routes':
            assert record['summary']['checks'] >= 150 and record['summary']['groups'] == 114 and not captures
            assert len(set(record['summary']['routes'])) == 24 and record['summary']['passages'] >= 144
        if name == 'natural-mid':
            summary = record['summary']
            assert summary['checks'] >= 15 and len(summary['completed']) == 3
            assert summary['membership_earned'] and summary['examination_registered'] and summary['normal_loadout']
            assert summary['physical_distance_m'] > 1000 and summary['final_credit'] >= 0
        if name == 'natural-rank':
            summary = record['summary']
            assert summary['checks'] >= 15 and summary['registered'] and summary['contracts_completed'] > 0
            assert summary['reputation_end'] > summary['reputation_start'] and summary['physical_distance_m'] > 1000
        if name == 'natural-scout':
            summary = record['summary']
            assert summary['checks'] >= 15 and summary['ship_bought'] and summary['scout_earned'] and summary['grant_earned']
            assert summary['physical_distance_m'] > 1000 and summary['final_credit'] >= 0
        if name == 'natural-research':
            summary = record['summary']
            assert summary['checks'] >= 15 and summary['research_earned'] and len(summary['completed']) == 2
            assert summary['physical_distance_m'] > 1000 and summary['final_credit'] >= 0
        if name == 'natural-rescue':
            summary = record['summary']
            assert summary['checks'] >= 15 and summary['rescue_earned'] and summary['grant_earned']
            assert summary['physical_distance_m'] > 1000 and summary['final_credit'] >= 0
        if name == 'natural-logistics':
            summary = record['summary']
            assert summary['checks'] >= (12 if summary.get('resumed') else 20) and summary['built'] and summary['delivered'] and summary['grant_earned']
            assert summary['physical_distance_m'] >= (0 if summary.get('resumed') else 1000) and summary['final_credit'] >= 0
        if name == 'natural-command':
            summary = record['summary']
            assert summary['checks'] >= 20 and summary['combat_earned'] and summary['certified'] and summary['war_ready']
            assert summary['physical_distance_m'] > 1000 and summary['final_credit'] >= 0
        if name == 'natural-war':
            summary = record['summary']
            assert summary['checks'] >= 20 and summary['won'] and summary['gate_passages'] >= 6
            assert len(summary['original_fleet']) == 3 and summary['physical_distance_m'] > 1000
        if name == 'natural-hull':
            summary = record['summary']
            assert summary['checks'] >= 20 and summary['researched'] and summary['hull_built'] and summary['fitted']
            assert summary['physical_distance_m'] > 1000 and summary['final_credit'] >= 0
        if name in ('natural-expedition','natural-project'):
            summary = record['summary']
            assert summary['checks'] >= 20
            assert summary['expedition_completed'] if name == 'natural-expedition' else summary['project_completed']
            assert summary['physical_distance_m'] > 1000 and summary['final_credit'] >= 0
        if name == 'growth-world':
            summary = record['summary']
            assert args.native and summary['checks'] >= 25 and len(captures) == 3
            assert summary['selections'] >= 5 and summary['maps'] == summary['services'] == 5 and summary['navigation_started']
        if name == "retention":
            assert record["summary"]["checks"] >= 50 and len(record["summary"]["cases"]) == 2
        if name in ("auxiliary-world","owned-combat-world"):
            performance = record["summary"]["performance"]
            assert performance["native"] and performance["samples"] >= 120 and performance["layouts"]
        if name == "natural-checkpoint":
            summary = record["summary"]
            assert summary["checks"] >= 10 and summary["verification_only"] and len(summary["completed"]) == 8
        if name == "natural-growth":
            summary = record["summary"]
            assert not summary["verification_only"]
            assert summary["checks"] >= 20 and len(summary["completed"]) == 8
            assert summary["physical_distance_m"] > 1000 and summary["earned_credit"] > 0
        if name == "natural-recovery":
            summary = record["summary"]
            assert summary["checks"] >= 15 and summary["naturally_lost"] and summary["rescued"] and summary["paid_replacement"] and summary["physical_distance_m"] > 1000
        assert all(path.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n" for path in captures)
        if name == "owned-fleet":
            assert record["summary"]["checks"] >= 34 and not captures
        if name in ("fleet-integration", "fleet-upgrade"):
            assert record["summary"]["checks"] >= (45 if name == "fleet-integration" else 20) and record["summary"]["groups"] == 114 and not captures
        if name == "legacy-chain":
            assert record["summary"]["checks"] >= 100 and sorted(record["summary"]["formats"]) == [16,17,18,19,20,21,23] and record["summary"]["groups"] == 114 and not captures
        if name == "legacy-early":
            assert record["summary"]["checks"] >= 100 and sorted(record["summary"]["formats"]) == list(range(9,16)) and record["summary"]["groups"] == 114 and not captures
        if name == "legacy-boundary":
            assert record["summary"]["checks"] >= 30 and sorted(record["summary"]["formats"]) == [6,8] and record["summary"]["groups"] == 114 and not captures
        if name == "owned-fleet-travel":
            assert record["summary"]["checks"] >= 100 and record["summary"]["groups"] == 114 and not captures
        if name == "owned-fleet-world":
            assert args.native and record["summary"]["checks"] >= 60 and len(captures) == 5
            assert record["summary"]["owned_moved_m"] > 50 and record["summary"]["owned_cancelled"] and record["summary"]["owned_arrived"]
        if name == "auxiliary-world":
            summary = record["summary"]
            assert args.native and summary["checks"] >= 60 and len(captures) == 6
            assert 0 < summary["repaired_hp"] <= 40 and summary["recon_distance_m"] > 1000
            assert summary["intercepted"] and summary["frozen_intel"] and summary["restored"]
            assert summary["comm_returned"] and summary["blocked_sensing"]
        if name == "owned-combat-world":
            summary = record["summary"]
            assert args.native and summary["checks"] >= 50 and len(captures) == 4
            assert summary["damage_dealt"] > 0 and summary["damage_taken"] > 0 and 0 < summary["owned_repaired_hp"] <= 40
            assert summary["retreat_m"] >= 1800 and summary["returned"] and summary["lost"] and summary["empty_shots"] == 0
        if name == "auxiliary-boundaries":
            summary = record["summary"]
            assert args.native and summary["checks"] >= 40 and len(captures) == 4
            assert summary["timeout_recovered"] and summary["timeout_lost"] and summary["mother_loss"] and summary["rescued"]
        if name in ("measurements","scenarios","scenarios-upgrade"):
            expected_groups = 114
            assert record["summary"]["checks"] >= {"measurements":30,"scenarios":80,"scenarios-upgrade":20}[name] and record["summary"]["groups"] == expected_groups and not captures
        if name == "scenarios-world":
            assert record["summary"]["checks"] >= 100 and len(captures) == 8 and record["summary"]["precision_hp"] >= 180 and record["summary"]["escort_m"] > 5000 and record["summary"]["repair_hp"] >= 120
        if name == "blockades-world":
            assert record["summary"]["checks"] >= 45 and len(captures) >= 5 and record["summary"]["survey_traveled"] > 9000 and record["summary"]["relay_traveled"] > 9000 and record["summary"]["survey_delivered"] == 12 and record["summary"]["relay_delivered"] > 0
        if builtin:
            assert record["summary"]["checks"] >= (6 if name == "base-store" else 110)
            assert len(captures) == (0 if name == "base-store" else 17)
        if name in ("civilizations", "civilization-upgrade"):
            assert record["summary"]["checks"] >= (200 if name == "civilizations" else 25) and len(captures) == 0
        if name == "frontier-governance-world":
            assert record["summary"]["checks"] >= 58 and len(captures) == 5 and record["summary"]["defended"] and record["summary"]["dispatched"] and record["summary"]["physical_damage"] > 0
        if name == "campaign-extension":
            assert record["summary"]["checks"] >= 60 and record["summary"]["groups"] == 114 and record["summary"]["routes_completed"] == 1 and record["summary"]["mineral_cycles"] == 6 and not captures
        if name == "campaign-world":
            assert record["summary"]["checks"] >= 40 and len(captures) >= 6 and record["summary"]["project_visual"] and record["summary"]["physical_tactics"] and record["summary"]["actual_damage"] > 0 and record["summary"]["exported"]
        if name == "campaign-upgrade":
            assert record["summary"]["checks"] >= 20 and record["summary"]["groups"] == 114 and record["summary"]["legacy_checked"] and record["summary"]["upgrade_only"]
        if name == "campaign":
            assert record["summary"]["checks"] >= 60 and record["summary"]["groups"] == 114 and not captures
        if name == "situational":
            assert record["summary"]["checks"] >= (30 if os.environ.get("XJ_SITUATIONAL_LEGACY_DATABASE") else 28) and record["summary"]["groups"] == 114 and not captures
            if os.environ.get("XJ_SITUATIONAL_LEGACY_DATABASE"):
                assert record["summary"]["legacy_checked"] is True
        if name == "situational-world":
            assert record["summary"]["checks"] >= 35 and len(captures) >= 5 and record["summary"]["physical_cues"] >= 2 and record["summary"]["audio_played"] and record["summary"]["pause_checked"]
        if name == "hire":
            assert record["summary"]["checks"] >= 40 and set(record["summary"]["roles"]) == {"escort", "support"} and record["summary"]["groups"] == 114 and not captures
            if os.environ.get("XJ_HIRE_LEGACY_DATABASE"):
                assert record["summary"]["checks"] >= 70 and record["summary"]["legacy_checked"] is True
        if name == "hire-world":
            assert record["summary"]["checks"] >= 60 and len(captures) == 7 and record["summary"]["escort_distance"] > 50 and record["summary"]["enemy_damage"] > 0 and record["summary"]["companion_damage"] > 0 and record["summary"]["healed_cycles"] >= 2 and record["summary"]["refunded"] and record["summary"]["pause_checked"]
        if name == "hire-travel-world":
            assert record["summary"]["checks"] >= 40 and len(captures) == 5 and record["summary"]["crossed"] == 2 and record["summary"]["cancelled"] and record["summary"]["failed_destination"] and record["summary"]["mass_checked"]
        if name == "frontier":
            assert record["summary"]["checks"] >= 134 and {"hold", "demolition"} <= set(record["summary"]["stages"]) and len(record["summary"]["conquered"]) == 2
            if os.environ.get("XJ_FRONTIER_LEGACY_DATABASE"):
                assert record["summary"]["checks"] >= 150 and record["summary"]["legacy_checked"] is True
        if name in ("frontier-world", "frontier-demolition-world"):
            assert record["summary"]["checks"] >= 45 and len(captures) == 5 and record["summary"]["moved_m"] > 2000 and record["summary"]["physical_damage"] > 0
            assert record["summary"]["battle_kind"] == ("demolition" if name == "frontier-demolition-world" else "hold")
        if name == "honors-world":
            assert record["summary"]["checks"] >= 60 and record["summary"]["real_actions"] == 4 and len(captures) == 7
        if name == "honors":
            assert record["summary"]["checks"] >= 150 and record["summary"]["factions"] == 3 and record["summary"]["evidence"] >= 15 and not captures
            if os.environ.get("XJ_HONORS_LEGACY_DATABASE"):
                assert record["summary"]["checks"] >= 190 and record["summary"]["legacy_checked"] is True
        if name == "fitting":
            assert record["summary"]["checks"] >= (77 if os.environ.get("XJ_FITTING_LEGACY_DATABASE") else 60) and len(captures) == 0
        if name == "roles":
            assert record["summary"]["checks"] >= (126 if os.environ.get("XJ_ROLES_LEGACY_DATABASE") else 114) and len(captures) == 0
            if os.environ.get("XJ_ROLES_LEGACY_DATABASE"):
                assert record["summary"]["legacy_checked"]
        if name == "roles-world":
            assert args.native and record["summary"]["checks"] >= 150 and len(captures) == 11 and not record["summary"].get("trip_only", False)
            observations = record["summary"]["observations"]
            protection = {row["hull"]: row for row in observations if row["kind"] == "protection"}
            assert protection.keys() == {"support_weaver", "cruiser_horizon"}
            assert all(row["reference_cost"] <= row["budget"] == 225000 and row["final_enemy_hp"] < row["initial_enemy_hp"] for row in protection.values())
            assert protection["support_weaver"]["final_friend_hp"] > protection["cruiser_horizon"]["final_friend_hp"]
            delivery = next(row for row in observations if row["kind"] == "freight_delivery")
            legs = [row for row in observations if row["kind"] == "freight_leg"]
            assert delivery["delivered_units"] == 24 and delivery["station"] == "station_echo_depot" and delivery["legs"] == len(legs) >= 1
            assert all(row["cargo_units"] == 24 and row["gate_credit"] > 0 for row in legs)
        if name == "fitting-world":
            assert args.native and record["summary"]["checks"] >= 149 and len(captures) == 12
            actual_range = next(row for row in record["summary"]["observations"] if row["kind"] == "range")
            assert actual_range["base_range_m"] < actual_range["distance_m"] < actual_range["actual_range_m"] and actual_range["damage"] > 0
            layouts = {row["case"]: (row["logical_width"], row["logical_height"]) for row in record["summary"]["observations"] if row["kind"] == "layout"}
            assert layouts == {"1440x900-100": (1440, 900), "3440x1188-100": (3440, 1188), "1280x720-200": (640, 360)}
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
