-- Persistent original NPC members, real gate legs and conservative supply handoff.

CREATE TABLE frozen_march_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    assembly_s REAL NOT NULL CHECK(assembly_s>0),
    align_s REAL NOT NULL CHECK(align_s>0),
    warp_speed_au_s REAL NOT NULL CHECK(warp_speed_au_s>0),
    warp_min_s REAL NOT NULL CHECK(warp_min_s>0),
    warp_max_s REAL NOT NULL CHECK(warp_max_s>=warp_min_s),
    arrival_radius_m REAL NOT NULL CHECK(arrival_radius_m>0),
    clear_distance_m REAL NOT NULL CHECK(clear_distance_m>arrival_radius_m),
    formation_m REAL NOT NULL CHECK(formation_m>0),
    gate_exit_m REAL NOT NULL CHECK(gate_exit_m>0),
    max_blocked_s REAL NOT NULL CHECK(max_blocked_s>0),
    return_supply_ratio REAL NOT NULL CHECK(return_supply_ratio BETWEEN 0 AND 1),
    gate_transit_s REAL NOT NULL CHECK(gate_transit_s>0),
    history_limit INTEGER NOT NULL CHECK(history_limit>=32),
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_march_balance_defs_insert_guard BEFORE INSERT ON frozen_march_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_march_balance_defs_update_guard BEFORE UPDATE ON frozen_march_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_march_balance_defs_delete_guard BEFORE DELETE ON frozen_march_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_march_campaign_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    war_id TEXT NOT NULL,
    origin_station_id TEXT NOT NULL,
    destination_anchor_id TEXT NOT NULL,
    supply_carrier_spawn_id TEXT NOT NULL,
    travel_hull_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, war_id),
    FOREIGN KEY (content_snapshot_id, war_id) REFERENCES frozen_civilization_war_defs (content_snapshot_id, war_id),
    FOREIGN KEY (content_snapshot_id, origin_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, destination_anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, supply_carrier_spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    FOREIGN KEY (content_snapshot_id, travel_hull_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_march_campaign_defs_insert_guard BEFORE INSERT ON frozen_march_campaign_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_march_campaign_defs_update_guard BEFORE UPDATE ON frozen_march_campaign_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_march_campaign_defs_delete_guard BEFORE DELETE ON frozen_march_campaign_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_march_route_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    war_id TEXT NOT NULL,
    leg_index INTEGER NOT NULL CHECK(leg_index>=0),
    endpoint_id TEXT NOT NULL,
    reverse_endpoint_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, war_id, leg_index),
    FOREIGN KEY (content_snapshot_id, war_id) REFERENCES frozen_march_campaign_defs (content_snapshot_id, war_id),
    FOREIGN KEY (content_snapshot_id, endpoint_id) REFERENCES frozen_gate_endpoint_defs (content_snapshot_id, endpoint_id),
    FOREIGN KEY (content_snapshot_id, reverse_endpoint_id) REFERENCES frozen_gate_endpoint_defs (content_snapshot_id, endpoint_id)
) STRICT;
CREATE TRIGGER frozen_march_route_defs_insert_guard BEFORE INSERT ON frozen_march_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_march_route_defs_update_guard BEFORE UPDATE ON frozen_march_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_march_route_defs_delete_guard BEFORE DELETE ON frozen_march_route_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_growth_stage_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    stage_id TEXT NOT NULL,
    faction_id TEXT,
    sort_order INTEGER NOT NULL CHECK(sort_order>=0),
    display_name TEXT NOT NULL,
    criterion_kind TEXT NOT NULL CHECK(criterion_kind IN('membership','rank','research','owned_hull','honors','war','expedition','project')),
    reference_id TEXT NOT NULL,
    target_count INTEGER NOT NULL CHECK(target_count>0),
    station_id TEXT NOT NULL,
    outcome_label TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, stage_id),
    FOREIGN KEY (content_snapshot_id, faction_id) REFERENCES frozen_civilization_defs (content_snapshot_id, faction_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id)
) STRICT;
CREATE TRIGGER frozen_growth_stage_defs_insert_guard BEFORE INSERT ON frozen_growth_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_growth_stage_defs_update_guard BEFORE UPDATE ON frozen_growth_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_growth_stage_defs_delete_guard BEFORE DELETE ON frozen_growth_stage_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_growth_activity_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    stage_id TEXT NOT NULL,
    activity_index INTEGER NOT NULL CHECK(activity_index>=0),
    activity_kind TEXT NOT NULL CHECK(activity_kind IN('mission','donation','research','honor','war','expedition','project')),
    reference_id TEXT NOT NULL,
    station_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, stage_id, activity_index),
    FOREIGN KEY (content_snapshot_id, stage_id) REFERENCES frozen_growth_stage_defs (content_snapshot_id, stage_id),
    FOREIGN KEY (content_snapshot_id, station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id)
) STRICT;
CREATE TRIGGER frozen_growth_activity_defs_insert_guard BEFORE INSERT ON frozen_growth_activity_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_growth_activity_defs_update_guard BEFORE UPDATE ON frozen_growth_activity_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_growth_activity_defs_delete_guard BEFORE DELETE ON frozen_growth_activity_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE march_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,war_id TEXT NOT NULL,attempt INTEGER NOT NULL CHECK(attempt>=1),
phase TEXT NOT NULL CHECK(phase IN('assembling','site_align','site_warp','gate_approach','gate_prepare','gate_transit','arrival_approach','arrived','blocked','returned','failed','cancelled','completed')),
resume_phase TEXT NOT NULL DEFAULT '',direction INTEGER NOT NULL DEFAULT 1 CHECK(direction IN(-1,1)),retreat_requested INTEGER NOT NULL DEFAULT 0 CHECK(retreat_requested IN(0,1)),
completed_legs INTEGER NOT NULL DEFAULT 0 CHECK(completed_legs>=0),sector_id TEXT NOT NULL,site_id TEXT NOT NULL,goal_anchor_id TEXT NOT NULL,
phase_remaining_s REAL NOT NULL DEFAULT 0 CHECK(phase_remaining_s>=0),gate_cooldown_remaining_s REAL NOT NULL DEFAULT 0 CHECK(gate_cooldown_remaining_s>=0),blocked_elapsed_s REAL NOT NULL DEFAULT 0 CHECK(blocked_elapsed_s>=0),blocked_reason TEXT NOT NULL DEFAULT '',
initial_supply_units INTEGER NOT NULL CHECK(initial_supply_units>=0),returned_supply_units INTEGER NOT NULL DEFAULT 0 CHECK(returned_supply_units>=0),lost_supply_units INTEGER NOT NULL DEFAULT 0 CHECK(lost_supply_units>=0),transferred_supply_units INTEGER NOT NULL DEFAULT 0 CHECK(transferred_supply_units>=0),
revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),started_tick INTEGER NOT NULL CHECK(started_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,war_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,war_id) REFERENCES war_campaign_state(snapshot_id,world_id,content_snapshot_id,war_id),FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_march_campaign_defs(content_snapshot_id,war_id),FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id),FOREIGN KEY(content_snapshot_id,goal_anchor_id) REFERENCES frozen_anchor_defs(content_snapshot_id,anchor_id)) STRICT;

