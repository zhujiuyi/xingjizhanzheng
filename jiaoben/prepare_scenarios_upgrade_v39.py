"""Create a closed format23 fixture using the verified real v0.29 executable."""
from pathlib import Path
import argparse,hashlib,json,msvcrt,os,re,sqlite3,subprocess,uuid
ROOT=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--legacy-executable',type=Path,required=True);args=parser.parse_args()
 exe=args.legacy_executable.resolve(strict=True)
 assert sha(exe)=='8d8147341000cca84799c1d89152b1974f05402b82605cfbbea9266324989511'
 assert sha(exe.with_suffix('.pck'))=='61b790db9829139266c0136cc4e6b845be3eb86d21c311ea1319312f6ed7b508'
 directory=ROOT/'jiaoben/tmp/fitting-v31'/str(uuid.uuid4());directory.mkdir(parents=True)
 output=ROOT/f'jiaoben/logs/v39-legacy-{directory.name}.log';engine=output.with_name(output.stem+'-engine.log')
 env=os.environ.copy()
 for key in ['XJ_TEST_DATABASE','XJ_ROLE_UPGRADE_FIXTURE','XJ_HONOR_UPGRADE_FIXTURE','XJ_FRONTIER_UPGRADE_FIXTURE','XJ_HIRE_UPGRADE_FIXTURE','XJ_SITUATIONAL_UPGRADE_FIXTURE','XJ_CAMPAIGN_UPGRADE_FIXTURE']:env.pop(key,None)
 env.update(XJ_FITTING_V31_SCRIPT=(ROOT/'jiaoben/tests/fitting_v31.gd').as_posix(),XJ_FITTING_V31_DIRECTORY=directory.as_posix(),XJ_SCENARIOS_UPGRADE_FIXTURE='1')
 with (ROOT/'jiaoben/tmp/feature-audit.lock').open('a+b') as lock:
  lock.seek(0);lock.write(b'0');lock.flush();lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
  try:r=subprocess.run([str(exe),'--headless','--log-file',str(engine),'--','--xj-verify-fitting-v31'],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
  finally:lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1)
 text=r.stdout.decode('utf-8',errors='replace');output.write_text(text,encoding='utf-8',newline='\n')
 assert r.returncode==0 and re.search(r'^ROLES_LEGACY_FIXTURE_RESULT PASS.*failures=0',text,re.M),output
 assert not re.search(r'^\s*(SCRIPT ERROR|ERROR|WARNING):|leaked|Resource still in use',text+'\n'+engine.read_text(encoding='utf-8'),re.M|re.I),output
 database=directory/'progress.db'
 with sqlite3.connect(database.as_uri()+'?mode=ro',uri=True) as db:
  assert db.execute('SELECT format_version FROM database_meta').fetchone()==(23,)
  assert db.execute('SELECT content_hash FROM content_snapshot LIMIT 1').fetchone()==('b60b0d7883593b5fee43cbd8b3f639a2cdae5ab248f7d0d81beefdf9c16a8e82',)
  assert db.execute('SELECT count(*) FROM industry_job_state').fetchone()[0]>=3
  assert db.execute("SELECT count(*) FROM mission_state WHERE status IN('active','ready')").fetchone()[0]>0
  assert db.execute("SELECT count(*) FROM exploration_instance_state WHERE operation_kind='survey' AND operation_remaining_s>0").fetchone()[0]>0
 payload={'directory':str(directory),'database':str(database),'database_sha256':sha(database),'executable':str(exe),'exe_sha256':sha(exe),'pck_sha256':sha(exe.with_suffix('.pck')),'output':str(output),'engine_log':str(engine),'format':23}
 report=output.with_suffix('.json');report.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(payload,ensure_ascii=False))
if __name__=='__main__':main()
