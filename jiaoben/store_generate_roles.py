"""Append format17 roles and consignments; never rewrite 001-019 or old adapters."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from roles_catalog import TABLES

ROOT=Path(__file__).resolve().parents[1]
STATES={
 'remote_support_state': ('''item_instance_id TEXT NOT NULL,ship_instance_id TEXT NOT NULL,target_npc_id TEXT NOT NULL,
 target_generation INTEGER NOT NULL CHECK(target_generation>=0),layer_id TEXT NOT NULL CHECK(layer_id IN ('shield','armor')),
 phase TEXT NOT NULL DEFAULT 'armed' CHECK(phase IN ('armed','cycling')),remaining_s REAL NOT NULL DEFAULT 0 CHECK(remaining_s>=0),paid_restore REAL NOT NULL DEFAULT 0 CHECK(paid_restore>=0)''','item_instance_id',
 '''FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,item_instance_id) REFERENCES item_instance_state(snapshot_id,world_id,content_snapshot_id,item_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,ship_instance_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,target_npc_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id)'''),
 'consignment_state': ('''contract_id TEXT NOT NULL,generation INTEGER NOT NULL DEFAULT 1 CHECK(generation>0),
 phase TEXT NOT NULL DEFAULT 'idle' CHECK(phase IN ('idle','active','ready','claimed')),payload_ship_id TEXT,
 accepted_units INTEGER NOT NULL DEFAULT 0 CHECK(accepted_units>=0),cargo_units INTEGER NOT NULL DEFAULT 0 CHECK(cargo_units>=0),
 delivered_units INTEGER NOT NULL DEFAULT 0 CHECK(delivered_units>=0),lost_units INTEGER NOT NULL DEFAULT 0 CHECK(lost_units>=0),returned_units INTEGER NOT NULL DEFAULT 0 CHECK(returned_units>=0),
 remaining_s REAL NOT NULL DEFAULT 0 CHECK(remaining_s>=0),cooldown_remaining_s REAL NOT NULL DEFAULT 0 CHECK(cooldown_remaining_s>=0),
 exposure_remaining_s REAL NOT NULL DEFAULT 0 CHECK(exposure_remaining_s>=0),damage_debt_hp REAL NOT NULL DEFAULT 0 CHECK(damage_debt_hp>=0),
 paid_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit_total>=0),refunded_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(refunded_credit_total>=0),reward_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit_total>=0)''','contract_id',
 '''FOREIGN KEY(content_snapshot_id,contract_id) REFERENCES frozen_consignment_defs(content_snapshot_id,contract_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,payload_ship_id) REFERENCES ship_state(snapshot_id,world_id,content_snapshot_id,ship_instance_id)'''),
 'consignment_receipt_state': ('''receipt_id TEXT NOT NULL,contract_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>0),
 action_kind TEXT NOT NULL CHECK(action_kind IN ('dispatch','deliver','loss','return','claim')),units INTEGER NOT NULL CHECK(units>=0),
 paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),refunded_credit INTEGER NOT NULL DEFAULT 0 CHECK(refunded_credit>=0),reward_credit INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit>=0)''','receipt_id',
 '''FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,contract_id) REFERENCES consignment_state(snapshot_id,world_id,content_snapshot_id,contract_id)'''),
}

SEAL='''CREATE TRIGGER role_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
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
END;'''

def main():
    db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
    parts=['-- Reviewed existing-hull support, scouting and entrusted freight.']+[frozen_table_sql(db,t) for t in TABLES]
    for table,(columns,key,foreign) in STATES.items():
        parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,{foreign}) STRICT;''')
        for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
            guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
            if action=='UPDATE': guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
    for kind in ['dispatch','claim']:
        parts.append(f"CREATE UNIQUE INDEX consignment_{kind}_once ON consignment_receipt_state(snapshot_id,world_id,content_snapshot_id,contract_id,generation) WHERE action_kind='{kind}';")
    parts.append(SEAL)
    legacy=(ROOT/'code/database/progress/018_operations.sql').read_text(encoding='utf-8')
    marker=' SELECT CASE WHEN EXISTS(SELECT 1 FROM ship_state s JOIN frozen_ship_defs sd'
    volume_start=legacy.index(marker,legacy.index('-- Cargo is an objective ledger'))
    volume_end=legacy.index(" THEN RAISE(ABORT,'operation cargo exceeds real hold') END;",volume_start)+len(" THEN RAISE(ABORT,'operation cargo exceeds real hold') END;")
    mass_start=legacy.index(marker,volume_end)
    mass_end=legacy.index(" THEN RAISE(ABORT,'operation cargo exceeds shared mass budget') END;",mass_start)+len(" THEN RAISE(ABORT,'operation cargo exceeds shared mass budget') END;")
    guards=[]
    for fragment,field in [(legacy[volume_start:volume_end],'unit_volume_l'),(legacy[mass_start:mass_end],'unit_mass_kg')]:
        extra=f"COALESCE((SELECT sum(h.cargo_units*d.{field}) FROM consignment_state h JOIN frozen_consignment_defs d USING(content_snapshot_id,contract_id) WHERE h.snapshot_id=s.snapshot_id AND h.payload_ship_id=s.ship_instance_id),0)+"
        fragment=fragment.replace('(COALESCE((SELECT sum(o.cargo_units', '('+extra+'COALESCE((SELECT sum(o.cargo_units',1)
        guards.append(fragment.replace('operation cargo exceeds','consignment combined cargo exceeds'))
    parts.append("CREATE TRIGGER role_payload_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM frozen_role_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) BEGIN\n"+'\n'.join(guards)+'\nEND;')
    # Preserve the complete reviewed quiescence guard, admitting only the new
    # fully persisted repair cycles. Ordinary attacks/interactions stay blocked.
    baseline=sqlite3.connect(':memory:')
    for path in sorted((ROOT/'code/database/progress').glob('*.sql')):
        if path.name[:3].isdigit() and int(path.name[:3])<=19: baseline.executescript(path.read_text(encoding='utf-8'))
    old_guard=baseline.execute("SELECT sql FROM sqlite_schema WHERE type='trigger' AND name='snapshot_seal_validation'").fetchone()[0]
    predicate="WHERE g.content_snapshot_id=NEW.content_snapshot_id AND g.module_id=equipment_state.module_def_id AND g.group_id='engine'))"
    replacement="WHERE g.content_snapshot_id=NEW.content_snapshot_id AND g.module_id=equipment_state.module_def_id AND g.group_id='engine') AND NOT EXISTS (SELECT 1 FROM remote_support_state r JOIN frozen_role_balance_defs b USING(content_snapshot_id) WHERE r.snapshot_id=equipment_state.snapshot_id AND r.item_instance_id=equipment_state.item_instance_id AND r.phase='cycling' AND abs(r.remaining_s-equipment_state.active_remaining_s)<=0.000001))"
    assert old_guard.count(predicate)==1
    parts.append('DROP TRIGGER snapshot_seal_validation;\n'+old_guard.replace(predicate,replacement)+';')
    baseline.close()
    parts.append('''CREATE TABLE database_meta_format17(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=17)) STRICT;
INSERT INTO database_meta_format17 SELECT singleton,application_id,17 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format17 RENAME TO database_meta;
PRAGMA user_version=17;''')
    (ROOT/'code/database/progress/020_roles.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
    adapter=['-- Reviewed schema15 role adapter.\nPRAGMA foreign_keys=ON;']
    adapter += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
    adapter += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type='view' ORDER BY name")]
    (ROOT/'code/database/progress/catalog_adapter_v0_16.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n')
    db.close()
if __name__=='__main__': main()
