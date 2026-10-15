extends "ui_interaction_consistency.gd"
## Explicit UI boundary fixtures; this is not natural growth or combat acceptance.
const Dtos63 = preload("res://contracts/contract_dtos.gd")
const DroneAvailability63 = preload("res://runtime/ui/drone_availability.gd")
var capability_matrix: Array[Dictionary] = []
var actual_hulls: Dictionary = {}
var phase_observations: Array[Dictionary] = []

func _initialize() -> void:
	get_tree().set_meta("xj_ui_information_v63_diagnostic", true)
	create_timer(420.0).timeout.connect(func(): check(false, "information UI watchdog"); finish())
	_run.call_deferred()

func button_named(name: String) -> Button:
	return host.ui.body.find_child(name, true, false) as Button

func choose(name: String, message: String) -> bool:
	var ok: bool = await actual_click(button_named(name), message)
	await frames(6)
	return ok

func state_tables(tables: Array[String]) -> String:
	var result: Dictionary = {}
	for table: String in tables:
		var values: Array[String] = []
		for row: RefCounted in host.state.rows(table): values.append(JSON.stringify(InteractionCodec.new().encode_row(table, row)))
		values.sort(); result[table] = values
	return JSON.stringify(result)

func selected_list_case() -> void:
	for page: String in ["fitting", "missions", "ships", "ship_roles", "operations", "consignments", "hire", "expeditions"]:
		await show_interaction(page)
		var measured: int = 0
		for node: Node in descendants(host.ui.body):
			if not node.has_meta("info_list"): continue
			var current_rows: Array = node.get("rows")
			if current_rows.is_empty(): continue
			measured += 1
			var old_callback: Callable = Callable()
			if page in ["operations", "consignments", "hire"] and current_rows.size() > 1:
				for command: Node in current_rows[0].actions.get_children():
					if not command is Button: continue
					var connections: Array = command.get_signal_connection_list("pressed")
					if not connections.is_empty(): old_callback = connections[0].callable; break
			# A stage list sends the selected item's detail to its own column, so no
			# row opens an inline block there; a workbench list still opens exactly one.
			var external: bool = bool(node.get("details_external"))
			for row: Dictionary in current_rows:
				if not await actual_click(row.selector, "select actual " + page + " row " + str(row.id)): continue
				await frames(3)
				var visible_count: int = 0
				for candidate: Dictionary in current_rows:
					if candidate.details.is_visible_in_tree(): visible_count += 1
					check(candidate.details.visible == ((str(candidate.id) == str(row.id)) and not external), "old detail closes when real row changes " + page + " " + str(candidate.id))
				check(visible_count == (0 if external else 1) and str(node.get("selected_id")) == str(row.id) and row.selector.button_pressed, "one visible detail matches current selector " + page + " " + str(row.id))
				if external:
					check(host.ui.stage_detail.get_child_count() > 0, "stage selection fills the detail column " + page + " " + str(row.id))
				check(row.actions is HFlowContainer, "selected item actions share a horizontal flow " + page)
			if old_callback.is_valid():
				var count: int = request_events.size(); var before: String = resources()
				old_callback.call(); await frames(3)
				check(request_events.size() == count and resources() == before and host.ui.page == page, "hidden previous contract callback cannot submit or navigate " + page)
		check(measured > 0, "actual non-trading list exercised " + page)
		await inspect("information-selected-" + page, page)

