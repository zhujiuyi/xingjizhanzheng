-- Durable offline expeditions, construction and measured outing summaries.

CREATE TABLE frozen_campaign_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    director_period_s REAL NOT NULL CHECK(director_period_s>0),
    focus_bonus_bp INTEGER NOT NULL CHECK(focus_bonus_bp BETWEEN 10000 AND 12000),
    partial_bonus_bp INTEGER NOT NULL CHECK(partial_bonus_bp BETWEEN 1 AND 10000),
    report_limit INTEGER NOT NULL CHECK(report_limit BETWEEN 10 AND 100),
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_campaign_balance_defs_insert_guard BEFORE INSERT ON frozen_campaign_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_campaign_balance_defs_update_guard BEFORE UPDATE ON frozen_campaign_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_campaign_balance_defs_delete_guard BEFORE DELETE ON frozen_campaign_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_construction_project_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    project_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    station_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    required_evidence_units INTEGER NOT NULL CHECK(required_evidence_units>0),
    description TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, project_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    UNIQUE (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_construction_project_defs_insert_guard BEFORE INSERT ON frozen_construction_project_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_construction_project_defs_update_guard BEFORE UPDATE ON frozen_construction_project_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_construction_project_defs_delete_guard BEFORE DELETE ON frozen_construction_project_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_construction_stage_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    project_id TEXT NOT NULL,
    stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 1 AND 3),
    display_name TEXT NOT NULL,
    work_s REAL NOT NULL CHECK(work_s>0),
    fee_credit INTEGER NOT NULL CHECK(fee_credit>0),
    effect_kind TEXT NOT NULL CHECK(effect_kind IN('manufacture_fee','repair_fee','stock_refresh')),
    multiplier_bp INTEGER NOT NULL CHECK(multiplier_bp BETWEEN 8000 AND 12000),
    PRIMARY KEY (content_snapshot_id, project_id, stage_index),
    FOREIGN KEY (content_snapshot_id, project_id) REFERENCES frozen_construction_project_defs (content_snapshot_id, project_id)
) STRICT;
CREATE TRIGGER frozen_construction_stage_defs_insert_guard BEFORE INSERT ON frozen_construction_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_construction_stage_defs_update_guard BEFORE UPDATE ON frozen_construction_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_construction_stage_defs_delete_guard BEFORE DELETE ON frozen_construction_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_construction_input_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    project_id TEXT NOT NULL,
    stage_index INTEGER NOT NULL,
    item_id TEXT NOT NULL,
    delivery_station_id TEXT NOT NULL,
    required_units INTEGER NOT NULL CHECK(required_units>0),
    FOREIGN KEY (content_snapshot_id, project_id,stage_index) REFERENCES frozen_construction_stage_defs (content_snapshot_id, project_id,stage_index),
    PRIMARY KEY (content_snapshot_id, project_id, stage_index, item_id, delivery_station_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id),
    FOREIGN KEY (content_snapshot_id, delivery_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id)
) STRICT;
CREATE TRIGGER frozen_construction_input_defs_insert_guard BEFORE INSERT ON frozen_construction_input_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_construction_input_defs_update_guard BEFORE UPDATE ON frozen_construction_input_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_construction_input_defs_delete_guard BEFORE DELETE ON frozen_construction_input_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_expedition_route_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    route_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    origin_station_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    start_fee_credit INTEGER NOT NULL CHECK(start_fee_credit>0),
    cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
    focus_index INTEGER NOT NULL CHECK(focus_index BETWEEN 0 AND 2),
    description TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, route_id),
    FOREIGN KEY (content_snapshot_id, origin_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id),
    UNIQUE (content_snapshot_id, focus_index)
) STRICT;
CREATE TRIGGER frozen_expedition_route_defs_insert_guard BEFORE INSERT ON frozen_expedition_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_expedition_route_defs_update_guard BEFORE UPDATE ON frozen_expedition_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_expedition_route_defs_delete_guard BEFORE DELETE ON frozen_expedition_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_expedition_option_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    route_id TEXT NOT NULL,
    stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 1 AND 3),
    option_id TEXT NOT NULL,
    event_id TEXT NOT NULL,
    bonus_credit INTEGER NOT NULL CHECK(bonus_credit>0),
    bonus_insight INTEGER NOT NULL CHECK(bonus_insight>0),
    UNIQUE (content_snapshot_id, route_id,event_id),
    PRIMARY KEY (content_snapshot_id, route_id, stage_index, option_id),
    FOREIGN KEY (content_snapshot_id, route_id) REFERENCES frozen_expedition_route_defs (content_snapshot_id, route_id),
    FOREIGN KEY (content_snapshot_id, event_id) REFERENCES frozen_exploration_event_defs (content_snapshot_id, event_id)
) STRICT;
CREATE TRIGGER frozen_expedition_option_defs_insert_guard BEFORE INSERT ON frozen_expedition_option_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_expedition_option_defs_update_guard BEFORE UPDATE ON frozen_expedition_option_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_expedition_option_defs_delete_guard BEFORE DELETE ON frozen_expedition_option_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_campaign_event_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    event_id TEXT NOT NULL,
    project_id TEXT NOT NULL,
    full_units INTEGER NOT NULL CHECK(full_units>0),
    partial_units INTEGER NOT NULL CHECK(partial_units>0 AND partial_units<=full_units),
    PRIMARY KEY (content_snapshot_id, event_id),
    FOREIGN KEY (content_snapshot_id, event_id) REFERENCES frozen_exploration_event_defs (content_snapshot_id, event_id),
    FOREIGN KEY (content_snapshot_id, project_id) REFERENCES frozen_construction_project_defs (content_snapshot_id, project_id)
) STRICT;
CREATE TRIGGER frozen_campaign_event_defs_insert_guard BEFORE INSERT ON frozen_campaign_event_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_campaign_event_defs_update_guard BEFORE UPDATE ON frozen_campaign_event_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_campaign_event_defs_delete_guard BEFORE DELETE ON frozen_campaign_event_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_campaign_tactical_links (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    site_id TEXT NOT NULL,
    event_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, site_id),
    FOREIGN KEY (content_snapshot_id, site_id) REFERENCES frozen_tactical_site_defs (content_snapshot_id, site_id),
    FOREIGN KEY (content_snapshot_id, event_id) REFERENCES frozen_exploration_event_defs (content_snapshot_id, event_id),
    UNIQUE (content_snapshot_id, event_id)
) STRICT;
CREATE TRIGGER frozen_campaign_tactical_links_insert_guard BEFORE INSERT ON frozen_campaign_tactical_links
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_campaign_tactical_links_update_guard BEFORE UPDATE ON frozen_campaign_tactical_links
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_campaign_tactical_links_delete_guard BEFORE DELETE ON frozen_campaign_tactical_links
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE construction_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,project_id TEXT NOT NULL,stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 1 AND 3),
 phase TEXT NOT NULL CHECK(phase IN('gathering','working','completed')),paused INTEGER NOT NULL DEFAULT 0 CHECK(paused IN(0,1)),
 work_remaining_s REAL NOT NULL DEFAULT 0 CHECK(work_remaining_s>=0),revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),
 paid_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit_total>=0),completed_tick INTEGER NOT NULL DEFAULT 0 CHECK(completed_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,project_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,project_id) REFERENCES frozen_construction_project_defs(content_snapshot_id,project_id)) STRICT;

