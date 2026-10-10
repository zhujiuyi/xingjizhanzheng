extends Node
## Real Main, native UI, real rendered allied/enemy combat and sealed results.
## Noble qualification and fitting supplies are explicit isolated preconditions.
const Main = preload("res://runtime/main.gd")
const Gameplay = preload("res://runtime/gameplay.gd")
const Factory = preload("res://runtime/visuals/civilization_visual_factory.gd")
const Codec = preload("res://runtime/data/codec.gd")
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
var host: Main
var directory: String
var checks: int = 0
var failures: Array[String] = []
var captures: int = 0
var impacts: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var finishing: bool = false
@onready var root: Window = get_tree().root

func _ready() -> void:
	get_tree().set_meta("xj_civilization_world_v24_diagnostic", true)
	get_tree().create_timer(420.0).timeout.connect(func(): check(false, "native watchdog"); finish())
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
	return value

func frames(count: int = 3) -> void:
	for index: int in range(count): await get_tree().process_frame

func settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 20000
	while is_instance_valid(host) and host.busy and Time.get_ticks_msec() < deadline: await frames()
	if is_instance_valid(host): host._process(0.0)
	await frames()

func show(page: String) -> void:
	host.ui.show_page(page)
	host._process(0.0)
	await frames(6)

func reveal(control: Control) -> void:
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await frames(4)

func click(control: Control, label: String) -> bool:
	if not check(control != null and control.is_visible_in_tree() and not (control is BaseButton and control.disabled), "native actionable control " + label): return false
	await reveal(control)
	var ready: bool = false
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline:
		if not root.has_focus(): root.grab_focus()
		var center: Vector2 = control.get_global_rect().get_center()
		host.get_viewport().warp_mouse(center)
		var motion := InputEventMouseMotion.new()
		motion.position = center; motion.global_position = center
		host.get_viewport().push_input(motion, true)
		await frames(1)
		var hover: Control = host.get_viewport().gui_get_hovered_control()
		var reached: bool = hover != null and (hover == control or control.is_ancestor_of(hover))
		var pointer: bool = root.has_focus() and control.get_global_rect().has_point(control.get_global_mouse_position())
		stable = stable + 1 if reached and pointer else 0
		if stable >= 2: ready = true; break
	if not ready: print("CIV_NATIVE_POINTER ", label, " focus=", root.has_focus(), " rect=", control.get_global_rect(), " mouse=", control.get_global_mouse_position(), " hover=", host.get_viewport().gui_get_hovered_control())
	if not check(ready, "real native pointer reaches " + label): return false
	var center: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center; event.global_position = center; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		host.get_viewport().push_input(event, true)
	await settle()
	return true

func key(value: Key, viewport: Viewport = null) -> void:
	var target: Viewport = root if viewport == null else viewport
	for down: bool in [true, false]:
		if not is_instance_valid(target): target = root
		var event := InputEventKey.new()
		event.keycode = value; event.physical_keycode = value; event.pressed = down
		if target is PopupMenu:
			event.window_id = target.get_window_id()
			if target.is_embedded(): root.push_input(event, true)
			else: Input.parse_input_event(event)
		else: target.push_input(event, true)
		await frames(1)
	await frames(2)

func choose(option: OptionButton, index: int) -> void:
	if not await click(option, "open sovereignty filter"): return
	var popup: PopupMenu = option.get_popup()
	if not check(popup.visible, "actual sovereignty popup opens"): return
	# Let the native opening mouse motion settle away from menu items before
	# using the keyboard; a late OS hover must not overwrite the arrow choice.
	host.get_viewport().warp_mouse(Vector2(4, 4))
	await get_tree().create_timer(0.12).timeout
	var deadline: int = Time.get_ticks_msec() + 2000
	var trace: Array[int] = []
	while Time.get_ticks_msec() < deadline:
		if popup.get_focused_item() == index: break
		await key(KEY_DOWN, popup)
		trace.append(popup.get_focused_item())
	print("CIV_NATIVE_DROPDOWN ", JSON.stringify({"index": index, "embedded": popup.is_embedded(), "trace": trace, "focused": popup.get_focused_item()}))
	check(popup.get_focused_item() == index, "native keyboard selects sovereignty choice")
	await key(KEY_ENTER, popup)

func capture(tag: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.get_width() == DisplayServer.window_get_size().x and image.get_height() == DisplayServer.window_get_size().y, "screenshot covers whole client " + tag)
	check(not image.is_empty() and image.get_used_rect().size.x > 300, "actual scene renders " + tag)
	if check(image.save_png(directory.path_join(tag + ".png")) == OK, "native image captured " + tag): captures += 1