func research_information_case() -> void:
	await show_interaction("research")
	check(host.ui.body.find_child("SpecializationQuantity", true, false) == null, "unselected specialization controls are not constructed on faction tab")
	for kind: String in ["faction", "specialization", "exploration", "facility"]:
		if not await choose("ResearchTab_" + kind, "open research category " + kind): continue
		var completed: Button = button_named("ResearchShowCompleted")
		if completed.is_visible_in_tree() and not completed.button_pressed: await choose("ResearchShowCompleted", "include completed catalog rows " + kind)
		var selectors: Array[Node] = host.ui.body.find_children("ResearchSelect_*", "Button", true, false)
		if not check(not selectors.is_empty(), "real catalog rows exist in research category " + kind): continue
		for selector: Node in selectors:
			await actual_click(selector as Button, "select research item " + str(selector.name)); await frames(3)
			var panel: Node = host.ui.body.find_child("ResearchDetail", true, false)
			var selected_id: String = str(selector.get_meta("target", ""))
			check(panel != null and host.ui.body.find_children("ResearchDetail", "VBoxContainer", true, false).size() == 1, "research has one constructed detail " + selected_id)
			var commands: int = 0
			for node: Node in descendants(panel):
				if not node is Button: continue
				var action: String = str(node.get_meta("action", ""))
				if action in ["research", "build_base", "exploration_research", "specialization_research"]:
					commands += 1
					check(str(node.get_meta("target", "")) == selected_id and node.get_parent() is HFlowContainer, "research command is only for selected item in horizontal actions " + selected_id)
					check(not node.disabled or not node.tooltip_text.is_empty(), "disabled selected research command explains its real blocker " + selected_id)
			check(commands == 1, "exactly one primary research or build action exists " + selected_id)
		await inspect("information-research-" + kind, "research")
	await choose("ResearchUnlocks", "expand qualification history")
	check(host.ui.body.find_child("ResearchQualifications", true, false).is_visible_in_tree(), "qualification history opens only on demand")
	await choose("ResearchUnlocks", "collapse qualification history")
	check(not host.ui.body.find_child("ResearchQualifications", true, false).is_visible_in_tree(), "qualification history really collapses")
	var history: Button = button_named("ResearchShowCompleted")
	if history.is_visible_in_tree() and history.button_pressed: await choose("ResearchShowCompleted", "hide completed research history")
	else: check(int(history.get_meta("count", -1)) == 0, "history control is hidden only when this category has no completed entries")
	for selector: Node in host.ui.body.find_children("ResearchSelect_*", "Button", true, false):
		var id: String = str(selector.get_meta("target", ""))
		var built: bool = false
		for row: RefCounted in host.state.rows("base_module_state"):
			if row.station_id == host.gameplay.station() and row.base_module_id == id: built = true
		check(not built, "completed facility is excluded by the real history filter " + id)
	# Remove only this presentation fixture's pre-granted design, then really
	# donate and invest. No test overwrites invested_points or creates progress.
	var spec: Dictionary = host.gameplay.definition("specialization_research_defs", "research_id", "spec_range")
	var unlock: RefCounted = host.state.find("unlock_state", "unlock_id", str(spec.reward_unlock_id))
	if unlock != null: host.state.remove("unlock_state", unlock)
	await research_case()
	await show_interaction("research")
	await choose("ResearchTab_specialization", "return to accumulated research")
	await choose("ResearchSelect_spec_range", "select real partial range research")
	var spin: SpinBox = host.ui.body.find_child("SpecializationQuantity", true, false) as SpinBox
	if not check(spin != null, "selected accumulated research exposes its actual quantity editor"): return
	await dirty_number(spin, "1")
	var available: int = host.gameplay.specializations.available()
	if await choose("SpecializationInvest_spec_range", "invest one real analysis point"):
		await settle_writer("partial specialization research")
		var progress: RefCounted = host.state.find("specialization_research_state", "research_id", "spec_range")
		check(progress != null and progress.invested_points == 1 and not progress.completed and host.gameplay.specializations.available() == available - 1, "actual partial investment retains progress and consumes exact evidence")
		check(str(request_events[-1].extra) == "0" and int(request_events[-1].quantity) == 1, "partial research carries the real expected previous progress and visible integer")

func industry_information_case() -> void:
	await show_interaction("industry")
	for kind: String in ["manufacture", "jobs", "demands", "recycle"]:
		if not await choose("IndustryTab_" + kind, "open real industry tab " + kind): continue
		check(host.ui.industry_tab == kind, "industry tab state follows actual click " + kind)
		var recipes: int = 0; var recycling: int = 0
		for node: Node in descendants(host.ui.body):
			if not node is Button: continue
			if str(node.get_meta("action", "")) == "manufacture": recipes += 1
			if str(node.get_meta("action", "")) == "recycle": recycling += 1
		check(recipes == 0 if kind != "manufacture" else recipes > 0, "manufacturing controls belong only to their actual category " + kind)
		check(recycling == 0 if kind != "recycle" else recycling > 0, "recycling controls belong only to their actual category " + kind)
		check(host.ui.body.find_children("DemandQuantity_*", "SpinBox", true, false).is_empty() if kind != "demands" else true, "demand editors are absent from other categories " + kind)
		check(host.ui.body.find_children("IndustryClaim_*", "Button", true, false).is_empty() if kind != "jobs" else true, "order claims are absent from other categories " + kind)
		await inspect("information-industry-" + kind, "industry")

