extends SceneTree
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Hangar = preload("res://runtime/station_hangar.gd")
const Factory = preload("res://runtime/visuals/visual_factory.gd")
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var host: Node
var preview_hangar: Node3D
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result
func capture(name: String) -> void:
	for frame: int in range(12): await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/logs/ui-v2-" + name + ".png")
	root.get_texture().get_image().save_png(path)
	captures += 1
	print("CAPTURE " + path)

func settle_fixture_pose(node: Node3D) -> void:
	# This manually placed NPC is a layout fixture. Its interpolation history
	# must start at that pose; the real UI/camera keep their normal render loop.
	await physics_frame
	node.get_global_transform_interpolated()
	node.reset_physics_interpolation()
	for frame: int in range(3): await process_frame

func check_instrument_content(ui: Node, label: String) -> void:
	var compact: bool = ui.root.size.x < 950
	var readouts: Array[Label] = []
	for entry: Dictionary in ui.condition_bars: readouts.append(entry.label)
	readouts.append(ui.energy_label); readouts.append(ui.heat_label)
	if compact: readouts.append(ui.compact_speed_label)
	else: readouts.append(ui.instrument_title); readouts.append(ui.cargo_label)
	var inside: bool = true
	var separate: bool = true
	var readable: bool = true
	for index: int in range(readouts.size()):
		var readout: Label = readouts[index]
		inside = inside and readout.is_visible_in_tree() and ui.instrument.get_global_rect().encloses(readout.get_global_rect())
		for other: int in range(index + 1, readouts.size()):
			separate = separate and not readout.get_global_rect().intersects(readouts[other].get_global_rect())
		if not compact: separate = separate and not readout.get_global_rect().intersects(ui.dial.get_global_rect())
		if compact:
			var font_size: int = readout.get_theme_font_size("font_size")
			var face: Font = readout.get_theme_font("font")
			var text_size: Vector2 = face.get_string_size(readout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			readable = readable and font_size >= 10 and text_size.x <= readout.size.x + 0.5 and face.get_height(font_size) <= readout.size.y + 0.5
	check(inside, "all real instrument labels fit their own panel " + label)
	check(separate, "instrument labels and visible dial own separate bounds " + label)
	if not compact: return
	var ship: D.ShipStateDto = host.state.ship()
	var speed_text: String = XJSpaceUnits.speed(Vector3(ship.vel_x, ship.vel_y, ship.vel_z).length())
	check(readable and not ui.dial.is_visible_in_tree() and ui.compact_speed_label.text.begins_with(speed_text) and ui.compact_speed_label.tooltip_text.contains("显示舰船"), "compact two-column readout retains readable values, true speed and view recovery " + label)
	var ship_area: Rect2 = Rect2(ui.root.size * 0.5 - Vector2(36, 28), Vector2(72, 56))
	check(not ui.equipment_bar.get_global_rect().intersects(ship_area) and not ui.instrument.get_global_rect().intersects(ship_area) and not ui.instrument.get_global_rect().intersects(ui.navigation.get_global_rect()), "compact bottom controls preserve central hull area and separate navigation " + label)
	var equipment_content: bool = true
	for id: String in ui.equipment_bar.module_buttons:
		var button: Button = ui.equipment_bar.module_buttons[id]
		var module_labels: Dictionary = ui.equipment_bar.module_labels[id]
		equipment_content = equipment_content and button.get_global_rect().encloses(module_labels.title.get_global_rect()) and button.get_global_rect().encloses(module_labels.status.get_global_rect()) and not module_labels.title.get_global_rect().intersects(module_labels.status.get_global_rect()) and module_labels.title.get_theme_font_size("font_size") >= 10 and module_labels.status.get_theme_font_size("font_size") >= 9
	check(equipment_content, "compact device name and true cycle state fit each actual button " + label)
	check(ui.navigation_hud.radar_frame.size.x <= 150.5 and ui.navigation_hud.radar_frame.size.y <= 140.5, "compact radar preserves its 150 by 140 footprint " + label)
func _run() -> void:
	var path: String = ProjectSettings.globalize_path("res://../jiaoben/tmp/ui-v2-client.db")
	DirAccess.remove_absolute(path)
	host = Main.new()
	host.progress_database_path = path
	root.add_child(host)
	await process_frame
	check(host.services_ready, "actual client services start")
	await capture("title-1440x900")
	for title_size: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for title_scale: float in [1.0, 2.0]:
			root.size = title_size
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_size = Vector2i(Vector2(title_size) / title_scale)
			host.ui.show_title(host.ui.slots)
			await capture("title-%dx%d-%dpercent" % [title_size.x, title_size.y, int(title_scale * 100)])
			var start: Button
			for node: Node in descendants(host.ui.body):
				if node is Button and node.text == "建立新远征": start = node
			check(start != null and Rect2(Vector2.ZERO, host.ui.root.size).encloses(start.get_global_rect()), "title new expedition reachable %s x%.0f" % [str(title_size), title_scale])
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	await process_frame
	await host._command("new_world", "第二版原生界面验收", 1, "")
	check(host.state != null, "actual single player world created")
	if host.state == null: quit(1); return
	host.busy = true
	# Use the real hangar component until Main's parallel integration is available.
	if host.get("hangar") == null:
		preview_hangar = Hangar.new()
		host.add_child(preview_hangar)
		preview_hangar.configure(host.state.ship().ship_def_id, host.store.catalog)
		host.world.hide()
		preview_hangar.get_camera().make_current()
		print("PREVIEW actual hangar component temporarily attached; Main integration is separate")
	var ui: Node = host.ui
	ui.show_page("station")
	ui.tick(1.0)
	await capture("station-1440x900")
	check(not ui.panel.visible and ui.station_layer.visible, "default station does not cover hangar with fullscreen menu")
	check(ui.station_portraits.size() == 4 and ui.station_portraits[0].texture != null, "four NPC portrait AtlasTexture services loaded")
	var center: Vector2 = ui.root.size * 0.5
	check(not ui.station_services.get_global_rect().has_point(center) and not ui.station_details.get_global_rect().has_point(center), "station leaves center viewport open for 3D ship")
	check(ui.root.find_child("UndockButton", true, false) != null, "bottom departure retains authoritative undock intent")
	ui.refresh_page()
	await process_frame
	check(ui.body.get_child_count() > 0, "station refresh retains usable service controls")
	var preference_before: Dictionary = host.store.preferences().duplicate(true)
	for key: String in ["ships", "warehouse", "fitting", "market", "industry", "missions", "research", "map", "pause", "settings"]:
		ui.show_page(key)
		await capture(key + "-1440x900")
		check(ui.page == key and ui.body.get_child_count() > 0 and ui.root.find_child("PanelClose", true, false) != null, "full service content + return action " + key)
		check(root.gui_get_focus_owner() != null, "default keyboard focus " + key)
	check(preference_before == host.store.preferences(), "opening new settings does not reset stored preferences")
	ui.show_page("missions")
	var first_title: String = ""
	for node: Node in descendants(ui.body):
		if bool(node.get_meta("mission_row", false)):
			first_title = str(node.find_child("BusinessName", true, false).text)
			break
	check(first_title == "新手教学 1 · 出航准备", "first tutorial remains first visible mission list row with its chapter classification")
	ui.market_filter = "buy"
	ui.show_page("market")
	ui.quantity_input.value = 5
	var accurate: bool = true
	for row: Dictionary in ui.quotes:
		accurate = accurate and int(row.label.get_meta("quote_amount", -1)) == host.gameplay.economy.quote(row.id, 5)
	check(accurate and not ui.quotes.is_empty(), "redesigned market uses actual quantity/tax quote")
	# Resize the current workbench without rebuilding it: list scroll remains accessible.
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(640, 360)
	await process_frame
	await process_frame
	var list: Node = ui.body.find_child("BusinessList", true, false)
	check(list != null and list.horizontal_scroll.get_h_scroll_bar().max_value > list.horizontal_scroll.get_h_scroll_bar().page and list.top_scrollbar.visible, "live window resize retains populated business list and accessible horizontal scroll")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for scale: float in [1.0, 2.0]:
			root.size = size
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_size = Vector2i(Vector2(size) / scale)
			await process_frame
			for key: String in ["station", "missions", "market", "settings", "pause"]:
				ui.show_page(key)
				if key == "pause": ui.set_operation_status("save", "等待当前周期结束后保存；可继续航行或取消。", true)
				await capture("%s-%dx%d-%dpercent" % [key, size.x, size.y, int(scale * 100)])
				var bounds: Rect2 = Rect2(Vector2.ZERO, ui.root.size)
				if key == "station":
					var undock: Button = ui.station_layer.find_child("UndockButton", true, false)
					check(bounds.encloses(undock.get_global_rect()), "departure reachable %s x%.0f" % [str(size), scale])
				else:
					var close: Button = ui.panel.find_child("PanelClose", true, false)
					check(bounds.encloses(close.get_global_rect()) and ui.page_scroll.size.y > 28, "return/content scroll reachable %s %s x%.0f" % [key, str(size), scale])
				if key == "pause":
					check(bounds.encloses(ui.operation_cancel.get_global_rect()), "save cancel reachable %s x%.0f" % [str(size), scale])
					check(not ui.operation_cancel.focus_next.is_empty() and not ui.operation_cancel.focus_previous.is_empty(), "save cancel participates in keyboard focus chain %s x%.0f" % [str(size), scale])
				ui.set_operation_status("idle", "")
	ui.show_page("station")
	host.busy = false
	host._business_action("accept_mission", "tutorial_flight", 1, "")
	while host.busy: await process_frame
	host._business_action("undock", "", 1, "")
	while host.busy: await process_frame
	host.busy = true
	if preview_hangar != null:
		preview_hangar.hide()
		host.world.show()
		host.camera.camera.make_current()
	ui.show_page("")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900)]:
		for scale: float in [1.0, 2.0]:
			root.size = size
			root.content_scale_size = Vector2i(Vector2(size) / scale)
			await process_frame
			ui.tick(1.0)
			await capture("flight-%dx%d-%dpercent" % [size.x, size.y, int(scale * 100)])
			check(ui.instrument.visible and Rect2(Vector2.ZERO, ui.root.size).encloses(ui.instrument.get_global_rect()), "bottom instrument within viewport %s x%.0f" % [str(size), scale])
			check(not ui.instrument.get_global_rect().has_point(ui.root.size * 0.5), "fixed center reticle clear of instrument %s x%.0f" % [str(size), scale])
			check_instrument_content(ui, "%s x%.0f" % [str(size), scale])
			ui.set_operation_status("local_navigation", "本地导航状态夹具")
			var local_bar_hidden: bool = true
			for frame: int in range(12):
				await process_frame
				local_bar_hidden = local_bar_hidden and not ui.operation_bar.visible
			check(local_bar_hidden and ui.operation_kind == "local_navigation" and ui.navigation_frame.is_visible_in_tree() and ui.overview.is_visible_in_tree(), "local navigation keeps side status cards without a global bar %s x%.0f" % [str(size), scale])
			ui.set_operation_status("save_wait", "保存等待状态夹具", true)
			check(ui.operation_bar.is_visible_in_tree() and ui.operation_cancel.visible, "save transaction retains its global status and cancel action %s x%.0f" % [str(size), scale])
			ui.set_operation_status("travel", "跨星系充能状态夹具", true)
			check(ui.operation_bar.is_visible_in_tree() and not ui.operation_cancel.visible and ui.operation_kind == "travel", "cross-sector transaction retains its distinct global status %s x%.0f" % [str(size), scale])
			ui.set_operation_status("idle", "")
	check(ui.condition_bars.size() == 3 and is_equal_approx(ui.condition_bars[0].bar.value, host.state.ship().shield), "instrument bars reflect actual shield/armor/hull")
	var original_velocity: Vector3 = host.world.flight.velocity
	var original_mode: T.CameraMode = host.camera.mode
	host.world.flight.velocity = Vector3(3, 4, 12)
	host.world.flight.write_back()
	ui.tick(1.0)
	check(ui.compact_speed_label.is_visible_in_tree() and ui.compact_speed_label.text.begins_with(XJSpaceUnits.speed(13.0)), "compact speed reads a real nonzero flight velocity in the appropriate unit after production write-back")
	host.camera.bind(host.world.flight, host.store.catalog, T.CameraMode.FRONT)
	ui.tick(1.0)
	check(ui.compact_speed_label.text.contains("舰首隐藏") and ui.compact_speed_label.tooltip_text.contains("显示舰船"), "compact FRONT view explains the hidden exterior and actual recovery action")
	host.world.flight.velocity = original_velocity
	host.world.flight.write_back()
	host.camera.bind(host.world.flight, host.store.catalog, original_mode)
	ui.tick(1.0)
	var npc: D.NpcStateDto = D.NpcStateDto.new()
	npc.npc_instance_id = "ui_v2_npc_fixture"
	var spawn: Dictionary = host.store.catalog.rows("npc_spawn_defs")[0]
	npc.spawn_id = spawn.spawn_id
	npc.sector_id = host.state.current_sector()
	npc.alive = true
	var definition: Dictionary = host.store.catalog.one("npc_full_defs", "npc_id", spawn.npc_id)
	npc.shield = float(definition.shield_max) * 0.5
	npc.armor = float(definition.armor_max) * 0.85
	npc.hull = float(definition.hull_max)
	host.state.add("npc_state", npc)
	var visual: Node3D = Factory.enemy_scene(str(definition.archetype_id))
	host.world.add_child(visual)
	visual.position = host.world.flight.position + Vector3(35, 20, -500)
	host.world.targets[npc.npc_instance_id] = {"id": npc.npc_instance_id, "title": str(definition.display_name), "kind": "npc", "node": visual, "anchor_id": ""}
	await settle_fixture_pose(visual)
	ui.target_id = npc.npc_instance_id
	host.gameplay.work.scan_target = "signal_anchor_gate_calibration"
	host.gameplay.work.scan_progress = 30.0
	host.gameplay.work.scan_remaining = 1.5
	for scale: float in [1.0, 2.0]:
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280 / scale, 720 / scale)
		await process_frame
		ui.tick(1.0)
		await capture("flight-npc-work-fixture-%dpercent" % int(scale * 100))
		check(Rect2(Vector2.ZERO, ui.root.size).encloses(ui.work_stop.get_global_rect()) and not ui.work_stop.get_global_rect().intersects(ui.instrument.get_global_rect()), "scan stop clear of bottom instrument x%.0f" % scale)
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		root.warp_mouse(ui.target_panel.get_global_rect().get_center())
		for frame: int in range(6): await process_frame
		check(ui.input_blocked(), "native target module hover blocks flight input")
	host.queue_free()
	await process_frame
	print("UI_VISUAL_V2_RESULT %s checks=%d failures=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size(), captures])
	quit(0 if failures.is_empty() else 1)
