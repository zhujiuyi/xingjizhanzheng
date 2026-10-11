"""Append format19 frontier state and narrowly extend reviewed legacy guards."""
from pathlib import Path
import sqlite3
from generate_frozen_schema import frozen_table_sql
from frontier_catalog import TABLES

ROOT=Path(__file__).resolve().parents[1]
STATES={
 'frontier_campaign_state':('''war_id TEXT NOT NULL,attempt INTEGER NOT NULL DEFAULT 0 CHECK(attempt>=0),
 phase TEXT NOT NULL DEFAULT 'idle' CHECK(phase IN ('idle','legacy','scouting','escorting','hold','demolition','rebuilding','completed','failed','cancelled')),
 legacy_attempt INTEGER NOT NULL DEFAULT 0 CHECK(legacy_attempt>=0),survey_paid INTEGER NOT NULL DEFAULT 0 CHECK(survey_paid IN(0,1)),survey_remaining_s REAL NOT NULL DEFAULT 0 CHECK(survey_remaining_s>=0),
 supplies_paid_units INTEGER NOT NULL DEFAULT 0 CHECK(supplies_paid_units>=0),supply_delivered INTEGER NOT NULL DEFAULT 0 CHECK(supply_delivered IN(0,1)),
 repair_paid_units INTEGER NOT NULL DEFAULT 0 CHECK(repair_paid_units>=0),repair_remaining_s REAL NOT NULL DEFAULT 0 CHECK(repair_remaining_s>=0),
 hold_remaining_s REAL NOT NULL DEFAULT 0 CHECK(hold_remaining_s>=0),demolition_units INTEGER NOT NULL DEFAULT 0 CHECK(demolition_units>=0)''','war_id',
 '''FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_frontier_campaign_defs(content_snapshot_id,war_id)'''),
 'frontier_actor_state':('''npc_instance_id TEXT NOT NULL,war_id TEXT,sector_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>0),
 actor_role TEXT NOT NULL CHECK(actor_role IN ('convoy','ambusher','structure','raider','beacon'))''','npc_instance_id',
 '''FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),
 FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_frontier_campaign_defs(content_snapshot_id,war_id),
 FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id)'''),
 'frontier_campaign_receipt_state':('''source_token TEXT NOT NULL,war_id TEXT NOT NULL,attempt INTEGER NOT NULL CHECK(attempt>0),
 event_kind TEXT NOT NULL CHECK(event_kind IN ('register','survey','supply','structure','hold','repair','capture','failed','cancelled')),
 units INTEGER NOT NULL DEFAULT 0 CHECK(units>=0),material_units INTEGER NOT NULL DEFAULT 0 CHECK(material_units>=0),
 reward_credit INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit>=0),reward_reputation INTEGER NOT NULL DEFAULT 0 CHECK(reward_reputation>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0)''','source_token',
 '''FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_frontier_campaign_defs(content_snapshot_id,war_id)'''),
 'frontier_territory_state':('''sector_id TEXT NOT NULL,phase TEXT NOT NULL DEFAULT 'neutral' CHECK(phase IN ('neutral','controlled','warning','defending')),
 revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0),reserve_units INTEGER NOT NULL DEFAULT 0 CHECK(reserve_units>=0),crisis_generation INTEGER NOT NULL DEFAULT 0 CHECK(crisis_generation>=0),
 warning_remaining_s REAL NOT NULL DEFAULT 0 CHECK(warning_remaining_s>=0),defense_remaining_s REAL NOT NULL DEFAULT 0 CHECK(defense_remaining_s>=0),hold_remaining_s REAL NOT NULL DEFAULT 0 CHECK(hold_remaining_s>=0)''','sector_id',
 '''FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id)'''),
 'frontier_journal_state':('''source_token TEXT NOT NULL,sector_id TEXT NOT NULL,revision INTEGER NOT NULL CHECK(revision>=0),
 event_kind TEXT NOT NULL CHECK(event_kind IN ('capture','import','loss','warning','defense','supply')),faction_id TEXT,war_id TEXT,attempt INTEGER NOT NULL DEFAULT 0 CHECK(attempt>=0),
 crisis_generation INTEGER NOT NULL DEFAULT 0 CHECK(crisis_generation>=0),supply_order_id TEXT,units INTEGER NOT NULL DEFAULT 0 CHECK(units>=0),
 reward_credit INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit>=0),reward_reputation INTEGER NOT NULL DEFAULT 0 CHECK(reward_reputation>=0),event_tick INTEGER NOT NULL CHECK(event_tick>=0)''','source_token',
 '''FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id),
 FOREIGN KEY(content_snapshot_id,war_id) REFERENCES frozen_civilization_war_defs(content_snapshot_id,war_id),
 FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,supply_order_id) REFERENCES frontier_supply_order_state(snapshot_id,world_id,content_snapshot_id,order_id)'''),
 'frontier_supply_order_state':('''order_id TEXT NOT NULL,sector_id TEXT NOT NULL,faction_id TEXT NOT NULL,units INTEGER NOT NULL CHECK(units>0),paid_credit INTEGER NOT NULL CHECK(paid_credit>=0),
 phase TEXT NOT NULL DEFAULT 'inflight' CHECK(phase IN ('inflight','delivered','lost')),remaining_s REAL NOT NULL CHECK(remaining_s>=0),created_tick INTEGER NOT NULL CHECK(created_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0)''','order_id',
 '''FOREIGN KEY(content_snapshot_id,sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id)'''),
 'frontier_director_state':('''player_id TEXT NOT NULL,next_event_s REAL NOT NULL CHECK(next_event_s>=0),active_sector_id TEXT,active_faction_id TEXT,
 CHECK((active_sector_id IS NULL)=(active_faction_id IS NULL))''','player_id',
 '''FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,player_id) REFERENCES player_state(snapshot_id,world_id,content_snapshot_id,player_id),
 FOREIGN KEY(content_snapshot_id,active_sector_id) REFERENCES frozen_frontier_governance_defs(content_snapshot_id,sector_id),
 FOREIGN KEY(content_snapshot_id,active_faction_id) REFERENCES frozen_civilization_defs(content_snapshot_id,faction_id)'''),
}

