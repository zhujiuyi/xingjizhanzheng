extends RefCounted
const D = preload("res://contracts/contract_dtos.gd")
const T = preload("res://contracts/contract_types.gd")
var g: RefCounted
var _definition_catalog: RefCounted
var _definition_hash: String=""
var _goods: Dictionary={}
var _hulls: Dictionary={}
func _init(gameplay: RefCounted) -> void: g = gameplay

func _index_stock_definitions() -> void:
	if _definition_catalog==g.catalog and _definition_hash==g.catalog.content_hash:return
	_goods.clear();_hulls.clear();_definition_catalog=g.catalog;_definition_hash=g.catalog.content_hash
	for row: Dictionary in g.catalog.rows("station_stock_defs"):
		if not _goods.has(row.station_id):_goods[row.station_id]={}
		_goods[row.station_id][row.item_id]=row
	for row: Dictionary in g.catalog.rows("station_ship_stock_defs"):
		if not _hulls.has(row.station_id):_hulls[row.station_id]={}
		_hulls[row.station_id][row.ship_id]=row

func reputation(faction_id: String) -> int:
	var row: RefCounted = g.state.find("reputation_state","faction_id",faction_id)
	return row.reputation if row != null else 0

func _stock(item_id: String) -> D.ShopStockStateDto:
	for row in g.state.rows("shop_stock_state"):
		if row.station_id == g.station() and row.item_def_id == item_id: return row
	return null
func _ship_stock(ship_id: String) -> D.ShopShipStockStateDto:
	for row in g.state.rows("shop_ship_stock_state"):
		if row.station_id == g.station() and row.ship_def_id == ship_id: return row
	return null
func _stock_def(item_id: String) -> Dictionary:
	_index_stock_definitions()
	var definition: Dictionary=_goods.get(g.station(),{}).get(item_id,{})
	return definition.duplicate(true)
func _budget() -> D.StationEconomyStateDto:
	return g.state.find("station_economy_state","station_id",g.station())

func quote(item_id: String, quantity: int, selling: bool = false) -> int:
	var stock: D.ShopStockStateDto = _stock(item_id)
	if stock==null:return 0
	var faction: String = g.definition("station_defs","station_id",g.station()).faction_id
	var bonus: float = minf(1.0,maxf(0.0,float(reputation(faction))/g.rule("reputation_discount_full_at")))
	var pressure: float = g.industry.price_factor(item_id) if g.industry != null else 1.0
	if selling:return int(floor(stock.bid_credit*pressure*quantity*(1+g.rule("max_sell_bonus_ratio")*bonus)*(1-g.rule("trade_fee_ratio"))))
	return int(ceil(stock.ask_credit*pressure*quantity*(1-g.rule("max_buy_discount_ratio")*bonus)*(1+g.rule("trade_fee_ratio"))))

func buy_item(item_id: String, quantity: int, destination: String) -> bool:
	if not g.allowed_service("trade"):return false
	var def: Dictionary = _stock_def(item_id)
	var stock: D.ShopStockStateDto = _stock(item_id)
	if def.is_empty() or stock==null or not def.allow_buy or not g.unlocked(def.required_unlock_id):return g.fail("商品尚未开放")
	if stock.quantity<quantity:return g.fail("站点库存不足")
	var dest: String = destination if not destination.is_empty() else g.inventory.warehouse(g.station())
	if not g.inventory.accessible(dest) or g.inventory.room(dest,item_id,quantity)<quantity:return g.fail("目标仓库无空间")
	var price: int = quote(item_id,quantity)
	if g.state.player().credit<price:return g.fail("信用点不足")
	g.state.player().credit-=price;stock.quantity-=quantity
	g.inventory.grant(dest,item_id,quantity)
	g.journal.source(item_id,quantity,"purchase")
	return true