CREATE TRIGGER march_state_insert_immutable BEFORE INSERT ON march_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_state_update_immutable BEFORE UPDATE ON march_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_state_delete_immutable BEFORE DELETE ON march_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM march_state WHERE snapshot_id=NEW.snapshot_id AND (abs(phase_remaining_s)>=1e100 OR abs(gate_cooldown_remaining_s)>=1e100 OR abs(blocked_elapsed_s)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite march scalar'); END;

CREATE TABLE march_member_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,npc_instance_id TEXT NOT NULL,war_id TEXT NOT NULL,attempt INTEGER NOT NULL CHECK(attempt>=1),spawn_id TEXT NOT NULL,ship_def_id TEXT NOT NULL,
phase TEXT NOT NULL DEFAULT 'active' CHECK(phase IN('active','released','lost')),
sector_id TEXT NOT NULL,site_id TEXT NOT NULL,cargo_units INTEGER NOT NULL DEFAULT 0 CHECK(cargo_units>=0),
goal_x REAL NOT NULL,goal_y REAL NOT NULL,goal_z REAL NOT NULL,moved_distance_m REAL NOT NULL DEFAULT 0 CHECK(moved_distance_m>=0),lost_tick INTEGER NOT NULL DEFAULT 0 CHECK(lost_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,war_id) REFERENCES march_state(snapshot_id,world_id,content_snapshot_id,war_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(content_snapshot_id,spawn_id) REFERENCES frozen_npc_spawn_defs(content_snapshot_id,spawn_id),FOREIGN KEY(content_snapshot_id,ship_def_id) REFERENCES frozen_ship_defs(content_snapshot_id,ship_id),FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id)) STRICT;

