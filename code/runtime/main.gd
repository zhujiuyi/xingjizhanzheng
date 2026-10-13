extends Node3D
## Local host authority; UI and scenes only submit intent/read typed state.
const Types = preload("res://contracts/contract_types.gd")
const Dtos = preload("res://contracts/contract_dtos.gd")
const CombatAutomation = preload("res://runtime/combat_automation.gd")
var progress_database_path: String = "user://database/progress.db"
var store: XJGameStore
var state: XJRuntimeState
var gameplay: RefCounted
var world: XJSector
var staged_world: XJSector
var staged_gameplay: RefCounted
var camera: XJCameraRig
var ui: XJUI
var travel: XJTravel
var local_navigation: XJLocalNavigation
var source_goal: Dictionary = {}
var auto_fire_target: String = ""
var combat_automation: RefCounted
var navigation_generation: int = 0
var busy: bool = false
var services_ready: bool = false
var observing: bool = false
var fire_held: bool = false
var last_destroyed_ship: String = ""
var pending_damage: Dictionary = {}
var player_damage_targets: Dictionary = {}
var owned_damage_targets: Dictionary = {}
var deferred_save: Dictionary = {}
var autosave_elapsed: float = 0.0
var auto_slot: int = 0
var brake_hold: Dictionary = {}
var preferences: Dictionary = {}
var presentation: XJPresentation
var last_error: String = ""
var save_wait_elapsed: float = 0.0
var previous_page: String = "title"
var weapon_errors: Dictionary = {}
var flight_look := XJFlightLook.new()
var pointer_mode: bool = true
var hangar: XJStationHangar
var presentation_stage: String = ""
var warp_visual: XJWarpVisual
var pointer_pick_pending: bool = false
var pointer_pick_position: Vector2 = Vector2.ZERO
var pointer_drag_pressed: bool = false
var pointer_dragged: bool = false
var pointer_drag_origin: Vector2 = Vector2.ZERO
var local_boundary_warning_s: float = 0.0
# This is a screen-space click tolerance, not a ship or combat balance value.
const POINTER_DRAG_TOLERANCE_PX: float = 6.0

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	for v18_contract: Dictionary in [
		{"flag":"--xj-verify-natural-campaign-v58","file":"natural_campaign_v58.gd","prefix":"natural-campaign-v58","env":"XJ_NATURAL_CAMPAIGN_V58","meta":"xj_natural_campaign_v58_diagnostic"},
		{"flag":"--xj-verify-natural-hull-v57","file":"natural_hull_v57.gd","prefix":"natural-hull-v57","env":"XJ_NATURAL_HULL_V57","meta":"xj_natural_hull_v57_diagnostic"},
		{"flag":"--xj-verify-natural-war-v56","file":"natural_war_v56.gd","prefix":"natural-war-v56","env":"XJ_NATURAL_WAR_V56","meta":"xj_natural_war_v56_diagnostic"},
		{"flag":"--xj-verify-natural-command-v55","file":"natural_command_v55.gd","prefix":"natural-command-v55","env":"XJ_NATURAL_COMMAND_V55","meta":"xj_natural_command_v55_diagnostic"},
		{"flag":"--xj-verify-natural-logistics-v54","file":"natural_logistics_v54.gd","prefix":"natural-logistics-v54","env":"XJ_NATURAL_LOGISTICS_V54","meta":"xj_natural_logistics_v54_diagnostic"},
		{"flag":"--xj-verify-natural-rescue-v53","file":"natural_rescue_v53.gd","prefix":"natural-rescue-v53","env":"XJ_NATURAL_RESCUE_V53","meta":"xj_natural_rescue_v53_diagnostic"},
		{"flag":"--xj-verify-natural-research-v52","file":"natural_research_v52.gd","prefix":"natural-research-v52","env":"XJ_NATURAL_RESEARCH_V52","meta":"xj_natural_research_v52_diagnostic"},
		{"flag":"--xj-verify-natural-scout-v51","file":"natural_scout_v51.gd","prefix":"natural-scout-v51","env":"XJ_NATURAL_SCOUT_V51","meta":"xj_natural_scout_v51_diagnostic"},
		{"flag":"--xj-verify-natural-rank-v50","file":"natural_rank_v50.gd","prefix":"natural-rank-v50","env":"XJ_NATURAL_RANK_V50","meta":"xj_natural_rank_v50_diagnostic"},
		{"flag":"--xj-verify-growth-world-v50","file":"growth_world_v50.gd","prefix":"growth-world-v50","env":"XJ_GROWTH_WORLD_V50","meta":"xj_growth_world_v50_diagnostic"},
		{"flag":"--xj-verify-natural-mid-v50","file":"natural_mid_v50.gd","prefix":"natural-mid-v50","env":"XJ_NATURAL_MID_V50","meta":"xj_natural_mid_v50_diagnostic"},
		{"flag":"--xj-verify-march-routes-v50","file":"march_routes_v50.gd","prefix":"march-routes-v50","env":"XJ_MARCH_ROUTES_V50","meta":"xj_march_routes_v50_diagnostic"},
		{"flag":"--xj-verify-march-upgrade-v49","file":"march_upgrade_v49.gd","prefix":"march-upgrade-v49","env":"XJ_MARCH_UPGRADE_V49","meta":"xj_march_upgrade_v49_diagnostic"},
		{"flag":"--xj-verify-march-world-v49","file":"march_world_v49.gd","prefix":"march-world-v49","env":"XJ_MARCH_WORLD_V49","meta":"xj_march_world_v49_diagnostic"},
		{"flag":"--xj-verify-march-v49","file":"march_v49.gd","prefix":"march-v49","env":"XJ_MARCH_V49","meta":"xj_march_v49_diagnostic"},
		{"flag":"--xj-verify-retention-v48","file":"retention_v48.gd","prefix":"retention-v48","env":"XJ_RETENTION_V48","meta":"xj_retention_v48_diagnostic"},
		{"flag":"--xj-verify-market-cache-v47","file":"market_cache_v47.gd","prefix":"market-cache-v47","env":"XJ_MARKET_CACHE_V47","meta":"xj_market_cache_v47_diagnostic"},
		{"flag":"--xj-verify-natural-recovery-v45","file":"natural_recovery_v45.gd","prefix":"natural-recovery-v45","env":"XJ_NATURAL_RECOVERY_V45","meta":"xj_natural_recovery_v45_diagnostic"},
		{"flag":"--xj-verify-natural-growth-v45","file":"natural_growth_v45.gd","prefix":"natural-growth-v45","env":"XJ_NATURAL_GROWTH_V45","meta":"xj_natural_growth_v45_diagnostic"},
		{"flag":"--xj-verify-legacy-chain-v44","file":"legacy_chain_v44.gd","prefix":"legacy-chain-v44","env":"XJ_LEGACY_CHAIN_V44","meta":"xj_legacy_chain_v44_diagnostic"},
		{"flag":"--xj-verify-owned-combat-world-v43","file":"owned_combat_world_v43.gd","prefix":"owned-combat-world-v43","env":"XJ_OWNED_COMBAT_WORLD_V43","meta":"xj_owned_combat_world_v43_diagnostic"},
		{"flag":"--xj-verify-auxiliary-boundaries-v43","file":"auxiliary_boundaries_v43.gd","prefix":"auxiliary-boundaries-v43","env":"XJ_AUXILIARY_BOUNDARIES_V43","meta":"xj_auxiliary_boundaries_v43_diagnostic"},
		{"flag":"--xj-verify-fleet-integration-v42","file":"fleet_integration_v42.gd","prefix":"fleet-integration-v42","env":"XJ_FLEET_INTEGRATION_V42","meta":"xj_fleet_integration_v42_diagnostic"},
		{"flag":"--xj-verify-fleet-upgrade-v42","file":"fleet_upgrade_v42.gd","prefix":"fleet-upgrade-v42","env":"XJ_FLEET_UPGRADE_V42","meta":"xj_fleet_upgrade_v42_diagnostic"},
		{"flag":"--xj-verify-auxiliary-world-v41","file":"auxiliary_world_v41.gd","prefix":"auxiliary-world-v41","env":"XJ_AUXILIARY_WORLD_V41","meta":"xj_auxiliary_world_v41_diagnostic"},
		{"flag":"--xj-verify-owned-fleet-v40","file":"owned_fleet_v40.gd","prefix":"owned-fleet-v40","env":"XJ_OWNED_FLEET_V40","meta":"xj_owned_fleet_v40_diagnostic"},
		{"flag":"--xj-verify-owned-fleet-travel-v40","file":"owned_fleet_travel_v40.gd","prefix":"owned-fleet-travel-v40","env":"XJ_OWNED_FLEET_TRAVEL_V40","meta":"xj_owned_fleet_travel_v40_diagnostic"},
		{"flag":"--xj-verify-owned-fleet-world-v40","file":"owned_fleet_world_v40.gd","prefix":"owned-fleet-world-v40","env":"XJ_OWNED_FLEET_WORLD_V40","meta":"xj_owned_fleet_world_v40_diagnostic"},
		{"flag":"--xj-verify-measurements-v39","file":"measurements_v39.gd","prefix":"measurements-v39","env":"XJ_MEASUREMENTS_V39","meta":"xj_measurements_v39_diagnostic"},
		{"flag":"--xj-verify-blockades-world-v39","file":"blockades_world_v39.gd","prefix":"blockades-world-v39","env":"XJ_BLOCKADES_WORLD_V39","meta":"xj_blockades_world_v39_diagnostic"},
		{"flag":"--xj-verify-scenarios-upgrade-v39","file":"scenarios_upgrade_v39.gd","prefix":"scenarios-upgrade-v39","env":"XJ_SCENARIOS_UPGRADE_V39","meta":"xj_scenarios_upgrade_v39_diagnostic"},
		{"flag":"--xj-verify-scenarios-world-v39","file":"scenarios_world_v39.gd","prefix":"scenarios-world-v39","env":"XJ_SCENARIOS_WORLD_V39","meta":"xj_scenarios_world_v39_diagnostic"},
		{"flag":"--xj-verify-scenarios-v39","file":"scenarios_v39.gd","prefix":"scenarios-v39","env":"XJ_SCENARIOS_V39","meta":"xj_scenarios_v39_diagnostic"},
		{"flag":"--xj-verify-campaign-extension-v38","file":"campaign_extension_v38.gd","prefix":"campaign-extension-v38","env":"XJ_CAMPAIGN_EXTENSION_V38","meta":"xj_campaign_extension_v38_diagnostic"},
		{"flag":"--xj-verify-campaign-world-v37","file":"campaign_world_v37.gd","prefix":"campaign-world-v37","env":"XJ_CAMPAIGN_WORLD_V37","meta":"xj_campaign_world_v37_diagnostic"},
		{"flag":"--xj-verify-campaign-v37","file":"campaign_v37.gd","prefix":"campaign-v37","env":"XJ_CAMPAIGN_V37","meta":"xj_campaign_v37_diagnostic"},
		{"flag":"--xj-verify-situational-v36","file":"situational_v36.gd","prefix":"situational-v36","env":"XJ_SITUATIONAL_V36","meta":"xj_situational_v36_diagnostic"},
		{"flag":"--xj-verify-situational-world-v36","file":"situational_world_v36.gd","prefix":"situational-world-v36","env":"XJ_SITUATIONAL_WORLD_V36","meta":"xj_situational_world_v36_diagnostic"},
		{"flag":"--xj-verify-hire-v35","file":"hire_v35.gd","prefix":"hire-v35","env":"XJ_HIRE_V35","meta":"xj_hire_v35_diagnostic"},
		{"flag":"--xj-verify-hire-world-v35","file":"hire_world_v35.gd","prefix":"hire-world-v35","env":"XJ_HIRE_WORLD_V35","meta":"xj_hire_world_v35_diagnostic"},
		{"flag":"--xj-verify-hire-travel-world-v35","file":"hire_travel_world_v35.gd","prefix":"hire-travel-world-v35","env":"XJ_HIRE_TRAVEL_WORLD_V35","meta":"xj_hire_travel_world_v35_diagnostic"},
		{"flag":"--xj-verify-frontier-v34","file":"frontier_v34.gd","prefix":"frontier-v34","env":"XJ_FRONTIER_V34","meta":"xj_frontier_v34_diagnostic"},
		{"flag":"--xj-verify-frontier-governance-world-v34","file":"frontier_governance_world_v34.gd","prefix":"frontier-governance-world-v34","env":"XJ_FRONTIER_GOVERNANCE_WORLD_V34","meta":"xj_frontier_governance_world_v34_diagnostic"},
		{"flag":"--xj-verify-frontier-world-v34","file":"frontier_world_v34.gd","prefix":"frontier-world-v34","env":"XJ_FRONTIER_WORLD_V34","meta":"xj_frontier_world_v34_diagnostic"},
		{"flag":"--xj-verify-honors-v33","file":"honors_v33.gd","prefix":"honors-v33","env":"XJ_HONORS_V33","meta":"xj_honors_v33_diagnostic"},
		{"flag":"--xj-verify-honors-world-v33","file":"honors_world_v33.gd","prefix":"honors-world-v33","env":"XJ_HONORS_WORLD_V33","meta":"xj_honors_world_v33_diagnostic"},
		{"flag":"--xj-verify-roles-v32","file":"roles_v32.gd","prefix":"roles-v32","env":"XJ_ROLES_V32","meta":"xj_roles_v32_diagnostic"},
		{"flag":"--xj-verify-roles-world-v32","file":"roles_world_v32.gd","prefix":"roles-world-v32","env":"XJ_ROLES_WORLD_V32","meta":"xj_roles_world_v32_diagnostic"},
		{"flag":"--xj-verify-fitting-v31","file":"fitting_v31.gd","prefix":"fitting-v31","env":"XJ_FITTING_V31","meta":"xj_fitting_v31_diagnostic"},
		{"flag":"--xj-verify-fitting-world-v31","file":"fitting_world_v31.gd","prefix":"fitting-world-v31","env":"XJ_FITTING_WORLD_V31","meta":"xj_fitting_world_v31_diagnostic"},
		{"flag":"--xj-verify-operations-v30","file":"operations_v30.gd","prefix":"operations-v30","env":"XJ_OPERATIONS_V30","meta":"xj_operations_v30_diagnostic"},
		{"flag":"--xj-verify-operations-world-v30","file":"operations_world_v30.gd","prefix":"operations-world-v30","env":"XJ_OPERATIONS_WORLD_V30","meta":"xj_operations_world_v30_diagnostic"},
		{"flag": "--xj-verify-exploration-world-v27", "file": "exploration_world_v27.gd", "prefix": "exploration-world-v27", "env": "XJ_EXPLORATION_WORLD_V27", "meta": "xj_exploration_world_v27_diagnostic"},
		{"flag": "--xj-verify-exploration-v27", "file": "exploration_v27.gd", "prefix": "exploration-v27", "env": "XJ_EXPLORATION_V27", "meta": "xj_exploration_v27_diagnostic"},
		{"flag": "--xj-verify-mobile-belts-v28", "file": "mobile_belts_v28.gd", "prefix": "mobile-belts-v28", "env": "XJ_MOBILE_BELTS_V28", "meta": "xj_mobile_belts_v28_diagnostic"},
		{"flag": "--xj-verify-mobile-belts-world-v28", "file": "mobile_belts_world_v28.gd", "prefix": "mobile-belts-world-v28", "env": "XJ_MOBILE_BELTS_WORLD_V28", "meta": "xj_mobile_belts_world_v28_diagnostic"},
		{"flag":"--xj-verify-tactics-v29","file":"tactics_v29.gd","prefix":"tactics-v29","env":"XJ_TACTICS_V29","meta":"xj_tactics_v29_diagnostic"},
		{"flag":"--xj-verify-tactics-world-v29","file":"tactics_world_v29.gd","prefix":"tactics-world-v29","env":"XJ_TACTICS_WORLD_V29","meta":"xj_tactics_world_v29_diagnostic"},
		{"flag": "--xj-verify-resource-intel-world-v26", "file": "resource_intel_world_v26.gd", "prefix": "resource-intel-world-v26", "env": "XJ_RESOURCE_INTEL_WORLD_V26", "meta": "xj_resource_intel_world_v26_diagnostic"},
		{"flag": "--xj-verify-resource-intel-v26", "file": "resource_intel_v26.gd", "prefix": "resource-intel-v26", "env": "XJ_RESOURCE_INTEL_V26", "meta": "xj_resource_intel_v26_diagnostic"},
		{"flag": "--xj-verify-industry-v25", "file": "industry_v25.gd", "prefix": "industry-v25", "env": "XJ_INDUSTRY_V25", "meta": "xj_industry_v25_diagnostic"},
		{"flag": "--xj-verify-industry-world-v25", "file": "industry_world_v25.gd", "prefix": "industry-world-v25", "env": "XJ_INDUSTRY_WORLD_V25", "meta": "xj_industry_world_v25_diagnostic"},
		{"flag": "--xj-verify-civilization-world-v24", "file": "civilization_world_v24.gd", "prefix": "civilization-world-v24", "env": "XJ_CIVILIZATION_WORLD_V24", "meta": "xj_civilization_world_v24_diagnostic"},
		{"flag": "--xj-verify-civilization-upgrade-v24", "file": "civilization_upgrade_v24.gd", "prefix": "civilization-upgrade-v24", "env": "XJ_CIVILIZATION_UPGRADE_V24", "meta": "xj_civilization_upgrade_v24_diagnostic"},
		{"flag": "--xj-verify-civilizations-v24", "file": "civilizations_v24.gd", "prefix": "civilizations-v24", "env": "XJ_CIVILIZATIONS_V24", "meta": "xj_civilizations_v24_diagnostic"},
		{"flag": "--xj-verify-combat-v18", "file": "combat_v18.gd", "prefix": "combat-v18", "env": "XJ_COMBAT_V18", "meta": "xj_combat_v18_diagnostic"},
		{"flag": "--xj-verify-lighting-v18", "file": "lighting_effects_v18.gd", "prefix": "lighting-effects-v18", "env": "XJ_LIGHTING_V18", "meta": "xj_lighting_v18_diagnostic"},
		{"flag": "--xj-verify-weapon-ui-v18", "file": "weapon_ui_v18.gd", "prefix": "weapon-ui-v18", "env": "XJ_WEAPON_UI_V18", "meta": "xj_weapon_ui_v18_diagnostic"},
		{"flag": "--xj-verify-upgrade-v18", "file": "combat_upgrade_v18.gd", "prefix": "combat-upgrade-v18", "env": "XJ_UPGRADE_V18", "meta": "xj_upgrade_v18_diagnostic"},
		{"flag": "--xj-verify-mission-display-v19", "file": "mission_display_v19.gd", "prefix": "mission-display-v19", "env": "XJ_MISSION_DISPLAY_V19", "meta": "xj_mission_display_v19_diagnostic"},
		{"flag": "--xj-verify-warp-visual-v20", "file": "warp_visual_v20.gd", "prefix": "warp-visual-v20", "env": "XJ_WARP_VISUAL_V20", "meta": "xj_warp_visual_v20_diagnostic"},
		{"flag": "--xj-verify-warp-scene-v21", "file": "warp_scene_v21.gd", "prefix": "warp-scene-v21", "env": "XJ_WARP_SCENE_V21", "meta": "xj_warp_scene_v21_diagnostic"},
		{"flag": "--xj-verify-service-navigation-v22", "file": "service_navigation_v22.gd", "prefix": "service-navigation-v22", "env": "XJ_SERVICE_NAVIGATION_V22", "meta": "xj_service_navigation_v22_diagnostic"},
		{"flag": "--xj-verify-spatial-business-v20", "file": "spatial_business_v20.gd", "prefix": "spatial-business-v20", "env": "XJ_SPATIAL_BUSINESS_V20", "meta": "xj_spatial_business_v20_diagnostic"},
		{"flag": "--xj-verify-space-upgrade-v20", "file": "space_upgrade_v20.gd", "prefix": "space-upgrade-v20", "env": "XJ_SPACE_UPGRADE_V20", "meta": "xj_space_upgrade_v20_diagnostic"},
		{"flag": "--xj-verify-spatial-navigation-v20", "file": "spatial_navigation_v20.gd", "prefix": "spatial-navigation-v20", "env": "XJ_SPATIAL_NAVIGATION_V20", "meta": "xj_spatial_navigation_v20_diagnostic"},
	]:
		if arguments.has(str(v18_contract.flag)) and not get_tree().has_meta(str(v18_contract.meta)):
			_start_v18_diagnostic(v18_contract)
			return
	if arguments.has("--xj-verify-encounters") and not get_tree().has_meta("xj_encounter_diagnostic"):
		_start_encounter_diagnostic()
		return
	if arguments.has("--xj-verify-combat-automation") and not get_tree().has_meta("xj_combat_automation_diagnostic"):
		_start_combat_automation_diagnostic()
		return
	if arguments.has("--xj-verify-warehouse") and not get_tree().has_meta("xj_warehouse_diagnostic"):
		_start_warehouse_diagnostic()
		return
	if arguments.has("--xj-verify-row-quantities") and not get_tree().has_meta("xj_row_quantity_diagnostic"):
		_start_row_quantity_diagnostic()
		return
	if arguments.has("--xj-verify-store"):
		var diagnostic := preload("res://runtime/data/diagnostic.gd")
		get_tree().quit(0 if diagnostic.run(OS.get_environment("XJ_TEST_DATABASE"), arguments.has("--xj-verify-upgrade")) else 1)
		return
	if arguments.has("--xj-validation-profile") or arguments.has("--xj-verify-presentation"):
		var validation_path := OS.get_environment("XJ_TEST_DATABASE").replace("\\", "/")
		if not validation_path.is_absolute_path() or validation_path.contains("..") or not validation_path.contains("/jiaoben/tmp/"):
			push_error("Validation profile requires an absolute jiaoben/tmp database path")
			get_tree().quit(2)
			return
		progress_database_path = validation_path
		if arguments.has("--xj-verify-presentation") and FileAccess.file_exists(validation_path):
			push_error("Presentation diagnostic requires a fresh test database")
			get_tree().quit(2)
			return
	last_error = XJPresentationResources.validate()
	if not last_error.is_empty():
		push_error(last_error)
		get_tree().quit(2)
		return
	_install_input()
	var warp_canvas := CanvasLayer.new()
	warp_canvas.layer = 0
	add_child(warp_canvas)
	warp_visual = XJWarpVisual.new()
	warp_canvas.add_child(warp_visual)
	get_tree().auto_accept_quit = false
	get_window().focus_exited.connect(_release_controls)
	ui = XJUI.new()
	add_child(ui)
	ui.requested.connect(_command)
	ui.target_selected.connect(_combat_selection_changed)
	camera = XJCameraRig.new()
	add_child(camera)
	store = XJGameStore.new(progress_database_path)
	store.status_changed.connect(_store_status)
	if not store.open():
		last_error = store.last_error
		ui.notify("航行档案初始化失败；已有进度保留。详情已写入运行日志。", true)
		push_error(last_error)
		return
	Engine.physics_ticks_per_second = int(store.catalog.rule("simulation_hz"))
	preferences = store.preferences()
	_apply_preferences()
	# Prepare every presentation dependency before publishing a new/load world.
	# It is a hidden exhibition; gameplay state and catalog balance are untouched.
	hangar = preload("res://runtime/civilization_hangar.gd").new()
	hangar.name = "StationExhibition"
	hangar.configure("shuttle_swift", store.catalog)
	add_child(hangar)
	hangar.hide()
	hangar.process_mode = Node.PROCESS_MODE_DISABLED
	if hangar.get_camera() == null:
		last_error = "空间站表现资源初始化失败"
		ui.notify(last_error, true)
		push_error(last_error)
		return
	camera.camera.make_current()
	ui.show_title(store.list_slots())
	services_ready = true
	if arguments.has("--xj-verify-presentation"):
		var diagnostic := preload("res://runtime/presentation_diagnostic.gd")
		var verified: bool = await diagnostic.run(self, progress_database_path.get_base_dir())
		get_tree().quit(0 if verified else 1)

