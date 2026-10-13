"""Author gate itineraries and growth references from the frozen v0.31 catalog.

The emitted SQL is authoritative. It references existing rewards and requirements
instead of maintaining a second numeric economy inside guidance code.
"""
from collections import deque
from pathlib import Path
import hashlib
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
FLEET_SHA256 = 'd05d4868ddd38a496bf6a54bcb59995dce3f9c449db35d3c714bdffb52690e30'


def literal(value):
    if value is None:
        return 'NULL'
    return "'" + value.replace("'", "''") + "'" if isinstance(value, str) else str(value)


def itinerary(endpoints, origin, target):
    queue = deque([(origin, [])])
    visited = {origin}
    while queue:
        sector, path = queue.popleft()
        if sector == target:
            return path
        for endpoint in endpoints:
            if endpoint['origin_sector_id'] == sector and endpoint['target_sector_id'] not in visited:
                visited.add(endpoint['target_sector_id'])
                queue.append((endpoint['target_sector_id'], path + [endpoint]))
    raise ValueError(f'War route is disconnected: {origin} -> {target}')


def main():
    source = ROOT / 'code/data/catalog_fleet_v23.db'
    assert hashlib.sha256(source.read_bytes()).hexdigest() == FLEET_SHA256, 'Unreviewed fleet bridge'
    with sqlite3.connect(source.as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        lines = ['-- Additive march/growth content; v0.31 definitions remain unchanged.']

        def insert(table, values):
            lines.append('INSERT INTO ' + table + ' VALUES(' + ','.join(map(literal, values)) + ');')

        # Timing hypotheses, to be checked with the combined normal-flow batch.
        insert('march_balance_defs', [1, 8.0, 4.0, 0.18, 6.0, 36.0, 120.0, 700.0, 180.0, 800.0, 180.0, 0.5, 2.0, 256, 60.0, 20.0])
        endpoints = [dict(x) for x in db.execute('SELECT * FROM gate_endpoint_defs ORDER BY endpoint_id')]
        for war in db.execute('SELECT * FROM civilization_war_defs ORDER BY war_id'):
            faction = db.execute('SELECT * FROM civilization_defs WHERE faction_id=?', (war['faction_id'],)).fetchone()
            allies = list(db.execute("SELECT spawn_id FROM civilization_war_members WHERE war_id=? AND side='ally' ORDER BY formation_index", (war['war_id'],)))
            hull = db.execute('SELECT ship_id FROM civilization_hull_defs WHERE faction_id=? AND required_rank=2', (war['faction_id'],)).fetchone()[0]
            insert('march_campaign_defs', [war['war_id'], faction['capital_station_id'], war['capture_anchor_id'], allies[0][0], hull])
            route = itinerary(endpoints, faction['capital_sector_id'], war['target_sector_id'])
            for index, endpoint in enumerate(route):
                reverse = next(e for e in endpoints if e['connection_id'] == endpoint['connection_id'] and e['origin_sector_id'] == endpoint['target_sector_id'] and e['target_sector_id'] == endpoint['origin_sector_id'])
                insert('march_route_defs', [war['war_id'], index, endpoint['endpoint_id'], reverse['endpoint_id']])

        for faction in db.execute('SELECT * FROM civilization_defs ORDER BY faction_id'):
            fid, station = faction['faction_id'], faction['capital_station_id']
            hulls = list(db.execute('SELECT * FROM civilization_hull_defs WHERE faction_id=? ORDER BY required_rank', (fid,)))
            research = [db.execute('SELECT research_id FROM research_defs WHERE reward_unlock_id=?', (hull['required_unlock_id'],)).fetchone()[0] for hull in hulls]
            war = db.execute('SELECT war_id FROM civilization_war_defs WHERE faction_id=? ORDER BY war_id LIMIT 1', (fid,)).fetchone()[0]
            stages = [
                ('join', '完成核心站入籍', 'membership', fid, 1, '加入文明，开放专属发展'),
                ('rank2', '取得中级舰采购资格', 'rank', fid, 2, '开放第一型文明舰'),
                ('register', '登记文明指挥考核', 'registration', fid, 1, '后续真实行动开始计入考核'),
                ('command', '完成文明指挥考核', 'honors', fid, 4, '取得战争指挥资格；逐项可领整备款'),
                ('research2', '研究中级文明舰', 'research', research[0], 1, '取得中级舰设计许可'),
                ('hull2', '整备中级文明舰', 'owned_hull', hulls[0]['ship_id'], 1, '形成文明战术核心'),
                ('rank4', '取得高级舰采购资格', 'rank', fid, 4, '开放第二型文明舰'),
                ('research4', '研究高级文明舰', 'research', research[1], 1, '取得高级舰设计许可'),
                ('rank5', '取得舰队伯爵爵位', 'rank', fid, 5, '达到边疆战争受领爵位'),
                ('war', '完成首次边疆战役', 'war', war, 1, '获得据点并开启持续治理'),
                ('rank6', '取得主力舰采购资格', 'rank', fid, 6, '开放文明主力舰'),
                ('research6', '研究文明主力舰', 'research', research[2], 1, '取得主力舰设计许可'),
                ('rank7', '取得星域公爵爵位', 'rank', fid, 7, '完成爵位成长，继续远征与治理'),
            ]
            for order, (suffix, title, criterion, ref, count, outcome) in enumerate(stages):
                stage = fid + '_' + suffix
                insert('growth_stage_defs', [stage, fid, order, title, criterion, ref, count, station, outcome])
                sources = []
                if criterion == 'membership':
                    sources = [('mission', row[0]) for row in db.execute('SELECT mission_id FROM civilization_join_missions WHERE faction_id=? ORDER BY step_index', (fid,))]
                elif criterion == 'registration':
                    sources = [('honor_register', fid)]
                elif criterion == 'rank':
                    sources = [('mission', row[0]) for row in db.execute('SELECT m.mission_id FROM mission_defs m JOIN mission_reputation_rewards r USING(mission_id) WHERE r.faction_id=? AND m.repeatable=1 ORDER BY r.reputation_delta DESC,m.mission_id', (fid,))]
                    sources += [('donation', row[0]) for row in db.execute('SELECT donation_id FROM civilization_donation_defs WHERE faction_id=? ORDER BY donation_id', (fid,))]
                elif criterion == 'honors':
                    sources = [('honor', row[0]) for row in db.execute('SELECT task_id FROM civilization_honor_task_defs WHERE faction_id=? ORDER BY task_id', (fid,))]
                elif criterion == 'research':
                    sources = [('research', ref)]
                elif criterion == 'owned_hull':
                    sources = [('hull_recipe', row[0]) for row in db.execute('SELECT hull_recipe_id FROM hull_recipe_defs WHERE ship_id=? ORDER BY hull_recipe_id', (ref,))]
                elif criterion == 'war':
                    sources = [('war', war)]
                for index, (kind, reference) in enumerate(sources):
                    at = db.execute('SELECT accept_station_id FROM mission_defs WHERE mission_id=?', (reference,)).fetchone()[0] if kind == 'mission' else station
                    insert('growth_activity_defs', [stage, index, kind, reference, at])
        for kind, table, id_field, station_field, title, outcome in [
            ('expedition', 'expedition_route_defs', 'route_id', 'origin_station_id', '完成分段深空远征', '带回成果，选择深入或撤回'),
            ('project', 'construction_project_defs', 'project_id', 'station_id', '完成跨站工业建设', '投入转化为持续地区收益'),
        ]:
            row = db.execute(f'SELECT * FROM {table} ORDER BY {id_field} LIMIT 1').fetchone()
            stage = 'growth_' + kind
            insert('growth_stage_defs', [stage, None, 13, title, kind, row[id_field], 1, row[station_field], outcome])
            insert('growth_activity_defs', [stage, 0, kind, row[id_field], row[station_field]])
        for task in db.execute('SELECT * FROM civilization_honor_task_defs ORDER BY task_id'):
            title = {'scout': '侦察', 'logistics': '物流', 'rescue': '救援', 'combat': '作战'}[task['task_kind']]
            insert('growth_grant_defs', [task['task_id'], 8000, 350, title + '整备款'])
        lines.append("UPDATE catalog_meta SET content_version='v0.24-march',ruleset_version='singleplayer_march_v1',schema_version=23,source_document='doc/61-边疆战争与重建争夺.md';")
        (ROOT / 'code/database/march_seed.sql').write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
        print('Authored continuous war itineraries and growth references; old definitions unchanged')


if __name__ == '__main__':
    main()