CREATE TRIGGER march_member_state_insert_immutable BEFORE INSERT ON march_member_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_member_state_update_immutable BEFORE UPDATE ON march_member_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_member_state_delete_immutable BEFORE DELETE ON march_member_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_member_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM march_member_state WHERE snapshot_id=NEW.snapshot_id AND (abs(goal_x)>=1e100 OR abs(goal_y)>=1e100 OR abs(goal_z)>=1e100 OR abs(moved_distance_m)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite march scalar'); END;

CREATE TABLE march_journal_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,source_token TEXT NOT NULL,war_id TEXT NOT NULL,attempt INTEGER NOT NULL CHECK(attempt>=1),
event_kind TEXT NOT NULL CHECK(event_kind IN('start','site_departure','site_arrival','gate','blocked','retreat','return','member_loss','cargo_transfer','finish','cancel')),
sector_id TEXT NOT NULL,endpoint_id TEXT,completed_legs INTEGER NOT NULL CHECK(completed_legs>=0),direction INTEGER NOT NULL CHECK(direction IN(-1,1)),npc_instance_id TEXT,
material_units INTEGER NOT NULL DEFAULT 0 CHECK(material_units>=0),mass_kg REAL NOT NULL DEFAULT 0 CHECK(mass_kg>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,source_token),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_march_campaign_defs(content_snapshot_id,war_id),FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),FOREIGN KEY(content_snapshot_id,endpoint_id) REFERENCES frozen_gate_endpoint_defs(content_snapshot_id,endpoint_id)) STRICT;

CREATE TRIGGER march_journal_state_insert_immutable BEFORE INSERT ON march_journal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_journal_state_update_immutable BEFORE UPDATE ON march_journal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_journal_state_delete_immutable BEFORE DELETE ON march_journal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_journal_state_finite BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM march_journal_state WHERE snapshot_id=NEW.snapshot_id AND (abs(mass_kg)>=1e100)) BEGIN SELECT RAISE(ABORT,'nonfinite march scalar'); END;

CREATE TABLE growth_goal_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,player_id TEXT NOT NULL,faction_id TEXT,stage_id TEXT,revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),selected_tick INTEGER NOT NULL DEFAULT 0 CHECK(selected_tick>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,player_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id),FOREIGN KEY(content_snapshot_id,stage_id) REFERENCES frozen_growth_stage_defs(content_snapshot_id,stage_id)) STRICT;

CREATE TRIGGER growth_goal_state_insert_immutable BEFORE INSERT ON growth_goal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER growth_goal_state_update_immutable BEFORE UPDATE ON growth_goal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER growth_goal_state_delete_immutable BEFORE DELETE ON growth_goal_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE growth_milestone_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,stage_id TEXT NOT NULL,observed_tick INTEGER NOT NULL CHECK(observed_tick>=0),credit_at_observation INTEGER NOT NULL CHECK(credit_at_observation>=0),reputation_at_observation INTEGER NOT NULL CHECK(reputation_at_observation>=0),owned_hulls_at_observation INTEGER NOT NULL CHECK(owned_hulls_at_observation>=0),PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,stage_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,stage_id) REFERENCES frozen_growth_stage_defs(content_snapshot_id,stage_id)) STRICT;

CREATE TRIGGER growth_milestone_state_insert_immutable BEFORE INSERT ON growth_milestone_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER growth_milestone_state_update_immutable BEFORE UPDATE ON growth_milestone_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER growth_milestone_state_delete_immutable BEFORE DELETE ON growth_milestone_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER march_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_march_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND (EXISTS(SELECT 1 FROM march_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM march_member_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM march_journal_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM growth_goal_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM growth_milestone_state WHERE snapshot_id=NEW.snapshot_id)) BEGIN SELECT RAISE(ABORT,'march state under legacy rules'); END;