func growth_information_case() -> void:
	var faction: String = "faction_route_council"
	host.ui.civilization_selected_faction = faction
	host.ui.set_meta("civilization_section", "progress")
	await show_interaction("civilizations")
	var growth: RefCounted = host.ui.civilization_panel.growth_panel
	var first: Dictionary = growth.selected_stage
	check(not first.is_empty() and not bool(host.gameplay.growth.progress(first).complete), "current growth is first actually incomplete criterion")
	var authority: String = state_tables(["growth_goal_state", "civilization_state", "rng_state"])
	if button_named("GrowthRoutesToggle") != null:
		check(not host.ui.body.find_child("GrowthRoutes", true, false).is_visible_in_tree(), "other growth routes default to collapsed")
		await choose("GrowthRoutesToggle", "open optional growth planning")
		var expected: Array[String] = []
		for candidate: Dictionary in host.gameplay.growth.stages(faction):
			if str(candidate.stage_id) != str(first.stage_id) and not bool(host.gameplay.growth.progress(candidate).complete): expected.append(str(candidate.stage_id))
		var preview: Label = host.ui.body.find_child("GrowthStage", true, false) as Label
		check(preview != null and preview.is_visible_in_tree() and int(preview.get_meta("route_count", 0)) == expected.size(), "planning exposes one labelled target with real remaining route count")
		check(host.ui.body.find_children("GrowthStage", "OptionButton", true, false).is_empty(), "planning does not construct an all-target dropdown")
		if preview != null:
			# Previous/next rebuild their controls. Always resolve a fresh button.
			for index: int in range(expected.size()):
				if button_named("GrowthPreviewPrevious").disabled: break
				await choose("GrowthPreviewPrevious", "return planning preview to first incomplete alternative")
			for index: int in range(expected.size()):
				preview = host.ui.body.find_child("GrowthStage", true, false) as Label
				var stage_id: String = str(preview.get_meta("stage_id", ""))
				var candidate: Dictionary = host.gameplay.definition("growth_stage_defs", "stage_id", stage_id)
				check(stage_id == expected[index] and stage_id != str(first.stage_id) and not bool(host.gameplay.growth.progress(candidate).complete), "single planning target excludes current/completed and follows real order " + stage_id)
				check(host.ui.body.find_children("GrowthStage", "Label", true, false).size() == 1 and host.ui.body.find_child("GrowthCurrentStage", true, false).text == str(first.display_name), "one preview leaves recommended objective unchanged " + stage_id)
				check(button_named("GrowthPreviewPrevious").disabled == (index == 0) and button_named("GrowthPreviewNext").disabled == (index == expected.size() - 1), "planning buttons expose actual sequence boundaries " + stage_id)
				if index + 1 < expected.size(): await choose("GrowthPreviewNext", "preview next incomplete planning target")
			for index: int in range(expected.size() - 2, -1, -1):
				await choose("GrowthPreviewPrevious", "preview previous incomplete planning target")
				preview = host.ui.body.find_child("GrowthStage", true, false) as Label
				check(str(preview.get_meta("stage_id", "")) == expected[index], "previous button returns to the actual prior target")
		await choose("GrowthRoutesToggle", "close optional growth planning")
		check(not host.ui.body.find_child("GrowthRoutes", true, false).is_visible_in_tree(), "other growth planning actually collapses")
	check(state_tables(["growth_goal_state", "civilization_state", "rng_state"]) == authority, "growth browsing does not persist fake progress or consume RNG")
	# Explicit membership boundary fixture; completion is read from its real DTO.
	var member: RefCounted = host.gameplay.civilizations.membership()
	var pending_join: Button = button_named("CivilizationJoin")
	var join_reason_before: String = pending_join.tooltip_text if pending_join != null else ""
	var join_generation: int = host.ui.business_generation
	check(pending_join != null and not join_reason_before.is_empty(), "Progress category exposes its actual declaration qualification before the membership boundary")
	member.has_faction_id = true; member.faction_id = faction
	await create_timer(0.3).timeout; host.ui.tick(0.0); await frames(6)
	var live_join_reason: String = host.gameplay.civilizations.join_reason(faction)
	check(is_instance_valid(pending_join) and host.ui.business_generation == join_generation and pending_join.disabled == (not live_join_reason.is_empty()) and pending_join.tooltip_text == live_join_reason and live_join_reason != join_reason_before, "Progress declaration qualification refreshes from live authority without rebuilding a page or constructing campaign status")
	check(host.ui.civilization_panel.join_note.text == live_join_reason and host.ui.civilization_panel.war_status == null, "Progress declaration note updates while the campaign category remains unconstructed")
	var next: Dictionary = host.ui.civilization_panel.growth_panel.selected_stage
	check(bool(host.gameplay.growth.progress(first).complete) and not next.is_empty() and str(next.stage_id) != str(first.stage_id) and not bool(host.gameplay.growth.progress(next).complete), "live authoritative completion advances current growth recommendation")
	check(host.ui.body.find_child("GrowthCurrentStage", true, false).text == str(next.display_name), "displayed current goal advances without opening a future dropdown")
	if check(button_named("GrowthHistoryToggle") != null, "completed criterion creates optional history"):
		check(not host.ui.body.find_child("GrowthHistory", true, false).is_visible_in_tree(), "completed growth history starts collapsed")
		await choose("GrowthHistoryToggle", "open actual completed growth history")
		check(host.ui.body.find_child("GrowthHistory", true, false).is_visible_in_tree(), "completed growth history opens")
		await choose("GrowthHistoryToggle", "close actual completed growth history")
		check(not host.ui.body.find_child("GrowthHistory", true, false).is_visible_in_tree(), "completed growth history closes")
	await inspect("information-growth-current", "civilizations")
	for section: String in ["contribution", "command", "campaign", "progress"]:
		await choose("CivilizationSection_" + section, "open actual civilization category " + section)
		check(str(host.ui.body.get_meta("civilization_section", "")) == section, "rendered civilization category matches state " + section)
		check((host.ui.body.find_child("GrowthPanel", true, false) != null) == (section == "progress"), "growth content exists only in its selected category " + section)
		check(host.ui.body.find_children("Commander*", "", true, false).is_empty() if section != "command" else true, "commander content is absent from unselected categories " + section)
		await inspect("information-civilization-" + section, "civilizations")

