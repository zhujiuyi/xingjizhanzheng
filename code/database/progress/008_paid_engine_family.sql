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
 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_state WHERE snapshot_id=NEW.snapshot_id AND behavior_phase IN ('acquire','pursue','attack','disengage'))
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

CREATE TABLE database_meta_format5 (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
 format_version INTEGER NOT NULL CHECK(format_version=5)
) STRICT;
INSERT INTO database_meta_format5 SELECT singleton,application_id,5 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format5 RENAME TO database_meta;
PRAGMA user_version=5;
