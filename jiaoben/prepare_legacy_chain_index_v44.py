"""Verify retained actual-PCK inputs against their recorded preservation hashes."""
from pathlib import Path
import argparse,hashlib,json,sqlite3,uuid
ROOT=Path(__file__).resolve().parents[1]
PRIMARY=Path('E:/星际战舰')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def early_inputs(known):
    registry=PRIMARY/'jiaoben/logs/v39-release-inputs.json'
    paths=json.loads(registry.read_text(encoding='utf-8'))
    inputs=[]
    for key in ['XJ_INDUSTRY_LEGACY_DATABASE','XJ_RESOURCE_INTEL_LEGACY_DATABASE']:
        # These two retained compatibility inputs have custody hashes and a
        # historical input registry; surviving direct writer proofs are absent.
        # Do not describe them as newly proved actual-PCK writer inputs.
        inputs.append({'database':paths[key],'proof':str(registry),'proof_sha256':sha(registry),'provenance_kind':'retained-input-registry'})
    for proof_path in sorted((PRIMARY/'jiaoben/logs').glob('*legacy*.json')):
        proof=json.loads(proof_path.read_text(encoding='utf-8'))
        if not isinstance(proof,dict) or not isinstance(proof.get('fixture'),dict) or proof['fixture'].get('format') not in range(11,16):continue
        stdout=Path(proof['stdout']);engine=Path(proof['engine_log'])
        assert sha(stdout)==proof['stdout_sha256'] and sha(engine)==proof['engine_sha256']
        assert '_FIXTURE_READY ' in stdout.read_text(encoding='utf-8')
        inputs.append({'database':proof['fixture']['database'],'proof':str(proof_path),'proof_sha256':sha(proof_path),'provenance_kind':'actual-PCK-writer','exe_sha256':proof['exe_sha256'],'pck_sha256':proof['pck_sha256'],'stdout_sha256':sha(stdout),'engine_sha256':sha(engine)})
    for entry in inputs:
        source=Path(entry['database']).resolve()
        assert source.is_relative_to((PRIMARY/'jiaoben/tmp').resolve()) and '/recovery-' not in source.as_posix()
        digest=sha(source);assert digest==known[str(source)],source
        with sqlite3.connect(source.as_uri()+'?mode=ro',uri=True) as db:
            version=db.execute('SELECT format_version FROM database_meta').fetchone()[0]
            content=db.execute('SELECT content_hash FROM content_snapshot LIMIT 1').fetchone()[0]
            shapes={}
            for (table,) in db.execute("SELECT name FROM sqlite_schema WHERE type='table' AND name LIKE '%_state' ORDER BY name"):
                cols=db.execute(f'PRAGMA table_info("{table}")').fetchall()
                if not {'snapshot_id','world_id','content_snapshot_id'}<=set(row[1] for row in cols):continue
                fields=[row[1] for row in cols if row[1] not in {'snapshot_id','world_id','content_snapshot_id'}]
                keys=[row[1] for row in sorted(cols,key=lambda row:row[5]) if row[5] and row[1] in fields]
                assert keys,(table,version)
                shapes[table]={'columns':fields,'keys':keys}
        entry.update(database=source.as_posix(),database_sha256=digest,format=version,content_hash=content,state_shapes=shapes)
    assert sorted(r['format'] for r in inputs)==list(range(9,16))
    return sorted(inputs,key=lambda r:r['format'])
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--early',action='store_true');args=parser.parse_args()
    protected=json.loads((PRIMARY/'jiaoben/logs/cleanup-20261012-plan.json').read_text(encoding='utf-8'))['protected']
    known={str((PRIMARY/r['path']).resolve()):r['sha256'] for r in protected}
    if args.early:
        inputs=early_inputs(known)
        path=ROOT/f'jiaoben/logs/v44-legacy-input-index-{uuid.uuid4()}.json'
        path.write_text(json.dumps({'result':'PASS','scope':'early-retained','inputs':inputs},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(str(path),flush=True);return
    inputs=[]
    for proof_path in sorted((PRIMARY/'jiaoben/logs').glob('*legacy*.json')):
        proof=json.loads(proof_path.read_text(encoding='utf-8'))
        if not isinstance(proof,dict) or proof.get('format') not in (16,17,18,19,20,21,23):continue
        source=Path(proof['database']).resolve();assert source.is_relative_to((PRIMARY/'jiaoben/tmp/fitting-v31').resolve())
        digest=sha(source);assert digest==known[str(source)],source
        stdout=Path(proof.get('stdout',proof.get('output')));engine=Path(proof['engine_log'])
        assert stdout.exists() and engine.exists()
        text=stdout.read_text(encoding='utf-8',errors='replace');assert 'ROLES_LEGACY_FIXTURE_RESULT PASS' in text
        with sqlite3.connect(source.as_uri()+'?mode=ro',uri=True) as db:
            version=db.execute('SELECT format_version FROM database_meta').fetchone()[0];assert version==proof['format']
            content=db.execute('SELECT content_hash FROM content_snapshot LIMIT 1').fetchone()[0]
        inputs.append({'database':source.as_posix(),'database_sha256':digest,'format':version,'content_hash':content,'proof':str(proof_path),'proof_sha256':sha(proof_path),'exe_sha256':proof['exe_sha256'],'pck_sha256':proof['pck_sha256'],'stdout_sha256':sha(stdout),'engine_sha256':sha(engine)})
    assert sorted(r['format'] for r in inputs)==[16,17,18,19,20,21,23]
    path=ROOT/f'jiaoben/logs/v44-legacy-input-index-{uuid.uuid4()}.json';path.write_text(json.dumps({'result':'PASS','inputs':inputs},ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(str(path),flush=True)
if __name__=='__main__':main()
