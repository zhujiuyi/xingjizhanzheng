class_name XJRuntimeState
extends RefCounted
## Mutable typed authority. Nodes, views and SQL handles never enter this state.
const Dtos = preload("res://contracts/contract_dtos.gd")
const TABLES: Array[String] = [
	"player_state", "ship_state", "container_state", "item_instance_state", "equipment_state",
	"inventory_stack_state", "mission_state", "mission_objective_state", "mission_window_state",
	"mission_collect_event_state", "mission_claim_state", "mission_availability_state",
	"loan_state", "loan_asset_state", "loan_issue_state", "manufacture_input_state",
	"discovery_state", "unlock_state", "reputation_state", "resource_state", "gate_state",
	"ship_gate_cooldown_state", "sector_state", "station_economy_state", "shop_stock_state",
	"shop_ship_stock_state", "npc_state", "production_state", "rng_state", "action_receipt_state", "transfer_state", "base_module_state"]

var snapshot: Dtos.WorldSnapshotDto = Dtos.WorldSnapshotDto.new()
var world_id: String = ""
var session_id: String = ""
var epoch: int = 0
var capture_sequence: int = 0
var last_error: String = ""

func rows(table: String) -> Array:
	if not TABLES.has(table):
		last_error = "Unknown state table: " + table
		return []
	return snapshot.get(table + "_rows")

func find(table: String, column: String, value: Variant) -> RefCounted:
	for row in rows(table):
		if row.get(column) == value:
			return row
	return null

func add(table: String, row: RefCounted) -> bool:
	if not TABLES.has(table) or row == null:
		last_error = "Invalid typed state row"
		return false
	var collection: Array = rows(table)
	if collection.get_typed_script() != row.get_script():
		last_error = "DTO type does not match " + table
		return false
	collection.append(row)
	return true

func remove(table: String, row: RefCounted) -> bool:
	var collection: Array = rows(table)
	if not collection.has(row):
		return false
	collection.erase(row)
	return true

func player() -> Dtos.PlayerStateDto:
	return snapshot.player_state_rows[0] if not snapshot.player_state_rows.is_empty() else null

func ship() -> Dtos.ShipStateDto:
	var owner: Dtos.PlayerStateDto = player()
	return find("ship_state", "ship_instance_id", owner.controlled_ship_id) as Dtos.ShipStateDto if owner != null else null

func current_sector() -> String:
	var current: Dtos.ShipStateDto = ship()
	return current.sector_id if current != null else ""

static func new_row(table: String) -> RefCounted:
	match table:
		"player_state": return Dtos.PlayerStateDto.new()
		"ship_state": return Dtos.ShipStateDto.new()
		"container_state": return Dtos.ContainerStateDto.new()
		"item_instance_state": return Dtos.ItemInstanceStateDto.new()
		"equipment_state": return Dtos.EquipmentStateDto.new()
		"inventory_stack_state": return Dtos.InventoryStackStateDto.new()
		"mission_state": return Dtos.MissionStateDto.new()
		"mission_objective_state": return Dtos.MissionObjectiveStateDto.new()
		"mission_window_state": return Dtos.MissionWindowStateDto.new()
		"mission_collect_event_state": return Dtos.MissionCollectEventStateDto.new()
		"mission_claim_state": return Dtos.MissionClaimStateDto.new()
		"mission_availability_state": return Dtos.MissionAvailabilityStateDto.new()
		"loan_state": return Dtos.LoanStateDto.new()
		"loan_asset_state": return Dtos.LoanAssetStateDto.new()
		"loan_issue_state": return Dtos.LoanIssueStateDto.new()
		"manufacture_input_state": return Dtos.ManufactureInputStateDto.new()
		"discovery_state": return Dtos.DiscoveryStateDto.new()
		"unlock_state": return Dtos.UnlockStateDto.new()
		"reputation_state": return Dtos.ReputationStateDto.new()
		"resource_state": return Dtos.ResourceStateDto.new()
		"gate_state": return Dtos.GateStateDto.new()
		"ship_gate_cooldown_state": return Dtos.ShipGateCooldownStateDto.new()
		"sector_state": return Dtos.SectorStateDto.new()
		"station_economy_state": return Dtos.StationEconomyStateDto.new()
		"shop_stock_state": return Dtos.ShopStockStateDto.new()
		"shop_ship_stock_state": return Dtos.ShopShipStockStateDto.new()
		"npc_state": return Dtos.NpcStateDto.new()
		"production_state": return Dtos.ProductionStateDto.new()
		"rng_state": return Dtos.RngStateDto.new()
		"action_receipt_state": return Dtos.ActionReceiptStateDto.new()
		"transfer_state": return Dtos.TransferStateDto.new()
		"base_module_state": return Dtos.BaseModuleStateDto.new()
	return null
