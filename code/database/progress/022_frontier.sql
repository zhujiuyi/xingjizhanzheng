-- Reviewed frontier stages, governance and durable territory history.

CREATE TABLE frozen_frontier_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    material_id TEXT NOT NULL,
    supply_units INTEGER NOT NULL CHECK(supply_units>0),
    rebuild_units INTEGER NOT NULL CHECK(rebuild_units>0),
    survey_s REAL NOT NULL CHECK(survey_s>0),
    survey_energy_eu REAL NOT NULL CHECK(survey_energy_eu>0),
    survey_heat_hu REAL NOT NULL CHECK(survey_heat_hu>=0),
    survey_radius_m REAL NOT NULL CHECK(survey_radius_m>0),
    escort_radius_m REAL NOT NULL CHECK(escort_radius_m>0),
    arrival_radius_m REAL NOT NULL CHECK(arrival_radius_m>0),
    hold_s REAL NOT NULL CHECK(hold_s>0),
    rebuild_s REAL NOT NULL CHECK(rebuild_s>0),
    repair_radius_m REAL NOT NULL CHECK(repair_radius_m>0),
    warning_s REAL NOT NULL CHECK(warning_s>0),
    defense_s REAL NOT NULL CHECK(defense_s>0),
    crisis_min_s REAL NOT NULL CHECK(crisis_min_s>warning_s),
    crisis_max_s REAL NOT NULL CHECK(crisis_max_s>=crisis_min_s),
    reserve_max_units INTEGER NOT NULL CHECK(reserve_max_units>0),
    crisis_supply_base_units INTEGER NOT NULL CHECK(crisis_supply_base_units>0),
    crisis_supply_per_extra_territory INTEGER NOT NULL CHECK(crisis_supply_per_extra_territory>=0),
    dispatch_s REAL NOT NULL CHECK(dispatch_s>0),
    dispatch_fee_credit INTEGER NOT NULL CHECK(dispatch_fee_credit>=0),
    max_supply_orders INTEGER NOT NULL CHECK(max_supply_orders>0),
    repair_fee_ratio REAL NOT NULL CHECK(repair_fee_ratio>0 AND repair_fee_ratio<=1),
    industry_fee_ratio REAL NOT NULL CHECK(industry_fee_ratio>0 AND industry_fee_ratio<=1),
    recapture_credit INTEGER NOT NULL CHECK(recapture_credit>=0),
    recapture_reputation INTEGER NOT NULL CHECK(recapture_reputation>=0),
    defense_credit INTEGER NOT NULL CHECK(defense_credit>=0),
    defense_reputation INTEGER NOT NULL CHECK(defense_reputation>=0),
    hostile_detection_ratio REAL NOT NULL CHECK(hostile_detection_ratio>0 AND hostile_detection_ratio<=1),
    restock_rate REAL NOT NULL CHECK(restock_rate>=1),
    PRIMARY KEY (content_snapshot_id, singleton),
    FOREIGN KEY (content_snapshot_id, material_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_frontier_balance_defs_insert_guard BEFORE INSERT ON frozen_frontier_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_balance_defs_update_guard BEFORE UPDATE ON frozen_frontier_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_balance_defs_delete_guard BEFORE DELETE ON frozen_frontier_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_frontier_campaign_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    war_id TEXT NOT NULL,
    scout_anchor_id TEXT NOT NULL,
    convoy_start_anchor_id TEXT NOT NULL,
    convoy_exit_anchor_id TEXT NOT NULL,
    battle_kind TEXT NOT NULL CHECK(battle_kind IN ('hold','demolition')),
    convoy_spawn_id TEXT NOT NULL,
    structure_count INTEGER NOT NULL CHECK(structure_count IN (0,2)),
    CHECK((battle_kind='hold' AND structure_count=0) OR (battle_kind='demolition' AND structure_count=2)),
    PRIMARY KEY (content_snapshot_id, war_id),
    FOREIGN KEY (content_snapshot_id, war_id) REFERENCES frozen_civilization_war_defs (content_snapshot_id, war_id),
    FOREIGN KEY (content_snapshot_id, scout_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, convoy_start_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, convoy_exit_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, convoy_spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    UNIQUE (content_snapshot_id, convoy_spawn_id)
) STRICT;
CREATE TRIGGER frozen_frontier_campaign_defs_insert_guard BEFORE INSERT ON frozen_frontier_campaign_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_campaign_defs_update_guard BEFORE UPDATE ON frozen_frontier_campaign_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_campaign_defs_delete_guard BEFORE DELETE ON frozen_frontier_campaign_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_frontier_actor_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    spawn_id TEXT NOT NULL,
    war_id TEXT,
    sector_id TEXT NOT NULL,
    actor_role TEXT NOT NULL CHECK(actor_role IN ('convoy','ambusher','structure','raider')),
    slot_index INTEGER NOT NULL CHECK(slot_index>=0),
    hull_id TEXT,
    CHECK((actor_role='raider' AND war_id IS NULL) OR (actor_role<>'raider' AND war_id IS NOT NULL)),
    CHECK((actor_role='convoy' AND hull_id IS NOT NULL) OR (actor_role<>'convoy' AND hull_id IS NULL)),
    PRIMARY KEY (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, war_id) REFERENCES frozen_frontier_campaign_defs (content_snapshot_id, war_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, hull_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_frontier_actor_defs_insert_guard BEFORE INSERT ON frozen_frontier_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_actor_defs_update_guard BEFORE UPDATE ON frozen_frontier_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_actor_defs_delete_guard BEFORE DELETE ON frozen_frontier_actor_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_frontier_governance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    sector_id TEXT NOT NULL,
    station_id TEXT NOT NULL,
    defense_anchor_id TEXT NOT NULL,
    beacon_spawn_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_sovereignty_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    UNIQUE (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, defense_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, beacon_spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    UNIQUE (content_snapshot_id, beacon_spawn_id)
) STRICT;
CREATE TRIGGER frozen_frontier_governance_defs_insert_guard BEFORE INSERT ON frozen_frontier_governance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_governance_defs_update_guard BEFORE UPDATE ON frozen_frontier_governance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_governance_defs_delete_guard BEFORE DELETE ON frozen_frontier_governance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_frontier_beacon_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    spawn_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    hull_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_frontier_governance_defs (content_snapshot_id, sector_id),
    UNIQUE (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, hull_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_frontier_beacon_defs_insert_guard BEFORE INSERT ON frozen_frontier_beacon_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_beacon_defs_update_guard BEFORE UPDATE ON frozen_frontier_beacon_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_frontier_beacon_defs_delete_guard BEFORE DELETE ON frozen_frontier_beacon_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frontier_campaign_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,war_id TEXT NOT NULL,attempt INTEGER NOT NULL DEFAULT 0 CHECK(attempt>=0),
 phase TEXT NOT NULL DEFAULT 'idle' CHECK(phase IN ('idle','legacy','scouting','escorting','hold','demolition','rebuilding','completed','failed','cancelled')),
 legacy_attempt INTEGER NOT NULL DEFAULT 0 CHECK(legacy_attempt>=0),survey_paid INTEGER NOT NULL DEFAULT 0 CHECK(survey_paid IN(0,1)),survey_remaining_s REAL NOT NULL DEFAULT 0 CHECK(survey_remaining_s>=0),
 supplies_paid_units INTEGER NOT NULL DEFAULT 0 CHECK(supplies_paid_units>=0),supply_delivered INTEGER NOT NULL DEFAULT 0 CHECK(supply_delivered IN(0,1)),
 repair_paid_units INTEGER NOT NULL DEFAULT 0 CHECK(repair_paid_units>=0),repair_remaining_s REAL NOT NULL DEFAULT 0 CHECK(repair_remaining_s>=0),
 hold_remaining_s REAL NOT NULL DEFAULT 0 CHECK(hold_remaining_s>=0),demolition_units INTEGER NOT NULL DEFAULT 0 CHECK(demolition_units>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,war_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_frontier_campaign_defs(content_snapshot_id,war_id)) STRICT;

CREATE TRIGGER frontier_campaign_state_insert_immutable BEFORE INSERT ON frontier_campaign_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_campaign_state_update_immutable BEFORE UPDATE ON frontier_campaign_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_campaign_state_delete_immutable BEFORE DELETE ON frontier_campaign_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE frontier_actor_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,npc_instance_id TEXT NOT NULL,war_id TEXT,sector_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>0),
 actor_role TEXT NOT NULL CHECK(actor_role IN ('convoy','ambusher','structure','raider','beacon')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_frontier_campaign_defs(content_snapshot_id,war_id),
 FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id)) STRICT;

CREATE TRIGGER frontier_actor_state_insert_immutable BEFORE INSERT ON frontier_actor_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_actor_state_update_immutable BEFORE UPDATE ON frontier_actor_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_actor_state_delete_immutable BEFORE DELETE ON frontier_actor_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE frontier_campaign_receipt_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,source_token TEXT NOT NULL,war_id TEXT NOT NULL,attempt INTEGER NOT NULL CHECK(attempt>0),
 event_kind TEXT NOT NULL CHECK(event_kind IN ('register','survey','supply','structure','hold','repair','capture','failed','cancelled')),
 units INTEGER NOT NULL DEFAULT 0 CHECK(units>=0),material_units INTEGER NOT NULL DEFAULT 0 CHECK(material_units>=0),
 reward_credit INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit>=0),reward_reputation INTEGER NOT NULL DEFAULT 0 CHECK(reward_reputation>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,source_token),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_frontier_campaign_defs(content_snapshot_id,war_id)) STRICT;