func warehouse_package_case() -> void:
	var warehouse: String = host.gameplay.inventory.warehouse(host.gameplay.station())
	var remote_station: String = ""
	for station: Dictionary in host.gameplay.rows("station_defs"):
		if str(station.station_id) != host.gameplay.station(): remote_station = str(station.station_id); break
	var remote: RefCounted = sealed_package(host.gameplay.inventory.warehouse(remote_station))
	if not check(remote != null, "production encounter source provides a schema-valid remote package"): return
	var remote_id: String = remote.package_id
	var cargo: String = host.gameplay.inventory.hold(host.state.ship(), T.ContainerKind.CARGO)
	for source: Dictionary in [{"container": warehouse, "tag": "station"}, {"container": cargo, "tag": "cargo"}]:
		var package: RefCounted = sealed_package(str(source.container))
		if not check(package != null, "production encounter source provides local sealed package " + str(source.tag)): continue
		var package_id: String = package.package_id
		var reward: Dictionary = host.gameplay.definition("salvage_reward_defs", "reward_id", str(package.reward_id))
		if str(source.tag) == "cargo":
			root.size = Vector2i(1280, 720); root.content_scale_size = Vector2i(640, 360)
			await frames(8)
		await show_interaction("salvage")
		check(host.ui.page == "warehouse", "legacy salvage route is the same real warehouse")
		var remote_row: Dictionary = host.ui.warehouse_panel.refs.rows_by_id.get(remote_id, {})
		check(not remote_row.is_empty() and remote_row.claim == null and remote_row.button == null, "remote sealed package remains read-only without claim or transfer")
		var row: Dictionary = host.ui.warehouse_panel.refs.rows_by_id.get(package_id, {})
		if not check(not row.is_empty() and row.claim is Button and row.claim.is_visible_in_tree(), "local sealed package has claim beside transfer " + str(source.tag)): continue
		check(str(row.claim.get_meta("action", "")) == "open_salvage" and str(row.claim.get_meta("target", "")) == package_id and not bool(row.claim.get_meta("uses_quantity", true)), "row claim binds exact sealed package and fixed quantity")
		# Keep a real old row alive outside the replaced panel to probe context.
		var old_row: Node = row.row
		var old_claim: Button = row.claim
		old_row.get_parent().remove_child(old_row); root.add_child(old_row); old_row.hide()
		host.ui.refresh_page(); await frames(10)
		row = host.ui.warehouse_panel.refs.rows_by_id.get(package_id, {})
		await inspect("information-warehouse-sealed-" + str(source.tag), "warehouse")
		var before_credit: int = host.state.player().credit
		if not await actual_click(row.claim, "claim actual sealed warehouse package " + str(source.tag)):
			old_row.queue_free(); continue
		await settle_writer("warehouse package claim")
		check(host.ui.toast.text.begins_with("战利品已领取"), "claim feedback uses the same action name as its warehouse button")
		# Identification commits a cloned state and activates it. Old DTOs are
		# immutable observations of the previous binding, never current receipts.
		package = host.state.find("salvage_package_state", "package_id", package_id)
		remote = host.state.find("salvage_package_state", "package_id", remote_id)
		check(package != null and package.status == "opened" and not package.has_host_container_id and str(package.reward_id) == str(reward.reward_id) and host.state.player().credit == before_credit + int(reward.credit_units), "activated local receipt opens once and pays exact frozen reward " + str(source.tag))
		var before: String = state_tables(["player_state", "salvage_package_state", "inventory_stack_state", "item_instance_state", "rng_state"])
		var request_count: int = request_events.size()
		old_claim.pressed.emit(); await frames(3)
		check(request_events.size() == request_count and state_tables(["player_state", "salvage_package_state", "inventory_stack_state", "item_instance_state", "rng_state"]) == before, "retained old warehouse claim cannot emit or pay after page replacement")
		old_row.queue_free()
		await host._command("open_salvage", package_id, 1, ""); await settle_writer("replayed package rejection")
		check(state_tables(["player_state", "salvage_package_state", "inventory_stack_state", "item_instance_state", "rng_state"]) == before, "replaying opened package cannot pay or grant second reward " + str(source.tag))
		remote = host.state.find("salvage_package_state", "package_id", remote_id)
		check(not host.ui.warehouse_panel.refs.rows_by_id.has(package_id) and remote != null and remote.status == "sealed", "opened local package disappears while current remote receipt remains sealed")
		var previous_snapshot: String = manual_snapshot()
		await host._command("save", "0", 1, "manual"); await settle_writer("schema-validated package manual snapshot")
		check(not manual_snapshot().is_empty() and manual_snapshot() != previous_snapshot, "real clone and SQLite save validate complete sealed/opened package state " + str(source.tag))
		if str(source.tag) == "cargo":
			check(host.ui.root.size.is_equal_approx(Vector2(640, 360)), "cargo claim uses the actual 200 percent logical viewport")
			root.size = Vector2i(1440, 900); root.content_scale_size = root.size
			await frames(8)

