extends VBoxContainer
func setup(u: Node) -> void:
	u._text_to(self,"18舰角色与装配预算",20)
	u._text_to(self,"裸舰预算与能力。装备效果在配装分析比较；详细长处与限制可悬停查看。",13)
	# Reuse the shared business rows so thumbnails, wrapping and action access
	# follow the same narrow-screen rules as the fleet and warehouse.
	var list: VBoxContainer=u._business_list("舰种角色矩阵")
	u.body.remove_child(list);add_child(list)
	for spec: Dictionary in u.gameplay.rows("ship_role_guidance_defs"):
		var ship: Dictionary=u.gameplay.definition("ship_defs","ship_id",spec.ship_id)
		var text: String=str(spec.strength_text)+"\n代价："+str(spec.tradeoff_text)+"\n适用："+str(spec.recommended_targets)+"\n"+u._ship_weapon_description(spec.ship_id)+"\n供能%.0f / 算力%.0f / 安装质量%.0fkg · 速度%.0fm/s · 货舱%.0fL / 矿舱%.0fL · 基础防护 %.0f/%.0f/%.0f" % [ship.power_capacity,ship.cpu_capacity,ship.max_installed_mass_kg,ship.max_speed_mps,ship.cargo_l,ship.mineral_cargo_l,ship.shield_max,ship.armor_max,ship.hull_max]
		var short: String="供能%.0f / 算力%.0f · 货舱%.0fm³" % [ship.power_capacity,ship.cpu_capacity,float(ship.cargo_l)/1000.0]
		if u.gameplay.ship_roles.supported():
			var cap: Dictionary=u.gameplay.definition("ship_role_capability_defs","ship_id",spec.ship_id)
			var b: Dictionary=u.gameplay.rows("role_balance_defs")[0]
			short+="\n裸舰调查×%.2f" % clampf(float(ship.scan_strength)*float(cap.survey_multiplier)/float(b.scan_reference_strength),float(b.min_survey_rate),float(b.max_survey_rate))
			if cap.remote_repair_allowed:short+=" · 可远修护盾/装甲"
			if float(cap.sensor_multiplier)>1.0:short+=" · 扫描器感知×%.1f" % cap.sensor_multiplier
		var entry: Dictionary=u._asset_row(list,spec.ship_id,"ship",spec.ship_id,u._ship_name(spec.ship_id)+" · "+str(spec.role_name),short,"艘","1","—",str(ship.base_ask_credit)+"信用点","船体基础预算")
		entry.name.tooltip_text=text;entry.description.tooltip_text=text
