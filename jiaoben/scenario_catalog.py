"""Definition closure. Column registration derives from the official SQL DDL."""
from pathlib import Path
import sqlite3

ROOT=Path(__file__).resolve().parents[1]
TABLES=('tactical_award_defs','trial_defs','trial_hull_defs','trial_actor_defs','blockade_defs','blockade_node_defs','blockade_actor_defs','telemetry_policy_defs')
EXTENSIONS=('site_defs','anchor_defs','anchor_site_defs','npc_defs','npc_spawn_defs','npc_patrol_points')

with sqlite3.connect(':memory:') as _schema:
 _schema.executescript((ROOT/'code/database/scenario_schema.sql').read_text(encoding='utf-8'))
 COLUMNS={t:'|'.join(f'{r[1]}:{r[2]}:{r[5]}' for r in _schema.execute('PRAGMA table_info('+t+')')) for t in TABLES}

def validate(db):
 def require(ok,message):
  if not ok:raise ValueError(message)
 require(db.execute('SELECT count(*) FROM trial_defs').fetchone()[0]==3,'Three distinct budget challenges required')
 require(db.execute('SELECT count(DISTINCT objective_kind) FROM trial_defs').fetchone()[0]==3,'Challenge objectives must differ')
 require(db.execute('SELECT count(*) FROM blockade_defs').fetchone()[0]==3,'Three corridor scenarios required')
 require(db.execute('SELECT count(*) FROM telemetry_policy_defs').fetchone()[0]==1,'One local measurement policy required')
 require(db.execute('SELECT count(*) FROM tactical_award_defs').fetchone()[0]==6,'Every distinct challenge/corridor needs one horizontal award')
 require(db.execute("SELECT count(*) FROM npc_spawn_defs p JOIN npc_defs n USING(npc_id) JOIN sector_defs s USING(sector_id) JOIN risk_zone_defs z ON z.risk_zone_id=s.risk_zone_id WHERE (p.spawn_id LIKE 'trial_%' OR p.spawn_id LIKE 'blockade_%') AND (n.level<z.npc_level_min OR n.level>z.npc_level_max OR n.risk_zone_id<>s.risk_zone_id)").fetchone()[0]==0,'Scenario actor levels must respect their actual regional ranges')
 for key,station,entry,exit in db.execute('SELECT trial_id,station_id,entry_anchor_id,exit_anchor_id FROM trial_defs UNION ALL SELECT blockade_id,station_id,entry_anchor_id,exit_anchor_id FROM blockade_defs'):
  require(db.execute('SELECT count(*) FROM anchor_site_defs WHERE anchor_id IN (?,?) AND site_id=?',(entry,exit,key+'_site')).fetchone()[0]==2,'Scenario entry/exit must share its actual local space')
  require(db.execute('SELECT s.sector_id=p.sector_id FROM station_defs s JOIN site_defs p ON p.site_id=? WHERE s.station_id=?',(key+'_site',station)).fetchone()==(1,),'Signing station must belong to the corridor system')
 for trial, in db.execute('SELECT trial_id FROM trial_defs'):
  require(db.execute('SELECT count(*) FROM trial_hull_defs WHERE trial_id=?',(trial,)).fetchone()[0]>0,'Challenge needs an explicit hull permission list')
  require(db.execute('SELECT count(*) FROM trial_hull_defs a JOIN ship_defs s USING(ship_id) JOIN trial_defs t USING(trial_id) WHERE a.trial_id=? AND s.base_ask_credit>t.budget_credit',(trial,)).fetchone()[0]==0,'Allowed bare hull already exceeds challenge budget')
 for key,quota in db.execute('SELECT blockade_id,survey_count FROM blockade_defs'):
  require(db.execute("SELECT count(*) FROM blockade_node_defs WHERE blockade_id=? AND node_kind='survey'",(key,)).fetchone()[0]==quota,'Survey quota must match actual independent nodes')
  require(db.execute("SELECT count(*) FROM blockade_actor_defs WHERE blockade_id=? AND actor_role='relay'",(key,)).fetchone()[0]==2,'Each blockade needs two destructible relay nodes')
  entry,exit=db.execute('SELECT entry_anchor_id,exit_anchor_id FROM blockade_defs WHERE blockade_id=?',(key,)).fetchone()
  start=db.execute('SELECT x_m,y_m,z_m FROM anchor_defs WHERE anchor_id=?',(entry,)).fetchone()
  end=db.execute('SELECT x_m,y_m,z_m FROM anchor_defs WHERE anchor_id=?',(exit,)).fetchone()
  direction=[b-a for a,b in zip(start,end)];length2=sum(v*v for v in direction)
  require(length2>0,'Corridor endpoints must differ')
  for point in db.execute("SELECT a.x_m,a.y_m,a.z_m FROM blockade_node_defs n JOIN anchor_defs a USING(anchor_id) WHERE n.blockade_id=? AND n.node_kind='survey'",(key,)):
   along=sum((p-a)*v for p,a,v in zip(point,start,direction))/length2
   require(0<=along<0.5,'Survey clues must be reachable on the entrance side before crossing the blockade')
 require(db.execute('SELECT count(*) FROM npc_spawn_defs WHERE (spawn_id LIKE ? OR spawn_id LIKE ?) AND (bounty_enabled!=0 OR loot_enabled!=0)',('trial_%','blockade_%')).fetchone()[0]==0,'Scenario actors may not create bounty/loot farms')
