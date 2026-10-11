-- Reviewed finite hired companions, movement binding and actual settlements.

CREATE TABLE frozen_hire_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    max_companions INTEGER NOT NULL CHECK(max_companions=1),
    formation_m REAL NOT NULL CHECK(formation_m>0),
    communication_m REAL NOT NULL CHECK(communication_m>formation_m),
    warp_ready_m REAL NOT NULL CHECK(warp_ready_m>=formation_m AND warp_ready_m<communication_m),
    retreat_distance_m REAL NOT NULL CHECK(retreat_distance_m>warp_ready_m),
    retreat_charge_s REAL NOT NULL CHECK(retreat_charge_s>0),
    return_s REAL NOT NULL CHECK(return_s>0),
    warning_s REAL NOT NULL CHECK(warning_s>0),
    support_range_m REAL NOT NULL CHECK(support_range_m>formation_m),
    support_cycle_s REAL NOT NULL CHECK(support_cycle_s>0),
    support_shield REAL NOT NULL CHECK(support_shield>0),
    support_armor REAL NOT NULL CHECK(support_armor>0),
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_hire_balance_defs_insert_guard BEFORE INSERT ON frozen_hire_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_hire_balance_defs_update_guard BEFORE UPDATE ON frozen_hire_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_hire_balance_defs_delete_guard BEFORE DELETE ON frozen_hire_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_hire_profile_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    profile_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    role_id TEXT NOT NULL CHECK(role_id IN('escort','support')),
    hull_id TEXT NOT NULL,
    spawn_id TEXT NOT NULL,
    hire_fee_credit INTEGER NOT NULL CHECK(hire_fee_credit>0),
    deposit_credit INTEGER NOT NULL CHECK(deposit_credit>0),
    lease_s REAL NOT NULL CHECK(lease_s>0),
    support_cycles INTEGER NOT NULL CHECK(support_cycles>=0),
    CHECK((role_id='escort' AND support_cycles=0) OR (role_id='support' AND support_cycles>0)),
    PRIMARY KEY (content_snapshot_id, profile_id),
    FOREIGN KEY (content_snapshot_id, hull_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, spawn_id) REFERENCES frozen_npc_spawn_defs (content_snapshot_id, spawn_id),
    UNIQUE (content_snapshot_id, spawn_id)
) STRICT;
CREATE TRIGGER frozen_hire_profile_defs_insert_guard BEFORE INSERT ON frozen_hire_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_hire_profile_defs_update_guard BEFORE UPDATE ON frozen_hire_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_hire_profile_defs_delete_guard BEFORE DELETE ON frozen_hire_profile_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE hire_contract_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,contract_id TEXT NOT NULL,player_id TEXT NOT NULL,profile_id TEXT NOT NULL,origin_station_id TEXT NOT NULL,
 phase TEXT NOT NULL CHECK(phase IN('deployed','retreating','returning','returned','lost')),npc_instance_id TEXT,
 sector_id TEXT NOT NULL,site_id TEXT NOT NULL,
 order_kind TEXT NOT NULL CHECK(order_kind IN('advance','regroup','focus','retreat')),order_revision INTEGER NOT NULL DEFAULT 0 CHECK(order_revision>=0),focus_target_id TEXT,
 lease_remaining_s REAL NOT NULL CHECK(lease_remaining_s>=0),return_remaining_s REAL NOT NULL DEFAULT 0 CHECK(return_remaining_s>=0),retreat_remaining_s REAL NOT NULL DEFAULT 0 CHECK(retreat_remaining_s>=0),
 goal_x REAL NOT NULL DEFAULT 0,goal_y REAL NOT NULL DEFAULT 0,goal_z REAL NOT NULL DEFAULT 0,
 retreat_origin_x REAL NOT NULL DEFAULT 0,retreat_origin_y REAL NOT NULL DEFAULT 0,retreat_origin_z REAL NOT NULL DEFAULT 0,
 fee_paid_credit INTEGER NOT NULL CHECK(fee_paid_credit>0),deposit_paid_credit INTEGER NOT NULL CHECK(deposit_paid_credit>0),
 condition_ratio REAL NOT NULL DEFAULT 1 CHECK(condition_ratio>=0 AND condition_ratio<=1),refund_credit INTEGER NOT NULL DEFAULT 0 CHECK(refund_credit>=0),
 support_cycles_remaining INTEGER NOT NULL CHECK(support_cycles_remaining>=0),support_cooldown_s REAL NOT NULL DEFAULT 0 CHECK(support_cooldown_s>=0),
 expiry_warned INTEGER NOT NULL DEFAULT 0 CHECK(expiry_warned IN(0,1)),end_reason TEXT NOT NULL DEFAULT '',created_tick INTEGER NOT NULL CHECK(created_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0),
 CHECK((phase IN('deployed','retreating') AND npc_instance_id IS NOT NULL) OR (phase IN('returning','returned','lost') AND npc_instance_id IS NULL)),
 CHECK((phase='returned') OR refund_credit=0),CHECK((order_kind='focus') OR focus_target_id IS NULL),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,contract_id),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(content_snapshot_id,profile_id) REFERENCES frozen_hire_profile_defs(content_snapshot_id,profile_id),
 FOREIGN KEY(content_snapshot_id,origin_station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id),
 FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id)) STRICT;

