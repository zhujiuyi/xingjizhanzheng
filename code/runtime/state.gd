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
	"shop_ship_stock_state", "npc_state", "production_state", "rng_state", "action_receipt_state", "transfer_state", "base_module_state", "encounter_state", "salvage_package_state", "spatial_state",
	"civilization_state", "territory_state", "war_campaign_state", "war_fleet_state",
	"industry_job_state", "industry_input_state", "station_demand_state",
	"exploration_instance_state", "exploration_actor_state", "exploration_claim_state", "exploration_progress_state", "exploration_research_state", "exploration_belt_state",
	"tactical_site_state", "npc_tactic_state", "ship_tactical_effect_state", "drone_bay_state", "operation_state", "specialization_progress_state", "specialization_evidence_state", "specialization_research_state", "remote_support_state", "consignment_state", "consignment_receipt_state", "civilization_command_state", "civilization_honor_evidence_state", "frontier_campaign_state", "frontier_actor_state", "frontier_campaign_receipt_state", "frontier_territory_state", "frontier_journal_state", "frontier_supply_order_state", "frontier_director_state", "hire_contract_state", "hire_receipt_state", "resource_intel_state", "demand_intel_state", "construction_state", "construction_input_state", "construction_receipt_state", "construction_evidence_state", "expedition_route_state", "expedition_run_state", "expedition_stage_state", "expedition_receipt_state", "campaign_director_state", "flight_record_state", "telemetry_total_state", "flight_material_state","telemetry_material_state","flight_repair_state","telemetry_repair_state", "trial_state", "trial_result_state", "scenario_actor_state", "tactical_award_state", "blockade_state", "blockade_node_state", "blockade_result_state", "telemetry_source_state", "activity_record_state", "telemetry_menu_state", "telemetry_timing_state", "activity_total_state", "crew_member_state", "crew_assignment_state", "fleet_deployment_state", "fleet_receipt_state", "crew_receipt_state", "fleet_total_state", "auxiliary_bay_state", "auxiliary_intel_state"]

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
		"auxiliary_intel_state": return Dtos.AuxiliaryIntelStateDto.new()
		"auxiliary_bay_state": return Dtos.AuxiliaryBayStateDto.new()
		"fleet_total_state": return Dtos.FleetTotalStateDto.new()
		"crew_receipt_state": return Dtos.CrewReceiptStateDto.new()
		"fleet_receipt_state": return Dtos.FleetReceiptStateDto.new()
		"fleet_deployment_state": return Dtos.FleetDeploymentStateDto.new()
		"crew_assignment_state": return Dtos.CrewAssignmentStateDto.new()
		"crew_member_state": return Dtos.CrewMemberStateDto.new()
		"activity_total_state": return Dtos.ActivityTotalStateDto.new()
		"telemetry_timing_state": return Dtos.TelemetryTimingStateDto.new()
		"telemetry_menu_state": return Dtos.TelemetryMenuStateDto.new()
		"activity_record_state": return Dtos.ActivityRecordStateDto.new()
		"telemetry_source_state": return Dtos.TelemetrySourceStateDto.new()
		"blockade_result_state": return Dtos.BlockadeResultStateDto.new()
		"blockade_node_state": return Dtos.BlockadeNodeStateDto.new()
		"blockade_state": return Dtos.BlockadeStateDto.new()
		"tactical_award_state": return Dtos.TacticalAwardStateDto.new()
		"scenario_actor_state": return Dtos.ScenarioActorStateDto.new()
		"trial_result_state": return Dtos.TrialResultStateDto.new()
		"trial_state": return Dtos.TrialStateDto.new()
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
		"encounter_state": return Dtos.EncounterStateDto.new()
		"salvage_package_state": return Dtos.SalvagePackageStateDto.new()
		"spatial_state": return Dtos.SpatialStateDto.new()
		"civilization_state": return Dtos.CivilizationStateDto.new()
		"territory_state": return Dtos.TerritoryStateDto.new()
		"war_campaign_state": return Dtos.WarCampaignStateDto.new()
		"war_fleet_state": return Dtos.WarFleetStateDto.new()
		"industry_job_state": return Dtos.IndustryJobStateDto.new()
		"industry_input_state": return Dtos.IndustryInputStateDto.new()
		"station_demand_state": return Dtos.StationDemandStateDto.new()
		"exploration_instance_state": return Dtos.ExplorationInstanceStateDto.new()
		"exploration_actor_state": return Dtos.ExplorationActorStateDto.new()
		"exploration_claim_state": return Dtos.ExplorationClaimStateDto.new()
		"exploration_progress_state": return Dtos.ExplorationProgressStateDto.new()
		"exploration_research_state": return Dtos.ExplorationResearchStateDto.new()
		"exploration_belt_state": return Dtos.ExplorationBeltStateDto.new()
		"specialization_progress_state": return Dtos.SpecializationProgressStateDto.new()
		"specialization_evidence_state": return Dtos.SpecializationEvidenceStateDto.new()
		"specialization_research_state": return Dtos.SpecializationResearchStateDto.new()
		"operation_state": return Dtos.OperationStateDto.new()
		"remote_support_state": return Dtos.RemoteSupportStateDto.new()
		"consignment_state": return Dtos.ConsignmentStateDto.new()
		"consignment_receipt_state": return Dtos.ConsignmentReceiptStateDto.new()
		"civilization_command_state": return Dtos.CivilizationCommandStateDto.new()
		"civilization_honor_evidence_state": return Dtos.CivilizationHonorEvidenceStateDto.new()
		"frontier_campaign_state": return Dtos.FrontierCampaignStateDto.new()
		"frontier_actor_state": return Dtos.FrontierActorStateDto.new()
		"frontier_campaign_receipt_state": return Dtos.FrontierCampaignReceiptStateDto.new()
		"frontier_territory_state": return Dtos.FrontierTerritoryStateDto.new()
		"frontier_journal_state": return Dtos.FrontierJournalStateDto.new()
		"frontier_supply_order_state": return Dtos.FrontierSupplyOrderStateDto.new()
		"frontier_director_state": return Dtos.FrontierDirectorStateDto.new()
		"hire_contract_state": return Dtos.HireContractStateDto.new()
		"resource_intel_state": return Dtos.ResourceIntelStateDto.new()
		"demand_intel_state": return Dtos.DemandIntelStateDto.new()
		"construction_state": return Dtos.ConstructionStateDto.new()
		"construction_input_state": return Dtos.ConstructionInputStateDto.new()
		"construction_receipt_state": return Dtos.ConstructionReceiptStateDto.new()
		"construction_evidence_state": return Dtos.ConstructionEvidenceStateDto.new()
		"expedition_route_state": return Dtos.ExpeditionRouteStateDto.new()
		"expedition_run_state": return Dtos.ExpeditionRunStateDto.new()
		"expedition_stage_state": return Dtos.ExpeditionStageStateDto.new()
		"expedition_receipt_state": return Dtos.ExpeditionReceiptStateDto.new()
		"campaign_director_state": return Dtos.CampaignDirectorStateDto.new()
		"flight_record_state": return Dtos.FlightRecordStateDto.new()
		"telemetry_total_state": return Dtos.TelemetryTotalStateDto.new()
		"flight_material_state": return Dtos.FlightMaterialStateDto.new()
		"telemetry_material_state": return Dtos.TelemetryMaterialStateDto.new()
		"flight_repair_state": return Dtos.FlightRepairStateDto.new()
		"telemetry_repair_state": return Dtos.TelemetryRepairStateDto.new()
		"hire_receipt_state": return Dtos.HireReceiptStateDto.new()
		"tactical_site_state": return Dtos.TacticalSiteStateDto.new()
		"npc_tactic_state": return Dtos.NpcTacticStateDto.new()
		"ship_tactical_effect_state": return Dtos.ShipTacticalEffectStateDto.new()
		"drone_bay_state": return Dtos.DroneBayStateDto.new()
	return null
