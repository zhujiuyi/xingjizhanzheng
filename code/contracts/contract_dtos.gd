class_name XJContractDtos
extends RefCounted
## 纯类型数据示例：无 Node/Resource/SQL/玩法循环。见 doc/21。
## 空 ID 是构造阶段占位；发布前必须验证，不是合法业务值。
const Types = preload("res://contracts/contract_types.gd")

class SessionRefDto extends RefCounted:
	var world_id: String = ""
	var session_id: String = ""
	var epoch: int = 0

## mutable控制记录；不属于WorldSnapshot业务行。
class RuntimeSessionRowDto extends RefCounted:
	var world_id: String = ""
	var session_id: String = ""
	var epoch: int = 0
	var has_loaded_snapshot_id: bool = false
	var loaded_snapshot_id: String = ""
	var has_resume_snapshot_id: bool = false
	var resume_snapshot_id: String = ""
	var has_transfer_barrier_id: bool = false
	var transfer_barrier_id: String = ""
	var last_committed_sequence: int = 0

class SaveSlotDto extends RefCounted:
	var slot_id: String = ""
	var profile_id: String = ""
	var world_id: String = ""
	var slot_kind: String = ""
	var slot_index: int = 0
	var label: String = ""
	var current_snapshot_id: String = ""
	var content_snapshot_id: String = ""
	var writer_session_id: String = ""
	var writer_epoch: int = 0
	var generation: int = 0
	var updated_utc: String = ""

class ProfilePreferenceDto extends RefCounted:
	var profile_id: String = ""
	var mouse_sensitivity: float = 0.0
	var master_volume: float = 0.0
	var vfx_intensity: float = 0.0
	var quality_mode: String = ""

class ContentRefDto extends RefCounted:
	var content_snapshot_id: String = ""
	var content_hash: String = ""
	var pack_id: String = ""
	var content_version: String = ""
	var catalog_schema_version: int = 0
	var ruleset_version: String = ""
	var rules_code_version: String = ""
	var asset_manifest_version: String = ""
	var asset_manifest_sha256: String = ""
	var frozen_adapter_version: String = ""

class EntityVersionDto extends RefCounted:
	var entity_kind: String = ""
	var entity_id: String = ""
	var expected_version: int = 0

class CommandEnvelopeDto extends RefCounted:
	var action_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var actor_player_id: String = ""
	var action_kind: Types.ActionKind = Types.ActionKind.THRUST
	var target_entity_id: String = ""
	var requested_tick: int = 0
	var versions: Array[EntityVersionDto] = []

class FlightInputDto extends RefCounted:
	var thrust_x: float = 0.0
	var thrust_y: float = 0.0
	var thrust_z: float = 0.0
	# Transient manual intent; ZERO retains ordinary ship-local navigation.
	var view_thrust_direction: Vector3 = Vector3.ZERO
	var yaw_request: float = 0.0
	var pitch_request: float = 0.0
	var roll_request: float = 0.0
	var brake_requested: bool = false
	var engine_cycle_requested: bool = false

class InventoryMoveDto extends RefCounted:
	var source_container_id: String = ""
	var destination_container_id: String = ""
	var has_stack_id: bool = false
	var stack_id: String = ""
	var has_item_instance_id: bool = false
	var item_instance_id: String = ""
	var quantity: int = 0

class FittingRequestDto extends RefCounted:
	var ship_instance_id: String = ""
	var slot_type: Types.SlotType = Types.SlotType.WEAPON
	var slot_index: int = 0
	var item_instance_id: String = ""
	var station_container_id: String = ""

class TradeRequestDto extends RefCounted:
	var station_id: String = ""
	var item_def_id: String = ""
	var has_item_instance_id: bool = false
	var item_instance_id: String = ""
	var has_stack_id: bool = false
	var stack_id: String = ""
	var quantity: int = 0
	var quoted_unit_credit: int = 0
	var destination_container_id: String = ""

class RecipeRequestDto extends RefCounted:
	var station_id: String = ""
	var recipe_id: String = ""
	var batches: int = 0
	var source_container_id: String = ""
	var destination_container_id: String = ""
	var item_instance_ids: Array[String] = []

class MissionRequestDto extends RefCounted:
	var mission_def_id: String = ""
	var has_mission_instance_id: bool = false
	var mission_instance_id: String = ""
	var station_id: String = ""
	var stack_ids: Array[String] = []
	var replacement_ship_id: String = ""

class LoanRequestDto extends RefCounted:
	var loan_service_id: String = ""
	var loan_id: String = ""
	var station_id: String = ""
	var has_replacement_ship_id: bool = false
	var replacement_ship_id: String = ""

class TravelRequestDto extends RefCounted:
	var transfer_id: String = ""
	var ship_instance_id: String = ""
	var endpoint_id: String = ""
	var connection_id: String = ""

