"""Fixed doctrine and drone-restoration registry with actual module/encounter consumers."""
COLUMNS={
 'tactical_balance_defs':'singleton:INTEGER:1|jam_max_duration_s:REAL:0|jam_immunity_s:REAL:0|jam_repeat_window_s:REAL:0|jam_repeat_multiplier:REAL:0|jam_max_repeat:INTEGER:0|min_thrust_ratio:REAL:0|drone_radius_m:REAL:0',
 'npc_tactic_defs':'tactic_id:TEXT:1|tactic_kind:TEXT:0|display_name:TEXT:0|model_ship_id:TEXT:0|charge_s:REAL:0|duration_s:REAL:0|cooldown_s:REAL:0|range_m:REAL:0|strength:REAL:0|interrupt_hp:REAL:0|energy_max:REAL:0|recharge_eu_s:REAL:0|energy_cost:REAL:0|projectile_speed_mps:REAL:0|drone_module_id:TEXT:0|drone_reserve:INTEGER:0',
 'tactical_site_defs':'site_id:TEXT:1|sector_id:TEXT:0|display_name:TEXT:0|anchor_id:TEXT:0|required_unlock_id:TEXT:0|respawn_s:REAL:0|warp_arrival_m:REAL:0|reveal_range_m:REAL:0',
 'npc_tactic_bindings':'spawn_id:TEXT:1|tactic_id:TEXT:0|site_id:TEXT:0|member_index:INTEGER:0',
 'drone_management_defs':'module_id:TEXT:1|hull_hp:REAL:0|material_id:TEXT:0|material_per_unit:INTEGER:0|credit_per_unit:INTEGER:0',
}
TABLES=tuple(COLUMNS)
def validate(db):
    if {r[0] for r in db.execute('SELECT tactic_kind FROM npc_tactic_defs')}!={'support','interceptor','siege','carrier'}:raise ValueError('Four actual tactical kinds required')
    if db.execute('SELECT count(*) FROM npc_tactic_bindings').fetchone()[0]!=9:raise ValueError('Three complete mixed tactical encounters required')
    if db.execute('SELECT count(*) FROM drone_management_defs').fetchone()!=db.execute('SELECT count(*) FROM drone_defs').fetchone():raise ValueError('Every bay needs real health and replacement costs')
    if db.execute("SELECT count(*) FROM tactical_site_defs").fetchone()[0]!=3:raise ValueError('Three independently navigable tactical sites required')
    for (site,) in db.execute('SELECT site_id FROM tactical_site_defs'):
        if [r[0] for r in db.execute('SELECT member_index FROM npc_tactic_bindings WHERE site_id=? ORDER BY member_index',(site,))]!=[0,1,2]:raise ValueError('Tactical site membership must be complete')
    if db.execute("SELECT count(*) FROM npc_tactic_defs n JOIN tactical_balance_defs b WHERE n.tactic_kind='interceptor' AND n.duration_s>b.jam_max_duration_s").fetchone()[0]:raise ValueError('Jam duration exceeds minimum-control policy')
