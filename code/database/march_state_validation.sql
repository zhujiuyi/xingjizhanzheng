CREATE TRIGGER march_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building'
 AND EXISTS(SELECT 1 FROM frozen_march_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
BEGIN
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM march_state m
  LEFT JOIN war_campaign_state w ON w.snapshot_id=m.snapshot_id AND w.war_id=m.war_id
  LEFT JOIN frontier_campaign_state f ON f.snapshot_id=m.snapshot_id AND f.war_id=m.war_id
  JOIN frozen_site_defs site ON site.content_snapshot_id=m.content_snapshot_id AND site.site_id=m.site_id
  WHERE m.snapshot_id=NEW.snapshot_id AND (
   w.war_id IS NULL OR f.war_id IS NULL OR m.attempt<>w.attempt OR m.attempt<>f.attempt
   OR m.initial_supply_units<>f.supplies_paid_units OR site.sector_id<>m.sector_id
   OR m.completed_legs>(SELECT count(*) FROM frozen_march_route_defs r WHERE r.content_snapshot_id=m.content_snapshot_id AND r.war_id=m.war_id)
   OR m.initial_supply_units<>m.returned_supply_units+m.lost_supply_units+m.transferred_supply_units+coalesce((SELECT sum(actor.cargo_units) FROM march_member_state actor WHERE actor.snapshot_id=m.snapshot_id AND actor.war_id=m.war_id),0)
   OR (m.phase IN('returned','cancelled') AND w.status<>'cancelled')
   OR (m.phase='failed' AND w.status<>'failed') OR (m.phase='completed' AND w.status<>'won')
   OR (m.phase NOT IN('returned','failed','cancelled','completed') AND w.status NOT IN('assembling','fighting','occupying'))
   OR (SELECT count(*) FROM march_member_state actor WHERE actor.snapshot_id=m.snapshot_id AND actor.war_id=m.war_id)<>
      CASE WHEN m.phase IN('returned','failed','cancelled','completed') THEN 0 ELSE (SELECT count(*) FROM frozen_civilization_war_members original WHERE original.content_snapshot_id=m.content_snapshot_id AND original.war_id=m.war_id AND original.side='ally') END
  )) THEN RAISE(ABORT,'march campaign or supply conservation differs') END;
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM march_member_state m
  JOIN march_state march ON march.snapshot_id=m.snapshot_id AND march.war_id=m.war_id
  JOIN npc_state n ON n.snapshot_id=m.snapshot_id AND n.npc_instance_id=m.npc_instance_id
  JOIN frozen_march_campaign_defs d ON d.content_snapshot_id=m.content_snapshot_id AND d.war_id=m.war_id
  WHERE m.snapshot_id=NEW.snapshot_id AND (
   m.attempt<>march.attempt OR n.generation<>m.attempt OR n.spawn_id<>m.spawn_id OR m.ship_def_id<>d.travel_hull_id
   OR n.sector_id<>m.sector_id OR NOT EXISTS(SELECT 1 FROM spatial_state p WHERE p.snapshot_id=m.snapshot_id AND p.entity_kind='npc' AND p.entity_id=m.npc_instance_id AND p.site_id=m.site_id)
   OR NOT EXISTS(SELECT 1 FROM war_fleet_state fleet JOIN frozen_civilization_war_members original ON original.content_snapshot_id=m.content_snapshot_id AND original.war_id=fleet.war_id AND original.spawn_id=m.spawn_id WHERE fleet.snapshot_id=m.snapshot_id AND fleet.npc_instance_id=m.npc_instance_id AND fleet.war_id=m.war_id AND fleet.side='ally' AND original.side='ally')
   OR (m.phase='lost' AND (n.alive<>0 OR m.cargo_units<>0))
   OR (m.phase NOT IN('lost','gate_wait') AND (n.alive<>1 OR m.sector_id<>march.sector_id OR m.site_id<>march.site_id OR m.completed_legs<>march.completed_legs))
   OR (m.phase='gate_wait' AND (n.alive<>1 OR m.completed_legs<>march.completed_legs+march.direction OR march.phase NOT IN('gate_prepare','gate_transit','blocked') OR NOT EXISTS(
    SELECT 1 FROM frozen_march_route_defs leg JOIN frozen_gate_endpoint_defs e ON e.content_snapshot_id=leg.content_snapshot_id AND e.endpoint_id=CASE march.direction WHEN 1 THEN leg.endpoint_id ELSE leg.reverse_endpoint_id END
    JOIN frozen_anchor_site_defs site ON site.content_snapshot_id=e.content_snapshot_id AND site.anchor_id=e.exit_anchor_id
    WHERE leg.content_snapshot_id=m.content_snapshot_id AND leg.war_id=m.war_id AND leg.leg_index=CASE march.direction WHEN 1 THEN march.completed_legs ELSE march.completed_legs-1 END AND m.sector_id=e.target_sector_id AND m.site_id=site.site_id)))
   OR (m.phase='gate_transit' AND (march.phase<>'gate_transit' OR coalesce(march.gate_actor_id,'')<>m.npc_instance_id))
   OR (m.cargo_units>0 AND m.spawn_id<>d.supply_carrier_spawn_id)
  )) THEN RAISE(ABORT,'march original actor binding differs') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM march_state march WHERE march.snapshot_id=NEW.snapshot_id AND (
  (march.phase IN('gate_prepare','gate_transit') AND march.gate_actor_id IS NULL)
  OR (march.gate_actor_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM march_member_state m WHERE m.snapshot_id=march.snapshot_id AND m.npc_instance_id=march.gate_actor_id AND m.war_id=march.war_id AND m.phase=CASE WHEN march.phase='gate_transit' THEN 'gate_transit' ELSE 'active' END AND march.phase IN('gate_prepare','gate_transit','blocked')))))
 THEN RAISE(ABORT,'march gate selection differs') END;
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM growth_goal_state g LEFT JOIN frozen_growth_stage_defs stage ON stage.content_snapshot_id=g.content_snapshot_id AND stage.stage_id=g.stage_id
  WHERE g.snapshot_id=NEW.snapshot_id AND (g.player_id<>(SELECT player_id FROM player_state WHERE snapshot_id=g.snapshot_id)
   OR g.selected_tick>NEW.simulation_tick OR (g.stage_id IS NOT NULL AND (stage.stage_id IS NULL OR (stage.faction_id IS NOT NULL AND coalesce(g.faction_id,'')<>stage.faction_id)))))
 THEN RAISE(ABORT,'growth selection owner or context differs') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM growth_milestone_state WHERE snapshot_id=NEW.snapshot_id AND observed_tick>NEW.simulation_tick)
 THEN RAISE(ABORT,'growth observation is in the future') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM growth_grant_receipt_state r
  JOIN frozen_growth_grant_defs g ON g.content_snapshot_id=r.content_snapshot_id AND g.task_id=r.task_id
  JOIN frozen_civilization_honor_task_defs task ON task.content_snapshot_id=r.content_snapshot_id AND task.task_id=r.task_id
  WHERE r.snapshot_id=NEW.snapshot_id AND (r.faction_id<>task.faction_id OR r.paid_credit<>g.reward_credit OR r.awarded_reputation<>g.reward_reputation OR r.claimed_tick>NEW.simulation_tick
   OR coalesce((SELECT sum(e.credited_units) FROM civilization_honor_evidence_state e WHERE e.snapshot_id=r.snapshot_id AND e.task_id=r.task_id),0)<task.required_units))
 THEN RAISE(ABORT,'growth grant lacks frozen award or actual proof') END;
END;
