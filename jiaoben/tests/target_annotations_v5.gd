extends SceneTree
## Real Main and fresh SQLite: one target annotation per render, no duplicate model.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
var host: Main
var nav: XJNavigationHUD
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0

func _initialize() -> void:
	create_timer(55.0).timeout.connect(func(): print("TARGET_ANNOTATIONS_V5 FAIL watchdog"); quit(1))
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)

func _frames(count: int = 2) -> void:
	for frame: int in range(count): await process_frame

func _meshes(node: Node) -> Array[int]:
	var ids: Array[int] = []
	if node is MeshInstance3D: ids.append(node.get_instance_id())
	for child: Node in node.get_children(): ids.append_array(_meshes(child))
	ids.sort()
	return ids

func _kind(kind: String) -> String:
	for id: String in host.world.targets:
		if host.world.targets[id].kind == kind: return id
	return ""

func _spawn_npc_fixture() -> bool:
	# Campaign/tutorial trigger is outside this visual test. Spawn its unmodified
	# SQLite archetype through the same production state-to-model projection.
	var spawn: Dictionary = host.store.catalog.one("npc_spawn_defs", "spawn_id", "spawn_anchor_tutorial_scout")
	var definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", str(spawn.npc_id))
	var npc := D.NpcStateDto.new()
	npc.npc_instance_id = "annotation-fixture-npc"
	npc.spawn_id = str(spawn.spawn_id)
	npc.sector_id = host.state.current_sector()
	npc.alive = true
	npc.shield = float(definition.shield_max)
	npc.armor = float(definition.armor_max)
	npc.hull = float(definition.hull_max)
	npc.behavior_phase = T.NpcPhase.PATROL
	var home: Vector3 = host.world.anchor_position(str(spawn.anchor_id))
	npc.pos_x = home.x; npc.pos_y = home.y; npc.pos_z = home.z
	host.state.add("npc_state", npc)
	return host.world.sync_entities()

func _caption_count(node: Node) -> int:
	var count: int = 1 if node is Label and node != nav.range_label and node != nav.selection_label else 0
	for child: Node in node.get_children(): count += _caption_count(child)
	return count

func _focus(id: String, mode: T.CameraMode = T.CameraMode.FOLLOW) -> void:
	var node: Node3D = host.world.targets[id].node
	host.world.flight.global_position = node.global_position + Vector3(80, 35, 650)
	host.world.flight.global_basis = Basis.IDENTITY
	host.world.flight.velocity = Vector3.ZERO
	host.world.flight.write_back()
	host.camera.bind(host.world.flight, host.store.catalog, mode)
	host.state.player().camera_mode = mode
	host.camera.step(1.0)
	host.ui.target_id = id
	host.ui.tick(1.0)
	nav.update_annotations()

func _caption_clear_of_hud() -> bool:
	if not nav.target_caption.is_visible_in_tree(): return true
	var bounds: Rect2 = nav.target_caption.get_global_rect()
	return Rect2(Vector2.ZERO, host.ui.root.size).encloses(bounds) and not nav.caption_obstacles.any(func(obstacle: Rect2): return bounds.grow(4).intersects(obstacle))

func capture(label: String) -> void:
	await _frames(3)
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../jiaoben/logs/target-annotations-v5-" + label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "native capture " + label)
	captures += 1

