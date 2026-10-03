#!/usr/bin/env python3
"""Run fresh SQLite star-chart checks; engine execution must be serialized."""
from pathlib import Path
import argparse
import fcntl
import json
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Requires exclusive Godot Metal/CoreAudio window")
    parser.add_argument("--audio-driver", choices=("Dummy", "CoreAudio"), default="CoreAudio")
    options = parser.parse_args()
    lock_path = ROOT / "jiaoben/tmp/feature-audit.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a") as engine_lock:
        try:
            fcntl.flock(engine_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SystemExit("Another feature audit owns the engine; wait for it to finish") from error
        stem = "star-chart-v13-native" if options.native else "star-chart-v13-headless"
        log = ROOT / f"jiaoben/logs/{stem}.log"
        engine_log = ROOT / f"jiaoben/logs/{stem}-engine.log"
        engine_log.unlink(missing_ok=True)
        command = ["sh", "jiaoben/run_godot.sh"]
        if not options.native:
            command.append("--headless")
        command += ["--audio-driver", options.audio_driver, "--log-file", str(engine_log),
                    "--path", "code", "--script", "../jiaoben/tests/star_chart_v13.gd"]
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=300)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            if isinstance(output, bytes):
                output = output.decode("utf-8", errors="replace")
            log.write_text(output, encoding="utf-8")
            raise SystemExit("STAR_CHART_V13_GUARD FAIL watchdog") from error
        log.write_text(result.stdout, encoding="utf-8")
        print(result.stdout)
        summaries = [line.removeprefix("STAR_CHART_V13_FINAL_JSON ")
                     for line in result.stdout.splitlines() if line.startswith("STAR_CHART_V13_FINAL_JSON ")]
        diagnostics = ("SCRIPT ERROR:", "ERROR:", "WARNING:", "leaked at exit")
        all_logs = result.stdout + (engine_log.read_text(encoding="utf-8") if engine_log.exists() else "")
        assert result.returncode == 0 and "STAR_CHART_V13_RESULT PASS" in result.stdout, result.stdout
        assert len(summaries) == 1 and engine_log.exists(), "missing/duplicated structured result or engine log"
        summary = json.loads(summaries[0])
        assert summary["result"] == "PASS" and summary["failures"] == 0, summary
        assert summary["synthetic_node_counts"] == [120, 300], summary
        assert summary["captures"] >= 6 if options.native else summary["captures"] == 0, summary
        assert not any(marker in all_logs for marker in diagnostics), all_logs
        (ROOT / f"jiaoben/logs/{stem}.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("STAR_CHART_V13_GUARD PASS", log)


if __name__ == "__main__":
    main()
