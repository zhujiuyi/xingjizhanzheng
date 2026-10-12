extends RefCounted
const D=preload("res://contracts/contract_dtos.gd")
static func rows(catalog: XJCatalog,state: XJRuntimeState) -> Dictionary:
	var result: Dictionary={}
	if not catalog.table_names.has("trial_defs"):return result
	result["trial_state"]=[];result["blockade_state"]=[];result["blockade_node_state"]=[]
	for def: Dictionary in catalog.rows("trial_defs"):
		var row: RefCounted=D.TrialStateDto.new();row.trial_id=def.trial_id;row.phase="available";result.trial_state.append(row)
	for def: Dictionary in catalog.rows("blockade_defs"):
		var row: RefCounted=D.BlockadeStateDto.new();row.blockade_id=def.blockade_id;row.phase="available";result.blockade_state.append(row)
	for def: Dictionary in catalog.rows("blockade_node_defs"):
		var row: RefCounted=D.BlockadeNodeStateDto.new();row.blockade_id=def.blockade_id;row.node_index=int(def.node_index);result.blockade_node_state.append(row)
	var timing: RefCounted=D.TelemetryTimingStateDto.new();timing.singleton=1;result["telemetry_timing_state"]=[timing]
	result["activity_record_state"]=[]
	for mission: RefCounted in state.rows("mission_state"):
		if mission.status not in ["active","ready"]:continue
		var row: RefCounted=D.ActivityRecordStateDto.new()
		row.record_id="baseline:"+mission.mission_instance_id;row.activity_kind="mission";row.object_id=mission.mission_instance_id;row.phase="active";row.partial_baseline=true
		row.started_tick=state.snapshot.meta.simulation_tick;result.activity_record_state.append(row)
	for kind: String in ["exploration","operation"]:
		for source: RefCounted in state.rows("exploration_instance_state" if kind=="exploration" else "operation_state"):
			if source.phase not in (["surveyed","rescue","relic","mineral","extracting"] if kind=="exploration" else ["accepted","active","ready"]) and not (kind=="exploration" and source.phase=="clue" and not source.operation_kind.is_empty()):continue
			var row: RefCounted=D.ActivityRecordStateDto.new();row.activity_kind=kind
			row.object_id=str(source.get("event_id" if kind=="exploration" else "operation_id"))+":"+str(source.generation)
			row.record_id="baseline:"+kind+":"+row.object_id;row.phase="active";row.partial_baseline=true;row.started_tick=state.snapshot.meta.simulation_tick
			result.activity_record_state.append(row)
	return result
