"""Author staged objectives for the existing 24 wars and eight frontier sectors."""
from pathlib import Path
import sqlite3

ROOT=Path(__file__).resolve().parents[1]

def literal(value):
    if value is None:return 'NULL'
    if isinstance(value,str):return "'"+value.replace("'","''")+"'"
    return str(value)

def main():
    db=sqlite3.connect((ROOT/'code/data/catalog_honors_v17.db').as_uri()+'?mode=ro',uri=True)
    db.row_factory=sqlite3.Row
    sql=['-- Additive frontier preparation, local convoy, objectives and governance.']
    def insert(table,values):sql.append('INSERT INTO '+table+' VALUES('+','.join(map(literal,values))+');')
    def anchor(id_,sector,site,position,kind='patrol',radius=500.0):
        insert('anchor_defs',[id_,sector,kind,*position,0.0,radius,0.0]);insert('anchor_site_defs',[id_,site]);return id_
    profiles={'convoy':('exp_transport',1),'structure':('op_jammer',1),'ambusher':('npc_raider_medium',3),'raider':('npc_scout_light',4)}
    risks={r[0] for r in db.execute('SELECT DISTINCT s.risk_zone_id FROM sector_defs s JOIN sector_sovereignty_defs p USING(sector_id) WHERE p.conquerable=1')}
    for risk in sorted(risks):
        low,high=db.execute('SELECT npc_level_min,npc_level_max FROM risk_zone_defs WHERE risk_zone_id=?',(risk,)).fetchone()
        for kind,(archetype,level) in profiles.items():insert('npc_defs',[f'frontier_npc_{kind}_{risk}',archetype,max(low,min(high,level)),risk])
    def actor(spawn,sector,site,position,risk,kind,war=None,slot=0):
        arch=profiles['convoy' if kind=='beacon' else kind][0]
        behavior=db.execute('SELECT behavior_id FROM npc_behavior_defs WHERE archetype_id=?',(arch,)).fetchone()[0]
        at=anchor(spawn+'_anchor',sector,site,position,'npc_spawn')
        patrol=anchor(spawn+'_patrol',sector,site,(position[0]+60,position[1],position[2]+80))
        insert('npc_spawn_defs',[spawn,f"frontier_npc_{'convoy' if kind=='beacon' else kind}_{risk}",sector,at,behavior,'mission_scoped','unlock_open_routes',None,0,0])
        insert('npc_patrol_points',[spawn,0,patrol])
        if kind!='beacon':insert('frontier_actor_defs',[spawn,war,sector,kind,slot,'transport_caravan' if kind=='convoy' else None])
        return spawn
    # All amounts below are authored only into frozen SQL, never runtime constants.
    insert('frontier_balance_defs',[1,'material_structural_stock',40,20,8.0,16.0,5.0,500.0,1600.0,150.0,45.0,20.0,500.0,600.0,180.0,1800.0,2400.0,80,20,5,120.0,1000,2,0.9,0.9,10000,50,8000,40,0.75,1.25])
    for w in db.execute('SELECT * FROM civilization_war_defs ORDER BY war_id'):
        war=w['war_id'];sector=w['target_sector_id'];a=db.execute('SELECT * FROM anchor_defs WHERE anchor_id=?',(w['capture_anchor_id'],)).fetchone()
        site=db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?',(w['capture_anchor_id'],)).fetchone()[0]
        risk=db.execute('SELECT risk_zone_id FROM sector_defs WHERE sector_id=?',(sector,)).fetchone()[0]
        x,y,z=a['x_m'],a['y_m'],a['z_m'];prefix='frontier_'+war
        scout=anchor(prefix+'_scout',sector,site,(x-3000,y,z+300))
        start=anchor(prefix+'_start',sector,site,(x-2700,y,z+300))
        exit_=anchor(prefix+'_exit',sector,site,(x,y,z+300))
        convoy=prefix+'_convoy'
        # The spawn precedes its campaign FK; actor membership follows it.
        arch=profiles['convoy'][0];behavior=db.execute('SELECT behavior_id FROM npc_behavior_defs WHERE archetype_id=?',(arch,)).fetchone()[0]
        at=anchor(convoy+'_anchor',sector,site,(x-2700,y,z+300),'npc_spawn')
        patrol=anchor(convoy+'_patrol',sector,site,(x-2640,y,z+380))
        insert('npc_spawn_defs',[convoy,f'frontier_npc_convoy_{risk}',sector,at,behavior,'mission_scoped','unlock_open_routes',None,0,0]);insert('npc_patrol_points',[convoy,0,patrol])
        kind='hold' if int(sector.rsplit('_',1)[1])%2 else 'demolition'
        insert('frontier_campaign_defs',[war,scout,start,exit_,kind,convoy,0 if kind=='hold' else 2])
        insert('frontier_actor_defs',[convoy,war,sector,'convoy',0,'transport_caravan'])
        for i in range(2):actor(prefix+'_ambusher_'+str(i),sector,site,(x-2400+i*350,y,z+800),risk,'ambusher',war,i)
        if kind=='demolition':
            for i in range(2):actor(prefix+'_structure_'+str(i),sector,site,(x+(i*2-1)*650,y,z-350),risk,'structure',war,i)
    for p in db.execute('SELECT * FROM sector_sovereignty_defs WHERE conquerable=1 ORDER BY sector_id'):
        sector=p['sector_id'];w=db.execute('SELECT * FROM civilization_war_defs WHERE target_sector_id=? ORDER BY war_id LIMIT 1',(sector,)).fetchone()
        a=db.execute('SELECT * FROM anchor_defs WHERE anchor_id=?',(w['capture_anchor_id'],)).fetchone()
        site=db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?',(w['capture_anchor_id'],)).fetchone()[0]
        risk=db.execute('SELECT risk_zone_id FROM sector_defs WHERE sector_id=?',(sector,)).fetchone()[0]
        station=db.execute('SELECT station_id FROM station_defs WHERE sector_id=? ORDER BY station_id LIMIT 1',(sector,)).fetchone()[0]
        beacon='frontier_'+sector+'_beacon';actor(beacon,sector,site,(a['x_m'],a['y_m'],a['z_m']+300),risk,'beacon')
        insert('frontier_governance_defs',[sector,station,w['capture_anchor_id'],beacon])
        insert('frontier_beacon_defs',[beacon,sector,'transport_caravan'])
        for i in range(3):actor('frontier_'+sector+'_raider_'+str(i),sector,site,(a['x_m']-800+i*650,a['y_m'],a['z_m']+1000),risk,'raider',None,i)
    sql.append("UPDATE catalog_meta SET schema_version=17,content_version='v0.18-frontier',ruleset_version='singleplayer_frontier_v1',source_document='doc/61-边疆战争与重建争夺.md';")
    (ROOT/'code/database/frontier_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n');db.close()

if __name__=='__main__':main()
