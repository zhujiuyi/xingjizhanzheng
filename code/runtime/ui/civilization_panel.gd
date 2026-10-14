class_name XJCivilizationPanel
extends RefCounted
const T = preload("res://contracts/contract_types.gd")
const Portraits = preload("res://runtime/ui/item_portraits.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
const Interaction = preload("res://runtime/ui/ui_interaction.gd")
var u: Node
var war_status: Label
var join_button: Button
var join_note: Label
var honor_panel: RefCounted
var growth_panel: RefCounted

const SECTION_META: String = "civilization_section"
const SECTIONS: Array[Dictionary] = [
	{"id":"progress","label":"当前进展"},
	{"id":"contribution","label":"贡献与权限"},
	{"id":"command","label":"指挥考核"},
	{"id":"campaign","label":"战役与治理"},
]
var section: String = "progress"
var active_faction: String = ""
var context: Dictionary = {}

static func select_section(ui: Node, value: String) -> void:
	ui.set_meta(SECTION_META, value if value in ["progress","contribution","command","campaign"] else "progress")

static func section_for_activity(kind: String) -> String:
	return "command" if kind in ["honor","honor_register"] else "campaign" if kind=="war" else "progress"

func _current() -> bool:
	return not context.is_empty() and is_instance_valid(u) and not u.loading_suspended and Interaction.current(u,context) and u.page=="civilizations" and u.civilization_selected_faction==active_faction and str(u.get_meta(SECTION_META,"progress"))==section

func build(ui: Node) -> void:
	u=ui
	war_status=null;join_button=null;join_note=null;honor_panel=null;growth_panel=null
	var civ: RefCounted=u.gameplay.civilizations
	if not civ.supported():
		u._text("当前世界仍使用旧规则。重新载入后可按备份分支流程升级文明内容。",16)
		return
	var definitions: Array=u.catalog.rows("civilization_defs")
	if definitions.is_empty():return
	var joined: String=civ.allegiance()
	if u.civilization_selected_faction.is_empty():u.civilization_selected_faction=joined if not joined.is_empty() else str(definitions[0].faction_id)
	active_faction=u.civilization_selected_faction
	var selected: Dictionary=u.catalog.one("civilization_defs","faction_id",active_faction)
	if selected.is_empty():return
	context=Interaction.context(u)
	section=str(u.get_meta(SECTION_META,"progress"))
	if section not in ["progress","contribution","command","campaign"]:section="progress"
	select_section(u,section)
	var identity: String="未效忠 · 中立舰长" if joined.is_empty() else civ.faction_name(joined)+" · "+str(civ.rank(joined).display_name)
	u._text("当前身份："+identity,14)
	var selectors:=HFlowContainer.new();u.body.add_child(selectors)
	for definition: Dictionary in definitions:
		var id: String=str(definition.faction_id)
		var button: Button=u._button(selectors,civ.faction_name(id),func():
			if _current():u.civilization_selected_faction=id;u.show_page("civilizations"))
		button.name="CivilizationSelect_"+id;button.tooltip_text=str(definition.doctrine)
		button.toggle_mode=true;button.button_pressed=id==active_faction
		button.custom_minimum_size=Vector2(0,32);button.add_theme_font_size_override("font_size",13)
		UISkin.apply_button(button,"filter",true,id==active_faction)
	var current_rank: Dictionary=civ.rank(active_faction)
	var owned: int=0
	for control: RefCounted in u.state.rows("territory_state"):
		if control.has_faction_id and control.faction_id==active_faction:owned+=1
	var title: String=civ.faction_name(active_faction)
	var summary:=HFlowContainer.new();summary.add_theme_constant_override("h_separation",UISkin.SECTION_GAP);u.body.add_child(summary)
	u._text_to(summary,"声望 %d · %s · 管辖 %d 个星系" % [u.gameplay.economy.reputation(active_faction),current_rank.display_name,owned],14)
	var capital: Button=_command(summary,"定位核心星系","civilization_map",active_faction)
	capital.name="CivilizationCapital";capital.tooltip_text="核心站："+u._station_name(str(selected.capital_station_id))
	var tabs:=HFlowContainer.new();tabs.name="CivilizationSections";u.body.add_child(tabs)
	for record: Dictionary in SECTIONS:
		var id: String=str(record.id)
		var button: Button=u._button(tabs,str(record.label),func():
			if _current():select_section(u,id);u.show_page("civilizations"))
		button.name="CivilizationSection_"+id;button.toggle_mode=true;button.button_pressed=id==section
		UISkin.apply_button(button,"filter",true,id==section)
	u.body.set_meta(SECTION_META,section)
	match section:
		"progress":_build_progress(active_faction,civ,joined,title)
		"contribution":_build_contribution(active_faction,civ)
		"command":_build_commander(active_faction)
		"campaign":_build_campaign(active_faction,civ)
	tick()

func _build_progress(faction: String,civ: RefCounted,joined: String,title: String) -> void:
	if u.gameplay.growth.supported():
		growth_panel=preload("res://runtime/ui/growth_panel.gd").new();growth_panel.build(u,faction)
	if joined==faction:
		u._text("入籍已完成。贡献、指挥考核与战役按上方分类查看；历史任务仍在任务与合同保留。",13)
		return
	u._text("入籍当前任务",18)
	var steps: Array[Dictionary]=[]
	for step: Dictionary in u.catalog.rows("civilization_join_missions"):
		if step.faction_id==faction:steps.append(step)
	steps.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.step_index)<int(b.step_index))
	var pending: Dictionary={}
	for step: Dictionary in steps:
		if not u.gameplay.missions.completed(step.mission_id):pending=step;break
	var active: RefCounted=u.gameplay.missions.active()
	if not pending.is_empty():
		var mission: Dictionary=u.catalog.one("mission_defs","mission_id",pending.mission_id)
		var row:=HFlowContainer.new();u.body.add_child(row)
		u._text_to(row,"第%d/%d步 · %s" % [pending.step_index,steps.size(),mission.display_name],14)
		var button: Button
		if active!=null and active.mission_def_id==pending.mission_id:
			button=u._button(row,"查看当前任务",func():
				if _current():u.show_mission(str(pending.mission_id)))
		else:
			button=_command(row,"接取当前任务","accept_mission",str(pending.mission_id))
			button.disabled=not civ.capital_reason(faction).is_empty() or not u.gameplay.missions.eligible(mission) or active!=null
		button.name="CivilizationAdmission"+str(pending.step_index)
		button.tooltip_text="在核心站按实际前置完成补给、测绘与边防任务。后续与历史可在任务与合同查看。"
	elif not steps.is_empty():u._text("入籍任务已完成，可办理宣誓。",14)
	if active!=null and (pending.is_empty() or active.mission_def_id!=pending.mission_id):
		u._button(u.body,"查看进行中的任务与合同",func():
			if _current():u.show_mission(active.mission_def_id))
	var switch_fee: int = int(u.gameplay.rule("civilization_switch_fee"))
	var join_label: String = "已效忠此文明" if joined == faction else "宣誓加入 " + title if joined.is_empty() else "改换效忠 · 支付 %d 信用点" % switch_fee
	var join: Button = _command(u.body, join_label, "join_civilization", faction)
	join.name = "CivilizationJoin"
	join_button = join
	var join_reason: String = civ.join_reason(faction)
	join.disabled = not join_reason.is_empty()
	join.tooltip_text = join_reason if not join_reason.is_empty() else "完成入籍，启用此文明的爵位和专属权限。"
	join_note = u._text_to(u.body, join_reason, 13)
	join_note.add_theme_color_override("font_color", UISkin.WARN)

