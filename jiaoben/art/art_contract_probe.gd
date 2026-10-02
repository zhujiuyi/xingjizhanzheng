extends SceneTree
const FACTORY: Script = preload("res://runtime/visuals/visual_factory.gd")
const EFFECTS: Script = preload("res://runtime/visuals/visual_effects.gd")
var checks: int = 0

func _initialize() -> void:
	_probe.call_deferred()

func _check(value: bool, label: String) -> void:
	if not value:
		push_error("ART_CONTRACT_FAIL " + label)
		quit(1)
		return
	checks += 1

func _probe() -> void:
	var db: Object = ClassDB.instantiate("SQLite")
	db.path = "res://data/catalog.db"
	db.read_only = true
	db.verbosity_level = 0
	_check(db.open_db(), "catalog open")
	for ship_id: String in FACTORY.SHIPS:
		var body: CharacterBody3D = FACTORY.scene(ship_id)
		_check(body != null and body.get_node("VisualRoot").get_child_count() > 0, ship_id + " model")
		db.query_with_bindings("SELECT slot_type,slot_index FROM ship_slot_defs WHERE ship_id=?", [ship_id])
		var definitions: Array = db.query_result.duplicate(true)
		_check(body.get_node("Hardpoints").get_child_count() == definitions.size(), ship_id + " slot count")
		for slot: Dictionary in definitions:
			var key: String = str(slot.slot_type) + "_" + str(slot.slot_index)
			_check(body.has_node("Hardpoints/" + key), ship_id + " " + key)
		if ship_id in ["shuttle_swift", "frigate_lantern", "frigate_kestrel", "miner_anvil"]:
			var old: CharacterBody3D = (load("res://assets/placeholders/" + ship_id + ".tscn") as PackedScene).instantiate()
			var old_shape: BoxShape3D = old.get_node("CollisionShape3D").shape
			var new_shape: BoxShape3D = body.get_node("CollisionShape3D").shape
			_check(old_shape.size.is_equal_approx(new_shape.size), ship_id + " preserve collision")
			for marker: Node3D in old.get_node("Hardpoints").get_children():
				_check(marker.position.is_equal_approx(body.get_node("Hardpoints/" + marker.name).position), ship_id + " preserve mount")
			old.free()
		body.free()
	for kind: String in ["station", "gate", "ore", "wreck"]:
		var body: StaticBody3D = FACTORY.static_body(kind, "probe_" + kind, "ore_conductive_crystal")
		_check(body != null, kind + " wrapper")
		if kind == "gate":
			_check(body.get_child_count() == 14, "gate 12 compound colliders + visual/marker")
		body.free()
	for archetype: String in ["scout", "raider", "guardian", "silent"]:
		var body: CharacterBody3D = FACTORY.enemy_scene(archetype)
		_check(body != null, archetype + " enemy geometry")
		body.free()
	for name: String in ["engine_loop", "mining_loop", "station_ambience", "ui_confirm", "explosion"]:
		var audio: AudioStream = FACTORY.sound(name)
		_check(audio != null and audio.get_length() > 0.0, name + " audio")
		if name.ends_with("_loop"):
			_check((audio as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, name + " looping")
	var config: Dictionary = {}
	db.query("SELECT * FROM presentation_defs")
	for entry: Dictionary in db.query_result:
		config[entry.presentation_id] = entry.value_integer if entry.value_integer != null else entry.value_real
	db.close_db()
	var fx_root: Node3D = Node3D.new()
	root.add_child(fx_root)
	var beam: Node3D = EFFECTS.beam(Vector3.ZERO, Vector3(0,0,-100), Color.CYAN, config)
	var shield: Node3D = EFFECTS.shield(20.0, Color.CYAN, config)
	var explosion: Node3D = EFFECTS.explosion(Vector3.ZERO, 20.0, Color.ORANGE, config)
	var gate: Node3D = EFFECTS.wormhole(80.0, Color.CYAN, config)
	var trail: GPUParticles3D = EFFECTS.engine_trail(1.0, Color.CYAN, config)
	for node: Node3D in [beam, shield, explosion, gate, trail]:
		fx_root.add_child(node)
	_check(float(beam.get("duration_s")) == float(config["fx_beam_lifetime_s"]), "beam uses DB lifetime")
	_check(trail.amount == int(config["engine_particles_near"]), "trail uses DB particle count")
	await create_timer(float(config["fx_explosion_lifetime_s"]) + 0.15).timeout
	_check(not is_instance_valid(beam) and not is_instance_valid(shield) and not is_instance_valid(explosion), "finite FX retire")
	_check(is_instance_valid(gate) and is_instance_valid(trail), "persistent FX stay under world owner")
	fx_root.free()
	print("ART_CONTRACT_PASS checks=", checks)
	quit(0)
