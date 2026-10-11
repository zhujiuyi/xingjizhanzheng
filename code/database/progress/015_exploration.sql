-- Format11 -> 12: authored exploration, real actors and unique evidence/reward ledgers.

CREATE TABLE frozen_exploration_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
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
    CHECK(hazard_warning_s+hazard_active_s<hazard_period_s),
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_exploration_balance_defs_insert_guard BEFORE INSERT ON frozen_exploration_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_balance_defs_update_guard BEFORE UPDATE ON frozen_exploration_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_balance_defs_delete_guard BEFORE DELETE ON frozen_exploration_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_exploration_event_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    event_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    event_kind TEXT NOT NULL CHECK(event_kind IN ('rescue','relic','mineral')),
    sector_id TEXT NOT NULL,
    entry_anchor_id TEXT NOT NULL,
    exit_anchor_id TEXT NOT NULL,
    station_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    environment_kind TEXT NOT NULL CHECK(environment_kind IN ('fragments','em','solar')),
    clue_text TEXT NOT NULL,
    cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
    operation_range_m REAL NOT NULL CHECK(operation_range_m>0),
    PRIMARY KEY (content_snapshot_id, event_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, entry_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    UNIQUE (content_snapshot_id, entry_anchor_id),
    FOREIGN KEY (content_snapshot_id, exit_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    UNIQUE (content_snapshot_id, exit_anchor_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_exploration_event_defs_insert_guard BEFORE INSERT ON frozen_exploration_event_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_event_defs_update_guard BEFORE UPDATE ON frozen_exploration_event_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_event_defs_delete_guard BEFORE DELETE ON frozen_exploration_event_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_exploration_variant_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    variant_id TEXT NOT NULL,
    event_id TEXT NOT NULL,
    variant_index INTEGER NOT NULL CHECK(variant_index BETWEEN 1 AND 3),
    display_name TEXT NOT NULL,
    duration_s REAL NOT NULL CHECK(duration_s>0),
    enemy_count INTEGER NOT NULL CHECK(enemy_count BETWEEN 1 AND 3),
    repair_units INTEGER NOT NULL CHECK(repair_units>0),
    recovery_item_id TEXT NOT NULL,
    recovery_units INTEGER NOT NULL CHECK(recovery_units>0),
    full_credit INTEGER NOT NULL CHECK(full_credit>0),
    partial_credit INTEGER NOT NULL CHECK(partial_credit>=0 AND partial_credit<full_credit),
    insight_units INTEGER NOT NULL CHECK(insight_units>0),
    reputation_units INTEGER NOT NULL CHECK(reputation_units>=0),
    survey_duration_s REAL NOT NULL CHECK(survey_duration_s>0),
    work_duration_s REAL NOT NULL CHECK(work_duration_s>0),
    relic_layers INTEGER NOT NULL CHECK(relic_layers>0),
    mineral_quota INTEGER NOT NULL CHECK(mineral_quota>0),
    mineral_units INTEGER NOT NULL CHECK(mineral_units>=mineral_quota),
    UNIQUE (content_snapshot_id, event_id,variant_index),
    UNIQUE (content_snapshot_id, variant_id,event_id),
    PRIMARY KEY (content_snapshot_id, variant_id),
    FOREIGN KEY (content_snapshot_id, event_id) REFERENCES frozen_exploration_event_defs (content_snapshot_id, event_id),
    FOREIGN KEY (content_snapshot_id, recovery_item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_exploration_variant_defs_insert_guard BEFORE INSERT ON frozen_exploration_variant_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_variant_defs_update_guard BEFORE UPDATE ON frozen_exploration_variant_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_variant_defs_delete_guard BEFORE DELETE ON frozen_exploration_variant_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_exploration_actor_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    event_id TEXT NOT NULL,
    actor_role TEXT NOT NULL CHECK(actor_role IN ('escort','enemy')),
    slot_index INTEGER NOT NULL CHECK(slot_index>=0),
    spawn_id TEXT NOT NULL,
    hull_id TEXT,
    CHECK((actor_role='escort')=(hull_id IS NOT NULL)),
    PRIMARY KEY (content_snapshot_id, event_id, actor_role, slot_index),
    FOREIGN KEY (content_snapshot_id, event_id) REFERENCES frozen_exploration_event_defs (content_snapshot_id, event_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    UNIQUE (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, hull_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_exploration_actor_defs_insert_guard BEFORE INSERT ON frozen_exploration_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_actor_defs_update_guard BEFORE UPDATE ON frozen_exploration_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_actor_defs_delete_guard BEFORE DELETE ON frozen_exploration_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_exploration_resource_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    node_id TEXT NOT NULL,
    event_id TEXT NOT NULL,
    choice_id TEXT NOT NULL CHECK(choice_id IN ('safe','rich')),
    UNIQUE (content_snapshot_id, event_id,choice_id),
    PRIMARY KEY (content_snapshot_id, node_id),
    FOREIGN KEY (content_snapshot_id, node_id) REFERENCES frozen_resource_node_defs (content_snapshot_id, node_id),
    FOREIGN KEY (content_snapshot_id, event_id) REFERENCES frozen_exploration_event_defs (content_snapshot_id, event_id)
) STRICT;
CREATE TRIGGER frozen_exploration_resource_defs_insert_guard BEFORE INSERT ON frozen_exploration_resource_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_resource_defs_update_guard BEFORE UPDATE ON frozen_exploration_resource_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_resource_defs_delete_guard BEFORE DELETE ON frozen_exploration_resource_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_exploration_obstacle_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    obstacle_id TEXT NOT NULL,
    event_id TEXT NOT NULL,
    anchor_id TEXT NOT NULL,
    radius_m REAL NOT NULL CHECK(radius_m>0),
    PRIMARY KEY (content_snapshot_id, obstacle_id),
    FOREIGN KEY (content_snapshot_id, event_id) REFERENCES frozen_exploration_event_defs (content_snapshot_id, event_id),
    FOREIGN KEY (content_snapshot_id, anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    UNIQUE (content_snapshot_id, anchor_id)
) STRICT;
CREATE TRIGGER frozen_exploration_obstacle_defs_insert_guard BEFORE INSERT ON frozen_exploration_obstacle_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_obstacle_defs_update_guard BEFORE UPDATE ON frozen_exploration_obstacle_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_obstacle_defs_delete_guard BEFORE DELETE ON frozen_exploration_obstacle_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_exploration_research_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    research_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    required_insight INTEGER NOT NULL CHECK(required_insight>0),
    required_credit INTEGER NOT NULL CHECK(required_credit>=0),
    reward_unlock_id TEXT NOT NULL,
    perk_kind TEXT NOT NULL CHECK(perk_kind IN ('scan','mitigation','mining')),
    multiplier REAL NOT NULL CHECK(multiplier>0),
    description TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, research_id),
    FOREIGN KEY (content_snapshot_id, reward_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id),
    UNIQUE (content_snapshot_id, reward_unlock_id),
    UNIQUE (content_snapshot_id, perk_kind)
) STRICT;
CREATE TRIGGER frozen_exploration_research_defs_insert_guard BEFORE INSERT ON frozen_exploration_research_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_research_defs_update_guard BEFORE UPDATE ON frozen_exploration_research_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_exploration_research_defs_delete_guard BEFORE DELETE ON frozen_exploration_research_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE exploration_instance_state (
 snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
 event_id TEXT NOT NULL, generation INTEGER NOT NULL CHECK(generation>0),
 variant_id TEXT NOT NULL, variant_seed INTEGER NOT NULL CHECK(variant_seed>=0),
 phase TEXT NOT NULL CHECK(phase IN ('clue','surveyed','rescue','relic','mineral','extracting','ready','claimed','failed','withdrawn')),
 choice_id TEXT NOT NULL, operation_kind TEXT NOT NULL, operation_remaining_s REAL NOT NULL CHECK(operation_remaining_s>=0 AND operation_remaining_s<1e100),
 elapsed_s REAL NOT NULL CHECK(elapsed_s>=0 AND elapsed_s<1e100), cooldown_remaining_s REAL NOT NULL CHECK(cooldown_remaining_s>=0 AND cooldown_remaining_s<1e100),
 evidence_units INTEGER NOT NULL CHECK(evidence_units>=0), stabilized INTEGER NOT NULL CHECK(stabilized IN (0,1)),
 hazard_clock_s REAL NOT NULL CHECK(hazard_clock_s>=0 AND hazard_clock_s<1e100),
 outcome TEXT NOT NULL CHECK(outcome IN ('','full','partial','failed')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,event_id),
 UNIQUE(snapshot_id,world_id,content_snapshot_id,event_id,generation),
 FOREIGN KEY(content_snapshot_id,event_id) REFERENCES frozen_exploration_event_defs(content_snapshot_id,event_id),
 FOREIGN KEY(content_snapshot_id,variant_id,event_id) REFERENCES frozen_exploration_variant_defs(content_snapshot_id,variant_id,event_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER exploration_instance_state_insert_immutable BEFORE INSERT ON exploration_instance_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_instance_state_update_immutable BEFORE UPDATE ON exploration_instance_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_instance_state_delete_immutable BEFORE DELETE ON exploration_instance_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE exploration_actor_state (
 snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
 npc_instance_id TEXT NOT NULL,event_id TEXT NOT NULL,generation INTEGER NOT NULL,
 actor_role TEXT NOT NULL CHECK(actor_role IN ('escort','enemy')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,event_id,generation) REFERENCES exploration_instance_state(snapshot_id,world_id,content_snapshot_id,event_id,generation),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER exploration_actor_state_insert_immutable BEFORE INSERT ON exploration_actor_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_actor_state_update_immutable BEFORE UPDATE ON exploration_actor_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_actor_state_delete_immutable BEFORE DELETE ON exploration_actor_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE exploration_claim_state (
 snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
 player_id TEXT NOT NULL,event_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>0),variant_id TEXT NOT NULL,
 outcome TEXT NOT NULL CHECK(outcome IN ('full','partial')),
 credit_units INTEGER NOT NULL CHECK(credit_units>=0),insight_units INTEGER NOT NULL CHECK(insight_units>0),reputation_units INTEGER NOT NULL CHECK(reputation_units>=0),
 demand_id TEXT, demand_generation INTEGER NOT NULL CHECK(demand_generation>=0),claimed_tick INTEGER NOT NULL CHECK(claimed_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,event_id,generation),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,variant_id,event_id) REFERENCES frozen_exploration_variant_defs(content_snapshot_id,variant_id,event_id),
 FOREIGN KEY(content_snapshot_id,demand_id) REFERENCES frozen_station_demand_defs(content_snapshot_id,demand_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER exploration_claim_state_insert_immutable BEFORE INSERT ON exploration_claim_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_claim_state_update_immutable BEFORE UPDATE ON exploration_claim_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_claim_state_delete_immutable BEFORE DELETE ON exploration_claim_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE exploration_progress_state (
 snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
 player_id TEXT NOT NULL,insight_available INTEGER NOT NULL CHECK(insight_available>=0),insight_earned INTEGER NOT NULL CHECK(insight_earned>=insight_available),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER exploration_progress_state_insert_immutable BEFORE INSERT ON exploration_progress_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_progress_state_update_immutable BEFORE UPDATE ON exploration_progress_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_progress_state_delete_immutable BEFORE DELETE ON exploration_progress_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE exploration_research_state (
 snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,
 player_id TEXT NOT NULL,research_id TEXT NOT NULL,spent_insight INTEGER NOT NULL CHECK(spent_insight>0),paid_credit INTEGER NOT NULL CHECK(paid_credit>=0),completed_tick INTEGER NOT NULL CHECK(completed_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id,research_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,research_id) REFERENCES frozen_exploration_research_defs(content_snapshot_id,research_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER exploration_research_state_insert_immutable BEFORE INSERT ON exploration_research_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_research_state_update_immutable BEFORE UPDATE ON exploration_research_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER exploration_research_state_delete_immutable BEFORE DELETE ON exploration_research_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;


CREATE TRIGGER exploration_context_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM exploration_instance_state WHERE snapshot_id=NEW.snapshot_id)<>
 (SELECT count(*) FROM frozen_exploration_event_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'exploration instance coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_exploration_event_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (SELECT count(*) FROM exploration_progress_state WHERE snapshot_id=NEW.snapshot_id)<>1
 THEN RAISE(ABORT,'exploration progress coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_instance_state s JOIN frozen_exploration_event_defs e USING(content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v USING(content_snapshot_id,variant_id,event_id)
 JOIN frozen_exploration_balance_defs b USING(content_snapshot_id)
 WHERE s.snapshot_id=NEW.snapshot_id AND (s.cooldown_remaining_s>e.cooldown_s OR s.hazard_clock_s>=b.hazard_period_s OR
 s.operation_remaining_s>max(v.survey_duration_s,v.work_duration_s) OR
 s.operation_kind NOT IN ('','survey','rescue','recover','stabilize','deepen') OR
 (s.operation_kind='' AND s.operation_remaining_s<>0) OR
 (s.phase IN ('ready','claimed') AND s.outcome NOT IN ('full','partial')) OR
 (e.event_kind='relic' AND s.evidence_units>v.relic_layers)))
 THEN RAISE(ABORT,'exploration timer or evidence outside frozen limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_actor_state a JOIN npc_state n USING(snapshot_id,world_id,content_snapshot_id,npc_instance_id)
 WHERE a.snapshot_id=NEW.snapshot_id AND (n.generation<>a.generation OR NOT EXISTS(SELECT 1 FROM frozen_exploration_actor_defs d
 WHERE d.content_snapshot_id=a.content_snapshot_id AND d.event_id=a.event_id AND d.actor_role=a.actor_role AND d.spawn_id=n.spawn_id)))
 THEN RAISE(ABORT,'exploration actor identity mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_claim_state c JOIN exploration_instance_state s USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v ON v.content_snapshot_id=c.content_snapshot_id AND v.variant_id=c.variant_id AND v.event_id=c.event_id
 WHERE c.snapshot_id=NEW.snapshot_id AND (c.generation>s.generation OR c.claimed_tick>NEW.simulation_tick OR
 (c.generation=s.generation AND (c.variant_id<>s.variant_id OR s.phase<>'claimed' OR c.outcome<>s.outcome)) OR
 c.credit_units<>CASE WHEN c.outcome='full' THEN v.full_credit ELSE v.partial_credit END OR
 c.reputation_units<>CASE WHEN c.outcome='full' THEN v.reputation_units ELSE 0 END OR
 c.insight_units>v.insight_units OR (c.outcome='full' AND c.insight_units<>v.insight_units)))
 THEN RAISE(ABORT,'exploration reward exceeds frozen receipt limits') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_instance_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.phase='claimed' AND
 NOT EXISTS(SELECT 1 FROM exploration_claim_state c WHERE c.snapshot_id=s.snapshot_id AND c.event_id=s.event_id AND c.generation=s.generation))
 THEN RAISE(ABORT,'exploration result lacks claim receipt') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_progress_state p WHERE p.snapshot_id=NEW.snapshot_id AND (
 p.insight_earned<>coalesce((SELECT sum(c.insight_units) FROM exploration_claim_state c WHERE c.snapshot_id=p.snapshot_id AND c.player_id=p.player_id),0) OR
 p.insight_available<>p.insight_earned-coalesce((SELECT sum(r.spent_insight) FROM exploration_research_state r WHERE r.snapshot_id=p.snapshot_id AND r.player_id=p.player_id),0)))
 THEN RAISE(ABORT,'exploration insight ledger mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM exploration_research_state r JOIN frozen_exploration_research_defs d USING(content_snapshot_id,research_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.spent_insight<>d.required_insight OR r.paid_credit<>d.required_credit OR r.completed_tick>NEW.simulation_tick OR
 NOT EXISTS(SELECT 1 FROM unlock_state u WHERE u.snapshot_id=r.snapshot_id AND u.player_id=r.player_id AND u.unlock_id=d.reward_unlock_id)))
 THEN RAISE(ABORT,'exploration research payment or knowledge mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM resource_state r JOIN frozen_exploration_resource_defs d USING(content_snapshot_id,node_id)
 JOIN exploration_instance_state s USING(snapshot_id,world_id,content_snapshot_id,event_id)
 JOIN frozen_exploration_variant_defs v USING(content_snapshot_id,variant_id,event_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.respawn_remaining_s<>0 OR r.remaining_units>v.mineral_units OR
 ((s.phase<>'mineral' OR s.choice_id<>d.choice_id) AND r.remaining_units<>0)))
 THEN RAISE(ABORT,'inactive exploration mineral regenerated') END;
END;
CREATE TABLE database_meta_format12 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=12)
) STRICT;
INSERT INTO database_meta_format12 SELECT singleton,application_id,12 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format12 RENAME TO database_meta;
PRAGMA user_version=12;
