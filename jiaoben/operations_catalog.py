"""Reviewed objective, cargo and jammer definition registry."""
COLUMNS = {
 'operation_defs': 'operation_id:TEXT:1|display_name:TEXT:0|operation_kind:TEXT:0|station_id:TEXT:0|tactical_site_id:TEXT:0|entry_anchor_id:TEXT:0|exit_anchor_id:TEXT:0|required_unlock_id:TEXT:0|duration_s:REAL:0|cooldown_s:REAL:0|interaction_radius_m:REAL:0|target_units:INTEGER:0|cargo_volume_l:REAL:0|cargo_mass_kg:REAL:0|exposure_duration_s:REAL:0|loss_damage_hp:REAL:0|exposure_detection_m:REAL:0|credit_per_unit:INTEGER:0|reputation_per_unit:INTEGER:0',
 'operation_structure_defs': 'spawn_id:TEXT:1|operation_id:TEXT:0|field_radius_m:REAL:0|thrust_ratio:REAL:0',
}
TABLES = tuple(COLUMNS)

def validate(db):
    assert {r[0] for r in db.execute('SELECT operation_kind FROM operation_defs')} == {'demolition', 'breakthrough'}
    for op, kind, units, entry, exit_ in db.execute('SELECT operation_id,operation_kind,target_units,entry_anchor_id,exit_anchor_id FROM operation_defs'):
        assert entry != exit_
        a = db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?', (entry,)).fetchone()
        b = db.execute('SELECT site_id FROM anchor_site_defs WHERE anchor_id=?', (exit_,)).fetchone()
        assert a == b, 'Objective travel is local, never an instant AU jump'
        if kind == 'demolition':
            assert db.execute('SELECT count(*) FROM operation_structure_defs WHERE operation_id=?', (op,)).fetchone()[0] == units
