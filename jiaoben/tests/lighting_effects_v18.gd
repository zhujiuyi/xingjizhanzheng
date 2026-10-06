extends Node
## Independent SQLite and real flight scene. Poses/NPCs are explicit fixtures;
## no personal save, natural progression or frame-rate claim is involved.
const Main = preload("res://runtime/main.gd")
const Store = preload("res://runtime/data/store.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Sector = preload("res://runtime/sector.gd")
const Effects = preload("res://runtime/visuals/visual_effects.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Space = preload("res://runtime/space_coordinates.gd")
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var output_dir: String
var host: Main
var viewport: Viewport
var star_min_separation_rad: float = 0.0
var star_max_separation_rad: float = 0.0
var image_evidence: Array[Dictionary] = []
var hull_luminance: Dictionary = {}
@onready var root: Window = get_tree().root
@onready var process_frame: Signal = get_tree().process_frame
@onready var physics_frame: Signal = get_tree().physics_frame

func _ready() -> void:
	# The same fixed Node is loaded by the source launcher and opt-in release
	# diagnostic. Main resources continue to resolve from the actual PCK.
	get_tree().set_meta("xj_lighting_v18_diagnostic", true)
	output_dir = OS.get_environment("XJ_LIGHTING_V18_DIRECTORY")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://../jiaoben/tmp/lighting-effects-v18/%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output_dir)
	create_timer(120.0).timeout.connect(func(): print("LIGHTING_EFFECTS_V18 FAIL watchdog"); quit(1))
	call_deferred("_run")

func create_timer(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(seconds)

func quit(code: int) -> void:
	get_tree().quit(code)

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value: failures.append(label); print("FAIL ", label)
	return value

func _run() -> void:
	root.size = Vector2i(1440, 900)
	viewport = root
	if DisplayServer.get_name() == "headless":
		var sub := SubViewport.new()
		sub.size = root.size
		sub.own_world_3d = true
		root.add_child(sub)
		viewport = sub
	await _lighting_catalog_checks()
	host = Main.new()
	host.progress_database_path = output_dir.path_join("progress.db")
	viewport.add_child(host)
	await process_frame
	if not check(host.services_ready, "real Main prepares independent SQLite"):
		await _finish(); return
	await host._command("new_world", "恒星光照与接触特效检查", 1, "")
	if not check(host.state != null, "production new-world endpoint succeeds"):
		await _finish(); return
	host._command("undock", "", 1, "")
	while host.busy: await process_frame
	check(host.state.ship().status == T.ShipStatus.FLYING, "production undock reaches flight before images")
	host.set_process(false)
	host.set_physics_process(false)
	host._sync_presentation_stage()
	var ship: XJFlight = host.world.flight
	# Stage the hull in the later NPC fixture's declared spawn site. Changing
	# local xyz alone must never invent or infer a strategic site.
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	if Space.supported(host.store.catalog):
		check(Space.assign(host.state, "ship", ship.record.ship_instance_id, Space.site_for_anchor(host.store.catalog, str(spawn.anchor_id))), "flight image fixture adopts explicit spawn site")
	ship.position = Vector3(3500, 3000, 2000)
	ship.velocity = Vector3.ZERO
	ship.basis = Basis.IDENTITY
	host.world.refresh_site()
	check(host.world.sync_entities(), "flight image fixture refreshes declared scene context")
	host.ui.show_page("")
	await _settle_pose()
	check(not host.ui.top.text.is_empty() and host.ui.instrument_title.text.contains("雨燕") and host.ui.condition_bars[0].bar.max_value > 0.0 and host.ui.condition_bars[0].label.text.contains("/"), "flight HUD shows actual ship name and populated authoritative defense telemetry")
	await _capture("flight-starlight-port")
	var toward_star: Vector3 = _star_direction(host.world, ship.global_position)
	host.camera.camera.global_position = ship.global_position - toward_star * 90.0 + Vector3.UP * 15.0
	host.camera.camera.look_at(ship.global_position)
	host.world.update_starlight()
	check(not host.camera.camera.is_position_behind(host.world.stellar_disc.global_position), "configured illuminating star has a real visible scene disc")
	await _capture("stellar-source-reference", host.world.stellar_disc)
	var first_local: Vector3 = ship.global_basis.inverse() * _star_direction(host.world, ship.global_position)
	ship.basis = Basis(Vector3.UP, PI)
	await _settle_pose()
	var second_local: Vector3 = ship.global_basis.inverse() * _star_direction(host.world, ship.global_position)
	check(first_local.distance_to(second_local) > 1.0, "actual hull rotation changes local incoming-light direction")
	await _capture("flight-starlight-starboard")
	if DisplayServer.get_name() != "headless":
		check(hull_luminance.has("flight-starlight-port") and hull_luminance.has("flight-starlight-starboard") and absf(float(hull_luminance.get("flight-starlight-port", 0.0)) - float(hull_luminance.get("flight-starlight-starboard", 0.0))) > 0.008, "opposing hull attitudes produce a measured change in actual hull-pixel lighting")
	ship.basis = Basis.IDENTITY
	await _settle_pose()
	await _weapon_geometry_checks()
	await _feedback_checks()
	await _finish()

func _lighting_catalog_checks() -> void:
	var store: Store = Store.new(output_dir.path_join("lighting.db"))
	if not check(store.open(), "isolated catalog/SQLite opens"):
		return
	check(store.catalog.table_names.has("system_lighting_defs"), "current catalog supplies system lighting table")
	var state: XJRuntimeState = store.new_world("十星系照明检查", 71)
	if not check(state != null, "isolated typed runtime exists"):
		store.close(); return
	state.ship().status = T.ShipStatus.FLYING
	state.ship().has_station_id = false
	state.player().has_docked_station_id = false
	var directions: Array[Vector3] = []
	for definition: Dictionary in store.catalog.rows("sector_defs"):
		state.ship().sector_id = str(definition.sector_id)
		var station_definition: Dictionary = store.catalog.one("station_defs", "sector_id", str(definition.sector_id))
		var station_anchor: Dictionary = store.catalog.one("anchor_defs", "anchor_id", str(station_definition.station_anchor_id))
		if Space.supported(store.catalog):
			check(Space.assign(state, "ship", state.ship().ship_instance_id, Space.site_for_anchor(store.catalog, str(station_anchor.anchor_id))), "system fixture adopts its declared station site " + str(definition.sector_id))
		state.ship().pos_x = float(station_anchor.x_m)
		state.ship().pos_y = float(station_anchor.y_m)
		state.ship().pos_z = float(station_anchor.z_m)
		var gameplay: Gameplay = Gameplay.new()
		gameplay.setup(state, store.catalog)
		var world: Sector = Sector.new()
		viewport.add_child(world)
		if check(world.build(state, store.catalog, gameplay), "actual lighting world builds " + state.current_sector()):
			var station_pose := Vector3(float(station_anchor.x_m), float(station_anchor.y_m), float(station_anchor.z_m))
			world.flight.position = station_pose
			world.flight.write_back()
			world.flight.get_global_transform_interpolated()
			world.flight.reset_physics_interpolation()
			world.update_starlight()
			var row: Dictionary = store.catalog.one("system_lighting_defs", "system_id", str(definition.system_id))
			check(not row.is_empty() and not world.lighting_definition.is_empty(), "system has one authoritative stellar definition")
			if not row.is_empty():
				var direction: Vector3 = _star_direction(world, station_pose)
				directions.append(direction)
				check(world.key_light.global_basis.z.normalized().dot(direction) > 0.99999, "directional rays originate from configured star")
				check((world.stellar_disc.global_position - world.flight.global_position).normalized().dot(direction) > 0.99999, "visible stellar disc agrees with illuminating direction")
				check(is_equal_approx(world.key_light.light_energy, float(row.energy)) and is_equal_approx(world.visual_environment.ambient_light_energy, float(row.ambient_energy)), "direct and ambient energies use catalog")
				check(world.key_light.shadow_enabled and is_equal_approx(world.key_light.directional_shadow_max_distance, float(row.shadow_distance_m)), "real directional shadow uses catalog coverage")
				var before: Vector3 = world.key_light.global_basis.z
				var lateral: Vector3 = before.cross(Vector3.UP)
				if lateral.length_squared() < 0.000001: lateral = before.cross(Vector3.RIGHT)
				world.flight.position = station_pose + lateral.normalized() * 5000.0
				world.flight.write_back()
				world.flight.reset_physics_interpolation()
				world.update_starlight()
				if Space.supported(store.catalog):
					check(before.normalized().dot(world.key_light.global_basis.z.normalized()) > 0.99999, "local five-kilometre motion keeps AU-distant stellar illumination stable")
				else:
					check(before.angle_to(world.key_light.global_basis.z) > 0.015, "legacy compressed translation changes stellar direction")
				var translated_pose: Vector3 = world.flight.get_global_transform_interpolated().origin
				var translated_ray: Vector3 = _star_direction(world, translated_pose)
				check(world.key_light.global_basis.z.normalized().dot(translated_ray) > 0.99999, "transverse translation uses the actual new star-to-ship ray")
				check((world.stellar_disc.global_position - translated_pose).normalized().dot(translated_ray) > 0.99999, "stellar disc follows the same transversely changed light direction")
				check(is_equal_approx(world.key_light.light_energy, float(row.energy)), "translation keeps scenic star energy stable")
				world.flight.position = station_pose + before.normalized() * 5000.0
				world.flight.write_back()
				world.flight.reset_physics_interpolation()
				world.update_starlight()
				check(world.key_light.global_basis.z.normalized().dot(before.normalized()) > 0.99999, "radial movement preserves incoming-light direction before crossing the star")
				check((world.stellar_disc.global_position - world.flight.get_global_transform_interpolated().origin).normalized().dot(before.normalized()) > 0.99999, "stellar disc also preserves its bearing during radial movement")
				if Space.supported(store.catalog): _strategic_light_change(world, direction, station_pose)
				world.apply_visual_quality("low")
				check(not world.key_light.shadow_enabled, "low quality disables shadow without changing light direction")
				world.apply_visual_quality("high")
				check(world.key_light.shadow_enabled and world.visual_environment.ssao_enabled, "high quality restores shadow and SSAO")
				var station: Node3D = null
				for entry: Dictionary in world.targets.values():
					if entry.kind == "station": station = entry.node; break
				check(station != null and not _lit_materials(station).is_empty(), "actual station retains shaded PBR surfaces")
		viewport.remove_child(world)
		world.queue_free()
		gameplay.dispose()
		await process_frame
	# Frozen SQLite rows can have a different order from the source catalog.
	# Measure all pairs instead of choosing whichever two happen to come first.
	var pair_count: int = 0
	star_min_separation_rad = PI
	for first: int in directions.size():
		for second: int in range(first + 1, directions.size()):
			var separation: float = directions[first].angle_to(directions[second])
			star_min_separation_rad = minf(star_min_separation_rad, separation)
			star_max_separation_rad = maxf(star_max_separation_rad, separation)
			pair_count += 1
	check(directions.size() == 10 and pair_count == 45, "all ten configured systems contribute all forty-five star-bearing pairs")
	if Space.supported(store.catalog):
		# Physical observers may have nearby orbital bearings. Only require
		# distinct rays beyond numerical precision, not artificial separation.
		check(star_min_separation_rad > 0.00001, "all ten physical system observers have distinct scalar star bearings beyond numerical precision")
	else:
		check(star_min_separation_rad > 0.5, "legacy compressed systems retain star bearings separated by over half a radian")
	check(star_max_separation_rad > 2.6, "star bearings include substantially opposing illumination directions")
	for axis: int in 3:
		var positive: bool = directions.any(func(direction: Vector3): return direction[axis] > 0.0)
		var negative: bool = directions.any(func(direction: Vector3): return direction[axis] < 0.0)
		check(positive and negative, "stellar lighting covers both sides of world axis %d" % axis)
	print("STELLAR_BEARINGS pairs=%d min_rad=%.6f max_rad=%.6f" % [pair_count, star_min_separation_rad, star_max_separation_rad])
	store.close()

func _star_components(catalog: XJCatalog, sector_id: String) -> Dictionary:
	for row: Dictionary in catalog.rows("celestial_defs"):
		if str(row.sector_id) == sector_id and str(row.celestial_kind) == "star":
			return {"x": float(row.x_m), "y": float(row.y_m), "z": float(row.z_m)}
	return {}

func _star_direction(world: Sector, local_position: Vector3) -> Vector3:
	if not Space.supported(world.catalog): return (world.stellar_position - local_position).normalized()
	return Space.scalar_direction(world.strategic_components(local_position), _star_components(world.catalog, world.state.current_sector()))

func _strategic_light_change(world: Sector, original_ray: Vector3, station_pose: Vector3) -> void:
	# Choose an explicit frozen site for directional stress, never nearest-site
	# inference. This scoped fixture is not a gameplay transition or save.
	var original_site: String = Space.current_site(world.state)
	var candidate: Dictionary = {}
	var maximum: float = -1.0
	var star: Dictionary = _star_components(world.catalog, world.state.current_sector())
	for site: Dictionary in world.catalog.rows("site_defs"):
		if str(site.sector_id) != world.state.current_sector() or str(site.site_id) == original_site: continue
		var local := Vector3(float(site.pivot_x_m), float(site.pivot_y_m), float(site.pivot_z_m))
		var ray: Vector3 = Space.scalar_direction(Space.global_components(world.catalog, str(site.site_id), local), star)
		var separation: float = original_ray.angle_to(ray)
		if separation > maximum or is_equal_approx(separation, maximum) and (candidate.is_empty() or str(site.site_id) < str(candidate.site_id)):
			candidate = site
			maximum = separation
	if not check(not candidate.is_empty() and maximum > 0.015, "system has a frozen strategic site with a measurably different star bearing"): return
	check(Space.assign(world.state, "ship", world.state.ship().ship_instance_id, str(candidate.site_id)), "strategic light fixture adopts the selected explicit site")
	world.flight.position = Vector3(float(candidate.pivot_x_m), float(candidate.pivot_y_m), float(candidate.pivot_z_m))
	world.flight.write_back()
	world.flight.get_global_transform_interpolated()
	world.flight.reset_physics_interpolation()
	world.refresh_site()
	check(world.sync_entities(), "strategic light fixture refreshes site-bound scene entities")
	world.update_starlight()
	var expected: Vector3 = _star_direction(world, world.flight.global_position)
	check(world.key_light.global_basis.z.normalized().dot(expected) > 0.99999 and original_ray.angle_to(expected) > 0.015, "AU strategic relocation changes lighting to the exact scalar star-to-player direction")
	check((world.stellar_disc.global_position - world.flight.global_position).normalized().dot(expected) > 0.99999, "strategic star disc agrees with the changed illuminating direction")
	check(Space.assign(world.state, "ship", world.state.ship().ship_instance_id, original_site), "strategic light fixture restores its declared station site")
	world.flight.position = station_pose
	world.flight.write_back()
	world.flight.get_global_transform_interpolated()
	world.flight.reset_physics_interpolation()
	world.refresh_site()
	check(world.sync_entities(), "restored light fixture refreshes original scene entities")
	world.update_starlight()

func _lit_materials(node: Node) -> Array[Material]:
	var materials: Array[Material] = []
	if node is MeshInstance3D and node.mesh != null:
		for index: int in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(index)
			if material is ShaderMaterial and not material.shader.code.contains("unshaded"): materials.append(material)
	for child: Node in node.get_children(): materials.append_array(_lit_materials(child))
	return materials

func _weapon_geometry_checks() -> void:
	var config: Dictionary = host.presentation.config
	var names: Array[String] = []
	for family: String in ["thermal", "kinetic", "pulse", "drone"]:
		var visual: Node3D = Effects.weapon_visual(family, config)
		names.append(str(visual.name))
		check(str(visual.get_meta("weapon_family")) == family, "explicit visual family " + family)
		check(visual.get_child_count() >= 2, "family has bounded distinct geometry " + family)
		check(visual.get("duration_s") == 0.0, "combat owns projectile visual lifetime " + family)
		check(visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual creates no second damage collision " + family)
		if family == "thermal":
			var core: MeshInstance3D = visual.get_node("LaserCore")
			check(core.mesh is CylinderMesh and is_equal_approx(core.position.z, -0.5) and is_equal_approx(core.mesh.height, 1.0), "laser is a thin unit-length beam along local -Z")
		elif family == "kinetic": check(visual.get_node_or_null("KineticSlug") != null and visual.get_node_or_null("KineticShortTrail") != null, "kinetic has short slug and separate short trail")
		elif family == "pulse": check(visual.get_node("PulseCore").mesh is SphereMesh and visual.get_node("PulseShell").mesh is SphereMesh, "pulse is a compact spherical packet")
		else: check(visual.get_node_or_null("DroneHull") != null and visual.get_node_or_null("DroneWingLeft") != null and visual.get_node_or_null("DroneGun") != null, "drone is a small hull with wings, gun and engines")
		visual.free()
	check(names[0] != names[1] and names[1] != names[2] and names[2] != names[3], "weapon families no longer share one light-column silhouette")
	check(not _lit_materials(host.world.flight).is_empty(), "real industrial hull keeps shaded PBR materials")
	# Images stage the same production geometry near the actual flight camera;
	# the separate physical-hit checks below verify the combat/event path.
	for family: String in ["thermal", "kinetic", "pulse", "drone"]:
		var visual: Node3D = Effects.weapon_visual(family, config)
		host.world.add_child(visual)
		visual.global_position = host.world.flight.global_position + Vector3(-8, 4, -12)
		visual.global_basis = Basis.looking_at(Vector3.RIGHT)
		if family == "thermal": visual.scale.z = 28.0
		await _capture("weapon-" + family, visual)
		visual.free()

func _feedback_checks() -> void:
	var presentation: XJPresentation = host.presentation
	var ship: XJFlight = host.world.flight
	var id: String = host.state.ship().ship_instance_id
	var half: Vector3 = (ship.get_node("CollisionShape3D").shape as BoxShape3D).size * 0.5
	var point: Vector3 = _visible_contact(ship)
	presentation.hit(id, true, point, Vector3(1, 0, 0))
	var pulse: Node3D = presentation.effects[-1]
	check(pulse.name == "ShieldContact" and pulse.get_meta("hit_kind") == "shield", "player shield receives a localized contact effect")
	check(pulse.get_node("LocalShieldArc").scale.is_equal_approx(half * 1.08), "shield ellipsoid follows actual collision half-extents")
	check(pulse.get_node("LocalShieldArc").material_override.shader.code.contains("hit_direction"), "shield shader restricts light to contact direction")
	ship.position += Vector3(8, 3, 0)
	ship.basis = Basis(Vector3.UP, 0.35)
	ship.reset_physics_interpolation()
	pulse.call("_process", 0.0)
	check(pulse.global_transform.is_equal_approx(ship.get_global_transform_interpolated()), "local shield contact follows owner render pose while moving")
	presentation.process_mode = Node.PROCESS_MODE_DISABLED
	await _settle_pose()
	pulse.call("_process", 0.07)
	var elapsed: float = pulse.get("elapsed_s")
	presentation.process_mode = Node.PROCESS_MODE_DISABLED
	presentation.set_paused(true)
	await _capture("player-shield-contact", pulse)
	await create_timer(0.05).timeout
	check(is_instance_valid(pulse) and is_equal_approx(float(pulse.get("elapsed_s")), elapsed), "pause freezes effect lifetime and follow animation")
	presentation.process_mode = Node.PROCESS_MODE_INHERIT
	presentation.set_paused(false)
	pulse.call("_process", float(presentation.config.fx_shield_lifetime_s) + 0.01)
	await process_frame
	check(not is_instance_valid(pulse), "shield contact expires at bounded catalog lifetime")
	presentation._prune_nodes(presentation.effects)
	presentation.hit(id, false, _visible_contact(ship), Vector3(0, 1, 0))
	var surface: Node3D = presentation.effects[-1]
	check(surface.name == "SurfaceContact" and surface.get_node("ContactSparks").amount == int(presentation.config.fx_impact_particle_count), "player armor contact produces catalog-count sparks")
	check(surface.find_children("*", "Light3D", true, false).is_empty(), "contact effect uses no per-hit light or shadow")
	presentation.set_paused(true)
	check(is_zero_approx(surface.get_node("ContactSparks").speed_scale), "pause also freezes GPU contact-particle clock")
	presentation.set_paused(false)
	check(is_equal_approx(surface.get_node("ContactSparks").speed_scale, 1.0), "resume restores GPU particle clock")
	await _capture("player-armor-contact", surface)
	var npc := D.NpcStateDto.new()
	npc.npc_instance_id = "lighting-v18-enemy"
	npc.spawn_id = "spawn_anchor_tutorial_scout"
	npc.sector_id = host.state.current_sector()
	npc.alive = true
	npc.shield = 50; npc.armor = 80; npc.hull = 100
	var enemy_position: Vector3 = ship.global_position - ship.global_basis.z * 80.0
	npc.pos_x = enemy_position.x; npc.pos_y = enemy_position.y; npc.pos_z = enemy_position.z
	host.state.add("npc_state", npc)
	if Space.supported(host.store.catalog):
		var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", npc.spawn_id)
		check(Space.assign(host.state, "npc", npc.npc_instance_id, Space.site_for_anchor(host.store.catalog, str(spawn.anchor_id))), "enemy image fixture keeps frozen spawn context")
	check(host.world.sync_entities(), "enemy fixture enters actual projection from unmodified NPC prototype")
	var enemy: CharacterBody3D = host.world.npcs[npc.npc_instance_id]
	enemy.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	presentation.hit(npc.npc_instance_id, true, _visible_contact(enemy), Vector3(0, 0, 1))
	var enemy_pulse: Node3D = presentation.effects[-1]
	enemy_pulse.call("_process", 0.07)
	check(enemy_pulse.get_meta("shield_entity", "") == npc.npc_instance_id, "enemy shield uses same localized feedback route")
	await _capture("enemy-shield-contact", enemy_pulse)
	presentation.hit(npc.npc_instance_id, false, _visible_contact(enemy), Vector3(1, 0, 0))
	check(presentation.effects[-1].get_meta("hit_entity", "") == npc.npc_instance_id, "enemy armor has physical-contact visual")
	await _capture("enemy-armor-contact", presentation.effects[-1])
	await _physical_hit_checks(enemy, npc)
	# Destroy a freshly created owner-following contact before its timer can end.
	for effect: Node3D in presentation.effects:
		if is_instance_valid(effect): effect.queue_free()
	await process_frame
	presentation._prune_nodes(presentation.effects)
	presentation.hit(npc.npc_instance_id, true, enemy_position + Vector3(0, 0, 15))
	var doomed: Node3D = presentation.effects[-1]
	check(is_instance_valid(doomed) and not doomed.is_queued_for_deletion(), "new following contact exists before owner destruction")
	npc.alive = false
	host.world.sync_entities()
	doomed.call("_process", 0.0)
	await process_frame
	check(not is_instance_valid(doomed), "owner destruction clears its following shield effect before lifetime end")
	# A hard max bounds bursts; no discarded visual can settle damage.
	presentation._prune_nodes(presentation.effects)
	for index: int in int(presentation.config.fx_active_instances_max) + 3:
		presentation.impact(ship.global_position + Vector3(index, 0, -10), Color("b2bfd1"))
	check(presentation.effects.size() <= int(presentation.config.fx_active_instances_max), "contact burst respects global effect-instance limit")
	var particles: int = 0
	for effect: Node3D in presentation.effects: particles += presentation._particles(effect)
	check(particles <= int(presentation.config.fx_particle_budget_max), "contact burst respects global particle budget")
	presentation.intensity = 0.0
	var before: int = presentation.effects.size()
	presentation.impact(ship.global_position, Color.WHITE)
	check(presentation.effects.size() == before, "zero effect setting rejects new geometry without gameplay change")
	presentation.intensity = 1.0
	for effect: Node3D in presentation.effects:
		if is_instance_valid(effect): effect.queue_free()
	await process_frame
	presentation._prune_nodes(presentation.effects)
	check(presentation.effects.is_empty(), "completed visuals leave no stale effect references")

func _physical_hit_checks(enemy: CharacterBody3D, npc: D.NpcStateDto) -> void:
	var ship: XJFlight = host.world.flight
	ship.write_back()
	host.world.projectiles.set_paused(false)
	await physics_frame
	await physics_frame
	var npc_before: float = npc.shield
	host.world.projectiles.fire(ship.record.ship_instance_id, ship.get_rid(), ship.global_position, ship.global_position.direction_to(enemy.global_position), 500.0, 200.0, Vector3(2, 0, 0), {"family_id": "kinetic"})
	host.world.projectiles.simulate(0.3)
	host._flush_damage()
	check(npc.shield < npc_before, "real swept projectile settles enemy shield damage through Main")
	check(host.presentation.effects.any(func(effect: Variant): return is_instance_valid(effect) and effect.get_meta("shield_entity", "") == npc.npc_instance_id), "real enemy hit creates localized shield feedback")
	await _capture("physical-enemy-hit", host.presentation.effects[-1])
	var player_before: float = ship.record.shield
	# Observe the real incoming side of the player hull for this contact image.
	host.camera.observation_basis = ship.global_basis * Basis(Vector3.UP, PI)
	host.camera.snapped = false
	host.camera.step(0.0)
	host.world.projectiles.fire(npc.npc_instance_id, enemy.get_rid(), enemy.global_position, enemy.global_position.direction_to(ship.global_position), 500.0, 200.0, Vector3(2, 0, 0), {"family_id": "kinetic"})
	host.world.projectiles.simulate(0.3)
	host._flush_damage()
	check(ship.record.shield < player_before, "real enemy projectile settles player shield damage through Main")
	check(host.presentation.effects.any(func(effect: Variant): return is_instance_valid(effect) and effect.get_meta("shield_entity", "") == ship.record.ship_instance_id), "real player hit creates same localized shield feedback")
	await _capture("physical-player-hit", host.presentation.effects[-1])
	# Explicit zero-shield fixture tests the actual armor-event branch.
	npc.shield = 0.0
	var armor_before: float = npc.armor
	host.world.projectiles.fire(ship.record.ship_instance_id, ship.get_rid(), ship.global_position, ship.global_position.direction_to(enemy.global_position), 500.0, 200.0, Vector3(2, 0, 0), {"family_id": "kinetic"})
	host.world.projectiles.simulate(0.3)
	host._flush_damage()
	check(npc.armor < armor_before, "zero-shield enemy receives real armor damage")
	check(host.presentation.effects.any(func(effect: Variant): return is_instance_valid(effect) and effect.get_meta("hit_entity", "") == npc.npc_instance_id and effect.get_meta("hit_kind", "") == "armor"), "real armor hit emits sparks and contact flash")
	# Production obstacles carry entity_id too; they need environment feedback
	# while remaining outside the ship/NPC damage consumer.
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 1
	obstacle.set_meta("entity_id", "lighting-v18-static-fixture")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 12, 12)
	collision.shape = shape
	obstacle.add_child(collision)
	host.world.add_child(obstacle)
	obstacle.global_position = ship.global_position + Vector3.RIGHT * 40.0
	await physics_frame
	await physics_frame
	var ship_hp: Vector3 = Vector3(ship.record.shield, ship.record.armor, ship.record.hull)
	host.world.projectiles.fire(ship.record.ship_instance_id, ship.get_rid(), ship.global_position, Vector3.RIGHT, 500.0, 100.0, Vector3(2, 0, 0), {"family_id": "kinetic"})
	host.world.projectiles.simulate(0.2)
	host._flush_damage()
	check(host.presentation.effects[-1].get_meta("hit_kind", "") == "environment", "swept collision with named static obstacle creates environment contact")
	check(ship_hp == Vector3(ship.record.shield, ship.record.armor, ship.record.hull), "environment feedback cannot produce a second ship damage settlement")
	obstacle.queue_free()
	host.world.projectiles.clear()

func _settle_pose() -> void:
	var ship: XJFlight = host.world.flight
	ship.write_back()
	ship.get_global_transform_interpolated()
	ship.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	await process_frame
	host._sync_presentation_stage()
	host.camera.bind(ship, host.store.catalog, T.CameraMode.FOLLOW)
	host.camera.zoom = 0.8
	host.camera.step(0.0)
	host.world.update_starlight()
	host.ui.tick(0.26)
	check(host.world.is_visible_in_tree() and ship.visual.is_visible_in_tree() and viewport.get_camera_3d() == host.camera.camera, "settled flight pose uses the visible hull and actual current flight camera")

func _visible_contact(body: Node3D) -> Vector3:
	var pose: Transform3D = body.get_global_transform_interpolated()
	var collision: CollisionShape3D = body.get_node("CollisionShape3D")
	var half: Vector3 = (collision.shape as BoxShape3D).size * 0.5
	var local_view: Vector3 = (pose.basis.inverse() * (host.camera.camera.global_position - pose.origin)).normalized()
	var distance: float = INF
	for axis: int in 3:
		if absf(local_view[axis]) > 0.000001: distance = minf(distance, half[axis] / absf(local_view[axis]))
	return pose * (local_view * distance * 1.015)

func _capture(name: String, feedback: Node3D = null) -> void:
	if DisplayServer.get_name() == "headless": return
	# Pose, telemetry and camera are refreshed after the actual render frame
	# starts. The source-reference shot deliberately keeps its staged camera.
	var old_mode: int = host.presentation.process_mode
	host.presentation.process_mode = Node.PROCESS_MODE_DISABLED
	host._sync_presentation_stage()
	if name != "stellar-source-reference": host.camera.step(0.0)
	host.ui.tick(0.26)
	host.world.update_starlight()
	var particles: Array[Node] = []
	if feedback != null:
		particles.assign(feedback.find_children("*", "GPUParticles3D", true, false))
	var particle_speeds: Array[float] = []
	for particle: GPUParticles3D in particles:
		particle_speeds.append(particle.speed_scale)
		particle.speed_scale = 1.0
		particle.restart()
	if not particles.is_empty():
		# Compile and genuinely render this emitter before freezing. Restart
		# after that warm frame so compile latency cannot consume its lifetime.
		await _render_image()
		for particle: GPUParticles3D in particles: particle.restart()
		await create_timer(0.045).timeout
		await _render_image()
		for particle: GPUParticles3D in particles: particle.speed_scale = 0.0
		check(particles.all(func(particle: Node): return is_zero_approx((particle as GPUParticles3D).speed_scale)), "native contact particles rendered and emitted before snapshot freeze " + name)
	if feedback != null and feedback.name == "ShieldContact": feedback.call("_process", 0.0 if host.presentation.effects_paused else 0.04)
	var image: Image = await _render_image()
	if not check(image != null and not image.is_empty(), "native viewport has a drawable flight frame " + name):
		host.presentation.process_mode = old_mode as Node.ProcessMode
		return
	var ship: XJFlight = host.world.flight
	var region: Rect2i = _projection_rectangle(ship, image.get_size())
	check(ship.visual.is_visible_in_tree() and viewport.get_camera_3d() == host.camera.camera and region.get_area() > 500 and Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), "native hull is visible and framed by the real flight camera " + name)
	ship.visual.hide()
	var without_hull: Image = await _render_image()
	ship.visual.show()
	var hull: Dictionary = _pixel_difference(image, without_hull, region)
	check(int(hull.changed) > 80, "native frame contains actual rendered hull pixels " + name)
	hull_luminance[name] = hull.luminance
	var measured := {"frame": name, "hull_region": [region.position.x, region.position.y, region.size.x, region.size.y], "hull_pixels": int(hull.changed), "hull_luminance": float(hull.luminance), "effect_pixels": 0}
	if feedback != null:
		var effect_region: Rect2i = _projection_rectangle(feedback, image.get_size())
		feedback.hide()
		var without_effect: Image = await _render_image()
		feedback.show()
		var effect: Dictionary = _pixel_difference(image, without_effect, effect_region)
		measured.effect_pixels = int(effect.brightened)
		check(int(effect.brightened) >= 4, "native weapon/contact/star visual contributes visible bright pixels " + name)
	image_evidence.append(measured)
	if check(image.save_png(output_dir.path_join(name + ".png")) == OK, "native real-flight screenshot " + name): captures += 1
	for index: int in particles.size(): (particles[index] as GPUParticles3D).speed_scale = particle_speeds[index]
	host.presentation.process_mode = old_mode as Node.ProcessMode

func _render_image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _projection_rectangle(node: Node3D, image_size: Vector2i) -> Rect2i:
	var corners: Array[Vector3] = []
	_collect_corners(node, corners)
	var minimum: Vector2 = Vector2(image_size)
	var maximum: Vector2 = Vector2.ZERO
	var projected: int = 0
	for point: Vector3 in corners:
		if host.camera.camera.is_position_behind(point): continue
		var screen: Vector2 = host.camera.camera.unproject_position(point)
		minimum = minimum.min(screen)
		maximum = maximum.max(screen)
		projected += 1
	if projected == 0: return Rect2i()
	var start: Vector2i = Vector2i(floori(minimum.x) - 5, floori(minimum.y) - 5).clamp(Vector2i.ZERO, image_size)
	var end: Vector2i = Vector2i(ceili(maximum.x) + 5, ceili(maximum.y) + 5).clamp(Vector2i.ZERO, image_size)
	return Rect2i(start, end - start)

func _collect_corners(node: Node, points: Array[Vector3]) -> void:
	var bounds: AABB
	var has_bounds: bool = false
	if node is MeshInstance3D and node.mesh != null:
		bounds = node.mesh.get_aabb()
		has_bounds = true
	elif node is GPUParticles3D:
		bounds = node.visibility_aabb
		has_bounds = true
	if has_bounds:
		var pose: Transform3D = (node as Node3D).global_transform
		for index: int in 8:
			var corner: Vector3 = bounds.position + Vector3(bounds.size.x if (index & 1) != 0 else 0.0, bounds.size.y if (index & 2) != 0 else 0.0, bounds.size.z if (index & 4) != 0 else 0.0)
			points.append(pose * corner)
	for child: Node in node.get_children(): _collect_corners(child, points)

func _pixel_difference(image: Image, baseline: Image, region: Rect2i) -> Dictionary:
	var changed: int = 0
	var brightened: int = 0
	var luminance: float = 0.0
	if image == null or baseline == null or image.is_empty() or baseline.is_empty(): return {"changed": 0, "brightened": 0, "luminance": 0.0}
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var color: Color = image.get_pixel(x, y)
			var prior: Color = baseline.get_pixel(x, y)
			var difference: Vector3 = Vector3(color.r - prior.r, color.g - prior.g, color.b - prior.b)
			if maxf(absf(difference.x), maxf(absf(difference.y), absf(difference.z))) > 0.035:
				changed += 1
				luminance += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			if maxf(difference.x, maxf(difference.y, difference.z)) > 0.035: brightened += 1
	return {"changed": changed, "brightened": brightened, "luminance": luminance / maxf(float(changed), 1.0)}

func _finish() -> void:
	check(DisplayServer.get_name() == "headless" or captures == 13, "native evidence contains all thirteen actual flight frames")
	if is_instance_valid(host): host.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	var report := {"backend": DisplayServer.get_name(), "checks": checks, "failures": failures, "captures": captures, "star_min_separation_rad": star_min_separation_rad, "star_max_separation_rad": star_max_separation_rad, "image_evidence": DisplayServer.get_name() != "headless", "image_measurements": image_evidence, "packed_runtime": not OS.has_feature("editor"), "fixture": "fresh SQLite; ten catalog systems; staged production flight geometry and explicit NPC; real swept combat/obstacle collisions; native hull/effect visibility differences; no natural campaign or FPS claim", "output_dir": output_dir}
	var file := FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t") + "\n"); file.close()
	print("LIGHTING_EFFECTS_V18 %s checks=%d failures=%d captures=%d output=%s" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures, output_dir])
	quit(0 if failures.is_empty() else 1)