class TargetRequestDto extends RefCounted:
	var target_entity_id: String = ""
	var module_instance_ids: Array[String] = []

class ShipServiceRequestDto extends RefCounted:
	var station_id: String = ""
	var ship_instance_id: String = ""
	var ship_def_id: String = ""
	var layer_id: String = ""
	var module_instance_ids: Array[String] = []
	var quoted_total_credit: int = 0

class CameraRequestDto extends RefCounted:
	var mode: Types.CameraMode = Types.CameraMode.FOLLOW

class ActionResultDto extends RefCounted:
	var action_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var phase: Types.ActionPhase = Types.ActionPhase.RECEIVED
	var reject_code: Types.RejectCode = Types.RejectCode.NONE
	var action_kind: Types.ActionKind = Types.ActionKind.THRUST
	var applied_tick: int = 0
	var result_entity_ids: Array[String] = []
	var changed_versions: Array[EntityVersionDto] = []
	var display_reason_key: String = ""
	var autosave_request_id: String = ""

class SaveEligibilityDto extends RefCounted:
	var allowed: bool = false
	var reasons: Array[Types.SaveBlockReason] = []
	var checked_tick: int = 0

class SaveRequestDto extends RefCounted:
	var save_request_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var slot_id: String = ""
	var slot_kind: String = ""
	var slot_index: int = 0
	var slot_label: String = ""
	var expected_slot_generation: int = 0
	var reason: String = ""
	var has_transfer_id: bool = false
	var transfer_id: String = ""

class SaveResultDto extends RefCounted:
	var save_request_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var phase: Types.SavePhase = Types.SavePhase.REQUESTED
	var reject_code: Types.RejectCode = Types.RejectCode.NONE
	var snapshot_id: String = ""
	var slot_id: String = ""
	var committed_generation: int = 0
	var saved_utc: String = ""

class LoadRequestDto extends RefCounted:
	var load_request_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var slot_id: String = ""
	var expected_slot_generation: int = 0
	var target_snapshot_id: String = ""

class LoadResultDto extends RefCounted:
	var load_request_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var phase: Types.LoadPhase = Types.LoadPhase.REQUESTED
	var reject_code: Types.RejectCode = Types.RejectCode.NONE
	var snapshot_id: String = ""
	var sector_id: String = ""

class TravelResultDto extends RefCounted:
	var transfer_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var phase: Types.TravelPhase = Types.TravelPhase.IDLE
	var reject_code: Types.RejectCode = Types.RejectCode.NONE
	var origin_snapshot_id: String = ""
	var destination_snapshot_id: String = ""
	var destination_sector_id: String = ""

class SnapshotMetaDto extends RefCounted:
	var snapshot_id: String = ""
	var world_id: String = ""
	var content_snapshot_id: String = ""
	var writer_session_id: String = ""
	var writer_epoch: int = 0
	var save_request_id: String = ""
	var capture_sequence: int = 0
	var saved_utc: String = ""
	var simulation_tick: int = 0
	var reason: String = ""
	var has_transfer_id: bool = false
	var transfer_id: String = ""

class AnchorDto extends RefCounted:
	var anchor_id: String = ""
	var sector_id: String = ""
	var anchor_kind: String = ""
	var pos_x: float = 0.0
	var pos_y: float = 0.0
	var pos_z: float = 0.0
	var yaw_rad: float = 0.0
	var interaction_radius_m: float = 0.0
	var safe_radius_m: float = 0.0

class SectorReadyDto extends RefCounted:
	var load_request_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var sector_id: String = ""
	var content: ContentRefDto = ContentRefDto.new()
	var anchors: Array[AnchorDto] = []
	var asset_ids: Array[String] = []
	var reject_code: Types.RejectCode = Types.RejectCode.NONE

class ShipFactoryRequestDto extends RefCounted:
	var content: ContentRefDto = ContentRefDto.new()
	var ship_instance_id: String = ""
	var ship_def_id: String = ""
	var asset_id: String = ""

class ShipFactoryResultDto extends RefCounted:
	var ship_instance_id: String = ""
	var asset_id: String = ""
	var mounted_item_instance_ids: Array[String] = []
	var reject_code: Types.RejectCode = Types.RejectCode.NONE

class EventDto extends RefCounted:
	var event_id: String = ""
	var session: SessionRefDto = SessionRefDto.new()
	var simulation_tick: int = 0
	var kind: Types.EventKind = Types.EventKind.UI_RESULT
	var source_entity_id: String = ""
	var target_entity_id: String = ""
	var module_instance_id: String = ""
	var transfer_id: String = ""
	var slot_type: Types.SlotType = Types.SlotType.WEAPON
	var slot_index: int = 0
	var pos_x: float = 0.0
	var pos_y: float = 0.0
	var pos_z: float = 0.0
	var direction_x: float = 0.0
	var direction_y: float = 0.0
	var direction_z: float = 0.0
	var has_end_position: bool = false
	var end_x: float = 0.0
	var end_y: float = 0.0
	var end_z: float = 0.0
	var normal_x: float = 0.0
	var normal_y: float = 0.0
	var normal_z: float = 0.0
	var damage_type: String = ""
	var defense_layer: String = ""
	var amount: float = 0.0
	var active: bool = false
	var remaining_s: float = 0.0
	var transfer_phase: Types.TravelPhase = Types.TravelPhase.IDLE


