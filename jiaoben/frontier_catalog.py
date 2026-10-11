"""Authored frontier closure and additive-row permissions, never a balance copy."""
TABLES=('frontier_balance_defs','frontier_campaign_defs','frontier_actor_defs','frontier_governance_defs','frontier_beacon_defs')
COLUMNS={
 'frontier_balance_defs':'singleton:INTEGER:1|material_id:TEXT:0|supply_units:INTEGER:0|rebuild_units:INTEGER:0|survey_s:REAL:0|survey_energy_eu:REAL:0|survey_heat_hu:REAL:0|survey_radius_m:REAL:0|escort_radius_m:REAL:0|arrival_radius_m:REAL:0|hold_s:REAL:0|rebuild_s:REAL:0|repair_radius_m:REAL:0|warning_s:REAL:0|defense_s:REAL:0|crisis_min_s:REAL:0|crisis_max_s:REAL:0|reserve_max_units:INTEGER:0|crisis_supply_base_units:INTEGER:0|crisis_supply_per_extra_territory:INTEGER:0|dispatch_s:REAL:0|dispatch_fee_credit:INTEGER:0|max_supply_orders:INTEGER:0|repair_fee_ratio:REAL:0|industry_fee_ratio:REAL:0|recapture_credit:INTEGER:0|recapture_reputation:INTEGER:0|defense_credit:INTEGER:0|defense_reputation:INTEGER:0|hostile_detection_ratio:REAL:0|restock_rate:REAL:0',
 'frontier_campaign_defs':'war_id:TEXT:1|scout_anchor_id:TEXT:0|convoy_start_anchor_id:TEXT:0|convoy_exit_anchor_id:TEXT:0|battle_kind:TEXT:0|convoy_spawn_id:TEXT:0|structure_count:INTEGER:0',
 'frontier_actor_defs':'spawn_id:TEXT:1|war_id:TEXT:0|sector_id:TEXT:0|actor_role:TEXT:0|slot_index:INTEGER:0|hull_id:TEXT:0',
 'frontier_governance_defs':'sector_id:TEXT:1|station_id:TEXT:0|defense_anchor_id:TEXT:0|beacon_spawn_id:TEXT:0',
 'frontier_beacon_defs':'spawn_id:TEXT:1|sector_id:TEXT:0|hull_id:TEXT:0',
}
EXTENSIONS={
 'anchor_defs':('anchor_id',),'anchor_site_defs':('anchor_id',),'npc_defs':('npc_id',),'npc_spawn_defs':('spawn_id',),'npc_patrol_points':('spawn_id',),
}

def validate(db):
    policies={r[0] for r in db.execute('SELECT sector_id FROM sector_sovereignty_defs WHERE conquerable=1')}
    if len(policies)!=8:raise ValueError('Authored frontier must preserve the eight neutral targets')
    if {r[0] for r in db.execute('SELECT sector_id FROM frontier_governance_defs')}!=policies:raise ValueError('Governance must cover exactly the conquerable frontier')
    wars={r[0] for r in db.execute('SELECT war_id FROM civilization_war_defs')}
    if {r[0] for r in db.execute('SELECT war_id FROM frontier_campaign_defs')}!=wars:raise ValueError('Every civilization war needs a real staged objective')
    if db.execute('SELECT count(*) FROM frontier_balance_defs').fetchone()[0]!=1:raise ValueError('Missing frontier balance')
    for war,scout,start,exit_,kind,convoy,count in db.execute('SELECT * FROM frontier_campaign_defs'):
        sector,capture=db.execute('SELECT target_sector_id,capture_anchor_id FROM civilization_war_defs WHERE war_id=?',(war,)).fetchone()
        site=db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?',(capture,)).fetchone()
        for anchor in (scout,start,exit_):
            if db.execute('SELECT sector_id FROM anchor_defs WHERE anchor_id=?',(anchor,)).fetchone()!=(sector,) or db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?',(anchor,)).fetchone()!=site:raise ValueError('Frontier operations must share their real local battlefield')
        actors=db.execute('SELECT actor_role,count(*) FROM frontier_actor_defs WHERE war_id=? GROUP BY actor_role',(war,)).fetchall()
        if dict(actors)!={'convoy':1,'ambusher':2,**({'structure':2} if kind=='demolition' else {})}:raise ValueError('Frontier actor coverage does not match its objective')
        if db.execute('SELECT count(*) FROM frontier_actor_defs WHERE war_id=? AND actor_role=? AND spawn_id=?',(war,'convoy',convoy)).fetchone()[0]!=1:raise ValueError('Convoy must be an authored real actor')
    for sector in policies:
        if db.execute("SELECT count(*) FROM frontier_actor_defs WHERE sector_id=? AND actor_role='raider'",(sector,)).fetchone()[0]!=3:raise ValueError('Every frontier defense needs three authored raiders')
        if db.execute('SELECT count(*) FROM frontier_beacon_defs WHERE sector_id=?',(sector,)).fetchone()[0]!=1:raise ValueError('Every frontier defense needs a real beacon')
    for spawn,sector in db.execute('SELECT spawn_id,sector_id FROM frontier_actor_defs UNION ALL SELECT spawn_id,sector_id FROM frontier_beacon_defs'):
        row=db.execute('SELECT sector_id,bounty_enabled,loot_enabled,occurrence_mode FROM npc_spawn_defs WHERE spawn_id=?',(spawn,)).fetchone()
        if row!=(sector,0,0,'mission_scoped'):raise ValueError('Frontier actors cannot create free ordinary bounties or loot')
