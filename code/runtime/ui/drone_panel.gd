extends VBoxContainer
const UISkin = preload("res://runtime/ui_theme.gd")
var u: Node
var context: Dictionary
var order_buttons: Dictionary = {}
var cards: Array[Dictionary] = []
var cards_root: VBoxContainer
var signature: String = ""
var elapsed: float = 0.0
var build_generation: int=0
func setup(ui: Node) -> void:
	u = ui; context = {"state":u.state,"epoch":u.state.epoch,"session":u.state.session_id,"generation":u.business_generation}
	add_theme_constant_override("separation", UISkin.SECTION_GAP); _build()
func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(u) and u.page == "drones" and u.state == context.state and u.state.epoch == context.epoch and u.state.session_id == context.session and u.business_generation == context.generation and u.body.is_ancestor_of(self)
func _request(action: String,target: String,quantity: int,extra: String,built: int=0) -> Callable:
	var reference: WeakRef=weakref(self)
	return func():
		var panel: Node=reference.get_ref() as Node
		if not is_instance_valid(panel) or not panel._current() or (built!=0 and panel.build_generation!=built):return
		var destination: String=str(panel.u.target_id) if action=="drone_command" and extra=="attack" else target
		panel.u.requested.emit(action,destination,quantity,extra)
func _signature() -> String:
	var parts: Array[String] = [str(u.state.ship().status),u.state.player().docked_station_id,u.target_id]
	for row: RefCounted in u.state.rows("drone_bay_state")+u.state.rows("auxiliary_bay_state"):
		var equipment: RefCounted = u.state.find("equipment_state", "item_instance_id", row.item_instance_id)
		parts.append(row.item_instance_id + ":" + str(row.revision) + ":" + str(row.stock_units) + ":" + row.command_kind + ":" + str(equipment.enabled if equipment != null else false))
	return "|".join(parts)