func sell_item(entity_id: String, quantity: int) -> bool:
	if not g.allowed_service("trade"):return false
	var item: D.ItemInstanceStateDto = g.state.find("item_instance_state","item_instance_id",entity_id)
	var stack: D.InventoryStackStateDto = g.state.find("inventory_stack_state","stack_id",entity_id)
	if item==null and stack==null:return g.fail("出售目标不存在")
	var item_id: String = item.item_def_id if item!=null else stack.item_def_id
	var policy: String = item.policy_id if item!=null else stack.policy_id
	var container: String = item.container_id if item!=null else stack.container_id
	if not g.inventory.accessible(container) or not g.definition("asset_policy_defs","policy_id",policy).may_sell:return g.fail("异地或受保护物品不能出售")
	if item!=null and (quantity!=1 or g.state.find("equipment_state","item_instance_id",entity_id)!=null):return g.fail("先卸下模块再出售")
	if stack!=null and stack.quantity<quantity:return g.fail("数量不足")
	var def: Dictionary = _stock_def(item_id)
	var stock: D.ShopStockStateDto = _stock(item_id)
	if def.is_empty() or stock==null or not def.allow_sell:return g.fail("站点不收购此物品")
	var price: int = quote(item_id,quantity,true)
	var budget: D.StationEconomyStateDto = _budget()
	if stock.buyback_remaining_units<quantity or stock.quantity+quantity>def.hard_cap_units or budget.buyback_remaining_credit<price:return g.fail("站点收购额度已用尽")
	if item!=null:g.inventory.erase_item(item)
	else:
		stack.quantity-=quantity
		if stack.quantity==0:g.state.remove("inventory_stack_state",stack)
	stock.quantity+=quantity;stock.buyback_remaining_units-=quantity;budget.buyback_remaining_credit-=price;g.state.player().credit+=price
	return true

func buy_ship(ship_id: String) -> bool:
	if not g.allowed_service("ship_purchase"):return false
	var civilization_reason: String = g.civilizations.hull_reason(ship_id)
	if not civilization_reason.is_empty(): return g.fail(civilization_reason)
	var stock: D.ShopShipStockStateDto = _ship_stock(ship_id)
	var role: Dictionary = g.definition("ship_role_defs","ship_id",ship_id)
	if stock==null or stock.quantity<=0 or (not role.is_empty() and not g.unlocked(role.required_unlock_id)):return g.fail("舰体未开放或暂无库存")
	var price: int = quote_ship(ship_id)
	if g.state.player().credit<price:return g.fail("信用点不足")
	g.state.player().credit-=price;stock.quantity-=1
	g.inventory.create_ship(ship_id,g.station())
	return true

func sell_ship(ship_id: String) -> bool:
	if not g.allowed_service("ship_purchase"):return false
	var ship: D.ShipStateDto = g.state.find("ship_state","ship_instance_id",ship_id)
	if g.scenarios.ship_locked(ship_id):return g.fail("先结束该舰绑定的挑战或封锁行动")
	if ship==null or ship.status!=T.ShipStatus.DOCKED or ship.station_id!=g.station() or ship.owner_player_id!=g.state.player().player_id:return g.fail("只能出售同站点自己的舰船")
	if not g.definition("asset_policy_defs","policy_id",ship.policy_id).may_sell:return g.fail("保障或借船不能出售")
	if g.state.player().controlled_ship_id==ship_id:return g.fail("先切换到另一艘船")
	var fleet_reason: String=g.owned_fleet.removal_reason(ship_id)
	if not fleet_reason.is_empty():return g.fail(fleet_reason)
	var stock: D.ShopShipStockStateDto = _ship_stock(ship.ship_def_id)
	var stockdef: Dictionary = {}
	for row in g.rows("station_ship_stock_defs"):
		if row.station_id==g.station() and row.ship_id==ship.ship_def_id:stockdef=row
	if stock==null or stockdef.is_empty() or stock.quantity>=stockdef.hard_cap_units:return g.fail("本站不再收购此舰体")
	var price: int = quote_ship(ship.ship_def_id,true)
	if _budget().buyback_remaining_credit<price:return g.fail("站点收购预算不足")
	for mounted in g.equipped(ship):
		if g.state.find("item_instance_state","item_instance_id",mounted.item_instance_id).policy_id!="normal_owned":return g.fail("船上仍有绑定设备")
	g.inventory.unload(ship,g.station())
	var dest: String = g.inventory.warehouse(g.station())
	for e in g.equipped(ship).duplicate():
		var item: D.ItemInstanceStateDto = g.state.find("item_instance_state","item_instance_id",e.item_instance_id)
		if item.policy_id!="normal_owned":return g.fail("船上仍有绑定设备")
		item.container_id=dest;g.state.remove("equipment_state",e)
	g.owned_fleet.remove_ship_records(ship_id)
	g.inventory.retire(ship)
	stock.quantity+=1;_budget().buyback_remaining_credit-=price;g.state.player().credit+=price
	return true

