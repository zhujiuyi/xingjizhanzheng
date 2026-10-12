"""Prove an actual client changed only its embedded diagnostic, not the game.

Both inventories come from the respective shipped EXE/PCK virtual file system.
This permits retaining applicable acceptance evidence after a diagnostic-only
repack. Any other byte difference rejects that reuse.
"""
from pathlib import Path
import argparse,hashlib,json,msvcrt,os,re,subprocess,uuid
ROOT=Path(__file__).resolve().parents[1]
DIAGNOSTIC='res://runtime/presentation_diagnostic.gd'

def sha(path):
 with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def inventory(executable,directory,label):
 output=directory/(label+'.json');log=directory/(label+'.log');engine=directory/(label+'-engine.log')
 env=os.environ.copy();env.pop('XJ_TEST_DATABASE',None)
 args=[str(executable),'--headless','--audio-driver','WASAPI','--log-file',str(engine),'--script',str(ROOT/'jiaoben/tests/pck_manifest_v36.gd'),'--','--xj-pck-manifest-out='+output.as_posix()]
 r=subprocess.run(args,cwd=executable.parent,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
 log.write_bytes(r.stdout)
 text=r.stdout.decode('utf-8')+'\n'+engine.read_text('utf-8')
 assert r.returncode==0 and 'PCK_MANIFEST_V36_RESULT PASS' in text,log
 assert not re.search(r'^\s*(SCRIPT ERROR|ERROR|WARNING):|leaked|Resource still in use',text,re.M|re.I),log
 q=json.loads(output.read_text('utf-8'))
 assert Path(q['exe']).resolve()==executable and len(q['files'])>300
 return q,output

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--before',type=Path,required=True);parser.add_argument('--after',type=Path,required=True);args=parser.parse_args()
 before=args.before.resolve(strict=True);after=args.after.resolve(strict=True)
 for p in [before,after]:p.relative_to((ROOT/'jiaoben/tmp/delivery').resolve())
 directory=ROOT/'jiaoben/tmp/pck-v36'/str(uuid.uuid4());directory.mkdir(parents=True)
 with (ROOT/'jiaoben/tmp/feature-audit.lock').open('a+b') as lock:
  lock.seek(0);lock.write(b'0');lock.flush();lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
  try:
   old,old_path=inventory(before,directory,'before');new,new_path=inventory(after,directory,'after')
  finally:lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1)
 assert old['version']==new['version']=='0.28.0'
 allowed={DIAGNOSTIC,DIAGNOSTIC+'.remap'}
 all_paths=set(old['files'])|set(new['files'])
 # Compiled-script names preserve their source basename under .godot/exported.
 allowed|={p for p in all_paths if p.startswith('res://.godot/exported/') and p.endswith('presentation_diagnostic.gdc')}
 changed={p for p in all_paths if old['files'].get(p)!=new['files'].get(p)}
 assert changed and changed<=allowed,('Non-diagnostic game components changed',sorted(changed-allowed))
 old_loose={p.relative_to(before.parent).as_posix():sha(p) for p in before.parent.rglob('*') if p.is_file() and p.suffix!='.pck'}
 new_loose={p.relative_to(after.parent).as_posix():sha(p) for p in after.parent.rglob('*') if p.is_file() and p.suffix!='.pck'}
 assert old_loose==new_loose,'EXE or external runtime changed'
 q={'result':'PASS','before_exe':str(before),'after_exe':str(after),'exe_sha256':sha(after),'before_pck_sha256':sha(before.with_suffix('.pck')),'after_pck_sha256':sha(after.with_suffix('.pck')),'before_manifest':str(old_path),'before_manifest_sha256':sha(old_path),'after_manifest':str(new_path),'after_manifest_sha256':sha(new_path),'unchanged_files':len(all_paths-changed),'changed_diagnostic_files':sorted(changed),'loose_runtime_files':len(old_loose)}
 report=ROOT/'jiaoben/logs/v36-diagnostic-only-repack.json';report.write_text(json.dumps(q,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(q,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