CREATE TRIGGER frontier_campaign_receipt_state_insert_immutable BEFORE INSERT ON frontier_campaign_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_campaign_receipt_state_update_immutable BEFORE UPDATE ON frontier_campaign_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_campaign_receipt_state_delete_immutable BEFORE DELETE ON frontier_campaign_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE frontier_territory_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,sector_id TEXT NOT NULL,phase TEXT NOT NULL DEFAULT 'neutral' CHECK(phase IN ('neutral','controlled','warning','defending')),
 revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),reserve_units INTEGER NOT NULL DEFAULT 0 CHECK(reserve_units>=0),crisis_generation INTEGER NOT NULL DEFAULT 0 CHECK(crisis_generation>=0),
 warning_remaining_s REAL NOT NULL DEFAULT 0 CHECK(warning_remaining_s>=0),defense_remaining_s REAL NOT NULL DEFAULT 0 CHECK(defense_remaining_s>=0),hold_remaining_s REAL NOT NULL DEFAULT 0 CHECK(hold_remaining_s>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,sector_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id)) STRICT;

CREATE TRIGGER frontier_territory_state_insert_immutable BEFORE INSERT ON frontier_territory_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_territory_state_update_immutable BEFORE UPDATE ON frontier_territory_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_territory_state_delete_immutable BEFORE DELETE ON frontier_territory_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE frontier_journal_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,source_token TEXT NOT NULL,sector_id TEXT NOT NULL,revision INTEGER NOT NULL CHECK(revision>=0),
 event_kind TEXT NOT NULL CHECK(event_kind IN ('capture','import','loss','warning','defense','supply')),faction_id TEXT,war_id TEXT,attempt INTEGER NOT NULL DEFAULT 0 CHECK(attempt>=0),
 crisis_generation INTEGER NOT NULL DEFAULT 0 CHECK(crisis_generation>=0),supply_order_id TEXT,units INTEGER NOT NULL DEFAULT 0 CHECK(units>=0),
 reward_credit INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit>=0),reward_reputation INTEGER NOT NULL DEFAULT 0 CHECK(reward_reputation>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,source_token),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id),
 FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_civilization_war_defs(content_snapshot_id,war_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,supply_order_id) REFERENCES frontier_supply_order_state(snapshot_id,world_id,content_snapshot_id,order_id)) STRICT;