func manual_snapshot() -> String:
	for slot: Dictionary in host.store.list_slots():
		if str(slot.world_id) == host.state.world_id and slot.slot_kind == "manual" and int(slot.slot_index) == 0: return str(slot.current_snapshot_id)
	return ""

func sealed_package(container: String) -> RefCounted:
	# The UI diagnostic intentionally has no live NPCs. Declare a distinct dead
	# actor from a frozen ambient loot prototype for each source. The production
	# encounter service chooses/seals the reward and immutable source identity.
	var spawn: Dictionary = {}
	for definition: Dictionary in host.gameplay.rows("npc_spawn_defs"):
		if definition.occurrence_mode != "ambient" or not bool(definition.loot_enabled): continue
		if host.gameplay.definition("npc_salvage_defs", "npc_def_id", str(definition.npc_id)).is_empty(): continue
		spawn = definition; break
	if not check(not spawn.is_empty(), "package fixture has a frozen ambient NPC and salvage mapping"): return null
	var npc: RefCounted = Dtos63.NpcStateDto.new()
	npc.npc_instance_id = host.gameplay.id("information_salvage_source")
	npc.spawn_id = str(spawn.spawn_id); npc.sector_id = str(spawn.sector_id); npc.generation = 0
	npc.alive = false; npc.behavior_phase = T.NpcPhase.DEAD
	var anchor: Dictionary = host.gameplay.definition("anchor_defs", "anchor_id", str(spawn.anchor_id))
	npc.pos_x = anchor.x_m; npc.pos_y = anchor.y_m; npc.pos_z = anchor.z_m
	if not check(host.state.add("npc_state", npc) and host.gameplay.assign_anchor_site("npc", npc.npc_instance_id, str(spawn.anchor_id)), "declared dead source NPC has valid frozen prototype and spatial ownership"): return null
	var spawned: bool = host.gameplay.encounters.on_destroy(npc)
	npc.loot_claimed = spawned
	var package: RefCounted = null
	for candidate: RefCounted in host.state.rows("salvage_package_state"):
		if candidate.source_npc_instance_id == npc.npc_instance_id and candidate.source_generation == npc.generation: package = candidate; break
	if not check(spawned and package != null, "actual encounter service seals one unique source reward"):
		host.gameplay.remove_npc(npc); return null
	var wreck: String = package.host_container_id
	# Container placement is the declared UI boundary fixture, not a claim.
	# Both ownership and capacity are checked before showing the real claim UI.
	if not check(host.gameplay.encounters.can_hold(container, str(package.package_def_id)), "local or remote fixture container can hold the sealed package"):
		host.gameplay.remove_npc(npc); return null
	package.host_container_id = container
	host.gameplay.inventory.remove_empty_wreck(wreck)
	host.gameplay.remove_npc(npc)
	return package

