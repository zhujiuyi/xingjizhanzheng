extends VBoxContainer
## The hull catalogue on the stage frame: eighteen cards on the left, the selected
## hull's role and budget on the right, and that hull's numbers along the bottom.
## Here the selection does drive the exhibit, because browsing hulls is the point of
## the page.

var u: Node

func setup(ui: Node) -> void:
	u = ui
	u.stage_rows.clear()
	var list: VBoxContainer = u._information_list(self, "舰种角色", "ship_roles")
	list.set("details_external", true)
	# Role captions are two characters. Zero width collapsed them to one character per
	# line; 32 px holds the caption and still leaves the name almost all the card.
	list.set("status_min_width", 32)
	list.connect("selection_changed", _selected)
	for spec: Dictionary in u.gameplay.rows("ship_role_guidance_defs"):
		var ship: Dictionary = u.gameplay.definition("ship_defs", "ship_id", spec.ship_id)
		var role: String = str(spec.role_name)
		var facts: String = str(spec.strength_text) + "\n代价：" + str(spec.tradeoff_text) + "\n适用：" + str(spec.recommended_targets)
		u.stage_rows[str(spec.ship_id)] = {"ship": ship, "role": role, "facts": facts, "spec": spec}
		var entry: Dictionary = list.call("append_row", str(spec.ship_id), u.ItemPortraits.texture("ship", spec.ship_id), u._ship_name(spec.ship_id), "", "", "", "", "", role)
		entry.row.set_meta("asset_kind", "ship")
		entry.row.set_meta("asset_id", spec.ship_id)
	var chosen: String = str(list.get("selected_id"))
	if not chosen.is_empty(): _selected(chosen)

func _selected(id: String) -> void:
	var record: Dictionary = u.stage_rows.get(id, {})
	if record.is_empty(): return
	if is_instance_valid(u.hangar): u.hangar.call("change_ship", id)
	var ship: Dictionary = record.ship
	for child: Node in u.stage_detail.get_children():
		u.stage_detail.remove_child(child)
		child.queue_free()
	var title: Label = u._text_to(u.stage_detail, u._ship_name(id), u.UISkin.SIZE_PAGE)
	u.UISkin.apply_text_style(title, "page")
	var role: Label = u._text_to(u.stage_detail, str(record.role), u.UISkin.SIZE_SECTION)
	u.UISkin.apply_text_style(role, "section")
	role.add_theme_color_override("font_color", u.UISkin.ICE)
	var line: HSeparator = HSeparator.new()
	u.stage_detail.add_child(line)
	var facts: Label = u._text_to(u.stage_detail, str(record.facts), u.UISkin.SIZE_BODY)
	facts.add_theme_color_override("font_color", u.UISkin.MUTED)
	var mounts: Label = u._text_to(u.stage_detail, u._ship_weapon_description(id), u.UISkin.SIZE_BODY)
	mounts.add_theme_color_override("font_color", u.UISkin.MUTED)
	var price: Label = u._text_to(u.stage_detail, "%d 信用点 · 裸舰预算" % int(ship.base_ask_credit), u.UISkin.SIZE_SECTION)
	u.UISkin.apply_text_style(price, "section")
	u._stage_strip_clear()
	u._stage_stat("供能 / 算力", "%.0f / %.0f" % [float(ship.power_capacity), float(ship.cpu_capacity)])
	u._stage_stat("速度", XJSpaceUnits.speed(float(ship.max_speed_mps)))
	u._stage_stat("货舱 / 矿舱", "%.0f / %.0f L" % [float(ship.cargo_l), float(ship.mineral_cargo_l)])
	u._stage_stat("基础防护", "%.0f / %.0f / %.0f" % [float(ship.shield_max), float(ship.armor_max), float(ship.hull_max)])
