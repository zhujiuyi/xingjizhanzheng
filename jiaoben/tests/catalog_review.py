"""Isolate only v0.15's reviewed names in older additive-preservation checks.

Callers first require every historical row to remain present. test_fitting.py
separately compares all v0.14 schemas, rows and views against the live catalogue.
"""
FITTING_NAMES = {
    'unlock_defs': ('unlock_id', 'unlock_spec_'),
    'item_defs': ('item_id', 'module_spec_'),
    'module_defs': ('module_id', 'module_spec_'),
    'module_tech_defs': ('module_id', 'module_spec_'),
    'module_group_members': ('module_id', 'module_spec_'),
    'module_salvage_recipe_defs': ('module_id', 'module_spec_'),
    'module_exclusion_groups': ('group_id', 'spec_'),
    'recipe_defs': ('recipe_id', 'recipe_spec_'),
    'recipe_inputs': ('recipe_id', 'recipe_spec_'),
    'recipe_access_defs': ('recipe_id', 'recipe_spec_'),
    'recycle_outputs': ('source_item_id', 'module_spec_'),
    'station_stock_defs': ('item_id', 'module_spec_'),
    'industry_recipe_defs': ('blueprint_id', 'recipe_spec_'),
}

def without_fleet_extensions(connection,table,rows):
    """Only the nineteen namespaces whose old rows test_fleet protects."""
    from fleet_catalog import EXTENSIONS
    if table not in EXTENSIONS:return rows
    column,prefix=EXTENSIONS[table]
    index=[r[1] for r in connection.execute(f'PRAGMA table_info("{table}")')].index(column)
    return {row for row in rows if not str(row[index]).startswith(prefix)}

def without_campaign_extensions(connection,table,rows):
    """Only explicit namespace additions; test_campaign protects every v0.28 row."""
    from scenario_catalog import EXTENSIONS as SCENARIO_EXTENSIONS
    from campaign_catalog import EXTENSIONS
    rows=without_fleet_extensions(connection,table,rows)
    if table not in set(EXTENSIONS)|set(SCENARIO_EXTENSIONS):return rows
    columns=[r[1] for r in connection.execute('PRAGMA table_info("'+table+'")')]
    key=next(r[1] for r in connection.execute('PRAGMA table_info("'+table+'")') if r[5]==1)
    index=columns.index(key)
    return {r for r in rows if not str(r[index]).startswith(('exp_theme_','tac_exp_theme_','trial_','blockade_'))}

def without_fitting_extensions(connection, table, rows):
    rows=without_campaign_extensions(connection,table,rows)
    if table not in FITTING_NAMES:
        return rows
    column, prefix = FITTING_NAMES[table]
    columns = [r[1] for r in connection.execute(f'PRAGMA table_info("{table}")')]
    index = columns.index(column)
    return {r for r in rows if not str(r[index]).startswith(prefix)}

def without_hire_extensions(connection,table,rows):
    """Only eight reviewed additive tables; test_hire protects all v0.26 rows."""
    rows=without_campaign_extensions(connection,table,rows)
    columns_by_table={'anchor_defs':'anchor_id','anchor_site_defs':'anchor_id','npc_archetype_defs':'archetype_id','npc_resistances':'archetype_id','npc_behavior_defs':'behavior_id','npc_defs':'npc_id','npc_spawn_defs':'spawn_id','npc_patrol_points':'spawn_id'}
    if table not in columns_by_table:return rows
    columns=[r[1] for r in connection.execute(f'PRAGMA table_info("{table}")')]
    index=columns.index(columns_by_table[table])
    return {r for r in rows if not str(r[index]).startswith('hire_')}

def without_frontier_extensions(connection, table, rows):
    """Reviewed frontier/hire additions only; newest archive checks every old row."""
    rows=without_hire_extensions(connection,table,rows)
    columns_by_table={'anchor_defs':'anchor_id','anchor_site_defs':'anchor_id','npc_defs':'npc_id','npc_spawn_defs':'spawn_id','npc_patrol_points':'spawn_id'}
    if table not in columns_by_table:return rows
    columns=[r[1] for r in connection.execute(f'PRAGMA table_info("{table}")')]
    index=columns.index(columns_by_table[table])
    return {r for r in rows if not str(r[index]).startswith('frontier_')}

def without_later_extensions(connection,table,rows):
    return without_frontier_extensions(connection,table,without_fitting_extensions(connection,table,rows))
