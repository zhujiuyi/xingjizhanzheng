class_name XJSpaceCoordinates
extends RefCounted
## Macro coordinates stay in GDScript float64 scalars. Vector3 is local metres
## or a normalized direction only; the existing DTO xyz remain the sole pose.

static func supported(catalog: XJCatalog) -> bool:
	return catalog != null and catalog.table_names.has("site_defs") and catalog.table_names.has("anchor_site_defs")

static func site_for_anchor(catalog: XJCatalog, anchor_id: String) -> String:
	if not supported(catalog): return ""
	return str(catalog.one("anchor_site_defs", "anchor_id", anchor_id).get("site_id", ""))

static func site_for_entity(state: XJRuntimeState, kind: String, id: String) -> String:
	if state == null or not state.TABLES.has("spatial_state"): return ""
	for context: RefCounted in state.rows("spatial_state"):
		if str(context.get("entity_kind")) == kind and str(context.get("entity_id")) == id:
			return str(context.get("site_id"))
	return ""

static func current_site(state: XJRuntimeState) -> String:
	return site_for_entity(state, "ship", state.ship().ship_instance_id) if state != null and state.ship() != null else ""

static func assign(state: XJRuntimeState, kind: String, id: String, site_id: String) -> bool:
	if state == null or not state.TABLES.has("spatial_state") or kind not in ["ship", "npc", "wreck"] or id.is_empty() or site_id.is_empty(): return false
	for context: RefCounted in state.rows("spatial_state"):
		if str(context.get("entity_kind")) == kind and str(context.get("entity_id")) == id:
			context.set("site_id", site_id)
			return true
	var context: RefCounted = XJRuntimeState.new_row("spatial_state")
	if context == null: return false
	context.set("entity_kind", kind)
	context.set("entity_id", id)
	context.set("site_id", site_id)
	return state.add("spatial_state", context)

static func remove(state: XJRuntimeState, kind: String, id: String) -> void:
	if state == null or not state.TABLES.has("spatial_state"): return
	for context: RefCounted in state.rows("spatial_state").duplicate():
		if str(context.get("entity_kind")) == kind and str(context.get("entity_id")) == id:
			state.remove("spatial_state", context)

static func same_site(state: XJRuntimeState, catalog: XJCatalog, kind: String, id: String, anchor_id: String) -> bool:
	if not supported(catalog): return true
	var a: String = site_for_entity(state, kind, id)
	return not a.is_empty() and a == site_for_anchor(catalog, anchor_id)

static func row_kind(row: RefCounted) -> String:
	if row == null: return ""
	if row is XJContractDtos.ShipStateDto: return "ship"
	if row is XJContractDtos.NpcStateDto: return "npc"
	if row is XJContractDtos.ContainerStateDto: return "wreck"
	return ""

static func row_id(row: RefCounted) -> String:
	match row_kind(row):
		"ship": return str(row.get("ship_instance_id"))
		"npc": return str(row.get("npc_instance_id"))
		"wreck": return str(row.get("container_id"))
	return ""

static func encoded(row: RefCounted) -> Vector3:
	return Vector3(float(row.get("pos_x")), float(row.get("pos_y")), float(row.get("pos_z")))

static func global_components(catalog: XJCatalog, site_id: String, local: Vector3) -> Dictionary:
	if not local.is_finite(): return {}
	if not supported(catalog): return {"x": float(local.x), "y": float(local.y), "z": float(local.z)}
	var site: Dictionary = catalog.one("site_defs", "site_id", site_id)
	if site.is_empty(): return {}
	return {"sector_id": str(site.sector_id), "x": float(site.x_m) + float(local.x) - float(site.pivot_x_m),
		"y": float(site.y_m) + float(local.y) - float(site.pivot_y_m),
		"z": float(site.z_m) + float(local.z) - float(site.pivot_z_m)}

static func entity_components(state: XJRuntimeState, catalog: XJCatalog, kind: String, row: RefCounted) -> Dictionary:
	if row == null: return {}
	return global_components(catalog, site_for_entity(state, kind, row_id(row)), encoded(row))

static func anchor_components(catalog: XJCatalog, anchor: Dictionary) -> Dictionary:
	if anchor.is_empty(): return {}
	return global_components(catalog, site_for_anchor(catalog, str(anchor.get("anchor_id", ""))), Vector3(float(anchor.x_m), float(anchor.y_m), float(anchor.z_m)))

