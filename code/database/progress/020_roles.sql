-- Reviewed existing-hull support, scouting and entrusted freight.

CREATE TABLE frozen_ship_role_capability_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    ship_id TEXT NOT NULL,
    survey_multiplier REAL NOT NULL CHECK(survey_multiplier>=1),
    sensor_multiplier REAL NOT NULL CHECK(sensor_multiplier>=1),
    remote_repair_allowed INTEGER NOT NULL CHECK(remote_repair_allowed IN (0,1)),
    remote_range_multiplier REAL NOT NULL CHECK(remote_range_multiplier>=1),
    remote_shield_multiplier REAL NOT NULL CHECK(remote_shield_multiplier>0),
    remote_armor_multiplier REAL NOT NULL CHECK(remote_armor_multiplier>0),
    PRIMARY KEY (content_snapshot_id, ship_id),
    FOREIGN KEY (content_snapshot_id, ship_id) REFERENCES frozen_ship_defs (content_snapshot_id, ship_id)
) STRICT;
CREATE TRIGGER frozen_ship_role_capability_defs_insert_guard BEFORE INSERT ON frozen_ship_role_capability_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_role_capability_defs_update_guard BEFORE UPDATE ON frozen_ship_role_capability_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_ship_role_capability_defs_delete_guard BEFORE DELETE ON frozen_ship_role_capability_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_role_balance_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    singleton INTEGER NOT NULL CHECK(singleton=1),
    scan_reference_strength REAL NOT NULL CHECK(scan_reference_strength>0),
    min_survey_rate REAL NOT NULL CHECK(min_survey_rate>=1),
    max_survey_rate REAL NOT NULL CHECK(max_survey_rate>=min_survey_rate),
    remote_range_floor_m REAL NOT NULL CHECK(remote_range_floor_m>0),
    freight_exposure_s REAL NOT NULL CHECK(freight_exposure_s>0),
    freight_loss_damage_hp REAL NOT NULL CHECK(freight_loss_damage_hp>0),
    PRIMARY KEY (content_snapshot_id, singleton)
) STRICT;
CREATE TRIGGER frozen_role_balance_defs_insert_guard BEFORE INSERT ON frozen_role_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_role_balance_defs_update_guard BEFORE UPDATE ON frozen_role_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_role_balance_defs_delete_guard BEFORE DELETE ON frozen_role_balance_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE frozen_consignment_defs (
    content_snapshot_id TEXT NOT NULL REFERENCES content_snapshot(content_snapshot_id) ON DELETE CASCADE,
    contract_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    origin_station_id TEXT NOT NULL,
    destination_station_id TEXT NOT NULL,
    required_unlock_id TEXT NOT NULL,
    max_units INTEGER NOT NULL CHECK(max_units>0),
    unit_volume_l REAL NOT NULL CHECK(unit_volume_l>0),
    unit_mass_kg REAL NOT NULL CHECK(unit_mass_kg>0),
    deposit_per_unit INTEGER NOT NULL CHECK(deposit_per_unit>0),
    fee_credit INTEGER NOT NULL CHECK(fee_credit>=0),
    reward_per_unit INTEGER NOT NULL CHECK(reward_per_unit>0),
    deadline_s REAL NOT NULL CHECK(deadline_s>0),
    cooldown_s REAL NOT NULL CHECK(cooldown_s>0),
    CHECK(origin_station_id<>destination_station_id),
    PRIMARY KEY (content_snapshot_id, contract_id),
    FOREIGN KEY (content_snapshot_id, origin_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, destination_station_id) REFERENCES frozen_station_defs (content_snapshot_id, station_id),
    FOREIGN KEY (content_snapshot_id, required_unlock_id) REFERENCES frozen_unlock_defs (content_snapshot_id, unlock_id)
) STRICT;
CREATE TRIGGER frozen_consignment_defs_insert_guard BEFORE INSERT ON frozen_consignment_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_consignment_defs_update_guard BEFORE UPDATE ON frozen_consignment_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;
CREATE TRIGGER frozen_consignment_defs_delete_guard BEFORE DELETE ON frozen_consignment_defs
WHEN EXISTS (SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT, 'frozen content is immutable'); END;


