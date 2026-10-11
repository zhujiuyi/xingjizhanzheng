"""Append the commander examination without rewriting any v0.24 definition."""
from pathlib import Path
import sqlite3

ROOT=Path(__file__).resolve().parents[1]

def literal(value):
    if value is None:return 'NULL'
    if isinstance(value,str):return "'"+value.replace("'","''")+"'"
    return str(value)

def main():
    db=sqlite3.connect((ROOT/'code/data/catalog_roles_v16.db').as_uri()+'?mode=ro',uri=True)
    sql=['-- Commander ability proofs; reputation alone does not grant new war commands.']
    events={kind:[row[0] for row in db.execute('SELECT event_id FROM exploration_event_defs WHERE event_kind=? ORDER BY event_id',(kind,))] for kind in ['relic','rescue']}
    freight=[row[0] for row in db.execute('SELECT contract_id FROM consignment_defs ORDER BY contract_id')]
    operations=[row[0] for row in db.execute("SELECT operation_id FROM operation_defs WHERE operation_kind='demolition' ORDER BY operation_id")]
    assert len(events['relic'])==2 and len(events['rescue'])==2 and len(freight)==2 and len(operations)==1
    def insert(table,values):sql.append('INSERT INTO '+table+' VALUES('+','.join(map(literal,values))+');')
    for (faction,) in db.execute('SELECT faction_id FROM civilization_defs ORDER BY faction_id'):
        insert('civilization_command_defs',[faction,'舰队指挥资格',2,5,'unlock_open_routes',4000,400])
        for kind,title,units,ids,field in [
            ('scout','遗迹侦察',1,events['relic'],'event'),
            ('logistics','实物补给',6,freight,'contract'),
            ('rescue','舰队救援',1,events['rescue'],'event'),
            ('combat','战术拆除',2,operations,'operation')]:
            task=f'honor_{faction}_{kind}'
            insert('civilization_honor_task_defs',[task,faction,kind,title,units])
            for index,id_ in enumerate(ids):insert('civilization_honor_source_defs',[task,index,id_ if field=='event' else None,id_ if field=='contract' else None,id_ if field=='operation' else None])
    sql.append("UPDATE catalog_meta SET schema_version=16,content_version='v0.17-honors',ruleset_version='singleplayer_honors_v1',source_document='doc/60-文明贡献与指挥资格.md';")
    (ROOT/'code/database/honors_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n')
    db.close()

if __name__=='__main__':main()
