extends VBoxContainer
var u: Node
var context: Dictionary
var quantity: SpinBox
var status: Label
var cards: Array[Dictionary]=[]
var donation: Button
func setup(ui: Node) -> void:
	u=ui;context={"state":u.state,"epoch":u.state.epoch,"session":u.state.session_id,"station":u.state.player().docked_station_id,"generation":u.business_generation}
	add_theme_constant_override("separation",8)
	u._text_to(self,"火控专精 · 可积累研究",20)
	status=u._text_to(self,"",14);status.name="SpecializationEvidence"
	u._text_to(self,"探索成果、战术敌舰和行动交付均可取得分析证据；普通材料分析提供稳定替代来源。研究分批投入并保存，完成后解锁采购和制造设计。一舰限一项火控专精。",14)
	var inputs: HFlowContainer=HFlowContainer.new();add_child(inputs)
	u._text_to(inputs,"本次投入分析点",14)
	quantity=SpinBox.new();quantity.name="SpecializationQuantity";quantity.min_value=1;quantity.max_value=u.gameplay.specializations.balance.max_donation_points;quantity.step=1;quantity.value=1;inputs.add_child(quantity)
	donation=u._button(inputs,"投入结构料进行分析",func():
		if _current():u.requested.emit("specialization_donate","",int(quantity.value),""));donation.name="SpecializationDonate"
	var balance: Dictionary=u.gameplay.specializations.balance
	u._text_to(self,"材料分析每点：本站仓库普通结构料 × %d、%d信用点；研究每点另按设计列出的费用投入。" % [balance.donation_units_per_point,balance.donation_credit_per_point],13)
	for spec: Dictionary in u.gameplay.rows("specialization_research_defs"):
		var card: VBoxContainer=VBoxContainer.new();add_child(card)
		u._text_to(card,str(spec.display_name),18)
		u._text_to(card,u.gameplay.specializations.description(spec.module_id),14)
		var progress: Label=u._text_to(card,"",14)
		u._text_to(card,"所需分析 %d 点 · 每点 %d信用点" % [spec.required_points,spec.credit_per_point],13)
		var id: String=spec.research_id;var controls: HFlowContainer=HFlowContainer.new();card.add_child(controls)
		var invest: Button=u._button(controls,"投入所选分析点",func():
			if not _current():return
			var row: RefCounted=u.state.find("specialization_research_state","research_id",id)
			u.requested.emit("specialization_research",id,int(quantity.value),str(row.invested_points if row!=null else 0)))
		invest.name="SpecializationInvest_"+id
		var buy: Button=u._button(controls,"采购已解锁设备",func():
			if _current():u.show_page("market"));buy.name="SpecializationMarket_"+id
		var build: Button=u._button(controls,"制造已解锁设备",func():
			if _current():u.show_page("industry"));build.name="SpecializationIndustry_"+id
		cards.append({"id":id,"spec":spec,"label":progress,"invest":invest,"buy":buy,"build":build})
	_update()
func _current() -> bool:return is_inside_tree() and is_instance_valid(u) and u.page=="research" and u.state==context.state and u.state.epoch==context.epoch and u.state.session_id==context.session and u.state.player().docked_station_id==context.station and u.business_generation==context.generation
func _process(_delta: float) -> void:
	if _current():_update()
func _update() -> void:
	var progress: RefCounted=u.gameplay.specializations.progress()
	status.text="可用分析证据 %d · 累计取得 %d · 已投入 %d" % [u.gameplay.specializations.available(),progress.earned_points,progress.spent_points]
	var reason: String=u.gameplay.specializations.donate_reason(int(quantity.value));donation.disabled=not reason.is_empty();donation.tooltip_text=reason
	for entry: Dictionary in cards:
		var row: RefCounted=u.state.find("specialization_research_state","research_id",entry.id)
		var unlocked: bool=u.gameplay.unlocked(entry.spec.reward_unlock_id)
		entry.label.text="研究 %d / %d · %s" % [row.invested_points if row!=null else 0,entry.spec.required_points,"设计已解锁" if unlocked else "可继续积累"]
		reason=u.gameplay.specializations.research_reason(entry.id,int(quantity.value));entry.invest.disabled=not reason.is_empty();entry.invest.tooltip_text=reason
		entry.buy.disabled=not unlocked;entry.build.disabled=not unlocked
