"""Create a closed format8 fixture with an actual previously delivered client."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--legacy-executable', type=Path, required=True)
    args = parser.parse_args()
    executable = args.legacy_executable.resolve()
    directory = ROOT / 'jiaoben/tmp/civilization-upgrade-v24-fixture' / str(uuid.uuid4())
    directory.mkdir(parents=True)
    database = directory / 'progress.db'
    log = directory / 'legacy-client.log'
    env = os.environ.copy()
    env['XJ_TEST_DATABASE'] = database.as_posix()
    with log.open('wb') as output:
        completed = subprocess.run([str(executable), '--headless', '--audio-driver', 'WASAPI', '--', '--xj-verify-store'],
                                   cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=90)
    text = log.read_text(encoding='utf-8')
    assert completed.returncode == 0 and 'STORE_RELEASE_RESULT PASS checks=6 failures=0' in text
    assert not re.search(r'^(?:SCRIPT ERROR|ERROR|WARNING):|[Ll]eaked', text, re.M)
    connection = sqlite3.connect(database.as_uri() + '?mode=ro', uri=True)
    try:
        assert connection.execute('SELECT format_version FROM database_meta').fetchone()[0] == 8
        assert connection.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert connection.execute('PRAGMA foreign_key_check').fetchall() == []
        assert connection.execute('SELECT DISTINCT content_hash FROM content_snapshot').fetchall() == [('d154bb865cf98a88d5db0e14722b8fa94f361500bb1687cd4ee38b8579a84d99',)]
    finally:
        connection.close()
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    result = {'result': 'PASS', 'database': str(database), 'database_sha256': sha(database),
              'legacy_executable': str(executable), 'legacy_exe_sha256': sha(executable),
              'legacy_pck_sha256': sha(executable.with_suffix('.pck')), 'format': 8,
              'stdout': str(log), 'stdout_sha256': sha(log)}
    report = ROOT / 'jiaoben/logs/civilization-upgrade-v24-fixture.json'
    report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
