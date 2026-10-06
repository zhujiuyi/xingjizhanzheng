-- Format7 -> 8: immutable astronomical site/anchor/celestial definitions.
-- Spatial state and format8 seal rules are appended by the integration owner.

CREATE TABLE frozen_site_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    site_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    site_kind TEXT NOT NULL CHECK(site_kind IN ('station','gate','resource','signal','encounter')),
    x_m REAL NOT NULL CHECK(abs(x_m)<1e15),
    y_m REAL NOT NULL CHECK(abs(y_m)<1e15),
    z_m REAL NOT NULL CHECK(abs(z_m)<1e15),
    pivot_x_m REAL NOT NULL CHECK(abs(pivot_x_m)<1e6),
    pivot_y_m REAL NOT NULL CHECK(abs(pivot_y_m)<1e6),
    pivot_z_m REAL NOT NULL CHECK(abs(pivot_z_m)<1e6),
    local_radius_m REAL NOT NULL CHECK(local_radius_m>0 AND local_radius_m<=1e6),
    UNIQUE (content_snapshot_id, site_id,sector_id),
    PRIMARY KEY (content_snapshot_id, site_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id)
) STRICT;
CREATE TRIGGER frozen_site_defs_insert_guard BEFORE INSERT ON frozen_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_site_defs_update_guard BEFORE UPDATE ON frozen_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_site_defs_delete_guard BEFORE DELETE ON frozen_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_anchor_site_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    anchor_id TEXT NOT NULL,
    site_id TEXT NOT NULL,
    PRIMARY KEY (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, anchor_id) REFERENCES frozen_anchor_defs (content_snapshot_id, anchor_id),
    FOREIGN KEY (content_snapshot_id, site_id) REFERENCES frozen_site_defs (content_snapshot_id, site_id)
) STRICT;
CREATE TRIGGER frozen_anchor_site_defs_insert_guard BEFORE INSERT ON frozen_anchor_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_anchor_site_defs_update_guard BEFORE UPDATE ON frozen_anchor_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_anchor_site_defs_delete_guard BEFORE DELETE ON frozen_anchor_site_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE frozen_celestial_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    celestial_id TEXT NOT NULL,
    sector_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    celestial_kind TEXT NOT NULL CHECK(celestial_kind IN ('star','planet')),
    x_m REAL NOT NULL CHECK(abs(x_m)<1e15),
    y_m REAL NOT NULL CHECK(abs(y_m)<1e15),
    z_m REAL NOT NULL CHECK(abs(z_m)<1e15),
    radius_m REAL NOT NULL CHECK(radius_m>0 AND radius_m<1e11),
    PRIMARY KEY (content_snapshot_id, celestial_id),
    FOREIGN KEY (content_snapshot_id, sector_id) REFERENCES frozen_sector_defs (content_snapshot_id, sector_id)
) STRICT;
CREATE TRIGGER frozen_celestial_defs_insert_guard BEFORE INSERT ON frozen_celestial_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_celestial_defs_update_guard BEFORE UPDATE ON frozen_celestial_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_celestial_defs_delete_guard BEFORE DELETE ON frozen_celestial_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;

CREATE TABLE spatial_state (
    snapshot_id TEXT NOT NULL, world_id TEXT NOT NULL, content_snapshot_id TEXT NOT NULL,
    entity_kind TEXT NOT NULL CHECK(entity_kind IN ('ship','npc','wreck')),
    entity_id TEXT NOT NULL,
    site_id TEXT NOT NULL,
    PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,entity_kind,entity_id),
    FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,
    FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id)
) STRICT;
CREATE TRIGGER spatial_state_insert_immutable BEFORE INSERT ON spatial_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;
CREATE TRIGGER spatial_state_update_immutable BEFORE UPDATE ON spatial_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;
CREATE TRIGGER spatial_state_delete_immutable BEFORE DELETE ON spatial_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;
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
  WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='npc' AND p.site_id<>a.site_id)
 THEN RAISE(ABORT,'NPC site differs from frozen spawn') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM spatial_state p JOIN ship_state s ON s.snapshot_id=p.snapshot_id AND s.ship_instance_id=p.entity_id
  JOIN frozen_station_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.station_id=s.station_id
  JOIN frozen_anchor_site_defs a ON a.content_snapshot_id=d.content_snapshot_id AND a.anchor_id=d.station_anchor_id
  WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='ship' AND s.status='docked' AND p.site_id<>a.site_id)
 THEN RAISE(ABORT,'docked ship site differs from frozen station') END;
