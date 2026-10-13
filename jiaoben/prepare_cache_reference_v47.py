"""Materialize pinned pre-optimization code for independent numerical checks."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
REF='7098b123747554111ae45e14f33a3c5c8b8ea5a1'
SPECS={
    'code/runtime/gameplay/economy.gd':('economy-reference-078571ee36cd.gd','078571ee36cd41ba700e998229d0479dd39f80baefe14b3880a42f76a2972574'),
    'code/runtime/gameplay.gd':('gameplay-reference.gd','239cbc7675a912565b1853b59e7fa93df4da8119a3874ce83efcb28ad9695c9f'),
}
def main():
    dest=ROOT/'jiaoben/tmp/performance-v47';dest.mkdir(parents=True,exist_ok=True);records=[]
    for source,(name,expected) in SPECS.items():
        raw=subprocess.check_output(['git','show',REF+':'+source],cwd=ROOT)
        data=raw.replace(b'class_name XJGameplay\n',b'',1) if source.endswith('/gameplay.gd') else raw
        digest=hashlib.sha256(data).hexdigest();assert digest==expected,source
        path=dest/name
        if path.exists():assert path.read_bytes()==data,path
        else:path.write_bytes(data)
        records.append({'source_revision':REF,'source_path':source,'reference':path.as_posix(),'sha256':digest,'class_declaration_removed':source.endswith('/gameplay.gd')})
    report=ROOT/'jiaoben/logs/v47-cache-reference-index.json';report.write_text(json.dumps({'result':'PASS','references':records},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(report)
if __name__=='__main__':main()
