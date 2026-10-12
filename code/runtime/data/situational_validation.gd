extends RefCounted
var last_error: String = ""

func validate(state: XJRuntimeState, catalog: XJCatalog) -> bool:
	var supported: bool = catalog.table_names.has("situational_balance_defs")
	for table: String in ["resource_intel_state","demand_intel_state"]:
		if not supported and not state.rows(table).is_empty(): return _fail("Observations under legacy rules")
		var seen: Dictionary = {}
		for row: RefCounted in state.rows(table):
			var key: String = row.node_id if table=="resource_intel_state" else row.demand_id
			if seen.has(key) or row.observed_tick<0 or row.observed_tick>state.snapshot.meta.simulation_tick: return _fail("Invalid observation identity or tick")
			seen[key]=true
			if table=="resource_intel_state":
				var spec: Dictionary = catalog.one("resource_node_defs","node_id",row.node_id)
				var site: Dictionary = catalog.one("site_defs","site_id",row.site_id)
				if spec.is_empty() or site.is_empty() or row.sector_id!=spec.sector_id or site.sector_id!=row.sector_id: return _fail("Observation resource/site mismatch")
				if row.remaining_units<0 or row.remaining_units>int(spec.capacity_units) or not is_finite(row.respawn_remaining_s) or row.respawn_remaining_s<0 or row.respawn_remaining_s>float(spec.respawn_s): return _fail("Invalid observed resource amount")
			else:
				var spec: Dictionary = catalog.one("station_demand_defs","demand_id",row.demand_id)
				if spec.is_empty() or row.phase not in ["active","cooldown"] or row.generation<1: return _fail("Invalid observed demand")
				if row.remaining_units<0 or row.remaining_units>int(spec.required_units) or row.unit_credit!=int(spec.unit_reward_credit): return _fail("Invalid observed quote")
				var maximum: float = float(spec.duration_s if row.phase=="active" else spec.cooldown_s)
				if not is_finite(row.phase_remaining_s) or row.phase_remaining_s<0 or row.phase_remaining_s>maximum: return _fail("Invalid observed demand duration")
	return true

func _fail(message: String) -> bool:
	last_error=message; return false