CREATE TRIGGER frontier_journal_state_insert_immutable BEFORE INSERT ON frontier_journal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_journal_state_update_immutable BEFORE UPDATE ON frontier_journal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_journal_state_delete_immutable BEFORE DELETE ON frontier_journal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE frontier_supply_order_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,order_id TEXT NOT NULL,sector_id TEXT NOT NULL,faction_id TEXT NOT NULL,units INTEGER NOT NULL CHECK(units>0),paid_credit INTEGER NOT NULL CHECK(paid_credit>=0),
 phase TEXT NOT NULL DEFAULT 'inflight' CHECK(phase IN ('inflight','delivered','lost')),remaining_s REAL NOT NULL CHECK(remaining_s>=0),created_tick INTEGER NOT NULL CHECK(created_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,order_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id)) STRICT;

CREATE TRIGGER frontier_supply_order_state_insert_immutable BEFORE INSERT ON frontier_supply_order_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_supply_order_state_update_immutable BEFORE UPDATE ON frontier_supply_order_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_supply_order_state_delete_immutable BEFORE DELETE ON frontier_supply_order_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE frontier_director_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,player_id TEXT NOT NULL,next_event_s REAL NOT NULL CHECK(next_event_s>=0),active_sector_id TEXT,active_faction_id TEXT,
 CHECK((active_sector_id IS NULL)=(active_faction_id IS NULL)),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,active_sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,active_faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id)) STRICT;

CREATE TRIGGER frontier_director_state_insert_immutable BEFORE INSERT ON frontier_director_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_director_state_update_immutable BEFORE UPDATE ON frontier_director_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER frontier_director_state_delete_immutable BEFORE DELETE ON frontier_director_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE UNIQUE INDEX frontier_ownership_revision ON frontier_journal_state(snapshot_id,world_id,content_snapshot_id,sector_id,revision) WHERE event_kind IN ('capture','import','loss');

CREATE UNIQUE INDEX frontier_defense_once ON frontier_journal_state(snapshot_id,world_id,content_snapshot_id,sector_id,crisis_generation) WHERE event_kind='defense';

CREATE UNIQUE INDEX frontier_campaign_register_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='register';

CREATE UNIQUE INDEX frontier_campaign_survey_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='survey';

CREATE UNIQUE INDEX frontier_campaign_supply_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='supply';

CREATE UNIQUE INDEX frontier_campaign_hold_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='hold';

