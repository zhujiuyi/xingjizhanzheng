"""Append format20 companion contracts; preserve all historical SQL bytes."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from hire_catalog import TABLES

ROOT=Path(__file__).resolve().parents[1]
STATES={
 'hire_contract_state':('''contract_id TEXT NOT NULL,player_id TEXT NOT NULL,profile_id TEXT NOT NULL,origin_station_id TEXT NOT NULL,
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
 CHECK((phase='returned') OR refund_credit=0),CHECK((order_kind='focus') OR focus_target_id IS NULL)''','contract_id',
 '''FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(content_snapshot_id,profile_id) REFERENCES frozen_hire_profile_defs(content_snapshot_id,profile_id),
 FOREIGN KEY(content_snapshot_id,origin_station_id) REFERENCES frozen_station_defs(content_snapshot_id,station_id),
 FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_sector_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,site_id) REFERENCES frozen_site_defs(content_snapshot_id,site_id)'''),
 'hire_receipt_state':('''source_token TEXT NOT NULL,contract_id TEXT NOT NULL,event_kind TEXT NOT NULL CHECK(event_kind IN('hire','return','loss')),
 paid_credit INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit>=0),refund_credit INTEGER NOT NULL DEFAULT 0 CHECK(refund_credit>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0)''','source_token',
 '''FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,contract_id) REFERENCES hire_contract_state(snapshot_id,world_id,content_snapshot_id,contract_id)'''),
}
SEAL='''CREATE TRIGGER hire_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
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
END;'''

def main():
    db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
    parts=['-- Reviewed finite hired companions, movement binding and actual settlements.']+[frozen_table_sql(db,t) for t in TABLES]
    for table,(columns,key,foreign) in STATES.items():
        parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,{foreign}) STRICT;''')
        for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
            guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
            if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
    parts.append("CREATE UNIQUE INDEX hire_actor_unique ON hire_contract_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id) WHERE npc_instance_id IS NOT NULL;")
    parts.append("CREATE UNIQUE INDEX hire_payment_once ON hire_receipt_state(snapshot_id,world_id,content_snapshot_id,contract_id) WHERE event_kind='hire';")
    parts.append("CREATE UNIQUE INDEX hire_outcome_once ON hire_receipt_state(snapshot_id,world_id,content_snapshot_id,contract_id) WHERE event_kind IN('return','loss');")
    parts.append(SEAL)
    prior=sqlite3.connect(':memory:')
    for path in sorted((ROOT/'code/database/progress').glob('*.sql')):
        if path.name[:3].isdigit() and int(path.name[:3])<=22:prior.executescript(path.read_text(encoding='utf-8'))
    old=prior.execute("SELECT sql FROM sqlite_schema WHERE type='trigger' AND name='spatial_context_seal_validation'").fetchone()[0]
    needle="WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='npc' AND p.site_id<>"
    binding="""EXISTS(SELECT 1 FROM hire_contract_state h JOIN frozen_hire_profile_defs profile USING(content_snapshot_id,profile_id)
 WHERE h.snapshot_id=n.snapshot_id AND h.npc_instance_id=n.npc_instance_id AND h.phase IN('deployed','retreating') AND profile.spawn_id=n.spawn_id
 AND h.player_id=(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id) AND h.sector_id=n.sector_id AND h.site_id=p.site_id)"""
    assert old.count(needle)==1
    parts.append('DROP TRIGGER spatial_context_seal_validation;\n'+old.replace(needle,"WHERE p.snapshot_id=NEW.snapshot_id AND p.entity_kind='npc' AND NOT "+binding+' AND p.site_id<>')+';')
    old=prior.execute("SELECT sql FROM sqlite_schema WHERE type='trigger' AND name='role_seal_validation'").fetchone()[0]
    needle='NOT (EXISTS(SELECT 1 FROM exploration_actor_state'
    friend="""EXISTS(SELECT 1 FROM hire_contract_state h JOIN frozen_hire_profile_defs profile USING(content_snapshot_id,profile_id)
 WHERE h.snapshot_id=r.snapshot_id AND h.npc_instance_id=r.target_npc_id AND h.phase IN('deployed','retreating') AND profile.spawn_id=n.spawn_id
 AND h.player_id=(SELECT player_id FROM player_state WHERE snapshot_id=h.snapshot_id))"""
    assert old.count(needle)==1
    parts.append('DROP TRIGGER role_seal_validation;\n'+old.replace(needle,'NOT ('+friend+' OR EXISTS(SELECT 1 FROM exploration_actor_state')+';')
    prior.close()
    parts.append('''CREATE TABLE database_meta_format20(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=20)) STRICT;
INSERT INTO database_meta_format20 SELECT singleton,application_id,20 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format20 RENAME TO database_meta;PRAGMA user_version=20;''')
    (ROOT/'code/database/progress/023_hire.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
    adapter=['-- Reviewed schema18 hire adapter.\nPRAGMA foreign_keys=ON;']
    for kind in ['table','view']:adapter += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type=? AND name NOT LIKE 'sqlite_%' ORDER BY name",(kind,))]
    (ROOT/'code/database/progress/catalog_adapter_v0_19.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n');db.close()

if __name__=='__main__':main()
