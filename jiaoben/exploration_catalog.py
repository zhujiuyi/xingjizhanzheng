"""Reviewed authored-event schema and complete gameplay definition checks."""
COLUMNS = {
 "exploration_balance_defs": "singleton:INTEGER:1|hazard_period_s:REAL:0|hazard_warning_s:REAL:0|hazard_active_s:REAL:0|hazard_radius_m:REAL:0|solar_damage_hp_s:REAL:0|em_scan_multiplier:REAL:0|em_shield_multiplier:REAL:0|stabilized_multiplier:REAL:0|escort_follow_m:REAL:0|extraction_radius_m:REAL:0|escort_departure_m:REAL:0|transport_initial_hull_ratio:REAL:0",
 "exploration_event_defs": "event_id:TEXT:1|display_name:TEXT:0|event_kind:TEXT:0|sector_id:TEXT:0|entry_anchor_id:TEXT:0|exit_anchor_id:TEXT:0|station_id:TEXT:0|required_unlock_id:TEXT:0|environment_kind:TEXT:0|clue_text:TEXT:0|cooldown_s:REAL:0|operation_range_m:REAL:0",
 "exploration_variant_defs": "variant_id:TEXT:1|event_id:TEXT:0|variant_index:INTEGER:0|display_name:TEXT:0|duration_s:REAL:0|enemy_count:INTEGER:0|repair_units:INTEGER:0|recovery_item_id:TEXT:0|recovery_units:INTEGER:0|full_credit:INTEGER:0|partial_credit:INTEGER:0|insight_units:INTEGER:0|reputation_units:INTEGER:0|survey_duration_s:REAL:0|work_duration_s:REAL:0|relic_layers:INTEGER:0|mineral_quota:INTEGER:0|mineral_units:INTEGER:0",
 "exploration_actor_defs": "event_id:TEXT:1|actor_role:TEXT:2|slot_index:INTEGER:3|spawn_id:TEXT:0|hull_id:TEXT:0",
 "exploration_resource_defs": "node_id:TEXT:1|event_id:TEXT:0|choice_id:TEXT:0",
 "exploration_obstacle_defs": "obstacle_id:TEXT:1|event_id:TEXT:0|anchor_id:TEXT:0|radius_m:REAL:0",
 "exploration_research_defs": "research_id:TEXT:1|display_name:TEXT:0|required_insight:INTEGER:0|required_credit:INTEGER:0|reward_unlock_id:TEXT:0|perk_kind:TEXT:0|multiplier:REAL:0|description:TEXT:0",
}
TABLES = tuple(COLUMNS)


def validate(db):
    events = db.execute("SELECT event_id,event_kind,entry_anchor_id,exit_anchor_id FROM exploration_event_defs").fetchall()
    campaign = db.execute("SELECT 1 FROM sqlite_schema WHERE type='table' AND name='campaign_event_defs'").fetchone() is not None
    expected = 12 if campaign else 6
    if len(events) != expected or db.execute("SELECT count(*) FROM exploration_variant_defs").fetchone()[0] != expected * 3:
        raise ValueError("Exploration requires six authored structures and eighteen fixed variants")
    for event, kind, entry, exit_ in events:
        if [r[0] for r in db.execute("SELECT variant_index FROM exploration_variant_defs WHERE event_id=? ORDER BY variant_index", (event,))] != [1, 2, 3]:
            raise ValueError("Every structure needs three executable variants")
        sites = db.execute("SELECT site_id FROM anchor_site_defs WHERE anchor_id IN (?,?)", (entry, exit_)).fetchall()
        if len(sites) != 2 or sites[0] != sites[1]:
            raise ValueError("Extraction and action must occupy the same precise local space")
        roles = dict(db.execute("SELECT actor_role,count(*) FROM exploration_actor_defs WHERE event_id=? GROUP BY actor_role", (event,)))
        if roles.get("enemy") != 3 or (kind == "rescue" and roles.get("escort") != 1):
            raise ValueError("Authored combat and escort roles are incomplete")
        if kind == "mineral" and set(r[0] for r in db.execute("SELECT choice_id FROM exploration_resource_defs WHERE event_id=?", (event,))) != {"safe", "rich"}:
            raise ValueError("Temporary mineral belt needs real safe and rich choices")
    invalid = db.execute("SELECT count(*) FROM exploration_actor_defs a JOIN npc_spawn_defs s USING(spawn_id) WHERE s.bounty_enabled<>0 OR s.loot_enabled<>0").fetchone()[0]
    if invalid:
        raise ValueError("Managed event actors must not mint independent repeatable bounty or loot")
    if db.execute("SELECT count(*) FROM exploration_research_defs").fetchone()[0] != 3:
        raise ValueError("Accumulated exploration evidence needs three actual research uses")
