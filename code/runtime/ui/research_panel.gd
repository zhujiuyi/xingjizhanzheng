extends VBoxContainer
## Research is a station service, not a simulated production queue.
const UISkin = preload("res://runtime/ui_theme.gd")
const Interaction = preload("res://runtime/ui/ui_interaction.gd")

const CATEGORIES: Array[String] = ["faction", "specialization", "exploration", "facility"]
const TITLES: Dictionary = {"faction": "势力研究", "specialization": "火控专精", "exploration": "探索研究", "facility": "本站设施"}
var u: Node
var context: Dictionary
var identity: String = ""
var category: String = "faction"
var selected: String = ""
var selections: Dictionary = {}
var show_completed: bool = false
var show_unlocks: bool = false
var entries: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var tabs: Dictionary = {}
var list: VBoxContainer
var detail: VBoxContainer
var qualifications: VBoxContainer
var summary: Label
var evidence: Label
var completed_button: Button
var unlock_button: Button
var quantity: SpinBox
var quantity_value: int = 1
var progress_label: Label
var action_reason: Label
var cost_label: Label
var primary: Button
var donation: Button
var market: Button
var industry: Button
var elapsed: float = 0.0
var membership: String = ""

func setup(ui: Node) -> void:
	u = ui
	context = Interaction.context(u)
	identity = "%s:%s:%s:%s" % [u.state.get_instance_id(), u.state.world_id, u.state.session_id, u.state.player().docked_station_id]
	var retained: Dictionary = u.get_meta("research_view", {})
	if str(retained.get("identity", "")) == identity:
		category = str(retained.get("category", "faction"))
		show_completed = bool(retained.get("completed", false))
		show_unlocks = bool(retained.get("unlocks", false))
		selected = str(retained.get("selected", ""))
		selections = retained.get("selections", {}).duplicate()
		quantity_value = maxi(1, int(retained.get("quantity", 1)))
	_collect()
	if not CATEGORIES.has(category) or _category_count(category) == 0:
		for candidate: String in CATEGORIES:
			if _category_count(candidate) > 0:
				category = candidate
				break
	add_theme_constant_override("separation", UISkin.SECTION_GAP)
	summary = u._text_to(self, "", 13)
	summary.add_theme_color_override("font_color", UISkin.MUTED)
	var toolbar: HFlowContainer = HFlowContainer.new()
	toolbar.name = "ResearchCategories"
	toolbar.add_theme_constant_override("h_separation", UISkin.GAP)
	toolbar.add_theme_constant_override("v_separation", UISkin.GAP)
	add_child(toolbar)
	for candidate: String in CATEGORIES:
		if _category_count(candidate) == 0: continue
		var tab: Button = u._button(toolbar, str(TITLES[candidate]), _set_category.bind(candidate))
		tab.name = "ResearchTab_" + candidate
		tab.set_meta("action", "research_category")
		tab.set_meta("target", candidate)
		tabs[candidate] = tab
	completed_button = u._button(toolbar, "", _toggle_completed)
	completed_button.name = "ResearchShowCompleted"
	evidence = u._text_to(self, "", 14)
	evidence.name = "ResearchEvidence"
	evidence.add_theme_color_override("font_color", UISkin.ICE)
	list = VBoxContainer.new()
	list.name = "ResearchList"
	list.add_theme_constant_override("separation", 0)
	add_child(list)
	var frame: PanelContainer = u._frame(self, "ResearchDetailFrame")
	detail = VBoxContainer.new()
	detail.name = "ResearchDetail"
	detail.add_theme_constant_override("separation", UISkin.GAP)
	frame.add_child(detail)
	unlock_button = u._button(self, "", _toggle_unlocks)
	unlock_button.name = "ResearchUnlocks"
	qualifications = VBoxContainer.new()
	qualifications.name = "ResearchQualifications"
	qualifications.add_theme_constant_override("separation", UISkin.GAP)
	add_child(qualifications)
	_build_list()
	_build_qualifications()
	_update()