func _start_v18_diagnostic(contract: Dictionary) -> void:
	# Explicit release acceptance hands off before opening any progress database.
	# res:// remains the executable's exported PCK; no source project is mounted.
	var script_path: String = OS.get_environment(str(contract.env) + "_SCRIPT").replace("\\", "/")
	var directory: String = OS.get_environment(str(contract.env) + "_DIRECTORY").replace("\\", "/")
	var temporary: String = script_path.get_base_dir().get_base_dir().path_join("tmp/" + str(contract.prefix))
	var uuid := RegEx.new()
	uuid.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	if not script_path.is_absolute_path() or script_path.contains("..") or not script_path.ends_with("/jiaoben/tests/" + str(contract.file)) or not FileAccess.file_exists(script_path) or not directory.is_absolute_path() or directory.contains("..") or directory.get_base_dir() != temporary or uuid.search(directory.get_file()) == null or FileAccess.file_exists(directory.path_join("progress.db")):
		push_error("V18 diagnostic requires its fixed test Node and a fresh scoped UUID directory: " + str(contract.prefix))
		get_tree().quit(2)
		return
	var source: Script = load(script_path)
	if source == null or not source.can_instantiate():
		push_error("V18 diagnostic test script cannot be loaded: " + str(contract.file))
		get_tree().quit(2)
		return
	var diagnostic: Node = source.new() as Node
	if diagnostic == null:
		push_error("V18 diagnostic requires a test Node: " + str(contract.file))
		get_tree().quit(2)
		return
	get_tree().set_meta(str(contract.meta), true)
	set_process(false)
	set_physics_process(false)
	get_tree().root.add_child.call_deferred(diagnostic)
	queue_free()

func _start_encounter_diagnostic() -> void:
	# Release templates do not implement the editor's --script option. Explicit
	# acceptance loads a test-owned Node while res:// stays the exported PCK.
	var script_path: String = OS.get_environment("XJ_ENCOUNTER_V12_SCRIPT").replace("\\", "/")
	var output_path: String = OS.get_environment("XJ_ENCOUNTER_V12_OUTPUT").replace("\\", "/")
	var temporary: String = script_path.get_base_dir().get_base_dir().path_join("tmp/release-encounters")
	if not script_path.is_absolute_path() or script_path.contains("..") or not script_path.ends_with("/jiaoben/tests/encounter_mission_v12.gd") or not FileAccess.file_exists(script_path) or not output_path.is_absolute_path() or output_path.contains("..") or not output_path.begins_with(temporary + "/") or FileAccess.file_exists(output_path.path_join("progress.db")):
		push_error("Encounter diagnostic requires an external test script and fresh test-owned output")
		get_tree().quit(2)
		return
	var diagnostic_script: Script = load(script_path)
	if diagnostic_script == null or not diagnostic_script.can_instantiate():
		push_error("Encounter diagnostic script cannot be loaded")
		get_tree().quit(2)
		return
	var diagnostic: Node = diagnostic_script.new() as Node
	if diagnostic == null:
		push_error("Encounter diagnostic must be a test Node")
		get_tree().quit(2)
		return
	# Test-created Main instances take their normal production startup path.
	get_tree().set_meta("xj_encounter_diagnostic", true)
	set_process(false)
	set_physics_process(false)
	get_tree().root.add_child.call_deferred(diagnostic)
	queue_free()

func _start_combat_automation_diagnostic() -> void:
	# Explicit release acceptance keeps all production resources in the PCK.
	# This entry accepts only the fixed test Node and a fresh test-owned folder.
	var script_path: String = OS.get_environment("XJ_AUTOMATION_V15_SCRIPT").replace("\\", "/")
	var directory: String = OS.get_environment("XJ_AUTOMATION_V15_DIRECTORY").replace("\\", "/")
	var temporary: String = script_path.get_base_dir().get_base_dir().path_join("tmp/combat-automation-v15")
	if not script_path.is_absolute_path() or script_path.contains("..") or not script_path.ends_with("/jiaoben/tests/combat_automation_v15.gd") or not FileAccess.file_exists(script_path) or not directory.is_absolute_path() or directory.contains("..") or not directory.begins_with(temporary + "/") or FileAccess.file_exists(directory.path_join("progress.db")):
		push_error("Combat automation diagnostic requires its fixed test script and a fresh scoped directory")
		get_tree().quit(2)
		return
	var source: Script = load(script_path)
	if source == null or not source.can_instantiate():
		push_error("Combat automation test script cannot be loaded")
		get_tree().quit(2)
		return
	var diagnostic: Node = source.new() as Node
	if diagnostic == null:
		push_error("Combat automation diagnostic must be a test Node")
		get_tree().quit(2)
		return
	get_tree().set_meta("xj_combat_automation_diagnostic", true)
	set_process(false)
	set_physics_process(false)
	get_tree().root.add_child.call_deferred(diagnostic)
	queue_free()

