extends VBoxContainer
func setup(u: Node) -> void:
	u._text_to(self,"18舰角色与装配预算",20)
	u._text_to(self,"船体预算和允许武器来自当前世界规则；当前实际配装在“配装分析”比较。通行还受航门质量上限限制，文明专属采购/制造取决于当前效忠和资格。",14)
	# Reuse the shared business rows so thumbnails, wrapping and action access
	# follow the same narrow-screen rules as the fleet and warehouse.
	var list: VBoxContainer=u._business_list("舰种角色矩阵")
	u.body.remove_child(list);add_child(list)
	for spec: Dictionary in u.gameplay.rows("ship_role_guidance_defs"):
		var ship: Dictionary=u.gameplay.definition("ship_defs","ship_id",spec.ship_id)
		var text: String=str(spec.strength_text)+"\n代价："+str(spec.tradeoff_text)+"\n适用："+str(spec.recommended_targets)+"\n"+u._ship_weapon_description(spec.ship_id)+"\n供能%.0f / 算力%.0f / 安装质量%.0fkg · 速度%.0fm/s · 货舱%.0fL / 矿舱%.0fL · 基础防护 %.0f/%.0f/%.0f" % [ship.power_capacity,ship.cpu_capacity,ship.max_installed_mass_kg,ship.max_speed_mps,ship.cargo_l,ship.mineral_cargo_l,ship.shield_max,ship.armor_max,ship.hull_max]
		u._asset_row(list,spec.ship_id,"ship",spec.ship_id,u._ship_name(spec.ship_id)+" · "+str(spec.role_name),text,"艘","1","—",str(ship.base_ask_credit)+"信用点","船体基础预算")
