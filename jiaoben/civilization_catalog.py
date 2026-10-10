"""Reviewed schema registry and semantic checks for civilization content."""
from collections import Counter, defaultdict, deque

COLUMNS = {
    'civilization_defs': 'faction_id:TEXT:1|capital_sector_id:TEXT:0|capital_station_id:TEXT:0|doctrine:TEXT:0|color_hex:TEXT:0',
    'civilization_rank_defs': 'faction_id:TEXT:1|rank_level:INTEGER:2|display_name:TEXT:0|required_reputation:INTEGER:0',
    'sector_sovereignty_defs': 'sector_id:TEXT:1|initial_faction_id:TEXT:0|conquerable:INTEGER:0|chart_x:REAL:0|chart_y:REAL:0',
    'civilization_join_missions': 'faction_id:TEXT:1|step_index:INTEGER:2|mission_id:TEXT:0',
    'civilization_hull_defs': 'ship_id:TEXT:1|faction_id:TEXT:0|required_rank:INTEGER:0|required_unlock_id:TEXT:0|base_ship_id:TEXT:0|description:TEXT:0',
    'civilization_technology_defs': 'research_id:TEXT:1|faction_id:TEXT:0|required_rank:INTEGER:0',
    'civilization_donation_defs': 'donation_id:TEXT:1|faction_id:TEXT:0|item_id:TEXT:0|units_per_batch:INTEGER:0|reputation_per_batch:INTEGER:0',
    'civilization_war_defs': 'war_id:TEXT:1|faction_id:TEXT:0|target_sector_id:TEXT:0|capture_anchor_id:TEXT:0|required_rank:INTEGER:0|capture_duration_s:REAL:0|capture_radius_m:REAL:0|reward_credit:INTEGER:0|reward_reputation:INTEGER:0',
    'civilization_war_members': 'war_id:TEXT:1|spawn_id:TEXT:0|side:TEXT:2|formation_index:INTEGER:3',
}
TABLES = tuple(COLUMNS)


def validate(connection):
    def rows(table):
        cur = connection.execute('SELECT * FROM ' + table)
        names = [entry[0] for entry in cur.description]
        return [dict(zip(names, row, strict=True)) for row in cur]

    def require(condition, message):
        if not condition:
            raise ValueError(message)

    sectors = {row['sector_id'] for row in rows('sector_defs')}
    civs = {row['faction_id']: row for row in rows('civilization_defs')}
    policies = {row['sector_id']: row for row in rows('sector_sovereignty_defs')}
    stations = {row['station_id']: row for row in rows('station_defs')}
    require(len(sectors) >= 51 and len(civs) >= 3, 'Civilization expansion needs >50 systems and >=3 civilizations')
    require(set(policies) == sectors, 'Every sector needs one sovereignty policy')
    owned = Counter(row['initial_faction_id'] for row in policies.values())
    require(all(owned[id_] >= 10 for id_ in civs), 'Every civilization needs at least ten systems')
    require(owned[None] >= 10 and policies['sector_anchor']['initial_faction_id'] is None, 'Neutral starter region is missing')
    edges = defaultdict(set)
    for row in rows('connection_defs'):
        edges[row['origin_sector_id']].add(row['target_sector_id'])
        if row['bidirectional']:
            edges[row['target_sector_id']].add(row['origin_sector_id'])
    seen, todo = {'sector_anchor'}, deque(['sector_anchor'])
    while todo:
        for neighbor in edges[todo.popleft()] - seen:
            seen.add(neighbor)
            todo.append(neighbor)
    require(seen == sectors, 'Expanded galaxy has unreachable sectors')
    require(all(policies[id_]['initial_faction_id'] is None and not policies[id_]['conquerable']
                for id_ in edges['sector_anchor'] | {'sector_anchor'}), 'Starter and immediate neighbors must remain protected neutral systems')
    for faction, civ in civs.items():
        require(stations[civ['capital_station_id']]['sector_id'] == civ['capital_sector_id'] and
                policies[civ['capital_sector_id']]['initial_faction_id'] == faction, 'Capital station/ownership mismatch')
        ranks = sorted((row for row in rows('civilization_rank_defs') if row['faction_id'] == faction), key=lambda row: row['rank_level'])
        require([r['rank_level'] for r in ranks] == list(range(8)) and ranks[0]['required_reputation'] == 0 and
                all(a['required_reputation'] < b['required_reputation'] for a, b in zip(ranks, ranks[1:])), 'Invalid reputation/title ladder')
        admission = sorted((row for row in rows('civilization_join_missions') if row['faction_id'] == faction), key=lambda row: row['step_index'])
        require([r['step_index'] for r in admission] == [1, 2, 3], 'Each civilization needs a three-step admission chain')
        missions = {row['mission_id']: row for row in rows('mission_defs')}
        for row in admission:
            mission = missions[row['mission_id']]
            require(mission['accept_station_id'] == civ['capital_station_id'] == mission['turnin_station_id'] and not mission['repeatable'], 'Admission must be one-time at the capital')
        hulls = [row for row in rows('civilization_hull_defs') if row['faction_id'] == faction]
        require(len(hulls) >= 3 and {r['required_rank'] for r in hulls} == {2, 4, 6}, 'Exclusive hull ladder incomplete')
        require(any(row['faction_id'] == faction for row in rows('civilization_donation_defs')), 'Civilization has no donation path')
    anchor_sites = {row['anchor_id']: row['site_id'] for row in rows('anchor_site_defs')}
    profiles = rows('weapon_behavior_defs')
    for permission in rows('ship_weapon_permissions'):
        require(any(profile['family_id'] == permission['family_id'] and profile['size_class'] <= permission['max_size'] for profile in profiles),
                'Hull permission has no compatible real weapon: ' + permission['ship_id'] + '/' + permission['family_id'])
    spawns = {row['spawn_id']: row for row in rows('npc_spawn_defs')}
    for war in rows('civilization_war_defs'):
        policy = policies[war['target_sector_id']]
        require(policy['initial_faction_id'] is None and policy['conquerable'] == 1, 'War targets a protected or sovereign system')
        members = [r for r in rows('civilization_war_members') if r['war_id'] == war['war_id']]
        require(Counter(row['side'] for row in members) == {'ally': 3, 'defender': 4}, 'War fleet lacks its actual combat participants')
        for row in members:
            spawn = spawns[row['spawn_id']]
            require(spawn['sector_id'] == war['target_sector_id'] and spawn['occurrence_mode'] == 'mission_scoped' and
                    not spawn['bounty_enabled'] and not spawn['loot_enabled'] and
                    anchor_sites[spawn['anchor_id']] == anchor_sites[war['capture_anchor_id']], 'War participant lifecycle/spatial/reward mismatch')