func _start_warehouse_diagnostic() -> void:
	var script_path: String = OS.get_environment("XJ_WAREHOUSE_V16_SCRIPT").replace("\\", "/")
	var directory: String = OS.get_environment("XJ_WAREHOUSE_V16_DIRECTORY").replace("\\", "/")
	var temporary: String = script_path.get_base_dir().get_base_dir().path_join("tmp/warehouse-transfer-v16")
	if not script_path.is_absolute_path() or script_path.contains("..") or not script_path.ends_with("/jiaoben/tests/warehouse_transfer_v16.gd") or not FileAccess.file_exists(script_path) or not directory.is_absolute_path() or directory.contains("..") or not directory.begins_with(temporary + "/") or FileAccess.file_exists(directory.path_join("progress.db")):
		push_error("Warehouse diagnostic requires its fixed test Node and fresh scoped directory")
		get_tree().quit(2)
		return
	var source: Script = load(script_path)
	if source == null or not source.can_instantiate():
		push_error("Warehouse diagnostic test script cannot be loaded")
		get_tree().quit(2)
		return
	var diagnostic: Node = source.new() as Node
	if diagnostic == null:
		push_error("Warehouse diagnostic requires a test Node")
		get_tree().quit(2)
		return
	get_tree().set_meta("xj_warehouse_diagnostic", true)
	set_process(false)
	set_physics_process(false)
	get_tree().root.add_child.call_deferred(diagnostic)
	queue_free()

func _start_row_quantity_diagnostic() -> void:
	# The acceptance Node uses the exported PCK and a fresh test-owned database.
	var script_path: String = OS.get_environment("XJ_ROW_QUANTITY_V17_SCRIPT").replace("\\", "/")
	var directory: String = OS.get_environment("XJ_ROW_QUANTITY_V17_DIRECTORY").replace("\\", "/")
	var temporary: String = script_path.get_base_dir().get_base_dir().path_join("tmp/row-quantity-v17")
	if not script_path.is_absolute_path() or script_path.contains("..") or not script_path.ends_with("/jiaoben/tests/row_quantity_v17.gd") or not FileAccess.file_exists(script_path) or not directory.is_absolute_path() or directory.contains("..") or not directory.begins_with(temporary + "/") or FileAccess.file_exists(directory.path_join("progress.db")):
		push_error("Row quantity diagnostic requires its fixed test Node and fresh scoped directory")
		get_tree().quit(2)
		return
	var source: Script = load(script_path)
	if source == null or not source.can_instantiate():
		push_error("Row quantity diagnostic test script cannot be loaded")
		get_tree().quit(2)
		return
	var diagnostic: Node = source.new() as Node
	if diagnostic == null:
		push_error("Row quantity diagnostic requires a test Node")
		get_tree().quit(2)
		return
	get_tree().set_meta("xj_row_quantity_diagnostic", true)
	set_process(false)
	set_physics_process(false)
	get_tree().root.add_child.call_deferred(diagnostic)
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui):
		_command("quit", "", 1, "")

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if gameplay != null and gameplay.has_method("dispose"):
		gameplay.call("dispose")
	if staged_gameplay != null and staged_gameplay.has_method("dispose"):
		staged_gameplay.call("dispose")
	if store != null:
		store.close()

func _process(delta: float) -> void:
	if state!=null and gameplay!=null and gameplay.journal!=null and not busy and ui!=null:
		var navigating: bool=(local_navigation!=null and local_navigation.active()) or (travel!=null and travel.active())
		var waiting: bool=navigating and not _paused() and state.ship()!=null and Vector3(state.ship().vel_x,state.ship().vel_y,state.ship().vel_z).length()<=float(gameplay.rows("telemetry_policy_defs")[0].navigation_wait_speed_mps) if gameplay.journal.supported() else false
		gameplay.journal.presentation(delta,ui.page,get_tree().root.has_focus(),waiting)
	if ui != null:
		if not previous_page.is_empty() and ui.page.is_empty(): _center_steering()
		previous_page = ui.page
	_sync_mouse_mode()
	_sync_presentation_stage()
	if not deferred_save.is_empty():
		save_wait_elapsed += delta
		if save_wait_elapsed >= float(store.catalog.rule("save_wait_prompt_s")):
			ui.set_operation_status("save", "保存仍在等待：继续航行、取消保存，或在暂停菜单放弃未保存进度退出", true, _exit_save_pending())
	if world != null:
		var stopped := _paused() or busy
		world.projectiles.set_paused(stopped)
		world.projectiles.process_mode = Node.PROCESS_MODE_DISABLED if stopped else Node.PROCESS_MODE_INHERIT
		if presentation != null:
			presentation.process_mode = Node.PROCESS_MODE_DISABLED if stopped else Node.PROCESS_MODE_INHERIT
			presentation.set_paused(stopped)
			if not stopped:
				presentation.consume(delta)
	# Camera and projected annotations must use the same rendered ship pose.
	if is_instance_valid(warp_visual):
		var warp_phase: String = local_navigation.phase if local_navigation != null and local_navigation.warp_active() else "warmup" if travel != null and travel.active() else "idle"
		warp_visual.update_navigation(warp_phase, delta, float(preferences.get("vfx_intensity", 1.0)), _paused() or busy)
	if camera != null:
		if state == null or state.ship().status != Types.ShipStatus.DOCKED:
			camera.step(delta)
	if is_instance_valid(warp_visual):
		warp_visual.update_pose(local_navigation.warp_heading if local_navigation != null and local_navigation.warp_active() else -world.flight.global_basis.z if is_instance_valid(world) and is_instance_valid(world.flight) else Vector3.FORWARD)
	if world != null:
		world.update_starlight()
		XJCelestialBackdrop.update(world)
	if ui != null: ui.tick(delta)
	local_boundary_warning_s = maxf(0.0, local_boundary_warning_s - delta)

func _physics_process(delta: float) -> void:
	if state == null or world == null or busy or _paused():
		return
	if not world.sync_entities():
		ui.show_page("pause")
		ui.notify(world.last_error, true)
		return
	var ship := state.ship()
	if pointer_pick_pending:
		pointer_pick_pending = false
		if ship.status == Types.ShipStatus.FLYING and not ui.ui_input_blocked():
			var picked: String = _world_target_at(pointer_pick_position)
			if not picked.is_empty(): ui._select_target(picked)
	if ship.ship_instance_id != world.flight.record.ship_instance_id:
		if not world.rebuild_player():
			ui.show_page("pause")
			ui.notify(world.last_error, true)
			return
		camera.bind(world.flight, store.catalog, state.player().camera_mode)
	gameplay.call("begin_step", delta)
	gameplay.ship_roles.spatial_active = not travel.active() and not local_navigation.warp_active()
	gameplay.hired.spatial_active = not travel.active() and not local_navigation.warp_active()
	gameplay.owned_fleet.spatial_active = not travel.active() and not local_navigation.warp_active()
	gameplay.auxiliary_drones.spatial_active = not travel.active() and not local_navigation.warp_active()
	gameplay.situational.spatial_active = not travel.active() and not local_navigation.warp_active()
	world.flight.metrics = gameplay.call("metrics", ship)
	if _manual_navigation_override(): source_goal.clear()
	if _manual_navigation_override() and combat_automation != null:
		combat_automation.relinquish_motion()
	if combat_automation != null and not _exit_save_pending() and not travel.active() and not local_navigation.warp_active():
		combat_automation.tick()
	if local_navigation != null and local_navigation.active():
		if _manual_navigation_override():
			if Input.is_action_pressed("brake"):
				local_navigation.stop()
			else:
				local_navigation.release_to_manual()
		else:
			flight_look.clear()
	if local_navigation == null or not local_navigation.active():
		_read_flight_input(delta)
		if combat_automation != null and not _manual_navigation_override(): combat_automation.hold_intent()
	elif Input.is_action_pressed("boost") and _keyboard_control_allowed():
		_request_engine_cycle()
	gameplay.call("activate_repairs")
	var warping: bool = local_navigation != null and local_navigation.warp_active()
	if not warping and fire_held and Input.is_action_pressed("fire") and _keyboard_control_allowed():
		_fire_weapons()
	elif not warping and not auto_fire_target.is_empty():
		_tick_auto_fire()
	world.flight.blocked = travel.active() if travel != null else false
	var crew_distance_origin: Vector3=world.flight.position
	if local_navigation != null and local_navigation.active():
		local_navigation.tick(delta)
	else:
		world.flight.simulate(delta)
	if not warping and not travel.active() and state.ship().status==Types.ShipStatus.FLYING:
		gameplay.crew.contribute(state.ship().ship_instance_id,"distance",crew_distance_origin.distance_to(world.flight.position))
	if not warping:
		if world.enforce_local_boundary() and local_boundary_warning_s <= 0.0:
			ui.notify("已到达当前地点的局部航行边界；选择其他地点并跃迁继续航行。")
			local_boundary_warning_s = 3.0
		world.simulate_npcs(delta)
	world.projectiles.simulate(delta)
	_flush_damage()
	gameplay.situational.spatial_active = not travel.active() and not local_navigation.warp_active()
	gameplay.call("finish_step", delta)
	_check_objectives(delta)
	if not str(gameplay.call("take_autosave_request")).is_empty():
		_queue_autosave()
		if busy:
			return
	if travel != null and travel.active():
		travel.tick(delta)
		return
	if ship.status == Types.ShipStatus.DESTROYED:
		_reset_combat_automation()
		if last_destroyed_ship != ship.ship_instance_id:
			last_destroyed_ship = ship.ship_instance_id
			ui.notify("舰船已毁，按 Esc 使用救援返回空间站。", true)
	if not deferred_save.is_empty() and _save_block_reason().is_empty():
		var request: Dictionary = deferred_save
		deferred_save = {}
		_save_now(str(request.kind), int(request.index), str(request.get("after", "")))
		return
	autosave_elapsed += delta
	if autosave_elapsed >= float(store.catalog.rule("autosave_interval_s")) and deferred_save.is_empty():
		autosave_elapsed = 0.0
		_queue_autosave()

func _paused() -> bool:
	return ui.menu_open or ui.page in ["pause", "settings", "title"]

