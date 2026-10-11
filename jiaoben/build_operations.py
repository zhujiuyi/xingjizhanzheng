"""Append demolition and cargo breakthrough; preserve all v0.13 definitions."""
from pathlib import Path
import sqlite3
from build_exploration_content import literal
ROOT = Path(__file__).resolve().parents[1]

def main():
    db = sqlite3.connect((ROOT/'code/data/catalog_tactics_v13.db').as_uri()+'?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    assert db.execute('SELECT content_hash FROM catalog_meta').fetchone()[0] == '597f1239d3ddf80697e2b1f9a519ac32d653ee72156a256fe578b2ecb8e5f09c'
    sql = ['-- New physical objectives, without modifying historical definitions.']
    def emit(t, v):
        sql.append(f'INSERT INTO {t} ('+','.join(v)+') VALUES ('+','.join(literal(x) for x in v.values())+');')
    def clone(t,k,v): return dict(db.execute(f'SELECT * FROM {t} WHERE {k}=?', (v,)).fetchone())
    for sector, kind, title, units in [('sector_echo','demolition','回声带 · 拆除推进干扰源',2),('sector_mirror','breakthrough','镜湖 · 封锁线物资突破',3)]:
        op = 'op_'+kind; entry = 'tac_'+sector+'_entry'; exit_ = op+'_exit'; site = 'tac_'+sector+'_site'
        point = clone('anchor_defs','anchor_id',entry)
        point.update(anchor_id=exit_, x_m=0.0,y_m=0.0,z_m=-5200.0)
        emit('anchor_defs', point); emit('anchor_site_defs',dict(anchor_id=exit_,site_id=site))
        station = db.execute('SELECT station_id FROM station_defs WHERE sector_id=?', (sector,)).fetchone()[0]
        emit('operation_defs',dict(operation_id=op,display_name=title,operation_kind=kind,station_id=station,tactical_site_id='tac_'+sector+'_group',entry_anchor_id=entry,exit_anchor_id=exit_,required_unlock_id='unlock_open_routes',duration_s=210.0,cooldown_s=900.0,interaction_radius_m=180.0,target_units=units,cargo_volume_l=8000.0 if kind=='breakthrough' else 0.0,cargo_mass_kg=3000.0 if kind=='breakthrough' else 0.0,exposure_duration_s=12.0,loss_damage_hp=80.0,exposure_detection_m=5000.0,credit_per_unit=1800 if kind=='breakthrough' else 2400,reputation_per_unit=20))
        if kind != 'demolition': continue
        arch = clone('npc_archetype_defs','archetype_id','npc_scout_light')
        arch.update(archetype_id='op_jammer', display_name='推进干扰装置',base_shield=0,base_armor=80,base_hull=240,base_raw_dps=1.0,speed_mps=0.01,range_m=1.0,base_reward_credit=0)
        emit('npc_archetype_defs',arch)
        for r in db.execute("SELECT * FROM npc_resistances WHERE archetype_id='npc_scout_light'"):
            r=dict(r);r['archetype_id']='op_jammer';emit('npc_resistances',r)
        npc=clone('npc_defs','npc_id','npc_scout_light_l1');npc.update(npc_id='op_jammer_l2',archetype_id='op_jammer',level=2,risk_zone_id=db.execute('SELECT risk_zone_id FROM sector_defs WHERE sector_id=?',(sector,)).fetchone()[0]);emit('npc_defs',npc)
        behavior=clone('npc_behavior_defs','behavior_id','behavior_scout');behavior.update(behavior_id='op_static_behavior',archetype_id='op_jammer');emit('npc_behavior_defs',behavior)
        for i,x in enumerate((-650.0,650.0)):
            spawn=f'op_jammer_{i}';anchor=spawn+'_anchor'
            point=clone('anchor_defs','anchor_id',entry);point.update(anchor_id=anchor,x_m=x,y_m=0.0,z_m=0.0);emit('anchor_defs',point);emit('anchor_site_defs',dict(anchor_id=anchor,site_id=site))
            emit('npc_spawn_defs',dict(spawn_id=spawn,npc_id=npc['npc_id'],sector_id=sector,anchor_id=anchor,behavior_id=behavior['behavior_id'],occurrence_mode='mission_scoped',required_unlock_id='unlock_open_routes',respawn_s=None,bounty_enabled=0,loot_enabled=0))
            point.update(anchor_id=spawn+'_patrol',anchor_kind='patrol');emit('anchor_defs',point);emit('anchor_site_defs',dict(anchor_id=point['anchor_id'],site_id=site))
            emit('npc_patrol_points',dict(spawn_id=spawn,point_index=0,anchor_id=point['anchor_id']))
            emit('operation_structure_defs',dict(spawn_id=spawn,operation_id=op,field_radius_m=1400.0,thrust_ratio=0.8))
    sql.append("UPDATE catalog_meta SET schema_version=13,content_version='v0.14-operations',ruleset_version='singleplayer_operations_v1',source_document='doc/56-拆除与封锁突破.md';")
    (ROOT/'code/database/operations_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n')
    db.close()
if __name__=='__main__': main()