## 对应 progress.player_state；公共复合键由 WorldSnapshot.meta 注入。
class PlayerStateDto extends RefCounted:
	var player_id: String = ""
	var controlled_ship_id: String = ""
	var currency_id: String = ""
	var credit: int = 0
	var camera_mode: Types.CameraMode = Types.CameraMode.FOLLOW
	var has_docked_station_id: bool = false
	var docked_station_id: String = ""

## 对应 progress.ship_state；公共复合键由 WorldSnapshot.meta 注入。
class ShipStateDto extends RefCounted:
	var ship_instance_id: String = ""
	var owner_player_id: String = ""
	var ship_def_id: String = ""
	var sector_id: String = ""
	var has_station_id: bool = false
	var station_id: String = ""
	var status: Types.ShipStatus = Types.ShipStatus.FLYING
	var pos_x: float = 0.0
	var pos_y: float = 0.0
	var pos_z: float = 0.0
	var quat_x: float = 0.0
	var quat_y: float = 0.0
	var quat_z: float = 0.0
	var quat_w: float = 1.0
	var vel_x: float = 0.0
	var vel_y: float = 0.0
	var vel_z: float = 0.0
	var angular_x: float = 0.0
	var angular_y: float = 0.0
	var angular_z: float = 0.0
	var shield: float = 0.0
	var armor: float = 0.0
	var hull: float = 0.0
	var energy: float = 0.0
	var heat: float = 0.0
	var overheated: bool = false
	var shield_delay_remaining_s: float = 0.0
	var state_version: int = 0
	var policy_id: String = ""

## 对应 progress.container_state；公共复合键由 WorldSnapshot.meta 注入。
class ContainerStateDto extends RefCounted:
	var container_id: String = ""
	var owner_player_id: String = ""
	var kind: Types.ContainerKind = Types.ContainerKind.STATION
	var has_ship_instance_id: bool = false
	var ship_instance_id: String = ""
	var has_ship_def_id: bool = false
	var ship_def_id: String = ""
	var has_station_id: bool = false
	var station_id: String = ""
	var sector_id: String = ""
	var has_slot_type: bool = false
	var slot_type: Types.SlotType = Types.SlotType.WEAPON
	var has_slot_index: bool = false
	var slot_index: int = 0
	var has_pos_x: bool = false
	var pos_x: float = 0.0
	var has_pos_y: bool = false
	var pos_y: float = 0.0
	var has_pos_z: bool = false
	var pos_z: float = 0.0

## 对应 progress.item_instance_state；公共复合键由 WorldSnapshot.meta 注入。
class ItemInstanceStateDto extends RefCounted:
	var item_instance_id: String = ""
	var item_def_id: String = ""
	var owner_player_id: String = ""
	var container_id: String = ""
	var policy_id: String = ""
	var origin_kind: Types.ItemOrigin = Types.ItemOrigin.PURCHASE
	var salvage_recipe_id: String = ""
	var durability: float = 0.0
	var quality_multiplier: float = 0.0
	var has_manufacture_batch_id: bool = false
	var manufacture_batch_id: String = ""

## 对应 progress.equipment_state；公共复合键由 WorldSnapshot.meta 注入。
class EquipmentStateDto extends RefCounted:
	var slot_container_id: String = ""
	var item_instance_id: String = ""
	var module_def_id: String = ""
	var cooldown_remaining_s: float = 0.0
	var active_remaining_s: float = 0.0
	var cycle_paid: bool = false
	var enabled: bool = false

## 对应 progress.inventory_stack_state；公共复合键由 WorldSnapshot.meta 注入。
class InventoryStackStateDto extends RefCounted:
	var container_id: String = ""
	var stack_id: String = ""
	var item_def_id: String = ""
	var quantity: int = 0
	var policy_id: String = ""
	var origin_kind: Types.StackOrigin = Types.StackOrigin.NORMAL
	var has_bound_mission_instance_id: bool = false
	var bound_mission_instance_id: String = ""
	var has_loan_id: bool = false
	var loan_id: String = ""

## 对应 progress.mission_state；公共复合键由 WorldSnapshot.meta 注入。
class MissionStateDto extends RefCounted:
	var mission_instance_id: String = ""
	var player_id: String = ""
	var mission_def_id: String = ""
	var attempt_number: int = 0
	var status: String = ""
	var has_deadline_remaining_s: bool = false
	var deadline_remaining_s: float = 0.0
	var cooldown_remaining_s: float = 0.0
	var collected_units: int = 0
	var delivered_units: int = 0
	var reward_claimed: bool = false