SEAL='''CREATE TRIGGER frontier_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN (SELECT count(*) FROM frontier_campaign_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_frontier_campaign_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM frontier_territory_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_frontier_governance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM frontier_director_state WHERE snapshot_id=NEW.snapshot_id)<>CASE WHEN EXISTS(SELECT 1 FROM frozen_frontier_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) THEN 1 ELSE 0 END
 THEN RAISE(ABORT,'frontier authority coverage incomplete') END;
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM frozen_frontier_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND
 (EXISTS(SELECT 1 FROM frontier_actor_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM frontier_campaign_receipt_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM frontier_journal_state WHERE snapshot_id=NEW.snapshot_id) OR EXISTS(SELECT 1 FROM frontier_supply_order_state WHERE snapshot_id=NEW.snapshot_id)) THEN RAISE(ABORT,'frontier state under legacy rules') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_territory_state f JOIN territory_state t USING(snapshot_id,world_id,content_snapshot_id,sector_id)
 JOIN frozen_frontier_balance_defs b USING(content_snapshot_id) WHERE f.snapshot_id=NEW.snapshot_id AND
 ((f.phase='neutral')<>(t.faction_id IS NULL) OR f.reserve_units>b.reserve_max_units OR f.warning_remaining_s>b.warning_s OR f.defense_remaining_s>b.defense_s OR f.hold_remaining_s>b.hold_s OR
 (f.phase='neutral' AND (f.reserve_units<>0 OR f.warning_remaining_s<>0 OR f.defense_remaining_s<>0 OR f.hold_remaining_s<>0)))) THEN RAISE(ABORT,'invalid frontier governance phase or reserve') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_territory_state f JOIN territory_state t USING(snapshot_id,world_id,content_snapshot_id,sector_id) WHERE f.snapshot_id=NEW.snapshot_id AND
 (f.revision<>(SELECT count(*) FROM frontier_journal_state j WHERE j.snapshot_id=f.snapshot_id AND j.sector_id=f.sector_id AND j.event_kind IN ('capture','import','loss')) OR
 (f.revision>0 AND NOT EXISTS(SELECT 1 FROM frontier_journal_state j WHERE j.snapshot_id=f.snapshot_id AND j.sector_id=f.sector_id AND j.revision=f.revision AND j.event_kind IN ('capture','import','loss') AND j.faction_id IS t.faction_id)) OR
 (f.revision=0 AND t.faction_id IS NOT NULL))) THEN RAISE(ABORT,'frontier ownership requires its complete revision journal') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state j WHERE j.snapshot_id=NEW.snapshot_id AND
 (j.event_tick>NEW.simulation_tick OR
 (j.event_kind IN ('capture','import','loss') AND (j.revision<1 OR j.revision>(SELECT f.revision FROM frontier_territory_state f WHERE f.snapshot_id=j.snapshot_id AND f.sector_id=j.sector_id))) OR
 (j.event_kind IN ('capture','import') AND (j.faction_id IS NULL OR j.war_id IS NULL OR j.attempt<1 OR NOT EXISTS(SELECT 1 FROM frozen_civilization_war_defs w WHERE w.content_snapshot_id=j.content_snapshot_id AND w.war_id=j.war_id AND w.target_sector_id=j.sector_id AND w.faction_id=j.faction_id))) OR
 (j.event_kind='loss' AND (j.faction_id IS NOT NULL OR j.crisis_generation<1)) OR
 (j.event_kind='import' AND (j.reward_credit<>0 OR j.reward_reputation<>0)))) THEN RAISE(ABORT,'invalid frontier ownership event or imported reward') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_actor_state a JOIN npc_state n USING(snapshot_id,world_id,content_snapshot_id,npc_instance_id) WHERE a.snapshot_id=NEW.snapshot_id AND
 (a.generation<>n.generation OR a.sector_id<>n.sector_id OR
 NOT(EXISTS(SELECT 1 FROM frozen_frontier_actor_defs d WHERE d.content_snapshot_id=a.content_snapshot_id AND d.spawn_id=n.spawn_id AND d.war_id IS a.war_id AND d.sector_id=a.sector_id AND d.actor_role=a.actor_role) OR
 (a.actor_role='beacon' AND a.war_id IS NULL AND EXISTS(SELECT 1 FROM frozen_frontier_beacon_defs d WHERE d.content_snapshot_id=a.content_snapshot_id AND d.spawn_id=n.spawn_id AND d.sector_id=a.sector_id))))) THEN RAISE(ABORT,'invalid frontier actor binding') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_campaign_state f JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
 WHERE f.snapshot_id=NEW.snapshot_id AND (f.survey_remaining_s>b.survey_s OR f.repair_remaining_s>b.rebuild_s OR f.hold_remaining_s>b.hold_s OR f.demolition_units>2 OR
 f.supplies_paid_units<>COALESCE((SELECT sum(r.material_units) FROM frontier_campaign_receipt_state r WHERE r.snapshot_id=f.snapshot_id AND r.war_id=f.war_id AND r.attempt=f.attempt AND r.event_kind='register'),0) OR
 f.repair_paid_units<>COALESCE((SELECT sum(r.material_units) FROM frontier_campaign_receipt_state r WHERE r.snapshot_id=f.snapshot_id AND r.war_id=f.war_id AND r.attempt=f.attempt AND r.event_kind='repair'),0))) THEN RAISE(ABORT,'frontier paid work or material conservation failed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_campaign_receipt_state r JOIN frozen_frontier_balance_defs b USING(content_snapshot_id) WHERE r.snapshot_id=NEW.snapshot_id AND
 (r.event_tick>NEW.simulation_tick OR (r.event_kind='register' AND r.material_units<>b.supply_units) OR (r.event_kind='repair' AND r.material_units<>b.rebuild_units))) THEN RAISE(ABORT,'invalid frontier material payment') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_supply_order_state o JOIN frozen_frontier_balance_defs b USING(content_snapshot_id) WHERE o.snapshot_id=NEW.snapshot_id AND
 (o.paid_credit<>b.dispatch_fee_credit OR o.units>b.reserve_max_units OR o.remaining_s>b.dispatch_s OR o.created_tick>NEW.simulation_tick OR o.finished_tick>NEW.simulation_tick OR
 (o.phase='inflight' AND o.finished_tick<>0) OR (o.phase<>'inflight' AND o.remaining_s<>0))) THEN RAISE(ABORT,'invalid paid strategic supply order') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state j JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
 LEFT JOIN frozen_civilization_war_defs w ON w.content_snapshot_id=j.content_snapshot_id AND w.war_id=j.war_id
 WHERE j.snapshot_id=NEW.snapshot_id AND (
 (j.event_kind='capture' AND (j.reward_credit<>CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state prior WHERE prior.snapshot_id=j.snapshot_id AND prior.sector_id=j.sector_id AND prior.faction_id=j.faction_id AND prior.event_kind IN ('capture','import') AND prior.revision<j.revision) THEN b.recapture_credit ELSE w.reward_credit END OR
 j.reward_reputation<>CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state prior WHERE prior.snapshot_id=j.snapshot_id AND prior.sector_id=j.sector_id AND prior.faction_id=j.faction_id AND prior.event_kind IN ('capture','import') AND prior.revision<j.revision) THEN b.recapture_reputation ELSE w.reward_reputation END)) OR
 (j.event_kind='defense' AND (j.reward_credit<>CASE WHEN j.units=0 THEN b.defense_credit ELSE 0 END OR j.reward_reputation<>CASE WHEN j.units=0 THEN b.defense_reputation ELSE 0 END)) OR
 (j.event_kind NOT IN ('capture','defense') AND (j.reward_credit<>0 OR j.reward_reputation<>0)))) THEN RAISE(ABORT,'frontier reward exceeds the real event entitlement') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_campaign_receipt_state r WHERE r.snapshot_id=NEW.snapshot_id AND
 ((r.event_kind<>'capture' AND (r.reward_credit<>0 OR r.reward_reputation<>0)) OR
 (r.event_kind='capture' AND NOT EXISTS(SELECT 1 FROM frontier_journal_state j WHERE j.snapshot_id=r.snapshot_id AND j.war_id=r.war_id AND j.attempt=r.attempt AND j.event_kind='capture' AND j.reward_credit=r.reward_credit AND j.reward_reputation=r.reward_reputation)))) THEN RAISE(ABORT,'frontier campaign reward lacks matching ownership history') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frontier_journal_state j LEFT JOIN frontier_supply_order_state o ON o.snapshot_id=j.snapshot_id AND o.order_id=j.supply_order_id
 WHERE j.snapshot_id=NEW.snapshot_id AND j.supply_order_id IS NOT NULL AND (j.event_kind<>'supply' OR o.phase<>'delivered' OR o.sector_id<>j.sector_id OR o.faction_id IS NOT j.faction_id OR j.units>o.units)) THEN RAISE(ABORT,'frontier resupply receipt lacks a delivered order') END;
 SELECT CASE WHEN (SELECT count(*) FROM frontier_territory_state WHERE snapshot_id=NEW.snapshot_id AND phase IN ('warning','defending'))<>(SELECT count(*) FROM frontier_director_state WHERE snapshot_id=NEW.snapshot_id AND active_sector_id IS NOT NULL) OR
 EXISTS(SELECT 1 FROM frontier_director_state d LEFT JOIN frontier_territory_state f ON f.snapshot_id=d.snapshot_id AND f.sector_id=d.active_sector_id LEFT JOIN territory_state t ON t.snapshot_id=d.snapshot_id AND t.sector_id=d.active_sector_id
 WHERE d.snapshot_id=NEW.snapshot_id AND d.active_sector_id IS NOT NULL AND (f.phase NOT IN ('warning','defending') OR t.faction_id IS NOT d.active_faction_id)) THEN RAISE(ABORT,'frontier crisis director mismatch') END;
END;'''

