"""Author the existing-hull roles without changing any v0.15 catalogue row."""
from pathlib import Path
import sqlite3

ROOT=Path(__file__).resolve().parents[1]
def literal(v):
    if isinstance(v,str): return "'"+v.replace("'","''")+"'"
    return str(v)
def main():
    db=sqlite3.connect((ROOT/'code/data/catalog_fitting_v15.db').as_uri()+'?mode=ro',uri=True)
    sql=['-- Existing hull capabilities and finite consignments.']
    for ship,kind in db.execute('SELECT ship_id,class_id FROM ship_role_defs ORDER BY ship_id'):
        support=kind=='support';explorer=kind=='explorer'
        values=[ship,1.5 if explorer else 1.0,1.5 if explorer else 1.0,int(support),4.0 if support else 1.0,1.25 if ship=='support_council_choir' else 1.0,1.0]
        sql.append('INSERT INTO ship_role_capability_defs VALUES('+','.join(map(literal,values))+');')
    sql.append('INSERT INTO role_balance_defs VALUES(1,20.0,1.0,3.0,250.0,12.0,300.0);')
    routes=[('freight_anchor_echo','锚港—回声带民用货运','station_anchor_port','station_echo_depot',350),('freight_echo_mirror','回声带—镜湖工业补给','station_echo_depot','station_mirror_hub',900)]
    stations={r[0] for r in db.execute('SELECT station_id FROM station_defs')}
    for id_,title,origin,dest,reward in routes:
        assert origin in stations and dest in stations,(origin,dest)
        values=[id_,title,origin,dest,'unlock_open_routes',24,40000.0,8000.0,400,100,reward,900.0,900.0]
        sql.append('INSERT INTO consignment_defs VALUES('+','.join(map(literal,values))+');')
    sql.append("UPDATE catalog_meta SET schema_version=15,content_version='v0.16-roles',ruleset_version='singleplayer_roles_v1',source_document='doc/59-舰种能力与有限承运.md';")
    (ROOT/'code/database/roles_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n')
    db.close()
if __name__=='__main__':main()