CREATE UNIQUE INDEX frontier_campaign_repair_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='repair';

CREATE UNIQUE INDEX frontier_campaign_capture_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='capture';

CREATE UNIQUE INDEX frontier_campaign_failed_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='failed';

CREATE UNIQUE INDEX frontier_campaign_cancelled_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='cancelled';

CREATE TRIGGER frontier_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM frontier_campaign_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_frontier_campaign_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM frontier_territory_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_frontier_governance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM frontier_director_state WHERE snapshot_id=NEW.snapshot_id)<>CASE WHEN EXISTS(SELECT 1 FROM frozen_frontier_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN 1 ELSE 0 END
 THEN RAISE(ABORT,'frontier authority coverage incomplete') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM frozen_frontier_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (EXISTS(SELECT 1 FROM frontier_actor_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM frontier_campaign_receipt_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM frontier_journal_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM frontier_supply_order_state WHERE snapshot_id=NEW.snapshot_id)) THEN RAISE(ABORT,'frontier state under legacy rules') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_territory_state f JOIN territory_state t USING(snapshot_id,world_id,content_snapshot_id,sector_id)
 JOIN frozen_frontier_balance_defs b USING(content_snapshot_id) WHERE f.snapshot_id=NEW.snapshot_id AND
 ((f.phase='neutral')<>(t.faction_id IS NULL) OR f.reserve_units>b.reserve_max_units OR f.warning_remaining_s>b.warning_s OR f.defense_remaining_s>b.defense_s OR f.hold_remaining_s>b.hold_s OR
 (f.phase='neutral' AND (f.reserve_units<>0 OR f.warning_remaining_s<>0 OR f.defense_remaining_s<>0 OR f.hold_remaining_s<>0)))) THEN RAISE(ABORT,'invalid frontier governance phase or reserve') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_territory_state f JOIN territory_state t USING(snapshot_id,world_id,content_snapshot_id,sector_id) WHERE f.snapshot_id=NEW.snapshot_id AND
 (f.revision<>(SELECT count(*) FROM frontier_journal_state j WHERE j.snapshot_id=f.snapshot_id AND j.sector_id=f.sector_id AND j.event_kind IN ('capture','import','loss')) OR
 (f.revision>0 AND NOT EXISTS(SELECT 1 FROM frontier_journal_state j WHERE j.snapshot_id=f.snapshot_id AND j.sector_id=f.sector_id AND j.revision=f.revision AND j.event_kind IN ('capture','import','loss') AND j.faction_id IS t.faction_id)) OR
 (f.revision=0 AND t.faction_id IS NOT NULL))) THEN RAISE(ABORT,'frontier ownership requires its complete revision journal') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state j WHERE j.snapshot_id=NEW.snapshot_id AND
 (j.event_tick>NEW.simulation_tick OR
 (j.event_kind IN ('capture','import','loss') AND (j.revision<1 OR j.revision>(SELECT f.revision FROM frontier_territory_state f WHERE f.snapshot_id=j.snapshot_id AND f.sector_id=j.sector_id))) OR
 (j.event_kind IN ('capture','import') AND (j.faction_id IS NULL OR j.war_id IS NULL OR j.attempt<1 OR NOT EXISTS(SELECT 1 FROM frozen_civilization_war_defs w WHERE w.content_snapshot_id=j.content_snapshot_id AND w.war_id=j.war_id AND w.target_sector_id=j.sector_id AND w.faction_id=j.faction_id))) OR
 (j.event_kind='loss' AND (j.faction_id IS NOT NULL OR j.crisis_generation<1)) OR
 (j.event_kind='import' AND (j.reward_credit<>0 OR j.reward_reputation<>0)))) THEN RAISE(ABORT,'invalid frontier ownership event or imported reward') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_actor_state a JOIN npc_state n USING(snapshot_id,world_id,content_snapshot_id,npc_instance_id) WHERE a.snapshot_id=NEW.snapshot_id AND
 (a.generation<>n.generation OR a.sector_id<>n.sector_id OR
 NOT(EXISTS(SELECT 1 FROM frozen_frontier_actor_defs d WHERE d.content_snapshot_id=a.content_snapshot_id AND d.spawn_id=n.spawn_id AND d.war_id IS a.war_id AND d.sector_id=a.sector_id AND d.actor_role=a.actor_role) OR
 (a.actor_role='beacon' AND a.war_id IS NULL AND EXISTS(SELECT 1 FROM frozen_frontier_beacon_defs d WHERE d.content_snapshot_id=a.content_snapshot_id AND d.spawn_id=n.spawn_id AND d.sector_id=a.sector_id))))) THEN RAISE(ABORT,'invalid frontier actor binding') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_campaign_state f JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
 WHERE f.snapshot_id=NEW.snapshot_id AND (f.survey_remaining_s>b.survey_s OR f.repair_remaining_s>b.rebuild_s OR f.hold_remaining_s>b.hold_s OR f.demolition_units>2 OR
 f.supplies_paid_units<>COALESCE((SELECT sum(r.material_units) FROM frontier_campaign_receipt_state r WHERE r.snapshot_id=f.snapshot_id AND r.war_id=f.war_id AND r.attempt=f.attempt AND r.event_kind='register'),0) OR
 f.repair_paid_units<>COALESCE((SELECT sum(r.material_units) FROM frontier_campaign_receipt_state r WHERE r.snapshot_id=f.snapshot_id AND r.war_id=f.war_id AND r.attempt=f.attempt AND r.event_kind='repair'),0))) THEN RAISE(ABORT,'frontier paid work or material conservation failed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_campaign_receipt_state r JOIN frozen_frontier_balance_defs b USING(content_snapshot_id) WHERE r.snapshot_id=NEW.snapshot_id AND
 (r.event_tick>NEW.simulation_tick OR (r.event_kind='register' AND r.material_units<>b.supply_units) OR (r.event_kind='repair' AND r.material_units<>b.rebuild_units))) THEN RAISE(ABORT,'invalid frontier material payment') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_supply_order_state o JOIN frozen_frontier_balance_defs b USING(content_snapshot_id) WHERE o.snapshot_id=NEW.snapshot_id AND
 (o.paid_credit<>b.dispatch_fee_credit OR o.units>b.reserve_max_units OR o.remaining_s>b.dispatch_s OR o.created_tick>NEW.simulation_tick OR o.finished_tick>NEW.simulation_tick OR
 (o.phase='inflight' AND o.finished_tick<>0) OR (o.phase<>'inflight' AND o.remaining_s<>0))) THEN RAISE(ABORT,'invalid paid strategic supply order') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state j JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
 LEFT JOIN frozen_civilization_war_defs w ON w.content_snapshot_id=j.content_snapshot_id AND w.war_id=j.war_id
 WHERE j.snapshot_id=NEW.snapshot_id AND (
 (j.event_kind='capture' AND (j.reward_credit<>CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state prior WHERE prior.snapshot_id=j.snapshot_id AND prior.sector_id=j.sector_id AND prior.faction_id=j.faction_id AND prior.event_kind IN ('capture','import') AND prior.revision<j.revision) THEN b.recapture_credit ELSE w.reward_credit END OR
 j.reward_reputation<>CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state prior WHERE prior.snapshot_id=j.snapshot_id AND prior.sector_id=j.sector_id AND prior.faction_id=j.faction_id AND prior.event_kind IN ('capture','import') AND prior.revision<j.revision) THEN b.recapture_reputation ELSE w.reward_reputation END)) OR
 (j.event_kind='defense' AND (j.reward_credit<>CASE WHEN j.units=0 THEN b.defense_credit ELSE 0 END OR j.reward_reputation<>CASE WHEN j.units=0 THEN b.defense_reputation ELSE 0 END)) OR
 (j.event_kind NOT IN ('capture','defense') AND (j.reward_credit<>0 OR j.reward_reputation<>0)))) THEN RAISE(ABORT,'frontier reward exceeds the real event entitlement') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_campaign_receipt_state r WHERE r.snapshot_id=NEW.snapshot_id AND
 ((r.event_kind<>'capture' AND (r.reward_credit<>0 OR r.reward_reputation<>0)) OR
 (r.event_kind='capture' AND NOT EXISTS(SELECT 1 FROM frontier_journal_state j WHERE j.snapshot_id=r.snapshot_id AND j.war_id=r.war_id AND j.attempt=r.attempt AND j.event_kind='capture' AND j.reward_credit=r.reward_credit AND j.reward_reputation=r.reward_reputation)))) THEN RAISE(ABORT,'frontier campaign reward lacks matching ownership history') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state j LEFT JOIN frontier_supply_order_state o ON o.snapshot_id=j.snapshot_id AND o.order_id=j.supply_order_id
 WHERE j.snapshot_id=NEW.snapshot_id AND j.supply_order_id IS NOT NULL AND (j.event_kind<>'supply' OR o.phase<>'delivered' OR o.sector_id<>j.sector_id OR o.faction_id IS NOT j.faction_id OR j.units>o.units)) THEN RAISE(ABORT,'frontier resupply receipt lacks a delivered order') END;
 SELECT CASE WHEN (SELECT count(*) FROM frontier_territory_state WHERE snapshot_id=NEW.snapshot_id AND phase IN ('warning','defending'))<>(SELECT count(*) FROM frontier_director_state WHERE snapshot_id=NEW.snapshot_id AND active_sector_id IS NOT NULL) OR
 EXISTS(SELECT 1 FROM frontier_director_state d LEFT JOIN frontier_territory_state f ON f.snapshot_id=d.snapshot_id AND f.sector_id=d.active_sector_id LEFT JOIN territory_state t ON t.snapshot_id=d.snapshot_id AND t.sector_id=d.active_sector_id
 WHERE d.snapshot_id=NEW.snapshot_id AND d.active_sector_id IS NOT NULL AND (f.phase NOT IN ('warning','defending') OR t.faction_id IS NOT d.active_faction_id)) THEN RAISE(ABORT,'frontier crisis director mismatch') END;
