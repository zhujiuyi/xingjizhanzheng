extends SceneTree
## Native Metal screenshot QA. Synthetic NPC/work values below are UI fixtures,
## not combat or gameplay acceptance evidence; they are never saved.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const Factory = preload("res://runtime/visuals/visual_factory.gd")
var paths: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func capture(name: String) -> void:
	for frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/logs/ui-" + name + ".png")
	root.get_texture().get_image().save_png(path)
	paths.append(path)
	print("CAPTURE " + path)
func _run() -> void:
	var database_path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/client-preview.db")
	DirAccess.remove_absolute(database_path)
	var host: Node = Main.new()
	host.progress_database_path = database_path
	root.add_child(host)
	await process_frame
	await host._command("new_world", "视觉验收", 1, "")
	if host.state == null: quit(1); return
	host.busy = true
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for scale: float in [1.0, 2.0]:
			root.size = size
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_size = Vector2i(Vector2(size) / scale)
			var suffix: String = "%dx%d-%dpercent" % [size.x, size.y, int(scale * 100)]
			host.ui.set_operation_status("idle", "")
			for key: String in ["station", "market", "missions", "settings"]:
				host.ui.show_page(key)
				await capture(key + "-" + suffix)
			host.ui.show_page("pause")
			host.ui.set_operation_status("save", "保存等待：扫描周期尚未结束。继续航行或取消保存；也可放弃未保存进度退出。", true)
			await capture("pause-waiting-" + suffix)
			host.ui.page_scroll.scroll_vertical = 100000
			await capture("pause-exit-" + suffix)
	host.ui.set_operation_status("idle", "")
	host.busy = false
	host._business_action("accept_mission", "tutorial_flight", 1, "")
	while host.busy: await process_frame
	host._business_action("undock", "", 1, "")
	while host.busy: await process_frame
	host.busy = true
	host.ui.show_page("")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for scale: float in [1.0, 2.0]:
			root.size = size
			root.content_scale_size = Vector2i(Vector2(size) / scale)
			host.ui.tick(1.0)
			await capture("flight-%dx%d-%dpercent" % [size.x, size.y, int(scale * 100)])
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	# Fixture: expose actual typed NPC health readout and paid scan progress.
	var npc: D.NpcStateDto = D.NpcStateDto.new()
	npc.npc_instance_id = "ui_fixture_npc"
	var spawn: Dictionary = host.store.catalog.rows("npc_spawn_defs")[0]
	npc.spawn_id = str(spawn.spawn_id)
	host.state.add("npc_state", npc)
	var definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
	npc.alive = true
	npc.sector_id = host.state.current_sector()
	npc.shield = float(definition.shield_max) * 0.5
	npc.armor = float(definition.armor_max) * 0.85
	npc.hull = float(definition.hull_max)
	var visual: Node3D = Factory.enemy_scene(str(definition.archetype_id))
	host.world.add_child(visual)
	visual.position = host.world.flight.position + Vector3(35, 20, -500)
	host.world.targets[npc.npc_instance_id] = {"id": npc.npc_instance_id, "title": str(definition.display_name) + " · 等级 " + str(definition.level), "kind": "npc", "node": visual, "anchor_id": ""}
	host.ui.target_id = npc.npc_instance_id
	host.gameplay.work.scan_target = "signal_anchor_gate_calibration"
	host.gameplay.work.scan_progress = 30.0
	host.gameplay.work.scan_remaining = 1.5
	host.ui.tick(1.0)
	await capture("flight-npc-scan-fixture")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(640, 360)
	host.ui.tick(1.0)
	await capture("flight-npc-scan-fixture-1280x720-200percent")
	host.queue_free()
	await process_frame
	print("CLIENT_PREVIEW_RESULT PASS captures=%d native Metal UI fixtures explicitly marked" % paths.size())
	quit()
