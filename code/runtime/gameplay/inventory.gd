extends RefCounted
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
func _init(gameplay: RefCounted) -> void: g = gameplay

func warehouse(station_id: String) -> String:
	for c in g.state.rows("container_state"):
		if c.kind == T.ContainerKind.STATION and c.station_id == station_id and c.owner_player_id == g.state.player().player_id: return c.container_id
	var station: Dictionary = g.definition("station_defs", "station_id", station_id)
	var c: D.ContainerStateDto = D.ContainerStateDto.new()
	c.container_id = g.id("warehouse"); c.owner_player_id = g.state.player().player_id; c.kind = T.ContainerKind.STATION
	c.has_station_id = true; c.station_id = station_id; c.sector_id = station.sector_id
	g.state.add("container_state", c)
	return c.container_id

func hold(ship: D.ShipStateDto, kind: T.ContainerKind) -> String:
	for c in g.state.rows("container_state"):
		if c.ship_instance_id == ship.ship_instance_id and c.kind == kind: return c.container_id
	return ""

func slot(ship: D.ShipStateDto, slot_type: String, index: int) -> D.ContainerStateDto:
	var ordinal: int = ["weapon","work","utility","structure"].find(slot_type)
	for c in g.state.rows("container_state"):
		if c.ship_instance_id == ship.ship_instance_id and c.kind == T.ContainerKind.SLOT and c.slot_type == ordinal and c.slot_index == index: return c
	return null

func accessible(container_id: String) -> bool:
	var c: D.ContainerStateDto = g.state.find("container_state", "container_id", container_id)
	if c == null or c.owner_player_id != g.state.player().player_id: return false
	if c.kind == T.ContainerKind.STATION: return c.station_id == g.station()
	if c.kind == T.ContainerKind.WRECK: return c.sector_id == g.state.current_sector() and g.position(g.state.ship()).distance_to(Vector3(c.pos_x,c.pos_y,c.pos_z)) <= g.rule("wreck_pickup_radius_m")
	return c.ship_instance_id == g.state.ship().ship_instance_id and g.state.ship().status not in [T.ShipStatus.DESTROYED,T.ShipStatus.RETURNED]

func totals(container_id: String) -> Dictionary:
	var mass: float = 0; var volume: float = 0
	for s in g.state.rows("inventory_stack_state"):
		if s.container_id != container_id: continue
		var def: Dictionary = g.definition("item_defs", "item_id", s.item_def_id)
		mass += def.unit_mass_kg * s.quantity; volume += def.unit_volume_l * s.quantity
	for item in g.state.rows("item_instance_state"):
		if item.container_id != container_id: continue
		var def: Dictionary = g.definition("item_defs", "item_id", item.item_def_id)
		mass += def.unit_mass_kg; volume += def.unit_volume_l
	for package: D.SalvagePackageStateDto in g.state.rows("salvage_package_state"):
		if package.status != "sealed" or not package.has_host_container_id or package.host_container_id != container_id: continue
		var def: Dictionary = g.definition("salvage_package_defs", "package_def_id", package.package_def_id)
		mass += float(def.mass_kg)
		volume += float(def.volume_m3) * 1000.0
	return {"mass":mass,"volume":volume}

func room(container_id: String, item_id: String, requested: int, moved_mass_credit: float = 0.0) -> int:
	var c: D.ContainerStateDto = g.state.find("container_state", "container_id", container_id)
	if c == null: return 0
	if c.kind in [T.ContainerKind.STATION,T.ContainerKind.WRECK]: return requested
	if c.kind == T.ContainerKind.SLOT: return 0
	var item: Dictionary = g.definition("item_defs", "item_id", item_id)
	if c.kind == T.ContainerKind.MINERAL and item.item_type != "ore": return 0
	var ship: D.ShipStateDto = g.state.find("ship_state", "ship_instance_id", c.ship_instance_id)
	var m: Dictionary = g.metrics(ship)
	var cap: int = m.mineral_capacity_l if c.kind == T.ContainerKind.MINERAL else m.cargo_capacity_l
	var used: float = float(totals(container_id).volume)
	var by_volume: int = int(floor(float(cap-used)/item.unit_volume_l)) if item.unit_volume_l > 0 else requested
	var by_mass: int = int(floor(maxf(0,m.max_payload_mass_kg-m.payload_mass_kg+moved_mass_credit)/item.unit_mass_kg)) if item.unit_mass_kg>0 else requested
	return maxi(0, mini(requested, mini(by_volume,by_mass)))