func _collect() -> void:
	var faction: String = _station_faction()
	for definition: Dictionary in u._defs("research_defs"):
		if str(definition.station_faction_id) == faction:
			entries.append({"kind": "faction", "id": str(definition.research_id), "definition": definition})
	if u.gameplay.specializations.supported():
		for definition: Dictionary in u._defs("specialization_research_defs"):
			entries.append({"kind": "specialization", "id": str(definition.research_id), "definition": definition})
	if u.gameplay.exploration.supported():
		for definition: Dictionary in u._defs("exploration_research_defs"):
			entries.append({"kind": "exploration", "id": str(definition.research_id), "definition": definition})
	for definition: Dictionary in u._defs("base_module_defs"):
		entries.append({"kind": "facility", "id": str(definition.base_module_id), "definition": definition})

func _category_count(kind: String) -> int:
	var count: int = 0
	for entry: Dictionary in entries:
		if entry.kind == kind: count += 1
	return count

func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and Interaction.current(u, context, self)

func _remember() -> void:
	selections[category] = selected
	u.set_meta("research_view", {"identity": identity, "category": category, "selected": selected, "selections": selections.duplicate(), "completed": show_completed, "unlocks": show_unlocks, "quantity": quantity_value})

func _set_category(kind: String) -> void:
	if not _current() or category == kind: return
	_retain_quantity()
	selections[category] = selected
	category = kind
	selected = str(selections.get(kind, ""))
	_build_list()
	_update()

func _toggle_completed() -> void:
	if not _current(): return
	_retain_quantity()
	show_completed = not show_completed
	_build_list()
	_update()

