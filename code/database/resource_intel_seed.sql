-- Preserve the original protected neutral corridor's yields and tutorial budget.
INSERT INTO resource_grade_defs
 SELECT n.node_id,
 CASE WHEN i.item_type<>'ore' OR (p.initial_faction_id IS NULL AND p.conquerable=0) THEN 1 WHEN r.npc_level_max>8 THEN 3 WHEN r.npc_level_max>5 THEN 2 ELSE 1 END,
 CASE WHEN i.item_type<>'ore' THEN '可回收组件' WHEN p.initial_faction_id IS NULL AND p.conquerable=0 THEN '常规矿脉' WHEN r.npc_level_max>8 THEN '高品位矿脉' WHEN r.npc_level_max>5 THEN '富集矿脉' ELSE '常规矿脉' END,
 CASE WHEN i.item_type<>'ore' OR (p.initial_faction_id IS NULL AND p.conquerable=0) THEN 10000 WHEN r.npc_level_max>8 THEN 12000 WHEN r.npc_level_max>5 THEN 11000 ELSE 10000 END
 FROM resource_node_defs n JOIN item_defs i ON i.item_id=n.item_id
 JOIN sector_defs s USING(sector_id) JOIN risk_zone_defs r USING(risk_zone_id) JOIN sector_sovereignty_defs p USING(sector_id);
INSERT INTO sector_activity_defs
 SELECT s.sector_id,
 coalesce((SELECT group_concat(display_name,'、') FROM (SELECT DISTINCT i.display_name FROM resource_node_defs n JOIN item_defs i ON i.item_id=n.item_id WHERE n.sector_id=s.sector_id ORDER BY i.item_id)), '无已登记矿产'),
 r.display_name||' · NPC '||r.npc_level_min||'–'||r.npc_level_max,
 CASE WHEN EXISTS(SELECT 1 FROM station_defs st JOIN station_service_defs sv USING(station_id) WHERE st.sector_id=s.sector_id AND sv.service_id='manufacture') THEN '工业与补给节点' ELSE '航路与资源中转' END,
 CASE WHEN p.conquerable=1 THEN '边疆争夺与巡护' WHEN p.initial_faction_id IS NULL THEN '中立航路与民用合同' ELSE '文明委托与工业发展' END
 FROM sector_defs s JOIN risk_zone_defs r USING(risk_zone_id) JOIN sector_sovereignty_defs p USING(sector_id);
UPDATE catalog_meta SET schema_version=9,content_version='v0.10-resource-intel',ruleset_version='singleplayer_resource_intel_v1',source_document='doc/52-物资来源与矿点情报.md';