## Read-only admission quote for warehouse rows. Internal relocation retains
## its existing policy semantics; this entry point describes user transfers.
func quote_transfer(kind: String, target_id: String, quantity: int, destination: String) -> Dictionary:
	var rejected: Dictionary = {"ok": false, "reason": "", "maximum": 0}
	if g == null or g.state == null or g.state.player() == null or g.state.ship() == null:
		rejected.reason = "当前档案不可用"
		return rejected
	var ship: D.ShipStateDto = g.state.ship()
	if ship.status != T.ShipStatus.DOCKED or g.station().is_empty():
		rejected.reason = "需要先停靠空间站"
		return rejected
	var service_available: bool = false
	for service: Dictionary in g.rows("station_service_defs"):
		if service.station_id == g.station() and service.service_id == "warehouse":
			if not g.unlocked(str(service.required_unlock_id)):
				rejected.reason = "本站仓库服务尚未解锁"
				return rejected
			service_available = true
			break
	if not service_available:
		rejected.reason = "本站不提供仓库服务"
		return rejected
	var source_id: String = ""
	var item_def_id: String = ""
	var available: int = 1
	var package_def_id: String = ""
	match kind:
		"stack":
			var stack: D.InventoryStackStateDto = g.state.find("inventory_stack_state", "stack_id", target_id)
			if stack == null:
				rejected.reason = "货物已转移或不存在"
				return rejected
			if stack.policy_id != "normal_owned":
				rejected.reason = "保障或任务绑定物资不可手动转移"
				return rejected
			source_id = stack.container_id
			item_def_id = stack.item_def_id
			available = stack.quantity
		"item":
			var item: D.ItemInstanceStateDto = g.state.find("item_instance_state", "item_instance_id", target_id)
			if item == null or item.owner_player_id != g.state.player().player_id:
				rejected.reason = "设备已转移或不属于当前玩家"
				return rejected
			if item.policy_id != "normal_owned":
				rejected.reason = "保障或借用设备不可手动转移"
				return rejected
			if g.state.find("equipment_state", "item_instance_id", target_id) != null:
				rejected.reason = "需先卸下已安装设备"
				return rejected
			source_id = item.container_id
			item_def_id = item.item_def_id
		"salvage":
			var package: D.SalvagePackageStateDto = g.state.find("salvage_package_state", "package_id", target_id)
			if package == null or package.status != "sealed" or not package.has_host_container_id:
				rejected.reason = "打捞包不存在或已鉴定"
				return rejected
			source_id = package.host_container_id
			package_def_id = package.package_def_id
		_:
			rejected.reason = "未知货物类型"
			return rejected
	var source: D.ContainerStateDto = g.state.find("container_state", "container_id", source_id)
	var target: D.ContainerStateDto = g.state.find("container_state", "container_id", destination)
	for container: D.ContainerStateDto in [source, target]:
		if container == null or container.kind not in [T.ContainerKind.STATION, T.ContainerKind.CARGO, T.ContainerKind.MINERAL] or not accessible(container.container_id):
			rejected.reason = "仅可转移当前舰与当前空间站的货物"
			return rejected
	if source_id == destination:
		rejected.reason = "源与目标相同"
		return rejected
	var limit: int = int(g.rule("business_quantity_limit"))
	var maximum: int = mini(available, limit)
	var mass_credit: float = 0.0
	if not package_def_id.is_empty():
		if source.kind not in [T.ContainerKind.CARGO, T.ContainerKind.STATION] or target.kind not in [T.ContainerKind.CARGO, T.ContainerKind.STATION]:
			rejected.reason = "打捞包只能放入货舱或空间站仓库"
			return rejected
		if g.encounters == null:
			rejected.reason = "打捞服务不可用"
			return rejected
		var definition: Dictionary = g.definition("salvage_package_defs", "package_def_id", package_def_id)
		if definition.is_empty():
			rejected.reason = "打捞包定义不可用"
			return rejected
		if source.has_ship_instance_id and source.ship_instance_id == target.ship_instance_id:
			mass_credit = float(definition.mass_kg)
		if not g.encounters.can_hold(destination, package_def_id, mass_credit): maximum = 0
	else:
		var definition: Dictionary = g.definition("item_defs", "item_id", item_def_id)
		if definition.is_empty():
			rejected.reason = "货物定义不可用"
			return rejected
		if target.kind == T.ContainerKind.MINERAL and definition.item_type != "ore":
			rejected.reason = "矿舱仅可装入原矿"
			return rejected
		if source.has_ship_instance_id and source.ship_instance_id == target.ship_instance_id:
			mass_credit = float(definition.unit_mass_kg) * maximum
		maximum = room(destination, item_def_id, maximum, mass_credit)
	rejected.maximum = maximum
	if quantity <= 0 or quantity > limit:
		rejected.reason = "数量超出合法范围"
		return rejected
	if kind != "stack" and quantity != 1:
		rejected.reason = "独立设备与打捞包每次转移一件"
		return rejected
	if quantity > available:
		rejected.reason = "转移数量超过当前持有量"
		return rejected
	if quantity > maximum:
		rejected.reason = "舱室体积或全舰载荷不足"
		return rejected
	return {"ok": true, "reason": "", "maximum": maximum}