func _toggle_unlocks() -> void:
	if not _current(): return
	show_unlocks = not show_unlocks
	_build_qualifications()
	_remember()

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _build_list() -> void:
	var view: Dictionary = u.capture_local_view(list)
	_clear(list)
	rows.clear()
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", UISkin.GAP)
	var header_frame: PanelContainer = PanelContainer.new()
	header_frame.add_theme_stylebox_override("panel", UISkin.table_header())
	list.add_child(header_frame)
	header_frame.add_child(header)
	var name_heading: Label = u._text_to(header, "名称", 13)
	name_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column(header, "状态", 112)
	_column(header, "费用 / 信用点", 192, true)
	var visible_ids: Array[String] = []
	for entry: Dictionary in entries:
		if entry.kind != category or (not show_completed and _done(entry)): continue
		visible_ids.append(str(entry.id))
		var frame: PanelContainer = PanelContainer.new()
		frame.name = "ResearchRow_" + str(entry.id)
		frame.set_meta("asset_kind", "facility" if category == "facility" else "research")
		frame.set_meta("asset_id", str(entry.id))
		list.add_child(frame)
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", UISkin.GAP)
		frame.add_child(line)
		var button: Button = u._button(line, str(entry.definition.display_name), _select.bind(str(entry.id)))
		button.name = "ResearchSelect_" + str(entry.id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.custom_minimum_size = Vector2(112, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("action", "select_research")
		button.set_meta("target", str(entry.id))
		var state_label: Label = _column(line, "", 112)
		var fee: Label = _column(line, _fee(entry), 192, true)
		rows.append({"entry": entry, "frame": frame, "button": button, "status": state_label, "fee": fee})
	if not visible_ids.has(selected): selected = visible_ids[0] if not visible_ids.is_empty() else ""
	if visible_ids.is_empty():
		u._text_to(list, "此类项目已全部完成。可开启「显示已完成」查看。", 14).add_theme_color_override("font_color", UISkin.MUTED)
	membership = _membership()
	_build_detail()
	_style_selection()
	_remember()
	u.finish_local_rebuild(list, view)

func _column(parent: Node, text: String, width: int, right: bool = false) -> Label:
	var label: Label = u._text_to(parent, text, 13)
	label.custom_minimum_size.x = width
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	return label

func _select(id: String) -> void:
	if not _current() or selected == id: return
	_retain_quantity()
	selected = id
	_build_detail()
	_style_selection()
	_remember()
	_update()

func _selected_entry() -> Dictionary:
	for entry: Dictionary in entries:
		if entry.kind == category and entry.id == selected: return entry
	return {}

func _build_detail() -> void:
	_clear(detail)
	u._link_page_focus.call_deferred()
	quantity = null; progress_label = null; action_reason = null; cost_label = null
	primary = null; donation = null; market = null; industry = null
	var entry: Dictionary = _selected_entry()
	if entry.is_empty():
		u._text_to(detail, "选择项目查看条件与操作。", 14)
		return
	var definition: Dictionary = entry.definition
	u._text_to(detail, str(definition.display_name), 18)
	if category == "specialization":
		_build_specialization(entry)
		return
	if category == "faction":
		u._text_to(detail, "解锁 · " + u._unlock_name(str(definition.reward_unlock_id)), 14)
		var reputation: int = int(u.gameplay.economy.reputation(_station_faction()))
		u._text_to(detail, "势力声望 %d / %d · 研究费 %d 信用点" % [reputation, int(definition.required_reputation), int(definition.required_credit)], 14)
		_materials(detail, "research_inputs", "research_id", str(entry.id))
		for prerequisite: Dictionary in u._defs("research_prerequisites"):
			if str(prerequisite.research_id) != str(entry.id): continue
			u._text_to(detail, "前置 · " + u._unlock_name(str(prerequisite.unlock_id)) + ("（已解锁）" if u._unlocked(str(prerequisite.unlock_id)) else "（未解锁）"), 13)
		var verification_id: String = str(definition.verification_mission_id) if definition.get("verification_mission_id") != null else ""
		if not verification_id.is_empty():
			var verification: Dictionary = u._one("mission_defs", "mission_id", verification_id)
			u._text_to(detail, "验证任务 · " + u._mission_category_title(verification) + " · " + u._mission_name(verification_id) + ("（已完成）" if u._mission_completed(verification_id) else "（未完成）"), 13)
			u._text_to(detail, "接取地点 · " + u._sector_name(str(verification.get("accept_sector_id", ""))) + " / " + u._station_name(str(verification.get("accept_station_id", ""))), 13).add_theme_color_override("font_color", UISkin.MUTED)
		action_reason = u._text_to(detail, "", 13)
		var actions: HFlowContainer = _actions(detail)
		primary = u._command(actions, "完成研究", "research", str(entry.id))
		primary.name = "ResearchComplete_" + str(entry.id)
		if not verification_id.is_empty():
			var mission: Button = u._button(actions, "查看验证任务" if u._mission_completed(verification_id) else "查看主线前置", u.show_mission.bind(verification_id))
			mission.set_meta("action", "show_mission")
			mission.set_meta("target", verification_id)
			mission.tooltip_text = "查看该验证任务的条件与接取地点。"
	elif category == "exploration":
		u._text_to(detail, str(definition.description), 14)
		u._text_to(detail, "解锁 · " + u._unlock_name(str(definition.reward_unlock_id)), 14)
		u._text_to(detail, "消耗探索证据 %d · 研究费 %d 信用点" % [int(definition.required_insight), int(definition.required_credit)], 14)
		action_reason = u._text_to(detail, "", 13)
		primary = u._command(_actions(detail), "研究", "exploration_research", str(entry.id))
		primary.name = "ExploreResearch_" + str(entry.id)
	else:
		var service: String = str({"industry": "工业", "repair": "维修", "navigation": "导航", "warehouse": "仓储"}.get(str(definition.service_kind), "站点"))
		u._text_to(detail, "%s设施 · 效率系数 %.2f · 建造费 %d 信用点" % [service, float(definition.effect_multiplier), int(definition.service_fee_credit)], 14)
		u._text_to(detail, "所需资格 · " + u._unlock_name(str(definition.required_unlock_id)) + ("（已解锁）" if u._unlocked(str(definition.required_unlock_id)) else "（未解锁）"), 13)
		_materials(detail, "base_module_inputs", "base_module_id", str(entry.id))
		u._text_to(detail, ("导航设施在本星系生效。" if str(definition.service_kind) == "navigation" else "设施在本站服务生效。") + "同站同型设施只可建造一次。", 13).add_theme_color_override("font_color", UISkin.MUTED)
		action_reason = u._text_to(detail, "", 13)
		primary = u._command(_actions(detail), "设施已建成" if _done(entry) else "建造设施", "build_base", str(entry.id))
		primary.name = "ResearchBuild_" + str(entry.id)
	UISkin.apply_button(primary, "primary")

func _actions(parent: Node) -> HFlowContainer:
	var actions: HFlowContainer = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", UISkin.GAP)
	actions.add_theme_constant_override("v_separation", UISkin.GAP)
	parent.add_child(actions)
	return actions

func _materials(parent: Node, table: String, key: String, id: String) -> void:
	var parts: PackedStringArray = []
	for material: Dictionary in u._defs(table):
		if str(material.get(key, "")) != id: continue
		var owned: int = int(u.gameplay.inventory.count(u._warehouse_id(), str(material.item_id), true))
		parts.append("%s %d / %d" % [u._item_name(str(material.item_id)), owned, int(material.quantity)])
	u._text_to(parent, "本站仓库普通自有材料（持有 / 需要）\n" + " · ".join(parts), 13).add_theme_color_override("font_color", UISkin.MUTED)

func _build_specialization(entry: Dictionary) -> void:
	var definition: Dictionary = entry.definition
	u._text_to(detail, u.gameplay.specializations.description(str(definition.module_id)), 14)
	u._text_to(detail, "前置 · " + u._unlock_name(str(definition.required_unlock_id)) + ("（已解锁）" if u._unlocked(str(definition.required_unlock_id)) else "（未解锁）"), 13)
	progress_label = u._text_to(detail, "", 14)
	progress_label.name = "SpecializationProgress_" + str(entry.id)
	progress_label.add_theme_color_override("font_color", UISkin.ICE)
	var inputs: HFlowContainer = _actions(detail)
	inputs.name = "SpecializationQuantityRow"
	# Keep the labelled editor as one compact flow item. Wrapped CJK labels
	# otherwise report a one-character minimum and stretch the whole flow row.
	var group: HBoxContainer = HBoxContainer.new()
	group.name = "SpecializationQuantityGroup"
	group.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.add_theme_constant_override("separation", UISkin.GAP)
	inputs.add_child(group)
	var quantity_label: Label = u._text_to(group, "本次分析点", 14)
	quantity_label.name = "SpecializationQuantityLabel"
	quantity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	quantity_label.custom_minimum_size.x = 80
	quantity_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quantity_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quantity = SpinBox.new()
	quantity.name = "SpecializationQuantity"
	quantity.min_value = 1
	quantity.max_value = int(u.gameplay.specializations.balance.max_donation_points)
	quantity.step = 1
	quantity.rounded = true
	quantity.value = mini(quantity_value, int(quantity.max_value))
	quantity.custom_minimum_size = Vector2(112, 36)
	quantity.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quantity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.add_child(quantity)
	cost_label = u._text_to(detail, "", 13)
	cost_label.name = "SpecializationCost"
	action_reason = u._text_to(detail, "", 13)
	var actions: HFlowContainer = _actions(detail)
	primary = u._button(actions, "投入所选分析点", _submit_specialization.bind("specialization_research", str(entry.id)))
	primary.name = "SpecializationInvest_" + str(entry.id)
	primary.set_meta("action", "specialization_research")
	primary.set_meta("target", str(entry.id))
	UISkin.apply_button(primary, "primary")
	market = u._button(actions, "采购已解锁设备", _open_page.bind("market"))
	market.name = "SpecializationMarket_" + str(entry.id)
	industry = u._button(actions, "制造已解锁设备", _open_page.bind("industry"))
	industry.name = "SpecializationIndustry_" + str(entry.id)
	var balance: Dictionary = u.gameplay.specializations.balance
	u._text_to(detail, "证据不足时，可分析普通材料换取分析点；探索、战斗与行动交付也会取得证据。", 13).add_theme_color_override("font_color", UISkin.MUTED)
	u._text_to(detail, "材料分析每点 · %s × %d · %d 信用点" % [u._item_name(str(balance.donation_item_id)), int(balance.donation_units_per_point), int(balance.donation_credit_per_point)], 13).add_theme_color_override("font_color", UISkin.MUTED)
	donation = u._button(_actions(detail), "投入结构料进行分析", _submit_specialization.bind("specialization_donate", ""))
	donation.name = "SpecializationDonate"
	donation.set_meta("action", "specialization_donate")
	donation.set_meta("target", "")
	Interaction.watch_integer(quantity, _update)

func _submit_specialization(action: String, id: String) -> void:
	if not _current(): return
	var amount: int = Interaction.integer_input(quantity)
	if amount <= 0:
		_update()
		u.notify("请输入范围内的整数分析点。", true)
		return
	var reason: String = u.gameplay.specializations.donate_reason(amount) if action == "specialization_donate" else u.gameplay.specializations.research_reason(id, amount)
	if not reason.is_empty():
		_update()
		u.notify(reason, true)
		return
	quantity.apply()
	quantity_value = amount
	_remember()
	var row: RefCounted = u.state.find("specialization_research_state", "research_id", id)
	var expected: String = str(row.invested_points if row != null else 0) if action == "specialization_research" else ""
	u.requested.emit(action, id, amount, expected)

func _open_page(page: String) -> void:
	if _current(): u.show_page(page)

func _retain_quantity() -> void:
	if is_instance_valid(quantity):
		var amount: int = Interaction.integer_input(quantity)
		if amount > 0: quantity_value = amount

func _station_faction() -> String:
	return str(u._one("station_defs", "station_id", str(u.state.player().docked_station_id)).get("faction_id", ""))

func _done(entry: Dictionary) -> bool:
	if entry.kind == "facility":
		for row: RefCounted in u.state.rows("base_module_state"):
			if row.station_id == u.state.player().docked_station_id and row.base_module_id == entry.id: return true
		return false
	if entry.kind == "exploration": return u.state.find("exploration_research_state", "research_id", str(entry.id)) != null
	return u._unlocked(str(entry.definition.reward_unlock_id))

func _reason(entry: Dictionary, amount: int = 1) -> String:
	if _done(entry): return "本站已建成" if entry.kind == "facility" else "已掌握"
	var definition: Dictionary = entry.definition
	if entry.kind == "specialization": return u.gameplay.specializations.research_reason(str(entry.id), amount)
	var service: String = u._service_reason("manufacture")
	if not service.is_empty(): return service
	if entry.kind == "exploration":
		var progress: RefCounted = u.state.find("exploration_progress_state", "player_id", u.state.player().player_id)
		if progress == null or int(progress.insight_available) < int(definition.required_insight): return "探索证据不足"
		return "信用点不足" if int(u.state.player().credit) < int(definition.required_credit) else ""
	if entry.kind == "facility":
		if not u._unlocked(str(definition.required_unlock_id)): return "需解锁 " + u._unlock_name(str(definition.required_unlock_id))
		var facility_materials: String = u._materials_reason("base_module_inputs", "base_module_id", str(entry.id), 1)
		if not facility_materials.is_empty(): return facility_materials
		return "信用点不足" if int(u.state.player().credit) < int(definition.service_fee_credit) else ""
	var civilization: String = u.gameplay.civilizations.research_reason(str(entry.id))
	if not civilization.is_empty(): return civilization
	for prerequisite: Dictionary in u._defs("research_prerequisites"):
		if str(prerequisite.research_id) == str(entry.id) and not u._unlocked(str(prerequisite.unlock_id)): return "需先解锁 " + u._unlock_name(str(prerequisite.unlock_id))
	var reputation: int = int(u.gameplay.economy.reputation(_station_faction()))
	if reputation < int(definition.required_reputation): return "声望 %d / %d" % [reputation, int(definition.required_reputation)]
	if definition.get("verification_mission_id") != null and not u._mission_completed(str(definition.verification_mission_id)): return "需先完成 " + u._mission_name(str(definition.verification_mission_id))
	var research_materials: String = u._materials_reason("research_inputs", "research_id", str(entry.id), 1)
	if not research_materials.is_empty(): return research_materials
	return "信用点不足" if int(u.state.player().credit) < int(definition.required_credit) else ""

func _fee(entry: Dictionary) -> String:
	var definition: Dictionary = entry.definition
	if entry.kind == "specialization": return "%d / 分析点" % int(definition.credit_per_point)
	if entry.kind == "exploration": return "%d · 证据 %d" % [int(definition.required_credit), int(definition.required_insight)]
	return str(int(definition.service_fee_credit if entry.kind == "facility" else definition.required_credit))

func _membership() -> String:
	var parts: PackedStringArray = []
	for entry: Dictionary in entries:
		if entry.kind == category: parts.append(str(entry.id) + ":" + str(_done(entry)))
	return "|".join(parts)

func _process(delta: float) -> void:
	if not _current(): return
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0.0
	if not show_completed and membership != _membership():
		_retain_quantity()
		_build_list()
	_update()

func _style_selection() -> void:
	completed_button.text = "收起已完成" if show_completed else "显示已完成"
	UISkin.apply_button(completed_button, "filter", true, show_completed)
	for id: String in tabs:
		UISkin.apply_button(tabs[id], "filter", true, id == category)
	for row: Dictionary in rows:
		var active: bool = str(row.entry.id) == selected
		UISkin.apply_button(row.button, "filter", true, active)
		var surface: StyleBoxFlat = UISkin.table_row(false)
		if active:
			surface.bg_color = UISkin.SURFACE
			surface.border_color = UISkin.ICE
			surface.border_width_left = 2
		row.frame.add_theme_stylebox_override("panel", surface)

func _update() -> void:
	if not _current(): return
	var faction: String = _station_faction()
	summary.text = "%s · 声望 %d · 信用点 %d" % [str(u._one("faction_defs", "faction_id", faction).get("display_name", "本站势力")), int(u.gameplay.economy.reputation(faction)), int(u.state.player().credit)]
	evidence.visible = category in ["specialization", "exploration"]
	if category == "specialization":
		var specialization_progress: RefCounted = u.gameplay.specializations.progress()
		evidence.name = "SpecializationEvidence"
		evidence.text = "可用分析证据 %d · 累计取得 %d · 已投入 %d" % [int(u.gameplay.specializations.available()), int(specialization_progress.earned_points) if specialization_progress != null else 0, int(specialization_progress.spent_points) if specialization_progress != null else 0]
	elif category == "exploration":
		var exploration_progress: RefCounted = u.state.find("exploration_progress_state", "player_id", u.state.player().player_id)
		evidence.name = "ExplorationEvidence"
		evidence.text = "可用探索证据 %d · 累计取得 %d" % [int(exploration_progress.insight_available) if exploration_progress != null else 0, int(exploration_progress.insight_earned) if exploration_progress != null else 0]
	for row: Dictionary in rows:
		var entry: Dictionary = row.entry
		var row_reason: String = _reason(entry)
		var done: bool = _done(entry)
		row.status.text = ("已建成" if category == "facility" else "已掌握") if done else ("可建造" if category == "facility" else "可研究") if row_reason.is_empty() else "条件未满足"
		if category == "specialization" and not done:
			var row_progress: RefCounted = u.state.find("specialization_research_state", "research_id", str(entry.id))
			row.status.text = "%d / %d 点" % [int(row_progress.invested_points) if row_progress != null else 0, int(entry.definition.required_points)]
		row.status.tooltip_text = row_reason
		row.status.add_theme_color_override("font_color", UISkin.MUTED if done else UISkin.ICE if row_reason.is_empty() else UISkin.AMBER)
		row.button.tooltip_text = str(entry.definition.display_name) + ("\n" + row_reason if not row_reason.is_empty() else "")
	var selected_entry: Dictionary = _selected_entry()
	if selected_entry.is_empty(): return
	var amount: int = Interaction.integer_input(quantity) if is_instance_valid(quantity) else 1
	var reason: String = "请输入范围内的整数分析点。" if amount <= 0 else _reason(selected_entry, amount)
	if is_instance_valid(primary): Interaction.action_state(primary, reason)
	if is_instance_valid(action_reason):
		action_reason.text = reason if not reason.is_empty() else "条件满足，可投入所选分析点。" if category == "specialization" else "条件满足，可建造。" if category == "facility" else "条件满足，可研究。"
		action_reason.add_theme_color_override("font_color", UISkin.MUTED if _done(selected_entry) else UISkin.ICE if reason.is_empty() else UISkin.AMBER)
	if category != "specialization": return
	var definition: Dictionary = selected_entry.definition
	var invested: RefCounted = u.state.find("specialization_research_state", "research_id", selected)
	progress_label.text = "已投入 %d / %d 分析点 · %s" % [int(invested.invested_points) if invested != null else 0, int(definition.required_points), "设计已解锁" if _done(selected_entry) else "分批投入，进度保存"]
	var balance: Dictionary = u.gameplay.specializations.balance
	cost_label.text = "本次研究 · %d 信用点；材料分析 · %s × %d + %d 信用点" % [maxi(0, amount) * int(definition.credit_per_point), u._item_name(str(balance.donation_item_id)), maxi(0, amount) * int(balance.donation_units_per_point), maxi(0, amount) * int(balance.donation_credit_per_point)] if amount > 0 else "输入整数分析点后查看本次费用。"
	var donation_reason: String = "请输入范围内的整数分析点。" if amount <= 0 else u.gameplay.specializations.donate_reason(amount)
	Interaction.action_state(donation, donation_reason, "消耗本站仓库普通自有材料，换取本次数量的分析证据。")
	var unlock_reason: String = "" if _done(selected_entry) else "先完成该火控设计研究"
	Interaction.action_state(market, unlock_reason)
	Interaction.action_state(industry, unlock_reason)

func _build_qualifications() -> void:
	_clear(qualifications)
	u._link_page_focus.call_deferred()
	qualifications.visible = show_unlocks
	unlock_button.text = ("收起" if show_unlocks else "查看") + "已解锁科技与资格（%d）" % u.state.rows("unlock_state").size()
	UISkin.apply_button(unlock_button, "filter", true, show_unlocks)
	if not show_unlocks: return
	var names: PackedStringArray = []
	for row: RefCounted in u.state.rows("unlock_state"):
		names.append(u._unlock_name(str(row.unlock_id)))
	u._text_to(qualifications, " · ".join(names), 13).add_theme_color_override("font_color", UISkin.MUTED)
	var reputations: PackedStringArray = []
	for row: RefCounted in u.state.rows("reputation_state"):
		reputations.append("%s %d" % [str(u._one("faction_defs", "faction_id", str(row.faction_id)).get("display_name", "未知势力")), int(row.reputation)])
	u._text_to(qualifications, "势力声望 · " + " · ".join(reputations), 13)
