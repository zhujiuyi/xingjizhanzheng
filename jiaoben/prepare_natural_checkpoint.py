"""Bind a passed normal-play report to its closed, test-owned manual save.

Read-only on all inputs. Produces a small provenance file under logs; never
accepts a player database or rewrites a failed case as a passing checkpoint.
"""
from __future__ import annotations

import argparse
from contextlib import closing
import hashlib
import json
from pathlib import Path
import sqlite3
import uuid

ROOT = Path(__file__).resolve().parents[1]
PROFILES = {
    "natural-hull": ("natural-hull-v57", 4, "v57-hull-origin", "fitted"),
    "natural-war": ("natural-war-v56", 3, "v56-war-origin", "won"),
    "natural-command": ("natural-command-v55", 2, "v55-command-origin", "war_ready"),
    "natural-logistics": ("natural-logistics-v54", 1, "v54-logistics-origin", "delivered"),
    "natural-research": ("natural-research-v52", 4, "v53-research-origin", "research_earned"),
    "natural-rescue": ("natural-rescue-v53", 0, "v53-rescue-origin", "rescue_earned"),
}


def sha(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def prepare(report: Path, case: str) -> Path:
    report = report.resolve(strict=True)
    logs = (ROOT / "jiaoben/logs").resolve()
    assert report.parent == logs and report.name.startswith("v18-"), "Require a local verifier report"
    prefix, slot, output_prefix, milestone = PROFILES[case]
    data = json.loads(report.read_text(encoding="utf-8"))
    cases = [row for row in data["cases"] if row["case"] == case]
    assert len(cases) == 1
    result = cases[0]
    summary = result["summary"]
    assert result["exit_code"] == 0 and not result["diagnostics"]
    assert summary["result"] == "PASS" and summary["failures"] == 0 and summary[milestone]
    for key, hash_key in [("stdout", "stdout_sha256"), ("engine_log", "engine_sha256")]:
        path = Path(result[key]).resolve(strict=True)
        assert path.parent == logs and sha(path) == result[hash_key]
    directory = Path(result["directory"]).resolve(strict=True)
    assert directory.parent == (ROOT / "jiaoben/tmp" / prefix).resolve()
    uuid.UUID(directory.name)
    database = directory / "progress.db"
    before = sha(database)
    with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)) as connection:
        assert connection.execute("PRAGMA quick_check").fetchall() == [("ok",)]
        rows = connection.execute(
            "SELECT p.credit FROM save_slot s JOIN player_state p "
            "ON p.snapshot_id=s.current_snapshot_id AND p.world_id=s.world_id "
            "WHERE s.slot_kind='manual' AND s.slot_index=?", (slot,)
        ).fetchall()
        assert rows == [(summary["final_credit"],)], "Require the exact earned manual wallet"
    assert sha(database) == before
    proof = {
        "result": "PASS", "database": database.as_posix(), "database_sha256": before,
        "manual_slot": slot, "source_report": str(report), "source_report_sha256": sha(report),
        "credit": summary["final_credit"], "scope": summary["scope"],
    }
    output = logs / f"{output_prefix}-{uuid.uuid4()}.json"
    output.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    (logs / f"{output_prefix}-path.txt").write_text(str(output) + "\n", encoding="utf-8", newline="\n")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--case", choices=PROFILES, required=True)
    args = parser.parse_args()
    print(prepare(args.report, args.case))