func drone_capability_case() -> void:
	for definition: Dictionary in host.gameplay.rows("ship_defs"):
		var candidate: RefCounted = Dtos63.ShipStateDto.new(); candidate.ship_def_id = str(definition.ship_id)
		var actual: Dictionary = DroneAvailability63.capabilities(host.gameplay, candidate)
		var expected: Dictionary = {"attack": false, "repair": false, "recon": false}
		var slots: Array[String] = []
		for slot: Dictionary in host.gameplay.rows("ship_slot_defs"):
			if str(slot.ship_id) == str(definition.ship_id): slots.append(str(slot.slot_type))
		for permission: Dictionary in host.gameplay.rows("ship_weapon_permissions"):
			if str(permission.ship_id) == str(definition.ship_id) and permission.family_id == "drone" and int(permission.max_installed) > 0 and slots.has("weapon"):
				for module: Dictionary in host.gameplay.rows("drone_defs"):
					if int(host.gameplay.weapon_profile(str(module.module_id)).get("size_class", 999)) <= int(permission.max_size): expected.attack = true
		for permission: Dictionary in host.gameplay.rows("ship_auxiliary_permissions"):
			if str(permission.ship_id) == str(definition.ship_id) and int(permission.max_installed) > 0 and slots.has("work"): expected[str(permission.role_kind)] = true
		check(actual == expected, "frozen slot/weapon/auxiliary permissions match UI capabilities " + str(definition.ship_id))
		capability_matrix.append({"ship_id": definition.ship_id, "expected": expected, "actual": actual})
	check(capability_matrix.size() == 18, "capability matrix covers all 18 player hull definitions")
	var station: String = host.gameplay.station()
	for hull_id: String in ["shuttle_swift", "frigate_lantern", "cruiser_horizon"]:
		var hull: RefCounted = host.gameplay.inventory.create_ship(hull_id, station)
		if not check(hull != null, "actual distinct fixture hull created with real containers " + hull_id): continue
		actual_hulls[hull_id] = hull.ship_instance_id
		await host._command("switch_ship", hull.ship_instance_id, 1, ""); await settle_writer("real controlled hull " + hull_id)
		check(host.state.ship().ship_instance_id == hull.ship_instance_id, "real switch controls requested distinct ship " + hull_id)
		host._process(0.0)
		if hull_id == "shuttle_swift":
			await show_interaction("fitting")
			check(not host.ui._related_entries().any(func(entry: Dictionary): return str(entry.id) == "drones"), "unsupported actual hull has no related drone entry")
			host.ui.show_page("drones"); await frames(6)
			check(host.ui.page == "fitting" and button_named("DroneOrder_attack") == null, "unsupported legacy direct drone route redirects to actual fitting")
			await host._command("undock", "", 1, ""); await settle_writer("real unsupported hull undock"); host._process(0.0)
			host.ui.show_page("drones"); await frames(6)
			check(host.ui.page.is_empty() and host.ui.body.find_children("DroneReplenish_*", "Button", true, false).is_empty(), "unsupported flight direct route returns to real HUD without replenishment")
			var has_drone_service: bool = false
			for record: Dictionary in host.ui._service_pages(false):
				if str(record.id) == "drones": has_drone_service = true
			check(not has_drone_service, "unsupported real flying hull has no drone service entry")
			phase_observations.append({"ship_id": hull_id, "instance": hull.ship_instance_id, "phase": "flight", "attack": false})
			await return_to_station(station, hull)
			continue
		var warehouse: String = host.gameplay.inventory.warehouse(station)
		var module_id: String = "module_aux_recon_i" if hull_id == "frigate_lantern" else "module_drone_swarm_i"
		var granted: Array = host.gameplay.inventory.grant(warehouse, module_id, 1)
		var item_id: String = str(granted[0])
		await host._command("fit_module", item_id, 1, "work:0" if hull_id == "frigate_lantern" else "weapon:0"); await settle_writer("legal drone equipment " + hull_id)
		if not check(not DroneAvailability63.equipped(host.gameplay).is_empty(), "real mounted SLOT is accepted for active hull " + hull_id): continue
		var bay: RefCounted = host.gameplay.drone_control.bay(item_id)
		bay.stock_units -= 1; bay.lost_units += 1; bay.revision += 1
		await show_interaction("drones")
		check(button_named("DroneOrder_attack") == null and host.ui.body.find_children("DroneOrder_*", "Button", true, false).is_empty() and host.ui.body.find_children("AuxiliaryLaunch_*", "Button", true, false).is_empty(), "station view constructs no combat or launch commands " + hull_id)
		check(button_named("DroneReplenish_" + item_id) != null, "station view offers replenishment only for missing mounted stock " + hull_id)
		var replenish: Button = button_named("DroneReplenish_" + item_id)
		var replenish_reason: String = host.gameplay.drone_control.replenish_reason(item_id, 1, str(bay.revision))
		check(replenish != null and replenish.disabled == (not replenish_reason.is_empty()) and (replenish_reason.is_empty() or replenish.tooltip_text.contains(replenish_reason)), "station replenishment eligibility and blocker match actual service " + hull_id)
		await inspect("information-drones-station-" + hull_id, "drones")
		await host._command("undock", "", 1, ""); await settle_writer("real undock " + hull_id); host._process(0.0)
		await show_interaction("drones")
		check(host.state.ship().status == T.ShipStatus.FLYING and host.ui.body.find_children("DroneReplenish_*", "Button", true, false).is_empty(), "flight view contains no station replenishment " + hull_id)
		check((button_named("DroneOrder_attack") != null) == (hull_id == "cruiser_horizon"), "attack command requires actual attack bay rather than merely drone-capable hull " + hull_id)
		if hull_id == "frigate_lantern": check(not host.ui.body.find_children("AuxiliaryLaunch_*", "Button", true, false).is_empty(), "recon-only real ship exposes its actual scout launch")
		var services: Array[String] = []
		for record: Dictionary in host.ui._service_pages(false): services.append(str(record.id))
		for blocked: String in ["market", "warehouse", "industry", "research", "salvage"]: check(not services.has(blocked), "flight service strip omits dock-only service " + blocked)
		host.ui.show_page("fitting"); await frames(6)
		check(host.ui.page == "fitting_analysis" and host.ui.body.find_children("BusinessQuantity_*", "SpinBox", true, false).is_empty(), "flight fitting route opens analysis without installation editors")
		await show_interaction("drones"); await inspect("information-drones-flight-" + hull_id, "drones")
		phase_observations.append({"ship_id": hull_id, "instance": hull.ship_instance_id, "phase": "flight", "attack": button_named("DroneOrder_attack") != null})
		await return_to_station(station, hull)

