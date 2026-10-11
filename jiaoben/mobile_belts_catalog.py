"""Reviewed route closure, same-sector geometry and strictly decreasing mineral caps."""
COLUMNS = {
 'exploration_belt_route_defs':'route_id:TEXT:1|event_id:TEXT:0|route_index:INTEGER:0|display_name:TEXT:0|entry_anchor_id:TEXT:0|exit_anchor_id:TEXT:0',
 'exploration_belt_anchor_defs':'route_id:TEXT:1|base_anchor_id:TEXT:2|anchor_id:TEXT:0',
 'exploration_belt_stage_defs':'stage_index:INTEGER:1|threshold_bp:INTEGER:0|remaining_cap_bp:INTEGER:0|warning_lead_s:REAL:0|display_name:TEXT:0',
}
TABLES = tuple(COLUMNS)


def validate(db):
    minerals = [r[0] for r in db.execute("SELECT event_id FROM exploration_event_defs WHERE event_kind='mineral'")]
    for event in minerals:
        routes = db.execute('SELECT route_id,route_index,entry_anchor_id,exit_anchor_id FROM exploration_belt_route_defs WHERE event_id=? ORDER BY route_index',(event,)).fetchall()
        if [r[1] for r in routes] != [0,1,2]: raise ValueError('Every mineral event requires three real routes')
        site_ids = set()
        for route,index,entry,exit_ in routes:
            sites = db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id IN (?,?)',(entry,exit_)).fetchall()
            if len(sites)!=2 or sites[0]!=sites[1]: raise ValueError('Mineral route exit and entry must share local space')
            site_ids.add(sites[0][0])
            maps = db.execute('SELECT base_anchor_id,anchor_id FROM exploration_belt_anchor_defs WHERE route_id=?',(route,)).fetchall()
            for base,actual in maps:
                if index==0 and base!=actual: raise ValueError('Original route must preserve every existing anchor')
                if db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?',(actual,)).fetchone()!=sites[0]: raise ValueError('Route actor/resource/cover escaped its own space')
            original = db.execute('SELECT entry_anchor_id FROM exploration_event_defs WHERE event_id=?',(event,)).fetchone()[0]
            oldsite = db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?',(original,)).fetchone()[0]
            expected = {r[0] for r in db.execute('SELECT anchor_id FROM anchor_site_defs WHERE site_id=?',(oldsite,))}
            if {r[0] for r in maps}!=expected: raise ValueError('Mineral route mapping omits actors, resource or cover')
        if len(site_ids)!=3: raise ValueError('Migration must change the actual AU site')
    stages = db.execute('SELECT stage_index,threshold_bp,remaining_cap_bp FROM exploration_belt_stage_defs ORDER BY stage_index').fetchall()
    if len(stages)!=3 or [r[0] for r in stages]!=[1,2,3] or not all(a[1]<b[1] and a[2]>b[2] for a,b in zip(stages,stages[1:])): raise ValueError('Mineral decay thresholds/caps must be monotonic')