CREATE TRIGGER construction_state_insert_immutable BEFORE INSERT ON construction_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER construction_state_update_immutable BEFORE UPDATE ON construction_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER construction_state_delete_immutable BEFORE DELETE ON construction_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE construction_input_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,project_id TEXT NOT NULL,stage_index INTEGER NOT NULL,
 item_id TEXT NOT NULL,delivery_station_id TEXT NOT NULL,delivered_units INTEGER NOT NULL DEFAULT 0 CHECK(delivered_units>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,project_id,stage_index,item_id,delivery_station_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,project_id,stage_index,item_id,delivery_station_id) REFERENCES frozen_construction_input_defs(content_snapshot_id,project_id,stage_index,item_id,delivery_station_id)) STRICT;

CREATE TRIGGER construction_input_state_insert_immutable BEFORE INSERT ON construction_input_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER construction_input_state_update_immutable BEFORE UPDATE ON construction_input_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER construction_input_state_delete_immutable BEFORE DELETE ON construction_input_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE construction_receipt_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,receipt_id TEXT NOT NULL,project_id TEXT NOT NULL,stage_index INTEGER NOT NULL,
 action_kind TEXT NOT NULL CHECK(action_kind IN('deliver','start')),station_id TEXT NOT NULL,item_id TEXT,
 units INTEGER NOT NULL DEFAULT 0 CHECK(units>=0),paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,receipt_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,project_id,stage_index) REFERENCES frozen_construction_stage_defs(content_snapshot_id,project_id,stage_index),
 FOREIGN KEY(content_snapshot_id,station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id),
 FOREIGN KEY(content_snapshot_id,item_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)) STRICT;