func count(container_id: String, item_id: String, normal_only: bool = true, mission_id: String = "") -> int:
	var n: int = 0
	for s in g.state.rows("inventory_stack_state"):
		if s.container_id == container_id and s.item_def_id == item_id and (not normal_only or s.policy_id == "normal_owned") and (mission_id.is_empty() or s.bound_mission_instance_id == mission_id): n += s.quantity
	for item in g.state.rows("item_instance_state"):
		if item.container_id == container_id and item.item_def_id == item_id and (not normal_only or item.policy_id == "normal_owned"): n += 1
	return n

func grant(container_id: String, item_id: String, quantity: int, policy: String = "normal_owned", mission_id: String = "", loan_id: String = "", origin: T.ItemOrigin = T.ItemOrigin.PURCHASE, recipe_id: String = "") -> Array[String]:
	var ids: Array[String] = []
	var def: Dictionary = g.definition("item_defs", "item_id", item_id)
	if def.stackable:
		for stack in g.state.rows("inventory_stack_state"):
			if stack.container_id == container_id and stack.item_def_id == item_id and stack.policy_id == policy and stack.bound_mission_instance_id == mission_id and stack.loan_id == loan_id:
				stack.quantity += quantity; ids.append(stack.stack_id); return ids
		var stack: D.InventoryStackStateDto = D.InventoryStackStateDto.new()
		stack.stack_id = g.id("stack"); stack.container_id = container_id; stack.item_def_id = item_id; stack.quantity = quantity; stack.policy_id = policy
		stack.origin_kind = T.StackOrigin.MISSION_BOUND if policy == "mission_bound" else T.StackOrigin.LOAN if not loan_id.is_empty() else T.StackOrigin.NORMAL if policy == "normal_owned" else T.StackOrigin.GUARANTEE
		stack.has_bound_mission_instance_id = not mission_id.is_empty(); stack.bound_mission_instance_id = mission_id
		stack.has_loan_id = not loan_id.is_empty(); stack.loan_id = loan_id
		g.state.add("inventory_stack_state", stack); ids.append(stack.stack_id)
	else:
		for i in range(quantity):
			var item: D.ItemInstanceStateDto = D.ItemInstanceStateDto.new()
			item.item_instance_id = g.id("item"); item.item_def_id = item_id; item.owner_player_id = g.state.player().player_id; item.container_id = container_id
			item.policy_id = policy; item.origin_kind = origin; item.quality_multiplier = g.rule("standard_quality_multiplier"); item.durability = g.rule("module_durability_max")
			var salvage: Dictionary = g.definition("module_salvage_recipe_defs", "module_id", item_id)
			item.salvage_recipe_id = recipe_id if not recipe_id.is_empty() else str(salvage.get("recipe_id",""))
			g.state.add("item_instance_state",item); ids.append(item.item_instance_id)
			if not loan_id.is_empty():
				var asset: D.LoanAssetStateDto = D.LoanAssetStateDto.new(); asset.loan_id = loan_id; asset.item_instance_id = item.item_instance_id; g.state.add("loan_asset_state",asset)
	return ids

