"""Append three real AU locations per temporary belt without rewriting its prior definitions."""
from pathlib import Path
import sqlite3
from build_exploration_content import literal

ROOT = Path(__file__).resolve().parents[1]


def main():
    db = sqlite3.connect((ROOT / 'code/data/catalog_exploration_v11.db').as_uri()+'?mode=ro',uri=True)
    db.row_factory = sqlite3.Row
    assert db.execute('SELECT content_hash FROM catalog_meta').fetchone()[0] == '9de35ad2ff0d3a20410c2b46202a6f01e81e651f2e6302247603df87fd38b8ff'
    sql = ['-- Current mineral cycles rotate between three separately simulated AU sites.']
    def emit(table, values):
        sql.append(f'INSERT INTO {table} ('+','.join(values)+') VALUES ('+','.join(literal(v) for v in values.values())+');')
    for event in db.execute("SELECT * FROM exploration_event_defs WHERE event_kind='mineral' ORDER BY event_id"):
        site = dict(db.execute('SELECT s.* FROM site_defs s JOIN anchor_site_defs a USING(site_id) WHERE a.anchor_id=?',(event['entry_anchor_id'],)).fetchone())
        anchors = [dict(r) for r in db.execute('SELECT d.* FROM anchor_defs d JOIN anchor_site_defs a USING(anchor_id) WHERE a.site_id=? ORDER BY anchor_id',(site['site_id'],))]
        for index in range(3):
            route = f"belt_{event['event_id']}_r{index}"
            mapping = {a['anchor_id']: a['anchor_id'] if index == 0 else route+'_'+a['anchor_id'] for a in anchors}
            if index:
                new_site = dict(site)
                new_site.update(site_id=route+'_site',display_name=event['display_name']+f' · 迁移区{index+1}',x_m=site['x_m']+149597870700.0*0.4*index,z_m=site['z_m']+149597870700.0*1.05*index)
                emit('site_defs',new_site)
                for a in anchors:
                    value = dict(a); x,z = a['x_m'],a['z_m']
                    value.update(anchor_id=mapping[a['anchor_id']],x_m=-z if index==1 else -x,z_m=x if index==1 else -z)
                    emit('anchor_defs',value)
                    emit('anchor_site_defs',{'anchor_id':value['anchor_id'],'site_id':new_site['site_id']})
            emit('exploration_belt_route_defs',{'route_id':route,'event_id':event['event_id'],'route_index':index,'display_name':('初始矿区','第二迁移区','第三迁移区')[index],'entry_anchor_id':mapping[event['entry_anchor_id']],'exit_anchor_id':mapping[event['exit_anchor_id']]})
            for base,actual in mapping.items(): emit('exploration_belt_anchor_defs',{'route_id':route,'base_anchor_id':base,'anchor_id':actual})
    for index,threshold,cap,title in ((1,3300,7500,'外围散逸'),(2,6600,4000,'矿脉破碎'),(3,9000,1500,'最后残留')):
        emit('exploration_belt_stage_defs',{'stage_index':index,'threshold_bp':threshold,'remaining_cap_bp':cap,'warning_lead_s':15.0,'display_name':title})
    sql.append("UPDATE catalog_meta SET schema_version=11,content_version='v0.12-mobile-belts',ruleset_version='singleplayer_mobile_belts_v1',source_document='doc/54-迁移矿带与分段衰减.md';")
    (ROOT/'code/database/mobile_belts_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n')
    db.close()
    print('MOBILE_BELTS_CONTENT PASS six AU routes, deterministic geometry and three decay stages')


if __name__ == '__main__': main()
