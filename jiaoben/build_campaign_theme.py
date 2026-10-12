"""Author six campaign encounters by extending reviewed exploration structures.

Gameplay amounts remain in the original SQL definitions or campaign_seed.sql.
This builder supplies names, locations, references and fixed source variants.
"""
from pathlib import Path
import sqlite3
ROOT=Path(__file__).resolve().parents[1]
ARCHIVE=ROOT/'code/data/catalog_situational_v20.db'
EVENTS=[
 ('01','rescue','resource','exp_echo_rescue','晨岬失联运输','fragments'),
 ('01','relic','signal','exp_mirror_relic','晨岬旧中继档案','em'),
 ('02','mineral','resource','exp_echo_mineral','浮屿漂移矿脉','solar'),
 ('02','rescue','signal','exp_mirror_rescue','浮屿被困补给舰','fragments'),
 ('03','mineral','resource','exp_echo_mineral','寒浦外围矿带','em'),
 ('03','relic','signal','exp_mirror_relic','寒浦热区信标','solar'),
]

def literal(value):
 if value is None:return 'NULL'
 if isinstance(value,str):return "'"+value.replace("'","''")+"'"
 return str(value)

def main():
 c=sqlite3.connect(ARCHIVE.as_uri()+'?mode=ro',uri=True);c.row_factory=sqlite3.Row
 sql=['-- Six authored places in three existing frontier systems.']
 def rows(table,where='',args=()):return [dict(r) for r in c.execute('SELECT * FROM '+table+(' WHERE '+where if where else ''),args)]
 def insert(table,row):sql.append('INSERT INTO '+table+'('+','.join(row)+') VALUES('+','.join(literal(x) for x in row.values())+');')
 for number,kind,site_kind,template,title,environment in EVENTS:
  event='exp_theme_frontier_'+number+'_'+kind;sector='sector_frontier_'+number;site='site_frontier_'+number+'_'+site_kind
  original=rows('exploration_event_defs','event_id=?',(template,))[0]
  old_entry=rows('anchor_defs','anchor_id=?',(original['entry_anchor_id'],))[0]
  reference_site=rows('site_defs','site_id=?',(site,))[0]
  new_site=dict(reference_site);new_site['site_id']=event+'_site';new_site['display_name']=title
  neighbour=rows('site_defs','site_id=?',('site_frontier_'+number+('_station' if site_kind=='resource' else '_encounter'),))[0]
  for axis in ['x_m','y_m','z_m']:new_site[axis]=(reference_site[axis]+neighbour[axis])*0.5
  site=new_site['site_id'];insert('site_defs',new_site)
  offset=[new_site['pivot_x_m']+2000-old_entry['x_m'],new_site['pivot_y_m']+200-old_entry['y_m'],new_site['pivot_z_m']+1000-old_entry['z_m']]
  actors=rows('exploration_actor_defs','event_id=?',(template,))
  spawns={r['spawn_id']:rows('npc_spawn_defs','spawn_id=?',(r['spawn_id'],))[0] for r in actors}
  resources=rows('exploration_resource_defs','event_id=?',(template,))
  obstacles=rows('exploration_obstacle_defs','event_id=?',(template,))
  anchor_ids={original['entry_anchor_id'],original['exit_anchor_id']}
  anchor_ids|={r['anchor_id'] for r in spawns.values()}|{r['anchor_id'] for r in obstacles}
  for spawn in spawns:anchor_ids|={r['anchor_id'] for r in rows('npc_patrol_points','spawn_id=?',(spawn,))}
  for resource in resources:anchor_ids.add(rows('resource_node_locations','node_id=?',(resource['node_id'],))[0]['anchor_id'])
  mapping={old:event+'_anchor_'+str(i) for i,old in enumerate(sorted(anchor_ids))}
  authored=[]
  for old in sorted(anchor_ids):
   row=rows('anchor_defs','anchor_id=?',(old,))[0];row['anchor_id']=mapping[old];row['sector_id']=sector
   for i,key in enumerate(['x_m','y_m','z_m']):row[key]+=offset[i]
   insert('anchor_defs',row);authored.append(dict(row));insert('anchor_site_defs',{'anchor_id':row['anchor_id'],'site_id':site})
  row=dict(original);row.update(event_id=event,display_name=title,sector_id=sector,entry_anchor_id=mapping[original['entry_anchor_id']],exit_anchor_id=mapping[original['exit_anchor_id']],station_id='station_frontier_'+number,environment_kind=environment,clue_text=title+'：调查与处理会为本星系长期工程留下贡献。')
  insert('exploration_event_defs',row)
  for variant in rows('exploration_variant_defs','event_id=?',(template,)):
   variant['variant_id']=event+'_v'+str(variant['variant_index']);variant['event_id']=event;insert('exploration_variant_defs',variant)
  risk=rows('sector_defs','sector_id=?',(sector,))[0]['risk_zone_id'];risk_def=rows('risk_zone_defs','risk_zone_id=?',(risk,))[0]
  for actor in actors:
   old_spawn=actor['spawn_id'];spawn=dict(spawns[old_spawn]);new_spawn=event+'_'+actor['actor_role']+'_'+str(actor['slot_index'])
   npc=rows('npc_defs','npc_id=?',(spawn['npc_id'],))[0]
   if actor['actor_role']=='enemy':
    tactic=['tac_support','tac_interceptor','tac_siege'][actor['slot_index']]
    binding=rows('npc_tactic_bindings','tactic_id=?',(tactic,))[0]
    source_spawn=rows('npc_spawn_defs','spawn_id=?',(binding['spawn_id'],))[0]
    npc=rows('npc_defs','npc_id=?',(source_spawn['npc_id'],))[0]
    spawn['behavior_id']=source_spawn['behavior_id']
   npc['npc_id']=new_spawn+'_npc';npc['risk_zone_id']=risk
   npc['level']=min(risk_def['npc_level_max'],max(risk_def['npc_level_min'],npc['level']))
   insert('npc_defs',npc);spawn.update(spawn_id=new_spawn,npc_id=npc['npc_id'],sector_id=sector,anchor_id=mapping[spawn['anchor_id']]);insert('npc_spawn_defs',spawn)
   for patrol in rows('npc_patrol_points','spawn_id=?',(old_spawn,)):
    patrol.update(spawn_id=new_spawn,anchor_id=mapping[patrol['anchor_id']]);insert('npc_patrol_points',patrol)
   actor.update(event_id=event,spawn_id=new_spawn);insert('exploration_actor_defs',actor)
  for resource in resources:
   old=resource['node_id'];new=event+'_'+resource['choice_id']
   node=rows('resource_node_defs','node_id=?',(old,))[0];node.update(node_id=new,sector_id=sector);insert('resource_node_defs',node)
   location=rows('resource_node_locations','node_id=?',(old,))[0];location.update(node_id=new,sector_id=sector,anchor_id=mapping[location['anchor_id']]);insert('resource_node_locations',location)
   grade=rows('resource_grade_defs','node_id=?',(old,))[0];grade['node_id']=new;insert('resource_grade_defs',grade)
   resource.update(node_id=new,event_id=event);insert('exploration_resource_defs',resource)
  for obstacle in obstacles:
   obstacle.update(obstacle_id=event+'_'+obstacle['obstacle_id'],event_id=event,anchor_id=mapping[obstacle['anchor_id']]);insert('exploration_obstacle_defs',obstacle)
  tactical=rows('tactical_site_defs')[0];tactical.update(site_id='tac_'+event,sector_id=sector,display_name=title+' · 战术威胁',anchor_id=mapping[original['entry_anchor_id']])
  insert('tactical_site_defs',tactical)
  for actor in actors:
   if actor['actor_role']=='enemy':insert('npc_tactic_bindings',{'spawn_id':actor['spawn_id'],'site_id':tactical['site_id'],'tactic_id':['tac_support','tac_interceptor','tac_siege'][actor['slot_index']],'member_index':actor['slot_index']})
  insert('campaign_tactical_links',{'site_id':tactical['site_id'],'event_id':event})
  if kind=='mineral':
   template_site=rows('site_defs','site_id=?',(rows('anchor_site_defs','anchor_id=?',(original['entry_anchor_id'],))[0]['site_id'],))[0]
   for index in range(3):
    route_id=event+'_route_'+str(index)
    translation={a['anchor_id']:a['anchor_id'] if index==0 else route_id+'_'+a['anchor_id'] for a in authored}
    if index:
     old_route=rows('exploration_belt_route_defs','event_id=? AND route_index=?',(template,index))[0]
     old_site=rows('site_defs','site_id=?',(rows('anchor_site_defs','anchor_id=?',(old_route['entry_anchor_id'],))[0]['site_id'],))[0]
     alternate=dict(new_site);alternate['site_id']=route_id+'_site';alternate['display_name']=title+' · 迁移区'+str(index+1)
     for axis in ['x_m','y_m','z_m']:alternate[axis]+=old_site[axis]-template_site[axis]
     insert('site_defs',alternate)
     for base in authored:
      anchor=dict(base);anchor['anchor_id']=translation[base['anchor_id']]
      anchor['x_m']=-base['z_m'] if index==1 else -base['x_m'];anchor['z_m']=base['x_m'] if index==1 else -base['z_m']
      insert('anchor_defs',anchor);insert('anchor_site_defs',{'anchor_id':anchor['anchor_id'],'site_id':alternate['site_id']})
    insert('exploration_belt_route_defs',{'route_id':route_id,'event_id':event,'route_index':index,'display_name':['初始矿区','第二迁移区','第三迁移区'][index],'entry_anchor_id':translation[mapping[original['entry_anchor_id']]],'exit_anchor_id':translation[mapping[original['exit_anchor_id']]]})
    for base,actual in translation.items():insert('exploration_belt_anchor_defs',{'route_id':route_id,'base_anchor_id':base,'anchor_id':actual})

 (ROOT/'code/database/campaign_theme_seed.sql').write_text('\n'.join(sql)+'\n',encoding='utf-8',newline='\n');c.close()

if __name__=='__main__':main()