func consume(container_id: String, item_id: String, quantity: int, normal_only: bool = true, mission_id: String = "") -> bool:
	if count(container_id,item_id,normal_only,mission_id) < quantity: return false
	var left: int = quantity
	for s in g.state.rows("inventory_stack_state").duplicate():
		if s.container_id != container_id or s.item_def_id != item_id or (normal_only and s.policy_id != "normal_owned") or (not mission_id.is_empty() and s.bound_mission_instance_id != mission_id): continue
		var used: int = mini(left,s.quantity); s.quantity -= used; left -= used
		if s.quantity == 0: g.state.remove("inventory_stack_state",s)
		if left == 0: return true
	for item in g.state.rows("item_instance_state").duplicate():
		if item.container_id == container_id and item.item_def_id == item_id and (not normal_only or item.policy_id == "normal_owned"):
			erase_item(item); left -= 1
			if left == 0: return true
	return left == 0

func erase_item(item: D.ItemInstanceStateDto) -> void:
	var e: RefCounted = g.state.find("equipment_state", "item_instance_id", item.item_instance_id)
	if e != null: g.state.remove("equipment_state",e)
	for table in ["loan_asset_state","manufacture_input_state"]:
		for row in g.state.rows(table).duplicate():
			if row.item_instance_id == item.item_instance_id: g.state.remove(table,row)
	g.state.remove("item_instance_state",item)

func move_stack(stack_id: String, quantity: int, destination: String) -> bool:
	var stack: D.InventoryStackStateDto = g.state.find("inventory_stack_state", "stack_id", stack_id)
	if stack == null or not accessible(stack.container_id) or not accessible(destination) or stack.quantity < quantity: return g.fail("货物或容器不可用")
	if stack.container_id == destination: return g.fail("源与目标相同")
	var source_container: RefCounted = g.state.find("container_state","container_id",stack.container_id)
	var target_container: RefCounted = g.state.find("container_state","container_id",destination)
	var mass_credit: float = quantity*g.definition("item_defs","item_id",stack.item_def_id).unit_mass_kg if source_container.has_ship_instance_id and source_container.ship_instance_id==target_container.ship_instance_id else 0.0
	if room(destination,stack.item_def_id,quantity,mass_credit) < quantity: return g.fail("体积或总载荷不足")
	grant(destination,stack.item_def_id,quantity,stack.policy_id,stack.bound_mission_instance_id,stack.loan_id)
	stack.quantity -= quantity
	if stack.quantity == 0: g.state.remove("inventory_stack_state",stack)
	remove_empty_wreck(str(source_container.container_id))
	return true

