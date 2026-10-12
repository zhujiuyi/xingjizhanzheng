"""Original SVG marks and catalogue-driven asset mappings; no balance values."""
from pathlib import Path
import hashlib,json,sqlite3
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'code/assets/fleet_v1'
MARKS={
    'repair':'<path d="M16 19h32v28H16z" fill="none"/><path d="M28 23h8v8h8v8h-8v8h-8v-8h-8v-8h8z"/><path d="m11 12 6 6m30 0 6-6M11 52l6-6m30 0 6 6" fill="none"/>',
    'recon':'<circle cx="32" cy="32" r="21" fill="none"/><circle cx="32" cy="32" r="12" fill="none"/><path d="M32 11v21l15 15M10 32h8m28 0h8M32 46v8" fill="none"/><circle cx="39" cy="23" r="3"/>',
}
def build():
    DEST.mkdir(parents=True,exist_ok=True);resources=[];entries=[]
    with sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True) as db:
        for role,mark in MARKS.items():
            path=DEST/(role+'.svg')
            path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="1" y="1" width="62" height="62" rx="8" fill="#101b25" stroke="#344e60"/><g fill="#79b5be" stroke="#b8c6ce" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{mark}</g></svg>\n',encoding='utf-8',newline='\n')
            ref='res://'+path.relative_to(ROOT/'code').as_posix();resources.append({'resource_path':ref,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source':'Project-authored static SVG'})
            for (module,) in db.execute('SELECT module_id FROM auxiliary_drone_defs WHERE role_kind=? ORDER BY module_id',(role,)):
                entries.append({'kind':'item','id':module,'resource_path':ref})
                for (recipe,) in db.execute('SELECT recipe_id FROM recipe_defs WHERE output_item_id=?',(module,)):entries.append({'kind':'blueprint','id':recipe,'resource_path':ref})
    manifest={'format_version':1,'asset_version':'fleet-v1','entries':entries,'resources':resources}
    (DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(f'FLEET_ASSETS PASS resources={len(resources)} mappings={len(entries)}')
if __name__=='__main__':build()