func state_signature() -> String:
	var values: Dictionary = {}
	for table: String in XJRuntimeState.TABLES:
		var rows: Array = []
		for row: RefCounted in host.state.rows(table): rows.append(Codec.new().encode_row(table, row))
		values[table] = rows
	return JSON.stringify(values)

func place(candidate: XJRuntimeState, business: Gameplay, anchor_id: String, station: String = "") -> void:
	var anchor: Dictionary = host.store.catalog.one("anchor_defs", "anchor_id", anchor_id)
	var ship: D.ShipStateDto = candidate.ship()
	ship.sector_id = anchor.sector_id; ship.pos_x = anchor.x_m; ship.pos_y = anchor.y_m; ship.pos_z = anchor.z_m
	ship.vel_x = 0; ship.vel_y = 0; ship.vel_z = 0
	ship.has_station_id = not station.is_empty(); ship.station_id = station
	ship.status = T.ShipStatus.DOCKED if ship.has_station_id else T.ShipStatus.FLYING
	candidate.player().has_docked_station_id = ship.has_station_id; candidate.player().docked_station_id = station
	for container: D.ContainerStateDto in candidate.rows("container_state"):
		if container.has_ship_instance_id and container.ship_instance_id == ship.ship_instance_id: container.sector_id = ship.sector_id
	business.assign_anchor_site("ship", ship.ship_instance_id, anchor_id)
	if not station.is_empty(): business.inventory.warehouse(station)

func activate(candidate: XJRuntimeState) -> bool:
	if not check(host._stage_candidate(candidate, host.store.catalog), "actual Main stages fixture world and ship geometry"): return false
	host._activate(candidate)
	host.set_process(false); host.set_physics_process(false)
	host._process(0.0)
	await frames(6)
	return true