func _build_contribution(faction: String,civ: RefCounted) -> void:
	u._text("材料捐献", 18)
	u._text("仅消耗核心站仓库中的普通自有物资；保障和借用物资不参与。", 13)
	for donation: Dictionary in u.catalog.rows("civilization_donation_defs"):
		if donation.faction_id != faction: continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UISkin.GAP)
		u.body.add_child(row)
		var label: Label = u._text_to(row, "%s × %d / 批 → 声望 +%d" % [u._item_name(str(donation.item_id)), int(donation.units_per_batch), int(donation.reputation_per_batch)], 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var amount := SpinBox.new()
		amount.name = "CivilizationDonationQuantity_" + str(donation.donation_id)
		amount.min_value = 1; amount.max_value = u.gameplay.rule("civilization_max_donation_batches"); amount.step = 1; amount.value = 1
		amount.custom_minimum_size = Vector2(72, 30)
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(amount)
		var button: Button = _command(row, "捐献", "donate_civilization", donation.donation_id, amount)
		button.name = "CivilizationDonate_" + str(donation.donation_id)
		var update: Callable = func(_value: float = 1.0):
			if not _current() or not is_instance_valid(amount) or not is_instance_valid(button):return
			var quantity: int = Interaction.integer_input(amount)
			var reason: String = civ.donation_reason(str(donation.donation_id), quantity)
			button.disabled = not reason.is_empty(); button.tooltip_text = reason
		Interaction.watch_integer(amount,update)
		update.call()
	u._text("爵位与权限", 18)
	for rank: Dictionary in u.catalog.rows("civilization_rank_defs"):
		if rank.faction_id != faction: continue
		var benefit: String = "正式效忠后生效" if int(rank.rank_level) == 1 else "专属舰船与设计学" if int(rank.rank_level) in [2, 4, 6] else ("舰队战争 · 另需指挥资格" if u.gameplay.honors.supported() else "可受领舰队战争委托") if int(rank.rank_level) == 5 else ""
		u._text("%s · 声望 %d%s" % [rank.display_name, int(rank.required_reputation), " · " + benefit if not benefit.is_empty() else ""], 13)
	u._text("文明专属舰船", 18)
	for hull: Dictionary in u.catalog.rows("civilization_hull_defs"):
		if hull.faction_id != faction: continue
		var ship: Dictionary = u.catalog.one("ship_defs", "ship_id", hull.ship_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UISkin.GAP)
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

func _build_campaign(faction: String,civ: RefCounted) -> void:
	u._text("舰队战争", 18)
	war_status = u._text_to(u.body, "", 14)
	war_status.name = "CivilizationWarStatus"
	war_status.add_theme_color_override("font_color", UISkin.ICE)
	var campaign: RefCounted = civ.active_war()
	if campaign != null:
		if u.gameplay.frontier.owns_campaign(campaign):
			_command(u.body,"查看战役阶段","frontier_open",campaign.war_id).name="FrontierCampaignEntry"
		var controls := HFlowContainer.new()
		u.body.add_child(controls)
		_command(controls, "战区航路", "war_navigate", "")
		_command(controls, "推进", "fleet_command", "advance")
		_command(controls, "集结", "fleet_command", "regroup")
		_command(controls, "集火当前目标", "fleet_command", "focus", null, str(u.target_id))
		_command(controls, "撤退返航" if u.gameplay.march.state_for(campaign.war_id)!=null else "撤退并放弃战役", "fleet_command", "retreat")
	else:
		u._text("舰队伯爵"+("取得指挥资格后" if u.gameplay.honors.supported() else "")+"可在所属核心站受领委托。"+("先侦察/护送，再完成战斗目标和修复。" if u.gameplay.frontier.supported() else "3艘友舰在战区集结，清敌后驻留占领。")+"出生航路受保护。", 13)
		for war: Dictionary in u.catalog.rows("civilization_war_defs"):
			if war.faction_id != faction: continue
			var reason: String = civ.war_reason(war.war_id)
			var owner: String = civ.owner(war.target_sector_id)
			var button: Button = _command(u.body, "远征 " + u._sector_name(war.target_sector_id) + (" · 中立争夺" if owner.is_empty() else " · 已归属" + civ.faction_name(owner)), "start_war", war.war_id)
			button.name = "CivilizationWar_" + str(war.war_id)
			button.disabled = not reason.is_empty()
			button.tooltip_text = reason if not reason.is_empty() else "战役奖励：%d 信用点、声望 %d；胜利后星系归属所代表文明。" % [int(war.reward_credit), int(war.reward_reputation)]
	if u.gameplay.frontier.supported():
		u._text("边疆治理",18)
		for control: Dictionary in u.catalog.rows("frontier_governance_defs"):
			if civ.owner(control.sector_id)!=faction:continue
			var id: String=control.sector_id
			_command(u.body,u._sector_name(id)+" · "+u.gameplay.frontier.status_text(id),"frontier_open",id).name="FrontierGovernance_"+id

func _build_commander(faction: String) -> void:
	if not u.gameplay.honors.supported():
		u._text("当前世界尚未启用指挥考核。",14)
		return
	honor_panel=preload("res://runtime/ui/civilization_honors_panel.gd").new()
	honor_panel.build(u,faction,self)

func tick() -> void:
	if not _current():return
	if growth_panel!=null:growth_panel.tick()
	if honor_panel!=null:honor_panel.tick()
	var civ: RefCounted = u.gameplay.civilizations
	if is_instance_valid(join_button):
		var reason: String = civ.join_reason(str(u.civilization_selected_faction))
		join_button.disabled = not reason.is_empty()
		join_button.tooltip_text = reason
		if is_instance_valid(join_note):
			join_note.text = reason
			join_note.visible = not reason.is_empty()
	if not is_instance_valid(war_status): return
	var campaign: RefCounted = civ.active_war()
	if campaign == null:
		war_status.text = "当前没有进行中的舰队战争。"
		return
	if u.gameplay.frontier.owns_campaign(campaign):war_status.text=u.gameplay.frontier.status_text(campaign.war_id);return
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
		if not _current():return
		if u.state != state or u.catalog != catalog or u.business_generation != generation or state.epoch != epoch or u.page != "civilizations" or u.gameplay.station() != station: return
		if amount != null:
			if Interaction.integer_input(amount)<=0: u.notify("请输入范围内的整数批数。", true); return
			amount.apply()
		u.requested.emit(action, target, int(amount.value) if amount != null else 1, extra)
	var button: Button = u._button(parent, title, callback)
	var font: Font = button.get_theme_font("font")
	var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x + button.get_theme_stylebox("normal").get_minimum_size().x + 12.0
	button.custom_minimum_size.x = minf(maxf(116.0, width), maxf(116.0, u.root.size.x - 64.0))
	button.set_meta("action", action); button.set_meta("target", target)
	return button
