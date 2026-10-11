"""Author paid companions. SQL output is the runtime balance authority."""
from pathlib import Path
import sqlite3

ROOT=Path(__file__).resolve().parents[1]

def literal(value):
    if value is None:return 'NULL'
    if isinstance(value,str):return "'"+value.replace("'","''")+"'"
    return str(value)

def main():
    db=sqlite3.connect((ROOT/'code/data/catalog_frontier_v18.db').as_uri()+'?mode=ro',uri=True)
    db.row_factory=sqlite3.Row
    sql=['-- Paid, finite agency companions. No player-owned hulls are granted.']
    def insert(table,values):sql.append('INSERT INTO '+table+' VALUES('+','.join(map(literal,values))+');')
    origin=db.execute("SELECT * FROM station_defs WHERE station_id='station_anchor_port'").fetchone()
    origin_pose=db.execute('SELECT * FROM anchor_defs WHERE anchor_id=?',(origin['undock_anchor_id'],)).fetchone()
    origin_site=db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?',(origin['undock_anchor_id'],)).fetchone()[0]
    risk=db.execute('SELECT risk_zone_id FROM sector_defs WHERE sector_id=?',(origin['sector_id'],)).fetchone()[0]
    base=dict(db.execute("SELECT * FROM npc_behavior_defs WHERE behavior_id='behavior_scout'").fetchone())
    insert('hire_balance_defs',[1,1,700.0,12000.0,1600.0,1800.0,6.0,120.0,60.0,1800.0,3.0,30.0,20.0])
    profiles=[
      ('escort','护航僚舰','frigate_kestrel',800,3000,0,(250,180,240,18.0,160.0,1800.0)),
      ('support','后勤僚舰','support_weaver',1200,4000,60,(220,260,320,1.0,140.0,1800.0)),
    ]
    for role,title,hull,fee,deposit,budget,stats in profiles:
        arch='hire_'+role;spawn=arch+'_spawn'
        shield,armor,structure,dps,speed,range_m=stats
        insert('npc_archetype_defs',[arch,title,shield,armor,structure,dps,'kinetic',speed,range_m,0])
        for layer,damage,resistance in db.execute("SELECT layer_id,damage_type,resistance FROM npc_resistances WHERE archetype_id='npc_scout_light'"):
            insert('npc_resistances',[arch,layer,damage,resistance])
        behavior=dict(base);behavior['behavior_id']=arch+'_behavior';behavior['archetype_id']=arch
        behavior['detection_range_m']=6000.0;behavior['target_drop_range_m']=9000.0;behavior['leash_radius_m']=1000.0
        behavior['return_radius_m']=60.0;behavior['acceleration_mps2']=30.0
        insert('npc_behavior_defs',list(behavior.values()))
        insert('npc_defs',[arch+'_npc',arch,1,risk])
        anchor=arch+'_anchor'
        insert('anchor_defs',[anchor,origin['sector_id'],'npc_spawn',origin_pose['x_m']+(300 if role=='escort' else -300),origin_pose['y_m'],origin_pose['z_m']+4000.0,origin_pose['yaw_rad'],60.0,0.0])
        insert('anchor_site_defs',[anchor,origin_site])
        patrol=arch+'_patrol'
        insert('anchor_defs',[patrol,origin['sector_id'],'patrol',origin_pose['x_m']+(360 if role=='escort' else -240),origin_pose['y_m'],origin_pose['z_m']+4080.0,origin_pose['yaw_rad'],60.0,0.0])
        insert('anchor_site_defs',[patrol,origin_site])
        insert('npc_spawn_defs',[spawn,arch+'_npc',origin['sector_id'],anchor,behavior['behavior_id'],'mission_scoped','unlock_open_routes',None,0,0])
        insert('npc_patrol_points',[spawn,0,patrol])
        insert('hire_profile_defs',[arch,title,role,hull,spawn,fee,deposit,900.0,budget])
    sql.append("UPDATE catalog_meta SET schema_version=18,content_version='v0.19-hire',ruleset_version='singleplayer_hire_v1',source_document='doc/62-雇佣支援与舰队指令.md';")
    (ROOT/'code/database/hire_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n')
    db.close()

if __name__=='__main__':main()
