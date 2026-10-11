"""Authoritative role capabilities and bounded entrusted freight definitions."""
TABLES = ('ship_role_capability_defs','role_balance_defs','consignment_defs')
COLUMNS = {
 'ship_role_capability_defs': 'ship_id:TEXT:1|survey_multiplier:REAL:0|sensor_multiplier:REAL:0|remote_repair_allowed:INTEGER:0|remote_range_multiplier:REAL:0|remote_shield_multiplier:REAL:0|remote_armor_multiplier:REAL:0',
 'role_balance_defs': 'singleton:INTEGER:1|scan_reference_strength:REAL:0|min_survey_rate:REAL:0|max_survey_rate:REAL:0|remote_range_floor_m:REAL:0|freight_exposure_s:REAL:0|freight_loss_damage_hp:REAL:0',
 'consignment_defs': 'contract_id:TEXT:1|display_name:TEXT:0|origin_station_id:TEXT:0|destination_station_id:TEXT:0|required_unlock_id:TEXT:0|max_units:INTEGER:0|unit_volume_l:REAL:0|unit_mass_kg:REAL:0|deposit_per_unit:INTEGER:0|fee_credit:INTEGER:0|reward_per_unit:INTEGER:0|deadline_s:REAL:0|cooldown_s:REAL:0',
}
def validate(db):
    ships={r[0] for r in db.execute('SELECT ship_id FROM ship_defs')}
    caps=db.execute('SELECT ship_id,remote_repair_allowed FROM ship_role_capability_defs').fetchall()
    if {r[0] for r in caps} != ships: raise ValueError('Role capability coverage must match every hull')
    supports={r[0] for r in db.execute("SELECT ship_id FROM ship_role_defs WHERE class_id='support'")}
    if {r[0] for r in caps if r[1]} != supports: raise ValueError('Remote repair must match support hull permissions')
    if db.execute('SELECT count(*) FROM role_balance_defs').fetchone()[0] != 1: raise ValueError('Missing role balance')
    if db.execute('SELECT count(*) FROM consignment_defs').fetchone()[0] != 2: raise ValueError('Authored freight routes incomplete')
    for row in db.execute('SELECT max_units,deposit_per_unit,fee_credit,reward_per_unit,deadline_s,cooldown_s FROM consignment_defs'):
        if row[0]*row[3]/row[5]>30: raise ValueError('Freight steady reward exceeds the reviewed credit/second ceiling')