CREATE TRIGGER construction_receipt_state_insert_immutable BEFORE INSERT ON construction_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER construction_receipt_state_update_immutable BEFORE UPDATE ON construction_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER construction_receipt_state_delete_immutable BEFORE DELETE ON construction_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE construction_evidence_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,project_id TEXT NOT NULL,player_id TEXT NOT NULL,event_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),
 units INTEGER NOT NULL CHECK(units>0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,project_id,event_id,generation),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,project_id) REFERENCES frozen_construction_project_defs(content_snapshot_id,project_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id,event_id,generation) REFERENCES exploration_claim_state(snapshot_id,world_id,content_snapshot_id,player_id,event_id,generation)) STRICT;

CREATE TRIGGER construction_evidence_state_insert_immutable BEFORE INSERT ON construction_evidence_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER construction_evidence_state_update_immutable BEFORE UPDATE ON construction_evidence_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER construction_evidence_state_delete_immutable BEFORE DELETE ON construction_evidence_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE expedition_route_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,route_id TEXT NOT NULL,cooldown_remaining_s REAL NOT NULL DEFAULT 0 CHECK(cooldown_remaining_s>=0),
 completed_runs INTEGER NOT NULL DEFAULT 0 CHECK(completed_runs>=0),withdrawn_runs INTEGER NOT NULL DEFAULT 0 CHECK(withdrawn_runs>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,route_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,route_id) REFERENCES frozen_expedition_route_defs(content_snapshot_id,route_id)) STRICT;

CREATE TRIGGER expedition_route_state_insert_immutable BEFORE INSERT ON expedition_route_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER expedition_route_state_update_immutable BEFORE UPDATE ON expedition_route_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER expedition_route_state_delete_immutable BEFORE DELETE ON expedition_route_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE expedition_run_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,run_id TEXT NOT NULL,route_id TEXT NOT NULL,stage_index INTEGER NOT NULL CHECK(stage_index BETWEEN 1 AND 3),
 phase TEXT NOT NULL CHECK(phase IN('active','checkpoint','returning','completed','withdrawn','failed')),withdraw_requested INTEGER NOT NULL DEFAULT 0 CHECK(withdraw_requested IN(0,1)),focus_bonus_bp INTEGER NOT NULL CHECK(focus_bonus_bp BETWEEN 10000 AND 12000),
 fee_paid_credit INTEGER NOT NULL CHECK(fee_paid_credit>0),started_tick INTEGER NOT NULL CHECK(started_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0),
 bonus_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(bonus_credit_total>=0),bonus_insight_total INTEGER NOT NULL DEFAULT 0 CHECK(bonus_insight_total>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,run_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,route_id) REFERENCES frozen_expedition_route_defs(content_snapshot_id,route_id)) STRICT;

