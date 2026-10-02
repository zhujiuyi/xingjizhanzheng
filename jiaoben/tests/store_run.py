#!/usr/bin/env python3
"""Run native serial acceptance; databases/logs stay in jiaoben."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "jiaoben/logs/store-native.log"

def main():
    runs = (("B historical content", "store_native.gd", []),
            ("Full single-player content", "store_native.gd", ["--", "current"]),
            ("Legacy upgrade/failure recovery", "store_migration.gd", []),
            ("Independent travel transactions", "store_travel_review.gd", []))
    evidence, total = [], 0
    for label, script, extra in runs:
        command = ["sh", "jiaoben/run_godot.sh", "--headless", "--path", "code", "--script", f"../jiaoben/tests/{script}", *extra]
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
        evidence.append(f"=== {label} ===\n{result.stdout}")
        match = re.search(r"STORE_(?:NATIVE|MIGRATION|TRAVEL)_RESULT PASS checks=(\d+) failures=0", result.stdout)
        if result.returncode or not match or "ERROR:" in result.stdout:
            LOG.write_text("\n".join(evidence), encoding="utf-8")
            raise SystemExit(f"Native acceptance failed: {label}; see {LOG}")
        total += int(match.group(1))
        print(label, match.group(0))
    evidence.append(f"STORE_SUITE_RESULT PASS assertions={total}\n")
    LOG.write_text("\n".join(evidence), encoding="utf-8")
    print(f"STORE_SUITE_RESULT PASS assertions={total}; log={LOG}")

if __name__ == "__main__":
    main()
