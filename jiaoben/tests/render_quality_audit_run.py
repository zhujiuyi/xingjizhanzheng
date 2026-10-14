"""Native paired material/FX source audit; fresh UUID DB, shared lock, strict logs.

py jiaoben/tests/render_quality_audit_run.py --label before
py jiaoben/tests/render_quality_audit_run.py --label after --baseline <before-report.json>
--executable uses only the guarded v61 release endpoint, never --path/--script.
"""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import mmap
import os
import re
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
DIAGNOSTIC = re.compile(r"^(?:\s*(?:SCRIPT ERROR|ERROR|WARNING):|.*[Ll]eak(?:ed|ing)?\b|.*Resource still in use)", re.M)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def sources():
    paths = sorted((ROOT / "code/runtime").rglob("*.gd"))
    paths += sorted((ROOT / "code/runtime").rglob("*.gdshader"))
    paths += sorted((ROOT / "code/assets").rglob("*.gdshader"))
    return {path.relative_to(ROOT).as_posix(): sha(path) for path in paths}


def protected():
    paths = sorted((ROOT / "code/assets").rglob("manifest.json"))
    paths += sorted((ROOT / "code/assets/ships").glob("*.tscn"))
    paths += sorted((ROOT / "code/assets/objects").glob("*.tscn"))
    paths += [ROOT / "code/data/catalog.db"]
    return {path.relative_to(ROOT).as_posix(): sha(path) for path in paths}


def render_resources():
    """Raw runtime bytes, including imported-asset originals in actual PCKs."""
    paths = {"runtime/surface_style.gd", "runtime/rendering/surface_materials.gd",
             "runtime/rendering/surface_meshes.gd", "runtime/rendering/material_hangar.gd",
             "runtime/rendering/realistic_effects.gd", "runtime/rendering/ship_v4_factory.gd",
             "runtime/rendering/ship_v4_hangar.gd", "assets/materials_v1/hangar_reflection.res",
             "assets/materials_v1/hangar_reflection.gdshader", "assets/materials_v1/rock_strata.png"}
    for pack in ("materials_v1", "effects_v1", "ship_v4"):
        manifest = ROOT / "code/assets" / pack / "manifest.json"
        if not manifest.is_file():
            continue  # before predates these new packs
        paths.add(manifest.relative_to(ROOT / "code").as_posix())
        for resource in json.loads(manifest.read_text(encoding="utf-8")).get("resources", []):
            path = resource.get("resource_path", resource.get("path", ""))
            if not path.startswith("res://") or ".." in path:
                raise RuntimeError(f"Unsafe runtime pack resource path: {path}")
            paths.add(path.removeprefix("res://"))
    return {"res://" + path: sha(ROOT / "code" / path) for path in sorted(paths)
            if (ROOT / "code" / path).is_file()}


