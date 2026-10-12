"""Append format23 measurements without changing existing snapshot columns."""
from pathlib import Path
from metrics_state_spec import STATES
ROOT=Path(__file__).resolve().parents[1]
def main():
 parts=['-- Aggregate measured investment/refunds and actual repair, no invented valuation.']
 for table,(key,columns,foreign) in STATES.items():
  extra=','+foreign if foreign else ''
  parts.append(f'''CREATE TABLE {table}(snapshot_id TEXT NOT NULL,world_id TEXT NOT NULL,content_snapshot_id TEXT NOT NULL,{columns},
 PRIMARY KEY(snapshot_id,world_id,content_snapshot_id,{key}),FOREIGN KEY(snapshot_id,world_id,content_snapshot_id) REFERENCES save_snapshot(snapshot_id,world_id,content_snapshot_id) ON DELETE CASCADE{extra}) STRICT;''')
  for action,ctx in [('INSERT','NEW'),('UPDATE','OLD'),('DELETE','OLD')]:
   guard=f"EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id={ctx}.snapshot_id AND status='sealed')"
   if action=='UPDATE':guard+=" OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')"
   parts.append(f"CREATE TRIGGER {table}_{action.lower()}_immutable BEFORE {action} ON {table} WHEN {guard} BEGIN SELECT RAISE(ABORT,'sealed snapshot is immutable'); END;")
 legacy=' OR '.join(f'EXISTS(SELECT 1 FROM {t} WHERE snapshot_id=NEW.snapshot_id)' for t in STATES)
 parts.append(f"CREATE TRIGGER metric_legacy_guard BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building' AND NOT EXISTS(SELECT 1 FROM frozen_campaign_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) AND ({legacy}) BEGIN SELECT RAISE(ABORT,'campaign measurements under legacy rules'); END;")
 parts.append('''CREATE TRIGGER metric_seal_validation BEFORE UPDATE OF status ON save_snapshot WHEN NEW.status='sealed' AND OLD.status='building'
BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM flight_material_state f LEFT JOIN telemetry_material_state t USING(snapshot_id,world_id,content_snapshot_id,item_id)
 WHERE f.snapshot_id=NEW.snapshot_id AND (t.item_id IS NULL OR f.used_units>t.used_units OR f.returned_units>t.returned_units)) THEN RAISE(ABORT,'outing material exceeds measured totals') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM telemetry_material_state t WHERE t.snapshot_id=NEW.snapshot_id AND
 (t.used_units<(SELECT coalesce(sum(f.used_units),0) FROM flight_material_state f WHERE f.snapshot_id=t.snapshot_id AND f.item_id=t.item_id) OR
 t.returned_units<(SELECT coalesce(sum(f.returned_units),0) FROM flight_material_state f WHERE f.snapshot_id=t.snapshot_id AND f.item_id=t.item_id))) THEN RAISE(ABORT,'material totals below retained outings') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM flight_repair_state f LEFT JOIN telemetry_repair_state t USING(snapshot_id,world_id,content_snapshot_id,repair_kind)
 WHERE f.snapshot_id=NEW.snapshot_id AND (t.repair_kind IS NULL OR f.restored_hp>t.restored_hp)) THEN RAISE(ABORT,'outing repair exceeds measured totals') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM telemetry_repair_state t WHERE t.snapshot_id=NEW.snapshot_id AND
 t.restored_hp+0.00001<(SELECT coalesce(sum(f.restored_hp),0) FROM flight_repair_state f WHERE f.snapshot_id=t.snapshot_id AND f.repair_kind=t.repair_kind)) THEN RAISE(ABORT,'repair totals below retained outings') END;
END;
CREATE TABLE database_meta_format23(singleton INTEGER PRIMARY KEY CHECK(singleton=1),application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),format_version INTEGER NOT NULL CHECK(format_version=23)) STRICT;
INSERT INTO database_meta_format23 SELECT singleton,application_id,23 FROM database_meta;
DROP TABLE database_meta;ALTER TABLE database_meta_format23 RENAME TO database_meta;PRAGMA user_version=23;''')
 (ROOT/'code/database/progress/026_metrics.sql').write_text('\n\n'.join(parts)+'\n',encoding='utf-8',newline='\n')
if __name__=='__main__':main()
