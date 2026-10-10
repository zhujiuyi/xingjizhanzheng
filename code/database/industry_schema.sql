-- Additive offline industry definitions; legacy definition rows remain exact.
CREATE TABLE industry_balance_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 queue_limit INTEGER NOT NULL CHECK(queue_limit BETWEEN 1 AND 20),
 max_batches INTEGER NOT NULL CHECK(max_batches BETWEEN 1 AND 100),
 running_refund_bp INTEGER NOT NULL CHECK(running_refund_bp BETWEEN 0 AND 10000),
 price_min_bp INTEGER NOT NULL CHECK(price_min_bp BETWEEN 1 AND 10000),
 price_max_bp INTEGER NOT NULL CHECK(price_max_bp>=10000),
 pressure_bp INTEGER NOT NULL CHECK(pressure_bp>=0),
 demand_industry_discount_bp INTEGER NOT NULL CHECK(demand_industry_discount_bp BETWEEN 0 AND 5000),
 demand_benefit_duration_s REAL NOT NULL CHECK(demand_benefit_duration_s>0)
) STRICT;
CREATE TABLE industry_recipe_defs (
 blueprint_id TEXT PRIMARY KEY,
 recipe_id TEXT UNIQUE REFERENCES recipe_defs(recipe_id),
 hull_recipe_id TEXT UNIQUE REFERENCES hull_recipe_defs(hull_recipe_id),
 duration_per_batch_s REAL NOT NULL CHECK(duration_per_batch_s>0),
 CHECK((recipe_id IS NULL)<>(hull_recipe_id IS NULL))
) STRICT;
CREATE TABLE station_demand_defs (
 demand_id TEXT PRIMARY KEY,
 station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 item_id TEXT NOT NULL REFERENCES item_defs(item_id),
 display_name TEXT NOT NULL, reason TEXT NOT NULL,
 required_units INTEGER NOT NULL CHECK(required_units>0),
 unit_reward_credit INTEGER NOT NULL CHECK(unit_reward_credit>0),
 reward_reputation INTEGER NOT NULL CHECK(reward_reputation>=0),
 duration_s REAL NOT NULL CHECK(duration_s>0),
 cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
 UNIQUE(station_id,item_id)
) STRICT;