END;

DROP TRIGGER civilization_context_seal_validation;
CREATE TRIGGER civilization_context_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_civilization_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND (
  (SELECT count(*) FROM civilization_state WHERE snapshot_id=NEW.snapshot_id)<>1 OR
  (SELECT count(*) FROM territory_state WHERE snapshot_id=NEW.snapshot_id)<>
   (SELECT count(*) FROM frozen_sector_sovereignty_defs WHERE content_snapshot_id=NEW.content_snapshot_id))
 THEN RAISE(ABORT,'civilization authority coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM territory_state t JOIN frozen_sector_sovereignty_defs p USING(content_snapshot_id,sector_id)
  WHERE t.snapshot_id=NEW.snapshot_id AND p.conquerable=0 AND t.faction_id IS NOT p.initial_faction_id)
 THEN RAISE(ABORT,'protected territory ownership changed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM territory_state t JOIN frozen_sector_sovereignty_defs p USING(content_snapshot_id,sector_id)
  WHERE t.snapshot_id=NEW.snapshot_id AND p.initial_faction_id IS NULL AND t.faction_id IS NOT NULL
  AND NOT EXISTS(SELECT 1 FROM war_campaign_state w JOIN frozen_civilization_war_defs d USING(content_snapshot_id,war_id)
   WHERE w.snapshot_id=t.snapshot_id AND w.status='won' AND d.target_sector_id=t.sector_id AND d.faction_id=t.faction_id))
 THEN RAISE(ABORT,'territory capture lacks a completed war') END;
 SELECT CASE WHEN (SELECT count(*) FROM war_campaign_state WHERE snapshot_id=NEW.snapshot_id AND status IN ('assembling','fighting','occupying'))>1
 THEN RAISE(ABORT,'multiple active wars') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_campaign_state w
  JOIN frozen_civilization_war_defs d USING(content_snapshot_id,war_id)
  JOIN civilization_state c ON c.snapshot_id=w.snapshot_id AND c.player_id=w.player_id
  JOIN territory_state t ON t.snapshot_id=w.snapshot_id AND t.sector_id=d.target_sector_id
  WHERE w.snapshot_id=NEW.snapshot_id AND (w.capture_remaining_s>d.capture_duration_s OR
   (w.status IN ('assembling','fighting','occupying') AND (c.faction_id IS NOT d.faction_id OR t.faction_id IS NOT NULL)) OR
   (w.status='won' AND t.faction_id IS NOT d.faction_id AND NOT EXISTS(SELECT 1 FROM frontier_journal_state j JOIN frontier_territory_state f ON f.snapshot_id=j.snapshot_id AND f.sector_id=j.sector_id WHERE j.snapshot_id=w.snapshot_id AND j.war_id=w.war_id AND j.attempt=w.attempt AND j.event_kind IN ('capture','import') AND f.revision>j.revision))))
 THEN RAISE(ABORT,'invalid war allegiance target or occupation') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_campaign_state w JOIN frozen_civilization_war_defs d USING(content_snapshot_id,war_id)
  JOIN frozen_civilization_rank_defs r ON r.content_snapshot_id=d.content_snapshot_id AND r.faction_id=d.faction_id AND r.rank_level=d.required_rank
  LEFT JOIN reputation_state p ON p.snapshot_id=w.snapshot_id AND p.player_id=w.player_id AND p.faction_id=d.faction_id
  WHERE w.snapshot_id=NEW.snapshot_id AND w.status IN ('assembling','fighting','occupying') AND coalesce(p.reputation,0)<r.required_reputation)
 THEN RAISE(ABORT,'war reputation rank insufficient') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_fleet_state f
  JOIN npc_state n ON n.snapshot_id=f.snapshot_id AND n.npc_instance_id=f.npc_instance_id
  WHERE f.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM frozen_civilization_war_members m
   WHERE m.content_snapshot_id=f.content_snapshot_id AND m.war_id=f.war_id AND m.spawn_id=n.spawn_id AND m.side=f.side))
 THEN RAISE(ABORT,'invalid war fleet identity') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM war_campaign_state w WHERE w.snapshot_id=NEW.snapshot_id
  AND w.status IN ('assembling','fighting','occupying') AND
   (SELECT count(*) FROM war_fleet_state f WHERE f.snapshot_id=w.snapshot_id AND f.war_id=w.war_id)<>
   (SELECT count(*) FROM frozen_civilization_war_members m WHERE m.content_snapshot_id=w.content_snapshot_id AND m.war_id=w.war_id))
 THEN RAISE(ABORT,'incomplete active war fleet') END;