CREATE TRIGGER expedition_run_state_insert_immutable BEFORE INSERT ON expedition_run_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER expedition_run_state_update_immutable BEFORE UPDATE ON expedition_run_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER expedition_run_state_delete_immutable BEFORE DELETE ON expedition_run_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE expedition_stage_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,run_id TEXT NOT NULL,stage_index INTEGER NOT NULL,option_id TEXT NOT NULL,event_id TEXT NOT NULL,
 event_generation INTEGER NOT NULL CHECK(event_generation>=1),outcome TEXT NOT NULL DEFAULT '' CHECK(outcome IN('','full','partial','failed','withdrawn')),
 settled INTEGER NOT NULL DEFAULT 0 CHECK(settled IN(0,1)),bonus_credit INTEGER NOT NULL DEFAULT 0 CHECK(bonus_credit>=0),bonus_insight INTEGER NOT NULL DEFAULT 0 CHECK(bonus_insight>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,run_id,stage_index),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,run_id) REFERENCES expedition_run_state(snapshot_id,world_id,content_snapshot_id,run_id),
 FOREIGN KEY(content_snapshot_id,event_id) REFERENCES frozen_exploration_event_defs(content_snapshot_id,event_id)) STRICT;

CREATE TRIGGER expedition_stage_state_insert_immutable BEFORE INSERT ON expedition_stage_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER expedition_stage_state_update_immutable BEFORE UPDATE ON expedition_stage_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER expedition_stage_state_delete_immutable BEFORE DELETE ON expedition_stage_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE expedition_receipt_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,receipt_id TEXT NOT NULL,run_id TEXT NOT NULL,stage_index INTEGER NOT NULL,
 action_kind TEXT NOT NULL CHECK(action_kind IN('start','stage','withdraw','complete','fail')),
 paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),bonus_credit INTEGER NOT NULL DEFAULT 0 CHECK(bonus_credit>=0),
 bonus_insight INTEGER NOT NULL DEFAULT 0 CHECK(bonus_insight>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,receipt_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,run_id) REFERENCES expedition_run_state(snapshot_id,world_id,content_snapshot_id,run_id)) STRICT;

CREATE TRIGGER expedition_receipt_state_insert_immutable BEFORE INSERT ON expedition_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER expedition_receipt_state_update_immutable BEFORE UPDATE ON expedition_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER expedition_receipt_state_delete_immutable BEFORE DELETE ON expedition_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE campaign_director_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,singleton INTEGER NOT NULL CHECK(singleton=1),focus_index INTEGER NOT NULL CHECK(focus_index BETWEEN 0 AND 2),
 generation INTEGER NOT NULL CHECK(generation>=1),remaining_s REAL NOT NULL CHECK(remaining_s>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,singleton),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER campaign_director_state_insert_immutable BEFORE INSERT ON campaign_director_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER campaign_director_state_update_immutable BEFORE UPDATE ON campaign_director_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER campaign_director_state_delete_immutable BEFORE DELETE ON campaign_director_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE flight_record_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,record_id TEXT NOT NULL,sequence INTEGER NOT NULL CHECK(sequence>=1),ship_def_id TEXT NOT NULL,
 phase TEXT NOT NULL CHECK(phase IN('active','docked','lost')),partial_baseline INTEGER NOT NULL CHECK(partial_baseline IN(0,1)),
 started_tick INTEGER NOT NULL CHECK(started_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0),
 elapsed_s REAL NOT NULL DEFAULT 0 CHECK(elapsed_s>=0),combat_s REAL NOT NULL DEFAULT 0 CHECK(combat_s>=0),transit_s REAL NOT NULL DEFAULT 0 CHECK(transit_s>=0),
 credit_start INTEGER NOT NULL CHECK(credit_start>=0),credit_last INTEGER NOT NULL CHECK(credit_last>=0),
 flight_income INTEGER NOT NULL DEFAULT 0 CHECK(flight_income>=0),flight_spent INTEGER NOT NULL DEFAULT 0 CHECK(flight_spent>=0),
 return_income INTEGER NOT NULL DEFAULT 0 CHECK(return_income>=0),return_spent INTEGER NOT NULL DEFAULT 0 CHECK(return_spent>=0),
 mined_units INTEGER NOT NULL DEFAULT 0 CHECK(mined_units>=0),kills INTEGER NOT NULL DEFAULT 0 CHECK(kills>=0),
 damage_dealt REAL NOT NULL DEFAULT 0 CHECK(damage_dealt>=0),damage_taken REAL NOT NULL DEFAULT 0 CHECK(damage_taken>=0),
 weapon_cycles INTEGER NOT NULL DEFAULT 0 CHECK(weapon_cycles>=0),drone_losses INTEGER NOT NULL DEFAULT 0 CHECK(drone_losses>=0),
 activity_count INTEGER NOT NULL DEFAULT 0 CHECK(activity_count>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,record_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,ship_def_id) REFERENCES frozen_ship_defs(content_snapshot_id,ship_id)) STRICT;