func move_item(item_id: String, destination: String) -> bool:
	var item: D.ItemInstanceStateDto = g.state.find("item_instance_state", "item_instance_id", item_id)
	if item == null or not accessible(item.container_id) or not accessible(destination) or g.state.find("equipment_state","item_instance_id",item_id) != null: return g.fail("不能移动已安装或异地模块")
	if item.policy_id != "normal_owned": return g.fail("保障或借用模块只能留在其保障舰")
	var source_container: RefCounted = g.state.find("container_state","container_id",item.container_id)
	var target_container: RefCounted = g.state.find("container_state","container_id",destination)
	var mass_credit: float = g.definition("item_defs","item_id",item.item_def_id).unit_mass_kg if source_container.has_ship_instance_id and source_container.ship_instance_id==target_container.ship_instance_id else 0.0
	if room(destination,item.item_def_id,1,mass_credit) < 1: return g.fail("载荷不足")
	item.container_id = destination
	remove_empty_wreck(str(source_container.container_id))
	return true

func fit(item_id: String, _quantity_index: int, target_slot: String) -> bool:
	if not g.allowed_service("fitting"): return false
	var item: D.ItemInstanceStateDto = g.state.find("item_instance_state", "item_instance_id", item_id)
	if item == null or not accessible(item.container_id) or g.state.find("equipment_state","item_instance_id",item_id) != null: return g.fail("模块不可安装")
	if item.policy_id == "normal_owned" and g.state.ship().policy_id != "normal_owned": return g.fail("保障或借船仅使用保护设备；普通自有设备请安装到自有舰船")
	var mod: Dictionary = g.definition("module_full_defs", "module_id", item.item_def_id)
	var tech: Dictionary = g.definition("module_tech_defs","module_id",item.item_def_id)
	if not tech.is_empty() and not g.unlocked(tech.required_unlock_id): return g.fail("设备科技尚未解锁")
	var parts: PackedStringArray = target_slot.split(":")
	var index: int = int(parts[1]) if parts.size()>1 else _quantity_index
	var kind: String = parts[0] if parts.size()>0 and not parts[0].is_empty() else str(mod.slot_type)
	var c: D.ContainerStateDto = slot(g.state.ship(),kind,index)
	if c == null or kind != mod.slot_type: return g.fail("槽位类型或位置不匹配")
	for e in g.state.rows("equipment_state"):
		if e.slot_container_id == c.container_id: return g.fail("槽位已占用")
	if item.policy_id != "normal_owned" and g.state.ship().policy_id == "normal_owned": return g.fail("绑定设备不能安装到普通舰船")
	var m: Dictionary = g.metrics(g.state.ship())
	if m.power_used+mod.power_pu>m.power_capacity or m.cpu_used+mod.cpu_cu>m.cpu_capacity or m.installed_mass_kg+mod.mass_kg>m.max_installed_mass_kg: return g.fail("功率、计算或安装质量超限")
	var count_same: int = 0
	for e in g.equipped(g.state.ship()):
		if e.module_def_id == mod.module_id: count_same += 1
	if mod.max_per_ship != null and count_same >= mod.max_per_ship: return g.fail("同类设备数量超限")
	for member in g.rows("module_group_members"):
		if member.module_id != item.item_def_id: continue
		var group: Dictionary = g.definition("module_exclusion_groups","group_id",member.group_id)
		var n: int = 0
		for e in g.equipped(g.state.ship()):
			for other in g.rows("module_group_members"):
				if other.module_id == e.module_def_id and other.group_id == member.group_id: n += 1
		if n>=group.max_installed: return g.fail("互斥设备组数量超限")
	item.container_id = c.container_id
	if g.state.ship().policy_id != "normal_owned":
		item.policy_id = g.state.ship().policy_id
		for loan in g.state.rows("loan_state"):
			if loan.status==T.LoanStatus.ACTIVE and loan.current_ship_id==g.state.ship().ship_instance_id and g.state.find("loan_asset_state","item_instance_id",item_id)==null:
				var asset:D.LoanAssetStateDto=D.LoanAssetStateDto.new();asset.loan_id=loan.loan_id;asset.item_instance_id=item_id;g.state.add("loan_asset_state",asset)
	var e: D.EquipmentStateDto = D.EquipmentStateDto.new()
	e.slot_container_id = c.container_id; e.item_instance_id = item_id; e.module_def_id = item.item_def_id; e.enabled = true
	g.state.add("equipment_state",e)
	return true