func run() -> void:
	directory = OS.get_environment("XJ_CIVILIZATION_WORLD_V24_DIRECTORY").replace("\\", "/")
	if not check(DisplayServer.get_name() != "headless" and directory.is_absolute_path() and directory.contains("/jiaoben/tmp/civilization-world-v24/") and not directory.contains("..") and not FileAccess.file_exists(directory.path_join("progress.db")), "native suite requires fresh scoped SQLite and real renderer"):
		await finish(); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900)
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db")
	root.add_child(host)
	await frames(5)
	if not check(host.services_ready, "native client starts with all 54-system resources"): await finish(); return
	await host._command("new_world", "文明与舰队原生验收", 1, "")
	await settle()
	if not check(host.state != null, "native Main creates the expanded world"): await finish(); return
	host.set_process(false); host.set_physics_process(false)
	await show("civilizations")
	var before: String = state_signature()
	check(host.ui.body.find_child("CivilizationJoin", true, false) != null and host.ui.body.find_child("CivilizationJoin", true, false).disabled, "new neutral player sees admission requirements")
	await capture("civilizations-neutral")
	await click(host.ui.body.find_child("CivilizationCapital", true, false), "capital route from civilization screen")
	check(host.ui.page == "map" and host.ui.resource_chart.selected_sector == "sector_council_01", "capital navigation selects its real star-system destination")
	check(state_signature() == before, "browsing civilization and map creates no economic or saved-state mutations")
	root.size = Vector2i(3440, 1370); root.content_scale_factor = 1.0
	await show("map")
	var chart: Node = host.ui.resource_chart
	check(chart.sectors.size() == 54 and chart.links.size() == 73, "actual galaxy renders all 54 systems and 73 directed-connection records")
	await click(chart.find_child("ChartFitAll", true, false), "fit the whole expanded galaxy")
	await capture("galaxy-all")
	await choose(chart.sovereignty_filter, 2)
	var matched: int = 0
	for id: String in chart.sectors:
		if chart.matches_filter(id): matched += 1
	check(matched == 12, "actual civilization filter shows exactly twelve initial systems")
	await capture("galaxy-civilization")
	await choose(chart.sovereignty_filter, 1)
	matched = 0
	for id: String in chart.sectors:
		if chart.matches_filter(id): matched += 1
	check(matched == 18, "actual neutral filter shows eighteen systems")
	await capture("galaxy-neutral")
	root.size = Vector2i(1280, 720); root.content_scale_factor = 2.0
	await show("civilizations")
	var join: Button = host.ui.body.find_child("CivilizationJoin", true, false)
	await reveal(join)
	check(Rect2(Vector2.ZERO, host.ui.root.size).encloses(join.get_global_rect()), "200-percent compact civilization actions remain reachable")
	await capture("civilizations-1280-200")
	root.size = Vector2i(1440, 900); root.content_scale_factor = 1.0
	var candidate: XJRuntimeState = host.store.clone_state(host.state)
	var g := Gameplay.new(); g.setup(candidate, host.store.catalog)
	candidate.player().credit = 10000000
	for id: String in ["unlock_open_routes", "unlock_basic_industry", "unlock_tech_iii", "unlock_tech_ii", "unlock_combat_equipment", "unlock_cruiser_council_sentinel"]: g.grant_unlock(id)
	var affiliation: D.CivilizationStateDto = g.civilizations.membership()
	affiliation.has_faction_id = true; affiliation.faction_id = "faction_route_council"
	candidate.find("reputation_state", "faction_id", affiliation.faction_id).reputation = 6000
	var hull: D.ShipStateDto = g.inventory.create_ship("cruiser_council_sentinel", "station_council_01")
	candidate.player().controlled_ship_id = hull.ship_instance_id
	place(candidate, g, "anchor_council_01_station", "station_council_01")
	var warehouse: String = g.inventory.warehouse(g.station())
	g.inventory.grant(warehouse, "ore_ferrosilicate", 1000)
	var index: int = 0
	for module: String in ["module_thermal_sunline_iii", "module_drone_swarm_iii"]:
		var items: Array[String] = g.inventory.grant(warehouse, module, 1)
		check(g.act("fit_module", items[0], index + 1, "weapon").phase == T.ActionPhase.APPLIED, "fixture uses real compatible fitting " + module + " " + g.last_error)
		index += 1
	g.dispose()
	if not await activate(candidate): await finish(); return
	host.ui.civilization_selected_faction = "faction_route_council"
	await show("civilizations")
	await capture("civilizations-qualified")
	var quantity: SpinBox = host.ui.body.find_child("CivilizationDonationQuantity_donate_council_ore_ferrosilicate", true, false)
	if await click(quantity.get_line_edit(), "edit real donation quantity"):
		for down: bool in [true, false]:
			var select_all := InputEventKey.new()
			select_all.keycode = KEY_A; select_all.physical_keycode = KEY_A; select_all.ctrl_pressed = true; select_all.pressed = down
			host.get_viewport().push_input(select_all, true)
		for down: bool in [true, false]:
			var digit := InputEventKey.new()
			digit.keycode = KEY_3; digit.physical_keycode = KEY_3; digit.unicode = 51; digit.pressed = down
			host.get_viewport().push_input(digit, true)
		await frames(3)
		check(quantity.get_line_edit().text == "3", "native keyboard enters exact donation batch count")
		var before_ore: int = host.gameplay.inventory.count(warehouse, "ore_ferrosilicate", true)
		var before_rep: int = host.gameplay.economy.reputation("faction_route_council")
		if await click(host.ui.body.find_child("CivilizationDonate_donate_council_ore_ferrosilicate", true, false), "commit real material donation"):
			check(host.gameplay.inventory.count(warehouse, "ore_ferrosilicate", true) == before_ore - 300 and host.gameplay.economy.reputation("faction_route_council") == before_rep + 30, "actual UI donation consumes 300 ore and grants exactly 30 reputation")
	var war_button: Button = host.ui.body.find_child("CivilizationWar_war_council_01", true, false)
	if not await click(war_button, "accept actual council expedition"): await finish(); return
	check(host.gameplay.civilizations.active_war() != null, "real GUI dispatch creates the active war")
	await show("civilizations")
	await reveal(host.ui.body.find_child("CivilizationWarStatus", true, false))
	await capture("civilizations-war-orders")
	await settle()
	candidate = host.store.clone_state(host.state)
	g = Gameplay.new(); g.setup(candidate, host.store.catalog)
	place(candidate, g, "anchor_frontier_01_patrol")
	var rotation := Quaternion(Vector3.UP, PI)
	candidate.ship().quat_x = rotation.x; candidate.ship().quat_y = rotation.y; candidate.ship().quat_z = rotation.z; candidate.ship().quat_w = rotation.w
	g.dispose()
	if not await activate(candidate): await finish(); return
	await show("")
	check(host.world.sync_entities(), "actual battle scene projects all fleet actors")
	var civ: RefCounted = host.gameplay.civilizations
	var war: D.WarCampaignStateDto = civ.active_war()
	var allies: Array = civ.living_fleet(war, "ally")
	var defenders: Array = civ.living_fleet(war, "defender")
	check(allies.size() == 3 and defenders.size() == 4, "three visible allies and four declared defenders exist")
	for ally: D.NpcStateDto in allies:
		check(host.world.npcs.has(ally.npc_instance_id) and not host._enemy_target_valid(ally.npc_instance_id), "friend is rendered but excluded from hostile automatic targeting")
		check(str(host.world.npcs[ally.npc_instance_id].get_meta("visual_asset_version", "")) == "civilization-v1", "ally uses its actual civilization hull")
	check(host.ui.navigation_hud.contact_color("ally") != host.ui.navigation_hud.contact_color("npc"), "allied radar and projected indicators use a separate friendly color")
	var friend: D.NpcStateDto = allies[0]
	var hp: float = friend.shield + friend.armor + friend.hull
	host._weapon_hit(friend.npc_instance_id, Vector3(9999, 0, 0), host.world.npcs[friend.npc_instance_id].position, host.state.ship().ship_instance_id)
	host._flush_damage()
	check(is_equal_approx(hp, friend.shield + friend.armor + friend.hull), "production hit resolver blocks player friendly fire")
	host.world.projectiles.hit.connect(func(target: String, _damage: Vector3, _point: Vector3, owner: String):
		if impacts.size() < 500: impacts.append({"target": target, "owner": owner, "ally": host.gameplay.civilizations.friendly(owner)}))
	await capture("fleet-assembly")
	host.ui._select_target(defenders[0].npc_instance_id)
	host.combat_automation.lock_target(defenders[0].npc_instance_id)
	host.combat_automation.set_option("fire", true)
	host.combat_automation.set_option("seek", true)
	host.set_process(true); host.set_physics_process(true)
	var battle_start: int = Time.get_ticks_msec()
	var starting_tick: int = host.state.snapshot.meta.simulation_tick
	var captured_combat: bool = false
	var occupying: bool = false
	var logged_seconds: int = -10
	while Time.get_ticks_msec() - battle_start < 300000 and host.gameplay.civilizations.active_war() != null:
		await frames(6)
		if not captured_combat and impacts.size() > 2:
			await capture("fleet-combat")
			captured_combat = true
		if war.status == "occupying" and not occupying:
			occupying = true
			host.combat_automation.reset()
			await host._command("nav_approach", "encounter:encounter_frontier_01", 1, "")
		var elapsed: int = (Time.get_ticks_msec() - battle_start) / 1000
		if elapsed >= logged_seconds + 10:
			logged_seconds = elapsed
			print("CIV_BATTLE_PROGRESS seconds=", elapsed, " simulation_s=", (host.state.snapshot.meta.simulation_tick - starting_tick) / host.gameplay.rule("simulation_hz"), " fps=", Engine.get_frames_per_second(), " phase=", war.status, " allies=", civ.living_fleet(war, "ally").size(), " defenders=", civ.living_fleet(war, "defender").size(), " remaining=", war.capture_remaining_s, " hits=", impacts.size())
			print("CIV_PERFORMANCE process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, " physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	host.set_process(false); host.set_physics_process(false)
	check(captured_combat and impacts.any(func(hit: Dictionary): return bool(hit.ally)), "actual NPC ally projectiles damage hostile battle participants")
	check(war.status == "won" and host.gameplay.civilizations.owner("sector_frontier_01") == "faction_route_council", "real simulated fleet combat and occupation produce durable sovereignty")
	observations.append({"kind": "battle", "seconds": (Time.get_ticks_msec() - battle_start) / 1000.0, "impacts": impacts.size(), "ally_impacts": impacts.filter(func(hit: Dictionary): return bool(hit.ally)).size(), "status": war.status})
	await capture("fleet-outcome")
	await show("map")
	chart = host.ui.resource_chart
	chart.select_sector("sector_frontier_01")
	check(str(chart.sectors["sector_frontier_01"].get("owner_id", "")) == "faction_route_council" and chart.information.text.contains("航路议会"), "actual galaxy reflects the conquered system's owner")
	await capture("galaxy-conquered")
	for definition: Dictionary in host.store.catalog.rows("civilization_hull_defs"):
		var wrapper: CharacterBody3D = Factory.scene(definition.ship_id)
		check(wrapper != null and wrapper.has_node("VisualRoot/Model/PortFitting") and not Factory.geometry(definition.ship_id).is_empty(), "complete distinct hull model and collision contract " + str(definition.ship_id))
		if wrapper != null: wrapper.free()
	candidate = host.store.clone_state(host.state)
	g = Gameplay.new(); g.setup(candidate, host.store.catalog)
	hull = g.inventory.create_ship("battleship_forge_ironwall", "station_council_01")
	candidate.player().controlled_ship_id = hull.ship_instance_id
	place(candidate, g, "anchor_council_01_station", "station_council_01")
	g.dispose()
	if await activate(candidate):
		await show("station")
		check(host.hangar.ship_def_id == "battleship_forge_ironwall", "retained foreign-civilization owned hull remains usable in actual hangar")
		await capture("civilization-heavy-hangar")
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null
	await frames(5)
	await get_tree().create_timer(0.25).timeout
	var summary: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "directory": directory, "observations": observations}
	print("CIVILIZATION_WORLD_V24_FINAL_JSON ", JSON.stringify(summary))
	print("CIVILIZATION_WORLD_V24_RESULT ", summary.result, " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