END;

DROP TRIGGER role_seal_validation;
CREATE TRIGGER role_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM consignment_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_consignment_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN RAISE(ABORT,'consignment coverage incomplete') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM frozen_role_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (EXISTS(SELECT 1 FROM remote_support_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM consignment_receipt_state WHERE snapshot_id=NEW.snapshot_id)) THEN RAISE(ABORT,'role state under legacy definitions') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM remote_support_state r
 JOIN ship_state s ON s.snapshot_id=r.snapshot_id AND s.ship_instance_id=r.ship_instance_id
 JOIN frozen_ship_role_capability_defs c ON c.content_snapshot_id=r.content_snapshot_id AND c.ship_id=s.ship_def_id
 JOIN item_instance_state i ON i.snapshot_id=r.snapshot_id AND i.item_instance_id=r.item_instance_id
 LEFT JOIN equipment_state e ON e.snapshot_id=r.snapshot_id AND e.item_instance_id=r.item_instance_id
 LEFT JOIN frozen_repair_defs d ON d.content_snapshot_id=r.content_snapshot_id AND d.module_id=e.module_def_id
 LEFT JOIN frozen_module_defs m ON m.content_snapshot_id=r.content_snapshot_id AND m.module_id=e.module_def_id
 JOIN npc_state n ON n.snapshot_id=r.snapshot_id AND n.npc_instance_id=r.target_npc_id
 WHERE r.snapshot_id=NEW.snapshot_id AND
 (c.remote_repair_allowed<>1 OR s.policy_id<>'normal_owned' OR i.policy_id<>'normal_owned' OR s.status<>'flying' OR
 s.ship_instance_id<>(SELECT controlled_ship_id FROM player_state WHERE snapshot_id=r.snapshot_id) OR
 i.durability<=0 OR e.item_instance_id IS NULL OR e.enabled<>1 OR d.module_id IS NULL OR r.layer_id<>d.layer_id OR
 NOT EXISTS(SELECT 1 FROM container_state x WHERE x.snapshot_id=r.snapshot_id AND x.container_id=e.slot_container_id AND x.ship_instance_id=s.ship_instance_id) OR
 n.alive<>1 OR n.generation<>r.target_generation OR
 NOT (EXISTS(SELECT 1 FROM exploration_actor_state a WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND a.actor_role='escort') OR EXISTS(SELECT 1 FROM war_fleet_state f WHERE f.snapshot_id=r.snapshot_id AND f.npc_instance_id=r.target_npc_id AND f.side='ally') OR EXISTS(SELECT 1 FROM frontier_actor_state a JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
 JOIN civilization_state identity ON identity.snapshot_id=a.snapshot_id
 LEFT JOIN war_campaign_state w ON w.snapshot_id=a.snapshot_id AND w.war_id=a.war_id
 LEFT JOIN frozen_civilization_war_defs d ON d.content_snapshot_id=a.content_snapshot_id AND d.war_id=a.war_id
 LEFT JOIN frontier_territory_state f ON f.snapshot_id=a.snapshot_id AND f.sector_id=a.sector_id
 LEFT JOIN territory_state t ON t.snapshot_id=a.snapshot_id AND t.sector_id=a.sector_id
 WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND
 ((a.actor_role='convoy' AND w.status IN ('assembling','fighting','occupying') AND w.attempt=a.generation AND identity.faction_id IS d.faction_id) OR
 (a.actor_role='beacon' AND a.war_id IS NULL AND f.phase='defending' AND f.crisis_generation=a.generation AND identity.faction_id IS t.faction_id)))) OR
 (r.phase='armed' AND (r.remaining_s<>0 OR r.paid_restore<>0)) OR
 (r.phase='cycling' AND (r.remaining_s<=0 OR r.remaining_s>m.cycle_s+0.000001 OR e.cycle_paid<>1 OR
 abs(e.active_remaining_s-r.remaining_s)>0.000001 OR abs(r.paid_restore-d.restore_amount*i.quality_multiplier*(CASE r.layer_id WHEN 'shield' THEN c.remote_shield_multiplier ELSE c.remote_armor_multiplier END))>0.000001)))) THEN RAISE(ABORT,'remote support binding or paid cycle invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM consignment_state s JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) JOIN frozen_role_balance_defs b USING(content_snapshot_id) WHERE s.snapshot_id=NEW.snapshot_id AND
 (s.accepted_units>d.max_units OR s.accepted_units<>s.cargo_units+s.delivered_units+s.lost_units+s.returned_units OR
 s.remaining_s>d.deadline_s OR s.cooldown_remaining_s>d.cooldown_s OR s.exposure_remaining_s>b.freight_exposure_s OR s.damage_debt_hp>=b.freight_loss_damage_hp OR
 (s.phase='idle' AND (s.accepted_units<>0 OR s.payload_ship_id IS NOT NULL OR s.remaining_s<>0 OR s.cooldown_remaining_s<>0)) OR
 (s.phase='active' AND (s.cargo_units<=0 OR s.payload_ship_id IS NULL OR s.remaining_s<=0 OR s.cooldown_remaining_s<>0 OR NOT EXISTS(SELECT 1 FROM ship_state h JOIN player_state p USING(snapshot_id,world_id,content_snapshot_id) WHERE h.snapshot_id=s.snapshot_id AND h.ship_instance_id=s.payload_ship_id AND h.owner_player_id=p.player_id AND h.policy_id='normal_owned' AND h.status IN ('flying','docked')))) OR
 (s.phase IN ('ready','claimed') AND (s.accepted_units<=0 OR s.cargo_units<>0 OR s.payload_ship_id IS NOT NULL OR s.remaining_s<>0 OR s.exposure_remaining_s<>0 OR s.damage_debt_hp<>0)) OR
 (s.phase<>'claimed' AND s.cooldown_remaining_s<>0) OR
 (s.exposure_remaining_s=0 AND s.damage_debt_hp<>0) OR
 (s.phase='claimed')<>EXISTS(SELECT 1 FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='claim'))) THEN RAISE(ABORT,'consignment phase or cargo invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM consignment_receipt_state r JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) JOIN consignment_state s USING(snapshot_id,world_id,content_snapshot_id,contract_id) WHERE r.snapshot_id=NEW.snapshot_id AND
 (r.generation>s.generation OR (r.action_kind<>'claim' AND r.units<=0) OR
 (r.action_kind='dispatch' AND (r.units>d.max_units OR r.paid_credit<>d.fee_credit+r.units*d.deposit_per_unit OR r.refunded_credit<>0 OR r.reward_credit<>0)) OR
 (r.action_kind IN ('deliver','loss','return') AND (r.paid_credit<>0 OR r.refunded_credit<>0 OR r.reward_credit<>0)) OR
 (r.action_kind='claim' AND (r.paid_credit<>0 OR
 r.units<>COALESCE((SELECT sum(x.units) FROM consignment_receipt_state x WHERE x.snapshot_id=r.snapshot_id AND x.contract_id=r.contract_id AND x.generation=r.generation AND x.action_kind='deliver'),0) OR
 r.reward_credit<>r.units*d.reward_per_unit OR
 r.refunded_credit<>d.deposit_per_unit*COALESCE((SELECT sum(x.units) FROM consignment_receipt_state x WHERE x.snapshot_id=r.snapshot_id AND x.contract_id=r.contract_id AND x.generation=r.generation AND x.action_kind IN ('deliver','return')),0))))) THEN RAISE(ABORT,'consignment receipt payment invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM consignment_state s WHERE s.snapshot_id=NEW.snapshot_id AND
 (s.accepted_units<>COALESCE((SELECT sum(r.units) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='dispatch'),0) OR
 s.delivered_units<>COALESCE((SELECT sum(r.units) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='deliver'),0) OR
 s.lost_units<>COALESCE((SELECT sum(r.units) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='loss'),0) OR
 s.returned_units<>COALESCE((SELECT sum(r.units) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id AND r.generation=s.generation AND r.action_kind='return'),0) OR
 s.paid_credit_total<>COALESCE((SELECT sum(r.paid_credit) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id),0) OR
 s.refunded_credit_total<>COALESCE((SELECT sum(r.refunded_credit) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id),0) OR
 s.reward_credit_total<>COALESCE((SELECT sum(r.reward_credit) FROM consignment_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.contract_id=s.contract_id),0))) THEN RAISE(ABORT,'consignment ledger conservation failed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM consignment_receipt_state r JOIN consignment_state s USING(snapshot_id,world_id,content_snapshot_id,contract_id) WHERE r.snapshot_id=NEW.snapshot_id AND r.generation<s.generation GROUP BY r.contract_id,r.generation HAVING
 sum(CASE WHEN r.action_kind='dispatch' THEN r.units ELSE 0 END)<>sum(CASE WHEN r.action_kind IN ('deliver','loss','return') THEN r.units ELSE 0 END) OR sum(r.action_kind='claim')<>1) THEN RAISE(ABORT,'past consignment round incomplete') END;
END;

CREATE TABLE database_meta_format19(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=19)) STRICT;
INSERT INTO database_meta_format19 SELECT singleton,application_id,19 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format19 RENAME TO database_meta;
PRAGMA user_version=19;
