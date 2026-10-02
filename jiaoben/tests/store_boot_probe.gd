extends SceneTree
const State = preload("res://runtime/state.gd")
const Catalog = preload("res://runtime/data/catalog.gd")
const Codec = preload("res://runtime/data/codec.gd")
const Rng = preload("res://runtime/rng.gd")
func _initialize() -> void:
	var memory: Object = ClassDB.instantiate("SQLite")
	memory.path = ":memory:"
	memory.verbosity_level = 0
	print("MEMORY ", memory.open_db(), " path=", memory.path)
	var catalog: Catalog = Catalog.new()
	print("CATALOG ", catalog.open(), " ", catalog.last_error, " ships=", catalog.rows("ship_defs").size())
	print("HASH ", catalog.verify_reviewed(), " ", catalog.logical_hash(), " ", catalog.last_error)
	var state: State = State.new()
	var player: RefCounted = State.new_row("player_state")
	player.player_id = "test"
	print("ADD ", state.add("player_state", player), " ", state.last_error)
	var codec: Codec = Codec.new()
	print("ENCODE ", codec.encode_row("player_state", player))
	var rng: Rng = Rng.new()
	rng.initialize(42)
	var output: Array = []
	for index in range(6): output.append("%08x" % rng.next_uint32())
	print("RNG ", output)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/placeholders/manifest.json"))
	var expected: String = manifest.manifest_sha256
	manifest.erase("manifest_sha256")
	manifest.format_version = int(manifest.format_version)
	print("ASSET ", expected == JSON.stringify(manifest, "", true, true).sha256_text())
	memory.close_db()
	catalog.close()
	quit(0)