func unfit(item_id: String) -> bool:
	if not g.allowed_service("fitting"): return false
	var e: D.EquipmentStateDto = g.state.find("equipment_state","item_instance_id",item_id)
	if e == null or not g.equipped(g.state.ship()).has(e): return g.fail("模块未安装到当前舰船")
	var item: D.ItemInstanceStateDto = g.state.find("item_instance_state","item_instance_id",item_id)
	item.container_id = warehouse(g.station())
	g.state.remove("equipment_state",e)
	var m: Dictionary = g.metrics(g.state.ship())
	g.state.ship().armor = minf(g.state.ship().armor,m.armor_max)
	return true

func create_ship(ship_id: String, station_id: String, policy: String = "normal_owned", loadout_id: String = "", loan_id: String = "") -> D.ShipStateDto:
	var def: Dictionary = g.definition("ship_defs","ship_id",ship_id)
	var station: Dictionary = g.definition("station_defs","station_id",station_id)
	var ship: D.ShipStateDto = D.ShipStateDto.new()
	ship.ship_instance_id = g.id("ship"); ship.ship_def_id=ship_id; ship.owner_player_id = g.state.player().player_id
	ship.sector_id=station.sector_id; ship.status=T.ShipStatus.DOCKED; ship.has_station_id=true; ship.station_id=station_id; ship.policy_id=policy
	ship.shield=def.shield_max; ship.armor=def.armor_max; ship.hull=def.hull_max; ship.energy=def.energy_max
	g.state.add("ship_state",ship)
	for kind in [T.ContainerKind.CARGO,T.ContainerKind.MINERAL]:
		if kind == T.ContainerKind.MINERAL and def.mineral_cargo_l <= 0: continue
		var c: D.ContainerStateDto = D.ContainerStateDto.new(); c.container_id=g.id("hold");c.owner_player_id=ship.owner_player_id;c.kind=kind;c.has_ship_instance_id=true;c.ship_instance_id=ship.ship_instance_id;c.has_ship_def_id=true;c.ship_def_id=ship_id;c.sector_id=ship.sector_id;g.state.add("container_state",c)
	for slotdef in g.rows("ship_slot_defs"):
		if slotdef.ship_id != ship_id: continue
		var c: D.ContainerStateDto = D.ContainerStateDto.new();c.container_id=g.id("slot");c.owner_player_id=ship.owner_player_id;c.kind=T.ContainerKind.SLOT;c.has_ship_instance_id=true;c.ship_instance_id=ship.ship_instance_id;c.has_ship_def_id=true;c.ship_def_id=ship_id;c.sector_id=ship.sector_id;c.has_slot_type=true;c.slot_type=["weapon","work","utility","structure"].find(slotdef.slot_type);c.has_slot_index=true;c.slot_index=slotdef.slot_index;g.state.add("container_state",c)
	if not loadout_id.is_empty():
		for fitdef in g.rows("ship_loadout_items"):
			if fitdef.loadout_id != loadout_id: continue
			var c: D.ContainerStateDto = slot(ship,fitdef.slot_type,fitdef.slot_index)
			var ids: Array[String] = grant(c.container_id,fitdef.module_id,1,policy,"",loan_id,T.ItemOrigin.LOAN if not loan_id.is_empty() else T.ItemOrigin.GUARANTEE)
			var e: D.EquipmentStateDto = D.EquipmentStateDto.new();e.slot_container_id=c.container_id;e.item_instance_id=ids[0];e.module_def_id=fitdef.module_id;e.enabled=true;g.state.add("equipment_state",e)
		for supply in g.rows("loadout_supply_defs"):
			if supply.loadout_id == loadout_id: grant(hold(ship,T.ContainerKind.CARGO),supply.item_id,supply.quantity,policy,"",loan_id)
	return ship