func _unhandled_input(event: InputEvent) -> void:
	if state == null or busy:
		return
	if event.is_action_pressed("menu"):
		var next_page := "pause" if ui.page.is_empty() or ui.page == "station" else _home_page()
		if ui.page == "settings": next_page = "pause"
		ui.show_page(next_page)
		_release_controls()
		get_viewport().set_input_as_handled()
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.is_action_pressed("map"):
		ui.show_page(_home_page() if ui.page == "map" else "map")
		_release_controls()
	elif event.is_action_pressed("missions"):
		ui.show_page(_home_page() if ui.page == "missions" else "missions")
		_release_controls()
	elif event.is_action_pressed("quick_save"):
		_request_save("quick", 0)
	elif event.is_action_pressed("quick_load"):
		for slot in store.list_slots():
			if slot.world_id == state.world_id and slot.slot_kind == "quick":
				_command("load", slot.slot_id, slot.generation, slot.current_snapshot_id)
				break
	if not _keyboard_control_allowed(): return
	if event.is_action_pressed("interact"):
		_command("interact", "", 1, "")
		return
	if event.is_action_pressed("camera") and not event.is_echo():
		_release_observation()
		camera.cycle_mode()
		state.player().camera_mode = camera.mode
		ui.update_camera_status()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("brake") and not event.is_echo():
		_command("nav_stop", "", 1, "")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("combat_toggle") and not event.is_echo():
		# The global shortcut always stops the current fire order first, even
		# when the player is inspecting a different station or scenic bearing.
		if combat_automation != null and bool(combat_automation.options.fire):
			combat_automation.set_option("fire", false)
			_sync_combat_automation()
			ui.notify("已停止自动开火。")
		else:
			_command("combat_toggle", ui.target_id, 1, "")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("target"):
		ui.select_next()
	elif event.is_action_pressed("fire"):
		fire_held = true
	if event is InputEventMouseButton and event.pressed and not ui.ui_input_blocked():
		if event.button_index == MOUSE_BUTTON_LEFT:
			# A click chooses; holding and moving rotates the camera. Neither
			# action owns the ship's motion or replaces an accepted order.
			pointer_drag_pressed = true
			pointer_dragged = false
			pointer_drag_origin = event.position
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.scroll_zoom(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.scroll_zoom(1)

func _input(event: InputEvent) -> void:
	# Mouse/key release must end a gesture even after entering a HUD control.
	# Native window events can arrive before _ready installs the input actions.
	if InputMap.has_action("fire") and event.is_action_released("fire"):
		fire_held = false
		weapon_errors.clear()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if state != null and ui != null and ui.page.is_empty():
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and pointer_drag_pressed:
		if not pointer_dragged and _keyboard_control_allowed() and not ui.ui_input_blocked():
			pointer_pick_position = event.position
			pointer_pick_pending = true
		pointer_drag_pressed = false
		pointer_dragged = false
		_release_observation()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_drag_pressed:
		if not _keyboard_control_allowed():
			_release_controls()
			return
		var motion: Vector2 = event.relative
		if not pointer_dragged:
			motion = event.position - pointer_drag_origin
			if motion.length() < POINTER_DRAG_TOLERANCE_PX: return
			pointer_dragged = true
			observing = true
			camera.begin_observation()
		camera.observe(motion, float(preferences.get("mouse_sensitivity", 0.0)))
		get_viewport().set_input_as_handled()

func _keyboard_control_allowed() -> bool:
	return state != null and world != null and ui != null and not busy and not _exit_save_pending() and state.ship().status == Types.ShipStatus.FLYING and not ui.keyboard_blocked() and (DisplayServer.get_name() == "headless" or get_window().has_focus())

func _world_target_at(screen_position: Vector2) -> String:
	if local_navigation != null and local_navigation.warp_active(): return ""
	if world == null or camera == null or state == null or state.ship().status != Types.ShipStatus.FLYING: return ""
	var view: Camera3D = camera.camera
	var start: Vector3 = view.project_ray_origin(screen_position)
	var end: Vector3 = start + view.project_ray_normal(screen_position) * view.far
	var query := PhysicsRayQueryParameters3D.create(start, end, 195, [world.flight.get_rid()])
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return ""
	var collider: Node = hit.collider as Node
	for id: String in world.targets:
		var entry: Dictionary = world.targets[id]
		var node: Node3D = entry.node
		if not is_instance_valid(node) or not is_instance_valid(collider): continue
		if node != collider and not node.is_ancestor_of(collider): continue
		if str(entry.kind) == "npc":
			var npc: RefCounted = state.find("npc_state", "npc_instance_id", id)
			if npc == null or not npc.alive or world.flight.global_position.distance_to(node.global_position) > gameplay.ship_roles.detection_range(): return ""
		if str(entry.kind) == "drone" and not gameplay.drone_control.live.has(id): return ""
		return id
	return ""

func _read_flight_input(delta: float = 0.0) -> void:
	world.flight.clear_intent()
	if not _keyboard_control_allowed() or travel.active():
		fire_held = false
		flight_look.clear()
		return
	var intent := world.flight.intent
	intent.thrust_y = Input.get_axis("down", "up")
	intent.thrust_z = Input.get_axis("back", "forward")
	var option_focus: bool = ui.combat_option_has_focus()
	if option_focus: intent.thrust_y = -Input.get_action_strength("down")
	var turn: Vector3 = flight_look.keyboard_turn(option_focus)
	# A/D uses the same axis as the visible camera. A tilted local ship-up
	# otherwise made the physical yaw compete with the world-up view yaw.
	var yaw_axis: Vector3 = world.flight.global_basis.y if camera.mode == Types.CameraMode.FRONT else Vector3.UP
	var combined: Vector3 = flight_look.world_rotation_to_input(world.flight.global_basis, yaw_axis * turn.y) + Vector3(turn.x, 0.0, turn.z)
	var mapped: Vector3 = combined.limit_length(1.0)
	intent.pitch_request = mapped.x
	intent.yaw_request = mapped.y
	intent.roll_request = mapped.z
	intent.brake_requested = Input.is_action_pressed("brake")
	intent.engine_cycle_requested = Input.is_action_pressed("boost")
	var tick_delta := delta if delta > 0.0 else 1.0 / float(Engine.physics_ticks_per_second)
	var turn_budget: float = float(world.flight.metrics.turn_radps) * tick_delta
	if not is_zero_approx(turn.y): camera.steer_yaw(turn.y * turn_budget / maxf(1.0, combined.length()))
	if not is_zero_approx(intent.thrust_z):
		var heading: Vector3 = camera.control_forward()
		intent.view_thrust_direction = heading
		var local_heading: Vector3 = world.flight.global_basis.inverse() * heading
		# W/S still advances along the visible view; explicit attitude keys own
		# this tick's steering instead of being overwritten by view alignment.
		if turn.is_zero_approx() and turn_budget > 0.0:
			intent.yaw_request = clampf(atan2(-local_heading.x, -local_heading.z) / turn_budget, -1.0, 1.0)
			intent.pitch_request = clampf(atan2(local_heading.y, Vector2(local_heading.x, local_heading.z).length()) / turn_budget, -1.0, 1.0)
	if intent.engine_cycle_requested:
		_request_engine_cycle()

func _request_engine_cycle() -> void:
	if _exit_save_pending(): return
	if local_navigation != null and local_navigation.warp_active(): return
	for equipment: Dtos.EquipmentStateDto in state.rows("equipment_state"):
		var slot := state.find("container_state", "container_id", equipment.slot_container_id) as Dtos.ContainerStateDto
		var definition: Dictionary = store.catalog.one("module_defs", "module_id", equipment.module_def_id)
		var item := state.find("item_instance_state", "item_instance_id", equipment.item_instance_id) as Dtos.ItemInstanceStateDto
		if slot != null and slot.ship_instance_id == state.ship().ship_instance_id and equipment.module_def_id.begins_with("module_engine_") and equipment.enabled and item != null and item.durability > 0.0 and equipment.cooldown_remaining_s <= 0.0 and not state.ship().overheated and state.ship().energy >= float(definition.energy_eu) and state.ship().heat + float(definition.heat_hu) <= float(world.flight.metrics.heat_max):
			gameplay.call("act", "request_engine_cycle", "", 1, "")
			break

func _fire_weapons(automatic: bool = false, target_override: String = "") -> void:
	if travel.active() or _exit_save_pending():
		return
	var target_node: Node3D
	var selected_target: String = target_override if not target_override.is_empty() else ui.target_id
	if world.targets.has(selected_target) and world.target_is_local(selected_target):
		target_node = world.targets[selected_target].node
	for equipment: Dtos.EquipmentStateDto in gameplay.call("equipped", state.ship()):
		var slot := state.find("container_state", "container_id", equipment.slot_container_id) as Dtos.ContainerStateDto
		if slot == null or slot.ship_instance_id != state.ship().ship_instance_id or slot.slot_type != Types.SlotType.WEAPON:
			continue
		if equipment.cooldown_remaining_s > 0.0:
			continue
		if not equipment.enabled:
			continue
		var profile: Dictionary = gameplay.specializations.weapon_spec(equipment,state.ship())
		if profile.is_empty(): continue
		var drone: bool = str(profile.fire_mode) == "drone"
		if drone and gameplay.drone_control.supported() and gameplay.drone_control.bay(equipment.item_instance_id).command_kind != "attack": continue
		if drone and (world.projectiles.module_busy(equipment.item_instance_id) or not _enemy_target_valid(selected_target)): continue
		var cone: float = float(profile.fire_cone_half_angle_rad)
		var origin := world.flight.muzzle(slot.slot_index)
		var direction := -origin.basis.z
		if automatic or drone:
			if not is_instance_valid(target_node): continue
			var definition: Dictionary = profile
			var range_origin: Vector3 = world.flight.global_position if drone else origin.origin
			if range_origin.distance_to(target_node.global_position) > float(definition.get("range_m", 0.0)): continue
			if direction.angle_to(origin.origin.direction_to(target_node.global_position)) > cone: continue
			if not world.line_of_sight(origin.origin, target_node.global_position, world.flight.get_rid(), selected_target): continue
		if is_instance_valid(target_node):
			var target_direction := origin.origin.direction_to(target_node.global_position)
			if direction.angle_to(target_direction) <= cone:
				direction = target_direction
		var cycle: Dictionary = gameplay.call("consume_weapon_cycle", equipment.item_instance_id)
		if cycle.is_empty():
			var reason: String = str(gameplay.get("last_error"))
			if weapon_errors.get(equipment.item_instance_id, "") != reason:
				ui.notify(reason, true)
				weapon_errors[equipment.item_instance_id] = reason
			continue
		weapon_errors.erase(equipment.item_instance_id)
		world.projectiles.fire(state.ship().ship_instance_id, world.flight.get_rid(), origin.origin, direction, float(cycle.speed) if cycle.get("speed") != null else 0.0, float(cycle.get("range", 0.0)), cycle.get("damage_vector", Vector3.ZERO), cycle.profile, equipment.item_instance_id, selected_target)

func _weapon_hit(target_id: String, damage: Vector3, point: Vector3, owner_id: String) -> void:
	if not gameplay.civilizations.hostile_to(owner_id, target_id): return
	if owner_id == state.ship().ship_instance_id: player_damage_targets[target_id] = (player_damage_targets.get(target_id,Vector3.ZERO) as Vector3)+damage
	elif gameplay.owned_fleet.row(owner_id)!=null and gameplay.owned_fleet.row(owner_id).phase in ["deployed","retreating","lost"]:
		if not owned_damage_targets.has(target_id):owned_damage_targets[target_id]={}
		owned_damage_targets[target_id][owner_id]=(owned_damage_targets[target_id].get(owner_id,Vector3.ZERO) as Vector3)+damage
	if target_id == state.ship().ship_instance_id and owner_id != target_id:
		if presentation != null: presentation.hit(target_id, state.ship().shield > 0.0, point, damage)
		pending_damage[target_id] = (pending_damage.get(target_id, Vector3.ZERO) as Vector3) + damage
	elif (owner_id == state.ship().ship_instance_id or state.find("npc_state", "npc_instance_id", owner_id) != null) and state.find("npc_state", "npc_instance_id", target_id) != null:
		var npc := state.find("npc_state", "npc_instance_id", target_id) as Dtos.NpcStateDto
		if presentation != null: presentation.hit(target_id, npc.shield > 0.0, point, damage)
		pending_damage[target_id] = (pending_damage.get(target_id, Vector3.ZERO) as Vector3) + damage
	# point is a render position, never a persistence identity.
	if point.is_finite():
		pass

func _surface_impact(point: Vector3, color: Color, normal: Vector3) -> void:
	if presentation != null: presentation.impact(point, color, normal)

func _flush_damage() -> void:
	for id in pending_damage:
		var raw: Vector3 = pending_damage[id]
		if id == state.ship().ship_instance_id:
			gameplay.call("damage_ship", raw)
		else:
			gameplay.call("damage_npc", id, raw,player_damage_targets.get(id,Vector3.ZERO),owned_damage_targets.get(id,{}))
			if player_damage_targets.has(id):
				gameplay.call("record_event", "weapon_hit", id, 1)
				ui.notify("命中敌舰 · %.0f" % (raw.x + raw.y + raw.z))
	pending_damage.clear()
	player_damage_targets.clear(); owned_damage_targets.clear()

func _owned_attacks_pending(owner_id: String) -> bool:
	return world!=null and is_instance_valid(world.projectiles) and world.projectiles.owner_busy(owner_id)

func interaction_context(target_id: String = "") -> Dictionary:
	var context = preload("res://runtime/interaction_context.gd")
	if target_id.is_empty(): return context.choose(world, state, store.catalog, gameplay, ui.target_id)
	return context.inspect(world, state, store.catalog, gameplay, target_id)

func _interact(target_id: String = "") -> void:
	if local_navigation != null and local_navigation.warp_active():
		ui.notify("本星系跃迁中，请先停船取消。", true)
		return
	if state == null or world == null or travel == null:
		ui.notify("当前没有可交互的舰船。", true)
		return
	if travel.active():
		if not target_id.is_empty():
			ui.notify("虫洞传送正在进行，F 可取消充能。", true)
		elif not travel.cancel():
			ui.notify("跃迁进度正在提交，暂时不能取消。", true)
		return
	# F may choose a nearby eligible object; a mouse command never changes its target.
	var candidate: Dictionary = interaction_context(target_id)
	if not candidate.ready:
		ui.notify(str(candidate.reason), true)
		return
	ui.target_id = str(candidate.target_id)
	if candidate.action == "travel":
		gameplay.call("stop_interactions")
		if not _save_block_reason().is_empty():
			ui.notify("脱离交战并等待设备周期结束后，才能通过虫洞。", true)
			return
		travel.begin(str(candidate.target_id))
	else:
		_command(str(candidate.action), str(candidate.target_id), 1, "")

func _command(action: String, target: String, quantity: int, extra: String) -> void:
	if busy:
		ui.notify("存档操作正在完成，请稍候。")
		if action == "set_combat_option": _sync_combat_automation()
		return
	if _exit_save_pending() and action not in ["cancel_save", "quit_without_save", "quit", "return_title", "preference", "show_ship", "hangar_focus"]:
		ui.notify("正在等待稳定保存后离开；取消保存请求后可继续操作。")
		if action == "set_combat_option": _sync_combat_automation()
		return
	match action:
		"scenario_map","scenario_navigate":_scenario_navigation(action,target,extra)
		"campaign_map","campaign_navigate":
			_campaign_navigation(action,target,extra)
		"export_flight_report":
			_export_flight_report(target)
		"drone_command":
			_drone_order(extra, target)
		"frontier_open":
			ui.frontier_selected_id=target;ui.show_page("frontier")
		"frontier_sources":
			ui.open_sources(str(gameplay.frontier.balance.material_id))
		"frontier_map", "frontier_navigate":
			_frontier_navigation(action,target,extra)
		"growth_map", "growth_navigate":
			_growth_navigation(action,target,extra)
		"growth_open":
			_growth_open(target,extra)
		"operation_open":
			ui.show_page("operations")
		"operation_map", "operation_nav":
			_operation_navigation(action,target,extra)
		"exploration_open":
			var event_id: String = str(world.targets.get(target, {}).get("event_id", target))
			ui.open_exploration(event_id)
		"exploration_map", "exploration_nav":
			_exploration_navigation(action, target, extra)
		"source_map", "source_travel":
			_source_navigation(action, target, extra)
		"demand_navigate":
			_demand_navigation(target)
		"civilization_map", "war_navigate":
			_civilization_navigation(action, target)
		"set_combat_option":
			if combat_automation != null and _keyboard_control_allowed() and not travel.active() and not local_navigation.warp_active() and not _paused():
				combat_automation.set_option(target, extra == "on")
			_sync_combat_automation()
		"mission_locate", "mission_travel", "mission_station":
			source_goal.clear()
			_mission_navigation(action, target)
		"consignment_navigate", "consignment_map":
			_consignment_navigation(action,target,extra)
		"nav_warp", "nav_approach", "nav_orbit", "nav_dock":
			source_goal.clear()
			_navigation_command(action.trim_prefix("nav_"), target)
		"nav_stop":
			source_goal.clear()
			if combat_automation != null: combat_automation.relinquish_motion()
			if local_navigation != null: local_navigation.stop()
			_center_steering()
		"combat_engage":
			if not _combat_target_valid(target):
				ui.notify("需选择探测范围内的存活敌舰，并安装可用武器。", true)
			elif _navigation_command("approach", target, true):
				combat_automation.lock_target(target)
				combat_automation.set_option("fire", true)
				_sync_combat_automation()
				ui.notify("交战指令已接受：接近并在武器条件满足时开火。")
		"combat_toggle":
			if auto_fire_target == target:
				combat_automation.set_option("fire", false)
				ui.notify("已停止自动开火。")
			elif _combat_target_valid(target):
				combat_automation.lock_target(target)
				combat_automation.set_option("fire", true)
				ui.target_id = target
				ui.notify("自动开火已开启：仅在射程、射界与视线满足时执行。")
			else:
				ui.notify("需选择探测范围内的存活敌舰，并安装可用武器。", true)
			_sync_combat_automation()
		"interact", "interact_target": _interact(target)
		"show_ship":
			if state == null or world == null or camera == null or state.ship().status != Types.ShipStatus.FLYING or ui.keyboard_blocked(): return
			_release_observation()
			camera.bind(world.flight, store.catalog, Types.CameraMode.FOLLOW)
			state.player().camera_mode = camera.mode
			_center_steering()
			camera.step(0.0)
			ui.update_camera_status()
		"new_world":
			source_goal.clear()
			if not services_ready:
				ui.notify("存档服务未就绪，无法新建远征。", true)
				return
			busy = true
			_sync_combat_automation()
			ui.set_operation_status("load", "正在建立远征")
			ui.notify("正在建立远征")
			await get_tree().process_frame
			var created := store.new_world(target.strip_edges() if not target.strip_edges().is_empty() else "断航远征", int(Time.get_unix_time_from_system()), _prepare_loaded)
			if created != null:
				_activate(created)
				ui.notify("远征已建立，选择任务与合同开始教学。")
			else:
				_discard_staged()
				ui.notify("新建世界失败，已有档案保留。", true)
				push_error(store.last_error + " " + last_error)
			busy = false
			_sync_combat_automation()
			ui.set_operation_status("idle", "")
		"load":
			source_goal.clear()
			busy = true
			_sync_combat_automation()
			ui.set_operation_status("load", "正在验证存档并准备星系")
			ui.notify("验证存档并准备星系")
			await get_tree().process_frame
			var loaded := store.load(target, extra, quantity, _prepare_loaded)
			if loaded != null:
				loaded = _upgrade_loaded(loaded)
				_activate(loaded)
				ui.notify("存档已读取。")
			else:
				_discard_staged()
				ui.notify("读档失败，当前世界与原档案保留。", true)
				push_error(store.last_error)
			busy = false
			_sync_combat_automation()
			ui.set_operation_status("idle", "")
		"continue":
			busy = true
			_sync_combat_automation()
			ui.set_operation_status("load", "正在恢复上次航行")
			await get_tree().process_frame
			var resumed := store.resume(_prepare_loaded)
			if resumed != null:
				resumed = _upgrade_loaded(resumed)
				_activate(resumed)
			else:
				_discard_staged()
				ui.notify("恢复航行失败，原档案保留。", true)
				push_error(store.last_error)
			busy = false
			_sync_combat_automation()
			ui.set_operation_status("idle", "")
		"save": _request_save(extra, int(target))
		"cancel_save":
			deferred_save = {}
			_sync_combat_automation()
			ui.set_operation_status("idle", "")
			ui.notify("已取消等待中的保存请求。")
		"quit_without_save":
			deferred_save = {}
			get_tree().quit()
		"hangar_focus":
			if hangar != null and state != null and state.ship().status == Types.ShipStatus.DOCKED:
				hangar.focus_service(target)
		"quit", "return_title":
			if state == null:
				if action == "quit": get_tree().quit()
				return
			_request_save("auto", auto_slot, action)
		"preference":
			var value: Variant = extra if target == "quality_mode" else float(extra)
			if store.set_preference(target, value):
				preferences = store.preferences()
				_apply_preferences()
		_: _business_action(action, target, quantity, extra)

func _business_action(action: String, target: String, quantity: int, extra: String) -> void:
	if state == null or travel.active():
		ui.notify("当前无法执行此操作。", true)
		return
	if local_navigation != null and local_navigation.warp_active():
		ui.notify("本星系跃迁中，请先停船取消。", true)
		return
	if action == "open_salvage":
		_identify_salvage(target, quantity)
		return
	if action=="hire_action" and (target=="dismiss" or not gameplay.hired.profile(target).is_empty()):
		_hire_financial(target,quantity,extra)
		return
	if action=="crew_action" or (action=="owned_fleet_action" and extra.get_slice("|",0) in ["deploy","recover"]):
		_commit_fleet_action(action,target,quantity,extra,"船员与自有编队")
		return
	if action=="growth_claim" or (action=="start_war" and gameplay.march.supported()):
		_commit_fleet_action(action,target,quantity,extra,"整备款" if action=="growth_claim" else "舰队整备")
		return
	if ui.page == "warehouse" and action in ["move_stack", "move_item", "move_salvage"]:
		var kind: String = {"move_stack": "stack", "move_item": "item", "move_salvage": "salvage"}[action]
		var quote: Dictionary = gameplay.get("inventory").call("quote_transfer", kind, target, quantity, extra)
		if not bool(quote.ok):
			ui.notify(str(quote.reason), true)
			return
	if action in ["dock", "request_rescue", "undock", "switch_ship"]:
		if world.projectiles.has_pending() or not pending_damage.is_empty():
			world.projectiles.recall_drones()
			ui.notify("等待在途攻击结束、无人机回收后再停靠或切换舰船。", true)
			return
		_reset_combat_automation()
		if local_navigation != null and local_navigation.active(): local_navigation.cancel()
	var previous_ship := state.ship().ship_instance_id
	var actor: RefCounted = gameplay
	var rescue_candidate: XJRuntimeState
	if action == "request_rescue":
		# A rescue may cross sectors. Prepare its complete candidate before publishing.
		rescue_candidate = store.clone_state(state)
		actor = preload("res://runtime/gameplay.gd").new()
		actor.call("setup", rescue_candidate, store.catalog)
	var result: Dtos.ActionResultDto = actor.call("act", action, target, quantity, extra)
	var feedback: String = str(actor.get("status_text")) if result.phase == Types.ActionPhase.APPLIED else str(actor.get("last_error"))
	if rescue_candidate != null:
		actor.call("dispose")
		if result.phase == Types.ActionPhase.APPLIED:
			if not _stage_candidate(rescue_candidate, store.catalog):
				ui.notify("救援目的地暂时无法准备，保留原世界。", true)
				return
			_activate(rescue_candidate)
	if result.phase == Types.ActionPhase.APPLIED:
		if presentation != null: presentation.ui_result(true)
		ui.notify(feedback)
		if state.ship().ship_instance_id != previous_ship and world.flight.record.ship_instance_id != state.ship().ship_instance_id:
			if world.rebuild_player():
				camera.bind(world.flight, store.catalog, state.player().camera_mode)
			else:
				ui.show_page("pause")
				ui.notify(world.last_error, true)
				return
		if action in ["dock", "undock", "switch_ship", "request_rescue"]:
			if world.flight.record.ship_instance_id == state.ship().ship_instance_id:
				world.flight.bind(state.ship(), store.catalog)
			ui.show_page("station" if state.player().has_docked_station_id else "")
		if not result.autosave_request_id.is_empty():
			_queue_autosave()
		ui.refresh_page()
		if action == "accept_mission": ui.show_mission(target)
		if action == "undock": _mission_navigation("mission_locate", "", false)
	else:
		if presentation != null: presentation.ui_result(false)
		ui.notify(feedback, true)

func _hire_financial(target: String,quantity: int,extra: String) -> void:
	_commit_fleet_action("hire_action",target,quantity,extra,"雇佣合同")

func _commit_fleet_action(action: String,target: String,quantity: int,extra: String,label: String) -> void:
	var blocked: String=_save_block_reason()
	if not blocked.is_empty():ui.notify("等待%s结束后提交%s。" % [blocked,label],true);return
	var candidate: XJRuntimeState=store.clone_state(state)
	if candidate==null:ui.notify("无法准备%s，资金保留。" % label,true);return
	var actor: RefCounted=preload("res://runtime/gameplay.gd").new();actor.setup(candidate,store.catalog)
	var result: Dtos.ActionResultDto=actor.act(action,target,quantity,extra)
	var feedback: String=str(actor.status_text) if result.phase==Types.ActionPhase.APPLIED else str(actor.last_error)
	actor.dispose()
	if result.phase!=Types.ActionPhase.APPLIED:ui.notify(feedback,true);return
	var old_page: String=ui.page;busy=true;_sync_combat_automation();ui.set_operation_status("save","正在提交"+label)
	if not _stage_candidate(candidate,store.catalog) or not store.save(candidate,"auto",auto_slot):
		_discard_staged();busy=false;_sync_combat_automation();ui.set_operation_status("idle","");ui.notify("操作未提交，原舰船、船员与资金保留。"+store.last_error,true);return
	auto_slot=(auto_slot+1)%3;_activate(candidate);busy=false;_sync_combat_automation();ui.set_operation_status("idle","");ui.show_page(old_page);ui.notify(feedback)

func _identify_salvage(package_id: String, quantity: int) -> void:
	# Identification consumes the sealed package, awards its frozen result and
	# records its receipt on a detached candidate. No success reaches the UI
	# until the complete snapshot and resume pointer have committed.
	var candidate: XJRuntimeState = store.clone_state(state)
	if candidate == null:
		ui.notify("无法准备鉴定，回收包保留。", true)
		return
	var actor: RefCounted = preload("res://runtime/gameplay.gd").new()
	actor.call("setup", candidate, store.catalog)
	var result: Dtos.ActionResultDto = actor.call("act", "open_salvage", package_id, quantity)
	var feedback: String = str(actor.get("status_text")) if result.phase == Types.ActionPhase.APPLIED else str(actor.get("last_error"))
	actor.call("dispose")
	if result.phase != Types.ActionPhase.APPLIED:
		ui.notify(feedback, true)
		return
	var old_page: String = ui.page
	busy = true
	_sync_combat_automation()
	ui.set_operation_status("save", "正在提交打捞鉴定")
	if not _stage_candidate(candidate, store.catalog) or not store.save(candidate, "auto", auto_slot):
		_discard_staged()
		busy = false
		_sync_combat_automation()
		ui.set_operation_status("idle", "")
		ui.notify("鉴定未提交，回收包与资金保留。" + store.last_error, true)
		return
	auto_slot = (auto_slot + 1) % 3
	_activate(candidate)
	busy = false
	_sync_combat_automation()
	ui.set_operation_status("idle", "")
	ui.show_page(old_page)
	ui.notify(feedback)

func _stage_candidate(candidate: XJRuntimeState, definitions: XJCatalog) -> bool:
	_discard_staged()
	var source := load("res://runtime/gameplay.gd") as Script
	if source == null:
		last_error = "玩法模块加载失败"
		return false
	staged_gameplay = source.new()
	staged_gameplay.call("setup", candidate, definitions)
	staged_world = XJSector.new()
	staged_world.visible = false
	add_child(staged_world)
	if not staged_world.build(candidate, definitions, staged_gameplay):
		last_error = staged_world.last_error
		_discard_staged()
		return false
	return true

func _prepare_loaded(candidate: XJRuntimeState) -> bool:
	return _stage_candidate(candidate, store.staging_catalog)

func _upgrade_loaded(candidate: XJRuntimeState) -> XJRuntimeState:
	# Keep the original validated staging scene until the complete replacement
	# commits. Failed new construction must never require rebuilding the fallback.
	var previous_world: XJSector = staged_world
	var previous_gameplay: RefCounted = staged_gameplay
	staged_world = null; staged_gameplay = null
	var upgraded: XJRuntimeState = store.upgrade_content(candidate, _prepare_loaded)
	if upgraded == candidate:
		staged_world = previous_world; staged_gameplay = previous_gameplay
		return candidate
	if upgraded != null:
		if is_instance_valid(previous_world): remove_child(previous_world); previous_world.queue_free()
		if previous_gameplay != null: previous_gameplay.call("dispose")
		return upgraded
	# Failure preserves the validated original world and all its save pointers.
	ui.notify("新版内容未能安全升级；继续使用原档案。" + store.last_error, true)
	_discard_staged()
	staged_world = previous_world; staged_gameplay = previous_gameplay
	return candidate

func _mission_navigation(action: String, mission_id: String, announce: bool = true) -> void:
	if state == null or world == null or gameplay == null: return
	var missions: RefCounted = gameplay.get("missions")
	var info: Dictionary = missions.station_guidance(mission_id) if action == "mission_station" else missions.guidance(mission_id)
	if info.is_empty():
		if announce: ui.notify("当前没有可定位的任务；可在任务与合同中查看教学或主线。")
		return
	if state.ship().status == Types.ShipStatus.DOCKED:
		if info.get("local", false) and str(info.get("target_id", "")) == gameplay.call("station"):
			var service: String = str(info.get("required_page", ""))
			if not service.is_empty(): ui.show_page(service)
			elif announce: ui.show_mission(str(info.mission_id))
		if announce: ui.notify("任务地点：" + str(info.target_title) + "；出港后可按“前往”导航。")
		return
	_navigate_guidance(info, action == "mission_travel", announce)

func _source_navigation(action: String, key: String, item_id: String) -> void:
	if state == null or gameplay == null or busy or travel.active(): return
	var info: Dictionary = gameplay.resource_intel.guidance(key, item_id)
	if info.is_empty(): ui.notify("物资来源已失效，请重新查询。", true); return
	if action == "source_map":
		ui.show_page("map")
		if is_instance_valid(ui.resource_chart): ui.resource_chart.select_sector(info.sector_id)
		return
	if state.ship().status != Types.ShipStatus.FLYING:
		ui.notify("请先出港，再从星图的物资来源继续导航。", true); return
	if not str(info.route_reason).is_empty(): ui.notify(str(info.route_reason), true); return
	source_goal = {"world": state.world_id, "key": key, "item": item_id}
	_navigate_guidance(info, true, true, true)

func _source_after_arrival() -> void:
	await get_tree().process_frame
	if not source_goal.is_empty() and state != null and source_goal.world == state.world_id and not busy:
		if source_goal.has("growth"):_growth_navigation("growth_navigate",source_goal.growth,str(source_goal.activity))
		elif source_goal.has("frontier"):_frontier_navigation("frontier_navigate",source_goal.frontier,gameplay.frontier.expected_token(source_goal.frontier))
		elif source_goal.has("consignment"): _consignment_navigation("consignment_navigate",source_goal.consignment,str(source_goal.generation))
		elif source_goal.has("operation"): _operation_navigation("operation_nav",source_goal.operation,str(source_goal.generation))
		elif source_goal.has("event"): _exploration_navigation("exploration_nav", source_goal.event, str(source_goal.generation))
		elif source_goal.has("demand"): _demand_navigation(source_goal.demand)
		elif source_goal.has("campaign"):_campaign_navigation("campaign_navigate",source_goal.campaign,source_goal.token)
		elif source_goal.has("scenario"):_scenario_navigation("scenario_navigate",source_goal.scenario,source_goal.token)
		else: _source_navigation("source_travel", source_goal.key, source_goal.item)

func _drone_order(kind: String, target: String) -> void:
	if travel.active() or local_navigation.warp_active(): ui.notify("航行转移期间先等待无人机稳定回收。", true); return
	var result: Dtos.ActionResultDto = gameplay.act("drone_command", target, 1, kind)
	if result.phase != Types.ActionPhase.APPLIED: ui.notify(str(result.display_reason_key), true); return
	var launched: bool = false
	if kind == "recall": world.projectiles.recall_drones()
	else:
		var target_id: String = target if kind == "attack" else state.ship().ship_instance_id
		var target_node: Node3D = world.targets[target].node if kind == "attack" and world.targets.has(target) else world.flight
		for equipment: RefCounted in gameplay.equipped(state.ship()):
			var profile: Dictionary = gameplay.weapon_profile(equipment.module_def_id)
			if profile.get("fire_mode", "") != "drone" or not equipment.enabled or world.projectiles.module_busy(equipment.item_instance_id): continue
			var module: Dictionary = store.catalog.one("module_defs", "module_id", equipment.module_def_id)
			if kind == "attack" and (not world.target_is_local(target) or world.flight.global_position.distance_to(target_node.global_position) > float(module.range_m)): continue
			var slot: RefCounted = state.find("container_state", "container_id", equipment.slot_container_id)
			var origin: Transform3D = world.flight.muzzle(slot.slot_index)
			if kind == "attack" and not world.line_of_sight(origin.origin, target_node.global_position, world.flight.get_rid(), target): continue
			var cycle: Dictionary = gameplay.consume_weapon_cycle(equipment.item_instance_id)
			if cycle.is_empty(): continue
			var direction: Vector3 = origin.origin.direction_to(target_node.global_position) if kind == "attack" else -origin.basis.z
			world.projectiles.fire(state.ship().ship_instance_id, world.flight.get_rid(), origin.origin, direction, float(cycle.speed), float(cycle.range), cycle.damage_vector, cycle.profile, equipment.item_instance_id, target_id)
			launched = true
	ui.notify({"attack":"无人机攻击指令已下达。","follow":"无人机跟随指令已下达；本次仍只有一次已支付攻击。","recall":"无人机正在回收，尚未发出的攻击已停止。"}.get(kind, "无人机指令已更新。"))
	if kind != "recall" and not launched and gameplay.drone_control.live.is_empty(): ui.notify("指令已更新；机库冷却或电容不足，满足条件后可再次出击。",true)
	ui.refresh_page()

func _growth_navigation(action: String,stage_id: String,selection: String) -> void:
	if state==null or gameplay==null or busy or travel.active() or not selection.is_valid_int():return
	var index: int=int(selection)
	var info: Dictionary=gameplay.growth.guidance(stage_id,index)
	if info.is_empty():ui.notify("此成长途径暂不可用。",true);return
	if action=="growth_map" or state.ship().status!=Types.ShipStatus.FLYING:
		ui.show_page("map")
		if ui.resource_chart!=null:ui.resource_chart.select_sector(str(info.sector_id));ui.resource_chart.call("focus_selected")
		return
	if not str(info.get("route_reason","")).is_empty():ui.notify(str(info.route_reason),true);return
	source_goal={"world":state.world_id,"growth":stage_id,"activity":index}
	_navigate_guidance(info,true,true,true)

func _growth_open(stage_id: String,selection: String) -> void:
	if state==null or gameplay==null or busy or not selection.is_valid_int():return
	var stage: Dictionary=gameplay.definition("growth_stage_defs","stage_id",stage_id)
	var selected: Dictionary=gameplay.growth.activity(stage_id,int(selection))
	if stage.is_empty() or selected.is_empty():return
	if stage.faction_id!=null:ui.civilization_selected_faction=str(stage.faction_id)
	var page: String=gameplay.growth.service_page(stage_id,int(selection))
	ui.show_page(page)
	if page=="civilizations":
		var focus_name: String="CommanderRegister" if selected.activity_kind=="honor_register" else "CommanderCertify" if selected.activity_kind=="honor" else "CivilizationJoin" if stage.criterion_kind=="membership" else "CivilizationWar_"+str(stage.reference_id) if selected.activity_kind=="war" else ""
		if not focus_name.is_empty():
			var control: Control=ui.find_child(focus_name,true,false) as Control
			if is_instance_valid(control):
				control.grab_focus();var parent: Node=control.get_parent()
				while parent!=null:
					if parent is ScrollContainer:parent.ensure_control_visible(control);break
					parent=parent.get_parent()

func _frontier_navigation(action: String,id: String,expected: String) -> void:
	if state==null or gameplay==null or busy or travel.active():return
	if expected!=gameplay.frontier.expected_token(id):ui.notify("边疆阶段已变化，请重新查看。",true);return
	var info: Dictionary=gameplay.frontier.guidance(id)
	if info.is_empty():return
	if action=="frontier_map" or state.ship().status!=Types.ShipStatus.FLYING:
		ui.show_page("map")
		if ui.resource_chart!=null:ui.resource_chart.select_sector(str(info.sector_id));ui.resource_chart.call("focus_selected")
		return
	if not str(info.get("route_reason","")).is_empty():ui.notify(str(info.route_reason),true);return
	source_goal={"world":state.world_id,"frontier":id}
	if str(info.get("target_kind",""))=="npc" and world.targets.has(str(info.waypoint_id)) and world.target_is_local(str(info.waypoint_id)):
		ui._select_target(str(info.waypoint_id));_navigation_command("approach",str(info.waypoint_id));return
	_navigate_guidance(info,true,true,true)

func _consignment_navigation(action: String,id: String,generation: String) -> void:
	if state == null or gameplay == null or busy or travel.active(): return
	var row: RefCounted=gameplay.consignments.instance(id)
	if row==null or str(row.generation)!=generation: ui.notify("承运合同已更新，请重新查看。",true);return
	var info: Dictionary=gameplay.consignments.guidance(id)
	if info.is_empty():return
	if action=="consignment_map" or state.ship().status!=Types.ShipStatus.FLYING:
		ui.show_page("map")
		if is_instance_valid(ui.resource_chart):ui.resource_chart.select_sector(info.sector_id)
		if action!="consignment_map":ui.notify("已标记目的站；出港后可前往。")
		return
	if not str(info.route_reason).is_empty():ui.notify(str(info.route_reason),true);return
	source_goal={"world":state.world_id,"consignment":id,"generation":row.generation}
	_navigate_guidance(info,true,true,true)

func _operation_navigation(action: String, id: String, generation: String) -> void:
	if state == null or gameplay == null or busy or travel.active(): return
	var row: RefCounted = gameplay.operations.instance(id)
	if row == null or str(row.generation) != generation: ui.notify("行动代次已变化，请重新查看。",true); return
	var info: Dictionary = gameplay.operations.guidance(id)
	if info.is_empty(): return
	if action == "operation_map":
		ui.show_page("map")
		if is_instance_valid(ui.resource_chart): ui.resource_chart.select_sector(info.sector_id)
		return
	if state.ship().status != Types.ShipStatus.FLYING: ui.notify("出港后可前往行动地点。",true); return
	if not str(info.route_reason).is_empty(): ui.notify(str(info.route_reason),true); return
	source_goal = {"world":state.world_id,"operation":id,"generation":row.generation}
	_navigate_guidance(info,true,true,true)

func _exploration_navigation(action: String, event_id: String, generation: String) -> void:
	if state == null or gameplay == null or busy or travel.active(): return
	var row: RefCounted = gameplay.exploration.instance(event_id)
	if row == null or generation != str(row.generation): ui.notify("事件代次已变化，请重新查看线索。", true); return
	var info: Dictionary = gameplay.exploration.guidance(event_id)
	if info.is_empty(): return
	if action == "exploration_map":
		ui.show_page("map")
		if is_instance_valid(ui.resource_chart): ui.resource_chart.select_sector(info.sector_id)
		return
	if state.ship().status != Types.ShipStatus.FLYING: ui.notify("出港后可前往事件或交付地点。", true); return
	if not str(info.route_reason).is_empty(): ui.notify(str(info.route_reason), true); return
	source_goal = {"world": state.world_id, "event": event_id, "generation": row.generation}
	_navigate_guidance(info, true, true, true)

func _exploration_warning(message: String) -> void:
	if ui != null: ui.notify(message, true)
	if presentation != null: presentation.ui_result(false)

func _tactical_warning(message: String) -> void:
	# Important ongoing states have typed cues; prose is never a severity parser.
	if ui != null: ui.notify(message)

func _tactical_feedback(kind: String, message: String) -> void:
	if gameplay.situational.supported() and kind in ["charging","jam"]:return
	if ui!=null:ui.notify(message,kind!="interrupted")
	if presentation!=null:presentation.ui_result(kind=="interrupted")

func _situational_cue(cue: Dictionary) -> void:
	if presentation != null: presentation.situational_cue(cue)

func _scenario_navigation(action: String,target: String,expected: String) -> void:
	if state==null or gameplay==null or busy or travel.active():return
	var parts: PackedStringArray=target.split(":",true,2)
	if parts.size()<2 or parts[0] not in ["trial","blockade"]:return
	if expected!=gameplay.scenarios.token(parts[0],parts[1]):ui.notify("行动代次已变化，请刷新",true);return
	var info: Dictionary=gameplay.scenarios.guidance(parts[0],parts[1],int(parts[2]) if parts.size()==3 else -1)
	if info.is_empty():return
	if action=="scenario_map":ui.show_page("map");ui.resource_chart.select_sector(info.sector_id);return
	if state.ship().status!=Types.ShipStatus.FLYING:ui.notify("出港后可前往目标");return
	if not str(info.route_reason).is_empty():ui.notify(info.route_reason,true);return
	source_goal={"world":state.world_id,"scenario":target,"token":expected};_navigate_guidance(info,true,true,true)

func _campaign_navigation(action: String,target: String,expected: String) -> void:
	if state==null or gameplay==null or busy or travel.active():return
	var parts: PackedStringArray=target.split(":",true,1)
	if parts.size()!=2:return
	var info: Dictionary={}
	if parts[0]=="expedition":
		var run: RefCounted=gameplay.expeditions.active()
		if run==null or run.run_id!=parts[1] or gameplay.expeditions.token(run.run_id)!=expected:ui.notify("远征阶段已变化，请刷新",true);return
		info=gameplay.expeditions.guidance()
	elif parts[0]=="project":
		if gameplay.projects.token(parts[1])!=expected:ui.notify("工程阶段已变化，请刷新",true);return
		var def: Dictionary=gameplay.projects.definition(parts[1])
		if not def.is_empty():info=gameplay.missions._route_location(gameplay.missions._station_location(def.station_id),"")
	elif parts[0]=="station":info=gameplay.missions._route_location(gameplay.missions._station_location(parts[1]),"")
	if info.is_empty():return
	if action=="campaign_map":
		ui.show_page("map");ui.resource_chart.select_sector(info.sector_id);return
	if state.ship().status!=Types.ShipStatus.FLYING:ui.notify("出港后可前往当前目标");return
	if not str(info.route_reason).is_empty():ui.notify(info.route_reason,true);return
	source_goal={"world":state.world_id,"campaign":target,"token":expected}
	_navigate_guidance(info,true,true,true)

func _export_flight_report(format: String) -> void:
	if gameplay==null or not gameplay.telemetry.supported() or format not in ["csv","json"]:return
	var directory: String=ProjectSettings.globalize_path(store.path).get_base_dir().path_join("reports")
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:ui.notify("无法创建报告目录",true);return
	var stamp: String=Time.get_datetime_string_from_system(true).replace(":","")
	var filename: String="flight-report-"+stamp+"-"+Crypto.new().generate_random_bytes(4).hex_encode()+"."+format
	var output: FileAccess=FileAccess.open(directory.path_join(filename),FileAccess.WRITE)
	if output==null:ui.notify("无法写入报告",true);return
	var reports: Array[Dictionary]=gameplay.telemetry.export_rows()
	var total: Dictionary=gameplay.telemetry.export_total()
	var measurements: Dictionary=gameplay.journal.export_data()
	if format=="json":output.store_string(JSON.stringify({"format_version":3,"totals":total,"reports":reports,"measurements":measurements},"\t"))
	else:
		output.store_buffer(PackedByteArray([239,187,191]))
		var columns: PackedStringArray=["record_type","sequence","hull","status","partial_baseline","outings","lost_outings","income_credit","spent_credit","elapsed_s","combat_s","transit_s","flight_income","flight_spent","return_income","return_spent","mined_units","kills","damage_dealt","damage_taken","weapon_cycles","drone_losses","activity_count","materials_used","materials_returned","repair_hp","kind","object_id","phase","outcome","reason","item_id","source","units","page","duration_s","visits","count","navigation_wait_s"]
		output.store_csv_line(columns)
		total["record_type"]="lifetime"
		var rows: Array[Dictionary]=[total]
		for report: Dictionary in reports:report["record_type"]="outing";rows.append(report)
		for section: String in ["sources","activities","activity_totals","menus"]:
			for measured: Dictionary in measurements[section]:
				measured["record_type"]=section;rows.append(measured)
		rows.append({"record_type":"timing","navigation_wait_s":measurements.navigation_wait_s})
		for report: Dictionary in rows:
			var values: PackedStringArray=[]
			for column: String in columns:
				var value: Variant=report.get(column,"");values.append(JSON.stringify(value) if value is Dictionary or value is Array else str(value))
			output.store_csv_line(values)

	output.close();ui.notify("已导出游戏报告："+directory.path_join(filename))

func _demand_navigation(id: String) -> void:
	if state == null or gameplay == null or busy or travel.active(): return
	var spec: Dictionary = gameplay.definition("station_demand_defs","demand_id",id)
	if spec.is_empty(): return
	var info: Dictionary = gameplay.missions._route_location(gameplay.missions._station_location(spec.station_id),"")
	if state.ship().status != Types.ShipStatus.FLYING: ui.notify("出港后可前往需求站；到站重新确认报价。"); return
	if not str(info.get("route_reason","")).is_empty(): ui.notify(info.route_reason,true); return
	source_goal = {"world":state.world_id,"demand":id}
	_navigate_guidance(info,true,true,true)

func _hire_warning(message: String) -> void:
	var critical: bool = false
	if gameplay != null and state != null:
		for row: RefCounted in state.rows("hire_contract_state"):
			if row.phase=="lost" and row.finished_tick==state.snapshot.meta.simulation_tick: critical=true
		var active: RefCounted = gameplay.hired.active()
		if active!=null and active.phase in ["deployed","retreating"] and not gameplay.hired.connected(active): critical=true
	if ui!=null:ui.notify(message,critical)
	if presentation!=null:presentation.ui_result(not critical)
func _hire_healed(npc_id: String,ship_id: String,layer: String) -> void:
	if presentation!=null:presentation.companion_support(npc_id,ship_id,layer)

func _navigate_guidance(info: Dictionary, do_travel: bool, announce: bool, approach_destination: bool = false) -> void:
	world.sync_entities()
	var id: String = str(info.get("waypoint_id", ""))
	if id.is_empty() or not world.targets.has(id):
		var reason: String = str(info.get("route_reason", ""))
		if announce: ui.notify(reason if not reason.is_empty() else "目的地暂不可达，请重新查看地点与航路条件。", true)
		return
	ui.show_page("")
	ui._select_target(id)
	ui._update_mission_guidance()
	if camera != null:
		var direction: Vector3 = world.target_direction(id)
		if direction.length_squared() > 0.000001:
			_release_observation()
			camera.orbit = Vector2.ZERO
			camera.observation_basis = Basis.looking_at(direction, Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
	if announce: ui.notify("已定位：" + str(info.waypoint_title) + (" · " + str(info.route_reason) if not str(info.route_reason).is_empty() else ""))
	if do_travel:
		var context: Dictionary = navigation_context(id)
		_navigation_command("approach" if approach_destination else "warp" if bool(context.get("warp_ready", false)) else "approach", id)

func _prepare_travel(candidate: XJRuntimeState) -> bool:
	return _stage_candidate(candidate, store.catalog)

func _record_arrival(candidate: XJRuntimeState, connection_id: String) -> void:
	var source := load("res://runtime/gameplay.gd") as Script
	var business: RefCounted = source.new()
	business.call("setup", candidate, store.catalog)
	business.call("record_event", "transit_connection", connection_id, 1)
	business.hired.follow_arrival()
	if business.has_method("dispose"):
		business.call("dispose")

func _activate(candidate: XJRuntimeState) -> void:
	if not source_goal.is_empty() and source_goal.world != candidate.world_id: source_goal.clear()
	# All fallible construction happened in staging before the durable boundary.
	if is_instance_valid(warp_visual): warp_visual.unbind()
	if world != null:
		remove_child(world)
		world.queue_free()
	if gameplay != null and gameplay.has_method("dispose"):
		gameplay.call("dispose")
	state = candidate
	world = staged_world
	gameplay = staged_gameplay
	staged_world = null
	staged_gameplay = null
	world.visible = true
	world.apply_visual_quality(str(preferences.get("quality_mode", "high")))
	if world.tactical_view != null: world.tactical_view.intensity = float(preferences.get("vfx_intensity", 1.0))
	last_destroyed_ship = ""
	presentation = XJPresentation.new()
	world.add_child(presentation)
	presentation.setup(world, gameplay, store.catalog, float(preferences.get("vfx_intensity", 1.0)))
	world.projectiles.hit.connect(_weapon_hit)
	world.projectiles.surface_impact.connect(_surface_impact)
	gameplay.call("set_spatial_validator", _spatial_valid)
	gameplay.owned_fleet.pending_attacks=_owned_attacks_pending
	gameplay.auxiliary_drones.prepare=world.projectiles.prepare_auxiliary
	gameplay.auxiliary_drones.publish=world.projectiles.publish_auxiliary
	gameplay.auxiliary_drones.discard=world.projectiles.discard_auxiliary
	gameplay.auxiliary_drones.target_query=world.projectiles.auxiliary_target
	gameplay.auxiliary_drones.sight_query=world.projectiles.auxiliary_sight
	travel = XJTravel.new()
	travel.setup(state, store, _prepare_travel, _record_arrival, _travel_stable)
	travel.changed.connect(_travel_changed)
	auto_fire_target = ""
	local_navigation = XJLocalNavigation.new()
	navigation_generation += 1
	if not local_navigation.configure(world, state, store.catalog, gameplay, _travel_stable):
		ui.notify(local_navigation.last_error, true)
	local_navigation.changed.connect(_local_navigation_changed)
	local_navigation.arrived.connect(_local_navigation_arrived)
	camera.bind(world.flight, store.catalog, state.player().camera_mode)
	var visual_rules := XJWarpPresentationRules.new()
	if visual_rules.load_rules():
		if not world.configure_warp_projection(visual_rules.parameters): ui.notify(world.last_error, true)
		if not warp_visual.bind(world, camera, visual_rules.parameters): ui.notify(warp_visual.last_error, true)
	else: ui.notify(visual_rules.last_error, true)
	ui.slots = store.list_slots()
	ui.bind(state, store.catalog, gameplay, world, camera)
	gameplay.civilizations.status_changed.connect(_civilization_status)
	gameplay.exploration.warning_changed.connect(_exploration_warning)
	gameplay.specializations.warning_changed.connect(_tactical_warning)
	gameplay.ship_roles.warning_changed.connect(_tactical_warning)
	gameplay.consignments.warning_changed.connect(_tactical_warning)
	gameplay.honors.warning_changed.connect(_tactical_warning)
	gameplay.frontier.warning_changed.connect(_tactical_warning)
	gameplay.hired.warning_changed.connect(_hire_warning)
	gameplay.hired.healed.connect(_hire_healed)
	gameplay.operations.warning_changed.connect(_tactical_warning)
	gameplay.tactics.feedback_changed.connect(_tactical_feedback)
	gameplay.drone_control.warning_changed.connect(_tactical_warning)
	gameplay.situational.cue_started.connect(_situational_cue)
	gameplay.projects.changed.connect(_tactical_warning)
	gameplay.expeditions.changed.connect(_tactical_warning)
	gameplay.scenarios.changed.connect(_tactical_warning)
	combat_automation = CombatAutomation.new()
	combat_automation.changed.connect(_sync_combat_automation)
	combat_automation.acquired.connect(_combat_acquired)
	combat_automation.configure(self)
	presentation_stage = ""
	deferred_save = {}
	brake_hold.clear()
	pending_damage.clear()
	autosave_elapsed = 0.0
	player_damage_targets.clear(); owned_damage_targets.clear()
	_release_controls()
	_center_steering()
	_sync_presentation_stage()

func _civilization_status(message: String) -> void:
	ui.notify(message)
	if ui.page in ["civilizations", "map"]: ui.refresh_page.call_deferred()

func _civilization_navigation(action: String, faction: String) -> void:
	if state == null or not gameplay.civilizations.supported(): return
	var destination: String = ""
	if action == "civilization_map":
		destination = str(store.catalog.one("civilization_defs", "faction_id", faction).get("capital_sector_id", ""))
	else:
		var war: RefCounted = gameplay.civilizations.active_war()
		if war == null: return
		var definition: Dictionary = store.catalog.one("civilization_war_defs", "war_id", war.war_id)
		destination = str(definition.target_sector_id)
		if destination == state.current_sector() and state.ship().status == Types.ShipStatus.FLYING:
			var encounter: Dictionary = store.catalog.one("encounter_defs", "anchor_id", definition.capture_anchor_id)
			var target: String = "encounter:" + str(encounter.get("encounter_id", ""))
			if world.targets.has(target):
				ui.show_page("")
				ui._select_target(target)
				ui.notify("战区已定位 · 跃迁或接近目标后率领舰队清场。")
				return
	if destination.is_empty(): return
	ui.show_page("map")
	if is_instance_valid(ui.resource_chart):
		ui.resource_chart.call("select_sector", destination)
		ui.resource_chart.call("focus_selected")

func _discard_staged() -> void:
	if is_instance_valid(staged_world):
		remove_child(staged_world)
		staged_world.queue_free()
	if staged_gameplay != null and staged_gameplay.has_method("dispose"):
		staged_gameplay.call("dispose")
	staged_world = null
	staged_gameplay = null

func _travel_changed(next_phase: int, message: String) -> void:
	if next_phase == Types.TravelPhase.PREPARING: _reset_combat_automation()
	_sync_combat_automation()
	ui.set_operation_status("travel" if travel.active() else "idle", message if travel.active() else "", next_phase == Types.TravelPhase.PREPARING)
	if next_phase == Types.TravelPhase.PREPARING and presentation != null:
		presentation.jump(true)
	ui.notify(message, next_phase == Types.TravelPhase.FAILED)
	if next_phase == Types.TravelPhase.COMMITTED:
		var destination := travel.ready_candidate
		_activate(destination)
		presentation.jump(false)
		ui.notify(message)
		if not source_goal.is_empty(): _source_after_arrival.call_deferred()
	elif next_phase == Types.TravelPhase.FAILED:
		_discard_staged()

func _spatial_valid(from: Vector3, to: Vector3, target: String) -> bool:
	return world.line_of_sight(from, to, world.flight.get_rid(), target)

func _travel_stable() -> bool:
	return not world.projectiles.has_pending() and pending_damage.is_empty() and bool(gameplay.call("save_eligible"))

func navigation_context(target_id: String) -> Dictionary:
	var result: Dictionary = local_navigation.inspect(target_id) if local_navigation != null else {"reason": "导航设备未就绪"}
	result["display_speed_mps"] = local_navigation.path_length_m / local_navigation.travel_duration_s if local_navigation != null and local_navigation.warp_active() and local_navigation.phase == "travel" and local_navigation.travel_duration_s > 0.0 else world.flight.velocity.length() if world != null else 0.0
	result["active"] = local_navigation != null and local_navigation.active()
	result["navigation_target_id"] = local_navigation.target_id if local_navigation != null else ""
	result["combat_ready"] = _combat_target_valid(target_id)
	result["combat_active"] = not target_id.is_empty() and auto_fire_target == target_id
	var locked: String = combat_automation.target_id if combat_automation != null else auto_fire_target
	result["combat_target_id"] = locked
	result["combat_target_title"] = str(world.targets[locked].title) if world != null and world.targets.has(locked) else ""
	result["combat_target_status"] = combat_automation.status if combat_automation != null else (_auto_fire_status(locked) if not locked.is_empty() else "")
	result["combat_options"] = combat_automation.options.duplicate() if combat_automation != null else {"fire": false, "orbit": false, "seek": false}
	result["combat_automation_phase"] = combat_automation.phase if combat_automation != null else "idle"
	result["combat_status"] = _auto_fire_status(target_id) if result.combat_active else ""
	result["combat_reason"] = "仅向探测范围内敌舰开火；需满足武器射程、射界、视线、电容及热量条件。"
	result["combat_engage_ready"] = bool(result.combat_ready) and bool(result.get("approach_ready", false))
	result["combat_engage_reason"] = str(result.get("approach_reason", "")) if not bool(result.get("approach_ready", false)) else ("需选择探测范围内的存活敌舰，并安装可用武器。" if not bool(result.combat_ready) else "")
	if busy or _exit_save_pending() or (travel != null and travel.active()) or (local_navigation != null and local_navigation.warp_active()):
		for key: String in ["warp_ready", "approach_ready", "orbit_ready", "dock_ready", "combat_ready", "combat_engage_ready"]: result[key] = false
		result["reason"] = "正在等待稳定保存后离开；取消保存请求后可继续操作" if _exit_save_pending() else "正在保存或读取进度，请稍候" if busy else "正在通过虫洞，请稍候" if travel != null and travel.active() else "正在本星系跃迁，X或停船可取消"
		for action: String in ["warp", "approach", "orbit", "dock", "combat", "combat_engage"]: result[action + "_reason"] = result.reason
	return result

func _navigation_command(mode: String, target_id: String, retain_combat_options: bool = false) -> bool:
	if state == null or local_navigation == null or busy or _exit_save_pending() or ui.keyboard_blocked(): return false
	if travel != null and travel.active():
		ui.notify("请等待虫洞传送结束。", true)
		return false
	if local_navigation.warp_active():
		ui.notify("本星系跃迁中，请先用X或停船取消。", true)
		return false
	if _manual_navigation_override():
		ui.notify("请先释放手动操舰键，再执行自动导航。", true)
		return false
	var context := local_navigation.inspect(target_id)
	if not bool(context.get(mode + "_ready", false)):
		ui.notify(str(context.get(mode + "_reason", context.get("reason", "当前无法执行导航"))), true)
		return false
	var requires_warp: bool = mode == "warp" or (bool(context.get("remote_site", false)) and mode in ["approach", "dock"])
	if requires_warp:
		# The stable origin is durable before any movement or charge state begins.
		# Local navigation never borrows wormhole receipts or transfer barriers.
		if not _save_block_reason().is_empty():
			ui.notify("脱离交战、停止设备作业并等待航行结束后再跃迁。", true)
			return false
		if not store.save(state, "auto", auto_slot):
			ui.notify("出发进度保存失败，舰船保留在起点。", true)
			return false
		ui.slots = store.list_slots()
		auto_slot = (auto_slot + 1) % 3
	# An invalid replacement has already returned; only accepted commands hand
	# motion over, keeping ordinary navigation transitions physically continuous.
	if local_navigation.active(): local_navigation.release_to_manual(false)
	world.flight.clear_intent()
	flight_look.clear()
	ui.target_id = target_id
	navigation_generation += 1
	var accepted: bool = local_navigation.begin(mode, target_id)
	if accepted:
		if requires_warp: _reset_combat_automation(false)
		elif combat_automation != null and not retain_combat_options: combat_automation.relinquish_motion()
		_sync_combat_automation()
	return accepted

func _local_navigation_changed(_mode: String, phase: String, message: String) -> void:
	if local_navigation == null: return
	if gameplay != null:
		gameplay.ship_roles.spatial_active = not local_navigation.warp_active()
		gameplay.hired.spatial_active = not local_navigation.warp_active()
		gameplay.owned_fleet.spatial_active = not local_navigation.warp_active()
		gameplay.auxiliary_drones.spatial_active = not local_navigation.warp_active()
		if local_navigation.warp_active(): gameplay.ship_roles.stop_support()
	_sync_combat_automation()
	if local_navigation.warp_active():
		if deferred_save.is_empty(): ui.set_operation_status("local_navigation", message)
		if phase == "warmup" and presentation != null: presentation.jump(true)
	elif operation_kind_is_navigation():
		ui.set_operation_status("idle", "")
	if not message.is_empty(): ui.notify(message, phase == "failed")

func operation_kind_is_navigation() -> bool:
	return ui != null and ui.operation_kind == "local_navigation"

func _local_navigation_arrived(target_id: String) -> void:
	if local_navigation == null: return
	_finalize_local_arrival.call_deferred(target_id, local_navigation.mode, navigation_generation)

func _finalize_local_arrival(target_id: String, mode: String, generation: int) -> void:
	# Finish the physical tick before committing or docking; NPCs and device
	# cycles can change eligibility in the latter half of the arrival tick.
	while busy: await get_tree().process_frame
	if local_navigation == null or generation != navigation_generation or local_navigation.phase != "arrived" or local_navigation.target_id != target_id: return
	# Dock remains a separately revalidated business action at the safe boundary.
	if mode == "dock":
		_business_action("dock", target_id, 1, "")
	else:
		if presentation != null: presentation.jump(false)
		_queue_autosave()

func _manual_navigation_override() -> bool:
	return _keyboard_control_allowed() and flight_look.manual_override_requested(ui.combat_option_has_focus())

func _combat_selection_changed(target: String) -> void:
	if combat_automation != null: combat_automation.manual_selection(target)

func _combat_acquired(target: String) -> void:
	ui._select_target(target)

func _sync_combat_automation() -> void:
	if combat_automation == null or ui == null: return
	auto_fire_target = combat_automation.fire_target() if state != null and world != null else ""
	var blocked: bool = state == null or state.ship().status != Types.ShipStatus.FLYING or busy or _exit_save_pending() or (travel != null and travel.active()) or (local_navigation != null and local_navigation.warp_active())
	ui.set_combat_automation_status(combat_automation.options, combat_automation.status, blocked)
	# The target card shares the same accepted lock/status as the weapon row.
	if state != null and world != null: ui._update_navigation()

func _reset_combat_automation(release_motion: bool = true) -> void:
	if combat_automation != null: combat_automation.reset(release_motion)
	auto_fire_target = ""

func _enemy_target_valid(target_id: String) -> bool:
	if state == null or world == null or gameplay == null or state.ship().status != Types.ShipStatus.FLYING: return false
	if gameplay.civilizations.friendly(target_id): return false
	if travel != null and travel.active(): return false
	if local_navigation != null and local_navigation.warp_active(): return false
	if not world.targets.has(target_id): return false
	var target: Dictionary = world.targets[target_id]
	var node: Variant = target.get("node")
	if target.get("kind", "") not in ["npc","drone"] or not is_instance_valid(node) or not node.global_position.is_finite(): return false
	if target.get("kind", "") == "drone": return gameplay.drone_control.live.has(target_id) and world.target_is_local(target_id) and world.contact_visible(target, world.flight.global_position.distance_to(node.global_position))
	var npc: RefCounted = state.find("npc_state", "npc_instance_id", target_id)
	if npc == null or not npc.alive or npc.sector_id != state.current_sector(): return false
	return world.contact_visible(target, world.flight.global_position.distance_to(node.global_position))

func _combat_target_valid(target_id: String) -> bool:
	if not _enemy_target_valid(target_id): return false
	for equipment: RefCounted in gameplay.call("equipped", state.ship()):
		var definition: Dictionary = store.catalog.one("module_defs", "module_id", equipment.module_def_id)
		var item: RefCounted = state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
		if definition.get("slot_type", "") == "weapon" and equipment.enabled and item != null and item.durability > 0.0: return true
	return false

func _tick_auto_fire() -> void:
	if not _combat_target_valid(auto_fire_target):
		auto_fire_target = ""
		return
	var node: Node3D = world.targets[auto_fire_target].node
	var offset: Vector3 = node.global_position - world.flight.global_position
	if offset.length_squared() <= 0.0: return
	_fire_weapons(true, auto_fire_target)

func _auto_fire_status(target_id: String) -> String:
	if not _combat_target_valid(target_id): return "自动开火待机：目标不可用"
	var target: Node3D = world.targets[target_id].node
	var offset: Vector3 = target.global_position - world.flight.global_position
	if offset.is_zero_approx(): return "自动开火待机：目标重合"
	var ship: RefCounted = state.ship()
	if ship.overheated: return "自动开火待机：等待散热"
	var reason: String = "武器未就绪"
	for equipment: RefCounted in gameplay.call("equipped", ship):
		var definition: Dictionary = store.catalog.one("module_defs", "module_id", equipment.module_def_id)
		if definition.get("slot_type", "") != "weapon" or not equipment.enabled: continue
		var item: RefCounted = state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
		if item == null or item.durability <= 0.0: continue
		var profile: Dictionary = gameplay.call("weapon_profile", equipment.module_def_id)
		if profile.is_empty(): continue
		if str(profile.fire_mode) == "drone" and world.projectiles.module_busy(equipment.item_instance_id): reason = "无人机出击或回收中"; continue
		var slot: RefCounted = state.find("container_state", "container_id", equipment.slot_container_id)
		var muzzle: Transform3D = world.flight.muzzle(slot.slot_index)
		var range_origin: Vector3 = world.flight.global_position if str(profile.fire_mode) == "drone" else muzzle.origin
		if range_origin.distance_to(target.global_position) > float(definition.range_m): reason = "超出武器射程"; continue
		if (-muzzle.basis.z).angle_to(muzzle.origin.direction_to(target.global_position)) > float(profile.fire_cone_half_angle_rad): reason = "目标不在射界"; continue
		if not world.line_of_sight(muzzle.origin, target.global_position, world.flight.get_rid(), target_id): reason = "挂点视线受阻"; continue
		if equipment.cooldown_remaining_s > 0.0: reason = "武器循环中"; continue
		var weapon: Dictionary = store.catalog.one("weapon_defs", "module_id", equipment.module_def_id)
		if weapon.is_empty(): continue
		if weapon.get("ammo_item_id") != null:
			var inventory: RefCounted = gameplay.get("inventory")
			var hold: String = str(inventory.call("hold", ship, Types.ContainerKind.CARGO))
			if int(inventory.call("count", hold, weapon.ammo_item_id, false)) < int(weapon.ammo_per_cycle): reason = "弹药不足"; continue
		if ship.energy < float(definition.energy_eu): reason = "电容不足"; continue
		if ship.heat + float(definition.heat_hu) > float(world.flight.metrics.heat_max): reason = "等待散热"; continue
		return "自动开火中"
	return "自动开火待机：" + reason

func _check_objectives(delta: float) -> void:
	var ship := state.ship()
	if ship.status != Types.ShipStatus.FLYING:
		return
	for mission: Dtos.MissionStateDto in state.rows("mission_state"):
		if mission.status not in ["active", "ready", "ready_to_deliver"]:
			continue
		for definition in store.catalog.rows("mission_objective_defs"):
			if definition.mission_id != mission.mission_def_id or definition.target_anchor_id == null:
				continue
			var anchor: Dictionary = store.catalog.one("anchor_defs", "anchor_id", definition.target_anchor_id)
			if anchor.sector_id != state.current_sector():
				continue
			var in_radius := XJSpaceCoordinates.same_site(state, store.catalog, "ship", state.ship().ship_instance_id, anchor.anchor_id) and world.flight.position.distance_to(world.anchor_position(anchor.anchor_id)) <= float(anchor.interaction_radius_m)
			var key := "%s:%d" % [mission.mission_instance_id, definition.objective_index]
			if definition.objective_kind == "reach_anchor" and in_radius:
				gameplay.call("record_event", "reach_anchor", anchor.anchor_id, 1)
			elif definition.objective_kind == "brake_at_anchor":
				if in_radius and world.flight.velocity.length() <= float(definition.max_speed_mps):
					brake_hold[key] = float(brake_hold.get(key, 0.0)) + delta
					if float(brake_hold[key]) >= float(definition.hold_s):
						gameplay.call("record_event", "brake_at_anchor", anchor.anchor_id, 1)
				else:
					brake_hold[key] = 0.0

func _save_block_reason() -> String:
	if state != null and state.ship().status == Types.ShipStatus.DESTROYED: return "舰船已毁，先申请救援"
	if travel != null and travel.active(): return "虫洞传送"
	if local_navigation != null and local_navigation.active(): return "自动导航"
	if world != null and not world.projectiles.drones.is_empty(): return "无人机出击或回收"
	if world != null and world.projectiles.has_pending(): return "在途弹丸"
	if not pending_damage.is_empty(): return "待结算命中"
	if gameplay != null and not bool(gameplay.call("save_eligible")): return "交战或设备周期"
	return ""

func _exit_save_pending() -> bool:
	return not str(deferred_save.get("after", "")).is_empty()

func _request_save(kind: String, index: int, after: String = "") -> void:
	if state == null:
		return
	if not after.is_empty():
		_reset_combat_automation()
		world.projectiles.recall_drones()
		_release_controls()
		# An explicit exit stops new firing cycles and navigation before saving.
		if local_navigation != null and local_navigation.active(): local_navigation.cancel()
	# Automatic snapshots can merge; they never replace a chosen manual slot or exit.
	if not deferred_save.is_empty() and kind == "auto" and after.is_empty() and (deferred_save.kind != "auto" or not str(deferred_save.get("after", "")).is_empty()):
		return
	var reason := _save_block_reason()
	if not reason.is_empty():
		deferred_save = {"kind": kind, "index": index, "after": after}
		_sync_combat_automation()
		save_wait_elapsed = 0.0
		ui.set_operation_status("save", "等待%s结束后保存；暂停时请先继续航行" % reason, true, not after.is_empty())
		return
	_save_now(kind, index, after)

func _queue_autosave() -> void:
	_request_save("auto", auto_slot)
	auto_slot = (auto_slot + 1) % 3

func _save_now(kind: String, index: int, after: String = "") -> void:
	if busy:
		return
	busy = true
	_sync_combat_automation()
	ui.set_operation_status("save", "正在保存航行进度")
	await get_tree().process_frame
	if store.save(state, kind, index):
		if presentation != null and after.is_empty(): presentation.ui_result(true)
		ui.slots = store.list_slots()
		ui.notify("已保存 · " + {"manual": "手动", "auto": "自动", "quick": "快速"}[kind] + " " + str(index + 1))
		if after == "quit":
			get_tree().quit()
		elif after == "return_title":
			_reset_combat_automation(false)
			combat_automation = null
			local_navigation = null
			auto_fire_target = ""
			remove_child(world)
			world.queue_free()
			world = null
			state = null
			if gameplay != null and gameplay.has_method("dispose"):
				gameplay.call("dispose")
			gameplay = null
			presentation = null
			camera.ship = null
			ui.state = null
			ui.sector = null
			ui.show_title(store.list_slots())
	else:
		ui.notify("保存失败，当前世界与最后成功档保留。", true)
		push_error(store.last_error)
	busy = false
	_sync_combat_automation()
	ui.set_operation_status("idle", "")

func _store_status(_phase: String, message: String) -> void:
	# Storage diagnostics belong in logs. Product feedback uses operation states.
	if not message.is_empty():
		print("Database operation: ", _phase)

func _apply_preferences() -> void:
	ui.preferences = preferences.duplicate(true)
	if preferences.has("master_volume"):
		AudioServer.set_bus_volume_db(0, linear_to_db(float(preferences.master_volume)))
	var quality: String = str(preferences.get("quality_mode", "high"))
	if world != null: world.apply_visual_quality(quality)
	if world != null and world.tactical_view != null: world.tactical_view.intensity = float(preferences.get("vfx_intensity", 1.0))
	RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X if quality == "high" else RenderingServer.VIEWPORT_MSAA_DISABLED)
	if presentation != null:
		presentation.intensity = float(preferences.get("vfx_intensity", 1.0))

func _release_observation() -> void:
	observing = false
	if camera != null: camera.end_observation()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _release_controls() -> void:
	_release_observation()
	pointer_drag_pressed = false
	pointer_dragged = false
	pointer_pick_pending = false
	fire_held = false
	flight_look.clear()
	if world != null: world.flight.clear_intent()

func _home_page() -> String:
	return "station" if state != null and state.ship().status == Types.ShipStatus.DOCKED else ""

func _sync_mouse_mode() -> void:
	# Cursor availability is a product rule, independent of navigation or view.
	pointer_mode = true
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _sync_presentation_stage() -> void:
	if state == null or world == null:
		if hangar != null:
			hangar.hide()
			hangar.process_mode = Node.PROCESS_MODE_DISABLED
		presentation_stage = ""
		return
	var docked := state.ship().status == Types.ShipStatus.DOCKED
	if docked:
		hangar.set_space_context(store.catalog, state.ship().station_id)
		if hangar.ship_def_id != state.ship().ship_def_id:
			hangar.change_ship(state.ship().ship_def_id)
		if presentation_stage != "hangar": hangar.focus_service("")
		world.hide()
		hangar.show()
		hangar.process_mode = Node.PROCESS_MODE_DISABLED if _paused() or busy else Node.PROCESS_MODE_INHERIT
		hangar.get_camera().make_current()
		presentation_stage = "hangar"
	else:
		if hangar != null:
			hangar.hide()
			hangar.process_mode = Node.PROCESS_MODE_DISABLED
		if presentation_stage == "hangar": camera.snapped = false
		world.show()
		camera.camera.make_current()
		presentation_stage = "flight"

func _center_steering() -> void:
	if state != null and ui != null and ui.page.is_empty() and state.ship().status == Types.ShipStatus.FLYING:
		fire_held = false
		weapon_errors.clear()
		world.flight.clear_intent()
		flight_look.clear()
		pointer_mode = true
		_sync_mouse_mode()

func _install_input() -> void:
	for obsolete: String in ["pointer", "observe"]:
		if InputMap.has_action(obsolete): InputMap.erase_action(obsolete)
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "yaw_left": KEY_A, "yaw_right": KEY_D, "pitch_up": KEY_UP, "pitch_down": KEY_DOWN, "up": KEY_SPACE, "down": KEY_C, "roll_left": KEY_Q, "roll_right": KEY_E, "brake": KEY_X, "boost": KEY_SHIFT, "interact": KEY_F, "target": KEY_TAB, "camera": KEY_V, "map": KEY_M, "missions": KEY_J, "menu": KEY_ESCAPE, "quick_save": KEY_F5, "quick_load": KEY_F9, "fire": KEY_CTRL, "combat_toggle": KEY_Z}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
