"""Append four physically distinct doctrines and three mixed encounters; old balance rows stay exact."""
from pathlib import Path
import sqlite3
from build_exploration_content import literal

ROOT=Path(__file__).resolve().parents[1]
def main():
    db=sqlite3.connect((ROOT/'code/data/catalog_mobile_v12.db').as_uri()+'?mode=ro',uri=True);db.row_factory=sqlite3.Row
    assert db.execute('SELECT content_hash FROM catalog_meta').fetchone()[0]=='450ca2a4b020e01d97b2e433b7f682114be3f871d6756146d2794c3791b07f9c'
    sql=['-- Four counterable doctrines; no changes to previously frozen content.']
    def emit(t,v):sql.append(f'INSERT INTO {t} ('+','.join(v)+') VALUES ('+','.join(literal(x) for x in v.values())+');')
    def clone(t,key,val):return dict(db.execute(f'SELECT * FROM {t} WHERE {key}=?',(val,)).fetchone())
    emit('tactical_balance_defs',dict(singleton=1,jam_max_duration_s=4.0,jam_immunity_s=6.0,jam_repeat_window_s=20.0,jam_repeat_multiplier=0.5,jam_max_repeat=3,min_thrust_ratio=0.65,drone_radius_m=3.0))
    models={r['ship_id'] for r in db.execute('SELECT ship_id FROM ship_defs')}
    doctrines=[
      ('support','远程维修支援舰','support_weaver',400,650,600,5,100,850,0.5,3.0,8.0,28.0,0.0,30.0),
      ('interceptor','推进干扰截击舰','frigate_kestrel',140,200,260,8,240,450,1.2,4.0,14.0,1.0,0.0,32.0),
      ('siege','蓄能齐射火力舰','battleship_bastion',650,1000,1000,5,55,1600,4.0,1.0,9.0,180.0,30.0,48.0),
      ('carrier','无人机载机舰','support_council_choir',550,850,1000,5,65,1800,1.5,1.0,10.0,180.0,0.0,40.0),
    ]
    for kind,title,model,shield,armor,hull,dps,speed,range_,charge,duration,cooldown,strength,interrupt,cost in doctrines:
        assert model in models,model
        arch=clone('npc_archetype_defs','archetype_id','npc_scout_light')
        arch.update(archetype_id='tac_'+kind,display_name=title,base_shield=shield,base_armor=armor,base_hull=hull,base_raw_dps=float(dps),speed_mps=float(speed),range_m=float(range_),base_reward_credit={'support':450,'interceptor':350,'siege':850,'carrier':950}[kind])
        emit('npc_archetype_defs',arch)
        for row in db.execute("SELECT * FROM npc_resistances WHERE archetype_id='npc_scout_light'"):
            v=dict(row);v['archetype_id']=arch['archetype_id'];emit('npc_resistances',v)
        behavior=clone('npc_behavior_defs','behavior_id','behavior_scout')
        behavior.update(behavior_id='tac_'+kind+'_behavior',archetype_id=arch['archetype_id'],detection_range_m=3500.0,target_drop_range_m=6000.0,leash_radius_m=7000.0,los_loss_timeout_s=8.0,acceleration_mps2=50.0 if kind=='interceptor' else 18.0,turn_rad_s=1.8 if kind=='interceptor' else 0.8)
        emit('npc_behavior_defs',behavior)
        emit('npc_tactic_defs',dict(tactic_id='tac_'+kind,tactic_kind=kind,display_name=title,model_ship_id=model,charge_s=charge,duration_s=duration,cooldown_s=cooldown,range_m=float(range_),strength=strength,interrupt_hp=interrupt,energy_max=120.0,recharge_eu_s=12.0,energy_cost=cost,projectile_speed_mps=800.0,drone_module_id='module_drone_swarm_ii' if kind=='carrier' else None,drone_reserve=6 if kind=='carrier' else 0))
    for i,module in enumerate(db.execute('SELECT module_id FROM drone_defs ORDER BY module_id')):
        emit('drone_management_defs',dict(module_id=module[0],hull_hp=24.0+i*12.0,material_id='material_structural_stock',material_per_unit=2+i,credit_per_unit=150+i*100))
    au=149597870700.0
    for index,(sector,title,kinds) in enumerate((('sector_echo','回声带 · 维修中继队',('support','interceptor','siege')),('sector_mirror','镜湖 · 齐射封锁队',('siege','interceptor','interceptor')),('sector_forge','熔脊 · 载机护卫队',('carrier','support','interceptor')))):
        home=dict(db.execute('SELECT s.* FROM site_defs s JOIN anchor_site_defs a USING(site_id) JOIN station_defs st ON st.station_anchor_id=a.anchor_id WHERE st.sector_id=? LIMIT 1',(sector,)).fetchone())
        site='tac_'+sector+'_site';anchor='tac_'+sector+'_entry';group='tac_'+sector+'_group'
        emit('site_defs',dict(site_id=site,sector_id=sector,display_name=title,site_kind='encounter',x_m=home['x_m']-au*(2.1+index),y_m=home['y_m']+au*.04,z_m=home['z_m']+au*(1.2+index*.3),pivot_x_m=0.0,pivot_y_m=0.0,pivot_z_m=0.0,local_radius_m=150000.0))
        def point(id_,x,y,z,kind):
            emit('anchor_defs',dict(anchor_id=id_,sector_id=sector,anchor_kind=kind,x_m=float(x),y_m=float(y),z_m=float(z),yaw_rad=0.0,interaction_radius_m=80.0,safe_radius_m=0.0));emit('anchor_site_defs',dict(anchor_id=id_,site_id=site))
        point(anchor,0,0,0,'npc_spawn')
        emit('tactical_site_defs',dict(site_id=group,sector_id=sector,display_name=title,anchor_id=anchor,reveal_range_m=4000.0,respawn_s=900.0,warp_arrival_m=2200.0,required_unlock_id='unlock_open_routes'))
        zone=db.execute('SELECT risk_zone_id FROM sector_defs WHERE sector_id=?',(sector,)).fetchone()[0]
        level=db.execute('SELECT npc_level_min FROM risk_zone_defs WHERE risk_zone_id=?',(zone,)).fetchone()[0]
        for slot,kind in enumerate(kinds):
            npc=clone('npc_defs','npc_id','npc_scout_light_l1');npc.update(npc_id=f'tac_{sector}_{kind}_{slot}',archetype_id='tac_'+kind,level=level,risk_zone_id=zone);emit('npc_defs',npc)
            spawn=f'tac_{sector}_{slot}';location=spawn+'_anchor';patrol=spawn+'_patrol'
            point(location,slot*420-420,(slot-1)*100,350+slot*180,'npc_spawn');point(patrol,slot*420-420,(slot-1)*100,350+slot*180,'patrol')
            emit('npc_spawn_defs',dict(spawn_id=spawn,npc_id=npc['npc_id'],sector_id=sector,anchor_id=location,behavior_id='tac_'+kind+'_behavior',occurrence_mode='mission_scoped',required_unlock_id='unlock_open_routes',respawn_s=None,bounty_enabled=1,loot_enabled=0))
            emit('npc_patrol_points',dict(spawn_id=spawn,point_index=0,anchor_id=patrol));emit('npc_tactic_bindings',dict(spawn_id=spawn,tactic_id='tac_'+kind,site_id=group,member_index=slot))
    sql.append("UPDATE catalog_meta SET schema_version=12,content_version='v0.13-tactics',ruleset_version='singleplayer_tactics_v1',source_document='doc/55-战术敌人与无人机管理.md';")
    (ROOT/'code/database/tactics_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n');db.close();print('TACTICS_CONTENT four doctrines, three mixed encounters and finite drone restoration')
if __name__=='__main__':main()
