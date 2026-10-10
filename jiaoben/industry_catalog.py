"""Reviewed registry and semantic checks for offline industrial progression."""
COLUMNS = {
    "industry_balance_defs": "singleton:INTEGER:1|queue_limit:INTEGER:0|max_batches:INTEGER:0|running_refund_bp:INTEGER:0|price_min_bp:INTEGER:0|price_max_bp:INTEGER:0|pressure_bp:INTEGER:0|demand_industry_discount_bp:INTEGER:0|demand_benefit_duration_s:REAL:0",
    "industry_recipe_defs": "blueprint_id:TEXT:1|recipe_id:TEXT:0|hull_recipe_id:TEXT:0|duration_per_batch_s:REAL:0",
    "station_demand_defs": "demand_id:TEXT:1|station_id:TEXT:0|item_id:TEXT:0|display_name:TEXT:0|reason:TEXT:0|required_units:INTEGER:0|unit_reward_credit:INTEGER:0|reward_reputation:INTEGER:0|duration_s:REAL:0|cooldown_s:REAL:0",
}
TABLES = tuple(COLUMNS)


def validate(db):
    actual = db.execute("SELECT COUNT(*) FROM industry_recipe_defs").fetchone()[0]
    expected = sum(db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] for table in ("recipe_defs", "hull_recipe_defs"))
    if actual != expected:
        raise ValueError("Every manufacturing blueprint needs a frozen queue duration")
    invalid = db.execute("SELECT COUNT(*) FROM station_demand_defs d JOIN item_defs i USING(item_id) WHERE i.item_type='module' OR d.unit_reward_credit>=i.base_ask_credit OR NOT EXISTS(SELECT 1 FROM station_service_defs s WHERE s.station_id=d.station_id AND s.service_id='manufacture')").fetchone()[0]
    if invalid or not db.execute("SELECT COUNT(*) FROM station_demand_defs").fetchone()[0]:
        raise ValueError("Regional needs lack normal materials, bounded spread or a real industrial service")
    missing = db.execute("SELECT COUNT(DISTINCT station_id) FROM station_service_defs s WHERE service_id='manufacture' AND NOT EXISTS(SELECT 1 FROM station_demand_defs d WHERE d.station_id=s.station_id)").fetchone()[0]
    if missing:
        raise ValueError("An industrial station silently lost its regional material need")
