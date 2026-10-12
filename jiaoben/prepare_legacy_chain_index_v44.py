"""Verify retained actual-PCK inputs against their recorded preservation hashes."""
from pathlib import Path
import hashlib,json,sqlite3,uuid
ROOT=Path(__file__).resolve().parents[1]
PRIMARY=Path('E:/星际战舰')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    protected=json.loads((PRIMARY/'jiaoben/logs/cleanup-20261012-plan.json').read_text(encoding='utf-8'))['protected']
    known={str((PRIMARY/r['path']).resolve()):r['sha256'] for r in protected}
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