func unload(ship: D.ShipStateDto, station_id: String, normal_only: bool = true) -> void:
	var dest: String = warehouse(station_id)
	for c in g.state.rows("container_state"):
		if c.ship_instance_id != ship.ship_instance_id or c.kind == T.ContainerKind.SLOT: continue
		for stack in g.state.rows("inventory_stack_state"):
			if stack.container_id == c.container_id and (not normal_only or stack.policy_id == "normal_owned"): stack.container_id = dest
		for item in g.state.rows("item_instance_state"):
			if item.container_id == c.container_id and (not normal_only or item.policy_id == "normal_owned"): item.container_id = dest
		# A sealed package is ordinary cargo, independently of the hull's loan
		# policy. Move the original record so its predetermined reward survives.
		for package: D.SalvagePackageStateDto in g.state.rows("salvage_package_state"):
			if package.status == "sealed" and package.has_host_container_id and package.host_container_id == c.container_id:
				package.host_container_id = dest

func retire(ship: D.ShipStateDto) -> void:
	for c in g.state.rows("container_state"):
		if c.ship_instance_id != ship.ship_instance_id: continue
		for stack in g.state.rows("inventory_stack_state").duplicate():
			if stack.container_id == c.container_id: g.state.remove("inventory_stack_state",stack)
		for item in g.state.rows("item_instance_state").duplicate():
			if item.container_id == c.container_id: erase_item(item)
		for package: D.SalvagePackageStateDto in g.state.rows("salvage_package_state").duplicate():
			if package.status == "sealed" and package.has_host_container_id and package.host_container_id == c.container_id: g.state.remove("salvage_package_state", package)
	ship.status = T.ShipStatus.RETURNED; ship.hull = 0; ship.has_station_id = false; ship.station_id = ""

func wreck(sector: String, pos: Vector3) -> String:
	var c: D.ContainerStateDto = D.ContainerStateDto.new();c.container_id=g.id("wreck");c.owner_player_id=g.state.player().player_id;c.kind=T.ContainerKind.WRECK;c.sector_id=sector;c.has_pos_x=true;c.has_pos_y=true;c.has_pos_z=true;c.pos_x=pos.x;c.pos_y=pos.y;c.pos_z=pos.z;g.state.add("container_state",c)
	return c.container_id