func _run() -> void:
	host = Main.new()
	host.progress_database_path = ProjectSettings.globalize_path("res://../jiaoben/tmp/target-annotations-v5-%d.db" % Time.get_ticks_usec())
	root.add_child(host)
	await process_frame
	check(host.services_ready, "actual Main validates resource identities")
	if not host.services_ready: await finish(); return
	await host._command("new_world", "目标单层标注验收", 1, "")
	check(host.state != null, "fresh isolated SQLite world")
	if host.state == null: await finish(); return
	await host._command("undock", "", 1, "")
	while host.busy: await process_frame
	# Freeze simulation only; production Main/UI/Nav render updates remain active.
	host.set_physics_process(false)
	host.ui.show_page("")
	host._sync_presentation_stage()
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = root.size
	await _frames(3)
	nav = host.ui.navigation_hud
	check(host.presentation_stage == "flight" and nav.is_visible_in_tree(), "real flight stage exposes target overlay")
	check(is_instance_valid(nav.target_caption) and _caption_count(nav) == 1, "exactly one persistent native target caption")
	check(nav.target_caption.get_theme_constant("outline_size") == 0 and nav.target_caption.get_theme_constant("shadow_outline_size") == 0 and nav.target_caption.get_theme_color("font_shadow_color").a == 0.0, "caption has neither thick outline nor offset shadow")
	check(_spawn_npc_fixture(), "configured tutorial NPC uses production state-to-model projection")
	var ids: Dictionary = {}
	for kind: String in ["station", "gate", "npc", "planet"]:
		ids[kind] = _kind(kind)
		check(not str(ids[kind]).is_empty(), "real sector contains " + kind)
		if str(ids[kind]).is_empty(): await finish(); return
	var original_meshes: Dictionary = {}
	var original_nodes: Dictionary = {}
	for kind: String in ids:
		var node: Node3D = host.world.targets[ids[kind]].node
		original_nodes[kind] = node.get_instance_id()
		original_meshes[kind] = _meshes(node)
	var target_count: int = host.world.targets.size()
	for kind: String in ["station", "gate", "npc", "planet"]:
		_focus(str(ids[kind]))
		await _frames(3)
		var title: String = str(host.world.targets[ids[kind]].title)
		check(nav.selected_id == ids[kind] and nav.target_caption.text.contains(title), "selected " + kind + " updates sole caption")
		check(not nav.marker_geometry().any(func(row: Dictionary): return row.id == ids[kind]), "selected " + kind + " excluded from unselected marker pass")
		var stable_text: String = nav.target_caption.text
		var stable_position: Vector2 = nav.target_caption.position
		await _frames(8)
		check(nav.target_caption.text == stable_text and nav.target_caption.position.is_equal_approx(stable_position), "stationary " + kind + " annotation has no second stale position")
		check(nav.target_caption.position.is_equal_approx(nav.target_caption.position.round()), "selected " + kind + " caption snaps to integer logical pixels")
		var node: Node3D = host.world.targets[ids[kind]].node
		check(node.get_instance_id() == original_nodes[kind] and _meshes(node) == original_meshes[kind] and host.world.targets.size() == target_count, "selection leaves " + kind + " model instances unchanged")
		if kind != "planet": await capture(kind)
	# Change only the UI selection between renders, below the business HUD interval.
	_focus(str(ids.station))
	await _frames(2)
	host.ui.hud_refresh = 0.0
	host.ui.target_id = str(ids.gate)
	await _frames(2)
	check(nav.selected_id == ids.gate and nav.target_caption.text.contains(str(host.world.targets[ids.gate].title)) and not nav.target_caption.text.contains(str(host.world.targets[ids.station].title)), "selection replacement reaches next render without stale name")
	check(_caption_count(nav) == 1, "switching selection keeps one caption instance")
	var moving: Node3D = host.world.targets[ids.npc].node
	for mode: T.CameraMode in [T.CameraMode.FOLLOW, T.CameraMode.FRONT, T.CameraMode.TACTICAL]:
		_focus(str(ids.npc), mode)
		moving.global_position = host.camera.camera.global_position - host.camera.camera.global_basis.z * 500 + host.camera.camera.global_basis.x * 70
		await _frames(2)
		var geometry: Dictionary = nav.target_geometry()
		check(not geometry.is_empty() and geometry.on_screen and geometry.end.distance_to(host.camera.camera.unproject_position(moving.global_position)) < 0.01, "single selected bracket tracks real projection in view " + str(mode))
		check(nav.target_caption.text.contains(str(host.world.targets[ids.npc].title)) and _caption_clear_of_hud(), "native caption remains current and avoids HUD in view " + str(mode))
	# A moving target advances its displayed range and caption in the same render.
	_focus(str(ids.npc))
	moving.global_position = host.camera.camera.global_position - host.camera.camera.global_basis.z * 550 + host.camera.camera.global_basis.x * 70
	await _frames(2)
	var old_text: String = nav.target_caption.text
	var old_position: Vector2 = nav.target_caption.position
	moving.global_position += host.camera.camera.global_basis.x * 95 - host.camera.camera.global_basis.z * 60
	await _frames(2)
	var changed: Dictionary = nav.target_geometry()
	check(nav.target_caption.text != old_text and not nav.target_caption.position.is_equal_approx(old_position) and changed.end.distance_to(host.camera.camera.unproject_position(moving.global_position)) < 0.01, "moving target range and annotation update together without stale copy")
	await capture("moving-target")
	for point: Vector3 in [Vector3(1200, 0, -500), Vector3(0, 0, 120)]:
		moving.global_position = host.camera.camera.global_transform * point
		nav.update_annotations()
		var geometry: Dictionary = nav.target_geometry()
		check(not geometry.is_empty() and not geometry.on_screen and geometry.end.is_finite(), "offscreen or behind target uses finite single edge marker " + str(point))
		check(not nav.marker_geometry().any(func(row: Dictionary): return row.id == ids.npc), "edge target never creates second on-screen marker " + str(point))
	_focus(str(ids.station))
	for window_size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		for scale: float in [1.0, 2.0]:
			root.size = window_size
			root.content_scale_size = Vector2i(Vector2(window_size) / scale)
			await _frames(4)
			host.ui.tick(1.0)
			await _frames(2)
			check(_caption_clear_of_hud() and nav.target_caption.position.is_equal_approx(nav.target_caption.position.round()), "single caption fits safe HUD bounds and pixel grid %s scale %.0f" % [window_size, scale])
			check(nav.selected_id == ids.station and not nav.marker_geometry().any(func(row: Dictionary): return row.id == ids.station), "single selected marker preserved under layout %s scale %.0f" % [window_size, scale])
	host.ui.show_page("pause")
	await _frames(2)
	check(not nav.is_visible_in_tree() and not nav.target_caption.is_visible_in_tree(), "pause removes all projected target annotations")
	host.ui.show_page("")
	host.ui.target_id = "missing_target"
	await _frames(2)
	check(nav.target_geometry().is_empty() and not nav.target_caption.visible and not nav.selection_frame.visible, "invalid selection clears name and selected header")
	var dead := Node3D.new()
	host.world.add_child(dead)
	host.world.targets["dead_target"] = {"id": "dead_target", "title": "已释放测试目标", "kind": "npc", "node": dead}
	host.ui.target_id = "dead_target"
	dead.free()
	await _frames(2)
	check(nav.target_geometry().is_empty() and not nav.target_caption.visible and not nav.marker_geometry().any(func(row: Dictionary): return row.id == "dead_target"), "freed target leaves no stale caption or marker")
	await finish()

func finish() -> void:
	if is_instance_valid(host): host.queue_free()
	await _frames(2)
	await create_timer(0.25).timeout
	print("TARGET_ANNOTATIONS_V5_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
