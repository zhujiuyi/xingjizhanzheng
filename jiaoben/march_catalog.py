"""Closure checks for real gate itineraries and references to existing growth."""
TABLES = ('march_balance_defs', 'march_campaign_defs', 'march_route_defs',
          'growth_stage_defs', 'growth_activity_defs', 'growth_grant_defs')
COLUMNS = {
    'march_balance_defs': 'singleton:INTEGER:1|assembly_s:REAL:0|align_s:REAL:0|warp_speed_au_s:REAL:0|warp_min_s:REAL:0|warp_max_s:REAL:0|arrival_radius_m:REAL:0|clear_distance_m:REAL:0|formation_m:REAL:0|gate_exit_m:REAL:0|max_blocked_s:REAL:0|return_supply_ratio:REAL:0|gate_transit_s:REAL:0|history_limit:INTEGER:0|gate_approach_m:REAL:0|gate_stop_m:REAL:0',
    'march_campaign_defs': 'war_id:TEXT:1|origin_station_id:TEXT:0|destination_anchor_id:TEXT:0|supply_carrier_spawn_id:TEXT:0|travel_hull_id:TEXT:0',
    'march_route_defs': 'war_id:TEXT:1|leg_index:INTEGER:2|endpoint_id:TEXT:0|reverse_endpoint_id:TEXT:0',
    'growth_stage_defs': 'stage_id:TEXT:1|faction_id:TEXT:0|sort_order:INTEGER:0|display_name:TEXT:0|criterion_kind:TEXT:0|reference_id:TEXT:0|target_count:INTEGER:0|station_id:TEXT:0|outcome_label:TEXT:0',
    'growth_activity_defs': 'stage_id:TEXT:1|activity_index:INTEGER:2|activity_kind:TEXT:0|reference_id:TEXT:0|station_id:TEXT:0',
    'growth_grant_defs': 'task_id:TEXT:1|reward_credit:INTEGER:0|reward_reputation:INTEGER:0|display_name:TEXT:0',
}


