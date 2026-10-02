-- Generated, reviewed guards for every snapshot state table.

CREATE TRIGGER player_state_insert_immutable BEFORE INSERT ON player_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER player_state_update_immutable BEFORE UPDATE ON player_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER player_state_delete_immutable BEFORE DELETE ON player_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER ship_state_insert_immutable BEFORE INSERT ON ship_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER ship_state_update_immutable BEFORE UPDATE ON ship_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER ship_state_delete_immutable BEFORE DELETE ON ship_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER container_state_insert_immutable BEFORE INSERT ON container_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER container_state_update_immutable BEFORE UPDATE ON container_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER container_state_delete_immutable BEFORE DELETE ON container_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER item_instance_state_insert_immutable BEFORE INSERT ON item_instance_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER item_instance_state_update_immutable BEFORE UPDATE ON item_instance_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER item_instance_state_delete_immutable BEFORE DELETE ON item_instance_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER equipment_state_insert_immutable BEFORE INSERT ON equipment_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER equipment_state_update_immutable BEFORE UPDATE ON equipment_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER equipment_state_delete_immutable BEFORE DELETE ON equipment_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER inventory_stack_state_insert_immutable BEFORE INSERT ON inventory_stack_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER inventory_stack_state_update_immutable BEFORE UPDATE ON inventory_stack_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER inventory_stack_state_delete_immutable BEFORE DELETE ON inventory_stack_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_state_insert_immutable BEFORE INSERT ON mission_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_state_update_immutable BEFORE UPDATE ON mission_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_state_delete_immutable BEFORE DELETE ON mission_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_availability_state_insert_immutable BEFORE INSERT ON mission_availability_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_availability_state_update_immutable BEFORE UPDATE ON mission_availability_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_availability_state_delete_immutable BEFORE DELETE ON mission_availability_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_collect_event_state_insert_immutable BEFORE INSERT ON mission_collect_event_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_collect_event_state_update_immutable BEFORE UPDATE ON mission_collect_event_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_collect_event_state_delete_immutable BEFORE DELETE ON mission_collect_event_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_claim_state_insert_immutable BEFORE INSERT ON mission_claim_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_claim_state_update_immutable BEFORE UPDATE ON mission_claim_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_claim_state_delete_immutable BEFORE DELETE ON mission_claim_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_state_insert_immutable BEFORE INSERT ON loan_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_state_update_immutable BEFORE UPDATE ON loan_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_state_delete_immutable BEFORE DELETE ON loan_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_asset_state_insert_immutable BEFORE INSERT ON loan_asset_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_asset_state_update_immutable BEFORE UPDATE ON loan_asset_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_asset_state_delete_immutable BEFORE DELETE ON loan_asset_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_issue_state_insert_immutable BEFORE INSERT ON loan_issue_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_issue_state_update_immutable BEFORE UPDATE ON loan_issue_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER loan_issue_state_delete_immutable BEFORE DELETE ON loan_issue_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER manufacture_input_state_insert_immutable BEFORE INSERT ON manufacture_input_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER manufacture_input_state_update_immutable BEFORE UPDATE ON manufacture_input_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER manufacture_input_state_delete_immutable BEFORE DELETE ON manufacture_input_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER discovery_state_insert_immutable BEFORE INSERT ON discovery_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER discovery_state_update_immutable BEFORE UPDATE ON discovery_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER discovery_state_delete_immutable BEFORE DELETE ON discovery_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_objective_state_insert_immutable BEFORE INSERT ON mission_objective_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_objective_state_update_immutable BEFORE UPDATE ON mission_objective_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_objective_state_delete_immutable BEFORE DELETE ON mission_objective_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_window_state_insert_immutable BEFORE INSERT ON mission_window_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_window_state_update_immutable BEFORE UPDATE ON mission_window_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER mission_window_state_delete_immutable BEFORE DELETE ON mission_window_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER unlock_state_insert_immutable BEFORE INSERT ON unlock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER unlock_state_update_immutable BEFORE UPDATE ON unlock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER unlock_state_delete_immutable BEFORE DELETE ON unlock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER reputation_state_insert_immutable BEFORE INSERT ON reputation_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER reputation_state_update_immutable BEFORE UPDATE ON reputation_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER reputation_state_delete_immutable BEFORE DELETE ON reputation_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER shop_stock_state_insert_immutable BEFORE INSERT ON shop_stock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER shop_stock_state_update_immutable BEFORE UPDATE ON shop_stock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER shop_stock_state_delete_immutable BEFORE DELETE ON shop_stock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER shop_ship_stock_state_insert_immutable BEFORE INSERT ON shop_ship_stock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER shop_ship_stock_state_update_immutable BEFORE UPDATE ON shop_ship_stock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER shop_ship_stock_state_delete_immutable BEFORE DELETE ON shop_ship_stock_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER station_economy_state_insert_immutable BEFORE INSERT ON station_economy_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER station_economy_state_update_immutable BEFORE UPDATE ON station_economy_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER station_economy_state_delete_immutable BEFORE DELETE ON station_economy_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER sector_state_insert_immutable BEFORE INSERT ON sector_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER sector_state_update_immutable BEFORE UPDATE ON sector_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER sector_state_delete_immutable BEFORE DELETE ON sector_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER npc_state_insert_immutable BEFORE INSERT ON npc_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER npc_state_update_immutable BEFORE UPDATE ON npc_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER npc_state_delete_immutable BEFORE DELETE ON npc_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER production_state_insert_immutable BEFORE INSERT ON production_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER production_state_update_immutable BEFORE UPDATE ON production_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER production_state_delete_immutable BEFORE DELETE ON production_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER resource_state_insert_immutable BEFORE INSERT ON resource_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER resource_state_update_immutable BEFORE UPDATE ON resource_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER resource_state_delete_immutable BEFORE DELETE ON resource_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER gate_state_insert_immutable BEFORE INSERT ON gate_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER gate_state_update_immutable BEFORE UPDATE ON gate_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER gate_state_delete_immutable BEFORE DELETE ON gate_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER ship_gate_cooldown_state_insert_immutable BEFORE INSERT ON ship_gate_cooldown_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER ship_gate_cooldown_state_update_immutable BEFORE UPDATE ON ship_gate_cooldown_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER ship_gate_cooldown_state_delete_immutable BEFORE DELETE ON ship_gate_cooldown_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER rng_state_insert_immutable BEFORE INSERT ON rng_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER rng_state_update_immutable BEFORE UPDATE ON rng_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER rng_state_delete_immutable BEFORE DELETE ON rng_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER action_receipt_state_insert_immutable BEFORE INSERT ON action_receipt_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER action_receipt_state_update_immutable BEFORE UPDATE ON action_receipt_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER action_receipt_state_delete_immutable BEFORE DELETE ON action_receipt_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER transfer_state_insert_immutable BEFORE INSERT ON transfer_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER transfer_state_update_immutable BEFORE UPDATE ON transfer_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=NEW.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER transfer_state_delete_immutable BEFORE DELETE ON transfer_state
WHEN EXISTS(SELECT 1 FROM save_snapshot WHERE snapshot_id=OLD.snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed state is immutable'); END;

CREATE TRIGGER content_table_manifest_insert_immutable BEFORE INSERT ON content_table_manifest
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed manifest is immutable'); END;

CREATE TRIGGER content_table_manifest_update_immutable BEFORE UPDATE ON content_table_manifest
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed manifest is immutable'); END;

CREATE TRIGGER content_table_manifest_delete_immutable BEFORE DELETE ON content_table_manifest
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed manifest is immutable'); END;

CREATE TRIGGER content_view_manifest_insert_immutable BEFORE INSERT ON content_view_manifest
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed manifest is immutable'); END;

CREATE TRIGGER content_view_manifest_update_immutable BEFORE UPDATE ON content_view_manifest
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed') OR EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=NEW.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed manifest is immutable'); END;

CREATE TRIGGER content_view_manifest_delete_immutable BEFORE DELETE ON content_view_manifest
WHEN EXISTS(SELECT 1 FROM content_snapshot WHERE content_snapshot_id=OLD.content_snapshot_id AND status='sealed')
BEGIN SELECT RAISE(ABORT,'sealed manifest is immutable'); END;