func return_to_station(station: String, hull: RefCounted) -> void:
	# Explicit return-pose fixture; docking itself uses the unchanged real gate.
	var anchor: Dictionary = host.gameplay.definition("anchor_defs", "anchor_id", str(host.gameplay.definition("station_defs", "station_id", station).station_anchor_id))
	hull.pos_x = anchor.x_m; hull.pos_y = anchor.y_m; hull.pos_z = anchor.z_m
	hull.vel_x = 0; hull.vel_y = 0; hull.vel_z = 0
	host.gameplay.assign_anchor_site("ship", hull.ship_instance_id, str(anchor.anchor_id))
	await host._command("dock", station, 1, ""); await settle_writer("real return dock " + str(hull.ship_def_id))
	check(host.state.ship().status == T.ShipStatus.DOCKED, "real dock permits next hull phase without faking docked status")

func report_information_case() -> void:
	await show_interaction("reports")
	var list: Node = host.ui.body.find_child("ReportList", true, false)
	if not check(list != null and list.get("rows").size() >= 3, "three actual undock/return records populate the report list"): return
	var current_rows: Array = list.get("rows")
	var latest: String = str(host.gameplay.telemetry.latest().sequence)
	check(str(list.get("selected_id")) == latest, "latest real flight is selected by default")
	for row: Dictionary in current_rows:
		check(row.row.visible == (str(row.id) == latest) and str(row.row.get_meta("report_sequence", "")) == str(row.id), "old flight summaries default to hidden with actual sequence identity")
	for export: String in ["ReportExportCSV", "ReportExportJSON"]:
		var button: Button = button_named(export)
		check(button != null and button.is_visible_in_tree() and not button.disabled and str(button.get_meta("action", "")) == "export_flight_report", "real local report export remains available " + export)
	await choose("ReportHistoryToggle", "expand previous flight summaries")
	for row: Dictionary in current_rows: check(row.row.visible, "report history disclosure exposes each real summary")
	await actual_click(current_rows[-1].selector, "select actual previous flight"); await frames(3)
	var open_count: int = 0
	for row: Dictionary in current_rows:
		if row.details.is_visible_in_tree(): open_count += 1
	check(open_count == 1 and str(list.get("selected_id")) == str(current_rows[-1].id), "history selection still expands only one real flight")
	await choose("ReportHistoryToggle", "collapse previous flight summaries")
	check(str(list.get("selected_id")) == latest, "closing history restores latest visible flight detail")
	current_rows[-1].selector.pressed.emit()
	check(str(list.get("selected_id")) == latest, "hidden old history selector cannot replace current visible flight")
	var statistics: Control = host.ui.body.find_child("ReportStatistics", true, false)
	if check(statistics != null and not statistics.is_visible_in_tree(), "long activity and material statistics start collapsed"):
		await choose("ReportStatisticsToggle", "expand report activity and material statistics")
		check(statistics.is_visible_in_tree() and host.ui.body.find_child("ReportMeasurements", true, false).is_visible_in_tree() and host.ui.body.find_child("ReportRecentActivities", true, false).is_visible_in_tree(), "statistics disclosure exposes actual measurements and activities")
		await choose("ReportStatisticsToggle", "collapse report activity and material statistics")
		check(not statistics.is_visible_in_tree(), "long report statistics really collapse")
	await inspect("information-reports-current", "reports")
	host.ui.frontier_selected_id = ""; await show_interaction("frontier")
	var target: String = host.ui.frontier_selected_id
	if target.is_empty():
		check(host.ui.body.find_child("FrontierEmptyState", true, false) != null, "unowned frontier has explicit empty state instead of default neutral governance")
		await choose("FrontierCivilizationsEntry", "open eligible frontier campaign information")
		check(host.ui.page == "civilizations" and str(host.ui.get_meta("civilization_section", "")) == "campaign", "frontier empty-state route opens the actual campaign category")
	else:
		check(host.gameplay.civilizations.owner(target) == host.gameplay.civilizations.allegiance() or host.gameplay.frontier.campaign(target) != null, "default frontier target is owned territory or actual campaign")

