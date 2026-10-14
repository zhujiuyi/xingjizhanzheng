extends Node
## Real Main and catalog, fresh test-owned SQLite and actual Viewport input.
## Menu visits grant no resources, unlocks or progression and never open a save.
const Main = preload("res://runtime/main.gd")
const Navigation = preload("res://runtime/ui/service_navigation.gd")
const Codec = preload("res://runtime/data/codec.gd")
const State = preload("res://runtime/state.gd")
const Types = preload("res://contracts/contract_types.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
const IDS: Array[String] = ["station", "ships", "warehouse", "fitting", "market", "industry", "salvage", "missions", "civilizations", "research", "map", "pause"]
const LABELS: Array[String] = ["空间站", "舰队与借船", "仓库与货舱", "舰船配装", "站点市场", "工业与回收", "打捞鉴定", "任务与合同", "文明与声望", "科技与设施", "星域航路", "暂停与存读档"]
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(3440, 1370)]
var host: Main
var directory: String = ""
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var events: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var old_fps: int = 0
var started_ms: int = 0
var finishing: bool = false
@onready var root: Window = get_tree().root

func _ready() -> void:
	get_tree().set_meta("xj_service_navigation_v22_diagnostic", true)
	get_tree().create_timer(90.0).timeout.connect(func(): check(false, "watchdog"); finish())
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 6000
	while is_instance_valid(host) and host.busy and Time.get_ticks_msec() < deadline: await frames(1)
	if is_instance_valid(host): host._process(0.0)
	await frames(3)
	check(is_instance_valid(host) and not host.busy, "production SQLite endpoint settles")

func show(id: String) -> void:
	host.ui.show_page(id)
	# Simulation is frozen for state-invariance checks; this zero-delta production
	# frame still applies real camera, input and hangar/flight visibility rules.
	host._process(0.0)
	await frames(3)