## 对应 progress.mission_availability_state；公共复合键由 WorldSnapshot.meta 注入。
class MissionAvailabilityStateDto extends RefCounted:
	var player_id: String = ""
	var mission_def_id: String = ""
	var status: String = ""

## 对应 progress.mission_collect_event_state；公共复合键由 WorldSnapshot.meta 注入。
class MissionCollectEventStateDto extends RefCounted:
	var event_id: String = ""
	var mission_instance_id: String = ""
	var item_def_id: String = ""
	var quantity: int = 0
	var event_tick: int = 0

## 对应 progress.mission_claim_state；公共复合键由 WorldSnapshot.meta 注入。
class MissionClaimStateDto extends RefCounted:
	var mission_instance_id: String = ""
	var action_id: String = ""

## 对应 progress.loan_state；公共复合键由 WorldSnapshot.meta 注入。
class LoanStateDto extends RefCounted:
	var loan_id: String = ""
	var player_id: String = ""
	var loan_service_id: String = ""
	var mission_instance_id: String = ""
	var has_current_ship_id: bool = false
	var current_ship_id: String = ""
	var status: Types.LoanStatus = Types.LoanStatus.AVAILABLE
	var issuance_count: int = 0
	var has_quota_remaining_units: bool = false
	var quota_remaining_units: int = 0
	var replacement_remaining_s: float = 0.0

## 对应 progress.loan_asset_state；公共复合键由 WorldSnapshot.meta 注入。
class LoanAssetStateDto extends RefCounted:
	var loan_id: String = ""
	var item_instance_id: String = ""

## 对应 progress.loan_issue_state；公共复合键由 WorldSnapshot.meta 注入。
class LoanIssueStateDto extends RefCounted:
	var loan_id: String = ""
	var issuance_index: int = 0
	var ship_instance_id: String = ""
	var status: String = ""

## 对应 progress.manufacture_input_state；公共复合键由 WorldSnapshot.meta 注入。
class ManufactureInputStateDto extends RefCounted:
	var item_instance_id: String = ""
	var input_item_id: String = ""
	var input_quantity: int = 0

## 对应 progress.discovery_state；公共复合键由 WorldSnapshot.meta 注入。
class DiscoveryStateDto extends RefCounted:
	var player_id: String = ""
	var discovery_id: String = ""
	var sector_id: String = ""
	var kind: Types.DiscoveryKind = Types.DiscoveryKind.SIGNAL
	var has_signal_id: bool = false
	var signal_id: String = ""
	var has_connection_id: bool = false
	var connection_id: String = ""
	var has_node_id: bool = false
	var node_id: String = ""
	var discovered_tick: int = 0

## 对应 progress.mission_objective_state；公共复合键由 WorldSnapshot.meta 注入。
class MissionObjectiveStateDto extends RefCounted:
	var mission_instance_id: String = ""
	var mission_def_id: String = ""
	var objective_index: int = 0
	var progress_units: int = 0

## 对应 progress.mission_window_state；公共复合键由 WorldSnapshot.meta 注入。
class MissionWindowStateDto extends RefCounted:
	var player_id: String = ""
	var mission_def_id: String = ""
	var remaining_s: float = 0.0
	var window_index: int = 0
	var accepted_window_count: int = 0
	var completed_window_count: int = 0
	var has_last_accept_tick: bool = false
	var last_accept_tick: int = 0
	var has_last_failure_tick: bool = false
	var last_failure_tick: int = 0
	var has_last_settle_tick: bool = false
	var last_settle_tick: int = 0

## 对应 progress.unlock_state；公共复合键由 WorldSnapshot.meta 注入。
class UnlockStateDto extends RefCounted:
	var player_id: String = ""
	var unlock_id: String = ""
	var acquired_tick: int = 0

## 对应 progress.reputation_state；公共复合键由 WorldSnapshot.meta 注入。
class ReputationStateDto extends RefCounted:
	var player_id: String = ""
	var faction_id: String = ""
	var reputation: int = 0

## 对应 progress.shop_stock_state；公共复合键由 WorldSnapshot.meta 注入。
class ShopStockStateDto extends RefCounted:
	var station_id: String = ""
	var item_def_id: String = ""
	var quantity: int = 0
	var buyback_remaining_units: int = 0
	var ask_credit: int = 0
	var bid_credit: int = 0
	var refresh_remaining_s: float = 0.0

## 对应 progress.shop_ship_stock_state；公共复合键由 WorldSnapshot.meta 注入。
class ShopShipStockStateDto extends RefCounted:
	var station_id: String = ""
	var ship_def_id: String = ""
	var quantity: int = 0
	var ask_credit: int = 0
	var bid_credit: int = 0
	var refresh_remaining_s: float = 0.0

