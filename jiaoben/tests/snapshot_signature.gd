extends RefCounted
## Pure diagnostics: compare durable rows to decoded rows before presentation
## callbacks legitimately accrue new menu visits/time. No state is modified.
const Codec=preload("res://runtime/data/codec.gd")
static func canonical(values: Dictionary) -> String:
	for table: String in values:
		values[table].sort_custom(func(a: Dictionary,b: Dictionary):return JSON.stringify(a)<JSON.stringify(b))
	return JSON.stringify(values)
static func runtime(state: XJRuntimeState) -> String:
	var values: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		values[table]=[]
		for row: RefCounted in state.rows(table):values[table].append(Codec.new().encode_row(table,row))
	return canonical(values)
static func saved(store: RefCounted,snapshot_id: String) -> String:
	var values: Dictionary={}
	for table: String in XJRuntimeState.TABLES:
		values[table]=[]
		for row: Dictionary in store._records('SELECT * FROM "%s" WHERE snapshot_id=?' % table,[snapshot_id]):
			values[table].append(Codec.new().encode_row(table,Codec.new().decode_row(table,row)))
	return canonical(values)
