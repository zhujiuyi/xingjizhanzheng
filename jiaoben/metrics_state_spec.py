"""Additive measured material and repair rows; no balance values."""
STATES={
 'flight_material_state':('record_id,item_id','record_id TEXT NOT NULL,item_id TEXT NOT NULL,used_units INTEGER NOT NULL DEFAULT 0 CHECK(used_units>=0),returned_units INTEGER NOT NULL DEFAULT 0 CHECK(returned_units>=0)',
 '''FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,record_id) REFERENCES flight_record_state(snapshot_id,world_id,content_snapshot_id,record_id),FOREIGN KEY(content_snapshot_id,item_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)'''),
 'telemetry_material_state':('item_id','item_id TEXT NOT NULL,used_units INTEGER NOT NULL DEFAULT 0 CHECK(used_units>=0),returned_units INTEGER NOT NULL DEFAULT 0 CHECK(returned_units>=0)',
 '''FOREIGN KEY(content_snapshot_id,item_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)'''),
 'flight_repair_state':('record_id,repair_kind',"record_id TEXT NOT NULL,repair_kind TEXT NOT NULL CHECK(repair_kind IN('self','provided','received','station')),restored_hp REAL NOT NULL CHECK(restored_hp>0)",
 '''FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,record_id) REFERENCES flight_record_state(snapshot_id,world_id,content_snapshot_id,record_id)'''),
 'telemetry_repair_state':('repair_kind',"repair_kind TEXT NOT NULL CHECK(repair_kind IN('self','provided','received','station')),restored_hp REAL NOT NULL CHECK(restored_hp>0)",'')
}
