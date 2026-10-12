"""Create a genuine closed v0.30 fixture using its existing fitting endpoint."""
from pathlib import Path
import argparse, hashlib, json, msvcrt, os, re, sqlite3, subprocess, uuid
ROOT = Path(__file__).resolve().parents[1]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--legacy-executable',type=Path,required=True);args=parser.parse_args()
    exe=args.legacy_executable.resolve(strict=True)
    assert sha(exe)=='7f1f9b3cf086b70cdb06fd70466897a3f37531fbd96cc04f8b3135755e2381af'
    assert sha(exe.with_suffix('.pck'))=='b10f63ad76dd7e8a2406bf7cd7fee5ed4419a3162f958c830ee68c4653f71389'
    directory=ROOT/'jiaoben/tmp/fitting-v31'/str(uuid.uuid4());directory.mkdir(parents=True)
    output=ROOT/f'jiaoben/logs/v42-legacy-{directory.name}.log';engine=output.with_name(output.stem+'-engine.log')
    env=os.environ.copy()
    for key in ['XJ_TEST_DATABASE','XJ_ROLE_UPGRADE_FIXTURE','XJ_HONOR_UPGRADE_FIXTURE','XJ_FRONTIER_UPGRADE_FIXTURE','XJ_HIRE_UPGRADE_FIXTURE','XJ_SITUATIONAL_UPGRADE_FIXTURE','XJ_CAMPAIGN_UPGRADE_FIXTURE','XJ_SCENARIOS_UPGRADE_FIXTURE']:env.pop(key,None)
    env.update(XJ_FITTING_V31_SCRIPT=(ROOT/'jiaoben/tests/fitting_v31.gd').as_posix(),XJ_FITTING_V31_DIRECTORY=directory.as_posix(),XJ_FLEET_UPGRADE_FIXTURE='1')
    # The caller holds the primary workspace lock when running from a worktree.
    with (ROOT/'jiaoben/tmp/feature-audit.lock').open('a+b') as lock:
        lock.seek(0);lock.write(b'0');lock.flush();lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
        try:
            with output.open('wb') as stream:
                result=subprocess.run([str(exe),'--headless','--audio-driver','WASAPI','--log-file',str(engine),'--','--xj-verify-fitting-v31'],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=300)
        finally:lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1)
    text=output.read_text(encoding='utf-8',errors='replace')
    assert result.returncode==0 and re.search(r'^ROLES_LEGACY_FIXTURE_RESULT PASS.*failures=0',text,re.M),output
    assert not re.search(r'^\s*(SCRIPT ERROR|ERROR|WARNING):|leaked|Resource still in use',text+'\n'+engine.read_text(encoding='utf-8'),re.M|re.I),output
    database=directory/'progress.db'
    with sqlite3.connect(database.as_uri()+'?mode=ro',uri=True) as db:
        assert db.execute('SELECT format_version FROM database_meta').fetchone()==(24,)
        assert db.execute('SELECT content_hash FROM content_snapshot LIMIT 1').fetchone()==('b28cd08757d1db655d7aab2d1eef7fa4b8787fb25c678017a652112f94536eca',)
        assert db.execute('SELECT count(*) FROM industry_job_state').fetchone()[0]>=3
        assert db.execute("SELECT count(*) FROM trial_state WHERE phase='accepted'").fetchone()[0]>0
        assert db.execute("SELECT count(*) FROM hire_contract_state WHERE phase='deployed'").fetchone()[0]>0
        assert db.execute("SELECT count(*) FROM exploration_instance_state WHERE operation_kind='survey' AND operation_remaining_s>0").fetchone()[0]>0
    payload={'result':'PASS','database':str(database),'database_sha256':sha(database),'executable':str(exe),'exe_sha256':sha(exe),'pck_sha256':sha(exe.with_suffix('.pck')),'script_sha256':sha(ROOT/'jiaoben/tests/fleet_upgrade_fixture_v42.gd'),'output':str(output),'engine_log':str(engine),'format':24}
    output.with_suffix('.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(payload,ensure_ascii=False),flush=True)
if __name__=='__main__':main()