func _inputs(table: String, key: String, target: String, batches: int) -> Dictionary:
	var result: Dictionary = {}
	for row in g.rows(table):
		if row[key]==target:result[row.item_id]=row.quantity*batches
	return result
func _can_inputs(inputs: Dictionary) -> bool:
	var source: String = g.inventory.warehouse(g.station())
	for item_id in inputs:
		if g.inventory.count(source,item_id,true)<inputs[item_id]:return g.fail("仓库缺少正常来源材料："+str(g.definition("item_defs", "item_id", item_id).get("display_name", item_id)))
	return true
func _consume_inputs(inputs: Dictionary) -> void:
	var source: String = g.inventory.warehouse(g.station())
	for item_id in inputs:g.inventory.consume(source,item_id,inputs[item_id],true)

func manufacture(recipe_id: String, batches: int) -> bool:
	if g.industry != null and g.industry.supported(): return g.industry.start(recipe_id, batches)
	if not g.allowed_service("manufacture"):return false
	var hull: Dictionary = g.definition("hull_recipe_defs","hull_recipe_id",recipe_id)
	if not hull.is_empty():
		var civilization_reason: String = g.civilizations.hull_reason(hull.ship_id)
		if not civilization_reason.is_empty(): return g.fail(civilization_reason)
		if not g.unlocked(hull.required_unlock_id):return g.fail("舰体蓝图未掌握")
		if _ship_stock(hull.ship_id)==null:return g.fail("本站没有此舰体规格的船坞")
		var inputs: Dictionary = _inputs("hull_recipe_inputs","hull_recipe_id",recipe_id,batches)
		var fee: int = int(ceil(hull.service_fee_credit*batches/base_factor("industry")))
		if not _can_inputs(inputs) or g.state.player().credit<fee:return g.fail("舰体材料或服务费不足")
		_consume_inputs(inputs);g.state.player().credit-=fee
		for i in range(batches):g.inventory.create_ship(hull.ship_id,g.station())
		return true
	var recipe: Dictionary = g.definition("recipe_defs","recipe_id",recipe_id)
	if recipe.is_empty():return g.fail("配方不存在")
	var access: bool = false
	for row in g.rows("recipe_access_defs"):
		if row.recipe_id==recipe_id and row.station_id==g.station() and g.unlocked(row.required_unlock_id):access=true
	if not access:return g.fail("本站设施或蓝图尚不可用")
	var inputs: Dictionary = _inputs("recipe_inputs","recipe_id",recipe_id,batches)
	var fee: int = int(ceil(recipe.service_fee_credit*batches/base_factor("industry")))
	if not _can_inputs(inputs) or g.state.player().credit<fee:return g.fail("材料或服务费不足")
	_consume_inputs(inputs);g.state.player().credit-=fee
	var batch: D.ProductionStateDto = D.ProductionStateDto.new();batch.production_id=g.id("production");batch.player_id=g.state.player().player_id;batch.recipe_id=recipe_id;batch.station_id=g.station();batch.batches=batches;batch.output_claimed=true;g.state.add("production_state",batch)
	var ids: Array[String] = g.inventory.grant(g.inventory.warehouse(g.station()),recipe.output_item_id,recipe.output_quantity*batches,"normal_owned","","",T.ItemOrigin.MANUFACTURE,recipe_id)
	g.journal.source(recipe.output_item_id,int(recipe.output_quantity)*batches,"manufacture")
	if not g.definition("module_defs","module_id",recipe.output_item_id).is_empty():
		for item_id in ids:
			var item: D.ItemInstanceStateDto = g.state.find("item_instance_state","item_instance_id",item_id);item.has_manufacture_batch_id=true;item.manufacture_batch_id=batch.production_id
			for material in inputs:
				var ledger: D.ManufactureInputStateDto = D.ManufactureInputStateDto.new();ledger.item_instance_id=item_id;ledger.input_item_id=material;ledger.input_quantity=int(inputs[material]/(recipe.output_quantity*batches));g.state.add("manufacture_input_state",ledger)
	return true

