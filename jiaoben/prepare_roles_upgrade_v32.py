"""Prepare a closed real-format16 world using the verified previous Windows PCK."""
from pathlib import Path
import argparse,hashlib,json,msvcrt,os,re,sqlite3,subprocess,uuid
ROOT=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--legacy-executable',type=Path,required=True);args=p.parse_args()
 executable=args.legacy_executable.resolve(strict=True)
 directory=ROOT/'jiaoben/tmp/fitting-v31'/str(uuid.uuid4());directory.mkdir(parents=True)
 script=ROOT/'jiaoben/tests/fitting_v31.gd'
 output=ROOT/f'jiaoben/logs/v32-legacy-{directory.name}.log';engine=output.with_name(output.stem+'-engine.log')
 env=os.environ.copy();env.update(XJ_FITTING_V31_SCRIPT=script.as_posix(),XJ_FITTING_V31_DIRECTORY=directory.as_posix(),XJ_ROLE_UPGRADE_FIXTURE='1');env.pop('XJ_TEST_DATABASE',None)
 with (ROOT/'jiaoben/tmp/feature-audit.lock').open('a+b') as lock:
  lock.seek(0);lock.write(b'0');lock.flush();lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
  try:r=subprocess.run([str(executable),'--headless','--log-file',str(engine),'--','--xj-verify-fitting-v31'],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
  finally:lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1)
 text=r.stdout.decode('utf-8',errors='replace');output.write_text(text,encoding='utf-8',newline='\n')
 assert r.returncode==0 and re.search(r'^ROLES_LEGACY_FIXTURE_RESULT PASS.*failures=0',text,re.M),output
 logs=text+'\n'+engine.read_text(encoding='utf-8')
 assert not re.search(r'^\s*(SCRIPT ERROR|ERROR|WARNING):|leaked|Resource still in use',logs,re.M|re.I)
 database=directory/'progress.db'
 with sqlite3.connect(database.as_uri()+'?mode=ro',uri=True) as db:
  assert db.execute('SELECT format_version FROM database_meta').fetchone()==(16,)
  assert db.execute("SELECT count(*) FROM specialization_research_state WHERE invested_points=3 AND completed=0").fetchone()[0]>0
  assert db.execute('SELECT count(*) FROM industry_job_state').fetchone()[0]>=3
  assert db.execute('SELECT count(*) FROM drone_bay_state').fetchone()[0]>0
  assert db.execute('SELECT content_hash FROM content_snapshot LIMIT 1').fetchone()[0]=='67062a01b5fac2779b385d27d1bb9988bb49a93dbbc9db01567ff7fea9571409'
 record={'result':'PASS','database':str(database),'exe':str(executable),'exe_sha256':sha(executable),'pck_sha256':sha(executable.with_suffix('.pck')),'script_sha256':sha(script),'format':16,'stdout':str(output),'engine_log':str(engine)}
 report=ROOT/f'jiaoben/logs/v32-legacy-{directory.name}.json';report.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(record,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