CREATE TABLE remote_support_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,item_instance_id TEXT NOT NULL,ship_instance_id TEXT NOT NULL,target_npc_id TEXT NOT NULL,
 target_generation INTEGER NOT NULL CHECK(target_generation>=0),layer_id TEXT NOT NULL CHECK(layer_id IN ('shield','armor')),
 phase TEXT NOT NULL DEFAULT 'armed' CHECK(phase IN ('armed','cycling')),remaining_s REAL NOT NULL DEFAULT 0 CHECK(remaining_s>=0),paid_restore REAL NOT NULL DEFAULT 0 CHECK(paid_restore>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id) REFERENCES item_instance_state(snapshot_id,world_id,content_snapshot_id,item_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,target_npc_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id)) STRICT;

CREATE TRIGGER remote_support_state_insert_immutable BEFORE INSERT ON remote_support_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER remote_support_state_update_immutable BEFORE UPDATE ON remote_support_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER remote_support_state_delete_immutable BEFORE DELETE ON remote_support_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE consignment_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,contract_id TEXT NOT NULL,generation INTEGER NOT NULL DEFAULT 1 CHECK(generation>0),
 phase TEXT NOT NULL DEFAULT 'idle' CHECK(phase IN ('idle','active','ready','claimed')),payload_ship_id TEXT,
 accepted_units INTEGER NOT NULL DEFAULT 0 CHECK(accepted_units>=0),cargo_units INTEGER NOT NULL DEFAULT 0 CHECK(cargo_units>=0),
 delivered_units INTEGER NOT NULL DEFAULT 0 CHECK(delivered_units>=0),lost_units INTEGER NOT NULL DEFAULT 0 CHECK(lost_units>=0),returned_units INTEGER NOT NULL DEFAULT 0 CHECK(returned_units>=0),
 remaining_s REAL NOT NULL DEFAULT 0 CHECK(remaining_s>=0),cooldown_remaining_s REAL NOT NULL DEFAULT 0 CHECK(cooldown_remaining_s>=0),
 exposure_remaining_s REAL NOT NULL DEFAULT 0 CHECK(exposure_remaining_s>=0),damage_debt_hp REAL NOT NULL DEFAULT 0 CHECK(damage_debt_hp>=0),
 paid_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit_total>=0),refunded_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(refunded_credit_total>=0),reward_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit_total>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,contract_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(content_snapshot_id,contract_id) REFERENCES frozen_consignment_defs(content_snapshot_id,contract_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,payload_ship_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id)) STRICT;

CREATE TRIGGER consignment_state_insert_immutable BEFORE INSERT ON consignment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER consignment_state_update_immutable BEFORE UPDATE ON consignment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER consignment_state_delete_immutable BEFORE DELETE ON consignment_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TABLE consignment_receipt_state(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,receipt_id TEXT NOT NULL,contract_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>0),
 action_kind TEXT NOT NULL CHECK(action_kind IN ('dispatch','deliver','loss','return','claim')),units INTEGER NOT NULL CHECK(units>=0),
 paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),refunded_credit INTEGER NOT NULL DEFAULT 0 CHECK(refunded_credit>=0),reward_credit INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit>=0),
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,receipt_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,contract_id) REFERENCES consignment_state(snapshot_id,world_id,content_snapshot_id,contract_id)) STRICT;

CREATE TRIGGER consignment_receipt_state_insert_immutable BEFORE INSERT ON consignment_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER consignment_receipt_state_update_immutable BEFORE UPDATE ON consignment_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE TRIGGER consignment_receipt_state_delete_immutable BEFORE DELETE ON consignment_receipt_state WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;

CREATE UNIQUE INDEX consignment_dispatch_once ON consignment_receipt_state(snapshot_id,world_id,content_snapshot_id,contract_id,generation) WHERE action_kind='dispatch';

CREATE UNIQUE INDEX consignment_claim_once ON consignment_receipt_state(snapshot_id,world_id,content_snapshot_id,contract_id,generation) WHERE action_kind='claim';

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
 NOT (EXISTS(SELECT 1 FROM exploration_actor_state a WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND a.actor_role='escort') OR EXISTS(SELECT 1 FROM war_fleet_state f WHERE f.snapshot_id=r.snapshot_id AND f.npc_instance_id=r.target_npc_id AND f.side='ally')) OR
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

