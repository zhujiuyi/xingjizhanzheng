"""Create an isolated format15 fixture with the actual v0.22 Windows PCK."""
from pathlib import Path
import argparse
import hashlib
import json
import msvcrt
import os
import re
import sqlite3
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--legacy-executable", type=Path, required=True)
    args = parser.parse_args()
    executable = args.legacy_executable.resolve(strict=True)
    directory = ROOT / "jiaoben/tmp/industry-v25" / str(uuid.uuid4())
    directory.mkdir(parents=True)
    script = ROOT / "jiaoben/tests/industry_v25.gd"
    stdout = ROOT / f"jiaoben/logs/fitting-v31-legacy-{directory.name}.log"
    engine = stdout.with_name(stdout.stem + "-engine.log")
    env = os.environ.copy()
    env.update(XJ_INDUSTRY_FIXTURE_ONLY="1", XJ_TACTICS_FIXTURE_BAY="1", XJ_INDUSTRY_V25_SCRIPT=script.as_posix(), XJ_INDUSTRY_V25_DIRECTORY=directory.as_posix())
    env.pop("XJ_TEST_DATABASE", None)
    with (ROOT / "jiaoben/tmp/feature-audit.lock").open("a+b") as lock:
        lock.seek(0); lock.write(b"0"); lock.flush(); lock.seek(0)
        msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            result = subprocess.run([str(executable), "--headless", "--log-file", str(engine), "--", "--xj-verify-industry-v25"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        finally:
            lock.seek(0); msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
    output = result.stdout.decode("utf-8", errors="replace")
    stdout.write_text(output, encoding="utf-8", newline="\n")
    assert result.returncode == 0, output[-4000:]
    for log in (output, engine.read_text(encoding="utf-8")):
        assert not re.search(r"^(?:\s*(?:SCRIPT ERROR|ERROR|WARNING):|.*[Ll]eak(?:ed|ing)?\b|.*Resource still in use)", log, re.M), log[-4000:]
    match = re.search(r"INDUSTRY_FIXTURE_READY (\{.*\})", output)
    assert match, output[-4000:]
    summary = json.loads(match.group(1))
    assert summary["format"] == 15 and summary["content_hash"] == "d46b84f07f8239e4a62cffe96e8467f44cc16553bf48fb46b9155e80869749b0" and summary["jobs"] == 3
    database = directory / "progress.db"
    with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as db:
        assert db.execute("PRAGMA integrity_check").fetchone() == ("ok",)
        assert not db.execute("PRAGMA foreign_key_check").fetchall()
    report = {"fixture": summary, "database_sha256": sha(database), "executable": str(executable), "exe_sha256": sha(executable), "pck_sha256": sha(executable.with_suffix(".pck")), "script_sha256": sha(script), "stdout": str(stdout), "stdout_sha256": sha(stdout), "engine_log": str(engine), "engine_sha256": sha(engine)}
    path = stdout.with_suffix(".json")
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("FITTING_LEGACY_FIXTURE PASS " + str(database))
    print("REPORT " + str(path))


if __name__ == "__main__":
    main()