def validate(db):
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    require(db.execute('SELECT count(*) FROM march_balance_defs').fetchone()[0] == 1,
            'A single authoritative march balance is required')
    approach, stop = db.execute('SELECT gate_approach_m,gate_stop_m FROM march_balance_defs').fetchone()
    radius = db.execute("SELECT value_real FROM rule_parameters WHERE parameter_id='gate_entry_radius_m'").fetchone()[0]
    require(approach + stop < radius, 'Sequential gate goal must fit the real entry radius')
    wars = {r[0] for r in db.execute('SELECT war_id FROM civilization_war_defs')}
    require({r[0] for r in db.execute('SELECT war_id FROM march_campaign_defs')} == wars,
            'Every civilization campaign needs a real route')
    for war, origin, destination, carrier, hull in db.execute('SELECT * FROM march_campaign_defs'):
        faction, target = db.execute('SELECT faction_id,target_sector_id FROM civilization_war_defs WHERE war_id=?', (war,)).fetchone()
        capital = db.execute('SELECT capital_station_id FROM civilization_defs WHERE faction_id=?', (faction,)).fetchone()[0]
        require(origin == capital, 'War fleet must originate at its actual civilization capital')
        require(db.execute('SELECT sector_id FROM anchor_defs WHERE anchor_id=?', (destination,)).fetchone()[0] == target,
                'March destination must be the war sector')
        require(db.execute("SELECT count(*) FROM civilization_war_members WHERE war_id=? AND spawn_id=? AND side='ally'", (war, carrier)).fetchone()[0] == 1,
                'Supplies must bind to a real original allied member')
        require(db.execute('SELECT count(*) FROM civilization_hull_defs WHERE faction_id=? AND ship_id=? AND required_rank=2', (faction, hull)).fetchone()[0] == 1,
                'Travel mass and shape must match the existing allied hull')
        sector = db.execute('SELECT sector_id FROM station_defs WHERE station_id=?', (origin,)).fetchone()[0]
        dry_mass, cargo_l = db.execute('SELECT dry_mass_kg,cargo_l FROM ship_defs WHERE ship_id=?', (hull,)).fetchone()
        item, units = db.execute('SELECT material_id,supply_units FROM frontier_balance_defs').fetchone()
        unit_mass, unit_volume = db.execute('SELECT unit_mass_kg,unit_volume_l FROM item_defs WHERE item_id=?', (item,)).fetchone()
        fleet_count = db.execute("SELECT count(*) FROM civilization_war_members WHERE war_id=? AND side='ally'", (war,)).fetchone()[0]
        largest_mass, party_mass = dry_mass + units * unit_mass, dry_mass * fleet_count + units * unit_mass
        require(units * unit_volume <= cargo_l, 'Original supply carrier lacks cargo capacity')
        route = db.execute('SELECT leg_index,endpoint_id,reverse_endpoint_id FROM march_route_defs WHERE war_id=? ORDER BY leg_index', (war,)).fetchall()
        require(route and [r[0] for r in route] == list(range(len(route))), 'March legs must be continuous')
        for _, endpoint, reverse in route:
            connection, start, end = db.execute('SELECT connection_id,origin_sector_id,target_sector_id FROM gate_endpoint_defs WHERE endpoint_id=?', (endpoint,)).fetchone()
            back = db.execute('SELECT connection_id,origin_sector_id,target_sector_id FROM gate_endpoint_defs WHERE endpoint_id=?', (reverse,)).fetchone()
            require(start == sector and tuple(back) == (connection, end, start), 'March or retreat would skip a gate')
            cap, total = db.execute('SELECT max_gross_mass_kg,total_mass_budget_kg FROM effective_connection_defs WHERE connection_id=?', (connection,)).fetchone()
            require(largest_mass <= cap and (total is None or party_mass <= total), 'Authored fleet cannot fit through its gate')
            sector = end
        require(sector == target, 'March must reach its declared war sector')
    references = {
        'mission': ('mission_defs', 'mission_id'), 'donation': ('civilization_donation_defs', 'donation_id'),
        'honor': ('civilization_honor_task_defs', 'task_id'), 'war': ('civilization_war_defs', 'war_id'),
        'expedition': ('expedition_route_defs', 'route_id'), 'project': ('construction_project_defs', 'project_id'),
        'research': ('research_defs', 'research_id'),
        'honor_register': ('civilization_command_defs', 'faction_id'), 'hull_recipe': ('hull_recipe_defs', 'hull_recipe_id'),
    }
    criteria = dict(references, membership=('civilization_defs', 'faction_id'),
                    rank=('civilization_defs', 'faction_id'), honors=('civilization_defs', 'faction_id'),
                    registration=('civilization_command_defs', 'faction_id'),
                    owned_hull=('ship_defs', 'ship_id'))
    for kind, reference in db.execute('SELECT criterion_kind,reference_id FROM growth_stage_defs'):
        table, key = criteria[kind]
        require(db.execute(f'SELECT count(*) FROM {table} WHERE {key}=?', (reference,)).fetchone()[0] == 1,
                'Growth guidance must reference a real result')
    for kind, reference in db.execute('SELECT activity_kind,reference_id FROM growth_activity_defs'):
        table, key = references[kind]
        require(db.execute(f'SELECT count(*) FROM {table} WHERE {key}=?', (reference,)).fetchone()[0] == 1,
                'Growth guidance must reference a playable activity')
    for faction, in db.execute('SELECT faction_id FROM civilization_defs'):
        require(db.execute('SELECT count(*) FROM growth_stage_defs WHERE faction_id=?', (faction,)).fetchone()[0] >= 13,
                'All civilizations need a path through middle and late progression')
    require({r[0] for r in db.execute('SELECT task_id FROM growth_grant_defs')} ==
            {r[0] for r in db.execute('SELECT task_id FROM civilization_honor_task_defs')},
            'Every actual capability proof needs an explicit finite outfitting grant')
