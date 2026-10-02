class_name XJStateCodec
extends RefCounted
const Dtos = preload("res://contracts/contract_dtos.gd")
const State = preload("res://runtime/state.gd")
const ENUMS: Dictionary = {
	"player_state:camera_mode": ["follow", "front", "tactical"],
	"ship_state:status": ["flying", "docked", "destroyed", "returned"],
	"container_state:kind": ["station", "cargo", "mineral", "slot", "wreck"],
	"container_state:slot_type": ["weapon", "work", "utility", "structure"],
	"item_instance_state:origin_kind": ["guarantee", "loan", "purchase", "manufacture", "loot"],
	"inventory_stack_state:origin_kind": ["normal", "guarantee", "loan", "mission_bound"],
	"loan_state:status": ["available", "active", "handoff_pending", "lost", "returned"],
	"npc_state:behavior_phase": ["idle", "patrol", "acquire", "pursue", "attack", "disengage", "return", "dead"],
	"discovery_state:kind": ["signal", "gate", "resource"],
	"transfer_state:endpoint": ["origin", "destination"]}
var last_error: String = ""

func encode_row(table: String, row: RefCounted) -> Dictionary:
	var values: Dictionary = {}
	var properties: Dictionary = _properties(row)
	for column in properties:
		if column.begins_with("has_"):
			continue
		if properties.has("has_" + column) and not row.get("has_" + column):
			values[column] = null
			continue
		var value: Variant = row.get(column)
		var key: String = table + ":" + column
		if ENUMS.has(key):
			if value < 0 or value >= ENUMS[key].size():
				last_error = "Invalid enum " + key
				return {}
			value = ENUMS[key][value]
		elif properties[column] == TYPE_BOOL:
			value = 1 if value else 0
		elif properties[column] == TYPE_FLOAT and not is_finite(value):
			last_error = "Non-finite state " + key
			return {}
		values[column] = value
	return values

func decode_row(table: String, values: Dictionary) -> RefCounted:
	var row: RefCounted = State.new_row(table)
	if row == null:
		last_error = "Unregistered DTO " + table
		return null
	var properties: Dictionary = _properties(row)
	for column in values:
		if column in ["snapshot_id", "world_id", "content_snapshot_id"]:
			continue
		if not properties.has(column):
			last_error = "Unmapped SQL column " + table + ":" + column
			return null
		var value: Variant = values[column]
		if properties.has("has_" + column):
			row.set("has_" + column, value != null)
		if value == null:
			if not properties.has("has_" + column):
				last_error = "Unexpected NULL " + table + ":" + column
				return null
			continue
		var key: String = table + ":" + column
		if ENUMS.has(key):
			value = ENUMS[key].find(value)
			if value < 0:
				last_error = "Unknown stable enum " + key
				return null
		elif properties[column] == TYPE_BOOL:
			value = bool(value)
		row.set(column, value)
	return row

func clone(source: State) -> State:
	var result: State = State.new()
	result.world_id = source.world_id
	result.session_id = source.session_id
	result.epoch = source.epoch
	result.capture_sequence = source.capture_sequence
	for property in _properties(source.snapshot.meta):
		result.snapshot.meta.set(property, source.snapshot.meta.get(property))
	for property in _properties(source.snapshot.content):
		result.snapshot.content.set(property, source.snapshot.content.get(property))
	for table in State.TABLES:
		for row in source.rows(table):
			var copy: RefCounted = decode_row(table, encode_row(table, row))
			if copy == null or not result.add(table, copy):
				return null
	return result

static func _properties(row: Object) -> Dictionary:
	var result: Dictionary = {}
	for property in row.get_property_list():
		if property.name != "script" and (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			result[property.name] = property.type
	return result
