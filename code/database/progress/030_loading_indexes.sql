-- Progress format 27: bound parent-definition FK checks by content identity.
-- Snapshot-leading primary keys cannot seek the child rows checked when a
-- new frozen catalog is inserted. These indexes change no values or rules.
CREATE INDEX shop_stock_content_fk
ON shop_stock_state(content_snapshot_id,station_id,item_def_id);
CREATE INDEX shop_ship_stock_content_fk
ON shop_ship_stock_state(content_snapshot_id,station_id,ship_def_id);

CREATE TABLE database_meta_format27(
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    application_id TEXT NOT NULL CHECK(application_id='xingjizhanjian'),
    format_version INTEGER NOT NULL CHECK(format_version=27)
) STRICT;
INSERT INTO database_meta_format27 SELECT singleton,application_id,27 FROM database_meta;
DROP TABLE database_meta;
ALTER TABLE database_meta_format27 RENAME TO database_meta;
PRAGMA user_version=27;