func _run() -> void:
	directory = OS.get_environment("XJ_UI_INFORMATION_V63_DIRECTORY").replace("\\", "/")
	if not check(fresh_external_directory("ui_information_v63.gd", "ui-information-v63"), "fresh scoped v63 database required"): await finish(); return
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440, 900); root.content_scale_size = root.size
	host = Main.new(); host.progress_database_path = directory.path_join("progress.db"); root.add_child(host); await frames(8)
	if not check(host.services_ready and host.state == null, "real Main initializes without opening personal save"): await finish(); return
	await host._command("new_world", "信息分层专项", 1, ""); await settle_writer("fresh information world")
	label = "information"; await fixture()
	host.set_process(false); host.set_physics_process(false)
	host.ui.requested.connect(func(action: String, target: String, amount: int, extra: String): request_events.append({"action": action, "target": target, "quantity": amount, "extra": extra}))
	await selected_list_case(); await research_information_case(); await industry_information_case()
	await growth_information_case(); await warehouse_package_case(); await drone_capability_case()
	await report_information_case()
	await finish()

func finish() -> void:
	if finishing: return
	finishing = true
	if is_instance_valid(host): host.queue_free()
	host = null; await frames(6)
	var result: Dictionary = {"result": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures.size(), "failure_labels": failures, "captures": captures, "native": DisplayServer.get_name() != "headless", "interaction_checks": interaction_checks, "capability_matrix": capability_matrix, "actual_hulls": actual_hulls, "phase_observations": phase_observations, "observations": observations, "findings": findings, "fixtures": ["fresh UUID Main", "credit and all catalog unlocks", "named local inventory", "distinct frozen dead NPC sources with production encounter reward sealing and declared container placement", "membership DTO completion boundary", "three distinct normal-owned hulls via real inventory creation", "legal fit/switch/undock/dock commands", "one missing drone stock unit", "station return position only"], "scope": "selected information hierarchy, category and phase eligibility, package replay rejection and full snapshot save; not natural progression, active combat, balance or performance acceptance"}
	var file: FileAccess = FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t") + "\n"); file.close()
	print("UI_INFORMATION_V63_RESULT ", result.result, " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