static func delta_components(from: Dictionary, to: Dictionary) -> Dictionary:
	if from.is_empty() or to.is_empty(): return {}
	if from.has("sector_id") and to.has("sector_id") and str(from.sector_id) != str(to.sector_id): return {}
	# Scalar subtraction happens before any Vector3 construction.
	return {"x": float(to.x) - float(from.x), "y": float(to.y) - float(from.y), "z": float(to.z) - float(from.z)}

static func scalar_distance(from: Dictionary, to: Dictionary) -> float:
	var delta: Dictionary = delta_components(from, to)
	if delta.is_empty(): return INF
	return sqrt(float(delta.x) * float(delta.x) + float(delta.y) * float(delta.y) + float(delta.z) * float(delta.z))

static func scalar_direction(from: Dictionary, to: Dictionary) -> Vector3:
	var delta: Dictionary = delta_components(from, to)
	if delta.is_empty(): return Vector3.ZERO
	var magnitude: float = sqrt(float(delta.x) * float(delta.x) + float(delta.y) * float(delta.y) + float(delta.z) * float(delta.z))
	if not is_finite(magnitude) or magnitude <= 0.000001: return Vector3.ZERO
	return Vector3(float(delta.x) / magnitude, float(delta.y) / magnitude, float(delta.z) / magnitude).normalized()

static func anchor_distance(state: XJRuntimeState, catalog: XJCatalog, row: RefCounted, anchor: Dictionary) -> float:
	if row == null or anchor.is_empty(): return INF
	if str(row.get("sector_id")) != str(anchor.get("sector_id", "")): return INF
	var kind: String = row_kind(row)
	if not supported(catalog) or same_site(state, catalog, kind, row_id(row), str(anchor.anchor_id)):
		# Keep local physics exact: never add/subtract AU when both are local.
		return encoded(row).distance_to(Vector3(float(anchor.x_m), float(anchor.y_m), float(anchor.z_m)))
	return scalar_distance(entity_components(state, catalog, kind, row), anchor_components(catalog, anchor))

static func anchor_direction(state: XJRuntimeState, catalog: XJCatalog, row: RefCounted, anchor: Dictionary) -> Vector3:
	if row == null or anchor.is_empty(): return Vector3.ZERO
	if str(row.get("sector_id")) != str(anchor.get("sector_id", "")): return Vector3.ZERO
	var kind: String = row_kind(row)
	if not supported(catalog) or same_site(state, catalog, kind, row_id(row), str(anchor.anchor_id)):
		return encoded(row).direction_to(Vector3(float(anchor.x_m), float(anchor.y_m), float(anchor.z_m)))
	return scalar_direction(entity_components(state, catalog, kind, row), anchor_components(catalog, anchor))

static func entity_distance(state: XJRuntimeState, catalog: XJCatalog, kind_a: String, row_a: RefCounted, kind_b: String, row_b: RefCounted) -> float:
	if row_a == null or row_b == null: return INF
	if str(row_a.get("sector_id")) != str(row_b.get("sector_id")): return INF
	if not supported(catalog): return encoded(row_a).distance_to(encoded(row_b))
	var a: String = site_for_entity(state, kind_a, row_id(row_a))
	var b: String = site_for_entity(state, kind_b, row_id(row_b))
	if not a.is_empty() and a == b: return encoded(row_a).distance_to(encoded(row_b))
	return scalar_distance(entity_components(state, catalog, kind_a, row_a), entity_components(state, catalog, kind_b, row_b))

static func infer_legacy_site(catalog: XJCatalog, sector_id: String, local: Vector3) -> String:
	# Migration-only deterministic assignment. Ordinary creation must know its
	# station/spawn/source site and must never repair missing contexts this way.
	if not supported(catalog) or not local.is_finite(): return ""
	var best: float = INF
	var selected: String = ""
	for site: Dictionary in catalog.rows("site_defs"):
		if str(site.sector_id) != sector_id: continue
		var distance: float = local.distance_squared_to(Vector3(float(site.pivot_x_m), float(site.pivot_y_m), float(site.pivot_z_m)))
		if distance < best or (is_equal_approx(distance, best) and (selected.is_empty() or str(site.site_id) < selected)):
			best = distance
			selected = str(site.site_id)
	return selected