func descendants(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in node.get_children():
		found.append(child)
		found.append_array(descendants(child))
	return found

func rows(node: Node, surface: String) -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in descendants(node):
		if child is Button and str(child.get_meta("service_surface", "")) == surface: found.append(child)
	return found

func row(node: Node, surface: String, id: String) -> Button:
	for button: Button in rows(node, surface):
		if str(button.get_meta("service_page_id", "")) == id: return button
	return null

func scrolls(control: Control) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: found.append(parent)
		parent = parent.get_parent()
	return found

func reveal(control: Control) -> void:
	for scroll: ScrollContainer in scrolls(control): scroll.ensure_control_visible(control)
	await frames(3)

func complete(control: Control) -> bool:
	if not control.is_visible_in_tree() or not Rect2(Vector2.ZERO, host.ui.root.size).grow(1.5).encloses(control.get_global_rect()): return false
	for scroll: ScrollContainer in scrolls(control):
		if not scroll.get_global_rect().grow(1.5).encloses(control.get_global_rect()): return false
	return true

func click(control: Control, label: String, request_count: int = 0) -> bool:
	if not check(is_instance_valid(control) and not (control is BaseButton and control.disabled), "real GUI control exists " + label): return false
	await reveal(control)
	var before: int = events.size()
	var ready: bool = false
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		if DisplayServer.get_name() != "headless" and not root.has_focus(): root.grab_focus()
		var center: Vector2 = control.get_global_rect().get_center()
		host.get_viewport().warp_mouse(center)
		var motion := InputEventMouseMotion.new()
		motion.position = center; motion.global_position = center
		host.get_viewport().push_input(motion, true)
		await frames(1)
		var hover: Control = host.get_viewport().gui_get_hovered_control()
		var reached: bool = hover != null and (hover == control or control.is_ancestor_of(hover))
		var native_pointer: bool = DisplayServer.get_name() == "headless" or root.has_focus() and control.get_global_rect().has_point(control.get_global_mouse_position())
		stable = stable + 1 if reached and complete(control) and native_pointer else 0
		if stable >= 2: ready = true; break
	if not check(ready, "actual pointer reaches complete control " + label): return false
	var center: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var input := InputEventMouseButton.new()
		input.button_index = MOUSE_BUTTON_LEFT; input.pressed = pressed
		input.position = center; input.global_position = center
		host.get_viewport().push_input(input, true)
	await settle()
	return check(events.size() == before + request_count, "GUI intent count %d " % request_count + label)

func key(code: Key, viewport: Viewport = null, reverse: bool = false) -> void:
	var target: Viewport = root if viewport == null else viewport
	for pressed: bool in [true, false]:
		# Selecting a page frees the old selector and popup on key-down.
		# Deliver key-up to the surviving window, as native dispatch does.
		if not is_instance_valid(target): target = root
		var input := InputEventKey.new()
		input.keycode = code; input.physical_keycode = code; input.pressed = pressed; input.shift_pressed = reverse
		if target is PopupMenu:
			# PopupMenu handles keyboard navigation in Window's input callback,
			# before Viewport.push_input. Inject through the real window dispatcher;
			# direct popup.push_input would skip that production handler entirely.
			input.window_id = target.get_window_id()
			if target.is_embedded(): root.push_input(input, true)
			else: Input.parse_input_event(input)
			await frames(1)
		else:
			target.push_input(input, true)
	await frames(2)

func authority() -> String:
	var value: Dictionary = {}
	var codec := Codec.new()
	for table: String in State.TABLES:
		var encoded: Array[Dictionary] = []
		for record: RefCounted in host.state.rows(table): encoded.append(codec.encode_row(table, record))
		value[table] = encoded
	value["slots"] = host.store._records("SELECT slot_id,current_snapshot_id,generation FROM save_slot ORDER BY slot_id", [])
	value["preferences"] = host.store.preferences()
	return JSON.stringify(value)

func sequence(buttons: Array[Button]) -> Array[String]:
	var ids: Array[String] = []
	for button: Button in buttons: ids.append(str(button.get_meta("service_page_id", "")))
	return ids

func identity(buttons: Array[Button], expected: Array[String], label: String) -> void:
	check(sequence(buttons) == expected, "one canonical page order " + label)
	var valid: bool = true
	for button: Button in buttons:
		var id: String = str(button.get_meta("service_page_id", ""))
		var index: int = IDS.find(id)
		valid = valid and index >= 0 and button.text == LABELS[index] and button.icon == Navigation.icon(id) and button.icon != null
	check(valid, "canonical labels and matching functional icons " + label)

func panel_identity(id: String, expected: Array[String]) -> void:
	var heading: Label = host.ui.panel.find_child("PageHeading", true, false)
	var icon: TextureRect = host.ui.panel.find_child("PageHeadingIcon", true, false)
	check(heading != null and heading.text == LABELS[IDS.find(id)] and icon != null and icon.texture == Navigation.icon(id), "actual page heading matches menu " + id)
	identity(rows(host.ui.sidebar, "sidebar"), expected, "sidebar/" + id)
	var selector: OptionButton = host.ui.panel.find_child("PageSelector", true, false)
	var valid: bool = selector != null and selector.item_count == expected.size()
	var options: Array[String] = []
	if selector != null:
		for index: int in range(selector.item_count):
			var key_id: String = str(selector.get_item_metadata(index))
			options.append(key_id)
			valid = valid and IDS.has(key_id) and selector.get_item_text(index) == LABELS[IDS.find(key_id)] and selector.get_item_icon(index) == Navigation.icon(key_id)
		valid = valid and options == expected and str(selector.get_item_metadata(selector.selected)) == id
	check(valid, "actual dropdown label icon order selection agrees " + id)

func geometry(button: Button, label: String, kind: String = "row") -> void:
	var font: Font = button.get_theme_font("font")
	var text_size: Vector2 = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
	var padding: Vector2 = button.get_theme_stylebox("normal").get_minimum_size()
	var icon_width: float = float(button.get_theme_constant("icon_max_width"))
	if icon_width <= 0.0 and button.icon != null: icon_width = button.icon.get_width()
	var icon_height: float = icon_width * button.icon.get_height() / button.icon.get_width() if button.icon != null else 0.0
	var required: Vector2 = Vector2(text_size.x + icon_width + button.get_theme_constant("h_separation"), maxf(text_size.y, icon_height)) + padding
	check(button.icon != null and icon_width >= 20.0 and button.size.x + 1.0 >= required.x and button.size.y + 1.0 >= required.y and button.size.y <= 40.0 and not button.clip_text, "compact row fits complete readable icon and label " + label)
	observations.append({"kind": kind, "label": label, "text": button.text, "rect": str(button.get_global_rect()), "required_width": required.x, "required_height": required.y, "icon_width": icon_width, "font_size": button.get_theme_font_size("font_size")})

func icon_assets() -> void:
	var found: Array[String] = []
	var unique: Array[String] = []
	var assets: Array[Dictionary] = Navigation.PAGES.duplicate()
	assets.append({"id": "observe", "icon": Navigation.OBSERVE_ICON})
	for definition: Dictionary in assets:
		if str(definition.id) != "observe": found.append(str(definition.id))
		var icon: Texture2D = Navigation.texture(str(definition.icon))
		if not check(icon != null, "production icon loads " + str(definition.id)): continue
		var image: Image = icon.get_image()
		if not check(image != null and not image.is_empty() and image.get_width() >= 24 and image.get_height() >= 24, "icon raster has usable native detail " + str(definition.id)): continue
		var ink: int = 0
		var cropped: bool = false
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				if image.get_pixel(x, y).a <= 0.05: continue
				ink += 1
				if x == 0 or y == 0 or x == image.get_width() - 1 or y == image.get_height() - 1: cropped = true
		var digest: String = image.get_data().hex_encode().sha256_text()
		check(ink >= 24 and not cropped and not unique.has(digest), "distinct nonblank complete functional symbol " + str(definition.id))
		unique.append(digest)
	check(found == IDS, "shared registry keeps independent expected page order")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var physical: Vector2i = DisplayServer.window_get_size(root.get_window_id())
	if not check(not image.is_empty() and image.get_size().distance_to(physical) <= 3.0, "native capture spans complete client " + label): return
	var lit: int = 0
	for y: int in range(10, image.get_height(), 80):
		for x: int in range(10, image.get_width(), 80):
			var pixel: Color = image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.025: lit += 1
	check(lit >= 10, "capture rejects blank actual rendering " + label)
	if check(image.save_png(directory.path_join(label + ".png")) == OK, "native screenshot saves " + label): captures += 1
	observations.append({"kind": "capture", "label": label, "width": image.get_width(), "height": image.get_height()})

func tab_rows(label: String) -> void:
	var entries: Array[Button] = rows(host.ui.station_services, "hangar")
	if entries.is_empty(): return
	entries[0].grab_focus()
	await frames(3)
	var visited: Array[String] = []
	var accessible: bool = true
	for index: int in range(entries.size()):
		var focused: Control = root.gui_get_focus_owner()
		accessible = accessible and focused == entries[index] and complete(entries[index])
		if focused != null: visited.append(str(focused.get_meta("service_page_id", "")))
		if index < entries.size() - 1: await key(KEY_TAB)
	check(accessible and visited == IDS, "real Tab reaches and reveals every compact row " + label)
	var before: String = authority()
	var count: int = events.size()
	for control_name: String in ["HangarOverview", "StationRepair"]:
		await key(KEY_TAB)
		var context: Button = host.ui.station_services.find_child(control_name, true, false)
		var focused: Control = root.gui_get_focus_owner()
		if check(context != null and focused == context and complete(context), "real Tab scrolls to complete contextual control " + label + "/" + control_name):
			geometry(context, label + "/" + control_name, "context-row")
			var context_scrolls: Array[Dictionary] = []
			for scroll: ScrollContainer in scrolls(context): context_scrolls.append({"name": str(scroll.name), "vertical": scroll.scroll_vertical, "rect": str(scroll.get_global_rect())})
			observations.append({"kind": "context-focus", "label": label, "control": control_name, "focus_path": str(focused.get_path()), "fully_visible": complete(context), "scrolls": context_scrolls})
			if control_name == "HangarOverview":
				check(context.icon == Navigation.texture(Navigation.OBSERVE_ICON) and str(context.get_meta("action", "")) == "hangar_focus", "secondary observation keeps complete actual symbol and formal intent " + label)
			else:
				check(str(context.get_meta("action", "")) == "repair" and str(context.get_meta("target", "")) == host.state.ship().ship_instance_id, "reachable repair retains actual ship-bound command " + label)
	check(authority() == before and events.size() == count, "context focus and scrolling execute no repair or hidden mutation " + label)

func layout_matrix() -> void:
	for size: Vector2i in SIZES:
		for scale: float in [1.0, 2.0]:
			root.mode = Window.MODE_WINDOWED
			root.size = size
			root.content_scale_factor = scale
			await frames(6)
			await show("station")
			host.ui.tick(1.0)
			await frames(4)
			var label: String = "%dx%d-%d" % [size.x, size.y, int(scale * 100)]
			identity(rows(host.ui.station_services, "hangar"), IDS, "hangar/" + label)
			var heading: Label = host.ui.station_services.find_child("StationNavigationHeading", true, false)
			check(heading != null and heading.text == "服务导航" and host.ui.station_services.find_child("PageHeading", true, false) == null and host.ui.station_services.find_child("PageHeadingIcon", true, false) == null, "landing has one navigation heading instead of duplicate station title and icon " + label)
			var station_captions: int = 0
			for node: Node in descendants(host.ui.station_services):
				if node is Button and node.text == "空间站": station_captions += 1
				if node is Label and node.text in ["空间站", "空间站服务"]: station_captions += 1
			check(station_captions == 1, "station caption appears only on its page row " + label)
			var bounds: Rect2 = Rect2(Vector2.ZERO, host.ui.root.size).grow(1.5)
			check(bounds.encloses(host.ui.station_services.get_global_rect()) and not host.ui.station_services.get_global_rect().has_point(host.ui.root.size * 0.5), "functional menu fits and leaves 3D ship center open " + label)
			var details_expected: bool = host.ui.root.size.x >= 950.0 and host.ui.root.size.y >= 560.0
			check(host.ui.station_details.visible == details_expected, "short or narrow client hides tall hangar telemetry " + label)
			if host.ui.station_details.visible:
				check(bounds.encloses(host.ui.station_details.get_global_rect()) and not host.ui.station_details.get_global_rect().intersects(host.ui.station_departure.get_global_rect()), "visible hangar telemetry fits client and avoids departure " + label)
			var transform: Transform2D = root.get_final_transform()
			var physical: Vector2i = DisplayServer.window_get_size(root.get_window_id()) if DisplayServer.get_name() != "headless" else root.size
			check((transform * root.get_visible_rect().position).length() <= 2.5 and (transform * root.get_visible_rect().end).distance_to(Vector2(physical)) <= 3.0 and absf(transform.x.length() - transform.y.length()) <= 0.005, "production canvas covers native client proportionally " + label)
			observations.append({"kind": "window", "label": label, "native_width": physical.x, "native_height": physical.y, "logical_width": host.ui.root.size.x, "logical_height": host.ui.root.size.y, "scale_factor": scale})
			for button: Button in rows(host.ui.station_services, "hangar"):
				geometry(button, label + "/" + str(button.get_meta("service_page_id", "")))
			await tab_rows(label)
			await reveal(row(host.ui.station_services, "hangar", "station"))
			await capture("hangar-" + label)
			await click(row(host.ui.station_services, "hangar", "pause"), "last scrollable row " + label)
			check(host.ui.page == "pause", "last row reaches actual system page " + label)
			panel_identity("pause", IDS)

func dropdown_navigation() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 2.0
	await show("missions")
	await frames(6)
	var selector: OptionButton = host.ui.panel.find_child("PageSelector", true, false)
	if not check(selector != null and selector.is_visible_in_tree(), "compact screen exposes actual page dropdown"): return
	if not await click(selector, "open compact page dropdown"): return
	var popup: PopupMenu = selector.get_popup()
	if not check(popup.visible, "real click opens native dropdown popup"): return
	var index: int = IDS.find("warehouse")
	var trace: Array[Dictionary] = []
	trace.append({"step": -1, "focused_index": popup.get_focused_item(), "popup_focus": popup.has_focus(), "root_focus": root.has_focus(), "visible": popup.visible})
	for step: int in range(popup.item_count + 1):
		if popup.get_focused_item() == index: break
		await key(KEY_DOWN, popup)
		var focused_index: int = popup.get_focused_item()
		trace.append({"step": step, "focused_index": focused_index, "focused_id": str(selector.get_item_metadata(focused_index)) if focused_index >= 0 and focused_index < selector.item_count else "", "popup_focus": popup.has_focus(), "root_focus": root.has_focus(), "visible": popup.visible})
	var observation: Dictionary = {"kind": "dropdown-keyboard", "window_id": popup.get_window_id(), "root_window_id": root.get_window_id(), "embedded": popup.is_embedded(), "requested_index": index, "trace": trace}
	observations.append(observation)
	print("SERVICE_NAVIGATION_V22_DROPDOWN " + JSON.stringify(observation))
	if not check(popup.get_focused_item() == index and str(selector.get_item_metadata(index)) == "warehouse", "actual dropdown keyboard reaches warehouse item"): await key(KEY_ESCAPE, popup); return
	await key(KEY_ENTER, popup)
	await frames(4)
	check(host.ui.page == "warehouse", "actual dropdown keyboard selection reaches production page")
	panel_identity("warehouse", IDS)

func only_industry_active() -> bool:
	var active: Array[String] = []
	var valid: bool = true
	for button: Button in rows(host.ui.sidebar, "sidebar"):
		var id: String = str(button.get_meta("service_page_id", ""))
		var font_color: Color = button.get_theme_color("font_color")
		var icon_color: Color = button.get_theme_color("icon_normal_color")
		if font_color == UISkin.AMBER: active.append(id)
		valid = valid and font_color == (UISkin.AMBER if id == "industry" else UISkin.TEXT) and icon_color == (UISkin.AMBER if id == "industry" else UISkin.TEXT)
		for color_key: String in ["font_hover_color", "font_pressed_color", "font_focus_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			valid = valid and button.get_theme_color(color_key) == (UISkin.AMBER if id == "industry" else UISkin.TEXT)
	return valid and active == ["industry"]

func industry_focus_regression() -> void:
	var industry: Button = row(host.ui.sidebar, "sidebar", "industry")
	var station: Button = row(host.ui.sidebar, "sidebar", "station")
	if not check(industry != null and station != null and industry.is_visible_in_tree() and station.is_visible_in_tree(), "initial industry exposes current and station navigation controls"): return
	var enabled_body: int = 0
	for node: Node in descendants(host.ui.body):
		if node is Button and node.is_visible_in_tree() and not node.disabled and node.focus_mode != Control.FOCUS_NONE: enabled_body += 1
	var enabled_manufacture: int = 0
	for quote: Dictionary in host.ui.quotes:
		if quote.action == "manufacture" and not quote.button.disabled: enabled_manufacture += 1
	check(enabled_manufacture == 0, "fresh industry still cannot manufacture without its actual prerequisites")
	var initial_focus: Control = root.gui_get_focus_owner()
	check(initial_focus != station and (initial_focus == industry if enabled_body == 0 else host.ui.body.is_ancestor_of(initial_focus)), "industry focuses an available body function or its own page without selecting station")
	check(only_industry_active(), "current industry alone has selected amber text and symbol")
	var normal: StyleBoxFlat = industry.get_theme_stylebox("normal") as StyleBoxFlat
	var focus: StyleBoxFlat = station.get_theme_stylebox("focus") as StyleBoxFlat
	var current_focus: StyleBoxFlat = industry.get_theme_stylebox("focus") as StyleBoxFlat
	var thin: bool = focus != null and current_focus != null and not focus.draw_center and focus.bg_color.a <= 0.001 and focus.border_color != UISkin.AMBER and focus.border_color == current_focus.border_color
	if focus != null:
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: thin = thin and focus.get_border_width(side) == 1
	check(thin, "keyboard focus is a separate thin neutral outline without selected fill")
	await capture("service-industry-focus")
	var before: String = authority()
	var count: int = events.size()
	var reached: bool = false
	for step: int in range(IDS.size() + 8):
		await key(KEY_TAB, null, true)
		if root.gui_get_focus_owner() == station: reached = true; break
	check(reached and complete(station), "real reverse Tab reaches fully visible station while industry stays open")
	check(host.ui.page == "industry" and only_industry_active(), "station keyboard focus does not create a second active page")
	var center: Vector2 = station.get_global_rect().get_center()
	host.get_viewport().warp_mouse(center)
	var motion := InputEventMouseMotion.new()
	motion.position = center; motion.global_position = center
	host.get_viewport().push_input(motion, true)
	await frames(3)
	var hovered: Control = host.get_viewport().gui_get_hovered_control()
	check(hovered != null and (hovered == station or station.is_ancestor_of(hovered)), "actual pointer hovers inactive station row")
	var hover: StyleBoxFlat = station.get_theme_stylebox("hover") as StyleBoxFlat
	var pressed: StyleBoxFlat = station.get_theme_stylebox("pressed") as StyleBoxFlat
	check(normal != null and hover != null and pressed != null and hover.bg_color != normal.bg_color and pressed.bg_color != normal.bg_color and only_industry_active(), "inactive hover and pressed feedback cannot imitate selected industry fill")
	observations.append({"kind": "industry-focus", "page": host.ui.page, "default_focus": "industry", "tab_focus": str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else "", "body_eligible_buttons": enabled_body, "only_industry_active": only_industry_active(), "focus_border": str(focus.border_color) if focus != null else "missing", "pointer_hover": str(hovered.get_path()) if hovered != null else "none"})
	check(authority() == before and events.size() == count, "industry Tab and hover leave economy typed state SQL endpoints and preferences unchanged")
	if reached:
		await key(KEY_ENTER)
		await settle()
		check(host.ui.page == "station" and host.ui.station_layer.visible and not host.ui.panel.visible, "real focused station Enter returns to hangar")
		check(authority() == before and events.size() == count, "keyboard station navigation changes no economy save pointers or requested business actions")

func navigation_and_observation() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_factor = 1.0
	await show("station")
	await frames(5)
	var before: String = authority()
	for id: String in IDS:
		await show("station")
		await frames(3)
		await click(row(host.ui.station_services, "hangar", id), "hangar destination " + id)
		check(host.ui.page == id, "real hangar row reaches declared page " + id)
		if id != "station": panel_identity(id, IDS)
		if id == "industry": await industry_focus_regression()
		if id in ["missions", "market"]: await capture("service-" + id)
	await show("missions")
	await frames(4)
	await click(row(host.ui.sidebar, "sidebar", "industry"), "sidebar industry")
	check(host.ui.page == "industry", "real sidebar reaches matching industry page")
	await dropdown_navigation()
	check(authority() == before and events.is_empty(), "page navigation leaves all typed state SQL endpoints and preferences unchanged")
	root.size = Vector2i(1440, 900)
	root.content_scale_factor = 1.0
	await show("station")
	await frames(4)
	check(host.ui.station_services.find_children("Npc*", "Button", true, false).is_empty() and host.ui.station_services.find_child("ObserveOperations", true, false) == null, "landing has no portrait cards or crew navigation controls")
	# Crew remains a production 3D scene. It is deliberately absent from the
	# functional menu; call the existing command before testing ship observation.
	host._command("hangar_focus", "operations", 1, "")
	var deadline: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline and host.hangar.get_camera().position.distance_to(host.hangar._camera_destination) > 1.0: await frames(1)
	check(host.hangar._focused == "operations" and host.hangar.get_service_anchor("operations").is_visible_in_tree(), "existing formal command preserves actual 3D crew observation")
	await capture("hangar-context-observation")
	var overview: Button = host.ui.station_services.find_child("HangarOverview", true, false)
	await click(overview, "secondary observe current ship", 1)
	check(host.hangar._focused.is_empty() and host.ui.page == "station" and events.size() == 1 and str(events[0].action) == "hangar_focus" and str(events[0].target).is_empty(), "secondary ship observe restores framing without changing service page")
	check(authority() == before, "observation changes no gameplay ownership funds permissions or save pointers")

func guarded_departure() -> void:
	await show("station")
	await frames(4)
	var repairs: int = 0
	for node: Node in descendants(host.ui.station_layer):
		if node is Button and str(node.get_meta("action", "")) == "repair": repairs += 1
	check(repairs == 1 and rows(host.ui.station_departure, "hangar").is_empty(), "repair stays singular and departure stays separate from page navigation")
	await click(host.ui.station_departure.find_child("UndockButton", true, false), "authoritative separate undock", 1)
	check(host.state.ship().status == Types.ShipStatus.FLYING and not host.state.player().has_docked_station_id and host.ui.page.is_empty() and not host.ui.station_layer.visible and not host.hangar.visible and host.world.visible and host.presentation_stage == "flight", "real undock reaches flight and hides landing controls")
	var expected: Array[String] = IDS.duplicate()
	expected.erase("station")
	var before: String = authority()
	var count: int = events.size()
	await show("missions")
	await frames(4)
	panel_identity("missions", expected)
	await click(row(host.ui.sidebar, "sidebar", "market"), "flight guarded market access")
	check(host.ui.page == "market" and not host.ui.station_layer.visible, "flight service row respects hidden hangar state")
	panel_identity("market", expected)
	var reason: bool = false
	var business_actions: int = 0
	for node: Node in descendants(host.ui.body):
		if node is Label and node.text.contains("此服务需要停靠空间站"): reason = true
		if node is Button and not str(node.get_meta("action", "")).is_empty(): business_actions += 1
	check(reason and business_actions == 0, "guarded service exposes docking reason and no actionable business shortcuts")
	check(authority() == before and events.size() == count, "guarded menu access cannot mutate flight state permissions or SQL save endpoints")
	await capture("flight-market-docking-guard")

func _run() -> void:
	started_ms = Time.get_ticks_msec()
	old_fps = Engine.max_fps
	Engine.max_fps = 120
	var script_path: String = OS.get_environment("XJ_SERVICE_NAVIGATION_V22_SCRIPT").replace("\\", "/")
	directory = OS.get_environment("XJ_SERVICE_NAVIGATION_V22_DIRECTORY").replace("\\", "/")
	var prefix: String = script_path.get_base_dir().get_base_dir().path_join("tmp/service-navigation-v22")
	var uuid := RegEx.new()
	uuid.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	if not check(script_path.is_absolute_path() and not script_path.contains("..") and script_path.ends_with("/jiaoben/tests/service_navigation_v22.gd") and directory.is_absolute_path() and not directory.contains("..") and directory.get_base_dir() == prefix and uuid.search(directory.get_file()) != null and not FileAccess.file_exists(directory.path_join("progress.db")), "fixed test Node requires fresh scoped UUID SQLite"):
		await finish(); return
	DirAccess.make_dir_recursive_absolute(directory)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_factor = 1.0
	host = Main.new()
	host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host)
	await frames(4)
	if not check(host.services_ready, "real source or packed Main opens formal catalog and isolated SQLite"): await finish(); return
	await host._command("new_world", "空间站功能菜单独立验收", 1, "")
	await settle()
	if not check(host.state != null and host.state.ship().status == Types.ShipStatus.DOCKED, "fresh initial world docks using real typed state"): await finish(); return
	host.set_process(false)
	host.set_physics_process(false)
	host.ui.requested.connect(func(action: String, target: String, quantity: int, extra: String): events.append({"action": action, "target": target, "quantity": quantity, "extra": extra}))
	icon_assets()
	await layout_matrix()
	await navigation_and_observation()
	await guarded_departure()
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(4)
	await get_tree().create_timer(0.25).timeout
	Engine.max_fps = old_fps
	var result: String = "PASS" if failures.is_empty() else "FAIL"
	var summary: Dictionary = {"result": result, "checks": checks, "captures": captures, "failures": failures.size(), "failure_labels": failures, "directory": directory, "database_path": directory.path_join("progress.db"), "native": DisplayServer.get_name() != "headless", "seconds": (Time.get_ticks_msec() - started_ms) / 1000.0, "fixture": "fresh-main-real-gui-no-granted-assets-no-personal-save", "observations": observations}
	if not directory.is_empty() and DirAccess.dir_exists_absolute(directory):
		var file: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(summary, "\t") + "\n"); file.close()
	print("SERVICE_NAVIGATION_V22_FINAL_JSON " + JSON.stringify(summary))
	print("SERVICE_NAVIGATION_V22_RESULT %s checks=%d captures=%d failures=%d" % [result, checks, captures, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