## 对应 progress.station_economy_state；公共复合键由 WorldSnapshot.meta 注入。
class StationEconomyStateDto extends RefCounted:
	var station_id: String = ""
	var buyback_remaining_credit: int = 0
	var refresh_remaining_s: float = 0.0

## 对应 progress.sector_state；公共复合键由 WorldSnapshot.meta 注入。
class SectorStateDto extends RefCounted:
	var sector_id: String = ""
	var visited: bool = false
	var generation_counter: int = 0

## 对应 progress.npc_state；公共复合键由 WorldSnapshot.meta 注入。
class NpcStateDto extends RefCounted:
	var npc_instance_id: String = ""
	var spawn_id: String = ""
	var sector_id: String = ""
	var generation: int = 0
	var has_mission_instance_id: bool = false
	var mission_instance_id: String = ""
	var alive: bool = false
	var shield: float = 0.0
	var armor: float = 0.0
	var hull: float = 0.0
	var pos_x: float = 0.0
	var pos_y: float = 0.0
	var pos_z: float = 0.0
	var quat_x: float = 0.0
	var quat_y: float = 0.0
	var quat_z: float = 0.0
	var quat_w: float = 1.0
	var vel_x: float = 0.0
	var vel_y: float = 0.0
	var vel_z: float = 0.0
	var angular_x: float = 0.0
	var angular_y: float = 0.0
	var angular_z: float = 0.0
	var behavior_phase: Types.NpcPhase = Types.NpcPhase.IDLE
	var wait_remaining_s: float = 0.0
	var patrol_point_index: int = 0
	var cooldown_remaining_s: float = 0.0
	var respawn_remaining_s: float = 0.0
	var bounty_claimed: bool = false
	var loot_claimed: bool = false

## 对应 progress.production_state；公共复合键由 WorldSnapshot.meta 注入。
class ProductionStateDto extends RefCounted:
	var production_id: String = ""
	var player_id: String = ""
	var recipe_id: String = ""
	var station_id: String = ""
	var batches: int = 0
	var output_claimed: bool = false

## 对应 progress.resource_state；公共复合键由 WorldSnapshot.meta 注入。
class ResourceStateDto extends RefCounted:
	var node_id: String = ""
	var remaining_units: int = 0
	var respawn_remaining_s: float = 0.0

## 对应 progress.gate_state；公共复合键由 WorldSnapshot.meta 注入。
class GateStateDto extends RefCounted:
	var connection_id: String = ""
	var enabled: bool = false
	var has_remaining_mass_budget_kg: bool = false
	var remaining_mass_budget_kg: float = 0.0
	var has_lifetime_remaining_s: bool = false
	var lifetime_remaining_s: float = 0.0

## 对应 progress.ship_gate_cooldown_state；公共复合键由 WorldSnapshot.meta 注入。
class ShipGateCooldownStateDto extends RefCounted:
	var ship_instance_id: String = ""
	var remaining_s: float = 0.0

## 对应 progress.rng_state；公共复合键由 WorldSnapshot.meta 注入。
class RngStateDto extends RefCounted:
	var stream_id: String = ""
	var algorithm: String = ""
	var state_hi: int = 0
	var state_lo: int = 0
	var increment_hi: int = 0
	var increment_lo: int = 0

## 对应 progress.action_receipt_state；公共复合键由 WorldSnapshot.meta 注入。
class ActionReceiptStateDto extends RefCounted:
	var action_id: String = ""
	var actor_player_id: String = ""
	var source_epoch: int = 0
	var action_kind: String = ""
	var result_code: String = ""
	var has_result_entity_id: bool = false
	var result_entity_id: String = ""

## 对应 progress.transfer_state；公共复合键由 WorldSnapshot.meta 注入。
class TransferStateDto extends RefCounted:
	var transfer_id: String = ""
	var ship_instance_id: String = ""
	var connection_id: String = ""
	var endpoint: Types.TransferEndpoint = Types.TransferEndpoint.ORIGIN

## 对应format2 progress.base_module_state：站点设施，无Node引用。
class BaseModuleStateDto extends RefCounted:
	var player_id: String = ""
	var base_instance_id: String = ""
	var base_module_id: String = ""
	var station_id: String = ""
	var enabled: bool = false

## 战斗地点的整群代次与世界时间冷却，和成员 NPC 一同封存。
class EncounterStateDto extends RefCounted:
	var encounter_id: String = ""
	var generation: int = 0
	var respawn_remaining_s: float = 0.0

## 独立回收包：结果在击毁时预定，打开后保留唯一来源记录。
class SalvagePackageStateDto extends RefCounted:
	var package_id: String = ""
	var package_def_id: String = ""
	var source_npc_instance_id: String = ""
	var source_generation: int = 0
	var has_host_container_id: bool = false
	var host_container_id: String = ""
	var reward_id: String = ""
	var status: String = "sealed"
	var has_opened_station_id: bool = false
	var opened_station_id: String = ""
	var opened_tick: int = 0