func recycle(item_id: String) -> bool:
	if not g.allowed_service("recycle"):return false
	var item: D.ItemInstanceStateDto = g.state.find("item_instance_state","item_instance_id",item_id)
	if item==null or not g.inventory.accessible(item.container_id) or g.state.find("equipment_state","item_instance_id",item_id)!=null:return g.fail("先将模块卸到本站仓库")
	if not g.definition("asset_policy_defs","policy_id",item.policy_id).may_recycle:return g.fail("受保护设备不能拆解")
	var inputs: Dictionary = {}
	# Actual manufacturing inputs and materialized historical standard inputs
	# belong to the instance. Its origin tag remains unchanged during upgrades.
	for row in g.state.rows("manufacture_input_state"):
		if row.item_instance_id==item_id:inputs[row.input_item_id]=row.input_quantity
	if inputs.is_empty() and item.origin_kind==T.ItemOrigin.MANUFACTURE:return g.fail("缺少合法材料追溯账本")
	if inputs.is_empty():
		if item.salvage_recipe_id.is_empty():return g.fail("设备没有冻结拆解来源")
		inputs=_inputs("recipe_inputs","recipe_id",item.salvage_recipe_id,1)
	if inputs.is_empty():return g.fail("缺少合法材料追溯账本")
	var fee: int = int(g.rule("recycle_service_fee_credit"))
	if g.state.player().credit<fee:return g.fail("拆解服务费不足")
	g.state.player().credit-=fee
	g.inventory.erase_item(item)
	for input in inputs:
		var returned: int = int(floor(inputs[input]*g.rule("recycle_input_return_ratio")))
		if returned>0:g.inventory.grant(g.inventory.warehouse(g.station()),input,returned)
	return true

func repair(_target: String) -> bool:
	if not g.allowed_service("repair"):return false
	var ship: D.ShipStateDto = g.state.ship()
	var m: Dictionary = g.metrics(ship)
	var required: Dictionary = repair_requirements()
	var fee: int = required.credit
	var structural: int = required.structural_units
	var source: String = g.inventory.warehouse(g.station())
	if g.state.player().credit<fee or g.inventory.count(source,"material_structural_stock",true)<structural:return g.fail("维修费用或结构料不足")
	g.state.player().credit-=fee;g.inventory.consume(source,"material_structural_stock",structural,true)
	var before: float=ship.armor+ship.hull+ship.shield
	ship.armor=m.armor_max;ship.hull=m.hull_max;ship.shield=m.shield_max;ship.energy=m.energy_max;ship.heat=0
	g.telemetry.repair("station",ship.armor+ship.hull+ship.shield-before)
	for e in g.equipped(ship):g.state.find("item_instance_state","item_instance_id",e.item_instance_id).durability=g.rule("module_durability_max")
	return true

