extends VBoxContainer
const T = preload("res://contracts/contract_types.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
var u: Node
var context: Dictionary
var signature: String = ""
var elapsed: float = 0.0
var status: Label
var buttons: Array[Dictionary] = []
var current_event: String = ""

func setup(ui: Node) -> void:
	u = ui; context = {"state": u.state, "session": u.state.session_id, "epoch": u.state.epoch, "generation": u.business_generation}
	add_theme_constant_override("separation", UISkin.GAP)
	_build()

func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(u) and u.state != null and u.page == "exploration" and u.body.is_ancestor_of(self) and u.state == context.state and u.state.session_id == context.session and u.state.epoch == context.epoch and u.business_generation == context.generation

func _build() -> void:
	for child: Node in get_children(): remove_child(child); child.queue_free()
	buttons.clear()
	var service: RefCounted = u.gameplay.exploration
	if not service.supported(): u._text_to(self, "当前旧规则世界没有多阶段探索。", 16); return
	var choices: HFlowContainer = HFlowContainer.new(); add_child(choices)
	var definitions: Array = u.catalog.rows("exploration_event_defs")
	if u.exploration_selected.is_empty():
		u.exploration_selected = definitions[0].event_id
		for event: Dictionary in definitions:
			if event.sector_id == u.state.current_sector(): u.exploration_selected = event.event_id; break
	for event: Dictionary in definitions:
		var id: String = event.event_id
		var button: Button = u._button(choices, event.display_name, func():
			if _current(): u.exploration_selected = id; _build())
		button.name = "ExploreSelect_" + id
		button.toggle_mode = true; button.button_pressed = id == u.exploration_selected
		button.custom_minimum_size = Vector2(0, 32); button.add_theme_font_size_override("font_size", 13)
		UISkin.apply_button(button, "filter", true, id == u.exploration_selected)
	current_event = u.exploration_selected
	var row: RefCounted = service.instance(current_event)
	var event: Dictionary = service.definition(current_event)
	var variant: Dictionary = service.variant(row)
	signature = _signature(row)
	u._text_to(self, str(event.display_name) + " · " + u._sector_name(event.sector_id), 20)
	u._text_to(self, str(event.clue_text), 14).add_theme_color_override("font_color", UISkin.MUTED)
	var detail: String = "环境：" + str({"fragments": "碎片碰撞与遮挡", "em": "电磁扰动影响扫描和护盾恢复", "solar": "恒星喷流有预告，离开中心可避开"}[event.environment_kind])
	var unlocked: bool = u.gameplay.unlocked(event.required_unlock_id)
	if not unlocked: detail += "\n开放条件：完成新手教学并取得远域航路许可。"
	detail += "\n交付站：" + u._station_name(event.station_id) + "。暂停与退出不推进；活动窗口开始后离场仍会计时。"
	if row.phase != "clue": detail += "\n本轮 %s · 截击者 %d · 完整奖励 %d 信用点 / %d 探索证据 / %d 声望" % [str(variant.display_name), int(variant.enemy_count), int(variant.full_credit), int(variant.insight_units), int(variant.reputation_units)]
	u._text_to(self, detail, 13).add_theme_color_override("font_color", UISkin.MUTED)
	status = u._text_to(self, service.status_text(current_event), 15); status.name = "ExploreStatus"
	status.add_theme_color_override("font_color", UISkin.ICE)
	var navigation: HFlowContainer = HFlowContainer.new(); add_child(navigation)
	var generation: String = str(row.generation)
	u._button(navigation, "星图定位", func(): _navigation("exploration_map", current_event, generation)).name = "ExploreMap"
	var go: Button = u._button(navigation, "前往当前目标", func(): _navigation("exploration_nav", current_event, generation)); go.name = "ExploreNavigate"
	go.disabled = u.state.ship().status != T.ShipStatus.FLYING or not unlocked
	go.tooltip_text = "出港后导航；过门仍按 F 确认，抵达后由你选择行动。" if unlocked else "完成新手教学并取得远域航路许可后开放。"
	if u.gameplay.situational.supported():
		var equipment: Dictionary=u.gameplay.situational.exploration_equipment(current_event)
		if not str(equipment.note).is_empty():
			u._text_to(self,str(equipment.note),14).name="ExploreEquipmentHint"
			u._button(navigation,"检查配装",func():
				if _current():u.show_page("fitting" if u.state.ship().status==T.ShipStatus.DOCKED else "fitting_analysis")).name="ExploreEquipmentGuide"
	var actions: HFlowContainer = HFlowContainer.new(); add_child(actions)
	if row.phase == "clue": _action(actions, "调查线索", "survey", row)
	elif row.phase == "ready": _action(actions, "交付成果", "claim", row)
	elif row.phase not in ["claimed", "failed", "withdrawn"]:
		if event.event_kind == "rescue" and row.phase == "surveyed":
			_action(actions, "投入结构料修复并护送", "rescue", row)
			_action(actions, "抢救货物后撤离", "recover", row)
			u._text_to(self, "修复投入当前货舱普通结构料 × %d；护送舰需实际到达撤离点。抢救货物需要 %d 单位的货舱空间，奖励较少。" % [int(variant.repair_units), int(variant.recovery_units)], 13)
		elif event.event_kind == "relic" and row.phase in ["surveyed", "relic"]:
			_action(actions, "投入结构料稳定风险源", "stabilize", row)
			_action(actions, "继续深入取证", "deepen", row)
			u._text_to(self, "稳定投入当前货舱普通结构料 × %d。可以取得部分证据后撤回；深入过程仍需支付电容与热量。" % int(variant.repair_units), 13)
		elif event.event_kind == "mineral" and row.phase == "surveyed":
			_action(actions, "选择安全外围矿脉", "safe", row)
			_action(actions, "选择稀缺核心矿脉", "rich", row)
			u._text_to(self, "选定后开放实际矿体；原矿进入真实货舱。完整目标至少采集 %d 单位，再抵达撤离点。" % int(variant.mineral_quota), 13)
		if row.phase == "mineral":
			for node_id: String in service.managed_resources:
				if not service.resource_visible(node_id) or service.managed_resources[node_id].event_id != current_event: continue
				var node: String = node_id
				u._button(actions, "接近选定矿脉", func():
					if _current(): u.requested.emit("nav_approach", node, 1, ""))
		_action(actions, "结束行动并前往撤离点", "extract", row)
	var progress: RefCounted = u.state.rows("exploration_progress_state")[0]
	u._text_to(self, "当前探索证据 %d。研究在“科技与设施”消耗证据和信用点，扫描、环境防护与临时矿业均有独立作用。" % int(progress.insight_available), 13)
	u._button(self, "查看探索研究", func():
		if _current(): u.show_page("research"))
	_update()

func _signature(row: RefCounted) -> String:
	return "%s:%d:%s:%s:%d:%s" % [row.event_id, row.generation, row.phase, row.operation_kind, row.evidence_units, row.stabilized]

func _action(parent: Node, label: String, action: String, row: RefCounted) -> void:
	var event_id: String = row.event_id
	var generation: String = str(row.generation)
	var button: Button = u._button(parent, label, func():
		if not _current() or current_event != event_id: return
		var current: RefCounted = u.gameplay.exploration.instance(event_id)
		if current == null or str(current.generation) != generation or not u.gameplay.exploration.action_reason(event_id, action).is_empty(): return
		u.requested.emit("exploration_action", event_id, 1, action + ":" + generation))
	button.name = "ExploreAction_" + action
	buttons.append({"button": button, "event": event_id, "action": action})

func _navigation(action: String, event_id: String, generation: String) -> void:
	if not _current(): return
	var row: RefCounted = u.gameplay.exploration.instance(event_id)
	if row != null and str(row.generation) == generation: u.requested.emit(action, event_id, 1, generation)

func _update() -> void:
	if not _current() or not is_instance_valid(status): return
	status.text = u.gameplay.exploration.status_text(current_event)
	for row: Dictionary in buttons:
		var reason: String = u.gameplay.exploration.action_reason(row.event, row.action)
		row.button.disabled = not reason.is_empty(); row.button.tooltip_text = reason

func _process(delta: float) -> void:
	if not _current(): return
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0.0
	var row: RefCounted = u.gameplay.exploration.instance(current_event)
	if row != null and _signature(row) != signature: _build()
	else: _update()