func _build() -> void:
	build_generation+=1;var built: int=build_generation
	cards.clear(); signature = _signature()
	if not u.gameplay.drone_control.supported(): u._text_to(self, "当前旧规则世界沿用原无人机出击方式。", 15); return
	if cards_root == null:
		u._text_to(self, "攻击、维修和侦察各自出击；跟随与回收适用于全编队。", 14).add_theme_color_override("font_color", UISkin.MUTED)
		var orders: HFlowContainer = HFlowContainer.new(); add_child(orders)
		for kind: String in ["attack","follow","recall"]:
			var order: String = kind
			var button: Button = u._button(orders, {"attack":"攻击选中目标","follow":"跟随母舰","recall":"回收全部无人机"}[kind],_request("drone_command","",1,order))
			button.name = "DroneOrder_" + kind; order_buttons[kind] = button
		u._text_to(self, "超出通信范围自动返航；损毁或超时扣除存量。在外时保存等待回收。", 13).add_theme_color_override("font_color", UISkin.MUTED)
		cards_root = VBoxContainer.new(); cards_root.add_theme_constant_override("separation",UISkin.SECTION_GAP); add_child(cards_root)
		if u.gameplay.auxiliary_drones.supported():
			var intel: VBoxContainer=preload("res://runtime/ui/auxiliary_intel_panel.gd").new();add_child(intel);intel.setup(u)
	for child: Node in cards_root.get_children(): cards_root.remove_child(child); child.queue_free()
	for row: RefCounted in u.state.rows("drone_bay_state")+u.state.rows("auxiliary_bay_state"):
		var item: RefCounted = u.state.find("item_instance_state", "item_instance_id", row.item_instance_id)
		var hull: RefCounted=u.gameplay.auxiliary_drones.owner(row.item_instance_id)
		var deployment: RefCounted=u.gameplay.owned_fleet.row(hull.ship_instance_id) if hull!=null else null
		if item == null or (not u.gameplay.inventory.accessible(item.container_id) and (deployment==null or not u.gameplay.owned_fleet.connected(deployment))): continue
		var card: VBoxContainer = VBoxContainer.new(); card.add_theme_constant_override("separation", UISkin.GAP); cards_root.add_child(card)
		u._text_to(card, u._item_name(item.item_def_id), 19)
		var label: Label = u._text_to(card, "", 14);label.name="DroneReadout_"+item.item_instance_id
		label.add_theme_color_override("font_color", UISkin.ICE)
		var spec: Dictionary = u.gameplay.drone_control.definition(item.item_def_id)
		var count: int = u.gameplay.drone_control.maximum(item.item_def_id)
		u._text_to(card,"单机结构 %.0f · 补充：结构料 %d + %d 信用点" % [float(spec.hull_hp),int(spec.material_per_unit),int(spec.credit_per_unit)],13).add_theme_color_override("font_color", UISkin.MUTED)
		var actions: HFlowContainer = HFlowContainer.new(); card.add_child(actions)
		var item_id: String = item.item_instance_id
		var revision: String = str(row.revision)
		var missing: int = count - row.stock_units
		var replenish: Button = u._button(actions,"补充 %d 架" % missing if missing>0 else "机库完整",_request("drone_replenish",item_id,missing,revision,built))
		replenish.name = "DroneReplenish_" + item_id
		var equipment: RefCounted = u.state.find("equipment_state", "item_instance_id", item_id)
		if equipment != null and u.gameplay.equipped(u.state.ship()).has(equipment):
			var toggle: Button = u._button(actions, "停用机库" if equipment.enabled else "启用机库",_request("set_module_enabled",item_id,1,"off" if equipment.enabled else "on",built))
			toggle.name = "DroneToggle_" + item_id
		var launches: Array=[]
		if spec.has("role_kind"):
			var definition: Dictionary=u.gameplay.definition("module_defs","module_id",item.item_def_id)
			var capability: Label=u._text_to(card,"修复装甲 / 结构 · %.0f HP/机" % (float(spec.restore_amount)*item.quality_multiplier) if spec.role_kind=="repair" else "探测 %s · 记录 %.0f 秒" % [XJSpaceUnits.distance(float(spec.sensor_range_m)),float(spec.observation_ttl_s)],13);card.move_child(capability,actions.get_index())
			capability.add_theme_color_override("font_color", UISkin.MUTED)
			var budget: Label=u._text_to(card,"通信 %s · 每次电容 %.0f / 热量 %.0f%s" % [XJSpaceUnits.distance(float(definition.range_m)),float(definition.energy_eu),float(definition.heat_hu)," / 维修包 %d" % int(spec.consumable_per_sortie) if spec.role_kind=="repair" else ""],13);card.move_child(budget,actions.get_index())
			budget.add_theme_color_override("font_color", UISkin.MUTED)
			var targets: Array=[["侦察选中地点",str(u.target_id)]] if spec.role_kind=="recon" else [["维修选中友舰",str(u.target_id)],["维修主舰",u.state.ship().ship_instance_id]]
			for pair: Array in targets:
				var destination: String=pair[1];var expected: String=u.gameplay.auxiliary_drones.token(item_id)
				var launch: Button=u._button(actions,pair[0],_request("auxiliary_launch",item_id,1,destination+"|"+expected,built))
				launch.name="AuxiliaryLaunch_"+item_id+("_self" if destination==u.state.ship().ship_instance_id else "_target");launches.append({"button":launch,"target":destination,"token":expected})
		cards.append({"row":row,"item":item,"label":label,"button":replenish,"missing":missing,"revision":revision,"maximum":count,"launches":launches})
	if cards.is_empty():u._text_to(cards_root,"尚无可访问机库。攻击机库装在武器槽，维修/侦察机库装在获准舰种的作业槽。",15)
	_update()
func _update() -> void:
	if not _current(): return
	for kind: String in order_buttons:
		var reason: String = u.gameplay.drone_control.command_reason(kind, u.target_id if kind == "attack" else "")
		order_buttons[kind].disabled = not reason.is_empty(); order_buttons[kind].tooltip_text = reason
	for card: Dictionary in cards:
		var row: RefCounted = card.row
		var mode: String=str({"attack":"攻击","follow":"跟随","recall":"回收"}[row.command_kind]);var live: Array=[]
		for drone: RefCounted in u.gameplay.drone_control.live.values():
			if drone.module_instance_id==card.item.item_instance_id:live.append(drone)
		if not live.is_empty():
			if live.all(func(drone: RefCounted):return drone.returning):mode="返航"
			elif live.any(func(drone: RefCounted):return drone.command_kind=="repair"):mode="维修作业"
			elif live.any(func(drone: RefCounted):return drone.command_kind=="recon"):mode="侦察作业"
		card.label.text = "存量 %d/%d · 在外 %d · %s · 累计损失 %d / 已补充 %d" % [row.stock_units,card.maximum,row.deployed_units,mode,row.lost_units,row.replenished_units]
		var reason: String = u.gameplay.drone_control.replenish_reason(card.item.item_instance_id, card.missing, card.revision)
		card.button.disabled = not reason.is_empty(); card.button.tooltip_text = reason
		for launch: Dictionary in card.launches:
			var blocked: String=u.gameplay.auxiliary_drones.reason(card.item.item_instance_id,launch.target,launch.token)
			launch.button.disabled=not blocked.is_empty();launch.button.tooltip_text=blocked
func _process(delta: float) -> void:
	if not _current(): return
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0.0
	if _signature() != signature: _build()
	else: _update()
