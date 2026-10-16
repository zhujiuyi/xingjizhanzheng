extends VBoxContainer
const UISkin = preload("res://runtime/ui_theme.gd")
const Types = preload("res://contracts/contract_types.gd")
const Interaction = preload("res://runtime/ui/ui_interaction.gd")
const Availability = preload("res://runtime/ui/drone_availability.gd")
var u: Node
var context: Dictionary
var order_buttons: Dictionary = {}
var cards: Array[Dictionary] = []
var cards_root: VBoxContainer
var _intel_view: VBoxContainer
var signature: String = ""
var elapsed: float = 0.0
var build_generation: int=0
func setup(ui: Node) -> void:
	u = ui; context = Interaction.context(u)
	add_theme_constant_override("separation", UISkin.SECTION_GAP); _build()
func _current() -> bool:
	return not is_queued_for_deletion() and Interaction.current(u, context, self)
func _request(action: String,target: String,quantity: int,extra: String,built: int=0) -> Callable:
	var reference: WeakRef=weakref(self)
	return func():
		var panel: Node=reference.get_ref() as Node
		if not is_instance_valid(panel) or not panel._current() or (built!=0 and panel.build_generation!=built):return
		var destination: String=str(panel.u.target_id) if action=="drone_command" and extra=="attack" else target
		panel.u.requested.emit(action,destination,quantity,extra)
func _signature() -> String:
	var parts: Array[String] = [str(u.state.ship().status),u.state.ship().ship_instance_id,u.state.player().docked_station_id,u.target_id]
	for equipment: RefCounted in Availability.equipped(u.gameplay):
		var row: RefCounted=u.gameplay.drone_control.bay(equipment.item_instance_id)
		parts.append(equipment.item_instance_id+":"+str(equipment.enabled)+(":"+str(row.revision)+":"+str(row.stock_units)+":"+str(row.deployed_units)+":"+row.command_kind if row!=null else ""))
	return "|".join(parts)
