extends SceneTree
## Scene/renderer evidence, independent of HUD and personal databases.
const Store = preload("res://runtime/data/store.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Sector = preload("res://runtime/sector.gd")
const Navigation = preload("res://runtime/navigation_catalog.gd")
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
var checks: int = 0
var failures: Array[String] = []
var worlds: int = 0
var targets: int = 0
var meshes: int = 0

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): print("SCENE_RENDERING_V7 FAIL timeout"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); print("FAIL ", label)

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child: Node in node.get_children(): result.append_array(descendants(child))
	return result

func _audit(world: Sector) -> void:
	var planets: Array[Node] = []
	var environments: int = 0
	var player_models: int = 0
	for node: Node in descendants(world):
		if node is WorldEnvironment: environments += 1
		if node is XJFlight: player_models += 1
		if node.name.begins_with("Celestial_"): planets.append(node)
		if node is MeshInstance3D:
			var instance: MeshInstance3D = node
			meshes += 1
			check(instance.material_overlay == null, "no overlay copy " + str(instance.get_path()))
			if instance.mesh != null:
				for surface: int in range(instance.mesh.get_surface_count()):
					var material: Material = instance.get_active_material(surface)
					check(material == null or material.next_pass == null, "one material pass " + str(instance.get_path()))
	check(environments == 1, "single world environment " + world.state.current_sector())
	check(player_models == 1, "single live player model " + world.state.current_sector())
	check(planets.size() == 1, "one actual celestial mesh " + world.state.current_sector())
	for node: Node in planets:
		var planet: MeshInstance3D = node
		check(planet.mesh is SphereMesh and not planet.mesh.flip_faces, "celestial is a single outward sphere")
		var material: ShaderMaterial = planet.material_override
		var source: String = material.shader.code
		check(source.contains("cull_back") and not source.contains("ALPHA") and not source.contains("hint_screen_texture"), "celestial opaque front surface has no screen/history pass")
		check(not source.contains("TIME") and not source.contains("VERTEX ="), "planet surface has no animated displacement")
		check(planet.get_global_transform_interpolated().is_equal_approx(planet.global_transform), "static celestial spawn history equals actual pose")
	var positions: Array[Vector3] = []
	for entry: Dictionary in world.targets.values():
		targets += 1
		var node: Node3D = entry.node
		check(node.is_inside_tree(), "target still in the real scene " + str(entry.id))
		check(not positions.any(func(point: Vector3): return point.is_equal_approx(node.global_position)), "target positions unique " + str(entry.id))
		positions.append(node.global_position)
	check(not world.visual_environment.volumetric_fog_enabled and not world.visual_environment.ssil_enabled and not world.visual_environment.ssr_enabled, "no active temporal fog/SSIL/reflection chain")

func _npc_lifecycle(world: Sector) -> void:
	var spawn: Dictionary = world.catalog.one("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	var definition: Dictionary = world.catalog.one("npc_full_defs", "npc_id", str(spawn.npc_id))
	var npc: D.NpcStateDto = D.NpcStateDto.new()
	npc.npc_instance_id = "scene-rendering-v7-npc"
	npc.spawn_id = str(spawn.spawn_id)
	npc.sector_id = world.state.current_sector()
	npc.alive = true
	npc.shield = float(definition.shield_max); npc.armor = float(definition.armor_max); npc.hull = float(definition.hull_max)
	npc.behavior_phase = T.NpcPhase.PATROL
	var pose: Vector3 = world.anchor_position(str(spawn.anchor_id))
	npc.pos_x = pose.x; npc.pos_y = pose.y; npc.pos_z = pose.z
	world.state.add("npc_state", npc)
	check(world.sync_entities(), "real NPC projection creates its unmodified SQLite archetype")
	var body: CharacterBody3D = world.npcs[npc.npc_instance_id]
	check(body.get_global_transform_interpolated().is_equal_approx(body.global_transform), "NPC spawn resets rendered pose after placement")
	npc.alive = false
	check(world.sync_entities(), "dead NPC projection updates")
	check(not body.is_inside_tree() and not body.visible and not world.targets.has(npc.npc_instance_id), "retired NPC detaches immediately before deferred deletion")
	world.state.rows("npc_state").erase(npc)

func _run() -> void:
	print("RENDER_SETTINGS taa=%s scale_mode=%s scale=%.2f screen_aa=%s interpolation=%s" % [root.use_taa, root.scaling_3d_mode, root.scaling_3d_scale, root.screen_space_aa, is_physics_interpolation_enabled()])
	check(not root.use_taa and root.scaling_3d_mode != Viewport.SCALING_3D_MODE_FSR2, "runtime is not accumulating TAA/FSR2 frame history")
	# Enable in this fixture even when auditing an older project configuration.
	# This validates spawn history, not a claim about the default release setting.
	set_physics_interpolation_enabled(true)
	var store: Store = Store.new(ProjectSettings.globalize_path("res://../jiaoben/tmp/scene-rendering-v7-%d.db" % Time.get_ticks_usec()))
	check(store.open(), "independent SQLite store opens")
	var state: XJRuntimeState = store.new_world("场景渲染独立检查", 71)
	check(state != null, "fresh sealed runtime initialized")
	if state == null: store.close(); quit(1); return
	state.ship().status = T.ShipStatus.FLYING
	state.ship().has_station_id = false; state.ship().station_id = ""
	state.player().has_docked_station_id = false; state.player().docked_station_id = ""
	for sector: Dictionary in store.catalog.rows("sector_defs"):
		state.ship().sector_id = str(sector.sector_id)
		var business: Gameplay = Gameplay.new()
		business.setup(state, store.catalog)
		var world: Sector = Sector.new()
		root.add_child(world)
		check(world.build(state, store.catalog, business), "actual sector builds " + state.current_sector())
		worlds += 1
		_audit(world)
		var prior: XJFlight = world.flight
		check(world.rebuild_player(), "real hull replacement builds")
		check(not prior.is_inside_tree() and not prior.visible, "old hull never remains a second rendered/physics branch")
		var count: int = 0
		for child: Node in world.get_children():
			if child is XJFlight: count += 1
		check(count == 1, "exactly one player hull before the deferred queue flush")
		check(world.flight.get_global_transform_interpolated().is_equal_approx(world.flight.global_transform), "replacement interpolation begins at its final pose")
		if state.current_sector() == "sector_anchor": _npc_lifecycle(world)
		root.remove_child(world)
		world.queue_free()
		business.dispose()
		await process_frame
	store.close()
	await process_frame
	await create_timer(0.25).timeout
	print("SCENE_RENDERING_V7 %s checks=%d failures=%d worlds=%d targets=%d meshes=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), worlds, targets, meshes])
	quit(0 if failures.is_empty() else 1)