CREATE TRIGGER hire_contract_state_insert_immutable BEFORE INSERT ON hire_contract_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER hire_contract_state_update_immutable BEFORE UPDATE ON hire_contract_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER hire_contract_state_delete_immutable BEFORE DELETE ON hire_contract_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE hire_receipt_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,source_token TEXT NOT NULL,contract_id TEXT NOT NULL,event_kind TEXT NOT NULL CHECK(event_kind IN('hire','return','loss')),
 paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),refund_credit INTEGER NOT NULL DEFAULT 0 CHECK(refund_credit>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,source_token),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,contract_id) REFERENCES hire_contract_state(snapshot_id,world_id,content_snapshot_id,contract_id)) STRICT;

CREATE TRIGGER hire_receipt_state_insert_immutable BEFORE INSERT ON hire_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER hire_receipt_state_update_immutable BEFORE UPDATE ON hire_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER hire_receipt_state_delete_immutable BEFORE DELETE ON hire_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE UNIQUE INDEX hire_actor_unique ON hire_contract_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id) WHERE npc_instance_id IS NOT NULL;

CREATE UNIQUE INDEX hire_payment_once ON hire_receipt_state(snapshot_id,world_id,content_snapshot_id,contract_id) WHERE event_kind='hire';

CREATE UNIQUE INDEX hire_outcome_once ON hire_receipt_state(snapshot_id,world_id,content_snapshot_id,contract_id) WHERE event_kind IN('return','loss');