def run(args):
    binary = (args.executable or args.engine).resolve()
    if not binary.is_file():
        raise RuntimeError(f"Engine/client not found: {binary}")
    binary_version = None
    if args.executable:
        if args.label != "after":
            raise RuntimeError("Release mode supports after verification only")
        spec = importlib.util.spec_from_file_location("xj_build_client_metadata", ROOT / "jiaoben/build_client.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        binary_version = module.inspect_windows_binary_version(binary, "0.33.0.0")
        if binary_version.get("result") != "PASS":
            raise RuntimeError("Native Windows version metadata was not verified")
        pck = binary.with_suffix(".pck")
        if not pck.is_file():
            raise RuntimeError(f"External client PCK not found: {pck}")
        with pck.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as packed:
            if packed.find(b"--xj-verify-render-quality-v61") < 0:
                raise RuntimeError("Client lacks fixed v61 render diagnostic; game was not launched")
    baseline = None
    if args.baseline:
        baseline = json.loads(args.baseline.resolve().read_text(encoding="utf-8"))
        if baseline.get("label") != "before" or baseline.get("exit_code") != 0 or baseline.get("diagnostics"):
            raise RuntimeError("Baseline must be a completed native before report with strict logs")
    if args.label == "after" and baseline is None:
        raise RuntimeError("Pass --baseline pointing to the accepted native before report")
    start_sources, start_protected, start_assets = sources(), protected(), render_resources()
    source_identity = None
    if args.executable:
        if args.source_reference:
            source_identity = json.loads(args.source_reference.resolve().read_text(encoding="utf-8"))
            if (source_identity.get("label") != "after" or source_identity.get("mode") != "source-native"
                    or source_identity.get("exit_code") != 0 or source_identity.get("diagnostics")
                    or source_identity.get("source_sha256") != start_sources
                    or source_identity.get("protected_sha256") != start_protected
                    or source_identity.get("render_resource_sha256") != start_assets):
                raise RuntimeError("Current code differs from the accepted source after reference")
        else:
            manifests = [binary.parent / "build-manifest.json", binary.parent.parent / "build-manifest.json"]
            manifest_path = next((path for path in manifests if path.is_file()), None)
            if manifest_path is None:
                raise RuntimeError("Pass --source-reference <accepted source-after report> or provide build-manifest.json")
            identity = json.loads(manifest_path.read_text(encoding="utf-8"))
            head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
            dirty = bool(subprocess.check_output(["git", "status", "--porcelain", "--", "code"], cwd=ROOT))
            if identity.get("source_revision") != head or identity.get("source_dirty") or dirty:
                raise RuntimeError("Current clean source revision must match the actual client build manifest")
            for pack in identity.get("presentation_packs", []):
                path = ROOT / "code" / pack["manifest_path"]
                if not path.is_file() or sha(path) != pack["manifest_sha256"]:
                    raise RuntimeError(f"Current presentation pack differs from client build: {path}")
            source_identity = {"build_manifest": str(manifest_path), "sha256": sha(manifest_path), "source_revision": head}
    if baseline:
        altered = [path for path, value in baseline["protected_sha256"].items()
                   if start_protected.get(path) != value]
        if altered:
            raise RuntimeError(f"Published manifests, wrappers or catalog changed: {altered}")
    run_id = str(uuid.uuid4())
    directory = ROOT / "jiaoben/tmp/render-quality-audit" / run_id
    directory.mkdir(parents=True, exist_ok=False)
    script = ROOT / "jiaoben/tests/render_quality_audit.gd"
    helper = ROOT / "jiaoben/tests/render_quality_contracts.gd"
    launcher = directory / "launcher.gd"
    launcher.write_text("extends SceneTree\nfunc _initialize() -> void:\n\tcall_deferred(\"_start\")\n"
                        "func _start() -> void:\n"
                        f"\tvar source := load({json.dumps(script.as_posix(), ensure_ascii=False)}) as Script\n"
                        "\tif source == null or not source.can_instantiate():\n\t\tquit(1)\n\t\treturn\n"
                        "\troot.add_child(source.new())\n", encoding="utf-8", newline="\n")
    stem = f"render-quality-{args.label}-{'release-native' if args.executable else 'native'}-{run_id}"
    output = ROOT / "jiaoben/logs" / f"{stem}.log"
    engine_log = output.with_name(f"{stem}-engine.log")
    report = output.with_suffix(".json")
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.pop("XJ_TEST_DATABASE", None)
    env["XJ_RENDER_QUALITY_AUDIT_DIRECTORY"] = directory.as_posix()
    env["XJ_RENDER_QUALITY_AUDIT_SCRIPT"] = script.as_posix()
    env["XJ_RENDER_QUALITY_AUDIT_LABEL"] = args.label
    env["XJ_RENDER_QUALITY_MATERIAL_SCRIPT"] = "res://runtime/surface_style.gd"
    env["XJ_RENDER_QUALITY_EFFECTS_SCRIPT"] = "res://runtime/rendering/realistic_effects.gd"
    if baseline:
        env["XJ_RENDER_QUALITY_BASELINE_RESULT"] = baseline["result_path"]
    command = [str(binary), "--audio-driver", "WASAPI", "--log-file", engine_log.as_posix()]
    if args.executable:
        command += ["--", "--xj-verify-render-quality-v61"]
    else:
        command += ["--path", (ROOT / "code").as_posix(), "--script", launcher.as_posix()]
    record = {"label": args.label, "mode": "release-native" if args.executable else "source-native", "engine": str(binary),
              "engine_sha256": sha(binary), "script_sha256": sha(script), "directory": str(directory),
              "helper_sha256": sha(helper),
              "stdout": str(output), "engine_log": str(engine_log), "source_sha256": start_sources,
              "protected_sha256": start_protected, "render_resource_sha256": start_assets, "seed": 71,
              "baseline": str(args.baseline.resolve()) if args.baseline else None,
              "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()}
    if args.executable:
        record.update({"executable": str(binary), "exe_sha256": sha(binary), "pck_sha256": sha(binary.with_suffix(".pck")),
                       "windows_version": binary_version, "source_identity": source_identity})
    print(f"START {stem}", flush=True)
    started = time.monotonic()
    with output.open("wb") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        try:
            record["exit_code"] = process.wait(timeout=540)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            record["exit_code"] = process.returncode
            record["timed_out"] = True
    text = output.read_text(encoding="utf-8", errors="replace")
    engine = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
    record.update({"seconds": round(time.monotonic() - started, 2), "stdout_sha256": sha(output),
                   "engine_log_sha256": sha(engine_log) if engine_log.exists() else None,
                   "script_changed_during_run": sha(script) != record["script_sha256"],
                   "helper_changed_during_run": sha(helper) != record["helper_sha256"],
                   "source_changed_during_run": sources() != start_sources,
                   "protected_changed_during_run": protected() != start_protected,
                   "render_resources_changed_during_run": render_resources() != start_assets,
                   "diagnostics": [line for line in (text + engine).splitlines() if DIAGNOSTIC.search(line)]})
    result_path = directory / "result.json"
    if result_path.exists():
        full = json.loads(result_path.read_text(encoding="utf-8"))
        record["result_path"] = str(result_path)
        record["result_sha256"] = sha(result_path)
        record["summary"] = {key: value for key, value in full.items() if key != "observations"}
        record["cases"] = [entry["case"] for entry in full["observations"]]
        record["pairing_errors"] = []
        if baseline:
            previous = json.loads(Path(baseline["result_path"]).read_text(encoding="utf-8"))
            prior = {entry["case"]: entry for entry in previous["observations"]}
            actual_pairs = {entry["case"] for entry in full["observations"] if not entry["case"].startswith("extra-")}
            if set(prior) != actual_pairs:
                record["pairing_errors"].append(f"Paired case inventory changed: missing={sorted(set(prior) - actual_pairs)} unexpected={sorted(actual_pairs - set(prior))}")
            for entry in full["observations"]:
                if entry["case"].startswith("extra-") and entry["kind"] in {"hangar_quality", "debris_generator", "ship_view", "ore_view", "enemy_ship", "operation_generator"}:
                    continue
                old = prior.get(entry["case"])
                if old is None:
                    record["pairing_errors"].append(f"Missing before case: {entry['case']}")
                    continue
                if entry["kind"] != "hangar" and entry["composition"] != old["composition"]:
                    record["pairing_errors"].append(f"Studio framing/lighting mismatch: {entry['case']}")
            record["hangar_lighting_scope"] = "Actual production hangar changes are recorded; reflection/environment changes are allowed. Controlled studio pairs require identical composition."
    captures = sorted(directory.glob("*.png"))
    record["captures"] = [{"path": str(path), "sha256": sha(path)} for path in captures]
    report.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"REPORT {report}", flush=True)
    assert record["exit_code"] == 0 and engine_log.exists(), f"Native engine failed: {output}"
    assert not any(record[key] for key in ("script_changed_during_run", "helper_changed_during_run", "source_changed_during_run", "protected_changed_during_run", "render_resources_changed_during_run")), "Source or published identity changed during execution"
    assert not record["diagnostics"], f"Strict dual-log diagnostics: {record['diagnostics'][:8]}"
    assert re.search(r"^RENDER_QUALITY_AUDIT_RESULT PASS checks=\d+ failures=0", text, re.M), "Complete successful endpoint missing"
    assert result_path.exists() and record["summary"]["result"] == "PASS" and record["summary"]["failures"] == 0
    assert len(captures) == len(full["observations"]) == record["summary"]["captures"]
    assert len([x for x in full["observations"] if x["kind"] == "ship"]) == 18
    assert len([x for x in full["observations"] if x["kind"] == "hangar"]) == 18
    assert len([x for x in full["observations"] if x["kind"] == "ore"]) == 8
    assert len([x for x in full["observations"] if x["kind"] == "effect"]) == 15
    assert not record.get("pairing_errors"), record.get("pairing_errors")
    if args.executable:
        assert record["summary"]["packed_runtime"], "Actual PCK runtime was not confirmed"
        loaded = record["summary"].get("loaded_resource_sha256", {})
        assert all(loaded.get(path) == value for path, value in start_assets.items()), "PCK rendering resources differ from recorded current source"
        assert len([path for path in loaded if path.startswith("res://assets/ship_v4/") and path.endswith(".glb")]) == 19, "Actual PCK must expose all nineteen authored GLB originals"
        assert len([path for path in loaded if path.startswith("res://assets/ship_v4/portraits/") and path.endswith(".png")]) == 19, "Actual PCK must expose all nineteen authored portraits"
    print(f"RENDER_QUALITY_AUDIT_ACCEPTANCE PASS captures={len(captures)} {report}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True, choices=("before", "after"))
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--executable", type=Path, help="Actual Windows 0.33.0.0 client; fixed v61 entry only")
    parser.add_argument("--source-reference", type=Path, help="Accepted source after report binding current code to the client build")
    parser.add_argument("--engine", type=Path, default=Path("D:/DevTools/Godot/4.7.2/Godot_v4.7.2-stable_win64.exe"))
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
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


if __name__ == "__main__":
    main()
