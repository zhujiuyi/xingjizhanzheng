INSERT INTO industry_balance_defs VALUES(1,4,20,8000,8500,11500,1500,1000,900.0);
INSERT INTO industry_recipe_defs
 SELECT r.recipe_id,r.recipe_id,NULL,12.0*coalesce(t.tech_level,1)
 FROM recipe_defs r LEFT JOIN module_tech_defs t ON t.module_id=r.output_item_id;
INSERT INTO industry_recipe_defs
 SELECT hull_recipe_id,NULL,hull_recipe_id,CASE WHEN service_fee_credit<1000 THEN 30.0 WHEN service_fee_credit<10000 THEN 90.0 ELSE 180.0 END
 FROM hull_recipe_defs;
-- Small repeatable material needs across authored industrial hubs. No new currency source without actual delivery.
INSERT INTO station_demand_defs
 SELECT 'demand_'||s.station_id,s.station_id,i.item_id,
 CASE s.faction_id WHEN 'faction_route_council' THEN '传感晶矿补给' WHEN 'faction_deepforge' THEN '冶炼矿料补给' ELSE '站点维修补给' END,
 CASE s.faction_id WHEN 'faction_route_council' THEN '航路传感网需要晶矿维护；完成需求后提供限时工业优惠。' WHEN 'faction_deepforge' THEN '重型工业炉需要铁硅矿补充原料；完成需求后提供限时工业优惠。' ELSE '泊位检修与航路设施维护需要结构料；完成需求后提供限时工业优惠。' END,
 60,CAST(i.base_bid_credit*1.2 AS INTEGER),30,1200.0,600.0
 FROM station_defs s JOIN item_defs i ON i.item_id=CASE s.faction_id WHEN 'faction_route_council' THEN 'ore_conductive_crystal' WHEN 'faction_deepforge' THEN 'ore_ferrosilicate' ELSE 'material_structural_stock' END
 WHERE EXISTS(SELECT 1 FROM station_service_defs p WHERE p.station_id=s.station_id AND p.service_id='manufacture');
UPDATE catalog_meta SET schema_version=8,content_version='v0.9-industry',ruleset_version='singleplayer_industry_v1',source_document='doc/51-单机完善实施与验收矩阵.md';
