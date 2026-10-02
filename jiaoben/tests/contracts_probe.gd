extends SceneTree
## 仅验证类型与占位结构，不实现世界或游戏玩法。
const Dtos = preload("res://contracts/contract_dtos.gd")
const Types = preload("res://contracts/contract_types.gd")

func _initialize() -> void:
	var snapshot: Dtos.WorldSnapshotDto = Dtos.WorldSnapshotDto.new()
	var ship: Dtos.ShipStateDto = Dtos.ShipStateDto.new()
	ship.ship_instance_id = "test_ship"
	snapshot.ship_state_rows.append(ship)
	var equipment: Dtos.EquipmentStateDto = Dtos.EquipmentStateDto.new()
	equipment.active_remaining_s = 0.5
	equipment.cycle_paid = true
	snapshot.equipment_state_rows.append(equipment)
	var load_request: Dtos.LoadRequestDto = Dtos.LoadRequestDto.new()
	load_request.target_snapshot_id = "test_snapshot"
	assert(snapshot.ship_state_rows[0].ship_instance_id == "test_ship")
	assert(snapshot.equipment_state_rows[0].cycle_paid)
	assert(load_request.target_snapshot_id == "test_snapshot")
	assert(Types.RejectCode.STALE_SELECTION != Types.RejectCode.STALE_VERSION)
	var other_snapshot: Dtos.WorldSnapshotDto = Dtos.WorldSnapshotDto.new()
	assert(other_snapshot.ship_state_rows.is_empty(), "DTO arrays must not be shared")
	for ship_id: String in ["shuttle_swift", "frigate_lantern", "frigate_kestrel", "miner_anvil"]:
		var packed: PackedScene = load("res://assets/placeholders/" + ship_id + ".tscn") as PackedScene
		assert(packed != null)
		var root: CharacterBody3D = packed.instantiate() as CharacterBody3D
		assert(root != null)
		assert(root.get_meta("ship_def_id") == ship_id)
		assert(root.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING)
		assert(root.collision_layer == 2 and root.collision_mask == 3)
		assert(root.get_node_or_null("CollisionShape3D") is CollisionShape3D)
		assert(root.get_node_or_null("CameraTarget") is Marker3D)
		assert(root.get_node_or_null("FrontCamera") is Marker3D)
		assert(root.get_node_or_null("InteractionAnchor") is Marker3D)
		for marker: Node in root.get_node("Hardpoints").get_children():
			assert(marker is Marker3D)
			assert(marker.has_meta("slot_type") and marker.has_meta("slot_index"))
			if marker.get_meta("slot_type") == "weapon":
				assert(marker.get_node_or_null("muzzle") is Marker3D)
		root.free()
	print("CONTRACTS_PROBE_PASS: typed DTOs and four static ship scenes; not gameplay")
	quit(0)
