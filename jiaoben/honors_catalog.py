"""Stable examination definitions and their actual gameplay source closure."""
TABLES=('civilization_command_defs','civilization_honor_task_defs','civilization_honor_source_defs')
COLUMNS={
 'civilization_command_defs':'faction_id:TEXT:1|display_name:TEXT:0|registration_rank:INTEGER:0|command_rank:INTEGER:0|required_unlock_id:TEXT:0|reward_credit:INTEGER:0|reward_reputation:INTEGER:0',
 'civilization_honor_task_defs':'task_id:TEXT:1|faction_id:TEXT:0|task_kind:TEXT:0|display_name:TEXT:0|required_units:INTEGER:0',
 'civilization_honor_source_defs':'task_id:TEXT:1|source_index:INTEGER:2|event_id:TEXT:0|contract_id:TEXT:0|operation_id:TEXT:0',
}

def validate(db):
    civs={r[0] for r in db.execute('SELECT faction_id FROM civilization_defs')}
    if {r[0] for r in db.execute('SELECT faction_id FROM civilization_command_defs')}!=civs:raise ValueError('Commander examination must cover all civilizations')
    for faction in civs:
        tasks=db.execute('SELECT task_id,task_kind,required_units FROM civilization_honor_task_defs WHERE faction_id=?',(faction,)).fetchall()
        if {r[1] for r in tasks}!={'scout','logistics','rescue','combat'}:raise ValueError('Four distinct ability categories are required')
        for id_,kind,units in tasks:
            sources=db.execute('SELECT event_id,contract_id,operation_id FROM civilization_honor_source_defs WHERE task_id=?',(id_,)).fetchall()
            if not sources:raise ValueError('Examination task has no real source')
            for event,freight,operation in sources:
                if kind in ('scout','rescue'):
                    expected='relic' if kind=='scout' else 'rescue'
                    if db.execute('SELECT event_kind FROM exploration_event_defs WHERE event_id=?',(event,)).fetchone()!=(expected,) or units!=1:raise ValueError('Exploration proof must match a full real outcome')
                elif kind=='logistics':
                    row=db.execute('SELECT max_units FROM consignment_defs WHERE contract_id=?',(freight,)).fetchone()
                    if row is None or row[0]<units:raise ValueError('Freight proof exceeds a real haul')
                else:
                    if db.execute('SELECT operation_kind,target_units FROM operation_defs WHERE operation_id=?',(operation,)).fetchone()!=('demolition',units):raise ValueError('Combat examination requires a complete real demolition')
    for faction,rank in db.execute('SELECT faction_id,command_rank FROM civilization_command_defs'):
        if db.execute('SELECT count(*) FROM civilization_war_defs WHERE faction_id=? AND required_rank<>?',(faction,rank)).fetchone()[0]:raise ValueError('Commander rank diverges from existing war permissions')