func ship_destroyed(ship: D.ShipStateDto) -> void:
	var dest: String = wreck(ship.sector_id,g.position(ship))
	var stack_groups:Dictionary={}
	var item_groups:Dictionary={}
	var packages: Array[D.SalvagePackageStateDto] = []
	for c in g.state.rows("container_state"):
		if c.ship_instance_id != ship.ship_instance_id: continue
		for stack in g.state.rows("inventory_stack_state").duplicate():
			if stack.container_id != c.container_id: continue
			if stack.policy_id == "normal_owned":
				# Compatible source stacks are grouped across holds before rounding.
				var key:String="%s|%s|%s|%s|%s"%[stack.item_def_id,stack.policy_id,stack.origin_kind,stack.bound_mission_instance_id,stack.loan_id]
				if not stack_groups.has(key):stack_groups[key]=[]
				stack_groups[key].append(stack)
			else:g.state.remove("inventory_stack_state",stack)
		for item in g.state.rows("item_instance_state").duplicate():
			if item.container_id != c.container_id: continue
			# Installed equipment is destroyed; it never becomes guaranteed salvage.
			if c.kind==T.ContainerKind.SLOT or item.policy_id!="normal_owned":erase_item(item);continue
			var key:String="%s|%s|%s|%s|%s"%[item.item_def_id,item.origin_kind,item.salvage_recipe_id,item.quality_multiplier,item.durability]
			if not item_groups.has(key):item_groups[key]=[]
			item_groups[key].append(item)
		for package: D.SalvagePackageStateDto in g.state.rows("salvage_package_state"):
			if package.status == "sealed" and package.has_host_container_id and package.host_container_id == c.container_id: packages.append(package)
	var ratio:float=g.rule("wreck_cargo_recovery_ratio")
	for key in stack_groups:
		var group:Array=stack_groups[key];var units:int=0
		for stack in group:units+=stack.quantity
		var survived:int=int(floor(units*ratio))
		for index in range(group.size()):
			var stack:D.InventoryStackStateDto=group[index]
			if index==0 and survived>0:stack.container_id=dest;stack.quantity=survived
			else:g.state.remove("inventory_stack_state",stack)
	for key in item_groups:
		var group:Array=item_groups[key]
		group.sort_custom(func(a:RefCounted,b:RefCounted)->bool:return a.item_instance_id<b.item_instance_id)
		var survived:int=int(floor(group.size()*ratio))
		for index in range(group.size()):
			if index<survived:group[index].container_id=dest
			else:erase_item(group[index])
	packages.sort_custom(func(a: D.SalvagePackageStateDto, b: D.SalvagePackageStateDto) -> bool: return a.package_id < b.package_id)
	var recovered: int = floori(float(packages.size()) * ratio)
	for index: int in range(packages.size()):
		if index < recovered: packages[index].host_container_id = dest
		else: g.state.remove("salvage_package_state", packages[index])
	remove_empty_wreck(dest)

func pickup_wreck(container_id: String) -> bool:
	var c: D.ContainerStateDto = g.state.find("container_state","container_id",container_id)
	if c==null or c.kind!=T.ContainerKind.WRECK or not accessible(container_id): return g.fail("残骸不在打捞范围")
	if g.spatial_validator.is_valid() and g.spatial_validator.call(g.position(g.state.ship()), Vector3(c.pos_x, c.pos_y, c.pos_z), container_id) != true: return g.fail("残骸被障碍物遮挡，请调整舰船位置")
	var dest: String = hold(g.state.ship(),T.ContainerKind.CARGO)
	var moved: bool = false
	for stack in g.state.rows("inventory_stack_state").duplicate():
		if stack.container_id==container_id:
			var units: int = room(dest,stack.item_def_id,stack.quantity)
			if units>0 and move_stack(stack.stack_id,units,dest): moved=true
	for item in g.state.rows("item_instance_state"):
		if item.container_id==container_id and room(dest,item.item_def_id,1)>0: item.container_id=dest;moved=true
	var encounters: RefCounted = g.get("encounters")
	for package: D.SalvagePackageStateDto in g.state.rows("salvage_package_state"):
		if package.status != "sealed" or not package.has_host_container_id or package.host_container_id != container_id: continue
		if encounters == null or not bool(encounters.call("can_hold", dest, package.package_def_id)): continue
		package.host_container_id = dest
		moved = true
	remove_empty_wreck(container_id)
	return moved or g.fail("残骸为空或货舱已满")

func remove_empty_wreck(container_id: String) -> void:
	var container: D.ContainerStateDto = g.state.find("container_state", "container_id", container_id)
	if container == null or container.kind != T.ContainerKind.WRECK: return
	for stack: D.InventoryStackStateDto in g.state.rows("inventory_stack_state"):
		if stack.container_id == container_id and stack.quantity > 0: return
	for item: D.ItemInstanceStateDto in g.state.rows("item_instance_state"):
		if item.container_id == container_id: return
	for package: D.SalvagePackageStateDto in g.state.rows("salvage_package_state"):
		if package.status == "sealed" and package.has_host_container_id and package.host_container_id == container_id: return
	g.state.remove("container_state", container)