func research(research_id: String) -> bool:
	if not g.allowed_service("manufacture"):return false
	var civilization_reason: String = g.civilizations.research_reason(research_id)
	if not civilization_reason.is_empty(): return g.fail(civilization_reason)
	var def: Dictionary = g.definition("research_defs","research_id",research_id)
	if def.is_empty() or g.unlocked(def.reward_unlock_id):return g.fail("研究不存在或已完成")
	if g.definition("station_defs","station_id",g.station()).faction_id!=def.station_faction_id:return g.fail("需到对应势力研究设施")
	if reputation(def.station_faction_id)<def.required_reputation:return g.fail("势力声望不足")
	if def.verification_mission_id!=null and not g.missions.completed(def.verification_mission_id):return g.fail("尚未完成验证任务")
	for row in g.rows("research_prerequisites"):
		if row.research_id==research_id and not g.unlocked(row.unlock_id):return g.fail("前置知识尚未掌握")
	var inputs: Dictionary = _inputs("research_inputs","research_id",research_id,1)
	if not _can_inputs(inputs) or g.state.player().credit<def.required_credit:return g.fail("研究样本或服务费不足")
	_consume_inputs(inputs);g.state.player().credit-=def.required_credit;g.grant_unlock(def.reward_unlock_id)
	return true

func build_base(module_id: String) -> bool:
	if not g.allowed_service("manufacture"):return false
	var def: Dictionary = g.definition("base_module_defs","base_module_id",module_id)
	if def.is_empty() or not g.unlocked(def.required_unlock_id):return g.fail("个人设施尚未解锁")
	for row in g.state.rows("base_module_state"):
		if row.station_id==g.station() and row.base_module_id==module_id:return g.fail("本站已经有同型设施")
	var inputs: Dictionary = _inputs("base_module_inputs","base_module_id",module_id,1)
	if not _can_inputs(inputs) or g.state.player().credit<def.service_fee_credit:return g.fail("设施材料或费用不足")
	_consume_inputs(inputs);g.state.player().credit-=def.service_fee_credit
	var row: RefCounted = g.state.new_row("base_module_state")
	if row==null:return g.fail("基地状态结构尚不可用")
	row.base_instance_id=g.id("base");row.player_id=g.state.player().player_id;row.base_module_id=module_id;row.station_id=g.station();row.enabled=true;g.state.add("base_module_state",row)
	return true

func base_factor(service_kind: String) -> float:
	var result: float = 1.0
	for row in g.state.rows("base_module_state"):
		var station:Dictionary=g.definition("station_defs","station_id",row.station_id)
		if not row.enabled or (row.station_id!=g.station() and (service_kind!="navigation" or station.sector_id!=g.state.current_sector())):continue
		var def: Dictionary = g.definition("base_module_defs","base_module_id",row.base_module_id)
		if def.service_kind==service_kind:result=maxf(result,def.effect_multiplier)
	return result

