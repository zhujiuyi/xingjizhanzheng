"""Campaign definition closure and strict additive namespaces."""
TABLES=('campaign_balance_defs','construction_project_defs','construction_stage_defs','construction_input_defs','expedition_route_defs','expedition_option_defs','campaign_event_defs','campaign_tactical_links')
COLUMNS={
 'campaign_balance_defs':'singleton:INTEGER:1|director_period_s:REAL:0|focus_bonus_bp:INTEGER:0|partial_bonus_bp:INTEGER:0|report_limit:INTEGER:0',
 'construction_project_defs':'project_id:TEXT:1|display_name:TEXT:0|sector_id:TEXT:0|station_id:TEXT:0|required_unlock_id:TEXT:0|required_evidence_units:INTEGER:0|description:TEXT:0',
 'construction_stage_defs':'project_id:TEXT:1|stage_index:INTEGER:2|display_name:TEXT:0|work_s:REAL:0|fee_credit:INTEGER:0|effect_kind:TEXT:0|multiplier_bp:INTEGER:0',
 'construction_input_defs':'project_id:TEXT:1|stage_index:INTEGER:2|item_id:TEXT:3|delivery_station_id:TEXT:4|required_units:INTEGER:0',
 'expedition_route_defs':'route_id:TEXT:1|display_name:TEXT:0|origin_station_id:TEXT:0|required_unlock_id:TEXT:0|start_fee_credit:INTEGER:0|cooldown_s:REAL:0|focus_index:INTEGER:0|description:TEXT:0',
 'expedition_option_defs':'route_id:TEXT:1|stage_index:INTEGER:2|option_id:TEXT:3|event_id:TEXT:0|bonus_credit:INTEGER:0|bonus_insight:INTEGER:0',
 'campaign_event_defs':'event_id:TEXT:1|project_id:TEXT:0|full_units:INTEGER:0|partial_units:INTEGER:0',
 'campaign_tactical_links':'site_id:TEXT:1|event_id:TEXT:0',
}
EXTENSIONS=('site_defs','exploration_belt_route_defs','exploration_belt_anchor_defs','anchor_defs','anchor_site_defs','npc_defs','npc_spawn_defs','npc_patrol_points','exploration_event_defs','exploration_variant_defs','exploration_actor_defs','exploration_resource_defs','exploration_obstacle_defs','resource_node_defs','resource_node_locations','resource_grade_defs','tactical_site_defs','npc_tactic_bindings')

def validate(db):
 if db.execute('SELECT count(*) FROM campaign_balance_defs').fetchone()[0]!=1:raise ValueError('One offline campaign policy required')
 if db.execute('SELECT count(*) FROM construction_project_defs').fetchone()[0]!=3:raise ValueError('Three actual frontier construction projects required')
 for project,sector,station in db.execute('SELECT project_id,sector_id,station_id FROM construction_project_defs'):
  if db.execute('SELECT sector_id FROM station_defs WHERE station_id=?',(station,)).fetchone()!=(sector,):raise ValueError('Construction station/sector mismatch')
  if [r[0] for r in db.execute('SELECT stage_index FROM construction_stage_defs WHERE project_id=? ORDER BY stage_index',(project,))]!=[1,2,3]:raise ValueError('Construction needs three finite stages')
  if db.execute('SELECT count(DISTINCT delivery_station_id) FROM construction_input_defs WHERE project_id=?',(project,)).fetchone()[0]<3:raise ValueError('Project must consume actual inputs at three stations')
  if db.execute('SELECT count(*) FROM campaign_event_defs WHERE project_id=?',(project,)).fetchone()[0]!=2:raise ValueError('Each project needs two independent exploration contributions')
 for route, in db.execute('SELECT route_id FROM expedition_route_defs'):
  for stage in (1,2,3):
   if db.execute('SELECT count(*) FROM expedition_option_defs WHERE route_id=? AND stage_index=?',(route,stage)).fetchone()[0]!=2:raise ValueError('Every expedition stage needs two actual choices')
 linked=db.execute('SELECT e.sector_id,a.site_id FROM campaign_event_defs b JOIN exploration_event_defs e USING(event_id) JOIN anchor_site_defs a ON a.anchor_id=e.entry_anchor_id').fetchall()
 if len(linked)!=6 or len(set(linked))!=6 or len({s for s,_ in linked})!=3:raise ValueError('Theme must have six distinct places within three existing systems')
 if db.execute('SELECT count(*) FROM campaign_tactical_links').fetchone()[0]!=6:raise ValueError('Each theme encounter needs a guarded tactical lifecycle')
