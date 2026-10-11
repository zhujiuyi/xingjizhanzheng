-- Six authored structures and frozen per-generation variations.
CREATE TABLE exploration_balance_defs (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 hazard_period_s REAL NOT NULL CHECK(hazard_period_s>0),
 hazard_warning_s REAL NOT NULL CHECK(hazard_warning_s>0),
 hazard_active_s REAL NOT NULL CHECK(hazard_active_s>0),
 hazard_radius_m REAL NOT NULL CHECK(hazard_radius_m>0),
 solar_damage_hp_s REAL NOT NULL CHECK(solar_damage_hp_s>0),
 em_scan_multiplier REAL NOT NULL CHECK(em_scan_multiplier>0 AND em_scan_multiplier<=1),
 em_shield_multiplier REAL NOT NULL CHECK(em_shield_multiplier>0 AND em_shield_multiplier<=1),
 stabilized_multiplier REAL NOT NULL CHECK(stabilized_multiplier>=0 AND stabilized_multiplier<=1),
 escort_follow_m REAL NOT NULL CHECK(escort_follow_m>0),
 extraction_radius_m REAL NOT NULL CHECK(extraction_radius_m>0),
 escort_departure_m REAL NOT NULL CHECK(escort_departure_m>0),
 transport_initial_hull_ratio REAL NOT NULL CHECK(transport_initial_hull_ratio>0 AND transport_initial_hull_ratio<1),
 CHECK(hazard_warning_s+hazard_active_s<hazard_period_s)
) STRICT;
CREATE TABLE exploration_event_defs (
 event_id TEXT PRIMARY KEY, display_name TEXT NOT NULL,
 event_kind TEXT NOT NULL CHECK(event_kind IN ('rescue','relic','mineral')),
 sector_id TEXT NOT NULL REFERENCES sector_defs(sector_id),
 entry_anchor_id TEXT NOT NULL UNIQUE REFERENCES anchor_defs(anchor_id),
 exit_anchor_id TEXT NOT NULL UNIQUE REFERENCES anchor_defs(anchor_id),
 station_id TEXT NOT NULL REFERENCES station_defs(station_id),
 required_unlock_id TEXT NOT NULL REFERENCES unlock_defs(unlock_id),
 environment_kind TEXT NOT NULL CHECK(environment_kind IN ('fragments','em','solar')),
 clue_text TEXT NOT NULL, cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
 operation_range_m REAL NOT NULL CHECK(operation_range_m>0)
) STRICT;
CREATE TABLE exploration_variant_defs (
 variant_id TEXT PRIMARY KEY, event_id TEXT NOT NULL REFERENCES exploration_event_defs(event_id),
 variant_index INTEGER NOT NULL CHECK(variant_index BETWEEN 1 AND 3),
 display_name TEXT NOT NULL, duration_s REAL NOT NULL CHECK(duration_s>0),
 enemy_count INTEGER NOT NULL CHECK(enemy_count BETWEEN 1 AND 3),
 repair_units INTEGER NOT NULL CHECK(repair_units>0),
 recovery_item_id TEXT NOT NULL REFERENCES item_defs(item_id),
 recovery_units INTEGER NOT NULL CHECK(recovery_units>0),
 full_credit INTEGER NOT NULL CHECK(full_credit>0), partial_credit INTEGER NOT NULL CHECK(partial_credit>=0 AND partial_credit<full_credit),
 insight_units INTEGER NOT NULL CHECK(insight_units>0), reputation_units INTEGER NOT NULL CHECK(reputation_units>=0),
 survey_duration_s REAL NOT NULL CHECK(survey_duration_s>0), work_duration_s REAL NOT NULL CHECK(work_duration_s>0),
 relic_layers INTEGER NOT NULL CHECK(relic_layers>0), mineral_quota INTEGER NOT NULL CHECK(mineral_quota>0),
 mineral_units INTEGER NOT NULL CHECK(mineral_units>=mineral_quota),
 UNIQUE(event_id,variant_index), UNIQUE(variant_id,event_id)
) STRICT;
CREATE TABLE exploration_actor_defs (
 event_id TEXT NOT NULL REFERENCES exploration_event_defs(event_id),
 actor_role TEXT NOT NULL CHECK(actor_role IN ('escort','enemy')),
 slot_index INTEGER NOT NULL CHECK(slot_index>=0),
 spawn_id TEXT NOT NULL UNIQUE REFERENCES npc_spawn_defs(spawn_id),
 hull_id TEXT REFERENCES ship_defs(ship_id),
 PRIMARY KEY(event_id,actor_role,slot_index),
 CHECK((actor_role='escort')=(hull_id IS NOT NULL))
) STRICT;
CREATE TABLE exploration_resource_defs (
 node_id TEXT PRIMARY KEY REFERENCES resource_node_defs(node_id),
 event_id TEXT NOT NULL REFERENCES exploration_event_defs(event_id),
 choice_id TEXT NOT NULL CHECK(choice_id IN ('safe','rich')),
 UNIQUE(event_id,choice_id)
) STRICT;
CREATE TABLE exploration_obstacle_defs (
 obstacle_id TEXT PRIMARY KEY, event_id TEXT NOT NULL REFERENCES exploration_event_defs(event_id),
 anchor_id TEXT NOT NULL UNIQUE REFERENCES anchor_defs(anchor_id),
 radius_m REAL NOT NULL CHECK(radius_m>0)
) STRICT;
CREATE TABLE exploration_research_defs (
 research_id TEXT PRIMARY KEY, display_name TEXT NOT NULL,
 required_insight INTEGER NOT NULL CHECK(required_insight>0),
 required_credit INTEGER NOT NULL CHECK(required_credit>=0),
 reward_unlock_id TEXT NOT NULL UNIQUE REFERENCES unlock_defs(unlock_id),
 perk_kind TEXT NOT NULL UNIQUE CHECK(perk_kind IN ('scan','mitigation','mining')),
 multiplier REAL NOT NULL CHECK(multiplier>0), description TEXT NOT NULL
) STRICT;
