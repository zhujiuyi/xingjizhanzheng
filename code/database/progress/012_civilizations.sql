-- Format8 -> 9: civilization authority, territory and real NPC war fleets.

CREATE TABLE frozen_civilization_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    faction_id TEXT NOT NULL,
    capital_sector_id TEXT NOT NULL,
    capital_station_id TEXT NOT NULL,
    doctrine TEXT NOT NULL,
    color_hex TEXT NOT NULL CHECK(length(color_hex)=6),
    PRIMARY KEY (content_snapshot_id, faction_id),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_faction_defs (content_snapshot_id, faction_id),
    FOREIGN KEY (content_snapshot_id, capital_sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    UNIQUE (content_snapshot_id, capital_sector_id),
    FOREIGN KEY (content_snapshot_id, capital_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    UNIQUE (content_snapshot_id, capital_station_id)
) STRICT;
CREATE TRIGGER frozen_civilization_defs_insert_guard BEFORE INSERT ON frozen_civilization_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_defs_update_guard BEFORE UPDATE ON frozen_civilization_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_defs_delete_guard BEFORE DELETE ON frozen_civilization_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_civilization_rank_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    faction_id TEXT NOT NULL,
    rank_level INTEGER NOT NULL CHECK(rank_level BETWEEN 0 AND 7),
    display_name TEXT NOT NULL,
    required_reputation INTEGER NOT NULL CHECK(required_reputation>=0),
    UNIQUE (content_snapshot_id, faction_id,required_reputation),
    PRIMARY KEY (content_snapshot_id, faction_id, rank_level),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_civilization_defs (content_snapshot_id, faction_id)
) STRICT;
CREATE TRIGGER frozen_civilization_rank_defs_insert_guard BEFORE INSERT ON frozen_civilization_rank_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_rank_defs_update_guard BEFORE UPDATE ON frozen_civilization_rank_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_rank_defs_delete_guard BEFORE DELETE ON frozen_civilization_rank_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_sector_sovereignty_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    sector_id TEXT NOT NULL,
    initial_faction_id TEXT,
    conquerable INTEGER NOT NULL CHECK(conquerable IN (0,1)),
    chart_x REAL NOT NULL,
    chart_y REAL NOT NULL,
    CHECK(initial_faction_id IS NULL OR conquerable=0),
    PRIMARY KEY (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, initial_faction_id) REFERENCES frozen_civilization_defs (content_snapshot_id, faction_id)
) STRICT;
CREATE TRIGGER frozen_sector_sovereignty_defs_insert_guard BEFORE INSERT ON frozen_sector_sovereignty_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_sector_sovereignty_defs_update_guard BEFORE UPDATE ON frozen_sector_sovereignty_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_sector_sovereignty_defs_delete_guard BEFORE DELETE ON frozen_sector_sovereignty_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_civilization_join_missions (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    faction_id TEXT NOT NULL,
    step_index INTEGER NOT NULL CHECK(step_index BETWEEN 1 AND 3),
    mission_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, faction_id, step_index),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_civilization_defs (content_snapshot_id, faction_id),
    FOREIGN KEY (content_snapshot_id, mission_id) REFERENCES frozen_mission_defs (content_snapshot_id, mission_id),
    UNIQUE (content_snapshot_id, mission_id)
) STRICT;
CREATE TRIGGER frozen_civilization_join_missions_insert_guard BEFORE INSERT ON frozen_civilization_join_missions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_join_missions_update_guard BEFORE UPDATE ON frozen_civilization_join_missions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_join_missions_delete_guard BEFORE DELETE ON frozen_civilization_join_missions
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_civilization_hull_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    faction_id TEXT NOT NULL,
    required_rank INTEGER NOT NULL,
    required_unlock_id TEXT NOT NULL,
    base_ship_id TEXT NOT NULL,
    description TEXT NOT NULL,
    FOREIGN KEY (content_snapshot_id, faction_id,required_rank) REFERENCES frozen_civilization_rank_defs (content_snapshot_id, faction_id,rank_level),
    PRIMARY KEY (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_civilization_defs (content_snapshot_id, faction_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id),
    FOREIGN KEY (content_snapshot_id, base_ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_civilization_hull_defs_insert_guard BEFORE INSERT ON frozen_civilization_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_hull_defs_update_guard BEFORE UPDATE ON frozen_civilization_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_hull_defs_delete_guard BEFORE DELETE ON frozen_civilization_hull_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_civilization_technology_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    research_id TEXT NOT NULL,
    faction_id TEXT NOT NULL,
    required_rank INTEGER NOT NULL,
    FOREIGN KEY (content_snapshot_id, faction_id,required_rank) REFERENCES frozen_civilization_rank_defs (content_snapshot_id, faction_id,rank_level),
    PRIMARY KEY (content_snapshot_id, research_id),
    FOREIGN KEY (content_snapshot_id, research_id) REFERENCES frozen_research_defs (content_snapshot_id, research_id),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_civilization_defs (content_snapshot_id, faction_id)
) STRICT;
CREATE TRIGGER frozen_civilization_technology_defs_insert_guard BEFORE INSERT ON frozen_civilization_technology_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_technology_defs_update_guard BEFORE UPDATE ON frozen_civilization_technology_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_technology_defs_delete_guard BEFORE DELETE ON frozen_civilization_technology_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_civilization_donation_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    donation_id TEXT NOT NULL,
    faction_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    units_per_batch INTEGER NOT NULL CHECK(units_per_batch>0),
    reputation_per_batch INTEGER NOT NULL CHECK(reputation_per_batch>0),
    PRIMARY KEY (content_snapshot_id, donation_id),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_civilization_defs (content_snapshot_id, faction_id),
    FOREIGN KEY (content_snapshot_id, item_id) REFERENCES frozen_item_defs (content_snapshot_id, item_id)
) STRICT;
CREATE TRIGGER frozen_civilization_donation_defs_insert_guard BEFORE INSERT ON frozen_civilization_donation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_donation_defs_update_guard BEFORE UPDATE ON frozen_civilization_donation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_donation_defs_delete_guard BEFORE DELETE ON frozen_civilization_donation_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_civilization_war_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    war_id TEXT NOT NULL,
    faction_id TEXT NOT NULL,
    target_sector_id TEXT NOT NULL,
    capture_anchor_id TEXT NOT NULL,
    required_rank INTEGER NOT NULL,
    capture_duration_s REAL NOT NULL CHECK(capture_duration_s>0),
    capture_radius_m REAL NOT NULL CHECK(capture_radius_m>0),
    reward_credit INTEGER NOT NULL CHECK(reward_credit>=0),
    reward_reputation INTEGER NOT NULL CHECK(reward_reputation>0),
    FOREIGN KEY (content_snapshot_id, faction_id,required_rank) REFERENCES frozen_civilization_rank_defs (content_snapshot_id, faction_id,rank_level),
    UNIQUE (content_snapshot_id, faction_id,target_sector_id),
    PRIMARY KEY (content_snapshot_id, war_id),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_civilization_defs (content_snapshot_id, faction_id),
    FOREIGN KEY (content_snapshot_id, target_sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id),
    FOREIGN KEY (content_snapshot_id, capture_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id)
) STRICT;
CREATE TRIGGER frozen_civilization_war_defs_insert_guard BEFORE INSERT ON frozen_civilization_war_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_war_defs_update_guard BEFORE UPDATE ON frozen_civilization_war_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_war_defs_delete_guard BEFORE DELETE ON frozen_civilization_war_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_civilization_war_members (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    war_id TEXT NOT NULL,
    spawn_id TEXT NOT NULL,
    side TEXT NOT NULL CHECK(side IN ('ally','defender')),
    formation_index INTEGER NOT NULL CHECK(formation_index>=0),
    PRIMARY KEY (content_snapshot_id, war_id, side, formation_index),
    FOREIGN KEY (content_snapshot_id, war_id) REFERENCES frozen_civilization_war_defs (content_snapshot_id, war_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    UNIQUE (content_snapshot_id, spawn_id)
) STRICT;
CREATE TRIGGER frozen_civilization_war_members_insert_guard BEFORE INSERT ON frozen_civilization_war_members
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_war_members_update_guard BEFORE UPDATE ON frozen_civilization_war_members
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_civilization_war_members_delete_guard BEFORE DELETE ON frozen_civilization_war_members
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE civilization_state (
 snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
 player_id TEXT NOT NULL,
 faction_id TEXT,
 joined_tick INTEGER NOT NULL CHECK(joined_tick>=0),
 switch_cooldown_remaining_s REAL NOT NULL CHECK(switch_cooldown_remaining_s>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER civilization_state_insert_immutable BEFORE INSERT ON civilization_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER civilization_state_update_immutable BEFORE UPDATE ON civilization_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER civilization_state_delete_immutable BEFORE DELETE ON civilization_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE territory_state (
 snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
 sector_id TEXT NOT NULL,
 faction_id TEXT,
 captured_tick INTEGER NOT NULL CHECK(captured_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_sovereignty_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER territory_state_insert_immutable BEFORE INSERT ON territory_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER territory_state_update_immutable BEFORE UPDATE ON territory_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER territory_state_delete_immutable BEFORE DELETE ON territory_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE war_campaign_state (
 snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
 war_id TEXT NOT NULL, player_id TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('assembling','fighting','occupying','won','failed','cancelled')),
 fleet_order TEXT NOT NULL CHECK(fleet_order IN ('advance','focus','regroup')),
 focus_target_id TEXT NOT NULL,
 capture_remaining_s REAL NOT NULL CHECK(capture_remaining_s>=0),
 attempt INTEGER NOT NULL CHECK(attempt>0), started_tick INTEGER NOT NULL CHECK(started_tick>=0),
 finished_tick INTEGER NOT NULL CHECK(finished_tick>=0), rewards_claimed INTEGER NOT NULL CHECK(rewards_claimed IN (0,1)),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,war_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_civilization_war_defs(content_snapshot_id,war_id),
 CHECK((status='won')=(rewards_claimed=1)),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER war_campaign_state_insert_immutable BEFORE INSERT ON war_campaign_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER war_campaign_state_update_immutable BEFORE UPDATE ON war_campaign_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER war_campaign_state_delete_immutable BEFORE DELETE ON war_campaign_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE war_fleet_state (
 snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
 npc_instance_id TEXT NOT NULL, war_id TEXT NOT NULL,
 side TEXT NOT NULL CHECK(side IN ('ally','defender')),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,war_id) REFERENCES war_campaign_state(snapshot_id,world_id,content_snapshot_id,war_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE
) STRICT;

CREATE TRIGGER war_fleet_state_insert_immutable BEFORE INSERT ON war_fleet_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER war_fleet_state_update_immutable BEFORE UPDATE ON war_fleet_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER war_fleet_state_delete_immutable BEFORE DELETE ON war_fleet_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;


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
   (w.status='won' AND t.faction_id IS NOT d.faction_id)))
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
CREATE TABLE database_meta_format9 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=9)
) STRICT;
INSERT INTO database_meta_format9 SELECT singleton,application_id,9 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format9 RENAME TO database_meta;
PRAGMA user_version=9;