## 实体所属地点；xyz仍由原实体持有，不复制另一份位置。
class SpatialStateDto extends RefCounted:
	var entity_kind: String = ""
	var entity_id: String = ""
	var site_id: String = ""

## 完整世界快照：所有已初始化星区状态都在数组中，不限当前已加载星区。
class CivilizationStateDto extends RefCounted:
	var player_id: String = ""
	var has_faction_id: bool = false
	var faction_id: String = ""
	var joined_tick: int = 0
	var switch_cooldown_remaining_s: float = 0.0

class CivilizationRequestDto extends RefCounted:
	var action: String = ""
	var target_id: String = ""
	var quantity: int = 1
	var extra: String = ""

class TerritoryStateDto extends RefCounted:
	var sector_id: String = ""
	var has_faction_id: bool = false
	var faction_id: String = ""
	var captured_tick: int = 0

class WarCampaignStateDto extends RefCounted:
	var war_id: String = ""
	var player_id: String = ""
	var status: String = "assembling"
	var fleet_order: String = "advance"
	var focus_target_id: String = ""
	var capture_remaining_s: float = 0.0
	var attempt: int = 1
	var started_tick: int = 0
	var finished_tick: int = 0
	var rewards_claimed: bool = false

class WarFleetStateDto extends RefCounted:
	var npc_instance_id: String = ""
	var war_id: String = ""
	var side: String = "ally"

## 对应 progress.industry_job_state；材料在提交时托管，产物只能在原站领取一次。
class IndustryJobStateDto extends RefCounted:
	var job_id: String = ""
	var player_id: String = ""
	var station_id: String = ""
	var blueprint_id: String = ""
	var batches: int = 0
	var status: String = "queued"
	var queue_sequence: int = 0
	var duration_s: float = 0.0
	var remaining_s: float = 0.0
	var paid_credit: int = 0
	var created_tick: int = 0
	var finished_tick: int = 0

class IndustryInputStateDto extends RefCounted:
	var job_id: String = ""
	var item_id: String = ""
	var quantity: int = 0

class StationDemandStateDto extends RefCounted:
	var demand_id: String = ""
	var generation: int = 1
	var status: String = "active"
	var remaining_units: int = 0
	var phase_remaining_s: float = 0.0
	var benefit_remaining_s: float = 0.0
	var completed_cycles: int = 0

class ExplorationInstanceStateDto extends RefCounted:
	var event_id: String = ""
	var generation: int = 1
	var variant_id: String = ""
	var variant_seed: int = 0
	var phase: String = "clue"
	var choice_id: String = ""
	var operation_kind: String = ""
	var operation_remaining_s: float = 0.0
	var elapsed_s: float = 0.0
	var cooldown_remaining_s: float = 0.0
	var evidence_units: int = 0
	var stabilized: bool = false
	var hazard_clock_s: float = 0.0
	var outcome: String = ""

class ExplorationActorStateDto extends RefCounted:
	var npc_instance_id: String = ""
	var event_id: String = ""
	var generation: int = 1
	var actor_role: String = "enemy"

class ExplorationClaimStateDto extends RefCounted:
	var player_id: String = ""
	var event_id: String = ""
	var generation: int = 1
	var variant_id: String = ""
	var outcome: String = "partial"
	var credit_units: int = 0
	var insight_units: int = 0
	var reputation_units: int = 0
	var has_demand_id: bool = false
	var demand_id: String = ""
	var demand_generation: int = 0
	var claimed_tick: int = 0

class ExplorationProgressStateDto extends RefCounted:
	var player_id: String = ""
	var insight_available: int = 0
	var insight_earned: int = 0

class ExplorationResearchStateDto extends RefCounted:
	var player_id: String = ""
	var research_id: String = ""
	var spent_insight: int = 0
	var paid_credit: int = 0
	var completed_tick: int = 0

class ExplorationBeltStateDto extends RefCounted:
	var event_id: String = ""
	var route_id: String = ""
	var stage_index: int = 0
	var warning_stage_index: int = 0
	var start_elapsed_s: float = 0.0
	var initial_units: int = 0

class SpecializationProgressStateDto extends RefCounted:
	var player_id: String = ""
	var earned_points: int = 0
	var spent_points: int = 0
	var donated_points: int = 0
class SpecializationEvidenceStateDto extends RefCounted:
	var player_id: String = ""
	var source_token: String = ""
	var source_kind: String = ""
	var source_def_id: String = ""
	var generation: int = 0
	var source_units: int = 0
	var awarded_points: int = 0
	var material_units: int = 0
	var paid_credit: int = 0
class SpecializationResearchStateDto extends RefCounted:
	var player_id: String = ""
	var research_id: String = ""
	var invested_points: int = 0
	var paid_credit: int = 0
	var completed: bool = false
	var completed_tick: int = 0

