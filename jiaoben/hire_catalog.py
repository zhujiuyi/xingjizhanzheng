"""Companion definition closure and explicit additive row permissions."""
TABLES=('hire_balance_defs','hire_profile_defs')
COLUMNS={
 'hire_balance_defs':'singleton:INTEGER:1|max_companions:INTEGER:0|formation_m:REAL:0|communication_m:REAL:0|warp_ready_m:REAL:0|retreat_distance_m:REAL:0|retreat_charge_s:REAL:0|return_s:REAL:0|warning_s:REAL:0|support_range_m:REAL:0|support_cycle_s:REAL:0|support_shield:REAL:0|support_armor:REAL:0',
 'hire_profile_defs':'profile_id:TEXT:1|display_name:TEXT:0|role_id:TEXT:0|hull_id:TEXT:0|spawn_id:TEXT:0|hire_fee_credit:INTEGER:0|deposit_credit:INTEGER:0|lease_s:REAL:0|support_cycles:INTEGER:0',
}
EXTENSIONS=('npc_archetype_defs','npc_resistances','npc_behavior_defs','npc_defs','npc_spawn_defs','npc_patrol_points','anchor_defs','anchor_site_defs')

def validate(db):
    if db.execute('SELECT count(*) FROM hire_balance_defs').fetchone()[0]!=1:raise ValueError('One companion balance definition required')
    profiles=db.execute('SELECT profile_id,role_id,hull_id,spawn_id,lease_s FROM hire_profile_defs').fetchall()
    if len(profiles)!=2 or {r[1] for r in profiles}!={'escort','support'}:raise ValueError('Both paid companion roles required')
    warning=db.execute('SELECT warning_s FROM hire_balance_defs').fetchone()[0]
    for id_,role,hull,spawn,lease in profiles:
        if not id_.startswith('hire_') or lease<=warning:raise ValueError('Invalid companion identity or warning interval')
        if db.execute('SELECT required_rank FROM civilization_hull_defs WHERE ship_id=?',(hull,)).fetchone():raise ValueError('Agency must not grant civilization-exclusive hull access')
        row=db.execute('SELECT occurrence_mode,bounty_enabled,loot_enabled FROM npc_spawn_defs WHERE spawn_id=?',(spawn,)).fetchone()
        if row!=('mission_scoped',0,0):raise ValueError('Companions must not create ordinary bounties or loot')
        if db.execute('SELECT count(*) FROM npc_patrol_points WHERE spawn_id=?',(spawn,)).fetchone()[0]!=1:raise ValueError('Companion needs a valid original spawn anchor')
