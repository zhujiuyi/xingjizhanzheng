"""Fixed specialization/analysis registry; no parallel balance configuration."""
COLUMNS={
 'fitting_analysis_defs':'singleton:INTEGER:1|burst_window_s:REAL:0|sustained_window_s:REAL:0|horizon_s:REAL:0|default_distance_m:REAL:0',
 'weapon_tuning_defs':'module_id:TEXT:1|specialization_kind:TEXT:0|damage_ratio:REAL:0|cycle_ratio:REAL:0|range_ratio:REAL:0|energy_ratio:REAL:0|heat_ratio:REAL:0|speed_ratio:REAL:0|cone_ratio:REAL:0',
 'specialization_balance_defs':'singleton:INTEGER:1|tactic_points:INTEGER:0|exploration_points:INTEGER:0|operation_points_per_unit:INTEGER:0|donation_item_id:TEXT:0|donation_units_per_point:INTEGER:0|donation_credit_per_point:INTEGER:0|max_donation_points:INTEGER:0',
 'specialization_research_defs':'research_id:TEXT:1|display_name:TEXT:0|module_id:TEXT:0|required_points:INTEGER:0|credit_per_point:INTEGER:0|required_unlock_id:TEXT:0|reward_unlock_id:TEXT:0',
 'ship_role_guidance_defs':'ship_id:TEXT:1|role_name:TEXT:0|strength_text:TEXT:0|tradeoff_text:TEXT:0|recommended_targets:TEXT:0',
}
TABLES=tuple(COLUMNS)
def validate(db):
 assert db.execute('SELECT count(*) FROM ship_role_guidance_defs').fetchone()==db.execute('SELECT count(*) FROM ship_defs').fetchone()
 assert {r[0] for r in db.execute('SELECT specialization_kind FROM weapon_tuning_defs')}=={'burst','sustain','range'}
 assert db.execute('SELECT count(*) FROM specialization_research_defs').fetchone()==(3,)
 for (module,) in db.execute('SELECT module_id FROM weapon_tuning_defs'):
  assert db.execute('SELECT max_per_ship,slot_type FROM module_defs WHERE module_id=?',(module,)).fetchone()==(1,'utility')
  assert db.execute('SELECT max_installed FROM module_exclusion_groups g JOIN module_group_members m USING(group_id) WHERE m.module_id=?',(module,)).fetchone()==(1,)