class OperationStateDto extends RefCounted:
	var operation_id: String = ""
	var generation: int = 0
	var phase: String = "available"
	var remaining_s: float = 0.0
	var cooldown_remaining_s: float = 0.0
	var has_payload_ship_id: bool = false
	var payload_ship_id: String = ""
	var loaded_units: int = 0
	var cargo_units: int = 0
	var completed_units: int = 0
	var lost_units: int = 0
	var jettisoned_units: int = 0
	var exposure_remaining_s: float = 0.0
	var damage_debt_hp: float = 0.0
	var rewarded_units_total: int = 0
	var paid_credit_total: int = 0

class TacticalSiteStateDto extends RefCounted:
	var site_id: String = ""
	var generation: int = 0
	var respawn_remaining_s: float = 0.0
	var cleared_cycles: int = 0
class NpcTacticStateDto extends RefCounted:
	var npc_instance_id: String = ""
	var tactic_id: String = ""
	var phase: String = "ready"
	var remaining_s: float = 0.0
	var cooldown_remaining_s: float = 0.0
	var energy: float = 0.0
	var has_target_entity_id: bool = false
	var target_entity_id: String = ""
	var aim_x: float = 0.0
	var aim_y: float = 0.0
	var aim_z: float = 0.0
	var charge_start_hp: float = 0.0
	var drone_stock: int = 0
	var deployed_drones: int = 0
	var lost_drones: int = 0
class ShipTacticalEffectStateDto extends RefCounted:
	var ship_instance_id: String = ""
	var has_source_npc_id: bool = false
	var source_npc_id: String = ""
	var jam_remaining_s: float = 0.0
	var immunity_remaining_s: float = 0.0
	var repeat_window_s: float = 0.0
	var repeat_count: int = 0
class DroneBayStateDto extends RefCounted:
	var item_instance_id: String = ""
	var stock_units: int = 0
	var deployed_units: int = 0
	var lost_units: int = 0
	var replenished_units: int = 0
	var paid_credit_total: int = 0
	var material_units_total: int = 0
	var revision: int = 0
	var command_kind: String = "attack"
class DroneRuntimeDto extends RefCounted:
	var drone_id: String = ""
	var owner_id: String = ""
	var module_instance_id: String = ""
	var module_def_id: String = ""
	var health: float = 0.0
	var health_max: float = 0.0
	var command_kind: String = "attack"
	var communication_lost: bool = false
	var target_id: String = ""
	var returning: bool = false
	var fired: bool = false
	var pos_x: float = 0.0
	var pos_y: float = 0.0
	var pos_z: float = 0.0
class DroneCommandRequestDto extends RefCounted:
	var action: String = ""
	var target_id: String = ""
	var order_kind: String = ""
	var quantity: int = 1
	var quote_revision: String = ""