CREATE TRIGGER role_payload_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM frozen_role_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_state s JOIN frozen_ship_defs sd ON sd.content_snapshot_id=s.content_snapshot_id AND sd.ship_id=s.ship_def_id WHERE s.snapshot_id=NEW.snapshot_id AND
 (COALESCE((SELECT sum(h.cargo_units*d.unit_volume_l) FROM consignment_state h JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) WHERE h.snapshot_id=s.snapshot_id AND h.payload_ship_id=s.ship_instance_id),0)+COALESCE((SELECT sum(o.cargo_units*d.cargo_volume_l) FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=s.snapshot_id AND o.payload_ship_id=s.ship_instance_id),0)+
 COALESCE((SELECT sum(i.quantity*d.unit_volume_l) FROM inventory_stack_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)+
 COALESCE((SELECT sum(d.unit_volume_l) FROM item_instance_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)+
 COALESCE((SELECT sum(d.volume_m3*1000) FROM salvage_package_state p JOIN container_state c ON c.snapshot_id=p.snapshot_id AND c.container_id=p.host_container_id JOIN frozen_salvage_package_defs d USING(content_snapshot_id,package_def_id) WHERE p.snapshot_id=s.snapshot_id AND p.status='sealed' AND c.ship_instance_id=s.ship_instance_id AND c.kind='cargo'),0)>sd.cargo_l))
 THEN RAISE(ABORT,'consignment combined cargo exceeds real hold') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_state s JOIN frozen_ship_defs sd ON sd.content_snapshot_id=s.content_snapshot_id AND sd.ship_id=s.ship_def_id WHERE s.snapshot_id=NEW.snapshot_id AND
 (COALESCE((SELECT sum(h.cargo_units*d.unit_mass_kg) FROM consignment_state h JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) WHERE h.snapshot_id=s.snapshot_id AND h.payload_ship_id=s.ship_instance_id),0)+COALESCE((SELECT sum(o.cargo_units*d.cargo_mass_kg) FROM operation_state o JOIN frozen_operation_defs d USING(content_snapshot_id,operation_id) WHERE o.snapshot_id=s.snapshot_id AND o.payload_ship_id=s.ship_instance_id),0)+
 COALESCE((SELECT sum(i.quantity*d.unit_mass_kg) FROM inventory_stack_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind IN ('cargo','mineral')),0)+
 COALESCE((SELECT sum(d.unit_mass_kg) FROM item_instance_state i JOIN container_state c USING(snapshot_id,world_id,content_snapshot_id,container_id) JOIN frozen_item_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.item_id=i.item_def_id WHERE i.snapshot_id=s.snapshot_id AND c.ship_instance_id=s.ship_instance_id AND c.kind IN ('cargo','mineral')),0)+
 COALESCE((SELECT sum(d.mass_kg) FROM salvage_package_state p JOIN container_state c ON c.snapshot_id=p.snapshot_id AND c.container_id=p.host_container_id JOIN frozen_salvage_package_defs d ON d.content_snapshot_id=p.content_snapshot_id AND d.package_def_id=p.package_def_id WHERE p.snapshot_id=s.snapshot_id AND p.status='sealed' AND c.ship_instance_id=s.ship_instance_id),0)>sd.max_payload_mass_kg))
 THEN RAISE(ABORT,'consignment combined cargo exceeds shared mass budget') END;
END;

DROP TRIGGER snapshot_seal_validation;
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
  WHERE g.content_snapshot_id=NEW.content_snapshot_id AND g.module_id=equipment_state.module_def_id AND g.group_id='engine') AND NOT EXISTS (SELECT 1 FROM remote_support_state r JOIN frozen_role_balance_defs b USING(content_snapshot_id) WHERE r.snapshot_id=equipment_state.snapshot_id AND r.item_instance_id=equipment_state.item_instance_id AND r.phase='cycling' AND abs(r.remaining_s-equipment_state.active_remaining_s)<=0.000001))
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

CREATE TABLE database_meta_format17(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=17)) STRICT;
INSERT INTO database_meta_format17 SELECT singleton,application_id,17 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format17 RENAME TO database_meta;
PRAGMA user_version=17;