func _build() -> void:
	var view: Dictionary=u.capture_local_view(self)
	build_generation+=1;var built: int=build_generation
	cards.clear();order_buttons.clear();signature = _signature()
	var keep_intel: bool=u.state.ship().status==Types.ShipStatus.FLYING and not Availability.equipped(u.gameplay,"recon").is_empty()
	for child: Node in get_children():
		remove_child(child)
		if child!=_intel_view or not keep_intel:child.queue_free()
	if not keep_intel:_intel_view=null
	if not Availability.capable(u.gameplay):
		u._text_to(self,"当前舰船不支持无人机。",14);u.finish_local_rebuild(self,view);return
	var installation: Array=Availability.equipped(u.gameplay)
	if installation.is_empty():
		u._text_to(self,"当前舰尚未安装无人机库。请在舰船配装中安装后整备。",14);u.finish_local_rebuild(self,view);return
	var flying: bool=u.state.ship().status==Types.ShipStatus.FLYING
	if flying:
		var has_attack: bool=not Availability.equipped(u.gameplay,"attack").is_empty()
		var deployed: bool=false
		for equipment: RefCounted in installation:
			var bay: RefCounted=u.gameplay.drone_control.bay(equipment.item_instance_id)
			if bay!=null and bay.deployed_units>0:deployed=true
		var kinds: Array[String]=[]
		if has_attack:
			kinds.append("attack")
		if has_attack or deployed:
			kinds.append("follow")
			kinds.append("recall")
		if not kinds.is_empty():
			var orders: HFlowContainer = HFlowContainer.new();add_child(orders)
			orders.add_theme_constant_override("h_separation",UISkin.GAP);orders.add_theme_constant_override("v_separation",UISkin.GAP)
			for kind: String in kinds:
				var order: String = kind
				var button: Button = u._button(orders, {"attack":"攻击选中目标","follow":"跟随母舰","recall":"回收全部无人机"}[kind],_request("drone_command","",1,order,built))
				button.name = "DroneOrder_" + kind; order_buttons[kind] = button
			u._text_to(self,"跟随与回收适用于已连接编队；在外时保存等待回收。",12).add_theme_color_override("font_color",UISkin.MUTED)
	cards_root = VBoxContainer.new(); cards_root.add_theme_constant_override("separation",UISkin.SECTION_GAP); add_child(cards_root)
	for equipment: RefCounted in installation:
		var row: RefCounted=u.gameplay.drone_control.bay(equipment.item_instance_id)
		var item: RefCounted = u.state.find("item_instance_state", "item_instance_id", equipment.item_instance_id)
		if item == null or row==null: continue
		var card: VBoxContainer = VBoxContainer.new(); card.add_theme_constant_override("separation", UISkin.GAP); cards_root.add_child(card)
		u._text_to(card, u._item_name(item.item_def_id), UISkin.SIZE_PAGE)
		var label: Label = u._text_to(card, "", 14);label.name="DroneReadout_"+item.item_instance_id
		label.add_theme_color_override("font_color", UISkin.ICE)
		label.mouse_filter=Control.MOUSE_FILTER_PASS
		var spec: Dictionary = u.gameplay.drone_control.definition(item.item_def_id)
		var count: int = u.gameplay.drone_control.maximum(item.item_def_id)
		var actions: HFlowContainer = HFlowContainer.new(); card.add_child(actions)
		actions.add_theme_constant_override("h_separation",UISkin.GAP);actions.add_theme_constant_override("v_separation",UISkin.GAP)
		var item_id: String = item.item_instance_id
		var revision: String = str(row.revision)
		var missing: int = count - row.stock_units
		var replenish: Button
		if not flying:
			if missing>0:
				var cost: Label=u._text_to(card,"补充需结构料 %d + %d 信用点" % [missing*int(spec.material_per_unit),missing*int(spec.credit_per_unit)],13)
				cost.add_theme_color_override("font_color",UISkin.MUTED);card.move_child(cost,actions.get_index())
				replenish=u._button(actions,"补充 %d 架" % missing,_request("drone_replenish",item_id,missing,revision,built))
				replenish.name = "DroneReplenish_" + item_id
			var toggle: Button = u._button(actions, "停用机库" if equipment.enabled else "启用机库",_request("set_module_enabled",item_id,1,"off" if equipment.enabled else "on",built))
			toggle.name = "DroneToggle_" + item_id
		var launches: Array=[]
		if flying and spec.has("role_kind"):
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
		cards.append({"row":row,"item":item,"equipment":equipment,"label":label,"button":replenish,"missing":missing,"revision":revision,"maximum":count,"launches":launches,"flying":flying})
	if cards.is_empty():u._text_to(cards_root,"当前舰尚无可整备的无人机库。",UISkin.SIZE_BODY)
	if keep_intel:
		if not is_instance_valid(_intel_view):
			_intel_view=preload("res://runtime/ui/auxiliary_intel_panel.gd").new();add_child(_intel_view);_intel_view.setup(u)
		else:add_child(_intel_view)
	_update();u.finish_local_rebuild(self,view)
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
		else:mode="待命" if row.stock_units>0 else "机库已空，返站补充"
		if not card.flying:mode="已启用"
		if not card.equipment.enabled:mode="已停用"
		elif card.item.durability<=0.0:mode="已损坏"
		card.label.text = "存量 %d/%d · 在外 %d · %s" % [row.stock_units,card.maximum,row.deployed_units,mode] if card.flying else "存量 %d/%d · %s" % [row.stock_units,card.maximum,mode]
		var definition: Dictionary=u.gameplay.drone_control.definition(card.item.item_def_id)
		card.label.tooltip_text="单机结构 %.0f · 累计损失 %d / 已补充 %d\n超出通信范围自动返航；损毁或超时扣除存量。" % [float(definition.hull_hp),row.lost_units,row.replenished_units]
		if is_instance_valid(card.button):
			var reason: String = u.gameplay.drone_control.replenish_reason(card.item.item_instance_id, card.missing, card.revision)
			var spec: Dictionary=u.gameplay.drone_control.definition(card.item.item_def_id)
			Interaction.action_state(card.button,reason,"结构料 %d + %d 信用点" % [card.missing*int(spec.material_per_unit),card.missing*int(spec.credit_per_unit)])
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
