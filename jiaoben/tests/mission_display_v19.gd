extends Node
## Real Main, fresh SQLite, real Viewport GUI input. Long content below is a
## presentation-only stress fixture; no balance, unlocks or personal saves change.
const Main = preload("res://runtime/main.gd")
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
const Codec = preload("res://runtime/data/codec.gd")
const FILTERS: Array[String] = ["local", "available", "active", "tutorial", "story", "contract", "all"]
const SIZES: Array[Vector2i] = [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(3440, 1370)]
var host: Main
var directory: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var events: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var old_fps: int = 0
var baseline: bool = false
var finishing: bool = false
var root: Window:
	get: return get_tree().root
var process_frame: Signal:
	get: return get_tree().process_frame

func _ready() -> void:
	get_tree().set_meta("xj_mission_display_v19_diagnostic", true)
	get_tree().create_timer(540.0).timeout.connect(func(): check(false, "watchdog"); finish())
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func wait_writer() -> void:
	var deadline: int = Time.get_ticks_msec() + 6000
	while is_instance_valid(host) and host.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(is_instance_valid(host) and not host.busy, "production SQLite writer settles")

func command(action: String, target: String = "", quantity: int = 1, extra: String = "") -> void:
	host._command(action, target, quantity, extra)
	await frames(4)
	await wait_writer()

func start_host() -> bool:
	host = Main.new()
	host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host)
	host.set_process(false)
	host.set_physics_process(false)
	await frames(4)
	if not check(host.services_ready, "real Main opens formal catalog and scoped SQLite"): return false
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): events.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))
	return true

func release_host() -> void:
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(4)
	await get_tree().create_timer(0.25).timeout

func show(filter: String = "local", page_number: int = 0) -> void:
	host.ui.mission_filter = filter
	host.ui.mission_focus_id = ""
	host.ui.mission_page = page_number
	host.ui.show_page("missions")
	await frames(4)
	host.ui.tick(1.0)
	await frames(3)

