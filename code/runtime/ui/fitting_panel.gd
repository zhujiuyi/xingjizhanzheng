extends VBoxContainer
const T = preload("res://contracts/contract_types.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
var u: Node
var context: Dictionary
var distance: SpinBox
var target: OptionButton
var layer: OptionButton
var candidate: OptionButton
var slot: OptionButton
var results: VBoxContainer
var apply_button: Button
var last_quote: Dictionary={}
var comparison_signature: String=""
var comparison_note: Label
func setup(ui: Node) -> void:
	u=ui;context={"state":u.state,"epoch":u.state.epoch,"session":u.state.session_id,"station":u.state.player().docked_station_id,"ship":u.state.ship().ship_instance_id,"generation":u.business_generation}
	add_theme_constant_override("separation",UISkin.GAP)
	var filters: HFlowContainer=HFlowContainer.new()
	var conditions: Button=u._button(self,"计算条件",func():filters.visible=not filters.visible)
	conditions.name="FittingConditionsToggle"
	conditions.toggle_mode=true
	conditions.toggled.connect(func(open: bool):conditions.text="收起条件" if open else "计算条件")
	add_child(filters);filters.hide()
	var distance_label: Label = u._text_to(filters,"局部射击距离（米）",14)
	distance_label.name = "FittingDistanceLabel"
	distance_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	distance_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	distance=SpinBox.new();distance.name="FittingDistance";distance.min_value=0;distance.max_value=10000000;distance.step=100;distance.value=u.gameplay.fitting_analysis.config().default_distance_m;filters.add_child(distance)
	target=OptionButton.new();target.name="FittingTarget";target.add_item("无抗性参考");target.set_item_metadata(0,"")
	for spec: Dictionary in u.gameplay.rows("npc_archetype_defs"):
		target.add_item(str(spec.display_name));target.set_item_metadata(target.item_count-1,str(spec.archetype_id))
	filters.add_child(target)
	layer=OptionButton.new();layer.name="FittingTargetLayer"
	for name: String in ["护盾","装甲","结构"]:layer.add_item(name)
	filters.add_child(layer)
	var selection: HFlowContainer=HFlowContainer.new();add_child(selection)
	candidate=OptionButton.new();candidate.name="FittingCandidate";candidate.add_item("选择本地自有设备");candidate.set_item_metadata(0,"")
	for item: RefCounted in u.state.rows("item_instance_state"):
		if item.owner_player_id!=u.state.player().player_id or item.policy_id!="normal_owned" or not u.gameplay.inventory.accessible(item.container_id) or u.gameplay.definition("module_defs","module_id",item.item_def_id).is_empty():continue
		candidate.add_item(u._item_name(item.item_def_id)+" · 品质%.2f" % item.quality_multiplier);candidate.set_item_metadata(candidate.item_count-1,item.item_instance_id)
	candidate.fit_to_longest_item=false;candidate.custom_minimum_size=Vector2(220,32)
	selection.add_child(candidate)
	slot=OptionButton.new();slot.name="FittingSlot"
	for row: RefCounted in u.state.rows("container_state"):
		if not row.has_ship_instance_id or row.ship_instance_id!=u.state.ship().ship_instance_id or row.kind!=T.ContainerKind.SLOT:continue
		var type: String=["weapon","work","utility","structure"][row.slot_type]
		slot.add_item(["武器","作业","通用","结构"][row.slot_type]+"槽 "+str(row.slot_index+1));slot.set_item_metadata(slot.item_count-1,type+":"+str(row.slot_index))
	selection.add_child(slot)
	u._button(selection,"比较",_calculate).name="FittingCalculate"
	apply_button=u._button(selection,"应用替换",_apply);apply_button.name="FittingApply";apply_button.disabled=true
	var links: HFlowContainer=HFlowContainer.new();add_child(links)
	u._button(links,"舰船定位",func():
		if _current():u.show_page("ship_roles")).name="FittingRoles"
	u._button(links,"火控研究",func():
		if _current():u.show_page("research")).name="FittingSpecializations"
	comparison_note=u._text_to(self,"",13);comparison_note.name="FittingComparisonStatus";comparison_note.add_theme_color_override("font_color",UISkin.AMBER);comparison_note.hide()
	results=VBoxContainer.new();results.name="FittingResults";add_child(results)
	for picker: OptionButton in [candidate,slot,target,layer]:picker.item_selected.connect(func(_index: int):_invalidate())
	distance.value_changed.connect(func(_value: float):_invalidate())
	distance.get_line_edit().text_changed.connect(func(_text: String):_invalidate())
	_calculate()
func _current() -> bool:
	return is_inside_tree() and is_instance_valid(u) and not u.loading_suspended and u.page=="fitting_analysis" and u.state==context.state and u.state.epoch==context.epoch and u.state.session_id==context.session and u.state.ship().ship_instance_id==context.ship and u.state.player().docked_station_id==context.station and u.business_generation==context.generation
func _clear() -> void:
	for child: Node in results.get_children():results.remove_child(child);child.queue_free()

func _input_signature() -> String:
	return JSON.stringify([str(candidate.get_selected_metadata()),str(slot.get_selected_metadata()),str(target.get_selected_metadata()),layer.selected,float(distance.get_line_edit().text) if distance.get_line_edit().text.is_valid_float() else null])

func _invalidate() -> void:
	last_quote={};comparison_signature=""
	if is_instance_valid(apply_button):apply_button.disabled=true;apply_button.tooltip_text="计算条件已改变，请重新比较。"
	if is_instance_valid(comparison_note):comparison_note.text="计算条件已改变，请重新比较。";comparison_note.show()
func _calculate() -> void:
	if not _current():return
	var raw: String=distance.get_line_edit().text.strip_edges()
	if not raw.is_valid_float() or not is_finite(float(raw)) or float(raw)<distance.min_value or float(raw)>distance.max_value:
		_invalidate();comparison_note.text="请输入范围内的射击距离。";return
	distance.apply()
	_clear();last_quote={};apply_button.disabled=true;comparison_note.hide()
	var item: String=str(candidate.get_selected_metadata());var archetype: String=str(target.get_selected_metadata());var target_layer: String=["shield","armor","hull"][layer.selected]
	if item.is_empty():
		_summary(u.gameplay.fitting_analysis.report(distance.value,archetype,target_layer),{});return
	var quote: Dictionary=u.gameplay.fitting_analysis.quote(item,str(slot.get_selected_metadata()),distance.value,archetype,target_layer)
	_summary(quote.current,quote.preview if quote.ok else {})
	if not quote.ok:u._text_to(results,"无法替换 · "+str(quote.reason),14);return
	last_quote=quote;comparison_signature=_input_signature();apply_button.disabled=quote.old_item_id==item
	apply_button.tooltip_text="该设备已安装在所选槽位。" if apply_button.disabled else "应用当前比较中的设备与槽位；提交时再次检查资格。"
func _summary(before: Dictionary,after: Dictionary) -> void:
	if not before.get("ok",false):u._text_to(results,str(before.get("reason","分析不可用")),14);return
	var caption: Label=u._text_to(results,"%s · %s · 满电就绪起算" % [XJSpaceUnits.distance(before.distance_m),target.get_item_text(target.selected)],13)
	caption.tooltip_text="使用当前弹药、无人机库存、设备开关、品质与耐久。电容充满、热量归零、冷却就绪起算。目标静止、无遮挡且处于射界内；未计机动、掩体和无人机损失。"
	caption.mouse_filter=Control.MOUSE_FILTER_PASS
	var table: GridContainer=GridContainer.new();table.name="FittingKeyValues";table.columns=4 if not after.is_empty() else 2
	table.add_theme_constant_override("h_separation",UISkin.SECTION_GAP);table.add_theme_constant_override("v_separation",UISkin.GAP)
	var plate: PanelContainer=PanelContainer.new();plate.add_theme_stylebox_override("panel",UISkin.panel_style());results.add_child(plate);plate.add_child(table)
	_cell(table,"关键指标",UISkin.MUTED);_cell(table,"当前",UISkin.MUTED)
	if not after.is_empty():_cell(table,"替换后",UISkin.MUTED);_cell(table,"变化",UISkin.MUTED)
	_metric(table,"理论输出",before.nominal_dps,after.get("nominal_dps"),"DPS")
	_metric(table,"%.0f秒爆发" % before.burst_window_s,before.burst_damage,after.get("burst_damage"),"伤害")
	_metric(table,"持续输出",before.sustained_dps,after.get("sustained_dps"),"DPS","模拟最后%.0f秒的发射输出" % before.sustained_span_s)
	_metric(table,"射程上限",_range(before),_range(after) if not after.is_empty() else null,"m")
	_text_row(table,"电容续航",_time(before.first_energy_stall_s),_time(after.first_energy_stall_s) if not after.is_empty() else "","首次电容不足；稳定表示%.0f秒模拟内未触及" % before.horizon_s)
	_text_row(table,"热量余裕",_time(before.first_heat_stall_s),_time(after.first_heat_stall_s) if not after.is_empty() else "","首次热量受限；稳定表示%.0f秒模拟内未触及" % before.horizon_s)
	_text_row(table,"供能 / 算力",_budget(before),_budget(after) if not after.is_empty() else "","安装预算占用，越低余量越多；完整数值见详情","%+.0f PU / %+.0f CU" % [after.metrics.power_used-before.metrics.power_used,after.metrics.cpu_used-before.metrics.cpu_used] if not after.is_empty() else "")
	_issues(before,"当前")
	if not after.is_empty():_issues(after,"替换后")
	var detail: VBoxContainer=VBoxContainer.new();detail.name="FittingDetailedValues"
	var toggle: Button=u._button(results,"完整数值",func():detail.visible=not detail.visible)
	toggle.name="FittingDetailsToggle";toggle.toggle_mode=true
	toggle.toggled.connect(func(open: bool):toggle.text="收起详情" if open else "完整数值")
	results.add_child(detail)
	# Reuse the complete calculation view only inside the explicit disclosure.
	var summary: VBoxContainer=results;results=detail
	_render("当前",before)
	if not after.is_empty():_render("替换后",after)
	results=summary;detail.hide()
func _cell(parent: Node,value: String,color: Color=UISkin.TEXT) -> Label:
	var label: Label=u._text_to(parent,value,14);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color",color);label.mouse_filter=Control.MOUSE_FILTER_PASS
	var grid: GridContainer=parent as GridContainer
	if grid!=null and (grid.get_child_count()-1)%grid.columns>0:label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	return label
func _metric(table: GridContainer,title: String,before: float,after: Variant,unit: String,hint: String="") -> void:
	_cell(table,title,UISkin.MUTED).tooltip_text=hint
	_cell(table,XJSpaceUnits.distance(before) if unit=="m" else "%.1f %s" % [before,unit])
	if after==null:return
	_cell(table,XJSpaceUnits.distance(float(after)) if unit=="m" else "%.1f %s" % [float(after),unit])
	var change: float=float(after)-before
	_cell(table,"—" if absf(change)<0.05 else "%+.1f %s" % [change,unit],UISkin.ICE if change>0.05 else UISkin.AMBER if change< -0.05 else UISkin.MUTED)
func _text_row(table: GridContainer,title: String,before: String,after: String,hint: String,change: String="") -> void:
	_cell(table,title,UISkin.MUTED).tooltip_text=hint;_cell(table,before,UISkin.AMBER if before.contains("受限") else UISkin.TEXT).tooltip_text=hint
	if table.columns==4:_cell(table,after,UISkin.AMBER if after.contains("受限") else UISkin.TEXT).tooltip_text=hint;_cell(table,change if not change.is_empty() else "—" if before==after else "见数值",UISkin.MUTED)
func _budget(report: Dictionary) -> String:
	return "%.0f%% / %.0f%%" % [100.0*report.metrics.power_used/report.metrics.power_capacity,100.0*report.metrics.cpu_used/report.metrics.cpu_capacity]
func _range(report: Dictionary) -> float:
	var value: float=0.0
	for weapon: Dictionary in report.get("weapons",[]):
		if weapon.enabled:value=maxf(value,float(weapon.range_m))
	return value
func _issues(report: Dictionary,title: String) -> void:
	var issues: PackedStringArray=[];var outside: int=0;var active: int=0
	for weapon: Dictionary in report.weapons:
		if weapon.enabled:
			active+=1
			if not weapon.in_range:outside+=1
	if active==0:issues.append("无可用武器")
	if outside>0:issues.append("%d件武器超射程" % outside)
	if report.first_ammo_stall_s>=0:issues.append("%.1f秒缺弹" % report.first_ammo_stall_s)
	if not issues.is_empty():_cell(results,title+" · "+" / ".join(issues),UISkin.AMBER)
func _render(title: String,report: Dictionary) -> void:
	if not report.ok:u._text_to(results,str(report.reason),14);return
	u._text_to(results,title,18)
	var m: Dictionary=report.metrics
	var table: GridContainer=GridContainer.new();table.columns=2;table.add_theme_constant_override("h_separation",UISkin.SECTION_GAP);results.add_child(table)
	var values: Array[Array]=[
		["%.0f秒平均" % report.horizon_s,"%.1f DPS" % report.average_dps],
		["条件命中估计","%.1f DPS · %.0f秒到达 %.1f伤害" % [report.conditional_dps,report.burst_window_s,report.conditional_burst]],
		["电容消耗 / 回充","%.1f / %.1f EU/s" % [report.energy_rate,m.energy_recharge]],
		["产热 / 散热","%.1f / %.1f HU/s" % [report.heat_rate,m.heat_cooling]],
		["供能 / 算力","%.0f/%.0f PU · %.0f/%.0f CU" % [m.power_used,m.power_capacity,m.cpu_used,m.cpu_capacity]],
		["安装质量","%.0f/%.0f kg" % [m.installed_mass_kg,m.max_installed_mass_kg]],
		["速度 / 加速 / 转向","%.1f m/s · %.2f m/s² · %.2f rad/s" % [m.speed_mps,m.acceleration_mps2,m.turn_radps]],
		["货舱 / 矿舱","%.0f/%.0f L · %.0f/%.0f L" % [m.cargo_used_l,m.cargo_capacity_l,m.mineral_used_l,m.mineral_capacity_l]],
		["护盾 / 装甲 / 结构","%.0f / %.0f / %.0f" % [m.shield_max,m.armor_max,m.hull_max]],
		["电容 / 热量上限","%.0f EU / %.0f HU" % [m.energy_max,m.heat_max]]]
	for row: Array in values:_cell(table,str(row[0]),UISkin.MUTED);_cell(table,str(row[1]))
	for weapon: Dictionary in report.weapons:
		var label: Label=_cell(results,"%s · %s · %.2f秒/次 · %d次循环" % [u._item_name(weapon.module_id),XJSpaceUnits.distance(weapon.range_m),weapon.cycle_s,weapon.shots])
		label.tooltip_text="%s · 射界 ±%.1f° · 到达 %.2f秒\n出击 %d / 库存 %d · 假设途中无损回收" % ["启用 / 距离内" if weapon.enabled and weapon.in_range else "距离外" if weapon.enabled else "关闭 / 不可出击",rad_to_deg(weapon.cone_rad),weapon.flight_s,weapon.pods,weapon.stock]
func _time(value: float) -> String:return "稳定" if value<0.0 else "%.1f秒受限" % value
func _apply() -> void:
	if not _current() or last_quote.is_empty():return
	if comparison_signature!=_input_signature():_invalidate();return
	u.requested.emit("replace_fit",str(last_quote.item_id),1,str(last_quote.slot_ref)+"|"+str(last_quote.old_item_id))
