class_name XJUIInteraction
extends RefCounted
## Shared presentation contracts; gameplay services still own every qualification.

static func parent_page(id: String, source: String = "map") -> String:
	return str({"fitting_analysis": "fitting", "trials": "fitting", "ship_roles": "ships", "hire": "ships", "operations": "missions", "expeditions": "missions", "blockades": "missions", "consignments": "missions", "projects": "industry", "reports": "pause", "frontier": "civilizations", "exploration": "map", "drones": "fitting", "sources": source if source != "sources" else "map"}.get(id, ""))

static func integer_input(spin: SpinBox) -> int:
	if not is_instance_valid(spin): return 0
	var raw: String = spin.get_line_edit().text.strip_edges()
	if not raw.is_valid_int(): return 0
	var value: int = int(raw)
	return value if value >= maxi(1, ceili(spin.min_value)) and value <= floori(spin.max_value) else 0

static func watch_integer(spin: SpinBox, update: Callable) -> void:
	var witness: WeakRef=weakref(spin)
	var refresh: Callable=func():
		var current_spin: SpinBox=witness.get_ref() as SpinBox
		if is_instance_valid(current_spin) and current_spin.is_visible_in_tree() and not current_spin.is_queued_for_deletion() and update.is_valid():update.call()
	spin.value_changed.connect(func(_value: float): refresh.call())
	spin.get_line_edit().text_changed.connect(func(_text: String): refresh.call())
	spin.get_line_edit().focus_exited.connect(func(): refresh.call_deferred())

static func action_state(button: Button, reason: String, help: String = "") -> void:
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason + ("\n" if not reason.is_empty() and not help.is_empty() else "") + help

static func context(ui: Node) -> Dictionary:
	var result: Dictionary = {"state": ui.state, "catalog": ui.catalog, "page": ui.page, "generation": ui.business_generation}
	if ui.state != null:
		result.merge({"world": ui.state.world_id, "session": ui.state.session_id, "epoch": ui.state.epoch, "ship": ui.state.ship().ship_instance_id, "station": ui.state.player().docked_station_id})
	return result

static func current(ui: Variant, token: Dictionary, witness: Variant = null) -> bool:
	if not is_instance_valid(ui) or not ui is Node:return false
	var owner: Node=ui as Node
	if owner.loading_suspended: return false
	if not owner.is_inside_tree() or owner.state != token.state or owner.catalog != token.catalog or owner.page != token.page or owner.business_generation != token.generation: return false
	if typeof(witness)!=TYPE_NIL:
		if not is_instance_valid(witness) or not witness is Control:return false
		var control: Control=witness as Control
		if control.is_queued_for_deletion() or not control.is_visible_in_tree():return false
		var surface: Control=owner.station_layer if owner.page=="station" else owner.panel
		if not is_instance_valid(surface) or (surface!=control and not surface.is_ancestor_of(control)):return false
	if owner.state == null: return true
	return owner.state.world_id == token.world and owner.state.session_id == token.session and owner.state.epoch == token.epoch and owner.state.ship().ship_instance_id == token.ship and owner.state.player().docked_station_id == token.station
