extends VBoxContainer
const T = preload("res://contracts/contract_types.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
const Interaction = preload("res://runtime/ui/ui_interaction.gd")
const Services = preload("res://runtime/ui/service_navigation.gd")
var u: CanvasLayer
var context_state: RefCounted
var context_epoch: int
var context_generation: int
var summaries: Array[Dictionary] = []
var signature: String = ""
func setup(ui: CanvasLayer) -> void:
	u = ui; context_state = u.state; context_epoch = u.state.epoch
	context_generation=u.business_generation
	add_theme_constant_override("separation", UISkin.SECTION_GAP)
	u._text_to(self, "战术行动 · 拆除与封锁突破", 20)
	var focused: RefCounted=u.gameplay.operations.focused()
	var list: VBoxContainer=u._information_list(self,"可选行动","operations",str(focused.operation_id) if focused!=null else "")
	for spec: Dictionary in u.gameplay.rows("operation_defs"):
		var row: RefCounted = u.gameplay.operations.instance(spec.operation_id)
		var entry: Dictionary=list.append_row(str(spec.operation_id),Services.icon("missions"),str(spec.display_name),"","","","","","")
		var card: VBoxContainer = entry.details
		u._text_to(card, "在对应签发站接取，出港后抵达起点开始。无需清场；实际到达撤离点后返回签发站交付。暂停与退出不推进计时。", 13).add_theme_color_override("font_color", UISkin.MUTED)
		var text: Label = u._text_to(card, "", 14)
		text.add_theme_color_override("font_color", UISkin.ICE)
		var guide: String = "实际射击拆除推进干扰装置。装置周围降低推进效率，与截击干扰取较强效果。完成部分拆除可保留对应成果，敌舰仍可存活。" if spec.operation_kind == "demolition" else "最多运送%d批物资，每批占%.0f升 / %.0f千克。按本舰真实空余装载；加速暴露%.0f秒，暴露时每累计%.0f实际伤害损失一批，允许主动抛货。" % [spec.target_units,spec.cargo_volume_l,spec.cargo_mass_kg,spec.exposure_duration_s,spec.loss_damage_hp]
		u._text_to(card, guide, 14).add_theme_color_override("font_color", UISkin.MUTED)
		u._text_to(card,"签发/交付：%s · 起点/撤离范围 %.0f 米 · 时限 %.0f 秒 · 每完成一份 %d 信用点、%d 声望" % [u._station_name(spec.station_id),spec.interaction_radius_m,spec.duration_s,spec.credit_per_unit,spec.reputation_per_unit],13).add_theme_color_override("font_color", UISkin.MUTED)
		var controls: HFlowContainer = entry.actions;card.move_child(controls,card.get_child_count()-1)
		var id: String = spec.operation_id; var gen: String = str(row.generation)
		u._button(controls,"星图定位",func():
			if _row_current(id): u.requested.emit("operation_map",id,1,gen)).name = "OperationMap_"+id
		var travel: Button=u._button(controls,"前往当前目标",func():
			if _row_current(id): u.requested.emit("operation_nav",id,1,gen))
		travel.name = "OperationNavigate_"+id
		Interaction.action_state(travel,"请先出港；可用星图定位查看目标。" if u.state.ship().status!=T.ShipStatus.FLYING else str(u.gameplay.operations.guidance(id).get("route_reason","")))
		var actions: Array = ["accept"] if row.phase in ["available","claimed","failed","withdrawn"] else ["start","withdraw"] if row.phase == "accepted" else ["exit","jettison","withdraw"] if row.phase == "active" and spec.operation_kind == "breakthrough" else ["exit","withdraw"] if row.phase == "active" else ["claim"]
		var buttons: Array[Dictionary] = []
		for action: String in actions:
			var verb: String = action
			var button: Button = u._button(controls,str({"accept":"接取行动","start":"抵达起点并开始","exit":"确认送达/撤离","withdraw":"撤回行动","jettison":"抛弃一批货物","claim":"交付成果"}[verb]),func():
				if _row_current(id): u.requested.emit("operation_action",id,1,verb+":"+gen))
			button.name = "OperationAction_"+id+"_"+verb
			if verb in ["withdraw", "jettison"]: UISkin.apply_button(button, "danger")
			buttons.append({"button":button,"action":verb})
		summaries.append({"id":id,"text":text,"buttons":buttons,"summary":entry.status,"details":card,"spec":spec})
	signature = _signature(); _update()
func _current() -> bool: return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(u) and not u.loading_suspended and u.page == "operations" and u.state == context_state and u.state.epoch == context_epoch and u.business_generation==context_generation and u.body.is_ancestor_of(self)
func _row_current(id: String) -> bool:
	if not _current():return false
	for entry: Dictionary in summaries:
		if entry.id==id:return is_instance_valid(entry.details) and entry.details.is_visible_in_tree()
	return false
func _signature() -> String:
	var result: String = ""
	for row: RefCounted in u.state.rows("operation_state"): result += "%s:%s:%d;" % [row.operation_id,row.phase,row.generation]
	return result
func _process(_delta: float) -> void:
	if not _current(): return
	if signature != _signature():
		set_process(false); u.refresh_page.call_deferred(); return
	_update()
func _update() -> void:
	for entry: Dictionary in summaries:
		var row: RefCounted = u.gameplay.operations.instance(entry.id)
		entry.text.text = u.gameplay.operations.status_text(entry.id) + (" · 整备 %.0f 秒" % row.cooldown_remaining_s if row.cooldown_remaining_s > 0.0 else "")
		var phase: String=str({"available":"可接取","accepted":"已接取","active":"行动中","ready":"待交付","claimed":"已交付","failed":"未完成","withdrawn":"已撤回"}[row.phase])
		var progress: int=row.cargo_units if row.phase=="active" and entry.spec.operation_kind=="breakthrough" else row.completed_units
		entry.summary.text=phase+" · %d/%d" % [progress,entry.spec.target_units]
		entry.summary.tooltip_text=entry.text.text
		for record: Dictionary in entry.buttons:
			var reason: String = u.gameplay.operations.action_reason(entry.id,record.action)
			Interaction.action_state(record.button,reason,"立即抛弃一批在途货物，该批不再计入送达成果。" if record.action=="jettison" else "撤回本次行动，未完成成果按原规则结算。" if record.action=="withdraw" else "")