CREATE TRIGGER hire_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM frozen_hire_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (EXISTS(SELECT 1 FROM hire_contract_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM hire_receipt_state WHERE snapshot_id=NEW.snapshot_id)) THEN RAISE(ABORT,'hire state under legacy rules') END;
 SELECT CASE WHEN (SELECT count(*) FROM hire_contract_state WHERE snapshot_id=NEW.snapshot_id AND phase IN('deployed','retreating','returning'))>
 (SELECT max_companions FROM frozen_hire_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN RAISE(ABORT,'too many paid companions') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM hire_contract_state h JOIN frozen_hire_profile_defs p USING(content_snapshot_id,profile_id)
 JOIN frozen_hire_balance_defs b USING(content_snapshot_id) JOIN frozen_site_defs site USING(content_snapshot_id,site_id)
 LEFT JOIN npc_state n ON n.snapshot_id=h.snapshot_id AND n.npc_instance_id=h.npc_instance_id
 LEFT JOIN spatial_state s ON s.snapshot_id=h.snapshot_id AND s.entity_kind='npc' AND s.entity_id=h.npc_instance_id
 WHERE h.snapshot_id=NEW.snapshot_id AND (
 h.player_id<>(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id) OR h.fee_paid_credit<>p.hire_fee_credit OR h.deposit_paid_credit<>p.deposit_credit OR
 h.lease_remaining_s>p.lease_s OR h.return_remaining_s>b.return_s OR h.retreat_remaining_s>b.retreat_charge_s OR
 h.support_cycles_remaining>p.support_cycles OR h.support_cooldown_s>b.support_cycle_s OR site.sector_id<>h.sector_id OR
 h.created_tick>NEW.simulation_tick OR h.finished_tick>NEW.simulation_tick OR
 (h.phase IN('deployed','retreating') AND (n.npc_instance_id IS NULL OR n.alive<>1 OR n.generation<>1 OR n.spawn_id<>p.spawn_id OR n.sector_id<>h.sector_id OR s.site_id IS NOT h.site_id)) OR
 (h.phase='deployed' AND (h.order_kind='retreat' OR h.return_remaining_s<>0 OR h.retreat_remaining_s<>0)) OR
 (h.phase='retreating' AND (h.order_kind<>'retreat' OR h.return_remaining_s<>0)) OR
 (h.phase='returning' AND (h.return_remaining_s<=0 OR h.retreat_remaining_s<>0)) OR
 (h.phase IN('deployed','retreating','returning') AND h.finished_tick<>0) OR
 (h.phase IN('returned','lost') AND (h.lease_remaining_s<>0 OR h.return_remaining_s<>0 OR h.retreat_remaining_s<>0 OR h.support_cooldown_s<>0 OR h.finished_tick<h.created_tick)) OR
 (h.phase='returned' AND h.refund_credit<>CAST(h.deposit_paid_credit*h.condition_ratio AS INTEGER)) OR
 (h.phase='lost' AND (h.condition_ratio<>0 OR h.refund_credit<>0)) OR
 (h.order_kind='focus' AND NOT EXISTS(SELECT 1 FROM npc_state enemy WHERE enemy.snapshot_id=h.snapshot_id AND enemy.npc_instance_id=h.focus_target_id AND enemy.alive=1 AND enemy.sector_id=h.sector_id AND enemy.npc_instance_id<>h.npc_instance_id))
 )) THEN RAISE(ABORT,'invalid paid companion binding or lifecycle') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_state n JOIN frozen_hire_profile_defs p ON p.content_snapshot_id=n.content_snapshot_id AND p.spawn_id=n.spawn_id
 WHERE n.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM hire_contract_state h WHERE h.snapshot_id=n.snapshot_id AND h.npc_instance_id=n.npc_instance_id AND h.phase IN('deployed','retreating') AND h.profile_id=p.profile_id)) THEN RAISE(ABORT,'orphan hire actor') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM hire_contract_state h WHERE h.snapshot_id=NEW.snapshot_id AND (
 (SELECT count(*) FROM hire_receipt_state r WHERE r.snapshot_id=h.snapshot_id AND r.contract_id=h.contract_id AND r.event_kind='hire')<>1 OR
 (SELECT count(*) FROM hire_receipt_state r WHERE r.snapshot_id=h.snapshot_id AND r.contract_id=h.contract_id AND r.event_kind IN('return','loss'))<>CASE WHEN h.phase IN('returned','lost') THEN 1 ELSE 0 END)) THEN RAISE(ABORT,'missing or duplicate hire settlement') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM hire_receipt_state r JOIN hire_contract_state h USING(snapshot_id,world_id,content_snapshot_id,contract_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.event_tick>NEW.simulation_tick OR
 (r.event_kind='hire' AND (r.paid_credit<>h.fee_paid_credit+h.deposit_paid_credit OR r.refund_credit<>0 OR r.event_tick<>h.created_tick)) OR
 (r.event_kind='return' AND (h.phase<>'returned' OR r.paid_credit<>0 OR r.refund_credit<>h.refund_credit OR r.event_tick<>h.finished_tick)) OR
 (r.event_kind='loss' AND (h.phase<>'lost' OR r.paid_credit<>0 OR r.refund_credit<>0 OR r.event_tick<>h.finished_tick)))) THEN RAISE(ABORT,'hire payment or refund lacks entitlement') END;
END;

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
 AND h.player_id=(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id) AND h.sector_id=n.sector_id AND h.site_id=p.site_id) AND p.site_id<>coalesce((SELECT mapped.site_id FROM exploration_belt_state b
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
 NOT (EXISTS(SELECT 1 FROM hire_contract_state h JOIN frozen_hire_profile_defs profile USING(content_snapshot_id,profile_id)
 WHERE h.snapshot_id=r.snapshot_id AND h.npc_instance_id=r.target_npc_id AND h.phase IN('deployed','retreating') AND profile.spawn_id=n.spawn_id
 AND h.player_id=(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id)) OR EXISTS(SELECT 1 FROM exploration_actor_state a WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND a.actor_role='escort') OR EXISTS(SELECT 1 FROM war_fleet_state f WHERE f.snapshot_id=r.snapshot_id AND f.npc_instance_id=r.target_npc_id AND f.side='ally') OR EXISTS(SELECT 1 FROM frontier_actor_state a JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
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

CREATE TABLE database_meta_format20(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=20)) STRICT;
INSERT INTO database_meta_format20 SELECT singleton,application_id,20 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format20 RENAME TO database_meta;PRAGMA user_version=20;
