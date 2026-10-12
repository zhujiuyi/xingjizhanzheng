"""Additive situational definitions; SQL remains the sole numeric authority."""
TABLES=('situational_balance_defs','situational_cue_defs')
COLUMNS={
 'situational_balance_defs':'singleton:INTEGER:1|observation_interval_s:REAL:0|resource_fresh_s:REAL:0|demand_fresh_s:REAL:0|extraction_warning_s:REAL:0|cue_sound_cooldown_s:REAL:0|max_flight_cues:INTEGER:0',
 'situational_cue_defs':'cue_id:TEXT:1|title:TEXT:0|icon_page:TEXT:0|sound_id:TEXT:0|priority:INTEGER:0|severity:TEXT:0',
}

def validate(db):
    row=db.execute('SELECT * FROM situational_balance_defs').fetchall()
    if len(row)!=1:raise ValueError('Exactly one situational policy required')
    cues={r[0] for r in db.execute('SELECT cue_id FROM situational_cue_defs')}
    if cues!={'charge','jam','drone_link','hire_link','support','cargo','extraction','environment'}:
        raise ValueError('Incomplete situational cue vocabulary')
    for sound, in db.execute('SELECT DISTINCT sound_id FROM situational_cue_defs'):
        from pathlib import Path
        if not (Path(__file__).resolve().parents[1]/'code/assets/audio'/f'{sound}.wav').is_file():
            raise ValueError('Cue sound not in asset catalog: '+sound)