CREATE TRIGGER flight_record_state_insert_immutable BEFORE INSERT ON flight_record_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER flight_record_state_update_immutable BEFORE UPDATE ON flight_record_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER flight_record_state_delete_immutable BEFORE DELETE ON flight_record_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE telemetry_total_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,singleton INTEGER NOT NULL CHECK(singleton=1),next_sequence INTEGER NOT NULL CHECK(next_sequence>=1),wallet_last INTEGER NOT NULL CHECK(wallet_last>=0),
 outings INTEGER NOT NULL DEFAULT 0 CHECK(outings>=0),lost_outings INTEGER NOT NULL DEFAULT 0 CHECK(lost_outings>=0),
 elapsed_s REAL NOT NULL DEFAULT 0 CHECK(elapsed_s>=0),combat_s REAL NOT NULL DEFAULT 0 CHECK(combat_s>=0),transit_s REAL NOT NULL DEFAULT 0 CHECK(transit_s>=0),
 income_credit INTEGER NOT NULL DEFAULT 0 CHECK(income_credit>=0),spent_credit INTEGER NOT NULL DEFAULT 0 CHECK(spent_credit>=0),
 mined_units INTEGER NOT NULL DEFAULT 0 CHECK(mined_units>=0),kills INTEGER NOT NULL DEFAULT 0 CHECK(kills>=0),
 damage_dealt REAL NOT NULL DEFAULT 0 CHECK(damage_dealt>=0),damage_taken REAL NOT NULL DEFAULT 0 CHECK(damage_taken>=0),
 weapon_cycles INTEGER NOT NULL DEFAULT 0 CHECK(weapon_cycles>=0),drone_losses INTEGER NOT NULL DEFAULT 0 CHECK(drone_losses>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,singleton),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE) STRICT;

CREATE TRIGGER telemetry_total_state_insert_immutable BEFORE INSERT ON telemetry_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER telemetry_total_state_update_immutable BEFORE UPDATE ON telemetry_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER telemetry_total_state_delete_immutable BEFORE DELETE ON telemetry_total_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER campaign_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_campaign_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND (EXISTS(SELECT 1 FROM construction_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM construction_input_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM construction_receipt_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM construction_evidence_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM expedition_route_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM expedition_run_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM expedition_stage_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM expedition_receipt_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM campaign_director_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM flight_record_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM telemetry_total_state WHERE snapshot_id=NEW.snapshot_id)) BEGIN SELECT RAISE(ABORT,'campaign state under legacy rules'); END;

CREATE UNIQUE INDEX construction_stage_payment_once ON construction_receipt_state(snapshot_id,world_id,content_snapshot_id,project_id,stage_index) WHERE action_kind='start';

CREATE UNIQUE INDEX expedition_one_active ON expedition_run_state(snapshot_id,world_id,content_snapshot_id) WHERE phase IN('active','checkpoint','returning');