DROP TRIGGER spatial_context_seal_validation;
CREATE TRIGGER spatial_context_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM spatial_state p JOIN frozen_site_defs d USING(content_snapshot_id,site_id)
  WHERE p.snapshot_id=NEW.snapshot_id AND NOT (
   (p.entity_kind='ship' AND EXISTS(SELECT 1 FROM ship_state s WHERE s.snapshot_id=p.snapshot_id AND s.ship_instance_id=p.entity_id AND s.sector_id=d.sector_id)) OR
   (p.entity_kind='npc' AND EXISTS(SELECT 1 FROM npc_state n WHERE n.snapshot_id=p.snapshot_id AND n.npc_instance_id=p.entity_id AND n.sector_id=d.sector_id)) OR
   (p.entity_kind='wreck' AND EXISTS(SELECT 1 FROM container_state c WHERE c.snapshot_id=p.snapshot_id AND c.container_id=p.entity_id AND c.kind='wreck' AND c.sector_id=d.sector_id))))
 THEN RAISE(ABORT,'orphan or wrong-sector spatial context') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_site_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND (
  EXISTS(SELECT 1 FROM ship_state s WHERE s.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM spatial_state p WHERE p.snapshot_id=s.snapshot_id AND p.entity_kind='ship' AND p.entity_id=s.ship_instance_id)) OR
  EXISTS(SELECT 1 FROM npc_state n WHERE n.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM spatial_state p WHERE p.snapshot_id=n.snapshot_id AND p.entity_kind='npc' AND p.entity_id=n.npc_instance_id)) OR
  EXISTS(SELECT 1 FROM container_state c WHERE c.snapshot_id=NEW.snapshot_id AND c.kind='wreck' AND NOT EXISTS(SELECT 1 FROM spatial_state p WHERE p.snapshot_id=c.snapshot_id AND p.entity_kind='wreck' AND p.entity_id=c.container_id)))
 THEN RAISE(ABORT,'missing spatial context') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM spatial_state p JOIN npc_state n ON n.snapshot_id=p.snapshot_id AND n.npc_instance_id=p.entity_id
  JOIN frozen_npc_spawn_defs d ON d.content_snapshot_id=n.content_snapshot_id AND d.spawn_id=n.spawn_id
  JOIN frozen_anchor_site_defs a ON a.content_snapshot_id=d.content_snapshot_id AND a.anchor_id=d.anchor_id
  WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='npc' AND NOT EXISTS(SELECT 1 FROM hire_contract_state h JOIN frozen_hire_profile_defs profile USING(content_snapshot_id,profile_id)
 WHERE h.snapshot_id=n.snapshot_id AND h.npc_instance_id=n.npc_instance_id AND h.phase IN('deployed','retreating') AND profile.spawn_id=n.spawn_id
 AND h.player_id=(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id) AND h.sector_id=n.sector_id AND h.site_id=p.site_id) AND NOT EXISTS(SELECT 1 FROM fleet_deployment_state f JOIN ship_state ship ON ship.snapshot_id=f.snapshot_id AND ship.ship_instance_id=f.ship_instance_id JOIN frozen_fleet_hull_defs hull ON hull.content_snapshot_id=ship.content_snapshot_id AND hull.ship_id=ship.ship_def_id WHERE f.snapshot_id=n.snapshot_id AND f.npc_instance_id=n.npc_instance_id AND f.npc_instance_id=f.ship_instance_id AND f.phase IN('deployed','retreating') AND ship.policy_id='normal_owned' AND ship.owner_player_id=(SELECT player_id FROM player_state WHERE snapshot_id=f.snapshot_id) AND hull.spawn_id=n.spawn_id AND f.sector_id=n.sector_id AND f.site_id=p.site_id) AND NOT EXISTS(SELECT 1 FROM march_member_state m JOIN march_state march ON march.snapshot_id=m.snapshot_id AND march.war_id=m.war_id AND march.attempt=m.attempt JOIN war_campaign_state war ON war.snapshot_id=m.snapshot_id AND war.war_id=m.war_id AND war.attempt=m.attempt JOIN war_fleet_state fleet ON fleet.snapshot_id=m.snapshot_id AND fleet.npc_instance_id=m.npc_instance_id AND fleet.war_id=m.war_id JOIN frozen_civilization_war_members member ON member.content_snapshot_id=m.content_snapshot_id AND member.war_id=m.war_id AND member.spawn_id=m.spawn_id WHERE m.snapshot_id=n.snapshot_id AND m.npc_instance_id=n.npc_instance_id AND m.spawn_id=n.spawn_id AND m.sector_id=n.sector_id AND m.site_id=p.site_id AND n.generation=m.attempt AND fleet.side='ally' AND member.side='ally') AND p.site_id<>coalesce((SELECT mapped.site_id FROM exploration_belt_state b
 JOIN frozen_exploration_belt_anchor_defs m ON m.content_snapshot_id=b.content_snapshot_id AND m.route_id=b.route_id AND m.base_anchor_id=d.anchor_id
 JOIN frozen_anchor_site_defs mapped ON mapped.content_snapshot_id=m.content_snapshot_id AND mapped.anchor_id=m.anchor_id
 WHERE b.snapshot_id=n.snapshot_id),a.site_id))
 THEN RAISE(ABORT,'NPC site differs from frozen spawn') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM spatial_state p JOIN ship_state s ON s.snapshot_id=p.snapshot_id AND s.ship_instance_id=p.entity_id
  JOIN frozen_station_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.station_id=s.station_id
  JOIN frozen_anchor_site_defs a ON a.content_snapshot_id=d.content_snapshot_id AND a.anchor_id=d.station_anchor_id
  WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='ship' AND s.status='docked' AND p.site_id<>a.site_id)
 THEN RAISE(ABORT,'docked ship site differs from frozen station') END;
END;

CREATE TABLE database_meta_format26(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=26)) STRICT;
INSERT INTO database_meta_format26 SELECT singleton,application_id,26 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format26 RENAME TO database_meta;PRAGMA user_version=26;