func buttons_below(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button: found.append(child)
		found.append_array(buttons_below(child))
	return found

func lists_below(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node.has_meta("business_list"): found.append(node)
	for child: Node in node.get_children(): found.append_array(lists_below(child))
	return found

func mission_rows() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for list: Node in lists_below(host.ui.body):
		for row: Dictionary in list.get("rows"):
			if bool(row.row.get_meta("mission_row", false)): found.append(row)
	return found

func row_for(id: String) -> Dictionary:
	for row: Dictionary in mission_rows():
		if str(row.id) == id: return row
	return {}

func action_button(action: String, target: String = "") -> Button:
	for button: Button in buttons_below(host.ui.body):
		if str(button.get_meta("action", "")) == action and (target.is_empty() or str(button.get_meta("target", "")) == target): return button
	return null

func scroll_ancestors(control: Control) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: found.append(ancestor)
		ancestor = ancestor.get_parent()
	return found

func reveal(control: Control) -> void:
	for scroll: ScrollContainer in scroll_ancestors(control): scroll.ensure_control_visible(control)
	await frames(4)

func visible_control(control: Control) -> bool:
	if not control.is_visible_in_tree() or not Rect2(Vector2.ZERO, host.ui.root.size).grow(1.0).encloses(control.get_global_rect()): return false
	for scroll: ScrollContainer in scroll_ancestors(control):
		if not scroll.get_global_rect().grow(1.0).encloses(control.get_global_rect()): return false
	return true

func button_geometry(button: Button, label: String) -> void:
	var font: Font = button.get_theme_font("font")
	var size: int = button.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var style: StyleBox = button.get_theme_stylebox("normal")
	var required: Vector2 = text_size + style.get_minimum_size()
	check(button.size.x + 1.0 >= required.x, "button text width complete " + label)
	check(button.size.y + 1.0 >= required.y and button.size.y <= maxf(80.0, required.y + 30.0), "button text height usable " + label)
	check(button.get_parent().get_global_rect().grow(1.0).encloses(button.get_global_rect()), "action cell contains full button " + label)
	observations.append({"kind": "button", "label": label, "text": button.text, "width": button.size.x, "height": button.size.y, "required_width": required.x, "required_height": required.y, "disabled": button.disabled})

func row_geometry(row: Dictionary, label: String, visit_actions: bool = false) -> void:
	var actions: Array[Button] = buttons_below(row.actions)
	check(actions.size() >= 2, "real mission row exposes actions " + label)
	for button: Button in actions:
		button_geometry(button, label + "/" + str(button.get_meta("action", button.text)))
		if visit_actions:
			await reveal(button)
			check(visible_control(button), "scroll reveals complete mission action " + label + "/" + button.text)
	var description: Label = row.description
	var natural_height: float = maxf(description.get_minimum_size().y + row.name.get_minimum_size().y + 40.0, row.actions.get_minimum_size().y + 28.0)
	check(row.row.size.y <= maxf(320.0, natural_height + 20.0) and row.row.size.y < 760.0, "mission row has bounded natural height " + label)
	check(not row.name.text.is_empty() and not row.description.text.is_empty() and not row.status.text.is_empty(), "real mission identity description and status remain visible " + label)
	observations.append({"kind": "row", "label": label, "height": row.row.size.y, "description_lines": description.get_line_count(), "actions": actions.size()})

func actual_click(button: Button, label: String) -> bool:
	if not check(is_instance_valid(button) and not button.disabled, "legal GUI action exists " + label): return false
	await reveal(button)
	var before: int = events.size()
	var stable: int = 0
	var ready: bool = false
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if DisplayServer.get_name() != "headless" and not root.has_focus(): root.grab_focus()
		var center: Vector2 = button.get_global_rect().get_center()
		host.get_viewport().warp_mouse(center)
		var motion := InputEventMouseMotion.new()
		motion.position = center; motion.global_position = center
		host.get_viewport().push_input(motion, true)
		await process_frame
		var hovered: Control = host.get_viewport().gui_get_hovered_control()
		var on_button: bool = hovered != null and (hovered == button or button.is_ancestor_of(hovered))
		stable = stable + 1 if on_button and visible_control(button) else 0
		if stable >= 2: ready = true; break
	if not check(ready, "real Viewport pointer reaches " + label):
		print("MISSION_DISPLAY_V19_GUI_TIMEOUT ", label, " rect=", button.get_global_rect(), " hovered=", host.get_viewport().gui_get_hovered_control())
		return false
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT; click.pressed = pressed
		click.position = button.get_global_rect().get_center(); click.global_position = click.position
		host.get_viewport().push_input(click, true)
	await frames(6)
	await wait_writer()
	return check(events.size() == before + 1, "real GUI click emits exactly one production request " + label)

func latest(id: String = "tutorial_flight") -> D.MissionStateDto:
	return host.ui._latest_mission(id)

func capture(label: String, coverage: bool = false) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not check(not image.is_empty() and image.get_width() > 300 and image.get_height() > 200, "native rendered screenshot has real pixels " + label): return
	if coverage:
		var physical: Vector2i = DisplayServer.window_get_size(root.get_window_id())
		check(Vector2(image.get_size()).distance_to(Vector2(physical)) <= 3.0, "native screenshot spans complete client pixel dimensions " + label)
	var center_pixels: int = 0
	var left_pixels: int = 0
	var right_pixels: int = 0
	var count: int = 0
	for y: int in range(int(image.get_height() * 0.15), int(image.get_height() * 0.85), 7):
		for x: int in range(4, mini(28, image.get_width()), 4):
			var left: Color = image.get_pixel(x, y)
			var right: Color = image.get_pixel(image.get_width() - 1 - x, y)
			var center: Color = image.get_pixel(int(float(image.get_width()) * 0.5) + x, y)
			if maxf(left.r, maxf(left.g, left.b)) > 0.006: left_pixels += 1
			if maxf(right.r, maxf(right.g, right.b)) > 0.006: right_pixels += 1
			if maxf(center.r, maxf(center.g, center.b)) > 0.025: center_pixels += 1
			count += 1
	check(float(center_pixels) > float(count) / 30.0, "screenshot rejects blank rendering " + label)
	if coverage:
		check(float(left_pixels) > float(count) / 30.0 and float(right_pixels) > float(count) / 30.0, "native image content reaches both outer edges " + label)
	observations.append({"kind": "capture", "label": label, "width": image.get_width(), "height": image.get_height(), "samples": count, "center_pixels": center_pixels, "left_pixels": left_pixels, "right_pixels": right_pixels, "coverage_required": coverage})
	if check(image.save_png(directory.path_join(label + ".png")) == OK, "native screenshot saves " + label): captures += 1

func window_geometry(label: String) -> void:
	var physical: Vector2i = DisplayServer.window_get_size(root.get_window_id()) if DisplayServer.get_name() != "headless" else root.size
	var visible: Rect2 = root.get_visible_rect()
	var transform: Transform2D = root.get_final_transform()
	var top_left: Vector2 = transform * visible.position
	var bottom_right: Vector2 = transform * visible.end
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "production aspect expands native window " + label)
	check(root.content_scale_size == Vector2i(1440, 900), "production base canvas stays fixed " + label)
	check(top_left.length() <= 2.5 and bottom_right.distance_to(Vector2(physical)) <= 3.0, "logical canvas maps onto complete native client area " + label)
	check(absf(transform.x.length() - transform.y.length()) <= 0.005, "native stretch preserves pixel proportions " + label)
	check(host.ui.root.size.distance_to(visible.size) <= 2.0, "real UI root follows expanded logical viewport " + label)
	check(Rect2(Vector2.ZERO, host.ui.root.size).grow(2.0).encloses(host.ui.panel.get_global_rect()), "missions panel stays inside expanded viewport " + label)
	observations.append({"kind": "window", "label": label, "mode": root.mode, "native_width": physical.x, "native_height": physical.y, "window_width": root.size.x, "window_height": root.size.y, "logical_width": visible.size.x, "logical_height": visible.size.y, "scale_factor": root.content_scale_factor, "aspect": root.content_scale_aspect, "mapped_left": top_left.x, "mapped_top": top_left.y, "mapped_right": bottom_right.x, "mapped_bottom": bottom_right.y})

func filters_and_pages(label: String, full_pages: bool = false) -> void:
	for filter: String in FILTERS:
		await show(filter)
		var definitions: Array[Dictionary] = host.ui._filtered_mission_definitions()
		var pages: int = maxi(1, ceili(float(definitions.size()) / 6.0)) if full_pages else 1
		for index: int in range(pages):
			if index > 0: await show(filter, index)
			var rows: Array[Dictionary] = mission_rows()
			check(rows.size() == mini(6, maxi(0, definitions.size() - index * 6)), "filter page contains exact formal rows " + label + "/" + filter + "/" + str(index))
			for row: Dictionary in rows:
				await row_geometry(row, label + "/" + filter + "/" + str(row.id), full_pages)
				var definition: Dictionary = host.store.catalog.one("mission_defs", "mission_id", str(row.id))
				var current: D.MissionStateDto = latest(str(row.id))
				var active: bool = current != null and current.status in ["active", "ready"]
				var button: Button = action_button("deliver_mission" if active else "accept_mission", current.mission_instance_id if active else str(row.id))
				check(button != null, "formal row retains accept or deliver action " + label + "/" + str(row.id))
				if button == null: continue
				var disabled: bool = current.status != "ready" or host.state.player().docked_station_id != definition.turnin_station_id if active else not host.ui._mission_reason(definition, current).is_empty()
				check(button.disabled == disabled, "UI disabled permission agrees with authoritative mission state " + label + "/" + str(row.id))

func gui_mission_and_persistence() -> void:
	await show("tutorial")
	check(host.state.rows("unlock_state").size() > 0 and not host.gameplay.call("unlocked", "unlock_open_routes"), "fresh world retains initial progression without blanket unlock fixture")
	if not await actual_click(action_button("accept_mission", "tutorial_flight"), "accept legal initial tutorial"): return
	var mission: D.MissionStateDto = latest()
	if not check(mission != null and mission.status == "active" and mission.attempt_number == 1, "GUI accepts real typed initial tutorial"): return
	var initial_id: String = mission.mission_instance_id
	await show("active")
	var row: Dictionary = row_for("tutorial_flight")
	if check(not row.is_empty(), "active filter exposes accepted tutorial"):
		await row_geometry(row, "accepted-initial-tutorial", true)
		check(action_button("mission_locate", "tutorial_flight") != null and action_button("mission_travel", "tutorial_flight") != null and action_button("abandon_mission", initial_id) != null, "active row retains locate travel and abandon controls")
		var deliver: Button = action_button("deliver_mission", initial_id)
		check(deliver != null and deliver.disabled, "incomplete tutorial delivery remains disabled")
		await reveal(action_button("abandon_mission", initial_id))
		await capture("accepted-tutorial-actions")
	if not await actual_click(action_button("abandon_mission", initial_id), "abandon accepted tutorial"): return
	check(latest().status == "abandoned", "GUI abandons same real mission attempt")
	await show("tutorial")
	if not await actual_click(action_button("accept_mission", "tutorial_flight"), "reaccept initial tutorial"): return
	mission = latest()
	check(mission.status == "active" and mission.attempt_number == 2 and mission.mission_instance_id != initial_id, "reaccept creates actual distinct second attempt")
	var expected: Dictionary = Codec.new().encode_row("mission_state", mission)
	var world: String = host.state.world_id
	var unlock_count: int = host.state.rows("unlock_state").size()
	check(host.store.save(host.state, "manual", 2), "accepted GUI mission seals through real SQLite writer")
	var sealed: Array[Dictionary] = host.store._records("SELECT slot_id,current_snapshot_id,generation FROM save_slot WHERE world_id=? AND slot_kind='manual' AND slot_index=2", [world])
	check(sealed.size() == 1 and not str(sealed[0].current_snapshot_id).is_empty(), "accepted tutorial has durable manual snapshot endpoint")
	await release_host()
	if not await start_host(): return
	await command("continue")
	if not check(host.state != null and host.state.world_id == world, "closed SQLite reopens exact GUI mission world"): return
	check(latest() != null and Codec.new().encode_row("mission_state", latest()) == expected, "SQLite restart preserves real mission attempt status and progress")
	check(host.state.rows("unlock_state").size() == unlock_count, "display and GUI checks grant no extra progression unlocks")
	await show("active")
	await row_geometry(row_for("tutorial_flight"), "reopened-tutorial", true)

func stress_content() -> void:
	await show("active")
	var list: Node = host.ui._business_list("测试专用长说明与大量操作")
	var description: String = ""
	for index: int in range(6): description += "第%d项目标：在当前恒星系统确认任务接取地点、舰船载荷与前置任务条件，按钮完整可读且长说明按列换行。\n" % (index + 1)
	var row: Dictionary = host.ui._asset_row(list, "presentation-stress-only", "mission", "tutorial_flight", "长中文任务描述与操作边界专项", description.strip_edges(), "份", "1", "—", "纯界面", "此行仅测试，不改变数据库")
	for index: int in range(12):
		var button: Button = host.ui._button(row.actions, "查看完整前置任务%d" % (index + 1), func(): pass)
		button.tooltip_text = "任务操作完整说明，包含十二项条件。"
		for step: int in range(12): button.tooltip_text += "\n条件%d：确认站点、任务及当前舰船载荷。" % (step + 1)
	await frames(6)
	check(row.description.get_line_count() > 6 and row.description.size.x >= 200, "long Chinese stress content wraps in a real usable description column")
	for button: Button in buttons_below(row.actions):
		button_geometry(button, "stress/" + button.text)
		await reveal(button)
		check(visible_control(button), "all twelve stress actions scroll into complete viewport bounds " + button.text)
	check(row.row.size.y < 760.0, "long text and twelve actions have bounded stress row height")
	await capture("long-chinese-twelve-actions")
	await native_tooltip_check(buttons_below(row.actions)[0])

func find_tooltip(node: Node, text: String) -> Label:
	if node is Label and node.is_visible_in_tree() and node.text == text: return node
	for child: Node in node.get_children(true):
		var found: Label = find_tooltip(child, text)
		if found != null: return found
	return null

func native_tooltip_check(button: Button) -> void:
	check(button.tooltip_text.split("\n").size() == 13 and button.tooltip_text.contains("条件12"), "long tooltip retains every instructed stress condition")
	if DisplayServer.get_name() == "headless": return
	await reveal(button)
	root.grab_focus()
	var center: Vector2 = button.get_global_rect().get_center()
	host.get_viewport().warp_mouse(center)
	var motion := InputEventMouseMotion.new()
	motion.position = center; motion.global_position = center
	host.get_viewport().push_input(motion, true)
	await get_tree().create_timer(0.85).timeout
	await frames(4)
	var tooltip: Label = find_tooltip(root, button.tooltip_text)
	if check(tooltip != null, "native real hover creates complete thirteen-line stress tooltip"):
		var popup: Window = tooltip.get_window()
		check(popup.size.x <= root.size.x and popup.size.y <= root.size.y and Rect2(Vector2.ZERO, Vector2(popup.size)).grow(1.0).encloses(tooltip.get_global_rect()), "native long tooltip text fits popup and native game window")
	await capture("long-tooltip-200percent")

func layouts() -> void:
	for size: Vector2i in SIZES:
		for scale: float in [1.0, 2.0]:
			root.mode = Window.MODE_WINDOWED
			root.size = size
			root.content_scale_factor = scale
			await frames(8)
			var label: String = "%dx%d-%d" % [size.x, size.y, int(scale * 100)]
			await filters_and_pages(label)
			await show("active")
			window_geometry(label)
			var row: Dictionary = row_for("tutorial_flight")
			if not row.is_empty():
				await row_geometry(row, "matrix-active/" + label, true)
				await reveal(action_button("abandon_mission", latest().mission_instance_id))
			await capture("missions-" + label, true)
	if DisplayServer.get_name() == "headless": return
	root.content_scale_factor = 1.0
	for mode: Window.Mode in [Window.MODE_MAXIMIZED, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		root.mode = mode
		await frames(20)
		var label: String = "maximized" if mode == Window.MODE_MAXIMIZED else "exclusive-fullscreen"
		check(root.mode == mode, "real native window enters " + label)
		await show("active")
		window_geometry(label)
		await row_geometry(row_for("tutorial_flight"), label, true)
		await capture("missions-" + label, true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	await frames(8)

func _run() -> void:
	old_fps = Engine.max_fps
	Engine.max_fps = 120
	baseline = OS.get_environment("XJ_MISSION_DISPLAY_V19_BASELINE") == "1"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_factor = 1.0
	# Preserve the project stretch/aspect rule; setting expand here would mask
	# exactly the production black-bar regression this test must detect.
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "production canvas_items stretch mode")
	var script_path: String = OS.get_environment("XJ_MISSION_DISPLAY_V19_SCRIPT").replace("\\", "/")
	var prefix: String = script_path.get_base_dir().get_base_dir().path_join("tmp/mission-display-v19") if not script_path.is_empty() else ProjectSettings.globalize_path("res://../jiaoben/tmp/mission-display-v19").replace("\\", "/")
	directory = OS.get_environment("XJ_MISSION_DISPLAY_V19_DIRECTORY").replace("\\", "/")
	if directory.is_empty():
		var scope: String = Crypto.new().generate_random_bytes(16).hex_encode()
		directory = prefix.path_join("%s-%s-%s-%s-%s" % [scope.substr(0, 8), scope.substr(8, 4), scope.substr(12, 4), scope.substr(16, 4), scope.substr(20, 12)])
	if not check(directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == prefix and directory.begins_with(prefix + "/") and directory.get_file().length() == 36, "test refuses directories outside fresh UUID tmp scope"): await finish(); return
	DirAccess.make_dir_recursive_absolute(directory)
	if not check(not FileAccess.file_exists(directory.path_join("progress.db")), "test refuses pre-existing progress database"): await finish(); return
	if not await start_host(): await finish(); return
	await command("new_world", "任务按钮与宽屏独立验收")
	if not check(host.state != null, "fresh world has real typed state"): await finish(); return
	print("MISSION_DISPLAY_V19_FIXTURE fresh-production-main scoped-sqlite no-personal-save no-granted-unlocks no-balance-edit long-content-presentation-only")
	if baseline:
		await show("story")
		for row: Dictionary in mission_rows(): await row_geometry(row, "baseline-story/" + str(row.id))
		await capture("baseline-story-compressed-actions")
		root.size = Vector2i(3440, 1370)
		await frames(8)
		await show("story")
		window_geometry("baseline-wide")
		await capture("baseline-wide-bars", true)
		await finish()
		return
	await filters_and_pages("initial-formal-catalog", true)
	await gui_mission_and_persistence()
	if latest() != null and latest().status == "active":
		await layouts()
		root.content_scale_factor = 2.0
		root.size = Vector2i(1280, 720)
		await frames(8)
		await stress_content()
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	await release_host()
	Engine.max_fps = old_fps
	var result: String = "PASS" if failures.is_empty() else "FAIL"
	if baseline: result = "REPRODUCED" if failures.any(func(label: String): return label.begins_with("button text width complete") or label.begins_with("production aspect expands") or label.begins_with("logical canvas maps")) else "UNREPRODUCED"
	var summary: Dictionary = {"result": result, "checks": checks, "captures": captures, "failures": failures.size(), "failure_labels": failures, "directory": directory, "database_path": directory.path_join("progress.db"), "baseline": baseline, "observations": observations, "fixture": "fresh-main-real-gui-initial-tutorial-isolated-sqlite-no-extra-unlocks", "native": DisplayServer.get_name() != "headless"}
	if not directory.is_empty() and DirAccess.dir_exists_absolute(directory):
		var output: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
		if output != null: output.store_string(JSON.stringify(summary, "\t") + "\n"); output.close()
	print("MISSION_DISPLAY_V19_FINAL_JSON " + JSON.stringify(summary))
	print("MISSION_DISPLAY_V19_RESULT %s checks=%d captures=%d failures=%d" % [result, checks, captures, failures.size()])
	get_tree().quit(0 if failures.is_empty() or baseline and result == "REPRODUCED" else 1)