CREATE UNIQUE INDEX expedition_stage_receipt_once ON expedition_receipt_state(snapshot_id,world_id,content_snapshot_id,run_id,stage_index) WHERE action_kind='stage';

CREATE UNIQUE INDEX flight_one_active ON flight_record_state(snapshot_id,world_id,content_snapshot_id) WHERE phase='active';

CREATE UNIQUE INDEX expedition_start_once ON expedition_receipt_state(snapshot_id,world_id,content_snapshot_id,run_id) WHERE action_kind='start';

CREATE UNIQUE INDEX expedition_terminal_once ON expedition_receipt_state(snapshot_id,world_id,content_snapshot_id,run_id) WHERE action_kind IN('withdraw','complete','fail');

CREATE UNIQUE INDEX flight_sequence_unique ON flight_record_state(snapshot_id,world_id,content_snapshot_id,sequence);

DROP TRIGGER exploration_context_seal_validation;
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
 p.insight_earned<>coalesce((SELECT sum(c.insight_units) FROM exploration_claim_state c WHERE c.snapshot_id=p.snapshot_id AND c.player_id=p.player_id),0)+coalesce((SELECT sum(s.bonus_insight) FROM expedition_stage_state s WHERE s.snapshot_id=p.snapshot_id AND s.settled=1),0) OR
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

