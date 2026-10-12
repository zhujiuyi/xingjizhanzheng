"""Definition closure for owned fleet, finite crew and auxiliary drone bays."""
TABLES = ('fleet_balance_defs', 'crew_profession_defs', 'crew_rank_defs',
          'crew_profile_defs', 'fleet_hull_defs', 'auxiliary_drone_defs',
          'ship_auxiliary_permissions')
COLUMNS = {'auxiliary_drone_defs': 'module_id:TEXT:1|role_kind:TEXT:0|drone_count:INTEGER:0|speed_mps:REAL:0|acceleration_mps2:REAL:0|turn_rad_s:REAL:0|work_range_m:REAL:0|sortie_timeout_s:REAL:0|return_radius_m:REAL:0|hull_hp:REAL:0|restore_amount:REAL:0|sensor_range_m:REAL:0|observe_cycle_s:REAL:0|observation_ttl_s:REAL:0|consumable_item_id:TEXT:0|consumable_per_sortie:INTEGER:0|material_id:TEXT:0|material_per_unit:INTEGER:0|credit_per_unit:INTEGER:0',
 'crew_profession_defs': 'profession_id:TEXT:1|display_name:TEXT:0|duty_kind:TEXT:0|hire_fee_credit:INTEGER:0|salary_credit:INTEGER:0|effect_stat:TEXT:0|effect_mode:TEXT:0|contribution_kind:TEXT:0|contribution_per_xp:REAL:0|description:TEXT:0',
 'crew_profile_defs': 'profile_id:TEXT:1|display_name:TEXT:0|profession_id:TEXT:0',
 'crew_rank_defs': 'profession_id:TEXT:1|rank:INTEGER:2|experience_required:INTEGER:0|effect_value:REAL:0|salary_multiplier:REAL:0',
 'fleet_balance_defs': 'singleton:INTEGER:1|max_owned_companions:INTEGER:0|max_recruited_crew:INTEGER:0|required_unlock_id:TEXT:0|communication_m:REAL:0|formation_m:REAL:0|warp_ready_m:REAL:0|retreat_distance_m:REAL:0|retreat_charge_s:REAL:0|return_s:REAL:0|deploy_fee_credit:INTEGER:0|deploy_hull_fee_bp:INTEGER:0|salary_period_s:REAL:0|loyalty_initial:INTEGER:0|loyalty_paid_gain:INTEGER:0|loyalty_unpaid_loss:INTEGER:0|loyalty_casualty_loss:INTEGER:0|loyalty_ready_min:INTEGER:0|arrears_period_limit:INTEGER:0|injury_recovery_s:REAL:0|injury_treatment_credit:INTEGER:0|rest_duration_s:REAL:0|rest_credit:INTEGER:0|experience_cap:INTEGER:0|history_limit:INTEGER:0',
 'fleet_hull_defs': 'ship_id:TEXT:1|spawn_id:TEXT:0|crew_slots:INTEGER:0',
 'ship_auxiliary_permissions': 'ship_id:TEXT:1|role_kind:TEXT:2|max_installed:INTEGER:0'}


def validate(db):
    def require(ok, message):
        if not ok:
            raise ValueError(message)
    require(db.execute('SELECT count(*) FROM fleet_balance_defs').fetchone()[0] == 1,
            'Exactly one fleet balance row is required')
    require({r[0] for r in db.execute('SELECT duty_kind FROM crew_profession_defs')} ==
            {'pilot', 'gunner', 'engineer', 'scout'}, 'Four usable crew professions required')
    cap = db.execute('SELECT experience_cap FROM fleet_balance_defs').fetchone()[0]
    for (profession,) in db.execute('SELECT profession_id FROM crew_profession_defs'):
        ranks = db.execute('SELECT rank,experience_required,effect_value,salary_multiplier FROM crew_rank_defs WHERE profession_id=? ORDER BY rank', (profession,)).fetchall()
        require([r[0] for r in ranks] == [1, 2, 3] and ranks[0][1] == 0 and
                ranks[0][1] < ranks[1][1] < ranks[2][1] <= cap and
                ranks[0][2] < ranks[1][2] < ranks[2][2], 'Crew career must be finite and progressive')
        require(db.execute('SELECT count(*) FROM crew_profile_defs WHERE profession_id=?', (profession,)).fetchone()[0] == 2,
                'Each profession requires two persistent named recruits')
    require({r[0] for r in db.execute('SELECT ship_id FROM fleet_hull_defs')} ==
            {r[0] for r in db.execute('SELECT ship_id FROM ship_defs')}, 'All owned hulls need explicit crew/deployment bindings')
    for ship, spawn in db.execute('SELECT ship_id,spawn_id FROM fleet_hull_defs'):
        row = db.execute('SELECT occurrence_mode,bounty_enabled,loot_enabled FROM npc_spawn_defs WHERE spawn_id=?', (spawn,)).fetchone()
        require(tuple(row) == ('mission_scoped', 0, 0) and spawn.startswith('owned_'),
                'Owned actors must not automatically spawn, grant bounty or duplicate loot')
    for module, role, count, speed, timeout in db.execute('SELECT module_id,role_kind,drone_count,speed_mps,sortie_timeout_s FROM auxiliary_drone_defs'):
        spec = db.execute('SELECT slot_type,range_m FROM module_defs WHERE module_id=?', (module,)).fetchone()
        require(spec[0] == 'work' and 2 * spec[1] / speed < timeout,
                'Auxiliary sorties require a work slot and feasible outward/return flight')
        require(db.execute('SELECT count(*) FROM station_stock_defs WHERE item_id=? AND allow_buy=1', (module,)).fetchone()[0] > 0,
                'Auxiliary bay lacks a purchase route')
        require(db.execute('SELECT count(*) FROM recipe_defs r JOIN recipe_access_defs a USING(recipe_id) WHERE r.output_item_id=?', (module,)).fetchone()[0] > 0,
                'Auxiliary bay lacks a real construction route')
    for ship, role in db.execute('SELECT ship_id,role_kind FROM ship_auxiliary_permissions'):
        slots = db.execute("SELECT slot_count FROM ship_slot_capacity WHERE ship_id=? AND slot_type='work'", (ship,)).fetchone()
        require(slots is not None and slots[0] > 0, 'Auxiliary permission requires a physical work slot')
    for role in ['repair', 'recon']:
        tiers = db.execute('SELECT t.tech_level,m.range_m,i.base_ask_credit FROM auxiliary_drone_defs a JOIN module_tech_defs t USING(module_id) JOIN module_defs m USING(module_id) JOIN item_defs i ON i.item_id=a.module_id WHERE a.role_kind=? ORDER BY t.tech_level', (role,)).fetchall()
        require(len(tiers) == 2 and [r[0] for r in tiers] == [1, 2] and
                tiers[0][1] < tiers[1][1] and tiers[0][2] < tiers[1][2],
                'Both auxiliary roles need real cost/range/technology tiers')
