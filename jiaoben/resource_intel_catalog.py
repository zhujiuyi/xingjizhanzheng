"""Reviewed resource quality and sector-role definition registry."""
COLUMNS = {
    "resource_grade_defs": "node_id:TEXT:1|grade_level:INTEGER:0|display_name:TEXT:0|yield_multiplier_bp:INTEGER:0",
    "sector_activity_defs": "sector_id:TEXT:1|resource_role:TEXT:0|environment_hint:TEXT:0|logistics_role:TEXT:0|event_hint:TEXT:0",
}
TABLES = tuple(COLUMNS)


def validate(db):
    for definitions, base, key in (("resource_grade_defs", "resource_node_defs", "node_id"), ("sector_activity_defs", "sector_defs", "sector_id")):
        if db.execute(f"SELECT count(*) FROM {definitions}").fetchone()[0] != db.execute(f"SELECT count(*) FROM {base}").fetchone()[0]:
            raise ValueError(f"Incomplete resource intelligence: {definitions}")
    invalid = db.execute("SELECT count(*) FROM resource_grade_defs g JOIN resource_node_defs n USING(node_id) JOIN sector_sovereignty_defs p USING(sector_id) WHERE p.initial_faction_id IS NULL AND p.conquerable=0 AND g.yield_multiplier_bp<>10000").fetchone()[0]
    if invalid:
        raise ValueError("Protected tutorial corridor must preserve its original mining yield")
    if not db.execute("SELECT count(*) FROM resource_grade_defs WHERE yield_multiplier_bp>10000").fetchone()[0]:
        raise ValueError("Resource grades must have a real extraction effect")
