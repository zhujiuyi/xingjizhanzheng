class_name XJCivilizationPanel
extends RefCounted
const T = preload("res://contracts/contract_types.gd")
const Portraits = preload("res://runtime/ui/item_portraits.gd")
var u: Node
var war_status: Label
var join_button: Button
var join_note: Label

func build(ui: Node) -> void:
	u = ui
	var civ: RefCounted = u.gameplay.civilizations
	if not civ.supported():
		u._text("当前世界仍使用旧规则。重新载入后可按备份分支流程升级文明内容。", 16)
		return
	var joined: String = civ.allegiance()
	var identity: String = "未效忠 · 中立舰长" if joined.is_empty() else civ.faction_name(joined) + " · " + str(civ.rank(joined).display_name)
	u._text("当前身份：" + identity, 20)
	u._text("单一效忠，可改换文明。各文明声望、已拥有舰船及已研究知识保留；专属采购、制造和战争权限由当前效忠决定。", 13)
	var selectors := HFlowContainer.new()
	u.body.add_child(selectors)
	var definitions: Array = u.catalog.rows("civilization_defs")
	if u.civilization_selected_faction.is_empty(): u.civilization_selected_faction = joined if not joined.is_empty() else str(definitions[0].faction_id)
	for definition: Dictionary in definitions:
		var id: String = str(definition.faction_id)
		var button: Button = u._button(selectors, civ.faction_name(id), func(): u.civilization_selected_faction = id; u.show_page("civilizations"))
		button.name = "CivilizationSelect_" + id
		button.tooltip_text = str(definition.doctrine)
		u._service_button_style(button, id == u.civilization_selected_faction)
	var faction: String = u.civilization_selected_faction
	var selected: Dictionary = u.catalog.one("civilization_defs", "faction_id", faction)
	if selected.is_empty(): return
	var title: String = civ.faction_name(faction)
	var current_rank: Dictionary = civ.rank(faction)
	var owned: int = 0
	for control: RefCounted in u.state.rows("territory_state"):
		if control.has_faction_id and control.faction_id == faction: owned += 1
	u._text(title + " · " + str(selected.doctrine), 18)
	var title_status: String = str(current_rank.display_name) if joined == faction else "未效忠（声望等级：%s）" % str(current_rank.display_name)
	u._text("声望 %d · %s · 管辖 %d 个星系\n核心站：%s" % [u.gameplay.economy.reputation(faction), title_status, owned, u._station_name(str(selected.capital_station_id))], 14)
	var map_button: Button = _command(u.body, "定位文明核心星系", "civilization_map", faction)
	map_button.name = "CivilizationCapital"
	u._text("入籍任务", 18)
	for step: Dictionary in u.catalog.rows("civilization_join_missions"):
		if step.faction_id != faction: continue
		var mission: Dictionary = u.catalog.one("mission_defs", "mission_id", step.mission_id)
		var completed: bool = u.gameplay.missions.completed(step.mission_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		u.body.add_child(row)
		var label: Label = u._text_to(row, ("✓ " if completed else "") + str(mission.display_name), 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button: Button = _command(row, "已完成" if completed else "接取任务", "accept_mission", step.mission_id)
		button.name = "CivilizationAdmission" + str(step.step_index)
		button.disabled = completed or not civ.capital_reason(faction).is_empty() or not u.gameplay.missions.eligible(mission) or u.gameplay.missions.active() != null
		button.tooltip_text = "在核心站按顺序完成补给、测绘与边防任务。当前任务可在任务与合同中查看和交付。"
	var active: RefCounted = u.gameplay.missions.active()
	if active != null:
		u._button(u.body, "查看进行中的任务与合同", func(): u.show_mission(active.mission_def_id))
	var switch_fee: int = int(u.gameplay.rule("civilization_switch_fee"))
	var join_label: String = "已效忠此文明" if joined == faction else "宣誓加入 " + title if joined.is_empty() else "改换效忠 · 支付 %d 信用点" % switch_fee
	var join: Button = _command(u.body, join_label, "join_civilization", faction)
	join.name = "CivilizationJoin"
	join_button = join
	var join_reason: String = civ.join_reason(faction)
	join.disabled = not join_reason.is_empty()
	join.tooltip_text = join_reason if not join_reason.is_empty() else "完成入籍，启用此文明的爵位和专属权限。"
	join_note = u._text_to(u.body, join_reason, 13)
	u._text("材料捐献", 18)
	u._text("仅消耗核心站仓库中的普通自有物资；保障和借用物资不参与。", 13)
	for donation: Dictionary in u.catalog.rows("civilization_donation_defs"):
		if donation.faction_id != faction: continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		u.body.add_child(row)
		var label: Label = u._text_to(row, "%s × %d / 批 → 声望 +%d" % [u._item_name(str(donation.item_id)), int(donation.units_per_batch), int(donation.reputation_per_batch)], 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var amount := SpinBox.new()
		amount.name = "CivilizationDonationQuantity_" + str(donation.donation_id)
		amount.min_value = 1; amount.max_value = u.gameplay.rule("civilization_max_donation_batches"); amount.step = 1; amount.value = 1
		amount.custom_minimum_size = Vector2(72, 30)
		row.add_child(amount)
		var button: Button = _command(row, "捐献", "donate_civilization", donation.donation_id, amount)
		button.name = "CivilizationDonate_" + str(donation.donation_id)
		var update: Callable = func(_value: float = 1.0):
			var raw: String = amount.get_line_edit().text.strip_edges()
			var quantity: int = int(raw) if raw.is_valid_int() else 0
			var reason: String = civ.donation_reason(str(donation.donation_id), quantity)
			button.disabled = not reason.is_empty(); button.tooltip_text = reason
		amount.value_changed.connect(update)
		amount.get_line_edit().text_changed.connect(func(_text: String): update.call())
		amount.get_line_edit().focus_exited.connect(func(): update.call_deferred())
		update.call()
	u._text("爵位与权限", 18)
	for rank: Dictionary in u.catalog.rows("civilization_rank_defs"):
		if rank.faction_id != faction: continue
		var benefit: String = "正式效忠后生效" if int(rank.rank_level) == 1 else "专属舰船与设计学" if int(rank.rank_level) in [2, 4, 6] else "可受领舰队战争委托" if int(rank.rank_level) == 5 else ""
		u._text("%s · 声望 %d%s" % [rank.display_name, int(rank.required_reputation), " · " + benefit if not benefit.is_empty() else ""], 13)
	u._text("文明专属舰船", 18)
	for hull: Dictionary in u.catalog.rows("civilization_hull_defs"):
		if hull.faction_id != faction: continue
		var ship: Dictionary = u.catalog.one("ship_defs", "ship_id", hull.ship_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		u.body.add_child(row)
		var image := TextureRect.new()
		image.texture = Portraits.texture("ship", hull.ship_id)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(88, 66); image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
		var required: Dictionary = civ.rank_requirement(faction, int(hull.required_rank))
		var label: Label = u._text_to(row, "%s · %s\n%s\n%s" % [ship.display_name, required.display_name, hull.description, "技术已掌握" if u.gameplay.unlocked(hull.required_unlock_id) else "需研究对应设计学；采购和制造另核验效忠"], 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	u._button(u.body, "打开科技与设施", func(): u.show_page("research"))
	u._text("舰队战争", 18)
	war_status = u._text_to(u.body, "", 14)
	war_status.name = "CivilizationWarStatus"
	var campaign: RefCounted = civ.active_war()
	if campaign != null:
		var controls := HFlowContainer.new()
		u.body.add_child(controls)
		_command(controls, "战区航路", "war_navigate", "")
		_command(controls, "推进", "fleet_command", "advance")
		_command(controls, "集结", "fleet_command", "regroup")
		_command(controls, "集火当前目标", "fleet_command", "focus", null, str(u.target_id))
		_command(controls, "撤退并放弃战役", "fleet_command", "retreat")
	else:
		u._text("舰队伯爵可在所属核心站受领委托。率领3艘友舰前往战区，清除守军及常规敌舰，再于目标点持续驻留完成占领。出生航路受保护。", 13)
		for war: Dictionary in u.catalog.rows("civilization_war_defs"):
			if war.faction_id != faction: continue
			var reason: String = civ.war_reason(war.war_id)
			var owner: String = civ.owner(war.target_sector_id)
			var button: Button = _command(u.body, "远征 " + u._sector_name(war.target_sector_id) + (" · 中立争夺" if owner.is_empty() else " · 已归属" + civ.faction_name(owner)), "start_war", war.war_id)
			button.name = "CivilizationWar_" + str(war.war_id)
			button.disabled = not reason.is_empty()
			button.tooltip_text = reason if not reason.is_empty() else "战役奖励：%d 信用点、声望 %d；胜利后星系归属所代表文明。" % [int(war.reward_credit), int(war.reward_reputation)]
	tick()

func tick() -> void:
	if not is_instance_valid(war_status): return
	var civ: RefCounted = u.gameplay.civilizations
	if is_instance_valid(join_button):
		var reason: String = civ.join_reason(str(u.civilization_selected_faction))
		join_button.disabled = not reason.is_empty()
		join_button.tooltip_text = reason
		join_note.text = reason
		join_note.visible = not reason.is_empty()
	var campaign: RefCounted = civ.active_war()
	if campaign == null:
		war_status.text = "当前没有进行中的舰队战争。"
		return
	var definition: Dictionary = u.catalog.one("civilization_war_defs", "war_id", campaign.war_id)
	var phase: String = str({"assembling": "前往战区与舰队会合", "fighting": "清除战区全部敌舰", "occupying": "留在占领范围内"}.get(campaign.status, campaign.status))
	war_status.text = "%s · %s\n友军 %d / 3 · 战役守军 %d / 4 · 占领剩余 %.1f 秒" % [u._sector_name(definition.target_sector_id), phase, civ.living_fleet(campaign, "ally").size(), civ.living_fleet(campaign, "defender").size(), campaign.capture_remaining_s]

func _command(parent: Node, title: String, action: String, target: String, amount: SpinBox = null, extra: String = "") -> Button:
	var state: RefCounted = u.state
	var catalog: RefCounted = u.catalog
	var generation: int = u.business_generation
	var epoch: int = state.epoch
	var station: String = u.gameplay.station()
	var callback: Callable = func():
		if u.state != state or u.catalog != catalog or u.business_generation != generation or state.epoch != epoch or u.page != "civilizations" or u.gameplay.station() != station: return
		if amount != null:
			var raw: String = amount.get_line_edit().text.strip_edges()
			if not raw.is_valid_int() or int(raw) < 1 or int(raw) > int(amount.max_value): u.notify("请输入合法的整数批数。", true); return
			amount.apply()
		u.requested.emit(action, target, int(amount.value) if amount != null else 1, extra)
	var button: Button = u._button(parent, title, callback)
	var font: Font = button.get_theme_font("font")
	var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x + button.get_theme_stylebox("normal").get_minimum_size().x + 12.0
	button.custom_minimum_size.x = minf(maxf(116.0, width), maxf(116.0, u.root.size.x - 64.0))
	button.set_meta("action", action); button.set_meta("target", target)
	return button