CREATE TRIGGER campaign_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_input_state i JOIN frozen_construction_input_defs d USING(content_snapshot_id,project_id,stage_index,item_id,delivery_station_id)
 WHERE i.snapshot_id=NEW.snapshot_id AND (i.delivered_units>d.required_units OR i.delivered_units<>(SELECT coalesce(sum(r.units),0) FROM construction_receipt_state r WHERE r.snapshot_id=i.snapshot_id AND r.project_id=i.project_id AND r.stage_index=i.stage_index AND r.item_id=i.item_id AND r.station_id=i.delivery_station_id AND r.action_kind='deliver'))) THEN RAISE(ABORT,'construction delivery lacks finite receipts') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_state s JOIN frozen_construction_stage_defs d USING(content_snapshot_id,project_id,stage_index)
 WHERE s.snapshot_id=NEW.snapshot_id AND (s.work_remaining_s>d.work_s OR s.completed_tick>NEW.simulation_tick OR
 s.paid_credit_total<>(SELECT coalesce(sum(r.paid_credit),0) FROM construction_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.project_id=s.project_id) OR
 (s.phase='working' AND NOT EXISTS(SELECT 1 FROM construction_receipt_state r WHERE r.snapshot_id=s.snapshot_id AND r.project_id=s.project_id AND r.stage_index=s.stage_index AND r.action_kind='start')) OR
 (s.phase='completed' AND (s.stage_index<>3 OR s.work_remaining_s<>0)) OR
 (s.phase='gathering' AND s.work_remaining_s<>0))) THEN RAISE(ABORT,'invalid construction phase or expense') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_receipt_state r JOIN frozen_construction_stage_defs d USING(content_snapshot_id,project_id,stage_index)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.event_tick>NEW.simulation_tick OR
 (r.action_kind='start' AND (r.units<>0 OR r.item_id IS NOT NULL OR r.paid_credit<>d.fee_credit)) OR
 (r.action_kind='deliver' AND (r.units<=0 OR r.item_id IS NULL OR r.paid_credit<>0 OR NOT EXISTS(SELECT 1 FROM frozen_construction_input_defs i WHERE i.content_snapshot_id=r.content_snapshot_id AND i.project_id=r.project_id AND i.stage_index=r.stage_index AND i.item_id=r.item_id AND i.delivery_station_id=r.station_id))))) THEN RAISE(ABORT,'invalid construction receipt') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_evidence_state e JOIN exploration_claim_state c USING(snapshot_id,world_id,content_snapshot_id,player_id,event_id,generation)
 JOIN frozen_campaign_event_defs d USING(content_snapshot_id,event_id) WHERE e.snapshot_id=NEW.snapshot_id AND (e.project_id<>d.project_id OR e.units<>CASE WHEN c.outcome='full' THEN d.full_units ELSE d.partial_units END)) THEN RAISE(ABORT,'construction evidence lacks actual exploration outcome') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_run_state r JOIN frozen_expedition_route_defs d USING(content_snapshot_id,route_id)
 JOIN frozen_campaign_balance_defs b USING(content_snapshot_id) WHERE r.snapshot_id=NEW.snapshot_id AND (
 r.fee_paid_credit<>d.start_fee_credit OR r.focus_bonus_bp NOT IN(10000,b.focus_bonus_bp) OR r.started_tick>NEW.simulation_tick OR r.finished_tick>NEW.simulation_tick OR
 (SELECT count(*) FROM expedition_stage_state s WHERE s.snapshot_id=r.snapshot_id AND s.run_id=r.run_id)<>r.stage_index OR
 (SELECT count(*) FROM expedition_receipt_state x WHERE x.snapshot_id=r.snapshot_id AND x.run_id=r.run_id AND x.action_kind='start')<>1 OR
 r.bonus_credit_total<>(SELECT coalesce(sum(s.bonus_credit),0) FROM expedition_stage_state s WHERE s.snapshot_id=r.snapshot_id AND s.run_id=r.run_id) OR
 r.bonus_insight_total<>(SELECT coalesce(sum(s.bonus_insight),0) FROM expedition_stage_state s WHERE s.snapshot_id=r.snapshot_id AND s.run_id=r.run_id) OR
 (r.phase IN('active','checkpoint','returning') AND r.finished_tick<>0) OR
 (r.phase IN('completed','withdrawn','failed') AND r.finished_tick<r.started_tick))) THEN RAISE(ABORT,'invalid expedition sequence or totals') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_stage_state s JOIN expedition_run_state r USING(snapshot_id,world_id,content_snapshot_id,run_id)
 LEFT JOIN frozen_expedition_option_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.route_id=r.route_id AND d.stage_index=s.stage_index AND d.option_id=s.option_id
 LEFT JOIN exploration_claim_state c ON c.snapshot_id=s.snapshot_id AND c.event_id=s.event_id AND c.generation=s.event_generation
 JOIN frozen_campaign_balance_defs b ON b.content_snapshot_id=s.content_snapshot_id
 WHERE s.snapshot_id=NEW.snapshot_id AND (d.option_id IS NULL OR d.event_id<>s.event_id OR s.stage_index>r.stage_index OR
 (s.settled=0 AND (s.bonus_credit<>0 OR s.bonus_insight<>0 OR s.outcome<>'')) OR
 (s.settled=1 AND (c.event_id IS NULL OR s.outcome<>c.outcome OR
 s.bonus_credit<>CAST(d.bonus_credit*r.focus_bonus_bp/10000.0*CASE WHEN c.outcome='full' THEN 1.0 ELSE b.partial_bonus_bp/10000.0 END AS INTEGER) OR
 s.bonus_insight<>CAST(d.bonus_insight*r.focus_bonus_bp/10000.0*CASE WHEN c.outcome='full' THEN 1.0 ELSE b.partial_bonus_bp/10000.0 END AS INTEGER))))) THEN RAISE(ABORT,'expedition stage lacks exact claimed result') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM construction_receipt_state r JOIN frozen_construction_project_defs p USING(content_snapshot_id,project_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND r.action_kind='start' AND (r.station_id<>p.station_id OR
 EXISTS(SELECT 1 FROM frozen_construction_input_defs d LEFT JOIN construction_input_state i ON i.snapshot_id=r.snapshot_id AND i.project_id=d.project_id AND i.stage_index=d.stage_index AND i.item_id=d.item_id AND i.delivery_station_id=d.delivery_station_id
 WHERE d.content_snapshot_id=r.content_snapshot_id AND d.project_id=r.project_id AND d.stage_index=r.stage_index AND coalesce(i.delivered_units,0)<d.required_units) OR
 (r.stage_index=3 AND (SELECT coalesce(sum(e.units),0) FROM construction_evidence_state e WHERE e.snapshot_id=r.snapshot_id AND e.project_id=r.project_id)<p.required_evidence_units))) THEN RAISE(ABORT,'construction started without complete inputs or evidence') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_receipt_state x JOIN expedition_run_state r USING(snapshot_id,world_id,content_snapshot_id,run_id)
 LEFT JOIN expedition_stage_state s USING(snapshot_id,world_id,content_snapshot_id,run_id,stage_index)
 WHERE x.snapshot_id=NEW.snapshot_id AND (x.event_tick>NEW.simulation_tick OR
 (x.action_kind='start' AND (x.stage_index<>1 OR x.paid_credit<>r.fee_paid_credit OR x.bonus_credit<>0 OR x.bonus_insight<>0)) OR
 (x.action_kind='stage' AND (s.run_id IS NULL OR s.settled<>1 OR x.paid_credit<>0 OR x.bonus_credit<>s.bonus_credit OR x.bonus_insight<>s.bonus_insight)) OR
 (x.action_kind IN('withdraw','complete','fail') AND (x.paid_credit<>0 OR x.bonus_credit<>0 OR x.bonus_insight<>0 OR x.event_tick<>r.finished_tick OR x.stage_index<>r.stage_index OR
 x.action_kind<>CASE r.phase WHEN 'withdrawn' THEN 'withdraw' WHEN 'completed' THEN 'complete' WHEN 'failed' THEN 'fail' ELSE '' END)))) THEN RAISE(ABORT,'expedition receipt has no entitlement') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_stage_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.settled=1 AND
 (SELECT count(*) FROM expedition_receipt_state x WHERE x.snapshot_id=s.snapshot_id AND x.run_id=s.run_id AND x.stage_index=s.stage_index AND x.action_kind='stage')<>1) THEN RAISE(ABORT,'missing expedition stage payment') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM expedition_run_state r WHERE r.snapshot_id=NEW.snapshot_id AND
 (SELECT count(*) FROM expedition_receipt_state x WHERE x.snapshot_id=r.snapshot_id AND x.run_id=r.run_id AND x.action_kind IN('withdraw','complete','fail'))<>CASE WHEN r.phase IN('completed','withdrawn','failed') THEN 1 ELSE 0 END) THEN RAISE(ABORT,'missing or duplicate expedition outcome') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_campaign_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 ((SELECT count(*) FROM construction_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_construction_project_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM construction_input_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_construction_input_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM expedition_route_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_expedition_route_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM campaign_director_state WHERE snapshot_id=NEW.snapshot_id)<>1 OR (SELECT count(*) FROM telemetry_total_state WHERE snapshot_id=NEW.snapshot_id)<>1) THEN RAISE(ABORT,'campaign initial coverage incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM flight_record_state r WHERE r.snapshot_id=NEW.snapshot_id AND
 (r.started_tick>NEW.simulation_tick OR r.finished_tick>NEW.simulation_tick OR r.combat_s>r.elapsed_s OR r.transit_s>r.elapsed_s OR
 r.credit_last<>r.credit_start+r.flight_income+r.return_income-r.flight_spent-r.return_spent OR
 (r.phase='active' AND r.finished_tick<>0) OR (r.phase<>'active' AND r.finished_tick<r.started_tick))) THEN RAISE(ABORT,'invalid measured outing summary') END;
 SELECT CASE WHEN (SELECT count(*) FROM flight_record_state WHERE snapshot_id=NEW.snapshot_id)>(SELECT report_limit FROM frozen_campaign_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN RAISE(ABORT,'outing reports exceed retention') END;
END;

CREATE TABLE database_meta_format22(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=22)) STRICT;
INSERT INTO database_meta_format22 SELECT singleton,application_id,22 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format22 RENAME TO database_meta;PRAGMA user_version=22;