def main():
    db=sqlite3.connect((ROOT/'code/data/catalog.db').as_uri()+'?mode=ro',uri=True)
    parts=['-- Reviewed frontier stages, governance and durable territory history.']+[frozen_table_sql(db,t) for t in TABLES]
    for table,(columns,key,foreign) in STATES.items():
        parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE,{foreign}) STRICT;''')
        for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
            guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
            if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
            parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
    parts.append("CREATE UNIQUE INDEX frontier_ownership_revision ON frontier_journal_state(snapshot_id,world_id,content_snapshot_id,sector_id,revision) WHERE event_kind IN ('capture','import','loss');")
    parts.append("CREATE UNIQUE INDEX frontier_defense_once ON frontier_journal_state(snapshot_id,world_id,content_snapshot_id,sector_id,crisis_generation) WHERE event_kind='defense';")
    for kind in ['register','survey','supply','hold','repair','capture','failed','cancelled']:
        parts.append(f"CREATE UNIQUE INDEX frontier_campaign_{kind}_once ON frontier_campaign_receipt_state(snapshot_id,world_id,content_snapshot_id,war_id,attempt) WHERE event_kind='{kind}';")
    parts.append(SEAL)
    prior=sqlite3.connect(':memory:')
    for path in sorted((ROOT/'code/database/progress').glob('*.sql')):
        if path.name[:3].isdigit() and int(path.name[:3])<=21:prior.executescript(path.read_text(encoding='utf-8'))
    old=prior.execute("SELECT sql FROM sqlite_schema WHERE type='trigger' AND name='civilization_context_seal_validation'").fetchone()[0]
    needle="(w.status='won' AND t.faction_id IS NOT d.faction_id)"
    replacement="(w.status='won' AND t.faction_id IS NOT d.faction_id AND NOT EXISTS(SELECT 1 FROM frontier_journal_state j JOIN frontier_territory_state f ON f.snapshot_id=j.snapshot_id AND f.sector_id=j.sector_id WHERE j.snapshot_id=w.snapshot_id AND j.war_id=w.war_id AND j.attempt=w.attempt AND j.event_kind IN ('capture','import') AND f.revision>j.revision))"
    assert old.count(needle)==1
    parts.append('DROP TRIGGER civilization_context_seal_validation;\n'+old.replace(needle,replacement)+';')
    old=prior.execute("SELECT sql FROM sqlite_schema WHERE type='trigger' AND name='role_seal_validation'").fetchone()[0]
    needle="OR EXISTS(SELECT 1 FROM war_fleet_state f WHERE f.snapshot_id=r.snapshot_id AND f.npc_instance_id=r.target_npc_id AND f.side='ally'))"
    frontier_friend="""EXISTS(SELECT 1 FROM frontier_actor_state a JOIN frozen_frontier_balance_defs b USING(content_snapshot_id)
 JOIN civilization_state identity ON identity.snapshot_id=a.snapshot_id
 LEFT JOIN war_campaign_state w ON w.snapshot_id=a.snapshot_id AND w.war_id=a.war_id
 LEFT JOIN frozen_civilization_war_defs d ON d.content_snapshot_id=a.content_snapshot_id AND d.war_id=a.war_id
 LEFT JOIN frontier_territory_state f ON f.snapshot_id=a.snapshot_id AND f.sector_id=a.sector_id
 LEFT JOIN territory_state t ON t.snapshot_id=a.snapshot_id AND t.sector_id=a.sector_id
 WHERE a.snapshot_id=r.snapshot_id AND a.npc_instance_id=r.target_npc_id AND
 ((a.actor_role='convoy' AND w.status IN ('assembling','fighting','occupying') AND w.attempt=a.generation AND identity.faction_id IS d.faction_id) OR
 (a.actor_role='beacon' AND a.war_id IS NULL AND f.phase='defending' AND f.crisis_generation=a.generation AND identity.faction_id IS t.faction_id)))"""
    replacement="OR EXISTS(SELECT 1 FROM war_fleet_state f WHERE f.snapshot_id=r.snapshot_id AND f.npc_instance_id=r.target_npc_id AND f.side='ally') OR "+frontier_friend+")"
    assert old.count(needle)==1
    parts.append('DROP TRIGGER role_seal_validation;\n'+old.replace(needle,replacement)+';');prior.close()
    parts.append('''CREATE TABLE database_meta_format19(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=19)) STRICT;
INSERT INTO database_meta_format19 SELECT singleton,application_id,19 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format19 RENAME TO database_meta;
PRAGMA user_version=19;''')
    (ROOT/'code/database/progress/022_frontier.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
    adapter=['-- Reviewed schema17 frontier adapter.\nPRAGMA foreign_keys=ON;']
    for kind in ['table','view']:adapter += [r[0]+';' for r in db.execute("SELECT sql FROM sqlite_schema WHERE type=? AND name NOT LIKE 'sqlite_%' ORDER BY name",(kind,))]
    (ROOT/'code/database/progress/catalog_adapter_v0_18.sql').write_text('\n\n'.join(adapter)+'\n',encoding='utf-8',newline='\n');db.close()

if __name__=='__main__':main()
