extends VBoxContainer
const UISkin=preload("res://runtime/ui_theme.gd")
const Interaction=preload("res://runtime/ui/ui_interaction.gd")
const T=preload("res://contracts/contract_types.gd")
var u: Node
var context: Dictionary
var entries: Dictionary={}
func setup(ui: Node) -> void:
	u=ui;name="ConsignmentPanel"
	context={"state":u.state,"epoch":u.state.epoch,"session":u.state.session_id,"ship":u.state.ship().ship_instance_id,"generation":u.business_generation}
	add_theme_constant_override("separation",UISkin.SECTION_GAP)
	u._text_to(self,"按实际舱容选批数；送达退押金并结算奖励。增推时受击可能损失货物。",13).add_theme_color_override("font_color",UISkin.MUTED)
	for spec: Dictionary in u.gameplay.rows("consignment_defs"):
		var frame: PanelContainer=PanelContainer.new();frame.add_theme_stylebox_override("panel",UISkin.panel_style());add_child(frame)
		var card: VBoxContainer=VBoxContainer.new();card.add_theme_constant_override("separation",UISkin.GAP);frame.add_child(card)
		u._text_to(card,str(spec.display_name),18)
		u._text_to(card,"%s → %s" % [u._station_name(spec.origin_station_id),u._station_name(spec.destination_station_id)],13)
		u._text_to(card,"限时%.0f分 · 整备%.0f分 · 货损押金不退" % [float(spec.deadline_s)/60.0,float(spec.cooldown_s)/60.0],12).add_theme_color_override("font_color",UISkin.MUTED)
		var status: Label=u._text_to(card,"",14);status.name="FreightStatus_"+str(spec.contract_id)
		var quote: Label=u._text_to(card,"",12);quote.name="FreightQuote_"+str(spec.contract_id)
		quote.add_theme_color_override("font_color",UISkin.MUTED)
		var actions: HFlowContainer=HFlowContainer.new();actions.add_theme_constant_override("h_separation",UISkin.GAP);card.add_child(actions)
		var quantity: SpinBox=SpinBox.new();quantity.name="FreightQuantity_"+str(spec.contract_id)
		quantity.min_value=1;quantity.max_value=spec.max_units;quantity.step=1;quantity.value=maxi(1,u.gameplay.consignments.available(spec.contract_id));actions.add_child(quantity)
		var buttons: Dictionary={}
		for action: String in ["dispatch","deliver","withdraw","claim"]:
			var button: Button=u._button(actions,{"dispatch":"装载签约","deliver":"交付货物","withdraw":"中止承运","claim":"领取结算"}[action],_act.bind(str(spec.contract_id),action))
			button.name="Freight_"+action+"_"+str(spec.contract_id);buttons[action]=button
			if action=="withdraw":UISkin.apply_button(button,"danger")
		var route: Button=u._button(actions,"前往站点",func():
			if _current():u.requested.emit("consignment_navigate",str(spec.contract_id),1,str(u.gameplay.consignments.instance(spec.contract_id).generation)))
		route.name="FreightRoute_"+str(spec.contract_id)
		var locate: Button=u._button(actions,"星图定位",func():
			if _current():u.requested.emit("consignment_map",str(spec.contract_id),1,str(u.gameplay.consignments.instance(spec.contract_id).generation)))
		locate.name="FreightMap_"+str(spec.contract_id)
		entries[spec.contract_id]={"status":status,"quote":quote,"quantity":quantity,"buttons":buttons,"route":route}
		Interaction.watch_integer(quantity,refresh)
	refresh()
func _current() -> bool:
	return is_inside_tree() and is_instance_valid(u) and u.page=="consignments" and u.state==context.state and u.state.epoch==context.epoch and u.state.session_id==context.session and u.state.ship().ship_instance_id==context.ship and u.business_generation==context.generation
func _act(id: String,action: String) -> void:
	if not _current():return
	var row: RefCounted=u.gameplay.consignments.instance(id)
	var amount: int=Interaction.integer_input(entries[id].quantity) if action=="dispatch" else 1
	if amount<=0:refresh();u.notify("请输入范围内的整数批数。",true);return
	var reason: String=u.gameplay.consignments.action_reason(id,action,amount)
	if not reason.is_empty():refresh();u.notify(reason,true);return
	if action=="dispatch":entries[id].quantity.apply()
	u.requested.emit("consignment_action",id,amount,action+":"+str(row.generation))
func refresh() -> void:
	if not _current():return
	for id: String in entries:
		var view: Dictionary=entries[id];var row: RefCounted=u.gameplay.consignments.instance(id);var d: Dictionary=u.gameplay.consignments.definition(id)
		view.status.text={"idle":"可承运","active":"运输中","ready":"待结算","claimed":"整备中"}[row.phase]+" · 在途%d / 送达%d / 损失%d批" % [row.cargo_units,row.delivered_units,row.lost_units]
		if row.phase=="active":view.status.text+=" · 剩余%.0f秒" % row.remaining_s
		elif row.phase=="claimed":view.status.text+=" · %.0f秒" % row.cooldown_remaining_s
		view.status.add_theme_color_override("font_color",UISkin.AMBER if row.exposure_remaining_s>0.0 else UISkin.ICE)
		view.quantity.visible=row.phase=="idle"
		var amount: int=Interaction.integer_input(view.quantity) if row.phase=="idle" else 1
		if row.phase=="idle":view.quote.text="本舰可载%d批 · 每批%.0fm³ / %.0f吨 · 押金%d + 手续费%d · 奖励%d" % [u.gameplay.consignments.available(id),float(d.unit_volume_l)/1000.0,float(d.unit_mass_kg)/1000.0,amount*int(d.deposit_per_unit),d.fee_credit,amount*int(d.reward_per_unit)]
		elif row.phase=="active":view.quote.text="在押%d · 已损押金%d · 送达奖励%d%s" % [row.cargo_units*int(d.deposit_per_unit),row.lost_units*int(d.deposit_per_unit),row.cargo_units*int(d.reward_per_unit)," · 暴露 %.1f秒" % row.exposure_remaining_s if row.exposure_remaining_s>0.0 else ""]
		else:view.quote.text="可退押金%d · 奖励%d · 损失押金%d" % [(row.delivered_units+row.returned_units)*int(d.deposit_per_unit),row.delivered_units*int(d.reward_per_unit),row.lost_units*int(d.deposit_per_unit)]
		if row.phase=="idle" and amount<=0:view.quote.text="请输入范围内的整数批数。"
		var guidance: Dictionary=u.gameplay.consignments.guidance(id)
		Interaction.action_state(view.route,"请先出港；可用星图定位查看站点。" if u.state.ship().status!=T.ShipStatus.FLYING else str(guidance.get("route_reason","")))
		for action: String in view.buttons:
			var button: Button=view.buttons[action]
			button.visible=(action=="dispatch" and row.phase=="idle") or (action in ["deliver","withdraw"] and row.phase=="active") or (action=="claim" and row.phase=="ready")
			var reason: String="请输入范围内的整数批数。" if action=="dispatch" and amount<=0 else u.gameplay.consignments.action_reason(id,action,amount)
			if reason.is_empty() and u.operation_blocks_flight:reason="正在等待稳定保存后离开。"
			Interaction.action_state(button,reason,"原站退回完好货物可退对应押金；其他地点中止会损失在途货物和押金。手续费不退。" if action=="withdraw" else "")
