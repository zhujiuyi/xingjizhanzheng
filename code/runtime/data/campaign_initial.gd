extends RefCounted
const D=preload("res://contracts/contract_dtos.gd")

static func rows(catalog: XJCatalog,state: XJRuntimeState,seed: int) -> Dictionary:
	var result: Dictionary={}
	if not catalog.table_names.has("campaign_balance_defs"):return result
	result["construction_state"]=[]
	for def: Dictionary in catalog.rows("construction_project_defs"):
		var row: RefCounted=D.ConstructionStateDto.new();row.project_id=def.project_id;row.stage_index=1;row.phase="gathering"
		result.construction_state.append(row)
	result["construction_input_state"]=[]
	for def: Dictionary in catalog.rows("construction_input_defs"):
		var row: RefCounted=D.ConstructionInputStateDto.new()
		row.project_id=def.project_id;row.stage_index=int(def.stage_index);row.item_id=def.item_id;row.delivery_station_id=def.delivery_station_id
		result.construction_input_state.append(row)
	result["expedition_route_state"]=[]
	for def: Dictionary in catalog.rows("expedition_route_defs"):
		var row: RefCounted=D.ExpeditionRouteStateDto.new();row.route_id=def.route_id;result.expedition_route_state.append(row)
	var director: RefCounted=D.CampaignDirectorStateDto.new()
	director.singleton=1;director.focus_index=(str(seed)+":campaign").sha256_text().substr(0,8).hex_to_int()%3
	director.generation=1;director.remaining_s=float(catalog.rows("campaign_balance_defs")[0].director_period_s)
	result["campaign_director_state"]=[director]
	var total: RefCounted=D.TelemetryTotalStateDto.new();total.singleton=1;total.next_sequence=1;total.wallet_last=state.player().credit
	result["telemetry_total_state"]=[total]
	return result