func tick(delta: float) -> void:
	# Modifiers are pure station queries. Cache only within this tick, keeping
	# delta * frontier * project in its original floating-point order.
	var decrements: Dictionary={}
	for budget in g.state.rows("station_economy_state"):
		budget.refresh_remaining_s=maxf(0,budget.refresh_remaining_s-delta)
		if budget.refresh_remaining_s==0:
			var station: Dictionary = g.definition("station_defs","station_id",budget.station_id);budget.refresh_remaining_s=station.stock_refresh_s;budget.buyback_remaining_credit=station.buyback_budget_credit
	for stock in g.state.rows("shop_stock_state"):
		if not decrements.has(stock.station_id):decrements[stock.station_id]=delta*g.frontier.restock_rate(stock.station_id)*g.projects.factor(stock.station_id,"stock_refresh")
		stock.refresh_remaining_s=maxf(0,stock.refresh_remaining_s-float(decrements[stock.station_id]))
		if stock.refresh_remaining_s>0:continue
		_index_stock_definitions()
		var def: Dictionary=_goods.get(stock.station_id,{}).get(stock.item_def_id,{})
		if not def.is_empty():
			stock.quantity=mini(def.hard_cap_units,mini(def.target_units,maxi(stock.quantity,stock.quantity+def.restock_units_per_refresh))) if stock.quantity<def.target_units else stock.quantity
			stock.buyback_remaining_units=def.buyback_units_per_refresh
		stock.refresh_remaining_s=g.definition("station_defs","station_id",stock.station_id).stock_refresh_s
	for stock in g.state.rows("shop_ship_stock_state"):
		if not decrements.has(stock.station_id):decrements[stock.station_id]=delta*g.frontier.restock_rate(stock.station_id)*g.projects.factor(stock.station_id,"stock_refresh")
		stock.refresh_remaining_s=maxf(0,stock.refresh_remaining_s-float(decrements[stock.station_id]))
		if stock.refresh_remaining_s>0:continue
		_index_stock_definitions()
		var def: Dictionary=_hulls.get(stock.station_id,{}).get(stock.ship_def_id,{})
		if not def.is_empty():stock.quantity=mini(def.target_units,stock.quantity+def.restock_units_per_refresh) if stock.quantity<def.target_units else stock.quantity
		stock.refresh_remaining_s=g.definition("station_defs","station_id",stock.station_id).stock_refresh_s


func quote_ship(ship_id: String, selling: bool = false) -> int:
	var instance: RefCounted = g.state.find("ship_state","ship_instance_id",ship_id)
	var definition_id: String = instance.ship_def_id if instance!=null else ship_id
	var stock: D.ShopShipStockStateDto = _ship_stock(definition_id)
	if stock==null:return 0
	var faction: String = g.definition("station_defs","station_id",g.station()).faction_id
	var progress: float = clampf(float(reputation(faction))/g.rule("reputation_discount_full_at"),0,1)
	if selling:return int(floor(stock.bid_credit*(1+g.rule("max_sell_bonus_ratio")*progress)*(1-g.rule("trade_fee_ratio"))))
	return int(ceil(stock.ask_credit*(1-g.rule("max_buy_discount_ratio")*progress)*(1+g.rule("trade_fee_ratio"))))

func repair_requirements() -> Dictionary:
	var ship: D.ShipStateDto = g.state.ship()
	var m: Dictionary = g.metrics(ship)
	var armor: int = int(ceil(maxf(0,m.armor_max-ship.armor)))
	var hull: int = int(ceil(maxf(0,m.hull_max-ship.hull)))
	var fee: int = int(armor*g.rule("station_armor_credit_per_hp")+hull*g.rule("station_hull_credit_per_hp"))
	for e in g.equipped(ship):
		var item: D.ItemInstanceStateDto = g.state.find("item_instance_state","item_instance_id",e.item_instance_id)
		fee += int(ceil(maxf(0,g.rule("module_durability_max")-item.durability)*g.rule("station_module_credit_per_durability")))
	return {"credit":int(ceil(fee*g.frontier.station_factor(g.station(),"repair")*g.projects.factor(g.station(),"repair_fee")/base_factor("repair"))),"structural_units":int(ceil(hull/g.rule("station_hull_hp_per_structural_unit")))}

func quote_repair() -> int:
	return repair_requirements().credit

func quote_manufacture(recipe_id: String, batches: int = 1) -> int:
	var def: Dictionary = g.definition("recipe_defs","recipe_id",recipe_id)
	if def.is_empty():def=g.definition("hull_recipe_defs","hull_recipe_id",recipe_id)
	var discount: float = g.industry.discount(g.station()) if g.industry != null else 1.0
	return int(ceil(def.service_fee_credit*batches*discount*g.projects.factor(g.station(),"manufacture_fee")/base_factor("industry"))) if not def.is_empty() else 0