END;
CREATE TABLE database_meta_format8 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=8)
) STRICT;
INSERT INTO database_meta_format8 SELECT singleton,application_id,8 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format8 RENAME TO database_meta;
PRAGMA user_version=8;

-- Re-register the full existing seal guard; only hostile locality changes.
-- Format4 -> 5: every reviewed engine family preserves its paid active cycle.
DROP TRIGGER snapshot_seal_validation;
-- Defense in depth at the building->sealed boundary. Aggregated budgets and
-- finite DTO validation remain required by SaveService before these SQL guards.
CREATE TRIGGER snapshot_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed'
BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM runtime_session WHERE world_id=NEW.world_id
  AND session_id=NEW.writer_session_id AND epoch=NEW.writer_epoch
  AND (transfer_barrier_id IS NULL OR transfer_barrier_id=NEW.transfer_id))
  THEN RAISE(ABORT,'stale session at seal') END;
 SELECT CASE WHEN (SELECT count(*) FROM player_state WHERE snapshot_id=NEW.snapshot_id)<>1
  THEN RAISE(ABORT,'offline snapshot requires exactly one player') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM player_state p LEFT JOIN ship_state s
  ON s.snapshot_id=p.snapshot_id AND s.world_id=p.world_id AND s.content_snapshot_id=p.content_snapshot_id
  AND s.ship_instance_id=p.controlled_ship_id AND s.owner_player_id=p.player_id
  WHERE p.snapshot_id=NEW.snapshot_id AND (s.status IS NULL OR s.status NOT IN ('flying','docked') OR s.hull<=0))
  THEN RAISE(ABORT,'controlled ship is not owned and drivable') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM rng_state WHERE snapshot_id=NEW.snapshot_id AND stream_id='world')
  THEN RAISE(ABORT,'world RNG state missing') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_state n WHERE n.snapshot_id=NEW.snapshot_id AND n.behavior_phase IN ('acquire','pursue','attack','disengage')
  AND (NOT EXISTS(SELECT 1 FROM frozen_site_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
    OR EXISTS(SELECT 1 FROM spatial_state np JOIN spatial_state sp ON sp.snapshot_id=np.snapshot_id AND sp.site_id=np.site_id AND sp.entity_kind='ship'
     JOIN player_state pl ON pl.snapshot_id=sp.snapshot_id AND pl.controlled_ship_id=sp.entity_id
     WHERE np.snapshot_id=n.snapshot_id AND np.entity_kind='npc' AND np.entity_id=n.npc_instance_id)))
  THEN RAISE(ABORT,'active hostile AI cannot be saved in B') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_resource_node_defs d WHERE d.content_snapshot_id=NEW.content_snapshot_id
  AND NOT EXISTS(SELECT 1 FROM resource_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.node_id=d.node_id))
  THEN RAISE(ABORT,'resource snapshot incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_connection_defs d WHERE d.content_snapshot_id=NEW.content_snapshot_id
  AND NOT EXISTS(SELECT 1 FROM gate_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.connection_id=d.connection_id))
  THEN RAISE(ABORT,'gate snapshot incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_sector_defs d WHERE d.content_snapshot_id=NEW.content_snapshot_id
  AND NOT EXISTS(SELECT 1 FROM sector_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.sector_id=d.sector_id))
  THEN RAISE(ABORT,'sector snapshot incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_station_stock_defs d WHERE d.content_snapshot_id=NEW.content_snapshot_id
  AND NOT EXISTS(SELECT 1 FROM shop_stock_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.station_id=d.station_id AND s.item_def_id=d.item_id))
  THEN RAISE(ABORT,'item shop snapshot incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_station_ship_stock_defs d WHERE d.content_snapshot_id=NEW.content_snapshot_id
  AND NOT EXISTS(SELECT 1 FROM shop_ship_stock_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.station_id=d.station_id AND s.ship_def_id=d.ship_id))
  THEN RAISE(ABORT,'ship shop snapshot incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_station_defs d WHERE d.content_snapshot_id=NEW.content_snapshot_id
  AND NOT EXISTS(SELECT 1 FROM station_economy_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.station_id=d.station_id))
  THEN RAISE(ABORT,'station economy snapshot incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM item_instance_state i JOIN container_state c
  ON c.snapshot_id=i.snapshot_id AND c.container_id=i.container_id
  WHERE i.snapshot_id=NEW.snapshot_id AND c.kind='slot' AND NOT EXISTS
   (SELECT 1 FROM equipment_state e WHERE e.snapshot_id=i.snapshot_id AND e.item_instance_id=i.item_instance_id AND e.slot_container_id=i.container_id))
  THEN RAISE(ABORT,'installed item lacks equipment row') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM equipment_state e JOIN container_state c
  ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
  JOIN frozen_module_defs m ON m.content_snapshot_id=e.content_snapshot_id AND m.module_id=e.module_def_id
  WHERE e.snapshot_id=NEW.snapshot_id AND (c.kind<>'slot' OR c.slot_type<>m.slot_type))
  THEN RAISE(ABORT,'equipment slot mismatch') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM equipment_state WHERE snapshot_id=NEW.snapshot_id
  AND active_remaining_s>0 AND NOT EXISTS (SELECT 1 FROM frozen_module_group_members g
  WHERE g.content_snapshot_id=NEW.content_snapshot_id AND g.module_id=equipment_state.module_def_id AND g.group_id='engine'))
  THEN RAISE(ABORT,'unfinished interaction/attack cannot be saved in B') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM equipment_state e JOIN frozen_module_defs d
  ON d.content_snapshot_id=e.content_snapshot_id AND d.module_id=e.module_def_id
  WHERE e.snapshot_id=NEW.snapshot_id AND (e.active_remaining_s>d.cycle_s OR e.cooldown_remaining_s>d.cycle_s))
  THEN RAISE(ABORT,'module timer over cycle duration') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM mission_state m WHERE m.snapshot_id=NEW.snapshot_id
  AND m.reward_claimed=1 AND NOT EXISTS(SELECT 1 FROM mission_claim_state c
  WHERE c.snapshot_id=m.snapshot_id AND c.mission_instance_id=m.mission_instance_id))
  THEN RAISE(ABORT,'reward claim receipt missing') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM loan_state l WHERE l.snapshot_id=NEW.snapshot_id
  AND l.status IN ('active','handoff_pending') AND NOT EXISTS(SELECT 1 FROM loan_issue_state i
  WHERE i.snapshot_id=l.snapshot_id AND i.loan_id=l.loan_id AND i.ship_instance_id=l.current_ship_id AND i.status='active'))
  THEN RAISE(ABORT,'active loan generation missing') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM resource_state s JOIN frozen_resource_node_defs d
  ON d.content_snapshot_id=s.content_snapshot_id AND d.node_id=s.node_id
  WHERE s.snapshot_id=NEW.snapshot_id AND s.remaining_units>d.capacity_units)
  THEN RAISE(ABORT,'resource over capacity') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM mission_window_state s JOIN frozen_mission_defs d
  ON d.content_snapshot_id=s.content_snapshot_id AND d.mission_id=s.mission_def_id
  JOIN frozen_rule_parameters r ON r.content_snapshot_id=s.content_snapshot_id AND r.parameter_id='contract_max_accepts_per_window'
  WHERE s.snapshot_id=NEW.snapshot_id AND (s.completed_window_count>d.max_completions_per_window
  OR s.accepted_window_count>r.value_integer OR s.remaining_s>d.repeat_window_s))
  THEN RAISE(ABORT,'contract window over budget') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM loan_state s JOIN frozen_loan_service_defs d
  ON d.content_snapshot_id=s.content_snapshot_id AND d.loan_service_id=s.loan_service_id
  WHERE s.snapshot_id=NEW.snapshot_id AND ((s.quota_remaining_units IS NULL)<>(d.operation_quota_units IS NULL)
  OR s.quota_remaining_units>d.operation_quota_units))
  THEN RAISE(ABORT,'loan quota over definition') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM loan_state s JOIN frozen_loan_service_defs d
  ON d.content_snapshot_id=s.content_snapshot_id AND d.loan_service_id=s.loan_service_id
  JOIN mission_state m ON m.snapshot_id=s.snapshot_id AND m.mission_instance_id=s.mission_instance_id
  WHERE s.snapshot_id=NEW.snapshot_id AND m.mission_def_id<>d.required_mission_id)
  THEN RAISE(ABORT,'loan service does not match attempt') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM loan_state s WHERE s.snapshot_id=NEW.snapshot_id AND s.issuance_count<>
  (SELECT count(*) FROM loan_issue_state i WHERE i.snapshot_id=s.snapshot_id AND i.loan_id=s.loan_id))
  THEN RAISE(ABORT,'loan issuance history incomplete') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM inventory_stack_state s WHERE s.snapshot_id=NEW.snapshot_id AND
  ((s.origin_kind='normal' AND s.policy_id<>'normal_owned') OR (s.origin_kind='mission_bound' AND s.policy_id<>'mission_bound')
   OR (s.origin_kind IN ('guarantee','loan') AND s.policy_id<>'tutorial_protected')))
  THEN RAISE(ABORT,'stack origin and frozen policy disagree') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM shop_stock_state s JOIN frozen_station_stock_defs d
  ON d.content_snapshot_id=s.content_snapshot_id AND d.station_id=s.station_id AND d.item_id=s.item_def_id
  WHERE s.snapshot_id=NEW.snapshot_id AND (s.quantity>d.hard_cap_units OR s.buyback_remaining_units>d.buyback_units_per_refresh))
  THEN RAISE(ABORT,'item stock/buyback over cap') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM shop_ship_stock_state s JOIN frozen_station_ship_stock_defs d
  ON d.content_snapshot_id=s.content_snapshot_id AND d.station_id=s.station_id AND d.ship_id=s.ship_def_id
  WHERE s.snapshot_id=NEW.snapshot_id AND s.quantity>d.hard_cap_units)
  THEN RAISE(ABORT,'ship stock over cap') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM station_economy_state s JOIN frozen_station_defs d
  ON d.content_snapshot_id=s.content_snapshot_id AND d.station_id=s.station_id
  WHERE s.snapshot_id=NEW.snapshot_id AND s.buyback_remaining_credit>d.buyback_budget_credit)
  THEN RAISE(ABORT,'station buyback budget over cap') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM item_instance_state i JOIN frozen_rule_parameters r
  ON r.content_snapshot_id=i.content_snapshot_id AND r.parameter_id='module_durability_max'
  WHERE i.snapshot_id=NEW.snapshot_id AND i.durability>r.value_integer)
  THEN RAISE(ABORT,'durability over maximum') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM item_instance_state i WHERE i.snapshot_id=NEW.snapshot_id
  AND i.origin_kind='manufacture' AND NOT EXISTS(SELECT 1 FROM manufacture_input_state m
   WHERE m.snapshot_id=i.snapshot_id AND m.item_instance_id=i.item_instance_id))
  THEN RAISE(ABORT,'manufactured item input origin missing') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM item_instance_state i JOIN frozen_recipe_defs r
  ON r.content_snapshot_id=i.content_snapshot_id AND r.recipe_id=i.salvage_recipe_id
  WHERE i.snapshot_id=NEW.snapshot_id AND r.output_item_id<>i.item_def_id)
  THEN RAISE(ABORT,'salvage recipe does not make item') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM item_instance_state i WHERE i.snapshot_id=NEW.snapshot_id AND i.origin_kind='loan'
  AND NOT EXISTS(SELECT 1 FROM loan_asset_state a WHERE a.snapshot_id=i.snapshot_id AND a.item_instance_id=i.item_instance_id))
  THEN RAISE(ABORT,'loan item missing contract') END;
 SELECT CASE WHEN NEW.reason IN ('travel_origin','travel_destination') AND NOT EXISTS
  (SELECT 1 FROM transfer_state t WHERE t.snapshot_id=NEW.snapshot_id AND t.transfer_id=NEW.transfer_id
   AND t.endpoint=CASE NEW.reason WHEN 'travel_origin' THEN 'origin' ELSE 'destination' END)
  THEN RAISE(ABORT,'travel endpoint receipt missing') END;
END;
