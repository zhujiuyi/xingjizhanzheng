extends VBoxContainer
var u: Node
var context: Dictionary
var order_buttons: Dictionary = {}
var cards: Array[Dictionary] = []
var cards_root: VBoxContainer
var signature: String = ""
var elapsed: float = 0.0
func setup(ui: Node) -> void:
	u = ui; context = {"state":u.state,"epoch":u.state.epoch,"session":u.state.session_id,"generation":u.business_generation}
	add_theme_constant_override("separation", 10); _build()
func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(u) and u.page == "drones" and u.state == context.state and u.state.epoch == context.epoch and u.state.session_id == context.session and u.business_generation == context.generation and u.body.is_ancestor_of(self)
func _signature() -> String:
	var parts: Array[String] = [str(u.state.ship().status),u.state.player().docked_station_id]
	for row: RefCounted in u.state.rows("drone_bay_state"):
		var equipment: RefCounted = u.state.find("equipment_state", "item_instance_id", row.item_instance_id)
		parts.append(row.item_instance_id + ":" + str(row.revision) + ":" + str(row.stock_units) + ":" + row.command_kind + ":" + str(equipment.enabled if equipment != null else false))
	return "|".join(parts)
func _build() -> void:
	cards.clear(); signature = _signature()
	if not u.gameplay.drone_control.supported(): u._text_to(self, "当前旧规则世界沿用原无人机出击方式。", 15); return
	if cards_root == null:
		u._text_to(self, "航行期间本面板保持世界运行。每次付费出击只携带一次攻击，完成攻击后回收；跟随用于重新布位，回收可停止尚未发出的攻击。", 14)
		var orders: HFlowContainer = HFlowContainer.new(); add_child(orders)
		for kind: String in ["attack","follow","recall"]:
			var order: String = kind
			var button: Button = u._button(orders, {"attack":"攻击选中目标","follow":"跟随母舰","recall":"回收全部无人机"}[kind], func():
				if _current(): u.requested.emit("drone_command", u.target_id if order == "attack" else "", 1, order))
			button.name = "DroneOrder_" + kind; order_buttons[kind] = button
		u._text_to(self, "通信超限会停止攻击并返航。击毁或超时失联扣除机库存量；在外时保存会等待回收。命中无人机可反制敌方载机舰。", 13)
		cards_root = VBoxContainer.new(); cards_root.add_theme_constant_override("separation",10); add_child(cards_root)
	for child: Node in cards_root.get_children(): cards_root.remove_child(child); child.queue_free()
	for row: RefCounted in u.state.rows("drone_bay_state"):
		var item: RefCounted = u.state.find("item_instance_state", "item_instance_id", row.item_instance_id)
		if item == null or not u.gameplay.inventory.accessible(item.container_id): continue
		var card: VBoxContainer = VBoxContainer.new(); card.add_theme_constant_override("separation", 6); cards_root.add_child(card)
		u._text_to(card, u._item_name(item.item_def_id), 19)
		var label: Label = u._text_to(card, "", 14)
		var spec: Dictionary = u.catalog.one("drone_management_defs", "module_id", item.item_def_id)
		var count: int = int(u.catalog.one("drone_defs", "module_id", item.item_def_id).drone_count)
		u._text_to(card, "每机补充：普通结构料 × %d + %d 信用点；在当前站仓库扣除。单机结构 %.0f，可被实际火力击毁。" % [int(spec.material_per_unit), int(spec.credit_per_unit), float(spec.hull_hp)], 13)
		var actions: HFlowContainer = HFlowContainer.new(); card.add_child(actions)
		var item_id: String = item.item_instance_id
		var revision: String = str(row.revision)
		var missing: int = count - row.stock_units
		var replenish: Button = u._button(actions, "补满缺口 × %d" % missing, func():
			if _current(): u.requested.emit("drone_replenish", item_id, missing, revision))
		replenish.name = "DroneReplenish_" + item_id
		var equipment: RefCounted = u.state.find("equipment_state", "item_instance_id", item_id)
		if equipment != null and u.gameplay.equipped(u.state.ship()).has(equipment):
			var toggle: Button = u._button(actions, "停用机库" if equipment.enabled else "启用机库", func():
				if _current(): u.requested.emit("set_module_enabled", item_id, 1, "off" if equipment.enabled else "on"))
			toggle.name = "DroneToggle_" + item_id
		cards.append({"row":row,"item":item,"label":label,"button":replenish,"missing":missing,"revision":revision,"maximum":count})
	if cards.is_empty(): u._text_to(cards_root, "当前没有可访问的无人机舱。需取得对应科技，在允许该家族的舰船武器槽中装载。", 15)
	_update()
func _update() -> void:
	if not _current(): return
	for kind: String in order_buttons:
		var reason: String = u.gameplay.drone_control.command_reason(kind, u.target_id if kind == "attack" else "")
		order_buttons[kind].disabled = not reason.is_empty(); order_buttons[kind].tooltip_text = reason
	for card: Dictionary in cards:
		var row: RefCounted = card.row
		card.label.text = "存量 %d/%d · 在外 %d · 模式 %s · 累计损失 %d / 已补充 %d" % [row.stock_units,card.maximum,row.deployed_units,str({"attack":"攻击","follow":"跟随","recall":"回收"}[row.command_kind]),row.lost_units,row.replenished_units]
		var reason: String = u.gameplay.drone_control.replenish_reason(card.item.item_instance_id, card.missing, card.revision)
		card.button.disabled = not reason.is_empty(); card.button.tooltip_text = reason
func _process(delta: float) -> void:
	if not _current(): return
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0.0
	if _signature() != signature: _build()
	else: _update()