class WorldSnapshotDto extends RefCounted:
	var meta: SnapshotMetaDto = SnapshotMetaDto.new()
	var content: ContentRefDto = ContentRefDto.new()
	var player_state_rows: Array[PlayerStateDto] = []
	var ship_state_rows: Array[ShipStateDto] = []
	var container_state_rows: Array[ContainerStateDto] = []
	var item_instance_state_rows: Array[ItemInstanceStateDto] = []
	var equipment_state_rows: Array[EquipmentStateDto] = []
	var inventory_stack_state_rows: Array[InventoryStackStateDto] = []
	var mission_state_rows: Array[MissionStateDto] = []
	var mission_availability_state_rows: Array[MissionAvailabilityStateDto] = []
	var mission_collect_event_state_rows: Array[MissionCollectEventStateDto] = []
	var mission_claim_state_rows: Array[MissionClaimStateDto] = []
	var loan_state_rows: Array[LoanStateDto] = []
	var loan_asset_state_rows: Array[LoanAssetStateDto] = []
	var loan_issue_state_rows: Array[LoanIssueStateDto] = []
	var manufacture_input_state_rows: Array[ManufactureInputStateDto] = []
	var discovery_state_rows: Array[DiscoveryStateDto] = []
	var mission_objective_state_rows: Array[MissionObjectiveStateDto] = []
	var mission_window_state_rows: Array[MissionWindowStateDto] = []
	var unlock_state_rows: Array[UnlockStateDto] = []
	var reputation_state_rows: Array[ReputationStateDto] = []
	var shop_stock_state_rows: Array[ShopStockStateDto] = []
	var shop_ship_stock_state_rows: Array[ShopShipStockStateDto] = []
	var station_economy_state_rows: Array[StationEconomyStateDto] = []
	var sector_state_rows: Array[SectorStateDto] = []
	var npc_state_rows: Array[NpcStateDto] = []
	var production_state_rows: Array[ProductionStateDto] = []
	var resource_state_rows: Array[ResourceStateDto] = []
	var gate_state_rows: Array[GateStateDto] = []
	var ship_gate_cooldown_state_rows: Array[ShipGateCooldownStateDto] = []
	var rng_state_rows: Array[RngStateDto] = []
	var action_receipt_state_rows: Array[ActionReceiptStateDto] = []
	var transfer_state_rows: Array[TransferStateDto] = []
	var base_module_state_rows: Array[BaseModuleStateDto] = []
	var encounter_state_rows: Array[EncounterStateDto] = []
	var salvage_package_state_rows: Array[SalvagePackageStateDto] = []
	var spatial_state_rows: Array[SpatialStateDto] = []
	var civilization_state_rows: Array[CivilizationStateDto] = []
	var territory_state_rows: Array[TerritoryStateDto] = []
	var war_campaign_state_rows: Array[WarCampaignStateDto] = []
	var war_fleet_state_rows: Array[WarFleetStateDto] = []
	var industry_job_state_rows: Array[IndustryJobStateDto] = []
	var industry_input_state_rows: Array[IndustryInputStateDto] = []
	var station_demand_state_rows: Array[StationDemandStateDto] = []
	var exploration_instance_state_rows: Array[ExplorationInstanceStateDto] = []
	var exploration_actor_state_rows: Array[ExplorationActorStateDto] = []
	var exploration_claim_state_rows: Array[ExplorationClaimStateDto] = []
	var exploration_progress_state_rows: Array[ExplorationProgressStateDto] = []
	var exploration_research_state_rows: Array[ExplorationResearchStateDto] = []
	var exploration_belt_state_rows: Array[ExplorationBeltStateDto] = []
	var specialization_progress_state_rows: Array[SpecializationProgressStateDto] = []
	var specialization_evidence_state_rows: Array[SpecializationEvidenceStateDto] = []
	var specialization_research_state_rows: Array[SpecializationResearchStateDto] = []
	var operation_state_rows: Array[OperationStateDto] = []
	var tactical_site_state_rows: Array[TacticalSiteStateDto] = []
	var npc_tactic_state_rows: Array[NpcTacticStateDto] = []
	var ship_tactical_effect_state_rows: Array[ShipTacticalEffectStateDto] = []
	var drone_bay_state_rows: Array[DroneBayStateDto] = []

## 表现派生值不是另一份定义：每次由 frozen catalog + 当前状态计算。
class ShipMetricsViewDto extends RefCounted:
	var shield_max: float = 0.0
	var armor_max: float = 0.0
	var hull_max: float = 0.0
	var energy_max: float = 0.0
	var heat_max: float = 0.0
	var speed_mps: float = 0.0
	var total_mass_kg: float = 0.0
	var cargo_used_l: int = 0
	var cargo_capacity_l: int = 0
	var mineral_used_l: int = 0
	var mineral_capacity_l: int = 0
	var power_used: float = 0.0
	var power_capacity: float = 0.0
	var cpu_used: float = 0.0
	var cpu_capacity: float = 0.0

class TargetViewDto extends RefCounted:
	var entity_id: String = ""
	var entity_kind: String = ""
	var display_name: String = ""
	var distance_m: float = 0.0
	var hostile: bool = false
	var identified: bool = false
	var screen_visible: bool = false
	var screen_u: float = 0.0
	var screen_v: float = 0.0

class MainInteractionViewDto extends RefCounted:
	var target_entity_id: String = ""
	var action_kind: Types.ActionKind = Types.ActionKind.START_SCAN
	var allowed: bool = false
	var reject_code: Types.RejectCode = Types.RejectCode.NONE
	var display_reason_key: String = ""
	var running: bool = false
	var cycle_remaining_s: float = 0.0
	var completed_cycles: int = 0
	var required_cycles: int = 0

class WorldViewDto extends RefCounted:
	var session: SessionRefDto = SessionRefDto.new()
	var simulation_tick: int = 0
	var world_revision: int = 0
	var player: PlayerStateDto = PlayerStateDto.new()
	var controlled_ship: ShipStateDto = ShipStateDto.new()
	var metrics: ShipMetricsViewDto = ShipMetricsViewDto.new()
	var has_selected_target: bool = false
	var selected_target_id: String = ""
	var targets: Array[TargetViewDto] = []
	var main_interaction: MainInteractionViewDto = MainInteractionViewDto.new()
	var containers: Array[ContainerStateDto] = []
	var items: Array[ItemInstanceStateDto] = []
	var stacks: Array[InventoryStackStateDto] = []
	var equipment: Array[EquipmentStateDto] = []
	var missions: Array[MissionStateDto] = []
	var objectives: Array[MissionObjectiveStateDto] = []
	var shop_items: Array[ShopStockStateDto] = []
	var shop_ships: Array[ShopShipStockStateDto] = []
	var save_eligibility: SaveEligibilityDto = SaveEligibilityDto.new()
	var versions: Array[EntityVersionDto] = []
